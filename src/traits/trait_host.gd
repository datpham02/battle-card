class_name TraitHost
extends RefCounted
## Owns the BossTrait instances of ONE battle (CombatView builds one host per match from
## match_params["traits"]) and forwards every hook to them in declaration order. Unknown trait
## ids and malformed entries are skipped with a warning; the match still runs. Each trait gets
## the match seed plus its index times BossTrait.SEED_STRIDE (negative seed = random), so two
## instances of one trait id do not share an RNG stream.
## Implements: Story 014 (Part B).

## Story 023: a trait changed the boss phase (phase_shift): the new phase number (2 = first change).
signal phase_changed(phase: int)

## Multi-enemy Phase 5 (step 1): the enemy unit this host's traits belong to (a CombatState key; unit 0 by
## default, so a one-enemy match is unchanged). Also placed in the trait context as `key`, which is how a trait
## learns which unit it is attached to.
var key: int = CombatState.Side.ENEMY

var _traits: Array[BossTrait] = []
var _ctx: Dictionary = {}
## True when this host installed the five one-point hooks itself (the single-host callers). False for CombatView's
## per-unit hosts, which must neither install nor unbind them.
var _installed_hooks: bool = true
var _seed_value: int = -1
var _next_index: int = 0
## Monster Skill Phase 0: a second voice on the three one-point hooks, for the pattern brain's skill effects (evade,
## shroud, immune_reactions): Callable() -> bool / Callable(side, id) -> bool, OR'd with the live traits' answers.
## Invalid = none. Set by CombatView after the PatternController exists; never by a trait.
var extra_untargetable_fn: Callable = Callable()
var extra_forecast_blocked_fn: Callable = Callable()
var extra_reaction_immune_fn: Callable = Callable()


## Builds a trait per entry of [param specs] (each `{id: String, params: Dictionary}`; `params`
## optional) from the TraitRegistry and calls its setup() with [param ctx] (see BossTrait for the
## keys). Hooks are NOT called here: call [method on_match_start] once the wiring is done.
## [param p_install_hooks] MUST be false whenever more than one host exists at a time, and true otherwise.
## Multi-enemy Phase 5 (step 1): the five one-point hooks are single slots on SwingArbiter / StatusEffects /
## CombatState / PlacementController. With one host per enemy unit, every host would write the same slot, the last
## one constructed would silently win, and the earlier hosts' teardown would then no-op on its identity check —
## nothing errors, the wrong unit's answer is simply used. So CombatView passes false and installs one dispatcher
## per hook itself, routed by unit key. Single-host callers (tools/balance/sim_core.gd, tests that build a host by
## hand) keep the default and behave exactly as before.
func _init(ctx: Dictionary, specs: Array, seed_value: int, p_key: int = CombatState.Side.ENEMY,
		p_install_hooks: bool = true) -> void:
	_ctx = ctx
	_ctx["trait_host_ref"] = weakref(self)
	_ctx["key"] = p_key
	key = p_key
	_seed_value = seed_value
	_installed_hooks = p_install_hooks
	if p_install_hooks:
		# Story 036: the ONE untargetable point of the damage path (burrow). Callables do not keep the host alive.
		var arbiter: SwingArbiter = ctx.get("arbiter") as SwingArbiter
		if arbiter != null:
			arbiter.enemy_untargetable_fn = Callable(self, "_untargetable_keyed")
		# Story 039: the three one-point hooks (burn heal, boss would die, hit forecast).
		var status: StatusEffects = ctx.get("status") as StatusEffects
		if status != null:
			status.burn_heal_ratio_fn = Callable(self, "_burn_heal_ratio_keyed")
			# Phase 0 (bug G3): the reaction immunity hook was declared by StatusEffects but never bound by anyone.
			status.reaction_immune_fn = Callable(self, "reaction_immune")
		var combat_state: CombatState = ctx.get("state") as CombatState
		if combat_state != null:
			combat_state.enemy_death_hook_fn = Callable(self, "on_boss_would_die")
		var placement: PlacementController = ctx.get("placement") as PlacementController
		if placement != null:
			placement.forecast_blocked_fn = Callable(self, "hit_forecast_blocked")
	for entry: Variant in specs:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("TraitHost: a trait entry is not an object, skipped")
			continue
		var spec: Dictionary = entry as Dictionary
		var id: String = str(spec.get("id", ""))
		_create_and_setup(id, spec.get("params", {}))


## Story 023: adds a trait at runtime (phase_shift's extra_traits): created, set up with the
## match context and on_match_start called at once. Returns it, or null for an unknown id.
func add_trait(id: String, params: Dictionary = {}) -> BossTrait:
	var trait_instance: BossTrait = _create_and_setup(id, params)
	if trait_instance != null:
		trait_instance.on_match_start()
	return trait_instance


# Registry lookup + setup + append; the seed stride follows the creation index.
func _create_and_setup(id: String, raw_params: Variant) -> BossTrait:
	var trait_instance: BossTrait = TraitRegistry.create(id)
	if trait_instance == null:
		return null
	var params: Dictionary = {}
	if typeof(raw_params) == TYPE_DICTIONARY:
		params = raw_params as Dictionary
	else:
		push_warning("TraitHost: params of trait '%s' must be an object, using defaults" % id)
	var trait_seed: int = _seed_value + _next_index * BossTrait.SEED_STRIDE if _seed_value >= 0 else -1
	_next_index += 1
	trait_instance.setup(_ctx, params, trait_seed)
	_traits.append(trait_instance)
	return trait_instance


## The live traits in order (shallow copy; empty after [method teardown_all]).
func get_traits() -> Array[BossTrait]:
	return _traits.duplicate()


## The first live trait with [param id], or null.
func get_trait(id: String) -> BossTrait:
	for trait_instance: BossTrait in _traits:
		if trait_instance.get_id() == id:
			return trait_instance
	return null


## Number of live traits.
func size() -> int:
	return _traits.size()


## Ids of the live traits in order.
func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for trait_instance: BossTrait in _traits:
		ids.append(trait_instance.get_id())
	return ids


## Story 035: removes [param trait_instance] from the live list and tears it down (boss_phases ends a
## phase). Returns false when it is not live. Safe during a hook (the hooks below walk a snapshot).
func remove_trait(trait_instance: BossTrait) -> bool:
	if trait_instance == null or not _traits.has(trait_instance):
		return false
	_traits.erase(trait_instance)
	trait_instance.teardown()
	return true


## Forwards BossTrait.on_match_start (a snapshot: a trait added meanwhile already got its own call).
func on_match_start() -> void:
	for trait_instance: BossTrait in _traits.duplicate():
		if _traits.has(trait_instance):
			trait_instance.on_match_start()


## Forwards BossTrait.on_tick with the scaled [param step] (a snapshot; a trait removed meanwhile is skipped).
func on_tick(step: float) -> void:
	for trait_instance: BossTrait in _traits.duplicate():
		if _traits.has(trait_instance):
			trait_instance.on_tick(step)


## Forwards BossTrait.on_boss_swing_started.
func on_boss_swing_started(cells: Array[Vector2i], skill_id: String) -> void:
	for trait_instance: BossTrait in _traits:
		trait_instance.on_boss_swing_started(cells, skill_id)


## Forwards BossTrait.on_boss_swing_resolved.
func on_boss_swing_resolved(result: Dictionary) -> void:
	for trait_instance: BossTrait in _traits:
		trait_instance.on_boss_swing_resolved(result)


## Forwards BossTrait.on_player_swing_resolved.
func on_player_swing_resolved(result: Dictionary) -> void:
	for trait_instance: BossTrait in _traits:
		trait_instance.on_player_swing_resolved(result)


## Forwards BossTrait.on_point_spawned.
func on_point_spawned(side: int, point: FieldPoint) -> void:
	for trait_instance: BossTrait in _traits:
		trait_instance.on_point_spawned(side, point)


## Forwards BossTrait.on_player_stepped.
func on_player_stepped(from: Vector2i, to: Vector2i) -> void:
	for trait_instance: BossTrait in _traits:
		trait_instance.on_player_stepped(from, to)


## Emits [signal phase_changed] (called by phase_shift).
func announce_phase(phase: int) -> void:
	phase_changed.emit(phase)


## Forwards BossTrait.on_boss_damaged (ignored for amounts <= 0).
func on_boss_damaged(amount: float) -> void:
	if amount <= 0.0:
		return
	for trait_instance: BossTrait in _traits.duplicate():
		if _traits.has(trait_instance):
			trait_instance.on_boss_damaged(amount)


## DEV-ONLY (DemoArgs captures): appends an already set-up [param trait_instance] to the live
## list so the HUD and the hooks see it. Does not call setup() or on_match_start(); the caller
## does. Never used by the game itself (traits come from match_params through _init).
func debug_add_trait(trait_instance: BossTrait) -> void:
	if trait_instance == null:
		return
	_traits.append(trait_instance)


## Story 036: true while any live trait says the boss cannot be hit (BossTrait.untargetable(), burrow).
## SwingArbiter asks it for every player cast (a landing cast is then a miss that still leaves its zone).
# Phase 5 (step 1): the two hooks that gained a key argument. A single-host caller owns exactly one enemy unit, so
# it answers for whatever key it is asked about; the key only matters when several hosts exist, and then CombatView
# dispatches instead of these.
func _untargetable_keyed(_key: int) -> bool:
	return is_boss_untargetable()


func _burn_heal_ratio_keyed(_key: int) -> float:
	return burn_heal_ratio()


func is_boss_untargetable() -> bool:
	for trait_instance: BossTrait in _traits:
		if trait_instance.untargetable():
			return true
	return extra_untargetable_fn.is_valid() and bool(extra_untargetable_fn.call())


## Phase 0 (M15 immunity): true when the unit of [param side] is immune to reaction [param id] by a live trait
## (BossTrait.reaction_immune) or by [member extra_reaction_immune_fn] (a pattern enemy's `immune_reactions`).
## StatusEffects.reaction_immune_fn points here: the ONE place reaction immunity is decided.
func reaction_immune(side: int, id: String) -> bool:
	for trait_instance: BossTrait in _traits:
		if trait_instance.reaction_immune(side, id):
			return true
	return extra_reaction_immune_fn.is_valid() and bool(extra_reaction_immune_fn.call(side, id))


## Story 039: the largest burn-heal ratio of the live traits (burn_eater); 0 = burning hurts the boss as usual.
## StatusEffects.burn_heal_ratio_fn points here: the ONE place a burn tick on the boss asks.
func burn_heal_ratio() -> float:
	var best: float = 0.0
	for trait_instance: BossTrait in _traits:
		best = maxf(best, trait_instance.burn_heal_ratio())
	return best


## Story 039: true when a live trait (rebirth) takes the boss's death over. CombatState.enemy_death_hook_fn points here:
## the ONE place the death is decided (damage_enemy). The first trait that says true wins.
func on_boss_would_die() -> bool:
	for trait_instance: BossTrait in _traits.duplicate():
		if _traits.has(trait_instance) and trait_instance.on_boss_would_die():
			return true
	return false


## Story 039: true when a live trait (shroud) hides the placement preview's hit forecast. PlacementController.
## forecast_blocked_fn points here: the ONE place the forecast switch is read.
func hit_forecast_blocked() -> bool:
	for trait_instance: BossTrait in _traits:
		if trait_instance.hit_forecast_blocked():
			return true
	return extra_forecast_blocked_fn.is_valid() and bool(extra_forecast_blocked_fn.call())


## Tears every trait down and forgets them. Safe to call more than once.
func teardown_all() -> void:
	for trait_instance: BossTrait in _traits:
		trait_instance.teardown()
	_traits.clear()
	# Phase 5 (step 1): a host unbinds ONLY what it installed itself. A host that did not install (CombatView's
	# per-unit hosts) must not clear a slot the view owns, or the first unit to be torn down would silence the rest.
	if _installed_hooks:
		var arbiter: SwingArbiter = _ctx.get("arbiter") as SwingArbiter
		if arbiter != null and arbiter.enemy_untargetable_fn == Callable(self, "_untargetable_keyed"):
			arbiter.enemy_untargetable_fn = Callable()
		var status: StatusEffects = _ctx.get("status") as StatusEffects
		if status != null and status.burn_heal_ratio_fn == Callable(self, "_burn_heal_ratio_keyed"):
			status.burn_heal_ratio_fn = Callable()
		if status != null and status.reaction_immune_fn == Callable(self, "reaction_immune"):
			status.reaction_immune_fn = Callable()
		var combat_state: CombatState = _ctx.get("state") as CombatState
		if combat_state != null and combat_state.enemy_death_hook_fn == Callable(self, "on_boss_would_die"):
			combat_state.enemy_death_hook_fn = Callable()
		var placement: PlacementController = _ctx.get("placement") as PlacementController
		if placement != null and placement.forecast_blocked_fn == Callable(self, "hit_forecast_blocked"):
			placement.forecast_blocked_fn = Callable()
	extra_untargetable_fn = Callable()
	extra_forecast_blocked_fn = Callable()
	extra_reaction_immune_fn = Callable()
	_ctx = {}

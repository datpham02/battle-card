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

var _traits: Array[BossTrait] = []
var _ctx: Dictionary = {}
var _seed_value: int = -1
var _next_index: int = 0


## Builds a trait per entry of [param specs] (each `{id: String, params: Dictionary}`; `params`
## optional) from the TraitRegistry and calls its setup() with [param ctx] (see BossTrait for the
## keys). Hooks are NOT called here: call [method on_match_start] once the wiring is done.
func _init(ctx: Dictionary, specs: Array, seed_value: int) -> void:
	_ctx = ctx
	_ctx["trait_host_ref"] = weakref(self)
	_seed_value = seed_value
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


## Tears every trait down and forgets them. Safe to call more than once.
func teardown_all() -> void:
	for trait_instance: BossTrait in _traits:
		trait_instance.teardown()
	_traits.clear()
	_ctx = {}

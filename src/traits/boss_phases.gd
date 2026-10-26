class_name BossPhasesTrait
extends BossTrait
## Trait `boss_phases` (Story 035, the Ấn Đài final boss): a boss fought in PHASES, the general form of the
## Story 023 `phase_shift` trait (which stays as it is). Params: `{phases: Array}` where element 0 is phase 1
## (active from the start, no `at_hp_ratio`) and element i >= 1 starts when the boss HP ratio falls to its
## `at_hp_ratio` (strictly descending; an entry that is not lower than the previous one is skipped with a warning).
## Every field of a phase is optional and a missing field keeps the previous phase's value:
## `traits` ([{id, params}], added to the TraitHost; the previous phase's traits are torn down first),
## `brain_set` (BossBrain.use_set), `boss_step_cooldown_mult` (the boss mover's cooldown_mult = the value at
## match start x this, NOT compounded across phases), `boss_cards` (BossBrain.cards), `root_while_swinging`
## (BossController.set_root_while_swinging), `phase_shift_sec` (default: the top-level param `phase_shift_sec`,
## else [constant DEFAULT_PHASE_SHIFT_SEC]) and `name_key` (HUD banner, [method get_phase_name_key]).
## A phase change happens ONCE per threshold, in order (checked in on_tick and on_boss_damaged): the boss is
## invulnerable for phase_shift_sec (CombatState.enemy_invulnerable_left, ticked down here), its cast in progress
## is cancelled with no damage (CutActor.cancel, like a feint) and its decisions pause for the shift, the new
## phase is applied, then `host.announce_phase(n)` fires TraitHost.phase_changed(n). The player's formation,
## bag and field pieces are never touched. CombatState.enemy_hp_floor is kept at the NEXT threshold's HP
## (0 after the last phase), so a single big hit is clamped there and no phase can be skipped.
## No RNG use. Implements: Story 035 (Part B, Part F "final_boss_phase_test").

## A new phase began (2 = the first change).
signal phase_entered(phase: int)

const ID: String = "boss_phases"
## Fallback invulnerable seconds of a phase change (chapters.json phases[i].phase_shift_sec).
const DEFAULT_PHASE_SHIFT_SEC: float = 1.0
## HP tolerance of the threshold test (the clamp lands exactly on ratio x max HP).
const _HP_EPS: float = 0.0001

## Cleaned phases: each a copy of the data entry with float `at_hp_ratio` (1.0 for phase 1) and `phase_shift_sec`.
var _phases: Array[Dictionary] = []
var _index: int = 0
var _phase_traits: Array[BossTrait] = []
var _base_cooldown_mult: float = 1.0
var _frozen: bool = false
var _name_key: String = ""


func get_id() -> String:
	return ID


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_phases = []
	var default_shift: float = maxf(param_float("phase_shift_sec", DEFAULT_PHASE_SHIFT_SEC), 0.0)
	var raw: Variant = _params.get("phases", [])
	if typeof(raw) != TYPE_ARRAY:
		push_warning("BossPhasesTrait: param phases must be an array, no phases")
		return
	var last_ratio: float = 1.0 + _HP_EPS
	for entry: Variant in raw as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("BossPhasesTrait: a phase entry is not an object, skipped")
			continue
		var phase: Dictionary = (entry as Dictionary).duplicate(true)
		if _phases.is_empty():
			phase["at_hp_ratio"] = 1.0
		else:
			var at: Variant = phase.get("at_hp_ratio")
			if typeof(at) != TYPE_FLOAT and typeof(at) != TYPE_INT:
				push_warning("BossPhasesTrait: phase %d has no at_hp_ratio, skipped" % (_phases.size() + 1))
				continue
			var ratio: float = clampf(float(at), 0.0, 1.0)
			if ratio >= last_ratio:
				push_warning("BossPhasesTrait: at_hp_ratio %.3f is not below the previous phase, skipped" % ratio)
				continue
			phase["at_hp_ratio"] = ratio
		last_ratio = float(phase["at_hp_ratio"])
		var shift: Variant = phase.get("phase_shift_sec")
		phase["phase_shift_sec"] = maxf(float(shift), 0.0) if (typeof(shift) == TYPE_FLOAT or typeof(shift) == TYPE_INT) else default_shift
		_phases.append(phase)


func on_match_start() -> void:
	_index = 0
	_frozen = false
	_name_key = ""
	_phase_traits = []
	var boss: BossController = _boss()
	if boss != null:
		_base_cooldown_mult = boss.get_mover().cooldown_mult
	if not _phases.is_empty():
		_apply(_phases[0])
	_update_floor()


func on_tick(step: float) -> void:
	var state: CombatState = _state()
	if state == null:
		return
	if state.enemy_invulnerable_left > 0.0:
		state.enemy_invulnerable_left = maxf(state.enemy_invulnerable_left - step, 0.0)
		if state.enemy_invulnerable_left > 0.0:
			return
	_unfreeze()
	_check()


func on_boss_damaged(_amount: float) -> void:
	_check()


## Current phase, 1-based (1 = data element 0).
func get_phase() -> int:
	return _index + 1


## Number of usable phases in the params (0 when none).
func get_phase_count() -> int:
	return _phases.size()


## Translation key of the current phase's name (`name_key` of the latest phase that had one; "" when none).
func get_phase_name_key() -> String:
	return _name_key


## True while the boss is invulnerable after a phase change.
func is_invulnerable() -> bool:
	var state: CombatState = _state()
	return state != null and state.enemy_invulnerable_left > 0.0


## Traits added by the current phase (live in the host).
func get_phase_traits() -> Array[BossTrait]:
	return _phase_traits.duplicate()


func get_debug() -> Dictionary:
	return {"id": ID, "phase": get_phase(), "phases": _phases.size(), "invulnerable": is_invulnerable()}


func teardown() -> void:
	_unfreeze()
	_phase_traits = []
	_phases = []
	super()


func _state() -> CombatState:
	return get_context().get("state") as CombatState


func _boss() -> BossController:
	return get_context().get("boss") as BossController


# Enters the next phase when the HP is at or below its threshold (never during a shift).
func _check() -> void:
	var state: CombatState = _state()
	if state == null or state.enemy_max_hp <= 0.0 or state.enemy_invulnerable_left > 0.0 or state.is_enemy_dead():
		return
	var next: int = _index + 1
	if next >= _phases.size():
		return
	if state.enemy_hp > float(_phases[next]["at_hp_ratio"]) * state.enemy_max_hp + _HP_EPS:
		return
	_enter(next)


func _enter(index: int) -> void:
	_index = index
	var phase: Dictionary = _phases[index]
	var state: CombatState = _state()
	var shift: float = float(phase["phase_shift_sec"])
	state.enemy_invulnerable_left = shift
	var boss: BossController = _boss()
	if boss != null:
		# The cast in progress (and a queued combo) is dropped with no damage, like a feint.
		boss.get_actor().cancel()
		if shift > 0.0 and boss.is_active():
			boss.set_active(false)
			_frozen = true
	_apply(phase)
	_update_floor()
	var host: TraitHost = get_host()
	if host != null:
		host.announce_phase(get_phase())
	phase_entered.emit(get_phase())


# Applies the fields [param phase] declares; absent fields keep the previous phase's value.
func _apply(phase: Dictionary) -> void:
	var boss: BossController = _boss()
	var host: TraitHost = get_host()
	if phase.has("traits") and typeof(phase["traits"]) == TYPE_ARRAY and host != null:
		for old: BossTrait in _phase_traits:
			host.remove_trait(old)
		_phase_traits = []
		for entry: Variant in phase["traits"] as Array:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var spec: Dictionary = entry as Dictionary
			var id: String = str(spec.get("id", ""))
			if id == ID:
				push_warning("BossPhasesTrait: a phase cannot add boss_phases itself, skipped")
				continue
			var raw_params: Variant = spec.get("params", {})
			var added: BossTrait = host.add_trait(id, (raw_params as Dictionary) if typeof(raw_params) == TYPE_DICTIONARY else {})
			if added != null:
				_phase_traits.append(added)
	if phase.has("name_key"):
		_name_key = str(phase["name_key"])
	if boss == null:
		return
	if phase.has("brain_set"):
		var set_name: String = str(phase["brain_set"])
		if not boss.get_brain().use_set(set_name):
			push_warning("BossPhasesTrait: unknown brain_set '%s'" % set_name)
	var mult: Variant = phase.get("boss_step_cooldown_mult")
	if typeof(mult) == TYPE_FLOAT or typeof(mult) == TYPE_INT:
		boss.get_mover().cooldown_mult = _base_cooldown_mult * maxf(float(mult), 0.01)
	var cards: Variant = phase.get("boss_cards")
	if typeof(cards) == TYPE_ARRAY and not (cards as Array).is_empty():
		var ids: Array[String] = []
		for card: Variant in cards as Array:
			if not str(card).is_empty():
				ids.append(str(card))
		if not ids.is_empty():
			boss.get_brain().cards = ids
	var root: Variant = phase.get("root_while_swinging")
	if typeof(root) == TYPE_BOOL:
		boss.set_root_while_swinging(bool(root))


# HP floor = the next phase's threshold HP (0 after the last phase).
func _update_floor() -> void:
	var state: CombatState = _state()
	if state == null:
		return
	var next: int = _index + 1
	state.enemy_hp_floor = float(_phases[next]["at_hp_ratio"]) * state.enemy_max_hp if next < _phases.size() else 0.0


func _unfreeze() -> void:
	if not _frozen:
		return
	_frozen = false
	var boss: BossController = _boss()
	if boss != null:
		boss.set_active(true)

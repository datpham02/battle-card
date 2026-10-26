class_name PhaseShiftTrait
extends BossTrait
## Trait `phase_shift` (OSFE boss phases): when the boss HP ratio first falls to `at_hp_ratio` or
## below it enters phase 2, once: the brain's weight set switches to `brain_set`
## (BossBrain.use_set), the boss's step cooldown is multiplied by `step_mult`, and every entry of
## `extra_traits` ([{id, params}]) is added to the TraitHost at runtime. The host emits
## `phase_changed(2)` (HUD banner).
## Params (fallbacks below): `at_hp_ratio`, `brain_set`, `extra_traits`, `step_mult`, `vent_interval_mult` (Story 039:
## > 0 and != 1 multiplies the lava vents' interval through TileHazards.set_vent_interval_mult on entering phase 2;
## absent = untouched).
## HUD: [method get_phase] (1 then 2).
## Implements: Story 023 (Part B).

## Phase 2 began.
signal phase_entered(phase: int)

const ID: String = "phase_shift"
const DEFAULT_AT_HP_RATIO: float = 0.5
const DEFAULT_BRAIN_SET: String = "aggressive"
const DEFAULT_STEP_MULT: float = 0.85
## Fallback of `extra_traits` when the param is absent.
const DEFAULT_EXTRA_TRAITS: Array = [{"id": "row_burner", "params": {}}]

var _at_ratio: float = DEFAULT_AT_HP_RATIO
var _brain_set: String = DEFAULT_BRAIN_SET
var _step_mult: float = DEFAULT_STEP_MULT
var _extra: Array = DEFAULT_EXTRA_TRAITS
var _vent_interval_mult: float = 1.0
var _phase: int = 1


func get_id() -> String:
	return ID


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_at_ratio = clampf(param_float("at_hp_ratio", DEFAULT_AT_HP_RATIO), 0.0, 1.0)
	_brain_set = param_string("brain_set", DEFAULT_BRAIN_SET)
	_step_mult = maxf(param_float("step_mult", DEFAULT_STEP_MULT), 0.01)
	_vent_interval_mult = param_float("vent_interval_mult", 1.0)
	var raw: Variant = _params.get("extra_traits", DEFAULT_EXTRA_TRAITS)
	_extra = raw as Array if typeof(raw) == TYPE_ARRAY else DEFAULT_EXTRA_TRAITS


func on_match_start() -> void:
	_phase = 1


func on_tick(_step: float) -> void:
	_check()


func on_boss_damaged(_amount: float) -> void:
	_check()


## Current phase: 1, then 2 once the threshold was crossed.
func get_phase() -> int:
	return _phase


func get_debug() -> Dictionary:
	return {"id": ID, "phase": _phase}


func _check() -> void:
	if _phase >= 2:
		return
	var state: CombatState = get_context().get("state") as CombatState
	if state == null or state.enemy_max_hp <= 0.0 or state.enemy_hp / state.enemy_max_hp > _at_ratio:
		return
	_phase = 2
	var boss: BossController = get_context().get("boss") as BossController
	if boss != null:
		if not boss.get_brain().use_set(_brain_set):
			push_warning("PhaseShiftTrait: unknown brain_set '%s'" % _brain_set)
		boss.get_mover().cooldown_mult *= _step_mult
	if _vent_interval_mult > 0.0 and not is_equal_approx(_vent_interval_mult, 1.0):
		apply_vent_interval_mult(_vent_interval_mult)
	var host: TraitHost = get_host()
	if host != null:
		for entry: Variant in _extra:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var spec: Dictionary = entry as Dictionary
			var raw_params: Variant = spec.get("params", {})
			host.add_trait(str(spec.get("id", "")), (raw_params as Dictionary) if typeof(raw_params) == TYPE_DICTIONARY else {})
		host.announce_phase(_phase)
	phase_entered.emit(_phase)

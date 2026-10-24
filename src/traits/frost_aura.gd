class_name FrostAuraTrait
extends BossTrait
## Trait `frost_aura`: while the boss's HP ratio is above `until_hp_ratio`, the player's rune drop
## RATE is scaled by `rune_rate_mult` (FieldDrops.interval_scale = 1 / mult, so 0.8 = a 25 %
## longer spawn interval). At or below the ratio it switches off permanently.
## Params (fallbacks below): `rune_rate_mult`, `until_hp_ratio`. HUD: [method is_active].
## Implements: Story 023 (Part B).

## The aura switched off (boss HP fell to the threshold).
signal aura_ended

const ID: String = "frost_aura"
const DEFAULT_RUNE_RATE_MULT: float = 0.8
const DEFAULT_UNTIL_HP_RATIO: float = 0.5

var _rate_mult: float = DEFAULT_RUNE_RATE_MULT
var _until_ratio: float = DEFAULT_UNTIL_HP_RATIO
var _active: bool = false
var _drops: FieldDrops = null


func get_id() -> String:
	return ID


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_rate_mult = clampf(param_float("rune_rate_mult", DEFAULT_RUNE_RATE_MULT), 0.01, 1.0)
	_until_ratio = clampf(param_float("until_hp_ratio", DEFAULT_UNTIL_HP_RATIO), 0.0, 1.0)


func on_match_start() -> void:
	_drops = get_context().get("player_drops") as FieldDrops
	_active = _drops != null and _ratio() > _until_ratio
	if _active:
		_drops.interval_scale = 1.0 / _rate_mult


func on_tick(_step: float) -> void:
	_check()


func on_boss_damaged(_amount: float) -> void:
	_check()


## True while the aura slows the player's runes.
func is_active() -> bool:
	return _active


## Rune rate multiplier while active.
func get_rune_rate_mult() -> float:
	return _rate_mult


func get_debug() -> Dictionary:
	return {"id": ID, "active": _active, "rune_rate_mult": _rate_mult}


func teardown() -> void:
	_release()
	_drops = null
	super()


func _check() -> void:
	if _active and _ratio() <= _until_ratio:
		_release()
		aura_ended.emit()


func _release() -> void:
	if _active and _drops != null:
		_drops.interval_scale = 1.0
	_active = false


func _ratio() -> float:
	var state: CombatState = get_context().get("state") as CombatState
	if state == null or state.enemy_max_hp <= 0.0:
		return 1.0
	return state.enemy_hp / state.enemy_max_hp

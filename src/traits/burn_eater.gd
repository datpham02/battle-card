class_name BurnEaterTrait
extends BossTrait
## Trait `burn_eater` (Story 039 Part B, Quy Nuot Lua / fire_eater): burning cells (Dot from the player's cards, the
## player's own burning cells AND the lava vents', all of them are StatusEffects burning cells) HEAL the boss by the
## damage a tick would deal times `heal_ratio`, instead of hurting it. The change lives at the ONE place a burn tick
## reaches the boss (StatusEffects.burn_heal_ratio_fn -> TraitHost.burn_heal_ratio -> [method burn_heal_ratio]); the
## heal itself goes through CombatState.heal_enemy, which emits `enemy_healed(amount)` (the HUD's green number); this
## trait also emits [signal healed] per tick and keeps [method get_heal_total].
## Params (match trait entry): `heal_ratio` (default 1.0).
## HUD: [method heals_from_burn], [method get_heal_total], [method get_last_heal].
## Implements: Story 039 (Part B).

## A burn tick healed the boss by [param amount] HP (the HP actually gained, after the max-HP clamp).
signal healed(amount: float)

const ID: String = "burn_eater"
const DEFAULT_HEAL_RATIO: float = 1.0

var _heal_ratio: float = DEFAULT_HEAL_RATIO
var _heal_total: float = 0.0
var _last_heal: float = 0.0
var _heal_count: int = 0
var _status: StatusEffects = null


func get_id() -> String:
	return ID


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_heal_ratio = maxf(param_float("heal_ratio", DEFAULT_HEAL_RATIO), 0.0)


func on_match_start() -> void:
	_heal_total = 0.0
	_last_heal = 0.0
	_heal_count = 0
	_status = get_context().get("status") as StatusEffects
	if _status != null and not _status.burn_healed.is_connected(_on_burn_healed):
		_status.burn_healed.connect(_on_burn_healed)


## The hook: burning heals the boss by tick damage x this ratio (0 would mean normal damage).
func burn_heal_ratio() -> float:
	return _heal_ratio


## True while this trait turns burning into healing (the match description says so).
func heals_from_burn() -> bool:
	return _heal_ratio > 0.0


## HP healed from burning so far this match.
func get_heal_total() -> float:
	return _heal_total


## HP the last burn tick healed (0 before the first).
func get_last_heal() -> float:
	return _last_heal


## Burn ticks that healed so far.
func get_heal_count() -> int:
	return _heal_count


func get_debug() -> Dictionary:
	return {"id": ID, "heal_ratio": _heal_ratio, "heal_total": _heal_total, "heals": _heal_count}


func teardown() -> void:
	if _status != null and _status.burn_healed.is_connected(_on_burn_healed):
		_status.burn_healed.disconnect(_on_burn_healed)
	_status = null
	super()


func _on_burn_healed(_side: int, amount: float) -> void:
	_last_heal = amount
	_heal_total += amount
	_heal_count += 1
	healed.emit(amount)

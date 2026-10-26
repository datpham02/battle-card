class_name HuyetAn
extends BaseRelic
## Huyet An (Story 032, tag `negative`): a cast over `min_cells` or more cells deals `mult` times
## the damage; such a cast that MISSES the boss (`cast_info.hit` false in [method on_cast_landed])
## costs the player `self_damage` HP. A hit costs nothing and smaller casts are never affected.
## params `{min_cells, mult, self_damage}`.
## ctx keys: `damage_player` Callable(amount: float) -> Variant (hurts the player through
## CombatState; may kill). Missing key: no self damage. Emits `triggered` when it multiplies a
## cast and when it hurts. Implements: Story 032; rework 2026-10-26 (user decision: HP is lost
## only on a miss; the Story 032 rule charged every cast and simulated as a trap).

var _min_cells: int = 0
var _mult: float = 1.0
var _self_damage: float = 0.0


func _init() -> void:
	_relic_id = "huyet_an"


func setup(ctx: Dictionary, params: Dictionary) -> void:
	super.setup(ctx, params)
	_min_cells = param_int("min_cells", 0)
	_mult = param_float("mult", 1.0)
	_self_damage = param_float("self_damage", 0.0)


## `damage` x mult for a cast of `min_cells` or more cells.
func modify_cast_damage(cast_info: Dictionary, damage: float) -> float:
	if int(cast_info.get("cells", 0)) >= _min_cells and _mult != 1.0:
		triggered.emit(get_id())
		return damage * _mult
	return damage


## The blood price of a missed big cast: `self_damage` HP when a cast of `min_cells`+ cells did
## not hit the boss. CombatView and the balance sim (SimCore) both call this once per resolved
## player swing with `hit` and `cells` filled from the swing result.
func on_cast_landed(cast_info: Dictionary) -> void:
	if _self_damage <= 0.0 or not _ctx.has("damage_player"):
		return
	if bool(cast_info.get("hit", false)) or int(cast_info.get("cells", 0)) < _min_cells:
		return
	_call_ctx("damage_player", [_self_damage])
	triggered.emit(get_id())

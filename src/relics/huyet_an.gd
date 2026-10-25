class_name HuyetAn
extends BaseRelic
## Huyet An (Story 032, tag `negative`): a cast over `min_cells` or more cells deals `mult` times
## the damage; EVERY player cast costs `self_damage` HP. params `{min_cells, mult, self_damage}`.
## ctx keys: `damage_player` Callable(amount: float) -> Variant (hurts the player through
## CombatState; may kill). Missing key: no self damage. Emits `triggered` when it multiplies a
## cast and when it hurts. Implements: Story 032.

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


## The blood price of every cast, hit or miss.
func on_cast_landed(_cast_info: Dictionary) -> void:
	if _self_damage <= 0.0 or not _ctx.has("damage_player"):
		return
	_call_ctx("damage_player", [_self_damage])
	triggered.emit(get_id())

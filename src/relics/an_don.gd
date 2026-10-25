class_name AnDon
extends BaseRelic
## An Don (Story 032): a cast made of exactly one `mono` piece deals `mult` times the damage.
## params `{mult}`. ctx keys: none. Emits `triggered` when it multiplies a cast.
## Implements: Story 032.

const MONO_ID: String = "mono"

var _mult: float = 1.0


func _init() -> void:
	_relic_id = "an_don"


func setup(ctx: Dictionary, params: Dictionary) -> void:
	super.setup(ctx, params)
	_mult = param_float("mult", 1.0)


## `damage` x mult when the cast is a lone mono piece.
func modify_cast_damage(cast_info: Dictionary, damage: float) -> float:
	var pieces: Array = cast_info.get("pieces", [])
	if pieces.size() == 1 and str(pieces[0]) == MONO_ID and _mult != 1.0:
		triggered.emit(get_id())
		return damage * _mult
	return damage

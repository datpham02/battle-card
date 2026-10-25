class_name PhanDon
extends BaseRelic
## Phan Don (Story 032): interrupting a boss spell puts one piece of `shape` into the player's
## bag at once (if there is room). params `{shape}`. ctx keys: `give_piece` Callable(shape_id:
## String) -> bool (true when a piece was placed; false when the bag is full). Missing key: nothing.
## Emits `triggered` only when a piece was given. Implements: Story 032.

var _shape: String = "mono"


func _init() -> void:
	_relic_id = "phan_don"


func setup(ctx: Dictionary, params: Dictionary) -> void:
	super.setup(ctx, params)
	_shape = param_string("shape", "mono")


func on_interrupt_by_player() -> void:
	var given: Variant = _call_ctx("give_piece", [_shape])
	if typeof(given) == TYPE_BOOL and given:
		triggered.emit(get_id())

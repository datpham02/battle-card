class_name HandInputController
extends Node2D
## Tap on an occupied hand slot = select / deselect its point (Story 007; cutting comes in
## Story 008). A tap is press + release inside the same occupied slot with the pointer
## moving no more than hold_slots.json tap_threshold_px. Input only; selection lives in
## HoldSlots. Uses _unhandled_input so the d-pad (handled in _input) always wins.
## Mouse events only: with emulate_mouse_from_touch a touch also arrives as a mouse event,
## so one path serves mouse and touch without double-handling.

@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")

var _slots_view: HoldSlotsView
var _press_slot: int = -1
var _press_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_slots_view = get_node(hold_slots_view_path) as HoldSlotsView
	assert(_slots_view != null, "HandInputController: hold slots view path not set")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_slot = _slots_view.occupied_slot_at(button.position)
		_press_pos = button.position
		if _press_slot != -1:
			get_viewport().set_input_as_handled()
	elif _press_slot != -1:
		var slot: int = _press_slot
		_press_slot = -1
		var within: bool = button.position.distance_to(_press_pos) <= _slots_view.get_config().tap_threshold_px
		if within and _slots_view.occupied_slot_at(button.position) == slot:
			_slots_view.get_slots().toggle_selected(slot)
		get_viewport().set_input_as_handled()

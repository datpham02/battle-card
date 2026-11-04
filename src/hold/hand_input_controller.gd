class_name HandInputController
extends Node2D
## Pointer input on the player's piece bag (Story 024, touch-first).
## DRAG (main gesture): press a piece in the bag and move past hold_slots.json tap_threshold_px; the
## piece is picked up, the ghost floats drag_lift_px above the finger and snaps to the enemy half;
## RELEASING with the ghost on the enemy half commits the piece (the place window starts; the card menu opens on
## Tung phép), releasing anywhere else puts the piece back. TAP (fallback): tapping a slot selects it (PLACING) and tapping the selected
## slot again rotates it; tapping an enemy cell / the ghost / the confirm button is CutHudView's job.
## Story 028: in the place window (before Tung phép) the same drag places the cast's SECOND piece (CombatView joins it).
## 2026-11-04 (user: placed blocks must stay adjustable): in the place window a press on a PLACED piece on the board
## lifts it off the cast (CombatView.lift_placed_piece): a drag carries it like a bag piece, a tap lifts it in place
## (Xoay rotates it, a tapped cell moves it, a tap on the ghost puts it back).
## Multi-touch: every pointer is tracked by id (the touch index; -1 for the mouse), and ONLY the
## pointer that started the drag moves or releases it, so the left thumb can press the ROTATE button
## (another touch index) while the right finger keeps dragging. A real mouse and a real touch both
## work; mouse events emulated from a touch (device == DEVICE_ID_EMULATION) are ignored because the
## touch event itself is handled. Nothing here depends on mouse hover.
## Input only; the logic lives in CombatView / PlacementController. Uses _unhandled_input so the
## HUD buttons (handled in _input) always win.

const MOUSE_ID: int = -1

@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")

## Selection is ignored while the skill menu is open (Story 008).
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _slots_view: HoldSlotsView
var _combat: CombatView
## The pointer (touch index / MOUSE_ID) that pressed a slot, -2 = none, where and on which slot.
var _press_id: int = -2
var _press_slot: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
## Index (in the cast plan) of the placed piece the press landed on; -1 = the press is on a bag slot.
var _press_placed: int = -1


func _ready() -> void:
	_slots_view = get_node(hold_slots_view_path) as HoldSlotsView
	assert(_slots_view != null, "HandInputController: hold slots view path not set")
	_combat = get_node_or_null(combat_view_path) as CombatView


func _unhandled_input(event: InputEvent) -> void:
	if _combat != null and _combat.get_cut_flow() != null and (_combat.get_cut_flow().is_menu_open()
			or (_combat.is_placed() and not _combat.can_join_piece() and _press_placed < 0
				and not _presses_placed_piece(event))):
		# 2026-11-01: the bag is ignored while the card menu is open; in the place window (pieces placed, Tung phép
		# not pressed yet) it stays live for the cast's next piece until the cast is full.
		_reset()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_down(touch.index, touch.position)
		else:
			_up(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(drag.index, drag.position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT or button.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if button.pressed:
			_down(MOUSE_ID, button.position)
		else:
			_up(MOUSE_ID, button.position)
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).device != InputEvent.DEVICE_ID_EMULATION:
			_move(MOUSE_ID, (event as InputEventMouseMotion).position)


# --- Pointer handlers (public so a test can drive them without synthesising events) -------------


## A pointer pressed at [param pos]: remembers a press that lands on an occupied slot.
func pointer_down(id: int, pos: Vector2) -> void:
	_down(id, pos)


## A pointer moved to [param pos]: past the tap threshold a press that started on a slot becomes a drag.
func pointer_move(id: int, pos: Vector2) -> void:
	_move(id, pos)


## A pointer lifted at [param pos]: ends a drag (confirm over the enemy half, else the piece goes
## back) or counts as a tap on the slot it pressed.
func pointer_up(id: int, pos: Vector2) -> void:
	_up(id, pos)


func _down(id: int, pos: Vector2) -> void:
	if _press_id != -2:
		# One drag at a time; other fingers belong to the HUD buttons. Story 028: a SECOND finger tapping the
		# slot of the piece being dragged rotates it (like the Xoay button), the drag itself stays alive.
		if _dragging and id != _press_id and _combat != null and _slots_view.occupied_slot_at(pos) == _press_slot:
			_combat.rotate_piece()
			get_viewport().set_input_as_handled()
		return
	var slot: int = _slots_view.occupied_slot_at(pos)
	var placed: int = -1
	if slot == -1 and _combat != null:
		placed = _combat.placed_piece_at_screen(pos)
	if slot == -1 and placed < 0:
		return
	_press_id = id
	_press_slot = slot
	_press_placed = placed
	_press_pos = pos
	_dragging = false
	get_viewport().set_input_as_handled()


func _move(id: int, pos: Vector2) -> void:
	if id != _press_id or _combat == null:
		return
	if not _dragging:
		if pos.distance_to(_press_pos) <= _slots_view.get_config().tap_threshold_px:
			return
		if _press_placed >= 0:
			# Carry a placed piece: lift it (back to its bag slot, selected), then drag it from there.
			if not _combat.lift_placed_piece(_press_placed):
				_reset()
				return
			_press_slot = _combat.get_placement().get_slot()
			_press_placed = -1
		if not _combat.begin_drag(_press_slot, pos):
			_reset()
			return
		_dragging = true
	_combat.drag_to(pos)


func _up(id: int, pos: Vector2) -> void:
	if id != _press_id:
		return
	var slot: int = _press_slot
	var placed: int = _press_placed
	var was_dragging: bool = _dragging
	var started: Vector2 = _press_pos
	_reset()
	if _combat == null:
		return
	if placed >= 0:
		# Tap on a placed piece: lift it in place (ghost on the same cells) to rotate / move / put back.
		if pos.distance_to(started) <= _slots_view.get_config().tap_threshold_px:
			_combat.lift_placed_piece(placed)
		get_viewport().set_input_as_handled()
		return
	if was_dragging:
		_combat.end_drag(pos)
	elif pos.distance_to(started) <= _slots_view.get_config().tap_threshold_px \
			and _slots_view.occupied_slot_at(pos) == slot:
		_combat.select_piece(slot, true)
	get_viewport().set_input_as_handled()


func _reset() -> void:
	_press_id = -2
	_press_slot = -1
	_press_placed = -1
	_dragging = false


# True when [param event] is a press landing on a placed piece of the cast (place window), which stays live even when
# the cast is full and no bag piece may join.
func _presses_placed_piece(event: InputEvent) -> bool:
	if _combat == null:
		return false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		return _combat.placed_piece_at_screen((event as InputEventScreenTouch).position) >= 0
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		return _combat.placed_piece_at_screen((event as InputEventMouseButton).position) >= 0
	return false

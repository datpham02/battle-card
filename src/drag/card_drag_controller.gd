class_name CardDragController
extends Node2D
## Press-and-drag of belt cards into hold slots (Story 002) and use of slotted cards on
## the board (Stories 003, 006). Input only; rules live elsewhere (ConveyorBelt owns
## card positions, HoldSlots owns slot occupancy, CardPlayer owns play/recovery rules).
##
## State machine: IDLE --press on a belt card or a slotted card--> DRAGGING --release--> IDLE.
## Belt card: released over a free slot it moves belt -> slot; anywhere else (or when every
## slot is full) it is handed back and resumes from its true belt position.
## Slot card, MOVE type (Step): the card is dragged; released over a board cell ADJACENT to
## the player (own half) while CardPlayer.can_play it steps there; valid cells are
## highlighted while dragging; anywhere else it snaps back to its slot.
## Slot card, other types (attack / shield): TAP-TO-USE. Press and release without moving
## beyond hold_slots.json tap_threshold_px uses it. While pressed, an attack card previews
## its shape on the board, but only while CardPlayer.can_play is true (no preview during
## recovery or once a unit is dead). If the pointer moves beyond the threshold the card
## follows it; releasing back over its own slot uses it, releasing anywhere else cancels
## (the card stays in its slot) and the preview is hidden as soon as the pointer leaves
## the slot rect, so the cancel is visible before release.
## A drag whose node was freed, or whose slot card changed underneath it, is aborted
## cleanly (state cleared, highlights/preview removed) on the next input or update.
##
## Input: mouse events only. With the project default
## input_devices/pointing/emulate_mouse_from_touch = true (verified in the 4.6.3 class
## reference), a touch also arrives as InputEventMouseButton/Motion, so this one path
## serves desktop mouse and phone touch without double-handling. Nothing uses hover.
## Event positions are taken as viewport (canvas) coordinates; views must sit at the
## canvas origin or the global-position maths still holds because both sides use global.

## Emitted when a drag begins on card [param uid].
signal card_drag_started(uid: int)
## Emitted when card [param uid] was dropped into slot [param slot_index].
signal card_placed(uid: int, slot_index: int)
## Emitted when card [param uid] went back to the belt (invalid drop, full, or cancelled).
signal card_returned(uid: int)
## Emitted when the card in slot [param slot_index] was played.
signal card_played(type_id: String, slot_index: int)
## Emitted when a slot card was released without being played (it stays in its slot).
signal slot_card_returned(slot_index: int)

@export var conveyor_view_path: NodePath = NodePath("../ConveyorView")
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _conveyor: ConveyorView
var _slots_view: HoldSlotsView
var _combat: CombatView
var _drag_slot: int = -1 # >= 0 while a slotted card is pressed/dragged
var _drag_uid: int = -1
var _drag_node: Control = null
var _grab_offset: Vector2 = Vector2.ZERO
var _press_pos: Vector2 = Vector2.ZERO
var _pointer: Vector2 = Vector2.ZERO
var _moved: bool = false # slot card: pointer travelled beyond the tap threshold
var _drag_card_uid: int = 0 # slot card: uid of the card held when the press began


func _ready() -> void:
	_conveyor = get_node(conveyor_view_path) as ConveyorView
	_slots_view = get_node(hold_slots_view_path) as HoldSlotsView
	_combat = get_node(combat_view_path) as CombatView
	assert(
		_conveyor != null and _slots_view != null and _combat != null,
		"CardDragController: view paths not set"
	)


func _unhandled_input(event: InputEvent) -> void:
	_abort_if_stale()
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			if not is_dragging():
				var uid: int = _conveyor.pick_card_at(
					button.position, _slots_view.get_config().drag_pick_padding_px
				)
				if uid != -1 and start_drag(uid, button.position):
					get_viewport().set_input_as_handled()
				else:
					var slot: int = _slots_view.occupied_slot_at(button.position)
					if slot != -1 and start_slot_drag(slot, button.position):
						get_viewport().set_input_as_handled()
		elif is_dragging():
			update_drag(button.position)
			finish_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_dragging():
		update_drag((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Losing window focus mid-drag must not strand a card in the air.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_dragging():
		cancel_drag()


## True while a card is being dragged or a slot card is pressed (and its node still exists).
func is_dragging() -> bool:
	return _drag_node != null and is_instance_valid(_drag_node)


## Begins dragging card [param uid] with the pointer at [param pointer]. The card keeps
## its offset under the pointer and is lifted by the configured lift. Returns false if
## the card is not on the belt or a drag is already active.
func start_drag(uid: int, pointer: Vector2) -> bool:
	if is_dragging():
		return false
	var node: Control = _conveyor.begin_card_drag(uid)
	if node == null:
		return false
	_drag_uid = uid
	_drag_node = node
	_grab_offset = pointer - node.global_position
	update_drag(pointer)
	card_drag_started.emit(uid)
	return true


## Presses the card held in slot [param slot_index]. A move card follows the pointer at
## once; any other card stays put until the pointer passes the tap threshold, and an
## attack card shows its shape preview. Returns false if the slot is empty or a drag is
## active. The card stays registered in the slot until it is actually played.
func start_slot_drag(slot_index: int, pointer: Vector2) -> bool:
	if is_dragging():
		return false
	var node: Control = _slots_view.get_slot_node(slot_index)
	if node == null:
		return false
	var card: ConveyorCard = _slots_view.get_slots().get_card(slot_index)
	_drag_slot = slot_index
	_drag_card_uid = card.uid if card != null else 0
	_drag_node = node
	_grab_offset = pointer - node.global_position
	_press_pos = pointer
	_pointer = pointer
	_moved = false
	update_drag(pointer)
	return true


## Plays the card in slot [param slot_index] if the rules allow (no recovery, enemy alive,
## valid step cell): applies its effect, empties the slot. Returns false and changes
## nothing otherwise. Used by tap/drop and by dev capture code.
## [param target_cell] is the destination for move cards (ignored by others).
func play_slot_card(slot_index: int, target_cell: Vector2i = CardPlayer.NO_CELL) -> bool:
	var card: ConveyorCard = _slots_view.get_slots().get_card(slot_index)
	if card == null or not _combat.get_player().play(card.type_id, target_cell):
		return false
	_slots_view.remove_card(slot_index)
	card_played.emit(card.type_id, slot_index)
	return true


## Moves the dragged card to follow [param pointer] and updates highlights/preview.
func update_drag(pointer: Vector2) -> void:
	_abort_if_stale()
	if not is_dragging():
		return
	_pointer = pointer
	var cfg: HoldSlotsConfig = _slots_view.get_config()
	if _drag_slot != -1:
		if pointer.distance_to(_press_pos) > cfg.tap_threshold_px:
			_moved = true
		if _moved or _is_move_card():
			_drag_node.z_index = 10
			_drag_node.global_position = pointer - _grab_offset - Vector2(0.0, cfg.drag_lift_px)
		_update_slot_feedback()
		return
	_drag_node.global_position = pointer - _grab_offset - Vector2(0.0, cfg.drag_lift_px)
	var index: int = _target_slot()
	_slots_view.set_drop_highlight(index if _can_drop_on(index) else -1)


## Ends the drag at the current position: a belt card is placed in a free slot under it
## (else returned to the belt); a slot card is used or cancelled per the rules above.
## Returns the slot index used for a belt card, or -1.
func finish_drag() -> int:
	_abort_if_stale()
	if not is_dragging():
		return -1
	if _drag_slot != -1:
		_finish_slot_drag()
		return -1
	var uid: int = _drag_uid
	var index: int = _target_slot()
	var placed: int = -1
	if _can_drop_on(index):
		var card: ConveyorCard = _conveyor.get_card(uid)
		var node: Control = _conveyor.take_card(uid)
		if card != null and node != null:
			placed = _slots_view.put_card(card, node, index)
	_clear_drag()
	if placed != -1:
		card_placed.emit(uid, placed)
	else:
		_conveyor.end_card_drag(uid)
		card_returned.emit(uid)
	return placed


## Aborts the drag and returns the card to the belt / its slot.
func cancel_drag() -> void:
	if not is_dragging():
		return
	if _drag_slot != -1:
		_return_slot_card()
		return
	var uid: int = _drag_uid
	_clear_drag()
	_conveyor.end_card_drag(uid)
	card_returned.emit(uid)


# True for a real slot index that is free. (HoldSlots.can_place(-1) means "any slot",
# which is not what "no slot under the card" should mean, so -1 is rejected here.)
func _can_drop_on(index: int) -> bool:
	return index != -1 and _slots_view.get_slots().can_place(index)


# Slot under the dragged card's centre (with drop padding), or -1.
func _target_slot() -> int:
	var centre: Vector2 = _drag_node.global_position + _drag_node.size * 0.5
	return _slots_view.slot_index_at(centre, _slots_view.get_config().drop_hit_padding_px)


func _slot_type() -> String:
	var card: ConveyorCard = _slots_view.get_slots().get_card(_drag_slot)
	return "" if card == null else card.type_id


func _is_move_card() -> bool:
	return _combat.get_player().is_move(_slot_type())


# Board cell under the dragged card's centre (Vector2i(-1,-1) off the board).
func _drag_cell() -> Vector2i:
	return _combat.get_cell_at(_drag_node.global_position + _drag_node.size * 0.5)


# Valid step destinations: the 4 neighbours of the player inside its own half.
func _step_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var player: CardPlayer = _combat.get_player()
	var origin: Vector2i = player.get_state().player_cell
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if player.is_valid_step(origin + d):
			cells.append(origin + d)
	return cells


# True while the pressed slot card still counts as "over its own slot": not moved beyond
# the tap threshold, or the pointer is inside the slot rect grown by the drop padding.
func _over_own_slot() -> bool:
	if not _moved:
		return true
	var padding: float = _slots_view.get_config().drop_hit_padding_px
	return _slots_view.get_slot_rect(_drag_slot).grow(padding).has_point(_pointer)


# Step cards highlight valid cells (and the hovered one). Attack cards preview the shape
# only while playable (no lock, units alive) and still over their slot; otherwise no preview.
func _update_slot_feedback() -> void:
	var player: CardPlayer = _combat.get_player()
	var type_id: String = _slot_type()
	if player.is_move(type_id):
		var cell: Vector2i = _drag_cell()
		var hover: Vector2i = cell if player.can_play(type_id, cell) else CardPlayer.NO_CELL
		_combat.set_step_targets(_step_cells(), hover)
	elif player.is_attack(type_id) and player.can_play(type_id) and _over_own_slot():
		_combat.set_preview(player.shape_cells(type_id))
	else:
		_combat.clear_preview()


# Tap or release back over the own slot uses a non-move card; a move card needs a valid cell.
func _finish_slot_drag() -> void:
	var index: int = _drag_slot
	var type_id: String = _slot_type()
	var use: bool = false
	var cell: Vector2i = CardPlayer.NO_CELL
	if _is_move_card():
		cell = _drag_cell()
		use = _combat.get_player().can_play(type_id, cell)
	else:
		use = _over_own_slot()
	_clear_drag()
	if use and play_slot_card(index, cell):
		return
	_slots_view.relayout()
	slot_card_returned.emit(index)


# A press/drag is stale if its node was freed, or (slot card) the slot now holds a
# different card or none. Aborts it: state cleared, highlights/preview removed, the
# matching "returned" signal emitted. Belt side goes through end_card_drag (safe for a
# uid that no longer exists).
func _abort_if_stale() -> void:
	if _drag_node == null:
		return
	var stale: bool = not is_instance_valid(_drag_node)
	if not stale and _drag_slot != -1:
		var card: ConveyorCard = _slots_view.get_slots().get_card(_drag_slot)
		stale = card == null or card.uid != _drag_card_uid
	if not stale:
		return
	var slot: int = _drag_slot
	var uid: int = _drag_uid
	_drag_node = null # never touch a freed node
	_clear_drag()
	if slot != -1:
		_slots_view.relayout()
		slot_card_returned.emit(slot)
	else:
		_conveyor.end_card_drag(uid)
		card_returned.emit(uid)


func _return_slot_card() -> void:
	var index: int = _drag_slot
	_clear_drag()
	_slots_view.relayout()
	slot_card_returned.emit(index)


func _clear_drag() -> void:
	if _drag_slot != -1 and _drag_node != null and is_instance_valid(_drag_node):
		_drag_node.z_index = 0
	_drag_uid = -1
	_drag_slot = -1
	_drag_card_uid = 0
	_drag_node = null
	_moved = false
	_combat.set_step_targets([] as Array[Vector2i])
	_combat.clear_preview()
	_slots_view.set_drop_highlight(-1)

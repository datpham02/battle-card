class_name CardDragController
extends Node2D
## Press-and-drag of belt cards into hold slots (Story 002) and of slotted cards onto
## the arena to play them (Story 003). Input only; rules live elsewhere (ConveyorBelt owns
## card positions, HoldSlots owns slot occupancy, CardPlayer owns play/recovery rules).
##
## State machine: IDLE --press on a belt card or a slotted card--> DRAGGING --release--> IDLE.
## Belt card: released over a free slot it moves belt -> slot; anywhere else (or when every
## slot is full) it is handed back and resumes from its true belt position.
## Slot card: released over the arena while CardPlayer.can_play it is played (effect now,
## slot emptied, recovery starts); anywhere else, or during recovery, it snaps back to its slot.
## A lane-shift card (Sidestep) must instead be dropped on a lane column ADJACENT to the
## player's row; that row becomes the destination and is highlighted while hovered.
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
## Emitted when the card in slot [param slot_index] was played onto the arena.
signal card_played(type_id: String, slot_index: int)
## Emitted when a slot card was dropped without being played (it snapped back to its slot).
signal slot_card_returned(slot_index: int)

@export var conveyor_view_path: NodePath = NodePath("../ConveyorView")
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _conveyor: ConveyorView
var _slots_view: HoldSlotsView
var _combat: CombatView
var _drag_slot: int = -1 # >= 0 while a slotted card is dragged
var _drag_uid: int = -1
var _drag_node: Control = null
var _grab_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_conveyor = get_node(conveyor_view_path) as ConveyorView
	_slots_view = get_node(hold_slots_view_path) as HoldSlotsView
	_combat = get_node(combat_view_path) as CombatView
	assert(
		_conveyor != null and _slots_view != null and _combat != null,
		"CardDragController: view paths not set"
	)


func _unhandled_input(event: InputEvent) -> void:
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
			finish_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_dragging():
		update_drag((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Losing window focus mid-drag must not strand a card in the air.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_dragging():
		cancel_drag()


## True while a card is being dragged.
func is_dragging() -> bool:
	return _drag_node != null


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


## Begins dragging the card held in slot [param slot_index] (to play it). Returns false
## if the slot is empty or a drag is active. The card stays registered in the slot until
## it is actually played.
func start_slot_drag(slot_index: int, pointer: Vector2) -> bool:
	if is_dragging():
		return false
	var node: Control = _slots_view.get_slot_node(slot_index)
	if node == null:
		return false
	_drag_slot = slot_index
	_drag_node = node
	_drag_node.z_index = 10
	_grab_offset = pointer - node.global_position
	update_drag(pointer)
	return true


## Plays the card in slot [param slot_index] if the rules allow (no recovery, enemy alive):
## applies its effect, empties the slot. Returns false and changes nothing otherwise.
## Used by the arena drop and by dev capture code.
## [param target_lane] is the destination for lane-shift cards (ignored by others).
func play_slot_card(slot_index: int, target_lane: int = -1) -> bool:
	var card: ConveyorCard = _slots_view.get_slots().get_card(slot_index)
	if card == null or not _combat.get_player().play(card.type_id, target_lane):
		return false
	_slots_view.remove_card(slot_index)
	card_played.emit(card.type_id, slot_index)
	return true


## Moves the dragged card to follow [param pointer] and updates the drop highlight.
func update_drag(pointer: Vector2) -> void:
	if not is_dragging():
		return
	var lift := Vector2(0.0, _slots_view.get_config().drag_lift_px)
	_drag_node.global_position = pointer - _grab_offset - lift
	if _drag_slot != -1:
		_update_play_highlight()
		return
	var index: int = _target_slot()
	_slots_view.set_drop_highlight(index if _can_drop_on(index) else -1)


## Ends the drag at the card's current position: place it in a free slot under it,
## otherwise return it to the belt. Returns the slot index used, or -1 if returned.
func finish_drag() -> int:
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


## Aborts the drag and returns the card to the belt.
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


# Lane row under the dragged card's centre, or -1 outside the lane area.
func _drag_lane() -> int:
	return _combat.get_lane_at(_drag_node.global_position + _drag_node.size * 0.5)


# True if the dragged slot card is over a valid drop and may be played now.
func _can_play_here() -> bool:
	var card: ConveyorCard = _slots_view.get_slots().get_card(_drag_slot)
	if card == null:
		return false
	var centre: Vector2 = _drag_node.global_position + _drag_node.size * 0.5
	var lane: int = _drag_lane()
	if _combat.get_player().is_lane_shift(card.type_id):
		return lane != -1 and _combat.get_player().can_play(card.type_id, lane)
	return _combat.get_arena_rect().has_point(centre) and _combat.get_player().can_play(card.type_id)


# Arena highlight for ordinary cards, hovered-lane highlight for lane-shift cards.
func _update_play_highlight() -> void:
	var card: ConveyorCard = _slots_view.get_slots().get_card(_drag_slot)
	var ok: bool = _can_play_here()
	var shifts: bool = card != null and _combat.get_player().is_lane_shift(card.type_id)
	_combat.set_drop_highlight(ok and not shifts)
	_combat.set_lane_highlight(_drag_lane() if ok and shifts else -1)


func _finish_slot_drag() -> void:
	var index: int = _drag_slot
	var play: bool = _can_play_here()
	var lane: int = _drag_lane()
	_clear_drag()
	if play and play_slot_card(index, lane):
		return
	_slots_view.relayout()
	slot_card_returned.emit(index)


func _return_slot_card() -> void:
	var index: int = _drag_slot
	_clear_drag()
	_slots_view.relayout()
	slot_card_returned.emit(index)


func _clear_drag() -> void:
	if _drag_node != null and _drag_slot != -1:
		_drag_node.z_index = 0
	_drag_uid = -1
	_drag_slot = -1
	_drag_node = null
	_combat.set_drop_highlight(false)
	_combat.set_lane_highlight(-1)
	_slots_view.set_drop_highlight(-1)

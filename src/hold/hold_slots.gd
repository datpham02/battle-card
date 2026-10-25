class_name HoldSlots
extends RefCounted
## Pure-logic hold slots: a fixed number of slots, each empty or holding one FieldPoint,
## plus a selection set (Story 007; cutting comes in Story 008).
## Story 014: a ROTTEN point (FieldPoint.rotten) may be placed and occupies its slot, but it can
## never be selected, never appears in the selected labels and leaves on its own after its
## rot_in_hand_sec, counted down by [method tick_rot].
## No scene/node dependency. Implements: design/game-brief.md MVP feature 2.

## Allowed slot count range (story AC: 3-4 slots).
const MIN_SLOTS: int = 3
const MAX_SLOTS: int = 4

## Emitted after a point is placed into slot [param index].
signal slot_filled(index: int, point: FieldPoint)
## Emitted after slot [param index] is emptied; [param point] is the point that left.
signal slot_cleared(index: int, point: FieldPoint)

var _slots: Array[FieldPoint] = []
var _selected: Array[int] = [] # slot indices in selection order


## [param slot_count] is clamped to [constant MIN_SLOTS]..[constant MAX_SLOTS].
func _init(slot_count: int = MAX_SLOTS) -> void:
	_slots.resize(clampi(slot_count, MIN_SLOTS, MAX_SLOTS))


## Story 024: a hand of exactly [param count] slots (at least 1), NOT clamped to
## MIN_SLOTS..MAX_SLOTS, for the player's piece bag (hold_slots.json piece_slot_count).
static func create_piece_hand(count: int) -> HoldSlots:
	var hand := HoldSlots.new(MIN_SLOTS)
	hand._slots.resize(maxi(count, 1))
	return hand


## Number of slots (empty or not).
func get_slot_count() -> int:
	return _slots.size()


## Number of slots currently holding a point.
func get_occupied_count() -> int:
	var count: int = 0
	for point: FieldPoint in _slots:
		if point != null:
			count += 1
	return count


## True when every slot holds a point.
func is_full() -> bool:
	return get_occupied_count() == _slots.size()


## True when no slot holds a point.
func is_empty() -> bool:
	return get_occupied_count() == 0


## True if [param index] is a valid slot with no point in it.
func is_slot_free(index: int) -> bool:
	return index >= 0 and index < _slots.size() and _slots[index] == null


## Point in slot [param index], or null if empty or out of range.
func get_point(index: int) -> FieldPoint:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


## Story 024: the piece held in slot [param index]; null when the slot is empty, out of range
## or holds a classic (label) point.
func get_piece(index: int) -> Piece:
	var point: FieldPoint = get_point(index)
	if point == null:
		return null
	return point.piece


## Index of the first free slot, or -1 when full.
func find_free_slot() -> int:
	for i: int in _slots.size():
		if _slots[i] == null:
			return i
	return -1


## True if a point could be placed: into [param slot_index], or into any free slot
## when [param slot_index] is -1.
func can_place(slot_index: int = -1) -> bool:
	if slot_index == -1:
		return find_free_slot() != -1
	return is_slot_free(slot_index)


## Places [param point] into [param slot_index] (or the first free slot when -1).
## Returns the slot index used, or -1 if the point is null or the slot is not free.
func place(point: FieldPoint, slot_index: int = -1) -> int:
	if point == null:
		return -1
	var index: int = find_free_slot() if slot_index == -1 else slot_index
	if not is_slot_free(index):
		return -1
	_slots[index] = point
	slot_filled.emit(index, point)
	return index


## Places [param point] into the first free slot. Returns its index, or -1 when full.
func place_in_first_free(point: FieldPoint) -> int:
	return place(point, -1)


## Empties slot [param index] (clearing its selection) and returns its point
## (null if it was empty or invalid).
func remove(index: int) -> FieldPoint:
	var point: FieldPoint = get_point(index)
	if point == null:
		return null
	_slots[index] = null
	_selected.erase(index)
	slot_cleared.emit(index, point)
	return point


## Toggles selection of an occupied slot. Returns the new state (false for empty slots and
## always false for a rotten point, which cannot be selected).
func toggle_selected(index: int) -> bool:
	var point: FieldPoint = get_point(index)
	if point == null:
		return false
	if point.rotten:
		_selected.erase(index)
		return false
	if _selected.has(index):
		_selected.erase(index)
		return false
	_selected.append(index)
	return true


## True when slot [param index] is selected.
func is_selected(index: int) -> bool:
	return _selected.has(index)


## Selected slot indices in the order they were selected (polygon order matters).
func get_selected_indices() -> Array[int]:
	return _selected.duplicate()


## Perimeter labels of the selected points, in selection order (rotten points never count).
func get_selected_labels() -> Array[String]:
	var labels: Array[String] = []
	for index: int in _selected:
		var point: FieldPoint = _slots[index]
		if point != null and not point.rotten:
			labels.append(point.label)
	return labels


## Deselects everything (points stay in their slots).
func clear_selection() -> void:
	_selected.clear()


## Removes the selected points from their slots, in selection order, and returns them.
## The selection ends up empty. Rotten points are never removed by this (they stay).
func remove_selected() -> Array[FieldPoint]:
	var removed: Array[FieldPoint] = []
	for index: int in _selected.duplicate():
		var held: FieldPoint = get_point(index)
		if held != null and held.rotten:
			continue
		var point: FieldPoint = remove(index)
		if point != null:
			removed.append(point)
	_selected.clear()
	return removed


## Story 014: counts [param delta] seconds off every rotten point held; a point whose
## rot_in_hand_sec reaches 0 leaves its slot (slot_cleared is emitted, the point is dropped).
## Call with the SCALED simulation step so slow motion also slows the rot.
func tick_rot(delta: float) -> void:
	if delta <= 0.0:
		return
	for i: int in _slots.size():
		var point: FieldPoint = _slots[i]
		if point == null or not point.rotten:
			continue
		point.rot_in_hand_sec -= delta
		if point.rot_in_hand_sec <= 0.0:
			point.rot_in_hand_sec = 0.0
			remove(i)


## Number of rotten points held right now (Story 014).
func get_rotten_count() -> int:
	var count: int = 0
	for point: FieldPoint in _slots:
		if point != null and point.rotten:
			count += 1
	return count

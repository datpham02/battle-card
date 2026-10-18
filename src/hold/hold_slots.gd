class_name HoldSlots
extends RefCounted
## Pure-logic hold slots: a fixed number of slots, each empty or holding one card.
## No scene/node dependency. Does not know about the belt or dragging.
## Implements: design/game-brief.md MVP feature 2 (Story 002).

## Allowed slot count range (story AC: 3-4 slots).
const MIN_SLOTS: int = 3
const MAX_SLOTS: int = 4

## Emitted after a card is placed into slot [param index].
signal slot_filled(index: int, card: ConveyorCard)
## Emitted after slot [param index] is emptied; [param card] is the card that left.
signal slot_cleared(index: int, card: ConveyorCard)

var _slots: Array[ConveyorCard] = []


## [param slot_count] is clamped to [constant MIN_SLOTS]..[constant MAX_SLOTS].
func _init(slot_count: int = MAX_SLOTS) -> void:
	_slots.resize(clampi(slot_count, MIN_SLOTS, MAX_SLOTS))


## Number of slots (empty or not).
func get_slot_count() -> int:
	return _slots.size()


## Number of slots currently holding a card.
func get_occupied_count() -> int:
	var count: int = 0
	for card: ConveyorCard in _slots:
		if card != null:
			count += 1
	return count


## True when every slot holds a card.
func is_full() -> bool:
	return get_occupied_count() == _slots.size()


## True when no slot holds a card.
func is_empty() -> bool:
	return get_occupied_count() == 0


## True if [param index] is a valid slot with no card in it.
func is_slot_free(index: int) -> bool:
	return index >= 0 and index < _slots.size() and _slots[index] == null


## Card in slot [param index], or null if empty or out of range.
func get_card(index: int) -> ConveyorCard:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


## Index of the first free slot, or -1 when full.
func find_free_slot() -> int:
	for i: int in _slots.size():
		if _slots[i] == null:
			return i
	return -1


## True if a card could be placed: into [param slot_index], or into any free slot
## when [param slot_index] is -1.
func can_place(slot_index: int = -1) -> bool:
	if slot_index == -1:
		return find_free_slot() != -1
	return is_slot_free(slot_index)


## Places [param card] into [param slot_index] (or the first free slot when -1).
## Returns the slot index used, or -1 if the card is null or the slot is not free.
func place(card: ConveyorCard, slot_index: int = -1) -> int:
	if card == null:
		return -1
	var index: int = find_free_slot() if slot_index == -1 else slot_index
	if not is_slot_free(index):
		return -1
	_slots[index] = card
	slot_filled.emit(index, card)
	return index


## Empties slot [param index] and returns its card (null if it was empty or invalid).
func remove(index: int) -> ConveyorCard:
	var card: ConveyorCard = get_card(index)
	if card == null:
		return null
	_slots[index] = null
	slot_cleared.emit(index, card)
	return card

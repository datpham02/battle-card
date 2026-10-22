class_name CutFlow
extends RefCounted
## Card-menu flow of the player's cut: IDLE or MENU. Pure logic (no nodes); the menu
## countdown advances only through [method tick_real] with a REAL (unscaled) delta.
## Opening the menu stores the consumed cut (labels + covered cells) and the drawn hand;
## choosing an available card OF THE HAND, or the countdown running out (the basic default
## card, even if the hand does not contain it), emits [signal skill_chosen].
## Implements: Story 008, Story 017 part A.

## Emitted once when a card is chosen (by the player or by timeout); the menu is closed.
signal skill_chosen(skill_id: String, labels: Array[String], cells: Array[Vector2i])

var _config: SkillConfig
var _cooldowns: SkillCooldowns
var _open: bool = false
var _time_left: float = 0.0
var _labels: Array[String] = []
var _cells: Array[Vector2i] = []
var _hand: Array[String] = []


func _init(skill_config: SkillConfig, cooldowns: SkillCooldowns) -> void:
	_config = skill_config
	_cooldowns = cooldowns


## Opens the menu for a cut with the drawn [param hand] (ordered; empty = [default_card]).
## Returns false if a menu is already open or [param cells] is empty.
func open_menu(labels: Array[String], cells: Array[Vector2i], hand: Array[String] = []) -> bool:
	if _open or cells.is_empty():
		return false
	_open = true
	_labels = labels.duplicate()
	_cells = cells.duplicate()
	_hand = hand.duplicate()
	if _hand.is_empty():
		_hand = [_config.default_card]
	_time_left = _config.menu_choose_sec
	return true


## Advances the choose countdown by [param delta] REAL seconds; at zero the default card
## (kiem_khi, no cell minimum) is chosen whether or not the hand holds it.
func tick_real(delta: float) -> void:
	if not _open:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	if not _emit_choice(_config.default_card):
		_emit_choice(SkillConfig.FALLBACK_SKILL)
	_open = false


## Chooses [param skill_id] if the menu is open, the card is in the hand and it is available
## (cell minimum + cooldown). Returns false (menu stays open) otherwise.
func choose(skill_id: String) -> bool:
	if not _open or not _hand.has(skill_id):
		return false
	return _emit_choice(skill_id)


# Availability check + close + emit, without the hand test (the timeout path uses it).
func _emit_choice(skill_id: String) -> bool:
	var check: Dictionary = SkillAvailability.check(_config, _cooldowns, skill_id, _cells.size())
	if not bool(check["available"]):
		return false
	var labels: Array[String] = _labels
	var cells: Array[Vector2i] = _cells
	_open = false
	_time_left = 0.0
	_labels = []
	_cells = []
	_hand = []
	skill_chosen.emit(skill_id, labels, cells)
	return true


## True while the menu is open.
func is_menu_open() -> bool:
	return _open


## The drawn hand of the open menu, in order (empty when closed).
func get_hand() -> Array[String]:
	return _hand.duplicate()


## REAL seconds left to choose (0 when closed).
func get_time_left() -> float:
	return maxf(_time_left, 0.0) if _open else 0.0


## Total choose time (cards.json menu_choose_sec).
func get_duration() -> float:
	return _config.menu_choose_sec


## Cells of the pending cut (empty when closed).
func get_cells() -> Array[Vector2i]:
	return _cells.duplicate()


## Labels of the pending cut in selection order (empty when closed).
func get_labels() -> Array[String]:
	return _labels.duplicate()

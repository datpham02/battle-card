class_name CutFlow
extends RefCounted
## Skill-menu flow of the player's cut: IDLE or MENU. Pure logic (no nodes); the menu
## countdown advances only through [method tick_real] with a REAL (unscaled) delta.
## Opening the menu stores the consumed cut (labels + covered cells); choosing an
## available skill, or the countdown running out (default skill), emits [signal skill_chosen].
## Implements: Story 008.

## Emitted once when a skill is chosen (by the player or by timeout); the menu is closed.
signal skill_chosen(skill_id: String, labels: Array[String], cells: Array[Vector2i])

var _config: SkillConfig
var _cooldowns: SkillCooldowns
var _open: bool = false
var _time_left: float = 0.0
var _labels: Array[String] = []
var _cells: Array[Vector2i] = []


func _init(skill_config: SkillConfig, cooldowns: SkillCooldowns) -> void:
	_config = skill_config
	_cooldowns = cooldowns


## Opens the menu for a cut. Returns false if a menu is already open or [param cells] is empty.
func open_menu(labels: Array[String], cells: Array[Vector2i]) -> bool:
	if _open or cells.is_empty():
		return false
	_open = true
	_labels = labels.duplicate()
	_cells = cells.duplicate()
	_time_left = _config.menu_choose_sec
	return true


## Advances the choose countdown by [param delta] REAL seconds; at zero the default skill
## is chosen (slash if the default is somehow unavailable).
func tick_real(delta: float) -> void:
	if not _open:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	if not choose(_config.default_skill):
		choose(SkillConfig.FALLBACK_SKILL)
	# Slash has no cell minimum, so one of the two always succeeds; close defensively.
	_open = false


## Chooses [param skill_id] if the menu is open and the skill is available for the cut's
## cell count. Returns false (menu stays open) otherwise.
func choose(skill_id: String) -> bool:
	if not _open:
		return false
	var check: Dictionary = SkillAvailability.check(_config, _cooldowns, skill_id, _cells.size())
	if not bool(check["available"]):
		return false
	var labels: Array[String] = _labels
	var cells: Array[Vector2i] = _cells
	_open = false
	_time_left = 0.0
	_labels = []
	_cells = []
	skill_chosen.emit(skill_id, labels, cells)
	return true


## True while the menu is open.
func is_menu_open() -> bool:
	return _open


## REAL seconds left to choose (0 when closed).
func get_time_left() -> float:
	return maxf(_time_left, 0.0) if _open else 0.0


## Total choose time (skills.json menu_choose_sec).
func get_duration() -> float:
	return _config.menu_choose_sec


## Cells of the pending cut (empty when closed).
func get_cells() -> Array[Vector2i]:
	return _cells.duplicate()


## Labels of the pending cut in selection order (empty when closed).
func get_labels() -> Array[String]:
	return _labels.duplicate()

class_name CutFlow
extends RefCounted
## Card-menu flow of the player's cut: IDLE or MENU. Since 2026-11-01 (quick spec menu-la-giua-man-hinh) the menu
## opens when the player presses Tung phép (or the place window runs out) on the pieces already placed; pieces
## are never joined while it is open. Pure logic (no nodes); the menu
## countdown advances only through [method tick_real] with a REAL (unscaled) delta.
## Opening the menu stores the consumed cut (labels + covered cells) and the drawn hand;
## choosing an available card OF THE HAND, or the countdown running out, emits [signal skill_chosen].
## 2026-11-04 (user: "hết 4s thì ... cast random lá bài thỏa điều kiện"): on timeout a RANDOM card of the hand that is
## available (cell minimum, cooldown, not a curse) is cast; only when none is, the basic default card.
## Implements: Story 008, Story 017 part A, design/quick-specs/niem-dung-tran-2026-11-04.md.

## Emitted once when a card is chosen (by the player or by timeout); the menu is closed.
signal skill_chosen(skill_id: String, labels: Array[String], cells: Array[Vector2i])

var _config: SkillConfig
var _cooldowns: SkillCooldowns
var _open: bool = false
var _time_left: float = 0.0
var _labels: Array[String] = []
var _cells: Array[Vector2i] = []
var _hand: Array[String] = []
## Story 020: Callable(id: String) -> int giving the player's card level; invalid = level 1.
var level_of: Callable = Callable()
## Accessibility "Thời gian chọn lá" (SettingsStore.card_time_mult): the choose time is menu_choose_sec x this;
## 0 = no limit (the menu waits for a card; the match stays slowed).
var time_mult: float = 1.0
## Picks the timeout card. Randomized at creation; tests seed it for a deterministic pick.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(skill_config: SkillConfig, cooldowns: SkillCooldowns) -> void:
	_config = skill_config
	_cooldowns = cooldowns


## Opens the menu for a cut with the drawn [param hand] (ordered; empty = [default_card]).
## [param time_left] = REAL seconds to choose (2026-11-04: what is left of the shared cast clock); negative = the
## full [method get_duration]. Ignored while unlimited. Returns false if a menu is already open or [param cells] is empty.
func open_menu(labels: Array[String], cells: Array[Vector2i], hand: Array[String] = [], time_left: float = -1.0) -> bool:
	if _open or cells.is_empty():
		return false
	_open = true
	_labels = labels.duplicate()
	_cells = cells.duplicate()
	_hand = hand.duplicate()
	if _hand.is_empty():
		_hand = [_config.default_card]
	_time_left = time_left if time_left >= 0.0 else get_duration()
	return true


## Advances the choose countdown by [param delta] REAL seconds; at zero a random available card of the hand is
## chosen ([method timeout_choice]); with none available the default card (kiem_khi, no cell minimum) whether or not
## the hand holds it. A [param delta] of 0 resolves a menu opened with no time left.
func tick_real(delta: float) -> void:
	if not _open or is_unlimited():
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	var pick: String = timeout_choice()
	if pick.is_empty() or not _emit_choice(pick):
		if not _emit_choice(_config.default_card):
			_emit_choice(SkillConfig.FALLBACK_SKILL)
	_open = false


## The card the timeout casts: a random one (via [member rng]) among the hand's cards that are available for the
## open cut (duplicates weigh more); "" when none is or the menu is closed.
func timeout_choice() -> String:
	if not _open:
		return ""
	var ok: Array[String] = []
	for id: String in _hand:
		if bool(SkillAvailability.check(_config, _cooldowns, id, _cells.size(), card_level(id))["available"]):
			ok.append(id)
	if ok.is_empty():
		return ""
	return ok[rng.randi_range(0, ok.size() - 1)]


## Chooses [param skill_id] if the menu is open, the card is in the hand and it is available
## (cell minimum + cooldown). Returns false (menu stays open) otherwise.
func choose(skill_id: String) -> bool:
	if not _open or not _hand.has(skill_id):
		return false
	return _emit_choice(skill_id)


# Availability check + close + emit, without the hand test (the timeout path uses it).
func _emit_choice(skill_id: String) -> bool:
	var check: Dictionary = SkillAvailability.check(_config, _cooldowns, skill_id, _cells.size(), card_level(skill_id))
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


## Story 024: closes the open menu WITHOUT choosing (the piece goes back to the bag). Returns the
## cells of the abandoned cut ([] when no menu was open). Emits nothing.
func cancel_menu() -> Array[Vector2i]:
	if not _open:
		return []
	var cells: Array[Vector2i] = _cells
	_open = false
	_time_left = 0.0
	_labels = []
	_cells = []
	_hand = []
	return cells


## Level used for [param skill_id] (1 without a [member level_of] callable).
func card_level(skill_id: String) -> int:
	if level_of.is_valid():
		return maxi(int(level_of.call(skill_id)), 1)
	return 1


## True while the menu is open.
func is_menu_open() -> bool:
	return _open


## The drawn hand of the open menu, in order (empty when closed).
func get_hand() -> Array[String]:
	return _hand.duplicate()


## REAL seconds left to choose (0 when closed).
func get_time_left() -> float:
	return maxf(_time_left, 0.0) if _open else 0.0


## Dev/capture only: sets the REAL seconds left of the open menu (no effect while closed).
func debug_set_time_left(sec: float) -> void:
	if _open:
		_time_left = maxf(sec, 0.0)


## Total choose time: cards.json menu_choose_sec x [member time_mult] (0 = no limit).
func get_duration() -> float:
	return 0.0 if is_unlimited() else _config.menu_choose_sec * time_mult


## True when the menu has no time limit ([member time_mult] 0, the "không giới hạn" setting).
func is_unlimited() -> bool:
	return time_mult <= 0.0


## Cells of the pending cut (empty when closed).
func get_cells() -> Array[Vector2i]:
	return _cells.duplicate()


## Labels of the pending cut in selection order (empty when closed).
func get_labels() -> Array[String]:
	return _labels.duplicate()

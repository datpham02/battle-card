class_name CharacterSelectView
extends Node2D
## Character select screen (Story 018): after the title, before the floor select. One card per
## character of [method GameFlow.get_characters], side by side (ScreenLayout.character_card_rects,
## file order): the name, the HP line, a short description (two lines at most), the passive's name
## and text, and the starter deck summarised by copies ("Kiếm khí ×2 · Chấn phong ×2 …", card names
## from SkillConfig). Locked characters (`unlocked` false) draw grey with a code-drawn padlock and
## ignore taps. Tap an unlocked card -> [method GameFlow.character_chosen]; "Về"
## (ScreenLayout.back_button_rect) -> [method GameFlow.show_title]. Child of GameFlow (reads it
## through [member flow_path]); draws and takes taps only in
## [constant GameFlow.Phase.CHARACTER_SELECT]; owns no state. Taps are consumed on a card or the
## button only; input dedup as in TitleView (emulated copies — device ==
## InputEvent.DEVICE_ID_EMULATION — are consumed but never act).
## DEV convenience: Enter / Keypad Enter / Space (pressed, not echo) pick the FIRST unlocked card.
## Placeholder art; all strings are TEXT_* keys drawn through tr(). More than four characters only
## narrow the cards (a second row is out of scope for Story 018).

const TITLE_COLOR: Color = Color(0.15, 0.12, 0.1)
const CARD_OPEN_BACK: Color = Color(1.0, 0.97, 0.9)
const CARD_OPEN_OUTLINE: Color = Color(0.6, 0.52, 0.4)
const CARD_LOCKED_BACK: Color = Color(0.72, 0.7, 0.66)
const CARD_LOCKED_OUTLINE: Color = Color(0.5, 0.48, 0.44)
const CARD_PRESSED_OUTLINE: Color = Color(1.0, 0.85, 0.2)
const NAME_COLOR: Color = Color(0.15, 0.12, 0.1)
const HP_COLOR: Color = Color(0.7, 0.2, 0.15)
const BODY_COLOR: Color = Color(0.3, 0.26, 0.22)
const PASSIVE_COLOR: Color = Color(0.2, 0.4, 0.55)
const DIVIDER_COLOR: Color = Color(0.6, 0.52, 0.4, 0.5)
const LOCKED_TEXT: Color = Color(0.4, 0.38, 0.35)
const PADLOCK_COLOR: Color = Color(0.45, 0.43, 0.4)
const OUTLINE_WIDTH: float = 3.0
const PRESSED_OUTLINE_WIDTH: float = 6.0
const DIVIDER_WIDTH: float = 2.0
const MARK_WIDTH: float = 6.0

const TITLE_FONT_SIZE: int = 48
const BUTTON_FONT_SIZE: int = 28
const NAME_FONT_SIZE: int = 36
const HP_FONT_SIZE: int = 26
const DESC_FONT_SIZE: int = 20
const PASSIVE_NAME_FONT_SIZE: int = 24
const PASSIVE_DESC_FONT_SIZE: int = 18
const DECK_HEADER_FONT_SIZE: int = 22
const DECK_FONT_SIZE: int = 18
## Line limits of the wrapped blocks (draw_multiline_string max_lines).
const DESC_MAX_LINES: int = 2
const PASSIVE_DESC_MAX_LINES: int = 3
const DECK_MAX_LINES: int = 2

## Inner horizontal padding of a card as a share of its width.
const CARD_PAD_RATIO: float = 0.06
## Baselines inside a card as shares of its height (wrapped blocks start at theirs and grow down).
const NAME_BASELINE: float = 0.09
const HP_BASELINE: float = 0.16
const DESC_BASELINE: float = 0.24
const DIVIDER_1: float = 0.37
const PASSIVE_NAME_BASELINE: float = 0.44
const PASSIVE_DESC_BASELINE: float = 0.5
const DIVIDER_2: float = 0.66
const DECK_HEADER_BASELINE: float = 0.72
const DECK_BASELINE: float = 0.78
## Padlock geometry as shares of the card size: body size, body centre y, shackle radius.
const LOCK_BODY_W: float = 0.14
const LOCK_BODY_H: float = 0.05
const LOCK_CENTER_Y: float = 0.93
const LOCK_SHACKLE_R: float = 0.05
const ARC_POINTS: int = 12
## Joins the deck entries ("Kiếm khí ×2 · Chấn phong ×2"); punctuation, same glyph as the match labels.
const DECK_SEPARATOR: String = " · "

const TEXT_TITLE: String = "ui.character_select.title"
## "Máu %d" with the character's max HP.
const TEXT_HP: String = "ui.character_select.hp"
## Header of the starter deck block.
const TEXT_DECK: String = "ui.character_select.deck"
## One deck entry: "%s ×%d" (card name, copies).
const TEXT_DECK_ENTRY: String = "ui.character_select.deck_entry"
## The back-to-title button (ScreenLayout.back_button_rect).
const TEXT_BACK: String = "ui.character_select.back"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow
## Card names for the deck summary (loaded once).
var _skills: SkillConfig


func _ready() -> void:
	_flow = get_node(flow_path) as GameFlow
	_skills = SkillConfig.load_from_file()


func _process(_delta: float) -> void:
	if _is_active():
		queue_redraw()


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			var unlocked: Array[String] = _flow.get_characters().unlocked_ids()
			if not unlocked.is_empty():
				_flow.character_chosen(unlocked[0])
		return
	var pos: Vector2
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
			return
		pos = button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		pos = touch.position
	else:
		return
	var vp: Vector2 = get_viewport_rect().size
	if ScreenLayout.back_button_rect(vp).has_point(pos):
		get_viewport().set_input_as_handled()
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_flow.show_title()
		return
	var ids: Array[String] = _flow.get_characters().ids()
	var rects: Array[Rect2] = ScreenLayout.character_card_rects(vp, ids.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			get_viewport().set_input_as_handled()
			if event.device != InputEvent.DEVICE_ID_EMULATION and _is_unlocked(ids[i]):
				_flow.character_chosen(ids[i])
			return


func _is_unlocked(id: String) -> bool:
	return bool(_flow.get_characters().get_character(id).get("unlocked", false))


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR)
	var back: Rect2 = ScreenLayout.back_button_rect(vp)
	UiButtons.draw_button(self, back, tr(TEXT_BACK), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, back), true, BUTTON_FONT_SIZE, OUTLINE_WIDTH)
	var ids: Array[String] = _flow.get_characters().ids()
	var rects: Array[Rect2] = ScreenLayout.character_card_rects(vp, ids.size())
	for i: int in rects.size():
		_draw_card(rects[i], ids[i])


func _draw_card(rect: Rect2, id: String) -> void:
	var character: Dictionary = _flow.get_characters().get_character(id)
	var locked: bool = not bool(character.get("unlocked", false))
	var pressed: bool = not locked and UiButtons.is_pressed_at(self, rect)
	draw_rect(rect, CARD_LOCKED_BACK if locked else CARD_OPEN_BACK)
	if pressed:
		draw_rect(rect, CARD_PRESSED_OUTLINE, false, PRESSED_OUTLINE_WIDTH)
	else:
		draw_rect(rect, CARD_LOCKED_OUTLINE if locked else CARD_OPEN_OUTLINE, false, OUTLINE_WIDTH)
	var pad: float = rect.size.x * CARD_PAD_RATIO
	var inner := Rect2(rect.position.x + pad, rect.position.y, rect.size.x - pad * 2.0, rect.size.y)
	var name_color: Color = LOCKED_TEXT if locked else NAME_COLOR
	var hp_color: Color = LOCKED_TEXT if locked else HP_COLOR
	var body_color: Color = LOCKED_TEXT if locked else BODY_COLOR
	var passive_color: Color = LOCKED_TEXT if locked else PASSIVE_COLOR
	_text(inner, _y(rect, NAME_BASELINE), tr(str(character.get("name_key", id))), NAME_FONT_SIZE, name_color)
	_text(inner, _y(rect, HP_BASELINE), tr(TEXT_HP) % int(float(character.get("max_hp", 0.0))), HP_FONT_SIZE, hp_color)
	_wrapped(inner, _y(rect, DESC_BASELINE), tr(str(character.get("desc_key", ""))), DESC_FONT_SIZE, DESC_MAX_LINES, body_color)
	_divider(inner, _y(rect, DIVIDER_1))
	_text(inner, _y(rect, PASSIVE_NAME_BASELINE), tr(str(character.get("passive_name_key", ""))), PASSIVE_NAME_FONT_SIZE, passive_color)
	_wrapped(inner, _y(rect, PASSIVE_DESC_BASELINE), tr(str(character.get("passive_desc_key", ""))), PASSIVE_DESC_FONT_SIZE, PASSIVE_DESC_MAX_LINES, body_color)
	_divider(inner, _y(rect, DIVIDER_2))
	_text(inner, _y(rect, DECK_HEADER_BASELINE), tr(TEXT_DECK), DECK_HEADER_FONT_SIZE, name_color)
	_wrapped(inner, _y(rect, DECK_BASELINE), _deck_summary(id), DECK_FONT_SIZE, DECK_MAX_LINES, body_color)
	if locked:
		_draw_padlock(rect)


# The starter deck of [param id] by copies, in first-appearance order: "Kiếm khí ×2 · Chấn phong ×2 …".
func _deck_summary(id: String) -> String:
	var counts: Dictionary = {}
	var order: Array[String] = []
	for card: String in _flow.get_characters().deck_of(id):
		if not counts.has(card):
			counts[card] = 0
			order.append(card)
		counts[card] = int(counts[card]) + 1
	var parts := PackedStringArray()
	for card: String in order:
		parts.append(tr(TEXT_DECK_ENTRY) % [_card_name(card), int(counts[card])])
	return DECK_SEPARATOR.join(parts)


# Translated card name from SkillConfig (the id itself when the card is unknown).
func _card_name(card: String) -> String:
	var skill: Dictionary = _skills.get_skill(card)
	return tr(str(skill.get("name_key", card)))


# Padlock: a filled body with a half-circle shackle above it (the FloorSelectView look).
func _draw_padlock(rect: Rect2) -> void:
	var body_size := Vector2(rect.size.x * LOCK_BODY_W, rect.size.y * LOCK_BODY_H)
	var center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * LOCK_CENTER_Y)
	var body := Rect2(center - body_size * 0.5, body_size)
	draw_rect(body, PADLOCK_COLOR)
	var radius: float = rect.size.x * LOCK_SHACKLE_R
	draw_arc(Vector2(center.x, body.position.y), radius, PI, TAU, ARC_POINTS, PADLOCK_COLOR, MARK_WIDTH)
	draw_line(Vector2(center.x - radius, body.position.y), Vector2(center.x - radius, body.position.y - radius * 0.3), PADLOCK_COLOR, MARK_WIDTH)
	draw_line(Vector2(center.x + radius, body.position.y), Vector2(center.x + radius, body.position.y - radius * 0.3), PADLOCK_COLOR, MARK_WIDTH)


# Baseline y for a share of the card height.
func _y(rect: Rect2, share: float) -> float:
	return rect.position.y + rect.size.y * share


func _divider(inner: Rect2, y: float) -> void:
	draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), DIVIDER_COLOR, DIVIDER_WIDTH)


# Centred single-line text at baseline [param y] over the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


# Centred word-wrapped text from baseline [param y], at most [param max_lines] lines, over the width of [param rect].
func _wrapped(rect: Rect2, y: float, text: String, size: int, max_lines: int, color: Color) -> void:
	draw_multiline_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, max_lines, color)

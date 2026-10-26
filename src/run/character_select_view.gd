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
## Placeholder art; all strings are TEXT_* keys drawn through tr(). Story 037: five cards share the width
## (fonts shrink with the card width, wrapped blocks get one more line); a tap on a LOCKED card fills the
## strip under the cards with its unlock condition and progress ("Giết 3 boss vùng - 1/3", from
## AchievementsConfig / UnlockRules); the strip is reserved whenever any card is locked.
## DEV-ONLY user arg `--screen=character_locked=<id>` shows that card's strip on entry (captures).
## Story 038: the cards are shorter (CARDS_BOTTOM) to make room for the Kiep panel under them: the level bar of the
## FOCUSED card (a large "-" at the left edge, the level in the middle, a large "+" at the right edge; "+" is dimmed
## above the unlocked level and a tap on it shows "Thắng Kiếp N để mở") and the list of the active rules (levels 1..k,
## the newest highlighted, dragged vertically when it does not fit). A card shows its best-won "Kiếp N" badge. Tapping an
## unfocused unlocked card focuses it (GameFlow.set_character; the level resets to its unlocked one); tapping the focused
## card starts the run at the bar's level. DEV `--screen=kiep_hint` shows the locked-level hint on entry.

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
const SIGNATURE_NAME_FONT_SIZE: int = 22
const SIGNATURE_DESC_FONT_SIZE: int = 17
const SIGNATURE_DESC_MAX_LINES: int = 3
const KIEP_BADGE_FONT_SIZE: int = 13
const KIEP_CAPTION_FONT_SIZE: int = 20
const KIEP_NUMBER_FONT_SIZE: int = 56
const KIEP_BUTTON_FONT_SIZE: int = 64
const KIEP_HINT_FONT_SIZE: int = 18
const KIEP_RULES_FONT_SIZE: int = 16
const KIEP_RULES_LINE_HEIGHT: float = 20.0
const KIEP_RULES_HEADER_HEIGHT: float = 18.0
const SIGNATURE_COLOR: Color = Color(0.6, 0.25, 0.1)
## Line limits of the wrapped blocks (draw_multiline_string max_lines).
const DESC_MAX_LINES: int = 3
const PASSIVE_DESC_MAX_LINES: int = 4
const DECK_MAX_LINES: int = 3

## Inner horizontal padding of a card as a share of its width.
const CARD_PAD_RATIO: float = 0.06
## Baselines inside a card as shares of its height (wrapped blocks start at theirs and grow down).
const NAME_BASELINE: float = 0.07
const HP_BASELINE: float = 0.135
const DESC_BASELINE: float = 0.195
const DIVIDER_1: float = 0.31
const PASSIVE_NAME_BASELINE: float = 0.375
const PASSIVE_DESC_BASELINE: float = 0.41
const DIVIDER_2: float = 0.575
const DECK_HEADER_BASELINE: float = 0.63
const DECK_BASELINE: float = 0.67
## Story 021: the signature block under the deck (unlocked cards only): a divider, then the
## "Tuyệt kỹ: <tên>" line and its short description (two lines at most).
const DIVIDER_3: float = 0.79
const SIGNATURE_NAME_BASELINE: float = 0.825
const SIGNATURE_DESC_BASELINE: float = 0.865
## Padlock geometry as shares of the card size: body size, body centre y, shackle radius.
const LOCK_BODY_W: float = 0.14
const LOCK_BODY_H: float = 0.05
const LOCK_CENTER_Y: float = 0.9
const LOCK_SHACKLE_R: float = 0.05
const ARC_POINTS: int = 12
## Joins the deck entries ("Kiếm khí ×2 · Chấn phong ×2"); punctuation, same glyph as the match labels.
const DECK_SEPARATOR: String = " · "

const TEXT_TITLE: String = "ui.character_select.title"
## "Máu %d" with the character's max HP.
const TEXT_HP: String = "ui.character_select.hp"
## Header of the starter deck block.
const TEXT_DECK: String = "ui.character_select.deck"
## Story 021: "Tuyệt kỹ: %s" with the signature name; the names and descriptions are signature.<id>.name / .desc.
const TEXT_SIGNATURE: String = "ui.character_select.signature"
const SIGNATURE_KEY_PREFIX: String = "signature."
const SIGNATURE_NAME_SUFFIX: String = ".name"
const SIGNATURE_DESC_SUFFIX: String = ".desc"
## One deck entry: "%s ×%d" (card name, copies).
const TEXT_DECK_ENTRY: String = "ui.character_select.deck_entry"
## The back-to-title button (ScreenLayout.back_button_rect).
const TEXT_BACK: String = "ui.character_select.back"
## Story 037: the strip under the cards: the hint before any locked card was tapped, and "%s - %d/%d" (condition,
## current, target) after.
const TEXT_LOCKED_HINT: String = "character.locked_hint"
const TEXT_LOCKED_PROGRESS: String = "character.locked_progress"
const DEV_LOCKED_ARG: String = "--screen=character_locked="
const REWARD_KIND_CHARACTER: String = "character"
## Story 037 layout: the font scale of the card text (Story 038: always the smallest, the cards are short), the
## share of the height where the cards end, and the strip itself. Story 038: under the cards, in order: the level bar,
## the rules list, the strip.
const MIN_FONT_SCALE: float = 0.66
const MIN_FONT_SIZE: int = 12
const CARDS_BOTTOM: float = 0.65
const BAR_TOP: float = 0.665
const BAR_HEIGHT: float = 0.139
const BAR_BUTTON_WIDTH_RATIO: float = 0.12
const RULES_TOP: float = 0.812
const RULES_BOTTOM_WITH_STRIP: float = 0.925
const RULES_BOTTOM: float = 0.985
const STRIP_TOP: float = 0.93
const STRIP_BOTTOM: float = 0.985
const STRIP_FONT_SIZE: int = 22
const STRIP_BACK: Color = Color(1.0, 0.97, 0.9)
const STRIP_TEXT_COLOR: Color = Color(0.4, 0.2, 0.12)
const DEV_KIEP_HINT_ARG: String = "--screen=kiep_hint"
## Story 038 strings: the badge "Kiếp %d" (best won), the bar caption, the locked-level hint "Thắng Kiếp %d để mở",
## the rules list title and its numbered line, the level-0 line, the "tap again" hint.
const TEXT_KIEP_BADGE: String = "ui.character_select.kiep_badge"
const TEXT_KIEP_LABEL: String = "ui.character_select.kiep_label"
const TEXT_KIEP_LOCKED_HINT: String = "ui.character_select.kiep_locked_hint"
const TEXT_KIEP_RULES_TITLE: String = "ui.character_select.kiep_rules_title"
const TEXT_KIEP_RULE_LINE: String = "ui.character_select.kiep_rule_line"
const TEXT_KIEP_NONE: String = "ui.character_select.kiep_none"
const TEXT_TAP_TO_START: String = "ui.character_select.tap_to_start"
const KIEP_BADGE_BACK: Color = Color(0.45, 0.2, 0.55)
const KIEP_BADGE_TEXT: Color = Color(1.0, 1.0, 1.0)
const KIEP_FOCUS_OUTLINE: Color = Color(0.25, 0.45, 0.85)
const KIEP_RULES_BACK: Color = Color(1.0, 0.97, 0.9, 0.85)
const KIEP_RULE_COLOR: Color = Color(0.3, 0.26, 0.22)
const KIEP_NEWEST_COLOR: Color = Color(0.75, 0.2, 0.1)
const KIEP_HINT_COLOR: Color = Color(0.75, 0.2, 0.1)
const KIEP_NUMBER_COLOR: Color = Color(0.15, 0.12, 0.1)
const FOCUS_OUTLINE_WIDTH: float = 6.0

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow
## Card names for the deck summary (loaded once).
var _skills: SkillConfig
## Story 037: the locked character whose unlock condition the strip shows ("" = the hint).
var _hint_id: String = ""
## Story 038: true while the "Thắng Kiếp N để mở" hint shows (a tap on the dimmed "+"); cleared by any level / card change.
var _kiep_hint: bool = false
## Story 038: vertical scroll offset (px) of the rules list; -1 = not set yet (shows the newest rules at the bottom).
var _rules_scroll: float = -1.0
## Story 038: the level the list scroll was last aimed at (a level change re-aims it at the newest rule).
var _rules_for_level: int = -1
var _drag_active: bool = false


func _ready() -> void:
	_flow = get_node(flow_path) as GameFlow
	_skills = SkillConfig.load_from_file()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DEV_LOCKED_ARG):
			_hint_id = arg.trim_prefix(DEV_LOCKED_ARG)
		elif arg == DEV_KIEP_HINT_ARG:
			_kiep_hint = true


# Redraws every frame, also while inactive: a CanvasItem keeps its last frame until the next
# redraw, and a transparent screen drawn later (the chapter map) would show the stale title.
func _process(_delta: float) -> void:
	queue_redraw()


## The id whose unlock condition the strip shows ("" = none yet).
func get_hint_id() -> String:
	return _hint_id


## Story 037 / 038: the card rectangles; they end at [constant CARDS_BOTTOM] of the height (the Kiep panel is under them).
func card_rects(vp: Vector2) -> Array[Rect2]:
	var ids: Array[String] = _flow.get_characters().ids()
	var rects: Array[Rect2] = ScreenLayout.character_card_rects(vp, ids.size())
	for i: int in rects.size():
		rects[i].size.y = vp.y * CARDS_BOTTOM - rects[i].position.y
	return rects


## Story 038: the focused card's id: the flow's selected character when unlocked, else the default / first unlocked one.
func focus_id() -> String:
	var id: String = _flow.get_character_id()
	if not id.is_empty() and _is_unlocked(id):
		return id
	var default_id: String = _flow.get_characters().default_id()
	if _is_unlocked(default_id):
		return default_id
	var unlocked: Array[String] = _flow.get_characters().unlocked_ids()
	return unlocked[0] if not unlocked.is_empty() else ""


## Story 038: the level bar rectangle (full width between the margins).
static func bar_rect(vp: Vector2) -> Rect2:
	var margin: float = vp.x * ScreenLayout.MARGIN_RATIO
	return Rect2(margin, vp.y * BAR_TOP, vp.x - margin * 2.0, vp.y * BAR_HEIGHT)


## Story 038: the "-" button at the left edge of the bar (>= 96 px wide and high at 1280x720).
static func minus_rect(vp: Vector2) -> Rect2:
	var bar: Rect2 = bar_rect(vp)
	return Rect2(bar.position.x, bar.position.y, vp.x * BAR_BUTTON_WIDTH_RATIO, bar.size.y)


## Story 038: the "+" button at the right edge of the bar.
static func plus_rect(vp: Vector2) -> Rect2:
	var bar: Rect2 = bar_rect(vp)
	var width: float = vp.x * BAR_BUTTON_WIDTH_RATIO
	return Rect2(bar.end.x - width, bar.position.y, width, bar.size.y)


## Story 038: the rules list rectangle (shorter while the locked-character strip is reserved).
func rules_rect(vp: Vector2) -> Rect2:
	var margin: float = vp.x * ScreenLayout.MARGIN_RATIO
	var bottom: float = RULES_BOTTOM_WITH_STRIP if _any_locked(_flow.get_characters().ids()) else RULES_BOTTOM
	return Rect2(margin, vp.y * RULES_TOP, vp.x - margin * 2.0, vp.y * (bottom - RULES_TOP))


## The strip under the cards (only meaningful while a card is locked).
static func strip_rect(vp: Vector2) -> Rect2:
	var margin: float = vp.x * ScreenLayout.MARGIN_RATIO
	return Rect2(margin, vp.y * STRIP_TOP, vp.x - margin * 2.0, vp.y * (STRIP_BOTTOM - STRIP_TOP))


func _any_locked(ids: Array[String]) -> bool:
	for id: String in ids:
		if not _is_unlocked(id):
			return true
	return false


## The strip text for locked character [param id]: the condition of the achievement that owns it, " - cur/target".
func locked_text(id: String) -> String:
	var cfg: AchievementsConfig = AchievementsConfig.shared()
	var owner_id: String = cfg.reward_owner(REWARD_KIND_CHARACTER, id)
	if owner_id.is_empty():
		return tr(TEXT_LOCKED_HINT)
	var info: Dictionary = UnlockRules.progress_of(cfg, owner_id, _flow.get_progress())
	return tr(TEXT_LOCKED_PROGRESS) % [tr(str(cfg.get_def(owner_id).get("desc_key", ""))), int(info.get("current", 0)), int(info.get("target", 1))]


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
	# Story 038: the rules list scrolls with a one-finger vertical drag (real events only; the emulated copies are ignored).
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
		if _drag_active and event.device != InputEvent.DEVICE_ID_EMULATION:
			var dy: float = (event as InputEventMouseMotion).relative.y if event is InputEventMouseMotion else (event as InputEventScreenDrag).relative.y
			_scroll_rules(-dy)
			get_viewport().set_input_as_handled()
		return
	if (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed):
		_drag_active = false
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
	var real: bool = event.device != InputEvent.DEVICE_ID_EMULATION
	if minus_rect(vp).has_point(pos) or plus_rect(vp).has_point(pos):
		get_viewport().set_input_as_handled()
		if real:
			_step_level(-1 if minus_rect(vp).has_point(pos) else 1)
		return
	if rules_rect(vp).has_point(pos):
		get_viewport().set_input_as_handled()
		_drag_active = real
		return
	var ids: Array[String] = _flow.get_characters().ids()
	var rects: Array[Rect2] = card_rects(vp)
	for i: int in rects.size():
		if rects[i].has_point(pos):
			get_viewport().set_input_as_handled()
			if real:
				if not _is_unlocked(ids[i]):
					_hint_id = ids[i]
				elif ids[i] == focus_id():
					_flow.character_chosen(ids[i])
				else:
					_flow.set_character(ids[i])
					_kiep_hint = false
			return


# Story 038: one tap on "-" (delta -1) or "+" (delta +1). "+" above the unlocked level only shows the hint.
func _step_level(delta: int) -> void:
	var level: int = _flow.get_kiep_level()
	if delta < 0:
		_kiep_hint = false
		if level > 0:
			_flow.set_kiep_level(level - 1)
		return
	if _flow.set_kiep_level(level + 1):
		_kiep_hint = false
	else:
		_kiep_hint = true


# Story 038: moves the rules list by [param delta] px, clamped to its content.
func _scroll_rules(delta: float) -> void:
	var vp: Vector2 = get_viewport_rect().size
	_rules_scroll = clampf(_rules_scroll + delta, 0.0, _rules_max_scroll(vp))


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
	var rects: Array[Rect2] = card_rects(vp)
	for i: int in rects.size():
		_draw_card(rects[i], ids[i])
	_draw_kiep_bar(vp)
	_draw_kiep_rules(vp)
	if _any_locked(ids):
		_draw_strip(vp)


# Story 037: the unlock condition of the tapped locked card (or the hint to tap one).
func _draw_strip(vp: Vector2) -> void:
	var strip: Rect2 = strip_rect(vp)
	draw_rect(strip, STRIP_BACK)
	draw_rect(strip, CARD_LOCKED_OUTLINE, false, OUTLINE_WIDTH)
	var text: String = locked_text(_hint_id) if not _hint_id.is_empty() else tr(TEXT_LOCKED_HINT)
	var pad: float = strip.size.x * 0.02
	var size: int = _fit(text, strip.size.x - pad * 2.0, STRIP_FONT_SIZE)
	draw_string(ThemeDB.fallback_font, Vector2(strip.position.x + pad, strip.get_center().y + size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, strip.size.x - pad * 2.0, size, STRIP_TEXT_COLOR if not _hint_id.is_empty() else LOCKED_TEXT)


func _draw_card(rect: Rect2, id: String) -> void:
	var character: Dictionary = _flow.get_characters().get_character(id)
	var locked: bool = not bool(character.get("unlocked", false))
	var pressed: bool = not locked and UiButtons.is_pressed_at(self, rect)
	var picked: bool = locked and id == _hint_id
	var focused: bool = not locked and id == focus_id()
	draw_rect(rect, CARD_LOCKED_BACK if locked else CARD_OPEN_BACK)
	if pressed or picked:
		draw_rect(rect, CARD_PRESSED_OUTLINE, false, PRESSED_OUTLINE_WIDTH)
	elif focused:
		draw_rect(rect, KIEP_FOCUS_OUTLINE, false, FOCUS_OUTLINE_WIDTH)
	else:
		draw_rect(rect, CARD_LOCKED_OUTLINE if locked else CARD_OPEN_OUTLINE, false, OUTLINE_WIDTH)
	var scale: float = MIN_FONT_SCALE
	var pad: float = rect.size.x * CARD_PAD_RATIO
	var inner := Rect2(rect.position.x + pad, rect.position.y, rect.size.x - pad * 2.0, rect.size.y)
	var name_color: Color = LOCKED_TEXT if locked else NAME_COLOR
	var hp_color: Color = LOCKED_TEXT if locked else HP_COLOR
	var body_color: Color = LOCKED_TEXT if locked else BODY_COLOR
	var passive_color: Color = LOCKED_TEXT if locked else PASSIVE_COLOR
	var name_text: String = tr(str(character.get("name_key", id)))
	_text(inner, _y(rect, NAME_BASELINE), name_text, _fit(name_text, inner.size.x, _fs(NAME_FONT_SIZE, scale)), name_color)
	_text(inner, _y(rect, HP_BASELINE), tr(TEXT_HP) % int(float(character.get("max_hp", 0.0))), _fs(HP_FONT_SIZE, scale), hp_color)
	if not locked:
		_draw_kiep_badge(rect, id)
	_wrapped(inner, _y(rect, DESC_BASELINE), tr(str(character.get("desc_key", ""))), _fs(DESC_FONT_SIZE, scale), DESC_MAX_LINES, body_color)
	_divider(inner, _y(rect, DIVIDER_1))
	var passive_name: String = tr(str(character.get("passive_name_key", "")))
	_text(inner, _y(rect, PASSIVE_NAME_BASELINE), passive_name, _fit(passive_name, inner.size.x, _fs(PASSIVE_NAME_FONT_SIZE, scale)), passive_color)
	_wrapped(inner, _y(rect, PASSIVE_DESC_BASELINE), tr(str(character.get("passive_desc_key", ""))), _fs(PASSIVE_DESC_FONT_SIZE, scale), PASSIVE_DESC_MAX_LINES, body_color)
	_divider(inner, _y(rect, DIVIDER_2))
	_text(inner, _y(rect, DECK_HEADER_BASELINE), tr(TEXT_DECK), _fs(DECK_HEADER_FONT_SIZE, scale), name_color)
	_wrapped(inner, _y(rect, DECK_BASELINE), _deck_summary(id), _fs(DECK_FONT_SIZE, scale), DECK_MAX_LINES, body_color)
	var signature_id: String = _signature_id(character)
	if not locked and not signature_id.is_empty():
		_divider(inner, _y(rect, DIVIDER_3))
		var key_base: String = SIGNATURE_KEY_PREFIX + signature_id
		var sig_text: String = tr(TEXT_SIGNATURE) % tr(key_base + SIGNATURE_NAME_SUFFIX)
		_text(inner, _y(rect, SIGNATURE_NAME_BASELINE), sig_text, _fit(sig_text, inner.size.x, _fs(SIGNATURE_NAME_FONT_SIZE, scale)), SIGNATURE_COLOR)
		_wrapped(inner, _y(rect, SIGNATURE_DESC_BASELINE), tr(key_base + SIGNATURE_DESC_SUFFIX), _fs(SIGNATURE_DESC_FONT_SIZE, scale), SIGNATURE_DESC_MAX_LINES, body_color)
	if locked:
		_draw_padlock(rect)


# Story 038: the "Kiếp N" badge (N = best level won, hidden at -1) at the right end of the HP line of an unlocked card.
func _draw_kiep_badge(rect: Rect2, id: String) -> void:
	var best: int = _flow.kiep_best_for(id)
	if best < 0:
		return
	var text: String = tr(TEXT_KIEP_BADGE) % best
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, KIEP_BADGE_FONT_SIZE).x + 8.0
	var badge := Rect2(rect.end.x - width - 4.0, _y(rect, HP_BASELINE) - KIEP_BADGE_FONT_SIZE - 3.0, width, KIEP_BADGE_FONT_SIZE + 8.0)
	draw_rect(badge, KIEP_BADGE_BACK)
	draw_string(font, Vector2(badge.position.x, badge.get_center().y + KIEP_BADGE_FONT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, KIEP_BADGE_FONT_SIZE, KIEP_BADGE_TEXT)


# Story 038: the level bar of the focused card: "-" | caption, the big level, a hint line | "+".
func _draw_kiep_bar(vp: Vector2) -> void:
	var id: String = focus_id()
	if id.is_empty():
		return
	var level: int = _flow.get_kiep_level()
	var unlocked: int = _flow.kiep_unlocked_for(id)
	var minus: Rect2 = minus_rect(vp)
	var plus: Rect2 = plus_rect(vp)
	UiButtons.draw_button(self, minus, "-", UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, minus), level > 0, KIEP_BUTTON_FONT_SIZE, OUTLINE_WIDTH)
	var can_up: bool = level < KiepRules.shared().max_level() and level < unlocked
	UiButtons.draw_button(self, plus, "+", UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, plus), can_up, KIEP_BUTTON_FONT_SIZE, OUTLINE_WIDTH)
	var bar: Rect2 = bar_rect(vp)
	var middle := Rect2(minus.end.x, bar.position.y, plus.position.x - minus.end.x, bar.size.y)
	var name_text: String = tr(str(_flow.get_characters().get_character(id).get("name_key", id)))
	var caption: String = name_text + " · " + tr(TEXT_KIEP_LABEL)
	_text(middle, middle.position.y + KIEP_CAPTION_FONT_SIZE + 2.0, caption, _fit(caption, middle.size.x, KIEP_CAPTION_FONT_SIZE), BODY_COLOR)
	_text(middle, middle.position.y + middle.size.y * 0.72, str(level), KIEP_NUMBER_FONT_SIZE, KIEP_NUMBER_COLOR)
	var hint: String = tr(TEXT_KIEP_LOCKED_HINT) % unlocked if _kiep_hint else tr(TEXT_TAP_TO_START)
	var hint_color: Color = KIEP_HINT_COLOR if _kiep_hint else LOCKED_TEXT
	_text(middle, middle.end.y - 5.0, hint, _fit(hint, middle.size.x, KIEP_HINT_FONT_SIZE), hint_color)


# Story 038: the active-rules lines of the selected level, "k. rule", level 1 first (the newest last).
func _rules_lines() -> Array[String]:
	var lines: Array[String] = []
	var keys: Array[String] = _flow.get_kiep_rules_keys(_flow.get_kiep_level())
	for i: int in keys.size():
		lines.append(tr(TEXT_KIEP_RULE_LINE) % [i + 1, tr(keys[i])])
	return lines


# Height of the scrollable lines (the title row is fixed above them).
func _rules_view_height(vp: Vector2) -> float:
	var rows: int = maxi(floori((rules_rect(vp).size.y - KIEP_RULES_HEADER_HEIGHT) / KIEP_RULES_LINE_HEIGHT), 1)
	return rows * KIEP_RULES_LINE_HEIGHT


func _rules_max_scroll(vp: Vector2) -> float:
	return maxf(_rules_lines().size() * KIEP_RULES_LINE_HEIGHT - _rules_view_height(vp), 0.0)


# The scroll offset snapped to whole lines (a half-cut line cannot be clipped in a plain draw).
func _rules_scroll_snapped(vp: Vector2) -> float:
	return clampf(snappedf(_rules_scroll, KIEP_RULES_LINE_HEIGHT), 0.0, _rules_max_scroll(vp))


# Story 038: the title row and the rules of levels 1..k (the newest highlighted); the list starts scrolled to its end.
func _draw_kiep_rules(vp: Vector2) -> void:
	var rect: Rect2 = rules_rect(vp)
	draw_rect(rect, KIEP_RULES_BACK)
	draw_rect(rect, CARD_LOCKED_OUTLINE, false, DIVIDER_WIDTH)
	var font: Font = ThemeDB.fallback_font
	var pad: float = 12.0
	var lines: Array[String] = _rules_lines()
	var title: String = tr(TEXT_KIEP_RULES_TITLE) if not lines.is_empty() else tr(TEXT_KIEP_NONE)
	draw_string(font, Vector2(rect.position.x + pad, rect.position.y + KIEP_RULES_FONT_SIZE + 1.0), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0, KIEP_RULES_FONT_SIZE, PASSIVE_COLOR)
	if lines.is_empty():
		return
	var level: int = _flow.get_kiep_level()
	if _rules_scroll < 0.0 or _rules_for_level != level:
		_rules_for_level = level
		_rules_scroll = _rules_max_scroll(vp)
	_rules_scroll = clampf(_rules_scroll, 0.0, _rules_max_scroll(vp))
	var view := Rect2(rect.position.x, rect.position.y + KIEP_RULES_HEADER_HEIGHT, rect.size.x, _rules_view_height(vp))
	var top_y: float = view.position.y - _rules_scroll_snapped(vp)
	for i: int in lines.size():
		var y: float = top_y + KIEP_RULES_LINE_HEIGHT * (i + 1)
		# Whole lines only (the scroll is snapped to lines); the ones outside the list are skipped.
		if y - KIEP_RULES_LINE_HEIGHT < view.position.y - 1.0 or y > view.end.y + 1.0:
			continue
		var color: Color = KIEP_NEWEST_COLOR if i == lines.size() - 1 else KIEP_RULE_COLOR
		draw_string(font, Vector2(rect.position.x + pad, y - 5.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0, KIEP_RULES_FONT_SIZE, color)


# Font size [param base] scaled by [param scale], never below MIN_FONT_SIZE.
func _fs(base: int, scale: float) -> int:
	return maxi(roundi(base * scale), MIN_FONT_SIZE)


# The largest size from [param size] down to MIN_FONT_SIZE whose one-line [param text] fits [param width].
func _fit(text: String, width: float, size: int) -> int:
	while size > MIN_FONT_SIZE and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > width:
		size -= 1
	return size


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


# The character's signature id (characters.json signature.id); "" when it has none.
func _signature_id(character: Dictionary) -> String:
	var raw: Variant = character.get("signature")
	if raw is Dictionary:
		return str((raw as Dictionary).get("id", ""))
	return ""

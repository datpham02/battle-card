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

## 2026-10-31 dark skin (HudSkin): card faces (CARD_FILL, Mist edge; the focused card Grid Light 3 px; a pressed /
## picked card an Ivory edge), Night Stone panels, outlined text. HP reads in the player-HP green (red is reserved for
## enemy telegraphs); the passive blue and the signature accent are lightened to read on the dark field.
const TITLE_COLOR: Color = HudSkin.IVORY
const CARD_OPEN_BACK: Color = HudSkin.CARD_FILL
const CARD_OPEN_OUTLINE: Color = HudSkin.CARD_LINE
const CARD_LOCKED_BACK: Color = HudSkin.NIGHT_STONE
const CARD_LOCKED_OUTLINE: Color = Color("7D889699")
const CARD_PRESSED_OUTLINE: Color = HudSkin.IVORY
const NAME_COLOR: Color = HudSkin.IVORY
const HP_COLOR: Color = HudSkin.HP_FILL
const BODY_COLOR: Color = HudSkin.TEXT_DIM
const PASSIVE_COLOR: Color = Color("7FB8E0")
const DIVIDER_COLOR: Color = Color("7D889680")
const LOCKED_TEXT: Color = HudSkin.MIST
const PADLOCK_COLOR: Color = HudSkin.MIST
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
const SIGNATURE_COLOR: Color = HudSkin.GRID_LIGHT
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
const STRIP_BACK: Color = HudSkin.NIGHT_STONE
const STRIP_TEXT_COLOR: Color = HudSkin.GRID_LIGHT
const DEV_KIEP_HINT_ARG: String = "--screen=kiep_hint"
## DEV-ONLY (captures): `--screen=character_info=<id>` opens that character's info panel.
const DEV_INFO_ARG: String = "--screen=character_info="
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
const KIEP_BADGE_TEXT: Color = HudSkin.TEXT
const KIEP_FOCUS_OUTLINE: Color = HudSkin.GRID_LIGHT
const KIEP_RULES_BACK: Color = HudSkin.NIGHT_STONE
const KIEP_RULE_COLOR: Color = HudSkin.TEXT_DIM
const KIEP_NEWEST_COLOR: Color = HudSkin.GRID_LIGHT
const KIEP_HINT_COLOR: Color = Color("E89A6E")
const KIEP_NUMBER_COLOR: Color = HudSkin.IVORY
const FOCUS_OUTLINE_WIDTH: float = 6.0
## 2026-11-07 hero cards: the "i" button (share of the card width, touch minimum, inset), the hero sprite area (shares of
## the card height: top, feet line) and the info panel (shares of the screen).
const INFO_BUTTON_RATIO: float = 0.2
const INFO_BUTTON_MIN_PX: float = 44.0
const INFO_BUTTON_INSET_PX: float = 8.0
## Px from the card's top-right corner to the info gem's centre (the gem sits on the rim's corner).
const INFO_GEM_FROM_CORNER_PX: float = 22.0
const SPRITE_TOP: float = 0.13
## Px the name and HP lines sit lower than their old baselines (clear of the plate's rim).
const CARD_TEXT_DROP_PX: float = 14.0
const SPRITE_FEET: float = 0.95
const SPRITE_CLIP: String = "idle"
const LOCKED_SILHOUETTE: Color = Color(0.06, 0.05, 0.09, 0.92)
const INFO_PANEL_W: float = 0.64
const INFO_PANEL_TOP: float = 0.13
const INFO_PANEL_H: float = 0.8
const INFO_SHADE: Color = Color(0.0, 0.0, 0.0, 0.6)
const INFO_PAD_PX: float = 28.0
const INFO_GAP_PX: float = 10.0
const INFO_GLYPH_COLOR: Color = HudSkin.IVORY

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
## 2026-11-07 (user: show the hero, and a button to read the hero's info): the character whose info panel is open
## ("" = closed) and the clock (s) of the idle animation the cards play.
var _info_id: String = ""
var _anim_time: float = 0.0
## 2026-11-07 (user: the names were big and small): one font size for every card name, set each draw.
var _name_size: int = NAME_FONT_SIZE


func _ready() -> void:
	# 2026-11-01: crisp pixel frames (PixelFrame) and the menu font (MenuFont) on every menu screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flow = get_node(flow_path) as GameFlow
	_skills = SkillConfig.load_from_file()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(DEV_LOCKED_ARG):
			_hint_id = arg.trim_prefix(DEV_LOCKED_ARG)
		elif arg == DEV_KIEP_HINT_ARG:
			_kiep_hint = true
		elif arg.begins_with(DEV_INFO_ARG):
			_info_id = arg.trim_prefix(DEV_INFO_ARG)


# Redraws every frame, also while inactive: a CanvasItem keeps its last frame until the next
# redraw, and a transparent screen drawn later (the chapter map) would show the stale title.
func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()


## 2026-11-07: the "i" button of card [param card] (top-right inside the plate's gold line, a touch-size square).
static func info_button_rect(card: Rect2) -> Rect2:
	var edge: float = INFO_BUTTON_MIN_PX
	var c := Vector2(card.end.x - INFO_GEM_FROM_CORNER_PX, card.position.y + INFO_GEM_FROM_CORNER_PX)
	return Rect2(c - Vector2.ONE * edge * 0.5, Vector2.ONE * edge)


## 2026-11-07: the info panel (centred over the cards and the level bar).
static func info_panel_rect(vp: Vector2) -> Rect2:
	var w: float = vp.x * INFO_PANEL_W
	return Rect2((vp.x - w) * 0.5, vp.y * INFO_PANEL_TOP, w, vp.y * INFO_PANEL_H)


## 2026-11-07: the info panel's close button (top-right of the panel).
static func info_close_rect(vp: Vector2) -> Rect2:
	var panel: Rect2 = info_panel_rect(vp)
	return Rect2(panel.end.x - INFO_BUTTON_MIN_PX - INFO_BUTTON_INSET_PX * 2.0, panel.position.y + INFO_BUTTON_INSET_PX * 2.0, INFO_BUTTON_MIN_PX, INFO_BUTTON_MIN_PX)


## The character whose info panel is open ("" = none).
func get_info_id() -> String:
	return _info_id


## Opens the info panel of [param id] ("" closes it).
func show_info(id: String) -> void:
	_info_id = id


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
	var margin: float = ScreenLayout.side_margin(vp)
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
	var margin: float = ScreenLayout.side_margin(vp)
	var bottom: float = RULES_BOTTOM_WITH_STRIP if _any_locked(_flow.get_characters().ids()) else RULES_BOTTOM
	return Rect2(margin, vp.y * RULES_TOP, vp.x - margin * 2.0, vp.y * (bottom - RULES_TOP))


## The strip under the cards (only meaningful while a card is locked).
static func strip_rect(vp: Vector2) -> Rect2:
	var margin: float = ScreenLayout.side_margin(vp)
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
		if not _info_id.is_empty():
			if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
				get_viewport().set_input_as_handled()
				_info_id = ""
			return
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
	# 2026-11-07: an open info panel takes every tap: the close button or a tap outside the panel closes it.
	if not _info_id.is_empty():
		get_viewport().set_input_as_handled()
		if event.device != InputEvent.DEVICE_ID_EMULATION and (info_close_rect(vp).has_point(pos) or not info_panel_rect(vp).has_point(pos)):
			_info_id = ""
		return
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
			if real and info_button_rect(rects[i]).has_point(pos):
				_info_id = ids[i]
			elif real:
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
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR, true)
	var back: Rect2 = ScreenLayout.back_button_rect(vp)
	UiButtons.draw_button(self, back, tr(TEXT_BACK), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, back), true, BUTTON_FONT_SIZE, OUTLINE_WIDTH)
	var ids: Array[String] = _flow.get_characters().ids()
	var rects: Array[Rect2] = card_rects(vp)
	_name_size = _uniform_name_size(rects, ids)
	for i: int in rects.size():
		_draw_card(rects[i], ids[i])
	_draw_kiep_bar(vp)
	_draw_kiep_rules(vp)
	if _any_locked(ids):
		_draw_strip(vp)
	if not _info_id.is_empty():
		_draw_info(vp, _info_id)


# Story 037: the unlock condition of the tapped locked card (or the hint to tap one).
func _draw_strip(vp: Vector2) -> void:
	var strip: Rect2 = strip_rect(vp)
	HudSkin.plate_panel(self, strip, "navy")
	var text: String = locked_text(_hint_id) if not _hint_id.is_empty() else tr(TEXT_LOCKED_HINT)
	var pad: float = strip.size.x * 0.02
	var size: int = _fit(text, strip.size.x - pad * 2.0, STRIP_FONT_SIZE)
	MenuFont.text(self, Vector2(strip.position.x + pad, strip.get_center().y + size * 0.35), text, size, STRIP_TEXT_COLOR if not _hint_id.is_empty() else HudSkin.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, strip.size.x - pad * 2.0)


# 2026-11-07 (user: show the hero, and a button for the info): an ancient plate (grey when locked, gold ring on the
# focused card, sunk while pressed) with the name, the HP line, the hero's idle animation (a dark silhouette and a
# padlock while locked) and the "i" button; the rules text lives in the info panel ([method _draw_info]).
func _draw_card(rect: Rect2, id: String) -> void:
	var character: Dictionary = _flow.get_characters().get_character(id)
	var locked: bool = not bool(character.get("unlocked", false))
	var info: Rect2 = info_button_rect(rect)
	var pressed: bool = not locked and UiButtons.is_pressed_at(self, rect) and not UiButtons.is_pressed_at(self, info)
	var picked: bool = locked and id == _hint_id
	var focused: bool = not locked and id == focus_id()
	HudSkin.plate_panel(self, rect, "grey" if locked else "navy", pressed, 1.0, focused or picked)
	var name_color: Color = LOCKED_TEXT if locked else NAME_COLOR
	var hp_color: Color = LOCKED_TEXT if locked else HP_COLOR
	var name_box := Rect2(rect.position.x + info.size.x, rect.position.y, rect.size.x - info.size.x * 2.0, rect.size.y)
	var name_text: String = tr(str(character.get("name_key", id)))
	_text(name_box, _y(rect, NAME_BASELINE) + CARD_TEXT_DROP_PX, name_text, _name_size, name_color, true)
	# 2026-11-07 (user: no HP on the card): HP is in the info panel only.
	var _unused_hp: Color = hp_color
	if not locked:
		_draw_kiep_badge(rect, id)
	var area := Rect2(rect.position.x, _y(rect, SPRITE_TOP), rect.size.x, _y(rect, SPRITE_FEET) - _y(rect, SPRITE_TOP))
	_draw_hero(area.grow_individual(-INFO_BUTTON_INSET_PX * 2.0, 0.0, -INFO_BUTTON_INSET_PX * 2.0, 0.0), id, locked)
	if locked:
		_draw_padlock(rect)
	_draw_info_button(info, locked)


# The largest size (<= NAME_FONT_SIZE) at which EVERY card's name fits its name box, so all names share one size.
func _uniform_name_size(rects: Array[Rect2], ids: Array[String]) -> int:
	var size: int = NAME_FONT_SIZE
	for i: int in rects.size():
		var info: Rect2 = info_button_rect(rects[i])
		var width: float = rects[i].size.x - info.size.x * 2.0
		var name_text: String = tr(str(_flow.get_characters().get_character(ids[i]).get("name_key", ids[i])))
		size = mini(size, _fit(name_text, width, NAME_FONT_SIZE, true))
	return size


## Pure: the frame of [param clip] to show at [param t] seconds (durations in ms; 0-ms frames count as 100 ms; loops).
static func clip_frame_at(clip: Dictionary, t: float) -> int:
	var durations: Array = clip.get("durations_ms", [])
	var frames: Array = clip.get("frames", [])
	if frames.is_empty():
		return -1
	var total: int = 0
	for i: int in frames.size():
		total += _frame_ms(durations, i)
	var ms: int = int(t * 1000.0) % total
	for i: int in frames.size():
		var d: int = _frame_ms(durations, i)
		if ms < d:
			return i
		ms -= d
	return frames.size() - 1


static func _frame_ms(durations: Array, i: int) -> int:
	var d: int = int(durations[i]) if i < durations.size() else 0
	return d if d > 0 else 100


# The hero's idle clip (SpriteSheet unit_<id>), whole-number scaled to fit [param area], feet on its bottom, centred;
# a dark silhouette while [param locked]. Nothing when the sheet or its texture is missing.
func _draw_hero(area: Rect2, id: String, locked: bool) -> void:
	var sheet: SpriteSheet = SpriteSheet.load_unit(id)
	if sheet == null or sheet.texture() == null or not sheet.has_clip(SPRITE_CLIP):
		return
	var clip: Dictionary = sheet.clip(SPRITE_CLIP)
	var index: int = clip_frame_at(clip, 0.0 if locked else _anim_time)
	if index < 0:
		return
	# The body rows only (bottom-aligned frames): a taller frame for a raised-weapon clip must not shrink the portrait.
	var src: Rect2i = sheet.body_rect((clip["frames"] as Array)[index])
	# Scaled by the height (the frames carry wide empty sides for weapons and casts); what overflows the card's width
	# is cropped evenly from both sides, in whole art px.
	var k: int = maxi(floori(area.size.y / src.size.y), 1)
	var vis_w: int = mini(src.size.x, floori(area.size.x / k))
	@warning_ignore("integer_division")
	var crop := Rect2i(src.position.x + (src.size.x - vis_w) / 2, src.position.y, vis_w, src.size.y)
	var size := Vector2(crop.size) * k
	var dst := Rect2(Vector2(roundf(area.get_center().x - size.x * 0.5), roundf(area.end.y - size.y)), size)
	draw_texture_rect_region(PixelFrame.nearest(sheet.texture()), dst, Rect2(crop), LOCKED_SILHOUETTE if locked else Color.WHITE)


# 2026-11-07 (user: the "i" button should feel part of the card): a pixel gem (CardFace's, blue; grey on a locked card)
# set on the card's top-right rim like the cell gem of a skill card, with an Ivory "i" cut into it; [param rect] is the
# touch square around it, the gem darkens while pressed.
func _draw_info_button(rect: Rect2, locked: bool) -> void:
	var s: int = PixelFrame.scale_for(get_viewport_rect().size.y)
	var edge: float = float(CardFace.V2_GEM_ART * s)
	var box := Rect2((rect.get_center() - Vector2.ONE * edge * 0.5).round(), Vector2.ONE * edge)
	var tint: Color = CardFace.PRESSED_TINT if UiButtons.is_pressed_at(self, rect) else Color.WHITE
	CardFace._draw_pixel_gem(self, box, s, CardFace.GEM_DULL if locked else CardFace.GEM_BLUE, tint)
	var c: Vector2 = box.get_center()
	var w: float = float(s * 2)
	var ink := Color("081327")
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_rect(Rect2(c.x - w * 0.5 + o.x, c.y - w * 2.5 + o.y, w, w), ink)
		draw_rect(Rect2(c.x - w * 0.5 + o.x, c.y - w + o.y, w, w * 3.0 + o.y * 0.0), ink)
	draw_rect(Rect2(c.x - w * 0.5, c.y - w * 2.5, w, w), INFO_GLYPH_COLOR)
	draw_rect(Rect2(c.x - w * 0.5, c.y - w, w, w * 3.0), INFO_GLYPH_COLOR)


# 2026-11-07: the info panel of [param id] over a shade: name, HP, description, passive, starter deck, Awakening (and
# the unlock condition while locked), top to bottom; the close button top-right.
func _draw_info(vp: Vector2, id: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), INFO_SHADE)
	var panel: Rect2 = info_panel_rect(vp)
	var body: Rect2 = HudSkin.plate_panel(self, panel, "navy")
	var close: Rect2 = info_close_rect(vp)
	var cb: Rect2 = HudSkin.plate_panel(self, close, "navy", UiButtons.is_pressed_at(self, close))
	var arm: float = cb.size.x * 0.22
	var cc: Vector2 = cb.get_center()
	draw_line(cc - Vector2(arm, arm), cc + Vector2(arm, arm), INFO_GLYPH_COLOR, 4.0)
	draw_line(cc + Vector2(-arm, arm), cc + Vector2(arm, -arm), INFO_GLYPH_COLOR, 4.0)
	var character: Dictionary = _flow.get_characters().get_character(id)
	var locked: bool = not bool(character.get("unlocked", false))
	var inner := Rect2(body.position.x + INFO_PAD_PX, body.position.y, body.size.x - INFO_PAD_PX * 2.0, body.size.y)
	var y: float = body.position.y + INFO_PAD_PX + NAME_FONT_SIZE
	var name_text: String = tr(str(character.get("name_key", id)))
	_text(inner, y, name_text, _fit(name_text, inner.size.x - close.size.x * 2.0, NAME_FONT_SIZE + 6, true), NAME_COLOR, true)
	y += HP_FONT_SIZE + INFO_GAP_PX
	_text(inner, y, tr(TEXT_HP) % int(float(character.get("max_hp", 0.0))), HP_FONT_SIZE, HP_COLOR)
	y = _flow_wrapped(inner, y + INFO_GAP_PX + DESC_FONT_SIZE, tr(str(character.get("desc_key", ""))), DESC_FONT_SIZE, DESC_MAX_LINES, BODY_COLOR)
	y = _info_divider(inner, y)
	var passive_name: String = tr(str(character.get("passive_name_key", "")))
	_text(inner, y + PASSIVE_NAME_FONT_SIZE, passive_name, _fit(passive_name, inner.size.x, PASSIVE_NAME_FONT_SIZE, true), PASSIVE_COLOR, true)
	y = _flow_wrapped(inner, y + PASSIVE_NAME_FONT_SIZE + INFO_GAP_PX + DESC_FONT_SIZE, tr(str(character.get("passive_desc_key", ""))), DESC_FONT_SIZE, PASSIVE_DESC_MAX_LINES, BODY_COLOR)
	y = _info_divider(inner, y)
	_text(inner, y + DECK_HEADER_FONT_SIZE, tr(TEXT_DECK), DECK_HEADER_FONT_SIZE, NAME_COLOR, true)
	y = _flow_wrapped(inner, y + DECK_HEADER_FONT_SIZE + INFO_GAP_PX + DESC_FONT_SIZE, _deck_summary(id), DESC_FONT_SIZE, DECK_MAX_LINES, BODY_COLOR)
	var signature_id: String = _signature_id(character)
	if not signature_id.is_empty():
		y = _info_divider(inner, y)
		var key_base: String = SIGNATURE_KEY_PREFIX + signature_id
		var sig_text: String = tr(TEXT_SIGNATURE) % tr(key_base + SIGNATURE_NAME_SUFFIX)
		_text(inner, y + SIGNATURE_NAME_FONT_SIZE, sig_text, _fit(sig_text, inner.size.x, SIGNATURE_NAME_FONT_SIZE + 2, true), SIGNATURE_COLOR, true)
		y = _flow_wrapped(inner, y + SIGNATURE_NAME_FONT_SIZE + INFO_GAP_PX + DESC_FONT_SIZE, tr(key_base + SIGNATURE_DESC_SUFFIX), DESC_FONT_SIZE, SIGNATURE_DESC_MAX_LINES, BODY_COLOR)
	if locked:
		var lock_text: String = locked_text(id)
		_text(inner, body.end.y - INFO_PAD_PX, lock_text, _fit(lock_text, inner.size.x, STRIP_FONT_SIZE), STRIP_TEXT_COLOR)


# A divider under the block ending at [param y]; returns the next block's top.
func _info_divider(inner: Rect2, y: float) -> float:
	var at: float = y + INFO_GAP_PX
	_divider(inner, at)
	return at + INFO_GAP_PX


# _wrapped from baseline [param y]; returns the bottom of the drawn block.
func _flow_wrapped(rect: Rect2, y: float, text: String, size: int, max_lines: int, color: Color) -> float:
	if text.is_empty():
		return y - size
	_wrapped(rect, y, text, size, max_lines, color)
	var f: Font = HudSkin.font()
	var lines: int = mini(roundi(f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, max_lines).y / f.get_height(size)), max_lines)
	return y - size + f.get_height(size) * maxi(lines, 1)


# Story 038: the "Kiếp N" badge (N = best level won, hidden at -1) at the right end of the HP line of an unlocked card.
func _draw_kiep_badge(rect: Rect2, id: String) -> void:
	var best: int = _flow.kiep_best_for(id)
	if best < 0:
		return
	var text: String = tr(TEXT_KIEP_BADGE) % best
	var width: float = HudSkin.text_width(text, KIEP_BADGE_FONT_SIZE, true) + 8.0
	var badge := Rect2(rect.end.x - width - 4.0, _y(rect, HP_BASELINE) - KIEP_BADGE_FONT_SIZE - 3.0, width, KIEP_BADGE_FONT_SIZE + 8.0)
	HudSkin.panel(self, badge, [0.0, 3.0, 0.0, 3.0], KIEP_BADGE_BACK, HudSkin.IVORY, 1.0)
	MenuFont.text(self, Vector2(badge.position.x, badge.get_center().y + KIEP_BADGE_FONT_SIZE * 0.35), text, KIEP_BADGE_FONT_SIZE, KIEP_BADGE_TEXT, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, true)


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
	_text(middle, middle.position.y + middle.size.y * 0.72, str(level), KIEP_NUMBER_FONT_SIZE, KIEP_NUMBER_COLOR, true)
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
	HudSkin.plate_panel(self, rect, "navy")
	var pad: float = 16.0
	var lines: Array[String] = _rules_lines()
	var title: String = tr(TEXT_KIEP_RULES_TITLE) if not lines.is_empty() else tr(TEXT_KIEP_NONE)
	MenuFont.text(self, Vector2(rect.position.x + pad, rect.position.y + KIEP_RULES_FONT_SIZE + 8.0), title, KIEP_RULES_FONT_SIZE, PASSIVE_COLOR, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0, true)
	if lines.is_empty():
		return
	var level: int = _flow.get_kiep_level()
	if _rules_scroll < 0.0 or _rules_for_level != level:
		_rules_for_level = level
		_rules_scroll = _rules_max_scroll(vp)
	_rules_scroll = clampf(_rules_scroll, 0.0, _rules_max_scroll(vp))
	var view := Rect2(rect.position.x, rect.position.y + KIEP_RULES_HEADER_HEIGHT + 7.0, rect.size.x, _rules_view_height(vp))
	var top_y: float = view.position.y - _rules_scroll_snapped(vp)
	for i: int in lines.size():
		var y: float = top_y + KIEP_RULES_LINE_HEIGHT * (i + 1)
		# Whole lines only (the scroll is snapped to lines); the ones outside the list are skipped.
		if y - KIEP_RULES_LINE_HEIGHT < view.position.y - 1.0 or y > view.end.y + 1.0:
			continue
		var color: Color = KIEP_NEWEST_COLOR if i == lines.size() - 1 else KIEP_RULE_COLOR
		MenuFont.text(self, Vector2(rect.position.x + pad, y - 5.0), lines[i], KIEP_RULES_FONT_SIZE, color, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0)


# Font size [param base] scaled by [param scale], never below MIN_FONT_SIZE.
func _fs(base: int, scale: float) -> int:
	return maxi(roundi(base * scale), MIN_FONT_SIZE)


# The largest size from [param size] down to MIN_FONT_SIZE whose one-line [param text] fits [param width] (measured in
# the HudSkin font, Bold when [param bold]).
func _fit(text: String, width: float, size: int, bold: bool = false) -> int:
	while size > MIN_FONT_SIZE and HudSkin.text_width(text, size, bold) > width:
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


# Padlock: a filled body with an angular shackle above it (HudSkin.shackle_points; no circles in the UI).
func _draw_padlock(rect: Rect2) -> void:
	var body_size := Vector2(rect.size.x * LOCK_BODY_W, rect.size.y * LOCK_BODY_H)
	var center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * LOCK_CENTER_Y)
	var body := Rect2(center - body_size * 0.5, body_size)
	draw_rect(body, PADLOCK_COLOR)
	var radius: float = rect.size.x * LOCK_SHACKLE_R
	draw_polyline(HudSkin.shackle_points(center.x, body.position.y, radius), PADLOCK_COLOR, MARK_WIDTH)


# Baseline y for a share of the card height.
func _y(rect: Rect2, share: float) -> float:
	return rect.position.y + rect.size.y * share


func _divider(inner: Rect2, y: float) -> void:
	draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), DIVIDER_COLOR, DIVIDER_WIDTH)


# Centred single-line outlined text (HudSkin) at baseline [param y] over the width of [param rect]; Bold when [param bold].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, bold: bool = false) -> void:
	MenuFont.text(self, Vector2(rect.position.x, y), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, bold)


# Centred word-wrapped outlined text (HudSkin font) from baseline [param y], at most [param max_lines] lines, over the
# width of [param rect].
func _wrapped(rect: Rect2, y: float, text: String, size: int, max_lines: int, color: Color) -> void:
	if text.is_empty():
		return
	var f: Font = HudSkin.font()
	var pos := Vector2(rect.position.x, y)
	draw_multiline_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, max_lines, HudSkin.TEXT_OUTLINE_PX, Color(HudSkin.TEXT_OUTLINE, color.a))
	draw_multiline_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, max_lines, color)


# The character's signature id (characters.json signature.id); "" when it has none.
func _signature_id(character: Dictionary) -> String:
	var raw: Variant = character.get("signature")
	if raw is Dictionary:
		return str((raw as Dictionary).get("id", ""))
	return ""

class_name WorldMapView
extends Node2D
## World map screen (Story 031, Part D): the region pick at the start of every floor of a run.
## Title band: "Về title" (NEUTRAL, ScreenLayout.back_button_rect, hit-tested on
## ScreenLayout.touch_rect -> [method GameFlow.leave_run_keep_save]), "Tầng N/5 · Chọn vùng" and the
## hero's HP at the right. Under it a progress strip (ScreenLayout.world_strip_segment_rects): one
## segment per floor plus the final match ("Ấn Đài"); passed floors are filled and name the region
## chosen there, the current floor is bright gold, later ones dimmed. In the middle the offered
## regions ([method GameFlow.get_region_offer]) as large cards (ScreenLayout.world_card_rects: two
## pinned left / right, one per thumb; one centred when the pool offers a single region), each
## naming the region, a one-line description of its arena / enemies, its boss and the floor's
## difficulty from [method GameFlow.region_preview] ("Tầng 3 — máu địch ×1,3" + tempo / armour /
## attack-size extras when they apply).
## Touch, two steps so a stray tap never commits: the first tap on a card selects it (the card
## rises, gold outline) and shows the big "Vào vùng" button at the bottom edge under it (that
## thumb's side); a tap on the selected card again or on the button -> [method GameFlow.choose_region].
## A tap on the other card moves the selection. A notice banner — the restart notice
## ([method GameFlow.take_restart_notice], a pre-v5 save was restarted) or the floor-clear notice
## ([method GameFlow.take_floor_clear_notice]: "Tầng N — hồi X máu", the screen the run lands on
## after a region boss) — shows until the first tap, which only closes it. Enter / Keypad Enter /
## Space pick the first offer (DEV convenience, as the other views). Child of GameFlow (reads it
## through [member flow_path]); draws and takes input only in phase WORLD_MAP; owns no run state.
## Input dedup as in RunHudView (emulated copies — device == InputEvent.DEVICE_ID_EMULATION — are
## consumed but never act). Placeholder art drawn in code; all strings are TEXT_* keys through tr().

const TITLE_COLOR: Color = Color(0.15, 0.12, 0.1)
const HEADER_COLOR: Color = Color(0.4, 0.35, 0.3)
## Progress strip segments: passed floor, current floor, later floor, the final match.
const STRIP_PAST_BACK: Color = Color(0.82, 0.9, 0.8)
const STRIP_PAST_OUTLINE: Color = Color(0.2, 0.65, 0.3)
const STRIP_CURRENT_BACK: Color = Color(1.0, 0.93, 0.7)
const STRIP_CURRENT_OUTLINE: Color = Color(0.95, 0.72, 0.15)
const STRIP_FUTURE_BACK: Color = Color(0.8, 0.78, 0.74)
const STRIP_FUTURE_OUTLINE: Color = Color(0.58, 0.56, 0.52)
const STRIP_FINAL_BACK: Color = Color(0.45, 0.14, 0.12)
const STRIP_FINAL_OUTLINE: Color = Color(0.75, 0.15, 0.12)
const STRIP_TEXT: Color = Color(0.15, 0.12, 0.1)
const STRIP_DIM_TEXT: Color = Color(0.5, 0.48, 0.45)
const STRIP_FINAL_TEXT: Color = Color(1.0, 0.85, 0.6)
## Region cards: body, outline (rest / pressed / selected), the shadow left under a raised card,
## the header band colours (by card position, left first) and the text colours.
const CARD_BACK: Color = Color(1.0, 0.97, 0.9)
const CARD_OUTLINE: Color = Color(0.6, 0.52, 0.4)
const CARD_PRESSED_OUTLINE: Color = Color(1.0, 0.85, 0.2)
const CARD_SELECTED_OUTLINE: Color = Color(0.95, 0.72, 0.15)
const CARD_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.25)
const CARD_ACCENTS: Array[Color] = [Color(0.18, 0.42, 0.36), Color(0.5, 0.2, 0.2), Color(0.3, 0.28, 0.5)]
const CARD_NAME_TEXT: Color = Color(1.0, 0.97, 0.9)
const CARD_TEXT: Color = Color(0.15, 0.12, 0.1)
const CARD_DESC_TEXT: Color = Color(0.35, 0.3, 0.25)
const CARD_BOSS_TEXT: Color = Color(0.7, 0.15, 0.12)
const CARD_HINT_TEXT: Color = Color(0.5, 0.42, 0.3)
const CARD_HINT_SELECTED_TEXT: Color = Color(0.75, 0.5, 0.05)
const NOTICE_BACK: Color = Color(0.1, 0.09, 0.08, 0.96)
const NOTICE_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const NOTICE_TEXT: Color = Color(0.95, 0.9, 0.78)
const NOTICE_SUB_TEXT: Color = Color(0.75, 0.72, 0.65)

const OUTLINE_WIDTH: float = 3.0
const SELECTED_OUTLINE_WIDTH: float = 8.0
const TITLE_FONT_SIZE: int = 40
const HEADER_FONT_SIZE: int = 24
const STRIP_FLOOR_FONT_SIZE: int = 20
const STRIP_REGION_FONT_SIZE: int = 16
const CARD_NAME_FONT_SIZE: int = 40
const CARD_DESC_FONT_SIZE: int = 22
const CARD_LINE_FONT_SIZE: int = 26
const CARD_EXTRA_FONT_SIZE: int = 20
const CARD_HINT_FONT_SIZE: int = 22
const MIN_FIT_FONT_SIZE: int = 14
const BUTTON_FONT_SIZE: int = 24
## Story 031: the back button text shrinks to fit, not below this size; inset per side (pixels).
const BACK_MIN_FONT_SIZE: int = 14
const BACK_TEXT_INSET: float = 6.0
const ENTER_FONT_SIZE: int = 36
const NOTICE_FONT_SIZE: int = 30
const NOTICE_SUB_FONT_SIZE: int = 22
## The description may wrap to this many lines inside the card before it is cut.
const CARD_DESC_MAX_LINES: int = 2
## Strip segment baselines as shares of its height (floor label, region name).
const STRIP_FLOOR_BASELINE: float = 0.42
const STRIP_REGION_BASELINE: float = 0.82
## Card layout as shares of its height: the header band, the baselines of the name, the description
## (first line top), boss, difficulty, extras and the tap hint; the side inset as a share of its width.
const CARD_BAND_RATIO: float = 0.2
const CARD_NAME_BASELINE: float = 0.135
const CARD_DESC_TOP: float = 0.25
const CARD_BOSS_BASELINE: float = 0.55
const CARD_DIFFICULTY_BASELINE: float = 0.68
const CARD_EXTRA_BASELINE: float = 0.78
const CARD_HINT_BASELINE: float = 0.93
const CARD_INSET_RATIO: float = 0.05
## Offset of the shadow a raised card leaves on its rest position (pixels).
const SHADOW_OFFSET: Vector2 = Vector2(6.0, 6.0)
## Notice banner baselines as shares of its height.
const NOTICE_BASELINE: float = 0.45
const NOTICE_SUB_BASELINE: float = 0.8
const SEPARATOR: String = " · "

## "Tầng %d/%d · Chọn vùng": the current floor (1-based) and the floor count.
const TEXT_TITLE: String = "ui.world.title"
## "Tầng %d" on a strip segment.
const TEXT_STRIP_FLOOR: String = "ui.world.strip_floor"
## "Ấn Đài": the final match (strip segment, map title, HUD line).
const TEXT_FINAL_NAME: String = "ui.world.final_name"
## "Đang chọn" under the current floor's segment while no region is chosen there.
const TEXT_CHOOSING: String = "ui.world.choosing"
## "Boss: %s".
const TEXT_BOSS: String = "ui.world.boss"
## "Tầng %d — máu địch ×%s" (floor 1-based, the floor's hp_mult as a decimal).
const TEXT_DIFFICULTY: String = "ui.world.floor_difficulty"
## Extras of the floor scaling, each only when it changes something: "nhịp ×%s", "giáp +%d",
## "đòn +%d ô".
const TEXT_STEP: String = "ui.world.floor_step"
const TEXT_DEFENSE: String = "ui.world.floor_defense"
const TEXT_SIZE: String = "ui.world.floor_size"
## The decimal mark of the multipliers ("," in vi, "." in en).
const TEXT_DECIMAL_POINT: String = "ui.world.decimal_point"
## Tap hints at the card's bottom: "Chạm để chọn" / "Chạm lại để vào".
const TEXT_TAP_TO_PICK: String = "ui.world.tap_to_pick"
const TEXT_TAP_AGAIN: String = "ui.world.tap_again"
## The confirm button: "Vào vùng".
const TEXT_ENTER: String = "ui.world.enter"
## Floor-clear notice: "Tầng %d — hồi %d máu".
const TEXT_FLOOR_CLEAR: String = "ui.world.floor_clear"
## Floor-clear notice when the next match is the final one: "Ấn Đài — hồi %d máu".
const TEXT_FINAL_CLEAR: String = "ui.world.final_clear"
## Shared with ChapterMapView: back button, "HP %d/%d", the banner's "Chạm để đóng".
const TEXT_BACK: String = "ui.map.back"
const TEXT_HP: String = "ui.map.hp"
const TEXT_NOTICE_DISMISS: String = "ui.map.notice_dismiss"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow = null
## Story 032: owned-relic strip along the bottom band (tap an icon for its card).
var _strip: RelicStrip = null
## Region id of the selected card ("" = none): the first tap selects, the second confirms.
var _selected: String = ""
## Banner shown until the first tap: a string key ("" = none) and its format args (may be empty).
var _notice_key: String = ""
var _notice_args: Array = []


func _ready() -> void:
	_flow = get_node_or_null(flow_path) as GameFlow
	_strip = RelicStrip.new()
	add_child(_strip)


func _process(_delta: float) -> void:
	_sync_strip()
	if not _is_active():
		_selected = ""
		_notice_key = ""
		_notice_args = []
		queue_redraw()  # clear the last frame (see TitleView)
		return
	if _notice_key.is_empty():
		_pull_notice()
	if not _selected.is_empty() and not _flow.get_region_offer().has(_selected):
		_selected = ""
	queue_redraw()


## Story 031: the floor-clear banner line of [param notice] ([method GameFlow.take_floor_clear_notice]):
## "Tầng N — hồi X máu" (N = floor_number, 1-based), or "Ấn Đài — hồi X máu" when the next match is
## the final one. Shared with ChapterMapView, which shows it when the run goes straight to the final map.
static func floor_clear_text(notice: Dictionary) -> String:
	var healed: int = roundi(float(notice.get("healed", 0.0)))
	if bool(notice.get("is_final", false)):
		return TranslationServer.translate(TEXT_FINAL_CLEAR) % healed
	var number: int = int(notice.get("floor_number", int(notice.get("floor", 0)) + 1))
	return TranslationServer.translate(TEXT_FLOOR_CLEAR) % [number, healed]


## Region id of the selected card ("" when none) — for tests.
func get_selected_region() -> String:
	return _selected


## Translation key of the banner on screen ("" when none) — for tests.
func get_notice_key() -> String:
	return _notice_key


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.WORLD_MAP and _flow.get_run() != null


# Takes the next banner from the flow: the restart notice first, then the floor-clear notice.
func _pull_notice() -> void:
	var restart: String = _flow.take_restart_notice()
	if not restart.is_empty():
		_notice_key = restart
		_notice_args = []
		return
	var clear: Dictionary = _flow.take_floor_clear_notice()
	if not clear.is_empty():
		_notice_key = floor_clear_text(clear)
		_notice_args = []


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if not _notice_key.is_empty():
				_close_notice()
				return
			var offer: Array[String] = _flow.get_region_offer()
			if not offer.is_empty():
				_flow.choose_region(offer[0])
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device != InputEvent.DEVICE_ID_EMULATION and _strip.visible and _strip.handle_input(event):
		return
	var pos: Vector2 = _press_position(event)
	if pos == Vector2.INF or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if not _notice_key.is_empty():
		_close_notice()
		return
	_tap(pos)


# One real tap at [param pos] (no banner open).
func _tap(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if ScreenLayout.touch_rect(ScreenLayout.back_button_rect(vp)).has_point(pos):
		_flow.leave_run_keep_save()
		return
	var offer: Array[String] = _flow.get_region_offer()
	var cards: Array[Rect2] = ScreenLayout.world_card_rects(vp, offer.size())
	var selected_index: int = offer.find(_selected)
	if selected_index >= 0 and ScreenLayout.world_enter_button_rect(vp, cards[selected_index]).has_point(pos):
		_confirm()
		return
	for i: int in cards.size():
		if ScreenLayout.world_card_touch_rect(vp, cards[i]).has_point(pos):
			if offer[i] == _selected:
				_confirm()
			else:
				_selected = offer[i]
			return


func _confirm() -> void:
	var region: String = _selected
	_selected = ""
	_flow.choose_region(region)


# Closes the banner; the next one (a floor-clear notice after a restart notice) shows on the next frame.
func _close_notice() -> void:
	_notice_key = ""
	_notice_args = []


# Position of a left mouse press or a touch press; Vector2.INF for any other event.
func _press_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			return button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			return touch.position
	return Vector2.INF


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	_draw_header(vp)
	_draw_strip(vp)
	var offer: Array[String] = _flow.get_region_offer()
	var cards: Array[Rect2] = ScreenLayout.world_card_rects(vp, offer.size())
	for i: int in cards.size():
		_draw_card(vp, cards[i], offer[i], i)
	var selected_index: int = offer.find(_selected)
	if selected_index >= 0:
		var button: Rect2 = ScreenLayout.world_enter_button_rect(vp, cards[selected_index])
		UiButtons.draw_button(self, button, tr(TEXT_ENTER), UiButtons.Style.PRIMARY, UiButtons.is_pressed_at(self, button), true, ENTER_FONT_SIZE)
	if not _notice_key.is_empty():
		_draw_notice(vp)


# Title band: back button, "Tầng N/5 · Chọn vùng", the hero's HP at the right.
func _draw_header(vp: Vector2) -> void:
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	var count: int = _flow.get_floor_count()
	var text: String = tr(TEXT_TITLE) % [mini(_flow.get_floor() + 1, count), count]
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, text, TITLE_FONT_SIZE, TITLE_COLOR)
	var back: Rect2 = ScreenLayout.back_button_rect(vp)
	var back_text: String = tr(TEXT_BACK)
	UiButtons.draw_button(self, back, back_text, UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, ScreenLayout.touch_rect(back)), true, _back_font_size(back_text, back.size.x), OUTLINE_WIDTH)
	var run: RunSession = _flow.get_run()
	var character: Dictionary = _flow.get_characters().get_character(run.character_id)
	var max_hp: float = float(character.get("max_hp", 1.0))
	var hp: float = max_hp if run.hp < 0.0 else minf(run.hp, max_hp)
	var label: String = tr(str(character.get("name_key", run.character_id))) + SEPARATOR + tr(TEXT_HP) % [ceili(hp), ceili(max_hp)]
	var rect: Rect2 = ScreenLayout.floor_hero_label_rect(vp)
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.get_center().y + HEADER_FONT_SIZE * 0.35), label, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, HEADER_FONT_SIZE, HEADER_COLOR)


# Progress strip: one segment per floor, then the final match.
func _draw_strip(vp: Vector2) -> void:
	var count: int = _flow.get_floor_count()
	var floor_index: int = _flow.get_floor()
	var path: Array[String] = _flow.get_region_path()
	var segments: Array[Rect2] = ScreenLayout.world_strip_segment_rects(vp, count + 1)
	for i: int in segments.size():
		var rect: Rect2 = segments[i]
		var back: Color = STRIP_FUTURE_BACK
		var outline: Color = STRIP_FUTURE_OUTLINE
		var width: float = OUTLINE_WIDTH
		var color: Color = STRIP_DIM_TEXT
		var label: String = tr(TEXT_STRIP_FLOOR) % (i + 1)
		var region: String = ""
		if i == count:
			back = STRIP_FINAL_BACK
			outline = STRIP_CURRENT_OUTLINE if floor_index >= count else STRIP_FINAL_OUTLINE
			width = SELECTED_OUTLINE_WIDTH if floor_index >= count else OUTLINE_WIDTH
			color = STRIP_FINAL_TEXT
			label = tr(TEXT_FINAL_NAME)
		elif i < floor_index:
			back = STRIP_PAST_BACK
			outline = STRIP_PAST_OUTLINE
			color = STRIP_TEXT
		elif i == floor_index:
			back = STRIP_CURRENT_BACK
			outline = STRIP_CURRENT_OUTLINE
			width = SELECTED_OUTLINE_WIDTH
			color = STRIP_TEXT
			region = tr(TEXT_CHOOSING)
		if i < count and i < path.size():
			region = _flow.region_name(path[i])
		draw_rect(rect, back)
		draw_rect(rect, outline, false, width)
		var inner: float = rect.size.x - width * 2.0
		_text(rect, rect.position.y + rect.size.y * STRIP_FLOOR_BASELINE, label, _fit(label, inner, STRIP_FLOOR_FONT_SIZE), color)
		if not region.is_empty():
			_text(rect, rect.position.y + rect.size.y * STRIP_REGION_BASELINE, region, _fit(region, inner, STRIP_REGION_FONT_SIZE), color)


# One region card at rest rect [param base] (raised when selected).
func _draw_card(vp: Vector2, base: Rect2, region_id: String, index: int) -> void:
	var selected: bool = region_id == _selected
	var rect: Rect2 = base
	var outline: Color = CARD_OUTLINE
	var width: float = OUTLINE_WIDTH
	if selected:
		draw_rect(Rect2(base.position + SHADOW_OFFSET, base.size), CARD_SHADOW)
		rect.position.y -= ScreenLayout.world_card_raise(vp)
		outline = CARD_SELECTED_OUTLINE
		width = SELECTED_OUTLINE_WIDTH
	elif UiButtons.is_pressed_at(self, ScreenLayout.world_card_touch_rect(vp, base)):
		outline = CARD_PRESSED_OUTLINE
		width = SELECTED_OUTLINE_WIDTH
	var preview: Dictionary = _flow.region_preview(region_id)
	draw_rect(rect, CARD_BACK)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * CARD_BAND_RATIO)), CARD_ACCENTS[index % CARD_ACCENTS.size()])
	draw_rect(rect, outline, false, width)
	var inner: float = rect.size.x * (1.0 - CARD_INSET_RATIO * 2.0)
	var region_name: String = str(preview.get("name", _flow.region_name(region_id)))
	_card_line(rect, CARD_NAME_BASELINE, region_name, CARD_NAME_FONT_SIZE, CARD_NAME_TEXT, inner)
	var desc: String = _preview_desc(preview)
	if not desc.is_empty():
		var top: float = rect.position.y + rect.size.y * CARD_DESC_TOP + CARD_DESC_FONT_SIZE
		draw_multiline_string(ThemeDB.fallback_font, Vector2(rect.position.x + rect.size.x * CARD_INSET_RATIO, top), desc, HORIZONTAL_ALIGNMENT_CENTER, inner, CARD_DESC_FONT_SIZE, CARD_DESC_MAX_LINES, CARD_DESC_TEXT)
	var boss: String = str(preview.get("boss_name", ""))
	if not boss.is_empty():
		_card_line(rect, CARD_BOSS_BASELINE, tr(TEXT_BOSS) % tr(boss), CARD_LINE_FONT_SIZE, CARD_BOSS_TEXT, inner)
	var scaling: Dictionary = preview.get("floor_scaling", {})
	var floor_number: int = _flow.get_floor() + 1
	_card_line(rect, CARD_DIFFICULTY_BASELINE, tr(TEXT_DIFFICULTY) % [floor_number, _decimal(float(scaling.get("hp_mult", 1.0)))], CARD_LINE_FONT_SIZE, CARD_TEXT, inner)
	var extras: String = _scaling_extras(scaling)
	if not extras.is_empty():
		_card_line(rect, CARD_EXTRA_BASELINE, extras, CARD_EXTRA_FONT_SIZE, CARD_DESC_TEXT, inner)
	var hint: String = tr(TEXT_TAP_AGAIN if selected else TEXT_TAP_TO_PICK)
	_card_line(rect, CARD_HINT_BASELINE, hint, CARD_HINT_FONT_SIZE, CARD_HINT_SELECTED_TEXT if selected else CARD_HINT_TEXT, inner)


# The region's one-line description: a key (desc_key) or ready text (desc); "" when neither.
func _preview_desc(preview: Dictionary) -> String:
	var key: String = str(preview.get("desc_key", ""))
	if not key.is_empty():
		return tr(key)
	return str(preview.get("desc", ""))


# "nhịp ×0,9 · giáp +1 · đòn +1 ô": only the parts that change the floor's matches.
func _scaling_extras(scaling: Dictionary) -> String:
	var parts: Array[String] = []
	var step: float = float(scaling.get("step_mult", 1.0))
	if not is_equal_approx(step, 1.0):
		parts.append(tr(TEXT_STEP) % _decimal(step))
	var defense: int = int(scaling.get("defense_add", 0))
	if defense != 0:
		parts.append(tr(TEXT_DEFENSE) % defense)
	var size_add: int = int(scaling.get("size_add", 0))
	if size_add != 0:
		parts.append(tr(TEXT_SIZE) % size_add)
	return SEPARATOR.join(parts)


# A multiplier as text with at most two decimals and no trailing zeros, in the locale's decimal mark.
func _decimal(value: float) -> String:
	var text: String = String.num(value, 2)
	return text.replace(".", tr(TEXT_DECIMAL_POINT))


func _draw_notice(vp: Vector2) -> void:
	var band: Rect2 = ScreenLayout.map_notice_rect(vp)
	draw_rect(band, NOTICE_BACK)
	draw_rect(band, NOTICE_OUTLINE, false, OUTLINE_WIDTH)
	var text: String = tr(_notice_key) % _notice_args if not _notice_args.is_empty() else tr(_notice_key)
	_text(band, band.position.y + band.size.y * NOTICE_BASELINE, text, _fit(text, band.size.x - vp.x * ScreenLayout.MARGIN_RATIO * 2.0, NOTICE_FONT_SIZE), NOTICE_TEXT)
	_text(band, band.position.y + band.size.y * NOTICE_SUB_BASELINE, tr(TEXT_NOTICE_DISMISS), NOTICE_SUB_FONT_SIZE, NOTICE_SUB_TEXT)


# A centred card line at baseline share [param share] of [param rect], shrunk to fit [param width].
func _card_line(rect: Rect2, share: float, text: String, size: int, color: Color, width: float) -> void:
	_text(rect, rect.position.y + rect.size.y * share, text, _fit(text, width, size), color)


# Largest font size <= [param size] (never below MIN_FIT_FONT_SIZE) at which [param text] fits [param width].
func _fit(text: String, width: float, size: int) -> int:
	var font: Font = ThemeDB.fallback_font
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted).x > width:
		fitted -= 1
	return fitted


# Centred single-line text at baseline [param y] over the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


# Story 031: the back button's font, shrunk until [param text] fits [param width] minus a small inset
# ("Back to title" is wider than the 128 px button at BUTTON_FONT_SIZE).
func _back_font_size(text: String, width: float) -> int:
	var font: Font = ThemeDB.fallback_font
	var size: int = BUTTON_FONT_SIZE
	while size > BACK_MIN_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x > width - BACK_TEXT_INSET * 2.0:
		size -= 1
	return size


# Story 032: the relic strip shows while this screen is up (nothing covering it); its card closes otherwise.
func _sync_strip() -> void:
	var shown: bool = _is_active() and _notice_key.is_empty()
	if not shown:
		_strip.close_tooltip()
	_strip.visible = shown
	if shown:
		_strip.area = ScreenLayout.relic_strip_rect(get_viewport_rect().size)
		_strip.set_relics(_flow.get_relics())

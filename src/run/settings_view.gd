class_name SettingsView
extends Node2D
## Settings screen (user 2026-11-01, Main Menu pass; tabs 2026-11-09; visual redesign 2026-11-09): opened from the title
## ("Cài đặt", [method GameFlow.open_settings]).
##
## Layout (design px at a 1280x720 viewport, scaled by [method unit] for other sizes; the game's canvas_items
## stretch keeps the height at 720, so only the width varies; everything sits inside the display safe area and the
## nav + panel group is centred with a capped width on wide phones):
## - Header band with the title.
## - Left NAV rail ([constant TABS]): the selected tab is the one gold plate on screen; the others are flat stone tabs
##   without a frame. "Về" (secondary navy plate) closes the rail at the bottom (left thumb reach).
## - One MAIN PANEL (navy plate) holding the selected tab's rows; rows are separated by thin lines, not framed.
##   Each row: label, optional description, a right-aligned control. The whole row is the touch target.
## Controls (angular, no circles):
## - On / off: a two-segment switch "Tắt | Bật" (the chosen segment gold). Tapping a segment sets it; tapping elsewhere
##   on the row flips it.
## - Language (user 2026-11-09: a switch only fits two languages): a SELECT box showing the current language and an
##   angular chevron; a tap opens a list of every [constant GameFlow.SUPPORTED_LOCALES] entry (the current one gold,
##   each name in its own language, key ui.settings.lang_<code>) under the box (above it when there is no room); a tap
##   on an option picks it, a tap anywhere else closes the list. ui_left / ui_right cycle the languages.
## - Volume ([constant AUDIO_ROWS] vol_*): a stepper: "-" button, the percent over a 10-segment meter, "+" button.
##   -/+ move by SettingsStore.VOLUME_STEP and stop at 0 / 100 (the end button greys out); tapping the meter sets the
##   level under the finger.
## Rows: "general" = [constant ROWS] (Control hints, Reduce motion, Language); "audio" = [constant AUDIO_ROWS] (Master,
## Music, SFX, UI, Ambience volumes, Reduced audio, Vibration). The seven audio rows fit one panel at every supported
## size (rows >= 64 px), so there is no scrolling. Keyboard / gamepad: ui_up / ui_down move the focus ring,
## ui_left / ui_right change the focused value, ui_focus_next / ui_page_down / ui_page_up switch tabs, ui_accept flips
## a toggle; "Về" stays on ui_cancel (GameFlow).
## Every change is saved at once by its store; the audio rows edit the flow's settings ([method GameFlow.get_settings]),
## which the [AudioRig] applies to the buses; changes play a UI tick through the audio event system.
## Child of GameFlow (reads it through [member flow_path]); draws and takes input only in
## [constant GameFlow.Phase.SETTINGS]; owns no settings state (only the selected tab and the keyboard focus). Input
## dedup as in TitleView (emulated copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act).
## Every string is a TEXT_* key.

## Colours (HudSkin / UiButtons palette).
const TITLE_COLOR: Color = HudSkin.IVORY
const LABEL_COLOR: Color = Color("F8F8D0")
const HINT_COLOR: Color = HudSkin.TEXT_DIM
const TAB_IDLE_FILL: Color = Color("232030")
const TAB_IDLE_FILL_PRESSED: Color = Color("2E2A3C")
const TAB_IDLE_TEXT: Color = Color("A9A3B4")
const SEPARATOR: Color = Color(0.49, 0.53, 0.59, 0.28)
const ROW_PRESSED: Color = Color(1.0, 1.0, 1.0, 0.06)
const CONTROL_WELL: Color = Color("15131C")
const CONTROL_RIM: Color = Color("7A4E16")
const CONTROL_GOLD: Color = UiButtons.GOLD_FILL
const CONTROL_GOLD_PRESSED: Color = UiButtons.GOLD_FILL_PRESSED
const CONTROL_TEXT_ON: Color = UiButtons.LABEL_DARK
const CONTROL_TEXT_OFF: Color = Color("8C8698")
const STEP_FILL: Color = Color("2A2840")
const STEP_FILL_PRESSED: Color = Color("3A3656")
const STEP_GLYPH: Color = UiButtons.GOLD_RIM_LIGHT
const STEP_GLYPH_OFF: Color = Color("4E4A5C")
const METER_LIT: Color = UiButtons.GOLD_FILL
const FOCUS_RING: Color = HudSkin.GRID_LIGHT
## Font sizes (nominal, MenuFont scales them), at the 720 px design height.
const TITLE_FONT_SIZE: int = 44
const TAB_FONT_SIZE: int = 26
const LABEL_FONT_SIZE: int = 26
const HINT_FONT_SIZE: int = 18
const VALUE_FONT_SIZE: int = 22
const BUTTON_FONT_SIZE: int = 26
## Design px at 720 px tall ([method unit] scales them).
const DESIGN_HEIGHT: float = 720.0
const DESIGN_WIDTH: float = 1280.0
const HEADER_BOTTOM_RATIO: float = 0.13
const MARGIN_PX: float = 32.0
const TOP_PX: float = 120.0
const GROUP_MAX_W_PX: float = 1200.0
const NAV_W_PX: float = 232.0
const NAV_GAP_PX: float = 24.0
const TAB_H_PX: float = 72.0
const TAB_GAP_PX: float = 12.0
const TAB_CUT_PX: float = 8.0
const BACK_H_PX: float = 64.0
const PANEL_PAD_PX: float = 16.0
const ROW_PAD_X_PX: float = 20.0
const GENERAL_ROW_H_PX: float = 116.0
const AUDIO_ROW_H_PX: float = 76.0
const SEPARATOR_PX: float = 2.0
const SWITCH_SEG_W_PX: float = 96.0
const LANG_SELECT_W_PX: float = 272.0
const LANG_OPTION_H_PX: float = 56.0
const CHEVRON_W_PX: float = 16.0
const CHEVRON_H_PX: float = 10.0
## Display order of the languages in the select list (codes not listed follow in GameFlow order).
const LANGUAGE_ORDER: Array[String] = ["vi", "en"]
## Name key of a language code: "ui.settings.lang_<code>" (each name written in its own language).
const LANG_NAME_KEY_FMT: String = "ui.settings.lang_%s"
const SWITCH_H_PX: float = 48.0
const CONTROL_CUT_PX: float = 6.0
const CONTROL_RIM_PX: float = 2.0
const SEG_INSET_PX: float = 4.0
const STEP_BTN_W_PX: float = 64.0
const STEP_METER_W_PX: float = 200.0
const STEP_GAP_PX: float = 12.0
const STEP_H_PX: float = 56.0
const METER_H_PX: float = 8.0
const METER_SEGMENTS: int = 10
const GLYPH_LEN_PX: float = 20.0
const GLYPH_THICK_PX: float = 4.0
const FOCUS_RING_PX: float = 2.0

const TEXT_TITLE: String = "ui.settings.title"
const TEXT_BACK: String = "ui.settings.back"
const TEXT_HINTS: String = "ui.settings.hints"
const TEXT_HINTS_HINT: String = "ui.settings.hints_hint"
const TEXT_MOTION: String = "ui.settings.reduce_motion"
const TEXT_MOTION_HINT: String = "ui.settings.reduce_motion_hint"
const TEXT_LANGUAGE: String = "ui.settings.language"
const TEXT_LANGUAGE_HINT: String = "ui.settings.language_hint"
const TEXT_ON: String = "ui.settings.on"
const TEXT_OFF: String = "ui.settings.off"
const TEXT_LANG_NAME_VI: String = "ui.settings.lang_vi"
const TEXT_LANG_NAME_EN: String = "ui.settings.lang_en"
## Accessibility "Thời gian chọn lá" (2026-11-01): label, hint and one value key per SettingsStore.CARD_TIMES entry.
const TEXT_CARD_TIME: String = "ui.settings.card_time"
const TEXT_CARD_TIME_HINT: String = "ui.settings.card_time_hint"
const TEXT_CARD_TIME_VALUES: Dictionary = {"normal": "ui.settings.card_time_normal", "long": "ui.settings.card_time_long",
	"unlimited": "ui.settings.card_time_unlimited"}
## General tab row ids, top to bottom.
## 2026-11-07 (user): the card time row is gone; matches use the normal card time (CombatView).
const ROWS: Array[String] = ["hints", "motion", "language"]
## Audio tab row ids, top to bottom: "vol_<Bus>" per SettingsStore.VOLUME_BUSES, then the two toggles.
const AUDIO_ROWS: Array[String] = ["vol_Master", "vol_Music", "vol_SFX", "vol_UI", "vol_Ambience", "reduced_audio",
	"vibration"]
const TEXT_AUDIO: String = "ui.settings.audio"
const TEXT_AUDIO_LABELS: Dictionary = {"vol_Master": "ui.settings.vol_master", "vol_Music": "ui.settings.vol_music",
	"vol_SFX": "ui.settings.vol_sfx", "vol_UI": "ui.settings.vol_ui", "vol_Ambience": "ui.settings.vol_ambience",
	"reduced_audio": "ui.settings.reduced_audio", "vibration": "ui.settings.vibration"}
const TEXT_VOLUME_VALUE: String = "ui.settings.volume_value"
const TEXT_TAB_GENERAL: String = "ui.settings.tab_general"
## Tab ids, top to bottom, and their label keys.
const TABS: Array[String] = ["general", "audio"]
const TEXT_TABS: Dictionary = {"general": TEXT_TAB_GENERAL, "audio": TEXT_AUDIO}
## Control kinds ([method value_rect]).
const KIND_SWITCH: String = "switch"
const KIND_LANGUAGE: String = "language"
const KIND_VOLUME: String = "volume"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

## The store the rows edit; null = the flow's settings (else the shared store). Tests inject a memory store.
var audio_settings: SettingsStore = null

var _flow: GameFlow
var _tab: String = "general"
## Keyboard / gamepad focus: the row index in the current tab, -1 = none shown (touch use).
var _focus: int = -1
## True while the language list is open.
var _lang_open: bool = false


func _ready() -> void:
	_flow = get_node(flow_path) as GameFlow
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	MenuFont.read_args()


func _process(_delta: float) -> void:
	queue_redraw()


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.SETTINGS


# --- Layout (pure but for the display safe area) -------------------------------


## Design px -> viewport px for [param viewport_size]: 1 at 1280x720 and on wider screens of the same height; a
## narrower-than-16:9 screen (4:3 tablets, a square window) scales down by its width so nothing crowds.
static func unit(viewport_size: Vector2) -> float:
	return minf(viewport_size.y / DESIGN_HEIGHT, viewport_size.x / DESIGN_WIDTH)


static func _px(viewport_size: Vector2, design: float) -> float:
	return roundf(design * unit(viewport_size))


## The nav + panel group: inside the safe area, centred, at most GROUP_MAX_W_PX wide.
static func group_rect(viewport_size: Vector2) -> Rect2:
	var safe: Rect2 = ScreenLayout.safe_rect(viewport_size)
	var m: float = _px(viewport_size, MARGIN_PX)
	var w: float = minf(safe.size.x - m * 2.0, _px(viewport_size, GROUP_MAX_W_PX))
	var top: float = maxf(_px(viewport_size, TOP_PX), safe.position.y + m)
	var bottom: float = safe.end.y - m
	var left: float = roundf(safe.position.x + (safe.size.x - w) * 0.5)
	return Rect2(left, top, w, bottom - top)


## The tab rail's rects (one per [constant TABS]), top to bottom.
static func tab_rects(viewport_size: Vector2) -> Array[Rect2]:
	var g: Rect2 = group_rect(viewport_size)
	var h: float = _px(viewport_size, TAB_H_PX)
	var gap: float = _px(viewport_size, TAB_GAP_PX)
	var rects: Array[Rect2] = []
	for i: int in TABS.size():
		rects.append(Rect2(g.position.x, g.position.y + (h + gap) * i, _px(viewport_size, NAV_W_PX), h))
	return rects


## "Về" at the bottom of the rail (left thumb reach).
static func back_rect(viewport_size: Vector2) -> Rect2:
	var g: Rect2 = group_rect(viewport_size)
	var h: float = _px(viewport_size, BACK_H_PX)
	return Rect2(g.position.x, g.end.y - h, _px(viewport_size, NAV_W_PX), h)


## The main panel for a tab with [param row_count] rows of [param row_h] design px (it hugs its rows).
static func panel_rect(viewport_size: Vector2, row_count: int, row_h: float) -> Rect2:
	var g: Rect2 = group_rect(viewport_size)
	var x: float = g.position.x + _px(viewport_size, NAV_W_PX + NAV_GAP_PX)
	var pad: float = _px(viewport_size, PANEL_PAD_PX)
	var h: float = minf(_px(viewport_size, row_h) * row_count + pad * 2.0, g.size.y)
	return Rect2(x, g.position.y, g.end.x - x, h)


static func _rows_in(viewport_size: Vector2, count: int, row_h: float) -> Array[Rect2]:
	var panel: Rect2 = panel_rect(viewport_size, count, row_h)
	var pad: float = _px(viewport_size, PANEL_PAD_PX)
	var h: float = floorf((panel.size.y - pad * 2.0) / float(count))
	var rects: Array[Rect2] = []
	for i: int in count:
		rects.append(Rect2(panel.position.x + pad, panel.position.y + pad + h * i, panel.size.x - pad * 2.0, h))
	return rects


## The General tab's row rects, top to bottom (one per [constant ROWS]).
static func row_rects(viewport_size: Vector2) -> Array[Rect2]:
	return _rows_in(viewport_size, ROWS.size(), GENERAL_ROW_H_PX)


## The Audio tab's row rects, top to bottom (one per [constant AUDIO_ROWS]).
static func audio_row_rects(viewport_size: Vector2) -> Array[Rect2]:
	return _rows_in(viewport_size, AUDIO_ROWS.size(), AUDIO_ROW_H_PX)


## The control of a row: right-aligned, vertically centred; [param kind] = [constant KIND_SWITCH] (default),
## [constant KIND_LANGUAGE] or [constant KIND_VOLUME].
static func value_rect(row: Rect2, viewport_size: Vector2, kind: String = KIND_SWITCH) -> Rect2:
	var w: float
	var h: float = _px(viewport_size, SWITCH_H_PX)
	match kind:
		KIND_LANGUAGE:
			w = _px(viewport_size, LANG_SELECT_W_PX)
		KIND_VOLUME:
			w = _px(viewport_size, STEP_BTN_W_PX * 2.0 + STEP_GAP_PX * 2.0 + STEP_METER_W_PX)
			h = _px(viewport_size, STEP_H_PX)
		_:
			w = _px(viewport_size, SWITCH_SEG_W_PX) * 2.0
	var right: float = row.end.x - _px(viewport_size, ROW_PAD_X_PX)
	return Rect2(right - w, roundf(row.position.y + (row.size.y - h) * 0.5), w, h)


## The two segments of a switch control (left = off / Tiếng Việt, right = on / English).
static func switch_segments(control: Rect2) -> Array[Rect2]:
	var half: float = floorf(control.size.x * 0.5)
	return [Rect2(control.position, Vector2(half, control.size.y)),
		Rect2(control.position + Vector2(half, 0.0), Vector2(control.size.x - half, control.size.y))]


## The languages the select offers, in display order ([constant LANGUAGE_ORDER] first, then GameFlow's others).
static func language_options() -> Array[String]:
	var out: Array[String] = []
	for code: String in LANGUAGE_ORDER:
		if GameFlow.SUPPORTED_LOCALES.has(code):
			out.append(code)
	for code: String in GameFlow.SUPPORTED_LOCALES:
		if not out.has(code):
			out.append(code)
	return out


## The open language list's option rects for select box [param control]: under it, or above it when the list would
## leave the group ([method group_rect]).
static func language_option_rects(control: Rect2, viewport_size: Vector2) -> Array[Rect2]:
	var n: int = language_options().size()
	var h: float = _px(viewport_size, LANG_OPTION_H_PX)
	var gap: float = _px(viewport_size, 4.0)
	var top: float = control.end.y + gap
	if top + h * n > group_rect(viewport_size).end.y:
		top = control.position.y - gap - h * n
	var out: Array[Rect2] = []
	for i: int in n:
		out.append(Rect2(control.position.x, top + h * i, control.size.x, h))
	return out


## The three parts of a volume stepper: [minus button, meter block, plus button].
static func stepper_parts(control: Rect2, viewport_size: Vector2) -> Array[Rect2]:
	var bw: float = _px(viewport_size, STEP_BTN_W_PX)
	var gap: float = _px(viewport_size, STEP_GAP_PX)
	return [Rect2(control.position, Vector2(bw, control.size.y)),
		Rect2(control.position + Vector2(bw + gap, 0.0), Vector2(control.size.x - (bw + gap) * 2.0, control.size.y)),
		Rect2(Vector2(control.end.x - bw, control.position.y), Vector2(bw, control.size.y))]


## The control kind of row [param row_id].
static func kind_of(row_id: String) -> String:
	if row_id.begins_with("vol_"):
		return KIND_VOLUME
	if row_id == "language":
		return KIND_LANGUAGE
	return KIND_SWITCH


## Pure: the volume (0-100, steps of SettingsStore.VOLUME_STEP) for a tap at x [param x] across meter [param meter].
static func volume_at(meter: Rect2, x: float) -> int:
	var t: float = clampf((x - meter.position.x) / maxf(meter.size.x, 1.0), 0.0, 1.0)
	return clampi(roundi(t * 100.0 / SettingsStore.VOLUME_STEP) * SettingsStore.VOLUME_STEP, 0, 100)


## The selected tab id (one of [constant TABS]).
func get_tab() -> String:
	return _tab


## Selects tab [param tab_id]; an unknown id is ignored. The keyboard focus resets.
func set_tab(tab_id: String) -> void:
	if TABS.has(tab_id) and tab_id != _tab:
		_tab = tab_id
		_focus = -1
		_lang_open = false


## True while the language list is open.
func is_language_open() -> bool:
	return _lang_open


## Opens / closes the language list.
func set_language_open(open: bool) -> void:
	_lang_open = open and _tab == "general"


## Picks UI language [param code] (one of [method language_options]) and closes the list.
func select_language(code: String) -> void:
	_lang_open = false
	if not language_options().has(code) or _flow == null or _flow.get_locale() == code:
		return
	_flow.set_locale(code)
	_ui_cue("toggle")


## Moves the UI language to the next (or previous, [param direction] < 0) entry of [method language_options].
func cycle_language(direction: int) -> void:
	if _flow == null:
		return
	var opts: Array[String] = language_options()
	var i: int = opts.find(_flow.get_locale())
	select_language(opts[(maxi(i, 0) + signi(direction) + opts.size()) % opts.size()])


## The row ids of the selected tab.
func current_rows() -> Array[String]:
	return AUDIO_ROWS if _tab == "audio" else ROWS


## The keyboard / gamepad focus row index (-1 = none).
func get_focus() -> int:
	return _focus


func _current_rects(vp: Vector2) -> Array[Rect2]:
	return audio_row_rects(vp) if _tab == "audio" else row_rects(vp)


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		handle_nav(event)
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
	if tap(pos, event.device != InputEvent.DEVICE_ID_EMULATION):
		get_viewport().set_input_as_handled()


## A tap / click at [param pos]: Back, a tab, or a row (see [method tap_row]). Returns true when it hit something;
## [param acts] = false only consumes it (an emulated duplicate).
func tap(pos: Vector2, acts: bool = true) -> bool:
	var vp: Vector2 = get_viewport_rect().size
	if _lang_open:
		# The open list takes every tap: an option picks it, anything else only closes the list.
		if acts:
			var control: Rect2 = value_rect(row_rects(vp)[ROWS.find("language")], vp, KIND_LANGUAGE)
			var opts: Array[String] = language_options()
			var rects: Array[Rect2] = language_option_rects(control, vp)
			var picked: String = ""
			for i: int in rects.size():
				if rects[i].has_point(pos):
					picked = opts[i]
			if picked.is_empty():
				_lang_open = false
			else:
				select_language(picked)
		return true
	if back_rect(vp).has_point(pos):
		if acts:
			_flow.close_settings()
		return true
	var tabs: Array[Rect2] = tab_rects(vp)
	for i: int in tabs.size():
		if tabs[i].has_point(pos):
			if acts and _tab != TABS[i]:
				set_tab(TABS[i])
				_ui_cue("tap")
			return true
	var rects: Array[Rect2] = _current_rects(vp)
	var ids: Array[String] = current_rows()
	for i: int in rects.size():
		# The whole row is the hit area (a big thumb target).
		if rects[i].has_point(pos):
			if acts:
				_focus = -1
				tap_row(ids[i], pos, rects[i], vp)
			return true
	return false


## A tap at [param pos] on row [param row_id] (rect [param row]): switch segments set their value, the rest of a switch
## row flips it; the language row opens its list; a stepper's -/+ (full row height) step the volume and its meter sets
## the level under the finger (a tap on the label side does nothing).
func tap_row(row_id: String, pos: Vector2, row: Rect2, vp: Vector2) -> void:
	var kind: String = kind_of(row_id)
	var control: Rect2 = value_rect(row, vp, kind)
	if kind == KIND_VOLUME:
		# Thumb-sized: "-" / "+" take the full row height, "-" from a little left of the control up to the meter,
		# "+" from the meter to the row's right edge; the meter column sets the level under the finger.
		var parts: Array[Rect2] = stepper_parts(control, vp)
		var reach: float = _px(vp, ROW_PAD_X_PX)
		if pos.x >= control.position.x - reach and pos.x < parts[1].position.x:
			step_volume(row_id, -1)
		elif pos.x >= parts[1].end.x:
			step_volume(row_id, 1)
		elif pos.x >= parts[1].position.x:
			set_volume_row(row_id, volume_at(parts[1], pos.x))
		return
	if kind == KIND_LANGUAGE:
		set_language_open(true)
		return
	var segs: Array[Rect2] = switch_segments(control)
	if segs[0].has_point(pos):
		set_switch(row_id, false)
	elif segs[1].has_point(pos):
		set_switch(row_id, true)
	elif row_id in AUDIO_ROWS:
		toggle_audio(row_id)
	else:
		toggle(row_id)


## Keyboard / gamepad: focus moves, value changes, tab switches (see the class doc). Returns true when handled.
func handle_nav(event: InputEvent) -> bool:
	var ids: Array[String] = current_rows()
	var handled: bool = true
	if event.is_action_pressed("ui_down", true):
		_focus = 0 if _focus < 0 else mini(_focus + 1, ids.size() - 1)
	elif event.is_action_pressed("ui_up", true):
		_focus = 0 if _focus < 0 else maxi(_focus - 1, 0)
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_page_down"):
		set_tab(TABS[(TABS.find(_tab) + 1) % TABS.size()])
		_ui_cue("tap")
	elif event.is_action_pressed("ui_page_up"):
		set_tab(TABS[(TABS.find(_tab) - 1 + TABS.size()) % TABS.size()])
		_ui_cue("tap")
	elif _focus >= 0 and (event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true)):
		var up: bool = event.is_action_pressed("ui_right", true)
		var id: String = ids[_focus]
		if kind_of(id) == KIND_VOLUME:
			step_volume(id, 1 if up else -1)
		elif kind_of(id) == KIND_LANGUAGE:
			cycle_language(1 if up else -1)
		else:
			set_switch(id, up)
	elif _focus >= 0 and event.is_action_pressed("ui_accept"):
		var id2: String = ids[_focus]
		if kind_of(id2) == KIND_LANGUAGE:
			cycle_language(1)
		elif kind_of(id2) != KIND_VOLUME:
			if id2 in AUDIO_ROWS:
				toggle_audio(id2)
			else:
				toggle(id2)
	else:
		handled = false
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()
	return handled


# --- Actions ------------------------------------------------------------------


## Cycles the option [param row_id] (one of [constant ROWS]); unknown ids are ignored.
func toggle(row_id: String) -> void:
	var store: SettingsStore = audio_store()
	match row_id:
		"hints":
			store.set_show_control_hints(not store.get_show_control_hints())
		"motion":
			store.set_reduce_motion(not store.get_reduce_motion())
		"card_time":
			store.cycle_card_time()
		"language":
			_flow.toggle_locale()
		_:
			return
	_ui_cue("toggle")


## Sets a switch row to [param on] (right segment): no-op when it already is. Language: on = English.
func set_switch(row_id: String, on: bool) -> void:
	if switch_on(row_id) != on:
		if row_id in AUDIO_ROWS:
			toggle_audio(row_id)
		else:
			toggle(row_id)


## True when switch row [param row_id] shows its right segment (on / English).
func switch_on(row_id: String) -> bool:
	match row_id:
		"language":
			return TranslationServer.get_locale().begins_with("en")
		"reduced_audio":
			return audio_store().get_reduced_audio()
		"vibration":
			return audio_store().get_vibration()
	return value_key(row_id) == TEXT_ON


## The settings every row edits: the injected store, else the flow's store (the one the AudioRig applies; the shared
## store in the game), else the shared one. (Before 2026-11-09 the General rows always wrote the shared store.)
func audio_store() -> SettingsStore:
	if audio_settings != null:
		return audio_settings
	if _flow != null and _flow.get_settings() != null:
		return _flow.get_settings()
	return SettingsStore.shared()


## Moves volume row [param row_id] by [param direction] x SettingsStore.VOLUME_STEP, stopping at 0 and 100.
func step_volume(row_id: String, direction: int) -> void:
	var bus: String = row_id.trim_prefix("vol_")
	set_volume_row(row_id, audio_store().get_volume(bus) + signi(direction) * SettingsStore.VOLUME_STEP)


## Sets volume row [param row_id] to [param percent] (clamped 0-100); a change plays the UI tick.
func set_volume_row(row_id: String, percent: int) -> void:
	var bus: String = row_id.trim_prefix("vol_")
	var store: SettingsStore = audio_store()
	var target: int = clampi(percent, 0, 100)
	if not row_id.begins_with("vol_") or store.get_volume(bus) == target:
		return
	store.set_volume(bus, target)
	_ui_cue("toggle")


## Changes the audio row [param row_id] (one of [constant AUDIO_ROWS]): a volume steps by [param direction]
## (stopping at 0 / 100); a toggle flips. Unknown ids are ignored.
func toggle_audio(row_id: String, direction: int = 1) -> void:
	var store: SettingsStore = audio_store()
	if row_id.begins_with("vol_"):
		step_volume(row_id, direction)
		return
	if row_id == "reduced_audio":
		store.set_reduced_audio(not store.get_reduced_audio())
	elif row_id == "vibration":
		store.set_vibration(not store.get_vibration())
	else:
		return
	_ui_cue("toggle")


## The value text of audio row [param row_id] now (translated): "80%" or On / Off.
func audio_value_text(row_id: String) -> String:
	var store: SettingsStore = audio_store()
	if row_id.begins_with("vol_"):
		return tr(TEXT_VOLUME_VALUE).format({"pct": store.get_volume(row_id.trim_prefix("vol_"))})
	if row_id == "reduced_audio":
		return tr(TEXT_ON if store.get_reduced_audio() else TEXT_OFF)
	if row_id == "vibration":
		return tr(TEXT_ON if store.get_vibration() else TEXT_OFF)
	return ""


## The value label key of [param row_id] now.
func value_key(row_id: String) -> String:
	var store: SettingsStore = audio_store()
	match row_id:
		"hints":
			return TEXT_ON if store.get_show_control_hints() else TEXT_OFF
		"motion":
			return TEXT_ON if store.get_reduce_motion() else TEXT_OFF
		"card_time":
			return str(TEXT_CARD_TIME_VALUES.get(store.get_card_time(), TEXT_CARD_TIME_VALUES["normal"]))
		"language":
			return TEXT_LANG_NAME_EN if TranslationServer.get_locale().begins_with("en") else TEXT_LANG_NAME_VI
	return ""


func _ui_cue(cue_name: String) -> void:
	var rig: AudioRig = AudioRig.of(_flow) if _flow != null else null
	if rig == null or rig.get_ui() == null:
		return
	if cue_name == "tap":
		rig.get_ui().tap()
	else:
		rig.get_ui().toggle()


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	HudSkin.screen_background(self, Rect2(Vector2.ZERO, vp), HEADER_BOTTOM_RATIO)
	MenuFont.text(self, Vector2(0.0, roundf(vp.y * HEADER_BOTTOM_RATIO * 0.68)), tr(TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	_draw_tabs(vp)
	var back: Rect2 = back_rect(vp)
	UiButtons.draw_button(self, back, tr(TEXT_BACK), UiButtons.Style.SECONDARY, UiButtons.is_pressed_at(self, back), true, BUTTON_FONT_SIZE)
	var ids: Array[String] = current_rows()
	HudSkin.plate_panel(self, panel_rect(vp, ids.size(), AUDIO_ROW_H_PX if _tab == "audio" else GENERAL_ROW_H_PX), "navy")
	var rects: Array[Rect2] = _current_rects(vp)
	var line: float = maxf(_px(vp, SEPARATOR_PX), 1.0)
	var inset: float = _px(vp, ROW_PAD_X_PX * 0.5)
	for i: int in rects.size():
		_draw_row(vp, rects[i], ids[i], i == _focus)
		if i < rects.size() - 1:
			draw_rect(Rect2(rects[i].position.x + inset, rects[i].end.y - floorf(line * 0.5), rects[i].size.x - inset * 2.0, line), SEPARATOR)
	if _lang_open and _tab == "general":
		_draw_language_list(vp, value_rect(rects[ROWS.find("language")], vp, KIND_LANGUAGE))


# The tab rail: the selected tab is a gold plate (the strongest accent on the screen); the others are flat stone.
func _draw_tabs(vp: Vector2) -> void:
	var tabs: Array[Rect2] = tab_rects(vp)
	var cut: float = _px(vp, TAB_CUT_PX)
	for i: int in tabs.size():
		var label: String = tr(TEXT_TABS[TABS[i]])
		if TABS[i] == _tab:
			var look: Dictionary = UiButtons.look(UiButtons.Style.SECONDARY, false, true, true)
			var body: Rect2 = UiButtons.draw_plate(self, tabs[i], look, UiButtons.ui_scale(self), false)
			MenuFont.text_outlined(self, Vector2(body.position.x, roundf(body.get_center().y + MenuFont.size(TAB_FONT_SIZE) * 0.3)),
				label, TAB_FONT_SIZE, look["text"], look["text_outline"], HORIZONTAL_ALIGNMENT_CENTER, body.size.x)
		else:
			var pressed: bool = UiButtons.is_pressed_at(self, tabs[i])
			HudSkin.panel(self, tabs[i], [cut, cut, cut, cut], TAB_IDLE_FILL_PRESSED if pressed else TAB_IDLE_FILL, Color.TRANSPARENT, 0.0)
			MenuFont.text(self, Vector2(tabs[i].position.x, roundf(tabs[i].get_center().y + MenuFont.size(TAB_FONT_SIZE) * 0.3)), label,
				TAB_FONT_SIZE, TAB_IDLE_TEXT, HORIZONTAL_ALIGNMENT_CENTER, tabs[i].size.x)


func _draw_row(vp: Vector2, row: Rect2, id: String, focused: bool) -> void:
	if UiButtons.is_pressed_at(self, row):
		draw_rect(row, ROW_PRESSED)
	var kind: String = kind_of(id)
	var control: Rect2 = value_rect(row, vp, kind)
	var x: float = row.position.x + _px(vp, ROW_PAD_X_PX)
	var text_w: float = control.position.x - x - _px(vp, ROW_PAD_X_PX)
	var label: String = tr(_label_key(id))
	var hint_key: String = _hint_key(id)
	var label_size: int = MenuFont.fit_size(label, LABEL_FONT_SIZE, text_w)
	if hint_key.is_empty():
		MenuFont.text(self, Vector2(x, roundf(row.get_center().y + MenuFont.size(label_size) * 0.3)), label, label_size, LABEL_COLOR,
			HORIZONTAL_ALIGNMENT_LEFT, text_w)
	else:
		MenuFont.text(self, Vector2(x, roundf(row.position.y + row.size.y * 0.44)), label, label_size, LABEL_COLOR,
			HORIZONTAL_ALIGNMENT_LEFT, text_w)
		var hint: String = tr(hint_key)
		MenuFont.text(self, Vector2(x, roundf(row.position.y + row.size.y * 0.78)), hint, MenuFont.fit_size(hint, HINT_FONT_SIZE, text_w),
			HINT_COLOR, HORIZONTAL_ALIGNMENT_LEFT, text_w)
	if kind == KIND_VOLUME:
		_draw_stepper(vp, control, id)
	elif kind == KIND_LANGUAGE:
		_draw_language_select(vp, control)
	else:
		_draw_switch(vp, control, id)
	if focused:
		var c: float = _px(vp, TAB_CUT_PX)
		var ring: PackedVector2Array = HudSkin.chamfer_points(row.grow(-1.0), [c, c, c, c])
		ring.append(ring[0])
		draw_polyline(ring, FOCUS_RING, maxf(_px(vp, FOCUS_RING_PX), 1.0))


func _label_key(id: String) -> String:
	match id:
		"hints":
			return TEXT_HINTS
		"motion":
			return TEXT_MOTION
		"language":
			return TEXT_LANGUAGE
		"card_time":
			return TEXT_CARD_TIME
	return str(TEXT_AUDIO_LABELS.get(id, ""))


func _hint_key(id: String) -> String:
	match id:
		"hints":
			return TEXT_HINTS_HINT
		"motion":
			return TEXT_MOTION_HINT
		"language":
			return TEXT_LANGUAGE_HINT
	return ""


# A two-segment switch: a dark angular well with a thin bronze rim; the chosen segment is a gold slab.
func _draw_switch(vp: Vector2, control: Rect2, id: String) -> void:
	var cut: float = _px(vp, CONTROL_CUT_PX)
	HudSkin.panel(self, control, [cut, cut, cut, cut], CONTROL_WELL, CONTROL_RIM, maxf(_px(vp, CONTROL_RIM_PX), 1.0))
	var on: bool = switch_on(id)
	var labels: Array[String] = [tr(TEXT_OFF), tr(TEXT_ON)]
	var segs: Array[Rect2] = switch_segments(control)
	var inset: float = _px(vp, SEG_INSET_PX)
	var small_cut: float = roundf(cut * 0.5)
	for i: int in 2:
		var chosen: bool = (i == 1) == on
		var seg: Rect2 = segs[i].grow(-inset)
		var pressed: bool = UiButtons.is_pressed_at(self, segs[i])
		if chosen:
			HudSkin.panel(self, seg, [small_cut, small_cut, small_cut, small_cut], CONTROL_GOLD_PRESSED if pressed else CONTROL_GOLD,
				UiButtons.GOLD_FILL_TOP, maxf(_px(vp, 1.0), 1.0))
		elif pressed:
			HudSkin.panel(self, seg, [small_cut, small_cut, small_cut, small_cut], STEP_FILL_PRESSED, Color.TRANSPARENT, 0.0)
		var size_px: int = MenuFont.fit_size(labels[i], VALUE_FONT_SIZE, seg.size.x - inset * 2.0)
		var y: float = roundf(seg.get_center().y + MenuFont.size(size_px) * 0.3)
		if chosen:
			MenuFont.text_outlined(self, Vector2(seg.position.x, y), labels[i], size_px, CONTROL_TEXT_ON, UiButtons.GOLD_FILL_TOP,
				HORIZONTAL_ALIGNMENT_CENTER, seg.size.x)
		else:
			MenuFont.text(self, Vector2(seg.position.x, y), labels[i], size_px, CONTROL_TEXT_OFF, HORIZONTAL_ALIGNMENT_CENTER, seg.size.x)


# A volume stepper: [-] percent over a 10-segment meter [+]; an end button greys out at 0 / 100.
func _draw_stepper(vp: Vector2, control: Rect2, id: String) -> void:
	var parts: Array[Rect2] = stepper_parts(control, vp)
	var pct: int = audio_store().get_volume(id.trim_prefix("vol_"))
	_draw_step_button(vp, parts[0], false, pct > 0)
	_draw_step_button(vp, parts[2], true, pct < 100)
	var block: Rect2 = parts[1]
	MenuFont.text(self, Vector2(block.position.x, roundf(block.position.y + block.size.y * 0.5)), audio_value_text(id), VALUE_FONT_SIZE,
		LABEL_COLOR if pct > 0 else CONTROL_TEXT_OFF, HORIZONTAL_ALIGNMENT_CENTER, block.size.x)
	var mh: float = maxf(_px(vp, METER_H_PX), 2.0)
	var meter := Rect2(block.position.x, block.end.y - mh - _px(vp, 6.0), block.size.x, mh)
	HudSkin.segments(self, meter, METER_SEGMENTS, roundi(float(pct) / 100.0 * METER_SEGMENTS), METER_LIT, maxf(_px(vp, 2.0), 1.0))


func _draw_step_button(vp: Vector2, rect: Rect2, plus: bool, enabled: bool) -> void:
	var cut: float = _px(vp, CONTROL_CUT_PX)
	var pressed: bool = enabled and UiButtons.is_pressed_at(self, rect)
	# Pressed = a gold slab with a dark glyph (clear touch feedback); disabled = a dark well with a grey glyph.
	HudSkin.panel(self, rect, [cut, cut, cut, cut], CONTROL_GOLD_PRESSED if pressed else (STEP_FILL if enabled else CONTROL_WELL),
		UiButtons.GOLD_FILL_TOP if pressed else (CONTROL_RIM if enabled else Color("2A2733")), maxf(_px(vp, CONTROL_RIM_PX), 1.0))
	var c: Vector2 = rect.get_center().round()
	if pressed:
		c.y += _px(vp, 2.0)
	var l: float = _px(vp, GLYPH_LEN_PX)
	var t: float = maxf(_px(vp, GLYPH_THICK_PX), 2.0)
	var col: Color = CONTROL_TEXT_ON if pressed else (STEP_GLYPH if enabled else STEP_GLYPH_OFF)
	draw_rect(Rect2(roundf(c.x - l * 0.5), roundf(c.y - t * 0.5), l, t), col)
	if plus:
		draw_rect(Rect2(roundf(c.x - t * 0.5), roundf(c.y - l * 0.5), t, l), col)


## The display name of language [param code] (written in that language).
func language_name(code: String) -> String:
	return tr(LANG_NAME_KEY_FMT % code)


# The language select box: the current language and a chevron (pointing down, up while the list is open).
func _draw_language_select(vp: Vector2, control: Rect2) -> void:
	var cut: float = _px(vp, CONTROL_CUT_PX)
	var pressed: bool = UiButtons.is_pressed_at(self, control) and not _lang_open
	HudSkin.panel(self, control, [cut, cut, cut, cut], STEP_FILL_PRESSED if pressed or _lang_open else CONTROL_WELL,
		UiButtons.GOLD_RIM if _lang_open else CONTROL_RIM, maxf(_px(vp, CONTROL_RIM_PX), 1.0))
	var pad: float = _px(vp, ROW_PAD_X_PX * 0.75)
	var cw: float = _px(vp, CHEVRON_W_PX)
	var ch: float = _px(vp, CHEVRON_H_PX)
	var text_w: float = control.size.x - pad * 3.0 - cw
	var lang_name: String = language_name(_flow.get_locale()) if _flow != null else tr(value_key("language"))
	var size_px: int = MenuFont.fit_size(lang_name, VALUE_FONT_SIZE, text_w)
	MenuFont.text(self, Vector2(control.position.x + pad, roundf(control.get_center().y + MenuFont.size(size_px) * 0.3)), lang_name, size_px,
		LABEL_COLOR, HORIZONTAL_ALIGNMENT_LEFT, text_w)
	var c := Vector2(roundf(control.end.x - pad - cw * 0.5), roundf(control.get_center().y))
	var tri: PackedVector2Array
	if _lang_open:
		tri = PackedVector2Array([c + Vector2(-cw * 0.5, ch * 0.5), c + Vector2(cw * 0.5, ch * 0.5), c + Vector2(0.0, -ch * 0.5)])
	else:
		tri = PackedVector2Array([c + Vector2(-cw * 0.5, -ch * 0.5), c + Vector2(cw * 0.5, -ch * 0.5), c + Vector2(0.0, ch * 0.5)])
	draw_colored_polygon(tri, STEP_GLYPH)


# The open language list: a dark well with a gold rim, one option per language, the current one gold.
func _draw_language_list(vp: Vector2, control: Rect2) -> void:
	var rects: Array[Rect2] = language_option_rects(control, vp)
	if rects.is_empty():
		return
	var cut: float = _px(vp, CONTROL_CUT_PX)
	var box := Rect2(rects[0].position, Vector2(rects[0].size.x, rects[-1].end.y - rects[0].position.y)).grow(_px(vp, SEG_INSET_PX))
	HudSkin.panel(self, box, [cut, cut, cut, cut], CONTROL_WELL, UiButtons.GOLD_RIM, maxf(_px(vp, CONTROL_RIM_PX), 1.0))
	var opts: Array[String] = language_options()
	var current: String = _flow.get_locale() if _flow != null else ""
	var small_cut: float = roundf(cut * 0.5)
	var pad: float = _px(vp, ROW_PAD_X_PX * 0.75)
	for i: int in rects.size():
		var r: Rect2 = rects[i]
		var chosen: bool = opts[i] == current
		var pressed: bool = UiButtons.is_pressed_at(self, r)
		var slab: Rect2 = r.grow(-_px(vp, 2.0))
		if chosen:
			HudSkin.panel(self, slab, [small_cut, small_cut, small_cut, small_cut], CONTROL_GOLD_PRESSED if pressed else CONTROL_GOLD,
				UiButtons.GOLD_FILL_TOP, maxf(_px(vp, 1.0), 1.0))
		elif pressed:
			HudSkin.panel(self, slab, [small_cut, small_cut, small_cut, small_cut], STEP_FILL_PRESSED, Color.TRANSPARENT, 0.0)
		var opt_name: String = language_name(opts[i])
		var size_px: int = MenuFont.fit_size(opt_name, VALUE_FONT_SIZE, r.size.x - pad * 2.0)
		var y: float = roundf(r.get_center().y + MenuFont.size(size_px) * 0.3)
		if chosen:
			MenuFont.text_outlined(self, Vector2(r.position.x + pad, y), opt_name, size_px, CONTROL_TEXT_ON, UiButtons.GOLD_FILL_TOP,
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0)
		else:
			MenuFont.text(self, Vector2(r.position.x + pad, y), opt_name, size_px, LABEL_COLOR, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0)

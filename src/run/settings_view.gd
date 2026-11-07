class_name SettingsView
extends Node2D
## Settings screen (user 2026-11-01, Main Menu pass): opened from the title ("Cài đặt",
## [method GameFlow.open_settings]). One row per option, label on the left and a toggle button on the right
## that shows the current value and cycles it on tap:
## - Control hints: on / off ([method SettingsStore.set_show_control_hints]).
## - Reduce motion: on / off ([method SettingsStore.set_reduce_motion]).
## - (Card pick time removed 2026-11-07: matches always use the normal card time.)
## - Language: VI / EN ([method GameFlow.toggle_locale]).
## 2026-11-01 (user decision): the Movement row is gone with the pad mode (the joystick is the only movement
## control), so the four rows get back a comfortable height.
## "Về" sits in the bottom-left corner (left thumb reach) and returns to the title. There is no audio in the
## game yet, so no volume row. Every change is saved at once by its store.
## Child of GameFlow (reads it through [member flow_path]); draws and takes input only in
## [constant GameFlow.Phase.SETTINGS]; owns no state. Input dedup as in TitleView (emulated copies —
## device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act). Every string is a TEXT_* key.

const TITLE_COLOR: Color = HudSkin.IVORY
## Labels in the menu ivory; the rows, values and Back are UiButtons ancient plates (2026-11-02).
const LABEL_COLOR: Color = Color("F8F8D0")
const HINT_COLOR: Color = HudSkin.TEXT_DIM
const TITLE_FONT_SIZE: int = 44
const LABEL_FONT_SIZE: int = 30
const HINT_FONT_SIZE: int = 22
const VALUE_FONT_SIZE: int = 26
const BUTTON_FONT_SIZE: int = 28
## Layout as shares of the viewport.
const HEADER_BOTTOM_RATIO: float = 0.13
const ROWS_TOP_RATIO: float = 0.18
const ROW_HEIGHT_RATIO: float = 0.13
const ROW_GAP_RATIO: float = 0.035
const ROWS_LEFT_RATIO: float = 0.12
const ROWS_WIDTH_RATIO: float = 0.76
const VALUE_WIDTH_RATIO: float = 0.24
const BACK_WIDTH_RATIO: float = 0.14
const BACK_HEIGHT_RATIO: float = 0.09
const PAD_RATIO: float = 0.02

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
## Row ids, top to bottom.
## 2026-11-07 (user): the card time row is gone; matches use the normal card time (CombatView).
const ROWS: Array[String] = ["hints", "motion", "language"]

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow


func _ready() -> void:
	_flow = get_node(flow_path) as GameFlow
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	MenuFont.read_args()


func _process(_delta: float) -> void:
	queue_redraw()


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.SETTINGS


## The row rects (full width) for [param viewport_size], top to bottom; pure.
static func row_rects(viewport_size: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var h: float = viewport_size.y * ROW_HEIGHT_RATIO
	var gap: float = viewport_size.y * ROW_GAP_RATIO
	for i: int in ROWS.size():
		rects.append(Rect2(viewport_size.x * ROWS_LEFT_RATIO, viewport_size.y * ROWS_TOP_RATIO + (h + gap) * i,
			viewport_size.x * ROWS_WIDTH_RATIO, h))
	return rects


## The toggle button of a row rect (right side); pure.
static func value_rect(row: Rect2, viewport_size: Vector2) -> Rect2:
	var pad: float = viewport_size.y * PAD_RATIO
	var w: float = viewport_size.x * VALUE_WIDTH_RATIO
	return Rect2(row.end.x - pad - w, row.position.y + pad, w, row.size.y - pad * 2.0)


## "Về" in the bottom-left corner; pure.
static func back_rect(viewport_size: Vector2) -> Rect2:
	var size := Vector2(viewport_size.x * BACK_WIDTH_RATIO, viewport_size.y * BACK_HEIGHT_RATIO)
	var margin: float = viewport_size.y * PAD_RATIO * 1.5
	return Rect2(Vector2(margin, viewport_size.y - margin - size.y), size)


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
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
	if back_rect(vp).has_point(pos):
		get_viewport().set_input_as_handled()
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_flow.close_settings()
		return
	var rows: Array[Rect2] = row_rects(vp)
	for i: int in rows.size():
		# The whole row is the hit area (a big thumb target); the button only shows the value.
		if rows[i].has_point(pos):
			get_viewport().set_input_as_handled()
			if event.device != InputEvent.DEVICE_ID_EMULATION:
				toggle(ROWS[i])
			return


## Cycles the option [param row_id] (one of [constant ROWS]); unknown ids are ignored.
func toggle(row_id: String) -> void:
	var store: SettingsStore = SettingsStore.shared()
	match row_id:
		"hints":
			store.set_show_control_hints(not store.get_show_control_hints())
		"motion":
			store.set_reduce_motion(not store.get_reduce_motion())
		"card_time":
			store.cycle_card_time()
		"language":
			_flow.toggle_locale()


## The value label key of [param row_id] now.
func value_key(row_id: String) -> String:
	var store: SettingsStore = SettingsStore.shared()
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


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	HudSkin.screen_background(self, Rect2(Vector2.ZERO, vp), HEADER_BOTTOM_RATIO)
	MenuFont.text(self, Vector2(0.0, vp.y * HEADER_BOTTOM_RATIO * 0.68), tr(TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	var labels: Dictionary = {"hints": [TEXT_HINTS, TEXT_HINTS_HINT],
		"motion": [TEXT_MOTION, TEXT_MOTION_HINT], "card_time": [TEXT_CARD_TIME, TEXT_CARD_TIME_HINT],
		"language": [TEXT_LANGUAGE, TEXT_LANGUAGE_HINT]}
	var rows: Array[Rect2] = row_rects(vp)
	var pad: float = vp.y * PAD_RATIO
	for i: int in rows.size():
		var row: Rect2 = rows[i]
		var id: String = ROWS[i]
		# 2026-11-02: the ancient plate (navy) instead of the riveted stone frame, which stays on cards only.
		var row_pressed: bool = UiButtons.is_pressed_at(self, row)
		UiButtons.draw_plate(self, row, UiButtons.look(UiButtons.Style.SECONDARY, row_pressed), UiButtons.ui_scale(self), row_pressed)
		var text_w: float = row.size.x - vp.x * VALUE_WIDTH_RATIO - pad * 3.0
		MenuFont.text(self, Vector2(row.position.x + pad * 1.5, row.position.y + row.size.y * 0.45), tr(labels[id][0]),
			LABEL_FONT_SIZE, LABEL_COLOR, HORIZONTAL_ALIGNMENT_LEFT, text_w)
		MenuFont.text(self, Vector2(row.position.x + pad * 1.5, row.position.y + row.size.y * 0.8), tr(labels[id][1]),
			HINT_FONT_SIZE, HINT_COLOR, HORIZONTAL_ALIGNMENT_LEFT, text_w)
		var value: Rect2 = value_rect(row, vp)
		var on: bool = value_key(id) != TEXT_OFF
		var value_look: Dictionary = UiButtons.look(UiButtons.Style.SECONDARY, false, true, on)
		var value_body: Rect2 = UiButtons.draw_plate(self, value, value_look, UiButtons.ui_scale(self), false)
		MenuFont.text_outlined(self, Vector2(value_body.position.x, value_body.get_center().y + VALUE_FONT_SIZE * 0.36), tr(value_key(id)),
			VALUE_FONT_SIZE, value_look["text"], value_look["text_outline"], HORIZONTAL_ALIGNMENT_CENTER, value_body.size.x)
	var back: Rect2 = back_rect(vp)
	UiButtons.draw_button(self, back, tr(TEXT_BACK), UiButtons.Style.SECONDARY, UiButtons.is_pressed_at(self, back), true, BUTTON_FONT_SIZE)

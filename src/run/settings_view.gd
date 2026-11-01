class_name SettingsView
extends Node2D
## Settings screen (user 2026-11-01, Main Menu pass): opened from the title ("Cài đặt",
## [method GameFlow.open_settings]). One row per option, label on the left and a toggle button on the right
## that shows the current value and cycles it on tap:
## - Movement: joystick / d-pad ([method SettingsStore.set_movement]).
## - Control hints: on / off ([method SettingsStore.set_show_control_hints]).
## - Reduce motion: on / off ([method SettingsStore.set_reduce_motion]).
## - Language: VI / EN ([method GameFlow.toggle_locale]).
## "Về" sits in the bottom-left corner (left thumb reach) and returns to the title. There is no audio in the
## game yet, so no volume row. Every change is saved at once by its store.
## Child of GameFlow (reads it through [member flow_path]); draws and takes input only in
## [constant GameFlow.Phase.SETTINGS]; owns no state. Input dedup as in TitleView (emulated copies —
## device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act). Every string is a TEXT_* key.

const TITLE_COLOR: Color = HudSkin.IVORY
## Main Menu pass: the PixelLab stone frames of the title (PixelFrame), labels in the menu's ivory / gold.
const LABEL_COLOR: Color = Color("F8F8D0")
const VALUE_ON_COLOR: Color = Color("F8E080")
const ON_TINT: Color = Color(1.12, 1.08, 1.0)
const OFF_TINT: Color = Color(0.8, 0.8, 0.85)
const PRESSED_TINT: Color = Color(0.75, 0.75, 0.8)
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
const ROW_GAP_RATIO: float = 0.025
const ROWS_LEFT_RATIO: float = 0.12
const ROWS_WIDTH_RATIO: float = 0.76
const VALUE_WIDTH_RATIO: float = 0.24
const BACK_WIDTH_RATIO: float = 0.14
const BACK_HEIGHT_RATIO: float = 0.09
const PAD_RATIO: float = 0.02

const TEXT_TITLE: String = "ui.settings.title"
const TEXT_BACK: String = "ui.settings.back"
const TEXT_MOVEMENT: String = "ui.settings.movement"
const TEXT_MOVEMENT_HINT: String = "ui.settings.movement_hint"
const TEXT_JOYSTICK: String = "ui.settings.joystick"
const TEXT_PAD: String = "ui.settings.pad"
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
## Row ids, top to bottom.
const ROWS: Array[String] = ["movement", "hints", "motion", "language"]

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
		"movement":
			store.set_movement(SettingsStore.MOVEMENT_PAD if store.get_movement() == SettingsStore.MOVEMENT_JOYSTICK else SettingsStore.MOVEMENT_JOYSTICK)
		"hints":
			store.set_show_control_hints(not store.get_show_control_hints())
		"motion":
			store.set_reduce_motion(not store.get_reduce_motion())
		"language":
			_flow.toggle_locale()


## The value label key of [param row_id] now.
func value_key(row_id: String) -> String:
	var store: SettingsStore = SettingsStore.shared()
	match row_id:
		"movement":
			return TEXT_PAD if store.get_movement() == SettingsStore.MOVEMENT_PAD else TEXT_JOYSTICK
		"hints":
			return TEXT_ON if store.get_show_control_hints() else TEXT_OFF
		"motion":
			return TEXT_ON if store.get_reduce_motion() else TEXT_OFF
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
	var labels: Dictionary = {"movement": [TEXT_MOVEMENT, TEXT_MOVEMENT_HINT], "hints": [TEXT_HINTS, TEXT_HINTS_HINT],
		"motion": [TEXT_MOTION, TEXT_MOTION_HINT], "language": [TEXT_LANGUAGE, TEXT_LANGUAGE_HINT]}
	var rows: Array[Rect2] = row_rects(vp)
	var pad: float = vp.y * PAD_RATIO
	for i: int in rows.size():
		var row: Rect2 = rows[i]
		var id: String = ROWS[i]
		PixelFrame.draw(self, PixelFrame.BUTTON_FRAME, row, PixelFrame.BUTTON_MARGIN, PixelFrame.scale_for(vp.y),
			PRESSED_TINT if UiButtons.is_pressed_at(self, row) else Color.WHITE)
		var text_w: float = row.size.x - vp.x * VALUE_WIDTH_RATIO - pad * 3.0
		MenuFont.text(self, Vector2(row.position.x + pad * 1.5, row.position.y + row.size.y * 0.45), tr(labels[id][0]),
			LABEL_FONT_SIZE, LABEL_COLOR, HORIZONTAL_ALIGNMENT_LEFT, text_w)
		MenuFont.text(self, Vector2(row.position.x + pad * 1.5, row.position.y + row.size.y * 0.8), tr(labels[id][1]),
			HINT_FONT_SIZE, HINT_COLOR, HORIZONTAL_ALIGNMENT_LEFT, text_w)
		var value: Rect2 = value_rect(row, vp)
		var on: bool = value_key(id) != TEXT_OFF
		PixelFrame.draw(self, PixelFrame.BUTTON_FRAME, value, PixelFrame.BUTTON_MARGIN, PixelFrame.scale_for(vp.y),
			ON_TINT if on else OFF_TINT)
		MenuFont.text(self, Vector2(value.position.x, value.get_center().y + VALUE_FONT_SIZE * 0.36), tr(value_key(id)),
			VALUE_FONT_SIZE, VALUE_ON_COLOR if on else LABEL_COLOR, HORIZONTAL_ALIGNMENT_CENTER, value.size.x)
	var back: Rect2 = back_rect(vp)
	var back_pressed: bool = UiButtons.is_pressed_at(self, back)
	PixelFrame.draw(self, PixelFrame.BUTTON_FRAME, back, PixelFrame.BUTTON_MARGIN, PixelFrame.scale_for(vp.y),
		PRESSED_TINT if back_pressed else Color.WHITE)
	MenuFont.text(self, Vector2(back.position.x, back.get_center().y + BUTTON_FONT_SIZE * 0.36 + (2.0 if back_pressed else 0.0)),
		tr(TEXT_BACK), BUTTON_FONT_SIZE, LABEL_COLOR, HORIZONTAL_ALIGNMENT_CENTER, back.size.x)

class_name TitleView
extends Node2D
## Title screen (Story 016): the game name drawn with code (big text over a knife-stroke motif of
## three thick slanted lines), a one-line tagline, and a centred column of buttons — "Tiếp tục"
## (only when the save has a floor in progress; resumes it), "Chơi" (floor select; the main
## action when there is nothing to continue) and "Thoát" (hidden on platforms without a quit
## button, see [method GameFlow.can_show_quit]). Child of GameFlow (reads it through
## [member flow_path]); draws and takes taps only in [constant GameFlow.Phase.TITLE]; owns no
## state. Taps are consumed on a button only; input dedup as in RunHudView / DPadView (emulated
## copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act).
## DEV convenience: Enter / Keypad Enter / Space (pressed, not echo) trigger the FIRST button.
## Placeholder art; all strings are TEXT_* keys drawn through tr() (Story 017). A small language button
## (UiButtons NEUTRAL, bottom-right) shows the label of the NEXT locale and cycles [method GameFlow.toggle_locale].

const NAME_COLOR: Color = Color(0.15, 0.12, 0.1)
const TAGLINE_COLOR: Color = Color(0.4, 0.35, 0.3)
const STROKE_COLOR: Color = Color(0.8, 0.25, 0.15, 0.8)
const STROKE_WIDTH: float = 12.0
const NAME_FONT_SIZE: int = 96
const TAGLINE_FONT_SIZE: int = 28
const BUTTON_FONT_SIZE: int = 36
## Baselines of the name and the tagline as shares of the title band height.
const NAME_BASELINE: float = 0.6
const TAGLINE_BASELINE: float = 0.92
## Knife strokes behind the name: (from, to) pairs as shares of the title band size.
const STROKES: Array[Vector2] = [
	Vector2(0.33, 0.78), Vector2(0.43, 0.08),
	Vector2(0.47, 0.82), Vector2(0.57, 0.12),
	Vector2(0.61, 0.78), Vector2(0.71, 0.08),
]

const TEXT_NAME: String = "title.name"
const TEXT_TAGLINE: String = "title.tagline"
const TEXT_CONTINUE: String = "ui.title.continue"
const TEXT_PLAY: String = "ui.title.play"
const TEXT_QUIT: String = "ui.title.quit"
## Labels of the language button by locale code (the button shows the NEXT locale's label).
const TEXT_LANG_VI: String = "ui.title.lang.vi"
const TEXT_LANG_EN: String = "ui.title.lang.en"
const LANG_FONT_SIZE: int = 28

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow


func _ready() -> void:
	_flow = get_node(flow_path) as GameFlow


func _process(_delta: float) -> void:
	if _is_active():
		queue_redraw()


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.TITLE


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	var labels: Array[String] = _button_labels()
	if labels.is_empty():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			_activate(0)
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
	if ScreenLayout.title_lang_button_rect(get_viewport_rect().size).has_point(pos):
		get_viewport().set_input_as_handled()
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_flow.toggle_locale()
		return
	var rects: Array[Rect2] = ScreenLayout.title_button_rects(get_viewport_rect().size, labels.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			get_viewport().set_input_as_handled()
			if event.device != InputEvent.DEVICE_ID_EMULATION:
				_activate(i)
			return


# Label KEYS of the column, top to bottom; the first is the main action (translated when drawn).
func _button_labels() -> Array[String]:
	var labels: Array[String] = []
	if _flow.has_continue():
		labels.append(TEXT_CONTINUE)
	labels.append(TEXT_PLAY)
	if _flow.can_show_quit():
		labels.append(TEXT_QUIT)
	return labels


# Style of button [param index] of [param labels]: the first is PRIMARY, "Chơi" after a
# "Tiếp tục" is SECONDARY, "Thoát" is NEUTRAL.
func _button_style(labels: Array[String], index: int) -> int:
	match labels[index]:
		TEXT_QUIT:
			return UiButtons.Style.NEUTRAL
		TEXT_PLAY:
			return UiButtons.Style.PRIMARY if index == 0 else UiButtons.Style.SECONDARY
	return UiButtons.Style.PRIMARY


# Runs the action of button [param index].
func _activate(index: int) -> void:
	var labels: Array[String] = _button_labels()
	if index < 0 or index >= labels.size():
		return
	match labels[index]:
		TEXT_CONTINUE:
			_flow.continue_requested()
		TEXT_PLAY:
			_flow.start_requested()
		TEXT_QUIT:
			_flow.quit_requested()


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	var band: Rect2 = ScreenLayout.title_rect(vp)
	for i: int in range(0, STROKES.size() - 1, 2):
		draw_line(band.position + band.size * STROKES[i], band.position + band.size * STROKES[i + 1], STROKE_COLOR, STROKE_WIDTH)
	_text(band, band.position.y + band.size.y * NAME_BASELINE, tr(TEXT_NAME), NAME_FONT_SIZE, NAME_COLOR)
	_text(band, band.position.y + band.size.y * TAGLINE_BASELINE, tr(TEXT_TAGLINE), TAGLINE_FONT_SIZE, TAGLINE_COLOR)
	var labels: Array[String] = _button_labels()
	var rects: Array[Rect2] = ScreenLayout.title_button_rects(vp, labels.size())
	for i: int in rects.size():
		UiButtons.draw_button(self, rects[i], tr(labels[i]), _button_style(labels, i), UiButtons.is_pressed_at(self, rects[i]), true, BUTTON_FONT_SIZE)
	var lang: Rect2 = ScreenLayout.title_lang_button_rect(vp)
	UiButtons.draw_button(self, lang, tr(_lang_label(_flow.next_locale())), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, lang), true, LANG_FONT_SIZE)


# Label key of the language button for locale [param code].
func _lang_label(code: String) -> String:
	return TEXT_LANG_EN if code == "en" else TEXT_LANG_VI


# Centred single-line text at baseline [param y] over the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)

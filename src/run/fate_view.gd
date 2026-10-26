class_name FateView
extends Node2D
## Spare / Execute screen (Story 035, Parts A and E1): shown in GameFlow phase FATE after a region boss is
## downed, while no Execute relic offer is open ([method GameFlow.has_fate_offer] false). A dim veil covers
## the battle (the downed boss stays visible behind it), the boss name on top, the question under it.
## Bottom half: two big buttons, "Tha" LEFT (left thumb) and "Giết" RIGHT (right thumb), each
## ScreenLayout.FATE_BUTTON_WIDTH_RATIO of the width, a consequence line under each.
## The choice cannot be undone, so it is HOLD to confirm: a press on a button starts a hold of
## [code]get_fate_view()["hold_sec"][/code] seconds with a progress ring drawn around its label; releasing
## early or sliding off the button cancels; a full hold calls [method GameFlow.choose_fate] with
## "spare" or "execute". Keyboard extra: Left / Right select, hold Enter (or Space) to confirm.
## Child of GameFlow (reads it through [member flow_path]); owns no run state. Input dedup as in
## PieceDeckView (emulated copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed but never act).
## Drawn on top of the battle (z_index). Every string is a TEXT_* key through tr(); presentation constants
## only — the hold time comes from data (world.fate.fate_hold_sec through GameFlow).

const VEIL_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const TITLE_COLOR: Color = Color(1.0, 0.75, 0.2)
const QUESTION_COLOR: Color = Color(0.95, 0.9, 0.78)
const LINE_COLOR: Color = Color(0.95, 0.9, 0.78)
const HINT_COLOR: Color = Color(0.85, 0.82, 0.75)
const RING_TRACK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const RING_COLOR: Color = Color(1.0, 0.85, 0.2)
const KEY_SELECT_COLOR: Color = Color(1.0, 0.85, 0.2)

const TITLE_FONT_SIZE: int = 52
const QUESTION_FONT_SIZE: int = 32
const BUTTON_FONT_SIZE: int = 48
const LINE_FONT_SIZE: int = 26
const HINT_FONT_SIZE: int = 26
const MIN_FIT_FONT_SIZE: int = 12
## Progress ring: radius as a share of the button height, line width, arc points.
const RING_RADIUS_RATIO: float = 0.4
const RING_WIDTH: float = 10.0
const RING_POINTS: int = 48
## The button label fits inside the ring: its width at most this many ring radii.
const LABEL_RING_SHARE: float = 1.5
const KEY_SELECT_WIDTH: float = 6.0
const KEY_SELECT_GROW: float = 8.0
## Draw above the battle and its HUD children of GameFlow.
const DRAW_Z_INDEX: int = 20

## The two choices, in button order (left, right).
const FATES: Array[String] = ["spare", "execute"]

## "%s đã quỵ" (the boss name).
const TEXT_TITLE: String = "ui.fate.title"
const TEXT_QUESTION: String = "ui.fate.question"
const TEXT_SPARE: String = "ui.fate.spare"
const TEXT_EXECUTE: String = "ui.fate.execute"
const TEXT_SPARE_LINE: String = "ui.fate.spare_line"
## "Chọn 1 trong %d bảo vật" (the offer size from data).
const TEXT_EXECUTE_LINE: String = "ui.fate.execute_line"
const TEXT_HOLD_HINT: String = "ui.fate.hold_hint"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow = null
## Button being held (0 = Tha, 1 = Giết, -1 = none) and how long it has been held.
var _hold: int = -1
var _hold_t: float = 0.0
## True when the hold comes from the Enter / Space key (a pointer release does not end it).
var _hold_by_key: bool = false
## Keyboard selection (-1 = none yet).
var _key_choice: int = -1


func _ready() -> void:
	_flow = get_node_or_null(flow_path) as GameFlow
	z_index = DRAW_Z_INDEX


func _process(delta: float) -> void:
	if not is_open():
		_reset()
		queue_redraw()  # clear the last frame (see PieceDeckView)
		return
	if _hold >= 0:
		_hold_t += delta
		if _hold_t >= hold_seconds():
			var fate: String = FATES[_hold]
			_reset()
			_flow.choose_fate(fate)
	queue_redraw()


## True while the screen is shown (phase FATE, no Execute relic offer open).
func is_open() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.FATE and not _flow.has_fate_offer()


## Seconds a button must be held (from [method GameFlow.get_fate_view]).
func hold_seconds() -> float:
	return float(_flow.get_fate_view().get("hold_sec", 0.0)) if _flow != null else 0.0


## Hold progress 0..1 of the held button (0 when nothing is held) — for tests and captures.
func get_hold_progress() -> float:
	if _hold < 0:
		return 0.0
	var need: float = hold_seconds()
	return 1.0 if need <= 0.0 else clampf(_hold_t / need, 0.0, 1.0)


## The fate of the held button ("" when none) — for tests and captures.
func get_held() -> String:
	return FATES[_hold] if _hold >= 0 else ""


## Starts holding [param fate] ("spare" / "execute") for [param seconds] already held, as a press would —
## for tests and captures (the hold then completes in _process unless [method cancel_hold] is called).
func begin_hold(fate: String, seconds: float = 0.0) -> void:
	var index: int = FATES.find(fate)
	if index < 0:
		return
	_hold = index
	_hold_t = maxf(seconds, 0.0)
	_hold_by_key = false


## Cancels a hold in progress (an early release).
func cancel_hold() -> void:
	_hold = -1
	_hold_t = 0.0
	_hold_by_key = false


func _reset() -> void:
	cancel_hold()
	_key_choice = -1


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey:
		_input_key(event as InputEventKey)
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var rects: Array[Rect2] = ScreenLayout.fate_button_rects(get_viewport_rect().size)
	var press: Vector2 = _pointer(event, true)
	if press != Vector2.INF:
		for i: int in rects.size():
			if rects[i].has_point(press):
				begin_hold(FATES[i])
				_key_choice = i
		return
	if _pointer(event, false) != Vector2.INF:
		if not _hold_by_key:
			cancel_hold()  # released before the hold completed
		return
	var drag: Vector2 = _drag_position(event)
	if _hold >= 0 and not _hold_by_key and drag != Vector2.INF and not rects[_hold].has_point(drag):
		cancel_hold()  # slid off the button


func _input_key(key: InputEventKey) -> void:
	var confirm: bool = key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE
	if key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT:
		get_viewport().set_input_as_handled()
		if key.pressed and _hold < 0:
			_key_choice = 0 if key.keycode == KEY_LEFT else 1
		return
	if not confirm:
		return
	get_viewport().set_input_as_handled()
	if key.pressed and not key.echo and _key_choice >= 0 and _hold < 0:
		begin_hold(FATES[_key_choice])
		_hold_by_key = true
	elif not key.pressed and _hold_by_key:
		cancel_hold()


# Press (pressed = true) or release position of a left mouse button / touch; Vector2.INF otherwise.
func _pointer(event: InputEvent, pressed: bool) -> Vector2:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed == pressed:
			return button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed == pressed:
			return touch.position
	return Vector2.INF


func _drag_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.INF


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not is_open():
		return
	var vp: Vector2 = get_viewport_rect().size
	var view: Dictionary = _flow.get_fate_view()
	draw_rect(Rect2(Vector2.ZERO, vp), VEIL_COLOR)
	var band: Rect2 = ScreenLayout.fate_title_rect(vp)
	var title: String = EndingView.format_text(tr(TEXT_TITLE), [tr(str(view.get("boss_name", "")))])
	_text(band, band.get_center().y + TITLE_FONT_SIZE * 0.35, title, _fit(title, vp.x * 0.9, TITLE_FONT_SIZE), TITLE_COLOR)
	var question: Rect2 = ScreenLayout.fate_question_rect(vp)
	_text(question, question.get_center().y + QUESTION_FONT_SIZE * 0.35, tr(TEXT_QUESTION), QUESTION_FONT_SIZE, QUESTION_COLOR)
	var hint: Rect2 = ScreenLayout.fate_hint_rect(vp)
	_text(hint, hint.get_center().y + HINT_FONT_SIZE * 0.35, tr(TEXT_HOLD_HINT), HINT_FONT_SIZE, HINT_COLOR)
	var rects: Array[Rect2] = ScreenLayout.fate_button_rects(vp)
	var labels: Array[String] = [tr(TEXT_SPARE), tr(TEXT_EXECUTE)]
	var lines: Array[String] = [tr(TEXT_SPARE_LINE), EndingView.format_text(tr(TEXT_EXECUTE_LINE), [int(view.get("offers", 0))])]
	var styles: Array[int] = [UiButtons.Style.SECONDARY, UiButtons.Style.DANGER]
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		if i == _key_choice and _hold < 0:
			draw_rect(rect.grow(KEY_SELECT_GROW), KEY_SELECT_COLOR, false, KEY_SELECT_WIDTH)
		UiButtons.draw_button(self, rect, labels[i], styles[i], i == _hold, true, _fit(labels[i], rect.size.y * RING_RADIUS_RATIO * LABEL_RING_SHARE, BUTTON_FONT_SIZE))
		_draw_ring(rect, get_hold_progress() if i == _hold else 0.0)
		var line: Rect2 = ScreenLayout.fate_line_rect(vp, rect)
		_text(line, line.get_center().y + LINE_FONT_SIZE * 0.35, lines[i], _fit(lines[i], line.size.x, LINE_FONT_SIZE), LINE_COLOR)


# The progress ring around a button's label: a faint full track, the held share drawn clockwise from the top.
func _draw_ring(rect: Rect2, progress: float) -> void:
	var radius: float = rect.size.y * RING_RADIUS_RATIO
	var center: Vector2 = rect.get_center()
	draw_arc(center, radius, 0.0, TAU, RING_POINTS, RING_TRACK_COLOR, RING_WIDTH, true)
	if progress > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, RING_POINTS, RING_COLOR, RING_WIDTH, true)


func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


# Largest font size <= [param size] (not below MIN_FIT_FONT_SIZE) at which [param text] fits [param width].
func _fit(text: String, width: float, size: int) -> int:
	var font: Font = ThemeDB.fallback_font
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted).x > width:
		fitted -= 1
	return fitted

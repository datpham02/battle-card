class_name ChapterSelectView
extends Node2D
## Chapter select screen (Story 019, Part C; replaces the Story 015 floor select): one tile per
## chapter of [method GameFlow.get_chapter_states] in a centred row (ScreenLayout.chapter_tile_rects)
## in four looks — LOCKED (grey, code-drawn padlock), UNLOCKED (bright), CLEARED (green outline +
## check mark) and IN_RUN (gold outline + "Đang dở": the saved run is in this chapter; a cleared
## chapter keeps its check). A tile shows the chapter name and its floor count. Child of GameFlow
## (reads it through [member flow_path]); draws and takes taps only in
## [constant GameFlow.Phase.CHAPTER_SELECT], owns no progress.
## Tap an unlocked / cleared tile -> [method GameFlow.start_run] — unless a run is saved (in this
## or another chapter): a confirm panel ("Bỏ run đang dở?", DANGER "Bỏ" / NEUTRAL "Thôi") first;
## start_run then overwrites the save. Tap the in-run tile -> a panel with PRIMARY "Tiếp tục"
## ([method GameFlow.continue_requested]) / DANGER "Chơi lại từ đầu" (start_run). "Về" goes back
## to the character select and the chosen character's name sits top-right
## (ScreenLayout.floor_hero_label_rect). Input dedup as in RunHudView / DPadView (emulated copies
## are consumed but never act). Placeholder art; all strings are TEXT_* keys drawn through tr().

enum Prompt { NONE, CONFIRM_ABANDON, RESUME_CHOICE }

const TITLE_COLOR: Color = Color(0.15, 0.12, 0.1)
const TILE_LOCKED_BACK: Color = Color(0.72, 0.7, 0.66)
const TILE_LOCKED_OUTLINE: Color = Color(0.5, 0.48, 0.44)
const TILE_LOCKED_TEXT: Color = Color(0.4, 0.38, 0.35)
const TILE_OPEN_BACK: Color = Color(1.0, 0.97, 0.9)
const TILE_OPEN_OUTLINE: Color = Color(0.6, 0.52, 0.4)
const TILE_TEXT: Color = Color(0.15, 0.12, 0.1)
const TILE_SUB_TEXT: Color = Color(0.4, 0.35, 0.3)
const CLEARED_OUTLINE: Color = Color(0.2, 0.65, 0.3)
const IN_RUN_OUTLINE: Color = Color(0.95, 0.72, 0.15)
const PADLOCK_COLOR: Color = Color(0.45, 0.43, 0.4)
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const PANEL_BACK: Color = Color(0.1, 0.09, 0.08, 0.96)
const PANEL_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const PANEL_TEXT: Color = Color(0.95, 0.9, 0.78)
const PANEL_SUB_TEXT: Color = Color(0.75, 0.72, 0.65)
## Tile, panel and (through UiButtons) prompt-button outline width.
const OUTLINE_WIDTH: float = 3.0
const STATE_OUTLINE_WIDTH: float = 6.0
const MARK_WIDTH: float = 6.0

const TITLE_FONT_SIZE: int = 48
const TILE_NAME_FONT_SIZE: int = 36
const TILE_SUB_FONT_SIZE: int = 24
const TILE_STATE_FONT_SIZE: int = 26
const PANEL_FONT_SIZE: int = 36
const PANEL_SUB_FONT_SIZE: int = 26
const BUTTON_FONT_SIZE: int = 28
## Story 018: the "Nhân vật: …" label in the title band's right corner.
const HERO_FONT_SIZE: int = 26
const HERO_COLOR: Color = Color(0.4, 0.35, 0.3)

## Text baselines inside a tile / a panel, as shares of their height.
const TILE_NAME_BASELINE: float = 0.3
const TILE_SUB_BASELINE: float = 0.45
const TILE_STATE_BASELINE: float = 0.82
const PANEL_TEXT_BASELINE: float = 0.3
const PANEL_SUB_BASELINE: float = 0.42
## Padlock geometry as shares of the tile size: body size, body centre y, shackle radius.
const LOCK_BODY_W: float = 0.14
const LOCK_BODY_H: float = 0.12
const LOCK_CENTER_Y: float = 0.76
const LOCK_SHACKLE_R: float = 0.05
const ARC_POINTS: int = 12
## Check mark polyline as shares of the tile size.
const CHECK_POINTS: Array[Vector2] = [Vector2(0.74, 0.78), Vector2(0.81, 0.86), Vector2(0.92, 0.68)]
## Key separator of ChaptersConfig.find_floor ("ch1/f2").
const FLOOR_KEY_SEPARATOR: String = "/"

const TEXT_TITLE: String = "ui.chapter_select.title"
## "%d tầng" with the chapter's floor count.
const TEXT_FLOORS: String = "ui.chapter_select.floors"
const TEXT_IN_RUN: String = "ui.chapter_select.in_run"
## "Tầng %d · Trận %d" (1-based) of the saved run, on the resume prompt.
const TEXT_SAVED_POSITION: String = "ui.chapter_select.saved_position"
const TEXT_CONFIRM_ABANDON: String = "ui.chapter_select.confirm_abandon"
const TEXT_ABANDON: String = "ui.chapter_select.abandon"
const TEXT_CANCEL: String = "ui.chapter_select.cancel"
const TEXT_RESUME: String = "ui.chapter_select.resume"
const TEXT_RESTART: String = "ui.chapter_select.restart"
## The back button (ScreenLayout.back_button_rect): to the character select.
const TEXT_BACK: String = "ui.chapter_select.back"
## "Nhân vật: %s" with the selected character's translated name.
const TEXT_HERO: String = "ui.chapter_select.hero"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow
var _panel: Prompt = Prompt.NONE
## Chapter index the open panel is about (-1 = none).
var _pending: int = -1


func _ready() -> void:
	_flow = get_node(flow_path) as GameFlow


func _process(_delta: float) -> void:
	queue_redraw()


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.CHAPTER_SELECT and _flow.get_config() != null


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
	if _panel != Prompt.NONE:
		get_viewport().set_input_as_handled()
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_tap_panel(vp, pos)
		return
	if ScreenLayout.back_button_rect(vp).has_point(pos):
		get_viewport().set_input_as_handled()
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_flow.back_to_character_select()
		return
	var states: Array[Dictionary] = _flow.get_chapter_states()
	var rects: Array[Rect2] = ScreenLayout.chapter_tile_rects(vp, states.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			get_viewport().set_input_as_handled()
			if event.device != InputEvent.DEVICE_ID_EMULATION:
				_tap_tile(states[i])
			return


func _tap_tile(state: Dictionary) -> void:
	if not bool(state.get("unlocked", false)):
		return
	var ci: int = int(state.get("index", -1))
	if bool(state.get("in_run", false)):
		_pending = ci
		_panel = Prompt.RESUME_CHOICE
	elif _flow.has_continue():
		_pending = ci
		_panel = Prompt.CONFIRM_ABANDON
	else:
		_flow.start_run(ci)


# Prompt buttons: index 0 = the main action, 1 = the alternative; a tap elsewhere closes it.
func _tap_panel(vp: Vector2, pos: Vector2) -> void:
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(vp, 2)
	var index: int = -1
	for i: int in rects.size():
		if rects[i].has_point(pos):
			index = i
	var panel: Prompt = _panel
	var target: int = _pending
	_panel = Prompt.NONE
	_pending = -1
	if index < 0:
		return
	match panel:
		Prompt.CONFIRM_ABANDON:
			if index == 0:
				_flow.start_run(target)
		Prompt.RESUME_CHOICE:
			if index == 0:
				_flow.continue_requested()
			else:
				_flow.start_run(target)


# --- State --------------------------------------------------------------------


# (floor, match) of the saved run, 1-based, from the progress dictionary; (1, 1) when unreadable.
func _saved_position() -> Vector2i:
	var saved: Dictionary = _flow.get_progress().get_run_dict()
	var key: String = str(saved.get("chapter", "")) + FLOOR_KEY_SEPARATOR + str(saved.get("floor", ""))
	var pos: Vector2i = _flow.get_config().find_floor(key)
	return Vector2i(maxi(pos.y, 0) + 1, int(saved.get("match_index", 0)) + 1)


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, tr(TEXT_TITLE), TITLE_FONT_SIZE, TITLE_COLOR)
	var back: Rect2 = ScreenLayout.back_button_rect(vp)
	UiButtons.draw_button(self, back, tr(TEXT_BACK), UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, back), true, BUTTON_FONT_SIZE, OUTLINE_WIDTH)
	_draw_hero_label(vp)
	var states: Array[Dictionary] = _flow.get_chapter_states()
	var rects: Array[Rect2] = ScreenLayout.chapter_tile_rects(vp, states.size())
	for i: int in rects.size():
		_draw_tile(rects[i], states[i])
	if _panel != Prompt.NONE:
		_draw_panel(vp)


func _draw_tile(rect: Rect2, state: Dictionary) -> void:
	var locked: bool = not bool(state.get("unlocked", false))
	var cleared: bool = bool(state.get("cleared", false))
	var in_run: bool = bool(state.get("in_run", false))
	draw_rect(rect, TILE_LOCKED_BACK if locked else TILE_OPEN_BACK)
	if in_run:
		draw_rect(rect, IN_RUN_OUTLINE, false, STATE_OUTLINE_WIDTH)
	elif cleared:
		draw_rect(rect, CLEARED_OUTLINE, false, STATE_OUTLINE_WIDTH)
	else:
		draw_rect(rect, TILE_LOCKED_OUTLINE if locked else TILE_OPEN_OUTLINE, false, OUTLINE_WIDTH)
	var text_color: Color = TILE_LOCKED_TEXT if locked else TILE_TEXT
	var sub_color: Color = TILE_LOCKED_TEXT if locked else TILE_SUB_TEXT
	_text(rect, rect.position.y + rect.size.y * TILE_NAME_BASELINE, str(state.get("name", "")), TILE_NAME_FONT_SIZE, text_color)
	_text(rect, rect.position.y + rect.size.y * TILE_SUB_BASELINE, tr(TEXT_FLOORS) % _flow.get_config().floor_count(int(state.get("index", 0))), TILE_SUB_FONT_SIZE, sub_color)
	if locked:
		_draw_padlock(rect)
		return
	if cleared:
		_draw_check(rect)
	if in_run:
		_text(rect, rect.position.y + rect.size.y * TILE_STATE_BASELINE, tr(TEXT_IN_RUN), TILE_STATE_FONT_SIZE, IN_RUN_OUTLINE.darkened(0.2))


# Padlock: a filled body with a half-circle shackle above it.
func _draw_padlock(rect: Rect2) -> void:
	var body_size := Vector2(rect.size.x * LOCK_BODY_W, rect.size.y * LOCK_BODY_H)
	var center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * LOCK_CENTER_Y)
	var body := Rect2(center - body_size * 0.5, body_size)
	draw_rect(body, PADLOCK_COLOR)
	var radius: float = rect.size.x * LOCK_SHACKLE_R
	draw_arc(Vector2(center.x, body.position.y), radius, PI, TAU, ARC_POINTS, PADLOCK_COLOR, MARK_WIDTH)
	draw_line(Vector2(center.x - radius, body.position.y), Vector2(center.x - radius, body.position.y - radius * 0.3), PADLOCK_COLOR, MARK_WIDTH)
	draw_line(Vector2(center.x + radius, body.position.y), Vector2(center.x + radius, body.position.y - radius * 0.3), PADLOCK_COLOR, MARK_WIDTH)


# Check mark: two joined lines in the tile's bottom-right corner.
func _draw_check(rect: Rect2) -> void:
	var points := PackedVector2Array()
	for p: Vector2 in CHECK_POINTS:
		points.append(rect.position + rect.size * p)
	draw_polyline(points, CLEARED_OUTLINE, MARK_WIDTH)


func _draw_panel(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	var panel: Rect2 = ScreenLayout.run_panel_rect(vp)
	draw_rect(panel, PANEL_BACK)
	draw_rect(panel, PANEL_OUTLINE, false, OUTLINE_WIDTH)
	var labels: Array[String] = []
	var message: String = ""
	var sub: String = ""
	# Button styles by prompt: the destructive choice in the warm colour, the safe one green/grey.
	var styles: Array[int] = [UiButtons.Style.DANGER, UiButtons.Style.NEUTRAL]
	match _panel:
		Prompt.CONFIRM_ABANDON:
			message = tr(TEXT_CONFIRM_ABANDON)
			labels = [tr(TEXT_ABANDON), tr(TEXT_CANCEL)]
		Prompt.RESUME_CHOICE:
			var saved: Vector2i = _saved_position()
			message = _flow.get_config().chapter_name(_pending)
			sub = tr(TEXT_SAVED_POSITION) % [saved.x, saved.y]
			labels = [tr(TEXT_RESUME), tr(TEXT_RESTART)]
			styles = [UiButtons.Style.PRIMARY, UiButtons.Style.DANGER]
	_text(panel, panel.position.y + panel.size.y * PANEL_TEXT_BASELINE, message, PANEL_FONT_SIZE, PANEL_TEXT)
	if not sub.is_empty():
		_text(panel, panel.position.y + panel.size.y * PANEL_SUB_BASELINE, sub, PANEL_SUB_FONT_SIZE, PANEL_SUB_TEXT)
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(vp, labels.size())
	for i: int in rects.size():
		UiButtons.draw_button(self, rects[i], labels[i], styles[i], UiButtons.is_pressed_at(self, rects[i]), true, BUTTON_FONT_SIZE, OUTLINE_WIDTH)


# Story 018: the selected character's name, right-aligned in the title band; nothing when none.
func _draw_hero_label(vp: Vector2) -> void:
	var id: String = _flow.get_character_id()
	if id.is_empty():
		return
	var character: Dictionary = _flow.get_characters().get_character(id)
	var rect: Rect2 = ScreenLayout.floor_hero_label_rect(vp)
	var text: String = tr(TEXT_HERO) % tr(str(character.get("name_key", id)))
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.get_center().y + HERO_FONT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, HERO_FONT_SIZE, HERO_COLOR)


# Centred single-line text at baseline [param y] over the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)

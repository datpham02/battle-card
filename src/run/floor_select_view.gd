class_name FloorSelectView
extends Node2D
## Floor select screen (Story 015): one row per chapter, one tile per floor in four states —
## LOCKED (grey, code-drawn padlock), UNLOCKED (bright), CLEARED (green outline + check mark),
## IN_PROGRESS (gold outline + "Trận 3/4"). Child of GameFlow (reads it through [member flow_path]);
## draws and takes taps only in [constant GameFlow.Phase.FLOOR_SELECT], owns no progress.
## Tap an unlocked/cleared tile -> enter the floor from match 1 — unless another floor is in
## progress: a confirm panel ("Bỏ tầng đang dở?") first. Tap the in-progress tile -> a panel with
## "Tiếp tục" / "Chơi lại từ đầu". Input dedup as in RunHudView / DPadView (emulated copies are
## consumed but never act). Placeholder art; all strings are TEXT_* constants.

enum Prompt { NONE, CONFIRM_ABANDON, RESUME_CHOICE }
enum TileState { LOCKED, UNLOCKED, CLEARED, IN_PROGRESS }

const TITLE_COLOR: Color = Color(0.15, 0.12, 0.1)
const CHAPTER_COLOR: Color = Color(0.25, 0.2, 0.15)
const TILE_LOCKED_BACK: Color = Color(0.72, 0.7, 0.66)
const TILE_LOCKED_OUTLINE: Color = Color(0.5, 0.48, 0.44)
const TILE_LOCKED_TEXT: Color = Color(0.4, 0.38, 0.35)
const TILE_OPEN_BACK: Color = Color(1.0, 0.97, 0.9)
const TILE_OPEN_OUTLINE: Color = Color(0.6, 0.52, 0.4)
const TILE_TEXT: Color = Color(0.15, 0.12, 0.1)
const TILE_SUB_TEXT: Color = Color(0.4, 0.35, 0.3)
const CLEARED_OUTLINE: Color = Color(0.2, 0.65, 0.3)
const IN_PROGRESS_OUTLINE: Color = Color(0.95, 0.72, 0.15)
const PADLOCK_COLOR: Color = Color(0.45, 0.43, 0.4)
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const PANEL_BACK: Color = Color(0.1, 0.09, 0.08, 0.96)
const PANEL_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const PANEL_TEXT: Color = Color(0.95, 0.9, 0.78)
const BUTTON_BACK: Color = Color(0.13, 0.45, 0.22)
const BUTTON_ALT_BACK: Color = Color(0.4, 0.2, 0.15)
## Neutral (grey) button: the safe choice next to a destructive one ("Thôi").
const BUTTON_NEUTRAL_BACK: Color = Color(0.32, 0.3, 0.34)
const BUTTON_PRESSED_BACK: Color = Color(0.06, 0.25, 0.12)
const BUTTON_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const BUTTON_PRESSED_OUTLINE: Color = Color(1.0, 0.85, 0.2)
const TEXT_WHITE: Color = Color(1.0, 1.0, 1.0)
const OUTLINE_WIDTH: float = 3.0
const STATE_OUTLINE_WIDTH: float = 6.0
const MARK_WIDTH: float = 6.0

const TITLE_FONT_SIZE: int = 48
const CHAPTER_FONT_SIZE: int = 30
const TILE_NAME_FONT_SIZE: int = 32
const TILE_SUB_FONT_SIZE: int = 22
const TILE_STATE_FONT_SIZE: int = 24
const PANEL_FONT_SIZE: int = 36
const BUTTON_FONT_SIZE: int = 28

## Text baselines inside a tile / the chapter label / a panel, as shares of their height.
const TILE_NAME_BASELINE: float = 0.3
const TILE_SUB_BASELINE: float = 0.5
const TILE_STATE_BASELINE: float = 0.82
const CHAPTER_BASELINE: float = 0.3
const PANEL_TEXT_BASELINE: float = 0.3
## Padlock geometry as shares of the tile size: body size, body centre y, shackle radius.
const LOCK_BODY_W: float = 0.14
const LOCK_BODY_H: float = 0.12
const LOCK_CENTER_Y: float = 0.76
const LOCK_SHACKLE_R: float = 0.05
const ARC_POINTS: int = 12
## Check mark polyline as shares of the tile size.
const CHECK_POINTS: Array[Vector2] = [Vector2(0.74, 0.78), Vector2(0.81, 0.86), Vector2(0.92, 0.68)]

const TEXT_TITLE: String = "CHỌN TẦNG"
const TEXT_IN_PROGRESS: String = "Trận %d/%d"
const TEXT_CONFIRM_ABANDON: String = "Bỏ tầng đang dở?"
const TEXT_ABANDON: String = "Bỏ"
const TEXT_CANCEL: String = "Thôi"
const TEXT_RESUME: String = "Tiếp tục (Trận %d/%d)"
const TEXT_RESTART_FLOOR: String = "Chơi lại từ đầu"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow
var _panel: Prompt = Prompt.NONE
## Floor the open panel is about.
var _pending: Vector2i = GameFlow.NO_FLOOR


func _ready() -> void:
	_flow = get_node(flow_path) as GameFlow


func _process(_delta: float) -> void:
	if _is_active():
		queue_redraw()


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.FLOOR_SELECT and _flow.get_config() != null


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
	var hit: Vector2i = _tile_at(vp, pos)
	if hit == GameFlow.NO_FLOOR:
		return
	get_viewport().set_input_as_handled()
	if event.device != InputEvent.DEVICE_ID_EMULATION:
		_tap_tile(hit)


func _tile_at(vp: Vector2, pos: Vector2) -> Vector2i:
	var config: ChaptersConfig = _flow.get_config()
	for ci: int in config.chapter_count():
		var rects: Array[Rect2] = ScreenLayout.floor_tile_rects(vp, ci, config.floor_count(ci))
		for fi: int in rects.size():
			if rects[fi].has_point(pos):
				return Vector2i(ci, fi)
	return GameFlow.NO_FLOOR


func _tap_tile(pos: Vector2i) -> void:
	match _tile_state(pos.x, pos.y):
		TileState.LOCKED:
			return
		TileState.IN_PROGRESS:
			_pending = pos
			_panel = Prompt.RESUME_CHOICE
		_:
			if _flow.get_progress().has_in_progress():
				_pending = pos
				_panel = Prompt.CONFIRM_ABANDON
			else:
				_flow.enter_floor(pos.x, pos.y, true)


# Prompt buttons: index 0 = the main action, 1 = the alternative; a tap elsewhere closes it.
func _tap_panel(vp: Vector2, pos: Vector2) -> void:
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(vp, 2)
	var index: int = -1
	for i: int in rects.size():
		if rects[i].has_point(pos):
			index = i
	var panel: Prompt = _panel
	var target: Vector2i = _pending
	_panel = Prompt.NONE
	_pending = GameFlow.NO_FLOOR
	if index < 0:
		return
	match panel:
		Prompt.CONFIRM_ABANDON:
			if index == 0:
				_flow.enter_floor(target.x, target.y, true)
		Prompt.RESUME_CHOICE:
			_flow.enter_floor(target.x, target.y, index != 0)


# --- State --------------------------------------------------------------------


func _tile_state(ci: int, fi: int) -> TileState:
	var config: ChaptersConfig = _flow.get_config()
	var progress: ProgressState = _flow.get_progress()
	var key: String = config.floor_key(ci, fi)
	var saved: Dictionary = progress.get_in_progress()
	if not saved.is_empty() and str(saved["floor"]) == key:
		return TileState.IN_PROGRESS
	if progress.is_cleared(key):
		return TileState.CLEARED
	if progress.is_unlocked(config, ci, fi):
		return TileState.UNLOCKED
	return TileState.LOCKED


# Arena line of a tile: the fixed shape's name, "Ngẫu nhiên" for a pool, "" for none.
func _arena_text(ci: int, fi: int) -> String:
	var summary: Dictionary = _flow.get_config().arena_summary(ci, fi)
	match str(summary["kind"]):
		"fixed":
			return ArenaNames.name_for(str(summary["shape"]))
		"pool":
			return ArenaNames.TEXT_RANDOM
		_:
			return ""


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	var config: ChaptersConfig = _flow.get_config()
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, TEXT_TITLE, TITLE_FONT_SIZE, TITLE_COLOR)
	for ci: int in config.chapter_count():
		var label: Rect2 = ScreenLayout.floor_chapter_label_rect(vp, ci)
		draw_string(ThemeDB.fallback_font, Vector2(label.position.x, label.position.y + label.size.y * CHAPTER_BASELINE), config.chapter_name(ci), HORIZONTAL_ALIGNMENT_LEFT, label.size.x, CHAPTER_FONT_SIZE, CHAPTER_COLOR)
		var rects: Array[Rect2] = ScreenLayout.floor_tile_rects(vp, ci, config.floor_count(ci))
		for fi: int in rects.size():
			_draw_tile(rects[fi], ci, fi)
	if _panel != Prompt.NONE:
		_draw_panel(vp)


func _draw_tile(rect: Rect2, ci: int, fi: int) -> void:
	var config: ChaptersConfig = _flow.get_config()
	var state: TileState = _tile_state(ci, fi)
	var locked: bool = state == TileState.LOCKED
	draw_rect(rect, TILE_LOCKED_BACK if locked else TILE_OPEN_BACK)
	match state:
		TileState.CLEARED:
			draw_rect(rect, CLEARED_OUTLINE, false, STATE_OUTLINE_WIDTH)
		TileState.IN_PROGRESS:
			draw_rect(rect, IN_PROGRESS_OUTLINE, false, STATE_OUTLINE_WIDTH)
		_:
			draw_rect(rect, TILE_LOCKED_OUTLINE if locked else TILE_OPEN_OUTLINE, false, OUTLINE_WIDTH)
	var text_color: Color = TILE_LOCKED_TEXT if locked else TILE_TEXT
	var sub_color: Color = TILE_LOCKED_TEXT if locked else TILE_SUB_TEXT
	_text(rect, rect.position.y + rect.size.y * TILE_NAME_BASELINE, config.floor_name(ci, fi), TILE_NAME_FONT_SIZE, text_color)
	_text(rect, rect.position.y + rect.size.y * TILE_SUB_BASELINE, _arena_text(ci, fi), TILE_SUB_FONT_SIZE, sub_color)
	match state:
		TileState.LOCKED:
			_draw_padlock(rect)
		TileState.CLEARED:
			_draw_check(rect)
		TileState.IN_PROGRESS:
			var saved: Dictionary = _flow.get_progress().get_in_progress()
			var text: String = TEXT_IN_PROGRESS % [int(saved["match_index"]) + 1, config.match_count(ci, fi)]
			_text(rect, rect.position.y + rect.size.y * TILE_STATE_BASELINE, text, TILE_STATE_FONT_SIZE, IN_PROGRESS_OUTLINE.darkened(0.2))


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
	var config: ChaptersConfig = _flow.get_config()
	var labels: Array[String] = []
	var message: String = ""
	# Button colours by prompt: destructive choice in the warm colour, safe choice green/grey.
	var backs: Array[Color] = [BUTTON_BACK, BUTTON_ALT_BACK]
	match _panel:
		Prompt.CONFIRM_ABANDON:
			message = TEXT_CONFIRM_ABANDON
			labels = [TEXT_ABANDON, TEXT_CANCEL]
			backs = [BUTTON_ALT_BACK, BUTTON_NEUTRAL_BACK]
		Prompt.RESUME_CHOICE:
			var saved: Dictionary = _flow.get_progress().get_in_progress()
			message = config.floor_name(_pending.x, _pending.y)
			labels = [TEXT_RESUME % [int(saved.get("match_index", 0)) + 1, config.match_count(_pending.x, _pending.y)], TEXT_RESTART_FLOOR]
	_text(panel, panel.position.y + panel.size.y * PANEL_TEXT_BASELINE, message, PANEL_FONT_SIZE, PANEL_TEXT)
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(vp, labels.size())
	for i: int in rects.size():
		var pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and rects[i].has_point(get_viewport().get_mouse_position())
		var back: Color = backs[i]
		draw_rect(rects[i], BUTTON_PRESSED_BACK if pressed else back)
		draw_rect(rects[i], BUTTON_PRESSED_OUTLINE if pressed else BUTTON_OUTLINE, false, OUTLINE_WIDTH)
		_text(rects[i], rects[i].get_center().y + BUTTON_FONT_SIZE * 0.35, labels[i], BUTTON_FONT_SIZE, TEXT_WHITE)


# Centred single-line text at baseline [param y] over the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)

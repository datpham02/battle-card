class_name RunHudView
extends Node2D
## Run UI (Story 011, Story 015): match label, intro banner, between-matches screen, floor-clear
## screen and lose screen. Reads the RunController and redraws every frame; owns no run state.
## It is a child of Main added AFTER the GameFlow, so it draws above the battle (the battle is a
## child of the controller under GameFlow, and canvas items draw in tree order). Placeholder art.
##
## Story 015: the controller comes from the GameFlow at [member flow_path] (signal
## controller_changed; nothing is drawn while it is null). Without a GameFlow (scratch tests) it
## falls back to [member controller_path] and the Story 011 single "Chơi lại" button.
## Buttons are handled in _input and consumed, active only in the phase they belong to; taps are
## routed by button index (ScreenLayout.run_button_rects). Dedup (same rule as DPadView): with
## emulate_mouse_from_touch a touch also arrives as a mouse event and with
## emulate_touch_from_mouse a click also arrives as a touch; both emulated copies carry
## device == InputEvent.DEVICE_ID_EMULATION, are consumed on the button but never act.
## DEV convenience: Enter / Keypad Enter / Space (pressed, not echo) trigger the FIRST button.
## All UI strings are constants here (no localization system exists yet at this tier).

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const BAND_COLOR: Color = Color(0.08, 0.07, 0.06, 0.78)
const PANEL_BACK: Color = Color(0.1, 0.09, 0.08, 0.96)
const PANEL_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const TEXT_LIGHT: Color = Color(0.95, 0.9, 0.78)
const TEXT_WHITE: Color = Color(1.0, 1.0, 1.0)
const TEXT_DIM: Color = Color(0.75, 0.72, 0.65)
const TEXT_WIN: Color = Color(0.45, 0.9, 0.5)
const TEXT_LOSE: Color = Color(1.0, 0.4, 0.35)
const TEXT_BOSS: Color = Color(1.0, 0.75, 0.2)
const LABEL_COLOR: Color = Color(0.15, 0.12, 0.1)
const BUTTON_BACK: Color = Color(0.13, 0.45, 0.22)
const BUTTON_ALT_BACK: Color = Color(0.3, 0.3, 0.32)
const BUTTON_PRESSED_BACK: Color = Color(0.06, 0.25, 0.12)
const BUTTON_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const BUTTON_PRESSED_OUTLINE: Color = Color(1.0, 0.85, 0.2)
const OUTLINE_WIDTH: float = 4.0

const LABEL_FONT_SIZE: int = 16
const BAND_TITLE_FONT_SIZE: int = 64
const BAND_NAME_FONT_SIZE: int = 36
const BAND_HINT_FONT_SIZE: int = 24
const TITLE_FONT_SIZE: int = 56
const LINE_FONT_SIZE: int = 30
const SMALL_FONT_SIZE: int = 22
const BUTTON_FONT_SIZE: int = 40
const BUTTON_PAIR_FONT_SIZE: int = 32

## Intro band text baselines as shares of the band height.
const BAND_TITLE_BASELINE: float = 0.38
const BAND_NAME_BASELINE: float = 0.64
const BAND_HINT_BASELINE: float = 0.88
## Panel text baselines as shares of the panel height (the buttons sit below them).
const PANEL_TITLE_BASELINE: float = 0.16
const PANEL_LINE1_BASELINE: float = 0.29
const PANEL_LINE2_BASELINE: float = 0.40
const PANEL_LINE3_BASELINE: float = 0.51
const PANEL_NOTE_BASELINE: float = 0.60

const TEXT_MATCH_LABEL: String = "Trận %d/%d · %s"
const TEXT_MATCH_LABEL_BOSS: String = "BOSS · %s"
## Story 015: the floor name leads the label ("Tầng 2 · Trận 1/4 · Bếp trưởng").
const TEXT_MATCH_LABEL_FLOOR: String = "%s · %s"
## Story 014: the match label ends with the arena's display name when the battle has a named
## arena ("Trận 3/4 · Bếp trưởng · Chữ thập"), plus a variant marker for seeded variants.
const TEXT_MATCH_LABEL_ARENA: String = "%s · %s"
const TEXT_ARENA_VARIANT: String = " (biến thể)"
const TEXT_INTRO_TITLE: String = "TRẬN %d/%d"
const TEXT_INTRO_TITLE_BOSS: String = "TRẬN BOSS"
const TEXT_INTRO_HINT: String = "Nhặt điểm · nối hình · Chốt"
const TEXT_BETWEEN_TITLE: String = "THẮNG TRẬN!"
const TEXT_HEAL: String = "+%d HP"
const TEXT_HP: String = "HP %d/%d"
const TEXT_NEXT: String = "Đối thủ kế: %s"
const TEXT_CONTINUE: String = "Tiếp tục"
const TEXT_AUTO: String = "tự động sau %d s"
const TEXT_WIN_TITLE: String = "CHIẾN THẮNG!"
const TEXT_WIN_LINE: String = "Hạ gục %s"
const TEXT_FLOOR_CLEAR_TITLE: String = "TẦNG XONG"
const TEXT_CHAPTER_CLEAR_TITLE: String = "CHƯƠNG XONG"
const TEXT_LOSE_TITLE: String = "THUA!"
const TEXT_LOSE_LINE: String = "Gục ngã ở trận %d/%d · %s"
const TEXT_TIME: String = "Thời gian %s"
const TEXT_CLEARED: String = "Trận thắng %d/%d"
const TEXT_RESTART: String = "Chơi lại"
const TEXT_RETRY_MATCH: String = "Chơi lại trận"
const TEXT_NEXT_FLOOR: String = "Tầng tiếp"
const TEXT_CHOOSE_FLOOR: String = "Chọn tầng"

## Path to the GameFlow (a sibling under Main) that owns the controller.
@export var flow_path: NodePath = NodePath("../GameFlow")
## Fallback: a fixed RunController (scratch tests without a GameFlow).
@export var controller_path: NodePath = NodePath("../RunController")

var _flow: GameFlow = null
var _controller: RunController = null


func _ready() -> void:
	_flow = get_node_or_null(flow_path) as GameFlow
	if _flow != null:
		_flow.controller_changed.connect(_on_controller_changed)
		_controller = _flow.get_controller()
	else:
		_controller = get_node_or_null(controller_path) as RunController


func _process(_delta: float) -> void:
	queue_redraw()


func _on_controller_changed(controller: RunController) -> void:
	_controller = controller


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _has_controller():
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
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(get_viewport_rect().size, labels.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			get_viewport().set_input_as_handled()
			if event.device != InputEvent.DEVICE_ID_EMULATION:
				_activate(i)
			return


func _has_controller() -> bool:
	return _controller != null and _controller.get_state() != null


# Labels of the buttons of the current phase, left to right; empty when the phase has none.
func _button_labels() -> Array[String]:
	match _controller.get_state().get_phase():
		RunState.Phase.BETWEEN:
			return [TEXT_CONTINUE]
		RunState.Phase.WON:
			if _flow == null:
				return [TEXT_RESTART]
			if _flow.get_next_floor() != GameFlow.NO_FLOOR and not _is_chapter_clear():
				return [TEXT_NEXT_FLOOR, TEXT_CHOOSE_FLOOR]
			return [TEXT_CHOOSE_FLOOR]
		RunState.Phase.LOST:
			if _flow == null:
				return [TEXT_RESTART]
			return [TEXT_RETRY_MATCH, TEXT_CHOOSE_FLOOR]
	return []


# Runs the action of button [param index] of the current phase.
func _activate(index: int) -> void:
	var labels: Array[String] = _button_labels()
	if index < 0 or index >= labels.size():
		return
	match labels[index]:
		TEXT_CONTINUE:
			_controller.advance_requested()
		TEXT_RESTART:
			_controller.restart_requested()
		TEXT_RETRY_MATCH:
			_flow.retry_requested()
		TEXT_NEXT_FLOOR:
			_flow.next_floor_requested()
		TEXT_CHOOSE_FLOOR:
			_flow.leave_floor()


# True when the floor just won is the last of its chapter (the story shows only "Chọn tầng").
func _is_chapter_clear() -> bool:
	if _flow == null:
		return false
	var pos: Vector2i = _flow.get_current_floor()
	return _flow.get_config().is_last_floor_of_chapter(pos.x, pos.y)


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _has_controller():
		return
	var vp: Vector2 = get_viewport_rect().size
	var state: RunState = _controller.get_state()
	match state.get_phase():
		RunState.Phase.INTRO:
			_draw_match_label(vp)
			_draw_intro(vp)
		RunState.Phase.PLAYING:
			_draw_match_label(vp)
		RunState.Phase.BETWEEN:
			_draw_match_label(vp)
			_draw_between(vp)
		RunState.Phase.WON:
			_draw_won(vp)
		RunState.Phase.LOST:
			_draw_lost(vp)


# Centred single-line text at baseline [param y] over the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


func _match_name(index: int) -> String:
	return str(_controller.get_config().matches[index].get("display_name", ""))


func _boss_index() -> int:
	return _controller.get_state().get_match_count() - 1


func _draw_match_label(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var opponent: String = _match_name(state.get_match_index())
	var text: String = TEXT_MATCH_LABEL_BOSS % opponent if state.is_boss_match() else TEXT_MATCH_LABEL % [state.get_match_index() + 1, state.get_match_count(), opponent]
	if not _controller.floor_label.is_empty():
		text = TEXT_MATCH_LABEL_FLOOR % [_controller.floor_label, text]
	var arena: String = _arena_name()
	if not arena.is_empty():
		text = TEXT_MATCH_LABEL_ARENA % [text, arena]
	var rect: Rect2 = ScreenLayout.run_match_label_rect(vp)
	_text(rect, rect.get_center().y + LABEL_FONT_SIZE * 0.35, text, LABEL_FONT_SIZE, LABEL_COLOR)


# Display name of the current battle's arena (+ variant marker); "" when the battle has none
# (combat.json board) or is not spawned yet.
func _arena_name() -> String:
	var battle: Node = _controller.get_battle()
	if battle == null:
		return ""
	var view := battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
	if view == null or view.get_grid() == null:
		return ""
	var info: Dictionary = view.get_arena_info()
	var shape: String = str(info.get("shape", ""))
	if shape.is_empty():
		return ""
	var display: String = ArenaNames.name_for(shape)
	if bool(info.get("variant", false)):
		display += TEXT_ARENA_VARIANT
	return display


func _draw_intro(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var band: Rect2 = ScreenLayout.run_intro_band_rect(vp)
	draw_rect(band, BAND_COLOR)
	var title: String = TEXT_INTRO_TITLE_BOSS if state.is_boss_match() else TEXT_INTRO_TITLE % [state.get_match_index() + 1, state.get_match_count()]
	_text(band, band.position.y + band.size.y * BAND_TITLE_BASELINE, title, BAND_TITLE_FONT_SIZE, TEXT_BOSS if state.is_boss_match() else TEXT_WHITE)
	_text(band, band.position.y + band.size.y * BAND_NAME_BASELINE, _match_name(state.get_match_index()), BAND_NAME_FONT_SIZE, TEXT_LIGHT)
	_text(band, band.position.y + band.size.y * BAND_HINT_BASELINE, TEXT_INTRO_HINT, BAND_HINT_FONT_SIZE, TEXT_DIM)


func _draw_between(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var config: RunConfig = _controller.get_config()
	var panel: Rect2 = _draw_panel(vp)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, TEXT_BETWEEN_TITLE, TITLE_FONT_SIZE, TEXT_WIN)
	var max_hp: float = _controller.get_player_max_hp()
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, TEXT_HEAL % roundi(config.heal_between_matches), LINE_FONT_SIZE, TEXT_LIGHT)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE2_BASELINE, TEXT_HP % [ceili(state.get_carried_hp()), ceili(max_hp)], LINE_FONT_SIZE, TEXT_WHITE)
	var next_index: int = mini(state.get_match_index() + 1, _boss_index())
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE3_BASELINE, TEXT_NEXT % _match_name(next_index), LINE_FONT_SIZE, TEXT_LIGHT)
	if config.between_sec > 0.0:
		_text(panel, panel.position.y + panel.size.y * PANEL_NOTE_BASELINE, TEXT_AUTO % ceili(_controller.get_between_left()), SMALL_FONT_SIZE, TEXT_DIM)
	_draw_buttons(vp)


# Floor-clear screen (Story 015): "TẦNG XONG" + floor name, or "CHƯƠNG XONG" + chapter name on
# the chapter's last floor. Without a GameFlow: the Story 011 win screen.
func _draw_won(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var panel: Rect2 = _draw_panel(vp)
	var title: String = TEXT_WIN_TITLE
	var line: String = TEXT_WIN_LINE % _match_name(_boss_index())
	if _flow != null:
		var pos: Vector2i = _flow.get_current_floor()
		if _is_chapter_clear():
			title = TEXT_CHAPTER_CLEAR_TITLE
			line = _flow.get_config().chapter_name(pos.x)
		else:
			title = TEXT_FLOOR_CLEAR_TITLE
			line = _flow.get_config().floor_name(pos.x, pos.y)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, title, TITLE_FONT_SIZE, TEXT_WIN)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, line, LINE_FONT_SIZE, TEXT_BOSS)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE2_BASELINE, TEXT_TIME % state.get_elapsed_text(), LINE_FONT_SIZE, TEXT_WHITE)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE3_BASELINE, TEXT_CLEARED % [state.get_match_count(), state.get_match_count()], LINE_FONT_SIZE, TEXT_LIGHT)
	_draw_buttons(vp)


func _draw_lost(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var panel: Rect2 = _draw_panel(vp)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, TEXT_LOSE_TITLE, TITLE_FONT_SIZE, TEXT_LOSE)
	var line: String = TEXT_LOSE_LINE % [state.get_match_index() + 1, state.get_match_count(), _match_name(state.get_match_index())]
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, line, LINE_FONT_SIZE, TEXT_LIGHT)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE2_BASELINE, TEXT_TIME % state.get_elapsed_text(), LINE_FONT_SIZE, TEXT_WHITE)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE3_BASELINE, TEXT_CLEARED % [state.get_match_index(), state.get_match_count()], LINE_FONT_SIZE, TEXT_LIGHT)
	_draw_buttons(vp)


# Dim overlay over the whole screen plus the centred panel; returns the panel rect.
func _draw_panel(vp: Vector2) -> Rect2:
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	var panel: Rect2 = ScreenLayout.run_panel_rect(vp)
	draw_rect(panel, PANEL_BACK)
	draw_rect(panel, PANEL_OUTLINE, false, OUTLINE_WIDTH)
	return panel


# The buttons of the current phase, left to right (the first is the main action).
func _draw_buttons(vp: Vector2) -> void:
	var labels: Array[String] = _button_labels()
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(vp, labels.size())
	var font_size: int = BUTTON_FONT_SIZE if labels.size() == 1 else BUTTON_PAIR_FONT_SIZE
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and rect.has_point(get_viewport().get_mouse_position())
		var back: Color = BUTTON_BACK if i == 0 else BUTTON_ALT_BACK
		draw_rect(rect, BUTTON_PRESSED_BACK if pressed else back)
		draw_rect(rect, BUTTON_PRESSED_OUTLINE if pressed else BUTTON_OUTLINE, false, OUTLINE_WIDTH)
		_text(rect, rect.get_center().y + font_size * 0.35, labels[i], font_size, TEXT_WHITE)

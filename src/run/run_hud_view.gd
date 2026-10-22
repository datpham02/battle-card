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
## Story 016: in PLAYING a pause button sits in the HUD band (ScreenLayout.pause_button_rect),
## dimmed while [method RunController.can_pause] is false; while the controller is paused a
## full-screen overlay ("TẠM DỪNG", "Tiếp tục" / "Về chọn tầng" on the run panel) swallows every
## pointer event, and Enter / Space resume. Buttons are painted by UiButtons (shared look).
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
const OUTLINE_WIDTH: float = 4.0
## Pause glyph ("||"): bar width, bar height and the gap between the bars, as shares of the
## button side; drawn in TEXT_WHITE (dimmed with the button when pausing is not allowed).
const PAUSE_BAR_WIDTH_RATIO: float = 0.14
const PAUSE_BAR_HEIGHT_RATIO: float = 0.46
const PAUSE_BAR_GAP_RATIO: float = 0.14

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

const TEXT_MATCH_LABEL: String = "ui.run_hud.match_label"
const TEXT_MATCH_LABEL_BOSS: String = "ui.run_hud.match_label_boss"
## Story 015: the floor name leads the label ("Lối mòn · Trận 1/4 · Sói đầu đàn").
const TEXT_MATCH_LABEL_FLOOR: String = "ui.run_hud.match_label_floor"
## Story 014: the match label ends with the arena's display name when the battle has a named
## arena ("Trận 3/4 · Thủ lĩnh Goblin · Chữ thập"), plus a variant marker for seeded variants.
const TEXT_MATCH_LABEL_ARENA: String = "ui.run_hud.match_label_arena"
const TEXT_ARENA_VARIANT: String = "ui.run_hud.arena_variant"
const TEXT_INTRO_TITLE: String = "ui.run_hud.intro_title"
const TEXT_INTRO_TITLE_BOSS: String = "ui.run_hud.intro_title_boss"
const TEXT_INTRO_HINT: String = "ui.run_hud.intro_hint"
const TEXT_BETWEEN_TITLE: String = "ui.run_hud.between_title"
const TEXT_HEAL: String = "ui.run_hud.heal"
const TEXT_HP: String = "ui.run_hud.hp"
const TEXT_NEXT: String = "ui.run_hud.next"
const TEXT_CONTINUE: String = "ui.run_hud.continue"
const TEXT_AUTO: String = "ui.run_hud.auto"
const TEXT_WIN_TITLE: String = "ui.run_hud.win_title"
const TEXT_WIN_LINE: String = "ui.run_hud.win_line"
const TEXT_FLOOR_CLEAR_TITLE: String = "ui.run_hud.floor_clear_title"
const TEXT_CHAPTER_CLEAR_TITLE: String = "ui.run_hud.chapter_clear_title"
const TEXT_LOSE_TITLE: String = "ui.run_hud.lose_title"
const TEXT_LOSE_LINE: String = "ui.run_hud.lose_line"
const TEXT_TIME: String = "ui.run_hud.time"
const TEXT_CLEARED: String = "ui.run_hud.cleared"
const TEXT_RESTART: String = "ui.run_hud.restart"
const TEXT_RETRY_MATCH: String = "ui.run_hud.retry_match"
const TEXT_NEXT_FLOOR: String = "ui.run_hud.next_floor"
## Chapter-clear screen: enters the first floor of the next chapter (user decision 2026-10-21).
const TEXT_NEXT_CHAPTER: String = "ui.run_hud.next_chapter"
const TEXT_CHOOSE_FLOOR: String = "ui.run_hud.choose_floor"
## Story 016 pause overlay.
const TEXT_PAUSE_TITLE: String = "ui.run_hud.pause_title"
const TEXT_RESUME: String = "ui.run_hud.resume"
const TEXT_LEAVE_FLOOR: String = "ui.run_hud.leave_floor"

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
	if _controller.is_paused():
		_input_paused(event)
		return
	var labels: Array[String] = _button_labels()
	if event is InputEventKey:
		if labels.is_empty():
			return
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			_activate(0)
		return
	var pos: Vector2 = _press_position(event)
	if pos == Vector2.INF:
		return
	var vp: Vector2 = get_viewport_rect().size
	if _controller.get_state().get_phase() == RunState.Phase.PLAYING:
		# Story 016: the pause button; a tap on it is consumed even when pausing is not allowed
		# (set_paused is a no-op then), so nothing under the band reacts.
		if ScreenLayout.pause_button_rect(vp).has_point(pos):
			get_viewport().set_input_as_handled()
			if event.device != InputEvent.DEVICE_ID_EMULATION:
				_controller.set_paused(true)
		return
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(vp, labels.size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			get_viewport().set_input_as_handled()
			if event.device != InputEvent.DEVICE_ID_EMULATION:
				_activate(i)
			return


# Story 016, while paused: Enter / Space resume; EVERY pointer event is swallowed (the battle
# is process-disabled, this keeps the d-pad / hand / cut UI from seeing a release or drag too);
# a press on an overlay button runs it. Esc is left to GameFlow (ui_cancel -> toggle_pause).
func _input_paused(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			_activate(0)
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	var pos: Vector2 = _press_position(event)
	if pos == Vector2.INF or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(get_viewport_rect().size, _button_labels().size())
	for i: int in rects.size():
		if rects[i].has_point(pos):
			_activate(i)
			return


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


func _has_controller() -> bool:
	return _controller != null and _controller.get_state() != null


# Label KEYS of the buttons of the current phase, left to right (translated when drawn); empty when the phase has none.
# Story 016: while paused, the overlay's buttons (only "Tiếp tục" without a GameFlow).
func _button_labels() -> Array[String]:
	if _controller.is_paused():
		if _flow == null:
			return [TEXT_RESUME]
		return [TEXT_RESUME, TEXT_LEAVE_FLOOR]
	match _controller.get_state().get_phase():
		RunState.Phase.BETWEEN:
			return [TEXT_CONTINUE]
		RunState.Phase.WON:
			if _flow == null:
				return [TEXT_RESTART]
			if _flow.get_next_floor() != GameFlow.NO_FLOOR:
				return [TEXT_NEXT_CHAPTER if _is_chapter_clear() else TEXT_NEXT_FLOOR, TEXT_CHOOSE_FLOOR]
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
	if _controller.is_paused():
		if index == 0:
			_controller.set_paused(false)
		else:
			_flow.leave_floor()
		return
	match labels[index]:
		TEXT_CONTINUE:
			_controller.advance_requested()
		TEXT_RESTART:
			_controller.restart_requested()
		TEXT_RETRY_MATCH:
			_flow.retry_requested()
		TEXT_NEXT_FLOOR, TEXT_NEXT_CHAPTER:
			_flow.next_floor_requested()
		TEXT_CHOOSE_FLOOR:
			_flow.leave_floor()


# True when the floor just won is the last of its chapter ("CHƯƠNG XONG", button "Chương tiếp").
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
			_draw_pause_button(vp)
			if _controller.is_paused():
				_draw_paused(vp)
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


# Translated opponent name of match [param index] (name_key, or a legacy literal display_name).
func _match_name(index: int) -> String:
	return RunConfig.match_name(_controller.get_config().matches[index])


func _boss_index() -> int:
	return _controller.get_state().get_match_count() - 1


func _draw_match_label(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var opponent: String = _match_name(state.get_match_index())
	var text: String = tr(TEXT_MATCH_LABEL_BOSS) % opponent if state.is_boss_match() else tr(TEXT_MATCH_LABEL) % [state.get_match_index() + 1, state.get_match_count(), opponent]
	if not _controller.floor_label.is_empty():
		text = tr(TEXT_MATCH_LABEL_FLOOR) % [_controller.floor_label, text]
	var arena: String = _arena_name()
	if not arena.is_empty():
		text = tr(TEXT_MATCH_LABEL_ARENA) % [text, arena]
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
		display += tr(TEXT_ARENA_VARIANT)
	return display


func _draw_intro(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var band: Rect2 = ScreenLayout.run_intro_band_rect(vp)
	draw_rect(band, BAND_COLOR)
	var title: String = tr(TEXT_INTRO_TITLE_BOSS) if state.is_boss_match() else tr(TEXT_INTRO_TITLE) % [state.get_match_index() + 1, state.get_match_count()]
	_text(band, band.position.y + band.size.y * BAND_TITLE_BASELINE, title, BAND_TITLE_FONT_SIZE, TEXT_BOSS if state.is_boss_match() else TEXT_WHITE)
	_text(band, band.position.y + band.size.y * BAND_NAME_BASELINE, _match_name(state.get_match_index()), BAND_NAME_FONT_SIZE, TEXT_LIGHT)
	_text(band, band.position.y + band.size.y * BAND_HINT_BASELINE, tr(TEXT_INTRO_HINT), BAND_HINT_FONT_SIZE, TEXT_DIM)


func _draw_between(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var config: RunConfig = _controller.get_config()
	var panel: Rect2 = _draw_panel(vp)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, tr(TEXT_BETWEEN_TITLE), TITLE_FONT_SIZE, TEXT_WIN)
	var max_hp: float = _controller.get_player_max_hp()
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, tr(TEXT_HEAL) % roundi(config.heal_between_matches), LINE_FONT_SIZE, TEXT_LIGHT)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE2_BASELINE, tr(TEXT_HP) % [ceili(state.get_carried_hp()), ceili(max_hp)], LINE_FONT_SIZE, TEXT_WHITE)
	var next_index: int = mini(state.get_match_index() + 1, _boss_index())
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE3_BASELINE, tr(TEXT_NEXT) % _match_name(next_index), LINE_FONT_SIZE, TEXT_LIGHT)
	if config.between_sec > 0.0:
		_text(panel, panel.position.y + panel.size.y * PANEL_NOTE_BASELINE, tr(TEXT_AUTO) % ceili(_controller.get_between_left()), SMALL_FONT_SIZE, TEXT_DIM)
	_draw_buttons(vp)


# Floor-clear screen (Story 015): "TẦNG XONG" + floor name, or "CHƯƠNG XONG" + chapter name on
# the chapter's last floor. Without a GameFlow: the Story 011 win screen.
func _draw_won(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var panel: Rect2 = _draw_panel(vp)
	var title: String = tr(TEXT_WIN_TITLE)
	var line: String = tr(TEXT_WIN_LINE) % _match_name(_boss_index())
	if _flow != null:
		var pos: Vector2i = _flow.get_current_floor()
		if _is_chapter_clear():
			title = tr(TEXT_CHAPTER_CLEAR_TITLE)
			line = _flow.get_config().chapter_name(pos.x)
		else:
			title = tr(TEXT_FLOOR_CLEAR_TITLE)
			line = _flow.get_config().floor_name(pos.x, pos.y)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, title, TITLE_FONT_SIZE, TEXT_WIN)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, line, LINE_FONT_SIZE, TEXT_BOSS)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE2_BASELINE, tr(TEXT_TIME) % state.get_elapsed_text(), LINE_FONT_SIZE, TEXT_WHITE)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE3_BASELINE, tr(TEXT_CLEARED) % [state.get_match_count(), state.get_match_count()], LINE_FONT_SIZE, TEXT_LIGHT)
	_draw_buttons(vp)


func _draw_lost(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var panel: Rect2 = _draw_panel(vp)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, tr(TEXT_LOSE_TITLE), TITLE_FONT_SIZE, TEXT_LOSE)
	var line: String = tr(TEXT_LOSE_LINE) % [state.get_match_index() + 1, state.get_match_count(), _match_name(state.get_match_index())]
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, line, LINE_FONT_SIZE, TEXT_LIGHT)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE2_BASELINE, tr(TEXT_TIME) % state.get_elapsed_text(), LINE_FONT_SIZE, TEXT_WHITE)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE3_BASELINE, tr(TEXT_CLEARED) % [state.get_match_index(), state.get_match_count()], LINE_FONT_SIZE, TEXT_LIGHT)
	_draw_buttons(vp)


# Story 016: the pause button in the HUD band — a neutral button with a "||" glyph, dimmed
# while the controller cannot pause (skill menu open, swing lockout, already paused).
func _draw_pause_button(vp: Vector2) -> void:
	var rect: Rect2 = ScreenLayout.pause_button_rect(vp)
	var enabled: bool = _controller.can_pause()
	UiButtons.draw_button(self, rect, "", UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, rect), enabled)
	var side: float = rect.size.y
	var bar := Vector2(side * PAUSE_BAR_WIDTH_RATIO, side * PAUSE_BAR_HEIGHT_RATIO)
	var gap: float = side * PAUSE_BAR_GAP_RATIO
	var color: Color = TEXT_WHITE
	if not enabled:
		color.a *= UiButtons.DIM_ALPHA
	var center: Vector2 = rect.get_center()
	draw_rect(Rect2(center - Vector2(gap * 0.5 + bar.x, bar.y * 0.5), bar), color)
	draw_rect(Rect2(center - Vector2(-gap * 0.5, bar.y * 0.5), bar), color)


# Story 016: the pause overlay — dim, panel, "TẠM DỪNG" and the resume / leave buttons.
func _draw_paused(vp: Vector2) -> void:
	var panel: Rect2 = _draw_panel(vp)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, tr(TEXT_PAUSE_TITLE), TITLE_FONT_SIZE, TEXT_LIGHT)
	_draw_buttons(vp)


# Dim overlay over the whole screen plus the centred panel; returns the panel rect.
func _draw_panel(vp: Vector2) -> Rect2:
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	var panel: Rect2 = ScreenLayout.run_panel_rect(vp)
	draw_rect(panel, PANEL_BACK)
	draw_rect(panel, PANEL_OUTLINE, false, OUTLINE_WIDTH)
	return panel


# The buttons of the current phase, left to right (the first is the main action, PRIMARY; the
# others SECONDARY — NEUTRAL on the pause overlay, where the second one leaves the floor).
func _draw_buttons(vp: Vector2) -> void:
	var labels: Array[String] = _button_labels()
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(vp, labels.size())
	var font_size: int = BUTTON_FONT_SIZE if labels.size() == 1 else BUTTON_PAIR_FONT_SIZE
	var alt_style: int = UiButtons.Style.NEUTRAL if _controller.is_paused() else UiButtons.Style.SECONDARY
	for i: int in rects.size():
		var style: int = UiButtons.Style.PRIMARY if i == 0 else alt_style
		UiButtons.draw_button(self, rects[i], tr(labels[i]), style, UiButtons.is_pressed_at(self, rects[i]), true, font_size)

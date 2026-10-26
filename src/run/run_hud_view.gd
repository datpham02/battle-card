class_name RunHudView
extends Node2D
## Run UI (Story 011, 015, 016, 019): match label + deck label, intro banner, pause button and
## pause overlay, and the run result screens. Reads the RunController / GameFlow and redraws every
## frame; owns no run state. It is a child of Main added AFTER the GameFlow, so it draws above the
## battle (the battle is a child of the controller under GameFlow, and canvas items draw in tree
## order); RewardView comes after it and covers it while an offer is open. Placeholder art.
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
## full-screen overlay ("TẠM DỪNG", "Tiếp tục" / "Thoát run (đã lưu)") swallows every pointer
## event, and Enter / Space resume. Buttons are painted by UiButtons (shared look).
##
## Story 019 (roguelike run): while the flow has an open card offer ([method GameFlow.get_pending_reward]
## non-empty or [method GameFlow.is_reward_blocking]) this view draws only the labels and takes no
## button taps — RewardView owns the screen. When the run ended ([method GameFlow.get_run_result]
## WON / LOST) the controller's WON / LOST panels are replaced by RUN THẮNG / RUN KẾT THÚC (character,
## chapter, floor · match, deck size, run time) with the one button "Về title" ->
## [method GameFlow.leave_run]. The BETWEEN panel and the floor WON / LOST panels remain only for
## floors outside a run (test floors, no GameFlow): a run floor never shows them, the flow advances
## itself after the offer. A small "Bộ: N lá" label (ScreenLayout.run_deck_label_rect) sits in the
## top margin right of the match label while a run is live. All strings are TEXT_* keys through tr().
##
## Story 020: the result panels add ONE small line listing the final deck ("Kiếm khí +2 · Hỏa trận
## · …": names from SkillConfig.resolved, the level suffix when the level is above 1), cut with an
## ellipsis to the panel's inner width (font.get_string_size).
##
## Story 031 (world map): in a run the match label leads with the run position "Tầng N/5 · <vùng> ·
## cột C/3" ("Ấn Đài" at the final match; [method _run_position_text]), then "<kind> · <opponent> ·
## <arena>"; the RUN THẮNG / RUN KẾT THÚC panels show the floor reached ("Tới tầng N/5" / "Tới Ấn
## Đài") and the region path ("Đường: Rừng Sương → Hầm Ngục → …", [method GameFlow.get_region_path])
## instead of the chapter. The floor-clear notice is shown by WorldMapView (the screen a region boss
## leads to), not here.
##
## Story 022 (chapter map): in a run the match label reads "Cột N · <kind> · <opponent> · <arena>"
## (the run's column and node kind, ChapterMapView.kind_name) instead of "<floor> · Trận a/b · …",
## and the RUN THẮNG / RUN KẾT THÚC panels show "Cột N · <kind>" (the node the run ended on: the
## chosen node, else the last cleared one). The intro band names the node kind ("HIỂM ĐỊA"; the
## boss node keeps "TRẬN BOSS") since a node is a one-match config. Floors outside a run keep the
## Story 015 labels.

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
## Story 023: the match description line of the intro band (between the name and the hint).
const BAND_DESC_FONT_SIZE: int = 20
## Smallest font a long line (match description, chapter end text) shrinks to before clipping.
const MIN_FIT_FONT_SIZE: int = 14
const TITLE_FONT_SIZE: int = 56
const LINE_FONT_SIZE: int = 30
const SMALL_FONT_SIZE: int = 22
const BUTTON_FONT_SIZE: int = 40
const BUTTON_PAIR_FONT_SIZE: int = 32

## Intro band text baselines as shares of the band height.
const BAND_TITLE_BASELINE: float = 0.38
const BAND_NAME_BASELINE: float = 0.64
const BAND_DESC_BASELINE: float = 0.78
const BAND_HINT_BASELINE: float = 0.91
## Panel text baselines as shares of the panel height (the buttons sit below them).
const PANEL_TITLE_BASELINE: float = 0.16
const PANEL_LINE1_BASELINE: float = 0.29
const PANEL_LINE2_BASELINE: float = 0.40
const PANEL_LINE3_BASELINE: float = 0.51
const PANEL_NOTE_BASELINE: float = 0.60
## Story 019 / 020 result panels: up to six lines under the title, above the button (0.75); the
## fifth slot is the small deck line.
const RESULT_LINE_BASELINES: Array[float] = [0.27, 0.35, 0.43, 0.51, 0.585, 0.66]
## Story 020: separator between deck entries, the cut mark, and the gap before a level suffix.
const DECK_LINE_SEPARATOR: String = " · "
const DECK_LINE_ELLIPSIS: String = "…"
const LEVEL_SEPARATOR: String = " "

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
## Story 016 pause overlay; Story 019: the second button leaves the run (it stays saved).
const TEXT_PAUSE_TITLE: String = "ui.run_hud.pause_title"
const TEXT_RESUME: String = "ui.run_hud.resume"
const TEXT_LEAVE_RUN: String = "ui.run_hud.leave_run"
## Story 019: "Bộ: %d lá" in the top margin while a run is live.
const TEXT_DECK_LABEL: String = "ui.run_hud.deck_label"
## Story 019 result screens.
const TEXT_RUN_OVER_TITLE: String = "ui.run_hud.run_over_title"
## Story 035: "Gục ở tầng %d · %s" (floor, region) and "Kẻ hạ bạn: %s" (boss) on the defeat panel.
const TEXT_FELL_AT: String = "ui.run_hud.fell_at"
const TEXT_KILLED_BY: String = "ui.run_hud.killed_by"
## Story 035: baselines of the defeat panel's title and two death lines, as shares of the screen height.
const DEFEAT_TITLE_BASELINE_RATIO: float = 0.1
const DEFEAT_LINE1_BASELINE_RATIO: float = 0.16
const DEFEAT_LINE2_BASELINE_RATIO: float = 0.215
const TEXT_RUN_WON_TITLE: String = "ui.run_hud.run_won_title"
## Legacy "Tầng %d · Trận %d" of a floor run (kept for the CSV; unused since Story 022).
const TEXT_RUN_POSITION: String = "ui.run_hud.run_position"
## Story 022: "Cột %d · %s" (1-based column, node kind name) in the match label and on the result panels.
const TEXT_NODE_LABEL: String = "ui.run_hud.node_label"
const TEXT_RUN_NODE: String = "ui.run_hud.run_node"
## "Bộ: %d lá" on the result panel.
const TEXT_RUN_DECK: String = "ui.run_hud.run_deck"
const TEXT_BACK_TO_TITLE: String = "ui.run_hud.back_to_title"
## Story 031: "Tầng %d/%d · %s · cột %d/%d" (floor, floor count, region, column, column count) at
## the head of the match label; "Ấn Đài" at the final match; on the result panels "Tới tầng %d/%d" /
## "Tới Ấn Đài" and "Đường: %s" (the region names joined by PATH_SEPARATOR).
const TEXT_RUN_FLOOR_POSITION: String = "ui.run_hud.run_floor_position"
## Story 038: "Kiếp %d" shown before the floor line while the run's Kiep level is above 0.
const TEXT_RUN_KIEP: String = "ui.run.kiep"
const TEXT_FINAL_NAME: String = "ui.world.final_name"
const TEXT_RUN_FLOOR_REACHED: String = "ui.run_hud.run_floor_reached"
const TEXT_RUN_FINAL_REACHED: String = "ui.run_hud.run_final_reached"
const TEXT_RUN_PATH: String = "ui.run_hud.run_path"
const PATH_SEPARATOR: String = " → "
## Story 020: "+%d" after a card name on the result panels' deck line.
const TEXT_LEVEL_SUFFIX: String = "ui.card.level_suffix"

## Path to the GameFlow (a sibling under Main) that owns the controller.
@export var flow_path: NodePath = NodePath("../GameFlow")
## Fallback: a fixed RunController (scratch tests without a GameFlow).
@export var controller_path: NodePath = NodePath("../RunController")

var _flow: GameFlow = null
var _controller: RunController = null


## Story 032: owned-relic strip under the pause panel (tap an icon for its card).
var _strip: RelicStrip = null


func _ready() -> void:
	_strip = RelicStrip.new()
	add_child(_strip)
	_flow = get_node_or_null(flow_path) as GameFlow
	if _flow != null:
		_flow.controller_changed.connect(_on_controller_changed)
		_controller = _flow.get_controller()
	else:
		_controller = get_node_or_null(controller_path) as RunController


func _process(_delta: float) -> void:
	_sync_strip()
	queue_redraw()


func _on_controller_changed(controller: RunController) -> void:
	_controller = controller


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _has_controller() or _reward_open():
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
	if _controller.get_state().get_phase() == RunState.Phase.PLAYING and not _run_ended():
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
	if event.device != InputEvent.DEVICE_ID_EMULATION and _strip.visible and _strip.handle_input(event):
		return
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


# Story 019: true while RewardView owns the screen (an offer is open or a resumed one is held).
func _reward_open() -> bool:
	return _flow != null and (_flow.is_reward_blocking() or not _flow.get_pending_reward().is_empty())


# Story 019: true once the live run ended (WON / LOST); the result panel replaces the floor panels.
func _run_ended() -> bool:
	return _flow != null and _flow.get_run_result() != GameFlow.RunResult.NONE


# Label KEYS of the buttons of the current phase, left to right (translated when drawn); empty when
# the phase has none. Story 016: while paused, the overlay's buttons (only "Tiếp tục" without a
# GameFlow). Story 019: a finished run has the one "Về title" button whatever the controller phase.
func _button_labels() -> Array[String]:
	if _fate_or_ending():
		return []  # Story 035: FateView / EndingView own the screen (no stray RESTART on Enter)
	if _controller.is_paused():
		if _flow == null:
			return [TEXT_RESUME]
		return [TEXT_RESUME, TEXT_LEAVE_RUN]
	if _run_ended():
		return [TEXT_BACK_TO_TITLE]
	match _controller.get_state().get_phase():
		RunState.Phase.BETWEEN:
			return [TEXT_CONTINUE]
		RunState.Phase.WON, RunState.Phase.LOST:
			return [TEXT_RESTART]
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
		TEXT_BACK_TO_TITLE:
			_flow.leave_run()


# True when the node just won is on the last column of the run's map (the boss column): "CHƯƠNG XONG".
# Story 026: the legacy floor API is gone, the map column decides.
func _is_chapter_clear() -> bool:
	if _flow == null or _flow.get_run() == null:
		return false
	var run: RunSession = _flow.get_run()
	return not run.map.is_empty() and run.column >= run.map.size() - 1


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _has_controller():
		return
	if _fate_or_ending():
		return
	var vp: Vector2 = get_viewport_rect().size
	if _run_ended():
		_draw_run_result(vp)
		return
	var state: RunState = _controller.get_state()
	if _reward_open():
		_draw_match_label(vp)
		_draw_deck_label(vp)
		return
	match state.get_phase():
		RunState.Phase.INTRO:
			_draw_match_label(vp)
			_draw_deck_label(vp)
			_draw_intro(vp)
		RunState.Phase.PLAYING:
			_draw_match_label(vp)
			_draw_deck_label(vp)
			_draw_pause_button(vp)
			if _controller.is_paused():
				_draw_paused(vp)
		RunState.Phase.BETWEEN:
			_draw_match_label(vp)
			_draw_deck_label(vp)
			_draw_between(vp)
		RunState.Phase.WON:
			_draw_won(vp)
		RunState.Phase.LOST:
			_draw_lost(vp)


# Centred single-line text at baseline [param y] over the width of [param rect].
# Largest font size <= [param size] (never below MIN_FIT_FONT_SIZE) at which [param text] fits [param width].
func _fit_line_font(text: String, width: float, size: int) -> int:
	var font: Font = ThemeDB.fallback_font
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted).x > width:
		fitted -= 1
	return fitted


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
	var run: RunSession = _flow.get_run() if _flow != null else null
	var text: String
	if run != null and not run.map.is_empty():
		# Story 022: "Cột N · <kind> · <opponent>".
		# Story 031: "Tầng N/5 · <vùng> · cột C/3 · <kind> · <opponent>".
		var node: Array = _run_node_position(run)
		var place: String = tr(TEXT_MATCH_LABEL_FLOOR) % [_run_position_text(run, int(node[0])), ChapterMapView.kind_name(str(node[1]))]
		text = tr(TEXT_MATCH_LABEL_FLOOR) % [place, opponent]
	else:
		text = tr(TEXT_MATCH_LABEL_BOSS) % opponent if state.is_boss_match() else tr(TEXT_MATCH_LABEL) % [state.get_match_index() + 1, state.get_match_count(), opponent]
		if not _controller.floor_label.is_empty():
			text = tr(TEXT_MATCH_LABEL_FLOOR) % [_controller.floor_label, text]
	var arena: String = _arena_name()
	if not arena.is_empty():
		text = tr(TEXT_MATCH_LABEL_ARENA) % [text, arena]
	var rect: Rect2 = ScreenLayout.run_match_label_rect(vp)
	_text(rect, rect.get_center().y + LABEL_FONT_SIZE * 0.35, text, LABEL_FONT_SIZE, LABEL_COLOR)


# Story 019: "Bộ: N lá", right-aligned in the top margin; nothing outside a run.
func _draw_deck_label(vp: Vector2) -> void:
	if _flow == null or _flow.get_run() == null:
		return
	var rect: Rect2 = ScreenLayout.run_deck_label_rect(vp)
	var text: String = tr(TEXT_DECK_LABEL) % _flow.get_run().deck_ids.size()
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.get_center().y + LABEL_FONT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, LABEL_FONT_SIZE, LABEL_COLOR)


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
	var boss: bool = state.is_boss_match()
	var title: String = tr(TEXT_INTRO_TITLE_BOSS) if boss else tr(TEXT_INTRO_TITLE) % [state.get_match_index() + 1, state.get_match_count()]
	var run: RunSession = _flow.get_run() if _flow != null else null
	if run != null and not run.map.is_empty():
		# Story 022: a node is one match (every match is the config's "boss" match), so the band names
		# the node kind instead; only the boss node keeps TRẬN BOSS, boss and miniboss draw gold.
		var kind: String = str(_run_node_position(run)[1])
		boss = kind == ChapterMapView.KIND_BOSS or kind == ChapterMapView.KIND_MINIBOSS
		title = tr(TEXT_INTRO_TITLE_BOSS) if kind == ChapterMapView.KIND_BOSS else ChapterMapView.kind_name(kind).to_upper()
	_text(band, band.position.y + band.size.y * BAND_TITLE_BASELINE, title, BAND_TITLE_FONT_SIZE, TEXT_BOSS if boss else TEXT_WHITE)
	_text(band, band.position.y + band.size.y * BAND_NAME_BASELINE, _match_name(state.get_match_index()), BAND_NAME_FONT_SIZE, TEXT_LIGHT)
	# Story 023: the match's one-line description (desc_key) under the name, shrunk to the band width.
	var desc_key: String = str(_controller.get_config().matches[state.get_match_index()].get("desc_key", ""))
	if not desc_key.is_empty():
		var desc: String = tr(desc_key)
		var desc_width: float = band.size.x - vp.x * ScreenLayout.MARGIN_RATIO * 2.0
		_text(band, band.position.y + band.size.y * BAND_DESC_BASELINE, desc, _fit_line_font(desc, desc_width, BAND_DESC_FONT_SIZE), TEXT_DIM)
	_text(band, band.position.y + band.size.y * BAND_HINT_BASELINE, tr(TEXT_INTRO_HINT), BAND_HINT_FONT_SIZE, TEXT_DIM)


# Between-matches panel of a floor outside a run (a run floor shows the reward screen instead).
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


# Floor-clear screen of a floor outside a run (Story 015 look): "TẦNG XONG" + floor name, or
# "CHƯƠNG XONG" + chapter name on the chapter's last floor. Without a GameFlow: the Story 011 win screen.
func _draw_won(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var panel: Rect2 = _draw_panel(vp)
	var title: String = tr(TEXT_WIN_TITLE)
	var line: String = tr(TEXT_WIN_LINE) % _match_name(_boss_index())
	if _flow != null and _flow.get_current_floor() != GameFlow.NO_FLOOR:
		var pos: Vector2i = _flow.get_current_floor()
		if _is_chapter_clear():
			title = tr(TEXT_CHAPTER_CLEAR_TITLE)
			line = _flow.get_config().chapter_name(pos.x)
		else:
			title = tr(TEXT_FLOOR_CLEAR_TITLE)
			line = _flow.get_config().chapter_name(pos.x)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, title, TITLE_FONT_SIZE, TEXT_WIN)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, line, LINE_FONT_SIZE, TEXT_BOSS)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE2_BASELINE, tr(TEXT_TIME) % state.get_elapsed_text(), LINE_FONT_SIZE, TEXT_WHITE)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE3_BASELINE, tr(TEXT_CLEARED) % [state.get_match_count(), state.get_match_count()], LINE_FONT_SIZE, TEXT_LIGHT)
	_draw_buttons(vp)


# Lose screen of a floor outside a run (a run shows RUN KẾT THÚC instead).
func _draw_lost(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var panel: Rect2 = _draw_panel(vp)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, tr(TEXT_LOSE_TITLE), TITLE_FONT_SIZE, TEXT_LOSE)
	var line: String = tr(TEXT_LOSE_LINE) % [state.get_match_index() + 1, state.get_match_count(), _match_name(state.get_match_index())]
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, line, LINE_FONT_SIZE, TEXT_LIGHT)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE2_BASELINE, tr(TEXT_TIME) % state.get_elapsed_text(), LINE_FONT_SIZE, TEXT_WHITE)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE3_BASELINE, tr(TEXT_CLEARED) % [state.get_match_index(), state.get_match_count()], LINE_FONT_SIZE, TEXT_LIGHT)
	_draw_buttons(vp)


# Story 019: RUN KẾT THÚC (character, chapter, floor · match, deck size, deck line, time) or RUN
# THẮNG (chapter, deck size, deck line, time), with the one "Về title" button. Story 020: the deck
# line (small font) lists the final deck in one line, cut to the panel's inner width.
func _draw_run_result(vp: Vector2) -> void:
	var run: RunSession = _flow.get_run()
	var won: bool = _flow.get_run_result() == GameFlow.RunResult.WON
	if not won and run != null:
		_draw_defeat(vp)
		return
	var panel: Rect2 = _draw_panel(vp)
	var inner_width: float = panel.size.x - vp.y * ScreenLayout.RUN_PANEL_INSET_RATIO * 2.0
	var lines: Array[String] = []
	var colors: Array[Color] = []
	var sizes: Array[int] = []
	if run != null:
		# Story 031: the floor reached and the region path replace the chapter name.
		var reached: String = _floor_reached_text()
		var path_line: String = _region_path_text()
		var deck_line: String = _deck_line(run, inner_width, SMALL_FONT_SIZE)
		var node: Array = _run_node_position(run)
		var node_line: String = tr(TEXT_RUN_NODE) % [node[0], ChapterMapView.kind_name(str(node[1]))]
		var deck_size: String = tr(TEXT_RUN_DECK) % run.deck_ids.size()
		if won:
			lines = [reached, path_line, deck_size, deck_line, tr(TEXT_TIME) % _elapsed_text(run.elapsed_sec)]
			colors = [TEXT_BOSS, TEXT_LIGHT, TEXT_LIGHT, TEXT_DIM, TEXT_WHITE]
			sizes = [LINE_FONT_SIZE, LINE_FONT_SIZE, LINE_FONT_SIZE, SMALL_FONT_SIZE, LINE_FONT_SIZE]
		else:
			var character: Dictionary = _flow.get_characters().get_character(run.character_id)
			lines = [
				tr(str(character.get("name_key", run.character_id))) + DECK_LINE_SEPARATOR + reached,
				path_line, node_line + DECK_LINE_SEPARATOR + deck_size, deck_line, tr(TEXT_TIME) % _elapsed_text(run.elapsed_sec),
			]
			colors = [TEXT_BOSS, TEXT_LIGHT, TEXT_LIGHT, TEXT_DIM, TEXT_WHITE]
			sizes = [LINE_FONT_SIZE, LINE_FONT_SIZE, LINE_FONT_SIZE, SMALL_FONT_SIZE, LINE_FONT_SIZE]
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, tr(TEXT_RUN_WON_TITLE if won else TEXT_RUN_OVER_TITLE), TITLE_FONT_SIZE, TEXT_WIN if won else TEXT_LOSE)
	for i: int in mini(lines.size(), RESULT_LINE_BASELINES.size()):
		_text(panel, panel.position.y + panel.size.y * RESULT_LINE_BASELINES[i], lines[i], _fit_line_font(lines[i], inner_width, sizes[i]), colors[i])
	_draw_buttons(vp)


# Story 031: "Tầng N/5 · <vùng> · cột C/3" for 1-based column [param column], or "Ấn Đài" at the
# final match.
func _run_position_text(run: RunSession, column: int) -> String:
	return _kiep_prefix() + _floor_position_text(run, column)


# Story 038: "Kiếp k · " while the run's Kiep level k is above 0, else "".
func _kiep_prefix() -> String:
	var level: int = _flow.get_run_kiep_level()
	return (tr(TEXT_RUN_KIEP) % level + DECK_LINE_SEPARATOR) if level > 0 else ""


func _floor_position_text(run: RunSession, column: int) -> String:
	var count: int = _flow.get_floor_count()
	if _flow.is_final_floor() or _flow.get_floor() >= count:
		return tr(TEXT_FINAL_NAME)
	var region: String = _flow.region_name(_flow.get_current_region())
	return tr(TEXT_RUN_FLOOR_POSITION) % [_flow.get_floor() + 1, count, region, column, run.map.size()]


# Story 035: true while GameFlow is in phase FATE or ENDING (FateView / EndingView draw and take input).
func _fate_or_ending() -> bool:
	if _flow == null:
		return false
	var phase: int = _flow.get_phase()
	return phase == GameFlow.Phase.FATE or phase == GameFlow.Phase.ENDING


# Story 035 D: RUN KẾT THÚC on a wide panel — the title, "Gục ở tầng N · <vùng>", "Kẻ hạ bạn: <boss>",
# then the run stats block (EndingView helpers, two columns at SMALL_FONT_SIZE) from
# [method GameFlow.get_defeat_summary]; the run buttons stay where they were (run_button_rects).
func _draw_defeat(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	var panel: Rect2 = ScreenLayout.defeat_panel_rect(vp)
	draw_rect(panel, PANEL_BACK)
	draw_rect(panel, PANEL_OUTLINE, false, OUTLINE_WIDTH)
	var summary: Dictionary = _flow.get_defeat_summary()
	var death: Dictionary = summary.get("death", {})
	var inner_width: float = panel.size.x - vp.y * ScreenLayout.RUN_PANEL_INSET_RATIO * 2.0
	_text(panel, vp.y * DEFEAT_TITLE_BASELINE_RATIO, tr(TEXT_RUN_OVER_TITLE), TITLE_FONT_SIZE, TEXT_LOSE)
	var region_id: String = str(death.get("region_id", summary.get("region_id", _flow.get_current_region())))
	var floor_number: int = int(summary.get("floor_reached", _flow.get_floor() + 1))
	var fell: String = EndingView.format_text(tr(TEXT_FELL_AT), [floor_number, _flow.region_name(region_id)])
	_text(panel, vp.y * DEFEAT_LINE1_BASELINE_RATIO, fell, _fit_line_font(fell, inner_width, LINE_FONT_SIZE), TEXT_LIGHT)
	var killer_key: String = str(death.get("boss_name_key", summary.get("boss_name_key", "")))
	if not killer_key.is_empty():
		var killer: String = EndingView.format_text(tr(TEXT_KILLED_BY), [tr(killer_key)])
		_text(panel, vp.y * DEFEAT_LINE2_BASELINE_RATIO, killer, _fit_line_font(killer, inner_width, LINE_FONT_SIZE), TEXT_BOSS)
	var block: Rect2 = ScreenLayout.defeat_stats_rect(vp)
	EndingView.draw_stats(self, block, EndingView.path_text(self, summary, _flow), EndingView.stat_rows(self, summary, _flow), 0, SMALL_FONT_SIZE)
	_draw_buttons(vp)


# Story 031: "Tới tầng N/5" (the floor the run ended on), or "Tới Ấn Đài" at the final match.
func _floor_reached_text() -> String:
	var count: int = _flow.get_floor_count()
	if _flow.is_final_floor() or _flow.get_floor() >= count:
		return tr(TEXT_RUN_FINAL_REACHED)
	return tr(TEXT_RUN_FLOOR_REACHED) % [_flow.get_floor() + 1, count]


# Story 031: "Đường: Rừng Sương → Hầm Ngục → …" — the regions chosen, floor by floor.
func _region_path_text() -> String:
	var names: Array[String] = []
	for id: String in _flow.get_region_path():
		names.append(_flow.region_name(id))
	return tr(TEXT_RUN_PATH) % PATH_SEPARATOR.join(names)


# Story 022: [1-based column, kind] of the run's node — the chosen node of the current column, else
# the last cleared node (the run already advanced after a win), else the current column and "".
func _run_node_position(run: RunSession) -> Array:
	var node: Dictionary = run.current_node()
	if not node.is_empty():
		return [run.column + 1, str(node.get("kind", ""))]
	if not run.cleared_nodes.is_empty():
		var last: Dictionary = run.cleared_nodes[run.cleared_nodes.size() - 1]
		return [int(last.get("column", 0)) + 1, str(last.get("kind", ""))]
	return [run.column + 1, ""]


# Story 020: the run's deck as one line ("Kiếm khí +2 · Hỏa trận · …", deck order, level suffix
# above level 1). Entries are dropped from the end and replaced by an ellipsis until the line fits
# [param max_width] at [param font_size]; "" for an empty deck.
func _deck_line(run: RunSession, max_width: float, font_size: int) -> String:
	var cards: SkillConfig = _flow.get_cards()
	var parts: Array[String] = []
	for entry: Dictionary in run.deck_entries():
		var id: String = str(entry.get("id", ""))
		var level: int = int(entry.get("level", 1))
		var name: String = tr(str(cards.resolved(id, level).get("name_key", id)))
		if level > 1:
			name += LEVEL_SEPARATOR + tr(TEXT_LEVEL_SUFFIX) % level
		parts.append(name)
	var font: Font = ThemeDB.fallback_font
	var line: String = DECK_LINE_SEPARATOR.join(parts)
	while parts.size() > 1 and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width:
		parts.pop_back()
		line = DECK_LINE_SEPARATOR.join(parts) + DECK_LINE_SEPARATOR + DECK_LINE_ELLIPSIS
	return line


# Run clock as m:ss (seconds floored), like RunState.get_elapsed_text.
func _elapsed_text(seconds: float) -> String:
	var total: int = floori(maxf(seconds, 0.0))
	var minutes: int = floori(total / 60.0)
	return "%d:%02d" % [minutes, total - minutes * 60]


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
# others SECONDARY — NEUTRAL on the pause overlay, where the second one leaves the run).
func _draw_buttons(vp: Vector2) -> void:
	var labels: Array[String] = _button_labels()
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(vp, labels.size())
	var font_size: int = BUTTON_FONT_SIZE if labels.size() == 1 else BUTTON_PAIR_FONT_SIZE
	var alt_style: int = UiButtons.Style.NEUTRAL if _controller.is_paused() else UiButtons.Style.SECONDARY
	for i: int in rects.size():
		var style: int = UiButtons.Style.PRIMARY if i == 0 else alt_style
		UiButtons.draw_button(self, rects[i], tr(labels[i]), style, UiButtons.is_pressed_at(self, rects[i]), true, font_size)


# Story 032: the relic strip shows while this screen is up (nothing covering it); its card closes otherwise.
func _sync_strip() -> void:
	var shown: bool = _has_controller() and _controller.is_paused() and get_node_or_null(^"../GameFlow") is GameFlow
	if not shown:
		_strip.close_tooltip()
	_strip.visible = shown
	if shown:
		_strip.area = ScreenLayout.relic_strip_rect(get_viewport_rect().size)
		_strip.set_relics((get_node_or_null(^"../GameFlow") as GameFlow).get_relics())

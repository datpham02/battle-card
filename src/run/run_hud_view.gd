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
## itself after the offer. All strings are TEXT_* keys through tr().
## Controls v3 (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md): no deck label in battle; the pause tile sits
## in the top-right corner with the gold (an angular glyph) left of it; the "Floor 1/5 · ..." title line is a
## debug-build aid; the intro band shows the arena name and the featured (resonance) shape once.
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

## 2026-10-31 (user: "chưa apply hud cho toàn bộ màn"): the intro / between bands, the pause panel and the run
## result panels in the dark game skin (HudSkin): Night Stone chamfered panels (cut top-right and bottom-left) with
## a Mist line, outlined text (Bold titles), Ivory / gold text colours. Rects and hit areas are unchanged.
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const BAND_COLOR: Color = Color(HudSkin.NIGHT_STONE, 0.92)
const PANEL_BACK: Color = Color(HudSkin.NIGHT_STONE, 0.95)
const PANEL_OUTLINE: Color = HudSkin.MIST
## Chamfer of the bands and panels, px (top-right and bottom-left corners).
const PANEL_CUT: float = 12.0
const TEXT_LIGHT: Color = HudSkin.IVORY
const TEXT_WHITE: Color = HudSkin.TEXT
const TEXT_DIM: Color = HudSkin.TEXT_DIM
const TEXT_WIN: Color = Color(0.45, 0.9, 0.5)
const TEXT_LOSE: Color = Color(1.0, 0.4, 0.35)
const TEXT_BOSS: Color = HudSkin.GRID_LIGHT
const LABEL_COLOR: Color = Color(0.15, 0.12, 0.1)
const OUTLINE_WIDTH: float = 4.0
## Pause glyph ("||"): bar width, bar height and the gap between the bars, as shares of the
## button side; drawn in the menu ivory with a dark rim (dimmed with the button when pausing is not allowed).
const PAUSE_BAR_WIDTH_RATIO: float = 0.14
const PAUSE_BAR_HEIGHT_RATIO: float = 0.46
const PAUSE_BAR_GAP_RATIO: float = 0.14
## Pause tile pressed: how far it drops (px). Controls v3: its size and place are ScreenLayout.pause_tile_rect.
const PAUSE_PRESS_DROP: float = 2.0
## Battle HUD pass 2026-11-01: dark rim around each pause bar, px.
const PAUSE_BAR_RIM: float = 2.0

const LABEL_FONT_SIZE: int = 16
## 2026-10-31: the gold number in the top-right corner (720p px, scaled by height / 720). Controls v3: the angular
## gold glyph left of it (its width and the gap, 720p px) and its two golds.
const GOLD_FONT_SIZE: int = 20
const GOLD_GLYPH_PX: float = 20.0
const GOLD_GLYPH_GAP_PX: float = 6.0
const GOLD_FILL: Color = Color("E8A820")
const GOLD_FACET: Color = Color("FFE27A")
## Controls v3 intro band: the arena block at its right end (width, top padding), the featured shape icon's edge
## (720p px) and its gold, and the resonance word.
const INTRO_ARENA_WIDTH_PX: float = 280.0
const INTRO_ARENA_PAD_PX: float = 14.0
const INTRO_SHAPE_PX: float = 44.0
const INTRO_SHAPE_GOLD: Color = Color("FFD447")
const TEXT_INTRO_RESONANCE: String = "ui.run_hud.intro_resonance"
## Controls v3: the "Floor 1/5 · ..." title line is drawn only in debug builds; a capture may hide it with the user
## argument --no-dev-title (the release look).
static var show_dev_title: bool = OS.is_debug_build() and not OS.get_cmdline_user_args().has("--no-dev-title")
## Story 046: smallest size the match label shrinks to so it fits its rect.
const MATCH_LABEL_MIN_FONT_SIZE: int = 14
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
## Story 046 Part C: "<move name> · <N> cells" of the boss swing winding up, under the pause title (the board no
## longer shows the move name or the cell count); the cell count uses the HUD's "%d cells" key.
const TEXT_PAUSE_BOSS_SWING: String = "ui.run_hud.pause_boss_swing"
const TEXT_PAUSE_BOSS_CELLS: String = "ui.hud.cells"
const TEXT_RESUME: String = "ui.run_hud.resume"
const TEXT_LEAVE_RUN: String = "ui.run_hud.leave_run"
## Story 019: "Bộ: %d lá" in the top margin while a run is live.
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
	# 2026-11-01: crisp pixel frames (PixelFrame) and the menu font (MenuFont) on every menu screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var vp: Vector2 = get_viewport_rect().size
	var rects: Array[Rect2] = ScreenLayout.run_button_rects(vp, _button_labels().size())
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
		return
	match state.get_phase():
		RunState.Phase.INTRO:
			_draw_match_label(vp)
			_draw_intro(vp)
		RunState.Phase.PLAYING:
			_draw_match_label(vp)
			_draw_gold(vp)
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
# Largest font size <= [param size] (never below MIN_FIT_FONT_SIZE) at which [param text] fits [param width].
func _fit_line_font(text: String, width: float, size: int) -> int:
	var font: Font = HudSkin.font_semibold()
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted).x > width:
		fitted -= 1
	return fitted


# 2026-10-31: HudSkin outlined text (Bold when [param bold]: the band and panel titles).
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, bold: bool = false) -> void:
	MenuFont.text(self, Vector2(rect.position.x, y), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, bold)


# Translated opponent name of match [param index] (name_key, or a legacy literal display_name).
func _match_name(index: int) -> String:
	return RunConfig.match_name(_controller.get_config().matches[index])


func _boss_index() -> int:
	return _controller.get_state().get_match_count() - 1


func _draw_match_label(vp: Vector2) -> void:
	# Controls v3: the "Floor 1/5 · ..." title line is a development aid, drawn only in debug builds.
	if not show_dev_title:
		return
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
	# Story 046 Part B: HudSkin outlined text (TEXT, 16 px, down to 14 px to fit) so it reads over the backdrop.
	var rect: Rect2 = ScreenLayout.run_match_label_rect(vp)
	var size: int = LABEL_FONT_SIZE
	while size > MATCH_LABEL_MIN_FONT_SIZE and HudSkin.text_width(text, size) > rect.size.x:
		size -= 1
	MenuFont.text(self, Vector2(rect.position.x, rect.get_center().y + size * 0.35), text, size, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


# Controls v3: the run's gold in the top-right corner, left of the pause tile (ScreenLayout.hud_gold_rect): an
# angular gold glyph (a hexagon, no circles in the HUD) left of the number, right-aligned, HudSkin outlined text so it
# reads over the canopy. Nothing outside a run.
func _draw_gold(vp: Vector2) -> void:
	if _flow == null or _flow.get_run() == null:
		return
	var s: float = ScreenLayout.controls_scale(vp)
	var rect: Rect2 = ScreenLayout.hud_gold_rect(vp)
	var size: int = roundi(GOLD_FONT_SIZE * s)
	var text: String = str(_flow.get_gold())
	var width: float = HudSkin.text_width(text, size, true)
	var cy: float = roundf(rect.get_center().y)
	MenuFont.text(self, Vector2(rect.end.x - width, floorf(cy + size * 0.36)), text, size, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	var r: float = roundf(GOLD_GLYPH_PX * s * 0.5)
	draw_gold_glyph(self, Vector2(roundf(rect.end.x - width - roundf(GOLD_GLYPH_GAP_PX * s) - r), cy), r)


## Controls v3: the gold glyph, a flat-topped hexagon of circumradius [param r] at [param center] (gold fill, a lighter
## top facet, ink rim).
static func draw_gold_glyph(canvas: CanvasItem, center: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	var rim := PackedVector2Array(pts)
	rim.append(pts[0])
	canvas.draw_polyline(rim, HudSkin.TEXT_OUTLINE, 3.0)
	canvas.draw_colored_polygon(pts, GOLD_FILL)
	var inner := PackedVector2Array()
	for p: Vector2 in pts:
		inner.append(center + (p - center) * 0.5)
	canvas.draw_colored_polygon(inner, GOLD_FACET)


# Display name of the current battle's arena (+ variant marker); "" when the battle has none
# (combat.json board) or is not spawned yet.
func _arena_name() -> String:
	var view: CombatView = _battle_view()
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


# The running battle's CombatView, null when none is spawned.
func _battle_view() -> CombatView:
	var battle: Node = _controller.get_battle()
	if battle == null:
		return null
	return battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView


## Controls v3: the featured (resonance) shape of the running battle, {cells, bonus} as CombatView.get_featured(); {}
## when the battle has none.
func featured_shape() -> Dictionary:
	var view: CombatView = _battle_view()
	return {} if view == null else view.get_featured()


func _draw_intro(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var band: Rect2 = ScreenLayout.run_intro_band_rect(vp)
	HudSkin.panel(self, band, [0.0, PANEL_CUT, 0.0, PANEL_CUT], BAND_COLOR, PANEL_OUTLINE)
	var boss: bool = state.is_boss_match()
	var title: String = tr(TEXT_INTRO_TITLE_BOSS) if boss else tr(TEXT_INTRO_TITLE) % [state.get_match_index() + 1, state.get_match_count()]
	var run: RunSession = _flow.get_run() if _flow != null else null
	if run != null and not run.map.is_empty():
		# Story 022: a node is one match (every match is the config's "boss" match), so the band names
		# the node kind instead; only the boss node keeps TRẬN BOSS, boss and miniboss draw gold.
		var kind: String = str(_run_node_position(run)[1])
		boss = kind == ChapterMapView.KIND_BOSS or kind == ChapterMapView.KIND_MINIBOSS
		title = tr(TEXT_INTRO_TITLE_BOSS) if kind == ChapterMapView.KIND_BOSS else ChapterMapView.kind_name(kind).to_upper()
	_text(band, band.position.y + band.size.y * BAND_TITLE_BASELINE, title, BAND_TITLE_FONT_SIZE, TEXT_BOSS if boss else TEXT_WHITE, true)
	_text(band, band.position.y + band.size.y * BAND_NAME_BASELINE, _match_name(state.get_match_index()), BAND_NAME_FONT_SIZE, TEXT_LIGHT)
	# Controls v3: the arena name and the shape to join for resonance, once, at the band's right end.
	var block: Rect2 = intro_arena_rect(vp)
	var shown: bool = _draw_intro_arena(vp, block)
	# Story 023: the match's one-line description (desc_key) under the name, shrunk to the band width (and, with the
	# arena block shown, clear of it on both sides since the line is centred).
	var desc_key: String = str(_controller.get_config().matches[state.get_match_index()].get("desc_key", ""))
	if not desc_key.is_empty():
		var desc: String = tr(desc_key)
		var desc_width: float = band.size.x - vp.x * ScreenLayout.MARGIN_RATIO * 2.0
		if shown:
			desc_width = band.size.x - (band.end.x - block.position.x) * 2.0
		_text(band, band.position.y + band.size.y * BAND_DESC_BASELINE, desc, _fit_line_font(desc, desc_width, BAND_DESC_FONT_SIZE), TEXT_DIM)
	_text(band, band.position.y + band.size.y * BAND_HINT_BASELINE, tr(TEXT_INTRO_HINT), BAND_HINT_FONT_SIZE, TEXT_DIM)


## Controls v3: the intro band's arena block (right end of the band, INTRO_ARENA_WIDTH_PX wide at 720p, from the
## band's top padding down to just above the description line).
static func intro_arena_rect(vp: Vector2) -> Rect2:
	var s: float = ScreenLayout.controls_scale(vp)
	var band: Rect2 = ScreenLayout.run_intro_band_rect(vp)
	var w: float = roundf(INTRO_ARENA_WIDTH_PX * s)
	var margin: float = vp.x * ScreenLayout.MARGIN_RATIO
	var top: float = band.position.y + roundf(INTRO_ARENA_PAD_PX * s)
	var bottom: float = band.position.y + band.size.y * BAND_DESC_BASELINE - roundf(BAND_DESC_FONT_SIZE * s * 1.2)
	return Rect2(band.end.x - margin - w, top, w, maxf(bottom - top, 0.0))


# The arena name, and under it the featured shape as gold cells with "Cộng hưởng ×1,5" (the bonus multiplier) beside
# it, centred in [param block]. False (nothing drawn) when the battle has neither an arena name nor a featured shape.
func _draw_intro_arena(vp: Vector2, block: Rect2) -> bool:
	var arena: String = _arena_name()
	var featured: Dictionary = featured_shape()
	if arena.is_empty() and featured.is_empty():
		return false
	var s: float = ScreenLayout.controls_scale(vp)
	var name_size: int = _fit_line_font(arena, block.size.x, roundi(BAND_HINT_FONT_SIZE * s))
	var y: float = block.position.y + name_size
	if not arena.is_empty():
		MenuFont.text(self, Vector2(block.position.x, y), arena, name_size, TEXT_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, block.size.x)
	if featured.is_empty():
		return true
	var cells: Array[Vector2i] = featured["cells"]
	var box := Vector2i.ONE
	for cell: Vector2i in cells:
		box = Vector2i(maxi(box.x, cell.x + 1), maxi(box.y, cell.y + 1))
	var icon: float = roundf(INTRO_SHAPE_PX * s)
	var unit: float = floorf(icon / float(maxi(box.x, box.y)))
	var label: String = "%s ×%s" % [tr(TEXT_INTRO_RESONANCE), _mult_text(float((featured["bonus"] as Dictionary).get("damage_mult", 1.0)))]
	var label_size: int = roundi(BAND_HINT_FONT_SIZE * s)
	var gap: float = roundf(10.0 * s)
	var label_w: float = HudSkin.text_width(label, label_size, true)
	var shape_w: float = unit * box.x
	var left: float = roundf(block.get_center().x - (shape_w + gap + label_w) * 0.5)
	var top: float = roundf(y + roundf(10.0 * s))
	var shape_top: float = top + roundf((icon - unit * box.y) * 0.5)
	for cell: Vector2i in cells:
		var r := Rect2(Vector2(left, shape_top) + Vector2(cell) * unit, Vector2(unit, unit))
		draw_rect(r, HudSkin.TEXT_OUTLINE)
		draw_rect(r.grow(-maxf(roundf(2.0 * s), 1.0)), INTRO_SHAPE_GOLD)
	EffectText.draw(self, Vector2(left + shape_w + gap, roundf(top + icon * 0.5 + label_size * 0.36)), label, label_size, EffectText.GOOD,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, s)
	return true


# The multiplier with the locale's decimal mark ("1,5" in Vietnamese).
func _mult_text(mult: float) -> String:
	var text: String = ("%.2f" % mult).rstrip("0").rstrip(".")
	return text.replace(".", ",") if TranslationServer.get_locale().begins_with("vi") else text


# Between-matches panel of a floor outside a run (a run floor shows the reward screen instead).
func _draw_between(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var config: RunConfig = _controller.get_config()
	var panel: Rect2 = _draw_panel(vp)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, tr(TEXT_BETWEEN_TITLE), TITLE_FONT_SIZE, TEXT_WIN, true)
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
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, title, TITLE_FONT_SIZE, TEXT_WIN, true)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, line, LINE_FONT_SIZE, TEXT_BOSS)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE2_BASELINE, tr(TEXT_TIME) % state.get_elapsed_text(), LINE_FONT_SIZE, TEXT_WHITE)
	_text(panel, panel.position.y + panel.size.y * PANEL_LINE3_BASELINE, tr(TEXT_CLEARED) % [state.get_match_count(), state.get_match_count()], LINE_FONT_SIZE, TEXT_LIGHT)
	_draw_buttons(vp)


# Lose screen of a floor outside a run (a run shows RUN KẾT THÚC instead).
func _draw_lost(vp: Vector2) -> void:
	var state: RunState = _controller.get_state()
	var panel: Rect2 = _draw_panel(vp)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, tr(TEXT_LOSE_TITLE), TITLE_FONT_SIZE, TEXT_LOSE, true)
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
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, tr(TEXT_RUN_WON_TITLE if won else TEXT_RUN_OVER_TITLE), TITLE_FONT_SIZE, TEXT_WIN if won else TEXT_LOSE, true)
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
	HudSkin.panel(self, panel, [0.0, PANEL_CUT, 0.0, PANEL_CUT], PANEL_BACK, PANEL_OUTLINE, HudSkin.PANEL_LINE_WIDTH + 0.5)
	var summary: Dictionary = _flow.get_defeat_summary()
	var death: Dictionary = summary.get("death", {})
	var inner_width: float = panel.size.x - vp.y * ScreenLayout.RUN_PANEL_INSET_RATIO * 2.0
	_text(panel, vp.y * DEFEAT_TITLE_BASELINE_RATIO, tr(TEXT_RUN_OVER_TITLE), TITLE_FONT_SIZE, TEXT_LOSE, true)
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
	var font: Font = HudSkin.font_semibold()
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


# Story 016: the pause button, dimmed while the controller cannot pause (skill menu open, swing lockout, already
# paused). Controls v3: the stone tile sits against the top-right corner (ScreenLayout.pause_tile_rect) with the two
# bars drawn on it; the larger corner square ScreenLayout.pause_button_rect is the hit area; pressed = the tile drops
# PAUSE_PRESS_DROP px.
func _draw_pause_button(vp: Vector2) -> void:
	var tile: Rect2 = ScreenLayout.pause_tile_rect(vp)
	var enabled: bool = _controller.can_pause()
	var pressed: bool = enabled and UiButtons.is_pressed_at(self, ScreenLayout.pause_button_rect(vp))
	if pressed:
		tile.position.y += PAUSE_PRESS_DROP
	var side: float = tile.size.x
	var center: Vector2 = tile.get_center().floor()
	var alpha: float = 1.0 if enabled else UiButtons.DIM_ALPHA
	# Battle HUD pass 2026-11-01: the menus' pixel stone frame (PixelFrame, whole-number scale) instead of the vector tile.
	var tint: Color = UiButtons.PIXEL_DISABLED_TINT if not enabled else (UiButtons.PIXEL_PRESSED_TINT if pressed else Color.WHITE)
	PixelFrame.draw(self, PixelFrame.BUTTON_FRAME, tile, PixelFrame.BUTTON_MARGIN, PixelFrame.scale_for(vp.y), tint)
	# The icon sheet's "pause" carries its own vector tile, so on the stone frame the two bars are drawn here: menu
	# ivory with a dark rim, whole pixels.
	var bar := Vector2(roundf(side * PAUSE_BAR_WIDTH_RATIO), roundf(side * PAUSE_BAR_HEIGHT_RATIO))
	var gap: float = roundf(side * PAUSE_BAR_GAP_RATIO)
	var color := Color(UiButtons.PIXEL_LABEL, alpha)
	var rim := Color(HudSkin.TEXT_OUTLINE, alpha)
	for left: float in [center.x - gap * 0.5 - bar.x, center.x + gap * 0.5]:
		var r := Rect2(Vector2(roundf(left), roundf(center.y - bar.y * 0.5)), bar)
		draw_rect(r.grow(PAUSE_BAR_RIM), rim)
		draw_rect(r, color)


# Story 016: the pause overlay — dim, panel, "TẠM DỪNG" and the resume / leave buttons.
func _draw_paused(vp: Vector2) -> void:
	var panel: Rect2 = _draw_panel(vp)
	_text(panel, panel.position.y + panel.size.y * PANEL_TITLE_BASELINE, tr(TEXT_PAUSE_TITLE), TITLE_FONT_SIZE, TEXT_LIGHT, true)
	var swing: String = boss_swing_line()
	if not swing.is_empty():
		_text(panel, panel.position.y + panel.size.y * PANEL_LINE1_BASELINE, swing, _fit_line_font(swing, panel.size.x, SMALL_FONT_SIZE), TEXT_LIGHT)
	_draw_buttons(vp)


## Story 046 Part C: the pause panel's boss swing line, "<move name> · <N> cells" of the swing the boss is winding
## up (its queued combo swing only exists while that one runs); "" when no battle or no boss swing.
func boss_swing_line() -> String:
	if not _has_controller() or _controller.get_battle() == null:
		return ""
	var view := _controller.get_battle().get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
	if view == null or view.get_boss() == null or view.get_skill_config() == null:
		return ""
	var actor: CutActor = view.get_boss().get_actor()
	if not actor.is_swinging():
		return ""
	var id: String = actor.get_skill_id()
	var move: String = tr(str(view.get_skill_config().get_skill(id).get("name_key", id)))
	return tr(TEXT_PAUSE_BOSS_SWING) % [move, tr(TEXT_PAUSE_BOSS_CELLS) % actor.get_cells().size()]


# Dim overlay over the whole screen plus the centred panel; returns the panel rect.
func _draw_panel(vp: Vector2) -> Rect2:
	draw_rect(Rect2(Vector2.ZERO, vp), DIM_COLOR)
	var panel: Rect2 = ScreenLayout.run_panel_rect(vp)
	HudSkin.panel(self, panel, [0.0, PANEL_CUT, 0.0, PANEL_CUT], PANEL_BACK, PANEL_OUTLINE, HudSkin.PANEL_LINE_WIDTH + 0.5)
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

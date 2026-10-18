class_name CombatView
extends Node2D
## Draws the arena and owns the combat logic objects, ticking recovery and feedback from
## _process with one shared (capped) delta. Layout (landscape): a thin HUD band at the top
## of the arena (player HP/armor left, enemy HP right), then a 6x3 board below it: the
## player's half (cols 0-2) left of a divider, the boss's half (cols 3-5) right. Units are
## drawn centred in their cell, scaled from the cell size. The boss stands still (it does
## not attack yet). Step-target highlights, attack-shape preview, HIT/MISS feedback and the
## VICTORY/DEFEAT band are drawn over the board. Placeholder art.
## Implements: Story 003, Story 005, Story 006.

const ENEMY_COLOR: Color = Color(0.7, 0.3, 0.3)
const ENEMY_DEAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const BAR_BACK: Color = Color(0.2, 0.17, 0.15, 0.8)
const HP_COLOR: Color = Color(0.85, 0.2, 0.2)
const PLAYER_HP_COLOR: Color = Color(0.3, 0.75, 0.35)
const ARMOR_COLOR: Color = Color(0.3, 0.55, 0.95)
const TEXT_COLOR: Color = Color(0.15, 0.12, 0.1)
const DROP_COLOR: Color = Color(0.2, 0.8, 0.4)
const GRID_LINE_COLOR: Color = Color(0.15, 0.12, 0.1, 0.35)
const PLAYER_HALF_TINT: Color = Color(0.3, 0.55, 0.95, 0.12)
const ENEMY_HALF_TINT: Color = Color(0.85, 0.25, 0.25, 0.12)
const DIVIDER_COLOR: Color = Color(0.15, 0.12, 0.1, 0.9)
const PREVIEW_COLOR: Color = Color(0.95, 0.75, 0.1, 0.4)
const PREVIEW_HIT_COLOR: Color = Color(0.9, 0.1, 0.1, 0.5)
const PLAYER_COLOR: Color = Color(0.25, 0.6, 0.9)
const HIT_COLOR: Color = Color(0.9, 0.1, 0.1)
const MISS_COLOR: Color = Color(0.1, 0.5, 0.2)
const PAD: float = 10.0
const BAR_HEIGHT: float = 22.0
const FONT_SIZE: int = 24
const BIG_FONT_SIZE: int = 72
## In-cell elements scale from the cell size: player marker radius (of cell height),
## enemy body width / height (of cell width / height), feedback font (of cell height).
const MARKER_RADIUS_RATIO: float = 0.33
const ENEMY_BODY_WIDTH_RATIO: float = 0.6
const ENEMY_BODY_HEIGHT_RATIO: float = 0.8
const FEEDBACK_FONT_RATIO: float = 0.4
## Gap between the HUD's left and right halves as a share of arena width.
const HUD_GAP_RATIO: float = 0.04

@export_file("*.json") var config_path: String = CombatConfig.DEFAULT_PATH
## Slot row that shows the recovery lock (dimmed slots + bar).
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
## Dev/capture only: when true time does not advance (recovery, feedback), so
## screenshots are deterministic.
var freeze_recovery: bool = false

var _player: CardPlayer
var _step_targets: Array[Vector2i] = []
var _step_hover: Vector2i = CardPlayer.NO_CELL
var _preview_cells: Array[Vector2i] = []
var _preview_active: bool = false
var _feedback_left: float = 0.0
var _feedback_hit: bool = false
var _feedback_cells: Array[Vector2i] = []


func _ready() -> void:
	var config: CombatConfig = CombatConfig.load_from_file(config_path)
	if config == null:
		push_warning("CombatView: using built-in default config (no card effects)")
		config = CombatConfig.new()
	var state := CombatState.new(
		config.player_max_hp, config.enemy_max_hp, config.player_start_cell, config.enemy_start_cell
	)
	_player = CardPlayer.new(config, state, RecoveryLock.new())
	_player.attack_resolved.connect(_on_attack_resolved)


func _process(delta: float) -> void:
	if not freeze_recovery:
		# Cap the step so a frame hitch cannot skip a whole timing window.
		var step: float = minf(delta, _player.get_config().max_tick_sec)
		_player.get_lock().tick(step)
		_feedback_left = maxf(_feedback_left - step, 0.0)
	var lock: RecoveryLock = _player.get_lock()
	var slots_view := get_node_or_null(hold_slots_view_path) as HoldSlotsView
	if slots_view != null:
		slots_view.set_recovery(lock.get_ratio(), lock.get_remaining())
	queue_redraw()


func _on_attack_resolved(cells: Array[Vector2i], hit: bool) -> void:
	_feedback_left = _player.get_config().feedback_sec
	_feedback_hit = hit
	_feedback_cells = cells


func _draw() -> void:
	if _player == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var arena: Rect2 = ScreenLayout.arena_rect(vp)
	var state: CombatState = _player.get_state()
	_draw_board(vp)
	_draw_hud(vp, state)
	_draw_cell_set(vp, _step_targets, Color(DROP_COLOR, 0.25), DROP_COLOR)
	if _step_hover != CardPlayer.NO_CELL:
		var hover: Rect2 = ScreenLayout.cell_rect(vp, _step_hover)
		draw_rect(hover, Color(DROP_COLOR, 0.35))
		draw_rect(hover, DROP_COLOR, false, 6.0)
	_draw_enemy(vp, state)
	_draw_player_marker(vp, state)
	if _preview_active:
		var hits_boss: bool = _preview_cells.has(state.enemy_cell)
		_draw_cell_set(vp, _preview_cells, PREVIEW_COLOR, Color(PREVIEW_COLOR, 1.0))
		if hits_boss:
			var boss: Rect2 = ScreenLayout.cell_rect(vp, state.enemy_cell)
			draw_rect(boss, PREVIEW_HIT_COLOR)
			draw_rect(boss, HIT_COLOR, false, 5.0)
	_draw_feedback(vp, state)
	_draw_banner(arena, state)


## The card-playing logic (play through [method CardPlayer.play]).
func get_player() -> CardPlayer:
	return _player


## Board cell under the viewport point, or Vector2i(-1, -1) off the board.
func get_cell_at(point: Vector2) -> Vector2i:
	return ScreenLayout.cell_at(get_viewport_rect().size, point)


## Highlights the valid step destination [param cells] and the hovered one
## ([constant CardPlayer.NO_CELL] = none). Pass an empty array to clear.
func set_step_targets(cells: Array[Vector2i], hovered: Vector2i = CardPlayer.NO_CELL) -> void:
	_step_targets = cells
	_step_hover = hovered


## Shows the attack shape [param cells] tinted on the board (the boss cell tinted
## differently if inside).
func set_preview(cells: Array[Vector2i]) -> void:
	_preview_cells = cells
	_preview_active = true


## Hides the attack-shape preview.
func clear_preview() -> void:
	_preview_cells = []
	_preview_active = false


func _draw_cell_set(vp: Vector2, cells: Array[Vector2i], fill: Color, outline: Color) -> void:
	for cell: Vector2i in cells:
		var rect: Rect2 = ScreenLayout.cell_rect(vp, cell)
		draw_rect(rect, fill)
		draw_rect(rect.grow(-3.0), outline, false, 3.0)


func _draw_board(vp: Vector2) -> void:
	var board: Rect2 = ScreenLayout.board_rect(vp)
	var cell: Vector2 = ScreenLayout.cell_size(vp)
	var half_w: float = cell.x * ScreenLayout.PLAYER_COLS
	draw_rect(Rect2(board.position, Vector2(half_w, board.size.y)), PLAYER_HALF_TINT)
	draw_rect(Rect2(board.position + Vector2(half_w, 0.0), Vector2(board.size.x - half_w, board.size.y)), ENEMY_HALF_TINT)
	for col: int in ScreenLayout.BOARD_COLS + 1:
		var x: float = board.position.x + cell.x * col
		draw_line(Vector2(x, board.position.y), Vector2(x, board.end.y), GRID_LINE_COLOR, 2.0)
	for row: int in ScreenLayout.BOARD_ROWS + 1:
		var y: float = board.position.y + cell.y * row
		draw_line(Vector2(board.position.x, y), Vector2(board.end.x, y), GRID_LINE_COLOR, 2.0)
	var dx: float = ScreenLayout.divider_x(vp)
	draw_line(Vector2(dx, board.position.y - 6.0), Vector2(dx, board.end.y + 6.0), DIVIDER_COLOR, 6.0)


# Top band: player HP bar + armor on the left half, enemy HP bar on the right half.
func _draw_hud(vp: Vector2, state: CombatState) -> void:
	var hud: Rect2 = ScreenLayout.hud_rect(vp)
	var gap: float = hud.size.x * HUD_GAP_RATIO
	var half_w: float = (hud.size.x - gap) * 0.5 - PAD * 2.0
	var text_y: float = hud.position.y + PAD + FONT_SIZE
	var bar_y: float = text_y + 8.0
	var left_x: float = hud.position.x + PAD
	var right_x: float = hud.position.x + PAD + half_w + PAD * 2.0 + gap
	var hp_text: String = "YOU  HP %d/%d" % [ceili(state.player_hp), ceili(state.player_max_hp)]
	_draw_text(hp_text, Vector2(left_x, text_y), half_w, HORIZONTAL_ALIGNMENT_LEFT, TEXT_COLOR)
	var pbar := Rect2(Vector2(left_x, bar_y), Vector2(half_w, BAR_HEIGHT))
	_draw_bar(pbar, state.player_hp / state.player_max_hp, PLAYER_HP_COLOR)
	var armor_color: Color = TEXT_COLOR
	if state.player_armor > 0.0:
		armor_color = ARMOR_COLOR.darkened(0.3)
		var armor_ratio: float = minf(state.player_armor / state.player_max_hp, 1.0)
		draw_rect(Rect2(pbar.position + Vector2(0.0, BAR_HEIGHT + 3.0), Vector2(half_w * armor_ratio, 6.0)), ARMOR_COLOR)
	_draw_text("ARMOR %d" % ceili(state.player_armor), Vector2(left_x, text_y), half_w, HORIZONTAL_ALIGNMENT_RIGHT, armor_color)
	var dead: bool = state.is_enemy_dead()
	var enemy_text: String = "DUMMY  DEAD"
	if not dead:
		enemy_text = "DUMMY  HP %d/%d" % [ceili(state.enemy_hp), ceili(state.enemy_max_hp)]
	_draw_text(enemy_text, Vector2(right_x, text_y), half_w, HORIZONTAL_ALIGNMENT_RIGHT, TEXT_COLOR)
	_draw_bar(Rect2(Vector2(right_x, bar_y), Vector2(half_w, BAR_HEIGHT)), state.enemy_hp / state.enemy_max_hp, HP_COLOR)


func _draw_enemy(vp: Vector2, state: CombatState) -> void:
	var dead: bool = state.is_enemy_dead()
	var cell: Vector2 = ScreenLayout.cell_size(vp)
	var body_size := Vector2(cell.x * ENEMY_BODY_WIDTH_RATIO, cell.y * ENEMY_BODY_HEIGHT_RATIO)
	var body := Rect2(ScreenLayout.cell_center(vp, state.enemy_cell) - body_size * 0.5, body_size)
	draw_rect(body, ENEMY_DEAD_COLOR if dead else ENEMY_COLOR)
	draw_rect(body, TEXT_COLOR, false, 3.0)
	if dead:
		draw_line(body.position, body.end, TEXT_COLOR, 6.0)
		draw_line(Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), TEXT_COLOR, 6.0)


func _draw_player_marker(vp: Vector2, state: CombatState) -> void:
	var c: Vector2 = ScreenLayout.cell_center(vp, state.player_cell)
	var radius: float = _marker_radius(vp)
	var color: Color = ENEMY_DEAD_COLOR if state.is_player_dead() else PLAYER_COLOR
	draw_circle(c, radius, color)
	draw_arc(c, radius, 0.0, TAU, 32, TEXT_COLOR, 3.0)
	draw_string(ThemeDB.fallback_font, c + Vector2(-radius, 8.0), "YOU", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, FONT_SIZE - 6, Color.WHITE)


# Brief feedback after an attack: HIT tints the boss cell red with "HIT!"; MISS outlines
# the attacked cells green and writes "MISS" over the boss cell.
func _draw_feedback(vp: Vector2, state: CombatState) -> void:
	if _feedback_left <= 0.0:
		return
	var boss: Rect2 = ScreenLayout.cell_rect(vp, state.enemy_cell)
	if _feedback_hit:
		draw_rect(boss, Color(HIT_COLOR, 0.4))
		draw_rect(boss.grow(-2.0), HIT_COLOR, false, 6.0)
	else:
		for cell: Vector2i in _feedback_cells:
			draw_rect(ScreenLayout.cell_rect(vp, cell).grow(-3.0), MISS_COLOR, false, 4.0)
	var text: String = "HIT!" if _feedback_hit else "MISS"
	var color: Color = HIT_COLOR if _feedback_hit else MISS_COLOR
	var font_size: int = int(ScreenLayout.cell_size(vp).y * FEEDBACK_FONT_RATIO)
	draw_string(ThemeDB.fallback_font, boss.position + Vector2(0.0, boss.size.y * 0.5 + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, boss.size.x, font_size, color)


func _draw_banner(arena: Rect2, state: CombatState) -> void:
	var text: String = ""
	var color: Color = TEXT_COLOR
	if state.is_player_dead():
		text = "DEFEAT"
		color = HIT_COLOR
	elif state.is_enemy_dead():
		text = "VICTORY"
		color = MISS_COLOR
	if text == "":
		return
	var band := Rect2(arena.position.x, arena.get_center().y - 60.0, arena.size.x, 110.0)
	draw_rect(band, Color(1.0, 1.0, 1.0, 0.85))
	draw_string(ThemeDB.fallback_font, Vector2(band.position.x, band.position.y + 80.0), text, HORIZONTAL_ALIGNMENT_CENTER, band.size.x, BIG_FONT_SIZE, color)


func _marker_radius(vp: Vector2) -> float:
	return ScreenLayout.cell_size(vp).y * MARKER_RADIUS_RATIO


func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, BAR_BACK)
	var fill := Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)
	draw_rect(Rect2(rect.position, fill), color)
	draw_rect(rect, TEXT_COLOR, false, 2.0)


func _draw_text(text: String, pos: Vector2, width: float, align: HorizontalAlignment, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, align, width, FONT_SIZE, color)

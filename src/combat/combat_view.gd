class_name CombatView
extends Node2D
## Draws the arena and owns the combat logic objects (CombatState, the player's UnitMover,
## the player half's FieldDrops), ticking them from _process with one shared (capped) delta.
## Layout (landscape): a thin HUD band (player HP left, boss HP right), then the board (size
## and shape from CombatConfig.grid): player's half left of a divider, boss's half right.
## The boss stands still.
## A cooldown ring under the player's feet shows the step cooldown. Placeholder art.
## Stepping onto a cell with a field point picks it up into the hand (HoldSlots).
## Implements: Story 003, Story 005, Story 006, Story 007.

const ENEMY_COLOR: Color = Color(0.7, 0.3, 0.3)
const ENEMY_DEAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const BAR_BACK: Color = Color(0.2, 0.17, 0.15, 0.8)
const HP_COLOR: Color = Color(0.85, 0.2, 0.2)
const PLAYER_HP_COLOR: Color = Color(0.3, 0.75, 0.35)
const TEXT_COLOR: Color = Color(0.15, 0.12, 0.1)
const GRID_LINE_COLOR: Color = Color(0.15, 0.12, 0.1, 0.35)
const PLAYER_HALF_TINT: Color = Color(0.3, 0.55, 0.95, 0.12)
const ENEMY_HALF_TINT: Color = Color(0.85, 0.25, 0.25, 0.12)
const DIVIDER_COLOR: Color = Color(0.15, 0.12, 0.1, 0.9)
const PLAYER_COLOR: Color = Color(0.25, 0.6, 0.9)
const DEFEAT_COLOR: Color = Color(0.9, 0.1, 0.1)
const VICTORY_COLOR: Color = Color(0.1, 0.5, 0.2)
const RING_COLOR: Color = Color(0.95, 0.6, 0.1)
const RING_BACK_COLOR: Color = Color(0.15, 0.12, 0.1, 0.25)
const PAD: float = 10.0
const BAR_HEIGHT: float = 22.0
const FONT_SIZE: int = 24
const BIG_FONT_SIZE: int = 72
## In-cell elements scale from the cell size: player marker radius (of cell height),
## enemy body width / height (of cell width / height).
const MARKER_RADIUS_RATIO: float = 0.33
## Marker label font size as a share of the marker radius (so it shrinks with the grid).
const MARKER_FONT_RATIO: float = 0.6
const ENEMY_BODY_WIDTH_RATIO: float = 0.6
const ENEMY_BODY_HEIGHT_RATIO: float = 0.8
## Cooldown ring: gap outside the marker (of cell height), line width, arc point count.
const RING_GAP_RATIO: float = 0.06
const RING_WIDTH: float = 6.0
const RING_POINTS: int = 48
## Gap between the HUD's left and right halves as a share of arena width.
const HUD_GAP_RATIO: float = 0.04
## Seed for the field drops RNG; negative = random. Dev/capture only (DemoArgs sets it).
const RANDOM_SEED: int = -1

@export_file("*.json") var config_path: String = CombatConfig.DEFAULT_PATH
@export_file("*.json") var drops_config_path: String = FieldDropsConfig.DEFAULT_PATH
## The hand (its view owns the HoldSlots instance).
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
## Dev/capture only: when true time does not advance, so screenshots are deterministic.
var freeze_time: bool = false
## Dev/capture only: field drops RNG seed (negative = random). Set before _ready.
var drops_seed: int = RANDOM_SEED
## Dev/capture only: replaces the board from combat.json (DemoArgs --grid). Set before _ready.
var grid_override: BoardGrid = null

var _config: CombatConfig
var _grid: BoardGrid
var _state: CombatState
var _mover: UnitMover
var _drops: FieldDrops
var _drops_config: FieldDropsConfig
var _cut_config: CutConfig
var _skill_config: SkillConfig
var _cooldowns: SkillCooldowns
var _cut_actor: CutActor
var _cut_flow: CutFlow
## Last resolved player cut for the HIT/MISS marker: {cells, hit, damage, cell, time_left}; empty = none.
var _feedback: Dictionary = {}
var _hold_hooked: bool = false


func _ready() -> void:
	_config = CombatConfig.load_from_file(config_path)
	if _config == null:
		push_warning("CombatView: using built-in default config")
		_config = CombatConfig.new()
	if grid_override != null:
		_config.use_grid(grid_override)
	_grid = _config.grid
	_state = CombatState.new(
		_grid, _config.player_max_hp, _config.enemy_max_hp, _config.player_start_cell, _config.enemy_start_cell
	)
	_mover = UnitMover.new(_state, CombatState.Side.PLAYER, _config.player_step_cooldown_sec)
	_drops_config = FieldDropsConfig.load_from_file(drops_config_path)
	_drops = FieldDrops.new(_drops_config, _grid.player_cells(), _grid.perimeter_labels(), drops_seed)
	_state.cell_changed.connect(_on_cell_changed)
	_cut_config = CutConfig.load_from_file()
	_skill_config = SkillConfig.load_from_file()
	_cooldowns = SkillCooldowns.new()
	_cut_actor = CutActor.new(_cut_config, CombatState.Side.PLAYER)
	_cut_flow = CutFlow.new(_skill_config, _cooldowns)
	_cut_flow.skill_chosen.connect(_on_skill_chosen)
	_cut_actor.swing_resolved.connect(_on_swing_resolved)


func _process(delta: float) -> void:
	_hook_hold()
	if not freeze_time:
		# Cap the step so a frame hitch cannot skip a whole timing window.
		var real_step: float = minf(delta, _config.max_tick_sec)
		# The menu countdown runs on REAL time; it may close the menu this frame.
		_cut_flow.tick_real(real_step)
		# Simulation time is scaled down while the skill menu is open (slow motion).
		var step: float = real_step * (_skill_config.menu_time_scale if _cut_flow.is_menu_open() else 1.0)
		_mover.tick(step)
		var hold: HoldSlots = _get_hold()
		var held: int = 0 if hold == null else hold.get_occupied_count()
		_drops.tick(step, _state.player_cell, held)
		_cut_actor.tick(step)
		_cooldowns.tick(step)
		if not _feedback.is_empty():
			_feedback["time_left"] = float(_feedback["time_left"]) - step
			if float(_feedback["time_left"]) <= 0.0:
				_feedback = {}
	queue_redraw()


## How long the HIT/MISS marker stays on screen (UI timing, real-ish seconds of sim time).
const FEEDBACK_SEC: float = 0.8


## The player's cut swing (one at a time).
func get_cut_actor() -> CutActor:
	return _cut_actor


## The skill-menu flow (IDLE / MENU).
func get_cut_flow() -> CutFlow:
	return _cut_flow


## Skill definitions and menu timing.
func get_skill_config() -> SkillConfig:
	return _skill_config


## Cut numbers (damage per cell, swing timing).
func get_cut_config() -> CutConfig:
	return _cut_config


## The player's skill cooldowns.
func get_skill_cooldowns() -> SkillCooldowns:
	return _cooldowns


## The hand (null until the hold view is ready).
func get_hold() -> HoldSlots:
	return _get_hold()


## Last resolved player cut for the HIT/MISS marker ({cells, hit, damage, cell, time_left});
## empty when nothing is showing.
func get_cut_feedback() -> Dictionary:
	return _feedback


## Labels of the current selection that a cut would use: the first hand_max_points in
## selection order (extra selected points are left selected).
func get_cut_selection_labels() -> Array[String]:
	var labels: Array[String] = []
	var hold: HoldSlots = _get_hold()
	if hold == null:
		return labels
	for index: int in hold.get_selected_indices():
		if labels.size() >= _cut_config.hand_max_points:
			break
		labels.append(hold.get_point(index).label)
	return labels


## True when the CONFIRM button should be on screen: >= 1 point selected, no menu open and
## nobody dead. (While a swing runs it is shown dimmed and pressing it does nothing.)
func is_confirm_visible() -> bool:
	var hold: HoldSlots = _get_hold()
	if hold == null or _state == null or _cut_flow.is_menu_open():
		return false
	if _state.is_player_dead() or _state.is_enemy_dead():
		return false
	return not hold.get_selected_indices().is_empty()


## Confirms the current selection as a cut. Returns false (nothing changes) when blocked
## (menu open, own swing running, dead, nothing selected) or when every covered cell is
## missing. Otherwise the used points leave the hand NOW (more than hand_max_points selected:
## the first hand_max_points in selection order are used, the rest stay selected); one
## point with single_point_opens_menu == false swings slash at once, else the skill menu opens.
func confirm_selection() -> bool:
	var hold: HoldSlots = _get_hold()
	if hold == null or not is_confirm_visible() or _cut_actor.is_swinging():
		return false
	var labels: Array[String] = get_cut_selection_labels()
	var cells: Array[Vector2i] = CutResolver.resolve_on_board(_grid, true, labels)
	if cells.is_empty():
		return false
	var used: Array[int] = []
	for index: int in hold.get_selected_indices():
		if used.size() >= labels.size():
			break
		used.append(index)
	for index: int in used:
		hold.remove(index)
	if labels.size() == 1 and not _cut_config.single_point_opens_menu:
		_begin_cut(SkillConfig.FALLBACK_SKILL, cells)
	else:
		_cut_flow.open_menu(labels, cells)
	return true


# Hand slot cleared while the player stands on a field point: pick it up right away.
func _hook_hold() -> void:
	if _hold_hooked:
		return
	var hold: HoldSlots = _get_hold()
	if hold == null:
		return
	_hold_hooked = true
	hold.slot_cleared.connect(_on_slot_cleared)


func _on_slot_cleared(_index: int, _point: FieldPoint) -> void:
	var hold: HoldSlots = _get_hold()
	if hold == null or _state.is_player_dead():
		return
	var point: FieldPoint = _drops.pick_up_at(_state.player_cell, true)
	if point != null:
		hold.place_in_first_free(point)


func _on_skill_chosen(skill_id: String, _labels: Array[String], cells: Array[Vector2i]) -> void:
	_begin_cut(skill_id, cells)


func _begin_cut(skill_id: String, cells: Array[Vector2i]) -> void:
	if _cut_actor.begin_swing(cells, skill_id, true):
		_cooldowns.start(skill_id, float(_skill_config.get_skill(skill_id).get("cooldown_sec", 0.0)))


func _on_swing_resolved(cells: Array[Vector2i], skill_id: String) -> void:
	if _state.is_player_dead() or _state.is_enemy_dead():
		return
	var result: Dictionary = CutEffects.apply(
		_state, _grid, CombatState.Side.PLAYER, cells, skill_id, _cut_config, _skill_config
	)
	_feedback = {
		"cells": cells, "hit": bool(result["hit"]), "damage": float(result["damage"]),
		"cell": _state.enemy_cell, "time_left": FEEDBACK_SEC,
	}


## The board (size, shape, halves) every view of the arena shares.
func get_grid() -> BoardGrid:
	return _grid


## The combat numbers and unit cells.
func get_state() -> CombatState:
	return _state


## The player's step mover (cooldown).
func get_mover() -> UnitMover:
	return _mover


## Field points of the player's half.
func get_drops() -> FieldDrops:
	return _drops


## Drop tuning in use (freshness total etc.).
func get_drops_config() -> FieldDropsConfig:
	return _drops_config


## Tries one step of the player in [param direction] (Vector2i.UP/DOWN/LEFT/RIGHT).
## Returns false on cooldown, wall or when dead; nothing is queued.
func try_step_player(direction: Vector2i) -> bool:
	return _mover.try_step(direction)


func _get_hold() -> HoldSlots:
	var view := get_node_or_null(hold_slots_view_path) as HoldSlotsView
	return null if view == null else view.get_slots()


# Stepping onto a point picks it up into the first free hand slot.
func _on_cell_changed(side: int, _old_cell: Vector2i, new_cell: Vector2i) -> void:
	if side != CombatState.Side.PLAYER:
		return
	var hold: HoldSlots = _get_hold()
	if hold == null:
		return
	var point: FieldPoint = _drops.pick_up_at(new_cell, not hold.is_full())
	if point != null:
		hold.place_in_first_free(point)


func _draw() -> void:
	if _state == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	_draw_board(vp)
	_draw_hud(vp)
	_draw_enemy(vp)
	_draw_cooldown_ring(vp)
	_draw_player_marker(vp)
	_draw_banner(ScreenLayout.arena_rect(vp))


func _draw_board(vp: Vector2) -> void:
	var board: Rect2 = ScreenLayout.board_rect(_grid, vp)
	# Cell by cell; missing cells are simply not drawn (the board looks cut out there).
	for cell: Vector2i in _grid.player_cells():
		_draw_cell(ScreenLayout.cell_rect(_grid, vp, cell), PLAYER_HALF_TINT)
	for cell: Vector2i in _grid.enemy_cells():
		_draw_cell(ScreenLayout.cell_rect(_grid, vp, cell), ENEMY_HALF_TINT)
	var dx: float = ScreenLayout.divider_x(_grid, vp)
	draw_line(Vector2(dx, board.position.y - 6.0), Vector2(dx, board.end.y + 6.0), DIVIDER_COLOR, 6.0)


func _draw_cell(rect: Rect2, tint: Color) -> void:
	draw_rect(rect, tint)
	draw_rect(rect, GRID_LINE_COLOR, false, 2.0)


# Top band: player HP bar on the left half, boss HP bar on the right half.
func _draw_hud(vp: Vector2) -> void:
	var hud: Rect2 = ScreenLayout.hud_rect(vp)
	var gap: float = hud.size.x * HUD_GAP_RATIO
	var half_w: float = (hud.size.x - gap) * 0.5 - PAD * 2.0
	var text_y: float = hud.position.y + PAD + FONT_SIZE
	var bar_y: float = text_y + 8.0
	var left_x: float = hud.position.x + PAD
	var right_x: float = hud.position.x + PAD + half_w + PAD * 2.0 + gap
	var hp_text: String = "YOU  HP %d/%d" % [ceili(_state.player_hp), ceili(_state.player_max_hp)]
	_draw_text(hp_text, Vector2(left_x, text_y), half_w, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_bar(Rect2(Vector2(left_x, bar_y), Vector2(half_w, BAR_HEIGHT)), _state.player_hp / _state.player_max_hp, PLAYER_HP_COLOR)
	var enemy_text: String = "DUMMY  DEAD"
	if not _state.is_enemy_dead():
		enemy_text = "DUMMY  HP %d/%d" % [ceili(_state.enemy_hp), ceili(_state.enemy_max_hp)]
	_draw_text(enemy_text, Vector2(right_x, text_y), half_w, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_bar(Rect2(Vector2(right_x, bar_y), Vector2(half_w, BAR_HEIGHT)), _state.enemy_hp / _state.enemy_max_hp, HP_COLOR)


func _draw_enemy(vp: Vector2) -> void:
	var dead: bool = _state.is_enemy_dead()
	var cell: Vector2 = ScreenLayout.cell_size(_grid, vp)
	var body_size := Vector2(cell.x * ENEMY_BODY_WIDTH_RATIO, cell.y * ENEMY_BODY_HEIGHT_RATIO)
	var body := Rect2(ScreenLayout.cell_center(_grid, vp, _state.enemy_cell) - body_size * 0.5, body_size)
	draw_rect(body, ENEMY_DEAD_COLOR if dead else ENEMY_COLOR)
	draw_rect(body, TEXT_COLOR, false, 3.0)
	if dead:
		draw_line(body.position, body.end, TEXT_COLOR, 6.0)
		draw_line(Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), TEXT_COLOR, 6.0)


# Ring around the player's feet: full right after a step, shrinks to nothing; hidden when ready.
func _draw_cooldown_ring(vp: Vector2) -> void:
	var fraction: float = _mover.get_cooldown_fraction()
	if fraction <= 0.0:
		return
	var c: Vector2 = ScreenLayout.cell_center(_grid, vp, _state.player_cell)
	var radius: float = _marker_radius(vp) + ScreenLayout.cell_size(_grid, vp).y * RING_GAP_RATIO
	draw_arc(c, radius, 0.0, TAU, RING_POINTS, RING_BACK_COLOR, RING_WIDTH)
	draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, RING_POINTS, RING_COLOR, RING_WIDTH)


func _draw_player_marker(vp: Vector2) -> void:
	var c: Vector2 = ScreenLayout.cell_center(_grid, vp, _state.player_cell)
	var radius: float = _marker_radius(vp)
	var color: Color = ENEMY_DEAD_COLOR if _state.is_player_dead() else PLAYER_COLOR
	draw_circle(c, radius, color)
	draw_arc(c, radius, 0.0, TAU, 32, TEXT_COLOR, 3.0)
	var font_size: int = maxi(int(radius * MARKER_FONT_RATIO), 8)
	draw_string(ThemeDB.fallback_font, c + Vector2(-radius, font_size * 0.4), "YOU", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color.WHITE)


func _draw_banner(arena: Rect2) -> void:
	var text: String = ""
	var color: Color = TEXT_COLOR
	if _state.is_player_dead():
		text = "DEFEAT"
		color = DEFEAT_COLOR
	elif _state.is_enemy_dead():
		text = "VICTORY"
		color = VICTORY_COLOR
	if text == "":
		return
	var band := Rect2(arena.position.x, arena.get_center().y - 60.0, arena.size.x, 110.0)
	draw_rect(band, Color(1.0, 1.0, 1.0, 0.85))
	draw_string(ThemeDB.fallback_font, Vector2(band.position.x, band.position.y + 80.0), text, HORIZONTAL_ALIGNMENT_CENTER, band.size.x, BIG_FONT_SIZE, color)


func _marker_radius(vp: Vector2) -> float:
	return ScreenLayout.cell_size(_grid, vp).y * MARKER_RADIUS_RATIO


func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, BAR_BACK)
	var fill := Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)
	draw_rect(Rect2(rect.position, fill), color)
	draw_rect(rect, TEXT_COLOR, false, 2.0)


func _draw_text(text: String, pos: Vector2, width: float, align: HorizontalAlignment) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, align, width, FONT_SIZE, TEXT_COLOR)

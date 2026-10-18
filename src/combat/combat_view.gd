class_name CombatView
extends Node2D
## Draws the arena and owns the combat logic objects, ticking recovery and the enemy from
## _process with one shared delta. Layout (landscape): a thin HUD band at the top of the
## arena (player HP/armor left, enemy HP right), then 3 lane rows stacked below it. The
## player marker stands at the left edge of its row, the enemy body at the right edge of
## the middle row. Telegraph (stripe, icon, countdown ring), hit/miss feedback and the
## VICTORY/DEFEAT band are drawn inside the rows, never over the HUD. Placeholder art.
## Implements: Story 003, Story 005.

const ENEMY_COLOR: Color = Color(0.7, 0.3, 0.3)
const ENEMY_DEAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const BAR_BACK: Color = Color(0.2, 0.17, 0.15, 0.8)
const HP_COLOR: Color = Color(0.85, 0.2, 0.2)
const PLAYER_HP_COLOR: Color = Color(0.3, 0.75, 0.35)
const ARMOR_COLOR: Color = Color(0.3, 0.55, 0.95)
const TEXT_COLOR: Color = Color(0.15, 0.12, 0.1)
const DROP_COLOR: Color = Color(0.2, 0.8, 0.4)
const LANE_LINE_COLOR: Color = Color(0.15, 0.12, 0.1, 0.35)
const LANE_TINT: Color = Color(1.0, 1.0, 1.0, 0.08)
const STRIPE_COLOR: Color = Color(0.9, 0.1, 0.1, 0.32)
const WARN_COLOR: Color = Color(0.9, 0.1, 0.1)
const ICON_FILL: Color = Color(1.0, 0.85, 0.1)
const PLAYER_COLOR: Color = Color(0.25, 0.6, 0.9)
const HIT_COLOR: Color = Color(0.9, 0.1, 0.1)
const MISS_COLOR: Color = Color(0.1, 0.5, 0.2)
const PAD: float = 10.0
const BAR_HEIGHT: float = 22.0
const FONT_SIZE: int = 24
const BIG_FONT_SIZE: int = 72
const RING_WIDTH: float = 8.0
## In-row elements scale from the row height so they always fit one lane row:
## player marker radius, countdown ring radius, warning icon half-size, feedback font.
const MARKER_RADIUS_RATIO: float = 0.33
const RING_RADIUS_RATIO: float = 0.40
const ICON_SIZE_RATIO: float = 0.36
const FEEDBACK_FONT_RATIO: float = 0.55
## Enemy body width and height as a share of row height (fits inside one row with padding).
const ENEMY_BODY_WIDTH_RATIO: float = 0.9
const ENEMY_BODY_HEIGHT_RATIO: float = 0.7
## Countdown ring and warning icon horizontal centres as a share of row width
## (between the player at ScreenLayout.PLAYER_X_RATIO and the enemy at ENEMY_X_RATIO).
const RING_X_RATIO: float = 0.55
const ICON_X_RATIO: float = 0.69
## Gap between the HUD's left and right halves as a share of arena width.
const HUD_GAP_RATIO: float = 0.04

@export_file("*.json") var config_path: String = CombatConfig.DEFAULT_PATH
@export_file("*.json") var pattern_path: String = EnemyPatternConfig.DEFAULT_PATH
## Slot row that shows the recovery lock (dimmed slots + bar).
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
## Dev/capture only: when true time does not advance (recovery, enemy, feedback), so
## screenshots are deterministic.
var freeze_recovery: bool = false

var _player: CardPlayer
var _enemy: EnemyLogic
var _drop_highlight: bool = false
var _lane_highlight: int = -1
var _feedback_left: float = 0.0
var _feedback_hit: bool = false
var _feedback_lane: int = 1


func _ready() -> void:
	var config: CombatConfig = CombatConfig.load_from_file(config_path)
	if config == null:
		push_warning("CombatView: using built-in default config (no card effects)")
		config = CombatConfig.new()
	var state := CombatState.new(config.player_max_hp, config.enemy_max_hp)
	_player = CardPlayer.new(config, state, RecoveryLock.new())
	var pattern: EnemyPatternConfig = EnemyPatternConfig.load_from_file(pattern_path)
	if pattern == null:
		push_warning("CombatView: no enemy pattern, enemy stays idle")
		pattern = EnemyPatternConfig.new()
	_enemy = EnemyLogic.new(pattern, state)
	_enemy.attack_resolved.connect(_on_attack_resolved)


func _process(delta: float) -> void:
	if not freeze_recovery:
		# Cap the step so a frame hitch cannot telegraph and resolve an attack in one tick.
		var step: float = minf(delta, _enemy.get_config().max_tick_sec)
		_player.get_lock().tick(step)
		_enemy.tick(step)
		_feedback_left = maxf(_feedback_left - step, 0.0)
	var lock: RecoveryLock = _player.get_lock()
	var slots_view := get_node_or_null(hold_slots_view_path) as HoldSlotsView
	if slots_view != null:
		slots_view.set_recovery(lock.get_ratio(), lock.get_remaining())
	queue_redraw()


func _on_attack_resolved(target_lane: int, _damage: float, hit: bool) -> void:
	_feedback_left = _enemy.get_config().feedback_sec
	_feedback_hit = hit
	_feedback_lane = target_lane


func _draw() -> void:
	if _player == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var arena: Rect2 = ScreenLayout.arena_rect(vp)
	var state: CombatState = _player.get_state()
	_draw_lanes(vp, arena)
	_draw_hud(vp, state)
	_draw_telegraph(vp)
	_draw_enemy(vp, state)
	_draw_player_marker(vp, state)
	_draw_feedback(vp, state)
	if _lane_highlight != -1:
		var lane_rect: Rect2 = ScreenLayout.lane_rect(vp, _lane_highlight)
		draw_rect(lane_rect, Color(DROP_COLOR, 0.2))
		draw_rect(lane_rect, DROP_COLOR, false, 8.0)
	if _drop_highlight:
		draw_rect(arena, Color(DROP_COLOR, 0.15))
		draw_rect(arena, DROP_COLOR, false, 8.0)
	_draw_banner(arena, state)


## The card-playing logic (play through [method CardPlayer.play]).
func get_player() -> CardPlayer:
	return _player


## The enemy logic (time-to-impact API: [method EnemyLogic.get_time_to_impact]).
func get_enemy() -> EnemyLogic:
	return _enemy


## Screen rectangle of the arena (the card drop target).
func get_arena_rect() -> Rect2:
	return ScreenLayout.arena_rect(get_viewport_rect().size)


## Lane row under the viewport point, or -1 outside the lane area.
func get_lane_at(point: Vector2) -> int:
	return ScreenLayout.lane_at(get_viewport_rect().size, point)


## Shows or hides the arena as the current drop target.
func set_drop_highlight(on: bool) -> void:
	_drop_highlight = on


## Highlights one lane row as the valid drop target (-1 = none).
func set_lane_highlight(lane: int) -> void:
	_lane_highlight = lane


func _draw_lanes(vp: Vector2, arena: Rect2) -> void:
	for lane: int in ScreenLayout.LANE_COUNT:
		var rect: Rect2 = ScreenLayout.lane_rect(vp, lane)
		if lane % 2 == 0:
			draw_rect(rect, LANE_TINT)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), LANE_LINE_COLOR, 3.0)
	draw_rect(arena, LANE_LINE_COLOR, false, 3.0)


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
	var row: Rect2 = ScreenLayout.lane_rect(vp, CombatState.ENEMY_LANE)
	var body_size := Vector2(row.size.y * ENEMY_BODY_WIDTH_RATIO, row.size.y * ENEMY_BODY_HEIGHT_RATIO)
	var body := Rect2(ScreenLayout.enemy_center(vp, CombatState.ENEMY_LANE) - body_size * 0.5, body_size)
	draw_rect(body, ENEMY_DEAD_COLOR if dead else ENEMY_COLOR)
	draw_rect(body, TEXT_COLOR, false, 3.0)
	if dead:
		draw_line(body.position, body.end, TEXT_COLOR, 6.0)
		draw_line(Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), TEXT_COLOR, 6.0)


# Red stripe over the target row, warning icon at the enemy side of the row, countdown
# ring + seconds between player and enemy.
func _draw_telegraph(vp: Vector2) -> void:
	if not _enemy.has_incoming_attack():
		return
	var row: Rect2 = ScreenLayout.lane_rect(vp, _enemy.get_target_lane())
	draw_rect(row, STRIPE_COLOR)
	draw_rect(row, WARN_COLOR, false, 4.0)
	var icon: float = row.size.y * ICON_SIZE_RATIO
	var icon_c := Vector2(row.position.x + row.size.x * ICON_X_RATIO, row.get_center().y)
	var tri := PackedVector2Array([
		icon_c + Vector2(0.0, -icon), icon_c + Vector2(icon, icon * 0.8), icon_c + Vector2(-icon, icon * 0.8)
	])
	draw_colored_polygon(tri, ICON_FILL)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), WARN_COLOR, 5.0)
	draw_string(ThemeDB.fallback_font, icon_c + Vector2(-icon, icon * 0.6), "!", HORIZONTAL_ALIGNMENT_CENTER, icon * 2.0, int(icon * 1.2), WARN_COLOR)
	var ring: float = row.size.y * RING_RADIUS_RATIO
	var ring_c := Vector2(row.position.x + row.size.x * RING_X_RATIO, row.get_center().y)
	draw_circle(ring_c, ring, Color(1.0, 1.0, 1.0, 0.8))
	draw_arc(ring_c, ring, 0.0, TAU, 48, BAR_BACK, RING_WIDTH)
	var ratio: float = _enemy.get_telegraph_ratio()
	draw_arc(ring_c, ring, -PI * 0.5, -PI * 0.5 + TAU * ratio, 48, WARN_COLOR, RING_WIDTH)
	var secs: String = "%.1f" % _enemy.get_time_to_impact()
	draw_string(ThemeDB.fallback_font, ring_c + Vector2(-ring, 9.0), secs, HORIZONTAL_ALIGNMENT_CENTER, ring * 2.0, FONT_SIZE, TEXT_COLOR)


func _draw_player_marker(vp: Vector2, state: CombatState) -> void:
	var c: Vector2 = ScreenLayout.player_marker_center(vp, state.player_lane)
	var radius: float = _marker_radius(vp)
	var color: Color = PLAYER_COLOR
	if state.is_player_dead():
		color = ENEMY_DEAD_COLOR
	elif _feedback_left > 0.0 and _feedback_hit:
		color = HIT_COLOR
	draw_circle(c, radius, color)
	draw_arc(c, radius, 0.0, TAU, 32, TEXT_COLOR, 3.0)
	draw_string(ThemeDB.fallback_font, c + Vector2(-radius, 8.0), "YOU", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, FONT_SIZE - 6, Color.WHITE)


# HIT!/MISS text in the player's row just right of the marker; the target row is tinted
# (hit) or outlined (miss).
func _draw_feedback(vp: Vector2, state: CombatState) -> void:
	if _feedback_left <= 0.0:
		return
	var target_row: Rect2 = ScreenLayout.lane_rect(vp, _feedback_lane)
	if _feedback_hit:
		draw_rect(target_row, Color(HIT_COLOR, 0.25))
	else:
		draw_rect(target_row, MISS_COLOR, false, 6.0)
	var marker: Vector2 = ScreenLayout.player_marker_center(vp, state.player_lane)
	var text: String = "HIT!" if _feedback_hit else "MISS"
	var color: Color = HIT_COLOR if _feedback_hit else MISS_COLOR
	var font_size: int = int(ScreenLayout.lane_rect(vp, 0).size.y * FEEDBACK_FONT_RATIO)
	var pos := Vector2(marker.x + _marker_radius(vp) + PAD, marker.y + font_size * 0.35)
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


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
	return ScreenLayout.lane_rect(vp, 0).size.y * MARKER_RADIUS_RATIO


func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, BAR_BACK)
	var fill := Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)
	draw_rect(Rect2(rect.position, fill), color)
	draw_rect(rect, TEXT_COLOR, false, 2.0)


func _draw_text(text: String, pos: Vector2, width: float, align: HorizontalAlignment, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, align, width, FONT_SIZE, color)

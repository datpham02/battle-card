class_name CombatView
extends Node2D
## Draws the arena contents (dummy enemy + HP bar, player HP/armor, drop highlight) and
## owns the combat logic objects, ticking recovery from _process. Placeholder art.
## Implements: Story 003.

const ENEMY_COLOR: Color = Color(0.7, 0.3, 0.3)
const ENEMY_DEAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const BAR_BACK: Color = Color(0.2, 0.17, 0.15, 0.8)
const HP_COLOR: Color = Color(0.85, 0.2, 0.2)
const PLAYER_HP_COLOR: Color = Color(0.3, 0.75, 0.35)
const ARMOR_COLOR: Color = Color(0.3, 0.55, 0.95)
const TEXT_COLOR: Color = Color(0.15, 0.12, 0.1)
const DROP_COLOR: Color = Color(0.2, 0.8, 0.4)
const PAD: float = 24.0
const BAR_HEIGHT: float = 26.0
const FONT_SIZE: int = 26

@export_file("*.json") var config_path: String = CombatConfig.DEFAULT_PATH
## Slot row that shows the recovery lock (dimmed slots + bar).
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
## Dev/capture only: when true recovery does not advance (deterministic screenshots).
var freeze_recovery: bool = false

var _player: CardPlayer
var _drop_highlight: bool = false


func _ready() -> void:
	var config: CombatConfig = CombatConfig.load_from_file(config_path)
	if config == null:
		push_warning("CombatView: using built-in default config (no card effects)")
		config = CombatConfig.new()
	_player = CardPlayer.new(
		config, CombatState.new(config.player_max_hp, config.enemy_max_hp), RecoveryLock.new()
	)


func _process(delta: float) -> void:
	if not freeze_recovery:
		_player.get_lock().tick(delta)
	var lock: RecoveryLock = _player.get_lock()
	var slots_view := get_node_or_null(hold_slots_view_path) as HoldSlotsView
	if slots_view != null:
		slots_view.set_recovery(lock.get_ratio(), lock.get_remaining())
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var arena: Rect2 = ScreenLayout.arena_rect(get_viewport_rect().size)
	var state: CombatState = _player.get_state()
	var dead: bool = state.is_enemy_dead()
	var body_size := Vector2(arena.size.x * 0.4, arena.size.y * 0.36)
	var body := Rect2(
		Vector2(arena.get_center().x - body_size.x * 0.5, arena.position.y + PAD + 10.0), body_size
	)
	draw_rect(body, ENEMY_DEAD_COLOR if dead else ENEMY_COLOR)
	draw_rect(body, TEXT_COLOR, false, 3.0)
	if dead:
		draw_line(body.position, body.end, TEXT_COLOR, 6.0)
		draw_line(
			Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), TEXT_COLOR, 6.0
		)
	var bar_width: float = arena.size.x - PAD * 4.0
	var bar := Rect2(
		Vector2(arena.position.x + PAD * 2.0, body.end.y + PAD), Vector2(bar_width, BAR_HEIGHT)
	)
	_draw_bar(bar, state.enemy_hp / state.enemy_max_hp, HP_COLOR)
	var enemy_text: String = "DUMMY  DEAD"
	if not dead:
		enemy_text = "DUMMY  HP %d/%d" % [ceili(state.enemy_hp), ceili(state.enemy_max_hp)]
	_draw_text(enemy_text, bar.position + Vector2(0.0, BAR_HEIGHT + FONT_SIZE + 4.0), bar_width, HORIZONTAL_ALIGNMENT_CENTER, TEXT_COLOR)
	var pbar := Rect2(
		Vector2(bar.position.x, arena.end.y - PAD - BAR_HEIGHT - FONT_SIZE - 12.0),
		Vector2(bar_width, BAR_HEIGHT)
	)
	_draw_bar(pbar, state.player_hp / state.player_max_hp, PLAYER_HP_COLOR)
	var hp_text: String = "YOU  HP %d/%d" % [ceili(state.player_hp), ceili(state.player_max_hp)]
	_draw_text(hp_text, pbar.position + Vector2(0.0, -6.0), bar_width, HORIZONTAL_ALIGNMENT_LEFT, TEXT_COLOR)
	var armor_pos: Vector2 = pbar.position + Vector2(0.0, BAR_HEIGHT + FONT_SIZE + 4.0)
	var armor_color: Color = TEXT_COLOR
	if state.player_armor > 0.0:
		armor_color = ARMOR_COLOR.darkened(0.3)
		var armor_ratio: float = minf(state.player_armor / state.player_max_hp, 1.0)
		draw_rect(Rect2(pbar.position + Vector2(0.0, BAR_HEIGHT + 3.0), Vector2(bar_width * armor_ratio, 6.0)), ARMOR_COLOR)
	_draw_text("ARMOR %d" % ceili(state.player_armor), armor_pos, bar_width, HORIZONTAL_ALIGNMENT_LEFT, armor_color)
	if _drop_highlight:
		draw_rect(arena, Color(DROP_COLOR, 0.15))
		draw_rect(arena, DROP_COLOR, false, 8.0)


## The card-playing logic (play through [method CardPlayer.play]).
func get_player() -> CardPlayer:
	return _player


## Screen rectangle of the arena (the card drop target).
func get_arena_rect() -> Rect2:
	return ScreenLayout.arena_rect(get_viewport_rect().size)


## Shows or hides the arena as the current drop target.
func set_drop_highlight(on: bool) -> void:
	_drop_highlight = on


func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, BAR_BACK)
	var fill := Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)
	draw_rect(Rect2(rect.position, fill), color)
	draw_rect(rect, TEXT_COLOR, false, 2.0)


func _draw_text(text: String, pos: Vector2, width: float, align: HorizontalAlignment, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, align, width, FONT_SIZE, color)

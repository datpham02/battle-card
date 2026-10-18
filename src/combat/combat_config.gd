class_name CombatConfig
extends RefCounted
## Combat start values, timing and the board shape, loaded from assets/data/combat.json.
## Schema: assets/data/schema.md. Implements: Story 003, Story 007.

const DEFAULT_PATH: String = "res://assets/data/combat.json"
## Built-in fallback board (columns / rows of ONE half), used only when the JSON omits them.
const FALLBACK_SIDE_COLS: int = 3
const FALLBACK_SIDE_ROWS: int = 3

var player_max_hp: float = 100.0
var enemy_max_hp: float = 100.0
## Columns / rows of one half of the board.
var side_cols: int = FALLBACK_SIDE_COLS
var side_rows: int = FALLBACK_SIDE_ROWS
## Holes in side coordinates (mirrored to the other half by BoardGrid).
var missing_cells: Array[Vector2i] = []
## The board built from the three values above (never null after construction).
var grid: BoardGrid = BoardGrid.new(FALLBACK_SIDE_COLS, FALLBACK_SIDE_ROWS)
## Optional start-cell overrides (board cells). BoardGrid.NO_CELL = use the grid's default.
var player_start_cell: Vector2i = BoardGrid.NO_CELL
var enemy_start_cell: Vector2i = BoardGrid.NO_CELL
## Cap (s) on one frame's time step so a frame hitch cannot skip logic windows.
var max_tick_sec: float = 0.1
## Seconds the HIT / MISS feedback stays on screen.
var feedback_sec: float = 1.0
## Seconds the player must wait between steps.
var player_step_cooldown_sec: float = 0.45


## Loads from a JSON file. Returns null (and pushes an error) on failure.
static func load_from_file(path: String = DEFAULT_PATH) -> CombatConfig:
	if not FileAccess.file_exists(path):
		push_error("CombatConfig: file not found: %s" % path)
		return null
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Returns null (and pushes an error) if invalid.
static func from_json_text(text: String) -> CombatConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CombatConfig: JSON root must be an object")
		return null
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults. Start cells that are not
## real cells of the unit's half are dropped (warning) so the grid default is used.
static func from_dictionary(data: Dictionary) -> CombatConfig:
	var config := CombatConfig.new()
	config.player_max_hp = maxf(float(data.get("player_max_hp", config.player_max_hp)), 1.0)
	config.enemy_max_hp = maxf(float(data.get("enemy_max_hp", config.enemy_max_hp)), 1.0)
	config.side_cols = int(data.get("side_cols", config.side_cols))
	config.side_rows = int(data.get("side_rows", config.side_rows))
	config.missing_cells = _parse_cells(data.get("missing_cells"))
	config.grid = BoardGrid.new(config.side_cols, config.side_rows, config.missing_cells)
	config.player_start_cell = _parse_cell(data.get("player_start_cell"), BoardGrid.NO_CELL)
	config.enemy_start_cell = _parse_cell(data.get("enemy_start_cell"), BoardGrid.NO_CELL)
	config._validate_start_cells()
	config.max_tick_sec = maxf(float(data.get("max_tick_sec", config.max_tick_sec)), 0.001)
	config.feedback_sec = maxf(float(data.get("feedback_sec", config.feedback_sec)), 0.0)
	config.player_step_cooldown_sec = maxf(
		float(data.get("player_step_cooldown_sec", config.player_step_cooldown_sec)), 0.0
	)
	return config


## Replaces the board (dev / capture override). Start-cell overrides were authored for the
## data board, so they are cleared and the new grid's default cells are used.
func use_grid(new_grid: BoardGrid) -> void:
	grid = new_grid
	side_cols = new_grid.side_cols
	side_rows = new_grid.side_rows
	missing_cells = new_grid.missing_side_cells()
	player_start_cell = BoardGrid.NO_CELL
	enemy_start_cell = BoardGrid.NO_CELL


func _validate_start_cells() -> void:
	if player_start_cell != BoardGrid.NO_CELL and not grid.is_player_cell(player_start_cell):
		push_warning("CombatConfig: player_start_cell %s is not a cell of the player's half, using the default" % player_start_cell)
		player_start_cell = BoardGrid.NO_CELL
	if enemy_start_cell != BoardGrid.NO_CELL and not grid.is_enemy_cell(enemy_start_cell):
		push_warning("CombatConfig: enemy_start_cell %s is not a cell of the boss's half, using the default" % enemy_start_cell)
		enemy_start_cell = BoardGrid.NO_CELL


static func _parse_cell(raw: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() == 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return fallback


static func _parse_cells(raw: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY:
		return cells
	for item: Variant in raw as Array:
		var cell: Vector2i = _parse_cell(item, BoardGrid.NO_CELL)
		if cell == BoardGrid.NO_CELL:
			push_warning("CombatConfig: bad missing_cells entry %s, ignored" % str(item))
		else:
			cells.append(cell)
	return cells

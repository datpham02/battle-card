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
## Story 016: the pause is refused during the last this-many seconds of a running swing
## (no "preview the hit" pause). 0 = only the skill menu blocks the pause.
var pause_lockout_sec: float = 0.5
## Story 021: default cells the player must cast to fill the signature charge bar (a character's
## `signature.charge_cells` overrides it).
var signature_charge_cells: int = 18
## Story 021: keyboard key name (OS.find_keycode_from_string) that fires the signature on desktop.
var signature_key: String = "Q"
## Board-scaled step cooldown: [member step_cooldown_ref_sec] on a board that is
## [member step_cooldown_ref_steps] steps across, scaled by (ref_steps / steps_across)^exponent
## and clamped to [min, max]. See [method step_cooldown_for].
var step_cooldown_ref_sec: float = 0.45
var step_cooldown_ref_steps: int = 2
var step_cooldown_exponent: float = 0.75
var step_cooldown_min_sec: float = 0.18
var step_cooldown_max_sec: float = 0.60
## DEPRECATED absolute override of the computed player step cooldown; negative = not set.
var player_step_cooldown_sec: float = -1.0
## Story 020 keywords. These are the ONLY built-in fallbacks (used when combat.json omits or
## invalidates a key); the tuned values live in combat.json.
## Ghim: damage multiplier against a pinned unit (>= 0; 1.0 = control only, Story 023).
var pinned_damage_mult: float = 1.0
## Dot: seconds added to a re-ignited burning cell, extra damage per tick per extra stack, stack cap.
var burn_stack_extend_sec: float = 2.0
var burn_stack_tick_bonus: float = 1.0
var burn_max_stacks: int = 3
## Story 023: Ran (fragile) damage multiplier (>= 1) and stack cap (>= 1); Han (frost) stacks that
## trigger the burst (>= 1) and its damage (>= 0, ignores defense and Ran); default execute threshold
## (share of max HP, 0..1) for cards with `execute: true`. Ghim is control only: its multiplier is 1.0.
var fragile_mult: float = 1.5
var fragile_max_stacks: int = 3
var frost_stacks_to_burst: int = 3
var frost_burst_damage: float = 24.0
var execute_ratio: float = 0.25


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
	config.pause_lockout_sec = maxf(float(data.get("pause_lockout_sec", config.pause_lockout_sec)), 0.0)
	config.signature_charge_cells = maxi(int(data.get("signature_charge_cells", config.signature_charge_cells)), 1)
	var key_name: String = str(data.get("signature_key", config.signature_key)).strip_edges()
	if key_name.is_empty() or OS.find_keycode_from_string(key_name) == KEY_NONE:
		push_warning("CombatConfig: signature_key '%s' is not a key name, using '%s'" % [key_name, config.signature_key])
	else:
		config.signature_key = key_name
	config._parse_step_cooldown(data)
	config._parse_keywords(data)
	return config


## Seconds between steps on [param board]: the computed, board-scaled value (or the deprecated
## `player_step_cooldown_sec` override when combat.json still carries it).
func step_cooldown_for(board: BoardGrid) -> float:
	if player_step_cooldown_sec >= 0.0:
		return player_step_cooldown_sec
	var steps_across: int = maxi(maxi(board.side_cols, board.side_rows) - 1, 1)
	var raw: float = step_cooldown_ref_sec * pow(float(step_cooldown_ref_steps) / float(steps_across), step_cooldown_exponent)
	return clampf(raw, step_cooldown_min_sec, step_cooldown_max_sec)


## Replaces the board (dev / capture override). Start-cell overrides were authored for the
## data board, so they are cleared and the new grid's default cells are used.
func use_grid(new_grid: BoardGrid) -> void:
	grid = new_grid
	side_cols = new_grid.side_cols
	side_rows = new_grid.side_rows
	missing_cells = new_grid.missing_side_cells()
	player_start_cell = BoardGrid.NO_CELL
	enemy_start_cell = BoardGrid.NO_CELL


func _parse_keywords(data: Dictionary) -> void:
	var mult: float = float(data.get("pinned_damage_mult", pinned_damage_mult))
	var extend: float = float(data.get("burn_stack_extend_sec", burn_stack_extend_sec))
	var bonus: float = float(data.get("burn_stack_tick_bonus", burn_stack_tick_bonus))
	var stacks: int = int(data.get("burn_max_stacks", burn_max_stacks))
	var f_mult: float = float(data.get("fragile_mult", fragile_mult))
	var f_max: int = int(data.get("fragile_max_stacks", fragile_max_stacks))
	var frost_n: int = int(data.get("frost_stacks_to_burst", frost_stacks_to_burst))
	var frost_dmg: float = float(data.get("frost_burst_damage", frost_burst_damage))
	var exec_ratio: float = float(data.get("execute_ratio", execute_ratio))
	if f_mult >= 1.0 and f_max >= 1 and frost_n >= 1 and frost_dmg >= 0.0 and exec_ratio >= 0.0 and exec_ratio <= 1.0:
		fragile_mult = f_mult
		fragile_max_stacks = f_max
		frost_stacks_to_burst = frost_n
		frost_burst_damage = frost_dmg
		execute_ratio = exec_ratio
	else:
		push_warning("CombatConfig: invalid Ran/Han/execute values (fragile_mult>=1, fragile_max_stacks>=1, frost_stacks_to_burst>=1, frost_burst_damage>=0, execute_ratio 0..1), using defaults")
	if mult >= 0.0 and extend >= 0.0 and bonus >= 0.0 and stacks >= 1:
		pinned_damage_mult = mult
		burn_stack_extend_sec = extend
		burn_stack_tick_bonus = bonus
		burn_max_stacks = stacks
	else:
		push_warning("CombatConfig: invalid keyword values (pinned_damage_mult>=0, burn_stack_*>=0, burn_max_stacks>=1), using defaults")


## Applies the keyword numbers to [param status].
func configure_status(status: StatusEffects) -> void:
	status.configure(burn_stack_extend_sec, burn_stack_tick_bonus, burn_max_stacks, pinned_damage_mult)
	status.configure_keywords(fragile_mult, fragile_max_stacks, frost_stacks_to_burst, frost_burst_damage)


func _parse_step_cooldown(data: Dictionary) -> void:
	var ref_sec: float = float(data.get("step_cooldown_ref_sec", step_cooldown_ref_sec))
	var ref_steps: int = int(data.get("step_cooldown_ref_steps", step_cooldown_ref_steps))
	var exponent: float = float(data.get("step_cooldown_exponent", step_cooldown_exponent))
	var min_sec: float = float(data.get("step_cooldown_min_sec", step_cooldown_min_sec))
	var max_sec: float = float(data.get("step_cooldown_max_sec", step_cooldown_max_sec))
	if ref_sec > 0.0 and ref_steps >= 1 and exponent >= 0.0 and min_sec <= max_sec:
		step_cooldown_ref_sec = ref_sec
		step_cooldown_ref_steps = ref_steps
		step_cooldown_exponent = exponent
		step_cooldown_min_sec = min_sec
		step_cooldown_max_sec = max_sec
	else:
		push_warning("CombatConfig: invalid step_cooldown_* values, using defaults")
	if data.has("player_step_cooldown_sec"):
		push_warning("CombatConfig: player_step_cooldown_sec is deprecated (overrides the board-scaled step cooldown); remove it")
		player_step_cooldown_sec = maxf(float(data["player_step_cooldown_sec"]), 0.0)


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

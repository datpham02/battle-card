class_name RowBurnerTrait
extends BossTrait
## Trait `row_burner`: every `interval_sec` of simulation time (warning to warning) the boss
## announces one row of the player's half, then `warn_sec` later ignites it for `burn_sec`
## through StatusEffects.ignite (damage `damage_per_tick` every `tick_sec` to a unit standing
## in it). `row_pick` = `player_row` (default: the row the player stands on when the warning
## starts; moving out afterwards is the counterplay) or `random` (a seeded row of the half).
## While a warning runs the next one waits for it to end. The HUD reads the warning through
## [method get_warning_cells] / [method get_warn_left].
## Params (chapters.json `traits[].params`, defaults in the constants below): `interval_sec`,
## `warn_sec`, `burn_sec`, `tick_sec`, `damage_per_tick`, `first_delay_sec`, `row_pick`.
## Implements: Story 014 (Part B).

## A row was announced: its real [param cells] on the player's half.
signal row_warned(cells: Array[Vector2i])
## The announced [param cells] just ignited.
signal row_burned(cells: Array[Vector2i])

const ID: String = "row_burner"
const DEFAULT_INTERVAL_SEC: float = 8.0
const DEFAULT_WARN_SEC: float = 1.2
const DEFAULT_BURN_SEC: float = 2.5
const DEFAULT_TICK_SEC: float = 0.5
const DEFAULT_DAMAGE_PER_TICK: float = 2.0
const DEFAULT_FIRST_DELAY_SEC: float = 4.0
const ROW_PICK_PLAYER: String = "player_row"
const ROW_PICK_RANDOM: String = "random"
const DEFAULT_ROW_PICK: String = ROW_PICK_PLAYER
const _SEED_OFFSET: int = 6151

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _warn_sec: float = DEFAULT_WARN_SEC
var _burn_sec: float = DEFAULT_BURN_SEC
var _tick_sec: float = DEFAULT_TICK_SEC
var _damage_per_tick: float = DEFAULT_DAMAGE_PER_TICK
var _first_delay_sec: float = DEFAULT_FIRST_DELAY_SEC
var _row_pick: String = DEFAULT_ROW_PICK
## Seconds until the next warning.
var _timer: float = 0.0
## Seconds of warning left (0 = no warning running).
var _warn_left: float = 0.0
var _warning_cells: Array[Vector2i] = []
var _last_burned_cells: Array[Vector2i] = []
var _burn_count: int = 0


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_interval_sec = maxf(param_float("interval_sec", DEFAULT_INTERVAL_SEC), 0.0)
	_warn_sec = maxf(param_float("warn_sec", DEFAULT_WARN_SEC), 0.0)
	_burn_sec = maxf(param_float("burn_sec", DEFAULT_BURN_SEC), 0.0)
	_tick_sec = maxf(param_float("tick_sec", DEFAULT_TICK_SEC), 0.0)
	_damage_per_tick = maxf(param_float("damage_per_tick", DEFAULT_DAMAGE_PER_TICK), 0.0)
	_first_delay_sec = maxf(param_float("first_delay_sec", DEFAULT_FIRST_DELAY_SEC), 0.0)
	_row_pick = param_string("row_pick", DEFAULT_ROW_PICK)
	if _row_pick != ROW_PICK_PLAYER and _row_pick != ROW_PICK_RANDOM:
		push_warning("RowBurnerTrait: unknown row_pick '%s', using %s" % [_row_pick, DEFAULT_ROW_PICK])
		_row_pick = DEFAULT_ROW_PICK


func on_match_start() -> void:
	_timer = _first_delay_sec
	_warn_left = 0.0
	_warning_cells = []
	_last_burned_cells = []
	_burn_count = 0


func on_tick(step: float) -> void:
	_timer -= step
	if not _warning_cells.is_empty():
		_warn_left -= step
		if _warn_left <= 0.0:
			_ignite()
		return
	if _timer > 0.0:
		return
	var cells: Array[Vector2i] = _pick_row_cells()
	if cells.is_empty():
		return
	_warning_cells = cells
	_warn_left = _warn_sec
	_timer = _interval_sec
	row_warned.emit(cells)
	if _warn_sec <= 0.0:
		_ignite()


## Cells of the row being announced (empty when no warning runs).
func get_warning_cells() -> Array[Vector2i]:
	return _warning_cells.duplicate()


## Seconds until the announced row ignites (0 when no warning runs).
func get_warn_left() -> float:
	return maxf(_warn_left, 0.0) if not _warning_cells.is_empty() else 0.0


## Seconds until the next warning starts (0 when one is due or running).
func get_next_warning_left() -> float:
	return maxf(_timer, 0.0)


## Cells ignited by the last burn (empty before the first).
func get_last_burned_cells() -> Array[Vector2i]:
	return _last_burned_cells.duplicate()


## Rows burned so far this match.
func get_burn_count() -> int:
	return _burn_count


func get_debug() -> Dictionary:
	return {
		"id": ID, "warn_left": get_warn_left(), "warning_cells": _warning_cells.size(),
		"next_warning_left": get_next_warning_left(), "burns": _burn_count,
	}


func teardown() -> void:
	_warning_cells = []
	_last_burned_cells = []
	super()


func _ignite() -> void:
	var status: StatusEffects = get_context().get("status") as StatusEffects
	var cells: Array[Vector2i] = _warning_cells
	_warning_cells = []
	_warn_left = 0.0
	if status != null:
		status.ignite(cells, _burn_sec, _tick_sec, _damage_per_tick)
	_last_burned_cells = cells.duplicate()
	_burn_count += 1
	row_burned.emit(cells)


# Real cells of the chosen row on the player's half.
func _pick_row_cells() -> Array[Vector2i]:
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	var state: CombatState = get_context().get("state") as CombatState
	var out: Array[Vector2i] = []
	if grid == null or state == null:
		return out
	var row: int = state.player_cell.y
	if _row_pick == ROW_PICK_RANDOM:
		var rows: Array[int] = []
		for cell: Vector2i in grid.player_cells():
			if not rows.has(cell.y):
				rows.append(cell.y)
		if rows.is_empty():
			return out
		rows.sort()
		row = rows[rng.randi_range(0, rows.size() - 1)]
	for cell: Vector2i in grid.player_cells():
		if cell.y == row:
			out.append(cell)
	return out

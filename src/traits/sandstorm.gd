class_name SandstormTrait
extends BossTrait
## Trait `sandstorm` (Story 036 Part C, Nhan Su Cat / sand_sphinx): every `interval_sec` a storm of `storm_sec`:
## the wind drift runs faster (TileHazards.set_drift_mult(`drift_mult`), drift_sec x 0.5) and `extra_sand` seeded
## cells of the player's half (never the player's cell, never a cell already sand) get sand through
## TileHazards.add_sand (which keeps the leave-a-path rule), lasting `sand_sec` after `sand_warn_sec` of warning
## (each <= 0 = the hazards' own defaults). When the storm ends the drift multiplier goes back to 1.
## Params (chapters.json, fallbacks below): `interval_sec`, `storm_sec`, `drift_mult`, `extra_sand`, `sand_sec`,
## `sand_warn_sec`, `first_delay_sec` (default = the interval).
## HUD: [method is_storm], [method get_storm_fraction].
## Implements: Story 036 (Part C).

## A storm started; [param cells] = the sand cells kept by add_sand.
signal storm_started(cells: Array[Vector2i])
## The storm ended.
signal storm_ended()

const ID: String = "sandstorm"
const DEFAULT_INTERVAL_SEC: float = 12.0
const DEFAULT_STORM_SEC: float = 3.0
const DEFAULT_DRIFT_MULT: float = 0.5
const DEFAULT_EXTRA_SAND: int = 2
const _SEED_OFFSET: int = 9433

## Float slack for timers counted down in fixed steps (0.1 x 4 may leave 1e-17).
const _EPS: float = 0.000001

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _storm_sec: float = DEFAULT_STORM_SEC
var _drift_mult: float = DEFAULT_DRIFT_MULT
var _extra_sand: int = DEFAULT_EXTRA_SAND
var _sand_sec: float = -1.0
var _sand_warn_sec: float = -1.0
var _first_delay_sec: float = DEFAULT_INTERVAL_SEC
var _timer: float = DEFAULT_INTERVAL_SEC
var _storm_left: float = 0.0
var _storm_count: int = 0
var _last_cells: Array[Vector2i] = []


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_interval_sec = maxf(param_float("interval_sec", DEFAULT_INTERVAL_SEC), 0.1)
	_storm_sec = maxf(param_float("storm_sec", DEFAULT_STORM_SEC), 0.0)
	_drift_mult = clampf(param_float("drift_mult", DEFAULT_DRIFT_MULT), 0.05, 1.0)
	_extra_sand = maxi(param_int("extra_sand", DEFAULT_EXTRA_SAND), 0)
	_sand_sec = param_float("sand_sec", -1.0)
	_sand_warn_sec = param_float("sand_warn_sec", -1.0)
	_first_delay_sec = maxf(param_float("first_delay_sec", _interval_sec), 0.0)


func on_match_start() -> void:
	_timer = _first_delay_sec
	_storm_left = 0.0
	_storm_count = 0
	_last_cells = []


func on_tick(step: float) -> void:
	if _storm_left > 0.0:
		_storm_left -= step
		if _storm_left <= _EPS:
			_end_storm()
	_timer -= step
	if _timer > _EPS:
		return
	_timer = _interval_sec
	if _storm_left <= 0.0:
		_start_storm()


## True while a storm blows.
func is_storm() -> bool:
	return _storm_left > 0.0


## Fraction (0..1) of the current storm still left; 0 when no storm.
func get_storm_fraction() -> float:
	if _storm_left <= 0.0 or _storm_sec <= 0.0:
		return 0.0
	return clampf(_storm_left / _storm_sec, 0.0, 1.0)


## Seconds until the next storm starts.
func get_next_storm_left() -> float:
	return maxf(_timer, 0.0)


## Storms so far this match.
func get_storm_count() -> int:
	return _storm_count


## Sand cells kept by the last storm.
func get_last_cells() -> Array[Vector2i]:
	return _last_cells.duplicate()


func get_debug() -> Dictionary:
	return {"id": ID, "storm": is_storm(), "storm_fraction": get_storm_fraction(), "storms": _storm_count, "next_left": get_next_storm_left()}


func teardown() -> void:
	if _storm_left > 0.0:
		var hazards: TileHazards = get_context().get("hazards") as TileHazards
		if hazards != null:
			hazards.set_drift_mult(1.0)
	_storm_left = 0.0
	_last_cells = []
	super()


func _start_storm() -> void:
	var hazards: TileHazards = get_hazards()
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	var state: CombatState = get_context().get("state") as CombatState
	if hazards == null or grid == null or state == null or _storm_sec <= 0.0:
		return
	_storm_left = _storm_sec
	_storm_count += 1
	hazards.set_drift_mult(_drift_mult)
	var free: Array[Vector2i] = []
	for cell: Vector2i in grid.player_cells():
		if cell != state.player_cell and not hazards.is_sanded(CombatState.Side.PLAYER, cell) \
				and not hazards.is_sand_warning(CombatState.Side.PLAYER, cell):
			free.append(cell)
	var picked: Array[Vector2i] = []
	while picked.size() < _extra_sand and not free.is_empty():
		var index: int = rng.randi_range(0, free.size() - 1)
		picked.append(free[index])
		free.remove_at(index)
	_last_cells = []
	if not picked.is_empty():
		_last_cells = hazards.add_sand(CombatState.Side.PLAYER, picked, _sand_sec, _sand_warn_sec)
	storm_started.emit(_last_cells.duplicate())


func _end_storm() -> void:
	_storm_left = 0.0
	var hazards: TileHazards = get_hazards()
	if hazards != null:
		hazards.set_drift_mult(1.0)
	storm_ended.emit()

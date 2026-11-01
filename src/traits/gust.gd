class_name GustTrait
extends BossTrait
## Trait `gust` (Story 039 Part C, Chim Gio / gale_bird; a light copy on the storm_dragon boss): every `interval_sec` a
## seeded direction is picked and shown as an arrow for `warn_sec`; then the PLAYER is pushed 1 cell that way. The push
## is CANCELLED (the player stays) when the target is outside the player's half or a missing cell, a fallen cell, a
## sealed cell, sand (filled or warning), or blocked for the player's mover (any blocker source). The warning shows
## even when the push will be cancelled (the cancel is judged when the gust lands, so a cell that changes meanwhile
## counts). The push is a plain CombatState.set_player_cell move: it starts no step cooldown.
## Params (match trait entry): `interval_sec` (default 6), `warn_sec` (default 0.6), `first_delay_sec` (default = interval).
## HUD: [method get_gust_dir] ((0, 0) when idle), [method get_gust_warn_left].
## Implements: Story 039 (Part C).

## The player was pushed from [param from] to [param to].
signal pushed(from: Vector2i, to: Vector2i)
## The gust landed on [param cell] but the push was cancelled (forbidden target).
signal cancelled(cell: Vector2i)

const ID: String = "gust"
const DEFAULT_INTERVAL_SEC: float = 6.0
const DEFAULT_WARN_SEC: float = 0.6
const _SEED_OFFSET: int = 9601
const _DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## Float slack for timers counted down in fixed steps.
const _EPS: float = 0.000001

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _warn_sec: float = DEFAULT_WARN_SEC
var _first_delay_sec: float = DEFAULT_INTERVAL_SEC
var _timer: float = DEFAULT_INTERVAL_SEC
var _dir: Vector2i = Vector2i.ZERO
var _warn_left: float = 0.0
var _gust_count: int = 0
var _push_count: int = 0
var _cancel_count: int = 0


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_interval_sec = maxf(param_float("interval_sec", DEFAULT_INTERVAL_SEC), 0.1)
	_warn_sec = maxf(param_float("warn_sec", DEFAULT_WARN_SEC), 0.0)
	_first_delay_sec = maxf(param_float("first_delay_sec", _interval_sec), 0.0)


func on_match_start() -> void:
	_timer = _first_delay_sec
	_dir = Vector2i.ZERO
	_warn_left = 0.0
	_gust_count = 0
	_push_count = 0
	_cancel_count = 0


func on_tick(step: float) -> void:
	if _dir != Vector2i.ZERO:
		_warn_left -= step
		if _warn_left <= _EPS:
			_land()
		return
	_timer -= step
	if _timer > _EPS:
		return
	_timer = _interval_sec
	_dir = _DIRS[rng.randi_range(0, _DIRS.size() - 1)]
	_warn_left = _warn_sec
	_gust_count += 1
	if _warn_sec <= _EPS:
		_land()


## The gust direction while its arrow shows, else (0, 0).
func get_gust_dir() -> Vector2i:
	return _dir


## Seconds until the gust lands while the arrow shows, else 0.
func get_gust_warn_left() -> float:
	return maxf(_warn_left, 0.0) if _dir != Vector2i.ZERO else 0.0


## Seconds until the next gust is announced (0 while an arrow shows).
func get_next_gust_left() -> float:
	return 0.0 if _dir != Vector2i.ZERO else maxf(_timer, 0.0)


## Gusts announced so far.
func get_gust_count() -> int:
	return _gust_count


## Gusts that moved the player.
func get_push_count() -> int:
	return _push_count


## Gusts whose push was cancelled.
func get_cancel_count() -> int:
	return _cancel_count


## True when the player may be pushed onto [param cell] (the rules of the class doc).
func can_push_to(cell: Vector2i) -> bool:
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	if grid == null or not grid.is_player_cell(cell):
		return false
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if status != null and status.is_hole(CombatState.Side.PLAYER, cell):
		return false
	var hazards: TileHazards = get_context().get("hazards") as TileHazards
	if hazards != null:
		if hazards.is_sanded(CombatState.Side.PLAYER, cell) or hazards.is_sand_warning(CombatState.Side.PLAYER, cell):
			return false
		if hazards.has_method("is_fallen") and bool(hazards.call("is_fallen", CombatState.Side.PLAYER, cell)):
			return false
	var mover: UnitMover = get_context().get("player_mover") as UnitMover
	if mover != null and mover.is_cell_blocked(cell):
		return false
	return true


func get_debug() -> Dictionary:
	return {"id": ID, "dir": _dir, "warn_left": get_gust_warn_left(), "gusts": _gust_count, "pushes": _push_count, "cancels": _cancel_count}


func teardown() -> void:
	_dir = Vector2i.ZERO
	_warn_left = 0.0
	super()


func _land() -> void:
	var dir: Vector2i = _dir
	_dir = Vector2i.ZERO
	_warn_left = 0.0
	var state: CombatState = get_context().get("state") as CombatState
	if state == null or state.is_player_dead() or dir == Vector2i.ZERO:
		return
	var from: Vector2i = state.player_cell
	var target: Vector2i = from + dir
	if can_push_to(target) and state.set_player_cell(target):
		_push_count += 1
		pushed.emit(from, target)
	else:
		_cancel_count += 1
		cancelled.emit(from)

class_name RiposteTrait
extends BossTrait
## Trait `riposte` (Story 036 Part C, Bo Cap Phan / scorpion): when a player cast of at least `min_cells` cells
## HITS the boss, the boss answers with a 1-cell counter on the cell the player stood on AT THE MOMENT OF THE HIT
## (never re-aimed): the cell is shown for `warn_sec`, then a player still standing on it takes `damage`. One
## counter at a time (a hit while a counter is pending does not queue another). The opposite of spore_burst: it
## rewards small casts.
## Params (chapters.json, fallbacks below): `min_cells`, `warn_sec`, `damage`.
## HUD: [method get_riposte_cell], [method get_riposte_warn_left].
## Implements: Story 036 (Part C).

## A counter was announced on [param cell].
signal riposte_warned(cell: Vector2i)
## The counter landed on [param cell]; [param hit] = the player was still on it.
signal riposte_landed(cell: Vector2i, hit: bool)

const ID: String = "riposte"
const DEFAULT_MIN_CELLS: int = 4
const DEFAULT_WARN_SEC: float = 0.4
const DEFAULT_DAMAGE: float = 10.0
const _SEED_OFFSET: int = 9341

## Float slack for timers counted down in fixed steps (0.1 x 4 may leave 1e-17).
const _EPS: float = 0.000001

var _min_cells: int = DEFAULT_MIN_CELLS
var _warn_sec: float = DEFAULT_WARN_SEC
var _damage: float = DEFAULT_DAMAGE
var _cell: Vector2i = BoardGrid.NO_CELL
var _warn_left: float = 0.0
var _counter_count: int = 0
var _hit_count: int = 0


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_min_cells = maxi(param_int("min_cells", DEFAULT_MIN_CELLS), 1)
	_warn_sec = maxf(param_float("warn_sec", DEFAULT_WARN_SEC), 0.0)
	_damage = maxf(param_float("damage", DEFAULT_DAMAGE), 0.0)


func on_match_start() -> void:
	_cell = BoardGrid.NO_CELL
	_warn_left = 0.0
	_counter_count = 0
	_hit_count = 0


func on_player_swing_resolved(result: Dictionary) -> void:
	if not bool(result.get("hit", false)) or float(result.get("damage", 0.0)) <= 0.0:
		return
	var cells: Variant = result.get("cells", [])
	if typeof(cells) != TYPE_ARRAY or (cells as Array).size() < _min_cells or _cell != BoardGrid.NO_CELL:
		return
	var state: CombatState = get_context().get("state") as CombatState
	if state == null:
		return
	_cell = state.player_cell
	_warn_left = _warn_sec
	_counter_count += 1
	riposte_warned.emit(_cell)
	if _warn_left <= 0.0:
		_land()


func on_tick(step: float) -> void:
	if _cell == BoardGrid.NO_CELL:
		return
	_warn_left -= step
	if _warn_left <= _EPS:
		_land()


## The announced counter cell, or Vector2i(-1, -1) when none is pending.
func get_riposte_cell() -> Vector2i:
	return _cell if _cell != BoardGrid.NO_CELL else Vector2i(-1, -1)


## Seconds left before the pending counter lands (0 when none).
func get_riposte_warn_left() -> float:
	return maxf(_warn_left, 0.0) if _cell != BoardGrid.NO_CELL else 0.0


## Counters announced so far this match.
func get_counter_count() -> int:
	return _counter_count


## Counters that hit the player so far this match.
func get_hit_count() -> int:
	return _hit_count


func get_debug() -> Dictionary:
	return {"id": ID, "cell": get_riposte_cell(), "warn_left": get_riposte_warn_left(), "counters": _counter_count, "hits": _hit_count}


# The counter lands on the stored cell (the player's cell at the moment of the hit).
func _land() -> void:
	var cell: Vector2i = _cell
	_cell = BoardGrid.NO_CELL
	_warn_left = 0.0
	var state: CombatState = get_context().get("state") as CombatState
	var hit: bool = state != null and state.player_cell == cell and not state.is_player_dead()
	if hit:
		state.damage_player(_damage)
		_hit_count += 1
	riposte_landed.emit(cell, hit)

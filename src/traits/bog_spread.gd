class_name BogSpreadTrait
extends BossTrait
## Trait `bog_spread` (Story 036 Part B, Coc Chua / toad_matriarch): every `interval_sec` the boss turns `cells`
## cells of the PLAYER's half into timed mire for `mire_sec` (TileHazards.add_mire). Priority like thorn_field:
## while the boss is casting a swing of at least `min_swing_cells` cells, the player's escape cells next to that
## swing come first (cells the swing does not cover, reachable within `escape_steps` steps, touching a swing cell,
## never the player's own cell, nearest first, then x, then y); the rest (or all, with no such swing) are seeded
## cells of the player's half that are not mire already and not the player's cell. Mire never blocks a step, so no
## leave-a-path reduction applies.
## Params (chapters.json, fallbacks below): `interval_sec`, `cells`, `mire_sec`, `min_swing_cells`,
## `escape_steps`, `first_delay_sec` (default = the interval).
## Implements: Story 036 (Part B).

## Mire was spread on the player's half; [param escape] = the escape-cell priority applied.
signal bog_spread(cells: Array[Vector2i], escape: bool)

const ID: String = "bog_spread"
const DEFAULT_INTERVAL_SEC: float = 8.0
const DEFAULT_CELLS: int = 2
const DEFAULT_MIRE_SEC: float = 5.0
const DEFAULT_MIN_SWING_CELLS: int = 3
const DEFAULT_ESCAPE_STEPS: int = 2
const _SEED_OFFSET: int = 9241

## Float slack for timers counted down in fixed steps (0.1 x 4 may leave 1e-17).
const _EPS: float = 0.000001

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _cells: int = DEFAULT_CELLS
var _mire_sec: float = DEFAULT_MIRE_SEC
var _min_swing_cells: int = DEFAULT_MIN_SWING_CELLS
var _escape_steps: int = DEFAULT_ESCAPE_STEPS
var _first_delay_sec: float = DEFAULT_INTERVAL_SEC
var _timer: float = DEFAULT_INTERVAL_SEC
var _spread_count: int = 0
var _last_cells: Array[Vector2i] = []
var _last_escape: bool = false


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_interval_sec = maxf(param_float("interval_sec", DEFAULT_INTERVAL_SEC), 0.1)
	_cells = maxi(param_int("cells", DEFAULT_CELLS), 1)
	_mire_sec = maxf(param_float("mire_sec", DEFAULT_MIRE_SEC), 0.0)
	_min_swing_cells = maxi(param_int("min_swing_cells", DEFAULT_MIN_SWING_CELLS), 1)
	_escape_steps = maxi(param_int("escape_steps", DEFAULT_ESCAPE_STEPS), 1)
	_first_delay_sec = maxf(param_float("first_delay_sec", _interval_sec), 0.0)


func on_match_start() -> void:
	_timer = _first_delay_sec
	_spread_count = 0
	_last_cells = []
	_last_escape = false


func on_tick(step: float) -> void:
	_timer -= step
	if _timer > _EPS:
		return
	_timer = _interval_sec
	_spread()


## Spreads so far this match.
func get_spread_count() -> int:
	return _spread_count


## Cells of the last spread (empty before the first).
func get_last_cells() -> Array[Vector2i]:
	return _last_cells.duplicate()


## True when the last spread used the escape-cell priority.
func was_last_escape() -> bool:
	return _last_escape


## Seconds until the next spread.
func get_next_spread_left() -> float:
	return maxf(_timer, 0.0)


func get_debug() -> Dictionary:
	return {"id": ID, "spreads": _spread_count, "next_left": get_next_spread_left(), "escape": _last_escape}


func teardown() -> void:
	_last_cells = []
	super()


func _spread() -> void:
	var hazards: TileHazards = get_hazards()
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	var state: CombatState = get_context().get("state") as CombatState
	if hazards == null or grid == null or state == null or _mire_sec <= 0.0:
		return
	var picked: Array[Vector2i] = []
	var swing: Array[Vector2i] = _boss_swing_cells()
	var escape: bool = swing.size() >= _min_swing_cells
	if escape:
		for cell: Vector2i in _escape_cells(grid, state, swing):
			if picked.size() >= _cells:
				break
			picked.append(cell)
	var free: Array[Vector2i] = []
	for cell: Vector2i in grid.player_cells():
		if cell != state.player_cell and not picked.has(cell) and not hazards.is_mire(CombatState.Side.PLAYER, cell):
			free.append(cell)
	while picked.size() < _cells and not free.is_empty():
		var index: int = rng.randi_range(0, free.size() - 1)
		picked.append(free[index])
		free.remove_at(index)
	if picked.is_empty():
		return
	hazards.add_mire(CombatState.Side.PLAYER, picked, _mire_sec)
	_spread_count += 1
	_last_cells = picked.duplicate()
	_last_escape = escape
	bog_spread.emit(picked, escape)


# Cells of the boss's swing in progress (empty when it is not casting).
func _boss_swing_cells() -> Array[Vector2i]:
	var boss: BossController = get_context().get("boss") as BossController
	if boss == null or boss.get_actor() == null or not boss.get_actor().is_swinging():
		return [] as Array[Vector2i]
	return boss.get_actor().get_cells()


# The player's escape cells next to [param swing], nearest first (see the class doc).
func _escape_cells(grid: BoardGrid, state: CombatState, swing: Array[Vector2i]) -> Array[Vector2i]:
	var status: StatusEffects = get_context().get("status") as StatusEffects
	var mover: UnitMover = get_context().get("player_mover") as UnitMover
	var blocked: Array[Vector2i] = []
	if status != null:
		blocked = SealCasterTrait.blocked_player_cells(grid, status, mover)
	var player_cell: Vector2i = state.player_cell
	var out: Array[Vector2i] = []
	for cell: Vector2i in EscapeAnalysis.escape_cells(grid, player_cell, _escape_steps, true, swing, blocked):
		if cell != player_cell and ThornFieldTrait._touches(cell, swing):
			out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var na: int = absi(a.x - player_cell.x) + absi(a.y - player_cell.y)
		var nb: int = absi(b.x - player_cell.x) + absi(b.y - player_cell.y)
		if na != nb:
			return na < nb
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out

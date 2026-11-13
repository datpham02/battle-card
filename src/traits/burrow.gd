class_name BurrowTrait
extends BossTrait
## Trait `burrow` (Story 036 Part C, Bo Cat An / sand_burrower): every `interval_sec` (counted only while the boss is
## not casting) the boss burrows for `burrow_sec`: it cannot be hit (BossTrait.untargetable(): a player cast that
## lands meanwhile is a miss but still leaves its zone, Story 027 rule; a miss never interrupts) and it takes no
## decisions (BossController.set_active(false), restored when it surfaces, so nothing can interrupt it). It
## surfaces at a seeded cell of its half (not its burrow cell, not sealed, not sand, not blocked for its mover),
## shown as a warning circle for the last `surface_warn_sec` of the burrow; when the cell is no longer free at
## surfacing time another free cell is picked, else it surfaces where it burrowed.
## Params (chapters.json, fallbacks below): `interval_sec`, `burrow_sec`, `surface_warn_sec`, `first_delay_sec`
## (default = the interval).
## HUD: [method is_burrowed], [method get_surface_cell], [method get_surface_warn_left].
## Implements: Story 036 (Part C).

## The boss burrowed; it will surface on [param surface_cell].
signal burrowed(surface_cell: Vector2i)
## The boss surfaced on [param cell].
signal surfaced(cell: Vector2i)

const ID: String = "burrow"
const DEFAULT_INTERVAL_SEC: float = 7.0
const DEFAULT_BURROW_SEC: float = 1.5
const DEFAULT_SURFACE_WARN_SEC: float = 0.5
const _SEED_OFFSET: int = 9319
const _NONE: Vector2i = Vector2i(-1, -1)

## Float slack for timers counted down in fixed steps (0.1 x 4 may leave 1e-17).
const _EPS: float = 0.000001

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _burrow_sec: float = DEFAULT_BURROW_SEC
var _warn_sec: float = DEFAULT_SURFACE_WARN_SEC
var _first_delay_sec: float = DEFAULT_INTERVAL_SEC
var _timer: float = DEFAULT_INTERVAL_SEC
var _burrowed: bool = false
var _burrow_left: float = 0.0
var _surface_cell: Vector2i = _NONE
var _restore_active: bool = false
var _restore_pattern: bool = false
var _burrow_count: int = 0


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_interval_sec = maxf(param_float("interval_sec", DEFAULT_INTERVAL_SEC), 0.1)
	_burrow_sec = maxf(param_float("burrow_sec", DEFAULT_BURROW_SEC), 0.05)
	_warn_sec = clampf(param_float("surface_warn_sec", DEFAULT_SURFACE_WARN_SEC), 0.0, _burrow_sec)
	_first_delay_sec = maxf(param_float("first_delay_sec", _interval_sec), 0.0)


func on_match_start() -> void:
	_timer = _first_delay_sec
	_burrowed = false
	_burrow_left = 0.0
	_surface_cell = _NONE
	_burrow_count = 0


func untargetable() -> bool:
	return _burrowed


func on_tick(step: float) -> void:
	if _burrowed:
		_burrow_left -= step
		if _burrow_left <= _EPS:
			_surface()
		return
	_timer -= step
	if _timer > _EPS:
		return
	var boss: BossController = get_context().get("boss") as BossController
	if boss != null and boss.get_actor() != null and boss.get_actor().is_swinging():
		return  # waits for the cast in progress to resolve
	var pattern: PatternController = _pattern()
	if pattern != null and pattern.is_busy():
		return  # Phase 0 (G6): a pattern enemy finishes its skill (windup / warning / recovery) before it burrows
	_timer = _interval_sec
	_burrow(boss)


# Phase 0 (G6): the pattern brain's controller when the match runs one (ctx `pattern_getter`: Callable() ->
# PatternController, set by CombatView; the controller is built after the host), else null.
func _pattern() -> PatternController:
	var getter: Callable = get_context().get("pattern_getter", Callable()) as Callable
	if not getter.is_valid():
		return null
	return getter.call() as PatternController


## True while the boss is burrowed (cannot be hit).
func is_burrowed() -> bool:
	return _burrowed


## The surface cell while its warning circle shows (the last surface_warn_sec of the burrow), else (-1, -1).
func get_surface_cell() -> Vector2i:
	if _burrowed and _burrow_left <= _warn_sec + _EPS:
		return _surface_cell
	return _NONE


## Seconds until the boss surfaces while the warning shows, else 0.
func get_surface_warn_left() -> float:
	if _burrowed and _burrow_left <= _warn_sec + _EPS:
		return maxf(_burrow_left, 0.0)
	return 0.0


## Seconds until the next burrow (0 while burrowed or due).
func get_next_burrow_left() -> float:
	return 0.0 if _burrowed else maxf(_timer, 0.0)


## Burrows so far this match.
func get_burrow_count() -> int:
	return _burrow_count


func get_debug() -> Dictionary:
	return {"id": ID, "burrowed": _burrowed, "surface_cell": _surface_cell, "burrow_left": maxf(_burrow_left, 0.0), "burrows": _burrow_count}


func teardown() -> void:
	if _burrowed:
		var boss: BossController = get_context().get("boss") as BossController
		if boss != null and _restore_active:
			boss.set_active(true)
		var pattern: PatternController = _pattern()
		if pattern != null and _restore_pattern:
			pattern.set_active(true)
	_burrowed = false
	super()


func _burrow(boss: BossController) -> void:
	var state: CombatState = get_context().get("state") as CombatState
	if state == null or state.is_enemy_dead():
		return
	_burrowed = true
	_burrow_left = _burrow_sec
	_burrow_count += 1
	_restore_active = boss != null and boss.is_active()
	if boss != null:
		boss.set_active(false)
	# Phase 0 (G6): the pattern brain's clocks stop too (no skill is chosen or resolved underground).
	var pattern: PatternController = _pattern()
	_restore_pattern = pattern != null and pattern.is_active()
	if pattern != null:
		pattern.set_active(false)
	_surface_cell = _pick_cell(state.enemy_cell)
	burrowed.emit(_surface_cell)


func _surface() -> void:
	_burrowed = false
	_burrow_left = 0.0
	var state: CombatState = get_context().get("state") as CombatState
	var boss: BossController = get_context().get("boss") as BossController
	if state != null:
		var cell: Vector2i = _surface_cell
		if cell == _NONE or not _is_free(cell):
			cell = _pick_cell(state.enemy_cell)
		if cell != _NONE:
			state.set_enemy_cell(cell)
		surfaced.emit(state.enemy_cell)
	if boss != null and _restore_active:
		boss.set_active(true)
	var pattern: PatternController = _pattern()
	if pattern != null and _restore_pattern:
		pattern.set_active(true)
	_surface_cell = _NONE


# A seeded free cell of the boss's half other than [param from] (_NONE when none).
func _pick_cell(from: Vector2i) -> Vector2i:
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	if grid == null:
		return _NONE
	var free: Array[Vector2i] = []
	for cell: Vector2i in grid.enemy_cells():
		if cell != from and _is_free(cell):
			free.append(cell)
	if free.is_empty():
		return _NONE
	return free[rng.randi_range(0, free.size() - 1)]


func _is_free(cell: Vector2i) -> bool:
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	if grid == null or not grid.is_enemy_cell(cell):
		return false
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if status != null and status.is_hole(CombatState.Side.ENEMY, cell):
		return false
	var hazards: TileHazards = get_context().get("hazards") as TileHazards
	if hazards != null and (hazards.is_sanded(CombatState.Side.ENEMY, cell) or hazards.is_sand_warning(CombatState.Side.ENEMY, cell)):
		return false
	var boss: BossController = get_context().get("boss") as BossController
	if boss != null and boss.get_mover() != null and boss.get_mover().is_cell_blocked(cell):
		return false
	return true

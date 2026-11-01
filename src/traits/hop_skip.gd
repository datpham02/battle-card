class_name HopSkipTrait
extends BossTrait
## Trait `hop_skip` (Story 036 Part B, Ech Nhay / leap_frog): after every `hop_every` boss steps the boss's next
## move is a straight 2-cell hop that ignores what lies on the cell in between (seals, thorns, a blocked cell).
## The destination must be a real cell of its half that is steppable: not sealed, not sand (filled or warning),
## not blocked for its mover. The trait picks the hop as soon as the boss could step (mover ready, not casting,
## active): a hop over a blocked middle cell first, else a seeded straight direction. The destination is shown as
## a shadow for `hop_warn_sec` (the boss's normal steps are locked meanwhile through UnitMover.step_lock_fn, OR-ed
## with the lock that was there), then the boss lands if the cell is still steppable (else the hop is re-picked).
## The hop does not start a step cooldown (the warning already paid the time). Hop moves are not counted as steps.
## Params (chapters.json, fallbacks below): `hop_every`, `hop_warn_sec`.
## HUD: [method get_hop_target], [method get_hop_warn_left].
## Implements: Story 036 (Part B).

## A hop was announced to [param target].
signal hop_warned(target: Vector2i)
## The boss hopped from [param from] to [param to].
signal hopped(from: Vector2i, to: Vector2i)

const ID: String = "hop_skip"
const DEFAULT_HOP_EVERY: int = 3
const DEFAULT_HOP_WARN_SEC: float = 0.4
const _SEED_OFFSET: int = 9203
const _NONE: Vector2i = Vector2i(-1, -1)
const _DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## Float slack for timers counted down in fixed steps (0.1 x 4 may leave 1e-17).
const _EPS: float = 0.000001

var _hop_every: int = DEFAULT_HOP_EVERY
var _warn_sec: float = DEFAULT_HOP_WARN_SEC
var _steps: int = 0
var _target: Vector2i = _NONE
var _warn_left: float = 0.0
var _hop_count: int = 0
var _moving: bool = false
var _mover: UnitMover = null
var _prev_lock: Callable = Callable()
var _state: CombatState = null


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_hop_every = maxi(param_int("hop_every", DEFAULT_HOP_EVERY), 1)
	_warn_sec = maxf(param_float("hop_warn_sec", DEFAULT_HOP_WARN_SEC), 0.0)


func on_match_start() -> void:
	_steps = 0
	_target = _NONE
	_warn_left = 0.0
	_hop_count = 0
	_state = get_context().get("state") as CombatState
	if _state != null and not _state.cell_changed.is_connected(_on_cell_changed):
		_state.cell_changed.connect(_on_cell_changed)
	var boss: BossController = get_context().get("boss") as BossController
	_mover = boss.get_mover() if boss != null else null
	if _mover != null and _mover.step_lock_fn != Callable(self, "_is_locked"):
		_prev_lock = _mover.step_lock_fn
		_mover.step_lock_fn = Callable(self, "_is_locked")


func on_tick(step: float) -> void:
	if _target != _NONE:
		_warn_left = maxf(_warn_left - step, 0.0)
		if _warn_left <= _EPS:
			_land()
		return
	if _steps < _hop_every or not _can_move():
		return
	var target: Vector2i = _pick_target()
	if target == _NONE:
		return
	_target = target
	_warn_left = _warn_sec
	hop_warned.emit(_target)
	if _warn_left <= 0.0:
		_land()


## The announced hop destination (the shadow), or Vector2i(-1, -1) when none.
func get_hop_target() -> Vector2i:
	return _target


## Seconds left before the boss lands on [method get_hop_target] (0 when none).
func get_hop_warn_left() -> float:
	return _warn_left if _target != _NONE else 0.0


## Boss steps counted since the last hop.
func get_step_count() -> int:
	return _steps


## Hops so far this match.
func get_hop_count() -> int:
	return _hop_count


func get_debug() -> Dictionary:
	return {"id": ID, "steps": _steps, "target": _target, "warn_left": get_hop_warn_left(), "hops": _hop_count}


func teardown() -> void:
	if _state != null and _state.cell_changed.is_connected(_on_cell_changed):
		_state.cell_changed.disconnect(_on_cell_changed)
	if _mover != null and _mover.step_lock_fn == Callable(self, "_is_locked"):
		_mover.step_lock_fn = _prev_lock
	_mover = null
	_prev_lock = Callable()
	_state = null
	_target = _NONE
	super()


# The boss mover's step lock: the previous lock OR a hop being announced.
func _is_locked() -> bool:
	if _target != _NONE:
		return true
	return _prev_lock.is_valid() and bool(_prev_lock.call())


func _on_cell_changed(side: int, _old_cell: Vector2i, _new_cell: Vector2i) -> void:
	if side == CombatState.Side.ENEMY and not _moving:
		_steps += 1


# True when the boss could take a step now (ready, not casting, active).
func _can_move() -> bool:
	var boss: BossController = get_context().get("boss") as BossController
	if boss == null or _state == null or _state.is_enemy_dead() or not boss.is_active():
		return false
	if boss.get_actor() != null and boss.get_actor().is_swinging():
		return false
	return _mover == null or _mover.get_cooldown_remaining() <= 0.0


func _pick_target() -> Vector2i:
	var over_blocked: Array[Vector2i] = []
	var plain: Array[Vector2i] = []
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	if grid == null:
		return _NONE
	var from: Vector2i = _state.enemy_cell
	for dir: Vector2i in _DIRS:
		var mid: Vector2i = from + dir
		var dest: Vector2i = from + dir * 2
		if not grid.is_enemy_cell(mid) or not _is_steppable(dest):
			continue
		if _is_steppable(mid):
			plain.append(dest)
		else:
			over_blocked.append(dest)
	var pool: Array[Vector2i] = over_blocked if not over_blocked.is_empty() else plain
	if pool.is_empty():
		return _NONE
	return pool[rng.randi_range(0, pool.size() - 1)]


func _is_steppable(cell: Vector2i) -> bool:
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	if grid == null or not grid.is_enemy_cell(cell):
		return false
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if status != null and (status.is_hole(CombatState.Side.ENEMY, cell) or not status.thorns_at(CombatState.Side.ENEMY, cell).is_empty()):
		return false
	var hazards: TileHazards = get_context().get("hazards") as TileHazards
	if hazards != null and (hazards.is_sanded(CombatState.Side.ENEMY, cell) or hazards.is_sand_warning(CombatState.Side.ENEMY, cell)):
		return false
	return _mover == null or not _mover.is_cell_blocked(cell)


func _land() -> void:
	var target: Vector2i = _target
	_target = _NONE
	_warn_left = 0.0
	if _state == null or _state.is_enemy_dead():
		return
	if not _is_landable(target):
		return  # re-picked on a later tick (still armed)
	var from: Vector2i = _state.enemy_cell
	_moving = true
	var ok: bool = _state.set_enemy_cell(target)
	_moving = false
	if ok:
		_steps = 0
		_hop_count += 1
		hopped.emit(from, target)


# The destination is landable: steppable for the boss (thorns allowed: a thorned cell is still steppable).
func _is_landable(cell: Vector2i) -> bool:
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	if grid == null or not grid.is_enemy_cell(cell):
		return false
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if status != null and status.is_hole(CombatState.Side.ENEMY, cell):
		return false
	var hazards: TileHazards = get_context().get("hazards") as TileHazards
	if hazards != null and hazards.is_sanded(CombatState.Side.ENEMY, cell):
		return false
	return _mover == null or not _mover.is_cell_blocked(cell)

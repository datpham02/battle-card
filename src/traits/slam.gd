class_name SlamTrait
extends BossTrait
## Trait `slam` (OSFE TileType Cracked): every `slam_interval_sec` the boss slams the floor:
## `cracked_cells` seeded-random cells of the PLAYER's half (never the player's current cell, never
## an already cracked/announced one) are announced for `warning_sec`, then crack for `crack_sec`.
## A cracked cell cannot be stepped onto (this trait installs [method is_cracked] as the
## player's UnitMover.blocked_cell_fn) and expires after `crack_sec`; the player, if standing on
## a cell at the moment it cracks, takes `slam_damage` once. A CrackField owns the timers.
## Params (fallbacks below): `slam_interval_sec`, `cracked_cells`, `crack_sec`, `warning_sec`,
## `slam_damage`, `first_delay_sec` (default = the interval).
## HUD: [method get_cracked_cells], [method get_warning_cells].
## Implements: Story 023 (Part B).

## Cells were announced.
signal slam_warned(cells: Array[Vector2i])
## Cells cracked; [param damaged] = the player stood on one and took slam_damage.
signal slam_landed(cells: Array[Vector2i], damaged: bool)

const ID: String = "slam"
const DEFAULT_INTERVAL_SEC: float = 7.0
const DEFAULT_CRACKED_CELLS: int = 2
const DEFAULT_CRACK_SEC: float = 4.0
const DEFAULT_WARNING_SEC: float = 0.8
const DEFAULT_SLAM_DAMAGE: float = 20.0
const _SEED_OFFSET: int = 3571

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _cell_count: int = DEFAULT_CRACKED_CELLS
var _crack_sec: float = DEFAULT_CRACK_SEC
var _warning_sec: float = DEFAULT_WARNING_SEC
var _slam_damage: float = DEFAULT_SLAM_DAMAGE
var _first_delay_sec: float = DEFAULT_INTERVAL_SEC
var _timer: float = DEFAULT_INTERVAL_SEC
var _field: CrackField = CrackField.new()
var _slam_count: int = 0
var _mover: UnitMover = null


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_interval_sec = maxf(param_float("slam_interval_sec", DEFAULT_INTERVAL_SEC), 0.1)
	_cell_count = maxi(param_int("cracked_cells", DEFAULT_CRACKED_CELLS), 1)
	_crack_sec = maxf(param_float("crack_sec", DEFAULT_CRACK_SEC), 0.0)
	_warning_sec = maxf(param_float("warning_sec", DEFAULT_WARNING_SEC), 0.0)
	_slam_damage = maxf(param_float("slam_damage", DEFAULT_SLAM_DAMAGE), 0.0)
	_first_delay_sec = maxf(param_float("first_delay_sec", _interval_sec), 0.0)
	_timer = _first_delay_sec
	_field.cracked.connect(_on_cracked)


func on_match_start() -> void:
	_timer = _first_delay_sec
	_slam_count = 0
	_field.clear()
	_mover = get_context().get("player_mover") as UnitMover
	if _mover != null:
		_mover.blocked_cell_fn = Callable(self, "is_cracked")


func on_tick(step: float) -> void:
	_field.tick(step)
	_timer -= step
	if _timer > 0.0:
		return
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	var state: CombatState = get_context().get("state") as CombatState
	if grid == null or state == null:
		return
	var free: Array[Vector2i] = []
	for cell: Vector2i in grid.player_cells():
		if cell != state.player_cell and not _field.is_cracked(cell) and not _field.is_warned(cell):
			free.append(cell)
	var picked: Array[Vector2i] = []
	while picked.size() < _cell_count and not free.is_empty():
		var index: int = rng.randi_range(0, free.size() - 1)
		picked.append(free[index])
		free.remove_at(index)
	_timer = _interval_sec
	if picked.is_empty():
		return
	_slam_count += 1
	_field.announce(picked, _warning_sec, _crack_sec)
	slam_warned.emit(picked)


## True while [param cell] is cracked (the player's mover refuses to step onto it).
func is_cracked(cell: Vector2i) -> bool:
	return _field.is_cracked(cell)


## Cracked cells now.
func get_cracked_cells() -> Array[Vector2i]:
	return _field.get_cracked_cells()


## Announced (about to crack) cells now.
func get_warning_cells() -> Array[Vector2i]:
	return _field.get_warning_cells()


## Seconds until the next slam starts (0 when due).
func get_next_slam_left() -> float:
	return maxf(_timer, 0.0)


## Slams started so far this match.
func get_slam_count() -> int:
	return _slam_count


func get_debug() -> Dictionary:
	return {
		"id": ID, "cracked": _field.get_cracked_cells().size(), "warning": _field.get_warning_cells().size(),
		"next_slam_left": get_next_slam_left(), "slams": _slam_count,
	}


func teardown() -> void:
	if _mover != null and _mover.blocked_cell_fn == Callable(self, "is_cracked"):
		_mover.blocked_cell_fn = Callable()
	_mover = null
	_field.clear()
	if _field.cracked.is_connected(_on_cracked):
		_field.cracked.disconnect(_on_cracked)
	super()


# Cells just cracked: a player standing on one takes the slam damage once.
func _on_cracked(cells: Array[Vector2i]) -> void:
	var state: CombatState = get_context().get("state") as CombatState
	var damaged: bool = state != null and cells.has(state.player_cell)
	if damaged:
		state.damage_player(_slam_damage)
	slam_landed.emit(cells, damaged)

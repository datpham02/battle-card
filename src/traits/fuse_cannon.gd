class_name FuseCannonTrait
extends BossTrait
## Trait `fuse_cannon` (OSFE Chargecannon): a fuse counts down `fuse_sec` of simulation time from
## match start (the HUD bar reads [method get_fuse_left]). At 0 the cannon announces the player's
## row for `warn_sec` (HUD reads [method get_warning_cells]); when the warning ends it deals
## `fuse_damage` to the player IF the player's cell, at that moment, is still in the row; then
## the fuse restarts. A SINGLE player hit on the boss of at least `interrupt_damage` resets the
## fuse to full (ignored while the warning runs: the shot is already loaded).
## Params (fallbacks below): `fuse_sec`, `fuse_damage`, `interrupt_damage`, `row_scope`
## (`player_row` = the row the player stands on when the warning starts, or `random`), `warn_sec`.
## Implements: Story 023 (Part A).

## The row was announced (real cells of the player's half).
signal blast_warned(cells: Array[Vector2i])
## The blast resolved: [param hit] = the player stood in the row and took the damage.
signal blast_fired(cells: Array[Vector2i], hit: bool)
## The fuse was reset by a big enough hit.
signal fuse_interrupted

const ID: String = "fuse_cannon"
const DEFAULT_FUSE_SEC: float = 12.0
const DEFAULT_FUSE_DAMAGE: float = 40.0
const DEFAULT_INTERRUPT_DAMAGE: float = 30.0
const DEFAULT_WARN_SEC: float = 0.6
const SCOPE_PLAYER_ROW: String = "player_row"
const SCOPE_RANDOM: String = "random"
const DEFAULT_ROW_SCOPE: String = SCOPE_PLAYER_ROW
const _SEED_OFFSET: int = 9901

var _fuse_sec: float = DEFAULT_FUSE_SEC
var _fuse_damage: float = DEFAULT_FUSE_DAMAGE
var _interrupt_damage: float = DEFAULT_INTERRUPT_DAMAGE
var _warn_sec: float = DEFAULT_WARN_SEC
var _row_scope: String = DEFAULT_ROW_SCOPE
var _fuse_left: float = DEFAULT_FUSE_SEC
var _warn_left: float = 0.0
var _warning_cells: Array[Vector2i] = []
var _blast_count: int = 0
var _interrupt_count: int = 0


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_fuse_sec = maxf(param_float("fuse_sec", DEFAULT_FUSE_SEC), 0.1)
	_fuse_damage = maxf(param_float("fuse_damage", DEFAULT_FUSE_DAMAGE), 0.0)
	_interrupt_damage = maxf(param_float("interrupt_damage", DEFAULT_INTERRUPT_DAMAGE), 0.0)
	_warn_sec = maxf(param_float("warn_sec", DEFAULT_WARN_SEC), 0.0)
	_row_scope = param_string("row_scope", DEFAULT_ROW_SCOPE)
	if _row_scope != SCOPE_PLAYER_ROW and _row_scope != SCOPE_RANDOM:
		push_warning("FuseCannonTrait: unknown row_scope '%s', using %s" % [_row_scope, DEFAULT_ROW_SCOPE])
		_row_scope = DEFAULT_ROW_SCOPE
	_fuse_left = _fuse_sec


func on_match_start() -> void:
	_fuse_left = _fuse_sec
	_warn_left = 0.0
	_warning_cells = []
	_blast_count = 0
	_interrupt_count = 0


func on_tick(step: float) -> void:
	if not _warning_cells.is_empty():
		_warn_left -= step
		if _warn_left <= 0.0:
			_resolve()
		return
	_fuse_left -= step
	if _fuse_left > 0.0:
		return
	_fuse_left = 0.0
	var cells: Array[Vector2i] = _pick_row()
	if cells.is_empty():
		return
	_warning_cells = cells
	_warn_left = _warn_sec
	blast_warned.emit(cells)
	if _warn_sec <= 0.0:
		_resolve()


func on_boss_damaged(amount: float) -> void:
	if not _warning_cells.is_empty() or amount < _interrupt_damage:
		return
	_fuse_left = _fuse_sec
	_interrupt_count += 1
	fuse_interrupted.emit()


## Seconds left on the fuse (0 while the blast warning runs).
func get_fuse_left() -> float:
	return maxf(_fuse_left, 0.0)


## Full fuse length in seconds (HUD bar denominator).
func get_fuse_sec() -> float:
	return _fuse_sec


## Cells of the announced row (empty when no warning runs).
func get_warning_cells() -> Array[Vector2i]:
	return _warning_cells.duplicate()


## Seconds until the announced blast resolves (0 when none).
func get_warn_left() -> float:
	return maxf(_warn_left, 0.0) if not _warning_cells.is_empty() else 0.0


## Blasts resolved so far this match.
func get_blast_count() -> int:
	return _blast_count


## Fuse resets by a big hit so far this match.
func get_interrupt_count() -> int:
	return _interrupt_count


func get_debug() -> Dictionary:
	return {
		"id": ID, "fuse_left": get_fuse_left(), "fuse_sec": _fuse_sec, "warn_left": get_warn_left(),
		"blasts": _blast_count, "interrupts": _interrupt_count,
	}


func teardown() -> void:
	_warning_cells = []
	super()


func _resolve() -> void:
	var state: CombatState = get_context().get("state") as CombatState
	var cells: Array[Vector2i] = _warning_cells
	_warning_cells = []
	_warn_left = 0.0
	_fuse_left = _fuse_sec
	var hit: bool = state != null and cells.has(state.player_cell)
	if hit:
		state.damage_player(_fuse_damage)
	_blast_count += 1
	blast_fired.emit(cells, hit)


# Real cells of the chosen row of the player's half.
func _pick_row() -> Array[Vector2i]:
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	var state: CombatState = get_context().get("state") as CombatState
	var out: Array[Vector2i] = []
	if grid == null or state == null:
		return out
	var row: int = state.player_cell.y
	if _row_scope == SCOPE_RANDOM:
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

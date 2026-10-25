class_name RottenThrowerTrait
extends BossTrait
## Trait `rotten_thrower`: every `interval_sec` of simulation time the boss throws one ROTTEN
## point onto a random (seeded) free, non-burning cell of the player's half that is not the
## player's cell. A rotten point lies on the field like any point (it rots away after
## `field_freshness_sec`), can be picked up into the hand where it occupies a slot but can never
## be selected or cut, and leaves the hand on its own after `rot_in_hand_sec` (HoldSlots.tick_rot).
## At most `max_on_field` rotten points lie on the field at once: when the cap is reached the
## throw waits (no catch-up burst) and happens as soon as a rotten point leaves the field.
## Params (chapters.json `traits[].params`, defaults in the constants below): `interval_sec`,
## `field_freshness_sec`, `rot_in_hand_sec`, `label`, `max_on_field`, `first_delay_sec`.
## Story 024: when the player's drops are in piece mode the throw is a ROTTEN PIECE (1 cell, grey,
## FieldPoint.piece.is_rotten(), never placeable) via FieldDrops.place_rotten_piece; `label` is then unused.
## Implements: Story 014 (Part B), Story 024.

## A rotten point was thrown onto the player's half (FieldDrops.point_spawned fires too).
signal thrown(point: FieldPoint)

const ID: String = "rotten_thrower"
const DEFAULT_INTERVAL_SEC: float = 6.0
const DEFAULT_FIELD_FRESHNESS_SEC: float = 5.0
const DEFAULT_ROT_IN_HAND_SEC: float = 6.0
const DEFAULT_LABEL: String = "X"
const DEFAULT_MAX_ON_FIELD: int = 1
const DEFAULT_FIRST_DELAY_SEC: float = 3.0
const _SEED_OFFSET: int = 4201

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _field_freshness_sec: float = DEFAULT_FIELD_FRESHNESS_SEC
var _rot_in_hand_sec: float = DEFAULT_ROT_IN_HAND_SEC
var _label: String = DEFAULT_LABEL
var _max_on_field: int = DEFAULT_MAX_ON_FIELD
var _first_delay_sec: float = DEFAULT_FIRST_DELAY_SEC
## Seconds until the next throw; <= 0 = a throw is due (waits for a free cell / the cap).
var _timer: float = 0.0
var _last_thrown_cell: Vector2i = BoardGrid.NO_CELL
var _throw_count: int = 0


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_interval_sec = maxf(param_float("interval_sec", DEFAULT_INTERVAL_SEC), 0.0)
	_field_freshness_sec = maxf(param_float("field_freshness_sec", DEFAULT_FIELD_FRESHNESS_SEC), 0.0)
	_rot_in_hand_sec = maxf(param_float("rot_in_hand_sec", DEFAULT_ROT_IN_HAND_SEC), 0.0)
	_label = param_string("label", DEFAULT_LABEL)
	_max_on_field = maxi(param_int("max_on_field", DEFAULT_MAX_ON_FIELD), 1)
	_first_delay_sec = maxf(param_float("first_delay_sec", DEFAULT_FIRST_DELAY_SEC), 0.0)


func on_match_start() -> void:
	_timer = _first_delay_sec
	_last_thrown_cell = BoardGrid.NO_CELL
	_throw_count = 0


func on_tick(step: float) -> void:
	_timer -= step
	if _timer > 0.0:
		return
	var drops: FieldDrops = get_context().get("player_drops") as FieldDrops
	var state: CombatState = get_context().get("state") as CombatState
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if drops == null or state == null or grid == null:
		return
	if _rotten_on_field(drops) >= _max_on_field:
		return
	var candidates: Array[Vector2i] = _free_cells(grid, state, drops, status)
	if candidates.is_empty():
		return
	var cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	var point: FieldPoint
	if drops.is_piece_mode():
		# Story 024: the player's drops carry pieces, so the lie is a 1-cell grey piece.
		point = drops.place_rotten_piece(cell, _field_freshness_sec, _rot_in_hand_sec)
	else:
		point = drops.place_rotten(cell, _label, _field_freshness_sec, _rot_in_hand_sec)
	if point == null:
		return
	_last_thrown_cell = cell
	_throw_count += 1
	_timer = _interval_sec
	thrown.emit(point)


## Cell of the last thrown rotten point (BoardGrid.NO_CELL before the first throw).
func get_last_thrown_cell() -> Vector2i:
	return _last_thrown_cell


## Seconds until the next throw is due (0 when one is pending).
func get_next_throw_left() -> float:
	return maxf(_timer, 0.0)


## Rotten points thrown so far this match.
func get_throw_count() -> int:
	return _throw_count


func get_debug() -> Dictionary:
	return {
		"id": ID, "next_throw_left": get_next_throw_left(), "last_cell": _last_thrown_cell,
		"throws": _throw_count,
	}


func teardown() -> void:
	_last_thrown_cell = BoardGrid.NO_CELL
	super()


# Free real cells of the player's half: no point, not burning, not the player's cell.
func _free_cells(grid: BoardGrid, state: CombatState, drops: FieldDrops, status: StatusEffects) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for point: FieldPoint in drops.get_points():
		occupied.append(point.cell)
	var out: Array[Vector2i] = []
	for cell: Vector2i in grid.player_cells():
		if cell == state.player_cell or occupied.has(cell):
			continue
		if status != null and status.is_burning(cell):
			continue
		out.append(cell)
	return out


func _rotten_on_field(drops: FieldDrops) -> int:
	var count: int = 0
	for point: FieldPoint in drops.get_points():
		if point.rotten:
			count += 1
	return count

class_name SporeBurstTrait
extends BossTrait
## Trait `spore_burst` (Story 036 Part B, Nam Bao Tu / spore_cap): every time the boss is hit (on_boss_damaged,
## amount > 0) it spreads timed mire over the player's cell plus up to `spread_cells` real neighbours of the
## player's half (seeded order) for `spore_mire_sec`, then waits `icd_sec` before it can burst again. Many small
## hits turn the player's half into a bog: it rewards few, heavy casts.
## Reaches the hazards through ctx `hazards` (TileHazards.add_mire); without it the trait does nothing.
## Params (chapters.json, fallbacks below): `spread_cells`, `spore_mire_sec`, `icd_sec`.
## Implements: Story 036 (Part B).

## Mire was spread on the player's half.
signal spores_spread(cells: Array[Vector2i])

const ID: String = "spore_burst"
const DEFAULT_SPREAD_CELLS: int = 2
const DEFAULT_SPORE_MIRE_SEC: float = 4.0
const DEFAULT_ICD_SEC: float = 1.5
const _SEED_OFFSET: int = 9137
const _DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var _spread_cells: int = DEFAULT_SPREAD_CELLS
var _mire_sec: float = DEFAULT_SPORE_MIRE_SEC
var _icd_sec: float = DEFAULT_ICD_SEC
var _icd_left: float = 0.0
var _burst_count: int = 0
var _last_cells: Array[Vector2i] = []


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_spread_cells = maxi(param_int("spread_cells", DEFAULT_SPREAD_CELLS), 0)
	_mire_sec = maxf(param_float("spore_mire_sec", DEFAULT_SPORE_MIRE_SEC), 0.0)
	_icd_sec = maxf(param_float("icd_sec", DEFAULT_ICD_SEC), 0.0)


func on_match_start() -> void:
	_icd_left = 0.0
	_burst_count = 0
	_last_cells = []


func on_tick(step: float) -> void:
	_icd_left = maxf(_icd_left - step, 0.0)


func on_boss_damaged(amount: float) -> void:
	if amount <= 0.0 or _icd_left > 0.0 or _mire_sec <= 0.0:
		return
	var hazards: TileHazards = get_hazards()
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	var state: CombatState = get_context().get("state") as CombatState
	if hazards == null or grid == null or state == null:
		return
	var cells: Array[Vector2i] = [state.player_cell]
	var around: Array[Vector2i] = []
	for dir: Vector2i in _DIRS:
		if grid.is_player_cell(state.player_cell + dir):
			around.append(state.player_cell + dir)
	while cells.size() < _spread_cells + 1 and not around.is_empty():
		var index: int = rng.randi_range(0, around.size() - 1)
		cells.append(around[index])
		around.remove_at(index)
	hazards.add_mire(CombatState.Side.PLAYER, cells, _mire_sec)
	_icd_left = _icd_sec
	_burst_count += 1
	_last_cells = cells.duplicate()
	spores_spread.emit(cells)


## Bursts so far this match.
func get_burst_count() -> int:
	return _burst_count


## Cells of the last burst (empty before the first).
func get_last_cells() -> Array[Vector2i]:
	return _last_cells.duplicate()


## Seconds until a hit can burst again (0 = ready).
func get_icd_left() -> float:
	return _icd_left


func get_debug() -> Dictionary:
	return {"id": ID, "bursts": _burst_count, "icd_left": _icd_left}


func teardown() -> void:
	_last_cells = []
	super()

class_name ThornFieldTrait
extends BossTrait
## Trait `thorn_field` (Story 027 Phan C): when the boss STARTS a swing of at least `min_swing_cells`
## cells, it lays a Tran gai (thorns) over the player's escape cells next to the swing: cells of the
## player's half that the swing does not cover, that touch a swing cell (4-neighbour) and that the player
## can reach within `escape_steps` steps (never the player's own cell), nearest the player first (then x,
## then y), at most `max_cells`. Thorns stay steppable (the player may pay to dodge), so no
## leave-a-path reduction applies; they are formed through ZoneRules.cast_thorns. After a field,
## `cooldown_sec` must pass before the next one (0 = every qualifying swing). Thorn numbers: `thorn_sec`,
## `thorn_damage`, `fragile_stacks`, defaults from CombatConfig.zone_numbers() (combat.json `zones`).
## Deterministic: no randomness is used.
## Params (chapters.json, fallbacks in the constants below): `min_swing_cells`, `max_cells`,
## `escape_steps`, `cooldown_sec`, `thorn_sec`, `thorn_damage`, `fragile_stacks`.
## Implements: Story 027 (Phan C), design/game-brief.md v5 "Vung: Ket gioi va Tran gai".

## Thorns were laid on the player's half.
signal thorns_laid(cells: Array[Vector2i])

const ID: String = "thorn_field"
const DEFAULT_MIN_SWING_CELLS: int = 4
const DEFAULT_MAX_CELLS: int = 3
const DEFAULT_ESCAPE_STEPS: int = 2
const DEFAULT_COOLDOWN_SEC: float = 0.0
const _SEED_OFFSET: int = 8461

var _min_swing_cells: int = DEFAULT_MIN_SWING_CELLS
var _max_cells: int = DEFAULT_MAX_CELLS
var _escape_steps: int = DEFAULT_ESCAPE_STEPS
var _cooldown_sec: float = DEFAULT_COOLDOWN_SEC
var _thorn_sec: float = 0.0
var _thorn_damage: float = 0.0
var _fragile_stacks: int = 0
var _cooldown_left: float = 0.0
var _field_count: int = 0
var _last_cells: Array[Vector2i] = []


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	var zones: Dictionary = SealCasterTrait.zone_numbers_from(ctx)
	_min_swing_cells = maxi(param_int("min_swing_cells", DEFAULT_MIN_SWING_CELLS), 1)
	_max_cells = maxi(param_int("max_cells", DEFAULT_MAX_CELLS), 1)
	_escape_steps = maxi(param_int("escape_steps", DEFAULT_ESCAPE_STEPS), 1)
	_cooldown_sec = maxf(param_float("cooldown_sec", DEFAULT_COOLDOWN_SEC), 0.0)
	_thorn_sec = maxf(param_float("thorn_sec", float(zones["thorn_sec"])), 0.0)
	_thorn_damage = maxf(param_float("thorn_damage", float(zones["thorn_damage"])), 0.0)
	_fragile_stacks = maxi(param_int("fragile_stacks", int(zones["thorn_fragile_stacks"])), 0)


func on_match_start() -> void:
	_cooldown_left = 0.0
	_field_count = 0
	_last_cells = []


func on_tick(step: float) -> void:
	_cooldown_left = maxf(_cooldown_left - step, 0.0)


func on_boss_swing_started(cells: Array[Vector2i], _skill_id: String) -> void:
	if cells.size() < _min_swing_cells or _cooldown_left > 0.0 or _thorn_sec <= 0.0:
		return
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if status == null:
		return
	var picked: Array[Vector2i] = _pick_cells(cells)
	if picked.is_empty():
		return
	var laid: Array[Vector2i] = ZoneRules.cast_thorns(
		status, CombatState.Side.PLAYER, picked, _thorn_sec, _thorn_damage, _fragile_stacks
	)
	_cooldown_left = _cooldown_sec
	_field_count += 1
	_last_cells = laid.duplicate()
	thorns_laid.emit(laid)


## Thorn fields laid so far this match.
func get_field_count() -> int:
	return _field_count


## Cells of the last field (empty before the first).
func get_last_cells() -> Array[Vector2i]:
	return _last_cells.duplicate()


## Seconds until a swing may lay thorns again (0 = ready).
func get_cooldown_left() -> float:
	return _cooldown_left


func get_debug() -> Dictionary:
	return {"id": ID, "fields": _field_count, "cooldown_left": _cooldown_left}


func teardown() -> void:
	_last_cells = []
	super()


# The player's escape cells next to [param swing] (see the class doc), at most max_cells.
func _pick_cells(swing: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	var state: CombatState = get_context().get("state") as CombatState
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if grid == null or state == null or status == null:
		return out
	var mover: UnitMover = get_context().get("player_mover") as UnitMover
	var blocked: Array[Vector2i] = SealCasterTrait.blocked_player_cells(grid, status, mover)
	var player_cell: Vector2i = state.player_cell
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in EscapeAnalysis.escape_cells(grid, player_cell, _escape_steps, true, swing, blocked):
		if cell != player_cell and _touches(cell, swing):
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var na: int = absi(a.x - player_cell.x) + absi(a.y - player_cell.y)
		var nb: int = absi(b.x - player_cell.x) + absi(b.y - player_cell.y)
		if na != nb:
			return na < nb
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	for i: int in mini(_max_cells, candidates.size()):
		out.append(candidates[i])
	return out


static func _touches(cell: Vector2i, swing: Array[Vector2i]) -> bool:
	for dir: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if swing.has(cell + dir):
			return true
	return false

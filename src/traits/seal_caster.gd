class_name SealCasterTrait
extends BossTrait
## Trait `seal_caster` (Story 027 Phan C): every `interval_sec` the boss gets ARMED; the next boss swing
## of at least `min_swing_cells` cells then places a Ket gioi (seal) of `cells_min`..`cells_max` cells
## (seeded count) on the PLAYER's half when that swing has `lead_sec` or less left (at once for a shorter
## swing), so the seal is up when the blow lands. The cells are the player's escape cells: cells the
## player could reach within `escape_steps` steps that the swing does NOT cover (never the player's own
## cell), nearest first (seeded order among equally near cells). At least one escape cell is always left
## open (cells are dropped from the pick until one remains), and the seal goes through
## ZoneRules.cast_seal, the single code point that applies the "leave a path" rule (fit_cells), so the
## player is never trapped. Seal duration: `seal_sec`, default CombatConfig.zone_numbers().seal_sec
## (combat.json `zones`). No escape cell to seal = nothing placed, the trait stays armed for the next swing.
## Params (chapters.json, fallbacks in the constants below): `interval_sec`, `first_delay_sec` (default =
## the interval), `cells_min`, `cells_max`, `lead_sec`, `min_swing_cells`, `escape_steps`, `seal_sec`.
## Implements: Story 027 (Phan C), design/game-brief.md v5 "Vung: Ket gioi va Tran gai".

## A seal was placed on the player's half: the cells actually sealed (after the leave-a-path rule).
signal seal_cast(cells: Array[Vector2i])

const ID: String = "seal_caster"
const DEFAULT_INTERVAL_SEC: float = 8.0
const DEFAULT_CELLS_MIN: int = 2
const DEFAULT_CELLS_MAX: int = 3
const DEFAULT_LEAD_SEC: float = 0.6
const DEFAULT_MIN_SWING_CELLS: int = 3
const DEFAULT_ESCAPE_STEPS: int = 2
const _SEED_OFFSET: int = 7919

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _first_delay_sec: float = DEFAULT_INTERVAL_SEC
var _cells_min: int = DEFAULT_CELLS_MIN
var _cells_max: int = DEFAULT_CELLS_MAX
var _lead_sec: float = DEFAULT_LEAD_SEC
var _min_swing_cells: int = DEFAULT_MIN_SWING_CELLS
var _escape_steps: int = DEFAULT_ESCAPE_STEPS
var _seal_sec: float = 0.0
## Seconds until the trait is armed again (<= 0 = armed).
var _timer: float = DEFAULT_INTERVAL_SEC
## True once the current boss swing has been handled (one try per swing).
var _swing_handled: bool = false
var _seal_count: int = 0
var _last_cells: Array[Vector2i] = []


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	var zones: Dictionary = zone_numbers_from(ctx)
	_interval_sec = maxf(param_float("interval_sec", DEFAULT_INTERVAL_SEC), 0.1)
	_first_delay_sec = maxf(param_float("first_delay_sec", _interval_sec), 0.0)
	_cells_min = maxi(param_int("cells_min", DEFAULT_CELLS_MIN), 1)
	_cells_max = maxi(param_int("cells_max", DEFAULT_CELLS_MAX), _cells_min)
	_lead_sec = maxf(param_float("lead_sec", DEFAULT_LEAD_SEC), 0.0)
	_min_swing_cells = maxi(param_int("min_swing_cells", DEFAULT_MIN_SWING_CELLS), 1)
	_escape_steps = maxi(param_int("escape_steps", DEFAULT_ESCAPE_STEPS), 1)
	_seal_sec = maxf(param_float("seal_sec", float(zones["seal_sec"])), 0.0)
	_timer = _first_delay_sec


## Story 027 zone numbers for a trait: the context's `combat_config` (CombatConfig) when present, else
## combat.json through CombatConfig.load_from_file(). Keys of CombatConfig.zone_numbers().
static func zone_numbers_from(ctx: Dictionary) -> Dictionary:
	var config: CombatConfig = ctx.get("combat_config") as CombatConfig
	if config == null:
		config = CombatConfig.load_from_file()
	return config.zone_numbers()


func on_match_start() -> void:
	_timer = _first_delay_sec
	_swing_handled = false
	_seal_count = 0
	_last_cells = []


func on_tick(step: float) -> void:
	_timer -= step
	var boss: BossController = get_context().get("boss") as BossController
	if boss == null:
		return
	var actor: CutActor = boss.get_actor()
	if actor == null or not actor.is_swinging() or actor.targets_enemy():
		_swing_handled = false
		return
	if _timer > 0.0 or _swing_handled:
		return
	var swing: Array[Vector2i] = actor.get_cells()
	if swing.size() < _min_swing_cells or actor.get_time_left() > _lead_sec:
		return
	_swing_handled = true
	var placed: Array[Vector2i] = _cast(swing)
	if placed.is_empty():
		return
	_timer = _interval_sec
	_seal_count += 1
	_last_cells = placed.duplicate()
	seal_cast.emit(placed)


## True while the next qualifying boss swing will place a seal.
func is_armed() -> bool:
	return _timer <= 0.0


## Seconds until the trait is armed (0 when armed).
func get_next_seal_left() -> float:
	return maxf(_timer, 0.0)


## Seals placed so far this match.
func get_seal_count() -> int:
	return _seal_count


## Cells of the last seal placed (empty before the first).
func get_last_cells() -> Array[Vector2i]:
	return _last_cells.duplicate()


func get_debug() -> Dictionary:
	return {"id": ID, "armed": is_armed(), "next_seal_left": get_next_seal_left(), "seals": _seal_count}


func teardown() -> void:
	_last_cells = []
	super()


# Picks the escape cells to seal around [param swing] and forms the seal; returns the cells sealed.
func _cast(swing: Array[Vector2i]) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	var state: CombatState = get_context().get("state") as CombatState
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if grid == null or state == null or status == null or _seal_sec <= 0.0:
		return none
	var mover: UnitMover = get_context().get("player_mover") as UnitMover
	var extra_blocked: Callable = Callable()
	if mover != null:
		extra_blocked = Callable(mover, "is_cell_blocked")
	var blocked: Array[Vector2i] = blocked_player_cells(grid, status, mover)
	var player_cell: Vector2i = state.player_cell
	var escape: Array[Vector2i] = EscapeAnalysis.escape_cells(grid, player_cell, _escape_steps, true, swing, blocked)
	escape.erase(player_cell)
	if escape.size() < 2:
		return none
	# Nearest first; a seeded rank breaks ties between equally near cells.
	var ranked: Array[Dictionary] = []
	for cell: Vector2i in escape:
		var near: int = absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y)
		ranked.append({"cell": cell, "near": near, "roll": rng.randi()})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["near"]) != int(b["near"]):
			return int(a["near"]) < int(b["near"])
		return int(a["roll"]) < int(b["roll"]))
	var count: int = mini(rng.randi_range(_cells_min, _cells_max), escape.size() - 1)
	var picked: Array[Vector2i] = []
	for i: int in count:
		picked.append(ranked[i]["cell"] as Vector2i)
	# Leave the player at least one escape cell outside the swing.
	while not picked.is_empty():
		var with_seal: Array[Vector2i] = blocked.duplicate()
		with_seal.append_array(picked)
		var left: Array[Vector2i] = EscapeAnalysis.escape_cells(grid, player_cell, _escape_steps, true, swing, with_seal)
		left.erase(player_cell)
		if not left.is_empty():
			break
		picked.pop_back()
	if picked.is_empty():
		return none
	return ZoneRules.cast_seal(state, grid, status, CombatState.Side.PLAYER, picked, _seal_sec, extra_blocked)


## Cells of the player's half the player cannot step into now: sealed cells plus whatever
## [param mover] (the player's UnitMover, may be null) refuses (cracks...). Shared with ThornFieldTrait.
static func blocked_player_cells(grid: BoardGrid, status: StatusEffects, mover: UnitMover) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in grid.player_cells():
		if status.is_sealed(CombatState.Side.PLAYER, cell) or (mover != null and mover.is_cell_blocked(cell)):
			out.append(cell)
	return out

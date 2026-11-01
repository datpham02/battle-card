class_name SealCasterTrait
extends BossTrait
## Trait `seal_caster` (Ấn phong tỏa), drop tile version (Ô rớt, design/quick-specs/o-rot-thay-tuong-2026-10-31.md,
## ADR-0001 A5). Rhythm as Story 027 Phan C: every `interval_sec` the boss gets ARMED; the next boss swing of at least
## `min_swing_cells` cells, once it has `lead_sec` or less left (at once for a shorter swing), makes `cells_min`..
## `cells_max` cells (seeded count) of the PLAYER's half CRACK (rule 3: `hole_warn_sec` warning, still enterable and
## leavable), then FALL and stay a hole for `seal_sec` (rule 4), then return. A unit on a cell when it falls drops to
## HP 0 (rule 5, StatusEffects; the player's death is the existing match loss).
## Cell choice (rule 2): the player's escape cells (reachable within `escape_steps` steps, outside the swing), nearest
## first, seeded order among equally near cells, AND the player's own cell (nearest of all) when
## `may_target_player_cell` is true and the player can step off in time (rule 6: ZoneRules.unit_cell_droppable: step
## cooldown left <= hole_warn_sec - hole_reaction_margin_sec, not Frozen, not rooted). At least one escape cell outside
## the swing is left open (picks are dropped until one remains), then ZoneRules.cast_drop applies the single fairness
## point (a safe, non-cracking, non-hole neighbour stays open; no safe neighbour = no cast).
## `may_target_player_cell` false = the old choice (escape cells only, never the player's cell).
## Nothing to crack = nothing placed, the trait stays armed for the next swing.
## Params (chapters.json, fallbacks in the constants below / combat.json `zones`): `interval_sec`, `first_delay_sec`
## (default = the interval), `cells_min`, `cells_max`, `lead_sec`, `min_swing_cells`, `escape_steps`, `seal_sec`
## (hole seconds, default zones.seal_sec), `hole_warn_sec` (default zones.hole_warn_sec),
## `hole_reaction_margin_sec` (default zones.hole_reaction_margin_sec), `may_target_player_cell` (default true).
## Implements: Story 027 (Phan C), design/quick-specs/o-rot-thay-tuong-2026-10-31.md rules 1-6.

## A drop tile started on the player's half: the cells that began cracking (after the fairness rules).
signal seal_cast(cells: Array[Vector2i])

const ID: String = "seal_caster"
const DEFAULT_INTERVAL_SEC: float = 8.0
const DEFAULT_CELLS_MIN: int = 2
const DEFAULT_CELLS_MAX: int = 3
const DEFAULT_LEAD_SEC: float = 0.6
const DEFAULT_MIN_SWING_CELLS: int = 3
const DEFAULT_ESCAPE_STEPS: int = 2
const DEFAULT_MAY_TARGET_PLAYER_CELL: bool = true
const _SEED_OFFSET: int = 7919

var _interval_sec: float = DEFAULT_INTERVAL_SEC
var _first_delay_sec: float = DEFAULT_INTERVAL_SEC
var _cells_min: int = DEFAULT_CELLS_MIN
var _cells_max: int = DEFAULT_CELLS_MAX
var _lead_sec: float = DEFAULT_LEAD_SEC
var _min_swing_cells: int = DEFAULT_MIN_SWING_CELLS
var _escape_steps: int = DEFAULT_ESCAPE_STEPS
var _seal_sec: float = 0.0
var _warn_sec: float = 0.0
var _margin_sec: float = 0.0
var _may_target_player_cell: bool = DEFAULT_MAY_TARGET_PLAYER_CELL
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
	_warn_sec = maxf(param_float("hole_warn_sec", float(zones["hole_warn_sec"])), 0.0)
	_margin_sec = clampf(param_float("hole_reaction_margin_sec", float(zones["hole_reaction_margin_sec"])), 0.0, _warn_sec)
	var raw_may: Variant = params.get("may_target_player_cell", DEFAULT_MAY_TARGET_PLAYER_CELL)
	if typeof(raw_may) == TYPE_BOOL:
		_may_target_player_cell = bool(raw_may)
	else:
		push_warning("SealCasterTrait: may_target_player_cell must be true or false, using %s" % DEFAULT_MAY_TARGET_PLAYER_CELL)
		_may_target_player_cell = DEFAULT_MAY_TARGET_PLAYER_CELL
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


## True while the next qualifying boss swing will start a drop tile.
func is_armed() -> bool:
	return _timer <= 0.0


## Seconds until the trait is armed (0 when armed).
func get_next_seal_left() -> float:
	return maxf(_timer, 0.0)


## Drop tiles started so far this match.
func get_seal_count() -> int:
	return _seal_count


## Cells of the last drop tile started (empty before the first).
func get_last_cells() -> Array[Vector2i]:
	return _last_cells.duplicate()


## The resolved knobs (tests / debug): {warn_sec, hole_sec, margin_sec, may_target_player_cell}.
func get_drop_numbers() -> Dictionary:
	return {"warn_sec": _warn_sec, "hole_sec": _seal_sec, "margin_sec": _margin_sec,
		"may_target_player_cell": _may_target_player_cell}


func get_debug() -> Dictionary:
	return {"id": ID, "armed": is_armed(), "next_seal_left": get_next_seal_left(), "seals": _seal_count}


func teardown() -> void:
	_last_cells = []
	super()


## Rule 6 (through ZoneRules.unit_cell_droppable): may the player's own cell be chosen right now? Always false with
## `may_target_player_cell` off.
func player_cell_droppable() -> bool:
	if not _may_target_player_cell:
		return false
	var status: StatusEffects = get_context().get("status") as StatusEffects
	var mover: UnitMover = get_context().get("player_mover") as UnitMover
	var frozen: bool = status != null and status.is_pinned(CombatState.Side.PLAYER)
	var rooted: bool = mover != null and mover.is_step_locked()
	var cooldown: float = mover.get_cooldown_remaining() if mover != null else 0.0
	return ZoneRules.unit_cell_droppable(cooldown, _warn_sec, _margin_sec, frozen, rooted)


# Picks the cells to crack around [param swing] and starts the drop tile; returns the cells that started cracking.
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
	# A cell already cracking will be a hole soon: never an escape cell (and never cracked twice).
	for cell: Vector2i in status.crack_cells(CombatState.Side.PLAYER):
		if not blocked.has(cell):
			blocked.append(cell)
	var player_cell: Vector2i = state.player_cell
	var escape: Array[Vector2i] = EscapeAnalysis.escape_cells(grid, player_cell, _escape_steps, true, swing, blocked)
	escape.erase(player_cell)
	var own_ok: bool = player_cell_droppable() and not status.is_cracking(CombatState.Side.PLAYER, player_cell)
	var pool: int = escape.size() + (1 if own_ok else 0)
	if pool < 2:
		return none
	# Nearest first (the player's own cell is distance 0); a seeded rank breaks ties between equally near cells.
	var ranked: Array[Dictionary] = []
	if own_ok:
		ranked.append({"cell": player_cell, "near": 0, "roll": 0})
	for cell: Vector2i in escape:
		var near: int = absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y)
		ranked.append({"cell": cell, "near": near, "roll": rng.randi()})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["near"]) != int(b["near"]):
			return int(a["near"]) < int(b["near"])
		return int(a["roll"]) < int(b["roll"]))
	var count: int = mini(rng.randi_range(_cells_min, _cells_max), pool - 1)
	var picked: Array[Vector2i] = []
	for i: int in count:
		picked.append(ranked[i]["cell"] as Vector2i)
	# Leave the player at least one escape cell outside the swing (the player's own cell is the start, not a step).
	while not picked.is_empty():
		var with_drop: Array[Vector2i] = blocked.duplicate()
		for cell: Vector2i in picked:
			if cell != player_cell:
				with_drop.append(cell)
		var left: Array[Vector2i] = EscapeAnalysis.escape_cells(grid, player_cell, _escape_steps, true, swing, with_drop)
		left.erase(player_cell)
		if not left.is_empty():
			break
		picked.pop_back()
	if picked.is_empty():
		return none
	return ZoneRules.cast_drop(state, grid, status, CombatState.Side.PLAYER, picked, _warn_sec, _seal_sec, own_ok, extra_blocked)


## Cells of the player's half the player cannot step into now: sealed cells plus whatever [param mover] (the player's
## UnitMover, may be null) refuses (slam cracks, sand, drop-tile holes...), and the open holes even without a mover.
## Shared with ThornFieldTrait. Cracking cells are still steppable, so they are not listed here.
static func blocked_player_cells(grid: BoardGrid, status: StatusEffects, mover: UnitMover) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in grid.player_cells():
		if status.is_hole(CombatState.Side.PLAYER, cell) \
				or (mover != null and mover.is_cell_blocked(cell)):
			out.append(cell)
	return out

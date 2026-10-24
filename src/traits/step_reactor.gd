class_name StepReactorTrait
extends BossTrait
## Trait `step_reactor` (OSFE Reacter): every successful PLAYER step gives the boss one charge;
## at `charges_to_fire` it fires at once a boss swing of `swing_cells` connected cells that
## includes the player's current cell, telegraphed for `warning_sec` through the normal boss
## swing pipeline (CutActor -> SwingArbiter), so it can be interrupted and dodged like any
## swing. Charges reset to 0 on firing; none are gained while `cooldown_sec` runs. Standing
## still never adds a charge. If the boss's actor is busy the shot waits (charges stay full)
## and fires the moment it is free.
## Params (chapters.json `traits[].params`, fallbacks in the constants below): `charges_to_fire`,
## `warning_sec`, `swing_cells`, `cooldown_sec`, `skill_id` (a damage card id).
## HUD: [method get_debug] {charges, charges_to_fire, cooldown_left, pending}.
## Implements: Story 023 (Part A).

## The reactor fired a swing over [param cells].
signal fired(cells: Array[Vector2i])
## The charge count changed (new count).
signal charges_changed(charges: int)

const ID: String = "step_reactor"
const DEFAULT_CHARGES_TO_FIRE: int = 3
const DEFAULT_WARNING_SEC: float = 0.5
const DEFAULT_SWING_CELLS: int = 3
const DEFAULT_COOLDOWN_SEC: float = 2.0
const DEFAULT_SKILL_ID: String = "kiem_khi"
const _SEED_OFFSET: int = 8803
const _DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var _charges_to_fire: int = DEFAULT_CHARGES_TO_FIRE
var _warning_sec: float = DEFAULT_WARNING_SEC
var _swing_cells: int = DEFAULT_SWING_CELLS
var _cooldown_sec: float = DEFAULT_COOLDOWN_SEC
var _skill_id: String = DEFAULT_SKILL_ID
var _charges: int = 0
var _cooldown_left: float = 0.0
var _pending: bool = false
var _fire_count: int = 0


func get_id() -> String:
	return ID


func seed_offset() -> int:
	return _SEED_OFFSET


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_charges_to_fire = maxi(param_int("charges_to_fire", DEFAULT_CHARGES_TO_FIRE), 1)
	_warning_sec = maxf(param_float("warning_sec", DEFAULT_WARNING_SEC), 0.05)
	_swing_cells = maxi(param_int("swing_cells", DEFAULT_SWING_CELLS), 1)
	_cooldown_sec = maxf(param_float("cooldown_sec", DEFAULT_COOLDOWN_SEC), 0.0)
	_skill_id = param_string("skill_id", DEFAULT_SKILL_ID)


func on_match_start() -> void:
	_charges = 0
	_cooldown_left = 0.0
	_pending = false
	_fire_count = 0


func on_tick(step: float) -> void:
	_cooldown_left = maxf(_cooldown_left - step, 0.0)
	if _pending:
		_try_fire()


func on_player_stepped(_from: Vector2i, _to: Vector2i) -> void:
	if _cooldown_left > 0.0 or _pending:
		return
	_charges += 1
	charges_changed.emit(_charges)
	if _charges >= _charges_to_fire:
		_pending = true
		_try_fire()


## Charges gathered (0 .. charges_to_fire).
func get_charges() -> int:
	return _charges


## Charges needed to fire.
func get_charges_to_fire() -> int:
	return _charges_to_fire


## Seconds until steps count again (0 = counting).
func get_cooldown_left() -> float:
	return _cooldown_left


## Swings fired so far this match.
func get_fire_count() -> int:
	return _fire_count


func get_debug() -> Dictionary:
	return {
		"id": ID, "charges": _charges, "charges_to_fire": _charges_to_fire,
		"cooldown_left": _cooldown_left, "pending": _pending, "fires": _fire_count,
	}


func teardown() -> void:
	_pending = false
	super()


# Starts the swing when the boss's actor is free; otherwise stays pending.
func _try_fire() -> void:
	var boss: BossController = get_context().get("boss") as BossController
	var state: CombatState = get_context().get("state") as CombatState
	var grid: BoardGrid = get_context().get("grid") as BoardGrid
	if boss == null or state == null or grid == null:
		return
	var actor: CutActor = boss.get_actor()
	if not actor.can_begin():
		return
	var cells: Array[Vector2i] = _cluster(grid, state.player_cell)
	if cells.is_empty() or not actor.begin_swing(cells, _skill_id, false, 1, _warning_sec):
		return
	_pending = false
	_charges = 0
	_cooldown_left = _cooldown_sec
	_fire_count += 1
	charges_changed.emit(0)
	fired.emit(cells)


# Connected cluster of [member _swing_cells] cells of the player's half containing [param start]
# (seeded random growth; smaller only when the half has no more neighbours).
func _cluster(grid: BoardGrid, start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not grid.is_player_cell(start):
		return out
	out.append(start)
	while out.size() < _swing_cells:
		var frontier: Array[Vector2i] = []
		for cell: Vector2i in out:
			for dir: Vector2i in _DIRS:
				var next: Vector2i = cell + dir
				if grid.is_player_cell(next) and not out.has(next) and not frontier.has(next):
					frontier.append(next)
		if frontier.is_empty():
			break
		out.append(frontier[rng.randi_range(0, frontier.size() - 1)])
	return out

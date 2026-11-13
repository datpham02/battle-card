class_name TileHazards
extends RefCounted
## Story 036 Part A: the tile hazard layer shared by every region and both sides. A pure model (no node):
##  - MIRE: steppable; stepping OUT of a mire cell multiplies that step's cooldown ([method step_cost_mult], read
##    by UnitMover.step_cost_fn); standing in mire costs mire_tick_damage every mire_tick_sec after mire_grace_sec.
##  - SAND: cells fall on both halves every sand_interval_sec (warning, then filled = blocked, then cleared);
##    never under a unit; the Story 027 leave-a-path rule ([ZoneRules.fit_cells]) keeps one exit open.
##  - WIND: a seeded direction among 4 that shifts every wind_shift_sec; [signal drift_due] every drift_sec x drift mult
##    (the caller drifts the field pieces, FieldDrops.drift_pieces).
## Every number comes from the hazards block of combat.json (CombatConfig.hazards()) plus the match overrides,
## handed to [method configure]. With nothing enabled the model never draws a random number and never emits.
## Implements: Story 036 Part A. Schema: assets/data/schema.md ("hazards").

## Standing in mire past the grace period: the caller applies [param amount] to the unit of [param side].
signal mire_damage(side: int, amount: float)
## A sand fall was scheduled: the warning phase of [param cells] starts.
signal sand_warned(side: int, cells: Array[Vector2i])
## The warning is over: [param cells] are now sand (blocked); pieces lying on them must be buried by the caller.
signal sand_filled(side: int, cells: Array[Vector2i])
## A filled sand cell ran out.
signal sand_cleared(side: int, cell: Vector2i)
## The wind direction changed (Vector2i.ZERO when the wind was switched off).
signal wind_changed(dir: Vector2i)
## Every drift_sec x drift mult while the wind blows: drift the field pieces one cell along [method wind_dir].
signal drift_due()

## Story 039: a lava vent of [param side] started its warning ([param cells] = every cell of the vent).
signal vent_warned(side: int, vent_index: int, cells: Array[Vector2i])
## Story 039: the vent erupts: [param cells] burn now (the caller ignites them through StatusEffects and burns the
## field pieces lying there).
signal vent_erupted(side: int, vent_index: int, cells: Array[Vector2i])
## Story 039: the vent calmed down.
signal vent_ended(side: int, vent_index: int)
## Story 039: [param cell] of [param side] cracks (warning phase before it falls).
signal cell_crumbling(side: int, cell: Vector2i)
## Story 039: [param cell] fell (blocked for fall_sec). [param occupant_pushed]: the unit stood on it and was moved to
## a steppable cell by the model; the caller applies fall_damage ([method config_value]) and burns the pieces there.
signal cell_fell(side: int, cell: Vector2i, occupant_pushed: bool)
## Story 039: a fallen cell is solid again.
signal cell_restored(side: int, cell: Vector2i)

## Defaults mirror assets/data/combat.json `hazards`. Story 039 adds the vent / crumble keys (vent_tick_sec and
## vent_tick_damage are the burn numbers the caller hands to StatusEffects.ignite for an erupting vent).
const DEFAULTS: Dictionary = {
	"mire_step_mult": 1.6, "mire_tick_damage": 0.5, "mire_tick_sec": 0.5, "mire_grace_sec": 0.5,
	"sand_interval_sec": 6.0, "sand_cells": 2, "sand_sec": 3.0, "sand_warn_sec": 0.8,
	"drift_sec": 2.0, "wind_shift_sec": 8.0,
	"vent_interval_sec": 7.0, "vent_warn_sec": 1.0, "vent_sec": 2.0, "vent_tick_sec": 0.5, "vent_tick_damage": 2.0,
	"crumble_after_sec": 2.0, "crumble_warn_sec": 0.6, "fall_sec": 4.0, "fall_damage": 8.0,
}
const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const _SIDES: Array[int] = [CombatState.Side.PLAYER, CombatState.Side.ENEMY]
const _EPS: float = 0.000001
# Safety cap on mire ticks fired by one call (a huge delta must not loop for long).
const _MAX_TICKS_PER_CALL: int = 16

## Optional Callable(side: int, cell: Vector2i) -> bool: extra blocked cells for the leave-a-path rule (seals, cracks).
var extra_blocked_fn: Callable = Callable()

var _grid: BoardGrid
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _state: CombatState = null
var _cfg: Dictionary = DEFAULTS.duplicate()
var _mire: Array[Dictionary] = [{}, {}]  # per side: cell -> seconds left (-1.0 = permanent)
var _sand: Array[Dictionary] = [{}, {}]  # per side: cell -> {warn, left, total, filled}
# Multi-enemy Phase 2: the UNIT books (mire immunity, standing timers, crumble standing) are keyed by unit key (0 =
# player, 1 + i = enemy unit i); the CELL books (_mire, _sand, _vents, _crumble) stay per half (index = Side).
var _immune: Dictionary = {}
var _standing: Dictionary = {}
var _next_tick: Dictionary = {}
var _stand_cell: Dictionary = {}
var _sand_on: bool = false
var _sand_timer: float = 0.0
var _wind_on: bool = false
var _wind_dir: Vector2i = Vector2i.ZERO
var _wind_left: float = 0.0
var _drift_acc: float = 0.0
var _drift_mult: float = 1.0
# Story 039 vents: per side an Array of {cells: Array[Vector2i], phase: int (0 idle, 1 warn, 2 erupt), left: float}.
var _vents: Array[Array] = [[], []]
var _vent_timer: float = 0.0
var _vent_mult: float = 1.0
var _vent_standing: Dictionary = {}
# Story 039 crumble: per side cell -> {phase: int (1 crack, 2 fallen), left, total (fall seconds), kind: "crumble" | "drop"}.
var _crumble: Array[Dictionary] = [{}, {}]
var _crumble_on: bool = false
## Presentation only (no rule / timing change): seconds a restored crumble / island_drop cell fades back in from
## white, like a drop tile's return. CombatView sets it from combat.json `zones.hole_return_fade_sec`
## (CombatConfig.hole_return_fade_sec); 0 = no fade (ADR-0001 Phase 1, 2026-11-01).
var return_fade_sec: float = 0.0
# Per side: restored cell -> fade seconds left.
var _return_fade: Array[Dictionary] = [{}, {}]
var _cr_cell: Dictionary = {}
var _cr_stand: Dictionary = {}
var _stats: Dictionary = {"pushes": 0, "vent_ticks": 0, "fall_damage_total": 0.0, "vent_damage_total": 0.0}

const _IDLE: int = 0
const _WARN: int = 1
const _ACTIVE: int = 2
# Crumble phases reuse _WARN (crack) and _ACTIVE (fallen).


## [param seed_value] < 0 gives a random seed; otherwise every seeded choice (sand cells, wind) is deterministic.
func _init(grid: BoardGrid, seed_value: int) -> void:
	_grid = grid
	if seed_value >= 0:
		_rng.seed = hash(["tile_hazards", seed_value])
	else:
		_rng.randomize()


## Returns [param base] overlaid with the valid values of [param cfg] (a bad value keeps the base one, with a
## warning). Used by CombatConfig.hazards() and [method configure].
static func clean(cfg: Dictionary, base: Dictionary = DEFAULTS) -> Dictionary:
	var out: Dictionary = base.duplicate()
	for key: String in DEFAULTS:
		if not cfg.has(key):
			continue
		var raw: Variant = cfg[key]
		if not (raw is float or raw is int):
			push_warning("TileHazards: hazards.%s must be a number, keeping %s" % [key, str(out[key])])
			continue
		var value: float = float(raw)
		var ok: bool = true
		match key:
			"mire_step_mult", "mire_tick_damage", "mire_grace_sec", "sand_warn_sec", \
			"vent_warn_sec", "vent_tick_damage", "crumble_warn_sec", "fall_damage":
				ok = value >= 0.0
			"mire_tick_sec", "sand_interval_sec", "sand_sec", "drift_sec", "wind_shift_sec", \
			"vent_interval_sec", "vent_sec", "vent_tick_sec", "crumble_after_sec", "fall_sec":
				ok = value > 0.0
			"sand_cells":
				ok = value >= 0.0
		if not ok:
			push_warning("TileHazards: hazards.%s=%s is out of range, keeping %s" % [key, str(raw), str(out[key])])
			continue
		out[key] = int(value) if key == "sand_cells" else value
	return out


## Gives the model the match state (unit cells: never sand under a unit, mire standing time). [method tick] also sets it.
func bind_state(state: CombatState) -> void:
	_state = state


## The merged hazards dictionary (combat.json block + match overrides); missing/bad keys keep the defaults.
func configure(cfg: Dictionary) -> void:
	_cfg = clean(cfg, DEFAULTS)


## Permanent arena mire on [param side]'s half (replaces the previous permanent mire; timed mire stays).
func set_mire(side: int, cells: Array[Vector2i]) -> void:
	var table: Dictionary = _mire[side]
	for cell: Vector2i in table.keys():
		if float(table[cell]) < 0.0:
			table.erase(cell)
	for cell: Vector2i in cells:
		if _is_half_cell(side, cell):
			table[cell] = -1.0


## Timed mire (traits): [param cells] of [param side]'s half become mire for [param sec]; a longer timer wins and
## permanent mire is untouched.
func add_mire(side: int, cells: Array[Vector2i], sec: float) -> void:
	if sec <= 0.0:
		return
	var table: Dictionary = _mire[side]
	for cell: Vector2i in cells:
		if not _is_half_cell(side, cell):
			continue
		var cur: float = float(table.get(cell, 0.0))
		if cur < 0.0:
			continue
		table[cell] = maxf(cur, sec)


## Removes all mire of [param side] (-1 = both sides), permanent included.
func clear_mire(side: int = -1) -> void:
	for s: int in _SIDES:
		if side < 0 or side == s:
			_mire[s].clear()
	for k: Variant in _standing.keys():
		if side < 0 or CombatState.side_of(int(k)) == side:
			_standing[k] = 0.0


## The unit of [param side] ignores mire (no slow, no damage) while [param immune].
func set_mire_immune(side: int, immune: bool) -> void:
	# Phase 2: [param side] is a unit key (Side.ENEMY = unit 0, the match's `mire_immune`)
	_immune[side] = immune


## Switches the periodic sand fall on/off (every sand_interval_sec, sand_cells per side).
func enable_sand(on: bool) -> void:
	if on and not _sand_on:
		_sand_timer = float(_cfg["sand_interval_sec"])
	_sand_on = on


## Trait / storm sand: [param cells] of [param side]'s half warn for [param warn_sec] (< 0 = sand_warn_sec; 0 = fill
## at once) then block for [param sec] (< 0 = sand_sec). Cells already sand/warning, off the half or under the unit are
## dropped, then the leave-a-path rule may drop one more. Returns the cells kept.
func add_sand(side: int, cells: Array[Vector2i], sec: float = -1.0, warn_sec: float = -1.0) -> Array[Vector2i]:
	var total: float = float(_cfg["sand_sec"]) if sec < 0.0 else sec
	var warn: float = float(_cfg["sand_warn_sec"]) if warn_sec < 0.0 else warn_sec
	return _schedule(side, cells, maxf(total, 0.0), maxf(warn, 0.0))


## Switches the wind on/off; switching it on picks a seeded direction.
func enable_wind(on: bool) -> void:
	if on == _wind_on:
		return
	_wind_on = on
	_drift_acc = 0.0
	if on:
		_wind_dir = _DIRS[_rng.randi_range(0, _DIRS.size() - 1)]
		_wind_left = float(_cfg["wind_shift_sec"])
	else:
		_wind_dir = Vector2i.ZERO
	wind_changed.emit(_wind_dir)


## Multiplies the drift interval (sandstorm: 0.5 = twice as often). Clamped to >= 0.01.
func set_drift_mult(mult: float) -> void:
	_drift_mult = maxf(mult, 0.01)


## Advances every hazard. [param state] gives the unit cells (sand never fills under a unit, mire standing time);
## [param dragged_cells] is reserved for the caller's drift (dragged pieces never drift) and does not change the model.
func tick(delta: float, state: CombatState, dragged_cells: Array[Vector2i] = []) -> void:
	_state = state
	if delta <= 0.0:
		return
	_tick_mire(delta)
	_tick_sand(delta)
	_tick_wind(delta)
	_tick_vents(delta)
	_tick_crumble(delta)


## True when [param cell] is mire for [param side] (permanent or timed).
func is_mire(side: int, cell: Vector2i) -> bool:
	return _mire[side].has(cell)


## Mire cells of [param side] (permanent and timed).
func mire_cells(side: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _mire[side]:
		out.append(cell)
	return out


## Seconds the mire on [param cell] lasts: -1.0 = permanent, 0.0 = not mire.
func mire_left(side: int, cell: Vector2i) -> float:
	return float(_mire[side].get(cell, 0.0))


## True when [param cell] is FILLED sand (blocked).
func is_sanded(side: int, cell: Vector2i) -> bool:
	return _sand[side].has(cell) and bool((_sand[side][cell] as Dictionary)["filled"])


## True when [param cell] is in the sand warning phase.
func is_sand_warning(side: int, cell: Vector2i) -> bool:
	return _sand[side].has(cell) and not bool((_sand[side][cell] as Dictionary)["filled"])


## Filled sand cells of [param side].
func sand_cells(side: int) -> Array[Vector2i]:
	return _sand_with(side, true)


## Sand cells of [param side] still in the warning phase.
func sand_warning_cells(side: int) -> Array[Vector2i]:
	return _sand_with(side, false)


## Seconds a filled sand cell has left (a warning cell reports its full duration; 0 = no sand).
func sand_left(side: int, cell: Vector2i) -> float:
	return float((_sand[side][cell] as Dictionary)["left"]) if _sand[side].has(cell) else 0.0


## Full duration of the sand on [param cell] (0 = no sand).
func sand_total_sec(side: int, cell: Vector2i) -> float:
	return float((_sand[side][cell] as Dictionary)["total"]) if _sand[side].has(cell) else 0.0


## One of (1,0) (-1,0) (0,1) (0,-1); (0,0) while the wind is off.
func wind_dir() -> Vector2i:
	return _wind_dir


## True while the wind blows.
func wind_enabled() -> bool:
	return _wind_on


## Multiplier of the step that starts on [param from_cell]: mire_step_mult when that cell is mire for [param side] and the
## side is not immune, else 1.0. Plugged into UnitMover.step_cost_fn (it runs after cooldown_scale, so a free step stays free).
func step_cost_mult(side: int, from_cell: Vector2i) -> float:
	if bool(_immune.get(side, false)) or not _mire[CombatState.side_of(side)].has(from_cell):
		return 1.0
	return float(_cfg["mire_step_mult"])


## Seconds the unit of [param side] has stood in mire on its current cell (0 when not in mire / immune).
func mire_standing_sec(side: int) -> float:
	return float(_standing.get(side, 0.0))


## Seconds until the next periodic sand fall (0 when sand is off).
func sand_timer_left() -> float:
	return _sand_timer if _sand_on else 0.0


## Seconds until the wind changes direction (0 when the wind is off).
func wind_shift_left() -> float:
	return _wind_left if _wind_on else 0.0


## Seconds until the next [signal drift_due] (0 when the wind is off); read by the boss brain's pickup.
func drift_left() -> float:
	if not _wind_on:
		return 0.0
	return maxf(float(_cfg["drift_sec"]) * _drift_mult - _drift_acc, 0.0)


## True while the unit of [param side] ignores mire (see [method set_mire_immune]).
func is_mire_immune(side: int) -> bool:
	return bool(_immune.get(side, false))


## Debug snapshot for tests and capture overlays.
func get_debug() -> Dictionary:
	return {
		"mire_player": _mire[CombatState.Side.PLAYER].size(), "mire_enemy": _mire[CombatState.Side.ENEMY].size(),
		"sand_player": _sand[CombatState.Side.PLAYER].size(), "sand_enemy": _sand[CombatState.Side.ENEMY].size(),
		"sand_on": _sand_on, "sand_timer": sand_timer_left(), "wind_on": _wind_on, "wind_dir": _wind_dir,
		"wind_left": wind_shift_left(), "drift_mult": _drift_mult, "cfg": _cfg.duplicate(),
		"vents": _vent_count(), "vents_active": _vents_in_phase(_ACTIVE), "vent_timer": vent_timer_left(),
		"crumble": _crumble_on, "fallen_player": fallen_cells(CombatState.Side.PLAYER).size(),
		"fallen_enemy": fallen_cells(CombatState.Side.ENEMY).size(),
	}


# --- mire ---------------------------------------------------------------------------------------------------

func _tick_mire(delta: float) -> void:
	for side: int in _SIDES:
		var table: Dictionary = _mire[side]
		for cell: Vector2i in table.keys():
			var left: float = float(table[cell])
			if left < 0.0:
				continue
			left -= delta
			if left <= 0.0:
				table.erase(cell)
			else:
				table[cell] = left
	if _state == null:
		return
	var grace: float = float(_cfg["mire_grace_sec"])
	var tick_sec: float = float(_cfg["mire_tick_sec"])
	var amount: float = float(_cfg["mire_tick_damage"])
	for side: int in _unit_keys():
		var half: int = CombatState.side_of(side)
		var cell: Vector2i = _state.cell_of(side)
		if cell != _stand_cell.get(side, BoardGrid.NO_CELL):
			_stand_cell[side] = cell
			_standing[side] = 0.0
			_next_tick[side] = grace
		if bool(_immune.get(side, false)) or not _unit_over(side, func(c: Vector2i) -> bool: return _mire[half].has(c)):
			_standing[side] = 0.0
			_next_tick[side] = grace
			continue
		_standing[side] = float(_standing.get(side, 0.0)) + delta
		var fired: int = 0
		while float(_standing[side]) + _EPS >= float(_next_tick.get(side, grace)) and fired < _MAX_TICKS_PER_CALL:
			_next_tick[side] = float(_next_tick.get(side, grace)) + tick_sec
			fired += 1
			if amount > 0.0 and not _is_dead(side):
				mire_damage.emit(side, amount)


func _is_dead(side: int) -> bool:
	return _state.is_key_dead(side)


# Phase 2: the unit keys the unit books run over: the player, then every enemy unit (the two sides without a state).
func _unit_keys() -> Array[int]:
	if _state == null:
		var both: Array[int] = [CombatState.Side.PLAYER, CombatState.Side.ENEMY]
		return both
	return _state.all_keys()


# --- sand ---------------------------------------------------------------------------------------------------

func _tick_sand(delta: float) -> void:
	for side: int in _SIDES:
		var table: Dictionary = _sand[side]
		var due: bool = false
		for cell: Vector2i in table.keys():
			var entry: Dictionary = table[cell]
			if bool(entry["filled"]):
				entry["left"] = float(entry["left"]) - delta
				if float(entry["left"]) <= 0.0:
					table.erase(cell)
					sand_cleared.emit(side, cell)
			else:
				entry["warn"] = float(entry["warn"]) - delta
				if float(entry["warn"]) <= 0.0:
					due = true
		if due:
			_resolve_fills(side)
	if not _sand_on:
		return
	_sand_timer -= delta
	if _sand_timer > 0.0:
		return
	_sand_timer = float(_cfg["sand_interval_sec"])
	var count: int = int(_cfg["sand_cells"])
	for side: int in _SIDES:
		var candidates: Array[Vector2i] = []
		for cell: Vector2i in _side_cells(side):
			if not _sand[side].has(cell) and not _unit_on(side, cell) and not _crumble[side].has(cell):
				candidates.append(cell)
		var picked: Array[Vector2i] = []
		while picked.size() < count and not candidates.is_empty():
			var idx: int = _rng.randi_range(0, candidates.size() - 1)
			picked.append(candidates[idx])
			candidates.remove_at(idx)
		if not picked.is_empty():
			_schedule(side, picked, float(_cfg["sand_sec"]), float(_cfg["sand_warn_sec"]))


# Registers [param cells] as sand entries (warning first) after the filters and the leave-a-path rule.
func _schedule(side: int, cells: Array[Vector2i], total: float, warn: float) -> Array[Vector2i]:
	var wanted: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if _is_half_cell(side, cell) and not _sand[side].has(cell) and not _unit_on(side, cell) and not wanted.has(cell):
			wanted.append(cell)
	var kept: Array[Vector2i] = ZoneRules.fit_cells_for(_grid, side, ZoneRules.standing_cells(_state, side), wanted, _blocked_fn(side, []))
	for cell: Vector2i in kept:
		_sand[side][cell] = {"warn": warn, "left": total, "total": total, "filled": false}
	if kept.is_empty():
		return kept
	if warn > 0.0:
		sand_warned.emit(side, kept.duplicate())
	else:
		_resolve_fills(side)
	return kept


# Turns every warning entry whose warning ran out into filled sand. A cell under a unit is cancelled and the
# leave-a-path rule is applied to the whole batch again (the unit may have moved since the warning).
func _resolve_fills(side: int) -> void:
	var table: Dictionary = _sand[side]
	var expired: Array[Vector2i] = []
	for cell: Vector2i in table:
		var entry: Dictionary = table[cell]
		if not bool(entry["filled"]) and float(entry["warn"]) <= 0.0:
			expired.append(cell)
	if expired.is_empty():
		return
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in expired:
		if not _unit_on(side, cell):
			candidates.append(cell)
	var kept: Array[Vector2i] = ZoneRules.fit_cells_for(_grid, side, ZoneRules.standing_cells(_state, side), candidates, _blocked_fn(side, expired))
	for cell: Vector2i in expired:
		if not kept.has(cell):
			table.erase(cell)
	for cell: Vector2i in kept:
		(table[cell] as Dictionary)["filled"] = true
	if not kept.is_empty():
		sand_filled.emit(side, kept.duplicate())


func _blocked_fn(side: int, exclude: Array[Vector2i]) -> Callable:
	return func(cell: Vector2i) -> bool:
		if _sand[side].has(cell) and not exclude.has(cell):
			return true
		if _crumble[side].has(cell):
			return true
		return extra_blocked_fn.is_valid() and bool(extra_blocked_fn.call(side, cell))


func _sand_with(side: int, filled: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _sand[side]:
		if bool((_sand[side][cell] as Dictionary)["filled"]) == filled:
			out.append(cell)
	return out


# --- wind ---------------------------------------------------------------------------------------------------

func _tick_wind(delta: float) -> void:
	if not _wind_on:
		return
	_wind_left -= delta
	if _wind_left <= 0.0:
		_wind_left = float(_cfg["wind_shift_sec"])
		# A shift always turns the wind: the new direction is drawn among the 3 other ones.
		var others: Array[Vector2i] = []
		for dir: Vector2i in _DIRS:
			if dir != _wind_dir:
				others.append(dir)
		_wind_dir = others[_rng.randi_range(0, others.size() - 1)]
		wind_changed.emit(_wind_dir)
	_drift_acc += delta
	var interval: float = float(_cfg["drift_sec"]) * _drift_mult
	if _drift_acc + _EPS >= interval:
		_drift_acc = 0.0
		drift_due.emit()


# --- vents (Story 039) ---------------------------------------------------------------------------------------

## Sets the lava vents of [param side]'s half: [param vents] is an Array of Array[Vector2i] (the cells of each vent;
## cells off the half are dropped, empty vents ignored). Replaces the previous vents of that side. The first vents
## start the vent clock (every vent_interval_sec one seeded vent of the whole arena warns, then erupts).
func set_vents(side: int, vents: Array) -> void:
	var out: Array = []
	for vent: Variant in vents:
		var cells: Array[Vector2i] = []
		for raw: Variant in (vent as Array):
			var cell: Vector2i = raw as Vector2i
			if _is_half_cell(side, cell) and not cells.has(cell):
				cells.append(cell)
		if not cells.is_empty():
			out.append({"cells": cells, "phase": _IDLE, "left": 0.0})
	_vents[side] = out
	for k: Variant in _vent_standing.keys():
		if CombatState.side_of(int(k)) == side:
			_vent_standing[k] = 0.0
	if _vent_count() == 0:
		_vent_timer = 0.0
	elif _vent_timer <= 0.0:
		_vent_timer = float(_cfg["vent_interval_sec"]) * _vent_mult


## Trait surge: makes one vent of [param side] warn for [param warn_sec] (< 0 = vent_warn_sec; 0 = erupt at once).
## [param vent_index] < 0 = a seeded idle vent. Returns false when the side has no idle vent (or the index is busy).
func trigger_vent(side: int, vent_index: int = -1, warn_sec: float = -1.0) -> bool:
	var idle: Array[int] = _idle_vents(side)
	if idle.is_empty():
		return false
	var idx: int = vent_index
	if idx < 0:
		idx = idle[_rng.randi_range(0, idle.size() - 1)]
	elif not idle.has(idx):
		return false
	_start_vent(side, idx, warn_sec)
	return true


## vent_surge: starts up to [param count] idle vents of [param side]: the ones containing [param prefer_cell] first,
## then seeded picks. Returns how many started.
func trigger_vents(side: int, count: int, prefer_cell: Vector2i = Vector2i(-1, -1)) -> int:
	var idle: Array[int] = _idle_vents(side)
	var order: Array[int] = []
	for idx: int in idle:
		var vent: Dictionary = _vents[side][idx]
		if (vent["cells"] as Array[Vector2i]).has(prefer_cell):
			order.append(idx)
	for idx: int in order:
		idle.erase(idx)
	while not idle.is_empty():
		var pick: int = _rng.randi_range(0, idle.size() - 1)
		order.append(idle[pick])
		idle.remove_at(pick)
	var started: int = 0
	for idx: int in order:
		if started >= count:
			break
		_start_vent(side, idx, -1.0)
		started += 1
	return started


## phase_shift: the vent interval becomes vent_interval_sec x [param mult] (clamped >= 0.01); the running countdown is
## scaled so a phase change takes effect at once.
func set_vent_interval_mult(mult: float) -> void:
	var m: float = maxf(mult, 0.01)
	if _vent_count() > 0 and _vent_timer > 0.0:
		_vent_timer *= m / _vent_mult
	_vent_mult = m


## Seconds until the next periodic vent starts (0 when the arena has no vents).
func vent_timer_left() -> float:
	return maxf(_vent_timer, 0.0) if _vent_count() > 0 else 0.0


## True while a vent of [param side] containing [param cell] erupts (the cell burns).
func is_venting(side: int, cell: Vector2i) -> bool:
	return _vent_phase_at(side, cell) == _ACTIVE


## True while a vent of [param side] containing [param cell] is in its warning phase.
func is_vent_warning(side: int, cell: Vector2i) -> bool:
	return _vent_phase_at(side, cell) == _WARN


## Every cell of every vent of [param side] (the fixed red streaks).
func vent_cells(side: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for vent: Dictionary in _vents[side]:
		for cell: Vector2i in (vent["cells"] as Array[Vector2i]):
			if not out.has(cell):
				out.append(cell)
	return out


## Seconds of warning left on [param cell] (0 when no vent containing it warns).
func vent_warn_left(side: int, cell: Vector2i) -> float:
	var best: float = 0.0
	for vent: Dictionary in _vents[side]:
		if int(vent["phase"]) == _WARN and (vent["cells"] as Array[Vector2i]).has(cell):
			best = maxf(best, float(vent["left"]))
	return best


## Seconds an erupting vent still burns [param cell] (0 when it does not erupt).
func vent_burn_left(side: int, cell: Vector2i) -> float:
	var best: float = 0.0
	for vent: Dictionary in _vents[side]:
		if int(vent["phase"]) == _ACTIVE and (vent["cells"] as Array[Vector2i]).has(cell):
			best = maxf(best, float(vent["left"]))
	return best


## Number of vents of [param side].
func vent_count(side: int) -> int:
	return (_vents[side] as Array).size()


## A number of the merged hazards config (the caller reads fall_damage, vent_tick_sec, vent_tick_damage here).
func config_value(key: String) -> float:
	return float(_cfg.get(key, 0.0))


## Match counters for the simulation: {pushes (units pushed by a falling cell), vent_ticks (burn ticks suffered on an
## erupting vent, estimated from the unit cells), fall_damage_total (fall_damage of every push), vent_damage_total
## (vent ticks x vent_tick_damage)}.
func stats() -> Dictionary:
	return _stats.duplicate()


func _vent_count() -> int:
	return (_vents[0] as Array).size() + (_vents[1] as Array).size()


func _vents_in_phase(phase: int) -> int:
	var n: int = 0
	for side: int in _SIDES:
		for vent: Dictionary in _vents[side]:
			if int(vent["phase"]) == phase:
				n += 1
	return n


func _idle_vents(side: int) -> Array[int]:
	var out: Array[int] = []
	var list: Array = _vents[side]
	for i: int in list.size():
		if int((list[i] as Dictionary)["phase"]) == _IDLE:
			out.append(i)
	return out


# The highest phase of a vent of [param side] containing [param cell].
func _vent_phase_at(side: int, cell: Vector2i) -> int:
	var best: int = _IDLE
	for vent: Dictionary in _vents[side]:
		if int(vent["phase"]) > best and (vent["cells"] as Array[Vector2i]).has(cell):
			best = int(vent["phase"])
	return best


func _start_vent(side: int, idx: int, warn_sec: float) -> void:
	var vent: Dictionary = _vents[side][idx]
	var warn: float = float(_cfg["vent_warn_sec"]) if warn_sec < 0.0 else warn_sec
	if warn <= 0.0:
		_erupt(side, idx, 0.0)
		return
	vent["phase"] = _WARN
	vent["left"] = warn
	vent_warned.emit(side, idx, (vent["cells"] as Array[Vector2i]).duplicate())


func _erupt(side: int, idx: int, carry: float) -> void:
	var vent: Dictionary = _vents[side][idx]
	vent["phase"] = _ACTIVE
	vent["left"] = float(_cfg["vent_sec"]) - carry
	vent_erupted.emit(side, idx, (vent["cells"] as Array[Vector2i]).duplicate())
	if float(vent["left"]) <= 0.0:
		vent["phase"] = _IDLE
		vent_ended.emit(side, idx)


func _tick_vents(delta: float) -> void:
	if _vent_count() == 0:
		return
	for side: int in _SIDES:
		var list: Array = _vents[side]
		for i: int in list.size():
			var vent: Dictionary = list[i]
			var phase: int = int(vent["phase"])
			if phase == _IDLE:
				continue
			vent["left"] = float(vent["left"]) - delta
			if float(vent["left"]) > 0.0:
				continue
			if phase == _WARN:
				_erupt(side, i, -float(vent["left"]))
			else:
				vent["phase"] = _IDLE
				vent_ended.emit(side, i)
	_tick_vent_burn(delta)
	_vent_timer -= delta
	if _vent_timer > 0.0:
		return
	_vent_timer += float(_cfg["vent_interval_sec"]) * _vent_mult
	if _vent_timer <= 0.0:
		_vent_timer = float(_cfg["vent_interval_sec"]) * _vent_mult
	var candidates: Array[Vector2i] = []  # (side, index)
	for side: int in _SIDES:
		for idx: int in _idle_vents(side):
			candidates.append(Vector2i(side, idx))
	if candidates.is_empty():
		return
	var pick: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_start_vent(pick.x, pick.y, -1.0)


# Counts the burn ticks a unit standing on an erupting vent cell suffers (the damage itself is dealt by the
# StatusEffects burning cell the caller lights on vent_erupted); mirrors StatusEffects' tick cadence.
func _tick_vent_burn(delta: float) -> void:
	if _state == null:
		return
	var tick_sec: float = float(_cfg["vent_tick_sec"])
	for side: int in _unit_keys():
		var half: int = CombatState.side_of(side)
		if _is_dead(side) or not _unit_over(side, func(c: Vector2i) -> bool: return is_venting(half, c)):
			_vent_standing[side] = 0.0
			continue
		_vent_standing[side] = float(_vent_standing.get(side, 0.0)) + delta
		while float(_vent_standing[side]) + _EPS >= tick_sec:
			_vent_standing[side] = float(_vent_standing[side]) - tick_sec
			_stats["vent_ticks"] = int(_stats["vent_ticks"]) + 1
			_stats["vent_damage_total"] = float(_stats["vent_damage_total"]) + float(_cfg["vent_tick_damage"])


# --- crumble (Story 039) -------------------------------------------------------------------------------------

## Switches the crumbling cells on/off: the player standing on one cell for crumble_after_sec makes it crack
## (crumble_warn_sec), then it falls for fall_sec (blocked; a unit on it is pushed to a steppable neighbour and takes
## fall_damage from the caller). Cells already cracking / fallen are not affected by switching off.
func enable_crumble(on: bool) -> void:
	_crumble_on = on
	_cr_cell.clear()
	_cr_stand.clear()


## True when crumbling cells are on.
func crumble_enabled() -> bool:
	return _crumble_on


## True when standing still cracks the cells of [param side]: only the player's half crumbles (user 2026-11-01,
## "phía map đảo trời thì cũng chỉ có bên người chơi có hiệu ứng sụp thôi"); the boss's half never crumbles.
func crumbles_side(side: int) -> bool:
	return _crumble_on and side == CombatState.Side.PLAYER


## Trait island_drop: [param cells] of [param side] crack for [param warn_sec] (< 0 = crumble_warn_sec) then fall for
## [param fall_sec] (< 0 = fall_sec). Cells off the half or already cracking / fallen are dropped, then the
## leave-a-path rule ([ZoneRules.fit_cells]) keeps one neighbour of the unit standing, and nothing falls at all when it
## would take the last standing island of the side. Returns the cells kept.
func drop_cells(side: int, cells: Array[Vector2i], fall_sec: float = -1.0, warn_sec: float = -1.0) -> Array[Vector2i]:
	var fall: float = float(_cfg["fall_sec"]) if fall_sec < 0.0 else fall_sec
	var warn: float = float(_cfg["crumble_warn_sec"]) if warn_sec < 0.0 else warn_sec
	var wanted: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if _is_half_cell(side, cell) and not _crumble[side].has(cell) and not wanted.has(cell):
			wanted.append(cell)
	var kept: Array[Vector2i] = ZoneRules.fit_cells_for(_grid, side, ZoneRules.standing_cells(_state, side), wanted, _blocked_fn(side, []))
	if kept.is_empty() or _standing_cells(side, kept, false).is_empty():
		var none: Array[Vector2i] = []
		return none
	for cell: Vector2i in kept:
		_start_crack(side, cell, maxf(warn, 0.0), maxf(fall, 0.0), "drop")
	return kept


## Connected components (4-neighbour) of the real, non-fallen cells of [param side]'s half: an Array of
## Array[Vector2i]. Cracking cells still count as standing.
func islands(side: int) -> Array:
	var open: Array[Vector2i] = _standing_cells(side, [], true)
	var out: Array = []
	var seen: Dictionary = {}
	for start: Vector2i in open:
		if seen.has(start):
			continue
		var comp: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			comp.append(cur)
			for dir: Vector2i in _DIRS:
				var n: Vector2i = cur + dir
				if not seen.has(n) and open.has(n):
					seen[n] = true
					queue.append(n)
		out.append(comp)
	return out


## Restored crumble cells of [param side] still fading back in (presentation, [member return_fade_sec]); sorted.
func returning_cells(side: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _return_fade[side]:
		out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _before(a, b))
	return out


## 1 = [param cell] of [param side] has just come back (full white), 0 = the fade is over / not returning.
func return_fraction(side: int, cell: Vector2i) -> float:
	if return_fade_sec <= 0.0 or not _return_fade[side].has(cell):
		return 0.0
	return clampf(float(_return_fade[side][cell]) / return_fade_sec, 0.0, 1.0)


## True when [param cell] of [param side] is fallen (blocked).
func is_fallen(side: int, cell: Vector2i) -> bool:
	return _crumble[side].has(cell) and int((_crumble[side][cell] as Dictionary)["phase"]) == _ACTIVE


## Fallen cells of [param side].
func fallen_cells(side: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _crumble[side]:
		if int((_crumble[side][cell] as Dictionary)["phase"]) == _ACTIVE:
			out.append(cell)
	return out


## Seconds until the fallen [param cell] is solid again (0 when it is not fallen).
func fallen_left(side: int, cell: Vector2i) -> float:
	if not is_fallen(side, cell):
		return 0.0
	return maxf(float((_crumble[side][cell] as Dictionary)["left"]), 0.0)


## Full fall time of the cracking / fallen [param cell] (0 when it is neither): the denominator of the time bar.
func fall_total_sec(side: int, cell: Vector2i) -> float:
	return float((_crumble[side][cell] as Dictionary)["total"]) if _crumble[side].has(cell) else 0.0


## 0..1: the standing timer of the unit on [param cell] towards crumble_after_sec (below 1 until the crack starts),
## 1.0 while the cell cracks, 0 otherwise (a fallen cell is drawn through [method is_fallen]).
func crumble_progress(side: int, cell: Vector2i) -> float:
	if _crumble[side].has(cell):
		return 1.0 if int((_crumble[side][cell] as Dictionary)["phase"]) == _WARN else 0.0
	if not _crumble_on or _cr_cell.get(side, BoardGrid.NO_CELL) != cell or _state == null or _state.cell_of(side) != cell:
		return 0.0
	return minf(float(_cr_stand.get(side, 0.0)) / float(_cfg["crumble_after_sec"]), 0.99)


## True while [param cell] of [param side] shows its crack warning.
func is_crumble_warning(side: int, cell: Vector2i) -> bool:
	return _crumble[side].has(cell) and int((_crumble[side][cell] as Dictionary)["phase"]) == _WARN


## Seconds of crack warning left on [param cell] (0 when it does not crack).
func crumble_warn_left(side: int, cell: Vector2i) -> float:
	if not is_crumble_warning(side, cell):
		return 0.0
	return maxf(float((_crumble[side][cell] as Dictionary)["left"]), 0.0)


func _tick_crumble(delta: float) -> void:
	for side: int in _SIDES:
		var fades: Dictionary = _return_fade[side]
		for cell: Variant in fades.keys():
			fades[cell] = float(fades[cell]) - delta
			if float(fades[cell]) <= 0.0:
				fades.erase(cell)
	for side: int in _SIDES:
		var table: Dictionary = _crumble[side]
		if table.is_empty():
			continue
		var keys: Array = table.keys()
		keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _before(a, b))
		for key: Variant in keys:
			var cell: Vector2i = key as Vector2i
			if not table.has(cell):
				continue
			var entry: Dictionary = table[cell]
			entry["left"] = float(entry["left"]) - delta
			if float(entry["left"]) > 0.0:
				continue
			if int(entry["phase"]) == _WARN:
				_fall(side, cell, -float(entry["left"]))
			else:
				table.erase(cell)
				if return_fade_sec > 0.0:
					_return_fade[side][cell] = return_fade_sec
				cell_restored.emit(side, cell)
	if not _crumble_on or _state == null:
		return
	var after: float = float(_cfg["crumble_after_sec"])
	for side: int in _unit_keys():
		var half: int = CombatState.side_of(side)
		if _is_dead(side) or not crumbles_side(half):
			continue
		var cell: Vector2i = _state.cell_of(side)
		if cell != _cr_cell.get(side, BoardGrid.NO_CELL):
			_cr_cell[side] = cell
			_cr_stand[side] = 0.0
			continue
		_cr_stand[side] = float(_cr_stand.get(side, 0.0)) + delta
		if float(_cr_stand[side]) + _EPS >= after and not _crumble[half].has(cell) \
				and _push_target(half, cell, true) != BoardGrid.NO_CELL:
			_start_crack(half, cell, float(_cfg["crumble_warn_sec"]), float(_cfg["fall_sec"]), "crumble")


func _start_crack(side: int, cell: Vector2i, warn: float, fall: float, kind: String) -> void:
	_crumble[side][cell] = {"phase": _WARN, "left": warn, "total": fall, "kind": kind}
	cell_crumbling.emit(side, cell)
	if warn <= 0.0:
		_fall(side, cell, 0.0)


# The crack ran out: the cell falls. A unit on it is pushed first (the model moves it; the caller applies fall_damage);
# when no landing cell exists the cell does not fall at all (the crack is cancelled).
func _fall(side: int, cell: Vector2i, carry: float) -> void:
	var entry: Dictionary = _crumble[side][cell]
	var pushed: bool = false
	# Phase 2: [param side] is the half; the unit on the cell is whichever living unit of that half stands there.
	var key: int = _key_on(side, cell)
	if key >= 0:
		var target: Vector2i = _push_target(side, cell, String(entry["kind"]) == "crumble")
		if target == BoardGrid.NO_CELL:
			_crumble[side].erase(cell)
			_cr_stand[key] = 0.0
			return
		pushed = _state.set_key_cell(key, target)
		if pushed:
			_cr_cell[key] = target
			_cr_stand[key] = 0.0
			_stats["pushes"] = int(_stats["pushes"]) + 1
			_stats["fall_damage_total"] = float(_stats["fall_damage_total"]) + float(_cfg["fall_damage"])
	entry["phase"] = _ACTIVE
	entry["left"] = maxf(float(entry["total"]) - carry, _EPS)
	cell_fell.emit(side, cell, pushed)


# Where a unit on [param from] lands when that cell falls: the nearest open cell of the half (ties: most onward exits,
# then x then y). [param single] (a crumbling cell) = a 4-neighbour that itself keeps an exit other than [param from]
# (the unit must keep a way off its island); an island drop accepts any distance. NO_CELL = nowhere to go.
func _push_target(side: int, from: Vector2i, single: bool) -> Vector2i:
	var best: Vector2i = BoardGrid.NO_CELL
	var best_dist: int = 1 << 30
	var best_exits: int = -1
	for cell: Vector2i in _side_cells(side):
		if cell == from or not _is_open(side, cell):
			continue
		var dist: int = absi(cell.x - from.x) + absi(cell.y - from.y)
		if single and dist != 1:
			continue
		var exits: int = _exits(side, cell, from)
		if single and exits == 0:
			continue
		if dist < best_dist or (dist == best_dist and (exits > best_exits or (exits == best_exits and _before(cell, best)))):
			best = cell
			best_dist = dist
			best_exits = exits
	return best


# A cell a unit could stand on / land on: not cracking, fallen or sand, and not blocked by the caller's test.
func _is_open(side: int, cell: Vector2i) -> bool:
	if _crumble[side].has(cell) or _sand[side].has(cell):
		return false
	# Phase 2: a cell another living unit of that half covers is not a landing cell (one unit: never true off its cell)
	if _state != null and side == CombatState.Side.ENEMY and _state.unit_count() > 1 and _state.enemy_at(cell) >= 0:
		return false
	return not (extra_blocked_fn.is_valid() and bool(extra_blocked_fn.call(side, cell)))


func _exits(side: int, cell: Vector2i, excluded: Vector2i) -> int:
	var n: int = 0
	for dir: Vector2i in _DIRS:
		var next: Vector2i = cell + dir
		if next != excluded and _is_half_cell(side, next) and _is_open(side, next):
			n += 1
	return n


# Real cells of [param side] that stand: not fallen (and not cracking unless [param cracking_stands]) and not in [param excluded].
func _standing_cells(side: int, excluded: Array[Vector2i], cracking_stands: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _side_cells(side):
		if excluded.has(cell):
			continue
		if _crumble[side].has(cell) and (not cracking_stands or int((_crumble[side][cell] as Dictionary)["phase"]) == _ACTIVE):
			continue
		out.append(cell)
	return out


static func _before(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


# --- helpers ------------------------------------------------------------------------------------------------

func _side_cells(side: int) -> Array[Vector2i]:
	return _grid.player_cells() if side == CombatState.Side.PLAYER else _grid.enemy_cells()


func _is_half_cell(side: int, cell: Vector2i) -> bool:
	return _grid.is_player_cell(cell) if side == CombatState.Side.PLAYER else _grid.is_enemy_cell(cell)


func _unit_cell(side: int) -> Vector2i:
	return BoardGrid.NO_CELL if _state == null else _state.cell_of(side)


# P2.2b: true when a unit of [param side]'s half covers [param cell] (any footprint cell of a multi-cell boss). Phase 2:
# any living unit of that half (unit 0 / the player as before, even dead, for the single-unit answer).
func _unit_on(side: int, cell: Vector2i) -> bool:
	return _state != null and (_state.unit_at(side, cell) or _state.key_at(side, cell) >= 0)


# Phase 2: the key of the living unit of [param half] whose ANCHOR is [param cell] (the pre-Phase-2 fall test read the
# anchor only, `cell_of(side) == cell`); -1 when none or without a state.
func _key_on(half: int, cell: Vector2i) -> int:
	if _state == null:
		return -1
	if half == CombatState.Side.PLAYER:
		return CombatState.Side.PLAYER if (not _state.is_player_dead() and _state.player_cell == cell) else -1
	for key: int in _state.enemy_keys(true):
		if _state.cell_of(key) == cell:
			return key
	return -1


# P2.2b: true when [param test] (Callable(cell) -> bool) holds on any cell the unit of [param side] covers; one answer, so
# a hazard tick hurts a multi-cell boss once however many of its cells are in the hazard.
func _unit_over(side: int, test: Callable) -> bool:
	if _state == null:
		return false
	for cell: Vector2i in _state.unit_cells(side):
		if bool(test.call(cell)):
			return true
	return false

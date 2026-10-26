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

## Defaults mirror assets/data/combat.json `hazards`.
const DEFAULTS: Dictionary = {
	"mire_step_mult": 1.6, "mire_tick_damage": 0.5, "mire_tick_sec": 0.5, "mire_grace_sec": 0.5,
	"sand_interval_sec": 6.0, "sand_cells": 2, "sand_sec": 3.0, "sand_warn_sec": 0.8,
	"drift_sec": 2.0, "wind_shift_sec": 8.0,
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
var _immune: Array[bool] = [false, false]
var _standing: Array[float] = [0.0, 0.0]
var _next_tick: Array[float] = [0.0, 0.0]
var _stand_cell: Array[Vector2i] = [BoardGrid.NO_CELL, BoardGrid.NO_CELL]
var _sand_on: bool = false
var _sand_timer: float = 0.0
var _wind_on: bool = false
var _wind_dir: Vector2i = Vector2i.ZERO
var _wind_left: float = 0.0
var _drift_acc: float = 0.0
var _drift_mult: float = 1.0


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
			"mire_step_mult", "mire_tick_damage", "mire_grace_sec", "sand_warn_sec":
				ok = value >= 0.0
			"mire_tick_sec", "sand_interval_sec", "sand_sec", "drift_sec", "wind_shift_sec":
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
			_standing[s] = 0.0


## The unit of [param side] ignores mire (no slow, no damage) while [param immune].
func set_mire_immune(side: int, immune: bool) -> void:
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
	if _immune[side] or not _mire[side].has(from_cell):
		return 1.0
	return float(_cfg["mire_step_mult"])


## Seconds the unit of [param side] has stood in mire on its current cell (0 when not in mire / immune).
func mire_standing_sec(side: int) -> float:
	return _standing[side]


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
	return _immune[side]


## Debug snapshot for tests and capture overlays.
func get_debug() -> Dictionary:
	return {
		"mire_player": _mire[CombatState.Side.PLAYER].size(), "mire_enemy": _mire[CombatState.Side.ENEMY].size(),
		"sand_player": _sand[CombatState.Side.PLAYER].size(), "sand_enemy": _sand[CombatState.Side.ENEMY].size(),
		"sand_on": _sand_on, "sand_timer": sand_timer_left(), "wind_on": _wind_on, "wind_dir": _wind_dir,
		"wind_left": wind_shift_left(), "drift_mult": _drift_mult, "cfg": _cfg.duplicate(),
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
	for side: int in _SIDES:
		var cell: Vector2i = _state.cell_of(side)
		if cell != _stand_cell[side]:
			_stand_cell[side] = cell
			_standing[side] = 0.0
			_next_tick[side] = grace
		if _immune[side] or not _mire[side].has(cell):
			_standing[side] = 0.0
			_next_tick[side] = grace
			continue
		_standing[side] += delta
		var fired: int = 0
		while _standing[side] + _EPS >= _next_tick[side] and fired < _MAX_TICKS_PER_CALL:
			_next_tick[side] += tick_sec
			fired += 1
			if amount > 0.0 and not _is_dead(side):
				mire_damage.emit(side, amount)


func _is_dead(side: int) -> bool:
	return _state.is_player_dead() if side == CombatState.Side.PLAYER else _state.is_enemy_dead()


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
			if not _sand[side].has(cell) and cell != _unit_cell(side):
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
		if _is_half_cell(side, cell) and not _sand[side].has(cell) and cell != _unit_cell(side) and not wanted.has(cell):
			wanted.append(cell)
	var kept: Array[Vector2i] = ZoneRules.fit_cells(_grid, side, _unit_cell(side), wanted, _blocked_fn(side, []))
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
		if cell != _unit_cell(side):
			candidates.append(cell)
	var kept: Array[Vector2i] = ZoneRules.fit_cells(_grid, side, _unit_cell(side), candidates, _blocked_fn(side, expired))
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


# --- helpers ------------------------------------------------------------------------------------------------

func _side_cells(side: int) -> Array[Vector2i]:
	return _grid.player_cells() if side == CombatState.Side.PLAYER else _grid.enemy_cells()


func _is_half_cell(side: int, cell: Vector2i) -> bool:
	return _grid.is_player_cell(cell) if side == CombatState.Side.PLAYER else _grid.is_enemy_cell(cell)


func _unit_cell(side: int) -> Vector2i:
	return BoardGrid.NO_CELL if _state == null else _state.cell_of(side)

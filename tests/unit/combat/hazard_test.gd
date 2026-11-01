extends SceneTree
## Story 036 Part A (tile hazards) + Story 039 (vents, crumbling cells, island drops): mire (step cost, grace + tick cadence, immunity), sand (warn / fill / clear,
## burial, never under a unit, leave-a-path), wind (direction, shift, drift cadence, FieldDrops drift rules),
## the UnitMover step_cost_fn hook and the combat.json `hazards` block. Deterministic, headless.
## Run: godot --headless --path . -s res://tests/unit/combat/hazard_test.gd

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const HP: float = 1000.0
const STEP_SEC: float = 0.5
const EPS: float = 0.0001
const NO_UNIT: Vector2i = Vector2i(-1, -1)

var fails: int = 0


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func mk() -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), HP, HP, Vector2i(1, 1), Vector2i(4, 1))


func hz_new(state: CombatState, seed_value: int = 7) -> TileHazards:
	var hz: TileHazards = TileHazards.new(BoardGrid.new(3, 3), seed_value)
	hz.bind_state(state)
	return hz


func mover_for(state: CombatState, side: int, hz: TileHazards) -> UnitMover:
	var mv: UnitMover = UnitMover.new(state, side, STEP_SEC)
	var s: int = side
	mv.step_cost_fn = func(from_cell: Vector2i) -> float: return hz.step_cost_mult(s, from_cell)
	mv.add_blocker(func(cell: Vector2i) -> bool: return hz.is_sanded(s, cell))
	return mv


func cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in list:
		out.append(c as Vector2i)
	return out


## Ticks [param total] seconds in [param step] slices.
func run(hz: TileHazards, state: CombatState, total: float, step: float = 0.1) -> void:
	var left: float = total
	while left > 0.0001:
		var d: float = minf(step, left)
		hz.tick(d, state)
		left -= d


func _init() -> void:
	_mire_step_tests()
	_mire_tick_tests()
	_sand_tests()
	_wind_tests()
	_drift_tests()
	_config_tests()
	_vent_tests()
	_crumble_tests()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _mire_step_tests() -> void:
	var st: CombatState = mk()
	var hz: TileHazards = hz_new(st)
	hz.set_mire(P, cells([Vector2i(1, 1), Vector2i(0, 0)]))
	var mv: UnitMover = mover_for(st, P, hz)
	ck("mire: leaving a mire cell multiplies that step's cooldown", mv.try_step(Vector2i(-1, 0)) and absf(mv.get_cooldown_remaining() - STEP_SEC * 1.6) < EPS)
	mv.tick(5.0)
	# (0,1) is not mire: a normal step; stepping INTO mire (0,0) is not slowed either.
	ck("mire: a step from a normal cell costs the plain cooldown", mv.try_step(Vector2i(0, -1)) and absf(mv.get_cooldown_remaining() - STEP_SEC) < EPS)
	mv.tick(5.0)
	ck("mire: now on a mire cell, stepping out is slow again", mv.try_step(Vector2i(1, 0)) and absf(mv.get_cooldown_remaining() - STEP_SEC * 1.6) < EPS)
	ck("mire: step_cost_mult reads the configured mire_step_mult", absf(hz.step_cost_mult(P, Vector2i(1, 1)) - 1.6) < EPS and hz.step_cost_mult(P, Vector2i(2, 2)) == 1.0)
	ck("mire: enemy half mire does not slow the player side", hz.step_cost_mult(E, Vector2i(1, 1)) == 1.0)

	# A free step (cooldown_scale 0.0, Anh Bo) stays free even when leaving mire.
	var st2: CombatState = mk()
	var hz2: TileHazards = hz_new(st2)
	hz2.set_mire(P, cells([Vector2i(1, 1)]))
	var mv2: UnitMover = mover_for(st2, P, hz2)
	mv2.cooldown_scale = func() -> float: return 0.0
	ck("mire: a free step stays free", mv2.try_step(Vector2i(-1, 0)) and mv2.get_cooldown_remaining() == 0.0)

	# No hook: the cooldown is unchanged (today's behaviour).
	var st3: CombatState = mk()
	var mv3: UnitMover = UnitMover.new(st3, P, STEP_SEC)
	ck("mire: without step_cost_fn the cooldown is plain", mv3.try_step(Vector2i(-1, 0)) and absf(mv3.get_cooldown_remaining() - STEP_SEC) < EPS)

	# Immune side: no slow.
	var st4: CombatState = mk()
	var hz4: TileHazards = hz_new(st4)
	hz4.set_mire(E, cells([Vector2i(4, 1)]))
	hz4.set_mire_immune(E, true)
	var mv4: UnitMover = mover_for(st4, E, hz4)
	ck("mire: an immune side is not slowed", mv4.try_step(Vector2i(1, 0)) and absf(mv4.get_cooldown_remaining() - STEP_SEC) < EPS)


func _mire_tick_tests() -> void:
	var st: CombatState = mk()
	var hz: TileHazards = hz_new(st)
	hz.set_mire(P, cells([Vector2i(1, 1)]))
	var box: Dictionary = {"count": 0, "side": -1, "amount": 0.0}
	hz.mire_damage.connect(func(side: int, amount: float) -> void:
		box["count"] += 1
		box["side"] = side
		box["amount"] = amount)
	run(hz, st, 0.4)
	ck("mire tick: nothing during the grace period", box["count"] == 0)
	run(hz, st, 0.1)
	ck("mire tick: first tick right after the grace (0.5 s)", box["count"] == 1 and box["side"] == P and absf(float(box["amount"]) - float(TileHazards.DEFAULTS["mire_tick_damage"])) < EPS)
	run(hz, st, 0.4)
	ck("mire tick: no second tick before the cadence", box["count"] == 1)
	run(hz, st, 0.1)
	ck("mire tick: second tick one mire_tick_sec later", box["count"] == 2)
	run(hz, st, 0.5)
	ck("mire tick: third tick at the cadence", box["count"] == 3)
	ck("mire tick: standing time accumulates", absf(hz.mire_standing_sec(P) - 1.5) < 0.001)

	# Passing through one mire cell (one step cooldown, 0.45 s) costs nothing.
	var st2: CombatState = mk()
	var hz2: TileHazards = hz_new(st2)
	hz2.set_mire(P, cells([Vector2i(0, 1)]))
	var box2: Dictionary = {"count": 0}
	hz2.mire_damage.connect(func(_side: int, _amount: float) -> void: box2["count"] += 1)
	st2.set_player_cell(Vector2i(0, 1))
	run(hz2, st2, 0.45)
	st2.set_player_cell(Vector2i(1, 1))
	run(hz2, st2, 2.0)
	ck("mire tick: walking through one mire cell costs nothing", box2["count"] == 0 and hz2.mire_standing_sec(P) == 0.0)
	# Re-entering restarts the grace.
	st2.set_player_cell(Vector2i(0, 1))
	run(hz2, st2, 0.4)
	ck("mire tick: re-entering restarts the grace period", box2["count"] == 0)

	# Immune side takes nothing; the other side still does.
	var st3: CombatState = mk()
	var hz3: TileHazards = hz_new(st3)
	hz3.set_mire(E, cells([Vector2i(4, 1)]))
	hz3.set_mire(P, cells([Vector2i(1, 1)]))
	hz3.set_mire_immune(E, true)
	var box3: Dictionary = {"player": 0, "enemy": 0}
	hz3.mire_damage.connect(func(side: int, _amount: float) -> void:
		if side == P:
			box3["player"] += 1
		else:
			box3["enemy"] += 1)
	run(hz3, st3, 1.0)
	ck("mire immune: the immune boss takes no tick damage, the player does", box3["enemy"] == 0 and box3["player"] == 2)
	ck("mire immune: no standing time counted", hz3.mire_standing_sec(E) == 0.0)

	# Timed mire expires; permanent mire reports -1.
	var st4: CombatState = mk()
	var hz4: TileHazards = hz_new(st4)
	hz4.set_mire(P, cells([Vector2i(2, 2)]))
	hz4.add_mire(P, cells([Vector2i(0, 0), Vector2i(2, 2)]), 1.0)
	ck("mire timed: permanent mire is not shortened", hz4.mire_left(P, Vector2i(2, 2)) == -1.0)
	ck("mire timed: a timed cell reports its time", absf(hz4.mire_left(P, Vector2i(0, 0)) - 1.0) < EPS and hz4.is_mire(P, Vector2i(0, 0)))
	run(hz4, st4, 1.1)
	ck("mire timed: the timed cell is gone after its time", not hz4.is_mire(P, Vector2i(0, 0)) and hz4.is_mire(P, Vector2i(2, 2)))
	hz4.add_mire(P, cells([Vector2i(3, 1)]), 2.0)
	ck("mire timed: cells of the other half are ignored", not hz4.is_mire(P, Vector2i(3, 1)))
	hz4.clear_mire()
	ck("mire clear: clear_mire empties both sides", hz4.mire_cells(P).is_empty() and hz4.mire_cells(E).is_empty())

	# Idle model: nothing enabled, nothing emitted, no state change.
	var st5: CombatState = mk()
	var hz5: TileHazards = hz_new(st5)
	var box5: Dictionary = {"signals": 0}
	hz5.mire_damage.connect(func(_s: int, _a: float) -> void: box5["signals"] += 1)
	hz5.sand_warned.connect(func(_s: int, _c: Array[Vector2i]) -> void: box5["signals"] += 1)
	hz5.sand_filled.connect(func(_s: int, _c: Array[Vector2i]) -> void: box5["signals"] += 1)
	hz5.wind_changed.connect(func(_d: Vector2i) -> void: box5["signals"] += 1)
	hz5.drift_due.connect(func() -> void: box5["signals"] += 1)
	run(hz5, st5, 30.0)
	ck("idle: with nothing enabled the model emits nothing", box5["signals"] == 0 and hz5.wind_dir() == Vector2i.ZERO and not hz5.wind_enabled())


func _sand_tests() -> void:
	var st: CombatState = mk() # player (1,1)
	var hz: TileHazards = hz_new(st)
	var mv: UnitMover = mover_for(st, P, hz)
	var box: Dictionary = {"warned": 0, "filled": [], "cleared": 0}
	hz.sand_warned.connect(func(_s: int, c: Array[Vector2i]) -> void: box["warned"] += c.size())
	hz.sand_filled.connect(func(_s: int, c: Array[Vector2i]) -> void: box["filled"].append_array(c))
	hz.sand_cleared.connect(func(_s: int, _c: Vector2i) -> void: box["cleared"] += 1)
	var drops: FieldDrops = FieldDrops.new(FieldDropsConfig.new(), BoardGrid.new(3, 3).player_cells(), 1)
	drops.debug_place("x", Vector2i(0, 1), 50.0)
	drops.debug_place("y", Vector2i(2, 2), 50.0)
	var buried: Dictionary = {"n": 0}
	hz.sand_filled.connect(func(_s: int, c: Array[Vector2i]) -> void: buried["n"] += drops.bury_cells(c))
	var kept: Array[Vector2i] = hz.add_sand(P, cells([Vector2i(0, 1)]), 3.0, 0.8)
	ck("sand: add_sand returns the kept cells", kept == cells([Vector2i(0, 1)]))
	ck("sand: first the warning, not yet blocked", hz.is_sand_warning(P, Vector2i(0, 1)) and not hz.is_sanded(P, Vector2i(0, 1)) and not mv.is_cell_blocked(Vector2i(0, 1)) and box["warned"] == 1)
	run(hz, st, 0.7)
	ck("sand: still a warning just before sand_warn_sec", hz.is_sand_warning(P, Vector2i(0, 1)))
	run(hz, st, 0.15)
	ck("sand: filled after the warning and blocks the step", hz.is_sanded(P, Vector2i(0, 1)) and mv.is_cell_blocked(Vector2i(0, 1)) and not mv.try_step(Vector2i(-1, 0)))
	ck("sand: the piece lying on the filled cell is buried, the other stays", buried["n"] == 1 and drops.get_points().size() == 1 and drops.get_points()[0].cell == Vector2i(2, 2))
	ck("sand: sand_cells lists it and a time bar is available", hz.sand_cells(P) == cells([Vector2i(0, 1)]) and absf(hz.sand_total_sec(P, Vector2i(0, 1)) - 3.0) < EPS and hz.sand_left(P, Vector2i(0, 1)) <= 3.0)
	run(hz, st, 3.0)
	ck("sand: the cell opens again after sand_sec", not hz.is_sanded(P, Vector2i(0, 1)) and box["cleared"] == 1 and not mv.is_cell_blocked(Vector2i(0, 1)))
	ck("sand: a step into the cleared cell works", mv.try_step(Vector2i(-1, 0)))

	# Never under a unit: the cell under the unit is dropped from add_sand; a unit that walks onto a warning cell cancels it.
	var st2: CombatState = mk()
	var hz2: TileHazards = hz_new(st2)
	var k2: Array[Vector2i] = hz2.add_sand(P, cells([Vector2i(1, 1), Vector2i(2, 2)]), 3.0, 0.5)
	ck("sand: the cell under the unit is never kept", k2 == cells([Vector2i(2, 2)]))
	var k3: Array[Vector2i] = hz2.add_sand(P, cells([Vector2i(0, 0)]), 3.0, 0.5)
	st2.set_player_cell(Vector2i(0, 0))
	run(hz2, st2, 0.6)
	ck("sand: a unit that stepped onto a warning cell cancels it (never sand under a unit)", k3.size() == 1 and not hz2.is_sanded(P, Vector2i(0, 0)) and not hz2.is_sand_warning(P, Vector2i(0, 0)) and hz2.is_sanded(P, Vector2i(2, 2)))
	ck("sand: cells of the other half and duplicates are dropped", hz2.add_sand(P, cells([Vector2i(4, 0), Vector2i(2, 2)]), 1.0, 0.0).is_empty())

	# Leave-a-path: the four neighbours of the unit cannot all close.
	var st3: CombatState = mk()
	var hz3: TileHazards = hz_new(st3)
	var k4: Array[Vector2i] = hz3.add_sand(P, cells([Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]), 3.0, 0.0)
	ck("sand: leave-a-path keeps one neighbour of the unit open", k4.size() == 3 and hz3.sand_cells(P).size() == 3)
	var open: int = 0
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not hz3.is_sanded(P, Vector2i(1, 1) + dir):
			open += 1
	ck("sand: exactly one neighbour is open", open == 1)
	ck("sand: warn 0 fills at once", hz3.sand_warning_cells(P).is_empty())
	# A seal (extra blocker) counts as blocked for the rule.
	var st4: CombatState = mk()
	var hz4: TileHazards = hz_new(st4)
	hz4.extra_blocked_fn = func(_side: int, cell: Vector2i) -> bool: return cell == Vector2i(1, 0) or cell == Vector2i(0, 1)
	var k5: Array[Vector2i] = hz4.add_sand(P, cells([Vector2i(2, 1), Vector2i(1, 2)]), 3.0, 0.0)
	ck("sand: seals count as blocked for leave-a-path", k5.size() == 1)

	# Periodic fall on both halves, seeded, never under a unit, always a path.
	var st5: CombatState = mk()
	var hz5: TileHazards = hz_new(st5, 11)
	hz5.configure({"sand_interval_sec": 1.0, "sand_cells": 9, "sand_warn_sec": 0.2, "sand_sec": 2.0})
	hz5.enable_sand(true)
	var warned: Dictionary = {P: [], E: []}
	hz5.sand_warned.connect(func(side: int, c: Array[Vector2i]) -> void: warned[side].append_array(c))
	run(hz5, st5, 0.95)
	ck("sand periodic: nothing before the interval", warned[P].is_empty() and warned[E].is_empty())
	run(hz5, st5, 0.1)
	ck("sand periodic: both halves get a fall", not warned[P].is_empty() and not warned[E].is_empty())
	ck("sand periodic: never under a unit", not warned[P].has(Vector2i(1, 1)) and not warned[E].has(Vector2i(4, 1)))
	var p_open: bool = false
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = Vector2i(1, 1) + dir
		if BoardGrid.new(3, 3).is_player_cell(c) and not warned[P].has(c):
			p_open = true
	ck("sand periodic: the player keeps a way out even when the fall wants every cell", p_open)
	var hz6: TileHazards = hz_new(mk(), 11)
	hz6.configure({"sand_interval_sec": 1.0, "sand_cells": 9, "sand_warn_sec": 0.2, "sand_sec": 2.0})
	hz6.enable_sand(true)
	var st6: CombatState = mk()
	hz6.bind_state(st6)
	var warned6: Array[Vector2i] = []
	hz6.sand_warned.connect(func(side: int, c: Array[Vector2i]) -> void:
		if side == P:
			warned6.append_array(c))
	run(hz6, st6, 1.05)
	ck("sand periodic: the same seed gives the same cells", warned6 == warned[P])
	# sand_cells count honoured with a small number.
	var st7: CombatState = mk()
	var hz7: TileHazards = hz_new(st7, 3)
	hz7.configure({"sand_interval_sec": 1.0, "sand_cells": 2, "sand_warn_sec": 0.2})
	hz7.enable_sand(true)
	run(hz7, st7, 1.05)
	ck("sand periodic: sand_cells per side", hz7.sand_warning_cells(P).size() == 2 and hz7.sand_warning_cells(E).size() == 2)
	run(hz7, st7, 0.3)
	ck("sand periodic: warning turned into sand", hz7.sand_cells(P).size() == 2 and hz7.sand_warning_cells(P).is_empty())


func _wind_tests() -> void:
	var st: CombatState = mk()
	var hz: TileHazards = hz_new(st, 5)
	hz.enable_wind(true)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	ck("wind: seeded direction among the 4", hz.wind_enabled() and dirs.has(hz.wind_dir()))
	var hz2: TileHazards = hz_new(mk(), 5)
	hz2.enable_wind(true)
	ck("wind: the same seed gives the same direction", hz.wind_dir() == hz2.wind_dir())
	var first: Vector2i = hz.wind_dir()
	var seen: Array = []
	hz.wind_changed.connect(func(d: Vector2i) -> void: seen.append(d))
	run(hz, st, 7.9)
	ck("wind: the direction holds until wind_shift_sec", hz.wind_dir() == first and seen.is_empty())
	run(hz, st, 0.2)
	ck("wind: the direction changes every wind_shift_sec", hz.wind_dir() != first and dirs.has(hz.wind_dir()) and seen.size() == 1)
	run(hz2, st, 8.1)
	ck("wind: the shift is seed-deterministic", hz2.wind_dir() == hz.wind_dir())
	hz.enable_wind(false)
	ck("wind: off gives (0,0)", hz.wind_dir() == Vector2i.ZERO and not hz.wind_enabled())

	# drift_due cadence follows drift_sec x drift mult.
	var st2: CombatState = mk()
	var hz3: TileHazards = hz_new(st2, 9)
	hz3.enable_wind(true)
	var box: Dictionary = {"n": 0}
	hz3.drift_due.connect(func() -> void: box["n"] += 1)
	run(hz3, st2, 1.9)
	ck("wind: no drift before drift_sec", box["n"] == 0)
	run(hz3, st2, 0.2)
	ck("wind: drift_due every drift_sec (2.0)", box["n"] == 1)
	hz3.set_drift_mult(0.5)
	box["n"] = 0
	run(hz3, st2, 4.0)
	ck("wind: drift_mult 0.5 doubles the cadence", box["n"] == 4)
	hz3.set_drift_mult(1.0)
	box["n"] = 0
	hz3.configure({"drift_sec": 1.0})
	run(hz3, st2, 3.0)
	ck("wind: drift_sec comes from the configured value", box["n"] == 3)


func _drift_tests() -> void:
	var grid: BoardGrid = BoardGrid.new(3, 3)
	var drops: FieldDrops = FieldDrops.new(FieldDropsConfig.new(), grid.player_cells(), 1)
	var moved: Array = []
	drops.point_moved.connect(func(p: FieldPoint, old: Vector2i) -> void: moved.append([p.cell, old]))
	var a: FieldPoint = drops.debug_place("a", Vector2i(0, 1), 50.0)
	ck("drift: a piece moves one cell along the direction", drops.drift_pieces(Vector2i(1, 0)) == 1 and a.cell == Vector2i(1, 1) and moved == [[Vector2i(1, 1), Vector2i(0, 1)]])
	drops.drift_pieces(Vector2i(1, 0))
	ck("drift: keeps going", a.cell == Vector2i(2, 1))
	ck("drift: never outside the half", drops.drift_pieces(Vector2i(1, 0)) == 0 and a.cell == Vector2i(2, 1))
	ck("drift: never off the top edge", drops.drift_pieces(Vector2i(0, -1)) == 1 and drops.drift_pieces(Vector2i(0, -1)) == 0 and a.cell == Vector2i(2, 0))
	ck("drift: direction (0,0) does nothing", drops.drift_pieces(Vector2i.ZERO) == 0)

	# Missing cell, sand cell, another piece, dragged piece.
	var holed: BoardGrid = BoardGrid.new(3, 3, cells([Vector2i(1, 1)]))
	var d2: FieldDrops = FieldDrops.new(FieldDropsConfig.new(), holed.player_cells(), 1)
	var m: FieldPoint = d2.debug_place("m", Vector2i(0, 1), 50.0)
	ck("drift: never into a missing cell", d2.drift_pieces(Vector2i(1, 0)) == 0 and m.cell == Vector2i(0, 1))
	var d3: FieldDrops = FieldDrops.new(FieldDropsConfig.new(), grid.player_cells(), 1)
	var s: FieldPoint = d3.debug_place("s", Vector2i(0, 0), 50.0)
	var sand_fn: Callable = func(cell: Vector2i) -> bool: return cell == Vector2i(1, 0)
	ck("drift: never into a sand cell", d3.drift_pieces(Vector2i(1, 0), sand_fn) == 0 and s.cell == Vector2i(0, 0))
	var d4: FieldDrops = FieldDrops.new(FieldDropsConfig.new(), grid.player_cells(), 1)
	var p1: FieldPoint = d4.debug_place("p1", Vector2i(0, 2), 50.0)
	var p2: FieldPoint = d4.debug_place("p2", Vector2i(1, 2), 50.0)
	ck("drift: never into a cell holding a piece, the free one moves", d4.drift_pieces(Vector2i(1, 0)) == 1 and p1.cell == Vector2i(0, 2) and p2.cell == Vector2i(2, 2))
	var d5: FieldDrops = FieldDrops.new(FieldDropsConfig.new(), grid.player_cells(), 1)
	var g: FieldPoint = d5.debug_place("g", Vector2i(0, 0), 50.0)
	var o: FieldPoint = d5.debug_place("o", Vector2i(0, 2), 50.0)
	ck("drift: a dragged piece does not drift, the others do", d5.drift_pieces(Vector2i(1, 0), Callable(), cells([Vector2i(0, 0)])) == 1 and g.cell == Vector2i(0, 0) and o.cell == Vector2i(1, 2))

	# Burial.
	var d6: FieldDrops = FieldDrops.new(FieldDropsConfig.new(), grid.player_cells(), 1)
	d6.debug_place("a", Vector2i(0, 0), 50.0)
	d6.debug_place("b", Vector2i(1, 0), 50.0)
	var expired: Dictionary = {"n": 0}
	d6.point_expired.connect(func(_p: FieldPoint) -> void: expired["n"] += 1)
	ck("bury: removes the pieces on those cells and reports the number", d6.bury_cells(cells([Vector2i(0, 0), Vector2i(2, 2)])) == 1 and d6.get_points().size() == 1 and expired["n"] == 1)

	# New drops land one cell along the wind when that cell is free.
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var cfg_a: FieldDropsConfig = FieldDropsConfig.new()
	cfg_a.initial_delay_sec = 0.0
	var cfg_b: FieldDropsConfig = FieldDropsConfig.new()
	cfg_b.initial_delay_sec = 0.0
	var plain: FieldDrops = FieldDrops.new(cfg_a, grid.player_cells(), 21)
	var windy: FieldDrops = FieldDrops.new(cfg_b, grid.player_cells(), 21)
	plain.enable_pieces(lib, "ch1", grid, 5)
	windy.enable_pieces(lib, "ch1", grid, 5)
	windy.wind_offset_fn = func() -> Vector2i: return Vector2i(1, 0)
	plain.tick(0.1, NO_UNIT, 0)
	windy.tick(0.1, NO_UNIT, 0)
	var pc: Vector2i = plain.get_points()[0].cell if not plain.get_points().is_empty() else NO_UNIT
	var wc: Vector2i = windy.get_points()[0].cell if not windy.get_points().is_empty() else NO_UNIT
	var expect: Vector2i = pc + Vector2i(1, 0) if grid.player_cells().has(pc + Vector2i(1, 0)) else pc
	ck("wind offset: a new drop lands one cell along the wind (same draw, shifted)", pc != NO_UNIT and wc == expect)


func _config_tests() -> void:
	var config: CombatConfig = CombatConfig.load_from_file()
	var h: Dictionary = config.hazards()
	var ok: bool = true
	for key: String in TileHazards.DEFAULTS:
		ok = ok and absf(float(h[key]) - float(TileHazards.DEFAULTS[key])) < EPS
	ck("config: combat.json hazards block mirrors the code defaults", ok and h.size() == TileHazards.DEFAULTS.size())
	var bad: CombatConfig = CombatConfig.from_dictionary({"hazards": {"mire_tick_sec": 0, "sand_cells": 3, "mire_step_mult": "x"}})
	var hb: Dictionary = bad.hazards()
	ck("config: a bad hazards value keeps its default, a good one applies", absf(float(hb["mire_tick_sec"]) - 0.5) < EPS and int(hb["sand_cells"]) == 3 and absf(float(hb["mire_step_mult"]) - 1.6) < EPS)
	ck("config: no hazards block gives the defaults", absf(float(CombatConfig.from_dictionary({}).hazards()["sand_sec"]) - 3.0) < EPS)
	var st: CombatState = mk()
	var hz: TileHazards = hz_new(st)
	hz.configure({"mire_step_mult": 2.0})
	hz.set_mire(P, cells([Vector2i(1, 1)]))
	ck("config: a match override changes the step cost", absf(hz.step_cost_mult(P, Vector2i(1, 1)) - 2.0) < EPS)


# --- Story 039: lava vents ---------------------------------------------------------------------------------

func row0() -> Array[Vector2i]:
	return cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])


func _vent_tests() -> void:
	var st: CombatState = mk() # player (1,1)
	var hz: TileHazards = hz_new(st, 4)
	hz.configure({"vent_interval_sec": 2.0, "vent_warn_sec": 0.5, "vent_sec": 1.0})
	hz.set_vents(P, [row0()])
	var mv: UnitMover = mover_for(st, P, hz)
	var box: Dictionary = {"warned": 0, "erupted": 0, "ended": 0, "cells": []}
	hz.vent_warned.connect(func(_s: int, _i: int, _c: Array[Vector2i]) -> void: box["warned"] += 1)
	hz.vent_erupted.connect(func(_s: int, _i: int, c: Array[Vector2i]) -> void:
		box["erupted"] += 1
		box["cells"] = c)
	hz.vent_ended.connect(func(_s: int, _i: int) -> void: box["ended"] += 1)
	ck("vent: the fixed streak cells are listed from the start", hz.vent_cells(P) == row0() and hz.vent_count(P) == 1 and not hz.is_venting(P, Vector2i(0, 0)))
	run(hz, st, 1.9)
	ck("vent: nothing before vent_interval_sec", box["warned"] == 0 and not hz.is_vent_warning(P, Vector2i(0, 0)))
	run(hz, st, 0.15)
	ck("vent: the warning starts on the beat", box["warned"] == 1 and hz.is_vent_warning(P, Vector2i(1, 0)) and not hz.is_venting(P, Vector2i(1, 0)) and hz.vent_warn_left(P, Vector2i(1, 0)) > 0.0)
	ck("vent: a warning vent never blocks a step", mv.try_step(Vector2i(0, -1)) and st.player_cell == Vector2i(1, 0))
	run(hz, st, 0.5)
	ck("vent: erupts after vent_warn_sec on all its cells", box["erupted"] == 1 and hz.is_venting(P, Vector2i(2, 0)) and box["cells"] == row0() and not hz.is_vent_warning(P, Vector2i(2, 0)))
	ck("vent: the other row is not venting", not hz.is_venting(P, Vector2i(1, 1)))
	run(hz, st, 1.0)
	ck("vent: ends after vent_sec", box["ended"] == 1 and not hz.is_venting(P, Vector2i(0, 0)))
	var before: int = int(box["warned"])
	run(hz, st, 0.5)
	ck("vent: the next vent follows one interval after the first", int(box["warned"]) == before + 1)

	# Burning through the same StatusEffects mechanism + pieces burnt (what CombatView does on vent_erupted).
	var st2: CombatState = mk()
	st2.set_player_cell(Vector2i(1, 0))
	var hz2: TileHazards = hz_new(st2, 4)
	hz2.configure({"vent_interval_sec": 1.0, "vent_warn_sec": 0.2, "vent_sec": 1.0})
	hz2.set_vents(P, [row0()])
	var status: StatusEffects = StatusEffects.new()
	var drops: FieldDrops = FieldDrops.new(FieldDropsConfig.new(), BoardGrid.new(3, 3).player_cells(), 1)
	drops.debug_place("on", Vector2i(2, 0), 50.0)
	drops.debug_place("off", Vector2i(2, 2), 50.0)
	var burnt: Dictionary = {"n": 0}
	hz2.vent_erupted.connect(func(_s: int, _i: int, c: Array[Vector2i]) -> void:
		status.ignite(c, hz2.config_value("vent_sec"), hz2.config_value("vent_tick_sec"), hz2.config_value("vent_tick_damage"))
		burnt["n"] += drops.bury_cells(c))
	var lit: Dictionary = {"all": false}
	for i: int in 25:
		hz2.tick(0.1, st2)
		status.tick(0.1, st2)
		if i == 15:
			lit["all"] = status.is_burning(Vector2i(0, 0)) and status.is_burning(Vector2i(1, 0)) and status.is_burning(Vector2i(2, 0)) and not status.is_burning(Vector2i(1, 1))
	ck("vent burn: the erupted cells are burning cells of the StatusEffects", bool(lit["all"]))
	ck("vent burn: a unit standing on the vent loses HP per tick", st2.player_hp < HP)
	ck("vent burn: the piece on the vent is burnt, the other stays", burnt["n"] == 1 and drops.get_points().size() == 1 and drops.get_points()[0].cell == Vector2i(2, 2))
	var s2: Dictionary = hz2.stats()
	ck("vent stats: ticks and damage are counted for the unit on the vent", int(s2["vent_ticks"]) >= 1 and float(s2["vent_damage_total"]) > 0.0 and int(s2["pushes"]) == 0)

	# Triggers: seeded pick, none without vents, prefer_cell first, count cap, busy vents skipped.
	var st3: CombatState = mk() # player (1,1)
	var hz3: TileHazards = hz_new(st3, 9)
	ck("vent trigger: no vent on the side gives false", not hz3.trigger_vent(P) and hz3.trigger_vents(P, 2) == 0)
	hz3.set_vents(P, [row0(), cells([Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]), cells([Vector2i(0, 2), Vector2i(1, 2)])])
	var order: Array = []
	hz3.vent_warned.connect(func(_s: int, i: int, _c: Array[Vector2i]) -> void: order.append(i))
	ck("vent trigger: trigger_vents starts the vent holding prefer_cell first", hz3.trigger_vents(P, 1, Vector2i(1, 1)) == 1 and order == [1])
	ck("vent trigger: a busy vent is not triggered again by index", not hz3.trigger_vent(P, 1))
	ck("vent trigger: count caps the number started, the busy one is skipped", hz3.trigger_vents(P, 5, Vector2i(1, 1)) == 2 and order.size() == 3)
	ck("vent trigger: nothing idle left gives false", not hz3.trigger_vent(P))
	var hz4: TileHazards = hz_new(mk(), 9)
	hz4.set_vents(P, [row0(), cells([Vector2i(0, 1)]), cells([Vector2i(0, 2)])])
	var hz5: TileHazards = hz_new(mk(), 9)
	hz5.set_vents(P, [row0(), cells([Vector2i(0, 1)]), cells([Vector2i(0, 2)])])
	var o4: Array = []
	var o5: Array = []
	hz4.vent_warned.connect(func(_s: int, i: int, _c: Array[Vector2i]) -> void: o4.append(i))
	hz5.vent_warned.connect(func(_s: int, i: int, _c: Array[Vector2i]) -> void: o5.append(i))
	hz4.trigger_vents(P, 3)
	hz5.trigger_vents(P, 3)
	ck("vent trigger: the seeded order is deterministic", o4 == o5 and o4.size() == 3)
	var hz6: TileHazards = hz_new(mk(), 9)
	hz6.set_vents(P, [row0()])
	var e6: Dictionary = {"n": 0}
	hz6.vent_erupted.connect(func(_s: int, _i: int, _c: Array[Vector2i]) -> void: e6["n"] += 1)
	ck("vent trigger: warn 0 erupts at once", hz6.trigger_vent(P, 0, 0.0) and e6["n"] == 1 and hz6.is_venting(P, Vector2i(0, 0)))

	# Vents on the enemy half run on the same clock; the interval mult speeds it up.
	var st7: CombatState = mk()
	var hz7: TileHazards = hz_new(st7, 2)
	hz7.configure({"vent_interval_sec": 2.0, "vent_warn_sec": 0.5, "vent_sec": 1.0})
	var enemy_cell: Vector2i = BoardGrid.new(3, 3).enemy_cells()[0]
	hz7.set_vents(E, [cells([enemy_cell])])
	var w7: Dictionary = {"side": -1, "n": 0}
	hz7.vent_warned.connect(func(s: int, _i: int, _c: Array[Vector2i]) -> void:
		w7["side"] = s
		w7["n"] += 1)
	hz7.set_vent_interval_mult(0.5)
	run(hz7, st7, 1.05)
	ck("vent clock: set_vent_interval_mult halves the cadence and enemy vents run too", w7["n"] == 1 and w7["side"] == E and absf(hz7.vent_timer_left() - 1.0) < 0.2)

	# No vents / no crumble: the model never draws a number or emits, stats stay 0.
	var hz8: TileHazards = hz_new(mk(), 2)
	run(hz8, mk(), 20.0)
	ck("vent idle: a model without vents stays silent", int(hz8.stats()["vent_ticks"]) == 0 and hz8.vent_timer_left() == 0.0 and not hz8.crumble_enabled())


# --- Story 039: crumbling cells and island drops -----------------------------------------------------------

func _crumble_tests() -> void:
	var st: CombatState = mk() # player (1,1)
	var hz: TileHazards = hz_new(st, 3)
	hz.enable_crumble(true)
	var mv: UnitMover = mover_for(st, P, hz)
	mv.add_blocker(func(cell: Vector2i) -> bool: return hz.is_fallen(P, cell))
	hz.extra_blocked_fn = func(side: int, cell: Vector2i) -> bool: return mv.is_cell_blocked(cell) if side == P else false
	var box: Dictionary = {"crumbling": 0, "fell": 0, "pushed": false, "restored": 0}
	# Count the player side only (the enemy half never crumbles).
	hz.cell_crumbling.connect(func(s: int, _c: Vector2i) -> void:
		if s == P:
			box["crumbling"] += 1)
	hz.cell_fell.connect(func(s: int, _c: Vector2i, p: bool) -> void:
		if s == P:
			box["fell"] += 1
			box["pushed"] = p)
	hz.cell_restored.connect(func(s: int, _c: Vector2i) -> void:
		if s == P:
			box["restored"] += 1)
	ck("crumble: enabled flag", hz.crumble_enabled())
	run(hz, st, 1.0)
	var prog: float = hz.crumble_progress(P, Vector2i(1, 1))
	ck("crumble: the standing timer shows its progress (0..1) while the unit stays", prog > 0.3 and prog < 0.7 and hz.crumble_progress(P, Vector2i(0, 0)) == 0.0)
	run(hz, st, 0.85)
	ck("crumble: nothing cracks before crumble_after_sec", box["crumbling"] == 0 and not hz.is_crumble_warning(P, Vector2i(1, 1)))
	run(hz, st, 0.3)
	ck("crumble: the cell cracks after crumble_after_sec of standing", box["crumbling"] == 1 and hz.is_crumble_warning(P, Vector2i(1, 1)) and hz.crumble_progress(P, Vector2i(1, 1)) == 1.0 and not hz.is_fallen(P, Vector2i(1, 1)))
	ck("crumble: a cracking cell can still be stepped on (a warning, not a wall)", not mv.is_cell_blocked(Vector2i(1, 1)))
	run(hz, st, 0.7)
	ck("crumble: it falls after crumble_warn_sec and the unit is pushed off", box["fell"] == 1 and bool(box["pushed"]) and hz.is_fallen(P, Vector2i(1, 1)) and st.player_cell != Vector2i(1, 1))
	var dist: int = absi(st.player_cell.x - 1) + absi(st.player_cell.y - 1)
	ck("crumble: the push lands on a neighbour of the fallen cell", dist == 1 and BoardGrid.new(3, 3).is_player_cell(st.player_cell))
	ck("crumble: a fallen cell blocks the step and lists a time bar", mv.is_cell_blocked(Vector2i(1, 1)) and hz.fallen_cells(P) == cells([Vector2i(1, 1)]) and absf(hz.fall_total_sec(P, Vector2i(1, 1)) - 4.0) < EPS and hz.fallen_left(P, Vector2i(1, 1)) > 3.0)
	var stats: Dictionary = hz.stats()
	ck("crumble: stats count the pushes (player only, the boss half never crumbles) and fall_damage", int(stats["pushes"]) == 1 and absf(float(stats["fall_damage_total"]) - 8.0) < EPS and absf(hz.config_value("fall_damage") - 8.0) < EPS)
	# Sky Isles return fade (ADR-0001 Phase 1, 2026-11-01): sampled inside cell_restored, i.e. the very moment (1,1) returns.
	hz.return_fade_sec = 0.5
	var back: Dictionary = {}
	hz.cell_restored.connect(func(s: int, c: Vector2i) -> void:
		if s == P and c == Vector2i(1, 1) and back.is_empty():
			back["fraction"] = hz.return_fraction(P, c)
			back["returning"] = hz.returning_cells(P).has(c)
			back["steppable"] = not mv.is_cell_blocked(c) and not hz.is_fallen(P, c))
	run(hz, st, 4.2)
	ck("crumble: the cell is restored after fall_sec", box["restored"] >= 1 and not hz.is_fallen(P, Vector2i(1, 1)) and not mv.is_cell_blocked(Vector2i(1, 1)))
	ck("crumble return: the fade starts at 1.0 (full white) the moment the cell returns", not back.is_empty() and absf(float(back["fraction"]) - 1.0) < EPS and bool(back["returning"]))
	ck("crumble return: the returning cell is steppable at once (the fade is presentation only)", bool(back.get("steppable", false)))
	run(hz, st, 0.6)
	ck("crumble return: the fade is over after return_fade_sec", hz.return_fraction(P, Vector2i(1, 1)) == 0.0 and not hz.returning_cells(P).has(Vector2i(1, 1)))

	# A unit that moves on before crumble_after_sec never crumbles the cell (the timer restarts per cell).
	var st2: CombatState = mk()
	var hz2: TileHazards = hz_new(st2, 3)
	hz2.enable_crumble(true)
	for i: int in 12:
		run(hz2, st2, 1.5)
		st2.set_player_cell(Vector2i(0, 1) if st2.player_cell == Vector2i(1, 1) else Vector2i(1, 1))
	ck("crumble: moving every 1.5 s keeps every cell standing", hz2.fallen_cells(P).is_empty() and not hz2.is_crumble_warning(P, Vector2i(1, 1)) and not hz2.is_crumble_warning(P, Vector2i(0, 1)))
	# Crumble off: nothing happens however long the unit stands.
	var st3: CombatState = mk()
	var hz3: TileHazards = hz_new(st3, 3)
	run(hz3, st3, 10.0)
	ck("crumble: off by default, a long stand changes nothing", hz3.fallen_cells(P).is_empty() and not hz3.crumble_enabled())
	# Only the player's half crumbles (user 2026-11-01): the boss standing still never cracks its own cell.
	var st4: CombatState = mk()
	var hz4: TileHazards = hz_new(st4, 3)
	hz4.enable_crumble(true)
	run(hz4, st4, 3.2)
	ck("crumble: the enemy side never crumbles under the boss", hz4.fallen_cells(E).is_empty() and not hz4.is_crumble_warning(E, Vector2i(4, 1)) and st4.enemy_cell == Vector2i(4, 1))
	ck("crumble: crumbles_side is player only", hz4.crumbles_side(P) and not hz4.crumbles_side(E))

	_island_tests()


# Split-island arena: player half cells (0,0),(0,1) = island A, (2,0),(2,1) = island B, the rest missing.
func split_holes() -> Array[Vector2i]:
	return cells([Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2), Vector2i(2, 2)])


func split_state(unit: Vector2i) -> CombatState:
	var grid: BoardGrid = BoardGrid.new(3, 3, split_holes())
	return CombatState.new(grid, HP, HP, unit, grid.enemy_cells()[0])


func split_hz(state: CombatState) -> TileHazards:
	var hz: TileHazards = TileHazards.new(BoardGrid.new(3, 3, split_holes()), 5)
	hz.bind_state(state)
	return hz


func _island_tests() -> void:
	var st: CombatState = split_state(Vector2i(0, 0))
	var hz: TileHazards = split_hz(st)
	var isl: Array = hz.islands(P)
	ck("islands: two components of real cells", isl.size() == 2 and (isl[0] as Array).size() == 2 and (isl[1] as Array).size() == 2)
	ck("islands: each component is one connected island", (isl[0] as Array).has(Vector2i(0, 0)) and (isl[0] as Array).has(Vector2i(0, 1)) and (isl[1] as Array).has(Vector2i(2, 0)))
	hz.enable_crumble(true)
	run(hz, st, 6.0)
	ck("leave-a-path: a unit on a 2-cell island never crumbles its cell (no way off the island afterwards)", hz.fallen_cells(P).is_empty() and not hz.is_crumble_warning(P, Vector2i(0, 0)) and st.player_cell == Vector2i(0, 0))

	# drop_cells: island B falls (never the unit's), warning then fall, then it is restored.
	var box: Dictionary = {"crumbling": 0, "fell": 0}
	hz.cell_crumbling.connect(func(_s: int, _c: Vector2i) -> void: box["crumbling"] += 1)
	hz.cell_fell.connect(func(_s: int, _c: Vector2i, _p: bool) -> void: box["fell"] += 1)
	var kept: Array[Vector2i] = hz.drop_cells(P, cells([Vector2i(2, 0), Vector2i(2, 1)]), 4.0, 1.2)
	ck("drop_cells: returns the cells kept and starts their crack warning", kept == cells([Vector2i(2, 0), Vector2i(2, 1)]) and box["crumbling"] == 2 and hz.is_crumble_warning(P, Vector2i(2, 0)))
	ck("drop_cells: islands() still counts the cracking cells as standing", hz.islands(P).size() == 2)
	run(hz, st, 1.1)
	ck("drop_cells: still cracking just before warn_sec", hz.fallen_cells(P).is_empty())
	run(hz, st, 0.2)
	ck("drop_cells: the island falls after warn_sec and blocks", box["fell"] == 2 and hz.is_fallen(P, Vector2i(2, 0)) and hz.is_fallen(P, Vector2i(2, 1)) and absf(hz.fall_total_sec(P, Vector2i(2, 0)) - 4.0) < EPS)
	ck("drop_cells: islands() now lists only the standing island", hz.islands(P).size() == 1)
	var again: Array[Vector2i] = hz.drop_cells(P, cells([Vector2i(2, 0)]))
	ck("drop_cells: an already fallen cell is not dropped twice", again.is_empty())
	var last: Array[Vector2i] = hz.drop_cells(P, cells([Vector2i(0, 0), Vector2i(0, 1)]))
	ck("drop_cells: never drops the whole last standing island (leave-a-path keeps the unit's neighbour)", last.size() <= 1 and not last.has(Vector2i(0, 1)))
	run(hz, st, 4.0)
	ck("drop_cells: the dropped island is restored after fall_sec", not hz.is_fallen(P, Vector2i(2, 0)) and hz.islands(P).size() == 2)

	# The last standing island of a side is never dropped when the unit has no way anywhere.
	var holes: Array[Vector2i] = []
	for cell: Vector2i in BoardGrid.new(3, 3).player_cells():
		if cell != Vector2i(0, 0):
			holes.append(cell)
	var one: BoardGrid = BoardGrid.new(3, 3, holes)
	var st1: CombatState = CombatState.new(one, HP, HP, Vector2i(0, 0), one.enemy_cells()[0])
	var hz1: TileHazards = TileHazards.new(one, 5)
	hz1.bind_state(st1)
	ck("drop_cells: a single remaining cell (the last island) never falls", hz1.drop_cells(P, cells([Vector2i(0, 0)])).is_empty() and hz1.islands(P).size() == 1)

	# One island out of two can be dropped.
	var st2: CombatState = split_state(Vector2i(0, 0))
	var hz2: TileHazards = split_hz(st2)
	var both: Array[Vector2i] = hz2.drop_cells(P, cells([Vector2i(2, 0), Vector2i(2, 1)]))
	ck("drop_cells: dropping one island out of two works", both.size() == 2)
	# A unit standing on a dropping cell is pushed to the nearest open cell when it falls.
	var st3: CombatState = split_state(Vector2i(2, 0))
	var hz3: TileHazards = split_hz(st3)
	hz3.drop_cells(P, cells([Vector2i(2, 0)]), 2.0, 0.3)
	var pushed: Dictionary = {"p": false}
	hz3.cell_fell.connect(func(_s: int, _c: Vector2i, p: bool) -> void: pushed["p"] = p)
	run(hz3, st3, 0.4)
	ck("drop_cells: the unit on the falling cell is pushed to the open cell next to it", bool(pushed["p"]) and st3.player_cell == Vector2i(2, 1) and hz3.is_fallen(P, Vector2i(2, 0)))

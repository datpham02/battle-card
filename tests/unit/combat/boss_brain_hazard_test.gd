extends SceneTree
## Story 036 Part A (W4): the boss brain reads the tile hazards. A mire cell of the boss's half costs
## mire_avoid x (mire_step_mult - 1 + mire_tick_damage) to step into (0 for a mire_immune boss), sand cells
## (filled and warning) are blocked for steps and paths, and with wind on a field piece that drifts before
## the boss gets there is targeted at its drift cell. Null hazards = the pre-036 decisions (same RNG draws).
## Story 039 (W4): crumble_avoid (cost of standing long on a cell of a crumble arena: the boss relocates instead of
## camping), fallen and cracking cells blocked in paths and steps, a warning vent scored like a burning cell about to
## be and an erupting vent as a burning cell. The brain-side checks run on a stub TileHazards (no dependency on the
## model timers); the last test drives the real TileHazards when it has the crumble API.
## Pure brain world, headless; FAILS=N. Deterministic: fixed seeds, noise 0 in the fixture config.

const SEED: int = 7
const THINK_SEC: float = 1.0
## Board of 3x3 per half: the boss's half is x 3..5 (x = 3 nearest the divider).
const SIDE_COLS: int = 3
const SIDE_ROWS: int = 3
const FRESH_SEC: float = 1000.0
## Long enough for a sand warning (sand_warn_sec 0.8 by default) to turn into filled sand.
const FILL_TICK_SEC: float = 1.0
const SAND_SEC: float = 30.0
const SAND_WARN_SEC: float = 0.8
## Halves drift_sec (2.0) so a two-step walk (2 x 0.55 s) is slower than the next drift.
const DRIFT_MULT: float = 0.5
const DECISIONS: int = 20
const ENEMY: int = CombatState.Side.ENEMY
const PLAYER: int = CombatState.Side.PLAYER


## Test double: the Story 039 state the brain reads, set by the test (no timers).
class StubHazards extends TileHazards:
	var crumble_on: bool = false
	var progress: float = 0.0
	var vents: Array[Vector2i] = []
	var vent_warn: Array[Vector2i] = []
	var vent_fire: Array[Vector2i] = []
	var fallen: Array[Vector2i] = []
	var cracking: Array[Vector2i] = []

	func _init(grid: BoardGrid, seed_value: int) -> void:
		super(grid, seed_value)

	func crumble_enabled() -> bool:
		return crumble_on

	# The stub lets the boss half crumble so the crumble_avoid scoring stays tested; the real TileHazards never does.
	func crumbles_side(_side: int) -> bool:
		return crumble_on

	func crumble_progress(_side: int, _cell: Vector2i) -> float:
		return progress

	func vent_cells(_side: int) -> Array[Vector2i]:
		return vents

	func is_venting(_side: int, cell: Vector2i) -> bool:
		return vent_fire.has(cell)

	func is_vent_warning(_side: int, cell: Vector2i) -> bool:
		return vent_warn.has(cell)

	func fallen_cells(_side: int) -> Array[Vector2i]:
		return fallen

	func is_crumble_warning(_side: int, cell: Vector2i) -> bool:
		return cracking.has(cell)

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	_test_dry_cell_preferred_over_mire()
	_test_mire_cost_ordered_by_set_weight()
	_test_immune_boss_ignores_mire()
	_test_sand_warning_never_stepped()
	_test_filled_sand_never_stepped()
	_test_sand_blocks_path()
	_test_pickup_follows_wind()
	_test_null_hazards_unchanged()
	_test_crumble_weights_in_every_set()
	_test_crumble_avoid_steers_off_long_stood_cell()
	_test_crumble_cost_ordered_by_set_weight()
	_test_fallen_cells_blocked()
	_test_cracking_cell_blocked_and_left()
	_test_vent_scoring()
	_test_idle_crumble_stub_identical_to_null()
	_test_real_tile_hazards_crumble()
	print("FAILS=%d" % fails)
	quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ fixtures

func _config(mire_avoid: float) -> BossBrainConfig:
	return BossBrainConfig.from_dictionary({
		"step_cooldown_sec": 0.55, "think_interval_sec": 0.0, "reaction_sec": 0.0, "noise": 0.0,
		"active_set": "t",
		"sets": {"t": {
			"dodge_danger": 10.0, "idle_bias": 0.2, "retreat_bonus": 0.0, "pickup_value": 2.0,
			"mire_avoid": mire_avoid, "combo_chance": 0.0,
			"movement": {
				"move_commitment": 1.0, "move_noise": 0.0, "reaction_sec": 0.0, "path_style": "shortest",
				"juke_chance": 0.0, "wander_when_idle": false,
			},
		}},
	})


# A brain world: empty piece hand (no cuts), no swing, the boss on [param boss_cell], one field point on
# [param piece_cell] (NO_CELL = none), a fresh TileHazards (not handed to the brain: the test decides).
func _world(config: BossBrainConfig, boss_cell: Vector2i, piece_cell: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(SIDE_COLS, SIDE_ROWS)
	var state := CombatState.new(grid, 1.0e6, 1.0e6, BoardGrid.NO_CELL, boss_cell)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 1.0e9
	var drops := FieldDrops.new(drops_config, grid.enemy_cells(), SEED)
	if piece_cell != BoardGrid.NO_CELL:
		drops.debug_place("A", piece_cell, FRESH_SEC)
	var hazards := TileHazards.new(grid, SEED)
	hazards.bind_state(state)
	var brain := BossBrain.new(config, grid, cut_config, skill_config, SEED)
	var ctx: Dictionary = {
		"state": state, "hand": HoldSlots.create_piece_hand(3), "drops": drops,
		"mover": UnitMover.new(state, CombatState.Side.ENEMY, config.step_cooldown_sec),
		"actor": CutActor.new(cut_config, CombatState.Side.ENEMY), "cooldowns": SkillCooldowns.new(),
		"player_actor": CutActor.new(cut_config, CombatState.Side.PLAYER), "status": StatusEffects.new(),
	}
	return {"brain": brain, "ctx": ctx, "state": state, "hazards": hazards, "grid": grid}


func _decide(w: Dictionary) -> Dictionary:
	var brain: BossBrain = w["brain"]
	brain.tick(THINK_SEC, false)
	return brain.decide(w["ctx"])


func _dir_of(action: Dictionary) -> Vector2i:
	if str(action.get("type", "")) != "move":
		return Vector2i.ZERO
	return action["direction"] as Vector2i


# Walks up to [param steps] decisions, moving the boss on each move; returns the visited cells.
func _walk(w: Dictionary, steps: int) -> Array[Vector2i]:
	var state: CombatState = w["state"]
	var visited: Array[Vector2i] = [state.enemy_cell]
	for i: int in steps:
		var dir: Vector2i = _dir_of(_decide(w))
		if dir == Vector2i.ZERO:
			continue
		state.set_enemy_cell(state.enemy_cell + dir)
		visited.append(state.enemy_cell)
	return visited


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in list:
		out.append(cell)
	return out


# ------------------------------------------------------------------ tests

# From (3,0) to a piece on (4,1) both first steps are equal; the tie goes horizontal to (4,0). A mire on
# (4,0) makes that path dearer, so the boss steps down to the dry (3,1) instead.
func _test_dry_cell_preferred_over_mire() -> void:
	var dry: Dictionary = _world(_config(1.0), Vector2i(3, 0), Vector2i(4, 1))
	(dry["brain"] as BossBrain).set_hazards(dry["hazards"])
	var dry_dir: Vector2i = _dir_of(_decide(dry))
	_check("no mire: tie goes horizontal into (4,0)", dry_dir == Vector2i(1, 0), str(dry_dir))
	var wet: Dictionary = _world(_config(1.0), Vector2i(3, 0), Vector2i(4, 1))
	(wet["hazards"] as TileHazards).set_mire(CombatState.Side.ENEMY, _cells([Vector2i(4, 0)]))
	(wet["brain"] as BossBrain).set_hazards(wet["hazards"])
	var wet_dir: Vector2i = _dir_of(_decide(wet))
	_check("mire on (4,0): the boss steps into the dry (3,1)", wet_dir == Vector2i(0, 1), str(wet_dir))
	var hz: Dictionary = (wet["brain"] as BossBrain).last_debug().get("hazards", {})
	var pen: float = float((hz.get("mire_pen", {}) as Dictionary).get(Vector2i(4, 0), 0.0))
	# mire_avoid 1.0 x (mire_step_mult 1.6 - 1 + mire_tick_damage 0.5) with the shipped hazard defaults.
	var expected: float = 1.0 * (float(TileHazards.DEFAULTS["mire_step_mult"]) - 1.0 + float(TileHazards.DEFAULTS["mire_tick_damage"]))
	_check("mire cost in last_debug = weight x unit cost", absf(pen - expected) < 0.0001, "%f vs %f" % [pen, expected])


# The shipped sets price the same mire cell aggressive < balanced < cautious (0.5 / 1.0 / 1.5 x unit cost).
func _test_mire_cost_ordered_by_set_weight() -> void:
	var costs: Dictionary = {}
	for set_name: String in ["aggressive", "balanced", "cautious"]:
		var config: BossBrainConfig = BossBrainConfig.load_from_file()
		var w: Dictionary = _world(config, Vector2i(3, 0), Vector2i(4, 1))
		var brain: BossBrain = w["brain"]
		_check("set %s exists" % set_name, brain.use_set(set_name))
		(w["hazards"] as TileHazards).set_mire(CombatState.Side.ENEMY, _cells([Vector2i(4, 0)]))
		brain.set_hazards(w["hazards"])
		_decide(w)
		var hz: Dictionary = brain.last_debug().get("hazards", {})
		costs[set_name] = float((hz.get("mire_pen", {}) as Dictionary).get(Vector2i(4, 0), -1.0))
	var ok: bool = float(costs["aggressive"]) > 0.0 and float(costs["aggressive"]) < float(costs["balanced"]) \
			and float(costs["balanced"]) < float(costs["cautious"])
	_check("mire cost aggressive < balanced < cautious", ok, str(costs))
	var unit: float = float(TileHazards.DEFAULTS["mire_step_mult"]) - 1.0 + float(TileHazards.DEFAULTS["mire_tick_damage"])
	_check("shipped weights 0.5 / 1.0 / 1.5", absf(float(costs["aggressive"]) - 0.5 * unit) < 0.0001
			and absf(float(costs["balanced"]) - unit) < 0.0001 and absf(float(costs["cautious"]) - 1.5 * unit) < 0.0001, str(costs))


# A mire_immune boss pays nothing for mire: it takes the tie-break path through (4,0) as on dry ground.
func _test_immune_boss_ignores_mire() -> void:
	var w: Dictionary = _world(_config(1.5), Vector2i(3, 0), Vector2i(4, 1))
	var hazards: TileHazards = w["hazards"]
	hazards.set_mire(CombatState.Side.ENEMY, _cells([Vector2i(4, 0)]))
	hazards.set_mire_immune(CombatState.Side.ENEMY, true)
	(w["brain"] as BossBrain).set_hazards(hazards)
	var dir: Vector2i = _dir_of(_decide(w))
	_check("immune boss steps into the mire (4,0)", dir == Vector2i(1, 0), str(dir))
	var hz: Dictionary = (w["brain"] as BossBrain).last_debug().get("hazards", {})
	_check("immune: no mire cost, flagged", (hz.get("mire_pen", {}) as Dictionary).is_empty() and bool(hz.get("mire_immune", false)), str(hz))


# A sand WARNING cell is never stepped into (the tie-break cell (4,0) is avoided).
func _test_sand_warning_never_stepped() -> void:
	var w: Dictionary = _world(_config(1.0), Vector2i(3, 0), Vector2i(4, 1))
	var hazards: TileHazards = w["hazards"]
	var kept: Array[Vector2i] = hazards.add_sand(CombatState.Side.ENEMY, _cells([Vector2i(4, 0)]), SAND_SEC, SAND_WARN_SEC)
	_check("sand warning laid on (4,0)", kept.has(Vector2i(4, 0)) and hazards.is_sand_warning(CombatState.Side.ENEMY, Vector2i(4, 0)), str(kept))
	(w["brain"] as BossBrain).set_hazards(hazards)
	var dir: Vector2i = _dir_of(_decide(w))
	_check("warning cell not stepped: boss goes (0,1)", dir == Vector2i(0, 1), str(dir))


# Filled sand is never stepped into either.
func _test_filled_sand_never_stepped() -> void:
	var w: Dictionary = _world(_config(1.0), Vector2i(3, 0), Vector2i(4, 1))
	var hazards: TileHazards = w["hazards"]
	hazards.add_sand(CombatState.Side.ENEMY, _cells([Vector2i(4, 0)]), SAND_SEC, SAND_WARN_SEC)
	hazards.tick(FILL_TICK_SEC, w["state"])
	_check("sand filled on (4,0)", hazards.is_sanded(CombatState.Side.ENEMY, Vector2i(4, 0)))
	(w["brain"] as BossBrain).set_hazards(hazards)
	var dir: Vector2i = _dir_of(_decide(w))
	_check("filled sand not stepped: boss goes (0,1)", dir == Vector2i(0, 1), str(dir))
	var hz: Dictionary = (w["brain"] as BossBrain).last_debug().get("hazards", {})
	_check("sand cell listed as blocked in last_debug", (hz.get("sand_blocked", []) as Array).has(Vector2i(4, 0)), str(hz))


# Sand on (4,1) between the boss (3,1) and the piece (5,1): the walk goes around and never enters it.
func _test_sand_blocks_path() -> void:
	var w: Dictionary = _world(_config(1.0), Vector2i(3, 1), Vector2i(5, 1))
	var hazards: TileHazards = w["hazards"]
	var kept: Array[Vector2i] = hazards.add_sand(CombatState.Side.ENEMY, _cells([Vector2i(4, 1)]), SAND_SEC, SAND_WARN_SEC)
	_check("sand laid on (4,1)", kept.has(Vector2i(4, 1)), str(kept))
	(w["brain"] as BossBrain).set_hazards(hazards)
	var visited: Array[Vector2i] = _walk(w, 8)
	_check("path never enters the sand cell", not visited.has(Vector2i(4, 1)), str(visited))
	_check("boss still reaches the piece around the sand", visited.has(Vector2i(5, 1)) and visited.size() == 5, str(visited))


# With wind on, a piece two steps away (2 x 0.55 s > drift in 1.0 s) is targeted at its drift cell; the
# destination stays valid while the piece has not drifted yet. Wind off: the piece's own cell.
func _test_pickup_follows_wind() -> void:
	var piece: Vector2i = Vector2i(4, 1)
	var calm: Dictionary = _world(_config(1.0), Vector2i(3, 0), piece)
	(calm["brain"] as BossBrain).set_hazards(calm["hazards"])
	_decide(calm)
	var calm_dest: Dictionary = (calm["brain"] as BossBrain).get_destination()
	_check("wind off: pickup aims at the piece cell", calm_dest.get("cell", BoardGrid.NO_CELL) == piece, str(calm_dest))
	var w: Dictionary = _world(_config(1.0), Vector2i(3, 0), piece)
	var hazards: TileHazards = w["hazards"]
	hazards.enable_wind(true)
	hazards.set_drift_mult(DRIFT_MULT)
	var dir: Vector2i = hazards.wind_dir()
	var drift_cell: Vector2i = piece + dir
	# The boss starts on a corner that is not the drift cell, two steps from the centre piece.
	var start: Vector2i = Vector2i(3, 0) if drift_cell != Vector2i(3, 0) else Vector2i(5, 2)
	(w["state"] as CombatState).set_enemy_cell(start)
	var brain: BossBrain = w["brain"]
	brain.set_hazards(hazards)
	_decide(w)
	var dest: Dictionary = brain.get_destination()
	_check("wind %s: pickup aims at the drift cell %s" % [dir, drift_cell], dest.get("cell", BoardGrid.NO_CELL) == drift_cell, str(dest))
	var drift: Array = (brain.last_debug().get("hazards", {}) as Dictionary).get("pickup_drift", [])
	_check("pickup drift in last_debug", drift.size() == 1 and (drift[0] as Dictionary).get("to") == drift_cell, str(drift))
	_decide(w)
	_check("destination kept while the piece has not drifted yet", brain.get_destination().get("cell", BoardGrid.NO_CELL) == drift_cell,
			str(brain.get_destination()))


# A TileHazards with nothing active gives the same decisions as no hazards (null) with the shipped noisy
# balanced set: the hazard code draws no RNG. Without hazards last_debug has no "hazards" key.
func _test_null_hazards_unchanged() -> void:
	var runs: Array[Array] = []
	for with_hazards: bool in [false, true]:
		var w: Dictionary = _world(BossBrainConfig.load_from_file(), Vector2i(5, 2), Vector2i(3, 0))
		if with_hazards:
			(w["brain"] as BossBrain).set_hazards(w["hazards"])
		var seq: Array = []
		var state: CombatState = w["state"]
		for i: int in DECISIONS:
			var action: Dictionary = _decide(w)
			seq.append([str(action["type"]), _dir_of(action), (w["brain"] as BossBrain).get_destination()])
			if _dir_of(action) != Vector2i.ZERO:
				state.set_enemy_cell(state.enemy_cell + _dir_of(action))
		if not with_hazards:
			_check("null hazards: no hazards key in last_debug", not (w["brain"] as BossBrain).last_debug().has("hazards"))
		runs.append(seq)
	_check("idle hazards = null hazards decisions", str(runs[0]) == str(runs[1]), str(runs[0]))


# ------------------------------------------------------------------ Story 039

const CENTER: Vector2i = Vector2i(4, 1)


# Config for the Story 039 tests: like _config but with crumble_avoid.
func _config_crumble(crumble_avoid: float) -> BossBrainConfig:
	return BossBrainConfig.from_dictionary({
		"step_cooldown_sec": 0.55, "think_interval_sec": 0.0, "reaction_sec": 0.0, "noise": 0.0,
		"active_set": "t",
		"sets": {"t": {
			"dodge_danger": 10.0, "idle_bias": 0.2, "retreat_bonus": 0.0, "pickup_value": 2.0,
			"crumble_avoid": crumble_avoid, "combo_chance": 0.0,
			"movement": {
				"move_commitment": 1.0, "move_noise": 0.0, "reaction_sec": 0.0, "path_style": "shortest",
				"juke_chance": 0.0, "wander_when_idle": false,
			},
		}},
	})


# Same world as _world with a StubHazards handed to the brain.
func _stub_world(config: BossBrainConfig, boss_cell: Vector2i, piece_cell: Vector2i) -> Dictionary:
	var w: Dictionary = _world(config, boss_cell, piece_cell)
	var stub := StubHazards.new(w["grid"], SEED)
	stub.bind_state(w["state"])
	w["stub"] = stub
	(w["brain"] as BossBrain).set_hazards(stub)
	return w


func _crumble_debug(w: Dictionary) -> Dictionary:
	var hz: Dictionary = (w["brain"] as BossBrain).last_debug().get("hazards", {})
	return hz.get("crumble", {}) as Dictionary


# The weight exists with the default and in every shipped set: balanced 1.0, aggressive 0.5, cautious 1.5.
func _test_crumble_weights_in_every_set() -> void:
	_check("default weight crumble_avoid 1.0", float(BossBrainConfig.DEFAULT_WEIGHTS.get("crumble_avoid", -1.0)) == 1.0)
	var config: BossBrainConfig = BossBrainConfig.load_from_file()
	var want: Dictionary = {"balanced": 1.0, "aggressive": 0.5, "cautious": 1.5}
	for set_name: String in want.keys():
		var got: float = float(config.weights_for(set_name).get("crumble_avoid", -1.0))
		_check("set %s crumble_avoid = %.1f" % [set_name, float(want[set_name])], absf(got - float(want[set_name])) < 0.0001, str(got))


# On a crumble arena an idle boss waits at first, then walks off the cell once the standing timer is near the
# crack; with crumble_avoid 0 it camps; without a crumble arena it camps too.
func _test_crumble_avoid_steers_off_long_stood_cell() -> void:
	var w: Dictionary = _stub_world(_config_crumble(1.0), CENTER, BoardGrid.NO_CELL)
	(w["stub"] as StubHazards).crumble_on = true
	var first: Dictionary = _decide(w)
	_check("crumble: first think on a fresh cell waits", str(first["type"]) == "wait", str(first))
	_check("crumble: debug has the stand state", _crumble_debug(w).has("stand_sec") and bool(_crumble_debug(w).get("on", false)), str(_crumble_debug(w)))
	var second: Dictionary = _decide(w)
	_check("crumble: after 1 s of standing the boss relocates", str(second["type"]) == "move" and str((w["brain"] as BossBrain).last_debug().get("purpose", "")) == "crumble", str(second))
	var dbg: Dictionary = _crumble_debug(w)
	_check("crumble: leave flagged, cost > 0", bool(dbg.get("leave", false)) and float(dbg.get("cost", 0.0)) > 0.0, str(dbg))
	var dest: Vector2i = (w["brain"] as BossBrain).get_destination().get("cell", BoardGrid.NO_CELL)
	_check("crumble: destination is another own cell", dest != CENTER and (w["grid"] as BoardGrid).is_enemy_cell(dest), str(dest))
	var camp: Dictionary = _stub_world(_config_crumble(0.0), CENTER, BoardGrid.NO_CELL)
	(camp["stub"] as StubHazards).crumble_on = true
	var camped: bool = true
	for i: int in 4:
		camped = camped and str(_decide(camp)["type"]) == "wait"
	_check("crumble_avoid 0: the boss camps", camped)
	var dry: Dictionary = _stub_world(_config_crumble(1.0), CENTER, BoardGrid.NO_CELL)
	var stayed: bool = true
	for i: int in 4:
		stayed = stayed and str(_decide(dry)["type"]) == "wait"
	_check("no crumble arena: the boss stays put", stayed)
	var moved: Dictionary = _stub_world(_config_crumble(1.0), CENTER, BoardGrid.NO_CELL)
	(moved["stub"] as StubHazards).crumble_on = true
	_decide(moved)
	_decide(moved)
	(moved["state"] as CombatState).set_enemy_cell(Vector2i(3, 1))
	_decide(moved)
	_check("standing timer restarts on a new cell", float(_crumble_debug(moved).get("stand_sec", -1.0)) == 0.0, str(_crumble_debug(moved)))


# The model's own timer counts too: progress 0.5 gives each set its weighted cost at once.
func _test_crumble_cost_ordered_by_set_weight() -> void:
	var damage: float = float(TileHazards.DEFAULTS.get("fall_damage", 8.0))
	var costs: Dictionary = {}
	for set_name: String in ["aggressive", "balanced", "cautious"]:
		var w: Dictionary = _stub_world(BossBrainConfig.load_from_file(), CENTER, BoardGrid.NO_CELL)
		_check("set %s exists (crumble)" % set_name, (w["brain"] as BossBrain).use_set(set_name))
		var stub: StubHazards = w["stub"]
		stub.crumble_on = true
		stub.progress = 0.5
		_decide(w)
		costs[set_name] = float(_crumble_debug(w).get("cost", -1.0))
	var ok: bool = float(costs["aggressive"]) > 0.0 and float(costs["aggressive"]) < float(costs["balanced"]) \
			and float(costs["balanced"]) < float(costs["cautious"])
	_check("crumble cost aggressive < balanced < cautious", ok, str(costs))
	_check("shipped weights 0.5 / 1.0 / 1.5 x fall_damage x fraction", absf(float(costs["aggressive"]) - 0.5 * damage * 0.5) < 0.0001
			and absf(float(costs["balanced"]) - damage * 0.5) < 0.0001 and absf(float(costs["cautious"]) - 1.5 * damage * 0.5) < 0.0001, str(costs))


# A fallen cell is blocked for paths and steps: the walk goes around it; a relocation never picks it.
func _test_fallen_cells_blocked() -> void:
	var w: Dictionary = _stub_world(_config_crumble(1.0), Vector2i(3, 1), Vector2i(5, 1))
	(w["stub"] as StubHazards).fallen = _cells([Vector2i(4, 1)])
	var visited: Array[Vector2i] = _walk(w, 8)
	_check("fallen cell: path never enters it", not visited.has(Vector2i(4, 1)), str(visited))
	_check("fallen cell: boss still reaches the piece around it", visited.has(Vector2i(5, 1)) and visited.size() == 5, str(visited))
	var hz: Dictionary = (w["brain"] as BossBrain).last_debug().get("hazards", {})
	_check("fallen cell listed in crumble_blocked", (hz.get("crumble_blocked", []) as Array).has(Vector2i(4, 1)), str(hz.get("crumble_blocked")))
	# Relocation off a cracking cell with three of four neighbours fallen: the only way out is (4,2).
	var r: Dictionary = _stub_world(_config_crumble(1.0), CENTER, BoardGrid.NO_CELL)
	var stub: StubHazards = r["stub"]
	stub.crumble_on = true
	stub.progress = 1.0
	stub.fallen = _cells([Vector2i(3, 1), Vector2i(5, 1), Vector2i(4, 0)])
	var dir: Vector2i = _dir_of(_decide(r))
	_check("relocation never steps onto fallen cells: goes (0,1)", dir == Vector2i(0, 1), str(dir))


# A cell in its crack warning is blocked like a sealed cell (the tie-break cell (4,0) is avoided), and a boss
# standing on a cracking cell steps off at once.
func _test_cracking_cell_blocked_and_left() -> void:
	var w: Dictionary = _stub_world(_config_crumble(1.0), Vector2i(3, 0), Vector2i(4, 1))
	(w["stub"] as StubHazards).cracking = _cells([Vector2i(4, 0)])
	var dir: Vector2i = _dir_of(_decide(w))
	_check("cracking cell not stepped: boss goes (0,1)", dir == Vector2i(0, 1), str(dir))
	var r: Dictionary = _stub_world(_config_crumble(1.0), CENTER, BoardGrid.NO_CELL)
	var stub: StubHazards = r["stub"]
	stub.crumble_on = true
	stub.progress = 1.0
	stub.cracking = _cells([CENTER])
	var action: Dictionary = _decide(r)
	_check("standing on a cracking cell: relocates on the first think", str(action["type"]) == "move" and str((r["brain"] as BossBrain).last_debug().get("purpose", "")) == "crumble", str(action))
	var other: Dictionary = _stub_world(_config_crumble(1.0), Vector2i(3, 0), Vector2i(4, 1))
	(other["stub"] as StubHazards).fallen = _cells([Vector2i(1, 1)])
	_decide(other)
	var hz: Dictionary = (other["brain"] as BossBrain).last_debug().get("hazards", {})
	_check("a fallen cell of the player's half is listed too", (hz.get("crumble_blocked", []) as Array).has(Vector2i(1, 1)), str(hz.get("crumble_blocked")))


# A warning vent is a burning cell about to be and an erupting vent a burning cell: neither is stepped into; an idle
# vent (only the red streak) is walked like any cell.
func _test_vent_scoring() -> void:
	var idle: Dictionary = _stub_world(_config(1.0), Vector2i(3, 0), Vector2i(4, 1))
	(idle["stub"] as StubHazards).vents = _cells([Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	var idle_dir: Vector2i = _dir_of(_decide(idle))
	_check("idle vent streak is walked: boss goes (1,0)", idle_dir == Vector2i(1, 0), str(idle_dir))
	var idle_hz: Dictionary = (idle["brain"] as BossBrain).last_debug().get("hazards", {})
	_check("idle vent is not blocked", (idle_hz.get("vent_blocked", [1]) as Array).is_empty(), str(idle_hz.get("vent_blocked")))
	for phase: String in ["warning", "erupting"]:
		var w: Dictionary = _stub_world(_config(1.0), Vector2i(3, 0), Vector2i(4, 1))
		var stub: StubHazards = w["stub"]
		stub.vents = _cells([Vector2i(4, 0)])
		if phase == "warning":
			stub.vent_warn = _cells([Vector2i(4, 0)])
		else:
			stub.vent_fire = _cells([Vector2i(4, 0)])
		var dir: Vector2i = _dir_of(_decide(w))
		_check("%s vent not stepped: boss goes (0,1)" % phase, dir == Vector2i(0, 1), str(dir))
		var hz: Dictionary = (w["brain"] as BossBrain).last_debug().get("hazards", {})
		_check("%s vent listed in vent_blocked" % phase, (hz.get("vent_blocked", []) as Array).has(Vector2i(4, 0)), str(hz.get("vent_blocked")))
	# A walk across a warning vent line goes around it (the line (4,1) is in the way of (3,1) -> (5,1)).
	var path: Dictionary = _stub_world(_config(1.0), Vector2i(3, 1), Vector2i(5, 1))
	(path["stub"] as StubHazards).vents = _cells([Vector2i(4, 1)])
	(path["stub"] as StubHazards).vent_warn = _cells([Vector2i(4, 1)])
	var visited: Array[Vector2i] = _walk(path, 8)
	_check("warning vent blocks the path", not visited.has(Vector2i(4, 1)) and visited.has(Vector2i(5, 1)), str(visited))
	# A vent on the player's half is a blocked escape cell too (listed in the debug).
	var side: Dictionary = _stub_world(_config(1.0), Vector2i(3, 0), Vector2i(4, 1))
	(side["stub"] as StubHazards).vents = _cells([Vector2i(1, 1)])
	(side["stub"] as StubHazards).vent_fire = _cells([Vector2i(1, 1)])
	_decide(side)
	var side_hz: Dictionary = (side["brain"] as BossBrain).last_debug().get("hazards", {})
	_check("player-half erupting vent is listed", (side_hz.get("vent_blocked", []) as Array).has(Vector2i(1, 1)), str(side_hz.get("vent_blocked")))


# A hazards object with nothing active (crumble off, no vents, nothing fallen) gives the same decisions as no
# hazards with the shipped noisy balanced set: the new code draws no RNG until a crumble arena or a vent matters.
func _test_idle_crumble_stub_identical_to_null() -> void:
	var runs: Array[Array] = []
	for with_stub: bool in [false, true]:
		var w: Dictionary = _world(BossBrainConfig.load_from_file(), Vector2i(5, 2), Vector2i(3, 0))
		if with_stub:
			var stub := StubHazards.new(w["grid"], SEED)
			(w["brain"] as BossBrain).set_hazards(stub)
		var seq: Array = []
		var state: CombatState = w["state"]
		for i: int in DECISIONS:
			var action: Dictionary = _decide(w)
			seq.append([str(action["type"]), _dir_of(action), (w["brain"] as BossBrain).get_destination()])
			if _dir_of(action) != Vector2i.ZERO:
				state.set_enemy_cell(state.enemy_cell + _dir_of(action))
		runs.append(seq)
	_check("idle stub hazards = null hazards decisions (RNG draws)", str(runs[0]) == str(runs[1]), str(runs[0]))


# With the real TileHazards: only the player's half crumbles (user 2026-11-01), so a boss standing still on a
# crumble arena builds no progress, the brain sees crumble off for its half and never pays a crumble cost.
func _test_real_tile_hazards_crumble() -> void:
	var w: Dictionary = _world(_config_crumble(1.0), CENTER, BoardGrid.NO_CELL)
	var hazards: TileHazards = w["hazards"]
	hazards.call("enable_crumble", true)
	(w["brain"] as BossBrain).set_hazards(hazards)
	var state: CombatState = w["state"]
	# The player stands elsewhere; the boss does not move for 3.2 s of model time (crumble_after_sec 2.0).
	for i: int in 32:
		hazards.tick(0.1, state)
	_check("real hazards: the boss half builds no crumble_progress", float(hazards.call("crumble_progress", ENEMY, CENTER)) == 0.0)
	_decide(w)
	var dbg: Dictionary = _crumble_debug(w)
	_check("real hazards: the brain sees crumble off for its half, no cost", not bool(dbg.get("on", true)) and float(dbg.get("cost", 1.0)) == 0.0, str(dbg))
	_check("real hazards: the boss cell never cracks or falls", not bool(hazards.call("is_fallen", ENEMY, CENTER)) 			and not bool(hazards.call("is_crumble_warning", ENEMY, CENTER)))

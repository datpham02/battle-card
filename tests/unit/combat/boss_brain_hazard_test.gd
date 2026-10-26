extends SceneTree
## Story 036 Part A (W4): the boss brain reads the tile hazards. A mire cell of the boss's half costs
## mire_avoid x (mire_step_mult - 1 + mire_tick_damage) to step into (0 for a mire_immune boss), sand cells
## (filled and warning) are blocked for steps and paths, and with wind on a field piece that drifts before
## the boss gets there is targeted at its drift cell. Null hazards = the pre-036 decisions (same RNG draws).
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

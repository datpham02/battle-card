extends SceneTree
## Story 027 Phan B: the boss brain understands zones on its own half. A sealed cell is a blocked cell
## for every path / dodge search (never entered, and a boss standing in one can still leave); a thorn
## cell costs thorn_avoid x its damage: the boss dodges THROUGH a thorn when the incoming swing would hurt
## more than the thorn cost and it cannot get around in time, goes around when the thorns cost more, and
## always goes around when the detour arrives in time. Pure brain world, headless; FAILS=N.
## Deterministic: noise 0, move_noise 0, commitment 1, juke 0, no wander, fixed seed.

const SEED: int = 7
const THINK_SEC: float = 1.0
## Board of 3x3 per half: the boss's half is x 3..5.
const SIDE_COLS: int = 3
const SIDE_ROWS: int = 3
## Damage of the thorn laid in the tests (the cost compared against the swing).
const THORN_DAMAGE: float = 6.0
## A swing the boss cannot walk two cells away from in time (boss step 0.55 s) / one it easily can.
const SHORT_TIME_LEFT: float = 0.3
const LONG_TIME_LEFT: float = 5.0

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	_test_grid_layout()
	_test_seal_blocks_dodge_path()
	_test_boss_leaves_seal_it_stands_in()
	_test_thorn_cheaper_than_swing_goes_through()
	_test_thorn_dearer_than_swing_goes_around()
	_test_thorn_detour_in_time_goes_around()
	_test_non_dodge_path_avoids_thorn()
	_test_weight_loaded()
	print("FAILS=%d" % fails)
	quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ fixtures

func _config(thorn_avoid: float) -> BossBrainConfig:
	var config: BossBrainConfig = BossBrainConfig.from_dictionary({
		"step_cooldown_sec": 0.55, "think_interval_sec": 0.0, "reaction_sec": 0.0, "noise": 0.0,
		"active_set": "t",
		"sets": {"t": {
			"dodge_danger": 10.0, "idle_bias": 0.2, "retreat_bonus": 0.0, "pickup_value": 2.0,
			"thorn_avoid": thorn_avoid, "combo_chance": 0.0,
			"movement": {
				"move_commitment": 1.0, "move_noise": 0.0, "reaction_sec": 0.0, "path_style": "shortest",
				"juke_chance": 0.0, "wander_when_idle": false,
			},
		}},
	})
	return config


# A brain world: empty piece hand (no cuts), status effects, the player swinging [param swing] with
# [param time_left] seconds of wind-up, the boss on [param boss_cell].
func _world(thorn_avoid: float, boss_cell: Vector2i, swing: Array[Vector2i], time_left: float) -> Dictionary:
	var grid := BoardGrid.new(SIDE_COLS, SIDE_ROWS)
	var state := CombatState.new(grid, 1.0e6, 1.0e6, BoardGrid.NO_CELL, boss_cell)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var config: BossBrainConfig = _config(thorn_avoid)
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 1.0e9
	var player_actor := CutActor.new(cut_config, CombatState.Side.PLAYER)
	if not swing.is_empty():
		player_actor.begin_swing(swing, SkillConfig.FALLBACK_SKILL, true, 1, time_left)
	var status := StatusEffects.new()
	var brain := BossBrain.new(config, grid, cut_config, skill_config, SEED)
	var ctx: Dictionary = {
		"state": state, "hand": HoldSlots.create_piece_hand(3),
		"drops": FieldDrops.new(drops_config, grid.enemy_cells(), SEED),
		"mover": UnitMover.new(state, CombatState.Side.ENEMY, config.step_cooldown_sec),
		"actor": CutActor.new(cut_config, CombatState.Side.ENEMY), "cooldowns": SkillCooldowns.new(),
		"player_actor": player_actor, "status": status,
	}
	return {"grid": grid, "state": state, "brain": brain, "ctx": ctx, "status": status, "cut_config": cut_config}


func _decide(w: Dictionary) -> Dictionary:
	var brain: BossBrain = w["brain"]
	brain.tick(THINK_SEC, true)
	return brain.decide(w["ctx"])


# Every cell of the boss's half except column x = 3 (the swing the boss must dodge out of).
func _swing_all_but_front() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in [4, 5]:
		for y: int in SIDE_ROWS:
			cells.append(Vector2i(x, y))
	return cells


# Walks up to [param steps] decisions, moving the boss on each move; returns the visited cells.
func _walk(w: Dictionary, steps: int) -> Array[Vector2i]:
	var state: CombatState = w["state"]
	var visited: Array[Vector2i] = [state.enemy_cell]
	for i: int in steps:
		var action: Dictionary = _decide(w)
		if str(action["type"]) != "move":
			continue
		state.set_enemy_cell(state.enemy_cell + (action["direction"] as Vector2i))
		visited.append(state.enemy_cell)
	return visited


# ------------------------------------------------------------------ tests

func _test_grid_layout() -> void:
	var grid := BoardGrid.new(SIDE_COLS, SIDE_ROWS)
	_check("fixture: the boss's half is x 3..5", grid.is_enemy_cell(Vector2i(3, 0)) and grid.is_enemy_cell(Vector2i(5, 2))
		and not grid.is_enemy_cell(Vector2i(2, 0)))


func _test_seal_blocks_dodge_path() -> void:
	var w: Dictionary = _world(1.0, Vector2i(4, 1), _swing_all_but_front(), LONG_TIME_LEFT)
	var sealed: Array[Vector2i] = [Vector2i(3, 1)]
	(w["status"] as StatusEffects).apply_seal(CombatState.Side.ENEMY, sealed, 10.0)
	var visited: Array[Vector2i] = _walk(w, 4)
	var end: Vector2i = (w["state"] as CombatState).enemy_cell
	_check("seal: the boss never enters the sealed cell", not visited.has(Vector2i(3, 1)), str(visited))
	_check("seal: the boss still dodges out of the swing (around the seal)", end.x == 3 and end != Vector2i(3, 1), str(visited))
	var plan: Dictionary = (w["brain"] as BossBrain).last_debug().get("dodge_plan", {})
	# Without the seal the nearest safe cell would be the sealed one (1 step).
	var w2: Dictionary = _world(1.0, Vector2i(4, 1), _swing_all_but_front(), LONG_TIME_LEFT)
	var free_action: Dictionary = _decide(w2)
	_check("control: without the seal the boss steps straight to (3,1)", free_action.get("direction") == Vector2i(-1, 0), str(free_action))
	_check("seal: dodge plan never aims at the sealed cell", plan.is_empty() or plan.get("cell") != Vector2i(3, 1), str(plan))


func _test_boss_leaves_seal_it_stands_in() -> void:
	var swing: Array[Vector2i] = [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)]
	var w: Dictionary = _world(1.0, Vector2i(3, 1), swing, LONG_TIME_LEFT)
	var sealed: Array[Vector2i] = [Vector2i(3, 1)]
	(w["status"] as StatusEffects).apply_seal(CombatState.Side.ENEMY, sealed, 10.0)
	var action: Dictionary = _decide(w)
	_check("seal under the boss: it still steps out of the swing", action.get("direction") == Vector2i(1, 0), str(action))


func _test_thorn_cheaper_than_swing_goes_through() -> void:
	var w: Dictionary = _world(1.0, Vector2i(4, 1), _swing_all_but_front(), SHORT_TIME_LEFT)
	var thorn: Array[Vector2i] = [Vector2i(3, 1)]
	(w["status"] as StatusEffects).apply_thorns(CombatState.Side.ENEMY, thorn, 10.0, THORN_DAMAGE, 1)
	var swing_damage: float = (w["cut_config"] as CutConfig).slash_damage(6)
	var action: Dictionary = _decide(w)
	var debug: Dictionary = (w["brain"] as BossBrain).last_debug()
	var plan: Dictionary = debug.get("dodge_plan", {})
	_check("fixture: thorn cost 1.0 x 6 < the swing's damage", 1.0 * THORN_DAMAGE < swing_damage, "dmg=%.1f" % swing_damage)
	_check("thorn cheaper than the swing: the boss steps onto the thorn", action.get("direction") == Vector2i(-1, 0), str(action))
	_check("dodge plan: aims at the thorn, pays its cost, not late",
		plan.get("cell") == Vector2i(3, 1) and is_equal_approx(float(plan.get("thorn_cost", -1.0)), THORN_DAMAGE)
		and not bool(plan.get("late", true)), str(plan))
	_check("debug breakdown carries the thorn term", (debug.get("breakdown", {}) as Dictionary).has("thorn"), str(debug.get("breakdown")))


func _test_thorn_dearer_than_swing_goes_around() -> void:
	var avoid: float = 10.0
	var w: Dictionary = _world(avoid, Vector2i(4, 1), _swing_all_but_front(), SHORT_TIME_LEFT)
	var thorn: Array[Vector2i] = [Vector2i(3, 1)]
	(w["status"] as StatusEffects).apply_thorns(CombatState.Side.ENEMY, thorn, 10.0, THORN_DAMAGE, 1)
	var swing_damage: float = (w["cut_config"] as CutConfig).slash_damage(6)
	_check("fixture: thorn cost 10 x 6 > the swing's damage", avoid * THORN_DAMAGE > swing_damage, "dmg=%.1f" % swing_damage)
	var visited: Array[Vector2i] = _walk(w, 3)
	_check("thorn dearer than the swing: the boss never enters the thorn", not visited.has(Vector2i(3, 1)), str(visited))
	_check("thorn dearer than the swing: the boss goes around (sideways first)",
		visited.size() >= 2 and visited[1].x == 4, str(visited))


func _test_thorn_detour_in_time_goes_around() -> void:
	var w: Dictionary = _world(1.0, Vector2i(4, 1), _swing_all_but_front(), LONG_TIME_LEFT)
	var thorn: Array[Vector2i] = [Vector2i(3, 1)]
	(w["status"] as StatusEffects).apply_thorns(CombatState.Side.ENEMY, thorn, 10.0, THORN_DAMAGE, 1)
	var visited: Array[Vector2i] = _walk(w, 3)
	var end: Vector2i = (w["state"] as CombatState).enemy_cell
	_check("detour in time: the boss walks around the thorn", not visited.has(Vector2i(3, 1)) and end.x == 3, str(visited))


func _test_non_dodge_path_avoids_thorn() -> void:
	# No swing: the brain is asked for a step toward a far cell through its path search.
	var w: Dictionary = _world(1.0, Vector2i(3, 1), [] as Array[Vector2i], 0.0)
	var thorn: Array[Vector2i] = [Vector2i(4, 1)]
	(w["status"] as StatusEffects).apply_thorns(CombatState.Side.ENEMY, thorn, 10.0, THORN_DAMAGE, 1)
	var brain: BossBrain = w["brain"]
	brain.tick(THINK_SEC, false)
	brain.decide(w["ctx"]) # builds the thorn costs
	var dir: Vector2i = brain._step_toward(Vector2i(3, 1), Vector2i(5, 1), BossBrain.STYLE_SHORTEST, [] as Array[Vector2i])
	_check("path search: a thorn on the straight line is walked around", dir == Vector2i(0, -1) or dir == Vector2i(0, 1), str(dir))
	var sealed: Array[Vector2i] = [Vector2i(3, 0), Vector2i(3, 2)]
	var dir2: Vector2i = brain._step_toward(Vector2i(3, 1), Vector2i(5, 1), BossBrain.STYLE_SHORTEST, sealed)
	_check("path search: when the only way is through the thorn, it is taken", dir2 == Vector2i(1, 0), str(dir2))


func _test_weight_loaded() -> void:
	var config: BossBrainConfig = BossBrainConfig.load_from_file()
	var ok: bool = true
	for set_name: String in config.set_names():
		ok = ok and config.weights_for(set_name).has("thorn_avoid")
	_check("boss_brain.json: every set has thorn_avoid", ok)
	_check("BossBrainConfig default thorn_avoid", BossBrainConfig.DEFAULT_WEIGHTS.has("thorn_avoid"))

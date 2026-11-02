extends SceneTree
## P2.4 Forest Witch (design/quick-specs/phase2-misty-forest-2026-11-01.md section 4, 7, 9 P2.4; D13): every one of her
## seven skills passes the fairness rules on boss_hall and on 200 seeded variants of it (ArenaVariants through
## ArenaLibrary.grid_for_spec; a variant her 2x2 footprint cannot stand on is skipped and counted). Each grid plays all
## three phases (HP driven through 65 % / 30 % by one huge hit) with the perfect-dodger bot, and the test re-checks,
## independently of the controller, at the moment EVERY warning starts:
##   F1 / F9  FairnessCheck.can_hero_respond with the hero's real lock (step cooldown left, Frozen, Root) and step time;
##   F2       warning + queued stripe (Withered Crown's second lane) within FairnessCheck.red_cap of the usable floor;
##   F5       two warnings start >= min_gap_between_warnings_sec apart;
##   F6       FloorLayer.pattern_telegraph_state paints exactly those red cells (reduce motion on and off);
##   F10      after a heavy skill (recovery >= heavy_recovery_sec) the next warning starts no sooner than its recovery
##            and one step + margin after its last strike;
## and F4 on a standing-still bot (Root Nail roots it): a new Root lands only after the last one ended + cc_grace_sec.
## F3 / F7 / F8 have nothing to bite on (no zone, no crack, no trait on the Witch). Also: the dodger takes 0 damage on
## every grid and every skill is cast (no skill silently unusable on boss_hall).
## Run: godot --headless --path . -s res://tests/unit/combat/forest_witch_fairness_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const FloorLayerScript := preload("res://src/battle/floor_layer.gd")
const P: int = CombatState.Side.PLAYER
const ENEMY: String = "forest_witch"
const ARENA: String = "boss_hall"
const VARIANTS: int = 200
const PHASE_SEC: float = 30.0
const ENEMY_HP: float = 770.0
const HUGE_HIT: float = 100000.0
const STILL_SEC: float = 40.0
const _EPS: float = 0.0001

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	_check("shipped enemy_skills.json has no problems", cfg.problems.is_empty(), str(cfg.problems))
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	var grids: Array[BoardGrid] = [ArenaLibrary.grid_for_spec({"shape": ARENA}, library, 0)]
	for s: int in range(1, VARIANTS + 1):
		grids.append(ArenaLibrary.grid_for_spec({"shape": ARENA, "variant": true}, library, s))
	var tally: Dictionary = {"grids": 0, "skipped": 0, "warnings": 0, "f1": [], "f2": [], "f5": [], "f6": [], "f10": [], "hurt": [], "cast": {}}
	for gi: int in grids.size():
		if grids[gi] == null:
			tally["skipped"] = int(tally["skipped"]) + 1
			continue
		_play(cfg, grids[gi], gi, tally)
	var key: String = "forest_witch on boss_hall + %d variants (%d grids played, %d skipped, %d warnings)" % [VARIANTS, int(tally["grids"]),
		int(tally["skipped"]), int(tally["warnings"])]
	_check("%s: most variants playable" % key, int(tally["grids"]) >= VARIANTS / 2)
	for rule: String in ["f1", "f2", "f5", "f6", "f10"]:
		_check("%s %s holds at every warning" % [key, rule.to_upper()], (tally[rule] as Array).is_empty(), str((tally[rule] as Array).slice(0, 3)))
	_check("%s perfect dodger never hurt" % key, (tally["hurt"] as Array).is_empty(), str((tally["hurt"] as Array).slice(0, 3)))
	var silent: Array[String] = []
	for phase: Dictionary in cfg.get_enemy(ENEMY)["phases"]:
		for sid: String in phase["skills"]:
			if not (tally["cast"] as Dictionary).has(sid) and not silent.has(sid):
				silent.append(sid)
	_check("%s every skill is cast" % key, silent.is_empty(), "silent=%s cast=%s" % [silent, tally["cast"]])
	_check_f4_on_still_bot(cfg, library)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _play(cfg: EnemySkillsConfig, grid: BoardGrid, seed_value: int, tally: Dictionary) -> void:
	var w: Dictionary = Fx.world(grid, cfg, ENEMY, seed_value, ENEMY_HP)
	var state: CombatState = w["state"]
	if state.enemy_footprint_size() != 4:
		tally["skipped"] = int(tally["skipped"]) + 1
		return
	tally["grids"] = int(tally["grids"]) + 1
	var status: StatusEffects = w["status"]
	var mover: UnitMover = w["mover"]
	var ctrl: PatternController = w["ctrl"]
	var margin: float = float(cfg.fairness["reaction_margin_sec"])
	var ratio: float = float(cfg.fairness["max_red_ratio"])
	var min_gap: float = float(cfg.fairness["min_gap_between_warnings_sec"])
	var heavy: float = float(cfg.fairness["heavy_recovery_sec"])
	var combat_config: CombatConfig = CombatConfig.new()
	var tag: String = "grid%d" % seed_value
	var clock: Array[float] = [0.0]
	var last_warning: Array[float] = [-1000.0]
	var after_heavy: Dictionary = {}  # {t: last strike time, recovery: sec} of the last heavy skill, cleared at the next warning
	var on_warning: Callable = func(id: String, cells: Array[Vector2i], queued: Array[Vector2i], warning_sec: float) -> void:
		tally["warnings"] = int(tally["warnings"]) + 1
		var env: Dictionary = ctrl.fairness_env()
		var lock: float = FairnessCheck.lock_left(mover.get_cooldown_remaining(), status.get_pin_left(P), status.get_root_left(P))
		var step_cd: float = ctrl.player_step_cd * status.step_mult(P)
		if not FairnessCheck.can_hero_respond(grid, state.player_cell, cells, warning_sec, lock, step_cd, margin, env):
			(tally["f1"] as Array).append("%s %s at %s on %s lock %.2f" % [tag, id, cells, state.player_cell, lock])
		if not FairnessCheck.red_ok(cells, queued, FairnessCheck.usable_floor(grid, env), ratio):
			(tally["f2"] as Array).append("%s %s %d+%d red" % [tag, id, cells.size(), queued.size()])
		if clock[0] - last_warning[0] + _EPS < min_gap:
			(tally["f5"] as Array).append("%s %s %.2f s after the last warning" % [tag, id, clock[0] - last_warning[0]])
		last_warning[0] = clock[0]
		for reduce: bool in [false, true]:
			var painted: Dictionary = FloorLayerScript.pattern_telegraph_state(ctrl, combat_config, reduce)
			if painted.is_empty() or painted["cells"] != cells:
				(tally["f6"] as Array).append("%s %s painted %s vs red %s (reduce %s)" % [tag, id, painted.get("cells", []), cells, reduce])
		if not after_heavy.is_empty() and str(after_heavy["skill"]) != id:  # its own followup is the same skill
			var since: float = clock[0] - float(after_heavy["t"])
			var need: float = maxf(float(after_heavy["recovery"]), step_cd + margin)
			if since + _EPS < need:
				(tally["f10"] as Array).append("%s %s %.2f s after heavy %s (need %.2f)" % [tag, id, since, after_heavy["skill"], need])
			after_heavy.clear()
	ctrl.warning_started.connect(on_warning)
	var on_resolved: Callable = func(id: String, _result: Dictionary) -> void:
		(tally["cast"] as Dictionary)[id] = true
		var skill: Dictionary = cfg.skills.get(id, {}) as Dictionary
		if float(skill.get("recovery_sec", 0.0)) + _EPS >= heavy:
			after_heavy["t"] = clock[0]
			after_heavy["recovery"] = float(skill["recovery_sec"]) * ctrl.tempo_mult
			after_heavy["skill"] = id
	ctrl.skill_resolved.connect(on_resolved)
	var on_tick: Callable = func(t: float) -> void:
		clock[0] = t
	var t0: float = 0.0
	for phase: int in 3:
		if phase > 0:
			state.damage_enemy(HUGE_HIT)
		var base: float = t0
		Fx.run(ctrl, state, status, mover, PHASE_SEC, "dodge", 0.05, func(t: float) -> void: on_tick.call(base + t))
		t0 += PHASE_SEC
	if state.player_hp < state.player_max_hp - _EPS:
		(tally["hurt"] as Array).append("%s hp %.1f" % [tag, state.player_hp])


# F4: a standing-still hero gets rooted by Root Nail; every new Root starts no sooner than the last one ended plus
# cc_grace_sec (StatusEffects' own clock), never while rooted. With the shipped numbers Root Nail's own cycle (windup +
# warning + recovery + cooldown) is longer than Root + grace, so the check also runs a STRESS copy of her: Root Nail
# alone with windup / recovery / cooldown 0 (phase overrides), where only the controller's F4 gate keeps the grace.
func _check_f4_on_still_bot(cfg: EnemySkillsConfig, library: ArenaLibrary) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH)) as Dictionary
	(data["enemies"] as Dictionary)["f4_stress"] = {"tier": "warden", "footprint": [[0, 0], [1, 0], [0, 1], [1, 1]], "phases": [{"id": "solo",
		"skills": ["root_nail"], "overrides": {"root_nail": {"windup_sec": 0.0, "recovery_sec": 0.0, "cooldown_sec": 0.0}}}]}
	var stress: EnemySkillsConfig = EnemySkillsConfig.from_dictionary(data)
	for enemy_id: String in [ENEMY, "f4_stress"]:
		_f4_for(stress, library, enemy_id)


func _f4_for(cfg: EnemySkillsConfig, library: ArenaLibrary, enemy_id: String) -> void:
	var grace: float = float(cfg.fairness["cc_grace_sec"])
	var roots: Array[int] = [0]  # an array: a lambda captures locals by value
	var early: Array[String] = []
	for s: int in [1, 2, 3, 4, 5]:
		var w: Dictionary = Fx.world(ArenaLibrary.grid_for_spec({"shape": ARENA}, library, s), cfg, enemy_id, s, ENEMY_HP)
		var state: CombatState = w["state"]
		state.player_max_hp = 100000.0
		state.player_hp = 100000.0
		var status: StatusEffects = w["status"]
		var clock: Array[float] = [0.0]
		var last_end: Array[float] = [-1000.0]
		var was_rooted: Array[bool] = [false]
		(w["ctrl"] as PatternController).skill_resolved.connect(func(_id: String, result: Dictionary) -> void:
			if str(result.get("status", "")) == "root":
				roots[0] += 1
				if was_rooted[0] or clock[0] - last_end[0] + _EPS < grace:
					early.append("seed %d t %.2f last end %.2f rooted %s" % [s, clock[0], last_end[0], was_rooted[0]]))
		Fx.run(w["ctrl"], state, status, w["mover"], STILL_SEC, "still", 0.05, func(t: float) -> void:
			var rooted: bool = status.get_root_left(P) > 0.0
			if was_rooted[0] and not rooted:
				last_end[0] = t
			was_rooted[0] = rooted
			clock[0] = t)
	_check("F4 %s: Root Nail roots the standing hero (%d roots)" % [enemy_id, roots[0]], roots[0] > 0)
	_check("F4 %s: no Root on a rooted hero nor within cc_grace_sec after one" % enemy_id, early.is_empty(), str(early.slice(0, 3)))

extends SceneTree
## 2026-11-03 Goblin Warlock (design/quick-specs/doi-hinh-rung-suong-2026-11-03.md §3.5, §8 R2): the floor 1-2 boss's
## five skills pass the fairness rules on boss_hall and on 200 seeded variants of it, the same checks as the Forest
## Witch's fairness test: at the moment EVERY warning starts F1 / F9 (can_hero_respond with the hero's real lock), F2
## (warning + the queued second shape of twin_shapes within red_cap), F5 (gap), F6 (the floor paints exactly the red
## cells, reduce motion on and off), F10 (after a heavy skill). Both phases are played (HP driven below 50 % by one huge
## hit). The dodger takes 0 damage on every grid and every skill is cast. No Root / zone / crack on the Warlock, so
## F3 / F4 / F7 / F8 have nothing to bite on.
## Run: godot --headless --path . -s res://tests/unit/combat/goblin_warlock_fairness_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const FloorLayerScript := preload("res://src/battle/floor_layer.gd")
const P: int = CombatState.Side.PLAYER
const ENEMY: String = "goblin_warlock"
const ARENA: String = "boss_hall"
const VARIANTS: int = 200
const PHASE_SEC: float = 30.0
const ENEMY_HP: float = 561.0
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
	var key: String = "goblin_warlock on boss_hall + %d variants (%d grids played, %d skipped, %d warnings)" % [VARIANTS, int(tally["grids"]),
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
	for phase: int in (cfg.get_enemy(ENEMY)["phases"] as Array).size():
		if phase > 0:
			state.damage_enemy(HUGE_HIT)
		var base: float = t0
		Fx.run(ctrl, state, status, mover, PHASE_SEC, "dodge", 0.05, func(t: float) -> void: on_tick.call(base + t))
		t0 += PHASE_SEC
	if state.player_hp < state.player_max_hp - _EPS:
		(tally["hurt"] as Array).append("%s hp %.1f" % [tag, state.player_hp])



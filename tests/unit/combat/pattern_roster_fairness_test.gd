extends SceneTree
## Phase 2 P2.3 (design/quick-specs/phase2-misty-forest-2026-11-01.md 4.2, 9 P2.3, 10): every skill of the five Misty
## Forest pattern enemies passes the fairness rules on EVERY ch1 arena shape (square, rect, u_shape, cross, staircase)
## and on 200 seeded variants of each (ArenaVariants through ArenaLibrary.grid_for_spec), whichever enemy's own arena
## that is. Each grid plays a short headless match per enemy (perfect-dodger bot, real StatusEffects / UnitMover) and
## re-checks, independently of the controller's own choice, at the moment EVERY warning starts:
##   F1 / F9  FairnessCheck.can_hero_respond with the hero's real lock (step cooldown left, Frozen, Root) and step time;
##   F2       the red (warning + queued stripe) fits FairnessCheck.red_cap of the usable floor;
## and at every zone it leaves (seedbed Thorns, bark_shift drop tile):
##   F3       the hero keeps a neighbour cell outside the zone that is not a hole / cracking.
## Also: the dodger takes 0 damage on every grid, and every skill is cast on every arena shape (no skill silently
## unusable on a ch1 shape).
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_roster_fairness_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
# 2026-11-03 (doi-hinh-rung-suong spec §3): the goblins and wolves on the pattern brain join the five.
const ENEMIES: Array[String] = ["rootling", "mossbound_sentry", "greycap_sporeling", "ancient_root_sentinel", "mistbriar_matron",
	"goblin_scout", "goblin_archer", "dire_wolf", "wolf_alpha"]
const SHAPES: Array[String] = ["square", "rect", "u_shape", "cross", "staircase"]
const VARIANTS: int = 200
const MATCH_SEC: float = 60.0
const AIM_EVERY_SEC: float = 1.5
const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	_check("shipped enemy_skills.json has no problems", cfg.problems.is_empty(), str(cfg.problems))
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	for shape: String in SHAPES:
		var grids: Array[BoardGrid] = [ArenaLibrary.grid_for_spec({"shape": shape}, library, 0)]
		for s: int in range(1, VARIANTS + 1):
			grids.append(ArenaLibrary.grid_for_spec({"shape": shape, "variant": true}, library, s))
		for enemy_id: String in ENEMIES:
			var tally: Dictionary = {"grids": 0, "warnings": 0, "f1": [], "f2": [], "f3": [], "hurt": [], "cast": {}}
			for gi: int in grids.size():
				if grids[gi] == null:
					continue
				tally["grids"] = int(tally["grids"]) + 1
				_play(cfg, enemy_id, grids[gi], gi, tally)
			var key: String = "%s on %s (+%d variants, %d grids, %d warnings)" % [enemy_id, shape, VARIANTS, int(tally["grids"]), int(tally["warnings"])]
			_check("%s F1: every warning escapable in time" % key, (tally["f1"] as Array).is_empty(), str((tally["f1"] as Array).slice(0, 3)))
			_check("%s F2: red within the ceiling" % key, (tally["f2"] as Array).is_empty(), str((tally["f2"] as Array).slice(0, 3)))
			_check("%s F3: a zone always leaves an exit" % key, (tally["f3"] as Array).is_empty(), str((tally["f3"] as Array).slice(0, 3)))
			_check("%s perfect dodger never hurt" % key, (tally["hurt"] as Array).is_empty(), str((tally["hurt"] as Array).slice(0, 3)))
			var silent: Array[String] = []
			for phase: Dictionary in cfg.get_enemy(enemy_id)["phases"]:
				for sid: String in phase["skills"]:
					if not (tally["cast"] as Dictionary).has(sid):
						silent.append(sid)
			_check("%s every skill is usable" % key, silent.is_empty(), "silent=%s" % str(silent))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _play(cfg: EnemySkillsConfig, enemy_id: String, grid: BoardGrid, seed_value: int, tally: Dictionary) -> void:
	var w: Dictionary = Fx.world(grid, cfg, enemy_id, seed_value, 1000.0)
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var mover: UnitMover = w["mover"]
	var ctrl: PatternController = w["ctrl"]
	var margin: float = float(cfg.fairness["reaction_margin_sec"])
	var ratio: float = float(cfg.fairness["max_red_ratio"])
	var tag: String = "grid%d" % seed_value
	var on_warning: Callable = func(id: String, cells: Array[Vector2i], queued: Array[Vector2i], warning_sec: float) -> void:
		tally["warnings"] = int(tally["warnings"]) + 1
		var env: Dictionary = ctrl.fairness_env()
		var lock: float = FairnessCheck.lock_left(mover.get_cooldown_remaining(), status.get_pin_left(P), status.get_root_left(P))
		var step_cd: float = ctrl.player_step_cd * status.step_mult(P)
		if not FairnessCheck.can_hero_respond(grid, state.player_cell, cells, warning_sec, lock, step_cd, margin, env):
			(tally["f1"] as Array).append("%s %s at %s on %s lock %.2f" % [tag, id, cells, state.player_cell, lock])
		if not FairnessCheck.red_ok(cells, queued, FairnessCheck.usable_floor(grid, env), ratio):
			(tally["f2"] as Array).append("%s %s %d+%d red" % [tag, id, cells.size(), queued.size()])
	ctrl.warning_started.connect(on_warning)
	var on_resolved: Callable = func(id: String, result: Dictionary) -> void:
		(tally["cast"] as Dictionary)[id] = true
		var zone: Array = result.get("zone_cells", []) as Array
		if zone.is_empty():
			return
		var exit: bool = false
		for d: Vector2i in _DIRS:
			var n: Vector2i = state.player_cell + d
			if grid.is_player_cell(n) and not zone.has(n) and not status.is_hole(P, n) and not status.is_cracking(P, n):
				exit = true
		if not exit:
			(tally["f3"] as Array).append("%s %s zone %s around %s" % [tag, id, zone, state.player_cell])
	ctrl.skill_resolved.connect(on_resolved)
	var next_aim: Array[float] = [AIM_EVERY_SEC]
	var hurt_enemy: Array[bool] = [false]
	var on_tick: Callable = func(t: float) -> void:
		if t >= next_aim[0]:
			next_aim[0] += AIM_EVERY_SEC
			ctrl.on_player_aim(state.enemy_footprint_cells())
		if not hurt_enemy[0] and t >= MATCH_SEC * 0.5:
			hurt_enemy[0] = true
			state.enemy_hp = state.enemy_max_hp * 0.45
	Fx.run(ctrl, state, status, mover, MATCH_SEC, "dodge", 0.05, on_tick)
	ctrl.warning_started.disconnect(on_warning)
	ctrl.skill_resolved.disconnect(on_resolved)
	if state.player_hp < state.player_max_hp - 0.0001:
		(tally["hurt"] as Array).append("%s hp %.1f" % [tag, state.player_hp])

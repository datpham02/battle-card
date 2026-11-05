extends SceneTree
## P2.4 Forest Witch (design/quick-specs/phase2-misty-forest-2026-11-01.md 7.2-7.3, 9 P2.4, 10; decisions D9, D13, D14):
## the headless 3-phase sim on boss_hall with her 2x2 footprint and the real StatusEffects / UnitMover.
## - perfect dodger (walks FairnessCheck.escape_path when its cell is red): 0 damage over 180 s of EACH phase (spec 9),
##   her HP driven down through the 65 % / 30 % thresholds by one huge hit per phase;
## - standing-still bot: damaged;
## - each phase casts every skill of its list and nothing outside it (no withered_crown / moss_guard in phase 1, no
##   forest_last_knot before phase 3);
## - phase 3: forest_last_knot (weight 0) is cast ONLY as the 3rd, 6th... cast of the phase (every_nth 3), and at most
##   of those turns;
## - the footprint stays 2x2 and fitting the whole time, and no root anchor ever lands under it.
## Run: godot --headless --path . -s res://tests/unit/combat/forest_witch_phases_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const ENEMY: String = "forest_witch"
const ARENA: String = "boss_hall"
const SEEDS: Array[int] = [1, 2, 3]
const PHASE_SEC: float = 180.0
## Effective HP at floor 3 (written 1210 x 0.6375 at P2.4, spec 5.1 / D8; written is 1090 since 2026-11-05); only the ratio matters here.
const ENEMY_HP: float = 770.0
const HUGE_HIT: float = 100000.0
const STEP: float = 0.05

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	_check("shipped enemy_skills.json has no problems", cfg.problems.is_empty(), str(cfg.problems))
	var enemy: Dictionary = cfg.get_enemy(ENEMY)
	_check("forest_witch: 3 phases", (enemy.get("phases", []) as Array).size() == 3)
	if (enemy.get("phases", []) as Array).size() != 3:
		print("FAILS=%d" % fails)
		quit(1)
		return
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	var cast_by_phase: Array[Dictionary] = [{}, {}, {}]
	var knot_turns: Array[int] = [0, 0]  # [multiples of 3 seen in phase 3, of which the knot]
	var knot_off_turn: Array[String] = []
	for s: int in SEEDS:
		var w: Dictionary = Fx.world(ArenaLibrary.grid_for_spec({"shape": ARENA}, library, s), cfg, ENEMY, s, ENEMY_HP)
		var state: CombatState = w["state"]
		var ctrl: PatternController = w["ctrl"]
		var bad_body: Array[String] = []
		ctrl.markers_changed.connect(func() -> void:
			for m: Vector2i in ctrl.marker_cells():
				if state.enemy_footprint_cells().has(m) or not state.grid.is_enemy_cell(m):
					bad_body.append("seed %d marker %s body %s" % [s, m, state.enemy_footprint_cells()]))
		var fits: Array[bool] = [true]
		var check_body: Callable = func(_t: float) -> void:
			fits[0] = fits[0] and state.enemy_footprint_size() == 4 and state.enemy_fits(state.enemy_cell)
		for phase: int in 3:
			if phase > 0:
				var before: float = state.enemy_hp
				state.damage_enemy(HUGE_HIT)
				var threshold: float = float((enemy["phases"][phase] as Dictionary)["enter_hp_ratio"]) * state.enemy_max_hp
				_check("seed %d: one huge hit stops at the phase-%d threshold (%.0f -> %.1f)" % [s, phase + 1, before, state.enemy_hp],
					is_equal_approx(state.enemy_hp, threshold))
			Fx.run(ctrl, state, w["status"], w["mover"], PHASE_SEC, "dodge", STEP, check_body)
			_check("seed %d: phase %d reached and held (index %d)" % [s, phase + 1, ctrl.get_phase_index()], ctrl.get_phase_index() == phase)
		_check("seed %d: perfect dodger takes 0 damage over 3 x %.0f s" % [s, PHASE_SEC], is_equal_approx(state.player_hp, state.player_max_hp),
			"hp=%.1f" % state.player_hp)
		_check("seed %d: 2x2 footprint fits the whole match" % s, fits[0])
		_check("seed %d: no root anchor under her or off her half" % s, bad_body.is_empty(), str(bad_body.slice(0, 3)))
		# Casts per phase (followup strikes not counted: one cast = one skill use).
		var turn: int = 0
		var last_phase: int = 0
		for ev: Dictionary in ctrl.event_log:
			var ph: int = int(ev.get("phase", 0))
			if ph != last_phase:
				turn = 0
				last_phase = ph
			if str(ev.get("event", "")) != "resolve" or bool(ev.get("followup_strike", false)):
				continue
			var sid: String = str(ev["skill"])
			cast_by_phase[ph][sid] = int(cast_by_phase[ph].get(sid, 0)) + 1
			# 2026-11-02: the row shift (counts_as_cast false) is not a cast, so it never moves the every_nth count.
			if not bool(cfg.skill_for_phase(sid, enemy["phases"][ph]).get("counts_as_cast", true)):
				continue
			turn += 1
			if ph == 2:
				if turn % 3 == 0:
					knot_turns[0] += 1
					if sid == "forest_last_knot":
						knot_turns[1] += 1
				elif sid == "forest_last_knot":
					knot_off_turn.append("seed %d turn %d" % [s, turn])
		# Standing still: hurt.
		var still: Dictionary = Fx.world(ArenaLibrary.grid_for_spec({"shape": ARENA}, library, s), cfg, ENEMY, s, ENEMY_HP)
		Fx.run(still["ctrl"], still["state"], still["status"], still["mover"], 60.0, "still", STEP)
		_check("seed %d: standing still is damaged" % s, (still["state"] as CombatState).player_hp < (still["state"] as CombatState).player_max_hp,
			"hp=%.1f" % (still["state"] as CombatState).player_hp)
	for phase: int in 3:
		var listed: Array = (enemy["phases"][phase] as Dictionary)["skills"] as Array
		var missing: Array[String] = []
		var outside: Array[String] = []
		for sid: String in listed:
			if not cast_by_phase[phase].has(sid):
				missing.append(sid)
		for sid: String in cast_by_phase[phase]:
			if not listed.has(sid):
				outside.append(sid)
		_check("phase %d casts every skill of its list" % (phase + 1), missing.is_empty(), "missing=%s casts=%s" % [missing, cast_by_phase[phase]])
		_check("phase %d casts nothing outside its list" % (phase + 1), outside.is_empty(), str(outside))
	_check("phase 3: forest_last_knot only on every 3rd cast", knot_off_turn.is_empty(), str(knot_off_turn.slice(0, 5)))
	_check("phase 3: forest_last_knot on most 3rd casts (%d of %d)" % [knot_turns[1], knot_turns[0]],
		knot_turns[0] > 0 and float(knot_turns[1]) >= 0.5 * float(knot_turns[0]))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

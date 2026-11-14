extends SceneTree
## Monster Skill Phase 2 group S-D (MONSTER-SKILL-PHASE2-PLAN.md §5): sand_sphinx, the Sands boss, on the shipped
## oasis grid.
## - data: tier boss, two phases; p1 {gaze, claw, bury, shared_sidestep} with mechanic bury and sidestep overridden
##   to weight 2 / cooldown 8; p2 at 0.5 adds sandfall (weight 0, forced only), every_nth 3, a 1.5 s transition with
##   on_enter sandfall, and a `phases[].traits` override of the match's sandstorm trait to interval_sec 9 (Phase 0 G5
##   — this is the first shipped data to use that path);
## - p1 never casts sandfall;
## - sphinx_gaze: one cell, data damage + 1 Rạn;
## - sphinx_claw: a T covering the hero, data damage;
## - sphinx_bury: TWO cells BESIDE the hero, never the hero's own, left sanded for 4 s and no damage of its own
##   (deviation from §4.3 recorded in the plan: `count` is marker-only, so the two cells are written as offsets);
## - sphinx_sandfall: a 2x2 covering the hero, then a second fall one row across (followup relative_to first_shift,
##   shown with the first), both for their data damage, and it cannot be interrupted.
## Hit damage is read from the shipped data, so a tuning pass moves the numbers without touching this file.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_sands_group_d_test.gd
##
## WHAT THIS SUITE DOES NOT PROVE — and the blocker that would retire this paragraph:
## The `phases[].traits` leg below asserts the **data shape** of the override (p2 carries sandstorm at
## interval_sec 9). It does NOT prove the override reaches the engine, because `pattern_fixtures.gd` builds no
## TraitHost, so `CombatView._apply_pattern_phase` is never entered by this suite. This is the first shipped data
## to use that path, so there is no earlier green run to compare against: a green here means the data is right,
## not that the path works. Whoever wires a TraitHost into `pattern_fixtures.gd` makes this paragraph false while
## they are making it false — delete it then, and add the leg that asserts the host actually received the override.
## (Related, verified separately: `phase_started` is connected only on unit 0's controller, combat_view.gd:3207,
## and `_apply_pattern_phase` uses `_trait_host`, :3244 — safe for a solo sphinx, latent for formations.
## Recorded as MONSTER-SKILL-PHASE2-PLAN.md §13.1b and §13.2.)

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const FALL: String = "sphinx_sandfall"

var fails: int = 0
var _cfg: EnemySkillsConfig
var _library: ArenaLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_cfg = EnemySkillsConfig.load_from_file()
	_library = ArenaLibrary.load_from_file()
	_check("shipped enemy_skills.json has no problems", _cfg.problems.is_empty(), str(_cfg.problems))
	test_data_shape()
	test_phase1_never_calls_the_sandfall()
	test_gaze_and_claw()
	test_bury_sands_two_cells_beside_the_hero()
	test_phase_change_then_sandfall()
	test_sandfall_falls_twice_one_row_across()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": "oasis"}, _library, seed_value)


func _world(seed_value: int = 1, enemy_hp: float = 1000.0) -> Dictionary:
	var w: Dictionary = Fx.world(_grid(seed_value), _cfg, "sand_sphinx", seed_value, enemy_hp)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)  # combat.json numbers
	var hazards: TileHazards = TileHazards.new(w["state"].grid, seed_value)
	hazards.bind_state(w["state"])
	(w["ctrl"] as PatternController).hazards = hazards
	w["hazards"] = hazards
	return w


## A world holding only [param ids] on one enemy, so one skill can be tested in isolation.
##
## [param weight_override], when >= 0, replaces each skill's weight. It exists for ONE reason: the sandfall ships
## with weight 0 so the planner never picks it — it is forced by the phase transition's on_enter and by every_nth.
## In an isolated world nothing forces it, so without this the skill simply never casts and every leg below fails
## while pointing at the skill's geometry. The override touches selection weight ONLY; offsets, damage, warning and
## followup are still the shipped data. That the FORCED path works is a separate leg
## (test_phase_change_then_sandfall: "p2: the first cast after the change is the sandfall"), and that leg is what
## would catch a broken on_enter — this one cannot, and is not meant to.
##
## It also has a TIMING consequence, which cost two debugging rounds: the sandfall has cooldown_sec 0, so a
## weight above 0 makes the NEXT cast arrive inside any measurement window. Never measure this skill by an HP
## delta across a window here — read the strike's own recorded damage from the event log, and filter on
## `followup_strike` when you mean the followup rather than the next cast.
func _only(ids: Array, seed_value: int = 1, weight_override: float = -1.0) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = ((data["skills"] as Dictionary)[id] as Dictionary).duplicate(true)
		if weight_override >= 0.0:
			skills[id]["weight"] = weight_override
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills,
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ids}}})
	var w: Dictionary = Fx.world(_grid(seed_value), cfg, "g", seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	var hazards: TileHazards = TileHazards.new(w["state"].grid, seed_value)
	hazards.bind_state(w["state"])
	(w["ctrl"] as PatternController).hazards = hazards
	w["hazards"] = hazards
	return w


func _run(w: Dictionary, seconds: float) -> void:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < seconds - 0.000001 and not (w["state"] as CombatState).is_player_dead():
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		(w["hazards"] as TileHazards).tick(STEP, w["state"])
		(w["mover"] as UnitMover).tick(STEP)
		ctrl.tick(STEP)
		t += STEP


func _dmg(id: String, followup: bool = false) -> float:
	var s: Dictionary = _cfg.skills[id]
	var fx: Dictionary = ((s["followup"] as Dictionary)["effects"] if followup else s["effects"]) as Dictionary
	return float(fx.get("damage", 0.0))


## [param want_followup]: -1 any strike, 0 only a FIRST strike, 1 only a FOLLOWUP strike.
##
## The filter is not cosmetic. Matching on skill id alone cannot tell a skill's followup strike apart from the
## NEXT CAST of the same skill, and for a 0-cooldown skill the next cast arrives within the window. That is how
## the second-fall leg first read 40 instead of 30: it had caught the next cast's first strike and reported it as
## the followup. `_record` writes `followup_strike` (pattern_controller.gd:1239) precisely so this is decidable.
func _until_resolve(w: Dictionary, skill_id: String, limit: float = 20.0, want_followup: int = -1) -> Dictionary:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	var seen: int = ctrl.event_log.size()
	while t < limit:
		_run(w, STEP)
		t += STEP
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) != "resolve" or str(ev.get("skill", "")) != skill_id:
				continue
			if want_followup >= 0 and int(bool(ev.get("followup_strike", false))) != want_followup:
				continue
			return ev
		seen = ctrl.event_log.size()
	return {}


func _until_stage(w: Dictionary, stage: int, limit: float = 8.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		_run(w, STEP)
		t += STEP
		if ctrl.get_stage() == stage:
			return true
	return false


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	var sphinx: Dictionary = _cfg.get_enemy("sand_sphinx")
	_check("sphinx loaded", not sphinx.is_empty())
	_check("sphinx is a boss", str(sphinx.get("tier", "")) == "boss", str(sphinx.get("tier")))
	var phases: Array = sphinx["phases"] as Array
	_check("sphinx has two phases", phases.size() == 2, str(phases.size()))
	var p1: Dictionary = phases[0]
	var p2: Dictionary = phases[1]
	_check("p1: gaze + claw + bury + sidestep, mechanic bury",
		(p1["skills"] as Array) == ["sphinx_gaze", "sphinx_claw", "sphinx_bury", "shared_sidestep"]
		and str(p1["mechanic"]) == "sphinx_bury")
	_check("p1: sidestep overridden to weight 2 / cooldown 8",
		is_equal_approx(float(_cfg.skill_for_phase("shared_sidestep", p1)["weight"]), 2.0)
		and is_equal_approx(float(_cfg.skill_for_phase("shared_sidestep", p1)["cooldown_sec"]), 8.0))
	_check("p2 opens at half HP and adds the sandfall",
		is_equal_approx(float(p2["enter_hp_ratio"]), 0.5) and (p2["skills"] as Array).has(FALL))
	_check("p2: every 3rd counted cast is the sandfall",
		str((p2["every_nth"] as Dictionary)["skill"]) == FALL and int((p2["every_nth"] as Dictionary)["n"]) == 3)
	_check("p2 transition 1.5 s, on_enter sandfall", is_equal_approx(float((p2["transition"] as Dictionary)["sec"]), 1.5)
		and ((p2["transition"] as Dictionary)["on_enter"] as Array) == [FALL])
	# Phase 0 G5: the first shipped use of phases[].traits.
	var traits: Array = p2["traits"] as Array
	_check("p2 overrides the sandstorm trait to interval 9", traits.size() == 1
		and str((traits[0] as Dictionary)["id"]) == "sandstorm"
		and is_equal_approx(float(((traits[0] as Dictionary)["params"] as Dictionary)["interval_sec"]), 9.0), str(traits))
	_check("p1 carries no trait override", (p1["traits"] as Array).is_empty(), str(p1["traits"]))
	_check("sandfall: weight 0 (forced only), not interruptible",
		is_equal_approx(float(_cfg.skills[FALL]["weight"]), 0.0) and not bool(_cfg.skills[FALL]["interruptible"]))
	var fu: Dictionary = _cfg.skills[FALL]["followup"] as Dictionary
	_check("sandfall followup: one row across, shown with the first",
		str(fu["relative_to"]) == "first_shift" and bool(fu["show_with_first"]) and float(fu["effects"]["damage"]) > 0.0)
	_check("bury: a sand zone and no damage of its own",
		str(((_cfg.skills["sphinx_bury"]["effects"] as Dictionary)["zone"] as Dictionary)["id"]) == "sand"
		and is_equal_approx(_dmg("sphinx_bury"), 0.0), str(_dmg("sphinx_bury")))
	_check("bury: two cells, never the hero's own",
		((_cfg.skills["sphinx_bury"]["pattern"] as Dictionary)["offsets"] as Array).size() == 2
		and bool((_cfg.skills["sphinx_bury"]["pattern"] as Dictionary).get("exclude_player", false)))
	for id: String in ["sphinx_gaze", "sphinx_claw", "sphinx_bury", FALL]:
		var s: Dictionary = _cfg.skills[id]
		_check("%s has name / counter keys" % id, str(s["name_key"]) == "enemy_skill.%s.name" % id
			and str(s["counter_key"]) == "enemy_skill.%s.counter" % id)
		_check("%s names its delivery" % id, (s["delivery"] as Dictionary).has("type"))
	# Tuning guard, as in groups A-C.
	var chars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/characters.json"))
	var low: float = INF
	for c: Dictionary in (chars["characters"] as Array):
		var attrs: Dictionary = c.get("attributes", {}) as Dictionary
		low = minf(low, float(attrs.get("max_hp", c.get("max_hp", INF))))
	var worst: float = 0.0
	for sid: String in ["sphinx_gaze", "sphinx_claw", FALL]:
		worst = maxf(worst, 1.5 * _dmg(sid))
		if not (_cfg.skills[sid]["followup"] as Dictionary).is_empty():
			worst = maxf(worst, 1.5 * _dmg(sid, true))
	_check("guard: the worst S-D hit (x1.5 Rạn) < half the lowest hero HP", worst > 0.0 and worst < 0.5 * low,
		"%.1f vs %.1f" % [worst, 0.5 * low])


func test_phase1_never_calls_the_sandfall() -> void:
	var w: Dictionary = _world(1)  # full HP, so p1 for the whole run
	_run(w, 30.0)
	var casts: int = 0
	var others: int = 0
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) != "resolve":
			continue
		if str(ev.get("skill", "")) == FALL:
			casts += 1
		else:
			others += 1
	_check("p1: the sandfall is never cast", casts == 0, str(casts))
	_check("p1: the other skills do cast", others >= 3, str(others))


func test_gaze_and_claw() -> void:
	var wg: Dictionary = _only(["sphinx_gaze"])
	var ev: Dictionary = _until_resolve(wg, "sphinx_gaze")
	_check("gaze: damage from data (%.0f)" % _dmg("sphinx_gaze"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("sphinx_gaze")), str(ev))
	_check("gaze: a hit leaves 1 Rạn", (wg["status"] as StatusEffects).fragile_stacks(P) >= 1,
		str((wg["status"] as StatusEffects).fragile_stacks(P)))
	var wc: Dictionary = _only(["sphinx_claw"])
	var ctrl: PatternController = wc["ctrl"]
	var state: CombatState = wc["state"]
	_check("claw: it warns", _until_stage(wc, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("claw: the T covers the hero", red.has(state.player_cell), str(red))
	_check("claw: 3-4 cells after clipping", red.size() >= 3 and red.size() <= 4, str(red))
	var ev2: Dictionary = _until_resolve(wc, "sphinx_claw")
	_check("claw: damage from data (%.0f)" % _dmg("sphinx_claw"),
		not ev2.is_empty() and bool(ev2["hit"]) and is_equal_approx(float(ev2["damage"]), _dmg("sphinx_claw")), str(ev2))


func test_bury_sands_two_cells_beside_the_hero() -> void:
	var w: Dictionary = _only(["sphinx_bury"])
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var hazards: TileHazards = w["hazards"]
	_check("bury: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("bury: two cells", red.size() == 2, str(red))
	_check("bury: never the cell the hero stands on", not red.has(state.player_cell),
		"%s vs hero %s" % [str(red), str(state.player_cell)])
	var ev: Dictionary = _until_resolve(w, "sphinx_bury")
	_check("bury: it resolves without damaging the hero", not ev.is_empty()
		and is_equal_approx(float(ev["damage"]), 0.0), str(ev))
	# The sand is read from TileHazards, not from the event log: _record never writes zone_cells.
	var sanded: int = 0
	for c: Vector2i in red:
		if hazards.is_sanded(P, c) or hazards.is_sand_warning(P, c):
			sanded += 1
	_check("bury: the struck cells are sand (or its warning)", sanded > 0, "%d of %d" % [sanded, red.size()])
	_check("bury: the hero's own cell is never sanded",
		not (hazards.is_sanded(P, state.player_cell) or hazards.is_sand_warning(P, state.player_cell)))


func test_phase_change_then_sandfall() -> void:
	var w: Dictionary = _world(2, 200.0)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_run(w, 1.0)
	_check("p1 at full HP", ctrl.get_phase_index() == 0, str(ctrl.get_phase_index()))
	state.enemy_hp = state.enemy_max_hp * 0.45  # cross the 50 % line
	var t: float = 0.0
	while t < 6.0 and ctrl.get_phase_index() == 0:
		_run(w, STEP)
		t += STEP
	_check("p2 opens once HP drops below half", ctrl.get_phase_index() == 1, str(ctrl.get_phase_index()))
	# on_enter forces the sandfall first, even though its weight is 0.
	var seq: Array[String] = []
	var seen: int = ctrl.event_log.size()
	var t2: float = 0.0
	while t2 < 14.0 and seq.size() < 1:
		_run(w, STEP)
		t2 += STEP
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) == "resolve":
				seq.append(str(ev.get("skill", "")))
		seen = ctrl.event_log.size()
	_check("p2: the first cast after the change is the sandfall", not seq.is_empty() and seq[0] == FALL, str(seq))


func test_sandfall_falls_twice_one_row_across() -> void:
	var w: Dictionary = _only([FALL], 3, 1.0)  # weight lifted: see _only — the forced path is a separate leg
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	state.player_max_hp = 400.0
	state.player_hp = 400.0
	_check("sandfall: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var first: Array[Vector2i] = ctrl.telegraph_cells()
	_check("sandfall: a 2x2 over the hero", first.size() == 4 and first.has(state.player_cell), str(first))
	_check("sandfall: it cannot be interrupted", not ctrl.on_enemy_hit())
	var hp: float = state.player_hp
	var ev: Dictionary = _until_resolve(w, FALL, 8.0, 0)  # the FIRST strike, not a followup
	_check("sandfall: the first fall costs its data damage (%.0f)" % _dmg(FALL),
		not ev.is_empty() and is_equal_approx(hp - state.player_hp, _dmg(FALL)), "%.0f -> %.0f" % [hp, state.player_hp])
	# The second fall lands one row across; a hero who stays put takes it too.
	var hp2: float = state.player_hp
	var ev2: Dictionary = _until_resolve(w, FALL, 6.0, 1)  # the FOLLOWUP strike, not the next cast
	_check("sandfall: a second fall follows", not ev2.is_empty())
	if not ev2.is_empty():
		# Assert the RECORDED damage of the followup strike, not the HP delta: between the first strike and the
		# followup the hero can take an unrelated hit (here the next cast's first strike, since the harness lifted
		# the weight and the skill has no cooldown), and an HP delta cannot say which strike spent it.
		var took: float = hp2 - state.player_hp
		_check("sandfall: the second fall costs its own data damage (%.0f) or misses" % _dmg(FALL, true),
			is_equal_approx(float(ev2["damage"]), _dmg(FALL, true)) or not bool(ev2["hit"]),
			"recorded=%s hit=%s hp_delta=%.0f" % [str(ev2["damage"]), str(ev2["hit"]), took])


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	var keys: Array[String] = []
	for id: String in ["sphinx_gaze", "sphinx_claw", "sphinx_bury", FALL]:
		keys.append("enemy_skill.%s.name" % id)
		keys.append("enemy_skill.%s.counter" % id)
	var seen: Dictionary = {}
	for line: String in raw.split("\n"):
		var row: PackedStringArray = line.strip_edges().split(",")
		if row.size() > 0 and keys.has(row[0]):
			seen[row[0]] = line.strip_edges()
	_check("strings: all 8 S-D rows exist", seen.size() == keys.size(), str(seen.keys()))
	for k: String in seen:
		var cols: PackedStringArray = (seen[k] as String).split(",")
		var quoted: bool = (seen[k] as String).contains("\"")
		_check("strings: %s parses as 3 columns" % k, quoted or cols.size() == 3, seen[k])

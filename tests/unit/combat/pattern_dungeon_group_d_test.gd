extends SceneTree
## Monster Skill Phase 2 group D-D (MONSTER-SKILL-PHASE2-PLAN.md §22): ogre_king, the Hầm Ngục boss, on the
## shipped ring grid. Hệ số vùng: ×2,5. **Hầm Ngục hoàn tất 10/10 quái.**
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_dungeon_group_d_test.gd
##
## THIS SUITE CARRIES A LEG THE OTHERS DO NOT: THE CHAIN BUDGET.
## Every guard leg so far asks whether the heaviest SINGLE blow stays under half the lowest hero's HP. For a
## two-beat skill that is the wrong question. At ×3.5 `ogre_quake` would be 56 then 42 — both under the 85
## threshold, both passing — while a hero who stands still eats 98 = 58 % of phap_su's 170 in one beat. The leg
## below asserts the PAIR.
## Found by building the ×2.5-vs-×3.5 comparison table in full rather than citing one row of it; the single-blow
## guard was blind to it and had been since the Hellfire group.
## STILL UNCHECKED ELSEWHERE, said plainly rather than left implied: `sphinx_sandfall` (Sands) and
## `matriarch_toxic_croak` (Swamp) are the same two-beat shape and have never been checked this way. At their
## shipped multipliers they come to 70 and 84 against 170 — inside, but *unverified*, which is not the same as
## *verified safe*.
##
## WHAT THIS SUITE DOES NOT PROVE:
## The `phases[].traits` leg asserts the DATA SHAPE of the slam override (slam_interval_sec 5). It does not prove
## the override reaches the engine: `pattern_fixtures.gd` builds no TraitHost, so `CombatView._apply_pattern_phase`
## is never entered here. Third shipped use of that path (sand_sphinx, toad_matriarch, this) and still only the
## data shape is covered. Whoever wires a TraitHost into the fixture makes this paragraph false while making it so.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const QUAKE: String = "ogre_quake"
const ROAR: String = "ogre_roar"
const CLUB: String = "ogre_club"

var fails: int = 0
var _cfg: EnemySkillsConfig
var _library: ArenaLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " + name) if ok else ("FAIL " + name + (" " + extra if not extra.is_empty() else "")))
	if not ok:
		fails += 1


func _initialize() -> void:
	_cfg = EnemySkillsConfig.load_from_file()
	_library = ArenaLibrary.load_from_file()
	_check("shipped enemy_skills.json has no problems", _cfg.problems.is_empty(), str(_cfg.problems))
	test_data_shape()
	test_phase1_never_quakes_or_roars()
	test_club_and_grab()
	test_phase_change_then_roar_then_quake()
	test_quake_runs_the_row_then_the_next()
	test_chain_damage_budget()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": "ring"}, _library, seed_value)


func _dmg(id: String, followup: bool = false) -> float:
	var s: Dictionary = _cfg.skills[id]
	var fx: Dictionary = ((s["followup"] as Dictionary)["effects"] if followup else s["effects"]) as Dictionary
	return float(fx.get("damage", 0.0))


func _world(seed_value: int = 1, enemy_hp: float = 1000.0) -> Dictionary:
	var w: Dictionary = Fx.world(_grid(seed_value), _cfg, "ogre_king", seed_value, enemy_hp)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	var hazards: TileHazards = TileHazards.new(w["state"].grid, seed_value)
	hazards.bind_state(w["state"])
	(w["ctrl"] as PatternController).hazards = hazards
	w["hazards"] = hazards
	return w


## [param weight_override] >= 0 replaces each skill's weight. The quake and the roar ship at weight 0 (forced by
## on_enter and every_nth), so nothing would cast them in an isolated world. It also has cooldown 0, so a weight
## above 0 makes the NEXT cast land inside any measurement window — read a strike's own recorded damage and filter
## on `followup_strike`, never an HP delta (that trap cost two rounds on sphinx_sandfall; plan §14.1).
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
	var hazards: TileHazards = w["hazards"]
	var state: CombatState = w["state"]
	var t: float = 0.0
	while t < seconds:
		ctrl.tick(STEP)
		if hazards != null:
			hazards.tick(STEP, state)
		t += STEP


func _until_stage(w: Dictionary, stage: int, limit: float = 8.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		_run(w, STEP)
		t += STEP
		if ctrl.get_stage() == stage:
			return true
	return false


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


func _casts(w: Dictionary, skill_id: String) -> int:
	var n: int = 0
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id:
			n += 1
	return n


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	_check("ogre_king is in the shipped enemies", _cfg.enemies.has("ogre_king"))
	var phases: Array = (_cfg.enemies["ogre_king"] as Dictionary).get("phases", []) as Array
	_check("two phases", phases.size() == 2, str(phases.size()))
	if phases.size() == 2:
		var p2: Dictionary = phases[1] as Dictionary
		_check("p2 opens at half HP", is_equal_approx(float(p2["enter_hp_ratio"]), 0.5), str(p2.get("enter_hp_ratio")))
		_check("p2's mechanic is the quake", str(p2.get("mechanic", "")) == QUAKE, str(p2.get("mechanic")))
		_check("p2 forces the quake every 3rd cast",
			int((p2.get("every_nth", {}) as Dictionary).get("n", 0)) == 3, str(p2.get("every_nth", {})))
		var on_enter: Array = (p2.get("transition", {}) as Dictionary).get("on_enter", []) as Array
		_check("p2's transition forces the roar on entry",
			on_enter.size() == 1 and str(on_enter[0]) == ROAR, str(p2.get("transition", {})))
		# DATA SHAPE ONLY — see the header: no TraitHost is built here.
		var tr: Array = p2.get("traits", []) as Array
		_check("p2 tightens slam to 5 s (data shape only)",
			tr.size() == 1 and str((tr[0] as Dictionary)["id"]) == "slam"
			and is_equal_approx(float(((tr[0] as Dictionary)["params"] as Dictionary)["slam_interval_sec"]), 5.0), str(tr))
	# §16.2: multi-cell patterns on an irregular arena must clip.
	for sid: String in [CLUB, QUAKE]:
		var pat: Dictionary = _cfg.skills[sid]["pattern"] as Dictionary
		_check("%s clips" % sid, bool(pat.get("clip", false)) and int(pat.get("min_cells", 0)) >= 2, str(pat))
	_check("club cannot be interrupted", not bool(_cfg.skills[CLUB]["interruptible"]))
	_check("quake cannot be interrupted", not bool(_cfg.skills[QUAKE]["interruptible"]))
	_check("quake's second beat lands one row across",
		str((_cfg.skills[QUAKE]["followup"] as Dictionary)["relative_to"]) == "first_shift")
	_check("roar hastens the ogre and is never chosen on its own",
		float(((_cfg.skills[ROAR]["effects"] as Dictionary).get("haste", {}) as Dictionary).get("cooldown_mult", 1.0)) < 1.0
		and is_equal_approx(float(_cfg.skills[ROAR].get("weight", 1.0)), 0.0))
	# Trait slam stays on the match; p2 only overrides its interval.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chapters.json")) as Dictionary
	var traits: Array = []
	for ch: Dictionary in (data["chapters"] as Array):
		var m: Dictionary = ((ch.get("matches", {}) as Dictionary).get("ogre_king", {})) as Dictionary
		for t: Variant in (m.get("traits", []) as Array):
			traits.append(str((t as Dictionary)["id"]) if typeof(t) == TYPE_DICTIONARY else str(t))
	_check("slam stays on the match", traits.has("slam"), str(traits))


func test_phase1_never_quakes_or_roars() -> void:
	var w: Dictionary = _world(1)  # full HP, so p1 for the whole run
	_run(w, 30.0)
	_check("p1: the quake is never cast", _casts(w, QUAKE) == 0, str(_casts(w, QUAKE)))
	_check("p1: the roar is never cast", _casts(w, ROAR) == 0, str(_casts(w, ROAR)))
	var others: int = 0
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) != QUAKE:
			others += 1
	_check("p1: the other skills do cast", others >= 3, str(others))


func test_club_and_grab() -> void:
	var wc: Dictionary = _only([CLUB])
	var ctrl: PatternController = wc["ctrl"]
	var state: CombatState = wc["state"]
	_check("club: it warns", _until_stage(wc, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("club: the square covers the hero", red.has(state.player_cell), str(red))
	_check("club: 3-4 cells after clipping", red.size() >= 3 and red.size() <= 4, str(red))
	var ev: Dictionary = _until_resolve(wc, CLUB)
	_check("club: damage from data (%.0f)" % _dmg(CLUB),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg(CLUB)), str(ev))

	var wg: Dictionary = _only(["ogre_grab"])
	var ev2: Dictionary = _until_resolve(wg, "ogre_grab")
	_check("grab: damage from data (%.0f)" % _dmg("ogre_grab"),
		not ev2.is_empty() and bool(ev2["hit"]) and is_equal_approx(float(ev2["damage"]), _dmg("ogre_grab")), str(ev2))
	_check("grab: a hit pins the hero", (wg["status"] as StatusEffects).is_pinned(P))


func test_phase_change_then_roar_then_quake() -> void:
	var w: Dictionary = _world(2, 200.0)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_run(w, 1.0)
	_check("p1 at full HP", ctrl.get_phase_index() == 0, str(ctrl.get_phase_index()))
	state.enemy_hp = state.enemy_max_hp * 0.45
	var t: float = 0.0
	while t < 6.0 and ctrl.get_phase_index() == 0:
		_run(w, STEP)
		t += STEP
	_check("p2 opens once HP drops below half", ctrl.get_phase_index() == 1, str(ctrl.get_phase_index()))
	var ev: Dictionary = _until_resolve(w, ROAR, 10.0)
	_check("p2: the roar fires on entry", not ev.is_empty(), str(ev))
	_check("p2: the ogre is hasted afterwards", ctrl.haste_left() > 0.0, "haste_left=%.2f" % ctrl.haste_left())
	_run(w, 24.0)
	_check("p2: the quake does cast in phase two", _casts(w, QUAKE) >= 1, str(_casts(w, QUAKE)))


func test_quake_runs_the_row_then_the_next() -> void:
	var w: Dictionary = _only([QUAKE], 3, 1.0)  # weight lifted: see _only
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_check("quake: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var first: Array[Vector2i] = ctrl.telegraph_cells()
	var on_row: bool = not first.is_empty()
	for c: Vector2i in first:
		if c.y != state.player_cell.y:
			on_row = false
	_check("quake: the first beat runs the hero's row", on_row,
		"%s vs hero row %d" % [str(first), state.player_cell.y])
	_check("quake: at least 2 cells after clipping", first.size() >= 2, str(first))
	var ev: Dictionary = _until_resolve(w, QUAKE, 10.0, 0)
	_check("quake: the first beat costs its data damage (%.0f)" % _dmg(QUAKE),
		not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg(QUAKE)), str(ev))
	var ev2: Dictionary = _until_resolve(w, QUAKE, 8.0, 1)
	_check("quake: a second beat follows", not ev2.is_empty(), str(ev2))
	if not ev2.is_empty():
		_check("quake: the second beat costs its own data damage (%.0f) or misses" % _dmg(QUAKE, true),
			is_equal_approx(float(ev2["damage"]), _dmg(QUAKE, true)) or not bool(ev2["hit"]),
			"recorded=%s hit=%s" % [str(ev2["damage"]), str(ev2["hit"])])


## The leg this whole suite exists for. A hero who does not move eats BOTH beats; the single-blow guard cannot see
## that, because each beat on its own is well under the threshold.
func test_chain_damage_budget() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/characters.json")) as Dictionary
	var chars: Variant = raw.get("characters", raw)
	var list: Array = (chars.values() if typeof(chars) == TYPE_DICTIONARY else chars) as Array
	var low: float = INF
	for c: Variant in list:
		var cd: Dictionary = c as Dictionary
		low = minf(low, float((cd.get("attributes", {}) as Dictionary).get("max_hp", cd.get("max_hp", INF))))
	var chain: float = _dmg(QUAKE) + _dmg(QUAKE, true)
	_check("guard: each quake beat alone < half the lowest hero HP",
		maxf(_dmg(QUAKE), _dmg(QUAKE, true)) < 0.5 * low,
		"%.0f vs half of %.0f" % [maxf(_dmg(QUAKE), _dmg(QUAKE, true)), low])
	_check("guard: BOTH quake beats together < half the lowest hero HP",
		low < INF and chain > 0.0 and chain < 0.5 * low,
		"chain %.0f = %.0f%% of %.0f" % [chain, 100.0 * chain / low, low])


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in [CLUB, "ogre_grab", ROAR, QUAKE]:
		for suffix: String in ["name", "counter"]:
			var key: String = "enemy_skill.%s.%s" % [id, suffix]
			_check("strings.csv has %s" % key, raw.contains(key + ","))

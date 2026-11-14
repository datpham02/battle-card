extends SceneTree
## Monster Skill Phase 2 group W-D (MONSTER-SKILL-PHASE2-PLAN.md §18): toad_matriarch, the Swamp boss, on the
## shipped bog grid.
## - two phases; p1 {spit, tongue_lash, sink, shared_sidestep} with mechanic sink, p2 at 0.5 adds toxic_croak
##   (weight 0, forced only) and regrow, every_nth 3, a 1.5 s transition whose on_enter forces regrow, and a
##   `phases[].traits` override of the match's bog_spread to interval_sec 6;
## - matriarch_spit: one cell, data damage, and that cell turns to mire;
## - matriarch_tongue_lash: a VERTICAL three-cell lance down the hero's column, data damage + Chậm;
## - matriarch_sink: TWO cells BESIDE the hero, never the hero's own, left as a drop zone and no damage;
## - matriarch_toxic_croak: a 2x2 covering the hero then a second fall one row across, uninterruptible;
## - matriarch_regrow: heals 8 % ONCE, on entering phase 2.
## Damage is read from the shipped data, so a tuning pass moves the numbers without touching this file.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_swamp_group_d_test.gd
##
## WHAT THIS SUITE DOES NOT PROVE:
## 1. `phases[].traits` — the leg asserts the DATA SHAPE of the bog_spread override (interval_sec 6). It does NOT
##    prove the override reaches the engine: `pattern_fixtures.gd` builds no TraitHost, so
##    `CombatView._apply_pattern_phase` is never entered here. Same gap as sand_sphinx (plan §13.1b); the sphinx
##    was the first shipped use of that path and this is the second, so there is now one earlier green — of the
##    data shape only, which is the same thing this leg checks. Whoever wires a TraitHost into the fixture makes
##    this paragraph false while making it false.
## 2. `seal_caster` being gone is checked in `chapters.json` (the data) and by the absence of any such skill. That
##    the TRAIT no longer hooks the swing block at runtime is not exercised here — `region_traits_test` owns that.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const CROAK: String = "matriarch_toxic_croak"
const REGROW: String = "matriarch_regrow"
const SINK: String = "matriarch_sink"
const LASH: String = "matriarch_tongue_lash"

var fails: int = 0
var _cfg: EnemySkillsConfig
var _library: ArenaLibrary


## [param extra] prints on FAILURE only. Printing it on a pass too makes a hint written for the failing case
## read as a statement of fact on a green line — e.g. "an unclipped cast was found ... no 2+ cell cast over
## 8 seeds", which says the opposite of what the PASS means.
func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " + name) if ok else ("FAIL " + name + (" " + extra if not extra.is_empty() else "")))
	if not ok:
		fails += 1


func _initialize() -> void:
	_cfg = EnemySkillsConfig.load_from_file()
	_library = ArenaLibrary.load_from_file()
	_check("shipped enemy_skills.json has no problems", _cfg.problems.is_empty(), str(_cfg.problems))
	test_data_shape()
	test_seal_caster_is_gone_from_the_match()
	test_phase1_never_calls_the_croak()
	test_spit_mires_the_cell_it_hits()
	test_tongue_lash_runs_down_the_column()
	test_sink_drops_two_cells_beside_the_hero()
	test_phase_change_then_regrow_then_croak()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": "bog"}, _library, seed_value)


func _dmg(id: String, followup: bool = false) -> float:
	var s: Dictionary = _cfg.skills[id]
	var fx: Dictionary = ((s["followup"] as Dictionary)["effects"] if followup else s["effects"]) as Dictionary
	return float(fx.get("damage", 0.0))


func _world(seed_value: int = 1, enemy_hp: float = 1000.0) -> Dictionary:
	var w: Dictionary = Fx.world(_grid(seed_value), _cfg, "toad_matriarch", seed_value, enemy_hp)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	var hazards: TileHazards = TileHazards.new(w["state"].grid, seed_value)
	hazards.bind_state(w["state"])
	(w["ctrl"] as PatternController).hazards = hazards
	w["hazards"] = hazards
	return w


## [param weight_override] >= 0 replaces each skill's weight. The croak ships at weight 0 (forced by on_enter and
## every_nth), so in an isolated world nothing would ever cast it and every leg would fail while pointing at the
## skill's geometry. It also has cooldown 0, so a weight above 0 makes the NEXT cast arrive inside any measurement
## window — read a strike's own recorded damage and filter on `followup_strike`, never an HP delta. (Both traps
## cost rounds on sphinx_sandfall; plan §14.1.)
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
	_check("toad_matriarch is in the shipped enemies", _cfg.enemies.has("toad_matriarch"))
	var phases: Array = (_cfg.enemies["toad_matriarch"] as Dictionary).get("phases", []) as Array
	_check("two phases", phases.size() == 2, str(phases.size()))
	if phases.size() == 2:
		var p2: Dictionary = phases[1] as Dictionary
		_check("p2 opens at half HP", is_equal_approx(float(p2["enter_hp_ratio"]), 0.5), str(p2.get("enter_hp_ratio")))
		_check("p2's mechanic is the croak", str(p2.get("mechanic", "")) == CROAK, str(p2.get("mechanic")))
		_check("p2 forces the croak every 3rd cast",
			int(((p2.get("every_nth", {}) as Dictionary).get("n", 0))) == 3, str(p2.get("every_nth", {})))
		# `on_enter` is normalised to Array[String] by enemy_skills_config.gd:424-431 — the {"skill": ...} objects
		# in the JSON are flattened to plain ids. Casting an entry to Dictionary raises, and a raise here
		# TRUNCATES this function: the nine legs below it silently never run while FAILS= still prints 0.
		var on_enter: Array = (p2.get("transition", {}) as Dictionary).get("on_enter", []) as Array
		_check("p2's transition forces the regrow on entry",
			on_enter.size() == 1 and str(on_enter[0]) == REGROW, str(p2.get("transition", {})))
		# DATA SHAPE ONLY — see the header: no TraitHost is built here.
		var tr: Array = p2.get("traits", []) as Array
		_check("p2 tightens bog_spread to 6 s (data shape only)",
			tr.size() == 1 and str((tr[0] as Dictionary)["id"]) == "bog_spread"
			and is_equal_approx(float(((tr[0] as Dictionary)["params"] as Dictionary)["interval_sec"]), 6.0), str(tr))
	# §13.1: `count` is marker-only, so the sink is written as a two-cell offsets bar.
	var sink: Dictionary = _cfg.skills[SINK]["pattern"] as Dictionary
	_check("sink is TWO cells beside the hero, not count: 2",
		(sink["offsets"] as Array).size() == 2 and bool(sink.get("exclude_player", false)), str(sink))
	_check("sink drops the cells it marks",
		(((_cfg.skills[SINK]["effects"] as Dictionary).get("zone", {}) as Dictionary).get("id", "")) == "drop")
	_check("sink deals no damage of its own", is_equal_approx(_dmg(SINK), 0.0), str(_dmg(SINK)))
	# §16.1: off.x walks DOWN the column on column_of_player.
	var lash: Array = _cfg.skills[LASH]["pattern"]["offsets"] as Array
	_check("tongue_lash walks DOWN the column, not across",
		lash.size() == 3 and (lash[0] as Vector2i) == Vector2i(0, 0)
		and (lash[1] as Vector2i) == Vector2i(1, 0) and (lash[2] as Vector2i) == Vector2i(2, 0), str(lash))
	# §16.2: a multi-cell pattern on an irregular arena must clip, or it silently never casts.
	var croak: Dictionary = _cfg.skills[CROAK]["pattern"] as Dictionary
	_check("toxic_croak clips", bool(croak.get("clip", false)) and int(croak.get("min_cells", 0)) >= 3, str(croak))
	_check("toxic_croak cannot be interrupted", not bool(_cfg.skills[CROAK]["interruptible"]))
	var heal: Dictionary = (_cfg.skills[REGROW]["effects"] as Dictionary).get("heal", {}) as Dictionary
	_check("regrow heals a ratio over seconds", float(heal.get("ratio", 0.0)) > 0.0 and float(heal.get("sec", 0.0)) > 0.0, str(heal))
	_check("regrow happens only once", bool((_cfg.skills[REGROW]["conditions"] as Dictionary).get("once", false)))


## §4.4 turns `seal_caster` into the skill `matriarch_sink`, because the trait hooks the swing block. The trait
## must be GONE from the match, not merely unused.
func test_seal_caster_is_gone_from_the_match() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/data/chapters.json")
	var data: Dictionary = JSON.parse_string(raw) as Dictionary
	var found: bool = false
	var traits: Array = []
	for ch: Dictionary in (data["chapters"] as Array):
		var m: Dictionary = ((ch.get("matches", {}) as Dictionary).get("toad_matriarch", {})) as Dictionary
		if m.is_empty():
			continue
		found = true
		for t: Variant in (m.get("traits", []) as Array):
			traits.append(str((t as Dictionary)["id"]) if typeof(t) == TYPE_DICTIONARY else str(t))
	_check("the matriarch match was found in chapters.json", found)
	_check("seal_caster is gone (it became matriarch_sink)", not traits.has("seal_caster"), str(traits))
	_check("bog_spread stays (p2 only overrides its interval)", traits.has("bog_spread"), str(traits))


func test_phase1_never_calls_the_croak() -> void:
	var w: Dictionary = _world(1)  # full HP, so p1 for the whole run
	_run(w, 30.0)
	_check("p1: the croak is never cast", _casts(w, CROAK) == 0, str(_casts(w, CROAK)))
	_check("p1: the regrow is never cast", _casts(w, REGROW) == 0, str(_casts(w, REGROW)))
	var others: int = 0
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) != CROAK:
			others += 1
	_check("p1: the other skills do cast", others >= 3, str(others))


func test_spit_mires_the_cell_it_hits() -> void:
	var w: Dictionary = _only(["matriarch_spit"])
	var hazards: TileHazards = w["hazards"]
	var state: CombatState = w["state"]
	var hit_cell: Vector2i = state.player_cell
	var ev: Dictionary = _until_resolve(w, "matriarch_spit")
	_check("spit: damage from data (%.0f)" % _dmg("matriarch_spit"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("matriarch_spit")), str(ev))
	# Read the mire from TileHazards, not the event log: `_record` never writes zone_cells.
	var cells: Array = ev.get("cells", []) as Array
	var mired: bool = false
	for c: Variant in cells:
		if hazards.is_mire(P, c as Vector2i):
			mired = true
	_check("spit: the struck cell turns to mire", mired, "%s, hero was %s" % [str(cells), str(hit_cell)])


func test_tongue_lash_runs_down_the_column() -> void:
	var judged: bool = false
	for seed_value: int in range(1, 9):
		var w: Dictionary = _only([LASH], seed_value)
		if not _until_stage(w, PatternController.Stage.WARNING):
			continue
		var red: Array[Vector2i] = (w["ctrl"] as PatternController).telegraph_cells()
		if red.size() < 2:
			continue  # clipped to one cell: cannot judge the axis on this seed
		var state: CombatState = w["state"]
		judged = true
		var same_x: bool = true
		var differing_y: bool = false
		for c: Vector2i in red:
			if c.x != state.player_cell.x:
				same_x = false
			if c.y != red[0].y:
				differing_y = true
		_check("lash: every cell shares the hero's column (seed %d)" % seed_value, same_x, str(red))
		_check("lash: the cells differ in row — a lance, not a bar (seed %d)" % seed_value, differing_y, str(red))
		var ev: Dictionary = _until_resolve(w, LASH)
		_check("lash: damage from data (%.0f)" % _dmg(LASH),
			not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg(LASH)), str(ev))
		_check("lash: a hit leaves Chậm running", (w["status"] as StatusEffects).get_slow_left(P) > 0.0)
		break
	_check("lash: an unclipped cast was found to judge the axis on", judged, "no 2+ cell cast over 8 seeds")


func test_sink_drops_two_cells_beside_the_hero() -> void:
	var w: Dictionary = _only([SINK])
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_check("sink: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("sink: two cells", red.size() == 2, str(red))
	_check("sink: never the cell the hero stands on", not red.has(state.player_cell),
		"%s vs hero %s" % [str(red), str(state.player_cell)])
	var hp: float = state.player_hp
	var ev: Dictionary = _until_resolve(w, SINK)
	_check("sink: it resolves without damaging the hero",
		not ev.is_empty() and is_equal_approx(float(ev["damage"]), 0.0) and is_equal_approx(hp, state.player_hp), str(ev))


func test_phase_change_then_regrow_then_croak() -> void:
	var w: Dictionary = _world(2, 200.0)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_run(w, 1.0)
	_check("p1 at full HP", ctrl.get_phase_index() == 0, str(ctrl.get_phase_index()))
	state.enemy_hp = state.enemy_max_hp * 0.45
	var before: float = state.enemy_hp
	var t: float = 0.0
	while t < 6.0 and ctrl.get_phase_index() == 0:
		_run(w, STEP)
		t += STEP
	_check("p2 opens once HP drops below half", ctrl.get_phase_index() == 1, str(ctrl.get_phase_index()))
	# on_enter forces the regrow, and `once` means it must not come back.
	var ev: Dictionary = _until_resolve(w, REGROW, 10.0)
	_check("p2: the regrow fires on entry", not ev.is_empty(), str(ev))
	var sec: float = float(((_cfg.skills[REGROW]["effects"] as Dictionary)["heal"] as Dictionary)["sec"])
	_run(w, sec + 0.5)
	_check("p2: the regrow actually raised HP", state.enemy_hp > before,
		"%.1f -> %.1f" % [before, state.enemy_hp])
	_run(w, 24.0)
	_check("p2: the regrow happens only once (`once`)", _casts(w, REGROW) == 1, str(_casts(w, REGROW)))
	_check("p2: the croak does cast in phase two", _casts(w, CROAK) >= 1, str(_casts(w, CROAK)))


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in ["matriarch_spit", LASH, SINK, CROAK, REGROW]:
		for suffix: String in ["name", "counter"]:
			var key: String = "enemy_skill.%s.%s" % [id, suffix]
			_check("strings.csv has %s" % key, raw.contains(key + ","))

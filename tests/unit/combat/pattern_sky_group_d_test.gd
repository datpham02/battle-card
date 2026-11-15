extends SceneTree
## Monster Skill Phase 2 group S-D: storm_dragon — the Không Đảo (`sky_isles`) Warden, on
## islands_bridge. Hệ số: ×2,5.
## - dragon_tail_sweep: three cells along the hero's row, and a shove;
## - dragon_storm_breath: three cells straight down the hero's column, and a slow;
## - dragon_tempest (phase 2 only): a three-cell patch, then a shifted second beat that shoves.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_sky_group_d_test.gd
##
## THE OVERLAP LEG IS THE POINT OF THIS SUITE, and it is checked GEOMETRICALLY, from the cells the
## engine actually recorded — not from the data.
##
## A two-beat attack is only a CHAIN if its beats share ground. If the second beat lands entirely
## clear of the first, a hero who simply stands still is hit once, and the counterplay the design
## writes down — "đừng ăn cả hai nhịp" — becomes something that cannot be failed. That is not a
## theoretical worry: it happened. In Tháp Sương the Whiteout was reshaped to fit its arena and the
## shift chosen was two cells, which fit beautifully and left the beats disjoint; twelve seeds went by
## with the second beat never touching a stationary hero before a leg asked the right question.
##
## A data-shape check ("the followup offset is [[0,1]]") would not catch the next version of that
## mistake, because whether two shapes overlap depends on the shape AND the offset AND the rotation
## the planner picked. So this leg takes the two recorded cell lists and intersects them.
##
## WHAT THIS SUITE DOES NOT PROVE:
## - the 2 s push ICD of design §9.2: `push_icd_sec` is declared and read but NO CODE ASSIGNS IT, so
##   it is 0 in the shipped game. The Warden shoves on the sweep and on the tempest's second beat;
##   nothing here can see a cooldown that does not exist;
## - that the `island_drop` and `gust` traits fire in phase 2 with their overridden intervals: those
##   live on TraitHost, and pattern_fixtures builds none.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const SWEEP: String = "dragon_tail_sweep"
const BREATH: String = "dragon_storm_breath"
const TEMPEST: String = "dragon_tempest"

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
	test_sweep_runs_the_row()
	test_breath_runs_the_column_and_slows()
	test_phases_open_in_order()
	test_tempest_strikes_twice()
	test_tempest_beats_overlap_so_standing_still_eats_both()
	test_tempest_window_matches_the_approved_budget()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _dmg(id: String) -> float:
	return float((_cfg.skills[id]["effects"] as Dictionary).get("damage", 0.0))


func _only(ids: Array, shape: String, seed_value: int = 1, weights: Dictionary = {}) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = ((data["skills"] as Dictionary)[id] as Dictionary).duplicate(true)
		if weights.has(id):
			skills[id]["weight"] = weights[id]
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills,
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ids}}})
	var w: Dictionary = Fx.world(_grid(shape, seed_value), cfg, "g", seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	w["cfg"] = cfg
	return w


func _run(w: Dictionary, seconds: float) -> void:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < seconds:
		ctrl.tick(STEP)
		t += STEP


func _until(w: Dictionary, skill_id: String, want_followup: bool, limit: float = 24.0) -> Dictionary:
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
			if bool(ev.get("followup_strike", false)) == want_followup:
				return ev
		seen = ctrl.event_log.size()
	return {}


func _all_same_row(cells: Array) -> bool:
	if cells.size() < 2:
		return false
	var y: int = (cells[0] as Vector2i).y
	for c: Vector2i in cells:
		if c.y != y:
			return false
	return true


func _all_same_column(cells: Array) -> bool:
	if cells.size() < 2:
		return false
	var x: int = (cells[0] as Vector2i).x
	for c: Vector2i in cells:
		if c.x != x:
			return false
	return true


func _shared(a: Array, b: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in a:
		if b.has(c):
			out.append(c)
	return out


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	_check("storm_dragon is in enemy_skills.json", not _cfg.get_enemy("storm_dragon").is_empty())
	for id: String in [SWEEP, BREATH, TEMPEST]:
		_check("skill %s survived loading (not refused)" % id, _cfg.skills.has(id))
	if _cfg.skills.has(TEMPEST):
		var offs: Array = (_cfg.skills[TEMPEST]["pattern"] as Dictionary).get("offsets", []) as Array
		# Pinned: a 2x2 here could not reach one cell of islands_bridge, and the L was measured at 14/14.
		_check("the tempest is a three-cell patch, not a 2x2", offs.size() == 3, str(offs))
		_check("the tempest cannot be interrupted",
			not bool(_cfg.skills[TEMPEST].get("interruptible", true)))
		var fu: Dictionary = _cfg.skills[TEMPEST].get("followup", {}) as Dictionary
		_check("the tempest's second beat shoves",
			((fu.get("effects", {}) as Dictionary).get("push", {}) as Dictionary).has("cells"), str(fu))


func test_sweep_runs_the_row() -> void:
	var seen: bool = false
	for seed_value: int in range(1, 7):
		var w: Dictionary = _only([SWEEP], "islands_bridge", seed_value)
		var ev: Dictionary = _until(w, SWEEP, false, 14.0)
		if ev.is_empty():
			continue
		seen = true
		var cells: Array = ev.get("cells", []) as Array
		_check("sweep seed %d is a row of at least two cells" % seed_value,
			cells.size() >= 2 and _all_same_row(cells), str(cells))
	_check("the sweep casts on islands_bridge at all", seen)


func test_breath_runs_the_column_and_slows() -> void:
	var hit_seen: bool = false
	for seed_value: int in range(1, 9):
		var w: Dictionary = _only([BREATH], "islands_bridge", seed_value)
		var ev: Dictionary = _until(w, BREATH, false, 14.0)
		if ev.is_empty():
			continue
		var cells: Array = ev.get("cells", []) as Array
		# The design prints a column as [[0,0],[0,1]]; on this engine off.x walks the axis, so that
		# would be a bar. Five regions shipped the slip before it was caught each time.
		_check("breath seed %d is a column of at least two cells" % seed_value,
			cells.size() >= 2 and _all_same_column(cells), str(cells))
		if bool(ev.get("hit", false)) and not hit_seen:
			hit_seen = true
			_check("a connecting breath leaves the hero slowed",
				(w["status"] as StatusEffects).get_slow_left(P) > 0.0,
				str((w["status"] as StatusEffects).get_slow_left(P)))
	_check("the breath connects at least once across seeds", hit_seen)


func test_phases_open_in_order() -> void:
	var phases: Array = (_cfg.get_enemy("storm_dragon").get("phases", []) as Array)
	_check("the dragon has two phases", phases.size() == 2, str(phases.size()))
	if phases.size() != 2:
		return
	var p1: Dictionary = phases[0]
	var p2: Dictionary = phases[1]
	_check("phase 1 opens at full health", is_equal_approx(float(p1["enter_hp_ratio"]), 1.0))
	_check("phase 2 opens at half", is_equal_approx(float(p2["enter_hp_ratio"]), 0.5))
	_check("the tempest belongs to phase 2 only",
		not (p1["skills"] as Array).has(TEMPEST) and (p2["skills"] as Array).has(TEMPEST))
	# Live: the controller must actually change phase when the HP drops.
	var w: Dictionary = Fx.world(_grid("islands_bridge", 2), _cfg, "storm_dragon", 2, 200.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	var ctrl: PatternController = w["ctrl"]
	_run(w, 1.0)
	_check("the dragon opens in phase 1", ctrl.get_phase_index() == 0, str(ctrl.get_phase_index()))
	var state: CombatState = w["state"]
	state.enemy_hp = state.enemy_max_hp * 0.45
	var t: float = 0.0
	while t < 8.0 and ctrl.get_phase_index() == 0:
		_run(w, STEP)
		t += STEP
	_check("phase 2 opens once HP drops below half", ctrl.get_phase_index() == 1,
		str(ctrl.get_phase_index()))


func test_tempest_strikes_twice() -> void:
	# weight 0 in the data: it is cast by every_nth inside the phase, so a one-skill world must lift it.
	var w: Dictionary = _only([TEMPEST], "islands_bridge", 1, {TEMPEST: 1.0})
	var first: Dictionary = _until(w, TEMPEST, false)
	_check("the tempest's first beat resolves", not first.is_empty())
	var second: Dictionary = _until(w, TEMPEST, true, 8.0)
	_check("the tempest's second beat resolves", not second.is_empty())
	if first.is_empty() or second.is_empty():
		return
	_check("the first beat covers three cells", (first.get("cells", []) as Array).size() == 3,
		str(first.get("cells", [])))
	_check("the second beat hits for its own, lower number",
		float(second.get("damage", 0.0)) < float(first.get("damage", 0.0)),
		"%s vs %s" % [second.get("damage", 0.0), first.get("damage", 0.0)])


## THE OVERLAP LEG. Geometric, from the engine's own recorded cells.
func test_tempest_beats_overlap_so_standing_still_eats_both() -> void:
	var checked: int = 0
	for seed_value: int in range(1, 9):
		var w: Dictionary = _only([TEMPEST], "islands_bridge", seed_value, {TEMPEST: 1.0})
		var first: Dictionary = _until(w, TEMPEST, false, 16.0)
		if first.is_empty():
			continue
		var second: Dictionary = _until(w, TEMPEST, true, 8.0)
		if second.is_empty():
			continue
		checked += 1
		var a: Array = first.get("cells", []) as Array
		var b: Array = second.get("cells", []) as Array
		_check("seed %d: the second beat lands somewhere else" % seed_value, str(a) != str(b),
			"%s vs %s" % [a, b])
		_check("seed %d: but the beats still share ground (a hero who stands still eats both)"
			% seed_value, not _shared(a, b).is_empty(), "first=%s second=%s" % [a, b])
	_check("at least one full two-beat cast was examined (else the legs above are vacuous)",
		checked > 0)


## The damage budget the user approved: 40 + 30 = 70, which is 41% of the squishiest hero's 170 HP —
## the level already accepted in Hầm Ngục and Tháp Sương. Read from the data so a tuning pass moves
## the numbers without editing this file, but the RATIO is what the leg is really about.
func test_tempest_window_matches_the_approved_budget() -> void:
	var first: float = _dmg(TEMPEST)
	var fu: Dictionary = _cfg.skills[TEMPEST].get("followup", {}) as Dictionary
	var second: float = float((fu.get("effects", {}) as Dictionary).get("damage", 0.0))
	var window: float = first + second
	_check("the two beats together are a real window", window > 0.0, str(window))
	# 170 = phap_su, the lowest hero max_hp in characters.json, which is the right denominator for a
	# safety budget: the game has to be fair for the squishiest character, not the average one.
	var share: float = window / 170.0
	_check("the two-beat window stays under half the squishiest hero's health",
		share < 0.5, "window=%.0f share=%.0f%%" % [window, 100.0 * share])


func test_strings_rows() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in [SWEEP, BREATH, TEMPEST]:
		_check("strings.csv has a name row for %s" % id, text.contains("enemy_skill.%s.name" % id))
		_check("strings.csv has a counter row for %s" % id, text.contains("enemy_skill.%s.counter" % id))

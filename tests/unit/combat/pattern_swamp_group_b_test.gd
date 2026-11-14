extends SceneTree
## Monster Skill Phase 2 group W-B (MONSTER-SKILL-PHASE2-PLAN.md §16): marsh_toad, reed_witch and bog_hound on the
## shipped bog / reed_maze grids.
## - toad_tongue: a VERTICAL two-cell lance down the hero's column, data damage, then a one-cell pull;
## - witch_rot_cloud: an L of three cells with the hero in its corner, data damage + Độc;
## - hound_mire_chase: a lane along the hero's row, data damage, and a weight that doubles while the hero is Chậm;
## - every damage number is read from the shipped data, so a tuning pass moves them without touching this file.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_swamp_group_b_test.gd
##
## THE AXIS LEG IS THE POINT OF THIS SUITE.
## On `column_of_player` the planner maps Vector2i(player.x - off.y, start + off.x) (pattern_planner.gd:87): off.x
## walks DOWN the column, off.y walks ACROSS it. `[[0,0],[0,1]]` therefore lays a HORIZONTAL pair. That exact slip
## shipped twice before (eater_ember_belch, then scarab_spear — plan §12.1) and the design doc for this skill
## prints it a third time, so the data here deviates from the doc on purpose.
## The leg demands an UNCLIPPED two-cell cast before judging the axis. Without that, a cast clipped to one cell
## makes "every cell shares the hero's column" trivially true, which is how the scarab_spear bug passed its first
## test and shipped.
##
## WHAT THIS SUITE DOES NOT PROVE:
## `hound_mire_chase` carries `weights: {player_status: {slow: 2.0}}`. The legs below assert that weight is in the
## shipped data; they do NOT assert the planner actually prefers the skill while the hero is slowed, because a
## weight only shifts a probability and a deterministic suite cannot read a probability off one run. Whoever adds a
## multi-run weight harness should retire this paragraph and add that leg.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05

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
	test_tongue_runs_down_the_column()
	test_tongue_pulls()
	test_rot_cloud()
	test_mire_chase()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _dmg(id: String) -> float:
	return float((_cfg.skills[id]["effects"] as Dictionary).get("damage", 0.0))


func _only(ids: Array, shape: String, seed_value: int = 1) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = ((data["skills"] as Dictionary)[id] as Dictionary).duplicate(true)
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills,
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ids}}})
	var w: Dictionary = Fx.world(_grid(shape, seed_value), cfg, "g", seed_value, 1000.0)
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


func _until_resolve(w: Dictionary, skill_id: String, limit: float = 20.0) -> Dictionary:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	var seen: int = ctrl.event_log.size()
	while t < limit:
		_run(w, STEP)
		t += STEP
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id:
				return ev
		seen = ctrl.event_log.size()
	return {}


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["marsh_toad", "reed_witch", "bog_hound"]:
		_check("%s is in the shipped enemies" % id, _cfg.enemies.has(id))
	var off: Array = _cfg.skills["toad_tongue"]["pattern"]["offsets"] as Array
	_check("toad_tongue offsets walk DOWN the column, not across",
		off.size() == 2 and (off[0] as Vector2i) == Vector2i(0, 0) and (off[1] as Vector2i) == Vector2i(1, 0), str(off))
	_check("toad_tongue pulls one cell",
		int(((_cfg.skills["toad_tongue"]["effects"] as Dictionary).get("pull", {}) as Dictionary).get("cells", 0)) == 1)
	_check("witch_rot_cloud is an L of three cells",
		(_cfg.skills["witch_rot_cloud"]["pattern"]["offsets"] as Array).size() == 3,
		str(_cfg.skills["witch_rot_cloud"]["pattern"]["offsets"]))
	_check("witch_rot_cloud carries Độc",
		(((_cfg.skills["witch_rot_cloud"]["effects"] as Dictionary).get("status", {}) as Dictionary).get("id", "")) == "poison")
	_check("hound_mire_chase runs the hero's row",
		str(_cfg.skills["hound_mire_chase"]["pattern"]["anchor"]) == "row_of_player")
	_check("hound_mire_chase weighs Chậm at 2x",
		is_equal_approx(float((((_cfg.skills["hound_mire_chase"].get("weights", {}) as Dictionary).get("player_status", {})
			as Dictionary).get("slow", 0.0))), 2.0),
		str(_cfg.skills["hound_mire_chase"].get("weights", {})))


## The axis. An unclipped 2-cell cast is REQUIRED before the axis is judged — a 1-cell clipped cast would make the
## column assertion trivially true, which is exactly how this bug shipped once already.
func test_tongue_runs_down_the_column() -> void:
	var judged: bool = false
	for seed_value: int in range(1, 9):
		var w: Dictionary = _only(["toad_tongue"], "bog", seed_value)
		if not _until_stage(w, PatternController.Stage.WARNING):
			continue
		var red: Array[Vector2i] = (w["ctrl"] as PatternController).telegraph_cells()
		if red.size() != 2:
			continue  # clipped against the board edge; this seed cannot judge the axis
		var state: CombatState = w["state"]
		judged = true
		_check("tongue: the two cells share the hero's column (seed %d)" % seed_value,
			red[0].x == red[1].x and red[0].x == state.player_cell.x, str(red))
		_check("tongue: the two cells differ in row (a lance, not a bar) (seed %d)" % seed_value,
			red[0].y != red[1].y, str(red))
		break
	_check("tongue: an unclipped 2-cell cast was found to judge the axis on", judged,
		"no 2-cell cast over 8 seeds")


func test_tongue_pulls() -> void:
	var w: Dictionary = _only(["toad_tongue"], "bog")
	var state: CombatState = w["state"]
	var before: Vector2i = state.player_cell
	var ev: Dictionary = _until_resolve(w, "toad_tongue")
	_check("tongue: damage from data (%.0f)" % _dmg("toad_tongue"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("toad_tongue")), str(ev))
	# The pull moves the hero one cell toward the divide, OR is refused because something blocks it. Both are
	# legal; what must never happen is the hero drifting the WRONG way.
	# Direction is NOT a fixed axis. `CutEffects.pull_toward` steps the hero toward the CASTER's cell, and which
	# way that is depends on the board, so an assertion written as "x must not grow" encodes the author's guess
	# about board orientation rather than the rule. Assert the rule: the distance to the caster never grows.
	var after: Vector2i = state.player_cell
	var origin: Vector2i = state.cast_origin(E)
	var d_before: int = absi(before.x - origin.x) + absi(before.y - origin.y)
	var d_after: int = absi(after.x - origin.x) + absi(after.y - origin.y)
	_check("tongue: a hit never pushes the hero away from the caster",
		d_after <= d_before, "%s -> %s, caster %s (%d -> %d)" % [str(before), str(after), str(origin), d_before, d_after])


func test_rot_cloud() -> void:
	var w: Dictionary = _only(["witch_rot_cloud"], "reed_maze")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_check("cloud: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("cloud: the L covers the hero", red.has(state.player_cell), str(red))
	_check("cloud: 2-3 cells after clipping", red.size() >= 2 and red.size() <= 3, str(red))
	var ev: Dictionary = _until_resolve(w, "witch_rot_cloud")
	_check("cloud: damage from data (%.0f)" % _dmg("witch_rot_cloud"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("witch_rot_cloud")), str(ev))
	_check("cloud: a hit leaves Độc running", status.get_poison_left(P) > 0.0, str(status.get_poison_left(P)))


func test_mire_chase() -> void:
	var w: Dictionary = _only(["hound_mire_chase"], "bog")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_check("chase: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("chase: every cell is on the hero's row", red.size() > 0 and red.all(
		func(c: Vector2i) -> bool: return c.y == state.player_cell.y), "%s vs hero %s" % [str(red), str(state.player_cell)])
	_check("chase: at least 2 cells (min_cells)", red.size() >= 2, str(red))
	var ev: Dictionary = _until_resolve(w, "hound_mire_chase")
	_check("chase: damage from data (%.0f)" % _dmg("hound_mire_chase"),
		not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg("hound_mire_chase")), str(ev))


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in ["toad_tongue", "witch_rot_cloud", "hound_mire_chase"]:
		for suffix: String in ["name", "counter"]:
			var key: String = "enemy_skill.%s.%s" % [id, suffix]
			_check("strings.csv has %s" % key, raw.contains(key + ","))

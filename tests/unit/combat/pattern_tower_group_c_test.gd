extends SceneTree
## Monster Skill Phase 2 group T-C: ice_golem and ghost_elite — the two Tháp Sương (`ch3`) heavies,
## on the shipped diamond / cross_wide grids. Hệ số vùng: ×2,0.
## - ice_golem_glacier_fist: a 2x2 that must cover the hero, Đóng Băng on hit, and cannot be interrupted;
## - greater_ghost_wail: a three-cell line DOWN the hero's column, + 1 tầng Giá Lạnh;
## - ghost_phase: shared with the lesser ghost, listed by id rather than duplicated.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_tower_group_c_test.gd
##
## THE COLUMN LEG IS THE POINT OF THIS SUITE, and it is a guard against a documentation defect rather
## than a code one. MONSTER-SKILL-DESIGN.md prints a vertical line as `[[0,0],[0,1]]`. The engine walks
## `off.x` ALONG the chosen axis and `off.y` ACROSS it (pattern_planner.gd: column anchors map
## Vector2i(player.x - off.y, start + off.x)), so `[[0,0],[0,1]]` is two cells SIDE BY SIDE — a bar, not
## a column. Copying the document faithfully has produced that defect five times in earlier regions, and
## every one of them still "worked": the skill cast, hit, dealt its damage, and simply pointed the wrong
## way. No automated check catches a cast that is merely rotated 90 degrees, unless a leg asks.
## So one leg demands all three cells share a column, and it is the reason this file exists.
##
## THE SHARED-SKILL LEG is the other one worth reading. `ghost_phase` belongs to `ghost` (Hầm Ngục) and
## the Greater Ghost reuses it by id. The leg asserts there is no second copy under another name: a
## duplicated skill drifts the moment one copy is tuned, and nothing would report the divergence.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const FIST: String = "ice_golem_glacier_fist"
const WAIL: String = "greater_ghost_wail"

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
	test_fist_is_a_two_by_two_over_the_hero()
	test_fist_freezes_on_a_connecting_hit()
	test_wail_runs_down_a_column_not_across_a_row()
	test_wail_chills()
	test_ghost_phase_is_shared_not_duplicated()
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
	w["cfg"] = cfg
	return w


func _run(w: Dictionary, seconds: float) -> void:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < seconds:
		ctrl.tick(STEP)
		t += STEP


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


## The first resolve of [param skill_id] that actually connected, across seeds — a leg about what a HIT
## does proves nothing on a cast that missed.
func _first_hit(skill_id: String, shape: String, seeds: int = 12) -> Dictionary:
	for seed_value: int in range(1, seeds + 1):
		var w: Dictionary = _only([skill_id], shape, seed_value)
		for _i: int in range(4):
			var ev: Dictionary = _until_resolve(w, skill_id, 14.0)
			if ev.is_empty():
				break
			if bool(ev.get("hit", false)):
				ev["_world"] = w
				return ev
	return {}


func _all_same_column(cells: Array) -> bool:
	if cells.size() < 2:
		return false
	var x: int = (cells[0] as Vector2i).x
	for c: Vector2i in cells:
		if c.x != x:
			return false
	return true


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["ice_golem", "ghost_elite"]:
		_check("enemy %s is in enemy_skills.json" % id, not _cfg.get_enemy(id).is_empty())
	for id: String in [FIST, WAIL]:
		_check("skill %s survived loading (not refused)" % id, _cfg.skills.has(id))
	if _cfg.skills.has(FIST):
		_check("the fist cannot be interrupted", not bool(_cfg.skills[FIST].get("interruptible", true)))


func test_fist_is_a_two_by_two_over_the_hero() -> void:
	var w: Dictionary = _only([FIST], "diamond")
	var ev: Dictionary = _until_resolve(w, FIST)
	_check("the fist resolves", not ev.is_empty())
	if ev.is_empty():
		return
	var cells: Array = ev.get("cells", []) as Array
	_check("the fist covers four cells", cells.size() == 4, str(cells))
	# A 2x2 is two distinct columns and two distinct rows; four cells in a line would also be "four".
	var xs: Dictionary = {}
	var ys: Dictionary = {}
	for c: Vector2i in cells:
		xs[c.x] = true
		ys[c.y] = true
	_check("the four cells form a square, not a line", xs.size() == 2 and ys.size() == 2, str(cells))
	_check("the fist deals the data damage",
		is_equal_approx(float(ev.get("damage", 0.0)), _dmg(FIST)))


func test_fist_freezes_on_a_connecting_hit() -> void:
	var ev: Dictionary = _first_hit(FIST, "diamond")
	_check("the fist connects at least once across seeds", not ev.is_empty())
	if ev.is_empty():
		return
	var w: Dictionary = ev["_world"]
	_check("a connecting fist leaves the hero frozen", (w["status"] as StatusEffects).is_pinned(P))


## THE COLUMN LEG. See the header: the design document prints this shape on the wrong axis.
func test_wail_runs_down_a_column_not_across_a_row() -> void:
	var seen: bool = false
	for seed_value: int in range(1, 7):
		var w: Dictionary = _only([WAIL], "cross_wide", seed_value)
		var ev: Dictionary = _until_resolve(w, WAIL, 14.0)
		if ev.is_empty():
			continue
		seen = true
		var cells: Array = ev.get("cells", []) as Array
		# NOT "exactly 3": cross_wide clips. But a clipped wail must still be a COLUMN of >= 2.
		_check("wail seed %d is a column of at least two cells" % seed_value,
			cells.size() >= 2 and _all_same_column(cells), str(cells))
	_check("the wail casts on cross_wide at all", seen)


func test_wail_chills() -> void:
	var ev: Dictionary = _first_hit(WAIL, "cross_wide")
	_check("the wail connects at least once across seeds", not ev.is_empty())
	if ev.is_empty():
		return
	var w: Dictionary = ev["_world"]
	_check("a connecting wail leaves 1 tầng Giá Lạnh",
		(w["status"] as StatusEffects).frost_stacks(P) >= 1,
		str((w["status"] as StatusEffects).frost_stacks(P)))


func test_ghost_phase_is_shared_not_duplicated() -> void:
	var elite: Dictionary = _cfg.get_enemy("ghost_elite")
	var listed: Array = []
	for phase: Dictionary in (elite.get("phases", []) as Array):
		listed.append_array(phase.get("skills", []) as Array)
	_check("the Greater Ghost lists ghost_phase by id", listed.has("ghost_phase"), str(listed))
	# A second copy under another name would drift the moment either is tuned, with nothing reporting it.
	var copies: int = 0
	for id: String in _cfg.skills:
		if id != "ghost_phase" and id.ends_with("_phase") and id.begins_with("ghost"):
			copies += 1
	_check("no duplicate ghost phase skill was added for the elite", copies == 0, str(copies))


func test_strings_rows() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in [FIST, WAIL]:
		_check("strings.csv has a name row for %s" % id, text.contains("enemy_skill.%s.name" % id))
		_check("strings.csv has a counter row for %s" % id, text.contains("enemy_skill.%s.counter" % id))

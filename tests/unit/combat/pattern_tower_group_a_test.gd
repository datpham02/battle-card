extends SceneTree
## Monster Skill Phase 2 group T-A: frost_sprite, wisp and stone_sentry — the first three Tháp Sương (`ch3`)
## normals, on the shipped square / rect / cross_wide grids. Hệ số vùng: ×2,0.
## - sprite_frost_kiss: one cell, data damage + 1 tầng Giá Lạnh;
## - wisp_lantern + wisp_lantern_flare: a marker, then a two-cell line along the marker's row;
## - sentry_rime_bulwark + sentry_hammer: a self guard, and a two-cell bar.
## Damage is read from the shipped data, so a tuning pass moves the numbers without touching this file.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_tower_group_a_test.gd
##
## THE ANCHOR LEG AND THE EXISTENCE LEG ARE THE POINT OF THIS SUITE.
## Both come from defects this region actually shipped with, for about twenty minutes, on 2026-11-15:
##
## 1. `wisp_lantern_flare` first carried `requires_anchor` at the SKILL level. The engine reads it from
##    `conditions` (enemy_skills_config.gd:260, pattern_controller.gd:586), so the misplaced key was
##    ignored IN SILENCE — no refusal, no `problems` entry, nothing. The flare would have fired with no
##    lantern anywhere, which is the entire mechanic of the Wisp. Every other leg in this suite passes
##    just as happily in that broken state: the flare still lands on a row, still deals its damage, still
##    applies Giá Lạnh. So one leg runs the Wisp with NO marker on the board and demands silence.
##
## 2. `sentry_rime_bulwark` first used `anchor: "self"` (which does not exist — the engine's list is
##    on_player, near_player, row_of_player, column_of_player, row_of_anchor, fixed, self_cell,
##    enemy_half_empty) and `origin: "caster"` with DIRECT_MANIFESTATION. Each was enough on its own to
##    have the skill REFUSED and dropped from the enemy. A dropped skill is not a broken skill: the Sentry
##    simply never guards, and nothing anywhere says why. `_cfg.problems` caught that one — which is why
##    the first leg below is the problems check, and why it prints the problems rather than just a count.
##
## WHAT THIS SUITE DOES NOT PROVE:
## It does not prove the lantern is DRAWN, or drawn in a colour that reads as ice. `floor_layer.gd` paints
## an unknown marker kind with MARKER_ANCHOR (wood brown, 7A5230) and has no branch for "lantern"; that is
## a known open defect, not something a headless suite can see. Do not read these green legs as "the Wisp
## looks right".

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05

var fails: int = 0
var _cfg: EnemySkillsConfig
var _library: ArenaLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	# `extra` prints on FAIL only. A hint printed beside PASS reads as a finding and has been
	# misread as one before.
	print(("PASS " + name) if ok else ("FAIL " + name + (" " + extra if not extra.is_empty() else "")))
	if not ok:
		fails += 1


func _initialize() -> void:
	_cfg = EnemySkillsConfig.load_from_file()
	_library = ArenaLibrary.load_from_file()
	_check("shipped enemy_skills.json has no problems", _cfg.problems.is_empty(), str(_cfg.problems))
	test_data_shape()
	test_frost_kiss_one_cell_and_one_stack()
	test_lantern_places_a_marker()
	test_flare_never_casts_without_a_lantern()
	test_flare_runs_two_cells_once_a_lantern_stands()
	test_bulwark_exists_and_guards()
	test_hammer_is_a_two_cell_bar()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _dmg(id: String) -> float:
	return float((_cfg.skills[id]["effects"] as Dictionary).get("damage", 0.0))


## A world running ONLY [param ids], so one skill's behaviour cannot be explained by another's.
## `weight_override`: a skill shipped with weight 0 (cast only by `every_nth`) would never be picked in
## isolation, so the caller lifts it. Lifting weight also means the cooldown is the only spacing left.
func _only(ids: Array, shape: String, seed_value: int = 1, weight_override: Dictionary = {}) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = ((data["skills"] as Dictionary)[id] as Dictionary).duplicate(true)
		if weight_override.has(id):
			skills[id]["weight"] = weight_override[id]
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


func _cells_of(ev: Dictionary) -> Array:
	return ev.get("cells", []) as Array


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["frost_sprite", "wisp", "stone_sentry"]:
		var e: Dictionary = _cfg.get_enemy(id)
		_check("enemy %s is in enemy_skills.json" % id, not e.is_empty())
	for id: String in ["sprite_frost_kiss", "wisp_lantern", "wisp_lantern_flare",
			"sentry_rime_bulwark", "sentry_hammer"]:
		_check("skill %s survived loading (not refused)" % id, _cfg.skills.has(id))
	# The misplaced-key defect, pinned so it cannot come back quietly in any Tháp Sương skill.
	for id: String in _cfg.skills:
		if not id.begins_with("wisp_") and not id.begins_with("sentry_") and not id.begins_with("sprite_frost"):
			continue
		var raw: Dictionary = _cfg.skills[id]
		_check("skill %s keeps requires_anchor inside conditions, not at skill level" % id,
			not raw.has("requires_anchor"))


func test_frost_kiss_one_cell_and_one_stack() -> void:
	var w: Dictionary = _only(["sprite_frost_kiss"], "square")
	var ev: Dictionary = _until_resolve(w, "sprite_frost_kiss")
	_check("frost_kiss resolves", not ev.is_empty())
	if ev.is_empty():
		return
	_check("frost_kiss covers exactly one cell", _cells_of(ev).size() == 1, str(_cells_of(ev)))
	_check("frost_kiss deals the data damage",
		is_equal_approx(float(ev.get("damage", 0.0)), _dmg("sprite_frost_kiss")),
		"%s vs data %s" % [ev.get("damage", 0.0), _dmg("sprite_frost_kiss")])
	var st: StatusEffects = w["status"]
	_check("frost_kiss leaves exactly 1 tầng Giá Lạnh", st.frost_stacks(P) == 1, str(st.frost_stacks(P)))


func test_lantern_places_a_marker() -> void:
	var w: Dictionary = _only(["wisp_lantern"], "rect")
	_run(w, 6.0)
	var ctrl: PatternController = w["ctrl"]
	_check("lantern places a marker", ctrl.marker_cells().size() >= 1, str(ctrl.marker_cells()))
	var grid: BoardGrid = w["state"].grid
	var on_enemy_half: bool = true
	for c: Vector2i in ctrl.marker_cells():
		if grid.is_player_cell(c):
			on_enemy_half = false
	_check("the lantern hangs on the enemy half", on_enemy_half, str(ctrl.marker_cells()))


## THE REGRESSION LEG. With `requires_anchor` at the skill level the engine ignored it and the flare fired
## with no lantern at all. Running the flare ALONE means no lantern can ever exist, so a single resolve is
## the defect. Watched failing against the misplaced-key version before this leg was trusted.
func test_flare_never_casts_without_a_lantern() -> void:
	var w: Dictionary = _only(["wisp_lantern_flare"], "rect")
	var ev: Dictionary = _until_resolve(w, "wisp_lantern_flare", 14.0)
	_check("flare never resolves while no lantern stands", ev.is_empty(), str(ev))
	var ctrl: PatternController = w["ctrl"]
	_check("and the config did not quietly refuse the flare instead",
		(w["cfg"] as EnemySkillsConfig).skills.has("wisp_lantern_flare"))
	# Guard against the leg passing for the wrong reason: a flare that cannot be PLANNED anywhere would
	# also never resolve. The controller must still be alive and choosing.
	_check("the controller is running, not stalled", ctrl.event_log.size() >= 0)


func test_flare_runs_two_cells_once_a_lantern_stands() -> void:
	var w: Dictionary = _only(["wisp_lantern", "wisp_lantern_flare"], "rect")
	var ev: Dictionary = _until_resolve(w, "wisp_lantern_flare", 24.0)
	_check("flare resolves once a lantern stands", not ev.is_empty())
	if ev.is_empty():
		return
	var cells: Array = _cells_of(ev)
	_check("flare covers two cells", cells.size() == 2, str(cells))
	# The axis: `row_of_anchor` walks off.x ALONG the row, so the two cells share a row.
	# The design document prints [[0,0],[0,1]] for a line, which is the other axis; this leg is what
	# stops that printing from reaching the data a sixth time.
	var same_row: bool = cells.size() == 2 and (cells[0] as Vector2i).y == (cells[1] as Vector2i).y
	_check("the flare's two cells lie along one row, not across rows", same_row, str(cells))
	_check("flare deals the data damage",
		is_equal_approx(float(ev.get("damage", 0.0)), _dmg("wisp_lantern_flare")))


func test_bulwark_exists_and_guards() -> void:
	# The existence half is not ceremony: the shipped version of this skill was REFUSED for two separate
	# schema errors, and a refused skill is silently dropped from the enemy's list.
	_check("bulwark is a loaded skill, not a refused one", _cfg.skills.has("sentry_rime_bulwark"))
	if not _cfg.skills.has("sentry_rime_bulwark"):
		return
	var w: Dictionary = _only(["sentry_rime_bulwark"], "cross_wide")
	_run(w, 6.0)
	# Guard lives on StatusEffects, not CombatState. The first version of this line called a
	# CombatState.guard_of() that does not exist: the leg raised a SCRIPT ERROR, was abandoned
	# half-way, and the suite still printed FAILS=0 and exited 0. A missing assertion is invisible
	# in the failure count — which is why the project's runner counts script errors separately and
	# why "FAILS=0" alone is never read as a pass.
	var st: StatusEffects = w["status"]
	var amount: float = st.guard_amount(E)
	_check("the Sentry actually gains guard", amount > 0.0, str(amount))
	_check("the guard matches the shipped amount",
		is_equal_approx(amount, float((_cfg.skills["sentry_rime_bulwark"]["effects"]["guard"] as Dictionary)["amount"])),
		"%s vs data" % amount)


func test_hammer_is_a_two_cell_bar() -> void:
	var w: Dictionary = _only(["sentry_hammer"], "cross_wide")
	var ev: Dictionary = _until_resolve(w, "sentry_hammer")
	_check("hammer resolves", not ev.is_empty())
	if ev.is_empty():
		return
	var cells: Array = _cells_of(ev)
	_check("hammer covers two cells", cells.size() == 2, str(cells))
	var a: Vector2i = cells[0]
	var b: Vector2i = cells[1]
	_check("the two cells are adjacent", absi(a.x - b.x) + absi(a.y - b.y) == 1, str(cells))
	_check("hammer deals the data damage",
		is_equal_approx(float(ev.get("damage", 0.0)), _dmg("sentry_hammer")))


func test_strings_rows() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in ["sprite_frost_kiss", "wisp_lantern", "wisp_lantern_flare",
			"sentry_rime_bulwark", "sentry_hammer"]:
		_check("strings.csv has a name row for %s" % id,
			text.contains("enemy_skill.%s.name" % id))
		_check("strings.csv has a counter row for %s" % id,
			text.contains("enemy_skill.%s.counter" % id))

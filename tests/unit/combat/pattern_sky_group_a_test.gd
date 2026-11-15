extends SceneTree
## Monster Skill Phase 2 group S-A: cloud_sprite, harpy and wind_monk — the first three Không Đảo
## (`sky_isles`) normals, on the shipped twin_isles / three_isles / islands_bridge grids. Hệ số: ×2,5.
## - cloud_sprite_mist_veil: a timed shroud that hides the placement hit forecast;
## - harpy_dive: one cell and a shove back;
## - monk_gale_palm: two cells straight down the hero's column, and a shove;
## - monk_wind_step: a reposition that does not count as a cast.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_sky_group_a_test.gd
##
## THE SHROUD LEG IS THE POINT OF THIS SUITE, and it is here because the effect had NEVER SHIPPED.
## Before this region no skill anywhere used `effects.shroud` — only the Cloud Veil's trait did. A
## skill-driven shroud reaches the HUD through a different road: PatternController.is_shrouded() ->
## TraitHost.extra_forecast_blocked_fn (wired in combat_view.gd:3055 and :3206) -> hit_forecast_blocked().
## Reading only TraitHost.hit_forecast_blocked() makes that road look absent — it loops over traits and
## returns — and the OR into extra_forecast_blocked_fn is the last line of the function. So the leg below
## asserts the controller's own flag, which is the half this suite can see headlessly, and the header
## says plainly what it does not prove.
##
## THE PUSH LEG is the other one worth reading. `push` is the region's identity and the engine takes only
## `{"cells": n}` — there is no direction key, the shove is always away from the caster. A leg that only
## checked the data would pass while nothing moved, so this one reads the hero's CELL before and after.
##
## WHAT THIS SUITE DOES NOT PROVE:
## - that the forecast is actually hidden on screen: that needs the HUD, and no fixture here builds one;
## - that the shove respects the push ICD of design §9.2. It cannot: `push_icd_sec` is declared in
##   pattern_controller.gd:60, read at :935, and NO CODE ANYWHERE ASSIGNS IT (only a test injects it).
##   In the shipped game it is 0, so shoves have no cooldown at all. That is a known, reported gap, not
##   something these legs can cover — and this region has five push sources.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const VEIL: String = "cloud_sprite_mist_veil"
const DIVE: String = "harpy_dive"
const PALM: String = "monk_gale_palm"
const STEP_SKILL: String = "monk_wind_step"

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
	test_mist_veil_raises_the_shroud()
	test_dive_is_one_cell_and_shoves()
	test_palm_runs_down_the_column_not_across()
	test_wind_step_moves_without_counting_as_a_cast()
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
	for id: String in ["cloud_sprite", "harpy", "wind_monk"]:
		_check("enemy %s is in enemy_skills.json" % id, not _cfg.get_enemy(id).is_empty())
	for id: String in [VEIL, DIVE, PALM, STEP_SKILL]:
		_check("skill %s survived loading (not refused)" % id, _cfg.skills.has(id))
	# push takes `cells` only: the engine has no direction key, and a stray one would be ignored
	# in silence rather than refused.
	for id: String in [DIVE, PALM]:
		if not _cfg.skills.has(id):
			continue
		var push: Dictionary = (_cfg.skills[id]["effects"] as Dictionary).get("push", {}) as Dictionary
		_check("%s shoves by a declared number of cells" % id, int(push.get("cells", 0)) >= 1, str(push))


## THE SHROUD LEG. First skill in the project to use `effects.shroud`.
func test_mist_veil_raises_the_shroud() -> void:
	var w: Dictionary = _only([VEIL], "twin_isles")
	var ctrl: PatternController = w["ctrl"]
	_check("no shroud before the sprite casts", not ctrl.is_shrouded())
	var ev: Dictionary = _until_resolve(w, VEIL, 16.0)
	_check("the veil resolves", not ev.is_empty())
	if ev.is_empty():
		return
	_check("the veil raises the controller's shroud", ctrl.is_shrouded(),
		"shroud_left=%.2f" % ctrl.shroud_left())
	# It is a TIMED shroud, unlike the Cloud Veil's permanent trait: it must run out on its own.
	_run(w, 4.0)
	_check("and the shroud expires on its own", not ctrl.is_shrouded(),
		"shroud_left=%.2f" % ctrl.shroud_left())


## THE PUSH LEG, in BOTH directions — and the first version of it was wrong in a way worth recording.
##
## It ran eight seeds and asked whether the hero moved on any of them. The answer was no, every time,
## and the damage read 33 against the data's 25. That looks like two separate defects; it is one
## correct behaviour. `CutEffects._push` moves the player side toward -x, and on `three_isles`
## (`##.##.#` on the near row) the fixture's default cell (3, 0) has a HOLE at (2, 0). The shove is
## blocked, and a blocked shove is an R3 slam: 25 + 8 = 33. Design §4.7 states exactly this —
## "trên three_isles (7×2) đứng hàng sau = đẩy bị chặn = Va Đập → đứng hàng trước".
##
## So the seeds were never the variable: the fixture puts the hero on the same cell every time, and
## that cell is the blocked one. Looping eight of them measured one situation eight times.
##
## Placing the hero deliberately turns the weakest leg in this suite into the strongest: the shove
## LANDS from (4, 0) and is BLOCKED from (3, 0), with the R3 showing up as damage on exactly the
## blocked side. A leg that only saw the landing case would pass against an engine that never slams;
## a leg that only saw the blocked case would pass against an engine that never pushes.
func test_dive_is_one_cell_and_shoves() -> void:
	# --- the shove LANDS: (4, 0) -> (3, 0), and the damage is the data's, with no R3 added.
	var a: Dictionary = _only([DIVE], "three_isles", 1)
	var sa: CombatState = a["state"]
	sa.set_player_cell(Vector2i(4, 0))
	var ea: Dictionary = _until_resolve(a, DIVE, 14.0)
	_check("the dive resolves from (4,0)", not ea.is_empty() and bool(ea.get("hit", false)), str(ea))
	if not ea.is_empty() and bool(ea.get("hit", false)):
		_check("the dive covers exactly one cell", (ea.get("cells", []) as Array).size() == 1,
			str(ea.get("cells", [])))
		_run(a, 0.4)
		_check("an unblocked shove moves the hero one cell toward the far side",
			sa.cell_of(P) == Vector2i(3, 0), "hero=%s" % sa.cell_of(P))
		_check("and the hit is the data damage, with no slam added",
			is_equal_approx(float(ea.get("damage", 0.0)), _dmg(DIVE)),
			"%s vs data %s" % [ea.get("damage", 0.0), _dmg(DIVE)])

	# --- the shove is BLOCKED by the hole at (2, 0): the hero stays and takes the R3 slam on top.
	var b: Dictionary = _only([DIVE], "three_isles", 1)
	var sb: CombatState = b["state"]
	sb.set_player_cell(Vector2i(3, 0))
	var eb: Dictionary = _until_resolve(b, DIVE, 14.0)
	_check("the dive resolves from (3,0)", not eb.is_empty() and bool(eb.get("hit", false)), str(eb))
	if not eb.is_empty() and bool(eb.get("hit", false)):
		_run(b, 0.4)
		_check("a blocked shove leaves the hero where it stood",
			sb.cell_of(P) == Vector2i(3, 0), "hero=%s" % sb.cell_of(P))
		_check("and the blocked shove costs MORE than the plain hit (the R3 slam)",
			float(eb.get("damage", 0.0)) > _dmg(DIVE) + 0.5,
			"blocked=%s vs data %s" % [eb.get("damage", 0.0), _dmg(DIVE)])


func test_palm_runs_down_the_column_not_across() -> void:
	var seen: bool = false
	for seed_value: int in range(1, 7):
		var w: Dictionary = _only([PALM], "islands_bridge", seed_value)
		var ev: Dictionary = _until_resolve(w, PALM, 14.0)
		if ev.is_empty():
			continue
		seen = true
		var cells: Array = ev.get("cells", []) as Array
		# The design document prints this shape as [[0,0],[0,1]], which on this engine is two cells
		# SIDE BY SIDE. Five earlier regions shipped that slip before it was caught each time.
		_check("palm seed %d is a column of at least two cells" % seed_value,
			cells.size() >= 2 and _all_same_column(cells), str(cells))
	_check("the palm casts on islands_bridge at all", seen)


func test_wind_step_moves_without_counting_as_a_cast() -> void:
	_check("wind step is marked as not counting as a cast",
		not bool(_cfg.skills.get(STEP_SKILL, {}).get("counts_as_cast", true)))
	var w: Dictionary = _only([STEP_SKILL], "islands_bridge")
	var ctrl: PatternController = w["ctrl"]
	var before: Vector2i = (w["state"] as CombatState).cell_of(E)
	var ev: Dictionary = _until_resolve(w, STEP_SKILL, 14.0)
	_check("wind step resolves", not ev.is_empty())
	if ev.is_empty():
		return
	_run(w, 0.4)
	_check("the monk ends up somewhere else", (w["state"] as CombatState).cell_of(E) != before,
		"%s -> %s" % [before, (w["state"] as CombatState).cell_of(E)])
	_check("and the move deals no damage", is_equal_approx(float(ev.get("damage", 0.0)), 0.0),
		str(ev.get("damage", 0.0)))


func test_strings_rows() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in [VEIL, DIVE, PALM, STEP_SKILL]:
		_check("strings.csv has a name row for %s" % id, text.contains("enemy_skill.%s.name" % id))
		_check("strings.csv has a counter row for %s" % id, text.contains("enemy_skill.%s.counter" % id))

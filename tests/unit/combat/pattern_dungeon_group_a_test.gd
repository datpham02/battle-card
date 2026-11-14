extends SceneTree
## Monster Skill Phase 2 group D-A (MONSTER-SKILL-PHASE2-PLAN.md §19): skeleton, zombie and bat_swarm, the first
## three Hầm Ngục normals, on the shipped square / rect / cross grids. Hệ số vùng: ×2,5.
## - skeleton_shield_bash: one cell, data damage + a brief Ghim;
## - zombie_grab: one cell, data damage + Trói;
## - swarm_scatter: three SEPARATE bites whose shape changes between casts, data damage + 1 Rạn.
## Damage is read from the shipped data, so a tuning pass moves the numbers without touching this file.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_dungeon_group_a_test.gd
##
## THE VARIANTS LEG IS THE POINT OF THIS SUITE.
## `swarm_scatter` ships three shapes under `pattern.variants`. Every other leg here would pass just as well if the
## engine silently used the first shape forever — the cells would still be scattered, still clip, still hit. The
## only thing that would be lost is the identity of the skill ("a shape that changes each time"), and nothing
## about a single cast can reveal that. So one leg casts across many seeds and demands at least two DISTINCT
## shapes. It is the same hole as a gate tested in one direction: correct behaviour and a broken-but-plausible
## behaviour produce identical evidence unless you look for the difference on purpose.
##
## WHAT THIS SUITE DOES NOT PROVE:
## `swarm_flutter` ships as an `overrides` block on shared_sidestep, not as a skill of its own (§4.5 calls it
## "shared_sidestep with its own numbers"). The leg below asserts no `swarm_flutter` skill exists and that the
## bat's override carries the design's numbers. It does NOT assert the player ever sees the move named "Bay Tản" —
## no fixture here renders a skill banner.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const SCATTER: String = "swarm_scatter"

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
	test_shield_bash_pins()
	test_grab_roots()
	test_scatter_bites_and_marks()
	test_scatter_actually_varies_its_shape()
	test_guard_damage_budget()
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


## The sorted cell offsets of [param cells] relative to their own top-left, so the same SHAPE in two places
## compares equal and two different shapes do not.
func _shape_key(cells: Array[Vector2i]) -> String:
	if cells.is_empty():
		return ""
	var min_x: int = cells[0].x
	var min_y: int = cells[0].y
	for c: Vector2i in cells:
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
	var norm: Array[Vector2i] = []
	for c: Vector2i in cells:
		norm.append(Vector2i(c.x - min_x, c.y - min_y))
	norm.sort()
	return str(norm)


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["skeleton", "zombie", "bat_swarm"]:
		_check("%s is in the shipped enemies" % id, _cfg.enemies.has(id))
	_check("shield_bash leaves Ghim",
		(((_cfg.skills["skeleton_shield_bash"]["effects"] as Dictionary).get("status", {}) as Dictionary).get("id", "")) == "pin")
	_check("grab leaves Trói",
		(((_cfg.skills["zombie_grab"]["effects"] as Dictionary).get("status", {}) as Dictionary).get("id", "")) == "root")
	var sc: Dictionary = _cfg.skills[SCATTER]["pattern"] as Dictionary
	_check("scatter ships three shapes", (sc.get("variants", []) as Array).size() == 3, str(sc.get("variants", [])))
	# §16.2: a multi-cell pattern on an irregular arena must clip, or it silently never casts.
	_check("scatter clips", bool(sc.get("clip", false)) and int(sc.get("min_cells", 0)) >= 2, str(sc))
	_check("scatter leaves 1 Rạn",
		(((_cfg.skills[SCATTER]["effects"] as Dictionary).get("status", {}) as Dictionary).get("id", "")) == "fragile")
	# §4.5: the bat's flutter is shared_sidestep with its own numbers, not a second skill the player would see named.
	_check("there is no separate swarm_flutter skill", not _cfg.skills.has("swarm_flutter"))
	# Overrides are read off the PHASE, never the enemy (enemy_skills_config.gd:131). A phaseless enemy gets a
	# synthetic phase built as {"id": "main", "enter_hp_ratio": 1.0, "skills": ...} (:402) which carries NO
	# overrides — so an `overrides` block written at the enemy level is DROPPED IN SILENCE, with `_cfg.problems`
	# empty. That is why the bat and the skeleton ship an explicit single phase. Ask the config the same way the
	# engine does, rather than reading the raw dict.
	var phases: Array = (_cfg.enemies["bat_swarm"] as Dictionary).get("phases", []) as Array
	_check("the bat has a phase to hang its overrides on", phases.size() == 1, str(phases.size()))
	if phases.size() == 1:
		var merged: Dictionary = _cfg.skill_for_phase("shared_sidestep", phases[0] as Dictionary)
		var base: Dictionary = _cfg.skills["shared_sidestep"] as Dictionary
		_check("the bat's sidestep carries its own numbers, merged by the engine's own path",
			is_equal_approx(float(merged.get("weight", 0.0)), 1.0)
			and is_equal_approx(float(merged.get("cooldown_sec", 0.0)), 3.0),
			"merged=%s base=%s" % [str(merged.get("weight")), str(base.get("weight"))])
		_check("and those numbers really differ from the shared default",
			not is_equal_approx(float(merged.get("weight", 0.0)), float(base.get("weight", 0.0))),
			"both %s — the override would be invisible" % str(base.get("weight")))


func test_shield_bash_pins() -> void:
	var w: Dictionary = _only(["skeleton_shield_bash"], "square")
	var status: StatusEffects = w["status"]
	var ev: Dictionary = _until_resolve(w, "skeleton_shield_bash")
	_check("bash: damage from data (%.0f)" % _dmg("skeleton_shield_bash"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("skeleton_shield_bash")), str(ev))
	_check("bash: a hit pins the hero", status.is_pinned(P))


func test_grab_roots() -> void:
	var w: Dictionary = _only(["zombie_grab"], "rect")
	var status: StatusEffects = w["status"]
	var ev: Dictionary = _until_resolve(w, "zombie_grab")
	_check("grab: damage from data (%.0f)" % _dmg("zombie_grab"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("zombie_grab")), str(ev))
	_check("grab: a hit roots the hero", status.is_rooted(P))


func test_scatter_bites_and_marks() -> void:
	var w: Dictionary = _only([SCATTER], "cross")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_check("scatter: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("scatter: the first bite is on the hero", red.has(state.player_cell), str(red))
	_check("scatter: 2-3 cells after clipping", red.size() >= 2 and red.size() <= 3, str(red))
	var ev: Dictionary = _until_resolve(w, SCATTER)
	_check("scatter: damage from data (%.0f)" % _dmg(SCATTER),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg(SCATTER)), str(ev))
	_check("scatter: a hit leaves 1 Rạn", status.fragile_stacks(P) >= 1, str(status.fragile_stacks(P)))


## Three shapes in the data mean nothing if the engine always reaches for the first one. Every other leg in this
## file would stay green in that case.
func test_scatter_actually_varies_its_shape() -> void:
	var shapes: Dictionary = {}
	for seed_value: int in range(1, 13):
		var w: Dictionary = _only([SCATTER], "cross", seed_value)
		if not _until_stage(w, PatternController.Stage.WARNING):
			continue
		var red: Array[Vector2i] = (w["ctrl"] as PatternController).telegraph_cells()
		if red.size() < 3:
			continue  # clipped: the shape cannot be judged from a partial cast
		shapes[_shape_key(red)] = true
	_check("scatter: at least one unclipped cast was found", shapes.size() >= 1,
		"no 3-cell cast over 12 seeds — the leg below cannot judge anything")
	_check("scatter: the shape really does change between casts", shapes.size() >= 2,
		"only %d distinct shape(s) over 12 seeds: %s" % [shapes.size(), str(shapes.keys())])


## The region budget: the heaviest single blow in this group, after the ×1.5 Rạn multiplier, must stay under half
## the lowest hero's HP. At ×2.5 the group's worst is the bash/grab at 20 → 30, well inside.
func test_guard_damage_budget() -> void:
	var low: float = INF
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/characters.json")) as Dictionary
	var chars: Variant = raw.get("characters", raw)
	var list: Array = (chars.values() if typeof(chars) == TYPE_DICTIONARY else chars) as Array
	for c: Variant in list:
		var cd: Dictionary = c as Dictionary
		var attrs: Dictionary = cd.get("attributes", {}) as Dictionary
		var hp: float = float(attrs.get("max_hp", cd.get("max_hp", INF)))
		low = minf(low, hp)
	var worst: float = 0.0
	for id: String in ["skeleton_shield_bash", "zombie_grab", SCATTER]:
		worst = maxf(worst, _dmg(id) * 1.5)
	_check("guard: the worst D-A hit (×1.5 Rạn) < half the lowest hero HP",
		low < INF and worst > 0.0 and worst < 0.5 * low,
		"worst %.0f vs half of %.0f" % [worst, low])


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in ["skeleton_shield_bash", "zombie_grab", SCATTER]:
		for suffix: String in ["name", "counter"]:
			var key: String = "enemy_skill.%s.%s" % [id, suffix]
			_check("strings.csv has %s" % key, raw.contains(key + ","))

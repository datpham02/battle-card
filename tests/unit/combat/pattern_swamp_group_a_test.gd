extends SceneTree
## Monster Skill Phase 2 group W-A (MONSTER-SKILL-PHASE2-PLAN.md §15): bog_rat, mire_slug and swamp_lizard on the
## shipped bog / reed_maze grids.
## - rat_gnaw: one cell on the hero, data damage, and Độc that REFRESHES rather than stacks;
## - slug_slime_trail: TWO cells BESIDE the hero, never the hero's own, left as mire, and no damage of its own
##   (deviation from §4.4 recorded in the plan: `count` is marker-only, so the two cells are written as offsets);
## - lizard_tail_sweep: a 3-cell bar covering the hero, data damage + Chậm;
## - lizard_drag_bite: the GATE — it must not fire at a hero who is neither slowed nor standing in mire, and must
##   fire once they are. §4.4 writes that gate as "slow OR mire"; `_conditions_ok` ANDs across keys
##   (pattern_controller.gd:595), so it ships as TWO entries sharing one name_key / counter_key. The legs below
##   check BOTH entries, because a gate that only half exists is the failure this split is most likely to cause.
## Hit damage is read from the shipped data, so a tuning pass moves the numbers without touching this file.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_swamp_group_a_test.gd
##
## WHAT THIS SUITE DOES NOT PROVE — and the blocker that would retire this paragraph:
## The two drag-bite entries share a name_key and a counter_key so the PLAYER sees one skill with one rule. This
## suite asserts the keys are equal; it does NOT assert the player ever sees one name, because no fixture here
## renders a skill banner. If a UI pass ever starts showing the raw skill id, the player sees "Cắn Lôi" twice under
## two ids and this paragraph becomes wrong — check the banner then, and either retire the split or make the UI
## key off name_key.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const BITE: String = "lizard_drag_bite"
const BITE_MIRE: String = "lizard_drag_bite_mire"

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
	test_rat_gnaw()
	test_slime_trail_mires_two_cells_beside_the_hero()
	test_tail_sweep()
	test_drag_bite_is_gated()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _dmg(id: String) -> float:
	return float((_cfg.skills[id]["effects"] as Dictionary).get("damage", 0.0))


## A world holding only [param ids] on one enemy, so one skill can be tested in isolation.
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
			hazards.tick(STEP, state)  # TileHazards.tick(delta, state) — there is no on_tick
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


func _until_stage(w: Dictionary, stage: int, limit: float = 8.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		_run(w, STEP)
		t += STEP
		if ctrl.get_stage() == stage:
			return true
	return false


## Every resolve of [param skill_id] in the log so far.
func _casts(w: Dictionary, skill_id: String) -> int:
	var n: int = 0
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id:
			n += 1
	return n


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["bog_rat", "mire_slug", "swamp_lizard"]:
		_check("%s is in the shipped enemies" % id, _cfg.enemies.has(id))
	_check("rat_gnaw carries Độc", (((_cfg.skills["rat_gnaw"]["effects"] as Dictionary).get("status", {})
		as Dictionary).get("id", "")) == "poison")
	_check("slug_slime_trail lays mire and no damage",
		(((_cfg.skills["slug_slime_trail"]["effects"] as Dictionary).get("zone", {}) as Dictionary).get("id", "")) == "mire"
		and is_equal_approx(_dmg("slug_slime_trail"), 0.0))
	_check("slug_slime_trail is TWO cells, not count: 2",
		(_cfg.skills["slug_slime_trail"]["pattern"]["offsets"] as Array).size() == 2,
		str(_cfg.skills["slug_slime_trail"]["pattern"]["offsets"]))
	# The split gate: two entries, one skill as far as the player is concerned.
	_check("both drag-bite entries share one name_key",
		str(_cfg.skills[BITE]["name_key"]) == str(_cfg.skills[BITE_MIRE]["name_key"]))
	_check("both drag-bite entries share one counter_key",
		str(_cfg.skills[BITE]["counter_key"]) == str(_cfg.skills[BITE_MIRE]["counter_key"]))
	_check("both drag-bite entries deal the same damage",
		is_equal_approx(_dmg(BITE), _dmg(BITE_MIRE)), "%.0f vs %.0f" % [_dmg(BITE), _dmg(BITE_MIRE)])
	_check("the slow entry is gated on slow",
		((_cfg.skills[BITE]["conditions"] as Dictionary).get("player_status", []) as Array).has("slow"),
		str(_cfg.skills[BITE].get("conditions", {})))
	_check("the mire entry is gated on mire",
		((_cfg.skills[BITE_MIRE]["conditions"] as Dictionary).get("player_on_zone", []) as Array).has("mire"),
		str(_cfg.skills[BITE_MIRE].get("conditions", {})))


func test_rat_gnaw() -> void:
	var w: Dictionary = _only(["rat_gnaw"], "bog")
	var status: StatusEffects = w["status"]
	var ev: Dictionary = _until_resolve(w, "rat_gnaw")
	_check("gnaw: damage from data (%.0f)" % _dmg("rat_gnaw"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("rat_gnaw")), str(ev))
	_check("gnaw: a hit leaves Độc running", status.get_poison_left(P) > 0.0, str(status.get_poison_left(P)))
	# Refresh, not stack: a second gnaw must not push the remaining time past the skill's own duration.
	var sec: float = float(((_cfg.skills["rat_gnaw"]["effects"] as Dictionary)["status"] as Dictionary)["sec"])
	var ev2: Dictionary = _until_resolve(w, "rat_gnaw")
	_check("gnaw: Độc refreshes, never stacks (<= %.1f s left)" % sec,
		ev2.is_empty() or status.get_poison_left(P) <= sec + 0.001, str(status.get_poison_left(P)))


func test_slime_trail_mires_two_cells_beside_the_hero() -> void:
	var w: Dictionary = _only(["slug_slime_trail"], "bog")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var hazards: TileHazards = w["hazards"]
	_check("trail: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("trail: two cells", red.size() == 2, str(red))
	_check("trail: never the cell the hero stands on", not red.has(state.player_cell),
		"%s vs hero %s" % [str(red), str(state.player_cell)])
	var hp: float = state.player_hp
	var ev: Dictionary = _until_resolve(w, "slug_slime_trail")
	_check("trail: it resolves without damaging the hero",
		not ev.is_empty() and is_equal_approx(float(ev["damage"]), 0.0) and is_equal_approx(hp, state.player_hp), str(ev))
	# The mire is read from TileHazards, not from the event log: _record never writes zone_cells.
	var mired: int = 0
	for c: Vector2i in red:
		if hazards.is_mire(P, c):
			mired += 1
	_check("trail: the struck cells are mire", mired > 0, "%d of %d" % [mired, red.size()])
	_check("trail: the hero's own cell is never mire", not hazards.is_mire(P, state.player_cell))


func test_tail_sweep() -> void:
	var w: Dictionary = _only(["lizard_tail_sweep"], "reed_maze")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_check("sweep: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("sweep: the bar covers the hero", red.has(state.player_cell), str(red))
	_check("sweep: 2-3 cells after clipping", red.size() >= 2 and red.size() <= 3, str(red))
	var ev: Dictionary = _until_resolve(w, "lizard_tail_sweep")
	_check("sweep: damage from data (%.0f)" % _dmg("lizard_tail_sweep"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("lizard_tail_sweep")), str(ev))
	_check("sweep: a hit leaves Chậm running", status.get_slow_left(P) > 0.0, str(status.get_slow_left(P)))


## The gate, both halves. A hero who is neither slowed nor mired must never be bitten; once either is true the
## matching entry must fire. Checking only the firing direction would pass against a skill with no gate at all.
func test_drag_bite_is_gated() -> void:
	# 1. Clean hero: NEITHER entry may cast, for a long run.
	var clean: Dictionary = _only([BITE, BITE_MIRE], "reed_maze")
	_run(clean, 24.0)
	_check("gate: no bite at a hero who is neither slowed nor mired",
		_casts(clean, BITE) == 0 and _casts(clean, BITE_MIRE) == 0,
		"slow-entry %d, mire-entry %d" % [_casts(clean, BITE), _casts(clean, BITE_MIRE)])

	# 2. Slowed hero: the slow entry fires.
	var slowed: Dictionary = _only([BITE], "reed_maze")
	(slowed["status"] as StatusEffects).slow(P, 30.0, 1.6)
	var ev: Dictionary = _until_resolve(slowed, BITE, 12.0)
	_check("gate: the slow entry bites a slowed hero", not ev.is_empty(), str(ev))
	_check("gate: the bite costs its data damage (%.0f)" % _dmg(BITE),
		not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg(BITE)), str(ev))

	# 3. Mired hero: the mire entry fires.
	var mired: Dictionary = _only([BITE_MIRE], "reed_maze")
	var st: CombatState = mired["state"]
	(mired["hazards"] as TileHazards).add_mire(P, [st.player_cell] as Array[Vector2i], 30.0)
	var ev2: Dictionary = _until_resolve(mired, BITE_MIRE, 12.0)
	_check("gate: the mire entry bites a hero standing in mire", not ev2.is_empty(), str(ev2))


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in ["rat_gnaw", "slug_slime_trail", "lizard_tail_sweep", "lizard_drag_bite"]:
		for suffix: String in ["name", "counter"]:
			var key: String = "enemy_skill.%s.%s" % [id, suffix]
			_check("strings.csv has %s" % key, raw.contains(key + ","))

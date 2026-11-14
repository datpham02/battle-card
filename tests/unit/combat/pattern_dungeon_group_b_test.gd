extends SceneTree
## Monster Skill Phase 2 group D-B (MONSTER-SKILL-PHASE2-PLAN.md §20): slime, ghost and reacter, on the shipped
## u_shape / rect / cross grids. Hệ số vùng: ×2,5.
## - slime_engulf: a 2x2 covering the hero, data damage + Chậm;
## - slime_ooze: ONE cell beside the hero, never the hero's own, left as mire, no damage of its own;
## - ghost_wail: a VERTICAL two-cell column, data damage + 1 Rạn;
## - ghost_phase: the Ghost moves row and becomes untouchable for a moment;
## - reacter_lash: the GATE — it must not fire until the hero has stepped three times, and must fire once they have.
## Damage is read from the shipped data, so a tuning pass moves the numbers without touching this file.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_dungeon_group_b_test.gd
##
## THE AXIS AGAIN (§16.1, fourth occurrence).
## §4.5 prints `ghost_wail` as `column_of_player` [[0,0],[0,1]]. On that anchor the planner maps
## Vector2i(player.x - off.y, start + off.x) — off.x walks DOWN, off.y walks ACROSS — so the doc's pair lies
## HORIZONTAL. The data deviates on purpose and the leg below demands an UNCLIPPED 2-cell cast before judging,
## because a cast clipped to one cell makes "every cell shares the hero's column" trivially true. That is exactly
## how the same bug passed its first test and shipped in `scarab_spear`.
##
## WHAT THIS SUITE DOES NOT PROVE:
## `ghost_phase` carries `evade {sec 0.8}`. The leg below asserts the cast resolves and that the data carries the
## evade; it does NOT assert the Ghost is actually untargetable for those 0.8 s, because nothing in this fixture
## swings at it. `region_traits_test` and the combat view own that.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const LASH: String = "reacter_lash"
const WAIL: String = "ghost_wail"

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
	test_engulf()
	test_ooze_mires_one_cell_beside_the_hero()
	test_wail_runs_down_the_column()
	test_ghost_phase()
	test_lash_is_gated_on_three_steps()
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


func _casts(w: Dictionary, skill_id: String) -> int:
	var n: int = 0
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id:
			n += 1
	return n


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["slime", "ghost", "reacter"]:
		_check("%s is in the shipped enemies" % id, _cfg.enemies.has(id))
	var wail: Array = _cfg.skills[WAIL]["pattern"]["offsets"] as Array
	_check("wail walks DOWN the column, not across",
		wail.size() == 2 and (wail[0] as Vector2i) == Vector2i(0, 0) and (wail[1] as Vector2i) == Vector2i(1, 0), str(wail))
	# §13.1: `count` is marker-only, so the ooze is written as a one-cell offsets entry.
	var ooze: Dictionary = _cfg.skills["slime_ooze"]["pattern"] as Dictionary
	_check("ooze is ONE cell beside the hero, not count: 1",
		(ooze["offsets"] as Array).size() == 1 and bool(ooze.get("exclude_player", false)), str(ooze))
	_check("ooze lays mire and deals no damage",
		(((_cfg.skills["slime_ooze"]["effects"] as Dictionary).get("zone", {}) as Dictionary).get("id", "")) == "mire"
		and is_equal_approx(_dmg("slime_ooze"), 0.0))
	# §16.2: every multi-cell pattern on an irregular arena must clip.
	for sid: String in ["slime_engulf", LASH, WAIL]:
		var pat: Dictionary = _cfg.skills[sid]["pattern"] as Dictionary
		_check("%s clips" % sid, bool(pat.get("clip", false)) and int(pat.get("min_cells", 0)) >= 2, str(pat))
	_check("lash is gated on three steps",
		int((_cfg.skills[LASH]["conditions"] as Dictionary).get("player_steps_since", 0)) == 3,
		str(_cfg.skills[LASH].get("conditions", {})))
	var ph: Dictionary = _cfg.skills["ghost_phase"]["effects"] as Dictionary
	_check("ghost_phase moves row and fades",
		str((ph.get("move", {}) as Dictionary).get("to", "")) == "adjacent_row"
		and float((ph.get("evade", {}) as Dictionary).get("sec", 0.0)) > 0.0, str(ph))


func test_engulf() -> void:
	var w: Dictionary = _only(["slime_engulf"], "u_shape")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_check("engulf: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("engulf: the square covers the hero", red.has(state.player_cell), str(red))
	_check("engulf: 3-4 cells after clipping", red.size() >= 3 and red.size() <= 4, str(red))
	var ev: Dictionary = _until_resolve(w, "slime_engulf")
	_check("engulf: damage from data (%.0f)" % _dmg("slime_engulf"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("slime_engulf")), str(ev))
	_check("engulf: a hit leaves Chậm running", status.get_slow_left(P) > 0.0)


func test_ooze_mires_one_cell_beside_the_hero() -> void:
	var w: Dictionary = _only(["slime_ooze"], "u_shape")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var hazards: TileHazards = w["hazards"]
	_check("ooze: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("ooze: exactly one cell", red.size() == 1, str(red))
	_check("ooze: never the cell the hero stands on", not red.has(state.player_cell),
		"%s vs hero %s" % [str(red), str(state.player_cell)])
	var hp: float = state.player_hp
	var ev: Dictionary = _until_resolve(w, "slime_ooze")
	_check("ooze: it resolves without damaging the hero",
		not ev.is_empty() and is_equal_approx(hp, state.player_hp), str(ev))
	var mired: bool = false
	for c: Vector2i in red:
		if hazards.is_mire(P, c):
			mired = true
	_check("ooze: the struck cell is mire", mired, str(red))
	_check("ooze: the hero's own cell is never mire", not hazards.is_mire(P, state.player_cell))


func test_wail_runs_down_the_column() -> void:
	var judged: bool = false
	for seed_value: int in range(1, 9):
		var w: Dictionary = _only([WAIL], "rect", seed_value)
		if not _until_stage(w, PatternController.Stage.WARNING):
			continue
		var red: Array[Vector2i] = (w["ctrl"] as PatternController).telegraph_cells()
		if red.size() != 2:
			continue  # clipped: cannot judge the axis from one cell
		var state: CombatState = w["state"]
		judged = true
		_check("wail: both cells share the hero's column (seed %d)" % seed_value,
			red[0].x == red[1].x and red[0].x == state.player_cell.x, str(red))
		_check("wail: the cells differ in row — a column, not a bar (seed %d)" % seed_value,
			red[0].y != red[1].y, str(red))
		var ev: Dictionary = _until_resolve(w, WAIL)
		_check("wail: damage from data (%.0f)" % _dmg(WAIL),
			not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg(WAIL)), str(ev))
		_check("wail: a hit leaves 1 Rạn", (w["status"] as StatusEffects).fragile_stacks(P) >= 1)
		break
	_check("wail: an unclipped 2-cell cast was found to judge the axis on", judged,
		"no 2-cell cast over 8 seeds")


func test_ghost_phase() -> void:
	var w: Dictionary = _only(["ghost_phase"], "rect")
	var state: CombatState = w["state"]
	var before: Vector2i = state.cell_of(E)
	var ev: Dictionary = _until_resolve(w, "ghost_phase", 14.0)
	_check("phase: it resolves", not ev.is_empty(), str(ev))
	_check("phase: the Ghost changed row", state.cell_of(E) != before,
		"%s -> %s" % [str(before), str(state.cell_of(E))])


## The gate, both directions. Only "does not fire" would also pass against a skill broken so badly it can never be
## chosen; only "fires" would pass against a skill with no gate at all.
func test_lash_is_gated_on_three_steps() -> void:
	# 1. A hero who never steps is never lashed.
	var still: Dictionary = _only([LASH], "cross")
	_run(still, 24.0)
	_check("gate: a hero who never steps is never lashed", _casts(still, LASH) == 0, str(_casts(still, LASH)))

	# 2. After three steps it fires. `on_player_stepped` is what CombatView calls on a completed step.
	var moving: Dictionary = _only([LASH], "cross")
	var ctrl: PatternController = moving["ctrl"]
	for i: int in 3:
		ctrl.on_player_stepped()
	var ev: Dictionary = _until_resolve(moving, LASH, 12.0)
	_check("gate: after the third step it lashes", not ev.is_empty(), str(ev))
	_check("gate: the lash costs its data damage (%.0f)" % _dmg(LASH),
		not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg(LASH)), str(ev))


func test_guard_damage_budget() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/characters.json")) as Dictionary
	var chars: Variant = raw.get("characters", raw)
	var list: Array = (chars.values() if typeof(chars) == TYPE_DICTIONARY else chars) as Array
	var low: float = INF
	for c: Variant in list:
		var cd: Dictionary = c as Dictionary
		var attrs: Dictionary = cd.get("attributes", {}) as Dictionary
		low = minf(low, float(attrs.get("max_hp", cd.get("max_hp", INF))))
	var worst: float = 0.0
	for id: String in ["slime_engulf", WAIL, LASH]:
		worst = maxf(worst, _dmg(id) * 1.5)
	_check("guard: the worst D-B hit (×1.5 Rạn) < half the lowest hero HP",
		low < INF and worst > 0.0 and worst < 0.5 * low, "worst %.0f vs half of %.0f" % [worst, low])


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in ["slime_engulf", "slime_ooze", WAIL, "ghost_phase", LASH]:
		for suffix: String in ["name", "counter"]:
			var key: String = "enemy_skill.%s.%s" % [id, suffix]
			_check("strings.csv has %s" % key, raw.contains(key + ","))

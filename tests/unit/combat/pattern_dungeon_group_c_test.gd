extends SceneTree
## Monster Skill Phase 2 group D-C (MONSTER-SKILL-PHASE2-PLAN.md §21): cultist, rat_king_guard and jailer, on the
## shipped staircase / ring / u_shape grids. Hệ số vùng: ×2,5.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_dungeon_group_c_test.gd
##
## THE CURSE RING LEG EXISTS BECAUSE THE DESIGN DOC WOULD HAVE SHIPPED A SKILL THAT NEVER CASTS.
## §4.5 writes `cultist_curse_ring` as `near_player` with offsets [[0,0],[1,0],[-1,0],[0,1],[0,-1]] and
## `exclude_player`. In `_add_plan`, **`exclude_player` rejects the WHOLE plan** when it contains the hero's cell —
## it does not drop that one cell. Anchored at a cell adjacent to the hero, a plus of five ALWAYS contains the
## hero's cell, so every plan is rejected and the skill never casts, with `_cfg.problems` empty. That is the exact
## failure `witch_rot_cloud` had in the Swamp: valid data, invisible to the config checker, silent in play.
## The shipped data is `on_player` with the FOUR NEIGHBOURS and no [0,0] — what the doc's prose actually asks for.
## So the legs below check BOTH that it casts at all AND that it never covers the hero's cell. Either alone is
## satisfied by a broken version: a skill that never fires passes "never hits the hero".

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const RING: String = "cultist_curse_ring"
const HOOK: String = "jailer_chain_hook"
const LOCK: String = "jailer_lockdown"

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
	test_seal_caster_is_gone_from_the_jailer()
	test_curse_ring_casts_and_spares_the_hero_cell()
	test_shove_pushes_away()
	test_chain_hook_runs_down_the_column_and_pulls()
	test_lockdown_drops_two_cells_beside_the_hero()
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


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["cultist", "rat_king_guard", "jailer"]:
		_check("%s is in the shipped enemies" % id, _cfg.enemies.has(id))
	var ring: Dictionary = _cfg.skills[RING]["pattern"] as Dictionary
	var offs: Array = ring["offsets"] as Array
	_check("curse_ring does NOT include the hero's own cell",
		not offs.has(Vector2i(0, 0)), str(offs))
	_check("curse_ring is four cells anchored on the hero",
		offs.size() == 4 and str(ring["anchor"]) == "on_player", str(ring))
	# §16.1: off.x walks DOWN the column.
	var hook: Array = _cfg.skills[HOOK]["pattern"]["offsets"] as Array
	_check("chain_hook walks DOWN the column, not across",
		hook.size() == 2 and (hook[0] as Vector2i) == Vector2i(0, 0) and (hook[1] as Vector2i) == Vector2i(1, 0), str(hook))
	_check("chain_hook roots and pulls",
		(((_cfg.skills[HOOK]["effects"] as Dictionary).get("status", {}) as Dictionary).get("id", "")) == "root"
		and int(((_cfg.skills[HOOK]["effects"] as Dictionary).get("pull", {}) as Dictionary).get("cells", 0)) == 1)
	# §13.1: `count` is marker-only.
	var lock: Dictionary = _cfg.skills[LOCK]["pattern"] as Dictionary
	_check("lockdown is TWO cells beside the hero, not count: 2",
		(lock["offsets"] as Array).size() == 2 and bool(lock.get("exclude_player", false)), str(lock))
	_check("lockdown drops the cells it marks",
		(((_cfg.skills[LOCK]["effects"] as Dictionary).get("zone", {}) as Dictionary).get("id", "")) == "drop")
	_check("shove pushes one cell",
		int(((_cfg.skills["guard_shove"]["effects"] as Dictionary).get("push", {}) as Dictionary).get("cells", 0)) == 1)
	var rite: Dictionary = _cfg.skills["cultist_dark_rite"] as Dictionary
	_check("dark_rite waits for an ally to fall, and happens once",
		float((rite["conditions"] as Dictionary).get("ally_died_within_sec", 0.0)) > 0.0
		and bool((rite["conditions"] as Dictionary).get("once", false)), str(rite.get("conditions", {})))
	_check("dark_rite guards the side and hastens it",
		float(((rite["effects"] as Dictionary).get("guard", {}) as Dictionary).get("amount", 0.0)) > 0.0
		and float(((rite["effects"] as Dictionary).get("haste", {}) as Dictionary).get("cooldown_mult", 1.0)) < 1.0,
		str(rite["effects"]))


## §4.5 turns `seal_caster` into `jailer_lockdown`. The trait must be GONE from the match; the other two stay.
func test_seal_caster_is_gone_from_the_jailer() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chapters.json")) as Dictionary
	var traits: Array = []
	var found: bool = false
	for ch: Dictionary in (data["chapters"] as Array):
		var m: Dictionary = ((ch.get("matches", {}) as Dictionary).get("jailer", {})) as Dictionary
		if m.is_empty():
			continue
		found = true
		for t: Variant in (m.get("traits", []) as Array):
			traits.append(str((t as Dictionary)["id"]) if typeof(t) == TYPE_DICTIONARY else str(t))
	_check("the jailer match was found in chapters.json", found)
	_check("seal_caster is gone (it became jailer_lockdown)", not traits.has("seal_caster"), str(traits))
	_check("rotten_thrower and row_burner stay",
		traits.has("rotten_thrower") and traits.has("row_burner"), str(traits))


## Both halves. A skill that never casts would satisfy "never covers the hero's cell" on its own.
func test_curse_ring_casts_and_spares_the_hero_cell() -> void:
	var w: Dictionary = _only([RING], "staircase")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_check("ring: it warns at all (the doc's version never would)", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("ring: 2-4 cells after clipping", red.size() >= 2 and red.size() <= 4, str(red))
	_check("ring: never the cell the hero stands on", not red.has(state.player_cell),
		"%s vs hero %s" % [str(red), str(state.player_cell)])
	for c: Vector2i in red:
		var d: int = absi(c.x - state.player_cell.x) + absi(c.y - state.player_cell.y)
		_check("ring: every cell is adjacent to the hero (%s)" % str(c), d == 1, "distance %d" % d)
	var ev: Dictionary = _until_resolve(w, RING, 14.0)
	_check("ring: it resolves", not ev.is_empty(), str(ev))
	if not ev.is_empty() and bool(ev["hit"]):
		_check("ring: a hit costs its data damage (%.0f)" % _dmg(RING),
			is_equal_approx(float(ev["damage"]), _dmg(RING)), str(ev))
		_check("ring: a hit leaves Chậm running", status.get_slow_left(P) > 0.0)


func test_shove_pushes_away() -> void:
	var w: Dictionary = _only(["guard_shove"], "ring")
	var state: CombatState = w["state"]
	var before: Vector2i = state.player_cell
	var origin: Vector2i = state.cast_origin(E)
	var d_before: int = absi(before.x - origin.x) + absi(before.y - origin.y)
	var ev: Dictionary = _until_resolve(w, "guard_shove")
	# A push that is BLOCKED adds the R3 slam on top of the skill's own damage
	# (pattern_controller.gd _apply_forced_move). So the recorded damage is the data value, or the data value
	# plus the reaction. Asserting equality alone fails on correct engine behaviour — it did, at 33 vs 25.
	var base: float = _dmg("guard_shove")
	var rec: float = float(ev.get("damage", 0.0)) if not ev.is_empty() else 0.0
	_check("shove: damage is the data value, plus the R3 slam only if the push was blocked",
		not ev.is_empty() and bool(ev["hit"]) and rec >= base and rec <= base + 20.0,
		"recorded %.0f vs data %.0f, moved=%s" % [rec, base, str(ev.get("moved", "?"))])
	_check("shove: the extra damage only ever appears when the hero could not be moved",
		ev.is_empty() or is_equal_approx(rec, base) or int(ev.get("moved", 0)) < 1,
		"recorded %.0f > data %.0f but moved=%s" % [rec, base, str(ev.get("moved", "?"))])
	# Direction is not a fixed axis — assert the rule, not the author's guess about board orientation.
	var after: Vector2i = state.player_cell
	var d_after: int = absi(after.x - origin.x) + absi(after.y - origin.y)
	_check("shove: a hit never drags the hero TOWARD the caster", d_after >= d_before,
		"%s -> %s, caster %s (%d -> %d)" % [str(before), str(after), str(origin), d_before, d_after])


func test_chain_hook_runs_down_the_column_and_pulls() -> void:
	var judged: bool = false
	for seed_value: int in range(1, 9):
		var w: Dictionary = _only([HOOK], "u_shape", seed_value)
		if not _until_stage(w, PatternController.Stage.WARNING):
			continue
		var red: Array[Vector2i] = (w["ctrl"] as PatternController).telegraph_cells()
		if red.size() != 2:
			continue
		var state: CombatState = w["state"]
		judged = true
		_check("hook: both cells share the hero's column (seed %d)" % seed_value,
			red[0].x == red[1].x and red[0].x == state.player_cell.x, str(red))
		_check("hook: the cells differ in row (seed %d)" % seed_value, red[0].y != red[1].y, str(red))
		var before: Vector2i = state.player_cell
		var origin: Vector2i = state.cast_origin(E)
		var d_before: int = absi(before.x - origin.x) + absi(before.y - origin.y)
		var ev: Dictionary = _until_resolve(w, HOOK)
		_check("hook: damage from data (%.0f)" % _dmg(HOOK),
			not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg(HOOK)), str(ev))
		var after: Vector2i = state.player_cell
		var d_after: int = absi(after.x - origin.x) + absi(after.y - origin.y)
		_check("hook: a hit never pushes the hero AWAY from the caster", d_after <= d_before,
			"%s -> %s (%d -> %d)" % [str(before), str(after), d_before, d_after])
		break
	_check("hook: an unclipped 2-cell cast was found to judge the axis on", judged,
		"no 2-cell cast over 8 seeds")


func test_lockdown_drops_two_cells_beside_the_hero() -> void:
	var w: Dictionary = _only([LOCK], "u_shape")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_check("lockdown: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("lockdown: two cells", red.size() == 2, str(red))
	_check("lockdown: never the cell the hero stands on", not red.has(state.player_cell),
		"%s vs hero %s" % [str(red), str(state.player_cell)])
	var hp: float = state.player_hp
	var ev: Dictionary = _until_resolve(w, LOCK)
	_check("lockdown: it resolves without damaging the hero",
		not ev.is_empty() and is_equal_approx(hp, state.player_hp), str(ev))


func test_guard_damage_budget() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/characters.json")) as Dictionary
	var chars: Variant = raw.get("characters", raw)
	var list: Array = (chars.values() if typeof(chars) == TYPE_DICTIONARY else chars) as Array
	var low: float = INF
	for c: Variant in list:
		var cd: Dictionary = c as Dictionary
		low = minf(low, float((cd.get("attributes", {}) as Dictionary).get("max_hp", cd.get("max_hp", INF))))
	var worst: float = 0.0
	for id: String in [RING, "guard_shove", HOOK]:
		worst = maxf(worst, _dmg(id) * 1.5)
	_check("guard: the worst D-C hit (×1.5 Rạn) < half the lowest hero HP",
		low < INF and worst > 0.0 and worst < 0.5 * low, "worst %.0f vs half of %.0f" % [worst, low])


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in [RING, "cultist_dark_rite", "guard_shove", HOOK, LOCK]:
		for suffix: String in ["name", "counter"]:
			var key: String = "enemy_skill.%s.%s" % [id, suffix]
			_check("strings.csv has %s" % key, raw.contains(key + ","))

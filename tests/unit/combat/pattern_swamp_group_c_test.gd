extends SceneTree
## Monster Skill Phase 2 group W-C (MONSTER-SKILL-PHASE2-PLAN.md §17): spore_cap and leap_frog, the two Swamp
## elites, on the shipped bog / reed_maze grids.
## - spore_puff: a cross covering the hero, data damage + Độc;
## - spore_regrow: GATED on hp_below 0.6 — it must not fire at a healthy enemy, and must heal when it does;
## - frog_leap_slam: a 2x2 covering the hero, then the SAME cells again after a delay;
## - frog_croak: a self-cast that shortens the enemy's own cooldowns for a while.
## Hit damage is read from the shipped data, so a tuning pass moves the numbers without touching this file.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_swamp_group_c_test.gd
##
## FIRST SHIPPED USE OF `heal` — what a green here does and does not mean.
## `spore_regrow` is the first data in the game to carry the `heal` effect, so `PatternController` :1090-1098 and
## `CombatState.heal_key` have never run from shipped data before. There is no earlier green to compare against:
## a green below means the heal path works for THIS shape (ratio over sec), not that `heal` is generally sound.
## `amount` (the flat variant) is still unexercised by any shipped skill — the config accepts it, nothing uses it,
## and nothing here covers it. Whoever ships the first `amount` heal should not read this suite as cover.
##
## WHY THE CLIP LEGS MATTER (§16.2).
## Both multi-cell patterns here carry `clip: true` + `min_cells`, deviating from the design doc on purpose. Without
## `clip`, `_add_plan` drops the WHOLE plan when a single cell falls off the player's half, and on an irregular
## arena the skill then never casts at all — while `_cfg.problems` stays empty, so it looks exactly like a skill
## that simply has not come up yet. `witch_rot_cloud` failed this way in W-B before it was caught.

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const REGROW: String = "spore_regrow"
const SLAM: String = "frog_leap_slam"

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
	test_spore_puff()
	test_regrow_is_gated_and_heals()
	test_leap_slam_hits_the_same_cells_twice()
	test_croak_hastes()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _dmg(id: String, followup: bool = false) -> float:
	var s: Dictionary = _cfg.skills[id]
	var fx: Dictionary = ((s["followup"] as Dictionary)["effects"] if followup else s["effects"]) as Dictionary
	return float(fx.get("damage", 0.0))


func _only(ids: Array, shape: String, seed_value: int = 1, enemy_hp: float = 1000.0) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = ((data["skills"] as Dictionary)[id] as Dictionary).duplicate(true)
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills,
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ids}}})
	var w: Dictionary = Fx.world(_grid(shape, seed_value), cfg, "g", seed_value, enemy_hp)
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


## [param want_followup]: -1 any, 0 first strike only, 1 followup strike only. Matching on skill id alone cannot
## tell a followup apart from the NEXT CAST of the same skill (W-B §16.3 cost two rounds to this).
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
	for id: String in ["spore_cap", "leap_frog"]:
		_check("%s is in the shipped enemies" % id, _cfg.enemies.has(id))
	# §16.2: every multi-cell pattern on an irregular arena must clip, or it silently never casts.
	for sid: String in ["spore_puff", SLAM]:
		var pat: Dictionary = _cfg.skills[sid]["pattern"] as Dictionary
		_check("%s clips (so one off-board cell cannot drop the whole cast)" % sid,
			bool(pat.get("clip", false)) and int(pat.get("min_cells", 0)) >= 3, str(pat))
	_check("spore_puff carries Độc",
		(((_cfg.skills["spore_puff"]["effects"] as Dictionary).get("status", {}) as Dictionary).get("id", "")) == "poison")
	var heal: Dictionary = (_cfg.skills[REGROW]["effects"] as Dictionary).get("heal", {}) as Dictionary
	_check("spore_regrow heals a ratio over seconds",
		float(heal.get("ratio", 0.0)) > 0.0 and float(heal.get("sec", 0.0)) > 0.0, str(heal))
	_check("spore_regrow is gated under 0.6 HP",
		is_equal_approx(float((_cfg.skills[REGROW]["conditions"] as Dictionary).get("hp_below", 0.0)), 0.6),
		str(_cfg.skills[REGROW].get("conditions", {})))
	_check("spore_regrow can be interrupted", bool(_cfg.skills[REGROW]["interruptible"]))
	var haste: Dictionary = (_cfg.skills["frog_croak"]["effects"] as Dictionary).get("haste", {}) as Dictionary
	_check("frog_croak shortens its own cooldowns for a while",
		float(haste.get("cooldown_mult", 1.0)) < 1.0 and float(haste.get("sec", 0.0)) > 0.0, str(haste))
	_check("leap_slam's followup lands on the SAME cells",
		str((_cfg.skills[SLAM]["followup"] as Dictionary)["relative_to"]) == "same_cells")


func test_spore_puff() -> void:
	var w: Dictionary = _only(["spore_puff"], "bog")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_check("puff: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("puff: the cross covers the hero", red.has(state.player_cell), str(red))
	_check("puff: 3-5 cells after clipping", red.size() >= 3 and red.size() <= 5, str(red))
	var ev: Dictionary = _until_resolve(w, "spore_puff")
	_check("puff: damage from data (%.0f)" % _dmg("spore_puff"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("spore_puff")), str(ev))
	_check("puff: a hit leaves Độc running", status.get_poison_left(P) > 0.0, str(status.get_poison_left(P)))


## The gate, both directions. Only the "does not fire" half would also pass against a skill broken so badly it can
## never be chosen; only the "fires" half would pass against a skill with no gate at all.
func test_regrow_is_gated_and_heals() -> void:
	# 1. Healthy enemy: never.
	var healthy: Dictionary = _only([REGROW], "bog", 1, 1000.0)
	_run(healthy, 24.0)
	_check("regrow: a healthy Nấm never regrows", _casts(healthy, REGROW) == 0, str(_casts(healthy, REGROW)))

	# 2. Hurt enemy: it fires, and HP actually goes up.
	var hurt: Dictionary = _only([REGROW], "bog", 1, 1000.0)
	var state: CombatState = hurt["state"]
	state.enemy_hp = state.enemy_max_hp * 0.4  # under the 0.6 gate
	var before: float = state.enemy_hp
	var ev: Dictionary = _until_resolve(hurt, REGROW, 14.0)
	_check("regrow: a hurt Nấm regrows", not ev.is_empty(), str(ev))
	# The heal runs over `sec`, so it is not all present the instant it resolves: tick past the duration.
	var sec: float = float(((_cfg.skills[REGROW]["effects"] as Dictionary)["heal"] as Dictionary)["sec"])
	_run(hurt, sec + 0.5)
	var ratio: float = float(((_cfg.skills[REGROW]["effects"] as Dictionary)["heal"] as Dictionary)["ratio"])
	var want: float = ratio * state.enemy_max_hp
	_check("regrow: HP rose by about the data ratio (%.0f%%)" % (ratio * 100.0),
		state.enemy_hp > before and absf((state.enemy_hp - before) - want) <= maxf(1.0, want * 0.25),
		"%.1f -> %.1f (want +%.1f)" % [before, state.enemy_hp, want])


## NOTE, measured 2026-11-14, NOT a bug: `reed_maze`'s player half is a comb — rows 0/2/4 are full, rows 1 and 3
## hold ONE cell each. A 2x2 needs two adjacent rows, so with `min_cells: 3` the slam can be placed from 10 of the
## 17 hero cells and NOT from the other 7 — the fixture's default hero cell (2,2) is one of those 7. In a real
## match the hero moves and the frog gets its chances; that positional gap is counterplay, not breakage. The test
## has to move the hero somewhere the pattern fits, or it sits forever in a dead spot and reports five failures
## that look exactly like "the skill never casts".
func test_leap_slam_hits_the_same_cells_twice() -> void:
	var w: Dictionary = _only([SLAM], "reed_maze")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var placed: bool = false
	for cell: Vector2i in (state.grid as BoardGrid).player_cells():
		if not state.set_key_cell(P, cell):
			continue
		if PatternPlanner.plans(_cfg.skills[SLAM], ctrl._plan_ctx()).size() > 0:
			placed = true
			break
	_check("slam: a hero cell exists where the 2x2 fits", placed, "none of the player half worked")
	_check("slam: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var first: Array[Vector2i] = ctrl.telegraph_cells()
	_check("slam: the square covers the hero", first.has(state.player_cell), str(first))
	_check("slam: 3-4 cells after clipping", first.size() >= 3 and first.size() <= 4, str(first))
	var ev: Dictionary = _until_resolve(w, SLAM, 10.0, 0)
	_check("slam: damage from data (%.0f)" % _dmg(SLAM),
		not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg(SLAM)), str(ev))
	var ev2: Dictionary = _until_resolve(w, SLAM, 8.0, 1)
	_check("slam: a second strike follows", not ev2.is_empty(), str(ev2))
	if not ev2.is_empty():
		var again: Array = ev2.get("cells", []) as Array
		var same: bool = true
		for c: Variant in again:
			if not first.has(c as Vector2i):
				same = false
		_check("slam: the second strike lands on the first strike's cells", same,
			"%s vs %s" % [str(again), str(first)])
		_check("slam: the second strike costs its own data damage (%.0f) or misses" % _dmg(SLAM, true),
			is_equal_approx(float(ev2["damage"]), _dmg(SLAM, true)) or not bool(ev2["hit"]),
			"recorded=%s hit=%s" % [str(ev2["damage"]), str(ev2["hit"])])


func test_croak_hastes() -> void:
	var w: Dictionary = _only(["frog_croak"], "reed_maze")
	var ev: Dictionary = _until_resolve(w, "frog_croak", 14.0)
	_check("croak: it resolves", not ev.is_empty(), str(ev))
	# NOT from the event log: `_record` writes only t/skill/event/cells/hit/damage/phase/followup_strike. There is
	# no `status` key there at all, so a leg reading ev["status"] can never pass whatever the skill does — the same
	# mistake as reading `zone_cells` off the log in the Sands suites. The controller exposes haste_left() instead.
	_check("croak: the enemy is actually hasted afterwards",
		(w["ctrl"] as PatternController).haste_left() > 0.0,
		"haste_left=%.2f" % (w["ctrl"] as PatternController).haste_left())


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	for id: String in ["spore_puff", REGROW, SLAM, "frog_croak"]:
		for suffix: String in ["name", "counter"]:
			var key: String = "enemy_skill.%s.%s" % [id, suffix]
			_check("strings.csv has %s" % key, raw.contains(key + ","))

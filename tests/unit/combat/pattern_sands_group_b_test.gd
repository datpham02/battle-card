extends SceneTree
## Monster Skill Phase 2 group S-B (MONSTER-SKILL-PHASE2-PLAN.md §5): the shipped enemy_skills.json entries of
## mirage_sprite / scarab_guard / sun_archer on the shipped dunes / oasis grids.
## - sprite_mirage places ONE mirage marker on the enemy half in the hero's row; a 1-cell player cast breaks it;
## - sprite_shimmer_lash is gated on that marker (conditions.requires_anchor 1): with no mirage it is never cast, and
##   when it lands it hits for its data damage and leaves 1 Rạn (fragile);
## - scarab_shield_wall puts Guard +4 on the ENEMY side for 4 s and its windup is interruptible with a 0.8 s stun;
##   weight 0.3 alone, x4 with an ally alive;
## - scarab_spear is a 2-cell line down the hero's column (offsets [[0,0],[0,1]] on column_of_player, which runs along
##   x: see the convention note before §4.1 of MONSTER-SKILL-DESIGN.md);
## - archer_blinding_arc is a 5-cell cross covering the hero, its data damage plus Slow (step x1.3 for 1.5 s).
## Hit damage is read from the shipped data, so a tuning pass moves the numbers without touching this file.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_sands_group_b_test.gd

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
	test_mirage_marker_lands_and_breaks()
	test_lash_needs_the_mirage()
	test_lash_damage_and_fragile()
	test_shield_wall_guards_and_can_be_interrupted()
	test_shield_wall_weight_with_an_ally()
	test_spear_is_a_line_down_the_column()
	test_blinding_arc_cross_and_slow()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _world(enemy_id: String, shape: String, seed_value: int = 1) -> Dictionary:
	var w: Dictionary = Fx.world(_grid(shape, seed_value), _cfg, enemy_id, seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)  # combat.json numbers
	return w


func _run(w: Dictionary, seconds: float) -> void:
	Fx.run(w["ctrl"], w["state"], w["status"], w["mover"], seconds, "still", STEP)


func _dmg(id: String) -> float:
	return float((_cfg.skills[id]["effects"] as Dictionary).get("damage", 0.0))


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


## A config holding only [param ids] on one enemy, so a skill can be tested without its sibling competing for casts.
func _only(ids: Array, shape: String, seed_value: int = 1) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = (data["skills"] as Dictionary)[id]
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills,
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ids}}})
	var w: Dictionary = Fx.world(_grid(shape, seed_value), cfg, "g", seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	return w


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["mirage_sprite", "scarab_guard", "sun_archer"]:
		_check("enemy %s loaded" % id, not _cfg.get_enemy(id).is_empty())
	_check("sprite: mirage + lash", (_cfg.get_enemy("mirage_sprite")["phases"][0]["skills"] as Array) == ["sprite_mirage", "sprite_shimmer_lash"])
	_check("scarab: wall + spear", (_cfg.get_enemy("scarab_guard")["phases"][0]["skills"] as Array) == ["scarab_shield_wall", "scarab_spear"])
	_check("archer: blinding arc only", (_cfg.get_enemy("sun_archer")["phases"][0]["skills"] as Array) == ["archer_blinding_arc"])
	for id: String in ["sprite_mirage", "sprite_shimmer_lash", "scarab_shield_wall", "scarab_spear", "archer_blinding_arc"]:
		var s: Dictionary = _cfg.skills[id]
		_check("%s has name / counter keys" % id, str(s["name_key"]) == "enemy_skill.%s.name" % id
			and str(s["counter_key"]) == "enemy_skill.%s.counter" % id)
		_check("%s names its delivery" % id, (s["delivery"] as Dictionary).has("type"))
	_check("mirage: one marker in the hero's row, life 8, breaks on 1 cell",
		int((_cfg.skills["sprite_mirage"]["pattern"] as Dictionary)["count"]) == 1
		and str((_cfg.skills["sprite_mirage"]["pattern"] as Dictionary).get("row", "")) == "player"
		and is_equal_approx(float(((_cfg.skills["sprite_mirage"]["effects"] as Dictionary)["marker"] as Dictionary)["life_sec"]), 8.0)
		and int(((_cfg.skills["sprite_mirage"]["effects"] as Dictionary)["marker"] as Dictionary)["break_min_cells"]) == 1)
	_check("lash: gated on an anchor",
		int((_cfg.skills["sprite_shimmer_lash"]["conditions"] as Dictionary).get("requires_anchor", 0)) == 1)
	_check("shield wall: Guard 4 for 4 s, interrupt stuns 0.8 s",
		is_equal_approx(float(((_cfg.skills["scarab_shield_wall"]["effects"] as Dictionary)["guard"] as Dictionary)["amount"]), 4.0)
		and is_equal_approx(float(_cfg.skills["scarab_shield_wall"].get("interrupt_stun_sec", 0.0)), 0.8))
	_check("arc: slow 1.5 s at step x1.3",
		is_equal_approx(float(((_cfg.skills["archer_blinding_arc"]["effects"] as Dictionary)["status"] as Dictionary)["sec"]), 1.5)
		and str(((_cfg.skills["archer_blinding_arc"]["effects"] as Dictionary)["status"] as Dictionary)["id"]) == "slow")
	# Tuning guard, as in group A: no S-B hit, even x1.5 on a Rạn stack, reaches half the lowest hero max HP.
	var chars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/characters.json"))
	var low: float = INF
	for c: Dictionary in (chars["characters"] as Array):
		var attrs: Dictionary = c.get("attributes", {}) as Dictionary
		low = minf(low, float(attrs.get("max_hp", c.get("max_hp", INF))))
	var worst: float = 0.0
	for sid: String in ["sprite_shimmer_lash", "scarab_spear", "archer_blinding_arc"]:
		worst = maxf(worst, 1.5 * _dmg(sid))
	_check("guard: the worst S-B hit (x1.5 Rạn) < half the lowest hero HP", worst > 0.0 and worst < 0.5 * low,
		"%.1f vs %.1f" % [worst, 0.5 * low])


func test_mirage_marker_lands_and_breaks() -> void:
	var w: Dictionary = _only(["sprite_mirage"], "dunes")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var ev: Dictionary = _until_resolve(w, "sprite_mirage")
	_check("mirage: the marker skill resolves", not ev.is_empty())
	var marks: Array[Vector2i] = ctrl.marker_cells()
	_check("mirage: exactly one marker", marks.size() == 1, str(marks))
	_check("mirage: it sits on the enemy half", not marks.is_empty() and state.grid.is_enemy_cell(marks[0]), str(marks))
	_check("mirage: in the hero's row", not marks.is_empty() and marks[0].y == state.player_cell.y,
		"%s vs hero %s" % [str(marks), str(state.player_cell)])
	# break_min_cells 1: a single-cell player cast on it clears the shade.
	ctrl.on_player_cast([marks[0]] as Array[Vector2i])
	_check("mirage: a 1-cell cast breaks it", ctrl.marker_cells().is_empty(), str(ctrl.marker_cells()))


func test_lash_needs_the_mirage() -> void:
	# The lash alone, with no mirage to anchor on, must never be cast: requires_anchor gates it.
	var w: Dictionary = _only(["sprite_shimmer_lash"], "dunes")
	_run(w, 14.0)
	var casts: int = 0
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == "sprite_shimmer_lash":
			casts += 1
	_check("lash: never cast without a mirage", casts == 0, str(casts))


func test_lash_damage_and_fragile() -> void:
	var w: Dictionary = _world("mirage_sprite", "dunes", 2)
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ev: Dictionary = _until_resolve(w, "sprite_shimmer_lash", 25.0)
	_check("lash: it lands once a mirage is up", not ev.is_empty())
	if ev.is_empty():
		return
	_check("lash: damage from data (%.0f)" % _dmg("sprite_shimmer_lash"),
		not bool(ev["hit"]) or is_equal_approx(float(ev["damage"]), _dmg("sprite_shimmer_lash")), str(ev))
	_check("lash: a hit leaves 1 Rạn", not bool(ev["hit"]) or status.fragile_stacks(P) >= 1, str(status.fragile_stacks(P)))


func test_shield_wall_guards_and_can_be_interrupted() -> void:
	var w: Dictionary = _only(["scarab_shield_wall"], "oasis")
	var status: StatusEffects = w["status"]
	_until_resolve(w, "scarab_shield_wall")
	_check("shield wall: Guard 4 on the ENEMY side", is_equal_approx(status.guard_amount(E), 4.0), str(status.guard_amount(E)))
	_check("shield wall: the hero side gets nothing", is_equal_approx(status.guard_amount(P), 0.0), str(status.guard_amount(P)))
	# Its windup is interruptible and stuns for 0.8 s.
	var w2: Dictionary = _only(["scarab_shield_wall"], "oasis", 3)
	var ctrl2: PatternController = w2["ctrl"]
	var hit: bool = false
	var t: float = 0.0
	while t < 12.0 and not hit:
		_run(w2, STEP)
		t += STEP
		if ctrl2.get_stage() == PatternController.Stage.WINDUP:
			hit = ctrl2.on_enemy_hit()
	_check("shield wall: a hit during the windup interrupts it", hit)
	_check("shield wall: and leaves it stunned", not hit or ctrl2.get_stage() == PatternController.Stage.STUNNED,
		str(ctrl2.get_stage()))


func test_shield_wall_weight_with_an_ally() -> void:
	var skill: Dictionary = _cfg.skills["scarab_shield_wall"]
	var alone: float = PatternBrain.weight_for(skill, {}, {"player_cell": Vector2i.ZERO, "allies_alive": 0}, _cfg.ai)
	var packed: float = PatternBrain.weight_for(skill, {}, {"player_cell": Vector2i.ZERO, "allies_alive": 1}, _cfg.ai)
	_check("shield wall: 0.3 alone", is_equal_approx(alone, 0.3), str(alone))
	_check("shield wall: x4 with an ally alive (= 1.2)", is_equal_approx(packed, 1.2), str(packed))


func test_spear_is_a_line_down_the_column() -> void:
	var w: Dictionary = _only(["scarab_spear"], "oasis")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_check("spear: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("spear: 1-2 cells covering the hero", red.size() >= 1 and red.size() <= 2 and red.has(state.player_cell), str(red))
	# PatternPlanner maps a column_of_player offset as (player.x - off.y, start + off.x), so a line DOWN the column
	# shares the hero's x and differs in y. The shared-x half alone passes trivially on a 1-cell array (clip can leave
	# one), which is how a horizontal pair hid here once: the differing-y half is what makes this leg able to fail.
	var same_x: bool = true
	for c: Vector2i in red:
		same_x = same_x and c.x == state.player_cell.x
	_check("spear: every cell shares the hero's column (x)", same_x, str(red))
	var two_cell_seen: bool = false
	var ys: Array[int] = []
	for i: int in 8:
		var w2: Dictionary = _only(["scarab_spear"], "oasis", i + 1)
		if not _until_stage(w2, PatternController.Stage.WARNING):
			continue
		var r2: Array[Vector2i] = (w2["ctrl"] as PatternController).telegraph_cells()
		if r2.size() == 2:
			two_cell_seen = true
			ys = [r2[0].y, r2[1].y]
			break
	_check("spear: an unclipped cast is 2 cells", two_cell_seen, "no 2-cell cast over 8 seeds")
	_check("spear: those two cells differ in y (a line, not a bar)", ys.size() == 2 and ys[0] != ys[1], str(ys))
	var ev: Dictionary = _until_resolve(w, "scarab_spear")
	_check("spear: damage from data (%.0f)" % _dmg("scarab_spear"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("scarab_spear")), str(ev))


func test_blinding_arc_cross_and_slow() -> void:
	var w: Dictionary = _only(["archer_blinding_arc"], "dunes")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_check("arc: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("arc: the cross covers the hero", red.has(state.player_cell), str(red))
	_check("arc: 3-5 cells after clipping to the grid", red.size() >= 3 and red.size() <= 5, str(red))
	# A cross leaves its four diagonals open, which is the counter the strings row promises.
	var diag_free: bool = false
	for d: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var n: Vector2i = state.player_cell + d
		if state.grid.is_player_cell(n) and not red.has(n):
			diag_free = true
	_check("arc: at least one diagonal step is out of the cross", diag_free, str(red))
	var ev: Dictionary = _until_resolve(w, "archer_blinding_arc")
	_check("arc: damage from data (%.0f)" % _dmg("archer_blinding_arc"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("archer_blinding_arc")), str(ev))
	_check("arc: a hit slows the hero (step mult > 1)", status.step_mult(P) > 1.0, str(status.step_mult(P)))


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	var keys: Array[String] = []
	for id: String in ["sprite_mirage", "sprite_shimmer_lash", "scarab_shield_wall", "scarab_spear", "archer_blinding_arc"]:
		keys.append("enemy_skill.%s.name" % id)
		keys.append("enemy_skill.%s.counter" % id)
	var seen: Dictionary = {}
	for line: String in raw.split("\n"):
		var row: PackedStringArray = line.strip_edges().split(",")
		if row.size() > 0 and keys.has(row[0]):
			seen[row[0]] = line.strip_edges()
	_check("strings: all 10 S-B rows exist", seen.size() == keys.size(), str(seen.keys()))
	for k: String in seen:
		var cols: PackedStringArray = (seen[k] as String).split(",")
		var quoted: bool = (seen[k] as String).contains("\"")
		_check("strings: %s parses as 3 columns" % k, quoted or cols.size() == 3, seen[k])

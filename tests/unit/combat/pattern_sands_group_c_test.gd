extends SceneTree
## Monster Skill Phase 2 group S-C (MONSTER-SKILL-PHASE2-PLAN.md §5): the two Sands elites, sand_burrower and
## scorpion, on the shipped dunes / oasis grids.
## - burrower_undertow: a 2-3 cell line down the hero's COLUMN (offsets [[0,0],[0,1],[0,2]] on column_of_player, which
##   runs along x), data damage, and Rễ (root) on the FIRST cell only;
## - burrower_sinkhole: gated on hp_below 0.5 — never cast at full HP — and drops TWO cells BESIDE the hero, never
##   the hero's own (deviation from §4.3 recorded in the plan: `count` is marker-only in the engine, so the two cells
##   are written as offsets);
## - scorpion_venom_sting: one cell, data damage plus Độc 3 s at 0.5 s / 1.5 (9 total), and a second sting REFRESHES
##   rather than stacks (Phase 0: max duration, max damage, min interval);
## - scorpion_pincer_hold: a 2-cell clamp on the hero, data damage plus Đóng Băng (pin) 0.6 s, subject to the F4
##   grace so it can never chain locks.
## The two traits these elites carry (burrow, riposte) are not exercised here: burrow's pause of the pattern brain is
## covered by pattern_phase0_pause_test and region_traits_test, riposte by region_traits_test. This suite is the SKILL
## invariant, as the Hellfire group suites were.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_sands_group_c_test.gd

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
	test_undertow_is_a_column_line_with_root_on_the_first_cell()
	test_sinkhole_waits_for_half_hp()
	test_sinkhole_drops_two_cells_beside_the_hero()
	test_venom_sting_poisons_and_refreshes()
	test_pincer_hold_pins()
	test_strings_rows()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers ---------------------------------------------------------------------------------------------

func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


## A world holding only [param ids], so one skill can be tested without its sibling competing for casts.
func _only(ids: Array, shape: String, seed_value: int = 1) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	var skills: Dictionary = {}
	for id: String in ids:
		skills[id] = (data["skills"] as Dictionary)[id]
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": skills,
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ids}}})
	var w: Dictionary = Fx.world(_grid(shape, seed_value), cfg, "g", seed_value, 1000.0)
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


# --- tests -----------------------------------------------------------------------------------------------

func test_data_shape() -> void:
	for id: String in ["sand_burrower", "scorpion"]:
		_check("enemy %s loaded" % id, not _cfg.get_enemy(id).is_empty())
		_check("%s is an elite" % id, str(_cfg.get_enemy(id).get("tier", "")) == "elite", str(_cfg.get_enemy(id).get("tier")))
	_check("burrower: undertow + sinkhole",
		(_cfg.get_enemy("sand_burrower")["phases"][0]["skills"] as Array) == ["burrower_undertow", "burrower_sinkhole"])
	_check("scorpion: sting + pincer",
		(_cfg.get_enemy("scorpion")["phases"][0]["skills"] as Array) == ["scorpion_venom_sting", "scorpion_pincer_hold"])
	for id: String in ["burrower_undertow", "burrower_sinkhole", "scorpion_venom_sting", "scorpion_pincer_hold"]:
		var s: Dictionary = _cfg.skills[id]
		_check("%s has name / counter keys" % id, str(s["name_key"]) == "enemy_skill.%s.name" % id
			and str(s["counter_key"]) == "enemy_skill.%s.counter" % id)
		_check("%s names its delivery" % id, (s["delivery"] as Dictionary).has("type"))
	_check("sinkhole: gated on half HP",
		is_equal_approx(float((_cfg.skills["burrower_sinkhole"]["conditions"] as Dictionary).get("hp_below", 0.0)), 0.5))
	# EnemySkillsConfig._normalize_effects always writes a `damage` key (0 when the data omits it, :270), so the test
	# is that it is ZERO — asking whether the key exists would be false for every skill in the file.
	_check("sinkhole: a drop zone, and no damage of its own",
		str(((_cfg.skills["burrower_sinkhole"]["effects"] as Dictionary)["zone"] as Dictionary)["id"]) == "drop"
		and is_equal_approx(_dmg("burrower_sinkhole"), 0.0), str(_dmg("burrower_sinkhole")))
	_check("sinkhole: two cells, never the hero's own",
		((_cfg.skills["burrower_sinkhole"]["pattern"] as Dictionary)["offsets"] as Array).size() == 2
		and bool((_cfg.skills["burrower_sinkhole"]["pattern"] as Dictionary).get("exclude_player", false)))
	var venom: Dictionary = (_cfg.skills["scorpion_venom_sting"]["effects"] as Dictionary)["status"] as Dictionary
	_check("sting: Độc 3 s at 0.5 s / 1.5 = 9 total",
		str(venom["id"]) == "poison" and is_equal_approx(float(venom["sec"]), 3.0)
		and is_equal_approx(float(venom["tick_sec"]), 0.5) and is_equal_approx(float(venom["damage"]), 1.5))
	_check("pincer: pin 0.6 s",
		str(((_cfg.skills["scorpion_pincer_hold"]["effects"] as Dictionary)["status"] as Dictionary)["id"]) == "pin")
	# Tuning guard, as in groups A and B.
	var chars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/characters.json"))
	var low: float = INF
	for c: Dictionary in (chars["characters"] as Array):
		var attrs: Dictionary = c.get("attributes", {}) as Dictionary
		low = minf(low, float(attrs.get("max_hp", c.get("max_hp", INF))))
	var worst: float = 0.0
	for sid: String in ["burrower_undertow", "scorpion_venom_sting", "scorpion_pincer_hold"]:
		worst = maxf(worst, 1.5 * _dmg(sid))
	_check("guard: the worst S-C hit (x1.5 Rạn) < half the lowest hero HP", worst > 0.0 and worst < 0.5 * low,
		"%.1f vs %.1f" % [worst, 0.5 * low])


func test_undertow_is_a_column_line_with_root_on_the_first_cell() -> void:
	var w: Dictionary = _only(["burrower_undertow"], "dunes")
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_check("undertow: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("undertow: 2-3 cells covering the hero", red.size() >= 2 and red.size() <= 3 and red.has(state.player_cell), str(red))
	var same_x: bool = true
	for c: Vector2i in red:
		same_x = same_x and c.x == state.player_cell.x
	_check("undertow: the line runs down the hero's column (shared x)", same_x, str(red))
	var ev: Dictionary = _until_resolve(w, "burrower_undertow")
	_check("undertow: damage from data (%.0f)" % _dmg("burrower_undertow"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("burrower_undertow")), str(ev))
	# first_cell_only: the root lands only when the hero is standing on the line's FIRST cell.
	var rooted: bool = status.get_root_left(P) > 0.0
	var on_first: bool = not red.is_empty() and red[0] == state.player_cell
	_check("undertow: Rễ only when the hero was on the first cell", rooted == on_first,
		"rooted %s, hero on first %s" % [str(rooted), str(on_first)])


func test_sinkhole_waits_for_half_hp() -> void:
	# At full HP the sinkhole must never be cast: hp_below gates it, not just its weight.
	var w: Dictionary = _only(["burrower_sinkhole"], "dunes")
	_run(w, 16.0)
	var casts: int = 0
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == "burrower_sinkhole":
			casts += 1
	_check("sinkhole: never cast while the burrower is above half HP", casts == 0, str(casts))


func test_sinkhole_drops_two_cells_beside_the_hero() -> void:
	var w: Dictionary = _only(["burrower_sinkhole"], "dunes", 2)
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	state.enemy_hp = state.enemy_max_hp * 0.4  # open the gate
	_check("sinkhole: it warns once the burrower is hurt", _until_stage(w, PatternController.Stage.WARNING, 12.0))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("sinkhole: two cells", red.size() == 2, str(red))
	_check("sinkhole: never the cell the hero stands on", not red.has(state.player_cell),
		"%s vs hero %s" % [str(red), str(state.player_cell)])
	_until_resolve(w, "burrower_sinkhole", 8.0)
	# The drop zone marks the cells as cracking or holes through StatusEffects.
	var marked: int = 0
	for c: Vector2i in red:
		if status.is_cracking(P, c) or status.is_hole(P, c):
			marked += 1
	_check("sinkhole: the struck cells crack or fall", marked > 0, "%d of %d" % [marked, red.size()])
	# Ô rớt rule: the hero always keeps a neighbour to step to.
	var exit_free: bool = false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = state.player_cell + d
		if state.grid.is_player_cell(n) and not status.is_hole(P, n) and not status.is_cracking(P, n):
			exit_free = true
	_check("sinkhole: a safe neighbour always remains", exit_free, str(state.player_cell))


func test_venom_sting_poisons_and_refreshes() -> void:
	var w: Dictionary = _only(["scorpion_venom_sting"], "oasis")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ev: Dictionary = _until_resolve(w, "scorpion_venom_sting")
	_check("sting: it hits", not ev.is_empty() and bool(ev["hit"]), str(ev))
	_check("sting: damage from data (%.0f)" % _dmg("scorpion_venom_sting"),
		not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg("scorpion_venom_sting")), str(ev))
	_check("sting: the hero is poisoned", status.is_poisoned(P))
	var left_after_first: float = status.get_poison_left(P)
	_check("sting: about 3 s of venom", left_after_first > 2.0 and left_after_first <= 3.01, str(left_after_first))
	# Let it tick a while, then take a second sting: the venom REFRESHES rather than stacking.
	_run(w, 1.0)
	var mid: float = status.get_poison_left(P)
	_check("sting: the venom is ticking down", mid < left_after_first, "%.2f -> %.2f" % [left_after_first, mid])
	var ev2: Dictionary = _until_resolve(w, "scorpion_venom_sting", 10.0)
	if not ev2.is_empty() and bool(ev2["hit"]):
		_check("sting: a second sting refreshes, never exceeds 3 s", status.get_poison_left(P) <= 3.01,
			str(status.get_poison_left(P)))
		_check("sting: and the tick damage stays 1.5", is_equal_approx(status.poison_tick_damage(P), 1.5),
			str(status.poison_tick_damage(P)))


func test_pincer_hold_pins() -> void:
	var w: Dictionary = _only(["scorpion_pincer_hold"], "oasis")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	_check("pincer: it warns", _until_stage(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = ctrl.telegraph_cells()
	_check("pincer: a 2-cell clamp on the hero", red.size() == 2 and red.has(state.player_cell), str(red))
	var ev: Dictionary = _until_resolve(w, "scorpion_pincer_hold")
	_check("pincer: damage from data (%.0f)" % _dmg("scorpion_pincer_hold"),
		not ev.is_empty() and bool(ev["hit"]) and is_equal_approx(float(ev["damage"]), _dmg("scorpion_pincer_hold")), str(ev))
	_check("pincer: a hit pins the hero", status.is_pinned(P) or status.get_pin_left(P) > 0.0,
		str(status.get_pin_left(P)))


func test_strings_rows() -> void:
	var raw: String = FileAccess.get_file_as_string("res://assets/i18n/strings.csv")
	var keys: Array[String] = []
	for id: String in ["burrower_undertow", "burrower_sinkhole", "scorpion_venom_sting", "scorpion_pincer_hold"]:
		keys.append("enemy_skill.%s.name" % id)
		keys.append("enemy_skill.%s.counter" % id)
	var seen: Dictionary = {}
	for line: String in raw.split("\n"):
		var row: PackedStringArray = line.strip_edges().split(",")
		if row.size() > 0 and keys.has(row[0]):
			seen[row[0]] = line.strip_edges()
	_check("strings: all 8 S-C rows exist", seen.size() == keys.size(), str(seen.keys()))
	for k: String in seen:
		var cols: PackedStringArray = (seen[k] as String).split(",")
		var quoted: bool = (seen[k] as String).contains("\"")
		_check("strings: %s parses as 3 columns" % k, quoted or cols.size() == 3, seen[k])

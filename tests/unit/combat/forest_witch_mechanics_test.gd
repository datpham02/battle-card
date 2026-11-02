extends SceneTree
## P2.4 Forest Witch mechanics (design/quick-specs/phase2-misty-forest-2026-11-01.md 7.1-7.4 and the user decisions D8,
## D9, D11-D14). Each test names its scenario and the expected result:
## - data: 1210 written HP (= 5.5 x 140 effective at floor 3), pattern brain, boss_hall, 2x2 footprint, 3 phases at
##   65 % / 30 % with the spec's skill lists, mechanics and every_nth, no rotten_thrower, boss pool tiers, strings;
## - phase change: 1.5 s invulnerable (hits do nothing), the warning showing is cleared, one hit never skips a phase,
##   phase 2 opens by placing 2 root anchors in 2 different rows;
## - D9: entangled_row / withered_crown / forest_last_knot cannot be interrupted (ivory frame on her 4 cells while they
##   wind up / warn), the other four can;
## - D13: a card covering several of her 4 cells hits once (same damage as one covering a single cell of her);
## - 7.1 anchors: on her half, never under her, one 1-cell block breaks one, Moss Guard drops when the last one breaks;
## - branch_lattice's followup grows from the L's end toward the anchor's row; withered_crown's second lane is the same
##   bar one row / column over (parallel, adjacent) and shows as the queued stripe; entangled_row strikes the two anchor
##   rows when the red ceiling allows and falls back to one row when it does not (F2);
## - forest_last_knot: 22 + followup with an anchor alive, 11 and no followup without.
## Run: godot --headless --path . -s res://tests/unit/combat/forest_witch_mechanics_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const FloorLayerScript := preload("res://src/battle/floor_layer.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const ARENA: String = "boss_hall"
const STEP: float = 0.05
const ENEMY_HP: float = 770.0
const HEAVY: Array[String] = ["entangled_row", "withered_crown", "forest_last_knot"]
const LIGHT: Array[String] = ["root_nail", "branch_lattice", "moss_guard", "root_anchor"]
const SQUARE_2X2: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

var fails: int = 0
var cfg: EnemySkillsConfig
var raw: Dictionary
var library: ArenaLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	cfg = EnemySkillsConfig.load_from_file()
	raw = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH)) as Dictionary
	library = ArenaLibrary.load_from_file()
	_check("shipped enemy_skills.json has no problems", cfg.problems.is_empty(), str(cfg.problems))
	test_data_matches_spec_and_decisions()
	test_phase_change_invulnerable_1_5_sec_clears_red_and_clamps()
	test_heavy_skills_ignore_interrupt_others_cancel()
	test_hit_over_several_footprint_cells_counts_once()
	test_anchors_on_her_half_break_with_one_cell_and_drop_guard()
	test_branch_lattice_followup_grows_toward_anchor_row()
	test_withered_crown_second_lane_parallel_and_queued()
	test_entangled_row_two_rows_then_one_under_red_ceiling()
	test_last_knot_damage_depends_on_anchor()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- helpers -----------------------------------------------------------------------------------------------------------

func _grid() -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": ARENA}, library, 1)


# A config = the shipped data plus test enemies [param extra] (id -> enemy dict, 2x2 like her).
func _config_with(extra: Dictionary) -> EnemySkillsConfig:
	var data: Dictionary = raw.duplicate(true)
	for id: String in extra:
		var e: Dictionary = (extra[id] as Dictionary).duplicate(true)
		e["footprint"] = [[0, 0], [1, 0], [0, 1], [1, 1]]
		(data["enemies"] as Dictionary)[id] = e
	return EnemySkillsConfig.from_dictionary(data)


func _tick(w: Dictionary, sec: float) -> void:
	var left: float = sec
	while left > 0.000001:
		var d: float = minf(STEP, left)
		(w["status"] as StatusEffects).tick(d, w["state"] as CombatState)
		(w["mover"] as UnitMover).tick(d)
		(w["ctrl"] as PatternController).tick(d)
		left -= d


func _until(w: Dictionary, pred: Callable, limit: float) -> bool:
	var t: float = 0.0
	while t < limit:
		if pred.call():
			return true
		_tick(w, STEP)
		t += STEP
	return bool(pred.call())


func _skill_now(ctrl: PatternController) -> String:
	return str(ctrl.get_current_skill().get("id", ""))


func _resolves(ctrl: PatternController, skill: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in ctrl.event_log:
		if str(ev.get("skill", "")) == skill and str(ev.get("event", "")) == "resolve":
			out.append(ev)
	return out


# A player cell in the middle rows / columns of the half (every neighbour real), so every rotation fits.
func _inner_cell(grid: BoardGrid) -> Vector2i:
	return Vector2i(grid.side_cols / 2, 1)


# --- tests -------------------------------------------------------------------------------------------------------------

func test_data_matches_spec_and_decisions() -> void:
	var chapters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chapters.json")) as Dictionary
	var ch1: Dictionary = {}
	for chapter: Variant in chapters["chapters"]:
		if str((chapter as Dictionary).get("id", "")) == "ch1":
			ch1 = chapter
	var m: Dictionary = (ch1["matches"] as Dictionary)["forest_witch"]
	var written: float = float(m["boss_max_hp"])
	_check("match: 1210 written HP", is_equal_approx(written, 1210.0), str(written))
	var effective: float = written * 0.75 * 0.85
	_check("D8: 1210 x 0.6375 = %.1f effective at floor 3, within 1 %% of 5.5 x 140 = 770" % effective, absf(effective - 770.0) <= 7.7)
	_check("match: pattern brain, enemy forest_witch, boss_hall, aggressive movement",
		str(m.get("brain", "")) == "pattern" and str(m.get("enemy", "")) == "forest_witch"
		and str((m.get("arena", {}) as Dictionary).get("shape", "")) == ARENA and str(m.get("brain_set", "")) == "aggressive")
	_check("D12: no rotten_thrower", not JSON.stringify(m.get("traits", [])).contains("rotten_thrower"))
	var boss: Dictionary = (ch1["pools"] as Dictionary)["boss"]
	_check("D11: boss tier 1 goblin_warlock, tier 2 forest_witch", boss["1"] == ["goblin_warlock"] and boss["2"] == ["forest_witch"], str(boss))
	var enemy: Dictionary = cfg.get_enemy("forest_witch")
	_check("enemy: warden, not dev, 2x2 footprint, boss_hall hint", str(enemy.get("tier", "")) == "warden" and not bool(enemy.get("dev", true))
		and (enemy.get("footprint", []) as Array) == SQUARE_2X2 and str(enemy.get("arena", "")) == ARENA)
	var phases: Array = enemy.get("phases", []) as Array
	var lists: Array = [
		["root_nail", "branch_lattice", "root_anchor", "entangled_row", "witch_shift"],
		["root_nail", "branch_lattice", "root_anchor", "entangled_row", "moss_guard", "withered_crown", "witch_shift"],
		["root_nail", "branch_lattice", "root_anchor", "entangled_row", "moss_guard", "withered_crown", "forest_last_knot", "witch_shift"],
	]
	var ratios: Array[float] = [1.0, 0.65, 0.30]
	var mechanics: Array[String] = ["root_anchor", "withered_crown", "forest_last_knot"]
	var phases_ok: bool = phases.size() == 3
	for i: int in mini(phases.size(), 3):
		var ph: Dictionary = phases[i]
		phases_ok = phases_ok and ph["skills"] == lists[i] and is_equal_approx(float(ph["enter_hp_ratio"]), ratios[i]) \
			and str(ph["mechanic"]) == mechanics[i] and (i == 0 or is_equal_approx(float((ph["transition"] as Dictionary)["sec"]), 1.5))
	_check("phases: 65 % / 30 %, the 4 / 6 / 7 skills + the row shift, mechanics, 1.5 s transitions", phases_ok)
	# 2026-11-02 (user: "Thêm chiêu dời hàng"): the row shift moves her one row, every 8 s at most, and is not a cast.
	var shift: Dictionary = cfg.skill_for_phase("witch_shift", phases[0]) if phases.size() > 0 else {}
	_check("witch_shift: self skill, adjacent_row move, 8 s cooldown, not counted as a cast",
		str(shift.get("kind", "")) == "self" and ((shift.get("effects", {}) as Dictionary).get("move", {}) as Dictionary).get("to", "") == "adjacent_row"
		and is_equal_approx(float(shift.get("cooldown_sec", 0.0)), 8.0) and not bool(shift.get("counts_as_cast", true)), str(shift))
	_check("phase 3: forest_last_knot every 3rd cast", phases.size() == 3 and (phases[2]["every_nth"] as Dictionary) == {"skill": "forest_last_knot", "n": 3})
	_check("phase 2 opens with root_anchor; anchors x2 in phases 2-3",
		phases.size() == 3 and ((phases[1]["transition"] as Dictionary)["on_enter"] as Array) == ["root_anchor"]
		and int((cfg.skill_for_phase("root_anchor", phases[0])["pattern"] as Dictionary)["count"]) == 1
		and int((cfg.skill_for_phase("root_anchor", phases[1])["pattern"] as Dictionary)["count"]) == 2
		and int((cfg.skill_for_phase("root_anchor", phases[2])["pattern"] as Dictionary)["count"]) == 2)
	var flags_ok: bool = true
	for id: String in HEAVY:
		flags_ok = flags_ok and not bool(cfg.skills[id]["interruptible"]) and float(cfg.skills[id]["recovery_sec"]) >= 1.2
	for id: String in LIGHT:
		flags_ok = flags_ok and bool(cfg.skills[id]["interruptible"])
	_check("D9: the 3 heavy skills uninterruptible with recovery >= 1.2 s, the 4 others interruptible", flags_ok)
	var strings: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() == 3:
			strings[row[0]] = row
	var missing: Array[String] = []
	var keys: Array[String] = ["boss.forest_witch.name"]
	for id: String in HEAVY + LIGHT:
		keys.append(str(cfg.skills[id]["name_key"]))
		keys.append(str(cfg.skills[id]["counter_key"]))
	for k: String in keys:
		if not strings.has(k) or (strings[k] as PackedStringArray)[1].is_empty() or (strings[k] as PackedStringArray)[2].is_empty():
			missing.append(k)
	_check("strings: boss name + every skill name / counter in vi and en", missing.is_empty(), str(missing))


func test_phase_change_invulnerable_1_5_sec_clears_red_and_clamps() -> void:
	var w: Dictionary = Fx.world(_grid(), cfg, "forest_witch", 3, ENEMY_HP)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var cleared: Array[String] = []
	ctrl.warning_cleared.connect(func(id: String, reason: String) -> void: cleared.append("%s:%s" % [id, reason]))
	var warning: bool = _until(w, func() -> bool: return ctrl.get_stage() == PatternController.Stage.WARNING, 20.0)
	_check("phase 1: a warning is showing", warning and not ctrl.telegraph_cells().is_empty())
	var id: String = _skill_now(ctrl)
	state.damage_enemy(100000.0)
	_check("one huge hit stops at 65 % (never skips phase 2)", is_equal_approx(state.enemy_hp, 0.65 * ENEMY_HP), str(state.enemy_hp))
	_tick(w, STEP)
	_check("phase 2 transition started", ctrl.get_phase_index() == 1 and ctrl.get_stage() == PatternController.Stage.TRANSITION)
	_check("the warning showing is cleared at once", ctrl.telegraph_cells().is_empty() and cleared.has("%s:phase" % id), str(cleared))
	_check("invulnerable for 1.5 s from the transition", is_equal_approx(state.enemy_invulnerable_left + STEP, 1.5) or is_equal_approx(state.enemy_invulnerable_left, 1.5),
		str(state.enemy_invulnerable_left))
	var hp: float = state.enemy_hp
	state.damage_enemy(50.0)
	_tick(w, 1.35)
	state.damage_enemy(50.0)
	_check("hits during the 1.5 s do nothing", is_equal_approx(state.enemy_hp, hp) and state.enemy_invulnerable_left > 0.0,
		"hp %.1f left %.2f" % [state.enemy_hp, state.enemy_invulnerable_left])
	_check("no red during the transition", ctrl.telegraph_cells().is_empty() and ctrl.get_stage() == PatternController.Stage.TRANSITION)
	_tick(w, 0.15)
	_check("vulnerable again after 1.5 s", state.enemy_invulnerable_left <= 0.0 and ctrl.get_stage() != PatternController.Stage.TRANSITION)
	var placed: bool = _until(w, func() -> bool: return ctrl.marker_cells().size() >= 2, 3.0)
	var rows: Dictionary = {}
	for c: Vector2i in ctrl.marker_cells():
		rows[c.y] = true
	_check("phase 2 opens with 2 root anchors in 2 rows", placed and rows.size() >= 2, str(ctrl.marker_cells()))
	state.damage_enemy(100000.0)
	_check("in phase 2 a huge hit stops at 30 %", is_equal_approx(state.enemy_hp, 0.30 * ENEMY_HP), str(state.enemy_hp))
	_tick(w, STEP)
	_check("phase 3 transition, invulnerable again", ctrl.get_phase_index() == 2 and state.enemy_invulnerable_left > 1.4)


func test_heavy_skills_ignore_interrupt_others_cancel() -> void:
	var extra: Dictionary = {}
	for id: String in HEAVY + LIGHT:
		var skills: Array = ["root_anchor", id] if id != "root_anchor" else [id]
		var phase: Dictionary = {"id": "solo", "skills": skills}
		if id == "forest_last_knot":
			phase["every_nth"] = {"skill": id, "n": 2}
		extra["solo_" + id] = {"tier": "warden", "phases": [phase]}
	var c: EnemySkillsConfig = _config_with(extra)
	for id: String in HEAVY + LIGHT:
		var w: Dictionary = Fx.world(_grid(), c, "solo_" + id, 5, ENEMY_HP)
		var ctrl: PatternController = w["ctrl"]
		(w["state"] as CombatState).set_player_cell(_inner_cell((w["state"] as CombatState).grid))
		var in_windup: bool = _until(w, func() -> bool: return ctrl.get_stage() == PatternController.Stage.WINDUP and _skill_now(ctrl) == id, 40.0)
		if not in_windup:
			_check("%s winds up" % id, false)
			continue
		var heavy: bool = HEAVY.has(id)
		var extras: Dictionary = FloorLayerScript.pattern_extras_state(ctrl, w["status"], w["state"])
		var framed: bool = (extras.get("outline", []) as Array).size() == 4
		for cell: Vector2i in (w["state"] as CombatState).enemy_footprint_cells():
			framed = framed and (extras.get("outline", []) as Array).has(cell)
		_check("%s: ivory frame on her 4 cells while winding up = %s" % [id, heavy], framed == heavy and ctrl.uninterruptible_tell() == heavy)
		var cancelled: bool = ctrl.on_enemy_hit()
		_check("%s: a hit during the windup %s" % [id, "does not cancel it" if heavy else "cancels it"],
			cancelled == (not heavy) and (_skill_now(ctrl) == id) == heavy)
		if heavy and str(c.skills[id]["kind"]) == "attack":
			var warned: bool = _until(w, func() -> bool: return ctrl.get_stage() == PatternController.Stage.WARNING and _skill_now(ctrl) == id, 3.0)
			var framed_warn: bool = (FloorLayerScript.pattern_extras_state(ctrl, w["status"], w["state"]).get("outline", []) as Array).size() == 4
			_check("%s: a hit during the warning does not cancel it, frame still on" % id,
				warned and not ctrl.on_enemy_hit() and not ctrl.telegraph_cells().is_empty() and framed_warn)
		elif str(c.skills[id]["kind"]) == "attack":
			var w2: Dictionary = Fx.world(_grid(), c, "solo_" + id, 5, ENEMY_HP)
			var c2: PatternController = w2["ctrl"]
			(w2["state"] as CombatState).set_player_cell(_inner_cell((w2["state"] as CombatState).grid))
			var warned2: bool = _until(w2, func() -> bool: return c2.get_stage() == PatternController.Stage.WARNING and _skill_now(c2) == id, 40.0)
			_check("%s: a hit during the warning cancels it and the red goes" % id, warned2 and c2.on_enemy_hit() and c2.telegraph_cells().is_empty())


func test_hit_over_several_footprint_cells_counts_once() -> void:
	var damages: Array[float] = []
	var cut: CutConfig = CutConfig.load_from_file()
	var skills: SkillConfig = SkillConfig.load_from_file()
	for covered: int in [1, 2, 4]:
		var w: Dictionary = Fx.world(_grid(), cfg, "forest_witch", 1, ENEMY_HP)
		var state: CombatState = w["state"]
		var body: Array[Vector2i] = state.enemy_footprint_cells()
		# Always a 4-cell card: [covered] cells on her, the rest on free cells of her half.
		var cells: Array[Vector2i] = body.slice(0, covered)
		for c: Vector2i in state.grid.enemy_cells():
			if cells.size() >= 4:
				break
			if not body.has(c):
				cells.append(c)
		var before: float = state.enemy_hp
		var result: Dictionary = CutEffects.apply(state, state.grid, P, cells, SkillConfig.FALLBACK_SKILL, cut, skills, w["status"])
		_check("4-cell card covering %d of her cells: one hit" % covered, bool(result["hit"]) and is_equal_approx(before - state.enemy_hp, float(result["damage"])))
		damages.append(before - state.enemy_hp)
	_check("D13: covering 1, 2 or 4 of her cells deals the same damage %s" % str(damages),
		damages.size() == 3 and damages[0] > 0.0 and is_equal_approx(damages[0], damages[1]) and is_equal_approx(damages[0], damages[2]))


func test_anchors_on_her_half_break_with_one_cell_and_drop_guard() -> void:
	var c: EnemySkillsConfig = _config_with({"solo_guard": {"tier": "warden", "phases": [{"id": "solo", "skills": ["root_anchor", "moss_guard"],
		"overrides": {"root_anchor": {"count": 2}}}]}})
	var w: Dictionary = Fx.world(_grid(), c, "solo_guard", 2, ENEMY_HP)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var guarded: bool = _until(w, func() -> bool: return status.get_guard_left(E) > 0.0, 30.0)
	_check("Moss Guard: +6 armor while an anchor stands", guarded and is_equal_approx(status.guard_amount(E), 6.0) and status.get_guard_left(E) <= 10.0)
	var marks: Array[Vector2i] = ctrl.marker_cells()
	var placed_ok: bool = marks.size() == 2 and marks[0].y != marks[1].y
	# More seeds: a 2-anchor cast always uses 2 rows (a same-row pick would show on some seed).
	for s: int in range(10, 22):
		var ws: Dictionary = Fx.world(_grid(), c, "solo_guard", s, ENEMY_HP)
		var cs: PatternController = ws["ctrl"]
		_until(ws, func() -> bool: return cs.marker_cells().size() >= 2, 10.0)
		var ms: Array[Vector2i] = cs.marker_cells()
		placed_ok = placed_ok and ms.size() == 2 and ms[0].y != ms[1].y
	for m: Vector2i in marks:
		placed_ok = placed_ok and state.grid.is_enemy_cell(m) and not state.enemy_footprint_cells().has(m)
	_check("2 anchors in 2 rows of her half, none under her (13 seeds)", placed_ok, "%s body %s" % [marks, state.enemy_footprint_cells()])
	if marks.size() < 2:
		return
	ctrl.on_player_cast([marks[0]] as Array[Vector2i])
	_check("a 1-cell block breaks one anchor", ctrl.marker_cells() == ([marks[1]] as Array[Vector2i]))
	_tick(w, STEP)
	_check("Guard holds while one anchor stands", status.get_guard_left(E) > 0.0)
	ctrl.on_player_cast([marks[1], state.enemy_footprint_cells()[0]] as Array[Vector2i])
	_tick(w, STEP)
	_check("breaking the last anchor drops the Guard", ctrl.marker_cells().is_empty() and status.get_guard_left(E) <= 0.0)
	var none: Dictionary = Fx.world(_grid(), _config_with({"solo_g": {"tier": "warden", "skills": ["moss_guard"]}}), "solo_g", 2, ENEMY_HP)
	_tick(none, 20.0)
	_check("Moss Guard is never cast without an anchor", _resolves(none["ctrl"], "moss_guard").is_empty())


func test_branch_lattice_followup_grows_toward_anchor_row() -> void:
	var grid: BoardGrid = _grid()
	var followup: Dictionary = cfg.skills["branch_lattice"]["followup"]
	var first: Array[Vector2i] = [Vector2i(3, 1), Vector2i(3, 2), Vector2i(2, 2)]  # L, its end (2, 2)
	for anchor_row: int in [0, 3]:
		var ctx: Dictionary = {"grid": grid, "player_cell": Vector2i(3, 1), "enemy_cell": Vector2i(8, 1), "markers": [Vector2i(10, anchor_row)] as Array[Vector2i]}
		var lanes: Array[Dictionary] = PatternPlanner.followup_candidates(followup, first, Vector2i(3, 1), ctx)
		var ok: bool = not lanes.is_empty()
		for lane: Dictionary in lanes:
			var cell: Vector2i = (lane["cells"] as Array[Vector2i])[0]
			ok = ok and (lane["cells"] as Array).size() == 1 and absi(cell.y - anchor_row) < absi(2 - anchor_row) \
				and absi(cell.x - 2) + absi(cell.y - 2) == 1 and not first.has(cell)
		_check("branch_lattice followup: one new cell next to the L's end, toward anchor row %d" % anchor_row, ok, str(lanes))
	var free: Array[Dictionary] = PatternPlanner.followup_candidates(followup, first, Vector2i(3, 1),
		{"grid": grid, "player_cell": Vector2i(3, 1), "enemy_cell": Vector2i(8, 1), "markers": [] as Array[Vector2i]})
	_check("branch_lattice followup without an anchor: every free neighbour of the end (AI picks)", free.size() == 3, str(free))


func test_withered_crown_second_lane_parallel_and_queued() -> void:
	var grid: BoardGrid = _grid()
	var skill: Dictionary = cfg.skills["withered_crown"]
	var ctx: Dictionary = {"grid": grid, "player_cell": _inner_cell(grid), "enemy_cell": Vector2i(8, 1)}
	var all_ok: bool = true
	var seen: int = 0
	for plan: Dictionary in PatternPlanner.plans(skill, ctx):
		var first: Array[Vector2i] = plan["cells"]
		var lanes: Array[Dictionary] = PatternPlanner.followup_candidates(skill["followup"], first, ctx["player_cell"], ctx, int(plan["rotation"]))
		var bar: Vector2i = first[1] - first[0]
		for lane: Dictionary in lanes:
			seen += 1
			var second: Array[Vector2i] = lane["cells"]
			var shift: Vector2i = second[0] - first[0]
			all_ok = all_ok and second.size() == 2 and second[1] - second[0] == bar and absi(shift.x) + absi(shift.y) == 1 \
				and shift.x * bar.x + shift.y * bar.y == 0 and not first.has(second[0]) and not first.has(second[1])
	_check("withered_crown: every second lane is the bar one row / column over (%d lanes checked)" % seen, all_ok and seen >= 4)
	var w: Dictionary = Fx.world(grid, _config_with({"solo_crown": {"tier": "warden", "skills": ["withered_crown"]}}), "solo_crown", 4, ENEMY_HP)
	var ctrl: PatternController = w["ctrl"]
	(w["state"] as CombatState).set_player_cell(_inner_cell(grid))
	var warned: bool = _until(w, func() -> bool: return ctrl.get_stage() == PatternController.Stage.WARNING, 10.0)
	var queued: Array[Vector2i] = ctrl.queued_cells()
	var painted: Dictionary = FloorLayerScript.pattern_telegraph_state(ctrl, CombatConfig.new(), false)
	_check("withered_crown: lane 2 shows as the queued stripe with lane 1", warned and queued.size() == 2 and (painted.get("queued", []) as Array) == queued)
	var red2: bool = _until(w, func() -> bool: return ctrl.telegraph_cells() == queued, 2.0)
	_check("withered_crown: lane 2 turns red when lane 1 strikes, 0.75 s to land", red2 and is_equal_approx(ctrl.warning_progress(), 0.0)
		and not _resolves(ctrl, "withered_crown").is_empty())


func test_entangled_row_two_rows_then_one_under_red_ceiling() -> void:
	var data: Dictionary = {"solo_row": {"tier": "warden", "phases": [{"id": "solo", "skills": ["root_anchor", "entangled_row"],
		"overrides": {"root_anchor": {"count": 2}, "entangled_row": {"pattern": {"anchor_rows": 2}}}}]}}
	var two_rows: Dictionary = {"anchor_rows": 2}
	for crowded: bool in [false, true]:
		var w: Dictionary = Fx.world(_grid(), _config_with(data), "solo_row", 6, ENEMY_HP)
		var ctrl: PatternController = w["ctrl"]
		var state: CombatState = w["state"]
		if crowded:
			# 9 cells of another warning in the rows WITHOUT an anchor (no overlap with the row windows): 9 + two rows of
			# 2..3 cells > 12 (half of 24), 9 + one row of 2..3 fits.
			ctrl.external_red_fn = func() -> Array:
				var out: Array = []
				var rows: Array[int] = PatternPlanner.anchor_rows(two_rows, ctrl.marker_cells())
				if rows.size() < 2:
					return out
				for cell: Vector2i in state.grid.player_cells():
					if out.size() < 9 and not rows.has(cell.y):
						out.append(cell)
				return out
		var warned: bool = _until(w, func() -> bool:
			return ctrl.get_stage() == PatternController.Stage.WARNING and _skill_now(ctrl) == "entangled_row" 				and PatternPlanner.anchor_rows(two_rows, ctrl.marker_cells()).size() == 2, 40.0)
		var anchor_rows: Array[int] = PatternPlanner.anchor_rows(two_rows, ctrl.marker_cells())
		var red_rows: Array[int] = []
		for cell: Vector2i in ctrl.telegraph_cells():
			if not red_rows.has(cell.y):
				red_rows.append(cell.y)
		red_rows.sort()
		anchor_rows.sort()
		if not crowded:
			_check("entangled_row with anchors in 2 rows strikes both rows %s (anchor rows %s)" % [red_rows, anchor_rows],
				warned and anchor_rows.size() == 2 and red_rows == anchor_rows)
		else:
			_check("entangled_row falls back to one anchor row when two would break the red ceiling %s (anchor rows %s)" % [red_rows, anchor_rows],
				warned and red_rows.size() == 1 and anchor_rows.has(red_rows[0]))


func test_last_knot_damage_depends_on_anchor() -> void:
	var c: EnemySkillsConfig = _config_with({
		"knot_anchor": {"tier": "warden", "phases": [{"id": "solo", "skills": ["root_anchor", "forest_last_knot"],
			"every_nth": {"skill": "forest_last_knot", "n": 2}}]},
		"knot_bare": {"tier": "warden", "phases": [{"id": "solo", "skills": ["forest_last_knot"],
			"every_nth": {"skill": "forest_last_knot", "n": 1}}]},
	})
	for id: String in ["knot_anchor", "knot_bare"]:
		var w: Dictionary = Fx.world(_grid(), c, id, 7, ENEMY_HP)
		var ctrl: PatternController = w["ctrl"]
		var state: CombatState = w["state"]
		state.player_max_hp = 1000.0
		state.player_hp = 1000.0
		state.set_player_cell(_inner_cell(state.grid))
		_until(w, func() -> bool: return _resolves(ctrl, "forest_last_knot").size() >= 2 or (id == "knot_bare" and _resolves(ctrl, "forest_last_knot").size() >= 1 and ctrl.get_stage() == PatternController.Stage.RECOVERY), 20.0)
		var strikes: Array[Dictionary] = _resolves(ctrl, "forest_last_knot")
		if id == "knot_anchor":
			_check("forest_last_knot with an anchor: 22 on the hero, then a followup strike on the T's centre",
				strikes.size() >= 2 and is_equal_approx(float(strikes[0]["damage"]), 22.0) and bool(strikes[1]["followup_strike"])
				and (strikes[1]["cells"] as Array).size() == 1, str(strikes))
		else:
			var followups: int = strikes.filter(func(e: Dictionary) -> bool: return bool(e["followup_strike"])).size()
			_check("forest_last_knot without an anchor: 11 and no followup",
				strikes.size() >= 1 and is_equal_approx(float(strikes[0]["damage"]), 11.0) and followups == 0, str(strikes))

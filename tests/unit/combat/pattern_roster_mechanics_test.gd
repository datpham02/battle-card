extends SceneTree
## Phase 2 P2.3 (design/quick-specs/phase2-misty-forest-2026-11-01.md 5.2-5.5, D2/D3/D5/D6/D10/D11/D12): the five Misty
## Forest pattern enemies' own mechanics on the SHIPPED enemy_skills.json, through PatternController with the real
## StatusEffects / UnitMover:
## - Rootling root_prick roots 0.7 s (step refused while rooted); creep only right after a block was aimed at it, the
##   ivory target is a cell one row up / down and the Rootling ends there;
## - Mossbound Sentry brace = Guard +3 for 3 s; Greycap Sporeling seedbed leaves Thorns on a cell next to the player;
## - Ancient Root Sentinel: a 1-cell cast does NOT break the anchor, a 2-cell cast does -> stunned 1.0 s, the
##   branch_net repeat (followup) cancelled, back to idle after the stun; the bark_shift zone is a drop tile (D6); the
##   anchor lands in the player's current row when that row has an empty enemy-half cell (`pattern.row: player`);
## - Mistbriar Matron thorn_fork: the followup is the two cells next to the first cell on ONE axis, the axis the
##   player stepped along; wreath_guard only at <= 50 % HP, once, Guard while the wreath stands, a 1-cell cast breaks it;
## - data: rotten_thrower gone from the Forest Witch (D12), boss pool tier 1 = goblin_warlock / tier 2 = forest_witch
##   (D11), every new match uses its own pattern enemy, teach_after on both elites (D10), names in strings.csv.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_roster_mechanics_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const NEW_ENEMIES: Array[String] = ["rootling", "mossbound_sentry", "greycap_sporeling", "ancient_root_sentinel", "mistbriar_matron"]

var fails: int = 0
var cfg: EnemySkillsConfig


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	cfg = EnemySkillsConfig.load_from_file()
	_check("shipped enemy_skills.json has no problems", cfg.problems.is_empty(), str(cfg.problems))
	test_rootling_root_prick_roots_0_7_sec()
	test_rootling_creep_needs_aim_and_moves_to_shown_cell()
	test_sentry_brace_guards_3_for_3_sec()
	test_sporeling_seedbed_leaves_thorns_next_to_player()
	test_sentinel_anchor_two_cell_break_stuns_and_cancels_followup()
	test_sentinel_anchor_prefers_player_row()
	test_sentinel_bark_shift_is_a_drop_tile()
	test_matron_fork_followup_follows_the_step_axis()
	test_matron_wreath_guard_below_half_once_breaks_with_one_cell()
	test_data_roster_pools_and_strings()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# Ticks [param w] (status, mover, controller) until [param pred] (Callable() -> bool) or [param limit] seconds; true when
# the predicate held. [param each] (Callable()) runs before each slice.
func _until(w: Dictionary, pred: Callable, limit: float, each: Callable = Callable()) -> bool:
	var t: float = 0.0
	while t < limit:
		if pred.call():
			return true
		if each.is_valid():
			each.call()
		_tick(w, STEP)
		t += STEP
	return bool(pred.call())


func _tick(w: Dictionary, sec: float) -> void:
	var left: float = sec
	while left > 0.000001:
		var d: float = minf(STEP, left)
		(w["status"] as StatusEffects).tick(d, w["state"] as CombatState)
		(w["mover"] as UnitMover).tick(d)
		(w["ctrl"] as PatternController).tick(d)
		left -= d


func _events(w: Dictionary, skill: String, event: String = "resolve") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in (w["ctrl"] as PatternController).event_log:
		if str(ev.get("skill", "")) == skill and str(ev.get("event", "")) == event:
			out.append(ev)
	return out


func test_rootling_root_prick_roots_0_7_sec() -> void:
	var w: Dictionary = Fx.world(Fx.arena("square"), cfg, "rootling", 3, 80.0)
	var status: StatusEffects = w["status"]
	var hit: bool = _until(w, func() -> bool: return _events(w, "root_prick").any(func(e: Dictionary) -> bool: return bool(e["hit"])), 10.0)
	_check("root_prick hits a standing player", hit)
	_check("root_prick roots the player for 0.7 s (D2)", status.is_rooted(P) and status.get_root_left(P) > 0.6 and status.get_root_left(P) <= 0.7 + 0.0001,
		"left=%.3f" % status.get_root_left(P))
	var dmg: float = 100.0 - (w["state"] as CombatState).player_hp
	_check("root_prick deals 8", is_equal_approx(dmg, 8.0), "dmg=%.1f" % dmg)
	var state: CombatState = w["state"]
	var dir: Vector2i = Vector2i(1, 0) if state.grid.is_player_cell(state.player_cell + Vector2i(1, 0)) else Vector2i(-1, 0)
	_check("rooted: a step is refused", not (w["mover"] as UnitMover).try_step(dir))
	_tick(w, 0.75)
	_check("after 0.7 s the root is gone", not status.is_rooted(P))


func test_rootling_creep_needs_aim_and_moves_to_shown_cell() -> void:
	var w: Dictionary = Fx.world(Fx.arena("square"), cfg, "rootling", 5, 80.0)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_tick(w, 15.0)
	_check("creep never fires without a block aimed at the Rootling", _events(w, "creep").is_empty())
	var aim: Callable = func() -> void: ctrl.on_player_aim([state.enemy_cell] as Array[Vector2i])
	var winding: bool = _until(w, func() -> bool:
		return ctrl.get_stage() == PatternController.Stage.WINDUP and str(ctrl.get_current_skill().get("id", "")) == "creep", 30.0, aim)
	_check("creep fires right after a block is aimed at the Rootling", winding)
	var from: Vector2i = state.enemy_cell
	var target: Vector2i = ctrl.move_target_cell()
	_check("creep shows its target one row up / down (ivory, not red)", target != BoardGrid.NO_CELL and target.x == from.x
		and absi(target.y - from.y) == 1 and state.grid.is_enemy_cell(target) and ctrl.telegraph_cells().is_empty(), "%s -> %s" % [from, target])
	_until(w, func() -> bool: return ctrl.get_stage() != PatternController.Stage.WINDUP, 2.0)
	_check("the Rootling ends on the shown cell", state.enemy_cell == target, "%s" % state.enemy_cell)
	var aimed_off: Dictionary = Fx.world(Fx.arena("square"), cfg, "rootling", 5, 80.0)
	var other: Vector2i = (aimed_off["state"] as CombatState).enemy_cell + Vector2i(0, 1)
	var miss_aim: Callable = func() -> void: (aimed_off["ctrl"] as PatternController).on_player_aim([other] as Array[Vector2i])
	_until(aimed_off, func() -> bool: return false, 20.0, miss_aim)
	_check("a block aimed elsewhere does not trigger creep", _events(aimed_off, "creep").is_empty())


func test_sentry_brace_guards_3_for_3_sec() -> void:
	var w: Dictionary = Fx.world(Fx.arena("rect"), cfg, "mossbound_sentry", 2, 110.0)
	var status: StatusEffects = w["status"]
	var braced: bool = _until(w, func() -> bool: return not _events(w, "brace").is_empty(), 20.0)
	_check("brace is used", braced)
	_check("brace = Guard +3 for 3 s (D5)", is_equal_approx(status.get_guard_left(E), 3.0) or (status.get_guard_left(E) > 2.9 and status.get_guard_left(E) <= 3.0),
		"left=%.2f" % status.get_guard_left(E))
	_tick(w, 3.1)
	_check("Guard ends after 3 s", status.get_guard_left(E) <= 0.0)


func test_sporeling_seedbed_leaves_thorns_next_to_player() -> void:
	var w: Dictionary = Fx.world(Fx.arena("square"), cfg, "greycap_sporeling", 4, 90.0)
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	var seeded: bool = _until(w, func() -> bool: return not _events(w, "seedbed").is_empty(), 30.0)
	_check("seedbed is used", seeded)
	if not seeded:
		return
	var ev: Dictionary = _events(w, "seedbed")[0]
	var cell: Vector2i = (ev["cells"] as Array)[0] if not (ev["cells"] as Array).is_empty() else BoardGrid.NO_CELL
	_check("seedbed lands next to the player, never on it", cell != state.player_cell and absi(cell.x - state.player_cell.x) + absi(cell.y - state.player_cell.y) == 1,
		"%s vs %s" % [cell, state.player_cell])
	_check("seedbed leaves Thorns (D3: no Poison in Phase 2)", not status.thorns_at(P, cell).is_empty())
	_check("seedbed strike itself deals no damage", is_equal_approx(float(ev["damage"]), 0.0))


func test_sentinel_anchor_two_cell_break_stuns_and_cancels_followup() -> void:
	var w: Dictionary = Fx.world(Fx.arena("rect"), cfg, "ancient_root_sentinel", 1, 165.0)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var stuns: Array[float] = []
	ctrl.stunned.connect(func(sec: float) -> void: stuns.append(sec))
	var waiting: bool = _until(w, func() -> bool: return ctrl.get_stage() == PatternController.Stage.FOLLOWUP_WAIT, 40.0)
	_check("branch_net resolves with an anchor and waits for its repeat", waiting and str(ctrl.get_current_skill().get("id", "")) == "branch_net")
	if not waiting:
		return
	var marks: Array[Vector2i] = ctrl.marker_cells()
	_check("an anchor stands on the Sentinel's half", marks.size() == 1 and state.grid.is_enemy_cell(marks[0]))
	var anchor: Vector2i = marks[0]
	ctrl.on_player_cast([anchor] as Array[Vector2i])
	_check("a 1-cell block does not break the anchor (break_min_cells 2)", ctrl.marker_cells().has(anchor) and stuns.is_empty())
	var other: Vector2i = BoardGrid.NO_CELL
	for c: Vector2i in state.grid.enemy_cells():
		if c != anchor:
			other = c
			break
	var repeats_before: int = _events(w, "branch_net").filter(func(e: Dictionary) -> bool: return bool(e["followup_strike"])).size()
	ctrl.on_player_cast([anchor, other] as Array[Vector2i])
	_check("a 2-cell block breaks the anchor", ctrl.marker_cells().is_empty())
	_check("breaking the anchor stuns the Sentinel 1.0 s", stuns.size() == 1 and is_equal_approx(stuns[0], 1.0) and ctrl.get_stage() == PatternController.Stage.STUNNED and ctrl.is_busy(), str(stuns))
	_check("the repeat is cancelled at once", ctrl.get_current_skill().is_empty() and ctrl.telegraph_cells().is_empty())
	_tick(w, 0.95)
	_check("still stunned at 0.95 s", ctrl.get_stage() == PatternController.Stage.STUNNED)
	_tick(w, 0.1)
	_check("stun over after 1.0 s", ctrl.get_stage() != PatternController.Stage.STUNNED)
	_tick(w, 3.0)
	var repeats_after: int = _events(w, "branch_net").filter(func(e: Dictionary) -> bool: return bool(e["followup_strike"])).size()
	_check("the cancelled repeat never strikes", repeats_after == repeats_before, "%d -> %d" % [repeats_before, repeats_after])
	# Stun during the repeat's own warning cancels it too.
	var w2: Dictionary = Fx.world(Fx.arena("rect"), cfg, "ancient_root_sentinel", 1, 165.0)
	var c2: PatternController = w2["ctrl"]
	var in_repeat: bool = _until(w2, func() -> bool:
		return c2.get_stage() == PatternController.Stage.WARNING and str(c2.get_current_skill().get("id", "")) == "branch_net" \
			and _events(w2, "branch_net").size() > 0 and float(_events(w2, "branch_net").back()["t"]) > 0.0 \
			and c2.event_log.back().get("skill", "") == "branch_net" and not bool(c2.event_log.back().get("followup_strike", true)), 40.0)
	_check("branch_net repeat warning reached", in_repeat)
	if in_repeat:
		var a2: Vector2i = c2.marker_cells()[0]
		var o2: Vector2i = a2 + Vector2i(0, 1) if (w2["state"] as CombatState).grid.is_enemy_cell(a2 + Vector2i(0, 1)) else a2 + Vector2i(0, -1)
		c2.on_player_cast([a2, o2] as Array[Vector2i])
		_check("anchor broken during the repeat warning: red off, stunned", c2.telegraph_cells().is_empty() and c2.get_stage() == PatternController.Stage.STUNNED)


func test_sentinel_anchor_prefers_player_row() -> void:
	_check("sentinel_anchor data: pattern.row = player", str(cfg.skills["sentinel_anchor"]["pattern"].get("row", "")) == "player")
	# Through the controller: the player stands in each row of the rect arena in turn (never moves); the anchor lands
	# on the Sentinel's half in that row, on a seeded random column.
	var in_row: bool = true
	var placed: int = 0
	var columns: Dictionary = {}
	for s: int in 24:
		var w: Dictionary = Fx.world(Fx.arena("rect"), cfg, "ancient_root_sentinel", 100 + s, 420.0)
		var state: CombatState = w["state"]
		var row: int = s % state.grid.rows
		var target: Vector2i = BoardGrid.NO_CELL
		for c: Vector2i in state.grid.player_cells():
			if c.y == row and target == BoardGrid.NO_CELL:
				target = c
		state.set_player_cell(target)
		if not _until(w, func() -> bool: return not _events(w, "sentinel_anchor").is_empty(), 30.0):
			continue
		placed += 1
		var cell: Vector2i = (_events(w, "sentinel_anchor")[0]["cells"] as Array)[0]
		in_row = in_row and cell.y == state.player_cell.y and state.grid.is_enemy_cell(cell)
		columns[cell.x] = true
	_check("sentinel_anchor placed in 24 seeded matches", placed == 24, str(placed))
	_check("the anchor lands in the player's current row (every row, 24 seeds)", in_row)
	_check("the anchor's column is drawn, not fixed (>= 2 columns seen)", columns.size() >= 2, str(columns.keys()))
	# Through the planner: only player-row cells while one is free; every empty cell when the row has none.
	var grid: BoardGrid = Fx.arena("rect")
	var skill: Dictionary = cfg.skills["sentinel_anchor"]
	var enemy: Vector2i = grid.enemy_cells()[0]
	var player: Vector2i = BoardGrid.NO_CELL
	for c: Vector2i in grid.player_cells():
		if c.y == 1 and player == BoardGrid.NO_CELL:
			player = c
	var ctx: Dictionary = {"grid": grid, "player_cell": player, "enemy_cell": enemy, "markers": [] as Array[Vector2i]}
	var plans: Array[Dictionary] = PatternPlanner.plans(skill, ctx)
	var row_only: bool = not plans.is_empty()
	for p: Dictionary in plans:
		row_only = row_only and (p["anchor"] as Vector2i).y == 1
	_check("planner: row player -> only the player's row", row_only, str(plans.size()))
	var blocked: Dictionary = ctx.duplicate()
	blocked["cell_ok_fn"] = func(c: Vector2i) -> bool: return c.y != 1
	var fallback: Array[Dictionary] = PatternPlanner.plans(skill, blocked)
	var free_cells: int = 0
	for c: Vector2i in grid.enemy_cells():
		if c != enemy and c.y != 1:
			free_cells += 1
	_check("planner: no free cell in the player's row -> any empty cell (old rule)", fallback.size() == free_cells and free_cells > 0,
		"%d vs %d" % [fallback.size(), free_cells])
	var bad: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"version": 1, "skills": {"bad_row": {"kind": "marker",
		"pattern": {"anchor": "enemy_half_empty", "row": "diagonal"}, "windup_sec": 0.6, "delivery": Fx.DM,
		"effects": {"marker": {"life_sec": 5.0}}, "cooldown_sec": 5.0}}, "enemies": {}})
	_check("an unknown pattern.row refuses the skill with a problem line", not bad.skills.has("bad_row")
		and JSON.stringify(bad.problems).contains("pattern.row"), str(bad.problems))


func test_sentinel_bark_shift_is_a_drop_tile() -> void:
	var w: Dictionary = Fx.world(Fx.arena("rect"), cfg, "ancient_root_sentinel", 7, 165.0)
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	var ok: bool = _until(w, func() -> bool: return not _events(w, "bark_shift").is_empty(), 40.0)
	_check("bark_shift is used", ok)
	if not ok:
		return
	var cell: Vector2i = (_events(w, "bark_shift")[0]["cells"] as Array)[0]
	_check("bark_shift cracks a cell next to the player (drop tile, D6)", status.is_cracking(P, cell) and cell != state.player_cell, str(cell))
	_check("no Thorns from bark_shift (barrier became a drop tile)", status.thorns_at(P, cell).is_empty())


func _interior_player_cell(grid: BoardGrid) -> Vector2i:
	for c: Vector2i in grid.player_cells():
		var all_in: bool = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			all_in = all_in and grid.is_player_cell(c + d)
		if all_in:
			return c
	return BoardGrid.NO_CELL


func _fork_followup(seed_value: int, step_dir: Vector2i) -> Dictionary:
	var w: Dictionary = Fx.world(Fx.arena("cross"), cfg, "mistbriar_matron", seed_value, 155.0)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var c0: Vector2i = _interior_player_cell(state.grid)
	state.set_player_cell(c0)
	var warnings: Array[Array] = []
	ctrl.warning_started.connect(func(id: String, cells: Array[Vector2i], _q: Array[Vector2i], _s: float) -> void:
		if id == "thorn_fork":
			warnings.append(cells))
	_until(w, func() -> bool: return warnings.size() >= 1, 20.0)
	var first: Array = warnings[0] if not warnings.is_empty() else []
	state.set_player_cell(c0 + step_dir)
	_until(w, func() -> bool: return warnings.size() >= 2, 3.0)
	return {"first": first, "second": warnings[1] if warnings.size() >= 2 else [], "c0": c0}


func test_matron_fork_followup_follows_the_step_axis() -> void:
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var r: Dictionary = _fork_followup(2, dir)
		var c0: Vector2i = r["c0"]
		var second: Array = r["second"]
		var axis: Array = [c0 + dir, c0 - dir]
		_check("thorn_fork first red = the player's cell", r["first"] == [c0])
		var same_axis: bool = second.size() == 2 and second.has(axis[0]) and second.has(axis[1])
		_check("fork followup = both cells next to the first on the axis stepped along %s" % dir, same_axis, "%s" % [second])


func test_matron_wreath_guard_below_half_once_breaks_with_one_cell() -> void:
	var w: Dictionary = Fx.world(Fx.arena("cross"), cfg, "mistbriar_matron", 3, 155.0)
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_tick(w, 10.0)
	_check("wreath_guard not used above 50 % HP", _events(w, "wreath_guard").is_empty())
	state.enemy_hp = state.enemy_max_hp * 0.45
	var placed: bool = _until(w, func() -> bool: return not _events(w, "wreath_guard").is_empty(), 15.0)
	_check("wreath_guard used at <= 50 % HP", placed)
	if not placed:
		return
	var marks: Array[Dictionary] = ctrl.markers()
	_check("one wreath on the Matron's half, Guard +5 up (D5)", marks.size() == 1 and str(marks[0]["kind"]) == "wreath" and status.get_guard_left(E) > 0.0)
	ctrl.on_player_cast([marks[0]["cell"]] as Array[Vector2i])
	_tick(w, STEP)
	_check("a 1-cell block breaks the wreath and the Guard drops, no stun", ctrl.marker_cells().is_empty() and status.get_guard_left(E) <= 0.0
		and ctrl.get_stage() != PatternController.Stage.STUNNED)
	_tick(w, 20.0)
	_check("wreath_guard is once per match", _events(w, "wreath_guard").size() == 1)


func test_data_roster_pools_and_strings() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chapters.json"))
	var ch1: Dictionary = {}
	for chapter: Variant in data["chapters"]:
		if str((chapter as Dictionary).get("id", "")) == "ch1":
			ch1 = chapter
	var matches: Dictionary = ch1["matches"]
	var witch: Dictionary = matches["forest_witch"]
	var witch_traits: Array = witch.get("traits", [])
	_check("Forest Witch has no rotten_thrower (D12)", not JSON.stringify(witch_traits).contains("rotten_thrower"))
	var boss: Dictionary = ch1["pools"]["boss"]
	_check("boss pool: tier 1 goblin_warlock, tier 2 forest_witch (D11)", boss["1"] == ["goblin_warlock"] and boss["2"] == ["forest_witch"], str(boss))
	for id: String in NEW_ENEMIES:
		var m: Dictionary = matches.get(id, {})
		var enemy: Dictionary = cfg.get_enemy(id)
		_check("%s: a ch1 match on the pattern brain with its own enemy" % id, str(m.get("brain", "")) == "pattern" and str(m.get("enemy", "")) == id
			and not enemy.is_empty() and not bool(enemy.get("dev", true)))
	_check("Sentinel teach_after rootling + mossbound_sentry (D10)", matches["ancient_root_sentinel"].get("teach_after", []) == ["rootling", "mossbound_sentry"])
	_check("Matron teach_after greycap_sporeling + rootling (D10)", matches["mistbriar_matron"].get("teach_after", []) == ["greycap_sporeling", "rootling"])
	var hp: Dictionary = {"rootling": 190, "mossbound_sentry": 250, "greycap_sporeling": 220, "ancient_root_sentinel": 420, "mistbriar_matron": 400}
	var hp_ok: bool = true
	for id: String in hp:
		hp_ok = hp_ok and int(matches[id]["boss_max_hp"]) == int(hp[id])
	_check("authored HP = pack budget at the floor-3 reference (spec 5.1, D8)", hp_ok)
	var keys: Dictionary = {}
	for line: String in FileAccess.get_file_as_string("res://assets/i18n/strings.csv").split("\n"):
		keys[line.get_slice(",", 0)] = true
	var missing: Array[String] = []
	for id: String in NEW_ENEMIES:
		if not keys.has("boss.%s.name" % id):
			missing.append("boss.%s.name" % id)
		for phase: Dictionary in cfg.get_enemy(id)["phases"]:
			for sid: String in phase["skills"]:
				var skill: Dictionary = cfg.skills[sid]
				for k: String in [str(skill.get("name_key", "")), str(skill.get("counter_key", ""))]:
					if k.is_empty() or not keys.has(k):
						missing.append("%s:%s" % [sid, k])
	_check("every new enemy and skill has its name / counter strings", missing.is_empty(), str(missing))

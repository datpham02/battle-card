extends SceneTree
## P2.2b (decision D13 / ADR-0001 A7): multi-cell boss footprints. Covers the CombatState footprint helpers and fit rules
## (edge of the half, missing cell, hole via a blocker, the divider, default anchor, refused footprint), the data
## (enemy_skills.json dev_pattern_boss, a bad footprint refused, arenas.json boss_hall boss-only), the boss's mover
## (whole destination footprint checked), HIT ONCE (a card / a SEQUENTIAL_CHAIN card covering all 4 cells of a 2x2 boss
## deals the single-hit damage; a fire zone over 2 footprint cells ticks once; two zones tick twice; a step onto 2 thorn
## cells pays one toll), Hunter mark and Vay Bat with a 2x2 boss, a drop crack under a non-anchor footprint cell, the
## planner's footprint-aware anchors and the cast origin; and that a 1-cell enemy gives the pre-P2.2b answers.
## Pure logic (the shipped data files are read for the data checks only).
## Run: godot --headless --path . -s res://tests/unit/combat/boss_footprint_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const SQUARE_2X2: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
## 6x4 per side (boss_hall): the 2x2 boss's default anchor is the middle of the enemy half (cols 6..11, rows 0..3).
const HALL_ANCHOR: Vector2i = Vector2i(8, 1)
const BOSS_HP: float = 500.0

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_helpers_and_fit_rules()
	test_one_cell_unchanged()
	test_data()
	test_mover_checks_whole_footprint()
	test_card_hits_once()
	test_burn_zone_ticks_once_per_zone()
	test_thorn_entry_toll_once()
	test_hunter_mark_and_vay_bat()
	test_drop_crack_under_footprint()
	test_planner_and_origin()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _hall() -> BoardGrid:
	return BoardGrid.new(6, 4)


func _boss(grid: BoardGrid = null) -> CombatState:
	var state := CombatState.new(grid if grid != null else _hall(), 100.0, BOSS_HP)
	state.set_enemy_footprint(SQUARE_2X2)
	return state


func test_helpers_and_fit_rules() -> void:
	var s: CombatState = _boss()
	_check("normalize: shifted to top-left, sorted, deduped",
		CombatState.normalize_footprint([Vector2i(3, 2), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 2)] as Array[Vector2i]) == SQUARE_2X2)
	_check("normalize: empty = 1 cell", CombatState.normalize_footprint([] as Array[Vector2i]) == ([Vector2i.ZERO] as Array[Vector2i]))
	_check("default anchor = centre of the 6x4 half", s.enemy_cell == HALL_ANCHOR, str(s.enemy_cell))
	_check("4 footprint cells", s.enemy_footprint_size() == 4 and s.enemy_footprint_cells() == ([Vector2i(8, 1), Vector2i(9, 1), Vector2i(8, 2), Vector2i(9, 2)] as Array[Vector2i]),
		str(s.enemy_footprint_cells()))
	_check("is_enemy_at every footprint cell, not a neighbour", s.is_enemy_at(Vector2i(9, 2)) and s.is_enemy_at(Vector2i(8, 1)) and not s.is_enemy_at(Vector2i(10, 1)) and not s.is_enemy_at(Vector2i(7, 1)))
	_check("enemy_in: any footprint cell", s.enemy_in([Vector2i(9, 2)]) and not s.enemy_in([Vector2i(10, 2), Vector2i(7, 1)]))
	_check("unit_at / unit_in mirror the enemy helpers", s.unit_at(E, Vector2i(9, 1)) and s.unit_in(E, [Vector2i(0, 0), Vector2i(8, 2)]) and not s.unit_at(P, Vector2i(9, 1)))
	# Edge of the half: the right edge is col 11, the bottom row 3.
	_check("fits: anchor (10, 2) touches the corner", s.enemy_fits(Vector2i(10, 2)))
	_check("edge: anchor (11, 0) would cross the right edge", not s.enemy_fits(Vector2i(11, 0)))
	_check("edge: anchor (8, 3) would cross the bottom", not s.enemy_fits(Vector2i(8, 3)))
	# Divider: col 5 is the player's half.
	_check("divider: anchor (5, 1) refused", not s.enemy_fits(Vector2i(5, 1)))
	_check("divider: anchor (6, 1) fits", s.enemy_fits(Vector2i(6, 1)))
	# Missing cell: side (0, 0) = board (11, 0) on the boss half.
	var holed: CombatState = _boss(BoardGrid.new(6, 4, [Vector2i(0, 0)] as Array[Vector2i]))
	_check("missing cell: anchor (10, 0) covers the hole (11, 0)", not holed.enemy_fits(Vector2i(10, 0)) and holed.enemy_fits(Vector2i(9, 0)))
	# Hole / blocked cell through the blocker callable.
	var hole := func(c: Vector2i) -> bool: return c == Vector2i(9, 2)
	_check("hole: a blocked footprint cell refuses the anchor", not s.enemy_fits(HALL_ANCHOR, hole) and s.enemy_fits(Vector2i(10, 0), hole))
	_check("set_enemy_cell refuses a non-fitting anchor", not s.set_enemy_cell(Vector2i(11, 1)) and s.enemy_cell == HALL_ANCHOR)
	_check("set_enemy_cell accepts a fitting anchor", s.set_enemy_cell(Vector2i(10, 2)) and s.enemy_cell == Vector2i(10, 2))
	# A footprint that fits nowhere is refused.
	var small := CombatState.new(BoardGrid.new(3, 3), 100.0, BOSS_HP)
	var wide: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	_check("4-wide footprint on a 3-col half: refused, 1 cell kept", not small.set_enemy_footprint(wide) and small.enemy_footprint_size() == 1)
	# Setting a footprint moves a non-fitting anchor to the default.
	var moved := CombatState.new(_hall(), 100.0, BOSS_HP, BoardGrid.NO_CELL, Vector2i(11, 3))
	moved.set_enemy_footprint(SQUARE_2X2)
	_check("footprint set on a corner anchor: moved to the default", moved.enemy_cell == HALL_ANCHOR, str(moved.enemy_cell))


func test_one_cell_unchanged() -> void:
	var grids: Array[BoardGrid] = [BoardGrid.new(3, 3), Fx.arena("rect"), Fx.arena("cross"), Fx.arena("staircase"), BoardGrid.new(6, 4)]
	var all_same: bool = true
	for grid: BoardGrid in grids:
		var s := CombatState.new(grid)
		all_same = all_same and s.enemy_footprint_size() == 1 and s.default_enemy_anchor() == grid.default_enemy_cell()
		for col: int in range(-1, grid.total_cols + 1):
			for row: int in range(-1, grid.rows + 1):
				var c := Vector2i(col, row)
				all_same = all_same and s.enemy_fits(c) == grid.is_enemy_cell(c)
		all_same = all_same and s.enemy_cast_origin() == s.enemy_cell and s.enemy_hit_cell([s.enemy_cell]) == s.enemy_cell
		all_same = all_same and s.enemy_in([s.enemy_cell]) and not s.enemy_in([s.player_cell])
		all_same = all_same and s.enemy_footprint_cells() == ([s.enemy_cell] as Array[Vector2i])
	_check("1-cell enemy: fits = is_enemy_cell, default anchor = default_enemy_cell, origin = hit cell = its cell", all_same)


func test_data() -> void:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	_check("shipped enemy_skills.json has no problems", cfg.problems.is_empty(), str(cfg.problems))
	var boss: Dictionary = cfg.get_enemy("dev_pattern_boss")
	_check("dev_pattern_boss: dev, boss tier, arena hint", bool(boss.get("dev", false)) and str(boss.get("tier", "")) == "boss" and str(boss.get("arena", "")) == "boss_hall")
	_check("dev_pattern_boss: 2x2 footprint", (boss.get("footprint", []) as Array) == SQUARE_2X2)
	_check("dev_pattern_dummy: still 1 cell", (cfg.get_enemy("dev_pattern_dummy").get("footprint", []) as Array) == [Vector2i.ZERO])
	var bad: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": Fx.skills(), "enemies": {
		"neg": {"skills": ["fx_1"], "footprint": [[0, 0], [-1, 0]]},
		"no_anchor": {"skills": ["fx_1"], "footprint": [[1, 0], [1, 1]]}}})
	_check("bad footprints refused to 1 cell with problem lines",
		(bad.get_enemy("neg")["footprint"] as Array).size() == 1 and (bad.get_enemy("no_anchor")["footprint"] as Array).size() == 1
		and bad.problems.size() >= 2, str(bad.problems))
	var lib: ArenaLibrary = ArenaLibrary.load_from_file()
	var hall: Dictionary = lib.get_shape("boss_hall")
	_check("boss_hall loads (6x4, no holes, boss_only)", not hall.is_empty() and int(hall["side_cols"]) == 6 and int(hall["side_rows"]) == 4
		and (hall["missing_cells"] as Array).is_empty() and lib.is_boss_only("boss_hall"))
	_check("boss_hall left out of shape_ids() and the difficulty pools", not lib.shape_ids().has("boss_hall") and lib.shape_ids(true).has("boss_hall")
		and lib.shapes_with_difficulty(5).filter(func(sh: Dictionary) -> bool: return str(sh["id"]) == "boss_hall").is_empty())
	var grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "boss_hall"}, lib, 1)
	_check("boss_hall builds a 6x4 board", grid != null and grid.side_cols == 6 and grid.side_rows == 4 and grid.enemy_cells().size() == 24)
	var chapters: String = FileAccess.get_file_as_string("res://assets/data/chapters.json")
	_check("no chapters.json match or pool names boss_hall / dev_pattern_boss", not chapters.contains("boss_hall") and not chapters.contains("dev_pattern_boss"))
	var w: Dictionary = Fx.world(grid, cfg, "dev_pattern_boss", 1)
	var st: CombatState = w["state"]
	_check("PatternController applies the footprint from data", st.enemy_footprint_size() == 4 and st.enemy_cell == HALL_ANCHOR, str(st.enemy_cell))


func test_mover_checks_whole_footprint() -> void:
	var s: CombatState = _boss()
	var mover := UnitMover.new(s, E, 0.0)
	mover.add_blocker(func(c: Vector2i) -> bool: return c == Vector2i(10, 2))
	_check("step right refused: a destination footprint cell is blocked", not mover.try_step(Vector2i(1, 0)) and s.enemy_cell == HALL_ANCHOR)
	_check("step down accepted: the whole footprint fits", mover.try_step(Vector2i(0, 1)) and s.enemy_cell == Vector2i(8, 2))
	_check("step down again refused: the footprint would leave the board", not mover.try_step(Vector2i(0, 1)) and s.enemy_cell == Vector2i(8, 2))
	_check("step left to the divider column accepted", mover.try_step(Vector2i(-1, 0)) and mover.try_step(Vector2i(-1, 0)) and s.enemy_cell == Vector2i(6, 2))
	_check("step across the divider refused", not mover.try_step(Vector2i(-1, 0)) and s.enemy_cell == Vector2i(6, 2))


# Damage of [param skill_id] cast by the player on [param cells] against [param state]; returns [result, hp lost].
func _cast(state: CombatState, cells: Array[Vector2i], skill_id: String, status: StatusEffects = null) -> Array:
	var before: float = state.enemy_hp
	var result: Dictionary = CutEffects.apply(state, state.grid, P, cells, skill_id, CutConfig.load_from_file(), SkillConfig.load_from_file(), status)
	return [result, before - state.enemy_hp]


func test_card_hits_once() -> void:
	var cells: Array[Vector2i] = [Vector2i(8, 1), Vector2i(9, 1), Vector2i(8, 2), Vector2i(9, 2), Vector2i(7, 1)]
	for skill_id: String in ["dai_dao", SkillConfig.FALLBACK_SKILL]:
		var boss: CombatState = _boss()
		var one := CombatState.new(_hall(), 100.0, BOSS_HP, BoardGrid.NO_CELL, Vector2i(9, 2))
		var big: Array = _cast(boss, cells, skill_id)
		var small: Array = _cast(one, cells, skill_id)
		var r: Dictionary = big[0]
		_check("%s over all 4 footprint cells: one hit, damage = the 1-cell damage" % skill_id,
			bool(r["hit"]) and float(big[1]) > 0.0 and is_equal_approx(float(big[1]), float(small[1])) and is_equal_approx(float(r["damage"]), float(big[1])),
			"2x2 lost %s, 1-cell lost %s" % [big[1], small[1]])
		_check("%s: hit drawn on a covered footprint cell" % skill_id, boss.is_enemy_at(r["cell"] as Vector2i), str(r["cell"]))
	var chain: Dictionary = SkillConfig.load_from_file().get_skill("dai_dao").get("delivery", {}) as Dictionary
	_check("dai_dao is a SEQUENTIAL_CHAIN card", str(chain.get("type", "")) == SkillDelivery.SEQUENTIAL_CHAIN)
	var corner: CombatState = _boss()
	var r2: Array = _cast(corner, [Vector2i(9, 2), Vector2i(10, 2), Vector2i(10, 3)] as Array[Vector2i], SkillConfig.FALLBACK_SKILL)
	_check("a cast touching one footprint cell hits", bool((r2[0] as Dictionary)["hit"]) and float(r2[1]) > 0.0)
	var miss: CombatState = _boss()
	var r3: Array = _cast(miss, [Vector2i(10, 1), Vector2i(10, 2), Vector2i(7, 0)] as Array[Vector2i], SkillConfig.FALLBACK_SKILL)
	_check("a cast beside the footprint misses", not bool((r3[0] as Dictionary)["hit"]) and is_zero_approx(float(r3[1])))


func test_burn_zone_ticks_once_per_zone() -> void:
	var tick: float = 0.5
	var dmg: float = 3.0
	var s: CombatState = _boss()
	var st := StatusEffects.new()
	st.ignite([Vector2i(8, 1), Vector2i(9, 1), Vector2i(10, 1)] as Array[Vector2i], 5.0, tick, dmg)
	st.tick(tick, s)
	_check("one fire zone over 2 footprint cells: one tick of damage", is_equal_approx(BOSS_HP - s.enemy_hp, dmg), str(BOSS_HP - s.enemy_hp))
	st.tick(tick, s)
	_check("...and one per tick after", is_equal_approx(BOSS_HP - s.enemy_hp, dmg * 2.0), str(BOSS_HP - s.enemy_hp))
	var s2: CombatState = _boss()
	var st2 := StatusEffects.new()
	st2.ignite([Vector2i(8, 1)] as Array[Vector2i], 5.0, tick, dmg)
	st2.ignite([Vector2i(9, 2)] as Array[Vector2i], 5.0, tick, dmg)
	st2.tick(tick, s2)
	_check("two fire zones on 2 footprint cells: one tick each", is_equal_approx(BOSS_HP - s2.enemy_hp, dmg * 2.0), str(BOSS_HP - s2.enemy_hp))
	var s1 := CombatState.new(_hall(), 100.0, BOSS_HP, BoardGrid.NO_CELL, Vector2i(8, 1))
	var st1 := StatusEffects.new()
	st1.ignite([Vector2i(8, 1), Vector2i(9, 1)] as Array[Vector2i], 5.0, tick, dmg)
	st1.tick(tick, s1)
	_check("1-cell enemy on a fire: one tick (unchanged)", is_equal_approx(BOSS_HP - s1.enemy_hp, dmg))


func test_thorn_entry_toll_once() -> void:
	var s: CombatState = _boss()
	var st := StatusEffects.new()
	var toll: float = 6.0
	st.tick(0.0, s)
	ZoneRules.cast_thorns(st, E, [Vector2i(10, 1), Vector2i(10, 2)] as Array[Vector2i], 5.0, toll, 0)
	var entries: Array[int] = [0]
	st.thorn_entered.connect(func(_side: int, _cell: Vector2i, _d: float) -> void: entries[0] += 1)
	s.set_enemy_cell(Vector2i(9, 1))
	st.tick(0.05, s)
	_check("step onto 2 thorn cells: one toll", is_equal_approx(BOSS_HP - s.enemy_hp, toll) and entries[0] == 1, "lost %s entries %d" % [BOSS_HP - s.enemy_hp, entries[0]])
	s.set_enemy_cell(Vector2i(9, 2))
	st.tick(0.05, s)
	_check("step down still on thorns, (10, 3) has none: no toll", is_equal_approx(BOSS_HP - s.enemy_hp, toll), str(BOSS_HP - s.enemy_hp))


func test_hunter_mark_and_vay_bat() -> void:
	var s: CombatState = _boss()
	var st := StatusEffects.new()
	var mark: HunterMarkPassive = PassiveRegistry.create("hunter_mark") as HunterMarkPassive
	mark.setup({"status": st, "grid": s.grid, "state": s}, {"fragile_stacks": 1, "icd_sec": 0.0})
	# (10, 2) is next to footprint cell (9, 2) only: 3 steps from the anchor.
	mark.on_player_zone_formed(StatusEffects.KIND_THORNS, [Vector2i(10, 2), Vector2i(11, 2)] as Array[Vector2i])
	_check("Hunter mark: thorns beside a non-anchor footprint cell mark once", mark.marks_given() == 1 and st.fragile_stacks(E) == 1)
	var far: HunterMarkPassive = PassiveRegistry.create("hunter_mark") as HunterMarkPassive
	far.setup({"status": StatusEffects.new(), "grid": s.grid, "state": s}, {"fragile_stacks": 1, "icd_sec": 0.0})
	far.on_player_zone_formed(StatusEffects.KIND_THORNS, [Vector2i(11, 0), Vector2i(6, 3)] as Array[Vector2i])
	_check("Hunter mark: thorns 2+ cells from every footprint cell do not mark", far.marks_given() == 0)
	var on: HunterMarkPassive = PassiveRegistry.create("hunter_mark") as HunterMarkPassive
	on.setup({"status": StatusEffects.new(), "grid": s.grid, "state": s}, {"fragile_stacks": 1, "icd_sec": 0.0})
	on.on_player_zone_formed(StatusEffects.KIND_THORNS, [Vector2i(9, 2), Vector2i(8, 2)] as Array[Vector2i])
	_check("Hunter mark: thorns ON 2 footprint cells mark once", on.marks_given() == 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var extra: Array[Vector2i] = CutEffects.extra_thorn_cells(s, s.grid, st, E, [Vector2i(7, 1), Vector2i(8, 0), Vector2i(10, 1)] as Array[Vector2i], 20, Callable(), rng)
	var clean: bool = not extra.is_empty()
	for c: Vector2i in extra:
		clean = clean and not s.is_enemy_at(c)
	var want: Array[Vector2i] = [Vector2i(6, 1), Vector2i(7, 0), Vector2i(7, 2), Vector2i(9, 0), Vector2i(10, 0), Vector2i(10, 2), Vector2i(11, 1)]
	var got: Array[Vector2i] = extra.duplicate()
	got.sort()
	_check("Vay Bat: extra thorn cells exclude every footprint cell", clean and got == want, str(got))


func test_drop_crack_under_footprint() -> void:
	var s: CombatState = _boss()
	var st := StatusEffects.new()
	st.apply_drop(E, [Vector2i(9, 2)] as Array[Vector2i], 0.5, 1.0)
	st.tick(0.3, s)
	_check("crack under a footprint cell: alive during the warning", not s.is_enemy_dead())
	st.tick(0.3, s)
	_check("crack under a non-anchor footprint cell falls the boss (lethal rule, as a 1-cell boss)", s.is_enemy_dead())
	var s2: CombatState = _boss()
	var st2 := StatusEffects.new()
	st2.hole_fall_lethal = false
	st2.hole_fall_damage = 10.0
	st2.apply_drop(E, [Vector2i(8, 1), Vector2i(9, 2)] as Array[Vector2i], 0.2, 1.0)
	st2.tick(0.3, s2)
	_check("non-lethal: 2 cracks under the footprint = one fall, one damage", is_equal_approx(BOSS_HP - s2.enemy_hp, 10.0), str(BOSS_HP - s2.enemy_hp))
	var fits: bool = s2.enemy_fits(s2.enemy_cell, func(c: Vector2i) -> bool: return st2.is_hole(E, c))
	_check("non-lethal: lands on an anchor whose whole footprint is open", fits and s2.enemy_cell != HALL_ANCHOR, str(s2.enemy_cell))
	var cast: Array[Vector2i] = ZoneRules.cast_drop(_boss(), _hall(), StatusEffects.new(), E, [Vector2i(9, 2), Vector2i(10, 2)] as Array[Vector2i], 0.8, 1.2, false)
	_check("cast_drop with the unit's cell refused: no footprint cell cracks", cast == ([Vector2i(10, 2)] as Array[Vector2i]), str(cast))


func test_planner_and_origin() -> void:
	var s: CombatState = _boss()
	var ctx: Dictionary = {"grid": s.grid, "player_cell": s.player_cell, "enemy_cell": s.enemy_cell, "enemy_cells": s.enemy_footprint_cells()}
	var empty_plans: Array[Dictionary] = PatternPlanner.plans({"pattern": {"anchor": "enemy_half_empty"}}, ctx)
	var under: bool = false
	for plan: Dictionary in empty_plans:
		under = under or s.enemy_in(plan["cells"] as Array)
	_check("enemy_half_empty never under the footprint (24 - 4 cells)", empty_plans.size() == 20 and not under, str(empty_plans.size()))
	var self_plan: Array[Dictionary] = PatternPlanner.plans({"pattern": {"anchor": "self_cell"}}, ctx)
	_check("self_cell covers the footprint", self_plan.size() == 1 and (self_plan[0]["cells"] as Array).size() == 4)
	_check("cast origin = the upper front cell (nearest the divider)", s.enemy_cast_origin() == Vector2i(8, 1) and s.cast_origin(E) == Vector2i(8, 1))
	var tall: CombatState = CombatState.new(_hall(), 100.0, BOSS_HP)
	tall.set_enemy_footprint([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)] as Array[Vector2i])
	_check("3-tall footprint: origin = the front middle cell", tall.enemy_cast_origin() == tall.enemy_cell + Vector2i(0, 1), str(tall.enemy_cast_origin()))
	_check("hit cell: the covered cell nearest the centre", s.enemy_hit_cell([Vector2i(9, 2), Vector2i(10, 2)]) == Vector2i(9, 2)
		and s.enemy_hit_cell([Vector2i(0, 0)]) == s.enemy_cell)

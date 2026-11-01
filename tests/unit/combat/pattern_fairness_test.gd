extends SceneTree
## PatternPlanner (anchors, rotations, clip) and FairnessCheck (spec 4.1, F1-F10) of the phase 2 pattern brain.
## Covers: every anchor; rotation maths; clip / min_cells; locked cells drop plans (F7); 4.1 with step ready / just
## stepped / Rooted 0.5 s left / Slow / mire-like multiplier; red ceiling 50 % (3x3 -> 4, cross -> 6, F2); zone exit
## (F3); no Root+Frozen stacking + grace (F4); warning gap 0.4 s (F5); heavy recovery gap (F10); two sources leave a
## common safe cell (F8); Root / Slow / Guard statuses incl. Pierce vs Guard (D2 / D4 / D5).
## Pure logic: no file I/O.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_fairness_test.gd

const Fx = preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const MARGIN: float = 0.25

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_anchor_plans_cover_rules()
	test_rotation_and_clip()
	test_locked_cells_drop_plans()
	test_reach_formula_cases()
	test_red_ceiling()
	test_zone_exit_cc_gap_rules()
	test_root_slow_guard_statuses()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _ctx(grid: BoardGrid, player: Vector2i, markers: Array = [], ok_fn: Callable = Callable()) -> Dictionary:
	return {"grid": grid, "player_cell": player, "enemy_cell": grid.default_enemy_cell(), "markers": markers, "cell_ok_fn": ok_fn}


func test_anchor_plans_cover_rules() -> void:
	var c: EnemySkillsConfig = Fx.config()
	var g: BoardGrid = BoardGrid.new(3, 3)
	var centre: Vector2i = Vector2i(1, 1)
	var p1: Array[Dictionary] = PatternPlanner.plans(c.skills["fx_1"], _ctx(g, centre))
	_check("on_player: one plan on the player", p1.size() == 1 and p1[0]["cells"] == [centre])
	var p2: Array[Dictionary] = PatternPlanner.plans(c.skills["fx_2"], _ctx(g, centre))
	_check("bar 4 rotations from centre", p2.size() == 4)
	var all_cover: bool = true
	for p: Dictionary in p2:
		all_cover = all_cover and (p["cells"] as Array).has(centre)
	_check("every plan covers the player (must_cover_player)", all_cover)
	var p9: Array[Dictionary] = PatternPlanner.plans(c.skills["fx_9"], _ctx(Fx.arena("cross"), Vector2i(1, 1)))
	var near_ok: bool = not p9.is_empty()
	for p: Dictionary in p9:
		near_ok = near_ok and (p["cells"] as Array).has(Vector2i(1, 1)) and (p["anchor"] as Vector2i) != Vector2i(1, 1)
	_check("near_player: anchor next to player, T covers player", near_ok, str(p9.size()))
	var row_skill: Dictionary = c.skills["fx_5"]
	var pr: Array[Dictionary] = PatternPlanner.plans(row_skill, _ctx(g, Vector2i(0, 2), [Vector2i(4, 2)]))
	_check("row_of_anchor: front start, marker row", pr.size() == 1 and pr[0]["cells"] == [Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)])
	var pr2: Array[Dictionary] = PatternPlanner.plans(row_skill, _ctx(g, Vector2i(0, 1), []))
	_check("row_of_anchor without marker falls back to player row", pr2.size() == 1 and (pr2[0]["cells"] as Array).has(Vector2i(0, 1)) and int((pr2[0]["cells"] as Array)[0].y) == 1)
	var row_p: Dictionary = {"id": "r", "kind": "attack", "pattern": {"anchor": "row_of_player", "offsets": [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i],
		"rotations": [0], "must_cover_player": true, "clip": false, "min_cells": 2, "start": "any", "count": 1, "exclude_player": false}}
	var prp: Array[Dictionary] = PatternPlanner.plans(row_p, _ctx(Fx.arena("rect"), Vector2i(1, 0)))
	_check("row_of_player: windows containing the player", prp.size() == 2)
	var col_p: Dictionary = row_p.duplicate(true)
	(col_p["pattern"] as Dictionary)["anchor"] = "column_of_player"
	var pc: Array[Dictionary] = PatternPlanner.plans(col_p, _ctx(g, Vector2i(2, 0)))
	_check("column_of_player: vertical windows with the player", pc.size() == 1 and pc[0]["cells"] == [Vector2i(2, 0), Vector2i(2, 1)])
	var fixed: Dictionary = row_p.duplicate(true)
	(fixed["pattern"] as Dictionary)["anchor"] = "fixed"
	(fixed["pattern"] as Dictionary)["must_cover_player"] = false
	var pf: Array[Dictionary] = PatternPlanner.plans(fixed, _ctx(g, Vector2i(0, 0)))
	_check("fixed: absolute pattern coords, col 0 = front", pf.size() == 1 and pf[0]["cells"] == [Vector2i(2, 0), Vector2i(1, 0)])
	var pm: Array[Dictionary] = PatternPlanner.plans(c.skills["fx_4"], _ctx(g, centre, [Vector2i(3, 0)]))
	var marker_ok: bool = pm.size() == 9 - 2
	for p: Dictionary in pm:
		marker_ok = marker_ok and g.is_enemy_cell((p["cells"] as Array)[0]) and (p["cells"] as Array)[0] != g.default_enemy_cell()
	_check("enemy_half_empty: free enemy cells only", marker_ok, str(pm.size()))
	var ps: Array[Dictionary] = PatternPlanner.plans(c.skills["fx_6"], _ctx(g, centre))
	_check("self_cell: the enemy's cell", ps.size() == 1 and ps[0]["cells"] == [g.default_enemy_cell()])


func test_rotation_and_clip() -> void:
	_check("rotate 90", PatternPlanner.rotate(Vector2i(1, 0), 90) == Vector2i(0, 1))
	_check("rotate 180", PatternPlanner.rotate(Vector2i(1, 0), 180) == Vector2i(-1, 0))
	_check("rotate 270", PatternPlanner.rotate(Vector2i(1, 0), 270) == Vector2i(0, -1))
	_check("pattern col grows away from the enemy", PatternPlanner.to_board(Vector2i(1, 0)) == Vector2i(-1, 0))
	var c: EnemySkillsConfig = Fx.config()
	var g: BoardGrid = BoardGrid.new(3, 3)
	var corner: Array[Dictionary] = PatternPlanner.plans(c.skills["fx_2"], _ctx(g, Vector2i(0, 0)))
	_check("no clip: off-board rotations dropped (corner keeps 2)", corner.size() == 2)
	var row_skill: Dictionary = (c.skills["fx_5"] as Dictionary).duplicate(true)
	var small: BoardGrid = BoardGrid.new(2, 3)
	var clipped: Array[Dictionary] = PatternPlanner.plans(row_skill, _ctx(small, Vector2i(0, 1)))
	_check("clip keeps the on-board cells (2 >= min 2)", clipped.size() == 1 and (clipped[0]["cells"] as Array).size() == 2)
	(row_skill["pattern"] as Dictionary)["min_cells"] = 3
	_check("clip below min_cells = no plan (canCast false)", PatternPlanner.plans(row_skill, _ctx(small, Vector2i(0, 1))).is_empty())


func test_locked_cells_drop_plans() -> void:
	var c: EnemySkillsConfig = Fx.config()
	var g: BoardGrid = BoardGrid.new(3, 3)
	var locked: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 2), Vector2i(0, 1)]
	var ok_fn: Callable = func(cell: Vector2i) -> bool: return not locked.has(cell)
	var plans: Array[Dictionary] = PatternPlanner.plans(c.skills["fx_2"], _ctx(g, Vector2i(1, 1), [], ok_fn))
	var none_locked: bool = plans.size() == 1
	for p: Dictionary in plans:
		for cell: Vector2i in p["cells"]:
			none_locked = none_locked and not locked.has(cell)
	_check("F7 locked cells never in a plan", none_locked, str(plans.size()))
	_check("F7 drop_locked", FairnessCheck.drop_locked([Vector2i(1, 0), Vector2i(1, 1)], func(x: Vector2i) -> bool: return locked.has(x)) == [Vector2i(1, 1)])


func test_reach_formula_cases() -> void:
	var g: BoardGrid = BoardGrid.new(3, 3)
	var step_cd: float = 0.45
	_check("t_need k=1 ready", is_equal_approx(FairnessCheck.t_need(1, 0.0, step_cd, MARGIN), 0.25))
	_check("t_need k=1 just stepped", is_equal_approx(FairnessCheck.t_need(1, 0.45, step_cd, MARGIN), 0.70))
	_check("t_need k=2", is_equal_approx(FairnessCheck.t_need(2, 0.0, step_cd, MARGIN), 0.70))
	var one: Array = [Vector2i(1, 1)]
	_check("not in pattern = fair", FairnessCheck.can_hero_respond(g, Vector2i(0, 0), one, 0.1, 5.0, step_cd, MARGIN))
	_check("0.9 s warning fair just after a step (3x3)", FairnessCheck.can_hero_respond(g, Vector2i(1, 1), one, 0.9, 0.45, step_cd, MARGIN))
	_check("Rooted 0.5 s left: 0.9 s fair", FairnessCheck.can_hero_respond(g, Vector2i(1, 1), one, 0.9, 0.5, step_cd, MARGIN))
	_check("Rooted 0.7 s left: 0.9 s unfair (F9)", not FairnessCheck.can_hero_respond(g, Vector2i(1, 1), one, 0.9, 0.7, step_cd, MARGIN))
	_check("lock_left = max", is_equal_approx(FairnessCheck.lock_left(0.2, 0.0, 0.5), 0.5))
	var slow_cd: float = step_cd * 1.3
	var row: Array = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	var far: Array = [Vector2i(1, 1), Vector2i(1, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 1)]
	_check("plus shape from centre: 2 steps, 0.70 s ok", FairnessCheck.can_hero_respond(g, Vector2i(1, 1), far, 0.70, 0.0, step_cd, MARGIN))
	_check("plus shape with Slow (mire-like x1.3): 0.70 s unfair", not FairnessCheck.can_hero_respond(g, Vector2i(1, 1), far, 0.70, 0.0, slow_cd, MARGIN))
	_check("row: one step out", FairnessCheck.escape_path(g, Vector2i(1, 1), row, 0.9, 0.0, step_cd, MARGIN).size() == 1)
	var env: Dictionary = {"blocked_fn": func(c: Vector2i) -> bool: return c == Vector2i(1, 0), "unsafe": [Vector2i(1, 2)]}
	_check("holes and other warnings are not safe ends (0.6 s, 2 steps needed)", not FairnessCheck.can_hero_respond(g, Vector2i(1, 1), row, 0.6, 0.0, step_cd, MARGIN, env))
	_check("same case fair at 0.9 s (walks through red)", FairnessCheck.escape_path(g, Vector2i(1, 1), row, 0.9, 0.0, step_cd, MARGIN, env).size() == 2)
	_check("path may cross red", FairnessCheck.escape_path(g, Vector2i(1, 1), far, 0.75, 0.0, step_cd, MARGIN).size() == 2)


func test_red_ceiling() -> void:
	_check("3x3 cap 4", FairnessCheck.red_cap(9, 0.5) == 4)
	_check("cross 12 cap 6", FairnessCheck.red_cap(12, 0.5) == 6)
	_check("4 red ok on 3x3", FairnessCheck.red_ok([Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(2, 0), Vector2i(0, 1)], 9, 0.5))
	_check("5 red refused on 3x3", not FairnessCheck.red_ok([Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)], 9, 0.5))
	_check("overlap counted once", FairnessCheck.red_ok([Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)], 9, 0.5))
	var g: BoardGrid = BoardGrid.new(3, 3)
	_check("usable floor drops holes / cracks", FairnessCheck.usable_floor(g, {"blocked_fn": func(c: Vector2i) -> bool: return c == Vector2i(0, 0)}) == 8)


func test_zone_exit_cc_gap_rules() -> void:
	var g: BoardGrid = BoardGrid.new(3, 3)
	_check("F3 corner with both exits in zone fails", not FairnessCheck.zone_leaves_exit(g, Vector2i(0, 0), [Vector2i(1, 0), Vector2i(0, 1)]))
	_check("F3 one exit left passes", FairnessCheck.zone_leaves_exit(g, Vector2i(0, 0), [Vector2i(1, 0)]))
	_check("F4 locked: no new lock", not FairnessCheck.cc_allowed(0.3, 0.0))
	_check("F4 grace: no new lock", not FairnessCheck.cc_allowed(0.0, 0.5))
	_check("F4 free and grace over: allowed", FairnessCheck.cc_allowed(0.0, 0.0))
	_check("F5 0.39 s too soon", not FairnessCheck.gap_ok(0.39, 0.4))
	_check("F5 0.4 s ok", FairnessCheck.gap_ok(0.4, 0.4))
	_check("F10 heavy recovery leaves a step", is_equal_approx(FairnessCheck.gap_needed(1.2, 0.4, 0.45, MARGIN, 1.2), 0.7))
	_check("F10 light skill keeps min gap", is_equal_approx(FairnessCheck.gap_needed(0.6, 0.4, 0.45, MARGIN, 1.2), 0.4))
	_check("F8 two sources leave a common safe cell", FairnessCheck.both_leave_safe(g, Vector2i(1, 1), [Vector2i(1, 1)], [Vector2i(0, 1)], 0.9, 0.0, 0.45, MARGIN))
	var all_neighbours: Array = [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]
	_check("F8 refused when union closes every reachable safe cell", not FairnessCheck.both_leave_safe(g, Vector2i(1, 1), [Vector2i(1, 1)], all_neighbours, 0.6, 0.0, 0.45, MARGIN))


func test_root_slow_guard_statuses() -> void:
	var g: BoardGrid = BoardGrid.new(3, 3)
	var state: CombatState = CombatState.new(g, 100.0, 100.0, Vector2i(1, 1))
	var status: StatusEffects = StatusEffects.new()
	var mover: UnitMover = UnitMover.new(state, P, 0.45)
	mover.set_status(status)
	_check("root lands", status.root(P, 0.6))
	_check("rooted: step refused", not mover.try_step(Vector2i(1, 0)))
	_check("root does not stack", not status.root(P, 2.0) and is_equal_approx(status.get_root_left(P), 0.6))
	status.tick(0.7, state)
	_check("root ends", not status.is_rooted(P) and mover.try_step(Vector2i(1, 0)))
	status.pin(P, 1.0)
	_check("no Root on Frozen (D2)", not status.root(P, 0.6))
	_check("lock_left covers Frozen", is_equal_approx(status.lock_left(P), 1.0))
	status.clear()
	mover.tick(1.0)
	status.slow(P, 1.5, 1.3)
	mover.try_step(Vector2i(-1, 0))
	_check("Slow x1.3 step cooldown (D4)", is_equal_approx(mover.get_cooldown_remaining(), 0.45 * 1.3), str(mover.get_cooldown_remaining()))
	status.tick(1.6, state)
	_check("Slow ends after 1.5 s", is_equal_approx(status.step_mult(P), 1.0))
	status.guard(E, 3.0, 3.0)
	_check("Guard amount", is_equal_approx(status.guard_amount(E), 3.0))
	var skills: SkillConfig = SkillConfig.from_dictionary({"default_card": "hit", "cards": {
		"hit": {"effect": "damage", "damage_per_cell": 10.0, "implemented": true},
		"pierce": {"effect": "damage", "damage_per_cell": 10.0, "pierce_defense": true, "implemented": true}}})
	var cut: CutConfig = CutConfig.new()
	var player_actor: CutActor = CutActor.new(cut, P)
	var boss_actor: CutActor = CutActor.new(cut, E)
	var arbiter: SwingArbiter = SwingArbiter.new(state, g, player_actor, boss_actor, cut, skills, status)
	var enemy_cell: Array[Vector2i] = [state.enemy_cell]
	player_actor.begin_swing(enemy_cell, "hit", true, 1, 0.1)
	arbiter.tick(0.2)
	_check("Guard reduces a normal hit (10 - 3)", is_equal_approx(state.enemy_damage_taken, 7.0), str(state.enemy_damage_taken))
	player_actor.begin_swing(enemy_cell, "pierce", true, 1, 0.1)
	arbiter.tick(0.2)
	_check("Pierce ignores Guard fully (D5)", is_equal_approx(state.enemy_damage_taken, 17.0), str(state.enemy_damage_taken))
	status.tick(3.1, state)
	_check("Guard expires", is_equal_approx(status.guard_amount(E), 0.0))

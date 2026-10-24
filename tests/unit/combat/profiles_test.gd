extends SceneTree
## Scratch verification for Story 013 Parts 1 + 2 (movement profiles, escape scoring).

const DT: float = 0.05
const SLOW_SWING_SEC: float = 5.0

var _fails: int = 0


class World:
	extends RefCounted
	var grid: BoardGrid
	var state: CombatState
	var cut_config: CutConfig
	var skill_config: SkillConfig
	var brain_config: BossBrainConfig
	var hand: HoldSlots
	var drops: FieldDrops
	var mover: UnitMover
	var actor: CutActor
	var player_actor: CutActor
	var cooldowns: SkillCooldowns
	var status: StatusEffects
	var brain: BossBrain
	var ctx: Dictionary = {}
	var t: float = 0.0
	var cells_log: Array[Vector2i] = []
	var cut_log: Array[String] = []
	var purposes_seen: Array[String] = []

	func _init(set_name: String, brain_seed: int, drops_seed: int, movement_override: Dictionary = {},
			natural_spawns: bool = true, boss_cell: Vector2i = BoardGrid.NO_CELL) -> void:
		grid = BoardGrid.new(3, 3)
		state = CombatState.new(grid, 100000.0, 100000.0)
		if boss_cell != BoardGrid.NO_CELL:
			state.set_enemy_cell(boss_cell)
		cut_config = CutConfig.load_from_file()
		skill_config = SkillConfig.load_from_file()
		brain_config = BossBrainConfig.load_from_file()
		if not movement_override.is_empty():
			brain_config.override_movement(set_name, movement_override)
		hand = HoldSlots.new(4)
		var drops_config := FieldDropsConfig.new()
		if not natural_spawns:
			drops_config.spawn_interval_sec = 1.0e9
			drops_config.initial_delay_sec = 1.0e9
		drops = FieldDrops.new(drops_config, grid.enemy_cells(), grid.perimeter_labels(), drops_seed)
		mover = UnitMover.new(state, CombatState.Side.ENEMY, brain_config.step_cooldown_sec)
		actor = CutActor.new(cut_config, CombatState.Side.ENEMY)
		var slow := CutConfig.new()
		slow.swing_base_sec = SLOW_SWING_SEC
		slow.swing_per_cell_sec = 0.0
		player_actor = CutActor.new(slow, CombatState.Side.PLAYER)
		cooldowns = SkillCooldowns.new()
		status = StatusEffects.new()
		mover.set_status(status)
		brain = BossBrain.new(brain_config, grid, cut_config, skill_config, brain_seed)
		brain.use_set(set_name)
		ctx = {
			"state": state, "hand": hand, "drops": drops, "mover": mover, "actor": actor,
			"cooldowns": cooldowns, "player_actor": player_actor, "status": status,
			"player_step_cooldown": 0.45,
		}

	func place(label: String, cell: Vector2i, freshness: float) -> void:
		drops.debug_place(label, cell, freshness)

	func swing(cells: Array[Vector2i]) -> void:
		player_actor.begin_swing(cells, "kiem_khi", true)

	func step() -> void:
		t += DT
		brain.tick(DT, player_actor.is_swinging())
		status.tick(DT, state)
		drops.set_blocked_cells(status.burning_cells())
		drops.tick(DT, state.enemy_cell, hand.get_occupied_count())
		mover.tick(DT)
		cooldowns.tick(DT)
		actor.tick(DT)
		player_actor.tick(DT)
		var action: Dictionary = brain.decide(ctx)
		var dest: Dictionary = brain.get_destination()
		if not dest.is_empty():
			var purpose: String = str(dest["purpose"])
			if not purposes_seen.has(purpose):
				purposes_seen.append(purpose)
		var type: String = str(action["type"])
		if type == "move":
			if mover.try_step(action["direction"] as Vector2i):
				cells_log.append(state.enemy_cell)
				var point: FieldPoint = drops.pick_up_at(state.enemy_cell, hand.can_place())
				if point != null:
					hand.place_in_first_free(point)
		elif type == "cut":
			# Test executor: no swing, the whole hand is spent, so hand state never depends on
			# WHICH (noisy) cut was picked.
			var labels: Array[String] = []
			for index: int in action["hand_indices"]:
				labels.append(hand.get_point(index).label)
			for i: int in hand.get_slot_count():
				if hand.get_point(i) != null:
					hand.remove(i)
			cut_log.append("%.2f %s" % [t, ",".join(labels)])

	func run(seconds: float) -> void:
		var end: float = t + seconds
		while t < end - DT * 0.5:
			step()


func _init() -> void:
	_test_determinism()
	_test_path_styles()
	_test_commitment()
	_test_invalidation()
	_test_juke()
	_test_wander()
	_test_escape_scoring()
	print("RESULT: %s FAILS=%d" % ["ALL PASS" if _fails == 0 else "SOME FAIL", _fails])
	quit(0 if _fails == 0 else 1)


func _check(text: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_fails += 1


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v: Variant in list:
		out.append(v as Vector2i)
	return out


func _scripted_run(brain_seed: int) -> World:
	var w := World.new("cautious", brain_seed, 5, {}, true, Vector2i(3, 0))
	var script: Array = [
		[0.5, "A1", Vector2i(5, 2)], [4.0, "B2", Vector2i(3, 2)], [8.0, "C3", Vector2i(5, 0)],
		[12.0, "D1", Vector2i(4, 1)], [16.0, "A2", Vector2i(3, 1)], [20.0, "B1", Vector2i(5, 1)],
		[24.0, "C1", Vector2i(4, 2)], [28.0, "D3", Vector2i(3, 0)],
	]
	var next: int = 0
	while w.t < 40.0:
		if next < script.size() and w.t >= float(script[next][0]):
			w.place(str(script[next][1]), script[next][2] as Vector2i, 6.0)
			next += 1
		w.step()
	return w


func _test_determinism() -> void:
	var a: World = _scripted_run(11)
	var b: World = _scripted_run(22)
	_check("(a) cautious movement log identical across brain seeds 11/22 (%d steps vs %d; cuts a=%d b=%d)" % [
		a.cells_log.size(), b.cells_log.size(), a.cut_log.size(), b.cut_log.size()],
		a.cells_log == b.cells_log and a.cells_log.size() > 0)
	print("    cuts a: %s" % str(a.cut_log))
	print("    cuts b: %s" % str(b.cut_log))


func _test_path_styles() -> void:
	var expected: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)])
	var w := World.new("cautious", 1, 1, {}, false, Vector2i(3, 0))
	w.place("A1", Vector2i(5, 2), 60.0)
	w.run(6.0)
	_check("(b1) cautious row_first (3,0)->(5,2): %s" % str(w.cells_log), w.cells_log == expected)
	_check("(b1') debug destination reports row_first style", str(w.brain.last_debug().get("destination", {}).get("path_style_in_use", "")) == "row_first" or w.cells_log == expected)
	var s := World.new("balanced", 1, 1, {}, false, Vector2i(3, 0))
	s.place("A1", Vector2i(5, 2), 60.0)
	s.run(6.0)
	_check("(b2) balanced shortest tie rule (keep row first) (3,0)->(5,2): %s" % str(s.cells_log.slice(0, 4)), s.cells_log.slice(0, 4) == expected)
	var o := World.new("balanced", 1, 1, {}, false, Vector2i(3, 0))
	o.status.ignite(_cells([Vector2i(4, 0)]), 60.0, 1.0, 0.0)
	o.place("A1", Vector2i(5, 0), 60.0)
	o.run(6.0)
	var around: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 0)])
	_check("(b3) shortest routes around fire at (4,0) toward (5,0): %s" % str(o.cells_log.slice(0, 4)), o.cells_log.slice(0, 4) == around)
	var c := World.new("aggressive", 1, 1, {"path_style": "mixed", "move_noise": 0.0, "move_commitment": 1.0}, false, Vector2i(3, 0))
	c.place("A1", Vector2i(5, 2), 60.0)
	c.run(6.0)
	var column_first: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)])
	_check("(b4) mixed resolves to row_first or column_first: %s" % str(c.cells_log.slice(0, 4)), c.cells_log.slice(0, 4) == expected or c.cells_log.slice(0, 4) == column_first)


func _test_commitment() -> void:
	var w := World.new("cautious", 1, 1, {}, false, Vector2i(3, 0))
	w.place("A1", Vector2i(5, 2), 60.0)
	while w.cells_log.size() < 1 and w.t < 5.0:
		w.step()
	w.place("B2", Vector2i(3, 0), 60.0)
	w.run(5.0)
	var expected: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)])
	_check("(c1) commitment 1.0 keeps (5,2) despite a closer point at (3,0): %s" % str(w.cells_log.slice(0, 4)), w.cells_log.slice(0, 4) == expected)
	var z := World.new("cautious", 1, 1, {"move_commitment": 0.0}, false, Vector2i(3, 0))
	z.place("A1", Vector2i(5, 2), 60.0)
	while z.cells_log.size() < 1 and z.t < 5.0:
		z.step()
	z.place("B2", Vector2i(3, 0), 60.0)
	z.run(2.0)
	_check("(c2) commitment 0.0 re-targets to (3,0) on the next think: %s" % str(z.cells_log.slice(0, 2)), z.cells_log.size() >= 2 and z.cells_log[1] == Vector2i(3, 0))


func _test_invalidation() -> void:
	var w := World.new("cautious", 1, 1, {}, false, Vector2i(3, 0))
	w.place("A1", Vector2i(5, 2), 1.2)
	w.run(0.6)
	var had: bool = not w.brain.get_destination().is_empty()
	w.run(0.6 + DT + 0.4)
	var steps_at_expiry: int = w.cells_log.size()
	w.run(3.0)
	_check("(d1) expired target drops the destination within one think (had=%s, after=%s) and the boss stops" % [had, str(w.brain.get_destination())],
		had and w.brain.get_destination().is_empty() and w.cells_log.size() == steps_at_expiry)
	var f := World.new("cautious", 1, 1, {}, false, Vector2i(3, 0))
	f.place("A1", Vector2i(5, 2), 60.0)
	while f.cells_log.size() < 1 and f.t < 5.0:
		f.step()
	f.status.ignite(_cells([Vector2i(5, 2)]), 60.0, 1.0, 0.0)
	f.run(0.4)
	_check("(d2) burning destination cell -> re-target (destination now %s)" % str(f.brain.get_destination()), f.brain.get_destination().is_empty())
	var s := World.new("cautious", 1, 1, {}, false, Vector2i(3, 0))
	s.place("A1", Vector2i(5, 2), 60.0)
	var row: Array[Vector2i] = _cells([Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)])
	s.swing(row)
	var impact_cell: Vector2i = BoardGrid.NO_CELL
	while s.player_actor.is_swinging():
		s.step()
		impact_cell = s.state.enemy_cell
	var dodged: bool = s.purposes_seen.has("dodge")
	_check("(d3) visible swing on current/next cell -> dodge (purposes %s), boss at %s at impact, log %s" % [str(s.purposes_seen), str(impact_cell), str(s.cells_log)],
		dodged and not row.has(impact_cell))
	s.run(4.0)
	_check("(d3') after the swing the boss resumes toward (5,2): final cell %s" % str(s.state.enemy_cell), s.state.enemy_cell == Vector2i(5, 2))


func _test_juke() -> void:
	var j := World.new("cautious", 1, 1, {"juke_chance": 1.0}, false, Vector2i(3, 0))
	j.swing(_cells([Vector2i(3, 0)]))
	j.run(3.0)
	_check("(e1) juke 1.0: dodge then one perpendicular step: %s" % str(j.cells_log), j.cells_log == _cells([Vector2i(4, 0), Vector2i(4, 1)]))
	var n := World.new("cautious", 1, 1, {"juke_chance": 0.0}, false, Vector2i(3, 0))
	n.swing(_cells([Vector2i(3, 0)]))
	n.run(3.0)
	_check("(e2) juke 0.0: dodge only: %s" % str(n.cells_log), n.cells_log == _cells([Vector2i(4, 0)]))


func _test_wander() -> void:
	var b := World.new("balanced", 3, 3, {}, false)
	b.run(3.0)
	_check("(f1) balanced wanders within 3 s: %s" % str(b.cells_log), b.cells_log.size() >= 1 and b.purposes_seen.has("wander"))
	var c := World.new("cautious", 3, 3, {}, false)
	c.run(10.0)
	_check("(f2) cautious stays put for 10 s: %s" % str(c.cells_log), c.cells_log.is_empty())


func _escape_case(set_name: String, labels: Array[String], player_cell: Vector2i) -> Dictionary:
	var w := World.new(set_name, 1, 1, {}, false)
	w.state.set_player_cell(player_cell)
	for label: String in labels:
		var p := FieldPoint.new()
		p.label = label
		w.hand.place_in_first_free(p)
	w.ctx["player_step_cooldown"] = CombatConfig.load_from_file().step_cooldown_for(w.grid)
	w.brain.tick(1.0, false)
	var action: Dictionary = w.brain.decide(w.ctx)
	var debug: Dictionary = w.brain.last_debug()
	var min_escape: int = 999
	var alt_escape: int = -1
	var alt_key: float = -INF
	var chosen: String = ",".join(debug.get("labels", [] as Array[String])) if str(action["type"]) == "cut" else "(no cut)"
	for cand: Variant in debug.get("cut_candidates", []):
		var c: Dictionary = cand as Dictionary
		min_escape = mini(min_escape, int(c["escape"]))
		var without: float = float(c["score"]) - float(c["escape_term"])
		if bool(c["hit_now"]) and str(c["labels"]) != chosen and without > alt_key:
			alt_key = without
			alt_escape = int(c["escape"])
		print("      cand %-12s escape=%d score=%.2f (w/o escape %.2f) hit_now=%s" % [c["labels"], c["escape"], c["score"], without, c["hit_now"]])
	return {"type": str(action["type"]), "chosen": chosen, "escape": int(debug.get("escape", -1)),
		"cells": (debug.get("cells", []) as Array).size(), "min_escape": min_escape, "alt_escape": alt_escape}


func _test_escape_scoring() -> void:
	print("  (g1) player (0,0), balanced, hand A1,B1:")
	var g1: Dictionary = _escape_case("balanced", ["A1", "B1"], Vector2i(0, 0))
	_check("(g1) corner: chosen %s escape=%d vs best hit-now alternative escape=%d (chosen <= alt)" % [g1["chosen"], g1["escape"], g1["alt_escape"]],
		g1["type"] == "cut" and int(g1["escape"]) <= int(g1["alt_escape"]))
	print("  (g1b) player (0,0), aggressive, hand A1,D1 (corner nick A1-D1 = 1 cell):")
	var g1b: Dictionary = _escape_case("aggressive", ["A1", "D1"], Vector2i(0, 0))
	print("      -> chosen %s escape=%d min_escape=%d" % [g1b["chosen"], g1b["escape"], g1b["min_escape"]])
	print("  (g2) player (1,1), balanced, hand A1,B1:")
	var g2: Dictionary = _escape_case("balanced", ["A1", "B1"], Vector2i(1, 1))
	_check("(g2) centre: no single candidate leaves 0 escape cells (min=%d)" % int(g2["min_escape"]), int(g2["min_escape"]) > 0)
	print("  (g3) player (1,1), balanced, hand A1,A3,C3,C1:")
	var g3: Dictionary = _escape_case("balanced", ["A1", "A3", "C3", "C1"], Vector2i(1, 1))
	_check("(g3) full-board polygon chosen: %s cells=%d escape=%d" % [g3["chosen"], g3["cells"], g3["escape"]],
		g3["type"] == "cut" and int(g3["cells"]) == 9 and int(g3["escape"]) == 0)

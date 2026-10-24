extends SceneTree

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func near(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _init() -> void:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	check("2x2 = 0.60", near(cfg.step_cooldown_for(BoardGrid.new(2, 2)), 0.60, 0.0001))
	check("3x3 = 0.45", near(cfg.step_cooldown_for(BoardGrid.new(3, 3)), 0.45, 0.0001))
	var v43: float = cfg.step_cooldown_for(BoardGrid.new(4, 3))
	var v66: float = cfg.step_cooldown_for(BoardGrid.new(6, 6))
	print("4x3=%s 6x6=%s 10x10=%s" % [v43, v66, cfg.step_cooldown_for(BoardGrid.new(10, 10))])
	check("4x3 = 0.33", near(v43, 0.33))
	check("6x6 = 0.23", near(v66, 0.23))
	check("10x10 = 0.18", near(cfg.step_cooldown_for(BoardGrid.new(10, 10)), 0.18, 0.0001))
	print("--- expect deprecation warning next ---")
	var old: CombatConfig = CombatConfig.from_dictionary({"player_step_cooldown_sec": 0.3})
	check("old key overrides", near(old.step_cooldown_for(BoardGrid.new(6, 6)), 0.3, 0.0001))
	print("--- expect invalid warning next ---")
	var bad: CombatConfig = CombatConfig.from_dictionary({"step_cooldown_ref_sec": 0, "step_cooldown_min_sec": 5})
	check("invalid -> defaults", near(bad.step_cooldown_for(BoardGrid.new(3, 3)), 0.45, 0.0001))

	var rc: RunConfig = RunConfig.load_from_file()
	check("mult parsed", near(float(rc.matches[0]["boss_step_cooldown_mult"]), 1.78, 0.0001) and near(float(rc.matches[3]["boss_step_cooldown_mult"]), 1.11, 0.0001))
	check("shipped has no abs key", not rc.matches[0].has("boss_step_cooldown_sec"))
	check("boss cooldown m1 on 3x3", near(cfg.step_cooldown_for(BoardGrid.new(3, 3)) * float(rc.matches[0]["boss_step_cooldown_mult"]), 0.80, 0.005))
	print("--- expect RunConfig deprecation warning next ---")
	var rold: RunConfig = RunConfig.from_dictionary({"matches": [{"boss_step_cooldown_sec": 0.7}]})
	check("old abs key", near(float(rold.matches[0]["boss_step_cooldown_sec"]), 0.7, 0.0001))
	check("default mult 1.0", near(float(rold.matches[0]["boss_step_cooldown_mult"]), 1.0, 0.0001))

	var g: BoardGrid = BoardGrid.new(3, 3)
	var none: Array[Vector2i] = []
	var c11: Vector2i = Vector2i(1, 1)
	check("0 steps", EscapeAnalysis.reachable_cells(g, c11, 0, true) == [c11])
	check("1 step = 5", EscapeAnalysis.reachable_cells(g, c11, 1, true).size() == 5)
	check("2 steps = 9", EscapeAnalysis.reachable_cells(g, c11, 2, true).size() == 9)
	check("corner 1 step = 3", EscapeAnalysis.reachable_cells(g, Vector2i(0, 0), 1, true).size() == 3)
	var blocked: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	var r: Array[Vector2i] = EscapeAnalysis.reachable_cells(g, Vector2i(0, 0), 5, true, blocked)
	check("blocked neighbours seal corner", r == [Vector2i(0, 0)])
	var blocked2: Array[Vector2i] = [Vector2i(1, 1)]
	var r2: Array[Vector2i] = EscapeAnalysis.reachable_cells(g, Vector2i(1, 0), 1, true, blocked2)
	check("blocked not entered", not r2.has(Vector2i(1, 1)) and r2.size() == 3)
	var r3: Array[Vector2i] = EscapeAnalysis.reachable_cells(g, Vector2i(1, 0), 2, true, blocked2)
	check("blocked not a path", r3.size() == 6 and not r3.has(Vector2i(1, 2)) or r3.has(Vector2i(1, 2)) == false)
	var cov: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 1)]
	var esc: Array[Vector2i] = EscapeAnalysis.escape_cells(g, c11, 1, true, cov)
	check("escape excludes covered", esc.size() == 3 and not esc.has(c11))
	var ecells: Array[Vector2i] = EscapeAnalysis.reachable_cells(g, g.default_enemy_cell(), 1, false)
	check("enemy half", ecells.size() >= 3 and g.is_enemy_cell(ecells[ecells.size() - 1]))
	check("steps 0.95", EscapeAnalysis.steps_for_swing(0.95, 0.45) == 3)
	check("steps 0.9", EscapeAnalysis.steps_for_swing(0.9, 0.45) == 2)
	check("steps 0.0", EscapeAnalysis.steps_for_swing(0.0, 0.45) == 1)
	check("steps cd0", EscapeAnalysis.steps_for_swing(1.0, 0.0) == 0)
	var g6: BoardGrid = BoardGrid.new(6, 6)
	check("6x6 reach", EscapeAnalysis.reachable_cells(g6, Vector2i(2, 2), 2, true).size() == 13)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

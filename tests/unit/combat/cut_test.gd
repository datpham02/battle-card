extends SceneTree
var fails: int = 0
func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)
func sq(l: Array[String], c: int = 3, r: int = 3) -> Array[Vector2i]:
	return CutResolver.resolve_square(l, c, r)
func _init() -> void:
	ck("A1 col1", sq(["A1"]) == ([Vector2i(0,0),Vector2i(0,1),Vector2i(0,2)] as Array[Vector2i]))
	ck("D2 row2", sq(["D2"]) == ([Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)] as Array[Vector2i]))
	ck("A1+A3", sq(["A1","A3"]) == ([Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)] as Array[Vector2i]))
	var d: Array[Vector2i] = sq(["A1","C3"])
	print(d)
	ck("A1+C3", d == ([Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(1,2),Vector2i(2,2)] as Array[Vector2i]))
	ck("poly9", sq(["A1","A3","C3","C1"]).size() == 9)
	ck("poly 4x3 12", sq(["A1","A4","C4","C1"], 4, 3).size() == 12)
	print("triangle A1+A3+D3: ", sq(["A1","A3","D3"]))
	for g: Array in [[3,3],[4,3]]:
		var cols: int = g[0]
		var rows: int = g[1]
		var ok: bool = true
		var n: int = 0
		for e: String in ["A","C"]:
			for i in range(1, cols+1):
				var l: String = "%s%d" % [e, i]
				ok = ok and CutResolver.opposite_label(CutResolver.opposite_label(l, cols, rows), cols, rows) == l
				ok = ok and CutResolver.opposite_label(l, cols, rows) != ""
				n += 1
		for e: String in ["B","D"]:
			for i in range(1, rows+1):
				var l: String = "%s%d" % [e, i]
				ok = ok and CutResolver.opposite_label(CutResolver.opposite_label(l, cols, rows), cols, rows) == l
				ok = ok and CutResolver.opposite_label(l, cols, rows) != ""
				n += 1
		print("labels ", n)
		ck("opposite %dx%d" % [cols, rows], ok)
	ck("opp A2=C2 B1=D1", CutResolver.opposite_label("A2",3,3) == "C2" and CutResolver.opposite_label("B1",3,3) == "D1")
	ck("invalid", sq(["Z9"]).is_empty() and not CutResolver.is_valid_label("A4", 3, 3))
	var g1 := BoardGrid.new(3, 3, [Vector2i(0,0)] as Array[Vector2i])
	var lb: Array[String] = ["A1"]
	print("enemy A1 with hole side(0,0): ", CutResolver.resolve_on_board(g1, true, lb), " player: ", CutResolver.resolve_on_board(g1, false, lb))
	var g2 := BoardGrid.new(3, 3, [Vector2i(2,0)] as Array[Vector2i])
	print("hole side(2,0) (board 2,0 and 3,0): enemy A1 ", CutResolver.resolve_on_board(g2, true, lb), " player A1 ", CutResolver.resolve_on_board(g2, false, lb))
	ck("hole side(2,0) enemy A1 loses 1", CutResolver.resolve_on_board(g2, true, lb).size() == 2)
	ck("hole side(2,0) player A1 intact (col 0)", CutResolver.resolve_on_board(g2, false, lb).size() == 3)
	var cc := CutConfig.new()
	var a := CutActor.new(cc, 0)
	var three: Array[Vector2i] = [Vector2i(4,0),Vector2i(4,1),Vector2i(4,2)]
	ck("begin", a.begin_swing(three, "kiem_khi", true))
	ck("dur3", is_equal_approx(a.get_duration(), 0.2 + 0.25 * 3.0))
	ck("one at a time", not a.begin_swing(three, "kiem_khi", true) and not a.can_begin())
	var cnt: Array[int] = [0]
	a.swing_resolved.connect(func(_c: Array[Vector2i], _s: String) -> void: cnt[0] += 1)
	a.tick(100.0)
	a.tick(100.0)
	ck("resolved once", cnt[0] == 1 and a.can_begin())
	var nine: Array[Vector2i] = []
	for i in 9:
		nine.append(Vector2i(3 + i % 3, i / 3))
	a.begin_swing(nine, "kiem_khi", true)
	ck("dur9", is_equal_approx(a.get_duration(), 0.2 + 0.25 * 9.0))
	a.cancel()
	ck("cancel", a.can_begin())
	var sc := SkillConfig.load_from_file()
	var cfg := CutConfig.load_from_file()
	var grid := BoardGrid.new(3, 3)
	var st := CombatState.new(grid, 100.0, 100.0)
	print("enemy cell ", st.enemy_cell)
	var r: Dictionary = CutEffects.apply(st, grid, CombatState.Side.PLAYER, three, "kiem_khi", cfg, sc)
	ck("slash 3 = 18", r["hit"] and is_equal_approx(r["damage"], 18.0) and is_equal_approx(st.enemy_hp, 82.0))
	var st2 := CombatState.new(grid, 100.0, 1000.0)
	r = CutEffects.apply(st2, grid, CombatState.Side.PLAYER, nine, "kiem_khi", cfg, sc)
	ck("slash 9 = 54", is_equal_approx(r["damage"], 54.0))
	var five: Array[Vector2i] = [Vector2i(3,0),Vector2i(3,1),Vector2i(3,2),Vector2i(4,1),Vector2i(4,2)]
	var st3 := CombatState.new(grid, 100.0, 1000.0)
	r = CutEffects.apply(st3, grid, CombatState.Side.PLAYER, five, "chan_phong", cfg, sc)
	ck("push 5 = 20 pushed (chan_phong 4/cell)", is_equal_approx(r["damage"], 20.0) and r["pushed"] and st3.enemy_cell == Vector2i(5,1))
	var st4 := CombatState.new(grid, 100.0, 1000.0, BoardGrid.NO_CELL, Vector2i(5,1))
	r = CutEffects.apply(st4, grid, CombatState.Side.PLAYER, [Vector2i(5,1)] as Array[Vector2i], "chan_phong", cfg, sc)
	ck("push blocked at edge", r["hit"] and not r["pushed"] and st4.enemy_cell == Vector2i(5,1))
	r = CutEffects.apply(st4, grid, CombatState.Side.PLAYER, three, "kiem_khi", cfg, sc)
	three = [Vector2i(3,0)]
	ck("miss", not r["hit"] and r["damage"] == 0.0)
	var st5 := CombatState.new(grid, 100.0, 100.0)
	r = CutEffects.apply(st5, grid, CombatState.Side.ENEMY, [st5.player_cell] as Array[Vector2i], "kiem_khi", cfg, sc)
	ck("enemy hits player 6", r["hit"] and is_equal_approx(st5.player_hp, 94.0))
	var cd := SkillCooldowns.new()
	var av: Dictionary = SkillAvailability.check(sc, cd, "chan_phong", 2)
	ck("push 2 need 3", av["reason"] == "need_cells" and av["need_cells"] == 3)
	av = SkillAvailability.check(sc, cd, "hoa_tran", 9)
	ck("burn implemented (stale since Story 010)", av["available"])
	cd.start("chan_phong", 6.0)
	av = SkillAvailability.check(sc, cd, "chan_phong", 5)
	ck("push cooldown", av["reason"] == "cooldown" and is_equal_approx(av["cooldown_left"], 6.0))
	cd.tick(6.5)
	ck("push ready", SkillAvailability.check(sc, cd, "chan_phong", 5)["available"])
	ck("skill order", sc.card_order.slice(0, 4) == (["kiem_khi","chan_phong","hoa_tran","bang_phong"] as Array[String]))
	var hs := HoldSlots.new(4)
	for l in ["A1","B2","C3","D1"]:
		var p := FieldPoint.new()
		p.label = l
		hs.place_in_first_free(p)
	hs.toggle_selected(2)
	hs.toggle_selected(0)
	hs.toggle_selected(3)
	ck("sel order", hs.get_selected_indices() == ([2,0,3] as Array[int]) and hs.get_selected_labels() == (["C3","A1","D1"] as Array[String]))
	hs.toggle_selected(0)
	ck("deselect", hs.get_selected_indices() == ([2,3] as Array[int]))
	var rem: Array[FieldPoint] = hs.remove_selected()
	ck("remove_selected", rem.size() == 2 and rem[0].label == "C3" and hs.get_occupied_count() == 2 and hs.get_selected_indices().is_empty())
	print("FAILS: ", fails)
	quit(fails)

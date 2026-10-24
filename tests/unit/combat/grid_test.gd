extends SceneTree

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	var g := BoardGrid.new(3, 3)
	var labels: Array[String] = g.perimeter_labels()
	check("3x3 12 labels", labels.size() == 12)
	check("3x3 label order", ",".join(labels) == "A1,A2,A3,B1,B2,B3,C1,C2,C3,D1,D2,D3")
	check("3x3 player 9", g.player_cells().size() == 9)
	check("3x3 enemy 9", g.enemy_cells().size() == 9)
	check("3x3 defaults", g.default_player_cell() == Vector2i(1, 1) and g.default_enemy_cell() == Vector2i(4, 1))
	check("3x3 side coords", g.to_side_coords(Vector2i(5, 2)) == Vector2i(0, 2))

	var h := BoardGrid.new(4, 3, [Vector2i(0, 0), Vector2i(0, 2)])
	check("4x3 14 labels", h.perimeter_labels().size() == 14)
	check("4x3 10 player", h.player_cells().size() == 10)
	check("4x3 10 enemy", h.enemy_cells().size() == 10)
	check("4x3 missing mirrored", not h.is_in_board(Vector2i(0, 0)) and not h.is_in_board(Vector2i(0, 2)) and not h.is_in_board(Vector2i(7, 0)) and not h.is_in_board(Vector2i(7, 2)))
	check("4x3 neighbours real", h.is_in_board(Vector2i(1, 0)) and h.is_in_board(Vector2i(6, 0)))
	print("4x3 defaults: ", h.default_player_cell(), " ", h.default_enemy_cell())
	check("4x3 defaults real and in halves", h.is_player_cell(h.default_player_cell()) and h.is_enemy_cell(h.default_enemy_cell()))
	check("4x3 defaults centre-ish", h.default_player_cell() == Vector2i(2, 1) and h.default_enemy_cell() == Vector2i(5, 1))

	var b := BoardGrid.new(10, 10)
	check("10x10 40 labels", b.perimeter_labels().size() == 40)
	check("10x10 100 player", b.player_cells().size() == 100)
	check("10x10 100 enemy", b.enemy_cells().size() == 100)
	for vp: Vector2 in [Vector2(1280, 720), Vector2(720, 1280)]:
		var area: Rect2 = ScreenLayout.board_area_rect(vp)
		var rect: Rect2 = ScreenLayout.board_rect(b, vp)
		check("10x10 board inside area at %s" % vp, area.grow(0.01).encloses(rect))
	var vp2 := Vector2(1280, 720)
	check("cell_at outside", ScreenLayout.cell_at(g, vp2, Vector2(-5, -5)) == ScreenLayout.NO_CELL)
	var c: Vector2i = Vector2i(4, 1)
	check("cell_at round trip", ScreenLayout.cell_at(g, vp2, ScreenLayout.cell_center(g, vp2, c)) == c)
	print("FAILS=%d" % fails)
	quit(fails)

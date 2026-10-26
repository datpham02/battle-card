extends SceneTree
## Story 024 Part A: PiecePlacement (valid anchors, snap, has_any_placement, covers) on the
## default 3x3 board, a rectangle and boards with holes. Headless; FAILS=N.

var fails: int = 0
var lib: PieceLibrary


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _holes(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Array in list:
		out.append(Vector2i(item[0], item[1]))
	return out


func _init() -> void:
	lib = PieceLibrary.load_from_file()
	_test_square_board()
	_test_rectangle()
	_test_holes()
	_test_snap()
	_test_snap_prefers_covering()
	_test_any_placement()
	_test_covers_and_rotten()
	print("FAILS=%d" % fails)
	quit(fails)


func _test_square_board() -> void:
	var grid := BoardGrid.new(3, 3)
	ck("square 3x3: mono has 9 anchors on the enemy half", PiecePlacement.valid_anchors(grid, lib.make_piece("mono")).size() == 9)
	ck("square 3x3: mono on the player half has 9 anchors too", PiecePlacement.valid_anchors(grid, lib.make_piece("mono"), false).size() == 9)
	var all_enemy: bool = true
	for a: Vector2i in PiecePlacement.valid_anchors(grid, lib.make_piece("mono")):
		all_enemy = all_enemy and a.x >= 3
	ck("square 3x3: enemy anchors are in the boss columns", all_enemy)
	var all_player: bool = true
	for a: Vector2i in PiecePlacement.valid_anchors(grid, lib.make_piece("mono"), false):
		all_player = all_player and a.x < 3
	ck("square 3x3: player-half anchors are in the player columns", all_player)
	ck("square 3x3: 2x2 square has 4 anchors", PiecePlacement.valid_anchors(grid, lib.make_piece("square")).size() == 4)
	ck("square 3x3: horizontal bar3 has 3 anchors (one per row)", PiecePlacement.valid_anchors(grid, lib.make_piece("bar3")).size() == 3)
	ck("square 3x3: plus5 has exactly 1 anchor", PiecePlacement.valid_anchors(grid, lib.make_piece("plus5")) == ([Vector2i(3, 0)] as Array[Vector2i]))
	ck("square 3x3: bar4 and bar5 have no anchor", PiecePlacement.valid_anchors(grid, lib.make_piece("bar4")).is_empty() and PiecePlacement.valid_anchors(grid, lib.make_piece("bar5")).is_empty())
	var first: Array[Vector2i] = PiecePlacement.valid_anchors(grid, lib.make_piece("square"))
	ck("square 3x3: anchors come row by row", first == ([Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1)] as Array[Vector2i]))
	var rotated_ok: bool = true
	for turns: int in 4:
		rotated_ok = rotated_ok and PiecePlacement.valid_anchors(grid, lib.make_piece("t4", turns)).size() == 2
	ck("square 3x3: t4 has 2 anchors in every rotation", rotated_ok)


func _test_rectangle() -> void:
	var grid := BoardGrid.new(4, 2)
	ck("rect 4x2: horizontal bar4 has 2 anchors (one per row)", PiecePlacement.valid_anchors(grid, lib.make_piece("bar4")).size() == 2)
	ck("rect 4x2: vertical bar4 has none (only 2 rows)", PiecePlacement.valid_anchors(grid, lib.make_piece("bar4", 1)).is_empty())
	ck("rect 4x2: bar4 fits in some rotation", PiecePlacement.has_any_placement(grid, lib.make_piece("bar4", 1)))
	ck("rect 4x2: bar5 never fits", not PiecePlacement.has_any_placement(grid, lib.make_piece("bar5")))
	ck("rect 4x2: square has 3 anchors per row pair", PiecePlacement.valid_anchors(grid, lib.make_piece("square")).size() == 3)
	var wide := BoardGrid.new(5, 1)
	ck("rect 5x1: bar5 fits horizontally, only one anchor", PiecePlacement.valid_anchors(wide, lib.make_piece("bar5")) == ([Vector2i(5, 0)] as Array[Vector2i]))
	ck("rect 5x1: square does not fit", not PiecePlacement.has_any_placement(wide, lib.make_piece("square")))


func _test_holes() -> void:
	# Side hole (0,0) is board (5,0) on the boss half and (0,0) on the player half.
	var corner := BoardGrid.new(3, 3, _holes([[0, 0]]))
	var squares: Array[Vector2i] = PiecePlacement.valid_anchors(corner, lib.make_piece("square"))
	ck("holes: corner hole removes the one square that would cover it", squares.size() == 3 and not squares.has(Vector2i(4, 0)))
	ck("holes: mono has 8 anchors", PiecePlacement.valid_anchors(corner, lib.make_piece("mono")).size() == 8)
	# Side hole (1,1) is board (4,1) on the boss half: the plus has no centre.
	var centre := BoardGrid.new(3, 3, _holes([[1, 1]]))
	ck("holes: centre hole makes plus5 impossible", not PiecePlacement.has_any_placement(centre, lib.make_piece("plus5")))
	ck("holes: centre hole leaves no 2x2 square", PiecePlacement.valid_anchors(centre, lib.make_piece("square")).is_empty())
	ck("holes: centre hole is exactly the notch of an upright u5 at anchor (3,1)", PiecePlacement.valid_anchors(centre, lib.make_piece("u5")) == ([Vector2i(3, 1)] as Array[Vector2i]))
	var grids: Array[BoardGrid] = [corner, centre, BoardGrid.new(4, 3, _holes([[1, 0], [2, 2]])), BoardGrid.new(2, 3, _holes([[0, 1]]))]
	var clean: bool = true
	var checked: int = 0
	for grid: BoardGrid in grids:
		for id: String in lib.shape_ids():
			for turns: int in 4:
				for target_is_enemy: bool in [true, false]:
					var piece: Piece = lib.make_piece(id, turns)
					for anchor: Vector2i in PiecePlacement.valid_anchors(grid, piece, target_is_enemy):
						for cell: Vector2i in piece.cells_at(anchor):
							checked += 1
							var on_half: bool = grid.is_enemy_cell(cell) if target_is_enemy else grid.is_player_cell(cell)
							clean = clean and grid.is_in_board(cell) and on_half
	ck("holes: no valid anchor of any shape/rotation/half ever includes a missing or off-half cell (%d cells checked)" % checked, clean and checked > 0)
	var snapped: Dictionary = PiecePlacement.snap(centre, lib.make_piece("bar3"), Vector2i(4, 1))
	var snap_clean: bool = not snapped.is_empty()
	for cell: Vector2i in snapped.get("cells", [] as Array[Vector2i]):
		snap_clean = snap_clean and centre.is_enemy_cell(cell)
	ck("holes: a snapped placement never covers the hole", snap_clean and not (snapped["cells"] as Array[Vector2i]).has(Vector2i(4, 1)))


func _test_snap() -> void:
	var grid := BoardGrid.new(3, 3)
	var mono: Dictionary = PiecePlacement.snap(grid, lib.make_piece("mono"), Vector2i(4, 1))
	ck("snap: mono on the target cell stays there", mono["anchor"] == Vector2i(4, 1) and mono["cells"] == ([Vector2i(4, 1)] as Array[Vector2i]))
	var outside: Dictionary = PiecePlacement.snap(grid, lib.make_piece("mono"), Vector2i(0, 0))
	ck("snap: a target on the other half snaps to the nearest enemy cell", outside["anchor"] == Vector2i(3, 0))
	var far: Dictionary = PiecePlacement.snap(grid, lib.make_piece("mono"), Vector2i(20, 20))
	ck("snap: a far-away target snaps to the nearest corner", far["anchor"] == Vector2i(5, 2))
	var square: Piece = lib.make_piece("square")
	ck("snap: square near the bottom-right picks anchor (4,1)", PiecePlacement.snap(grid, square, Vector2i(5, 2))["anchor"] == Vector2i(4, 1))
	ck("snap: square near the top-left picks anchor (3,0)", PiecePlacement.snap(grid, square, Vector2i(3, 0))["anchor"] == Vector2i(3, 0))
	var result: Dictionary = PiecePlacement.snap(grid, square, Vector2i(5, 2))
	ck("snap: cells are the piece cells at the anchor", result["cells"] == square.cells_at(Vector2i(4, 1)))
	var bar2: Piece = lib.make_piece("bar2")
	var tie_a: Dictionary = PiecePlacement.snap(grid, bar2, Vector2i(4, 1))
	var tie_b: Dictionary = PiecePlacement.snap(grid, bar2, Vector2i(4, 1))
	ck("snap: a tie (anchors x=3 and x=4 equally near) is broken deterministically towards the left", tie_a["anchor"] == Vector2i(3, 1) and tie_a["anchor"] == tie_b["anchor"])
	var nearest_ok: bool = true
	var rect := BoardGrid.new(4, 3)
	var bar3: Piece = lib.make_piece("bar3", 1)
	var anchors: Array[Vector2i] = PiecePlacement.valid_anchors(rect, bar3)
	for target_x: int in range(0, 8):
		for target_y: int in range(0, 3):
			var got: Vector2i = PiecePlacement.snap(rect, bar3, Vector2i(target_x, target_y))["anchor"]
			var got_d: int = _dist(got, bar3.size(), Vector2i(target_x, target_y))
			for a: Vector2i in anchors:
				nearest_ok = nearest_ok and got_d <= _dist(a, bar3.size(), Vector2i(target_x, target_y))
	ck("snap: the result is never farther than any other valid anchor (vertical bar3 on 4x3)", nearest_ok)
	ck("snap: nothing fits gives an empty dictionary", PiecePlacement.snap(grid, lib.make_piece("bar5"), Vector2i(4, 1)).is_empty())
	var player_side: Dictionary = PiecePlacement.snap(grid, lib.make_piece("mono"), Vector2i(4, 1), false)
	ck("snap: target_is_enemy false snaps onto the player half", player_side["anchor"] == Vector2i(2, 1))


func _test_snap_prefers_covering() -> void:
	var grid := BoardGrid.new(3, 3)
	# t4 upright on 3x3 has anchors (3,0) and (3,1); aimed at (3,1) both centres are equally
	# near, but only (3,1) puts a cell on the target. The old rule took the upper one and missed.
	var t4_tie: Dictionary = PiecePlacement.snap(grid, lib.make_piece("t4"), Vector2i(3, 1))
	ck("snap covering: on an equal-distance tie the anchor covering the target wins (t4 at (3,1))", t4_tie["anchor"] == Vector2i(3, 1) and (t4_tie["cells"] as Array[Vector2i]).has(Vector2i(3, 1)))
	var l4_boss: bool = true
	for turns: int in 4:
		var piece: Piece = lib.make_piece("l4", turns)
		var any_cover: bool = false
		for a: Vector2i in PiecePlacement.valid_anchors(grid, piece):
			any_cover = any_cover or piece.cells_at(a).has(Vector2i(5, 1))
		if any_cover:
			l4_boss = l4_boss and (PiecePlacement.snap(grid, piece, Vector2i(5, 1))["cells"] as Array[Vector2i]).has(Vector2i(5, 1))
	ck("snap covering: l4 aimed at boss cell (5,1) covers it in every rotation that can", l4_boss)
	var grids: Array[BoardGrid] = [grid, BoardGrid.new(4, 3), BoardGrid.new(5, 2), BoardGrid.new(4, 3, _holes([[1, 0], [2, 2]]))]
	var names: Array[String] = ["3x3", "4x3", "5x2", "4x3 holes"]
	for gi: int in grids.size():
		var g: BoardGrid = grids[gi]
		var covered_ok: bool = true
		var nearest_ok: bool = true
		var cases: int = 0
		for id: String in lib.shape_ids():
			for turns: int in 4:
				var piece: Piece = lib.make_piece(id, turns)
				var anchors: Array[Vector2i] = PiecePlacement.valid_anchors(g, piece)
				for tx: int in range(g.side_cols, g.total_cols):
					for ty: int in range(0, g.rows):
						var target := Vector2i(tx, ty)
						var covering: Array[Vector2i] = []
						for a: Vector2i in anchors:
							if piece.cells_at(a).has(target):
								covering.append(a)
						if covering.is_empty():
							continue
						cases += 1
						var got: Dictionary = PiecePlacement.snap(g, piece, target)
						covered_ok = covered_ok and (got["cells"] as Array[Vector2i]).has(target)
						var got_d: int = _dist(got["anchor"], piece.size(), target)
						for a: Vector2i in covering:
							nearest_ok = nearest_ok and got_d <= _dist(a, piece.size(), target)
		ck("snap covering %s: whenever a covering anchor exists the snapped cells contain the target (%d shape x rotation x cell cases)" % [names[gi], cases], covered_ok and cases > 0)
		ck("snap covering %s: the snapped anchor is the nearest of the covering anchors" % names[gi], nearest_ok)


func _dist(anchor: Vector2i, box: Vector2i, target: Vector2i) -> int:
	var dx: int = anchor.x * 2 + box.x - 1 - target.x * 2
	var dy: int = anchor.y * 2 + box.y - 1 - target.y * 2
	return dx * dx + dy * dy


func _test_any_placement() -> void:
	var tiny := BoardGrid.new(1, 1)
	ck("any: 1x1 half takes only the mono", PiecePlacement.has_any_placement(tiny, lib.make_piece("mono")) and not PiecePlacement.has_any_placement(tiny, lib.make_piece("bar2")))
	var column := BoardGrid.new(1, 3)
	ck("any: a 1x3 half takes a bar3 only after turning it", PiecePlacement.valid_anchors(column, lib.make_piece("bar3")).is_empty() and PiecePlacement.has_any_placement(column, lib.make_piece("bar3")))
	ck("any: has_any_placement does not depend on the piece's current rotation", PiecePlacement.has_any_placement(column, lib.make_piece("bar3", 1)) and PiecePlacement.has_any_placement(column, lib.make_piece("bar3", 2)))
	var grid := BoardGrid.new(3, 3)
	var drawable: int = 0
	for id: String in lib.base_shape_ids(): # Story 034: the default pool (run_only shapes excluded)
		if PiecePlacement.has_any_placement(grid, lib.make_piece(id)):
			drawable += 1
	ck("any: on 3x3, 11 of the 13 shapes fit (bar4, bar5 do not)", drawable == 11)
	ck("any: null grid or piece is false and empty", not PiecePlacement.has_any_placement(null, lib.make_piece("mono")) and PiecePlacement.valid_anchors(null, lib.make_piece("mono")).is_empty() and PiecePlacement.valid_anchors(grid, null).is_empty())


func _test_covers_and_rotten() -> void:
	var cells: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0)]
	ck("covers: true for a cell of the piece, false otherwise", PiecePlacement.covers(cells, Vector2i(4, 0)) and not PiecePlacement.covers(cells, Vector2i(4, 1)))
	var grid := BoardGrid.new(3, 3)
	var rotten: Piece = Piece.make_rotten()
	ck("rotten: no valid anchors, no placement, snap is empty", PiecePlacement.valid_anchors(grid, rotten).is_empty() and not PiecePlacement.has_any_placement(grid, rotten) and PiecePlacement.snap(grid, rotten, Vector2i(4, 1)).is_empty())

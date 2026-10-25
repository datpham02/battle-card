extends SceneTree
## Story 028 flow: PlacementController.anchors_avoiding / snap_avoiding (the second piece of a cast
## never covers the first one's cells) and a PLACING controller with blocked cells. Headless; FAILS=N.

var fails: int = 0


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _init() -> void:
	var grid := BoardGrid.new(4, 3, [])
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var bar2: Piece = lib.make_piece("bar2")
	var blocked: Array[Vector2i] = [Vector2i(grid.side_cols, 0), Vector2i(grid.side_cols + 1, 0)]
	var all: Array[Vector2i] = PiecePlacement.valid_anchors(grid, bar2, true)
	var free: Array[Vector2i] = PlacementController.anchors_avoiding(grid, bar2, blocked)
	ck("empty blocked list keeps every anchor", PlacementController.anchors_avoiding(grid, bar2, []) == all)
	ck("blocked cells remove the overlapping anchors", free.size() < all.size() and not free.has(Vector2i(grid.side_cols, 0)))
	var overlap_free: bool = true
	for anchor: Vector2i in free:
		for cell: Vector2i in bar2.cells_at(anchor):
			if blocked.has(cell):
				overlap_free = false
	ck("no remaining anchor overlaps a blocked cell", overlap_free)
	var snap: Dictionary = PlacementController.snap_avoiding(grid, bar2, blocked[0], blocked)
	var snap_ok: bool = not snap.is_empty()
	if snap_ok:
		for cell: Vector2i in snap["cells"]:
			snap_ok = snap_ok and not blocked.has(cell)
	ck("snapping onto a blocked cell lands beside it", snap_ok)
	ck("empty blocked snap equals PiecePlacement.snap", PlacementController.snap_avoiding(grid, bar2, blocked[0], []) == PiecePlacement.snap(grid, bar2, blocked[0], true))
	var everything: Array[Vector2i] = grid.enemy_cells()
	ck("a fully blocked half has no anchor and no snap", PlacementController.anchors_avoiding(grid, bar2, everything).is_empty() and PlacementController.snap_avoiding(grid, bar2, blocked[0], everything).is_empty())
	var ctrl := PlacementController.new(grid)
	ck("begin with blocked cells", ctrl.begin(1, bar2, blocked))
	ctrl.move_to(blocked[0])
	var clear: bool = ctrl.can_confirm()
	for cell: Vector2i in ctrl.get_cells():
		clear = clear and not blocked.has(cell)
	ck("controller ghost avoids the blocked cells", clear)
	ctrl.rotate()
	for cell: Vector2i in ctrl.get_cells():
		clear = clear and not blocked.has(cell)
	ck("a rotated ghost still avoids them", clear)
	ctrl.cancel()
	ck("cancel forgets the blocked cells", ctrl.begin(1, bar2) and ctrl.get_cells().size() == 2)
	print("FAILS=%d" % fails)
	quit(fails)

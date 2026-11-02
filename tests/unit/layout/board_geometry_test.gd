extends SceneTree
## ADR-0002: BoardGeometry, the one board-space facade. Headless, deterministic; reads arenas.json (every shipped shape).
## Flat (ratio 0): exactly ScreenLayout's rects, centres and cell_at (the flat build draws what it drew before).
## Perspective (0.82): the cell polygon is the floor slab's warped polygon (FloorPerspective.warped_cell_polygon_screen),
## cell_at inverts cell_center on every cell of every arena, neighbours share edges, rows shrink towards the back, the
## anchors (centre / top-centre / fit rect) sit on the warped cell, and offset_polygon is the exact Rect2.grow.
## Run: godot --headless --path . -s res://tests/unit/layout/board_geometry_test.gd

const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 720), Vector2(1024, 768)]
const RATIO: float = 0.82
const EPS: float = 0.01

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	test_make_null_without_grid()
	test_flat_is_screen_layout()
	test_warped_polygon_is_the_slab_polygon()
	test_warped_cell_at_round_trips_on_every_arena()
	test_warped_neighbours_share_edges_and_rows_shrink_back()
	test_warped_anchors_sit_on_the_cell()
	test_offset_polygon_is_rect_grow()
	test_point_above_the_board_is_no_cell()
	print("FAILS=%d" % fails)
	quit(fails)


func _arena(id: String) -> BoardGrid:
	return ArenaValidator.build_grid(ArenaLibrary.load_from_file().get_shape(id))


func test_make_null_without_grid() -> void:
	check("test_make_without_grid_is_null", BoardGeometry.make(null, Vector2(1280, 720), RATIO) == null)
	check("test_of_null_combat_is_null", BoardGeometry.of(null) == null)


func test_flat_is_screen_layout() -> void:
	# Arrange
	var grid: BoardGrid = _arena("rect")
	for vp: Vector2 in VIEWPORTS:
		var geo: BoardGeometry = BoardGeometry.make(grid, vp, 0.0)
		var ok: bool = not geo.is_warped()
		# Act / Assert
		for cell: Vector2i in grid.player_cells() + grid.enemy_cells():
			var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, cell)
			ok = ok and geo.flat_cell_rect(cell) == rect
			ok = ok and geo.cell_center(cell) == ScreenLayout.cell_center(grid, vp, cell)
			ok = ok and geo.cell_at(rect.get_center()) == ScreenLayout.cell_at(grid, vp, rect.get_center())
			ok = ok and geo.cell_polygon(cell) == PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
			ok = ok and geo.fit_rect(rect) == rect and geo.cell_bounds(cell).is_equal_approx(rect)
		ok = ok and geo.flat_board_rect() == ScreenLayout.board_rect(grid, vp) and geo.board_bounds().is_equal_approx(ScreenLayout.board_rect(grid, vp))
		ok = ok and geo.to_screen(Vector2(123.4, 56.7)) == Vector2(123.4, 56.7) and geo.local_scale(Vector2(10, 10)) == Vector2.ONE
		ok = ok and geo.flat_half_rect(false).is_equal_approx(ScreenLayout.player_half_rect(grid, vp))
		check("test_flat_%dx%d_matches_screen_layout_exactly" % [int(vp.x), int(vp.y)], ok)


func test_warped_polygon_is_the_slab_polygon() -> void:
	var grid: BoardGrid = _arena("boss_hall")
	for vp: Vector2 in VIEWPORTS:
		var geo: BoardGeometry = BoardGeometry.make(grid, vp, RATIO)
		var ok: bool = geo.is_warped()
		for cell: Vector2i in grid.player_cells() + grid.enemy_cells():
			var a: PackedVector2Array = geo.cell_polygon(cell)
			var b: PackedVector2Array = geo.perspective.warped_cell_polygon_screen(grid, cell)
			var art: PackedVector2Array = geo.cell_art_polygon(cell)
			var art_want: PackedVector2Array = geo.perspective.warped_cell_polygon(grid, cell)
			for i: int in 4:
				ok = ok and a[i].distance_to(b[i]) < EPS and art[i].distance_to(art_want[i]) < EPS
		check("test_warped_%dx%d_cell_polygon_is_the_floor_slab_polygon" % [int(vp.x), int(vp.y)], ok)


func test_warped_cell_at_round_trips_on_every_arena() -> void:
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	for id: String in library.shape_ids(true):
		var grid: BoardGrid = ArenaValidator.build_grid(library.get_shape(id))
		for vp: Vector2 in VIEWPORTS:
			var geo: BoardGeometry = BoardGeometry.make(grid, vp, RATIO)
			var ok: bool = true
			for cell: Vector2i in grid.player_cells() + grid.enemy_cells():
				ok = ok and geo.cell_at(geo.cell_center(cell)) == cell
				# Just inside each corner of the drawn quad is still the cell.
				var poly: PackedVector2Array = geo.cell_polygon(cell)
				var centre: Vector2 = geo.cell_center(cell)
				for p: Vector2 in poly:
					ok = ok and geo.cell_at(p.lerp(centre, 0.1)) == cell
			check("test_%s_%dx%d_cell_at_of_every_drawn_cell_is_the_cell" % [id, int(vp.x), int(vp.y)], ok)


func test_warped_neighbours_share_edges_and_rows_shrink_back() -> void:
	var grid: BoardGrid = _arena("rect")
	var geo: BoardGeometry = BoardGeometry.make(grid, Vector2(1280, 720), RATIO)
	var a: PackedVector2Array = geo.cell_polygon(Vector2i(1, 1))
	var right: PackedVector2Array = geo.cell_polygon(Vector2i(2, 1))
	var below: PackedVector2Array = geo.cell_polygon(Vector2i(1, 2))
	check("test_right_neighbour_shares_the_edge", a[1].distance_to(right[0]) < EPS and a[2].distance_to(right[3]) < EPS)
	check("test_lower_neighbour_shares_the_edge", a[3].distance_to(below[0]) < EPS and a[2].distance_to(below[1]) < EPS)
	var back: Rect2 = geo.cell_bounds(Vector2i(1, 0))
	var front: Rect2 = geo.cell_bounds(Vector2i(1, grid.rows - 1))
	check("test_back_row_cell_smaller_than_front_row_cell", back.size.x < front.size.x and back.size.y < front.size.y)
	var k_back: Vector2 = geo.local_scale(geo.flat_cell_rect(Vector2i(1, 0)).get_center())
	var k_front: Vector2 = geo.local_scale(geo.flat_cell_rect(Vector2i(1, grid.rows - 1)).get_center())
	check("test_local_scale_below_one_and_smaller_at_the_back", k_back.x < k_front.x and k_back.y < k_front.y and k_front.x <= 1.0 + EPS)


func test_warped_anchors_sit_on_the_cell() -> void:
	var grid: BoardGrid = _arena("square")
	var geo: BoardGeometry = BoardGeometry.make(grid, Vector2(1280, 720), RATIO)
	var ok: bool = true
	for cell: Vector2i in grid.player_cells() + grid.enemy_cells():
		var poly: PackedVector2Array = geo.cell_polygon(cell)
		var top: Vector2 = geo.cell_top_center(cell)
		ok = ok and Geometry2D.is_point_in_polygon(geo.cell_center(cell), poly)
		# The top-centre lies on the drawn top edge (between its two corners).
		ok = ok and absf(top.y - poly[0].y) < EPS and top.x > poly[0].x and top.x < poly[1].x
		ok = ok and geo.fit_rect(geo.flat_cell_rect(cell)).get_center().distance_to(geo.cell_center(cell)) < EPS
		ok = ok and geo.cell_point(cell, Vector2(0.5, 1.0)).distance_to((poly[2] + poly[3]) * 0.5) < EPS
	check("test_centre_top_centre_and_fit_rect_sit_on_the_drawn_cell", ok)
	var feet: Vector2i = Vector2i(400, 200)
	check("test_warp_art_px_follows_the_floor_map", geo.warp_art_px(feet) == Vector2i(geo.perspective.warp(Vector2(feet) + Vector2(0.5, 0.5)).floor()))
	var flat: BoardGeometry = BoardGeometry.make(grid, Vector2(1280, 720), 0.0)
	check("test_warp_art_px_is_the_identity_flat", flat.warp_art_px(feet) == feet)


func test_offset_polygon_is_rect_grow() -> void:
	var rect := Rect2(10.0, 20.0, 64.0, 46.0)
	var quad := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var inset: PackedVector2Array = BoardGeometry.offset_polygon(quad, 3.0)
	var g: Rect2 = rect.grow(-3.0)
	var want := PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)])
	var ok: bool = inset.size() == 4
	for i: int in 4:
		ok = ok and inset[i].distance_to(want[i]) < EPS
	check("test_offset_polygon_of_a_rect_is_rect_grow_minus_px", ok)
	var outset: PackedVector2Array = BoardGeometry.offset_polygon(quad, -2.0)
	check("test_negative_offset_grows", outset[0].distance_to(rect.position - Vector2(2, 2)) < EPS)
	# A trapezoid inset keeps every edge parallel and px away.
	var trap := PackedVector2Array([Vector2(10, 0), Vector2(90, 0), Vector2(100, 50), Vector2(0, 50)])
	var t_in: PackedVector2Array = BoardGeometry.offset_polygon(trap, 4.0)
	var d_left: float = absf((trap[3] - trap[0]).normalized().cross(t_in[0] - trap[0]))
	check("test_trapezoid_inset_edges_move_exactly_px_inwards", absf(t_in[0].y - 4.0) < EPS and absf(d_left - 4.0) < EPS)


func test_point_above_the_board_is_no_cell() -> void:
	var grid: BoardGrid = _arena("rect")
	var geo: BoardGeometry = BoardGeometry.make(grid, Vector2(1280, 720), RATIO)
	var board: PackedVector2Array = geo.board_polygon()
	check("test_above_the_drawn_board_is_no_cell", geo.cell_at((board[0] + board[1]) * 0.5 - Vector2(0.0, 3.0)) == ScreenLayout.NO_CELL)
	check("test_left_of_the_drawn_board_is_no_cell", geo.cell_at((board[0] + board[3]) * 0.5 - Vector2(3.0, 0.0)) == ScreenLayout.NO_CELL)

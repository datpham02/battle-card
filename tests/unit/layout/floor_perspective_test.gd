extends SceneTree
## PROTOTYPE floor-perspective (2026-11-02): the pure homography of FloorPerspective. Headless, deterministic, no I/O
## beyond arenas.json (every shipped shape's cell centres must round-trip through warp / cell_at_warped).
## Run: godot --headless --path . -s res://tests/unit/layout/floor_perspective_test.gd

const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 720), Vector2(1024, 768)]
const RATIOS: Array[float] = [0.82, 0.9, 0.6]
const EPS: float = 0.01
const BOARD: Rect2 = Rect2(100.0, 50.0, 400.0, 200.0)

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	test_identity_at_ratio_one()
	test_corners_map_as_specified()
	test_inverse_round_trips()
	test_rows_shorter_towards_the_back()
	test_matrix_agrees_with_closed_form()
	test_basis_convention()
	test_is_on()
	test_cell_at_round_trip_on_every_arena()
	test_warped_cell_polygon_edges_meet()
	print("FAILS=%d" % fails)
	quit(fails)


func test_identity_at_ratio_one() -> void:
	var ok: bool = true
	for p: Vector2 in [Vector2(100, 50), Vector2(300, 150), Vector2(500, 250), Vector2(0, 0), Vector2(350, 400)]:
		ok = ok and FloorPerspective.warp_point(BOARD, 1.0, p).distance_to(p) < EPS
		ok = ok and FloorPerspective.unwarp_point(BOARD, 1.0, p).distance_to(p) < EPS
	check("test_ratio_1_is_the_identity", ok)


func test_corners_map_as_specified() -> void:
	for r: float in RATIOS:
		var tl: Vector2 = FloorPerspective.warp_point(BOARD, r, BOARD.position)
		var tr: Vector2 = FloorPerspective.warp_point(BOARD, r, Vector2(BOARD.end.x, BOARD.position.y))
		var bl: Vector2 = FloorPerspective.warp_point(BOARD, r, Vector2(BOARD.position.x, BOARD.end.y))
		var br: Vector2 = FloorPerspective.warp_point(BOARD, r, BOARD.end)
		var cx: float = BOARD.get_center().x
		var half_top: float = BOARD.size.x * r * 0.5
		check("test_r%.2f_bottom_edge_stays" % r, bl.distance_to(Vector2(BOARD.position.x, BOARD.end.y)) < EPS and br.distance_to(BOARD.end) < EPS)
		check("test_r%.2f_top_edge_shrinks_to_ratio_about_the_centre_line" % r,
			absf(tl.y - BOARD.position.y) < EPS and absf(tr.y - BOARD.position.y) < EPS
			and absf(tl.x - (cx - half_top)) < EPS and absf(tr.x - (cx + half_top)) < EPS)
		var top_mid: Vector2 = FloorPerspective.warp_point(BOARD, r, Vector2(cx, BOARD.position.y))
		check("test_r%.2f_centre_line_stays_vertical" % r, absf(top_mid.x - cx) < EPS)


func test_inverse_round_trips() -> void:
	for r: float in RATIOS:
		var worst: float = 0.0
		for i: int in 21:
			for j: int in 21:
				var p: Vector2 = BOARD.position + Vector2(BOARD.size.x * (i / 20.0 * 1.4 - 0.2), BOARD.size.y * (j / 20.0 * 1.4 - 0.2))
				var back: Vector2 = FloorPerspective.unwarp_point(BOARD, r, FloorPerspective.warp_point(BOARD, r, p))
				worst = maxf(worst, back.distance_to(p))
				var fwd: Vector2 = FloorPerspective.warp_point(BOARD, r, FloorPerspective.unwarp_point(BOARD, r, p))
				worst = maxf(worst, fwd.distance_to(p))
		check("test_r%.2f_round_trip_worst_%.5f_px_under_0.01" % [r, worst], worst < EPS)


func test_rows_shorter_towards_the_back() -> void:
	for r: float in [0.82, 0.9]:
		var rows: int = 5
		var heights: Array[float] = []
		for i: int in rows:
			var y0: float = BOARD.position.y + BOARD.size.y * i / rows
			var y1: float = BOARD.position.y + BOARD.size.y * (i + 1) / rows
			heights.append(FloorPerspective.warp_point(BOARD, r, Vector2(300, y1)).y - FloorPerspective.warp_point(BOARD, r, Vector2(300, y0)).y)
		var monotonic: bool = true
		for i: int in rows - 1:
			monotonic = monotonic and heights[i] < heights[i + 1]
		check("test_r%.2f_row_heights_grow_towards_the_front_%s" % [r, heights], monotonic)
		# Projective, not linear: the midline lands at r / (1 + r) of the height, above the centre.
		var mid: Vector2 = FloorPerspective.warp_point(BOARD, r, BOARD.get_center())
		var want: float = BOARD.position.y + BOARD.size.y * r / (1.0 + r)
		check("test_r%.2f_midline_at_r_over_1_plus_r" % r, absf(mid.y - want) < EPS and want < BOARD.get_center().y)


func test_matrix_agrees_with_closed_form() -> void:
	for r: float in RATIOS:
		var m: PackedFloat64Array = FloorPerspective.matrix_rows(BOARD, r)
		var inv: PackedFloat64Array = FloorPerspective.inverse_matrix_rows(BOARD, r)
		var worst: float = 0.0
		for i: int in 11:
			for j: int in 11:
				var p: Vector2 = BOARD.position + Vector2(BOARD.size.x * (i / 10.0 * 1.2 - 0.1), BOARD.size.y * (j / 10.0 * 1.2 - 0.1))
				worst = maxf(worst, FloorPerspective.apply_rows(m, p).distance_to(FloorPerspective.warp_point(BOARD, r, p)))
				worst = maxf(worst, FloorPerspective.apply_rows(inv, p).distance_to(FloorPerspective.unwarp_point(BOARD, r, p)))
		check("test_r%.2f_matrices_match_closed_form_worst_%.5f" % [r, worst], worst < EPS)


func test_basis_convention() -> void:
	var m: PackedFloat64Array = FloorPerspective.matrix_rows(BOARD, 0.82)
	var b: Basis = FloorPerspective.rows_to_basis(m)
	var p: Vector2 = Vector2(260.0, 120.0)
	var v: Vector3 = b * Vector3(p.x, p.y, 1.0)
	var got: Vector2 = Vector2(v.x / v.z, v.y / v.z)
	check("test_basis_times_vector3_equals_row_major_product", got.distance_to(FloorPerspective.apply_rows(m, p)) < EPS)


func test_is_on() -> void:
	check("test_is_on_0_off", not FloorPerspective.is_on(0.0))
	check("test_is_on_1_on", FloorPerspective.is_on(1.0))
	check("test_is_on_082_on", FloorPerspective.is_on(0.82))
	check("test_is_on_1_5_off", not FloorPerspective.is_on(1.5))
	check("test_is_on_0_1_off", not FloorPerspective.is_on(0.1))
	check("test_is_on_nan_off", not FloorPerspective.is_on(NAN))
	check("test_make_returns_null_when_off", FloorPerspective.make(BoardGrid.new(3, 3), Vector2(1280, 720), 0.0) == null)


func test_cell_at_round_trip_on_every_arena() -> void:
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	var ids: Array[String] = library.shape_ids(true)
	check("test_arenas_loaded_%d_shapes" % ids.size(), ids.size() > 0)
	for id: String in ids:
		var grid: BoardGrid = ArenaValidator.build_grid(library.get_shape(id))
		for vp: Vector2 in VIEWPORTS:
			for r: float in [0.82, 0.9]:
				var persp: FloorPerspective = FloorPerspective.make(grid, vp, r)
				var ok: bool = persp != null
				var ok_screen: bool = persp != null
				for cell: Vector2i in grid.player_cells() + grid.enemy_cells():
					var centre_screen: Vector2 = ScreenLayout.cell_center(grid, vp, cell)
					var centre_art: Vector2 = persp.to_art(centre_screen)
					if persp.cell_at_warped(grid, persp.warp(centre_art)) != cell:
						ok = false
					if persp.cell_at_warped_screen(grid, persp.warp_screen(centre_screen)) != cell:
						ok_screen = false
				check("test_%s_%dx%d_r%.2f_cell_at_warped_of_warped_centre_is_the_cell" % [id, int(vp.x), int(vp.y), r], ok)
				check("test_%s_%dx%d_r%.2f_screen_round_trip" % [id, int(vp.x), int(vp.y), r], ok_screen)
				# A point just above the warped board is NO_CELL, as on the flat board.
				var above: Vector2 = persp.warp(persp.board.position + Vector2(persp.board.size.x * 0.5, -2.0))
				check("test_%s_%dx%d_r%.2f_above_the_board_is_no_cell" % [id, int(vp.x), int(vp.y), r], persp.cell_at_warped(grid, above) == ScreenLayout.NO_CELL)


func test_warped_cell_polygon_edges_meet() -> void:
	var grid: BoardGrid = BoardGrid.new(4, 3)
	var vp: Vector2 = Vector2(1280, 720)
	var persp: FloorPerspective = FloorPerspective.make(grid, vp, 0.82)
	var a: PackedVector2Array = persp.warped_cell_polygon(grid, Vector2i(1, 1))
	var right: PackedVector2Array = persp.warped_cell_polygon(grid, Vector2i(2, 1))
	var below: PackedVector2Array = persp.warped_cell_polygon(grid, Vector2i(1, 2))
	check("test_polygon_has_four_points", a.size() == 4)
	check("test_right_neighbour_shares_the_edge", a[1].distance_to(right[0]) < EPS and a[2].distance_to(right[3]) < EPS)
	check("test_lower_neighbour_shares_the_edge", a[3].distance_to(below[0]) < EPS and a[2].distance_to(below[1]) < EPS)
	check("test_top_edge_narrower_than_bottom_edge", (a[1].x - a[0].x) < (a[2].x - a[3].x))
	var basis: Basis = persp.inverse_uv_basis()
	var uv: Vector2 = persp.warp(persp.board.get_center()) / Vector2(ScreenLayout.ART_CANVAS_WIDTH, ScreenLayout.ART_CANVAS_HEIGHT)
	var q: Vector3 = basis * Vector3(uv.x, uv.y, 1.0)
	var flat_uv: Vector2 = Vector2(q.x / q.z, q.y / q.z) * Vector2(ScreenLayout.ART_CANVAS_WIDTH, ScreenLayout.ART_CANVAS_HEIGHT)
	check("test_inverse_uv_basis_maps_the_warped_centre_back_to_the_flat_centre", flat_uv.distance_to(persp.board.get_center()) < EPS)

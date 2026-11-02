extends SceneTree
## Story 044 Part A: control layout v2 geometry (ScreenLayout). Headless suite, deterministic, no I/O.
## Story 047 Part A: the board band starts at 20 % (BOARD_BAND_TOP_RATIO), cells scale by the integer
## art_scale, and the art canvas rect / play rect / to_art / from_art conversions are checked here.
## Controls v3 (2026-11-02): the bag, the bottom-left row, the corners and their hit rects are checked in
## tests/unit/layout/controls_v3_layout_test.gd; this suite keeps the board geometry and checks the board against the
## v3 controls (their hit rects).
## Run: godot --headless --path . -s res://tests/unit/layout/screen_layout_v2_test.gd

const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 720)]
## Quick spec section 3: the crystal shape (6x6 per half), not in arenas.json.
const CRYSTAL_MISSING: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2),
	Vector2i(0, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5),
]
## arenas.json "ring" (6x5 per half).
const RING_MISSING: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
]
## A 7x6 crystal-like shape (the spec's box ceiling) whose bottom row has 3 real cells per half.
const WIDE_CRYSTAL_MISSING: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(1, 4),
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5),
]
const CROSS_MISSING: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 3), Vector2i(3, 0), Vector2i(3, 3)]
const EPS: float = 0.01

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	var grids: Dictionary = {
		"3x3": BoardGrid.new(3, 3),
		"5x5": BoardGrid.new(5, 5),
		"cross4x4": BoardGrid.new(4, 4, CROSS_MISSING),
		"ring6x5": BoardGrid.new(6, 5, RING_MISSING),
		"crystal6x6": BoardGrid.new(6, 6, CRYSTAL_MISSING),
		"crystal7x6": BoardGrid.new(7, 6, WIDE_CRYSTAL_MISSING),
	}
	test_cell_table_matches_quick_spec(grids)
	test_row_rule_wide_and_narrow(grids)
	test_board_never_under_controls(grids)
	test_every_arena_shape_clear_of_slots(grids)
	test_cell_at_round_trip(grids)
	test_stick_zone_numbers()
	test_signature_rect_bottom_centre()
	test_huge_board_falls_back_inside_area()
	test_art_scale_and_rect_1280x720()
	test_art_scale_and_rect_1600x720()
	test_art_scale_and_rect_2400x1080()
	test_art_scale_and_rect_1024x768()
	test_to_art_from_art_round_trip(grids)
	test_board_band_top_20_percent()
	test_corner_hp_panels()
	print("FAILS=%d" % fails)
	quit(fails)


func _art(grid: BoardGrid, vp: Vector2) -> Vector2:
	return ScreenLayout.cell_size(grid, vp) / float(ScreenLayout.art_scale(vp))


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func test_cell_table_matches_quick_spec(grids: Dictionary) -> void:
	var vp := Vector2(1280, 720)
	# Story 047 Part A: the board band starts at 20 % (was 15.2 %), so it is 316.8 px tall at 720p and a 5-row
	# board gets at most 31 art px per row: 3x3 64x46 (unchanged), 5x5 43x31, 4x4 cross 55x39, ring 43x31 (clear
	# of every slot), 6x6 crystal 43x31 (its row 4 starts left of the thumb gap, so it is a wide row and must end
	# at 64 %), 7x6 crystal 42x30 (half-width bound, unchanged). The quick spec's 48x34 / 49x35 are no longer reachable.
	var table: Dictionary = {
		"3x3": Vector2(64, 46), "5x5": Vector2(43, 31), "cross4x4": Vector2(55, 39),
		"ring6x5": Vector2(43, 31), "crystal6x6": Vector2(43, 31), "crystal7x6": Vector2(42, 30),
	}
	for id: String in table:
		var art: Vector2 = _art(grids[id], vp)
		var want: Vector2 = table[id]
		check("test_cell_size_%s_art_px_%s_within_1_of_%s" % [id, art, want], _near(art.x, want.x, 1.0) and _near(art.y, want.y, 1.0))
		check("test_cell_size_%s_aspect_1_4_and_within_min_max" % id, art.x >= 38.0 and art.x <= 64.0 and art.y >= 27.0 and art.y <= 46.0)
	for id: String in grids:
		var g: BoardGrid = grids[id]
		var wide := Vector2(1600, 720)
		var a: Vector2 = _art(g, wide)
		var b: Vector2 = _art(g, vp)
		check("test_cell_size_%s_at_1600_never_smaller_than_at_1280" % id, a.x >= b.x - EPS and a.y >= b.y - EPS)
		check("test_cell_size_%s_half_at_most_298_art_px" % id, b.x * g.side_cols <= 298.0)


# Independent re-implementation of the row rule from the rect functions.
func _row_extent(grid: BoardGrid, vp: Vector2, row: int) -> Vector2:
	var left: float = INF
	var right: float = -INF
	for col: int in grid.total_cols:
		if grid.is_in_board(Vector2i(col, row)):
			var r: Rect2 = ScreenLayout.cell_rect(grid, vp, Vector2i(col, row))
			left = minf(left, r.position.x)
			right = maxf(right, r.end.x)
	return Vector2(left, right)


func test_row_rule_wide_and_narrow(grids: Dictionary) -> void:
	for vp: Vector2 in VIEWPORTS:
		for id: String in grids:
			var g: BoardGrid = grids[id]
			var ok_all: bool = true
			var narrow_rows: int = 0
			for row: int in g.rows:
				var ext: Vector2 = _row_extent(g, vp, row)
				var bottom: float = ScreenLayout.cell_rect(g, vp, Vector2i(0, row)).end.y
				var inside: bool = ext.x >= vp.x * 0.25 - EPS and ext.y <= vp.x * 0.764 + EPS
				var limit: float = vp.y * (0.76 if inside else 0.64)
				if inside and bottom > vp.y * 0.64 + EPS:
					narrow_rows += 1
				if bottom > limit + EPS:
					ok_all = false
			check("test_row_rule_%s_at_%s_every_row_ends_within_its_limit" % [id, vp], ok_all)
			var board: Rect2 = ScreenLayout.board_rect(g, vp)
			check("test_board_%s_at_%s_centred_horizontally" % [id, vp], _near(board.get_center().x, vp.x * 0.5, 0.5))
			check("test_board_%s_at_%s_top_not_above_20_percent" % [id, vp], board.position.y >= vp.y * 0.20 - EPS)
	var vp := Vector2(1280, 720)
	var five: Rect2 = ScreenLayout.board_rect(grids["5x5"], vp)
	check("test_row_rule_5x5_wide_rows_end_at_or_above_64_percent", five.end.y <= vp.y * 0.64 + EPS)
	var crystal: BoardGrid = grids["crystal6x6"]
	var crystal_board: Rect2 = ScreenLayout.board_rect(crystal, vp)
	check("test_row_rule_crystal_overflows_below_64_percent_for_its_narrow_bottom_row", crystal_board.end.y > vp.y * 0.64 + EPS and crystal_board.end.y <= vp.y * 0.76 + EPS)
	var three: Rect2 = ScreenLayout.board_rect(grids["3x3"], vp)
	check("test_board_3x3_centred_in_band_below_64_percent", three.end.y <= vp.y * 0.64 and three.position.y > vp.y * 0.20)


# Controls v3: the stick zone, the Awaken button and every hit rect of the bottom rows (the visuals sit inside them).
func _controls(vp: Vector2) -> Dictionary:
	var out: Dictionary = {
		"stick_zone": ScreenLayout.stick_zone_rect(vp),
		"awaken": ScreenLayout.signature_rect(vp),
		"confirm_hit": ScreenLayout.confirm_hit_rect(vp),
		"rotate_hit": ScreenLayout.rotate_hit_rect(vp),
		"cancel_hit": ScreenLayout.cancel_hit_rect(vp),
		"place_hint": ScreenLayout.place_hint_rect(vp),
	}
	var slots: Array[Rect2] = ScreenLayout.slot_hit_rects(vp, 4)
	for i: int in slots.size():
		out["slot_hit_%d" % i] = slots[i]
	return out


func test_board_never_under_controls(grids: Dictionary) -> void:
	for vp: Vector2 in VIEWPORTS:
		var controls: Dictionary = _controls(vp)
		for id: String in grids:
			var g: BoardGrid = grids[id]
			var hit_control: String = ""
			for cell: Vector2i in g.player_cells() + g.enemy_cells():
				var r: Rect2 = ScreenLayout.cell_rect(g, vp, cell)
				for name: String in controls:
					if r.intersects(controls[name]):
						hit_control = name
			check("test_board_%s_at_%s_no_cell_under_a_button_or_the_stick_zone%s" % [id, vp, "" if hit_control.is_empty() else " (hits " + hit_control + ")"], hit_control.is_empty())


# Name of the first slot (of a bag of four, which includes the three-slot arc) that a real cell of [param g]
# overlaps at [param vp], "" if none.
func _slot_hit(g: BoardGrid, vp: Vector2) -> String:
	var slots: Array[Rect2] = ScreenLayout.slot_hit_rects(vp, 4)
	for cell: Vector2i in g.player_cells() + g.enemy_cells():
		var r: Rect2 = ScreenLayout.cell_rect(g, vp, cell)
		for i: int in slots.size():
			if r.intersects(slots[i]):
				return "T%d (cell %s)" % [i + 1, cell]
	return ""


# Story 044 Part C: no real cell of any arenas.json shape (nor the test grids, crystal 6x6 / 7x6 included) under
# any of the four slot rectangles, at 1280x720 and 1600x720. Reads the shipped data file so a new shape is covered.
func test_every_arena_shape_clear_of_slots(grids: Dictionary) -> void:
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	var all: Dictionary = grids.duplicate()
	for id: String in library.shape_ids():
		all["arenas.json:" + id] = ArenaValidator.build_grid(library.get_shape(id))
	check("test_arenas_json_has_shapes_to_check", all.size() > grids.size())
	for vp: Vector2 in VIEWPORTS:
		for id: String in all:
			var hit: String = _slot_hit(all[id], vp)
			check("test_board_%s_at_%s_no_cell_under_a_slot%s" % [id, vp, "" if hit.is_empty() else " (hits " + hit + ")"], hit.is_empty())


func test_cell_at_round_trip(grids: Dictionary) -> void:
	for vp: Vector2 in VIEWPORTS:
		for id: String in grids:
			var g: BoardGrid = grids[id]
			var ok_all: bool = true
			for cell: Vector2i in g.player_cells() + g.enemy_cells():
				if ScreenLayout.cell_at(g, vp, ScreenLayout.cell_center(g, vp, cell)) != cell:
					ok_all = false
			check("test_cell_at_%s_at_%s_round_trips_every_real_cell" % [id, vp], ok_all)
			var board: Rect2 = ScreenLayout.board_rect(g, vp)
			check("test_cell_at_%s_at_%s_outside_board_is_no_cell" % [id, vp], ScreenLayout.cell_at(g, vp, board.position - Vector2(3, 3)) == ScreenLayout.NO_CELL and ScreenLayout.cell_at(g, vp, board.end + Vector2(3, 3)) == ScreenLayout.NO_CELL)


func test_stick_zone_numbers() -> void:
	var z: Rect2 = ScreenLayout.stick_zone_rect(Vector2(1280, 720))
	check("test_stick_zone_1280_is_0_460.8_320_259.2_got_%s" % z, _near(z.position.x, 0.0, EPS) and _near(z.position.y, 460.8, EPS) and _near(z.size.x, 320.0, EPS) and _near(z.size.y, 259.2, EPS))
	var w: Rect2 = ScreenLayout.stick_zone_rect(Vector2(1600, 720))
	check("test_stick_zone_1600_width_is_a_quarter_of_the_width", _near(w.size.x, 400.0, EPS) and _near(w.position.y, 460.8, EPS) and _near(w.end.y, 720.0, EPS))
	var arena: Rect2 = ScreenLayout.arena_rect(Vector2(1280, 720))
	check("test_arena_rect_ends_where_the_stick_zone_starts", _near(arena.end.y, z.position.y, EPS) and _near(arena.position.y, 21.6, EPS))
	var area: Rect2 = ScreenLayout.board_area_rect(Vector2(1280, 720))
	check("test_board_area_top_is_20_percent", _near(area.position.y, 720.0 * 0.20, EPS))


func test_signature_rect_bottom_centre() -> void:
	for vp: Vector2 in VIEWPORTS:
		var r: Rect2 = ScreenLayout.signature_rect(vp)
		check("test_signature_rect_%s_is_115_px_square" % vp, _near(r.size.x, 115.2, 0.05) and _near(r.size.y, 115.2, 0.05))
		check("test_signature_rect_%s_centred_horizontally" % vp, _near(r.get_center().x, vp.x * 0.5, EPS))
		check("test_signature_rect_%s_half_a_margin_above_the_bottom" % vp, _near(vp.y - r.end.y, vp.x * 0.03 * 0.5, EPS))
		check("test_signature_button_rect_%s_delegates_to_signature_rect" % vp, ScreenLayout.signature_button_rect(vp) == r)
		check("test_signature_charge_%s_inside_the_button" % vp, r.encloses(ScreenLayout.signature_charge_rect(vp)))


func test_huge_board_falls_back_inside_area() -> void:
	var g := BoardGrid.new(10, 10)
	for vp: Vector2 in [Vector2(1280, 720), Vector2(720, 1280)]:
		var area: Rect2 = ScreenLayout.board_area_rect(vp)
		var board: Rect2 = ScreenLayout.board_rect(g, vp)
		check("test_fallback_10x10_at_%s_board_inside_board_area" % vp, area.grow(EPS).encloses(board))


# Story 047 Part A: art_scale / art_rect / play_rect at one viewport.
func _check_art_rects(vp: Vector2, n: int, art: Rect2, play: Rect2) -> void:
	check("test_art_scale_%s_is_%d_got_%d" % [vp, n, ScreenLayout.art_scale(vp)], ScreenLayout.art_scale(vp) == n)
	var got_art: Rect2 = ScreenLayout.art_rect(vp)
	check("test_art_rect_%s_is_%s_got_%s" % [vp, art, got_art], got_art.is_equal_approx(art))
	var got_play: Rect2 = ScreenLayout.play_rect(vp)
	check("test_play_rect_%s_is_%s_got_%s" % [vp, play, got_play], got_play.is_equal_approx(play))
	check("test_play_rect_%s_centred_in_art_rect" % vp, _near(got_play.get_center().x, got_art.get_center().x, EPS) and _near(got_play.position.y, got_art.position.y, EPS))
	check("test_art_rect_%s_centred_on_screen" % vp, got_art.get_center().is_equal_approx(vp * 0.5))


func test_art_scale_and_rect_1280x720() -> void:
	_check_art_rects(Vector2(1280, 720), 2, Rect2(-160, 0, 1600, 720), Rect2(0, 0, 1280, 720))


func test_art_scale_and_rect_1600x720() -> void:
	_check_art_rects(Vector2(1600, 720), 2, Rect2(0, 0, 1600, 720), Rect2(160, 0, 1280, 720))


func test_art_scale_and_rect_2400x1080() -> void:
	_check_art_rects(Vector2(2400, 1080), 3, Rect2(0, 0, 2400, 1080), Rect2(240, 0, 1920, 1080))


func test_art_scale_and_rect_1024x768() -> void:
	_check_art_rects(Vector2(1024, 768), 1, Rect2(112, 204, 800, 360), Rect2(192, 204, 640, 360))


# Story 047 Part A: to_art(from_art(a)) == a for whole art px (and for any point inside that art px), one art px
# is n screen px, to_art_rect keeps adjacent cells edge to edge and every cell inside the play rect at 720p.
func test_to_art_from_art_round_trip(grids: Dictionary) -> void:
	for vp: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080), Vector2(1024, 768)]:
		var n: int = ScreenLayout.art_scale(vp)
		var ok_all: bool = true
		for a: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(399, 179), Vector2i(640, 359), Vector2i(799, 359)]:
			if ScreenLayout.to_art(vp, ScreenLayout.from_art(vp, Vector2(a))) != a:
				ok_all = false
			if ScreenLayout.to_art(vp, ScreenLayout.from_art(vp, Vector2(a)) + Vector2(n - 0.01, n - 0.01)) != a:
				ok_all = false
		check("test_to_art_from_art_%s_round_trips_whole_art_px" % vp, ok_all)
		check("test_from_art_%s_origin_is_art_rect_position" % vp, ScreenLayout.from_art(vp, Vector2.ZERO) == ScreenLayout.art_rect(vp).position)
		check("test_from_art_%s_one_art_px_is_n_screen_px" % vp, ScreenLayout.from_art(vp, Vector2(1, 1)) - ScreenLayout.from_art(vp, Vector2.ZERO) == Vector2(n, n))
	var vp720 := Vector2(1280, 720)
	check("test_to_art_1280_screen_px_640_360_is_art_400_180", ScreenLayout.to_art(vp720, Vector2(640, 360)) == Vector2i(400, 180))
	check("test_to_art_1280_screen_origin_is_art_80_0", ScreenLayout.to_art(vp720, Vector2.ZERO) == Vector2i(80, 0))
	var play := Rect2i(ScreenLayout.to_art_rect(vp720, ScreenLayout.play_rect(vp720)))
	check("test_play_rect_1280_in_art_px_is_80_0_640_360_got_%s" % play, play == Rect2i(80, 0, 640, 360))
	for id: String in ["3x3", "5x5", "ring6x5"]:
		var g: BoardGrid = grids[id]
		var edges_ok: bool = true
		var inside_play: bool = true
		for cell: Vector2i in g.player_cells() + g.enemy_cells():
			var r: Rect2i = ScreenLayout.to_art_rect(vp720, ScreenLayout.cell_rect(g, vp720, cell))
			if not play.encloses(r):
				inside_play = false
			var right: Vector2i = cell + Vector2i(1, 0)
			if g.is_in_board(right) and ScreenLayout.to_art_rect(vp720, ScreenLayout.cell_rect(g, vp720, right)).position.x != r.end.x:
				edges_ok = false
			var below: Vector2i = cell + Vector2i(0, 1)
			if g.is_in_board(below) and ScreenLayout.to_art_rect(vp720, ScreenLayout.cell_rect(g, vp720, below)).position.y != r.end.y:
				edges_ok = false
		check("test_to_art_rect_%s_adjacent_cells_share_edges" % id, edges_ok)
		check("test_to_art_rect_%s_every_cell_inside_the_play_rect" % id, inside_play)


# Story 047 Part A: the board band starts at 20 % of the height; the Z1 HUD band keeps 3-8 %.
func test_board_band_top_20_percent() -> void:
	check("test_board_band_top_ratio_is_0_20", is_equal_approx(ScreenLayout.BOARD_BAND_TOP_RATIO, 0.20))
	for vp: Vector2 in VIEWPORTS:
		var area: Rect2 = ScreenLayout.board_area_rect(vp)
		check("test_board_area_%s_starts_at_20_percent_got_%s" % [vp, area.position.y], _near(area.position.y, vp.y * 0.20, EPS))
		check("test_board_area_%s_ends_at_the_wide_arena_bottom" % vp, _near(area.end.y, vp.y * 0.64, EPS))
		var hud: Rect2 = ScreenLayout.hud_rect(vp)
		check("test_hud_rect_%s_is_3_to_8_percent_got_%s_%s" % [vp, hud.position.y, hud.end.y], _near(hud.position.y, vp.y * 0.03, EPS) and _near(hud.end.y, vp.y * (0.03 + 0.61 * 0.2), EPS))
		check("test_hud_rect_%s_ends_above_the_board_band" % vp, hud.end.y <= area.position.y + EPS)
	check("test_board_band_top_144_px_at_720p", _near(ScreenLayout.board_area_rect(Vector2(1280, 720)).position.y, 144.0, EPS))


# 2026-10-31 (user, OSFE reference): the HP panels sit flush in the top corners, 52 px tall at 720p (above a
# v3 hero's head on a 5x5 back row), at most 28 % of the width; the match label spans the gap between them.
func test_corner_hp_panels() -> void:
	for vp: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1024, 768)]:
		var s: float = vp.y / 720.0
		var left: Rect2 = ScreenLayout.hud_panel_rect(vp, 0)
		var right: Rect2 = ScreenLayout.hud_panel_rect(vp, 1)
		check("test_corner_panel_%s_left_flush_top_left" % vp, left.position == Vector2.ZERO)
		check("test_corner_panel_%s_right_flush_top_right" % vp, _near(right.end.x, vp.x, EPS) and _near(right.position.y, 0.0, EPS))
		check("test_corner_panel_%s_height_52_at_720p_got_%s" % [vp, left.size.y], _near(left.size.y, floorf(52.0 * s), EPS) and _near(right.size.y, left.size.y, EPS))
		check("test_corner_panel_%s_width_at_most_28_percent_got_%s" % [vp, left.size.x], left.size.x <= vp.x * 0.28 + EPS and _near(right.size.x, left.size.x, EPS))
		check("test_corner_panel_%s_ends_above_the_board_band" % vp, left.end.y < ScreenLayout.board_area_rect(vp).position.y)
		var title: Rect2 = ScreenLayout.run_match_label_rect(vp)
		check("test_match_label_%s_between_the_panels" % vp, title.position.x >= left.end.x and title.end.x <= right.position.x and title.size.x > 0.0)
	# User 2026-10-31: a short OSFE-like bar, 260 px panel at 720p.
	check("test_corner_panel_1280x720_is_260x52", ScreenLayout.hud_panel_rect(Vector2(1280, 720), 0).size == Vector2(260, 52))

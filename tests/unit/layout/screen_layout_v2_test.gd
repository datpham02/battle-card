extends SceneTree
## Story 044 Part A: control layout v2 geometry (ScreenLayout). Headless suite, deterministic, no I/O.
## Story 047 Part A: the board band starts at 20 % (BOARD_BAND_TOP_RATIO), cells scale by the integer
## art_scale, and the art canvas rect / play rect / to_art / from_art conversions are checked here.
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
	test_slot_rects_arc()
	test_four_slot_bag()
	test_signature_rect_bottom_centre()
	test_center_controls_clear_of_slots_and_stick()
	test_place_hint_and_tag_zone()
	test_menu_reaches_at_most_x960()
	test_pad_inside_stick_zone()
	test_huge_board_falls_back_inside_area()
	test_art_scale_and_rect_1280x720()
	test_art_scale_and_rect_1600x720()
	test_art_scale_and_rect_2400x1080()
	test_art_scale_and_rect_1024x768()
	test_to_art_from_art_round_trip(grids)
	test_board_band_top_20_percent()
	test_corner_hp_panels()
	test_top_row_relics_left_gold_right()
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


func _controls(vp: Vector2) -> Dictionary:
	return {
		"stick_zone": ScreenLayout.stick_zone_rect(vp),
		"awaken": ScreenLayout.signature_rect(vp),
		"confirm": ScreenLayout.confirm_button_rect(vp),
		"cancel": ScreenLayout.cancel_button_rect(vp),
		"focus_bar": ScreenLayout.focus_bar_rect(vp),
		"menu": ScreenLayout.skill_menu_panel_rect(vp),
	}


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
	var slots: Array[Rect2] = ScreenLayout.slot_rects(vp, 4)
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


func test_slot_rects_arc() -> void:
	for vp: Vector2 in VIEWPORTS:
		var rects: Array[Rect2] = ScreenLayout.slot_rects(vp, 3)
		check("test_slot_rects_%s_returns_three" % vp, rects.size() == 3)
		_check_slots_disjoint_on_screen(rects, vp)
		check("test_slot_order_T1_high_right_to_T3_low_left_at_%s" % vp, rects[0].position.y < rects[1].position.y and rects[1].position.y < rects[2].position.y and rects[0].position.x > rects[1].position.x and rects[1].position.x > rects[2].position.x)
		check("test_slot_rects_%s_do_not_overlap_the_stick_zone" % vp, not rects[2].intersects(ScreenLayout.stick_zone_rect(vp)))
	var vp := Vector2(1280, 720)
	var size: Vector2 = ScreenLayout.slot_size(vp)
	check("test_slot_size_1280_is_92.6_by_129.6_got_%s" % size, _near(size.x, 92.57, 0.05) and _near(size.y, 129.6, 0.05))
	var pivot: Vector2 = ScreenLayout.slot_arc_pivot(vp)
	check("test_slot_arc_pivot_1280_is_1260.8_765.4_got_%s" % pivot, _near(pivot.x, 1260.8, 0.05) and _near(pivot.y, 765.4, 0.1))
	var r0: Rect2 = ScreenLayout.slot_rect(vp, 0)
	var r1: Rect2 = ScreenLayout.slot_rect(vp, 1)
	var r2: Rect2 = ScreenLayout.slot_rect(vp, 2)
	# Story 044 Part C arc: 96/126/156 degrees at radius 2.25 x slot height (291.6 px).
	check("test_slot_T1_centre_at_96_degrees_radius_291.6_got_%s" % r0.get_center(), _near(r0.get_center().x, 1230.3, 0.2) and _near(r0.get_center().y, 475.4, 0.2))
	check("test_slot_T2_centre_at_126_degrees_got_%s" % r1.get_center(), _near(r1.get_center().x, 1089.4, 0.2) and _near(r1.get_center().y, 529.5, 0.2))
	check("test_slot_T3_centre_at_156_degrees_got_%s" % r2.get_center(), _near(r2.get_center().x, 994.4, 0.2) and _near(r2.get_center().y, 646.8, 0.2))
	check("test_slot_T3_left_edge_x_948_bottom_712_got_%s" % r2, _near(r2.position.x, 948.1, 0.2) and _near(r2.end.y, 711.6, 0.2))
	check("test_slot_rects_zero_count_is_empty", ScreenLayout.slot_rects(vp, 0).is_empty())


# Every pair of [param rects] disjoint, each inside the viewport, each at least 88 px on its short side.
func _check_slots_disjoint_on_screen(rects: Array[Rect2], vp: Vector2) -> void:
	var n: int = rects.size()
	for i: int in n:
		var r: Rect2 = rects[i]
		check("test_%d_slots_slot_%d_at_%s_at_least_88_px_short_side" % [n, i, vp], minf(r.size.x, r.size.y) >= 88.0)
		check("test_%d_slots_slot_%d_at_%s_inside_viewport" % [n, i, vp], Rect2(Vector2.ZERO, vp).encloses(r))
		check("test_%d_slots_slot_rect_%d_equals_slot_rects_entry_at_%s" % [n, i, vp], ScreenLayout.slot_rect(vp, i) == r)
		for j: int in range(i + 1, n):
			check("test_%d_slots_%d_%d_at_%s_do_not_overlap" % [n, i, j, vp], not r.intersects(rects[j]))


# Story 044 Part C: a relic bag of four. The first three stay on the arc; the fourth (inner-ring fallback) is
# disjoint from them, on screen, >= 88 px, and clear of every centre control, the stick zone and the menu.
func test_four_slot_bag() -> void:
	for vp: Vector2 in VIEWPORTS:
		var four: Array[Rect2] = ScreenLayout.slot_rects(vp, 4)
		check("test_slot_rects_%s_four_returns_four" % vp, four.size() == 4)
		_check_slots_disjoint_on_screen(four, vp)
		var three: Array[Rect2] = ScreenLayout.slot_rects(vp, 3)
		check("test_four_slots_%s_first_three_equal_the_three_slot_arc" % vp, four.slice(0, 3) == three)
		var controls: Dictionary = _controls(vp)
		controls["preview_info"] = ScreenLayout.cut_preview_info_rect(vp)
		controls["swing_info"] = ScreenLayout.cut_swing_info_rect(vp)
		controls["side_tag"] = ScreenLayout.slot_side_left_rect(vp, 4)
		controls["strip"] = ScreenLayout.cut_strip_rect(vp)
		controls["place_hint"] = ScreenLayout.place_hint_rect(vp)
		for name: String in controls:
			check("test_four_slots_%s_slot_4_clear_of_%s" % [vp, name], not four[3].intersects(controls[name]))


func test_signature_rect_bottom_centre() -> void:
	for vp: Vector2 in VIEWPORTS:
		var r: Rect2 = ScreenLayout.signature_rect(vp)
		check("test_signature_rect_%s_is_115_px_square" % vp, _near(r.size.x, 115.2, 0.05) and _near(r.size.y, 115.2, 0.05))
		check("test_signature_rect_%s_centred_horizontally" % vp, _near(r.get_center().x, vp.x * 0.5, EPS))
		check("test_signature_rect_%s_half_a_margin_above_the_bottom" % vp, _near(vp.y - r.end.y, vp.x * 0.03 * 0.5, EPS))
		check("test_signature_button_rect_%s_delegates_to_signature_rect" % vp, ScreenLayout.signature_button_rect(vp) == r)
		check("test_signature_charge_%s_inside_the_button" % vp, r.encloses(ScreenLayout.signature_charge_rect(vp)))


func test_center_controls_clear_of_slots_and_stick() -> void:
	for vp: Vector2 in VIEWPORTS:
		var slots: Array[Rect2] = ScreenLayout.slot_rects(vp, 3)
		var stick: Rect2 = ScreenLayout.stick_zone_rect(vp)
		var controls: Dictionary = _controls(vp)
		controls["preview_info"] = ScreenLayout.cut_preview_info_rect(vp)
		controls["swing_info"] = ScreenLayout.cut_swing_info_rect(vp)
		controls["side_tag"] = ScreenLayout.slot_side_left_rect(vp, 3)
		controls["strip"] = ScreenLayout.cut_strip_rect(vp)
		controls["focus_tag"] = CutHudView.focus_tag_rect(vp)
		for name: String in controls:
			var r: Rect2 = controls[name]
			if name == "stick_zone":
				continue
			check("test_%s_at_%s_not_empty" % [name, vp], r.size.x > 0.0 and r.size.y > 0.0)
			check("test_%s_at_%s_clear_of_the_stick_zone" % [name, vp], not r.intersects(stick))
			for i: int in slots.size():
				check("test_%s_at_%s_clear_of_slot_%d" % [name, vp, i], not r.intersects(slots[i]))
			check("test_%s_at_%s_inside_the_viewport" % [name, vp], Rect2(Vector2.ZERO, vp).encloses(r))
		for name: String in ["confirm", "cancel", "awaken"]:
			var r: Rect2 = controls[name]
			check("test_%s_at_%s_at_least_88_px_each_side" % [name, vp], r.size.x >= 88.0 and r.size.y >= 88.0)
		check("test_confirm_awaken_cancel_at_%s_do_not_overlap_each_other" % vp, not controls["confirm"].intersects(controls["awaken"]) and not controls["cancel"].intersects(controls["awaken"]) and not controls["confirm"].intersects(controls["cancel"]))
		check("test_menu_at_%s_does_not_cover_the_cancel_button" % vp, not controls["menu"].intersects(controls["cancel"]))
		check("test_focus_bar_at_%s_clear_of_confirm_and_below_76_percent" % vp, not controls["focus_bar"].intersects(controls["confirm"]) and controls["focus_bar"].position.y >= vp.y * 0.76)
		check("test_rotate_button_at_%s_inside_the_stick_zone" % vp, stick.encloses(ScreenLayout.rotate_button_rect(vp)) and ScreenLayout.rotate_button_rect(vp).size.x >= 88.0)


# Story 044 Part C: the placement hint sits in a band at the top of the Rotate button (it no longer shares the
# 30 px tag zone); the FULL label (left-aligned) and the focus tag (right-aligned) share the tag zone without overlap.
func test_place_hint_and_tag_zone() -> void:
	for vp: Vector2 in VIEWPORTS:
		var hint: Rect2 = ScreenLayout.place_hint_rect(vp)
		var rotate: Rect2 = ScreenLayout.rotate_button_rect(vp)
		check("test_place_hint_at_%s_inside_the_rotate_button_top_band" % vp, rotate.encloses(hint) and _near(hint.position.y, rotate.position.y, EPS) and hint.size.y >= 30.0 and hint.size.y <= rotate.size.y * 0.2)
		for name: String in ["confirm", "cancel", "awaken", "menu", "focus_bar"]:
			check("test_place_hint_at_%s_clear_of_%s" % [vp, name], not hint.intersects(_controls(vp)[name]))
		for s: Rect2 in ScreenLayout.slot_rects(vp, 4):
			check("test_place_hint_at_%s_clear_of_slot_%s" % [vp, s.position], not hint.intersects(s))
		var zone: Rect2 = ScreenLayout.slot_side_left_rect(vp, 4)
		var tag: Rect2 = CutHudView.focus_tag_rect(vp)
		check("test_focus_tag_at_%s_inside_the_tag_zone_got_%s_in_%s" % [vp, tag, zone], zone.encloses(tag) and tag.size.y >= 20.0)
		check("test_focus_tag_at_%s_right_aligned" % vp, _near(tag.end.x, zone.end.x, EPS))
		var font: Font = ThemeDB.fallback_font
		for word: String in ["ĐẦY", "FULL"]:
			var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, HoldSlotsView.FULL_FONT_SIZE).x
			check("test_full_label_%s_at_%s_left_of_the_focus_tag" % [word, vp], zone.position.x + width < tag.position.x)


func test_menu_reaches_at_most_x960() -> void:
	var vp := Vector2(1280, 720)
	var menu: Rect2 = ScreenLayout.skill_menu_panel_rect(vp)
	check("test_menu_panel_1280_right_edge_at_most_960_got_%s" % menu.end.x, menu.end.x <= 960.0)
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, 4)
	var ok_all: bool = rects.size() == 4
	for r: Rect2 in rects:
		ok_all = ok_all and r.size.x >= 88.0 and r.size.y >= 88.0 and menu.encloses(r)
	check("test_skill_menu_four_cards_1280_each_at_least_88_px_inside_the_panel_got_%s" % [rects], ok_all)
	var bar: Rect2 = ScreenLayout.skill_menu_bar_rect(vp)
	check("test_skill_menu_bar_inside_the_panel", menu.encloses(bar))
	check("test_skill_menu_panel_below_the_lowest_narrow_row_76_percent", menu.position.y >= vp.y * 0.76)


func test_pad_inside_stick_zone() -> void:
	for vp: Vector2 in VIEWPORTS:
		var zone: Rect2 = ScreenLayout.stick_zone_rect(vp)
		var bounds: Rect2 = ScreenLayout.dpad_bounds(vp)
		var rects: Dictionary = ScreenLayout.dpad_rects(vp)
		check("test_pad_bounds_%s_inside_the_stick_zone" % vp, zone.grow(EPS).encloses(bounds))
		check("test_pad_%s_has_four_directions" % vp, rects.size() == 4)
		var ok_all: bool = true
		for dir: Vector2i in rects:
			var r: Rect2 = rects[dir]
			ok_all = ok_all and bounds.grow(EPS).encloses(r) and r.size.x >= 86.0
		check("test_pad_buttons_%s_inside_bounds_and_at_least_86_px" % vp, ok_all)
		check("test_pad_%s_up_above_down_left_left_of_right" % vp, rects[Vector2i.UP].position.y < rects[Vector2i.DOWN].position.y and rects[Vector2i.LEFT].position.x < rects[Vector2i.RIGHT].position.x)


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
# v3 hero's head on a 5x5 back row), at most 28 % of the width; the match label spans the gap between them and
# the deck label sits right of the pause tile, left of the boss panel.
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
		var deck: Rect2 = ScreenLayout.run_deck_label_rect(vp)
		var pause: Rect2 = ScreenLayout.pause_button_rect(vp)
		check("test_deck_label_%s_right_of_the_pause_centre_left_of_the_boss_panel" % vp, deck.position.x > pause.get_center().x and deck.end.x <= right.position.x and deck.size.x > 0.0)
	# User 2026-10-31: a short OSFE-like bar, 260 px panel at 720p.
	check("test_corner_panel_1280x720_is_260x52", ScreenLayout.hud_panel_rect(Vector2(1280, 720), 0).size == Vector2(260, 52))


# 2026-10-31 (user: "debuff hay buff thì hiện ở góc trái, tiền góc phải"): the relic row starts at the top-left
# corner, on the top HUD row (under the match label, above the board band), and ends before the Resonant-shape
# tile; the top row is the same band the gold and the boss's held points use.
func test_top_row_relics_left_gold_right() -> void:
	for vp: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1024, 768)]:
		var s: float = vp.y / 720.0
		var relics: Rect2 = ScreenLayout.hud_relic_strip_rect(vp)
		var row: Rect2 = ScreenLayout.hud_top_row_rect(vp)
		check("test_relic_row_%s_starts_at_the_left_corner" % vp, _near(relics.position.x, floorf(ScreenLayout.HUD_TOP_ROW_INSET_PX * s), EPS))
		check("test_relic_row_%s_on_the_top_row" % vp, _near(relics.position.y, row.position.y, EPS) and _near(relics.size.y, row.size.y, EPS))
		check("test_relic_row_%s_below_the_match_label" % vp, relics.position.y >= ScreenLayout.run_match_label_rect(vp).end.y - EPS)
		check("test_relic_row_%s_above_the_board_band" % vp, row.end.y < ScreenLayout.board_area_rect(vp).position.y)
		check("test_relic_row_%s_ends_before_the_featured_tile" % vp, relics.end.x < ScreenLayout.featured_icon_rect(vp).position.x and relics.size.x > 0.0)

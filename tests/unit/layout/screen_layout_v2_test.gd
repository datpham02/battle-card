extends SceneTree
## Story 044 Part A: control layout v2 geometry (ScreenLayout). Headless suite, deterministic, no I/O.
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
	print("FAILS=%d" % fails)
	quit(fails)


func _art(grid: BoardGrid, vp: Vector2) -> Vector2:
	return ScreenLayout.cell_size(grid, vp) / (vp.y / 360.0)


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func test_cell_table_matches_quick_spec(grids: Dictionary) -> void:
	var vp := Vector2(1280, 720)
	# Quick spec 2.1: 3x3 64x46, 5x5 48x34 (+-1), 6x6 crystal 49x35, 7x6 crystal 42x30, cross 60x43.
	# Ring: the spec's 49x35 reached slot T1 (Story 044 Part C); the slot-clearance rule shrinks it to 45x32.
	var table: Dictionary = {
		"3x3": Vector2(64, 46), "5x5": Vector2(48, 34), "cross4x4": Vector2(60, 43),
		"ring6x5": Vector2(45, 32), "crystal6x6": Vector2(49, 35), "crystal7x6": Vector2(42, 30),
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
			check("test_board_%s_at_%s_top_not_above_15_2_percent" % [id, vp], board.position.y >= vp.y * 0.152 - EPS)
	var vp := Vector2(1280, 720)
	var five: Rect2 = ScreenLayout.board_rect(grids["5x5"], vp)
	check("test_row_rule_5x5_wide_rows_end_at_or_above_64_percent", five.end.y <= vp.y * 0.64 + EPS)
	var crystal: BoardGrid = grids["crystal6x6"]
	var crystal_board: Rect2 = ScreenLayout.board_rect(crystal, vp)
	check("test_row_rule_crystal_overflows_below_64_percent_for_its_narrow_bottom_row", crystal_board.end.y > vp.y * 0.64 + EPS and crystal_board.end.y <= vp.y * 0.76 + EPS)
	var three: Rect2 = ScreenLayout.board_rect(grids["3x3"], vp)
	check("test_board_3x3_centred_in_band_below_64_percent", three.end.y <= vp.y * 0.64 and three.position.y > vp.y * 0.152)


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
	check("test_board_area_top_is_15_2_percent", _near(area.position.y, 720.0 * 0.152, EPS))


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

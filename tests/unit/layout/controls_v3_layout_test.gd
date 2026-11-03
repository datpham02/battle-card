extends SceneTree
## Controls v3 geometry (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md; ScreenLayout, pure, headless): the
## bottom-left row [Tung phép 100][Xoay 64][Hủy 72] and the bag's 64 px sockets share one bottom edge and one 64 px
## height with 8-12 px gaps; every control's invisible hit rect encloses its visual, is >= 96 px tall (and >= 64 px
## wide), stays on screen and overlaps no other hit rect; no HUD element overlaps the board (every arenas.json shape and
## the layout test grids); in idle the bag and the Awaken button keep clear of the stick zone; the top-left holds the
## relic row over the buff / debuff row over the cooldown column; top-right: the pause tile against the corner, the gold
## left of it.
## Run: godot --headless --path . -s res://tests/unit/layout/controls_v3_layout_test.gd

const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]
const EPS: float = 0.51

var fails: int = 0


func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	for vp: Vector2 in VIEWPORTS:
		test_bottom_rows_share_a_bottom_edge_and_height(vp)
		test_sizes_match_the_spec(vp)
		test_hit_rects_enclose_visuals_and_never_overlap(vp)
		test_idle_controls_clear_of_the_stick_zone(vp)
		test_top_left_relics_statuses_cooldowns(vp)
		test_top_right_pause_is_right_most_gold_left_of_it(vp)
	test_no_hud_element_overlaps_the_board()
	test_row_hit_rects_split_gaps_in_the_middle()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _s(vp: Vector2) -> float:
	return vp.y / 720.0


func test_bottom_rows_share_a_bottom_edge_and_height(vp: Vector2) -> void:
	var left: Array[Rect2] = [ScreenLayout.confirm_button_rect(vp), ScreenLayout.rotate_button_rect(vp), ScreenLayout.cancel_button_rect(vp)]
	var bag: Array[Rect2] = ScreenLayout.slot_rects(vp, 3)
	var bottom: float = left[0].end.y
	var h: float = left[0].size.y
	var ok: bool = true
	for r: Rect2 in left + bag:
		ok = ok and absf(r.end.y - bottom) <= EPS and absf(r.size.y - h) <= EPS
	check("test_bottom_left_row_and_bag_share_bottom_edge_and_height_at_%s" % vp, ok, "bottom %s h %s" % [bottom, h])
	check("test_bottom_edge_inset_12px_at_%s" % vp, absf(vp.y - bottom - 12.0 * _s(vp)) <= EPS, str(bottom))
	for row: Array[Rect2] in [left, bag]:
		for i: int in range(1, row.size()):
			var gap: float = row[i].position.x - row[i - 1].end.x
			check("test_row_gap_8_to_12_px_at_%s_got_%s" % [vp, gap], gap >= 8.0 * _s(vp) - EPS and gap <= 12.0 * _s(vp) + EPS)
	check("test_tung_phep_against_the_left_corner_at_%s" % vp, absf(left[0].position.x - 12.0 * _s(vp)) <= EPS)
	check("test_bag_against_the_right_corner_at_%s" % vp, absf(vp.x - bag[2].end.x - 12.0 * _s(vp)) <= EPS)
	check("test_order_tung_phep_xoay_huy_left_to_right_at_%s" % vp, left[0].end.x < left[1].position.x and left[1].end.x < left[2].position.x)


func test_sizes_match_the_spec(vp: Vector2) -> void:
	var s: float = _s(vp)
	check("test_tung_phep_100x64_at_%s" % vp, _size_is(ScreenLayout.confirm_button_rect(vp), Vector2(100, 64) * s))
	check("test_xoay_64x64_at_%s" % vp, _size_is(ScreenLayout.rotate_button_rect(vp), Vector2(64, 64) * s))
	check("test_huy_72x64_at_%s" % vp, _size_is(ScreenLayout.cancel_button_rect(vp), Vector2(72, 64) * s))
	for r: Rect2 in ScreenLayout.slot_rects(vp, 3):
		check("test_socket_64x64_at_%s" % vp, _size_is(r, Vector2(64, 64) * s), str(r))
	check("test_four_sockets_one_row_on_screen_at_%s" % vp, _one_row_on_screen(ScreenLayout.slot_rects(vp, 4), vp))
	check("test_slot_rect_default_count_is_three_at_%s" % vp, ScreenLayout.slot_rect(vp, 1) == ScreenLayout.slot_rects(vp, 3)[1])
	check("test_slot_rects_zero_count_is_empty", ScreenLayout.slot_rects(vp, 0).is_empty())


func _size_is(r: Rect2, want: Vector2) -> bool:
	return absf(r.size.x - want.x) <= EPS and absf(r.size.y - want.y) <= EPS


func _one_row_on_screen(rects: Array[Rect2], vp: Vector2) -> bool:
	var ok: bool = true
	for i: int in rects.size():
		ok = ok and Rect2(Vector2.ZERO, vp).encloses(rects[i])
		if i > 0:
			ok = ok and rects[i].position.x > rects[i - 1].end.x and absf(rects[i].position.y - rects[0].position.y) <= EPS
	return ok


# name -> [visual, hit]
func _controls(vp: Vector2, sockets: int) -> Dictionary:
	var out: Dictionary = {
		"tung_phep": [ScreenLayout.confirm_button_rect(vp), ScreenLayout.confirm_hit_rect(vp)],
		"xoay": [ScreenLayout.rotate_button_rect(vp), ScreenLayout.rotate_hit_rect(vp)],
		"huy": [ScreenLayout.cancel_button_rect(vp), ScreenLayout.cancel_hit_rect(vp)],
		"awaken": [ScreenLayout.signature_rect(vp), ScreenLayout.signature_button_rect(vp)],
		"pause": [ScreenLayout.pause_tile_rect(vp), ScreenLayout.pause_button_rect(vp)],
	}
	var visuals: Array[Rect2] = ScreenLayout.slot_rects(vp, sockets)
	var hits: Array[Rect2] = ScreenLayout.slot_hit_rects(vp, sockets)
	for i: int in visuals.size():
		out["socket_%d" % i] = [visuals[i], hits[i]]
	return out


func test_hit_rects_enclose_visuals_and_never_overlap(vp: Vector2) -> void:
	var s: float = _s(vp)
	for sockets: int in [3, 4]:
		var controls: Dictionary = _controls(vp, sockets)
		var names: Array = controls.keys()
		for name: String in names:
			var visual: Rect2 = controls[name][0]
			var hit: Rect2 = controls[name][1]
			check("test_%s_hit_encloses_visual_%d_sockets_at_%s" % [name, sockets, vp], hit.encloses(visual), "%s / %s" % [hit, visual])
			check("test_%s_hit_on_screen_at_%s" % [name, vp], Rect2(Vector2.ZERO, vp).encloses(hit), str(hit))
			check("test_%s_hit_at_least_96_tall_64_wide_at_%s" % [name, vp], hit.size.y >= 96.0 * s - EPS and hit.size.x >= 64.0 * s - EPS, str(hit.size))
		for i: int in names.size():
			for j: int in range(i + 1, names.size()):
				var a: Rect2 = controls[names[i]][1]
				var b: Rect2 = controls[names[j]][1]
				check("test_hits_%s_and_%s_do_not_overlap_%d_sockets_at_%s" % [names[i], names[j], sockets, vp], not a.intersects(b), "%s / %s" % [a, b])
	# The menu's Hủy takes the place of Tung phép: its hit rect is that one.
	check("test_menu_cancel_hit_is_tung_phep_hit_at_%s" % vp, ScreenLayout.cancel_hit_rect(vp, true) == ScreenLayout.confirm_hit_rect(vp))
	check("test_tung_phep_hit_reaches_the_left_edge_at_%s" % vp, ScreenLayout.confirm_hit_rect(vp).position.x == 0.0)
	check("test_last_socket_hit_reaches_the_right_edge_at_%s" % vp, absf(ScreenLayout.slot_hit_rects(vp, 3)[2].end.x - vp.x) <= EPS)


func test_idle_controls_clear_of_the_stick_zone(vp: Vector2) -> void:
	var stick: Rect2 = ScreenLayout.stick_zone_rect(vp)
	for r: Rect2 in ScreenLayout.slot_hit_rects(vp, 4):
		check("test_socket_hit_clear_of_the_stick_zone_at_%s" % vp, not r.intersects(stick), str(r))
	check("test_awaken_clear_of_the_stick_zone_at_%s" % vp, not ScreenLayout.signature_rect(vp).intersects(stick))
	# The placing row replaces the stick (it is drawn only while a block is placed / in the place window).
	for r: Rect2 in ScreenLayout.placing_row_hit_rects(vp):
		check("test_placing_row_hit_inside_the_stick_zone_columns_at_%s" % vp, r.end.x <= stick.end.x + EPS, str(r))
	check("test_cooldown_column_clear_of_the_stick_zone_at_%s" % vp, not ScreenLayout.cooldown_column_rect(vp).intersects(stick))


func test_top_left_relics_statuses_cooldowns(vp: Vector2) -> void:
	var s: float = _s(vp)
	var relics: Rect2 = ScreenLayout.hud_relic_strip_rect(vp)
	var statuses: Rect2 = ScreenLayout.hud_status_row_rect(vp)
	var column: Rect2 = ScreenLayout.cooldown_column_rect(vp)
	# 2026-11-03: the relic row sits under the player's corner panel (hud.player_panel), still in the top-left corner.
	var panel: Rect2 = ScreenLayout.hud_player_panel_rect(vp)
	check("test_relic_row_under_the_player_panel_at_%s" % vp, absf(relics.position.x - floorf(12.0 * s)) <= EPS and relics.position.y >= panel.end.y
		and relics.position.y <= panel.end.y + 12.0 * s)
	check("test_status_row_under_the_relics_at_%s" % vp, statuses.position.y >= relics.end.y and absf(statuses.position.x - relics.position.x) <= EPS)
	check("test_status_row_40px_tall_at_%s" % vp, absf(statuses.size.y - 40.0 * s) <= EPS)
	check("test_cooldown_column_under_the_status_row_at_%s" % vp, column.position.y >= statuses.end.y)
	var icons: Array[Rect2] = ScreenLayout.status_icon_rects(vp, 50)
	var ok: bool = icons.size() >= 4 and icons.size() < 50
	for i: int in icons.size():
		ok = ok and statuses.encloses(icons[i]) and is_equal_approx(icons[i].size.x, icons[i].size.y)
		if i > 0:
			ok = ok and icons[i].position.x > icons[i - 1].end.x
	check("test_status_icons_left_to_right_inside_the_row_at_least_4_at_%s" % vp, ok, "%d icons" % icons.size())
	check("test_status_icons_count_follows_the_request_at_%s" % vp, ScreenLayout.status_icon_rects(vp, 3).size() == 3 and ScreenLayout.status_icon_rects(vp, 0).is_empty())
	check("test_top_left_clear_of_the_top_right_at_%s" % vp, relics.end.x < ScreenLayout.hud_gold_rect(vp).position.x and statuses.end.x < ScreenLayout.pause_button_rect(vp).position.x)


func test_top_right_pause_is_right_most_gold_left_of_it(vp: Vector2) -> void:
	var s: float = _s(vp)
	var tile: Rect2 = ScreenLayout.pause_tile_rect(vp)
	var hit: Rect2 = ScreenLayout.pause_button_rect(vp)
	var gold: Rect2 = ScreenLayout.hud_gold_rect(vp)
	check("test_pause_tile_against_the_top_right_corner_at_%s" % vp, absf(vp.x - tile.end.x - 12.0 * s) <= EPS and absf(tile.position.y - 12.0 * s) <= EPS)
	check("test_pause_hit_is_the_corner_square_at_%s" % vp, absf(hit.end.x - vp.x) <= EPS and hit.position.y == 0.0 and hit.encloses(tile))
	check("test_gold_left_of_the_pause_at_%s" % vp, gold.end.x <= tile.position.x and gold.end.x >= tile.position.x - 12.0 * s - EPS, "%s / %s" % [gold, tile])
	check("test_gold_on_the_pause_row_at_%s" % vp, absf(gold.get_center().y - tile.get_center().y) <= EPS)
	var right_most: float = maxf(maxf(ScreenLayout.hud_relic_strip_rect(vp).end.x, ScreenLayout.hud_status_row_rect(vp).end.x), gold.end.x)
	check("test_pause_is_the_right_most_top_element_at_%s" % vp, tile.position.x >= right_most)
	check("test_top_row_band_is_the_pause_tile_at_%s" % vp, ScreenLayout.hud_top_row_rect(vp).position.y == tile.position.y and ScreenLayout.hud_top_row_rect(vp).size.y == tile.size.y)


# Every HUD rect that can be on screen during a match (the hit rects of the controls, the corners, the cooldown column, the
# placing hint), against every real cell of every arenas.json shape and the layout test grids.
func test_no_hud_element_overlaps_the_board() -> void:
	var grids: Dictionary = {
		"3x3": BoardGrid.new(3, 3), "5x5": BoardGrid.new(5, 5), "4x4": BoardGrid.new(4, 4), "6x4": BoardGrid.new(6, 4),
	}
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	for id: String in library.shape_ids():
		grids["arenas.json:" + id] = ArenaValidator.build_grid(library.get_shape(id))
	check("test_arenas_json_has_shapes_to_check", grids.size() > 4)
	for vp: Vector2 in VIEWPORTS:
		var hud: Dictionary = {}
		var controls: Dictionary = _controls(vp, 4)
		for name: String in controls:
			hud[name] = controls[name][1]
		hud["relics"] = ScreenLayout.hud_relic_strip_rect(vp)
		hud["statuses"] = ScreenLayout.hud_status_row_rect(vp)
		hud["cooldowns"] = ScreenLayout.cooldown_column_rect(vp)
		hud["gold"] = ScreenLayout.hud_gold_rect(vp)
		hud["place_hint"] = ScreenLayout.place_hint_rect(vp)
		for id: String in grids:
			var g: BoardGrid = grids[id]
			var hit: String = ""
			for cell: Vector2i in g.player_cells() + g.enemy_cells():
				var r: Rect2 = ScreenLayout.cell_rect(g, vp, cell)
				for name: String in hud:
					if r.intersects(hud[name]):
						hit = "%s (cell %s)" % [name, cell]
			check("test_board_%s_at_%s_clear_of_every_hud_element%s" % [id, vp, "" if hit.is_empty() else " (hits " + hit + ")"], hit.is_empty())


func test_row_hit_rects_split_gaps_in_the_middle() -> void:
	var vp := Vector2(1280, 720)
	var hits: Array[Rect2] = ScreenLayout.placing_row_hit_rects(vp)
	check("test_tung_phep_hit_0_to_117_at_720p", absf(hits[0].position.x) <= EPS and absf(hits[0].end.x - 117.0) <= EPS, str(hits[0]))
	check("test_xoay_hit_117_to_191_at_720p", absf(hits[1].position.x - 117.0) <= EPS and absf(hits[1].end.x - 191.0) <= EPS, str(hits[1]))
	check("test_huy_hit_starts_at_191_at_least_88_wide_at_720p", absf(hits[2].position.x - 191.0) <= EPS and hits[2].size.x >= 88.0, str(hits[2]))
	check("test_row_hits_624_to_720_at_720p", absf(hits[0].position.y - 624.0) <= EPS and absf(hits[0].end.y - 720.0) <= EPS, str(hits[0]))

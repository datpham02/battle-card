extends SceneTree
## Voxel field-piece pickups (design/art/forest-integration-pickup-plan-2026-11-05.md step 1): VoxelPiece (pure
## renderer of the Ancient Stone Sigil, 2026-11-06) and PickupLayer (anchor, crack stage, crumble). Headless: frames
## are palette buffers.
## Run: godot --headless --path . -s res://tests/unit/battle/pickup_voxel_test.gd

const VP: Vector2 = Vector2(1280, 720)
## ADR-0002 floor back ratio (combat.json floor.perspective.back_ratio).
const BACK_RATIO: float = 0.82
## Edge used for the cube-count check: large enough that each cube's top is several px.
const COUNT_EDGE: int = 6
## The Odd Block fixture (Story 041, 7 cells, irregular).
const ODD_CELLS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(1, 2)]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_anchor_is_the_perspective_cell_centre_on_several_arenas()
	test_block_is_centred_on_its_anchor()
	test_frame_draws_the_exact_shape_front_facing()
	test_cube_count_matches_the_piece_cell_count()
	test_crack_stage_by_ratio_thresholds()
	test_crack_stages_change_the_frame_but_not_the_colour()
	test_crumble_runs_in_place_then_leaves_nothing()
	test_sigil_lies_still_with_no_float_bob_or_shadow()
	test_every_square_has_light_upper_left_and_dark_lower_right_edges()
	test_smallest_cell_still_reads()
	test_piece_width_is_60_to_75_percent_of_the_cell()
	test_piece_height_stays_within_the_cell()
	test_squares_squash_to_the_cell_aspect_and_keep_the_shape()
	test_warped_layer_anchors_in_flat_floor_space()
	test_weathered_stone_motif_pits_and_worn_corners()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _grid(shape: String) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, ArenaLibrary.load_from_file(), 1)


func test_anchor_is_the_perspective_cell_centre_on_several_arenas() -> void:
	for shape: String in ["square", "boss_hall", "cross"]:
		var grid: BoardGrid = _grid(shape)
		_check("test_%s_grid_built" % shape, grid != null)
		if grid == null:
			continue
		var geo: BoardGeometry = BoardGeometry.make(grid, VP, BACK_RATIO)
		_check("test_%s_geometry_warped" % shape, geo.is_warped())
		var ok: bool = true
		var worst: float = 0.0
		var cells: Array[Vector2i] = grid.player_cells() + grid.enemy_cells()
		for cell: Vector2i in cells:
			var anchor: Vector2i = PickupLayer.anchor_art(geo, cell)
			var centre: Vector2 = geo.warp_art(Rect2(geo.cell_art_rect(cell)).get_center())
			var d: float = (Vector2(anchor) + Vector2(0.5, 0.5)).distance_to(centre)
			worst = maxf(worst, d)
			ok = ok and d <= 1.0 and Geometry2D.is_point_in_polygon(Vector2(anchor) + Vector2(0.5, 0.5), geo.cell_art_polygon(cell))
		_check("test_%s_anchor_within_1px_of_warped_centre_on_%d_cells" % [shape, cells.size()], ok, "worst=%.2f" % worst)
	# cross has missing cells: none of them is a board cell, the anchors above only cover real ones.
	var cross: BoardGrid = _grid("cross")
	if cross != null:
		var missing: int = 0
		for y: int in cross.rows:
			for x: int in cross.total_cols:
				if not cross.is_in_board(Vector2i(x, y)):
					missing += 1
		_check("test_cross_has_missing_cells", missing > 0, "missing=%d" % missing)
	# Flat: the anchor is the plain centre.
	var flat: BoardGeometry = BoardGeometry.make(_grid("square"), VP, FloorPerspective.OFF)
	var r: Rect2i = flat.cell_art_rect(Vector2i(1, 1))
	_check("test_flat_anchor_is_the_cell_rect_centre", PickupLayer.anchor_art(flat, Vector2i(1, 1)) == Vector2i(Rect2(r).get_center().floor()))


# 2026-11-06: the body is centred on the frame anchor within 1 px.
func test_block_is_centred_on_its_anchor() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	for id: String in ["mono", "square", "plus5", "bar5", "l3", "t4"]:
		var cells: Array[Vector2i] = lib.make_piece(id, 0).relative_cells()
		var f: Dictionary = VoxelPiece.render_frame(cells, 5)
		var r: Rect2i = VoxelPiece.used_rect(f)
		var c: Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
		var d: Vector2 = (c - (Vector2(f["anchor"]) + Vector2(0.5, 0.5))).abs()
		_check("test_%s_body_centred_on_anchor" % id, d.x <= 1.0 and d.y <= 1.0, "d=%s" % str(d))


# 2026-11-06 (user: identify the exact shape before picking up): the centre pixel of every square of the piece is
# face and the centre of every empty square of its bounding box is not, in the hand orientation.
func test_frame_draws_the_exact_shape_front_facing() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var bad: Array[String] = []
	var edge: int = 6
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pieces.json"))
	var checked: int = 0
	for sh: Dictionary in parsed["shapes"]:
		var id: String = str(sh["id"])
		var cells: Array[Vector2i] = lib.make_piece(id, 0).relative_cells()
		var f: Dictionary = VoxelPiece.render_frame(cells, edge)
		var px: PackedByteArray = f["px"]
		var size: Vector2i = f["size"]
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-(1 << 20), -(1 << 20))
		for c: Vector2i in cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		for y: int in range(lo.y, hi.y + 1):
			for x: int in range(lo.x, hi.x + 1):
				@warning_ignore("integer_division")
				var p := Vector2i(VoxelPiece.PAD + (x - lo.x) * edge + (edge + 1) / 2, VoxelPiece.PAD + (y - lo.y) * edge + (edge + 1) / 2)
				var v: int = px[p.y * size.x + p.x]
				if cells.has(Vector2i(x, y)) != (v == VoxelPiece.PX_TOP):
					bad.append("%s (%d,%d) px=%d" % [id, x, y, v])
		checked += 1
	_check("test_every_square_and_gap_of_%d_shapes_reads_in_the_frame" % checked, bad.is_empty() and checked == 19, str(bad))


func test_cube_count_matches_the_piece_cell_count() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var ids: Array[String] = []
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pieces.json"))
	for s: Dictionary in parsed["shapes"]:
		ids.append(str(s["id"]))
	_check("test_pieces_json_has_19_shapes", ids.size() == 19, "got %d" % ids.size())
	var bad: Array[String] = []
	for id: String in ids:
		for rot: int in 4:
			var cells: Array[Vector2i] = lib.make_piece(id, rot).relative_cells()
			var f: Dictionary = VoxelPiece.render_frame(cells, COUNT_EDGE)
			var n: int = VoxelPiece.count_regions(f, VoxelPiece.PX_TOP)
			if n != cells.size():
				bad.append("%s r%d: %d tops for %d cells" % [id, rot, n, cells.size()])
	_check("test_every_shape_and_rotation_draws_one_top_per_cube", bad.is_empty(), str(bad))
	var odd: Dictionary = VoxelPiece.render_frame(ODD_CELLS, COUNT_EDGE)
	_check("test_odd_block_7_cells_draws_7_tops", VoxelPiece.count_squares(odd) == ODD_CELLS.size())
	# Silhouette outline: every coloured pixel touching transparency is impossible (ink in between).
	var px: PackedByteArray = odd["px"]
	var size: Vector2i = odd["size"]
	var open_edge: int = 0
	for y: int in size.y:
		for x: int in size.x:
			var v: int = px[y * size.x + x]
			if v == VoxelPiece.PX_NONE or v == VoxelPiece.PX_INK:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= size.x or q.y >= size.y or px[q.y * size.x + q.x] == VoxelPiece.PX_NONE:
					open_edge += 1
	_check("test_silhouette_fully_outlined_in_ink", open_edge == 0, "open=%d" % open_edge)


func test_crack_stage_by_ratio_thresholds() -> void:
	var cases: Array = [[1.0, 0], [FieldDropsView.FRESH_RATIO, 0], [FieldDropsView.FRESH_RATIO - 0.001, 1],
		[FieldDropsView.WARN_RATIO, 1], [FieldDropsView.WARN_RATIO - 0.001, 2], [0.0, 2]]
	for c: Array in cases:
		_check("test_ratio_%.3f_is_stage_%d" % [c[0], c[1]], VoxelPiece.crack_stage(float(c[0])) == int(c[1]), "got %d" % VoxelPiece.crack_stage(float(c[0])))


func _count(f: Dictionary, index: int) -> int:
	return (f["px"] as PackedByteArray).count(index)


func _opaque(f: Dictionary) -> int:
	return (f["px"] as PackedByteArray).size() - _count(f, VoxelPiece.PX_NONE)


func test_crack_stages_change_the_frame_but_not_the_colour() -> void:
	var cells: Array[Vector2i] = PieceLibrary.load_from_file().make_piece("l4", 0).relative_cells()
	var intact: Dictionary = VoxelPiece.render_frame(cells, 6, VoxelPiece.STAGE_INTACT, 11)
	var hair: Dictionary = VoxelPiece.render_frame(cells, 6, VoxelPiece.STAGE_HAIRLINE, 11)
	var deep: Dictionary = VoxelPiece.render_frame(cells, 6, VoxelPiece.STAGE_DEEP, 11)
	_check("test_hairline_adds_ink_inside", _count(hair, VoxelPiece.PX_INK) > _count(intact, VoxelPiece.PX_INK))
	_check("test_hairline_keeps_the_silhouette", _opaque(hair) == _opaque(intact))
	_check("test_deep_has_more_cracks_than_hairline", _count(deep, VoxelPiece.PX_TOP) < _count(hair, VoxelPiece.PX_TOP))
	var chipped: bool = false
	var ip: PackedByteArray = intact["px"]
	var dp: PackedByteArray = deep["px"]
	for i: int in ip.size():
		if ip[i] != VoxelPiece.PX_NONE and ip[i] != VoxelPiece.PX_INK and dp[i] == VoxelPiece.PX_NONE:
			chipped = true
	_check("test_deep_chips_pixels_off_the_edge", chipped)
	_check("test_same_seed_same_cracks", VoxelPiece.render_frame(cells, 6, VoxelPiece.STAGE_DEEP, 11)["px"] == dp)
	var img0: Image = VoxelPiece.to_image(intact, VoxelPiece.RAMP_NORMAL)
	var img2: Image = VoxelPiece.to_image(deep, VoxelPiece.RAMP_NORMAL)
	var top: Color = VoxelPiece.ramp(VoxelPiece.RAMP_NORMAL)["top"]
	_check("test_block_colour_fixed_across_stages", _has_colour(img0, top) and _has_colour(img2, top))


func _has_colour(img: Image, c: Color) -> bool:
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).is_equal_approx(c):
				return true
	return false


# 2026-11-06 (no particles): an expired piece crumbles in place, its squares vanishing one by one, then nothing.
func test_crumble_runs_in_place_then_leaves_nothing() -> void:
	var total: float = VoxelPiece.shatter_sec()
	_check("test_crumble_lasts_under_half_a_second", total > 0.2 and total <= 0.5, "%.2f" % total)
	var n: int = 5
	var start: Array[int] = VoxelPiece.crumble_left(0.0, n, 3)
	var mid: Array[int] = VoxelPiece.crumble_left(total * 0.5, n, 3)
	_check("test_crumble_starts_whole", start.size() == n)
	_check("test_crumble_loses_squares_one_by_one", mid.size() > 0 and mid.size() < n, "%d of %d" % [mid.size(), n])
	var shrinking: bool = true
	var prev: int = n
	for i: int in 20:
		var left: int = VoxelPiece.crumble_left(total * float(i) / 20.0, n, 3).size()
		shrinking = shrinking and left <= prev
		prev = left
	_check("test_crumble_never_regrows", shrinking)
	_check("test_crumble_same_seed_same_order", VoxelPiece.crumble_left(total * 0.5, n, 3) == mid)
	_check("test_nothing_left_after_the_crumble", VoxelPiece.crumble_left(total, n, 3).is_empty() and VoxelPiece.crumble_left(total + 1.0, n, 3).is_empty())
	# Layer: a running crumble ends after its time.
	var layer := PickupLayer.new()
	var combat := CombatView.new()
	layer._combat = combat
	layer._shatters.append({"anchor": Vector2i(100, 100), "age": 0.0, "seed": 4, "ramp": VoxelPiece.RAMP_NORMAL,
		"frame": VoxelPiece.render_frame([Vector2i(0, 0)] as Array[Vector2i], 6), "squares": [Rect2i(1, 1, 7, 7)]})
	layer.advance(total * 0.5)
	_check("test_layer_crumble_running_mid_way", layer.get_shatters().size() == 1)
	layer.advance(total)
	_check("test_layer_crumble_gone_after_its_time", layer.get_shatters().is_empty())
	layer._combat = null
	combat.free()
	layer.free()


# 2026-11-06 (redesign: no float, bob, rotation, shadow, particles or glow): the layer has no motion API and its
# entries carry no shadow; the sprite sits exactly at anchor - frame anchor.
func test_sigil_lies_still_with_no_float_bob_or_shadow() -> void:
	var layer := PickupLayer.new()
	_check("test_layer_has_no_rotation_or_bob", not layer.has_method("angle_step_at") and not layer.has_method("bob_at"))
	_check("test_no_float_or_bob_tuning", VoxelPiece.num("float_px") == 0.0 and VoxelPiece.num("bob_px") == 0.0)
	_check("test_no_sparkle_draw", not layer.has_method("_draw_sparkle"))
	layer.free()


# Every stone square: thin dark outline, a lighter upper-left edge, a darker lower-right edge, a flat face.
func test_every_square_has_light_upper_left_and_dark_lower_right_edges() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var e: int = 6
	var f: Dictionary = VoxelPiece.render_frame(cells, e)
	var px: PackedByteArray = f["px"]
	var w: int = (f["size"] as Vector2i).x
	var ok: bool = true
	for c: Vector2i in cells:
		var r: Rect2i = VoxelPiece.square_rect(c, Vector2i.ZERO, e)
		var at := func(i: int, j: int) -> int: return px[(r.position.y + j) * w + r.position.x + i]
		ok = ok and at.call(0, 3) == VoxelPiece.PX_INK and at.call(e, 3) == VoxelPiece.PX_INK
		ok = ok and at.call(1, 3) == VoxelPiece.PX_LIT and at.call(3, 1) == VoxelPiece.PX_LIT
		ok = ok and at.call(e - 1, 3) == VoxelPiece.PX_DARK and at.call(3, e - 1) == VoxelPiece.PX_DARK
		ok = ok and at.call(3, 3) == VoxelPiece.PX_TOP
	_check("test_square_outline_light_ul_dark_lr_face", ok)
	# The outline between the two squares is ONE shared 1 px line.
	var r0: Rect2i = VoxelPiece.square_rect(Vector2i(0, 0), Vector2i.ZERO, e)
	_check("test_neighbours_share_one_outline_column", px[(r0.position.y + 3) * w + r0.position.x + e] == VoxelPiece.PX_INK
		and px[(r0.position.y + 3) * w + r0.position.x + e + 1] == VoxelPiece.PX_LIT)
	var face: Color = VoxelPiece.ramp(VoxelPiece.RAMP_NORMAL)["top"]
	var hi: Color = VoxelPiece.ramp(VoxelPiece.RAMP_NORMAL)["lit"]
	var lo: Color = VoxelPiece.ramp(VoxelPiece.RAMP_NORMAL)["dark"]
	_check("test_ramp_light_above_face_above_dark", hi.get_luminance() > face.get_luminance() and face.get_luminance() > lo.get_luminance())
	_check("test_normal_stone_is_muted", face.s < 0.3, "s=%.2f" % face.s)


func test_smallest_cell_still_reads() -> void:
	# The smallest cell measured on the boards: 38 x 27 art px. A 5-long bar and a mono still get squares of edge_min+.
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var bar: Array[Vector2i] = lib.make_piece("bar5", 0).relative_cells()
	var e: int = VoxelPiece.edge_for(bar, 38.0, 27.0)
	_check("test_bar5_on_38px_cell_edge_at_least_min", e >= int(VoxelPiece.num("edge_min")), "edge=%d" % e)
	var mono_e: int = VoxelPiece.edge_for(lib.make_piece("mono", 0).relative_cells(), 38.0, 27.0)
	_check("test_mono_on_38px_cell_capped_below_half_the_cell", mono_e * 1.0 <= 38.0 / 2.0 and mono_e >= 4, "edge=%d" % mono_e)
	var f: Dictionary = VoxelPiece.render_frame(bar, e)
	_check("test_bar5_small_frame_still_has_5_faces", VoxelPiece.count_squares(f) == 5)


# 2026-11-06 spec: the piece spans about 60-75 % of the cell width (pieces 3+ squares wide; 1-2 wide ones are capped
# by edge_max, and tall ones by the cell height, so they never crowd the tile edge).
func test_piece_width_is_60_to_75_percent_of_the_cell() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var bad: Array[String] = []
	var checked: int = 0
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pieces.json"))
	for size: Vector2 in [Vector2(38, 27), Vector2(50, 36), Vector2(64, 46)]:
		for sh: Dictionary in parsed["shapes"]:
			var piece: Piece = lib.make_piece(str(sh["id"]), 0)
			if piece.size().x < 3:
				continue
			checked += 1
			var share: float = float(VoxelPiece.edge_for(piece.relative_cells(), size.x, size.y) * piece.size().x) / size.x
			# A tall shape is held by the cell height (spacing to the tile edge wins): only the upper bound applies.
			var by_height: bool = floori(size.y * VoxelPiece.num("height_ratio") / piece.size().y) < floori(size.x * VoxelPiece.num("width_ratio") / piece.size().x)
			if share > 0.76 or (share < 0.55 and not by_height):
				bad.append("%s on %s: %.2f" % [sh["id"], str(size), share])
	_check("test_wide_pieces_span_60_to_75_percent", bad.is_empty() and checked > 0, "%d checked %s" % [checked, str(bad)])


func test_piece_height_stays_within_the_cell() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var bad: Array[String] = []
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pieces.json"))
	for sh: Dictionary in parsed["shapes"]:
		for rot: int in 4:
			var piece: Piece = lib.make_piece(str(sh["id"]), rot)
			for size: Vector2 in [Vector2(38, 27), Vector2(64, 46)]:
				var e: int = VoxelPiece.edge_for(piece.relative_cells(), size.x, size.y)
				if e * piece.size().y + 1 > size.y and e > int(VoxelPiece.num("edge_min")):
					bad.append("%s r%d on %s" % [sh["id"], rot, str(size)])
	_check("test_no_piece_taller_than_its_cell", bad.is_empty(), str(bad))


# 2026-11-06 (user: lie with the stone's tilt): squares squash to the flat cell's height / width like the stone tiles,
# and the exact shape still reads (every square's face centre is face, every gap is not).
func test_squares_squash_to_the_cell_aspect_and_keep_the_shape() -> void:
	_check("test_edge_y_follows_the_aspect", VoxelPiece.edge_y_for(10, 0.72) == 7 and VoxelPiece.edge_y_for(10, 1.0) == 10)
	_check("test_edge_y_never_under_edge_min", VoxelPiece.edge_y_for(4, 0.5) == int(VoxelPiece.num("edge_min")))
	var cells: Array[Vector2i] = PieceLibrary.load_from_file().make_piece("plus5", 0).relative_cells()
	var f: Dictionary = VoxelPiece.render_frame(cells, 9, VoxelPiece.STAGE_INTACT, 0, false, 6)
	var size: Vector2i = f["size"]
	_check("test_squashed_frame_size", size == Vector2i(3 * 9 + 1 + 2 * VoxelPiece.PAD, 3 * 6 + 1 + 2 * VoxelPiece.PAD), str(size))
	var px: PackedByteArray = f["px"]
	var bad: int = 0
	for y: int in 3:
		for x: int in 3:
			var p := Vector2i(VoxelPiece.PAD + x * 9 + 5, VoxelPiece.PAD + y * 6 + 3)
			if cells.has(Vector2i(x, y)) != (px[p.y * size.x + p.x] == VoxelPiece.PX_TOP):
				bad += 1
	_check("test_squashed_cross_keeps_its_shape", bad == 0, "bad=%d" % bad)
	_check("test_squashed_cross_5_faces", VoxelPiece.count_squares(f) == 5)


# While BattleCanvas warps the layer with the floor, it anchors on the FLAT cell centre (the shader moves it).
func test_warped_layer_anchors_in_flat_floor_space() -> void:
	var geo: BoardGeometry = BoardGeometry.make(_grid("square"), VP, BACK_RATIO)
	var cell := Vector2i(1, 1)
	var flat: Vector2i = PickupLayer.anchor_flat(geo, cell)
	_check("test_anchor_flat_is_the_flat_cell_centre", flat == Vector2i(Rect2(geo.cell_art_rect(cell)).get_center().floor()))
	_check("test_flat_anchor_warps_onto_the_art_anchor", (geo.warp_art(Vector2(flat) + Vector2(0.5, 0.5)) - (Vector2(PickupLayer.anchor_art(geo, cell)) + Vector2(0.5, 0.5))).length() <= 1.5)
	var aspect: float = PickupLayer.cell_aspect(geo, cell)
	_check("test_cell_aspect_is_a_foreshortened_tile", aspect > 0.5 and aspect < 0.95, "%.2f" % aspect)


# 2026-11-06 (user: look older): big squares carry the engraved square-within-a-square, every square a pit, the
# silhouette's convex corners are worn; the shape still reads and small squares stay plain.
func test_weathered_stone_motif_pits_and_worn_corners() -> void:
	var one: Array[Vector2i] = [Vector2i(0, 0)]
	var big: Dictionary = VoxelPiece.render_frame(one, 12, VoxelPiece.STAGE_INTACT, 0, false, 9)
	var px: PackedByteArray = big["px"]
	var w: int = (big["size"] as Vector2i).x
	var r: Rect2i = VoxelPiece.square_rect(Vector2i(0, 0), Vector2i.ZERO, 12, 9)
	var at := func(i: int, j: int) -> int: return px[(r.position.y + j) * w + r.position.x + i]
	_check("test_big_square_has_the_engraved_inset_square", at.call(3, 3) == VoxelPiece.PX_SEAM and at.call(9, 3) == VoxelPiece.PX_SEAM
		and at.call(3, 6) == VoxelPiece.PX_SEAM and at.call(6, 6) == VoxelPiece.PX_SEAM)
	_check("test_motif_leaves_the_face_centre", at.call(6, 5) != VoxelPiece.PX_INK and at.call(6, 5) != VoxelPiece.PX_NONE)
	_check("test_worn_convex_corners", at.call(0, 0) == VoxelPiece.PX_NONE and at.call(12, 9) == VoxelPiece.PX_NONE and at.call(1, 0) == VoxelPiece.PX_INK)
	var small: Dictionary = VoxelPiece.render_frame(one, 5)
	_check("test_small_square_has_no_motif", (small["px"] as PackedByteArray).count(VoxelPiece.PX_SEAM) <= 1)
	# An L keeps its inner (concave) corner outlined: only convex corners wear.
	var l: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var lf: Dictionary = VoxelPiece.render_frame(l, 8)
	var lw: int = (lf["size"] as Vector2i).x
	var inner_corner := Vector2i(VoxelPiece.PAD + 8, VoxelPiece.PAD + 8)
	_check("test_concave_corner_kept", (lf["px"] as PackedByteArray)[inner_corner.y * lw + inner_corner.x] == VoxelPiece.PX_INK)
	_check("test_weathered_l_still_3_squares", VoxelPiece.count_squares(lf) == 3)
	var face: Color = VoxelPiece.ramp(VoxelPiece.RAMP_NORMAL)["top"]
	_check("test_aged_ivory_is_warm_and_muted", face.r > face.b and face.s < 0.3 and face.v < 0.85, "s=%.2f v=%.2f" % [face.s, face.v])

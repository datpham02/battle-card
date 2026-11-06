extends SceneTree
## SupportLayer (forest-integration-pickup-plan step 2, 2026-11-06): the stone foundation under the board. The walls
## hang below the platform's front faces only (never over a cell), one per lower edge on every arena shape, and the
## forest uses its generated, horizontally seamless wall strip.
## Run: godot --headless --path . -s res://tests/unit/battle/support_layer_test.gd

const VP: Vector2 = Vector2(1280, 720)
## ADR-0002 floor back ratio (combat.json floor.perspective.back_ratio).
const BACK_RATIO: float = 0.82
const WALL_HEIGHT: int = 44

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_walls_hang_below_the_front_faces_never_over_a_cell()
	test_one_wall_per_lower_edge_on_shaped_arenas()
	test_forest_wall_strip_is_loaded_and_tiles_seamlessly()
	test_pillars_at_both_ends_and_evenly_spread()
	test_arches_only_in_wide_enough_pillar_gaps()
	test_ferns_inside_the_span_and_one_on_a_short_span()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _grid(shape: String) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, ArenaLibrary.load_from_file(), 1)


func test_walls_hang_below_the_front_faces_never_over_a_cell() -> void:
	for shape: String in ["square", "boss_hall", "cross", "u_shape"]:
		var grid: BoardGrid = _grid(shape)
		if grid == null:
			_check("test_%s_grid_built" % shape, false)
			continue
		var geo: BoardGeometry = BoardGeometry.make(grid, VP, BACK_RATIO)
		var spans: Array[Dictionary] = SupportLayer.wall_spans(geo, grid, WALL_HEIGHT)
		_check("test_%s_has_walls" % shape, not spans.is_empty())
		# The layer draws BEFORE the floor (battle_canvas_test), so the floor covers whatever lies under a cell. The
		# rule: every front cell (no board cell below) has a wall whose top is its face's bottom (computed here on its
		# own: the deck grown by DECK_MARGIN, then FACE_HEIGHT), so walls hang from the faces, never above them.
		var over: int = 0
		for cell: Vector2i in grid.player_cells() + grid.enemy_cells():
			if grid.is_in_board(cell + Vector2i.DOWN):
				continue
			var deck: Rect2i = geo.cell_art_rect(cell).grow(SlabPainter.DECK_MARGIN)
			var face_bottom: float = geo.warp_art(Vector2(deck.get_center().x, deck.end.y - 1 + SlabPainter.FACE_HEIGHT)).y
			var cx: float = geo.warp_art(Vector2(deck.get_center())).x
			var found: bool = false
			for span: Dictionary in spans:
				var tl: Vector2 = span["top_left"]
				var tr: Vector2 = span["top_right"]
				if cx > tl.x and cx < tr.x and absf(tl.y - face_bottom) <= 1.5 and absf(tr.y - face_bottom) <= 1.5:
					found = true
			if not found:
				over += 1
		_check("test_%s_walls_hang_below_the_cells_above_them" % shape, over == 0, "over=%d" % over)


func test_one_wall_per_lower_edge_on_shaped_arenas() -> void:
	var square: BoardGrid = _grid("square")
	var geo_sq: BoardGeometry = BoardGeometry.make(square, VP, BACK_RATIO)
	var sq: Array[Dictionary] = SupportLayer.wall_spans(geo_sq, square, WALL_HEIGHT)
	# square: one front row per half (the divider deck joins them into one or two spans), all on the same line.
	var ys: Dictionary = {}
	for span: Dictionary in sq:
		ys[roundi((span["top_left"] as Vector2).y)] = true
	_check("test_square_walls_on_one_front_line", ys.size() == 1, str(ys.keys()))
	var cross: BoardGrid = _grid("cross")
	var geo_x: BoardGeometry = BoardGeometry.make(cross, VP, BACK_RATIO)
	var xs: Array[Dictionary] = SupportLayer.wall_spans(geo_x, cross, WALL_HEIGHT)
	var lines: Dictionary = {}
	for span: Dictionary in xs:
		lines[roundi((span["top_left"] as Vector2).y)] = true
	_check("test_cross_walls_under_two_edge_lines", lines.size() >= 2, str(lines.keys()))


func test_forest_wall_strip_is_loaded_and_tiles_seamlessly() -> void:
	ArtAssets.clear_cache()
	var layer := SupportLayer.new()
	layer.set_region_id("forest")
	var tex: Texture2D = layer.get_wall_texture()
	_check("test_forest_support_enabled", layer.is_enabled())
	_check("test_forest_wall_strip_loaded", tex != null)
	if tex != null:
		var img: Image = tex.get_image()
		_check("test_wall_strip_is_opaque_stone", img.get_pixel(img.get_width() / 2, img.get_height() / 2).a > 0.99)
		# Seamless: the last column continues into the first (mean colour step across the wrap is like an inner step).
		var wrap_d: float = _col_diff(img, img.get_width() - 1, 0)
		var inner: float = 0.0
		for x: int in range(1, img.get_width()):
			inner += _col_diff(img, x - 1, x)
		inner /= float(img.get_width() - 1)
		_check("test_wall_strip_wrap_step_like_an_inner_step", wrap_d <= inner * 2.5, "wrap=%.3f inner=%.3f" % [wrap_d, inner])
	layer.free()


func _col_diff(img: Image, a: int, b: int) -> float:
	var d: float = 0.0
	for y: int in img.get_height():
		var ca: Color = img.get_pixel(a, y)
		var cb: Color = img.get_pixel(b, y)
		d += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return d / float(img.get_height())


# 2026-11-06 (modular wall): a pillar inset at each end of a span and evenly spread about `every` px apart; none on a
# span narrower than two pillars or when pillars are off.
func test_pillars_at_both_ends_and_evenly_spread() -> void:
	var xs: Array[int] = SupportLayer.pillar_xs(100, 600, 120, 22)
	_check("test_first_pillar_inset_at_the_left_end", not xs.is_empty() and xs[0] == 111, str(xs))
	_check("test_last_pillar_inset_at_the_right_end", not xs.is_empty() and xs[xs.size() - 1] == 588, str(xs))
	var even: bool = true
	for i: int in range(1, xs.size() - 1):
		even = even and absi((xs[i] - xs[i - 1]) - (xs[i + 1] - xs[i])) <= 1
	_check("test_pillars_evenly_spread_about_every", even and xs.size() == 5, str(xs))
	_check("test_no_pillar_on_a_short_span", SupportLayer.pillar_xs(0, 30, 120, 22).is_empty())
	_check("test_no_pillar_when_off", SupportLayer.pillar_xs(0, 600, 0, 22).is_empty())


# 2026-11-06 (PixelLab kit): an arch in the middle of every pillar gap with room for it, none in narrow gaps.
func test_arches_only_in_wide_enough_pillar_gaps() -> void:
	var xs: Array[int] = SupportLayer.arch_xs([100, 220, 280, 400] as Array[int], 28, 72, 4)
	_check("test_arch_in_wide_gaps_only", xs == ([160, 340] as Array[int]), str(xs))
	_check("test_no_arch_without_pillars", SupportLayer.arch_xs([] as Array[int], 28, 72, 4).is_empty())


# Fern clumps stay inside their span; a span too short for the step still gets one centred clump; none when narrower
# than a clump; the same seed gives the same layout.
func test_ferns_inside_the_span_and_one_on_a_short_span() -> void:
	var xs: Array[int] = SupportLayer.fern_xs(50, 700, 150, 96, 7)
	_check("test_ferns_inside_the_span", not xs.is_empty() and xs.all(func(x: int) -> bool: return x >= 50 and x + 96 <= 700), str(xs))
	_check("test_ferns_same_seed_same_layout", SupportLayer.fern_xs(50, 700, 150, 96, 7) == xs)
	_check("test_short_span_gets_one_centred_clump", SupportLayer.fern_xs(0, 140, 150, 96, 3) == ([22] as Array[int]))
	_check("test_too_narrow_span_gets_none", SupportLayer.fern_xs(0, 80, 150, 96, 3).is_empty())

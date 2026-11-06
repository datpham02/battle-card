class_name SupportLayer
extends Node2D
## Support layer of the battle art canvas (forest-integration-pickup-plan-2026-11-05 step 2; user file
## tessera_regions_background_arena_blocks_v2 §0.6 "the board and the background are one place"): the stone
## foundation the board stands on, drawn in the art viewport between BackdropLayer and the floor (or its perspective
## warp), so the floor's deck and front face sit on top of its upper edge. Never over a cell: everything lies below the
## platform's front faces or outside its side edges.
##
## Pieces, all in art px on the drawn (warped) floor:
## - a retaining wall under every front face (SlabPainter.platform_front_rects, so a cross / u-shaped board gets a wall
##   under each lower edge), its top on the face's bottom corners mapped through BoardGeometry.warp_art, hanging
##   wall_height px straight down: stone courses (course_height rows, block widths cycled like the face), each block
##   3-tone like the slabs v2 (light top row, face, dark bottom / right), Ink mortar, courses darkening step by step
##   (no dither) down to the ground colour;
## - optional side walls (side_walls 1) under the left and right edges of the board's bounding box; off by default
##   since a cross / u-shaped board has no straight side edge;
## - moss clumps (low, organic, at block joints near the wall's top) in the region's cover colour;
## - aged stone: per-block tone shifts, a few 1 px cracks and chipped corners, seeded by the block's position;
## - a stepped Ink foot shadow (foot_shadow bands, no dither) so the wall sits on the ground. The near mist strip can be
##   laid over the foot (mist_alpha > 0); 2026-11-06 it read as white specks there, so the forest sets 0.
## 2026-11-06 (user approved a PixelLab wall, 9 gen): when the region names `support.wall_tile` (a horizontally
## seamless strip, env_support_forest_wall.png 231x44 for the forest) the wall is that texture repeated on an absolute
## x grid (so neighbouring spans line up), darkened by wall_modulate so the playable floor stays brighter; the coded
## courses above remain the fallback for regions without one.
## Static: redraws on setup, region change and screen size change. Tuning: region.json "support" (missing = no layer).

## Fallback numbers when the region's block names none (art px).
const DEFAULTS: Dictionary = {
	"wall_height": 40, "course_height": 8, "block_widths": [16, 20, 14, 18, 22, 15],
	"stone_top": "#55564F", "stone": "#3F403A", "stone_dark": "#2C2D29", "ground": "#1C1D1A",
	"side": "#24251F", "moss": "#4C5A40", "moss_dark": "#36412F", "moss_every": 3, "mist_alpha": 0.0,
	"foot_shadow": [0.55, 0.38, 0.22], "foot_band": 3, "crack_every": 4, "chip_every": 5,
	"wall_modulate": "#B8B8B8", "wall_bottom_shade": [0.25, 0.45], "side_walls": 0,
	"wall_top_shade": [0.55, 0.3], "pillar_every": 0, "pillar_width": 22, "pillar_modulate": "#D2D2D2",
	"arch_margin": 4, "fern_every": 150, "fern_sink": 8, "roots_inset": 10, "roots_rise": 2,
}


## The generated wall strip of the region (null = coded courses).
func get_wall_texture() -> Texture2D:
	return _wall_tex

var _combat: CombatView = null
var _region_id: String = ArtAssets.DEFAULT_REGION
var _cfg: Dictionary = {}
var _mist: Texture2D = null
var _wall_tex: Texture2D = null
var _pillar_tex: Texture2D = null
var _arch_tex: Texture2D = null
var _roots_tex: Texture2D = null
var _ferns_tex: Texture2D = null
var _redraws: int = 0


## Binds the layer to the battle's CombatView (grid, geometry, screen size) and its chapter's region.
func setup(combat: CombatView) -> void:
	_combat = combat
	var vp: Viewport = combat.get_viewport() if combat != null and combat.is_inside_tree() else null
	if vp != null and not vp.size_changed.is_connected(queue_redraw):
		vp.size_changed.connect(queue_redraw)
	var chapter: String = str(combat.match_params.get("chapter_id", "")) if combat != null else ""
	set_region_id(ArtAssets.region_for_chapter(chapter))


## Switches to art region [param id] (its `support` block and near mist) and redraws.
func set_region_id(id: String) -> void:
	_region_id = id
	var raw: Variant = ArtAssets.region(id).get("support", {})
	_cfg = raw if raw is Dictionary else {}
	_mist = ArtAssets.region_texture(id, "backdrop.near")
	_wall_tex = ArtAssets.region_texture(id, "support.wall_tile")
	_pillar_tex = ArtAssets.region_texture(id, "support.pillar")
	_arch_tex = ArtAssets.region_texture(id, "support.arch")
	_roots_tex = ArtAssets.region_texture(id, "support.roots")
	_ferns_tex = ArtAssets.region_texture(id, "support.ferns")
	queue_redraw()


## True when the region defines a support block (otherwise the layer draws nothing).
func is_enabled() -> bool:
	return not _cfg.is_empty()


## Number of times `_draw` ran (tests).
func get_redraw_count() -> int:
	return _redraws


## Pure: the wall quads (art px, drawn floor) under the front faces of [param grid] on [param geo]: an Array of
## {top_left, top_right: Vector2 (face bottom corners, warped), height: int}. Empty when no grid.
static func wall_spans(geo: BoardGeometry, grid: BoardGrid, height: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if geo == null or grid == null:
		return out
	var cells: Array[Vector2i] = grid.player_cells() + grid.enemy_cells()
	var rects: Array[Rect2i] = []
	for c: Vector2i in cells:
		rects.append(geo.cell_art_rect(c))
	var below: Callable = func(i: int) -> bool: return grid.is_in_board(cells[i] + Vector2i.DOWN)
	for f: Rect2i in SlabPainter.merge_row_rects(SlabPainter.platform_front_rects(rects, below)):
		var a: Vector2 = geo.warp_art(Vector2(f.position.x, f.end.y))
		var b: Vector2 = geo.warp_art(Vector2(f.end.x, f.end.y))
		out.append({"top_left": a.round(), "top_right": b.round(), "height": height})
	return out


## Pure: the side-wall polygons (art px) under the left and right edges of the board's deck bounding box: from the
## back corner down the slanted edge to the front face's bottom corner, then [param height] px down.
static func side_polygons(geo: BoardGeometry, grid: BoardGrid, height: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if geo == null or grid == null:
		return out
	var cells: Array[Vector2i] = grid.player_cells() + grid.enemy_cells()
	if cells.is_empty():
		return out
	var box: Rect2i = geo.cell_art_rect(cells[0])
	for c: Vector2i in cells:
		box = box.merge(geo.cell_art_rect(c))
	box = box.grow(SlabPainter.DECK_MARGIN)
	var bottom: float = box.end.y - 1 + SlabPainter.FACE_HEIGHT
	for x: float in [float(box.position.x), float(box.end.x)]:
		var back: Vector2 = geo.warp_art(Vector2(x, box.position.y)).round()
		var front: Vector2 = geo.warp_art(Vector2(x, bottom)).round()
		var outward: float = -1.0 if x == float(box.position.x) else 1.0
		# The visible side face: from the slanted edge out to the vertical through the back corner, down to the wall foot.
		out.append(PackedVector2Array([back, front, front + Vector2(0, height), Vector2(back.x + outward * 0.0, front.y + height)]))
	return out


func _num(key: String) -> float:
	return float(_cfg.get(key, DEFAULTS[key]))


func _col(key: String) -> Color:
	return Color(str(_cfg.get(key, DEFAULTS[key])))


func _draw() -> void:
	_redraws += 1
	if not is_enabled() or _combat == null or not is_instance_valid(_combat) or _combat.get_grid() == null:
		return
	var geo: BoardGeometry = _combat.board_geometry()
	if geo == null:
		return
	var h: int = int(_num("wall_height"))
	# Side walls follow the board's bounding box, wrong on a cross / u-shaped board: only with side_walls on.
	if _num("side_walls") > 0.0:
		for poly: PackedVector2Array in side_polygons(geo, _combat.get_grid(), h):
			draw_colored_polygon(poly, _col("side"))
	var lowest: float = 0.0
	for span: Dictionary in wall_spans(geo, _combat.get_grid(), h):
		_draw_wall(span)
		lowest = maxf(lowest, (span["top_left"] as Vector2).y + h)
	var bands: Array = _cfg.get("foot_shadow", DEFAULTS["foot_shadow"])
	var band: int = maxi(int(_num("foot_band")), 1)
	for span: Dictionary in wall_spans(geo, _combat.get_grid(), h):
		var tl: Vector2 = span["top_left"]
		var tr: Vector2 = span["top_right"]
		var foot: float = minf(tl.y, tr.y) + h
		for i: int in bands.size():
			draw_rect(Rect2(tl.x - 2 - i * 2, foot + i * band, tr.x - tl.x + 4 + i * 4, band), Color(Color("1B1722"), float(bands[i])))
	_draw_ferns_and_roots(geo, h)
	if _mist != null and lowest > 0.0 and _num("mist_alpha") > 0.0:
		var y: float = lowest - float(_mist.get_height()) + 8.0
		draw_texture(_mist, Vector2(0.0, y), Color(1, 1, 1, _num("mist_alpha")))


# 2026-11-06: fern clumps along every wall's foot (fern_xs, in front of the foot shadow), then roots hanging from the
# board's outermost wall ends (left as drawn, right mirrored), over the wall and its pillars.
func _draw_ferns_and_roots(geo: BoardGeometry, h: int) -> void:
	var spans: Array[Dictionary] = wall_spans(geo, _combat.get_grid(), h)
	if spans.is_empty():
		return
	var left: Dictionary = spans[0]
	var right: Dictionary = spans[0]
	for span: Dictionary in spans:
		var tl: Vector2 = span["top_left"]
		var tr: Vector2 = span["top_right"]
		var foot: int = int(minf(tl.y, tr.y)) + h
		if _ferns_tex != null:
			var fw: int = _ferns_tex.get_width()
			var fh: int = _ferns_tex.get_height()
			for fx: int in fern_xs(int(tl.x), int(tr.x), int(_num("fern_every")), fw, int(tl.x) * 31 + int(tl.y)):
				draw_texture(_ferns_tex, Vector2(fx, foot - fh + int(_num("fern_sink"))))
		if (span["top_left"] as Vector2).x < (left["top_left"] as Vector2).x:
			left = span
		if (span["top_right"] as Vector2).x > (right["top_right"] as Vector2).x:
			right = span
	if _roots_tex == null:
		return
	var rw: float = float(_roots_tex.get_width())
	var rh: float = float(_roots_tex.get_height())
	var inset: float = _num("roots_inset")
	var rise: float = _num("roots_rise")
	var lt: Vector2 = left["top_left"]
	draw_texture_rect(_roots_tex, Rect2(lt.x - inset, lt.y - rise, rw, rh), false)
	var rt: Vector2 = right["top_right"]
	draw_texture_rect(_roots_tex, Rect2(rt.x + inset, rt.y - rise, -rw, rh), false)


# One retaining wall under a front face: the region's strip when it has one, else coded courses.
func _draw_wall(span: Dictionary) -> void:
	if _wall_tex != null:
		_draw_wall_tex(span)
	else:
		_draw_wall_coded(span)


# The generated strip repeated across the span on an absolute x grid, top on the face's bottom, clipped to the span
# and to height px; the last rows stepped darker (Ink bands, wall_bottom_shade) so it sinks into the ground.
func _draw_wall_tex(span: Dictionary) -> void:
	var tl: Vector2 = span["top_left"]
	var tr: Vector2 = span["top_right"]
	var x0: int = int(tl.x)
	var x1: int = int(tr.x)
	var top: int = int(minf(tl.y, tr.y))
	var h: int = mini(int(span["height"]), _wall_tex.get_height())
	var tw: int = _wall_tex.get_width()
	if x1 <= x0 or tw <= 0 or h <= 0:
		return
	var mod: Color = _col("wall_modulate")
	var x: int = x0 - posmod(x0, tw)
	while x < x1:
		var a: int = maxi(x, x0)
		var b: int = mini(x + tw, x1)
		draw_texture_rect_region(_wall_tex, Rect2(a, top, b - a, h), Rect2(a - x, 0, b - a, h), mod)
		x += tw
	var shades: Array = _cfg.get("wall_bottom_shade", DEFAULTS["wall_bottom_shade"])
	var band: int = maxi(int(_num("foot_band")), 1)
	for i: int in shades.size():
		var y: int = top + h - band * (shades.size() - i)
		draw_rect(Rect2(x0, y, x1 - x0, band), Color(Color("1B1722"), float(shades[i])))
	# Contact shadow: the coping overhangs the wall, so the wall's first rows sit in its shade (2026-11-06).
	var tops: Array = _cfg.get("wall_top_shade", DEFAULTS["wall_top_shade"])
	for i: int in tops.size():
		draw_rect(Rect2(x0, top + i * 2, x1 - x0, 2), Color(Color("1B1722"), float(tops[i])))
	_draw_arches(x0, x1, top, h)
	_draw_pillars(x0, x1, top, h)


## Pure: the centres of the recessed arches of a span: one in the middle of every gap between two neighbouring pillars
## ([param pillars], [method pillar_xs]) whose free width is at least [param arch_w] + 2 * [param margin].
static func arch_xs(pillars: Array[int], pillar_w: int, arch_w: int, margin: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(1, pillars.size()):
		var free: int = pillars[i] - pillars[i - 1] - pillar_w
		if free >= arch_w + margin * 2:
			@warning_ignore("integer_division")
			out.append((pillars[i] + pillars[i - 1]) / 2)
	return out


# 2026-11-06: the generated recessed arch, bottom on the wall's foot, between pillars (arch_xs).
func _draw_arches(x0: int, x1: int, top: int, h: int) -> void:
	if _arch_tex == null:
		return
	var pw: int = _pillar_tex.get_width() if _pillar_tex != null else int(_num("pillar_width"))
	var aw: int = _arch_tex.get_width()
	var ah: int = mini(_arch_tex.get_height(), h)
	for cx: int in arch_xs(pillar_xs(x0, x1, int(_num("pillar_every")), pw), pw, aw, int(_num("arch_margin"))):
		@warning_ignore("integer_division")
		draw_texture_rect_region(_arch_tex, Rect2(cx - aw / 2, top + h - ah, aw, ah), Rect2(0, _arch_tex.get_height() - ah, aw, ah), _col("wall_modulate"))


## Pure: the fern clump x positions (left edges) along a span [param x0]..[param x1]: about every [param every] px,
## each nudged by up to a quarter step from [param seed], all inside the span for a clump [param w] wide; a span
## too short for that still gets one clump in its middle when it is at least [param w] wide.
static func fern_xs(x0: int, x1: int, every: int, w: int, seed: int) -> Array[int]:
	var out: Array[int] = []
	if every <= 0 or x1 - x0 < w:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed) + 4241
	var x: float = float(x0) + float(every) * 0.35
	while x + w <= x1:
		@warning_ignore("integer_division")
		out.append(clampi(int(x) + rng.randi_range(-every / 4, every / 4), x0, x1 - w))
		x += float(every)
	if out.is_empty():
		@warning_ignore("integer_division")
		out.append(x0 + (x1 - x0 - w) / 2)
	return out


## Pure: the x of every pillar centre on a wall span [param x0]..[param x1] (art px): one inset at each end and one
## every [param every] px between, evenly spread (none when every <= 0 or the span is narrower than 2 pillars).
static func pillar_xs(x0: int, x1: int, every: int, width: int) -> Array[int]:
	var out: Array[int] = []
	if every <= 0 or x1 - x0 < width * 2:
		return out
	@warning_ignore("integer_division")
	var first: int = x0 + width / 2
	@warning_ignore("integer_division")
	var last: int = x1 - width / 2 - 1
	var gaps: int = maxi(roundi(float(last - first) / float(every)), 1)
	for i: int in gaps + 1:
		out.append(first + roundi(float(last - first) * i / float(gaps)))
	return out


# 2026-11-06 prototype: structural pillars at the span ends and every pillar_every px (the generated pillar sprite
# will replace this placeholder: a brighter wall slice with Ink sides and a capstone row).
func _draw_pillars(x0: int, x1: int, top: int, h: int) -> void:
	if _pillar_tex != null:
		# The generated pillar (PixelLab, 2026-11-06): its capital under the coping, its base sunk below the foot.
		var pw: int = _pillar_tex.get_width()
		for cx: int in pillar_xs(x0, x1, int(_num("pillar_every")), pw):
			@warning_ignore("integer_division")
			draw_texture(_pillar_tex, Vector2(cx - pw / 2, top), _col("pillar_modulate"))
		return
	var w: int = int(_num("pillar_width"))
	var mod: Color = _col("pillar_modulate")
	var ink := Color("1B1722")
	for cx: int in pillar_xs(x0, x1, int(_num("pillar_every")), w):
		@warning_ignore("integer_division")
		var px: int = cx - w / 2
		var tw: int = _wall_tex.get_width()
		var src_x: int = posmod(px * 3, tw - w)
		draw_texture_rect_region(_wall_tex, Rect2(px, top, w, h + 4), Rect2(src_x, 0, w, mini(h + 4, _wall_tex.get_height())), mod)
		draw_rect(Rect2(px - 1, top, 1, h + 4), ink)
		draw_rect(Rect2(px + w, top, 1, h + 4), ink)
		draw_rect(Rect2(px + w - 2, top, 2, h + 4), Color(ink, 0.35))
		draw_rect(Rect2(px - 2, top - 1, w + 4, 3), Color("5A5B54"))
		draw_rect(Rect2(px - 2, top + 2, w + 4, 1), ink)


# Coded fallback: stone courses between the span's top corners and height px below, darkening per course.
func _draw_wall_coded(span: Dictionary) -> void:
	var tl: Vector2 = span["top_left"]
	var tr: Vector2 = span["top_right"]
	var h: int = int(span["height"])
	var x0: int = int(tl.x)
	var x1: int = int(tr.x)
	if x1 <= x0:
		return
	var top: int = int(minf(tl.y, tr.y))
	var ch: int = maxi(int(_num("course_height")), 3)
	var widths: Array = _cfg.get("block_widths", DEFAULTS["block_widths"])
	var courses: int = ceili(float(h) / float(ch))
	var ramp: Array[Color] = [_col("stone_top"), _col("stone"), _col("stone_dark"), _col("ground")]
	var ink := Color("1B1722")
	var moss_every: int = maxi(int(_num("moss_every")), 1)
	for k: int in courses:
		var y: int = top + k * ch
		var rows: int = mini(ch, top + h - y)
		if rows <= 0:
			break
		# Darken one step every course past the first two (no dither): face colour, then dark, then ground.
		var step: int = clampi(k - 1, 0, 2)
		var face: Color = ramp[mini(step + 1, 3)]
		var light: Color = ramp[mini(step, 3)]
		var dark: Color = ramp[mini(step + 2, 3)]
		draw_rect(Rect2(x0, y, x1 - x0, rows), ink)
		var x: int = x0 - ((k * 7) % 11)
		var b: int = k * 3
		while x < x1:
			var w: int = int(widths[b % widths.size()])
			var bx0: int = maxi(x, x0)
			var bx1: int = mini(x + w - 1, x1)
			if bx1 > bx0 and rows > 2:
				# Aged stone: some blocks one tone darker, seeded by position (static, the same every redraw).
				var hsh: int = absi(hash(Vector2i(x, k) + Vector2i(31, 7)))
				var bface: Color = dark if hsh % 4 == 0 else face
				draw_rect(Rect2(bx0, y, bx1 - bx0, rows - 1), bface)
				draw_rect(Rect2(bx0, y, bx1 - bx0, 1), light if hsh % 4 != 0 else face)
				draw_rect(Rect2(bx0, y + rows - 2, bx1 - bx0, 1), dark)
				draw_rect(Rect2(bx1 - 1, y, 1, rows - 1), dark)
				# A 1 px stepped crack down some blocks, a chipped corner on others.
				if hsh % maxi(int(_num("crack_every")), 1) == 1 and bx1 - bx0 > 6:
					var cx: int = bx0 + 3 + hsh % maxi(bx1 - bx0 - 6, 1)
					for r: int in rows - 2:
						draw_rect(Rect2(cx + (r / 2) % 2, y + 1 + r, 1, 1), ink)
				if hsh % maxi(int(_num("chip_every")), 1) == 2:
					draw_rect(Rect2(bx1 - 3, y, 2, 2), ink)
				# Moss: a low clump hanging from the top courses at some joints.
				if k == 0 and (b % moss_every) == 0:
					# Moss hanging from the wall's top edge: a clump, one drip a row longer.
					var mx: int = bx0 + 1 + hsh % 3
					draw_rect(Rect2(mx, y, 6, 1), _col("moss"))
					draw_rect(Rect2(mx + 1, y + 1, 4, 1), _col("moss"))
					draw_rect(Rect2(mx + 2, y + 2, 2, 1), _col("moss_dark"))
					draw_rect(Rect2(mx + 3, y + 3, 1, 2), _col("moss_dark"))
			x += w
			b += 1

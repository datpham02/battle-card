class_name SlabPainter
extends RefCounted
## Pure, node-free painters for the battle floor (Story 047 Part B, art bible §6.3): the slab
## 9-slice with seeded stamps, the raised stone platform (option B), and the thorn tile. Every
## function is static and takes the `CanvasItem` whose `_draw` is running; the pure selection
## steps (`pick_stamps`, `platform_front_rects`, `platform_deck_rects`, `merge_row_rects`) are
## separate so tests assert geometry and determinism without drawing. All coordinates are
## integer art pixels: no `Rect2` here ever gets a fractional origin or size.
##
## Stamp metadata is the stamps sheet JSON (`ArtAssets.region_stamps`): `stamps[]` with `name`,
## `rect` [x, y, w, h] on the sheet, `anchor`, `kind` (`crack | cover | speckle | chip`);
## `rules` (`max_cracks_per_slab`, `max_cover_face_ratio`, `speckle_max_face_ratio` and the
## optional `*_chance` keys below); `nine_slice.margins`.

## Ink: the one outline / shadow colour of the whole game (art bible §2).
const INK := Color("1B1722")
## Stone fill used when a region has no 9-slice texture (palette `stone` of the forest slab v2).
const FALLBACK_STONE := Color("4C4D47")

## 9-slice margins when `nine_slice.margins` is missing from the stamps JSON (v2: 3/3/3/4, the
## bottom covering the 3 px lip + the 1 px gap the texture carries).
const DEFAULT_MARGINS := {"left": 3, "right": 3, "top": 3, "bottom": 4}
## The 1 px gap the 9-slice carries on its right and bottom; the slab's visible stone stops before it.
const SLAB_GAP: int = 1

## Platform B numbers (art bible §6.3): deck around every real cell, front face under cells with
## nothing below, shadow under the face.
const DECK_MARGIN: int = 6
const FACE_HEIGHT: int = 12
const SHADOW_HEIGHT: int = 4
const SHADOW_INSET: int = 2
## Stone courses on the face: block widths cycled on an absolute x grid (so overlapping faces of
## neighbouring cells line up), average ~10 px, with a row-dependent phase so rows stagger.
const FACE_BLOCKS: Array[int] = [10, 12, 9, 11, 10, 13]

## Stamp density when the JSON `rules` carry no `*_chance` keys. Art density, not tuning: the
## artist overrides them per region in the stamps JSON.
const DEFAULT_RULES := {
	"max_cracks_per_slab": 2,
	"max_cover_face_ratio": 0.25,
	"speckle_max_face_ratio": 0.04,
	"speckle_chance": 0.75,
	"cover_chance": 0.4,
	"crack_chance": 0.3,
	"second_crack_chance": 0.1,
	"chip_chance": 0.7,
	"second_chip_chance": 0.35,
}
## `any`-anchored stamps keep this many px off the face edge.
const ANY_INSET: int = 1
## Edge nicks (`top_edge`, `left_edge`, `lip_bottom`) keep this many px off the corners.
const EDGE_MIN_OFFSET: int = 3
## `left_edge` nicks also stay this many px above the lip.
const LEFT_EDGE_BOTTOM_GAP: int = 6


# --- seeds -----------------------------------------------------------------------------------


## Stable per-cell seed (no RNG): the same cell always gets the same stamps between redraws,
## resizes and sessions. `side` 0 = player, 1 = enemy.
static func cell_seed(side: int, col: int, row: int) -> int:
	var h: int = (side + 1) * 73856093
	h = h ^ ((col + 1) * 19349663)
	h = h ^ ((row + 1) * 83492791)
	h = h * 2654435761
	return h & 0x7FFFFFFF


# --- slab ------------------------------------------------------------------------------------


## The 9-slice margins of `meta` (`nine_slice.margins`), DEFAULT_MARGINS where absent.
static func margins(meta: Dictionary) -> Dictionary:
	var m: Variant = (meta.get("nine_slice", {}) as Dictionary).get("margins", null)
	var out: Dictionary = DEFAULT_MARGINS.duplicate()
	if m is Dictionary:
		for key: String in out.keys():
			if (m as Dictionary).has(key):
				out[key] = int((m as Dictionary)[key])
	return out


## The face of a slab of `rect_size`: the cell inset by the 9-slice margins (inside the light
## edge, above the lip). Local to the cell origin.
static func face_rect(rect_size: Vector2i, meta: Dictionary) -> Rect2i:
	var m: Dictionary = margins(meta)
	var l: int = int(m["left"])
	var t: int = int(m["top"])
	return Rect2i(l, t, maxi(rect_size.x - l - int(m["right"]), 0), maxi(rect_size.y - t - int(m["bottom"]), 0))


## The visible stone of a slab of `rect_size` (the cell minus the gap the texture carries on its
## right and bottom). Chips are anchored to this rect: they bite the outer edge.
static func slab_rect(rect_size: Vector2i) -> Rect2i:
	return Rect2i(0, 0, maxi(rect_size.x - SLAB_GAP, 0), maxi(rect_size.y - SLAB_GAP, 0))


## Pure stamp selection for one slab of `rect_size`, seeded by `seed`. Returns
## `[{name, pos: Vector2i, size: Vector2i, src: Rect2i, kind}]` in draw order, `pos` local to the
## cell origin. Rules (`meta.rules`): only stamps that fit their container, at most
## `max_cracks_per_slab` cracks, cover stamps up to `max_cover_face_ratio` of the face area, at
## most one speckle stamp (its opaque pixels stay under `speckle_max_face_ratio` by the asset
## contract — checked in the test suite against the real sheet, not at runtime). Non-chip stamps
## lie inside the face; chips lie inside `slab_rect` (anchored to the outer edge).
static func pick_stamps(rect_size: Vector2i, seed: int, meta: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all: Variant = meta.get("stamps", [])
	if not (all is Array) or (all as Array).is_empty():
		return out
	var rules: Dictionary = DEFAULT_RULES.duplicate()
	var rule_in: Variant = meta.get("rules", {})
	if rule_in is Dictionary:
		for key: Variant in (rule_in as Dictionary).keys():
			rules[key] = (rule_in as Dictionary)[key]
	var face: Rect2i = face_rect(rect_size, meta)
	var slab: Rect2i = slab_rect(rect_size)
	if face.size.x <= 0 or face.size.y <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var by_kind: Dictionary = {"speckle": [], "cover": [], "crack": [], "chip": []}
	for raw: Variant in all:
		if not (raw is Dictionary):
			continue
		var stamp: Dictionary = raw
		var kind := String(stamp.get("kind", ""))
		if not by_kind.has(kind):
			continue
		var container: Rect2i = slab if kind == "chip" else face
		if _fits(stamp, container):
			(by_kind[kind] as Array).append(stamp)
	var face_area: int = face.size.x * face.size.y
	# Speckle: sparse 2 px clusters on most slabs.
	if rng.randf() < float(rules["speckle_chance"]):
		_pick_one(out, by_kind["speckle"], face, face, rng)
	# Cover: moss / roots / leaves, within the face-area budget.
	if rng.randf() < float(rules["cover_chance"]):
		var budget: int = int(floor(float(face_area) * float(rules["max_cover_face_ratio"])))
		var covers: Array = (by_kind["cover"] as Array).filter(func(s: Dictionary) -> bool: return _area(s) <= budget)
		_pick_one(out, covers, face, face, rng)
	# Cracks: at most max_cracks_per_slab.
	var max_cracks: int = int(rules["max_cracks_per_slab"])
	var cracks: int = 0
	if cracks < max_cracks and rng.randf() < float(rules["crack_chance"]):
		if _pick_one(out, by_kind["crack"], face, face, rng):
			cracks += 1
	if cracks < max_cracks and rng.randf() < float(rules["second_crack_chance"]):
		if _pick_one(out, by_kind["crack"], face, face, rng):
			cracks += 1
	# Chips: worn edges, one on most slabs, a second on some.
	if rng.randf() < float(rules["chip_chance"]):
		_pick_one(out, by_kind["chip"], slab, face, rng)
	if rng.randf() < float(rules["second_chip_chance"]):
		_pick_one(out, by_kind["chip"], slab, face, rng)
	return out


## Draw one slab into `rect`: the 16x16 9-slice stretched by its margins (9 region draws at
## most), then the stamps `pick_stamps` chooses for `seed`. `nine == null` paints a flat stone
## rect instead; `stamps == null` skips the stamps. Fallback drawing for a missing region belongs
## to the layer, this only keeps the cell visible.
## [param tint] multiplies the slab and its stamps (2026-10-31: the player's and the enemy's halves differ,
## ArtAssets.half_tints); white leaves the art unchanged.
static func paint_cell(canvas: CanvasItem, rect: Rect2i, seed: int, nine: Texture2D, stamps: Texture2D, meta: Dictionary, tint: Color = Color.WHITE) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	if nine == null:
		var stone: Color = _palette_color(meta.get("palette", {}), "stone", FALLBACK_STONE)
		canvas.draw_rect(_r2(slab_rect(rect.size).position + rect.position, slab_rect(rect.size).size), stone * tint)
		return
	_draw_nine_slice(canvas, rect, nine, margins(meta), tint)
	if stamps == null:
		return
	for s: Dictionary in pick_stamps(rect.size, seed, meta):
		var src: Rect2i = s["src"]
		canvas.draw_texture_rect_region(stamps, _r2(rect.position + (s["pos"] as Vector2i), src.size), _r2(src.position, src.size), tint)


# --- flagstones (2026-11-06) -----------------------------------------------------------------


## Index of the flagstone a cell of [param seed] draws out of [param weights] (one weight per tile of the sheet;
## empty = all equal). Deterministic: the same cell always draws the same stone.
static func flagstone_index(seed: int, weights: Array) -> int:
	var n: int = weights.size()
	if n == 0:
		return 0
	var total: float = 0.0
	for w: Variant in weights:
		total += maxf(float(w), 0.0)
	if total <= 0.0:
		return posmod(seed, n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed) + 2654435761
	var pick: float = rng.randf() * total
	for i: int in n:
		pick -= maxf(float(weights[i]), 0.0)
		if pick < 0.0:
			return i
	return n - 1


## Source spans (start, length) and target spans along one axis of a nine-crop: the [param border] px at both
## ends kept as they are, the middle a window centred in the source's middle when the target is shorter, the source
## middle repeated from its start when longer. Returns pairs [[target_start, src_start, length], ...].
static func nine_crop_spans(target: int, source: int, border: int) -> Array:
	var out: Array = []
	var b: int = mini(border, mini(target / 2, source / 2))
	out.append([0, 0, b])
	var mid_t: int = target - b * 2
	var mid_s: int = source - b * 2
	if mid_t > 0 and mid_s > 0:
		if mid_t <= mid_s:
			out.append([b, b + (mid_s - mid_t) / 2, mid_t])
		else:
			var t: int = 0
			while t < mid_t:
				var l: int = mini(mid_s, mid_t - t)
				out.append([b + t, b, l])
				t += l
	out.append([target - b, source - b, b])
	return out


## 2026-11-06 (user: redo the whole floor; PixelLab flagstones): one generated flagstone over the slab of
## [param rect] (the cell minus its 1 px gap, see [method slab_rect]): tile [method flagstone_index] of the
## [param sheet] (square tiles of [param size] px, row-major, sheet width / size per row), nine-cropped with
## [param border] (never stretched: the pixel density stays the art's at every cell size), multiplied by
## [param tint].
static func paint_flagstone(canvas: CanvasItem, rect: Rect2i, seed: int, sheet: Texture2D, size: int, border: int, weights: Array, tint: Color = Color.WHITE) -> void:
	if sheet == null or size <= 0 or rect.size.x <= 0 or rect.size.y <= 0:
		return
	var slab: Rect2i = slab_rect(rect.size)
	var per_row: int = maxi(sheet.get_width() / size, 1)
	var idx: int = flagstone_index(seed, weights)
	var origin := Vector2i((idx % per_row) * size, (idx / per_row) * size)
	for sx: Array in nine_crop_spans(slab.size.x, size, border):
		for sy: Array in nine_crop_spans(slab.size.y, size, border):
			var dst := Rect2i(rect.position + Vector2i(int(sx[0]), int(sy[0])), Vector2i(int(sx[2]), int(sy[2])))
			var src := Rect2i(origin + Vector2i(int(sx[1]), int(sy[1])), Vector2i(int(sx[2]), int(sy[2])))
			if dst.size.x > 0 and dst.size.y > 0:
				canvas.draw_texture_rect_region(sheet, _r2(dst.position, dst.size), _r2(src.position, src.size), tint)


## 2026-11-06: the region's front face strip [param tile] over every face of [param faces] (FACE_HEIGHT px tall
## strips, the merged front rects), repeated on an absolute x grid so faces of different rows line up, clipped to
## each face and to the tile's height, multiplied by [param modulate]; [param top_edge] (alpha > 0) redraws the top
## row as the light fold of the slab edge.
static func paint_face_strip(canvas: CanvasItem, faces: Array[Rect2i], tile: Texture2D, modulate: Color = Color.WHITE, top_edge: Color = Color(0, 0, 0, 0)) -> void:
	if tile == null:
		return
	var tw: int = tile.get_width()
	var th: int = tile.get_height()
	if tw <= 0 or th <= 0:
		return
	for f: Rect2i in faces:
		var h: int = mini(f.size.y, th)
		var x: int = f.position.x - posmod(f.position.x, tw)
		while x < f.end.x:
			var a: int = maxi(x, f.position.x)
			var b: int = mini(x + tw, f.end.x)
			if b > a:
				canvas.draw_texture_rect_region(tile, _r2(Vector2i(a, f.position.y), Vector2i(b - a, h)), _r2(Vector2i(a - x, 0), Vector2i(b - a, h)), modulate)
			x += tw
		# The slab's fold catching the light: one light row on the face's top edge (the deck's last row).
		if top_edge.a > 0.0:
			canvas.draw_rect(_r2(f.position, Vector2i(f.size.x, 1)), top_edge)


# --- region rim and joints (2026-11-12, arena integration) -----------------------------------


## 2026-11-12 (arena integration: the arena is part of its region, not a board laid over it): the region's edge
## rim strip [param tile] (horizontally seamless, alpha where nothing lies) along every front face of [param faces]:
## its top [param rise] px ABOVE the face's top row (over the deck margin: [param rise] is clamped to
## DECK_MARGIN - 1, so the rim never reaches a cell), repeated on an absolute x grid, clipped to the face's width
## and to the tile's height, multiplied by [param modulate]. Sand lapping over the edge, frost and icicles, scorched
## ash, weed, a crumbling lip: what the region leaves on the platform's edge (art bible §6.1 "phủ lên mép").
static func paint_rim_strip(canvas: CanvasItem, faces: Array[Rect2i], tile: Texture2D, rise: int = 3, modulate: Color = Color.WHITE) -> void:
	if tile == null:
		return
	var tw: int = tile.get_width()
	var th: int = tile.get_height()
	if tw <= 0 or th <= 0:
		return
	var up: int = clampi(rise, 0, DECK_MARGIN - 1)
	for f: Rect2i in faces:
		var top: int = f.position.y - up
		var h: int = mini(th, f.end.y + SHADOW_HEIGHT - top)
		if h <= 0:
			continue
		var x: int = f.position.x - posmod(f.position.x, tw)
		while x < f.end.x:
			var a: int = maxi(x, f.position.x)
			var b: int = mini(x + tw, f.end.x)
			if b > a:
				canvas.draw_texture_rect_region(tile, _r2(Vector2i(a, top), Vector2i(b - a, h)), _r2(Vector2i(a - x, 0), Vector2i(b - a, h)), modulate)
			x += tw


## 2026-11-12: pure selection of the joint segments of a board: for every cell rect of [param cells] (the flat
## art rects of every real cell, both halves, cell [param i] has board coordinate [param coords][i]) the 1 px gap
## column on its right and the 1 px gap row under it, each kept with probability [param chance] (seeded by the cell:
## stable between redraws) and only when a real cell lies on the other side of that gap (a joint, never an outer
## edge). Returns 1 px wide / tall Rect2i segments in draw order. Lava veins in the Hellfire's cracked floor, rime
## in the Ice Tower's joints, sand filling the Sands' joints, weed in the Swamp's: the region's "phủ lên khe".
static func joint_segments(cells: Array[Rect2i], coords: Array[Vector2i], chance: float, salt: int = 0) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if chance <= 0.0 or cells.size() != coords.size():
		return out
	var have: Dictionary = {}
	for i: int in coords.size():
		have[coords[i]] = i
	for i: int in cells.size():
		var r: Rect2i = cells[i]
		var c: Vector2i = coords[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = cell_seed(0, c.x, c.y) ^ (salt * 2654435761)
		if have.has(c + Vector2i.RIGHT) and rng.randf() < chance:
			out.append(Rect2i(r.end.x - SLAB_GAP, r.position.y + 2, SLAB_GAP, maxi(r.size.y - SLAB_GAP - 4, 0)))
		if have.has(c + Vector2i.DOWN) and rng.randf() < chance:
			out.append(Rect2i(r.position.x + 2, r.end.y - SLAB_GAP, maxi(r.size.x - SLAB_GAP - 4, 0), SLAB_GAP))
	return out


## 2026-11-12: draws [param segments] ([method joint_segments]) as 1 px dashed veins (3 px of [param color], 1 px of
## [param dark], art bible §6.2 "1 px bậc thang"), so a joint reads as a vein / rime / sand line, never a solid frame
## that would compete with the red telegraph or the ivory outlines.
static func paint_joint_segments(canvas: CanvasItem, segments: Array[Rect2i], color: Color, dark: Color = INK) -> void:
	for s: Rect2i in segments:
		if s.size.x <= 0 or s.size.y <= 0:
			continue
		var vertical: bool = s.size.y > s.size.x
		var n: int = s.size.y if vertical else s.size.x
		for k: int in n:
			var c: Color = color if k % 4 != 3 else dark
			var p: Vector2i = s.position + (Vector2i(0, k) if vertical else Vector2i(k, 0))
			canvas.draw_rect(_r2(p, Vector2i(1, 1)), c)


## 2026-11-12 (arena surface integration): the environment reaching onto the arena from its perimeter. For one cell
## [param rect] (flat art px) whose sides in [param open] (`{"left": bool, "top": bool, "right": bool, "bottom": bool}`,
## true where NO real cell lies beyond) face the surrounding ground, draws [param cfg]'s cover along those sides,
## seeded by [param seed] (stable). `cfg`: `kind` = `drift` (a low mound of sand / snow / ash along the edge, light
## crest, <= `depth` px deep), `clump` (one or two organic moss / weed clumps straddling the edge), `root` (one or two
## bark strokes from the edge inward, `depth` = reach in px), `rime` (a frost line with teeth); `color`, `light`,
## `dark`; `chance` per open side; `sides` = the sides it may come from (missing = all four; sand "from one side").
## Everything stays inside the slab's 3 px edge band + depth, so <= 25 % of the face (bible §6.2) and the cell's
## boundary (the Ink frame + light fold) stays visible.
static func paint_perimeter_cover(canvas: CanvasItem, rect: Rect2i, seed: int, open: Dictionary, cfg: Dictionary) -> void:
	for r: Dictionary in perimeter_cover_rects(rect, seed, open, cfg):
		canvas.draw_rect(_r2((r["rect"] as Rect2i).position, (r["rect"] as Rect2i).size), r["color"])


## Pure: the rects [method paint_perimeter_cover] draws, as `[{rect: Rect2i, color: Color}]` in draw order (tests:
## nothing on a closed cell, everything inside the cell, the same list for the same seed).
static func perimeter_cover_rects(rect: Rect2i, seed: int, open: Dictionary, cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if cfg.is_empty() or rect.size.x < 16 or rect.size.y < 16:
		return out
	var kind := String(cfg.get("kind", "drift"))
	var color: Color = _palette_color(cfg, "color", Color.WHITE)
	var light: Color = _palette_color(cfg, "light", color.lightened(0.2))
	var dark: Color = _palette_color(cfg, "dark", color.darkened(0.3))
	var chance: float = float(cfg.get("chance", 0.6))
	@warning_ignore("integer_division")
	var depth: int = clampi(int(cfg.get("depth", 5)), 2, mini(rect.size.x, rect.size.y) / 4)
	var allowed: Array = cfg.get("sides", ["left", "top", "right", "bottom"])
	var slab: Rect2i = slab_rect(rect.size)
	slab.position += rect.position
	var inner: Rect2i = slab.grow(-1)  # inside the Ink frame
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x5EED
	var px: Callable = func(p: int, q: int, horizontal: bool, c: Color) -> void:
		out.append({"rect": Rect2i(Vector2i(p, q) if horizontal else Vector2i(q, p), Vector2i(1, 1)), "color": c})
	for side: String in ["left", "top", "right", "bottom"]:
		if not bool(open.get(side, false)) or not allowed.has(side):
			continue
		if rng.randf() >= chance:
			continue
		var horizontal: bool = side == "top" or side == "bottom"
		var length: int = inner.size.x if horizontal else inner.size.y
		var edge: int = (inner.position.y if side == "top" else inner.end.y - 1) if horizontal else (inner.position.x if side == "left" else inner.end.x - 1)
		var dir: int = 1 if side == "top" or side == "left" else -1
		var start: int = inner.position.x if horizontal else inner.position.y
		match kind:
			"drift":
				var phase: float = rng.randf() * TAU
				var amp: float = rng.randf_range(0.5, 1.0)
				for t: int in length:
					var d: int = int(round(float(depth) * amp * (0.55 + 0.45 * sin(phase + float(t) * 0.35)) + rng.randf_range(-0.6, 0.6)))
					if d <= 0:
						continue
					var p: int = start + t
					# One rect per column / row (not per pixel): ~20 perimeter cells on a mobile target.
					var q0: int = edge if dir > 0 else edge - d + 1
					out.append({"rect": Rect2i(Vector2i(p, q0) if horizontal else Vector2i(q0, p), Vector2i(1, d) if horizontal else Vector2i(d, 1)), "color": color})
					px.call(p, edge + dir * d, horizontal, light if rng.randf() < 0.7 else color)
					if rng.randf() < 0.12:
						px.call(p, edge + dir * rng.randi_range(0, maxi(d - 1, 0)), horizontal, dark)
			"clump":
				for n: int in rng.randi_range(1, 2):
					var at: int = rng.randi_range(4, maxi(length - 5, 4))
					var rx: int = rng.randi_range(3, 3 + depth)
					@warning_ignore("integer_division")
					var ry: int = rng.randi_range(2, 2 + depth / 2)
					var cx: int = (start + at) if horizontal else edge
					var cy: int = edge if horizontal else (start + at)
					_blob_rects(out, rng, cx, cy, rx if horizontal else ry, ry if horizontal else rx, inner, color, dark)
			"root":
				for n: int in rng.randi_range(1, 2):
					var at: int = rng.randi_range(5, maxi(length - 6, 5))
					@warning_ignore("integer_division")
					var reach: int = rng.randi_range(depth / 2, depth)
					var p: int = start + at
					for k: int in reach:
						var q: int = edge + dir * k
						var r: Rect2i = Rect2i(Vector2i(p - 1, q), Vector2i(3, 1)) if horizontal else Rect2i(Vector2i(q, p - 1), Vector2i(1, 3))
						if inner.encloses(r):
							out.append({"rect": r, "color": color})
							out.append({"rect": Rect2i(r.position, Vector2i(1, 1)), "color": light})
						if rng.randf() < 0.3:
							p = clampi(p + rng.randi_range(-1, 1), start + 1, start + length - 2)
					var tip: int = edge + dir * reach
					if inner.has_point(Vector2i(p, tip) if horizontal else Vector2i(tip, p)):
						px.call(p, tip, horizontal, dark)
			"rime":
				var line: Rect2i = Rect2i(Vector2i(inner.position.x, edge if dir > 0 else edge - 1), Vector2i(length, 2)) if horizontal else Rect2i(Vector2i(edge if dir > 0 else edge - 1, inner.position.y), Vector2i(2, length))
				out.append({"rect": line, "color": color})
				var t: int = rng.randi_range(1, 3)
				while t < length - 1:
					var tooth: int = rng.randi_range(1, depth - 1)
					var p: int = start + t
					for k: int in tooth:
						px.call(p, edge + dir * (2 + k), horizontal, light if k == tooth - 1 else color)
					t += rng.randi_range(3, 6)
	return out


# An organic clump (an ellipse eaten at its rim), clipped to `inside`, with a few dark specks.
static func _blob_rects(out: Array[Dictionary], rng: RandomNumberGenerator, cx: int, cy: int, rx: int, ry: int, inside: Rect2i, c: Color, c2: Color) -> void:
	for y: int in range(-ry, ry + 1):
		var k: float = 1.0 - float(y * y) / float(maxi(ry * ry, 1))
		if k < 0.0:
			continue
		var half: int = int(float(rx) * sqrt(k)) - rng.randi_range(0, 1)
		if half <= 0:
			continue
		var x0: int = maxi(cx - half + rng.randi_range(0, 1), inside.position.x)
		var x1: int = mini(cx + half, inside.end.x)
		var yy: int = cy + y
		if x1 > x0 and yy >= inside.position.y and yy < inside.end.y:
			out.append({"rect": Rect2i(Vector2i(x0, yy), Vector2i(x1 - x0, 1)), "color": c})
	@warning_ignore("integer_division")
	for n: int in maxi(rx / 2, 1):
		var p := Vector2i(cx + rng.randi_range(-rx + 1, rx - 1), cy + rng.randi_range(-ry + 1, ry - 1))
		if inside.has_point(p):
			out.append({"rect": Rect2i(p, Vector2i(1, 1)), "color": c2})


# --- platform --------------------------------------------------------------------------------


## 2026-11-06: the 1 px divider segments (x [param divider_x]) over the decks that cross it, merged where they touch or
## overlap vertically: a board with no cell at the divider in some rows (cross, u-shape) leaves those rows open.
static func divider_segments(decks: Array[Rect2i], divider_x: int) -> Array[Rect2i]:
	var spans: Array[Vector2i] = []
	for d: Rect2i in decks:
		if d.position.x <= divider_x and divider_x < d.end.x:
			spans.append(Vector2i(d.position.y, d.end.y))
	spans.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var out: Array[Rect2i] = []
	for sp: Vector2i in spans:
		if not out.is_empty() and sp.x <= out[out.size() - 1].end.y:
			var last: Rect2i = out[out.size() - 1]
			out[out.size() - 1] = Rect2i(last.position, Vector2i(1, maxi(last.end.y, sp.y) - last.position.y))
		else:
			out.append(Rect2i(divider_x, sp.x, 1, sp.y - sp.x))
	return out


## The deck under every cell: the cell grown by DECK_MARGIN on all sides (the gap between the
## halves and between cells is deck too, because neighbouring decks overlap).
static func platform_deck_rects(cells: Array[Rect2i]) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for c: Rect2i in cells:
		out.append(c.grow(DECK_MARGIN))
	return out


## One front face per cell whose `has_cell_below.call(index)` is false: FACE_HEIGHT px, as wide
## as the deck, starting on the deck's last row (that row becomes the face's light top edge).
static func platform_front_rects(cells: Array[Rect2i], has_cell_below: Callable) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for i: int in cells.size():
		if bool(has_cell_below.call(i)):
			continue
		var deck: Rect2i = cells[i].grow(DECK_MARGIN)
		out.append(Rect2i(deck.position.x, deck.end.y - 1, deck.size.x, FACE_HEIGHT))
	return out


## Merge rects that share a `y` and `height` and touch or overlap in x into single spans, so a
## row of faces is filled and shadowed once (a 50 % shadow drawn twice reads as a darker patch).
static func merge_row_rects(rects: Array[Rect2i]) -> Array[Rect2i]:
	var sorted: Array[Rect2i] = rects.duplicate()
	sorted.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		if a.position.y != b.position.y:
			return a.position.y < b.position.y
		return a.position.x < b.position.x)
	var out: Array[Rect2i] = []
	for r: Rect2i in sorted:
		if not out.is_empty():
			var last: Rect2i = out[out.size() - 1]
			if last.position.y == r.position.y and last.size.y == r.size.y and r.position.x <= last.end.x:
				var end_x: int = maxi(last.end.x, r.end.x)
				out[out.size() - 1] = Rect2i(last.position.x, last.position.y, end_x - last.position.x, last.size.y)
				continue
		out.append(r)
	return out


## Platform B (art bible §6.3) for `cells` (art-px rects of every real cell, both halves):
## shadows, then front faces (fill, 1 px light top, vertical mortar, 2 px Ink bottom), then the
## deck over everything with a 1 px light top edge where no cell sits above, then an optional
## 1 px divider line at `divider_x` from the top of the highest deck to the bottom of the lowest.
## `palette` keys (hex strings or Colors): `deck`, `face`, `face_top`, `mortar`, `shadow`,
## `shadow_alpha`, `divider` — the region's `platform` block.
static func paint_platform(canvas: CanvasItem, cells: Array[Rect2i], has_cell_below: Callable, palette: Dictionary, divider_x: int = -1) -> void:
	if cells.is_empty():
		return
	var deck_c: Color = _palette_color(palette, "deck", Color("3A3B37"))
	var face_c: Color = _palette_color(palette, "face", Color("262521"))
	var face_top_c: Color = _palette_color(palette, "face_top", Color("5A5B54"))
	var mortar_c: Color = _palette_color(palette, "mortar", INK)
	var shadow_c: Color = _palette_color(palette, "shadow", INK)
	shadow_c.a = float(palette.get("shadow_alpha", 0.5))
	var divider_c: Color = _palette_color(palette, "divider", face_c)

	var faces: Array[Rect2i] = merge_row_rects(platform_front_rects(cells, has_cell_below))
	var decks: Array[Rect2i] = platform_deck_rects(cells)

	for f: Rect2i in faces:
		canvas.draw_rect(_r2(Vector2i(f.position.x + SHADOW_INSET, f.end.y), Vector2i(f.size.x - SHADOW_INSET * 2, SHADOW_HEIGHT)), shadow_c)
	for f: Rect2i in faces:
		canvas.draw_rect(_r2(f.position, f.size), face_c)
		for x: int in _face_joints(f):
			canvas.draw_rect(_r2(Vector2i(x, f.position.y + 1), Vector2i(1, f.size.y - 3)), mortar_c)
		canvas.draw_rect(_r2(Vector2i(f.position.x, f.end.y - 2), Vector2i(f.size.x, 2)), INK)
	for d: Rect2i in decks:
		canvas.draw_rect(_r2(d.position, d.size), deck_c)
	for i: int in cells.size():
		if not _has_cell_touching_above(cells, i):
			var d: Rect2i = decks[i]
			canvas.draw_rect(_r2(d.position, Vector2i(d.size.x, 1)), face_top_c)
	for f: Rect2i in faces:
		canvas.draw_rect(_r2(f.position, Vector2i(f.size.x, 1)), face_top_c)
	if divider_x >= 0:
		# 2026-11-06: one segment per deck the divider crosses, so a cross / u-shaped board's open notch (no cell at the
		# divider) gets no line through the background (it read as a stray vertical line over the new misty backdrop).
		for d: Rect2i in divider_segments(decks, divider_x):
			canvas.draw_rect(_r2(d.position, d.size), divider_c)


# --- thorns ----------------------------------------------------------------------------------


## Tile `tile` (16x16) across the whole cell `rect`, clipping the last column and row with
## region rects so nothing spills over the cell. `tile == null` draws nothing.
static func paint_thorns(canvas: CanvasItem, rect: Rect2i, tile: Texture2D) -> void:
	if tile == null or rect.size.x <= 0 or rect.size.y <= 0:
		return
	var tw: int = tile.get_width()
	var th: int = tile.get_height()
	if tw <= 0 or th <= 0:
		return
	var y: int = 0
	while y < rect.size.y:
		var h: int = mini(th, rect.size.y - y)
		var x: int = 0
		while x < rect.size.x:
			var w: int = mini(tw, rect.size.x - x)
			canvas.draw_texture_rect_region(tile, _r2(rect.position + Vector2i(x, y), Vector2i(w, h)), _r2(Vector2i.ZERO, Vector2i(w, h)))
			x += tw
		y += th


# --- internals -------------------------------------------------------------------------------


static func _draw_nine_slice(canvas: CanvasItem, rect: Rect2i, nine: Texture2D, m: Dictionary, tint: Color = Color.WHITE) -> void:
	var l: int = int(m["left"])
	var r: int = int(m["right"])
	var t: int = int(m["top"])
	var b: int = int(m["bottom"])
	var tw: int = nine.get_width()
	var th: int = nine.get_height()
	# Columns / rows as [source start, source length, destination start, destination length].
	var cols: Array = [[0, l, 0, l], [l, tw - l - r, l, rect.size.x - l - r], [tw - r, r, rect.size.x - r, r]]
	var rows: Array = [[0, t, 0, t], [t, th - t - b, t, rect.size.y - t - b], [th - b, b, rect.size.y - b, b]]
	for row: Array in rows:
		if int(row[1]) <= 0 or int(row[3]) <= 0:
			continue
		for col: Array in cols:
			if int(col[1]) <= 0 or int(col[3]) <= 0:
				continue
			var src := Rect2i(int(col[0]), int(row[0]), int(col[1]), int(row[1]))
			var dst := Rect2i(rect.position.x + int(col[2]), rect.position.y + int(row[2]), int(col[3]), int(row[3]))
			canvas.draw_texture_rect_region(nine, _r2(dst.position, dst.size), _r2(src.position, src.size), tint)


static func _fits(stamp: Dictionary, container: Rect2i) -> bool:
	var size: Vector2i = _stamp_size(stamp)
	if size.x <= 0 or size.y <= 0:
		return false
	var slack: int = ANY_INSET * 2 if String(stamp.get("anchor", "any")) == "any" else 0
	return size.x + slack <= container.size.x and size.y + slack <= container.size.y


static func _area(stamp: Dictionary) -> int:
	var size: Vector2i = _stamp_size(stamp)
	return size.x * size.y


static func _stamp_size(stamp: Dictionary) -> Vector2i:
	var r: Variant = stamp.get("rect", [])
	if not (r is Array) or (r as Array).size() < 4:
		return Vector2i.ZERO
	return Vector2i(int((r as Array)[2]), int((r as Array)[3]))


static func _stamp_src(stamp: Dictionary) -> Rect2i:
	var r: Array = stamp["rect"]
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


## Pick one stamp of `pool` at random and place it; false when the pool is empty. The RNG is
## consumed only when a stamp is placed, so the sequence stays stable across pool contents of
## the same size.
static func _pick_one(out: Array[Dictionary], pool: Array, container: Rect2i, face: Rect2i, rng: RandomNumberGenerator) -> bool:
	if pool.is_empty():
		return false
	var stamp: Dictionary = pool[rng.randi() % pool.size()]
	var size: Vector2i = _stamp_size(stamp)
	var pos: Vector2i = _anchor_pos(String(stamp.get("anchor", "any")), size, container, face, rng)
	pos.x = clampi(pos.x, container.position.x, container.end.x - size.x)
	pos.y = clampi(pos.y, container.position.y, container.end.y - size.y)
	out.append({
		"name": String(stamp.get("name", "")),
		"pos": pos,
		"size": size,
		"src": _stamp_src(stamp),
		"kind": String(stamp.get("kind", "")),
	})
	return true


## Anchor vocabulary of the stamps JSON. `container` is the face for cracks / covers / speckles
## and the slab's outer rect for chips; the `*_face` anchors sit on the face's bottom row in
## either case (a chip at the face bottom bites the slab's left / right edge above the lip).
static func _anchor_pos(anchor: String, size: Vector2i, c: Rect2i, face: Rect2i, rng: RandomNumberGenerator) -> Vector2i:
	match anchor:
		"top_left":
			return c.position
		"top_right":
			return Vector2i(c.end.x - size.x, c.position.y)
		"bottom_left":
			return Vector2i(c.position.x, c.end.y - size.y)
		"bottom_right":
			return c.end - size
		"bottom_left_face":
			return Vector2i(c.position.x, face.end.y - size.y)
		"bottom_right_face":
			return Vector2i(c.end.x - size.x, face.end.y - size.y)
		"top_edge":
			return Vector2i(c.position.x + _edge_offset(c.size.x - size.x, EDGE_MIN_OFFSET, rng), c.position.y)
		"left_edge":
			return Vector2i(c.position.x, c.position.y + _edge_offset(c.size.y - size.y - LEFT_EDGE_BOTTOM_GAP + EDGE_MIN_OFFSET, EDGE_MIN_OFFSET, rng))
		"lip_bottom":
			return Vector2i(c.position.x + _edge_offset(c.size.x - size.x, EDGE_MIN_OFFSET, rng), c.end.y - size.y)
		_:
			var max_x: int = c.size.x - size.x - ANY_INSET
			var max_y: int = c.size.y - size.y - ANY_INSET
			return c.position + Vector2i(rng.randi_range(ANY_INSET, maxi(max_x, ANY_INSET)), rng.randi_range(ANY_INSET, maxi(max_y, ANY_INSET)))


## A random offset in [min_off, span - min_off], min_off when the span is too short.
static func _edge_offset(span: int, min_off: int, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(min_off, maxi(span - min_off, min_off))


## x positions of the mortar joints inside face `f`: block boundaries of FACE_BLOCKS laid on an
## absolute x grid, phase-shifted by the face row so courses stagger; never on the face's ends.
static func _face_joints(f: Rect2i) -> Array[int]:
	var out: Array[int] = []
	var period: int = 0
	for w: int in FACE_BLOCKS:
		period += w
	var phase: int = (f.position.y * 7) % period
	var start: int = f.position.x - period
	var x: int = start - ((start + phase) % period + period) % period
	var bi: int = 0
	while x < f.end.x:
		x += FACE_BLOCKS[bi]
		bi = (bi + 1) % FACE_BLOCKS.size()
		if x > f.position.x + 1 and x < f.end.x - 1:
			out.append(x)
	return out


## True when another cell's bottom row touches `cells[i]`'s top row and overlaps it in x.
static func _has_cell_touching_above(cells: Array[Rect2i], i: int) -> bool:
	var c: Rect2i = cells[i]
	for j: int in cells.size():
		if j == i:
			continue
		var o: Rect2i = cells[j]
		if o.end.y == c.position.y and o.position.x < c.end.x and o.end.x > c.position.x:
			return true
	return false


static func _palette_color(palette: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = palette.get(key, null)
	if v is Color:
		return v
	if v is String and Color.html_is_valid(String(v)):
		return Color.html(String(v))
	return fallback


## Integer rect → Rect2 without ever introducing a fractional component.
static func _r2(pos: Vector2i, size: Vector2i) -> Rect2:
	return Rect2(Vector2(pos), Vector2(size))

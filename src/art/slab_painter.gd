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


# --- platform --------------------------------------------------------------------------------


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
		var top: int = decks[0].position.y
		var bottom: int = decks[0].end.y
		for d: Rect2i in decks:
			top = mini(top, d.position.y)
			bottom = maxi(bottom, d.end.y)
		canvas.draw_rect(_r2(Vector2i(divider_x, top), Vector2i(1, bottom - top)), divider_c)


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

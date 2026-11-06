class_name VoxelPiece
extends RefCounted
## Pure renderer of a field piece as a ground Block pickup, in art px (design/art/forest-integration-pickup-plan-2026-11-05.md
## section 4.2). No nodes, no time: PickupLayer picks the crack stage and the seed; this class turns them into pixels.
## (The class name is kept from the first, rotating voxel version.)
##
## 2026-11-06 (user, "Ground Block Pickup Visual Redesign"): an Ancient Stone Sigil. The player must read the exact
## shape and orientation before picking it up, so a Block is a flat 2D polyomino inlaid on the floor tile, built from
## one reusable stone square repeated over Piece.relative_cells (hand orientation, never rotated or reshaped): a thin
## dark outline shared between neighbouring squares (PX_INK), a lighter upper-left edge (PX_LIT), a darker lower-right
## edge (PX_DARK) and a flat face (PX_TOP). Muted materials (aged ivory stone, muted violet Odd Block, grey rotten). No
## float, bob, rotation, shadow, particles or glow. No anti-aliasing.
## 2026-11-06 (user: look older, fit the game's style): weathered stone ([method _weather]): each square big enough
## carries the culture's one motif, a "square within a square" engraved 1 px (PX_SEAM, region brief 0.1), one small
## pit, and the silhouette's convex outer corners are worn away by 1 px. The shape never changes.
##
## A frame is a palette-index buffer ([method render_frame]) so tests read it without a renderer; [method to_image]
## turns it into an RGBA Image with a ramp of [method ramp].
## Freshness = progressive cracking (user 2026-11-05): [method crack_stage] maps the freshness share to
## STAGE_INTACT / STAGE_HAIRLINE / STAGE_DEEP with FieldDropsView.FRESH_RATIO / WARN_RATIO; hairline = 1 px ink cracks
## on the stone faces, deep = longer cracks and chipped corners (pixels missing at the edge).
## Expiry = crumble in place ([method crumble_left]): the squares vanish one by one in a seeded order, nothing flies.
## Tuning: assets/art/vfx/pickup_voxel.json (defaults below when a key is missing).

## Tuning file (see the header).
const CONFIG_PATH: String = "res://assets/art/vfx/pickup_voxel.json"
## Ramp ids of [method ramp].
const RAMP_NORMAL: String = "normal"
const RAMP_ODD: String = "odd"
const RAMP_ROTTEN: String = "rotten"
## Crack stages ([method crack_stage]).
const STAGE_INTACT: int = 0
const STAGE_HAIRLINE: int = 1
const STAGE_DEEP: int = 2
## Palette indices of a frame buffer (0 = transparent). PX_TOP = stone face, PX_LIT = lighter upper-left edge,
## PX_DARK = darker lower-right edge, PX_INK = thin dark outline / cracks; PX_SEAM is kept for the ramp shape.
const PX_NONE: int = 0
const PX_TOP: int = 1
const PX_LIT: int = 2
const PX_DARK: int = 3
const PX_SEAM: int = 4
const PX_INK: int = 5
## Transparent margin round the body.
const PAD: int = 1

## Defaults for every key of CONFIG_PATH (the file overrides them key by key, one level deep for the blocks).
const DEFAULTS: Dictionary = {
	"ink": "2B2620",
	"ramps": {
		"normal": {"top": "C9BB9B", "lit": "DCCFB0", "dark": "8F8167", "seam": "A8997B"},
		"odd": {"top": "A8829F", "lit": "C2A2BA", "dark": "715168", "seam": "8E6C86"},
		"rotten": {"top": "8A8790", "lit": "A6A4A8", "dark": "5E5C63", "seam": "4E4C52"},
	},
	"width_ratio": 0.68, "height_ratio": 0.8, "edge_min": 4, "edge_max": 14,
	"crack": {"hairline_lines": 2, "deep_lines": 4, "hairline_steps": 3, "deep_steps": 6, "step_cells": 0.22,
		"hairline_side": 1, "deep_side": 2, "chips": 3, "chip_px": 2, "shake_px": 1, "shake_sec": 0.08},
	"shatter": {"crumble_sec": 0.4},
	"weather": {"motif_min": 7, "pits": 1, "worn_corners": 1},
}

static var _config: Dictionary = {}


## The merged tuning (CONFIG_PATH over DEFAULTS), loaded once.
static func config() -> Dictionary:
	if not _config.is_empty():
		return _config
	var out: Dictionary = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			for key: Variant in (parsed as Dictionary).keys():
				var value: Variant = parsed[key]
				if value is Dictionary and out.get(key) is Dictionary:
					(out[key] as Dictionary).merge(value as Dictionary, true)
				else:
					out[key] = value
		else:
			push_warning("VoxelPiece: %s is not a JSON object, using defaults" % CONFIG_PATH)
	_config = out
	return _config


## A number of the tuning ([param block] "" = top level).
static func num(key: String, block: String = "") -> float:
	var src: Dictionary = config() if block.is_empty() else config().get(block, {})
	var fallback: Dictionary = DEFAULTS if block.is_empty() else DEFAULTS.get(block, {})
	return float(src.get(key, fallback.get(key, 0.0)))


## The outline colour (Ink).
static func ink() -> Color:
	return Color(str(config().get("ink", DEFAULTS["ink"])))


## The colour ramp [param id] (RAMP_*): keys top, lit, dark, seam. Unknown ids give the normal ramp.
static func ramp(id: String) -> Dictionary:
	var ramps: Dictionary = config().get("ramps", DEFAULTS["ramps"])
	var raw: Dictionary = ramps.get(id, ramps.get(RAMP_NORMAL, DEFAULTS["ramps"][RAMP_NORMAL]))
	var out: Dictionary = {}
	for key: String in ["top", "lit", "dark", "seam"]:
		out[key] = Color(str(raw.get(key, DEFAULTS["ramps"][RAMP_NORMAL][key])))
	return out


## The ramp id a piece is drawn in: rotten grey, Odd Block violet-magenta, else the fixed normal gold.
static func ramp_id_for(piece: Piece, rotten: bool) -> String:
	if rotten or (piece != null and piece.is_rotten()):
		return RAMP_ROTTEN
	if piece != null and piece.is_odd():
		return RAMP_ODD
	return RAMP_NORMAL


## Crack stage of a freshness share [param ratio] (left / total): >= FieldDropsView.FRESH_RATIO intact, >=
## FieldDropsView.WARN_RATIO hairline cracks, below that deep cracks.
static func crack_stage(ratio: float) -> int:
	if ratio >= FieldDropsView.FRESH_RATIO:
		return STAGE_INTACT
	if ratio >= FieldDropsView.WARN_RATIO:
		return STAGE_HAIRLINE
	return STAGE_DEEP


## Horizontal unit (art px, the x pitch of one stone square) for [param cells] on a cell [param cell_width] x
## [param cell_height] art px, from the shape's bounding box: its width takes width_ratio of the cell width and its
## height (rows of [method edge_y_for] px, [param aspect] = the cell's height / width on the flat floor) at most
## height_ratio of the cell height; clamped to edge_min..edge_max (edge_max keeps a 1- or 2-wide piece from covering
## the stone; edge_min 4 keeps edge, face and edge in every square). The shape itself is never changed to fit.
static func edge_for(cells: Array[Vector2i], cell_width: float, cell_height: float = INF, aspect: float = 1.0) -> int:
	var dims: Vector2i = _dims(cells)
	var unit: int = floori(cell_width * num("width_ratio") / float(maxi(dims.x, 1)))
	if cell_height < INF:
		unit = mini(unit, floori(cell_height * num("height_ratio") / (float(maxi(dims.y, 1)) * maxf(aspect, 0.1))))
	return clampi(unit, int(num("edge_min")), int(num("edge_max")))


## Vertical pitch of a square of x pitch [param edge] on a floor cell [param aspect] (height / width) tall: the
## square is squashed like the stone tile it lies on (2026-11-06, user: follow the stone's tilt), never under
## edge_min rows.
static func edge_y_for(edge: int, aspect: float) -> int:
	return maxi(roundi(float(edge) * aspect), int(num("edge_min")))


## Size of a frame of [param cells] at pitch [param edge] x [param edge_y] (0 = square) and its anchor (the pixel at
## the shape's centre). The body is dims * pitch + 1 px (outlines shared between squares) plus PAD all round.
static func frame_layout(cells: Array[Vector2i], edge: int, edge_y: int = 0) -> Dictionary:
	var ey: int = edge_y if edge_y > 0 else edge
	var dims: Vector2i = _dims(cells)
	var body := Vector2i(dims.x * edge + 1, dims.y * ey + 1)
	@warning_ignore("integer_division")
	var anchor := Vector2i(PAD + body.x / 2, PAD + body.y / 2)
	return {"size": body + Vector2i(PAD * 2, PAD * 2), "anchor": anchor}


## The frame rect (frame px) of the square of cell [param cell] (outline included) for a piece whose bounding box
## starts at [param lo] (see [method lo_of]).
static func square_rect(cell: Vector2i, lo: Vector2i, edge: int, edge_y: int = 0) -> Rect2i:
	var ey: int = edge_y if edge_y > 0 else edge
	return Rect2i(Vector2i(PAD + (cell.x - lo.x) * edge, PAD + (cell.y - lo.y) * ey), Vector2i(edge + 1, ey + 1))


## The top-left cell of the bounding box of [param cells].
static func lo_of(cells: Array[Vector2i]) -> Vector2i:
	return _lo(cells)


## One frame of [param cells] (Piece.relative_cells) as palette indices: keys size (Vector2i), anchor (Vector2i, see
## [method frame_layout]), px (PackedByteArray, row-major, PX_*). Every cell is the same stone square (see the
## header), [param edge] x [param edge_y] px (0 = square). [param stage] a crack stage, [param seed] the crack
## layout, [param mark_x] the rotten piece's X.
static func render_frame(cells: Array[Vector2i], edge: int, stage: int = STAGE_INTACT, seed: int = 0, mark_x: bool = false, edge_y: int = 0) -> Dictionary:
	var ey: int = edge_y if edge_y > 0 else edge
	var layout: Dictionary = frame_layout(cells, edge, ey)
	var size: Vector2i = layout["size"]
	var px := PackedByteArray()
	px.resize(size.x * size.y)
	var lo: Vector2i = _lo(cells)
	var proj := func(x: float, _y: float, z: float) -> Vector3:
		return Vector3(PAD + (x - lo.x) * edge, PAD + (z - lo.y) * ey, 0.0)
	for c: Vector2i in cells:
		var r: Rect2i = square_rect(c, lo, edge, ey)
		for j: int in ey + 1:
			for i: int in edge + 1:
				var v: int = PX_TOP
				if i == 0 or j == 0 or i == edge or j == ey:
					v = PX_INK
				elif i == edge - 1 or j == ey - 1:
					v = PX_DARK
				elif i == 1 or j == 1:
					v = PX_LIT
				px[(r.position.y + j) * size.x + r.position.x + i] = v
	_weather(px, size, cells, lo, edge, ey)
	if stage >= STAGE_HAIRLINE:
		_crack(px, size, cells, stage, seed, proj, 1.0, 0.0)
	if stage >= STAGE_DEEP:
		_chip(px, size, cells, seed, proj)
	if mark_x:
		_mark_x(px, size)
	return {"size": size, "anchor": layout["anchor"], "px": px}


## Frame [param frame] ([method render_frame]) as an RGBA8 Image in ramp [param ramp_id].
static func to_image(frame: Dictionary, ramp_id: String) -> Image:
	var size: Vector2i = frame["size"]
	var px: PackedByteArray = frame["px"]
	var r: Dictionary = ramp(ramp_id)
	var colours: Array[Color] = [Color(0, 0, 0, 0), r["top"], r["lit"], r["dark"], r["seam"], ink()]
	var image: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			var i: int = px[y * size.x + x]
			if i != PX_NONE:
				image.set_pixel(x, y, colours[i])
	return image


## Number of 4-connected regions of stone (any coloured index, outline / cracks excluded) in [param frame]: one per
## square, since the shared outline separates the squares (tests).
static func count_squares(frame: Dictionary) -> int:
	var size: Vector2i = frame["size"]
	var px: PackedByteArray = frame["px"]
	var body := PackedByteArray()
	body.resize(px.size())
	for i: int in px.size():
		body[i] = 1 if _COLOURED.has(int(px[i])) else 0
	return count_regions({"size": size, "px": body}, 1)


## Number of 4-connected regions of palette index [param index] in [param frame] (tests: one top region per cube).
static func count_regions(frame: Dictionary, index: int) -> int:
	var size: Vector2i = frame["size"]
	var px: PackedByteArray = frame["px"]
	var seen := PackedByteArray()
	seen.resize(px.size())
	var regions: int = 0
	for start: int in px.size():
		if px[start] != index or seen[start] != 0:
			continue
		regions += 1
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x: int = i % size.x
			@warning_ignore("integer_division")
			var y: int = i / size.x
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
					continue
				var j: int = ny * size.x + nx
				if px[j] == index and seen[j] == 0:
					seen[j] = 1
					stack.append(j)
	return regions


## The opaque bounding rect of [param frame] (frame px; empty Rect2i when nothing is drawn).
static func used_rect(frame: Dictionary) -> Rect2i:
	var size: Vector2i = frame["size"]
	var px: PackedByteArray = frame["px"]
	var lo := Vector2i(size.x, size.y)
	var hi := Vector2i(-1, -1)
	for i: int in px.size():
		if px[i] == PX_NONE:
			continue
		@warning_ignore("integer_division")
		var p := Vector2i(i % size.x, i / size.x)
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	if hi.x < 0:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## Crumble in place [param t] seconds after expiry of a piece of [param count] squares: the indices (into its cells)
## still standing. All of them at 0, then one vanishes after another in an order seeded by [param seed] (the same
## for the same point), none from crumble_sec on (and none before 0). Nothing flies (2026-11-06: no particles).
static func crumble_left(t: float, count: int, seed: int) -> Array[int]:
	var out: Array[int] = []
	var total: float = maxf(num("crumble_sec", "shatter"), 0.01)
	if t < 0.0 or t >= total or count <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed) + 7919
	var order: Array[int] = []
	for k: int in count:
		order.append(k)
	for k: int in range(count - 1, 0, -1):
		var j: int = rng.randi_range(0, k)
		var tmp: int = order[k]
		order[k] = order[j]
		order[j] = tmp
	var gone: int = floori(t / total * float(count + 1))
	for k: int in count:
		if order.find(k) >= gone:
			out.append(k)
	return out


## Seconds a crumble lasts.
static func shatter_sec() -> float:
	return num("crumble_sec", "shatter")


# --- internals ------------------------------------------------------------------------------------------------------

static func _dims(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ONE
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c: Vector2i in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return hi - lo + Vector2i.ONE


static func _lo(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO
	var lo: Vector2i = cells[0]
	for c: Vector2i in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
	return lo


# Centroid of the cell centres (the vertical rotation axis), in cell units.
static func _pivot(cells: Array[Vector2i]) -> Vector2:
	var sum := Vector2.ZERO
	for c: Vector2i in cells:
		sum += Vector2(c) + Vector2(0.5, 0.5)
	return sum / float(maxi(cells.size(), 1))


static func _xy(pts: Array[Vector3]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector3 in pts:
		out.append(Vector2(p.x, p.y))
	return out


# Scanline fill at pixel centres (even-odd), no anti-aliasing.
static func _fill_poly(px: PackedByteArray, size: Vector2i, pts: PackedVector2Array, index: int) -> void:
	var lo_y: float = INF
	var hi_y: float = -INF
	for p: Vector2 in pts:
		lo_y = minf(lo_y, p.y)
		hi_y = maxf(hi_y, p.y)
	var n: int = pts.size()
	for y: int in range(maxi(0, floori(lo_y)), mini(size.y, ceili(hi_y) + 1)):
		var yc: float = y + 0.5
		var xs: Array[float] = []
		for i: int in n:
			var p1: Vector2 = pts[i]
			var p2: Vector2 = pts[(i + 1) % n]
			if (p1.y <= yc and yc < p2.y) or (p2.y <= yc and yc < p1.y):
				xs.append(p1.x + (yc - p1.y) * (p2.x - p1.x) / (p2.y - p1.y))
		xs.sort()
		for i: int in range(0, xs.size() - 1, 2):
			for x: int in range(maxi(0, roundi(xs[i])), mini(size.x, roundi(xs[i + 1]))):
				px[y * size.x + x] = index


# Bresenham line between projected points [param a] / [param b] (x, y used), painting [param index] only over
# pixels whose index is in [param over].
static func _line(px: PackedByteArray, size: Vector2i, a: Vector3, b: Vector3, index: int, over: Array) -> void:
	var x0: int = floori(a.x)
	var y0: int = floori(a.y)
	var x1: int = floori(b.x)
	var y1: int = floori(b.y)
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		if x0 >= 0 and y0 >= 0 and x0 < size.x and y0 < size.y and over.has(px[y0 * size.x + x0]):
			px[y0 * size.x + x0] = index
		if x0 == x1 and y0 == y1:
			break
		var e2: int = err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


# 1 px ink round the silhouette (4-neighbours of a body pixel; crack ink inside the body counts as body).
static func _outline(px: PackedByteArray, size: Vector2i) -> void:
	var src: PackedByteArray = px.duplicate()
	for y: int in size.y:
		for x: int in size.x:
			if src[y * size.x + x] != PX_NONE:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < size.x and ny < size.y:
					var v: int = src[ny * size.x + nx]
					if v != PX_NONE:
						px[y * size.x + x] = PX_INK
						break


const _COLOURED: Array = [PX_TOP, PX_LIT, PX_DARK, PX_SEAM]


# Cracks in model space: random walks over the stone faces and short zigzags at exposed bottom edges;
# the deep stage draws the full layout, the hairline stage a prefix of it (same seed, same rng order).
static func _crack(px: PackedByteArray, size: Vector2i, cells: Array[Vector2i], stage: int, seed: int, proj: Callable, ca: float, sa: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed) + 104729
	var deep: bool = stage >= STAGE_DEEP
	var lines_all: int = int(num("deep_lines", "crack"))
	var lines: int = lines_all if deep else int(num("hairline_lines", "crack"))
	var steps_all: int = int(num("deep_steps", "crack"))
	var steps: int = steps_all if deep else int(num("hairline_steps", "crack"))
	var step_len: float = num("step_cells", "crack")
	# Generate the deep layout always (same rng order), the hairline stage keeps a prefix of it.
	for l: int in lines_all:
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var p := Vector2(c) + Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75))
		var pts: Array[Vector2] = [p]
		for s: int in steps_all:
			var d := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * step_len
			var q: Vector2 = p + d
			if not cells.has(Vector2i(floori(q.x), floori(q.y))):
				q = p - d
			if not cells.has(Vector2i(floori(q.x), floori(q.y))):
				q = p
			pts.append(q)
			p = q
		if l >= lines:
			continue
		for s: int in mini(steps, pts.size() - 1):
			_line(px, size, proj.call(pts[s].x, 1.0, pts[s].y), proj.call(pts[s + 1].x, 1.0, pts[s + 1].y), PX_INK, _COLOURED)
	# Side zigzags on exterior faces that face the camera now.
	var faces: Array = []
	for c: Vector2i in cells:
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			if not cells.has(c + d):
				faces.append([c, d])
	var sides_all: int = int(num("deep_side", "crack"))
	var sides: int = sides_all if deep else int(num("hairline_side", "crack"))
	for k: int in sides_all:
		var f: Array = faces[rng.randi_range(0, faces.size() - 1)]
		var along: float = rng.randf_range(0.3, 0.7)
		var wiggle: float = rng.randf_range(-0.15, 0.15)
		if k >= sides:
			continue
		var c2: Vector2i = f[0]
		var d2: Vector2i = f[1]
		if d2.x * sa + d2.y * ca <= 0.0:
			continue
		var base := Vector2(c2) + Vector2(0.5, 0.5) + Vector2(d2) * 0.5
		var tangent := Vector2(-d2.y, d2.x)
		var a1: Vector2 = base + tangent * (along - 0.5)
		var a2: Vector2 = a1 + tangent * wiggle
		var a3: Vector2 = a1 - tangent * wiggle
		var depth_k: float = 0.35 if deep else 0.6
		_line(px, size, proj.call(a1.x, 1.0, a1.y), proj.call(a2.x, 0.75, a2.y), PX_INK, _COLOURED)
		_line(px, size, proj.call(a2.x, 0.75, a2.y), proj.call(a3.x, depth_k, a3.y), PX_INK, _COLOURED)


# Deep stage: chipped corners. Convex top corners (touched by exactly one cell) lose a chip_px block, outline
# included, AFTER the outline pass, so the notch reads as pixels missing from the edge. Own rng (seeded apart from the
# cracks), so the chips are the same at every angle.
static func _chip(px: PackedByteArray, size: Vector2i, cells: Array[Vector2i], seed: int, proj: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed) + 15485863
	var corners: Array[Vector2i] = []
	for c: Vector2i in cells:
		for k2: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var v: Vector2i = c + k2
			var touching: int = 0
			for o: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				if cells.has(v + o):
					touching += 1
			if touching == 1 and not corners.has(v):
				corners.append(v)
	var chip: int = maxi(int(num("chip_px", "crack")), 1)
	var pivot: Vector2 = _pivot(cells)
	var centre: Vector3 = proj.call(pivot.x, 1.0, pivot.y)
	for k3: int in mini(int(num("chips", "crack")), corners.size()):
		var v2: Vector2i = corners[rng.randi_range(0, corners.size() - 1)]
		var at: Vector3 = proj.call(float(v2.x), 1.0, float(v2.y))
		# The block covers the outline pixel at the corner and runs chip_px into the body (towards the centre).
		var sx: int = 1 if centre.x >= at.x else -1
		var sy: int = 1 if centre.y >= at.y else -1
		var cx: int = floori(at.x) - sx
		var cy: int = floori(at.y) - sy
		for j: int in chip + 1:
			for i: int in chip + 1:
				var xx: int = cx + i * sx
				var yy: int = cy + j * sy
				if xx >= 0 and yy >= 0 and xx < size.x and yy < size.y:
					px[yy * size.x + xx] = PX_NONE


# 2026-11-06 weathering (see the header). Engraved motif: an inset square ring 2 px inside the outline, on squares
# whose inner face is at least weather.motif_min px both ways. Pit: one PX_SEAM pixel per square at a spot seeded by
# the square's cell (same piece shape = same pits, so the cache still works), off the motif ring and the centre.
# Worn corners: the outline pixel at every convex outer corner of the silhouette is cleared.
static func _weather(px: PackedByteArray, size: Vector2i, cells: Array[Vector2i], lo: Vector2i, edge: int, ey: int) -> void:
	var motif_min: int = int(num("motif_min", "weather"))
	for c: Vector2i in cells:
		var r: Rect2i = square_rect(c, lo, edge, ey)
		var inner := Vector2i(edge - 1, ey - 1)
		if inner.x >= motif_min and inner.y >= motif_min:
			var a := Vector2i(3, 3)
			var b := Vector2i(edge - 3, ey - 3)
			for i: int in range(a.x, b.x + 1):
				for j: int in [a.y, b.y]:
					_set_if(px, size, r.position + Vector2i(i, j), PX_SEAM, [PX_TOP])
			for j: int in range(a.y, b.y + 1):
				for i: int in [a.x, b.x]:
					_set_if(px, size, r.position + Vector2i(i, j), PX_SEAM, [PX_TOP])
		if num("pits", "weather") > 0.0 and inner.x >= 4 and inner.y >= 4:
			var h: int = absi(hash(c * 7919 + Vector2i(13, 101)))
			var spot := Vector2i(2 + h % maxi(inner.x - 3, 1), 2 + (h / 7) % maxi(inner.y - 3, 1))
			@warning_ignore("integer_division")
			if spot != Vector2i((edge + 1) / 2, (ey + 1) / 2):
				_set_if(px, size, r.position + spot, PX_SEAM, [PX_TOP])
	if num("worn_corners", "weather") > 0.0:
		for c: Vector2i in cells:
			var r: Rect2i = square_rect(c, lo, edge, ey)
			for k: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				# Convex corner: no neighbour on either side towards it, nor diagonally.
				if cells.has(c + Vector2i(k.x, 0)) or cells.has(c + Vector2i(0, k.y)) or cells.has(c + k):
					continue
				var at := Vector2i(r.position.x + (0 if k.x < 0 else edge), r.position.y + (0 if k.y < 0 else ey))
				_set_if(px, size, at, PX_NONE, [PX_INK])


static func _set_if(px: PackedByteArray, size: Vector2i, at: Vector2i, index: int, over: Array) -> void:
	if at.x < 0 or at.y < 0 or at.x >= size.x or at.y >= size.y:
		return
	if over.has(int(px[at.y * size.x + at.x])):
		px[at.y * size.x + at.x] = index


# Rotten (Story 014): an ink X across the body, only over coloured pixels.
static func _mark_x(px: PackedByteArray, size: Vector2i) -> void:
	var r: Rect2i = used_rect({"size": size, "px": px})
	if r.size.x < 4 or r.size.y < 4:
		return
	var a := Vector3(r.position.x + 1, r.position.y + 1, 0)
	var b := Vector3(r.end.x - 2, r.end.y - 2, 0)
	var c := Vector3(r.end.x - 2, r.position.y + 1, 0)
	var d := Vector3(r.position.x + 1, r.end.y - 2, 0)
	_line(px, size, a, b, PX_INK, _COLOURED)
	_line(px, size, c, d, PX_INK, _COLOURED)

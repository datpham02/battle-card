class_name BoardGeometry
extends RefCounted
## The one definition of where the battle board's cells are on screen (ADR-0002). Every consumer that draws over,
## anchors on or hit-tests board cells asks this facade (the HUD's ghosts, labels and hazard tags, the field drops,
## the unit feet and shadows, the overlay VFX anchors, touch input), so they all agree on the same cell polygon.
##
## Two coordinate spaces:
## - MODEL space: the flat board in screen px, the layout ScreenLayout computes (cell rects, board rect). Code that
##   composes a decoration inside a cell (a bar along the bottom, an icon in a corner) builds it here, as before.
## - SCREEN space: where it is drawn. [method to_screen] maps model -> screen, [method to_model] back.
## Flat (back ratio 0 / off): the map is the identity and the model rects are exactly ScreenLayout's, so the flat
## build draws pixel-for-pixel what it drew before this facade. Perspective on (FloorPerspective, back ratio r): the
## model rects are snapped to whole art px (the floor slabs' own rects, FloorLayer.cell_art_rect) and the map is the
## floor homography, so a cell polygon here coincides with the slab the warp shader draws.
##
## The art-px helpers ([method warp_art], [method art_quad], ...) are the same map inside the 800x360 art canvas, for
## the art layers (UnitLayer, OverlayLayer). Sprites and VFX frames are never scaled: only their anchors move.

## Mitre limit of [method offset_polygon] (a corner never moves further than this many times the offset).
const MITRE_LIMIT: float = 4.0
## Entries of the per-frame [method of] cache (one per live CombatView; cleared when full).
const OF_CACHE_MAX: int = 8

static var _of_cache: Dictionary = {}

## The board this geometry describes.
var grid: BoardGrid = null
## Screen size (px) the layout is computed for.
var viewport_size: Vector2 = Vector2.ZERO
## The floor homography, or null while the board is flat.
var perspective: FloorPerspective = null


## The geometry of [param p_grid] at [param p_viewport_size] with back ratio [param back_ratio] (flat when the ratio
## is off, FloorPerspective.is_on). Null without a grid.
static func make(p_grid: BoardGrid, p_viewport_size: Vector2, back_ratio: float = FloorPerspective.OFF) -> BoardGeometry:
	if p_grid == null:
		return null
	var out := BoardGeometry.new()
	out.grid = p_grid
	out.viewport_size = p_viewport_size
	out.perspective = FloorPerspective.make(p_grid, p_viewport_size, back_ratio)
	return out


## The geometry the battle [param combat] draws right now (its grid, viewport size and CombatView.floor_back_ratio),
## or null when unbound / outside the tree. Cached per combat for the current process frame (every layer and view asks
## it, some per point); a change of grid, size or ratio inside the frame builds a fresh one.
static func of(combat: CombatView) -> BoardGeometry:
	if combat == null or not is_instance_valid(combat) or not combat.is_inside_tree() or combat.get_grid() == null:
		return null
	var grid: BoardGrid = combat.get_grid()
	var vp: Vector2 = combat.get_viewport_rect().size
	var ratio: float = combat.floor_back_ratio()
	var frame: int = Engine.get_process_frames()
	var key: int = combat.get_instance_id()
	var hit: Variant = _of_cache.get(key)
	if hit != null and hit["frame"] == frame and hit["grid"] == grid and hit["vp"] == vp and hit["ratio"] == ratio:
		return hit["geo"]
	var geo: BoardGeometry = make(grid, vp, ratio)
	if _of_cache.size() >= OF_CACHE_MAX:
		_of_cache.clear()
	_of_cache[key] = {"frame": frame, "grid": grid, "vp": vp, "ratio": ratio, "geo": geo}
	return geo


## True while the board is drawn in perspective.
func is_warped() -> bool:
	return perspective != null


# --- Model space (flat board, screen px) ---------------------------------------------------------------------------

## The model rect of board cell [param cell] (ScreenLayout.cell_rect; snapped to the slab's whole art px when warped).
func flat_cell_rect(cell: Vector2i) -> Rect2:
	var rect: Rect2 = ScreenLayout.cell_rect(grid, viewport_size, cell)
	if perspective == null:
		return rect
	return _snap_to_art(rect)


## The model bounding rect of [param cells] (empty Rect2 for none).
func flat_cells_rect(cells: Array[Vector2i]) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var out: Rect2 = flat_cell_rect(cells[0])
	for i: int in range(1, cells.size()):
		out = out.merge(flat_cell_rect(cells[i]))
	return out


## The model rect of the whole bounding board.
func flat_board_rect() -> Rect2:
	var rect: Rect2 = ScreenLayout.board_rect(grid, viewport_size)
	return rect if perspective == null else _snap_to_art(rect)


## The model rect of the player's half (left) or the enemy's half (right) of the bounding board.
func flat_half_rect(enemy: bool) -> Rect2:
	var board: Rect2 = flat_board_rect()
	var split: float = flat_divider_x()
	if enemy:
		return Rect2(split, board.position.y, board.end.x - split, board.size.y)
	return Rect2(board.position, Vector2(split - board.position.x, board.size.y))


## The model x of the divider between the halves.
func flat_divider_x() -> float:
	var x: float = ScreenLayout.divider_x(grid, viewport_size)
	if perspective == null:
		return x
	return ScreenLayout.from_art(viewport_size, Vector2(ScreenLayout.to_art(viewport_size, Vector2(x, 0.0)))).x


## The size of one cell in model px (font / label sizing; the same in both modes up to the art-px snap).
func cell_size() -> Vector2:
	return ScreenLayout.cell_size(grid, viewport_size)


# --- The map ---------------------------------------------------------------------------------------------------------

## Model point -> screen point.
func to_screen(model: Vector2) -> Vector2:
	return model if perspective == null else perspective.warp_screen(model)


## Screen point -> model point (the inverse of [method to_screen]).
func to_model(screen: Vector2) -> Vector2:
	return screen if perspective == null else perspective.unwarp_screen(screen)


## The model rect [param rect] on screen: its four corners mapped, clockwise from the top-left (straight edges stay
## straight under a homography, so this quad is exact).
func quad(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([to_screen(rect.position), to_screen(Vector2(rect.end.x, rect.position.y)), to_screen(rect.end), to_screen(Vector2(rect.position.x, rect.end.y))])


## The local scale of the map at model point [param model] (screen px per model px along x and y; Vector2.ONE flat).
func local_scale(model: Vector2) -> Vector2:
	if perspective == null:
		return Vector2.ONE
	var h: float = 0.5
	var dx: float = to_screen(model + Vector2(h, 0.0)).x - to_screen(model - Vector2(h, 0.0)).x
	var dy: float = to_screen(model + Vector2(0.0, h)).y - to_screen(model - Vector2(0.0, h)).y
	return Vector2(dx, dy) / (2.0 * h)


## An axis-aligned screen rect standing in for model rect [param rect] where a rect is needed (text, a panel, an
## icon, a circle): centred on the mapped centre, sized by the mapped mid-lines. [param rect] itself when flat.
func fit_rect(rect: Rect2) -> Rect2:
	if perspective == null:
		return rect
	var c: Vector2 = rect.get_center()
	var w: float = to_screen(Vector2(rect.end.x, c.y)).x - to_screen(Vector2(rect.position.x, c.y)).x
	var h: float = to_screen(Vector2(c.x, rect.end.y)).y - to_screen(Vector2(c.x, rect.position.y)).y
	var centre: Vector2 = to_screen(c)
	return Rect2(centre - Vector2(w, h) * 0.5, Vector2(w, h))


## The axis-aligned screen bounding box of model rect [param rect].
func bounds(rect: Rect2) -> Rect2:
	return polygon_bounds(quad(rect))


# --- Cells on screen -------------------------------------------------------------------------------------------------

## The screen polygon of board cell [param cell] (4 points clockwise from the top-left; the rect's corners flat).
func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	return quad(flat_cell_rect(cell))


## The screen polygon of the bounding rect of [param cells] (a rectangular multi-cell footprint).
func cells_polygon(cells: Array[Vector2i]) -> PackedVector2Array:
	return quad(flat_cells_rect(cells))


## The screen bounding box of board cell [param cell].
func cell_bounds(cell: Vector2i) -> Rect2:
	return bounds(flat_cell_rect(cell))


## The screen bounding box of [param cells] (empty Rect2 for none).
func cells_bounds(cells: Array[Vector2i]) -> Rect2:
	if cells.is_empty():
		return Rect2()
	return bounds(flat_cells_rect(cells))


## The screen polygon of the whole bounding board.
func board_polygon() -> PackedVector2Array:
	return quad(flat_board_rect())


## The screen bounding box of the whole bounding board.
func board_bounds() -> Rect2:
	return bounds(flat_board_rect())


## The screen bounding box of one half of the board (see [method flat_half_rect]).
func half_bounds(enemy: bool) -> Rect2:
	return bounds(flat_half_rect(enemy))


## The screen point at fraction [param at] (0..1 on each axis, from the top-left) of board cell [param cell].
func cell_point(cell: Vector2i, at: Vector2) -> Vector2:
	var rect: Rect2 = flat_cell_rect(cell)
	return to_screen(rect.position + rect.size * at)


## The screen centre of board cell [param cell] (the mapped model centre).
func cell_center(cell: Vector2i) -> Vector2:
	return cell_point(cell, Vector2(0.5, 0.5))


## The screen top-centre of board cell [param cell] (labels hang above it).
func cell_top_center(cell: Vector2i) -> Vector2:
	return cell_point(cell, Vector2(0.5, 0.0))


## The screen centre of the bounding rect of [param cells] (a footprint's centre).
func cells_center(cells: Array[Vector2i]) -> Vector2:
	return to_screen(flat_cells_rect(cells).get_center())


## The board cell under screen point [param point], or ScreenLayout.NO_CELL outside the bounding board (a missing
## cell is still returned: check BoardGrid.is_in_board).
func cell_at(point: Vector2) -> Vector2i:
	return cell_at_model(to_model(point))


## The board cell under MODEL point [param model] (see [method cell_at]).
func cell_at_model(model: Vector2) -> Vector2i:
	if perspective == null:
		return ScreenLayout.cell_at(grid, viewport_size, model)
	if not flat_board_rect().has_point(model):
		return ScreenLayout.NO_CELL
	# The snapped slabs differ from the unsnapped layout by under one art px: the estimate or a neighbour holds it.
	var guess: Vector2i = ScreenLayout.cell_at(grid, viewport_size, model.clamp(ScreenLayout.board_rect(grid, viewport_size).position, ScreenLayout.board_rect(grid, viewport_size).end - Vector2(0.001, 0.001)))
	if guess == ScreenLayout.NO_CELL:
		guess = Vector2i.ZERO
	for dy: int in [0, -1, 1]:
		for dx: int in [0, -1, 1]:
			var c: Vector2i = guess + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= grid.total_cols or c.y >= grid.rows:
				continue
			if flat_cell_rect(c).has_point(model):
				return c
	return guess


# --- Art px (inside the 800x360 art canvas) --------------------------------------------------------------------------

## The flat art rect of board cell [param cell] (FloorLayer.cell_art_rect: ScreenLayout.to_art_rect of the cell).
func cell_art_rect(cell: Vector2i) -> Rect2i:
	return ScreenLayout.to_art_rect(viewport_size, ScreenLayout.cell_rect(grid, viewport_size, cell))


## The flat art bounding rect of [param cells].
func cells_art_rect(cells: Array[Vector2i]) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var out: Rect2i = cell_art_rect(cells[0])
	for i: int in range(1, cells.size()):
		out = out.merge(cell_art_rect(cells[i]))
	return out


## Flat art point -> drawn art point.
func warp_art(p: Vector2) -> Vector2:
	return p if perspective == null else perspective.warp(p)


## Drawn art point -> flat art point.
func unwarp_art(p: Vector2) -> Vector2:
	return p if perspective == null else perspective.unwarp(p)


## A whole-art-px anchor [param p] moved onto the drawn board (the pixel centre is mapped, then floored); [param p]
## itself when flat. The rule every art anchor (unit feet, VFX feet, travel centres) follows.
func warp_art_px(p: Vector2i) -> Vector2i:
	if perspective == null:
		return p
	return Vector2i(perspective.warp(Vector2(p) + Vector2(0.5, 0.5)).floor())


## Flat art rect [param rect] as the drawn quad (clockwise from the top-left).
func art_quad(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([warp_art(rect.position), warp_art(Vector2(rect.end.x, rect.position.y)), warp_art(rect.end), warp_art(Vector2(rect.position.x, rect.end.y))])


## The drawn art polygon of board cell [param cell] (the slab the warp shader shows).
func cell_art_polygon(cell: Vector2i) -> PackedVector2Array:
	return art_quad(Rect2(cell_art_rect(cell)))


## The local scale of the art map at flat art point [param p] (Vector2.ONE flat).
func art_local_scale(p: Vector2) -> Vector2:
	if perspective == null:
		return Vector2.ONE
	var h: float = 0.5
	var dx: float = warp_art(p + Vector2(h, 0.0)).x - warp_art(p - Vector2(h, 0.0)).x
	var dy: float = warp_art(p + Vector2(0.0, h)).y - warp_art(p - Vector2(0.0, h)).y
	return Vector2(dx, dy) / (2.0 * h)


# --- Drawing ---------------------------------------------------------------------------------------------------------

## Fills model rect [param rect] on [param canvas] (draw_rect flat, the mapped quad warped).
func fill(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	if perspective == null:
		canvas.draw_rect(rect, color)
		return
	canvas.draw_colored_polygon(quad(rect), color)


## Outlines model rect [param rect] with a [param width] px stroke (draw_rect unfilled flat; warped, a mitred band
## centred on the mapped edges, so the corners close).
func outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	if perspective == null:
		canvas.draw_rect(rect, color, false, width)
		return
	draw_polygon_outline(canvas, quad(rect), color, width)


## A [param width] px line between model points [param a] and [param b], mapped.
func line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(to_screen(a), to_screen(b), color, width)


## Outlines convex polygon [param poly] with a [param width] px band centred on its edges (mitred corners).
static func draw_polygon_outline(canvas: CanvasItem, poly: PackedVector2Array, color: Color, width: float) -> void:
	if poly.size() < 3 or width <= 0.0:
		return
	var outer: PackedVector2Array = offset_polygon(poly, -width * 0.5)
	var inner: PackedVector2Array = offset_polygon(poly, width * 0.5)
	var n: int = poly.size()
	for i: int in n:
		var j: int = (i + 1) % n
		canvas.draw_colored_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), color)


## Convex polygon [param poly] with every edge moved [param px] towards the inside (negative = outwards), corners
## re-intersected (the exact form of Rect2.grow(-px) for any convex quad). Works for either winding.
static func offset_polygon(poly: PackedVector2Array, px: float) -> PackedVector2Array:
	var n: int = poly.size()
	if n < 3 or px == 0.0:
		return poly.duplicate()
	var centre: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		centre += p
	centre /= float(n)
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var prev: Vector2 = poly[(i - 1 + n) % n]
		var cur: Vector2 = poly[i]
		var next: Vector2 = poly[(i + 1) % n]
		var n1: Vector2 = _inward_normal(prev, cur, centre)
		var n2: Vector2 = _inward_normal(cur, next, centre)
		var bis: Vector2 = n1 + n2
		var denom: float = bis.dot(n1)
		if bis.length_squared() < 1e-12 or absf(denom) < 1e-9:
			out.append(cur + n1 * px)
			continue
		var k: float = clampf(1.0 / denom, -MITRE_LIMIT, MITRE_LIMIT)
		out.append(cur + bis * px * k)
	return out


# Unit normal of edge a -> b pointing to the side of [param inside].
static func _inward_normal(a: Vector2, b: Vector2, inside: Vector2) -> Vector2:
	var d: Vector2 = (b - a).normalized()
	var nrm := Vector2(-d.y, d.x)
	if nrm.dot(inside - a) < 0.0:
		nrm = -nrm
	return nrm


## The axis-aligned bounding box of [param poly].
static func polygon_bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var lo: Vector2 = poly[0]
	var hi: Vector2 = poly[0]
	for p: Vector2 in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


# A screen rect snapped to whole art px (to_art_rect then back): the floor slab's own rect.
func _snap_to_art(rect: Rect2) -> Rect2:
	var art: Rect2i = ScreenLayout.to_art_rect(viewport_size, rect)
	var s: float = float(ScreenLayout.art_scale(viewport_size))
	return Rect2(ScreenLayout.from_art(viewport_size, Vector2(art.position)), Vector2(art.size) * s)

class_name PieceDraw
extends RefCounted
## Drawing helper for a [Piece] as a mini shape: filled squares in its current rotation, fitted and
## centred in a rectangle. Shared by the field drops view, the bag view and (for the loose ghost) the
## HUD. Pure drawing on a given CanvasItem; no state. Story 041: the Odd Block look (ODD_* colours, outer edge, sparkle mark).
## Implements: Story 024 (Part B), Story 041 (Part C).

## Gap between two squares as a share of one square.
const GAP_RATIO: float = 0.08


## Edge length of one square when [param piece] is fitted into [param area], never above
## [param max_unit] (so a single cell does not fill the whole area).
static func unit_for(piece: Piece, area: Rect2, max_unit: float) -> float:
	var box: Vector2i = piece.size()
	return minf(minf(area.size.x / float(box.x), area.size.y / float(box.y)), max_unit)


## Rectangle of the whole shape (bounding box) when fitted and centred in [param area].
static func shape_rect(piece: Piece, area: Rect2, max_unit: float) -> Rect2:
	var unit: float = unit_for(piece, area, max_unit)
	var size := Vector2(piece.size()) * unit
	return Rect2(area.get_center() - size * 0.5, size)


## Draws the squares of [param piece] fitted and centred in [param area]; every square is filled
## with [param fill] and outlined with [param outline] (alpha 0 = no outline). ADR-0002: with the board's [param geo]
## ([param area] in its MODEL space, a mini shape lying on a board cell) every square is the mapped quad.
static func draw_shape(
	canvas: CanvasItem, piece: Piece, area: Rect2, fill: Color, outline: Color, max_unit: float = 1000000.0, geo: BoardGeometry = null
) -> void:
	if piece == null or area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var unit: float = unit_for(piece, area, max_unit)
	var origin: Vector2 = shape_rect(piece, area, max_unit).position
	var gap: float = unit * GAP_RATIO
	for cell: Vector2i in piece.relative_cells():
		var rect := Rect2(origin + Vector2(cell) * unit, Vector2(unit, unit)).grow(-gap * 0.5)
		if geo != null:
			geo.fill(canvas, rect, fill)
			if outline.a > 0.0:
				geo.outline(canvas, rect, outline, 2.0)
			continue
		canvas.draw_rect(rect, fill)
		if outline.a > 0.0:
			canvas.draw_rect(rect, outline, false, 2.0)


# --- Story 041: Odd Block (Khối Lạ) look ----------------------------------------
## Story 041: the Odd Block look shared by every view that draws a piece: a violet-magenta fill, a bright magenta
## edge around the shape's OUTER border (not around each square, so a big odd shape reads as one body) over a dark
## magenta under-stroke, and a small four-point sparkle mark. Hue chosen clear of the keyword colours (burn orange,
## frost / chill blues, fragile violet 0.62,0.32,0.88, seal dusk violet 0.36,0.26,0.58), the formation teal and the
## hit green / miss red: it is a hot pink-magenta with a strong blue part.
const ODD_FILL: Color = Color(0.85, 0.3, 0.8)
const ODD_EDGE: Color = Color(1.0, 0.3, 0.9)
const ODD_EDGE_DARK: Color = Color(0.32, 0.02, 0.3, 0.9)
const ODD_MARK_LIGHT: Color = Color(1.0, 0.86, 0.98)
## Edge stroke width (px) and the extra width of the dark under-stroke.
const ODD_EDGE_WIDTH: float = 3.0
const ODD_EDGE_UNDER_EXTRA: float = 3.0
## Mini shapes: edge width as a share of one square, never under ODD_EDGE_MIN_WIDTH px.
const ODD_EDGE_UNIT_RATIO: float = 0.16
const ODD_EDGE_MIN_WIDTH: float = 1.5
## Sparkle mark: inner radius of the star as a share of its outer radius, and the dark octagon badge as a share of it.
const ODD_MARK_INNER_RATIO: float = 0.36
const ODD_MARK_DISC_RATIO: float = 1.12


## Story 041: true when [param piece] is an Odd Block (null-safe).
static func is_odd(piece: Piece) -> bool:
	return piece != null and piece.is_odd()


## Story 041: true when any of [param shape_ids] names an Odd Block (labels of a cast: "odd:<key>").
static func any_odd_id(shape_ids: Array) -> bool:
	for id: Variant in shape_ids:
		if str(id).begins_with(Piece.ODD_PREFIX):
			return true
	return false


## Story 041: [param piece] fitted in [param area] like [method draw_shape] (fill [param fill], thin dark square
## outlines) plus the odd magenta edge around the whole shape. Used for an Odd Block in the bag, on the field
## and in the boss hand row. ADR-0002: [param geo] as in [method draw_shape].
static func draw_odd_shape(
	canvas: CanvasItem, piece: Piece, area: Rect2, fill: Color, max_unit: float = 1000000.0, edge_width: float = ODD_EDGE_WIDTH, geo: BoardGeometry = null
) -> void:
	if piece == null or area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	draw_shape(canvas, piece, area, fill, Color(ODD_EDGE_DARK, 0.55), max_unit, geo)
	var unit: float = unit_for(piece, area, max_unit)
	# A small shape (big odd blocks in a bag slot) gets a thinner edge so its squares stay readable.
	var width: float = clampf(unit * ODD_EDGE_UNIT_RATIO, ODD_EDGE_MIN_WIDTH, edge_width)
	draw_odd_edge(canvas, piece.relative_cells(), shape_rect(piece, area, max_unit).position, Vector2(unit, unit), width, geo)


## Story 041: the odd edge (dark under-stroke, then bright magenta) along the OUTER border of [param cells] laid on
## a uniform grid: cell c covers Rect2(origin + unit * c, unit). Inner edges between two cells of the set are skipped.
## ADR-0002: on the battle board pass the board's [param geo] (origin / unit in its MODEL space): every corner goes
## through BoardGeometry.to_screen, so the frame is the outline of the drawn (perspective) polygon; null = as given.
static func draw_odd_edge(canvas: CanvasItem, cells: Array[Vector2i], origin: Vector2, unit: Vector2, width: float = ODD_EDGE_WIDTH, geo: BoardGeometry = null) -> void:
	for pass_index: int in 2:
		var color: Color = ODD_EDGE_DARK if pass_index == 0 else ODD_EDGE
		var w: float = width + minf(ODD_EDGE_UNDER_EXTRA, width) if pass_index == 0 else width
		for cell: Vector2i in cells:
			var tl: Vector2 = origin + unit * Vector2(cell)
			var tr_: Vector2 = tl + Vector2(unit.x, 0.0)
			var bl: Vector2 = tl + Vector2(0.0, unit.y)
			var br: Vector2 = tl + unit
			if geo != null:
				tl = geo.to_screen(tl)
				tr_ = geo.to_screen(tr_)
				bl = geo.to_screen(bl)
				br = geo.to_screen(br)
			if not cells.has(cell + Vector2i.UP):
				canvas.draw_line(tl, tr_, color, w)
			if not cells.has(cell + Vector2i.DOWN):
				canvas.draw_line(bl, br, color, w)
			if not cells.has(cell + Vector2i.LEFT):
				canvas.draw_line(tl, bl, color, w)
			if not cells.has(cell + Vector2i.RIGHT):
				canvas.draw_line(tr_, br, color, w)


## Story 041: the small odd sparkle mark: a dark magenta disc with a magenta rim and a light four-point star,
## centred at [param center], star tips [param radius] px from the centre.
static func draw_odd_mark(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	# Angular badge (2026-11-02 rule: no circles but the joystick): a flat-topped octagon behind the sparkle.
	var badge := PackedVector2Array()
	for i: int in 8:
		var a: float = PI * 0.125 + PI * 0.25 * i
		badge.append(center + Vector2(cos(a), sin(a)) * radius * ODD_MARK_DISC_RATIO)
	canvas.draw_colored_polygon(badge, ODD_EDGE_DARK)
	badge.append(badge[0])
	canvas.draw_polyline(badge, ODD_EDGE, maxf(radius * 0.18, 1.5))
	var points := PackedVector2Array()
	for i: int in 8:
		var angle: float = -PI * 0.5 + PI * 0.25 * i
		var r: float = radius * (1.0 if i % 2 == 0 else ODD_MARK_INNER_RATIO)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	canvas.draw_colored_polygon(points, ODD_MARK_LIGHT)

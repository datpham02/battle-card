class_name PieceDraw
extends RefCounted
## Drawing helper for a [Piece] as a mini shape: filled squares in its current rotation, fitted and
## centred in a rectangle. Shared by the field drops view, the bag view and (for the loose ghost) the
## HUD. Pure drawing on a given CanvasItem; no state.
## Implements: Story 024 (Part B).

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
## with [param fill] and outlined with [param outline] (alpha 0 = no outline).
static func draw_shape(
	canvas: CanvasItem, piece: Piece, area: Rect2, fill: Color, outline: Color, max_unit: float = 1000000.0
) -> void:
	if piece == null or area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var unit: float = unit_for(piece, area, max_unit)
	var origin: Vector2 = shape_rect(piece, area, max_unit).position
	var gap: float = unit * GAP_RATIO
	for cell: Vector2i in piece.relative_cells():
		var rect := Rect2(origin + Vector2(cell) * unit, Vector2(unit, unit)).grow(-gap * 0.5)
		canvas.draw_rect(rect, fill)
		if outline.a > 0.0:
			canvas.draw_rect(rect, outline, false, 2.0)

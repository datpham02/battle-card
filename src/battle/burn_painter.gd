class_name BurnPainter
extends RefCounted
## Burning cells (Dot, Story 010), painted on the floor (Story 046 Part C follow-up; art bible 8.6 floor-layer rule):
## FloorDynamicLayer draws them UNDER the units, before the boss telegraph, in integer art px of the battle canvas.
## The look is the one CutHudView drew at screen resolution: an orange fire tint, dark 1 px diagonal hatching, a 1 px
## orange outline inset 1 px, a flame glyph (two stacked triangles) and a thin remaining-time bar along the cell's
## bottom that shrinks from full at ignition to empty when the cell burns out. Hue and hatching keep it apart from the
## red telegraph (art bible P3: red is the telegraph's colour only).
## The duration the bar is measured against is the burn skill's `burn_duration_sec` (skills.json, [constant BURN_SKILL_ID]).
## Implements: Story 046 Part C (burn on the floor).

## The skill whose `burn_duration_sec` is the full length of the time bar (moved from CutHudView).
const BURN_SKILL_ID: String = "hoa_tran"
## Colours (moved from CutHudView).
const BURN_TINT: Color = Color(1.0, 0.45, 0.0, 0.4)
const BURN_OUTLINE: Color = Color(1.0, 0.4, 0.0, 0.95)
const BURN_HATCH: Color = Color(0.25, 0.08, 0.0, 0.5)
const BURN_FLAME_OUTER: Color = Color(1.0, 0.78, 0.12, 0.95)
const BURN_FLAME_INNER: Color = Color(0.95, 0.25, 0.0, 0.95)
const BURN_BAR_BACK: Color = Color(0.25, 0.08, 0.0, 0.75)
const BURN_BAR_FILL: Color = Color(1.0, 0.6, 0.05)
## Hatch spacing as a share of the cell height (rounded to art px, at least 2 so lines never merge).
const BURN_HATCH_STEP_RATIO: float = 0.22
const HATCH_MIN_STEP_PX: int = 2
## Flame glyph size (shares of cell width / height); inner flame as a share of the outer.
const BURN_FLAME_WIDTH_RATIO: float = 0.3
const BURN_FLAME_HEIGHT_RATIO: float = 0.42
const BURN_FLAME_INNER_RATIO: float = 0.55
## Time bar: height and side / bottom inset (shares of cell height).
const BURN_BAR_HEIGHT_RATIO: float = 0.06
const BURN_BAR_INSET_RATIO: float = 0.08
## Outline width and inset in art px.
const OUTLINE_PX: int = 1
const OUTLINE_INSET_PX: int = 1


## Pure: one `{cell, ratio}` per burning cell of [param status], ratio = seconds left / [param duration_sec] clamped
## to 0..1 (0 when the duration is not positive). Empty when [param status] is null or nothing burns.
static func state_for(status: StatusEffects, duration_sec: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if status == null:
		return out
	for cell: Vector2i in status.burning_cells():
		var ratio: float = 0.0 if duration_sec <= 0.0 else clampf(status.get_burn_left(cell) / duration_sec, 0.0, 1.0)
		out.append({"cell": cell, "ratio": ratio})
	return out


## Paints [param cells] (from [method state_for]) on [param canvas] over the cells of [param floor]
## (FloorLayer.cell_art_rect), all in integer art px. No-op when empty or unbound. [param bar_only] (Story 048: the
## burning_cell VFX pack draws the fire) paints only the remaining-time bar.
static func paint(canvas: CanvasItem, floor: FloorLayer, cells: Array[Dictionary], bar_only: bool = false) -> void:
	if canvas == null or floor == null or cells.is_empty():
		return
	for entry: Dictionary in cells:
		var rect: Rect2i = floor.cell_art_rect(entry.get("cell", Vector2i.ZERO))
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		if bar_only:
			continue  # Story 048 (user 2026-10-31): the pack draws the fire and there is no time bar
			continue
		canvas.draw_rect(Rect2(rect), BURN_TINT)
		_hatch(canvas, rect, maxi(roundi(rect.size.y * BURN_HATCH_STEP_RATIO), HATCH_MIN_STEP_PX))
		_ring(canvas, rect.grow(-OUTLINE_INSET_PX), OUTLINE_PX, BURN_OUTLINE)
		_flame(canvas, rect)


# Diagonal hatch lines x + y = t (local px, the same direction as the old screen-px hatching), [param step] apart,
# each a 1 art-px staircase of 1x1 rects clipped to [param rect].
static func _hatch(canvas: CanvasItem, rect: Rect2i, step: int) -> void:
	var w: int = rect.size.x
	var h: int = rect.size.y
	var t: int = step
	while t < w + h - 1:
		for x: int in range(maxi(0, t - (h - 1)), mini(t, w - 1) + 1):
			canvas.draw_rect(Rect2(rect.position.x + x, rect.position.y + t - x, 1, 1), BURN_HATCH)
		t += step


# Flame glyph centred on [param rect]: an outer and an inner triangle on integer vertices, the inner one on the base.
static func _flame(canvas: CanvasItem, rect: Rect2i) -> void:
	var w: int = roundi(rect.size.x * BURN_FLAME_WIDTH_RATIO)
	var h: int = roundi(rect.size.y * BURN_FLAME_HEIGHT_RATIO)
	if w < 2 or h < 2:
		return
	var cx: int = rect.position.x + (rect.size.x >> 1)
	var cy: int = rect.position.y + (rect.size.y >> 1)
	var top: int = cy - (h >> 1)
	var base: int = top + h
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - (w >> 1), base), Vector2(cx, top), Vector2(cx - (w >> 1) + w, base),
	]), BURN_FLAME_OUTER)
	var iw: int = roundi(w * BURN_FLAME_INNER_RATIO)
	var ih: int = roundi(h * BURN_FLAME_INNER_RATIO)
	if iw < 2 or ih < 2:
		return
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - (iw >> 1), base), Vector2(cx, base - ih), Vector2(cx - (iw >> 1) + iw, base),
	]), BURN_FLAME_INNER)


# Remaining-time bar along the bottom of [param rect]: the back over the full width, the fill [param ratio] of it.
static func _bar(canvas: CanvasItem, rect: Rect2i, ratio: float) -> void:
	var inset: int = roundi(rect.size.y * BURN_BAR_INSET_RATIO)
	var bar_h: int = maxi(1, roundi(rect.size.y * BURN_BAR_HEIGHT_RATIO))
	var bar_w: int = rect.size.x - inset * 2
	if bar_w <= 0:
		return
	var y: int = rect.end.y - inset - bar_h
	canvas.draw_rect(Rect2(rect.position.x + inset, y, bar_w, bar_h), BURN_BAR_BACK)
	var fill_w: int = roundi(bar_w * ratio)
	if fill_w > 0:
		canvas.draw_rect(Rect2(rect.position.x + inset, y, fill_w, bar_h), BURN_BAR_FILL)


# A [param width]-px frame just inside [param rect], as four filled integer rects (no half-pixel line edges).
static func _ring(canvas: CanvasItem, rect: Rect2i, width: int, color: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var w: int = mini(width, mini(rect.size.x, rect.size.y))
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, w), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - w, rect.size.x, w), color)
	var inner: int = rect.size.y - w * 2
	if inner > 0:
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y + w, w, inner), color)
		canvas.draw_rect(Rect2(rect.end.x - w, rect.position.y + w, w, inner), color)

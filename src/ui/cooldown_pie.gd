class_name CooldownPie
extends RefCounted
## LoL-style cooldown pie (quick spec menu-la-giua-man-hinh-2026-11-01): a dark translucent sector over a square
## icon. The part already recovered is revealed CLOCKWISE from 12 o'clock, so right after the use the whole icon is
## covered and the shade shrinks clockwise until the card is ready. The seconds left (rounded up) sit in the
## middle. Pure geometry plus one draw helper; no state.

## The shade over the covered part, and the seconds text.
const SHADE: Color = Color(0.0, 0.0, 0.0, 0.7)
const TEXT_COLOR: Color = Color("F8F8D0")
## Arc points of a full turn (fewer for a smaller sector).
const ARC_POINTS: int = 48
## Seconds font size as a share of the icon edge (at least MIN_FONT_SIZE).
const FONT_RATIO: float = 0.42
const MIN_FONT_SIZE: int = 12
## 12 o'clock in Godot's screen angles (y grows downwards, so a growing angle turns clockwise).
const TOP_ANGLE: float = -PI * 0.5


## Pure: share of a cooldown already recovered: 0 at the use ([param left] == [param total]), 1 when ready.
## A cooldown without a length counts as ready.
static func recovered_fraction(left: float, total: float) -> float:
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - left / total, 0.0, 1.0)


## Pure: the screen angles (start, end) of the SHADED sector for [param fraction] recovered. The revealed part
## runs clockwise from 12 o'clock to the start angle; the shade runs on from there back round to 12 o'clock.
static func shade_angles(fraction: float) -> Vector2:
	var f: float = clampf(fraction, 0.0, 1.0)
	return Vector2(TOP_ANGLE + f * TAU, TOP_ANGLE + TAU)


## Pure: the seconds shown on the pie ([param left] rounded up; "" when ready).
static func seconds_text(left: float) -> String:
	return "" if left <= 0.0 else str(ceili(left))


## Pure: the shaded polygons over [param rect] for [param fraction] recovered (the sector clipped to the square);
## empty when fully recovered.
static func shade_polygons(rect: Rect2, fraction: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var f: float = clampf(fraction, 0.0, 1.0)
	if f >= 1.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return out
	var square := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	if f <= 0.0:
		out.append(square)
		return out
	var c: Vector2 = rect.get_center()
	var radius: float = rect.size.length()
	var angles: Vector2 = shade_angles(f)
	var steps: int = maxi(int(ceil(ARC_POINTS * (1.0 - f))), 2)
	var sector := PackedVector2Array([c])
	for i: int in steps + 1:
		var a: float = lerpf(angles.x, angles.y, float(i) / float(steps))
		sector.append(c + Vector2(cos(a), sin(a)) * radius)
	for poly: PackedVector2Array in Geometry2D.intersect_polygons(sector, square):
		out.append(poly)
	return out


## Pure: true when [param point] lies in the shade of [param rect] at [param fraction] recovered.
static func is_shaded(rect: Rect2, fraction: float, point: Vector2) -> bool:
	for poly: PackedVector2Array in shade_polygons(rect, fraction):
		if Geometry2D.is_point_in_polygon(point, poly):
			return true
	return false


## Draws the shade over [param rect] for [param fraction] recovered and, when [param left] > 0, the seconds left
## (rounded up) in its middle.
static func draw(canvas: CanvasItem, rect: Rect2, fraction: float, left: float) -> void:
	for poly: PackedVector2Array in shade_polygons(rect, fraction):
		canvas.draw_colored_polygon(poly, SHADE)
	var text: String = seconds_text(left)
	if text.is_empty():
		return
	var size: int = maxi(int(minf(rect.size.x, rect.size.y) * FONT_RATIO), MIN_FONT_SIZE)
	HudSkin.text(canvas, Vector2(rect.position.x, rect.get_center().y + size * 0.36), text, size, TEXT_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)

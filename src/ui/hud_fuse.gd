class_name HudFuse
extends RefCounted
## Controls v3 (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md): a gold fuse that burns CLOCKWISE round an
## angular (chamfered) frame, starting at 12 o'clock (the top-centre of the frame). It replaces the separate time bars:
## the 3 s place window and Focus round the Tung phép button, the 3 s card pick round the frame of the four cards.
## The part still to burn is the gold line from the head (a small bright diamond) clockwise back to 12 o'clock; the
## part already burnt is a dark groove. Pure geometry plus one draw helper; no state.

## Gold of the unburnt fuse, its bright head, the burnt groove and the ink rim under both.
const GOLD: Color = Color("F8C838")
const HEAD: Color = Color("FFF6C8")
const GROOVE: Color = Color("15131B", 0.75)
const RIM: Color = Color("15131B")
## Line width of the fuse and the head's half-diagonal, in 720p px (scaled by the caller's [param s]).
const WIDTH_PX: float = 3.0
const HEAD_PX: float = 6.0


## Pure: share of the fuse already burnt for [param left] seconds left of [param total]: 0 at the start, 1 when the time
## is up. A fuse without a length counts as burnt out.
static func burnt_fraction(left: float, total: float) -> float:
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - left / total, 0.0, 1.0)


## Pure: the closed path of the chamfered [param rect] (corner cut [param cut] px), starting and ending at the top
## centre and running CLOCKWISE on screen (right along the top edge first, y grows downwards).
static func path(rect: Rect2, cut: float) -> PackedVector2Array:
	var c: float = clampf(cut, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var l: float = rect.position.x
	var t: float = rect.position.y
	var r: float = rect.end.x
	var b: float = rect.end.y
	var top_mid := Vector2(rect.get_center().x, t)
	return PackedVector2Array([
		top_mid, Vector2(r - c, t), Vector2(r, t + c), Vector2(r, b - c), Vector2(r - c, b),
		Vector2(l + c, b), Vector2(l, b - c), Vector2(l, t + c), Vector2(l + c, t), top_mid,
	])


## Pure: total length of [param points] (an open polyline).
static func length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## Pure: the point [param fraction] (0..1) of the way along [param points].
static func point_at(points: PackedVector2Array, fraction: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var goal: float = length(points) * clampf(fraction, 0.0, 1.0)
	for i: int in range(1, points.size()):
		var seg: float = points[i - 1].distance_to(points[i])
		if goal <= seg and seg > 0.0:
			return points[i - 1].lerp(points[i], goal / seg)
		goal -= seg
	return points[points.size() - 1]


## Pure: the part of [param points] from [param fraction] of the way to the end (the fuse still to burn when
## [param fraction] is burnt). Fewer than two points when nothing is left.
static func remaining(points: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 2:
		return out
	var f: float = clampf(fraction, 0.0, 1.0)
	if f >= 1.0:
		return out
	var goal: float = length(points) * f
	out.append(point_at(points, f))
	var walked: float = 0.0
	for i: int in range(1, points.size()):
		walked += points[i - 1].distance_to(points[i])
		if walked > goal:
			out.append(points[i])
	return out


## Draws the fuse round [param rect] (chamfer [param cut]) with [param fraction] burnt, at [param s] px per 720p px:
## the groove along the whole path, the gold still to burn and the head diamond at the burn point.
## 2026-11-07 (user: the bare black frame of the card menu did not fit the game): the frame of a menu with no time
## limit: the same path as a whole gold line on its dark rim (no burning, no spark head).
static func draw_static(canvas: CanvasItem, rect: Rect2, cut: float, s: float, alpha: float = 1.0) -> void:
	var pts: PackedVector2Array = path(rect, cut)
	var w: float = maxf(roundf(WIDTH_PX * s), 1.0)
	canvas.draw_polyline(pts, Color(RIM, alpha), w + 2.0)
	canvas.draw_polyline(pts, Color(GOLD, alpha), w)


static func draw(canvas: CanvasItem, rect: Rect2, cut: float, fraction: float, s: float, alpha: float = 1.0) -> void:
	var pts: PackedVector2Array = path(rect, cut)
	var w: float = maxf(roundf(WIDTH_PX * s), 1.0)
	canvas.draw_polyline(pts, Color(RIM, alpha), w + 2.0)
	canvas.draw_polyline(pts, Color(GROOVE, GROOVE.a * alpha), w)
	var left: PackedVector2Array = remaining(pts, fraction)
	if left.size() < 2:
		return
	canvas.draw_polyline(left, Color(GOLD, alpha), w)
	var head: Vector2 = left[0].round()
	HudSkin.diamond(canvas, head, maxf(roundf(HEAD_PX * s), 3.0), Color(HEAD, alpha), Color(RIM, alpha), 1.0)

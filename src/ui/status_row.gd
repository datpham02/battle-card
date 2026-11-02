class_name StatusRow
extends RefCounted
## Controls v3 (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md): the player's buff / debuff row in the top-left
## corner, under the relics. One angular frame per active status (StatusEffects.active_statuses, in its order): the
## status icon from the HUD icon sheet (or, where the sheet has none yet, a simple angular code glyph in the status
## colour), the time already gone shaded CLOCKWISE from 12 o'clock over the icon (the lit part is the time left) and a
## stack count in the corner. A tap on a frame opens a small tooltip under the row with the status name and effect.
## Pure drawing / geometry plus the per-status table; no state (CutHudView owns the tooltip and the input).

## Per status id: [icon in ui_icons_55 ("" = none yet, code glyph), colour, name key, effect key].
const INFO: Dictionary = {
	"frozen": ["frozen", Color("7FD4FF"), "ui.hud.pinned", "ui.status.frozen.desc"],
	"root": ["", Color("B08A4A"), "ui.status.root.name", "ui.status.root.desc"],
	"slow": ["", Color("8FA3B8"), "ui.status.slow.name", "ui.status.slow.desc"],
	"burn": ["burn", Color("FF7A1F"), "keyword.burn", "ui.status.burn.desc"],
	"fragile": ["fragile", Color(0.62, 0.32, 0.88), "keyword.fragile", "ui.status.fragile.desc"],
	"chill": ["chill", Color(0.3, 0.68, 0.95), "keyword.frost", "ui.status.chill.desc"],
	"guard": ["armor", Color("F8E080"), "ui.status.guard.name", "ui.status.guard.desc"],
}
const UNKNOWN_COLOR: Color = Color("EFE6D2")
## Frame fill, the shade over the time already gone, the stack number colour.
const FRAME_FILL: Color = Color("1E1B24", 0.92)
const SHADE: Color = Color(0.0, 0.0, 0.0, 0.66)
## Alpha of the status-coloured glow behind the time left, and the clock hand's width (720p px).
const LEFT_GLOW_ALPHA: float = 0.45
const HAND_PX: float = 2.0
const STACK_COLOR: Color = Color("F8F8D0")
## Frame chamfer and line width, the icon's share of the frame edge, the stack font, all for a 40 px frame at 720p.
const CUT_RATIO: float = 0.22
const LINE_PX: float = 2.0
const ICON_SHARE: float = 0.8
const STACK_FONT_RATIO: float = 0.36
const ARC_POINTS: int = 40
const TOP_ANGLE: float = -PI * 0.5
## Tooltip: width, padding and fonts (720p px), and how long it stays open (seconds).
const TIP_WIDTH_PX: float = 300.0
const TIP_PAD_PX: float = 10.0
const TIP_NAME_FONT: int = 18
const TIP_DESC_FONT: int = 15
const TIP_GAP_PX: float = 6.0
const TIP_SEC: float = 3.0
const TIP_DESC_LINES: int = 3


## Icon sheet name of [param id] ("" when the sheet has none: a code glyph is drawn instead).
static func icon_name(id: String) -> String:
	return str((INFO.get(id, ["", UNKNOWN_COLOR, "", ""]) as Array)[0])


## Colour of [param id] (its frame line and its code glyph).
static func color_of(id: String) -> Color:
	return (INFO.get(id, ["", UNKNOWN_COLOR, "", ""]) as Array)[1] as Color


## Translation keys [name, effect] of [param id].
static func text_keys(id: String) -> Array[String]:
	var row: Array = INFO.get(id, ["", UNKNOWN_COLOR, id, ""]) as Array
	return [str(row[2]), str(row[3])]


## The status ids that have no icon in the sheet yet (drawn as code glyphs): the art to request.
static func missing_icons() -> Array[String]:
	var out: Array[String] = []
	for id: String in INFO:
		if icon_name(id).is_empty() or HudSkin.icon_frame(icon_name(id)) == Rect2():
			out.append(id)
	return out


## Pure: the chamfered outline of a frame [param rect] (all four corners cut), clockwise from the top-left cut.
static func frame_points(rect: Rect2) -> PackedVector2Array:
	var c: float = roundf(minf(rect.size.x, rect.size.y) * CUT_RATIO)
	var l: float = rect.position.x
	var t: float = rect.position.y
	var r: float = rect.end.x
	var b: float = rect.end.y
	return PackedVector2Array([Vector2(l + c, t), Vector2(r - c, t), Vector2(r, t + c), Vector2(r, b - c),
		Vector2(r - c, b), Vector2(l + c, b), Vector2(l, b - c), Vector2(l, t + c)])


## Pure: the shaded polygons over the frame [param rect] when [param gone] (0..1) of the status time has passed: a
## sector from 12 o'clock CLOCKWISE through gone * 360 degrees, clipped to the frame. Empty at 0, the whole frame at 1.
static func shade_polygons(rect: Rect2, gone: float) -> Array[PackedVector2Array]:
	return sector_polygons(rect, 0.0, gone)


## Pure: the part of the frame [param rect] between [param from] and [param to] (shares of a full turn, 0 = 12
## o'clock, growing CLOCKWISE), clipped to the frame. Empty when to <= from; the whole frame for 0..1.
static func sector_polygons(rect: Rect2, from: float, to: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var a0: float = clampf(from, 0.0, 1.0)
	var a1: float = clampf(to, 0.0, 1.0)
	var frame: PackedVector2Array = frame_points(rect)
	if a1 - a0 <= 0.0 or not rect.has_area():
		return out
	if a1 - a0 >= 1.0:
		out.append(frame)
		return out
	var c: Vector2 = rect.get_center()
	var radius: float = rect.size.length()
	var steps: int = maxi(int(ceil(ARC_POINTS * (a1 - a0))), 2)
	var sector := PackedVector2Array([c])
	for i: int in steps + 1:
		var a: float = TOP_ANGLE + TAU * lerpf(a0, a1, float(i) / float(steps))
		sector.append(c + Vector2(cos(a), sin(a)) * radius)
	for poly: PackedVector2Array in Geometry2D.intersect_polygons(sector, frame):
		out.append(poly)
	return out


## Pure: where the clock hand of a frame [param rect] at [param gone] meets the frame (the boundary between the time
## gone and the time left), from the frame centre at 12 o'clock + gone * 360 degrees clockwise.
static func hand_end(rect: Rect2, gone: float) -> Vector2:
	var a: float = TOP_ANGLE + TAU * clampf(gone, 0.0, 1.0)
	var c: Vector2 = rect.get_center()
	var far: Vector2 = c + Vector2(cos(a), sin(a)) * rect.size.length()
	var pts: PackedVector2Array = frame_points(rect)
	for i: int in pts.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(c, far, pts[i], pts[(i + 1) % pts.size()])
		if hit != null:
			return hit as Vector2
	return far


## Pure: true when [param point] lies in the shade of [param rect] at [param gone].
static func is_shaded(rect: Rect2, gone: float, point: Vector2) -> bool:
	for poly: PackedVector2Array in shade_polygons(rect, gone):
		if Geometry2D.is_point_in_polygon(point, poly):
			return true
	return false


## Draws one status frame [param entry] (StatusEffects.active_statuses) in [param rect] at [param s] px per 720p px.
static func draw_entry(canvas: CanvasItem, rect: Rect2, entry: Dictionary, s: float) -> void:
	var id: String = str(entry.get("id", ""))
	var color: Color = color_of(id)
	var frame: PackedVector2Array = frame_points(rect)
	canvas.draw_colored_polygon(frame, FRAME_FILL)
	var timed: bool = float(entry.get("total", 0.0)) > 0.0
	var gone: float = 1.0 - StatusEffects.status_left_fraction(entry)
	# The time left glows in the status colour behind the icon; the time gone is shaded over it.
	for poly: PackedVector2Array in sector_polygons(rect, gone, 1.0):
		canvas.draw_colored_polygon(poly, Color(color, LEFT_GLOW_ALPHA))
	var inner: Rect2 = rect.grow(-roundf(rect.size.x * (1.0 - ICON_SHARE) * 0.5))
	var icon: String = icon_name(id)
	var drawn: bool = false
	if not icon.is_empty():
		var src: Rect2 = HudSkin.icon_frame(icon)
		if src.size.x > 0.0:
			drawn = HudSkin.icon(canvas, icon, rect.get_center(), inner.size.x / src.size.x)
	if not drawn:
		draw_glyph(canvas, id, inner, color)
	for poly: PackedVector2Array in shade_polygons(rect, gone):
		canvas.draw_colored_polygon(poly, SHADE)
	if timed and gone > 0.0 and gone < 1.0:
		var w_hand: float = maxf(roundf(HAND_PX * s), 1.0)
		var c: Vector2 = rect.get_center()
		canvas.draw_line(c, hand_end(rect, gone), HudSkin.TEXT_OUTLINE, w_hand + 2.0)
		canvas.draw_line(c, hand_end(rect, gone), color.lightened(0.4), w_hand)
	var closed := PackedVector2Array(frame)
	closed.append(frame[0])
	var w: float = maxf(roundf(LINE_PX * s), 1.0)
	canvas.draw_polyline(closed, HudSkin.TEXT_OUTLINE, w + 2.0)
	canvas.draw_polyline(closed, color, w)
	var stacks: int = int(entry.get("stacks", 0))
	if stacks > 1:
		var size: int = maxi(roundi(rect.size.y * STACK_FONT_RATIO), 10)
		HudSkin.text(canvas, Vector2(rect.position.x, rect.end.y - roundf(2.0 * s)), str(stacks), size, STACK_COLOR,
			HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - roundf(3.0 * s), true)


## Code glyph of a status without sheet art, angular, in [param color] with an ink rim, filling [param rect]:
## root = a shackle (a bar with two chained links), slow = an hourglass; anything else = a diamond.
static func draw_glyph(canvas: CanvasItem, id: String, rect: Rect2, color: Color) -> void:
	var r: Rect2 = Rect2(rect.position.round(), rect.size.round())
	var u: float = maxf(roundf(r.size.x / 8.0), 1.0)
	var ink: Color = HudSkin.TEXT_OUTLINE
	match id:
		"root":
			# Two angular links hanging from a bar, a root tip under each.
			var bar := Rect2(r.position.x + u, r.position.y + u, r.size.x - u * 2.0, u * 1.5)
			canvas.draw_rect(bar.grow(1.0), ink)
			canvas.draw_rect(bar, color)
			for k: int in 2:
				var x: float = r.position.x + u * (2.0 + 3.0 * k)
				var link := Rect2(x, bar.end.y + u * 0.5, u * 1.5, u * 3.0)
				canvas.draw_rect(link.grow(1.0), ink)
				canvas.draw_rect(link, color)
				var tip := PackedVector2Array([Vector2(x, link.end.y), Vector2(x + u * 1.5, link.end.y), Vector2(x + u * 0.75, link.end.y + u * 1.5)])
				canvas.draw_colored_polygon(tip, color)
		"slow":
			# Hourglass: two triangles point to point between a top and a bottom bar.
			var top := Rect2(r.position.x + u, r.position.y + u * 0.5, r.size.x - u * 2.0, u)
			var bottom := Rect2(r.position.x + u, r.end.y - u * 1.5, r.size.x - u * 2.0, u)
			var mid := Vector2(r.get_center().x, r.get_center().y)
			var upper := PackedVector2Array([Vector2(top.position.x + u * 0.5, top.end.y), Vector2(top.end.x - u * 0.5, top.end.y), mid])
			var lower := PackedVector2Array([Vector2(bottom.position.x + u * 0.5, bottom.position.y), mid, Vector2(bottom.end.x - u * 0.5, bottom.position.y)])
			for poly: PackedVector2Array in [upper, lower]:
				var rim := PackedVector2Array(poly)
				rim.append(poly[0])
				canvas.draw_polyline(rim, ink, 3.0)
				canvas.draw_colored_polygon(poly, color)
			for b: Rect2 in [top, bottom]:
				canvas.draw_rect(b.grow(1.0), ink)
				canvas.draw_rect(b, color)
		_:
			HudSkin.diamond(canvas, r.get_center(), r.size.x * 0.4, color, ink, 2.0)


## Rect of the tooltip for the frame [param icon] (under the row, left-aligned with the frame, inside the screen):
## TIP_WIDTH_PX wide, the height of a name line and TIP_DESC_LINES effect lines.
static func tooltip_rect(viewport_size: Vector2, icon: Rect2, s: float) -> Rect2:
	var w: float = roundf(TIP_WIDTH_PX * s)
	var pad: float = roundf(TIP_PAD_PX * s)
	var h: float = pad * 2.0 + roundf(TIP_NAME_FONT * s * 1.3) + roundf(TIP_DESC_FONT * s * 1.25) * TIP_DESC_LINES
	var x: float = clampf(icon.position.x, 0.0, maxf(viewport_size.x - w, 0.0))
	return Rect2(x, icon.end.y + roundf(TIP_GAP_PX * s), w, h)


## Draws the tooltip [param rect]: an angular dark panel framed in the status colour, the name (in that colour) and
## the effect (wrapped, at most TIP_DESC_LINES lines).
static func draw_tooltip(canvas: CanvasItem, rect: Rect2, id: String, name_text: String, desc_text: String, s: float) -> void:
	var color: Color = color_of(id)
	var cut: float = roundf(8.0 * s)
	HudSkin.panel(canvas, rect, [0.0, cut, 0.0, cut], Color(HudSkin.NIGHT_STONE, 0.96), color, maxf(roundf(2.0 * s), 1.0))
	var pad: float = roundf(TIP_PAD_PX * s)
	var name_size: int = roundi(TIP_NAME_FONT * s)
	var desc_size: int = roundi(TIP_DESC_FONT * s)
	var y: float = rect.position.y + pad + name_size
	HudSkin.text(canvas, Vector2(rect.position.x + pad, y), name_text, name_size, color.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0, true)
	var font: Font = HudSkin.font(false)
	var desc_pos := Vector2(rect.position.x + pad, y + roundf(desc_size * 1.3))
	canvas.draw_multiline_string_outline(font, desc_pos, desc_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0, desc_size,
		TIP_DESC_LINES, HudSkin.TEXT_OUTLINE_PX, HudSkin.TEXT_OUTLINE)
	canvas.draw_multiline_string(font, desc_pos, desc_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - pad * 2.0, desc_size,
		TIP_DESC_LINES, HudSkin.TEXT)

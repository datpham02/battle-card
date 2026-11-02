class_name HudSkin
extends RefCounted

## Story 046 Part B: the sharp HUD skin (art bible §7.4 / §7.5 / §8.8). A static library: colours named
## after the art bible, the two Noto Sans fonts, and the shapes every HUD view draws at screen resolution
## (chamfered panels, diamonds, segmented bars, outlined text, HP bars, 55 px icons). It holds no node
## state: callers pass the CanvasItem they are drawing in (inside its _draw). The only static state is a
## load-once cache of the fonts and the icon sheet.

## Đá Đêm: panel and tile fill (art bible §7.4).
const NIGHT_STONE: Color = Color("1E1B24")
## A step lighter than Đá Đêm: the unlit segments of a segmented bar.
const NIGHT_STONE_LIGHT: Color = Color("2B2735")
## Sương: the 1 px frame line of panels.
const MIST: Color = Color("7D8896")
## Ngà: boss HP bar, half-HP notch, selected frame.
const IVORY: Color = Color("EFE6D2")
## Ánh Lưới: Engraving / Awaken gold.
const GRID_LIGHT: Color = Color("FFD45C")
## HUD text colour.
const TEXT: Color = Color("F4F6FA")
## Outline drawn behind every HUD text.
const TEXT_OUTLINE: Color = Color("0F1219")
## Secondary text (art bible §4: chữ phụ).
const TEXT_DIM: Color = Color("B8B0A0")
## Player HP fill (never red).
const HP_FILL: Color = Color("58D468")
## Damage trail behind the HP fill (art bible §7.5: not red).
const HP_TRAIL: Color = Color("B8B0A0")
## HP / segment groove.
const HP_GROOVE: Color = Color("15131A")
## The boss HP bar colour (art bible §7.5: boss = Ngà).
const BOSS_HP_FILL: Color = IVORY
## The enemy HP red CombatView used before Story 046 (the boss bar is Ivory now; kept for the boss step ring).
const ENEMY_RED: Color = Color(0.85, 0.2, 0.2)
## 2026-10-31 (user: "chưa apply hud cho toàn bộ màn"): the whole-game skin. Screen background (every menu screen),
## card face, and the button styles (UiButtons.Style order: PRIMARY, SECONDARY, DANGER, NEUTRAL) as fill + line.
const SCREEN_BG: Color = Color("17151D")
const SCREEN_BAND: Color = Color("1E1B24")
const CARD_FILL: Color = Color("242030")
const CARD_LINE: Color = MIST
const BUTTON_FILLS: Array[Color] = [Color("2F4A36"), Color("2B2735"), Color("4A2A24"), Color("231F2B")]
const BUTTON_LINES: Array[Color] = [Color("FFD45C"), Color("7D8896"), Color("C7714A"), Color("7D8896")]
const BUTTON_PRESSED_LIGHTEN: float = 0.15
const BUTTON_PRESSED_LINE: Color = IVORY
const BUTTON_DIM_ALPHA: float = 0.4
## Chamfer of a button / card corner: this share of the shorter side, capped at BUTTON_CUT_MAX px.
const BUTTON_CUT_RATIO: float = 0.18
const BUTTON_CUT_MAX: float = 12.0

## Outline width of HUD text, px.
const TEXT_OUTLINE_PX: int = 3
## Default frame width of panels, px.
const PANEL_LINE_WIDTH: float = 1.5
## Default gap between bar segments, px.
const SEGMENT_GAP: float = 2.0
## Half-HP notch: width and how far it protrudes above and below the bar, px.
const NOTCH_WIDTH: float = 2.0
const NOTCH_PROTRUDE: float = 3.0
## Lightening of the 1 px top line of an HP fill (a bevel without a gradient).
const FILL_BEVEL_LIGHTEN: float = 0.35

const FONT_SEMIBOLD_PATH: String = "res://assets/fonts/NotoSans-SemiBold.ttf"
const FONT_BOLD_PATH: String = "res://assets/fonts/NotoSans-Bold.ttf"
const ICONS_PNG_PATH: String = "res://assets/art/ui/ui_icons_55.png"
const ICONS_JSON_PATH: String = "res://assets/art/ui/ui_icons_55.json"

static var _font_semibold: Font = null
static var _font_bold: Font = null
static var _font_warned: bool = false
static var _icons_loaded: bool = false
static var _icon_texture: CanvasTexture = null
static var _icon_frames: Dictionary = {}
static var _icons_png: String = ICONS_PNG_PATH
static var _icons_json: String = ICONS_JSON_PATH


# --- Fonts --------------------------------------------------------------------


## Noto Sans SemiBold (names, labels). Loaded once; ThemeDB.fallback_font when the file is missing.
static func font_semibold() -> Font:
	if _font_semibold == null:
		_font_semibold = _load_font(FONT_SEMIBOLD_PATH)
	return _font_semibold


## Noto Sans Bold (numbers, banners). Loaded once; ThemeDB.fallback_font when the file is missing.
static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = _load_font(FONT_BOLD_PATH)
	return _font_bold


## [method font_bold] when [param bold], else [method font_semibold].
static func font(bold: bool = false) -> Font:
	return font_bold() if bold else font_semibold()


# Dynamic TTF with grey antialiasing, hinting on, no MSDF (art bible §8.8); one warning for any missing file.
static func _load_font(path: String) -> Font:
	var file: FontFile = null
	if ResourceLoader.exists(path):
		file = load(path) as FontFile
	if file == null:
		if not _font_warned:
			push_warning("HudSkin: font %s missing, using ThemeDB.fallback_font" % path)
			_font_warned = true
		return ThemeDB.fallback_font
	file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	file.hinting = TextServer.HINTING_LIGHT
	file.multichannel_signed_distance_field = false
	return file


# --- Shapes (pure) ------------------------------------------------------------


## Outline of [param rect] with 45-degree chamfers, clockwise from the top-left. [param cuts] = px cut at
## [top-left, top-right, bottom-right, bottom-left] (missing entries = 0, 0 = square corner, each clamped
## to half the shorter side). 4 vertices plus one per non-zero cut.
static func chamfer_points(rect: Rect2, cuts: Array) -> PackedVector2Array:
	var limit: float = minf(rect.size.x, rect.size.y) * 0.5
	var c: Array[float] = []
	for i: int in 4:
		var raw: Variant = cuts[i] if i < cuts.size() else 0.0
		var value: float = float(raw) if (typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT) else 0.0
		c.append(clampf(value, 0.0, limit))
	var x0: float = rect.position.x
	var y0: float = rect.position.y
	var x1: float = rect.end.x
	var y1: float = rect.end.y
	var p := PackedVector2Array()
	# top-left
	if c[0] > 0.0:
		p.append(Vector2(x0, y0 + c[0]))
	p.append(Vector2(x0 + c[0], y0))
	# top-right
	p.append(Vector2(x1 - c[1], y0))
	if c[1] > 0.0:
		p.append(Vector2(x1, y0 + c[1]))
	# bottom-right
	p.append(Vector2(x1, y1 - c[2]))
	if c[2] > 0.0:
		p.append(Vector2(x1 - c[2], y1))
	# bottom-left
	p.append(Vector2(x0 + c[3], y1))
	if c[3] > 0.0:
		p.append(Vector2(x0, y1 - c[3]))
	return p


## Corners of a regular [param sides]-gon of circumradius [param r] round [param center], clockwise, the first at
## [param start_angle] (default straight up). The angular stand-in for a circle (2026-11-02 rule: no circles in the
## UI but the movement joystick). Empty for sides < 3 or r <= 0.
static func regular_points(center: Vector2, r: float, sides: int, start_angle: float = -PI * 0.5) -> PackedVector2Array:
	var p := PackedVector2Array()
	if sides < 3 or r <= 0.0:
		return p
	for i: int in sides:
		var a: float = start_angle + TAU * float(i) / float(sides)
		p.append(center + Vector2(cos(a), sin(a)) * r)
	return p


## The first [param ratio] (0..1) of the closed outline through [param corners], clockwise from corners[0], as an
## open polyline: the angular radial timer. Empty when ratio <= 0 or fewer than 2 corners; the whole closed outline
## at ratio >= 1.
static func perimeter_trace(corners: PackedVector2Array, ratio: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = corners.size()
	if n < 2 or ratio <= 0.0:
		return out
	var span: float = clampf(ratio, 0.0, 1.0) * float(n)
	out.append(corners[0])
	for i: int in n:
		if span <= float(i):
			break
		var next: Vector2 = corners[(i + 1) % n]
		if span >= float(i + 1):
			out.append(next)
		else:
			out.append(corners[i].lerp(next, span - float(i)))
			break
	return out


## Faceted flame glyph (tip up) of half-height [param h] round [param c], as a closed polyline: the tip, two
## shoulders and a flat two-corner base (replaces the round-bottomed teardrop).
static func flame_points(c: Vector2, h: float) -> PackedVector2Array:
	var p := PackedVector2Array([c + Vector2(0.0, -h), c + Vector2(h * 0.7, h * 0.4), c + Vector2(h * 0.35, h),
		c + Vector2(-h * 0.35, h), c + Vector2(-h * 0.7, h * 0.4)])
	p.append(p[0])
	return p


## Padlock shackle over a lock body whose top edge is at [param top_y], centred on [param cx], half-width
## [param r]: an open polyline with chamfered top corners (the angular version of the half-ring).
static func shackle_points(cx: float, top_y: float, r: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx - r, top_y), Vector2(cx - r, top_y - r * 0.6), Vector2(cx - r * 0.6, top_y - r),
		Vector2(cx + r * 0.6, top_y - r), Vector2(cx + r, top_y - r * 0.6), Vector2(cx + r, top_y)])


## The [param total] segment rects of a segmented bar across [param rect], [param gap] px apart; edges
## rounded to whole px (widths differ by at most 1 px), the last one ends on rect's right edge. Empty
## for total <= 0.
static func segment_rects(rect: Rect2, total: int, gap: float = SEGMENT_GAP) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if total <= 0:
		return out
	var w: float = maxf((rect.size.x - gap * (total - 1)) / total, 0.0)
	for i: int in total:
		var left: float = roundf(i * (w + gap))
		var right: float = rect.size.x if i == total - 1 else roundf(i * (w + gap) + w)
		out.append(Rect2(rect.position + Vector2(left, 0.0), Vector2(maxf(right - left, 0.0), rect.size.y)))
	return out


## Damage-trail ratio [param elapsed] seconds into a shrink from [param from_ratio] to [param to_ratio]
## lasting [param sec] (linear; [param to_ratio] once over or when sec <= 0).
static func trail_ratio(from_ratio: float, to_ratio: float, elapsed: float, sec: float) -> float:
	if sec <= 0.0 or elapsed >= sec:
		return to_ratio
	return lerpf(from_ratio, to_ratio, clampf(elapsed / sec, 0.0, 1.0))


# --- Drawing ------------------------------------------------------------------


## Chamfered panel: [param fill] polygon and a closed [param line] frame [param width] px wide (no frame
## when width <= 0 or the line is transparent).
static func panel(canvas: CanvasItem, rect: Rect2, cuts: Array, fill: Color, line: Color, width: float = PANEL_LINE_WIDTH) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var poly: PackedVector2Array = chamfer_points(rect, cuts)
	canvas.draw_colored_polygon(poly, fill)
	_outline(canvas, poly, line, width)


## Diamond (square rotated 45°) of half-diagonal [param r] around [param center].
static func diamond(canvas: CanvasItem, center: Vector2, r: float, fill: Color, line: Color, width: float = 2.0) -> void:
	if r <= 0.0:
		return
	var poly := PackedVector2Array([center + Vector2(0.0, -r), center + Vector2(r, 0.0), center + Vector2(0.0, r), center + Vector2(-r, 0.0)])
	canvas.draw_colored_polygon(poly, fill)
	_outline(canvas, poly, line, width)


## Segmented bar: an outlined groove with [param total] segments, the first [param filled] in [param lit].
static func segments(canvas: CanvasItem, rect: Rect2, total: int, filled: int, lit: Color, gap: float = SEGMENT_GAP) -> void:
	canvas.draw_rect(rect.grow(1.0), TEXT_OUTLINE)
	canvas.draw_rect(rect, HP_GROOVE)
	var i: int = 0
	for seg: Rect2 in segment_rects(rect, total, gap):
		canvas.draw_rect(seg, lit if i < filled else NIGHT_STONE_LIGHT)
		i += 1


## Outlined HUD text at baseline [param pos]: a TEXT_OUTLINE_PX outline in TEXT_OUTLINE (alpha follows
## [param color]), then the text; SemiBold, or Bold when [param bold].
static func text(canvas: CanvasItem, pos: Vector2, content: String, size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, bold: bool = false) -> void:
	if content.is_empty():
		return
	var f: Font = font(bold)
	canvas.draw_string_outline(f, pos, content, align, width, size, TEXT_OUTLINE_PX, Color(TEXT_OUTLINE, color.a))
	canvas.draw_string(f, pos, content, align, width, size, color)


## Width in px of [param content] at [param size] in the SemiBold (or Bold) font, without the outline.
static func text_width(content: String, size: int, bold: bool = false) -> float:
	return font(bold).get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


## 2026-10-31: the menu-screen background: a flat SCREEN_BG field with a SCREEN_BAND strip over the top
## [param band_ratio] of the height (where the screen titles sit).
static func screen_background(canvas: CanvasItem, rect: Rect2, band_ratio: float = 0.16) -> void:
	canvas.draw_rect(rect, SCREEN_BG)
	if band_ratio > 0.0:
		canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, floorf(rect.size.y * band_ratio))), SCREEN_BAND)


## 2026-10-31: the chamfer (px) of a button or card of [param rect].
static func button_cut(rect: Rect2) -> float:
	return floorf(minf(minf(rect.size.x, rect.size.y) * BUTTON_CUT_RATIO, BUTTON_CUT_MAX))


## 2026-10-31: one button in the game skin: a panel cut top-right and bottom-left in the fill / line of [param style]
## (0 PRIMARY, 1 SECONDARY, 2 DANGER, 3 NEUTRAL; out of range = PRIMARY), lighter with an Ivory line when
## [param pressed], dimmed when not [param enabled], and [param label] centred in outlined bold text (skipped when
## empty). [param line_width] <= 0 uses PANEL_LINE_WIDTH (primary buttons draw it one px thicker).
static func button(canvas: CanvasItem, rect: Rect2, label: String, style: int, pressed: bool, enabled: bool = true, font_size: int = 32, line_width: float = 0.0) -> void:
	var i: int = style if style >= 0 and style < BUTTON_FILLS.size() else 0
	var fill: Color = BUTTON_FILLS[i]
	var line: Color = BUTTON_LINES[i]
	var width: float = line_width if line_width > 0.0 else PANEL_LINE_WIDTH + (1.0 if i == 0 else 0.0)
	if enabled and pressed:
		fill = fill.lightened(BUTTON_PRESSED_LIGHTEN)
		line = BUTTON_PRESSED_LINE
	var text_color: Color = TEXT
	if not enabled:
		fill.a *= BUTTON_DIM_ALPHA
		line.a *= BUTTON_DIM_ALPHA
		text_color.a *= BUTTON_DIM_ALPHA
	var cut: float = button_cut(rect)
	panel(canvas, rect, [0.0, cut, 0.0, cut], fill, line, width)
	if not label.is_empty():
		var size: int = font_size
		while size > 10 and text_width(label, size, true) > rect.size.x - cut * 2.0:
			size -= 1
		text(canvas, Vector2(rect.position.x, floorf(rect.get_center().y + size * 0.36)), label, size, text_color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)


## 2026-10-31: a card face in the game skin (reward / shop / deck cards, map nodes): CARD_FILL panel cut top-right
## with a [param line] edge (GRID_LIGHT and 3 px when [param selected]); [param dim] fades it (locked / taken).
static func card(canvas: CanvasItem, rect: Rect2, line: Color = CARD_LINE, selected: bool = false, dim: bool = false) -> void:
	var fill: Color = CARD_FILL
	var edge: Color = GRID_LIGHT if selected else line
	if dim:
		fill.a *= BUTTON_DIM_ALPHA
		edge.a *= BUTTON_DIM_ALPHA
	panel(canvas, rect, [0.0, button_cut(rect), 0.0, 0.0], fill, edge, 3.0 if selected else PANEL_LINE_WIDTH)


## HP bar (art bible §7.5): outlined groove, the trail up to [param trail_ratio] behind the [param fill]
## up to [param ratio] (with a 1 px lighter top line), and with [param notch] a 2 px Ivory mark at 50 %
## protruding 3 px above and below.
static func hp_bar(canvas: CanvasItem, rect: Rect2, ratio: float, trail_ratio_value: float, fill: Color, notch: bool) -> void:
	var r: float = clampf(ratio, 0.0, 1.0)
	var t: float = clampf(trail_ratio_value, 0.0, 1.0)
	canvas.draw_rect(rect.grow(1.0), TEXT_OUTLINE)
	canvas.draw_rect(rect, HP_GROOVE)
	if t > r:
		canvas.draw_rect(Rect2(rect.position, Vector2(floorf(rect.size.x * t), rect.size.y)), HP_TRAIL)
	var fill_w: float = floorf(rect.size.x * r)
	if fill_w > 0.0:
		canvas.draw_rect(Rect2(rect.position, Vector2(fill_w, rect.size.y)), fill)
		canvas.draw_rect(Rect2(rect.position, Vector2(fill_w, 1.0)), fill.lightened(FILL_BEVEL_LIGHTEN))
	if notch:
		var nx: float = floorf(rect.position.x + rect.size.x * 0.5) - NOTCH_WIDTH * 0.5
		canvas.draw_rect(Rect2(nx, rect.position.y - NOTCH_PROTRUDE, NOTCH_WIDTH, rect.size.y + NOTCH_PROTRUDE * 2.0), IVORY)


## Draws the 55 px icon [param icon_name] of the icon sheet centred on [param center] at [param scale]
## (NEAREST), tinted by [param modulate]. False (and nothing drawn) when the sheet or the name is missing.
static func icon(canvas: CanvasItem, icon_name: String, center: Vector2, scale: float = 1.0, modulate: Color = Color.WHITE) -> bool:
	var src: Rect2 = icon_frame(icon_name)
	if src.size == Vector2.ZERO or _icon_texture == null or scale <= 0.0:
		return false
	var size: Vector2 = src.size * scale
	canvas.draw_texture_rect_region(_icon_texture, Rect2((center - size * 0.5).floor(), size), src, modulate)
	return true


## Source rect of [param icon_name] in the icon sheet; Rect2() when the sheet or the name is missing.
static func icon_frame(icon_name: String) -> Rect2:
	_ensure_icons()
	var raw: Variant = _icon_frames.get(icon_name)
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 4:
		return Rect2()
	var a: Array = raw as Array
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


## Test hook: forget the cached icon sheet and read it from [param png_path] / [param json_path] next time.
static func reset_icons(png_path: String = ICONS_PNG_PATH, json_path: String = ICONS_JSON_PATH) -> void:
	_icons_loaded = false
	_icon_texture = null
	_icon_frames = {}
	_icons_png = png_path
	_icons_json = json_path


static func _ensure_icons() -> void:
	if _icons_loaded:
		return
	_icons_loaded = true
	if not ResourceLoader.exists(_icons_png) or not FileAccess.file_exists(_icons_json):
		return
	var tex: Texture2D = load(_icons_png) as Texture2D
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_icons_json))
	if tex == null or typeof(parsed) != TYPE_DICTIONARY:
		return
	var icons: Variant = (parsed as Dictionary).get("icons")
	if typeof(icons) != TYPE_DICTIONARY:
		return
	# A CanvasTexture carries its own NEAREST filter, so the caller's texture_filter is left alone.
	_icon_texture = CanvasTexture.new()
	_icon_texture.diffuse_texture = tex
	_icon_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_frames = icons as Dictionary


static func _outline(canvas: CanvasItem, poly: PackedVector2Array, line: Color, width: float) -> void:
	if width <= 0.0 or line.a <= 0.0 or poly.size() < 2:
		return
	var closed: PackedVector2Array = poly.duplicate()
	closed.append(poly[0])
	canvas.draw_polyline(closed, line, width, false)

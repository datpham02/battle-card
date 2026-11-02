class_name PixelFrame
extends RefCounted
## Main Menu pass (user 2026-11-01: "background cổ cổ pixel, nút nhìn hiện đại quá"): draws a pixel-art frame
## texture as a nine-slice at a whole-number scale, so a button of any width keeps crisp corners and the art's
## pixel density. The corners ([param margin] art px each side) are drawn as they are; the edges and the centre
## stretch. The caller's CanvasItem should use nearest filtering.

## The PixelLab-generated stone button frame (Pro Flash 96x32, palette sampled from the menu background).
const BUTTON_FRAME: Texture2D = preload("res://assets/art/ui/title/button_frame.png")
## Corner size of BUTTON_FRAME in art px.
const BUTTON_MARGIN: int = 11
## Border of BUTTON_FRAME in art px (outer rim to just inside its gold line).
const BUTTON_FRAME_BORDER: int = 5
## Stone bars: groove colour and how much lighter the 1-art-px top row of the fill is.
const BAR_GROOVE: Color = Color("15131B")
const BAR_SHINE: float = 0.3

static var _nearest_cache: Dictionary = {}


## Draws [param texture] nine-sliced over [param rect] (screen px) with corners of [param margin] art px drawn at
## [param scale] (whole number), tinted by [param modulate]. A rect smaller than two corners squeezes them.
static func draw(canvas: CanvasItem, texture: Texture2D, rect: Rect2, margin: int, scale: int, modulate: Color = Color.WHITE) -> void:
	draw_margins(canvas, texture, rect, [margin, margin, margin, margin], scale, modulate)


## As [method draw] with a margin per side ([param margins] = [left, top, right, bottom] art px), for frames
## whose corners differ (the card frame's gem sockets). Each pair of corners is squeezed to fit [param rect].
static func draw_margins(canvas: CanvasItem, texture: Texture2D, rect: Rect2, margins: Array, scale: int, modulate: Color = Color.WHITE) -> void:
	if texture == null or margins.size() < 4:
		return
	var pixel: Texture2D = nearest(texture)
	var tex := Vector2(texture.get_size())
	var l: float = float(margins[0])
	var t: float = float(margins[1])
	var rm: float = float(margins[2])
	var b: float = float(margins[3])
	var fx: float = minf(1.0, rect.size.x / maxf((l + rm) * scale, 1.0))
	var fy: float = minf(1.0, rect.size.y / maxf((t + b) * scale, 1.0))
	var xs_src: Array[float] = [0.0, l, tex.x - rm, tex.x]
	var ys_src: Array[float] = [0.0, t, tex.y - b, tex.y]
	var r: Rect2 = Rect2(rect.position.round(), rect.size.round())
	var xs_dst: Array[float] = [r.position.x, r.position.x + roundf(l * scale * fx), r.end.x - roundf(rm * scale * fx), r.end.x]
	var ys_dst: Array[float] = [r.position.y, r.position.y + roundf(t * scale * fy), r.end.y - roundf(b * scale * fy), r.end.y]
	for j: int in 3:
		for i: int in 3:
			var src := Rect2(xs_src[i], ys_src[j], xs_src[i + 1] - xs_src[i], ys_src[j + 1] - ys_src[j])
			var dst := Rect2(xs_dst[i], ys_dst[j], xs_dst[i + 1] - xs_dst[i], ys_dst[j + 1] - ys_dst[j])
			if src.has_area() and dst.has_area():
				canvas.draw_texture_rect_region(pixel, dst, src, modulate)


## [param texture] wrapped in a CanvasTexture with NEAREST filtering (cached per texture), so pixel art stays crisp
## on any canvas whatever its texture_filter (the battle HUD views keep the project's linear default for the board's
## icons); the HudSkin icon sheet does the same.
static func nearest(texture: Texture2D) -> Texture2D:
	if texture == null or texture is CanvasTexture:
		return texture
	var key: int = texture.get_instance_id()
	if not _nearest_cache.has(key):
		var wrapped := CanvasTexture.new()
		wrapped.diffuse_texture = texture
		wrapped.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_nearest_cache[key] = wrapped
	return _nearest_cache[key]


## Pure: the whole-number frame scale for a viewport of height [param viewport_height] (2 at 720p, the menu
## background's density).
static func scale_for(viewport_height: float) -> int:
	return maxi(1, roundi(2.0 * viewport_height / 720.0))


## Pure: the whole-number scale of the SMALL stone pieces (bars, chips, icon frames) on a [param viewport_height]
## screen: half the menu density, never below 1 (1 at 720p and 1080p, 2 at 1440p). Battle HUD pass 2026-11-01:
## those pieces are 14-38 px tall at 720p, too short for the 22 px corners of the frame at the menu density, and a
## squeezed corner would not be a whole-number scale.
static func small_scale_for(viewport_height: float) -> int:
	@warning_ignore("integer_division")
	return maxi(1, scale_for(viewport_height) / 2)


## Pure: how far a stone frame drawn at [param scale] reaches outside the content it surrounds (its border, in
## screen px), so a bar or an icon sits just inside the frame's inner gold line.
static func frame_pad(scale: int) -> float:
	return float(BUTTON_FRAME_BORDER * scale)


## Battle HUD pass 2026-11-01: a stone bar. The small stone frame around [param rect] (grown by [method frame_pad]),
## a dark groove in [param rect], the [param ratio] share filled with [param fill] and a 1-art-px light top row on
## the fill (pixel shading). Whole-number scale, no smoothing; [param rect] keeps its layout size.
static func draw_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color, groove: Color = BAR_GROOVE, frame_tint: Color = Color.WHITE) -> void:
	var s: int = small_scale_for(canvas.get_viewport_rect().size.y)
	var r := Rect2(rect.position.round(), rect.size.round())
	draw(canvas, BUTTON_FRAME, r.grow(frame_pad(s)), BUTTON_MARGIN, s, Color(frame_tint, frame_tint.a * fill.a))
	canvas.draw_rect(r, Color(groove, maxf(groove.a, 0.9) * fill.a))
	var w: float = floorf(r.size.x * clampf(ratio, 0.0, 1.0))
	if w <= 0.0:
		return
	canvas.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), fill)
	canvas.draw_rect(Rect2(r.position, Vector2(w, float(s))), Color(fill.lightened(BAR_SHINE), fill.a))


## Battle HUD pass 2026-11-01: a small stone panel (chips, tags, icon frames): the stone frame at
## [method small_scale_for] over [param rect] as it is.
static func draw_small(canvas: CanvasItem, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	draw(canvas, BUTTON_FRAME, rect, BUTTON_MARGIN, small_scale_for(canvas.get_viewport_rect().size.y), modulate)


## Draws [param src] (texture px) of [param texture] repeated at whole-number [param scale] over [param dst]
## (screen px), the last row / column cropped: a tiled nine-slice middle keeps the art's pixel density where a
## stretch would smear its texture. [param flip_x] mirrors every tile.
static func draw_tiled(canvas: CanvasItem, texture: Texture2D, src: Rect2, dst: Rect2, scale: int, modulate: Color = Color.WHITE, flip_x: bool = false) -> void:
	if texture == null or not src.has_area() or not dst.has_area():
		return
	var pixel: Texture2D = nearest(texture)
	var tile := src.size * scale
	var y: float = 0.0
	while y < dst.size.y - 0.01:
		var h: float = minf(tile.y, dst.size.y - y)
		var x: float = 0.0
		while x < dst.size.x - 0.01:
			var w: float = minf(tile.x, dst.size.x - x)
			var part := Rect2(src.position, Vector2(w, h) / scale)
			if flip_x:
				part.position.x = src.end.x - part.size.x
			var to := Rect2(dst.position + Vector2(x, y), Vector2(w, h))
			if flip_x:
				# A negative width draws the region mirrored (RenderingServer flips it, the position stays).
				to.size.x = -w
			canvas.draw_texture_rect_region(pixel, to, part, modulate)
			x += tile.x
		y += tile.y


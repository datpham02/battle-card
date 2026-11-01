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


## Draws [param texture] nine-sliced over [param rect] (screen px) with corners of [param margin] art px drawn at
## [param scale] (whole number), tinted by [param modulate]. A rect smaller than two corners squeezes them.
static func draw(canvas: CanvasItem, texture: Texture2D, rect: Rect2, margin: int, scale: int, modulate: Color = Color.WHITE) -> void:
	draw_margins(canvas, texture, rect, [margin, margin, margin, margin], scale, modulate)


## As [method draw] with a margin per side ([param margins] = [left, top, right, bottom] art px), for frames
## whose corners differ (the card frame's gem sockets). Each pair of corners is squeezed to fit [param rect].
static func draw_margins(canvas: CanvasItem, texture: Texture2D, rect: Rect2, margins: Array, scale: int, modulate: Color = Color.WHITE) -> void:
	if texture == null or margins.size() < 4:
		return
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
				canvas.draw_texture_rect_region(texture, dst, src, modulate)


## Pure: the whole-number frame scale for a viewport of height [param viewport_height] (2 at 720p, the menu
## background's density).
static func scale_for(viewport_height: float) -> int:
	return maxi(1, roundi(2.0 * viewport_height / 720.0))

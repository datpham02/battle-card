class_name EffectText
extends RefCounted
## Controls v3 (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md, general rule 2): effect text WITHOUT a box (the
## resonance label, the hit forecast on the board, NGẮT!...): the words stand on their own colour (gold for a good
## effect), a thick ink outline and a slight drop shadow, EFFECT_SCALE x the size of plain HUD text, and a short pop
## when they appear (skipped with the reduce-motion setting). Pure drawing / maths; the caller keeps each label's age.

## Gold of a good effect (resonance), and the hit / miss forecast colours (the ghost's green / red, lightened).
const GOOD: Color = Color("FFD447")
const HIT: Color = Color("9CF29C")
const MISS: Color = Color("FF9A8A")
const NEUTRAL: Color = Color("EFE6D2")
## Ink outline width (px at 720p) and the shadow's offset and alpha.
const OUTLINE_PX: float = 6.0
const SHADOW_OFFSET_PX: float = 2.0
const SHADOW_ALPHA: float = 0.55
## Size relative to plain HUD text.
const EFFECT_SCALE: float = 1.2
## Pop: seconds it lasts and the extra scale it starts with (eases back to 1).
const POP_SEC: float = 0.18
const POP_EXTRA: float = 0.25


## Pure: the scale of a label [param age] seconds after it appeared: 1 + POP_EXTRA easing out to exactly 1 at POP_SEC,
## always 1 with [param reduce_motion].
static func pop_scale(age: float, reduce_motion: bool) -> float:
	if reduce_motion or age >= POP_SEC or age < 0.0:
		return 1.0
	var t: float = 1.0 - age / POP_SEC
	return 1.0 + POP_EXTRA * t * t


## Pure: the font size of effect text for plain HUD text of [param base_size].
static func size_for(base_size: int) -> int:
	return roundi(base_size * EFFECT_SCALE)


## Width of [param text] at [param size] (HudSkin Bold), with the outline.
static func width(text: String, size: int, s: float = 1.0) -> float:
	return HudSkin.text_width(text, size, true) + roundf(OUTLINE_PX * s)


## Draws [param text] with its baseline at [param pos].y, aligned by [param align] inside [param box_width] from
## [param pos].x, in [param color] (alpha too), [param size] px, popped by [param scale] round the line's centre;
## [param s] scales the outline and the shadow (px per 720p px).
static func draw(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, align: HorizontalAlignment,
		box_width: float, s: float = 1.0, scale: float = 1.0) -> void:
	if text.is_empty():
		return
	var f: Font = HudSkin.font(true)
	var outline: int = maxi(roundi(OUTLINE_PX * s), 2)
	var shadow := Vector2(1.0, 1.0) * maxf(roundf(SHADOW_OFFSET_PX * s), 1.0)
	var scaled: bool = not is_equal_approx(scale, 1.0)
	if scaled:
		var pivot := Vector2(pos.x + box_width * 0.5, pos.y - size * 0.35)
		canvas.draw_set_transform(pivot - pivot * scale, 0.0, Vector2(scale, scale))
	canvas.draw_string_outline(f, pos + shadow, text, align, box_width, size, outline, Color(0.0, 0.0, 0.0, SHADOW_ALPHA * color.a))
	canvas.draw_string_outline(f, pos, text, align, box_width, size, outline, Color(HudSkin.TEXT_OUTLINE, color.a))
	canvas.draw_string(f, pos, text, align, box_width, size, color)
	if scaled:
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

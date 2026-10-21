class_name UiButtons
extends RefCounted
## Shared placeholder button painter (Story 016): the one look every tappable rectangle of the
## shell uses — RunHudView's run-screen and pause buttons, FloorSelectView's prompts and "Về",
## TitleView's column. Pure drawing on the caller's CanvasItem (no nodes, no state); the hit
## testing stays in the views (they own the rects and the input dedup).
## Styles: PRIMARY (green, the main action), SECONDARY (grey, the second run-screen action),
## DANGER (warm, destructive), NEUTRAL (grey, the safe choice next to a DANGER one).
## Pressed = darker back + gold outline; disabled = every colour dimmed to [constant DIM_ALPHA],
## never drawn pressed. The colours are the Story 011 / 015 ones, moved here unchanged.

enum Style { PRIMARY, SECONDARY, DANGER, NEUTRAL }

const PRIMARY_BACK: Color = Color(0.13, 0.45, 0.22)
const SECONDARY_BACK: Color = Color(0.3, 0.3, 0.32)
const DANGER_BACK: Color = Color(0.4, 0.2, 0.15)
const NEUTRAL_BACK: Color = Color(0.32, 0.3, 0.34)
const PRESSED_BACK: Color = Color(0.06, 0.25, 0.12)
const OUTLINE: Color = Color(0.95, 0.9, 0.78)
const PRESSED_OUTLINE: Color = Color(1.0, 0.85, 0.2)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const OUTLINE_WIDTH: float = 4.0
const DEFAULT_FONT_SIZE: int = 32
## Alpha multiplier of a disabled button (the CutHudView dim look).
const DIM_ALPHA: float = 0.4
## Text baseline below the rect centre, as a share of the font size (single-line centring).
const BASELINE_RATIO: float = 0.35


## Draws one button on [param canvas]: filled [param rect] in the colour of [param style] (a
## [enum Style] value), its outline, and [param text] centred (skipped when empty, so callers can
## paint a glyph of their own). [param pressed] (see [method is_pressed_at]) switches to the
## pressed colours unless [param enabled] is false, which dims everything instead.
## [param outline_width] exists so the Story 015 prompts keep their thinner outline.
static func draw_button(canvas: CanvasItem, rect: Rect2, text: String, style: int, pressed: bool, enabled: bool = true, font_size: int = DEFAULT_FONT_SIZE, outline_width: float = OUTLINE_WIDTH) -> void:
	var back: Color = back_color(style)
	var outline: Color = OUTLINE
	var text_color: Color = TEXT_COLOR
	if enabled and pressed:
		back = PRESSED_BACK
		outline = PRESSED_OUTLINE
	if not enabled:
		back.a *= DIM_ALPHA
		outline.a *= DIM_ALPHA
		text_color.a *= DIM_ALPHA
	canvas.draw_rect(rect, back)
	canvas.draw_rect(rect, outline, false, outline_width)
	if not text.is_empty():
		var baseline := Vector2(rect.position.x, rect.get_center().y + font_size * BASELINE_RATIO)
		canvas.draw_string(ThemeDB.fallback_font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, text_color)


## Background colour of a [enum Style] value (PRIMARY for unknown values).
static func back_color(style: int) -> Color:
	match style:
		Style.SECONDARY:
			return SECONDARY_BACK
		Style.DANGER:
			return DANGER_BACK
		Style.NEUTRAL:
			return NEUTRAL_BACK
	return PRIMARY_BACK


## True while the left mouse button (or the emulated mouse of a touch) is held over [param rect]
## of [param canvas]'s viewport: the pressed look between a press and its release.
static func is_pressed_at(canvas: CanvasItem, rect: Rect2) -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and rect.has_point(canvas.get_viewport().get_mouse_position())

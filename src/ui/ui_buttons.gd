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
	# 2026-10-31 (user: "chưa apply hud cho toàn bộ màn"): every screen's buttons in the game skin (HudSkin.button):
	# chamfered dark panel, style line, outlined bold label. Rects and hit areas are unchanged. The old outline width
	# maps to the skin's line width (thin prompts stay thin).
	# 2026-11-01 (user, Main Menu pass: the menu's pixel stone buttons on every screen): the PixelLab stone frame
	# (PixelFrame, nine-sliced at the menu background's density) and a Handjet label (MenuFont). Style: PRIMARY gold
	# label + brighter frame, DANGER warm-tinted frame + amber label, SECONDARY / NEUTRAL ivory; pressed darkens the
	# frame and sinks the label 2 px; disabled dims both. Rects and hit areas are unchanged.
	var _unused_outline: float = outline_width
	var tint: Color = Color.WHITE
	var label: Color = PIXEL_LABEL
	match style:
		Style.PRIMARY:
			tint = PIXEL_PRIMARY_TINT
			label = PIXEL_LABEL_PRIMARY
		Style.DANGER:
			tint = PIXEL_DANGER_TINT
			label = PIXEL_LABEL_DANGER
	if not enabled:
		tint = PIXEL_DISABLED_TINT
		label = Color(label, 0.5)
	elif pressed:
		tint = PIXEL_PRESSED_TINT
	var vp_h: float = canvas.get_viewport_rect().size.y
	PixelFrame.draw(canvas, PixelFrame.BUTTON_FRAME, rect, PixelFrame.BUTTON_MARGIN, PixelFrame.scale_for(vp_h), tint)
	if text.is_empty():
		return
	var size: int = MenuFont.fit_size(text, font_size, rect.size.x - PIXEL_LABEL_PAD * 2.0)
	var y: float = rect.get_center().y + MenuFont.size(size) * 0.3 + (2.0 if pressed and enabled else 0.0)
	MenuFont.text(canvas, Vector2(rect.position.x, y), text, size, label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


## Pixel stone buttons (2026-11-01): label colours and frame tints per style / state, label side padding in px.
const PIXEL_LABEL: Color = Color("F8F8D0")
const PIXEL_LABEL_PRIMARY: Color = Color("F8E080")
const PIXEL_LABEL_DANGER: Color = Color("F8B860")
const PIXEL_PRIMARY_TINT: Color = Color(1.12, 1.08, 1.0)
const PIXEL_DANGER_TINT: Color = Color(1.15, 0.82, 0.78)
const PIXEL_PRESSED_TINT: Color = Color(0.75, 0.75, 0.8)
const PIXEL_DISABLED_TINT: Color = Color(0.55, 0.55, 0.6, 0.8)
const PIXEL_LABEL_PAD: float = 14.0


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

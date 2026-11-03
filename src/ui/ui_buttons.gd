class_name UiButtons
extends RefCounted
## Shared button painter (Story 016; ancient plates since 2026-11-02): the one look every tappable rectangle of the
## shell uses — RunHudView's run-screen and pause buttons, FloorSelectView's prompts and "Về",
## TitleView's column. Pure drawing on the caller's CanvasItem (no nodes, no state); the hit
## testing stays in the views (they own the rects and the input dedup).
## Styles: PRIMARY (gold plate with gems, the main action), SECONDARY / NEUTRAL (navy plate), DANGER (wine plate).
## Pressed = darker fill and the plate sinks onto its lip; disabled = grey plate, never drawn pressed.
## The *_BACK colours and back_color are the Story 011 / 015 ones, kept for the views that still read them.

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


## Draws one button on [param canvas]: an ancient plate over [param rect] in the look of [param style] (a
## [enum Style] value, see [method look]) and [param text] centred on it (skipped when empty, so callers can paint a
## glyph of their own). [param pressed] (see [method is_pressed_at]) sinks the plate unless [param enabled] is false,
## which greys it instead. [param outline_width] is kept for the old callers and ignored.
static func draw_button(canvas: CanvasItem, rect: Rect2, text: String, style: int, pressed: bool, enabled: bool = true, font_size: int = DEFAULT_FONT_SIZE, outline_width: float = OUTLINE_WIDTH) -> void:
	# 2026-11-02 (user reference sheet of the button system; the riveted stone frame stays on cards only): every
	# screen's buttons are the ancient pixel-art plate (PLATES, tiled nine-slice): cut corners, gold rim shaded per
	# pixel, thin inner gold line, speckled fill and a lip; PRIMARY is gold with pixel gems at both ends and a dark
	# label. Rects and hit areas are unchanged.
	var _unused_outline: float = outline_width
	var s: float = ui_scale(canvas)
	var lk: Dictionary = look(style, pressed, enabled)
	var body: Rect2 = draw_plate(canvas, rect, lk, s, pressed and enabled)
	if bool(lk["gems"]):
		# Set on the rim at both ends, as on the reference sheet.
		var inset: float = GEM_INSET_ART * s
		draw_gem(canvas, Vector2(body.position.x + inset, body.get_center().y), s)
		draw_gem(canvas, Vector2(body.end.x - inset, body.get_center().y), s)
	if text.is_empty():
		return
	var pad: float = PIXEL_LABEL_PAD + (GEM_INSET_ART * 2.0 * s if bool(lk["gems"]) else 0.0)
	var size: int = MenuFont.fit_size(text, font_size, body.size.x - pad * 2.0)
	var y: float = body.get_center().y + MenuFont.size(size) * 0.3
	MenuFont.text_outlined(canvas, Vector2(body.position.x, y), text, size, lk["text"], lk["text_outline"],
		HORIZONTAL_ALIGNMENT_CENTER, body.size.x)


## 2026-11-02 ancient plates: pixel-art nine-slice sources made by tools/asset-pipeline/make_ui_plates.py (cut
## corners, ink outline, gold rim shaded per pixel, thin inner gold line with corner ticks, speckled fill, lip), drawn
## tiled at the whole-number art scale ([method ui_scale]); keys "<look>_up" / "<look>_down" (moss: a green plate a
## caller sets as look["plate"], e.g. the shop's heal service).
const PLATES: Dictionary = {
	"gold_up": preload("res://assets/art/ui/plates/plate_gold_up.png"), "gold_down": preload("res://assets/art/ui/plates/plate_gold_down.png"),
	"navy_up": preload("res://assets/art/ui/plates/plate_navy_up.png"), "navy_down": preload("res://assets/art/ui/plates/plate_navy_down.png"),
	"wine_up": preload("res://assets/art/ui/plates/plate_wine_up.png"), "wine_down": preload("res://assets/art/ui/plates/plate_wine_down.png"),
	"grey_up": preload("res://assets/art/ui/plates/plate_grey_up.png"), "grey_down": preload("res://assets/art/ui/plates/plate_grey_down.png"),
	"moss_up": preload("res://assets/art/ui/plates/plate_moss_up.png"), "moss_down": preload("res://assets/art/ui/plates/plate_moss_down.png"),
}
const GEM_TEXTURE: Texture2D = preload("res://assets/art/ui/plates/gem.png")
## Nine-slice margins of the plate sources (art px: left, top, right, bottom incl. the 2 px lip), the lip, the art px
## from the body edge to the inside of the inner gold line, and the gem centre's distance from a body end.
const PLATE_MARGINS: Array[int] = [8, 8, 8, 10]
const LIP_ART: float = 2.0
const PLATE_INNER_ART: float = 6.0
const GEM_INSET_ART: float = 3.0
## Ancient plate colours: ink edge, gold rim (light top facet / dark lip), fills per look, labels, the blue gem.
const PLATE_INK: Color = Color("1B1722")
const GOLD_RIM: Color = Color("D9A23E")
const GOLD_RIM_LIGHT: Color = Color("F2CF7A")
const GOLD_LIP: Color = Color("7A4E16")
const GOLD_FILL: Color = Color("E8B04A")
const GOLD_FILL_TOP: Color = Color("F5CD6C")
const GOLD_FILL_PRESSED: Color = Color("B98328")
const NAVY_FILL: Color = Color("262A44")
const NAVY_FILL_TOP: Color = Color("323858")
const NAVY_FILL_PRESSED: Color = Color("1A1D30")
const DANGER_FILL: Color = Color("5C2430")
const DANGER_FILL_TOP: Color = Color("703040")
const DANGER_FILL_PRESSED: Color = Color("431A23")
const GREY_FILL: Color = Color("34333C")
const GREY_FILL_TOP: Color = Color("3E3D47")
const GREY_RIM: Color = Color("6A6974")
const GREY_LIP: Color = Color("24232A")
const LABEL_DARK: Color = Color("3A2410")
const LABEL_LIGHT: Color = Color("F4EEDB")
const LABEL_DANGER: Color = Color("FFD9B0")
const LABEL_GREY: Color = Color("8A8992")
const GEM_FILL: Color = Color("5E9BE8")
const GEM_LIGHT: Color = Color("B5D4F4")


## Pure: the colours of a plate of [param style] (fill, fill_top, rim, rim_light, lip, text, text_outline), its
## texture ("plate": gold, navy, wine or grey) and whether it carries gems. PRIMARY gold (gems, dark label), SECONDARY / NEUTRAL navy, DANGER wine; [param selected] turns the
## plate gold (the chosen state); pressed darkens the fill; disabled is grey without gems.
static func look(style: int, pressed: bool, enabled: bool = true, selected: bool = false) -> Dictionary:
	var gold: bool = style == Style.PRIMARY or selected
	var out: Dictionary = {"rim": GOLD_RIM, "rim_light": GOLD_RIM_LIGHT, "lip": GOLD_LIP, "gems": style == Style.PRIMARY,
		"plate": "grey" if not enabled else ("gold" if gold else ("wine" if style == Style.DANGER else "navy"))}
	if not enabled:
		out.merge({"fill": GREY_FILL, "fill_top": GREY_FILL_TOP, "rim": GREY_RIM, "rim_light": GREY_RIM, "lip": GREY_LIP,
			"text": LABEL_GREY, "text_outline": PLATE_INK, "gems": false}, true)
	elif gold:
		out.merge({"fill": GOLD_FILL_PRESSED if pressed else GOLD_FILL, "fill_top": GOLD_FILL_PRESSED if pressed else GOLD_FILL_TOP,
			"text": LABEL_DARK, "text_outline": GOLD_FILL_TOP}, true)
	elif style == Style.DANGER:
		out.merge({"fill": DANGER_FILL_PRESSED if pressed else DANGER_FILL, "fill_top": DANGER_FILL_PRESSED if pressed else DANGER_FILL_TOP,
			"text": LABEL_DANGER, "text_outline": PLATE_INK}, true)
	else:
		out.merge({"fill": NAVY_FILL_PRESSED if pressed else NAVY_FILL, "fill_top": NAVY_FILL_PRESSED if pressed else NAVY_FILL_TOP,
			"text": LABEL_LIGHT, "text_outline": PLATE_INK}, true)
	return out


## Pure: the plate's body inside [param rect] at the whole-number art scale [param s]: the rect minus the lip, moved
## down by the lip while [param sunk] (pressed), so the hit rect never moves.
static func body_rect(rect: Rect2, s: float, sunk: bool) -> Rect2:
	var lip: float = LIP_ART * s
	return Rect2(rect.position + Vector2(0.0, lip if sunk else 0.0), Vector2(rect.size.x, maxf(rect.size.y - lip, 1.0)))


## Px from the body's edge to the inside of the plate's inner gold line at art scale [param s] (where the content of
## an icon plate sits).
static func plate_inset(s: float) -> float:
	return PLATE_INNER_ART * s


## Whole-number art scale of the plates on [param canvas]'s viewport (PixelFrame.scale_for: 2 at 720p).
static func ui_scale(canvas: CanvasItem) -> float:
	return float(PixelFrame.scale_for(canvas.get_viewport_rect().size.y))


## Draws the ancient plate [param lk] ([method look], its "plate" texture) over [param rect] as a tiled nine-slice at
## art scale [param s] (whole number); returns its body ([method body_rect]). The "up" texture carries the lip under
## the plate, the "down" one (while [param sunk]) is the plate moved onto it; [param modulate] tints the texture.
static func draw_plate(canvas: CanvasItem, rect: Rect2, lk: Dictionary, s: float, sunk: bool, modulate: Color = Color.WHITE) -> Rect2:
	var tex: Texture2D = PLATES.get("%s_%s" % [lk["plate"], "down" if sunk else "up"], null)
	PixelFrame.draw_nine_tiled(canvas, tex, rect, PLATE_MARGINS, maxi(int(s), 1), modulate)
	return body_rect(rect, s, sunk)


## An icon button: a navy ancient plate (gold while [param selected], grey when disabled) over [param rect]; returns
## the area inside its inner line for the caller's glyph (it follows the plate down while pressed).
static func draw_icon_button(canvas: CanvasItem, rect: Rect2, pressed: bool, enabled: bool = true, selected: bool = false) -> Rect2:
	var s: float = icon_scale(rect, ui_scale(canvas))
	var body: Rect2 = draw_plate(canvas, rect, look(Style.SECONDARY, pressed, enabled, selected), s, pressed and enabled)
	return body.grow(-plate_inset(s))


## Pure: the art scale for an icon plate of [param rect]: [param s] lowered (never below 1) until the plate's two
## corners take at most two thirds of its shorter side, so a small tile (the 38 px battle pause) keeps room for its
## glyph.
static func icon_scale(rect: Rect2, s: float) -> float:
	var corners: float = float(PLATE_MARGINS[0] + PLATE_MARGINS[2])
	var out: float = maxf(s, 1.0)
	while out > 1.0 and corners * out > minf(rect.size.x, rect.size.y) * 2.0 / 3.0:
		out -= 1.0
	return out


## The pixel gem (GEM_TEXTURE, a faceted blue diamond in a gold socket) centred on [param center] at art scale
## [param s] (whole number).
static func draw_gem(canvas: CanvasItem, center: Vector2, s: float) -> void:
	var size: Vector2 = Vector2(GEM_TEXTURE.get_size()) * maxf(s, 1.0)
	canvas.draw_texture_rect(PixelFrame.nearest(GEM_TEXTURE), Rect2((center - size * 0.5).round(), size), false)


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

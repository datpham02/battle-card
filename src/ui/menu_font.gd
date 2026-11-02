class_name MenuFont
extends RefCounted
## Main Menu pass (user 2026-11-01: the menu text looked too modern over the pixel background): the pixel font the
## title and the settings screen draw their labels with. Both candidates are OFL and cover Vietnamese (checked
## glyph by glyph): Handjet (variable, drawn at weight [constant HANDJET_WEIGHT]) and VT323. "noto" keeps the HUD's
## Noto Sans Bold. DEV-ONLY user arg `--menu-font=handjet|vt323|noto` picks one for captures.

const CHOICES: Array[String] = ["handjet", "vt323", "noto"]
const PATHS: Dictionary = {
	"handjet": "res://assets/fonts/Handjet.ttf",
	"vt323": "res://assets/fonts/VT323-Regular.ttf",
}
## Size factor per font so the same nominal size reads about as large as Noto Sans.
const SIZE_SCALE: Dictionary = {"handjet": 1.25, "vt323": 1.45, "noto": 1.0}
const HANDJET_WEIGHT: int = 600
const ARG: String = "--menu-font="
## Outline drawn around every label (HudSkin's outline colour).
const OUTLINE_PX: int = 6

static var choice: String = "handjet"
static var _cache: Dictionary = {}
static var _args_read: bool = false


## Applies the DEV `--menu-font=` user arg once (an unknown value is ignored).
static func read_args() -> void:
	if _args_read:
		return
	_args_read = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ARG) and CHOICES.has(arg.trim_prefix(ARG)):
			choice = arg.trim_prefix(ARG)


## The current menu font; null for "noto" or a missing file (HudSkin's bold font is used then).
static func font() -> Font:
	if choice == "noto" or not PATHS.has(choice):
		return null
	if _cache.has(choice):
		return _cache[choice]
	var base: Font = load(PATHS[choice]) as Font
	var out: Font = base
	if base != null and choice == "handjet":
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): HANDJET_WEIGHT}
		out = v
	_cache[choice] = out
	return out


## [param base] font size scaled for the current menu font.
static func size(base: int) -> int:
	return roundi(base * float(SIZE_SCALE.get(choice, 1.0)))


## The largest nominal size <= [param size_px] at which [param content] fits [param max_width] in the menu font
## (never below 60 % of it).
static func fit_size(content: String, size_px: int, max_width: float) -> int:
	var f: Font = font()
	if f == null or max_width <= 0.0:
		return size_px
	var s: int = size_px
	var floor_size: int = maxi(8, roundi(size_px * 0.6))
	while s > floor_size and f.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size(s)).x > max_width:
		s -= 1
	return s


## Draws an outlined label in the menu font at baseline [param pos] (HudSkin.text with Noto Bold when the menu font
## is "noto" or missing). [param size] is the nominal (Noto) size; it is scaled by [method size].
static func text(canvas: CanvasItem, pos: Vector2, content: String, size_px: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, _bold: bool = true) -> void:
	text_outlined(canvas, pos, content, size_px, color, HudSkin.TEXT_OUTLINE, align, width)


## As [method text] with the outline in [param outline] (2026-11-02: dark labels on the gold buttons take a light
## outline instead of the ink one).
static func text_outlined(canvas: CanvasItem, pos: Vector2, content: String, size_px: int, color: Color, outline: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if content.is_empty():
		return
	var f: Font = font()
	if f == null:
		HudSkin.text(canvas, pos, content, size_px, color, align, width, true)
		return
	var s: int = size(size_px)
	canvas.draw_string_outline(f, pos, content, align, width, s, OUTLINE_PX, Color(outline, outline.a * color.a))
	canvas.draw_string(f, pos, content, align, width, s, color)

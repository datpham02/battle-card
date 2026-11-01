class_name RelicStrip
extends Node2D
## Story 032 Phần D: a reusable, code-drawn strip of relic icons (one per owned relic, received order).
## An icon is a square with the first letter of the relic's translated name on a dark back, bordered in
## the rarity colour (common grey, rare blue, epic gold, boss crimson); a relic tagged `negative` gets
## a red border instead (its rarity stays visible as a thin inner bar along the bottom).
##
## Two modes:
## - interactive (map, treasure, pause): icons are touch targets >= [constant MIN_TOUCH_ICON] px
##   (48 dp at the 1280x720 logical resolution). When the icons do not fit [member area] the strip
##   scrolls by a horizontal drag. A tap (press + release without dragging past DRAG_THRESHOLD) opens
##   a tooltip card above/below the strip: name, rarity word (+ "Đánh đổi" for negative), the rule
##   text (which carries the numbers). Any press outside the card closes it (and is consumed).
## - display-only (in match, [member interactive] = false): takes NO input, smaller icons, overflow
##   shows "+N"; [method flash] lights one icon up for [constant FLASH_SEC] s.
## The owner view feeds input through [method handle_input] (the strip has no _input of its own, so the
## owner keeps its "swallow everything" rule) and sets [member area] / [method set_relics] each frame.
## Reads relic data through RelicRegistry.info; all strings via tr().

## 2026-10-31 (whole-game HUD skin): icons sit on the dark skin (NIGHT_STONE_LIGHT face, outlined TEXT letter);
## the rarity / negative borders keep their meaning colours, lifted a little to read on HudSkin.SCREEN_BG.
const BACK_COLOR: Color = HudSkin.NIGHT_STONE_LIGHT
const GLYPH_COLOR: Color = HudSkin.TEXT
const RARITY_COMMON_COLOR: Color = Color(0.66, 0.68, 0.72)
const RARITY_RARE_COLOR: Color = Color(0.38, 0.62, 1.0)
const RARITY_EPIC_COLOR: Color = HudSkin.GRID_LIGHT
const RARITY_BOSS_COLOR: Color = Color(0.86, 0.36, 0.58)
const NEGATIVE_COLOR: Color = Color(0.9, 0.12, 0.1)
const OPEN_OUTLINE: Color = HudSkin.IVORY
const FLASH_COLOR: Color = Color(1.0, 0.95, 0.6)
const EMPTY_TEXT_COLOR: Color = HudSkin.TEXT_DIM
const TIP_BACK: Color = Color(0.118, 0.106, 0.141, 0.97)
const TIP_NAME_COLOR: Color = HudSkin.IVORY
const TIP_DESC_COLOR: Color = HudSkin.TEXT
const TIP_HINT_COLOR: Color = HudSkin.TEXT_DIM
const MORE_COLOR: Color = HudSkin.TEXT_DIM

## Smallest interactive icon edge (48 dp ~ 64 px at the current logical resolution).
const MIN_TOUCH_ICON: float = 64.0
## Largest icon edge (a tall area does not make huge icons).
const MAX_ICON: float = 72.0
const ICON_GAP: float = 8.0
const DISPLAY_ICON_GAP: float = 4.0
const BORDER_WIDTH: float = 4.0
const DISPLAY_BORDER_WIDTH: float = 2.5
const RARITY_BAR_RATIO: float = 0.12
const GLYPH_FONT_RATIO: float = 0.5
## Drag distance (px) after which a press becomes a scroll instead of a tap.
const DRAG_THRESHOLD: float = 12.0
## Story 032: an in-match icon lights up this long when its relic acts.
const FLASH_SEC: float = 0.4
const FLASH_GROW: float = 3.0
## Tooltip card: width, inner padding, font sizes, description line cap, gap to the strip.
const TIP_WIDTH: float = 440.0
const TIP_PAD: float = 16.0
const TIP_NAME_FONT: int = 28
const TIP_RARITY_FONT: int = 20
const TIP_DESC_FONT: int = 22
const TIP_HINT_FONT: int = 16
const TIP_DESC_LINES: int = 5
const TIP_GAP: float = 10.0
const TIP_BORDER: float = 4.0
const EMPTY_FONT: int = 20
const MORE_FONT_RATIO: float = 0.55

const TAG_NEGATIVE: String = "negative"
const RARITY_KEY_FORMAT: String = "ui.relic.rarity.%s"
const TEXT_NEGATIVE: String = "ui.relic.negative"
const TEXT_TAP_CLOSE: String = "ui.relic.tap_close"
const TEXT_EMPTY: String = "ui.relic.empty"
const RARITY_SEPARATOR: String = " · "
const MORE_FORMAT: String = "+%d"

## Screen rect the strip lives in (owner sets it every frame from ScreenLayout).
var area: Rect2 = Rect2()
## False = display-only (in match): no input, no tooltip, small icons, can flash.
var interactive: bool = true
## Show "Chưa có bảo vật" when the list is empty (interactive mode only).
var show_empty_text: bool = true

var _ids: Array[String] = []
var _scroll: float = 0.0
var _open: int = -1
var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_scroll: float = 0.0
var _dragged: bool = false
var _flash: Dictionary = {}  # relic id -> seconds left


func _process(delta: float) -> void:
	for id: String in _flash.keys():
		_flash[id] = float(_flash[id]) - delta
		if float(_flash[id]) <= 0.0:
			_flash.erase(id)
	queue_redraw()


## Replaces the shown relics (received order). Keeps scroll / tooltip when the list is unchanged.
func set_relics(ids: Array[String]) -> void:
	if ids == _ids:
		return
	_ids = ids.duplicate()
	if _open >= _ids.size():
		_open = -1
	_scroll = clampf(_scroll, 0.0, _max_scroll())


func get_relics() -> Array[String]:
	return _ids.duplicate()


## Lights the icon of [param relic_id] up for FLASH_SEC (unknown / not shown ids are ignored).
func flash(relic_id: String) -> void:
	if _ids.has(relic_id):
		_flash[relic_id] = FLASH_SEC


func is_flashing(relic_id: String) -> bool:
	return _flash.has(relic_id)


## Opens the tooltip of icon [param index] (demos / tests; interactive mode only).
func open_tooltip(index: int) -> void:
	if interactive and index >= 0 and index < _ids.size():
		_open = index


func close_tooltip() -> void:
	_open = -1


func is_tooltip_open() -> bool:
	return _open >= 0


## Index of the open tooltip's relic, -1 when closed.
func get_open_index() -> int:
	return _open


## Edge of one icon in the current mode.
func icon_size() -> float:
	if not interactive:
		return maxf(area.size.y, 1.0)
	return clampf(area.size.y, MIN_TOUCH_ICON, MAX_ICON)


## Screen rect of icon [param index] after scrolling (may lie outside [member area] when scrolled away).
func icon_rect(index: int) -> Rect2:
	var size: float = icon_size()
	var gap: float = ICON_GAP if interactive else DISPLAY_ICON_GAP
	var x: float = area.position.x + (size + gap) * index - _scroll
	return Rect2(x, area.get_center().y - size * 0.5, size, size)


## Feeds one pointer event (owner's _input). Returns true when the strip used it (the owner must then
## not act on it). Display-only strips never consume anything.
func handle_input(event: InputEvent) -> bool:
	if not interactive or not visible:
		return false
	var pressed: Variant = _press_state(event)
	if pressed == true:
		var pos: Vector2 = _event_pos(event)
		if _open >= 0:
			if not _tooltip_rect().has_point(pos):
				_open = -1
			return true
		if area.has_point(pos) and not _ids.is_empty():
			_pressing = true
			_dragged = false
			_press_pos = pos
			_press_scroll = _scroll
			return true
		return false
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if not _pressing:
			return false
		var pos: Vector2 = _event_pos(event)
		if absf(pos.x - _press_pos.x) > DRAG_THRESHOLD:
			_dragged = true
		if _dragged:
			_scroll = clampf(_press_scroll - (pos.x - _press_pos.x), 0.0, _max_scroll())
		return true
	if pressed == false:
		if not _pressing:
			return false
		_pressing = false
		if not _dragged:
			var index: int = _index_at(_event_pos(event))
			if index >= 0:
				_open = index
		return true
	return false


# true for a press, false for a release, null for anything else (left mouse button or touch).
func _press_state(event: InputEvent) -> Variant:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index != MOUSE_BUTTON_LEFT:
			return null
		return b.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return null


func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.INF


func _index_at(pos: Vector2) -> int:
	if not area.has_point(pos):
		return -1
	for i: int in _ids.size():
		if icon_rect(i).has_point(pos):
			return i
	return -1


func _content_width() -> float:
	if _ids.is_empty():
		return 0.0
	var gap: float = ICON_GAP if interactive else DISPLAY_ICON_GAP
	return icon_size() * _ids.size() + gap * (_ids.size() - 1)


func _max_scroll() -> float:
	return maxf(_content_width() - area.size.x, 0.0)


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if area.size.x <= 0.0:
		return
	if _ids.is_empty():
		if interactive and show_empty_text:
			HudSkin.text(self, Vector2(area.position.x, area.get_center().y + EMPTY_FONT * 0.35),
				tr(TEXT_EMPTY), EMPTY_FONT, EMPTY_TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT, area.size.x)
		return
	if interactive:
		_draw_interactive()
	else:
		_draw_display()
	if _open >= 0:
		_draw_tooltip(_open)


func _draw_interactive() -> void:
	for i: int in _ids.size():
		var rect: Rect2 = icon_rect(i)
		# Only icons fully inside the area are drawn (no half-cut icons, no draw outside the strip).
		if rect.position.x < area.position.x - 0.5 or rect.end.x > area.end.x + 0.5:
			continue
		draw_icon(self, rect, _ids[i], BORDER_WIDTH, i == _open, 0.0)
	# Scroll hints: small chevrons at a side that hides icons.
	var size: float = icon_size()
	if _scroll > 0.5:
		_chevron(Vector2(area.position.x - ICON_GAP * 0.5, area.get_center().y), -1.0, size)
	if _scroll < _max_scroll() - 0.5:
		_chevron(Vector2(area.end.x + ICON_GAP * 0.5, area.get_center().y), 1.0, size)


func _draw_display() -> void:
	var size: float = icon_size()
	var fit: int = maxi(int((area.size.x + DISPLAY_ICON_GAP) / (size + DISPLAY_ICON_GAP)), 1)
	var shown: int = _ids.size() if _ids.size() <= fit else fit - 1
	for i: int in shown:
		var glow: float = 0.0
		if _flash.has(_ids[i]):
			glow = float(_flash[_ids[i]]) / FLASH_SEC
		draw_icon(self, icon_rect(i), _ids[i], DISPLAY_BORDER_WIDTH, false, glow)
	if shown < _ids.size():
		var rect: Rect2 = icon_rect(shown)
		var font: int = int(size * MORE_FONT_RATIO)
		HudSkin.text(self, Vector2(rect.position.x, rect.get_center().y + font * 0.35),
			MORE_FORMAT % (_ids.size() - shown), font, MORE_COLOR, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)


func _chevron(tip: Vector2, dir: float, size: float) -> void:
	var h: float = size * 0.18
	var w: float = h * 0.7 * dir
	draw_polyline(PackedVector2Array([tip + Vector2(-w, -h), tip, tip + Vector2(-w, h)]), EMPTY_TEXT_COLOR, 3.0)


## Draws one relic icon of [param relic_id] into [param rect] on [param canvas] (shared with the treasure
## cards). [param glow] in 0..1 lights it up (in-match flash).
static func draw_icon(canvas: CanvasItem, rect: Rect2, relic_id: String, border: float, open: bool, glow: float) -> void:
	var info: Dictionary = RelicRegistry.info(relic_id)
	var rarity_color: Color = rarity_color(str(info.get("rarity", "")))
	var negative: bool = is_negative(info)
	if glow > 0.0:
		canvas.draw_rect(rect.grow(FLASH_GROW * glow + border), Color(FLASH_COLOR, glow))
	canvas.draw_rect(rect, BACK_COLOR.lerp(FLASH_COLOR, glow * 0.6))
	var bar: float = rect.size.y * RARITY_BAR_RATIO
	if negative:
		canvas.draw_rect(Rect2(rect.position.x, rect.end.y - bar, rect.size.x, bar), rarity_color)
	var outline: Color = OPEN_OUTLINE if open else (NEGATIVE_COLOR if negative else rarity_color)
	canvas.draw_rect(rect, outline, false, border * (1.5 if open else 1.0))
	var font: int = maxi(int(rect.size.y * GLYPH_FONT_RATIO), 8)
	var name: String = TranslationServer.translate(str(info.get("name_key", relic_id)))
	var glyph: String = name.substr(0, 1).to_upper() if not name.is_empty() else "?"
	HudSkin.text(canvas, Vector2(rect.position.x, rect.get_center().y + font * 0.35),
		glyph, font, GLYPH_COLOR, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)


## Border colour of a relic rarity id (common for anything unknown).
static func rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return RARITY_RARE_COLOR
		"epic":
			return RARITY_EPIC_COLOR
		"boss":
			return RARITY_BOSS_COLOR
	return RARITY_COMMON_COLOR


static func is_negative(info: Dictionary) -> bool:
	var tags: Variant = info.get("tags", [])
	return tags is Array and (tags as Array).has(TAG_NEGATIVE)


## "Hiếm" / "Hiếm · Đánh đổi": the rarity word plus the trade-off word for a negative relic.
static func rarity_line(info: Dictionary) -> String:
	var text: String = TranslationServer.translate(RARITY_KEY_FORMAT % str(info.get("rarity", "common")))
	if is_negative(info):
		text += RARITY_SEPARATOR + TranslationServer.translate(TEXT_NEGATIVE)
	return text


# Tooltip card of icon [param index]: above the strip when the strip sits in the lower half of the screen,
# below it otherwise; clamped inside the viewport horizontally.
func _tooltip_rect() -> Rect2:
	if _open < 0:
		return Rect2()
	var vp: Vector2 = get_viewport_rect().size
	var desc: String = tr(str(RelicRegistry.info(_ids[_open]).get("desc_key", "")))
	var font: Font = ThemeDB.fallback_font
	var inner: float = TIP_WIDTH - TIP_PAD * 2.0
	var desc_h: float = font.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, inner, TIP_DESC_FONT, TIP_DESC_LINES).y
	var height: float = TIP_PAD * 2.0 + TIP_NAME_FONT * 1.3 + TIP_RARITY_FONT * 1.5 + desc_h + TIP_HINT_FONT * 1.8
	var icon: Rect2 = icon_rect(_open)
	var x: float = clampf(icon.get_center().x - TIP_WIDTH * 0.5, TIP_GAP, vp.x - TIP_WIDTH - TIP_GAP)
	var y: float = area.position.y - TIP_GAP - height
	if area.get_center().y < vp.y * 0.5:
		y = area.end.y + TIP_GAP
	return Rect2(x, y, TIP_WIDTH, height)


func _draw_tooltip(index: int) -> void:
	var info: Dictionary = RelicRegistry.info(_ids[index])
	var rect: Rect2 = _tooltip_rect()
	var font: Font = HudSkin.font()
	var border: Color = NEGATIVE_COLOR if is_negative(info) else rarity_color(str(info.get("rarity", "")))
	HudSkin.panel(self, rect, [0.0, HudSkin.BUTTON_CUT_MAX, 0.0, HudSkin.BUTTON_CUT_MAX], TIP_BACK, border, TIP_BORDER)
	var x: float = rect.position.x + TIP_PAD
	var inner: float = rect.size.x - TIP_PAD * 2.0
	var y: float = rect.position.y + TIP_PAD + TIP_NAME_FONT
	HudSkin.text(self, Vector2(x, y), tr(str(info.get("name_key", _ids[index]))), TIP_NAME_FONT, TIP_NAME_COLOR, HORIZONTAL_ALIGNMENT_LEFT, inner, true)
	y += TIP_RARITY_FONT * 1.5
	HudSkin.text(self, Vector2(x, y), rarity_line(info), TIP_RARITY_FONT, border.lightened(0.15), HORIZONTAL_ALIGNMENT_LEFT, inner)
	y += TIP_DESC_FONT * 1.4
	var desc: String = tr(str(info.get("desc_key", "")))
	draw_multiline_string_outline(font, Vector2(x, y), desc, HORIZONTAL_ALIGNMENT_LEFT, inner, TIP_DESC_FONT, TIP_DESC_LINES, HudSkin.TEXT_OUTLINE_PX, HudSkin.TEXT_OUTLINE)
	draw_multiline_string(font, Vector2(x, y), desc, HORIZONTAL_ALIGNMENT_LEFT, inner, TIP_DESC_FONT, TIP_DESC_LINES, TIP_DESC_COLOR)
	HudSkin.text(self, Vector2(x, rect.end.y - TIP_PAD * 0.8), tr(TEXT_TAP_CLOSE), TIP_HINT_FONT, TIP_HINT_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, inner)

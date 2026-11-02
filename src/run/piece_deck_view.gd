class_name PieceDeckView
extends Node2D
## Piece deck screen (Story 034, Part C): shown in phase PIECE_DECK, opened by the "Bộ mảnh" button of the
## world map / chapter map HUD ([method GameFlow.open_piece_deck]). Title band: "BỘ MẢNH" centred, the
## shape-removal token count at the right. Middle: the run's shapes as a grid of tiles
## (ScreenLayout.piece_deck_tile_rects, every tile well above 64 px), one per row of
## [method GameFlow.get_piece_deck_rows]: the shape drawn like on the field ([PieceDraw]), its name, its
## drop chance ("Rơi 12,5%", one decimal, the row's `percent`) and its mult as dots (the row's `dots`
## filled, out of ceil(PieceDeckConfig.mult_max)). A removed shape is dimmed and struck through ("Đã xóa"
## instead of the chance); a run-only shape carries a "Hình mới" tag.
## Touch: a tap on a tile (on release; a press that moves past TAP_SLOP is cancelled) selects it — it rises
## with a gold outline — and the bottom-right "Xóa hình (còn N token)" button appears (N =
## [method GameFlow.get_shape_removals]). When the row's `can_remove` is false the button is dimmed and
## tr(row.reason) is shown right above it (`piece_deck.reason.min_shapes` formatted with
## PieceDeckConfig.min_shapes); the enabled button calls [method GameFlow.remove_shape]. Bottom-left "Đóng"
## -> [method GameFlow.close_piece_deck]. The line between the bottom buttons shows a hint or the last
## result. Enter / Keypad Enter / Space close the screen (DEV convenience).
## Child of GameFlow (reads it through [member flow_path]); draws and takes input only in phase PIECE_DECK;
## owns no run state and reads only the GameFlow API. Input dedup as in ShopView (emulated copies — device ==
## InputEvent.DEVICE_ID_EMULATION — are consumed but never act). Placeholder art drawn in code; every string
## is a TEXT_* key (or a row's reason key) through tr(). Layout / presentation constants only, no gameplay
## numbers.
## Story 041: one line under the shape grid (left part of the band above the bottom buttons, clear of the right-aligned
## refusal line) states the Odd Block rule from field_drops.json `odd_blocks`: chance x 100 and the size range
## (min_cells .. largest weighted size up to size_max), "not learned, not forgotten"; or "no Odd Blocks" when the
## chance is 0 / no size has weight. The screen opens outside a match, so it states the rule, not a per-arena value.

## 2026-10-31 (user: "chưa apply hud cho toàn bộ màn"): the dark game skin (HudSkin) — screen background, card
## tiles, outlined text. Light text colours for the dark field; no red (red = enemy telegraph): refusals and the
## removed strike use the skin's ember orange.
const BACK_COLOR: Color = HudSkin.SCREEN_BG
const TITLE_COLOR: Color = HudSkin.IVORY
const HEADER_COLOR: Color = HudSkin.TEXT_DIM
const TILE_BACK: Color = HudSkin.CARD_FILL
const TILE_BORDER_COLOR: Color = HudSkin.CARD_LINE
const SELECTED_OUTLINE: Color = HudSkin.GRID_LIGHT
const PRESSED_OUTLINE: Color = HudSkin.IVORY
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.45)
const NAME_COLOR: Color = HudSkin.TEXT
const PERCENT_COLOR: Color = Color("8FC3E8")
const REMOVED_TEXT_COLOR: Color = Color("E08A4E")
## Shape squares: default-pool shapes and run-only shapes.
const SHAPE_FILL: Color = Color(0.32, 0.55, 0.85)
const RUN_ONLY_FILL: Color = Color(0.85, 0.6, 0.15)
const SHAPE_OUTLINE: Color = Color(0.04, 0.05, 0.08, 0.85)
const RUN_ONLY_TAG_COLOR: Color = HudSkin.GRID_LIGHT
const STRIKE_COLOR: Color = Color("E08A4E")
const DOT_ON: Color = HudSkin.GRID_LIGHT
const DOT_OFF: Color = Color("4A4458")
const MESSAGE_COLOR: Color = HudSkin.TEXT
const MESSAGE_BAD_COLOR: Color = Color("E08A4E")

const TILE_BORDER: float = 4.0
const SELECTED_BORDER: float = 8.0
const STRIKE_WIDTH: float = 5.0
const TITLE_FONT_SIZE: int = 44
const HEADER_FONT_SIZE: int = 24
const NAME_FONT_SIZE: int = 22
const PERCENT_FONT_SIZE: int = 20
const TAG_FONT_SIZE: int = 16
const BUTTON_FONT_SIZE: int = 28
const MESSAGE_FONT_SIZE: int = 22
const MIN_FIT_FONT_SIZE: int = 12
## A press that moves farther than this (px) is not a tap.
const TAP_SLOP: float = 16.0
## Tile layout as shares of the tile: inner padding (of the width), the shape area (top and height), the
## baselines of the run-only tag, the name and the chance line, the centre of the dot row.
const PAD_RATIO: float = 0.08
const SHAPE_TOP_RATIO: float = 0.17
const SHAPE_HEIGHT_RATIO: float = 0.42
const TAG_BASELINE: float = 0.12
const NAME_BASELINE: float = 0.7
const PERCENT_BASELINE: float = 0.82
const DOTS_CENTER: float = 0.92
## Largest square of a drawn shape as a share of the tile width (a single cell stays small).
const SHAPE_MAX_UNIT_RATIO: float = 0.2
## Dot radius as a share of the tile width (capped by DOT_MAX_RADIUS) and the gap between dots in radii.
const DOT_RADIUS_RATIO: float = 0.035
const DOT_MAX_RADIUS: float = 7.0
const DOT_GAP_RADII: float = 1.2
## Half-diagonal of a mult diamond in dot radii (a diamond reads smaller than a disc of the same radius).
const DOT_DIAMOND_RATIO: float = 1.2

const TEXT_TITLE: String = "ui.piece_deck.title"
## "Token Xóa hình: %d".
const TEXT_TOKENS: String = "ui.piece_deck.tokens"
## "Rơi %s%%" (the number already formatted with one decimal).
const TEXT_PERCENT: String = "ui.piece_deck.percent"
## "Xóa hình (còn %d token)".
const TEXT_REMOVE: String = "ui.piece_deck.remove"
const TEXT_CLOSE: String = "ui.piece_deck.close"
const TEXT_RUN_ONLY: String = "ui.piece_deck.run_only"
const TEXT_REMOVED_TAG: String = "ui.piece_deck.removed_tag"
const TEXT_HINT: String = "ui.piece_deck.hint"
## "Đã xóa: %s".
const TEXT_REMOVED_MSG: String = "ui.piece_deck.removed_msg"
## Shared: the locale's decimal separator (Story 031).
const TEXT_DECIMAL_POINT: String = "ui.world.decimal_point"
## Story 041: "%s: khoảng %d%% khối rơi, %d–%d ô tùy sân (...)" (name, percent, smallest, largest size) and "Không có %s".
const TEXT_ODD_RULE: String = "ui.piece_deck.odd_rule"
const TEXT_ODD_NONE: String = "ui.piece_deck.odd_none"
const ODD_NAME_KEY: String = "piece.odd.name"
const ODD_RULE_COLOR: Color = Color("D99AD2")
const ODD_RULE_FONT_SIZE: int = 20
## Odd sparkle mark before the line (radius px) and the gap between the line and the refusal line (share of width).
const ODD_RULE_MARK_RADIUS: float = 8.0
const ODD_RULE_GAP_RATIO: float = 0.012
## Target-half size used to state the rule's largest size (big enough that max_size_for clamps at size_max).
const ODD_RULE_ANY_ARENA_CELLS: int = 1 << 20

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow = null
## Id of the selected shape ("" = none).
var _selected: String = ""
## The press that may become a tap: the shape under it and where it began ("" / INF = none).
var _press_id: String = ""
var _press_pos: Vector2 = Vector2.INF
## Message line between the bottom buttons: a ready string and whether it is a refusal (red).
var _message: String = ""
var _message_bad: bool = false
## Story 041: the odd_blocks config of field_drops.json (loaded on first use).
var _odd_config: OddBlockConfig = null


func _ready() -> void:
	# 2026-11-01: crisp pixel frames (PixelFrame) and the menu font (MenuFont) on every menu screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flow = get_node_or_null(flow_path) as GameFlow


func _process(_delta: float) -> void:
	if not _is_active():
		_reset()
		queue_redraw()  # clear the last frame (see TitleView)
		return
	queue_redraw()


## Id of the selected shape ("" when none) — for tests and captures.
func get_selected() -> String:
	return _selected


## Selects shape [param id] as a tap would ("" clears) — for tests and captures.
func select_shape(id: String) -> void:
	_selected = id
	_message = ""
	_message_bad = false


## True while the screen is shown (phase PIECE_DECK of a run).
func is_open() -> bool:
	return _is_active()


## Story 041: the Odd Block rule line (translated): chance %, size range, or the "no Odd Blocks" line.
func odd_rule_text() -> String:
	var cfg: OddBlockConfig = _odd()
	var sizes: Array[int] = cfg.allowed_sizes(ODD_RULE_ANY_ARENA_CELLS)
	if cfg.chance <= 0.0 or sizes.is_empty():
		return tr(TEXT_ODD_NONE) % tr(ODD_NAME_KEY)
	return tr(TEXT_ODD_RULE) % [tr(ODD_NAME_KEY), roundi(cfg.chance * 100.0), sizes.min(), sizes.max()]


# Story 041: the odd block tuning of field_drops.json (built-in disabled default when the file is missing).
func _odd() -> OddBlockConfig:
	if _odd_config == null:
		var drops: FieldDropsConfig = FieldDropsConfig.load_from_file()
		_odd_config = drops.odd if drops != null else OddBlockConfig.new()
	return _odd_config


## Story 034: the drop chance [param percent] with one decimal and the locale's separator ("12,5").
func format_percent(percent: float) -> String:
	return ("%.1f" % percent).replace(".", tr(TEXT_DECIMAL_POINT))


## Story 034: the translated refusal text of a row (empty when it can be removed); the min_shapes reason
## carries PieceDeckConfig.min_shapes.
func reason_text(row: Dictionary) -> String:
	if bool(row.get("can_remove", false)):
		return ""
	var key: String = str(row.get("reason", ""))
	if key.is_empty():
		return ""
	if key == PieceDeck.REASON_MIN_SHAPES:
		return tr(key) % _flow.get_piece_deck_config().min_shapes
	return tr(key)


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.PIECE_DECK and _flow.get_run() != null


func _reset() -> void:
	_selected = ""
	_press_id = ""
	_press_pos = Vector2.INF
	_message = ""
	_message_bad = false


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			_flow.close_piece_deck()
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var vp: Vector2 = get_viewport_rect().size
	var press: Vector2 = _pointer(event, true)
	var release: Vector2 = _pointer(event, false)
	if press != Vector2.INF:
		_on_press(press, vp)
	elif release != Vector2.INF:
		_on_release()
	elif not _press_id.is_empty() and _drag_position(event).distance_to(_press_pos) > TAP_SLOP:
		_press_id = ""  # moved off: not a tap


# A real press: the buttons act at once; a tile waits for its release.
func _on_press(pos: Vector2, vp: Vector2) -> void:
	if ScreenLayout.shop_leave_rect(vp).has_point(pos):
		_flow.close_piece_deck()
		return
	if not _selected.is_empty() and ScreenLayout.shop_buy_rect(vp).has_point(pos):
		_remove_selected()
		return
	var id: String = _shape_at(pos, vp)
	if not id.is_empty():
		_press_id = id
		_press_pos = pos


func _on_release() -> void:
	var id: String = _press_id
	_press_id = ""
	_press_pos = Vector2.INF
	if not id.is_empty():
		select_shape(id)


func _remove_selected() -> void:
	var row: Dictionary = _row(_selected)
	if row.is_empty() or not bool(row.get("can_remove", false)):
		return  # the dimmed button already shows the reason
	var shape_name: String = str(row.get("name", _selected))
	if _flow.remove_shape(_selected):
		_selected = ""
		_message = tr(TEXT_REMOVED_MSG) % shape_name
		_message_bad = false
	else:
		_message = reason_text(_row(_selected))
		_message_bad = true


# Shape id under [param pos] ("" when none). Touch areas include the lift of a raised tile.
func _shape_at(pos: Vector2, vp: Vector2) -> String:
	var rows: Array[Dictionary] = _flow.get_piece_deck_rows()
	var rects: Array[Rect2] = ScreenLayout.piece_deck_tile_rects(vp, rows.size())
	var lift: float = ScreenLayout.piece_deck_tile_raise(vp)
	for i: int in rects.size():
		var area := Rect2(rects[i].position.x, rects[i].position.y - lift, rects[i].size.x, rects[i].size.y + lift)
		if area.has_point(pos):
			return str(rows[i].get("id", ""))
	return ""


func _row(id: String) -> Dictionary:
	for row: Dictionary in _flow.get_piece_deck_rows():
		if str(row.get("id", "")) == id:
			return row
	return {}


# Press (pressed = true) or release position of a left mouse button / touch; Vector2.INF otherwise.
func _pointer(event: InputEvent, pressed: bool) -> Vector2:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed == pressed:
			return button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed == pressed:
			return touch.position
	return Vector2.INF


func _drag_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return _press_pos


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	var band: Rect2 = ScreenLayout.floor_title_rect(vp)
	HudSkin.screen_background(self, Rect2(Vector2.ZERO, vp), clampf(band.end.y / vp.y, 0.0, 1.0) if vp.y > 0.0 else 0.0)
	_draw_header(vp)
	var rows: Array[Dictionary] = _flow.get_piece_deck_rows()
	var rects: Array[Rect2] = ScreenLayout.piece_deck_tile_rects(vp, rows.size())
	var dot_count: int = ceili(_flow.get_piece_deck_config().mult_max)
	var selected_row: Dictionary = {}
	for i: int in rects.size():
		var id: String = str(rows[i].get("id", ""))
		if id == _selected:
			selected_row = rows[i]
			continue  # drawn last, on top of its neighbours
		_draw_tile(vp, rects[i], rows[i], false, id == _press_id, dot_count)
	for i: int in rects.size():
		if str(rows[i].get("id", "")) == _selected:
			_draw_tile(vp, rects[i], rows[i], true, false, dot_count)
	var close: Rect2 = ScreenLayout.shop_leave_rect(vp)
	var close_text: String = tr(TEXT_CLOSE)
	UiButtons.draw_button(self, close, close_text, UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, close), true, _fit(close_text, close.size.x * 0.9, BUTTON_FONT_SIZE))
	if not selected_row.is_empty():
		_draw_remove_button(vp, selected_row)
	_draw_message(vp)
	_draw_odd_rule(vp)


# Story 041: the odd rule line under the grid: the left part of the refusal band (the refusal line is right-aligned
# with the bottom-right button), a sparkle mark then the text in dark magenta.
func _draw_odd_rule(vp: Vector2) -> void:
	var reason: Rect2 = ScreenLayout.piece_deck_reason_rect(vp)
	var left: float = vp.x * ScreenLayout.MARGIN_RATIO
	var right: float = reason.position.x - vp.x * ODD_RULE_GAP_RATIO
	if right - left <= ODD_RULE_MARK_RADIUS * 4.0:
		return
	var text: String = odd_rule_text()
	var text_left: float = left + ODD_RULE_MARK_RADIUS * 3.0
	var size: int = _fit(text, right - text_left, ODD_RULE_FONT_SIZE)
	var y: float = reason.get_center().y
	PieceDraw.draw_odd_mark(self, Vector2(left + ODD_RULE_MARK_RADIUS, y), ODD_RULE_MARK_RADIUS)
	MenuFont.text(self, Vector2(text_left, y + size * 0.35), text, size, ODD_RULE_COLOR, HORIZONTAL_ALIGNMENT_LEFT, right - text_left)


# Title band: "BỘ MẢNH" centred, the shape-removal tokens at the right.
func _draw_header(vp: Vector2) -> void:
	var band: Rect2 = ScreenLayout.floor_title_rect(vp)
	var title: String = tr(TEXT_TITLE)
	_text(band, band.get_center().y + TITLE_FONT_SIZE * 0.35, title, _fit(title, vp.x * 0.4, TITLE_FONT_SIZE, true), TITLE_COLOR, true)
	var label: Rect2 = ScreenLayout.floor_hero_label_rect(vp)
	var tokens: String = tr(TEXT_TOKENS) % _flow.get_shape_removals()
	MenuFont.text(self, Vector2(label.position.x, label.get_center().y + HEADER_FONT_SIZE * 0.35), tokens, _fit(tokens, label.size.x, HEADER_FONT_SIZE), HEADER_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, label.size.x)


# One shape tile at rest rect [param base]: raised with a gold outline when selected, dimmed and struck
# through when removed (or not in the deck), the run-only tag on top.
func _draw_tile(vp: Vector2, base: Rect2, row: Dictionary, selected: bool, pressed: bool, dot_count: int) -> void:
	var removed: bool = bool(row.get("removed", false))
	var dots: int = int(row.get("dots", 0))
	var dim: bool = removed or dots <= 0
	var run_only: bool = bool(row.get("run_only", false))
	var rect: Rect2 = base
	if selected:
		draw_rect(Rect2(base.position + Vector2(5.0, 5.0), base.size), SHADOW_COLOR)
		rect.position.y -= ScreenLayout.piece_deck_tile_raise(vp)
	var back: Color = TILE_BACK
	var border: Color = TILE_BORDER_COLOR
	var width: float = HudSkin.PANEL_LINE_WIDTH
	if selected:
		border = SELECTED_OUTLINE
		width = TILE_BORDER
	elif pressed:
		border = PRESSED_OUTLINE
		width = TILE_BORDER
	var fill: Color = RUN_ONLY_FILL if run_only else SHAPE_FILL
	var outline: Color = SHAPE_OUTLINE
	var name_color: Color = NAME_COLOR
	if dim:
		back.a *= UiButtons.DIM_ALPHA
		fill.a *= UiButtons.DIM_ALPHA
		outline.a *= UiButtons.DIM_ALPHA
		name_color.a *= UiButtons.DIM_ALPHA
		if not selected:
			border.a *= UiButtons.DIM_ALPHA
	# 2026-10-31: a HudSkin card face (CARD_FILL, cut top-right) instead of the beige tile.
	HudSkin.panel(self, rect, [0.0, HudSkin.button_cut(rect), 0.0, 0.0], back, border, width)
	var pad: float = rect.size.x * PAD_RATIO
	var inner: float = rect.size.x - pad * 2.0
	if run_only:
		var tag: String = tr(TEXT_RUN_ONLY)
		var tag_color: Color = RUN_ONLY_TAG_COLOR
		if dim:
			tag_color.a *= UiButtons.DIM_ALPHA
		_text(rect, rect.position.y + rect.size.y * TAG_BASELINE, tag, _fit(tag, inner, TAG_FONT_SIZE), tag_color)
	var area := Rect2(rect.position.x + pad, rect.position.y + rect.size.y * SHAPE_TOP_RATIO, inner, rect.size.y * SHAPE_HEIGHT_RATIO)
	var piece: Piece = Piece.make(str(row.get("id", "")), _cells(row))
	PieceDraw.draw_shape(self, piece, area, fill, outline, rect.size.x * SHAPE_MAX_UNIT_RATIO)
	if removed:
		var shape: Rect2 = PieceDraw.shape_rect(piece, area, rect.size.x * SHAPE_MAX_UNIT_RATIO).grow(pad * 0.5)
		draw_line(Vector2(shape.position.x, shape.end.y), Vector2(shape.end.x, shape.position.y), STRIKE_COLOR, STRIKE_WIDTH)
	var shape_name: String = str(row.get("name", ""))
	_text(rect, rect.position.y + rect.size.y * NAME_BASELINE, shape_name, _fit(shape_name, inner, NAME_FONT_SIZE), name_color)
	var line: String
	var line_color: Color
	if removed:
		line = tr(TEXT_REMOVED_TAG)
		line_color = REMOVED_TEXT_COLOR
	else:
		line = tr(TEXT_PERCENT) % format_percent(float(row.get("percent", 0.0)))
		line_color = PERCENT_COLOR
		if dim:
			line_color.a *= UiButtons.DIM_ALPHA
	_text(rect, rect.position.y + rect.size.y * PERCENT_BASELINE, line, _fit(line, inner, PERCENT_FONT_SIZE), line_color)
	_draw_dots(rect, dots, dot_count, dim)


# The mult as a row of [param total] small diamonds (no circles in the UI), [param filled] of them lit, centred under the
# chance line.
func _draw_dots(rect: Rect2, filled: int, total: int, dim: bool) -> void:
	var count: int = maxi(total, filled)
	if count <= 0:
		return
	var radius: float = minf(rect.size.x * DOT_RADIUS_RATIO, DOT_MAX_RADIUS)
	var step: float = radius * (2.0 + DOT_GAP_RADII)
	var left: float = rect.get_center().x - step * (count - 1) * 0.5
	var y: float = rect.position.y + rect.size.y * DOTS_CENTER
	for i: int in count:
		var color: Color = DOT_ON if i < filled else DOT_OFF
		if dim:
			color.a *= UiButtons.DIM_ALPHA
		HudSkin.diamond(self, Vector2(left + step * i, y), radius * DOT_DIAMOND_RATIO, color, Color.TRANSPARENT, 0.0)


# Bottom-right "Xóa hình (còn N token)": DANGER when the selected row can go, dimmed with its reason
# right above it otherwise.
func _draw_remove_button(vp: Vector2, row: Dictionary) -> void:
	var button: Rect2 = ScreenLayout.shop_buy_rect(vp)
	var ok: bool = bool(row.get("can_remove", false))
	var label: String = tr(TEXT_REMOVE) % _flow.get_shape_removals()
	UiButtons.draw_button(self, button, label, UiButtons.Style.DANGER, ok and UiButtons.is_pressed_at(self, button), ok, _fit(label, button.size.x * 0.9, BUTTON_FONT_SIZE))
	if ok:
		return
	var reason: String = reason_text(row)
	if reason.is_empty():
		return
	var line: Rect2 = ScreenLayout.piece_deck_reason_rect(vp)
	MenuFont.text(self, Vector2(line.position.x, line.get_center().y + MESSAGE_FONT_SIZE * 0.35), reason, _fit(reason, line.size.x, MESSAGE_FONT_SIZE), MESSAGE_BAD_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, line.size.x)


# The line between the bottom buttons: the last result, else the hint while nothing is selected.
func _draw_message(vp: Vector2) -> void:
	var text: String = _message
	var color: Color = MESSAGE_BAD_COLOR if _message_bad else MESSAGE_COLOR
	if text.is_empty():
		if not _selected.is_empty():
			return
		text = tr(TEXT_HINT)
		color = HEADER_COLOR
	var rect: Rect2 = ScreenLayout.shop_message_rect(vp)
	_text(rect, rect.get_center().y + MESSAGE_FONT_SIZE * 0.35, text, _fit(text, rect.size.x, MESSAGE_FONT_SIZE), color)


# The row's unrotated cells as a typed array (rows may carry a plain Array).
func _cells(row: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Variant in row.get("cells", []):
		if cell is Vector2i:
			cells.append(cell as Vector2i)
	return cells


# Centred HudSkin outlined text over [param rect]'s width at baseline [param y] (Bold when [param bold]).
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, bold: bool = false) -> void:
	MenuFont.text(self, Vector2(rect.position.x, y), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, bold)


# Largest font size <= [param size] (not below MIN_FIT_FONT_SIZE) at which [param text] fits [param width]
# in the HudSkin font (Bold when [param bold]).
func _fit(text: String, width: float, size: int, bold: bool = false) -> int:
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and HudSkin.text_width(text, fitted, bold) > width:
		fitted -= 1
	return fitted

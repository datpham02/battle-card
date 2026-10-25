class_name ChapterMapView
extends Node2D
## Chapter map screen (Story 022, Part A; the node picker that replaced the Story 015 floor
## select): the whole map of the live run as columns left to right ([method GameFlow.get_run_map],
## ScreenLayout.map_column_rects) with one square tile per node (ScreenLayout.map_node_rect). A tile
## shows a code-drawn glyph per node kind (battle: crossed blades; danger: triangle with "!";
## treasure: a chest; rest: a flame; miniboss: a skull; boss: a crown) and the kind's name
## ("node.<kind>.name"). Looks: CLEARED (filled, green check), CURRENT column (bright, tappable,
## pulsing gold outline), LOCKED (dimmed; the boss column keeps its glyph colour so the goal always
## reads). Thin connector lines trace the path taken (cleared node to cleared node) and fan out from
## the last cleared node to every node of the current column. Title band: "Về title" (NEUTRAL,
## ScreenLayout.back_button_rect, hit-tested on ScreenLayout.touch_rect so the touch area is
## >= 96 px -> [method GameFlow.leave_run_keep_save]), the title and "Cột %d/%d" at the right.
## Story 031: the map is the current REGION's (3 columns, tiles 170 px at 720p) and the title reads
## "Tầng N/5 · <vùng>" ([method GameFlow.get_floor], [method GameFlow.get_current_region]; "Ấn Đài"
## at the final match); the header strip under it lists hero, HP, deck size, removal tokens
## and luck. A tap on an available node -> [method GameFlow.choose_node]; every other pointer event
## is swallowed. While an offer is open over the map (a treasure node's, Story 022) RewardView draws
## and takes input above this view, and the title band / header are left to it. When
## [method GameFlow.take_restart_notice] returns text (a pre-v4 save was
## restarted) or [method GameFlow.take_floor_clear_notice] has a notice (Story 031) a banner shows
## it until the first tap. Enter / Keypad Enter / Space pick the first
## available node (DEV convenience, as the other views). Child of GameFlow (reads it through
## [member flow_path]); draws and takes input only in phase MAP; owns no run state. Input dedup as in
## RunHudView (emulated copies — device == InputEvent.DEVICE_ID_EMULATION — are consumed but never
## act). Placeholder art; all strings are TEXT_* keys drawn through tr().

const TITLE_COLOR: Color = Color(0.15, 0.12, 0.1)
const HEADER_COLOR: Color = Color(0.4, 0.35, 0.3)
const TILE_BACK: Color = Color(1.0, 0.97, 0.9)
const TILE_OUTLINE: Color = Color(0.6, 0.52, 0.4)
const TILE_TEXT: Color = Color(0.15, 0.12, 0.1)
const TILE_LOCKED_BACK: Color = Color(0.8, 0.78, 0.74)
const TILE_LOCKED_OUTLINE: Color = Color(0.58, 0.56, 0.52)
const TILE_LOCKED_TEXT: Color = Color(0.5, 0.48, 0.45)
const TILE_CLEARED_BACK: Color = Color(0.82, 0.9, 0.8)
const CLEARED_COLOR: Color = Color(0.2, 0.65, 0.3)
const CURRENT_OUTLINE: Color = Color(0.95, 0.72, 0.15)
const PRESSED_OUTLINE: Color = Color(1.0, 0.85, 0.2)
const CONNECTOR_COLOR: Color = Color(0.5, 0.45, 0.4, 0.7)
const CONNECTOR_CURRENT_COLOR: Color = Color(0.95, 0.72, 0.15, 0.9)
const NOTICE_BACK: Color = Color(0.1, 0.09, 0.08, 0.96)
const NOTICE_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const NOTICE_TEXT: Color = Color(0.95, 0.9, 0.78)
const NOTICE_SUB_TEXT: Color = Color(0.75, 0.72, 0.65)
## Glyph colours by kind (locked tiles multiply the alpha by UiButtons.DIM_ALPHA, except the boss).
const GLYPH_BATTLE: Color = Color(0.3, 0.3, 0.38)
const GLYPH_DANGER: Color = Color(0.85, 0.35, 0.15)
const GLYPH_TREASURE: Color = Color(0.72, 0.5, 0.05)
const GLYPH_REST: Color = Color(0.9, 0.45, 0.1)
const GLYPH_MINIBOSS: Color = Color(0.45, 0.2, 0.5)
const GLYPH_BOSS: Color = Color(0.75, 0.15, 0.12)

const OUTLINE_WIDTH: float = 3.0
const STATE_OUTLINE_WIDTH: float = 6.0
const GLYPH_WIDTH: float = 5.0
const MARK_WIDTH: float = 6.0
const CONNECTOR_WIDTH: float = 3.0
const TITLE_FONT_SIZE: int = 44
const COLUMN_FONT_SIZE: int = 26
const HEADER_FONT_SIZE: int = 22
## Story 023: the chapter intro line (intro_key) shown in the header strip while the run is still at
## column 0; the summary line moves to the strip's top row to make room.
const INTRO_FONT_SIZE: int = 20
const INTRO_MIN_FONT_SIZE: int = 14
const INTRO_COLOR: Color = Color(0.5, 0.42, 0.3)
const HEADER_TOP_BASELINE: float = 0.4
const HEADER_INTRO_BASELINE: float = 0.88
const TILE_FONT_SIZE: int = 20
const BUTTON_FONT_SIZE: int = 24
## Story 031: the back button text shrinks to fit, not below this size; inset per side (pixels).
const BACK_MIN_FONT_SIZE: int = 14
const BACK_TEXT_INSET: float = 6.0
const NOTICE_FONT_SIZE: int = 30
const NOTICE_SUB_FONT_SIZE: int = 22
const ARC_POINTS: int = 16
## Pulse of the current column's outline: period and the alpha it dips to.
const PULSE_PERIOD_SEC: float = 1.2
const PULSE_MIN_ALPHA: float = 0.45
## Inside a tile, as shares of its side: the glyph box (centre y, half size) and the name baseline.
const GLYPH_CENTER_Y: float = 0.42
const GLYPH_HALF: float = 0.22
const NAME_BASELINE: float = 0.88
## Check mark polyline as shares of the tile side (top-right corner).
const CHECK_POINTS: Array[Vector2] = [Vector2(0.7, 0.16), Vector2(0.78, 0.25), Vector2(0.9, 0.08)]
## Notice banner baselines as shares of its height.
const NOTICE_BASELINE: float = 0.45
const NOTICE_SUB_BASELINE: float = 0.8
## Separator between the header strip's parts.
const HEADER_SEPARATOR: String = " · "
## Node kinds as written in chapters.json / the map (ChapterMapGen).
const KIND_BATTLE: String = "battle"
const KIND_DANGER: String = "danger"
const KIND_TREASURE: String = "treasure"
const KIND_REST: String = "rest"
const KIND_MINIBOSS: String = "miniboss"
const KIND_BOSS: String = "boss"
## Format of a node kind's name key ("node.battle.name" ...; the CSV has a row per kind).
const NODE_NAME_KEY_FORMAT: String = "node.%s.name"

## "Cột %d/%d": the current column (1-based) and the column count.
const TEXT_COLUMN: String = "ui.map.column"
## "HP %d/%d" and "Bộ: %d lá" in the header strip.
const TEXT_HP: String = "ui.map.hp"
const TEXT_DECK: String = "ui.map.deck"
## "Token bỏ lá: %d" and "May mắn %d".
const TEXT_REMOVAL_TOKENS: String = "ui.map.removal_tokens"
const TEXT_LUCK: String = "ui.map.luck"
## The back button: to the title, the run stays saved.
const TEXT_BACK: String = "ui.map.back"
## Story 031: the title "Tầng %d/%d · %s" (1-based floor, floor count, region name) and the final
## match's name (shared with WorldMapView).
const TEXT_FLOOR_TITLE: String = "ui.map.floor_title"
const TEXT_FINAL_NAME: String = "ui.world.final_name"
## Second line of the restart notice banner ("Chạm để đóng").
const TEXT_NOTICE_DISMISS: String = "ui.map.notice_dismiss"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow = null
## Story 032: owned-relic strip along the bottom band (tap an icon for its card).
var _strip: RelicStrip = null
## Restart notice text shown in the banner until the first tap ("" = none).
var _notice: String = ""


func _ready() -> void:
	_flow = get_node_or_null(flow_path) as GameFlow
	_strip = RelicStrip.new()
	add_child(_strip)


func _process(_delta: float) -> void:
	_sync_strip()
	if not _is_active():
		_notice = ""
		queue_redraw()  # clear the last frame (see TitleView)
		return
	if _notice.is_empty():
		_notice = _flow.take_restart_notice()
	if _notice.is_empty():
		# Story 031: after the last region boss the run goes straight to the final match's map, so
		# the floor-clear banner ("Ấn Đài — hồi X máu") shows here (WorldMapView shows the others).
		var clear: Dictionary = _flow.take_floor_clear_notice()
		if not clear.is_empty():
			_notice = WorldMapView.floor_clear_text(clear)
	queue_redraw()


## Translated display name of node kind [param kind] ("node.<kind>.name").
static func kind_name(kind: String) -> String:
	return TranslationServer.translate(NODE_NAME_KEY_FORMAT % kind)


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.MAP and _flow.get_run() != null


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if not _notice.is_empty():
				_notice = ""
				return
			var available: Array[Dictionary] = _flow.get_available_nodes()
			if not available.is_empty():
				_flow.choose_node(int(available[0].get("node_index", 0)))
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device != InputEvent.DEVICE_ID_EMULATION and _strip.visible and _strip.handle_input(event):
		return
	var pos: Vector2 = _press_position(event)
	if pos == Vector2.INF or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if not _notice.is_empty():
		_notice = ""
		return
	var vp: Vector2 = get_viewport_rect().size
	if ScreenLayout.touch_rect(ScreenLayout.back_button_rect(vp)).has_point(pos):
		_flow.leave_run_keep_save()
		return
	var map: Array[Dictionary] = _flow.get_run_map()
	var current: int = _flow.get_current_column()
	if current < 0 or current >= map.size():
		return
	var columns: Array[Rect2] = ScreenLayout.map_column_rects(vp, map.size())
	var nodes: Array = map[current].get("nodes", [])
	for node: Dictionary in _flow.get_available_nodes():
		var i: int = int(node.get("node_index", -1))
		if i >= 0 and i < nodes.size() and ScreenLayout.map_node_rect(columns[current], i, nodes.size()).has_point(pos):
			_flow.choose_node(i)
			return


# Position of a left mouse press or a touch press; Vector2.INF for any other event.
func _press_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			return button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			return touch.position
	return Vector2.INF


# --- State --------------------------------------------------------------------


# Index of the cleared node of column [param column] (-1 when none).
func _cleared_index(column: int) -> int:
	for c: Variant in _flow.get_cleared_nodes():
		if int((c as Dictionary).get("column", -1)) == column:
			return int((c as Dictionary).get("node_index", -1))
	return -1


# Max HP of the run's character (CharacterConfig).
func _max_hp(run: RunSession) -> float:
	return float(_flow.get_characters().get_character(run.character_id).get("max_hp", 1.0))


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	var run: RunSession = _flow.get_run()
	var map: Array[Dictionary] = _flow.get_run_map()
	var current: int = _flow.get_current_column()
	# While an offer is open over the map (a treasure node, a resumed offer) RewardView owns the
	# title band: only the tiles stay under its dim.
	if _flow.get_pending_reward().is_empty():
		_draw_header(vp, run, map.size(), current)
	var columns: Array[Rect2] = ScreenLayout.map_column_rects(vp, map.size())
	_draw_connectors(columns, map, current)
	var pulse: float = _pulse_alpha()
	for ci: int in map.size():
		var nodes: Array = map[ci].get("nodes", [])
		var cleared_index: int = _cleared_index(ci)
		for ni: int in nodes.size():
			var rect: Rect2 = ScreenLayout.map_node_rect(columns[ci], ni, nodes.size())
			_draw_tile(rect, str((nodes[ni] as Dictionary).get("kind", "")), ci, current, ni == cleared_index, pulse)
	if not _notice.is_empty():
		_draw_notice(vp)


# Title band (back button, chapter name, "Cột x/y") and the header strip (hero · HP · deck · tokens · luck).
func _draw_header(vp: Vector2, run: RunSession, column_count: int, current: int) -> void:
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	_text(title, title.get_center().y + TITLE_FONT_SIZE * 0.35, _title_text(), TITLE_FONT_SIZE, TITLE_COLOR)
	var back: Rect2 = ScreenLayout.back_button_rect(vp)
	var back_text: String = tr(TEXT_BACK)
	UiButtons.draw_button(self, back, back_text, UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, ScreenLayout.touch_rect(back)), true, _back_font_size(back_text, back.size.x), OUTLINE_WIDTH)
	var column_rect: Rect2 = ScreenLayout.floor_hero_label_rect(vp)
	var column_text: String = tr(TEXT_COLUMN) % [mini(current + 1, column_count), column_count]
	draw_string(ThemeDB.fallback_font, Vector2(column_rect.position.x, column_rect.get_center().y + COLUMN_FONT_SIZE * 0.35), column_text, HORIZONTAL_ALIGNMENT_RIGHT, column_rect.size.x, COLUMN_FONT_SIZE, HEADER_COLOR)
	var character: Dictionary = _flow.get_characters().get_character(run.character_id)
	var max_hp: float = _max_hp(run)
	var hp: float = max_hp if run.hp < 0.0 else minf(run.hp, max_hp)
	var parts: Array[String] = [
		tr(str(character.get("name_key", run.character_id))),
		tr(TEXT_HP) % [ceili(hp), ceili(max_hp)],
		tr(TEXT_DECK) % run.deck.size(),
		tr(TEXT_REMOVAL_TOKENS) % _flow.get_removal_tokens(),
		tr(TEXT_LUCK) % roundi(_flow.get_luck()),
	]
	var header: Rect2 = ScreenLayout.map_header_rect(vp)
	var region_index: int = _flow.get_config().region_index(_flow.get_current_region())
	var intro_key: String = _flow.get_config().chapter_text_key(region_index, "intro") if current == 0 and region_index >= 0 else ""
	if intro_key.is_empty():
		_text(header, header.get_center().y + HEADER_FONT_SIZE * 0.35, HEADER_SEPARATOR.join(parts), HEADER_FONT_SIZE, HEADER_COLOR)
		return
	_text(header, header.position.y + header.size.y * HEADER_TOP_BASELINE, HEADER_SEPARATOR.join(parts), HEADER_FONT_SIZE, HEADER_COLOR)
	var intro: String = tr(intro_key)
	var intro_width: float = header.size.x - vp.x * ScreenLayout.MARGIN_RATIO * 2.0
	var font: Font = ThemeDB.fallback_font
	var size: int = INTRO_FONT_SIZE
	while size > INTRO_MIN_FONT_SIZE and font.get_string_size(intro, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x > intro_width:
		size -= 1
	_text(header, header.position.y + header.size.y * HEADER_INTRO_BASELINE, intro, size, INTRO_COLOR)


# Story 031: "Tầng N/5 · <vùng>", or "Ấn Đài" once the run stands at the final match.
func _title_text() -> String:
	var count: int = _flow.get_floor_count()
	if _flow.is_final_floor() or _flow.get_floor() >= count:
		return tr(TEXT_FINAL_NAME)
	return tr(TEXT_FLOOR_TITLE) % [_flow.get_floor() + 1, count, _flow.region_name(_flow.get_current_region())]


# The path through the cleared nodes, then the fan-out from the last cleared node to every node of
# the current column (gold). A column without a cleared node (the first) starts no line.
func _draw_connectors(columns: Array[Rect2], map: Array[Dictionary], current: int) -> void:
	var previous := Vector2.INF
	for ci: int in map.size():
		var nodes: Array = map[ci].get("nodes", [])
		if ci == current:
			if previous != Vector2.INF:
				for ni: int in nodes.size():
					draw_line(previous, ScreenLayout.map_node_rect(columns[ci], ni, nodes.size()).get_center(), CONNECTOR_CURRENT_COLOR, CONNECTOR_WIDTH)
			return
		var cleared_index: int = _cleared_index(ci)
		if cleared_index < 0 or cleared_index >= nodes.size():
			previous = Vector2.INF
			continue
		var center: Vector2 = ScreenLayout.map_node_rect(columns[ci], cleared_index, nodes.size()).get_center()
		if previous != Vector2.INF:
			draw_line(previous, center, CONNECTOR_COLOR, CONNECTOR_WIDTH)
		previous = center


# One node tile: back + outline by state, the kind glyph, the kind name, a check when cleared.
# A passed column's untaken nodes draw like locked ones (dim, not tappable).
func _draw_tile(rect: Rect2, kind: String, column: int, current: int, cleared: bool, pulse: float) -> void:
	var is_current: bool = column == current
	var back: Color = TILE_BACK
	var outline: Color = TILE_OUTLINE
	var width: float = OUTLINE_WIDTH
	var text_color: Color = TILE_TEXT
	var glyph: Color = _glyph_color(kind)
	if cleared:
		back = TILE_CLEARED_BACK
		outline = CLEARED_COLOR
		width = STATE_OUTLINE_WIDTH
	elif is_current:
		outline = PRESSED_OUTLINE if UiButtons.is_pressed_at(self, rect) else CURRENT_OUTLINE
		outline.a = pulse
		width = STATE_OUTLINE_WIDTH
	else:
		back = TILE_LOCKED_BACK
		outline = TILE_LOCKED_OUTLINE
		text_color = TILE_LOCKED_TEXT
		if kind != KIND_BOSS:
			glyph.a *= UiButtons.DIM_ALPHA
	draw_rect(rect, back)
	draw_rect(rect, outline, false, width)
	_draw_glyph(rect, kind, glyph)
	_text(rect, rect.position.y + rect.size.y * NAME_BASELINE, kind_name(kind), TILE_FONT_SIZE, text_color)
	if cleared:
		var points := PackedVector2Array()
		for p: Vector2 in CHECK_POINTS:
			points.append(rect.position + rect.size * p)
		draw_polyline(points, CLEARED_COLOR, MARK_WIDTH)


# Code-drawn glyph of a kind inside the tile's glyph box.
func _draw_glyph(rect: Rect2, kind: String, color: Color) -> void:
	var c := Vector2(rect.get_center().x, rect.position.y + rect.size.y * GLYPH_CENTER_Y)
	var h: float = rect.size.x * GLYPH_HALF
	match kind:
		KIND_BATTLE:
			# Two crossed blades with short thick hilts.
			draw_line(c + Vector2(-h, -h), c + Vector2(h, h), color, GLYPH_WIDTH)
			draw_line(c + Vector2(h, -h), c + Vector2(-h, h), color, GLYPH_WIDTH)
			draw_line(c + Vector2(-h * 0.5, h * 0.5), c + Vector2(-h, h), color, GLYPH_WIDTH * 2.0)
			draw_line(c + Vector2(h * 0.5, h * 0.5), c + Vector2(h, h), color, GLYPH_WIDTH * 2.0)
		KIND_DANGER:
			# Triangle with a "!" (a bar and a dot).
			var tri := PackedVector2Array([c + Vector2(0.0, -h), c + Vector2(h, h * 0.8), c + Vector2(-h, h * 0.8), c + Vector2(0.0, -h)])
			draw_polyline(tri, color, GLYPH_WIDTH)
			draw_line(c + Vector2(0.0, -h * 0.35), c + Vector2(0.0, h * 0.25), color, GLYPH_WIDTH)
			draw_circle(c + Vector2(0.0, h * 0.55), GLYPH_WIDTH * 0.7, color)
		KIND_TREASURE:
			# A chest: body, lid line, clasp.
			draw_rect(Rect2(c + Vector2(-h, -h * 0.5), Vector2(h * 2.0, h * 1.4)), color, false, GLYPH_WIDTH)
			draw_line(c + Vector2(-h, -h * 0.05), c + Vector2(h, -h * 0.05), color, GLYPH_WIDTH)
			draw_rect(Rect2(c + Vector2(-h * 0.18, -h * 0.25), Vector2(h * 0.36, h * 0.4)), color)
		KIND_REST:
			# A flame: an outer teardrop and an inner one.
			draw_polyline(_flame(c, h), color, GLYPH_WIDTH)
			draw_polyline(_flame(c + Vector2(0.0, h * 0.35), h * 0.45), color, GLYPH_WIDTH)
		KIND_MINIBOSS:
			# A skull: head arc, jaw, two eyes.
			draw_arc(c + Vector2(0.0, -h * 0.15), h * 0.8, PI, TAU, ARC_POINTS, color, GLYPH_WIDTH)
			draw_line(c + Vector2(-h * 0.8, -h * 0.15), c + Vector2(-h * 0.5, h * 0.9), color, GLYPH_WIDTH)
			draw_line(c + Vector2(h * 0.8, -h * 0.15), c + Vector2(h * 0.5, h * 0.9), color, GLYPH_WIDTH)
			draw_line(c + Vector2(-h * 0.5, h * 0.9), c + Vector2(h * 0.5, h * 0.9), color, GLYPH_WIDTH)
			draw_circle(c + Vector2(-h * 0.32, -h * 0.1), h * 0.18, color)
			draw_circle(c + Vector2(h * 0.32, -h * 0.1), h * 0.18, color)
		KIND_BOSS:
			# A crown: three points on a base.
			var crown := PackedVector2Array([
				c + Vector2(-h, h * 0.7), c + Vector2(-h, -h * 0.5), c + Vector2(-h * 0.5, h * 0.1),
				c + Vector2(0.0, -h), c + Vector2(h * 0.5, h * 0.1), c + Vector2(h, -h * 0.5),
				c + Vector2(h, h * 0.7), c + Vector2(-h, h * 0.7),
			])
			draw_polyline(crown, color, GLYPH_WIDTH)
		_:
			draw_circle(c, h * 0.5, color)


# Teardrop outline of half-height [param h] around [param c] (tip up): a lower half-circle closed
# by two lines to the tip.
func _flame(c: Vector2, h: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in ARC_POINTS + 1:
		var a: float = PI * i / float(ARC_POINTS)
		points.append(c + Vector2(-cos(a) * h * 0.7, h * 0.4 + sin(a) * h * 0.6))
	points.append(c + Vector2(0.0, -h))
	points.append(points[0])
	return points


func _draw_notice(vp: Vector2) -> void:
	var band: Rect2 = ScreenLayout.map_notice_rect(vp)
	draw_rect(band, NOTICE_BACK)
	draw_rect(band, NOTICE_OUTLINE, false, OUTLINE_WIDTH)
	_text(band, band.position.y + band.size.y * NOTICE_BASELINE, tr(_notice), NOTICE_FONT_SIZE, NOTICE_TEXT)
	_text(band, band.position.y + band.size.y * NOTICE_SUB_BASELINE, tr(TEXT_NOTICE_DISMISS), NOTICE_SUB_FONT_SIZE, NOTICE_SUB_TEXT)


func _glyph_color(kind: String) -> Color:
	match kind:
		KIND_DANGER:
			return GLYPH_DANGER
		KIND_TREASURE:
			return GLYPH_TREASURE
		KIND_REST:
			return GLYPH_REST
		KIND_MINIBOSS:
			return GLYPH_MINIBOSS
		KIND_BOSS:
			return GLYPH_BOSS
	return GLYPH_BATTLE


# Outline alpha of the current column (a slow sine pulse).
func _pulse_alpha() -> float:
	var t: float = fmod(Time.get_ticks_msec() / 1000.0, PULSE_PERIOD_SEC) / PULSE_PERIOD_SEC
	return lerpf(PULSE_MIN_ALPHA, 1.0, 0.5 + 0.5 * sin(t * TAU))


# Centred single-line text at baseline [param y] over the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


# Story 031: the back button's font, shrunk until [param text] fits [param width] minus a small inset
# ("Back to title" is wider than the 128 px button at BUTTON_FONT_SIZE).
func _back_font_size(text: String, width: float) -> int:
	var font: Font = ThemeDB.fallback_font
	var size: int = BUTTON_FONT_SIZE
	while size > BACK_MIN_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x > width - BACK_TEXT_INSET * 2.0:
		size -= 1
	return size


# Story 032: the relic strip shows while this screen is up (nothing covering it); its card closes otherwise.
func _sync_strip() -> void:
	var shown: bool = _is_active() and _flow.get_pending_reward().is_empty() and _notice.is_empty()
	if not shown:
		_strip.close_tooltip()
	_strip.visible = shown
	if shown:
		_strip.area = ScreenLayout.relic_strip_rect(get_viewport_rect().size)
		_strip.set_relics(_flow.get_relics())

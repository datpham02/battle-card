class_name EndingView
extends Node2D
## Ending screen (Story 035, Parts C2 and D): shown in GameFlow phase ENDING after the final match is won.
## Top: the ending title ([code]get_ending()["title_key"][/code]); then its story lines
## ([code]line_keys[/code], 3-5) appear one by one every LINE_REVEAL_SEC; a tap anywhere (or Enter /
## Space) shows them all at once, so the player is never forced to wait. Once every line is shown: the
## run stats ([code]get_ending()["stats"][/code], RunSession.stats_summary shape) in TWO columns at
## STATS_FONT_SIZE (>= RunHudView.SMALL_FONT_SIZE) with no scrolling at 1280x720 — when they do not fit,
## a page button (>= 96 px, bottom-right) flips to page 2 — and the big "Về màn chính" button in the bottom
## half -> [method GameFlow.leave_ending].
## The static helpers [method stat_rows], [method path_text] and [method draw_stats] are shared with the
## defeat panel of RunHudView. Child of GameFlow (reads it through [member flow_path]); owns no run state.
## Input dedup as in PieceDeckView. Every string is a key through tr(); presentation constants only.

const BACK_COLOR: Color = Color(0.08, 0.07, 0.1)
const TITLE_COLOR: Color = Color(1.0, 0.75, 0.2)
const LINE_COLOR: Color = Color(0.95, 0.9, 0.78)
const STATS_LABEL_COLOR: Color = Color(0.75, 0.72, 0.65)
const STATS_VALUE_COLOR: Color = Color(1.0, 1.0, 1.0)
const STATS_RULE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.15)

const TITLE_FONT_SIZE: int = 52
const LINE_FONT_SIZE: int = 28
## Run stats font: never below RunHudView.SMALL_FONT_SIZE (Story 035 D).
const STATS_FONT_SIZE: int = 24
const BUTTON_FONT_SIZE: int = 34
const MIN_FIT_FONT_SIZE: int = 12
## Seconds between two story lines appearing (presentation pacing; a tap skips it).
const LINE_REVEAL_SEC: float = 0.8
## Stats row height in font sizes; gap between the two columns as a share of the block width; the label
## takes this share of a column (the value is right-aligned in the rest).
const STATS_ROW_HEIGHT: float = 1.3
const STATS_COLUMN_GAP_RATIO: float = 0.06
const STATS_LABEL_SHARE: float = 0.62
const STATS_RULE_WIDTH: float = 1.0
## Separator of the region path and the ellipsis of a cut path.
const PATH_SEPARATOR: String = " → "
const ELLIPSIS: String = "…"
## Draw above the battle children of GameFlow.
const DRAW_Z_INDEX: int = 20

const TEXT_LEAVE: String = "ui.ending.leave"
const TEXT_PAGE_NEXT: String = "ui.ending.page_next"
const TEXT_PAGE_PREV: String = "ui.ending.page_prev"
const TEXT_STAT_PATH: String = "ui.stats.path"
const TEXT_STAT_CHARACTER: String = "ui.stats.character"
const TEXT_STAT_TIME: String = "ui.stats.time"
const TEXT_STAT_FLOOR: String = "ui.stats.floor"
const TEXT_STAT_MATCHES_WON: String = "ui.stats.matches_won"
const TEXT_STAT_DAMAGE_DEALT: String = "ui.stats.damage_dealt"
const TEXT_STAT_DAMAGE_TAKEN: String = "ui.stats.damage_taken"
const TEXT_STAT_HITS_TAKEN: String = "ui.stats.hits_taken"
const TEXT_STAT_CASTS: String = "ui.stats.casts"
const TEXT_STAT_JOINS: String = "ui.stats.joins"
const TEXT_STAT_FEATURED: String = "ui.stats.featured"
const TEXT_STAT_SIGNATURES: String = "ui.stats.signatures"
const TEXT_STAT_DECK_SIZE: String = "ui.stats.deck_size"
const TEXT_STAT_HIGHEST_LEVEL: String = "ui.stats.highest_level"
const TEXT_STAT_RELICS: String = "ui.stats.relics"
const TEXT_STAT_FATES: String = "ui.stats.fates"
## "%d / %d" (spared / executed).
const TEXT_STAT_FATES_VALUE: String = "ui.stats.fates_value"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow = null
## Seconds since the screen opened (drives the line reveal).
var _reveal_t: float = 0.0
## True once a tap showed every line at once.
var _all_shown: bool = false
## Stats page shown (0 or 1).
var _page: int = 0


func _ready() -> void:
	_flow = get_node_or_null(flow_path) as GameFlow
	z_index = DRAW_Z_INDEX


func _process(delta: float) -> void:
	if not is_open():
		_reset()
		queue_redraw()  # clear the last frame (see PieceDeckView)
		return
	_reveal_t += delta
	queue_redraw()


## True while the screen is shown (phase ENDING).
func is_open() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.ENDING


## Number of story lines shown now (all of them after a tap).
func get_visible_lines() -> int:
	var count: int = _line_keys().size()
	if _all_shown:
		return count
	return mini(count, floori(_reveal_t / LINE_REVEAL_SEC) + 1)


## True once every line is shown (the stats and the leave button are up).
func is_fully_shown() -> bool:
	return _all_shown or get_visible_lines() >= _line_keys().size() and _reveal_t >= _line_keys().size() * LINE_REVEAL_SEC


## Shows every line, the stats and the button at once (what a tap does) — also for tests and captures.
func show_all() -> void:
	_all_shown = true


## Stats page shown (0-based) — for tests and captures.
func get_page() -> int:
	return _page


## Number of stats pages at the current viewport (1 when everything fits).
func get_page_count() -> int:
	if not is_open():
		return 1
	var stats: Dictionary = _ending().get("stats", {})
	return page_count(ScreenLayout.ending_stats_rect(get_viewport_rect().size), stat_rows(self, stats, _flow).size(), STATS_FONT_SIZE)


func _reset() -> void:
	_reveal_t = 0.0
	_all_shown = false
	_page = 0


func _ending() -> Dictionary:
	return _flow.get_ending() if _flow != null else {}


func _line_keys() -> Array:
	return _ending().get("line_keys", []) if is_open() else []


# --- Shared stats helpers (EndingView and RunHudView's defeat panel) ----------


## Story 035 D: the two-column stats rows of [param stats] (RunSession.stats_summary shape) as
## [label, value] pairs of ready strings, translated through [param node]. The region path is not here
## (it is a full-width line, [method path_text]).
static func stat_rows(node: Node, stats: Dictionary, flow: GameFlow) -> Array:
	var character_id: String = str(stats.get("character", ""))
	var character_name: String = character_id
	if flow != null and not character_id.is_empty():
		character_name = node.tr(str(flow.get_characters().get_character(character_id).get("name_key", character_id)))
	var spared: int = 0
	var executed: int = 0
	for fate: Variant in stats.get("fates", []):
		if fate is Dictionary:
			var kind: String = str((fate as Dictionary).get("fate", ""))
			spared += 1 if kind == "spare" else 0
			executed += 1 if kind == "execute" else 0
	var relics: Variant = stats.get("relics", [])
	return [
		[node.tr(TEXT_STAT_CHARACTER), character_name],
		[node.tr(TEXT_STAT_TIME), elapsed_text(float(stats.get("elapsed_sec", 0.0)))],
		[node.tr(TEXT_STAT_FLOOR), str(int(stats.get("floor_reached", 0)))],
		[node.tr(TEXT_STAT_MATCHES_WON), str(int(stats.get("matches_won", 0)))],
		[node.tr(TEXT_STAT_DAMAGE_DEALT), str(roundi(float(stats.get("damage_dealt", 0.0))))],
		[node.tr(TEXT_STAT_DAMAGE_TAKEN), str(roundi(float(stats.get("damage_taken", 0.0))))],
		[node.tr(TEXT_STAT_HITS_TAKEN), str(int(stats.get("hits_taken", 0)))],
		[node.tr(TEXT_STAT_CASTS), str(int(stats.get("casts", 0)))],
		[node.tr(TEXT_STAT_JOINS), str(int(stats.get("joins", 0)))],
		[node.tr(TEXT_STAT_FEATURED), str(int(stats.get("featured_casts", 0)))],
		[node.tr(TEXT_STAT_SIGNATURES), str(int(stats.get("signatures_used", 0)))],
		[node.tr(TEXT_STAT_DECK_SIZE), str(int(stats.get("deck_size", 0)))],
		[node.tr(TEXT_STAT_HIGHEST_LEVEL), str(int(stats.get("highest_card_level", 0)))],
		[node.tr(TEXT_STAT_RELICS), str((relics as Array).size() if relics is Array else 0)],
		[node.tr(TEXT_STAT_FATES), format_text(node.tr(TEXT_STAT_FATES_VALUE), [spared, executed])],
	]


## Story 035 D: "Đường: A → B → …" from the stats' region_path (region names through [param flow]).
static func path_text(node: Node, stats: Dictionary, flow: GameFlow) -> String:
	var names: Array[String] = []
	for id: Variant in stats.get("region_path", []):
		names.append(flow.region_name(str(id)) if flow != null else str(id))
	return format_text(node.tr(TEXT_STAT_PATH), [PATH_SEPARATOR.join(names)])


## [param template] % [param args], or [param template] unchanged when its placeholder count does not
## match (a missing translation returns the bare key: no "not all arguments converted" error).
static func format_text(template: String, args: Array) -> String:
	var marks: int = template.replace("%%", "").count("%")
	if marks != args.size():
		return template
	return template % args


## Run clock as m:ss (seconds floored).
static func elapsed_text(seconds: float) -> String:
	var total: int = floori(maxf(seconds, 0.0))
	var minutes: int = floori(total / 60.0)
	return "%d:%02d" % [minutes, total - minutes * 60]


## Rows of one column that fit [param rect] at [param font_size] (the first row line is the path).
static func rows_per_column(rect: Rect2, font_size: int) -> int:
	return maxi(floori(rect.size.y / (font_size * STATS_ROW_HEIGHT)) - 1, 1)


## Pages needed to show [param row_count] stats rows in two columns inside [param rect].
static func page_count(rect: Rect2, row_count: int, font_size: int) -> int:
	return maxi(ceili(float(row_count) / (rows_per_column(rect, font_size) * 2)), 1)


## Story 035 D: draws the stats block into [param rect]: the path line across the top, then page
## [param page] of [param rows] in two columns (label left, value right-aligned) at [param font_size].
static func draw_stats(canvas: CanvasItem, rect: Rect2, path: String, rows: Array, page: int, font_size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var row_h: float = font_size * STATS_ROW_HEIGHT
	var baseline: float = row_h * 0.5 + font_size * 0.35
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + baseline), _cut(path, rect.size.x, font_size), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, STATS_VALUE_COLOR)
	var gap: float = rect.size.x * STATS_COLUMN_GAP_RATIO
	var column_w: float = (rect.size.x - gap) * 0.5
	var per_column: int = rows_per_column(rect, font_size)
	var first: int = page * per_column * 2
	for i: int in range(first, mini(rows.size(), first + per_column * 2)):
		var slot: int = i - first
		var column: int = floori(float(slot) / per_column)
		var x: float = rect.position.x + (column_w + gap) * column
		var y: float = rect.position.y + row_h * (slot % per_column + 1)
		var row: Array = rows[i]
		var label_w: float = column_w * STATS_LABEL_SHARE
		canvas.draw_line(Vector2(x, y + row_h), Vector2(x + column_w, y + row_h), STATS_RULE_COLOR, STATS_RULE_WIDTH)
		canvas.draw_string(font, Vector2(x, y + baseline), _cut(str(row[0]), label_w, font_size), HORIZONTAL_ALIGNMENT_LEFT, label_w, font_size, STATS_LABEL_COLOR)
		canvas.draw_string(font, Vector2(x + label_w, y + baseline), _cut(str(row[1]), column_w - label_w, font_size), HORIZONTAL_ALIGNMENT_RIGHT, column_w - label_w, font_size, STATS_VALUE_COLOR)


# [param text] cut with an ellipsis to fit [param width] at [param size] (the font never shrinks).
static func _cut(text: String, width: float, size: int) -> String:
	var font: Font = ThemeDB.fallback_font
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return text
	var cut: String = text
	while cut.length() > 1 and font.get_string_size(cut + ELLIPSIS, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		cut = cut.left(cut.length() - 1)
	return cut + ELLIPSIS


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if is_fully_shown():
				_flow.leave_ending()
			else:
				show_all()
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pos: Vector2 = _press(event)
	if pos == Vector2.INF:
		return
	if not is_fully_shown():
		show_all()  # a tap anywhere shows everything; it does not also press a button
		return
	var vp: Vector2 = get_viewport_rect().size
	if ScreenLayout.ending_leave_rect(vp).has_point(pos):
		_flow.leave_ending()
	elif get_page_count() > 1 and ScreenLayout.ending_page_rect(vp).has_point(pos):
		_page = (_page + 1) % get_page_count()


func _press(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			return button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			return touch.position
	return Vector2.INF


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not is_open():
		return
	var vp: Vector2 = get_viewport_rect().size
	var ending: Dictionary = _ending()
	draw_rect(Rect2(Vector2.ZERO, vp), BACK_COLOR)
	var band: Rect2 = ScreenLayout.ending_title_rect(vp)
	var title: String = tr(str(ending.get("title_key", "")))
	_text(band, band.get_center().y + TITLE_FONT_SIZE * 0.35, title, _fit(title, vp.x * 0.9, TITLE_FONT_SIZE), TITLE_COLOR)
	var keys: Array = ending.get("line_keys", [])
	for i: int in mini(get_visible_lines(), keys.size()):
		var line_rect: Rect2 = ScreenLayout.ending_line_rect(vp, i)
		var line: String = tr(str(keys[i]))
		_text(line_rect, line_rect.get_center().y + LINE_FONT_SIZE * 0.35, line, _fit(line, line_rect.size.x, LINE_FONT_SIZE), LINE_COLOR)
	if not is_fully_shown():
		return
	var stats: Dictionary = ending.get("stats", {})
	var rows: Array = stat_rows(self, stats, _flow)
	var block: Rect2 = ScreenLayout.ending_stats_rect(vp)
	var pages: int = page_count(block, rows.size(), STATS_FONT_SIZE)
	draw_stats(self, block, path_text(self, stats, _flow), rows, mini(_page, pages - 1), STATS_FONT_SIZE)
	var leave: Rect2 = ScreenLayout.ending_leave_rect(vp)
	var leave_text: String = tr(TEXT_LEAVE)
	UiButtons.draw_button(self, leave, leave_text, UiButtons.Style.PRIMARY, UiButtons.is_pressed_at(self, leave), true, _fit(leave_text, leave.size.x * 0.9, BUTTON_FONT_SIZE))
	if pages > 1:
		var page: Rect2 = ScreenLayout.ending_page_rect(vp)
		var page_text: String = tr(TEXT_PAGE_PREV if _page > 0 else TEXT_PAGE_NEXT)
		UiButtons.draw_button(self, page, page_text, UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, page), true, _fit(page_text, page.size.x * 0.9, BUTTON_FONT_SIZE))


func _text(rect: Rect2, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


# Largest font size <= [param size] (not below MIN_FIT_FONT_SIZE) at which [param text] fits [param width].
func _fit(text: String, width: float, size: int) -> int:
	var font: Font = ThemeDB.fallback_font
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted).x > width:
		fitted -= 1
	return fitted

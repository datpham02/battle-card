class_name ChapterMapView
extends Node2D
## Chapter map screen (Story 022, Part A; the node picker that replaced the Story 015 floor select): the live run's
## region map ([method GameFlow.get_run_map]). Redesigned 2026-11-02 (map v5 mockup, then v6 after the user's
## reference image: OSFE's route layout in Tessera's look):
## - the region's backdrop art under a dark veil;
## - along the top, the HUD bar (second reference image): the hero pennant, the hero block (name, "HP hp/max", the HP
##   bar), two stat groups on navy plates (deck size | block set, gold | card removals; the block-set half is a button
##   -> [method GameFlow.open_piece_deck]) and the gear button (a small panel: Resume, Back to title ->
##   [method GameFlow.leave_run_keep_save]); under it on the right, the floor banner ("Floor N/M · <region>");
## - the route (ScreenLayout.map_route_rect): every node a pixel-art diamond plate with its pixel icon
##   (tools/asset-pipeline/make_map_icons.py), joined by the floor's links (ChapterMapGen.link_columns, 2026-11-03):
##   every link in violet, then the path taken and the fan from the hero's node (a gold diamond above the last cleared
##   node, or the start point on the left) to the nodes open now in gold; nodes of the current column the hero's node
##   does not link to are dimmed and cannot be chosen. Nodes that cannot be taken now are tinted down (the warden's less, it is the goal),
##   cleared ones carry a green check; the SELECTED node uses the larger bright plate with a gold pointer under it;
## - under the route, a borderless info band (the selected node's icon, name and one line from "node.<kind>.desc")
##   and the gold Enter button (UiButtons PRIMARY);
## - along the bottom, a legend of the node kinds on this map (+ the cleared check) and the relic strip on the right.
## Input (touch first): a tap on an available node selects it, a tap on the selected node or on Enter enters it
## ([method GameFlow.choose_node]); Enter / Keypad Enter / Space enter the selected node, Up / Down move the selection,
## Escape opens / closes the pause panel (desktop extras). The first available node is selected when a column opens.
## While an offer is open over the map (a treasure node, Story 022) RewardView draws and takes input above this view:
## only the route is drawn. A restart / floor-clear notice shows in a banner until the first tap. Child of GameFlow
## (reads it through [member flow_path]); draws and takes input only in phase MAP; owns no run state. Input dedup as
## in RunHudView (emulated copies, device == InputEvent.DEVICE_ID_EMULATION, are consumed but never act). All strings
## are TEXT_* keys drawn through tr().

## Name colours by kind (info band), light enough for the dark screen; the warden is gold: red is kept for telegraphs.
const GLYPH_BATTLE: Color = HudSkin.IVORY
const GLYPH_DANGER: Color = Color("F08A4B")
const GLYPH_TREASURE: Color = Color("E8B04A")
const GLYPH_REST: Color = Color("FFB070")
const GLYPH_MINIBOSS: Color = Color("C495E0")
const GLYPH_BOSS: Color = HudSkin.GRID_LIGHT
## Story 033: shop (green purse, gold coin) and event (blue scroll).
const GLYPH_SHOP: Color = Color("6FD39A")
const GLYPH_EVENT: Color = Color("86A8F2")
## World Map v2 (docs/design/world-map-v2/01 section G): the forge node's code-drawn angular glyph, the lane bands'
## colours per archetype (translucent parallelograms behind the lane's three nodes), the Heat meter, the tier marks.
const KIND_FORGE: String = MapGraph.KIND_FORGE
const GLYPH_FORGE: Color = Color("D9A066")
const ARCHETYPE_COLORS: Dictionary = {"safe": Color("5FB37A"), "treasure": Color("E8B04A"), "peril": Color("E2653A"), "elite": Color("C495E0"), "mystery": Color("86A8F2")}
const BAND_ALPHA: float = 0.2
const BAND_LINE_ALPHA: float = 0.65
const BAND_HEIGHT_RATIO: float = 1.35
const BAND_PAD_RATIO: float = 0.75
const BAND_FONT_SIZE: int = 18
const HEAT_COLOR: Color = Color("F08A4B")
const HEAT_SIZE_PX: Vector2 = Vector2(440.0, 30.0)
const HEAT_GAP_PX: float = 8.0
const HEAT_FONT_SIZE: int = 20
const TIER_MARK_PX: float = 6.0
const PREVIEW_FONT_SIZE: int = 18
const PREVIEW_NAME_FONT_SIZE: int = 22
const ROUTE_NAME_KEY_FORMAT: String = "route.%s.name"
const TEXT_HEAT: String = "ui.map.heat"
const TEXT_HEAT_AFTER: String = "ui.map.heat_after"
const TEXT_ENEMY: String = "ui.map.enemy"
const TEXT_ARENA: String = "ui.map.arena"
const TEXT_TIER: String = "ui.map.tier"
const TEXT_OBJECTIVE: String = "ui.map.objective"
## Map v6 (2026-11-02 reference): pixel art made by tools/asset-pipeline/make_map_icons.py, drawn at the menus'
## whole-number scale: the diamond node plates (normal, selected, warden), one 20x20 icon per kind, the check.
const PLATE_TEX: Texture2D = preload("res://assets/art/ui/map/node_plate.png")
const PLATE_SELECTED_TEX: Texture2D = preload("res://assets/art/ui/map/node_plate_selected.png")
const PLATE_BOSS_TEX: Texture2D = preload("res://assets/art/ui/map/node_plate_boss.png")
const CHECK_TEX: Texture2D = preload("res://assets/art/ui/map/check.png")
const ICONS: Dictionary = {
	"battle": preload("res://assets/art/ui/map/icon_battle.png"), "danger": preload("res://assets/art/ui/map/icon_danger.png"),
	"treasure": preload("res://assets/art/ui/map/icon_treasure.png"), "rest": preload("res://assets/art/ui/map/icon_rest.png"),
	"miniboss": preload("res://assets/art/ui/map/icon_miniboss.png"), "boss": preload("res://assets/art/ui/map/icon_boss.png"),
	"shop": preload("res://assets/art/ui/map/icon_shop.png"), "event": preload("res://assets/art/ui/map/icon_event.png"),
}
## Tint of a node that cannot be taken now (cleared, passed, ahead), and the warden's (it stays readable as the goal).
const NODE_DIM: Color = Color(0.55, 0.55, 0.62, 0.85)
const NODE_WARDEN_DIM: Color = Color(0.85, 0.85, 0.9, 1.0)
## The region backdrop under the map: its art drawn to cover the screen, then this veil over it.
const BACKDROP_VEIL: Color = Color(0.09, 0.08, 0.11, 0.72)
## Floor banner: fill, outer and inner lines, the diamond bullet, font.
const BANNER_FILL: Color = Color(0.118, 0.106, 0.141, 0.92)
const BANNER_LINE: Color = Color("6A6080")
const BANNER_FONT_SIZE: int = 26
## Legend: font, colour and the gap between entries (icons at half the menus' art scale, 20 px at 720p).
const LEGEND_FONT_SIZE: int = 20
const LEGEND_COLOR: Color = Color("CFC9DC")
const LEGEND_GAP_PX: float = 20.0
## Route colours: the path taken, the fan to the current column, the lines ahead (violet), the hero marker / selection
## pointer.
const PATH_COLOR: Color = Color(1.0, 0.831, 0.361, 0.75)
const FAN_COLOR: Color = Color(1.0, 0.831, 0.361, 0.9)
const AHEAD_COLOR: Color = Color("4A3E6A")
const CLEARED_COLOR: Color = Color("58D468")
const MARKER_COLOR: Color = HudSkin.GRID_LIGHT
## Px at 720p (times ScreenLayout.controls_scale): route line widths (path / fan / ahead), the hero marker's
## half-diagonal and its lift above a node, the selection pointer's half-width and gap.
const PATH_WIDTH: float = 2.0
const FAN_WIDTH: float = 3.0
const AHEAD_WIDTH: float = 2.0
const MARKER_HALF_PX: float = 9.0
const MARKER_LIFT_PX: float = 52.0
const POINTER_HALF_PX: float = 9.0
const POINTER_GAP_PX: float = 8.0
## HUD bar (2026-11-02 reference): the pennant, the stat icons and the gear (pixel art by make_map_icons.py), the
## hero block's fonts and rows (baseline / bar top as px at 720p from its top), the gold rule's gap under it, the "HP"
## label, and the gap between a stat icon and its number.
const PENNANT_TEX: Texture2D = preload("res://assets/art/ui/map/pennant.png")
const STAT_DECK_TEX: Texture2D = preload("res://assets/art/ui/map/stat_deck.png")
const STAT_BLOCKS_TEX: Texture2D = preload("res://assets/art/ui/map/stat_blocks.png")
const STAT_GOLD_TEX: Texture2D = preload("res://assets/art/ui/map/stat_gold.png")
const STAT_REMOVAL_TEX: Texture2D = preload("res://assets/art/ui/map/stat_removal.png")
const GEAR_TEX: Texture2D = preload("res://assets/art/ui/map/gear.png")
const RULE_GAP_PX: float = 6.0
const HP_LABEL: String = "HP"
const NAME_FONT_SIZE: int = 22
const NUMBER_FONT_SIZE: int = 20
const STAT_FONT_SIZE: int = 22
const NAME_BASELINE_PX: float = 24.0
const BAR_TOP_PX: float = 34.0
const BAR_HEIGHT_PX: float = 14.0
const STAT_NUMBER_GAP_PX: float = 8.0
## Info band: fill, name and line fonts, inset, the icon's slot width.
const INFO_BACK: Color = Color(0.129, 0.118, 0.161, 0.85)
const INFO_NAME_FONT_SIZE: int = 26
const INFO_LINE_FONT_SIZE: int = 20
const INFO_LINE_COLOR: Color = Color("CFC9DC")
const INFO_INSET_PX: float = 16.0
const INFO_GLYPH_PX: float = 56.0
const ENTER_FONT_SIZE: int = 30
## The floor banner text: "Floor N/M" and the region, joined (TEXT_FLOOR_TITLE).
const TEXT_FLOOR_TITLE: String = "ui.map.floor_title"
## Pause panel: size (px at 720p), dim, title font, the two buttons (size, gap) and their font.
const PAUSE_PANEL_PX: Vector2 = Vector2(420.0, 300.0)
const PAUSE_DIM: Color = Color(0.0, 0.0, 0.0, 0.55)
const PAUSE_TITLE_FONT_SIZE: int = 36
const PAUSE_BUTTON_PX: Vector2 = Vector2(320.0, 66.0)
const PAUSE_BUTTON_GAP_PX: float = 18.0
const PAUSE_BUTTON_FONT_SIZE: int = 26
## Pause glyph on its icon button: bar width / height and gap as shares of the inner side.
const PAUSE_BAR_WIDTH_RATIO: float = 0.18
const PAUSE_BAR_HEIGHT_RATIO: float = 0.62
const PAUSE_BAR_GAP_RATIO: float = 0.18
## Notice banner (restart / floor clear): colours, fonts, baselines as shares of its height.
const NOTICE_BACK: Color = Color(0.118, 0.106, 0.141, 0.97)
const NOTICE_OUTLINE: Color = HudSkin.IVORY
const NOTICE_TEXT: Color = HudSkin.IVORY
const NOTICE_SUB_TEXT: Color = HudSkin.TEXT_DIM
const NOTICE_FONT_SIZE: int = 30
const NOTICE_SUB_FONT_SIZE: int = 22
const NOTICE_BASELINE: float = 0.45
const NOTICE_SUB_BASELINE: float = 0.8
const OUTLINE_WIDTH: float = 3.0
## Pulse of the selected node's pointer: period and the alpha it dips to.
const PULSE_PERIOD_SEC: float = 1.2
const PULSE_MIN_ALPHA: float = 0.55
## Node kinds as written in chapters.json / the map (ChapterMapGen).
const KIND_BATTLE: String = "battle"
const KIND_DANGER: String = "danger"
const KIND_TREASURE: String = "treasure"
const KIND_REST: String = "rest"
const KIND_MINIBOSS: String = "miniboss"
const KIND_BOSS: String = "boss"
const KIND_SHOP: String = "shop"
const KIND_EVENT: String = "event"
## Format of a node kind's name key ("node.battle.name" ...) and of its one-line description ("node.battle.desc").
const NODE_NAME_KEY_FORMAT: String = "node.%s.name"
const NODE_DESC_KEY_FORMAT: String = "node.%s.desc"

## The Enter button and the pause panel's title / buttons.
const TEXT_ENTER: String = "ui.map.enter"
## Legend entry for cleared nodes.
const TEXT_CLEARED: String = "ui.map.cleared"
const TEXT_PAUSE_TITLE: String = "ui.run_hud.pause_title"
const TEXT_RESUME: String = "ui.run_hud.resume"
## Back to title (the run stays saved), inside the pause panel.
const TEXT_BACK: String = "ui.map.back"
## Story 031: the final match's name (the floor banner at the end of the run, shared with WorldMapView).
const TEXT_FINAL_NAME: String = "ui.world.final_name"
## Second line of the notice banner ("Chạm để đóng").
const TEXT_NOTICE_DISMISS: String = "ui.map.notice_dismiss"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow = null
## Story 032: owned-relic strip in the bottom-left corner (tap an icon for its card).
var _strip: RelicStrip = null
## Restart / floor-clear notice text shown in the banner until the first tap ("" = none).
var _notice: String = ""
## The selected node of the current column (-1 = none) and the column it belongs to (a new column re-selects).
var _selected: int = -1
var _selected_column: int = -1
## The pause panel is open.
var _paused: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flow = get_node_or_null(flow_path) as GameFlow
	_strip = RelicStrip.new()
	add_child(_strip)


func _process(_delta: float) -> void:
	_sync_strip()
	if not _is_active():
		_notice = ""
		_paused = false
		_selected_column = -1
		queue_redraw()  # clear the last frame (see TitleView)
		return
	_sync_selection()
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


## Translated one-line description of node kind [param kind] ("node.<kind>.desc").
static func kind_description(kind: String) -> String:
	return TranslationServer.translate(NODE_DESC_KEY_FORMAT % kind)


## The selected node index of the current column (-1 when none).
func get_selected_node() -> int:
	return _selected


## True while the pause panel is open.
func is_paused() -> bool:
	return _paused


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.MAP and _flow.get_run() != null


# --- Selection ----------------------------------------------------------------


# A new column (or a selection that is no longer available) selects the column's first available node.
func _sync_selection() -> void:
	var current: int = _flow.get_current_column()
	var available: Array[int] = _available_indices()
	if current != _selected_column or not available.has(_selected):
		_selected_column = current
		_selected = available[0] if not available.is_empty() else -1


# Node indices of the current column that can be chosen now.
func _available_indices() -> Array[int]:
	var out: Array[int] = []
	for node: Dictionary in _flow.get_available_nodes():
		out.append(int(node.get("node_index", -1)))
	return out


func _enter_selected() -> void:
	if _selected >= 0 and _available_indices().has(_selected):
		_flow.choose_node(_selected)


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey:
		_key_input(event as InputEventKey)
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if not _paused and event.device != InputEvent.DEVICE_ID_EMULATION and _strip.visible and _strip.handle_input(event):
		return
	var pos: Vector2 = _press_position(event)
	if pos == Vector2.INF or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if not _notice.is_empty():
		_notice = ""
		return
	var vp: Vector2 = get_viewport_rect().size
	if _paused:
		var buttons: Array[Rect2] = pause_button_rects(vp)
		if buttons[0].has_point(pos):
			_paused = false
		elif buttons[1].has_point(pos):
			_paused = false
			_flow.leave_run_keep_save()
		return
	if ScreenLayout.touch_rect(ScreenLayout.map_pause_button_rect(vp)).has_point(pos):
		_paused = true
		return
	if ScreenLayout.touch_rect(ScreenLayout.map_block_set_button_rect(vp)).has_point(pos):
		_flow.open_piece_deck()
		return
	if ScreenLayout.touch_rect(ScreenLayout.map_enter_button_rect(vp)).has_point(pos):
		_enter_selected()
		return
	var tapped: int = _node_at(vp, pos)
	if tapped < 0:
		return
	if tapped == _selected:
		_enter_selected()
	else:
		_selected = tapped


func _key_input(key: InputEventKey) -> void:
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled()
			if not _notice.is_empty():
				_notice = ""
			elif not _paused:
				_enter_selected()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_paused = not _paused
		KEY_UP, KEY_DOWN:
			get_viewport().set_input_as_handled()
			var available: Array[int] = _available_indices()
			if not _paused and not available.is_empty():
				var at: int = maxi(available.find(_selected), 0)
				_selected = available[clampi(at + (1 if key.keycode == KEY_DOWN else -1), 0, available.size() - 1)]


# Index of the available node of the current column whose tap area holds [param pos]; -1 when none.
func _node_at(vp: Vector2, pos: Vector2) -> int:
	var map: Array[Dictionary] = _flow.get_run_map()
	var current: int = _flow.get_current_column()
	if current < 0 or current >= map.size():
		return -1
	var count: int = (map[current].get("nodes", []) as Array).size()
	for i: int in _available_indices():
		var center: Vector2 = ScreenLayout.map_route_node_center(vp, current, map.size(), i, count)
		if ScreenLayout.map_route_node_hit_rect(vp, center).has_point(pos):
			return i
	return -1


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


## The pause panel's two buttons (Resume, Back to title), stacked in the middle of the screen.
static func pause_button_rects(vp: Vector2) -> Array[Rect2]:
	var s: float = ScreenLayout.controls_scale(vp)
	var size: Vector2 = (PAUSE_BUTTON_PX * s).round()
	var gap: float = roundf(PAUSE_BUTTON_GAP_PX * s)
	var top: float = roundf(vp.y * 0.5 - size.y * 0.25)
	var left: float = roundf((vp.x - size.x) * 0.5)
	return [Rect2(left, top, size.x, size.y), Rect2(left, top + size.y + gap, size.x, size.y)] as Array[Rect2]


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
	var map: Array[Dictionary] = _flow.get_run_map()
	var current: int = _flow.get_current_column()
	var offer_open: bool = not _flow.get_pending_reward().is_empty()
	# The region's backdrop art under a dark veil (a flat background when the region has none).
	_draw_backdrop(vp)
	_draw_route(vp, map, current, not offer_open)
	# While an offer is open over the map (a treasure node, a resumed offer) RewardView owns the screen: only the route
	# stays under its dim.
	if offer_open:
		return
	_draw_hud_bar(vp, _flow.get_run())
	_draw_info(vp, map, current)
	_draw_floor_banner(vp)
	_draw_heat(vp)
	_draw_legend(vp, map)
	if _paused:
		_draw_pause(vp)
	if not _notice.is_empty():
		_draw_notice(vp)


# The route: lines first (path taken, the fan to the current column, the lines ahead), then every node's glyph by
# state, the hero marker and the selection pointer.
func _draw_route(vp: Vector2, map: Array[Dictionary], current: int, show_selection: bool) -> void:
	var s: float = ScreenLayout.controls_scale(vp)
	var count: int = map.size()
	# World Map v2: the lane bands behind a v2 region's three lanes, under the links.
	var graph: Dictionary = _flow.get_map_graph()
	if str(graph.get("source", "")) == MapGraph.SOURCE_V2:
		_draw_lane_bands(vp, map, graph)
	# 2026-11-03: every link of the floor (ChapterMapGen.link_columns; a map without links joins every pair), violet.
	for ci: int in count - 1:
		var from_nodes: Array = map[ci].get("nodes", [])
		var to_count: int = (map[ci + 1].get("nodes", []) as Array).size()
		for ni: int in from_nodes.size():
			var at: Vector2 = ScreenLayout.map_route_node_center(vp, ci, count, ni, from_nodes.size())
			for to: int in _links_of(from_nodes[ni] as Dictionary, to_count):
				draw_line(at, ScreenLayout.map_route_node_center(vp, ci + 1, count, to, to_count), AHEAD_COLOR, AHEAD_WIDTH * s)
	# The path through the cleared nodes from the start point, then the fan to the nodes open now, in gold.
	var hero: Vector2 = ScreenLayout.map_route_start(vp)
	for ci: int in mini(current, count):
		var nodes: int = (map[ci].get("nodes", []) as Array).size()
		var cleared: int = _cleared_index(ci)
		if cleared < 0 or cleared >= nodes:
			continue
		var at: Vector2 = ScreenLayout.map_route_node_center(vp, ci, count, cleared, nodes)
		draw_line(hero, at, PATH_COLOR, PATH_WIDTH * s)
		hero = at
	if current >= 0 and current < count:
		var open_count: int = (map[current].get("nodes", []) as Array).size()
		for ni: int in _available_indices():
			draw_line(hero, ScreenLayout.map_route_node_center(vp, current, count, ni, open_count), FAN_COLOR, FAN_WIDTH * s)
	var icon: float = ScreenLayout.MAP_NODE_ICON_PX * s
	var art: int = PixelFrame.scale_for(vp.y)
	var available: Array[int] = _available_indices()
	for ci: int in count:
		var nodes: Array = map[ci].get("nodes", [])
		var cleared: int = _cleared_index(ci)
		for ni: int in nodes.size():
			var kind: String = str((nodes[ni] as Dictionary).get("kind", ""))
			var center: Vector2 = ScreenLayout.map_route_node_center(vp, ci, count, ni, nodes.size())
			var open: bool = ci == current and available.has(ni)
			var selected: bool = open and show_selection and ni == _selected
			var tint: Color = Color.WHITE if open else (NODE_WARDEN_DIM if kind == KIND_BOSS else NODE_DIM)
			var plate: Texture2D = PLATE_SELECTED_TEX if selected else (PLATE_BOSS_TEX if kind == KIND_BOSS else PLATE_TEX)
			_draw_pixel(plate, center, art, tint)
			_draw_kind_icon(kind, center, art, tint, icon)
			# World Map v2: reward tier 2 / 3 marks (one / two small gold diamonds above the plate's right edge).
			var tier: int = int((nodes[ni] as Dictionary).get("reward_tier", 1))
			for k: int in tier - 1:
				HudSkin.diamond(self, center + Vector2(icon * 0.3 + float(k) * TIER_MARK_PX * 2.4 * s, -icon * 0.36), TIER_MARK_PX * s, Color(HudSkin.GRID_LIGHT, tint.a), HudSkin.TEXT_OUTLINE, 1.5)
			if ni == cleared:
				_draw_pixel(CHECK_TEX, center + Vector2(icon * 0.22, icon * 0.24), art, Color.WHITE)
	# The hero marker above the node the run stands on (the start point before the first column is cleared).
	var lift: float = (MARKER_LIFT_PX if hero != ScreenLayout.map_route_start(vp) else 0.0) * s
	HudSkin.diamond(self, hero - Vector2(0.0, lift), MARKER_HALF_PX * s, MARKER_COLOR, HudSkin.TEXT_OUTLINE, 2.0)
	if not show_selection or _selected < 0 or current < 0 or current >= count:
		return
	var sel_nodes: Array = map[current].get("nodes", [])
	if _selected >= sel_nodes.size():
		return
	var sel: Vector2 = ScreenLayout.map_route_node_center(vp, current, count, _selected, sel_nodes.size())
	var tip_y: float = sel.y + PLATE_SELECTED_TEX.get_height() * PixelFrame.scale_for(vp.y) * 0.5 + POINTER_GAP_PX * s
	var half: float = POINTER_HALF_PX * s
	var pointer := PackedVector2Array([Vector2(sel.x, tip_y), Vector2(sel.x + half, tip_y + half), Vector2(sel.x - half, tip_y + half)])
	draw_colored_polygon(pointer, Color(MARKER_COLOR, _pulse_alpha()))


# World Map v2: a node kind's icon: the pixel icon when one exists, else (forge) a code-drawn angular glyph: a diamond
# of the forge colour with a dark slab across its middle (no circle, no box).
func _draw_kind_icon(kind: String, center: Vector2, art: int, tint: Color, icon: float) -> void:
	if ICONS.has(kind):
		_draw_pixel(ICONS[kind], center, art, tint)
		return
	if kind == KIND_FORGE:
		var r: float = icon * 0.3
		HudSkin.diamond(self, center, r, Color(GLYPH_FORGE * tint, tint.a), HudSkin.TEXT_OUTLINE, 2.0)
		draw_rect(Rect2(center - Vector2(r * 0.55, r * 0.18), Vector2(r * 1.1, r * 0.36)), Color(HudSkin.NIGHT_STONE, tint.a))
		return
	_draw_pixel(ICONS["battle"], center, art, tint)


# World Map v2 (01 section G1): one translucent angular band per lane behind its three nodes (depths 1, 2 and 4 of
# the layout), in the archetype's colour, labelled with the archetype's name at its left end.
func _draw_lane_bands(vp: Vector2, map: Array[Dictionary], graph: Dictionary) -> void:
	var s: float = ScreenLayout.controls_scale(vp)
	var count: int = map.size()
	var lanes: Array = graph.get("lanes", [])
	if lanes.is_empty() or count < 5:
		return
	var icon: float = ScreenLayout.MAP_NODE_ICON_PX * s
	var lane_count: int = lanes.size()
	for lane: Variant in lanes:
		var order: int = int((lane as Dictionary).get("order", 0))
		var arch: String = str((lane as Dictionary).get("archetype", ""))
		var color: Color = ARCHETYPE_COLORS.get(arch, HudSkin.MIST)
		var first: Vector2 = ScreenLayout.map_route_node_center(vp, 1, count, order, lane_count)
		var last: Vector2 = ScreenLayout.map_route_node_center(vp, 4, count, order, lane_count)
		var h: float = icon * BAND_HEIGHT_RATIO
		var pad: float = icon * BAND_PAD_RATIO
		var rect := Rect2(first.x - pad, first.y - h * 0.5, last.x - first.x + pad * 2.0, h)
		var cut: float = h * 0.35
		var points: PackedVector2Array = HudSkin.chamfer_points(rect, [cut, 0.0, cut, 0.0])
		draw_colored_polygon(points, Color(color, BAND_ALPHA))
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(color, BAND_LINE_ALPHA), 2.0 * s)
		var label: String = tr(ROUTE_NAME_KEY_FORMAT % arch)
		MenuFont.text(self, Vector2(rect.position.x + cut * 0.5, rect.position.y - 4.0 * s), label, BAND_FONT_SIZE, color.lightened(0.25))


# World Map v2 (02 section 2): the region rule's gauge under the floor banner — "Nhiệt n/max" and max angular
# segments, the lit ones in ember. Nothing when the region has no rule.
func _draw_heat(vp: Vector2) -> void:
	var state: Dictionary = _flow.get_rule_state()
	if state.is_empty():
		return
	var rule: Dictionary = _flow.get_region_rule()
	var gauge_cfg: Dictionary = rule.get("gauge", {}) if typeof(rule.get("gauge")) == TYPE_DICTIONARY else {}
	var gmax: int = maxi(int(gauge_cfg.get("max", 4)), 1)
	var value: int = clampi(int(state.get("gauge", 0)), 0, gmax)
	var s: float = ScreenLayout.controls_scale(vp)
	var banner: Rect2 = ScreenLayout.map_floor_banner_rect(vp)
	var size: Vector2 = (HEAT_SIZE_PX * s).round()
	var rect := Rect2(Vector2(banner.end.x - size.x, banner.end.y + HEAT_GAP_PX * s).round(), size)
	var label: String = tr(TEXT_HEAT) % [value, gmax]
	var label_w: float = HudSkin.text_width(label, MenuFont.size(HEAT_FONT_SIZE), true) + 12.0 * s
	MenuFont.text(self, Vector2(rect.position.x, rect.get_center().y + MenuFont.size(HEAT_FONT_SIZE) * 0.35), label, HEAT_FONT_SIZE, HEAT_COLOR)
	var meter := Rect2(rect.position.x + label_w, rect.position.y + 4.0 * s, rect.size.x - label_w, rect.size.y - 8.0 * s)
	HudSkin.segments(self, meter, gmax, value, HEAT_COLOR)


# The HUD bar: the hero pennant; the hero block (name, "HP hp/max", the HP bar, a thin gold rule with diamond ends);
# two stat groups on navy ancient plates (deck size | block set, gold | card removals: pixel icon + number, a gold
# divider; the block-set half sinks while pressed); the gear button (pause panel).
func _draw_hud_bar(vp: Vector2, run: RunSession) -> void:
	var s: float = ScreenLayout.controls_scale(vp)
	var art: int = PixelFrame.scale_for(vp.y)
	_draw_pixel(PENNANT_TEX, ScreenLayout.map_pennant_rect(vp).get_center(), art, Color.WHITE)
	var hero: Rect2 = ScreenLayout.map_hp_panel_rect(vp)
	var max_hp: float = _max_hp(run)
	var hp: float = max_hp if run.hp < 0.0 else minf(run.hp, max_hp)
	var character: Dictionary = _flow.get_characters().get_character(run.character_id)
	var name_size: int = roundi(NAME_FONT_SIZE * s)
	var name_y: float = hero.position.y + NAME_BASELINE_PX * s
	var hp_text: String = "%d / %d" % [ceili(hp), ceili(max_hp)]
	var number_size: int = roundi(NUMBER_FONT_SIZE * s)
	var hp_w: float = HudSkin.text_width(hp_text, number_size, true)
	HudSkin.text(self, Vector2(hero.end.x - hp_w, name_y), hp_text, number_size, HudSkin.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	var hp_label_w: float = HudSkin.text_width(HP_LABEL, number_size, true)
	HudSkin.text(self, Vector2(hero.end.x - hp_w - hp_label_w - 8.0 * s, name_y), HP_LABEL, number_size, HudSkin.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	HudSkin.text(self, Vector2(hero.position.x, name_y), tr(str(character.get("name_key", run.character_id))), name_size, HudSkin.TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, maxf(hero.size.x - hp_w - hp_label_w - 16.0 * s, 0.0))
	var bar := Rect2(Vector2(hero.position.x, hero.position.y + BAR_TOP_PX * s).floor(), Vector2(hero.size.x, maxf(roundf(BAR_HEIGHT_PX * s), 1.0)).floor())
	var ratio: float = 0.0 if max_hp <= 0.0 else hp / max_hp
	HudSkin.hp_bar(self, bar, ratio, ratio, HudSkin.HP_FILL, false)
	var rule_y: float = roundf(hero.end.y + RULE_GAP_PX * s)
	draw_line(Vector2(hero.position.x, rule_y), Vector2(hero.end.x, rule_y), Color(MARKER_COLOR, 0.6), maxf(s, 1.0))
	HudSkin.diamond(self, Vector2(hero.end.x, rule_y), 4.0 * s, MARKER_COLOR, HudSkin.TEXT_OUTLINE, 1.0)
	var groups: Array = [
		[[STAT_DECK_TEX, run.deck.size()], [STAT_BLOCKS_TEX, PieceDeck.active_ids(_flow.get_piece_deck(), RunSession.piece_library()).size()]],
		[[STAT_GOLD_TEX, _flow.get_gold()], [STAT_REMOVAL_TEX, _flow.get_removal_tokens()]],
	]
	var block_chip: Rect2 = ScreenLayout.map_block_set_button_rect(vp)
	var block_pressed: bool = UiButtons.is_pressed_at(self, ScreenLayout.touch_rect(block_chip))
	for gi: int in groups.size():
		var group: Rect2 = ScreenLayout.map_stat_group_rect(vp, gi)
		var sunk: bool = gi == 0 and block_pressed
		var body: Rect2 = UiButtons.draw_plate(self, group, UiButtons.look(UiButtons.Style.SECONDARY, sunk), UiButtons.ui_scale(self), sunk)
		var half: float = body.size.x * 0.5
		draw_line(Vector2(body.position.x + half, body.position.y + body.size.y * 0.25), Vector2(body.position.x + half, body.end.y - body.size.y * 0.25),
			Color(UiButtons.GOLD_RIM, 0.8), maxf(s, 1.0))
		for k: int in 2:
			var entry: Array = groups[gi][k]
			var cell := Rect2(body.position + Vector2(half * k, 0.0), Vector2(half, body.size.y))
			var tex: Texture2D = entry[0]
			var icon_w: float = tex.get_width() * art
			var size: int = roundi(STAT_FONT_SIZE * s)
			var text: String = str(entry[1])
			var total: float = icon_w + STAT_NUMBER_GAP_PX * s + HudSkin.text_width(text, size, true)
			var left: float = cell.get_center().x - total * 0.5
			_draw_pixel(tex, Vector2(left + icon_w * 0.5, cell.get_center().y), art, Color.WHITE)
			HudSkin.text(self, Vector2(left + icon_w + STAT_NUMBER_GAP_PX * s, cell.get_center().y + size * 0.36), text, size,
				HudSkin.GRID_LIGHT if tex == STAT_GOLD_TEX else HudSkin.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	var gear: Rect2 = ScreenLayout.map_pause_button_rect(vp)
	var inner: Rect2 = UiButtons.draw_icon_button(self, gear, UiButtons.is_pressed_at(self, ScreenLayout.touch_rect(gear)))
	# The gear at the full art scale: it may reach over the plate's inner line, as on the reference.
	_draw_pixel(GEAR_TEX, inner.get_center(), art, Color.WHITE)


# The info band (selected node's glyph, name and description) and the Enter button.
func _draw_info(vp: Vector2, map: Array[Dictionary], current: int) -> void:
	var s: float = ScreenLayout.controls_scale(vp)
	var band: Rect2 = ScreenLayout.map_info_rect(vp)
	var enter: Rect2 = ScreenLayout.map_enter_button_rect(vp)
	var nodes: Array = map[current].get("nodes", []) if current >= 0 and current < map.size() else []
	var has_selection: bool = _selected >= 0 and _selected < nodes.size()
	UiButtons.draw_button(self, enter, tr(TEXT_ENTER), UiButtons.Style.PRIMARY, has_selection and UiButtons.is_pressed_at(self, ScreenLayout.touch_rect(enter)),
		has_selection, ENTER_FONT_SIZE)
	if not has_selection:
		return
	draw_rect(band, INFO_BACK)
	var kind: String = str((nodes[_selected] as Dictionary).get("kind", ""))
	var inset: float = INFO_INSET_PX * s
	var glyph: float = INFO_GLYPH_PX * s
	_draw_kind_icon(kind, Vector2(band.position.x + inset + glyph * 0.5, band.get_center().y), PixelFrame.scale_for(vp.y), Color.WHITE, ScreenLayout.MAP_NODE_ICON_PX * s)
	var text_x: float = band.position.x + inset * 2.0 + glyph
	var text_w: float = band.end.x - text_x - inset
	# World Map v2 (01 section G1, 03 section 7): a v2 node's preview — kind + lane, enemy + arena, modifiers, tier,
	# objective, heat before -> after; a v1 node keeps the kind name and its one-line description.
	var preview: Dictionary = _flow.get_node_preview(_selected) if str(_flow.get_map_graph().get("source", "")) == MapGraph.SOURCE_V2 else {}
	if preview.is_empty():
		MenuFont.text(self, Vector2(text_x, band.position.y + band.size.y * 0.42), kind_name(kind), INFO_NAME_FONT_SIZE, _glyph_color(kind), HORIZONTAL_ALIGNMENT_LEFT, text_w)
		var line: String = kind_description(kind)
		MenuFont.text(self, Vector2(text_x, band.position.y + band.size.y * 0.82), line, MenuFont.fit_size(line, INFO_LINE_FONT_SIZE, text_w), INFO_LINE_COLOR,
			HORIZONTAL_ALIGNMENT_LEFT, text_w)
		return
	var name: String = kind_name(kind)
	var arch: String = str(preview.get("archetype", ""))
	if not arch.is_empty():
		name += " · " + tr(ROUTE_NAME_KEY_FORMAT % arch)
	var name_color: Color = ARCHETYPE_COLORS.get(arch, _glyph_color(kind)) if not arch.is_empty() else _glyph_color(kind)
	MenuFont.text(self, Vector2(text_x, band.position.y + band.size.y * 0.32), name, MenuFont.fit_size(name, PREVIEW_NAME_FONT_SIZE, text_w), name_color, HORIZONTAL_ALIGNMENT_LEFT, text_w)
	var parts: Array[String] = []
	var enemy_key: String = str(preview.get("enemy_name_key", ""))
	if not enemy_key.is_empty():
		parts.append(tr(TEXT_ENEMY) % tr(enemy_key))
	var shape: String = str(preview.get("arena_shape", ""))
	if not shape.is_empty():
		parts.append(tr(TEXT_ARENA) % shape)
	for m: Variant in preview.get("modifiers", []):
		parts.append(tr(str((m as Dictionary).get("text_key", ""))))
	var line2: String = " · ".join(parts)
	if not line2.is_empty():
		MenuFont.text(self, Vector2(text_x, band.position.y + band.size.y * 0.6), line2, MenuFont.fit_size(line2, PREVIEW_FONT_SIZE, text_w), INFO_LINE_COLOR, HORIZONTAL_ALIGNMENT_LEFT, text_w)
	var parts3: Array[String] = []
	if MapGraph.MATCH_KINDS.has(kind):
		parts3.append(tr(TEXT_TIER) % int(preview.get("reward_tier", 1)))
	var objective_key: String = str(preview.get("objective_text_key", ""))
	if not objective_key.is_empty():
		parts3.append(tr(TEXT_OBJECTIVE) % tr(objective_key))
	if not _flow.get_rule_state().is_empty() and int(preview.get("gauge", 0)) != int(preview.get("gauge_after", 0)):
		parts3.append(tr(TEXT_HEAT_AFTER) % [int(preview.get("gauge", 0)), int(preview.get("gauge_after", 0))])
	if parts3.is_empty():
		parts3.append(kind_description(kind))
	var line3: String = " · ".join(parts3)
	MenuFont.text(self, Vector2(text_x, band.position.y + band.size.y * 0.88), line3, MenuFont.fit_size(line3, PREVIEW_FONT_SIZE, text_w), HudSkin.GRID_LIGHT if MapGraph.MATCH_KINDS.has(kind) else INFO_LINE_COLOR, HORIZONTAL_ALIGNMENT_LEFT, text_w)


# The next-column node indices [param node] links to (its `next`); every index below [param next_count] when it has
# none (a map saved before the links existed).
func _links_of(node: Dictionary, next_count: int) -> Array:
	var links: Variant = node.get("next")
	if typeof(links) == TYPE_ARRAY:
		return links as Array
	var all: Array = []
	for i: int in next_count:
		all.append(i)
	return all


# [param tex] centred on [param center] at whole-number [param scale], tinted by [param tint], nearest filtered.
func _draw_pixel(tex: Texture2D, center: Vector2, scale: int, tint: Color) -> void:
	if tex == null:
		return
	var size: Vector2 = Vector2(tex.get_size()) * scale
	draw_texture_rect(PixelFrame.nearest(tex), Rect2((center - size * 0.5).round(), size), false, tint)


# The current region's far backdrop stretched to cover the screen under BACKDROP_VEIL (the near layer is made for the
# battle's bottom rows and blows up into blocks at this scale); a flat background when the region has no art.
func _draw_backdrop(vp: Vector2) -> void:
	HudSkin.screen_background(self, Rect2(Vector2.ZERO, vp), 0.0)
	# 2026-11-06: the map shows the area of the column the player stands at (edge -> ruins -> sanctum).
	var region: String = ArtAssets.region_for_match({"chapter_id": _flow.get_current_region(), "art_area": _flow.current_art_area()})
	var drew: bool = false
	for key: String in ["backdrop.far"]:
		var tex: Texture2D = ArtAssets.region_texture(region, key)
		if tex == null:
			continue
		var size := Vector2(tex.get_size())
		var k: float = maxf(vp.x / size.x, vp.y / size.y)
		var dst := Rect2(((vp - size * k) * 0.5).round(), (size * k).round())
		draw_texture_rect(PixelFrame.nearest(tex), dst, false)
		drew = true
	if drew:
		draw_rect(Rect2(Vector2.ZERO, vp), BACKDROP_VEIL)


# "Floor N/M · <region>" (the final match's name at the end) in a long hexagon banner with a diamond bullet.
func _draw_floor_banner(vp: Vector2) -> void:
	var s: float = ScreenLayout.controls_scale(vp)
	var r: Rect2 = ScreenLayout.map_floor_banner_rect(vp)
	var tip: float = r.size.y * 0.5
	var hexagon := PackedVector2Array([Vector2(r.position.x, r.get_center().y), Vector2(r.position.x + tip, r.position.y), Vector2(r.end.x - tip, r.position.y),
		Vector2(r.end.x, r.get_center().y), Vector2(r.end.x - tip, r.end.y), Vector2(r.position.x + tip, r.end.y)])
	draw_colored_polygon(hexagon, BANNER_FILL)
	var closed: PackedVector2Array = hexagon.duplicate()
	closed.append(hexagon[0])
	draw_polyline(closed, BANNER_LINE, 2.0 * s)
	var inner := PackedVector2Array()
	for p: Vector2 in closed:
		inner.append(r.get_center() + (p - r.get_center()) * Vector2(1.0 - 8.0 * s / r.size.x, 1.0 - 8.0 * s / r.size.y))
	draw_polyline(inner, Color(BANNER_LINE, 0.5), 1.0)
	var count: int = _flow.get_floor_count()
	var text: String = tr(TEXT_FINAL_NAME) if _flow.is_final_floor() or _flow.get_floor() >= count \
		else tr(TEXT_FLOOR_TITLE) % [_flow.get_floor() + 1, count, _flow.region_name(_flow.get_current_region())]
	var bullet := Vector2(r.position.x + tip + 10.0 * s, r.get_center().y)
	HudSkin.diamond(self, bullet, 6.0 * s, HudSkin.IVORY, HudSkin.TEXT_OUTLINE, 1.0)
	var text_x: float = bullet.x + 16.0 * s
	var text_w: float = r.end.x - tip - text_x
	MenuFont.text(self, Vector2(text_x, r.get_center().y + MenuFont.size(BANNER_FONT_SIZE) * 0.3), text, MenuFont.fit_size(text, BANNER_FONT_SIZE, text_w),
		HudSkin.IVORY, HORIZONTAL_ALIGNMENT_CENTER, text_w)


# The legend: one entry (icon + name) per node kind on this map, in map order, then the check for cleared nodes.
func _draw_legend(vp: Vector2, map: Array[Dictionary]) -> void:
	var s: float = ScreenLayout.controls_scale(vp)
	var r: Rect2 = ScreenLayout.map_legend_rect(vp)
	var kinds: Array[String] = []
	for column: Dictionary in map:
		for node: Variant in column.get("nodes", []):
			var kind: String = str((node as Dictionary).get("kind", ""))
			if not kinds.has(kind) and ICONS.has(kind):
				kinds.append(kind)
	var x: float = r.position.x
	var cy: float = r.get_center().y
	# Icons at half the route's art scale so every kind of a 7-column floor fits before the relic strip.
	var art: int = maxi(PixelFrame.scale_for(vp.y) / 2, 1)
	var entries: Array = []
	for kind: String in kinds:
		entries.append([ICONS[kind], kind_name(kind)])
	entries.append([CHECK_TEX, tr(TEXT_CLEARED)])
	for entry: Array in entries:
		var tex: Texture2D = entry[0]
		var w: float = tex.get_width() * art
		var label: String = entry[1]
		var label_w: float = HudSkin.text_width(label, MenuFont.size(LEGEND_FONT_SIZE), true)
		# A whole entry or nothing: an entry that would run past the legend (into the relic strip) is left out.
		if x + w + 8.0 * s + label_w > r.end.x:
			break
		_draw_pixel(tex, Vector2(x + w * 0.5, cy), art, Color.WHITE)
		x += w + 8.0 * s
		MenuFont.text(self, Vector2(x, cy + MenuFont.size(LEGEND_FONT_SIZE) * 0.3), label, LEGEND_FONT_SIZE, LEGEND_COLOR)
		x += label_w + LEGEND_GAP_PX * s


# The pause panel: dim, a chamfered panel, the title and the two buttons.
func _draw_pause(vp: Vector2) -> void:
	var s: float = ScreenLayout.controls_scale(vp)
	draw_rect(Rect2(Vector2.ZERO, vp), PAUSE_DIM)
	var size: Vector2 = PAUSE_PANEL_PX * s
	var panel := Rect2(((vp - size) * 0.5).round(), size.round())
	HudSkin.panel(self, panel, [HudSkin.BUTTON_CUT_MAX, 0.0, HudSkin.BUTTON_CUT_MAX, 0.0], Color(HudSkin.NIGHT_STONE, 0.97), HudSkin.MIST, OUTLINE_WIDTH)
	_text(panel, panel.position.y + PAUSE_TITLE_FONT_SIZE * 1.4 * s, tr(TEXT_PAUSE_TITLE), PAUSE_TITLE_FONT_SIZE, HudSkin.IVORY, true)
	var buttons: Array[Rect2] = pause_button_rects(vp)
	UiButtons.draw_button(self, buttons[0], tr(TEXT_RESUME), UiButtons.Style.PRIMARY, UiButtons.is_pressed_at(self, buttons[0]), true, PAUSE_BUTTON_FONT_SIZE)
	UiButtons.draw_button(self, buttons[1], tr(TEXT_BACK), UiButtons.Style.SECONDARY, UiButtons.is_pressed_at(self, buttons[1]), true, PAUSE_BUTTON_FONT_SIZE)


func _draw_notice(vp: Vector2) -> void:
	var band: Rect2 = ScreenLayout.map_notice_rect(vp)
	HudSkin.panel(self, band, [0.0, HudSkin.BUTTON_CUT_MAX, 0.0, HudSkin.BUTTON_CUT_MAX], NOTICE_BACK, NOTICE_OUTLINE, OUTLINE_WIDTH)
	_text(band, band.position.y + band.size.y * NOTICE_BASELINE, tr(_notice), NOTICE_FONT_SIZE, NOTICE_TEXT, true)
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
		KIND_SHOP:
			return GLYPH_SHOP
		KIND_EVENT:
			return GLYPH_EVENT
		KIND_FORGE:
			return GLYPH_FORGE
	return GLYPH_BATTLE


# Alpha of the selection pointer (a slow sine pulse).
func _pulse_alpha() -> float:
	var t: float = fmod(Time.get_ticks_msec() / 1000.0, PULSE_PERIOD_SEC) / PULSE_PERIOD_SEC
	return lerpf(PULSE_MIN_ALPHA, 1.0, 0.5 + 0.5 * sin(t * TAU))


# Centred single-line outlined menu text at baseline [param y] over the width of [param rect].
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, bold: bool = false) -> void:
	MenuFont.text(self, Vector2(rect.position.x, y), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, bold)


# Story 032: the relic strip shows in the bottom-left corner while this screen is up (nothing covering it); its card
# closes otherwise.
func _sync_strip() -> void:
	var shown: bool = _is_active() and _flow.get_pending_reward().is_empty() and _notice.is_empty() and not _paused
	if not shown:
		_strip.close_tooltip()
	_strip.visible = shown
	if shown:
		_strip.area = ScreenLayout.map_relic_strip_rect(get_viewport_rect().size)
		_strip.set_relics(_flow.get_relics())

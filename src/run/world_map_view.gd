class_name WorldMapView
extends Node2D
## World map screen (Story 031, Part D): the region pick at the start of every floor of a run.
## Title band: "Về title" (NEUTRAL, ScreenLayout.back_button_rect, hit-tested on
## ScreenLayout.touch_rect -> [method GameFlow.leave_run_keep_save]), "Tầng N/5 · Chọn vùng" and the
## hero's HP at the right. Under it a progress strip (ScreenLayout.world_strip_segment_rects): one
## segment per floor plus the final match ("Ấn Đài"); passed floors are filled and name the region
## chosen there, the current floor is bright gold, later ones dimmed. In the middle the offered
## regions ([method GameFlow.get_region_offer]) as large cards (ScreenLayout.world_card_rects: two
## pinned left / right, one per thumb; one centred when the pool offers a single region), each
## naming the region, a one-line description of its arena / enemies, its boss and the floor's
## difficulty from [method GameFlow.region_preview] ("Tầng 3 — máu địch ×1,3" + tempo / armour /
## attack-size extras when they apply).
## Touch, two steps so a stray tap never commits: the first tap on a card selects it (the card
## rises, gold outline) and shows the big "Vào vùng" button at the bottom edge under it (that
## thumb's side); a tap on the selected card again or on the button -> [method GameFlow.choose_region].
## A tap on the other card moves the selection. A notice banner — the restart notice
## ([method GameFlow.take_restart_notice], a pre-v5 save was restarted) or the floor-clear notice
## ([method GameFlow.take_floor_clear_notice]: "Tầng N — hồi X máu", the screen the run lands on
## after a region boss) — shows until the first tap, which only closes it. Enter / Keypad Enter /
## Space pick the first offer (DEV convenience, as the other views). Child of GameFlow (reads it
## through [member flow_path]); draws and takes input only in phase WORLD_MAP; owns no run state.
## Input dedup as in RunHudView (emulated copies — device == InputEvent.DEVICE_ID_EMULATION — are
## consumed but never act). Placeholder art drawn in code; all strings are TEXT_* keys through tr().

## 2026-10-31 (whole-game HUD skin): colours for the dark screen background (HudSkin.SCREEN_BG); strip
## segments and region cards are HudSkin.card faces (GRID_LIGHT 3 px edge when current / selected).
const TITLE_COLOR: Color = HudSkin.IVORY
const HEADER_COLOR: Color = HudSkin.TEXT
## Progress strip segments: passed floor (green edge), current floor, later floor (faded), the final match.
const STRIP_PAST_OUTLINE: Color = Color("58D468")
const STRIP_FUTURE_OUTLINE: Color = HudSkin.CARD_LINE
const STRIP_FINAL_BACK: Color = Color("3D1F2A")
const STRIP_FINAL_OUTLINE: Color = Color("C7714A")
const STRIP_TEXT: Color = HudSkin.TEXT
const STRIP_DIM_TEXT: Color = HudSkin.TEXT_DIM
const STRIP_FINAL_TEXT: Color = HudSkin.GRID_LIGHT
## Region cards: outline (rest / pressed), the shadow left under a raised card, the header band colours
## (by card position, left first) and the text colours.
const CARD_OUTLINE: Color = HudSkin.CARD_LINE
const CARD_PRESSED_OUTLINE: Color = HudSkin.IVORY
const CARD_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.45)
const CARD_ACCENTS: Array[Color] = [Color("24473F"), Color("4A2A2C"), Color("35315A")]
const CARD_NAME_TEXT: Color = HudSkin.IVORY
const CARD_TEXT: Color = HudSkin.TEXT
const CARD_DESC_TEXT: Color = HudSkin.TEXT_DIM
## The boss line is gold, not red (red is kept for enemy telegraphs).
const CARD_BOSS_TEXT: Color = HudSkin.GRID_LIGHT
const CARD_HINT_TEXT: Color = HudSkin.TEXT_DIM
const CARD_HINT_SELECTED_TEXT: Color = HudSkin.GRID_LIGHT
const NOTICE_BACK: Color = Color(0.118, 0.106, 0.141, 0.97)
const NOTICE_OUTLINE: Color = HudSkin.IVORY
const NOTICE_TEXT: Color = HudSkin.IVORY
const NOTICE_SUB_TEXT: Color = HudSkin.TEXT_DIM
const CLEAR: Color = Color(0.0, 0.0, 0.0, 0.0)

const OUTLINE_WIDTH: float = 3.0
const SELECTED_OUTLINE_WIDTH: float = 8.0
const TITLE_FONT_SIZE: int = 40
## Story 042: the floor title shrinks step by step from TITLE_FONT_SIZE to fit the free span between
## the "Block set" button and the gold coin, not below this size (draw_string clips past that).
const TITLE_MIN_FONT_SIZE: int = 22
## Story 042: clear gap (px) kept between the floor title and the button / coin on each side.
const TITLE_SIDE_GAP: float = 16.0
const HEADER_FONT_SIZE: int = 24
const STRIP_FLOOR_FONT_SIZE: int = 20
const STRIP_REGION_FONT_SIZE: int = 16
const CARD_NAME_FONT_SIZE: int = 40
const CARD_DESC_FONT_SIZE: int = 22
const CARD_LINE_FONT_SIZE: int = 26
const CARD_EXTRA_FONT_SIZE: int = 20
const CARD_HINT_FONT_SIZE: int = 22
const MIN_FIT_FONT_SIZE: int = 14
const BUTTON_FONT_SIZE: int = 24
## Story 031: the back button text shrinks to fit, not below this size; inset per side (pixels).
const BACK_MIN_FONT_SIZE: int = 14
const BACK_TEXT_INSET: float = 6.0
const ENTER_FONT_SIZE: int = 36
## Story 033: the gold count left of the hero label (font size; gap in px).
const GOLD_FONT_SIZE: int = 26
const GOLD_GAP: float = 20.0
const NOTICE_FONT_SIZE: int = 30
const NOTICE_SUB_FONT_SIZE: int = 22
## The description may wrap to this many lines inside the card before it is cut.
const CARD_DESC_MAX_LINES: int = 2
## Strip segment baselines as shares of its height (floor label, region name).
const STRIP_FLOOR_BASELINE: float = 0.42
const STRIP_REGION_BASELINE: float = 0.82
## Card layout as shares of its height: the header band, the baselines of the name, the description
## (first line top), boss, difficulty, extras and the tap hint; the side inset as a share of its width.
const CARD_BAND_RATIO: float = 0.2
const CARD_NAME_BASELINE: float = 0.135
const CARD_DESC_TOP: float = 0.25
const CARD_BOSS_BASELINE: float = 0.55
const CARD_DIFFICULTY_BASELINE: float = 0.68
const CARD_EXTRA_BASELINE: float = 0.78
## World Map v2 briefing (01 section G1): the region's rule and "shop at the crossing" line, in ember.
const CARD_RULE_BASELINE: float = 0.86
const CARD_RULE_TEXT: Color = Color("F08A4B")
const TEXT_SHOP_HERE: String = "ui.world.shop_here"
const CARD_HINT_BASELINE: float = 0.93
const CARD_INSET_RATIO: float = 0.05
## Offset of the shadow a raised card leaves on its rest position (pixels).
const SHADOW_OFFSET: Vector2 = Vector2(6.0, 6.0)
## Notice banner baselines as shares of its height.
const NOTICE_BASELINE: float = 0.45
const NOTICE_SUB_BASELINE: float = 0.8
const SEPARATOR: String = " · "
## 2026-11-07 climb map: the dark band behind the header (share of the height), the region card panel beside the
## selected island (shares of the screen), the island tap margin (px) and the hero's scale on the map.
const HEADER_BAND: float = 0.17
## The concept's navy header band and the width (px) of the gold ornament each side of the title.
const HUD_NAVY: Color = Color("1C1A33")
const TITLE_ORNAMENT: float = 56.0
const PANEL_W: float = 0.3
const PANEL_TOP: float = 0.24
const PANEL_H: float = 0.45
const ISLAND_TOUCH_GROW: float = 16.0
## Art px between a hero frame's bottom and the feet, and the done tick's radius (px).
const HERO_FEET_FROM_BOTTOM: float = 4.0
const DONE_TICK_R: float = 9.0
## Path waypoints (radius px) and their colour ahead of the player.
const WAYPOINT_R: float = 7.0
## The climb panel: padding, emblem / icon size, the name / row / description font sizes and the row height (px).
const PANEL_PAD: float = 22.0
const PANEL_ICON: float = 26.0
const PANEL_NAME_SIZE: int = 36
const PANEL_ROW_SIZE: int = 24
const PANEL_DESC_SIZE: int = 20
const PANEL_ROW_H: float = 40.0
const TEXT_ENEMY_HP: String = "ui.world.enemy_hp"
const WAYPOINT_DIM: Color = Color("6A5F84")
## The floor label's baseline below the island rect's bottom, in label font heights.
const LABEL_DROP: float = 0.6
const DEV_SELECT_ARG: String = "--screen=climb_selected"

## "Tầng %d/%d · Chọn vùng": the current floor (1-based) and the floor count.
const TEXT_TITLE: String = "ui.world.title"
## "Tầng %d" on a strip segment.
const TEXT_STRIP_FLOOR: String = "ui.world.strip_floor"
## Story 038: " · Kiếp k" after the floor title while the run's Kiep level k is above 0.
const TEXT_KIEP: String = "ui.run.kiep"
## "Ấn Đài": the final match (strip segment, map title, HUD line).
const TEXT_FINAL_NAME: String = "ui.world.final_name"
## "Đang chọn" under the current floor's segment while no region is chosen there.
const TEXT_CHOOSING: String = "ui.world.choosing"
## "Boss: %s".
const TEXT_BOSS: String = "ui.world.boss"
## "Tầng %d — máu địch ×%s" (floor 1-based, the floor's hp_mult as a decimal).
const TEXT_DIFFICULTY: String = "ui.world.floor_difficulty"
## Extras of the floor scaling, each only when it changes something: "nhịp ×%s", "giáp +%d",
## "đòn +%d ô".
const TEXT_STEP: String = "ui.world.floor_step"
const TEXT_DEFENSE: String = "ui.world.floor_defense"
const TEXT_SIZE: String = "ui.world.floor_size"
## The decimal mark of the multipliers ("," in vi, "." in en).
const TEXT_DECIMAL_POINT: String = "ui.world.decimal_point"
## Tap hints at the card's bottom: "Chạm để chọn" / "Chạm lại để vào".
const TEXT_TAP_TO_PICK: String = "ui.world.tap_to_pick"
const TEXT_TAP_AGAIN: String = "ui.world.tap_again"
## The confirm button: "Vào vùng".
const TEXT_ENTER: String = "ui.world.enter"
## Floor-clear notice: "Tầng %d — hồi %d máu".
const TEXT_FLOOR_CLEAR: String = "ui.world.floor_clear"
## Floor-clear notice when the next match is the final one: "Ấn Đài — hồi %d máu".
const TEXT_FINAL_CLEAR: String = "ui.world.final_clear"
## Shared with ChapterMapView: back button, "HP %d/%d", the banner's "Chạm để đóng".
const TEXT_BACK: String = "ui.map.back"
## Story 034: the title band's "Bộ mảnh" button (ScreenLayout.map_piece_deck_button_rect) -> GameFlow.open_piece_deck.
const TEXT_PIECE_DECK: String = "ui.piece_deck.open"
const TEXT_HP: String = "ui.map.hp"
const TEXT_NOTICE_DISMISS: String = "ui.map.notice_dismiss"

## Path to the GameFlow (the parent by default).
@export var flow_path: NodePath = NodePath("..")

var _flow: GameFlow = null
## Story 032: owned-relic strip along the bottom band (tap an icon for its card).
var _strip: RelicStrip = null
## Region id of the selected card ("" = none): the first tap selects, the second confirms.
var _selected: String = ""
## 2026-11-07: clock (s) of the glow pulse and the hero's idle on the climb map.
var _time: float = 0.0
## DEV-ONLY (captures): `--screen=climb_selected` selects the current floor's island once.
var _dev_select: bool = false
## Banner shown until the first tap: a string key ("" = none) and its format args (may be empty).
var _notice_key: String = ""
var _notice_args: Array = []
## 2026-11-07 (user: "tôi ko kéo lên để xem các tầng ở trên đc"): drag (touch or mouse) or wheel to scroll the climb.
## _view_scroll < 0 = follow the current floor; a press becomes a tap only when it moved less than DRAG_SLOP px.
const DRAG_SLOP: float = 12.0
const WHEEL_STEP: float = 60.0
var _view_scroll: float = -1.0
var _view_floor: int = -1
var _press_at: Vector2 = Vector2.INF
var _press_scroll: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	# 2026-11-01: crisp pixel frames (PixelFrame) and the menu font (MenuFont) on every menu screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flow = get_node_or_null(flow_path) as GameFlow
	_strip = RelicStrip.new()
	add_child(_strip)
	_dev_select = OS.get_cmdline_user_args().has(DEV_SELECT_ARG)


func _process(delta: float) -> void:
	_time += delta
	if _dev_select and _is_active() and _selected.is_empty() and not _flow.get_region_offer().is_empty():
		_dev_select = false
		_selected = _flow.get_region_offer()[0]
	_sync_strip()
	if not _is_active():
		_selected = ""
		_notice_key = ""
		_notice_args = []
		_view_scroll = -1.0
		_press_at = Vector2.INF
		_dragging = false
		queue_redraw()  # clear the last frame (see TitleView)
		return
	if _notice_key.is_empty():
		_pull_notice()
	if not _selected.is_empty() and not _flow.get_region_offer().has(_selected):
		_selected = ""
	queue_redraw()


## Story 031: the floor-clear banner line of [param notice] ([method GameFlow.take_floor_clear_notice]):
## "Tầng N — hồi X máu" (N = floor_number, 1-based), or "Ấn Đài — hồi X máu" when the next match is
## the final one. Shared with ChapterMapView, which shows it when the run goes straight to the final map.
static func floor_clear_text(notice: Dictionary) -> String:
	var healed: int = roundi(float(notice.get("healed", 0.0)))
	if bool(notice.get("is_final", false)):
		return TranslationServer.translate(TEXT_FINAL_CLEAR) % healed
	var number: int = int(notice.get("floor_number", int(notice.get("floor", 0)) + 1))
	return TranslationServer.translate(TEXT_FLOOR_CLEAR) % [number, healed]


## Region id of the selected card ("" when none) — for tests.
func get_selected_region() -> String:
	return _selected


## Translation key of the banner on screen ("" when none) — for tests.
func get_notice_key() -> String:
	return _notice_key


func _is_active() -> bool:
	return _flow != null and _flow.get_phase() == GameFlow.Phase.WORLD_MAP and _flow.get_run() != null


# Takes the next banner from the flow: the restart notice first, then the floor-clear notice.
func _pull_notice() -> void:
	var restart: String = _flow.take_restart_notice()
	if not restart.is_empty():
		_notice_key = restart
		_notice_args = []
		return
	var clear: Dictionary = _flow.take_floor_clear_notice()
	if not clear.is_empty():
		_notice_key = floor_clear_text(clear)
		_notice_args = []


# --- Input --------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			if not _notice_key.is_empty():
				_close_notice()
				return
			var offer: Array[String] = _flow.get_region_offer()
			if not offer.is_empty():
				_flow.choose_region(offer[0])
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	if event.device != InputEvent.DEVICE_ID_EMULATION and _strip.visible and _strip.handle_input(event):
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var vp: Vector2 = get_viewport_rect().size
	if event is InputEventMouseButton:
		var wheel := event as InputEventMouseButton
		if wheel.pressed and (wheel.button_index == MOUSE_BUTTON_WHEEL_UP or wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var dy: float = WHEEL_STEP if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else -WHEEL_STEP
			_view_scroll = ClimbMap.dragged_scroll(vp, _flow.get_floor_count(), view_scroll(vp), dy)
			return
	var pos: Vector2 = _press_position(event)
	if pos != Vector2.INF:
		if not _notice_key.is_empty():
			_close_notice()
			return
		_press_at = pos
		_press_scroll = view_scroll(vp)
		_dragging = false
		return
	if _press_at == Vector2.INF:
		return
	var move: Vector2 = _drag_position(event)
	if move != Vector2.INF:
		if not _dragging and absf(move.y - _press_at.y) >= DRAG_SLOP:
			_dragging = true
			_selected = ""
		if _dragging:
			_view_scroll = ClimbMap.dragged_scroll(vp, _flow.get_floor_count(), _press_scroll, move.y - _press_at.y)
		return
	if _is_release(event):
		var at: Vector2 = _press_at
		var was_drag: bool = _dragging
		_press_at = Vector2.INF
		_dragging = false
		if not was_drag:
			_tap(at)


# One real tap at [param pos] (no banner open).
func _tap(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if ScreenLayout.touch_rect(ScreenLayout.back_button_rect(vp)).has_point(pos):
		_flow.leave_run_keep_save()
		return
	if ScreenLayout.touch_rect(ScreenLayout.map_piece_deck_button_rect(vp)).has_point(pos):
		_flow.open_piece_deck()
		return
	var offer: Array[String] = _flow.get_region_offer()
	if offer.is_empty():
		return
	var floors: int = _flow.get_floor_count()
	if not _selected.is_empty():
		var panel: Rect2 = climb_panel_rect(vp, _flow.get_floor(), floors)
		if ScreenLayout.world_enter_button_rect(vp, panel).has_point(pos):
			_confirm()
			return
	if current_island_rect(vp).has_point(pos):
		if _selected == offer[0]:
			_confirm()
		else:
			_selected = offer[0]
		return
	_selected = ""


func _confirm() -> void:
	var region: String = _selected
	_selected = ""
	_flow.choose_region(region)


# Closes the banner; the next one (a floor-clear notice after a restart notice) shows on the next frame.
func _close_notice() -> void:
	_notice_key = ""
	_notice_args = []


## The climb's scroll on screen now: the player's dragged view, else the current floor's.
func view_scroll(vp: Vector2) -> float:
	var floors: int = _flow.get_floor_count()
	if _view_floor != _flow.get_floor():
		_view_floor = _flow.get_floor()
		_view_scroll = -1.0
	if _view_scroll < 0.0:
		return ClimbMap.scroll_for(vp, _flow.get_floor(), floors)
	return clampf(_view_scroll, 0.0, ClimbMap.scroll_limit(vp, floors))


# Position of a left-held mouse move or a touch drag; Vector2.INF for any other event.
func _drag_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		return (event as InputEventMouseMotion).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.INF


# True for a left mouse release or a touch release.
func _is_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		return b.button_index == MOUSE_BUTTON_LEFT and not b.pressed
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	return false


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


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	if not _is_active():
		return
	var vp: Vector2 = get_viewport_rect().size
	_draw_climb(vp)
	# 2026-11-07 (the concept's navy-and-gold HUD): a navy band, a thin gold rule along its bottom with a dark line under
	# it, and a small gold diamond at each end of the rule.
	var band_h: float = floorf(vp.y * HEADER_BAND)
	draw_rect(Rect2(0.0, 0.0, vp.x, band_h), HUD_NAVY)
	draw_rect(Rect2(0.0, band_h - 3.0, vp.x, 2.0), Color(HudSkin.GRID_LIGHT, 0.75))
	draw_rect(Rect2(0.0, band_h - 1.0, vp.x, 2.0), ClimbMap.INK)
	for x: float in [ScreenLayout.side_margin(vp) * 0.5, vp.x - ScreenLayout.side_margin(vp) * 0.5]:
		HudSkin.diamond(self, Vector2(roundf(x), band_h - 2.0), 6.0, HudSkin.GRID_LIGHT, ClimbMap.INK, 1.5)
	_draw_header(vp)
	if not _notice_key.is_empty():
		_draw_notice(vp)


# 2026-11-07 (user: climb every region bottom to top; tap the floor's island, it lights up, tap again or press
# "Vào tầng"): the climb map (ClimbMap) scrolled to the current floor: sky, stairs (lit up to the current floor),
# the islands (done / current / future), the final cube, the hero on the current island; the selected island glows
# and its region card (the old WORLD_MAP card) opens beside it with the enter button.
func _draw_climb(vp: Vector2) -> void:
	var floors: int = _flow.get_floor_count()
	var floor: int = _flow.get_floor()
	var scroll: float = view_scroll(vp)
	var off := Vector2(0.0, -scroll)
	ClimbMap.draw_sky(self, vp, scroll, floors)
	_draw_cube(vp, off)
	# 2026-11-07 (user: the stairs did not connect to the land): islands first (far ones, then the current one), then
	# the stairs over them, so each stair starts ON the lower island's walk surface and climbs over the upper island's
	# front wall onto its walk surface; then the markers, the hero and the labels on top.
	# 2026-11-07 (user: the stairs must join the land in harmony): painter's order by depth, far to near: island i + 1,
	# then the stair from floor i up to it (over its front wall, landing on its walk surface), then island i (whose
	# ruins hide the stair's start: it leaves from the back corner facing the next island).
	var rects: Dictionary = {}
	for i: int in floors:
		var rr: Rect2 = ClimbMap.island_rect(vp, i, floors, floor)
		rr.position += off + Vector2(0.0, ClimbMap.island_bob(i, _time) * ClimbMap.map_scale(vp))
		rects[i] = rr
	var order: Array[int] = []
	for i: int in floors:
		order.append(i)
	for i: int in range(floors - 1, -1, -1):
		var r: Rect2 = rects[i]
		if r.end.y < 0.0 or r.position.y > vp.y:
			continue
		var region: String = climb_region(i)
		var tint: Color = ClimbMap.DONE_TINT if i < floor else (Color.WHITE if i == floor else ClimbMap.LOCKED_TINT)
		var glow: float = ClimbMap.glow_alpha(_time) if i == floor and not _selected.is_empty() else 0.0
		ClimbMap.draw_island(self, r, region, ArtAssets.fallback_bands(ArtAssets.region_for_chapter(region)), tint, glow, _time, float(i) * 1.7)
		ClimbMap.draw_island_fx(self, r, region, _time + float(i) * 0.9, tint)
	# 2026-11-07 (user: the route must join the middle points): a dashed line from each island's centre marker to the
	# next island's (the last one to the cube), over the islands, under the markers and the hero.
	for i: int in floors:
		var from: Vector2 = ClimbMap.anchor_point(rects[i], ClimbMap.island_info(climb_region(i))["marker"])
		var to: Vector2 = _summit_landing(vp, off)
		if i + 1 < floors:
			to = ClimbMap.anchor_point(rects[i + 1], ClimbMap.island_info(climb_region(i + 1))["marker"])
		if maxf(from.y, to.y) < 0.0 or minf(from.y, to.y) > vp.y:
			continue
		var rtint: Color = HudSkin.GRID_LIGHT if i < floor else (HudSkin.IVORY if i == floor else WAYPOINT_DIM)
		_draw_route(from, to, rtint)
	for i: int in order:
		var r: Rect2 = rects[i]
		if r.end.y < 0.0 or r.position.y > vp.y:
			continue
		var region: String = climb_region(i)
		var info: Dictionary = ClimbMap.island_info(region)
		if i < floor:
			_draw_done_tick(ClimbMap.anchor_point(r, info["marker"]))
		if i == floor:
			# The concept's gold node marker on the walk surface in front of the hero, then the hero.
			HudSkin.diamond(self, (ClimbMap.anchor_point(r, info["marker"])).round(), WAYPOINT_R * 1.2, HudSkin.GRID_LIGHT, ClimbMap.INK, 2.0)
			_draw_hero(ClimbMap.anchor_point(r, info["feet"]), ClimbMap.map_scale(vp))
		# Labels only on placeholder islands: a generated island is read by its art (the concept has no map labels).
		if ClimbMap.island_texture(region) != null:
			continue
		var label: String = tr(TEXT_STRIP_FLOOR) % (i + 1)
		var name: String = _flow.region_name(region) if not region.is_empty() else ""
		var color: Color = HudSkin.GRID_LIGHT if i == floor else (STRIP_TEXT if i < floor else STRIP_DIM_TEXT)
		var under := Rect2(r.position.x, r.end.y + STRIP_FLOOR_FONT_SIZE * LABEL_DROP, r.size.x, 0.0)
		_text(under, under.position.y, label, STRIP_FLOOR_FONT_SIZE, color, true)
		if not name.is_empty():
			_text(under, under.position.y + STRIP_FLOOR_FONT_SIZE + 6.0, name, _fit(name, under.size.x, STRIP_REGION_FONT_SIZE + 4), color)
	# 2026-11-07 (user: one gold point in the middle is enough): no diamonds at the route ends; each island keeps only its
	# centre marker (the current floor) or its done tick.
	if not _selected.is_empty() and floor < floors:
		var panel: Rect2 = climb_panel_rect(vp, floor, floors)
		_draw_climb_panel(panel, _selected)
		var button: Rect2 = ScreenLayout.world_enter_button_rect(vp, panel)
		UiButtons.draw_button(self, button, tr(TEXT_ENTER), UiButtons.Style.PRIMARY, UiButtons.is_pressed_at(self, button), true, ENTER_FONT_SIZE)


# 2026-11-07 (the concept's region panel): an ancient plate with the region's name under a small emblem, a gold rule
# with a diamond, three icon rows (floor, warden, enemy HP) and the region's description under a second rule.
func _draw_climb_panel(rect: Rect2, region: String) -> void:
	var body: Rect2 = HudSkin.plate_panel(self, rect, "navy")
	var pad: float = PANEL_PAD
	var inner := Rect2(body.position.x + pad, body.position.y + pad, body.size.x - pad * 2.0, body.size.y - pad * 2.0)
	var preview: Dictionary = _flow.region_preview(region)
	var name: String = str(preview.get("name", _flow.region_name(region)))
	var y: float = inner.position.y + PANEL_NAME_SIZE
	_draw_emblem(Vector2(inner.position.x + PANEL_ICON * 0.5, y - PANEL_NAME_SIZE * 0.35))
	var name_box := Rect2(inner.position.x + PANEL_ICON + 8.0, y, inner.size.x - PANEL_ICON - 8.0, 0.0)
	MenuFont.text(self, Vector2(name_box.position.x, y), name, _fit(name, name_box.size.x, PANEL_NAME_SIZE, true), CARD_NAME_TEXT, HORIZONTAL_ALIGNMENT_LEFT, name_box.size.x, true)
	y = _panel_rule(inner, y + 14.0)
	var scaling: Dictionary = preview.get("floor_scaling", {})
	var rows: Array = [
		["floor", tr(TEXT_STRIP_FLOOR) % int(preview.get("floor_number", _flow.get_floor() + 1)), CARD_TEXT],
		["warden", tr(TEXT_BOSS) % tr(str(preview.get("boss_name", ""))), CARD_BOSS_TEXT],
		["hp", tr(TEXT_ENEMY_HP) % _decimal(float(scaling.get("hp_mult", 1.0))), CARD_TEXT],
	]
	# World Map v2 briefing (01 section G1): the region's rule (its name and one line) and the shop plan.
	var rule: Dictionary = preview.get("rule", {}) if typeof(preview.get("rule")) == TYPE_DICTIONARY else {}
	var rule_parts: Array[String] = []
	if not rule.is_empty() and not str(rule.get("name_key", "")).is_empty():
		rule_parts.append(tr(str(rule["name_key"])))
	if bool(preview.get("has_shop", false)):
		rule_parts.append(tr(TEXT_SHOP_HERE))
	if not rule_parts.is_empty():
		rows.append(["rule" if not rule.is_empty() else "shop", SEPARATOR.join(rule_parts), CARD_RULE_TEXT if not rule.is_empty() else CARD_TEXT])
	for row: Array in rows:
		y += PANEL_ROW_H
		_draw_row_icon(str(row[0]), Vector2(inner.position.x + PANEL_ICON * 0.5, y - PANEL_ROW_SIZE * 0.35))
		var tx: float = inner.position.x + PANEL_ICON + 10.0
		MenuFont.text(self, Vector2(tx, y), str(row[1]), _fit(str(row[1]), inner.end.x - tx, PANEL_ROW_SIZE), row[2] as Color, HORIZONTAL_ALIGNMENT_LEFT, inner.end.x - tx)
	y = _panel_rule(inner, y + 16.0)
	var desc: String = _preview_desc(preview)
	if rows.size() > 3 and not desc.is_empty():
		# World Map v2: with the rule / shop row the plate has room for the description's first clause only.
		var cut: int = desc.length()
		for mark: String in [";", "."]:
			var at: int = desc.find(mark)
			if at > 0 and at < cut:
				cut = at
		desc = desc.left(cut).strip_edges()
	if not desc.is_empty():
		var f: Font = HudSkin.font()
		var pos := Vector2(inner.position.x, y + PANEL_DESC_SIZE + 6.0)
		# World Map v2: each row above the three fixed ones (the rule / shop line) costs the description two of its four lines.
		var max_lines: int = clampi(4 - 2 * (rows.size() - 3), 1, 4)
		draw_multiline_string_outline(f, pos, desc, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, PANEL_DESC_SIZE, max_lines, HudSkin.TEXT_OUTLINE_PX, HudSkin.TEXT_OUTLINE)
		draw_multiline_string(f, pos, desc, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, PANEL_DESC_SIZE, max_lines, CARD_DESC_TEXT)


# A thin gold rule across [param inner] at [param y] with a small diamond in its middle; returns the y under it.
func _panel_rule(inner: Rect2, y: float) -> float:
	draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(HudSkin.GRID_LIGHT, 0.7), 2.0)
	HudSkin.diamond(self, Vector2(inner.get_center().x, y).round(), 5.0, HudSkin.GRID_LIGHT, ClimbMap.INK, 1.0)
	return y + 6.0


# The region emblem left of the name: a gold diamond with an Ink inner diamond (angular, no circle).
func _draw_emblem(c: Vector2) -> void:
	HudSkin.diamond(self, c.round(), PANEL_ICON * 0.42, HudSkin.GRID_LIGHT, ClimbMap.INK, 2.0)
	HudSkin.diamond(self, c.round(), PANEL_ICON * 0.18, ClimbMap.INK, ClimbMap.INK, 1.0)


# A code-drawn angular row icon centred at [param c]: "floor" = three stair steps, "warden" = a horned helm,
# "hp" = two crossed blades.
func _draw_row_icon(kind: String, c: Vector2) -> void:
	var u: float = PANEL_ICON / 8.0
	var col: Color = HudSkin.IVORY
	match kind:
		"floor":
			for i: int in 3:
				draw_rect(Rect2(c + Vector2(-4.0 * u + i * 2.6 * u, 2.0 * u - i * 2.0 * u), Vector2(2.6 * u, 2.0 * u + i * 2.0 * u)).abs(), col)
		"rule":
			# World Map v2: the region rule's angular flame (HudSkin.flame_points) in ember.
			draw_colored_polygon(HudSkin.flame_points(c + Vector2(0.0, 3.5 * u), 7.0 * u), CARD_RULE_TEXT)
		"shop":
			# World Map v2: a chamfered pouch with a slit (no circle).
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3 * u, -1 * u), c + Vector2(3 * u, -1 * u), c + Vector2(3.5 * u, 3.5 * u),
				c + Vector2(-3.5 * u, 3.5 * u)]), col)
			draw_rect(Rect2(c + Vector2(-1.5 * u, -3.5 * u), Vector2(3 * u, 2.2 * u)), col)
			draw_rect(Rect2(c + Vector2(-1.2 * u, 0.6 * u), Vector2(2.4 * u, 0.8 * u)), ClimbMap.INK)
		"warden":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3 * u, -1 * u), c + Vector2(3 * u, -1 * u), c + Vector2(2.4 * u, 3 * u),
				c + Vector2(-2.4 * u, 3 * u)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3 * u, -1 * u), c + Vector2(-4 * u, -4 * u), c + Vector2(-1.6 * u, -1 * u)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(3 * u, -1 * u), c + Vector2(4 * u, -4 * u), c + Vector2(1.6 * u, -1 * u)]), col)
			draw_rect(Rect2(c + Vector2(-1.8 * u, 0.4 * u), Vector2(1.2 * u, 0.9 * u)), ClimbMap.INK)
			draw_rect(Rect2(c + Vector2(0.6 * u, 0.4 * u), Vector2(1.2 * u, 0.9 * u)), ClimbMap.INK)
		_:
			draw_line(c + Vector2(-3.5 * u, -3.5 * u), c + Vector2(3.5 * u, 3.5 * u), col, maxf(u, 2.0))
			draw_line(c + Vector2(3.5 * u, -3.5 * u), c + Vector2(-3.5 * u, 3.5 * u), col, maxf(u, 2.0))
			draw_line(c + Vector2(-3.5 * u, 1.5 * u), c + Vector2(-1.5 * u, 3.5 * u), col, maxf(u, 2.0))
			draw_line(c + Vector2(3.5 * u, 1.5 * u), c + Vector2(1.5 * u, 3.5 * u), col, maxf(u, 2.0))


# A dashed route between two islands (12 px dashes, 8 px gaps) in [param tint], 3 px wide.
func _draw_route(from: Vector2, to: Vector2, tint: Color) -> void:
	var length: float = from.distance_to(to)
	var dir: Vector2 = (to - from) / maxf(length, 1.0)
	var at: float = 0.0
	while at < length:
		draw_line(from + dir * at, from + dir * minf(at + 12.0, length), Color(tint, 0.7), 3.0)
		at += 20.0


# A path waypoint: a small diamond, gold on the walked / current route, muted violet ahead (the concept's markers).
func _draw_waypoint(at: Vector2, lit: bool) -> void:
	HudSkin.diamond(self, at.round(), WAYPOINT_R, HudSkin.GRID_LIGHT if lit else WAYPOINT_DIM, ClimbMap.INK, 2.0)


# A done floor's tick: a small gold diamond with an Ink rim at [param at] (angular, no circle).
func _draw_done_tick(at: Vector2) -> void:
	HudSkin.diamond(self, at.round(), DONE_TICK_R, HudSkin.GRID_LIGHT, ClimbMap.INK, 2.0)


## 2026-11-07: the region of 0-based floor [param index] on the climb map: the one walked (region path), the one
## offered now, else the fixed climb order (ChaptersConfig.region_order); "" when unknown.
func climb_region(index: int) -> String:
	var path: Array[String] = _flow.get_region_path()
	if index < path.size() and index != _flow.get_floor():
		return path[index]
	var offer: Array[String] = _flow.get_region_offer()
	if index == _flow.get_floor() and not offer.is_empty():
		return offer[0]
	if index < path.size():
		return path[index]
	var order: Array[String] = _flow.get_config().region_order()
	return order[index] if index < order.size() else ""


## 2026-11-07: the current floor's island on screen (the tap target, a little larger than the drawn island).
func current_island_rect(vp: Vector2) -> Rect2:
	var floors: int = _flow.get_floor_count()
	var floor: int = mini(_flow.get_floor(), floors - 1)
	var r: Rect2 = ClimbMap.island_rect(vp, floor, floors, floor)
	r.position.y -= view_scroll(vp)
	return r.grow(ISLAND_TOUCH_GROW)


## 2026-11-07: the region card panel beside island [param floor] (the screen half away from the island).
static func climb_panel_rect(vp: Vector2, floor: int, floors: int) -> Rect2:
	var left_island: bool = ClimbMap.island_center(vp, floor, floors).x < vp.x * 0.5
	var w: float = vp.x * PANEL_W
	var margin: float = ScreenLayout.side_margin(vp)
	var x: float = vp.x - margin - w if left_island else margin
	return Rect2(x, vp.y * PANEL_TOP, w, vp.y * PANEL_H)


# The final cube: the Lattice Heart cropped from the title art (whole-number scale, nearest).
func _draw_cube(vp: Vector2, off: Vector2) -> void:
	# 2026-11-07: the live Lattice Heart summit sprite when present (bobbing heart, pulsing seams); else the title crop.
	if ClimbMap.draw_summit(self, vp, ClimbMap.cube_center(vp) + off, _time):
		return
	var src: Rect2 = ClimbMap.CUBE_SRC
	var k: float = ClimbMap.map_scale(vp) * ClimbMap.CUBE_SCALE
	var size: Vector2 = src.size * k
	var dst := Rect2((ClimbMap.cube_center(vp) + off - size * 0.5).round(), size)
	if dst.end.y < 0.0:
		return
	draw_texture_rect_region(PixelFrame.nearest(TitleView.KEY_ART), dst, src)


# Where the route reaches the summit: its platform (ClimbMap.SUMMIT_LANDING), else below the title-crop cube.
func _summit_landing(vp: Vector2, off: Vector2) -> Vector2:
	var r: Rect2 = ClimbMap.summit_rect(vp, ClimbMap.cube_center(vp) + off)
	if r.size == Vector2.ZERO:
		return ClimbMap.cube_center(vp) + off + Vector2(0.0, vp.y * 0.12)
	return r.position + ClimbMap.SUMMIT_LANDING * ClimbMap.map_scale(vp)


# The hero's idle frame (the real sheet, whole-number [param k] like the islands) with its feet at [param feet].
func _draw_hero(feet: Vector2, k: float) -> void:
	var sheet: SpriteSheet = SpriteSheet.load_unit(_flow.get_run().character_id)
	if sheet == null or sheet.texture() == null or not sheet.has_clip("idle"):
		return
	var clip: Dictionary = sheet.clip("idle")
	var index: int = CharacterSelectView.clip_frame_at(clip, _time)
	if index < 0:
		return
	var src: Rect2i = (clip["frames"] as Array)[index]
	var size := Vector2(src.size) * k
	# The sheet's feet sit HERO_FEET_FROM_BOTTOM art px above the frame's bottom (the battle's UnitLayer rule).
	var pos := Vector2(feet.x - size.x * 0.5, feet.y - size.y + HERO_FEET_FROM_BOTTOM * k)
	draw_texture_rect_region(PixelFrame.nearest(sheet.texture()), Rect2(pos.round(), size), Rect2(src))


# Title band: back button, "Tầng N/5 · Chọn vùng", the hero's HP at the right.
func _draw_header(vp: Vector2) -> void:
	var title: Rect2 = ScreenLayout.floor_title_rect(vp)
	var back: Rect2 = ScreenLayout.back_button_rect(vp)
	var back_text: String = tr(TEXT_BACK)
	UiButtons.draw_button(self, back, back_text, UiButtons.Style.NEUTRAL, UiButtons.is_pressed_at(self, ScreenLayout.touch_rect(back)), true, _back_font_size(back_text, back.size.x), OUTLINE_WIDTH)
	var deck_button: Rect2 = ScreenLayout.map_piece_deck_button_rect(vp)
	var deck_text: String = tr(TEXT_PIECE_DECK)
	UiButtons.draw_button(self, deck_button, deck_text, UiButtons.Style.SECONDARY, UiButtons.is_pressed_at(self, ScreenLayout.touch_rect(deck_button)), true, _back_font_size(deck_text, deck_button.size.x), OUTLINE_WIDTH)
	var run: RunSession = _flow.get_run()
	var character: Dictionary = _flow.get_characters().get_character(run.character_id)
	var max_hp: float = float(character.get("max_hp", 1.0))
	var hp: float = max_hp if run.hp < 0.0 else minf(run.hp, max_hp)
	var label: String = tr(str(character.get("name_key", run.character_id))) + SEPARATOR + tr(TEXT_HP) % [ceili(hp), ceili(max_hp)]
	var rect: Rect2 = ScreenLayout.floor_hero_label_rect(vp)
	MenuFont.text(self, Vector2(rect.position.x, rect.get_center().y + HEADER_FONT_SIZE * 0.35), label, HEADER_FONT_SIZE, HEADER_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x)
	# Story 033: the gold count (code-drawn coin + number) left of the hero label.
	var label_width: float = HudSkin.text_width(label, HEADER_FONT_SIZE)
	var coin_left: float = ShopView.draw_gold(self, rect.end.x - label_width - GOLD_GAP, rect.get_center().y, _flow.get_gold(), GOLD_FONT_SIZE, HudSkin.GRID_LIGHT)
	# Story 042: the floor title is centred in the free span between the "Block set" button and the
	# gold coin (never under either), shrunk until it fits that span.
	var count: int = _flow.get_floor_count()
	var text: String = tr(TEXT_TITLE) % [mini(_flow.get_floor() + 1, count), count]
	if _flow.get_run_kiep_level() > 0:
		text += SEPARATOR + tr(TEXT_KIEP) % _flow.get_run_kiep_level()
	var span_left: float = deck_button.end.x + TITLE_SIDE_GAP
	var span: Rect2 = Rect2(span_left, title.position.y, maxf(coin_left - TITLE_SIDE_GAP - span_left, 0.0), title.size.y)
	var size: int = _title_font_size(text, span.size.x - TITLE_ORNAMENT * 2.0)
	_text(span, span.get_center().y + size * 0.35, text, size, TITLE_COLOR, true)
	# The concept's title ornaments: a short gold line ending in a diamond on each side of the title.
	var half: float = HudSkin.text_width(text, size, true) * 0.5 + 14.0
	var cy: float = roundf(span.get_center().y)
	for side: float in [-1.0, 1.0]:
		var inner: float = span.get_center().x + side * half
		var outer: float = inner + side * (TITLE_ORNAMENT - 18.0)
		draw_line(Vector2(inner, cy), Vector2(outer, cy), Color(HudSkin.GRID_LIGHT, 0.8), 2.0)
		HudSkin.diamond(self, Vector2(roundf(inner + side * 6.0), cy), 5.0, HudSkin.GRID_LIGHT, ClimbMap.INK, 1.0)


# Story 042: the floor title's font, shrunk one step at a time from TITLE_FONT_SIZE until
# [param text] fits [param width]; never below TITLE_MIN_FONT_SIZE (draw_string clips the rest).
func _title_font_size(text: String, width: float) -> int:
	var size: int = TITLE_FONT_SIZE
	while size > TITLE_MIN_FONT_SIZE and HudSkin.text_width(text, size, true) > width:
		size -= 1
	return size


# Progress strip: one segment per floor, then the final match.
func _draw_strip(vp: Vector2) -> void:
	var count: int = _flow.get_floor_count()
	var floor_index: int = _flow.get_floor()
	var path: Array[String] = _flow.get_region_path()
	var segments: Array[Rect2] = ScreenLayout.world_strip_segment_rects(vp, count + 1)
	for i: int in segments.size():
		var rect: Rect2 = segments[i]
		var width: float = OUTLINE_WIDTH
		var color: Color = STRIP_DIM_TEXT
		var label: String = tr(TEXT_STRIP_FLOOR) % (i + 1)
		var region: String = ""
		var cuts: Array = [0.0, HudSkin.button_cut(rect), 0.0, 0.0]
		if i == count:
			var current_final: bool = floor_index >= count
			width = SELECTED_OUTLINE_WIDTH if current_final else OUTLINE_WIDTH
			HudSkin.plate_panel(self, rect, "wine", false, 1.0, current_final)
			color = STRIP_FINAL_TEXT
			label = tr(TEXT_FINAL_NAME)
		elif i < floor_index:
			HudSkin.plate_panel(self, rect, "navy")
			color = STRIP_TEXT
		elif i == floor_index:
			width = SELECTED_OUTLINE_WIDTH
			HudSkin.plate_panel(self, rect, "navy", false, 1.0, true)
			color = STRIP_TEXT
			region = tr(TEXT_CHOOSING)
		else:
			HudSkin.plate_panel(self, rect, "grey")
		if i < count and i < path.size():
			region = _flow.region_name(path[i])
		var inner: float = rect.size.x - width * 2.0
		_text(rect, rect.position.y + rect.size.y * STRIP_FLOOR_BASELINE, label, _fit(label, inner, STRIP_FLOOR_FONT_SIZE, true), color, true)
		if not region.is_empty():
			_text(rect, rect.position.y + rect.size.y * STRIP_REGION_BASELINE, region, _fit(region, inner, STRIP_REGION_FONT_SIZE), color)


# One region card at rest rect [param base] (raised when selected).
func _draw_card(vp: Vector2, base: Rect2, region_id: String, index: int) -> void:
	var selected: bool = region_id == _selected
	var rect: Rect2 = base
	var outline: Color = CARD_OUTLINE
	if selected:
		HudSkin.panel(self, Rect2(base.position + SHADOW_OFFSET, base.size), [0.0, HudSkin.button_cut(base), 0.0, 0.0], CARD_SHADOW, CLEAR, 0.0)
		rect.position.y -= ScreenLayout.world_card_raise(vp)
	elif UiButtons.is_pressed_at(self, ScreenLayout.world_card_touch_rect(vp, base)):
		outline = CARD_PRESSED_OUTLINE
	var preview: Dictionary = _flow.region_preview(region_id)
	# 2026-10-31: card face, the accent header band inside its chamfer, then the edge again on top of the band.
	# 2026-11-07: the ancient plate (sunk while pressed, gold ring when selected), the region's accent band inside its
	# inner gold line.
	var body: Rect2 = HudSkin.plate_panel(self, rect, "navy", outline == CARD_PRESSED_OUTLINE, 1.0, selected)
	var inset: float = UiButtons.plate_inset(UiButtons.ui_scale(self))
	var inner_body: Rect2 = body.grow(-inset)
	var band: Rect2 = Rect2(inner_body.position, Vector2(inner_body.size.x, rect.size.y * CARD_BAND_RATIO - inset))
	draw_rect(band, CARD_ACCENTS[index % CARD_ACCENTS.size()])
	var inner: float = rect.size.x * (1.0 - CARD_INSET_RATIO * 2.0)
	var region_name: String = str(preview.get("name", _flow.region_name(region_id)))
	_card_line(rect, CARD_NAME_BASELINE, region_name, CARD_NAME_FONT_SIZE, CARD_NAME_TEXT, inner, true)
	var desc: String = _preview_desc(preview)
	if not desc.is_empty():
		var top: float = rect.position.y + rect.size.y * CARD_DESC_TOP + CARD_DESC_FONT_SIZE
		var desc_pos := Vector2(rect.position.x + rect.size.x * CARD_INSET_RATIO, top)
		var desc_font: Font = HudSkin.font()
		draw_multiline_string_outline(desc_font, desc_pos, desc, HORIZONTAL_ALIGNMENT_CENTER, inner, CARD_DESC_FONT_SIZE, CARD_DESC_MAX_LINES, HudSkin.TEXT_OUTLINE_PX, HudSkin.TEXT_OUTLINE)
		draw_multiline_string(desc_font, desc_pos, desc, HORIZONTAL_ALIGNMENT_CENTER, inner, CARD_DESC_FONT_SIZE, CARD_DESC_MAX_LINES, CARD_DESC_TEXT)
	var boss: String = str(preview.get("boss_name", ""))
	if not boss.is_empty():
		_card_line(rect, CARD_BOSS_BASELINE, tr(TEXT_BOSS) % tr(boss), CARD_LINE_FONT_SIZE, CARD_BOSS_TEXT, inner, true)
	var scaling: Dictionary = preview.get("floor_scaling", {})
	var floor_number: int = _flow.get_floor() + 1
	_card_line(rect, CARD_DIFFICULTY_BASELINE, tr(TEXT_DIFFICULTY) % [floor_number, _decimal(float(scaling.get("hp_mult", 1.0)))], CARD_LINE_FONT_SIZE, CARD_TEXT, inner)
	var extras: String = _scaling_extras(scaling)
	if not extras.is_empty():
		_card_line(rect, CARD_EXTRA_BASELINE, extras, CARD_EXTRA_FONT_SIZE, CARD_DESC_TEXT, inner)
	var rule: Dictionary = preview.get("rule", {}) if typeof(preview.get("rule")) == TYPE_DICTIONARY else {}
	var rule_parts: Array[String] = []
	if not rule.is_empty() and not str(rule.get("name_key", "")).is_empty():
		rule_parts.append(tr(str(rule["name_key"])))
	if bool(preview.get("has_shop", false)):
		rule_parts.append(tr(TEXT_SHOP_HERE))
	if not rule_parts.is_empty():
		_card_line(rect, CARD_RULE_BASELINE, SEPARATOR.join(rule_parts), CARD_EXTRA_FONT_SIZE, CARD_RULE_TEXT, inner)
	var hint: String = tr(TEXT_TAP_AGAIN if selected else TEXT_TAP_TO_PICK)
	_card_line(rect, CARD_HINT_BASELINE, hint, CARD_HINT_FONT_SIZE, CARD_HINT_SELECTED_TEXT if selected else CARD_HINT_TEXT, inner)


# The region's one-line description: a key (desc_key) or ready text (desc); "" when neither.
func _preview_desc(preview: Dictionary) -> String:
	var key: String = str(preview.get("desc_key", ""))
	if not key.is_empty():
		return tr(key)
	return str(preview.get("desc", ""))


# "nhịp ×0,9 · giáp +1 · đòn +1 ô": only the parts that change the floor's matches.
func _scaling_extras(scaling: Dictionary) -> String:
	var parts: Array[String] = []
	var step: float = float(scaling.get("step_mult", 1.0))
	if not is_equal_approx(step, 1.0):
		parts.append(tr(TEXT_STEP) % _decimal(step))
	var defense: int = int(scaling.get("defense_add", 0))
	if defense != 0:
		parts.append(tr(TEXT_DEFENSE) % defense)
	var size_add: int = int(scaling.get("size_add", 0))
	if size_add != 0:
		parts.append(tr(TEXT_SIZE) % size_add)
	return SEPARATOR.join(parts)


# A multiplier as text with at most two decimals and no trailing zeros, in the locale's decimal mark.
func _decimal(value: float) -> String:
	var text: String = String.num(value, 2)
	return text.replace(".", tr(TEXT_DECIMAL_POINT))


func _draw_notice(vp: Vector2) -> void:
	var band: Rect2 = ScreenLayout.map_notice_rect(vp)
	HudSkin.plate_panel(self, band, "navy")
	var text: String = tr(_notice_key) % _notice_args if not _notice_args.is_empty() else tr(_notice_key)
	_text(band, band.position.y + band.size.y * NOTICE_BASELINE, text, _fit(text, band.size.x - ScreenLayout.side_margin(vp) * 2.0, NOTICE_FONT_SIZE, true), NOTICE_TEXT, true)
	_text(band, band.position.y + band.size.y * NOTICE_SUB_BASELINE, tr(TEXT_NOTICE_DISMISS), NOTICE_SUB_FONT_SIZE, NOTICE_SUB_TEXT)


# A centred card line at baseline share [param share] of [param rect], shrunk to fit [param width].
func _card_line(rect: Rect2, share: float, text: String, size: int, color: Color, width: float, bold: bool = false) -> void:
	_text(rect, rect.position.y + rect.size.y * share, text, _fit(text, width, size, bold), color, bold)


# Largest font size <= [param size] (never below MIN_FIT_FONT_SIZE) at which [param text] fits [param width]
# in the HudSkin font ([param bold] picks Bold).
func _fit(text: String, width: float, size: int, bold: bool = false) -> int:
	var fitted: int = size
	while fitted > MIN_FIT_FONT_SIZE and HudSkin.text_width(text, fitted, bold) > width:
		fitted -= 1
	return fitted


# Centred single-line outlined HUD text at baseline [param y] over the width of [param rect] (Bold when [param bold]).
func _text(rect: Rect2, y: float, text: String, size: int, color: Color, bold: bool = false) -> void:
	MenuFont.text(self, Vector2(rect.position.x, y), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, bold)


# Story 031: the back button's font, shrunk until [param text] fits [param width] minus a small inset
# ("Back to title" is wider than the 128 px button at BUTTON_FONT_SIZE).
func _back_font_size(text: String, width: float) -> int:
	var size: int = BUTTON_FONT_SIZE
	while size > BACK_MIN_FONT_SIZE and HudSkin.text_width(text, size, true) > width - BACK_TEXT_INSET * 2.0:
		size -= 1
	return size


# Story 032: the relic strip shows while this screen is up (nothing covering it); its card closes otherwise.
func _sync_strip() -> void:
	var shown: bool = _is_active() and _notice_key.is_empty()
	if not shown:
		_strip.close_tooltip()
	_strip.visible = shown
	if shown:
		_strip.area = ScreenLayout.relic_strip_rect(get_viewport_rect().size)
		_strip.set_relics(_flow.get_relics())

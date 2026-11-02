class_name ScreenLayout
extends RefCounted
## Landscape screen layout (phone held sideways). Pure geometry (no nodes): every function
## takes the viewport size and returns rectangles in viewport (canvas) pixels. Ratios are
## layout constants, not tuning. Reference viewport is 1280x720 (see project.godot).
## Control layout v2 (Story 044, design/quick-specs/control-layout-v2.md): the arena (HUD band
## + board) runs 0.03-0.64 of the height for wide board rows and down to 0.76 for rows that sit
## inside the thumb gap; the left thumb owns the stick zone (x 0-25 %, y 64-100 %), the Awaken button sits
## bottom-centre.
## Controls v3 (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md): the bag is one straight row of three 64 px
## sockets in the bottom-right corner; while placing, the bottom-left row [Tung phép][Xoay][Hủy] (64 px tall, the
## same bottom edge) replaces the stick; relics and buffs / debuffs in the top-left corner, gold and pause in the
## top-right. Every control has a visual rect and an invisible hit rect of up to CONTROL_HIT_PX (720p px).
## The board size and shape come from a BoardGrid, passed as the first parameter of every
## board function; nothing here knows how many cells there are.

## Horizontal screen margin as a share of viewport width.
const MARGIN_RATIO: float = 0.03
## Arena: top edge as a share of viewport height.
const ARENA_TOP_RATIO: float = 0.03
## Quick spec section 4 (tuning knobs). Lowest edge of a board row that extends outside the thumb
## gap (and of the arena / board area), and of a row that sits fully inside it, as shares of the height.
const ARENA_BOTTOM_WIDE_RATIO: float = 0.64
const ARENA_BOTTOM_NARROW_RATIO: float = 0.76
## Thumb gap: the horizontal span (shares of the width) between the stick zone and the first hold
## slot; a board row fully inside it may reach ARENA_BOTTOM_NARROW_RATIO.
const THUMB_GAP_LEFT_RATIO: float = 0.25
const THUMB_GAP_RIGHT_RATIO: float = 0.764
## Stick zone (Z3): width as a share of the viewport width; it spans from the wide arena bottom
## to the bottom of the screen.
const STICK_ZONE_WIDTH_RATIO: float = 0.25
## Controls v3 (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md): every HUD size below is in px at the
## 720p reference height (CONTROLS_REF_HEIGHT) and scales with height / 720 like the rest of the battle HUD.
## Inset of the HUD from the screen edges (top-left relics, top-right pause, both bottom rows).
const CONTROLS_REF_HEIGHT: float = 720.0
const HUD_EDGE_INSET_PX: float = 12.0
## The two thumb rows (bottom-left Tung phép / Xoay / Hủy, bottom-right bag sockets): one height, one bottom edge.
const BOTTOM_ROW_HEIGHT_PX: float = 64.0
const BOTTOM_ROW_GAP_PX: float = 10.0
const CAST_WIDTH_PX: float = 100.0
const ROTATE_WIDTH_PX: float = 64.0
const CANCEL_WIDTH_PX: float = 72.0
## Bag socket (Z5): a square stone socket.
const SOCKET_PX: float = 64.0
## Invisible hit rect of a control: grown to this side around its visual (720p px), never into a neighbour's hit
## rect (the gap between two visuals is split in the middle); the outermost controls reach the screen edge.
const CONTROL_HIT_PX: float = 96.0
## Awaken button (Z4): a square of this share of the height, centred, half a margin above the bottom.
const AWAKEN_BUTTON_RATIO: float = 0.16
## Board cell (quick spec 2.1), in art pixels of the 640x360 battle canvas: smallest and largest
## cell, the canvas height the screen height is scaled from, and the gap the prototype leaves between
## the two halves (reserved in the width budget; the halves themselves touch on screen).
const CELL_MIN_ART: Vector2i = Vector2i(38, 27)
const CELL_MAX_ART: Vector2i = Vector2i(64, 46)
const ART_CANVAS_HEIGHT: float = 360.0
const ART_DIVIDER_GAP: float = 6.0
## Story 047 Part A (art bible 8.2): the battle art canvas is a SubViewport of ART_CANVAS_WIDTH x
## ART_CANVAS_HEIGHT art px shown at the integer scale [method art_scale]; its central
## PLAY_WIDTH_ART x ART_CANVAS_HEIGHT art px (the 16:9 play area) always fit the screen, the rest is
## bleed for wider screens. The remainder outside [method art_rect] is Ink (BattleCanvas).
const ART_CANVAS_WIDTH: float = 800.0
const PLAY_WIDTH_ART: float = 640.0
## HUD band at the top of the arena (HP bars) as a share of arena height; the board fills the rest.
const HUD_HEIGHT_RATIO: float = 0.2
## Story 047 Part A: top of the board band as a share of the height (144 px at 720p). The arena's
## 3-8 % stay the Z1 HUD band ([method hud_rect]); 8-20 % is the far-scenery strip of the backdrop
## (art bible 6.4) and holds no element; the board area starts here.
const BOARD_BAND_TOP_RATIO: float = 0.20
## Preferred cell width divided by cell height.
const CELL_ASPECT: float = 1.4
## Narrowest cell width / height for a board whose width is the limit (wide 5-7 column halves such as boss_hall):
## such a cell keeps its width and grows taller into the free band under the board, as far as the row rules allow
## (user 2026-11-01: 90x64 -> about 90x80 on the 6x4 boss arena at 720p).
const CELL_ASPECT_MIN_WIDE: float = 1.125
## Float slack (px) for the row-placement comparisons.
const LAYOUT_EPSILON: float = 0.01
## Cached cell sizes kept at most (one per board and viewport).
const CELL_CACHE_MAX: int = 32
## Returned by cell_at() when the point is outside the board's bounding rectangle.
const NO_CELL: Vector2i = BoardGrid.NO_CELL
## Quick spec menu-la-giua-man-hinh-2026-11-01: the card menu is four CardFace cards (card_face_size, 176x256 at 720p)
## centred on the screen: the row's vertical centre (share of height), the gap between cards (share of width, as the
## reward row). Controls v3: the 3 s pick time is a gold fuse round an angular frame MENU_FRAME_PAD_PX (720p) outside
## the cards.
const MENU_CARDS_CENTER_Y_RATIO: float = 0.5
const MENU_CARD_GAP_RATIO: float = 0.02
const MENU_FRAME_PAD_PX: float = 14.0
## LoL-style cooldown column at the LEFT screen edge (px at 720p, scaled by height / 720): icon edge, gap between
## icons, and the gap kept to the buff / debuff row above and the stick zone below. The left inset is the relic row's.
const COOLDOWN_ICON_PX: float = 52.0
const COOLDOWN_ICON_GAP_PX: float = 8.0
const COOLDOWN_COLUMN_GAP_PX: float = 8.0
## How far the stone frame round a cooldown icon reaches outside it (720p px; PixelFrame.frame_pad at the small scale).
const COOLDOWN_FRAME_PAD_PX: float = 5.0
## Controls v3 top-left corner (720p px): the relic row's height, the buff / debuff row under it (its angular frame
## edge, the gap between frames and the gap to the relic row).
const HUD_RELIC_ROW_PX: float = 28.0
const STATUS_ICON_PX: float = 40.0
const STATUS_ICON_GAP_PX: float = 6.0
const STATUS_ROW_GAP_PX: float = 6.0
## Controls v3 top-right corner (720p px): the visible pause tile, the gap between it and the gold, and the room kept
## for the gold (glyph + number) left of which the boss's held points sit.
const PAUSE_TILE_PX: float = 48.0
const TOP_RIGHT_GAP_PX: float = 10.0
const HUD_GOLD_RESERVE_PX: float = 84.0
## The placing hint ("drag the block onto the enemy's side") above the bottom-left row: its height and width (720p px).
const PLACE_HINT_HEIGHT_PX: float = 26.0
const PLACE_HINT_WIDTH_PX: float = 380.0
## Run UI (Story 011), shares of the viewport: intro band height; panel size; panel inner
## inset; action button height (0.14 * 720 = 101 px >= 96 px) and its width as a share of the panel.
const RUN_INTRO_HEIGHT_RATIO: float = 0.3
const RUN_PANEL_WIDTH_RATIO: float = 0.5
const RUN_PANEL_HEIGHT_RATIO: float = 0.7
const RUN_PANEL_INSET_RATIO: float = 0.035
const RUN_BUTTON_HEIGHT_RATIO: float = 0.14
const RUN_BUTTON_WIDTH_RATIO: float = 0.7
## Run UI (Story 015): gap between two side-by-side panel buttons (share of width).
const RUN_BUTTON_GAP_RATIO: float = 0.015
## Menu screens (Story 015): the title band (top .. bottom) shared by the chapter select, the
## character select and the reward screen.
const FLOOR_TITLE_TOP_RATIO: float = 0.03
const FLOOR_TITLE_BOTTOM_RATIO: float = 0.13
## Chapter select (Story 019), shares of the viewport: the tile row's top, one tile's size
## (0.22 * 1280 = 282 px wide, 0.4 * 720 = 288 px tall >= 96 px) and the gap between tiles; the
## row is centred. Four tiles (4 * 282 + 3 * 26 = 1206 px) still fit between the margins.
const CHAPTER_TILES_TOP_RATIO: float = 0.22
const CHAPTER_TILE_WIDTH_RATIO: float = 0.22
const CHAPTER_TILE_HEIGHT_RATIO: float = 0.4
const CHAPTER_TILE_GAP_RATIO: float = 0.02
## Reward screen (Story 019), shares of the viewport: the card row's top and bottom (0.17 .. 0.82
## = 468 px tall at 720p), the gap between cards, the widest a card may get (0.27 * 1280 = 346 px;
## three cards share min(384, 346) = 346 px >= 300 px) and the skip button's top (its height is
## BACK_BUTTON_HEIGHT_RATIO: 0.86 + 0.09 = 0.95 of the height).
const REWARD_CARDS_TOP_RATIO: float = 0.17
## 2026-11-01 (OSFE cards): portrait cards (about 3:4) that print their effect text.
const REWARD_CARDS_BOTTOM_RATIO: float = 0.72
const REWARD_CARD_GAP_RATIO: float = 0.02
const REWARD_CARD_MAX_WIDTH_RATIO: float = 0.22
const REWARD_SKIP_TOP_RATIO: float = 0.86
## Reward screen (Story 020): the "Bỏ 1 lá" slot's width (0.16 * 1280 = 205 px, a narrower fourth
## card right of the offer); with it the three cards share (1203 - 205 - 3 * 25.6) / 3 = 307 px
## >= 280 px. Remove list: tiles per row and rows shown (6 x 2 = 12 entries visible), tile height
## (0.16 * 720 = 115 px >= 64 px) and the gap between the rows (share of height).
const REWARD_REMOVE_SLOT_WIDTH_RATIO: float = 0.16
const REWARD_REMOVE_COLS: int = 6
const REWARD_REMOVE_ROWS: int = 2
const REWARD_REMOVE_TILE_HEIGHT_RATIO: float = 0.16
const REWARD_REMOVE_ROW_GAP_RATIO: float = 0.03
## Boss status readouts (Story 020): the gap CombatView._draw_hud leaves between the HP text
## baseline and its bar (mirrors the inline 8 px there; the bar itself is CombatView.BAR_HEIGHT).
const HUD_BAR_TEXT_GAP: float = 8.0
## Corner HP panels (2026-10-31, user: "đưa thanh máu về góc như này giống osfe"): flush to the top
## corners of the screen, HUD_CORNER_PANEL_PX at 720p (scaled by height / 720), never wider than
## HUD_CORNER_PANEL_MAX_WIDTH_RATIO of the width. 52 px tall at 720p keeps the panel above the head of a
## v3 hero on a 5x5 back row (head top ~57 px).
## User 2026-10-31: "thanh máu có thể ko cần dài quá như osfe": 260 px wide (HP bar ~236 px).
const HUD_CORNER_PANEL_PX: Vector2 = Vector2(260.0, 52.0)
const HUD_CORNER_PANEL_REF_HEIGHT: float = 720.0
const HUD_CORNER_PANEL_MAX_WIDTH_RATIO: float = 0.28
## Gap (720p px) between a corner panel and the labels placed beside it (match label, deck label).
const HUD_CORNER_GAP_PX: float = 8.0
## 2026-10-31 top HUD row (no corner panels in battle): inset of the relic row from the left edge (720p px).
const HUD_TOP_ROW_INSET_PX: float = 12.0


## Controls v3: the top HUD row's vertical band (the pause tile's top and height), shared by the relic row, the gold
## and the boss's held points so they line up on its centre.
static func hud_top_row_rect(viewport_size: Vector2) -> Rect2:
	var s: float = controls_scale(viewport_size)
	return Rect2(0.0, roundf(HUD_EDGE_INSET_PX * s), viewport_size.x, roundf(PAUSE_TILE_PX * s))


## Controls v3: px per 720p px (viewport height / 720).
static func controls_scale(viewport_size: Vector2) -> float:
	return viewport_size.y / CONTROLS_REF_HEIGHT
## Title screen (Story 016), shares of the viewport: the name band (top .. bottom: game name,
## knife motif, tagline), the button column's top, one button's size (0.3 * 1280 = 384 px wide,
## 0.11 * 720 = 79 px tall >= 72 px) and the gap between buttons (share of height). Three
## buttons end at 0.47 + 3 * 0.11 + 2 * 0.025 = 0.85 of the height.
## Main Menu pass (user 2026-11-01, OSFE-style): the name band and the button column sit on the LEFT
## (TITLE_LEFT_RATIO from the edge, left thumb reach); the right side shows the key-art scene.
const TITLE_TOP_RATIO: float = 0.06
const TITLE_BOTTOM_RATIO: float = 0.36
const TITLE_LEFT_RATIO: float = 0.06
const TITLE_BAND_WIDTH_RATIO: float = 0.42
const TITLE_BUTTONS_TOP_RATIO: float = 0.41
const TITLE_BUTTON_WIDTH_RATIO: float = 0.3
const TITLE_BUTTON_HEIGHT_RATIO: float = 0.1
const TITLE_BUTTON_GAP_RATIO: float = 0.022
## Story 037: the lowest the title button column may reach (share of the height).
const TITLE_BUTTONS_BOTTOM_RATIO: float = 0.95
## The full column (Continue, Play, Achievements, Settings, Quit): 5 buttons of 65 px at 720p (>= 64 px); the
## continue summary strip sits under its first button.
const TITLE_BUTTON_COLUMN_COUNT: int = 5
## Key-art menu (user 2026-11-01): the button column on the right (the art's hero stands bottom-left), the name
## band stays top-left; false puts the column on the left (the art is then mirrored). The language button takes the
## free bottom corner.
static var title_menu_right: bool = true
## Title screen language button (Story 017): width / height as shares of the viewport.
const TITLE_LANG_BUTTON_WIDTH_RATIO: float = 0.1
const TITLE_LANG_BUTTON_HEIGHT_RATIO: float = 0.09
## Back button of the floor select (Story 016): width (share of width) and height (0.09 * 720 =
## 65 px >= 64 px, share of height); sits on the left screen margin, centred in the title band
## (the "CHỌN TẦNG" text is centred and clear of it).
const BACK_BUTTON_WIDTH_RATIO: float = 0.1
const BACK_BUTTON_HEIGHT_RATIO: float = 0.09
## Character select (Story 018), shares of the viewport: the card row's top and bottom (0.16 ..
## 0.95 of the height = 569 px tall at 720p), the gap between cards (share of width) and the
## widest a card may get (0.3 * 1280 = 384 px; three cards share the margin-to-margin width,
## (1203 - 2 * 25.6) / 3 = 384 px >= 300 px). Five or more cards get narrower — a second row is
## out of scope for Story 018.
const CHARACTER_CARDS_TOP_RATIO: float = 0.16
const CHARACTER_CARDS_BOTTOM_RATIO: float = 0.95
const CHARACTER_CARD_GAP_RATIO: float = 0.02
const CHARACTER_CARD_MAX_WIDTH_RATIO: float = 0.3
## Floor select (Story 018): the "Nhân vật: …" label on the right margin inside the title band
## (width as a share of the viewport width, same height as the back button).
const FLOOR_HERO_LABEL_WIDTH_RATIO: float = 0.3
## Signature skill UI (Story 021): the charge bar inside the Awaken button's bottom edge (share of height),
## the active-timer bar along the top of the player's half (share of the board height) and the banner's
## height (share of the board height). The button itself is [method signature_rect] (Story 044).
const SIGNATURE_CHARGE_HEIGHT_RATIO: float = 0.025
const SIGNATURE_TIMER_HEIGHT_RATIO: float = 0.035
const SIGNATURE_BANNER_HEIGHT_RATIO: float = 0.3
## Chapter map (Story 022), shares of the viewport: the column band's top and bottom under the
## header strip (0.21 .. 0.96 of the height = 540 px), the gap between columns (share of width) and
## between a column's node tiles (share of height). A column holds MAP_MAX_NODES tile slots and a
## tile is a square of min(column width, slot height): with 7 columns a column is
## (1203 - 6 * 19) / 7 = 155 px wide and a slot (540 - 2 * 14) / 3 = 170 px tall, so a tile is
## 155 x 155 px >= 96 px. The header strip (hero, HP, deck, tokens, luck) sits between the title
## band and the columns; the restart notice is a band across the middle of the column area.
const MAP_COLUMNS_TOP_RATIO: float = 0.21
## Story 032: 0.96 -> 0.86, the band under the columns holds the relic strip.
const MAP_COLUMNS_BOTTOM_RATIO: float = 0.86
const MAP_COLUMN_GAP_RATIO: float = 0.015
const MAP_NODE_GAP_RATIO: float = 0.02
const MAP_MAX_NODES: int = 3
const MAP_NOTICE_HEIGHT_RATIO: float = 0.14
## Rest view (Story 022): the two choice cards' top and bottom (0.2 .. 0.82 of the height = 446 px),
## one card's width (0.3 * 1280 = 384 px) and the gap between them (shares of the viewport).
const REST_CARDS_TOP_RATIO: float = 0.2
const REST_CARDS_BOTTOM_RATIO: float = 0.82
const REST_CARD_WIDTH_RATIO: float = 0.3
const REST_CARD_GAP_RATIO: float = 0.04
## Smallest touch target side in logical pixels (Story 031): a drawn button smaller than this
## (the 128 x 65 px back button) is hit-tested on [method touch_rect], grown to this size around
## its centre, so one thumb hits it.
const MIN_TOUCH_SIDE: float = 96.0
## World map (Story 031), shares of the viewport: the floor progress strip under the title band
## (0.145 .. 0.245 of the height = 72 px) and the gap between its segments (share of width); the
## region cards' top and bottom (0.28 .. 0.8 = 374 px, 52 % of the height >= 50 %), one card's
## width (0.44 * 1280 = 563 px, >= 40 % of the width; two cards plus the margins leave a 77 px
## gap in the middle), how far a selected card rises (share of height) and the "Vào vùng" button
## under it (0.83 .. 0.97 of the height = 101 px >= MIN_TOUCH_SIDE; width a share of the width,
## centred under its card, i.e. on that thumb's side).
const WORLD_STRIP_TOP_RATIO: float = 0.145
const WORLD_STRIP_BOTTOM_RATIO: float = 0.245
const WORLD_STRIP_GAP_RATIO: float = 0.008
const WORLD_CARDS_TOP_RATIO: float = 0.28
## Story 032: cards and the enter button moved up (were 0.8 / 0.83-0.97) to free the relic strip band.
const WORLD_CARDS_BOTTOM_RATIO: float = 0.71
const WORLD_CARD_WIDTH_RATIO: float = 0.44
const WORLD_CARD_RAISE_RATIO: float = 0.025
const WORLD_ENTER_TOP_RATIO: float = 0.735
const WORLD_ENTER_BOTTOM_RATIO: float = 0.855
const WORLD_ENTER_WIDTH_RATIO: float = 0.3


## Rectangle of the arena area (HUD band + board), down to the wide-row bottom (64 % of the height).
static func arena_rect(viewport_size: Vector2) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * ARENA_TOP_RATIO
	var bottom: float = viewport_size.y * ARENA_BOTTOM_WIDE_RATIO
	return Rect2(margin, top, viewport_size.x - margin * 2.0, bottom - top)


## Bottom edge of the controls: half a margin above the bottom of the screen (the Awaken button's
## bottom edge; the stick zone runs to the very bottom).
static func controls_bottom(viewport_size: Vector2) -> float:
	return viewport_size.y - viewport_size.x * MARGIN_RATIO * 0.5


## Stick zone (Z3): x 0-25 % of the width, from the wide-row arena bottom (64 %) to the bottom of
## the screen (320 x 259 px at 1280x720). The floating joystick appears where a touch lands in it;
## while a piece is placed it hosts the big ROTATE button.
static func stick_zone_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * ARENA_BOTTOM_WIDE_RATIO
	return Rect2(0.0, top, viewport_size.x * STICK_ZONE_WIDTH_RATIO, viewport_size.y - top)


## Controls v3: the bottom edge of both thumb rows (HUD_EDGE_INSET_PX above the screen's bottom, whole px).
static func bottom_row_bottom(viewport_size: Vector2) -> float:
	return roundf(viewport_size.y - HUD_EDGE_INSET_PX * controls_scale(viewport_size))


# Controls v3: a visual control of [param width_px] x BOTTOM_ROW_HEIGHT_PX (720p px) whose left edge is [param left]
# (screen px) on the shared bottom edge, whole px.
static func _row_rect(viewport_size: Vector2, left: float, width_px: float) -> Rect2:
	var s: float = controls_scale(viewport_size)
	var h: float = roundf(BOTTOM_ROW_HEIGHT_PX * s)
	return Rect2(roundf(left), bottom_row_bottom(viewport_size) - h, roundf(width_px * s), h)


## Size of one bag socket: a SOCKET_PX square (64 x 64 at 720p).
static func slot_size(viewport_size: Vector2) -> Vector2:
	var side: float = roundf(SOCKET_PX * controls_scale(viewport_size))
	return Vector2(side, side)


## Controls v3: rectangle of bag socket [param index] of a bag of [param count] (the bag's order, 0 = left): one
## straight row of SOCKET_PX squares, BOTTOM_ROW_GAP_PX apart, the last one HUD_EDGE_INSET_PX from the right
## edge, on the shared bottom edge (1056 / 1130 / 1204 x 644-708 for three sockets at 1280x720).
static func slot_rect(viewport_size: Vector2, index: int, count: int = 3) -> Rect2:
	var s: float = controls_scale(viewport_size)
	var n: int = maxi(count, 1)
	var i: int = clampi(index, 0, n - 1)
	var size: Vector2 = slot_size(viewport_size)
	var gap: float = roundf(BOTTOM_ROW_GAP_PX * s)
	var right: float = viewport_size.x - roundf(HUD_EDGE_INSET_PX * s)
	var left: float = right - size.x * n - gap * (n - 1) + (size.x + gap) * i
	return Rect2(Vector2(left, bottom_row_bottom(viewport_size) - size.y), size)


## Socket rectangles for slots 0..count-1 in bag order (left to right), see [method slot_rect].
static func slot_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for i: int in maxi(count, 0):
		rects.append(slot_rect(viewport_size, i, count))
	return rects


## Controls v3: the invisible tap rects of the [param count] sockets, see [method row_hit_rects] (the row reaches the
## right screen edge).
static func slot_hit_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	return row_hit_rects(viewport_size, slot_rects(viewport_size, count), false, true)


## Controls v3: the invisible tap rects of [param visuals] (one row, left to right, on the shared bottom edge): each
## visual grown to CONTROL_HIT_PX (720p px) around its centre and down to the screen's bottom edge; two neighbours
## that would overlap split the gap between their visuals in the middle; [param to_left_edge] / [param to_right_edge]
## stretch the first / last one to that screen edge. Every hit rect encloses its visual and none overlaps another.
static func row_hit_rects(viewport_size: Vector2, visuals: Array[Rect2], to_left_edge: bool, to_right_edge: bool) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var target: float = roundf(CONTROL_HIT_PX * controls_scale(viewport_size))
	var lefts: Array[float] = []
	var rights: Array[float] = []
	for v: Rect2 in visuals:
		var pad: float = maxf((target - v.size.x) * 0.5, 0.0)
		lefts.append(maxf(v.position.x - pad, 0.0))
		rights.append(minf(v.end.x + pad, viewport_size.x))
	for i: int in visuals.size():
		if i > 0 and lefts[i] < rights[i - 1]:
			var mid: float = roundf((visuals[i - 1].end.x + visuals[i].position.x) * 0.5)
			rights[i - 1] = mid
			lefts[i] = mid
	if to_left_edge and not visuals.is_empty():
		lefts[0] = 0.0
	if to_right_edge and not visuals.is_empty():
		rights[visuals.size() - 1] = viewport_size.x
	for i: int in visuals.size():
		var top: float = minf(visuals[i].position.y, viewport_size.y - target)
		out.append(Rect2(lefts[i], top, rights[i] - lefts[i], viewport_size.y - top))
	return out


## HUD band at the top of the arena (HP bars; nothing else draws here).
static func hud_rect(viewport_size: Vector2) -> Rect2:
	var arena: Rect2 = arena_rect(viewport_size)
	return Rect2(arena.position, Vector2(arena.size.x, arena.size.y * HUD_HEIGHT_RATIO))


## Area the board shares: from BOARD_BAND_TOP_RATIO (20 % of the height, Story 047) down to the
## arena's wide-row bottom, as wide as the arena.
static func board_area_rect(viewport_size: Vector2) -> Rect2:
	var arena: Rect2 = arena_rect(viewport_size)
	var top: float = viewport_size.y * BOARD_BAND_TOP_RATIO
	return Rect2(arena.position.x, top, arena.size.x, maxf(arena.end.y - top, 0.0))


## Story 047 Part A: integer scale of the battle art canvas, n = max(1, floor(min(W / 640, H / 360)))
## (2 at 1280x720 and 1600x720, 3 at 2400x1080, 1 at 1024x768).
static func art_scale(viewport_size: Vector2) -> int:
	return maxi(1, floori(minf(viewport_size.x / PLAY_WIDTH_ART, viewport_size.y / ART_CANVAS_HEIGHT)))


## Story 047 Part A: screen rectangle the 800x360 art canvas is shown in: 800n x 360n px centred
## ((-160, 0, 1600, 720) at 1280x720: the bleed hangs off both sides; (112, 204, 800, 360) at 1024x768).
static func art_rect(viewport_size: Vector2) -> Rect2:
	var n: float = float(art_scale(viewport_size))
	var size := Vector2(ART_CANVAS_WIDTH, ART_CANVAS_HEIGHT) * n
	return Rect2((viewport_size - size) * 0.5, size)


## Story 047 Part A: the central 640n x 360n px of [method art_rect] (the 16:9 play area, always on screen).
static func play_rect(viewport_size: Vector2) -> Rect2:
	var art: Rect2 = art_rect(viewport_size)
	var size := Vector2(PLAY_WIDTH_ART, ART_CANVAS_HEIGHT) * float(art_scale(viewport_size))
	return Rect2(Vector2(art.get_center().x - size.x * 0.5, art.position.y), size)


## Story 047 Part A: screen px -> whole art px of the canvas (floor; the art px that contains the point).
static func to_art(viewport_size: Vector2, px: Vector2) -> Vector2i:
	var local: Vector2 = (px - art_rect(viewport_size).position) / float(art_scale(viewport_size))
	return Vector2i(floori(local.x), floori(local.y))


## Story 047 Part A: art px of the canvas -> screen px (the top-left corner of that art px); the inverse
## of [method to_art] for whole art px.
static func from_art(viewport_size: Vector2, art: Vector2) -> Vector2:
	return art_rect(viewport_size).position + art * float(art_scale(viewport_size))


## Story 047 Part A: a screen rectangle -> art px (both corners through [method to_art], so adjacent cells
## keep sharing an edge).
static func to_art_rect(viewport_size: Vector2, r: Rect2) -> Rect2i:
	var pos: Vector2i = to_art(viewport_size, r.position)
	return Rect2i(pos, to_art(viewport_size, r.end) - pos)


## Board cells cached per (grid, viewport): cell_size() is called by every draw helper.
static var _cell_cache: Dictionary = {}


## Size of one board cell. The largest cell of aspect CELL_ASPECT between CELL_MIN_ART and
## CELL_MAX_ART (whole art px of the battle canvas, times [method art_scale]) such that: each half is
## at most (arena width - ART_DIVIDER_GAP) / 2 wide, a board row that extends outside the thumb gap
## ends at or above ARENA_BOTTOM_WIDE_RATIO, and a row fully inside it at or above
## ARENA_BOTTOM_NARROW_RATIO (see [method board_rect] for the vertical placement), and no real cell
## overlaps a HUD obstacle ([method hud_obstacle_rects]: the bag's tap rects and, controls v3, the cooldown column at
## the left edge, which the 7-column halves would otherwise reach). A board too big even for the smallest cell shrinks
## continuously to fit the board area instead.
static func cell_size(grid: BoardGrid, viewport_size: Vector2) -> Vector2:
	var key: int = grid.get_instance_id()
	var cached: Variant = _cell_cache.get(key)
	if cached != null and cached["grid"] == grid and cached["vp"] == viewport_size:
		return cached["size"]
	var size: Vector2 = _compute_cell_size(grid, viewport_size)
	if _cell_cache.size() >= CELL_CACHE_MAX:
		_cell_cache.clear()
	_cell_cache[key] = {"grid": grid, "vp": viewport_size, "size": size}
	return size


static func _compute_cell_size(grid: BoardGrid, viewport_size: Vector2) -> Vector2:
	# Story 047: whole art px at the canvas's integer scale (2 at 720p, as viewport.y / 360 was).
	var scale: float = float(art_scale(viewport_size))
	var arena: Rect2 = arena_rect(viewport_size)
	var half_max_art: float = (arena.size.x / scale - ART_DIVIDER_GAP) * 0.5
	var first_cols: Array[int] = _row_first_cols(grid)
	var slots: Array[Rect2] = hud_obstacle_rects(viewport_size)
	for h_art: int in range(CELL_MAX_ART.y, CELL_MIN_ART.y - 1, -1):
		var w_art: int = clampi(roundi(h_art * CELL_ASPECT), CELL_MIN_ART.x, CELL_MAX_ART.x)
		if grid.side_cols * w_art > half_max_art + LAYOUT_EPSILON:
			continue
		var cell := Vector2(w_art, h_art) * scale
		if _rows_fit(grid, viewport_size, cell, first_cols) and _clear_of_slots(grid, viewport_size, cell, slots):
			return _taller_if_width_bound(grid, viewport_size, Vector2i(w_art, h_art), scale, half_max_art, first_cols, slots)
	var area: Rect2 = board_area_rect(viewport_size)
	var h: float = area.size.y / grid.rows
	return Vector2(minf(h * CELL_ASPECT, area.size.x / grid.total_cols), h)


# A cell [param art] picked at CELL_ASPECT: when one more art px of width would not fit ([method _width_bound]), the tallest height up to CELL_MAX_ART.y and down to aspect CELL_ASPECT_MIN_WIDE whose rows and slots still
# fit; otherwise [param art] unchanged. Narrow boards that reach CELL_MAX_ART or are height-bound keep their cell.
static func _taller_if_width_bound(grid: BoardGrid, viewport_size: Vector2, art: Vector2i, scale: float,
		half_max_art: float, first_cols: Array[int], slots: Array[Rect2]) -> Vector2:
	if art.x >= CELL_MAX_ART.x or not _width_bound(grid, viewport_size, art, scale, half_max_art, first_cols, slots):
		return Vector2(art) * scale
	var tallest: int = mini(floori(art.x / CELL_ASPECT_MIN_WIDE + LAYOUT_EPSILON), CELL_MAX_ART.y)
	for h_art: int in range(tallest, art.y, -1):
		var cell := Vector2(art.x, h_art) * scale
		if _rows_fit(grid, viewport_size, cell, first_cols) and _clear_of_slots(grid, viewport_size, cell, slots):
			return cell
	return Vector2(art) * scale


# True when a cell one art px wider than [param art] (same height) would break the half width, the row rules or the
# hold slots: the width, not the height, limits the board.
static func _width_bound(grid: BoardGrid, viewport_size: Vector2, art: Vector2i, scale: float, half_max_art: float,
		first_cols: Array[int], slots: Array[Rect2]) -> bool:
	if grid.side_cols * (art.x + 1) > half_max_art + LAYOUT_EPSILON:
		return true
	var wider := Vector2(art.x + 1, art.y) * scale
	return not (_rows_fit(grid, viewport_size, wider, first_cols) and _clear_of_slots(grid, viewport_size, wider, slots))


## Controls v3: the HUD rects no real board cell may overlap ([method cell_size] shrinks the cell until none does): the
## tap rects of a bag of HoldSlots.MAX_SLOTS sockets and the cooldown column at the left edge with its stone frames
## (COOLDOWN_FRAME_PAD_PX outside the icons).
static func hud_obstacle_rects(viewport_size: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = slot_hit_rects(viewport_size, HoldSlots.MAX_SLOTS)
	out.append(cooldown_column_rect(viewport_size).grow(roundf(COOLDOWN_FRAME_PAD_PX * controls_scale(viewport_size))))
	return out


# For each board row, the first real column of the player's half (the board's left extent in that row), -1 if none.
static func _row_first_cols(grid: BoardGrid) -> Array[int]:
	var cols: Array[int] = []
	for row: int in grid.rows:
		var first: int = -1
		for col: int in grid.side_cols:
			if grid.is_in_board(Vector2i(col, row)):
				first = col
				break
		cols.append(first)
	return cols


# Top edge of a board of [param rows] rows of [param cell_h] px: centred in the board area, but never above it
# (a tall board overflows downwards).
static func _board_top(viewport_size: Vector2, rows: int, cell_h: float) -> float:
	var area: Rect2 = board_area_rect(viewport_size)
	return area.position.y + maxf((area.size.y - cell_h * rows) * 0.5, 0.0)


# True if every row of the board, laid out with [param cell], ends above its limit: the wide bottom for a row that
# reaches outside the thumb gap, the narrow bottom for a row fully inside it.
static func _rows_fit(grid: BoardGrid, viewport_size: Vector2, cell: Vector2, first_cols: Array[int]) -> bool:
	var top: float = _board_top(viewport_size, grid.rows, cell.y)
	var left: float = (viewport_size.x - cell.x * grid.total_cols) * 0.5
	var gap_left: float = viewport_size.x * THUMB_GAP_LEFT_RATIO
	var gap_right: float = viewport_size.x * THUMB_GAP_RIGHT_RATIO
	var wide: float = viewport_size.y * ARENA_BOTTOM_WIDE_RATIO
	var narrow: float = viewport_size.y * ARENA_BOTTOM_NARROW_RATIO
	for row: int in grid.rows:
		var first: int = first_cols[row]
		var inside: bool = first < 0
		if not inside:
			var row_left: float = left + first * cell.x
			var row_right: float = left + (grid.total_cols - first) * cell.x
			inside = row_left >= gap_left - LAYOUT_EPSILON and row_right <= gap_right + LAYOUT_EPSILON
		var bottom: float = top + (row + 1) * cell.y
		if bottom > (narrow if inside else wide) + LAYOUT_EPSILON:
			return false
	return true


# True if no real cell of the board, laid out with [param cell] (as [method board_rect] places it), overlaps any of
# [param slots] (shared edges allowed).
static func _clear_of_slots(grid: BoardGrid, viewport_size: Vector2, cell: Vector2, slots: Array[Rect2]) -> bool:
	var origin := Vector2((viewport_size.x - cell.x * grid.total_cols) * 0.5, _board_top(viewport_size, grid.rows, cell.y))
	var board := Rect2(origin, cell * Vector2(grid.total_cols, grid.rows))
	for slot: Rect2 in slots:
		if not board.intersects(slot):
			continue
		for row: int in grid.rows:
			for col: int in grid.total_cols:
				if grid.is_in_board(Vector2i(col, row)) and Rect2(origin + cell * Vector2(col, row), cell).intersects(slot):
					return false
	return true


## Bounding rectangle of the whole board: centred horizontally, centred vertically in the board area
## (from BOARD_BAND_TOP_RATIO down to the wide-row bottom) and, when taller than it, overflowing downwards
## where [method cell_size]'s row rule allows.
static func board_rect(grid: BoardGrid, viewport_size: Vector2) -> Rect2:
	var cell: Vector2 = cell_size(grid, viewport_size)
	var size: Vector2 = cell * Vector2(grid.total_cols, grid.rows)
	var area: Rect2 = board_area_rect(viewport_size)
	return Rect2(Vector2(area.get_center().x - size.x * 0.5, _board_top(viewport_size, grid.rows, cell.y)), size)


## Rectangle of board cell [param cell] (its position in the bounding grid; the cell should
## be a real cell, see BoardGrid.is_in_board).
static func cell_rect(grid: BoardGrid, viewport_size: Vector2, cell: Vector2i) -> Rect2:
	var size: Vector2 = cell_size(grid, viewport_size)
	var origin: Vector2 = board_rect(grid, viewport_size).position
	return Rect2(origin + size * Vector2(cell), size)


## P2.2b: bounding rectangle of the board cells [param cells] (a multi-cell boss's footprint); the cell's own rect for
## one cell; an empty Rect2 for none.
static func cells_rect(grid: BoardGrid, viewport_size: Vector2, cells: Array[Vector2i]) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var out: Rect2 = cell_rect(grid, viewport_size, cells[0])
	for i: int in range(1, cells.size()):
		out = out.merge(cell_rect(grid, viewport_size, cells[i]))
	return out


## Centre of board cell [param cell].
static func cell_center(grid: BoardGrid, viewport_size: Vector2, cell: Vector2i) -> Vector2:
	return cell_rect(grid, viewport_size, cell).get_center()


## Board cell under [param point], or NO_CELL if the point is outside the bounding
## rectangle. A point over a missing cell still returns that cell: check
## BoardGrid.is_in_board().
static func cell_at(grid: BoardGrid, viewport_size: Vector2, point: Vector2) -> Vector2i:
	var board: Rect2 = board_rect(grid, viewport_size)
	if not board.has_point(point):
		return NO_CELL
	var size: Vector2 = cell_size(grid, viewport_size)
	var local: Vector2 = point - board.position
	return Vector2i(
		clampi(int(local.x / size.x), 0, grid.total_cols - 1),
		clampi(int(local.y / size.y), 0, grid.rows - 1)
	)


## X of the vertical divider between the player's half and the boss's half.
static func divider_x(grid: BoardGrid, viewport_size: Vector2) -> float:
	return board_rect(grid, viewport_size).position.x + cell_size(grid, viewport_size).x * grid.side_cols


## Controls v3 bottom-left row while placing: Tung phép (CAST_WIDTH_PX wide, against the left inset), Xoay
## (ROTATE_WIDTH_PX square, the buffer between the two opposite actions), Hủy (CANCEL_WIDTH_PX); BOTTOM_ROW_HEIGHT_PX
## tall, BOTTOM_ROW_GAP_PX apart, on the shared bottom edge (12-112 / 122-186 / 196-268 x 644-708 at 1280x720).
static func confirm_button_rect(viewport_size: Vector2) -> Rect2:
	return _row_rect(viewport_size, HUD_EDGE_INSET_PX * controls_scale(viewport_size), CAST_WIDTH_PX)


## Controls v3: the Xoay (rotate) square right of Tung phép, see [method confirm_button_rect].
static func rotate_button_rect(viewport_size: Vector2) -> Rect2:
	var cast: Rect2 = confirm_button_rect(viewport_size)
	return _row_rect(viewport_size, cast.end.x + roundf(BOTTOM_ROW_GAP_PX * controls_scale(viewport_size)), ROTATE_WIDTH_PX)


## Controls v3: the Hủy (cancel) button. While placing / in the place window it closes the bottom-left row right of
## Xoay; with the card menu open ([param menu]) it takes the corner place and size of Tung phép instead.
static func cancel_button_rect(viewport_size: Vector2, menu: bool = false) -> Rect2:
	if menu:
		return confirm_button_rect(viewport_size)
	var rotate: Rect2 = rotate_button_rect(viewport_size)
	return _row_rect(viewport_size, rotate.end.x + roundf(BOTTOM_ROW_GAP_PX * controls_scale(viewport_size)), CANCEL_WIDTH_PX)


## Controls v3: the tap rects of the bottom-left row [Tung phép, Xoay, Hủy] (see [method row_hit_rects]; the row reaches
## the left screen edge). Tung phép 0-117, Xoay 117-191, Hủy 191-280 x 624-720 at 1280x720.
static func placing_row_hit_rects(viewport_size: Vector2) -> Array[Rect2]:
	var visuals: Array[Rect2] = [confirm_button_rect(viewport_size), rotate_button_rect(viewport_size), cancel_button_rect(viewport_size)]
	return row_hit_rects(viewport_size, visuals, true, false)


## Controls v3: tap rect of Tung phép (also of the card menu's Hủy, which sits in its place).
static func confirm_hit_rect(viewport_size: Vector2) -> Rect2:
	return placing_row_hit_rects(viewport_size)[0]


## Controls v3: tap rect of Xoay.
static func rotate_hit_rect(viewport_size: Vector2) -> Rect2:
	return placing_row_hit_rects(viewport_size)[1]


## Controls v3: tap rect of Hủy ([param menu]: the card menu's Hủy in the place of Tung phép).
static func cancel_hit_rect(viewport_size: Vector2, menu: bool = false) -> Rect2:
	return placing_row_hit_rects(viewport_size)[0 if menu else 2]


## Card menu (2026-11-01): one CardFace rectangle per drawn card, left to right, the row centred on the screen
## (4 cards: 249-1030 x 232-488 px at 1280x720). Every card is a tap target of the full card size.
static func skill_menu_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var size: Vector2 = card_face_size(viewport_size)
	var gap: float = roundf(viewport_size.x * MENU_CARD_GAP_RATIO)
	var left: float = roundf((viewport_size.x - (size.x * count + gap * (count - 1))) * 0.5)
	var top: float = roundf(viewport_size.y * MENU_CARDS_CENTER_Y_RATIO - size.y * 0.5)
	for i: int in count:
		rects.append(Rect2(left + (size.x + gap) * i, top, size.x, size.y))
	return rects


## Controls v3: the angular frame enclosing the [param count] menu cards (MENU_FRAME_PAD_PX outside them); the
## pick-time fuse burns clockwise round it from 12 o'clock (235-1044 x 218-502 at 1280x720 for four cards).
static func skill_menu_frame_rect(viewport_size: Vector2, count: int = 4) -> Rect2:
	var rects: Array[Rect2] = skill_menu_rects(viewport_size, maxi(count, 1))
	return rects[0].merge(rects[-1]).grow(roundf(MENU_FRAME_PAD_PX * controls_scale(viewport_size)))


## Card menu area (the fuse frame round the card row).
static func skill_menu_panel_rect(viewport_size: Vector2, count: int = 4) -> Rect2:
	return skill_menu_frame_rect(viewport_size, count)


## Controls v3 top-left corner, row 2: the player's buffs / debuffs (StatusEffects), one STATUS_ICON_PX angular frame
## each, under the relic row and as wide as it (12-268 x 54-94 at 1280x720).
static func hud_status_row_rect(viewport_size: Vector2) -> Rect2:
	var s: float = controls_scale(viewport_size)
	var relics: Rect2 = hud_relic_strip_rect(viewport_size)
	var top: float = relics.end.y + roundf(STATUS_ROW_GAP_PX * s)
	return Rect2(relics.position.x, top, relics.size.x, roundf(STATUS_ICON_PX * s))


## Controls v3: the frames of [param count] statuses in the row, left to right (at most as many as fit).
static func status_icon_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var row: Rect2 = hud_status_row_rect(viewport_size)
	var edge: float = row.size.y
	var gap: float = roundf(STATUS_ICON_GAP_PX * controls_scale(viewport_size))
	for i: int in count:
		var r := Rect2(row.position.x + (edge + gap) * i, row.position.y, edge, edge)
		if r.end.x > row.end.x:
			break
		rects.append(r)
	return rects


## 2026-11-01 LoL-style cooldown column at the LEFT screen edge. Controls v3: under the buff / debuff row, down to the
## stick zone; the relic row's left inset, one icon wide (12-64 x 102-453 px at 1280x720).
static func cooldown_column_rect(viewport_size: Vector2) -> Rect2:
	var s: float = controls_scale(viewport_size)
	var left: float = floorf(HUD_TOP_ROW_INSET_PX * s)
	var top: float = ceilf(hud_status_row_rect(viewport_size).end.y + COOLDOWN_COLUMN_GAP_PX * s)
	var bottom: float = floorf(stick_zone_rect(viewport_size).position.y - COOLDOWN_COLUMN_GAP_PX * s)
	return Rect2(left, top, roundf(COOLDOWN_ICON_PX * s), maxf(bottom - top, 0.0))


## The icons of the cooldown column, top-down (the earliest use first): at most as many of [param count] as fit.
static func cooldown_icon_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var column: Rect2 = cooldown_column_rect(viewport_size)
	var edge: float = column.size.x
	var gap: float = roundf(COOLDOWN_ICON_GAP_PX * controls_scale(viewport_size))
	for i: int in count:
		var r := Rect2(column.position.x, column.position.y + (edge + gap) * i, edge, edge)
		if r.end.y > column.end.y:
			break
		rects.append(r)
	return rects


## Controls v3: the placing hint, bare text just above the bottom-left row (left inset, PLACE_HINT_WIDTH_PX wide), shown
## while the block is off the enemy's side. Clear of the board (the rows that reach this low sit in the thumb gap).
static func place_hint_rect(viewport_size: Vector2) -> Rect2:
	var s: float = controls_scale(viewport_size)
	var row_top: float = confirm_button_rect(viewport_size).position.y
	var h: float = roundf(PLACE_HINT_HEIGHT_PX * s)
	var left: float = roundf(HUD_EDGE_INSET_PX * s)
	return Rect2(left, row_top - roundf(BOTTOM_ROW_GAP_PX * s) - h, roundf(PLACE_HINT_WIDTH_PX * s), h)


## Controls v3 top-right corner: the visible pause tile (PAUSE_TILE_PX), HUD_EDGE_INSET_PX from the right and top
## edges (1220-1268 x 12-60 at 1280x720).
static func pause_tile_rect(viewport_size: Vector2) -> Rect2:
	var s: float = controls_scale(viewport_size)
	var side: float = roundf(PAUSE_TILE_PX * s)
	var inset: float = roundf(HUD_EDGE_INSET_PX * s)
	return Rect2(viewport_size.x - inset - side, inset, side, side)


## Controls v3: the gold (angular glyph + number) left of the pause tile, right-aligned TOP_RIGHT_GAP_PX before it,
## HUD_GOLD_RESERVE_PX wide, on the top row (1126-1210 x 12-60 at 1280x720).
static func hud_gold_rect(viewport_size: Vector2) -> Rect2:
	var s: float = controls_scale(viewport_size)
	var tile: Rect2 = pause_tile_rect(viewport_size)
	var right: float = tile.position.x - roundf(TOP_RIGHT_GAP_PX * s)
	var width: float = roundf(HUD_GOLD_RESERVE_PX * s)
	return Rect2(right - width, tile.position.y, width, tile.size.y)


## Run UI (Story 011). Match label: the thin margin above the arena, for centred text. Since the corner
## HP panels (2026-10-31) it spans only the gap between the two panels.
static func run_match_label_rect(viewport_size: Vector2) -> Rect2:
	var gap: float = HUD_CORNER_GAP_PX * viewport_size.y / HUD_CORNER_PANEL_REF_HEIGHT
	var left: float = hud_panel_rect(viewport_size, 0).end.x + gap
	var right: float = hud_panel_rect(viewport_size, 1).position.x - gap
	return Rect2(left, 0.0, maxf(right - left, 0.0), viewport_size.y * ARENA_TOP_RATIO)


## Corner HP panel of [param side] (0 = player, top-left; 1 = boss, top-right), flush to the screen
## corner (OSFE-style, user 2026-10-31): HUD_CORNER_PANEL_PX scaled by height / 720, at most
## HUD_CORNER_PANEL_MAX_WIDTH_RATIO of the width, whole pixels.
static func hud_panel_rect(viewport_size: Vector2, side: int) -> Rect2:
	var s: float = viewport_size.y / HUD_CORNER_PANEL_REF_HEIGHT
	var w: float = floorf(minf(HUD_CORNER_PANEL_PX.x * s, viewport_size.x * HUD_CORNER_PANEL_MAX_WIDTH_RATIO))
	var h: float = floorf(HUD_CORNER_PANEL_PX.y * s)
	var x: float = 0.0 if side == 0 else viewport_size.x - w
	return Rect2(x, 0.0, w, h)


## Run UI: intro band across the full width, centred on the arena (board stays visible around it).
static func run_intro_band_rect(viewport_size: Vector2) -> Rect2:
	var arena: Rect2 = arena_rect(viewport_size)
	var height: float = viewport_size.y * RUN_INTRO_HEIGHT_RATIO
	return Rect2(0.0, arena.get_center().y - height * 0.5, viewport_size.x, height)


## Run UI: centred panel of the between / win / lose screens.
static func run_panel_rect(viewport_size: Vector2) -> Rect2:
	var size := Vector2(viewport_size.x * RUN_PANEL_WIDTH_RATIO, viewport_size.y * RUN_PANEL_HEIGHT_RATIO)
	return Rect2((viewport_size - size) * 0.5, size)


## Run UI: the big action button (Tiếp tục / Chơi lại), at the bottom of the panel.
static func run_button_rect(viewport_size: Vector2) -> Rect2:
	var panel: Rect2 = run_panel_rect(viewport_size)
	var inset: float = viewport_size.y * RUN_PANEL_INSET_RATIO
	var height: float = viewport_size.y * RUN_BUTTON_HEIGHT_RATIO
	var width: float = panel.size.x * RUN_BUTTON_WIDTH_RATIO
	return Rect2(panel.get_center().x - width * 0.5, panel.end.y - inset - height, width, height)


## Run UI (Story 015): [param count] action buttons at the bottom of the panel, left to right.
## One button is [method run_button_rect]; two or more share the panel width (minus the inset
## and the gaps) with the same height. Empty for count <= 0.
static func run_button_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	if count == 1:
		rects.append(run_button_rect(viewport_size))
		return rects
	var panel: Rect2 = run_panel_rect(viewport_size)
	var inset: float = viewport_size.y * RUN_PANEL_INSET_RATIO
	var height: float = viewport_size.y * RUN_BUTTON_HEIGHT_RATIO
	var gap: float = viewport_size.x * RUN_BUTTON_GAP_RATIO
	var width: float = maxf((panel.size.x - inset * 2.0 - gap * (count - 1)) / count, 0.0)
	var top: float = panel.end.y - inset - height
	for i: int in count:
		rects.append(Rect2(panel.position.x + inset + (width + gap) * i, top, width, height))
	return rects


## Menu screens (Story 015): the title band across the top (chapter select, character select,
## reward screen).
static func floor_title_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * FLOOR_TITLE_TOP_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * FLOOR_TITLE_BOTTOM_RATIO - top)


## Chapter select (Story 019): one tile per chapter, left to right in ChaptersConfig order, in a
## centred row under the title band. Empty for count <= 0.
static func chapter_tile_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var size := Vector2(viewport_size.x * CHAPTER_TILE_WIDTH_RATIO, viewport_size.y * CHAPTER_TILE_HEIGHT_RATIO)
	var gap: float = viewport_size.x * CHAPTER_TILE_GAP_RATIO
	var left: float = (viewport_size.x - (size.x * count + gap * (count - 1))) * 0.5
	var top: float = viewport_size.y * CHAPTER_TILES_TOP_RATIO
	for i: int in count:
		rects.append(Rect2(left + (size.x + gap) * i, top, size.x, size.y))
	return rects


## Reward screen (Story 019): [param count] offer cards side by side under the title band, centred,
## left to right in offer order; width = the smaller of the shared width and
## [constant REWARD_CARD_MAX_WIDTH_RATIO]. Empty for count <= 0.
## Story 020: with [param with_remove] the row also reserves the "Bỏ 1 lá" slot
## ([method reward_remove_slot_rect]) right of the last card, and the cards get narrower.
static func reward_card_rects(viewport_size: Vector2, count: int, with_remove: bool = false) -> Array[Rect2]:
	return _card_row(viewport_size, count, REWARD_CARD_ROW_TOP_RATIO, viewport_size.x * 0.5, with_remove)


## 2026-11-01 (user: "sao mỗi ảnh một kiểu format thẻ … OSFE hài hòa, nhỏ gọn, cân đối"): every card face has
## this one size (px at 720p, scaled with the viewport height) on every screen — reward, treasure, shop.
const CARD_FACE_SIZE: Vector2 = Vector2(176.0, 256.0)
## 2026-11-01: top of the plain reward screen's card row — the compact cards sit midway between the title and "Bỏ qua".
const REWARD_CARD_ROW_TOP_RATIO: float = 0.3


## 2026-11-01: the one card face size for [param viewport_size] ([constant CARD_FACE_SIZE]).
static func card_face_size(viewport_size: Vector2) -> Vector2:
	return (CARD_FACE_SIZE * viewport_size.y / 720.0).round()


# 2026-11-01: [param count] card faces of the one size side by side from [param top_ratio], centred on
# [param center_x]; [param with_remove] keeps room for one more card-sized slot on the right.
static func _card_row(viewport_size: Vector2, count: int, top_ratio: float, center_x: float, with_remove: bool) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var size: Vector2 = card_face_size(viewport_size)
	var gap: float = viewport_size.x * REWARD_CARD_GAP_RATIO
	var slots: int = count + (1 if with_remove else 0)
	var left: float = roundf(center_x - (size.x * slots + gap * (slots - 1)) * 0.5)
	var top: float = roundf(viewport_size.y * top_ratio)
	for i: int in count:
		rects.append(Rect2(left + (size.x + gap) * i, top, size.x, size.y))
	return rects


## Reward screen (Story 020): the "Bỏ 1 lá" slot — a narrower fourth card right of the
## [param count] offer cards (same top / height), centred alone when the offer is empty.
static func reward_remove_slot_rect(viewport_size: Vector2, count: int) -> Rect2:
	var gap: float = viewport_size.x * REWARD_CARD_GAP_RATIO
	var size: Vector2 = card_face_size(viewport_size)
	var top: float = roundf(viewport_size.y * REWARD_CARD_ROW_TOP_RATIO)
	var cards: Array[Rect2] = reward_card_rects(viewport_size, count, true)
	var left: float = (viewport_size.x - size.x) * 0.5 if cards.is_empty() else cards[cards.size() - 1].end.x + gap
	return Rect2(left, top, size.x, size.y)


## Reward screen (Story 020), remove list: one tile per deck entry in deck order, rows of
## [constant REWARD_REMOVE_COLS] from the left margin under the title band, at most
## [constant REWARD_REMOVE_ROWS] rows (entries beyond COLS * ROWS get no rect — the view says
## how many are hidden). Empty for count <= 0.
static func reward_remove_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var margin: float = viewport_size.x * MARGIN_RATIO
	var gap: float = viewport_size.x * REWARD_CARD_GAP_RATIO
	var width: float = maxf((viewport_size.x - margin * 2.0 - gap * (REWARD_REMOVE_COLS - 1)) / REWARD_REMOVE_COLS, 0.0)
	var height: float = viewport_size.y * REWARD_REMOVE_TILE_HEIGHT_RATIO
	var row_gap: float = viewport_size.y * REWARD_REMOVE_ROW_GAP_RATIO
	var top: float = viewport_size.y * REWARD_CARDS_TOP_RATIO
	var visible: int = mini(count, REWARD_REMOVE_COLS * REWARD_REMOVE_ROWS)
	for i: int in visible:
		@warning_ignore("integer_division")
		var row: int = i / REWARD_REMOVE_COLS
		var col: int = i % REWARD_REMOVE_COLS
		rects.append(Rect2(margin + (width + gap) * col, top + (height + row_gap) * row, width, height))
	return rects


## Reward screen (Story 020), remove list: the full-width strip between the last tile row and
## the cancel button ([method reward_skip_button_rect]), for the one-line hint.
static func reward_remove_hint_rect(viewport_size: Vector2) -> Rect2:
	var height: float = viewport_size.y * REWARD_REMOVE_TILE_HEIGHT_RATIO
	var row_gap: float = viewport_size.y * REWARD_REMOVE_ROW_GAP_RATIO
	var top: float = viewport_size.y * REWARD_CARDS_TOP_RATIO + (height + row_gap) * REWARD_REMOVE_ROWS
	return Rect2(0.0, top, viewport_size.x, maxf(viewport_size.y * REWARD_SKIP_TOP_RATIO - top, 0.0))


## Reward screen (Story 019): the centred "Bỏ qua" button under the card row (title-button width,
## back-button height: 65 px >= 64 px at 720p).
static func reward_skip_button_rect(viewport_size: Vector2) -> Rect2:
	var size := Vector2(viewport_size.x * TITLE_BUTTON_WIDTH_RATIO, viewport_size.y * BACK_BUTTON_HEIGHT_RATIO)
	return Rect2(Vector2((viewport_size.x - size.x) * 0.5, viewport_size.y * REWARD_SKIP_TOP_RATIO), size)


## Controls v3: the deck label ("Deck: N") was removed from the battle HUD (spec bo-cuc-dieu-khien-v3).


## Boss status readouts (Story 020): the strip right under the boss HP bar (the right half of the
## HUD band as CombatView._draw_hud lays it out: PAD, HUD_GAP_RATIO, FONT_SIZE, the text-to-bar gap
## and BAR_HEIGHT), from the bar's bottom down to the top of the board cells (the band's remaining
## height plus the board area's top padding): 23 px at 1280x720, enough for one small text line.
static func hud_boss_status_rect(viewport_size: Vector2) -> Rect2:
	var hud: Rect2 = hud_rect(viewport_size)
	var gap: float = hud.size.x * CombatView.HUD_GAP_RATIO
	var half_w: float = (hud.size.x - gap) * 0.5 - CombatView.PAD * 2.0
	var right_x: float = hud.position.x + CombatView.PAD + half_w + CombatView.PAD * 2.0 + gap
	var bar_bottom: float = hud.position.y + CombatView.PAD + CombatView.FONT_SIZE + HUD_BAR_TEXT_GAP + CombatView.BAR_HEIGHT
	var cells_top: float = board_area_rect(viewport_size).position.y
	return Rect2(right_x, bar_bottom, half_w, maxf(cells_top - bar_bottom, 0.0))


## Trait readouts (Story 023): the mirror strip right under the PLAYER HP bar (left half of the HUD
## band, same vertical span as [method hud_boss_status_rect]), for left-aligned text. The traits it
## reports (reactor charges, fuse, frost aura) all land on the player's half, so the line sits above
## the half they threaten; clear of the pause button (band centre), the deck label (above the band)
## and the right-aligned learning debug line (boss side).
static func hud_trait_status_rect(viewport_size: Vector2) -> Rect2:
	var hud: Rect2 = hud_rect(viewport_size)
	var gap: float = hud.size.x * CombatView.HUD_GAP_RATIO
	var half_w: float = (hud.size.x - gap) * 0.5 - CombatView.PAD * 2.0
	var boss_strip: Rect2 = hud_boss_status_rect(viewport_size)
	return Rect2(hud.position.x + CombatView.PAD, boss_strip.position.y, half_w, boss_strip.size.y)


## Controls v3: the featured-shape chip was removed (the match intro band shows the shape; the ghost turns gold).


## Title screen (Story 016): the band across the top that holds the game name, the knife motif
## and the tagline.
static func title_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * TITLE_TOP_RATIO
	return Rect2(viewport_size.x * TITLE_LEFT_RATIO, top, viewport_size.x * TITLE_BAND_WIDTH_RATIO, viewport_size.y * TITLE_BOTTOM_RATIO - top)


## Title screen: [param count] buttons in one left column under the title band, top to
## bottom (the first is the main action). Empty for count <= 0.
static func title_button_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var size := Vector2(viewport_size.x * TITLE_BUTTON_WIDTH_RATIO, viewport_size.y * TITLE_BUTTON_HEIGHT_RATIO)
	var gap: float = viewport_size.y * TITLE_BUTTON_GAP_RATIO
	var left: float = viewport_size.x * TITLE_LEFT_RATIO
	if title_menu_right:
		left = viewport_size.x * (1.0 - TITLE_LEFT_RATIO) - size.x
	var top: float = viewport_size.y * TITLE_BUTTONS_TOP_RATIO
	# Story 037: four buttons (Continue, Play, Achievements, Quit) shrink to end by TITLE_BUTTONS_BOTTOM_RATIO.
	size.y = minf(size.y, (viewport_size.y * TITLE_BUTTONS_BOTTOM_RATIO - top - gap * (count - 1)) / count)
	for i: int in count:
		rects.append(Rect2(left, top + (size.y + gap) * i, size.x, size.y))
	return rects


## Title screen (Story 019): the strip right under the first button of [method title_button_rects]
## (the "Tiếp tục run" button; the gap before the next button), for the saved run's one-line summary.
static func title_continue_summary_rect(viewport_size: Vector2) -> Rect2:
	var first: Rect2 = title_button_rects(viewport_size, TITLE_BUTTON_COLUMN_COUNT)[0]
	return Rect2(Vector2(first.position.x, first.end.y), Vector2(first.size.x, viewport_size.y * TITLE_BUTTON_GAP_RATIO))


## Title screen (Story 017): the VI / EN language button in the bottom-right corner (>= 64 px tall
## at 720p), clear of the button column.
static func title_lang_button_rect(viewport_size: Vector2) -> Rect2:
	var size := Vector2(viewport_size.x * TITLE_LANG_BUTTON_WIDTH_RATIO, viewport_size.y * TITLE_LANG_BUTTON_HEIGHT_RATIO)
	var margin: float = viewport_size.y * MARGIN_RATIO
	var x: float = margin if title_menu_right else viewport_size.x - margin - size.x
	return Rect2(Vector2(x, viewport_size.y - margin - size.y), size)


## Controls v3: the pause hit rect, CONTROL_HIT_PX square in the top-right screen corner, enclosing the visible tile
## ([method pause_tile_rect]; 1184-1280 x 0-96 at 1280x720).
static func pause_button_rect(viewport_size: Vector2) -> Rect2:
	var side: float = roundf(CONTROL_HIT_PX * controls_scale(viewport_size))
	return Rect2(viewport_size.x - side, 0.0, side, side).merge(pause_tile_rect(viewport_size))


## Floor select (Story 016): the "Về" (back to title) button, on the left margin inside the
## title band.
static func back_button_rect(viewport_size: Vector2) -> Rect2:
	var title: Rect2 = floor_title_rect(viewport_size)
	var size := Vector2(viewport_size.x * BACK_BUTTON_WIDTH_RATIO, viewport_size.y * BACK_BUTTON_HEIGHT_RATIO)
	return Rect2(Vector2(viewport_size.x * MARGIN_RATIO, title.get_center().y - size.y * 0.5), size)


## Character select (Story 018): [param count] cards side by side under the title band, centred,
## left to right in CharacterConfig order; width = the smaller of the shared width and
## [constant CHARACTER_CARD_MAX_WIDTH_RATIO]. Empty for count <= 0.
static func character_card_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var margin: float = viewport_size.x * MARGIN_RATIO
	var gap: float = viewport_size.x * CHARACTER_CARD_GAP_RATIO
	var shared: float = (viewport_size.x - margin * 2.0 - gap * (count - 1)) / count
	var width: float = maxf(minf(shared, viewport_size.x * CHARACTER_CARD_MAX_WIDTH_RATIO), 0.0)
	var top: float = viewport_size.y * CHARACTER_CARDS_TOP_RATIO
	var height: float = viewport_size.y * CHARACTER_CARDS_BOTTOM_RATIO - top
	var left: float = (viewport_size.x - (width * count + gap * (count - 1))) * 0.5
	for i: int in count:
		rects.append(Rect2(left + (width + gap) * i, top, width, height))
	return rects


## Floor select (Story 018): the selected character's label, right-aligned on the right margin
## inside the title band (mirror of [method back_button_rect]).
static func floor_hero_label_rect(viewport_size: Vector2) -> Rect2:
	var title: Rect2 = floor_title_rect(viewport_size)
	var size := Vector2(viewport_size.x * FLOOR_HERO_LABEL_WIDTH_RATIO, viewport_size.y * BACK_BUTTON_HEIGHT_RATIO)
	return Rect2(Vector2(viewport_size.x * (1.0 - MARGIN_RATIO) - size.x, title.get_center().y - size.y * 0.5), size)


## Awaken button rectangle (Z4): a square of AWAKEN_BUTTON_RATIO of the height (115 px at 720p), centred
## horizontally, half a margin above the bottom of the screen.
static func signature_rect(viewport_size: Vector2) -> Rect2:
	var side: float = viewport_size.y * AWAKEN_BUTTON_RATIO
	return Rect2((viewport_size.x - side) * 0.5, controls_bottom(viewport_size) - side, side, side)


## Signature button (Story 021): the Awaken button, see [method signature_rect].
static func signature_button_rect(viewport_size: Vector2) -> Rect2:
	return signature_rect(viewport_size)


## Charge bar along the bottom edge of the signature button (inside it).
static func signature_charge_rect(viewport_size: Vector2) -> Rect2:
	var button: Rect2 = signature_button_rect(viewport_size)
	var height: float = viewport_size.y * SIGNATURE_CHARGE_HEIGHT_RATIO
	return Rect2(button.position.x, button.end.y - height, button.size.x, height)


## The player's half of the board (cells only), for the signature border.
static func player_half_rect(grid: BoardGrid, viewport_size: Vector2) -> Rect2:
	var board: Rect2 = board_rect(grid, viewport_size)
	return Rect2(board.position, Vector2(cell_size(grid, viewport_size).x * grid.side_cols, board.size.y))


## Thin timer bar along the top of the player's half while a signature runs.
static func signature_timer_rect(grid: BoardGrid, viewport_size: Vector2) -> Rect2:
	var half: Rect2 = player_half_rect(grid, viewport_size)
	return Rect2(half.position, Vector2(half.size.x, half.size.y * SIGNATURE_TIMER_HEIGHT_RATIO))


## Signature name banner: a band across the middle of the whole board.
static func signature_banner_rect(grid: BoardGrid, viewport_size: Vector2) -> Rect2:
	var board: Rect2 = board_rect(grid, viewport_size)
	var height: float = board.size.y * SIGNATURE_BANNER_HEIGHT_RATIO
	return Rect2(board.position.x, board.get_center().y - height * 0.5, board.size.x, height)


## Chapter map (Story 022): the header strip between the title band and the columns, full width,
## for the one-line run summary (hero, HP, deck size, removal tokens, luck).
static func map_header_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * FLOOR_TITLE_BOTTOM_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * MAP_COLUMNS_TOP_RATIO - top)


## Chapter map (Story 022): [param count] column rectangles left to right (map order), sharing the
## width between the screen margins under the header strip. Empty for count <= 0.
static func map_column_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var margin: float = viewport_size.x * MARGIN_RATIO
	var gap: float = viewport_size.x * MAP_COLUMN_GAP_RATIO
	var width: float = maxf((viewport_size.x - margin * 2.0 - gap * (count - 1)) / count, 0.0)
	var top: float = viewport_size.y * MAP_COLUMNS_TOP_RATIO
	var height: float = viewport_size.y * MAP_COLUMNS_BOTTOM_RATIO - top
	for i: int in count:
		rects.append(Rect2(margin + (width + gap) * i, top, width, height))
	return rects


## Chapter map (Story 022): the tile of node [param index] of a column holding [param count] nodes
## (top to bottom), inside [param column] (one of [method map_column_rects]). Tiles are squares of
## the same size in every column (the column width or the height of one of MAP_MAX_NODES slots,
## whichever is smaller), stacked with a gap and centred vertically as a group.
static func map_node_rect(column: Rect2, index: int, count: int) -> Rect2:
	# The gap is a share of the viewport height; the column is (BOTTOM - TOP) of that height.
	var gap: float = column.size.y * MAP_NODE_GAP_RATIO / (MAP_COLUMNS_BOTTOM_RATIO - MAP_COLUMNS_TOP_RATIO)
	var slot: float = (column.size.y - gap * (MAP_MAX_NODES - 1)) / MAP_MAX_NODES
	var side: float = maxf(minf(column.size.x, slot), 0.0)
	var total: float = side * count + gap * (count - 1)
	var top: float = column.get_center().y - total * 0.5 + (side + gap) * index
	return Rect2(column.get_center().x - side * 0.5, top, side, side)


## Chapter map (Story 022): the restart-notice banner, a full-width band across the middle of the
## column area (one tap dismisses it).
static func map_notice_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * MAP_COLUMNS_TOP_RATIO
	var height: float = viewport_size.y * MAP_COLUMNS_BOTTOM_RATIO - top
	var band: float = viewport_size.y * MAP_NOTICE_HEIGHT_RATIO
	return Rect2(0.0, top + (height - band) * 0.5, viewport_size.x, band)


## Rest view (Story 022): the two choice cards ("Nghỉ", "Rèn") side by side, centred under the
## title band.
static func rest_card_rects(viewport_size: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var width: float = viewport_size.x * REST_CARD_WIDTH_RATIO
	var gap: float = viewport_size.x * REST_CARD_GAP_RATIO
	var top: float = viewport_size.y * REST_CARDS_TOP_RATIO
	var height: float = viewport_size.y * REST_CARDS_BOTTOM_RATIO - top
	var left: float = (viewport_size.x - (width * 2.0 + gap)) * 0.5
	for i: int in 2:
		rects.append(Rect2(left + (width + gap) * i, top, width, height))
	return rects


## Reward screen (Story 022): the strip between the title band and the card row, for the one-line
## subtitle of a miniboss / boss offer.
static func reward_subtitle_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * FLOOR_TITLE_BOTTOM_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * REWARD_CARDS_TOP_RATIO - top)


## Story 031: the touch area of a drawn target [param rect] — the rect itself when both sides are at
## least [constant MIN_TOUCH_SIDE], else grown to that size around its centre.
static func touch_rect(rect: Rect2) -> Rect2:
	var grow := Vector2(maxf(MIN_TOUCH_SIDE - rect.size.x, 0.0), maxf(MIN_TOUCH_SIDE - rect.size.y, 0.0)) * 0.5
	return Rect2(rect.position - grow, rect.size + grow * 2.0)


## World map (Story 031): the floor progress strip, between the screen margins under the title band.
static func world_strip_rect(viewport_size: Vector2) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * WORLD_STRIP_TOP_RATIO
	return Rect2(margin, top, viewport_size.x - margin * 2.0, viewport_size.y * WORLD_STRIP_BOTTOM_RATIO - top)


## World map (Story 031): [param count] equal segments of the progress strip, left to right (the
## floors, then the final match). Empty for count <= 0.
static func world_strip_segment_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var strip: Rect2 = world_strip_rect(viewport_size)
	var gap: float = viewport_size.x * WORLD_STRIP_GAP_RATIO
	var width: float = maxf((strip.size.x - gap * (count - 1)) / count, 0.0)
	for i: int in count:
		rects.append(Rect2(strip.position.x + (width + gap) * i, strip.position.y, width, strip.size.y))
	return rects


## World map (Story 031): the region cards at rest — two pinned to the left and right margins (one
## per thumb), one centred; a third or more share the width (not offered in Story 031). Empty for
## count <= 0.
static func world_card_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * WORLD_CARDS_TOP_RATIO
	var height: float = viewport_size.y * WORLD_CARDS_BOTTOM_RATIO - top
	var width: float = viewport_size.x * WORLD_CARD_WIDTH_RATIO
	if count == 1:
		rects.append(Rect2((viewport_size.x - width) * 0.5, top, width, height))
		return rects
	if count == 2:
		rects.append(Rect2(margin, top, width, height))
		rects.append(Rect2(viewport_size.x - margin - width, top, width, height))
		return rects
	var gap: float = viewport_size.x * MAP_COLUMN_GAP_RATIO
	var shared: float = maxf((viewport_size.x - margin * 2.0 - gap * (count - 1)) / count, 0.0)
	for i: int in count:
		rects.append(Rect2(margin + (shared + gap) * i, top, shared, height))
	return rects


## World map (Story 031): how far up a selected card is drawn (its touch area keeps the rest rect
## plus this lift, see [method world_card_touch_rect]).
static func world_card_raise(viewport_size: Vector2) -> float:
	return viewport_size.y * WORLD_CARD_RAISE_RATIO


## World map (Story 031): the touch area of a card at rest [param card]: the card plus the strip it
## rises into when selected, so a tap on a raised card's top edge still lands.
static func world_card_touch_rect(viewport_size: Vector2, card: Rect2) -> Rect2:
	var lift: float = world_card_raise(viewport_size)
	return Rect2(card.position.x, card.position.y - lift, card.size.x, card.size.y + lift)


## World map (Story 031): the "Vào vùng" button at the bottom edge, centred under [param card]
## (the selected card at rest), kept inside the screen margins.
static func world_enter_button_rect(viewport_size: Vector2, card: Rect2) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	var width: float = viewport_size.x * WORLD_ENTER_WIDTH_RATIO
	var top: float = viewport_size.y * WORLD_ENTER_TOP_RATIO
	var left: float = clampf(card.get_center().x - width * 0.5, margin, viewport_size.x - margin - width)
	return Rect2(left, top, width, viewport_size.y * WORLD_ENTER_BOTTOM_RATIO - top)


# --- Story 032: relic strips and the treasure screen with two rows -----------------------------

## Relic strip band (map, world map, pause): top / bottom as shares of the height (0.105 * 720 = 76 px,
## room for a 72 px icon, >= 64 px touch target).
const RELIC_STRIP_TOP_RATIO: float = 0.875
const RELIC_STRIP_BOTTOM_RATIO: float = 0.98
## Treasure screen with a relic row: label bands, the card row, the relic row and the bottom buttons.
const REWARD_DUAL_CARD_LABEL_TOP_RATIO: float = 0.125
const REWARD_DUAL_CARDS_TOP_RATIO: float = 0.175
const REWARD_DUAL_CARDS_BOTTOM_RATIO: float = 0.53
const REWARD_DUAL_RELIC_LABEL_TOP_RATIO: float = 0.54
const REWARD_DUAL_RELICS_TOP_RATIO: float = 0.59
const REWARD_DUAL_RELICS_BOTTOM_RATIO: float = 0.865
const REWARD_DUAL_LABEL_HEIGHT_RATIO: float = 0.045
const REWARD_DUAL_BUTTON_TOP_RATIO: float = 0.885
const REWARD_DUAL_BUTTON_WIDTH_RATIO: float = 0.18


## Story 032: the relic strip band under the chapter map / world map / pause panel, margin to margin.
static func relic_strip_rect(viewport_size: Vector2) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * RELIC_STRIP_TOP_RATIO
	return Rect2(margin, top, viewport_size.x - margin * 2.0, viewport_size.y * RELIC_STRIP_BOTTOM_RATIO - top)


## Story 032: the in-match display-only relic strip (top edge, far from the stick and the bag).
## Controls v3: the top-left corner holds only the relics (this row) and the buffs / debuffs under it
## ([method hud_status_row_rect]): HUD_RELIC_ROW_PX tall, centred on the top row, from the left inset to the right
## edge of the old player corner panel (where the dev-build title line starts; 12-260 x 22-50 at 1280x720).
static func hud_relic_strip_rect(viewport_size: Vector2) -> Rect2:
	var s: float = controls_scale(viewport_size)
	var row: Rect2 = hud_top_row_rect(viewport_size)
	var left: float = floorf(HUD_TOP_ROW_INSET_PX * s)
	var right: float = hud_panel_rect(viewport_size, 0).end.x
	var h: float = roundf(HUD_RELIC_ROW_PX * s)
	return Rect2(left, roundf(row.get_center().y - h * 0.5), maxf(right - left, 0.0), h)


## Story 032, treasure screen with a relic row: "Bỏ qua" at the bottom-left.
static func reward_dual_skip_rect(viewport_size: Vector2) -> Rect2:
	var size := Vector2(viewport_size.x * REWARD_DUAL_BUTTON_WIDTH_RATIO, viewport_size.y * BACK_BUTTON_HEIGHT_RATIO)
	return Rect2(Vector2(viewport_size.x * MARGIN_RATIO, viewport_size.y * REWARD_DUAL_BUTTON_TOP_RATIO), size)


## Story 032, treasure screen with a relic row: "Xác nhận" (relic pick) at the bottom-right.
static func reward_dual_confirm_rect(viewport_size: Vector2) -> Rect2:
	var size := Vector2(viewport_size.x * REWARD_DUAL_BUTTON_WIDTH_RATIO, viewport_size.y * BACK_BUTTON_HEIGHT_RATIO)
	return Rect2(Vector2(viewport_size.x * (1.0 - MARGIN_RATIO) - size.x, viewport_size.y * REWARD_DUAL_BUTTON_TOP_RATIO), size)


## Story 032: the owned-relic strip of the reward screen. With a relic row ([param dual]) it sits between
## "Bỏ qua" and "Xác nhận"; on the plain card offer it fills the left of the centred skip button.
static func reward_relic_strip_rect(viewport_size: Vector2, dual: bool) -> Rect2:
	var gap: float = viewport_size.x * REWARD_CARD_GAP_RATIO
	if dual:
		var skip: Rect2 = reward_dual_skip_rect(viewport_size)
		var confirm: Rect2 = reward_dual_confirm_rect(viewport_size)
		return Rect2(skip.end.x + gap, skip.position.y, maxf(confirm.position.x - gap - skip.end.x - gap, 0.0), skip.size.y)
	var centred: Rect2 = reward_skip_button_rect(viewport_size)
	var left: float = viewport_size.x * MARGIN_RATIO
	return Rect2(left, centred.position.y, maxf(centred.position.x - gap - left, 0.0), centred.size.y)


## Story 032: label band above the card row ("CHỌN MỘT LÁ").
static func reward_dual_cards_label_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(0.0, viewport_size.y * REWARD_DUAL_CARD_LABEL_TOP_RATIO, viewport_size.x, viewport_size.y * REWARD_DUAL_LABEL_HEIGHT_RATIO)


## Story 032: label band above the relic row ("HOẶC MỘT BẢO VẬT").
static func reward_dual_relics_label_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(0.0, viewport_size.y * REWARD_DUAL_RELIC_LABEL_TOP_RATIO, viewport_size.x, viewport_size.y * REWARD_DUAL_LABEL_HEIGHT_RATIO)


## Story 032: the card row of the treasure screen with a relic row (plus room for the "Bỏ 1 lá" slot).
static func reward_dual_card_rects(viewport_size: Vector2, count: int, with_remove: bool = false) -> Array[Rect2]:
	return _card_row(viewport_size, count, REWARD_DUAL_CARDS_TOP_RATIO, viewport_size.x * 0.5, with_remove)


## Story 032: the 3 large relic cards of the treasure screen, centred.
static func reward_dual_relic_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	return _reward_row(viewport_size, count, REWARD_DUAL_RELICS_TOP_RATIO, REWARD_DUAL_RELICS_BOTTOM_RATIO, 0.0)


# Story 032: [param count] centred cards between [param top_ratio] and [param bottom_ratio] of the height
# (widths as reward_card_rects); [param extra_ratio] > 0 reserves a narrower slot on the right.
static func _reward_row(viewport_size: Vector2, count: int, top_ratio: float, bottom_ratio: float, extra_ratio: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var margin: float = viewport_size.x * MARGIN_RATIO
	var gap: float = viewport_size.x * REWARD_CARD_GAP_RATIO
	var extra: float = viewport_size.x * extra_ratio + gap if extra_ratio > 0.0 else 0.0
	var shared: float = (viewport_size.x - margin * 2.0 - gap * (count - 1) - extra) / count
	var width: float = maxf(minf(shared, viewport_size.x * REWARD_CARD_MAX_WIDTH_RATIO), 0.0)
	var top: float = viewport_size.y * top_ratio
	var height: float = viewport_size.y * bottom_ratio - top
	var left: float = (viewport_size.x - (width * count + gap * (count - 1) + extra)) * 0.5
	for i: int in count:
		rects.append(Rect2(left + (width + gap) * i, top, width, height))
	return rects


# --- Story 033: shop and event screens, the deck picker ------------------------------------------

## Shop: the item rows fill [MARGIN_RATIO, SHOP_ROWS_RIGHT_RATIO] of the width; the services column
## sits right of it. Label bands, card row, relic row as shares of the height (720p: cards 227 px,
## relics 176 px tall; every target well above 64 px).
const SHOP_ROWS_RIGHT_RATIO: float = 0.74
const SHOP_CARD_LABEL_TOP_RATIO: float = 0.135
const SHOP_LABEL_HEIGHT_RATIO: float = 0.045
const SHOP_CARDS_TOP_RATIO: float = 0.185
const SHOP_CARDS_BOTTOM_RATIO: float = 0.5
const SHOP_RELIC_LABEL_TOP_RATIO: float = 0.545
const SHOP_RELICS_TOP_RATIO: float = 0.595
const SHOP_RELICS_BOTTOM_RATIO: float = 0.81
const SHOP_ITEM_GAP_RATIO: float = 0.02
const SHOP_ITEM_MAX_WIDTH_RATIO: float = 0.2
## How far a selected item rises (share of the height).
## 2026-11-01: 0 — a selected card rose into the row label (user); the gold ring marks the selection now.
const SHOP_ITEM_RAISE_RATIO: float = 0.0
const SHOP_SERVICE_LEFT_RATIO: float = 0.765
const SHOP_SERVICE_GAP_RATIO: float = 0.03
## Bottom band: "Rời cửa hàng" bottom-left, "Mua (N vàng)" bottom-right (right thumb), a message between.
const SHOP_BUTTON_TOP_RATIO: float = 0.85
const SHOP_BUTTON_BOTTOM_RATIO: float = 0.97
const SHOP_LEAVE_WIDTH_RATIO: float = 0.24
const SHOP_BUY_WIDTH_RATIO: float = 0.28
## Long-press detail panel (share of the screen).
const SHOP_DETAIL_WIDTH_RATIO: float = 0.5
const SHOP_DETAIL_HEIGHT_RATIO: float = 0.66
## Deck picker: a horizontally scrolling row of card tiles across the full width.
const DECK_PICKER_TOP_RATIO: float = 0.2
const DECK_PICKER_BOTTOM_RATIO: float = 0.66
const DECK_PICKER_TILE_WIDTH_RATIO: float = 0.15
const DECK_PICKER_TILE_HEIGHT_RATIO: float = 0.36
const DECK_PICKER_GAP_RATIO: float = 0.015
const DECK_PICKER_HINT_TOP_RATIO: float = 0.7
const DECK_PICKER_HINT_BOTTOM_RATIO: float = 0.8
## Event: the text box (upper half), the choice stack (lower half), button height cap and gap.
const EVENT_TEXT_TOP_RATIO: float = 0.14
const EVENT_TEXT_BOTTOM_RATIO: float = 0.5
const EVENT_CHOICES_TOP_RATIO: float = 0.53
const EVENT_CHOICES_BOTTOM_RATIO: float = 0.97
const EVENT_CHOICE_WIDTH_RATIO: float = 0.84
const EVENT_CHOICE_MAX_HEIGHT_RATIO: float = 0.13
const EVENT_CHOICE_GAP_RATIO: float = 0.015
## Event result with a card offer: the text box shrinks to this bottom, the cards fill the rest.
const EVENT_RESULT_SHORT_BOTTOM_RATIO: float = 0.36
const EVENT_OFFER_TOP_RATIO: float = 0.39
const EVENT_OFFER_BOTTOM_RATIO: float = 0.82


# Story 033: [param count] shop items centred in the rows area between [param top_ratio] and
# [param bottom_ratio] of the height (width capped at SHOP_ITEM_MAX_WIDTH_RATIO).
static func _shop_row(viewport_size: Vector2, count: int, top_ratio: float, bottom_ratio: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var area: Rect2 = shop_rows_area_rect(viewport_size)
	var gap: float = viewport_size.x * SHOP_ITEM_GAP_RATIO
	var width: float = maxf(minf((area.size.x - gap * (count - 1)) / count, viewport_size.x * SHOP_ITEM_MAX_WIDTH_RATIO), 0.0)
	var top: float = viewport_size.y * top_ratio
	var left: float = area.position.x + (area.size.x - (width * count + gap * (count - 1))) * 0.5
	for i: int in count:
		rects.append(Rect2(left + (width + gap) * i, top, width, viewport_size.y * bottom_ratio - top))
	return rects


## Story 033: the area of the two item rows (left of the services column), full height.
static func shop_rows_area_rect(viewport_size: Vector2) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	return Rect2(margin, 0.0, viewport_size.x * SHOP_ROWS_RIGHT_RATIO - margin, viewport_size.y)


## Story 033: the card row of the shop.
static func shop_card_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	return _card_row(viewport_size, count, SHOP_CARDS_TOP_RATIO, shop_rows_area_rect(viewport_size).get_center().x, false)


## Story 033: the relic row of the shop.
static func shop_relic_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	return _shop_row(viewport_size, count, SHOP_RELICS_TOP_RATIO, SHOP_RELICS_BOTTOM_RATIO)


## Story 033: label band above the shop's card row ("Lá") — with [param relics], above the relic row.
static func shop_row_label_rect(viewport_size: Vector2, relics: bool) -> Rect2:
	var area: Rect2 = shop_rows_area_rect(viewport_size)
	var top: float = viewport_size.y * (SHOP_RELIC_LABEL_TOP_RATIO if relics else SHOP_CARD_LABEL_TOP_RATIO)
	return Rect2(area.position.x, top, area.size.x, viewport_size.y * SHOP_LABEL_HEIGHT_RATIO)


## Story 033: label band above the services column ("Dịch vụ").
static func shop_services_label_rect(viewport_size: Vector2) -> Rect2:
	var left: float = viewport_size.x * SHOP_SERVICE_LEFT_RATIO
	return Rect2(left, viewport_size.y * SHOP_CARD_LABEL_TOP_RATIO, viewport_size.x * (1.0 - MARGIN_RATIO) - left, viewport_size.y * SHOP_LABEL_HEIGHT_RATIO)


## Story 033: the two service buttons (remove a card, heal) stacked at the right edge.
static func shop_service_rects(viewport_size: Vector2) -> Array[Rect2]:
	var left: float = viewport_size.x * SHOP_SERVICE_LEFT_RATIO
	var width: float = viewport_size.x * (1.0 - MARGIN_RATIO) - left
	var top: float = viewport_size.y * SHOP_CARDS_TOP_RATIO
	var gap: float = viewport_size.y * SHOP_SERVICE_GAP_RATIO
	var height: float = (viewport_size.y * SHOP_RELICS_BOTTOM_RATIO - top - gap) * 0.5
	var rects: Array[Rect2] = [Rect2(left, top, width, height), Rect2(left, top + height + gap, width, height)]
	return rects


## Story 033: how far a selected shop item is drawn up (its touch area adds this lift on top).
static func shop_item_raise(viewport_size: Vector2) -> float:
	return viewport_size.y * SHOP_ITEM_RAISE_RATIO


## Story 033: bottom-left button ("Rời cửa hàng", "Thôi").
static func shop_leave_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * SHOP_BUTTON_TOP_RATIO
	return Rect2(viewport_size.x * MARGIN_RATIO, top, viewport_size.x * SHOP_LEAVE_WIDTH_RATIO, viewport_size.y * SHOP_BUTTON_BOTTOM_RATIO - top)


## Story 033: bottom-right button ("Mua (N vàng)", confirm, "Tiếp tục") — the right thumb's spot.
static func shop_buy_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * SHOP_BUTTON_TOP_RATIO
	var width: float = viewport_size.x * SHOP_BUY_WIDTH_RATIO
	return Rect2(viewport_size.x * (1.0 - MARGIN_RATIO) - width, top, width, viewport_size.y * SHOP_BUTTON_BOTTOM_RATIO - top)


## Story 033: the one-line message between the two bottom buttons (result of a buy, refusal reason).
static func shop_message_rect(viewport_size: Vector2) -> Rect2:
	var leave: Rect2 = shop_leave_rect(viewport_size)
	var buy: Rect2 = shop_buy_rect(viewport_size)
	var gap: float = viewport_size.x * SHOP_ITEM_GAP_RATIO
	return Rect2(leave.end.x + gap, leave.position.y, maxf(buy.position.x - leave.end.x - gap * 2.0, 0.0), leave.size.y)


## Story 033: the long-press detail panel, centred.
static func shop_detail_rect(viewport_size: Vector2) -> Rect2:
	var size := Vector2(viewport_size.x * SHOP_DETAIL_WIDTH_RATIO, viewport_size.y * SHOP_DETAIL_HEIGHT_RATIO)
	return Rect2((viewport_size - size) * 0.5, size)


## Story 033: the deck picker's scrolling band (full width; tiles scroll past the screen edges).
static func deck_picker_row_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * DECK_PICKER_TOP_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * DECK_PICKER_BOTTOM_RATIO - top)


## Story 033: size of one deck picker tile.
static func deck_picker_tile_size(viewport_size: Vector2) -> Vector2:
	return Vector2(viewport_size.x * DECK_PICKER_TILE_WIDTH_RATIO, viewport_size.y * DECK_PICKER_TILE_HEIGHT_RATIO)


## Story 033: the hint line under the deck picker row.
static func deck_picker_hint_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * DECK_PICKER_HINT_TOP_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * DECK_PICKER_HINT_BOTTOM_RATIO - top)


## Story 033: the event text box (upper half); [param short] shrinks it above a card-offer row.
static func event_text_rect(viewport_size: Vector2, short: bool = false) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * EVENT_TEXT_TOP_RATIO
	var bottom: float = viewport_size.y * (EVENT_RESULT_SHORT_BOTTOM_RATIO if short else EVENT_TEXT_BOTTOM_RATIO)
	return Rect2(margin, top, viewport_size.x - margin * 2.0, bottom - top)


## Story 033: [param count] wide event choice buttons stacked in the lower half, centred, each at most
## EVENT_CHOICE_MAX_HEIGHT_RATIO tall (4 choices at 720p: 69 px each).
static func event_choice_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var top: float = viewport_size.y * EVENT_CHOICES_TOP_RATIO
	var gap: float = viewport_size.y * EVENT_CHOICE_GAP_RATIO
	var avail: float = viewport_size.y * EVENT_CHOICES_BOTTOM_RATIO - top
	var height: float = minf((avail - gap * (count - 1)) / count, viewport_size.y * EVENT_CHOICE_MAX_HEIGHT_RATIO)
	var width: float = viewport_size.x * EVENT_CHOICE_WIDTH_RATIO
	var left: float = (viewport_size.x - width) * 0.5
	for i: int in count:
		rects.append(Rect2(left, top + (height + gap) * i, width, height))
	return rects


## Story 033: the card-offer row of an event result (the text box is short above it), centred.
static func event_offer_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	return _reward_row(viewport_size, count, EVENT_OFFER_TOP_RATIO, EVENT_OFFER_BOTTOM_RATIO, 0.0)


# --- Story 034 (P3b): the ink row of the reward screen, the shop's services column ---------------

## Plain reward screen WITH an ink row: the card row shrinks to 0.17 .. 0.53 (259 px at 720p, compact
## cards), the ink label band starts at 0.545 and the ink row fills 0.595 .. 0.835 (173 px). The centred
## skip button keeps its place at REWARD_SKIP_TOP_RATIO (0.86): nothing is pushed out of the thumb zone.
const REWARD_INK_CARDS_BOTTOM_RATIO: float = 0.53
## 2026-11-01: the ink row is a step of its own (before the card choice), so it sits under the title.
const REWARD_INK_LABEL_TOP_RATIO: float = 0.2
const REWARD_INK_ROW_TOP_RATIO: float = 0.26
const REWARD_INK_ROW_BOTTOM_RATIO: float = 0.5
## Treasure screen with a relic row AND an ink row: cards 0.175 .. 0.39 (155 px), relic label 0.398,
## relics 0.445 .. 0.645 (144 px), ink label 0.653, ink row 0.7 .. 0.87 (122 px); "Bỏ qua" / "Xác nhận"
## keep REWARD_DUAL_BUTTON_TOP_RATIO (0.885).
const REWARD_INK_DUAL_CARDS_BOTTOM_RATIO: float = 0.39
const REWARD_INK_DUAL_RELIC_LABEL_TOP_RATIO: float = 0.398
const REWARD_INK_DUAL_RELICS_TOP_RATIO: float = 0.445
const REWARD_INK_DUAL_RELICS_BOTTOM_RATIO: float = 0.645
const REWARD_INK_DUAL_LABEL_TOP_RATIO: float = 0.653
const REWARD_INK_DUAL_ROW_TOP_RATIO: float = 0.7
const REWARD_INK_DUAL_ROW_BOTTOM_RATIO: float = 0.87
## One ink tile's width (0.22 * 1280 = 282 px; height = the row, >= 122 px) and the ink row's two buttons
## (0.15 * 1280 = 192 px wide, BACK_BUTTON_HEIGHT_RATIO tall = 65 px >= 64 px), right-aligned in the row.
const REWARD_INK_TILE_WIDTH_RATIO: float = 0.22
const REWARD_INK_BUTTON_WIDTH_RATIO: float = 0.15


## Story 034: the card row of the reward screen while an ink row is open ([param dual] = the treasure
## screen that also carries a relic row); [param with_remove] reserves the "Bỏ 1 lá" slot as usual.
static func reward_ink_card_rects(viewport_size: Vector2, count: int, with_remove: bool, dual: bool) -> Array[Rect2]:
	var top: float = REWARD_DUAL_CARDS_TOP_RATIO if dual else REWARD_CARDS_TOP_RATIO
	var bottom: float = REWARD_INK_DUAL_CARDS_BOTTOM_RATIO if dual else REWARD_INK_CARDS_BOTTOM_RATIO
	return _reward_row(viewport_size, count, top, bottom, REWARD_REMOVE_SLOT_WIDTH_RATIO if with_remove else 0.0)


## Story 034: the relic row of the treasure screen while an ink row is open (shorter, moved up).
static func reward_ink_relic_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	return _reward_row(viewport_size, count, REWARD_INK_DUAL_RELICS_TOP_RATIO, REWARD_INK_DUAL_RELICS_BOTTOM_RATIO, 0.0)


## Story 034: the relic row's label band while an ink row is open.
static func reward_ink_relics_label_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(0.0, viewport_size.y * REWARD_INK_DUAL_RELIC_LABEL_TOP_RATIO, viewport_size.x, viewport_size.y * REWARD_DUAL_LABEL_HEIGHT_RATIO)


## Story 034: the ink row's label band ("ẤN HÌNH").
static func reward_ink_label_rect(viewport_size: Vector2, dual: bool) -> Rect2:
	var top: float = REWARD_INK_DUAL_LABEL_TOP_RATIO if dual else REWARD_INK_LABEL_TOP_RATIO
	return Rect2(0.0, viewport_size.y * top, viewport_size.x, viewport_size.y * REWARD_DUAL_LABEL_HEIGHT_RATIO)


## Story 034: the whole ink row band, margin to margin.
static func reward_ink_row_rect(viewport_size: Vector2, dual: bool) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * (REWARD_INK_DUAL_ROW_TOP_RATIO if dual else REWARD_INK_ROW_TOP_RATIO)
	var bottom: float = viewport_size.y * (REWARD_INK_DUAL_ROW_BOTTOM_RATIO if dual else REWARD_INK_ROW_BOTTOM_RATIO)
	return Rect2(margin, top, viewport_size.x - margin * 2.0, bottom - top)


## Story 034: [param count] ink tiles from the left of the ink row, full row height. Empty for count <= 0.
static func reward_ink_tile_rects(viewport_size: Vector2, count: int, dual: bool) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var row: Rect2 = reward_ink_row_rect(viewport_size, dual)
	var gap: float = viewport_size.x * REWARD_CARD_GAP_RATIO
	var width: float = viewport_size.x * REWARD_INK_TILE_WIDTH_RATIO
	for i: int in maxi(count, 0):
		rects.append(Rect2(row.position.x + (width + gap) * i, row.position.y, width, row.size.y))
	return rects


## Story 034: the ink row's confirm button, at the right end of the row (right thumb), vertically centred.
static func reward_ink_confirm_rect(viewport_size: Vector2, dual: bool) -> Rect2:
	var row: Rect2 = reward_ink_row_rect(viewport_size, dual)
	var size := Vector2(viewport_size.x * REWARD_INK_BUTTON_WIDTH_RATIO, minf(viewport_size.y * BACK_BUTTON_HEIGHT_RATIO, row.size.y))
	return Rect2(Vector2(row.end.x - size.x, row.get_center().y - size.y * 0.5), size)


## Story 034: the ink row's small skip button, left of its confirm button.
static func reward_ink_skip_rect(viewport_size: Vector2, dual: bool) -> Rect2:
	var confirm: Rect2 = reward_ink_confirm_rect(viewport_size, dual)
	var gap: float = viewport_size.x * REWARD_CARD_GAP_RATIO
	return Rect2(confirm.position.x - gap - confirm.size.x, confirm.position.y, confirm.size.x, confirm.size.y)


## Story 034: [param count] service buttons stacked in the shop's services column (the area of
## [method shop_service_rects]); three at 720p are (450 - 2 * 21.6) / 3 = 135 px tall >= 64 px.
static func shop_service_column_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var left: float = viewport_size.x * SHOP_SERVICE_LEFT_RATIO
	var width: float = viewport_size.x * (1.0 - MARGIN_RATIO) - left
	var top: float = viewport_size.y * SHOP_CARDS_TOP_RATIO
	var gap: float = viewport_size.y * SHOP_SERVICE_GAP_RATIO
	var height: float = (viewport_size.y * SHOP_RELICS_BOTTOM_RATIO - top - gap * (count - 1)) / count
	for i: int in count:
		rects.append(Rect2(left, top + (height + gap) * i, width, height))
	return rects


# --- Story 034: piece deck screen and the map HUD "Bộ mảnh" button (P3a) ---------------------------

## Piece deck grid: top and bottom of the tile area (shares of height), tiles per row, gaps between
## tiles (column gap share of width, row gap share of height), tallest tile as a multiple of its width.
const PIECE_DECK_GRID_TOP_RATIO: float = 0.16
const PIECE_DECK_GRID_BOTTOM_RATIO: float = 0.78
const PIECE_DECK_COLUMNS: int = 8
const PIECE_DECK_GAP_RATIO: float = 0.012
const PIECE_DECK_ROW_GAP_RATIO: float = 0.03
const PIECE_DECK_TILE_MAX_ASPECT: float = 1.35
## How far a selected tile is drawn up (share of height).
const PIECE_DECK_RAISE_RATIO: float = 0.02
## The refusal line right above the bottom-right button: top / bottom (shares of height) and width as a
## multiple of that button's width (right-aligned with it).
const PIECE_DECK_REASON_TOP_RATIO: float = 0.79
const PIECE_DECK_REASON_BOTTOM_RATIO: float = 0.845
const PIECE_DECK_REASON_WIDTH_SCALE: float = 1.8
## Map HUD "Bộ mảnh" button: width (share of width) and the gap to the back button (share of width).
const MAP_PIECE_DECK_BUTTON_WIDTH_RATIO: float = 0.12
const MAP_PIECE_DECK_BUTTON_GAP_RATIO: float = 0.012


## Story 034: [param count] piece deck tiles in rows of PIECE_DECK_COLUMNS (each row centred, the block
## centred vertically in the grid area), in the given order. At 1280x720 with 16 shapes: 137 x 185 px.
## Empty for count <= 0.
static func piece_deck_tile_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * PIECE_DECK_GRID_TOP_RATIO
	var avail_h: float = viewport_size.y * PIECE_DECK_GRID_BOTTOM_RATIO - top
	var gap: float = viewport_size.x * PIECE_DECK_GAP_RATIO
	var row_gap: float = viewport_size.y * PIECE_DECK_ROW_GAP_RATIO
	var columns: int = mini(count, PIECE_DECK_COLUMNS)
	var row_count: int = ceili(float(count) / PIECE_DECK_COLUMNS)
	var width: float = maxf((viewport_size.x - margin * 2.0 - gap * (PIECE_DECK_COLUMNS - 1)) / PIECE_DECK_COLUMNS, 0.0)
	var height: float = minf(maxf((avail_h - row_gap * (row_count - 1)) / row_count, 0.0), width * PIECE_DECK_TILE_MAX_ASPECT)
	var block_top: float = top + (avail_h - (height * row_count + row_gap * (row_count - 1))) * 0.5
	for i: int in count:
		var r: int = floori(float(i) / PIECE_DECK_COLUMNS)
		var in_row: int = mini(count - r * PIECE_DECK_COLUMNS, columns)
		var left: float = (viewport_size.x - (width * in_row + gap * (in_row - 1))) * 0.5
		rects.append(Rect2(left + (width + gap) * (i % PIECE_DECK_COLUMNS), block_top + (height + row_gap) * r, width, height))
	return rects


## Story 034: how far a selected piece deck tile is drawn up (its touch area adds this lift on top).
static func piece_deck_tile_raise(viewport_size: Vector2) -> float:
	return viewport_size.y * PIECE_DECK_RAISE_RATIO


## Story 034: the refusal line right above the bottom-right button (shop_buy_rect), right-aligned with it.
static func piece_deck_reason_rect(viewport_size: Vector2) -> Rect2:
	var button: Rect2 = shop_buy_rect(viewport_size)
	var width: float = minf(button.size.x * PIECE_DECK_REASON_WIDTH_SCALE, viewport_size.x * (1.0 - MARGIN_RATIO * 2.0))
	var top: float = viewport_size.y * PIECE_DECK_REASON_TOP_RATIO
	return Rect2(button.end.x - width, top, width, viewport_size.y * PIECE_DECK_REASON_BOTTOM_RATIO - top)


## Story 034: the "Bộ mảnh" button of the world map / chapter map title band, right of the back button and
## as tall as it (hit-test it on touch_rect, like the back button).
static func map_piece_deck_button_rect(viewport_size: Vector2) -> Rect2:
	var back: Rect2 = back_button_rect(viewport_size)
	var left: float = back.end.x + viewport_size.x * MAP_PIECE_DECK_BUTTON_GAP_RATIO
	return Rect2(left, back.position.y, viewport_size.x * MAP_PIECE_DECK_BUTTON_WIDTH_RATIO, back.size.y)


# --- Story 035: fate screen, ending screen, defeat panel --------------------------------------------

## Story 035: fate buttons (Tha / Giết): width share of each, the outer margin, and their top / bottom.
const FATE_BUTTON_WIDTH_RATIO: float = 0.4
const FATE_BUTTON_SIDE_RATIO: float = 0.06
const FATE_BUTTON_TOP_RATIO: float = 0.52
const FATE_BUTTON_BOTTOM_RATIO: float = 0.8
## Story 035: the consequence line under each fate button (top / bottom) and the hold hint above them.
const FATE_LINE_TOP_RATIO: float = 0.82
const FATE_LINE_BOTTOM_RATIO: float = 0.9
const FATE_HINT_TOP_RATIO: float = 0.42
const FATE_HINT_BOTTOM_RATIO: float = 0.5
## Story 035: the boss name band and the question line of the fate screen.
const FATE_TITLE_TOP_RATIO: float = 0.05
const FATE_TITLE_BOTTOM_RATIO: float = 0.17
const FATE_QUESTION_BOTTOM_RATIO: float = 0.25
## Story 035: ending screen bands (title, story lines, stats block, bottom buttons).
const ENDING_TITLE_TOP_RATIO: float = 0.03
const ENDING_TITLE_BOTTOM_RATIO: float = 0.13
const ENDING_LINES_TOP_RATIO: float = 0.14
const ENDING_LINE_HEIGHT_RATIO: float = 0.052
const ENDING_STATS_TOP_RATIO: float = 0.36
const ENDING_STATS_BOTTOM_RATIO: float = 0.76
const ENDING_BUTTON_TOP_RATIO: float = 0.79
const ENDING_BUTTON_BOTTOM_RATIO: float = 0.95
const ENDING_LEAVE_WIDTH_RATIO: float = 0.4
const ENDING_PAGE_WIDTH_RATIO: float = 0.18
## Story 035: the wide defeat panel (RUN KẾT THÚC with the stats block) and its bands.
const DEFEAT_PANEL_SIDE_RATIO: float = 0.04
const DEFEAT_PANEL_TOP_RATIO: float = 0.03
const DEFEAT_STATS_TOP_RATIO: float = 0.25
const DEFEAT_STATS_GAP_RATIO: float = 0.02


## Story 035: the two fate buttons in the bottom half, [Tha (left thumb), Giết (right thumb)], each
## FATE_BUTTON_WIDTH_RATIO (>= 35 %) of the width.
static func fate_button_rects(viewport_size: Vector2) -> Array[Rect2]:
	var width: float = viewport_size.x * FATE_BUTTON_WIDTH_RATIO
	var side: float = viewport_size.x * FATE_BUTTON_SIDE_RATIO
	var top: float = viewport_size.y * FATE_BUTTON_TOP_RATIO
	var height: float = viewport_size.y * FATE_BUTTON_BOTTOM_RATIO - top
	return [Rect2(side, top, width, height), Rect2(viewport_size.x - side - width, top, width, height)]


## Story 035: the consequence line under fate button [param button] (same x span).
static func fate_line_rect(viewport_size: Vector2, button: Rect2) -> Rect2:
	var top: float = viewport_size.y * FATE_LINE_TOP_RATIO
	return Rect2(button.position.x, top, button.size.x, viewport_size.y * FATE_LINE_BOTTOM_RATIO - top)


## Story 035: the "Giữ để xác nhận" hint band right above the fate buttons.
static func fate_hint_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * FATE_HINT_TOP_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * FATE_HINT_BOTTOM_RATIO - top)


## Story 035: the boss name band at the top of the fate screen.
static func fate_title_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * FATE_TITLE_TOP_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * FATE_TITLE_BOTTOM_RATIO - top)


## Story 035: the question line under the boss name.
static func fate_question_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * FATE_TITLE_BOTTOM_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * FATE_QUESTION_BOTTOM_RATIO - top)


## Story 035: the ending title band.
static func ending_title_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * ENDING_TITLE_TOP_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * ENDING_TITLE_BOTTOM_RATIO - top)


## Story 035: story line [param index] (0-based) of the ending, one under the other.
static func ending_line_rect(viewport_size: Vector2, index: int) -> Rect2:
	var height: float = viewport_size.y * ENDING_LINE_HEIGHT_RATIO
	var margin: float = viewport_size.x * MARGIN_RATIO
	return Rect2(margin, viewport_size.y * ENDING_LINES_TOP_RATIO + height * index, viewport_size.x - margin * 2.0, height)


## Story 035: the run stats block of the ending screen (two columns are laid inside it).
static func ending_stats_rect(viewport_size: Vector2) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO * 2.0
	var top: float = viewport_size.y * ENDING_STATS_TOP_RATIO
	return Rect2(margin, top, viewport_size.x - margin * 2.0, viewport_size.y * ENDING_STATS_BOTTOM_RATIO - top)


## Story 035: the big "Về màn chính" button, centred in the bottom band.
static func ending_leave_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * ENDING_BUTTON_TOP_RATIO
	var width: float = viewport_size.x * ENDING_LEAVE_WIDTH_RATIO
	return Rect2((viewport_size.x - width) * 0.5, top, width, viewport_size.y * ENDING_BUTTON_BOTTOM_RATIO - top)


## Story 035: the stats page button (only when the stats need two pages), bottom-right, as tall as the
## leave button (>= 96 px at 720 px high).
static func ending_page_rect(viewport_size: Vector2) -> Rect2:
	var leave: Rect2 = ending_leave_rect(viewport_size)
	var width: float = viewport_size.x * ENDING_PAGE_WIDTH_RATIO
	return Rect2(viewport_size.x * (1.0 - MARGIN_RATIO) - width, leave.position.y, width, leave.size.y)


## Story 035: the wide RUN KẾT THÚC panel (it carries the stats block); its bottom matches
## run_panel_rect so the run buttons (run_button_rects) stay where they were.
static func defeat_panel_rect(viewport_size: Vector2) -> Rect2:
	var side: float = viewport_size.x * DEFEAT_PANEL_SIDE_RATIO
	var top: float = viewport_size.y * DEFEAT_PANEL_TOP_RATIO
	return Rect2(side, top, viewport_size.x - side * 2.0, run_panel_rect(viewport_size).end.y - top)


## Story 035: the stats block of the defeat panel, between the death lines and the buttons.
static func defeat_stats_rect(viewport_size: Vector2) -> Rect2:
	var panel: Rect2 = defeat_panel_rect(viewport_size)
	var inset: float = viewport_size.y * RUN_PANEL_INSET_RATIO
	var top: float = viewport_size.y * DEFEAT_STATS_TOP_RATIO
	var bottom: float = run_button_rect(viewport_size).position.y - viewport_size.y * DEFEAT_STATS_GAP_RATIO
	return Rect2(panel.position.x + inset * 2.0, top, panel.size.x - inset * 4.0, bottom - top)

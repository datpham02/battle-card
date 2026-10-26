class_name ScreenLayout
extends RefCounted
## Landscape screen layout (phone held sideways). Pure geometry (no nodes): every function
## takes the viewport size and returns rectangles in viewport (canvas) pixels. Ratios are
## layout constants, not tuning. Reference viewport is 1280x720 (see project.godot).
## Vertical partition (shares of height): arena (HUD band + board) 0.03-0.55, then the
## bottom zone: d-pad at the bottom-left, hold-slot row at the bottom-right.
## The board size and shape come from a BoardGrid, passed as the first parameter of every
## board function; nothing here knows how many cells there are.

## Horizontal screen margin as a share of viewport width.
const MARGIN_RATIO: float = 0.03
## Gap between the bottom of the screen and the d-pad / hand row, as a share of viewport height.
const BOTTOM_MARGIN_RATIO: float = 0.02
## Arena: top and bottom edges as a share of viewport height.
const ARENA_TOP_RATIO: float = 0.03
const ARENA_BOTTOM_RATIO: float = 0.55
## Hand slot height as a share of viewport height; width = height / SLOT_ASPECT.
const SLOT_HEIGHT_RATIO: float = 0.22
const SLOT_ASPECT: float = 1.4
## Gap between hand slots, as a share of viewport width.
const SLOT_GAP_RATIO: float = 0.02
## Gap between the hand row and the area on its left (hosts the FULL label), share of width.
const SLOT_SIDE_GAP_RATIO: float = 0.02
## D-pad button edge as a share of viewport height (0.135 * 720 = 97 px, thumb size) and
## the gap between buttons.
const DPAD_BUTTON_RATIO: float = 0.135
const DPAD_GAP_RATIO: float = 0.008
## HUD band at the top of the arena (HP bars) as a share of arena height; the board fills the rest.
const HUD_HEIGHT_RATIO: float = 0.2
## Vertical padding above and below the board inside the board area, as a share of its height.
const BOARD_PAD_RATIO: float = 0.04
## Preferred cell width divided by cell height (shrinks if the board would not fit the width).
const CELL_ASPECT: float = 1.4
## Returned by cell_at() when the point is outside the board's bounding rectangle.
const NO_CELL: Vector2i = BoardGrid.NO_CELL
## Cut UI (Story 008). The confirm button fills the gap between the d-pad and the hand row,
## minus a strip at the row's left reserved for the "FULL" label (share of width).
const CONFIRM_FULL_RESERVE_RATIO: float = 0.09
## Left edge of the strip between the arena and the hand row (share of width); clear of the d-pad.
const STRIP_LEFT_RATIO: float = 0.28
## Vertical gap around the strip, and inner padding of the skill panel (shares of height).
const STRIP_GAP_RATIO: float = 0.012
const MENU_PAD_RATIO: float = 0.012
## Countdown bar height (share of height) and gap between skill buttons (share of width).
const MENU_BAR_HEIGHT_RATIO: float = 0.02
const MENU_BUTTON_GAP_RATIO: float = 0.008
## Run UI (Story 011), shares of the viewport: intro band height; panel size; panel inner
## inset; action button height (0.14 * 720 = 101 px >= 96 px) and its width as a share of the panel.
const RUN_INTRO_HEIGHT_RATIO: float = 0.3
const RUN_PANEL_WIDTH_RATIO: float = 0.5
const RUN_PANEL_HEIGHT_RATIO: float = 0.7
const RUN_PANEL_INSET_RATIO: float = 0.035
const RUN_BUTTON_HEIGHT_RATIO: float = 0.14
const RUN_BUTTON_WIDTH_RATIO: float = 0.7
## Focus UI (Story 012): height of the "TẬP TRUNG" countdown / cooldown bar (share of height).
## 0.032 * 720 = 23 px: fits under the strip's "Sát thương" line and above the CONFIRM button.
const FOCUS_BAR_HEIGHT_RATIO: float = 0.032
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
const REWARD_CARDS_BOTTOM_RATIO: float = 0.82
const REWARD_CARD_GAP_RATIO: float = 0.02
const REWARD_CARD_MAX_WIDTH_RATIO: float = 0.27
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
## Run HUD (Story 019): left edge (share of width) of the deck label strip in the top margin;
## the centred match label (~450 px at 16 px) ends well before 0.72 * 1280 = 922 px.
const RUN_DECK_LABEL_LEFT_RATIO: float = 0.72
## Title screen (Story 016), shares of the viewport: the name band (top .. bottom: game name,
## knife motif, tagline), the button column's top, one button's size (0.3 * 1280 = 384 px wide,
## 0.11 * 720 = 79 px tall >= 72 px) and the gap between buttons (share of height). Three
## buttons end at 0.47 + 3 * 0.11 + 2 * 0.025 = 0.85 of the height.
const TITLE_TOP_RATIO: float = 0.08
const TITLE_BOTTOM_RATIO: float = 0.42
const TITLE_BUTTONS_TOP_RATIO: float = 0.47
const TITLE_BUTTON_WIDTH_RATIO: float = 0.3
const TITLE_BUTTON_HEIGHT_RATIO: float = 0.11
const TITLE_BUTTON_GAP_RATIO: float = 0.025
## Story 037: the lowest the title button column may reach (share of the height).
const TITLE_BUTTONS_BOTTOM_RATIO: float = 0.95
## Story 037: the full column (Continue, Play, Achievements, Quit); the continue summary strip sits under its first button.
const TITLE_BUTTON_COLUMN_COUNT: int = 4
## Title screen language button (Story 017): width / height as shares of the viewport.
const TITLE_LANG_BUTTON_WIDTH_RATIO: float = 0.1
const TITLE_LANG_BUTTON_HEIGHT_RATIO: float = 0.09
## Pause button (Story 016): a square of 0.09 * 720 = 65 px (>= 64 px touch target) centred in
## the HUD band, in the free column between the two HP bars (68 px wide at 1280x720: the band's
## HUD_GAP_RATIO plus CombatView's paddings). The top margin above holds the match label and is
## too thin for a touch target; both band halves end in right/left-aligned HP text.
const PAUSE_BUTTON_RATIO: float = 0.09
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
## Signature skill UI (Story 021): button height (0.12 * 720 = 86 px >= 64 px, share of height),
## the charge bar inside its bottom edge (share of height), the active-timer bar along the top of
## the player's half (share of the board height) and the banner's height (share of the board height).
## The button's width is whatever is free between the Focus bar and the FULL-label zone's right edge.
const SIGNATURE_BUTTON_HEIGHT_RATIO: float = 0.12
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


## Rectangle of the arena area (HUD band + board).
static func arena_rect(viewport_size: Vector2) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * ARENA_TOP_RATIO
	var bottom: float = viewport_size.y * ARENA_BOTTOM_RATIO
	return Rect2(margin, top, viewport_size.x - margin * 2.0, bottom - top)


## Size of one hold slot.
static func slot_size(viewport_size: Vector2) -> Vector2:
	var height: float = viewport_size.y * SLOT_HEIGHT_RATIO
	return Vector2(height / SLOT_ASPECT, height)


## Slot rectangles, left to right, flush with the bottom-right corner.
static func slot_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var size: Vector2 = slot_size(viewport_size)
	var gap: float = viewport_size.x * SLOT_GAP_RATIO
	var total: float = size.x * count + gap * (count - 1)
	var left: float = viewport_size.x - viewport_size.x * MARGIN_RATIO - total
	var top: float = viewport_size.y * (1.0 - BOTTOM_MARGIN_RATIO) - size.y
	for i: int in count:
		rects.append(Rect2(left + (size.x + gap) * i, top, size.x, size.y))
	return rects


## Bounding rectangle of the d-pad (plus layout, bottom-left corner).
static func dpad_bounds(viewport_size: Vector2) -> Rect2:
	var button: float = viewport_size.y * DPAD_BUTTON_RATIO
	var gap: float = viewport_size.y * DPAD_GAP_RATIO
	var side: float = button * 3.0 + gap * 2.0
	var left: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * (1.0 - BOTTOM_MARGIN_RATIO) - side
	return Rect2(left, top, side, side)


## D-pad button rectangles keyed by direction (Vector2i.UP/DOWN/LEFT/RIGHT), plus layout.
static func dpad_rects(viewport_size: Vector2) -> Dictionary:
	var button: float = viewport_size.y * DPAD_BUTTON_RATIO
	var gap: float = viewport_size.y * DPAD_GAP_RATIO
	var step: float = button + gap
	var bounds: Rect2 = dpad_bounds(viewport_size)
	var size := Vector2(button, button)
	var o: Vector2 = bounds.position
	return {
		Vector2i.UP: Rect2(o + Vector2(step, 0.0), size),
		Vector2i.LEFT: Rect2(o + Vector2(0.0, step), size),
		Vector2i.RIGHT: Rect2(o + Vector2(step * 2.0, step), size),
		Vector2i.DOWN: Rect2(o + Vector2(step, step * 2.0), size),
	}


## HUD band at the top of the arena (HP bars; nothing else draws here).
static func hud_rect(viewport_size: Vector2) -> Rect2:
	var arena: Rect2 = arena_rect(viewport_size)
	return Rect2(arena.position, Vector2(arena.size.x, arena.size.y * HUD_HEIGHT_RATIO))


## Area below the HUD band that the board shares.
static func board_area_rect(viewport_size: Vector2) -> Rect2:
	var arena: Rect2 = arena_rect(viewport_size)
	var hud_h: float = arena.size.y * HUD_HEIGHT_RATIO
	return Rect2(arena.position.x, arena.position.y + hud_h, arena.size.x, arena.size.y - hud_h)


## Size of one board cell: height fits the rows, width is CELL_ASPECT times that, shrunk so
## all columns of [param grid] fit the arena width (big grids get smaller cells).
static func cell_size(grid: BoardGrid, viewport_size: Vector2) -> Vector2:
	var area: Rect2 = board_area_rect(viewport_size)
	var h: float = area.size.y * (1.0 - BOARD_PAD_RATIO * 2.0) / grid.rows
	var w: float = minf(h * CELL_ASPECT, area.size.x / grid.total_cols)
	return Vector2(w, h)


## Bounding rectangle of the whole board, centred in the board area.
static func board_rect(grid: BoardGrid, viewport_size: Vector2) -> Rect2:
	var area: Rect2 = board_area_rect(viewport_size)
	var size: Vector2 = cell_size(grid, viewport_size) * Vector2(grid.total_cols, grid.rows)
	return Rect2(area.get_center() - size * 0.5, size)


## Rectangle of board cell [param cell] (its position in the bounding grid; the cell should
## be a real cell, see BoardGrid.is_in_board).
static func cell_rect(grid: BoardGrid, viewport_size: Vector2, cell: Vector2i) -> Rect2:
	var size: Vector2 = cell_size(grid, viewport_size)
	var origin: Vector2 = board_rect(grid, viewport_size).position
	return Rect2(origin + size * Vector2(cell), size)


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


## Free area left of the hand row (same vertical extent as the slots), from the d-pad's right
## edge plus the side gap to the row minus the side gap. Hosts the "FULL" label.
static func slot_side_left_rect(viewport_size: Vector2, count: int) -> Rect2:
	var rects: Array[Rect2] = slot_rects(viewport_size, count)
	if rects.is_empty():
		return Rect2()
	var gap: float = viewport_size.x * SLOT_SIDE_GAP_RATIO
	var left: float = dpad_bounds(viewport_size).end.x + gap
	var first: Rect2 = rects[0]
	return Rect2(left, first.position.y, maxf(first.position.x - gap - left, 0.0), first.size.y)


## CONFIRM ("Chốt") button: the free area between the d-pad and the hand row, same vertical
## extent as the slots, leaving room for the "FULL" label. Laid out for the widest hand so it
## never overlaps a slot whatever the slot count.
static func confirm_button_rect(viewport_size: Vector2) -> Rect2:
	var side: Rect2 = slot_side_left_rect(viewport_size, HoldSlots.MAX_SLOTS)
	var reserve: float = viewport_size.x * CONFIRM_FULL_RESERVE_RATIO
	return Rect2(side.position, Vector2(maxf(side.size.x - reserve, 0.0), side.size.y))


## Story 024: inset of the ROTATE ("Xoay") button from the d-pad's bounding square, in px.
const ROTATE_BUTTON_INSET: float = 6.0
## Story 024: while PLACING the d-pad is locked, so its whole square becomes one big ROTATE button
## the left thumb can hold while the right finger drags.
static func rotate_button_rect(viewport_size: Vector2) -> Rect2:
	return dpad_bounds(viewport_size).grow(-ROTATE_BUTTON_INSET)


## Story 024: top of the CANCEL button as a share of the slot height, measured from the hand row's
## top (clear of the "DỪNG" tag, which is 26 px high on the same zone).
const CANCEL_TOP_RATIO: float = 0.3
## Story 024: CANCEL button ("Hủy", PLACING and the card menu): the FULL-label reserve zone right of
## the CONFIRM button, below the focus tag, down to the hand row's bottom.
static func cancel_button_rect(viewport_size: Vector2) -> Rect2:
	var side: Rect2 = slot_side_left_rect(viewport_size, HoldSlots.MAX_SLOTS)
	var confirm: Rect2 = confirm_button_rect(viewport_size)
	var gap: float = viewport_size.x * SLOT_SIDE_GAP_RATIO * 0.5
	var left: float = confirm.end.x + gap
	var top: float = side.position.y + side.size.y * CANCEL_TOP_RATIO
	return Rect2(left, top, maxf(side.end.x - left, 0.0), maxf(side.end.y - top, 0.0))


## Strip between the arena bottom and the hand row, right of the d-pad column. Hosts the
## skill panel, and (split in halves) the preview and swing text.
static func cut_strip_rect(viewport_size: Vector2) -> Rect2:
	var gap: float = viewport_size.y * STRIP_GAP_RATIO
	var top: float = arena_rect(viewport_size).end.y + gap
	var hand_top: float = viewport_size.y * (1.0 - BOTTOM_MARGIN_RATIO) - slot_size(viewport_size).y
	var left: float = viewport_size.x * STRIP_LEFT_RATIO
	var right: float = viewport_size.x * (1.0 - MARGIN_RATIO)
	return Rect2(left, top, right - left, maxf(hand_top - gap - top, 0.0))


## Skill menu panel (the whole strip).
static func skill_menu_panel_rect(viewport_size: Vector2) -> Rect2:
	return cut_strip_rect(viewport_size)


## Countdown bar across the top of the skill panel.
static func skill_menu_bar_rect(viewport_size: Vector2) -> Rect2:
	var panel: Rect2 = skill_menu_panel_rect(viewport_size)
	var pad: float = viewport_size.y * MENU_PAD_RATIO
	return Rect2(panel.position + Vector2(pad, pad), Vector2(maxf(panel.size.x - pad * 2.0, 0.0), viewport_size.y * MENU_BAR_HEIGHT_RATIO))


## One button rectangle per skill, left to right, under the countdown bar inside the panel.
static func skill_menu_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var panel: Rect2 = skill_menu_panel_rect(viewport_size)
	var bar: Rect2 = skill_menu_bar_rect(viewport_size)
	var pad: float = viewport_size.y * MENU_PAD_RATIO
	var gap: float = viewport_size.x * MENU_BUTTON_GAP_RATIO
	var top: float = bar.end.y + pad
	var height: float = maxf(panel.end.y - pad - top, 0.0)
	var width: float = maxf((panel.size.x - pad * 2.0 - gap * (count - 1)) / count, 0.0)
	for i: int in count:
		rects.append(Rect2(panel.position.x + pad + (width + gap) * i, top, width, height))
	return rects


## Share of the strip's free width (right of the signature button) taken by the cell-count /
## damage readout; the rotate hint gets the rest (Story 024).
const PREVIEW_INFO_SHARE: float = 0.42


## Cell count and expected damage of the piece being placed: the strip right of the signature
## button (it used to start at the strip's left edge, under that button).
static func cut_preview_info_rect(viewport_size: Vector2) -> Rect2:
	var strip: Rect2 = cut_strip_rect(viewport_size)
	var gap: float = viewport_size.y * STRIP_GAP_RATIO
	var left: float = signature_button_rect(viewport_size).end.x + gap
	return Rect2(left, strip.position.y, maxf(strip.end.x - left, 0.0) * PREVIEW_INFO_SHARE, strip.size.y)


## Story 024: the rotate hint, right of the readout in the same strip.
static func place_hint_rect(viewport_size: Vector2) -> Rect2:
	var info: Rect2 = cut_preview_info_rect(viewport_size)
	var strip: Rect2 = cut_strip_rect(viewport_size)
	return Rect2(info.end.x, strip.position.y, maxf(strip.end.x - info.end.x, 0.0), strip.size.y)


## Right half of the strip: skill name and countdown of the running swing.
static func cut_swing_info_rect(viewport_size: Vector2) -> Rect2:
	var strip: Rect2 = cut_strip_rect(viewport_size)
	return Rect2(strip.position + Vector2(strip.size.x * 0.5, 0.0), Vector2(strip.size.x * 0.5, strip.size.y))


## Focus UI (Story 012): the "TẬP TRUNG" countdown (or cooldown) bar. As wide as the CONFIRM
## button and right above it, one strip gap up, inside the bottom band of the strip (the
## preview's cell count and damage text sit in the upper 85% of the strip, so they stay clear).
static func focus_bar_rect(viewport_size: Vector2) -> Rect2:
	var confirm: Rect2 = confirm_button_rect(viewport_size)
	var gap: float = viewport_size.y * STRIP_GAP_RATIO
	var height: float = viewport_size.y * FOCUS_BAR_HEIGHT_RATIO
	return Rect2(Vector2(confirm.position.x, confirm.position.y - gap - height), Vector2(confirm.size.x, height))


## Run UI (Story 011). Match label: the thin margin above the arena (clear of the HP bars
## and the boss hand tags, which live inside the HUD band), full width, for centred text.
static func run_match_label_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(0.0, 0.0, viewport_size.x, viewport_size.y * ARENA_TOP_RATIO)


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
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var margin: float = viewport_size.x * MARGIN_RATIO
	var gap: float = viewport_size.x * REWARD_CARD_GAP_RATIO
	var extra: float = viewport_size.x * REWARD_REMOVE_SLOT_WIDTH_RATIO + gap if with_remove else 0.0
	var shared: float = (viewport_size.x - margin * 2.0 - gap * (count - 1) - extra) / count
	var width: float = maxf(minf(shared, viewport_size.x * REWARD_CARD_MAX_WIDTH_RATIO), 0.0)
	var top: float = viewport_size.y * REWARD_CARDS_TOP_RATIO
	var height: float = viewport_size.y * REWARD_CARDS_BOTTOM_RATIO - top
	var left: float = (viewport_size.x - (width * count + gap * (count - 1) + extra)) * 0.5
	for i: int in count:
		rects.append(Rect2(left + (width + gap) * i, top, width, height))
	return rects


## Reward screen (Story 020): the "Bỏ 1 lá" slot — a narrower fourth card right of the
## [param count] offer cards (same top / height), centred alone when the offer is empty.
static func reward_remove_slot_rect(viewport_size: Vector2, count: int) -> Rect2:
	var gap: float = viewport_size.x * REWARD_CARD_GAP_RATIO
	var width: float = viewport_size.x * REWARD_REMOVE_SLOT_WIDTH_RATIO
	var top: float = viewport_size.y * REWARD_CARDS_TOP_RATIO
	var height: float = viewport_size.y * REWARD_CARDS_BOTTOM_RATIO - top
	var cards: Array[Rect2] = reward_card_rects(viewport_size, count, true)
	var left: float = (viewport_size.x - width) * 0.5 if cards.is_empty() else cards[cards.size() - 1].end.x + gap
	return Rect2(left, top, width, height)


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


## Run HUD (Story 019): the deck label strip — the right part of the top margin (same height as
## [method run_match_label_rect], from [constant RUN_DECK_LABEL_LEFT_RATIO] to the right screen
## margin), for right-aligned text; above the HUD band, so clear of the pause button.
static func run_deck_label_rect(viewport_size: Vector2) -> Rect2:
	var left: float = viewport_size.x * RUN_DECK_LABEL_LEFT_RATIO
	var right: float = viewport_size.x * (1.0 - MARGIN_RATIO)
	return Rect2(left, 0.0, right - left, viewport_size.y * ARENA_TOP_RATIO)


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
	var area: Rect2 = board_area_rect(viewport_size)
	var cells_top: float = area.position.y + area.size.y * BOARD_PAD_RATIO
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


## Story 028: the featured-shape icon, a square at the right end of the PLAYER half's HP text row
## (the HUD band's top padding plus the text row: above the HP bar, clear of the pause button column
## and of the left-aligned "YOU HP" text; its tiny label is drawn to its left).
const FEATURED_ICON_SIZE: float = 38.0
static func featured_icon_rect(viewport_size: Vector2) -> Rect2:
	var hud: Rect2 = hud_rect(viewport_size)
	var gap: float = hud.size.x * CombatView.HUD_GAP_RATIO
	var half_w: float = (hud.size.x - gap) * 0.5 - CombatView.PAD * 2.0
	var right: float = hud.position.x + CombatView.PAD + half_w
	return Rect2(right - FEATURED_ICON_SIZE, hud.position.y + 4.0, FEATURED_ICON_SIZE, FEATURED_ICON_SIZE)


## Title screen (Story 016): the band across the top that holds the game name, the knife motif
## and the tagline.
static func title_rect(viewport_size: Vector2) -> Rect2:
	var top: float = viewport_size.y * TITLE_TOP_RATIO
	return Rect2(0.0, top, viewport_size.x, viewport_size.y * TITLE_BOTTOM_RATIO - top)


## Title screen: [param count] buttons in one centred column under the title band, top to
## bottom (the first is the main action). Empty for count <= 0.
static func title_button_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var size := Vector2(viewport_size.x * TITLE_BUTTON_WIDTH_RATIO, viewport_size.y * TITLE_BUTTON_HEIGHT_RATIO)
	var gap: float = viewport_size.y * TITLE_BUTTON_GAP_RATIO
	var left: float = (viewport_size.x - size.x) * 0.5
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
	return Rect2(Vector2(viewport_size.x - margin - size.x, viewport_size.y - margin - size.y), size)


## Pause button (Story 016): a square centred in the HUD band, between the two HP bars.
static func pause_button_rect(viewport_size: Vector2) -> Rect2:
	var hud: Rect2 = hud_rect(viewport_size)
	var side := Vector2.ONE * viewport_size.y * PAUSE_BUTTON_RATIO
	return Rect2(hud.get_center() - side * 0.5, side)


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


## Signature button (Story 021): in the strip above the hand row, right of the Focus bar and
## ending at the right edge of the FULL-label zone (so it sits over the hand row's left end,
## clear of the slots, the CONFIRM button and the d-pad); its bottom is the Focus bar's bottom.
static func signature_button_rect(viewport_size: Vector2) -> Rect2:
	var bar: Rect2 = focus_bar_rect(viewport_size)
	var side: Rect2 = slot_side_left_rect(viewport_size, HoldSlots.MAX_SLOTS)
	var gap: float = viewport_size.y * STRIP_GAP_RATIO
	var left: float = bar.end.x + gap
	var height: float = viewport_size.y * SIGNATURE_BUTTON_HEIGHT_RATIO
	return Rect2(left, bar.end.y - height, maxf(side.end.x - left, 0.0), height)


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
## In-match relic strip (display only): in the HUD band between the player's name (left share) and the
## featured-shape label (room left of the featured icon, share of width); icon edge and top pad in px.
const HUD_RELIC_LEFT_RATIO: float = 0.225
const HUD_RELIC_LABEL_ROOM_RATIO: float = 0.1
const HUD_RELIC_ICON: float = 26.0
const HUD_RELIC_TOP_PAD: float = 6.0


## Story 032: the relic strip band under the chapter map / world map / pause panel, margin to margin.
static func relic_strip_rect(viewport_size: Vector2) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * RELIC_STRIP_TOP_RATIO
	return Rect2(margin, top, viewport_size.x - margin * 2.0, viewport_size.y * RELIC_STRIP_BOTTOM_RATIO - top)


## Story 032: the in-match display-only relic strip (top edge, HUD band, far from the d-pad and the bag).
static func hud_relic_strip_rect(viewport_size: Vector2) -> Rect2:
	var hud: Rect2 = hud_rect(viewport_size)
	var left: float = viewport_size.x * HUD_RELIC_LEFT_RATIO
	var right: float = featured_icon_rect(viewport_size).position.x - viewport_size.x * HUD_RELIC_LABEL_ROOM_RATIO
	return Rect2(left, hud.position.y + HUD_RELIC_TOP_PAD, maxf(right - left, 0.0), HUD_RELIC_ICON)


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
	return _reward_row(viewport_size, count, REWARD_DUAL_CARDS_TOP_RATIO, REWARD_DUAL_CARDS_BOTTOM_RATIO,
		REWARD_REMOVE_SLOT_WIDTH_RATIO if with_remove else 0.0)


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
const SHOP_RELIC_LABEL_TOP_RATIO: float = 0.515
const SHOP_RELICS_TOP_RATIO: float = 0.565
const SHOP_RELICS_BOTTOM_RATIO: float = 0.81
const SHOP_ITEM_GAP_RATIO: float = 0.02
const SHOP_ITEM_MAX_WIDTH_RATIO: float = 0.2
## How far a selected item rises (share of the height).
const SHOP_ITEM_RAISE_RATIO: float = 0.025
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
	return _shop_row(viewport_size, count, SHOP_CARDS_TOP_RATIO, SHOP_CARDS_BOTTOM_RATIO)


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
const REWARD_INK_LABEL_TOP_RATIO: float = 0.545
const REWARD_INK_ROW_TOP_RATIO: float = 0.595
const REWARD_INK_ROW_BOTTOM_RATIO: float = 0.835
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

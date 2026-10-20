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


## Left half of the strip: cell count and expected damage of the current selection.
static func cut_preview_info_rect(viewport_size: Vector2) -> Rect2:
	var strip: Rect2 = cut_strip_rect(viewport_size)
	return Rect2(strip.position, Vector2(strip.size.x * 0.5, strip.size.y))


## Right half of the strip: skill name and countdown of the running swing.
static func cut_swing_info_rect(viewport_size: Vector2) -> Rect2:
	var strip: Rect2 = cut_strip_rect(viewport_size)
	return Rect2(strip.position + Vector2(strip.size.x * 0.5, 0.0), Vector2(strip.size.x * 0.5, strip.size.y))


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

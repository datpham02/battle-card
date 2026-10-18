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

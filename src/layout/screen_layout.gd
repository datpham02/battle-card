class_name ScreenLayout
extends RefCounted
## Landscape screen layout (phone held sideways), top to bottom: arena area (HUD band +
## 3 lane rows), hold-slot row, conveyor belt. Pure geometry (no nodes): every function
## takes the viewport size and returns rectangles in viewport (canvas) pixels. Ratios are
## layout constants, not tuning. Reference viewport is 1280x720 (see project.godot);
## everything scales from it. Vertical partition (shares of height): arena 0.03-0.51,
## slot row centred at 0.63, belt 0.75-0.98.

## Horizontal screen margin as a share of viewport width.
const MARGIN_RATIO: float = 0.03
## Arena: top and bottom edges as a share of viewport height.
const ARENA_TOP_RATIO: float = 0.03
const ARENA_BOTTOM_RATIO: float = 0.51
## Vertical centre of the hold-slot row as a share of viewport height.
const SLOTS_CENTER_Y_RATIO: float = 0.63
## Belt strip: top edge and height as a share of viewport height (bottom, thumb-reachable).
const BELT_TOP_RATIO: float = 0.75
const BELT_HEIGHT_RATIO: float = 0.23
## Card height divided by card width.
const CARD_ASPECT: float = 1.4
## Share of the belt strip height a card fills; card size derives from belt height only
## (width = height / CARD_ASPECT) so cards stay card-sized on a wide landscape belt.
const CARD_BELT_FILL: float = 0.75
## Slot padding around a card and gap between slots, as a share of viewport width.
const SLOT_PAD_RATIO: float = 0.011
const SLOT_GAP_RATIO: float = 0.02
## Gap between the slot row and the side indicator areas, as a share of viewport width.
const SLOT_SIDE_GAP_RATIO: float = 0.02
## Width of the recovery bar in the right side area, as a share of viewport width.
const RECOVERY_BAR_WIDTH_RATIO: float = 0.17
## Number of fixed combat lanes: horizontal rows stacked inside the arena (0 = top row).
const LANE_COUNT: int = 3
## HUD band at the top of the arena (HP bars) as a share of arena height; lanes fill the rest.
const HUD_HEIGHT_RATIO: float = 0.22
## Player marker horizontal centre as a share of arena width (left edge of its row).
const PLAYER_X_RATIO: float = 0.16
## Enemy body horizontal centre as a share of arena width (right edge of its row).
const ENEMY_X_RATIO: float = 0.84


## Rectangle of the arena area (HUD band + lane rows).
static func arena_rect(viewport_size: Vector2) -> Rect2:
	var margin: float = viewport_size.x * MARGIN_RATIO
	var top: float = viewport_size.y * ARENA_TOP_RATIO
	var bottom: float = viewport_size.y * ARENA_BOTTOM_RATIO
	return Rect2(margin, top, viewport_size.x - margin * 2.0, bottom - top)


## Rectangle of the conveyor belt strip (full width).
static func belt_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(
		0.0,
		viewport_size.y * BELT_TOP_RATIO,
		viewport_size.x,
		viewport_size.y * BELT_HEIGHT_RATIO
	)


## Size of one card (same on the belt and in a slot), derived from the belt height.
static func card_size(viewport_size: Vector2) -> Vector2:
	var height: float = belt_rect(viewport_size).size.y * CARD_BELT_FILL
	return Vector2(height / CARD_ASPECT, height)


## Size of one hold slot (a card plus padding).
static func slot_size(viewport_size: Vector2) -> Vector2:
	return card_size(viewport_size) + Vector2.ONE * viewport_size.x * SLOT_PAD_RATIO * 2.0


## Slot rectangles, left to right, centred horizontally in the slot row.
static func slot_rects(viewport_size: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var size: Vector2 = slot_size(viewport_size)
	var gap: float = viewport_size.x * SLOT_GAP_RATIO
	var total: float = size.x * count + gap * (count - 1)
	var left: float = (viewport_size.x - total) * 0.5
	var top: float = viewport_size.y * SLOTS_CENTER_Y_RATIO - size.y * 0.5
	for i: int in count:
		rects.append(Rect2(left + (size.x + gap) * i, top, size.x, size.y))
	return rects


## HUD band at the top of the arena (HP bars and armor text; nothing else draws here).
static func hud_rect(viewport_size: Vector2) -> Rect2:
	var arena: Rect2 = arena_rect(viewport_size)
	return Rect2(arena.position, Vector2(arena.size.x, arena.size.y * HUD_HEIGHT_RATIO))


## Area below the HUD band that the lane rows share.
static func lanes_rect(viewport_size: Vector2) -> Rect2:
	var arena: Rect2 = arena_rect(viewport_size)
	var hud_h: float = arena.size.y * HUD_HEIGHT_RATIO
	return Rect2(arena.position.x, arena.position.y + hud_h, arena.size.x, arena.size.y - hud_h)


## Row of lane [param lane] (0..LANE_COUNT-1, top to bottom) spanning the arena width.
static func lane_rect(viewport_size: Vector2, lane: int) -> Rect2:
	var lanes: Rect2 = lanes_rect(viewport_size)
	var height: float = lanes.size.y / LANE_COUNT
	return Rect2(lanes.position.x, lanes.position.y + height * lane, lanes.size.x, height)


## Lane row under [param point], or -1 if the point is outside the lane area (HUD included).
static func lane_at(viewport_size: Vector2, point: Vector2) -> int:
	var lanes: Rect2 = lanes_rect(viewport_size)
	if not lanes.has_point(point):
		return -1
	var height: float = lanes.size.y / LANE_COUNT
	return clampi(int((point.y - lanes.position.y) / height), 0, LANE_COUNT - 1)


## Centre of the player marker when standing in [param lane] (left side of the row).
static func player_marker_center(viewport_size: Vector2, lane: int) -> Vector2:
	var rect: Rect2 = lane_rect(viewport_size, lane)
	return Vector2(rect.position.x + rect.size.x * PLAYER_X_RATIO, rect.get_center().y)


## Centre of the enemy body when standing in [param lane] (right side of the row).
static func enemy_center(viewport_size: Vector2, lane: int) -> Vector2:
	var rect: Rect2 = lane_rect(viewport_size, lane)
	return Vector2(rect.position.x + rect.size.x * ENEMY_X_RATIO, rect.get_center().y)


## Free area left of the slot row (same vertical extent as the slots), from the screen
## margin to the row minus the side gap. Hosts the "FULL" label.
static func slot_side_left_rect(viewport_size: Vector2, count: int) -> Rect2:
	var rects: Array[Rect2] = slot_rects(viewport_size, count)
	if rects.is_empty():
		return Rect2()
	var margin: float = viewport_size.x * MARGIN_RATIO
	var gap: float = viewport_size.x * SLOT_SIDE_GAP_RATIO
	var first: Rect2 = rects[0]
	return Rect2(margin, first.position.y, first.position.x - gap - margin, first.size.y)


## Free area right of the slot row (same vertical extent as the slots), from the row plus
## the side gap to the screen margin. Hosts the recovery indicator.
static func slot_side_right_rect(viewport_size: Vector2, count: int) -> Rect2:
	var rects: Array[Rect2] = slot_rects(viewport_size, count)
	if rects.is_empty():
		return Rect2()
	var margin: float = viewport_size.x * MARGIN_RATIO
	var gap: float = viewport_size.x * SLOT_SIDE_GAP_RATIO
	var last: Rect2 = rects[rects.size() - 1]
	var left: float = last.end.x + gap
	return Rect2(left, last.position.y, viewport_size.x - margin - left, last.size.y)

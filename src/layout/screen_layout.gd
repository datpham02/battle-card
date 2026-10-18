class_name ScreenLayout
extends RefCounted
## Portrait screen layout, top to bottom: arena area, hold-slot row, conveyor belt.
## Pure geometry (no nodes): every function takes the viewport size and returns
## rectangles in viewport (canvas) pixels. Ratios are layout constants, not tuning.
## Reference viewport is 720x1280 (see project.godot); everything scales from it.

## Horizontal screen margin as a share of viewport width.
const MARGIN_RATIO: float = 0.03
## Arena placeholder: top and bottom edges as a share of viewport height (Story 003 fills it).
const ARENA_TOP_RATIO: float = 0.02
const ARENA_BOTTOM_RATIO: float = 0.46
## Vertical centre of the hold-slot row as a share of viewport height.
const SLOTS_CENTER_Y_RATIO: float = 0.60
## Belt strip: top edge and height as a share of viewport height (bottom, thumb-reachable).
const BELT_TOP_RATIO: float = 0.76
const BELT_HEIGHT_RATIO: float = 0.20
## Card width as a share of viewport width; chosen so neighbouring belt cards do not overlap.
const CARD_WIDTH_RATIO: float = 0.17
## Card height divided by card width.
const CARD_ASPECT: float = 1.4
## Share of the belt strip height a card may fill.
const CARD_BELT_FILL: float = 0.85
## Slot padding around a card and gap between slots, as a share of viewport width.
const SLOT_PAD_RATIO: float = 0.011
const SLOT_GAP_RATIO: float = 0.02


## Rectangle of the (empty, for now) arena area.
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


## Size of one card (same on the belt and in a slot).
static func card_size(viewport_size: Vector2) -> Vector2:
	var width: float = viewport_size.x * CARD_WIDTH_RATIO
	var height: float = width * CARD_ASPECT
	var max_height: float = belt_rect(viewport_size).size.y * CARD_BELT_FILL
	if height > max_height:
		height = max_height
		width = height / CARD_ASPECT
	return Vector2(width, height)


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

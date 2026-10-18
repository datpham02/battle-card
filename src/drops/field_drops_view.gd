class_name FieldDropsView
extends Node2D
## Draws the player half's field points above the board: a tag with the point LABEL, a
## freshness bar that shrinks, green -> yellow -> red colour, a blink for the last seconds,
## and a "FULL" tag on the point the player stands on while the hand is full (the point
## stays on the field, so the reason is visible). Placeholder art.
## Implements: Story 007.

const COLOR_FRESH: Color = Color(0.2, 0.75, 0.3)
const COLOR_WARN: Color = Color(0.95, 0.8, 0.1)
const COLOR_ROTTEN: Color = Color(0.9, 0.2, 0.15)
const TAG_BACK: Color = Color(1.0, 1.0, 1.0, 0.92)
const TEXT_COLOR: Color = Color(0.15, 0.12, 0.1)
const FULL_BACK: Color = Color(0.95, 0.7, 0.1)
## Freshness share (left / total) at or above which a point is "fresh" (green), and at or
## above which it is "warning" (yellow); below that it is red.
const FRESH_RATIO: float = 0.55
const WARN_RATIO: float = 0.28
## Seconds left at which a point starts to blink, and blink phases per second.
const BLINK_SEC: float = 2.0
const BLINK_HZ: float = 3.0
const BLINK_DIM_ALPHA: float = 0.35
## Tag size and top offset as shares of the cell size; freshness bar share of cell width/height.
const TAG_WIDTH_RATIO: float = 0.62
const TAG_HEIGHT_RATIO: float = 0.3
const TAG_TOP_RATIO: float = 0.05
const BAR_WIDTH_RATIO: float = 0.8
const BAR_HEIGHT_RATIO: float = 0.08
const BAR_BOTTOM_RATIO: float = 0.05
const FULL_TAG_HEIGHT_RATIO: float = 0.24
const LABEL_FONT_RATIO: float = 0.22
const FULL_FONT_RATIO: float = 0.18
const OUTLINE_WIDTH: float = 3.0

@export var combat_view_path: NodePath = NodePath("../CombatView")
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
var _combat: CombatView
var _hold_view: HoldSlotsView


func _ready() -> void:
	_combat = get_node(combat_view_path) as CombatView
	_hold_view = get_node(hold_slots_view_path) as HoldSlotsView


func _process(_delta: float) -> void:
	queue_redraw()


## Colour for a freshness share (1 = just landed, 0 = rotten).
static func freshness_color(ratio: float) -> Color:
	if ratio >= FRESH_RATIO:
		return COLOR_FRESH
	if ratio >= WARN_RATIO:
		return COLOR_WARN
	return COLOR_ROTTEN


func _draw() -> void:
	if _combat == null or _combat.get_drops() == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var grid: BoardGrid = _combat.get_grid()
	var cell: Vector2 = ScreenLayout.cell_size(grid, vp)
	var hand_full: bool = _hold_view != null and _hold_view.get_slots() != null and _hold_view.get_slots().is_full()
	var stand: Vector2i = _combat.get_state().player_cell
	for point: FieldPoint in _combat.get_drops().get_points():
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, point.cell)
		var ratio: float = clampf(point.freshness_left / _combat.get_drops_config().freshness_sec, 0.0, 1.0)
		var color: Color = freshness_color(ratio)
		var alpha: float = 1.0
		if point.freshness_left <= BLINK_SEC and int(point.freshness_left * BLINK_HZ * 2.0) % 2 == 0:
			alpha = BLINK_DIM_ALPHA
		color.a = alpha
		draw_rect(rect.grow(-3.0), Color(color, 0.18 * alpha))
		draw_rect(rect.grow(-3.0), color, false, OUTLINE_WIDTH)
		var tag_size := Vector2(cell.x * TAG_WIDTH_RATIO, cell.y * TAG_HEIGHT_RATIO)
		var tag := Rect2(Vector2(rect.get_center().x - tag_size.x * 0.5, rect.position.y + cell.y * TAG_TOP_RATIO), tag_size)
		draw_rect(tag, Color(TAG_BACK, alpha))
		draw_rect(tag, color, false, OUTLINE_WIDTH)
		var font_size: int = int(cell.y * LABEL_FONT_RATIO)
		draw_string(ThemeDB.fallback_font, tag.position + Vector2(0.0, tag.size.y * 0.5 + font_size * 0.35), point.label, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, font_size, Color(TEXT_COLOR, alpha))
		var bar_w: float = cell.x * BAR_WIDTH_RATIO
		var bar := Rect2(Vector2(rect.get_center().x - bar_w * 0.5, rect.end.y - cell.y * (BAR_BOTTOM_RATIO + BAR_HEIGHT_RATIO)), Vector2(bar_w, cell.y * BAR_HEIGHT_RATIO))
		draw_rect(bar, Color(TEXT_COLOR, 0.3))
		draw_rect(Rect2(bar.position, Vector2(bar_w * ratio, bar.size.y)), color)
		if hand_full and point.cell == stand:
			var full_size := Vector2(cell.x * TAG_WIDTH_RATIO, cell.y * FULL_TAG_HEIGHT_RATIO)
			var full_tag := Rect2(Vector2(rect.get_center().x - full_size.x * 0.5, rect.position.y + cell.y * TAG_TOP_RATIO - full_size.y - 2.0), full_size) # top edge, above the label tag, clear of the marker
			var full_font: int = int(cell.y * FULL_FONT_RATIO)
			draw_rect(full_tag, FULL_BACK)
			draw_rect(full_tag, TEXT_COLOR, false, OUTLINE_WIDTH)
			draw_string(ThemeDB.fallback_font, full_tag.position + Vector2(0.0, full_tag.size.y * 0.5 + full_font * 0.35), "FULL", HORIZONTAL_ALIGNMENT_CENTER, full_tag.size.x, full_font, TEXT_COLOR)

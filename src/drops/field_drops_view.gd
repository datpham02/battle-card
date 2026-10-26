class_name FieldDropsView
extends Node2D
## Draws the player half's field points above the board: a tag with the point LABEL, a
## freshness bar that shrinks, green -> yellow -> red colour, a blink for the last seconds,
## and a "FULL" tag on the point the player stands on while the hand is full (the point
## stays on the field, so the reason is visible). Placeholder art.
## Story 014: a ROTTEN point (FieldPoint.rotten, thrown by a boss trait) is drawn grey with a
## dark X across its marker, a grey tag and a grey freshness bar (no green-yellow-red ramp), so
## it never reads as something worth picking up.
## Implements: Story 007, Story 014.

const COLOR_FRESH: Color = Color(0.2, 0.75, 0.3)
const COLOR_WARN: Color = Color(0.95, 0.8, 0.1)
const COLOR_ROTTEN: Color = Color(0.9, 0.2, 0.15)
const TAG_BACK: Color = Color(1.0, 1.0, 1.0, 0.92)
const TEXT_COLOR: Color = Color(0.15, 0.12, 0.1)
const FULL_BACK: Color = Color(0.95, 0.7, 0.1)
## Rotten point (Story 014): grey marker / tag / bar and the dark X across the marker.
const ROTTEN_GREY: Color = Color(0.55, 0.55, 0.55)
const ROTTEN_TAG_BACK: Color = Color(0.8, 0.8, 0.8, 0.92)
const ROTTEN_X_COLOR: Color = Color(0.2, 0.2, 0.22, 0.9)
const ROTTEN_X_WIDTH: float = 5.0
## Inset of the X from the cell's edges (share of cell height).
const ROTTEN_X_INSET_RATIO: float = 0.16
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
## Piece mini shape (Story 024): side padding, top / bottom reserve (freshness bar) as shares of the
## cell, and the largest square as a share of cell height (so a single cell stays small).
const PIECE_PAD_RATIO: float = 0.14
const PIECE_TOP_RATIO: float = 0.14
const PIECE_BOTTOM_RATIO: float = 0.22
const PIECE_MAX_UNIT_RATIO: float = 0.3

@export var combat_view_path: NodePath = NodePath("../CombatView")
@export var hold_slots_view_path: NodePath = NodePath("../HoldSlotsView")
## True = draw the BOSS half's field points (boss.get_drops()) instead of the player's; the
## "FULL" tag is then never drawn (it belongs to the player's hand).
@export var boss_side: bool = false
var _combat: CombatView
var _hold_view: HoldSlotsView


# The FieldDrops this view draws (null before the combat view is ready).
func _source() -> FieldDrops:
	if boss_side:
		return _combat.get_boss().get_drops() if _combat.get_boss() != null else null
	return _combat.get_drops()


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
	if _combat == null or _source() == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var grid: BoardGrid = _combat.get_grid()
	var cell: Vector2 = ScreenLayout.cell_size(grid, vp)
	var hand_full: bool = not boss_side and _hold_view != null and _hold_view.get_slots() != null and _hold_view.get_slots().is_full()
	var stand: Vector2i = _combat.get_state().player_cell
	for point: FieldPoint in _source().get_points():
		var rect: Rect2 = ScreenLayout.cell_rect(grid, vp, point.cell)
		var total_sec: float = _combat.get_drops_config().piece_freshness_sec if point.piece != null else _combat.get_drops_config().freshness_sec
		var ratio: float = clampf(point.freshness_left / total_sec, 0.0, 1.0)
		var color: Color = ROTTEN_GREY if point.rotten else freshness_color(ratio)
		var alpha: float = 1.0
		if point.freshness_left <= BLINK_SEC and int(point.freshness_left * BLINK_HZ * 2.0) % 2 == 0:
			alpha = BLINK_DIM_ALPHA
		color.a = alpha
		if point.piece != null:
			_draw_piece_point(point, rect, cell, color, alpha, ratio, hand_full and point.cell == stand)
			continue
		draw_rect(rect.grow(-3.0), Color(color, 0.18 * alpha))
		draw_rect(rect.grow(-3.0), color, false, OUTLINE_WIDTH)
		if point.rotten:
			var x_rect: Rect2 = rect.grow(-cell.y * ROTTEN_X_INSET_RATIO)
			draw_line(x_rect.position, x_rect.end, Color(ROTTEN_X_COLOR, ROTTEN_X_COLOR.a * alpha), ROTTEN_X_WIDTH)
			draw_line(Vector2(x_rect.end.x, x_rect.position.y), Vector2(x_rect.position.x, x_rect.end.y), Color(ROTTEN_X_COLOR, ROTTEN_X_COLOR.a * alpha), ROTTEN_X_WIDTH)
		var tag_size := Vector2(cell.x * TAG_WIDTH_RATIO, cell.y * TAG_HEIGHT_RATIO)
		var tag := Rect2(Vector2(rect.get_center().x - tag_size.x * 0.5, rect.position.y + cell.y * TAG_TOP_RATIO), tag_size)
		draw_rect(tag, Color(ROTTEN_TAG_BACK if point.rotten else TAG_BACK, alpha))
		draw_rect(tag, color, false, OUTLINE_WIDTH)
		var font_size: int = int(cell.y * LABEL_FONT_RATIO)
		draw_string(ThemeDB.fallback_font, tag.position + Vector2(0.0, tag.size.y * 0.5 + font_size * 0.35), point.label, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, font_size, Color(TEXT_COLOR, alpha))
		var bar_w: float = cell.x * BAR_WIDTH_RATIO
		var bar := Rect2(Vector2(rect.get_center().x - bar_w * 0.5, rect.end.y - cell.y * (BAR_BOTTOM_RATIO + BAR_HEIGHT_RATIO)), Vector2(bar_w, cell.y * BAR_HEIGHT_RATIO))
		draw_rect(bar, Color(TEXT_COLOR, 0.3))
		draw_rect(Rect2(bar.position, Vector2(bar_w * ratio, bar.size.y)), ROTTEN_X_COLOR if point.rotten else color)
		if hand_full and point.cell == stand:
			var full_size := Vector2(cell.x * TAG_WIDTH_RATIO, cell.y * FULL_TAG_HEIGHT_RATIO)
			var full_tag := Rect2(Vector2(rect.get_center().x - full_size.x * 0.5, rect.position.y + cell.y * TAG_TOP_RATIO - full_size.y - 2.0), full_size) # top edge, above the label tag, clear of the marker
			var full_font: int = int(cell.y * FULL_FONT_RATIO)
			draw_rect(full_tag, FULL_BACK)
			draw_rect(full_tag, TEXT_COLOR, false, OUTLINE_WIDTH)
			draw_string(ThemeDB.fallback_font, full_tag.position + Vector2(0.0, full_tag.size.y * 0.5 + full_font * 0.35), tr("ui.hud.full"), HORIZONTAL_ALIGNMENT_CENTER, full_tag.size.x, full_font, TEXT_COLOR)


# Story 024: a piece lying on the player's half: a mini shape of the piece in its rotation (no text
# tag), a thin cell outline, the freshness bar and, when the bag is full and the player stands on it,
# the "FULL" tag. A rotten piece is grey with a dark X (never the green-yellow-red ramp).
func _draw_piece_point(point: FieldPoint, rect: Rect2, cell: Vector2, color: Color, alpha: float, ratio: float, show_full: bool) -> void:
	draw_rect(rect.grow(-3.0), Color(color, 0.12 * alpha))
	draw_rect(rect.grow(-3.0), color, false, OUTLINE_WIDTH)
	var area := Rect2(
		rect.position + Vector2(cell.x * PIECE_PAD_RATIO, cell.y * PIECE_TOP_RATIO),
		Vector2(cell.x * (1.0 - PIECE_PAD_RATIO * 2.0), cell.y * (1.0 - PIECE_TOP_RATIO - PIECE_BOTTOM_RATIO))
	)
	var unit_max: float = cell.y * PIECE_MAX_UNIT_RATIO
	if point.rotten:
		PieceDraw.draw_shape(self, point.piece, area, Color(ROTTEN_GREY, 0.8 * alpha), Color(ROTTEN_X_COLOR, 0.0), unit_max)
		var x_rect: Rect2 = PieceDraw.shape_rect(point.piece, area, unit_max).grow(-cell.y * ROTTEN_X_INSET_RATIO * 0.4)
		draw_line(x_rect.position, x_rect.end, Color(ROTTEN_X_COLOR, ROTTEN_X_COLOR.a * alpha), ROTTEN_X_WIDTH)
		draw_line(Vector2(x_rect.end.x, x_rect.position.y), Vector2(x_rect.position.x, x_rect.end.y), Color(ROTTEN_X_COLOR, ROTTEN_X_COLOR.a * alpha), ROTTEN_X_WIDTH)
	else:
		PieceDraw.draw_shape(self, point.piece, area, Color(color, 0.85 * alpha), Color(TEXT_COLOR, 0.6 * alpha), unit_max)
	var bar_w: float = cell.x * BAR_WIDTH_RATIO
	var bar := Rect2(Vector2(rect.get_center().x - bar_w * 0.5, rect.end.y - cell.y * (BAR_BOTTOM_RATIO + BAR_HEIGHT_RATIO)), Vector2(bar_w, cell.y * BAR_HEIGHT_RATIO))
	draw_rect(bar, Color(TEXT_COLOR, 0.3))
	draw_rect(Rect2(bar.position, Vector2(bar_w * ratio, bar.size.y)), ROTTEN_X_COLOR if point.rotten else color)
	if show_full:
		var full_size := Vector2(cell.x * TAG_WIDTH_RATIO, cell.y * FULL_TAG_HEIGHT_RATIO)
		var full_tag := Rect2(Vector2(rect.get_center().x - full_size.x * 0.5, rect.position.y + cell.y * TAG_TOP_RATIO), full_size)
		var full_font: int = int(cell.y * FULL_FONT_RATIO)
		draw_rect(full_tag, FULL_BACK)
		draw_rect(full_tag, TEXT_COLOR, false, OUTLINE_WIDTH)
		draw_string(ThemeDB.fallback_font, full_tag.position + Vector2(0.0, full_tag.size.y * 0.5 + full_font * 0.35), tr("ui.hud.full"), HORIZONTAL_ALIGNMENT_CENTER, full_tag.size.x, full_font, TEXT_COLOR)

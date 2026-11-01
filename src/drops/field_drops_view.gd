class_name FieldDropsView
extends Node2D
## Draws the player half's field points above the board: a tag with the point LABEL, a
## freshness bar that shrinks, green -> yellow -> red colour, a blink for the last seconds,
## and a "FULL" tag on the point the player stands on while the hand is full (the point
## stays on the field, so the reason is visible). Placeholder art.
## Story 014: a ROTTEN point (FieldPoint.rotten, thrown by a boss trait) is drawn grey with a
## dark X across its marker, a grey tag and a grey freshness bar (no green-yellow-red ramp), so
## it never reads as something worth picking up.
## Story 041: an Odd Block (Khoi La) lying on either half is drawn in the PieceDraw odd look (violet-magenta shape,
## magenta outer edge) with a sparkle mark in the cell's top-right corner; a rotten one stays grey.
## Implements: Story 007, Story 014, Story 041.

const COLOR_FRESH: Color = Color(0.2, 0.75, 0.3)
const COLOR_WARN: Color = Color(0.95, 0.8, 0.1)
const COLOR_ROTTEN: Color = Color(0.9, 0.2, 0.15)
## 2026-10-31: game skin (HudSkin) tag colours: Night Stone tags with light outlined text.
const TAG_BACK: Color = Color("1E1B24", 0.92)
const TEXT_COLOR: Color = Color("F4F6FA")
const FULL_BACK: Color = Color(0.95, 0.7, 0.1)
## Rotten point (Story 014): grey marker / tag / bar and the dark X across the marker.
const ROTTEN_GREY: Color = Color(0.55, 0.55, 0.55)
const ROTTEN_TAG_BACK: Color = Color("2B2735", 0.92)
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
## Story 041: radius of the odd sparkle mark in the cell's top-right corner (share of cell height).
const ODD_MARK_RADIUS_RATIO: float = 0.085

## Story 036 wind streak (see _draw_drift_streak): colour, line width, number of speed lines, their spread across
## the cell, where they start behind the centre and how long they run (shares of the half cell), the chevron's
## distance ahead of the centre and its arm (share of the shorter cell side).
const STREAK_COLOR: Color = Color(0.86, 0.95, 1.0, 0.95)
const STREAK_WIDTH: float = 3.0
const STREAK_LINES: int = 3
const STREAK_SPREAD_RATIO: float = 0.45
const STREAK_BACK_RATIO: float = 0.95
const STREAK_LENGTH_RATIO: float = 0.45
const STREAK_TIP_RATIO: float = 0.92
const STREAK_CHEVRON_RATIO: float = 0.12

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
		HudSkin.text(self, tag.position + Vector2(0.0, tag.size.y * 0.5 + font_size * 0.35), point.label, font_size, Color(TEXT_COLOR, alpha), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, true)
		var bar_w: float = cell.x * BAR_WIDTH_RATIO
		var bar := Rect2(Vector2(rect.get_center().x - bar_w * 0.5, rect.end.y - cell.y * (BAR_BOTTOM_RATIO + BAR_HEIGHT_RATIO)), Vector2(bar_w, cell.y * BAR_HEIGHT_RATIO))
		draw_rect(bar, HudSkin.HP_GROOVE)
		draw_rect(Rect2(bar.position, Vector2(bar_w * ratio, bar.size.y)), ROTTEN_X_COLOR if point.rotten else color)
		if hand_full and point.cell == stand:
			var full_size := Vector2(cell.x * TAG_WIDTH_RATIO, cell.y * FULL_TAG_HEIGHT_RATIO)
			var full_tag := Rect2(Vector2(rect.get_center().x - full_size.x * 0.5, rect.position.y + cell.y * TAG_TOP_RATIO - full_size.y - 2.0), full_size) # top edge, above the label tag, clear of the marker
			var full_font: int = int(cell.y * FULL_FONT_RATIO)
			HudSkin.panel(self, full_tag, [0.0, 4.0, 0.0, 4.0], HudSkin.NIGHT_STONE, HudSkin.GRID_LIGHT, 2.0)
			HudSkin.text(self, full_tag.position + Vector2(0.0, full_tag.size.y * 0.5 + full_font * 0.35), tr("ui.hud.full"), full_font, HudSkin.GRID_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, full_tag.size.x, true)


	# Story 036: a wind streak on every point the next drift will move, drawn above all points.
	for point: FieldPoint in drifting_points(_source().get_points(), grid):
		_draw_drift_streak(ScreenLayout.cell_rect(grid, vp, point.cell), _combat.get_hazards().wind_dir())


## Story 036: the points of [param points] that the next wind drift moves, by the rule of FieldDrops.drift_pieces:
## the cell one step along TileHazards.wind_dir() is a cell of this half, holds no other point (before the drift)
## and is not filled sand. Empty while no wind blows. No field point is ever dragged (pieces are placed from the
## hold bag), so no point is excluded as "dragged" (Story 036 W1 deviation).
func drifting_points(points: Array[FieldPoint], grid: BoardGrid) -> Array[FieldPoint]:
	var out: Array[FieldPoint] = []
	var hazards: TileHazards = _combat.get_hazards() if _combat != null else null
	if hazards == null or not hazards.wind_enabled() or hazards.wind_dir() == Vector2i.ZERO:
		return out
	var side: int = CombatState.Side.ENEMY if boss_side else CombatState.Side.PLAYER
	var dir: Vector2i = hazards.wind_dir()
	var occupied: Array[Vector2i] = []
	for p: FieldPoint in points:
		occupied.append(p.cell)
	for p: FieldPoint in points:
		var target: Vector2i = p.cell + dir
		var in_half: bool = grid.is_enemy_cell(target) if boss_side else grid.is_player_cell(target)
		if in_half and not occupied.has(target) and not hazards.is_sanded(side, target):
			out.append(p)
	return out


# Wind streak: STREAK_LINES short speed lines trailing on the upwind side of the cell and a chevron on the
# downwind edge, pointing along [param dir] (grid +y = screen down).
func _draw_drift_streak(rect: Rect2, dir_cell: Vector2i) -> void:
	var dir := Vector2(dir_cell)
	var normal := Vector2(-dir.y, dir.x)
	var c: Vector2 = rect.get_center()
	var half: Vector2 = rect.size * 0.5
	var reach: float = absf(dir.x) * half.x + absf(dir.y) * half.y
	var spread: float = absf(normal.x) * half.x + absf(normal.y) * half.y
	for i: int in STREAK_LINES:
		var offset: float = spread * STREAK_SPREAD_RATIO * (float(i) - float(STREAK_LINES - 1) * 0.5)
		var start: Vector2 = c - dir * reach * STREAK_BACK_RATIO + normal * offset
		draw_line(start, start + dir * reach * STREAK_LENGTH_RATIO, STREAK_COLOR, STREAK_WIDTH)
	var tip: Vector2 = c + dir * reach * STREAK_TIP_RATIO
	var arm: float = minf(rect.size.x, rect.size.y) * STREAK_CHEVRON_RATIO
	draw_polyline(PackedVector2Array([tip - dir * arm + normal * arm, tip, tip - dir * arm - normal * arm]), STREAK_COLOR, STREAK_WIDTH)


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
	elif point.piece.is_odd():
		# Story 041: an Odd Block keeps the freshness colour on its cell outline and bar; its shape is violet-magenta
		# with the odd edge, and the sparkle mark sits in the cell's top-right corner.
		PieceDraw.draw_odd_shape(self, point.piece, area, Color(PieceDraw.ODD_FILL, 0.9 * alpha), unit_max)
		var mark_r: float = cell.y * ODD_MARK_RADIUS_RATIO
		PieceDraw.draw_odd_mark(self, Vector2(rect.end.x - mark_r * 1.6, rect.position.y + mark_r * 1.6), mark_r)
	else:
		PieceDraw.draw_shape(self, point.piece, area, Color(color, 0.85 * alpha), Color(HudSkin.TEXT_OUTLINE, 0.6 * alpha), unit_max)
	var bar_w: float = cell.x * BAR_WIDTH_RATIO
	var bar := Rect2(Vector2(rect.get_center().x - bar_w * 0.5, rect.end.y - cell.y * (BAR_BOTTOM_RATIO + BAR_HEIGHT_RATIO)), Vector2(bar_w, cell.y * BAR_HEIGHT_RATIO))
	draw_rect(bar, HudSkin.HP_GROOVE)
	draw_rect(Rect2(bar.position, Vector2(bar_w * ratio, bar.size.y)), ROTTEN_X_COLOR if point.rotten else color)
	if show_full:
		var full_size := Vector2(cell.x * TAG_WIDTH_RATIO, cell.y * FULL_TAG_HEIGHT_RATIO)
		var full_tag := Rect2(Vector2(rect.get_center().x - full_size.x * 0.5, rect.position.y + cell.y * TAG_TOP_RATIO), full_size)
		var full_font: int = int(cell.y * FULL_FONT_RATIO)
		HudSkin.panel(self, full_tag, [0.0, 4.0, 0.0, 4.0], HudSkin.NIGHT_STONE, HudSkin.GRID_LIGHT, 2.0)
		HudSkin.text(self, full_tag.position + Vector2(0.0, full_tag.size.y * 0.5 + full_font * 0.35), tr("ui.hud.full"), full_font, HudSkin.GRID_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, full_tag.size.x, true)

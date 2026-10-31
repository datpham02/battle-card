class_name HoldSlotsView
extends Node2D
## Renders the hand row (bottom-right corner) and owns the [HoldSlots] logic instance.
## Each slot shows its point LABEL (A1...), tinted by the side letter. States are shown by
## shape as well as colour: empty = dim fill + "+" mark, occupied = outline + label,
## selected = thick bright outline, full = gold outlines and a "FULL" label in the tag zone above the
## Cancel button (left-aligned; the focus tag takes its right end).
## Story 044 Part C: portrait cards on the thumb arc (ScreenLayout.slot_rects); every slot sits on its own
## dark fill (Ink #1B1722 at 85 %) with a 2 px frame (art bible 7.2), there is no band behind the row.
## Story 014: a ROTTEN point's slot is grey with a dark X, a grey label, never the selection
## outline (HoldSlots refuses to select it) and a small "x.x" countdown at the slot's bottom:
## the seconds (FieldPoint.rot_in_hand_sec) until it leaves the hand on its own.
## Story 041: an Odd Block in a slot is drawn in the PieceDraw odd look with a small sparkle mark in the corner.
## Placeholder art. Implements: Story 002, Story 007, Story 014, Story 041.

const SLOT_FILL_EMPTY: Color = Color(0.106, 0.09, 0.133, 0.85)
const SLOT_FILL_OCCUPIED: Color = Color(0.106, 0.09, 0.133, 0.85)
const OUTLINE_EMPTY: Color = Color(0.45, 0.4, 0.35, 0.8)
const OUTLINE_OCCUPIED: Color = Color(0.2, 0.55, 0.9)
const OUTLINE_FULL: Color = Color(0.95, 0.7, 0.1)
const OUTLINE_SELECTED: Color = Color(1.0, 1.0, 1.0)
## Frame of an empty / occupied slot (art bible 7.2: 2 px); FULL and selected keep their thicker outlines
## (state shown by shape as well as colour).
const OUTLINE_WIDTH: float = 2.0
## Stroke of the "+" mark of an empty slot.
const PLUS_WIDTH: float = 3.0
const OUTLINE_WIDTH_STRONG: float = 6.0
const OUTLINE_WIDTH_SELECTED: float = 9.0
const LABEL_COLOR: Color = Color(1.0, 1.0, 1.0)
## Label tint by side letter (first character of the label).
const SIDE_COLORS: Dictionary = {
	"A": Color(0.85, 0.3, 0.3),
	"B": Color(0.25, 0.6, 0.9),
	"C": Color(0.3, 0.7, 0.35),
	"D": Color(0.9, 0.6, 0.15),
}
const DEFAULT_SIDE_COLOR: Color = Color(0.5, 0.5, 0.5)
const LABEL_FONT_RATIO: float = 0.3
const FULL_FONT_SIZE: int = 28
## Rotten slot (Story 014): grey fill / outline / label, dark X, countdown text.
const ROTTEN_FILL: Color = Color(0.5, 0.5, 0.5, 0.8)
const ROTTEN_OUTLINE: Color = Color(0.4, 0.4, 0.42)
const ROTTEN_LABEL_COLOR: Color = Color(0.7, 0.7, 0.7)
const ROTTEN_X_COLOR: Color = Color(0.18, 0.18, 0.2, 0.95)
const ROTTEN_X_WIDTH: float = 6.0
## X inset from the slot's edges and countdown font size / bottom gap (shares of slot width).
const ROTTEN_X_INSET_RATIO: float = 0.18
const ROTTEN_TIMER_FONT_RATIO: float = 0.17
const ROTTEN_TIMER_BOTTOM_RATIO: float = 0.06
const TEXT_ROTTEN_TIMER: String = "ui.hold.rotten_timer"
## Piece slot (Story 024): mini shape fitted in the top part of the slot (share of its height), the
## largest square (share of slot width), the cell-count font (share of slot width) and bottom gap.
const PIECE_SHAPE_HEIGHT_RATIO: float = 0.6
const PIECE_SHAPE_PAD_RATIO: float = 0.14
const PIECE_MAX_UNIT_RATIO: float = 0.28
const PIECE_COUNT_FONT_RATIO: float = 0.2
const PIECE_COUNT_BOTTOM_RATIO: float = 0.08
const PIECE_FILL: Color = Color(0.3, 0.65, 0.95)
const PIECE_SELECTED_FILL: Color = Color(1.0, 0.85, 0.25)
const TEXT_CELLS: String = "ui.hud.cells"
const TEXT_FULL: String = "ui.hud.full"
## Story 041: radius of the odd sparkle mark in a slot's top-right corner (share of slot width).
const ODD_MARK_RADIUS_RATIO: float = 0.1

## Path to the hold-slot JSON config.
@export_file("*.json") var config_path: String = HoldSlotsConfig.DEFAULT_PATH

var _config: HoldSlotsConfig
var _slots: HoldSlots
## Story 032: slot count imposed by the match (relic `hold_slots`, set by CombatView); 0 = the config's.
var _slot_count_override: int = 0


func _ready() -> void:
	_config = HoldSlotsConfig.load_from_file(config_path)
	if _config == null:
		push_warning("HoldSlotsView: using built-in default config")
		_config = HoldSlotsConfig.new()
	# Story 024: the player's bag holds puzzle pieces, piece_slot_count slots (the boss keeps slot_count).
	_slots = HoldSlots.create_piece_hand(
		_slot_count_override if _slot_count_override > 0 else _config.piece_slot_count)


## Story 032: the match's bag size (CombatView applies the relics' `hold_slots`); works before and after
## _ready (an existing bag is resized). [param count] <= 0 = keep the config's count.
func set_slot_count_override(count: int) -> void:
	_slot_count_override = maxi(count, 0)
	if _slots != null and _slot_count_override > 0:
		_slots.set_slot_count(_slot_count_override)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rects: Array[Rect2] = _slot_rects()
	var full: bool = _slots.is_full()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var point: FieldPoint = _slots.get_point(i)
		if point == null:
			draw_rect(rect, SLOT_FILL_EMPTY)
			draw_rect(rect, OUTLINE_FULL if full else OUTLINE_EMPTY, false, OUTLINE_WIDTH)
			_draw_plus(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.18, OUTLINE_EMPTY)
			continue
		if point.rotten:
			_draw_rotten_slot(rect, point)
			continue
		if point.piece != null:
			_draw_piece_slot(rect, point, full, _slots.is_selected(i))
			continue
		var tint: Color = SIDE_COLORS.get(point.label.substr(0, 1), DEFAULT_SIDE_COLOR)
		draw_rect(rect, SLOT_FILL_OCCUPIED)
		draw_rect(rect.grow(-OUTLINE_WIDTH_SELECTED), Color(tint, 0.55))
		var color: Color = OUTLINE_FULL if full else OUTLINE_OCCUPIED
		var width: float = OUTLINE_WIDTH_STRONG if full else OUTLINE_WIDTH
		if _slots.is_selected(i):
			color = OUTLINE_SELECTED
			width = OUTLINE_WIDTH_SELECTED
		draw_rect(rect, color, false, width)
		var font_size: int = int(rect.size.x * LABEL_FONT_RATIO)
		draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(0.0, rect.size.y * 0.5 + font_size * 0.35),
			point.label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, LABEL_COLOR
		)
	if full and not rects.is_empty():
		var side: Rect2 = ScreenLayout.slot_side_left_rect(get_viewport_rect().size, _slots.get_slot_count())
		draw_string(
			ThemeDB.fallback_font,
			Vector2(side.position.x, side.get_center().y + FULL_FONT_SIZE * 0.35),
			tr(TEXT_FULL), HORIZONTAL_ALIGNMENT_LEFT, side.size.x, FULL_FONT_SIZE, OUTLINE_FULL
		)


# --- Public API ---------------------------------------------------------------


## The slot logic (mutate it directly; this view redraws every frame).
func get_slots() -> HoldSlots:
	return _slots


## The loaded config (tap tuning lives here).
func get_config() -> HoldSlotsConfig:
	return _config


## Screen rectangle of slot [param index] (global pixels); empty Rect2 if out of range.
func get_slot_rect(index: int) -> Rect2:
	var rects: Array[Rect2] = _slot_rects()
	if index < 0 or index >= rects.size():
		return Rect2()
	return Rect2(rects[index].position + global_position, rects[index].size)


## Index of the slot whose rect (inflated by [param padding] px) contains [param point],
## nearest centre first; -1 if none.
func slot_index_at(point: Vector2, padding: float = 0.0) -> int:
	var best: int = -1
	var best_dist: float = INF
	var rects: Array[Rect2] = _slot_rects()
	var local_point: Vector2 = point - global_position
	for i: int in rects.size():
		var rect: Rect2 = rects[i].grow(padding)
		if rect.has_point(local_point):
			var dist: float = rect.get_center().distance_squared_to(local_point)
			if dist < best_dist:
				best_dist = dist
				best = i
	return best


## Index of the occupied slot containing [param point] (inflated by [param padding]), or -1.
func occupied_slot_at(point: Vector2, padding: float = 0.0) -> int:
	var index: int = slot_index_at(point, padding)
	if index == -1 or _slots.is_slot_free(index):
		return -1
	return index


# --- Internals ---------------------------------------------------------------


func _slot_rects() -> Array[Rect2]:
	# Local coordinates (what _draw needs); public API converts to global.
	return ScreenLayout.slot_rects(get_viewport_rect().size, _slots.get_slot_count())


# Grey slot with a dark X, grey label and the rot countdown; no selection look ever.
func _draw_rotten_slot(rect: Rect2, point: FieldPoint) -> void:
	draw_rect(rect, ROTTEN_FILL)
	draw_rect(rect, ROTTEN_OUTLINE, false, OUTLINE_WIDTH)
	var x_rect: Rect2 = rect.grow(-rect.size.x * ROTTEN_X_INSET_RATIO)
	draw_line(x_rect.position, x_rect.end, ROTTEN_X_COLOR, ROTTEN_X_WIDTH)
	draw_line(Vector2(x_rect.end.x, x_rect.position.y), Vector2(x_rect.position.x, x_rect.end.y), ROTTEN_X_COLOR, ROTTEN_X_WIDTH)
	var font_size: int = int(rect.size.x * LABEL_FONT_RATIO)
	if point.piece == null:
		draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(0.0, rect.size.y * 0.5 + font_size * 0.35),
			point.label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, ROTTEN_LABEL_COLOR
		)
	var timer_size: int = maxi(int(rect.size.x * ROTTEN_TIMER_FONT_RATIO), 8)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x, rect.end.y - rect.size.x * ROTTEN_TIMER_BOTTOM_RATIO),
		tr(TEXT_ROTTEN_TIMER) % point.rot_in_hand_sec, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, timer_size, ROTTEN_LABEL_COLOR
	)


# A bag slot holding a piece: the piece as a mini shape in its current rotation, its cell count under
# it; selected = thick white outline and a gold shape. A full bag keeps the gold outline like before.
func _draw_piece_slot(rect: Rect2, point: FieldPoint, full: bool, selected: bool) -> void:
	draw_rect(rect, SLOT_FILL_OCCUPIED)
	var color: Color = OUTLINE_FULL if full else OUTLINE_OCCUPIED
	var width: float = OUTLINE_WIDTH_STRONG if full else OUTLINE_WIDTH
	if selected:
		color = OUTLINE_SELECTED
		width = OUTLINE_WIDTH_SELECTED
	draw_rect(rect, color, false, width)
	var area := Rect2(
		rect.position + Vector2(rect.size.x * PIECE_SHAPE_PAD_RATIO, rect.size.y * PIECE_SHAPE_PAD_RATIO),
		Vector2(rect.size.x * (1.0 - PIECE_SHAPE_PAD_RATIO * 2.0), rect.size.y * PIECE_SHAPE_HEIGHT_RATIO)
	)
	if point.piece.is_odd():
		# Story 041: an Odd Block: violet-magenta shape (gold when selected) with the odd outer edge, fitted by its
		# bounding box like any piece (6-7 cells shrink), and the sparkle mark in the slot's top-right corner.
		PieceDraw.draw_odd_shape(self, point.piece, area, PIECE_SELECTED_FILL if selected else PieceDraw.ODD_FILL, rect.size.x * PIECE_MAX_UNIT_RATIO)
		var mark_r: float = rect.size.x * ODD_MARK_RADIUS_RATIO
		PieceDraw.draw_odd_mark(self, Vector2(rect.end.x - mark_r * 1.5, rect.position.y + mark_r * 1.5), mark_r)
	else:
		PieceDraw.draw_shape(self, point.piece, area, PIECE_SELECTED_FILL if selected else PIECE_FILL, Color(0.1, 0.1, 0.12, 0.7), rect.size.x * PIECE_MAX_UNIT_RATIO)
	var font_size: int = int(rect.size.x * PIECE_COUNT_FONT_RATIO)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x, rect.end.y - rect.size.x * PIECE_COUNT_BOTTOM_RATIO),
		tr(TEXT_CELLS) % point.piece.cell_count(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, LABEL_COLOR
	)


func _draw_plus(center: Vector2, arm: float, color: Color) -> void:
	draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), color, PLUS_WIDTH)
	draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), color, PLUS_WIDTH)

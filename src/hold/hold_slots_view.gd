class_name HoldSlotsView
extends Node2D
## Renders the bag (bottom-right corner) and owns the [HoldSlots] logic instance.
## Controls v3 (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md): a COMPACT BAG, one straight row of stone
## sockets (ScreenLayout.slot_rects, 64 x 64 at 720p, the same bottom edge as the bottom-left row). A socket shows
## only the piece as a mini shape (gold when selected) and its cell count small in the bottom-right corner; the
## selected socket gets a gold angular ring, a full bag an amber ring round every socket (no "FULL" text any more).
## Taps use the invisible hit rects (ScreenLayout.slot_hit_rects: larger than the sockets, never overlapping).
## Story 014: a ROTTEN point's socket is grey with a dark X, never the selection ring (HoldSlots refuses to select
## it) and a small "x.x" countdown above it: the seconds (FieldPoint.rot_in_hand_sec) until it leaves the hand.
## Story 041: an Odd Block in a socket is drawn in the PieceDraw odd look with a small sparkle mark in the corner.
## A legacy point without a piece shows its LABEL (A1...), tinted by the side letter.
## Implements: Story 002, Story 007, Story 014, Story 041, Story 046, controls v3.

const OUTLINE_FULL: Color = Color(0.95, 0.7, 0.1)
const OUTLINE_SELECTED: Color = Color("FFD447")
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
## Socket frame tints: empty socket, selected socket, rotten piece.
const EMPTY_TINT: Color = Color(0.72, 0.72, 0.78, 0.9)
const SELECTED_TINT: Color = Color(1.12, 1.06, 0.92)
const ROTTEN_TINT: Color = Color(0.55, 0.55, 0.58, 0.95)
## Width of the amber ring round each socket while the bag is full, and of the gold selection ring, px.
const FULL_RING_PX: float = 2.0
const SELECTED_RING_PX: float = 3.0
## Rotten socket (Story 014): grey label, dark X, countdown text.
const ROTTEN_LABEL_COLOR: Color = Color(0.7, 0.7, 0.7)
const ROTTEN_X_COLOR: Color = Color(0.18, 0.18, 0.2, 0.95)
const ROTTEN_X_WIDTH: float = 5.0
## X inset from the socket's inside and countdown font size (shares of socket width).
const ROTTEN_X_INSET_RATIO: float = 0.1
const ROTTEN_TIMER_FONT_RATIO: float = 0.24
const TEXT_ROTTEN_TIMER: String = "ui.hold.rotten_timer"
## Piece socket: the largest mini-shape square (share of socket width), the extra inset inside the frame's gold line
## (px), the fill colours.
const PIECE_MAX_UNIT_RATIO: float = 0.2
const INNER_EXTRA_PAD: float = 2.0
const PIECE_FILL: Color = Color(0.3, 0.65, 0.95)
const PIECE_SELECTED_FILL: Color = Color(1.0, 0.85, 0.25)
## Cell count in the bottom-right corner: font, gap to the bottom and right edges (720p px), colour.
const COUNT_FONT_PX: float = 13.0
const COUNT_BOTTOM_PX: float = 7.0
const COUNT_RIGHT_PX: float = 9.0
const COUNT_COLOR: Color = Color("F8F8D0")
## Story 041: radius of the odd sparkle mark in a socket's top-right corner (share of socket width).
const ODD_MARK_RADIUS_RATIO: float = 0.08

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
			_draw_socket(rect, EMPTY_TINT)
			if full:
				_draw_ring(rect, OUTLINE_FULL, FULL_RING_PX)
			continue
		if point.rotten:
			_draw_rotten_slot(rect, point)
			continue
		if point.piece != null:
			_draw_piece_slot(rect, point, full, _slots.is_selected(i))
			continue
		var tint: Color = SIDE_COLORS.get(point.label.substr(0, 1), DEFAULT_SIDE_COLOR)
		_draw_socket(rect, Color.WHITE)
		draw_rect(_inner(rect), Color(tint, 0.55))
		var font_size: int = int(rect.size.x * LABEL_FONT_RATIO)
		draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(0.0, rect.size.y * 0.5 + font_size * 0.35),
			point.label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, LABEL_COLOR
		)
		_draw_state_ring(rect, full, _slots.is_selected(i))


# --- Public API ---------------------------------------------------------------


## The slot logic (mutate it directly; this view redraws every frame).
func get_slots() -> HoldSlots:
	return _slots


## The loaded config (tap tuning lives here).
func get_config() -> HoldSlotsConfig:
	return _config


## Screen rectangle of slot [param index] (global pixels; the visible socket); empty Rect2 if out of range.
func get_slot_rect(index: int) -> Rect2:
	var rects: Array[Rect2] = _slot_rects()
	if index < 0 or index >= rects.size():
		return Rect2()
	return Rect2(rects[index].position + global_position, rects[index].size)


## Controls v3: screen rectangle of slot [param index]'s invisible tap area (global pixels, ScreenLayout.slot_hit_rects:
## larger than the socket, never overlapping a neighbour's); empty Rect2 if out of range.
func get_slot_hit_rect(index: int) -> Rect2:
	var rects: Array[Rect2] = _hit_rects()
	if index < 0 or index >= rects.size():
		return Rect2()
	return Rect2(rects[index].position + global_position, rects[index].size)


## Index of the slot whose tap rect (inflated by [param padding] px) contains [param point],
## nearest socket centre first; -1 if none.
func slot_index_at(point: Vector2, padding: float = 0.0) -> int:
	var best: int = -1
	var best_dist: float = INF
	var rects: Array[Rect2] = _hit_rects()
	var sockets: Array[Rect2] = _slot_rects()
	var local_point: Vector2 = point - global_position
	for i: int in rects.size():
		var rect: Rect2 = rects[i].grow(padding)
		if rect.has_point(local_point):
			var dist: float = sockets[i].get_center().distance_squared_to(local_point)
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


func _hit_rects() -> Array[Rect2]:
	return ScreenLayout.slot_hit_rects(get_viewport_rect().size, _slots.get_slot_count())


# Controls v3: the stone socket (the menus' pixel stone frame at their whole-number density) tinted by [param tint].
func _draw_socket(rect: Rect2, tint: Color) -> void:
	PixelFrame.draw(self, PixelFrame.BUTTON_FRAME, rect, PixelFrame.BUTTON_MARGIN, PixelFrame.scale_for(get_viewport_rect().size.y), tint)


# The socket's inside, where the piece shape sits (just within the frame's gold line).
func _inner(rect: Rect2) -> Rect2:
	var pad: float = PixelFrame.frame_pad(PixelFrame.scale_for(get_viewport_rect().size.y)) + INNER_EXTRA_PAD
	return rect.grow(-pad)


# Grey socket with a dark X over the grey piece (or label) and the rot countdown above it; no selection look ever.
func _draw_rotten_slot(rect: Rect2, point: FieldPoint) -> void:
	_draw_socket(rect, ROTTEN_TINT)
	if point.piece != null:
		PieceDraw.draw_shape(self, point.piece, _inner(rect), Color(ROTTEN_LABEL_COLOR, 0.8), Color(0.1, 0.1, 0.12, 0.7), rect.size.x * PIECE_MAX_UNIT_RATIO)
	else:
		var font_size: int = int(rect.size.x * LABEL_FONT_RATIO)
		draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(0.0, rect.size.y * 0.5 + font_size * 0.35),
			point.label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, ROTTEN_LABEL_COLOR
		)
	var x_rect: Rect2 = _inner(rect).grow(-rect.size.x * ROTTEN_X_INSET_RATIO)
	draw_line(x_rect.position, x_rect.end, ROTTEN_X_COLOR, ROTTEN_X_WIDTH)
	draw_line(Vector2(x_rect.end.x, x_rect.position.y), Vector2(x_rect.position.x, x_rect.end.y), ROTTEN_X_COLOR, ROTTEN_X_WIDTH)
	var timer_size: int = maxi(int(rect.size.x * ROTTEN_TIMER_FONT_RATIO), 8)
	HudSkin.text(self, Vector2(rect.position.x, rect.position.y - 4.0), tr(TEXT_ROTTEN_TIMER) % point.rot_in_hand_sec,
		timer_size, ROTTEN_LABEL_COLOR, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)


# Controls v3: a socket holding a piece: only the piece as a mini shape in its current rotation (gold when selected),
# its cell count small in the bottom-right corner; the selection ring is gold, a full bag's ring amber.
func _draw_piece_slot(rect: Rect2, point: FieldPoint, full: bool, selected: bool) -> void:
	_draw_socket(rect, SELECTED_TINT if selected else Color.WHITE)
	var area: Rect2 = _inner(rect)
	if point.piece.is_odd():
		# Story 041: an Odd Block: violet-magenta shape (gold when selected) with the odd outer edge, fitted by its
		# bounding box like any piece (6-7 cells shrink), and the sparkle mark in the socket's top-right corner.
		PieceDraw.draw_odd_shape(self, point.piece, area, PIECE_SELECTED_FILL if selected else PieceDraw.ODD_FILL, rect.size.x * PIECE_MAX_UNIT_RATIO)
		var mark_r: float = rect.size.x * ODD_MARK_RADIUS_RATIO
		PieceDraw.draw_odd_mark(self, Vector2(rect.end.x - mark_r * 1.5, rect.position.y + mark_r * 1.5), mark_r)
	else:
		PieceDraw.draw_shape(self, point.piece, area, PIECE_SELECTED_FILL if selected else PIECE_FILL, Color(0.1, 0.1, 0.12, 0.7), rect.size.x * PIECE_MAX_UNIT_RATIO)
	var s: float = ScreenLayout.controls_scale(get_viewport_rect().size)
	var count_size: int = roundi(COUNT_FONT_PX * s)
	HudSkin.text(self, Vector2(rect.position.x, rect.end.y - roundf(COUNT_BOTTOM_PX * s)), str(point.piece.cell_count()), count_size,
		COUNT_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - roundf(COUNT_RIGHT_PX * s), true)
	_draw_state_ring(rect, full, selected)


# The selection ring (gold) or, for a full bag, the amber ring; nothing otherwise.
func _draw_state_ring(rect: Rect2, full: bool, selected: bool) -> void:
	if selected:
		_draw_ring(rect, OUTLINE_SELECTED, SELECTED_RING_PX)
	elif full:
		_draw_ring(rect, OUTLINE_FULL, FULL_RING_PX)


# An angular (chamfered) ring of [param width] px just outside [param rect].
func _draw_ring(rect: Rect2, color: Color, width: float) -> void:
	var r := Rect2(rect.position.round(), rect.size.round()).grow(width * 0.5 + 1.0)
	var pts: PackedVector2Array = StatusRow.frame_points(r)
	pts.append(pts[0])
	draw_polyline(pts, color, width)

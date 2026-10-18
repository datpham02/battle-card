class_name HoldSlotsView
extends Node2D
## Renders the hand row (bottom-right corner) and owns the [HoldSlots] logic instance.
## Each slot shows its point LABEL (A1...), tinted by the side letter. States are shown by
## shape as well as colour: empty = dim fill + "+" mark, occupied = outline + label,
## selected = thick bright outline, full = gold outlines and a "FULL" label left of the row.
## Placeholder art. Implements: Story 002, Story 007.

const SLOT_FILL_EMPTY: Color = Color(0.2, 0.17, 0.15, 0.35)
const SLOT_FILL_OCCUPIED: Color = Color(0.2, 0.17, 0.15, 0.7)
const OUTLINE_EMPTY: Color = Color(0.45, 0.4, 0.35, 0.8)
const OUTLINE_OCCUPIED: Color = Color(0.2, 0.55, 0.9)
const OUTLINE_FULL: Color = Color(0.95, 0.7, 0.1)
const OUTLINE_SELECTED: Color = Color(1.0, 1.0, 1.0)
const OUTLINE_WIDTH: float = 3.0
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

## Path to the hold-slot JSON config.
@export_file("*.json") var config_path: String = HoldSlotsConfig.DEFAULT_PATH

var _config: HoldSlotsConfig
var _slots: HoldSlots


func _ready() -> void:
	_config = HoldSlotsConfig.load_from_file(config_path)
	if _config == null:
		push_warning("HoldSlotsView: using built-in default config")
		_config = HoldSlotsConfig.new()
	_slots = HoldSlots.new(_config.slot_count)


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
			"FULL", HORIZONTAL_ALIGNMENT_RIGHT, side.size.x, FULL_FONT_SIZE, OUTLINE_FULL
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


func _draw_plus(center: Vector2, arm: float, color: Color) -> void:
	draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), color, OUTLINE_WIDTH)
	draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), color, OUTLINE_WIDTH)

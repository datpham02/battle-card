class_name HoldSlotsView
extends Node2D
## Renders the hold-slot row (landscape layout, middle of the screen) and owns the
## [HoldSlots] logic instance. States are shown by shape as well as colour:
## empty = dim fill + "+" mark, occupied = bright outline + the card,
## full = every outline thick gold plus a bar under the row.
## The drag controller drives it through [method slot_index_at], [method put_card]
## and [method set_drop_highlight]; it never decides game rules itself.

const SLOT_FILL_EMPTY: Color = Color(0.2, 0.17, 0.15, 0.35)
const SLOT_FILL_OCCUPIED: Color = Color(0.2, 0.17, 0.15, 0.7)
const OUTLINE_EMPTY: Color = Color(0.45, 0.4, 0.35, 0.8)
const OUTLINE_OCCUPIED: Color = Color(0.2, 0.55, 0.9)
const OUTLINE_FULL: Color = Color(0.95, 0.7, 0.1)
const OUTLINE_DROP: Color = Color(0.2, 0.8, 0.4)
const OUTLINE_WIDTH: float = 3.0
const OUTLINE_WIDTH_STRONG: float = 6.0
const LOCKED_TINT: Color = Color(0.45, 0.45, 0.5, 1.0)
const RECOVERY_BAR_COLOR: Color = Color(0.9, 0.35, 0.25)
const RECOVERY_BAR_HEIGHT: float = 14.0
const RECOVERY_FONT_SIZE: int = 22
## Gap between the "RECOVERING" label baseline and the bar top.
const RECOVERY_LABEL_GAP: float = 6.0
const FULL_FONT_SIZE: int = 22

## Path to the hold-slot JSON config.
@export_file("*.json") var config_path: String = HoldSlotsConfig.DEFAULT_PATH

var _config: HoldSlotsConfig
var _slots: HoldSlots
var _slot_nodes: Dictionary = {} # slot index -> Control
var _highlight_index: int = -1
var _recovery_ratio: float = 0.0
var _recovery_left: float = 0.0


func _ready() -> void:
	_config = HoldSlotsConfig.load_from_file(config_path)
	if _config == null:
		push_warning("HoldSlotsView: using built-in default config")
		_config = HoldSlotsConfig.new()
	_slots = HoldSlots.new(_config.slot_count)
	_slots.slot_filled.connect(_on_slots_changed)
	_slots.slot_cleared.connect(_on_slots_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _draw() -> void:
	var rects: Array[Rect2] = _slot_rects()
	var full: bool = _slots.is_full()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var occupied: bool = not _slots.is_slot_free(i)
		draw_rect(rect, SLOT_FILL_OCCUPIED if occupied else SLOT_FILL_EMPTY)
		var color: Color = OUTLINE_OCCUPIED if occupied else OUTLINE_EMPTY
		var width: float = OUTLINE_WIDTH
		if full:
			color = OUTLINE_FULL
			width = OUTLINE_WIDTH_STRONG
		if i == _highlight_index:
			color = OUTLINE_DROP
			width = OUTLINE_WIDTH_STRONG
		draw_rect(rect, color, false, width)
		if not occupied:
			_draw_plus(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.18, color)
	if rects.is_empty():
		return
	var vp: Vector2 = get_viewport_rect().size
	var count: int = _slots.get_slot_count()
	# "FULL" label in the free area left of the row, vertically centred on the slots.
	if full:
		var side: Rect2 = ScreenLayout.slot_side_left_rect(vp, count)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(side.position.x, side.get_center().y + FULL_FONT_SIZE * 0.35),
			"FULL", HORIZONTAL_ALIGNMENT_CENTER, side.size.x, FULL_FONT_SIZE, OUTLINE_FULL
		)
	# Recovery bar + label in the free area right of the row, vertically centred on the slots.
	if _recovery_ratio > 0.0:
		var side: Rect2 = ScreenLayout.slot_side_right_rect(vp, count)
		var rwidth: float = minf(vp.x * ScreenLayout.RECOVERY_BAR_WIDTH_RATIO, side.size.x)
		var top: float = side.get_center().y - RECOVERY_BAR_HEIGHT * 0.5
		var bar := Rect2(side.position.x, top, rwidth, RECOVERY_BAR_HEIGHT)
		draw_rect(bar, SLOT_FILL_OCCUPIED)
		draw_rect(Rect2(bar.position, Vector2(rwidth * _recovery_ratio, RECOVERY_BAR_HEIGHT)), RECOVERY_BAR_COLOR)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(bar.position.x, top - RECOVERY_LABEL_GAP),
			"RECOVERING %.1fs" % _recovery_left,
			HORIZONTAL_ALIGNMENT_CENTER, rwidth, RECOVERY_FONT_SIZE, RECOVERY_BAR_COLOR
		)


# --- Public API ---------------------------------------------------------------


## The slot logic (read it; mutate through [method put_card] so the view stays in sync).
func get_slots() -> HoldSlots:
	return _slots


## The loaded config (drag/drop tuning lives here).
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


## Puts [param card] with its [param node] into slot [param slot_index] (-1 = first free).
## On success the node becomes a child of this view, fitted into the slot, and the slot
## index is returned. On failure returns -1 and does not touch [param node].
func put_card(card: ConveyorCard, node: Control, slot_index: int = -1) -> int:
	if node == null or not _slots.can_place(slot_index):
		return -1
	var index: int = _slots.place(card, slot_index)
	if index == -1:
		return -1
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.z_index = 0
	node.modulate = LOCKED_TINT if _recovery_ratio > 0.0 else Color.WHITE
	add_child(node)
	_slot_nodes[index] = node
	_layout_slot_nodes()
	return index


## Highlights slot [param index] as the current drop target; -1 clears it.
func set_drop_highlight(index: int) -> void:
	if index != _highlight_index:
		_highlight_index = index
		queue_redraw()


## Index of the occupied slot whose rect (inflated by [param padding]) contains
## [param point], or -1.
func occupied_slot_at(point: Vector2, padding: float = 0.0) -> int:
	var index: int = slot_index_at(point, padding)
	if index == -1 or _slots.is_slot_free(index):
		return -1
	return index


## Control node of the card in slot [param index], or null.
func get_slot_node(index: int) -> Control:
	return _slot_nodes.get(index, null) as Control


## Empties slot [param index], frees its card node and returns the removed card
## (null if the slot was empty).
func remove_card(index: int) -> ConveyorCard:
	var card: ConveyorCard = _slots.remove(index)
	var node: Control = _slot_nodes.get(index, null) as Control
	_slot_nodes.erase(index)
	if node != null:
		node.queue_free()
	return card


## Snaps every slotted card node back into its slot (e.g. after a cancelled drag).
func relayout() -> void:
	_layout_slot_nodes()


## Sets the play-lock look: slots dimmed and a bar under the row showing the share of
## recovery left ([param ratio] 0..1; 0 = unlocked, normal look) with [param seconds_left].
func set_recovery(ratio: float, seconds_left: float) -> void:
	if is_equal_approx(ratio, _recovery_ratio) and is_equal_approx(seconds_left, _recovery_left):
		return
	_recovery_ratio = ratio
	_recovery_left = seconds_left
	var tint: Color = LOCKED_TINT if ratio > 0.0 else Color.WHITE
	for index: int in _slot_nodes:
		(_slot_nodes[index] as Control).modulate = tint
	queue_redraw()


# --- Internals ---------------------------------------------------------------


func _slot_rects() -> Array[Rect2]:
	# Local coordinates (what _draw needs); public API converts to global.
	return ScreenLayout.slot_rects(get_viewport_rect().size, _slots.get_slot_count())


func _draw_plus(center: Vector2, arm: float, color: Color) -> void:
	draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), color, OUTLINE_WIDTH)
	draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), color, OUTLINE_WIDTH)


func _layout_slot_nodes() -> void:
	var card_size: Vector2 = ScreenLayout.card_size(get_viewport_rect().size)
	for index: int in _slot_nodes:
		var node: Control = _slot_nodes[index]
		var rect: Rect2 = get_slot_rect(index)
		node.size = card_size
		node.global_position = rect.get_center() - card_size * 0.5


func _on_slots_changed(_index: int, _card: ConveyorCard) -> void:
	queue_redraw()


func _on_viewport_resized() -> void:
	queue_redraw()
	_layout_slot_nodes()

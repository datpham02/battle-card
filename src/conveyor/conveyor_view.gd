class_name ConveyorView
extends Node2D
## Thin renderer for a ConveyorBelt: placeholder card nodes (ColorRect + Label)
## moved along a horizontal belt strip at the bottom of the landscape screen.
## Also the drag facade: lets the drag controller pick, hold, return and take cards
## without touching the belt directly. All public positions are global (canvas) pixels.

const BELT_COLOR: Color = Color(0.25, 0.22, 0.2)
## z_index of a card node while it is being dragged (above slots and belt).
const DRAG_Z_INDEX: int = 100

## Emitted when a card leaves the belt via [method take_card]; the receiver now owns
## [param node] (it is detached from this view and not freed).
signal card_node_released(card: ConveyorCard, node: Control)

## Path to the conveyor JSON config.
@export_file("*.json") var config_path: String = ConveyorConfig.DEFAULT_PATH
## RNG seed; negative means random.
@export var rng_seed: int = -1

var _config: ConveyorConfig
var _belt: ConveyorBelt
var _nodes: Dictionary = {} # uid -> Control
var _dragged: Dictionary = {} # uid -> true; these nodes are positioned by the drag code
var _card_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_config = ConveyorConfig.load_from_file(config_path)
	if _config == null:
		set_process(false)
		return
	_belt = ConveyorBelt.new(_config, rng_seed)
	_belt.card_spawned.connect(_on_card_spawned)
	_belt.card_expired.connect(_on_card_expired)
	_belt.card_taken.connect(_on_card_taken)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_update_metrics()
	_belt.prewarm(_config.prewarm_sec)
	_sync_positions()


func _process(delta: float) -> void:
	_belt.tick(delta)
	_sync_positions()


func _draw() -> void:
	draw_rect(ScreenLayout.belt_rect(get_viewport_rect().size), BELT_COLOR)


# --- Public API (drag support) ---------------------------------------------


## Size of one card in pixels.
func get_card_size() -> Vector2:
	return _card_size


## uids of cards currently on the belt, oldest (far end) first.
func get_card_uids() -> Array[int]:
	var uids: Array[int] = []
	if _belt != null:
		for card: ConveyorCard in _belt.get_cards():
			uids.append(card.uid)
	return uids


## Logic-side card for [param uid], or null if it is not on the belt (read-only).
func get_card(uid: int) -> ConveyorCard:
	return _belt.find_card(uid) if _belt != null else null


## Placeholder node for the card with [param uid], or null if not on the belt.
func get_card_node(uid: int) -> Control:
	return _nodes.get(uid) as Control


## Card type ids from the data table (used by the dev demo hook).
func get_card_type_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if _config != null:
		for entry: Dictionary in _config.cards:
			ids.append(str(entry.get("id", "")))
	return ids


## Builds a detached placeholder node for [param card] (not added to the tree).
func make_card_node(card: ConveyorCard) -> Control:
	var entry: Dictionary = _find_entry(card.type_id)
	var rect := ColorRect.new()
	rect.size = _card_size
	rect.color = Color.from_string(str(entry.get("color", "ffffff")), Color.WHITE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = str(entry.get("name", card.type_id))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(label)
	return rect


## Top-left screen position of a card sitting at [param belt_position] (belt units).
func belt_to_screen(belt_position: float) -> Vector2:
	var rect: Rect2 = ScreenLayout.belt_rect(get_viewport_rect().size)
	var span: float = _belt_span(rect)
	var t: float = belt_position / _config.belt_length
	return global_position + Vector2(
		rect.position.x + _belt_inset(rect) + span * t,
		rect.position.y + (rect.size.y - _card_size.y) * 0.5
	)


## Inverse of [method belt_to_screen] along the belt axis: belt position for a card
## whose top-left x is [param screen_x]. Not clamped (may be outside 0..belt_length).
func screen_to_belt(screen_x: float) -> float:
	var rect: Rect2 = ScreenLayout.belt_rect(get_viewport_rect().size)
	var span: float = _belt_span(rect)
	if span <= 0.0:
		return 0.0
	var t: float = (screen_x - global_position.x - rect.position.x - _belt_inset(rect)) / span
	return t * _config.belt_length


## uid of the belt card under [param point] (inflated by [param padding] px), or -1.
## If several qualify, the one whose centre is nearest wins. Held cards are ignored.
func pick_card_at(point: Vector2, padding: float = 0.0) -> int:
	var best_uid: int = -1
	var best_dist: float = INF
	for uid: int in _nodes:
		if _dragged.has(uid):
			continue
		var node: Control = _nodes[uid]
		var rect := Rect2(node.global_position, node.size).grow(padding)
		if rect.has_point(point):
			var dist: float = rect.get_center().distance_squared_to(point)
			if dist < best_dist:
				best_dist = dist
				best_uid = uid
	return best_uid


## Starts a drag of the card [param uid]: the belt keeps moving it logically, the view
## stops positioning its node (the drag code does) and draws it on top.
## Returns the card node, or null if the card is not on the belt.
func begin_card_drag(uid: int) -> Control:
	var node: Control = _nodes.get(uid) as Control
	if node == null or not _belt.set_card_held(uid, true):
		return null
	_dragged[uid] = true
	node.z_index = DRAG_Z_INDEX
	return node


## Ends a drag without taking the card: it resumes flowing from its TRUE current belt
## position. If that is the far end it expires on the next tick (see ConveyorBelt.set_card_held).
func end_card_drag(uid: int) -> void:
	_dragged.erase(uid)
	_belt.set_card_held(uid, false)
	var node: Control = _nodes.get(uid) as Control
	if node != null:
		node.z_index = 0
		_sync_positions()


## True if the card's true belt position is at the far end (it can no longer be put back safely).
func is_card_at_far_end(uid: int) -> bool:
	var card: ConveyorCard = _belt.find_card(uid)
	return card != null and card.position >= _config.belt_length


## Removes the card from the belt for good (e.g. dropped into a slot) and returns its
## node, detached from this view; the caller owns it. Null if the card is not on the belt.
func take_card(uid: int) -> Control:
	var node: Control = _nodes.get(uid) as Control
	if _belt.take_card(uid) == null:
		return null
	return node


# --- Internals ---------------------------------------------------------------


func _on_viewport_resized() -> void:
	_update_metrics()
	queue_redraw()
	_sync_positions()


func _update_metrics() -> void:
	_card_size = ScreenLayout.card_size(get_viewport_rect().size)
	for node: Control in _nodes.values():
		node.size = _card_size


func _belt_inset(rect: Rect2) -> float:
	return rect.size.x * ScreenLayout.MARGIN_RATIO


func _belt_span(rect: Rect2) -> float:
	return rect.size.x - _belt_inset(rect) * 2.0 - _card_size.x


func _on_card_spawned(card: ConveyorCard) -> void:
	var node: Control = make_card_node(card)
	add_child(node)
	_nodes[card.uid] = node


func _on_card_expired(card: ConveyorCard) -> void:
	var node: Control = _nodes.get(card.uid) as Control
	_nodes.erase(card.uid)
	_dragged.erase(card.uid)
	if node != null:
		node.queue_free()


func _on_card_taken(card: ConveyorCard) -> void:
	var node: Control = _nodes.get(card.uid) as Control
	_nodes.erase(card.uid)
	_dragged.erase(card.uid)
	if node == null:
		return
	if node.get_parent() == self:
		remove_child(node)
	card_node_released.emit(card, node)


func _find_entry(type_id: String) -> Dictionary:
	for entry: Dictionary in _config.cards:
		if str(entry.get("id", "")) == type_id:
			return entry
	return {}


func _sync_positions() -> void:
	for card: ConveyorCard in _belt.get_cards():
		if _dragged.has(card.uid):
			continue
		var node: Control = _nodes.get(card.uid) as Control
		if node == null:
			continue
		node.global_position = belt_to_screen(card.position)

class_name FieldDrops
extends RefCounted
## Cut-point drops for one side: shuffle bag, spawn pacing, hunger compensation,
## freshness and pickup. One instance per side. No scene dependency.
## Story 014: [method place_rotten] lets a boss trait drop a ROTTEN point on this half; it lies,
## rots and is picked up like any point (and counts toward max_on_field) but is flagged.
## Implements: Story 007, Story 014.

## A point landed on the field.
signal point_spawned(point: FieldPoint)
## A point rotted away.
signal point_expired(point: FieldPoint)
## A point was picked up (removed from the field).
signal point_picked(point: FieldPoint)
## A pickup was refused because the hand is full; the point stays on its cell.
signal pickup_blocked(point: FieldPoint)

const NO_CELL: Vector2i = BoardGrid.NO_CELL

var _config: FieldDropsConfig
var _side_cells: Array[Vector2i] = []
var _labels: Array[String] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bag: Array[String] = []
var _points: Array[FieldPoint] = []
var _danger_cells: Array[Vector2i] = []
var _blocked_cells: Array[Vector2i] = []
var _next_uid: int = 1
var _spawn_timer: float = 0.0
var _empty_hand_time: float = 0.0


## [param side_cells] is this side's half of the board (BoardGrid.player_cells()),
## [param labels] the shuffle-bag contents (BoardGrid.perimeter_labels()). A negative
## [param seed_value] gives a random seed; otherwise the bag order and cell choice are
## deterministic.
func _init(
	config: FieldDropsConfig, side_cells: Array[Vector2i], labels: Array[String], seed_value: int = -1
) -> void:
	_config = config
	_side_cells = side_cells.duplicate()
	_labels = labels.duplicate()
	if _labels.is_empty():
		push_warning("FieldDrops: no labels given, points will have empty labels")
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_spawn_timer = config.initial_delay_sec


## Advances time. [param stand_cell] is the owner's cell, [param hand_count] the points
## held. At most one spawn happens per call; a blocked spawn waits (no catch-up burst).
func tick(delta: float, stand_cell: Vector2i, hand_count: int) -> void:
	for i: int in range(_points.size() - 1, -1, -1):
		var p: FieldPoint = _points[i]
		p.freshness_left -= delta
		if p.freshness_left <= 0.0:
			_points.remove_at(i)
			point_expired.emit(p)
	if hand_count <= 0:
		_empty_hand_time += delta
	else:
		_empty_hand_time = 0.0
	_spawn_timer = maxf(_spawn_timer - delta, 0.0)
	if _spawn_timer > 0.0 or _points.size() >= _config.max_on_field:
		return
	var cell: Vector2i = _pick_free_cell(stand_cell)
	if cell == NO_CELL:
		return
	_add_point(_draw_label(), cell, _config.freshness_sec)
	_spawn_timer = _current_interval()


## Points currently on the field (shallow copy).
func get_points() -> Array[FieldPoint]:
	return _points.duplicate()


## Picks up the point on [param cell]. Returns it (and removes it) when there is one and
## [param hand_has_room]; emits pickup_blocked and returns null when the hand is full;
## returns null when the cell has no point.
func pick_up_at(cell: Vector2i, hand_has_room: bool) -> FieldPoint:
	if _blocked_cells.has(cell):
		return null
	for i: int in _points.size():
		var p: FieldPoint = _points[i]
		if p.cell != cell:
			continue
		if not hand_has_room:
			pickup_blocked.emit(p)
			return null
		_points.remove_at(i)
		_empty_hand_time = 0.0
		point_picked.emit(p)
		return p
	return null


## Sets the cells that refuse points (burning cells): nothing spawns there and
## pick_up_at returns null for them (no pickup_blocked). Points already lying on a blocked
## cell keep rotting normally. Pass an empty array to unblock everything.
func set_blocked_cells(cells: Array[Vector2i]) -> void:
	_blocked_cells = cells.duplicate()


## Sets the opponent's swing cells. Only used when allow_drop_in_danger is false.
func set_danger_cells(cells: Array[Vector2i]) -> void:
	_danger_cells = cells.duplicate()


## DEV-ONLY capture hook: puts a point on the field, bypassing the bag, timer and caps.
func debug_place(label: String, cell: Vector2i, freshness_left: float) -> FieldPoint:
	return _add_point(label, cell, freshness_left)


## Story 014 trait API: puts a ROTTEN point labelled [param label] on [param cell] of this
## half, bypassing the bag and the spawn timer (NOT the cell rules: the cell must be a real cell
## of this half, free of points and not blocked/burning, else null and nothing changes). It rots
## off the field after [param freshness_left] seconds; once held it leaves the hand after
## [param rot_in_hand_sec]. Emits point_spawned like any landing point.
func place_rotten(cell: Vector2i, label: String, freshness_left: float, rot_in_hand_sec: float) -> FieldPoint:
	if not _side_cells.has(cell) or _is_occupied(cell) or _blocked_cells.has(cell):
		return null
	return _add_point(label, cell, freshness_left, true, maxf(rot_in_hand_sec, 0.0))


## True when a real cell of this half has no point on it (missing cells are never free).
func is_cell_free(cell: Vector2i) -> bool:
	return _side_cells.has(cell) and not _is_occupied(cell)


func _add_point(label: String, cell: Vector2i, freshness: float, rotten: bool = false, rot_in_hand_sec: float = 0.0) -> FieldPoint:
	var p := FieldPoint.new()
	p.uid = _next_uid
	_next_uid += 1
	p.label = label
	p.cell = cell
	p.freshness_left = freshness
	p.rotten = rotten
	p.rot_in_hand_sec = rot_in_hand_sec
	_points.append(p)
	point_spawned.emit(p)
	return p


func _current_interval() -> float:
	var interval: float = _config.spawn_interval_sec
	if _empty_hand_time > _config.hungry_after_sec:
		interval *= _config.hungry_interval_mult
	return interval


func _draw_label() -> String:
	if _labels.is_empty():
		return ""
	if _bag.is_empty():
		_bag.assign(_labels)
		for i: int in range(_bag.size() - 1, 0, -1):
			var j: int = _rng.randi_range(0, i)
			var tmp: String = _bag[i]
			_bag[i] = _bag[j]
			_bag[j] = tmp
	return _bag.pop_back()


func _pick_free_cell(stand_cell: Vector2i) -> Vector2i:
	var free: Array[Vector2i] = []
	for cell: Vector2i in _side_cells:
		if cell == stand_cell or _is_occupied(cell):
			continue
		if _blocked_cells.has(cell):
			continue
		if not _config.allow_drop_in_danger and _danger_cells.has(cell):
			continue
		free.append(cell)
	if free.is_empty():
		return NO_CELL
	return free[_rng.randi_range(0, free.size() - 1)]


func _is_occupied(cell: Vector2i) -> bool:
	for p: FieldPoint in _points:
		if p.cell == cell:
			return true
	return false

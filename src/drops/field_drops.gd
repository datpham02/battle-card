class_name FieldDrops
extends RefCounted
## Puzzle-piece drops for one side: weighted piece draw, spawn pacing, hunger compensation,
## freshness and pickup. One instance per side. No scene dependency.
## Story 014: [method place_rotten] lets a boss trait drop a ROTTEN point on this half; it lies,
## rots and is picked up like any point (and counts toward max_on_field) but is flagged.
## Story 024: each spawn draws a puzzle [Piece] by chapter weight from the library given to
## [method enable_pieces] (nothing drops before that call); the piece_* keys of the config drive the
## pacing. Story 026 removed the perimeter-label shuffle bag (pieces are the only mode).
## Implements: Story 007, Story 014, Story 024, Story 026.

## A point landed on the field.
signal point_spawned(point: FieldPoint)
## A point rotted away.
signal point_expired(point: FieldPoint)
## A point was picked up (removed from the field).
signal point_picked(point: FieldPoint)
## A pickup was refused because the hand is full; the point stays on its cell.
signal pickup_blocked(point: FieldPoint)
## Story 036: the wind drifted a point one cell ([param old_cell] is where it lay; point.cell is the new one).
signal point_moved(point: FieldPoint, old_cell: Vector2i)

const NO_CELL: Vector2i = BoardGrid.NO_CELL

var _config: FieldDropsConfig
var _side_cells: Array[Vector2i] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _points: Array[FieldPoint] = []
var _danger_cells: Array[Vector2i] = []
var _blocked_cells: Array[Vector2i] = []
var _next_uid: int = 1
var _spawn_timer: float = 0.0
var _empty_hand_time: float = 0.0
## Story 023: multiplies the spawn interval (frost_aura: > 1 = runes fall slower). > 0.
var interval_scale: float = 1.0
# Story 024 pieces (set by enable_pieces).
var _piece_library: PieceLibrary
var _chapter_id: String = ""
var _piece_shapes: Array[String] = [] # shapes with at least one placement on the placement grid
var _piece_rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Story 034: injected weight source (Dictionary {id: float} or Callable(id) -> float); null = library weights.
var _weight_source: Variant = null
## Story 036: Callable() -> Vector2i, the wind direction ("piece lands off by one"): a NEW drop lands one cell
## along it when that cell is free. Invalid (default) or (0,0) = drops land where picked.
var wind_offset_fn: Callable = Callable()


## [param side_cells] is this side's half of the board (BoardGrid.player_cells()). A negative
## [param seed_value] gives a random seed; otherwise the cell choice is deterministic (the piece
## draw has its own seed, see [method enable_pieces]).
func _init(config: FieldDropsConfig, side_cells: Array[Vector2i], seed_value: int = -1) -> void:
	_config = config
	_side_cells = side_cells.duplicate()
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
	if _spawn_timer > 0.0 or _points.size() >= _max_on_field():
		return
	var cell: Vector2i = _pick_free_cell(stand_cell)
	if cell == NO_CELL:
		return
	var piece: Piece = _draw_piece()
	if piece == null:
		return
	cell = _wind_offset_cell(cell, stand_cell)
	_add_point(piece.shape_id, cell, _config.piece_freshness_sec, false, 0.0, piece)
	_spawn_timer = _current_interval()


## Story 036: buries (removes, emitting point_expired) every point lying on one of [param cells] (sand filled
## on them). Returns how many were buried.
func bury_cells(cells: Array[Vector2i]) -> int:
	var buried: int = 0
	for i: int in range(_points.size() - 1, -1, -1):
		var p: FieldPoint = _points[i]
		if cells.has(p.cell):
			_points.remove_at(i)
			point_expired.emit(p)
			buried += 1
	return buried


## Story 036: the wind moves every point one cell along [param dir]. A point stays where it is when the target is
## not a real cell of this half (missing / outside), is blocked by [param blocked_fn] (Callable(cell) -> bool, sand),
## holds another point (checked against the field BEFORE this drift, so the result does not depend on the order),
## or when its own cell is in [param dragged_cells]. Emits point_moved per move; returns the number moved.
func drift_pieces(dir: Vector2i, blocked_fn: Callable = Callable(), dragged_cells: Array[Vector2i] = []) -> int:
	if dir == Vector2i.ZERO:
		return 0
	var occupied: Array[Vector2i] = []
	for p: FieldPoint in _points:
		occupied.append(p.cell)
	var moves: Array = []
	for p: FieldPoint in _points:
		if dragged_cells.has(p.cell):
			continue
		var target: Vector2i = p.cell + dir
		if not _side_cells.has(target) or occupied.has(target):
			continue
		if blocked_fn.is_valid() and bool(blocked_fn.call(target)):
			continue
		moves.append([p, target])
	for move: Array in moves:
		var p: FieldPoint = move[0]
		var old_cell: Vector2i = p.cell
		p.cell = move[1]
		point_moved.emit(p, old_cell)
	return moves.size()


## Story 024: gives this half its pieces (required: nothing drops before it). Shapes of [param library] for which no rotation
## has a placement on the ENEMY half of [param placement_grid] (the PLAYER half when
## [param target_is_enemy] is false, as for the boss, Story 025) are never drawn; the rest are drawn
## by [method PieceLibrary.weight] for [param chapter_id], with a random rotation. [param rng_seed]
## < 0 gives a random seed, otherwise draws are deterministic. Pacing then reads the config's
## piece_spawn_interval_sec / piece_max_on_field / piece_freshness_sec; hunger compensation,
## blocked cells and pickup are unchanged. Call before the first tick.
## Story 034: [param weight_source] is an optional injected weight (a Dictionary {shape id: float},
## absent id = 0, or a Callable (id: String) -> float); null keeps [method PieceLibrary.weight] for
## [param chapter_id] (the boss path and every older call; run_only shapes are then not drawable at
## all). With a source, fitting shapes of
## weight 0 are not drawable unless EVERY fitting shape has weight 0 (then all of them are, uniformly).
func enable_pieces(
	library: PieceLibrary, chapter_id: String, placement_grid: BoardGrid, rng_seed: int,
	target_is_enemy: bool = true, weight_source: Variant = null
) -> void:
	_piece_library = library
	_chapter_id = chapter_id
	_weight_source = (weight_source as Dictionary).duplicate() if weight_source is Dictionary else weight_source
	if _weight_source != null and not (_weight_source is Dictionary or _weight_source is Callable):
		push_warning("FieldDrops: weight_source must be a Dictionary or a Callable, ignored")
		_weight_source = null
	_piece_shapes.clear()
	if library != null and placement_grid != null:
		for id: String in library.shape_ids():
			# Story 034: without an injected source (boss, runless match) a run_only shape never drops.
			if _weight_source == null and library.is_run_only(id):
				continue
			if PiecePlacement.has_any_placement(placement_grid, library.make_piece(id), target_is_enemy):
				_piece_shapes.append(id)
	if _weight_source != null:
		var weighted: Array[String] = []
		for id: String in _piece_shapes:
			if _weight_of(id) > 0.0:
				weighted.append(id)
		if not weighted.is_empty():
			_piece_shapes = weighted
	if _piece_shapes.is_empty():
		push_warning("FieldDrops: no piece shape fits the target half, no pieces will drop")
	if rng_seed >= 0:
		_piece_rng.seed = rng_seed
	else:
		_piece_rng.randomize()


## Shapes that can currently be drawn (empty before enable_pieces).
func get_drawable_shapes() -> Array[String]:
	return _piece_shapes.duplicate()


## Story 024: puts config.start_pieces pieces on free cells (seeded, never [param stand_cell],
## never a blocked cell, capped by piece_max_on_field) so a match opens with pieces to grab, and
## restarts the spawn timer at one interval so the next drop does not follow at once. Returns
## the number placed (0 before enable_pieces).
func place_start_pieces(stand_cell: Vector2i) -> int:
	var placed: int = 0
	while placed < _config.start_pieces and _points.size() < _max_on_field():
		var cell: Vector2i = _pick_free_cell(stand_cell)
		if cell == NO_CELL:
			break
		var piece: Piece = _draw_piece()
		if piece == null:
			break
		_add_point(piece.shape_id, cell, _config.piece_freshness_sec, false, 0.0, piece)
		placed += 1
	if placed > 0:
		_spawn_timer = _current_interval()
	return placed


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


## DEV-ONLY capture/test hook: puts a piece-less point on the field, bypassing the draw, timer and
## caps (tests use it to track freshness and pickup timing).
func debug_place(label: String, cell: Vector2i, freshness_left: float) -> FieldPoint:
	return _add_point(label, cell, freshness_left)


## Story 014 / 024 trait API: puts a point carrying a ROTTEN piece (1 cell, grey, never placeable;
## label = Piece.ROTTEN_ID) on [param cell] of this half, bypassing the draw and the spawn timer (NOT
## the cell rules: the cell must be a real cell of this half, free of points and not blocked/burning,
## else null and nothing changes). It rots off the field after [param freshness_left] seconds; once
## held it leaves the hand after [param rot_in_hand_sec]. Emits point_spawned like any landing point.
func place_rotten_piece(cell: Vector2i, freshness_left: float, rot_in_hand_sec: float) -> FieldPoint:
	if not _side_cells.has(cell) or _is_occupied(cell) or _blocked_cells.has(cell):
		return null
	return _add_point(
		Piece.ROTTEN_ID, cell, freshness_left, true, maxf(rot_in_hand_sec, 0.0), Piece.make_rotten()
	)


## DEV-ONLY capture hook: puts a piece on the field, bypassing the draw, timer and caps.
func debug_place_piece(piece: Piece, cell: Vector2i, freshness_left: float) -> FieldPoint:
	return _add_point(piece.shape_id, cell, freshness_left, piece.is_rotten(), 0.0, piece)


## True when a real cell of this half has no point on it (missing cells are never free).
func is_cell_free(cell: Vector2i) -> bool:
	return _side_cells.has(cell) and not _is_occupied(cell)


func _add_point(
	label: String, cell: Vector2i, freshness: float, rotten: bool = false, rot_in_hand_sec: float = 0.0,
	piece: Piece = null
) -> FieldPoint:
	var p := FieldPoint.new()
	p.uid = _next_uid
	_next_uid += 1
	p.label = label
	p.cell = cell
	p.freshness_left = freshness
	p.rotten = rotten
	p.rot_in_hand_sec = rot_in_hand_sec
	p.piece = piece
	_points.append(p)
	point_spawned.emit(p)
	return p


func _max_on_field() -> int:
	return _config.piece_max_on_field


# Weighted draw among the drawable shapes (uniform when every weight is 0) + random rotation.
func _draw_piece() -> Piece:
	if _piece_shapes.is_empty() or _piece_library == null:
		return null
	var total: float = 0.0
	for id: String in _piece_shapes:
		total += _weight_of(id)
	var chosen: String = _piece_shapes[_piece_rng.randi_range(0, _piece_shapes.size() - 1)]
	if total > 0.0:
		var roll: float = _piece_rng.randf() * total
		for id: String in _piece_shapes:
			roll -= _weight_of(id)
			if roll < 0.0:
				chosen = id
				break
	return _piece_library.make_piece(chosen, _piece_rng.randi_range(0, 3))


# Weight of a shape: the injected source when there is one, else the library's chapter weight.
func _weight_of(id: String) -> float:
	if _weight_source is Dictionary:
		return maxf(float((_weight_source as Dictionary).get(id, 0.0)), 0.0)
	if _weight_source is Callable:
		return maxf(float((_weight_source as Callable).call(id)), 0.0)
	return _piece_library.weight(id, _chapter_id)


func _current_interval() -> float:
	var interval: float = _config.piece_spawn_interval_sec
	if _empty_hand_time > _config.hungry_after_sec:
		interval *= _config.hungry_interval_mult
	return interval * maxf(interval_scale, 0.01)


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


# Story 036: one cell along the wind when that cell is a free cell of this half (not the owner's cell, not blocked).
func _wind_offset_cell(cell: Vector2i, stand_cell: Vector2i) -> Vector2i:
	if not wind_offset_fn.is_valid():
		return cell
	var offset: Vector2i = wind_offset_fn.call()
	if offset == Vector2i.ZERO:
		return cell
	var target: Vector2i = cell + offset
	if not _side_cells.has(target) or target == stand_cell or _is_occupied(target) or _blocked_cells.has(target):
		return cell
	return target


func _is_occupied(cell: Vector2i) -> bool:
	for p: FieldPoint in _points:
		if p.cell == cell:
			return true
	return false

class_name BoardGrid
extends RefCounted
## Size and shape of the duel board, as data. Pure logic (no nodes, no layout).
##
## The board is two facing halves of side_cols x side_rows cells around a vertical divider:
## the player's half on the left, the boss's half on the right. A board cell is
## Vector2i(col, row) with col in 0..total_cols-1 and row 0 = top. Player half = cols
## 0..side_cols-1, boss half = cols side_cols..total_cols-1.
##
## SIDE COORDINATES (used by data files such as combat.json "missing_cells"): each half has
## its own (side_col, side_row) system where side col 0 is the column FARTHEST from the
## divider and side col side_cols-1 is the column NEAREST the divider, for both halves. So
## side cell (0, 0) is the top-left cell of the player half and the top-RIGHT cell of the
## boss half (board col total_cols-1). Side to board: player col = side_col; boss col =
## total_cols - 1 - side_col; the row is unchanged.
##
## SHAPE: [param missing_side_cells] (side coordinates) are holes. They are MIRRORED to the
## other half, so both halves are always symmetric around the divider. A missing cell is not
## part of the board: is_in_board() is false for it.
## Implements: Story 007 (board size and shape from data).

## Sentinel for "no cell" (off the board / not chosen).
const NO_CELL: Vector2i = Vector2i(-1, -1)

## Columns and rows of ONE half.
var side_cols: int = 1
var side_rows: int = 1
## Columns of the whole board (both halves) = 2 * side_cols.
var total_cols: int = 2
## Rows of the board (same as side_rows).
var rows: int = 1

var _missing_side: Array[Vector2i] = []
var _missing: Dictionary = {}
var _player_cells: Array[Vector2i] = []
var _enemy_cells: Array[Vector2i] = []


## Builds the grid. side_cols / side_rows below 1 are clamped to 1 (warning). Missing cells
## outside the side rectangle are ignored (warning); if every cell of a half would be
## missing the shape falls back to a full rectangle (warning).
func _init(p_side_cols: int, p_side_rows: int, missing_side_cells: Array[Vector2i] = []) -> void:
	if p_side_cols < 1 or p_side_rows < 1:
		push_warning("BoardGrid: size %dx%d clamped to at least 1x1" % [p_side_cols, p_side_rows])
	side_cols = maxi(p_side_cols, 1)
	side_rows = maxi(p_side_rows, 1)
	total_cols = side_cols * 2
	rows = side_rows
	for cell: Vector2i in missing_side_cells:
		if cell.x < 0 or cell.x >= side_cols or cell.y < 0 or cell.y >= side_rows:
			push_warning("BoardGrid: missing cell %s is outside the %dx%d side, ignored" % [cell, side_cols, side_rows])
		elif not _missing_side.has(cell):
			_missing_side.append(cell)
	if _missing_side.size() >= side_cols * side_rows:
		push_warning("BoardGrid: every cell is missing, using a full rectangle")
		_missing_side.clear()
	for cell: Vector2i in _missing_side:
		_missing[cell] = true
		_missing[Vector2i(total_cols - 1 - cell.x, cell.y)] = true
	for row: int in rows:
		for col: int in side_cols:
			if not _missing.has(Vector2i(col, row)):
				_player_cells.append(Vector2i(col, row))
		for col: int in range(side_cols, total_cols):
			if not _missing.has(Vector2i(col, row)):
				_enemy_cells.append(Vector2i(col, row))


## True if [param cell] is inside the bounding rectangle and not a missing cell.
func is_in_board(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= total_cols or cell.y < 0 or cell.y >= rows:
		return false
	return not _missing.has(cell)


## True if [param cell] is a real cell of the player's half.
func is_player_cell(cell: Vector2i) -> bool:
	return cell.x < side_cols and is_in_board(cell)


## True if [param cell] is a real cell of the boss's half.
func is_enemy_cell(cell: Vector2i) -> bool:
	return cell.x >= side_cols and is_in_board(cell)


## Real cells of the player's half, row by row (top first), left to right.
func player_cells() -> Array[Vector2i]:
	return _player_cells.duplicate()


## Real cells of the boss's half, row by row (top first), left to right.
func enemy_cells() -> Array[Vector2i]:
	return _enemy_cells.duplicate()


## The holes, in side coordinates (as given, de-duplicated, in range).
func missing_side_cells() -> Array[Vector2i]:
	return _missing_side.duplicate()


## Real player cell nearest the centre of the player's half (ties: nearer the divider,
## then the upper one).
func default_player_cell() -> Vector2i:
	return _default_cell(_player_cells)


## Real boss cell nearest the centre of the boss's half (same tie rules, mirrored).
func default_enemy_cell() -> Vector2i:
	return _default_cell(_enemy_cells)


## Board cell to side coordinates (see the class doc: side col 0 = farthest from the
## divider on both halves). Works for any cell, real or not.
func to_side_coords(cell: Vector2i) -> Vector2i:
	if cell.x < side_cols:
		return cell
	return Vector2i(total_cols - 1 - cell.x, cell.y)


## Perimeter point labels: A1..A<side_cols> (top edge, by column), B1..B<side_rows> (right
## edge, by row), C1..C<side_cols> (bottom edge, by column), D1..D<side_rows> (left edge,
## by row).
func perimeter_labels() -> Array[String]:
	var labels: Array[String] = []
	for i: int in side_cols:
		labels.append("A%d" % (i + 1))
	for i: int in side_rows:
		labels.append("B%d" % (i + 1))
	for i: int in side_cols:
		labels.append("C%d" % (i + 1))
	for i: int in side_rows:
		labels.append("D%d" % (i + 1))
	return labels


# Doubled-integer distance to the side centre keeps ties exact (no float compare).
func _default_cell(cells: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = NO_CELL
	var best_dist: int = 0
	var best_sx: int = 0
	for cell: Vector2i in cells:
		var s: Vector2i = to_side_coords(cell)
		var dx: int = s.x * 2 - (side_cols - 1)
		var dy: int = s.y * 2 - (side_rows - 1)
		var dist: int = dx * dx + dy * dy
		var better: bool = best == NO_CELL or dist < best_dist
		if not better and dist == best_dist:
			# Larger side col = nearer the divider; cells iterate top row first, so an
			# equal (dist, sx) keeps the upper one.
			better = s.x > best_sx
		if better:
			best = cell
			best_dist = dist
			best_sx = s.x
	return best

class_name CutResolver
extends RefCounted
## Pure geometry for cuts: turns perimeter point labels into the set of covered cells.
##
## SQUARE COORDINATES: the target half is the square [0,cols] x [0,rows] (x right, y down,
## one unit per cell). Labels are by SCREEN position, same for both boards: A = top edge
## (A1 leftmost), C = bottom edge (left to right), B = right edge (top to bottom), D = left
## edge (top to bottom). A_i=(i-0.5,0), C_i=(i-0.5,rows), D_i=(0,i-0.5), B_i=(cols,i-0.5).
## One point cuts straight to its opposite (A_i<->C_i, B_i<->D_i). Two points make a
## segment, 3-4 points a closed polygon, in the order given.
## Covered cells = border cells (segment passes through the closed cell rect with positive
## length) plus, for polygons, cells whose centre is inside (even-odd).
## Implements: Story 008 (cut shapes).

## Returned by [method label_point] for an invalid label.
const INVALID_POINT: Vector2 = Vector2(-1.0, -1.0)
## Float tolerance for geometry.
const EPSILON: float = 0.000001
## Most labels one cut uses.
const MAX_LABELS: int = 4


## True if [param label] ("A1".."D<n>") exists on a [param cols] x [param rows] square.
static func is_valid_label(label: String, cols: int, rows: int) -> bool:
	if label.length() < 2:
		return false
	var edge: String = label.substr(0, 1)
	var num_text: String = label.substr(1)
	if not num_text.is_valid_int():
		return false
	var index: int = num_text.to_int()
	if edge == "A" or edge == "C":
		return index >= 1 and index <= cols
	if edge == "B" or edge == "D":
		return index >= 1 and index <= rows
	return false


## Perimeter point of [param label] in square coordinates, or [constant INVALID_POINT].
static func label_point(label: String, cols: int, rows: int) -> Vector2:
	if not is_valid_label(label, cols, rows):
		return INVALID_POINT
	var edge: String = label.substr(0, 1)
	var offset: float = label.substr(1).to_int() - 0.5
	match edge:
		"A":
			return Vector2(offset, 0.0)
		"C":
			return Vector2(offset, float(rows))
		"D":
			return Vector2(0.0, offset)
		_:
			return Vector2(float(cols), offset)


## Label straight across the square (A_i<->C_i, B_i<->D_i); "" if invalid.
static func opposite_label(label: String, cols: int, rows: int) -> String:
	if not is_valid_label(label, cols, rows):
		return ""
	var edge: String = label.substr(0, 1)
	var opposite: String = ""
	match edge:
		"A":
			opposite = "C"
		"C":
			opposite = "A"
		"B":
			opposite = "D"
		_:
			opposite = "B"
	return opposite + label.substr(1)


## Covered cells (col, row) in square coordinates, sorted row-major, no duplicates.
## Empty for invalid input. Labels beyond [constant MAX_LABELS] are ignored (warning).
static func resolve_square(labels: Array[String], cols: int, rows: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if labels.is_empty() or cols < 1 or rows < 1:
		return result
	var used: Array[String] = labels
	if labels.size() > MAX_LABELS:
		push_warning("CutResolver: %d labels given, only the first %d are used" % [labels.size(), MAX_LABELS])
		used = labels.slice(0, MAX_LABELS)
	var points: Array[Vector2] = []
	for label: String in used:
		var p: Vector2 = label_point(label, cols, rows)
		if p == INVALID_POINT:
			return result
		points.append(p)
	var covered: Dictionary = {}
	if points.size() == 1:
		var end: Vector2 = label_point(opposite_label(used[0], cols, rows), cols, rows)
		_add_segment_cells(points[0], end, cols, rows, covered)
	elif points.size() == 2:
		_add_segment_cells(points[0], points[1], cols, rows, covered)
	else:
		for i: int in points.size():
			_add_segment_cells(points[i], points[(i + 1) % points.size()], cols, rows, covered)
		for row: int in rows:
			for col: int in cols:
				if _inside_even_odd(Vector2(col + 0.5, row + 0.5), points):
					covered[Vector2i(col, row)] = true
	for row: int in rows:
		for col: int in cols:
			if covered.has(Vector2i(col, row)):
				result.append(Vector2i(col, row))
	return result


## Covered REAL board cells on the target half. The square is the target half only
## (grid.side_cols x grid.side_rows); enemy half col = side_cols + square col, player half
## col = square col. Missing cells are dropped. Row-major order.
static func resolve_on_board(grid: BoardGrid, target_is_enemy: bool, labels: Array[String]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offset: int = grid.side_cols if target_is_enemy else 0
	for cell: Vector2i in resolve_square(labels, grid.side_cols, grid.side_rows):
		var board_cell: Vector2i = Vector2i(cell.x + offset, cell.y)
		if grid.is_in_board(board_cell):
			result.append(board_cell)
	return result


static func _add_segment_cells(a: Vector2, b: Vector2, cols: int, rows: int, covered: Dictionary) -> void:
	for row: int in rows:
		for col: int in cols:
			if _clip_length(a, b, Vector2(col, row), Vector2(col + 1, row + 1)) > EPSILON:
				covered[Vector2i(col, row)] = true


# Length of segment a-b inside the closed rectangle [lo, hi] (Liang-Barsky).
static func _clip_length(a: Vector2, b: Vector2, lo: Vector2, hi: Vector2) -> float:
	var d: Vector2 = b - a
	var length: float = d.length()
	if length <= EPSILON:
		return 0.0
	var t: Vector2 = Vector2(0.0, 1.0)
	t = _clip_axis(a.x, d.x, lo.x, hi.x, t)
	if t.x > t.y:
		return 0.0
	t = _clip_axis(a.y, d.y, lo.y, hi.y, t)
	if t.x > t.y:
		return 0.0
	return (t.y - t.x) * length


static func _clip_axis(start: float, delta: float, lo: float, hi: float, t: Vector2) -> Vector2:
	if absf(delta) <= EPSILON:
		if start < lo - EPSILON or start > hi + EPSILON:
			return Vector2(1.0, 0.0)
		return t
	var t_lo: float = (lo - start) / delta
	var t_hi: float = (hi - start) / delta
	if t_lo > t_hi:
		var swap: float = t_lo
		t_lo = t_hi
		t_hi = swap
	return Vector2(maxf(t.x, t_lo), minf(t.y, t_hi))


static func _inside_even_odd(p: Vector2, poly: Array[Vector2]) -> bool:
	var inside: bool = false
	var n: int = poly.size()
	for i: int in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		if (a.y > p.y) != (b.y > p.y):
			var x_at: float = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
			if p.x < x_at:
				inside = not inside
	return inside

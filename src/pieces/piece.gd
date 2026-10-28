class_name Piece
extends RefCounted
## One puzzle piece ("manh an"): a fixed polyomino shape plus a rotation 0..3 (90 degrees
## clockwise per step, no mirroring). Pure data, no nodes. A piece never changes: [method rotated]
## returns a new one.
## Cells are (x, y) with y growing downward. [method relative_cells] is normalised so the
## top-left corner of the bounding box is (0, 0).
## A ROTTEN piece (thrown by the rotten_thrower trait) is a 1-cell grey piece that can never be
## placed ([method placeable] is false).
## Story 041: an ODD piece ("Khoi La") is a runtime polyomino not in pieces.json; its shape_id is
## [constant ODD_PREFIX] + its [method canonical_key]. It obeys every rule of a classic piece.
## Implements: Story 024 (Part A), Story 041, design/game-brief.md "Core loop (v5)".

## Shape id used by every rotten piece.
const ROTTEN_ID: String = "rotten"
## Story 041: shape_id prefix of every odd (runtime-generated) piece.
const ODD_PREFIX: String = "odd:"

## Id of the shape in assets/data/pieces.json ("mono", "t4", ...), or [constant ROTTEN_ID].
var shape_id: String = ""
## Rotation in quarter turns clockwise, 0..3.
var rotation: int = 0

var _base_cells: Array[Vector2i] = []
var _rotten: bool = false


## Builds a piece from the UNROTATED shape [param cells] (any offset; they are normalised) and a
## [param p_rotation] in quarter turns (wrapped into 0..3).
static func make(p_shape_id: String, cells: Array[Vector2i], p_rotation: int = 0) -> Piece:
	var piece := Piece.new()
	piece.shape_id = p_shape_id
	piece._base_cells = _normalise(cells)
	piece.rotation = posmod(p_rotation, 4)
	return piece


## A rotten piece: one cell, never placeable.
static func make_rotten() -> Piece:
	var piece: Piece = Piece.make(ROTTEN_ID, [Vector2i.ZERO] as Array[Vector2i])
	piece._rotten = true
	return piece


## New piece turned [param times] quarter turns clockwise more (negative = counter-clockwise).
func rotated(times: int = 1) -> Piece:
	var piece := Piece.new()
	piece.shape_id = shape_id
	piece._base_cells = _base_cells.duplicate()
	piece._rotten = _rotten
	piece.rotation = posmod(rotation + times, 4)
	return piece


## Cells of the piece in its current rotation, normalised to the origin and sorted row by row
## (top first, left to right).
func relative_cells() -> Array[Vector2i]:
	var turned: Array[Vector2i] = []
	for cell: Vector2i in _base_cells:
		var c: Vector2i = cell
		for _i: int in rotation:
			c = Vector2i(-c.y, c.x) # 90 degrees clockwise with y pointing down
		turned.append(c)
	return _normalise(turned)


## Absolute cells when the bounding box's top-left corner sits on [param anchor].
func cells_at(anchor: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in relative_cells():
		out.append(cell + anchor)
	return out


## Number of cells.
func cell_count() -> int:
	return _base_cells.size()


## Bounding box size (columns, rows) in the current rotation.
func size() -> Vector2i:
	var max_cell := Vector2i.ZERO
	for cell: Vector2i in relative_cells():
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	return max_cell + Vector2i.ONE


## True for the rotten piece (grey, cannot be placed).
func is_rotten() -> bool:
	return _rotten


## True when the piece may be placed on a board (false for a rotten piece).
func placeable() -> bool:
	return not _rotten and not _base_cells.is_empty()


## Story 041: true for an odd piece (shape_id starts with [constant ODD_PREFIX]).
func is_odd() -> bool:
	return shape_id.begins_with(ODD_PREFIX)


## Story 041: rotation-invariant key of a cell set (any offset): for each of the 4 quarter turns (the
## [method relative_cells] rule, normalised and sorted) the cells as "x,y;x,y;...", and the
## lexicographically smallest string wins. Mirror images (L vs J) give different keys. Empty = "".
static func canonical_key(cells: Array[Vector2i]) -> String:
	if cells.is_empty():
		return ""
	var best: String = ""
	for turns: int in 4:
		var turned: Array[Vector2i] = []
		for cell: Vector2i in cells:
			var c: Vector2i = cell
			for _i: int in turns:
				c = Vector2i(-c.y, c.x)
			turned.append(c)
		var parts: PackedStringArray = []
		for cell: Vector2i in _normalise(turned):
			parts.append("%d,%d" % [cell.x, cell.y])
		var key: String = ";".join(parts)
		if turns == 0 or key < best:
			best = key
	return best


# Shifts [param cells] so min x = min y = 0 and sorts them by (y, x).
static func _normalise(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if cells.is_empty():
		return out
	var min_x: int = cells[0].x
	var min_y: int = cells[0].y
	for cell: Vector2i in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	for cell: Vector2i in cells:
		var shifted := Vector2i(cell.x - min_x, cell.y - min_y)
		if not out.has(shifted):
			out.append(shifted)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out

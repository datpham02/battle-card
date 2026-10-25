class_name CastPlan
extends RefCounted
## The pieces a cast is made of (1..max_pieces_per_cast, normally 1 or 2) with the board cells
## each one covers. Pure data, no nodes. The cast's cells are the union of the pieces' cells;
## two pieces may touch by an edge or sit apart but never share a cell. An optional cell cap
## (combat.json max_cast_cells, 0 = off) refuses a piece that would push the total over it.
## Implements: Story 028 (Part A and B), design/game-brief.md "Ghep manh va hinh chu dao".

var _max_pieces: int = 2
var _max_cells: int = 0
var _slots: Array[int] = []
var _pieces: Array[Piece] = []
var _piece_cells: Array = [] # Array of Array[Vector2i], parallel to _pieces


## Sets the limits and empties the plan. [param max_pieces] is clamped to >= 1;
## [param max_cast_cells] 0 (or less) = no cell cap. Returns self for chaining.
func init(max_pieces: int, max_cast_cells: int) -> CastPlan:
	_max_pieces = maxi(max_pieces, 1)
	_max_cells = maxi(max_cast_cells, 0)
	clear()
	return self


## Adds [param piece] (taken from hold slot [param slot]) covering [param cells]. Returns false
## and changes nothing when the plan is already full, a cell overlaps a piece already in the
## plan, [param cells] is empty, or a positive cell cap would be exceeded.
func add_piece(slot: int, piece: Piece, cells: Array[Vector2i]) -> bool:
	if piece == null or cells.is_empty() or is_full():
		return false
	var own: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if own.has(cell):
			return false
		own.append(cell)
	for existing: Variant in _piece_cells:
		for cell: Vector2i in own:
			if (existing as Array).has(cell):
				return false
	if _max_cells > 0 and total_cells() + own.size() > _max_cells:
		return false
	_slots.append(slot)
	_pieces.append(piece)
	_piece_cells.append(own)
	return true


## Removes the piece at [param index]; false when the index is out of range.
func remove_piece(index: int) -> bool:
	if index < 0 or index >= _pieces.size():
		return false
	_slots.remove_at(index)
	_pieces.remove_at(index)
	_piece_cells.remove_at(index)
	return true


## Number of pieces in the plan.
func piece_count() -> int:
	return _pieces.size()


## Total number of cells of all pieces (pieces never overlap, so this is the union's size).
func total_cells() -> int:
	var total: int = 0
	for entry: Variant in _piece_cells:
		total += (entry as Array).size()
	return total


## Union of all pieces' cells, row by row (y, then x).
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for entry: Variant in _piece_cells:
		for cell: Vector2i in entry as Array:
			out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## Hold slot of each piece, in the order they were added.
func slots() -> Array[int]:
	return _slots.duplicate()


## The pieces, in the order they were added.
func pieces() -> Array[Piece]:
	return _pieces.duplicate()


## Cells covered by the piece at [param index] (empty when out of range).
func piece_cells(index: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if index >= 0 and index < _piece_cells.size():
		out.assign(_piece_cells[index])
	return out


## True when no more piece can be added (max pieces reached).
func is_full() -> bool:
	return _pieces.size() >= _max_pieces


## True when any of [param other] shares an EDGE with a cell of the plan (diagonal contact and
## overlap do not count).
func touches(other: Array[Vector2i]) -> bool:
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var mine: Array[Vector2i] = cells()
	for cell: Vector2i in other:
		for step: Vector2i in steps:
			if mine.has(cell + step):
				return true
	return false


## True only for a TWO-piece plan whose union equals [param featured] (4 rotations, no flip).
func is_featured(featured: Array[Vector2i]) -> bool:
	return piece_count() == 2 and FeaturedShape.matches(featured, cells())


## Empties the plan (limits are kept).
func clear() -> void:
	_slots.clear()
	_pieces.clear()
	_piece_cells.clear()

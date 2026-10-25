class_name FeaturedShape
extends RefCounted
## Pure helpers for the "featured shape" (hinh chu dao) of a match: a 5-7 cell polyomino that
## a two-piece cast earns a bonus for when the union of the two pieces' cells equals it.
## Matching normalises the cell set (translate to the origin, sort) and compares it with the
## 4 rotations of the featured shape; mirroring is NOT allowed.
## Implements: Story 028 (Part B), design/game-brief.md "Ghep manh va hinh chu dao".


## Translates [param cells] so min x = min y = 0, drops duplicates and sorts row by row
## (y, then x). An empty input gives an empty array.
static func normalize(cells: Array[Vector2i]) -> Array[Vector2i]:
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


## [param cells] turned [param quarter_turns] x 90 degrees clockwise (y points down), normalised.
static func rotate_cells(cells: Array[Vector2i], quarter_turns: int) -> Array[Vector2i]:
	var turned: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var c: Vector2i = cell
		for _i: int in posmod(quarter_turns, 4):
			c = Vector2i(-c.y, c.x)
		turned.append(c)
	return normalize(turned)


## True iff [param cast_cells], once normalised, equal [param featured] under one of its 4
## rotations (no flip). Both empty or different sizes never match.
static func matches(featured: Array[Vector2i], cast_cells: Array[Vector2i]) -> bool:
	if featured.is_empty() or cast_cells.is_empty():
		return false
	var cast: Array[Vector2i] = normalize(cast_cells)
	if cast.size() != normalize(featured).size():
		return false
	for turns: int in 4:
		if rotate_cells(featured, turns) == cast:
			return true
	return false


## Every DISTINCT unordered pair of shape ids of [param library] that tiles [param featured]
## (in the given orientation) with exactly two non-overlapping pieces, each piece in any of its
## rotations. Pairs are [id_a, id_b] with id_a <= id_b, sorted, e.g. [["bar3", "l3"], ...].
static func pair_compositions(library: PieceLibrary, featured: Array[Vector2i]) -> Array:
	var target: Array[Vector2i] = normalize(featured)
	var found: Dictionary = {}
	var ids: Array[String] = library.shape_ids()
	for id_a: String in ids:
		for turns_a: int in 4:
			var rel_a: Array[Vector2i] = library.make_piece(id_a, turns_a).relative_cells()
			if rel_a.size() >= target.size():
				continue
			for anchor_cell: Vector2i in target:
				var anchor: Vector2i = anchor_cell - rel_a[0]
				var placed: Array[Vector2i] = []
				var inside: bool = true
				for cell: Vector2i in rel_a:
					var abs_cell: Vector2i = cell + anchor
					if not target.has(abs_cell):
						inside = false
						break
					placed.append(abs_cell)
				if not inside:
					continue
				var rest: Array[Vector2i] = []
				for cell: Vector2i in target:
					if not placed.has(cell):
						rest.append(cell)
				for id_b: String in ids:
					if id_b < id_a or found.has(_pair_key(id_a, id_b)):
						continue
					if _is_piece_shape(library, id_b, rest):
						found[_pair_key(id_a, id_b)] = [id_a, id_b]
	# A pair (a, b) is also found as (b, a) from the other side; the id_b < id_a skip keeps one.
	var keys: Array = found.keys()
	keys.sort()
	var out: Array = []
	for key: Variant in keys:
		out.append(found[key])
	return out


static func _pair_key(a: String, b: String) -> String:
	return "%s+%s" % [a, b] if a <= b else "%s+%s" % [b, a]


# True when [param rest] (any offset) is one rotation of the shape [param id].
static func _is_piece_shape(library: PieceLibrary, id: String, rest: Array[Vector2i]) -> bool:
	var norm: Array[Vector2i] = normalize(rest)
	for turns: int in 4:
		var rel: Array[Vector2i] = library.make_piece(id, turns).relative_cells()
		if rel.size() != norm.size():
			return false
		if rel == norm:
			return true
	return false

class_name ShapeTags
extends RefCounted
## Skill v2 (docs/skill-v2/02-mechanics-catalog.md M16): pure classification of ONE placed piece from its physical
## cells (board or relative coordinates, y down). Tags are rotation-invariant except `line_h` / `line_v`, and
## mirror-invariant (an L and a J both get `L`). Effective cells (Trảm ×2) never reach this: callers pass the cells
## actually placed. Families:
##   mono (1 cell) · domino (2) · line (+ line_h / line_v) · square (2x2) · L (a path with one turn) ·
##   S (a path whose turns alternate) · U (a path whose two turns go the same way) · T (one 3-way cell, no 2x2) ·
##   plus (one 4-way cell) · P (5 cells: a 3-way cell next to a 2x2) · branched (any cell with >= 3 neighbours) ·
##   compact (see below) · odd (caller flag: an Odd block).
## `compact` (B1.5 reconciliation of M16): cells / bbox area >= [constant COMPACT_MIN_FILL] (the M16 rule) AND the
## piece holds a full 2x2 block. The fill rule alone would also tag mono, every bar (fill 1.0), l3 (0.75) and u5 (0.83),
## which the M16 table excludes (it lists only square and p5); the 2x2 requirement keeps both statements of M16 true.
## Numbers: size, bbox (Vector2i w, h), fill (cells / bbox area), length (longest straight run), branch_count (cells
## with >= 3 neighbours), centre (the cell nearest the bbox centre; ties -> the cell nearest [param hero_cell] when
## given, then smallest y, then x).

## M16: minimum cells / bbox-area ratio for `compact`.
const COMPACT_MIN_FILL: float = 0.75
## "No hero cell given" sentinel for the centre tie-break.
const NO_CELL := Vector2i(-99999, -99999)
const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## {tags: Array[String] (sorted), size, bbox, fill, length, branch_count, centre} of [param cells]; [param is_odd]
## adds `odd`; [param hero_cell] breaks centre ties (M16: nearest the hero).
static func tags_for(cells: Array[Vector2i], is_odd: bool = false, hero_cell: Vector2i = NO_CELL) -> Dictionary:
	var out: Dictionary = {"tags": [] as Array[String], "size": cells.size(), "bbox": Vector2i.ZERO, "fill": 0.0,
		"length": 0, "branch_count": 0, "centre": Vector2i.ZERO}
	if cells.is_empty():
		return out
	var lo := Vector2i(cells[0])
	var hi := Vector2i(cells[0])
	for c: Vector2i in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var bbox: Vector2i = hi - lo + Vector2i.ONE
	out["bbox"] = bbox
	var fill: float = float(cells.size()) / float(bbox.x * bbox.y)
	out["fill"] = fill
	out["length"] = _longest_run(cells)
	out["centre"] = _centre(cells, lo, hi, hero_cell)
	var degree: Dictionary = {}
	var branch: int = 0
	var max_deg: int = 0
	for c: Vector2i in cells:
		var d: int = 0
		for dir: Vector2i in _DIRS:
			if cells.has(c + dir):
				d += 1
		degree[c] = d
		max_deg = maxi(max_deg, d)
		if d >= 3:
			branch += 1
	out["branch_count"] = branch
	var tags: Array[String] = []
	var n: int = cells.size()
	var has_square: bool = _has_square(cells)
	var compact: bool = has_square and fill >= COMPACT_MIN_FILL - 0.0001
	if n == 1:
		tags.append("mono")
	elif bbox.x == 1 or bbox.y == 1:
		tags.append("line")
		tags.append("line_h" if bbox.y == 1 else "line_v")
		if n == 2:
			tags.append("domino")
	elif n == 4 and bbox == Vector2i(2, 2):
		tags.append("square")
	elif max_deg == 4:
		tags.append("plus")
	elif max_deg == 3:
		# P is the p5 family only: a bigger block with a 3-way cell and a 2x2 (an Odd 2x3, ...) keeps just
		# `branched` / `compact`.
		if not has_square:
			tags.append("T")
		elif n == 5:
			tags.append("P")
	elif max_deg <= 2 and not has_square:
		var turns: Array[int] = _path_turns(cells, degree)
		if turns.size() == 1:
			tags.append("L")
		elif turns.size() == 2 and turns[0] == turns[1]:
			tags.append("U")
		elif turns.size() >= 2:
			tags.append("S")
	if branch > 0:
		tags.append("branched")
	if compact:
		tags.append("compact")
	if is_odd:
		tags.append("odd")
	tags.sort()
	out["tags"] = tags
	return out


# Longest straight run of cells along a row or a column.
static func _longest_run(cells: Array[Vector2i]) -> int:
	var best: int = 0
	for c: Vector2i in cells:
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if cells.has(c - dir):
				continue
			var run: int = 1
			while cells.has(c + dir * run):
				run += 1
			best = maxi(best, run)
	return best


static func _centre(cells: Array[Vector2i], lo: Vector2i, hi: Vector2i, hero_cell: Vector2i) -> Vector2i:
	var mid: Vector2 = (Vector2(lo) + Vector2(hi)) * 0.5
	var best: Vector2i = cells[0]
	var best_d: float = INF
	for c: Vector2i in cells:
		var d: float = Vector2(c).distance_squared_to(mid)
		if d < best_d - 0.0001 or (absf(d - best_d) <= 0.0001 and _closer(c, best, hero_cell)):
			best = c
			best_d = d
	return best


# Tie-break of two equally central cells: nearer the hero (Manhattan) when known, then smallest y, then x.
static func _closer(a: Vector2i, b: Vector2i, hero_cell: Vector2i) -> bool:
	if hero_cell != NO_CELL:
		var da: int = absi(a.x - hero_cell.x) + absi(a.y - hero_cell.y)
		var db: int = absi(b.x - hero_cell.x) + absi(b.y - hero_cell.y)
		if da != db:
			return da < db
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func _has_square(cells: Array[Vector2i]) -> bool:
	for c: Vector2i in cells:
		if cells.has(c + Vector2i(1, 0)) and cells.has(c + Vector2i(0, 1)) and cells.has(c + Vector2i(1, 1)):
			return true
	return false


# The turn signs (+1 / -1) along a simple path (every cell degree <= 2, two ends); [] when it is not a path.
static func _path_turns(cells: Array[Vector2i], degree: Dictionary) -> Array[int]:
	var turns: Array[int] = []
	var start: Vector2i = Vector2i(-99999, -99999)
	for c: Vector2i in cells:
		if int(degree[c]) == 1:
			start = c
			break
	if start.x == -99999:
		return turns
	var order: Array[Vector2i] = [start]
	var prev := Vector2i(-99999, -99999)
	var cur: Vector2i = start
	while order.size() < cells.size():
		var moved: bool = false
		for dir: Vector2i in _DIRS:
			var nxt: Vector2i = cur + dir
			if nxt != prev and cells.has(nxt) and not order.has(nxt):
				prev = cur
				cur = nxt
				order.append(nxt)
				moved = true
				break
		if not moved:
			return [] as Array[int]
	for i: int in range(1, order.size() - 1):
		var a: Vector2i = order[i] - order[i - 1]
		var b: Vector2i = order[i + 1] - order[i]
		var cross: int = a.x * b.y - a.y * b.x
		if cross != 0:
			turns.append(1 if cross > 0 else -1)
	return turns

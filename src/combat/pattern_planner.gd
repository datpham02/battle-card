class_name PatternPlanner
extends RefCounted
## Pure: every legal cell plan of a pattern skill right now (spec 3.4 anchor rules, rotations, clip).
## Pattern coordinates (spec 3.4): on the player's half, pattern col 0 is the FRONT column (next to the enemy half) and
## grows away from it; row 0 is the top. A pattern offset [dc, dr] is rotated in pattern space ((x, y) -> (-y, x) per
## 90 degrees) and then mapped to the board (board dx = -dc, dy = dr). An invalid cell (missing, not on the half, or
## refused by ctx.cell_ok_fn: hole / cracking = locked) drops the plan, unless the skill clips (then the cell is
## dropped and at least pattern.min_cells must stay). No plan = the skill cannot be cast now (canCast false, A-default).
## Implements: design/quick-specs/phase2-misty-forest-2026-11-01.md 3.4, P2.2.

const _NEIGHBOURS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]


## Plans of [param skill] (EnemySkillsConfig normalized skill). [param ctx]: grid (BoardGrid), player_cell, enemy_cell,
## optional enemy_cells (P2.2b: the footprint cells; self_cell plans cover them all, markers never land under them),
## markers (Array[Vector2i], enemy-half marker cells, newest LAST), cell_ok_fn (Callable(cell) -> bool; invalid = all ok).
## Each plan: {cells: Array[Vector2i], anchor: Vector2i, rotation: int}; distinct cell sets, deterministic order.
static func plans(skill: Dictionary, ctx: Dictionary) -> Array[Dictionary]:
	var pattern: Dictionary = skill["pattern"] as Dictionary
	var grid: BoardGrid = ctx["grid"] as BoardGrid
	var player: Vector2i = ctx["player_cell"] as Vector2i
	var anchor: String = str(pattern["anchor"])
	var out: Array[Dictionary] = []
	match anchor:
		"self_cell":
			var own: Array[Vector2i] = []
			own.assign(_enemy_cells(ctx))
			out.append({"cells": own, "anchor": ctx["enemy_cell"], "rotation": 0})
			return out
		"enemy_half_empty":
			var body: Array[Vector2i] = _enemy_cells(ctx)
			for cell: Vector2i in grid.enemy_cells():
				if body.has(cell) or (ctx.get("markers", []) as Array).has(cell) or not _ok(ctx, cell):
					continue
				var one: Array[Vector2i] = []
				one.append(cell)
				out.append({"cells": one, "anchor": cell, "rotation": 0})
			# P2.3 follow-up: `row: player` keeps only the cells of the player's row when there is one (the halves' rows
			# line up, spec 3.4); the caller still picks one of them at random (seeded).
			if str(pattern.get("row", "any")) == "player":
				var in_row: Array[Dictionary] = []
				for p: Dictionary in out:
					if (p["anchor"] as Vector2i).y == player.y:
						in_row.append(p)
				if not in_row.is_empty():
					return in_row
			return out
		"fixed":
			var fixed: Array[Vector2i] = []
			for off: Vector2i in pattern["offsets"]:
				fixed.append(Vector2i(grid.side_cols - 1 - off.x, off.y))
			_add_plan(out, skill, ctx, fixed, fixed[0] if not fixed.is_empty() else BoardGrid.NO_CELL, 0)
			return out
		"row_of_player", "row_of_anchor":
			var row: int = player.y
			var markers: Array = ctx.get("markers", []) as Array
			if anchor == "row_of_anchor" and not markers.is_empty():
				row = (markers[markers.size() - 1] as Vector2i).y
			var last_start: int = 0 if str(pattern["start"]) == "front" else grid.side_cols - 1
			for start: int in range(0, last_start + 1):
				var cells: Array[Vector2i] = []
				for off: Vector2i in pattern["offsets"]:
					cells.append(Vector2i(grid.side_cols - 1 - (start + off.x), row + off.y))
				_add_plan(out, skill, ctx, cells, Vector2i(grid.side_cols - 1 - start, row), 0)
			# P2.4: pattern.anchor_rows > 1 (Witch entangled_row in phases 2-3) also offers the same window on every
			# distinct marker row (newest first, up to anchor_rows), tagged `rows`; each row keeps >= min_cells.
			var rows: Array[int] = []
			if anchor == "row_of_anchor":
				rows = anchor_rows(pattern, markers)
			if rows.size() > 1:
				for start: int in range(0, last_start + 1):
					var union: Array[Vector2i] = []
					var every_row: bool = true
					for r: int in rows:
						var lane: Array[Vector2i] = _row_window(pattern, ctx, start, r)
						if lane.is_empty():
							every_row = false
							break
						union.append_array(lane)
					if every_row and _add_plan(out, skill, ctx, union, Vector2i(grid.side_cols - 1 - start, rows[0]), 0):
						out[out.size() - 1]["rows"] = rows.size()
			return out
		"column_of_player":
			for start: int in range(0, grid.rows):
				var cells: Array[Vector2i] = []
				for off: Vector2i in pattern["offsets"]:
					cells.append(Vector2i(player.x - off.y, start + off.x))
				_add_plan(out, skill, ctx, cells, Vector2i(player.x, start), 0)
			return out
	var anchors: Array[Vector2i] = []
	if anchor == "near_player":
		for dir: Vector2i in _NEIGHBOURS:
			var cell: Vector2i = player + dir
			if grid.is_player_cell(cell) and _ok(ctx, cell):
				anchors.append(cell)
	else:
		anchors.append(player)
	for a: Vector2i in anchors:
		for rot: int in pattern["rotations"]:
			var cells: Array[Vector2i] = []
			for off: Vector2i in pattern["offsets"]:
				cells.append(a + to_board(rotate(off, rot)))
			_add_plan(out, skill, ctx, cells, a, rot)
	return out


## P2.4: the distinct rows of [param markers] (newest first), at most pattern.anchor_rows of them.
static func anchor_rows(pattern: Dictionary, markers: Array) -> Array[int]:
	var rows: Array[int] = []
	for i: int in range(markers.size() - 1, -1, -1):
		var r: int = (markers[i] as Vector2i).y
		if not rows.has(r) and rows.size() < int(pattern.get("anchor_rows", 1)):
			rows.append(r)
	return rows


## [param off] rotated by [param degrees] (0/90/180/270) in pattern space: (x, y) -> (-y, x) per 90.
static func rotate(off: Vector2i, degrees: int) -> Vector2i:
	var v: Vector2i = off
	for _i: int in ((degrees / 90) % 4 + 4) % 4:
		v = Vector2i(-v.y, v.x)
	return v


## Pattern-space offset to a board delta on the player's half (pattern col grows away from the enemy half).
static func to_board(off: Vector2i) -> Vector2i:
	return Vector2i(-off.x, off.y)


## Followup cells of [param followup] after the first strike hit [param first_cells] (spec 3.5), one candidate list per
## rotation (ordered as authored). relative_to: first_cells (around every first cell... the FIRST one is the anchor),
## first_end (last first cell), first_center (the first cell nearest the centroid), player, same_cells (P2.3: the
## first cells again, all of them or no candidate).
## P2.4: first_shift (the first cells moved by each offset turned by [param first_rotation] + the followup rotation),
## followup.exclude_first (no candidate touching a first cell) and followup.prefer anchor_row (see EnemySkillsConfig).
static func followup_candidates(followup: Dictionary, first_cells: Array[Vector2i], player_cell: Vector2i, ctx: Dictionary,
		first_rotation: int = 0) -> Array[Dictionary]:
	var origin: Vector2i = first_cells[0] if not first_cells.is_empty() else player_cell
	match str(followup["relative_to"]):
		"first_end":
			origin = first_cells[first_cells.size() - 1] if not first_cells.is_empty() else player_cell
		"first_center":
			origin = _center_cell(first_cells, player_cell)
		"player":
			origin = player_cell
	var grid: BoardGrid = ctx["grid"] as BoardGrid
	var out: Array[Dictionary] = []
	if str(followup["relative_to"]) == "same_cells":
		# P2.3: the first strike's cells again (offsets ignored); a cell that became invalid drops the followup.
		var again: Array[Vector2i] = []
		for cell: Vector2i in first_cells:
			if not grid.is_player_cell(cell) or not _ok(ctx, cell):
				return out
			again.append(cell)
		if not again.is_empty():
			out.append({"cells": again, "anchor": again[0], "rotation": 0})
		return out
	if str(followup["relative_to"]) == "first_shift":
		for rot: int in followup["rotations"]:
			for off: Vector2i in followup["offsets"]:
				var shift: Vector2i = to_board(rotate(off, first_rotation + rot))
				var moved: Array[Vector2i] = []
				for cell: Vector2i in first_cells:
					moved.append(cell + shift)
				_add_followup(out, followup, first_cells, moved, ctx, first_cells[0] + shift if not first_cells.is_empty() else player_cell, rot)
		return _prefer(followup, out, origin, ctx)
	for rot: int in followup["rotations"]:
		var cells: Array[Vector2i] = []
		for off: Vector2i in followup["offsets"]:
			var cell: Vector2i = origin + to_board(rotate(off, rot))
			if not cells.has(cell):
				cells.append(cell)
		_add_followup(out, followup, first_cells, cells, ctx, origin, rot)
	return _prefer(followup, out, origin, ctx)


# A followup candidate: every cell a valid player cell (else dropped), not touching the first strike when
# exclude_first, distinct from the candidates already kept.
static func _add_followup(out: Array[Dictionary], followup: Dictionary, first_cells: Array[Vector2i], cells: Array[Vector2i],
		ctx: Dictionary, anchor: Vector2i, rot: int) -> void:
	var grid: BoardGrid = ctx["grid"] as BoardGrid
	if cells.is_empty():
		return
	for cell: Vector2i in cells:
		if not grid.is_player_cell(cell) or not _ok(ctx, cell):
			return
		if bool(followup.get("exclude_first", false)) and first_cells.has(cell):
			return
	for other: Dictionary in out:
		if other["cells"] == cells:
			return
	out.append({"cells": cells, "anchor": anchor, "rotation": rot})


# followup.prefer anchor_row: the candidates nearer the newest marker's row than [param origin]; all when none is.
static func _prefer(followup: Dictionary, candidates: Array[Dictionary], origin: Vector2i, ctx: Dictionary) -> Array[Dictionary]:
	var markers: Array = ctx.get("markers", []) as Array
	if str(followup.get("prefer", "none")) != "anchor_row" or markers.is_empty():
		return candidates
	var target: int = (markers[markers.size() - 1] as Vector2i).y
	var closer: Array[Dictionary] = []
	for c: Dictionary in candidates:
		var best: int = 1000
		for cell: Vector2i in c["cells"]:
			best = mini(best, absi(cell.y - target))
		if best < absi(origin.y - target):
			closer.append(c)
	return closer if not closer.is_empty() else candidates


static func _center_cell(cells: Array[Vector2i], fallback: Vector2i) -> Vector2i:
	if cells.is_empty():
		return fallback
	var sum: Vector2 = Vector2.ZERO
	for c: Vector2i in cells:
		sum += Vector2(c)
	var centre: Vector2 = sum / float(cells.size())
	var best: Vector2i = cells[0]
	for c: Vector2i in cells:
		if Vector2(c).distance_squared_to(centre) < Vector2(best).distance_squared_to(centre) - 0.0001:
			best = c
	return best


# P2.2b: every cell the enemy covers (ctx.enemy_cells, the footprint), else just ctx.enemy_cell (a 1-cell enemy).
static func _enemy_cells(ctx: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(ctx.get("enemy_cells")) == TYPE_ARRAY and not (ctx["enemy_cells"] as Array).is_empty():
		out.assign(ctx["enemy_cells"] as Array)
	else:
		out.append(ctx["enemy_cell"] as Vector2i)
	return out


static func _ok(ctx: Dictionary, cell: Vector2i) -> bool:
	var fn: Callable = ctx.get("cell_ok_fn", Callable()) as Callable
	return not fn.is_valid() or bool(fn.call(cell))


# Validates one raw plan (clip, must_cover_player, exclude_player, duplicates) and appends it.
static func _add_plan(out: Array[Dictionary], skill: Dictionary, ctx: Dictionary, raw: Array[Vector2i], anchor: Vector2i, rot: int) -> bool:
	var pattern: Dictionary = skill["pattern"] as Dictionary
	var grid: BoardGrid = ctx["grid"] as BoardGrid
	var player: Vector2i = ctx["player_cell"] as Vector2i
	var cells: Array[Vector2i] = []
	for cell: Vector2i in raw:
		var valid: bool = grid.is_player_cell(cell) and _ok(ctx, cell)
		if not valid:
			if not bool(pattern["clip"]):
				return false
			continue
		if not cells.has(cell):
			cells.append(cell)
	if cells.is_empty() or (bool(pattern["clip"]) and cells.size() < int(pattern["min_cells"])):
		return false
	if bool(pattern["must_cover_player"]) and not cells.has(player):
		return false
	if bool(pattern["exclude_player"]) and cells.has(player):
		return false
	var key: Array[Vector2i] = cells.duplicate()
	key.sort()
	for plan: Dictionary in out:
		var other: Array[Vector2i] = (plan["cells"] as Array[Vector2i]).duplicate()
		other.sort()
		if other == key:
			return false
	out.append({"cells": cells, "anchor": anchor, "rotation": rot})
	return true


# P2.4: the valid cells of one row's window (pattern offsets from [param start]), clipped like _add_plan; [] when a cell
# is invalid without clip or fewer than min_cells stay.
static func _row_window(pattern: Dictionary, ctx: Dictionary, start: int, row: int) -> Array[Vector2i]:
	var grid: BoardGrid = ctx["grid"] as BoardGrid
	var cells: Array[Vector2i] = []
	for off: Vector2i in pattern["offsets"]:
		var cell: Vector2i = Vector2i(grid.side_cols - 1 - (start + off.x), row + off.y)
		if not grid.is_player_cell(cell) or not _ok(ctx, cell):
			if not bool(pattern["clip"]):
				return [] as Array[Vector2i]
			continue
		if not cells.has(cell):
			cells.append(cell)
	if cells.size() < (int(pattern["min_cells"]) if bool(pattern["clip"]) else 1):
		return [] as Array[Vector2i]
	return cells

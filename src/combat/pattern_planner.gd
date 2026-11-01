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
			own.append(ctx["enemy_cell"] as Vector2i)
			out.append({"cells": own, "anchor": ctx["enemy_cell"], "rotation": 0})
			return out
		"enemy_half_empty":
			for cell: Vector2i in grid.enemy_cells():
				if cell == ctx["enemy_cell"] or (ctx.get("markers", []) as Array).has(cell) or not _ok(ctx, cell):
					continue
				var one: Array[Vector2i] = []
				one.append(cell)
				out.append({"cells": one, "anchor": cell, "rotation": 0})
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
## first_end (last first cell), first_center (the first cell nearest the centroid), player.
static func followup_candidates(followup: Dictionary, first_cells: Array[Vector2i], player_cell: Vector2i, ctx: Dictionary) -> Array[Dictionary]:
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
	for rot: int in followup["rotations"]:
		var cells: Array[Vector2i] = []
		var valid: bool = true
		for off: Vector2i in followup["offsets"]:
			var cell: Vector2i = origin + to_board(rotate(off, rot))
			if not grid.is_player_cell(cell) or not _ok(ctx, cell):
				valid = false
				break
			if not cells.has(cell):
				cells.append(cell)
		if valid and not cells.is_empty():
			out.append({"cells": cells, "anchor": origin, "rotation": rot})
	return out


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


static func _ok(ctx: Dictionary, cell: Vector2i) -> bool:
	var fn: Callable = ctx.get("cell_ok_fn", Callable()) as Callable
	return not fn.is_valid() or bool(fn.call(cell))


# Validates one raw plan (clip, must_cover_player, exclude_player, duplicates) and appends it.
static func _add_plan(out: Array[Dictionary], skill: Dictionary, ctx: Dictionary, raw: Array[Vector2i], anchor: Vector2i, rot: int) -> void:
	var pattern: Dictionary = skill["pattern"] as Dictionary
	var grid: BoardGrid = ctx["grid"] as BoardGrid
	var player: Vector2i = ctx["player_cell"] as Vector2i
	var cells: Array[Vector2i] = []
	for cell: Vector2i in raw:
		var valid: bool = grid.is_player_cell(cell) and _ok(ctx, cell)
		if not valid:
			if not bool(pattern["clip"]):
				return
			continue
		if not cells.has(cell):
			cells.append(cell)
	if cells.is_empty() or (bool(pattern["clip"]) and cells.size() < int(pattern["min_cells"])):
		return
	if bool(pattern["must_cover_player"]) and not cells.has(player):
		return
	if bool(pattern["exclude_player"]) and cells.has(player):
		return
	var key: Array[Vector2i] = cells.duplicate()
	key.sort()
	for plan: Dictionary in out:
		var other: Array[Vector2i] = (plan["cells"] as Array[Vector2i]).duplicate()
		other.sort()
		if other == key:
			return
	out.append({"cells": cells, "anchor": anchor, "rotation": rot})

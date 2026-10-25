class_name ZoneRules
extends RefCounted
## Story 027 "leave a path" rule for Ket gioi (seal) zones. Pure static logic, injectable: the caller
## passes the grid and a blocked-cell Callable, so the rule is testable without a running match.
## Implements: Story 027 Phan A (luat chua duong), design/game-brief.md v5 "Vung: Ket giới và Trận gai".

const _DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## Returns the zone cells to actually place. A new SEAL must not leave the unit standing on
## [param standing_cell] with no steppable neighbour: a step destination must be a cell of [param side]'s
## half that is not blocked by [param blocked_fn] (Callable(cell: Vector2i) -> bool; true = blocked: cracks,
## existing seals...) and not in the new zone. If the zone would close every open neighbour, the fewest
## cells are dropped (exactly one: an open neighbour inside the zone; the one with the most onward open
## exits wins, ties broken by x then y), so at least one neighbour stays open and every other cell is kept.
## Input order is kept, duplicates are removed. Thorn cells stay steppable, so this rule is for seals only.
## A unit that already has no open neighbour is not made worse, so the zone is returned unchanged.
## [param side] is a CombatState.Side value (the side whose half holds the zone).
static func fit_cells(
	grid: BoardGrid, side: int, standing_cell: Vector2i, zone_cells: Array[Vector2i], blocked_fn: Callable
) -> Array[Vector2i]:
	var zone: Array[Vector2i] = []
	for cell: Vector2i in zone_cells:
		if not zone.has(cell):
			zone.append(cell)
	var open_now: Array[Vector2i] = _open_neighbours(grid, side, standing_cell, [], blocked_fn)
	if open_now.is_empty():
		return zone
	if not _open_neighbours(grid, side, standing_cell, zone, blocked_fn).is_empty():
		return zone
	# Every open neighbour is inside the zone: free exactly one of them.
	var keep_open: Vector2i = open_now[0]
	var best_exits: int = -1
	for cell: Vector2i in open_now:
		var exits: int = _open_neighbours(grid, side, cell, zone, blocked_fn).size()
		if exits > best_exits or (exits == best_exits and _before(cell, keep_open)):
			best_exits = exits
			keep_open = cell
	zone.erase(keep_open)
	return zone


## THE single code point that forms a seal: fits [param zone_cells] with [method fit_cells] (the blocked
## test is [param extra_blocked] OR the seals already in [param status]) around the unit of [param side]
## in [param state], then applies the kept cells with [method StatusEffects.apply_seal]. Used by cards
## (CutEffects) and boss traits alike. Returns the cells actually sealed.
static func cast_seal(
	state: CombatState, grid: BoardGrid, status: StatusEffects, side: int,
	zone_cells: Array[Vector2i], duration: float, extra_blocked: Callable = Callable()
) -> Array[Vector2i]:
	var blocked: Callable = func(cell: Vector2i) -> bool:
		return status.is_sealed(side, cell) or (extra_blocked.is_valid() and bool(extra_blocked.call(cell)))
	var kept: Array[Vector2i] = fit_cells(grid, side, state.cell_of(side), zone_cells, blocked)
	status.apply_seal(side, kept, duration)
	return kept


## Forms a thorn zone (never reduced: thorn cells stay steppable); mirror of [method cast_seal] so a
## trait has one call per kind. Returns the cells (deduplicated, input order).
static func cast_thorns(
	status: StatusEffects, side: int, zone_cells: Array[Vector2i], duration: float, damage: float, fragile_stacks: int
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in zone_cells:
		if not cells.has(cell):
			cells.append(cell)
	status.apply_thorns(side, cells, duration, damage, fragile_stacks)
	return cells


## Neighbours of [param from] on [param side]'s half that a step could land on right now, ignoring the
## cells in [param extra_blocked]. Sorted by x then y.
static func _open_neighbours(
	grid: BoardGrid, side: int, from: Vector2i, extra_blocked: Array[Vector2i], blocked_fn: Callable
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir: Vector2i in _DIRECTIONS:
		var cell: Vector2i = from + dir
		var on_half: bool = grid.is_player_cell(cell) if side == CombatState.Side.PLAYER else grid.is_enemy_cell(cell)
		if not on_half or extra_blocked.has(cell):
			continue
		if blocked_fn.is_valid() and bool(blocked_fn.call(cell)):
			continue
		out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _before(a, b))
	return out


static func _before(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)

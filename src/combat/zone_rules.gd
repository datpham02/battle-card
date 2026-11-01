class_name ZoneRules
extends RefCounted
## Story 027 "leave a path" rule for zones that block steps (TileHazards sand / crumble, drop tiles; the player seal
## zone that first used it was deleted 2026-11-01, ADR-0001 Phase 1). Pure static logic, injectable: the caller
## passes the grid and a blocked-cell Callable, so the rule is testable without a running match.
## One zone effect per cell and locked cells (quick spec 2026-11-01) live in StatusEffects, not here.
## Implements: Story 027 Phan A (luat chua duong), design/game-brief.md v5 "Vung: Ket giới và Trận gai";
## drop tiles (Ô rớt): design/quick-specs/o-rot-thay-tuong-2026-10-31.md rule 6 (fit_drop_cells, unit_cell_droppable, cast_drop).

const _DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Float slack for cooldowns counted down in fixed steps.
const _EPS: float = 0.000001


## Returns the zone cells to actually place. A new step-blocking zone must not leave the unit standing on
## [param standing_cell] with no steppable neighbour: a step destination must be a cell of [param side]'s
## half that is not blocked by [param blocked_fn] (Callable(cell: Vector2i) -> bool; true = blocked: cracks,
## holes, sand...) and not in the new zone. If the zone would close every open neighbour, the fewest
## cells are dropped (exactly one: an open neighbour inside the zone; the one with the most onward open
## exits wins, ties broken by x then y), so at least one neighbour stays open and every other cell is kept.
## Input order is kept, duplicates are removed. Thorn cells stay steppable, so this rule never applies to thorns.
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


## Drop tile fairness, part 1 (design/quick-specs/o-rot-thay-tuong-2026-10-31.md rule 6): the unit standing on
## [param standing_cell] must keep at least one 4-neighbour on [param side]'s half that is steppable, not cracking and
## not a hole ([param blocked_fn] Callable(cell) -> bool covers all three) and not in the new crack. Like
## [method fit_cells], the fewest cells are dropped when the crack would close every safe neighbour (exactly one); but
## when the unit has NO safe neighbour already, nothing may crack at all (empty result: no cast).
static func fit_drop_cells(
	grid: BoardGrid, side: int, standing_cell: Vector2i, zone_cells: Array[Vector2i], blocked_fn: Callable
) -> Array[Vector2i]:
	if _open_neighbours(grid, side, standing_cell, [], blocked_fn).is_empty():
		var none: Array[Vector2i] = []
		return none
	return fit_cells(grid, side, standing_cell, zone_cells, blocked_fn)


## Drop tile fairness, part 2 (rule 6): may the cell a unit stands on be chosen? Only when the unit can step off in
## time: not Frozen ([param frozen]), not rooted ([param rooted]) and its step cooldown left ([param cooldown_left],
## mire already folded in by UnitMover) is at most [param warn_sec] - [param margin_sec] (combat.json
## `zones.hole_warn_sec` - `zones.hole_reaction_margin_sec`, 0.8 - 0.2 = 0.6 s shipped).
static func unit_cell_droppable(
	cooldown_left: float, warn_sec: float, margin_sec: float, frozen: bool, rooted: bool
) -> bool:
	if frozen or rooted:
		return false
	return cooldown_left <= warn_sec - margin_sec + _EPS


## THE single code point that starts a drop tile (Ô rớt): drops the unit's own cell unless [param unit_cell_ok]
## (from [method unit_cell_droppable]), fits the rest with [method fit_drop_cells] (blocked = cracking cells, holes
## and [param extra_blocked], the unit's mover blockers) and starts the crack with [method StatusEffects.apply_drop]
## ([param warn_sec] warning, [param hole_sec] hole). Returns the cells that started cracking (empty = no cast).
static func cast_drop(
	state: CombatState, grid: BoardGrid, status: StatusEffects, side: int, zone_cells: Array[Vector2i],
	warn_sec: float, hole_sec: float, unit_cell_ok: bool, extra_blocked: Callable = Callable()
) -> Array[Vector2i]:
	var standing: Vector2i = state.cell_of(side)
	var wanted: Array[Vector2i] = []
	for cell: Vector2i in zone_cells:
		if wanted.has(cell) or status.is_cracking(side, cell) or status.is_hole(side, cell):
			continue
		# P2.2b: every footprint cell of a multi-cell boss is "the unit's own cell".
		if state.unit_at(side, cell) and not unit_cell_ok:
			continue
		var on_half: bool = grid.is_player_cell(cell) if side == CombatState.Side.PLAYER else grid.is_enemy_cell(cell)
		if on_half:
			wanted.append(cell)
	var blocked: Callable = func(cell: Vector2i) -> bool:
		return status.is_cracking(side, cell) or status.is_hole(side, cell) \
			or (extra_blocked.is_valid() and bool(extra_blocked.call(cell)))
	var kept: Array[Vector2i] = fit_drop_cells(grid, side, standing, wanted, blocked)
	# fit_cells may leave only the unit's own cell: still a legal crack (a safe neighbour stays open).
	if kept.is_empty():
		return kept
	return status.apply_drop(side, kept, warn_sec, hole_sec)


## Forms a thorn zone (never reduced: thorn cells stay steppable), the one call thorn traits and cards use. Returns
## the cells that hold thorns now (deduplicated, input order; locked cells skipped by StatusEffects.apply_thorns).
static func cast_thorns(
	status: StatusEffects, side: int, zone_cells: Array[Vector2i], duration: float, damage: float, fragile_stacks: int
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in zone_cells:
		if not cells.has(cell):
			cells.append(cell)
	# Quick spec 2026-11-01: locked cells are skipped, another zone on a cell is replaced (StatusEffects._claim_zone_cell).
	return status.apply_thorns(side, cells, duration, damage, fragile_stacks)


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

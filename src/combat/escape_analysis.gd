class_name EscapeAnalysis
extends RefCounted
## Pure helpers for "where can a unit still get to in time": BFS reachability on one half of the
## board and the number of steps that fit into a swing's wind-up. No state, no nodes.
## Implements: Story 013 (escape-route scoring input).

## A step that would finish within this many seconds of the impact is not counted (it lands
## at, not before, the swing's resolution).
const IMPACT_EPSILON_SEC: float = 0.001
const _DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Every cell reachable from [param from_cell] in AT MOST [param steps] 4-way moves while staying
## on the owner's half (player's half when [param own_side_is_player]), through real cells only
## and never entering [param blocked]. [param from_cell] is always included (distance 0), even
## if it is itself blocked or not a cell of that half. Breadth-first; order = nearest first.
static func reachable_cells(
	grid: BoardGrid, from_cell: Vector2i, steps: int, own_side_is_player: bool,
	blocked: Array[Vector2i] = []
) -> Array[Vector2i]:
	var result: Array[Vector2i] = [from_cell]
	var dist: Dictionary = {from_cell: 0}
	var queue: Array[Vector2i] = [from_cell]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var d: int = int(dist[cell])
		if d >= steps:
			continue
		for dir: Vector2i in _DIRECTIONS:
			var next: Vector2i = cell + dir
			if dist.has(next) or blocked.has(next):
				continue
			var on_half: bool = grid.is_player_cell(next) if own_side_is_player else grid.is_enemy_cell(next)
			if not on_half:
				continue
			dist[next] = d + 1
			result.append(next)
			queue.append(next)
	return result


## The reachable cells (see [method reachable_cells]) that are NOT in [param covered].
static func escape_cells(
	grid: BoardGrid, from_cell: Vector2i, steps: int, own_side_is_player: bool,
	covered: Array[Vector2i], blocked: Array[Vector2i] = []
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in reachable_cells(grid, from_cell, steps, own_side_is_player, blocked):
		if not covered.has(cell):
			result.append(cell)
	return result


## Steps a unit can make before a swing of [param duration_sec] resolves. The mover starts
## ready, so the first step is available now and each further step needs one full
## [param step_cooldown_sec]: 1 + floor((duration - epsilon) / cooldown). A step finishing
## exactly at impact does not count. A cooldown <= 0 is treated as no steps (0), as is a
## negative duration.
static func steps_for_swing(duration_sec: float, step_cooldown_sec: float) -> int:
	if step_cooldown_sec <= 0.0 or duration_sec < 0.0:
		return 0
	return 1 + maxi(int(floor((duration_sec - IMPACT_EPSILON_SEC) / step_cooldown_sec)), 0)

class_name AttackShape
extends RefCounted
## Pure resolver for attack shapes: a shape is a list of (dx,dy) offsets relative to the
## attacker, where +dx means "toward the opponent". [param facing] is +1 for a unit facing
## +col (the player) and -1 for one facing -col (the boss, Story 008). Cells that are not on
## [param grid] (off the board or missing) are dropped. No scene dependency.
## Implements: Story 006.

## Absolute board cells covered by [param offsets] from [param origin] (non-board cells removed).
static func resolve(grid: BoardGrid, offsets: Array[Vector2i], origin: Vector2i, facing: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var dir: int = -1 if facing < 0 else 1
	for offset: Vector2i in offsets:
		var cell := Vector2i(origin.x + offset.x * dir, origin.y + offset.y)
		if grid.is_in_board(cell) and not cells.has(cell):
			cells.append(cell)
	return cells


## True if [param target] is among the resolved cells.
static func hits(grid: BoardGrid, offsets: Array[Vector2i], origin: Vector2i, facing: int, target: Vector2i) -> bool:
	return resolve(grid, offsets, origin, facing).has(target)

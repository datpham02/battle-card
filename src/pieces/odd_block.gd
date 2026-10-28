class_name OddBlock
extends RefCounted
## Story 041 "Khoi La" generator (pure, static): a random edge-connected polyomino of a weighted size,
## never equivalent (under 90-degree rotation) to a shape of pieces.json, that fits the target half.
## Draws only from the RNG it is given (the caller's own odd RNG), so other systems' sequences are
## untouched. Implements: Story 041 (Part A).

const _STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## A new odd piece for the target half of [param grid] ([param target_is_enemy] true = the boss's half,
## false = the player's half), or null when [param cfg] allows no size there or [member OddBlockConfig.max_tries]
## tries all fail. Each try: draw a size by weight among [method OddBlockConfig.allowed_sizes], grow a
## polyomino from (0,0) by adding a random free neighbour of a random cell, reject it when
## [method PieceLibrary.has_equivalent_shape] or when [method PiecePlacement.has_any_placement] is false.
## The piece is [code]Piece.make(Piece.ODD_PREFIX + canonical_key, cells, random rotation)[/code].
static func generate(
	library: PieceLibrary, grid: BoardGrid, target_is_enemy: bool, cfg: OddBlockConfig, rng: RandomNumberGenerator
) -> Piece:
	if grid == null or cfg == null or rng == null:
		return null
	var target_cells: int = grid.enemy_cells().size() if target_is_enemy else grid.player_cells().size()
	var sizes: Array[int] = cfg.allowed_sizes(target_cells)
	if sizes.is_empty():
		return null
	for _try: int in cfg.max_tries:
		var cells: Array[Vector2i] = grow(_pick_size(sizes, cfg, rng), rng)
		if library != null and library.has_equivalent_shape(cells):
			continue
		var key: String = Piece.canonical_key(cells)
		var piece: Piece = Piece.make(Piece.ODD_PREFIX + key, cells)
		if not PiecePlacement.has_any_placement(grid, piece, target_is_enemy):
			continue
		return piece.rotated(rng.randi_range(0, 3))
	return null


## A random edge-connected polyomino of [param size] cells grown from (0,0) (normalised, sorted).
static func grow(size: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var shape: Array[Vector2i] = [Vector2i.ZERO]
	while shape.size() < size:
		var base: Vector2i = shape[rng.randi_range(0, shape.size() - 1)]
		var free: Array[Vector2i] = []
		for step: Vector2i in _STEPS:
			if not shape.has(base + step):
				free.append(base + step)
		if free.is_empty():
			continue
		shape.append(free[rng.randi_range(0, free.size() - 1)])
	return Piece.make("", shape).relative_cells()


# Weighted pick among [param sizes] (all have weight > 0).
static func _pick_size(sizes: Array[int], cfg: OddBlockConfig, rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for size: int in sizes:
		total += cfg.weight_of(size)
	var roll: float = rng.randf() * total
	for size: int in sizes:
		roll -= cfg.weight_of(size)
		if roll < 0.0:
			return size
	return sizes[sizes.size() - 1]

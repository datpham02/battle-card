extends SceneTree
## Story 028 Part B: the featured shape of EVERY arena shape in arenas.json: 5-7 cells, edge-connected,
## >= 2 distinct piece pairs, a valid bonus, placeable on the enemy half of the base board; on seeded
## variants (seeds 0..VARIANT_SEEDS-1): placeable on every variant of the FULL_COVERAGE shapes, and on
## the others the match turns the feature off exactly when it does not fit (featured_for_match with the
## grid). Plus the chapters.json match overrides. Headless; FAILS=N.

## Seeds of ArenaVariants.make checked per shape (deterministic).
const VARIANT_SEEDS: int = 100
## Shapes whose featured shape fits EVERY variant (checked exhaustively over all hole toggles when the
## data was chosen). The small boards (square, cross, u_shape, islands_bridge, staircase) have variants
## too small for any 5-cell shape that two pieces can tile in >= 2 ways; there the feature is off.
const FULL_COVERAGE: Array[String] = ["rect", "ring", "diamond", "cross_wide", "pillars"]
## Lowest share of seeded variants that must still hold the featured shape on the other boards.
const MIN_COVERAGE: float = 0.6
const EXPECTED_SHAPES: int = 19  # Story 036: + bog, reed_maze, dunes, oasis; Story 039: + forge, caldera, twin_isles, three_isles

var fails: int = 0


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _init() -> void:
	var arenas: ArenaLibrary = ArenaLibrary.load_from_file()
	var pieces: PieceLibrary = PieceLibrary.load_from_file()
	ck("arenas.json has %d shapes" % EXPECTED_SHAPES, arenas.shape_ids().size() == EXPECTED_SHAPES)
	for id: String in arenas.shape_ids():
		_check_shape(arenas, pieces, id)
	_test_match_overrides(arenas)
	print("FAILS=%d" % fails)
	quit(fails)


func _connected(cells: Array[Vector2i]) -> bool:
	var seen: Array[Vector2i] = [cells[0]]
	var frontier: Array[Vector2i] = [cells[0]]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cells.has(cur + step) and not seen.has(cur + step):
				seen.append(cur + step)
				frontier.append(cur + step)
	return seen.size() == cells.size()


func _check_shape(arenas: ArenaLibrary, pieces: PieceLibrary, id: String) -> void:
	var f: Dictionary = arenas.featured_for_shape(id)
	ck("%s: has a featured shape" % id, not f.is_empty())
	if f.is_empty():
		return
	var cells: Array[Vector2i] = f["cells"]
	ck("%s: 5-7 cells (%d)" % [id, cells.size()], cells.size() >= 5 and cells.size() <= 7)
	ck("%s: edge-connected" % id, _connected(cells))
	var pairs: Array = FeaturedShape.pair_compositions(pieces, cells)
	ck("%s: >= 2 distinct piece pairs (%d: %s)" % [id, pairs.size(), pairs], pairs.size() >= 2)
	var bonus: Dictionary = f["bonus"]
	var effect: String = str(bonus["effect"])
	ck("%s: damage_mult 1.5" % id, is_equal_approx(float(bonus["damage_mult"]), 1.5))
	ck("%s: effect %s is known" % [id, effect], ArenaLibrary.FEATURED_EFFECTS.has(effect))
	if effect == "pin":
		ck("%s: pin uses sec > 0, stacks 0" % id, float(bonus["sec"]) > 0.0 and int(bonus["stacks"]) == 0)
	else:
		ck("%s: %s uses stacks 1..2, sec 0" % [id, effect], int(bonus["stacks"]) >= 1 and int(bonus["stacks"]) <= 2 and float(bonus["sec"]) == 0.0)
	var piece: Piece = Piece.make("featured", cells)
	var base_grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": id}, arenas, 0)
	ck("%s: placeable on the enemy half of the base board" % id, PiecePlacement.has_any_placement(base_grid, piece))
	var fits: int = 0
	var off_matches_fit: bool = true
	for seed_value: int in VARIANT_SEEDS:
		var grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": id, "variant": true}, arenas, seed_value)
		var fit: bool = PiecePlacement.has_any_placement(grid, piece)
		if fit:
			fits += 1
		var resolved: Dictionary = arenas.featured_for_match({"arena": {"shape": id, "variant": true}}, grid)
		off_matches_fit = off_matches_fit and (resolved.is_empty() != fit)
	var share: float = float(fits) / float(VARIANT_SEEDS)
	print("  %s: featured fits %d/%d seeded variants" % [id, fits, VARIANT_SEEDS])
	if FULL_COVERAGE.has(id):
		ck("%s: placeable on every seeded variant" % id, fits == VARIANT_SEEDS)
	else:
		ck("%s: placeable on >= %.0f%% of seeded variants (%.2f)" % [id, MIN_COVERAGE * 100.0, share], share >= MIN_COVERAGE)
	ck("%s: featured_for_match(grid) is off exactly when the shape does not fit" % id, off_matches_fit)


func _test_match_overrides(arenas: ArenaLibrary) -> void:
	var base: Dictionary = arenas.featured_for_shape("cross")
	var m: Dictionary = arenas.featured_for_match({"arena": {"shape": "cross"}})
	ck("match: arena.shape resolves the shape's featured", m["cells"] == base["cells"] and m["bonus"] == base["bonus"])
	var bar5: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	var o: Dictionary = arenas.featured_for_match({
		"arena": {"shape": "cross"}, "featured_shape": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]],
		"featured_bonus": {"effect": "pin", "sec": 2.0, "stacks": 0}})
	ck("match override: featured_shape replaces the cells", o["cells"] == bar5)
	ck("match override: bonus keys override one by one (damage_mult kept)", str(o["bonus"]["effect"]) == "pin" and is_equal_approx(float(o["bonus"]["sec"]), 2.0) and is_equal_approx(float(o["bonus"]["damage_mult"]), 1.5))
	var bad: Dictionary = arenas.featured_for_match({"arena": {"shape": "cross"}, "featured_shape": [[0, 0], [1, 0], [2, 0], [3, 0]]})
	ck("match override: an invalid (4-cell) featured_shape is ignored", bad["cells"] == base["cells"])
	ck("match: no arena and no override = feature off", arenas.featured_for_match({}).is_empty())
	ck("match: unknown shape = feature off", arenas.featured_for_match({"arena": {"shape": "nope"}}).is_empty())
	var direct: Dictionary = arenas.featured_for_match({"arena": {"side_cols": 3, "side_rows": 3},
		"featured_shape": [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1]], "featured_bonus": {"damage_mult": 1.5, "effect": "frost", "stacks": 1}})
	ck("match: a direct arena block can carry its own featured shape + bonus", not direct.is_empty() and str(direct["bonus"]["effect"]) == "frost")
	ck("parse: a disconnected shape is invalid", ArenaLibrary.parse_featured_cells([[0, 0], [1, 0], [3, 0], [4, 0], [5, 0]]).is_empty())
	ck("parse: 8 cells is invalid", ArenaLibrary.parse_featured_cells([[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0], [7, 0]]).is_empty())
	ck("parse: an unknown effect is invalid", ArenaLibrary.parse_featured_bonus({"effect": "poison"}).is_empty())

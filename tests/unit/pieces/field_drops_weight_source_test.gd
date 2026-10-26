extends SceneTree
## Story 034 Part A/D: FieldDrops.enable_pieces with an injected weight source (Dictionary or
## Callable): distribution over 10 000 seeded draws within 2 percentage points, the zero-weight
## rule, the default source (boss path) unchanged and never giving run_only shapes. Headless and
## deterministic. Prints FAILS=N.

const DRAWS: int = 10000
const TOLERANCE_PERCENT: float = 2.0

var fails: int = 0
var lib: PieceLibrary
var cfg: PieceDeckConfig


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _init() -> void:
	lib = PieceLibrary.load_from_file()
	cfg = PieceDeckConfig.load_from_file()
	_test_default_source_unchanged()
	_test_player_distribution()
	_test_callable_source()
	_test_zero_weight_rule()
	_test_start_pieces_use_source()
	_test_dictionary_is_copied()
	print("FAILS=%d" % fails)
	quit(fails)


func _config() -> FieldDropsConfig:
	var c := FieldDropsConfig.new()
	c.initial_delay_sec = 0.0
	c.piece_spawn_interval_sec = 0.01
	c.piece_max_on_field = 3
	c.piece_freshness_sec = 4.0
	c.start_pieces = 1
	return c


# Draws [param n] pieces (one per tick, each picked up at once); returns ["shape:rotation", ...].
func _draw(drops: FieldDrops, grid: BoardGrid, n: int) -> Array[String]:
	var out: Array[String] = []
	var stand: Vector2i = grid.default_player_cell()
	while out.size() < n:
		drops.tick(0.02, stand, 0)
		for p: FieldPoint in drops.get_points():
			out.append("%s:%d" % [p.piece.shape_id, p.piece.rotation])
			drops.pick_up_at(p.cell, true)
	return out


func _counts(draws: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for entry: String in draws:
		var id: String = entry.split(":")[0]
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


# True when every id's share of [param draws] is within the tolerance of [param expected] (percent).
func _matches(draws: Array[String], expected: Dictionary) -> bool:
	var counts: Dictionary = _counts(draws)
	for id: Variant in counts.keys():
		if not expected.has(id):
			print("  unexpected shape drawn: %s" % id)
			return false
	for id: Variant in expected.keys():
		var share: float = 100.0 * float(counts.get(id, 0)) / float(draws.size())
		if absf(share - float(expected[id])) > TOLERANCE_PERCENT:
			print("  %s: drew %.2f%%, expected %.2f%%" % [id, share, float(expected[id])])
			return false
	return true


func _drops(grid: BoardGrid, seed_value: int, source: Variant, target_is_enemy: bool = true) -> FieldDrops:
	var drops := FieldDrops.new(_config(), grid.player_cells(), seed_value)
	drops.enable_pieces(lib, "ch1", grid, seed_value, target_is_enemy, source)
	return drops


func _test_default_source_unchanged() -> void:
	var grid := BoardGrid.new(5, 5)
	var base: Array[String] = _draw(_drops(grid, 5, null), grid, 600)
	var explicit_null: FieldDrops = FieldDrops.new(_config(), grid.player_cells(), 5)
	explicit_null.enable_pieces(lib, "ch1", grid, 5)
	ck("no source = the same sequence as the old signature", base == _draw(explicit_null, grid, 600))
	var table: Dictionary = {}
	for id: String in lib.base_shape_ids():
		table[id] = lib.weight(id, "ch1")
	ck("a Dictionary holding the library weights draws the identical sequence",
		base == _draw(_drops(grid, 5, table), grid, 600))
	var by_call: Callable = func(id: String) -> float: return lib.weight(id, "ch1")
	ck("a Callable returning the library weights draws the identical sequence",
		base == _draw(_drops(grid, 5, by_call), grid, 600))
	# The boss path (player half as target, no source): library weights, never a run_only shape.
	var boss: Array[String] = _draw(_drops(grid, 9, null, false), grid, DRAWS)
	var total: float = 0.0
	for id: String in lib.base_shape_ids():
		total += lib.weight(id, "ch1")
	var expected: Dictionary = {}
	for id: String in lib.base_shape_ids():
		expected[id] = 100.0 * lib.weight(id, "ch1") / total
	ck("boss path: distribution follows the original chapter weights", _matches(boss, expected))
	var counts: Dictionary = _counts(boss)
	ck("boss path: run_only shapes never drop", not (counts.has("z4") or counts.has("j4") or counts.has("y5")))
	var drawable: FieldDrops = _drops(grid, 9, null, false)
	ck("boss path: run_only shapes are not drawable", drawable.get_drawable_shapes().size() == 13)


func _test_player_distribution() -> void:
	var grid := BoardGrid.new(5, 5)
	var deck: Dictionary = PieceDeck.initial(lib)
	deck = PieceDeck.remove(deck, "mono", lib, cfg)
	deck = PieceDeck.apply_ink(deck, "bar2", lib, cfg)
	deck = PieceDeck.apply_ink(deck, "bar2", lib, cfg) # mult 3
	deck = PieceDeck.apply_ink(deck, "y5", lib, cfg)
	var match_info: Dictionary = PieceDeck.weights_for_match(deck, lib, "ch1", grid, cfg)
	ck("roomy arena: no fallback", not bool(match_info["fallback"]))
	var weights: Dictionary = match_info["weights"]
	var drops: FieldDrops = _drops(grid, 77, weights)
	ck("a removed shape (mono) is not drawable", not drops.get_drawable_shapes().has("mono"))
	ck("an owned run_only shape (y5) is drawable", drops.get_drawable_shapes().has("y5"))
	ck("a not-owned run_only shape (z4) is not drawable", not drops.get_drawable_shapes().has("z4"))
	var draws: Array[String] = _draw(drops, grid, DRAWS)
	ck("%d seeded draws follow the deck weights within %.0f points" % [DRAWS, TOLERANCE_PERCENT],
		_matches(draws, PieceDeck.drop_percent(weights)))
	var counts: Dictionary = _counts(draws)
	ck("y5 and bar2 (x3) really drop, mono never", int(counts.get("y5", 0)) > 0
		and int(counts.get("bar2", 0)) > int(counts.get("bar3", 0)) and not counts.has("mono"))
	var again: Array[String] = _draw(_drops(grid, 77, weights), grid, 300)
	ck("the same seed gives the same sequence", again == draws.slice(0, 300))
	var rotations: Dictionary = {}
	for entry: String in draws:
		rotations[entry.split(":")[1]] = true
	ck("rotations are still drawn (0..3)", rotations.size() == 4)


func _test_callable_source() -> void:
	var grid := BoardGrid.new(5, 5)
	var source: Callable = func(id: String) -> float:
		return 1.0 if id == "bar2" else (3.0 if id == "square" else 0.0)
	var drops: FieldDrops = _drops(grid, 3, source)
	ck("only shapes with weight are drawable", drops.get_drawable_shapes().size() == 2)
	ck("Callable source: 25 / 75 split within tolerance",
		_matches(_draw(drops, grid, DRAWS), {"bar2": 25.0, "square": 75.0}))


func _test_zero_weight_rule() -> void:
	var grid := BoardGrid.new(5, 5)
	var all_zero: FieldDrops = _drops(grid, 4, {})
	ck("every weight 0: all fitting shapes are drawable (uniform, as before)",
		all_zero.get_drawable_shapes().size() == lib.shape_ids().size())
	var uniform: Array[String] = _draw(all_zero, grid, DRAWS)
	var expected: Dictionary = {}
	for id: String in lib.shape_ids():
		expected[id] = 100.0 / float(lib.shape_ids().size())
	ck("every weight 0: draws are uniform over the fitting shapes", _matches(uniform, expected))
	# A shape with weight that does not fit is skipped; zero-weight fitting ones stay out.
	var narrow := BoardGrid.new(2, 3)
	var drops: FieldDrops = _drops(narrow, 4, {"bar5": 5.0, "mono": 1.0, "bar2": 0.0})
	var only_mono: Array[String] = ["mono"]
	ck("a weighted shape that does not fit is not drawable; zero-weight ones are out",
		drops.get_drawable_shapes() == only_mono)
	var none_fit: FieldDrops = _drops(narrow, 4, {"bar5": 5.0})
	ck("only non-fitting shapes weighted: every fitting shape is drawable uniformly",
		none_fit.get_drawable_shapes().has("mono") and not none_fit.get_drawable_shapes().has("bar5"))
	var junk: FieldDrops = _drops(grid, 4, 42)
	ck("a source that is neither Dictionary nor Callable is ignored (library weights)",
		junk.get_drawable_shapes().size() == 13)


func _test_start_pieces_use_source() -> void:
	var grid := BoardGrid.new(5, 5)
	var c: FieldDropsConfig = _config()
	c.start_pieces = 3
	var drops := FieldDrops.new(c, grid.player_cells(), 8)
	drops.enable_pieces(lib, "ch1", grid, 8, true, {"bar3": 1.0})
	var placed: int = drops.place_start_pieces(grid.default_player_cell())
	var all_bar3: bool = placed == 3
	for p: FieldPoint in drops.get_points():
		all_bar3 = all_bar3 and p.piece.shape_id == "bar3"
	ck("start pieces are drawn by the injected source", all_bar3)


func _test_dictionary_is_copied() -> void:
	var grid := BoardGrid.new(5, 5)
	var source: Dictionary = {"bar3": 1.0}
	var drops: FieldDrops = _drops(grid, 8, source)
	source["mono"] = 1000.0
	source["bar3"] = 0.0
	var draws: Array[String] = _draw(drops, grid, 200)
	ck("changing the dictionary afterwards does not change the draws",
		_counts(draws).size() == 1 and _counts(draws).has("bar3"))

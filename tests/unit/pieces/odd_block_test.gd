extends SceneTree
## Story 041 Part A/F: the odd block generator (OddBlock), its config (OddBlockConfig), Piece.canonical_key and
## PieceLibrary.has_equivalent_shape. Headless and deterministic (fixed seeds). Prints PASS/FAIL lines and FAILS=N.

const SEEDS: int = 60
const ARENA_SEEDS: int = 12
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var fails: int = 0
var lib: PieceLibrary
var arenas: ArenaLibrary
var file_cfg: OddBlockConfig


func ck(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name + ("" if extra.is_empty() else " " + extra))


func _init() -> void:
	lib = PieceLibrary.load_from_file()
	arenas = ArenaLibrary.load_from_file()
	file_cfg = FieldDropsConfig.load_from_file().odd
	_test_canonical_key()
	_test_library_equivalence()
	_test_config()
	_test_generate_basic()
	_test_islands_and_holes()
	_test_determinism()
	_test_exhaustion()
	_test_max_size_all_arenas()
	_test_disabled()
	print("FAILS=%d" % fails)
	quit(fails)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _grid(shape_id: String) -> BoardGrid:
	return ArenaValidator.build_grid(arenas.get_shape(shape_id))


func _connected(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var seen: Array[Vector2i] = [cells[0]]
	var frontier: Array[Vector2i] = [cells[0]]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_back()
		for step: Vector2i in STEPS:
			if cells.has(cur + step) and not seen.has(cur + step):
				seen.append(cur + step)
				frontier.append(cur + step)
	return seen.size() == cells.size()


func _test_canonical_key() -> void:
	var l_shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
	var j_shape: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2)]
	var key: String = Piece.canonical_key(l_shape)
	var same: bool = true
	for turns: int in 4:
		var turned: Array[Vector2i] = Piece.make("x", l_shape, turns).relative_cells()
		var shifted: Array[Vector2i] = []
		for c: Vector2i in turned:
			shifted.append(c + Vector2i(7, -3))
		same = same and Piece.canonical_key(shifted) == key
	ck("canonical_key is rotation and translation invariant", same, key)
	ck("canonical_key keeps chirality (L != J)", Piece.canonical_key(j_shape) != key)
	ck("canonical_key of an empty set is empty", Piece.canonical_key([] as Array[Vector2i]) == "")
	var odd := Piece.make(Piece.ODD_PREFIX + key, l_shape, 1)
	ck("is_odd on the prefix, rotated keeps id", odd.is_odd() and odd.rotated(2).shape_id == odd.shape_id and odd.rotated().is_odd())
	ck("a library piece is not odd", not lib.make_piece(lib.shape_ids()[0]).is_odd())


func _test_library_equivalence() -> void:
	var all_ok: bool = true
	for id: String in lib.shape_ids():
		for turns: int in 4:
			if not lib.has_equivalent_shape(lib.make_piece(id, turns).relative_cells()):
				all_ok = false
	ck("every library shape (both pools, every rotation) is equivalent to itself", all_ok)
	ck("the library has run_only shapes to check against", not lib.run_only_ids().is_empty())
	var plus: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(1, 3)]
	ck("a 6-cell shape is never equivalent", not lib.has_equivalent_shape(plus))


func _test_config() -> void:
	ck("file block: chance 0.12 (Story 041 tuning), min 5, weights 6/3/1, tries 40",
		is_equal_approx(file_cfg.chance, 0.12) and file_cfg.min_cells == 5 and is_equal_approx(file_cfg.weight_of(5), 6.0)
		and is_equal_approx(file_cfg.weight_of(6), 3.0) and is_equal_approx(file_cfg.weight_of(7), 1.0) and file_cfg.max_tries == 40)
	ck("a config without the block is off", FieldDropsConfig.from_dictionary({}).odd.chance == 0.0)
	var c: OddBlockConfig = OddBlockConfig.from_dictionary({"chance": 3.0, "min_cells": 0, "size_divisor": 0, "size_min": 0,
		"size_max": -2, "max_tries": 0, "size_weights": {"5": -1, "6": 2}})
	ck("clamps chance, min_cells, divisor, size_min, size_max, tries",
		c.chance == 1.0 and c.min_cells == 1 and c.size_divisor == 1 and c.size_min == 1 and c.size_max == 1 and c.max_tries == 1)
	ck("negative weight -> 0, missing size -> 0", c.weight_of(5) == 0.0 and c.weight_of(6) == 2.0 and c.weight_of(7) == 0.0)
	var fd: FieldDropsConfig = FieldDropsConfig.load_from_file()
	var cp: FieldDropsConfig = fd.copy()
	cp.odd.chance = 0.9
	cp.odd.size_weights[5] = 99.0
	ck("FieldDropsConfig.copy deep-copies odd", is_equal_approx(fd.odd.chance, 0.12) and is_equal_approx(fd.odd.weight_of(5), 6.0))
	var merged: OddBlockConfig = fd.odd.with_overrides({"chance": 0.0})
	ck("with_overrides merges over the block", merged.chance == 0.0 and merged.min_cells == 5 and is_equal_approx(merged.weight_of(6), 3.0))


func _test_generate_basic() -> void:
	var grid: BoardGrid = _grid("pillars") # 25 - 4 holes = 21 cells
	var max_size: int = file_cfg.max_size_for(grid.enemy_cells().size())
	var ok_conn: bool = true
	var ok_size: bool = true
	var ok_new: bool = true
	var ok_fit: bool = true
	var ok_id: bool = true
	var made: int = 0
	var sizes: Dictionary = {}
	for s: int in SEEDS:
		var p: Piece = OddBlock.generate(lib, grid, true, file_cfg, _rng(1000 + s))
		if p == null:
			continue
		made += 1
		var cells: Array[Vector2i] = p.relative_cells()
		sizes[cells.size()] = int(sizes.get(cells.size(), 0)) + 1
		ok_conn = ok_conn and _connected(cells)
		ok_size = ok_size and cells.size() >= file_cfg.min_cells and cells.size() <= max_size
		ok_new = ok_new and not lib.has_equivalent_shape(cells)
		ok_fit = ok_fit and PiecePlacement.has_any_placement(grid, p, true)
		ok_id = ok_id and p.is_odd() and p.shape_id == Piece.ODD_PREFIX + Piece.canonical_key(cells)
	ck("pillars: generated a piece for every seed", made == SEEDS, "%d/%d sizes %s" % [made, SEEDS, sizes])
	ck("connected", ok_conn)
	ck("size in [min_cells, max_size=%d]" % max_size, ok_size)
	ck("never equivalent to a library shape", ok_new)
	ck("fits the enemy half", ok_fit)
	ck("id = odd: + canonical key", ok_id)
	ck("sizes 5, 6 and 7 all appear on a 21-cell half", sizes.has(5) and sizes.has(6) and sizes.has(7))
	# Player half target (the boss side).
	var p2: Piece = OddBlock.generate(lib, grid, false, file_cfg, _rng(5))
	ck("boss side: fits the PLAYER half", p2 != null and PiecePlacement.has_any_placement(grid, p2, false))


func _test_islands_and_holes() -> void:
	for shape_id: String in ["twin_isles", "three_isles", "ring", "staircase", "square", "islands_bridge"]:
		var grid: BoardGrid = _grid(shape_id)
		var n: int = grid.enemy_cells().size()
		var made: int = 0
		var ok: bool = true
		for s: int in ARENA_SEEDS:
			for target_enemy: bool in [true, false]:
				var p: Piece = OddBlock.generate(lib, grid, target_enemy, file_cfg, _rng(77 + s))
				if p == null:
					continue
				made += 1
				var cells: Array[Vector2i] = p.relative_cells()
				ok = ok and _connected(cells) and not lib.has_equivalent_shape(cells) \
					and cells.size() <= file_cfg.max_size_for(n) and PiecePlacement.has_any_placement(grid, p, target_enemy)
		ck("%s (%d cells): every odd piece fits, new, sized" % [shape_id, n], ok and made > 0, "made %d/%d" % [made, ARENA_SEEDS * 2])


func _test_determinism() -> void:
	var grid: BoardGrid = _grid("cross_wide")
	var same: bool = true
	for s: int in 10:
		var a: Piece = OddBlock.generate(lib, grid, true, file_cfg, _rng(s))
		var b: Piece = OddBlock.generate(lib, grid, true, file_cfg, _rng(s))
		same = same and a != null and b != null and a.shape_id == b.shape_id and a.rotation == b.rotation
	ck("same seed -> same piece and rotation", same)
	var ids: Dictionary = {}
	for s: int in 20:
		ids[OddBlock.generate(lib, grid, true, file_cfg, _rng(s)).shape_id] = true
	ck("different seeds give different shapes", ids.size() > 5, "%d distinct" % ids.size())


func _test_exhaustion() -> void:
	# Only size 1..4 allowed: every grown shape duplicates the library, so every try fails.
	var dup: OddBlockConfig = OddBlockConfig.from_dictionary({"chance": 1.0, "min_cells": 1, "size_weights": {"4": 1}, "max_tries": 7})
	var rng := _rng(3)
	var p: Piece = OddBlock.generate(lib, _grid("pillars"), true, dup, rng)
	ck("max_tries exhausted -> null", p == null)
	# A 2x2 target half (4 cells) cannot hold any 5-cell piece: placement rejects every try.
	var tiny := BoardGrid.new(2, 2)
	var forced: OddBlockConfig = OddBlockConfig.from_dictionary({"chance": 1.0, "size_min": 5, "size_max": 5, "max_tries": 5})
	ck("nothing fits a 2x2 half -> null", OddBlock.generate(lib, tiny, true, forced, _rng(4)) == null)


func _test_max_size_all_arenas() -> void:
	ck("spec examples 9->5, 10->5, 11->5, 12->6, 15->6, 16->7, 17->7, 30->7",
		file_cfg.max_size_for(9) == 5 and file_cfg.max_size_for(10) == 5 and file_cfg.max_size_for(11) == 5
		and file_cfg.max_size_for(12) == 6 and file_cfg.max_size_for(15) == 6 and file_cfg.max_size_for(16) == 7
		and file_cfg.max_size_for(17) == 7 and file_cfg.max_size_for(30) == 7)
	var ids: Array[String] = arenas.shape_ids()
	ck("19 arena shapes", ids.size() == 19, str(ids.size()))
	var all_ok: bool = true
	var table: PackedStringArray = []
	for shape_id: String in ids:
		var grid: BoardGrid = _grid(shape_id)
		var n: int = grid.enemy_cells().size()
		var expected: int = 5 if n < 12 else (6 if n < 16 else 7)
		if n < 8:
			expected = 4
		var got: int = file_cfg.max_size_for(n)
		var enabled: bool = file_cfg.is_enabled_for(n)
		all_ok = all_ok and got == expected and enabled == (expected >= 5) and grid.player_cells().size() == n
		table.append("%s=%d:%d" % [shape_id, n, got])
		# Every arena with odd blocks on gets one within a few seeds.
		if enabled:
			var made: bool = false
			for s: int in 5:
				if OddBlock.generate(lib, grid, true, file_cfg, _rng(500 + s)) != null:
					made = true
					break
			ck("%s: an odd block can be generated" % shape_id, made)
	ck("max_size_for matches the formula on all arenas", all_ok, ", ".join(table))


func _test_disabled() -> void:
	var small: OddBlockConfig = OddBlockConfig.from_dictionary({"chance": 0.25, "size_max": 4})
	ck("size_max 4 < min_cells 5: no allowed size, disabled", small.allowed_sizes(30).is_empty() and not small.is_enabled_for(30))
	ck("disabled config generates null", OddBlock.generate(lib, _grid("pillars"), true, small, _rng(1)) == null)
	var off: OddBlockConfig = OddBlockConfig.from_dictionary({"chance": 0.0})
	ck("chance 0 is disabled even with sizes", not off.allowed_sizes(30).is_empty() and not off.is_enabled_for(30))
	var only7: OddBlockConfig = OddBlockConfig.from_dictionary({"chance": 0.5, "size_weights": {"7": 1}})
	ck("weights only on 7: off on a 9-cell half, on at 16", not only7.is_enabled_for(9) and only7.is_enabled_for(16))
	var drops := FieldDrops.new(_off_config(), _grid("square").player_cells(), 1)
	drops.enable_pieces(lib, "", _grid("square"), 1)
	ck("FieldDrops: odd off with a chance-0 config", not drops.is_odd_enabled() and drops.get_odd_max_size() == 0)
	var on_cfg := FieldDropsConfig.new()
	on_cfg.odd = file_cfg.copy()
	var drops2 := FieldDrops.new(on_cfg, _grid("square").player_cells(), 1)
	drops2.enable_pieces(lib, "", _grid("square"), 1)
	ck("FieldDrops: square (9 cells) odd on, max 5", drops2.is_odd_enabled() and drops2.get_odd_max_size() == 5)


func _off_config() -> FieldDropsConfig:
	return FieldDropsConfig.new()

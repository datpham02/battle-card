extends SceneTree
## Story 028 Part B: FeaturedShape.normalize / matches (4 rotations, any offset, no flip, size) and
## pair_compositions (distinct unordered piece pairs tiling a shape). Headless; FAILS=N.

var fails: int = 0


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Array in list:
		out.append(Vector2i(item[0], item[1]))
	return out


func _shift(cells: Array[Vector2i], by: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		out.append(c + by)
	return out


func _init() -> void:
	_test_normalize()
	_test_matches()
	_test_pairs()
	print("FAILS=%d" % fails)
	quit(fails)


func _test_normalize() -> void:
	var got: Array[Vector2i] = FeaturedShape.normalize(_cells([[5, 4], [3, 3], [4, 3], [3, 3]]))
	ck("normalize: shifts to origin, drops duplicates, sorts row by row", got == _cells([[0, 0], [1, 0], [2, 1]]))
	ck("normalize: empty stays empty", FeaturedShape.normalize([] as Array[Vector2i]).is_empty())


func _test_matches() -> void:
	# F pentomino .#./###/#.. is chiral: its mirror image must never match.
	var f: Array[Vector2i] = _cells([[1, 0], [0, 1], [1, 1], [2, 1], [0, 2]])
	var all_rot: bool = true
	for turns: int in 4:
		var cast: Array[Vector2i] = _shift(FeaturedShape.rotate_cells(f, turns), Vector2i(7, 3 + turns))
		all_rot = all_rot and FeaturedShape.matches(f, cast)
	ck("matches: all 4 rotations at any offset", all_rot)
	var mirrored: Array[Vector2i] = _cells([[1, 0], [0, 1], [1, 1], [2, 1], [2, 2]])
	var mirror_rejected: bool = true
	for turns: int in 4:
		mirror_rejected = mirror_rejected and not FeaturedShape.matches(f, FeaturedShape.rotate_cells(mirrored, turns))
	ck("matches: the mirrored (flipped) shape never matches", mirror_rejected)
	ck("matches: a different 5-cell shape (plus) is rejected", not FeaturedShape.matches(f, _cells([[1, 0], [0, 1], [1, 1], [2, 1], [1, 2]])))
	ck("matches: one cell fewer is rejected", not FeaturedShape.matches(f, _cells([[1, 0], [0, 1], [1, 1], [2, 1]])))
	ck("matches: one cell more is rejected", not FeaturedShape.matches(f, _cells([[1, 0], [0, 1], [1, 1], [2, 1], [0, 2], [0, 3]])))
	ck("matches: empty cast never matches", not FeaturedShape.matches(f, [] as Array[Vector2i]))


func _test_pairs() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	# P pentomino ###/##. : hand-counted tilings by two pieces.
	var p: Array[Vector2i] = _cells([[0, 0], [1, 0], [2, 0], [0, 1], [1, 1]])
	var expected: Array = [["bar2", "bar3"], ["bar2", "l3"], ["l4", "mono"], ["mono", "s4"], ["mono", "square"], ["mono", "t4"]]
	var got: Array = FeaturedShape.pair_compositions(lib, p)
	ck("pairs: P pentomino has the 6 hand-counted pairs (%s)" % [got], got == expected)
	ck("pairs: bar5 = bar2+bar3 or bar4+mono", FeaturedShape.pair_compositions(lib, _cells([[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]])) == [["bar2", "bar3"], ["bar4", "mono"]])
	ck("pairs: plus has only mono+t4", FeaturedShape.pair_compositions(lib, _cells([[1, 0], [0, 1], [1, 1], [2, 1], [1, 2]])) == [["mono", "t4"]])
	var big: Array[Vector2i] = _cells([[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]])
	var big_pairs: Array = FeaturedShape.pair_compositions(lib, big)
	ck("pairs: 2x3 block includes bar3+bar3 and bar2+square", big_pairs.has(["bar3", "bar3"]) and big_pairs.has(["bar2", "square"]))
	ck("pairs: a rotated shape gives the same pairs", FeaturedShape.pair_compositions(lib, FeaturedShape.rotate_cells(p, 1)) == expected)

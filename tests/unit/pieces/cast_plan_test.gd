extends SceneTree
## Story 028 Part A/C: CastPlan (max pieces, no overlap, cell cap, remove, union order, touches,
## is_featured only with two pieces). Headless; FAILS=N.

var fails: int = 0
var lib: PieceLibrary


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Array in list:
		out.append(Vector2i(item[0], item[1]))
	return out


func _init() -> void:
	lib = PieceLibrary.load_from_file()
	_test_add_and_limits()
	_test_cap()
	_test_remove_and_order()
	_test_touches()
	_test_featured()
	print("FAILS=%d" % fails)
	quit(fails)


func _test_add_and_limits() -> void:
	var plan: CastPlan = CastPlan.new().init(2, 0)
	ck("empty plan: 0 pieces, 0 cells, not full", plan.piece_count() == 0 and plan.total_cells() == 0 and not plan.is_full())
	ck("add bar3", plan.add_piece(0, lib.make_piece("bar3"), _cells([[3, 0], [4, 0], [5, 0]])))
	ck("overlapping second piece is refused", not plan.add_piece(1, lib.make_piece("bar2"), _cells([[5, 0], [5, 1]])))
	ck("refusal left the plan unchanged", plan.piece_count() == 1 and plan.total_cells() == 3)
	ck("separate second piece (not touching) is accepted", plan.add_piece(2, lib.make_piece("bar2"), _cells([[3, 2], [4, 2]])))
	ck("plan is full at 2 pieces", plan.is_full() and plan.piece_count() == 2 and plan.total_cells() == 5)
	ck("a third piece is refused (max 2)", not plan.add_piece(1, lib.make_piece("mono"), _cells([[3, 1]])))
	ck("slots in add order", plan.slots() == ([0, 2] as Array[int]))
	ck("pieces in add order", plan.pieces()[0].shape_id == "bar3" and plan.pieces()[1].shape_id == "bar2")
	ck("empty cells are refused", not CastPlan.new().init(2, 0).add_piece(0, lib.make_piece("mono"), [] as Array[Vector2i]))
	var one: CastPlan = CastPlan.new().init(1, 0)
	one.add_piece(0, lib.make_piece("mono"), _cells([[3, 0]]))
	ck("max_pieces 1: second piece refused", one.is_full() and not one.add_piece(1, lib.make_piece("mono"), _cells([[4, 0]])))


func _test_cap() -> void:
	var plan: CastPlan = CastPlan.new().init(2, 5)
	plan.add_piece(0, lib.make_piece("bar3"), _cells([[3, 0], [4, 0], [5, 0]]))
	ck("cap 5: 3 + 3 cells refused", not plan.add_piece(1, lib.make_piece("bar3"), _cells([[3, 1], [4, 1], [5, 1]])))
	ck("cap 5: 3 + 2 cells accepted (boundary)", plan.add_piece(1, lib.make_piece("bar2"), _cells([[3, 1], [4, 1]])) and plan.total_cells() == 5)
	var off: CastPlan = CastPlan.new().init(2, 0)
	off.add_piece(0, lib.make_piece("bar5"), _cells([[3, 0], [4, 0], [5, 0], [6, 0], [7, 0]]))
	ck("cap 0 = off: 5 + 5 cells accepted", off.add_piece(1, lib.make_piece("bar5"), _cells([[3, 1], [4, 1], [5, 1], [6, 1], [7, 1]])))


func _test_remove_and_order() -> void:
	var plan: CastPlan = CastPlan.new().init(2, 0)
	plan.add_piece(4, lib.make_piece("bar2"), _cells([[4, 2], [5, 2]]))
	plan.add_piece(1, lib.make_piece("l3"), _cells([[3, 0], [3, 1], [4, 1]]))
	ck("cells(): union sorted row by row", plan.cells() == _cells([[3, 0], [3, 1], [4, 1], [4, 2], [5, 2]]))
	ck("piece_cells(1) is the second piece", plan.piece_cells(1) == _cells([[3, 0], [3, 1], [4, 1]]))
	ck("piece_cells out of range is empty", plan.piece_cells(5).is_empty())
	ck("remove out of range fails", not plan.remove_piece(2) and not plan.remove_piece(-1))
	ck("remove index 0", plan.remove_piece(0) and plan.piece_count() == 1 and plan.slots() == ([1] as Array[int]))
	ck("after remove: not full, cells of the remaining piece", not plan.is_full() and plan.cells() == _cells([[3, 0], [3, 1], [4, 1]]))
	plan.clear()
	ck("clear empties the plan", plan.piece_count() == 0 and plan.cells().is_empty())


func _test_touches() -> void:
	var plan: CastPlan = CastPlan.new().init(2, 0)
	plan.add_piece(0, lib.make_piece("square"), _cells([[3, 0], [4, 0], [3, 1], [4, 1]]))
	ck("touches: edge contact", plan.touches(_cells([[5, 1], [6, 1]])))
	ck("touches: diagonal only is not contact", not plan.touches(_cells([[5, 2]])))
	ck("touches: far away is not contact", not plan.touches(_cells([[3, 3], [4, 3]])))


func _test_featured() -> void:
	# Featured P pentomino ###/##.
	var featured: Array[Vector2i] = _cells([[0, 0], [1, 0], [2, 0], [0, 1], [1, 1]])
	var joined: CastPlan = CastPlan.new().init(2, 0)
	joined.add_piece(0, lib.make_piece("t4"), _cells([[3, 0], [4, 0], [5, 0], [4, 1]]))
	ck("is_featured: one piece alone (t4) is not enough", not joined.is_featured(featured))
	joined.add_piece(1, lib.make_piece("mono"), _cells([[3, 1]]))
	ck("is_featured: t4 + mono forming P", joined.is_featured(featured))
	var rotated: CastPlan = CastPlan.new().init(2, 0)
	# #./##/## = P turned 3 quarter turns (its mirror .#/##/## would not count).
	rotated.add_piece(0, lib.make_piece("bar3", 1), _cells([[3, 0], [3, 1], [3, 2]]))
	rotated.add_piece(1, lib.make_piece("bar2", 1), _cells([[4, 1], [4, 2]]))
	ck("is_featured: bar3 + bar2 forming a rotated P", rotated.is_featured(featured))
	var one_piece: CastPlan = CastPlan.new().init(2, 0)
	one_piece.add_piece(0, lib.make_piece("u5"), _cells([[3, 0], [5, 0], [3, 1], [4, 1], [5, 1]]))
	ck("is_featured: a single piece of the featured shape does not count", not one_piece.is_featured(_cells([[0, 0], [2, 0], [0, 1], [1, 1], [2, 1]])))
	var apart: CastPlan = CastPlan.new().init(2, 0)
	apart.add_piece(0, lib.make_piece("bar3"), _cells([[3, 0], [4, 0], [5, 0]]))
	apart.add_piece(1, lib.make_piece("bar2"), _cells([[3, 2], [4, 2]]))
	ck("is_featured: two separate pieces are not the shape", not apart.is_featured(featured))

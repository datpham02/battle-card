extends SceneTree
## Story 024 Part A: Piece (rotation, normalisation, size, rotten) and PieceLibrary (loading,
## validation, weights, fallback). Headless; prints PASS/FAIL lines and FAILS=N.

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


func _init() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	_test_library_file(lib)
	_test_rotation(lib)
	_test_normalisation_and_size()
	_test_rotten()
	_test_library_validation()
	print("FAILS=%d" % fails)
	quit(fails)


func _test_library_file(lib: PieceLibrary) -> void:
	var expected_ids: Array[String] = ["mono", "bar2", "bar3", "l3", "square", "t4", "l4", "s4", "bar4", "plus5", "u5", "p5", "bar5"]
	# Story 034: the 3 run_only shapes (z4, j4, y5) follow; base_shape_ids() is the default pool.
	ck("library: the 12 story shapes plus p5 (Story 026) in order", lib.base_shape_ids() == expected_ids)
	var expected_counts: Array[int] = [1, 2, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5]
	var counts_ok: bool = true
	for i: int in expected_ids.size():
		var piece: Piece = lib.make_piece(expected_ids[i])
		counts_ok = counts_ok and piece.cell_count() == expected_counts[i] and piece.relative_cells().size() == expected_counts[i]
	ck("library: cell counts 1,2,3,3,4,4,4,4,4,5,5,5,5", counts_ok)
	ck("library: name_key is a piece.<id>.name key", lib.name_key("t4") == "piece.t4.name" and lib.name_key("nope") == "")
	ck("library: shape_cells of an unknown id is empty", lib.shape_cells("nope").is_empty())
	ck("library: unknown make_piece is null", lib.make_piece("nope") == null)
	ck("weights: chapter 1 favours small shapes over bar5", lib.weight("mono", "ch1") > 10.0 * lib.weight("bar5", "ch1"))
	var large_ch1: float = lib.weight("plus5", "ch1") + lib.weight("u5", "ch1") + lib.weight("bar5", "ch1")
	var large_ch3: float = lib.weight("plus5", "ch3") + lib.weight("u5", "ch3") + lib.weight("bar5", "ch3")
	ck("weights: chapter 3 has more 5-cell weight than chapter 1", large_ch3 > large_ch1)
	ck("weights: unknown chapter uses the default map", lib.weight("mono", "ch99") == lib.weight("mono", "default") and lib.weight("mono", "default") > 0.0)
	var every_positive: bool = true
	for id: String in lib.base_shape_ids(): # Story 034: run_only shapes have no table weight
		for chapter: String in ["ch1", "ch2", "ch3", "default"]:
			every_positive = every_positive and lib.weight(id, chapter) > 0.0
	ck("weights: every shape has a positive weight in every chapter", every_positive)


func _test_rotation(lib: PieceLibrary) -> void:
	var all_ok: bool = true
	var four_ok: bool = true
	var count_ok: bool = true
	for id: String in lib.shape_ids():
		var piece: Piece = lib.make_piece(id)
		var turned: Piece = piece.rotated(4)
		four_ok = four_ok and turned.relative_cells() == piece.relative_cells() and turned.rotation == 0
		var step: Piece = piece
		for _i: int in 4:
			step = step.rotated(1)
			count_ok = count_ok and step.cell_count() == piece.cell_count() and step.relative_cells().size() == piece.cell_count()
		all_ok = all_ok and step.relative_cells() == piece.relative_cells()
	ck("rotation: four single turns return the original cells (all 13 shapes)", all_ok)
	ck("rotation: rotated(4) equals the original and rotation wraps to 0", four_ok)
	ck("rotation: cell_count never changes while rotating", count_ok)
	var l3: Piece = lib.make_piece("l3")
	ck("rotation: l3 at 0 is X. / XX", l3.relative_cells() == _cells([[0, 0], [0, 1], [1, 1]]))
	ck("rotation: l3 turned once clockwise is XX / X.", l3.rotated(1).relative_cells() == _cells([[0, 0], [1, 0], [0, 1]]))
	ck("rotation: l3 turned twice is XX / .X", l3.rotated(2).relative_cells() == _cells([[0, 0], [1, 0], [1, 1]]))
	ck("rotation: rotated returns a NEW piece and leaves the source alone", l3.rotated(1) != l3 and l3.rotation == 0)
	ck("rotation: negative turns wrap (rotated(-1) == rotated(3))", l3.rotated(-1).relative_cells() == l3.rotated(3).relative_cells() and l3.rotated(-1).rotation == 3)
	ck("rotation: make wraps a rotation of 5 to 1", lib.make_piece("bar3", 5).rotation == 1)
	var bar3: Piece = lib.make_piece("bar3")
	ck("rotation: bar3 size (3,1) turns into (1,3)", bar3.size() == Vector2i(3, 1) and bar3.rotated(1).size() == Vector2i(1, 3))
	var plus5: Piece = lib.make_piece("plus5")
	var plus_same: bool = true
	for turns: int in 4:
		plus_same = plus_same and plus5.rotated(turns).relative_cells() == plus5.relative_cells()
	ck("rotation: plus5 is symmetric under every turn", plus_same)


func _test_normalisation_and_size() -> void:
	var offset: Piece = Piece.make("bar2", _cells([[5, 7], [6, 7]]))
	ck("normalise: offset cells move to the origin", offset.relative_cells() == _cells([[0, 0], [1, 0]]))
	var negative: Piece = Piece.make("l3", _cells([[-2, -3], [-2, -2], [-1, -2]]))
	ck("normalise: negative offsets too", negative.relative_cells() == _cells([[0, 0], [0, 1], [1, 1]]))
	var unsorted: Piece = Piece.make("l3", _cells([[1, 1], [0, 0], [0, 1]]))
	ck("normalise: cells come back sorted by row then column", unsorted.relative_cells() == _cells([[0, 0], [0, 1], [1, 1]]))
	var dup: Piece = Piece.make("mono", _cells([[2, 2], [2, 2]]))
	ck("normalise: duplicate cells collapse", dup.cell_count() == 1)
	var square: Piece = Piece.make("square", _cells([[0, 0], [1, 0], [0, 1], [1, 1]]))
	ck("size: square is (2,2)", square.size() == Vector2i(2, 2))
	var t4: Piece = Piece.make("t4", _cells([[0, 0], [1, 0], [2, 0], [1, 1]]))
	ck("size: t4 is (3,2), rotated once (2,3)", t4.size() == Vector2i(3, 2) and t4.rotated(1).size() == Vector2i(2, 3))
	var min_ok: bool = true
	for turns: int in 4:
		var rel: Array[Vector2i] = t4.rotated(turns).relative_cells()
		var min_x: int = 99
		var min_y: int = 99
		for c: Vector2i in rel:
			min_x = mini(min_x, c.x)
			min_y = mini(min_y, c.y)
		min_ok = min_ok and min_x == 0 and min_y == 0
	ck("normalise: every rotation of t4 touches x=0 and y=0", min_ok)
	ck("cells_at: anchor shifts every cell", t4.cells_at(Vector2i(4, 1)) == _cells([[4, 1], [5, 1], [6, 1], [5, 2]]))
	ck("cells_at: uses the current rotation (T pointing down turns to point left)", t4.rotated(1).cells_at(Vector2i(3, 0)) == _cells([[4, 0], [3, 1], [4, 1], [4, 2]]))
	ck("piece: normal piece is not rotten and is placeable", not t4.is_rotten() and t4.placeable())
	ck("piece: an empty piece is not placeable", not Piece.make("none", [] as Array[Vector2i]).placeable())


func _test_rotten() -> void:
	var rotten: Piece = Piece.make_rotten()
	ck("rotten: is_rotten, 1 cell, not placeable", rotten.is_rotten() and rotten.cell_count() == 1 and not rotten.placeable())
	ck("rotten: shape id is the reserved one", rotten.shape_id == Piece.ROTTEN_ID)
	ck("rotten: rotating keeps it rotten and unplaceable", rotten.rotated(1).is_rotten() and not rotten.rotated(1).placeable())
	ck("rotten: relative cell is the origin", rotten.relative_cells() == _cells([[0, 0]]))


func _test_library_validation() -> void:
	var bad: PieceLibrary = PieceLibrary.from_json_text("not json")
	ck("fallback: garbage text gives the mono-only library", bad.shape_ids() == (["mono"] as Array[String]) and bad.make_piece("mono").cell_count() == 1)
	ck("fallback: its weight is positive", bad.weight("mono", "ch1") > 0.0)
	var missing: PieceLibrary = PieceLibrary.load_from_file("res://assets/data/__nope__.json")
	ck("fallback: a missing file gives the mono-only library", missing != null and missing.shape_ids() == (["mono"] as Array[String]))
	var empty: PieceLibrary = PieceLibrary.from_dictionary({"shapes": []})
	ck("fallback: no shapes gives the mono-only library", empty.shape_ids() == (["mono"] as Array[String]))
	var data: Dictionary = {
		"shapes": [
			{"id": "ok2", "cells": [[3, 3], [4, 3]], "name_key": "piece.ok2.name"},
			{"id": "split", "cells": [[0, 0], [2, 0]], "name_key": "x"},
			{"id": "big6", "cells": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [5, 0]], "name_key": "x"},
			{"id": "rotten", "cells": [[0, 0]], "name_key": "x"},
			{"id": "ok2", "cells": [[0, 0]], "name_key": "dup"},
			{"id": "malformed", "cells": [[0, 0, 1]], "name_key": "x"},
		],
		"weights": {"default": {"ok2": 3, "ghost": 5}, "ch9": {"ok2": -4}},
	}
	var lib: PieceLibrary = PieceLibrary.from_dictionary(data)
	ck("validation: only the valid shape survives (disconnected, 6 cells, reserved, duplicate, malformed dropped)", lib.shape_ids() == (["ok2"] as Array[String]))
	ck("validation: kept shape is normalised", lib.shape_cells("ok2") == _cells([[0, 0], [1, 0]]))
	ck("validation: weights for unknown shapes are ignored, valid ones read", lib.weight("ok2", "default") == 3.0 and lib.weight("ghost", "default") == 1.0)
	ck("validation: negative weights clamp to 0", lib.weight("ok2", "ch9") == 0.0)

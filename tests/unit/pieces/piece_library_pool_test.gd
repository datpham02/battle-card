extends SceneTree
## Story 034 Part A: PieceLibrary pools (default / run_only), the three run_only shapes of
## pieces.json and weight() = 0 for run_only. Headless and deterministic. Prints FAILS=N.

var fails: int = 0


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _init() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var run_only: Array[String] = ["z4", "j4", "y5"]
	ck("run_only_ids are z4, j4, y5 in file order", lib.run_only_ids() == run_only)
	ck("base_shape_ids holds the 13 original shapes + w5 n5 v5 (Story 037)", lib.base_shape_ids().size() == 16)
	ck("base_shape_ids keeps file order (mono first, bar5 last)",
		lib.base_shape_ids()[0] == "mono" and lib.base_shape_ids()[12] == "bar5")
	ck("shape_ids = base + run_only", lib.shape_ids().size() == 19)
	for id: String in run_only:
		ck("%s pool is run_only" % id, lib.pool(id) == "run_only" and lib.is_run_only(id))
		ck("%s has no table weight (0 for every chapter)" % id,
			lib.weight(id, "ch1") == 0.0 and lib.weight(id, "ch3") == 0.0 and lib.weight(id, "nope") == 0.0)
		ck("%s name_key" % id, lib.name_key(id) == "piece.%s.name" % id)
	ck("mono pool is default", lib.pool("mono") == "default" and not lib.is_run_only("mono"))
	ck("unknown id pool is empty", lib.pool("ghost") == "" and not lib.is_run_only("ghost"))
	ck("default weights unchanged", lib.weight("mono", "ch1") == 14.0 and lib.weight("bar5", "default") == 1.0)
	var z4_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]
	ck("z4 cells", lib.shape_cells("z4") == z4_cells)
	ck("j4 has 4 cells", lib.shape_cells("j4").size() == 4)
	ck("y5 has 5 cells", lib.shape_cells("y5").size() == 5)
	# The mirror shapes are not a rotation of their originals (no flip exists).
	ck("z4 is not a rotation of s4", not _same_up_to_rotation(lib, "z4", "s4"))
	ck("j4 is not a rotation of l4", not _same_up_to_rotation(lib, "j4", "l4"))
	ck("y5 is not a rotation of another 5-cell shape",
		not (_same_up_to_rotation(lib, "y5", "plus5") or _same_up_to_rotation(lib, "y5", "p5")
			or _same_up_to_rotation(lib, "y5", "u5") or _same_up_to_rotation(lib, "y5", "bar5")))
	# Pool parsing from a dictionary: missing = default, unknown = default with a warning.
	var custom: PieceLibrary = PieceLibrary.from_dictionary({
		"shapes": [
			{"id": "a", "cells": [[0, 0]]},
			{"id": "b", "cells": [[0, 0], [1, 0]], "pool": "run_only"},
			{"id": "c", "cells": [[0, 0], [1, 0], [2, 0]], "pool": "weird"},
		],
		"weights": {"default": {"a": 3, "b": 9}},
	})
	ck("missing pool = default", custom.pool("a") == "default")
	ck("unknown pool falls back to default", custom.pool("c") == "default")
	ck("run_only weight is 0 even when a table lists it", custom.weight("b", "default") == 0.0)
	var base_expected: Array[String] = ["a", "c"]
	ck("base ids of the custom lib", custom.base_shape_ids() == base_expected)
	ck("the mono-only fallback is a default shape",
		PieceLibrary.from_dictionary({}).pool("mono") == "default")
	print("FAILS=%d" % fails)
	quit(fails)


func _same_up_to_rotation(lib: PieceLibrary, a: String, b: String) -> bool:
	var pa: Piece = lib.make_piece(a)
	var target: Array[Vector2i] = lib.shape_cells(b)
	target.sort()
	for turns: int in 4:
		var cells: Array[Vector2i] = pa.rotated(turns).relative_cells()
		cells.sort()
		if cells == target:
			return true
	return false

extends SceneTree

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _spec(cols: int, rows: int, holes: Array) -> Dictionary:
	return {"id": "t", "side_cols": cols, "side_rows": rows, "missing_cells": holes, "difficulty": 1}


func _initialize() -> void:
	var lib: ArenaLibrary = ArenaLibrary.load_from_file()
	var ids: Array[String] = lib.shape_ids()
	_check("library has >= 8 shapes", ids.size() >= 8, str(ids))
	for id: String in ids:
		var s: Dictionary = lib.get_shape(id)
		var g: BoardGrid = ArenaValidator.build_grid(s)
		print("  shape %s: %d cells/side, diff %d, %dx%d" % [id, g.player_cells().size(), s["difficulty"], s["side_cols"], s["side_rows"]])
		_check("valid " + id, bool(ArenaValidator.validate(s, lib.rules)["ok"]))
	for want: String in ["square", "rect", "cross", "u_shape", "ring", "islands_bridge", "staircase", "diamond"]:
		_check("has " + want, ids.has(want))
	_check("difficulty filter", lib.shapes_with_difficulty(2).size() == 2)
	_check("unknown get_shape empty", lib.get_shape("nope").is_empty())
	# broken shapes
	var r: Dictionary = ArenaValidator.validate(_spec(3, 3, [[1, 0], [1, 1], [1, 2]]), lib.rules)
	print("  disconnected: ", r["reasons"])
	_check("disconnected rejected", not r["ok"] and str(r["reasons"]).contains("not connected"))
	r = ArenaValidator.validate(_spec(2, 2, []), lib.rules)
	print("  small: ", r["reasons"])
	_check("<6 rejected", not r["ok"] and str(r["reasons"]).contains("only 4 cells"))
	# Default cell (2, 1) is a leaf: its only neighbour is (3, 1), so a 2-cell piece seals it.
	r = ArenaValidator.validate(_spec(5, 3, [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [2, 0], [2, 2]]), lib.rules)
	print("  default cell is a dead end: ", r["reasons"])
	_check("default dead-end rejected", not r["ok"] and str(r["reasons"]).contains("no escape"))
	# Piece-placement checks (Story 026): coverage and a >= 3 cell shape per half.
	var square_spec: Dictionary = _spec(3, 3, [])
	var only_small: PieceLibrary = PieceLibrary.from_dictionary({"shapes": [
		{"id": "mono", "cells": [[0, 0]]}, {"id": "bar2", "cells": [[0, 0], [1, 0]]}]})
	r = ArenaValidator.validate(square_spec, lib.rules, only_small)
	_check("no 3+ cell shape on a half rejected", not r["ok"] and str(r["reasons"]).contains("no piece of 3+ cells fits on the player half"))
	_check("no 3+ cell shape: boss half too", str(r["reasons"]).contains("no piece of 3+ cells fits on the boss half"))
	var only_big: PieceLibrary = PieceLibrary.from_dictionary({"shapes": [{"id": "bar3", "cells": [[0, 0], [1, 0], [2, 0]]}]})
	r = ArenaValidator.validate(_spec(3, 3, [[0, 0], [0, 1], [1, 0]]), lib.rules, only_big)
	print("  bar3 only, odd shape: ", r["reasons"])
	_check("uncoverable cell rejected", not r["ok"] and str(r["reasons"]).contains("no piece placement covers the player cell"))
	r = ArenaValidator.validate(square_spec, lib.rules, only_big)
	_check("3x3 with only bar3 passes coverage", not str(r["reasons"]).contains("no piece placement covers"))
	r = ArenaValidator.validate(square_spec, lib.rules)
	_check("3x3 with the real library passes", bool(r["ok"]), str(r["reasons"]))
	r = ArenaValidator.validate(_spec(3, 3, [[7, 7]]), lib.rules)
	print("  out of range: ", r["reasons"])
	_check("out-of-range hole rejected", not r["ok"])
	# variants
	for id: String in ids:
		var base: Dictionary = lib.get_shape(id)
		var base_copy: Dictionary = base.duplicate(true)
		var good: int = 0
		for seed_value: int in 200:
			var v: Dictionary = ArenaVariants.make(base, lib.rules, seed_value)
			var ok: bool = bool(ArenaValidator.validate(v, lib.rules)["ok"])
			var differs: bool = ArenaValidator.build_grid(v).player_cells() != ArenaValidator.build_grid(base).player_cells()
			if ok and differs:
				good += 1
		_check("variants %s %d/200" % [id, good], good >= 180)
		_check("input not mutated " + id, base == base_copy)
		var a: Dictionary = ArenaVariants.make(base, lib.rules, 42)
		var b: Dictionary = ArenaVariants.make(base, lib.rules, 42)
		_check("deterministic " + id, a == b and str(a["variant_of"]) == id)
	# grid_for_spec
	var g1: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "rect"}, lib, 1)
	_check("shape spec", g1 != null and g1.side_cols == 4 and g1.side_rows == 3)
	var g2: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "bogus"}, lib, 1)
	_check("unknown shape -> null", g2 == null)
	var g3: BoardGrid = ArenaLibrary.grid_for_spec({"side_cols": 4, "side_rows": 3, "missing_cells": [[0, 0]]}, lib, 1)
	_check("direct block", g3 != null and g3.player_cells().size() == 11)
	var g4: BoardGrid = ArenaLibrary.grid_for_spec({"side_cols": 2, "side_rows": 2}, lib, 1)
	_check("invalid direct -> null", g4 == null)
	var g5: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "cross", "variant": true}, lib, 5)
	_check("variant spec", g5 != null and g5.side_cols == 4)
	# corrupt file
	var path: String = "res://tests/fixtures/bad_arenas.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var bad: ArenaLibrary = ArenaLibrary.load_from_file(path)
	_check("corrupt -> square", bad.shape_ids() == ["square"])
	var missing: ArenaLibrary = ArenaLibrary.load_from_file("res://nope.json")
	_check("missing -> square", missing.shape_ids() == ["square"])
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"rules":{"min_cells_per_side":6},"shapes":[{"id":"tiny","side_cols":2,"side_rows":2,"missing_cells":[]},{"id":"ok","side_cols":3,"side_rows":3}]}')
	f.close()
	var part: ArenaLibrary = ArenaLibrary.load_from_file(path)
	_check("invalid shape dropped from pool", part.shape_ids() == ["ok"])
	print("FAILS=%d" % fails)
	quit(fails)

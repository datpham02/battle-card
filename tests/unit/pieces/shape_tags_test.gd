extends SceneTree
## Skill v2 B1 (docs/skill-v2/02-mechanics-catalog.md M16): ShapeTags classifies a placed piece from its physical cells:
## every library shape gets its family, tags are rotation-invariant except line_h / line_v, mirror-invariant (L = J),
## and Odd blocks carry `odd`. Run: godot --headless --path . -s res://tests/unit/pieces/shape_tags_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_every_library_shape_gets_its_family()
	test_tags_survive_rotation()
	test_line_orientation_follows_rotation()
	test_mirrors_share_tags()
	test_numbers_and_centre()
	test_odd_flag_and_empty()
	test_compact_is_fill_and_square()
	test_family_examples_u_p_l_t_plus()
	test_odd_examples()
	test_centre_tie_goes_to_hero()
	test_fifty_random_odd_blocks()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


const EXPECTED: Dictionary = {
	"mono": ["mono"],
	"bar2": ["domino", "line", "line_h"],
	"bar3": ["line", "line_h"],
	"bar4": ["line", "line_h"],
	"bar5": ["line", "line_h"],
	"square": ["compact", "square"],
	"l3": ["L"],
	"l4": ["L"],
	"j4": ["L"],
	"v5": ["L"],
	"t4": ["T", "branched"],
	"y5": ["T", "branched"],
	"plus5": ["branched", "plus"],
	"s4": ["S"],
	"z4": ["S"],
	"n5": ["S"],
	"w5": ["S"],
	"u5": ["U"],
	"p5": ["P", "branched", "compact"],
}


func test_every_library_shape_gets_its_family() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	for id: String in EXPECTED.keys():
		var piece: Piece = lib.make_piece(id, 0)
		ck("library has %s" % id, piece != null)
		if piece == null:
			continue
		var got: Array = ShapeTags.tags_for(piece.relative_cells())["tags"]
		ck("tags %s" % id, got == EXPECTED[id], str(got))


func test_tags_survive_rotation() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	for id: String in ["l4", "t4", "s4", "u5", "p5", "plus5", "y5", "v5", "w5", "n5"]:
		var base: Array = ShapeTags.tags_for(lib.make_piece(id, 0).relative_cells())["tags"]
		var same: bool = true
		for r: int in [1, 2, 3]:
			same = same and ShapeTags.tags_for(lib.make_piece(id, r).relative_cells())["tags"] == base
		ck("rotation-invariant %s" % id, same)


func test_line_orientation_follows_rotation() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var flat: Array = ShapeTags.tags_for(lib.make_piece("bar3", 0).relative_cells())["tags"]
	var up: Array = ShapeTags.tags_for(lib.make_piece("bar3", 1).relative_cells())["tags"]
	ck("bar3 flat is line_h", flat.has("line_h") and not flat.has("line_v"))
	ck("bar3 turned is line_v", up.has("line_v") and not up.has("line_h"))


func test_mirrors_share_tags() -> void:
	var l: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
	var j: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2)]
	ck("L and J share tags", ShapeTags.tags_for(l)["tags"] == ShapeTags.tags_for(j)["tags"])
	var s: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var z: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]
	ck("S and Z share tags", ShapeTags.tags_for(s)["tags"] == ShapeTags.tags_for(z)["tags"])


func test_numbers_and_centre() -> void:
	var bar4: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	var t: Dictionary = ShapeTags.tags_for(bar4)
	ck("bar4 size / bbox / length", int(t["size"]) == 4 and t["bbox"] == Vector2i(4, 1) and int(t["length"]) == 4)
	var plus: Array[Vector2i] = [Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2)]
	var p: Dictionary = ShapeTags.tags_for(plus)
	ck("plus centre is the middle cell (board coords kept)", p["centre"] == Vector2i(4, 1))
	ck("plus branch count 1, length 3", int(p["branch_count"]) == 1 and int(p["length"]) == 3)


func test_odd_flag_and_empty() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)]
	ck("odd flag adds odd", (ShapeTags.tags_for(cells, true)["tags"] as Array).has("odd"))
	var none: Array[Vector2i] = []
	ck("empty cells -> no tags, size 0", (ShapeTags.tags_for(none)["tags"] as Array).is_empty() and int(ShapeTags.tags_for(none)["size"]) == 0)


func _cells(pts: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Variant in pts:
		out.append(p as Vector2i)
	return out


func _rot(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		out.append(Vector2i(-c.y, c.x))
	return out


func _drop_orientation(tags: Array) -> Array:
	var out: Array = []
	for t: Variant in tags:
		if t != "line_h" and t != "line_v":
			out.append(t)
	return out


# B1.5: M16 `compact` = fill >= 0.75 AND a full 2x2. Every library shape against the M16 table (square, p5 only).
func test_compact_is_fill_and_square() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var compact_ids: Array[String] = []
	for id: String in EXPECTED.keys():
		if (ShapeTags.tags_for(lib.make_piece(id, 0).relative_cells())["tags"] as Array).has("compact"):
			compact_ids.append(id)
	compact_ids.sort()
	var want: Array[String] = ["p5", "square"]
	ck("library compact set = M16 table [p5, square]", compact_ids == want, str(compact_ids))
	var u5: Dictionary = ShapeTags.tags_for(lib.make_piece("u5", 0).relative_cells())
	ck("u5 fill 5/6 but no 2x2 -> not compact", absf(float(u5["fill"]) - 5.0 / 6.0) < 0.001 and not (u5["tags"] as Array).has("compact"))
	var l3: Dictionary = ShapeTags.tags_for(lib.make_piece("l3", 0).relative_cells())
	ck("l3 fill 0.75 but no 2x2 -> not compact", absf(float(l3["fill"]) - 0.75) < 0.001 and not (l3["tags"] as Array).has("compact"))
	var bar3: Dictionary = ShapeTags.tags_for(lib.make_piece("bar3", 0).relative_cells())
	ck("bar3 fill 1.0 but a line -> not compact", absf(float(bar3["fill"]) - 1.0) < 0.001 and not (bar3["tags"] as Array).has("compact"))
	var p5: Dictionary = ShapeTags.tags_for(lib.make_piece("p5", 0).relative_cells())
	ck("p5 fill 5/6 with 2x2 -> compact", (p5["tags"] as Array).has("compact"))
	# A 2x2 inside a sprawling shape: fill 5/9 < 0.75 -> not compact (but still P-like structure is not claimed).
	var sprawl: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 2)])
	var sp: Dictionary = ShapeTags.tags_for(sprawl)
	ck("2x2 plus a far cell (fill 5/9) -> not compact", not (sp["tags"] as Array).has("compact"), str(sp["tags"]))


func test_family_examples_u_p_l_t_plus() -> void:
	var u: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0)])
	ck("U example -> [U]", ShapeTags.tags_for(u)["tags"] == ["U"], str(ShapeTags.tags_for(u)["tags"]))
	var p: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)])
	ck("P example -> [P, branched, compact]", ShapeTags.tags_for(p)["tags"] == ["P", "branched", "compact"], str(ShapeTags.tags_for(p)["tags"]))
	var l: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3)])
	ck("long L example -> [L]", ShapeTags.tags_for(l)["tags"] == ["L"], str(ShapeTags.tags_for(l)["tags"]))
	var t: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)])
	ck("T example -> [T, branched]", ShapeTags.tags_for(t)["tags"] == ["T", "branched"], str(ShapeTags.tags_for(t)["tags"]))
	var plus: Array[Vector2i] = _cells([Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)])
	var pt: Dictionary = ShapeTags.tags_for(plus)
	ck("plus example -> [branched, plus], fill 5/9", pt["tags"] == ["branched", "plus"] and absf(float(pt["fill"]) - 5.0 / 9.0) < 0.001, str(pt["tags"]))


func test_odd_examples() -> void:
	var rect6: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)])
	ck("odd 2x3 rectangle -> compact, odd", ShapeTags.tags_for(rect6, true)["tags"] == ["branched", "compact", "odd"], str(ShapeTags.tags_for(rect6, true)["tags"]))
	var blob7: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)])
	ck("odd 7-cell blob (fill 7/9) -> compact", (ShapeTags.tags_for(blob7, true)["tags"] as Array).has("compact"))
	var snake6: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)])
	ck("odd 6-cell staircase -> [S, odd]", ShapeTags.tags_for(snake6, true)["tags"] == ["S", "odd"], str(ShapeTags.tags_for(snake6, true)["tags"]))
	var hook7: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)])
	var hk: Array = ShapeTags.tags_for(hook7, true)["tags"]
	ck("odd 7-cell hook with a 2x2 (fill 7/12) -> not compact", not hk.has("compact") and hk.has("odd"), str(hk))


func test_centre_tie_goes_to_hero() -> void:
	# bar2 at (5,1)-(6,1): both cells are equally central.
	var bar2: Array[Vector2i] = _cells([Vector2i(5, 1), Vector2i(6, 1)])
	ck("no hero -> smallest x", ShapeTags.tags_for(bar2)["centre"] == Vector2i(5, 1))
	ck("hero on the right -> the right cell", ShapeTags.tags_for(bar2, false, Vector2i(9, 1))["centre"] == Vector2i(6, 1))
	ck("hero on the left -> the left cell", ShapeTags.tags_for(bar2, false, Vector2i(0, 1))["centre"] == Vector2i(5, 1))


# M16 "tests for every library shape and 50 random Odd blocks": tags are non-empty, carry `odd`, and are
# rotation-invariant (ignoring line_h / line_v); seeded, deterministic.
func test_fifty_random_odd_blocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 160016
	var bad: int = 0
	for i: int in 50:
		var cells: Array[Vector2i] = OddBlock.grow(rng.randi_range(4, 7), rng)
		var base: Array = _drop_orientation(ShapeTags.tags_for(cells, true)["tags"])
		var cur: Array[Vector2i] = cells
		var ok: bool = base.has("odd") and base.size() >= 1
		for r: int in 3:
			cur = _rot(cur)
			ok = ok and _drop_orientation(ShapeTags.tags_for(cur, true)["tags"]) == base
		if not ok:
			bad += 1
			print("  odd block ", cells, " tags ", base)
	ck("50 random Odd blocks: tagged, rotation-invariant", bad == 0, "bad=%d" % bad)

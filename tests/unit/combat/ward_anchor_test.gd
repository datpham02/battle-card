extends SceneTree
## Skill v2 batch 3 (M10 option A2): WardAnchor.remap, the pure re-anchoring of a ward card's placed shape on the
## hero: mirrored across the divider, its centre on the hero's cell, trimmed to the own half and to unlocked cells,
## never empty while the hero's cell is a player cell, deterministic.
## Run: godot --headless --path . -s res://tests/unit/combat/ward_anchor_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var grid := BoardGrid.new(4, 3)  # player x 0..3, enemy x 4..7, rows 0..2
	# a horizontal bar2 on the enemy half (4,1)-(5,1): centre (4,1) (nearest the hero on the tie); hero on (2,1)
	var bar: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1)]
	var r: Array[Vector2i] = WardAnchor.remap(bar, Vector2i(2, 1), grid)
	ck("bar2 (4,1)-(5,1) on hero (2,1): mirrored to (2,1) (1,1)", r == [Vector2i(2, 1), Vector2i(1, 1)], str(r))
	# a square (4..5, 0..1), hero (1,1): centre (4,1) -> (1,1) (0,1) (1,0) (0,0)
	var sq: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)]
	var rs: Array[Vector2i] = WardAnchor.remap(sq, Vector2i(1, 1), grid)
	ck("square on hero (1,1): the 4 cells around it on the own half", rs.size() == 4 and rs.has(Vector2i(1, 1)) and rs.has(Vector2i(0, 1))
		and rs.has(Vector2i(1, 0)) and rs.has(Vector2i(0, 0)), str(rs))
	# trimmed: hero on the edge (0,1), bar2 -> (0,1) and (-1,1) off-grid
	var re: Array[Vector2i] = WardAnchor.remap(bar, Vector2i(0, 1), grid)
	ck("hero on the left edge: the off-grid cell is trimmed", re == [Vector2i(0, 1)], str(re))
	# hero on the divider side (3,1): mirrored cells go toward x = 2: (3,1) (2,1) - never onto the enemy half
	var rd: Array[Vector2i] = WardAnchor.remap(bar, Vector2i(3, 1), grid)
	ck("hero next to the divider: the shape faces the own half, no enemy cell", rd == [Vector2i(3, 1), Vector2i(2, 1)], str(rd))
	# a vertical bar (4,0)-(4,1), hero (2,2): centre (4,1) -> (2,1) (2,2)... y keeps: (2,1) is off? (4,0)->(2,1), (4,1)->(2,2)
	var col: Array[Vector2i] = [Vector2i(4, 0), Vector2i(4, 1)]
	var rc: Array[Vector2i] = WardAnchor.remap(col, Vector2i(2, 2), grid)
	ck("a column keeps its rows (y unchanged): (2,1) (2,2)", rc == [Vector2i(2, 1), Vector2i(2, 2)], str(rc))
	# locked cells are trimmed
	var fx := StatusEffects.new()
	fx.apply_drop(CombatState.Side.PLAYER, [Vector2i(1, 1)] as Array[Vector2i], 0.5, 1.0)
	var rl: Array[Vector2i] = WardAnchor.remap(bar, Vector2i(2, 1), grid, fx)
	ck("a cracking cell is trimmed", rl == [Vector2i(2, 1)], str(rl))
	# everything trimmed -> the hero's own cell
	var far: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0)]
	var rf: Array[Vector2i] = WardAnchor.remap(far, Vector2i(0, 2), grid)
	ck("never empty: at least the hero's cell", not rf.is_empty() and rf.has(Vector2i(0, 2)), str(rf))
	ck("deterministic", str(WardAnchor.remap(sq, Vector2i(1, 1), grid)) == str(rs))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

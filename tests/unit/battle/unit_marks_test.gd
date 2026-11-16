extends SceneTree
## Head marks (art bible 5.2 'Mảnh Gốc', 2026-11-15): the Heart Keeper has a Lattice Light polyomino drawn by code
## above its head; the geometry is pure, whole art px, sits gap_px above the head and mirrors with the sprite.
## Run: godot --headless --path . -s res://tests/unit/battle/unit_marks_test.gd

const KEEPER: String = "an_dai_keeper"
const FEET: Vector2i = Vector2i(100, 200)

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_keeper_has_a_three_square_mark()
	test_unlisted_unit_has_no_mark()
	test_mark_sits_above_the_head()
	test_mark_mirrors_with_the_sprite()
	test_mark_without_cells_draws_nothing()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_keeper_has_a_three_square_mark() -> void:
	var mark: Dictionary = UnitLayer.head_mark_for(KEEPER)
	_check("test_keeper_has_a_mark", not mark.is_empty())
	_check("test_keeper_mark_has_three_squares", (mark.get("cells", []) as Array).size() == 3, str(mark.get("cells")))
	_check("test_keeper_mark_is_lattice_light", str(mark.get("colour", "")).to_upper() == "#FFD45C", str(mark.get("colour")))


func test_unlisted_unit_has_no_mark() -> void:
	_check("test_goblin_scout_has_no_mark", UnitLayer.head_mark_for("goblin_scout").is_empty())


func test_mark_sits_above_the_head() -> void:
	var mark: Dictionary = UnitLayer.head_mark_for(KEEPER)
	var rects: Array[Rect2i] = UnitLayer.head_mark_rects(mark, FEET, false)
	var bottom: int = -100000
	for r: Rect2i in rects:
		bottom = maxi(bottom, r.end.y)
	var expected: int = FEET.y - int(mark["head_px"]) - int(mark["gap_px"])
	_check("test_mark_three_rects", rects.size() == 3, str(rects))
	_check("test_mark_bottom_gap_above_head", bottom == expected, "%d vs %d" % [bottom, expected])
	var px: int = int(mark["cell_px"])
	var ok: bool = true
	for r: Rect2i in rects:
		ok = ok and r.size == Vector2i(px, px)
	_check("test_mark_squares_are_cell_px", ok, str(rects))


func test_mark_mirrors_with_the_sprite() -> void:
	var mark: Dictionary = UnitLayer.head_mark_for(KEEPER)
	var a: Array[Rect2i] = UnitLayer.head_mark_rects(mark, FEET, false)
	var b: Array[Rect2i] = UnitLayer.head_mark_rects(mark, FEET, true)
	var ca: float = 0.0
	var cb: float = 0.0
	for r: Rect2i in a:
		ca += r.get_center().x
	for r: Rect2i in b:
		cb += r.get_center().x
	ca /= a.size()
	cb /= b.size()
	# Mirrored about the feet: the two centres sit on opposite sides of feet.x by the same distance (± 1 px rounding).
	_check("test_mark_mirrors_about_the_feet", absf((ca - FEET.x) + (cb - FEET.x)) <= 1.0, "%.1f %.1f" % [ca, cb])
	_check("test_mark_flip_changes_layout", a != b)


func test_mark_without_cells_draws_nothing() -> void:
	_check("test_empty_mark_no_rects", UnitLayer.head_mark_rects({}, FEET, false).is_empty())

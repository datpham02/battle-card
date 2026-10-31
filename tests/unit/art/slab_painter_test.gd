extends SceneTree
## Story 047 Part B: SlabPainter pure steps (stamp selection, platform geometry). Headless,
## deterministic, no drawing; reads the real forest stamps JSON / PNG from disk (no import).
## Run: godot --headless --path . -s res://tests/unit/art/slab_painter_test.gd

const Painter := preload("res://src/art/slab_painter.gd")
const STAMPS_META := "res://assets/art/env/forest/env_slab_forest_stamps.json"
const STAMPS_PNG := "res://assets/art/env/forest/env_slab_forest_stamps.png"
## Cell sizes of the story's board table (Story 047 Part A) plus the art bible's smallest (38x27).
const CELL_SIZES: Array[Vector2i] = [Vector2i(38, 27), Vector2i(43, 31), Vector2i(46, 33), Vector2i(64, 46)]
const SEEDS_PER_SIZE: int = 200
const RING_CELL := Vector2i(43, 31)

var fails: int = 0
var meta: Dictionary = {}


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAMPS_META))
	check("stamps JSON parses", parsed is Dictionary)
	if parsed is Dictionary:
		meta = parsed
		test_margins_and_face()
		test_same_seed_same_stamps()
		test_cells_differ()
		test_stamps_inside_bounds()
		test_crack_and_cover_rules()
		test_speckle_density()
	test_cell_seed()
	test_empty_meta()
	test_front_rects_column()
	test_ring_keeps_hole_open()
	test_merge_row_rects()
	print("FAILS=%d" % fails)
	quit(fails)


func _serialize(stamps: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for s: Dictionary in stamps:
		parts.append("%s@%s" % [s["name"], s["pos"]])
	return ",".join(parts)


func test_margins_and_face() -> void:
	var m: Dictionary = Painter.margins(meta)
	check("margins read from JSON are 3/3/3/4", m["left"] == 3 and m["right"] == 3 and m["top"] == 3 and m["bottom"] == 4)
	check("face of 43x31 is (3,3,37,24)", Painter.face_rect(Vector2i(43, 31), meta) == Rect2i(3, 3, 37, 24))
	check("fallback margins when JSON has none", Painter.margins({})["bottom"] == 4)
	check("slab rect drops the 1 px gap", Painter.slab_rect(Vector2i(43, 31)) == Rect2i(0, 0, 42, 30))


func test_same_seed_same_stamps() -> void:
	var ok := true
	for size: Vector2i in CELL_SIZES:
		for i: int in 20:
			var seed: int = Painter.cell_seed(i % 2, i / 2, i % 3)
			var a: Array[Dictionary] = Painter.pick_stamps(size, seed, meta)
			var b: Array[Dictionary] = Painter.pick_stamps(size, seed, meta)
			if _serialize(a) != _serialize(b):
				ok = false
	check("same seed and size give identical pick_stamps", ok)


func test_cells_differ() -> void:
	var base: String = _serialize(Painter.pick_stamps(Vector2i(43, 31), Painter.cell_seed(0, 0, 0), meta))
	var differs := false
	for i: int in 20:
		var seed: int = Painter.cell_seed(0, 1 + i % 5, i / 5)
		if _serialize(Painter.pick_stamps(Vector2i(43, 31), seed, meta)) != base:
			differs = true
			break
	check("at least one of 20 other cells differs from cell (0,0,0)", differs)


func test_stamps_inside_bounds() -> void:
	var non_chip_ok := true
	var chip_ok := true
	var any_stamp := false
	for size: Vector2i in CELL_SIZES:
		var face: Rect2i = Painter.face_rect(size, meta)
		var slab: Rect2i = Painter.slab_rect(size)
		for i: int in SEEDS_PER_SIZE:
			for s: Dictionary in Painter.pick_stamps(size, Painter.cell_seed(i % 2, i % 7, i / 7), meta):
				any_stamp = true
				var r := Rect2i(s["pos"], s["size"])
				if s["kind"] == "chip":
					if not slab.encloses(r):
						chip_ok = false
				elif not face.encloses(r):
					non_chip_ok = false
	check("some stamps were picked across %d seeds" % (SEEDS_PER_SIZE * CELL_SIZES.size()), any_stamp)
	check("every crack / cover / speckle lies inside the face", non_chip_ok)
	check("every chip lies inside the slab's outer rect (bites the edge, never the gap)", chip_ok)


func test_crack_and_cover_rules() -> void:
	var max_cracks: int = int(meta["rules"]["max_cracks_per_slab"])
	var cover_ratio: float = float(meta["rules"]["max_cover_face_ratio"])
	var cracks_ok := true
	var cover_ok := true
	var seen_crack := false
	var seen_cover := false
	for size: Vector2i in CELL_SIZES:
		var face: Rect2i = Painter.face_rect(size, meta)
		var face_area: int = face.size.x * face.size.y
		for i: int in SEEDS_PER_SIZE:
			var cracks := 0
			var cover_area := 0
			for s: Dictionary in Painter.pick_stamps(size, Painter.cell_seed(1, i % 7, i / 7), meta):
				var sz: Vector2i = s["size"]
				if s["kind"] == "crack":
					cracks += 1
					seen_crack = true
				elif s["kind"] == "cover":
					cover_area += sz.x * sz.y
					seen_cover = true
			if cracks > max_cracks:
				cracks_ok = false
			if float(cover_area) > float(face_area) * cover_ratio:
				cover_ok = false
	check("cracks and covers both occur", seen_crack and seen_cover)
	check("never more than %d cracks per slab" % max_cracks, cracks_ok)
	check("cover stamps never exceed %d%% of the face area" % int(cover_ratio * 100.0), cover_ok)


## The 4 % speckle rule is a density of the stamp art: count opaque pixels of each speckle stamp
## on the real sheet against the smallest face in play.
func test_speckle_density() -> void:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(STAMPS_PNG))
	check("stamps PNG loads", img != null)
	if img == null:
		return
	check("stamps PNG is 96x48", img.get_width() == 96 and img.get_height() == 48)
	var smallest: Rect2i = Painter.face_rect(CELL_SIZES[0], meta)
	var budget: float = float(smallest.size.x * smallest.size.y) * float(meta["rules"]["speckle_max_face_ratio"])
	var ok := true
	var seen := false
	for s: Dictionary in meta["stamps"]:
		if s["kind"] != "speckle":
			continue
		seen = true
		var r: Array = s["rect"]
		var opaque := 0
		for y: int in int(r[3]):
			for x: int in int(r[2]):
				if img.get_pixel(int(r[0]) + x, int(r[1]) + y).a > 0.0:
					opaque += 1
		if float(opaque) > budget:
			ok = false
			print("  speckle %s has %d opaque px, budget %.1f" % [s["name"], opaque, budget])
	check("speckle stamps exist", seen)
	check("each speckle stamp stays under 4%% of the smallest face (%dx%d)" % [smallest.size.x, smallest.size.y], ok)


func test_cell_seed() -> void:
	var a: int = Painter.cell_seed(0, 2, 1)
	check("cell_seed is stable", a == Painter.cell_seed(0, 2, 1))
	check("cell_seed is non-negative", a >= 0 and Painter.cell_seed(1, 6, 5) >= 0)
	var seeds: Dictionary = {}
	for side: int in 2:
		for col: int in 7:
			for row: int in 6:
				seeds[Painter.cell_seed(side, col, row)] = true
	check("cell_seed distinct over 2x7x6 cells", seeds.size() == 84)


func test_empty_meta() -> void:
	var picked: Array[Dictionary] = Painter.pick_stamps(Vector2i(43, 31), 7, {})
	check("empty meta picks nothing and does not crash", picked.is_empty())
	check("tiny cell picks nothing", Painter.pick_stamps(Vector2i(4, 4), 7, meta).is_empty())


func test_front_rects_column() -> void:
	var top := Rect2i(100, 100, 43, 31)
	var bottom := Rect2i(100, 131, 43, 31)
	var cells: Array[Rect2i] = [top, bottom]
	var below: Callable = func(i: int) -> bool: return i == 0
	var faces: Array[Rect2i] = Painter.platform_front_rects(cells, below)
	check("one face for the column (only the bottom cell has nothing below)", faces.size() == 1)
	if faces.size() == 1:
		var expected := Rect2i(bottom.position.x - 6, bottom.end.y + 6 - 1, bottom.size.x + 12, 12)
		check("face sits on the deck's last row, deck-wide, 12 px tall", faces[0] == expected)
	var decks: Array[Rect2i] = Painter.platform_deck_rects(cells)
	check("deck grows the cell by 6 px on every side", decks[0] == top.grow(6) and decks[1] == bottom.grow(6))


## A 3x3 ring (centre missing): every ring cell is a cell; the hole keeps an open interior.
func test_ring_keeps_hole_open() -> void:
	var origin := Vector2i(200, 80)
	var cells: Array[Rect2i] = []
	var hole: Rect2i = Rect2i(origin + Vector2i(RING_CELL.x, RING_CELL.y), RING_CELL)
	for row: int in 3:
		for col: int in 3:
			if col == 1 and row == 1:
				continue
			cells.append(Rect2i(origin + Vector2i(col * RING_CELL.x, row * RING_CELL.y), RING_CELL))
	var below: Callable = func(i: int) -> bool:
		var c: Rect2i = cells[i]
		for o: Rect2i in cells:
			if o.position == Vector2i(c.position.x, c.end.y):
				return true
		return false
	var faces: Array[Rect2i] = Painter.platform_front_rects(cells, below)
	check("ring: faces under the bottom row and under the cell above the hole", faces.size() == 4)
	var decks: Array[Rect2i] = Painter.platform_deck_rects(cells)
	# Open interior: the hole minus the 6 px deck ring, minus the 12 px face + 4 px shadow
	# hanging from the cell above (deck 6 - 1 + 12 + 4 = 21 rows).
	var open := Rect2i(hole.position.x + 6, hole.position.y + 21, hole.size.x - 12, hole.size.y - 27)
	var covered := false
	for d: Rect2i in decks:
		if d.intersects(open):
			covered = true
	for f: Rect2i in faces:
		var with_shadow := Rect2i(f.position, Vector2i(f.size.x, f.size.y + 4))
		if with_shadow.intersects(open):
			covered = true
	check("ring: the hole's interior (%s) is untouched by deck, face and shadow" % open, not covered)
	var rim := Rect2i(hole.position.x + 1, hole.position.y + hole.size.y / 2, 1, 1)
	var rim_covered := false
	for d: Rect2i in decks:
		if d.intersects(rim):
			rim_covered = true
	check("ring: the hole's 6 px rim is deck", rim_covered)
	var merged: Array[Rect2i] = Painter.merge_row_rects(faces)
	check("ring: the three bottom faces merge into one span, the hole face stays", merged.size() == 2)


func test_merge_row_rects() -> void:
	var a := Rect2i(0, 10, 55, 12)
	var b := Rect2i(43, 10, 55, 12)
	var c := Rect2i(0, 40, 55, 12)
	var merged: Array[Rect2i] = Painter.merge_row_rects([b, c, a] as Array[Rect2i])
	check("overlapping faces on one row merge", merged.size() == 2 and merged[0] == Rect2i(0, 10, 98, 12))
	check("faces on another row stay separate", merged[1] == c)
	var touching: Array[Rect2i] = Painter.merge_row_rects([Rect2i(0, 0, 10, 12), Rect2i(10, 0, 10, 12)] as Array[Rect2i])
	check("touching faces merge too", touching.size() == 1 and touching[0].size.x == 20)

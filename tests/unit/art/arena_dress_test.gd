extends SceneTree
## Arena integration (2026-11-12, World Map v2: the arena is part of its region): SlabPainter.joint_segments picks
## 1 px joint lines only between neighbouring real cells, deterministically; the rim strip over the front faces
## can never reach a cell (rise clamped under DECK_MARGIN); every dressed region resolves its face / rim / foot
## strips from disk and SupportLayer loads the foot strip; the forest keeps its approved look (no rim, no foot).
## Run: godot --headless --path . -s res://tests/unit/art/arena_dress_test.gd

const DRESSED: Array[String] = ["hellfire", "sands", "swamp", "dungeon", "ice_tower", "sky_isles"]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_joint_segments_only_between_neighbours_and_stable()
	test_rim_strip_never_reaches_a_cell()
	test_dressed_regions_resolve_their_strips()
	test_forest_untouched()
	test_dressed_regions_have_their_own_flagstone_sheet_and_perimeter()
	test_perimeter_cover_draws_nothing_on_a_closed_cell()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# A 3x2 block of 40x30 cells with the top-right cell missing: joints exist only where both sides are real cells.
func _board() -> Array:
	var rects: Array[Rect2i] = []
	var coords: Array[Vector2i] = []
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]:
		rects.append(Rect2i(100 + c.x * 40, 80 + c.y * 30, 40, 30))
		coords.append(c)
	return [rects, coords]


func test_joint_segments_only_between_neighbours_and_stable() -> void:
	var b: Array = _board()
	var all: Array[Rect2i] = SlabPainter.joint_segments(b[0], b[1], 1.0)
	# Right joints: (0,0)-(1,0), (0,1)-(1,1), (1,1)-(2,1); down joints: (0,0)-(0,1), (1,0)-(1,1) = 5 segments.
	_check("test_five_joints_at_chance_1", all.size() == 5, str(all.size()))
	var inside: bool = true
	for s: Rect2i in all:
		inside = inside and (s.size.x == 1 or s.size.y == 1)
		# A joint lies on a cell's last column / row, which always has a real cell on the other side here.
		var on_gap: bool = false
		for r: Rect2i in b[0] as Array[Rect2i]:
			if (s.size.x == 1 and s.position.x == r.end.x - 1 and s.position.y >= r.position.y and s.end.y <= r.end.y) \
					or (s.size.y == 1 and s.position.y == r.end.y - 1 and s.position.x >= r.position.x and s.end.x <= r.end.x):
				on_gap = true
		inside = inside and on_gap
	_check("test_joints_are_1_px_lines_on_cell_gaps", inside)
	var none: Array[Rect2i] = SlabPainter.joint_segments(b[0], b[1], 0.0)
	_check("test_no_joints_at_chance_0", none.is_empty())
	var a1: Array[Rect2i] = SlabPainter.joint_segments(b[0], b[1], 0.5)
	var a2: Array[Rect2i] = SlabPainter.joint_segments(b[0], b[1], 0.5)
	_check("test_same_board_same_joints", a1 == a2)
	var a3: Array[Rect2i] = SlabPainter.joint_segments(b[0], b[1], 0.5, 7)
	_check("test_a_salt_changes_the_pick_or_keeps_it_but_never_adds_outer_edges", a3.size() <= 5)
	# No joint on the missing (2,0): the (1,0) cell has no right neighbour, (2,1) has no cell above.
	var r10: Rect2i = (b[0] as Array[Rect2i])[1]
	var leak: bool = false
	for s: Rect2i in all:
		if s.size.x == 1 and s.position.x == r10.end.x - 1 and s.position.y < r10.end.y:
			leak = true
	_check("test_no_joint_towards_a_missing_cell", not leak)


func test_rim_strip_never_reaches_a_cell() -> void:
	var b: Array = _board()
	var rects: Array[Rect2i] = b[0]
	var coords: Array[Vector2i] = b[1]
	var below: Callable = func(i: int) -> bool: return coords.has(coords[i] + Vector2i.DOWN)
	var faces: Array[Rect2i] = SlabPainter.merge_row_rects(SlabPainter.platform_front_rects(rects, below))
	_check("test_faces_exist_under_the_lower_edges", faces.size() >= 1)
	var ok: bool = true
	for rise: int in [0, 3, 5, 9, 40]:
		var up: int = clampi(rise, 0, SlabPainter.DECK_MARGIN - 1)
		for f: Rect2i in faces:
			var top: int = f.position.y - up
			for r: Rect2i in rects:
				if r.position.x < f.end.x and r.end.x > f.position.x and r.end.y > top and r.position.y < top:
					# a cell overlapping the face in x whose bottom lies below the rim's top: only allowed if that
					# cell is not the one the face hangs under (its bottom == deck.end.y - DECK_MARGIN <= top).
					ok = ok and r.end.y <= top
	_check("test_rim_top_stays_under_every_cell_bottom_for_any_rise", ok)


func test_dressed_regions_resolve_their_strips() -> void:
	ArtAssets.clear_cache()
	for id: String in DRESSED:
		var face: Texture2D = ArtAssets.region_texture(id, "platform.face_tile")
		var rim: Texture2D = ArtAssets.region_texture(id, "platform.rim_tile")
		var foot: Texture2D = ArtAssets.region_texture(id, "support.foot_tile")
		_check("test_%s_face_rim_foot_on_disk" % id, face != null and rim != null and foot != null)
		if face != null:
			_check("test_%s_face_is_231x12" % id, face.get_width() == 231 and face.get_height() == 12)
		var layer := SupportLayer.new()
		layer.set_region_id(id)
		_check("test_%s_support_layer_loads_the_foot_strip" % id, layer.get_foot_texture() != null)
		layer.free()
		var pal: Dictionary = ArtAssets.region(id).get("platform", {})
		_check("test_%s_rim_rise_within_the_deck_margin" % id, int(pal.get("rim_rise", 0)) < SlabPainter.DECK_MARGIN)


func test_forest_untouched() -> void:
	ArtAssets.clear_cache()
	_check("test_forest_has_no_rim", ArtAssets.region_texture("forest", "platform.rim_tile") == null)
	_check("test_forest_has_no_foot_strip", ArtAssets.region_texture("forest", "support.foot_tile") == null)
	_check("test_forest_has_plain_joints", not (ArtAssets.region("forest").get("platform", {}) as Dictionary).has("joints"))
	# 2026-11-12 (surface integration): the approved PixelLab sheet stays; only roots from the perimeter were added.
	var slab: Dictionary = ArtAssets.region("forest").get("slab", {})
	_check("test_forest_keeps_its_pixellab_flagstones", String(slab.get("flagstones", "")).ends_with("env_slab_forest_flagstones.png"))
	_check("test_forest_perimeter_is_roots", String((slab.get("perimeter", {}) as Dictionary).get("kind", "")) == "root")


# 2026-11-12 (surface integration): every dressed region draws its own procedural flagstone sheet (16 tiles, 64 px,
# one weight per tile) through the forest's hook, and names a perimeter cover of a known kind with a depth that
# keeps it inside the cell's edge band.
func test_dressed_regions_have_their_own_flagstone_sheet_and_perimeter() -> void:
	ArtAssets.clear_cache()
	var sheets: Array[String] = []
	for id: String in DRESSED:
		var tex: Texture2D = ArtAssets.region_texture(id, "slab.flagstones")
		_check("test_%s_flagstone_sheet_on_disk" % id, tex != null)
		if tex != null:
			_check("test_%s_sheet_is_256x256" % id, tex.get_width() == 256 and tex.get_height() == 256)
			sheets.append(String((ArtAssets.region(id).get("slab", {}) as Dictionary).get("flagstones", "")))
		var meta: Dictionary = (ArtAssets.region(id).get("slab", {}) as Dictionary).get("flagstone_meta", {})
		_check("test_%s_meta_size_64_border_6_16_weights" % id, int(meta.get("size", 0)) == 64 and int(meta.get("border", 0)) == 6 and (meta.get("weights", []) as Array).size() == 16)
		var perim: Dictionary = (ArtAssets.region(id).get("slab", {}) as Dictionary).get("perimeter", {})
		_check("test_%s_perimeter_kind_known" % id, ["drift", "clump", "root", "rime"].has(String(perim.get("kind", ""))))
		_check("test_%s_perimeter_depth_small" % id, int(perim.get("depth", 99)) <= 8)
	# six different files, not one sheet shared
	var unique: Dictionary = {}
	for s: String in sheets:
		unique[s] = true
	_check("test_six_regions_six_different_sheets", unique.size() == DRESSED.size(), str(unique.size()))


# The perimeter cover is driven by open sides: a cell surrounded by cells gets nothing; open sides get rects that all
# lie inside the cell, the same list for the same seed (pure SlabPainter.perimeter_cover_rects).
func test_perimeter_cover_draws_nothing_on_a_closed_cell() -> void:
	var cell := Rect2i(100, 80, 40, 30)
	var cfg: Dictionary = {"kind": "drift", "color": "#C8B890", "depth": 6, "chance": 1.0}
	var closed: Dictionary = {"left": false, "top": false, "right": false, "bottom": false}
	_check("test_closed_cell_no_cover", SlabPainter.perimeter_cover_rects(cell, 1234, closed, cfg).is_empty())
	var open: Dictionary = {"left": true, "top": false, "right": false, "bottom": true}
	for kind: String in ["drift", "clump", "root", "rime"]:
		cfg["kind"] = kind
		var rects: Array[Dictionary] = SlabPainter.perimeter_cover_rects(cell, 1234, open, cfg)
		_check("test_%s_open_sides_draw_cover" % kind, rects.size() > 0)
		var inside: bool = true
		for r: Dictionary in rects:
			inside = inside and cell.encloses(r["rect"] as Rect2i)
		_check("test_%s_cover_stays_inside_the_cell" % kind, inside)
		_check("test_%s_cover_is_deterministic" % kind, SlabPainter.perimeter_cover_rects(cell, 1234, open, cfg) == rects)

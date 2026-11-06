extends SceneTree
## Generated flagstones (2026-11-06, forest-integration step: redo the whole floor): SlabPainter.nine_crop_spans
## keeps the border, never stretches (every source span as long as its target span), centres the middle window or
## repeats it; flagstone_index is deterministic and honours the weights; the forest sheet loads with 16 64 px tiles.
## Run: godot --headless --path . -s res://tests/unit/art/flagstone_test.gd

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_nine_crop_never_stretches_and_covers_the_target()
	test_flagstone_index_deterministic_and_weighted()
	test_forest_sheet_loads()
	test_divider_only_over_decks_that_cross_it()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_nine_crop_never_stretches_and_covers_the_target() -> void:
	for target: int in [27, 37, 45, 63, 64, 90, 140]:
		var spans: Array = SlabPainter.nine_crop_spans(target, 64, 6)
		var covered: int = 0
		var ok: bool = true
		var next: int = 0
		for sp: Array in spans:
			ok = ok and int(sp[0]) == next and int(sp[2]) >= 0 and int(sp[1]) + int(sp[2]) <= 64
			next = int(sp[0]) + int(sp[2])
			covered += int(sp[2])
		_check("test_spans_tile_the_%d_px_target_exactly_from_inside_the_source" % target, ok and covered == target, str(spans))
		_check("test_border_kept_at_%d" % target, int(spans[0][1]) == 0 and int(spans[spans.size() - 1][1]) == 64 - int(spans[spans.size() - 1][2]))
	var mid: Array = SlabPainter.nine_crop_spans(37, 64, 6)[1]
	_check("test_shorter_middle_is_a_centred_window", int(mid[1]) == 6 + (52 - 25) / 2 and int(mid[2]) == 25, str(mid))


func test_flagstone_index_deterministic_and_weighted() -> void:
	var w: Array = [3, 3, 3, 3, 3, 3, 2, 1, 3, 3, 3, 3, 3, 3, 3, 1]
	_check("test_same_seed_same_stone", SlabPainter.flagstone_index(12345, w) == SlabPainter.flagstone_index(12345, w))
	var counts: Array[int] = []
	counts.resize(16)
	for s: int in 4000:
		counts[SlabPainter.flagstone_index(s, w)] += 1
	_check("test_every_stone_used", counts.all(func(c: int) -> bool: return c > 0))
	_check("test_heavy_moss_stones_rare", counts[7] < counts[0] / 2 and counts[15] < counts[0] / 2, str(counts))
	_check("test_zero_weight_never_drawn", (func() -> bool:
		for s2: int in 500:
			if SlabPainter.flagstone_index(s2, [1, 0, 1]) == 1:
				return false
		return true).call())


func test_forest_sheet_loads() -> void:
	ArtAssets.clear_cache()
	var tex: Texture2D = ArtAssets.region_texture("forest", "slab.flagstones")
	_check("test_forest_flagstone_sheet_loaded", tex != null)
	if tex != null:
		_check("test_sheet_is_4x4_of_64", tex.get_width() == 256 and tex.get_height() == 256)
	var meta: Dictionary = (ArtAssets.region("forest").get("slab", {}) as Dictionary).get("flagstone_meta", {})
	_check("test_meta_weights_one_per_tile", (meta.get("weights", []) as Array).size() == int(meta.get("count", 0)) and int(meta.get("count", 0)) == 16)


# 2026-11-06: the divider between the halves is drawn only over decks crossing it (no line through a cross arena's
# open notch), touching decks merged into one segment.
func test_divider_only_over_decks_that_cross_it() -> void:
	var decks: Array[Rect2i] = [Rect2i(90, 10, 20, 30), Rect2i(90, 40, 20, 30), Rect2i(90, 100, 20, 30), Rect2i(0, 60, 50, 30)]
	var segs: Array[Rect2i] = SlabPainter.divider_segments(decks, 100)
	_check("test_divider_two_segments_with_a_gap", segs == ([Rect2i(100, 10, 1, 60), Rect2i(100, 100, 1, 30)] as Array[Rect2i]), str(segs))
	_check("test_divider_none_when_no_deck_crosses", SlabPainter.divider_segments(decks, 300).is_empty())

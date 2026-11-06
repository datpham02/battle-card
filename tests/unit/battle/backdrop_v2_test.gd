extends SceneTree
## Misty Forest background redesign (2026-11-06): the forest draws the regenerated far backdrop (bg_forest_far_v2,
## the full 800x360 art canvas, opaque) and turns the old near mist strip off (`backdrop.near_enabled` false), since
## that strip read as white specks over the new canopy. A region without the flag keeps its near strip.
## Run: godot --headless --path . -s res://tests/unit/battle/backdrop_v2_test.gd

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	ArtAssets.clear_cache()
	var far: Texture2D = ArtAssets.region_texture("forest", "backdrop.far")
	_check("test_forest_far_is_the_v4_backdrop", far != null and far.resource_path.ends_with("bg_forest_far_v4.png"), far.resource_path if far != null else "null")
	if far != null:
		var img: Image = far.get_image()
		_check("test_v2_fills_the_art_canvas", img.get_width() == int(ScreenLayout.ART_CANVAS_WIDTH) and img.get_height() == int(ScreenLayout.ART_CANVAS_HEIGHT))
		var opaque: bool = true
		for p: Vector2i in [Vector2i(0, 0), Vector2i(799, 0), Vector2i(0, 359), Vector2i(799, 359), Vector2i(400, 180)]:
			opaque = opaque and img.get_pixelv(p).a > 0.99
		_check("test_v2_corners_and_centre_opaque", opaque)
	var layer := BackdropLayer.new()
	layer.set_region_id("forest")
	_check("test_forest_near_strip_off", layer.get("_near") == null)
	layer.free()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

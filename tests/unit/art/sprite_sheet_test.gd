extends SceneTree
## Story 047 Part C: SpriteSheet loader. Headless, deterministic. The fixture JSON (a trimmed
## kiem_si sheet) is parsed with `from_json` and never touches a texture; the two shipped sheets
## are loaded through `load_unit` and checked against the Story 045 Part A tag table.
## Run: godot --headless --path . -s res://tests/unit/art/sprite_sheet_test.gd

const SpriteSheetScript := preload("res://src/art/sprite_sheet.gd")

const FIXTURE := "res://tests/fixtures/art/unit_sheet_fixture.json"
const FIXTURE_IMAGE := "res://tests/fixtures/art/unit_fixture_sheet.png"
const FIXTURE_CLIPS: Array[String] = ["idle", "step", "cast_gesture", "hit", "defeat", "fall"]
## clip -> [durations_ms, loop]
const FIXTURE_FACTS: Dictionary = {
	"idle": [[400, 400], "loop"],
	"step": [[300, 300], "loop"],
	"cast_gesture": [[80, 120], "once"],
	"hit": [[120], "once"],
	"defeat": [[150, 150], "hold_last"],
	"fall": [[0], "hold"],
}
const FIXTURE_FRAME := Vector2i(40, 48)
## unit id -> [clips in frameTags order, frame size, facing]
const REAL_SHEETS: Dictionary = {
	"kiem_si": [["idle", "step", "cast_gesture", "hit", "victory", "defeat", "fall", "awaken"], Vector2i(96, 70), "right"],
	"goblin_scout": [["idle", "step", "windup", "hit", "down"], Vector2i(64, 52), "left"],
}

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	SpriteSheetScript.clear_cache()
	test_fixture_clips_and_facing()
	test_fixture_rects_and_durations()
	test_fixture_missing_clip_and_texture()
	test_from_json_malformed_is_null()
	test_real_sheets_match_story_045_table()
	test_load_unit_missing_is_null_and_cached()
	print("FAILS=%d" % fails)
	quit(fails)


func _load_fixture() -> SpriteSheetScript:
	var file := FileAccess.open(FIXTURE, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	return SpriteSheetScript.from_json(data, FIXTURE_IMAGE)


func test_fixture_clips_and_facing() -> void:
	# Arrange / Act
	var sheet := _load_fixture()
	# Assert
	check("fixture parses", sheet != null)
	if sheet == null:
		return
	check("fixture has 6 clips in frameTags order", sheet.clip_names() == FIXTURE_CLIPS)
	check("fixture clip_count is 6", sheet.clip_count() == 6)
	check("fixture facing is right", sheet.facing() == "right")
	check("fixture frame_size is 40x48 (first frame)", sheet.frame_size() == FIXTURE_FRAME)
	check("fixture image_size reads meta.size", sheet.image_size() == Vector2i(81, 293))
	check("fixture unit_id reads meta.tessera.unit", sheet.unit_id() == "fixture")
	check("fixture image_path is the one passed in", sheet.image_path() == FIXTURE_IMAGE)
	var all_ok := true
	for clip_name: String in FIXTURE_CLIPS:
		all_ok = all_ok and sheet.has_clip(clip_name)
	check("has_clip true for every fixture clip", all_ok)


func test_fixture_rects_and_durations() -> void:
	var sheet := _load_fixture()
	if sheet == null:
		return
	# idle: two cells on row 0 with a 1 px gutter
	var idle: Dictionary = sheet.clip("idle")
	var idle_frames: Array[Rect2i] = idle["frames"]
	check("idle has 2 frames", idle_frames.size() == 2)
	check("idle frame 0 rect is (0,0,40,48)", idle_frames[0] == Rect2i(0, 0, 40, 48))
	check("idle frame 1 rect is (41,0,40,48)", idle_frames[1] == Rect2i(41, 0, 40, 48))
	check("clip name key matches", String(idle["name"]) == "idle")
	# fall: row 5 (y = 5 * 49)
	var fall_frames: Array[Rect2i] = sheet.clip("fall")["frames"]
	check("fall frame 0 rect is (0,245,40,48)", fall_frames.size() == 1 and fall_frames[0] == Rect2i(0, 245, 40, 48))
	# durations and loop kind per tag
	for clip_name: String in FIXTURE_FACTS:
		var facts: Array = FIXTURE_FACTS[clip_name]
		var c: Dictionary = sheet.clip(clip_name)
		var durations: Array[int] = c["durations_ms"]
		check("%s durations_ms == %s" % [clip_name, str(facts[0])], durations == (facts[0] as Array))
		check("%s loop == %s" % [clip_name, facts[1]], String(c["loop"]) == String(facts[1]))
		check("%s frames and durations have the same length" % clip_name, (c["frames"] as Array).size() == durations.size())


func test_fixture_missing_clip_and_texture() -> void:
	var sheet := _load_fixture()
	if sheet == null:
		return
	check("has_clip('victory') is false on the trimmed fixture", not sheet.has_clip("victory"))
	check("clip('victory') is {}", sheet.clip("victory").is_empty())
	check("has_clip('') is false", not sheet.has_clip(""))
	check("texture() of a missing PNG is null (no error)", sheet.texture() == null)
	check("texture() again is still null (tried once)", sheet.texture() == null)


func test_from_json_malformed_is_null() -> void:
	check("from_json({}) is null", SpriteSheetScript.from_json({}, "") == null)
	check("from_json without frameTags is null",
		SpriteSheetScript.from_json({"frames": [{"frame": {"x": 0, "y": 0, "w": 4, "h": 4}, "duration": 1}]}, "") == null)
	check("from_json with an out-of-range tag yields null (no clip)",
		SpriteSheetScript.from_json({
			"frames": [{"frame": {"x": 0, "y": 0, "w": 4, "h": 4}, "duration": 1}],
			"meta": {"frameTags": [{"name": "idle", "from": 0, "to": 3}]},
		}, "") == null)
	# Loop and facing fall back to defaults when tessera is absent or carries unknown values.
	var bare := SpriteSheetScript.from_json({
		"frames": [{"frame": {"x": 0, "y": 0, "w": 4, "h": 4}, "duration": 1}],
		"meta": {"frameTags": [{"name": "idle", "from": 0, "to": 0}], "tessera": {"facing": "up", "loop": {"idle": "bounce"}}},
	}, "")
	check("unknown loop kind falls back to 'loop'", bare != null and String(bare.clip("idle")["loop"]) == "loop")
	check("unknown facing falls back to 'right'", bare != null and bare.facing() == "right")


func test_real_sheets_match_story_045_table() -> void:
	for unit_id: String in REAL_SHEETS:
		var facts: Array = REAL_SHEETS[unit_id]
		var sheet := SpriteSheetScript.load_unit(unit_id)
		check("load_unit('%s') is not null" % unit_id, sheet != null)
		if sheet == null:
			continue
		check("%s exposes exactly the Story 045 tags" % unit_id, sheet.clip_names() == (facts[0] as Array[String]))
		check("%s frame_size is %s" % [unit_id, str(facts[1])], sheet.frame_size() == (facts[1] as Vector2i))
		check("%s facing is %s" % [unit_id, facts[2]], sheet.facing() == String(facts[2]))
		check("%s unit_id is set by load_unit" % unit_id, sheet.unit_id() == unit_id)
		check("%s image_path points at the sheet PNG" % unit_id, sheet.image_path() == SpriteSheetScript.image_path_for(unit_id))
		check("load_unit('%s') is cached (same instance)" % unit_id, SpriteSheetScript.load_unit(unit_id) == sheet)
		# Texture is lazy and may be null headless; when it loads it must be the whole sheet.
		var tex: Texture2D = sheet.texture()
		check("%s texture is null or sized like meta.size" % unit_id, tex == null or Vector2i(tex.get_size()) == sheet.image_size())
	# Spot checks from the table: kiem_si cast_gesture 80 + 120 once; goblin windup 0 ms hold.
	var ks := SpriteSheetScript.load_unit("kiem_si")
	if ks != null:
		var cast: Dictionary = ks.clip("cast_gesture")
		check("kiem_si cast_gesture is the v3 7-frame once clip", (cast["durations_ms"] as Array[int]) == [50, 40, 40, 50, 50, 60, 80] and String(cast["loop"]) == "once")
		check("kiem_si defeat is hold_last", String(ks.clip("defeat")["loop"]) == "hold_last")
	var gs := SpriteSheetScript.load_unit("goblin_scout")
	if gs != null:
		var windup: Dictionary = gs.clip("windup")
		check("goblin_scout windup is [100, 0] hold_last (the 0 ms frame holds until the telegraph ends)", (windup["durations_ms"] as Array[int]) == [100, 0] and String(windup["loop"]) == "hold_last")
		check("goblin_scout down is hold_last", String(gs.clip("down")["loop"]) == "hold_last")
	# clear_cache drops the instances.
	SpriteSheetScript.clear_cache()
	check("clear_cache yields a fresh instance", SpriteSheetScript.load_unit("kiem_si") != ks)


func test_load_unit_missing_is_null_and_cached() -> void:
	check("load_unit('nobody') is null", SpriteSheetScript.load_unit("nobody") == null)
	check("load_unit('nobody') again is null (warned once, no error)", SpriteSheetScript.load_unit("nobody") == null)
	check("json_path builds the unit path", SpriteSheetScript.json_path("x") == "res://assets/art/units/unit_x_sheet.json")

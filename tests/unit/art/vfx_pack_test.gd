extends SceneTree
## Story 047 Part D: PixelLab VFX pack loader (VfxPack) and the status pack cache (StatusPacks).
## Headless, deterministic. The fixture manifest is parsed without any texture; the six real
## packs are checked file-by-file against their candidate sources by SHA-256.
## Run: godot --headless --path . -s res://tests/unit/art/vfx_pack_test.gd

const VfxPackScript := preload("res://src/art/vfx_pack.gd")
const StatusPacksScript := preload("res://src/art/status_packs.gd")

const FIXTURE := "res://tests/fixtures/art/vfx_manifest_fixture.json"
const CANDIDATES := "res://design/assets/candidates/slice1-fx/status-vfx"
const KINDS: Array[String] = ["burn", "frozen", "chill"]
const FRAME_KINDS: Array[String] = ["hero", "goblin"]
const COPIED_FILES: Array[String] = ["manifest.json", "behind.png", "front.png", "whole.png"]

## Fixture facts (burn-hero, trimmed): 12 frames, 4 columns, `whole` 18x33 at -9/-30.
const FX_FRAME_MS := 83
const FX_FRAMES := 12
const FX_COLUMNS := 4
const FX_WHOLE_SIZE := Vector2i(18, 33)
const FX_WHOLE_OFFSET := Vector2i(-9, -30)
const FX_BEHIND_OFFSET := Vector2i(-9, -27)
const FX_FRONT_OFFSET := Vector2i(-8, -30)
const FX_CANVAS := Vector2i(33, 52)
const FX_ANCHOR := Vector2i(16, 46)

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	test_fixture_header_and_clips()
	test_fixture_regions_follow_column_math()
	test_fixture_offsets()
	test_frame_at_loop_and_hold()
	test_texture_absent_draws_nothing()
	test_missing_and_malformed_manifests_are_null()
	test_real_packs_load_and_match_candidates()
	test_status_packs_cache()
	print("FAILS=%d" % fails)
	quit(fails)


func test_fixture_header_and_clips() -> void:
	var pack: VfxPackScript = VfxPackScript.load_manifest(FIXTURE)
	check("fixture: manifest loads", pack != null)
	if pack == null:
		return
	check("fixture: frame_ms %d" % FX_FRAME_MS, pack.frame_ms() == FX_FRAME_MS)
	check("fixture: loop true", pack.is_loop())
	check("fixture: canvas 33x52", pack.canvas_size() == FX_CANVAS)
	check("fixture: anchor 16,46", pack.anchor() == FX_ANCHOR)
	check("fixture: 3 clips", pack.clip_count() == 3)
	var names := pack.clip_names()
	names.sort()
	check("fixture: clip names whole/behind/front", names == ["behind", "front", "whole"])
	check("fixture: has_clip behind/front", pack.has_clip("behind") and pack.has_clip("front"))
	check("fixture: no part clip (trimmed)", not pack.has_clip("part-on_fire") and pack.clip("part-on_fire").is_empty())
	check("fixture: depth strings", pack.clip("behind")["depth"] == "behind" and pack.clip("front")["depth"] == "front" and pack.clip("whole")["depth"] == "both")
	check("fixture: frames per clip %d" % FX_FRAMES, int(pack.clip("whole")["frames"]) == FX_FRAMES and int(pack.clip("front")["frames"]) == FX_FRAMES)


func test_fixture_regions_follow_column_math() -> void:
	var pack: VfxPackScript = VfxPackScript.load_manifest(FIXTURE)
	if pack == null:
		check("fixture regions: pack loads", false)
		return
	var whole := pack.clip("whole")
	var regions: Array[Rect2i] = whole["regions"]
	check("fixture regions: one per frame", regions.size() == FX_FRAMES)
	check("fixture regions: frame_size 18x33", whole["frame_size"] == FX_WHOLE_SIZE)
	check("fixture regions: [0] at origin", regions[0] == Rect2i(Vector2i.ZERO, FX_WHOLE_SIZE))
	# Frame 5 with 4 columns sits at column 1, row 1.
	check("fixture regions: [5] = column 1 row 1", regions[5] == Rect2i(FX_WHOLE_SIZE.x * 1, FX_WHOLE_SIZE.y * 1, FX_WHOLE_SIZE.x, FX_WHOLE_SIZE.y))
	check("fixture regions: [11] = column 3 row 2", regions[11] == Rect2i(FX_WHOLE_SIZE.x * 3, FX_WHOLE_SIZE.y * 2, FX_WHOLE_SIZE.x, FX_WHOLE_SIZE.y))
	var behind_regions: Array[Rect2i] = pack.clip("behind")["regions"]
	check("fixture regions: behind rows use its own 30 px height", behind_regions[FX_COLUMNS] == Rect2i(0, 30, 18, 30))


func test_fixture_offsets() -> void:
	var pack: VfxPackScript = VfxPackScript.load_manifest(FIXTURE)
	if pack == null:
		check("fixture offsets: pack loads", false)
		return
	check("fixture offsets: whole -9/-30", pack.clip("whole")["offset"] == FX_WHOLE_OFFSET)
	check("fixture offsets: behind -9/-27", pack.clip("behind")["offset"] == FX_BEHIND_OFFSET)
	check("fixture offsets: front -8/-30", pack.clip("front")["offset"] == FX_FRONT_OFFSET)


func test_frame_at_loop_and_hold() -> void:
	var clip := {"frames": FX_FRAMES}
	check("frame_at: 0 s -> 0 (loop)", VfxPackScript.frame_at(clip, 0.0, FX_FRAME_MS, true) == 0)
	check("frame_at: 0 s -> 0 (hold)", VfxPackScript.frame_at(clip, 0.0, FX_FRAME_MS, false) == 0)
	# 500 ms / 83 ms = 6.02 -> frame 6 either way.
	check("frame_at: 0.5 s -> 6 (loop)", VfxPackScript.frame_at(clip, 0.5, FX_FRAME_MS, true) == 6)
	check("frame_at: 0.5 s -> 6 (hold)", VfxPackScript.frame_at(clip, 0.5, FX_FRAME_MS, false) == 6)
	# 2000 ms / 83 ms = 24.1 -> raw 24: wraps to 0 when looping, holds at 11 otherwise.
	check("frame_at: 2 s -> 0 (loop wraps)", VfxPackScript.frame_at(clip, 2.0, FX_FRAME_MS, true) == 0)
	check("frame_at: 2 s -> 11 (hold clamps)", VfxPackScript.frame_at(clip, 2.0, FX_FRAME_MS, false) == FX_FRAMES - 1)
	check("frame_at: negative time -> 0", VfxPackScript.frame_at(clip, -1.0, FX_FRAME_MS, true) == 0)
	check("frame_at: empty clip -> 0", VfxPackScript.frame_at({}, 1.0, FX_FRAME_MS, true) == 0)
	check("frame_at: frame_ms 0 -> 0", VfxPackScript.frame_at(clip, 1.0, 0, true) == 0)
	# A 100 ms pack (frozen) on the same clock lands on a different frame.
	check("frame_at: 0.5 s at 100 ms -> 5", VfxPackScript.frame_at(clip, 0.5, 100, true) == 5)


func test_texture_absent_draws_nothing() -> void:
	var pack: VfxPackScript = VfxPackScript.load_manifest(FIXTURE)
	if pack == null:
		check("no texture: pack loads", false)
		return
	# The fixture names sheets that do not exist next to it: texture stays null, no error.
	check("no texture: clip texture is null", pack.clip("whole")["texture"] == null)
	var canvas := Node2D.new()
	check("no texture: draw_clip returns false", not pack.draw_clip(canvas, "whole", Vector2i(100, 200), 3))
	check("no texture: draw_clip unknown clip returns false", not pack.draw_clip(canvas, "nope", Vector2i.ZERO, 0))
	canvas.free()


func test_missing_and_malformed_manifests_are_null() -> void:
	check("load_pack: res://nowhere is null", VfxPackScript.load_pack("res://nowhere") == null)
	check("parse_manifest: non-dictionary is null", VfxPackScript.parse_manifest("not json", "res://x") == null)
	check("parse_manifest: no clips key is null", VfxPackScript.parse_manifest({"frame_ms": 83}, "res://x") == null)
	check("parse_manifest: empty clips is null", VfxPackScript.parse_manifest({"clips": []}, "res://x") == null)
	check("parse_manifest: clip without sheets is skipped", VfxPackScript.parse_manifest({"clips": [{"name": "a", "frame": {"w": 1, "h": 1}}]}, "res://x") == null)
	var minimal := VfxPackScript.parse_manifest({"clips": [{"name": "a", "frames": 2, "frame": {"w": 4, "h": 4}, "sheets": [{"file": "a.png", "columns": 2}]}]}, "res://x")
	check("parse_manifest: minimal clip loads with defaults", minimal != null and minimal.frame_ms() == VfxPackScript.DEFAULT_FRAME_MS and minimal.is_loop() and int(minimal.clip("a")["frames"]) == 2)


func test_real_packs_load_and_match_candidates() -> void:
	for kind in KINDS:
		for frame_kind in FRAME_KINDS:
			var tag := "%s/%s" % [kind, frame_kind]
			var expected_dir := "%s_%s" % [kind, frame_kind]
			check("%s: index maps to %s" % [tag, expected_dir], StatusPacksScript.pack_dir_name(kind, frame_kind) == expected_dir)
			var pack_dir: String = StatusPacksScript.STATUS_DIR.path_join(expected_dir)
			var pack: VfxPackScript = VfxPackScript.load_pack(pack_dir)
			check("%s: manifest parses" % tag, pack != null)
			if pack == null:
				continue
			check("%s: behind and front clips exist" % tag, pack.has_clip("behind") and pack.has_clip("front"))
			check("%s: frame_ms > 0 and loop" % tag, pack.frame_ms() > 0 and pack.is_loop())
			for clip_name in ["behind", "front"]:
				var c := pack.clip(clip_name)
				var regions: Array[Rect2i] = c["regions"]
				check("%s: %s has one region per frame" % [tag, clip_name], regions.size() == int(c["frames"]) and regions.size() > 0)
				check("%s: %s depth matches name" % [tag, clip_name], c["depth"] == clip_name)
				var sheet_path: String = pack_dir.path_join(String(c["file"]))
				var image: Image = Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
				check("%s: %s sheet decodes" % [tag, clip_name], image != null)
				if image != null:
					var last: Rect2i = regions[regions.size() - 1]
					check("%s: %s regions fit the sheet" % [tag, clip_name], last.end.x <= image.get_width() and last.end.y <= image.get_height())
			var candidate_dir := "%s/pack-tessera-status-%s-%s" % [CANDIDATES, kind, frame_kind]
			for file_name in COPIED_FILES:
				var copy := pack_dir.path_join(file_name)
				var source := candidate_dir.path_join(file_name)
				check("%s: %s exists" % [tag, file_name], FileAccess.file_exists(copy))
				var same := FileAccess.file_exists(source) and FileAccess.file_exists(copy) and FileAccess.get_sha256(copy) == FileAccess.get_sha256(source) and not FileAccess.get_sha256(copy).is_empty()
				check("%s: %s sha256 equals candidate" % [tag, file_name], same)


func test_status_packs_cache() -> void:
	StatusPacksScript.clear_cache()
	var first: VfxPackScript = StatusPacksScript.pack("burn", "hero")
	check("StatusPacks: burn/hero loads", first != null)
	check("StatusPacks: same instance on second call", StatusPacksScript.pack("burn", "hero") == first)
	check("StatusPacks: unknown kind is null", StatusPacksScript.pack("poison", "hero") == null)
	check("StatusPacks: unknown frame kind is null", StatusPacksScript.pack("burn", "dragon") == null)
	check("StatusPacks: null is cached (no reload)", StatusPacksScript.pack("poison", "hero") == null)
	var kinds := StatusPacksScript.kinds()
	kinds.sort()
	check("StatusPacks: kinds burn/chill/frozen", kinds == ["burn", "chill", "frozen"])
	StatusPacksScript.clear_cache()
	var second: VfxPackScript = StatusPacksScript.pack("burn", "hero")
	check("StatusPacks: clear_cache yields a fresh instance", second != null and second != first)
	StatusPacksScript.clear_cache()

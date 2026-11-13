extends SceneTree
## P3 of the AI Game Art Workflow: a pack written by tools/fx-pipeline/pixelfx_adapter.py is a VfxPack the
## runtime reads like any other. The fixture is the adapted proof of concept (pixelfx impacts/hit-flash, steel
## ramp, 7 frames) copied from design/assets/candidates/pixelfx/impact_flash_steel_pixelfx-v1-2026-11-11.
## Headless, deterministic, no texture needed. Run:
##   godot --headless --path . -s res://tests/unit/art/pixelfx_adapter_test.gd

const VfxPackScript := preload("res://src/art/vfx_pack.gd")

const FIXTURE_DIR := "res://tests/fixtures/art/pixelfx_adapted_fixture"
const CANDIDATE_DIR := "res://design/assets/candidates/pixelfx/impact_flash_steel_pixelfx-v1-2026-11-11"

## Facts the adapter printed for the proof of concept (2026-11-11).
const FRAMES := 7
const FRAME_MS := 50
const CANVAS := Vector2i(80, 64)
const ANCHOR := Vector2i(40, 54)
const COLUMNS := 7
const PALETTE_MAX := 8

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	test_fixture_is_a_vfx_pack()
	test_one_shot_frame_clamps()
	test_provenance_and_tessera_block()
	test_candidate_matches_fixture_when_present()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func test_fixture_is_a_vfx_pack() -> void:
	var pack: VfxPack = VfxPackScript.load_pack(FIXTURE_DIR)
	check("fixture manifest parses into a VfxPack", pack != null)
	if pack == null:
		return
	check("frame_ms %d" % FRAME_MS, pack.frame_ms() == FRAME_MS)
	check("one-shot (loop false)", not pack.is_loop())
	check("canvas %s" % CANVAS, pack.canvas_size() == CANVAS)
	check("anchor %s (pixelfx pivot)" % ANCHOR, pack.anchor() == ANCHOR)
	check("has the whole clip only", pack.clip_names() == ["whole"])
	var c: Dictionary = pack.clip("whole")
	check("whole: %d frames" % FRAMES, int(c.get("frames", -1)) == FRAMES)
	check("whole: frame size = canvas (no crop)", c.get("frame_size", Vector2i.ZERO) == CANVAS)
	check("whole: offset = -pivot", c.get("offset", Vector2i.ONE) == -ANCHOR)
	var regions: Array = c.get("regions", [])
	check("regions: one per frame", regions.size() == FRAMES)
	if regions.size() == FRAMES:
		var ok := true
		for i: int in range(FRAMES):
			var expected := Rect2i(Vector2i((i % COLUMNS) * CANVAS.x, (i / COLUMNS) * CANVAS.y), CANVAS)
			if regions[i] != expected:
				ok = false
		check("regions follow the %d-column grid" % COLUMNS, ok)


func test_one_shot_frame_clamps() -> void:
	var pack: VfxPack = VfxPackScript.load_pack(FIXTURE_DIR)
	if pack == null:
		check("frame_at needs the pack", false)
		return
	var c: Dictionary = pack.clip("whole")
	check("frame_at(0) = 0", VfxPackScript.frame_at(c, 0.0, FRAME_MS, false) == 0)
	check("frame_at(0.12 s) = 2", VfxPackScript.frame_at(c, 0.12, FRAME_MS, false) == 2)
	check("frame_at past the end clamps to the last (empty) frame", VfxPackScript.frame_at(c, 9.0, FRAME_MS, false) == FRAMES - 1)


func test_provenance_and_tessera_block() -> void:
	var m: Variant = _read_json(FIXTURE_DIR + "/manifest.json")
	check("manifest json readable", m is Dictionary)
	if not (m is Dictionary):
		return
	var src: Dictionary = m.get("source", {})
	check("source.provider = pixelfx", src.get("provider", "") == "pixelfx")
	check("source.origin recorded (upstream | adapted | original)", src.get("origin", "") in ["upstream", "adapted", "original"])
	check("source.effect_id = impacts/hit-flash", src.get("effect_id", "") == "impacts/hit-flash")
	check("source.upstream_commit is a full sha", String(src.get("upstream_commit", "")).length() == 40)
	check("source.adapter_version present", String(src.get("adapter_version", "")) != "")
	var t: Dictionary = m.get("tessera", {})
	var palette: Array = t.get("palette", [])
	check("tessera.palette <= %d colours" % PALETTE_MAX, palette.size() > 0 and palette.size() <= PALETTE_MAX)
	check("tessera.index_entry plays once as an overlay", t.get("index_entry", {}).get("play", "") == "once" and t.get("index_entry", {}).get("layer", "") == "overlay")
	check("app names the adapter", String(m.get("app", "")).find("pixelfx_adapter") >= 0)


func test_candidate_matches_fixture_when_present() -> void:
	var cm: Variant = _read_json(CANDIDATE_DIR + "/manifest.json")
	if cm == null:
		print("NOT RUN: candidate folder absent (%s); the fixture copy is what is tested" % CANDIDATE_DIR)
		return
	var fm: Variant = _read_json(FIXTURE_DIR + "/manifest.json")
	check("candidate manifest equals the fixture copy", JSON.stringify(cm) == JSON.stringify(fm))

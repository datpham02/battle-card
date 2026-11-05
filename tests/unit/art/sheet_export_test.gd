extends SceneTree
## Story 045 — the exported unit sprite sheets (assets/art/units/) match their
## sources (art_src/units/), the story's clip table and the §8.7 import flags.
## Headless: godot --headless --path . -s res://tests/unit/art/sheet_export_test.gd

var fails: int = 0

const SHEET_DIR := "res://assets/art/units/"
const SRC_DIR := "res://art_src/units/"
const PALETTE := "res://art_src/palette/tessera_master.gpl"
const CANDIDATES := "res://design/assets/candidates/"
const MAX_COLOURS := 8

## Expected per unit: frame size, sheet size, facing, and the clip table of the story
## (name, frame count, ms per frame, loop kind), in row order.
const UNITS := {
	"kiem_si": {
		# 2026-10-31: v3 tall anchor (PixelLab 2d093318...), PixMiniMax south-east clips cleaned to 96x70.
		# 2026-11-02: guard stance (user: the knight holds the sword ready the whole battle): idle, hit and the four
		# directional dashes come from the guard_* candidates, the match-start draw from draw_to_guard.
		"frame": Vector2i(96, 70), "sheet": Vector2i(872, 922), "facing": "right",
		"candidate": "swordsman/v3-tall/clean-96x70/%s.png",
		"clips": [
			# 2026-11-05: idle = anim-idle-v2 (PixMiniMax breathing + cape follow-through, 8 frames @125 ms), cleaned copies in guard_idle_v2.
			["idle", ["guard_idle_v2/0", "guard_idle_v2/1", "guard_idle_v2/2", "guard_idle_v2/3", "guard_idle_v2/4", "guard_idle_v2/5", "guard_idle_v2/6", "guard_idle_v2/7"], [125, 125, 125, 125, 125, 125, 125, 125], "loop"],
			["draw", ["draw_to_guard/0", "draw_to_guard/1", "draw_to_guard/2", "draw_to_guard/3", "draw_to_guard/4", "draw_to_guard/5", "draw_to_guard/6", "draw_to_guard/7"], [60, 60, 80, 80, 80, 80, 80, 120], "once"],
			["step", ["step/0", "step/1", "step/2", "step/3"], [100, 100, 100, 100], "loop"],
			["step_forward", ["guard_step_forward/0", "guard_step_forward/1", "guard_step_forward/2", "guard_step_forward/3", "guard_step_forward/4", "guard_step_forward/5", "guard_step_forward/6"], [50, 50, 50, 50, 50, 50, 50], "once"],
			["step_back", ["guard_step_back/0", "guard_step_back/1", "guard_step_back/2", "guard_step_back/3", "guard_step_back/4", "guard_step_back/5", "guard_step_back/6"], [50, 50, 50, 50, 50, 50, 50], "once"],
			["step_up", ["guard_step_up/0", "guard_step_up/1", "guard_step_up/2", "guard_step_up/3", "guard_step_up/4", "guard_step_up/5", "guard_step_up/6"], [50, 50, 50, 50, 50, 50, 50], "once"],
			["step_down", ["guard_step_down/0", "guard_step_down/1", "guard_step_down/2", "guard_step_down/3", "guard_step_down/4", "guard_step_down/5", "guard_step_down/6"], [50, 50, 50, 50, 50, 50, 50], "once"],
			["cast_gesture", ["guard_cast/0", "guard_cast/1", "guard_cast/2", "guard_cast/3", "guard_cast/4", "guard_cast/5", "guard_cast/6", "guard_cast/7", "guard_cast/8"], [83, 83, 83, 83, 200, 50, 83, 100, 133], "once"],
			["hit", ["guard_hit/0", "guard_hit/1", "guard_hit/2"], [40, 40, 40], "once"],
			["victory", ["victory/0", "victory/1", "victory/2", "victory/3", "victory/4"], [100, 100, 100, 100, 100], "hold_last"],
			["defeat", ["defeat/0", "defeat/1", "defeat/2", "defeat/3", "defeat/4", "defeat/5", "defeat/6", "defeat/7"], [100, 100, 100, 100, 100, 100, 100, 100], "hold_last"],
			["fall", ["fall/0", "fall/1", "fall/2", "fall/3"], [100, 100, 100, 100], "hold_last"],
			["awaken", ["awaken/0", "awaken/1", "awaken/2", "awaken/3", "awaken/4", "awaken/5"], [120, 120, 120, 120, 120, 120], "loop"],
		],
	},
	"forest_witch": {
		# 2026-11-02: ASSET-020 wide anchor (160x136 Pro Flash, the 2x2 boss fills her block) + PixMiniMax south-west
		# clips cleaned to 160x130.
		"frame": Vector2i(160, 130), "sheet": Vector2i(1287, 1309), "facing": "left",
		"candidate": "forest-witch/clean-160x130/%s.png",
		"clips": [
			["idle", ["idle/0", "idle/1", "idle/2", "idle/3"], [300, 300, 300, 300], "loop"],
			["step_forward", ["step_forward/0", "step_forward/1", "step_forward/2", "step_forward/3", "step_forward/4", "step_forward/5", "step_forward/6"], [50, 50, 50, 50, 50, 50, 50], "once"],
			["step_back", ["step_back/0", "step_back/1", "step_back/2", "step_back/3", "step_back/4", "step_back/5", "step_back/6"], [50, 50, 50, 50, 50, 50, 50], "once"],
			["step_up", ["step_up/0", "step_up/1", "step_up/2", "step_up/3", "step_up/4"], [50, 50, 50, 50, 50], "once"],
			["step_down", ["step_down/0", "step_down/1", "step_down/2", "step_down/3", "step_down/4", "step_down/5", "step_down/6"], [50, 50, 50, 50, 50, 50, 50], "once"],
			["windup", ["windup/0", "windup/1", "windup/2"], [100, 100, 0], "hold_last"],
			["windup_heavy", ["windup_heavy/0", "windup_heavy/1", "windup_heavy/2"], [100, 100, 0], "hold_last"],
			["phase_shift", ["phase_shift/0", "phase_shift/1", "phase_shift/2", "phase_shift/3", "phase_shift/4", "phase_shift/5", "phase_shift/6", "phase_shift/7"], [120, 120, 120, 120, 150, 150, 150, 200], "hold_last"],
			["hit", ["hit/0", "hit/1", "hit/2"], [40, 40, 40], "once"],
			["down", ["down/0", "down/1", "down/2", "down/3", "down/4", "down/5"], [100, 100, 120, 120, 150, 150], "hold_last"],
		],
	},
	"rootling": {
		# 2026-11-02: ASSET-021, Pro Flash character ee8c6435 + PixMiniMax south-west clips cleaned to 64x52.
		"frame": Vector2i(64, 52), "sheet": Vector2i(389, 264), "facing": "left",
		"candidate": "rootling/clean-64x52/%s.png",
		"clips": [
			["idle", ["idle/0", "idle/1", "idle/2", "idle/3"], [250, 250, 250, 250], "loop"],
			["step", ["step/0", "step/1", "step/2", "step/3"], [100, 100, 100, 100], "loop"],
			["windup", ["windup/0", "windup/1", "windup/2", "windup/3"], [100, 100, 100, 0], "hold_last"],
			["hit", ["hit/0", "hit/1", "hit/2"], [40, 40, 40], "once"],
			["down", ["down/0", "down/1", "down/2", "down/3", "down/4", "down/5"], [100, 120, 150, 150, 150, 150], "hold_last"],
		],
	},
	"greycap_sporeling": {
		# 2026-11-02: ASSET-022, PixMiniMax south-west clips cleaned to 64x52.
		"frame": Vector2i(64, 52), "sheet": Vector2i(389, 264), "facing": "left",
		"candidate": "greycap/clean-64x52/%s.png",
		"clips": [
			["idle", ["idle/0", "idle/1", "idle/2", "idle/3"], [250, 250, 250, 250], "loop"],
			["step", ["step/0", "step/1", "step/2", "step/3"], [100, 100, 100, 100], "loop"],
			["windup", ["windup/0", "windup/1", "windup/2", "windup/3"], [100, 100, 100, 0], "hold_last"],
			["hit", ["hit/0", "hit/1", "hit/2"], [40, 40, 40], "once"],
			["down", ["down/0", "down/1", "down/2", "down/3", "down/4", "down/5"], [100, 120, 150, 150, 150, 150], "hold_last"],
		],
	},
	"mossbound_sentry": {
		# 2026-11-02: ASSET-023, PixMiniMax south-west clips cleaned to 64x52.
		"frame": Vector2i(64, 52), "sheet": Vector2i(389, 317), "facing": "left",
		"candidate": "mossbound-sentry/clean-64x52/%s.png",
		"clips": [
			["idle", ["idle/0", "idle/1", "idle/2", "idle/3"], [250, 250, 250, 250], "loop"],
			["step", ["step/0", "step/1", "step/2", "step/3"], [100, 100, 100, 100], "loop"],
			["windup", ["windup/0", "windup/1", "windup/2", "windup/3"], [100, 100, 100, 0], "hold_last"],
			["brace", ["brace/0", "brace/1", "brace/2", "brace/3"], [100, 100, 100, 0], "hold_last"],
			["hit", ["hit/0", "hit/1", "hit/2"], [40, 40, 40], "once"],
			["down", ["down/0", "down/1", "down/2", "down/3", "down/4", "down/5"], [100, 120, 150, 150, 150, 150], "hold_last"],
		],
	},
	"ancient_root_sentinel": {
		# 2026-11-02: ASSET-024 v2 (elite size), PixMiniMax south-west clips cleaned to 80x80.
		"frame": Vector2i(80, 80), "sheet": Vector2i(485, 485), "facing": "left",
		"candidate": "root-sentinel/clean-80x80/%s.png",
		"clips": [
			["idle", ["idle/0", "idle/1", "idle/2", "idle/3"], [250, 250, 250, 250], "loop"],
			["step", ["step/0", "step/1", "step/2", "step/3"], [100, 100, 100, 100], "loop"],
			["windup", ["windup/0", "windup/1", "windup/2", "windup/3"], [100, 100, 100, 0], "hold_last"],
			["stunned", ["stunned/0", "stunned/1", "stunned/2", "stunned/3"], [200, 200, 200, 200], "loop"],
			["hit", ["hit/0", "hit/1", "hit/2"], [40, 40, 40], "once"],
			["down", ["down/0", "down/1", "down/2", "down/3", "down/4", "down/5"], [100, 120, 150, 150, 150, 150], "hold_last"],
		],
	},
	"mistbriar_matron": {
		# 2026-11-02: ASSET-025 v2 (elite size), PixMiniMax south-west clips cleaned to 80x80.
		"frame": Vector2i(80, 80), "sheet": Vector2i(323, 485), "facing": "left",
		"candidate": "mistbriar-matron/clean-80x80/%s.png",
		"clips": [
			["idle", ["idle/0", "idle/1", "idle/2", "idle/3"], [250, 250, 250, 250], "loop"],
			["step", ["step/0", "step/1", "step/2", "step/3"], [100, 100, 100, 100], "loop"],
			["windup", ["windup/0", "windup/1", "windup/2", "windup/3"], [100, 100, 100, 0], "hold_last"],
			["guard", ["guard/0", "guard/1", "guard/2", "guard/3"], [100, 100, 100, 0], "hold_last"],
			["hit", ["hit/0", "hit/1", "hit/2"], [40, 40, 40], "once"],
			["down", ["down/0", "down/1", "down/2", "down/3"], [100, 120, 150, 150], "hold_last"],
		],
	},
	"goblin_scout": {
		# 2026-10-31: v3 OSFE-scale anchor (PixelLab 3b9516c8...), PixMiniMax south-west clips cleaned to 64x52.
		"frame": Vector2i(64, 52), "sheet": Vector2i(519, 264), "facing": "left",
		"candidate": "goblin-scout/v3/clean-64x52/%s.png",
		"clips": [
			["idle", ["idle/0", "idle/1", "idle/2", "idle/3"], [250, 250, 250, 250], "loop"],
			["step", ["step/0", "step/1", "step/2", "step/3"], [100, 100, 100, 100], "loop"],
			["windup", ["windup/0", "windup/1"], [100, 0], "hold_last"],
			["hit", ["hit/0", "hit/1", "hit/2"], [40, 40, 40], "once"],
			["down", ["down/0", "down/1", "down/2", "down/3", "down/4", "down/5", "down/6", "down/7"], [100, 100, 100, 100, 100, 100, 100, 100], "hold_last"],
		],
	},
}

const IMPORT_FLAGS := {
	"compress/mode": 0,
	"mipmaps/generate": false,
	"process/fix_alpha_border": true,
	"process/premult_alpha": false,
}


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _abs(res_path: String) -> String:
	return ProjectSettings.globalize_path(res_path)


func _read_json(res_path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(_abs(res_path))
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _load_palette() -> Dictionary:
	var out: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(_abs(PALETTE)).split("\n"):
		var s: String = line.strip_edges()
		if s.is_empty() or s.begins_with("#"):
			continue
		var parts: PackedStringArray = s.split("\t")[0].split(" ", false)
		if parts.size() < 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
			continue
		out[Color8(parts[0].to_int(), parts[1].to_int(), parts[2].to_int()).to_html(false).to_upper()] = true
	return out


func _same_pixels(sheet: Image, rect: Rect2i, frame: Image) -> bool:
	for y: int in rect.size.y:
		for x: int in rect.size.x:
			if sheet.get_pixel(rect.position.x + x, rect.position.y + y) != frame.get_pixel(x, y):
				return false
	return true


func _gutter_clear(sheet: Image, frame: Vector2i, cols: int, rows: int) -> bool:
	for c: int in range(1, cols):
		var gx: int = c * (frame.x + 1) - 1
		for y: int in sheet.get_height():
			if sheet.get_pixel(gx, y).a != 0.0:
				return false
	for r: int in range(1, rows):
		var gy: int = r * (frame.y + 1) - 1
		for x: int in sheet.get_width():
			if sheet.get_pixel(x, gy).a != 0.0:
				return false
	return true


func _import_files_under(res_dir: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(res_dir)
	if dir == null:
		return found
	dir.include_hidden = true
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		var path: String = res_dir.path_join(name)
		if dir.current_is_dir():
			if name != "." and name != "..":
				found.append_array(_import_files_under(path))
		elif name.ends_with(".import"):
			found.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	return found


func _check_unit(uid: String, spec: Dictionary, palette: Dictionary) -> void:
	var frame: Vector2i = spec["frame"]
	var json_path: String = SHEET_DIR + "unit_%s_sheet.json" % uid
	var png_path: String = SHEET_DIR + "unit_%s_sheet.png" % uid
	var doc: Dictionary = _read_json(json_path)
	ck("%s: json loads" % uid, not doc.is_empty() and doc.has("frames") and doc.has("meta"))
	if doc.is_empty():
		return
	var sheet: Image = Image.load_from_file(_abs(png_path))
	ck("%s: sheet loads" % uid, sheet != null)
	if sheet == null:
		return
	var meta: Dictionary = doc["meta"]
	# 1 sizes
	ck("%s: sheet is %s" % [uid, spec["sheet"]], Vector2i(sheet.get_width(), sheet.get_height()) == spec["sheet"])
	ck("%s: meta.size matches" % uid, int(meta["size"]["w"]) == sheet.get_width() and int(meta["size"]["h"]) == sheet.get_height())
	ck("%s: meta.image / scale" % uid, meta["image"] == "unit_%s_sheet.png" % uid and meta["scale"] == "1")
	# 2 tags, durations, loops, facing
	var tags: Array = meta["frameTags"]
	var clips: Array = spec["clips"]
	ck("%s: %d tags" % [uid, clips.size()], tags.size() == clips.size())
	var tessera: Dictionary = meta.get("tessera", {})
	ck("%s: facing = %s" % [uid, spec["facing"]], tessera.get("facing", "") == spec["facing"])
	ck("%s: tessera.frame" % uid, int(tessera.get("frame", {}).get("w", 0)) == frame.x and int(tessera.get("frame", {}).get("h", 0)) == frame.y)
	var frames: Array = doc["frames"]
	var expected_total: int = 0
	var all_ok: bool = true
	var cols: int = 1
	for i: int in clips.size():
		var clip: Array = clips[i]
		var names: Array = clip[1]
		var ms: Array = clip[2]
		cols = maxi(cols, names.size())
		var tag: Dictionary = tags[i] if i < tags.size() else {}
		var tag_ok: bool = tag.get("name", "") == clip[0] and int(tag.get("from", -1)) == expected_total \
			and int(tag.get("to", -1)) == expected_total + names.size() - 1 and tag.get("direction", "") == "forward"
		ck("%s: tag %s rows %d..%d" % [uid, clip[0], expected_total, expected_total + names.size() - 1], tag_ok)
		ck("%s: loop[%s] = %s" % [uid, clip[0], clip[3]], tessera.get("loop", {}).get(clip[0], "") == clip[3])
		for n: int in names.size():
			var idx: int = expected_total + n
			var f: Dictionary = frames[idx] if idx < frames.size() else {}
			var rect := Rect2i(int(f.get("frame", {}).get("x", -1)), int(f.get("frame", {}).get("y", -1)), int(f.get("frame", {}).get("w", 0)), int(f.get("frame", {}).get("h", 0)))
			var pos_ok: bool = rect == Rect2i(n * (frame.x + 1), i * (frame.y + 1), frame.x, frame.y)
			var fields_ok: bool = f.get("filename", "") == "%s_%s_%d" % [uid, clip[0], n] and f.get("rotated", true) == false \
				and f.get("trimmed", true) == false and int(f.get("duration", -1)) == int(ms[n]) \
				and int(f.get("sourceSize", {}).get("w", 0)) == frame.x and int(f.get("sourceSize", {}).get("h", 0)) == frame.y
			ck("%s: frame %s_%d rect + fields (%d ms)" % [uid, clip[0], n, ms[n]], pos_ok and fields_ok)
			# 3 the cell equals the source frame, and the source frame equals the candidate
			var src_path: String = SRC_DIR + "%s/%s/%d.png" % [uid, clip[0], n]
			var src: Image = Image.load_from_file(_abs(src_path))
			ck("%s: source %s/%d.png loads at %s" % [uid, clip[0], n, frame], src != null and Vector2i(src.get_width(), src.get_height()) == frame)
			if src != null and pos_ok:
				ck("%s: cell %s_%d pixel-identical to source" % [uid, clip[0], n], _same_pixels(sheet, rect, src))
			var cand_path: String = CANDIDATES + spec["candidate"] % names[n]
			var src_bytes: PackedByteArray = FileAccess.get_file_as_bytes(_abs(src_path))
			var cand_bytes: PackedByteArray = FileAccess.get_file_as_bytes(_abs(cand_path))
			ck("%s: source %s/%d.png byte-identical to candidate %s" % [uid, clip[0], n, names[n]], not src_bytes.is_empty() and src_bytes == cand_bytes)
		expected_total += names.size()
	ck("%s: %d frames" % [uid, expected_total], frames.size() == expected_total)
	# 4 alpha, colours, gutters
	var colours: Dictionary = {}
	var alpha_ok: bool = true
	for y: int in sheet.get_height():
		for x: int in sheet.get_width():
			var c: Color = sheet.get_pixel(x, y)
			if c.a8 == 0:
				continue
			if c.a8 != 255:
				alpha_ok = false
			colours[c.to_html(false).to_upper()] = true
	ck("%s: alpha only 0/255" % uid, alpha_ok)
	ck("%s: %d colours <= %d" % [uid, colours.size(), MAX_COLOURS], colours.size() <= MAX_COLOURS)
	var in_palette: bool = true
	for hex: String in colours.keys():
		if not palette.has(hex):
			in_palette = false
			print("  colour outside the palette: #" + hex)
	ck("%s: every colour in tessera_master.gpl" % uid, in_palette and all_ok)
	ck("%s: 1 px gutters transparent" % uid, _gutter_clear(sheet, frame, cols, clips.size()))
	# 5 import flags (§8.7)
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(png_path + ".import")
	ck("%s: .import exists" % uid, err == OK)
	if err == OK:
		for key: String in IMPORT_FLAGS.keys():
			var parts: PackedStringArray = key.split("/")
			var got: Variant = cfg.get_value("params", key, null)
			ck("%s: .import %s = %s (got %s)" % [uid, key, IMPORT_FLAGS[key], got], got == IMPORT_FLAGS[key])
		ck("%s: .import detect_3d/compress_to = 0" % uid, cfg.get_value("params", "detect_3d/compress_to", -1) == 0)
		ck("%s: .import importer = texture" % uid, cfg.get_value("remap", "importer", "") == "texture")


func _init() -> void:
	var palette: Dictionary = _load_palette()
	ck("palette: tessera_master.gpl has %d colours" % palette.size(), palette.size() >= 8)
	ck("art_src/.gdignore exists", FileAccess.file_exists(_abs("res://art_src/.gdignore")))
	for uid: String in UNITS.keys():
		_check_unit(uid, UNITS[uid], palette)
	ck("no .import under art_src/", _import_files_under("res://art_src").is_empty())
	ck("no .import under design/assets/candidates/", _import_files_under("res://design/assets/candidates").is_empty())
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## QA tool (not a test): proves a re-exported unit sheet whose frame only grew TALLER draws the same pixels as the old
## one. For every frame (matched by filename), the new cell's bottom old-height rows must equal the old cell pixel for
## pixel, and every row above them must be fully transparent.
## Usage (after --): <old sheet.png> <old sheet.json> <new sheet.png> <new sheet.json>

func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var old_img := Image.load_from_file(a[0])
	var new_img := Image.load_from_file(a[2])
	old_img.convert(Image.FORMAT_RGBA8)
	new_img.convert(Image.FORMAT_RGBA8)
	var old_frames: Dictionary = {}
	for f: Dictionary in (JSON.parse_string(FileAccess.get_file_as_string(a[1])) as Dictionary)["frames"]:
		old_frames[f["filename"]] = f["frame"]
	var checked: int = 0
	var bad: Array[String] = []
	var padding_ok: bool = true
	for f: Dictionary in (JSON.parse_string(FileAccess.get_file_as_string(a[3])) as Dictionary)["frames"]:
		var name: String = f["filename"]
		if not old_frames.has(name):
			bad.append(name + " (new frame, not in the old sheet)")
			continue
		var o: Dictionary = old_frames[name]
		var n: Dictionary = f["frame"]
		var ow: int = int(o["w"])
		var oh: int = int(o["h"])
		var pad: int = int(n["h"]) - oh
		var diff: int = 0
		for y: int in oh:
			for x: int in ow:
				if old_img.get_pixel(int(o["x"]) + x, int(o["y"]) + y) != new_img.get_pixel(int(n["x"]) + x, int(n["y"]) + pad + y):
					diff += 1
		for y: int in pad:
			for x: int in int(n["w"]):
				if new_img.get_pixel(int(n["x"]) + x, int(n["y"]) + y).a > 0.0:
					padding_ok = false
		if diff > 0:
			bad.append("%s: %d px differ" % [name, diff])
		checked += 1
	print("sheet_pad_compare: %d frames checked, %d differ, padding transparent: %s" % [checked, bad.size(), padding_ok])
	for b: String in bad:
		print("  ", b)
	quit(0 if bad.is_empty() and padding_ok else 1)

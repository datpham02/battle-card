extends SceneTree
## Skill v2 V2 review tool: renders each hero's cast glyph (CastGlyphFx) over that hero's real `cast_gesture` hold
## frame (frame 4 of the sheet), at the hand point the cast index gives, at progress k = 0.15 / 0.4 / 0.7 / 0.9 and
## the reduce-motion frame. Pure Image ops, headless.
## Run: godot --headless --path . -s res://tools/qa/glyph_contact_sheet.gd -- <out.png> [scale]

const HEROES := {"kiem_si": "sigil", "phap_su": "runes", "sat_thu": "daggers", "tho_san": "leaf", "giao_si": "halo"}
const KS: Array[float] = [0.15, 0.4, 0.7, 0.9]
const PAD: int = 6
const BG := Color("2A2B33")
const INK := Color("1B1722")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://glyph_contact_sheet.png"
	var scale: int = int(args[1]) if args.size() > 1 else 3
	var cols: int = KS.size() + 1
	var cell := Vector2i(96, 92)
	var w: int = PAD + cols * (cell.x + PAD)
	var h: int = PAD + HEROES.size() * (cell.y + PAD)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	var row: int = 0
	for hero: String in HEROES:
		var frame: Image = _hold_frame(hero)
		var cols2: Array[Color] = CastVfx.block_colours(hero)
		var entry: Dictionary = CastVfx.cast_glyph(hero)
		if entry.is_empty():
			entry = CastVfx.entry_for(hero, "", "")
		for i: int in cols:
			var x0: int = PAD + i * (cell.x + PAD)
			var y0: int = PAD + row * (cell.y + PAD)
			if frame != null:
				var dst := Vector2i(x0, y0 + cell.y - frame.get_height())
				img.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), dst)
			var feet := Vector2i(x0 + cell.x / 2, y0 + cell.y - 1)
			var hand: Vector2i = CastVfx.hand_point(entry, feet)
			var reduce: bool = i == cols - 1
			var k: float = 0.7 if reduce else KS[i]
			for it: Dictionary in CastGlyphFx.items(str(HEROES[hero]), hand, k, cols2, reduce):
				var r: Rect2i = it["rect"]
				var e: int = int(it.get("edge", 0))
				if e > 0:
					_fill(img, r.grow(e), INK)
				_fill(img, r, it["col"])
		row += 1
	if scale > 1:
		img.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	var err: int = img.save_png(out_path)
	print("wrote ", out_path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	quit(0 if err == OK else 1)


## The hero's cast_gesture frame 4 cut from its sheet (null when the sheet or clip is missing).
func _hold_frame(hero: String) -> Image:
	var json_path: String = "res://assets/art/units/unit_%s_sheet.json" % hero
	var png_path: String = "res://assets/art/units/unit_%s_sheet.png" % hero
	if not FileAccess.file_exists(json_path) or not FileAccess.file_exists(png_path):
		return null
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (meta is Dictionary):
		return null
	var tags: Array = (meta as Dictionary).get("meta", {}).get("frameTags", [])
	var frames: Array = (meta as Dictionary).get("frames", [])
	for t: Variant in tags:
		if str((t as Dictionary).get("name", "")) == "cast_gesture":
			var idx: int = int((t as Dictionary).get("from", 0)) + 4
			if idx >= frames.size():
				return null
			var f: Dictionary = (frames[idx] as Dictionary).get("frame", {})
			var sheet: Image = Image.load_from_file(ProjectSettings.globalize_path(png_path))
			if sheet == null:
				return null
			var rect := Rect2i(int(f.get("x", 0)), int(f.get("y", 0)), int(f.get("w", 0)), int(f.get("h", 0)))
			return sheet.get_region(rect)
	return null


func _fill(img: Image, r: Rect2i, col: Color) -> void:
	var c: Rect2i = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if c.size.x <= 0 or c.size.y <= 0:
		return
	if col.a >= 0.999:
		img.fill_rect(c, col)
		return
	for y: int in range(c.position.y, c.end.y):
		for x: int in range(c.position.x, c.end.x):
			img.set_pixel(x, y, img.get_pixel(x, y).blend(col))

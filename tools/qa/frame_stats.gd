extends SceneTree
## Art QA (read-only): per-frame measurements of a folder of PNGs -- opaque bbox, the bottom opaque row, the x range of
## the pixels in the bottom [param foot_rows] rows (the feet), and the number of distinct opaque colours. Prints one
## line per file plus the distinct colours of the whole folder, so a clip can be aligned and palette-checked by number
## instead of by eye. Writes nothing.
## Usage (after --): <folder> [foot_rows=6] [palette=hex,hex,...]
## With a palette, each line also reports how many opaque pixels are NOT one of those colours -- the number that
## decides whether a generated clip is a few specks away from the sheet or has had something painted into it.


func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() < 1:
		push_error("frame_stats: <folder> [foot_rows]")
		quit(1)
		return
	var foot_rows: int = a[1].to_int() if a.size() > 1 else 6
	var palette: Dictionary = {}
	if a.size() > 2 and not a[2].is_empty():
		for hex: String in a[2].split(","):
			palette[hex.to_lower().lstrip("#")] = true
	var dir := DirAccess.open(a[0])
	if dir == null:
		push_error("frame_stats: cannot open %s" % a[0])
		quit(1)
		return
	var names: Array[String] = []
	for f: String in dir.get_files():
		if f.ends_with(".png"):
			names.append(f)
	names.sort()
	var all_colours: Dictionary = {}
	for n: String in names:
		var img := Image.load_from_file(a[0].path_join(n))
		img.convert(Image.FORMAT_RGBA8)
		var w: int = img.get_width()
		var h: int = img.get_height()
		var x0: int = w
		var x1: int = -1
		var y0: int = h
		var y1: int = -1
		var cols: Dictionary = {}
		var off: int = 0
		for y: int in h:
			for x: int in w:
				if img.get_pixel(x, y).a <= 0.5:
					continue
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
				var key: String = img.get_pixel(x, y).to_html(false)
				cols[key] = int(cols.get(key, 0)) + 1
				all_colours[key] = int(all_colours.get(key, 0)) + 1
				if not palette.is_empty() and not palette.has(key.to_lower()):
					off += 1
		var fx0: int = w
		var fx1: int = -1
		if y1 >= 0:
			for y: int in range(maxi(y1 - foot_rows + 1, 0), y1 + 1):
				for x: int in w:
					if img.get_pixel(x, y).a > 0.5:
						fx0 = mini(fx0, x)
						fx1 = maxi(fx1, x)
		print("%s %dx%d bbox=%d,%d..%d,%d bottom=%d feet_x=%d..%d colours=%d%s"
			% [n, w, h, x0, y0, x1, y1, y1, fx0, fx1, cols.size(),
			"" if palette.is_empty() else " off_palette_px=%d" % off])
	var list: Array = all_colours.keys()
	list.sort()
	print("FOLDER_COLOURS=%d %s" % [list.size(), ",".join(list)])
	quit(0)

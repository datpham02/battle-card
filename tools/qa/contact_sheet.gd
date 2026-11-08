extends SceneTree
## QA tool (not a test): tiles consecutive movie frames (Godot --write-movie PNG sequence) into one contact sheet.
## Usage (after --): <dir> <prefix> <first> <last> <step> <crop x,y,w,h | full> <columns> <scale | half> <out.png>
##   e.g. godot --headless -s res://tools/qa/contact_sheet.gd -- /tmp/mov f 60 124 4 300,120,800,260 4 1 sheet.png
## Each cell gets the frame number written as a small pixel strip index in the corner (no font needed): a white bar
## whose length counts frames from <first>. Nearest-neighbour scaling only (pixel art).

const PAD: int = 4
const BG := Color(0.08, 0.08, 0.1)


func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() < 9:
		push_error("contact_sheet: need <dir> <prefix> <first> <last> <step> <crop|full> <columns> <scale> <out.png>")
		quit(1)
		return
	var dir: String = a[0]
	var prefix: String = a[1]
	var first: int = a[2].to_int()
	var last: int = a[3].to_int()
	var step: int = maxi(a[4].to_int(), 1)
	var crop_text: String = a[5]
	var cols: int = maxi(a[6].to_int(), 1)
	# <scale>: 1, 2, 3 ... = nearest upscale; "half" = nearest 0.5x (a 2x game capture back to native 640x360 pixels).
	var half: bool = a[7] == "half"
	var scale: int = 1 if half else maxi(a[7].to_int(), 1)
	var out_path: String = a[8]
	var frames: Array[Image] = []
	for i: int in range(first, last + 1, step):
		var path: String = "%s/%s%08d.png" % [dir, prefix, i]
		var img := Image.load_from_file(path)
		if img == null or img.is_empty():
			push_warning("contact_sheet: missing %s" % path)
			continue
		img.convert(Image.FORMAT_RGBA8)
		if crop_text != "full":
			var p: PackedStringArray = crop_text.split(",")
			img = img.get_region(Rect2i(p[0].to_int(), p[1].to_int(), p[2].to_int(), p[3].to_int()))
		if half:
			img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_NEAREST)
		elif scale > 1:
			img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
		frames.append(img)
	if frames.is_empty():
		push_error("contact_sheet: no frames")
		quit(1)
		return
	var w: int = frames[0].get_width()
	var h: int = frames[0].get_height()
	var rows: int = ceili(float(frames.size()) / float(cols))
	var sheet := Image.create(PAD + cols * (w + PAD), PAD + rows * (h + PAD), false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	for k: int in frames.size():
		var x: int = PAD + (k % cols) * (w + PAD)
		var y: int = PAD + (k / cols) * (h + PAD)
		sheet.blit_rect(frames[k], Rect2i(0, 0, w, h), Vector2i(x, y))
		# Frame tick bar: k + 1 white 3x6 marks top-left (order is readable without text).
		for m: int in mini(k + 1, w / 5):
			sheet.fill_rect(Rect2i(x + 2 + m * 4, y + 2, 3, 6), Color.WHITE)
	sheet.save_png(out_path)
	print("contact_sheet: %d frames -> %s (%dx%d)" % [frames.size(), out_path, sheet.get_width(), sheet.get_height()])
	quit(0)

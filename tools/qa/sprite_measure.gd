extends SceneTree
## QA tool (not a test): measures sprite frames for acceptance checks: size, alpha values used, bounding box, feet row
## and feet x span (the lowest opaque row), colour count, and colours not in a reference sheet's palette.
## Usage (after --): <reference png (palette source)> <frame png>...
##   godot --headless --path . -s res://tools/qa/sprite_measure.gd -- art_src/units/kiem_si/cast_gesture/0.png a.png b.png


func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() < 2:
		push_error("sprite_measure: <reference.png> <frame.png>...")
		quit(1)
		return
	var ref_cols: Dictionary = _palette(Image.load_from_file(a[0]))
	print("reference %s: %d colours" % [a[0], ref_cols.size()])
	for i: int in range(1, a.size()):
		var img := Image.load_from_file(a[i])
		if img == null or img.is_empty():
			print("%s: unreadable" % a[i])
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w: int = img.get_width()
		var h: int = img.get_height()
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		var alphas: Dictionary = {}
		var cols: Dictionary = _palette(img)
		for y: int in h:
			for x: int in w:
				var c: Color = img.get_pixel(x, y)
				alphas[int(roundf(c.a * 255.0))] = true
				if c.a > 0.5:
					lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
					hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		var feet_lo: int = w
		var feet_hi: int = -1
		for x: int in w:
			if img.get_pixel(x, hi.y).a > 0.5:
				feet_lo = mini(feet_lo, x)
				feet_hi = maxi(feet_hi, x)
		var off: Array = []
		for k: Variant in cols.keys():
			if not ref_cols.has(k):
				off.append(k)
		var ak: Array = alphas.keys()
		ak.sort()
		print("%s: %dx%d alpha %s bbox x%d-%d y%d-%d feet row %d x%d-%d colours %d off-palette %d %s" % [a[i].get_file(), w, h,
			str(ak) if ak.size() <= 4 else "%d values" % ak.size(), lo.x, hi.x, lo.y, hi.y, hi.y, feet_lo, feet_hi, cols.size(),
			off.size(), str(off.slice(0, 6))])
	quit(0)


func _palette(img: Image) -> Dictionary:
	var out: Dictionary = {}
	if img == null:
		return out
	img.convert(Image.FORMAT_RGBA8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5:
				out[c.to_html(false)] = true
	return out

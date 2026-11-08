extends SceneTree
## Art tool (deterministic, region-specific, mechanical): inside every 4-connected component of colour <from> that has
## at least <min_component> px, recolours the INTERIOR pixels (all 4 neighbours also <from>) to <to>; the component's
## 1 px rim keeps <from>. Thin trims (1-2 px wide lines) have no interior, so they never change. Used to put the Knight's
## navy cape back where PixMiniMax drew its lining gold (cast_forward), keeping the gold cape trim.
## Usage (after --): <from hex> <to hex> <min_component> <in.png> <out.png>


func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() < 5:
		push_error("sprite_recolour_region: <from> <to> <min_component> <in.png> <out.png>")
		quit(1)
		return
	var from := Color("#" + a[0])
	var to := Color("#" + a[1])
	var min_c: int = a[2].to_int()
	var img := Image.load_from_file(a[3])
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var is_from := func(p: Vector2i) -> bool:
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			return false
		var c: Color = img.get_pixelv(p)
		return c.a > 0.5 and c.is_equal_approx(from)
	var seen: Dictionary = {}
	var changed: int = 0
	var sizes: Array = []
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var interior: Array[Vector2i] = []
	for y: int in h:
		for x: int in w:
			var s := Vector2i(x, y)
			if seen.has(s) or not is_from.call(s):
				continue
			var comp: Array[Vector2i] = [s]
			seen[s] = true
			var i: int = 0
			while i < comp.size():
				var cur: Vector2i = comp[i]
				i += 1
				for d: Vector2i in dirs:
					var n: Vector2i = cur + d
					if not seen.has(n) and is_from.call(n):
						seen[n] = true
						comp.append(n)
			sizes.append(comp.size())
			if comp.size() < min_c:
				continue
			for p: Vector2i in comp:
				var inside: bool = true
				for d: Vector2i in dirs:
					inside = inside and is_from.call(p + d)
				if inside:
					interior.append(p)
	for p: Vector2i in interior:
		img.set_pixelv(p, Color(to, 1.0))
		changed += 1
	img.save_png(a[4])
	sizes.sort()
	sizes.reverse()
	print("sprite_recolour_region: %s components %s -> %d px recoloured" % [a[3].get_file(), str(sizes.slice(0, 5)), changed])
	quit(0)

extends SceneTree
## Art tool (mechanical edits only, never painting): snaps every opaque pixel of a generated frame to the nearest colour
## of a fixed palette (RGB distance), drops opaque clusters smaller than <min_cluster> px (8-connected specks / baked
## smear crumbs), and translates the whole frame by <dx>,<dy> (re-planting the feet). Alpha stays 0 / 255.
## Usage (after --): <palette hex,hex,...> <min_cluster> <dx> <dy> <in.png> <out.png>


func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() < 6:
		push_error("sprite_clean: <palette> <min_cluster> <dx> <dy> <in.png> <out.png>")
		quit(1)
		return
	var pal: Array[Color] = []
	for h: String in a[0].split(","):
		pal.append(Color("#" + h))
	var min_cluster: int = a[1].to_int()
	var dx: int = a[2].to_int()
	var dy: int = a[3].to_int()
	var src := Image.load_from_file(a[4])
	src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()
	var snapped := Image.create(w, h, false, Image.FORMAT_RGBA8)
	snapped.fill(Color(0, 0, 0, 0))
	for y: int in h:
		for x: int in w:
			var c: Color = src.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			var best: Color = pal[0]
			var bd: float = INF
			for p: Color in pal:
				var d: float = (c.r - p.r) * (c.r - p.r) + (c.g - p.g) * (c.g - p.g) + (c.b - p.b) * (c.b - p.b)
				if d < bd:
					bd = d
					best = p
			snapped.set_pixel(x, y, Color(best, 1.0))
	# Drop small 8-connected opaque clusters.
	var seen: Dictionary = {}
	var dropped: int = 0
	for y: int in h:
		for x: int in w:
			var start := Vector2i(x, y)
			if seen.has(start) or snapped.get_pixelv(start).a <= 0.5:
				continue
			var comp: Array[Vector2i] = [start]
			seen[start] = true
			var i: int = 0
			while i < comp.size():
				var cur: Vector2i = comp[i]
				i += 1
				for oy: int in range(-1, 2):
					for ox: int in range(-1, 2):
						var n := cur + Vector2i(ox, oy)
						if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n):
							continue
						if snapped.get_pixelv(n).a > 0.5:
							seen[n] = true
							comp.append(n)
			if comp.size() < min_cluster:
				for p: Vector2i in comp:
					snapped.set_pixelv(p, Color(0, 0, 0, 0))
				dropped += comp.size()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(snapped, Rect2i(0, 0, w, h), Vector2i(dx, dy))
	out.save_png(a[5])
	print("sprite_clean: %s -> %s dx %d dy %d dropped %d px" % [a[4].get_file(), a[5], dx, dy, dropped])
	quit(0)

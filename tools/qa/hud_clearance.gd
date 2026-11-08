extends SceneTree
## QA tool (not a test): checks a planned taller pose against the battle HUD on a real screenshot. Draws, on the shot,
## the HUD rects (red), the current 70 px body box (white) and each planned pose envelope (yellow = clear, magenta =
## too close), and prints the clearance of each envelope to every HUD rect (screen px; negative = overlap).
## Usage (after --): <shot.png> <out.png> <feet art x,y> <art scale> <art origin x,y> <min gap px>
##   <hud name:x,y,w,h;...> <envelope name:dx0,dy0,dx1,dy1;...>
## Envelope boxes are in art px relative to the feet (dy negative = up), e.g. "full:-10,-91,6,-62".

const RED := Color(1.0, 0.2, 0.2)
const WHITE := Color(1.0, 1.0, 1.0)
const OK := Color(1.0, 0.85, 0.1)
const BAD := Color(1.0, 0.2, 1.0)


func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGBA8)
	var feet: Vector2i = _v(a[2])
	var k: int = a[3].to_int()
	var origin: Vector2i = _v(a[4])
	var min_gap: int = a[5].to_int()
	var hud: Dictionary = {}
	for item: String in a[6].split(";", false):
		var p: PackedStringArray = item.split(":")
		var n: PackedStringArray = p[1].split(",")
		hud[p[0]] = Rect2i(n[0].to_int(), n[1].to_int(), n[2].to_int(), n[3].to_int())
	for r: Rect2i in hud.values():
		_outline(img, r, RED)
	var feet_px := Vector2i(origin.x + feet.x * k, origin.y + feet.y * k)
	_outline(img, Rect2i(feet_px + Vector2i(-24 * k, -70 * k), Vector2i(48 * k, 70 * k)), WHITE)
	for item: String in a[7].split(";", false):
		var p: PackedStringArray = item.split(":")
		var n: PackedStringArray = p[1].split(",")
		var box := Rect2i(feet_px + Vector2i(n[0].to_int() * k, n[1].to_int() * k),
			Vector2i((n[2].to_int() - n[0].to_int()) * k, (n[3].to_int() - n[1].to_int()) * k))
		var worst: int = 99999
		var worst_name: String = ""
		for hn: String in hud:
			var g: int = _gap(box, hud[hn])
			if g < worst:
				worst = g
				worst_name = hn
		var ok: bool = worst >= min_gap and box.position.y >= min_gap
		_outline(img, box, OK if ok else BAD)
		print("hud_clearance %s %s: top y %d, nearest HUD %s gap %d px -> %s" % [a[0].get_file(), p[0], box.position.y,
			worst_name, worst, "CLEAR" if ok else "TOO CLOSE"])
	img.save_png(a[1])
	quit()


# Distance between two rects in screen px (0 = touching, negative = overlap depth).
func _gap(a: Rect2i, b: Rect2i) -> int:
	var dx: int = maxi(b.position.x - a.end.x, a.position.x - b.end.x)
	var dy: int = maxi(b.position.y - a.end.y, a.position.y - b.end.y)
	if dx < 0 and dy < 0:
		return maxi(dx, dy)
	return maxi(dx, dy)


func _v(s: String) -> Vector2i:
	var p: PackedStringArray = s.split(",")
	return Vector2i(p[0].to_int(), p[1].to_int())


func _outline(img: Image, r: Rect2i, c: Color) -> void:
	var b := Rect2i(Vector2i.ZERO, img.get_size())
	for t: int in 2:
		var rr := r.grow(-t)
		for x: int in range(rr.position.x, rr.end.x):
			for y: int in [rr.position.y, rr.end.y - 1]:
				if b.has_point(Vector2i(x, y)):
					img.set_pixel(x, y, c)
		for y: int in range(rr.position.y, rr.end.y):
			for x: int in [rr.position.x, rr.end.x - 1]:
				if b.has_point(Vector2i(x, y)):
					img.set_pixel(x, y, c)

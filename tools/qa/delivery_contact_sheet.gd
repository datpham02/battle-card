extends SceneTree
## Skill v2 V3 review tool: renders each DeliveryFx travel on a 3-cell strip (origin → target) at five moments of its
## travel, flat layer on the slabs and standing layer in the air above, with the freeze colours. Pure Image ops.
## Run: godot --headless --path . -s res://tools/qa/delivery_contact_sheet.gd -- <out.png> [scale]

const CELL := Vector2i(64, 46)
const AIR: int = 70
const PAD: int = 6
const KS: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.9]
const SLAB := Color("4C4D47")
const GAP := Color("1B1722")
const BG := Color("2A2B33")
const AIR_BG := Color("34353E")
const INK := Color("1B1722")
const ROWS: Array[String] = ["sky", "ground", "chain", "streak", "gather"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://delivery_contact_sheet.png"
	var scale: int = int(args[1]) if args.size() > 1 else 3
	var strip_w: int = CELL.x * 3 + 2
	var panel_h: int = AIR + CELL.y
	var w: int = PAD + KS.size() * (strip_w + PAD)
	var h: int = PAD + ROWS.size() * (panel_h + PAD)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	var cols: Array[Color] = [Color("A6EEFF"), Color("EEF4FA")]
	for r: int in ROWS.size():
		for i: int in KS.size():
			var x0: int = PAD + i * (strip_w + PAD)
			var y0: int = PAD + r * (panel_h + PAD)
			var panel := Rect2i(x0, y0, strip_w, panel_h)
			img.fill_rect(panel, AIR_BG)
			var cells: Array[Rect2i] = []
			for c: int in 3:
				var slab := Rect2i(x0 + c * (CELL.x + 1), y0 + AIR, CELL.x, CELL.y)
				img.fill_rect(slab, GAP)
				img.fill_rect(slab.grow(-1), SLAB)
				cells.append(slab)
			var k: float = KS[i]
			var flat: Array[Dictionary] = []
			var standing: Array[Dictionary] = []
			var tgt: Rect2i = cells[2]
			var base_t := Vector2i(tgt.position.x + CELL.x / 2, tgt.end.y - 4)
			var base_o := Vector2i(cells[0].position.x + CELL.x / 2, cells[0].end.y - 4)
			var base_m := Vector2i(cells[1].position.x + CELL.x / 2, cells[1].end.y - 4)
			match ROWS[r]:
				"sky":
					var until: float = (1.0 - k) * 0.3
					flat = DeliveryFx.sky_floor(tgt, until)
					standing = DeliveryFx.sky_standing(base_t, CELL.x, minf(until, 0.12), 0.12, 7)
				"ground":
					var a: Vector2i = cells[0].get_center()
					var b: Vector2i = tgt.get_center()
					flat = DeliveryFx.ground_floor(a, b, k * 0.36, 0.36)
					var front: Vector2 = Vector2(base_o).lerp(Vector2(base_t), k)
					standing = DeliveryFx.ground_dust(Vector2i(front.round()), Vector2(-1, 0), CELL.x, k, 7)
				"chain":
					standing = DeliveryFx.chain_standing(base_o, base_m, CELL.x, k * 2.0) + DeliveryFx.chain_standing(base_m, base_t, CELL.x, k * 2.0 - 1.0)
				"streak":
					flat = DeliveryFx.streak(cells[0].get_center(), tgt.get_center(), k)
				"gather":
					var until: float = (1.0 - k) * 0.2
					for c: Rect2i in cells:
						flat.append_array(DeliveryFx.gather_floor(c, until))
					standing = DeliveryFx.gather_standing(base_t, CELL.x, until) + DeliveryFx.gather_standing(base_m, CELL.x, until)
			_paint(img, flat, cols, panel)
			_paint(img, standing, cols, panel)
	if scale > 1:
		img.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	var err: int = img.save_png(out_path)
	print("wrote ", out_path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	quit(0 if err == OK else 1)


func _paint(img: Image, items: Array[Dictionary], colours: Array[Color], clip: Rect2i) -> void:
	for it: Dictionary in items:
		var r: Rect2i = it["rect"]
		if mini(r.size.x, r.size.y) >= 3:
			_fill(img, r.grow(1), INK, clip)
	for it: Dictionary in items:
		_fill(img, it["rect"], OverlayLayer.tone_colour(it, colours), clip)


func _fill(img: Image, r: Rect2i, col: Color, clip: Rect2i) -> void:
	var c: Rect2i = r.intersection(clip)
	if c.size.x > 0 and c.size.y > 0:
		img.fill_rect(c, col)

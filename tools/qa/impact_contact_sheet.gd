extends SceneTree
## Skill v2 V1 review tool: renders every ImpactFx form as a contact sheet (no game scene, pure Image ops), so the
## per-card impact shapes can be approved before they are wired into the battle. One row per variant: the card id,
## then the form at u = 0.15 / 0.35 / 0.55 / 0.75 / 0.95 and the reduce-motion frame. Each panel is a 64x46 slab
## (the real cell art size) with the FLAT layer (ImpactFx.items) on it and the STANDING layer
## (ImpactFx.standing_items) rising from the slab's bottom-centre into the 64 px of air above it, drawn with that
## card's impact colours (CastVfx.impact_colours) and a 1 px Ink edge on squares >= 3 px, like OverlayLayer.
## Run: godot --headless --path . -s res://tools/qa/impact_contact_sheet.gd -- <out.png> [scale] [hero]

const CELL := Vector2i(64, 46)
const AIR: int = 64
const PAD: int = 6
const FRAMES: Array[float] = [0.15, 0.35, 0.55, 0.75, 0.95]
const SLAB := Color("4C4D47")
const GAP := Color("1B1722")
const BG := Color("2A2B33")
const AIR_BG := Color("34353E")
const INK := Color("1B1722")

## card -> {impact, form, knobs...}: mirrors `impact_variants` in the cast index.
const VARIANTS := {
	"bang_phong": {"impact": "freeze", "form": "frame"},
	"suong_mong": {"impact": "freeze", "form": "frame", "sparse": true},
	"han_khi": {"impact": "freeze", "form": "cross"},
	"han_phong": {"impact": "freeze", "form": "cross", "diag": true},
	"thanh_thuy": {"impact": "freeze", "form": "cross", "drops": 3},
	"han_kiem": {"impact": "freeze", "form": "spike", "tilt": true},
	"han_tran": {"impact": "freeze", "form": "spike", "count": 2},
	"bang_chau": {"impact": "freeze", "form": "cluster"},
	"thiet_kiem": {"impact": "slash", "form": "arc_h"},
	"kiem_vu": {"impact": "slash", "form": "arc_v"},
	"kiem_than": {"impact": "slash", "form": "cross_x"},
	"dai_dao": {"impact": "slash", "form": "double"},
	"song_kiem": {"impact": "slash", "form": "double", "size": 3},
	"tu_kiem": {"impact": "slash", "form": "stab4"},
	"ran_kich": {"impact": "shatter", "form": "crack"},
	"ran_van": {"impact": "shatter", "form": "crack", "web": true},
	"han_bang": {"impact": "shatter", "form": "chunks"},
	"bang_tam": {"impact": "shatter", "form": "shards"},
	"chan_phong": {"impact": "knockback", "form": "column"},
	"cuong_phong": {"impact": "knockback", "form": "column", "count": 2},
	"xung_kich": {"impact": "knockback", "form": "wedge"},
	"thien_lang": {"impact": "knockback", "form": "slam"},
	"tran_gai": {"impact": "thorns", "form": "spikes"},
	"gai_nguyen": {"impact": "thorns", "form": "spikes", "vine": true},
	"gai_doc": {"impact": "poison", "form": "bubbles"},
	"kiem_khi": {"impact": "burst", "form": "ring"},
	"do_kiem": {"impact": "burst", "form": "ring2"},
}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://impact_contact_sheet.png"
	var scale: int = int(args[1]) if args.size() > 1 else 2
	var caster: String = args[2] if args.size() > 2 else "kiem_si"
	var cols: int = FRAMES.size() + 1
	var label_w: int = 70
	var panel_h: int = AIR + CELL.y
	var w: int = label_w + cols * (CELL.x + PAD) + PAD
	var h: int = PAD + VARIANTS.size() * (panel_h + PAD)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	var font := _TinyFont.new()
	var row: int = 0
	for card: String in VARIANTS:
		var v: Dictionary = VARIANTS[card]
		var y0: int = PAD + row * (panel_h + PAD)
		font.draw(img, card, Vector2i(PAD, y0 + AIR + 2), Color("EFE6D2"))
		font.draw(img, str(v["form"]), Vector2i(PAD, y0 + AIR + 10), Color("A6A6A6"))
		var colours: Array[Color] = CastVfx.impact_colours(str(v["impact"]), caster)
		var params: Dictionary = v.duplicate()
		params.erase("impact")
		params.erase("form")
		var sec: float = float(v.get("sec", 0.5))
		for i: int in cols:
			var x0: int = label_w + PAD + i * (CELL.x + PAD)
			var panel := Rect2i(x0, y0, CELL.x, panel_h)
			var slab := Rect2i(x0, y0 + AIR, CELL.x, CELL.y)
			img.fill_rect(panel, AIR_BG)
			img.fill_rect(slab, GAP)
			img.fill_rect(slab.grow(-1), SLAB)
			var reduce: bool = i == cols - 1
			var age: float = 0.05 if reduce else FRAMES[i] * sec
			var flat: Array[Dictionary] = ImpactFx.items(str(v["form"]), slab, age, sec, 17, 1, params, reduce)
			_paint(img, flat, colours, slab)
			var base := Vector2i(slab.position.x + CELL.x / 2, slab.end.y - 4)
			var standing: Array[Dictionary] = ImpactFx.standing_items(str(v["form"]), base, CELL.x, age, sec, 17, 1, params, reduce)
			_paint(img, standing, colours, panel)
		row += 1
	if scale > 1:
		img.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	var err: int = img.save_png(out_path)
	print("wrote ", out_path, " ", img.get_width(), "x", img.get_height(), " err=", err, " forms=", VARIANTS.size())
	quit(0 if err == OK else 1)


func _paint(img: Image, items: Array[Dictionary], colours: Array[Color], clip: Rect2i) -> void:
	for it: Dictionary in items:
		var r: Rect2i = it["rect"]
		if mini(r.size.x, r.size.y) >= 3:
			_fill_clipped(img, r.grow(1), INK, clip)
	for it: Dictionary in items:
		var r: Rect2i = it["rect"]
		_fill_clipped(img, r, OverlayLayer.tone_colour(it, colours), clip)


func _fill_clipped(img: Image, r: Rect2i, col: Color, clip: Rect2i) -> void:
	var c: Rect2i = r.intersection(clip)
	if c.size.x > 0 and c.size.y > 0:
		img.fill_rect(c, col)


## 3x5 pixel font for the row labels (a-z, 0-9, _).
class _TinyFont:
	const GLYPHS := {
		"a": ["010", "101", "111", "101", "101"], "b": ["110", "101", "110", "101", "110"], "c": ["011", "100", "100", "100", "011"],
		"d": ["110", "101", "101", "101", "110"], "e": ["111", "100", "110", "100", "111"], "f": ["111", "100", "110", "100", "100"],
		"g": ["011", "100", "101", "101", "011"], "h": ["101", "101", "111", "101", "101"], "i": ["111", "010", "010", "010", "111"],
		"k": ["101", "101", "110", "101", "101"], "l": ["100", "100", "100", "100", "111"], "m": ["101", "111", "111", "101", "101"],
		"n": ["110", "101", "101", "101", "101"], "o": ["010", "101", "101", "101", "010"], "p": ["110", "101", "110", "100", "100"],
		"q": ["010", "101", "101", "011", "001"], "r": ["110", "101", "110", "101", "101"], "s": ["011", "100", "010", "001", "110"],
		"t": ["111", "010", "010", "010", "010"], "u": ["101", "101", "101", "101", "111"], "v": ["101", "101", "101", "101", "010"],
		"w": ["101", "101", "111", "111", "101"], "x": ["101", "101", "010", "101", "101"], "y": ["101", "101", "010", "010", "010"],
		"z": ["111", "001", "010", "100", "111"], "_": ["000", "000", "000", "000", "111"], "2": ["110", "001", "010", "100", "111"],
		"4": ["101", "101", "111", "001", "001"],
	}

	func draw(img: Image, text: String, at: Vector2i, col: Color) -> void:
		var x: int = at.x
		for ch: String in text:
			var g: Array = GLYPHS.get(ch, ["000", "000", "010", "000", "000"])
			for yy: int in 5:
				for xx: int in 3:
					if g[yy][xx] == "1":
						img.set_pixel(x + xx, at.y + yy, col)
			x += 4

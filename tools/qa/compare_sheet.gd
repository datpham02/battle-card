extends SceneTree
## QA tool (not a test): a LABELLED comparison sheet of movie captures (Godot --write-movie PNG sequences): one row per
## version, the same frames in every row, each row titled on its left and each column titled with its frame number and
## time (60 fps), in a built-in 5x7 pixel font (headless runs have no font rendering).
## Usage (after --): <out.png> <crop x,y,w,h | full> <scale | half> <frames a,b,c> <LABEL=dir> [<LABEL=dir> ...]
##   e.g. godot --headless -s res://tools/qa/compare_sheet.gd -- cmp.png 520,0,760,360 half 110,128,150 \
##        BEFORE=/tmp/old AFTER=/tmp/new
## Labels: A-Z, 0-9, space and . - : = / ( ) + % ; underscores print as spaces. Nearest-neighbour scaling only.

const PAD: int = 6
const TEXT_PX: int = 2
const BG := Color(0.08, 0.08, 0.1)
const FG := Color(0.95, 0.95, 0.9)
const GLYPHS: Dictionary = {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
	"=": ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
	"/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
	"(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
	")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
	"+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
	"%": ["11001", "11010", "00010", "00100", "01000", "01011", "10011"],
}


func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() < 5:
		push_error("compare_sheet: need <out.png> <crop|full> <scale|half> <frames a,b,c> <LABEL=dir> ...")
		quit(1)
		return
	var out_path: String = a[0]
	var crop_text: String = a[1]
	var half: bool = a[2] == "half"
	var scale: int = 1 if half else maxi(a[2].to_int(), 1)
	var frames: PackedInt32Array = []
	for f: String in a[3].split(","):
		frames.append(f.to_int())
	var rows: Array[Dictionary] = []
	for i: int in range(4, a.size()):
		var eq: int = a[i].find("=")
		rows.append({"label": a[i].substr(0, eq).replace("_", " ").to_upper(), "dir": a[i].substr(eq + 1)})
	var cells: Array = []
	var cell_size := Vector2i.ZERO
	for row: Dictionary in rows:
		var line: Array[Image] = []
		for f: int in frames:
			var img: Image = _frame(str(row["dir"]), f, crop_text, half, scale)
			if img == null:
				push_error("compare_sheet: missing frame %d in %s" % [f, row["dir"]])
				quit(1)
				return
			cell_size = img.get_size()
			line.append(img)
		cells.append(line)
	var label_w: int = 0
	for row: Dictionary in rows:
		label_w = maxi(label_w, _text_w(str(row["label"])))
	var head_h: int = 7 * TEXT_PX + PAD * 2
	var w: int = PAD + label_w + PAD + frames.size() * (cell_size.x + PAD)
	var h: int = head_h + rows.size() * (cell_size.y + PAD) + PAD
	var sheet := Image.create(w, h, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	var x0: int = PAD + label_w + PAD
	for c: int in frames.size():
		_text(sheet, "F%d T=%.2fS" % [frames[c], float(frames[c]) / 60.0], Vector2i(x0 + c * (cell_size.x + PAD), PAD))
	for r: int in rows.size():
		var y: int = head_h + r * (cell_size.y + PAD)
		_text(sheet, str(rows[r]["label"]), Vector2i(PAD, y + cell_size.y / 2 - 7 * TEXT_PX / 2))
		for c: int in frames.size():
			var img: Image = (cells[r] as Array)[c]
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x0 + c * (cell_size.x + PAD), y))
	var err: Error = sheet.save_png(out_path)
	print("compare_sheet: %d rows x %d frames -> %s (%dx%d) err=%d" % [rows.size(), frames.size(), out_path, w, h, err])
	quit(0 if err == OK else 1)


func _frame(dir: String, f: int, crop_text: String, half: bool, scale: int) -> Image:
	var img := Image.load_from_file("%s/f%08d.png" % [dir, f])
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	if crop_text != "full":
		var p: PackedStringArray = crop_text.split(",")
		img = img.get_region(Rect2i(p[0].to_int(), p[1].to_int(), p[2].to_int(), p[3].to_int()))
	if half:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_NEAREST)
	elif scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return img


func _text_w(s: String) -> int:
	return s.length() * 6 * TEXT_PX


func _text(img: Image, s: String, at: Vector2i) -> void:
	for i: int in s.length():
		var g: Array = GLYPHS.get(s[i].to_upper(), GLYPHS[" "])
		for gy: int in 7:
			var row: String = g[gy]
			for gx: int in 5:
				if row[gx] == "1":
					img.fill_rect(Rect2i(at.x + (i * 6 + gx) * TEXT_PX, at.y + gy * TEXT_PX, TEXT_PX, TEXT_PX), FG)

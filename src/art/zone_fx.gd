class_name ZoneFx
extends RefCounted
## Flat marks for a batch-3 field while it is armed (trap / ward / pillar). Cell art px, squares only.
## [param step] is 0..7 from the combat clock so the jaws and the spring breathe without a per-frame redraw.


static func marks(kind: String, skill_id: String, slab: Rect2i, step: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pulse: float = float(step % 8) / 7.0
	match kind:
		"trap":
			if skill_id == "bay_lo":
				_spring(out, slab, pulse)
			elif skill_id == "gai_no":
				_spikes(out, slab)
			else:
				_jaws(out, slab, pulse)
		"ward":
			if skill_id == "khien_thep":
				_plates(out, slab)
			else:
				_frame(out, slab, Color("8A6A20"), Color("E6D7A8"))
		"pillar":
			_stone(out, slab)
	return out


## Batch 4 (Dấu Tử): the death mark on the marked unit's slab while it lasts: four corner brackets that breathe with
## [param step] and shorten as [param frac] (time left / total) runs out, a 4 px core.
static func mark(slab: Rect2i, step: int, frac: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pulse: float = float(step % 8) / 7.0
	var inset: int = 4 + roundi(pulse * 2.0)
	var f: Rect2i = slab.grow(-inset)
	if f.size.x < 8 or f.size.y < 8:
		f = slab
	var arm: int = maxi(roundi(lerpf(4.0, 10.0, clampf(frac, 0.0, 1.0))), 4)
	var ink := Color("7A1F3A")
	var fill := Color("FFB3C6")
	out.append(_bar(f.position.x, f.position.y, arm, 2, fill))
	out.append(_bar(f.position.x, f.position.y, 2, arm, fill))
	out.append(_bar(f.end.x - arm, f.position.y, arm, 2, fill))
	out.append(_bar(f.end.x - 2, f.position.y, 2, arm, fill))
	out.append(_bar(f.position.x, f.end.y - 2, arm, 2, ink))
	out.append(_bar(f.position.x, f.end.y - arm, 2, arm, ink))
	out.append(_bar(f.end.x - arm, f.end.y - 2, arm, 2, ink))
	out.append(_bar(f.end.x - 2, f.end.y - arm, 2, arm, ink))
	var c := slab.position + Vector2i(floori(float(slab.size.x) / 2.0), floori(float(slab.size.y) / 2.0))
	out.append(_sq(c, 4, fill if pulse < 0.5 else ink))
	return out


static func _jaws(out: Array[Dictionary], slab: Rect2i, pulse: float) -> void:
	var jaw: int = maxi(roundi(lerpf(float(slab.size.x) * 0.22, float(slab.size.x) * 0.32, pulse)), 6)
	var top: int = slab.position.y + floori(float(slab.size.y) * 0.28)
	var bh: int = maxi(floori(float(slab.size.y) * 0.44), 6)
	out.append(_bar(slab.position.x + 2, top, jaw, bh, Color("3A3A42")))
	out.append(_bar(slab.end.x - 2 - jaw, top, jaw, bh, Color("C8C8D0")))


static func _spring(out: Array[Dictionary], slab: Rect2i, pulse: float) -> void:
	out.append(_bar(slab.position.x + 4, slab.end.y - 8, slab.size.x - 8, 4, Color("4A3428")))
	var n: int = 3 if pulse < 0.5 else 2
	var cx: int = slab.position.x + floori(float(slab.size.x) / 2.0)
	var cy: int = slab.position.y + floori(float(slab.size.y) / 2.0)
	for i: int in n:
		out.append(_sq(Vector2i(cx, cy - 6 + i * 6), 4, Color("C8C8D0") if i == 0 else Color("4A3428")))


static func _spikes(out: Array[Dictionary], slab: Rect2i) -> void:
	for i: int in 5:
		var x: int = slab.position.x + 4 + i * maxi(floori(float(slab.size.x - 8) / 5.0), 1)
		out.append(_bar(x, slab.end.y - 8, 4, 5, Color("5A4630") if i % 2 == 0 else Color("E2CFA0")))


static func _frame(out: Array[Dictionary], slab: Rect2i, ink: Color, fill: Color) -> void:
	var f: Rect2i = slab.grow(-4)
	if f.size.x < 4 or f.size.y < 4:
		f = slab
	out.append(_bar(f.position.x, f.position.y, f.size.x, 3, fill))
	out.append(_bar(f.position.x, f.end.y - 3, f.size.x, 3, ink))
	out.append(_bar(f.position.x, f.position.y, 3, f.size.y, fill))
	out.append(_bar(f.end.x - 3, f.position.y, 3, f.size.y, ink))


static func _plates(out: Array[Dictionary], slab: Rect2i) -> void:
	var bw: int = maxi(floori(float(slab.size.x) * 0.18), 4)
	var cx: int = slab.position.x + floori(float(slab.size.x) / 2.0)
	out.append(_bar(cx - floori(float(slab.size.x) / 3.0), slab.position.y + 4, bw, slab.size.y - 8, Color("5E6A78")))
	out.append(_bar(cx + floori(float(slab.size.x) / 5.0), slab.position.y + 4, bw, slab.size.y - 8, Color("C5D0DC")))


static func _stone(out: Array[Dictionary], slab: Rect2i) -> void:
	var w: int = maxi(floori(float(slab.size.x) * 0.46), 8)
	var h: int = maxi(floori(float(slab.size.y) * 0.46), 8)
	var c := slab.position + Vector2i(floori(float(slab.size.x) / 2.0), floori(float(slab.size.y) / 2.0))
	out.append(_bar(c.x - floori(float(w) / 2.0), c.y - floori(float(h) / 2.0), w, h, Color("A89B88")))
	out.append(_sq(c, 4, Color("E6D7A8")))


static func _bar(x: int, y: int, w: int, h: int, col: Color) -> Dictionary:
	return {"rect": Rect2i(x, y, maxi(w, 1), maxi(h, 1)), "col": col}


static func _sq(centre: Vector2i, size: int, col: Color) -> Dictionary:
	var s: int = maxi(size, 1)
	return {"rect": Rect2i(centre - Vector2i(floori(float(s) / 2.0), floori(float(s) / 2.0)), Vector2i(s, s)), "col": col}

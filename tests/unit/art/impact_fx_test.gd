extends SceneTree
## Skill v2 V1 ImpactFx: every form draws nothing outside [0, sec), is deterministic, stays inside the cell (with the
## 1 px Ink edge), draws something at the key moments, flips with the travel direction where it should, and holds a
## single still frame under reduce motion. form_of() accepts only known forms.
## Run: godot --headless --path . -s res://tests/unit/art/impact_fx_test.gd

const CELL := Rect2i(100, 60, 64, 46)
const SEC: float = 0.3
## Forms whose shape depends on the travel direction.
const DIRECTIONAL: Array[String] = ["arc_h", "arc_v", "cross_x", "double", "spike", "column", "wedge"]
const PARAMS := {"spike": {"tilt": true}}

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _inside(items: Array[Dictionary]) -> bool:
	var bound: Rect2i = CELL.grow(1)
	for it: Dictionary in items:
		var r: Rect2i = it["rect"]
		if r.size.x <= 0 or r.size.y <= 0 or not bound.encloses(r):
			return false
	return true


func _initialize() -> void:
	for form: String in ImpactFx.FORMS:
		var p: Dictionary = PARAMS.get(form, {})
		ck("%s: [] before" % form, ImpactFx.items(form, CELL, -0.01, SEC, 3, 1, p).is_empty())
		ck("%s: [] at the end" % form, ImpactFx.items(form, CELL, SEC, SEC, 3, 1, p).is_empty())
		var drew: bool = false
		var inside: bool = true
		for k: float in [0.1, 0.3, 0.5, 0.7, 0.9]:
			var items: Array[Dictionary] = ImpactFx.items(form, CELL, k * SEC, SEC, 3, 1, p)
			drew = drew or not items.is_empty()
			inside = inside and _inside(items)
			ck("%s @%.1f: deterministic" % [form, k], items == ImpactFx.items(form, CELL, k * SEC, SEC, 3, 1, p))
		ck("%s: draws something" % form, drew)
		ck("%s: every rect inside the cell (+1 px edge)" % form, inside)
		ck("%s: items carry rect + light" % form, ImpactFx.items(form, CELL, 0.5 * SEC, SEC, 3, 1, p).all(
			func(it: Dictionary) -> bool: return it.has("rect") and it.has("light") and it["rect"] is Rect2i))
		# reduce motion: one still frame (flat and / or standing), then nothing
		var r0: Array[Dictionary] = ImpactFx.items(form, CELL, 0.0, SEC, 3, 1, p, true)
		var r1: Array[Dictionary] = ImpactFx.items(form, CELL, ImpactFx.REDUCE_HOLD_SEC * 0.9, SEC, 3, 1, p, true)
		var s0: Array[Dictionary] = ImpactFx.standing_items(form, Vector2i(300, 200), 64, 0.0, SEC, 3, 1, p, true)
		ck("%s: reduce motion holds one still frame" % form, (not r0.is_empty() or not s0.is_empty()) and r0 == r1)
		ck("%s: reduce motion ends after the hold" % form, ImpactFx.items(form, CELL, ImpactFx.REDUCE_HOLD_SEC, SEC, 3, 1, p, true).is_empty())
	# the standing layer: screen px over a base point, never below the ground line, deterministic, bounded by the
	# tile's width and one cell width of height (plus the square's own size), still under reduce motion
	var base := Vector2i(300, 200)
	for form: String in ImpactFx.FORMS:
		var p: Dictionary = PARAMS.get(form, {})
		ck("%s standing: [] before / at the end" % form, ImpactFx.standing_items(form, base, 64, -0.01, SEC, 3, 1, p).is_empty()
			and ImpactFx.standing_items(form, base, 64, SEC, SEC, 3, 1, p).is_empty())
		var drew: bool = false
		var ok: bool = true
		var limit := Rect2i(base.x - 32 - 8, base.y - 64 - 8, 64 + 16, 64 + 8 + 8)
		for k: float in [0.1, 0.3, 0.5, 0.7, 0.9]:
			var st: Array[Dictionary] = ImpactFx.standing_items(form, base, 64, k * SEC, SEC, 3, 1, p)
			drew = drew or not st.is_empty()
			ok = ok and st == ImpactFx.standing_items(form, base, 64, k * SEC, SEC, 3, 1, p)
			for it: Dictionary in st:
				var r: Rect2i = it["rect"]
				ok = ok and limit.encloses(r) and r.end.y <= base.y + 4
		ck("%s standing: draws, deterministic, within the tile's width and one cell of height" % form, drew and ok)
		var r0: Array[Dictionary] = ImpactFx.standing_items(form, base, 64, 0.0, SEC, 3, 1, p, true)
		ck("%s standing: reduce motion holds one still frame" % form, r0 == ImpactFx.standing_items(form, base, 64, 0.1, SEC, 3, 1, p, true))
	for form: String in DIRECTIONAL:
		var p: Dictionary = PARAMS.get(form, {})
		var right: Array[Dictionary] = ImpactFx.items(form, CELL, 0.5 * SEC, SEC, 3, 1, p) + ImpactFx.standing_items(form, base, 64, 0.5 * SEC, SEC, 3, 1, p)
		var left: Array[Dictionary] = ImpactFx.items(form, CELL, 0.5 * SEC, SEC, 3, -1, p) + ImpactFx.standing_items(form, base, 64, 0.5 * SEC, SEC, 3, -1, p)
		ck("%s: flips with the travel direction" % form, right != left)
	# V4: tones and the aftermath
	for form: String in ImpactFx.FORMS:
		var p: Dictionary = PARAMS.get(form, {})
		var early: Array[Dictionary] = ImpactFx.items(form, CELL, 0.02, SEC, 3, 1, p) + ImpactFx.standing_items(form, base, 64, 0.02, SEC, 3, 1, p)
		var toned: bool = early.all(func(it: Dictionary) -> bool: return it.has("tone") and int(it["tone"]) >= 0 and int(it["tone"]) <= 3)
		var has_core: bool = early.any(func(it: Dictionary) -> bool: return int(it["tone"]) == 3)
		ck("%s: every item toned 0..3, with a core at the start" % form, toned and has_core)
		var late: Array[Dictionary] = ImpactFx.items(form, CELL, 0.5 * SEC, SEC, 3, 1, p)
		ck("%s: no core past the first tenth" % form, late.all(func(it: Dictionary) -> bool: return int(it["tone"]) != 3))
		ck("%s aftermath: [] outside, draws inside the cell, deterministic, dark at the end" % form,
			ImpactFx.aftermath_items(form, CELL, -0.01, 1.0, 3, p).is_empty() and ImpactFx.aftermath_items(form, CELL, 1.0, 1.0, 3, p).is_empty()
			and not ImpactFx.aftermath_items(form, CELL, 0.2, 1.0, 3, p).is_empty()
			and ImpactFx.aftermath_items(form, CELL, 0.2, 1.0, 3, p) == ImpactFx.aftermath_items(form, CELL, 0.2, 1.0, 3, p)
			and _inside(ImpactFx.aftermath_items(form, CELL, 0.2, 1.0, 3, p))
			and ImpactFx.aftermath_items(form, CELL, 0.9, 1.0, 3, p).all(func(it: Dictionary) -> bool: return int(it["tone"]) == 0))
	ck("unknown form -> []", ImpactFx.items("laser", CELL, 0.1, SEC, 3).is_empty())
	ck("sec 0 -> []", ImpactFx.items("frame", CELL, 0.0, 0.0, 3).is_empty())
	ck("form_of: known", ImpactFx.form_of({"form": "frame", "sparse": true}) == "frame")
	ck("form_of: unknown -> ''", ImpactFx.form_of({"form": "laser"}).is_empty() and ImpactFx.form_of({}).is_empty())
	# knobs change the picture
	ck("frame: sparse differs", ImpactFx.items("frame", CELL, 0.8 * SEC, SEC, 3, 1, {"sparse": true})
		!= ImpactFx.items("frame", CELL, 0.8 * SEC, SEC, 3))
	ck("spike: count 2 draws more (standing)", ImpactFx.standing_items("spike", base, 64, 0.8 * SEC, SEC, 3, 1, {"count": 2}).size()
		> ImpactFx.standing_items("spike", base, 64, 0.8 * SEC, SEC, 3).size())
	ck("ring2 draws more than ring (standing)", ImpactFx.standing_items("ring2", base, 64, 0.8 * SEC, SEC, 3).size()
		> ImpactFx.standing_items("ring", base, 64, 0.8 * SEC, SEC, 3).size())
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

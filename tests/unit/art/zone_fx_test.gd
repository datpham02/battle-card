extends SceneTree
## Batch-3 field marks stay inside the slab, differ by kind, and the jaw pulse moves.
## godot --headless --path . -s res://tests/unit/art/zone_fx_test.gd

const Fx = preload("res://src/art/zone_fx.gd")
const SLAB := Rect2i(10, 20, 64, 46)

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _inside(items: Array[Dictionary]) -> bool:
	var bound: Rect2i = SLAB.grow(2)
	for it: Dictionary in items:
		var r: Rect2i = it["rect"]
		if r.size.x <= 0 or r.size.y <= 0 or not bound.encloses(r):
			return false
	return true


func _initialize() -> void:
	for kind: String in ["trap", "ward", "pillar"]:
		var items: Array[Dictionary] = Fx.marks(kind, "", SLAB, 0)
		ck("%s draws inside" % kind, not items.is_empty() and _inside(items))
		ck("%s deterministic" % kind, items == Fx.marks(kind, "", SLAB, 0))
	ck("bay_lo is not the jaws", Fx.marks("trap", "bay_lo", SLAB, 0) != Fx.marks("trap", "bay_kep", SLAB, 0))
	ck("gai_no is not the jaws", Fx.marks("trap", "gai_no", SLAB, 0) != Fx.marks("trap", "bay_kep", SLAB, 0))
	ck("khien_thep is not the ward frame", Fx.marks("ward", "khien_thep", SLAB, 0) != Fx.marks("ward", "thanh_thuan", SLAB, 0))
	ck("jaws pulse", Fx.marks("trap", "bay_kep", SLAB, 0) != Fx.marks("trap", "bay_kep", SLAB, 7))
	ck("unknown kind draws nothing", Fx.marks("fuse", "", SLAB, 0).is_empty())
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

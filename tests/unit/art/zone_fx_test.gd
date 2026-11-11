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
	# batch 4: the death mark
	var mark: Array[Dictionary] = Fx.mark(SLAB, 0, 1.0)
	ck("mark draws inside, deterministic", not mark.is_empty() and _inside(mark) and mark == Fx.mark(SLAB, 0, 1.0))
	ck("mark breathes", mark != Fx.mark(SLAB, 4, 1.0))
	ck("mark shortens as it runs out", (Fx.mark(SLAB, 0, 0.1)[0]["rect"] as Rect2i).size.x < (mark[0]["rect"] as Rect2i).size.x)
	# Deferred 7: the fire wall base and columns
	var wf: Array[Dictionary] = Fx.wall_floor(SLAB, 0)
	ck("wall_floor draws inside, deterministic, flickers", not wf.is_empty() and _inside(wf) and wf == Fx.wall_floor(SLAB, 0) and wf != Fx.wall_floor(SLAB, 1))
	var base := Vector2i(300, 200)
	var ws: Array[Dictionary] = Fx.wall_standing(base, 64, 0)
	var ws_ok: bool = ws.all(func(it: Dictionary) -> bool:
		var r: Rect2i = it["rect"]
		return r.end.y <= base.y and r.position.y >= base.y - 64 - 8 and r.position.x >= base.x - 40 and r.end.x <= base.x + 40)
	ck("wall_standing stands on the base within one cell, deterministic, flickers", not ws.is_empty() and ws_ok
		and ws == Fx.wall_standing(base, 64, 0) and ws != Fx.wall_standing(base, 64, 3))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

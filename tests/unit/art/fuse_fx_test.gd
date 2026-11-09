extends SceneTree
## Skill v2 Hỏa Lôi H2 visuals (src/art/fuse_fx.gd): records only from the authoritative fuse event (cells, `at`), the
## 3-2-1 countdown thirds, phase changes exactly at `at` (no flame before, no sigil after), the final warning, every
## sigil rect inside its slab, the column standing on its tile, the fizzle (no flame), reduce motion (no flicker) and
## determinism.
## Run: godot --headless --path . -s res://tests/unit/art/fuse_fx_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_records_from_the_schedule()
	test_countdown_and_phases()
	test_sigil_geometry_and_warning()
	test_blast_on_the_tile()
	test_fizzle()
	test_reduce_motion_and_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _cast() -> Dictionary:
	return {"cast_id": 3, "skill_id": "hoa_loi", "clause": false, "events": [
		{"kind": "fuse", "cells": [Vector2i(4, 1), Vector2i(5, 1)], "at": 2.0},
		{"kind": "surge", "cells": [Vector2i(6, 1)], "at": 2.0}]}


func test_records_from_the_schedule() -> void:
	var recs: Array[Dictionary] = FuseFx.records_from_cast(_cast(), 0.5)
	ck("one record per armed cell of the fuse event only (other kinds ignored)", recs.size() == 2
		and recs[0]["cell"] == Vector2i(4, 1) and recs[1]["cell"] == Vector2i(5, 1))
	ck("records keep the authoritative at and the cast id", is_equal_approx(float(recs[0]["at"]), 2.0)
		and int(recs[0]["cast_id"]) == 3 and is_equal_approx(float(recs[0]["start"]), 0.5))
	ck("a cast with no fuse event (fizzled: nothing armed) gives no record",
		FuseFx.records_from_cast({"cast_id": 4, "events": []}, 0.5).is_empty())


func test_countdown_and_phases() -> void:
	var rec: Dictionary = FuseFx.records_from_cast(_cast(), 0.5)[0]
	ck("3 steps in the first third", FuseFx.steps_left(rec, 0.6) == 3 and FuseFx.steps_left(rec, 0.99) == 3)
	ck("2 in the second third", FuseFx.steps_left(rec, 1.01) == 2 and FuseFx.steps_left(rec, 1.49) == 2)
	ck("1 in the last third, 0 at the blast", FuseFx.steps_left(rec, 1.51) == 1 and FuseFx.steps_left(rec, 2.0) == 0)
	ck("sigil until the authoritative at, blast from it", FuseFx.phase(rec, 1.999) == "sigil" and FuseFx.phase(rec, 2.0) == "blast")
	ck("nothing after the blast has played out", FuseFx.phase(rec, FuseFx.end_time(rec)) == "")
	var slab := Rect2i(0, 0, 60, 42)
	ck("no flame before the blast, no sigil after it", FuseFx.eruption_items(rec, 1.999, Vector2i(30, 40), 60, false).is_empty()
		and FuseFx.sigil_items(rec, 2.0, slab, false).is_empty() and not FuseFx.eruption_items(rec, 2.0, Vector2i(30, 40), 60, false).is_empty())


func test_sigil_geometry_and_warning() -> void:
	var rec: Dictionary = FuseFx.records_from_cast(_cast(), 0.5)[0]
	var slab := Rect2i(100, 50, 60, 42)
	var ok: bool = true
	for t: float in [0.55, 0.7, 1.0, 1.4, 1.7, 1.95, 1.99]:
		for it: Dictionary in FuseFx.sigil_items(rec, t, slab, false):
			ok = ok and slab.grow(2).encloses(it["rect"])
	ck("every sigil rect stays on its slab (ground-anchored)", ok)
	var early: int = FuseFx.sigil_items(rec, 0.6, slab, false).size()
	var mid: int = FuseFx.sigil_items(rec, 0.9, slab, false).size()
	ck("the frame draws itself in (fewer pieces while it forms)", early > 0 and mid > early, "%d vs %d" % [early, mid])
	var s3: int = FuseFx.sigil_items(rec, 0.9, slab, false).size()
	var s2: int = FuseFx.sigil_items(rec, 1.3, slab, false).size()
	var s1: int = FuseFx.sigil_items(rec, 1.6, slab, false).size()
	ck("one charge ring goes out each third (3-2-1 readable without text)", s3 > s2 and s2 > s1, "%d %d %d" % [s3, s2, s1])
	var cols: Dictionary = {}
	for t: float in [1.70, 1.71, 1.72, 1.73, 1.74, 1.75, 1.76, 1.77]:
		var items: Array[Dictionary] = FuseFx.sigil_items(rec, t, slab, false)
		cols[str(items[5]["col"])] = true
	ck("the final warning flickers the frame", cols.size() >= 2, str(cols.keys()))


func test_blast_on_the_tile() -> void:
	var recs: Array[Dictionary] = FuseFx.records_from_cast(_cast(), 0.5)
	var base := Vector2i(130, 90)
	var items: Array[Dictionary] = FuseFx.eruption_items(recs[0], 2.0 + FuseFx.RISE_SEC, base, 60, false)
	var lowest: int = -100000
	var ok: bool = true
	for it: Dictionary in items:
		var r: Rect2i = it["rect"]
		lowest = maxi(lowest, r.end.y)
		ok = ok and r.end.y <= base.y
	ck("the column stands on its tile (nothing below the ground point, reaches it)", ok and lowest == base.y, "lowest %d" % lowest)
	var top: int = 100000
	for it: Dictionary in items:
		top = mini(top, (it["rect"] as Rect2i).position.y)
	ck("a tall column at the peak (>= 1 cell width high)", base.y - top >= 60, "height %d" % (base.y - top))
	var a: Array[Dictionary] = FuseFx.eruption_items(recs[0], 2.05, base, 60, false)
	var b: Array[Dictionary] = FuseFx.eruption_items(recs[1], 2.05, base, 60, false)
	ck("every armed cell blows at the same time (same column state)", a == b)
	ck("the floor flash and shock ring at the blast", not FuseFx.blast_floor_items(recs[0], 2.02, Rect2i(0, 0, 60, 42), false).is_empty())


func test_fizzle() -> void:
	var rec: Dictionary = FuseFx.records_from_cast(_cast(), 0.5)[0]
	rec["fired"] = true
	rec["fizzled"] = true
	ck("a fizzled cell: no flame column", FuseFx.eruption_items(rec, 2.05, Vector2i(30, 40), 60, false).is_empty())
	ck("a fizzled cell: ash pieces, then nothing", FuseFx.phase(rec, 2.05) == "fizzle"
		and not FuseFx.blast_floor_items(rec, 2.05, Rect2i(0, 0, 60, 42), false).is_empty() and FuseFx.phase(rec, 2.0 + FuseFx.FIZZLE_SEC) == "")


func test_reduce_motion_and_determinism() -> void:
	var rec: Dictionary = FuseFx.records_from_cast(_cast(), 0.5)[0]
	var slab := Rect2i(0, 0, 60, 42)
	var cols: Dictionary = {}
	for t: float in [1.70, 1.73, 1.76, 1.79]:
		cols[str(FuseFx.sigil_items(rec, t, slab, true)[5]["col"])] = true
	ck("reduce motion: the final warning is steady (no flicker)", cols.size() == 1)
	ck("deterministic", FuseFx.eruption_items(rec, 2.1, Vector2i(30, 40), 60, false) == FuseFx.eruption_items(rec, 2.1, Vector2i(30, 40), 60, false))
	ck("glyph lights cell by cell over the 0.45 s cast", FuseFx.glyph_items(Vector2i(10, 10), 0.1, false).size()
		< FuseFx.glyph_items(Vector2i(10, 10), 0.9, false).size())

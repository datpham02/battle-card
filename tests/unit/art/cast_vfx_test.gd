extends SceneTree
## 2026-10-31 (user: the skill must be cast out from the character): CastVfx — the shipped index maps the
## Swordsman (and any other hero) to the sword_wave pack, the flight lands exactly when the swing resolves, the
## gesture starts travel + lead before, and positions are whole art px. Headless, pure (no node).
## Run: godot --headless --path . -s res://tests/unit/art/cast_vfx_test.gd

var fails: int = 0


func ck(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))


func _initialize() -> void:
	CastVfx.clear_cache()
	var e: Dictionary = CastVfx.entry_for("kiem_si")
	# 2026-11-02: the Swordsman's cast is drawn by the tools/fx-pipeline packs; sword_wave stays the default (rollback).
	ck("index: kiem_si -> square_wave_steel", str(e.get("id", "")) == "square_wave_steel", str(e))
	ck("index: an unmapped hero uses the default", str(CastVfx.entry_for("phap_su").get("id", "")) == "sword_wave")
	ck("pack: square_wave_steel loads with its clip", CastVfx.pack_for(e) != null and not CastVfx.pack_for(e).clip("whole").is_empty())
	ck("pack: square_wave_steel keeps the sword_wave timing", is_equal_approx(CastVfx.travel_sec(e), CastVfx.travel_sec(CastVfx.pack_entry("sword_wave")))
		and CastVfx.gesture_hold_frame(e) == CastVfx.gesture_hold_frame(CastVfx.pack_entry("sword_wave")))
	ck("pack: square_wave_steel draws its art, not the code streak", str(e.get("travel_draw", "")) != "square_streak")
	# Release cut: plays once at the hand from the slash frame (gesture_lead before the launch).
	var due: float = CastVfx.gesture_due_left(e)
	ck("release: the cut pack loads", CastVfx.pack_for(CastVfx.release_entry(e)) != null)
	ck("release: none before the slash frame", CastVfx.release_elapsed(e, due + 0.01) < 0.0)
	ck("release: starts at the slash frame", is_zero_approx(CastVfx.release_elapsed(e, due)))
	ck("release: 0.1 s in, 0.1 s later", is_equal_approx(CastVfx.release_elapsed(e, due - 0.1), 0.1))
	ck("release: an entry without one never plays", CastVfx.release_elapsed(CastVfx.pack_entry("sword_wave"), 0.0) < 0.0)
	ck("impacts: packs replace the code shards for square_wave_steel only",
		CastVfx.packs_replace_shards(e) and not CastVfx.packs_replace_shards(CastVfx.pack_entry("sword_wave")))
	var fv := FloorVfx.new()
	for id: String in [str(e.get("impact", "")), str(e.get("cell_burst", "")), str(e.get("impact_mark", "")), str(e.get("cell_mark", ""))]:
		ck("impacts: floor pack %s is drawable" % id, fv.has_pack(id))
	var travel: float = CastVfx.travel_sec(e)
	ck("flight: not launched before travel_sec is left", CastVfx.flight_t(e, travel + 0.01) < 0.0)
	ck("flight: t = 0 at the launch", is_equal_approx(CastVfx.flight_t(e, travel), 0.0))
	ck("flight: t = 1 when the swing resolves", is_equal_approx(CastVfx.flight_t(e, 0.0), 1.0))
	ck("flight: half way at half travel", is_equal_approx(CastVfx.flight_t(e, travel * 0.5), 0.5))
	ck("gesture: due travel + lead before the resolve", is_equal_approx(CastVfx.gesture_due_left(e), travel + CastVfx.gesture_lead_sec(e)))
	var p: Vector2i = CastVfx.flight_pos(Vector2i(10, 20), Vector2i(31, 20), 0.5)
	ck("pos: whole px between the ends", p == Vector2i(21, 20) or p == Vector2i(20, 20), str(p))
	ck("pos: clamped past the end", CastVfx.flight_pos(Vector2i(0, 0), Vector2i(8, 0), 2.0) == Vector2i(8, 0))
	ck("hand: feet + hand offset", CastVfx.hand_point({"hand": [14, -34]}, Vector2i(100, 200)) == Vector2i(114, 166))
	var aim: Vector2i = CastVfx.aim_point({"aim_lift": 18}, [Vector2i(300, 200), Vector2i(340, 200)] as Array[Vector2i])
	ck("aim: mean of the targets lifted", aim == Vector2i(320, 182), str(aim))
	ck("aim: no targets -> zero", CastVfx.aim_point({}, [] as Array[Vector2i]) == Vector2i.ZERO)
	ck("defaults: an empty entry still has positive timings", CastVfx.travel_sec({}) > 0.0 and CastVfx.gesture_lead_sec({}) >= 0.0)
	# OSFE beats (design/references/osfe-spell-anatomy.md, user 2026-11-01).
	ck("wave: sword_wave flies straight to the first cell", str(e.get("path", "")) == CastVfx.PATH_FIRST_CELL)
	var charge: float = CastVfx.charge_sec(e)
	ck("charge: none before the window", CastVfx.charge_elapsed(e, travel + charge + 0.01) < 0.0)
	ck("charge: starts at travel + charge left", is_equal_approx(CastVfx.charge_elapsed(e, travel + charge), 0.0))
	ck("charge: ends at the launch", CastVfx.charge_elapsed(e, travel) < 0.0)
	ck("charge: hand_charge pack loads", CastVfx.pack_for(CastVfx.charge_entry(e)) != null)
	var to: Vector2i = CastVfx.flight_to({"path": CastVfx.PATH_ROW}, Vector2i(100, 150), [Vector2i(400, 210), Vector2i(330, 250)] as Array[Vector2i])
	ck("row: straight along the hero row to the nearest column", to == Vector2i(330, 150), str(to))
	ck("row: an entry without path still aims at the targets", CastVfx.flight_to({"aim_lift": 0}, Vector2i(0, 0), [Vector2i(10, 20)] as Array[Vector2i]) == Vector2i(10, 20))
	ck("wave: damage cards flow as a wave, no separate per-cell blast", CastVfx.flows_for(e, "damage") and CastVfx.blast_for(e, "damage") == "")
	ck("wave: other effects do not flow", not CastVfx.flows_for(e, "burn"))
	var delays: Dictionary = CastVfx.blast_delays({"stagger_sec": 0.04}, [Vector2i(4, 1), Vector2i(3, 1), Vector2i(5, 1), Vector2i(4, 2)])
	ck("stagger: nearest column first", is_zero_approx(float(delays[Vector2i(3, 1)])))
	ck("stagger: one column later = one step", is_equal_approx(float(delays[Vector2i(4, 1)]), 0.04) and is_equal_approx(float(delays[Vector2i(4, 2)]), 0.04))
	ck("stagger: two columns later = two steps", is_equal_approx(float(delays[Vector2i(5, 1)]), 0.08))
	var feel: Dictionary = CastVfx.hit_feel()
	ck("hit feel: flash and shake from the index", float(feel["flash_sec"]) > 0.0 and int(feel["shake_px"]) > 0)
	ck("shake: none when no time is left", UnitLayer.shake_offset(0.0, 2) == Vector2i.ZERO)
	# Wave flow (user 2026-11-01: like a sea wave, it lands on the first cell and spills on through the area).
	var area: Array = [Vector2i(4, 1), Vector2i(3, 1), Vector2i(5, 1), Vector2i(4, 2)]
	var first: Vector2i = CastVfx.first_cell(area, Vector2i(1, 1))
	ck("flow: the first cell is the one nearest the hero", first == Vector2i(3, 1), str(first))
	var plan: Dictionary = CastVfx.flow_plan(area, first, 0.07, 0.08)
	var arr: Dictionary = plan["arrive"]
	ck("flow: lands at 0", is_zero_approx(float(arr[Vector2i(3, 1)])))
	ck("flow: the neighbour one step later", is_equal_approx(float(arr[Vector2i(4, 1)]), 0.07))
	ck("flow: two steps away = two steps later", is_equal_approx(float(arr[Vector2i(5, 1)]), 0.14) and is_equal_approx(float(arr[Vector2i(4, 2)]), 0.14))
	ck("flow: ends after the last cell's linger", is_equal_approx(float(plan["end"]), 0.22))
	var mid: Array[Dictionary] = CastVfx.flow_fronts(plan, 0.105)
	ck("flow: mid-way the front runs from (4,1) to both next cells", mid.size() == 2 and float(mid[0]["t"]) > 0.4 and float(mid[0]["t"]) < 0.6, str(mid))
	var held: Dictionary = CastVfx.flow_plan(area, first, 0.08, 0.08, 0.13)["arrive"]
	ck("flow: the big explosion holds the spread on the first cell", is_equal_approx(float(held[Vector2i(4, 1)]), 0.21) and is_equal_approx(float(held[Vector2i(5, 1)]), 0.29))
	var island: Dictionary = CastVfx.flow_plan([Vector2i(3, 0), Vector2i(5, 2)], Vector2i(3, 0), 0.07)
	ck("flow: a cell not joined to the area is reached by distance", is_equal_approx(float(island["arrive"][Vector2i(5, 2)]), 0.28))
	ck("flow: nothing after the end", CastVfx.flow_fronts(plan, 0.3).is_empty())
	# Flood (user 2026-11-01 correction): explode on the first cell, then one stain floods back over the area.
	var fc: Array[Dictionary] = CastVfx.flood_cells(plan, 0.105, 0.07, 0.3, 0.3)
	var by_cell: Dictionary = {}
	for item: Dictionary in fc:
		by_cell[item["cell"]] = item
	ck("flood: the first cell grows from its centre", by_cell.has(Vector2i(3, 1)) and by_cell[Vector2i(3, 1)]["dir"] == Vector2i.ZERO)
	ck("flood: the next cell wipes in from the first", by_cell.has(Vector2i(4, 1)) and by_cell[Vector2i(4, 1)]["dir"] == Vector2i(1, 0) and float(by_cell[Vector2i(4, 1)]["reveal"]) > 0.4)
	ck("flood: a cell not reached yet is absent", not by_cell.has(Vector2i(5, 1)) and not by_cell.has(Vector2i(4, 2)))
	ck("flood: (4,2) comes in from above", CastVfx.flood_cells(plan, 0.2, 0.07, 0.3, 0.3).filter(func(it: Dictionary) -> bool: return it["cell"] == Vector2i(4, 2))[0]["dir"] == Vector2i(0, 1))
	ck("flood: all gone after flood_end", CastVfx.flood_cells(plan, CastVfx.flood_end(plan, 0.07, 0.3, 0.3) + 0.01, 0.07, 0.3, 0.3).is_empty())
	ck("flood_rect: half a wipe from the left", CastVfx.flood_rect(Rect2i(10, 20, 64, 46), 0.5, Vector2i(1, 0)) == Rect2i(10, 20, 32, 46))
	ck("flood_rect: from below", CastVfx.flood_rect(Rect2i(10, 20, 64, 46), 0.5, Vector2i(0, -1)) == Rect2i(10, 43, 64, 23))
	ck("flood_rect: centre growth", CastVfx.flood_rect(Rect2i(0, 0, 64, 46), 0.5, Vector2i.ZERO) == Rect2i(16, 11, 32, 23))
	# v4 wind-up (2026-11-01): the hero holds the coil frame during the telegraph.
	ck("hold: sword_wave holds the coil frame 4", CastVfx.gesture_hold_frame(e) == 4)
	ck("hold: an entry without one keeps the old frame-0 wait", CastVfx.gesture_hold_frame({}) == -1)
	ck("shake: flips side", UnitLayer.shake_offset(0.01, 2) == Vector2i(2, 0) and UnitLayer.shake_offset(0.04, 2) == Vector2i(-2, 0))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## ADR-0001 Phase 1 Task 5: CastFloorFx, the pure code-drawn geometry of the cast / floor presentation - charge steps
## and colours, the check mark, the streak / fall / run travels, the floor-run corner, the square impact flash, the
## square impacts (item 2), the drop-tile pit layout and its colours (no red). Headless, deterministic, no node.
## Run: godot --headless --path . -s res://tests/unit/art/cast_floor_fx_test.gd

const CELL := Rect2i(100, 60, 64, 46)
const SLAB := Rect2i(100, 60, 60, 40)
const RED := Color("E5293B")

var fails: int = 0


func ck(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))


func _initialize() -> void:
	_charge()
	_check()
	_travel()
	_flash()
	_impacts()
	_pit()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _charge() -> void:
	ck("charge_step: 0 at the start", CastFloorFx.charge_step(0.0, 4) == 0)
	ck("charge_step: 0 just below 1/4", CastFloorFx.charge_step(0.249, 4) == 0)
	ck("charge_step: 1 at 1/4", CastFloorFx.charge_step(0.25, 4) == 1)
	ck("charge_step: 3 at 3/4", CastFloorFx.charge_step(0.75, 4) == 3)
	ck("charge_step: last step at 1 (never steps)", CastFloorFx.charge_step(1.0, 4) == 3)
	ck("charge_step: clamped below 0", CastFloorFx.charge_step(-1.0, 4) == 0)
	ck("charge_step: clamped above 1", CastFloorFx.charge_step(2.0, 4) == 3)
	ck("charge_step: steps < 1 behaves as 1", CastFloorFx.charge_step(0.9, 0) == 0)
	var base := Color("8FA3B8")
	var light := Color("EEF4FA")
	var a: Dictionary = CastFloorFx.charge_colours(base, light, CastFloorFx.charge_step(0.30, 4), 4)
	var b: Dictionary = CastFloorFx.charge_colours(base, light, CastFloorFx.charge_step(0.49, 4), 4)
	var c: Dictionary = CastFloorFx.charge_colours(base, light, CastFloorFx.charge_step(0.51, 4), 4)
	ck("charge_colours: same step, same colours", a["fill"] == b["fill"] and a["outline"] == b["outline"])
	ck("charge_colours: next step, new colours", a["fill"] != c["fill"] and a["outline"] != c["outline"])
	var first: Dictionary = CastFloorFx.charge_colours(base, light, 0, 4)
	var last: Dictionary = CastFloorFx.charge_colours(base, light, 3, 4)
	ck("charge_colours: fill alpha lo at step 0", is_equal_approx((first["fill"] as Color).a, 0.35))
	ck("charge_colours: fill alpha hi at the last step", is_equal_approx((last["fill"] as Color).a, 0.75))
	ck("charge_colours: outline base at step 0, light at the end", first["outline"] == base and (last["outline"] as Color).is_equal_approx(light))


func _check() -> void:
	for s: int in [1, 2, 3]:
		var rects: Array[Rect2i] = CastFloorFx.check_rects(CELL, s)
		var box := Rect2i(rects[0])
		for r: Rect2i in rects:
			box = box.merge(r)
		ck("check: %d px -> %s" % [s, str(CastFloorFx.CHECK_SIZE * s)], box.size == CastFloorFx.CHECK_SIZE * s, str(box.size))
		ck("check: %d px inside the cell" % s, CELL.encloses(box))
	ck("check: one rect per point", CastFloorFx.check_rects(CELL, 2).size() == CastFloorFx.CHECK_POINTS.size())


func _travel() -> void:
	var a := Vector2i(10, 50)
	var b := Vector2i(110, 50)
	ck("streak: [] before 0", CastFloorFx.streak_rects(a, b, -0.01, 4, 5, 6).is_empty())
	ck("streak: [] after 1", CastFloorFx.streak_rects(a, b, 1.01, 4, 5, 6).is_empty())
	var s0: Array[Rect2i] = CastFloorFx.streak_rects(a, b, 0.0, 4, 5, 6)
	ck("streak: at 0 only the head, on the start", s0.size() == 1 and s0[0] == CastFloorFx.square_rect(a, 5), str(s0))
	var s1: Array[Rect2i] = CastFloorFx.streak_rects(a, b, 1.0, 4, 5, 6)
	ck("streak: at 1 the head on the end", s1.size() == 4 and s1[0] == CastFloorFx.square_rect(b, 5), str(s1))
	ck("streak: the tail shrinks 1 px per square", s1[1].size.x == 4 and s1[3].size.x == 2)
	var fall_start: Array[Rect2i] = CastFloorFx.fall_rects(CELL, 0.2, 0.2, 70, 3, 4, 7)
	var fall_land: Array[Rect2i] = CastFloorFx.fall_rects(CELL, 0.0, 0.2, 70, 3, 4, 7)
	ck("fall: [] before the drop starts", CastFloorFx.fall_rects(CELL, 0.21, 0.2, 70, 3, 4, 7).is_empty())
	ck("fall: [] after the landing", CastFloorFx.fall_rects(CELL, -0.01, 0.2, 70, 3, 4, 7).is_empty())
	ck("fall: 3 squares at the start, high above the cell", fall_start.size() == 3 and fall_start[0].end.y < CELL.position.y, str(fall_start))
	var landed: bool = fall_land.size() == 3
	for r: Rect2i in fall_land:
		landed = landed and CELL.encloses(r)
	ck("fall: all land inside the cell at arrival 0", landed, str(fall_land))
	ck("fall: deterministic per seed", fall_land == CastFloorFx.fall_rects(CELL, 0.0, 0.2, 70, 3, 4, 7))
	var o := Vector2i(0, 0)
	var e := Vector2i(40, 30)
	ck("run: [] before the start", CastFloorFx.run_rects(o, e, -0.01, 0.2, 3, 4, 0.025).is_empty())
	ck("run: [] after the arrival", CastFloorFx.run_rects(o, e, 0.21, 0.2, 3, 4, 0.025).is_empty())
	ck("run: [] for arrival 0 (nothing to run)", CastFloorFx.run_rects(o, e, 0.0, 0.0, 3, 4, 0.025).is_empty())
	var r0: Array[Rect2i] = CastFloorFx.run_rects(o, e, 0.0, 0.2, 3, 4, 0.025)
	ck("run: at 0 the head on the origin", r0.size() == 1 and r0[0] == CastFloorFx.square_rect(o, 4))
	var r1: Array[Rect2i] = CastFloorFx.run_rects(o, e, 0.2, 0.2, 3, 4, 0.025)
	ck("run: at the arrival the head on the target", r1[0] == CastFloorFx.square_rect(e, 4) and r1.size() == 3)
	ck("l_point: start", CastFloorFx.l_point(o, e, 0.0) == o)
	ck("l_point: end", CastFloorFx.l_point(o, e, 1.0) == e)
	ck("l_point: corner after the row leg", CastFloorFx.l_point(o, e, 40.0 / 70.0) == Vector2i(40, 0), str(CastFloorFx.l_point(o, e, 40.0 / 70.0)))
	ck("l_point: on the row before the corner", CastFloorFx.l_point(o, e, 20.0 / 70.0) == Vector2i(20, 0))
	ck("l_point: on the column after the corner", CastFloorFx.l_point(o, e, 55.0 / 70.0) == Vector2i(40, 15))
	ck("l_point: same point -> the target", CastFloorFx.l_point(e, e, 0.5) == e)


func _flash() -> void:
	ck("flash: [] before", CastFloorFx.flash_rects(CELL, -0.01, 0.12).is_empty())
	ck("flash: [] at the end", CastFloorFx.flash_rects(CELL, 0.12, 0.12).is_empty())
	ck("flash: [] with sec 0", CastFloorFx.flash_rects(CELL, 0.0, 0.0).is_empty())
	var st0: Array[Dictionary] = CastFloorFx.flash_rects(CELL, 0.0, 0.12)
	var st1: Array[Dictionary] = CastFloorFx.flash_rects(CELL, 0.05, 0.12)
	var st2: Array[Dictionary] = CastFloorFx.flash_rects(CELL, 0.11, 0.12)
	ck("flash: stage 0 a filled inner square", st0.size() == 1 and bool(st0[0]["fill"]) and CELL.encloses(st0[0]["rect"]))
	ck("flash: stage 1 a 2 px outline", st1.size() == 1 and not bool(st1[0]["fill"]) and int(st1[0]["width"]) == 2)
	ck("flash: stage 2 a 1 px outline at the cell edge", st2.size() == 1 and int(st2[0]["width"]) == 1 and st2[0]["rect"] == CELL.grow(-1))


func _impacts() -> void:
	for kind: String in CastFloorFx.IMPACT_KINDS:
		ck("impact %s: [] before" % kind, CastFloorFx.impact_rects(kind, CELL, -0.01, 0.25, 3).is_empty())
		ck("impact %s: [] at the end" % kind, CastFloorFx.impact_rects(kind, CELL, 0.25, 0.25, 3).is_empty())
		var mid: Array[Dictionary] = CastFloorFx.impact_rects(kind, CELL, 0.1, 0.25, 3)
		ck("impact %s: shards mid-way" % kind, not mid.is_empty())
		ck("impact %s: deterministic" % kind, mid == CastFloorFx.impact_rects(kind, CELL, 0.1, 0.25, 3))
		var near: bool = true
		for it: Dictionary in mid:
			near = near and CELL.grow(8).encloses(it["rect"])
		ck("impact %s: stays on its cell" % kind, near)
	ck("impact: unknown kind -> []", CastFloorFx.impact_rects("laser", CELL, 0.1, 0.25, 3).is_empty())
	var right: Array[Dictionary] = CastFloorFx.impact_rects("knockback", CELL, 0.2, 0.25, 3, 1)
	var left: Array[Dictionary] = CastFloorFx.impact_rects("knockback", CELL, 0.2, 0.25, 3, -1)
	ck("impact knockback: pushed the cast's way", (right[0]["rect"] as Rect2i).position.x > (left[0]["rect"] as Rect2i).position.x)


func _pit() -> void:
	var a: Dictionary = CastFloorFx.pit_layout(SLAB, 42)
	ck("pit: deterministic per seed", a == CastFloorFx.pit_layout(SLAB, 42))
	ck("pit: another seed, another rim", a["rim"] != CastFloorFx.pit_layout(SLAB, 43)["rim"])
	var inside: bool = SLAB.encloses(a["deep"])
	for key: String in ["bands", "rim", "rubble"]:
		for r: Rect2i in a[key]:
			inside = inside and SLAB.encloses(r)
	ck("pit: every rect inside the slab", inside)
	ck("pit: back wall above the middle band", (a["bands"][0] as Rect2i).end.y == (a["bands"][1] as Rect2i).position.y)
	ck("pit: %d rubble squares" % CastFloorFx.PIT_RUBBLE, (a["rubble"] as Array).size() == CastFloorFx.PIT_RUBBLE)
	var cols: Dictionary = CastFloorFx.pit_colours(Color("3A3B37"), Color("262521"), Color("5A5B54"))
	var no_red: bool = true
	for k: String in cols:
		var c: Color = cols[k]
		var close: bool = absf(c.r - RED.r) + absf(c.g - RED.g) + absf(c.b - RED.b) < 0.45
		var r_dominant: bool = c.r > c.g + 0.12 and c.r > c.b + 0.12
		no_red = no_red and not close and not r_dominant
	ck("pit colours: no red", no_red, str(cols))
	var floor_l: float = Color("3A3B37").get_luminance()
	ck("pit colours: the deep floor darker than the floor", (cols["deep"] as Color).get_luminance() < floor_l)
	ck("pit colours: the rim lighter than the deep floor (a visible edge)", (cols["rim"] as Color).get_luminance() > (cols["deep"] as Color).get_luminance() + 0.15)
	ck("pit colours: depth bands step down", (cols["wall"] as Color).get_luminance() > (cols["mid"] as Color).get_luminance() and (cols["mid"] as Color).get_luminance() > (cols["deep"] as Color).get_luminance())
	var tuned: Dictionary = CastFloorFx.pit_colours(Color("3A3B37"), Color("262521"), Color("5A5B54"), {"rim_light": 0.0})
	ck("pit colours: tuning overrides a key", tuned["rim"] == Color("5A5B54"))

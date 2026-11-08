extends SceneTree
## Skill v2 SkyDropFx (Ngàn Kiếm VFX, reusable for SKY_TO_TARGET cards): target-to-blade mapping from the REAL
## schedule (SwingArbiter.cast_scheduled), impact timing (the tip touches the ground exactly at the authoritative `at`),
## tile-exact shadows, phases, sword silhouette, finale emphasis, cleanup after interruption / match end, nothing left
## after the end, and no gameplay change from drawing.
## Run: godot --headless --path . -s res://tests/unit/art/sky_drop_fx_test.gd

const EPS: float = 0.0001
var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_mapping_from_real_schedule()
	test_impact_timing_and_phases()
	test_shadow()
	test_silhouette_and_finale()
	test_cleanup()
	test_scale_targets()
	test_landing_alignment_with_offsets()
	test_stacked_swords_do_not_overlap()
	test_hud_safety()
	test_enemy_stays_visible()
	test_finale_emphasis()
	test_board_shake_visual_only()
	test_deterministic_rendering()
	test_on_tile_summon()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# A real ngan_kiem plus5 cast through the arbiter; returns {cast (cast_scheduled payload), arb, state}.
func _real_cast() -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, Vector2i(1, 1), Vector2i(9, 1))
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var arb := SwingArbiter.new(state, grid, player, CutActor.new(cc, CombatState.Side.ENEMY), cc, sc, fx)
	var got: Array = []
	arb.cast_scheduled.connect(func(_s: int, cast: Dictionary) -> void: got.append({"cast": cast, "t0": arb.clock()}))
	var cells: Array[Vector2i] = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece("plus5", 0)]
	var ctx: Dictionary = CastContext.build("ngan_kiem", 1, pieces, [cells], sc.get_skill("ngan_kiem")["delivery"], false,
		CombatState.Side.PLAYER, Vector2i(1, 1))
	player.begin_swing(cells, "ngan_kiem", true, 1, 0.5, {}, ctx)
	arb.tick(0.51)
	return {"cast": got[0]["cast"] if not got.is_empty() else {}, "t0": got[0]["t0"] if not got.is_empty() else 0.0, "arb": arb, "state": state}


func test_mapping_from_real_schedule() -> void:
	var r: Dictionary = _real_cast()
	var cast: Dictionary = r["cast"]
	var recs: Array[Dictionary] = SkyDropFx.records_from_cast(cast, float(r["t0"]))
	var ev: Array = cast.get("events", []) as Array
	ck("one blade per scheduled drop (5)", recs.size() == 5 and ev.size() == 5)
	var same: bool = true
	for i: int in recs.size():
		same = same and recs[i]["cell"] == (ev[i]["cells"] as Array)[0] and absf(float(recs[i]["at"]) - float(ev[i]["at"])) < EPS
	ck("each blade = its event's cell and authoritative time, in schedule order", same)
	ck("only the branched centre is the finale", recs.filter(func(d: Dictionary) -> bool: return d["final"]).size() == 1
		and recs[4]["final"] and recs[4]["cell"] == Vector2i(5, 1))
	ck("blades start at the swing end (t0 = clock at schedule)", recs.all(func(d: Dictionary) -> bool: return absf(float(d["t0"]) - 0.5) < 0.02))


func _d(at: float, final: bool = false) -> Dictionary:
	return {"cell": Vector2i(5, 1), "at": at, "t0": 0.0, "final": final, "seed": 3, "cast_id": 1}


func test_impact_timing_and_phases() -> void:
	var d: Dictionary = _d(0.62)
	var g: int = 100
	ck("hovering above the tile before the fall", SkyDropFx.tip_y(d, 0.4, g) < g)
	ck("the tip reaches the ground exactly at the authoritative time (sunk after)", SkyDropFx.tip_y(d, 0.62 - 0.0001, g) <= g
		and SkyDropFx.tip_y(d, 0.62, g) == g + SkyDropFx.SINK_PX)
	ck("falls downward (monotonic)", SkyDropFx.tip_y(d, 0.53, g) < SkyDropFx.tip_y(d, 0.58, g) and SkyDropFx.tip_y(d, 0.58, g) < SkyDropFx.tip_y(d, 0.615, g))
	var seq: Array = [0.05, 0.3, 0.55, 0.7, 0.62 + SkyDropFx.EMBED_SEC + 0.05].map(func(t: float) -> String: return SkyDropFx.phase(d, t))
	ck("phases: materialize, hover, fall, embedded, shatter", seq == ["materialize", "hover", "fall", "embedded", "shatter"], str(seq))
	ck("impact flash only after the authoritative time", not _has_core(SkyDropFx.items(d, 0.61, Vector2i(50, g)))
		and _has_core(SkyDropFx.items(d, 0.63, Vector2i(50, g))))


func _has_core(items: Array[Dictionary]) -> bool:
	return items.any(func(it: Dictionary) -> bool: return int(it["tone"]) == SkyDropFx.TONE_CORE and (it["rect"] as Rect2i).size.x >= 7)


func test_shadow() -> void:
	var d: Dictionary = _d(0.62)
	ck("no shadow before the cast or after the strike", SkyDropFx.shadow_alpha(d, -0.1) == 0.0 and SkyDropFx.shadow_alpha(d, 0.62) == 0.0)
	ck("shadow darkens toward the strike", SkyDropFx.shadow_alpha(d, 0.1) < SkyDropFx.shadow_alpha(d, 0.5) and SkyDropFx.shadow_alpha(d, 0.0) > 0.0)
	var cell := Rect2i(100, 50, 64, 46)
	var s: Rect2i = SkyDropFx.shadow_rect(cell)
	ck("shadow is tile-exact (inside its cell, centred)", cell.encloses(s) and s.get_center() == cell.get_center())


func test_silhouette_and_finale() -> void:
	var tip := Vector2i(50, 100)
	var rects: Array[Dictionary] = SkyDropFx.blade_rects(tip, 1.0)
	var lowest: int = 0
	var blade_w: int = 0
	var guard_w: int = 0
	for it: Dictionary in rects:
		var r: Rect2i = it["rect"]
		lowest = maxi(lowest, r.end.y)
		if r.size.y > 10:
			blade_w = maxi(blade_w, r.size.x)
		guard_w = maxi(guard_w, r.size.x)
	ck("pointed down: the tip is the lowest pixel", lowest == tip.y)
	ck("a sword, not a bar: guard wider than the blade, hilt + pommel above", guard_w > blade_w and rects.size() >= 8, "guard %d blade %d" % [guard_w, blade_w])
	var area := func(items: Array[Dictionary]) -> int:
		var a: int = 0
		for it: Dictionary in items:
			a += (it["rect"] as Rect2i).get_area()
		return a
	var normal: int = area.call(SkyDropFx.items(_d(0.62), 0.4, Vector2i(50, 100)))
	var final: int = area.call(SkyDropFx.items(_d(0.62, true), 0.4, Vector2i(50, 100)))
	ck("the finale blade is bigger", final > normal, "%d vs %d" % [final, normal])
	var cols: Array[Color] = SkyDropFx.tone_colours(true)
	ck("steel colours, never the telegraph red", not cols.has(Color("#E5293B")) and not SkyDropFx.tone_colours(false).has(Color("#E5293B")))


func test_cleanup() -> void:
	var recs: Array = [_d(0.5), _d(0.62), _d(0.74)]
	var alive := func(_id: int) -> bool: return false
	var now: float = 0.6
	var shown: Array[Dictionary] = SkyDropFx.drops_now(recs, now, alive)
	ck("cast dropped (death / match end): pending blades vanish, the landed one finishes", shown.size() == 1 and absf(float(shown[0]["at"]) - 0.5) < EPS)
	ck("nothing drawn after the last shatter", SkyDropFx.drops_now(recs, 0.74 + SkyDropFx.end_after_impact() + 0.01).is_empty()
		and SkyDropFx.items(_d(0.74), 0.74 + SkyDropFx.end_after_impact(), Vector2i(50, 100)).is_empty())
	# Drawing never touches gameplay: a full real cast's damage equals its hits regardless of how often VFX is sampled.
	var r: Dictionary = _real_cast()
	var recs2: Array[Dictionary] = SkyDropFx.records_from_cast(r["cast"], float(r["t0"]))
	var hp_before: float = (r["state"] as CombatState).enemy_hp
	for i: int in 50:
		for d: Dictionary in SkyDropFx.drops_now(recs2, 0.5 + float(i) * 0.03):
			SkyDropFx.items(d, 0.5 + float(i) * 0.03, Vector2i(50, 100))
	ck("sampling the VFX changes no HP (no damage from visuals)", is_equal_approx((r["state"] as CombatState).enemy_hp, hp_before))
	(r["arb"] as SwingArbiter).tick(3.0)
	ck("after the cast the arbiter holds no cast (blades cannot outlive it)", not (r["arb"] as SwingArbiter).has_cast(int((r["cast"] as Dictionary)["cast_id"])))


# docs/art/vfx-scale-impact-guide.md targets at 640x360 (a drawn tile ~60 x 43 px): a SIGNATURE sword 1.3-1.8 tile
# heights, the blade-ground impact 0.8-1.2 tile widths, the finale +30-50 % emphasis.
const TILE_W: float = 60.0
const TILE_H: float = 43.0


func _extent(items: Array[Dictionary]) -> Vector2i:
	var lo := Vector2i(99999, 99999)
	var hi := Vector2i(-99999, -99999)
	for it: Dictionary in items:
		var r: Rect2i = it["rect"]
		lo = Vector2i(mini(lo.x, r.position.x), mini(lo.y, r.position.y))
		hi = Vector2i(maxi(hi.x, r.end.x), maxi(hi.y, r.end.y))
	return hi - lo


func test_scale_targets() -> void:
	var h: float = float(_extent(SkyDropFx.blade_rects(Vector2i(100, 200), 1.0)).y) / TILE_H
	ck("sword height 1.3-1.8 tile heights", h >= 1.3 and h <= 1.8, "%.2f" % h)
	var fh: float = float(_extent(SkyDropFx.blade_rects(Vector2i(100, 200), SkyDropFx.FINAL_SCALE, -1, true)).y) / TILE_H
	ck("finale sword 30-50 %% taller", fh / h >= 1.29 and fh / h <= 1.5, "%.2f" % (fh / h))
	var d: Dictionary = {"cell": Vector2i.ZERO, "at": 0.5, "t0": 0.0, "final": false, "seed": 1, "cast_id": 1}
	var w: float = float(_extent(SkyDropFx._impact(Vector2i(100, 200), 0.05, 1, false)).x) / TILE_W
	ck("blade-ground impact 0.8-1.2 tile widths at its flash", w >= 0.8 and w <= 1.2, "%.2f" % w)
	var fw: float = float(_extent(SkyDropFx._impact(Vector2i(100, 200), 0.05, 1, true)).x) / TILE_W
	ck("finale impact 30-50 %% wider", fw / w >= 1.29 and fw / w <= 1.5, "%.2f" % (fw / w))
	ck("hovering tip stays within one tile height above its tile", float(SkyDropFx.HOVER_TIP_PX) <= TILE_H and d["at"] == 0.5)



# --- Visual layout (2026-11-08 scale finalization): visual-only offsets, never the target cell or the timing ---------

const GROUND_TOP: int = 102  # drawn ground centre of the top row at 640x360 (DemoArgs geometry print)


func _cast(cells: Array, final_cell: Vector2i = Vector2i(-99, -99)) -> Dictionary:
	var ev: Array = []
	for i: int in cells.size():
		var c: Vector2i = cells[i]
		ev.append({"cells": [c], "at": 0.5 + 0.12 * float(i),
			"kind": CastResolver.KIND_DROP_FINAL if c == final_cell else CastResolver.KIND_DROP})
	return {"cast_id": 7, "events": ev}


func _base(cell: Vector2i) -> Vector2i:
	return Vector2i(100 + cell.x * 60, GROUND_TOP + cell.y * 43)


func _sword_at(d: Dictionary, now: float) -> Array[Dictionary]:
	var b: Vector2i = _base(d["cell"])
	return SkyDropFx.blade_rects(Vector2i(b.x + SkyDropFx.x_offset(d, now), SkyDropFx.tip_y(d, now, b.y)),
		SkyDropFx.FINAL_SCALE if d["final"] else 1.0)


func test_landing_alignment_with_offsets() -> void:
	var cells: Array = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]
	var recs: Array[Dictionary] = SkyDropFx.records_from_cast(_cast(cells, Vector2i(5, 1)), 0.0, [Vector2i(5, 1)])
	var ok: bool = true
	var moved: int = 0
	for i: int in recs.size():
		var d: Dictionary = recs[i]
		var at: float = float(d["at"])
		moved += 1 if SkyDropFx.x_offset(d, at - 0.2) != 0 else 0
		ok = ok and SkyDropFx.x_offset(d, at) == 0 and SkyDropFx.x_offset(d, at + 0.05) == 0 and SkyDropFx.x_offset(d, at + 0.3) == 0 and SkyDropFx.tip_y(d, at, 200) == 200 + SkyDropFx.SINK_PX \
			and SkyDropFx.tip_y(d, at - 0.0001, 200) <= 200 and d["cell"] == cells[i]
	ck("offset swords land on their tile centre exactly at the authoritative time; cells unchanged", ok and moved == 2,
		"moved %d" % moved)
	var dxs: Array = recs.map(func(d: Dictionary) -> int: return int(d["dx"]))
	ck("plus: the sword behind the finale moves 26, the one in front of it 18, the rest and the finale stay centred",
		dxs == [26, 0, 0, 0, 18], str(dxs))
	var d0: Dictionary = recs[0]
	ck("the offset slides home over the fall (monotonic)", SkyDropFx.x_offset(d0, float(d0["at"]) - 0.06) < 26
		and SkyDropFx.x_offset(d0, float(d0["at"]) - 0.02) < SkyDropFx.x_offset(d0, float(d0["at"]) - 0.06))


# The hovering swords of one cast never overlap (1 px Ink edge included), for every shape, with or without a lift.
func test_stacked_swords_do_not_overlap() -> void:
	var none := Vector2i(-99, -99)
	var shapes: Dictionary = {
		"plus5": [[Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)], Vector2i(5, 1)],
		"t4": [[Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)], Vector2i(5, 1)],
		"l4": [[Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(5, 1)], none],
		"col3": [[Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)], none],
		"bar4": [[Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)], none]}
	for name: String in shapes:
		for enemy: Array in [[], [Vector2i(5, 1)]]:
			var recs: Array[Dictionary] = SkyDropFx.records_from_cast(_cast(shapes[name][0], shapes[name][1]), 0.0, enemy)
			var now: float = 0.39  # every sword assembled and hovering (the first fall starts at 0.4)
			var hits: Array[String] = []
			for i: int in recs.size():
				for j: int in range(i + 1, recs.size()):
					if _parts_overlap(_sword_at(recs[i], now), _sword_at(recs[j], now)):
						hits.append("%s/%s" % [recs[i]["cell"], recs[j]["cell"]])
			ck("%s (enemy %s): hovering swords do not overlap" % [name, str(enemy)], hits.is_empty(), str(hits))


func _parts_overlap(ra: Array[Dictionary], rb: Array[Dictionary]) -> bool:
	for p: Dictionary in ra:
		for q: Dictionary in rb:
			if (p["rect"] as Rect2i).grow(1).intersects((q["rect"] as Rect2i).grow(1)):
				return true
	return false


func test_hud_safety() -> void:
	var worst: int = 9999
	for final: bool in [false, true]:
		for over: bool in [false, true]:
			var d: Dictionary = {"cell": Vector2i(5, 0), "at": 0.5, "t0": 0.0, "final": final, "seed": 3, "cast_id": 1,
				"dx": 0, "over_enemy": over}
			var t: float = 0.0
			while t < 0.5:
				for it: Dictionary in SkyDropFx.items(d, t, Vector2i(400, GROUND_TOP)):
					worst = mini(worst, (it["rect"] as Rect2i).position.y - int(it.get("edge", 1)))
				t += 1.0 / 60.0
	ck("top row: no sword, fragment or trail reaches into the HUD band (SAFE_TOP_PX minus its Ink edge)",
		worst >= SkyDropFx.SAFE_TOP_PX - 2, "highest y %d" % worst)
	var low: Dictionary = {"cell": Vector2i.ZERO, "at": 0.5, "t0": 0.0, "final": true, "over_enemy": true}
	ck("a board drawn too high still keeps a minimum hover", SkyDropFx.hover_px(low, 30) == SkyDropFx.MIN_HOVER_TIP_PX)


func test_enemy_stays_visible() -> void:
	var d: Dictionary = {"cell": Vector2i(5, 1), "at": 0.5, "t0": 0.0, "final": true, "seed": 3, "cast_id": 1, "dx": 0,
		"over_enemy": true}
	var ground: int = GROUND_TOP + 43
	var gap: int = ground - SkyDropFx.tip_y(d, 0.3, ground)
	ck("the finale over the enemy hovers above a Goblin-sized head (46 px)", gap > 46, "%d" % gap)
	ck("see-through while it hovers over the enemy, solid once it falls", SkyDropFx.blade_alpha(d, 0.3) < 1.0
		and SkyDropFx.blade_alpha(d, 0.47) == 1.0)
	var e: Dictionary = d.duplicate()
	e["over_enemy"] = false
	ck("solid over an empty cell, see-through if the enemy steps under it", SkyDropFx.blade_alpha(e, 0.3) == 1.0
		and SkyDropFx.blade_alpha(e, 0.3, true) < 1.0)


func test_finale_emphasis() -> void:
	var n: Dictionary = _d(0.62)
	var f: Dictionary = _d(0.62, true)
	ck("the finale falls faster (same contact time)", SkyDropFx.fall_sec(f) < SkyDropFx.fall_sec(n)
		and SkyDropFx.tip_y(f, 0.62, 100) == SkyDropFx.tip_y(n, 0.62, 100))
	var count := func(d: Dictionary, t: float) -> int: return SkyDropFx.items(d, t, Vector2i(50, 100)).size()
	ck("more fragments assembling and at contact", count.call(f, 0.05) > count.call(n, 0.05) and count.call(f, 0.63) > count.call(n, 0.63))
	var flash: Array[Dictionary] = SkyDropFx.items(f, 0.19, Vector2i(50, 100))
	ck("a white forge flash on its last assembly frames", not flash.is_empty() and flash.all(
		func(it: Dictionary) -> bool: return int(it["tone"]) == SkyDropFx.TONE_CORE))
	ck("a 2 px Ink edge on the finale only",
		SkyDropFx.items(f, 0.4, Vector2i(50, 100)).all(func(it: Dictionary) -> bool: return int(it.get("edge", 1)) == 2)
		and SkyDropFx.items(n, 0.4, Vector2i(50, 100)).all(func(it: Dictionary) -> bool: return int(it.get("edge", 1)) == 1))


func test_board_shake_visual_only() -> void:
	var drops: Array = [_d(0.5), _d(0.62, true)]
	ck("no shake for a normal drop or before the finale contact", SkyDropFx.board_shake(drops, 0.55) == Vector2i.ZERO
		and SkyDropFx.board_shake(drops, 0.61) == Vector2i.ZERO)
	ck("a subtle shake (2 px) at the finale contact", absi(SkyDropFx.board_shake(drops, 0.62).x) == SkyDropFx.SHAKE_PX
		and SkyDropFx.SHAKE_PX <= 2)
	ck("it stops after SHAKE_SEC", SkyDropFx.board_shake(drops, 0.62 + SkyDropFx.SHAKE_SEC + 0.001) == Vector2i.ZERO)
	ck("never under reduce motion", SkyDropFx.board_shake(drops, 0.62, true) == Vector2i.ZERO)
	var r: Dictionary = _real_cast()
	var arb: SwingArbiter = r["arb"]
	var c0: float = arb.clock()
	var recs: Array[Dictionary] = SkyDropFx.records_from_cast(r["cast"], float(r["t0"]))
	for i: int in 20:
		SkyDropFx.board_shake(recs, c0 + 0.1 * float(i))
	ck("the shake never touches the combat clock", is_equal_approx(arb.clock(), c0))


func test_deterministic_rendering() -> void:
	var cells: Array = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]
	var a: Array[Dictionary] = SkyDropFx.records_from_cast(_cast(cells, Vector2i(5, 1)), 0.0, [Vector2i(5, 1)])
	var b: Array[Dictionary] = SkyDropFx.records_from_cast(_cast(cells, Vector2i(5, 1)), 0.0, [Vector2i(5, 1)])
	var same: bool = a == b
	for t: float in [0.1, 0.3, 0.45, 0.6, 0.9]:
		for i: int in a.size():
			same = same and SkyDropFx.items(a[i], t, _base(a[i]["cell"])) == SkyDropFx.items(b[i], t, _base(b[i]["cell"]))
	ck("same cast, same frames: identical records and items", same)


# --- On-tile summon (2026-11-08): swords form on the target tiles during the raise, lock on at the command ----------

func test_on_tile_summon() -> void:
	var cells: Array = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]
	var cast: Dictionary = _cast(cells, Vector2i(5, 1))
	for e: Dictionary in cast["events"]:
		e["at"] = float(e["at"]) + 1.45  # the real plus5 timing: swing end 1.45, first drop at 1.95
	var recs: Array[Dictionary] = SkyDropFx.records_from_cast(cast, 1.45, [])
	var cmd: float = SkyDropFx.summon_command_at(recs)
	ck("command comes COMMAND_LEAD_SEC before the first sword starts to fall",
		is_equal_approx(cmd, 1.95 - SkyDropFx.FALL_SEC - SkyDropFx.COMMAND_LEAD_SEC), "%.3f" % cmd)
	var s: Array[Dictionary] = SkyDropFx.summon_records(recs, 0.17, cmd)
	var same_schedule: bool = s.size() == recs.size()
	for i: int in s.size():
		same_schedule = same_schedule and s[i]["cell"] == recs[i]["cell"] and is_equal_approx(float(s[i]["at"]), float(recs[i]["at"])) \
			and s[i]["final"] == recs[i]["final"]
	ck("re-timing keeps every cell, `at` and finale (gameplay schedule untouched)", same_schedule)
	ck("swords assemble in schedule order from the raise", is_equal_approx(float(s[0]["t0"]), 0.17)
		and is_equal_approx(float(s[4]["t0"]), 0.17 + 4.0 * SkyDropFx.SUMMON_STAGGER_SEC))
	ck("a sword over its tile is assembling, then hovering, before the command", SkyDropFx.phase(s[0], 0.3) == "materialize"
		and SkyDropFx.phase(s[0], 0.17 + SkyDropFx.SUMMON_ASSEMBLY_SEC + 0.01) == "hover")
	ck("nothing before the raise", SkyDropFx.items(s[0], 0.1, Vector2i(100, 150)).is_empty())
	var g: int = 150
	ck("lock-on: a small cock-up after the command, none before",
		SkyDropFx.tip_y(s[0], cmd - 0.01, g) - SkyDropFx.tip_y(s[0], cmd + SkyDropFx.COCK_SEC, g) == SkyDropFx.COCK_PX)
	ck("lock-on flash only right after the command", not SkyDropFx.locked_flash(s[0], cmd - 0.01)
		and SkyDropFx.locked_flash(s[0], cmd + 0.02) and not SkyDropFx.locked_flash(s[0], cmd + SkyDropFx.LOCK_FLASH_SEC + 0.01))
	var at0: float = float(s[0]["at"])
	ck("each tip still reaches its tile exactly at its authoritative `at`", SkyDropFx.tip_y(s[0], at0, g) == g + SkyDropFx.SINK_PX
		and SkyDropFx.tip_y(s[0], at0 - 0.0001, g) <= g and SkyDropFx.tip_y(s[4], float(s[4]["at"]), g) == g + SkyDropFx.SINK_PX)
	ck("the first sword starts to fall just after the command", at0 - SkyDropFx.fall_sec(s[0]) - cmd > 0.0
		and at0 - SkyDropFx.fall_sec(s[0]) - cmd <= SkyDropFx.COMMAND_LEAD_SEC + 0.0001)

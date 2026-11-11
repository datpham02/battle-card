extends SceneTree
## Skill v2 batch 2, Thiên Thạch (thien_thach) in the REAL player flow of a CombatView: a t4 placed with the boss
## inside, the card chosen; the shockwave is scheduled hub first (0.6 s) then ring by ring, the boss is hit once with
## its cell's multiplier (x1.5 on the hub, x1 on a ring), every cell burns afterwards (ignite payload). Time is
## stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/thien_thach_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "thien_thach"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_shockwave()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _match() -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = {"boss_max_hp": BIG_HP}
	v.drops_seed = 7
	v.freeze_time = true
	holder.add_child(v)
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	var pad := DPadView.new()
	pad.name = "DPadView"
	holder.add_child(pad)
	root.add_child(holder)
	await process_frame
	v.set_process(false)
	v.get_boss().set_active(false)
	if v.get_pattern_controller() != null:
		v.get_pattern_controller().set_process(false)
	v._featured = {}
	var drops: FieldDrops = v.get_drops()
	for cell: Vector2i in v.get_grid().player_cells():
		drops.pick_up_at(cell, true)
	drops.set_blocked_cells(v.get_grid().player_cells())
	v.get_state().set_enemy_cell(Vector2i(v.get_grid().side_cols + 1, 1))
	return holder


func _fill(v: CombatView) -> void:
	var hold: HoldSlots = v.get_hold()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	var shapes: Array[String] = ["t4", "bar2", "mono"]
	for i: int in shapes.size():
		var p := FieldPoint.new()
		p.uid = -300 - i
		p.freshness_left = 0.0
		p.piece = _lib.make_piece(shapes[i], 0)
		p.label = shapes[i]
		hold.place(p, i)
	v._deck = Deck.from_array([ID, ID, ID, ID] as Array[String], 1)


func _run(v: CombatView, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		v._process(STEP)
		t += STEP


func test_shockwave() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	var boss: Vector2i = v.get_state().enemy_cell  # (c + 1, 1): the stem of a t4 at (c, 0)
	var hp0: float = v.get_state().enemy_hp
	var log: Array = []
	v.get_arbiter().impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "kind": ev["kind"], "mult": float(ev["mult"]), "at": v.get_arbiter().clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	var scheduled: Array = []
	v.get_arbiter().cast_scheduled.connect(func(_side: int, cast: Dictionary) -> void: scheduled.append(cast))
	v.freeze_time = true
	_check("place the t4 at (c, 0)", v.select_piece(0, false) and v.aim_at_cell(Vector2i(c, 0)) and v.confirm_placement())
	var flow: CutFlow = v.get_cut_flow()
	_check("Tung phép opens the menu with Thiên Thạch", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	_check("choose Thiên Thạch", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	var events: Array = scheduled[0]["events"] if scheduled.size() == 1 else []
	var t0: float = v.get_arbiter().clock()
	_check("4 drops scheduled, the hub first at +0.6 s, the last ring later", events.size() == 4 and events[0]["kind"] == "hub"
		and absf(float(events[0]["at"]) - t0 - 0.6) < 0.001 and float(events[3]["at"]) > float(events[0]["at"]), str(scheduled))
	var boss_mult: float = 0.0
	for e: Dictionary in events:
		if (e["cells"] as Array)[0] == boss:
			boss_mult = float(e["mult"])
	_run(v, 1.0)
	var hits: int = 0
	var hit_dmg: float = 0.0
	for e: Dictionary in log:
		if bool(e["hit"]):
			hits += 1
			hit_dmg = float(e["dmg"])
	var want: float = 7.0 * 4.0 * boss_mult
	_check("one hit on the boss's cell: 7 x 4 x %.1f = %.1f (or more with a passive)" % [boss_mult, want], hits == 1 and (is_equal_approx(hit_dmg, want) or hit_dmg > want),
		"%.2f %s" % [hit_dmg, str(log)])
	_check("every cell burns after the shockwave (ignite payload, hit or miss)", v.get_status().burning_cells().size() == 4, str(v.get_status().burning_cells()))
	_check("HP lost >= the hit (the burn ticks add to it)", hp0 - v.get_state().enemy_hp >= want - 0.001)
	root.remove_child(holder)
	holder.free()

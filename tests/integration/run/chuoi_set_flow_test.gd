extends SceneTree
## Skill v2 batch 1, Chuỗi Sét (chuoi_set) in the REAL player flow of a CombatView: bar4 placed from the bag, the card
## chosen in the menu, the links scheduled on the authoritative clock one after another (0.1 s apart), the boss hit
## ONCE at the link that finds it with that link's ramp (+15 % per link after the first), and the card unavailable
## below 4 cells. Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/chuoi_set_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "chuoi_set"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_chain_ramp_hit()
	await test_need_cells()
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


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


# Bag: t4, bar2, mono; deck: four Chuỗi Sét. (The enemy half is 3 cells wide: a bar4 would not fit.)
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


func _place(v: CombatView, slot: int, target: Vector2i) -> CutFlow:
	v.freeze_time = true
	_check("place the Block from slot %d at %s" % [slot, str(target)], v.select_piece(slot, false) and v.aim_at_cell(target)
		and v.confirm_placement())
	var flow: CutFlow = v.get_cut_flow()
	_check("Tung phép opens the menu with Chuỗi Sét", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	return flow


func test_chain_ramp_hit() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	var boss: Vector2i = v.get_state().enemy_cell  # (c + 1, 1): the stem of a t4 anchored at (c, 0)
	var hp0: float = v.get_state().enemy_hp
	var log: Array = []
	v.get_arbiter().impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "mult": float(ev["mult"]), "at": v.get_arbiter().clock(), "hit": hit}))
	var scheduled: Array = []
	v.get_arbiter().cast_scheduled.connect(func(_side: int, cast: Dictionary) -> void: scheduled.append(cast))
	var flow: CutFlow = _place(v, 0, Vector2i(c, 0))
	_check("choose Chuỗi Sét", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	var events: Array = scheduled[0]["events"] if scheduled.size() == 1 else []
	_check("4 links scheduled at the swing end, 0.1 s apart", events.size() == 4
		and absf(float(events[3]["at"]) - float(events[0]["at"]) - 0.3) < 0.001, str(scheduled))
	# the link the boss stands on, in the scheduled chain order, sets the expected ramp
	var boss_link: int = -1
	for i: int in events.size():
		if (events[i]["cells"] as Array)[0] == boss:
			boss_link = i
	var want_mult: float = 1.0 + minf(0.15 * float(boss_link), 0.6)
	_check("the boss stands on a later link (ramp > x1)", boss_link >= 1, str(boss_link))
	_run(v, 0.5)
	var hits: int = 0
	var hit_mult: float = 0.0
	for e: Dictionary in log:
		if bool(e["hit"]):
			hits += 1
			hit_mult = float(e["mult"])
	_check("every link fired, in the scheduled chain order", log.size() == 4 and log[0]["cell"] == (events[0]["cells"] as Array)[0]
		and log[3]["cell"] == (events[3]["cells"] as Array)[0], str(log))
	_check("one hit, at the boss's link, x%.2f" % want_mult, hits == 1 and is_equal_approx(hit_mult, want_mult), str(log))
	var lost: float = hp0 - v.get_state().enemy_hp
	var want: float = 5.0 * 4.0 * want_mult
	_check("damage 5 x 4 x %.2f = %.1f (or more with a passive)" % [want_mult, want], is_equal_approx(lost, want) or lost > want, "%.2f" % lost)
	_check("the boss did not move", v.get_state().enemy_cell == boss)
	_drop(holder)


func test_need_cells() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var flow: CutFlow = _place(v, 1, v.get_state().enemy_cell)
	var check: Dictionary = SkillAvailability.check(v.get_skill_config(), v.get_skill_cooldowns(), ID, 2, 1, v.get_availability_context())
	_check("bar2 (2 cells): Chuỗi Sét needs 4, reason need_cells", not bool(check["available"]) and check["reason"] == "need_cells", str(check))
	_check("choosing it is refused", not flow.choose(ID) and flow.is_menu_open())
	_check("cancelling returns the Block", v.cancel_placement())
	_drop(holder)

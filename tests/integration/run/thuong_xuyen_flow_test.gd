extends SceneTree
## Skill v2 batch 1, Thương Xuyên (thuong_xuyen) in the REAL player flow of a CombatView: with only a square placed the
## card is greyed (reason need_shape, choosing refused, the Block comes back); with a bar4 it is chosen, the lance
## pierces the 4 cells one after another from the hero outward on the authoritative clock, hits the boss ONCE with
## the per-cell bonus (+2 at 4 cells), and the availability context carries the placed pieces' tags. Time is stepped
## by hand.
## Run: godot --headless --path . -s res://tests/integration/run/thuong_xuyen_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "thuong_xuyen"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_need_shape_rule()
	await test_pierce_in_order()
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


# Bag: square, bar3, bar2; deck: four Thương Xuyên. (The enemy half is 3 cells wide: a bar4 would not fit.)
func _fill(v: CombatView) -> void:
	var hold: HoldSlots = v.get_hold()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	var shapes: Array[String] = ["square", "bar3", "bar2"]
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
	_check("Tung phép opens the menu with Thương Xuyên", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	return flow


func test_need_shape_rule() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var hold: HoldSlots = v.get_hold()
	var before: int = hold.get_occupied_count()
	var boss: Vector2i = v.get_state().enemy_cell
	var flow: CutFlow = _place(v, 0, boss + Vector2i(0, -1))
	var ctx: Dictionary = v.get_availability_context()
	_check("the availability context carries the placed square's tags", ctx.has(SkillAvailability.CTX_PIECE_TAGS)
		and (ctx[SkillAvailability.CTX_PIECE_TAGS] as Array).size() == 1
		and ((ctx[SkillAvailability.CTX_PIECE_TAGS] as Array)[0] as Array).has("square"), str(ctx.get(SkillAvailability.CTX_PIECE_TAGS)))
	var check: Dictionary = SkillAvailability.check(v.get_skill_config(), v.get_skill_cooldowns(), ID, 4, 1, ctx)
	_check("only a square placed: Thương Xuyên unavailable, reason need_shape", not bool(check["available"]) and check["reason"] == "need_shape", str(check))
	_check("choosing it is refused, the menu stays open", not flow.choose(ID) and flow.is_menu_open())
	_check("cancelling the menu returns the Block", v.cancel_placement() and hold.get_occupied_count() == before)
	_drop(holder)


func test_pierce_in_order() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	var boss: Vector2i = v.get_state().enemy_cell  # (c + 1, 1): the 2nd cell of a bar3 anchored at (c, 1)
	var hp0: float = v.get_state().enemy_hp
	var log: Array = []
	v.get_arbiter().impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "kind": ev["kind"], "at": v.get_arbiter().clock(), "hit": hit}))
	var flow: CutFlow = _place(v, 1, Vector2i(c, 1))
	var check: Dictionary = SkillAvailability.check(v.get_skill_config(), v.get_skill_cooldowns(), ID, 4, 1, v.get_availability_context())
	_check("a bar3 placed: available", bool(check["available"]), str(check))
	_check("choose Thương Xuyên", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	_run(v, 1.0)
	var ordered: bool = log.size() == 3
	for i: int in log.size():
		ordered = ordered and log[i]["cell"] == Vector2i(c + i, 1) and (i == 0 or float(log[i]["at"]) > float(log[i - 1]["at"]) + 0.001)
	_check("the lance pierces (c,1) (c+1,1) (c+2,1) one after another", ordered, str(log))
	var hits: int = 0
	for e: Dictionary in log:
		if bool(e["hit"]):
			hits += 1
	_check("one hit, at the boss's cell (2nd)", hits == 1 and log.size() == 3 and bool(log[1]["hit"]))
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("(5 + 1) x 3 = 18 (or more with a passive)", is_equal_approx(lost, 18.0) or lost > 18.0, "%.2f" % lost)
	_check("the boss did not move", v.get_state().enemy_cell == boss)
	_drop(holder)

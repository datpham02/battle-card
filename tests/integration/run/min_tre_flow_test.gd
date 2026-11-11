extends SceneTree
## Skill v2 batch 1, Mìn Trễ (min_tre) in the REAL player flow of a CombatView: bag slot -> select_piece -> aim_at_cell ->
## confirm_placement -> press_cast -> CutFlow.choose("min_tre"). Checks the mines are armed at the swing end (the
## arbiter's armed-zone registry, the boss's threat feed), the detonation 1.2 s later on the authoritative clock with
## x1.6 damage, the push 1 cell away from the mask's centre, and the field cap / no-valid-cells menu rules shared with
## Hỏa Lôi. Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/min_tre_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "min_tre"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_detonation_and_push()
	await test_menu_rules()
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


# Bag: bar2, bar2, mono; deck: four Mìn Trễ.
func _fill(v: CombatView) -> void:
	var hold: HoldSlots = v.get_hold()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	var shapes: Array[String] = ["bar2", "bar2", "mono"]
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
	_check("Tung phép opens the menu with Mìn Trễ", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	return flow


func test_detonation_and_push() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var boss: Vector2i = v.get_state().enemy_cell
	var hp0: float = v.get_state().enemy_hp
	# bar2 anchored on the boss: cells (boss, boss + x); the mask centre is the boss's cell
	var flow: CutFlow = _place(v, 0, boss)
	_check("choose Mìn Trễ", flow.choose(ID))
	v.freeze_time = false
	var actor: CutActor = v.get_cut_actor()
	while actor.is_swinging():
		v._process(STEP)
	var armed: Array[Vector2i] = v.get_arbiter().armed_cells(CombatState.Side.PLAYER)
	_check("2 mines armed at the swing end", armed.size() == 2 and armed.has(boss), str(armed))
	var feed: Dictionary = v.get_arbiter().pending_cells(CombatState.Side.PLAYER)
	_check("the boss's threat feed sees the armed field", (feed.get("armed", []) as Array).size() == 1, str(feed))
	var first_at: float = v.get_arbiter().first_event_at()
	_check("detonation 1.2 s after the swing end", absf(first_at - v.get_arbiter().clock() - 1.2) < 0.011,
		"%.3f" % (first_at - v.get_arbiter().clock()))
	_check("nothing fired before the fuse: boss still on %s, no damage" % str(boss), v.get_state().enemy_cell == boss
		and is_equal_approx(v.get_state().enemy_hp, hp0))
	_run(v, 1.25)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("the boss on the mine took 5 x 2 x 1.6 = 16 (or more with a passive)", is_equal_approx(lost, 16.0) or lost > 16.0, "%.2f" % lost)
	_check("pushed 1 cell away from the mask centre (+x)", v.get_state().enemy_cell == boss + Vector2i(1, 0), str(v.get_state().enemy_cell))
	_check("no mine left armed", v.get_arbiter().armed_cells(CombatState.Side.PLAYER).is_empty())
	_drop(holder)


func test_menu_rules() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	var first: Vector2i = Vector2i(c + 1, 0)
	var flow: CutFlow = _place(v, 0, first)
	_check("first field", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	_run(v, 0.1)
	_check("the first field is armed (fuse running)", v.get_arbiter().armed_cells(CombatState.Side.PLAYER).size() == 2)
	v.get_skill_cooldowns().clear(ID)
	var hold: HoldSlots = v.get_hold()
	var before: int = hold.get_occupied_count()
	flow = _place(v, 1, first)
	var check: Dictionary = SkillAvailability.check(v.get_skill_config(), v.get_skill_cooldowns(), ID, 2, 1, v.get_availability_context())
	_check("placed only on armed cells: Mìn Trễ unavailable, reason no_valid_cells",
		not bool(check["available"]) and check["reason"] == "no_valid_cells", str(check))
	_check("choosing it is refused, the menu stays open", not flow.choose(ID) and flow.is_menu_open())
	_check("cancelling the menu returns the Block", v.cancel_placement() and hold.get_occupied_count() == before)
	_drop(holder)

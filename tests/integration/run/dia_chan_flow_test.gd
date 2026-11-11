extends SceneTree
## Skill v2 batch 2, Địa Chấn (dia_chan) in the REAL player flow of a CombatView: a bar3 placed from the bag across the
## 3-wide enemy half, the card chosen, the ground run scheduled cell by cell from the hero's side, the boss hit once,
## pushed by the line clause (2) but stopped by the half's edge after one cell -> R3 Va Đập (8 more damage, Pinned),
## reported on the card-level result. Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/dia_chan_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "dia_chan"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_push_and_slam()
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
	var shapes: Array[String] = ["bar3", "l3", "mono"]
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


func test_push_and_slam() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	var boss: Vector2i = v.get_state().enemy_cell  # (c + 1, 1): the middle of a bar3 at (c, 1)
	var hp0: float = v.get_state().enemy_hp
	var results: Array = []
	v.get_arbiter().swing_resolved.connect(func(_side: int, r: Dictionary) -> void: results.append(r))
	var scheduled: Array = []
	v.get_arbiter().cast_scheduled.connect(func(_side: int, cast: Dictionary) -> void: scheduled.append(cast))
	v.freeze_time = true
	_check("place the bar3 at (c, 1)", v.select_piece(0, false) and v.aim_at_cell(Vector2i(c, 1)) and v.confirm_placement())
	var flow: CutFlow = v.get_cut_flow()
	_check("Tung phép opens the menu with Địa Chấn", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	_check("choose Địa Chấn", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	var events: Array = scheduled[0]["events"] if scheduled.size() == 1 else []
	_check("3 cells scheduled from the hero's side outward, one wave", events.size() == 3 and (events[0]["cells"] as Array)[0] == Vector2i(c, 1)
		and (events[2]["cells"] as Array)[0] == Vector2i(c + 2, 1) and int(events[2]["wave"]) == 0, str(scheduled))
	_run(v, 1.5)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("the boss was pushed to the edge (c + 2, 1): line push 2 stopped after 1", v.get_state().enemy_cell == Vector2i(c + 2, 1),
		str(v.get_state().enemy_cell))
	_check("hit 5 x 3 = 15 plus the R3 slam 8 = 23 (or more with a passive)", is_equal_approx(lost, 23.0) or lost > 23.0, "%.2f" % lost)
	_check("the card-level result reports reaction r3 and the Pin", results.size() == 1 and results[0].get("reaction", "") == "r3"
		and bool(results[0].get("pinned", false)), str(results))
	root.remove_child(holder)
	holder.free()

extends SceneTree
## Skill v2 batch 2, Lốc Cuốn (loc_cuon) in the REAL player flow of a CombatView: a square placed with the boss inside
## it, the card chosen, the boss pulled 2 cells to the mask's centre (square clause) before the hit, hit once (16) and
## Pinned 0.4 s; then a t4 with the boss adjacent to it pulls 1 and hits. Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/loc_cuon_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "loc_cuon"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_square_pull_two_and_pin()
	await test_adjacent_pull_one()
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
	var shapes: Array[String] = ["square", "t4", "mono"]
	for i: int in shapes.size():
		var p := FieldPoint.new()
		p.uid = -300 - i
		p.freshness_left = 0.0
		p.piece = _lib.make_piece(shapes[i], 0)
		p.label = shapes[i]
		hold.place(p, i)
	v._deck = Deck.from_array([ID, ID, ID, ID] as Array[String], 1)


func _cast(v: CombatView, slot: int, anchor: Vector2i) -> void:
	v.freeze_time = true
	_check("place the Block from slot %d at %s" % [slot, str(anchor)], v.select_piece(slot, false) and v.aim_at_cell(anchor) and v.confirm_placement())
	var flow: CutFlow = v.get_cut_flow()
	_check("Tung phép opens the menu with Lốc Cuốn", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	_check("choose Lốc Cuốn", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	v._process(STEP)


func test_square_pull_two_and_pin() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	# (c + 1, 1) is the far-low cell of a square at (c, 0); the square's centre (ShapeTags, ties nearest the hero on
	# row 1) is (c, 1): the pull (2 allowed) stops after one step, on the centre
	var hp0: float = v.get_state().enemy_hp
	_cast(v, 0, Vector2i(c, 0))
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("the boss was pulled onto the square's centre (c, 1)", v.get_state().enemy_cell == Vector2i(c, 1), str(v.get_state().enemy_cell))
	_check("hit 4 x 4 = 16 (or more with a passive)", is_equal_approx(lost, 16.0) or lost > 16.0, "%.2f" % lost)
	_check("Pinned 0.4 s by the square clause", v.get_status().is_pinned(CombatState.Side.ENEMY)
		and v.get_status().get_pin_left(CombatState.Side.ENEMY) > 0.3, "%.2f" % v.get_status().get_pin_left(CombatState.Side.ENEMY))
	root.remove_child(holder)
	holder.free()


func test_adjacent_pull_one() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	# t4 at (c, 0): (c,0) (c+1,0) (c+2,0) (c+1,1); the boss on (c+1, 2) is adjacent to (c+1, 1), outside the mask
	v.get_state().set_enemy_cell(Vector2i(c + 1, 2))
	var hp0: float = v.get_state().enemy_hp
	_cast(v, 1, Vector2i(c, 0))
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("adjacent boss pulled 1 onto (c+1, 1) and hit 16 (or more with a passive)", v.get_state().enemy_cell == Vector2i(c + 1, 1)
		and (is_equal_approx(lost, 16.0) or lost > 16.0), "%s %.2f" % [str(v.get_state().enemy_cell), lost])
	_check("no square clause: not Pinned", not v.get_status().is_pinned(CombatState.Side.ENEMY))
	root.remove_child(holder)
	holder.free()

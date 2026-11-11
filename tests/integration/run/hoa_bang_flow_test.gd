extends SceneTree
## Skill v2 batch 2, Hỏa Băng (hoa_bang) in the REAL player flow of a CombatView: a t4 placed with the boss inside, the
## card chosen; the hit (3 x 4) gives 1 Hàn, the event payload lights the 4 cells, and R1 Hơi Nước bursts 12 on the
## boss, puts its cell out and spends the Hàn (reported on the card-level result). Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/hoa_bang_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "hoa_bang"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_steam()
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


func test_steam() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	var boss: Vector2i = v.get_state().enemy_cell  # (c + 1, 1): the stem of a t4 at (c, 0)
	var results: Array = []
	v.get_arbiter().swing_resolved.connect(func(_side: int, r: Dictionary) -> void: results.append(r))
	var hp0: float = v.get_state().enemy_hp
	v.freeze_time = true
	_check("place the t4 at (c, 0)", v.select_piece(0, false) and v.aim_at_cell(Vector2i(c, 0)) and v.confirm_placement())
	var flow: CutFlow = v.get_cut_flow()
	_check("Tung phép opens the menu with Hỏa Băng", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	_check("choose Hỏa Băng", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	v._process(STEP)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("hit 3 x 4 = 12 plus the R1 burst 12 = 24 (or more with a passive)", is_equal_approx(lost, 24.0) or lost > 24.0, "%.2f" % lost)
	_check("the Hàn was spent, the boss's cell put out, the other 3 cells burn", v.get_status().frost_stacks(CombatState.Side.ENEMY) == 0
		and not v.get_status().is_burning(boss) and v.get_status().burning_cells().size() == 3, str(v.get_status().burning_cells()))
	_check("the card-level result reports reaction r1", results.size() == 1 and results[0].get("reaction", "") == "r1", str(results))
	root.remove_child(holder)
	holder.free()

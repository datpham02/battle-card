extends SceneTree
## Skill v2 batch 1, Đập Vỡ (dap_vo) in the REAL player flow of a CombatView: the boss given Guard (StatusEffects.guard,
## the pattern status), a bar2 placed on it, the card chosen; the sky drops land, the Guard is stripped BEFORE the
## damage and the hit deals x1.5 with no Guard taken off it; a second cast on an unguarded boss deals the plain
## damage; a square (compact) adds 1 Rạn. Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/dap_vo_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "dap_vo"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_guard_break()
	await test_compact_fragile()
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


# Bag: bar2, square, bar2; deck: four Đập Vỡ.
func _fill(v: CombatView) -> void:
	var hold: HoldSlots = v.get_hold()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	var shapes: Array[String] = ["bar2", "square", "bar2"]
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
	_check("Tung phép opens the menu with Đập Vỡ", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	return flow


func _cast_and_settle(v: CombatView, slot: int, target: Vector2i) -> void:
	var flow: CutFlow = _place(v, slot, target)
	_check("choose Đập Vỡ", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	_run(v, 0.5)


func test_guard_break() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var boss: Vector2i = v.get_state().enemy_cell
	v.get_status().guard(CombatState.Side.ENEMY, 6.0, 30.0)
	_check("the boss has Guard 6", is_equal_approx(v.get_status().guard_amount(CombatState.Side.ENEMY), 6.0))
	var hp0: float = v.get_state().enemy_hp
	_cast_and_settle(v, 0, boss)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("Guard stripped by the hit", is_zero_approx(v.get_status().guard_amount(CombatState.Side.ENEMY)))
	_check("6 x 2 x 1.5 = 18 with no Guard taken off (or more with a passive)", is_equal_approx(lost, 18.0) or lost > 18.0, "%.2f" % lost)
	# second cast, no Guard left: the plain 12
	v.get_skill_cooldowns().clear(ID)
	var hp1: float = v.get_state().enemy_hp
	_cast_and_settle(v, 2, boss)
	var lost2: float = hp1 - v.get_state().enemy_hp
	_check("unguarded: plain 6 x 2 = 12 (or more with a passive), below the guarded hit", (is_equal_approx(lost2, 12.0) or lost2 > 12.0)
		and lost2 < lost, "%.2f" % lost2)
	_drop(holder)


func test_compact_fragile() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var boss: Vector2i = v.get_state().enemy_cell
	var before: int = v.get_status().fragile_stacks(CombatState.Side.ENEMY)
	# square anchored one row up so the boss stands inside it
	_cast_and_settle(v, 1, boss + Vector2i(0, -1))
	_check("square (compact): +1 Rạn on the boss", v.get_status().fragile_stacks(CombatState.Side.ENEMY) == before + 1,
		str(v.get_status().fragile_stacks(CombatState.Side.ENEMY)))
	_drop(holder)

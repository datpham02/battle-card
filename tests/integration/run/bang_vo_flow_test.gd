extends SceneTree
## Skill v2 batch 2, Băng Vỡ (bang_vo) in the REAL player flow of a CombatView: the boss Pinned, a bar3 placed on it,
## the card chosen; the sky drops land, the card's Rạn lands before its own hit, R2 Vỡ Băng doubles the hit (30) and
## ends the Pin at once; a second cast on an unpinned boss is the plain Rạn hit (22.5). Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/bang_vo_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "bang_vo"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_shatter()
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
	var shapes: Array[String] = ["bar3", "bar3", "mono"]
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
	_check("Tung phép opens the menu with Băng Vỡ", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	_check("choose Băng Vỡ", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	var t: float = 0.0
	while t < 0.5:
		v._process(STEP)
		t += STEP


func test_shatter() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	v.get_status().pin(CombatState.Side.ENEMY, 5.0)
	var results: Array = []
	v.get_arbiter().swing_resolved.connect(func(_side: int, r: Dictionary) -> void: results.append(r))
	var hp0: float = v.get_state().enemy_hp
	_cast(v, 0, Vector2i(c, 1))
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("Pinned boss: Rạn first, then R2 -> 5 x 3 x 2 = 30 (or more with a passive)", is_equal_approx(lost, 30.0) or lost > 30.0, "%.2f" % lost)
	_check("the Pin ended at once, the stack was spent, reaction r2 reported", not v.get_status().is_pinned(CombatState.Side.ENEMY)
		and v.get_status().fragile_stacks(CombatState.Side.ENEMY) == 0 and results.size() == 1 and results[0].get("reaction", "") == "r2", str(results))
	v.get_skill_cooldowns().clear(ID)
	var hp1: float = v.get_state().enemy_hp
	_cast(v, 1, Vector2i(c, 1))
	var lost2: float = hp1 - v.get_state().enemy_hp
	_check("unpinned boss: the plain Rạn hit 5 x 3 x 1.5 = 22.5 (or more with a passive), below the Shatter", (is_equal_approx(lost2, 22.5) or lost2 > 22.5)
		and lost2 < lost and results.size() == 2 and str(results[1].get("reaction", "")).is_empty(), "%.2f" % lost2)
	root.remove_child(holder)
	holder.free()

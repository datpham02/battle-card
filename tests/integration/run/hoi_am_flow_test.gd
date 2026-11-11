extends SceneTree
## Skill v2 batch 2, Hồi Âm (hoi_am) in the REAL player flow of a CombatView: a bar3 placed across the 3-wide enemy
## half with the boss on it, the card chosen; the hit lands now, the echo wave is scheduled 0.6 s later (in place, the
## shift would leave the half) at x0.6 and hits the boss that stayed: two hits, 15 + 9. Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/hoi_am_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "hoi_am"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_echo()
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
	var shapes: Array[String] = ["bar3", "bar2", "mono"]
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


func test_echo() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var c: int = v.get_grid().side_cols
	var hp0: float = v.get_state().enemy_hp
	var log: Array = []
	v.get_arbiter().impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cells": ev["cells"], "kind": ev["kind"], "mult": float(ev["mult"]), "at": v.get_arbiter().clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	v.freeze_time = true
	_check("place the bar3 at (c, 1)", v.select_piece(0, false) and v.aim_at_cell(Vector2i(c, 1)) and v.confirm_placement())
	var flow: CutFlow = v.get_cut_flow()
	_check("Tung phép opens the menu with Hồi Âm", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	_check("choose Hồi Âm", flow.choose(ID))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	v._process(STEP)
	_check("the first wave hit at once", log.size() == 1 and bool(log[0]["hit"]) and log[0]["kind"] == "hit", str(log))
	_check("the echo is still on the clock", v.get_arbiter().scheduled_count() == 1)
	_run(v, 0.7)
	_check("the echo fired 0.6 s later, in place (the shift would leave the half), x0.6, and hit", log.size() == 2 and log[1]["kind"] == "echo"
		and is_equal_approx(float(log[1]["mult"]), 0.6) and bool(log[1]["hit"]) and absf(float(log[1]["at"]) - float(log[0]["at"]) - 0.6) < 0.011
		and (log[1]["cells"] as Array) == (log[0]["cells"] as Array), str(log))
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("15 + 9 = 24 (or more with a passive)", is_equal_approx(lost, 24.0) or lost > 24.0, "%.2f" % lost)
	root.remove_child(holder)
	holder.free()

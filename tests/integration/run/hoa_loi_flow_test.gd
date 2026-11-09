extends SceneTree
## Skill v2 Hỏa Lôi (docs/skill-v2/09-hoa-loi-design.md), the REAL player flow in a CombatView: bag slot ->
## select_piece -> aim_at_cell -> confirm_placement -> press_cast -> CutFlow.choose("hoa_loi"). Checks the cast profile
## "lock" (0.45 s rooted, no Hủy, no commit lock, free right after), the detonation on the authoritative clock with the
## burn left behind, the d-pad lock, the menu's field cap and "no valid cells" (the card cannot be chosen, so no Block or
## cooldown is spent for nothing), and that the boss's threat feed sees the armed field. Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/hoa_loi_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "hoa_loi"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_cast_lock_and_detonation()
	await test_menu_rules()
	await test_visual_sync()
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


# Bag: bar2 in slot 0, bar2 in slot 1, mono; deck: four Hỏa Lôi.
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


# Places slot [param slot]'s bar2 at [param target] and opens the card menu. Returns the CutFlow.
func _place(v: CombatView, slot: int, target: Vector2i) -> CutFlow:
	v.freeze_time = true
	_check("place the Block from slot %d at %s" % [slot, str(target)], v.select_piece(slot, false) and v.aim_at_cell(target)
		and v.confirm_placement())
	var flow: CutFlow = v.get_cut_flow()
	_check("Tung phép opens the menu with Hỏa Lôi", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID))
	return flow


func test_cast_lock_and_detonation() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var pad: DPadView = holder.get_node("DPadView") as DPadView
	_fill(v)
	var boss: Vector2i = v.get_state().enemy_cell
	var hp0: float = v.get_state().enemy_hp
	var flow: CutFlow = _place(v, 0, boss)
	_check("choose Hỏa Lôi", flow.choose(ID))
	v.freeze_time = false
	var actor: CutActor = v.get_cut_actor()
	_check("the cast is 0.45 s", is_equal_approx(actor.get_duration(), 0.45), "%.3f" % actor.get_duration())
	_check("cast lock: hero rooted, d-pad locked, no Hủy, no channel phase", v.is_cast_rooted() and v.is_cast_locked()
		and pad._is_locked() and not v.is_channel_cancel_shown() and v.channel_phase() == CombatView.PHASE_NONE)
	var t0: float = v.get_arbiter().clock()
	while actor.is_swinging():
		v._process(STEP)
	_check("free right after the swing end (no commit lock)", not v.is_cast_rooted() and not pad._is_locked()
		and absf(v.get_arbiter().clock() - t0 - 0.45) < 0.011, "%.3f" % (v.get_arbiter().clock() - t0))
	var armed: Array[Vector2i] = v.get_arbiter().armed_cells(CombatState.Side.PLAYER)
	_check("2 seals armed", armed.size() == 2, str(armed))
	var dir: Vector2i = Vector2i.ZERO
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if v.get_grid().is_player_cell(v.get_state().player_cell + d):
			dir = d
			break
	_check("the hero steps during the fuse", v.try_step_player(dir))
	var feed: Dictionary = v.get_arbiter().pending_cells(CombatState.Side.PLAYER)
	_check("the boss's threat feed sees the armed field", (feed.get("armed", []) as Array).size() == 1, str(feed))
	var first_at: float = v.get_arbiter().first_event_at()
	_check("detonation 1.5 s after the swing end", absf(first_at - v.get_arbiter().clock() - 1.5) < 0.011)
	_run(v, 1.55)
	_check("the boss on the seal took 6 x 2 x 2.0 = 24", is_equal_approx(hp0 - v.get_state().enemy_hp, 24.0)
		or (hp0 - v.get_state().enemy_hp) > 24.0, "%.2f" % (hp0 - v.get_state().enemy_hp))
	_check("the seal cells burn after the blast", v.get_status().burning_cells().size() == 2, str(v.get_status().burning_cells()))
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
	_run(v, 0.5)
	v.get_skill_cooldowns().clear(ID)
	# the same cells again: nothing left to arm -> the card is unavailable (no Block / cooldown spent)
	var hold: HoldSlots = v.get_hold()
	var before: int = hold.get_occupied_count()
	flow = _place(v, 1, first)
	var check: Dictionary = SkillAvailability.check(v.get_skill_config(), v.get_skill_cooldowns(), ID, 2, 1, v.get_availability_context())
	_check("placed only on armed cells (cooldown cleared): Hỏa Lôi unavailable, reason no_valid_cells",
		not bool(check["available"]) and check["reason"] == "no_valid_cells",
		str(check))
	_check("choosing it is refused, the menu stays open", not flow.choose(ID) and flow.is_menu_open())
	_check("cancelling the menu returns the Block", v.cancel_placement() and hold.get_occupied_count() == before)
	_drop(holder)


# H2: the FuseFx records follow the authoritative schedule: one per armed cell, `at` == the arbiter's event time, none
# during the cast, fired on the detonation tick, the Mage free (not held in the cast clip) during the fuse, and an armed
# field cleared by the caster's death shows nothing more.
func test_visual_sync() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v)
	var boss: Vector2i = v.get_state().enemy_cell
	var flow: CutFlow = _place(v, 0, boss)
	_check("choose Hỏa Lôi (sync)", flow.choose(ID))
	v.freeze_time = false
	_check("no fire-seal record during the 0.45 s cast", v.get_fuse_fx().is_empty())
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	var recs: Array[Dictionary] = v.get_fuse_fx()
	var at: float = v.get_arbiter().first_event_at()
	var same: bool = recs.size() == 2
	for r: Dictionary in recs:
		same = same and is_equal_approx(float(r["at"]), at) and v.get_arbiter().armed_cells(CombatState.Side.PLAYER).has(r["cell"])
	_check("one record per armed cell, on the authoritative at", same, "%d recs, at %.3f" % [recs.size(), at])
	_check("the Mage is free during the fuse (no cast lock, not swinging)", not v.is_cast_rooted() and not v.get_cut_actor().is_swinging())
	while v.get_arbiter().clock() < at - STEP * 0.5:
		v._process(STEP)
		if v.get_arbiter().clock() < at - 0.0001:
			_check_once_unfired(v)
	v._process(STEP)
	var fired: bool = not v.get_fuse_fx().is_empty()
	for r: Dictionary in v.get_fuse_fx():
		fired = fired and bool(r["fired"]) and FuseFx.phase(r, v.combat_clock()) == "blast"
	_check("every record blasts on the detonation tick", fired)
	_drop(holder)
	# caster death during the fuse: the field is cleared, nothing shows
	var h2: Node = await _match()
	var v2: CombatView = h2.get_node("CombatView") as CombatView
	_fill(v2)
	var f2: CutFlow = _place(v2, 0, v2.get_state().enemy_cell)
	_check("choose Hỏa Lôi (death)", f2.choose(ID))
	v2.freeze_time = false
	_run(v2, 0.6)
	v2.get_state().damage(CombatState.Side.PLAYER, 1.0e9)
	_run(v2, 0.05)
	_check("caster death: no fire-seal record left", v2.get_fuse_fx().is_empty())
	_drop(h2)


var _unfired_checked: bool = false


func _check_once_unfired(v: CombatView) -> void:
	if _unfired_checked:
		return
	_unfired_checked = true
	var ok: bool = true
	for r: Dictionary in v.get_fuse_fx():
		ok = ok and not bool(r["fired"]) and FuseFx.phase(r, v.combat_clock()) == "sigil"
	_check("before the detonation every record is an armed sigil (no flame)", ok)

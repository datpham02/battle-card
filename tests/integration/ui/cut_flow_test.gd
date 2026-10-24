extends SceneTree
## Scratch: drives the real cut flow with mouse events (local coords).

var fails: int = 0
const VP: Vector2 = Vector2(1280, 720)


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _click(p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		root.push_input(ev, true)
		await process_frame


func _wait_real(sec: float) -> void:
	var end: int = Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _point(label: String) -> FieldPoint:
	var p := FieldPoint.new()
	p.label = label
	return p


func _initialize() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	var game_flow := main.get_node("GameFlow") as GameFlow
	game_flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	var rc: RunController = game_flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	await process_frame
	await process_frame
	for _i: int in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	var combat := battle.get_node("CombatView") as CombatView
	var sv := battle.get_node("HoldSlotsView") as HoldSlotsView
	var hold: HoldSlots = sv.get_slots()
	var state: CombatState = combat.get_state()
	combat.get_boss().set_active(false)
	var actor: CutActor = combat.get_cut_actor()
	var flow: CutFlow = combat.get_cut_flow()
	combat._deck = Deck.from_array(["kiem_khi", "chan_phong", "hoa_tran", "bang_phong"] as Array[String], 1)
	var cds: SkillCooldowns = combat.get_skill_cooldowns()
	var drops: FieldDrops = combat.get_drops()
	var skill_cfg: SkillConfig = combat.get_skill_config()
	var confirm_c: Vector2 = ScreenLayout.confirm_button_rect(VP).get_center()

	hold.place_in_first_free(_point("A1"))
	hold.place_in_first_free(_point("C3"))
	hold.place_in_first_free(_point("D2"))
	state.set_enemy_cell(Vector2i(4, 1))
	_check("confirm hidden with nothing selected", not combat.is_confirm_visible())
	await _click(sv.get_slot_rect(0).get_center())
	await _click(sv.get_slot_rect(1).get_center())
	_check("two tapped points selected in order", hold.get_selected_labels() == ["A1", "C3"], str(hold.get_selected_labels()))
	_check("confirm visible", combat.is_confirm_visible())

	await _click(confirm_c)
	_check("confirm opened the menu (2 points)", flow.is_menu_open())
	_check("points consumed, D2 left", hold.get_occupied_count() == 1 and hold.get_point(2) != null)
	_check("selection cleared", hold.get_selected_indices().is_empty())
	_check("no swing before a skill is chosen", not actor.is_swinging())

	var fp: FieldPoint = drops.debug_place("B2", Vector2i(0, 0), 5.0)
	var t0: int = Time.get_ticks_msec()
	await _wait_real(1.0)
	var real_s: float = float(Time.get_ticks_msec() - t0) / 1000.0
	var lost: float = 5.0 - fp.freshness_left
	_check("menu slows the sim (freshness lost << real time)", lost < real_s * 0.5 and lost > 0.0, "real=%.2f lost=%.2f" % [real_s, lost])

	var order: Array[String] = combat.get_hand()
	_check("hand holds the 4-card deck", order.size() == 4 and combat.get_deck().size() == 4, str(order))
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(VP, order.size())
	var burn_i: int = order.find("bang_phong")
	await _click(rects[burn_i].get_center())
	_check("locked skill click ignored, menu stays", flow.is_menu_open() and not actor.is_swinging())
	var push_i: int = order.find("chan_phong")
	await _click(rects[push_i].get_center())
	_check("push chosen: menu closed, swing running", not flow.is_menu_open() and actor.is_swinging())
	_check("push cooldown started", not cds.is_ready("chan_phong") and cds.remaining("chan_phong") > 5.0, "%.2f" % cds.remaining("chan_phong"))
	_check("swing covers 5 cells", actor.get_cells().size() == 5, str(actor.get_cells().size()))

	hold.place_in_first_free(_point("B1"))
	await _click(sv.get_slot_rect(hold.get_slot_count() - 1 if false else 0).get_center())
	var before: int = hold.get_occupied_count()
	var left: float = actor.get_time_left()
	await _click(confirm_c)
	_check("confirm during swing does nothing", hold.get_occupied_count() == before and not flow.is_menu_open() and actor.is_swinging() and actor.get_time_left() <= left, "occupied=%d" % hold.get_occupied_count())
	hold.clear_selection()

	var guard: int = 0
	while actor.is_swinging() and guard < 900:
		await process_frame
		guard += 1
	_check("swing resolved", not actor.is_swinging())
	_check("push damage 20 (5 cells x 4 dmg/cell, Story 020)", is_equal_approx(state.enemy_hp, state.enemy_max_hp - 20.0), str(state.enemy_hp))
	_check("boss pushed away from divider", state.enemy_cell == Vector2i(5, 1), str(state.enemy_cell))

	# Single point: select + confirm = straight to a slash, no menu.
	hold.clear_selection()
	var slot_a1: int = -1
	for i: int in hold.get_slot_count():
		if hold.get_point(i) != null and hold.get_point(i).label == "B1":
			slot_a1 = i
	await _click(sv.get_slot_rect(slot_a1).get_center())
	_check("one point selected", hold.get_selected_labels() == ["B1"])
	await _click(confirm_c)
	_check("1 point: no menu, swing started", not flow.is_menu_open() and actor.is_swinging())
	guard = 0
	while actor.is_swinging() and guard < 900:
		await process_frame
		guard += 1

	# Menu timeout auto-picks slash.
	for lab: String in ["A2", "C2"]:
		hold.place_in_first_free(_point(lab))
	var idxs: Array[int] = []
	for i: int in hold.get_slot_count():
		var p: FieldPoint = hold.get_point(i)
		if p != null and (p.label == "A2" or p.label == "C2"):
			idxs.append(i)
	for i: int in idxs:
		await _click(sv.get_slot_rect(i).get_center())
	await _click(confirm_c)
	_check("menu open again", flow.is_menu_open())
	await _wait_real(skill_cfg.menu_choose_sec + 0.5)
	_check("timeout auto-chose slash", not flow.is_menu_open() and actor.is_swinging() and actor.get_skill_id() == "kiem_khi", actor.get_skill_id())
	print("FAILS=%d" % fails)
	quit(fails)

extends SceneTree
## Scratch: drives the real main scene with pointer/key events (local coords).

var fails: int = 0


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


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev, true)
	await process_frame


func _wait_ready(mover: UnitMover) -> void:
	var guard: int = 0
	while not mover.is_ready() and guard < 600:
		await process_frame
		guard += 1


func _initialize() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	await process_frame
	await process_frame
	for _i: int in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	var combat := battle.get_node("CombatView") as CombatView
	var slots_view := battle.get_node("HoldSlotsView") as HoldSlotsView
	var state: CombatState = combat.get_state()
	var mover: UnitMover = combat.get_mover()
	var drops: FieldDrops = combat.get_drops()
	var hold: HoldSlots = slots_view.get_slots()
	var vp: Vector2 = Vector2(1280, 720)
	var rects: Dictionary = ScreenLayout.dpad_rects(vp)

	_check("start cell (1,1)", state.player_cell == Vector2i(1, 1), str(state.player_cell))
	await _click(rects[Vector2i.LEFT].get_center())
	_check("LEFT press moves exactly one cell", state.player_cell == Vector2i(0, 1), str(state.player_cell))
	await _click(rects[Vector2i.RIGHT].get_center())
	_check("press during cooldown ignored", state.player_cell == Vector2i(0, 1), str(state.player_cell))
	await _wait_ready(mover)
	_check("queued press did NOT fire after cooldown", state.player_cell == Vector2i(0, 1), str(state.player_cell))
	await _click(rects[Vector2i.RIGHT].get_center())
	_check("RIGHT after cooldown moves one cell", state.player_cell == Vector2i(1, 1), str(state.player_cell))
	await _wait_ready(mover)

	# Flake guard: a random drop may already sit on the target cell; clear it first.
	drops.pick_up_at(Vector2i(1, 0), true)
	drops.debug_place("B2", Vector2i(1, 0), 5.0)
	await _click(rects[Vector2i.UP].get_center())
	_check("stepping on point moved player", state.player_cell == Vector2i(1, 0), str(state.player_cell))
	var picked: FieldPoint = hold.get_point(0)
	_check("point picked into slot 0", picked != null and picked.label == "B2", picked.label if picked != null else "null")
	var still_on_field: bool = false
	for p: FieldPoint in drops.get_points():
		if p.cell == Vector2i(1, 0) and p.label == "B2":
			still_on_field = true
	_check("picked point left the field", not still_on_field)
	await _wait_ready(mover)

	await _click(rects[Vector2i.UP].get_center())
	_check("wall step rejected", state.player_cell == Vector2i(1, 0), str(state.player_cell))
	_check("rejected step starts no cooldown", mover.is_ready())

	var slot_center: Vector2 = slots_view.get_slot_rect(0).get_center()
	await _click(slot_center)
	_check("tap selects occupied slot", hold.is_selected(0))
	await _click(slot_center)
	_check("second tap deselects", not hold.is_selected(0))
	await _click(slots_view.get_slot_rect(3).get_center())
	_check("tap on empty slot does nothing", not hold.is_selected(3))

	await _key(KEY_DOWN)
	_check("DOWN arrow key steps one cell", state.player_cell == Vector2i(1, 1), str(state.player_cell))

	# Full hand: fill remaining slots, stand next to a point, step on it.
	await _wait_ready(mover)
	for i: int in range(hold.get_slot_count() - hold.get_occupied_count()):
		var fp := FieldPoint.new()
		fp.label = "C1"
		hold.place_in_first_free(fp)
	_check("hand is full", hold.is_full())
	drops.debug_place("D2", Vector2i(2, 1), 5.0)
	await _click(rects[Vector2i.RIGHT].get_center())
	var left_on_field: bool = false
	for p: FieldPoint in drops.get_points():
		if p.label == "D2":
			left_on_field = true
	_check("full hand: point stays on field", left_on_field)
	print("FAILS=%d" % fails)
	quit(fails)

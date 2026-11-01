extends SceneTree
## Story 044 Part B: the floating joystick in the real main scene (default control mode).
## Windowed only: --windowed --resolution 1280x720 ... -- --no-autopause.
## Intents: a touch in the stick zone steps once on entering a direction and again each time the
## UnitMover cooldown ends while held; release stops; a second finger outside the zone (the bag
## drag) never steals or ends the stick; a press outside the zone does not start it; placing turns
## the zone into the rotate button (no stick); mouse press / drag / release works the same.

var fails: int = 0
const VP: Vector2 = Vector2(1280, 720)
const ZONE_POINT: Vector2 = Vector2(150, 600)


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _touch(index: int, p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = p
	root.push_input(ev, true)
	await process_frame


func _drag(index: int, p: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = p
	root.push_input(ev, true)
	await process_frame


func _mouse(p: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	root.push_input(ev, true)
	await process_frame


func _mouse_move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(ev, true)
	await process_frame


func _wait_ready(mover: UnitMover) -> void:
	var guard: int = 0
	while not mover.is_ready() and guard < 600:
		await process_frame
		guard += 1


func _initialize() -> void:
	SettingsStore.set_movement_override(SettingsStore.MOVEMENT_JOYSTICK)
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	# The shipped hero, so the window shows the real sprite (not the character-less placeholder).
	flow.set_character("kiem_si")
	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	await process_frame
	await process_frame
	for _i: int in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	var combat := battle.get_node("CombatView") as CombatView
	var dpad := battle.get_node("DPadView") as DPadView
	var state: CombatState = combat.get_state()
	var mover: UnitMover = combat.get_mover()
	var reader: StickReader = dpad.get_stick_reader()
	combat.get_boss().set_active(false)
	var drops: FieldDrops = combat.get_drops()
	for cell: Vector2i in combat.get_grid().player_cells():
		drops.pick_up_at(cell, true)
	drops.set_blocked_cells(combat.get_grid().player_cells())
	_check("joystick mode is active", dpad.is_joystick_mode())
	_check("start cell (1,1)", state.player_cell == Vector2i(1, 1), str(state.player_cell))

	# --- Press outside the zone does not start the stick.
	await _touch(0, Vector2(700, 300), true)
	_check("press outside the zone: no stick", not reader.is_active())
	await _touch(0, Vector2(700, 300), false)

	# The player half is 3 columns wide: start on its left edge so a held RIGHT has two steps to repeat.
	state.player_cell = Vector2i(0, 1)

	# --- Touch in the zone: base at the touch, step on entering, repeat on cooldown end, release stops.
	await _touch(2, ZONE_POINT, true)
	_check("base appears at the touch point", reader.is_active() and reader.get_origin() == ZONE_POINT)
	_check("press alone does not step", state.player_cell == Vector2i(0, 1), str(state.player_cell))
	await _drag(2, ZONE_POINT + Vector2(55, 0))
	_check("entering RIGHT steps one cell at once", state.player_cell == Vector2i(1, 1), str(state.player_cell))
	await _drag(2, ZONE_POINT + Vector2(60, 5))
	_check("sliding inside RIGHT does not step again on cooldown", state.player_cell == Vector2i(1, 1), str(state.player_cell))
	await _wait_ready(mover)
	await process_frame
	await process_frame
	var cell_after_repeat: Vector2i = state.player_cell
	_check("held: steps again when the cooldown ended", cell_after_repeat == Vector2i(2, 1), str(cell_after_repeat))

	# --- Another finger (bag side) neither steals nor ends the stick.
	await _touch(5, Vector2(900, 650), true)
	await _drag(5, Vector2(950, 600))
	await _touch(5, Vector2(950, 600), false)
	_check("other finger's release does not end the stick", reader.is_active())

	await _touch(2, ZONE_POINT + Vector2(60, 5), false)
	_check("release hides the stick", not reader.is_active())
	await _wait_ready(mover)
	await process_frame
	await process_frame
	_check("no step after release", state.player_cell == cell_after_repeat, str(state.player_cell))

	# --- Direction change steps at once when ready.
	await _touch(3, ZONE_POINT, true)
	await _drag(3, ZONE_POINT + Vector2(0, -55))
	var up_cell: Vector2i = state.player_cell
	_check("UP steps one row", up_cell == cell_after_repeat + Vector2i.UP, str(up_cell))
	await _wait_ready(mover)
	await _drag(3, ZONE_POINT + Vector2(-55, 0))
	_check("direction change steps the new way at once", state.player_cell == up_cell + Vector2i.LEFT, str(state.player_cell))
	await _touch(3, ZONE_POINT, false)
	await _wait_ready(mover)

	# --- Mouse works the same (pointer -1).
	var before: Vector2i = state.player_cell
	await _mouse(ZONE_POINT, true)
	_check("mouse press starts the stick", reader.is_active())
	await _mouse_move(ZONE_POINT + Vector2(0, 55))
	_check("mouse drag DOWN steps one row", state.player_cell == before + Vector2i.DOWN, str(state.player_cell))
	await _mouse(ZONE_POINT + Vector2(0, 55), false)
	_check("mouse release hides the stick", not reader.is_active())

	# --- Pausing while held drops the gesture (no ghost finger on resume).
	await _wait_ready(mover)
	await _touch(4, ZONE_POINT, true)
	_check("stick held before the pause", reader.is_active())
	rc.set_paused(true)
	await process_frame
	_check("pause drops the gesture", not reader.is_active())
	rc.set_paused(false)
	await process_frame

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

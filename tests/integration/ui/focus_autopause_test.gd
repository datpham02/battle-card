extends SceneTree
## Production focus-loss auto-pause (GameFlow._notification, src/run/game_flow.gd): losing the window / app focus during
## a battle pauses the run; the test-only opt-out (set_focus_autopause_for_test(false), like the demos' --no-autopause)
## keeps it running; then a pushed tap on a bag slot still starts placing (the focus_flow_test failure mode, now
## reproduced on purpose and shown to be handled). Windowed test (real main scene).
## Run: godot --path . -s res://tests/integration/ui/focus_autopause_test.gd

const RealMouseGuard = preload("res://tests/integration/ui/real_mouse_guard.gd")

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	await test_default_pauses_on_focus_loss()
	await test_opt_out_keeps_running_and_taps_work()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _start(autopause: bool) -> Dictionary:
	SettingsStore.reset_shared()
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	root.add_child(RealMouseGuard.new())
	await process_frame
	# set AFTER GameFlow read its command line: the suite runner passes --no-autopause to every windowed test, which
	# would otherwise turn the production behaviour under test off
	flow.set_focus_autopause_for_test(autopause)
	flow.set_character("kiem_si")
	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	for _i: int in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	return {"main": main, "flow": flow, "rc": rc}


func _stop(w: Dictionary) -> void:
	var main: Node = w["main"]
	root.remove_child(main)
	main.queue_free()
	for ch: Node in root.get_children():
		if ch.get_script() == RealMouseGuard:
			ch.queue_free()
	await process_frame


func test_default_pauses_on_focus_loss() -> void:
	var w: Dictionary = await _start(true)
	var rc: RunController = w["rc"]
	# the real test window may already have lost OS focus (and auto-paused); resume so the check below is controlled
	rc.set_paused(false)
	_check("battle running before the controlled focus loss", not rc.is_paused())
	root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	_check("PRODUCTION: losing focus pauses the battle", rc.is_paused())
	await _stop(w)


func test_opt_out_keeps_running_and_taps_work() -> void:
	var w: Dictionary = await _start(false)
	var rc: RunController = w["rc"]
	root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await process_frame
	_check("TEST OPT-OUT: losing focus does not pause", not rc.is_paused())
	var battle: Node = rc.get_battle()
	var combat := battle.get_node("CombatView") as CombatView
	var sv := battle.get_node("HoldSlotsView") as HoldSlotsView
	var hold: HoldSlots = sv.get_slots()
	var p := FieldPoint.new()
	p.uid = -900
	p.freshness_left = 0.0
	p.piece = PieceLibrary.load_from_file().make_piece("bar2", 0)
	p.label = "bar2"
	for i: int in hold.get_slot_count():
		hold.remove(i)
	hold.place(p, 0)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.device = RealMouseGuard.TEST_DEVICE
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = sv.get_slot_rect(0).get_center()
		ev.global_position = ev.position
		root.push_input(ev, true)
		await process_frame
	await process_frame
	_check("after a focus loss the pushed tap on the bag still places", combat.is_placing())
	await _stop(w)

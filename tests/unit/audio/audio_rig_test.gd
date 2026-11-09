extends SceneTree
## AudioRig wiring (docs/skill-v2/10-audio-system-design.md §2, §9) in the REAL main scene, headless, with memory
## settings and slots (no file is written): GameFlow owns one rig; its director is silent headless; settings changes
## reach the director; a test floor's battle gets a CombatAudioBridge with the arbiter clock; the run pause pauses the
## director; navigation plays UI taps; freeing the scene releases the shared director.
## Run: godot --headless --path . -s res://tests/unit/audio/audio_rig_test.gd

const MAIN_SCENE: String = "res://src/main.tscn"

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	var settings := SettingsStore.memory()
	flow.set_slots_for_test(SaveSlots.memory(), settings)
	root.add_child(main)
	await _frames(3)
	var rig: AudioRig = AudioRig.of(flow)
	ck("GameFlow has one AudioRig", rig != null and flow.get_children().filter(func(n: Node) -> bool: return n is AudioRig).size() == 1)
	var director: AudioDirector = rig.director if rig != null else null
	ck("the rig's director is in the tree and silent headless", director != null and director.is_inside_tree() and director.is_silent()
		and AudioDirector.shared() == director)
	settings.set_reduced_audio(true)
	settings.set_vibration(false)
	ck("settings changes reach the director", director.reduced_audio and not director.vibration_enabled)
	settings.set_reduced_audio(false)
	var before: int = director.play_log.size()
	flow.open_settings()
	await _frames(1)
	ck("navigation plays a UI tap", director.play_log.slice(before).any(func(e: Dictionary) -> bool: return e["id"] == "ui.tap"))
	flow.close_settings()
	var controller: RunController = flow.enter_test_floor(RunConfig.load_from_file())
	for i: int in 600:
		if controller.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	ck("the test floor reaches PLAYING", controller.get_state().get_phase() == RunState.Phase.PLAYING)
	var view: CombatView = controller.get_battle().get_node(RunController.COMBAT_VIEW_NODE) as CombatView if controller.get_battle() != null else null
	ck("a test floor spawned a battle", view != null)
	var bridge: CombatAudioBridge = rig.get_combat_bridge()
	ck("the battle got a CombatAudioBridge under the battle root", bridge != null and bridge.get_parent() == controller.get_battle())
	ck("the director reads that battle's arbiter clock", director.clock_fn.is_valid() and view != null
		and is_equal_approx(float(director.clock_fn.call()), view.get_arbiter().clock()))
	controller.set_paused(true, true)
	ck("the run pause pauses the director", director.is_paused())
	controller.set_paused(false, true)
	ck("unpausing resumes it", not director.is_paused())
	# Movie Maker capture (--write-movie) runs unfocused: focus-out must not mute it (regression 2026-11-09: the
	# Ngàn Kiếm in-game capture was silent). An app pause still backgrounds the director.
	rig.keep_audio_unfocused = true
	rig.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	director.play("combat.hit.player", {})
	ck("while recording a movie, losing focus does not mute the director",
		director.play_log.back()["op"] == "play", str(director.play_log.back()))
	rig.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	director.play("combat.hit.enemy", {})
	ck("an app pause still backgrounds it", director.play_log.back()["op"] == "drop"
		and director.play_log.back()["reason"] == "background", str(director.play_log.back()))
	rig.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	rig.keep_audio_unfocused = false
	rig.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	director.play("combat.hit.enemy", {})
	ck("outside a movie capture, focus-out still backgrounds it", director.play_log.back()["op"] == "drop")
	rig.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	view.get_state().damage(CombatState.Side.PLAYER, 1.0)
	ck("a hit in the live battle reaches the director through the bridge", director.play_log.any(func(e: Dictionary) -> bool:
		return e["op"] == "play" and e["id"] == "combat.hit.player"))
	await _frames(30)
	ck("the battle keeps running with audio attached", not view.get_state().is_player_dead())
	root.remove_child(main)
	main.free()
	await _frames(2)
	ck("freeing the scene releases the shared director", AudioDirector._shared == null)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


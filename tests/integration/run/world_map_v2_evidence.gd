extends SceneTree
## World Map v2 evidence (06 section 5, E1-E7): drives the real game (main.tscn, memory stores, seed 24 / 28) through
## the Hellfire slice and saves 1280x720 frames under production/qa/evidence/world-map-v2/ui/. Not a test (no
## *_test.gd name); fights are won at once by killing the foe.
## Run (WINDOWED, muted): godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://tests/integration/run/world_map_v2_evidence.gd

const OUT: String = "res://production/qa/evidence/world-map-v2/ui"
const MAIN_SCENE: String = "res://src/main.tscn"
const HERO: String = "kiem_si"
const SEED_SLICE: int = 24
const SEED_FORGE: int = 28
const MAX_FRAMES: int = 4000

var _saved: Array[String] = []
## Balance validation 2026-11-12: `--out=res://...` writes the frames elsewhere (earlier evidence is never overwritten).
var _out: String = OUT


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	TranslationServer.set_locale("vi")
	var store: ProgressStore = ProgressStore.memory_store()
	var main: Node = await _new_main(store, SEED_SLICE)
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	flow.start_requested()
	flow.character_chosen(HERO)
	flow.choose_region("ch1")
	await _walk_region(flow)
	# E1: the climb screen at floor 2 with the hellfire island selected (briefing: Heat, shop, warden).
	# The unlock toast of floor 1's achievements opens a frame after WORLD_MAP; let it take the ids, then close it.
	for _i: int in 3:
		await process_frame
	var toast: Node = _find(main, "UnlockToastView")
	if toast != null and toast.has_method("dismiss"):
		toast.call("dismiss")
	await process_frame
	var world_view: Node = _find(main, "WorldMapView")
	if world_view != null:
		world_view.set("_selected", "hellfire")
		world_view.set("_notice_key", "")  # the floor-clear banner closes on the first tap
	await _shot("E1-climb-briefing-hellfire")
	flow.choose_region("hellfire")
	var map_view: Node = _find(main, "ChapterMapView")
	await _shot("E2-region-map-three-lanes-entry")
	await _play(flow, 0)
	if map_view != null:
		map_view.set("_selected", 0)
	await _shot("E2b-fork-peril-lane-preview")
	await _play(flow, _index_of(flow, "L0.1"))
	await _play(flow, _index_of(flow, "L0.2"))
	await _shot("E4a-heat-3-before-the-hub")
	await _play(flow, int(flow.get_available_nodes()[0]["node_index"]))
	if map_view != null:
		map_view.set("_selected", _index_of(flow, "L0.4"))
	await _shot("E3-peril-end-preview-modifiers-objective")
	# E8 (balance validation 2026-11-12): the battle intro of that node shows its active modifier(s) (left block).
	await _play_intro_shot(flow, _index_of(flow, "L0.4"), "E8-battle-intro-active-modifiers")
	await _shot("E4b-approach-prepare-vs-gamble-heat-3")
	await _play(flow, _index_of(flow, "a2"))
	await _shot("E5-warden-preview-heat-4")
	# E7: reload mid-region (go_back + continue) and show the same map.
	flow.go_back()
	await _drop_main(main)
	main = await _new_main(store, SEED_SLICE)
	flow = main.get_node("GameFlow") as GameFlow
	flow.continue_requested()
	await _shot("E7-resumed-at-the-warden-same-map-and-heat")
	await _drop_main(main)
	# E6: the forge screen (seed 28, treasure lane).
	var store2: ProgressStore = ProgressStore.memory_store()
	var main2: Node = await _new_main(store2, SEED_FORGE)
	var flow2: GameFlow = main2.get_node("GameFlow") as GameFlow
	flow2.start_requested()
	flow2.character_chosen(HERO)
	flow2.choose_region("ch1")
	await _walk_region(flow2)
	flow2.choose_region("hellfire")
	var g2: MapGraph = flow2.get_run().graph
	var forge_id: String = ""
	for id: String in g2.node_ids():
		if g2.nodes[id]["kind"] == "forge":
			forge_id = id
	if not forge_id.is_empty():
		var lane: String = str(g2.nodes[forge_id]["lane"])
		await _play(flow2, 0)
		await _play(flow2, _index_of(flow2, lane + ".1"))
		await _play(flow2, _index_of(flow2, lane + ".2"))
		await _play(flow2, int(flow2.get_available_nodes()[0]["node_index"]))
		var map_view2: Node = _find(main2, "ChapterMapView")
		if map_view2 != null:
			map_view2.set("_selected", _index_of(flow2, forge_id))
		await _shot("E6a-forge-node-preview")
		flow2.choose_node(_index_of(flow2, forge_id))
		await _shot("E6b-forge-screen-ink-row-free-removal")
	await _drop_main(main2)
	print("SAVED %d: %s" % [_saved.size(), ", ".join(PackedStringArray(_saved))])
	quit()


func _tap(at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	press.global_position = at
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	release.global_position = at
	Input.parse_input_event(release)
	await process_frame
	await process_frame


func _find(main: Node, type_name: String) -> Node:
	for child: Node in main.get_children():
		if child.get_class() == type_name or child.get_script() != null and str(child.get_script().get_global_name()) == type_name:
			return child
		var deeper: Node = _find(child, type_name)
		if deeper != null:
			return deeper
	return null


func _shot(name: String) -> void:
	for _i: int in 4:
		await process_frame
	var path: String = "%s/%s.png" % [_out, name]
	root.get_texture().get_image().save_png(path)
	_saved.append(name)


func _new_main(store: ProgressStore, seed: int) -> Node:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(store)
	flow.set_seed_for_test(seed)
	flow.set_focus_autopause_for_test(false)
	root.add_child(main)
	await process_frame
	return main


func _drop_main(main: Node) -> void:
	root.remove_child(main)
	main.queue_free()
	await process_frame


func _phase(controller: RunController) -> int:
	return controller.get_state().get_phase()


func _wait_phase(controller: RunController, phase: int) -> bool:
	for _i: int in MAX_FRAMES:
		if controller == null or not is_instance_valid(controller):
			return false
		if _phase(controller) == phase:
			return true
		await process_frame
	return false


func _view(controller: RunController) -> CombatView:
	return controller.get_battle().get_node(RunController.COMBAT_VIEW_NODE) as CombatView


func _kill_until_won(controller: RunController) -> bool:
	for _i: int in MAX_FRAMES:
		if controller == null or not is_instance_valid(controller):
			return false
		if _phase(controller) == RunState.Phase.WON:
			return true
		var view: CombatView = _view(controller) if controller.get_battle() != null else null
		if view != null and view.get_state() != null and not view.get_state().is_enemy_dead():
			view.get_state().enemy_invulnerable_left = 0.0
			view.get_state().damage(CombatState.Side.ENEMY, 999999.0)
		await process_frame
	return false


func _skip_reward(flow: GameFlow) -> void:
	if flow.get_run().has_pending_relic_offer():
		flow.skip_relic_offer()
	if flow.has_ink_offer():
		flow.skip_ink_offer()
	if flow.get_run().has_pending_reward():
		flow.reward_skipped()


func _play(flow: GameFlow, index: int) -> void:
	var kind: String = ""
	for n: Dictionary in flow.get_available_nodes():
		if int(n["node_index"]) == index:
			kind = str(n["kind"])
	if index < 0 or not flow.choose_node(index):
		return
	match kind:
		"battle", "danger", "miniboss", "boss":
			var c: RunController = flow.get_controller()
			if c == null:
				return
			await _wait_phase(c, RunState.Phase.PLAYING)
			await _kill_until_won(c)
			await process_frame
			if flow.get_phase() == GameFlow.Phase.FATE:
				flow.choose_fate("spare")
			_skip_reward(flow)
		"treasure":
			_skip_reward(flow)
		"rest":
			flow.rest_heal_requested()
		"shop":
			flow.shop_leave()
		"event":
			flow.event_leave()
		"forge":
			flow.forge_leave()


# A fight node: a frame of its INTRO band (the modifier block), then won like _play.
func _play_intro_shot(flow: GameFlow, index: int, name: String) -> void:
	if index < 0 or not flow.choose_node(index):
		return
	var c: RunController = flow.get_controller()
	if c == null:
		return
	await _wait_phase(c, RunState.Phase.INTRO)
	for _i: int in 3:
		await process_frame
	await _shot(name)
	await _wait_phase(c, RunState.Phase.PLAYING)
	await _kill_until_won(c)
	await process_frame
	if flow.get_phase() == GameFlow.Phase.FATE:
		flow.choose_fate("spare")
	_skip_reward(flow)


func _walk_region(flow: GameFlow) -> void:
	for _i: int in 20:
		if flow.get_phase() != GameFlow.Phase.MAP:
			return
		var avail: Array[Dictionary] = flow.get_available_nodes()
		if avail.is_empty():
			return
		var pick: int = int(avail[0]["node_index"])
		for n: Dictionary in avail:
			if n["kind"] == "boss":
				pick = int(n["node_index"])
		await _play(flow, pick)


func _index_of(flow: GameFlow, id: String) -> int:
	for n: Dictionary in flow.get_available_nodes():
		if flow.get_run().node_id_at(flow.get_run().column, int(n["node_index"])) == id:
			return int(n["node_index"])
	return -1

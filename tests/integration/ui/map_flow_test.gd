extends SceneTree
## 2026-11-02 map v5: drives the real chapter map with touch events. Windowed only:
## --windowed --resolution 1280x720 -s res://tests/integration/ui/map_flow_test.gd -- --no-autopause
## Intents: a new column selects its first available node; a tap on another available node only selects it (still
## MAP); the pause icon opens the pause panel, Resume closes it; the block-set icon opens the block set; a tap on the
## selected node enters it; on a fresh floor the Enter button enters the selected node; pause -> Back to title leaves
## the run saved. Memory progress store (no save touched). Prints PASS/FAIL lines and FAILS=n.

const RealMouseGuard = preload("res://tests/integration/ui/real_mouse_guard.gd")
const VP: Vector2 = Vector2(1280, 720)
const HERO: String = "kiem_si"

var fails: int = 0
var flow: GameFlow
var view: ChapterMapView


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = pos
	root.push_input(ev, true)
	await process_frame


func _tap(pos: Vector2) -> void:
	await _touch(pos, true)
	await _touch(pos, false)
	await process_frame


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _node_center(index: int) -> Vector2:
	var map: Array[Dictionary] = flow.get_run_map()
	var column: int = flow.get_current_column()
	return ScreenLayout.map_route_node_center(VP, column, map.size(), index, (map[column].get("nodes", []) as Array).size())


func _available() -> Array[int]:
	var out: Array[int] = []
	for node: Dictionary in flow.get_available_nodes():
		out.append(int(node.get("node_index", -1)))
	return out


func _new_run_on_map() -> void:
	flow.start_requested()
	flow.character_chosen(HERO)
	flow.choose_region(flow.get_region_offer()[0])
	await _frames(3)


func _initialize() -> void:
	root.size = Vector2i(VP)
	var main: Node = load("res://src/main.tscn").instantiate()
	flow = main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	root.add_child(RealMouseGuard.new())
	await _frames(3)
	view = flow.get_node("ChapterMapView") as ChapterMapView
	await test_enter_button_enters_the_selected_node()
	await test_select_pause_block_set_and_tap_to_enter()
	await test_pause_back_to_title_keeps_the_run()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_enter_button_enters_the_selected_node() -> void:
	await _new_run_on_map()
	_check("test_new_floor_opens_on_the_map", flow.get_phase() == GameFlow.Phase.MAP)
	var first: int = _available()[0] if not _available().is_empty() else -1
	_check("test_first_available_node_is_selected", view.get_selected_node() == first, "selected %d first %d" % [view.get_selected_node(), first])
	await _tap(ScreenLayout.map_enter_button_rect(VP).get_center())
	_check("test_enter_button_leaves_the_map", flow.get_phase() != GameFlow.Phase.MAP or not flow.get_pending_reward().is_empty(), "phase %d" % flow.get_phase())
	flow.leave_run_keep_save()
	flow.leave_run()
	await _frames(2)


func test_select_pause_block_set_and_tap_to_enter() -> void:
	await _new_run_on_map()
	# Walk to a column with at least two choices (the dev helper clears columns with their first node).
	for _i: int in 4:
		if _available().size() >= 2:
			break
		flow._dev_clear_columns(1)
		await _frames(2)
	var available: Array[int] = _available()
	_check("test_found_a_column_with_two_choices", available.size() >= 2, str(available))
	if available.size() < 2:
		return
	await _frames(2)
	_check("test_new_column_selects_its_first_node", view.get_selected_node() == available[0])
	await _tap(_node_center(available[1]))
	_check("test_tap_on_another_node_only_selects_it", view.get_selected_node() == available[1] and flow.get_phase() == GameFlow.Phase.MAP,
		"selected %d phase %d" % [view.get_selected_node(), flow.get_phase()])
	await _tap(ScreenLayout.map_pause_button_rect(VP).get_center())
	_check("test_pause_icon_opens_the_pause_panel", view.is_paused())
	await _tap(_node_center(available[0]))
	_check("test_paused_map_ignores_node_taps", view.get_selected_node() == available[1] and flow.get_phase() == GameFlow.Phase.MAP)
	await _tap(ChapterMapView.pause_button_rects(VP)[0].get_center())
	_check("test_resume_closes_the_pause_panel", not view.is_paused() and flow.get_phase() == GameFlow.Phase.MAP)
	await _tap(ScreenLayout.map_block_set_button_rect(VP).get_center())
	_check("test_block_set_icon_opens_the_block_set", flow.get_phase() == GameFlow.Phase.PIECE_DECK, "phase %d" % flow.get_phase())
	flow.go_back()
	await _frames(2)
	_check("test_block_set_returns_to_the_map", flow.get_phase() == GameFlow.Phase.MAP, "phase %d" % flow.get_phase())
	var column: int = flow.get_current_column()
	await _tap(_node_center(view.get_selected_node()))
	_check("test_tap_on_the_selected_node_enters_it", flow.get_phase() != GameFlow.Phase.MAP or not flow.get_pending_reward().is_empty() or flow.get_current_column() != column,
		"phase %d" % flow.get_phase())
	flow.leave_run_keep_save()
	flow.leave_run()
	await _frames(2)


func test_pause_back_to_title_keeps_the_run() -> void:
	await _new_run_on_map()
	await _tap(ScreenLayout.map_pause_button_rect(VP).get_center())
	await _tap(ChapterMapView.pause_button_rects(VP)[1].get_center())
	await _frames(2)
	_check("test_back_to_title_leaves_to_the_title", flow.get_phase() == GameFlow.Phase.TITLE, "phase %d" % flow.get_phase())
	_check("test_back_to_title_keeps_the_run_saved", flow.has_continue())
	_check("test_pause_panel_closed_after_leaving", not view.is_paused())

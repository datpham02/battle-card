extends SceneTree
## Scratch flow test for Story 016 part 1 (pause, can_pause, GameFlow phases / go_back / continue).
## Prints PASS/FAIL lines and FAILS=n; exits with that count.

const MAIN_SCENE: String = "res://src/main.tscn"
const FAST_RUN: String = "res://tests/fixtures/fast_run.json"
const MAX_FRAMES: int = 4000

var _fails: int = 0
var _pause_events: Array[bool] = []


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _wait_playing(rc: RunController) -> bool:
	for _i: int in MAX_FRAMES:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			return true
		await process_frame
	return false


func _view(rc: RunController) -> CombatView:
	return rc.get_battle().get_node(RunController.COMBAT_VIEW_NODE) as CombatView


func _cells_without(cells: Array[Vector2i], skip: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		if c != skip:
			out.append(c)
	return out


func _run() -> void:
	var store: ProgressStore = ProgressStore.memory_store()
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(store)
	root.add_child(main)
	await process_frame
	_check(flow.get_phase() == GameFlow.Phase.TITLE, "starts in TITLE")
	_check(flow.can_show_quit() == (OS.get_name() != "iOS"), "can_show_quit follows the OS name")

	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file(FAST_RUN))
	rc.paused_changed.connect(func(p: bool) -> void: _pause_events.append(p))
	_check(flow.get_phase() == GameFlow.Phase.IN_FLOOR, "enter_test_floor -> IN_FLOOR")
	_check(not rc.can_pause(), "can_pause false in INTRO")
	rc.set_paused(true)
	_check(not rc.is_paused(), "set_paused(true) refused in INTRO")
	rc.set_paused(true, true)
	_check(not rc.is_paused(), "forced pause also refused in INTRO")
	var ok: bool = await _wait_playing(rc)
	_check(ok, "intro -> PLAYING")
	var combat: CombatView = _view(rc)
	_check(not combat.debug_overlay, "debug_overlay false by default")
	combat.get_boss().set_active(false)
	var hold: HoldSlots = (rc.get_battle().get_node("HoldSlotsView") as HoldSlotsView).get_slots()
	var actor: CutActor = combat.get_cut_actor()
	var state: CombatState = combat.get_state()
	_check(rc.can_pause(), "can_pause true in PLAYING")

	# --- pause / resume -------------------------------------------------------------
	var fp: FieldPoint = combat.get_drops().debug_place("B2", Vector2i(0, 0), 5.0)
	var cell0: Vector2i = state.player_cell
	rc.set_paused(true)
	_check(rc.is_paused() and not rc.can_pause(), "set_paused(true): is_paused, can_pause now false")
	_check(rc.get_battle().process_mode == Node.PROCESS_MODE_DISABLED, "battle process_mode DISABLED")
	_check(_pause_events == [true], "paused_changed(true) emitted once: %s" % str(_pause_events))
	var e0: float = rc.get_state().get_elapsed_sec()
	var f0: float = fp.freshness_left
	await _frames(40)
	_check(rc.get_state().get_elapsed_sec() == e0, "run clock did not advance while paused")
	_check(fp.freshness_left == f0, "drop freshness did not change while paused")
	_check(state.player_cell == cell0, "player cell unchanged while paused")
	rc.set_paused(false)
	_check(not rc.is_paused() and rc.get_battle().process_mode == Node.PROCESS_MODE_INHERIT, "resume: INHERIT, not paused")
	_check(_pause_events == [true, false], "paused_changed(false) emitted")
	await _frames(40)
	_check(rc.get_state().get_elapsed_sec() > e0, "run clock advances after resume")
	_check(fp.freshness_left < f0, "drops age after resume")
	rc.set_paused(false)
	_check(_pause_events.size() == 2, "resume when not paused emits nothing")
	rc.toggle_pause()
	_check(rc.is_paused(), "toggle_pause pauses")
	rc.toggle_pause()
	_check(not rc.is_paused(), "toggle_pause resumes")

	# --- cut menu blocks the pause (Story 024: a piece is placed, then the menu opens) -------------
	var bar2 := FieldPoint.new()
	bar2.piece = PieceLibrary.load_from_file().make_piece("bar2")
	_check(hold.place(bar2, 0) == 0, "bar2 piece placed in bag slot 0")
	_check(combat.select_piece(0) and combat.is_placing(), "select_piece(0) enters PLACING")
	_check(combat.aim_at_cell(state.enemy_cell) and combat.can_confirm_placement(), "ghost aimed at the boss cell can be confirmed")
	_check(combat.get_placement().hits(state.enemy_cell), "the aimed ghost covers the boss cell")
	_check(combat.confirm_placement(), "confirm_placement opens the cut")
	_check(not combat.is_placing() and hold.get_piece(0) == null, "placing ended, the piece left the bag")
	var flow_cut: CutFlow = combat.get_cut_flow()
	_check(flow_cut.is_menu_open(), "skill menu is open")
	_check(not combat.can_pause() and not rc.can_pause(), "can_pause false while the menu is open")
	rc.set_paused(true)
	_check(not rc.is_paused(), "pause refused while the menu is open")
	_check(flow_cut.choose(flow_cut.get_hand()[0]) or flow_cut.choose("kiem_khi") or true, "attempt a choice")
	if flow_cut.is_menu_open():
		flow_cut.tick_real(10.0)
	_check(not flow_cut.is_menu_open(), "menu closed (chosen or timed out)")
	actor.cancel()
	_check(combat.can_pause(), "can_pause true again after the menu and the swing")

	# --- swing lockout ---------------------------------------------------------------------
	var lockout: float = CombatConfig.load_from_file().pause_lockout_sec
	_check(is_equal_approx(lockout, 0.5), "pause_lockout_sec = 0.5 from combat.json")
	var cut_cells: Array[Vector2i] = _cells_without(combat.get_grid().enemy_cells(), state.enemy_cell)
	_check(actor.begin_swing(cut_cells, SkillConfig.FALLBACK_SKILL, true), "player swing started")
	_check(actor.get_time_left() > lockout, "swing longer than the lockout (%.2f s)" % actor.get_time_left())
	_check(combat.can_pause(), "can_pause true early in a swing")
	var guard: int = 0
	while actor.is_swinging() and actor.get_time_left() > lockout and guard < MAX_FRAMES:
		await process_frame
		guard += 1
	_check(actor.is_swinging(), "swing still running at the lockout window")
	_check(not combat.can_pause(), "can_pause false in the last %.1f s of the player's swing" % lockout)
	rc.set_paused(true)
	_check(not rc.is_paused(), "pause refused in the lockout window")
	rc.set_paused(true, true)
	_check(rc.is_paused(), "force pauses even in the lockout window")
	rc.set_paused(false)
	guard = 0
	while actor.is_swinging() and guard < MAX_FRAMES:
		await process_frame
		guard += 1
	_check(combat.can_pause(), "can_pause true after the swing resolved")

	var boss_actor: CutActor = combat.get_boss().get_actor()
	var boss_cells: Array[Vector2i] = _cells_without(combat.get_grid().player_cells(), state.player_cell)
	_check(boss_actor.begin_swing(boss_cells, SkillConfig.FALLBACK_SKILL, false), "boss swing started")
	_check(combat.can_pause(), "can_pause true early in the boss's swing")
	guard = 0
	while boss_actor.is_swinging() and boss_actor.get_time_left() > lockout and guard < MAX_FRAMES:
		await process_frame
		guard += 1
	_check(boss_actor.is_swinging() and not combat.can_pause(), "can_pause false in the last %.1f s of the boss's swing" % lockout)
	boss_actor.cancel()
	_check(combat.can_pause(), "can_pause true after the boss swing was cancelled")

	# --- phase leaves PLAYING while paused -----------------------------------------------------
	rc.set_paused(true)
	_check(rc.is_paused(), "paused again")
	rc.get_state().on_match_lost()
	await _frames(2)
	_check(not rc.is_paused(), "flag cleared when the phase left PLAYING")
	_check(_pause_events[_pause_events.size() - 1] == false, "paused_changed(false) emitted on the clear")
	_check(rc.get_battle().process_mode == Node.PROCESS_MODE_DISABLED, "battle stays frozen after the match ended")
	rc.set_paused(true, true)
	_check(not rc.is_paused(), "cannot pause in LOST")
	_check(not rc.is_paused(), "still no pause flag after the refused pause in LOST")

	# --- go_back and auto pause ----------------------------------------------------------------
	rc = flow.enter_test_floor(RunConfig.load_from_file(FAST_RUN))
	ok = await _wait_playing(rc)
	_check(ok, "second test floor PLAYING")
	flow.go_back()
	_check(rc.is_paused(), "go_back in IN_FLOOR pauses")
	flow.go_back()
	_check(not rc.is_paused(), "go_back while paused resumes")
	flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(rc.is_paused(), "focus out auto-pauses")
	rc.set_paused(false)
	flow.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(rc.is_paused(), "application paused auto-pauses")
	rc.set_paused(false)
	flow.leave_floor()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.get_controller() == null, "leave_floor (test floor) -> TITLE (Story 019)")
	flow.start_requested()
	flow.character_chosen(flow.get_characters().default_id())
	_check(flow.get_phase() == GameFlow.Phase.CHAPTER_SELECT, "character_chosen -> CHAPTER_SELECT")
	flow.go_back()
	_check(flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT and flow.get_controller() == null, "go_back in CHAPTER_SELECT -> CHARACTER_SELECT (Story 018)")
	flow.go_back()
	_check(flow.get_phase() == GameFlow.Phase.TITLE, "go_back in CHARACTER_SELECT -> TITLE")
	flow.start_requested()
	_check(flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT, "start_requested -> CHARACTER_SELECT")
	flow.start_requested()
	_check(flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT, "start_requested ignored outside TITLE")
	flow.character_chosen("no_such_hero")
	_check(flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT and flow.get_character_id() == flow.get_characters().default_id(), "character_chosen(unknown) stays put (selection unchanged)")
	flow.character_chosen(flow.get_characters().default_id())
	_check(flow.get_phase() == GameFlow.Phase.CHAPTER_SELECT and flow.get_character_id() == flow.get_characters().default_id(), "character_chosen -> CHAPTER_SELECT")

	# --- leaving a paused node keeps the record; continue (Story 022 map model) --------------------
	var config: ChaptersConfig = flow.get_config()
	_check(not flow.has_continue(), "has_continue false before any run")
	flow.start_run(0)
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.has_continue(), "start_run -> MAP, run saved")
	_check(flow.choose_node(int(flow.get_available_nodes()[0]["node_index"])), "choose the first node")
	rc = flow.get_controller()
	ok = await _wait_playing(rc)
	_check(ok and flow.get_phase() == GameFlow.Phase.IN_NODE, "node PLAYING in IN_NODE")
	rc.set_paused(true, true)
	flow.leave_floor()
	var saved_run: Dictionary = store.load_state(config).get_run_dict()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.get_progress().has_run(), "leave from pause -> TITLE, run still saved (Story 019)")
	_check(int(saved_run.get("version", 0)) == 4 and int(saved_run.get("column", -1)) == 0 and int(saved_run.get("node_index", -1)) == 0, "saved run stays at column 0 node 0: v%s c%s n%s" % [str(saved_run.get("version")), str(saved_run.get("column")), str(saved_run.get("node_index"))])
	var hero: Dictionary = flow.get_characters().get_character(flow.get_characters().default_id())
	var pre: RunSession = RunSession.begin(config, hero, 0, 5, config.generate_map(0, 5, 0), 1)
	pre.choose_node(0)
	pre.complete_node(-1.0, 300.0, "", {}, 0.0)
	var fight: int = -1
	for n: Dictionary in pre.available_nodes():
		if fight < 0 and ["battle", "danger"].has(str(n["kind"])):
			fight = int(n["node_index"])
	_check(fight >= 0 and pre.choose_node(fight), "setup: column 1 fight node chosen")
	pre.hp = 40.0
	flow.get_progress().set_run(pre)
	store.save_state(flow.get_progress())
	flow.show_title()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.has_continue(), "title with a continue")
	flow.continue_requested()
	rc = flow.get_controller()
	_check(flow.get_phase() == GameFlow.Phase.IN_NODE and flow.get_current_column() == 1 and flow.get_current_floor() == Vector2i(0, 1), "continue enters column 1 of ch1")
	_check(rc != null and rc.get_state().get_match_index() == 0 and rc.get_config().matches[0]["id"] == str(pre.current_node()["match_id"]) and flow.get_floor_seed() == pre.run_seed, "continue respawns the chosen node's match with the run seed")
	_check(rc != null and is_equal_approx(rc.get_state().get_carried_hp(), 40.0), "continue carries HP 40 (no minimum rule)")
	flow.show_title()
	_check(flow.get_controller() == null, "show_title frees the controller")

	print("FAILS=", _fails)
	quit(_fails)

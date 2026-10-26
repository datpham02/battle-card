extends SceneTree
## Story 037 (W4) integration test of the unlock wiring in GameFlow on the real main scene:
## - a finished region boss writes its milestones (region_boss:<id>) and queues its achievements; the fate
##   writes spares_total / kills_total; take_new_unlocks() returns the ids once, then [];
## - an unfinished node (a match still playing, a run abandoned mid-match) writes and grants nothing;
## - the final match won ends the run: win_<character>, first_run_won, reach_an_dai, the ending milestone;
## - a lost run grants no win and writes no runs_won;
## - a new run freezes the locked content into the run (empty save) and locks nothing for an unlock-all save;
##   the character list follows the earned achievements (tho_san / giao_si).
## Prints PASS/FAIL lines and FAILS=n; exits with that count.

const MAIN_SCENE: String = "res://src/main.tscn"
const MAX_FRAMES: int = 4000
const HERO: String = "phap_su"
const REGION: String = "ch1"
const CH1_BATTLE: String = "goblin_scout"
const CH1_BOSS: String = "goblin_warlock"
const RUN_SEED: int = 11

var _fails: int = 0
var _config: ChaptersConfig
var _hero: Dictionary


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


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


func _new_main(store: ProgressStore) -> Node:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(store)
	# The real toast view takes the queue itself (W5); detach it so this test observes the queue.
	for toast: Node in main.find_children("*", "UnlockToastView", true, false):
		toast.get_parent().remove_child(toast)
		toast.queue_free()
	root.add_child(main)
	await process_frame
	return main


func _drop_main(main: Node) -> void:
	root.remove_child(main)
	main.queue_free()
	await process_frame


func _flow(main: Node) -> GameFlow:
	return main.get_node("GameFlow") as GameFlow


# A store holding a saved run in REGION at 0-based [param floor_index] whose map is one column of one node.
func _store_with(kind: String, match_id: String, floor_index: int = 0, locked: Dictionary = {}) -> ProgressStore:
	var store: ProgressStore = ProgressStore.memory_store()
	var map: Array[Dictionary] = [{"index": 0, "tier": 0, "nodes": [{"kind": kind, "match_id": match_id}]}]
	var pre: RunSession = RunSession.begin(_config, _hero, 0, RUN_SEED, map, 1)
	pre.floor = floor_index
	pre.locked = locked
	var progress := ProgressState.new()
	progress.set_run(pre)
	store.save_state(progress)
	return store


func _win_node(flow: GameFlow, label: String) -> RunController:
	if not flow.choose_node(0) or flow.get_controller() == null:
		_check(false, "%s: node 0 chosen with a controller" % label)
		return null
	var c: RunController = flow.get_controller()
	_check(await _wait_phase(c, RunState.Phase.PLAYING), "%s: PLAYING" % label)
	_check(await _kill_until_won(c), "%s: foe dead -> WON" % label)
	return c


func _fates_of(fate: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in _config.world_floors():
		out.append({"floor": i, "region_id": REGION, "match_id": CH1_BOSS, "fate": fate})
	return out


func _run() -> void:
	TranslationServer.set_locale("vi")
	_hero = CharacterConfig.load_from_file().get_character(HERO)
	var probe: Node = await _new_main(ProgressStore.memory_store())
	_config = _flow(probe).get_config()
	await _drop_main(probe)
	var cfg: AchievementsConfig = AchievementsConfig.shared()

	# --- a spared region boss: milestones, achievements, take_new_unlocks once ---------------------------
	var store_a: ProgressStore = _store_with("boss", CH1_BOSS)
	var main_a: Node = await _new_main(store_a)
	var flow: GameFlow = _flow(main_a)
	flow.continue_requested()
	_check(flow.take_new_unlocks().is_empty(), "nothing queued before any node")
	_check(flow.choose_node(0) and flow.get_controller() != null, "boss node chosen")
	var c: RunController = flow.get_controller()
	_check(await _wait_phase(c, RunState.Phase.PLAYING), "boss: PLAYING")
	var st0: ProgressState = store_a.load_state(_config)
	_check(st0.get_milestone("region_boss:" + REGION) == 0 and st0.get_achievements().is_empty(), "unfinished node: no milestone, no achievement")
	_check(await _kill_until_won(c), "boss: WON")
	var st1: ProgressState = store_a.load_state(_config)
	_check(st1.get_milestone("region_boss:" + REGION) == 1, "the finished boss wrote region_boss:%s = 1" % REGION)
	_check(st1.has_achievement("first_region_boss") and st1.has_achievement("boss_forest"), "first_region_boss and boss_forest earned and saved")
	flow.choose_fate("spare")
	var st2: ProgressState = store_a.load_state(_config)
	_check(st2.get_milestone("spares_total") == 1 and st2.get_milestone("kills_total") == 0, "spare wrote spares_total 1")
	var news: Array[String] = flow.take_new_unlocks()
	_check(news.has("first_region_boss") and news.has("boss_forest"), "take_new_unlocks returns %s" % str(news))
	_check(flow.take_new_unlocks().is_empty(), "take_new_unlocks clears the queue")
	_check(not flow.get_characters().unlocked_ids().has("tho_san") and not flow.get_characters().unlocked_ids().has("giao_si"), "1 spare: neither new character is open yet")
	await _drop_main(main_a)

	# --- an executed boss: kills_total ---------------------------------------------------------------------
	var store_b: ProgressStore = _store_with("boss", CH1_BOSS)
	var main_b: Node = await _new_main(store_b)
	flow = _flow(main_b)
	flow.continue_requested()
	await _win_node(flow, "execute run")
	flow.choose_fate("execute")
	_check(store_b.load_state(_config).get_milestone("kills_total") == 1, "execute wrote kills_total 1")
	await _drop_main(main_b)

	# --- hunter_path: 3 kills in the save open Tho san in the character list --------------------------------
	var store_h: ProgressStore = ProgressStore.memory_store()
	var st_h := ProgressState.new()
	st_h.add_milestone("kills_total", 2)
	store_h.save_state(st_h)
	var main_h: Node = await _new_main(store_h)
	flow = _flow(main_h)
	_check(not flow.get_characters().unlocked_ids().has("tho_san"), "2 kills: Tho san still locked")
	flow.get_progress().record_fate("goblin_a", FateLogic.FATE_EXECUTE)
	flow.get_progress().record_fate("goblin_b", FateLogic.FATE_EXECUTE)
	flow.get_progress().record_fate("goblin_c", FateLogic.FATE_EXECUTE)
	var earned: Array[String] = UnlockRules.process(cfg, flow.get_progress(), {"type": "fate"})
	_check(earned.has("hunter_path") and flow.get_characters().unlocked_ids().has("tho_san"), "3+ kills: hunter_path earned, Tho san in unlocked_ids %s" % str(earned))
	await _drop_main(main_h)

	# --- an abandoned run grants nothing for the unfinished node -------------------------------------------
	var store_c: ProgressStore = _store_with("boss", CH1_BOSS)
	var main_c: Node = await _new_main(store_c)
	flow = _flow(main_c)
	flow.continue_requested()
	c = null
	_check(flow.choose_node(0) and flow.get_controller() != null, "abandon run: boss chosen")
	c = flow.get_controller()
	_check(await _wait_phase(c, RunState.Phase.PLAYING), "abandon run: PLAYING")
	flow.leave_run_keep_save()
	var st_c: ProgressState = store_c.load_state(_config)
	_check(st_c.get_achievements().is_empty() and st_c.get_milestone("region_boss:" + REGION) == 0 and st_c.get_milestone("runs_won") == 0, "abandoned mid-match: no milestone, no achievement")
	_check(flow.take_new_unlocks().is_empty(), "abandoned mid-match: nothing queued")
	await _drop_main(main_c)

	# --- the final match won: run end ----------------------------------------------------------------------
	var store_e: ProgressStore = _store_with("boss", CH1_BOSS, _config.world_floors() - 1)
	var main_e: Node = await _new_main(store_e)
	flow = _flow(main_e)
	flow.continue_requested()
	await _win_node(flow, "last region boss")
	flow.choose_fate("spare")
	flow.reward_skipped()
	_check(flow.is_final_floor(), "the final floor is reached")
	var st_e0: ProgressState = store_e.load_state(_config)
	_check(st_e0.get_milestone("reached_final") == 1 and st_e0.has_achievement("reach_an_dai"), "reaching An Dai wrote reached_final and earned reach_an_dai")
	_check(st_e0.get_milestone("runs_won") == 0, "before the end no run is won")
	flow.get_run().boss_fates = _fates_of("spare")
	while flow.get_current_column() < flow.get_run_map().size() - 1 and flow.choose_node(0) and flow.get_phase() == GameFlow.Phase.SHOP:
		flow.shop_leave()
	flow.take_new_unlocks()
	await _win_node(flow, "final match")
	_check(flow.get_phase() == GameFlow.Phase.ENDING, "final won -> ENDING")
	var st_e: ProgressState = store_e.load_state(_config)
	_check(st_e.get_milestone("runs_won") == 1 and st_e.get_milestone("runs_won:" + HERO) == 1, "run end wrote runs_won and runs_won:%s" % HERO)
	_check(st_e.get_milestone("ending:spare") == 1, "run end wrote ending:spare")
	_check(st_e.has_achievement("win_" + HERO) and st_e.has_achievement("first_run_won") and st_e.has_achievement("ending_mercy"),
		"win_%s, first_run_won, ending_mercy earned" % HERO)
	var end_news: Array[String] = flow.take_new_unlocks()
	_check(end_news.has("win_" + HERO) and end_news.has("first_run_won"), "take_new_unlocks at the ending: %s" % str(end_news))
	_check(flow.take_new_unlocks().is_empty(), "…and then it is empty")
	await _drop_main(main_e)

	# --- a lost run grants no win -------------------------------------------------------------------------
	var store_f: ProgressStore = _store_with("battle", CH1_BATTLE)
	var main_f: Node = await _new_main(store_f)
	flow = _flow(main_f)
	flow.continue_requested()
	_check(flow.choose_node(0) and flow.get_controller() != null, "loss run: battle chosen")
	c = flow.get_controller()
	_check(await _wait_phase(c, RunState.Phase.PLAYING), "loss run: PLAYING")
	_view(c).get_state().damage(CombatState.Side.PLAYER, 999999.0)
	_check(await _wait_phase(c, RunState.Phase.LOST), "loss run: LOST")
	var st_f: ProgressState = store_f.load_state(_config)
	_check(st_f.get_milestone("runs_won") == 0 and not st_f.has_achievement("win_" + HERO), "a lost run: no runs_won, no win_%s" % HERO)
	for id: String in flow.take_new_unlocks():
		_check(not id.begins_with("win_") and id != "first_run_won", "a lost run queued only %s" % id)
	await _drop_main(main_f)

	# --- a new run freezes the locked content --------------------------------------------------------------
	var main_g: Node = await _new_main(ProgressStore.memory_store())
	flow = _flow(main_g)
	flow.start_run()
	var run_g: RunSession = flow.get_run()
	_check(run_g != null and run_g.is_locked("card", "gai_doc") and run_g.is_locked("relic", "tui_rong") and run_g.is_locked("piece", "w5"),
		"an empty save starts the run with the new card / relic / shape locked")
	_check(run_g != null and run_g.is_locked("character", "tho_san"), "…and the character list says Tho san is locked")
	await _drop_main(main_g)
	var store_all: ProgressStore = ProgressStore.memory_store()
	var st_all := ProgressState.new()
	st_all.mark_all_unlocked(cfg, _config.region_ids())
	store_all.save_state(st_all)
	var main_h2: Node = await _new_main(store_all)
	flow = _flow(main_h2)
	flow.start_run()
	_check(flow.get_run() != null and flow.get_run().locked.is_empty(), "an every-unlock save starts a run with nothing locked")
	_check(flow.get_characters().unlocked_ids().has("tho_san") and flow.get_characters().unlocked_ids().has("giao_si"), "…and both new characters are open")
	await _drop_main(main_h2)

	print("FAILS=%d" % _fails)
	quit(_fails)

extends SceneTree
## Story 035 (P3) integration test of the GameFlow fate / ending / stats flow on the real main scene:
## only a region boss opens FATE (a miniboss and the final match do not); spare -> no relic, boss reward of
## 3 cards + token; execute -> an offer of execute_artifact_offers relics at or above execute_min_rarity, a
## pick adds the relic, a skip still counts as execute; boss_fates / ProgressState updated; quit on FATE (and
## on the execute offer) and resume -> the same screen, match not replayed; the final match won -> ENDING with
## the right id for an all-spare and an all-execute run; a death records the stats and where.
## Prints PASS/FAIL lines and FAILS=n; exits with that count.

const MAIN_SCENE: String = "res://src/main.tscn"
const MAX_FRAMES: int = 4000
const HERO: String = "phap_su"
const REGION: String = "ch1"
const CH1_BATTLE: String = "goblin_scout"
const CH1_MINIBOSS: String = "goblin_chief"
const CH1_BOSS: String = "goblin_warlock"
const RUN_SEED: int = 11
## Boss reward of Story 022 / 031: 3 cards.
const BOSS_OFFER_CARDS: int = 3

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


# Hits the foe each frame (clearing a phased boss's invulnerability) until the controller reports WON.
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
func _store_with(kind: String, match_id: String, floor_index: int = 0) -> ProgressStore:
	var store: ProgressStore = ProgressStore.memory_store()
	var map: Array[Dictionary] = [{"index": 0, "tier": 0, "nodes": [{"kind": kind, "match_id": match_id}]}]
	var pre: RunSession = RunSession.begin(_config, _hero, 0, RUN_SEED, map, 1)
	pre.floor = floor_index
	var progress := ProgressState.new()
	progress.set_run(pre)
	store.save_state(progress)
	return store


# Chooses node 0, waits for PLAYING, kills the foe until WON. Returns the controller (null on failure).
func _win_node(flow: GameFlow, label: String) -> RunController:
	if not flow.choose_node(0) or flow.get_controller() == null:
		_check(false, "%s: node 0 chosen with a controller" % label)
		return null
	var c: RunController = flow.get_controller()
	_check(await _wait_phase(c, RunState.Phase.PLAYING), "%s: PLAYING" % label)
	_check(await _kill_until_won(c), "%s: foe dead -> WON" % label)
	return c


func _boss_reward_open(flow: GameFlow) -> bool:
	return flow.get_pending_reward_kind() == "boss" and flow.get_pending_reward().size() == BOSS_OFFER_CARDS \
		and flow.get_pending_reward_info().get("removal_token") == true


func _fates_of(fate: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in _config.world_floors():
		out.append({"floor": i, "region_id": REGION, "match_id": CH1_BOSS, "fate": fate})
	return out


func _run() -> void:
	TranslationServer.set_locale("vi")
	_hero = CharacterConfig.load_from_file().get_character(HERO)
	var fate_cfg: Dictionary = {}

	# --- a region boss: FATE, quit and resume, spare -> boss reward, no relic ----------------------------
	var store_a: ProgressStore = null
	var main_a: Node = await _new_main(ProgressStore.memory_store())
	_config = _flow(main_a).get_config()
	fate_cfg = _config.fate_config()
	await _drop_main(main_a)
	store_a = _store_with("boss", CH1_BOSS)
	main_a = await _new_main(store_a)
	var flow: GameFlow = _flow(main_a)
	flow.continue_requested()
	_check(flow.get_phase() == GameFlow.Phase.MAP, "region boss run on the MAP")
	var c: RunController = await _win_node(flow, "region boss")
	var relics0: Array[String] = flow.get_relics()
	_check(c != null and bool(_view(c).match_params.get(CombatView.PARAM_BOSS_CAN_DOWN, false)), "region boss match: boss_can_down set")
	_check(c != null and _view(c).is_boss_downed(), "region boss downed")
	_check(flow.get_phase() == GameFlow.Phase.FATE and flow.is_fate_pending() and flow.get_controller() == c, "region boss won -> FATE, controller kept")
	_check(flow.get_pending_reward().is_empty() and not flow.has_fate_offer(), "no reward and no offer before the fate")
	var fv: Dictionary = flow.get_fate_view()
	_check(int(fv.get("offers", -1)) == int(fate_cfg["execute_artifact_offers"]) and str(fv.get("min_rarity", "")) == str(fate_cfg["execute_min_rarity"])
		and is_equal_approx(float(fv.get("hold_sec", -1.0)), float(fate_cfg["fate_hold_sec"])) and not str(fv.get("boss_name", "")).is_empty(), "fate view %s" % str(fv))
	_check(store_a.load_state(_config).has_run() and bool(store_a.load_state(_config).get_run_dict().get("pending_fate", false)), "save: pending_fate true")
	_check(int(flow.get_run().stats.get("matches_won", 0)) == 1 and float(flow.get_run().stats.get("damage_dealt", 0.0)) > 0.0, "stats: 1 match won, damage dealt %s" % str(flow.get_run().stats.get("damage_dealt")))
	flow.leave_run_keep_save()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.has_continue(), "quit on FATE -> TITLE, continue offered")
	flow.continue_requested()
	_check(flow.get_phase() == GameFlow.Phase.FATE and flow.is_fate_pending() and flow.get_controller() == null, "resume -> FATE, no controller (not replayed)")
	_check(flow.get_floor() == 1 and int(flow.get_run().stats.get("matches_won", 0)) == 1, "resume: floor 2, the match counted once")
	flow.choose_fate("bogus")
	_check(flow.is_fate_pending(), "unknown fate ignored")
	flow.choose_fate("spare")
	_check(not flow.is_fate_pending() and not flow.has_fate_offer() and flow.get_relics() == relics0, "spare: no relic")
	_check(_boss_reward_open(flow) and flow.get_phase() == GameFlow.Phase.MAP, "spare -> boss reward of 3 cards + token (MAP, resumed run)")
	var fates: Array[Dictionary] = flow.get_run().boss_fates
	_check(fates.size() == 1 and str(fates[0]["fate"]) == "spare" and str(fates[0]["match_id"]) == CH1_BOSS and int(fates[0]["floor"]) == 0 and str(fates[0]["region_id"]) == REGION, "boss_fates %s" % str(fates))
	var st_a: ProgressState = store_a.load_state(_config)
	_check(st_a.get_spared_bosses().has(CH1_BOSS) and st_a.get_spare_total() == 1 and st_a.get_execute_total() == 0, "progress: spared %s" % str(st_a.get_spared_bosses()))
	await _drop_main(main_a)

	# --- execute: offer at the rarity floor, pick adds the relic, then the boss reward (live controller) ---
	var store_b: ProgressStore = _store_with("boss", CH1_BOSS)
	var main_b: Node = await _new_main(store_b)
	flow = _flow(main_b)
	flow.continue_requested()
	c = await _win_node(flow, "execute run")
	flow.choose_fate("execute")
	var offer: Array[String] = flow.get_fate_offer()
	var floor_rank: int = RelicConfig.rarity_rank(str(fate_cfg["execute_min_rarity"]))
	var at_floor: bool = true
	for id: String in offer:
		if RelicConfig.rarity_rank(str(RelicRegistry.info(id).get("rarity", ""))) < floor_rank:
			at_floor = false
	_check(flow.get_phase() == GameFlow.Phase.FATE and flow.has_fate_offer() and offer.size() == int(fate_cfg["execute_artifact_offers"]), "execute -> offer of %d: %s" % [offer.size(), str(offer)])
	_check(at_floor, "offer at or above %s" % str(fate_cfg["execute_min_rarity"]))
	_check(flow.get_pending_reward().is_empty(), "no card offer while the artifact offer is open")
	if not offer.is_empty():
		flow.choose_fate_relic(offer[0])
		_check(flow.get_relics().has(offer[0]) and not flow.has_fate_offer(), "pick adds %s" % offer[0])
	_check(_boss_reward_open(flow) and flow.get_phase() == GameFlow.Phase.IN_NODE and flow.get_controller() == c, "execute -> boss reward over the live match")
	var st_b: ProgressState = store_b.load_state(_config)
	_check(st_b.get_executed_bosses().has(CH1_BOSS) and st_b.get_execute_total() == 1 and str(flow.get_run().boss_fates[0]["fate"]) == "execute", "progress / run: executed")
	await _drop_main(main_b)

	# --- execute, quit on the offer, resume on it, skip: still execute -----------------------------------
	var store_c: ProgressStore = _store_with("boss", CH1_BOSS)
	var main_c: Node = await _new_main(store_c)
	flow = _flow(main_c)
	flow.continue_requested()
	await _win_node(flow, "execute skip run")
	flow.choose_fate("execute")
	var offer_c: Array[String] = flow.get_fate_offer()
	flow.leave_run_keep_save()
	flow.continue_requested()
	_check(flow.get_phase() == GameFlow.Phase.FATE and flow.has_fate_offer() and flow.get_fate_offer() == offer_c and flow.get_controller() == null, "resume on the open execute offer")
	var relics_c: Array[String] = flow.get_relics()
	flow.skip_fate_relic()
	_check(flow.get_relics() == relics_c and _boss_reward_open(flow), "skip: no relic, boss reward")
	_check(flow.get_run().boss_fates.size() == 1 and str(flow.get_run().boss_fates[0]["fate"]) == "execute" and store_c.load_state(_config).get_execute_total() == 1, "skip still counts as execute")
	await _drop_main(main_c)

	# --- a miniboss: no FATE ------------------------------------------------------------------------------
	var main_d: Node = await _new_main(_store_with("miniboss", CH1_MINIBOSS, 1))
	flow = _flow(main_d)
	flow.continue_requested()
	c = await _win_node(flow, "miniboss")
	_check(c != null and not bool(_view(c).match_params.get(CombatView.PARAM_BOSS_CAN_DOWN, false)) and not _view(c).is_boss_downed(), "miniboss: not downable")
	_check(flow.get_phase() == GameFlow.Phase.IN_NODE and not flow.is_fate_pending() and flow.get_pending_reward_kind() == "miniboss", "miniboss -> its reward, no FATE")
	await _drop_main(main_d)

	# --- the final match: no FATE, ENDING by the run's fates -----------------------------------------------
	for fate: String in ["spare", "execute"]:
		var store_e: ProgressStore = _store_with("boss", CH1_BOSS, _config.world_floors() - 1)
		var main_e: Node = await _new_main(store_e)
		flow = _flow(main_e)
		flow.continue_requested()
		await _win_node(flow, "last region boss (%s run)" % fate)
		flow.choose_fate(fate)
		if flow.has_fate_offer():
			flow.skip_fate_relic()
		flow.reward_skipped()
		_check(flow.is_final_floor() and flow.get_phase() == GameFlow.Phase.MAP, "%s run: the final match's MAP" % fate)
		flow.get_run().boss_fates = _fates_of(fate)
		# TD-029: leave the `world.final_prelude` shop column(s) first.
		while flow.get_current_column() < flow.get_run_map().size() - 1 and flow.choose_node(0) and flow.get_phase() == GameFlow.Phase.SHOP:
			flow.shop_leave()
		c = await _win_node(flow, "final match (%s run)" % fate)
		# Real-play order: the HUD connected at match start, the phase change came later -> banner text set.
		var banner: String = ""
		for hud: Node in main_e.find_children("*", "CutHudView", true, false):
			banner = str(hud.get("_phase_banner_text"))
		_check(not banner.is_empty(), "final match: the HUD got the phase banner '%s'" % banner)
		_check(c != null and not bool(_view(c).match_params.get(CombatView.PARAM_BOSS_CAN_DOWN, false)), "final match: boss_can_down not set")
		var ending: Dictionary = flow.get_ending()
		_check(flow.get_phase() == GameFlow.Phase.ENDING and flow.get_run_result() == GameFlow.RunResult.WON and not flow.is_fate_pending(), "%s run: final won -> ENDING, no FATE" % fate)
		_check(str(ending.get("id", "")) == fate and str(ending.get("title_key", "")) == "ending.%s.title" % fate
			and (ending.get("line_keys", []) as Array).size() == GameFlow.ENDING_LINE_COUNT and str((ending.get("line_keys", []) as Array)[0]) == "ending.%s.line1" % fate, "ending %s" % str(ending.get("id")))
		var stats: Dictionary = ending.get("stats", {})
		_check(int(stats.get("matches_won", 0)) == 2 and (stats.get("fates", []) as Array).size() == _config.world_floors() and (stats.get("death", {}) as Dictionary).is_empty(), "ending stats: 2 matches won, %d fates, no death" % (stats.get("fates", []) as Array).size())
		var st_e: ProgressState = store_e.load_state(_config)
		_check(st_e.get_endings_seen().has(fate) and not st_e.has_run(), "progress: ending %s seen, run dropped" % fate)
		flow.leave_ending()
		_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.get_run() == null and not flow.has_continue(), "leave_ending -> TITLE, no run")
		await _drop_main(main_e)

	# --- a death: stats and where -------------------------------------------------------------------------
	var store_f: ProgressStore = _store_with("battle", CH1_BATTLE)
	var main_f: Node = await _new_main(store_f)
	flow = _flow(main_f)
	flow.continue_requested()
	_check(flow.choose_node(0) and flow.get_controller() != null, "death run: battle chosen")
	c = flow.get_controller()
	_check(await _wait_phase(c, RunState.Phase.PLAYING), "death run: PLAYING")
	_view(c).get_state().damage(CombatState.Side.PLAYER, 999999.0)
	_check(await _wait_phase(c, RunState.Phase.LOST), "death run: LOST")
	var summary: Dictionary = flow.get_defeat_summary()
	var death: Dictionary = summary.get("death", {})
	_check(flow.get_run_result() == GameFlow.RunResult.LOST and not store_f.load_state(_config).has_run(), "death: LOST, save dropped")
	_check(int(death.get("floor", -1)) == 0 and str(death.get("region_id", "")) == REGION and str(death.get("match_id", "")) == CH1_BATTLE
		and not str(death.get("boss_name_key", "")).is_empty(), "death recorded %s" % str(death))
	_check(float(summary.get("damage_taken", 0.0)) > 0.0 and int(summary.get("matches_won", -1)) == 0, "death stats: damage taken %s, 0 won" % str(summary.get("damage_taken")))
	flow.leave_run()
	_check(flow.get_defeat_summary() == summary, "defeat summary kept after the run is dropped")
	await _drop_main(main_f)

	print("FAILS=%d" % _fails)
	quit(_fails)

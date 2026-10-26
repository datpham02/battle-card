extends SceneTree
## TD-029 (approved 2026-10-26): a SHOP before the final match at Ấn Đài (`world.final_prelude`).
## Config: ChaptersConfig.final_prelude() / final_map() = the shop column then the boss column; a missing
## key keeps the old one-column final map; kinds that need a match id are dropped (warning).
## Flow: the last region boss -> the final floor's MAP at column 0 = one shop node, then the boss; the
## prelude shop is seeded / tagged by the FINAL floor (a stale floor-5 region shop_state is not reused);
## buying works and saves; quitting in the shop and resuming returns to the same shop; leaving it goes to
## the boss column; winning the final still opens ENDING (no FATE).
## Headless: godot --headless --path . -s res://tests/integration/run/final_prelude_test.gd
## Prints PASS/FAIL lines and FAILS=n; exits with that count.

const MAIN_SCENE: String = "res://src/main.tscn"
const MAX_FRAMES: int = 4000
const HERO: String = "phap_su"
const CH1_BOSS: String = "goblin_warlock"
const RUN_SEED: int = 21
## Boundary value of the test: enough gold for any shop card.
const RICH_GOLD: int = 500

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


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


func _view(controller: RunController) -> CombatView:
	return controller.get_battle().get_node(RunController.COMBAT_VIEW_NODE) as CombatView


func _wait_phase(controller: RunController, phase: int) -> bool:
	for _i: int in MAX_FRAMES:
		if controller == null or not is_instance_valid(controller):
			return false
		if controller.get_state().get_phase() == phase:
			return true
		await process_frame
	return false


# Hits the foe each frame (clearing a phased boss's invulnerability) until the controller reports WON.
func _kill_until_won(controller: RunController) -> bool:
	for _i: int in MAX_FRAMES:
		if controller == null or not is_instance_valid(controller):
			return false
		if controller.get_state().get_phase() == RunState.Phase.WON:
			return true
		var view: CombatView = _view(controller) if controller.get_battle() != null else null
		if view != null and view.get_state() != null and not view.get_state().is_enemy_dead():
			view.get_state().enemy_invulnerable_left = 0.0
			view.get_state().damage(CombatState.Side.ENEMY, 999999.0)
		await process_frame
	return false


func _win_node(flow: GameFlow, node_index: int, label: String) -> RunController:
	if not flow.choose_node(node_index) or flow.get_controller() == null:
		_check(false, "%s: node %d chosen with a controller" % [label, node_index])
		return null
	var c: RunController = flow.get_controller()
	_check(await _wait_phase(c, RunState.Phase.PLAYING), "%s: PLAYING" % label)
	_check(await _kill_until_won(c), "%s: foe dead -> WON" % label)
	return c


func _run() -> void:
	TranslationServer.set_locale("vi")
	_test_config()
	await _test_flow()
	print("FAILS=%d" % _fails)
	quit(_fails)


func _test_config() -> void:
	var config: ChaptersConfig = ChaptersConfig.load_from_file()
	var fm: Dictionary = config.final_match()
	var fmap: Array[Dictionary] = config.final_map()
	_check(config.final_prelude() == [["shop"]], "shipped world.final_prelude = [[shop]]: %s" % str(config.final_prelude()))
	_check(fmap.size() == 2 and int(fmap[0]["index"]) == 0 and int(fmap[1]["index"]) == 1, "final map: 2 columns (prelude 0, boss 1)")
	_check((fmap[0]["nodes"] as Array).size() == 1 and str(fmap[0]["nodes"][0]["kind"]) == "shop" and str(fmap[0]["nodes"][0]["match_id"]).is_empty(), "column 0: one shop node, no match id")
	_check((fmap[1]["nodes"] as Array).size() == 1 and str(fmap[1]["nodes"][0]["kind"]) == "boss" and str(fmap[1]["nodes"][0]["match_id"]) == str(fm["match_id"]), "column 1: the final boss %s" % str(fm))
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ChaptersConfig.DEFAULT_PATH)) as Dictionary
	(raw["world"] as Dictionary).erase("final_prelude")
	var none: ChaptersConfig = ChaptersConfig.from_dictionary(raw.duplicate(true))
	var one: Array[Dictionary] = none.final_map()
	_check(none.final_prelude().is_empty() and one.size() == 1 and str(one[0]["nodes"][0]["kind"]) == "boss" and int(one[0]["index"]) == 0, "missing final_prelude -> the old one-column final map")
	(raw["world"] as Dictionary)["final_prelude"] = []
	_check(ChaptersConfig.from_dictionary(raw.duplicate(true)).final_map().size() == 1, "empty final_prelude -> one column")
	(raw["world"] as Dictionary)["final_prelude"] = [["battle", "rest"], ["boss"], "shop", [3]]
	var bad: ChaptersConfig = ChaptersConfig.from_dictionary(raw.duplicate(true))
	_check(bad.final_prelude() == [["rest"]] and bad.final_map().size() == 2, "bad kinds / columns dropped: %s" % str(bad.final_prelude()))
	(raw["world"] as Dictionary)["final_prelude"] = "shop"
	_check(ChaptersConfig.from_dictionary(raw.duplicate(true)).final_prelude().is_empty(), "non-array final_prelude ignored")
	(raw["world"] as Dictionary).erase("final_match")
	_check(ChaptersConfig.from_dictionary(raw.duplicate(true)).final_map().is_empty(), "no final match -> no final map")


func _test_flow() -> void:
	var store: ProgressStore = ProgressStore.memory_store()
	var main: Node = await _new_main(store)
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	var config: ChaptersConfig = flow.get_config()
	var floors: int = config.world_floors()
	var fm: Dictionary = config.final_match()
	var hero: Dictionary = flow.get_characters().get_character(HERO)
	var pre: RunSession = RunSession.begin(config, hero, 0, RUN_SEED,
		[{"index": 0, "tier": 0, "nodes": [{"kind": "boss", "match_id": CH1_BOSS}]}] as Array[Dictionary], 1)
	pre.floor = floors - 1
	var progress := ProgressState.new()
	progress.set_run(pre)
	store.save_state(progress)
	await _drop_main(main)
	main = await _new_main(store)
	flow = main.get_node("GameFlow") as GameFlow
	flow.continue_requested()
	_check(flow.get_phase() == GameFlow.Phase.MAP and not flow.is_final_floor(), "last floor's region boss on the MAP")
	await _win_node(flow, 0, "last region boss")
	flow.choose_fate("spare")
	if flow.has_fate_offer():
		flow.skip_fate_relic()
	_check(flow.is_final_floor() and bool(flow.take_floor_clear_notice().get("is_final", false)), "final floor reached, notice says final")
	flow.reward_skipped()
	var map: Array[Dictionary] = flow.get_run_map()
	var avail: Array[Dictionary] = flow.get_available_nodes()
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.get_current_region() == str(fm["region"]) and map.size() == 2 and flow.get_current_column() == 0, "final floor MAP: 2 columns, column 0")
	_check(avail.size() == 1 and str(avail[0]["kind"]) == "shop", "column 0 offers the shop: %s" % str(avail))
	_check(str(map[1]["nodes"][0]["kind"]) == "boss" and str(map[1]["nodes"][0]["match_id"]) == str(fm["match_id"]), "column 1 = the final boss")

	# --- the prelude shop: a stale floor-5 REGION shop state is not reused -------------------------------
	var run: RunSession = flow.get_run()
	run.gold = RICH_GOLD
	run.shop_state = {GameFlow.SHOP_NODE: "%d/0/0" % (floors - 1), "cards": [], "relics": []}
	_check(flow.choose_node(0) and flow.get_phase() == GameFlow.Phase.SHOP, "shop node -> SHOP")
	run = flow.get_run()
	_check(str(run.shop_state.get(GameFlow.SHOP_NODE, "")) == "%d/0/0" % floors, "shop tagged by the final floor: %s" % str(run.shop_state.get(GameFlow.SHOP_NODE, "")))
	var shop: Dictionary = flow.get_shop()
	_check(not (shop.get("cards", []) as Array).is_empty(), "final shop has its own stock (the stale region stock is not reused)")
	var card0: Dictionary = (shop["cards"] as Array)[0]
	var gold_before: int = run.gold
	var bought: Dictionary = flow.shop_buy(ShopLogic.KIND_CARD, str(card0["id"]))
	_check(bool(bought.get("ok", false)) and run.gold == gold_before - int(card0["price"]) and run.deck_ids.has(str(card0["id"])), "buy card %s in the final shop" % str(card0["id"]))
	var saved: Dictionary = store.load_state(config).get_run_dict()
	_check(int(saved.get("gold", -1)) == run.gold and int(saved.get("floor", -1)) == floors and int(saved.get("column", -1)) == 0, "the buy is saved (gold %d, final floor, column 0)" % run.gold)
	var gold_after: int = run.gold

	# --- quit in the shop, resume -> the same shop ----------------------------------------------------
	flow.go_back()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.has_continue(), "quit in the final shop -> TITLE, save kept")
	flow.continue_requested()
	run = flow.get_run()
	shop = flow.get_shop()
	_check(flow.get_phase() == GameFlow.Phase.SHOP and flow.is_final_floor() and run.gold == gold_after, "resume -> the final shop, gold %d" % run.gold)
	_check(bool(((shop.get("cards", []) as Array)[0] as Dictionary).get("sold", false)), "resume keeps the sold flag")

	# --- leave -> the boss column ----------------------------------------------------------------------
	flow.shop_leave()
	avail = flow.get_available_nodes()
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.get_current_column() == 1 and run.shop_state.is_empty(), "shop_leave -> MAP, column 1")
	_check(avail.size() == 1 and str(avail[0]["kind"]) == "boss" and str(avail[0]["match_id"]) == str(fm["match_id"]), "column 1 offers the final boss")
	flow.go_back()
	flow.continue_requested()
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.get_current_column() == 1 and flow.is_final_floor(), "resume after the shop -> the final MAP at the boss column")

	# --- the final match -> ENDING (no FATE) ------------------------------------------------------------
	var c: RunController = await _win_node(flow, 0, "final match")
	_check(c != null and not bool(_view(c).match_params.get(CombatView.PARAM_BOSS_CAN_DOWN, false)), "final match: boss_can_down not set")
	_check(flow.get_phase() == GameFlow.Phase.ENDING and flow.get_run_result() == GameFlow.RunResult.WON and not flow.is_fate_pending() and flow.get_pending_reward().is_empty(), "final won -> ENDING, no FATE, no offer")
	_check(not store.load_state(config).has_run(), "store: run dropped after the win")
	await _drop_main(main)

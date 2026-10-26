extends SceneTree
## Scratch flow test for Story 022 Part 2a, moved to the WORLD run of Story 031 (GameFlow node wiring):
## character select -> WORLD_MAP (floor 1 offer) -> choose_region -> MAP -> choose a battle node -> win
## -> reward -> MAP; save at the world map, at choose and after the reward; leave / continue from the
## world map, the map and a node; treasure (free offer, no fight); rest (heal / forge); miniboss rarity
## floor; region boss -> token, floor +1 with the floor heal, progress -> reward -> WORLD_MAP of the
## next floor; the boss of the last floor -> the final match's map -> winning it wins the run; removal
## token spent by remove; resume with a pending offer; pre-v5 save -> restart notice; death.
## Prints PASS/FAIL lines and FAILS=n; exits with that count.

const MAIN_SCENE: String = "res://src/main.tscn"
const MAX_FRAMES: int = 4000
const HERO: String = "phap_su"
const CH1_BATTLE: String = "goblin_scout"
const CH1_MINIBOSS: String = "goblin_chief"
const CH1_BOSS: String = "goblin_warlock"
const MATCH_KINDS: Array[String] = ["battle", "danger", "miniboss", "boss"]

var _fails: int = 0


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


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _view(controller: RunController) -> CombatView:
	return controller.get_battle().get_node(RunController.COMBAT_VIEW_NODE) as CombatView


func _deck_size(controller: RunController) -> int:
	return (_view(controller).match_params.get("deck", []) as Array).size()


func _deck_ids(controller: RunController) -> Array[String]:
	var ids: Array[String] = []
	for e: Variant in _view(controller).match_params.get("deck", []) as Array:
		ids.append(str((e as Dictionary).get("id", "")) if typeof(e) == TYPE_DICTIONARY else str(e))
	return ids


func _kill_boss(controller: RunController) -> void:
	_view(controller).get_state().damage(CombatState.Side.ENEMY, 999999.0)


# Story 035: a phased boss (the final an_dai_keeper, trait boss_phases) clamps one huge hit at its next
# phase threshold and is then invulnerable for phase_shift_sec; the test skips that wait by clearing the
# invulnerability and hitting again each frame until the run controller reports WON.
func _kill_until_won(controller: RunController) -> bool:
	for _i: int in MAX_FRAMES:
		if controller == null or not is_instance_valid(controller):
			return false
		if _phase(controller) == RunState.Phase.WON:
			return true
		var view: CombatView = _view(controller) if controller.get_battle() != null else null
		if view != null and view.get_state() != null and not view.get_state().is_enemy_dead():
			view.get_state().enemy_invulnerable_left = 0.0
			_kill_boss(controller)
		await process_frame
	return false


func _distinct(ids: Array[String]) -> bool:
	var seen: Dictionary = {}
	for id: String in ids:
		seen[id] = true
	return seen.size() == ids.size()


# node_index of the first available node whose kind is in [param kinds]; -1 when none.
func _find_node(flow: GameFlow, kinds: Array[String]) -> int:
	for n: Dictionary in flow.get_available_nodes():
		if kinds.has(str(n["kind"])):
			return int(n["node_index"])
	return -1


func _map(columns: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in columns.size():
		out.append({"index": i, "tier": 1, "nodes": columns[i]})
	return out


func _node(kind: String, match_id: String = "") -> Dictionary:
	return {"kind": kind, "match_id": match_id}


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


# Chooses the node, waits for PLAYING, kills the foe and waits for WON. Returns the controller.
func _win_node(flow: GameFlow, node_index: int, hurt: float = 0.0) -> RunController:
	_check(flow.choose_node(node_index), "choose_node(%d) accepted" % node_index)
	var c: RunController = flow.get_controller()
	if c == null:
		_check(false, "no controller after choose_node(%d)" % node_index)
		return null
	var ok: bool = await _wait_phase(c, RunState.Phase.PLAYING)
	_check(ok, "node PLAYING")
	if hurt > 0.0:
		_view(c).get_state().damage(CombatState.Side.PLAYER, hurt)
	ok = await _kill_until_won(c)
	_check(ok, "foe dead -> WON")
	return c


func _run() -> void:
	TranslationServer.set_locale("vi")
	var reward_cfg: Dictionary = RewardRoller.load_config()
	var cards: SkillConfig = SkillConfig.load_from_file()
	var characters: CharacterConfig = CharacterConfig.load_from_file()
	var store: ProgressStore = ProgressStore.memory_store()
	var main: Node = await _new_main(store)
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	var config: ChaptersConfig = flow.get_config()
	var starter: int = flow.get_characters().deck_of(HERO).size()
	var tokens0: int = int(reward_cfg["starting_removals"])
	_check(GameFlow.Phase.IN_FLOOR == GameFlow.Phase.IN_NODE and GameFlow.IN_FLOOR == GameFlow.Phase.IN_NODE, "IN_FLOOR aliases IN_NODE")
	_check(flow.get_phase() == GameFlow.Phase.TITLE, "starts in TITLE")
	_check(not flow.has_continue(), "no continue on a fresh save")
	_check(flow.get_run_map().is_empty() and flow.get_current_column() == -1 and flow.get_available_nodes().is_empty() and flow.get_removal_tokens() == 0 and is_zero_approx(flow.get_luck()), "map getters empty without a run")
	flow.start_requested()
	_check(flow.get_phase() == GameFlow.Phase.CHARACTER_SELECT, "start_requested -> CHARACTER_SELECT")
	flow.character_chosen(HERO)
	_check(flow.get_phase() == GameFlow.Phase.WORLD_MAP and flow.get_run() != null and flow.get_controller() == null, "character_chosen -> WORLD_MAP (Story 031)")
	_check(flow.get_floor() == 0 and flow.get_floor_count() == config.world_floors() and not flow.is_final_floor(), "floor 1 of %d" % flow.get_floor_count())
	_check(flow.get_current_region().is_empty() and flow.get_run_map().is_empty() and flow.get_region_path().is_empty(), "no region yet, no map")
	var offer0: Array[String] = flow.get_region_offer()
	_check(offer0.size() == mini(2, config.region_ids().size()) and _distinct(offer0), "floor 1 offers %s" % str(offer0))
	var preview: Dictionary = flow.region_preview(offer0[0])
	_check(str(preview.get("name", "")) == flow.region_name(offer0[0]) and not str(preview.get("name", "")).is_empty() and int(preview.get("floor_number", 0)) == 1, "region_preview: %s" % str(preview))
	var saved: Dictionary = store.load_state(config).get_run_dict()
	_check(int(saved.get("version", 0)) == RunSession.SAVE_VERSION and saved.get("region_offer", []) == offer0 and str(saved.get("region", "?")).is_empty(), "store holds the v5 run at the world map")
	_check(store.load_state(config).get_best_floor() == 1, "best floor 1 recorded")
	# leave at the WORLD_MAP, continue -> WORLD_MAP with the same offer
	flow.go_back()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.has_continue(), "go_back in WORLD_MAP -> TITLE, save kept")
	flow.continue_requested()
	_check(flow.get_phase() == GameFlow.Phase.WORLD_MAP and flow.get_region_offer() == offer0 and flow.get_floor() == 0, "continue -> WORLD_MAP, same offer")
	_check(not flow.choose_node(0), "choose_node refused on the world map")
	flow.choose_region("zz")
	_check(flow.get_phase() == GameFlow.Phase.WORLD_MAP and flow.get_region_offer() == offer0, "choose_region(unknown) ignored")

	# --- choose the region: MAP ----------------------------------------------------------------------
	var region: String = offer0[0]
	flow.choose_region(region)
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.get_controller() == null and flow.get_current_region() == region, "choose_region(%s) -> MAP, no controller" % region)
	_check(flow.get_region_path() == ([region] as Array[String]) and flow.get_region_offer().is_empty(), "path [%s], offer closed" % region)
	var map: Array[Dictionary] = flow.get_run_map()
	_check(map == config.generate_region_map(region, flow.get_run().run_seed, 0, 0) and map.size() >= 3, "map = the region's floor-1 map (%d columns)" % map.size())
	_check(flow.get_current_column() == 0 and flow.get_cleared_nodes().is_empty(), "at column 0, nothing cleared")
	var avail: Array[Dictionary] = flow.get_available_nodes()
	_check(avail.size() == 1 and str(avail[0]["kind"]) == "battle" and int(avail[0]["node_index"]) == 0, "column 0 offers one battle: %s" % str(avail))
	_check(flow.get_run().character_id == HERO and flow.get_run().deck_ids.size() == starter, "run: hero %s, starter deck %d" % [HERO, starter])
	_check(flow.get_removal_tokens() == tokens0 and is_zero_approx(flow.get_luck()), "tokens %d, luck 0 at start" % tokens0)
	_check(flow.get_pending_reward_kind().is_empty() and flow.get_pending_reward_info().is_empty(), "no pending kind / info")
	saved = store.load_state(config).get_run_dict()
	_check(int(saved.get("version", 0)) == RunSession.SAVE_VERSION and str(saved.get("region", "")) == region and int(saved.get("column", -1)) == 0 and int(saved.get("node_index", 0)) == -1 and (saved.get("map", []) as Array).size() == map.size() and int(saved.get("removal_tokens", -1)) == tokens0, "store holds the v5 run in the region: column %s node %s" % [str(saved.get("column")), str(saved.get("node_index"))])
	_check(not flow.choose_node(99), "choose_node(99) refused")

	# --- choose the battle node -> IN_NODE -----------------------------------------------------------
	_check(flow.choose_node(0), "choose_node(0) accepted")
	var c: RunController = flow.get_controller()
	_check(c != null and flow.get_phase() == GameFlow.Phase.IN_NODE, "battle node -> IN_NODE with a controller")
	_check(c.get_config().match_count() == 1 and is_zero_approx(c.get_config().between_sec), "one-match config, between_sec 0")
	_check(c.get_config().matches[0]["id"] == str(map[0]["nodes"][0]["match_id"]), "controller plays the node's match %s" % str(map[0]["nodes"][0]["match_id"]))
	_check(flow.get_current_floor() == Vector2i(config.region_index(region), 0), "get_current_floor (deprecated) = (region index, column)")
	saved = store.load_state(config).get_run_dict()
	_check(int(saved.get("node_index", -1)) == 0 and int(saved.get("column", -1)) == 0, "store saved at choose: node 0 of column 0")
	_check(_deck_size(c) == starter, "first CombatView deck = starter %d" % starter)
	var ok: bool = await _wait_phase(c, RunState.Phase.PLAYING)
	_check(ok, "intro -> PLAYING")
	var max_hp: float = c.get_player_max_hp()
	_check(is_equal_approx(max_hp, 190.0), "mage max HP 190 (from characters.json, Story 026)")

	# --- win -> node completed -> reward gate --------------------------------------------------------
	_view(c).get_state().damage(CombatState.Side.PLAYER, 30.0)
	_kill_boss(c)
	ok = await _wait_phase(c, RunState.Phase.WON)
	_check(ok, "node won -> WON")
	var offer: Array[String] = flow.get_pending_reward()
	_check(offer.size() == 3 and _distinct(offer), "pending reward of 3 distinct ids: %s" % str(offer))
	_check(flow.get_pending_reward_kind() == "battle" and flow.get_pending_reward_info().get("free") == false and int(flow.get_pending_reward_info().get("offers", 0)) == 3, "pending kind battle, info %s" % str(flow.get_pending_reward_info()))
	_check(flow.get_current_column() == 1 and flow.get_cleared_nodes().size() == 1 and str(flow.get_cleared_nodes()[0]["kind"]) == "battle", "node completed: column 1, 1 cleared")
	_check(is_equal_approx(flow.get_luck(), float(reward_cfg["luck_per_node"])), "luck %.1f after one node" % flow.get_luck())
	saved = store.load_state(config).get_run_dict()
	_check((saved.get("pending_reward", []) as Array).size() == 3 and int(saved.get("column", -1)) == 1 and int(saved.get("node_index", 0)) == -1, "store holds pending_reward at column 1: pending %d" % (saved.get("pending_reward", []) as Array).size())
	_check(flow.get_phase() == GameFlow.Phase.IN_NODE and c.get_battle().process_mode == Node.PROCESS_MODE_DISABLED, "still IN_NODE, battle frozen")
	_check(flow.get_run_result() == GameFlow.RunResult.NONE, "run result NONE mid-run")
	await _frames(30)
	_check(flow.get_controller() == c and flow.get_phase() == GameFlow.Phase.IN_NODE, "no auto-advance while the offer is open")
	var hp_end0: float = c.get_last_player_hp()
	var passive0: float = _view(c).get_passive_heal()
	_check(hp_end0 < max_hp, "setup: player hurt (hp %.1f)" % hp_end0)
	_check(is_equal_approx(flow.get_run().hp, minf(hp_end0 + passive0, max_hp)), "run hp = min(%.1f + passive %.1f, %.0f) = %.1f (no auto heal)" % [hp_end0, passive0, max_hp, flow.get_run().hp])
	flow.reward_chosen("no_such_card")
	_check(flow.get_pending_reward().size() == 3, "reward_chosen(unknown id) ignored")
	var pick_up: bool = RewardRoller.is_upgrade(offer[0], flow.get_deck_levels())
	var after1: int = starter + (0 if pick_up else 1)
	flow.reward_chosen(offer[0])
	_check(flow.get_run().deck_ids.size() == after1 and (int(flow.get_run().deck_levels()[offer[0]]) == 2 if pick_up else flow.get_run().deck_ids[starter] == offer[0]), "reward_chosen -> deck %d (upgrade: %s)" % [after1, pick_up])
	_check(flow.get_pending_reward().is_empty() and flow.get_pending_reward_kind().is_empty(), "offer cleared")
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.get_controller() == null, "after the reward -> MAP, controller freed")
	await process_frame
	_check(flow.get_node_or_null("RunController") == null, "RunController node freed")
	saved = store.load_state(config).get_run_dict()
	_check((saved.get("pending_reward", []) as Array).is_empty() and (saved.get("deck", []) as Array).size() == after1 and int(saved.get("column", -1)) == 1, "store after the reward: pending empty, deck %d, column 1" % after1)
	_check(flow.get_available_nodes().size() >= 2 and flow.get_available_nodes().size() <= 3, "column 1 offers 2-3 nodes: %s" % str(flow.get_available_nodes()))
	var hp_after_node: float = flow.get_run().hp

	# --- leave from the MAP, continue -> MAP at the same place ---------------------------------------
	flow.leave_run_keep_save()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.has_continue(), "leave_run_keep_save from MAP -> TITLE, continue offered")
	flow.continue_requested()
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.get_controller() == null, "continue (nothing chosen) -> MAP")
	_check(flow.get_run_map() == map and flow.get_current_column() == 1 and flow.get_run().deck_ids.size() == after1 and is_equal_approx(flow.get_run().hp, hp_after_node), "continue restored the map, column 1, deck %d, hp %.1f" % [after1, hp_after_node])
	_check(flow.get_character_id() == HERO, "continue restores the character")
	_check(flow.take_restart_notice().is_empty(), "no restart notice for a v5 save")

	# --- die in column 1 ------------------------------------------------------------------------------
	var fight: int = _find_node(flow, MATCH_KINDS)
	_check(fight >= 0, "column 1 has a fight node")
	_check(flow.choose_node(fight), "choose the fight node")
	var c2: RunController = flow.get_controller()
	_check(c2 != null and c2 != c and is_equal_approx(c2.get_state().get_carried_hp(), hp_after_node), "new controller carries hp %.1f" % hp_after_node)
	_check(_deck_size(c2) == after1 and _deck_ids(c2).has(offer[0]), "column 1 CombatView deck has %d ids incl. the pick" % after1)
	ok = await _wait_phase(c2, RunState.Phase.PLAYING)
	_check(ok, "column 1 node PLAYING")
	saved = store.load_state(config).get_run_dict()
	_check(int(saved.get("node_index", -1)) == fight and is_equal_approx(float(saved.get("hp", -1.0)), hp_after_node), "store saved at match start: node %d hp %.1f" % [fight, hp_after_node])
	await _frames(5)
	_check(c2.get_state().get_elapsed_sec() > 0.0, "run clock ticks")
	_view(c2).get_state().damage(CombatState.Side.PLAYER, 999999.0)
	ok = await _wait_phase(c2, RunState.Phase.LOST)
	_check(ok, "player dead -> LOST")
	_check(flow.get_run_result() == GameFlow.RunResult.LOST, "run result LOST")
	_check(flow.get_run() != null and flow.get_run().deck_ids.size() == after1, "run object kept for the result screen")
	var after_death: ProgressState = store.load_state(config)
	_check(not after_death.has_run() and after_death.get_regions_boss_beaten().is_empty(), "store: run dropped, no region boss beaten")
	_check(not flow.has_continue(), "has_continue false after death")
	_check(flow.get_phase() == GameFlow.Phase.IN_NODE and flow.get_controller() == c2, "result shown in IN_NODE")
	flow.go_back()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.get_controller() == null and flow.get_run() == null, "go_back on a finished run = leave_run -> TITLE, no run")
	_check(flow.get_run_result() == GameFlow.RunResult.NONE, "run result reset")
	await _drop_main(main)

	# --- hand-built map: battle, treasure, rest, miniboss, boss ---------------------------------------
	var hero: Dictionary = characters.get_character(HERO)
	var custom: Array[Dictionary] = _map([
		[_node("battle", CH1_BATTLE)], [_node("treasure")], [_node("rest")],
		[_node("miniboss", CH1_MINIBOSS)], [_node("boss", CH1_BOSS)],
	])
	var store2: ProgressStore = ProgressStore.memory_store()
	var pre: RunSession = RunSession.begin(config, hero, 0, 11, custom, 1)
	pre.hp = 100.0
	var pre_n: int = pre.deck_ids.size()
	var progress2 := ProgressState.new()
	progress2.set_run(pre)
	store2.save_state(progress2)
	var main2: Node = await _new_main(store2)
	var flow2: GameFlow = main2.get_node("GameFlow") as GameFlow
	_check(flow2.get_phase() == GameFlow.Phase.TITLE and flow2.has_continue(), "custom run: title with Continue")
	flow2.continue_requested()
	_check(flow2.get_phase() == GameFlow.Phase.MAP and flow2.get_run_map() == custom and flow2.get_current_column() == 0, "continue -> MAP of the custom map")
	# leave from IN_NODE, continue respawns the match
	_check(flow2.choose_node(0), "choose the battle")
	var c3: RunController = flow2.get_controller()
	_check(c3 != null and flow2.get_phase() == GameFlow.Phase.IN_NODE, "battle IN_NODE")
	flow2.leave_floor()
	_check(flow2.get_phase() == GameFlow.Phase.TITLE and flow2.get_controller() == null and flow2.has_continue(), "leave_floor (alias) from IN_NODE -> TITLE, save kept")
	saved = store2.load_state(config).get_run_dict()
	_check(int(saved.get("node_index", -1)) == 0 and int(saved.get("column", -1)) == 0 and (saved.get("pending_reward", [1]) as Array).is_empty(), "store: node 0 chosen, no offer")
	flow2.continue_requested()
	var c4: RunController = flow2.get_controller()
	_check(c4 != null and c4 != c3 and flow2.get_phase() == GameFlow.Phase.IN_NODE and not c4.hold_intro and not flow2.is_reward_blocking(), "continue (node chosen, no offer) respawns the match, intro not held")
	_check(c4.get_state().get_match_index() == 0 and is_equal_approx(c4.get_state().get_carried_hp(), 100.0) and _deck_size(c4) == pre_n, "respawned with hp 100, deck %d" % pre_n)
	ok = await _wait_phase(c4, RunState.Phase.PLAYING)
	_check(ok, "respawned match PLAYING")
	_kill_boss(c4)
	ok = await _wait_phase(c4, RunState.Phase.WON)
	_check(ok and flow2.get_pending_reward().size() == 3 and flow2.get_pending_reward_kind() == "battle", "battle won -> offer")
	# remove spends the token
	_check(flow2.get_removal_tokens() == 1, "1 removal token before the remove")
	flow2.reward_remove_requested(99)
	_check(flow2.get_pending_reward().size() == 3 and flow2.get_removal_tokens() == 1, "remove out of range refused, token kept")
	flow2.reward_remove_requested(0)
	_check(flow2.get_run().deck_ids.size() == pre_n - 1 and flow2.get_removal_tokens() == 0 and flow2.get_pending_reward().is_empty(), "remove: deck %d, token spent (0 left), offer cleared" % (pre_n - 1))
	_check(flow2.get_phase() == GameFlow.Phase.MAP and flow2.get_current_column() == 1, "after the remove -> MAP column 1")
	saved = store2.load_state(config).get_run_dict()
	_check(int(saved.get("removal_tokens", -1)) == 0 and (saved.get("deck", []) as Array).size() == pre_n - 1, "store: 0 tokens, deck %d" % (pre_n - 1))
	var deck_n: int = pre_n - 1
	# treasure: free offer, no fight; resume with the pending offer
	var treasure_hp: float = flow2.get_run().hp
	_check(flow2.choose_node(0), "choose the treasure")
	_check(flow2.get_phase() == GameFlow.Phase.MAP and flow2.get_controller() == null, "treasure: no fight, still MAP")
	var toffer: Array[String] = flow2.get_pending_reward()
	_check(toffer.size() == 3 and flow2.get_pending_reward_kind() == "treasure" and flow2.get_pending_reward_info().get("free") == true, "treasure offer of 3, free")
	_check(flow2.get_run().node_index == 0 and flow2.get_current_column() == 1 and flow2.get_cleared_nodes().size() == 1, "treasure not completed before the pick")
	saved = store2.load_state(config).get_run_dict()
	_check((saved.get("pending_reward", []) as Array).size() == 3 and int(saved.get("node_index", -1)) == 0, "store: treasure chosen with its offer")
	await _drop_main(main2)
	var main2b: Node = await _new_main(store2)
	var flow2b: GameFlow = main2b.get_node("GameFlow") as GameFlow
	flow2b.continue_requested()
	_check(flow2b.get_phase() == GameFlow.Phase.MAP and flow2b.get_controller() == null, "resume with a pending offer -> MAP")
	_check(flow2b.get_pending_reward() == toffer and flow2b.get_pending_reward_kind() == "treasure", "pending treasure offer exposed again")
	flow2b.reward_remove_requested(0)
	_check(flow2b.get_pending_reward().size() == 3, "remove with 0 tokens refused")
	var tpick: String = toffer[1]
	var after_t: int = deck_n + (0 if RewardRoller.is_upgrade(tpick, flow2b.get_deck_levels()) else 1)
	flow2b.reward_chosen(tpick)
	_check(flow2b.get_run().deck_ids.size() == after_t and flow2b.get_pending_reward().is_empty(), "treasure pick -> deck %d" % after_t)
	_check(flow2b.get_phase() == GameFlow.Phase.MAP and flow2b.get_current_column() == 2 and flow2b.get_cleared_nodes().size() == 2 and str(flow2b.get_cleared_nodes()[1]["kind"]) == "treasure", "treasure completed -> column 2")
	_check(is_equal_approx(flow2b.get_run().hp, treasure_hp), "treasure keeps hp %.1f" % treasure_hp)
	_check(is_equal_approx(flow2b.get_luck(), 2.0 * float(reward_cfg["luck_per_node"])), "luck %.1f after two nodes" % flow2b.get_luck())
	# rest: heal
	flow2b.rest_heal_requested()
	_check(flow2b.get_phase() == GameFlow.Phase.MAP, "rest_heal_requested outside REST ignored")
	_check(flow2b.choose_node(0), "choose the rest")
	_check(flow2b.get_phase() == GameFlow.Phase.REST and flow2b.get_controller() == null, "rest -> REST")
	saved = store2.load_state(config).get_run_dict()
	_check(int(saved.get("node_index", -1)) == 0 and int(saved.get("column", -1)) == 2, "store: rest chosen")
	flow2b.rest_forge_requested(99)
	_check(flow2b.get_phase() == GameFlow.Phase.REST, "forge out of range refused, still REST")
	var hp_before_rest: float = flow2b.get_run().hp
	flow2b.rest_heal_requested()
	var expected_rest: float = minf(hp_before_rest + float(reward_cfg["rest_heal_ratio"]) * 190.0, 190.0)
	_check(is_equal_approx(flow2b.get_run().hp, expected_rest), "rest heal: %.1f -> %.1f" % [hp_before_rest, flow2b.get_run().hp])
	_check(flow2b.get_phase() == GameFlow.Phase.MAP and flow2b.get_current_column() == 3 and str(flow2b.get_cleared_nodes()[2]["kind"]) == "rest", "rest completed -> MAP column 3")
	saved = store2.load_state(config).get_run_dict()
	_check(int(saved.get("column", -1)) == 3 and is_equal_approx(float(saved.get("hp", -1.0)), expected_rest), "store after the rest")
	# miniboss: rarity floor
	var c5: RunController = await _win_node(flow2b, 0)
	_check(c5 != null and flow2b.get_pending_reward_kind() == "miniboss" and str(flow2b.get_pending_reward_info().get("min_rarity", "")) == "rare", "miniboss offer with min_rarity rare")
	var all_rare: bool = flow2b.get_pending_reward().size() == 3
	for id: String in flow2b.get_pending_reward():
		if SkillConfig.RARITIES.find(cards.get_rarity(id)) < SkillConfig.RARITIES.find("rare"):
			all_rare = false
	_check(all_rare, "every miniboss card is rare or better: %s" % str(flow2b.get_pending_reward()))
	flow2b.reward_skipped()
	_check(flow2b.get_phase() == GameFlow.Phase.MAP and flow2b.get_current_column() == 4 and flow2b.get_controller() == null, "skip -> MAP column 4")
	# region boss (Story 031): token, progress, floor +1 with the floor heal, reward, then the WORLD_MAP
	var cleared_before: int = store2.load_state(config).get_cleared_bosses()
	var c6: RunController = await _win_node(flow2b, 0, 20.0)
	# Story 035: a region boss opens FATE first; spare leads to today's boss offer.
	_check(flow2b.get_phase() == GameFlow.Phase.FATE, "region boss won -> FATE")
	flow2b.choose_fate("spare")
	_check(c6 != null and flow2b.get_pending_reward_kind() == "boss" and flow2b.get_pending_reward_info().get("removal_token") == true, "boss offer with the token info")
	_check(flow2b.get_removal_tokens() == 1, "boss granted a removal token (1)")
	_check(not flow2b.get_run().is_run_won() and flow2b.get_run_result() == GameFlow.RunResult.NONE, "a region boss does not win the run")
	_check(flow2b.get_floor() == 1 and not flow2b.get_region_offer().is_empty() and flow2b.get_current_region().is_empty(), "floor 2, next offer open: %s" % str(flow2b.get_region_offer()))
	var boss_end: float = minf(c6.get_last_player_hp() + _view(c6).get_passive_heal(), 190.0)
	var floor_heal: float = minf(boss_end + config.floor_heal_ratio() * 190.0, 190.0) - boss_end
	_check(is_equal_approx(flow2b.get_run().hp, boss_end + floor_heal), "floor heal: %.1f + %.1f = %.1f" % [boss_end, floor_heal, flow2b.get_run().hp])
	var fnotice: Dictionary = flow2b.take_floor_clear_notice()
	_check(int(fnotice.get("floor", -1)) == 1 and int(fnotice.get("floor_number", -1)) == 2 and is_equal_approx(float(fnotice.get("healed", -1.0)), floor_heal), "floor-clear notice %s" % str(fnotice))
	_check(flow2b.take_floor_clear_notice().is_empty(), "floor-clear notice returned once")
	var st_b: ProgressState = store2.load_state(config)
	_check(st_b.get_cleared_bosses() == cleared_before + 1 and st_b.has_region_boss_beaten("ch1") and st_b.get_best_floor() == 2 and st_b.has_run(), "progress: boss counted, ch1 beaten, best floor 2, run saved with the offer")
	var boss_offer: Array[String] = flow2b.get_pending_reward()
	var after_b: int = after_t + (0 if RewardRoller.is_upgrade(boss_offer[0], flow2b.get_deck_levels()) else 1)
	var offer1: Array[String] = flow2b.get_region_offer()
	flow2b.reward_chosen(boss_offer[0])
	_check(flow2b.get_phase() == GameFlow.Phase.WORLD_MAP and flow2b.get_controller() == null and flow2b.get_run_result() == GameFlow.RunResult.NONE, "boss reward -> WORLD_MAP, controller freed")
	_check(flow2b.get_run().deck_ids.size() == after_b and flow2b.get_region_offer() == offer1 and flow2b.get_region_path() == (["ch1"] as Array[String]), "deck %d, floor 2 offer %s" % [after_b, str(offer1)])
	# continue from the v5 save at the floor-2 WORLD_MAP
	flow2b.go_back()
	_check(flow2b.get_phase() == GameFlow.Phase.TITLE and flow2b.has_continue(), "go_back in WORLD_MAP -> TITLE, save kept")
	flow2b.continue_requested()
	_check(flow2b.get_phase() == GameFlow.Phase.WORLD_MAP and flow2b.get_floor() == 1 and flow2b.get_region_offer() == offer1 and flow2b.get_run().deck_ids.size() == after_b, "continue -> floor 2 WORLD_MAP")
	flow2b.choose_region(offer1[0])
	_check(flow2b.get_phase() == GameFlow.Phase.MAP and flow2b.get_current_column() == 0 and flow2b.get_run_map() == config.generate_region_map(offer1[0], 11, 1, store2.load_state(config).get_cleared_bosses()), "floor 2 region %s: its floor-2 map" % offer1[0])
	_check(flow2b.get_cleared_nodes().is_empty() and is_equal_approx(flow2b.get_luck(), 5.0 * float(reward_cfg["luck_per_node"])), "new region: cleared reset, luck carried (%.1f)" % flow2b.get_luck())
	await _drop_main(main2b)

	# --- the final match (Story 031): boss of the last floor -> final map -> win = run won ----------
	var store5: ProgressStore = ProgressStore.memory_store()
	var pre5: RunSession = RunSession.begin(config, hero, 0, 15, _map([[_node("boss", CH1_BOSS)]]), 1)
	pre5.floor = config.world_floors() - 1
	var progress5 := ProgressState.new()
	progress5.set_run(pre5)
	store5.save_state(progress5)
	var main5: Node = await _new_main(store5)
	var flow5: GameFlow = main5.get_node("GameFlow") as GameFlow
	flow5.continue_requested()
	_check(flow5.get_phase() == GameFlow.Phase.MAP and flow5.get_floor() == config.world_floors() - 1 and not flow5.is_final_floor(), "last floor's region boss on the MAP")
	var c7: RunController = await _win_node(flow5, 0)
	flow5.choose_fate("spare")
	var final_match: Dictionary = config.final_match()
	_check(c7 != null and flow5.get_pending_reward_kind() == "boss" and flow5.is_final_floor() and flow5.get_floor() == flow5.get_floor_count(), "last region boss -> final floor, boss offer open")
	# TD-029: the final floor = the `world.final_prelude` columns (a shop) then the final boss column.
	var fmap5: Array[Dictionary] = flow5.get_run_map()
	_check(flow5.get_current_region() == str(final_match["region"]) and fmap5 == config.final_map() and str(fmap5[fmap5.size() - 1]["nodes"][0]["match_id"]) == str(final_match["match_id"]) and flow5.get_region_offer().is_empty(), "final map: prelude + boss %s (%d columns)" % [str(final_match), fmap5.size()])
	_check(flow5.get_run_result() == GameFlow.RunResult.NONE and bool(flow5.take_floor_clear_notice().get("is_final", false)), "not won yet, notice says final")
	flow5.reward_skipped()
	_check(flow5.get_phase() == GameFlow.Phase.MAP and flow5.get_available_nodes().size() == 1, "boss reward -> MAP of the final floor")
	flow5.go_back()
	flow5.continue_requested()
	_check(flow5.get_phase() == GameFlow.Phase.MAP and flow5.is_final_floor() and flow5.get_available_nodes().size() == 1, "continue -> the final floor's MAP")
	while flow5.get_current_column() < fmap5.size() - 1 and flow5.choose_node(0) and flow5.get_phase() == GameFlow.Phase.SHOP:
		flow5.shop_leave()
	_check(flow5.get_current_column() == fmap5.size() - 1 and str(flow5.get_available_nodes()[0]["kind"]) == "boss", "past the prelude: the final boss column")
	var c8: RunController = await _win_node(flow5, 0)
	_check(c8 != null and flow5.get_run_result() == GameFlow.RunResult.WON and flow5.get_phase() == GameFlow.Phase.ENDING and flow5.get_pending_reward().is_empty(), "final match won -> RUN WON at once (no offer), ENDING (Story 035)")
	var after_win: ProgressState = store5.load_state(config)
	_check(not after_win.has_run() and after_win.get_best_floor() == config.world_floors() + 1, "store: run dropped, best floor %d" % after_win.get_best_floor())
	_check(flow5.get_run() != null, "run object kept for the RUN THẮNG screen")
	flow5.leave_run()
	_check(flow5.get_phase() == GameFlow.Phase.TITLE and not flow5.has_continue() and flow5.get_run() == null, "leave_run after the win -> TITLE, no continue")
	await _drop_main(main5)

	# --- rest: forge --------------------------------------------------------------------------------
	var store3: ProgressStore = ProgressStore.memory_store()
	var pre3: RunSession = RunSession.begin(config, hero, 0, 13, _map([[_node("rest")], [_node("boss", CH1_BOSS)]]), 1)
	var progress3 := ProgressState.new()
	progress3.set_run(pre3)
	store3.save_state(progress3)
	var main3: Node = await _new_main(store3)
	var flow3: GameFlow = main3.get_node("GameFlow") as GameFlow
	flow3.continue_requested()
	_check(flow3.choose_node(0) and flow3.get_phase() == GameFlow.Phase.REST, "forge run: REST open")
	var forge_id: String = flow3.get_run_deck_entries()[0]["id"]
	flow3.rest_forge_requested(0)
	_check(int(flow3.get_run().deck[0]["level"]) == 1 + int(reward_cfg["rest_forge_levels"]) and flow3.get_deck_levels()[forge_id] == 2, "forge: card 0 at level 2")
	_check(flow3.get_phase() == GameFlow.Phase.MAP and flow3.get_current_column() == 1 and flow3.get_run().hp < 0.0, "forge -> MAP column 1, hp still full")
	_check(int(store3.load_state(config).get_run_dict()["deck"][0]["level"]) == 2, "store keeps the forged level")
	# leave from REST keeps the save
	var pre3b: RunSession = RunSession.begin(config, hero, 0, 14, _map([[_node("rest")], [_node("boss", CH1_BOSS)]]), 1)
	flow3.get_progress().set_run(pre3b)
	store3.save_state(flow3.get_progress())
	flow3.show_title()
	flow3.continue_requested()
	flow3.choose_node(0)
	flow3.go_back()
	_check(flow3.get_phase() == GameFlow.Phase.TITLE and flow3.has_continue(), "go_back in REST -> TITLE, save kept")
	flow3.continue_requested()
	_check(flow3.get_phase() == GameFlow.Phase.REST, "continue with a rest chosen -> REST")
	await _drop_main(main3)

	# --- pre-v5 save -> restart notice (Story 031) -------------------------------------------------
	# Dropped with Story 031: the Story 022 checks that a v3 save offered Continue "in ch2", restarted
	# that chapter at column 0 of a 7-column map and kept a v4 run. Every pre-v5 run now restarts as a
	# fresh WORLD run for the saved character (WORLD_MAP, floor 1).
	var v3: String = JSON.stringify({
		"version": 3, "locale": "vi", "cleared_chapters": ["ch1"], "seen_cards": [],
		"run_in_progress": {"version": 3, "character": HERO, "chapter": "ch2", "floor": "f1", "match_index": 1,
			"hp": 50, "deck": [{"id": "kiem_khi", "level": 1}], "run_seed": 9, "elapsed": 12, "pending_reward": [], "revives": 0},
	})
	_check(bool(ProgressState.from_json(v3, config).get_run_dict().get("needs_restart", false)), "v3 run loads as needs_restart")
	var v4: String = JSON.stringify({
		"version": 4, "locale": "vi", "cleared_chapters": ["ch1"], "seen_cards": [], "cleared_bosses": 1,
		"run_in_progress": {"version": 4, "character": HERO, "chapter": "ch2",
			"map": [{"index": 0, "tier": 0, "nodes": [{"kind": "battle", "match_id": "skeleton"}]}], "column": 0, "node_index": -1,
			"cleared_nodes": [], "hp": 50, "deck": [{"id": "kiem_khi", "level": 1}], "run_seed": 9, "elapsed": 12,
			"pending_reward": [], "revives": 0, "removal_tokens": 1, "cleared_bosses_this_run": 0},
	})
	var store4: ProgressStore = ProgressStore.memory_store()
	var old_state: ProgressState = ProgressState.from_json(v4, config)
	_check(old_state.has_run() and bool(old_state.get_run_dict().get("needs_restart", false)), "v4 run loads as needs_restart")
	store4.save_state(old_state)
	var main4: Node = await _new_main(store4)
	var flow4: GameFlow = main4.get_node("GameFlow") as GameFlow
	_check(flow4.has_continue(), "v4: continue offered")
	flow4.continue_requested()
	var notice: String = flow4.take_restart_notice()
	_check(notice == TranslationServer.translate("run.restart.old_save") and not notice.is_empty() and notice != "run.restart.old_save", "restart notice = '%s'" % notice)
	_check(flow4.take_restart_notice().is_empty(), "notice returned once")
	_check(flow4.get_phase() == GameFlow.Phase.WORLD_MAP and flow4.get_run() != null and flow4.get_floor() == 0 and not flow4.get_region_offer().is_empty() and flow4.get_run_map().is_empty(), "fresh world run at the floor 1 WORLD_MAP")
	_check(flow4.get_character_id() == HERO and flow4.get_run().deck_ids.size() == starter and flow4.get_run().hp < 0.0, "restart: saved character, starter deck, full hp")
	var st4: ProgressState = store4.load_state(config)
	_check(st4.has_region_boss_beaten("ch1") and st4.get_cleared_bosses() == 1 and int(st4.get_run_dict().get("version", 0)) == RunSession.SAVE_VERSION and not bool(st4.get_run_dict().get("needs_restart", false)), "regions and bosses kept, v5 run saved")
	await _drop_main(main4)

	print("FAILS=", _fails)
	quit(_fails)

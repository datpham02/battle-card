extends SceneTree
## Story 033 wave 2 flow test (production/epics/kaiten-duel/story-033-gold-shop-events.md Parts B, C):
## GameFlow SHOP and EVENT phases on a hand-built region map. Shop: enter -> SHOP, buy a card and a
## relic, both services once, refusals (sold / used / no gold), save + resume inside the shop keeps the
## sold / used flags, leave -> MAP with the node completed and no gold. Events: a disabled choice is
## refused, a choice applies its effects, resume after the choice shows the same result (no re-roll),
## loi_the's run modifier lasts 2 matches (the tran_thach extra fight counts) and reaches
## match_params["run_modifiers"] and the player's step cooldown (x1.2); tran_thach starts its extra
## danger match without advancing the column and a win gives relic + 25 gold and returns to EVENT.
## Curse rules of RunSession (min deck size, removal, forge). Last gold gain survives a resume.
## Headless: godot --headless --path . -s res://tests/integration/run/shop_event_flow_test.gd
## Prints PASS/FAIL lines and FAILS=n; exits with that count.

const MAIN_SCENE: String = "res://src/main.tscn"
const MAX_FRAMES: int = 4000
const HERO: String = "phap_su"
const CURSE_PLAIN: String = "ganh_nang"
## Boundary values of the test (the exact numbers are the point).
const RICH_GOLD: int = 500
const POOR_GOLD: int = 40
const HURT_HP: float = 100.0
const LOI_THE_MATCHES: int = 2
const LOI_THE_MUL: float = 1.2
const FIGHT_PRIZE_GOLD: int = 25

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _wait_phase(controller: RunController, phase: int) -> bool:
	for _i: int in MAX_FRAMES:
		if controller == null or not is_instance_valid(controller) or controller.get_state() == null:
			return false
		if controller.get_state().get_phase() == phase:
			return true
		await process_frame
	return false


func _wait_flow(flow: GameFlow, phase: int) -> bool:
	for _i: int in MAX_FRAMES:
		if flow.get_phase() == phase:
			return true
		await process_frame
	return false


func _view(controller: RunController) -> CombatView:
	return controller.get_battle().get_node(RunController.COMBAT_VIEW_NODE) as CombatView


func _step_ratio(controller: RunController) -> float:
	var view: CombatView = _view(controller)
	return float(view.get("_player_step_cooldown")) / maxf(float(view.get("_base_step_cooldown")), 0.0001)


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


func _resume(flow: GameFlow) -> void:
	if flow.get_phase() == GameFlow.Phase.IN_NODE:
		flow.leave_run_keep_save()
	else:
		flow.go_back()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.has_continue(), "leave (go_back outside a match) -> TITLE, save kept")
	flow.continue_requested()


# Plays the chosen match node to WON (controller of the node returned; null on failure).
func _play_to_win(flow: GameFlow) -> RunController:
	var c: RunController = flow.get_controller()
	if c == null:
		_check(false, "a controller is playing")
		return null
	_check(await _wait_phase(c, RunState.Phase.PLAYING), "match PLAYING")
	return c


func _kill(c: RunController) -> void:
	_view(c).get_state().damage(CombatState.Side.ENEMY, 999999.0)


func _run() -> void:
	TranslationServer.set_locale("vi")
	var store: ProgressStore = ProgressStore.memory_store()
	var main: Node = await _new_main(store)
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	var config: ChaptersConfig = flow.get_config()
	var cards: SkillConfig = flow.get_cards()
	_check(GameFlow.Phase.SHOP != GameFlow.Phase.MAP and GameFlow.Phase.EVENT != GameFlow.Phase.SHOP and GameFlow.Phase.IN_FLOOR == GameFlow.Phase.IN_NODE, "Phase SHOP / EVENT are new values")
	flow.start_requested()
	flow.character_chosen(HERO)
	var region: String = flow.get_region_offer()[0]
	flow.choose_region(region)
	var run: RunSession = flow.get_run()
	var gen: Array[Dictionary] = flow.get_run_map()
	var battle_id: String = str(gen[0]["nodes"][0]["match_id"])
	var boss_id: String = str(gen[gen.size() - 1]["nodes"][0]["match_id"])
	run.map = _map([
		[_node("shop")], [_node("event")], [_node("event")], [_node("event")],
		[_node("battle", battle_id)], [_node("battle", battle_id)], [_node("boss", boss_id)],
	])
	_check(flow.get_shop().is_empty() and flow.get_event_view().is_empty() and flow.get_event_result().is_empty(), "shop / event getters empty on the MAP")
	_check(not bool(flow.shop_buy("card", "x").get("ok", true)) and not bool(flow.event_choose(0).get("ok", true)), "shop_buy / event_choose refused on the MAP")

	# --- SHOP --------------------------------------------------------------------------------------
	run.gold = RICH_GOLD
	_check(flow.choose_node(0), "choose the shop node")
	_check(flow.get_phase() == GameFlow.Phase.SHOP and flow.get_controller() == null, "shop node -> SHOP, no controller")
	var shop: Dictionary = flow.get_shop()
	var shop_cards: Array = shop.get("cards", [])
	var shop_relics: Array = shop.get("relics", [])
	_check(shop_cards.size() >= 2 and shop_relics.size() >= 1, "stock: %d cards, %d relics" % [shop_cards.size(), shop_relics.size()])
	var expected: Dictionary = ShopLogic.build(run.run_seed, run.floor, 0, 0, run.luck(flow.get_reward_config()), [], cards,
		flow.get_reward_config(), null, EconomyConfig.shared(), run.locked)
	_check(expected.get("cards") == shop.get("cards") and expected.get("relics") == shop.get("relics"), "stock = ShopLogic.build seeded by run + floor + column + node")
	var saved: Dictionary = store.load_state(config).get_run_dict()
	_check(int(saved.get("node_index", -1)) == 0 and not (saved.get("shop_state", {}) as Dictionary).is_empty(), "the open shop is saved")
	var card0: Dictionary = shop_cards[0]
	var deck_before: Array[Dictionary] = run.deck_entries()
	var gold_before: int = run.gold
	var bought: Dictionary = flow.shop_buy(ShopLogic.KIND_CARD, str(card0["id"]))
	_check(bool(bought.get("ok", false)) and run.gold == gold_before - int(card0["price"]), "buy card %s for %d" % [str(card0["id"]), int(card0["price"])])
	var grew: bool = run.deck.size() == deck_before.size() + 1
	_check(grew or (bool(bought.get("upgraded", false)) and run.deck.size() == deck_before.size()), "the card joined (or upgraded a copy)")
	_check(bool(((flow.get_shop()["cards"] as Array)[0] as Dictionary)["sold"]), "the card shows sold")
	_check(str(flow.shop_buy(ShopLogic.KIND_CARD, str(card0["id"])).get("reason", "")) == ShopLogic.REASON_SOLD, "buying it again: refused (sold)")
	var relic0: Dictionary = shop_relics[0]
	gold_before = run.gold
	_check(bool(flow.shop_buy(ShopLogic.KIND_RELIC, str(relic0["id"])).get("ok", false)) and run.has_relic(str(relic0["id"])) and run.gold == gold_before - int(relic0["price"]), "buy relic %s" % str(relic0["id"]))
	run.hp = HURT_HP
	var max_hp: float = float(flow.get_characters().get_character(HERO).get("max_hp", 1.0))
	var heal_price: int = int((shop["services"] as Dictionary)["heal"]["price"])
	gold_before = run.gold
	var healed: Dictionary = flow.shop_use_service(ShopLogic.SERVICE_HEAL)
	var heal_ratio: float = float(shop.get("heal_ratio", 0.0))
	_check(bool(healed.get("ok", false)) and is_equal_approx(run.hp, minf(HURT_HP + heal_ratio * max_hp, max_hp)) and run.gold == gold_before - heal_price, "heal service: +%.0f HP for %d" % [heal_ratio * max_hp, heal_price])
	_check(str(flow.shop_use_service(ShopLogic.SERVICE_HEAL).get("reason", "")) == ShopLogic.REASON_USED, "heal again: refused (used)")
	var rich: int = run.gold
	run.gold = 0
	_check(str(flow.shop_buy(ShopLogic.KIND_CARD, str((shop_cards[1] as Dictionary)["id"])).get("reason", "")) == ShopLogic.REASON_NO_GOLD and run.gold == 0, "no gold: refused, nothing spent")
	run.gold = rich
	flow.get_run().add_card(CURSE_PLAIN, 1)
	flow._save_run()
	# save + resume inside the shop
	await _resume(flow)
	run = flow.get_run()
	shop = flow.get_shop()
	_check(flow.get_phase() == GameFlow.Phase.SHOP and run.gold == rich, "resume -> SHOP with the same gold %d" % rich)
	_check(bool((shop["cards"] as Array)[0]["sold"]) and bool((shop["relics"] as Array)[0]["sold"]) and bool((shop["services"] as Dictionary)["heal"]["used"]) and not bool((shop["cards"] as Array)[1]["sold"]), "resume keeps sold / used flags")
	var curse_index: int = -1
	for i: int in run.deck.size():
		if str(run.deck[i]["id"]) == CURSE_PLAIN:
			curse_index = i
	var removed: Dictionary = flow.shop_use_service(ShopLogic.SERVICE_REMOVE_CARD, curse_index)
	_check(bool(removed.get("ok", false)) and str(removed.get("removed_id", "")) == CURSE_PLAIN and not run.deck_ids.has(CURSE_PLAIN), "remove service takes the curse")
	_check(str(flow.shop_use_service(ShopLogic.SERVICE_REMOVE_CARD, 0).get("reason", "")) == ShopLogic.REASON_USED, "remove again: refused (used)")
	gold_before = run.gold
	flow.shop_leave()
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.get_current_column() == 1 and run.gold == gold_before, "shop_leave -> MAP, column 1, no gold")
	var cleared: Array = flow.get_cleared_nodes()
	_check(not cleared.is_empty() and str((cleared[cleared.size() - 1] as Dictionary)["kind"]) == "shop" and run.shop_state.is_empty() and not run.has_pending_reward(), "shop node completed, stock dropped, no reward")

	# --- EVENT: song_bac (disabled choice, effects, resume does not re-roll) -----------------------
	run.gold = POOR_GOLD
	flow.set("_dev_event_id", "song_bac")
	_check(flow.choose_node(0) and flow.get_phase() == GameFlow.Phase.EVENT, "event node -> EVENT")
	var ev: Dictionary = flow.get_event_view()
	var choices: Array = ev.get("choices", [])
	_check(str(ev.get("id", "")) == "song_bac" and choices.size() == 3 and int(ev.get("chosen", 0)) == -1, "event view: song_bac, 3 choices, none chosen")
	_check(bool(choices[0]["enabled"]) and not bool(choices[1]["enabled"]) and not str(choices[1]["reason_key"]).is_empty(), "bet 60 greyed out with %d gold (%s)" % [POOR_GOLD, str(choices[1]["reason_key"])])
	_check(not bool(flow.event_choose(1).get("ok", true)) and run.gold == POOR_GOLD and flow.get_event_result().is_empty(), "the disabled choice is refused, nothing changes")
	var res: Dictionary = flow.event_choose(0)
	var gold_after: int = run.gold
	_check(bool(res.get("ok", false)) and (gold_after == POOR_GOLD + 75 or gold_after == POOR_GOLD - 30), "bet 30 applied: gold %d -> %d" % [POOR_GOLD, gold_after])
	_check(not bool(flow.event_choose(0).get("ok", true)) and run.gold == gold_after, "a second choice is refused")
	var outcome: int = int(flow.get_event_result().get("outcome_index", -1))
	await _resume(flow)
	run = flow.get_run()
	var back: Dictionary = flow.get_event_result()
	_check(flow.get_phase() == GameFlow.Phase.EVENT and int(back.get("outcome_index", -2)) == outcome and str(back.get("text_key", "")) == str(res.get("text_key", "?")), "resume -> EVENT with the same result (outcome %d)" % outcome)
	_check(run.gold == gold_after and int(flow.get_event_view().get("chosen", -1)) == 0, "resume does not re-roll nor re-apply")
	_check((run.event_state.get("used", []) as Array).has("song_bac"), "song_bac recorded as seen")
	flow.event_leave()
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.get_current_column() == 2 and (run.event_state.get("used", []) as Array).has("song_bac") and not run.event_state.has("event_id"), "event_leave -> MAP, column 2, seen list kept")

	# --- EVENT: loi_the (run modifier) --------------------------------------------------------------
	flow.set("_dev_event_id", "loi_the")
	var tokens: int = run.removal_tokens
	gold_before = run.gold
	flow.choose_node(0)
	_check(bool(flow.event_choose(0).get("ok", false)), "loi_the: swear")
	_check(run.has_run_modifier("slow_step") and int(run.run_modifiers[0]["matches_left"]) == LOI_THE_MATCHES and run.removal_tokens == tokens + 1 and run.gold == gold_before + 30, "slow_step x%d matches, +1 token, +30 gold" % LOI_THE_MATCHES)
	_check(flow.get_run_modifier_overrides().has("step_cooldown"), "overrides carry step_cooldown")
	flow.event_leave()

	# --- EVENT: tran_thach (extra fight without advancing) ------------------------------------------
	flow.set("_dev_event_id", "tran_thach")
	flow.choose_node(0)
	var column: int = flow.get_current_column()
	var relics_before: int = run.relic_ids().size()
	gold_before = run.gold
	var fight: Dictionary = flow.event_choose(0)
	_check(bool(fight.get("ok", false)) and not (fight.get("pending_fight", {}) as Dictionary).is_empty(), "tran_thach: the challenge is accepted")
	var c: RunController = flow.get_controller()
	_check(flow.get_phase() == GameFlow.Phase.IN_NODE and c != null and flow.get_current_column() == column and run.node_index == 0, "extra match starts, column %d not advanced" % column)
	var danger_ids: Array = []
	var pools: Dictionary = config.region_spec(region, run.floor).get("pools", {})
	for tier: Variant in (pools.get("danger", {}) as Dictionary).keys():
		danger_ids.append_array(pools["danger"][tier] as Array)
	_check(c != null and danger_ids.has(str(c.get_config().matches[0]["id"])), "the extra match is a danger match of the region: %s" % (str(c.get_config().matches[0]["id"]) if c != null else "-"))
	saved = store.load_state(config).get_run_dict()
	_check(bool((saved.get("event_state", {}) as Dictionary).get("fight_active", false)), "the running fight is saved")
	var fight_match: String = str(c.get_config().matches[0]["id"]) if c != null else ""
	await _resume(flow)
	run = flow.get_run()
	c = flow.get_controller()
	_check(flow.get_phase() == GameFlow.Phase.IN_NODE and c != null and str(c.get_config().matches[0]["id"]) == fight_match and flow.get_current_column() == column, "resume mid-fight respawns the same extra match %s" % fight_match)
	c = await _play_to_win(flow)
	if c != null:
		_check(_view(c).match_params.has("run_modifiers"), "the extra match gets match_params.run_modifiers")
		_check(is_equal_approx(_step_ratio(c), LOI_THE_MUL * float(_view(c).call("_step_mult", _view(c).match_params.get("character", {})))), "step cooldown x%.1f in the extra match" % LOI_THE_MUL)
		_kill(c)
	_check(await _wait_flow(flow, GameFlow.Phase.EVENT), "won -> back to EVENT")
	var won: Dictionary = flow.get_event_result()
	_check(flow.get_controller() == null and flow.get_current_column() == column and bool(won.get("fight_won", false)), "fight result shown, still column %d" % column)
	_check(run.relic_ids().size() == relics_before + 1 and run.gold == gold_before + FIGHT_PRIZE_GOLD, "prize: 1 relic + %d gold" % FIGHT_PRIZE_GOLD)
	_check(int(run.run_modifiers[0]["matches_left"]) == LOI_THE_MATCHES - 1, "the extra match ticked the run modifier (1 left)")
	flow.event_leave()
	_check(flow.get_phase() == GameFlow.Phase.MAP and flow.get_current_column() == column + 1, "event_leave -> MAP, next column")

	# --- battles: modifier lasts its 2nd match, then gone; last gold gain survives a resume ----------
	_check(flow.choose_node(0), "battle with slow_step left")
	c = await _play_to_win(flow)
	var slow_ratio: float = 0.0
	if c != null:
		slow_ratio = _step_ratio(c)
		_check(_view(c).match_params.has("run_modifiers"), "battle gets match_params.run_modifiers")
		_kill(c)
		_check(await _wait_phase(c, RunState.Phase.WON), "battle WON")
	_check(run.run_modifiers.is_empty(), "slow_step expired after 2 matches")
	var gain: int = flow.get_last_gold_gain()
	_check(gain > 0 and run.has_pending_reward(), "battle dropped %d gold, reward open" % gain)
	await _resume(flow)
	run = flow.get_run()
	_check(flow.get_last_gold_gain() == gain and run.has_pending_reward(), "resume keeps the +%d gold readout" % gain)
	flow.reward_skipped()
	_check(flow.choose_node(0), "battle without modifier")
	c = await _play_to_win(flow)
	if c != null:
		_check(not _view(c).match_params.has("run_modifiers"), "no run_modifiers once expired")
		_check(slow_ratio > 0.0 and is_equal_approx(slow_ratio / _step_ratio(c), LOI_THE_MUL), "step cooldown ratio slowed / normal = %.2f" % (slow_ratio / maxf(_step_ratio(c), 0.0001)))
	root.remove_child(main)
	main.queue_free()
	await process_frame

	# --- curse rules (RunSession) --------------------------------------------------------------------
	var s := RunSession.new()
	s.cards_config = cards
	for id: String in ["kiem_khi", "chan_phong", "hoa_tran", "bang_phong", CURSE_PLAIN]:
		s.deck.append({"id": id, "level": 1})
	s.removal_tokens = 3
	_check(s.non_curse_count() == 4, "curses do not count: 4 non-curse cards")
	_check(not s.remove_card_at(0, 4) and s.removal_tokens == 3, "a normal card at the minimum (4) cannot go")
	_check(s.remove_card_at(4, 4) and not s.deck_ids.has(CURSE_PLAIN) and s.removal_tokens == 2, "a curse can always go")
	s.deck.append({"id": CURSE_PLAIN, "level": 1})
	_check(not bool(s.rest_forge(4, {}).get("ok", true)) and int(s.deck[4]["level"]) == 1, "a curse cannot be forged")
	_check(bool(s.rest_forge(0, {}).get("ok", false)), "a normal card can be forged")

	print("FAILS=%d" % _fails)
	quit(_fails)

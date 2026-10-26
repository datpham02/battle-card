extends SceneTree
## Story 034 flow test (production/epics/kaiten-duel/story-034-piece-deck.md Parts A, B): GameFlow's piece deck
## on a hand-built region map. PIECE_DECK opens from WORLD_MAP and MAP and returns there, refused elsewhere;
## every match of the run gets match_params["piece_deck"]; the ink row after a battle follows
## `ink_offer_chance` (forced to 1 and 0 here), a treasure always has one; choose_ink applies it and leaves
## the card choice open (the node does not advance); skip_ink_offer, reward_chosen, reward_skipped and
## choose_relic all close it; a resume shows the same ink row; remove_shape spends a token and is refused at
## 0 (reason no_token, rows say so); the shop's remove_shape service costs gold once per shop.
## Headless: godot --headless --path . -s res://tests/integration/run/piece_deck_flow_test.gd
## Prints PASS/FAIL lines and FAILS=n; exits with that count.

const MAIN_SCENE: String = "res://src/main.tscn"
const HERO: String = "phap_su"
const RICH_GOLD: int = 500
const SPAWN_FRAMES: int = 30
## Shape ids of pieces.json used by the checks (the ids ARE the point).
const SMALL: String = "mono"
const MID: String = "bar3"
## Boundary chances: the ink row always / never shows after a battle.
const ALWAYS: float = 1.0
const NEVER: float = 0.0

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _map(columns: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in columns.size():
		out.append({"index": i, "tier": 1, "nodes": columns[i]})
	return out


func _node(kind: String, match_id: String = "") -> Dictionary:
	return {"kind": kind, "match_id": match_id}


func _set_chance(chance: float) -> void:
	RunSession._shared_piece_config = PieceDeckConfig.from_dictionary({"ink_offer_chance": chance})


# Chooses the first node of the current column (a battle) and wins it on the spot (GameFlow's dev helper,
# the same completion path as a real win). Returns the controller that played it.
func _win_battle(flow: GameFlow) -> RunController:
	flow.choose_node(0)
	var c: RunController = flow.get_controller()
	for _i: int in SPAWN_FRAMES:
		await process_frame
	flow._dev_win_current_match(true)
	return c


func _run() -> void:
	TranslationServer.set_locale("vi")
	var store: ProgressStore = ProgressStore.memory_store()
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(store)
	root.add_child(main)
	await process_frame
	var lib: PieceLibrary = flow.get_piece_library()
	var shipped: PieceDeckConfig = RunSession.piece_config()
	_check(GameFlow.Phase.PIECE_DECK != GameFlow.Phase.MAP and GameFlow.Phase.IN_FLOOR == GameFlow.Phase.IN_NODE, "Phase.PIECE_DECK is a new value")

	# --- open / close from WORLD_MAP and MAP, refused elsewhere
	flow.open_piece_deck()
	_check(flow.get_phase() == GameFlow.Phase.TITLE, "open_piece_deck refused on the TITLE")
	flow.start_requested()
	flow.character_chosen(HERO)
	_check(flow.get_phase() == GameFlow.Phase.WORLD_MAP, "a new run shows the WORLD_MAP")
	flow.open_piece_deck()
	_check(flow.get_phase() == GameFlow.Phase.PIECE_DECK, "open from WORLD_MAP -> PIECE_DECK")
	flow.close_piece_deck()
	_check(flow.get_phase() == GameFlow.Phase.WORLD_MAP, "close -> back to WORLD_MAP")
	flow.choose_region(flow.get_region_offer()[0])
	var run: RunSession = flow.get_run()
	_check(flow.get_piece_deck() == PieceDeck.initial(lib) and flow.get_shape_removals() == shipped.shape_removals_start, "the run starts with the initial deck and token count")
	flow.open_piece_deck()
	_check(flow.get_phase() == GameFlow.Phase.PIECE_DECK, "open from MAP -> PIECE_DECK")
	flow.go_back()
	_check(flow.get_phase() == GameFlow.Phase.MAP, "back on PIECE_DECK -> MAP")
	var gen: Array[Dictionary] = flow.get_run_map()
	var battle_id: String = str(gen[0]["nodes"][0]["match_id"])
	var boss_id: String = str(gen[gen.size() - 1]["nodes"][0]["match_id"])
	run.map = _map([
		[_node("battle", battle_id)], [_node("battle", battle_id)], [_node("treasure")], [_node("treasure")],
		[_node("shop")], [_node("boss", boss_id)],
	])

	# --- remove_shape with tokens, rows
	run.shape_removals = 1
	_check(flow.remove_shape(SMALL) and flow.get_shape_removals() == 0, "remove_shape spends a token")
	_check(not PieceDeck.has_shape(flow.get_piece_deck(), SMALL), "the shape is gone from the deck")
	var refused: Dictionary = flow.can_remove_shape(MID)
	_check(not bool(refused["ok"]) and str(refused["reason"]) == RunSession.REASON_NO_TOKEN, "0 tokens: can_remove_shape says no_token")
	_check(not flow.remove_shape(MID) and PieceDeck.has_shape(flow.get_piece_deck(), MID), "0 tokens: remove_shape refused, nothing changes")
	var rows: Array[Dictionary] = flow.get_piece_deck_rows()
	var total: float = 0.0
	var mono_row: Dictionary = {}
	for row: Dictionary in rows:
		total += float(row["percent"])
		if str(row["id"]) == SMALL:
			mono_row = row
	_check(rows.size() == lib.base_shape_ids().size() - flow.get_run().locked_ids("piece").size(), "rows: one per default shape that is not locked (%d)" % rows.size())
	_check(bool(mono_row.get("removed", false)) and int(mono_row.get("dots", -1)) == 0 and float(mono_row.get("percent", -1.0)) == 0.0, "removed row: removed, no dots, 0 %")
	_check(is_equal_approx(total, 100.0), "drop percents sum to 100 (%.3f)" % total)
	_check(str(rows[1]["reason"]) == RunSession.REASON_NO_TOKEN and not bool(rows[1]["can_remove"]), "rows carry the no_token reason")
	_check(not (rows[0]["cells"] as Array).is_empty() and not str(rows[0]["name"]).is_empty(), "rows have cells and a name")

	# --- battle with chance 1: the match gets the deck, the ink row opens; choose_ink keeps the card choice open
	_set_chance(ALWAYS)
	var c: RunController = await _win_battle(flow)
	_check(c != null and c.piece_deck == run.piece_deck, "the match's controller carries the run's piece deck")
	var battle: Node = c.get_battle() if c != null else null
	var view: CombatView = battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView if battle != null else null
	_check(view != null and view.match_params.get("piece_deck") == run.piece_deck, "match_params[\"piece_deck\"] reaches CombatView")
	_check(flow.get_pending_reward().size() > 0 and flow.has_ink_offer(), "won battle at chance 1: card row and ink row open")
	var offer: Array[String] = flow.get_ink_offer()
	_check(offer.size() == shipped.ink_offer_count, "ink row has ink_offer_count shapes (%d)" % offer.size())
	var column_before: int = run.column
	var inked: String = offer[0]
	var mult_before: float = PieceDeck.mult_of(run.piece_deck, inked)
	flow.choose_ink(inked)
	_check(not flow.has_ink_offer() and PieceDeck.mult_of(run.piece_deck, inked) > mult_before, "choose_ink applies the ink and closes the row")
	_check(flow.get_pending_reward().size() > 0 and run.column == column_before, "choose_ink keeps the card choice open, the node does not advance")
	var saved: Dictionary = store.load_state(flow.get_config()).get_run_dict()
	_check((saved.get("pending_ink_offer", ["x"]) as Array).is_empty() and PieceDeck.mult_of(saved["piece_deck"], inked) > mult_before, "choose_ink is saved")
	flow.reward_chosen(flow.get_pending_reward()[0])
	_check(flow.get_phase() == GameFlow.Phase.MAP, "the card pick finishes the node")

	# --- battle with chance 0: no ink row
	_set_chance(NEVER)
	await _win_battle(flow)
	_check(flow.get_pending_reward().size() > 0 and not flow.has_ink_offer(), "won battle at chance 0: no ink row")
	flow.reward_skipped()

	# --- treasure: always an ink row; a resume shows the same one; choose_relic closes it
	_check(flow.choose_node(0) and flow.has_ink_offer(), "a treasure always has an ink row (chance 0)")
	var treasure_offer: Array[String] = flow.get_ink_offer()
	flow.go_back()
	_check(flow.get_phase() == GameFlow.Phase.TITLE and flow.has_continue(), "leave keeps the save")
	flow.continue_requested()
	run = flow.get_run()
	_check(flow.get_ink_offer() == treasure_offer, "the resumed treasure shows the same ink row")
	flow.skip_ink_offer()
	_check(not flow.has_ink_offer() and flow.get_pending_reward().size() > 0, "skip_ink_offer closes only the ink row")
	if flow.has_relic_offer():
		flow.choose_relic(flow.get_relic_offer()[0])
	else:
		flow.reward_skipped()
	_check(flow.choose_node(0) and flow.has_ink_offer(), "next treasure: ink row open")
	if flow.has_relic_offer():
		flow.choose_relic(flow.get_relic_offer()[0])
		_check(not flow.has_ink_offer() and not run.has_pending_ink_offer(), "choose_relic closes the ink row")
	else:
		flow.reward_skipped()
		_check(not flow.has_ink_offer(), "reward_skipped closes the ink row")
	_set_chance(shipped.ink_offer_chance)

	# --- shop: remove_shape for gold, once, refused when illegal
	run.gold = RICH_GOLD
	_check(flow.choose_node(0) and flow.get_phase() == GameFlow.Phase.SHOP, "shop node -> SHOP")
	flow.open_piece_deck()
	_check(flow.get_phase() == GameFlow.Phase.SHOP, "open_piece_deck refused in the SHOP")
	var price: int = int(flow.get_shop()["services"][ShopLogic.SERVICE_REMOVE_SHAPE]["price"])
	var bad: Dictionary = flow.shop_use_service(ShopLogic.SERVICE_REMOVE_SHAPE, SMALL)
	_check(not bool(bad["ok"]) and str(bad["reason_key"]) == PieceDeck.REASON_ALREADY_REMOVED and run.gold == RICH_GOLD, "removing a removed shape: refused, no gold")
	var tokens: int = run.shape_removals
	var ok: Dictionary = flow.shop_use_service(ShopLogic.SERVICE_REMOVE_SHAPE, MID)
	_check(bool(ok["ok"]) and run.gold == RICH_GOLD - price and not PieceDeck.has_shape(run.piece_deck, MID) and run.shape_removals == tokens, "remove_shape service: gold, not a token")
	_check(str(flow.shop_use_service(ShopLogic.SERVICE_REMOVE_SHAPE, "bar2")["reason"]) == ShopLogic.REASON_USED, "remove_shape service once per shop")
	flow.shop_leave()

	# --- boss: +shape_removals_per_boss
	tokens = run.shape_removals
	await _win_battle(flow)
	_check(run.shape_removals == tokens + shipped.shape_removals_per_boss, "the region boss grants shape_removals_per_boss")
	_check(not flow.has_ink_offer(), "no ink row after a boss")

	main.queue_free()
	await process_frame
	print("FAILS=%d" % _fails)
	quit(_fails)

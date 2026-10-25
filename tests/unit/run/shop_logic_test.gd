extends SceneTree
## Story 033 Part B/E: ShopLogic (pure). Stock deterministic by seed (3 cards, 2 relics, prices from
## economy.json, never a curse, never an owned relic); cannot buy without gold (nothing changes); buying
## a card the deck owns upgrades it; buying a relic gives has_relic; each service once per shop (heal =
## heal_ratio x max HP clamped, refused at full HP; remove a card without a token, refused at
## min_deck_size); the state survives a JSON save / load. Uses the shipped data files.
## Prints PASS/FAIL lines and FAILS=n; exits 1 on any failure.

const HERO: String = "kiem_si"
const SEED: int = 4242
const MAX_HP: float = 300.0
const RICH: int = 1000

var fails: int = 0
var passes: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _new_run() -> RunSession:
	var ch: Dictionary = CharacterConfig.load_from_file().get_character(HERO)
	return RunSession.begin_world(ChaptersConfig.load_from_file(), ch, SEED, 1)


func _build(run_seed: int, floor: int, owned: Array, cards: SkillConfig, reward: Dictionary,
		relics: RelicConfig, economy: EconomyConfig) -> Dictionary:
	return ShopLogic.build(run_seed, floor, 2, 1, 5.0, owned, cards, reward, relics, economy)


func _initialize() -> void:
	var cards: SkillConfig = SkillConfig.load_from_file()
	var reward: Dictionary = RewardRoller.load_config()
	var relics: RelicConfig = RelicConfig.load_from_file()
	var economy: EconomyConfig = EconomyConfig.load_from_file()
	var counts: Dictionary = economy.stock_counts()

	# --- stock: deterministic, sizes, prices
	var a: Dictionary = _build(SEED, 1, [], cards, reward, relics, economy)
	var b: Dictionary = _build(SEED, 1, [], cards, reward, relics, economy)
	_check("same seed -> same stock", a == b, "%s vs %s" % [str(a), str(b)])
	_check("card stock size = economy stock", (a["cards"] as Array).size() == int(counts["cards"]), str(a["cards"]))
	_check("relic stock size = economy stock", (a["relics"] as Array).size() == int(counts["relics"]), str(a["relics"]))
	var prices_ok: bool = true
	for e: Dictionary in a["cards"]:
		prices_ok = prices_ok and int(e["price"]) == economy.price_card(cards.get_rarity(str(e["id"])), 1) and not bool(e["sold"])
	for e: Dictionary in a["relics"]:
		prices_ok = prices_ok and int(e["price"]) == economy.price_relic(str(relics.get_relic(str(e["id"]))["rarity"]), 1)
	prices_ok = prices_ok and int(a["services"]["remove_card"]["price"]) == economy.service_price("remove_card", 1)
	prices_ok = prices_ok and int(a["services"]["heal"]["price"]) == economy.service_price("heal", 1)
	_check("every price comes from economy.json at the floor", prices_ok)
	var differs: bool = false
	var no_curse: bool = true
	var owned: Array = ["an_don", "la_ban", "han_ky"]
	var no_owned: bool = true
	for s: int in 40:
		var other: Dictionary = _build(SEED + 1 + s, 0, owned, cards, reward, relics, economy)
		differs = differs or other["cards"] != a["cards"] or other["relics"] != a["relics"]
		for e: Dictionary in other["cards"]:
			no_curse = no_curse and not cards.is_curse(str(e["id"]))
		for e: Dictionary in other["relics"]:
			no_owned = no_owned and not owned.has(str(e["id"]))
	_check("other seeds give other stock", differs)
	_check("a curse card is never in stock (40 seeds)", no_curse)
	_check("an owned relic is never in stock (40 seeds)", no_owned)

	# --- cannot buy without gold
	var run: RunSession = _new_run()
	var state: Dictionary = _build(SEED, 1, [], cards, reward, relics, economy)
	var card_id: String = str(state["cards"][0]["id"])
	run.gold = 0
	var deck_before: Array[Dictionary] = run.deck_entries()
	var poor: Dictionary = ShopLogic.buy(state, run, ShopLogic.KIND_CARD, card_id)
	_check("no gold: buy refused with no_gold", not bool(poor["ok"]) and poor["reason"] == ShopLogic.REASON_NO_GOLD, str(poor))
	_check("no gold: deck, gold and stock unchanged", run.deck_entries() == deck_before and run.gold == 0 and not bool(state["cards"][0]["sold"]))
	_check("can_buy says no_gold under the price", not bool(ShopLogic.can_buy(state, ShopLogic.KIND_CARD, card_id, int(state["cards"][0]["price"]) - 1)["ok"]))

	# --- buying a card the deck owns upgrades it
	run.gold = RICH
	run.deck.append({"id": card_id, "level": 1})
	var size_before: int = run.deck.size()
	var price: int = int(state["cards"][0]["price"])
	var bought: Dictionary = ShopLogic.buy(state, run, ShopLogic.KIND_CARD, card_id)
	_check("buying an owned card upgrades it (no new copy)", bool(bought["ok"]) and bool(bought["upgraded"]) and run.deck.size() == size_before, str(bought))
	_check("buying spends exactly the price", run.gold == RICH - price, str(run.gold))
	_check("a bought card is sold and cannot be bought again",
		bool(state["cards"][0]["sold"]) and ShopLogic.buy(state, run, ShopLogic.KIND_CARD, card_id)["reason"] == ShopLogic.REASON_SOLD)

	# --- buying a relic
	var relic_id: String = str(state["relics"][0]["id"])
	var gold_before: int = run.gold
	var relic_buy: Dictionary = ShopLogic.buy(state, run, ShopLogic.KIND_RELIC, relic_id)
	_check("buying a relic gives has_relic", bool(relic_buy["ok"]) and run.has_relic(relic_id), str(relic_buy))
	_check("relic price spent", run.gold == gold_before - int(state["relics"][0]["price"]))
	_check("remaining stock counts the unsold rows", ShopLogic.remaining_stock(state) == int(counts["cards"]) + int(counts["relics"]) - 2)

	# --- heal service: once, clamped, refused at full HP
	var full: Dictionary = ShopLogic.use_service(state, run, ShopLogic.SERVICE_HEAL, MAX_HP)
	_check("heal refused at full HP, nothing charged", not bool(full["ok"]) and full["reason"] == ShopLogic.REASON_FULL_HP and run.gold == gold_before - int(state["relics"][0]["price"]))
	run.hp = 100.0
	gold_before = run.gold
	var heal: Dictionary = ShopLogic.use_service(state, run, ShopLogic.SERVICE_HEAL, MAX_HP)
	var want_hp: float = minf(100.0 + economy.service_heal_ratio() * MAX_HP, MAX_HP)
	_check("heal restores heal_ratio x max HP", bool(heal["ok"]) and is_equal_approx(run.hp, want_hp), "%s hp=%.1f" % [str(heal), run.hp])
	_check("heal charges its price", run.gold == gold_before - int(state["services"]["heal"]["price"]))
	run.hp = 10.0
	var again: Dictionary = ShopLogic.use_service(state, run, ShopLogic.SERVICE_HEAL, MAX_HP)
	_check("heal only once per shop", not bool(again["ok"]) and again["reason"] == ShopLogic.REASON_USED and is_equal_approx(run.hp, 10.0))
	run.hp = MAX_HP - 5.0
	var clamp_state: Dictionary = _build(SEED, 1, [], cards, reward, relics, economy)
	ShopLogic.use_service(clamp_state, run, ShopLogic.SERVICE_HEAL, MAX_HP)
	_check("heal is clamped to max HP", is_equal_approx(run.hp, MAX_HP), str(run.hp))

	# --- remove service: no token, once, min deck size
	var tokens: int = run.removal_tokens
	var size_now: int = run.deck.size()
	var removed_id: String = str(run.deck[0]["id"])
	var rem: Dictionary = ShopLogic.use_service(state, run, ShopLogic.SERVICE_REMOVE_CARD, 0, cards)
	_check("remove takes the card out without a token", bool(rem["ok"]) and run.deck.size() == size_now - 1 and run.removal_tokens == tokens and rem["removed_id"] == removed_id, str(rem))
	_check("remove only once per shop", ShopLogic.use_service(state, run, ShopLogic.SERVICE_REMOVE_CARD, 0, cards)["reason"] == ShopLogic.REASON_USED)
	var small: RunSession = _new_run()
	small.gold = RICH
	var min_size: int = int(reward["min_deck_size"])
	small.deck_ids = [] as Array[String]
	for i: int in min_size:
		small.deck.append({"id": "kiem_khi", "level": 1})
	var small_state: Dictionary = _build(SEED, 1, [], cards, reward, relics, economy)
	var blocked: Dictionary = ShopLogic.use_service(small_state, small, ShopLogic.SERVICE_REMOVE_CARD, 0, cards)
	_check("remove refused at min_deck_size", not bool(blocked["ok"]) and blocked["reason"] == ShopLogic.REASON_MIN_DECK and small.gold == RICH, str(blocked))
	var curse_ids: Array[String] = cards.curse_ids()
	if not curse_ids.is_empty():
		small.deck.append({"id": curse_ids[0], "level": 1})
		var curse_rem: Dictionary = ShopLogic.use_service(small_state, small, ShopLogic.SERVICE_REMOVE_CARD, small.deck.size() - 1, cards)
		_check("a curse can be removed even at min_deck_size", bool(curse_rem["ok"]) and small.deck.size() == min_size, str(curse_rem))
	_check("bad deck index refused", not bool(ShopLogic.use_service(_build(SEED, 1, [], cards, reward, relics, economy), small, ShopLogic.SERVICE_REMOVE_CARD, 99, cards)["ok"]))

	# --- save / load of the state
	var saved: Dictionary = ShopLogic.from_dict(JSON.parse_string(JSON.stringify(ShopLogic.to_dict(state))))
	_check("state survives a JSON save / load", saved == state, "%s vs %s" % [str(saved), str(state)])
	_check("sold / used flags survive", bool(saved["cards"][0]["sold"]) and bool(saved["services"]["heal"]["used"]) and bool(saved["services"]["remove_card"]["used"]))
	run.shop_state = ShopLogic.to_dict(state)
	var reloaded: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), ChaptersConfig.load_from_file())
	_check("state survives the RunSession save", reloaded != null and ShopLogic.from_dict(reloaded.shop_state) == state)
	_check("from_dict of garbage is {}", ShopLogic.from_dict(42).is_empty() and ShopLogic.from_dict({}).is_empty())

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## Story 033 Part C: curse cards (rarity `curse`: ganh_nang, oan_hon). A curse takes a card-menu slot
## and cannot be chosen (SkillAvailability reason `curse`, CutFlow.choose refuses, timeout still gives
## the default card); Deck.draw_menu keeps >= 1 non-curse card in the menu while the deck holds one;
## oan_hon costs its cards.json `draw_damage` HP when drawn (CombatView, headless); curses never reach
## card_order (the reward / shop pool source) or RewardRoller.roll offers or the boss card list, and
## never level. Expected numbers come from cards.json. Prints PASS/FAIL lines and FAILS=n.

const SEEDS: int = 200
const HANDS_PER_SEED: int = 12
const CURSES: Array[String] = ["ganh_nang", "oan_hon"]

var fails: int = 0
var cards: SkillConfig


func ck(label: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + label + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	cards = SkillConfig.load_from_file()
	_test_data()
	_test_locked_in_menu()
	_test_menu_safety_rule()
	_test_pools_and_boss()
	_test_never_levels()
	await _test_oan_hon_draw_damage()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _test_data() -> void:
	for id: String in CURSES:
		ck("%s defined, implemented, rarity curse" % id, cards.has_skill(id) and bool(cards.get_skill(id)["implemented"]) and cards.get_rarity(id) == SkillConfig.CURSE_RARITY)
		ck("%s is_curse" % id, cards.is_curse(id))
	ck("a normal card is not a curse", not cards.is_curse("kiem_khi") and not cards.is_curse("nope"))
	ck("curse_ids lists both", cards.curse_ids().size() == CURSES.size() and cards.curse_ids().has("ganh_nang") and cards.curse_ids().has("oan_hon"))
	ck("ganh_nang has no draw damage", cards.draw_damage("ganh_nang") == 0.0)
	ck("oan_hon draw_damage > 0 (cards.json)", cards.draw_damage("oan_hon") > 0.0, str(cards.draw_damage("oan_hon")))
	ck("draw_damage of a normal card is 0", cards.draw_damage("kiem_khi") == 0.0)
	ck("default card / deck hold no curse", not cards.is_curse(cards.default_card) and cards.default_deck.all(func(id: String) -> bool: return not cards.is_curse(id)))


func _test_locked_in_menu() -> void:
	var cds := SkillCooldowns.new()
	for id: String in CURSES:
		var check: Dictionary = SkillAvailability.check(cards, cds, id, 9)
		ck("%s unavailable, reason curse" % id, not bool(check["available"]) and str(check["reason"]) == "curse")
	var flow := CutFlow.new(cards, cds)
	var chosen: Array[String] = []
	flow.skill_chosen.connect(func(id: String, _l: Array[String], _c: Array[Vector2i]) -> void: chosen.append(id))
	var hand: Array[String] = ["ganh_nang", "oan_hon", "kiem_khi"]
	flow.open_menu(["I"] as Array[String], [Vector2i(3, 0)] as Array[Vector2i], hand)
	ck("curse occupies a menu slot", flow.get_hand() == hand)
	ck("choosing ganh_nang is refused, menu stays open", not flow.choose("ganh_nang") and flow.is_menu_open() and chosen.is_empty())
	ck("choosing oan_hon is refused", not flow.choose("oan_hon") and flow.is_menu_open())
	ck("the non-curse card is still chosen", flow.choose("kiem_khi") and chosen == (["kiem_khi"] as Array[String]))
	var flow2 := CutFlow.new(cards, cds)
	var timed: Array[String] = []
	flow2.skill_chosen.connect(func(id: String, _l: Array[String], _c: Array[Vector2i]) -> void: timed.append(id))
	flow2.open_menu(["I"] as Array[String], [Vector2i(3, 0)] as Array[Vector2i], ["ganh_nang", "oan_hon"] as Array[String])
	flow2.tick_real(cards.menu_choose_sec + 0.1)
	ck("timeout over an all-curse hand still plays the default card", timed == ([cards.default_card] as Array[String]) and not flow2.is_menu_open(), str(timed))


# A curse-heavy deck: 7 curses and 1 non-curse card; with the plain draw some hands are all curses.
func _heavy_deck() -> Array:
	return ["ganh_nang", "ganh_nang", "ganh_nang", "ganh_nang", "oan_hon", "oan_hon", "oan_hon", cards.default_card]


func _test_menu_safety_rule() -> void:
	var is_curse := Callable(cards, "is_curse")
	var n: int = cards.hand_size
	# Fixture check: the plain deal does produce all-curse hands (so the rule below is exercised).
	var plain_all_curse: int = 0
	var rule_all_curse: int = 0
	var rule_has_curse: int = 0
	var sizes_ok: bool = true
	var non_curse_seen: int = 0
	for s: int in SEEDS:
		var plain := Deck.new(_heavy_deck(), s)
		var ruled := Deck.new(_heavy_deck(), s)
		for h: int in HANDS_PER_SEED:
			if _all_curse(plain.draw(n)):
				plain_all_curse += 1
			var hand: Array[String] = ruled.draw_menu(n, is_curse)
			sizes_ok = sizes_ok and hand.size() == n
			if _all_curse(hand):
				rule_all_curse += 1
			if hand.any(func(id: String) -> bool: return cards.is_curse(id)):
				rule_has_curse += 1
			non_curse_seen += hand.count(cards.default_card)
		sizes_ok = sizes_ok and ruled.size() == _heavy_deck().size()
	ck("fixture: the plain deal gives all-curse hands", plain_all_curse > 0, str(plain_all_curse))
	ck("menu always holds >= 1 non-curse card while the deck has one", rule_all_curse == 0, str(rule_all_curse))
	ck("curses still take menu slots", rule_has_curse == SEEDS * HANDS_PER_SEED)
	ck("hand size and deck size unchanged", sizes_ok)
	ck("the only non-curse card appears at most once per hand", non_curse_seen == SEEDS * HANDS_PER_SEED, str(non_curse_seen))
	var a := Deck.new(_heavy_deck(), 11)
	var b := Deck.new(_heavy_deck(), 11)
	var same: bool = true
	for h: int in HANDS_PER_SEED:
		same = same and a.draw_menu(n, is_curse) == b.draw_menu(n, is_curse)
	ck("menu draw deterministic per seed", same)
	var cursed_only := Deck.new(["ganh_nang", "oan_hon", "ganh_nang", "oan_hon", "ganh_nang"], 3)
	var only: Array[String] = cursed_only.draw_menu(n, is_curse)
	ck("an all-curse deck deals curses (nothing to swap in)", only.size() == n and _all_curse(only))
	var small := Deck.new(["oan_hon", cards.default_card], 5)
	var small_hand: Array[String] = small.draw_menu(n, is_curse)
	ck("deck smaller than the hand: whole deck dealt", small_hand.size() == 2 and small_hand.has("oan_hon") and small_hand.has(cards.default_card))
	var no_rule := Deck.new(_heavy_deck(), 1)
	ck("invalid is_curse callable = plain deal", no_rule.draw_menu(n, Callable()).size() == n)


func _all_curse(hand: Array[String]) -> bool:
	return not hand.is_empty() and hand.all(func(id: String) -> bool: return cards.is_curse(id))


func _test_pools_and_boss() -> void:
	var order_clean: bool = true
	for id: String in cards.card_order:
		order_clean = order_clean and not cards.is_curse(id)
	ck("card_order (reward / shop pool source) holds no curse", order_clean)
	var boss_clean: bool = true
	for id: String in cards.boss_card_order():
		boss_clean = boss_clean and not cards.is_curse(id)
	ck("boss card list holds no curse", boss_clean)
	ck("boss card list still excludes zone cards", not cards.boss_card_order().any(func(id: String) -> bool: return cards.is_zone_card(id)))
	var reward_cfg: Dictionary = RewardRoller.load_config()
	var offered_curse: bool = false
	for s: int in SEEDS:
		for rarity: String in SkillConfig.RARITIES:
			for luck: float in [0.0, 100.0]:
				for id: String in RewardRoller.roll(cards, reward_cfg, s, [], {}, luck, rarity):
					offered_curse = offered_curse or cards.is_curse(id)
	ck("RewardRoller.roll never offers a curse (%d seeds x rarity floors x luck)" % SEEDS, not offered_curse)
	# A cards.json that lists a curse in card_order still keeps it out.
	var listed := SkillConfig.from_dictionary({
		"card_order": ["kiem_khi", "ganh_nang"],
		"cards": {
			"kiem_khi": {"effect": "damage", "rarity": "common", "upgrade": {}, "implemented": true},
			"ganh_nang": {"effect": "damage", "rarity": "curse", "implemented": true},
		},
		"default_deck": ["ganh_nang", "kiem_khi"],
	})
	ck("a curse listed in card_order is dropped from it", listed.card_order == (["kiem_khi"] as Array[String]) and listed.has_skill("ganh_nang"))
	ck("a curse in default_deck is dropped", listed.default_deck == (["kiem_khi"] as Array[String]))


func _test_never_levels() -> void:
	ck("oan_hon resolved at level 3 stays level 1", int(cards.resolved("oan_hon", SkillConfig.MAX_LEVEL)["level"]) == 1)
	ck("curses have no upgrade table", (cards.get_skill("ganh_nang")["upgrade"] as Dictionary).is_empty() and (cards.get_skill("oan_hon")["upgrade"] as Dictionary).is_empty())
	var deck := Deck.new(["ganh_nang"], 1)
	var r: Dictionary = deck.add("ganh_nang", 1)
	ck("adding a curse with max_level 1 adds a copy, never upgrades", not bool(r["upgraded"]) and deck.count_of("ganh_nang") == 2 and deck.level_of("ganh_nang") == 1)


# oan_hon in the drawn menu hand costs draw_damage HP through CombatView (headless view, time frozen).
func _test_oan_hon_draw_damage() -> void:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.match_params = {"deck": ["oan_hon", "oan_hon", cards.default_card, cards.default_card], "player_hp": -1.0}
	v.drops_seed = 7
	v.freeze_time = true
	holder.add_child(v)
	root.add_child(holder)
	await process_frame
	ck("run deck with curses reaches the match deck", v.get_deck().count_of("oan_hon") == 2)
	var hits: Array[float] = []
	v.curse_drawn.connect(func(_id: String, dmg: float) -> void: hits.append(dmg))
	var state: CombatState = v.get_state()
	var before: float = state.player_hp
	var hand: Array[String] = v.get_deck().draw_menu(cards.hand_size, Callable(cards, "is_curse"))
	v._apply_curse_draw_damage(hand)
	var expected: float = cards.draw_damage("oan_hon") * float(hand.count("oan_hon"))
	ck("4-card deck: both oan_hon drawn", hand.count("oan_hon") == 2, str(hand))
	ck("oan_hon costs draw_damage per copy drawn", absf((before - state.player_hp) - expected) < 0.001 and hits.size() == 2, "%s -> %s" % [before, state.player_hp])
	var before2: float = state.player_hp
	v._apply_curse_draw_damage(["ganh_nang", cards.default_card] as Array[String])
	ck("ganh_nang and normal cards cost nothing", state.player_hp == before2)
	var boss_ids: Array[String] = v._boss_card_ids()
	ck("match boss card list holds no curse", not boss_ids.any(func(id: String) -> bool: return cards.is_curse(id)))
	root.remove_child(holder)
	holder.free()

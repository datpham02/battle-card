extends SceneTree

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _csv_rows() -> Dictionary:
	var rows: Dictionary = {}
	var f := FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var r: PackedStringArray = f.get_csv_line()
		if r.size() >= 3:
			rows[r[0]] = [r[1], r[2]]
	return rows


func _initialize() -> void:
	var cards: SkillConfig = SkillConfig.load_from_file()
	# --- cards.json sanity
	check(cards.card_order.size() >= 20, "at least 20 cards (%d)" % cards.card_order.size())
	var rar: Dictionary = {"common": 0, "rare": 0, "epic": 0}
	var rows: Dictionary = _csv_rows()
	var all_ok: bool = true
	var dpc_ok: bool = true
	var up_ok: bool = true
	var no_mult: bool = true
	var pins: int = 0
	var burns: int = 0
	for id: String in cards.card_order:
		var c: Dictionary = cards.get_skill(id)
		rar[c["rarity"]] += 1
		if c["effect"] == "pin":
			pins += 1
		if c["effect"] == "burn":
			burns += 1
		for k: String in ["name_key", "desc_key"]:
			var r: Array = rows.get(c[k], ["", ""])
			if str(r[0]).is_empty() or str(r[1]).is_empty():
				all_ok = false
				print("missing csv ", c[k])
		if typeof(c["damage_per_cell"]) != TYPE_FLOAT:
			dpc_ok = false
		if (c["upgrade"] as Dictionary).is_empty():
			up_ok = false
		if c.has("damage_multiplier") or c.has("class_tags"):
			no_mult = false
	# The Wall cards left the player's cards (quick spec 2026-10-31) and were deleted outright on 2026-11-01
	# (ADR-0001 Phase 1); the cast rhythm spec 2026-11-05 added the common parry card do_kiem, so card_order holds 32.
	check(rar["common"] == 17 and rar["rare"] == 11 and rar["epic"] == 4, "rarity spread (32 player cards, song_kiem epic) %s" % str(rar))
	# Story 027: the boss's default card list never holds a zone card (zones come from its traits only).
	var boss_ids: Array[String] = cards.boss_card_order()
	var boss_zone_free: bool = true
	for id: String in boss_ids:
		if cards.is_zone_card(id):
			boss_zone_free = false
	var zone_ids: Array[String] = ["tran_gai", "gai_nguyen", "gai_doc"]
	var all_zone: bool = true
	for id: String in zone_ids:
		if not cards.is_zone_card(id):
			all_zone = false
	check(cards.cards.size() == cards.card_order.size() + cards.curse_ids().size(),
		"every card is a player card or a curse (no boss-only Wall cards left) %d" % cards.cards.size())
	# Cast rhythm spec 2026-11-05: the parry card (do_kiem) answers an enemy telegraph; the boss never holds it either.
	check(boss_zone_free and all_zone and boss_ids.size() == cards.card_order.size() - zone_ids.size() - 1 and not boss_ids.has("do_kiem"),
		"boss card list excludes the 3 player zone cards and the parry card (%d of %d)" % [boss_ids.size(), cards.card_order.size()])
	check(all_ok, "all name/desc keys in CSV vi+en")
	check(dpc_ok, "every card has float damage_per_cell")
	check(up_ok, "every card has upgrade table")
	check(no_mult, "no damage_multiplier / class_tags")
	check(pins >= 4 and burns >= 4, "pin %d burn %d cards" % [pins, burns])
	check(cards.get_skill("kiem_khi")["damage_per_cell"] == 6.0 and cards.get_skill("tu_kiem")["damage_per_cell"] == 8.0, "curve ends (Story 023: epics 8 dpc)")
	var chars: CharacterConfig = CharacterConfig.load_from_file()
	var starters_ok: bool = true
	for cid: String in chars.ids():
		for id: Variant in chars.get_character(cid)["starter_deck"]:
			if not cards.has_skill(str(id)):
				starters_ok = false
	check(starters_ok, "starter decks use known cards")
	for id: String in cards.default_deck:
		starters_ok = starters_ok and cards.has_skill(id)
	check(starters_ok, "default deck known")

	# --- resolved
	var r1: Dictionary = cards.resolved("kiem_khi", 1)
	var r2: Dictionary = cards.resolved("kiem_khi", 2)
	var r3: Dictionary = cards.resolved("kiem_khi", 3)
	check(r1["damage_per_cell"] == 6.0 and r2["damage_per_cell"] == 7.0 and r3["damage_per_cell"] == 8.0, "kiem_khi dpc 6/7/8")
	check(cards.resolved("kiem_khi", 0)["damage_per_cell"] == 6.0 and cards.resolved("kiem_khi", 9)["damage_per_cell"] == 8.0, "level clamp")
	check(cards.resolved("nope", 1).is_empty(), "unknown id {}")
	var d3: Dictionary = cards.resolved("dai_dao", 3)
	check(d3["min_cells"] == 3 and typeof(d3["min_cells"]) == TYPE_INT, "dai_dao min_cells 5 -> 3")
	var cd: Dictionary = cards.resolved("thiet_kiem", 3)
	check(cd["cooldown_sec"] == 0.0, "cooldown never below 0 (2 -> 0)")
	var bc: Dictionary = cards.resolved("bang_chau", 3)
	check(bc["min_cells"] == 1, "min_cells floor 1 (3 -> 1)")
	check(cards.resolved("hoa_tran", 3)["burn_damage_per_tick"] == 3.0, "burn tick upgrade")
	check(is_equal_approx(float(cards.resolved("han_bang", 3)["pin_duration_sec"]), 2.4), "pin upgrade (Story 023: +0.3/level)")
	check(cards.get_skill("kiem_khi")["damage_per_cell"] == 6.0, "resolved does not mutate")
	var bare: SkillConfig = SkillConfig.from_json_text('{"cards": {"x": {"effect": "damage"}}}')
	check(bare.get_skill("x")["damage_per_cell"] == 6.0, "missing dpc falls back to cuts base")

	# --- Deck
	var deck := Deck.from_array(["a", "a", "b"] as Array, 5)
	check(deck.size() == 3 and deck.count_of("a") == 2 and deck.level_of("a") == 1, "deck from ids")
	var up: Dictionary = deck.add("a")
	check(up["upgraded"] and up["level"] == 2 and deck.size() == 3, "add upgrades first copy")
	deck.add("a")
	check(deck.level_of("a") == 3 and deck.entries()[0]["level"] == 3 and deck.entries()[1]["level"] == 1, "first copy lvl3, second still 1")
	deck.add("a")  # second copy 1->2
	deck.add("a")  # 2->3
	var nw: Dictionary = deck.add("a")
	check(not nw["upgraded"] and nw["level"] == 1 and deck.size() == 4, "all level 3: new copy")
	check(not deck.add("zzz")["upgraded"], "new id appended")
	var before: int = deck.size()
	deck.remove_at(0)
	check(deck.size() == before - 1 and deck.entries()[0]["level"] == 3, "remove_at")
	deck.remove_at(99)
	check(deck.size() == before - 1, "remove_at out of range ignored")
	var mixed := Deck.from_array([{"id": "a", "level": 2}, "b", {"id": "c"}] as Array, 1)
	check(mixed.level_of("a") == 2 and mixed.level_of("b") == 1 and mixed.level_of("c") == 1 and mixed.level_of("q") == 0, "from_array both formats")
	check(mixed.to_array() == (["a", "b", "c"] as Array[String]), "to_array ids")
	var d1 := Deck.from_array(["a", "b", "c", "d", "e"] as Array, 77)
	var d2 := Deck.from_array([{"id": "a", "level": 1}, {"id": "b", "level": 1}, {"id": "c", "level": 1}, {"id": "d", "level": 1}, {"id": "e", "level": 1}] as Array, 77)
	check(d1.draw(5) == d2.draw(5), "seeded determinism across formats")
	var d4 := Deck.from_array([{"id": "a", "level": 3}, {"id": "a", "level": 1}] as Array, 3)
	var hand: Array[Dictionary] = d4.draw_entries(2)
	check(hand.size() == 2 and (int(hand[0]["level"]) + int(hand[1]["level"])) == 4, "draw_entries carries levels")
	var d5 := Deck.from_array(["a", "b", "c"] as Array, 4)
	d5.remove_at(1)
	var seen: Array[String] = d5.draw(2)
	check(not seen.has("b") and seen.size() == 2, "removed card not dealt")

	# --- RewardRoller
	var rcfg: Dictionary = RewardRoller.load_config()
	check(not rcfg.has("class_tag_bonus") and rcfg["allow_remove"] and rcfg["min_deck_size"] == 4 and rcfg["max_card_level"] == 3 and rcfg["offer_upgrades"], "rewards config")
	var a: Array[String] = RewardRoller.roll(cards, rcfg, 42)
	var b: Array[String] = RewardRoller.roll(cards, rcfg, 42)
	check(a == b and a.size() == 3 and a[0] != a[1] and a[1] != a[2] and a[0] != a[2], "deterministic distinct")
	var levels: Dictionary = {}
	for id: String in cards.card_order.slice(0, 17):
		levels[id] = 3
	var all_offers_ok: bool = true
	for s: int in 40:
		for id: String in RewardRoller.roll(cards, rcfg, s, [], levels):
			if levels.has(id):
				all_offers_ok = false
	check(all_offers_ok, "max-level cards excluded when pool is large enough")
	var allmax: Dictionary = {}
	for id: String in cards.card_order:
		allmax[id] = 3
	check(RewardRoller.roll(cards, rcfg, 1, [], allmax).size() == 3, "pool exhausted: maxed cards return")
	var near: Dictionary = {}
	# 2026-11-05: hero cards (cards.json `hero`, e.g. do_kiem) never enter the pool, so "last" is the last POOL card.
	var pool_ids: Array[String] = []
	for id: String in cards.card_order:
		if cards.is_pool_card(id):
			pool_ids.append(id)
	var last: int = pool_ids.size() - 1
	for id: String in pool_ids.slice(0, last):
		near[id] = 3
	var near_offer: Array[String] = RewardRoller.roll(cards, rcfg, 1, [], near)
	check(near_offer.size() == 3 and near_offer.has(pool_ids[last]), "short pool: free card plus maxed fill")
	check(RewardRoller.is_upgrade("a", {"a": 1}) and RewardRoller.is_upgrade("a", {"a": 2}) and not RewardRoller.is_upgrade("a", {"a": 3}) and not RewardRoller.is_upgrade("a", {}), "is_upgrade")

	# --- RunSession (v4 map model, Story 022)
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var character: Dictionary = chars.get_character(chars.default_id())
	var s := RunSession.begin(chapters, character, 0, 123, chapters.generate_map(0, 123, 0), 10)
	var n0: int = s.deck.size()
	check(s.deck_ids.size() == n0 and s.deck[0].has("level") and s.removal_tokens == 10 and not s.map.is_empty(), "begin: deck entries level 1, 10 tokens, map")
	var res: Dictionary = s.add_card("kiem_vu")
	check(res["upgraded"] and res["level"] == 2 and s.deck.size() == n0 and s.deck_levels()["kiem_vu"] == 2, "add_card upgrades")
	s.add_card("kiem_vu")
	check(s.deck_levels()["kiem_vu"] == 3, "level 3")
	s.add_card("kiem_vu")  # second copy upgraded 1->2
	check(s.deck.size() == n0 and s.deck_levels()["kiem_vu"] == 3, "second copy upgraded, not added")
	s.add_card("kiem_vu")
	var res2: Dictionary = s.add_card("kiem_vu")
	check(not res2["upgraded"] and s.deck.size() == n0 + 1, "all copies lvl3 -> new copy")
	var removed: int = 0
	while s.remove_card_at(0, 4):
		removed += 1
	check(s.deck.size() == 4 and removed == n0 + 1 - 4 and s.removal_tokens == 10 - removed and not s.remove_card_at(0, 4), "min_deck_size respected, one token per removal")
	check(not s.remove_card_at(-1, 1) and not s.remove_card_at(50, 1) and s.removal_tokens == 10 - removed, "remove out of range false, no token spent")
	var broke := RunSession.begin(chapters, character, 0, 1, chapters.generate_map(0, 1, 0), 0)
	check(not broke.remove_card_at(0, 1) and broke.deck.size() == n0 and broke.removal_tokens == 0, "no token -> no removal")
	s.pending_reward = ["kiem_vu"]
	var dict: Dictionary = s.to_dict()
	check(typeof(dict["deck"][0]) == TYPE_DICTIONARY and dict["deck"][0].has("level") and int(dict["version"]) == RunSession.SAVE_VERSION and int(dict["removal_tokens"]) == 10 - removed, "to_dict deck entries + tokens (current save version)")
	var loaded: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(dict)), chapters, cards)
	check(loaded != null and loaded.deck_entries() == s.deck_entries() and loaded.removal_tokens == s.removal_tokens and loaded.map == s.map, "save/load keeps levels, tokens, map (via JSON)")
	var old: Dictionary = dict.duplicate(true)
	old["deck"] = ["kiem_khi", "chan_phong", "nope"]
	var v2: RunSession = RunSession.from_dict(old, chapters, cards)
	check(v2 != null and v2.deck.size() == 2 and v2.deck[0]["level"] == 1 and v2.deck_ids == (["kiem_khi", "chan_phong"] as Array[String]), "id-string deck -> level 1")
	var ps := ProgressState.new()
	ps.set_run(s)
	var ps2: ProgressState = ProgressState.from_json(ps.to_json(), chapters)
	check(ps2.has_run() and RunSession.from_dict(ps2.get_run_dict(), chapters, cards).deck_entries() == s.deck_entries(), "ProgressState round-trips the v4 run")

	print("PASSES=", passes)
	print("FAILS=", fails)
	quit(fails)

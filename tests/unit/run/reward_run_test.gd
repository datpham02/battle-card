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


func _initialize() -> void:
	var cards: SkillConfig = SkillConfig.load_from_file()
	var rcfg: Dictionary = RewardRoller.load_config()
	check(int(rcfg["offer_count"]) == 3 and bool(rcfg["allow_skip"]) and not rcfg.has("class_tag_bonus") and bool(rcfg["allow_remove"]) and int(rcfg["min_deck_size"]) == 4 and int(rcfg["max_card_level"]) == 3, "rewards.json loads (020 keys)")
	check(float(rcfg["rarity_weights"]["epic"]) == 5.0, "epic weight 5")
	check(cards.card_order.size() >= 20 and cards.has_skill("han_bang") and cards.get_rarity("han_bang") == "epic", ">= 20 cards, han_bang epic")
	check(not cards.get_skill("liet_hoa").has("class_tags") and not cards.get_skill("hoa_tran").has("class_tags"), "class tags gone (020)")

	var none: Array[String] = []
	var maxed_liet: Dictionary = {"liet_hoa": 3}
	var a: Array[String] = RewardRoller.roll(cards, rcfg, 42)
	var b: Array[String] = RewardRoller.roll(cards, rcfg, 42)
	check(a == b and a.size() == 3, "same seed same offer")
	var distinct: bool = true
	var counts_p: Dictionary = {}
	var counts_k: Dictionary = {}
	for sd: int in 2000:
		var op: Array[String] = RewardRoller.roll(cards, rcfg, sd)
		var ok_: Array[String] = RewardRoller.roll(cards, rcfg, sd, [], maxed_liet)
		for o: Array[String] in [op, ok_]:
			var seen: Dictionary = {}
			for id: String in o:
				seen[id] = true
			if seen.size() != 3:
				distinct = false
		for id: String in op:
			counts_p[id] = int(counts_p.get(id, 0)) + 1
		for id: String in ok_:
			counts_k[id] = int(counts_k.get(id, 0)) + 1
	check(distinct, "3 distinct ids over 4000 rolls")
	check(int(counts_p.get("liet_hoa", 0)) > 0 and int(counts_k.get("liet_hoa", 0)) == 0, "max-level card never offered while the pool is large (020) (%s vs %s)" % [counts_p.get("liet_hoa", 0), counts_k.get("liet_hoa", 0)])
	check(int(counts_p.get("han_bang", 0)) < int(counts_p.get("kiem_vu", 0)) and int(counts_p.get("han_bang", 0)) < int(counts_p.get("chan_phong", 0)), "epic rarest")
	var most: Array[String] = cards.card_order.slice(0, cards.card_order.size() - 2)
	var small: Array[String] = RewardRoller.roll(cards, rcfg, 1, most)
	check(small.size() == 2 and not small.has("kiem_khi"), "small pool returns what exists")
	var excl: Dictionary = rcfg.duplicate()
	excl["pool_excludes_defaults"] = true
	var ex: Array[String] = RewardRoller.roll(cards, excl, 3)
	check(not ex.has("kiem_khi") and not ex.has("chan_phong") and not ex.has("hoa_tran") and not ex.has("bang_phong"), "pool_excludes_defaults")
	check(RewardRoller.load_config("res://nope.json")["offer_count"] == 3, "bad path gives defaults")

	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var d: Dictionary = cfg.defaults()
	check(float(d["heal_between_floors"]) == 0.0 and float(d["heal_between_matches"]) == 0.0 and int(d["revive_tokens"]) == 0 and float(d["retry_min_hp_ratio"]) == 0.0, "chapters defaults (no auto heal, Story 022)")
	var rc: RunConfig = RunConfig.from_node(cfg, 0, "goblin_scout", "battle", 1)
	check(rc.match_count() == 1 and rc.matches[0]["id"] == "goblin_scout" and rc.heal_between_floors == 0.0 and rc.revive_tokens == 0 and int(rc.matches[0]["arena_seed"]) >= 0, "RunConfig.from_node: one match, seeded arena, defaults")
	var rc2: RunConfig = RunConfig.from_dictionary({"heal_between_floors": 12, "revive_tokens": 2, "retry_min_hp_ratio": 0.5})
	check(rc2.heal_between_floors == 12.0 and rc2.revive_tokens == 2 and rc2.retry_min_hp_ratio == 0.5, "flat file keeps parsing")
	var cc2: ChaptersConfig = ChaptersConfig.from_dictionary({"defaults": {"revive_tokens": 3, "heal_between_floors": -5}})
	check(int(cc2.defaults()["revive_tokens"]) == 3 and float(cc2.defaults()["heal_between_floors"]) == 0.0, "ChaptersConfig clamps")

	var chars: CharacterConfig = CharacterConfig.load_from_file()
	var ch: Dictionary = chars.get_character("kiem_si")
	var map: Array[Dictionary] = cfg.generate_map(0, 777, 0)
	var s: RunSession = RunSession.begin(cfg, ch, 0, 777, map, int(rcfg["starting_removals"]))
	check(s.column == 0 and s.node_index == -1 and s.hp == -1.0 and s.deck_ids.size() == 6 and s.character_id == "kiem_si" and s.removal_tokens == 1 and s.map.size() == cfg.column_count(0), "begin (v4: map, column 0, 1 token)")
	check(s.floor_index == 0 and s.match_index == -1, "deprecated floor_index / match_index alias column / node_index")
	check(s.available_nodes().size() == 1 and str(s.available_nodes()[0]["kind"]) == "battle" and s.current_node().is_empty(), "column 0: one battle, none chosen")
	check(not s.complete_node(60.0, 300.0, "", rcfg, 0.0)["advanced"], "complete_node without a chosen node does nothing")
	check(s.choose_node(0) and not s.choose_node(0) and s.current_node()["kind"] == "battle", "choose_node once")
	var r1: Dictionary = s.complete_node(60.0, 300.0, "", rcfg, 0.0)
	check(r1["advanced"] and not r1["run_won"] and s.hp == 60.0 and s.column == 1 and s.node_index == -1 and s.cleared_nodes.size() == 1, "battle win: hp 60 (no heal), column 1")
	check(s.luck(rcfg) == float(rcfg["luck_per_node"]) and s.luck({}) == 1.0, "luck 1 after one node")
	check(s.choose_node(int(s.available_nodes()[0]["node_index"])), "choose in column 1")
	s.complete_node(60.0, 300.0, "", rcfg, 10.0)
	check(s.hp == 70.0 and s.column == 2, "passive heal added")
	s.choose_node(int(s.available_nodes()[0]["node_index"]))
	s.complete_node(295.0, 300.0, "", rcfg, 10.0)
	check(s.hp == 300.0 and s.column == 3 and not s.is_run_won(), "clamped at max")
	var two: Array[Dictionary] = [{"index": 0, "tier": 0, "nodes": [{"kind": "battle", "match_id": "goblin_scout"}]}, {"index": 1, "tier": 2, "nodes": [{"kind": "boss", "match_id": "goblin_warlock"}]}]
	var s2: RunSession = RunSession.begin(cfg, ch, 0, 5, two, 1)
	s2.choose_node(0)
	s2.complete_node(30.0, 300.0, "", rcfg, 0.0)
	check(s2.hp == 30.0 and s2.column == 1 and not s2.is_run_won() and s2.removal_tokens == 1, "non-boss win: no refill, no token, not won")
	check(s2.is_last_floor(cfg) and s2.choose_node(0) and s2.is_boss_match(cfg), "boss column (deprecated shims agree)")
	var rb: Dictionary = s2.complete_node(10.0, 300.0, "", rcfg, 0.0)
	check(rb["run_won"] and s2.is_run_won() and s2.removal_tokens == 2 and s2.cleared_bosses_this_run == 1 and s2.hp == 10.0, "boss win -> run won, +1 token")
	check(s2.spend_removal() and s2.spend_removal() and not s2.spend_removal() and s2.removal_tokens == 0, "spend_removal never negative")
	s.add_card("han_bang")
	check(s.deck_ids.size() == 7 and s.deck_ids[6] == "han_bang", "add_card")

	var r: RunSession = RunSession.begin(cfg, ch, 0, 99, map, 1)
	r.choose_node(0)
	r.complete_node(57.0, 300.0, "", rcfg, 0.0)
	r.choose_node(int(r.available_nodes()[0]["node_index"]))
	r.elapsed_sec = 123.5
	for extra: String in ["kiem_vu", "han_bang", "liet_hoa"]:
		r.add_card(extra)
	r.set_pending_reward(["cuong_phong", "kiem_vu", "han_bang"])
	check(r.deck_ids.size() == 9 and r.has_pending_reward(), "9 cards pending reward")
	var back: RunSession = RunSession.from_dict(r.to_dict(), cfg, cards)
	check(back != null and back.deck_ids == r.deck_ids and back.hp == 57.0 and back.column == 1 and back.node_index == r.node_index and back.map == r.map and back.cleared_nodes == r.cleared_nodes and back.removal_tokens == 1 and back.pending_reward == r.pending_reward and back.run_seed == 99 and back.elapsed_sec == 123.5 and back.character_id == "kiem_si" and back.luck(rcfg) == r.luck(rcfg), "round trip (v4)")
	check(back.to_dict()["chapter"] == "ch1" and int(back.to_dict()["version"]) == 4, "dict ids, version 4")
	var bad: Dictionary = r.to_dict()
	bad["chapter"] = "zz"
	check(RunSession.from_dict(bad, cfg) == null, "unknown chapter -> null")
	bad = r.to_dict()
	bad["node_index"] = 9
	check(RunSession.from_dict(bad, cfg) == null, "node out of range -> null")
	bad = r.to_dict()
	bad["map"] = []
	check(RunSession.from_dict(bad, cfg) == null, "empty map -> null")
	bad = r.to_dict()
	bad["deck"] = ["ghost"]
	check(RunSession.from_dict(bad, cfg, cards) == null, "all cards unknown -> null")
	bad["deck"] = ["ghost", "kiem_khi"]
	var dropped: RunSession = RunSession.from_dict(bad, cfg, cards)
	check(dropped != null and dropped.deck_ids == ["kiem_khi"], "unknown card dropped")
	var v3d: Dictionary = {"version": 3, "character": "kiem_si", "chapter": "ch1", "floor": "f2", "match_index": 1, "hp": 50, "deck": ["kiem_khi"], "run_seed": 1}
	var old: RunSession = RunSession.from_dict(v3d, cfg, cards)
	check(old != null and old.needs_restart and old.restart_reason == "run.restart.old_save" and old.map.is_empty() and bool(old.to_dict()["needs_restart"]), "v3 run -> needs_restart session")
	r.clear_pending_reward()
	check(not r.has_pending_reward(), "clear reward")

	var p := ProgressState.new()
	check(p.is_chapter_unlocked(cfg, 0) and not p.is_chapter_unlocked(cfg, 1), "chapter 0 open, 1 locked")
	p.mark_chapter_cleared("ch1")
	p.mark_chapter_cleared("ch1")
	check(p.is_chapter_unlocked(cfg, 1) and p.get_cleared_chapters() == ["ch1"] and not p.is_chapter_unlocked(cfg, 2), "chain unlock, no dup")
	p.mark_card_seen("han_bang")
	p.mark_card_seen("han_bang")
	check(p.get_seen_cards() == ["han_bang"], "seen cards")
	p.record_boss_clear()
	check(p.get_cleared_bosses() == 1, "record_boss_clear")
	p.set_locale("en")
	p.set_run(r)
	check(p.has_run() and p.get_run_dict()["hp"] == 57.0, "set_run")
	var rt: ProgressState = ProgressState.from_json(p.to_json(), cfg)
	check(rt.get_locale() == "en" and rt.is_chapter_cleared("ch1") and rt.get_seen_cards() == ["han_bang"] and rt.get_cleared_bosses() == 1 and rt.has_run() and rt.get_run_dict() == p.get_run_dict(), "json round trip")
	check(JSON.parse_string(p.to_json())["version"] == 4, "writes v4")
	p.clear_run()
	check(not p.has_run() and JSON.parse_string(p.to_json())["run_in_progress"] == null, "clear_run -> null")
	var v1: ProgressState = ProgressState.from_json("{\"version\":1,\"locale\":\"en\",\"cleared\":[\"ch1/f1\"],\"in_progress\":{\"floor\":\"ch1/f1\",\"match_index\":1,\"hp_at_match_start\":50,\"floor_seed\":3}}", cfg)
	check(v1.get_locale() == "en" and not v1.has_run() and v1.get_cleared_chapters().is_empty(), "v1 loads, locale kept, no run")
	var corrupt: ProgressState = ProgressState.from_json("{{nope", cfg)
	check(corrupt.get_locale() == "vi" and not corrupt.has_run(), "corrupt -> empty")
	var badrun: String = "{\"version\":2,\"locale\":\"vi\",\"cleared_chapters\":[\"zz\"],\"run_in_progress\":{\"character\":\"kiem_si\",\"chapter\":\"zz\",\"floor\":\"f1\",\"match_index\":0,\"hp\":-1,\"deck\":[\"kiem_khi\"],\"run_seed\":1,\"elapsed\":0,\"pending_reward\":[],\"revives\":0}}"
	var br: ProgressState = ProgressState.from_json(badrun, cfg)
	check(not br.has_run() and br.get_cleared_chapters().is_empty(), "bad run and unknown chapter dropped")
	var v3run: String = "{\"version\":3,\"locale\":\"vi\",\"cleared_chapters\":[\"ch1\"],\"run_in_progress\":{\"character\":\"kiem_si\",\"chapter\":\"ch1\",\"floor\":\"f1\",\"match_index\":0,\"hp\":-1,\"deck\":[\"kiem_khi\"],\"run_seed\":1,\"elapsed\":0,\"pending_reward\":[],\"revives\":0}}"
	var v3s: ProgressState = ProgressState.from_json(v3run, cfg)
	check(v3s.has_run() and bool(v3s.get_run_dict()["needs_restart"]) and v3s.is_chapter_cleared("ch1") and v3s.get_cleared_bosses() == 0, "v3 save: run needs_restart, cleared chapters kept")
	var store: ProgressStore = ProgressStore.memory_store()
	store.save_state(rt)
	check(store.load_state(cfg).has_run(), "store round trip")

	print("FAILS=", fails, " PASSES=", passes)
	quit(1 if fails > 0 else 0)

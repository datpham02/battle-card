extends SceneTree
## Story 037 (W4): locked content never reaches a pool and comes back after the unlock. RunSession.locked
## ({kind: ids}) filters card rewards (RewardRoller exclusion list), shop stock, relic rolls (RelicRoller), the
## player's piece weights and ink offers (PieceDeck) and the region offer (RunSession.roll_offer); nothing
## locked (the default) leaves every pool as it was; `locked` survives a save / load and an old save without
## the key loads as nothing locked. Uses fake locked sets over the shipped data (no region is locked today).
## Prints PASS/FAIL lines and FAILS=n.

const HERO: String = "phap_su"
const SEEDS: int = 300

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _session(chapters: ChaptersConfig, locked: Dictionary, run_seed: int = 7) -> RunSession:
	var ch: Dictionary = CharacterConfig.load_from_file().get_character(HERO)
	return RunSession.begin_world(chapters, ch, run_seed, 1, locked)


func _init() -> void:
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	_test_cards()
	_test_relics()
	_test_shop(chapters)
	_test_pieces()
	_test_regions(chapters)
	_test_save(chapters)
	print("FAILS=%d" % fails)
	quit(fails)


func _test_cards() -> void:
	var cards: SkillConfig = SkillConfig.load_from_file()
	var cfg: Dictionary = RewardRoller.load_config()
	var seen: Dictionary = {}
	for sd: int in SEEDS:
		for id: String in RewardRoller.roll(cards, cfg, sd):
			seen[id] = int(seen.get(id, 0)) + 1
	var locked_ids: Array[String] = []
	for id: Variant in seen.keys():
		if locked_ids.size() < 4:
			locked_ids.append(str(id))
	_check("cards: the unlocked pool offers the 4 test cards", locked_ids.size() == 4)
	var run := RunSession.new()
	run.locked = {"card": locked_ids}
	_check("cards: is_locked true for a locked id, false for another kind / id", run.is_locked("card", locked_ids[0])
		and not run.is_locked("relic", locked_ids[0]) and not run.is_locked("card", "no_such_card"))
	var leaked: bool = false
	for sd: int in SEEDS:
		for id: String in RewardRoller.roll(cards, cfg, sd, run.locked_ids("card")):
			if locked_ids.has(id):
				leaked = true
	_check("cards: a locked card is never offered over %d seeds" % SEEDS, not leaked)
	var back: bool = false
	for sd: int in SEEDS:
		for id: String in RewardRoller.roll(cards, cfg, sd, [] as Array[String]):
			if locked_ids.has(id):
				back = true
	_check("cards: they are offered again once nothing is locked", back)
	var empty := RunSession.new()
	_check("cards: nothing locked = the same offer as before",
		RewardRoller.roll(cards, cfg, 11, empty.locked_ids("card")) == RewardRoller.roll(cards, cfg, 11))


func _test_relics() -> void:
	var seen: Dictionary = {}
	for sd: int in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		for id: String in RelicRoller.roll(RelicRoller.SOURCE_TREASURE, [], rng, null, 3):
			seen[id] = true
	var locked_ids: Array[String] = []
	for id: Variant in seen.keys():
		if locked_ids.size() < 4:
			locked_ids.append(str(id))
	var leaked: bool = false
	for source: String in [RelicRoller.SOURCE_TREASURE, RelicRoller.SOURCE_SHOP, RelicRoller.SOURCE_EVENT, RelicRoller.SOURCE_BOSS_KILL]:
		for sd: int in SEEDS:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = sd
			for id: String in RelicRoller.roll(source, [], rng2, null, 3, "", locked_ids):
				if locked_ids.has(id):
					leaked = true
	_check("relics: a locked relic is never rolled by any source over %d seeds" % SEEDS, not leaked and locked_ids.size() == 4)
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 5
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 5
	_check("relics: nothing locked = the same roll as before",
		RelicRoller.roll(RelicRoller.SOURCE_TREASURE, [], rng_a, null, 3, "", []) == RelicRoller.roll(RelicRoller.SOURCE_TREASURE, [], rng_b, null, 3))
	var fate_leak: bool = false
	for sd: int in SEEDS:
		for id: String in FateLogic.roll_execute_offer([], {}, null, sd, 0.0, locked_ids):
			if locked_ids.has(id):
				fate_leak = true
	_check("relics: the execute offer skips locked relics", not fate_leak)


func _test_shop(_chapters: ChaptersConfig) -> void:
	var cards: SkillConfig = SkillConfig.load_from_file()
	var reward: Dictionary = RewardRoller.load_config()
	var economy: EconomyConfig = EconomyConfig.shared()
	var base_cards: Dictionary = {}
	var base_relics: Dictionary = {}
	for sd: int in 120:
		var stock: Dictionary = ShopLogic.build(sd, 1, 2, 1, 0.0, [], cards, reward, null, economy)
		for c: Dictionary in stock["cards"]:
			base_cards[str(c["id"])] = true
		for r: Dictionary in stock["relics"]:
			base_relics[str(r["id"])] = true
	var locked: Dictionary = {"card": [base_cards.keys()[0]], "relic": [base_relics.keys()[0]]}
	var leaked: bool = false
	for sd: int in 120:
		var stock2: Dictionary = ShopLogic.build(sd, 1, 2, 1, 0.0, [], cards, reward, null, economy, locked)
		for c2: Dictionary in stock2["cards"]:
			if (locked["card"] as Array).has(str(c2["id"])):
				leaked = true
		for r2: Dictionary in stock2["relics"]:
			if (locked["relic"] as Array).has(str(r2["id"])):
				leaked = true
	_check("shop: a locked card / relic never enters the stock", not leaked)
	_check("shop: nothing locked = the same stock as before",
		ShopLogic.build(3, 1, 2, 1, 0.0, [], cards, reward, null, economy) == ShopLogic.build(3, 1, 2, 1, 0.0, [], cards, reward, null, economy, {}))


func _test_pieces() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var cfg: PieceDeckConfig = PieceDeckConfig.load_from_file()
	var state: Dictionary = PieceDeck.initial(lib)
	var base: Array[String] = lib.base_shape_ids()
	var locked: Array[String] = [base[0], base[1]]
	var run := RunSession.new()
	run.locked = {"piece": locked}
	var plain: Dictionary = PieceDeck.weights_for_match(state, lib, "ch1", null, cfg)
	var filtered: Dictionary = PieceDeck.weights_for_match(state, lib, "ch1", null, cfg, run.locked_ids("piece"))
	_check("pieces: without a lock every default shape is drawable", plain["weights"].has(locked[0]) and plain["weights"].has(locked[1]))
	_check("pieces: a locked shape is not in the drawable weights", not filtered["weights"].has(locked[0]) and not filtered["weights"].has(locked[1])
		and (filtered["weights"] as Dictionary).size() == (plain["weights"] as Dictionary).size() - 2)
	_check("pieces: the deck state itself is untouched (start-state parity)", state == PieceDeck.initial(lib))
	var empty_state: Dictionary = {}
	var runless: Dictionary = PieceDeck.weights_for_match(empty_state, lib, "ch1", null, cfg, run.locked_ids("piece"))
	_check("pieces: an empty deck keeps the original weights minus the locked ones", not runless["weights"].has(locked[0]) and runless["weights"].has(base[2]))
	var leaked: bool = false
	var drawn_back: bool = false
	for sd: int in SEEDS:
		for id: String in PieceDeck.roll_ink_offer(state, lib, cfg, sd, run.locked_ids("piece")):
			if locked.has(id):
				leaked = true
		for id2: String in PieceDeck.roll_ink_offer(state, lib, cfg, sd):
			if locked.has(id2):
				drawn_back = true
	_check("pieces: a locked shape is never in an ink offer", not leaked)
	_check("pieces: it is offered again once unlocked", drawn_back)
	_check("pieces: effective weights agree", not PieceDeck.effective_weights(state, lib, "ch1", cfg, locked).has(locked[0]))


func _test_regions(chapters: ChaptersConfig) -> void:
	var all_ids: Array[String] = chapters.region_ids()
	var victim: String = all_ids[0]
	var leaked: bool = false
	var appears: bool = false
	for sd: int in SEEDS:
		var locked_run: RunSession = _session(chapters, {"region": [victim]}, sd)
		if locked_run.region_offer.has(victim):
			leaked = true
		var open_run: RunSession = _session(chapters, {}, sd)
		if open_run.region_offer.has(victim):
			appears = true
	_check("regions: a locked region is never offered over %d seeds" % SEEDS, not leaked)
	_check("regions: it is offered once nothing is locked", appears)
	var s: RunSession = _session(chapters, {"region": [victim]}, 3)
	_check("regions: the offer still has the configured choices", s.region_offer.size() > 0)
	# Every region locked: the pool is not emptied (a run must be playable).
	var all_locked: RunSession = _session(chapters, {"region": all_ids}, 3)
	_check("regions: never an empty offer", not all_locked.region_offer.is_empty())


func _test_save(chapters: ChaptersConfig) -> void:
	var s: RunSession = _session(chapters, {"card": ["gai_doc", "gai_doc"], "relic": ["tui_rong"], "piece": []})
	_check("save: duplicates and empty kinds are cleaned", s.locked == {"card": ["gai_doc"], "relic": ["tui_rong"]}, str(s.locked))
	s.choose_region(s.region_offer[0], 0)
	var back: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), chapters)
	_check("save: locked round-trips", back != null and back.is_locked("card", "gai_doc") and back.is_locked("relic", "tui_rong")
		and not back.is_locked("card", "tui_rong"))
	var d: Dictionary = s.to_dict()
	d.erase("locked")
	var old: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(d)), chapters)
	_check("save: a save without `locked` loads as nothing locked", old != null and old.locked.is_empty())
	_check("save: the version did not change", int(s.to_dict()["version"]) == RunSession.SAVE_VERSION)
	var stats := RunSession.new()
	stats.add_match_stats({"frost_bursts": 3, "boss_thorn_steps": 2, "hits_taken": 1}, true)
	stats.add_match_stats({"frost_bursts": 2, "boss_thorn_steps": -4}, true)
	_check("stats: frost_bursts and boss_thorn_steps sum over the run (negatives ignored)",
		int(stats.stats["frost_bursts"]) == 5 and int(stats.stats["boss_thorn_steps"]) == 2)
	var cleaned: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(_with_stats(s, stats.stats))), chapters)
	_check("stats: both keys survive a save", cleaned != null and int(cleaned.stats["frost_bursts"]) == 5 and int(cleaned.stats["boss_thorn_steps"]) == 2)
	var fresh := RunSession.new()
	_check("stats: a new run starts both at 0", int(fresh.stats["frost_bursts"]) == 0 and int(fresh.stats["boss_thorn_steps"]) == 0)


func _with_stats(s: RunSession, stats: Dictionary) -> Dictionary:
	var d: Dictionary = s.to_dict()
	d["stats"] = stats.duplicate(true)
	return d

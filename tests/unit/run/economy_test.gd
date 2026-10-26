extends SceneTree
## Story 033 Part A: EconomyConfig (gold per kind / floor, prices, defaults), RunSession gold, run modifiers and
## their save round trip. The shipped economy.json numbers are read through the config, not repeated here,
## except where the number itself is the point (the documented starting values).

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _session() -> RunSession:
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var ch: Dictionary = CharacterConfig.load_from_file().get_character(CharacterConfig.load_from_file().default_id())
	return RunSession.begin_world(chapters, ch, 11, 1)


func _roundtrip(s: RunSession) -> RunSession:
	return RunSession.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), ChaptersConfig.load_from_file())


func _initialize() -> void:
	var eco: EconomyConfig = EconomyConfig.load_from_file()

	# --- shipped values (the documented starting numbers) ---
	check(eco.starting_gold() == 20, "starting_gold 20")
	check(eco.gold_bounds("battle", 0) == Vector2i(10, 14), "battle floor 1: 12 +-20 % = 10..14")
	check(eco.price_card("common", 0) == 30 and eco.price_card("rare", 0) == 40 and eco.price_card("epic", 0) == 60, "card prices floor 1: 30 / 40 / 60")
	check(eco.price_relic("common", 0) == 50 and eco.price_relic("rare", 0) == 70 and eco.price_relic("epic", 0) == 90, "relic prices floor 1: 50 / 70 / 90")
	check(eco.price_card("common", 4) == 36 and eco.price_relic("epic", 4) == 108, "prices x1.2 on floor 5")
	check(eco.price_card("common", 99) == eco.price_card("common", 4), "a floor past the last row uses the last multiplier")
	check(eco.service_price("remove_card", 0) == 60 and eco.service_price("heal", 0) == 40, "service prices 60 / 40")
	check(eco.service_max_uses("remove_card") == 1 and eco.service_max_uses("heal") == 1, "services: max one use each")
	check(is_equal_approx(eco.service_heal_ratio(), 0.25), "heal ratio 0.25")
	check(eco.stock_counts() == {"cards": 3, "relics": 2}, "stock 3 cards + 2 relics")
	check(eco.price_card("zz", 0) == eco.price_card("common", 0), "unknown rarity costs the common price")

	# --- gold per kind and floor: deterministic by seed, inside the variance bounds ---
	var deterministic: bool = true
	var in_bounds: bool = true
	var varied: Dictionary = {}
	for kind: String in ["battle", "danger", "miniboss", "boss", "treasure"]:
		for f: int in 6:
			var b: Vector2i = eco.gold_bounds(kind, f)
			for s: int in 60:
				var g: int = eco.gold_for(kind, f, s)
				if g != eco.gold_for(kind, f, s):
					deterministic = false
				if g < b.x or g > b.y:
					in_bounds = false
				if kind == "battle" and f == 0:
					varied[g] = true
	check(deterministic, "gold_for: same (kind, floor, seed) -> same gold")
	check(in_bounds, "gold_for: always inside +-variance of base x floor multiplier")
	check(varied.size() >= 3, "gold_for: the seed varies the amount (%d values)" % varied.size())
	check(eco.gold_for("battle", 4, 5) > eco.gold_bounds("battle", 0).y - 1 or eco.gold_bounds("battle", 4).x > eco.gold_bounds("battle", 0).y - 1, "later floors drop more gold")
	check(eco.gold_bounds("boss", 0).x > eco.gold_bounds("danger", 0).y and eco.gold_bounds("danger", 0).x > eco.gold_bounds("battle", 0).y, "boss > danger > battle")
	check(eco.gold_for("rest", 0, 1) == 0 and eco.gold_for("shop", 0, 1) == 0 and eco.gold_for("zz", 0, 1) == 0, "rest / shop / event / unknown drop 0")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a: int = eco.gold_for("battle", 1, rng)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 5
	check(a == eco.gold_for("battle", 1, rng2), "gold_for accepts a RandomNumberGenerator (same state -> same gold)")

	# --- defaults and bad data ---
	var empty: EconomyConfig = EconomyConfig.from_dictionary({})
	check(empty.starting_gold() == 20 and empty.price_card("rare", 0) == 60 and empty.stock_counts()["cards"] == 3, "empty data -> DEFAULTS")
	var bad: EconomyConfig = EconomyConfig.from_dictionary({"starting_gold": -5, "variance": 7, "gold_floor_mult": [], "shop": {"card_prices": {"common": "x"}}})
	check(bad.starting_gold() == 0 and bad.gold_bounds("battle", 0) == Vector2i(0, 24), "bad data: negative gold -> 0, variance clamped to 1, empty mult list -> default")
	check(bad.price_card("common", 0) == 40, "bad data: a non-number price keeps the default")
	var custom: EconomyConfig = EconomyConfig.from_dictionary({"variance": 0.0, "gold_drops": {"battle": 100}, "gold_floor_mult": [2.0]})
	check(custom.gold_for("battle", 0, 1) == 200 and custom.gold_for("battle", 3, 9) == 200, "custom: variance 0, one multiplier row -> exact x2")
	check(EconomyConfig.load_from_file("res://assets/data/__missing__.json").starting_gold() == 20, "missing file -> DEFAULTS")

	# --- RunSession gold ---
	var s: RunSession = _session()
	check(s.gold == eco.starting_gold(), "a new run starts with starting_gold")
	check(s.add_gold(30) == 50 and s.gold == 50, "add_gold adds")
	s.add_gold(-10)
	s.add_gold(0)
	check(s.gold == 50, "add_gold ignores non-positive amounts")
	check(not s.spend_gold(51) and s.gold == 50, "spend_gold refuses when short and changes nothing")
	check(s.spend_gold(50) and s.gold == 0, "spend_gold spends exactly the balance")
	check(not s.spend_gold(1) and s.gold == 0, "gold never goes negative")
	check(s.spend_gold(0) and s.spend_gold(-3) and s.gold == 0, "spending nothing is a no-op success")

	# --- save round trip ---
	var gs: RunSession = _session()
	gs.add_gold(77)
	gs.shop_state = {"stock": [{"id": "x", "n": 1}], "used": ["heal"]}
	gs.event_state = {"event": "ban_tho_mau", "chosen": 1}
	var back: RunSession = _roundtrip(gs)
	check(back != null and back.gold == gs.gold, "save round trip keeps gold")
	check(back != null and back.shop_state.get("used") == ["heal"] and (back.shop_state["stock"] as Array).size() == 1, "save round trip keeps shop_state as is")
	check(back != null and back.event_state.get("event") == "ban_tho_mau", "save round trip keeps event_state as is")
	var old: Dictionary = gs.to_dict()
	old.erase("gold")
	old.erase("run_modifiers")
	old.erase("shop_state")
	old.erase("event_state")
	var legacy: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(old)), ChaptersConfig.load_from_file())
	check(legacy != null and legacy.gold == eco.starting_gold() and legacy.run_modifiers.is_empty() and legacy.shop_state.is_empty() and legacy.event_state.is_empty(),
		"a save without the keys -> starting_gold / [] / {} / {}")
	var neg: Dictionary = gs.to_dict()
	neg["gold"] = -40
	var clamped: RunSession = RunSession.from_dict(neg, ChaptersConfig.load_from_file())
	check(clamped != null and clamped.gold == 0, "a negative saved gold loads as 0")
	check(RunSession.SAVE_VERSION == 7, "SAVE_VERSION 7 (Story 038 bump after Story 035; the Story 033 keys stay optional)")

	# --- run modifiers ---
	var m: RunSession = _session()
	var pledge: Dictionary = {"id": "loi_the", "matches_left": 2, "params": {"step_cooldown": {"mul": 1.2}}}
	check(m.add_run_modifier(pledge) and m.run_modifiers.size() == 1 and m.has_run_modifier("loi_the"), "add_run_modifier stores the pledge")
	check(not m.add_run_modifier({"id": "", "matches_left": 2}) and not m.add_run_modifier({"id": "x", "matches_left": 0}) and m.run_modifiers.size() == 1, "an empty id or matches_left < 1 is refused")
	pledge["matches_left"] = 99
	check(int(m.run_modifiers[0]["matches_left"]) == 2, "the stored modifier is a copy")
	check(is_equal_approx(float(m.active_modifier_params("step_cooldown")["mul"]), 1.2), "active_modifier_params: step_cooldown mul 1.2")
	check(m.active_modifier_params("seal_sec").is_empty(), "a key no modifier touches -> {}")
	check(is_equal_approx(RelicRegistry.apply_override(0.4, m.run_modifier_overrides(), "step_cooldown"), 0.48), "the overrides table applies through RelicRegistry.apply_override (0.4 x 1.2)")
	var mid: RunSession = _roundtrip(m)
	check(mid != null and mid.run_modifiers.size() == 1 and int(mid.run_modifiers[0]["matches_left"]) == 2 and is_equal_approx(float(mid.active_modifier_params("step_cooldown")["mul"]), 1.2),
		"save round trip keeps run_modifiers (id, matches_left, params)")
	check(m.tick_run_modifiers().is_empty() and int(m.run_modifiers[0]["matches_left"]) == 1 and m.has_run_modifier("loi_the"), "after 1 match the pledge has 1 left")
	var gone: Array[String] = m.tick_run_modifiers()
	check(gone == ["loi_the"] and m.run_modifiers.is_empty() and m.active_modifier_params("step_cooldown").is_empty(), "a 2-match modifier ends after 2 matches")
	check(m.tick_run_modifiers().is_empty(), "ticking with no modifier is a no-op")
	var stack: RunSession = _session()
	stack.add_run_modifier({"id": "a", "matches_left": 1, "params": {"step_cooldown": {"mul": 1.5, "add": 0.1}}})
	stack.add_run_modifier({"id": "b", "matches_left": 3, "params": {"step_cooldown": {"mul": 2.0}}})
	var folded: Dictionary = stack.active_modifier_params("step_cooldown")
	check(is_equal_approx(float(folded["mul"]), 3.0) and is_equal_approx(float(folded["add"]), 0.1), "two modifiers fold like merge_overrides (mul product, add sum)")
	stack.tick_run_modifiers()
	check(stack.run_modifiers.size() == 1 and is_equal_approx(float(stack.active_modifier_params("step_cooldown")["mul"]), 2.0), "only the expired modifier drops")
	var junk: Dictionary = _session().to_dict()
	junk["run_modifiers"] = [{"id": "ok", "matches_left": 2.0, "params": {}}, {"id": "", "matches_left": 2}, {"id": "dead", "matches_left": 0}, "zz"]
	var cleaned: RunSession = RunSession.from_dict(junk, ChaptersConfig.load_from_file())
	check(cleaned != null and cleaned.run_modifiers.size() == 1 and cleaned.run_modifiers[0]["id"] == "ok", "bad saved modifiers are dropped")

	print("FAILS=", fails, " PASSES=", passes)
	quit(1 if fails > 0 else 0)

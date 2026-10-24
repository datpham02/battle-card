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


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _initialize() -> void:
	var cards: SkillConfig = SkillConfig.load_from_file()
	var cfg: Dictionary = RewardRoller.load_config()
	check(int(cfg["starting_removals"]) == 1 and float(cfg["luck_start"]) == 0.0 and float(cfg["luck_per_node"]) == 1.0 and _near(float(cfg["rest_heal_ratio"]), 0.3) and int(cfg["rest_forge_levels"]) == 1 and bool(cfg["allow_remove"]), "rewards.json new keys")
	check(RewardRoller.reward_for_node("battle", cfg) == {"offers": 3, "min_rarity": "common", "free": false, "removal_token": false}, "battle reward")
	check(RewardRoller.reward_for_node("danger", cfg)["offers"] == 3 and RewardRoller.reward_for_node("danger", cfg)["min_rarity"] == "common", "danger reward")
	var t: Dictionary = RewardRoller.reward_for_node("treasure", cfg)
	check(t["offers"] == 3 and t["free"] == true and t["min_rarity"] == "common", "treasure free")
	var mb: Dictionary = RewardRoller.reward_for_node("miniboss", cfg)
	check(mb["offers"] == 3 and mb["min_rarity"] == "rare" and mb["removal_token"] == false, "miniboss rare floor")
	var b: Dictionary = RewardRoller.reward_for_node("boss", cfg)
	check(b["offers"] == 3 and b["removal_token"] == true and b["min_rarity"] == "common", "boss token")
	check(RewardRoller.reward_for_node("rest", cfg)["offers"] == 0, "rest no cards")
	var w0: Dictionary = RewardRoller.luck_rarity_weights(cfg, 0.0)
	check(_near(w0["common"], 70) and _near(w0["rare"], 25) and _near(w0["epic"], 5), "luck 0")
	var w35: Dictionary = RewardRoller.luck_rarity_weights(cfg, 35.0)
	check(_near(w35["common"], 50.5) and _near(w35["rare"], 30.0) and _near(w35["epic"], 19.5), "luck 35 midpoint")
	var w70: Dictionary = RewardRoller.luck_rarity_weights(cfg, 70.0)
	check(_near(w70["common"], 31) and _near(w70["rare"], 35) and _near(w70["epic"], 34), "luck 70")
	var w200: Dictionary = RewardRoller.luck_rarity_weights(cfg, 200.0)
	check(_near(w200["common"], 31) and _near(w200["epic"], 34), "luck 200 clamps")
	check(_near(RewardRoller.luck_rarity_weights(cfg, -5.0)["common"], 70), "negative luck clamps")
	var none: Array[String] = []
	var a: Array[String] = RewardRoller.roll(cards, cfg, 42, none, {}, 12.0, "rare")
	var a2: Array[String] = RewardRoller.roll(cards, cfg, 42, none, {}, 12.0, "rare")
	check(a == a2 and a.size() == 3, "roll deterministic with luck + min_rarity")
	var all_rare: bool = true
	var distinct: bool = true
	for sd: int in 500:
		var o: Array[String] = RewardRoller.roll(cards, cfg, sd, none, {}, float(sd % 70), "rare")
		var seen: Dictionary = {}
		for id: String in o:
			seen[id] = true
			if cards.get_rarity(id) == "common":
				all_rare = false
		if o.size() != 3 or seen.size() != 3:
			distinct = false
	check(all_rare and distinct, "min_rarity rare gives rare+ only, 3 distinct (500 seeds)")
	check(RewardRoller.roll(cards, cfg, 7) == RewardRoller.roll(cards, cfg, 7, none, {}, 0.0, "common"), "defaults == luck 0 common")
	var epic_lo: int = 0
	var epic_hi: int = 0
	for sd: int in 1000:
		for id: String in RewardRoller.roll(cards, cfg, sd, none, {}, 0.0):
			if cards.get_rarity(id) == "epic":
				epic_lo += 1
		for id: String in RewardRoller.roll(cards, cfg, sd, none, {}, 70.0):
			if cards.get_rarity(id) == "epic":
				epic_hi += 1
	check(epic_hi > epic_lo * 2, "epic share grows with luck (%d -> %d)" % [epic_lo, epic_hi])
	var tiny: Dictionary = {"rarity_weights": {"common": 70, "rare": 0, "epic": 0}}
	var top: Array[String] = RewardRoller.roll(cards, tiny, 3, none, {}, 0.0, "rare")
	check(top.size() == 3, "min_rarity unreachable tops up from the pool (%d)" % top.size())
	var bad: Dictionary = RewardRoller.clean_config({
		"starting_removals": -4, "luck_per_node": -1, "luck_start": -2, "rest_heal_ratio": 9, "rest_forge_levels": 0,
		"rarity_weights_at_luck": {"x": [1, 2, 3], "5": [1, 2]},
		"node_rewards": {"miniboss": {"min_rarity": "mythic", "offers": -3}, "boss": 5},
	})
	check(bad["starting_removals"] == 0 and bad["luck_per_node"] == 0.0 and bad["luck_start"] == 0.0 and _near(bad["rest_heal_ratio"], 1.0) and bad["rest_forge_levels"] == 1, "numeric clamps")
	check(_near(RewardRoller.luck_rarity_weights(bad, 70)["epic"], 34), "all-bad anchors keep defaults")
	check(bad["node_rewards"]["miniboss"]["min_rarity"] == "rare" and bad["node_rewards"]["miniboss"]["offers"] == 0 and bad["node_rewards"]["boss"]["removal_token"] == true, "node_rewards fallbacks")
	var ok_a: Dictionary = RewardRoller.clean_config({"rarity_weights_at_luck": {"0": [1, 1, 1], "10": [3, 1, 1]}})
	check(_near(RewardRoller.luck_rarity_weights(ok_a, 5)["common"], 2.0), "custom anchors interpolate")
	var flat: Dictionary = RewardRoller.clean_config({"rarity_weights": {"common": 1, "rare": 0, "epic": 0}})
	check(_near(RewardRoller.luck_rarity_weights(flat, 50)["common"], 1.0) and _near(RewardRoller.luck_rarity_weights(flat, 50)["rare"], 0.0), "custom rarity_weights without anchors is flat")
	check(RewardRoller.reward_for_node("weird", cfg)["offers"] == 3, "unknown kind -> battle")
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)

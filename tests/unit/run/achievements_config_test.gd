extends SceneTree
## Story 037: AchievementsConfig - loads the 22 shipped achievements, reward ownership, locked content, bad entries dropped.

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _good(id: String, rewards: Array = []) -> Dictionary:
	return {"id": id, "name_key": "achievement.%s.name" % id, "desc_key": "achievement.%s.desc" % id,
		"condition": {"type": "milestone", "params": {"key": "k", "min": 1}}, "rewards": rewards, "hidden": false}


func _init() -> void:
	var cfg: AchievementsConfig = AchievementsConfig.load_from_file()
	var ids: Array[String] = cfg.ids()
	_check("loads 24 achievements (22 of Story 037 + 2 of Story 039)", ids.size() == 24, str(ids.size()))
	_check("file order starts with first_region_boss, small_deck is 22nd, the Story 039 pair ends the file", ids[0] == "first_region_boss" and ids[21] == "small_deck" and ids[22] == "reach_floor_4" and ids[23] == "reach_floor_5")
	_check("shared() is cached", AchievementsConfig.shared() == AchievementsConfig.shared() and AchievementsConfig.shared().ids().size() == 24)
	_check("has", cfg.has("hunter_path") and not cfg.has("nope"))
	var d: Dictionary = cfg.get_def("hunter_path")
	_check("get_def fields", d["id"] == "hunter_path" and d["name_key"] == "achievement.hunter_path.name" and d["desc_key"] == "achievement.hunter_path.desc"
		and d["condition"] == {"type": "milestone", "params": {"key": "kills_total", "min": 3}} and d["rewards"] == [{"kind": "character", "id": "tho_san"}] and d["hidden"] == false, str(d))
	_check("get_def unknown -> {}", cfg.get_def("nope").is_empty())
	d["rewards"].clear()
	_check("get_def is a copy", (cfg.get_def("hunter_path")["rewards"] as Array).size() == 1)
	var hidden: Array[String] = []
	for id: String in ids:
		if bool(cfg.get_def(id)["hidden"]):
			hidden.append(id)
	_check("hidden: no_hit_boss, zone_trap, small_deck", hidden.size() == 3 and hidden.has("no_hit_boss") and hidden.has("zone_trap") and hidden.has("small_deck"), str(hidden))
	var types: Dictionary = {}
	for id: String in ids:
		types[cfg.get_def(id)["condition"]["type"]] = true
	_check("all 8 condition types used (Story 039: + best_floor)", types.size() == 8, str(types.keys()))

	# --- reward owner / is_unlocked
	_check("reward_owner of locked content", cfg.reward_owner("card", "gai_doc") == "first_region_boss" and cfg.reward_owner("character", "giao_si") == "mercy_path"
		and cfg.reward_owner("piece", "v5") == "boss_forest" and cfg.reward_owner("relic", "han_ky") == "frost_burst_5")
	_check("reward_owner of open content = \"\"", cfg.reward_owner("card", "kiem_khi") == "" and cfg.reward_owner("character", "kiem_si") == "" and cfg.reward_owner("card", "") == "")
	_check("reward_owner is kind-sensitive", cfg.reward_owner("relic", "gai_doc") == "")
	var p := ProgressState.new()
	_check("is_unlocked: open content true, locked false", cfg.is_unlocked("card", "kiem_khi", p) and not cfg.is_unlocked("card", "gai_doc", p) and not cfg.is_unlocked("character", "tho_san", p))
	_check("is_unlocked with null progress: locked stays locked", not cfg.is_unlocked("card", "gai_doc", null) and cfg.is_unlocked("card", "kiem_khi", null))
	p.add_achievement("first_region_boss")
	_check("is_unlocked after the owner is earned", cfg.is_unlocked("card", "gai_doc", p) and not cfg.is_unlocked("card", "gai_nguyen", p))

	# --- locked_content
	var empty := ProgressState.new()
	var locked: Dictionary = cfg.locked_content(empty)
	_check("locked_content kinds = card, piece, relic, character, region (Story 039: hellfire, sky_isles)", locked.keys().size() == 5 and (locked.get("region", []) as Array) == ["hellfire", "sky_isles"], str(locked))
	_check("locked cards", (locked["card"] as Array) == ["gai_doc", "bang_tam", "gai_nguyen", "thanh_thuy"], str(locked["card"]))
	_check("locked pieces", (locked["piece"] as Array) == ["w5", "v5", "n5"], str(locked["piece"]))
	_check("locked relics", (locked["relic"] as Array) == ["tui_rong", "phong_an", "gai_ran", "han_ky"], str(locked["relic"]))
	_check("locked characters", (locked["character"] as Array) == ["tho_san", "giao_si"], str(locked["character"]))
	var part: Dictionary = cfg.locked_content(p)
	_check("locked_content shrinks once an owner is earned", not (part["card"] as Array).has("gai_doc") and (part["card"] as Array).size() == 3)
	var all := ProgressState.new()
	all.mark_all_unlocked(cfg, [])
	_check("nothing locked when every achievement is earned", cfg.locked_content(all).is_empty())

	# --- rewards_of
	var r: Array[Dictionary] = cfg.rewards_of(["hunter_path", "win_kiem_si", "boss_forest", "nope"])
	_check("rewards_of flat list, skips empty and unknown", r == [{"kind": "character", "id": "tho_san", "achievement": "hunter_path"}, {"kind": "piece", "id": "v5", "achievement": "boss_forest"}], str(r))
	_check("all_rewards = 15 rewards (4 cards, 3 pieces, 4 relics, 2 characters, 2 regions)", cfg.all_rewards().size() == 15, str(cfg.all_rewards().size()))

	# --- bad entries dropped
	var bad: AchievementsConfig = AchievementsConfig.from_dictionary({"achievements": [
		_good("ok1", [{"kind": "card", "id": "c1"}]),
		5,
		{"name_key": "x"},
		_good("ok1"),
		{"id": "bad_type", "condition": {"type": "nope", "params": {}}, "rewards": []},
		{"id": "no_cond", "rewards": []},
		{"id": "bad_param", "condition": {"type": "milestone", "params": {"key": "k"}}, "rewards": []},
		{"id": "zero_min", "condition": {"type": "milestone", "params": {"key": "k", "min": 0}}, "rewards": []},
		{"id": "bad_kind", "condition": {"type": "boss_clear_no_hit", "params": {}}, "rewards": [{"kind": "hat", "id": "x"}]},
		{"id": "empty_reward", "condition": {"type": "boss_clear_no_hit", "params": {}}, "rewards": [{"kind": "card", "id": ""}]},
		{"id": "same_reward", "condition": {"type": "boss_clear_no_hit", "params": {}}, "rewards": [{"kind": "card", "id": "c1"}]},
		{"id": "rewards_not_array", "condition": {"type": "boss_clear_no_hit", "params": {}}, "rewards": "x"},
		_good("ok2", [{"kind": "relic", "id": "r1"}, {"kind": "piece", "id": "p1"}]),
		{"id": "ok3", "condition": {"type": "run_won_deck_max", "params": {"max": 8}}},
	]})
	_check("bad entries dropped, good kept in order", bad.ids() == (["ok1", "ok2", "ok3"] as Array[String]), str(bad.ids()))
	_check("a dropped entry's reward does not leak", bad.reward_owner("card", "c1") == "ok1" and bad.reward_owner("card", "x") == "" and bad.reward_owner("relic", "r1") == "ok2")
	_check("missing keys get default keys and hidden false", bad.get_def("ok3")["name_key"] == "achievement.ok3.name" and bad.get_def("ok3")["hidden"] == false and (bad.get_def("ok3")["rewards"] as Array).is_empty())
	_check("not an array / empty dictionary -> empty config", AchievementsConfig.from_dictionary({"achievements": "x"}).ids().is_empty() and AchievementsConfig.from_dictionary({}).ids().is_empty())
	_check("missing file -> empty config", AchievementsConfig.load_from_file("res://nope/nothing.json").ids().is_empty())

	print("FAILS=", fails)
	quit(fails)

extends SceneTree
## World Map v2 U2: region_rules.json loads; hellfire is v2 with the Heat rule, every other region v1 with no rule;
## gauge steps and clamps; the combat patch rows by gauge (exact row, nearest lower row); tier bonus; warden hook;
## defaults when the file is missing or parts are bad.
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/region_rules_config_test.gd

var fails: int = 0


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _initialize() -> void:
	var r: RegionRules = RegionRules.load_from_file()
	check(r.depth_layout == ([1, 3, 3, 1, 3, 2, 1] as Array[int]), "depth_layout is the approved [1,3,3,1,3,2,1]")
	check(r.uses_v2("hellfire") and r.rule_id_for("hellfire") == "heat", "hellfire: v2 + heat")
	for id: String in ["ch1", "desert", "swamp", "ch2", "ch3", "sky_isles", "an_dai"]:
		check(not r.uses_v2(id) and r.rule_id_for(id).is_empty(), "%s stays v1 with no active rule" % id)
	check(not r.uses_v2("unknown_region") and r.rule_for("unknown_region").is_empty(), "unknown region -> v1, no rule")
	check(r.modifier_pool("hellfire") == (["big_hands", "quick_blocks", "thorn_field", "seal_caster", "vent_surge"] as Array[String]), "hellfire modifier pool as shipped")
	check(r.archetype_weights("hellfire") == {"peril": 1.5}, "hellfire raises peril")
	check(r.modifier("big_hands").has("match") and r.modifier("vent_surge").has("trait") and r.modifier("nope").is_empty(), "modifier catalogue entries")

	var heat: Dictionary = r.rule_for("hellfire")
	check(RegionRules.has_gauge(heat) and RegionRules.gauge_start(heat) == 0, "heat has a gauge starting at 0")
	var g: int = 0
	g = RegionRules.gauge_after(heat, g, "battle")
	check(g == 1, "battle +1 -> 1")
	g = RegionRules.gauge_after(heat, g, "miniboss")
	check(g == 3, "miniboss +2 -> 3")
	g = RegionRules.gauge_after(heat, g, "danger")
	g = RegionRules.gauge_after(heat, g, "danger")
	check(g == 4, "clamped at 4")
	g = RegionRules.gauge_after(heat, g, "rest")
	check(g == 2, "rest -2 -> 2")
	g = RegionRules.gauge_after(heat, g, "shop")
	check(g == 1, "shop -1 -> 1")
	check(RegionRules.gauge_after(heat, 0, "shop") == 0, "clamped at 0")
	check(RegionRules.gauge_after(heat, 2, "forge") == 2 and RegionRules.gauge_after(heat, 2, "event") == 2 and RegionRules.gauge_after(heat, 2, "treasure") == 2, "forge / event / treasure leave heat alone")
	check(RegionRules.gauge_after({}, 7, "battle") == 7, "no rule -> gauge unchanged")

	check(RegionRules.combat_patch(heat, 0).is_empty(), "heat 0: no patch")
	check(RegionRules.combat_patch(heat, 1) == {"vent_interval_sec": 6.0}, "heat 1: vent 6 s")
	check(RegionRules.combat_patch(heat, 2) == {"vent_interval_sec": 5.0}, "heat 2: vent 5 s")
	var p3: Dictionary = RegionRules.combat_patch(heat, 3)
	check(p3.get("vent_interval_sec") == 4.5 and p3.get("vent_tick_damage") == 3.0 and p3.get("boss_drop_interval_mult") == 0.9 and not p3.has("traits"), "heat 3: vent 4.5 s, tick 3, enemy drops x0.9, no surge")
	check(not p3.has("vent_sec"), "heat 3: eruption length untouched (B1 2026-11-12: the 2.5 s burn is heat 4 only)")
	var p4: Dictionary = RegionRules.combat_patch(heat, 4)
	check(p4.get("vent_interval_sec") == 4.0 and (p4.get("traits", []) as Array).size() == 1 and (p4["traits"][0] as Dictionary)["id"] == "vent_surge", "heat 4: vent 4 s + vent_surge trait")
	check(p4.get("vent_sec") == 2.5 and p4.get("vent_tick_damage") == 3.0 and p4.get("boss_drop_interval_mult") == 0.9 and not p4.has("vent_warn_sec"), "heat 4: eruptions burn 2.5 s (B1), tick 3, drops x0.9, warning untouched")
	check(RegionRules.combat_patch(heat, 9) == p4, "above the last row: nearest lower row")
	for key: Variant in p4.keys():
		check(str(key) == "traits" or RunConfig.HAZARD_OVERRIDE_KEYS.has(str(key)) or RegionRules.PATCH_MULT_KEYS.has(str(key)), "patch key %s is a combat key" % key)
	check(RegionRules.tier_bonus(heat, 2) == 0 and RegionRules.tier_bonus(heat, 3) == 1 and RegionRules.tier_bonus(heat, 4) == 1, "tier bonus from heat 3")
	check(RegionRules.warden_hook(heat, 2).is_empty(), "warden hook: nothing at heat 2")
	var hook3: Dictionary = RegionRules.warden_hook(heat, 3)
	check(hook3 == {"vent_surge": {"interval_sec": 7.0, "first_delay_sec": 10.0}} and RegionRules.warden_hook(heat, 4) == hook3, "warden hook at heat 3 and 4: vent_surge interval 7 s, first surge at 10 s (B1 2026-11-12)")
	check(not (hook3["vent_surge"] as Dictionary).has("vents"), "warden hook never sets vents (the caldera has 2 per half; a higher count is clamped)")

	var missing: RegionRules = RegionRules.load_from_file("res://assets/data/does_not_exist.json")
	check(not missing.uses_v2("hellfire") and missing.rule_for("hellfire").is_empty() and missing.depth_layout == RegionRules.DEFAULT_DEPTH_LAYOUT, "missing file -> every region v1, no rule, default layout")
	var bad: RegionRules = RegionRules.from_dictionary({
		"depth_layout": [1, 0], "modifiers": {"x": {"nothing": 1}, "ok": {"match": {"boss_min_runes_add": 1}}},
		"rules": {"r": {"gauge": {"min": 0, "max": -1}, "combat_effect": {"by_gauge": {"a": {}, "1": {"typo_key": 3, "vent_sec": 1.5}}}}},
		"regions": {"ch1": {"map_gen": "v3", "rule": "ghost", "modifier_pool": ["x", "ok", "nope"]}}})
	check(bad.depth_layout == RegionRules.DEFAULT_DEPTH_LAYOUT, "bad depth_layout -> default")
	check(bad.modifier_ids() == (["ok"] as Array[String]), "modifier without trait/match/arena dropped")
	check(not bad.uses_v2("ch1") and bad.rule_id_for("ch1").is_empty(), "unknown map_gen -> v1; unknown rule -> none")
	check(bad.modifier_pool("ch1") == (["ok"] as Array[String]), "unknown modifiers dropped from the pool")
	var rr: Dictionary = bad.rule("r")
	check(int(rr["gauge"]["max"]) == 0, "gauge max < min -> min")
	check(RegionRules.combat_patch(rr, 1) == {"vent_sec": 1.5}, "typo patch key dropped, valid hazard key kept, non-integer gauge key dropped")
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

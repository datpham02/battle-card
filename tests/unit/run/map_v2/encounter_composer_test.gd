extends SceneTree
## World Map v2 U13-U17: EncounterComposer profiles (modifiers from the catalogue, the Heat rule by gauge, the warden
## hook, dedupe against the match's own traits), preview masking, RunConfig.from_node with an empty profile byte-equal to
## today and with a profile applying the patch after the danger traits, objective evaluation, and every catalogue
## modifier resolving to a registered trait id or a whitelisted match / arena key.
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/encounter_composer_test.gd

var fails: int = 0
var cfg: ChaptersConfig


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _trait_ids(m: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for t: Variant in m.get("traits", []):
		out.append(str((t as Dictionary).get("id", "")))
	return out


func _initialize() -> void:
	cfg = ChaptersConfig.load_from_file()
	var rules: RegionRules = RegionRules.shared()
	# U13 — profile of a peril node with two modifiers at heat 0, 3 and 4.
	var node: Dictionary = MapGraph.clean_node({"id": "L0.4", "depth": 4, "lane": "L0", "slot": "lane", "kind": "danger", "match_id": "magma_slug",
		"reward_tier": 3, "modifiers": ["big_hands", "thorn_field", "ghost_mod"], "objective": "no_hit_3"})
	var p0: Dictionary = EncounterComposer.profile(node, "hellfire", 0)
	check(p0["modifiers"] == (["big_hands", "thorn_field"] as Array[String]), "U13 unknown modifier dropped, known kept")
	check(p0["match_patch"].get("boss_min_runes_add") == 1.0 and _trait_ids(p0["match_patch"]) == (["thorn_field"] as Array[String]), "U13 big_hands -> boss_min_runes_add, thorn_field -> trait")
	check(int(p0["reward_tier"]) == 3 and p0["objective"]["stat"] == "hits_taken" and p0["rule_id"] == "heat", "U13 tier, objective and rule carried")
	var p3: Dictionary = EncounterComposer.profile(node, "hellfire", 3)
	check(p3["match_patch"].get("vent_interval_sec") == 4.5 and p3["match_patch"].get("vent_tick_damage") == 3.0 and p3["match_patch"].get("boss_drop_interval_mult") == 0.9, "U13 heat 3 patch merged (vent 4.5 s, tick 3, drops x0.9)")
	var p4: Dictionary = EncounterComposer.profile(node, "hellfire", 4)
	check(_trait_ids(p4["match_patch"]) == (["thorn_field", "vent_surge"] as Array[String]), "U13 heat 4 adds vent_surge after the modifier traits")
	var node_tier2: Dictionary = MapGraph.clean_node({"id": "L0.1", "kind": "danger", "match_id": "ash_golem", "reward_tier": 2})
	check(int(EncounterComposer.profile(node_tier2, "hellfire", 2)["reward_tier"]) == 2 and int(EncounterComposer.profile(node_tier2, "hellfire", 3)["reward_tier"]) == 3, "U13 heat 3 lifts the reward tier by one (cap 3)")
	var rest: Dictionary = MapGraph.clean_node({"id": "a1", "slot": "prepare", "kind": "rest"})
	var pr: Dictionary = EncounterComposer.profile(rest, "hellfire", 4)
	check(pr["match_patch"].is_empty() and int(pr["reward_tier"]) == 1, "U13 a non-fight node gets no patch and tier 1")
	var warden: Dictionary = MapGraph.clean_node({"id": "w", "slot": "warden", "kind": "boss", "match_id": "inferno_lord"})
	var pw3: Dictionary = EncounterComposer.profile(warden, "hellfire", 3)
	var pw2: Dictionary = EncounterComposer.profile(warden, "hellfire", 2)
	var pw4: Dictionary = EncounterComposer.profile(warden, "hellfire", 4)
	check(pw3["match_patch"].get("trait_params") == {"vent_surge": {"interval_sec": 7.0, "first_delay_sec": 10.0}} and pw4["match_patch"].get("trait_params") == pw3["match_patch"].get("trait_params") and not pw2["match_patch"].has("trait_params"), "U13 warden hook at heat 3 and 4 (surge 7 s, first at 10 s), not at 2")
	check(pw4["match_patch"].get("vent_sec") == 2.5 and not pw3["match_patch"].has("vent_sec") and not pw2["match_patch"].has("vent_sec"), "U13 heat 4 burns 2.5 s; heat 3 and 2 keep the base eruption")
	var v1node: Dictionary = MapGraph.clean_node({"id": "c1n0", "slot": "v1", "kind": "battle", "match_id": "imp", "tags": ["v1"]})
	check(EncounterComposer.profile(v1node, "ch1", 0)["match_patch"].is_empty(), "U13 a v1 node in a rule-less region gets an empty patch")

	# U15 — RunConfig.from_node: empty profile byte-equal; a profile applies after the danger traits.
	var base: RunConfig = RunConfig.from_node(cfg, "hellfire", "magma_slug", "danger", 123, 1, 0)
	var same: RunConfig = RunConfig.from_node(cfg, "hellfire", "magma_slug", "danger", 123, 1, 0, {})
	check(base.matches == same.matches, "U15 empty profile -> from_node byte-equal to today")
	var with: RunConfig = RunConfig.from_node(cfg, "hellfire", "magma_slug", "danger", 123, 1, 0, p4)
	var m: Dictionary = with.matches[0]
	check(_trait_ids(m) == (["row_burner", "thorn_field", "vent_surge"] as Array[String]), "U15 danger trait first, then the profile's traits: %s" % str(_trait_ids(m)))
	check(float(m["vent_interval_sec"]) == 4.0 and float(m["vent_tick_damage"]) == 3.0, "U15 hazard overrides reach the cleaned match")
	check(is_equal_approx(float(m["boss_drop_interval_mult"]), float(base.matches[0]["boss_drop_interval_mult"]) * 0.9), "U15 boss_drop_interval_mult multiplied")
	check(int(m["boss_min_runes"]) == int(base.matches[0]["boss_min_runes"]) + 1, "U15 boss_min_runes_add resolved after scaling")
	var w_cfg: RunConfig = RunConfig.from_node(cfg, "hellfire", "inferno_lord", "boss", 5, 1, 0, pw3)
	var surge: Dictionary = {}
	for t: Variant in w_cfg.matches[0]["traits"]:
		if (t as Dictionary)["id"] == "vent_surge":
			surge = t
	check(not surge.is_empty() and float(surge["params"]["interval_sec"]) == 7.0 and float(surge["params"]["first_delay_sec"]) == 10.0 and float(surge["params"]["vents"]) == 2.0, "U15 warden hook sets interval 7 / first delay 10 on the existing vent_surge and keeps its vents 2 (B1)")
	var w2_cfg: RunConfig = RunConfig.from_node(cfg, "hellfire", "inferno_lord", "boss", 5, 1, 0, pw2)
	var surge2: Dictionary = {}
	for t: Variant in w2_cfg.matches[0]["traits"]:
		if (t as Dictionary)["id"] == "vent_surge":
			surge2 = t
	check(not surge2.is_empty() and surge2["params"] == {"interval_sec": 10.0, "vents": 2.0} and not w2_cfg.matches[0].has("vent_sec") and not base.matches[0].has("vent_sec"), "U15 heat 2 warden: the boss's own surge (10 s, 2 vents) and the base eruption length")
	var w4_cfg: RunConfig = RunConfig.from_node(cfg, "hellfire", "inferno_lord", "boss", 5, 1, 0, pw4)
	check(float(w4_cfg.matches[0]["vent_sec"]) == 2.5 and not w4_cfg.matches[0].has("vent_warn_sec"), "U15 heat 4 warden: eruptions 2.5 s, warning unchanged")
	var raw_arena: Dictionary = {"arena": {"shape": "forge"}, "traits": []}
	EncounterComposer.apply_to_raw(raw_arena, {"arena_patch": {"variant": true}, "match_patch": {"typo": 1}})
	check(raw_arena["arena"] == {"shape": "forge", "variant": true}, "U15 arena patch sets the variant flag; a non-combat key is ignored")

	# U16 — objectives.
	var arch: RouteArchetypes = RouteArchetypes.shared()
	check(EncounterComposer.objective_met(arch.objective("no_hit_3"), {"hits_taken": 3}) and not EncounterComposer.objective_met(arch.objective("no_hit_3"), {"hits_taken": 4}), "U16 no_hit_3 <= 3")
	check(EncounterComposer.objective_met(arch.objective("big_cast"), {"max_cast_cells": 4}) and not EncounterComposer.objective_met(arch.objective("big_cast"), {}), "U16 big_cast >= 4; a missing counter is never met")
	check(EncounterComposer.objective_met(arch.objective("vent_dancer"), {"vents_dodged": 2}) and not EncounterComposer.objective_met({}, {"vents_dodged": 9}), "U16 vent_dancer >= 2; {} never met")

	# U17 — catalogue.
	var ok: bool = true
	for id: String in rules.modifier_ids():
		var cat: Dictionary = rules.modifier(id)
		if cat.has("trait") and not TraitRegistry.SCRIPTS.has(str((cat["trait"] as Dictionary).get("id", ""))):
			ok = false
		if cat.has("match"):
			for k: Variant in (cat["match"] as Dictionary).keys():
				if not (RunConfig.HAZARD_OVERRIDE_KEYS.has(str(k)) or RegionRules.PATCH_MULT_KEYS.has(str(k)) or RegionRules.PATCH_ADD_KEYS.has(str(k))):
					ok = false
		if cat.has("arena") and (cat["arena"] as Dictionary).keys() != ["variant"]:
			ok = false
	check(ok, "U17 every modifier resolves to a registered trait or a whitelisted match / arena key (%d modifiers)" % rules.modifier_ids().size())

	# U14 — preview.
	var g: MapGraph = cfg.generate_region_graph("hellfire", 2002, 1, 1)
	var pid: String = ""
	for id: String in g.node_ids():
		if g.nodes[id]["slot"] == "lane" and MapGraph.MATCH_KINDS.has(str(g.nodes[id]["kind"])):
			pid = id
			break
	var n: Dictionary = g.node(pid)
	var prof: Dictionary = EncounterComposer.profile(n, "hellfire", 2)
	var shown: Dictionary = EncounterComposer.preview(n, prof, "hellfire", false, cfg, g)
	var hidden: Dictionary = EncounterComposer.preview(n, prof, "hellfire", true, cfg, g)
	check(shown["enemy_name_key"] == "boss.%s.name" % n["match_id"] and not str(shown["arena_shape"]).is_empty() and shown["archetype"] == g.archetype_of(pid), "U14 preview names the enemy, arena and archetype")
	check(int(shown["gauge"]) == 2 and int(shown["gauge_after"]) == 3, "U14 preview shows heat before (2) and after (3) a fight")
	check(hidden["enemy_name_key"] == "" and hidden["arena_shape"] == "" and (hidden["modifiers"] as Array).is_empty() and hidden["kind"] == n["kind"] and int(hidden["reward_tier"]) == int(shown["reward_tier"]), "U14 hidden preview blanks enemy / arena / modifiers, keeps kind and tier")
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

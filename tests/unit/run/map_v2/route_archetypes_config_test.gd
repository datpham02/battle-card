extends SceneTree
## World Map v2 U3: route_archetypes.json loads the five approved templates with their slots, tiers, weights and floors;
## the guarantee list, hub kinds, the gamble rule, the objective catalogue; a missing file equals the shipped file.
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/route_archetypes_config_test.gd

var fails: int = 0


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _initialize() -> void:
	var a: RouteArchetypes = RouteArchetypes.load_from_file()
	check(a.ids() == (["elite", "mystery", "peril", "safe", "treasure"] as Array[String]), "five archetypes: %s" % str(a.ids()))
	for id: String in a.ids():
		check((a.template(id)["slots"] as Array).size() == 3 and (a.template(id)["modifier_slots"] as Array).size() == 3, "%s has 3 slots and 3 modifier counts" % id)
	var safe: Dictionary = a.template("safe")
	check(int(safe["slots"][0]["tier_delta"]) == -1 and safe["slots"][2]["kind"] == (["rest", "battle"] as Array[String]), "safe: first fight one tier easier, last slot rest-or-battle")
	var treasure: Dictionary = a.template("treasure")
	check(treasure["slots"][1]["kind"] == (["treasure"] as Array[String]) and treasure["slots"][2]["kind"] == (["battle", "forge"] as Array[String]) and float(treasure["slots"][2]["gold_mult"]) == 1.5, "treasure: chest in the middle, battle-or-forge last with gold x1.5")
	var peril: Dictionary = a.template("peril")
	check(int(peril["min_floor"]) == 2 and peril["modifier_slots"] == ([0, 1, 1] as Array[int]) and bool(peril["slots"][2]["objective"]) and int(peril["slots"][2]["reward_tier"]) == 3, "peril: floor 2+, 0/1/1 modifiers (tuned 2026-11-12), objective on the last slot at tier 3")
	var elite: Dictionary = a.template("elite")
	check(elite["slots"][1]["kind"] == (["miniboss"] as Array[String]) and int(elite["slots"][1]["relic_offer"]) == 1 and int(elite["min_floor"]) == 2, "elite: miniboss in the middle with a relic offer, floor 2+")
	check(a.template("mystery")["slots"][0]["kind"] == (["event"] as Array[String]), "mystery opens with an event")
	check(a.template("nope").is_empty(), "unknown archetype -> {}")
	check(is_equal_approx(a.weight("safe"), 1.0) and is_equal_approx(a.weight("elite"), 0.8) and is_equal_approx(a.weight("peril", {"peril": 1.5}), 1.5) and a.weight("nope") == 0.0, "weights with a region override")
	check(a.min_floor("safe") == 1 and a.min_floor("elite") == 2, "min floors")
	check(a.guarantee() == (["safe", "treasure"] as Array[String]), "guarantee list")
	check(a.hub_kinds() == (["rest", "event"] as Array[String]), "hub kinds")
	check(a.gamble() == {"kind": "miniboss", "min_floor": 2, "before_min_floor": "event"}, "gamble rule")
	check(a.objective_ids("hellfire") == (["big_cast", "joiner", "no_hit_3", "vent_dancer"] as Array[String]), "hellfire objectives include vent_dancer")
	check(a.objective_ids("ch1") == (["big_cast", "joiner", "no_hit_3"] as Array[String]), "vent_dancer is hellfire-only")
	check(a.objective("no_hit_3")["stat"] == "hits_taken" and a.objective("no_hit_3")["op"] == "<=" and a.objective("no_hit_3")["value"] == 3.0, "objective record")
	check(a.objective_bonus() == {"gold_mult": 1.3, "relic_offer": 1}, "objective bonus")

	var missing: RouteArchetypes = RouteArchetypes.load_from_file("res://assets/data/does_not_exist.json")
	var same: bool = missing.ids() == a.ids()
	for id: String in a.ids():
		if missing.template(id) != a.template(id):
			same = false
	check(same, "the built-in templates equal the shipped file")
	var bad: RouteArchetypes = RouteArchetypes.from_dictionary({"archetypes": {"two": {"slots": [{"kind": "battle"}, {"kind": "battle"}]}, "ok": {"slots": [{"kind": "zzz"}, {"kind": "battle"}, {"kind": "battle"}, {"kind": "rest"}]}}})
	check(bad.ids() == (["ok"] as Array[String]) and (bad.template("ok")["slots"] as Array).size() == 3, "a template with the wrong slot count is dropped; an unknown kind inside a slot drops that slot")
	var none: RouteArchetypes = RouteArchetypes.from_dictionary({"archetypes": {}})
	check(none.ids().size() == 5, "no valid template at all -> the built-in five")
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

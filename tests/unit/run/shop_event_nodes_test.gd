extends SceneTree
## Story 033 Part B/C: the shop and event node kinds of the region generator (chapters.json
## `world.special_nodes`, ChapterMapGen._apply_special_nodes, WorldMapGen.shop_floors): at most 1 shop and
## 1 event per region, at least 2 shops per run on two different floors (200 seeds), old maps unchanged.

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _count(map: Array[Dictionary], kind: String) -> int:
	var n: int = 0
	for col: Dictionary in map:
		for node: Dictionary in col["nodes"]:
			if node["kind"] == kind:
				n += 1
	return n


func _initialize() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var special: Dictionary = cfg.special_nodes()
	check(int(special["guaranteed_shops"]) >= 2 and float(special["shop_weight"]) >= 0.0 and float(special["event_weight"]) > 0.0,
		"chapters.json world.special_nodes: event weight > 0, shop weight >= 0, at least 2 guaranteed shops")
	check(ChapterMapGen.KINDS.has("shop") and ChapterMapGen.KINDS.has("event") and not ChapterMapGen.MATCH_KINDS.has("shop")
		and not ChapterMapGen.MATCH_KINDS.has("event"), "shop / event are node kinds without a match")

	# --- 200 seeded runs: walk 5 floors through the offers ---
	var per_region_ok: bool = true
	var two_shops_ok: bool = true
	var plan_ok: bool = true
	var empty_match_ok: bool = true
	var fight_kept_ok: bool = true
	var frame_ok: bool = true
	var regions: int = 0
	var shops: int = 0
	var events: int = 0
	var floors: int = cfg.world_floors()
	for s: int in 200:
		var plan: Array[int] = cfg.shop_floors(s)
		if plan.size() < 2 or plan[0] == plan[1]:
			plan_ok = false
		var path: Array[String] = []
		var shop_floors: Dictionary = {}
		for f: int in floors:
			var offer: Array[String] = WorldMapGen.offer_for_floor(cfg.region_ids(), s, f, path)
			var rid: String = offer[s % offer.size()]
			path.append(rid)
			var map: Array[Dictionary] = cfg.generate_region_map(rid, s, f, 1)
			regions += 1
			var n_shop: int = _count(map, "shop")
			var n_event: int = _count(map, "event")
			shops += n_shop
			events += n_event
			if n_shop > 1 or n_event > 1:
				per_region_ok = false
			if n_shop > 0:
				shop_floors[f] = true
			if plan.has(f) and n_shop != 1:
				plan_ok = false
			var mid: Array = map[1]["nodes"]
			if map.size() != 3 or mid.size() < 2 or mid.size() > 3:
				frame_ok = false
			var fights: int = 0
			for node: Dictionary in mid:
				if ChapterMapGen.REPLACEABLE_KINDS.has(str(node["kind"])):
					fights += 1
				if (node["kind"] == "shop" or node["kind"] == "event") and str(node["match_id"]) != "":
					empty_match_ok = false
			if not plan.has(f) and fights < 1:
				fight_kept_ok = false
		if shop_floors.size() < 2:
			two_shops_ok = false
	check(per_region_ok, "200 runs: at most 1 shop and 1 event per region")
	check(two_shops_ok, "200 runs: at least 2 shops per run, on two different floors")
	check(plan_ok, "the shop plan holds 2 different floors and each of them has its shop")
	check(empty_match_ok, "shop / event nodes have an empty match_id")
	check(fight_kept_ok, "outside a planned shop floor the middle column keeps at least one fight")
	check(frame_ok, "the region frame keeps 3 columns and 2..3 middle nodes")
	check(events > regions / 10 and shops > regions * 2 / 5, "shops and events actually appear (%d shops, %d events / %d regions)" % [shops, events, regions])
	check(cfg.shop_floors(42) == cfg.shop_floors(42), "the shop plan is deterministic")
	var min_floor_ok: bool = true
	for s: int in 100:
		for f: int in cfg.shop_floors(s):
			if f < int(special["guaranteed_min_floor"]) - 1:
				min_floor_ok = false
	check(min_floor_ok, "no planned shop before guaranteed_min_floor")

	# --- old maps unchanged: the special pass only replaces nodes in place ---
	var only_replaced: bool = true
	for s: int in 60:
		for rid: String in cfg.region_ids():
			for f: int in floors:
				var spec: Dictionary = cfg.region_spec(rid, f)
				spec["guarantee_shop"] = cfg.shop_floors(s).has(f)
				var seed_value: int = WorldMapGen.region_map_seed(s, rid, f)
				var with_special: Array[Dictionary] = ChapterMapGen.generate(spec, seed_value, 1)
				spec.erase("special_nodes")
				spec.erase("guarantee_shop")
				var without: Array[Dictionary] = ChapterMapGen.generate(spec, seed_value, 1)
				for ci: int in without.size():
					var a: Array = without[ci]["nodes"]
					var b: Array = with_special[ci]["nodes"]
					if a.size() != b.size() or without[ci]["tier"] != with_special[ci]["tier"]:
						only_replaced = false
						continue
					for i: int in a.size():
						var kb: String = str((b[i] as Dictionary)["kind"])
						if kb != "shop" and kb != "event" and a[i] != b[i]:
							only_replaced = false
						elif (kb == "shop" or kb == "event") and not ChapterMapGen.REPLACEABLE_KINDS.has(str((a[i] as Dictionary)["kind"])):
							only_replaced = false
	check(only_replaced, "with special nodes the map equals the plain map except fights turned shop / event")
	var no_world: ChaptersConfig = ChaptersConfig.from_dictionary({"chapters": [{"id": "a", "matches": {"m": {}}}]})
	check(no_world.special_nodes()["shop_weight"] == 0.0 and no_world.shop_floors(3).is_empty(), "without world.special_nodes: no weights, no shop plan")
	var seven_same: bool = true
	for ci: int in cfg.chapter_count():
		var spec7: Dictionary = cfg.get_map_spec(ci)
		check(not spec7.has("special_nodes"), "the 7-column chapter spec %d carries no special_nodes" % ci)
		for s: int in 20:
			var m7: Array[Dictionary] = cfg.generate_map(ci, s, 1)
			if _count(m7, "shop") > 0 or _count(m7, "event") > 0:
				seven_same = false
	check(seven_same, "7-column chapter maps never get a shop / event")
	check(WorldMapGen.shop_floors(1, 5, 2, 2).size() == 2 and WorldMapGen.shop_floors(1, 1, 2, 1) == [0] and WorldMapGen.shop_floors(1, 5, 0).is_empty(),
		"shop_floors: count, short floor list, count 0")

	# --- rewards: shop / event never open a post-fight card offer ---
	var cfg_rewards: Dictionary = RewardRoller.load_config()
	check(int(RewardRoller.reward_for_node("shop", cfg_rewards)["offers"]) == 0 and int(RewardRoller.reward_for_node("event", cfg_rewards)["offers"]) == 0,
		"rewards.json node_rewards: shop / event offers 0")

	print("FAILS=", fails, " PASSES=", passes)
	quit(1 if fails > 0 else 0)

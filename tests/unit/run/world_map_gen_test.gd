extends SceneTree
## Story 031 Part B/E: WorldMapGen offers, region map seeds and the v6 region frame of chapters.json.

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _count(col: Dictionary, kind: String) -> int:
	var n: int = 0
	for node: Dictionary in col["nodes"]:
		if node["kind"] == kind:
			n += 1
	return n


# Plays a world with a seeded "player" that picks an offered region at random; returns {offers, path}.
func _walk(pool: Array, seed_value: int, floors: int, pick_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = pick_seed
	var path: Array = []
	var offers: Array = []
	for f: int in floors:
		var offer: Array[String] = WorldMapGen.offer_for_floor(pool, seed_value, f, path)
		offers.append(offer)
		path.append(offer[rng.randi_range(0, offer.size() - 1)])
	return {"offers": offers, "path": path}


func _initialize() -> void:
	var pool3: Array = ["ch1", "ch2", "ch3"]
	var pool6: Array = ["a", "b", "c", "d", "e", "f"]

	# Same seed + same choices -> same offer; two different ids per floor.
	var same: bool = true
	var distinct: bool = true
	for s: int in 30:
		var w1: Dictionary = _walk(pool3, s, 5, s * 7)
		var w2: Dictionary = _walk(pool3, s, 5, s * 7)
		if w1 != w2:
			same = false
		for offer: Array in w1["offers"]:
			if offer.size() != 2 or offer[0] == offer[1]:
				distinct = false
	check(same, "same seed + same choices -> same offers on every floor")
	check(distinct, "every floor offers 2 different regions (pool 3)")

	# Different seeds change the first offer sometimes.
	var firsts: Dictionary = {}
	for s: int in 40:
		firsts[",".join(WorldMapGen.offer_for_floor(pool3, s, 0, []))] = true
	check(firsts.size() >= 2, "the seed changes the floor 1 offer (%d variants)" % firsts.size())

	# Pool 6: no region repeats inside 5 floors, whatever the player picks.
	var no_repeat: bool = true
	for s: int in 30:
		var w: Dictionary = _walk(pool6, s, 5, s + 3)
		var seen: Dictionary = {}
		for id: String in w["path"]:
			if seen.has(id):
				no_repeat = false
			seen[id] = true
		for offer: Array in w["offers"]:
			if offer[0] == offer[1]:
				no_repeat = false
	check(no_repeat, "pool 6: no region is repeated over 5 floors")

	# Pool 3: every region is offered in the first two floors; offers always are the least visited regions.
	var all_early: bool = true
	var least_visited: bool = true
	var never_third: bool = true
	var avoids_last: bool = true
	for s: int in 60:
		var w: Dictionary = _walk(pool3, s, 5, s * 13 + 1)
		var early: Dictionary = {}
		for f: int in 2:
			for id: String in w["offers"][f]:
				early[id] = true
		if early.size() != 3:
			all_early = false
		var visits: Dictionary = {"ch1": 0, "ch2": 0, "ch3": 0}
		for f: int in 5:
			var offer: Array = w["offers"][f]
			var max_offered: int = 0
			for id: String in offer:
				max_offered = maxi(max_offered, int(visits[id]))
			for id: String in pool3:
				if not offer.has(id) and int(visits[id]) < max_offered:
					least_visited = false
			if f > 0 and offer.has(w["path"][f - 1]):
				# allowed only when the other candidates were visited less than... never preferred
				var other_free: bool = false
				for id: String in pool3:
					if id != w["path"][f - 1] and not offer.has(id) and int(visits[id]) <= int(visits[w["path"][f - 1]]):
						other_free = true
				if other_free:
					avoids_last = false
			# A third visit is never OFFERED while a less visited region is left out of the offer
			# (the player may still pick it over a less visited region that IS offered).
			for id: String in offer:
				if int(visits[id]) >= 2:
					for other: String in pool3:
						if not offer.has(other) and int(visits[other]) < 2:
							never_third = false
			visits[w["path"][f]] = int(visits[w["path"][f]]) + 1
	check(all_early, "pool 3: all three regions show up in the offers of floors 1-2")
	check(least_visited, "pool 3: an offer never skips a less visited region for a more visited one")
	check(never_third, "pool 3: a third visit is never offered while a region visited less is left out")
	check(avoids_last, "pool 3: the previous floor's region is avoided while an equally visited one is left")

	# Pool 1 / empty / duplicates / unknown path ids.
	var one: Array[String] = WorldMapGen.offer_for_floor(["ch1"], 5, 2, ["ch1", "ch1"])
	check(one.size() == 1 and one[0] == "ch1", "pool 1: a single choice, no crash")
	check(WorldMapGen.offer_for_floor([], 5, 0, []).is_empty(), "empty pool: empty offer")
	check(WorldMapGen.offer_for_floor(["a", "a", "b"], 5, 0, []).size() == 2, "duplicate ids in the pool collapse")
	check(WorldMapGen.offer_for_floor(pool3, 5, 1, ["zz"]).size() == 2, "unknown ids in the path are ignored")
	check(WorldMapGen.offer_for_floor(pool3, 5, 0, [], 1).size() == 1, "choices parameter caps the offer")

	# Region map seed.
	var seed_a: int = WorldMapGen.region_map_seed(99, "ch2", 1)
	check(seed_a == WorldMapGen.region_map_seed(99, "ch2", 1) and seed_a >= 0, "region map seed is deterministic and non-negative")
	check(seed_a != WorldMapGen.region_map_seed(99, "ch2", 3) and seed_a != WorldMapGen.region_map_seed(99, "ch1", 1), "region map seed follows floor and region")

	# The shipped region frame.
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var world: Dictionary = cfg.world_spec()
	check(int(world["floors"]) == 5 and int(world["choices_per_floor"]) == 2, "world: 5 floors, 2 choices")
	check(",".join(cfg.region_ids()) == "ch1,ch2,ch3" and cfg.region_index("ch2") == 1 and cfg.region_index("zz") == -1, "region ids and indexes")
	check(is_equal_approx(cfg.floor_heal_ratio(), 0.35), "floor_heal_ratio 0.35 (Story 031 tuning, was 0.25)")
	var final: Dictionary = cfg.final_match()
	check(final.get("region") == "an_dai" and final.get("match_id") == "an_dai_keeper", "final_match is an_dai / an_dai_keeper (Story 035)")
	var frame_ok: bool = true
	var mini_floor1: int = 0
	var mini_later: int = 0
	var rest_or_treasure_ok: bool = true
	var boss_ok: bool = true
	var treasure_n: int = 0
	var rest_n: int = 0
	for rid: String in cfg.region_ids():
		for f: int in 5:
			for s: int in 30:
				var map: Array[Dictionary] = cfg.generate_region_map(rid, s, f, 2)
				if map.size() != 3 or _count(map[0], "battle") != 1 or (map[0]["nodes"] as Array).size() != 1:
					frame_ok = false
					continue
				var mid: int = (map[1]["nodes"] as Array).size()
				if mid < 2 or mid > 3:
					frame_ok = false
				var rt: int = _count(map[1], "rest") + _count(map[1], "treasure")
				if rt != 1:
					rest_or_treasure_ok = false
				treasure_n += _count(map[1], "treasure")
				rest_n += _count(map[1], "rest")
				if f == 0:
					mini_floor1 += _count(map[1], "miniboss")
				else:
					mini_later += _count(map[1], "miniboss")
				if (map[2]["nodes"] as Array).size() != 1 or _count(map[2], "boss") != 1:
					boss_ok = false
				else:
					var bid: String = str((map[2]["nodes"] as Array)[0]["match_id"])
					if not (cfg.get_map_spec(cfg.region_index(rid))["pools"]["boss"] as Dictionary).values().any(func(l: Array) -> bool: return l.has(bid)):
						boss_ok = false
	check(frame_ok, "region map: 3 columns, col 0 one battle, col 1 two or three nodes")
	check(rest_or_treasure_ok, "region map: col 1 has exactly one rest or treasure")
	check(treasure_n > 100 and rest_n > 100, "region map: rest / treasure drawn about 50/50 (%d / %d)" % [rest_n, treasure_n])
	check(boss_ok, "region map: col 2 is one boss from the region's boss pool")
	check(mini_floor1 == 0, "region map: no miniboss on floor 1 (min_floor 2)")
	check(mini_later > 0, "region map: miniboss appears from floor 2 (%d)" % mini_later)

	# Determinism and variation.
	check(cfg.generate_region_map("ch1", 7, 2, 1) == cfg.generate_region_map("ch1", 7, 2, 1), "same seed + region + floor -> same map")
	var varied: int = 0
	for s: int in 20:
		if cfg.generate_region_map("ch1", s, 1, 1) != cfg.generate_region_map("ch1", s, 3, 1):
			varied += 1
	check(varied >= 15, "the same region on another floor gives another map (%d/20)" % varied)
	check(cfg.generate_region_map("zz", 1, 0, 0).is_empty(), "unknown region -> empty map")

	# Tiers by floor and onboarding cap.
	var spec1: Dictionary = cfg.region_spec("ch1", 0)
	var spec3: Dictionary = cfg.region_spec("ch1", 2)
	check(int(spec1["columns"][0]["tier"]) == 0 and int(spec1["columns"][1]["tier"]) == 1 and int(spec1["columns"][2]["tier"]) == 1, "floor 1 tiers [0,1,1]")
	check(int(spec3["columns"][0]["tier"]) == 1 and int(spec3["columns"][1]["tier"]) == 2 and int(spec3["columns"][2]["tier"]) == 2, "floor 3 tiers [1,2,2]")
	check(int(cfg.region_spec("ch1", 3)["floor_number"]) == 4 and int(spec3["floor"]) == 2, "region_spec carries floor and floor_number")
	var capped: Array[Dictionary] = cfg.generate_region_map("ch1", 3, 4, 0)
	check(int(capped[1]["tier"]) == 1 and int(capped[2]["tier"]) == 1, "onboarding cap still clamps region map tiers")
	check(cfg.region_spec("zz", 0).is_empty(), "unknown region -> empty spec")

	# Old callers: min_floor never filters without floor_number; object-form kinds are read.
	var legacy: Dictionary = {"id": "x", "columns": [{"tier": 0, "kinds": [{"kind": "battle", "min_floor": 9}], "pick": [1, 1], "required": []}],
		"pools": {"battle": {"0": ["m"]}}, "match_ids": ["m"]}
	check(ChapterMapGen.generate(legacy, 1, 1)[0]["nodes"][0]["kind"] == "battle", "min_floor ignored without floor_number")
	legacy["floor_number"] = 2
	check((ChapterMapGen.generate(legacy, 1, 1)[0]["nodes"] as Array).is_empty(), "min_floor above the floor drops the kind")

	# Bad world data: defaults and warnings, never null.
	var bad: ChaptersConfig = ChaptersConfig.from_dictionary({"chapters": [{"id": "r1", "matches": {"m": {}}}],
		"world": {"floors": 0, "region_pool": ["nope"], "floor_scaling": {"1": {"hp_mult": -2}}, "final_match": {"region": "zz"}, "floor_heal_ratio": 4}})
	check(bad.world_floors() == 1 and ",".join(bad.region_ids()) == "r1", "bad world: floors >= 1, pool falls back to every chapter")
	check(is_equal_approx(float(bad.floor_scaling(0)["hp_mult"]), 1.0) and bad.final_match().is_empty() and is_equal_approx(bad.floor_heal_ratio(), 1.0), "bad world: identity scaling, no final match, ratio clamped")
	var none: ChaptersConfig = ChaptersConfig.from_dictionary({})
	check(not none.region_ids().is_empty() and none.generate_region_map("ch1", 1, 0, 0).size() == 3, "no world block: built-in 3-column frame")

	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)

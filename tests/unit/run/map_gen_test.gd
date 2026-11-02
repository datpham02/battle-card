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


func _count(col: Dictionary, kind: String) -> int:
	var n: int = 0
	for node: Dictionary in col["nodes"]:
		if node["kind"] == kind:
			n += 1
	return n


func _initialize() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	check(cfg.chapter_count() == 8 and cfg.chapter_id(3) == "an_dai" and cfg.chapter_id(0) == "ch1" and cfg.chapter_id(1) == "ch2" and cfg.chapter_id(2) == "ch3" and cfg.chapter_id(4) == "swamp" and cfg.chapter_id(5) == "desert" and cfg.chapter_id(6) == "hellfire" and cfg.chapter_id(7) == "sky_isles", "chapters.json v2 loads 3 chapters + an_dai + swamp + desert + hellfire + sky_isles (Stories 036 / 039)")
	check(cfg.column_count(0) == 7 and cfg.column_count(1) == 7 and cfg.column_count(2) == 7, "7 columns default spec")
	var d: Dictionary = cfg.defaults()
	check(float(d["heal_between_matches"]) == 0.0 and float(d["heal_between_floors"]) == 0.0 and int(d["revive_tokens"]) == 0, "heal defaults 0, revive 0")
	var m1: Array[Dictionary] = cfg.generate_map(0, 12345, 0)
	var m2: Array[Dictionary] = cfg.generate_map(0, 12345, 0)
	check(m1 == m2 and m1.size() == 7, "same seed same map")
	var differ: int = 0
	for s: int in 20:
		if cfg.generate_map(0, s, 2) != cfg.generate_map(0, s + 1000, 2):
			differ += 1
	check(differ >= 18, "different seeds differ (%d/20)" % differ)
	for ci: int in cfg.chapter_count():
		var spec: Dictionary = cfg.get_map_spec(ci)
		var bad: int = 0
		var boss_ok: bool = false
		for kind: String in spec["pools"].keys():
			for tier: String in spec["pools"][kind].keys():
				for id: String in spec["pools"][kind][tier]:
					if cfg.get_match_def(ci, id).is_empty():
						bad += 1
					if kind == "boss" and id == ["forest_witch", "ogre_king", "mist_lord", "an_dai_keeper", "toad_matriarch", "sand_sphinx", "inferno_lord", "storm_dragon"][ci]:
						boss_ok = true
		check(bad == 0, "ch%d pools reference existing matches" % (ci + 1))
		check(boss_ok, "ch%d boss pool has its final boss" % (ci + 1))
	var skeleton_bad: int = 0
	var repeats_bad: int = 0
	var empty_draw: int = 0
	var sibling_same: int = 0
	var sibling_cols: int = 0
	var tier_bad: int = 0
	var kinds_seen: Dictionary = {}
	var tiers: Array[int] = [0, 1, 1, 2, 2, 2, 2]
	for ci: int in 3:
		var spec: Dictionary = cfg.get_map_spec(ci)
		for s: int in 300:
			for cleared: int in [0, 1]:
				var map: Array[Dictionary] = cfg.generate_map(ci, s * 7919 + 1, cleared)
				var ok: bool = map.size() == 7
				if ok:
					ok = map[0]["nodes"].size() == 1 and _count(map[0], "battle") == 1
					for c: int in [1, 2, 5]:
						var n: int = map[c]["nodes"].size()
						ok = ok and n >= 2 and n <= 3
					ok = ok and _count(map[3], "miniboss") == 1 and _count(map[4], "rest") == 1
					ok = ok and (_count(map[4], "treasure") + _count(map[4], "battle")) >= 1
					ok = ok and map[6]["nodes"].size() == 1 and _count(map[6], "boss") == 1
					ok = ok and _count(map[5], "treasure") == 0 and _count(map[5], "rest") == 0
				if not ok:
					skeleton_bad += 1
					continue
				var used: Array[String] = []
				for col: Dictionary in map:
					var t: int = int(col["tier"])
					var want: int = tiers[int(col["index"])]
					if cleared == 0:
						want = mini(want, 1)
					if t != want:
						tier_bad += 1
					var kinds: Array[String] = []
					for node: Dictionary in col["nodes"]:
						kinds_seen[node["kind"]] = true
						kinds.append(node["kind"])
						var mid: String = node["match_id"]
						if node["kind"] in ["treasure", "rest"]:
							if mid != "":
								empty_draw += 1
						else:
							if mid == "" or cfg.get_match_def(ci, mid).is_empty():
								empty_draw += 1
							elif used.has(mid):
								var all_used: bool = true
								for tier: String in spec["pools"][node["kind"]].keys():
									for id: String in spec["pools"][node["kind"]][tier]:
										if not used.has(id):
											all_used = false
								if not all_used:
									repeats_bad += 1
							used.append(mid)
					if kinds.size() >= 2 and int(col["index"]) in [1, 2]:
						sibling_cols += 1
						var uniq: Dictionary = {}
						for k: String in kinds:
							uniq[k] = true
						if uniq.size() < mini(kinds.size(), 2):  # 022 tuning: col 2 has 2 kinds for up to 3 nodes
							sibling_same += 1
	check(skeleton_bad == 0, "skeleton invariants over 2x500x2 maps (bad %d)" % skeleton_bad)
	check(tier_bad == 0, "tier mapping + clamp")
	check(empty_draw == 0, "no empty pool draw; treasure/rest have no match")
	check(repeats_bad == 0, "no repeated match when pool allows")
	check(sibling_same == 0, "cols 1-2 siblings differ in kind (%d/%d)" % [sibling_same, sibling_cols])
	for k: String in ["battle", "danger", "treasure", "rest", "miniboss", "boss"]:
		check(kinds_seen.has(k), "kind %s generated" % k)
	var ob: Array[Dictionary] = cfg.generate_map(0, 99, 0)
	# P2.3 (spec phase2-misty-forest 5.5): the tier-1 elite pool is goblin_chief + ancient_root_sentinel (the latter only
	# after a Rootling / Mossbound Sentry column, teach_after; tests/unit/run/map_gen_teach_after_test.gd covers 10 000 seeds).
	check(ob[3]["nodes"].any(func(n: Dictionary) -> bool: return n["kind"] == "miniboss" and (n["match_id"] == "goblin_chief" 		or (n["match_id"] == "ancient_root_sentinel" and ChapterMapGen.is_taught(cfg.get_map_spec(0), "ancient_root_sentinel", ob.slice(0, 3))))),
		"onboarding miniboss is a tier-1 elite (goblin_chief, or the Sentinel once taught)")
	check(ob[6]["nodes"][0]["match_id"] == "goblin_warlock", "onboarding boss is goblin_warlock")
	check(cfg.node_count(ob) >= 13 and cfg.node_count(ob) <= 17, "node_count %d" % cfg.node_count(ob))
	var runnable: int = 0
	var total: int = 0
	for ci: int in 3:
		for id: String in cfg.match_ids(ci):
			for kind: String in ["battle", "danger", "miniboss", "boss"]:
				total += 1
				var rc: RunConfig = RunConfig.from_node(cfg, ci, id, kind, 777)
				var m: Dictionary = rc.matches[0]
				var arena_ok: bool = not (m["arena"] as Dictionary).is_empty() and int(m["arena_seed"]) >= 0
				var has_burner: bool = (m["traits"] as Array).any(func(tr: Dictionary) -> bool: return tr["id"] == "row_burner")
				if rc.match_count() == 1 and m["id"] == id and arena_ok and (kind != "danger" or has_burner) and float(m["boss_max_hp"]) > 0.0:
					runnable += 1
	check(runnable == total, "RunConfig.from_node runnable for every match x kind (%d/%d)" % [runnable, total])
	check(RunConfig.from_node(cfg, 0, "goblin_scout", "battle", 5).matches[0]["arena_seed"] == RunConfig.from_node(cfg, 0, "goblin_scout", "battle", 5).matches[0]["arena_seed"], "from_node arena_seed deterministic")
	check(RunConfig.from_node(cfg, 0, "goblin_scout", "battle", 5).matches[0]["arena_seed"] != RunConfig.from_node(cfg, 0, "goblin_scout", "battle", 6).matches[0]["arena_seed"], "arena_seed follows run_seed")
	check(float(cfg.get_match_def(0, "forest_witch")["boss_max_hp"]) == 1210.0 and cfg.get_match_def(0, "wolf")["brain_set"] == "balanced", "ch1 matches kept (wolf balanced since the 022 tuning; Forest Witch 1210 written since P2.4, D8 pack budget)")
	check(cfg.get_match_def(0, "wolf_alpha").has("arena") and cfg.get_match_def(0, "nope").is_empty(), "get_match_def has arena; unknown empty")
	check(ChapterMapGen.generate({}, 1, 0).size() == 7 and ChapterMapGen.generate({"columns": 5}, 1, 0).is_empty() and ChapterMapGen.generate({"columns": [{}]}, 1, 0).size() == 1, "bad spec tolerated (empty -> fallback skeleton, non-array -> [])")
	var dflt: ChaptersConfig = ChaptersConfig.from_dictionary({})
	check(dflt.chapter_count() == 1 and dflt.generate_map(0, 1, 0).size() == 7, "default chapter still generates a map")
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)

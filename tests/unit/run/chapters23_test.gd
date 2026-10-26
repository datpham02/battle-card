extends SceneTree
## Story 023 Part Z: chapters 2-3 data.
var fails: int = 0
var passes: int = 0
const TRAITS: Array[String] = ["row_burner", "rotten_thrower", "step_reactor", "fuse_cannon", "slam", "frost_aura", "phase_shift", "seal_caster", "thorn_field"]
const BOSSES: Array[String] = ["forest_witch", "ogre_king", "mist_lord"]
const NORMALS: Array[String] = ["skeleton", "zombie", "bat_swarm", "slime", "cultist", "rat_king_guard", "frost_sprite", "wisp", "stone_sentry", "snow_wolf", "rime_archer", "ice_golem"]


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


func _csv() -> Dictionary:
	var out: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		out[row[0]] = row
	return out


func _csv_ok(strings: Dictionary, key: String) -> bool:
	var row: PackedStringArray = strings.get(key, PackedStringArray())
	return row.size() == 3 and row[1] != "" and row[2] != ""


func _initialize() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var strings: Dictionary = _csv()
	var lib: ArenaLibrary = ArenaLibrary.load_from_file()
	check(cfg.chapter_count() == 8, "8 chapters (3 regions + an_dai + swamp + desert + hellfire + sky_isles, Stories 036 / 039)")
	var tiers_used: Dictionary = {}
	for c: Dictionary in cfg.get_map_spec(0)["columns"]:
		tiers_used[int(c["tier"])] = true
	var mean_hp: Array[float] = []
	var arenas_used: Dictionary = {}
	for ci: int in 3:
		var spec: Dictionary = cfg.get_map_spec(ci)
		var ids: Array[String] = cfg.match_ids(ci)
		var pools: Dictionary = spec["pools"]
		var bad_pool: int = 0
		var in_pool: Dictionary = {}
		for kind: String in pools.keys():
			for tier: String in pools[kind].keys():
				for id: String in pools[kind][tier]:
					in_pool[id] = true
					if not ids.has(id):
						bad_pool += 1
		check(bad_pool == 0, "ch%d pool ids exist in matches" % (ci + 1))
		var empty: int = 0
		for t: int in tiers_used.keys():
			if (pools["battle"].get(str(t), []) as Array).is_empty():
				empty += 1
			if t >= 1 and ((pools["danger"].get(str(t), []) as Array).is_empty() or (pools["miniboss"].get(str(t), []) as Array).is_empty() or (pools["boss"].get(str(t), []) as Array).is_empty()):
				empty += 1
		check(empty == 0, "ch%d pools non-empty for used tiers" % (ci + 1))
		check(in_pool.size() == ids.size(), "ch%d every match is in some pool (%d/%d)" % [ci + 1, in_pool.size(), ids.size()])
		if ci > 0:
			check(ids.size() == 10, "ch%d has 10 matches (%d)" % [ci + 1, ids.size()])
		var ph: int = 0
		var bad_trait: int = 0
		var bad_num: int = 0
		var hp_sum: float = 0.0
		var hp_n: int = 0
		for id: String in ids:
			var raw: Dictionary = cfg.get_match_raw(ci, id)
			if id.contains("placeholder"):
				ph += 1
			for t: Dictionary in raw.get("traits", []):
				if not TRAITS.has(str(t["id"])):
					bad_trait += 1
			for key: String in ["boss_defense", "boss_min_runes"]:
				if raw.has(key) and not (typeof(raw[key]) in [TYPE_INT, TYPE_FLOAT]):
					bad_num += 1
			if ci == 0 or NORMALS.has(id):
				hp_sum += float(raw["boss_max_hp"])
				hp_n += 1
			if ci == 0:
				continue
			if NORMALS.has(id):
				check(float(raw.get("boss_defense", 0)) == (2.0 if ci == 1 else 4.0), "ch%d normal %s defense" % [ci + 1, id])
			check(float(raw.get("boss_think_interval_sec", 0.3)) >= 0.3 and float(raw.get("boss_reaction_sec", 0.35)) >= 0.35, "%s think/reaction floor" % id)
			check(_csv_ok(strings, str(raw["name_key"])), "csv vi+en %s" % raw["name_key"])
			if raw.has("desc_key"):
				check(_csv_ok(strings, str(raw["desc_key"])), "csv vi+en %s" % raw["desc_key"])
			arenas_used[str((raw["arena"] as Dictionary)["shape"])] = true
			for kind2: String in ["battle", "danger", "miniboss", "boss"]:
				var rc: RunConfig = RunConfig.from_node(cfg, ci, id, kind2, 777)
				var m: Dictionary = rc.matches[0]
				if rc.match_count() != 1 or m["id"] != id or (m["arena"] as Dictionary).is_empty() or int(m["arena_seed"]) < 0 or float(m["boss_max_hp"]) <= 0.0:
					bad_num += 1
		check(ph == 0, "ch%d no placeholders" % (ci + 1))
		check(bad_trait == 0, "ch%d trait ids known" % (ci + 1))
		check(bad_num == 0, "ch%d numeric keys + runnable from_node" % (ci + 1))
		mean_hp.append(hp_sum / maxf(hp_n, 1))
		var skel_bad: int = 0
		var boss_bad: int = 0
		for s: int in 300:
			var map: Array[Dictionary] = cfg.generate_map(ci, s * 7919 + 1, 1)
			var ok: bool = map.size() == 7 and _count(map[3], "miniboss") == 1 and _count(map[4], "rest") == 1 and _count(map[6], "boss") == 1 and map[6]["nodes"].size() == 1
			if not ok:
				skel_bad += 1
				continue
			if map[6]["nodes"][0]["match_id"] != BOSSES[ci] and ci > 0:
				boss_bad += 1
			for col: Dictionary in map:
				for node: Dictionary in col["nodes"]:
					if node["kind"] in ["battle", "danger", "miniboss", "boss"] and cfg.get_match_def(ci, node["match_id"]).is_empty():
						skel_bad += 1
		check(skel_bad == 0, "ch%d 300-seed skeleton invariants" % (ci + 1))
		check(boss_bad == 0, "ch%d boss is %s" % [ci + 1, BOSSES[ci]])
		check(ci == 0 or cfg.generate_map(ci, 5, 0)[6]["nodes"][0]["match_id"] == BOSSES[ci], "ch%d onboarding boss" % (ci + 1))
		if ci > 0:
			for part: String in ["name", "intro", "end"]:
				check(_csv_ok(strings, "chapter.ch%d.%s" % [ci + 1, part]), "csv chapter.ch%d.%s" % [ci + 1, part])
	check(mean_hp[0] < mean_hp[1] and mean_hp[1] < mean_hp[2], "normal HP escalates %s" % str(mean_hp))
	check(absf(mean_hp[2] / mean_hp[1] - 1.15) < 0.1, "ch3/ch2 HP about +15 percent (%.3f)" % (mean_hp[2] / mean_hp[1]))
	check(float(cfg.get_match_raw(1, "ogre_king")["boss_min_runes"]) == 3.0 and float(cfg.get_match_raw(2, "mist_lord")["boss_min_runes"]) == 3.0, "boss min_runes 3")
	check(float(cfg.get_match_raw(1, "jailer")["boss_min_runes"]) == 2.0, "elite min_runes 2")
	check(float(cfg.get_match_raw(1, "ghost")["boss_defense"]) == 12.0 and float(cfg.get_match_raw(2, "ghost_elite")["boss_defense"]) == 16.0, "ghost defenses")
	check(float(cfg.get_match_raw(1, "ghost")["boss_max_hp"]) == 24.0 and float(cfg.get_match_raw(2, "ghost_elite")["boss_max_hp"]) == 36.0, "ghost hp")
	for shape: String in arenas_used.keys():
		var sp: Dictionary = lib.get_shape(shape)
		check(not sp.is_empty(), "arena %s in library" % shape)
		if not sp.is_empty():
			var v: Dictionary = ArenaValidator.validate(sp, lib.rules)
			var grid: BoardGrid = ArenaValidator.build_grid(sp)
			check(bool(v["ok"]) and grid.player_cells().size() >= 4 and grid.enemy_cells().size() >= 4, "arena %s valid %s" % [shape, str(v["reasons"])])
	for shape: String in ["cross_wide", "pillars"]:
		check(not lib.get_shape(shape).is_empty() and arenas_used.has(shape), "new shape %s present and used" % shape)
		check(ArenaNames.NAMES.has(shape) and _csv_ok(strings, "arena.%s.name" % shape), "arena name key %s" % shape)
	var ps := ProgressState.new()
	ps.add_region_boss_beaten("ch1")
	check(ps.has_region_boss_beaten("ch1") and not ps.has_region_boss_beaten("ch2"), "add_region_boss_beaten records the region")
	ps.add_region_boss_beaten("ch2")
	check(ps.get_regions_boss_beaten() == (["ch1", "ch2"] as Array[String]), "regions beaten in order")
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)

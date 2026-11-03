extends SceneTree
## Phase 2 P2.3 (design/quick-specs/phase2-misty-forest-2026-11-01.md 5.5, decision D10): the map generator never puts
## a new Misty Forest elite (a chapters.json match with `teach_after`) where a player can reach it before fighting one
## of the enemies it is taught by. Over 10 000 run seeds x every floor (0..4) of the Misty Forest region (the shipped
## world flow, ChaptersConfig.generate_region_map, with and without a boss cleared before) EVERY path through the map
## is walked (one node per column) and an elite node must come after a fought teacher on that path. Also checks the
## gate is not a ban: a drawn elite forces the first battle column to its (pool-legal) teachers, so the Matron holds
## >= 20 % of tier-2 elite nodes and the Sentinel >= 40 % of tier-1 ones (was ~8 % / ~24 % when an untaught elite was
## swapped out); only when no column can teach is it replaced by another elite of the same tier. The main rng stream
## is checked against the ungated draw (only teaching columns / swapped elites may differ). The legacy 7-column chapter map (ChaptersConfig.generate_map) is checked the same way on 1 000 seeds.
## Run: godot --headless --path . -s res://tests/unit/run/map_gen_teach_after_test.gd

const REGION: String = "ch1"
const SEEDS: int = 10000
const LEGACY_SEEDS: int = 1000

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var ci: int = cfg.region_index(REGION)
	var teach: Dictionary = cfg.get_map_spec(ci).get("teach_after", {}) as Dictionary
	_check("ch1 map spec carries teach_after for the three gated elites", teach.get("ancient_root_sentinel", []) == ["rootling", "mossbound_sentry"]
		and teach.get("mistbriar_matron", []) == ["greycap_sporeling", "rootling"]
		and teach.get("wolf_alpha", []) == ["dire_wolf", "goblin_archer"], str(teach))
	var bad: Array[String] = []
	var seen: Dictionary = {}
	var elite_nodes: int = 0
	# Follow-up to D10 (the Matron was in ~1 % of maps): elite share per tier, counted on cleared-1 maps only.
	var tier_elites: Dictionary = {1: {}, 2: {}}
	var not_in_pool: Array[String] = []
	for s: int in SEEDS:
		for floor: int in cfg.world_floors():
			for cleared: int in [0, 1]:
				var map: Array[Dictionary] = cfg.generate_region_map(REGION, s * 7919 + 13, floor, cleared)
				elite_nodes += _walk(map, teach, bad, "seed %d floor %d cleared %d" % [s, floor, cleared], seen)
				_check_first_column_pool(cfg, ci, map, not_in_pool, "seed %d floor %d cleared %d" % [s, floor, cleared])
				if cleared == 1:
					for col: Dictionary in map:
						for node: Dictionary in col["nodes"]:
							if node["kind"] == "miniboss" and tier_elites.has(int(col["tier"])):
								var by_id: Dictionary = tier_elites[int(col["tier"])]
								by_id[node["match_id"]] = int(by_id.get(node["match_id"], 0)) + 1
	_check("no path reaches a new elite before one of its teachers (%d seeds x %d floors x 2)" % [SEEDS, cfg.world_floors()],
		bad.is_empty(), str(bad.slice(0, 3)))
	_check("the first column (forced teachers included) only holds ids of its own battle pool at its tier or lower",
		not_in_pool.is_empty(), str(not_in_pool.slice(0, 3)))
	# A drawn gated elite forces the first column to its teachers instead of being swapped out, so it is as likely as
	# any other elite of its tier: tier 2 = shaman / alpha / sentinel / matron (1/4 each), tier 1 = chief / sentinel
	# (1/2 each). The old gate (swap unless the first column happened to teach) gave the Matron ~8 % of tier-2 elite
	# nodes and the Sentinel ~24 % of tier-1 ones.
	var t2: Dictionary = tier_elites[2]
	var t2_total: int = 0
	for id: Variant in t2:
		t2_total += int(t2[id])
	var matron_share: float = float(t2.get("mistbriar_matron", 0)) / maxf(float(t2_total), 1.0)
	_check("the Matron holds >= 20 % of tier-2 elite nodes (expected ~25 %)", matron_share >= 0.20,
		"%.1f %% of %d %s" % [matron_share * 100.0, t2_total, str(t2)])
	var t1: Dictionary = tier_elites[1]
	var t1_total: int = 0
	for id: Variant in t1:
		t1_total += int(t1[id])
	var sentinel_share: float = float(t1.get("ancient_root_sentinel", 0)) / maxf(float(t1_total), 1.0)
	_check("the Sentinel holds >= 40 % of tier-1 elite nodes (expected ~50 %)", sentinel_share >= 0.40,
		"%.1f %% of %d %s" % [sentinel_share * 100.0, t1_total, str(t1)])
	# The main rng stream is the same as without the gate: against the same spec without teach_after (no gate, the
	# raw draw), the columns, node kinds, rest / treasure / boss nodes and every non-gated elite are the same; a gated
	# elite may be swapped out; battle / danger ids may differ only on a map where a forcing changed a teaching column
	# (the forced teachers, and the nodes redrawn after them to keep "no repeat while the pool allows", map_gen_test).
	var stream_bad: Array[String] = []
	for s: int in 2000:
		for floor: int in cfg.world_floors():
			var gated_spec: Dictionary = cfg.region_spec(REGION, floor)
			var raw_spec: Dictionary = gated_spec.duplicate(true)
			raw_spec.erase("teach_after")
			var g: Array[Dictionary] = ChapterMapGen.generate(gated_spec, s, 1)
			var r: Array[Dictionary] = ChapterMapGen.generate(raw_spec, s, 1)
			if g.size() != r.size():
				stream_bad.append("seed %d floor %d: %d vs %d columns" % [s, floor, g.size(), r.size()])
				continue
			var forced: bool = false
			for c: int in g.size():
				for id: Variant in teach:
					if ChapterMapGen.is_taught(gated_spec, str(id), g.slice(0, c + 1)) and not ChapterMapGen.is_taught(gated_spec, str(id), g.slice(0, c)):
						forced = forced or g[c]["nodes"] != r[c]["nodes"]
			for c: int in g.size():
				if g[c]["nodes"].size() != r[c]["nodes"].size():
					stream_bad.append("seed %d floor %d column %d: node count" % [s, floor, c])
					continue
				for k: int in g[c]["nodes"].size():
					var gn: Dictionary = g[c]["nodes"][k]
					var rn: Dictionary = r[c]["nodes"][k]
					if gn == rn or (gn["kind"] == rn["kind"] and (teach.has(rn["match_id"])
							or (forced and ["battle", "danger"].has(str(gn["kind"]))))):
						continue
					stream_bad.append("seed %d floor %d column %d: %s vs %s" % [s, floor, c, str(gn), str(rn)])
	_check("main rng stream unchanged vs the ungated draw: same skeleton and elites; ids differ only in swapped gated elites or battle / danger nodes of forced maps (2000 seeds x 5 floors)",
		stream_bad.is_empty(), str(stream_bad.slice(0, 3)))
	var elites: String = "sentinel %d matron %d chief %d shaman %d alpha %d" % [int(seen.get("ancient_root_sentinel", 0)),
		int(seen.get("mistbriar_matron", 0)), int(seen.get("goblin_chief", 0)), int(seen.get("goblin_shaman", 0)), int(seen.get("wolf_alpha", 0))]
	_check("the Sentinel still appears (taught)", int(seen.get("ancient_root_sentinel", 0)) > 0, elites)
	_check("the Matron still appears (taught)", int(seen.get("mistbriar_matron", 0)) > 0, elites)
	# 2026-11-03 (doi-hinh-rung-suong spec §5): the goblin chief / shaman left the ch1 pools; the third elite is the
	# Wolf Alpha, itself gated (taught by the Dire Wolf / Goblin Archer).
	_check("the Wolf Alpha still appears (taught); the retired goblin elites never do", int(seen.get("wolf_alpha", 0)) > 0
		and int(seen.get("goblin_chief", 0)) + int(seen.get("goblin_shaman", 0)) == 0, elites)
	_check("gated elite nodes were generated", elite_nodes > 1000, str(elite_nodes))
	# Gate is a replacement, not a hole: a map whose first column cannot teach still gets an elite of the same tier.
	var spec: Dictionary = cfg.region_spec(REGION, 1)
	spec["columns"] = [
		{"tier": 0, "kinds": ["battle"], "pick": [1, 1], "required": []},
		{"tier": 1, "kinds": [], "pick": [1, 1], "required": ["miniboss"]},
	]
	spec["pools"] = {"battle": {"0": ["goblin_scout"]}, "miniboss": {"1": ["ancient_root_sentinel", "goblin_chief"]}}
	spec.erase("special_nodes")
	var fallback_ok: bool = true
	var taught_spec: Dictionary = spec.duplicate(true)
	taught_spec["pools"] = {"battle": {"0": ["rootling"]}, "miniboss": {"1": ["ancient_root_sentinel"]}}
	var sentinel_when_taught: bool = true
	for s: int in 200:
		var m: Array[Dictionary] = ChapterMapGen.generate(spec, s, 1)
		fallback_ok = fallback_ok and str(m[1]["nodes"][0]["match_id"]) == "goblin_chief"
		var t: Array[Dictionary] = ChapterMapGen.generate(taught_spec, s, 1)
		sentinel_when_taught = sentinel_when_taught and str(t[1]["nodes"][0]["match_id"]) == "ancient_root_sentinel"
	_check("untaught Sentinel is replaced by goblin_chief when no earlier column can hold a teacher (same tier)", fallback_ok)
	_check("taught Sentinel (Rootling first) is drawn", sentinel_when_taught)
	# A drawn elite forces the first column to its teachers (was: swapped out unless that column happened to teach).
	var force_spec: Dictionary = spec.duplicate(true)
	force_spec["pools"] = {"battle": {"0": ["goblin_scout", "goblin_warrior", "rootling"]}, "miniboss": {"1": ["ancient_root_sentinel"]}}
	var forced_ok: bool = true
	for s: int in 200:
		var m: Array[Dictionary] = ChapterMapGen.generate(force_spec, s, 1)
		forced_ok = forced_ok and str(m[1]["nodes"][0]["match_id"]) == "ancient_root_sentinel" and str(m[0]["nodes"][0]["match_id"]) == "rootling"
	_check("a drawn Sentinel forces the first battle column to its teacher (Rootling), 200 seeds", forced_ok)
	# Every node of the forced column takes a teacher, so every path passes one.
	var wide_spec: Dictionary = force_spec.duplicate(true)
	wide_spec["columns"] = [
		{"tier": 0, "kinds": ["battle"], "pick": [3, 3], "required": []},
		{"tier": 1, "kinds": [], "pick": [1, 1], "required": ["miniboss"]},
	]
	wide_spec["pools"]["battle"]["0"] = ["goblin_scout", "goblin_warrior", "goblin_archer", "rootling", "mossbound_sentry"]
	var wide_ok: bool = true
	for s: int in 200:
		var m: Array[Dictionary] = ChapterMapGen.generate(wide_spec, s, 1)
		for node: Dictionary in m[0]["nodes"]:
			wide_ok = wide_ok and ["rootling", "mossbound_sentry"].has(str(node["match_id"]))
	_check("a forced 3-node column holds a teacher on every node, 200 seeds", wide_ok)
	# Two gated elites on one map share the column through their common teacher (Rootling teaches both).
	var both_spec: Dictionary = force_spec.duplicate(true)
	both_spec["columns"] = [
		{"tier": 0, "kinds": ["battle"], "pick": [1, 1], "required": []},
		{"tier": 1, "kinds": [], "pick": [1, 1], "required": ["miniboss"]},
		{"tier": 2, "kinds": [], "pick": [1, 1], "required": ["miniboss"]},
	]
	both_spec["pools"] = {"battle": {"0": ["goblin_scout", "greycap_sporeling", "mossbound_sentry", "rootling"]},
		"miniboss": {"1": ["ancient_root_sentinel"], "2": ["mistbriar_matron"]}}
	var both_ok: bool = true
	for s: int in 200:
		var m: Array[Dictionary] = ChapterMapGen.generate(both_spec, s, 1)
		both_ok = both_ok and str(m[0]["nodes"][0]["match_id"]) == "rootling" and str(m[1]["nodes"][0]["match_id"]) == "ancient_root_sentinel" \
			and str(m[2]["nodes"][0]["match_id"]) == "mistbriar_matron"
	_check("Sentinel + Matron on one map: the first column is their shared teacher Rootling, 200 seeds", both_ok)
	var legacy_bad: Array[String] = []
	var legacy_seen: Dictionary = {}
	for s: int in LEGACY_SEEDS:
		for cleared: int in [0, 1]:
			_walk(cfg.generate_map(ci, s * 104729 + 7, cleared), teach, legacy_bad, "legacy seed %d cleared %d" % [s, cleared], legacy_seen)
	_check("legacy 7-column map: same guarantee (%d seeds x 2)" % LEGACY_SEEDS, legacy_bad.is_empty(), str(legacy_bad.slice(0, 3)))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# Reports in [param out] a first-column node of [param map] whose id is not in its kind's pool of chapter [param ci]
# at the column's tier or lower (a forced teacher must be pool-legal).
func _check_first_column_pool(cfg: ChaptersConfig, ci: int, map: Array[Dictionary], out: Array[String], label: String) -> void:
	if map.is_empty() or out.size() > 5:
		return
	var pools: Dictionary = cfg.get_map_spec(ci).get("pools", {}) as Dictionary
	for node: Dictionary in map[0]["nodes"]:
		var by_tier: Dictionary = pools.get(str(node["kind"]), {}) as Dictionary
		var ok: bool = false
		for t: int in range(int(map[0]["tier"]), -1, -1):
			ok = ok or (by_tier.get(str(t), []) as Array).has(node["match_id"])
		if not ok:
			out.append("%s: %s" % [label, str(node)])


# Walks every path of [param map] (one node per column) with the set of matches fought so far; an elite of
# [param teach] reached with none of its teachers fought is reported in [param bad]. Counts match ids in [param seen]
# (once per node) and returns the number of nodes holding a gated elite.
func _walk(map: Array[Dictionary], teach: Dictionary, bad: Array[String], label: String, seen: Dictionary) -> int:
	var gated: int = 0
	for col: Dictionary in map:
		for node: Dictionary in col["nodes"]:
			var id: String = str(node["match_id"])
			if not id.is_empty():
				seen[id] = int(seen.get(id, 0)) + 1
			if teach.has(id):
				gated += 1
	_dfs(map, 0, [], teach, bad, label)
	return gated


func _dfs(map: Array[Dictionary], column: int, fought: Array, teach: Dictionary, bad: Array[String], label: String) -> void:
	if column >= map.size() or bad.size() > 5:
		return
	for node: Dictionary in map[column]["nodes"]:
		var id: String = str(node["match_id"])
		if teach.has(id):
			var taught: bool = false
			for t: Variant in teach[id]:
				taught = taught or fought.has(str(t))
			if not taught:
				bad.append("%s: %s at column %d after %s" % [label, id, column, str(fought)])
				return
		var next: Array = fought.duplicate()
		if not id.is_empty():
			next.append(id)
		_dfs(map, column + 1, next, teach, bad, label)

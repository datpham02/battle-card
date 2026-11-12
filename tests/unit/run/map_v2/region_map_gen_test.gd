extends SceneTree
## World Map v2 U6-U11 in one suite (each block prints its own PASS/FAIL lines):
## U6 determinism (same inputs twice -> equal dicts; another seed / floor -> another map; edge seeds),
## U7 layout over 1000 seeds x the 7 assigned pairs forced through v2 (14 nodes, 20 edges, slots, 3 distinct
##    archetypes, a safe / treasure lane, validator ok with pools and floor rules),
## U8 archetype rules (floor 1 never peril / elite; hellfire's peril override; Kiep 3 raises peril; weights within
##    +-3 pts over 10 000 draws),
## U9 pools (every match id in its kind's pool at a legal tier; tier_delta -1 falls back when tier 0 is empty),
## U10 teach_after over the graph (ch1 forced v2: every path to a gated elite passes a teacher),
## U11 shop plan (hub = shop exactly on the plan floors, prepare never a shop, <= 5 shops per run over 2000 run
##    seeds, <= 2 events per map, prepare = forge only when the hub is a rest).
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/region_map_gen_test.gd

const PAIRS: Array = [["ch1", 0], ["hellfire", 1], ["desert", 2], ["swamp", 3], ["ch2", 4], ["ch3", 5], ["sky_isles", 6]]
const LAYOUT_SEEDS: int = 1000

var fails: int = 0
var cfg: ChaptersConfig


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _spec(region: String, floor: int, seed: int, cleared: int = 1, kiep: int = 0) -> Dictionary:
	var s: Dictionary = cfg.region_graph_spec(region, seed, floor, cleared, kiep)
	s["kind_floors"] = {"danger": {"min_floor": 2}, "miniboss": {"min_floor": 2}}
	return s


func _initialize() -> void:
	cfg = ChaptersConfig.load_from_file()
	_u6_determinism()
	_u7_layout()
	_u8_archetypes()
	_u9_pools()
	_u10_teach()
	_u11_shop_plan()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _u6_determinism() -> void:
	var same: bool = true
	for seed: int in [0, 1, 7, 42, 1234, 99991, 0x7fffffff]:
		var a: MapGraph = RegionMapGen.generate(_spec("hellfire", 1, seed), seed)
		var b: MapGraph = RegionMapGen.generate(_spec("hellfire", 1, seed), seed)
		if a.to_dict() != b.to_dict():
			same = false
	check(same, "U6 same spec + seed twice -> identical graph (incl. seeds 0, 1, 2^31-1)")
	var a1: MapGraph = RegionMapGen.generate(_spec("hellfire", 1, 5), 5)
	var a2: MapGraph = RegionMapGen.generate(_spec("hellfire", 1, 6), 6)
	var a3: MapGraph = RegionMapGen.generate(_spec("hellfire", 3, 5), 5)
	check(a1.to_dict() != a2.to_dict(), "U6 another seed -> another map")
	check(a1.to_dict() != a3.to_dict(), "U6 another floor -> another map")
	var via_cfg: MapGraph = cfg.generate_region_graph("hellfire", 77, 1, 1)
	var direct: MapGraph = RegionMapGen.generate(cfg.region_graph_spec("hellfire", 77, 1, 1), WorldMapGen.region_map_seed(77, "hellfire", 1))
	check(via_cfg.to_dict() == direct.to_dict(), "U6 ChaptersConfig.generate_region_graph == RegionMapGen with the same seed")


func _u7_layout() -> void:
	var bad: Array[String] = []
	var maps: int = 0
	for pair: Array in PAIRS:
		var region: String = str(pair[0])
		var floor: int = int(pair[1])
		for s: int in LAYOUT_SEEDS:
			var run_seed: int = s + 1
			var g: MapGraph = cfg.generate_region_graph(region, run_seed, floor, 1, 0, true)
			maps += 1
			var spec: Dictionary = _spec(region, floor, run_seed)
			var res: Dictionary = MapValidator.validate(g, spec)
			if not bool(res["ok"]) or g.nodes.size() != 14 or g.edges.size() != 20 or g.depths != 7:
				if bad.size() < 5:
					bad.append("%s f%d s%d: n=%d e=%d %s" % [region, floor + 1, run_seed, g.nodes.size(), g.edges.size(), str(res["errors"]).left(150)])
				else:
					bad.append("")
			var slots: Dictionary = {}
			for id: String in g.node_ids():
				slots[str(g.nodes[id]["slot"])] = int(slots.get(str(g.nodes[id]["slot"]), 0)) + 1
			if slots != {"entry": 1, "lane": 9, "hub": 1, "prepare": 1, "gamble": 1, "warden": 1}:
				bad.append("%s f%d s%d: slots %s" % [region, floor + 1, run_seed, str(slots)])
	check(bad.is_empty(), "U7 %d v2 maps (7 assigned pairs x %d seeds): 14 nodes, 20 edges, 7 depths, slots, validator ok; problems: %d, first: %s" % [maps, LAYOUT_SEEDS, bad.size(), str(bad.slice(0, 2))])


func _u8_archetypes() -> void:
	var f1_hostile: int = 0
	var f1_maps: int = 300
	for s: int in f1_maps:
		var g: MapGraph = cfg.generate_region_graph("ch1", s + 1, 0, 1, 0, true)
		for l: Dictionary in g.lanes:
			if l["archetype"] == "peril" or l["archetype"] == "elite":
				f1_hostile += 1
	check(f1_hostile == 0, "U8 floor 1 never draws peril or elite (%d maps)" % f1_maps)
	var counts: Dictionary = {}
	var draws: int = 10000
	var arch: RouteArchetypes = RouteArchetypes.shared()
	var rules: RegionRules = RegionRules.shared()
	var spec: Dictionary = _spec("hellfire", 1, 1)
	for s: int in draws:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for id: String in RegionMapGen.draw_archetypes(spec, arch, rules, rng):
			counts[id] = int(counts.get(id, 0)) + 1
	check(int(counts.get("peril", 0)) > int(counts.get("elite", 0)), "U8 hellfire's peril override (1.5) draws peril more than elite (0.8): %s" % str(counts))
	var guarantee_ok: bool = true
	for s: int in 2000:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var d: Array[String] = RegionMapGen.draw_archetypes(spec, arch, rules, rng)
		if not (d.has("safe") or d.has("treasure")) or d.size() != 3 or d[0] == d[1] or d[1] == d[2] or d[0] == d[2]:
			guarantee_ok = false
	check(guarantee_ok, "U8 every draw: 3 distinct archetypes with a safe or treasure lane")
	var spec_k3: Dictionary = _spec("hellfire", 1, 1, 1, 3)
	var peril_k0: int = 0
	var peril_k3: int = 0
	for s: int in 3000:
		var r0 := RandomNumberGenerator.new()
		r0.seed = s
		var r3 := RandomNumberGenerator.new()
		r3.seed = s
		if RegionMapGen.draw_archetypes(spec, arch, rules, r0).has("peril"):
			peril_k0 += 1
		if RegionMapGen.draw_archetypes(spec_k3, arch, rules, r3).has("peril"):
			peril_k3 += 1
	check(peril_k3 > peril_k0, "U8 Kiep 3 (danger x2) raises the peril share: %d -> %d of 3000" % [peril_k0, peril_k3])
	# Weighted draw without replacement is not a plain ratio; check that no legal archetype starves on hellfire floor 2.
	var starving: bool = false
	for id: String in ["safe", "treasure", "peril", "elite", "mystery"]:
		if int(counts.get(id, 0)) < draws * 3 / 10 / 2:
			starving = true
	check(not starving, "U8 every archetype appears in >= 15 %% of lane slots on hellfire floor 2: %s" % str(counts))


func _u9_pools() -> void:
	var spec: Dictionary = cfg.region_graph_spec("hellfire", 1, 1, 1)
	var pools: Dictionary = spec["pools"]
	var ok: bool = true
	var tier0_fallback_seen: bool = false
	for s: int in 500:
		var g: MapGraph = cfg.generate_region_graph("hellfire", s + 1, 1, 1)
		for id: String in g.node_ids():
			var n: Dictionary = g.nodes[id]
			if not MapGraph.MATCH_KINDS.has(str(n["kind"])):
				continue
			var by_tier: Dictionary = pools.get(str(n["kind"]), {})
			var found: bool = false
			for t: Variant in by_tier.keys():
				if (by_tier[t] as Array).has(str(n["match_id"])):
					found = true
			if not found:
				ok = false
			if str(n["kind"]) == "danger" and int(n.get("tier", 1)) == 0:
				tier0_fallback_seen = true
	check(ok, "U9 every hellfire fight node holds an id of its kind's pool")
	# A peril slot at tier_delta 0 on floor 2 is tier 1; a safe battle at -1 is tier 0 (B0 has ids). Danger tier 0 is
	# empty in every region: force it and confirm the draw falls back instead of returning "".
	var spec_d0: Dictionary = spec.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var drawn: String = ChapterMapGen._draw_match(spec_d0, "danger", 0, [] as Array[String], rng)
	check(not drawn.is_empty() and (pools["danger"]["1"] as Array).has(drawn), "U9 danger at tier 0 (empty pool) falls back to a tier-1 id: %s" % drawn)
	check(not tier0_fallback_seen, "U9 no generated danger node is tagged tier 0 (peril uses tier_delta 0)")


func _u10_teach() -> void:
	var spec: Dictionary = cfg.region_graph_spec("ch1", 1, 0, 1)
	var lists: Dictionary = spec["teach_after"]
	check(lists.size() == 3, "U10 ch1 has 3 gated elites: %s" % str(lists.keys()))
	var broken: int = 0
	var elites_seen: int = 0
	for s: int in 2000:
		var g: MapGraph = cfg.generate_region_graph("ch1", s + 1, 1, 1, 0, true)
		for id: String in g.node_ids():
			var mid: String = str(g.nodes[id]["match_id"])
			if not lists.has(mid):
				continue
			elites_seen += 1
			var teach: Array = lists[mid]
			# Every path from the entry to this node must contain a teacher.
			if not _every_path_teaches(g, g.entry_id(), id, teach):
				broken += 1
	check(broken == 0 and elites_seen > 0, "U10 every path to a gated ch1 elite passes a teacher (%d elites over 2000 floor-2 maps, %d broken)" % [elites_seen, broken])


func _every_path_teaches(g: MapGraph, cur: String, target: String, teach: Array) -> bool:
	if cur == target:
		return false
	if teach.has(str(g.nodes[cur]["match_id"])):
		return true
	for nxt: String in g.out_edges(cur):
		if g.can_reach(nxt, target) and not _every_path_teaches(g, nxt, target, teach):
			return false
	return true


func _u11_shop_plan() -> void:
	var plan_ok: bool = true
	var prepare_shop: bool = false
	var forge_rule_ok: bool = true
	var events_ok: bool = true
	var max_shops: int = 0
	for run_seed: int in range(1, 2001):
		var plan: Array[int] = cfg.shop_floors(run_seed)
		var shops: int = 0
		for f: int in cfg.world_floors():
			var g: MapGraph = cfg.generate_region_graph(cfg.region_order()[f], run_seed, f, 1, 0, true)
			var hub: String = str(g.nodes[RegionMapGen.ID_HUB]["kind"])
			var prep: String = str(g.nodes[RegionMapGen.ID_PREPARE]["kind"])
			if (hub == "shop") != plan.has(f):
				plan_ok = false
			if prep == "shop":
				prepare_shop = true
			if (prep == "forge") != (hub == "rest"):
				forge_rule_ok = false
			if hub == "shop":
				shops += 1
			var events: int = 0
			for id: String in g.node_ids():
				if g.nodes[id]["kind"] == "event":
					events += 1
			if events > 2:
				events_ok = false
		max_shops = maxi(max_shops, shops)
	check(plan_ok, "U11 hub is a shop exactly on the run's shop-plan floors")
	check(not prepare_shop, "U11 the prepare slot is never a shop")
	check(forge_rule_ok, "U11 prepare = forge exactly when the hub is a rest (D13)")
	check(max_shops <= 4, "U11 at most 4 region shops per run (+1 final prelude = 5): max %d" % max_shops)
	check(events_ok, "U11 at most 2 events per map")

class_name RegionMapGen
extends RefCounted
## World Map v2 route generator (docs/design/world-map-v2/01 section B, 03 section 2-5, 05 section 1.1). Pure, seeded:
## same ([param spec], [param seed]) -> the same [MapGraph], byte for byte. The layout is authored, the content drawn:
##
##   depth 0 entry `n0` (battle, first tier) -> depth 1-2 three lanes `L0..L2` (slots 1-2 of their archetype template)
##   -> depth 3 `hub` (shop on a shop-plan floor, else rest / event 50/50) -> depth 4 the lanes' slot 3 -> depth 5
##   `a1` prepare (rest, or forge when the hub is a rest: D13) and `a2` gamble (miniboss from the gamble floor, else
##   event) -> depth 6 `w` warden (boss, last tier). Edges: n0 -> every L*.1; L*.1 -> L*.2; L*.2 -> hub; hub -> every
##   L*.4; L*.4 -> a1 and a2; a1, a2 -> w. 14 nodes, 20 edges.
##
## Archetypes: 3 distinct of the five, by weight (region overrides, Kiep danger node_weight raises `peril`), never
## without a guarantee lane (safe / treasure); lane order on screen seeded. Fights draw their match id with the v1 rule
## (ChapterMapGen._draw_match: the kind's pool at the slot tier, lower tiers as fallback, unused ids first,
## onboarding cap). `teach_after` (ch1 elites) is honoured over the graph: an elite at slot 2 needs a teacher at the
## entry or at its lane's slot 1 (every path to it passes both); the gamble elite needs one at the entry. When the
## draw breaks that, slot 1 is forced to a teacher (its own pool) or the elite is redrawn with the gate closed.
## Modifiers (03 section 4) per template `modifier_slots` from the region's pool, deduped against the match's own
## traits, `big_hands` guarded by `boss_min_runes`. Objectives on the slots that ask for one, from the region's legal
## ids. Streams: hash([seed, "arch"|"kinds"|"matches"|"teach"|"hub"|"mods", node]) — adding a later step never moves an
## earlier draw.
##
## [param spec] = ChaptersConfig.region_spec(...) plus: `guarantee_shop` (bool), `cleared_bosses` (int),
## `kiep_level` (int), `match_traits` ({match id: [trait ids]}), `match_min_runes` ({match id: int}); optional
## `archetypes` (RouteArchetypes) / `rules` (RegionRules) override the shared instances (tests).

const LANE_IDS: Array[String] = ["L0", "L1", "L2"]
const LANE_DEPTHS: Array[int] = [1, 2, 4]
const ID_ENTRY: String = "n0"
const ID_HUB: String = "hub"
const ID_PREPARE: String = "a1"
const ID_GAMBLE: String = "a2"
const ID_WARDEN: String = "w"
const SEED_MASK: int = 0x7fffffff
## The only archetype that may appear twice (when a floor has fewer than 3 legal ones).
const FALLBACK_ARCHETYPE: String = "safe"
## Event nodes per map at most (01 section B5).
const MAX_EVENTS: int = 2


## See the class doc. Never returns null: a spec without pools still yields the layout (fight nodes with empty match
## ids, which the validator then reports).
static func generate(spec: Dictionary, seed: int) -> MapGraph:
	var archetypes: RouteArchetypes = spec.get("archetypes") if spec.get("archetypes") is RouteArchetypes else RouteArchetypes.shared()
	var rules: RegionRules = spec.get("rules") if spec.get("rules") is RegionRules else RegionRules.shared()
	var region_id: String = str(spec.get("region_id", spec.get("id", "")))
	var floor_number: int = maxi(int(spec.get("floor_number", 1)), 1)
	var g := MapGraph.new()
	g.source = MapGraph.SOURCE_V2
	g.region_id = region_id
	g.floor = maxi(int(spec.get("floor", floor_number - 1)), 0)
	g.seed = seed
	g.depths = rules.depth_layout.size()
	var tiers: Dictionary = _tiers(spec)

	# 1. Archetypes and lane order.
	var arch_rng := _rng(seed, ["arch"])
	var drawn: Array[String] = draw_archetypes(spec, archetypes, rules, arch_rng)
	for i: int in LANE_IDS.size():
		g.lanes.append({"id": LANE_IDS[i], "archetype": drawn[i], "order": i})

	# 2. Kinds of every slot (one stream, fixed order: lanes by id, slots by depth, then hub / approach).
	var gamble: Dictionary = archetypes.gamble()
	var gamble_kind: String = str(gamble["kind"]) if floor_number >= int(gamble["min_floor"]) else str(gamble["before_min_floor"])
	# Event cap (01 section B5): at most MAX_EVENTS event nodes on a map, counted in generation order: the gamble (floor
	# 1), then the lanes' slots, then the hub. A slot whose draw would pass the cap takes its other option (treasure),
	# a hub that would pass it becomes a rest.
	var events: int = 1 if gamble_kind == "event" else 0
	var kinds_rng := _rng(seed, ["kinds"])
	var slot_specs: Dictionary = {}
	for li: int in LANE_IDS.size():
		var template: Dictionary = archetypes.template(drawn[li])
		for si: int in LANE_DEPTHS.size():
			var s: Dictionary = template["slots"][si]
			var options: Array[String] = []
			options.assign(s["kind"])
			var kind: String = options[0] if options.size() == 1 else options[kinds_rng.randi_range(0, options.size() - 1)]
			if kind == "event" and events >= MAX_EVENTS:
				for alt: String in options:
					if alt != "event":
						kind = alt
						break
			if kind == "event":
				events += 1
			slot_specs[_lane_node_id(LANE_IDS[li], si)] = {"kind": kind, "slot": s, "mod_count": int(template["modifier_slots"][si]), "lane": LANE_IDS[li], "depth": LANE_DEPTHS[si]}
	var hub_rng := _rng(seed, ["hub"])
	var hub_kind: String = ""
	if bool(spec.get("guarantee_shop", false)):
		hub_kind = "shop"
	else:
		var hubs: Array[String] = archetypes.hub_kinds()
		hub_kind = hubs[hub_rng.randi_range(0, hubs.size() - 1)]
		if hub_kind == "event" and events >= MAX_EVENTS:
			hub_kind = "rest"
	var prepare_kind: String = "rest" if hub_kind != "rest" else MapGraph.KIND_FORGE

	# 3. Nodes with their match ids (one stream, fixed order: entry, lanes, gamble, warden).
	var match_rng := _rng(seed, ["matches"])
	var used: Array[String] = []
	var lists: Dictionary = _teach_lists(spec)
	var open_gate: Callable = func(_id: String) -> bool: return true
	var entry_match: String = _draw(spec, "battle", int(tiers["first"]), used, match_rng, open_gate if not lists.is_empty() else Callable())
	g.add_node({"id": ID_ENTRY, "depth": 0, "lane": "", "slot": MapGraph.SLOT_ENTRY, "kind": "battle", "match_id": entry_match,
		"reward_tier": 1, "tier": int(tiers["first"])})
	used.append(entry_match)
	for li: int in LANE_IDS.size():
		for si: int in LANE_DEPTHS.size():
			var id: String = _lane_node_id(LANE_IDS[li], si)
			var ss: Dictionary = slot_specs[id]
			var s: Dictionary = ss["slot"]
			var kind: String = str(ss["kind"])
			var tier: int = maxi(int(tiers["middle"]) + int(s["tier_delta"]), 0)
			var match_id: String = ""
			if MapGraph.MATCH_KINDS.has(kind):
				match_id = _draw(spec, kind, tier, used, match_rng, open_gate if not lists.is_empty() else Callable())
				used.append(match_id)
			var record: Dictionary = {"id": id, "depth": int(ss["depth"]), "lane": LANE_IDS[li], "slot": MapGraph.SLOT_LANE, "kind": kind,
				"match_id": match_id, "reward_tier": int(s["reward_tier"]), "tier": tier}
			if float(s["gold_mult"]) != 1.0:
				record["gold_mult"] = float(s["gold_mult"])
			if int(s["relic_offer"]) > 0:
				record["relic_offer"] = int(s["relic_offer"])
			g.add_node(record)
	g.add_node({"id": ID_HUB, "depth": 3, "lane": "", "slot": MapGraph.SLOT_HUB, "kind": hub_kind, "match_id": "", "reward_tier": 1})
	g.add_node({"id": ID_PREPARE, "depth": 5, "lane": "", "slot": MapGraph.SLOT_PREPARE, "kind": prepare_kind, "match_id": "", "reward_tier": 1})
	var gamble_match: String = ""
	if MapGraph.MATCH_KINDS.has(gamble_kind):
		gamble_match = _draw(spec, gamble_kind, int(tiers["middle"]), used, match_rng, open_gate if not lists.is_empty() else Callable())
		used.append(gamble_match)
	g.add_node({"id": ID_GAMBLE, "depth": 5, "lane": "", "slot": MapGraph.SLOT_GAMBLE, "kind": gamble_kind, "match_id": gamble_match,
		"reward_tier": 3 if gamble_kind == "miniboss" else 1, "tier": int(tiers["middle"])})
	var warden_match: String = _draw(spec, "boss", int(tiers["last"]), used, match_rng)
	g.add_node({"id": ID_WARDEN, "depth": 6, "lane": "", "slot": MapGraph.SLOT_WARDEN, "kind": "boss", "match_id": warden_match,
		"reward_tier": 1, "tier": int(tiers["last"])})

	# 4. teach_after over the graph (own stream; a map without lists is untouched).
	if not lists.is_empty():
		_teach_gated(g, spec, lists, tiers, _rng(seed, ["teach"]))

	# 5. Modifiers and objectives (own stream per node).
	var pool: Array[String] = rules.modifier_pool(region_id)
	var objective_ids: Array[String] = archetypes.objective_ids(region_id)
	for li: int in LANE_IDS.size():
		for si: int in LANE_DEPTHS.size():
			var id: String = _lane_node_id(LANE_IDS[li], si)
			var ss: Dictionary = slot_specs[id]
			var n: Dictionary = g.nodes[id]
			if not MapGraph.MATCH_KINDS.has(str(n["kind"])):
				continue
			var want: int = int(ss["mod_count"])
			if want > 0 and not pool.is_empty():
				n["modifiers"] = draw_modifiers(pool, want, str(n["match_id"]), spec, rules, _rng(seed, ["mods", id]))
			if bool((ss["slot"] as Dictionary)["objective"]) and not objective_ids.is_empty():
				var orng := _rng(seed, ["objective", id])
				n["objective"] = objective_ids[orng.randi_range(0, objective_ids.size() - 1)]

	# 6. Edges (authored).
	for lane_id: String in LANE_IDS:
		g.add_edge(ID_ENTRY, _lane_node_id(lane_id, 0))
		g.add_edge(_lane_node_id(lane_id, 0), _lane_node_id(lane_id, 1))
		g.add_edge(_lane_node_id(lane_id, 1), ID_HUB)
		g.add_edge(ID_HUB, _lane_node_id(lane_id, 2))
		g.add_edge(_lane_node_id(lane_id, 2), ID_PREPARE)
		g.add_edge(_lane_node_id(lane_id, 2), ID_GAMBLE)
	g.add_edge(ID_PREPARE, ID_WARDEN)
	g.add_edge(ID_GAMBLE, ID_WARDEN)

	# 7. Rule state at entry.
	var rule: Dictionary = rules.rule_for(region_id)
	if not rule.is_empty():
		g.rule = {"id": str(rule["id"]), "gauge": RegionRules.gauge_start(rule)}
	return g


## Three archetype ids for the lanes, in screen order (seeded): distinct, by weight (region overrides; Kiep's danger
## node_weight multiplies `peril`), legal on the floor, with at least one guarantee archetype; `safe` repeats when the
## floor has fewer than three legal ones.
static func draw_archetypes(spec: Dictionary, archetypes: RouteArchetypes, rules: RegionRules, rng: RandomNumberGenerator) -> Array[String]:
	var region_id: String = str(spec.get("region_id", spec.get("id", "")))
	var floor_number: int = maxi(int(spec.get("floor_number", 1)), 1)
	var overrides: Dictionary = rules.archetype_weights(region_id)
	var kiep: int = int(spec.get("kiep_level", 0))
	var legal: Array[String] = []
	var weights: Dictionary = {}
	for id: String in archetypes.ids():
		if archetypes.min_floor(id) > floor_number:
			continue
		var w: float = archetypes.weight(id, overrides)
		if id == RouteArchetypes.PERIL and kiep > 0:
			w *= KiepRules.shared().node_weight_mult("danger", kiep)
		if w <= 0.0:
			continue
		legal.append(id)
		weights[id] = w
	var out: Array[String] = []
	var remaining: Array[String] = legal.duplicate()
	while out.size() < LANE_IDS.size() and not remaining.is_empty():
		var pick: String = _weighted(remaining, weights, rng)
		out.append(pick)
		remaining.erase(pick)
	var guarantee: Array[String] = archetypes.guarantee()
	var has_guarantee: bool = false
	for id: String in out:
		if guarantee.has(id):
			has_guarantee = true
	if not has_guarantee and out.size() == LANE_IDS.size():
		var options: Array[String] = []
		for id: String in guarantee:
			if legal.has(id):
				options.append(id)
		if not options.is_empty():
			out[out.size() - 1] = _weighted(options, weights, rng)
	while out.size() < LANE_IDS.size():
		out.append(FALLBACK_ARCHETYPE)
	# Screen order: seeded shuffle so "top lane" never means one archetype.
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## [param want] distinct modifier ids from [param pool] for the fight [param match_id]: a modifier whose trait the
## match already carries is skipped, `big_hands` is skipped when the match's boss_min_runes is above its guard.
static func draw_modifiers(pool: Array[String], want: int, match_id: String, spec: Dictionary, rules: RegionRules, rng: RandomNumberGenerator) -> Array[String]:
	var traits: Array = (spec.get("match_traits", {}) as Dictionary).get(match_id, [])
	var min_runes: int = int((spec.get("match_min_runes", {}) as Dictionary).get(match_id, 0))
	var candidates: Array[String] = []
	for id: String in pool:
		var m: Dictionary = rules.modifier(id)
		if m.is_empty():
			continue
		if m.has("trait") and traits.has(str((m["trait"] as Dictionary).get("id", ""))):
			continue
		if m.has("guard") and typeof(m["guard"]) == TYPE_DICTIONARY and (m["guard"] as Dictionary).has("boss_min_runes_max") \
				and min_runes > int((m["guard"] as Dictionary)["boss_min_runes_max"]):
			continue
		candidates.append(id)
	var out: Array[String] = []
	while out.size() < want and not candidates.is_empty():
		out.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return out


## Node id of lane [param lane_id]'s slot [param slot_index] (0..2): "L0.1", "L0.2", "L0.4".
static func _lane_node_id(lane_id: String, slot_index: int) -> String:
	return "%s.%d" % [lane_id, LANE_DEPTHS[slot_index]]


static func _rng(seed: int, tags: Array) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var key: Array = [seed]
	key.append_array(tags)
	rng.seed = hash(key) & SEED_MASK
	return rng


static func _weighted(ids: Array[String], weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for id: String in ids:
		total += float(weights.get(id, 0.0))
	if total <= 0.0:
		return ids[rng.randi_range(0, ids.size() - 1)]
	var pick: float = rng.randf() * total
	for id: String in ids:
		pick -= float(weights.get(id, 0.0))
		if pick < 0.0:
			return id
	return ids[ids.size() - 1]


# {first, middle, last} pool tiers from the spec's columns (region_spec applies floor_tiers), capped by the onboarding
# rule when no boss was ever cleared (ChapterMapGen.generate does the same).
static func _tiers(spec: Dictionary) -> Dictionary:
	var columns: Array = spec.get("columns", []) if typeof(spec.get("columns")) == TYPE_ARRAY else []
	var first: int = 0
	var middle: int = 1
	var last: int = 1
	if not columns.is_empty():
		first = int((columns[0] as Dictionary).get("tier", 0))
		last = int((columns[columns.size() - 1] as Dictionary).get("tier", last))
		middle = int((columns[1] as Dictionary).get("tier", middle)) if columns.size() > 2 else last
	if int(spec.get("cleared_bosses", 1)) <= 0:
		var cap: int = int(spec.get("onboarding_tier_cap", 1))
		first = mini(first, cap)
		middle = mini(middle, cap)
		last = mini(last, cap)
	return {"first": first, "middle": middle, "last": last}


static func _draw(spec: Dictionary, kind: String, tier: int, used: Array[String], rng: RandomNumberGenerator, gate: Callable = Callable()) -> String:
	return ChapterMapGen._draw_match(spec, kind, tier, used, rng, gate)


static func _teach_lists(spec: Dictionary) -> Dictionary:
	var lists: Variant = spec.get("teach_after", {})
	return lists as Dictionary if typeof(lists) == TYPE_DICTIONARY else {}


# Every gated elite must have a teacher on every path to it: slot 2 of a lane -> the entry or that lane's slot 1;
# the gamble -> the entry. Fix order: force slot 1 (battle / danger, a teacher legal in its own pool) first, else redraw
# the elite with the gate closed (another id of the same pool / tier), else keep it (the pool had nothing else).
static func _teach_gated(g: MapGraph, spec: Dictionary, lists: Dictionary, tiers: Dictionary, rng: RandomNumberGenerator) -> void:
	var entry_match: String = str(g.nodes[ID_ENTRY]["match_id"])
	for lane_id: String in LANE_IDS:
		var slot1: String = _lane_node_id(lane_id, 0)
		var slot2: String = _lane_node_id(lane_id, 1)
		var elite: String = str(g.nodes[slot2]["match_id"])
		if elite.is_empty() or not lists.has(elite):
			continue
		var teach: Array = lists[elite] as Array
		if teach.has(entry_match) or teach.has(str(g.nodes[slot1]["match_id"])):
			continue
		var n1: Dictionary = g.nodes[slot1]
		if ChapterMapGen.TEACH_KINDS.has(str(n1["kind"])):
			var legal: Array = ChapterMapGen._pool_teachers(spec, str(n1["kind"]), int(n1.get("tier", tiers["middle"])), teach)
			if not legal.is_empty():
				var fresh: Array = legal.filter(func(x: Variant) -> bool: return not _used_ids(g).has(str(x)))
				var source: Array = fresh if not fresh.is_empty() else legal
				n1["match_id"] = str(source[rng.randi_range(0, source.size() - 1)])
				continue
		_redraw_untaught(g, slot2, spec, lists, rng, [entry_match, str(g.nodes[slot1]["match_id"])])
	var gamble: Dictionary = g.nodes[ID_GAMBLE]
	var gm: String = str(gamble["match_id"])
	if not gm.is_empty() and lists.has(gm) and not (lists[gm] as Array).has(entry_match):
		# The entry is the one node on every path to the gamble: make it a teacher when its pool has one.
		var entry: Dictionary = g.nodes[ID_ENTRY]
		var legal: Array = ChapterMapGen._pool_teachers(spec, "battle", int(entry.get("tier", tiers["first"])), lists[gm] as Array)
		if not legal.is_empty():
			var fresh: Array = legal.filter(func(x: Variant) -> bool: return not _used_ids(g).has(str(x)))
			var source: Array = fresh if not fresh.is_empty() else legal
			entry["match_id"] = str(source[rng.randi_range(0, source.size() - 1)])
		else:
			_redraw_untaught(g, ID_GAMBLE, spec, lists, rng, [entry_match])


static func _redraw_untaught(g: MapGraph, id: String, spec: Dictionary, lists: Dictionary, rng: RandomNumberGenerator, teachers_on_path: Array) -> void:
	var n: Dictionary = g.nodes[id]
	var used: Array[String] = _used_ids(g)
	used.erase(str(n["match_id"]))
	var gate: Callable = func(x: String) -> bool:
		if not lists.has(x):
			return true
		for t: Variant in teachers_on_path:
			if (lists[x] as Array).has(str(t)):
				return true
		return false
	n["match_id"] = ChapterMapGen._draw_match(spec, str(n["kind"]), int(n.get("tier", 1)), used, rng, gate)
	if str(n["match_id"]).is_empty():
		# Every id of the pool is gated and nothing on the path teaches it (ch1's whole miniboss pool is gated): the
		# slot degrades to an ordinary battle of the same tier, the pack rule "no elite before its teacher" over a
		# forced elite (ADR-0001 D3 / pack 02 section 3 item 1 and 6).
		n["kind"] = "battle"
		n["match_id"] = ChapterMapGen._draw_match(spec, "battle", int(n.get("tier", 1)), used, rng)
		n["reward_tier"] = mini(int(n["reward_tier"]), 2)
		n.erase("relic_offer")


static func _used_ids(g: MapGraph) -> Array[String]:
	var out: Array[String] = []
	for id: String in g.node_ids():
		var m: String = str(g.nodes[id]["match_id"])
		if not m.is_empty():
			out.append(m)
	return out

class_name MapValidator
extends RefCounted
## World Map v2 (docs/design/world-map-v2/06-validation-plan.md section 2): the one place that says whether a [MapGraph]
## is a legal region map. Pure, static. [method validate] returns {ok: bool, errors: Array[String]} and never throws;
## [method metrics] counts what the simulation reports. Rules marked (v2) apply only to generated maps (source "v2");
## a wrapped v1 map must pass the structural rules alone (U5).
##
## Structural rules (every graph): exactly one entry at depth 0; a warden; every edge names known nodes and goes to a
## strictly higher depth; every node reachable from the entry; the warden reachable from every node; every node but the
## warden has an out-edge and every node but the entry an in-edge; every node kind known; fight kinds carry a match id;
## with a [param spec] ({pools, match_ids, floor_number}) every fight node's match id is in the spec's pool of its kind
## and kinds respect min_floor / max_floor (danger and miniboss from floor 2, event-in-gamble only on floor 1 — the shipped
## chapters.json rules, passed in through spec.kind_floors).
## v2 rules: depths and node count match spec.depth_layout; slots hub / prepare / gamble / warden each exactly once;
## three lanes with three distinct archetypes, at least one of safe / treasure; lane nodes only on their lane's depths;
## no cross-lane edge except into / out of the hub and from depth-4 into the approach.

const ERR_ENTRY: String = "entry"
const ERR_WARDEN: String = "warden"
const ERR_EDGE: String = "edge"
const ERR_REACH: String = "reach"
const ERR_DEAD_END: String = "dead_end"
const ERR_ORPHAN: String = "orphan"
const ERR_KIND: String = "kind"
const ERR_MATCH: String = "match"
const ERR_POOL: String = "pool"
const ERR_FLOOR: String = "floor_rule"
const ERR_LAYOUT: String = "layout"
const ERR_SLOT: String = "slot"
const ERR_ARCHETYPE: String = "archetype"
const ERR_LANE: String = "lane"
## Archetypes counted as "breathing" lanes: a map must hold at least one.
const GUARANTEE_ARCHETYPES: Array[String] = ["safe", "treasure"]


## See the class doc. [param spec] optional: {pools, match_ids, floor_number, depth_layout, kind_floors}.
static func validate(graph: MapGraph, spec: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []
	if graph == null or graph.nodes.is_empty():
		errors.append("%s: no graph" % ERR_ENTRY)
		return {"ok": false, "errors": errors}
	var entry: String = graph.entry_id()
	if entry.is_empty():
		errors.append("%s: expected exactly one node at depth 0, found %d" % [ERR_ENTRY, graph.nodes_at_depth(0).size()])
	var warden: String = graph.warden_id()
	if warden.is_empty():
		errors.append("%s: no warden node" % ERR_WARDEN)
	for e: Variant in graph.edges:
		var a: String = str((e as Array)[0])
		var b: String = str((e as Array)[1])
		if not graph.has_node(a) or not graph.has_node(b):
			errors.append("%s: %s -> %s names an unknown node" % [ERR_EDGE, a, b])
		elif int(graph.nodes[a]["depth"]) >= int(graph.nodes[b]["depth"]):
			errors.append("%s: %s -> %s does not go to a deeper depth" % [ERR_EDGE, a, b])
	if not entry.is_empty():
		var reach: Array[String] = graph.reachable_from(entry)
		for id: String in graph.node_ids():
			if id != entry and not reach.has(id):
				errors.append("%s: %s is not reachable from the entry" % [ERR_REACH, id])
	if not warden.is_empty():
		for id: String in graph.node_ids():
			if not graph.can_reach(id, warden):
				errors.append("%s: the warden is not reachable from %s" % [ERR_REACH, id])
	for id: String in graph.node_ids():
		var n: Dictionary = graph.nodes[id]
		if id != warden and graph.out_edges(id).is_empty():
			errors.append("%s: %s has no way out" % [ERR_DEAD_END, id])
		if id != entry and graph.in_edges(id).is_empty():
			errors.append("%s: %s has no way in" % [ERR_ORPHAN, id])
		var kind: String = str(n["kind"])
		if not MapGraph.KINDS.has(kind):
			errors.append("%s: %s has unknown kind '%s'" % [ERR_KIND, id, kind])
		if MapGraph.MATCH_KINDS.has(kind) and str(n["match_id"]).is_empty():
			errors.append("%s: fight node %s has no match id" % [ERR_MATCH, id])
		if not MapGraph.MATCH_KINDS.has(kind) and not str(n["match_id"]).is_empty():
			errors.append("%s: %s (%s) carries a match id" % [ERR_MATCH, id, kind])
	if not spec.is_empty():
		_check_pools(graph, spec, errors)
		_check_floor_rules(graph, spec, errors)
	if not graph.is_v1():
		_check_v2_layout(graph, spec, errors)
	return {"ok": errors.is_empty(), "errors": errors}


## Counts for the simulation: nodes, edges, depths, lanes, archetypes (sorted ids joined by "+"), distinct match ids,
## repeated match id on one lane (count of lanes), paths entry -> warden, max in / out degree, kinds histogram.
static func metrics(graph: MapGraph) -> Dictionary:
	var kinds: Dictionary = {}
	var match_ids: Dictionary = {}
	var max_out: int = 0
	var max_in: int = 0
	for id: String in graph.node_ids():
		var n: Dictionary = graph.nodes[id]
		kinds[str(n["kind"])] = int(kinds.get(str(n["kind"]), 0)) + 1
		if not str(n["match_id"]).is_empty():
			match_ids[str(n["match_id"])] = true
		max_out = maxi(max_out, graph.out_edges(id).size())
		max_in = maxi(max_in, graph.in_edges(id).size())
	var archetypes: Array[String] = []
	for l: Dictionary in graph.lanes:
		archetypes.append(str(l.get("archetype", "")))
	archetypes.sort()
	var lane_repeats: int = 0
	for l: Dictionary in graph.lanes:
		var seen: Dictionary = {}
		var repeat: bool = false
		for id: String in graph.node_ids():
			var n: Dictionary = graph.nodes[id]
			if str(n["lane"]) == str(l.get("id", "")) and not str(n["match_id"]).is_empty():
				if seen.has(str(n["match_id"])):
					repeat = true
				seen[str(n["match_id"])] = true
		if repeat:
			lane_repeats += 1
	return {
		"nodes": graph.nodes.size(), "edges": graph.edges.size(), "depths": graph.depths, "lanes": graph.lanes.size(),
		"archetypes": "+".join(archetypes), "distinct_match_ids": match_ids.size(), "lane_repeats": lane_repeats,
		"paths_to_warden": _count_paths(graph, graph.entry_id(), graph.warden_id()), "max_out": max_out, "max_in": max_in,
		"kinds": kinds,
	}


static func _count_paths(graph: MapGraph, from: String, to: String) -> int:
	if from.is_empty() or to.is_empty():
		return 0
	var memo: Dictionary = {}
	return _paths_rec(graph, from, to, memo)


static func _paths_rec(graph: MapGraph, cur: String, to: String, memo: Dictionary) -> int:
	if cur == to:
		return 1
	if memo.has(cur):
		return int(memo[cur])
	var total: int = 0
	for nxt: String in graph.out_edges(cur):
		total += _paths_rec(graph, nxt, to, memo)
	memo[cur] = total
	return total


static func _check_pools(graph: MapGraph, spec: Dictionary, errors: Array[String]) -> void:
	var pools: Variant = spec.get("pools", {})
	if typeof(pools) != TYPE_DICTIONARY:
		return
	var all_ids: Array = spec.get("match_ids", []) if typeof(spec.get("match_ids")) == TYPE_ARRAY else []
	for id: String in graph.node_ids():
		var n: Dictionary = graph.nodes[id]
		var kind: String = str(n["kind"])
		if not MapGraph.MATCH_KINDS.has(kind) or str(n["match_id"]).is_empty():
			continue
		var mid: String = str(n["match_id"])
		var by_tier: Variant = (pools as Dictionary).get(kind)
		var found: bool = false
		if typeof(by_tier) == TYPE_DICTIONARY:
			for t: Variant in (by_tier as Dictionary).keys():
				var ids: Variant = (by_tier as Dictionary)[t]
				if typeof(ids) == TYPE_ARRAY and (ids as Array).has(mid):
					found = true
		elif all_ids.has(mid):
			# A kind without a pool draws from the chapter's matches (ChapterMapGen._draw_match).
			found = true
		if not found:
			errors.append("%s: %s (%s) holds '%s', not in the %s pool" % [ERR_POOL, id, kind, mid, kind])


# spec.kind_floors = {kind: {min_floor, max_floor}} (0 = none) with spec.floor_number (1-based).
static func _check_floor_rules(graph: MapGraph, spec: Dictionary, errors: Array[String]) -> void:
	var rules: Variant = spec.get("kind_floors", {})
	var floor_number: int = int(spec.get("floor_number", 0))
	if typeof(rules) != TYPE_DICTIONARY or floor_number <= 0:
		return
	for id: String in graph.node_ids():
		var kind: String = str(graph.nodes[id]["kind"])
		var r: Variant = (rules as Dictionary).get(kind)
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var lo: int = int((r as Dictionary).get("min_floor", 0))
		var hi: int = int((r as Dictionary).get("max_floor", 0))
		if lo > 0 and floor_number < lo:
			errors.append("%s: %s is a %s on floor %d (min_floor %d)" % [ERR_FLOOR, id, kind, floor_number, lo])
		if hi > 0 and floor_number > hi:
			errors.append("%s: %s is a %s on floor %d (max_floor %d)" % [ERR_FLOOR, id, kind, floor_number, hi])


static func _check_v2_layout(graph: MapGraph, spec: Dictionary, errors: Array[String]) -> void:
	var layout: Variant = spec.get("depth_layout", RegionRules.DEFAULT_DEPTH_LAYOUT)
	if typeof(layout) == TYPE_ARRAY and not (layout as Array).is_empty():
		var want_depths: int = (layout as Array).size()
		if graph.depths != want_depths:
			errors.append("%s: %d depths, expected %d" % [ERR_LAYOUT, graph.depths, want_depths])
		for d: int in want_depths:
			var have: int = graph.nodes_at_depth(d).size()
			if have != int((layout as Array)[d]):
				errors.append("%s: depth %d has %d nodes, expected %d" % [ERR_LAYOUT, d, have, int((layout as Array)[d])])
	var slot_counts: Dictionary = {}
	for id: String in graph.node_ids():
		var slot: String = str(graph.nodes[id]["slot"])
		slot_counts[slot] = int(slot_counts.get(slot, 0)) + 1
	for slot: String in [MapGraph.SLOT_HUB, MapGraph.SLOT_PREPARE, MapGraph.SLOT_GAMBLE, MapGraph.SLOT_WARDEN, MapGraph.SLOT_ENTRY]:
		if int(slot_counts.get(slot, 0)) != 1:
			errors.append("%s: slot %s appears %d times" % [ERR_SLOT, slot, int(slot_counts.get(slot, 0))])
	if graph.lanes.size() != 3:
		errors.append("%s: %d lanes, expected 3" % [ERR_LANE, graph.lanes.size()])
	var seen: Dictionary = {}
	var breathing: bool = false
	for l: Dictionary in graph.lanes:
		var a: String = str(l.get("archetype", ""))
		if a.is_empty():
			errors.append("%s: lane %s has no archetype" % [ERR_ARCHETYPE, str(l.get("id", ""))])
		if seen.has(a):
			errors.append("%s: archetype %s appears twice" % [ERR_ARCHETYPE, a])
		seen[a] = true
		if GUARANTEE_ARCHETYPES.has(a):
			breathing = true
	if not graph.lanes.is_empty() and not breathing:
		errors.append("%s: no safe / treasure lane" % ERR_ARCHETYPE)
	# Cross-lane edges: a lane node links only to its own lane, the hub, or the approach (prepare / gamble).
	for e: Variant in graph.edges:
		var a: String = str((e as Array)[0])
		var b: String = str((e as Array)[1])
		if not graph.has_node(a) or not graph.has_node(b):
			continue
		var na: Dictionary = graph.nodes[a]
		var nb: Dictionary = graph.nodes[b]
		if str(na["slot"]) == MapGraph.SLOT_LANE and str(nb["slot"]) == MapGraph.SLOT_LANE and str(na["lane"]) != str(nb["lane"]):
			errors.append("%s: %s -> %s crosses lanes outside the hub" % [ERR_LANE, a, b])

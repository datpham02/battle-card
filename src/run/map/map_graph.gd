class_name MapGraph
extends RefCounted
## World Map v2 (docs/design/world-map-v2/04-technical-architecture.md section 2): one region map as a directed graph of
## nodes with stable string ids. Pure data: no scene, no RNG. Built by [RegionMapGen] (schema 2, "v2") or wrapped from a
## v1 column map by [method from_v1_columns] (schema 2, source "v1"), so RunSession, GameFlow and the views speak one API
## whichever generator made the floor. [method to_dict] / [method from_dict] carry it through the run save (v8).
##
## Node record: {id, depth, lane, slot, kind, match_id, reward_tier, modifiers: Array[String], objective: String,
## tags: Array[String]} — v1-wrapped nodes carry reward_tier 1, no modifiers, no objective and the tag "v1".
## Slots: "entry" (depth 0), "lane" (a lane node), "hub", "prepare", "gamble", "warden", "v1" (a wrapped column node).
## Edges: [from_id, to_id], always from a lower depth to a higher one (the validator checks it).

const SCHEMA: int = 2
const SOURCE_V1: String = "v1"
const SOURCE_V2: String = "v2"
const SLOT_ENTRY: String = "entry"
const SLOT_LANE: String = "lane"
const SLOT_HUB: String = "hub"
const SLOT_PREPARE: String = "prepare"
const SLOT_GAMBLE: String = "gamble"
const SLOT_WARDEN: String = "warden"
const SLOT_V1: String = "v1"
const SLOTS: Array[String] = [SLOT_ENTRY, SLOT_LANE, SLOT_HUB, SLOT_PREPARE, SLOT_GAMBLE, SLOT_WARDEN, SLOT_V1]
## Node kinds the graph accepts: the ChapterMapGen kinds plus the v2 `forge` (01 section B8).
const KIND_FORGE: String = "forge"
const KINDS: Array[String] = ["battle", "danger", "treasure", "rest", "miniboss", "boss", "shop", "event", KIND_FORGE]
## Kinds that play a match (match_id required).
const MATCH_KINDS: Array[String] = ["battle", "danger", "miniboss", "boss"]
const TAG_V1: String = "v1"

var source: String = SOURCE_V2
var region_id: String = ""
var floor: int = 0
var seed: int = 0
## Number of depths (columns on screen); nodes have depth 0..depths-1.
var depths: int = 0
## [{id, archetype, order}] in screen order (top to bottom); empty for a wrapped v1 map.
var lanes: Array[Dictionary] = []
## id -> node record (insertion order = generation order; [method node_ids] sorts by depth then order).
var nodes: Dictionary = {}
## [[from, to]] in insertion order.
var edges: Array = []
## Live region-rule state copied here on save ({id, gauge}); RunSession owns the authoritative copy.
var rule: Dictionary = {}

var _out: Dictionary = {}
var _in: Dictionary = {}
var _cache_ok: bool = false


## Adds a node record (missing optional fields get defaults). False (warning) for a duplicate or empty id.
func add_node(record: Dictionary) -> bool:
	var id: String = str(record.get("id", ""))
	if id.is_empty() or nodes.has(id):
		push_warning("MapGraph: node id '%s' empty or duplicate, dropped" % id)
		return false
	nodes[id] = clean_node(record)
	_cache_ok = false
	return true


## Adds the edge from -> to. False (warning) when an id is unknown or the edge exists already.
func add_edge(from: String, to: String) -> bool:
	if not nodes.has(from) or not nodes.has(to):
		push_warning("MapGraph: edge %s -> %s names an unknown node, dropped" % [from, to])
		return false
	for e: Variant in edges:
		if str((e as Array)[0]) == from and str((e as Array)[1]) == to:
			return false
	edges.append([from, to])
	_cache_ok = false
	return true


func has_node(id: String) -> bool:
	return nodes.has(id)


## Copy of the node record; {} when unknown.
func node(id: String) -> Dictionary:
	if not nodes.has(id):
		return {}
	return (nodes[id] as Dictionary).duplicate(true)


## Node ids sorted by (depth, lane order, id) — the stable screen order.
func node_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(nodes.keys())
	var order: Dictionary = {}
	for i: int in lanes.size():
		order[str(lanes[i].get("id", ""))] = int(lanes[i].get("order", i))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var na: Dictionary = nodes[a]
		var nb: Dictionary = nodes[b]
		if int(na["depth"]) != int(nb["depth"]):
			return int(na["depth"]) < int(nb["depth"])
		var la: int = int(order.get(str(na["lane"]), 0))
		var lb: int = int(order.get(str(nb["lane"]), 0))
		if la != lb:
			return la < lb
		return a < b)
	return ids


## Ids of the nodes at [param depth], in screen order.
func nodes_at_depth(depth: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in node_ids():
		if int((nodes[id] as Dictionary)["depth"]) == depth:
			out.append(id)
	return out


## Ids this node links to (ascending by screen order); [] for an unknown id.
func out_edges(id: String) -> Array[String]:
	_build_cache()
	var out: Array[String] = []
	if _out.has(id):
		out.assign(_out[id])
	return out


## Ids that link into this node; [] for an unknown id.
func in_edges(id: String) -> Array[String]:
	_build_cache()
	var out: Array[String] = []
	if _in.has(id):
		out.assign(_in[id])
	return out


## The single depth-0 node's id ("" when there is none or more than one).
func entry_id() -> String:
	var at: Array[String] = nodes_at_depth(0)
	return at[0] if at.size() == 1 else ""


## The id of the node in slot "warden", else the single node of the last depth ("" when neither).
func warden_id() -> String:
	for id: String in node_ids():
		if str((nodes[id] as Dictionary)["slot"]) == SLOT_WARDEN:
			return id
	if depths <= 0:
		return ""
	var last: Array[String] = nodes_at_depth(depths - 1)
	return last[0] if last.size() == 1 else ""


## Lane record of [param lane_id] ({} when none).
func lane(lane_id: String) -> Dictionary:
	for l: Dictionary in lanes:
		if str(l.get("id", "")) == lane_id:
			return l.duplicate()
	return {}


## Archetype of the lane the node sits on ("" for hub / approach / entry / warden / v1 nodes).
func archetype_of(id: String) -> String:
	if not nodes.has(id):
		return ""
	return str(lane(str((nodes[id] as Dictionary)["lane"])).get("archetype", ""))


## True for a graph wrapped from a v1 column map.
func is_v1() -> bool:
	return source == SOURCE_V1


## Ids of every node reachable from [param from] (excluding it) by following out-edges.
func reachable_from(from: String) -> Array[String]:
	var seen: Dictionary = {}
	var stack: Array[String] = [from]
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for nxt: String in out_edges(cur):
			if not seen.has(nxt):
				seen[nxt] = true
				stack.append(nxt)
	var out: Array[String] = []
	out.assign(seen.keys())
	out.sort()
	return out


## True when [param to] can be reached from [param from] (or they are the same node).
func can_reach(from: String, to: String) -> bool:
	return from == to or reachable_from(from).has(to)


## Serialises the graph (sorted node ids, edges in insertion order). The result round-trips through [method from_dict].
func to_dict() -> Dictionary:
	var out_nodes: Dictionary = {}
	for id: String in node_ids():
		out_nodes[id] = (nodes[id] as Dictionary).duplicate(true)
	var out_edges: Array = []
	for e: Variant in edges:
		out_edges.append([str((e as Array)[0]), str((e as Array)[1])])
	var out_lanes: Array = []
	for l: Dictionary in lanes:
		out_lanes.append(l.duplicate(true))
	return {
		"schema": SCHEMA, "source": source, "region_id": region_id, "floor": floor, "seed": seed, "depths": depths,
		"lanes": out_lanes, "nodes": out_nodes, "edges": out_edges, "rule": rule.duplicate(true),
	}


## Rebuilds a graph from [method to_dict] output. Null (warning) when the dictionary is not a schema-2 graph, has no
## nodes, or an edge names an unknown node (an unknown edge is DROPPED, not fatal; the validator decides reachability).
static func from_dict(d: Variant) -> MapGraph:
	if typeof(d) != TYPE_DICTIONARY:
		return null
	var src: Dictionary = d as Dictionary
	if int(src.get("schema", 0)) != SCHEMA:
		push_warning("MapGraph: schema %s is not %d" % [str(src.get("schema", "?")), SCHEMA])
		return null
	var g := MapGraph.new()
	g.source = SOURCE_V1 if str(src.get("source", SOURCE_V2)) == SOURCE_V1 else SOURCE_V2
	g.region_id = str(src.get("region_id", ""))
	g.floor = maxi(int(src.get("floor", 0)), 0)
	g.seed = int(src.get("seed", 0))
	g.depths = maxi(int(src.get("depths", 0)), 0)
	var raw_lanes: Variant = src.get("lanes", [])
	if typeof(raw_lanes) == TYPE_ARRAY:
		for l: Variant in raw_lanes as Array:
			if typeof(l) == TYPE_DICTIONARY:
				g.lanes.append({"id": str((l as Dictionary).get("id", "")), "archetype": str((l as Dictionary).get("archetype", "")),
					"order": int((l as Dictionary).get("order", g.lanes.size()))})
	var raw_nodes: Variant = src.get("nodes", {})
	if typeof(raw_nodes) == TYPE_DICTIONARY:
		for id: Variant in (raw_nodes as Dictionary).keys():
			var rec: Variant = (raw_nodes as Dictionary)[id]
			if typeof(rec) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = (rec as Dictionary).duplicate(true)
			record["id"] = str(id)
			g.add_node(record)
	if g.nodes.is_empty():
		push_warning("MapGraph: no nodes")
		return null
	var raw_edges: Variant = src.get("edges", [])
	if typeof(raw_edges) == TYPE_ARRAY:
		for e: Variant in raw_edges as Array:
			if typeof(e) == TYPE_ARRAY and (e as Array).size() == 2:
				g.add_edge(str((e as Array)[0]), str((e as Array)[1]))
	if typeof(src.get("rule")) == TYPE_DICTIONARY:
		g.rule = clean_rule_state(src["rule"] as Dictionary)
	if g.depths <= 0:
		for id: String in g.nodes:
			g.depths = maxi(g.depths, int((g.nodes[id] as Dictionary)["depth"]) + 1)
	return g


## Region-rule state as saved: {id: String, gauge: int} (other keys dropped; JSON floats become ints).
static func clean_rule_state(raw: Dictionary) -> Dictionary:
	if raw.is_empty():
		return {}
	return {"id": str(raw.get("id", "")), "gauge": int(raw.get("gauge", 0))}


## A node record with every field present and typed (unknown kind kept as written: the validator reports it).
static func clean_node(raw: Dictionary) -> Dictionary:
	var mods: Array[String] = []
	var raw_mods: Variant = raw.get("modifiers", [])
	if typeof(raw_mods) == TYPE_ARRAY:
		for m: Variant in raw_mods as Array:
			if not mods.has(str(m)):
				mods.append(str(m))
	var tags: Array[String] = []
	var raw_tags: Variant = raw.get("tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for t: Variant in raw_tags as Array:
			if not tags.has(str(t)):
				tags.append(str(t))
	var out: Dictionary = {
		"id": str(raw.get("id", "")), "depth": maxi(int(raw.get("depth", 0)), 0), "lane": str(raw.get("lane", "")),
		"slot": str(raw.get("slot", SLOT_LANE)), "kind": str(raw.get("kind", "")), "match_id": str(raw.get("match_id", "")),
		"reward_tier": clampi(int(raw.get("reward_tier", 1)), 1, 3), "modifiers": mods,
		"objective": str(raw.get("objective", "")), "tags": tags,
	}
	# Optional: the v1 column tier (wrapped maps) — kept so GameFlow's event fights read the same tier as before; the
	# pool tier of a v2 fight node is stored the same way.
	if raw.has("tier"):
		out["tier"] = int(raw["tier"])
	# Optional slot economics (03 section 3): gold multiplier of the node's drop, relic rows it offers on top of its kind.
	if raw.has("gold_mult"):
		out["gold_mult"] = maxf(float(raw["gold_mult"]), 0.0)
	if raw.has("relic_offer"):
		out["relic_offer"] = maxi(int(raw["relic_offer"]), 0)
	return out


## Wraps a v1 column map (ChapterMapGen.generate output: [{index, tier, nodes: [{kind, match_id, next?}]}]) as a graph:
## node id "c<column>n<index>", depth = column, slot "entry" for the single first-column node, "warden" for the single
## last-column node, else "v1"; `next` becomes edges (a node without `next` — a map from before the links — links to every
## node of the next column, the rule RunSession.linked_indices applies). Tag "v1" on every node, tier kept in "tier".
static func from_v1_columns(map: Array, p_region_id: String, p_floor: int, p_seed: int) -> MapGraph:
	var g := MapGraph.new()
	g.source = SOURCE_V1
	g.region_id = p_region_id
	g.floor = maxi(p_floor, 0)
	g.seed = p_seed
	g.depths = map.size()
	for ci: int in map.size():
		var col: Dictionary = map[ci] if typeof(map[ci]) == TYPE_DICTIONARY else {}
		var col_nodes: Array = col.get("nodes", []) if typeof(col.get("nodes")) == TYPE_ARRAY else []
		for ni: int in col_nodes.size():
			var n: Dictionary = col_nodes[ni] if typeof(col_nodes[ni]) == TYPE_DICTIONARY else {}
			var slot: String = SLOT_V1
			if ci == 0 and col_nodes.size() == 1:
				slot = SLOT_ENTRY
			elif ci == map.size() - 1 and col_nodes.size() == 1 and str(n.get("kind", "")) == "boss":
				slot = SLOT_WARDEN
			g.add_node({"id": v1_node_id(ci, ni), "depth": ci, "lane": "", "slot": slot, "kind": str(n.get("kind", "")),
				"match_id": str(n.get("match_id", "")), "reward_tier": 1, "modifiers": [], "objective": "", "tags": [TAG_V1]})
			g.nodes[v1_node_id(ci, ni)]["tier"] = int(col.get("tier", 0))
	for ci: int in map.size() - 1:
		var col: Dictionary = map[ci] if typeof(map[ci]) == TYPE_DICTIONARY else {}
		var col_nodes: Array = col.get("nodes", []) if typeof(col.get("nodes")) == TYPE_ARRAY else []
		var next_col: Dictionary = map[ci + 1] if typeof(map[ci + 1]) == TYPE_DICTIONARY else {}
		var next_count: int = (next_col.get("nodes", []) as Array).size() if typeof(next_col.get("nodes")) == TYPE_ARRAY else 0
		for ni: int in col_nodes.size():
			var n: Dictionary = col_nodes[ni] if typeof(col_nodes[ni]) == TYPE_DICTIONARY else {}
			var links: Variant = n.get("next")
			if typeof(links) == TYPE_ARRAY:
				for v: Variant in links as Array:
					var to: int = int(v)
					if to >= 0 and to < next_count:
						g.add_edge(v1_node_id(ci, ni), v1_node_id(ci + 1, to))
			else:
				for to: int in next_count:
					g.add_edge(v1_node_id(ci, ni), v1_node_id(ci + 1, to))
	return g


## The wrapped id of v1 node (column, index): "c<column>n<index>".
static func v1_node_id(column: int, index: int) -> String:
	return "c%dn%d" % [column, index]


## (column, index) of a wrapped v1 id, or Vector2i(-1, -1) when the id is not of that form.
static func v1_position(id: String) -> Vector2i:
	if not id.begins_with("c") or not id.contains("n"):
		return Vector2i(-1, -1)
	var parts: PackedStringArray = id.substr(1).split("n")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


func _build_cache() -> void:
	if _cache_ok:
		return
	_out = {}
	_in = {}
	for e: Variant in edges:
		var a: String = str((e as Array)[0])
		var b: String = str((e as Array)[1])
		if not _out.has(a):
			_out[a] = [] as Array[String]
		(_out[a] as Array).append(b)
		if not _in.has(b):
			_in[b] = [] as Array[String]
		(_in[b] as Array).append(a)
	var order: Array[String] = node_ids()
	for key: Variant in _out.keys():
		(_out[key] as Array).sort_custom(func(x: String, y: String) -> bool: return order.find(x) < order.find(y))
	for key: Variant in _in.keys():
		(_in[key] as Array).sort_custom(func(x: String, y: String) -> bool: return order.find(x) < order.find(y))
	_cache_ok = true

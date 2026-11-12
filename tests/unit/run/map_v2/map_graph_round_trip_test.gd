extends SceneTree
## World Map v2 U1: MapGraph builds, serialises and reads back without loss; edge caches answer in screen order; unknown
## ids and bad dictionaries are refused; v1 ids round-trip through v1_node_id / v1_position.
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/map_graph_round_trip_test.gd

var fails: int = 0


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _small_graph() -> MapGraph:
	var g := MapGraph.new()
	g.region_id = "hellfire"
	g.floor = 1
	g.seed = 42
	g.depths = 3
	g.lanes = [{"id": "L0", "archetype": "safe", "order": 0}, {"id": "L1", "archetype": "peril", "order": 1}]
	g.add_node({"id": "n0", "depth": 0, "slot": "entry", "kind": "battle", "match_id": "imp"})
	g.add_node({"id": "b", "depth": 1, "lane": "L1", "slot": "lane", "kind": "danger", "match_id": "ash_golem", "reward_tier": 2, "modifiers": ["big_hands", "big_hands"], "objective": "no_hit_3", "tags": ["x"]})
	g.add_node({"id": "a", "depth": 1, "lane": "L0", "slot": "lane", "kind": "battle", "match_id": "imp"})
	g.add_node({"id": "w", "depth": 2, "slot": "warden", "kind": "boss", "match_id": "inferno_lord"})
	g.add_edge("n0", "b")
	g.add_edge("n0", "a")
	g.add_edge("a", "w")
	g.add_edge("b", "w")
	g.rule = {"id": "heat", "gauge": 2}
	return g


func _initialize() -> void:
	var g: MapGraph = _small_graph()
	check(g.nodes.size() == 4 and g.edges.size() == 4, "4 nodes, 4 edges")
	check(not g.add_node({"id": "a", "depth": 1}), "duplicate id refused")
	check(not g.add_node({"depth": 1}), "empty id refused")
	check(not g.add_edge("a", "zzz"), "edge to an unknown node refused")
	check(not g.add_edge("n0", "a"), "duplicate edge refused")
	check(g.node_ids() == (["n0", "a", "b", "w"] as Array[String]), "node ids sorted by depth then lane order: %s" % str(g.node_ids()))
	check(g.out_edges("n0") == (["a", "b"] as Array[String]), "out-edges in screen order: %s" % str(g.out_edges("n0")))
	check(g.in_edges("w") == (["a", "b"] as Array[String]), "in-edges in screen order")
	check(g.out_edges("zzz").is_empty() and g.in_edges("zzz").is_empty(), "unknown id has no edges")
	check(g.entry_id() == "n0" and g.warden_id() == "w", "entry and warden found")
	check(g.node("b")["modifiers"] == (["big_hands"] as Array[String]), "modifiers deduped on add")
	check(g.node("zzz").is_empty(), "unknown node -> {}")
	check(g.archetype_of("b") == "peril" and g.archetype_of("n0") == "", "archetype of a lane node / none for the entry")
	check(g.reachable_from("n0") == (["a", "b", "w"] as Array[String]), "reachable set from the entry")
	check(g.can_reach("a", "w") and not g.can_reach("a", "b"), "can_reach follows edges only")

	var d: Dictionary = g.to_dict()
	var back: MapGraph = MapGraph.from_dict(d)
	check(back != null and back.to_dict() == d, "to_dict / from_dict round trip is byte-equal")
	check(back.rule == {"id": "heat", "gauge": 2}, "rule state kept")
	check(back.out_edges("n0") == g.out_edges("n0"), "edge cache rebuilt after load")
	var text: String = JSON.stringify(d)
	var parsed: Variant = JSON.parse_string(text)
	var back2: MapGraph = MapGraph.from_dict(parsed)
	check(back2 != null and back2.to_dict() == d, "survives a JSON string round trip (ints stay ints)")

	check(MapGraph.from_dict({"schema": 1, "nodes": {}}) == null, "wrong schema -> null")
	check(MapGraph.from_dict({"schema": 2, "nodes": {}}) == null, "no nodes -> null")
	check(MapGraph.from_dict("nope") == null, "non-dictionary -> null")
	var bad_edge: Dictionary = d.duplicate(true)
	(bad_edge["edges"] as Array).append(["n0", "ghost"])
	var back3: MapGraph = MapGraph.from_dict(bad_edge)
	check(back3 != null and back3.edges.size() == 4, "an edge to an unknown node is dropped on load, the graph survives")

	check(MapGraph.v1_node_id(3, 2) == "c3n2" and MapGraph.v1_position("c3n2") == Vector2i(3, 2), "v1 id <-> (column, index)")
	check(MapGraph.v1_position("hub") == Vector2i(-1, -1) and MapGraph.v1_position("c1x") == Vector2i(-1, -1), "non-v1 ids give (-1, -1)")

	var cleaned: Dictionary = MapGraph.clean_node({"id": "q", "reward_tier": 9, "depth": -3})
	check(int(cleaned["reward_tier"]) == 3 and int(cleaned["depth"]) == 0 and cleaned["slot"] == "lane", "clean_node clamps tier and depth, defaults the slot")
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

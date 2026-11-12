extends SceneTree
## World Map v2 U4: MapValidator accepts a legal v2 layout graph and reports each error class once it is broken: dead
## end, orphan, unreachable warden, bad edge direction, unknown kind, fight without a match, match outside its pool,
## kind illegal on the floor, duplicate archetype, missing hub, cross-lane edge, depth layout mismatch.
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/map_validator_test.gd

var fails: int = 0


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


# The approved layout by hand: entry, 3 lanes x (d1, d2), hub, 3 x d4, prepare + gamble, warden (14 nodes, 20 edges).
func _legal() -> MapGraph:
	var g := MapGraph.new()
	g.region_id = "hellfire"
	g.floor = 1
	g.depths = 7
	g.lanes = [{"id": "L0", "archetype": "peril", "order": 0}, {"id": "L1", "archetype": "safe", "order": 1}, {"id": "L2", "archetype": "treasure", "order": 2}]
	g.add_node({"id": "n0", "depth": 0, "slot": "entry", "kind": "battle", "match_id": "imp"})
	var fights: Dictionary = {"L0": ["ash_golem", "flame_cultist", "magma_slug"], "L1": ["ember_hound", "imp", ""], "L2": ["ember_hound", "", "hell_knight"]}
	var kinds: Dictionary = {"L0": ["danger", "danger", "danger"], "L1": ["battle", "battle", "rest"], "L2": ["battle", "treasure", "battle"]}
	for lane: String in ["L0", "L1", "L2"]:
		for i: int in 3:
			var depth: int = [1, 2, 4][i]
			g.add_node({"id": "%s.%d" % [lane, depth], "depth": depth, "lane": lane, "slot": "lane", "kind": kinds[lane][i], "match_id": fights[lane][i]})
	g.add_node({"id": "hub", "depth": 3, "slot": "hub", "kind": "shop"})
	g.add_node({"id": "a1", "depth": 5, "slot": "prepare", "kind": "rest"})
	g.add_node({"id": "a2", "depth": 5, "slot": "gamble", "kind": "miniboss", "match_id": "fire_eater"})
	g.add_node({"id": "w", "depth": 6, "slot": "warden", "kind": "boss", "match_id": "inferno_lord"})
	for lane: String in ["L0", "L1", "L2"]:
		g.add_edge("n0", "%s.1" % lane)
		g.add_edge("%s.1" % lane, "%s.2" % lane)
		g.add_edge("%s.2" % lane, "hub")
		g.add_edge("hub", "%s.4" % lane)
		g.add_edge("%s.4" % lane, "a1")
		g.add_edge("%s.4" % lane, "a2")
	g.add_edge("a1", "w")
	g.add_edge("a2", "w")
	return g


func _spec() -> Dictionary:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var spec: Dictionary = cfg.region_spec("hellfire", 1)
	spec["kind_floors"] = {"danger": {"min_floor": 2}, "miniboss": {"min_floor": 2}, "event": {"max_floor": 0}}
	return spec


func _has(errors: Array[String], prefix: String) -> bool:
	for e: String in errors:
		if e.begins_with(prefix + ":"):
			return true
	return false


func _initialize() -> void:
	var g: MapGraph = _legal()
	var res: Dictionary = MapValidator.validate(g, _spec())
	check(bool(res["ok"]), "the hand-built layout is legal: %s" % str(res["errors"]))
	check(g.nodes.size() == 14 and g.edges.size() == 20, "14 nodes, 20 edges")
	var m: Dictionary = MapValidator.metrics(g)
	check(int(m["paths_to_warden"]) == 18 and m["archetypes"] == "peril+safe+treasure" and int(m["lane_repeats"]) == 0, "metrics: 18 paths (3 lanes x 3 lanes x 2 approach), archetype triple, no lane repeat: %s" % str(m))

	var g2: MapGraph = _legal()
	g2.edges.erase(["a1", "w"])
	g2._cache_ok = false
	var r2: Array[String] = MapValidator.validate(g2)["errors"]
	check(_has(r2, "dead_end") and _has(r2, "reach"), "prepare without a way out: dead end + warden unreachable from it")

	var g3: MapGraph = _legal()
	g3.edges.erase(["n0", "L2.1"])
	g3._cache_ok = false
	var r3: Array[String] = MapValidator.validate(g3)["errors"]
	check(_has(r3, "orphan") and _has(r3, "reach"), "lane start without a way in: orphan + unreachable from the entry")

	var g4: MapGraph = _legal()
	g4.edges.append(["w", "a1"])
	g4._cache_ok = false
	check(_has(MapValidator.validate(g4)["errors"], "edge"), "an edge to a lower depth is reported")

	var g5: MapGraph = _legal()
	g5.nodes["L1.2"]["kind"] = "tavern"
	check(_has(MapValidator.validate(g5)["errors"], "kind"), "unknown kind reported")

	var g6: MapGraph = _legal()
	g6.nodes["L1.1"]["match_id"] = ""
	check(_has(MapValidator.validate(g6)["errors"], "match"), "fight without a match id reported")

	var g7: MapGraph = _legal()
	g7.nodes["L1.1"]["match_id"] = "goblin_scout"
	check(_has(MapValidator.validate(g7, _spec())["errors"], "pool"), "match outside the region's pool reported")

	var g8: MapGraph = _legal()
	var spec8: Dictionary = _spec()
	spec8["floor_number"] = 1
	check(_has(MapValidator.validate(g8, spec8)["errors"], "floor_rule"), "danger on floor 1 reported through kind_floors")

	var g9: MapGraph = _legal()
	g9.lanes[1]["archetype"] = "peril"
	check(_has(MapValidator.validate(g9)["errors"], "archetype"), "duplicate archetype reported")
	var g9b: MapGraph = _legal()
	g9b.lanes[1]["archetype"] = "elite"
	g9b.lanes[2]["archetype"] = "mystery"
	check(_has(MapValidator.validate(g9b)["errors"], "archetype"), "three hostile lanes (no safe / treasure) reported")

	var g10: MapGraph = _legal()
	g10.nodes["hub"]["slot"] = "lane"
	check(_has(MapValidator.validate(g10)["errors"], "slot"), "missing hub slot reported")

	var g11: MapGraph = _legal()
	g11.edges.append(["L0.1", "L1.2"])
	g11._cache_ok = false
	check(_has(MapValidator.validate(g11)["errors"], "lane"), "a cross-lane edge outside the hub is reported")

	var g12: MapGraph = _legal()
	g12.nodes["a2"]["depth"] = 4
	g12.nodes["a2"]["slot"] = "gamble"
	check(_has(MapValidator.validate(g12)["errors"], "layout"), "depth layout mismatch reported")

	check(not bool(MapValidator.validate(null)["ok"]) and not bool(MapValidator.validate(MapGraph.new())["ok"]), "null / empty graph is not ok")
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

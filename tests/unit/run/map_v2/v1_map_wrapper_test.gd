extends SceneTree
## World Map v2 U5: every v1 column map of the 7 assigned (region, floor) pairs over 200 run seeds wraps into a MapGraph
## that the validator accepts (structural rules + pools); the wrap keeps every node, every `next` link and the column
## tiers; it round-trips through to_dict / from_dict; a map without `next` (an old save) links every node to the whole
## next column; the final map (shop column + keeper) wraps too; v1 behaviour itself is untouched (the wrap reads the
## column map, it never writes it).
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/v1_map_wrapper_test.gd

const SEEDS: int = 200
const PAIRS: Array = [["ch1", 0], ["hellfire", 1], ["desert", 2], ["swamp", 3], ["ch2", 4], ["ch3", 5], ["sky_isles", 6]]

var fails: int = 0


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var bad: Array[String] = []
	var maps: int = 0
	var round_trip_ok: bool = true
	var link_count_ok: bool = true
	var tier_ok: bool = true
	for pair: Array in PAIRS:
		var region: String = str(pair[0])
		var floor: int = int(pair[1])
		var spec: Dictionary = cfg.region_spec(region, floor)
		for s: int in SEEDS:
			var columns: Array[Dictionary] = cfg.generate_region_map(region, s + 1, floor, 1)
			var before: String = JSON.stringify(columns)
			var g: MapGraph = MapGraph.from_v1_columns(columns, region, floor, s + 1)
			maps += 1
			if JSON.stringify(columns) != before:
				bad.append("%s f%d s%d: the wrap modified the column map" % [region, floor, s + 1])
			var res: Dictionary = MapValidator.validate(g, spec)
			if not bool(res["ok"]):
				bad.append("%s f%d s%d: %s" % [region, floor, s + 1, str(res["errors"]).left(200)])
			var links: int = 0
			var nodes: int = 0
			for ci: int in columns.size():
				for ni: int in (columns[ci]["nodes"] as Array).size():
					nodes += 1
					var n: Dictionary = columns[ci]["nodes"][ni]
					links += (n.get("next", []) as Array).size()
					var id: String = MapGraph.v1_node_id(ci, ni)
					if not g.has_node(id) or g.nodes[id]["kind"] != n["kind"] or g.nodes[id]["match_id"] != n["match_id"]:
						bad.append("%s f%d s%d: node %s not wrapped faithfully" % [region, floor, s + 1, id])
					if int(g.nodes[id].get("tier", -1)) != int(columns[ci]["tier"]):
						tier_ok = false
			if g.nodes.size() != nodes or g.edges.size() != links:
				link_count_ok = false
			if g.is_v1() == false or g.entry_id() != "c0n0" or g.warden_id() != MapGraph.v1_node_id(columns.size() - 1, 0):
				bad.append("%s f%d s%d: entry / warden / source wrong" % [region, floor, s + 1])
			var d: Dictionary = g.to_dict()
			var back: MapGraph = MapGraph.from_dict(d)
			if back == null or back.to_dict() != d or not back.is_v1():
				round_trip_ok = false
	check(bad.is_empty(), "%d wrapped v1 maps valid (assigned pairs x %d seeds); first problems: %s" % [maps, SEEDS, str(bad.slice(0, 3))])
	check(link_count_ok, "node and edge counts equal the column map's nodes and `next` links")
	check(tier_ok, "column tiers kept on the wrapped nodes")
	check(round_trip_ok, "every wrapped map round-trips through to_dict / from_dict as v1")

	# A map saved before the links existed: no `next` -> every node of the next column is open (RunSession.linked_indices).
	var old: Array = [{"index": 0, "tier": 0, "nodes": [{"kind": "battle", "match_id": "imp"}]},
		{"index": 1, "tier": 1, "nodes": [{"kind": "battle", "match_id": "ember_hound"}, {"kind": "treasure", "match_id": ""}]},
		{"index": 2, "tier": 1, "nodes": [{"kind": "boss", "match_id": "inferno_lord"}]}]
	var g_old: MapGraph = MapGraph.from_v1_columns(old, "hellfire", 1, 7)
	check(g_old.edges.size() == 4 and g_old.out_edges("c0n0") == (["c1n0", "c1n1"] as Array[String]), "no `next` -> all-to-all links between columns")
	check(bool(MapValidator.validate(g_old)["ok"]), "the old-style wrapped map is valid")

	var final_map: Array[Dictionary] = cfg.final_map()
	var g_final: MapGraph = MapGraph.from_v1_columns(final_map, "an_dai", cfg.world_floors(), 1)
	var res_final: Dictionary = MapValidator.validate(g_final)
	check(bool(res_final["ok"]) and g_final.warden_id() == MapGraph.v1_node_id(final_map.size() - 1, 0), "the final map (prelude shop + keeper) wraps and validates: %s" % str(res_final["errors"]))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## 2026-11-03 (design/quick-specs/osfe-floor-length-2026-11-03.md): a floor is 7 columns linked OSFE's way.
## Every region at every floor, over several run seeds: 7 columns; columns 1 and 4 hold 3 nodes, column 4 a rest, the
## last the warden; every node before the last column links on (valid, ascending, distinct indices) and every node after
## the first is linked into. RunSession offers only the nodes linked from the node cleared before (choose_node refuses
## the others), a map without links (an old save) keeps every node open, and to_dict / from_dict keeps the links.
## Run: godot --headless --path . -s res://tests/unit/run/map_links_test.gd

const SEEDS: Array[int] = [1, 7, 42, 1234, 99991]

var fails: int = 0
var config: ChaptersConfig


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	config = ChaptersConfig.load_from_file()
	test_every_floor_has_the_osfe_frame_and_full_links()
	test_links_are_seeded()
	test_session_offers_only_linked_nodes()
	test_old_map_without_links_keeps_every_node_open()
	test_save_round_trip_keeps_the_links()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_every_floor_has_the_osfe_frame_and_full_links() -> void:
	var shape_ok: bool = true
	var links_ok: bool = true
	var bad: Array[String] = []
	for region: String in config.region_ids():
		for floor: int in config.world_floors():
			for run_seed: int in SEEDS:
				var map: Array[Dictionary] = config.generate_region_map(region, run_seed, floor, 3)
				var where: String = "%s f%d s%d" % [region, floor, run_seed]
				if map.size() != 7:
					shape_ok = false
					bad.append(where + " columns %d" % map.size())
					continue
				var sizes: Array[int] = []
				for column: Dictionary in map:
					sizes.append((column["nodes"] as Array).size())
				var kinds4: Array[String] = []
				for node: Variant in map[4]["nodes"]:
					kinds4.append(str((node as Dictionary)["kind"]))
				var last: Array = map[6]["nodes"]
				if sizes[0] != 1 or sizes[1] != 3 or sizes[4] != 3 or not kinds4.has("rest") or last.size() != 1 or str((last[0] as Dictionary)["kind"]) != "boss":
					shape_ok = false
					bad.append(where + " sizes %s col4 %s" % [str(sizes), str(kinds4)])
				for ci: int in map.size():
					var nodes: Array = map[ci]["nodes"]
					var linked_in: Array[int] = []
					if ci > 0:
						for prev: Variant in map[ci - 1]["nodes"]:
							for i: Variant in (prev as Dictionary)["next"]:
								linked_in.append(int(i))
					for ni: int in nodes.size():
						var next: Array = (nodes[ni] as Dictionary).get("next", [])
						if ci < map.size() - 1:
							var next_count: int = (map[ci + 1]["nodes"] as Array).size()
							var sorted: Array = next.duplicate()
							sorted.sort()
							var valid: bool = not next.is_empty() and sorted == next
							for i: Variant in next:
								valid = valid and int(i) >= 0 and int(i) < next_count and next.count(i) == 1
							if not valid:
								links_ok = false
								bad.append(where + " c%d n%d next %s" % [ci, ni, str(next)])
						elif not next.is_empty():
							links_ok = false
							bad.append(where + " warden links on")
						if ci > 0 and not linked_in.has(ni):
							links_ok = false
							bad.append(where + " c%d n%d has no way in" % [ci, ni])
	_check("test_every_floor_has_7_columns_3_3_rest_and_warden", shape_ok, str(bad.slice(0, 4)))
	_check("test_every_node_links_on_and_is_linked_into", links_ok, str(bad.slice(0, 4)))


func test_links_are_seeded() -> void:
	var region: String = config.region_ids()[0]
	var a: Array[Dictionary] = config.generate_region_map(region, 42, 1, 3)
	var b: Array[Dictionary] = config.generate_region_map(region, 42, 1, 3)
	_check("test_same_seed_same_links", a == b)


func _session_with(map: Array[Dictionary]) -> RunSession:
	var run := RunSession.new()
	run.map = map
	run.column = 0
	return run


func _three_columns(with_links: bool) -> Array[Dictionary]:
	var map: Array[Dictionary] = [
		{"index": 0, "tier": 0, "nodes": [{"kind": "battle", "match_id": "a", "next": [1]}]},
		{"index": 1, "tier": 1, "nodes": [{"kind": "battle", "match_id": "b", "next": [0]}, {"kind": "danger", "match_id": "c", "next": [0]},
			{"kind": "battle", "match_id": "d", "next": [0]}]},
		{"index": 2, "tier": 2, "nodes": [{"kind": "boss", "match_id": "e", "next": []}]},
	]
	if not with_links:
		for column: Dictionary in map:
			for node: Variant in column["nodes"]:
				(node as Dictionary).erase("next")
	return map


func test_session_offers_only_linked_nodes() -> void:
	var run: RunSession = _session_with(_three_columns(true))
	_check("test_first_column_open", run.available_nodes().size() == 1 and run.choose_node(0))
	run.complete_node(100.0, 100.0, "", {}, 0.0)
	var open: Array[int] = []
	for node: Dictionary in run.available_nodes():
		open.append(int(node["node_index"]))
	_check("test_only_the_linked_node_is_open", open == ([1] as Array[int]), str(open))
	_check("test_choose_an_unlinked_node_refused", not run.choose_node(0) and not run.choose_node(2))
	_check("test_choose_the_linked_node_accepted", run.choose_node(1))


func test_old_map_without_links_keeps_every_node_open() -> void:
	var run: RunSession = _session_with(_three_columns(false))
	run.choose_node(0)
	run.complete_node(100.0, 100.0, "", {}, 0.0)
	_check("test_old_map_every_node_open", run.available_nodes().size() == 3 and run.linked_indices() == ([0, 1, 2] as Array[int]))


func test_save_round_trip_keeps_the_links() -> void:
	var region: String = config.region_ids()[0]
	var map: Array[Dictionary] = config.generate_region_map(region, 7, 0, 3)
	var cleaned: Array[Dictionary] = RunSession._clean_map(JSON.parse_string(JSON.stringify(map)))
	var same: bool = cleaned.size() == map.size()
	for ci: int in mini(cleaned.size(), map.size()):
		for ni: int in (map[ci]["nodes"] as Array).size():
			var want: Array = ((map[ci]["nodes"] as Array)[ni] as Dictionary)["next"]
			var got: Variant = ((cleaned[ci]["nodes"] as Array)[ni] as Dictionary).get("next")
			same = same and typeof(got) == TYPE_ARRAY and (got as Array) == want
	_check("test_saved_map_keeps_next_links", same)

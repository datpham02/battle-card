extends SceneTree
## 2026-11-04 (user: "bớt ô nguy hiểm ... làm theo đề xuất"): the first floor teaches before it tests. On floor 1 the
## first two fight columns after the opening battle (region columns 1 and 2) hold no `danger` node (danger has
## min_floor 2 there), and floor 1 always has a shop (world.special_nodes.first_floor_shop) on top of the
## guaranteed shops drawn among floors 2..5. Floors 2+ keep danger in those columns.
## 2026-11-04 (user: "làm 2 ý", OSFE WorldBar layout): column 2 always holds a Treasure (OSFE: its 2nd node), and on
## floor 1 column 3 (no elite before floor 2) holds an Event instead, so every column 2..5 has a non-fight node.
## Run: godot --headless --path . -s res://tests/unit/run/first_floor_map_test.gd

const SEEDS: int = 300

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var special: Dictionary = cfg.special_nodes()
	var danger_f1: int = 0
	var danger_f2: int = 0
	var shop_f1: int = 0
	var plan_ok: bool = true
	for s: int in SEEDS:
		var plan: Array[int] = cfg.shop_floors(s)
		plan_ok = plan_ok and plan.has(0) and plan.size() == int(special["guaranteed_shops"]) + 1
		for floor: int in [0, 1]:
			var map: Array[Dictionary] = cfg.generate_region_map("ch1", s, floor, 1)
			for c: int in [1, 2]:
				for node: Dictionary in map[c]["nodes"]:
					if str(node["kind"]) == "danger":
						if floor == 0:
							danger_f1 += 1
						else:
							danger_f2 += 1
			if floor == 0:
				for col: Dictionary in map:
					for node: Dictionary in col["nodes"]:
						if str(node["kind"]) == "shop":
							shop_f1 += 1
	var treasure_ok: bool = true
	var event_f1: int = 0
	var elite_f1: int = 0
	var event_f2: int = 0
	var elite_f2: int = 0
	for s: int in SEEDS:
		for floor: int in [0, 1]:
			var map: Array[Dictionary] = cfg.generate_region_map("ch1", s, floor, 1)
			var kinds2: Array = (map[2]["nodes"] as Array).map(func(n: Dictionary) -> String: return str(n["kind"]))
			treasure_ok = treasure_ok and kinds2.has("treasure")
			for node: Dictionary in map[3]["nodes"]:
				var k: String = str(node["kind"])
				if floor == 0:
					event_f1 += 1 if k == "event" else 0
					elite_f1 += 1 if k == "miniboss" else 0
				else:
					event_f2 += 1 if k == "event" else 0
					elite_f2 += 1 if k == "miniboss" else 0
	_check("test_column2_always_has_a_treasure", treasure_ok)
	_check("test_floor1_column3_one_event_no_elite", event_f1 == SEEDS and elite_f1 == 0, "events=%d elites=%d" % [event_f1, elite_f1])
	_check("test_floor2_column3_elite_no_event", elite_f2 == SEEDS and event_f2 == 0, "events=%d elites=%d" % [event_f2, elite_f2])
	_check("test_floor1_columns_1_2_have_no_danger", danger_f1 == 0, "danger=%d" % danger_f1)
	_check("test_floor2_columns_1_2_still_have_danger", danger_f2 > 0, "danger=%d" % danger_f2)
	_check("test_first_floor_shop_flag_on", bool(special.get("first_floor_shop", false)))
	_check("test_shop_plan_has_floor1_plus_the_guaranteed", plan_ok)
	_check("test_every_floor1_map_has_a_shop", shop_f1 == SEEDS, "shops=%d of %d" % [shop_f1, SEEDS])
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

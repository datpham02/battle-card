extends SceneTree
## World Map v2 U18-U20, U25-U28: RunSession on a v2 region (hellfire, floor 2 of the climb): the graph is the truth
## and the column mirror follows it; node-id progression (available by edges, choose by id, cleared ids, warden by
## slot); the Heat gauge steps per completed kind, clamps and resets on entering a region; save v8 round-trips at
## every exit point; v5-v7 saves restart; invalid v8 data is dropped or clamped as specified; a run that crosses v1
## (floor 1) -> v2 (floor 2) -> v1 (floor 3) keeps one API and survives save/load between each step.
## Run: godot --headless --path . -s res://tests/unit/run/map_v2/run_session_v2_test.gd

const SEED: int = 2002

var fails: int = 0
var chapters: ChaptersConfig
var hero: Dictionary


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _run_at_hellfire() -> RunSession:
	var s: RunSession = RunSession.begin_world(chapters, hero, SEED, 1)
	# Floor 1 = ch1 (v1): walk it to the warden through the column rule, then enter hellfire (floor 2).
	check(s.choose_region("ch1", 1), "setup: enter ch1")
	_walk_to_boss(s)
	check(s.floor == 1 and s.region_offer == (["hellfire"] as Array[String]), "setup: floor 2 offers hellfire (%s)" % str(s.region_offer))
	check(s.choose_region("hellfire", 1), "setup: enter hellfire")
	return s


# Clears nodes along the first available node until the boss is cleared (v1 or v2 map).
func _walk_to_boss(s: RunSession) -> void:
	for _i: int in 20:
		var avail: Array[Dictionary] = s.available_nodes()
		if avail.is_empty():
			break
		var pick: Dictionary = avail[0]
		for n: Dictionary in avail:
			if n["kind"] == "boss":
				pick = n
		s.choose_node(int(pick["node_index"]))
		var kind: String = str(pick["kind"])
		var r: Dictionary = s.complete_node(100.0, 300.0, kind, {})
		if kind == "boss":
			break


func _round_trip(s: RunSession, label: String) -> RunSession:
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var back: RunSession = RunSession.from_dict(d, chapters)
	var same: bool = back != null and back.to_dict() == JSON.parse_string(JSON.stringify(s.to_dict()))
	if back != null and not same:
		# Float / int differences in JSON are expected; compare the fields that matter instead.
		same = back.column == s.column and back.node_index == s.node_index and back.cleared_ids() == s.cleared_ids() \
			and back.rule_state == s.rule_state and back.objectives_met == s.objectives_met and back.region_id == s.region_id \
			and back.floor == s.floor and back.graph != null and back.graph.to_dict() == s.graph.to_dict() and back.map == s.map
	check(same, "U25 save v8 round trip: %s" % label)
	return back


func _initialize() -> void:
	chapters = ChaptersConfig.load_from_file()
	hero = CharacterConfig.load_from_file().get_character("kiem_si")
	_u18_u19_progression()
	_u26_old_saves()
	_u27_invalid()
	_u28_mixed()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _u18_u19_progression() -> void:
	var s: RunSession = _run_at_hellfire()
	check(s.is_v2_region() and s.graph != null and not s.graph.is_v1(), "U18 hellfire is a v2 region")
	check(s.map.size() == 7 and s.map == RunSession.columns_from_graph(s.graph), "U18 the column mirror equals columns_from_graph(graph)")
	check(s.rule_state == {"id": "heat", "gauge": 0} and s.gauge() == 0, "U19 rule state starts at heat 0")
	check(s.available_node_ids() == (["n0"] as Array[String]), "U18 only the entry is available at depth 0")
	check(not s.choose_node_id("L0.1"), "U18 a node of another depth cannot be chosen")
	check(s.choose_node_id("n0") and s.current_node_id() == "n0", "U18 choose by id")
	s.complete_node(250.0, 300.0, "battle", {})
	check(s.gauge() == 1, "U19 battle -> heat 1")
	check(s.cleared_ids() == (["n0"] as Array[String]), "U18 cleared ids")
	var lane_ids: Array[String] = s.available_node_ids()
	check(lane_ids == (["L0.1", "L1.1", "L2.1"] as Array[String]), "U18 all three lane starts available after the entry: %s" % str(lane_ids))
	var back1: RunSession = _round_trip(s, "at the fork")
	check(back1.available_node_ids() == lane_ids, "U25 availability identical after reload")
	# Commit to lane L1: after L1.1 only L1.2 is open (no lane switching before the hub).
	check(s.choose_node_id("L1.1"), "U18 choose L1.1")
	var k1: String = str(s.current_node().get("kind", ""))
	s.complete_node(240.0, 300.0, k1, {})
	check(s.available_node_ids() == (["L1.2"] as Array[String]), "U18 lane commitment: only L1.2 open after L1.1 (%s)" % str(s.available_node_ids()))
	check(not s.choose_node_id("L1.1") and not s.choose_node_id("L0.2"), "U18 a cleared node and another lane's node are refused")
	s.choose_node_id("L1.2")
	var k2: String = str(s.current_node().get("kind", ""))
	s.complete_node(230.0, 300.0, k2, {})
	check(s.available_node_ids() == (["hub"] as Array[String]), "U18 the hub follows depth 2")
	_round_trip(s, "before the hub")
	s.choose_node_id("hub")
	var hub_kind: String = str(s.current_node().get("kind", ""))
	var g_before_hub: int = s.gauge()
	s.complete_node(230.0, 300.0, hub_kind, {})
	var expected: int = RegionRules.gauge_after(s.current_rule(), g_before_hub, hub_kind)
	check(s.gauge() == expected, "U19 hub (%s) steps heat %d -> %d" % [hub_kind, g_before_hub, s.gauge()])
	check(s.available_node_ids() == (["L0.4", "L1.4", "L2.4"] as Array[String]), "U18 the hub opens every lane's last node")
	s.choose_node_id("L0.4")
	s.complete_node(220.0, 300.0, str(s.current_node().get("kind", "")), {})
	check(s.available_node_ids() == (["a1", "a2"] as Array[String]), "U18 the approach offers prepare and gamble")
	_round_trip(s, "at the approach")
	s.choose_node_id("a2")
	var gamble_kind: String = str(s.current_node().get("kind", ""))
	var g_before: int = s.gauge()
	s.complete_node(200.0, 300.0, gamble_kind, {})
	check(s.gauge() == RegionRules.gauge_after(s.current_rule(), g_before, gamble_kind), "U19 gamble (%s) steps heat by its kind" % gamble_kind)
	check(s.available_node_ids() == (["w"] as Array[String]), "U18 the warden follows the approach")
	s.record_objective_met("L0.4")
	s.record_objective_met("L0.4")
	check(s.objectives_met == (["L0.4"] as Array[String]), "U18 objective recorded once")
	var back_w: RunSession = _round_trip(s, "warden chosen")
	check(back_w.objectives_met == (["L0.4"] as Array[String]) and back_w.gauge() == s.gauge(), "U25 objectives and gauge survive the reload")
	s.choose_node_id("w")
	var r: Dictionary = s.complete_node(150.0, 300.0, "boss", {})
	check(bool(r["floor_cleared"]) and s.floor == 2 and s.region_offer == (["desert"] as Array[String]), "U18 the warden clears the floor; desert (v1) offered next")
	check(s.choose_region("desert", 1) and not s.is_v2_region() and s.rule_state.is_empty() and s.objectives_met.is_empty(), "U19 entering a v1 region resets the rule state and objectives")
	# Clamp: a hand-set gauge above the max clamps on the next step.
	var s2: RunSession = _run_at_hellfire()
	s2.rule_state["gauge"] = 4
	s2.choose_node_id("n0")
	s2.complete_node(250.0, 300.0, "battle", {})
	check(s2.gauge() == 4, "U19 heat clamps at 4")


func _u26_old_saves() -> void:
	var s: RunSession = _run_at_hellfire()
	for v: int in [5, 6, 7]:
		var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
		d["version"] = v
		var old: RunSession = RunSession.from_dict(d, chapters)
		check(old != null and old.needs_restart and old.restart_reason == RunSession.RESTART_OLD_SAVE and old.map.is_empty(), "U26 v%d save -> needs_restart with the old-save notice" % v)
		check(int(old.to_dict()["version"]) == 8 and bool(old.to_dict()["needs_restart"]), "U26 v%d re-saves as a v8 restart record" % v)
	var d4: Dictionary = {"version": 4, "character": "kiem_si", "chapter": "ch2", "map": []}
	var o4: RunSession = RunSession.from_dict(d4, chapters)
	check(o4 != null and o4.needs_restart, "U26 v4 save unchanged path (needs_restart)")
	check(RunSession.from_dict({"version": 8}, chapters) == null, "U26 a v8 record without a character is dropped")


func _u27_invalid() -> void:
	var s: RunSession = _run_at_hellfire()
	s.choose_node_id("n0")
	s.complete_node(250.0, 300.0, "battle", {})
	var base: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	# Edge to an unknown node: dropped on load, run survives.
	var d1: Dictionary = base.duplicate(true)
	(d1["map_graph"]["edges"] as Array).append(["n0", "ghost"])
	var r1: RunSession = RunSession.from_dict(d1, chapters)
	check(r1 != null and r1.graph.edges.size() == 20, "U27 an edge to an unknown node is dropped, the run loads")
	# Warden unreachable: the graph fails validation -> run dropped.
	var d2: Dictionary = base.duplicate(true)
	var edges2: Array = d2["map_graph"]["edges"]
	edges2.erase(["a1", "w"])
	edges2.erase(["a2", "w"])
	check(RunSession.from_dict(d2, chapters) == null, "U27 a saved graph whose warden is unreachable drops the run")
	# Gauge out of range -> clamped; unknown rule id -> rule state dropped.
	var d3: Dictionary = base.duplicate(true)
	d3["rule_state"] = {"id": "heat", "gauge": 99}
	check(RunSession.from_dict(d3, chapters).gauge() == 4, "U27 gauge above the max clamps to 4")
	var d4: Dictionary = base.duplicate(true)
	d4["rule_state"] = {"id": "ghost_rule", "gauge": 2}
	check(RunSession.from_dict(d4, chapters).rule_state.is_empty(), "U27 unknown rule id -> rule state dropped")
	# node_index out of range of the mirror -> dropped (existing rule, now exercised on a v2 map).
	var d5: Dictionary = base.duplicate(true)
	d5["node_index"] = 7
	check(RunSession.from_dict(d5, chapters) == null, "U27 node_index past the depth's nodes drops the run")
	# A v8 save of a v2 region whose `map` copy was tampered: the mirror is rebuilt from the graph.
	var d6: Dictionary = base.duplicate(true)
	d6["map"] = []
	var r6: RunSession = RunSession.from_dict(d6, chapters)
	check(r6 != null and r6.map.size() == 7 and r6.available_node_ids() == (["L0.1", "L1.1", "L2.1"] as Array[String]), "U27 the column mirror is rebuilt from the saved graph")
	var size: int = JSON.stringify(s.to_dict()).length()
	check(size < 32768, "U27 save size %d bytes < 32 KB" % size)


func _u28_mixed() -> void:
	var s: RunSession = RunSession.begin_world(chapters, hero, 77, 1)
	check(s.choose_region("ch1", 1) and not s.is_v2_region() and s.graph != null and s.graph.is_v1(), "U28 floor 1 ch1 is v1 (wrapped graph available)")
	var v1_map_before: Array[Dictionary] = s.map.duplicate(true)
	var v1_ref: Array[Dictionary] = chapters.generate_region_map("ch1", 77, 0, 1, 0)
	check(v1_map_before == v1_ref, "U28 the v1 column map is generated exactly as before (byte-equal to generate_region_map)")
	var b1: RunSession = _round_trip(s, "U28 v1 floor 1 at entry")
	check(b1.graph != null and b1.graph.is_v1() and b1.map == v1_map_before, "U28 reload keeps the v1 columns and re-wraps them")
	_walk_to_boss(s)
	check(s.floor == 1 and s.choose_region("hellfire", 1) and s.is_v2_region(), "U28 floor 2 hellfire is v2 in the same session")
	s.choose_node_id("n0")
	s.complete_node(250.0, 300.0, "battle", {})
	var b2: RunSession = _round_trip(s, "U28 v2 floor 2 after the entry")
	check(b2.is_v2_region() and b2.gauge() == 1 and b2.available_node_ids() == s.available_node_ids(), "U28 reload inside the v2 region keeps gauge and availability")
	_walk_to_boss(b2)
	check(b2.floor == 2 and b2.choose_region("desert", 1) and not b2.is_v2_region(), "U28 floor 3 desert is v1 again")
	var b3: RunSession = _round_trip(b2, "U28 v1 floor 3 at entry")
	check(b3 != null and b3.region_id == "desert" and b3.available_nodes().size() == 1, "U28 the v1 region resumes at its entry after the v2 one")

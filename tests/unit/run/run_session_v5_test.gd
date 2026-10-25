extends SceneTree
## Story 031 Part C/E: RunSession save v5 (world run): round trip at 6 exit points, a region boss raises
## the floor and heals floor_heal_ratio x max HP (clamped) without winning, the final match wins the
## run, a v4 (chapter) save loads as needs_restart. Uses the shipped chapters.json (world block).

var fails: int = 0
var passes: int = 0
const CFG: Dictionary = {"luck_start": 0.0, "luck_per_node": 1.0, "rest_heal_ratio": 0.3, "rest_forge_levels": 1, "boss_removal_tokens": 1}
const MAX_HP: float = 300.0
const SEED: int = 4242


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _chapters() -> ChaptersConfig:
	return ChaptersConfig.load_from_file()


func _new(chapters: ChaptersConfig) -> RunSession:
	var ch: Dictionary = CharacterConfig.load_from_file().get_character("kiem_si")
	return RunSession.begin_world(chapters, ch, SEED, 1)


# JSON round trip (numbers come back as floats, like the real store).
func _rt(s: RunSession, chapters: ChaptersConfig) -> RunSession:
	return RunSession.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), chapters)


func _same(a: RunSession, b: RunSession) -> bool:
	return b != null and a.floor == b.floor and a.region_id == b.region_id and a.region_offer == b.region_offer \
		and a.region_path == b.region_path and a.map == b.map and a.column == b.column and a.node_index == b.node_index \
		and a.cleared_nodes == b.cleared_nodes and a.nodes_cleared == b.nodes_cleared and is_equal_approx(a.hp, b.hp) \
		and a.deck == b.deck and a.removal_tokens == b.removal_tokens and a.run_seed == b.run_seed \
		and is_equal_approx(a.elapsed_sec, b.elapsed_sec) and a.pending_reward == b.pending_reward \
		and a.last_node_kind == b.last_node_kind and is_equal_approx(a.luck(CFG), b.luck(CFG)) \
		and a.is_run_won() == b.is_run_won() and not b.needs_restart


# Clears the current region with first nodes up to (not including) its boss column.
func _walk_to_boss(s: RunSession) -> void:
	while s.column < s.map.size() - 1:
		s.choose_node(int(s.available_nodes()[0]["node_index"]))
		s.complete_node(s.hp, MAX_HP, "", CFG)


func _initialize() -> void:
	var chapters: ChaptersConfig = _chapters()
	var floors: int = chapters.world_floors()
	var ratio: float = chapters.floor_heal_ratio()
	# --- begin ---
	var s: RunSession = _new(chapters)
	_check("begin_world: floor 0, offer open, no region, no map", s.floor == 0 and s.is_choosing_region() and s.region_id.is_empty()
		and s.map.is_empty() and s.region_path.is_empty() and s.hp == -1.0 and not s.is_run_won())
	_check("offer = WorldMapGen", s.region_offer == WorldMapGen.offer_for_floor(chapters.region_ids(), SEED, 0, [],
		int(chapters.world_spec()["choices_per_floor"])))
	# exit 1: world map (region offer open)
	s.elapsed_sec = 12.5
	_check("round trip 1: world map", _same(s, _rt(s, chapters)) and _rt(s, chapters).is_choosing_region())
	_check("choose_region refuses an id not offered", not s.choose_region("zz", 0) and s.is_choosing_region())
	var pick: String = s.region_offer[0]
	_check("choose_region", s.choose_region(pick, 0) and s.region_id == pick and s.region_path == ([pick] as Array[String])
		and s.region_offer.is_empty() and s.column == 0 and not s.map.is_empty())
	_check("region map = generate_region_map", s.map == chapters.generate_region_map(pick, SEED, 0, 0))
	# exit 2: region map, nothing chosen
	_check("round trip 2: region map", _same(s, _rt(s, chapters)))
	# exit 3: mid-match (node chosen)
	s.choose_node(int(s.available_nodes()[0]["node_index"]))
	s.hp = 222.0
	_check("round trip 3: in a match", _same(s, _rt(s, chapters)) and _rt(s, chapters).node_index == s.node_index)
	_check("arena seed = arena_seed_for(run_seed, floor*100+column)", s.floor_seed() == ChaptersConfig.arena_seed_for(SEED, s.floor * 100 + s.column))
	# exit 4: reward screen (offer pending after the node)
	s.complete_node(200.0, MAX_HP, "", CFG)
	s.set_pending_reward(["kiem_khi"] as Array[String])
	_check("round trip 4: reward screen", _same(s, _rt(s, chapters)) and _rt(s, chapters).has_pending_reward())
	s.clear_pending_reward()
	# exit 5: rest node chosen
	var r: RunSession = _new(chapters)
	var rest_found: bool = false
	for id: String in r.region_offer:
		var t: RunSession = _new(chapters)
		t.choose_region(id, 0)
		t.choose_node(0)
		t.complete_node(t.hp, MAX_HP, "", CFG)
		for n: Dictionary in t.available_nodes():
			if str(n["kind"]) == "rest" and not rest_found:
				t.choose_node(int(n["node_index"]))
				rest_found = true
				r = t
	if rest_found:
		_check("round trip 5: rest node", _same(r, _rt(r, chapters)) and str(_rt(r, chapters).current_node()["kind"]) == "rest")
	else:
		# Column 1 always has rest OR treasure; a treasure node is the same exit shape (node chosen, no fight).
		var tr_run: RunSession = _new(chapters)
		tr_run.choose_region(tr_run.region_offer[0], 0)
		tr_run.choose_node(0)
		tr_run.complete_node(tr_run.hp, MAX_HP, "", CFG)
		tr_run.choose_node(int(tr_run.available_nodes()[0]["node_index"]))
		_check("round trip 5: node chosen in column 1 (no rest on this seed)", _same(tr_run, _rt(tr_run, chapters)))
	# --- region boss: floor +1, heal 25 % clamped, not won ---
	_walk_to_boss(s)
	s.choose_node(0)
	var tokens: int = s.removal_tokens
	var res: Dictionary = s.complete_node(100.0, MAX_HP, "", CFG)
	_check("region boss: floor +1, not won", s.floor == 1 and not bool(res["run_won"]) and not s.is_run_won() and bool(res["floor_cleared"])
		and str(res["region"]) == pick)
	_check("region boss: heal floor_heal_ratio x max", is_equal_approx(s.hp, 100.0 + ratio * MAX_HP) and is_equal_approx(float(res["healed"]), ratio * MAX_HP), str(s.hp))
	_check("floor_heal_ratio read from world data (story start value 0.25; the file wins)", ratio > 0.0 and ratio <= 1.0 and is_equal_approx(ratio, float(chapters.world_spec()["floor_heal_ratio"])))
	_check("region boss: +1 removal token, counter", s.removal_tokens == tokens + 1 and s.cleared_bosses_this_run == 1)
	_check("region boss: next offer rolled", s.is_choosing_region() and s.region_offer == WorldMapGen.offer_for_floor(chapters.region_ids(), SEED, 1, [pick],
		int(chapters.world_spec()["choices_per_floor"])) and s.last_node_kind == "boss")
	# exit 6: boss reward pending while the next floor's offer is open
	s.set_pending_reward(["kiem_khi"] as Array[String])
	_check("round trip 6: boss reward + world map", _same(s, _rt(s, chapters)) and _rt(s, chapters).has_pending_reward() and _rt(s, chapters).is_choosing_region())
	_check("choose_region refused while a card offer is open", not s.choose_region(s.region_offer[0], 0))
	s.clear_pending_reward()
	var c: RunSession = _new(chapters)
	c.choose_region(c.region_offer[0], 0)
	_walk_to_boss(c)
	c.choose_node(0)
	c.complete_node(290.0, MAX_HP, "", CFG)
	_check("region boss heal clamped at max", c.hp == MAX_HP and is_equal_approx(c.last_floor_heal, 10.0), str(c.hp))
	# --- luck accumulates across regions ---
	_check("luck counts every node of the run", is_equal_approx(s.luck(CFG), float(s.nodes_cleared)) and s.cleared_nodes.size() == s.map.size())
	# --- climb to the final match ---
	var guard: int = 0
	while not s.is_final_floor() and guard < 100:
		guard += 1
		s.choose_region(s.region_offer[0], 1)
		_walk_to_boss(s)
		s.choose_node(0)
		s.complete_node(s.hp, MAX_HP, "", CFG)
	var fm: Dictionary = chapters.final_match()
	_check("after floor %d -> final match node" % floors, s.floor == floors and s.is_final_floor() and s.region_offer.is_empty()
		and s.region_id == str(fm["region"]) and s.map.size() == 1 and str(s.map[0]["nodes"][0]["match_id"]) == str(fm["match_id"]) and not s.is_run_won())
	_check("region path one id per floor", s.region_path.size() == floors)
	_check("round trip at the final", _same(s, _rt(s, chapters)))
	s.choose_node(0)
	var fin: Dictionary = s.complete_node(50.0, MAX_HP, "", CFG)
	_check("final match won -> run won", bool(fin["run_won"]) and s.is_run_won() and not bool(fin["floor_cleared"]))
	# --- bad v5 data ---
	var bad: Dictionary = c.to_dict()
	bad["floor"] = floors + 1
	_check("floor out of range -> null", RunSession.from_dict(bad, chapters) == null)
	bad = c.to_dict()
	bad["region_offer"] = ["zz"]
	_check("unknown offered region -> null", RunSession.from_dict(bad, chapters) == null)
	# --- old saves ---
	var v4: Dictionary = {"version": 4, "character": "kiem_si", "chapter": "ch2", "map": [{"index": 0, "tier": 0, "nodes": [{"kind": "battle", "match_id": "skeleton"}]}],
		"column": 0, "node_index": -1, "cleared_nodes": [], "hp": 120.0, "deck": [{"id": "kiem_khi", "level": 1}], "run_seed": 3}
	var o4: RunSession = RunSession.from_dict(v4, chapters)
	_check("v4 save -> needs_restart", o4 != null and o4.needs_restart and o4.restart_reason == RunSession.RESTART_OLD_SAVE and o4.character_id == "kiem_si" and o4.map.is_empty())
	var ps := ProgressState.new()
	ps._run = v4.duplicate(true)
	var loaded: ProgressState = ProgressState.from_json(ps.to_json(), chapters)
	_check("v4 run inside a progress file -> needs_restart v5 dict", loaded.has_run() and bool(loaded.get_run_dict().get("needs_restart", false))
		and int(loaded.get_run_dict()["version"]) == RunSession.SAVE_VERSION)
	print("FAILS=", fails, " PASSES=", passes)
	quit(1 if fails > 0 else 0)

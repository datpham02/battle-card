extends SceneTree
## Story 022 Part 1b: RunSession v4 + ProgressState v4 (hand-built map, no generator).

var fails: int = 0
const CFG: Dictionary = {"luck_start": 0.0, "luck_per_node": 1.0, "rest_heal_ratio": 0.3, "rest_forge_levels": 1}


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _map() -> Array[Dictionary]:
	var kinds: Array = [["battle"], ["battle", "danger", "treasure"], ["danger", "battle"], ["miniboss"], ["rest", "treasure"], ["battle", "danger"], ["boss"]]
	var m: Array[Dictionary] = []
	for c: int in kinds.size():
		var nodes: Array = []
		for k: Variant in kinds[c] as Array:
			nodes.append({"kind": str(k), "match_id": "goblin_scout"})
		m.append({"index": c, "tier": 0 if c == 0 else (1 if c < 3 else 2), "nodes": nodes})
	return m


func _new(removals: int = 1) -> RunSession:
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var ch: Dictionary = CharacterConfig.load_from_file().get_character("kiem_si")
	return RunSession.begin(chapters, ch, 0, 42, _map(), removals)


func _initialize() -> void:
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var s: RunSession = _new()
	_check("begin", s.column == 0 and s.node_index == -1 and s.removal_tokens == 1 and s.hp == -1.0 and s.map.size() == 7 and s.deck.size() == 6 and not s.needs_restart)
	_check("current_column", int(s.current_column()["index"]) == 0)
	_check("current_node none", s.current_node().is_empty())
	_check("complete without choose rejected", not bool(s.complete_node(50.0, 300.0, "battle", CFG)["advanced"]) and s.column == 0 and s.cleared_nodes.is_empty())
	_check("choose out of range", not s.choose_node(5) and not s.choose_node(-1))
	_check("choose ok", s.choose_node(0) and s.node_index == 0 and s.current_node()["kind"] == "battle")
	_check("double choose rejected", not s.choose_node(0))
	var r: Dictionary = s.complete_node(120.0, 300.0, "battle", CFG)
	_check("complete advances; no heal", bool(r["advanced"]) and not bool(r["run_won"]) and s.column == 1 and s.node_index == -1 and s.hp == 120.0, str(s.hp))
	_check("cleared recorded", s.cleared_nodes.size() == 1 and s.cleared_nodes[0]["kind"] == "battle")
	_check("hp clamp to max", (func() -> bool:
		var t: RunSession = _new()
		t.choose_node(0)
		t.complete_node(500.0, 300.0, "battle", CFG)
		return t.hp == 300.0).call())
	_check("passive heal added once", (func() -> bool:
		var t: RunSession = _new()
		t.choose_node(0)
		t.complete_node(100.0, 300.0, "battle", CFG, 30.0)
		return t.hp == 130.0).call())
	var av: Array[Dictionary] = s.available_nodes()
	_check("available column 1 = 3 nodes with node_index", av.size() == 3 and int(av[2]["node_index"]) == 2)
	s.cleared_nodes.append({"column": 1, "node_index": 1, "kind": "danger"})
	_check("available excludes cleared", s.available_nodes().size() == 2 and not s.choose_node(1))
	s.cleared_nodes.pop_back()
	_check("one node per column", s.choose_node(2) and s.complete_node(100.0, 300.0, "", CFG)["advanced"] == true and s.column == 2 and s.cleared_nodes[1]["kind"] == "treasure")
	# luck formula
	var l: RunSession = _new()
	_check("luck 0", l.luck(CFG) == 0.0)
	for i: int in 3:
		l.cleared_nodes.append({"column": i, "node_index": 0, "kind": "battle"})
	_check("luck 3", l.luck(CFG) == 3.0)
	for i: int in 7:
		l.cleared_nodes.append({"column": 3 + i, "node_index": 0, "kind": "battle"})
	_check("luck 10", l.luck(CFG) == 10.0)
	_check("luck config-driven", l.luck({"luck_start": 5.0, "luck_per_node": 2.0}) == 25.0)
	# boss
	var b: RunSession = _new()
	b.column = 6
	b.choose_node(0)
	var rb: Dictionary = b.complete_node(200.0, 300.0, "boss", CFG)
	_check("boss: token, counter, won", b.removal_tokens == 2 and b.cleared_bosses_this_run == 1 and bool(rb["run_won"]) and b.is_run_won() and b.column == 7)
	_check("not won before boss", not _new().is_run_won())
	# removal tokens
	var t: RunSession = _new(1)
	_check("spend ok then refuse", t.spend_removal() and t.removal_tokens == 0 and not t.spend_removal() and t.removal_tokens == 0)
	var d: RunSession = _new(1)
	_check("remove needs token + spends", d.remove_card_at(0, 4) and d.removal_tokens == 0 and d.deck.size() == 5)
	_check("remove refused with 0 tokens", not d.remove_card_at(0, 4) and d.deck.size() == 5)
	d.removal_tokens = 3
	_check("remove respects min deck size, no token spent", not d.remove_card_at(0, 5) and d.removal_tokens == 3 and d.deck.size() == 5)
	_check("remove bad index", not d.remove_card_at(99, 1) and d.removal_tokens == 3)
	# rest
	var h: RunSession = _new()
	h.hp = 100.0
	var healed: float = h.rest_heal(300.0, CFG)
	_check("rest_heal 30%", is_equal_approx(healed, 90.0) and is_equal_approx(h.hp, 190.0), str(h.hp))
	h.hp = 280.0
	healed = h.rest_heal(300.0, CFG)
	_check("rest_heal clamp", is_equal_approx(healed, 20.0) and h.hp == 300.0)
	h.hp = -1.0
	_check("rest_heal at full (-1) heals 0", h.rest_heal(300.0, CFG) == 0.0 and h.hp == 300.0)
	var f: RunSession = _new()
	var fr: Dictionary = f.rest_forge(0, CFG)
	_check("forge +1", bool(fr["ok"]) and int(fr["level"]) == 2 and int(f.deck[0]["level"]) == 2)
	f.rest_forge(0, CFG)
	_check("forge cap 3", int(f.deck[0]["level"]) == SkillConfig.MAX_LEVEL)
	fr = f.rest_forge(0, CFG)
	_check("forge at cap refused", not bool(fr["ok"]) and int(fr["level"]) == SkillConfig.MAX_LEVEL)
	_check("forge bad index", not bool(f.rest_forge(-1, CFG)["ok"]) and not bool(f.rest_forge(99, CFG)["ok"]))
	# round trip
	var q: RunSession = _new(2)
	q.choose_node(0)
	q.complete_node(150.0, 300.0, "battle", CFG)
	q.choose_node(1)
	q.set_pending_reward(["kiem_khi"] as Array[String])
	q.hp = 150.0
	var text: String = JSON.stringify(q.to_dict())
	var back: RunSession = RunSession.from_dict(JSON.parse_string(text), chapters)
	_check("v4 round trip", back != null and back.column == 1 and back.node_index == 1 and back.removal_tokens == 2 and back.map.size() == 7
		and back.cleared_nodes.size() == 1 and back.luck(CFG) == 1.0 and back.hp == 150.0 and back.deck.size() == 6 and back.pending_reward.size() == 1
		and back.run_seed == 42 and not back.needs_restart and back.current_node()["kind"] == "danger", str(back))
	_check("round trip map content", back != null and back.map == q.map and int(back.map[3]["nodes"][0].get("kind", "") == "miniboss"))
	_check("round trip cleared_bosses_this_run", (func() -> bool:
		var z: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())), chapters)
		return z != null and z.cleared_bosses_this_run == 1 and z.is_run_won()).call())
	var bad: Dictionary = q.to_dict()
	bad["column"] = 99
	_check("bad column -> null", RunSession.from_dict(bad, chapters) == null)
	# old saves
	var chap_id: String = chapters.chapter_id(0)
	var v3: Dictionary = {"character": "kiem_si", "chapter": chap_id, "floor": "f2", "match_index": 1, "hp": 80.0, "deck": [{"id": "kiem_khi", "level": 2}], "run_seed": 5, "elapsed": 1.0, "pending_reward": [], "revives": 0}
	var o3: RunSession = RunSession.from_dict(v3, chapters)
	_check("v3 -> needs_restart", o3 != null and o3.needs_restart and o3.restart_reason == "run.restart.old_save" and o3.map.is_empty() and o3.character_id == "kiem_si")
	var v2: Dictionary = {"character": "phap_su", "chapter": chap_id, "floor": "f1", "match_index": 0, "hp": 50.0, "deck": ["kiem_khi", "hoa_tran"], "run_seed": 5, "elapsed": 0.0, "pending_reward": [], "revives": 0, "version": 2}
	var o2: RunSession = RunSession.from_dict(v2, chapters)
	_check("v2 -> needs_restart", o2 != null and o2.needs_restart and o2.character_id == "phap_su")
	var rt: RunSession = RunSession.from_dict(o2.to_dict(), chapters)
	_check("needs_restart survives to_dict", rt != null and rt.needs_restart and rt.restart_reason == "run.restart.old_save")
	_check("old run unknown chapter -> null", RunSession.from_dict({"character": "kiem_si", "chapter": "zz"}, chapters) == null)
	# progress state
	var ps := ProgressState.new()
	ps.mark_chapter_cleared(chap_id)
	ps.set_locale("en")
	ps.record_boss_clear()
	ps.add_cleared_boss()
	ps.set_run(q)
	var store: ProgressStore = ProgressStore.memory_store()
	_check("save ok", store.save_state(ps))
	var loaded: ProgressState = store.load_state(chapters)
	_check("progress v4 round trip", ProgressState.VERSION == 4 and loaded.get_cleared_bosses() == 2 and loaded.is_chapter_cleared(chap_id) and loaded.get_locale() == "en" and loaded.has_run())
	var lr: RunSession = RunSession.from_dict(loaded.get_run_dict(), chapters)
	_check("progress run back", lr != null and lr.column == 1 and lr.removal_tokens == 2 and lr.map.size() == 7)
	_check("version field 4", int(JSON.parse_string(ps.to_json())["version"]) == 4)
	var v3file: String = JSON.stringify({"version": 3, "locale": "en", "cleared_chapters": [chap_id], "seen_cards": ["kiem_khi"], "run_in_progress": v3})
	var l3: ProgressState = ProgressState.from_json(v3file, chapters)
	_check("v3 file loads", l3.get_cleared_bosses() == 0 and l3.is_chapter_cleared(chap_id) and l3.get_locale() == "en" and l3.get_seen_cards().has("kiem_khi"))
	var l3r: RunSession = RunSession.from_dict(l3.get_run_dict(), chapters)
	_check("v3 file run -> needs_restart", l3.has_run() and l3r != null and l3r.needs_restart)
	var v2file: String = JSON.stringify({"version": 2, "locale": "vi", "cleared_chapters": [], "seen_cards": [], "run_in_progress": null})
	_check("v2 file loads", not ProgressState.from_json(v2file, chapters).has_run())
	_check("v1 file loads", ProgressState.from_json("{\"version\":1,\"locale\":\"en\"}", chapters).get_locale() == "en")
	_check("future version rejected", not ProgressState.from_json("{\"version\":9}", chapters).is_chapter_cleared(chap_id))
	var ms: ProgressStore = ProgressStore.memory_store()
	ms.save_state(ProgressState.new())
	_check("memory empty state round trip", ms.load_state(chapters).get_cleared_bosses() == 0 and not ms.load_state(chapters).has_run())
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

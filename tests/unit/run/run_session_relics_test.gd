extends SceneTree
## Story 032 Part C (wave 1B): relics in the run. RunSession.add_relic (duplicate / unknown refused),
## save round trip with the open treasure offer, a v5 save without the relic keys, unknown ids dropped;
## GameFlow treasure node = ONE screen with a card row and a relic row: deterministic by seed, choosing a
## relic / a card / skipping closes BOTH rows, resume at the open screen keeps both rows, owned relics are
## never offered again, `--relics=` style start is validated. Uses the shipped data and main.tscn.
## Prints PASS/FAIL lines and FAILS=n; exits with that count.

const MAIN_SCENE: String = "res://src/main.tscn"
const HERO: String = "phap_su"
const SEED: int = 4242
const RUN_SEED: int = 77
const MAX_HP: float = 300.0
const CFG: Dictionary = {"luck_start": 0.0, "luck_per_node": 1.0, "rest_heal_ratio": 0.3, "rest_forge_levels": 1, "boss_removal_tokens": 1}
const UNKNOWN_RELIC: String = "relic_that_does_not_exist"

var fails: int = 0
var passes: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, name: String, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _new_session(chapters: ChaptersConfig) -> RunSession:
	var ch: Dictionary = CharacterConfig.load_from_file().get_character(HERO)
	return RunSession.begin_world(chapters, ch, SEED, 1)


func _rt(s: RunSession, chapters: ChaptersConfig) -> RunSession:
	return RunSession.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), chapters)


func _treasure_map() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in 4:
		out.append({"index": i, "tier": 1, "nodes": [{"kind": "treasure", "match_id": ""}]})
	return out


func _new_main(store: ProgressStore) -> Node:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	(main.get_node("GameFlow") as GameFlow).set_store_for_test(store)
	root.add_child(main)
	await process_frame
	return main


func _drop_main(main: Node) -> void:
	root.remove_child(main)
	main.queue_free()
	await process_frame


# A store holding a fresh run on the 4-treasure map (seed RUN_SEED), ready for continue_requested.
func _store_with_run(config: ChaptersConfig, owned: Array[String] = []) -> ProgressStore:
	var run: RunSession = RunSession.begin(config, CharacterConfig.load_from_file().get_character(HERO), 0, RUN_SEED, _treasure_map(), 1)
	for id: String in owned:
		run.add_relic(id)
	var store: ProgressStore = ProgressStore.memory_store()
	var progress := ProgressState.new()
	progress.set_run(run)
	store.save_state(progress)
	return store


func _run() -> void:
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var ids: Array[String] = RelicRegistry.all_ids()
	_check(ids.size() >= 3, "registry has at least 3 relics", str(ids.size()))
	if ids.size() < 3:
		print("FAILS=", fails)
		quit(fails)
		return
	var a: String = ids[0]
	var b: String = ids[1]
	var c: String = ids[2]

	# --- RunSession API ---
	var s: RunSession = _new_session(chapters)
	_check(s.relic_ids().is_empty() and not s.has_relic(a) and not s.has_pending_relic_offer(), "fresh run: no relics, no relic offer")
	_check(s.add_relic(a) and s.has_relic(a) and s.relic_ids() == ([a] as Array[String]), "add_relic adds a known relic")
	_check(not s.add_relic(a) and s.relics.size() == 1, "add_relic refuses a duplicate")
	_check(not s.add_relic(UNKNOWN_RELIC) and not s.has_relic(UNKNOWN_RELIC), "add_relic refuses an unknown id")
	_check(not s.add_relic(""), "add_relic refuses an empty id")
	s.add_relic(b)
	_check(s.relic_ids() == ([a, b] as Array[String]), "relics keep the received order")
	var copy: Array[String] = s.relic_ids()
	copy.append(c)
	_check(s.relics.size() == 2, "relic_ids() is a copy")

	# --- save round trip ---
	var d: Dictionary = s.to_dict()
	_check(d.has("relics") and d.has("pending_relic_offer") and int(d["version"]) == RunSession.SAVE_VERSION, "to_dict carries relics + pending_relic_offer")
	s.choose_region(s.region_offer[0], 0)
	s.choose_node(0)
	s.set_pending_reward(["kiem_khi"] as Array[String])
	s.set_pending_relic_offer([c] as Array[String])
	var back: RunSession = _rt(s, chapters)
	_check(back != null and back.relics == s.relics and back.pending_relic_offer == s.pending_relic_offer and back.pending_reward == s.pending_reward,
		"round trip keeps relics and both offer rows")
	_check(back != null and back.has_pending_relic_offer() and back.has_relic(a) and back.has_relic(b), "round trip: has_* work")
	s.clear_pending_relic_offer()
	_check(not s.has_pending_relic_offer() and s.has_pending_reward(), "clear_pending_relic_offer leaves the card row")

	# --- old save / bad ids ---
	var old: Dictionary = s.to_dict()
	old.erase("relics")
	old.erase("pending_relic_offer")
	var loaded: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(old)), chapters)
	_check(loaded != null and loaded.relics.is_empty() and not loaded.has_pending_relic_offer() and not loaded.needs_restart,
		"v5 save without the relic keys loads with no relics")
	var dirty: Dictionary = s.to_dict()
	dirty["relics"] = [a, UNKNOWN_RELIC, a, b]
	dirty["pending_relic_offer"] = [UNKNOWN_RELIC, c]
	var cleaned: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(dirty)), chapters)
	_check(cleaned != null and cleaned.relics == ([a, b] as Array[String]) and cleaned.pending_relic_offer == ([c] as Array[String]),
		"from_dict drops unknown and duplicate relic ids")
	var junk: Dictionary = s.to_dict()
	junk["relics"] = "not a list"
	var survived: RunSession = RunSession.from_dict(JSON.parse_string(JSON.stringify(junk)), chapters)
	_check(survived != null and survived.relics.is_empty(), "a non-list relics value = no relics, no crash")

	# --- GameFlow: treasure with two rows ---
	var store: ProgressStore = _store_with_run(chapters)
	var main: Node = await _new_main(store)
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	flow.continue_requested()
	_check(flow.get_phase() == GameFlow.Phase.MAP and not flow.has_relic_offer() and flow.get_relics().is_empty(), "continue: MAP, no relic offer yet")
	_check(flow.choose_node(0), "choose the treasure")
	var cards: Array[String] = flow.get_pending_reward()
	var relics: Array[String] = flow.get_relic_offer()
	_check(cards.size() == 3 and flow.get_pending_reward_kind() == "treasure", "treasure: card row of 3")
	_check(flow.has_relic_offer() and relics.size() >= 1 and relics.size() <= 3, "treasure: relic row open", str(relics))
	_check(_all_known_unique(relics), "relic row: known ids, no duplicates", str(relics))
	var info: Dictionary = flow.relic_info(relics[0])
	_check(str(info.get("id", "")) == relics[0] and info.has("rarity") and info.has("name") and info.has("desc"), "relic_info has registry fields + name/desc")
	_check(flow.relic_info(UNKNOWN_RELIC).is_empty(), "relic_info of an unknown id is {}")
	_check(flow.get_run().node_index == 0 and flow.get_cleared_nodes().is_empty(), "treasure not completed before a pick")
	var saved: Dictionary = store.load_state(chapters).get_run_dict()
	_check((saved.get("pending_reward", []) as Array).size() == 3 and (saved.get("pending_relic_offer", []) as Array).size() == relics.size(),
		"store: both rows saved with the treasure chosen")
	# wrong id ignored
	flow.choose_relic(UNKNOWN_RELIC)
	_check(flow.has_relic_offer() and flow.get_relics().is_empty() and flow.get_pending_reward().size() == 3, "choose_relic with an id outside the offer is ignored")
	# resume keeps both rows
	await _drop_main(main)
	var main_b: Node = await _new_main(store)
	var flow_b: GameFlow = main_b.get_node("GameFlow") as GameFlow
	flow_b.continue_requested()
	_check(flow_b.get_phase() == GameFlow.Phase.MAP and flow_b.get_pending_reward() == cards and flow_b.get_relic_offer() == relics,
		"resume at the open treasure screen keeps both rows")
	_check(flow_b.get_pending_reward_kind() == "treasure", "resume: pending kind is treasure")
	# choose a relic: both rows close
	var picked: String = relics[0]
	var deck_before: int = flow_b.get_run().deck_ids.size()
	flow_b.choose_relic(picked)
	_check(flow_b.get_relics() == ([picked] as Array[String]) and flow_b.get_run().has_relic(picked), "choose_relic: the relic joins the run")
	_check(flow_b.get_pending_reward().is_empty() and flow_b.get_relic_offer().is_empty() and not flow_b.has_relic_offer(), "choose_relic closes BOTH rows")
	_check(flow_b.get_run().deck_ids.size() == deck_before, "choose_relic adds no card")
	_check(flow_b.get_current_column() == 1 and flow_b.get_cleared_nodes().size() == 1 and flow_b.get_phase() == GameFlow.Phase.MAP, "choose_relic completes the node -> column 1")
	saved = store.load_state(chapters).get_run_dict()
	_check(saved.get("relics", []) == [picked] and (saved.get("pending_relic_offer", [1]) as Array).is_empty() and (saved.get("pending_reward", [1]) as Array).is_empty(),
		"store: relic saved, rows cleared")
	# second treasure: owned relic not offered again; choose a card -> both rows close
	_check(flow_b.choose_node(0), "choose the second treasure")
	var relics2: Array[String] = flow_b.get_relic_offer()
	_check(not relics2.has(picked), "an owned relic is not offered again", str(relics2))
	var cards2: Array[String] = flow_b.get_pending_reward()
	flow_b.reward_chosen(cards2[0])
	_check(flow_b.get_pending_reward().is_empty() and flow_b.get_relic_offer().is_empty(), "choosing a card closes BOTH rows")
	_check(flow_b.get_relics() == ([picked] as Array[String]), "choosing a card gives no relic")
	_check(flow_b.get_current_column() == 2, "choosing a card completes the node -> column 2")
	# third treasure: skip via the relic skip closes both
	_check(flow_b.choose_node(0), "choose the third treasure")
	var deck_mid: int = flow_b.get_run().deck_ids.size()
	flow_b.skip_relic_offer()
	_check(flow_b.get_pending_reward().is_empty() and flow_b.get_relic_offer().is_empty() and flow_b.get_relics() == ([picked] as Array[String]), "skip_relic_offer closes BOTH rows, takes nothing")
	_check(flow_b.get_run().deck_ids.size() == deck_mid and flow_b.get_current_column() == 3, "skip: deck unchanged, node completed")
	# fourth treasure: skip via the card skip also closes both
	_check(flow_b.choose_node(0), "choose the fourth treasure")
	flow_b.reward_skipped()
	_check(flow_b.get_pending_reward().is_empty() and flow_b.get_relic_offer().is_empty(), "reward_skipped closes BOTH rows")
	_check(flow_b.get_current_column() == 4, "fourth treasure done -> column 4")
	flow_b.choose_relic(a)
	_check(flow_b.get_relics() == ([picked] as Array[String]), "choose_relic with no offer open is ignored")
	await _drop_main(main_b)

	# --- determinism by seed: the same run + node rolls the same relic row ---
	var store_c: ProgressStore = _store_with_run(chapters)
	var main_c: Node = await _new_main(store_c)
	var flow_c: GameFlow = main_c.get_node("GameFlow") as GameFlow
	flow_c.continue_requested()
	flow_c.choose_node(0)
	_check(flow_c.get_relic_offer() == relics and flow_c.get_pending_reward() == cards, "same seed + node -> same relic row and card row")
	await _drop_main(main_c)
	var seed_other: RunSession = RunSession.begin(chapters, CharacterConfig.load_from_file().get_character(HERO), 0, RUN_SEED + 1, _treasure_map(), 1)
	var other_store: ProgressStore = ProgressStore.memory_store()
	var other_progress := ProgressState.new()
	other_progress.set_run(seed_other)
	other_store.save_state(other_progress)
	var main_o: Node = await _new_main(other_store)
	var flow_o: GameFlow = main_o.get_node("GameFlow") as GameFlow
	flow_o.continue_requested()
	flow_o.choose_node(0)
	_check(_all_known_unique(flow_o.get_relic_offer()) and flow_o.has_relic_offer(), "another seed still rolls a valid relic row")
	await _drop_main(main_o)

	# --- a run that already owns relics: they never come back in the offer ---
	var owned: Array[String] = [a, b]
	var store_d: ProgressStore = _store_with_run(chapters, owned)
	var main_d: Node = await _new_main(store_d)
	var flow_d: GameFlow = main_d.get_node("GameFlow") as GameFlow
	flow_d.continue_requested()
	_check(flow_d.get_relics() == owned, "a saved run keeps its relics on resume")
	flow_d.choose_node(0)
	var offer_d: Array[String] = flow_d.get_relic_offer()
	_check(not offer_d.has(a) and not offer_d.has(b), "owned relics are excluded from the treasure row", str(offer_d))
	await _drop_main(main_d)

	print("PASSES=", passes, " FAILS=", fails)
	quit(fails)


func _all_known_unique(list: Array[String]) -> bool:
	var seen: Dictionary = {}
	for id: String in list:
		if RelicRegistry.info(id).is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true

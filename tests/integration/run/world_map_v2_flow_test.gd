extends SceneTree
## World Map v2 I1 + I2 (docs/design/world-map-v2/06 section 4): GameFlow through the Hellfire vertical slice, headless,
## on run seed 24 (peril / safe / treasure lanes, shop at the hub, rest + miniboss approach, the peril objective
## no_hit_3; found by a seed search, see the Phase 5 note in autonomous-progress.md):
## floor 1 (ch1, v1) walked to its warden -> fate -> floor 2 hellfire (v2): graph API, previews, lane commitment,
## modifiers reaching the live match (CombatView.match_params), Heat stepping per node and reaching the hazards
## (vent_interval_sec / vent_tick_damage in TileHazards), the tier-3 reward (rare floor + relic row) and the objective
## bonus, the shop hub, prepare vs gamble, the warden hook (vent_surge vents 3 at heat >= 3), fate -> floor 3 desert
## (v1); save / reload (go_back + continue) at the fork, mid-lane and at the approach; the forge flow on a map that
## holds one (seed 28's treasure lane).
## Run: godot --headless --path . -s res://tests/integration/run/world_map_v2_flow_test.gd

const MAIN_SCENE: String = "res://src/main.tscn"
const MAX_FRAMES: int = 4000
const HERO: String = "kiem_si"
const SEED_SLICE: int = 24
const SEED_FORGE: int = 28

var _fails: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _phase(controller: RunController) -> int:
	return controller.get_state().get_phase()


func _wait_phase(controller: RunController, phase: int) -> bool:
	for _i: int in MAX_FRAMES:
		if controller == null or not is_instance_valid(controller):
			return false
		if _phase(controller) == phase:
			return true
		await process_frame
	return false


func _view(controller: RunController) -> CombatView:
	return controller.get_battle().get_node(RunController.COMBAT_VIEW_NODE) as CombatView


func _new_main(store: ProgressStore, seed: int) -> Node:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	var flow: GameFlow = main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(store)
	flow.set_seed_for_test(seed)
	root.add_child(main)
	await process_frame
	return main


func _drop_main(main: Node) -> void:
	root.remove_child(main)
	main.queue_free()
	await process_frame


func _kill_until_won(controller: RunController) -> bool:
	for _i: int in MAX_FRAMES:
		if controller == null or not is_instance_valid(controller):
			return false
		if _phase(controller) == RunState.Phase.WON:
			return true
		var view: CombatView = _view(controller) if controller.get_battle() != null else null
		if view != null and view.get_state() != null and not view.get_state().is_enemy_dead():
			view.get_state().enemy_invulnerable_left = 0.0
			view.get_state().damage(CombatState.Side.ENEMY, 999999.0)
		await process_frame
	return false


# Resolves whatever reward rows are open (relic, ink, cards) by skipping them.
func _skip_reward(flow: GameFlow) -> void:
	if flow.get_run().has_pending_relic_offer():
		flow.skip_relic_offer()
	if flow.has_ink_offer():
		flow.skip_ink_offer()
	if flow.get_run().has_pending_reward():
		flow.reward_skipped()


func _trait_ids(view: CombatView) -> Array[String]:
	var out: Array[String] = []
	for t: Variant in view.match_params.get("traits", []):
		out.append(str((t as Dictionary).get("id", "")))
	return out


func _trait_params(view: CombatView, id: String) -> Dictionary:
	for t: Variant in view.match_params.get("traits", []):
		if str((t as Dictionary).get("id", "")) == id:
			return (t as Dictionary).get("params", {})
	return {}


# Chooses node [param index], plays whatever it is to completion (fights are won at once), returns the controller used
# for a fight (null otherwise). Fate on a region boss: spare.
func _play(flow: GameFlow, index: int) -> RunController:
	var kind: String = ""
	for n: Dictionary in flow.get_available_nodes():
		if int(n["node_index"]) == index:
			kind = str(n["kind"])
	_check(flow.choose_node(index), "choose node %d (%s)" % [index, kind])
	match kind:
		"battle", "danger", "miniboss", "boss":
			var c: RunController = flow.get_controller()
			if c == null:
				_check(false, "no controller for %s" % kind)
				return null
			var ok: bool = await _wait_phase(c, RunState.Phase.PLAYING)
			ok = ok and await _kill_until_won(c)
			_check(ok, "%s won" % kind)
			await process_frame
			if flow.get_phase() == GameFlow.Phase.FATE:
				flow.choose_fate("spare")
			_skip_reward(flow)
			return c
		"treasure":
			_skip_reward(flow)
		"rest":
			flow.rest_heal_requested()
		"shop":
			flow.shop_leave()
		"event":
			flow.event_leave()
		"forge":
			flow.forge_leave()
	return null


# Walks the current region to its warden (first available node, the boss when offered).
func _walk_region(flow: GameFlow) -> void:
	for _i: int in 20:
		if flow.get_phase() != GameFlow.Phase.MAP:
			return
		var avail: Array[Dictionary] = flow.get_available_nodes()
		if avail.is_empty():
			return
		var pick: int = int(avail[0]["node_index"])
		for n: Dictionary in avail:
			if n["kind"] == "boss":
				pick = int(n["node_index"])
		await _play(flow, pick)


func _index_of(flow: GameFlow, id: String) -> int:
	for n: Dictionary in flow.get_available_nodes():
		if flow.get_run().node_id_at(flow.get_run().column, int(n["node_index"])) == id:
			return int(n["node_index"])
	return -1


func _reload(flow_holder: Array, store: ProgressStore, seed: int, label: String) -> GameFlow:
	var main_old: Node = flow_holder[0]
	var flow_old: GameFlow = main_old.get_node("GameFlow") as GameFlow
	var before: Dictionary = flow_old.get_run().to_dict()
	flow_old.go_back()
	_check(flow_old.get_phase() == GameFlow.Phase.TITLE and flow_old.has_continue(), "%s: go_back keeps the save" % label)
	await _drop_main(main_old)
	var main_new: Node = await _new_main(store, seed)
	var flow: GameFlow = main_new.get_node("GameFlow") as GameFlow
	flow.continue_requested()
	var after: Dictionary = flow.get_run().to_dict()
	_check(after["map_graph"] == before["map_graph"] and after["column"] == before["column"] and after["cleared_nodes"] == before["cleared_nodes"] and after["rule_state"] == before["rule_state"], "%s: continue restores graph, position and heat" % label)
	flow_holder[0] = main_new
	return flow


func _run() -> void:
	TranslationServer.set_locale("vi")
	var store: ProgressStore = ProgressStore.memory_store()
	var holder: Array = [await _new_main(store, SEED_SLICE)]
	var flow: GameFlow = (holder[0] as Node).get_node("GameFlow") as GameFlow
	var config: ChaptersConfig = flow.get_config()
	flow.start_requested()
	flow.character_chosen(HERO)
	_check(flow.get_phase() == GameFlow.Phase.WORLD_MAP and flow.get_region_offer() == (["ch1"] as Array[String]), "floor 1 offers ch1")
	var brief1: Dictionary = flow.region_preview("ch1")
	_check(brief1["map_gen"] == "v1" and (brief1["rule"] as Dictionary).is_empty(), "ch1 briefing: v1, no rule")
	flow.choose_region("ch1")
	_check(not flow.get_run().is_v2_region() and flow.get_map_graph().get("source", "") == "v1", "ch1 is v1 (wrapped graph available)")
	await _walk_region(flow)
	_check(flow.get_phase() == GameFlow.Phase.WORLD_MAP and flow.get_floor() == 1 and flow.get_region_offer() == (["hellfire"] as Array[String]), "ch1 warden spared -> floor 2 offers hellfire (phase %d)" % flow.get_phase())
	var brief2: Dictionary = flow.region_preview("hellfire")
	_check(brief2["map_gen"] == "v2" and brief2["rule"]["id"] == "heat" and (brief2["warden_traits"] as Array).has("vent_surge") and bool(brief2["has_shop"]), "hellfire briefing: v2, heat, warden vent_surge, shop on this floor")
	flow.choose_region("hellfire")
	var run: RunSession = flow.get_run()
	_check(flow.get_phase() == GameFlow.Phase.MAP and run.is_v2_region() and run.map.size() == 7, "hellfire entered: v2 map with 7 depths")
	var graph: Dictionary = flow.get_map_graph()
	var archs: Array[String] = []
	for l: Variant in graph["lanes"]:
		archs.append(str((l as Dictionary)["archetype"]))
	_check(archs == (["peril", "safe", "treasure"] as Array[String]) and flow.get_rule_state() == {"id": "heat", "gauge": 0}, "seed 24: lanes %s, heat 0" % str(archs))
	var p0: Dictionary = flow.get_node_preview(0)
	_check(p0["node_id"] == "n0" and p0["kind"] == "battle" and p0["enemy_name_key"].begins_with("boss.") and int(p0["gauge_after"]) == 1, "entry preview: enemy named, heat 0 -> 1")
	await _play(flow, 0)
	_check(flow.get_rule_state()["gauge"] == 1 and flow.get_available_nodes().size() == 3, "entry won: heat 1, three lane starts")
	var previews: Array = []
	for n: Dictionary in flow.get_available_nodes():
		previews.append(flow.get_node_preview(int(n["node_index"])))
	_check(previews[0]["archetype"] == "peril" and previews[1]["archetype"] == "safe" and previews[2]["archetype"] == "treasure" and int(previews[0]["reward_tier"]) == 2 and int(previews[1]["reward_tier"]) == 1, "lane previews carry archetype and tier")
	flow = await _reload(holder, store, SEED_SLICE, "at the fork")
	# Peril lane, slot 1: danger (row_burner from the danger rule), tier 2, 0 extra modifiers.
	var c1: RunController = await _play(flow, _index_of(flow, "L0.1"))
	_check(c1 != null and _trait_ids(_view(c1)).has("row_burner") and not _view(c1).match_params.has("modifiers"), "L0.1 danger: row_burner, no extra modifier")
	_check(is_equal_approx(_view(c1)._hazards.config_value("vent_interval_sec"), 6.0), "I2 heat 1 fight: vent interval 6 s in TileHazards")
	_check(flow.get_rule_state()["gauge"] == 2 and flow.get_available_nodes().size() == 1 and flow.get_run().node_id_at(flow.get_run().column, int(flow.get_available_nodes()[0]["node_index"])) == "L0.2", "lane commitment: only L0.2 open, heat 2")
	var c2: RunController = await _play(flow, _index_of(flow, "L0.2"))
	var mods2: Array = _view(c2).match_params.get("modifiers", [])
	_check(c2 != null and mods2.size() == 1, "L0.2 danger carries one modifier: %s" % str(mods2))
	_check(is_equal_approx(_view(c2)._hazards.config_value("vent_interval_sec"), 5.0), "I2 heat 2 fight: vent interval 5 s")
	_check(flow.get_rule_state()["gauge"] == 3, "heat 3 before the hub")
	flow = await _reload(holder, store, SEED_SLICE, "before the hub")
	_check(flow.get_available_nodes().size() == 1 and flow.get_available_nodes()[0]["kind"] == "shop", "the hub is the shop")
	await _play(flow, int(flow.get_available_nodes()[0]["node_index"]))
	_check(flow.get_rule_state()["gauge"] == 2 and flow.get_available_nodes().size() == 3, "shop: heat 3 -> 2, every lane's last node open")
	var hp_before: float = flow.get_run().hp
	var gold_before: int = flow.get_gold()
	# Balance validation 2026-11-12: the intro band shows RunController.match_modifiers = the node's profile ids (the
	# preview's list, not the region's pool); its block sits inside the band, left of the arena block, no overlap.
	var preview_mod_ids: Array[String] = []
	for m: Variant in flow.get_node_preview(_index_of(flow, "L0.4")).get("modifiers", []):
		preview_mod_ids.append(str((m as Dictionary).get("id", "")))
	var c4: RunController = await _play(flow, _index_of(flow, "L0.4"))
	var mods4: Array = _view(c4).match_params.get("modifiers", [])
	_check(c4 != null and mods4.size() == 1, "L0.4 peril end carries one modifier (tuned 2026-11-12, was two): %s" % str(mods4))
	_check(c4 != null and c4.match_modifiers == preview_mod_ids and preview_mod_ids.size() == 1,
		"intro band modifiers == the node preview's ids %s (1 of a pool of %d)" % [str(preview_mod_ids), RegionRules.shared().modifier_pool("hellfire").size()])
	var vp := Vector2(1280.0, 720.0)
	var band: Rect2 = ScreenLayout.run_intro_band_rect(vp)
	var mod_block: Rect2 = RunHudView.intro_modifiers_rect(vp)
	var arena_block: Rect2 = RunHudView.intro_arena_rect(vp)
	_check(band.encloses(mod_block) and band.encloses(arena_block) and mod_block.end.x < arena_block.position.x,
		"intro modifier block inside the band, clear of the arena block (%s | %s)" % [str(mod_block), str(arena_block)])
	_check(flow.get_run().objectives_met == (["L0.4"] as Array[String]), "objective no_hit_3 met on L0.4 (no hits taken)")
	_check(flow.get_gold() > gold_before, "tier-3 node paid gold (%d -> %d)" % [gold_before, flow.get_gold()])
	_check(flow.get_run().luck_extra > 0.0, "tier luck bonus added (%.1f)" % flow.get_run().luck_extra)
	_check(flow.get_rule_state()["gauge"] == 3 and flow.get_available_nodes().size() == 2, "heat 3, approach offers prepare + gamble")
	flow = await _reload(holder, store, SEED_SLICE, "at the approach")
	var a1: int = _index_of(flow, "a1")
	_check(a1 >= 0 and flow.get_node_preview(a1)["kind"] == "rest", "a1 is the rest (prepare)")
	await _play(flow, _index_of(flow, "a2"))
	_check(flow.get_rule_state()["gauge"] == 4, "gamble miniboss: heat 3 -> 4 (clamped)")
	var pw: Dictionary = flow.get_node_preview(int(flow.get_available_nodes()[0]["node_index"]))
	_check(pw["slot"] == "warden" and int(pw["gauge"]) == 4, "warden preview at heat 4")
	var cw: RunController = await _play(flow, int(flow.get_available_nodes()[0]["node_index"]))
	var surge: Dictionary = _trait_params(_view(cw), "vent_surge")
	_check(not surge.is_empty() and float(surge.get("interval_sec", 0)) == 7.0 and float(surge.get("first_delay_sec", 0)) == 10.0 and float(surge.get("vents", 0)) == 2.0, "warden hook at heat >= 3 (B1 2026-11-12): vent_surge every 7 s, first at 10 s, vents stay 2 (%s)" % str(surge))
	_check(is_equal_approx(_view(cw)._hazards.config_value("vent_interval_sec"), 4.0) and is_equal_approx(_view(cw)._hazards.config_value("vent_tick_damage"), 3.0), "I2 heat 4 warden: vent 4 s, tick 3")
	_check(is_equal_approx(_view(cw)._hazards.config_value("vent_sec"), 2.5) and is_equal_approx(_view(cw)._hazards.config_value("vent_warn_sec"), 1.0), "I2 heat 4 warden: eruptions 2.5 s, warning 1.0 s (B1)")
	_check(flow.get_phase() == GameFlow.Phase.WORLD_MAP and flow.get_floor() == 2 and flow.get_region_offer() == (["desert"] as Array[String]), "warden spared -> floor 3 offers desert")
	flow.choose_region("desert")
	_check(not flow.get_run().is_v2_region() and flow.get_rule_state().is_empty() and flow.get_phase() == GameFlow.Phase.MAP, "desert is v1 again, no rule state")
	await _drop_main(holder[0])

	# Forge (seed 28: treasure lane with a forge at L1.4 after the hub).
	var store2: ProgressStore = ProgressStore.memory_store()
	var main2: Node = await _new_main(store2, SEED_FORGE)
	var flow2: GameFlow = main2.get_node("GameFlow") as GameFlow
	flow2.start_requested()
	flow2.character_chosen(HERO)
	flow2.choose_region("ch1")
	await _walk_region(flow2)
	flow2.choose_region("hellfire")
	var g2: MapGraph = flow2.get_run().graph
	var forge_id: String = ""
	for id: String in g2.node_ids():
		if g2.nodes[id]["kind"] == "forge":
			forge_id = id
	_check(not forge_id.is_empty(), "seed 28 map holds a forge (%s)" % forge_id)
	if not forge_id.is_empty():
		var lane: String = str(g2.nodes[forge_id]["lane"])
		await _play(flow2, 0)
		await _play(flow2, _index_of(flow2, lane + ".1"))
		await _play(flow2, _index_of(flow2, lane + ".2"))
		await _play(flow2, int(flow2.get_available_nodes()[0]["node_index"]))
		var fi: int = _index_of(flow2, forge_id)
		_check(fi >= 0 and flow2.choose_node(fi) and flow2.is_forge_open() and flow2.get_phase() == GameFlow.Phase.FORGE, "forge opens")
		var ink: Array[String] = flow2.get_ink_offer()
		_check(ink.size() == 2 and flow2.forge_free_removal_left(), "forge: two inks offered, free removal available")
		var tokens: int = flow2.get_run().shape_removals
		var removable: String = ""
		for sid: String in PieceDeck.active_ids(flow2.get_run().piece_deck, RunSession.piece_library()):
			if bool(flow2.get_run().can_remove_shape(sid, false)["ok"]):
				removable = sid
				break
		_check(not removable.is_empty() and flow2.remove_shape(removable) and flow2.get_run().shape_removals == tokens and not flow2.forge_free_removal_left(), "forge: one free removal spends no token")
		flow2.choose_ink(ink[0])
		_check(not flow2.has_ink_offer(), "forge: ink applied")
		flow2.forge_leave()
		_check(flow2.get_phase() == GameFlow.Phase.MAP and flow2.get_run().cleared_ids().has(forge_id), "forge_leave completes the node")
	await _drop_main(main2)
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)

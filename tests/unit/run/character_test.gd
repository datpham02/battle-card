extends SceneTree
## Story 018 part 1 scratch test (headless). Real scene via GameFlow.set_character + enter_test_floor
## (which applies the selected character to the controller). PASS/FAIL + FAILS=n.

const CFG: String = "res://tests/fixtures/fast_run.json"

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _passive(id: String, params: Dictionary) -> BasePassive:
	var p: BasePassive = PassiveRegistry.create(id)
	p.setup({}, params)
	return p


# Builds a flow with an optional character and returns {flow, main, rc, view}.
func _start(character: String) -> Dictionary:
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	if not character.is_empty():
		flow.set_character(character)
	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file(CFG))
	await process_frame
	var view := rc.get_battle().get_node("CombatView") as CombatView
	return {"main": main, "flow": flow, "rc": rc, "view": view}


func _initialize() -> void:
	# ---- config
	var cc: CharacterConfig = CharacterConfig.load_from_file()
	_check("5 characters (Story 037 adds tho_san, giao_si)", cc.ids() == (["kiem_si", "phap_su", "sat_thu", "tho_san", "giao_si"] as Array[String]), str(cc.ids()))
	_check("5 unlocked without an unlock source", cc.unlocked_ids().size() == 5)
	_check("default kiem_si", cc.default_id() == "kiem_si")
	for id: String in cc.ids():
		_check("deck of %s has 6" % id, cc.deck_of(id).size() == 6)
	_check("phap_su deck", cc.deck_of("phap_su") == (["kiem_khi", "hoa_xa", "hoa_tinh", "hoa_tinh", "hoa_tran", "bang_phong"] as Array[String]))
	# F2 / OD-1 (2026-11-13): phap_su max_hp 210 -> 170 so the "frail" description matches the number.
	_check("get_character copy / unknown", cc.get_character("nope").is_empty() and int(cc.get_character("phap_su")["max_hp"]) == 170)
	var bad: CharacterConfig = CharacterConfig.from_dictionary({"characters": [
		{"id": "a", "max_hp": -5, "step_cooldown_mult": 0, "starter_deck": ["kiem_khi", "zzz"]},
		{"id": "a", "max_hp": 50, "starter_deck": ["kiem_khi"]},
		{"id": "b", "starter_deck": []},
	]})
	_check("duplicate dropped", bad.ids() == (["a", "b"] as Array[String]), str(bad.ids()))
	_check("unknown card dropped", bad.deck_of("a") == (["kiem_khi"] as Array[String]), str(bad.deck_of("a")))
	_check("clamps", float(bad.get_character("a")["max_hp"]) == 1.0 and float(bad.get_character("a")["step_cooldown_mult"]) == 1.0)
	_check("empty deck -> default", bad.deck_of("b") == SkillConfig.load_from_file().default_deck)
	_check("missing file -> built-in", CharacterConfig.load_from_file("res://nope.json").ids().size() == 1)
	# ---- passives
	var wide: BasePassive = _passive("wide_caster", {"min_cells": 5, "duration_mult": 0.85})
	_check("wide 5", is_equal_approx(wide.modify_swing_duration(5, 2.0), 1.7))
	_check("wide 6", is_equal_approx(wide.modify_swing_duration(6, 2.0), 1.7))
	_check("wide 4 unchanged", wide.modify_swing_duration(4, 2.0) == 2.0)
	var quick: BasePassive = _passive("quick_blade", {"max_cells": 3, "damage_mult": 1.25})
	_check("quick 3", is_equal_approx(quick.modify_damage(3, 18.0), 22.5))
	_check("quick 2", is_equal_approx(quick.modify_damage(2, 12.0), 15.0))
	_check("quick 4 unchanged", quick.modify_damage(4, 24.0) == 24.0)
	_check("second_wind 10", _passive("second_wind", {"heal_after_match": 10}).on_match_won() == 10.0)
	_check("registry unknown null", PassiveRegistry.create("zzz") == null)
	# ---- baseline (no character)
	var base: Dictionary = await _start("")
	var bv: CombatView = base["view"]
	var base_cd: float = bv.get_player_step_cooldown()
	var base_boss_cd: float = float(bv.get_boss().get_mover().get("_cooldown_sec"))
	_check("no character: max hp from combat.json", bv.get_state().player_max_hp == CombatConfig.load_from_file().player_max_hp)
	_check("no character: no passive", bv.get_passive() == null and bv.get_passive_heal() == 0.0)
	_check("no character: focus from cards.json", bv.get_focus().get_max_sec() == SkillConfig.load_from_file().focus_max_sec)
	(base["main"] as Node).queue_free()
	await process_frame
	# ---- phap_su
	var ps: Dictionary = await _start("phap_su")
	var pv: CombatView = ps["view"]
	# F2 / OD-1 (2026-11-13): 210 -> 170. This asserts the number reaches the live match, not just the config.
	_check("phap_su max hp 170 (Story 040, F2/OD-1)", pv.get_state().player_max_hp == 170.0 and pv.get_player_hp() == 170.0)
	_check("phap_su focus 5.0", pv.get_focus().get_max_sec() == 5.0)
	_check("phap_su deck = starter ids", pv.get_deck().to_array() == cc.deck_of("phap_su"))
	_check("phap_su step x1.0", is_equal_approx(pv.get_player_step_cooldown(), base_cd))
	_check("phap_su passive wide_caster", pv.get_passive() != null and pv.get_passive().get_id() == "wide_caster")
	# 4+-cell player swing duration is 0.75x (Story 026: min_cells 4, duration_mult 0.75), 3-cell unchanged, boss actor unaffected
	var cut: CutConfig = pv.get_cut_config()
	var cells5: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1)]
	var cells3: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	pv.get_cut_actor().begin_swing(cells5, "kiem_khi", true)
	_check("5-cell player swing 0.75x", is_equal_approx(pv.get_cut_actor().get_duration(), cut.swing_duration(5) * 0.75), "%f vs %f" % [pv.get_cut_actor().get_duration(), cut.swing_duration(5) * 0.75])
	pv.get_cut_actor().cancel()
	pv.get_cut_actor().begin_swing(cells5.slice(0, 4), "kiem_khi", true)
	_check("4-cell player swing 0.75x", is_equal_approx(pv.get_cut_actor().get_duration(), cut.swing_duration(4) * 0.75), "%f vs %f" % [pv.get_cut_actor().get_duration(), cut.swing_duration(4) * 0.75])
	pv.get_cut_actor().cancel()
	pv.get_cut_actor().begin_swing(cells3, "kiem_khi", true)
	_check("3-cell player swing unchanged", is_equal_approx(pv.get_cut_actor().get_duration(), cut.swing_duration(3)))
	pv.get_cut_actor().cancel()
	var boss_actor: CutActor = pv.get_boss().get_actor()
	boss_actor.begin_swing(cells5, "kiem_khi", false)
	_check("boss 5-cell swing unaffected", is_equal_approx(boss_actor.get_duration(), cut.swing_duration(5) * boss_actor.duration_mult))
	boss_actor.cancel()
	(ps["main"] as Node).queue_free()
	await process_frame
	# ---- sat_thu
	var st: Dictionary = await _start("sat_thu")
	var sv: CombatView = st["view"]
	_check("sat_thu max hp 180", sv.get_state().player_max_hp == 180.0)
	_check("sat_thu step x0.9", is_equal_approx(sv.get_player_step_cooldown(), base_cd * 0.9), "%f vs %f" % [sv.get_player_step_cooldown(), base_cd * 0.9])
	var boss_cd: float = float(sv.get_boss().get_mover().get("_cooldown_sec"))
	_check("sat_thu boss step cooldown unchanged", is_equal_approx(boss_cd, base_boss_cd), "%f vs %f" % [boss_cd, base_boss_cd])
	# damage through the real arbiter path: player swing, boss standing inside
	var hit3: float = _player_hit(sv, 3)
	var hit4: float = _player_hit(sv, 4)
	var hit5: float = _player_hit(sv, 5)
	var base3: float = sv.get_cut_config().slash_damage(3)
	var base4: float = sv.get_cut_config().slash_damage(4)
	var base5: float = sv.get_cut_config().slash_damage(5)
	_check("sat_thu 3-cell hit 1.4x", is_equal_approx(hit3, base3 * 1.4), "%f vs %f" % [hit3, base3 * 1.4])
	# TD-027 (2026-10-26): quick_blade max_cells 3 -> 4, so 4 cells get the bonus and 5 cells do not.
	_check("sat_thu 4-cell hit 1.4x", is_equal_approx(hit4, base4 * 1.4), "%f vs %f" % [hit4, base4 * 1.4])
	_check("sat_thu 5-cell hit unchanged", is_equal_approx(hit5, base5), "%f vs %f" % [hit5, base5])
	(st["main"] as Node).queue_free()
	await process_frame
	# ---- second_wind through the run
	var kv: Dictionary = await _start("kiem_si")
	var rc: RunController = kv["rc"]
	var view: CombatView = kv["view"]
	_check("kiem_si max hp 200", view.get_state().player_max_hp == 200.0)
	for _i: int in 200:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	view.get_state().damage(CombatState.Side.PLAYER, 40.0)
	view.get_state().damage(CombatState.Side.ENEMY, 999999.0)
	var heal: float = rc.get_config().heal_between_matches
	for _i: int in 300:
		if rc.get_state().get_phase() == RunState.Phase.BETWEEN:
			break
		await process_frame
	_check("BETWEEN reached", rc.get_state().get_phase() == RunState.Phase.BETWEEN)
	_check("passive heal 20", view.get_passive_heal() == 20.0)
	_check("carried = min(hp + heal + 20, max)", is_equal_approx(rc.get_state().get_carried_hp(), minf(160.0 + heal + 20.0, 200.0)), str(rc.get_state().get_carried_hp()))
	(kv["main"] as Node).queue_free()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# Resolves a player swing over [param count] cells with the boss standing inside; returns its damage.
func _player_hit(view: CombatView, count: int) -> float:
	var state: CombatState = view.get_state()
	var cells: Array[Vector2i] = []
	for i: int in count:
		cells.append(state.enemy_cell + Vector2i(0, 0) if i == 0 else Vector2i(state.enemy_cell.x, 100 + i))
	var got: Array[float] = [-1.0]
	var cb: Callable = func(side: int, result: Dictionary) -> void:
		if side == CombatState.Side.PLAYER:
			got[0] = float(result["damage"])
	view.get_arbiter().swing_resolved.connect(cb)
	view.get_cut_actor().begin_swing(cells, "kiem_khi", true)
	view.get_arbiter().tick(view.get_cut_actor().get_time_left() + 0.01)
	view.get_arbiter().swing_resolved.disconnect(cb)
	return got[0]

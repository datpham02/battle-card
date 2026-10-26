extends SceneTree
## Story 021 Part 1 scratch test (headless): signature charge, host API on CombatView, the three
## signatures' numbers, registry / CharacterConfig validation, v2 behaviour without a signature.
## Prints PASS/FAIL lines and FAILS=n. No frames are processed until the very end, so CombatView's
## _process never runs: time is injected by hand. Story 030: Thien Hoa ignites the lit formation then detonates;
## Anh Bo multiplies every small cast (no pin needed).

const BIG_HP: float = 1000000.0
const EPS: float = 0.001

var fails: int = 0
var _cc: CharacterConfig


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


# A CombatView in the tree for [param character] (a cleaned CharacterConfig dictionary or any dict).
func _view(character: Dictionary) -> CombatView:
	var v := CombatView.new()
	v.match_params = {"character": character, "boss_max_hp": BIG_HP, "player_hp": -1.0}
	v.drops_seed = 7
	v.freeze_time = true
	root.add_child(v)
	await process_frame
	v.freeze_time = false
	return v


func _drop(v: CombatView) -> void:
	root.remove_child(v)
	v.free()


# Casts [param skill] over [param count] cells, the boss's cell first, resolves it, returns the result.
func _cast(v: CombatView, count: int, skill: String = "kiem_khi") -> Dictionary:
	var state: CombatState = v.get_state()
	var cells: Array[Vector2i] = []
	for i: int in count:
		cells.append(state.enemy_cell if i == 0 else Vector2i(state.enemy_cell.x, 100 + i))
	return _cast_cells(v, cells, skill)


# Story 029: casts [param skill] over exactly [param cells], resolves it, returns the result.
func _cast_cells(v: CombatView, cells: Array[Vector2i], skill: String = "kiem_khi") -> Dictionary:
	var got: Array[Dictionary] = [{}]
	var cb: Callable = func(side: int, result: Dictionary) -> void:
		if side == CombatState.Side.PLAYER:
			got[0] = result
	v.get_arbiter().swing_resolved.connect(cb)
	v._begin_cut(skill, cells)
	v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	v.get_arbiter().swing_resolved.disconnect(cb)
	return got[0]


func _per_cell(v: CombatView, skill: String = "kiem_khi") -> float:
	return float(v.get_skill_config().resolved(skill, v.get_card_level(skill))["damage_per_cell"])


func _initialize() -> void:
	_cc = CharacterConfig.load_from_file()
	await _test_charge_and_host()
	await _test_locks()
	await _test_tram()
	await _test_thien_hoa()
	await _test_anh_bo()
	await _test_unknown_and_none()
	await _test_character_config()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _test_charge_and_host() -> void:
	var v: CombatView = await _view(_cc.get_character("kiem_si"))
	_check("kiem_si has tram", v.get_signature() != null and v.get_signature().get_id() == "tram")
	_check("charge starts at 0", v.get_signature_charge() == 0.0 and not v.is_signature_ready())
	_check("name translated", v.get_signature_name() == tr("signature.tram.name") and v.get_signature_name() != "signature.tram.name", v.get_signature_name())
	_check("duration 3 / time_left 0 / inactive", v.get_signature_duration() == 3.0 and v.get_signature_time_left() == 0.0 and not v.is_signature_active())
	# Story 029: the charge is the formation map (lit real enemy cells / total); off-board cells do not count.
	var total: float = float(v.get_formation().total())
	_cast(v, 5)
	_check("1 real enemy cell lit -> 1/total", _near(v.get_signature_charge(), 1.0 / total) and not v.is_signature_ready())
	_cast_cells(v, v.get_grid().enemy_cells())
	_check("whole enemy half lit -> full and ready", v.get_signature_charge() == 1.0 and v.is_signature_ready())
	_cast(v, 4)
	_check("charge stays 1 while ready", v.get_signature_charge() == 1.0)
	var fired: Array[String] = []
	v.signature_activated.connect(func(id: String) -> void: fired.append(id))
	var ended: Array[String] = []
	v.signature_ended.connect(func(id: String) -> void: ended.append(id))
	_check("can activate", v.can_activate_signature())
	_check("activate -> true", v.activate_signature())
	_check("signal signature_activated(tram)", fired == (["tram"] as Array[String]))
	_check("activate clears ready and resets the map (Story 029 Phần D)", v.get_signature_charge() == 0.0 and v.get_formation().lit_count() == 0 and not v.is_signature_ready())
	_check("active, 3 s left", v.is_signature_active() and _near(v.get_signature_time_left(), 3.0))
	_check("activate again -> false", not v.activate_signature() and fired.size() == 1)
	v._tick_signature(1.0)
	_check("ticked 1 s -> 2 left", _near(v.get_signature_time_left(), 2.0) and ended.is_empty())
	v._tick_signature(2.5)
	_check("ended after 3 s + signal", not v.is_signature_active() and ended == (["tram"] as Array[String]))
	v.debug_set_signature_charge(0.5)
	_check("debug charge 0.5 -> round(total/2) cells lit", _near(v.get_signature_charge(), float(roundi(0.5 * total)) / total) and not v.is_signature_ready())
	v.debug_set_signature_charge(1.0)
	_check("debug charge 1.0 ready", v.is_signature_ready())
	var sig: BaseSignature = v.get_signature()
	_drop(v)
	_check("teardown on exit_tree", sig.get_params().is_empty())
	var v2: CombatView = await _view(_cc.get_character("kiem_si"))
	_check("new match -> charge 0 (no carry)", v2.get_signature_charge() == 0.0)
	_drop(v2)


func _test_locks() -> void:
	var v: CombatView = await _view(_cc.get_character("kiem_si"))
	_check("not ready -> cannot activate", not v.can_activate_signature() and not v.activate_signature())
	v.debug_set_signature_charge(1.0)
	v.freeze_time = true
	_check("paused -> cannot", not v.can_activate_signature() and not v.activate_signature())
	v.freeze_time = false
	_check("unpaused -> can", v.can_activate_signature())
	v.get_cut_flow().open_menu(["A"], [v.get_state().player_cell])
	_check("menu open -> cannot", not v.can_activate_signature() and not v.activate_signature())
	_drop(v)
	v = await _view(_cc.get_character("kiem_si"))
	v.debug_set_signature_charge(1.0)
	v.get_focus().try_start()
	_check("focus active -> cannot", v.get_focus().is_active() and not v.can_activate_signature())
	v.get_focus().end("test")
	_check("focus ended -> can", v.can_activate_signature())
	v.get_state().damage_player(BIG_HP)
	_check("dead -> cannot", not v.can_activate_signature() and not v.activate_signature())
	_check("charge untouched by refused activations", v.get_signature_charge() == 1.0)
	_drop(v)


func _test_tram() -> void:
	var v: CombatView = await _view(_cc.get_character("kiem_si"))
	var state: CombatState = v.get_state()
	var per: float = _per_cell(v)
	var r: Dictionary = _cast(v, 3)
	_check("tram inactive: 3 cells plain", _near(float(r["damage"]), per * 3.0))
	v.debug_set_signature_charge(1.0)
	v.activate_signature()
	state.set_player_hp(50.0)
	var before: float = state.enemy_hp
	r = _cast(v, 3)
	_check("tram: 3 cells count as 6", _near(float(r["damage"]), per * 6.0), str(r["damage"]))
	_check("tram: swing still covers 3 cells", (r["cells"] as Array).size() == 3)
	_check("tram: boss took the doubled damage", _near(before - state.enemy_hp, per * 6.0))
	_check("tram: heals 20 %", _near(state.player_hp, 50.0 + 0.2 * per * 6.0), str(state.player_hp))
	state.set_player_hp(state.player_max_hp - 1.0)
	_cast(v, 3)
	_check("tram: heal clamped at max HP", state.player_hp == state.player_max_hp)
	var miss_hp: float = state.player_hp
	state.set_player_hp(50.0)
	# A miss heals nothing: swing over cells not containing the boss.
	var cells: Array[Vector2i] = [Vector2i(state.enemy_cell.x, 300)]
	v._begin_cut("kiem_khi", cells)
	v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	_check("tram: miss heals nothing", state.player_hp == 50.0, str(miss_hp))
	v._tick_signature(3.0)
	r = _cast(v, 3)
	_check("tram expired: plain again, no heal", _near(float(r["damage"]), per * 3.0) and state.player_hp == 50.0)
	_drop(v)
	# Pure hook check with explicit params.
	var t: BaseSignature = SignatureRegistry.create("tram")
	t.setup({}, {"duration_sec": 3.0, "cell_mult": 2.0, "lifesteal": 0.2})
	_check("tram inactive modify_cells unchanged", t.modify_cells(4) == 4)
	t.activate()
	_check("tram active modify_cells x2", t.modify_cells(4) == 8 and t.step_cooldown_scale() == 1.0)


func _test_thien_hoa() -> void:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	var st := StatusEffects.new()
	cfg.configure_status(st)
	var grid := BoardGrid.new(3, 3)
	var dummy := CombatState.new(grid, 100.0, 100.0, BoardGrid.NO_CELL, BoardGrid.NO_CELL)
	var a: Vector2i = grid.enemy_cells()[0]
	var b: Vector2i = grid.enemy_cells()[1]
	st.ignite([a, b], 2.0, 0.5, 1.5)
	_check("remaining_burn_damage fresh = left/tick*dmg", _near(st.remaining_burn_damage(a), 6.0))
	_check("remaining_burn_damage non-burning = 0", st.remaining_burn_damage(Vector2i(9, 9)) == 0.0)
	st.tick(0.5, dummy)
	_check("remaining_burn_damage after 0.5 s", _near(st.remaining_burn_damage(a), 4.5))
	st.ignite([a], 2.0, 0.5, 1.5)
	var expect_stacked: float = (maxf(1.5, 2.0) + cfg.burn_stack_extend_sec) / 0.5 * (1.5 + cfg.burn_stack_tick_bonus)
	_check("remaining_burn_damage with 2 stacks", _near(st.remaining_burn_damage(a), expect_stacked), str(st.remaining_burn_damage(a)))
	var outs: Array[Vector2i] = []
	st.cell_burned_out.connect(func(c: Vector2i) -> void: outs.append(c))
	_check("clear_burn(subset)", st.clear_burn([a]) == 1 and not st.is_burning(a) and st.is_burning(b) and outs == ([a] as Array[Vector2i]))
	_check("clear_burn() all", st.clear_burn() == 1 and st.burning_cells().is_empty())
	_check("clear_burn on nothing = 0", st.clear_burn() == 0)
	# Through the host (Story 030, order 2026-10-25): the burn that ALREADY exists detonates first (only it
	# counts), the burn cards reset, THEN every lit enemy cell is set on fire with the configured params
	# (a lasting fire, not detonated in the same use); the player-half burn is untouched.
	var v: CombatView = await _view(_cc.get_character("phap_su"))
	var state: CombatState = v.get_state()
	var status: StatusEffects = v.get_status()
	var g: BoardGrid = v.get_grid()
	var p1: Vector2i = g.player_cells()[0]
	var pre: Vector2i = g.enemy_cells()[0]
	status.ignite([p1], 2.0, 0.5, 1.5)
	status.ignite([pre], 2.0, 0.5, 1.5)
	var pre_burn: float = status.remaining_burn_damage(pre)
	var cds: SkillCooldowns = v.get_skill_cooldowns()
	cds.start("hoa_tran", 8.0)
	cds.start("hoa_tinh", 7.0)
	cds.start("chan_phong", 6.0)
	var ended: Array[String] = []
	v.signature_ended.connect(func(id: String) -> void: ended.append(id))
	var params: Dictionary = _cc.get_character("phap_su")["signature"]["params"]
	var expect_one: float = _fresh_cell_burn(cfg, params)
	var n_enemy: int = g.enemy_cells().size()
	# debug_set_signature_charge(1.0) only sets the ready flag: light the map the way play does.
	v.get_formation().cover(g.enemy_cells())
	v.debug_set_signature_charge(1.0)
	var before: float = state.enemy_hp
	_check("thien_hoa: duration 0 (instant)", v.get_signature_duration() == 0.0)
	_check("thien_hoa: activate", v.activate_signature())
	_check("thien_hoa: boss takes detonate_mult x ONLY the pre-existing burn", _near(before - state.enemy_hp, float(params["detonate_mult"]) * pre_burn), str(before - state.enemy_hp))
	_check("thien_hoa: last_damage matches", _near((v.get_signature() as ThienHoaSignature).last_damage(), before - state.enemy_hp))
	_check("thien_hoa: every enemy cell was ignited", (v.get_signature() as ThienHoaSignature).last_ignited_count() == n_enemy)
	var all_fresh: bool = true
	for c: Vector2i in g.enemy_cells():
		all_fresh = all_fresh and status.is_burning(c) and _near(status.remaining_burn_damage(c), expect_one)
	_check("thien_hoa: after activate every enemy cell burns with the configured fire (pre cell re-lit fresh, not stacked)", all_fresh, str(status.remaining_burn_damage(pre)))
	_check("thien_hoa: player burn kept", status.is_burning(p1))
	_check("thien_hoa: burn cards reset", cds.is_ready("hoa_tran") and cds.is_ready("hoa_tinh"))
	_check("thien_hoa: non-burn cooldown kept", _near(cds.remaining("chan_phong"), 6.0))
	_check("thien_hoa: instant -> never active, ended at once", not v.is_signature_active() and ended == (["thien_hoa"] as Array[String]))
	_check("thien_hoa: not ready after, map reset", not v.is_signature_ready() and v.get_signature_charge() < 1.0 and v.get_formation().lit_count() == 0)
	_drop(v)
	# Host: nothing burning before -> no detonation damage, but the board is on fire afterwards.
	v = await _view(_cc.get_character("phap_su"))
	g = v.get_grid()
	v.get_formation().cover(g.enemy_cells())
	v.debug_set_signature_charge(1.0)
	before = v.get_state().enemy_hp
	v.activate_signature()
	_check("thien_hoa host: no old burn -> 0 damage at once", _near(before - v.get_state().enemy_hp, 0.0) and (v.get_signature() as ThienHoaSignature).last_damage() == 0.0, str(before - v.get_state().enemy_hp))
	_check("thien_hoa host: no old burn -> whole half on fire", v.get_status().burning_cells().size() == g.enemy_cells().size())
	_drop(v)
	# Pure hook with a real FormationMap + StatusEffects (Story 030).
	var tp: Dictionary = {"burn_stacks": 1, "burn_duration_sec": 2.0, "burn_tick_sec": 0.5, "burn_damage_per_tick": 1.5, "detonate_mult": 2.0}
	var rig: Dictionary = _th_rig(cfg, tp, true)
	var rg: BoardGrid = rig["grid"]
	var lit: Array[Vector2i] = [rg.enemy_cells()[0], rg.enemy_cells()[2]]
	(rig["formation"] as FormationMap).cover(lit)
	var ignited: Array[Vector2i] = []
	(rig["status"] as StatusEffects).cell_ignited.connect(func(c: Vector2i) -> void: ignited.append(c))
	var hp0: float = (rig["state"] as CombatState).enemy_hp
	(rig["sig"] as ThienHoaSignature).activate()
	var dealt: float = hp0 - (rig["state"] as CombatState).enemy_hp
	_check("thien_hoa pure: ignites exactly the lit cells, in map order", ignited == lit, str(ignited))
	_check("thien_hoa pure: dark cells never ignited", not ignited.has(rg.enemy_cells()[1]))
	_check("thien_hoa pure: fresh fire is NOT detonated (0 damage)", _near(dealt, 0.0) and (rig["sig"] as ThienHoaSignature).last_damage() == 0.0, str(dealt))
	var burning: Array[Vector2i] = (rig["status"] as StatusEffects).burning_cells()
	_check("thien_hoa pure: the lit cells keep burning afterwards", burning.size() == 2 and burning.has(lit[0]) and burning.has(lit[1]))
	_check("thien_hoa pure: each lit cell holds 2 s / 0.5 / 1.5 = 6", _near((rig["status"] as StatusEffects).remaining_burn_damage(lit[0]), 6.0) and _near((rig["status"] as StatusEffects).get_burn_left(lit[1]), 2.0))
	_check("thien_hoa pure: last_ignited_count 2", (rig["sig"] as ThienHoaSignature).last_ignited_count() == 2)
	# Detonate BEFORE ignite: old burn on a dark cell detonates and is cleared; the lit cell is set on fire after.
	rig = _th_rig(cfg, tp, true)
	rg = rig["grid"]
	(rig["formation"] as FormationMap).cover([rg.enemy_cells()[0]] as Array[Vector2i])
	(rig["status"] as StatusEffects).ignite([rg.enemy_cells()[1]] as Array[Vector2i], 2.0, 0.5, 1.5)
	hp0 = (rig["state"] as CombatState).enemy_hp
	(rig["sig"] as ThienHoaSignature).activate()
	dealt = hp0 - (rig["state"] as CombatState).enemy_hp
	_check("thien_hoa pure: only the old burn detonates (2 x 6)", _near(dealt, 2.0 * 6.0), str(dealt))
	_check("thien_hoa pure: old dark-cell burn cleared, lit cell burning", not (rig["status"] as StatusEffects).is_burning(rg.enemy_cells()[1]) and (rig["status"] as StatusEffects).is_burning(rg.enemy_cells()[0]))
	# Old burn on a LIT cell: detonated (2 x 6), then the cell is re-lit fresh (6 left, not a stacked re-ignite).
	rig = _th_rig(cfg, tp, true)
	rg = rig["grid"]
	var both: Array[Vector2i] = [rg.enemy_cells()[0]]
	(rig["formation"] as FormationMap).cover(both)
	(rig["status"] as StatusEffects).ignite(both, 2.0, 0.5, 1.5)
	(rig["status"] as StatusEffects).ignite(both, 2.0, 0.5, 1.5)
	var stacked_old: float = (rig["status"] as StatusEffects).remaining_burn_damage(both[0])
	hp0 = (rig["state"] as CombatState).enemy_hp
	(rig["sig"] as ThienHoaSignature).activate()
	dealt = hp0 - (rig["state"] as CombatState).enemy_hp
	_check("thien_hoa pure: lit + already burning -> detonates the old (stacked) burn", _near(dealt, 2.0 * stacked_old), str(dealt))
	_check("thien_hoa pure: lit + already burning -> re-lit fresh afterwards", _near((rig["status"] as StatusEffects).remaining_burn_damage(both[0]), 6.0), str((rig["status"] as StatusEffects).remaining_burn_damage(both[0])))
	# Params: stacks / duration / tick / damage are the configured ones (compared with a reference ignite).
	var tp2: Dictionary = {"burn_stacks": 3, "burn_duration_sec": 3.0, "burn_tick_sec": 0.25, "burn_damage_per_tick": 0.5, "detonate_mult": 1.5}
	rig = _th_rig(cfg, tp2, true)
	rg = rig["grid"]
	var one: Array[Vector2i] = [rg.enemy_cells()[1]]
	(rig["formation"] as FormationMap).cover(one)
	var ref := StatusEffects.new()
	cfg.configure_status(ref)
	for _i: int in 3:
		ref.ignite(one, 3.0, 0.25, 0.5)
	var single := StatusEffects.new()
	cfg.configure_status(single)
	single.ignite(one, 3.0, 0.25, 0.5)
	(rig["sig"] as ThienHoaSignature).activate()
	var got: StatusEffects = rig["status"]
	_check("thien_hoa pure: 3 stacks of 3 s / 0.25 / 0.5 left on the cell", _near(got.remaining_burn_damage(one[0]), ref.remaining_burn_damage(one[0])) and _near(got.get_burn_left(one[0]), ref.get_burn_left(one[0])), str(got.remaining_burn_damage(one[0])))
	_check("thien_hoa pure: stacks matter when stacking is configured", cfg.burn_max_stacks < 2 or ref.remaining_burn_damage(one[0]) > single.remaining_burn_damage(one[0]))
	# The fire ticks on a boss standing in it (DoT): 0.5 s on a 0.5 s / 1.5 cell -> 1.5.
	rig = _th_rig(cfg, tp, true, rg.enemy_cells()[0])
	rg = rig["grid"]
	(rig["formation"] as FormationMap).cover([rg.enemy_cells()[0]] as Array[Vector2i])
	(rig["sig"] as ThienHoaSignature).activate()
	hp0 = (rig["state"] as CombatState).enemy_hp
	(rig["status"] as StatusEffects).tick(0.5, rig["state"] as CombatState)
	_check("thien_hoa pure: the boss standing in the fire takes burn_damage_per_tick per tick", _near(hp0 - (rig["state"] as CombatState).enemy_hp, 1.5), str(hp0 - (rig["state"] as CombatState).enemy_hp))
	rig = _th_rig(cfg, {"burn_stacks": 0, "burn_duration_sec": 2.0, "burn_tick_sec": 0.5, "burn_damage_per_tick": 1.5, "detonate_mult": 2.0}, true)
	(rig["formation"] as FormationMap).cover((rig["grid"] as BoardGrid).enemy_cells())
	(rig["sig"] as ThienHoaSignature).activate()
	_check("thien_hoa pure: burn_stacks 0 -> nothing ignited, no damage", (rig["sig"] as ThienHoaSignature).last_ignited_count() == 0 and (rig["sig"] as ThienHoaSignature).last_damage() == 0.0 and (rig["status"] as StatusEffects).burning_cells().is_empty())
	# Fallback numbers when the params are absent (mirror characters.json except detonate_mult 1).
	rig = _th_rig(cfg, {}, true)
	var fb_cell: Vector2i = (rig["grid"] as BoardGrid).enemy_cells()[0]
	(rig["formation"] as FormationMap).cover([fb_cell] as Array[Vector2i])
	(rig["status"] as StatusEffects).ignite([fb_cell] as Array[Vector2i], 2.0, 0.5, 1.5)
	(rig["sig"] as ThienHoaSignature).activate()
	_check("thien_hoa pure: fallbacks detonate x1 (6), re-light the cell with 2 s / 0.5 / 1.5", _near((rig["sig"] as ThienHoaSignature).last_damage(), 6.0) and _near((rig["status"] as StatusEffects).remaining_burn_damage(fb_cell), 6.0), str((rig["sig"] as ThienHoaSignature).last_damage()))
	# No formation in the ctx: old behaviour (detonate what already burns; cooldown reset still runs).
	rig = _th_rig(cfg, tp, false)
	rg = rig["grid"]
	(rig["status"] as StatusEffects).ignite([rg.enemy_cells()[0], rg.enemy_cells()[1]] as Array[Vector2i], 2.0, 0.5, 1.5)
	(rig["status"] as StatusEffects).ignite([rg.player_cells()[0]] as Array[Vector2i], 2.0, 0.5, 1.5)
	hp0 = (rig["state"] as CombatState).enemy_hp
	(rig["sig"] as ThienHoaSignature).activate()
	dealt = hp0 - (rig["state"] as CombatState).enemy_hp
	_check("thien_hoa pure no formation: only the existing burn detonates (2 x 12)", _near(dealt, 24.0) and (rig["sig"] as ThienHoaSignature).last_ignited_count() == 0, str(dealt))
	_check("thien_hoa pure no formation: player burn kept, no enemy fire left", (rig["status"] as StatusEffects).is_burning(rg.player_cells()[0]) and (rig["status"] as StatusEffects).burning_cells().size() == 1)
	rig = _th_rig(cfg, tp, false)
	hp0 = (rig["state"] as CombatState).enemy_hp
	(rig["sig"] as ThienHoaSignature).activate()
	_check("thien_hoa pure no formation, no burn: nothing happens", (rig["state"] as CombatState).enemy_hp == hp0 and (rig["status"] as StatusEffects).burning_cells().is_empty())
	# Formation present but nothing lit: same as no formation.
	rig = _th_rig(cfg, tp, true)
	rg = rig["grid"]
	(rig["status"] as StatusEffects).ignite([rg.enemy_cells()[0]] as Array[Vector2i], 2.0, 0.5, 1.5)
	hp0 = (rig["state"] as CombatState).enemy_hp
	(rig["sig"] as ThienHoaSignature).activate()
	dealt = hp0 - (rig["state"] as CombatState).enemy_hp
	_check("thien_hoa pure no lit cell: only the old burn (2 x 6), nothing re-lit", _near(dealt, 12.0) and (rig["sig"] as ThienHoaSignature).last_ignited_count() == 0 and (rig["status"] as StatusEffects).burning_cells().is_empty(), str(dealt))
	# Cooldown reset still runs without a formation (host objects give a real SkillConfig).
	v = await _view(_cc.get_character("phap_su"))
	var th: ThienHoaSignature = SignatureRegistry.create("thien_hoa") as ThienHoaSignature
	th.setup({"status": v.get_status(), "grid": v.get_grid(), "state": v.get_state(), "cooldowns": v.get_skill_cooldowns(), "skill_config": v.get_skill_config()}, tp)
	v.get_skill_cooldowns().start("hoa_tran", 8.0)
	th.activate()
	_check("thien_hoa pure no formation: burn cooldown still reset", v.get_skill_cooldowns().is_ready("hoa_tran"))
	_drop(v)


# A pure Thien Hoa rig: configured StatusEffects, a 3x3 board, a real FormationMap (when [param with_formation]),
# the boss on [param enemy_cell] (none by default).
func _th_rig(cfg: CombatConfig, params: Dictionary, with_formation: bool, enemy_cell: Vector2i = BoardGrid.NO_CELL) -> Dictionary:
	var st := StatusEffects.new()
	cfg.configure_status(st)
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, BIG_HP, BIG_HP, BoardGrid.NO_CELL, enemy_cell)
	var ctx: Dictionary = {"status": st, "grid": grid, "state": state}
	var fm: FormationMap = null
	if with_formation:
		fm = FormationMap.new().init(grid.enemy_cells(), 100.0)
		ctx["formation"] = fm
	var sig: ThienHoaSignature = SignatureRegistry.create("thien_hoa") as ThienHoaSignature
	sig.setup(ctx, params)
	return {"status": st, "grid": grid, "state": state, "formation": fm, "sig": sig}


# Remaining burn damage of ONE freshly ignited cell with the configured [param params] and `burn_stacks` ignites.
func _fresh_cell_burn(cfg: CombatConfig, params: Dictionary) -> float:
	var st := StatusEffects.new()
	cfg.configure_status(st)
	var cell := Vector2i(1, 1)
	for _i: int in int(params["burn_stacks"]):
		st.ignite([cell] as Array[Vector2i], float(params["burn_duration_sec"]), float(params["burn_tick_sec"]), float(params["burn_damage_per_tick"]))
	return st.remaining_burn_damage(cell)


func _test_anh_bo() -> void:
	var v: CombatView = await _view(_cc.get_character("sat_thu"))
	var state: CombatState = v.get_state()
	var status: StatusEffects = v.get_status()
	var cfg: CombatConfig = CombatConfig.load_from_file()
	var ghim: float = cfg.pinned_damage_mult
	var quick: float = float(_cc.get_character("sat_thu")["passive"]["params"]["damage_mult"])
	var small: float = float(_cc.get_character("sat_thu")["signature"]["params"]["small_mult"])
	var per: float = _per_cell(v)
	# Pinned, inactive: Ghim x Quick Blade only.
	status.pin(CombatState.Side.ENEMY, 100.0)
	var r: Dictionary = _cast(v, 3)
	_check("anh_bo inactive: pinned 3 cells = per*3*ghim*quick", _near(float(r["damage"]), per * 3.0 * ghim * quick), str(r["damage"]))
	v.debug_set_signature_charge(1.0)
	v.activate_signature()
	_check("anh_bo active 2 s", v.is_signature_active() and _near(v.get_signature_time_left(), 2.0))
	r = _cast(v, 3)
	_check("anh_bo active: pinned 3 cells x small_mult (stacks with Ghim + Quick Blade)", _near(float(r["damage"]), per * 3.0 * ghim * quick * small), str(r["damage"]))
	_check("anh_bo: pin_bonus off (Ghim control-only, Story 023)", not bool(r["pin_bonus"]))
	r = _cast(v, 4)
	# TD-027 (2026-10-26): Quick Blade now reaches 4 cells; Anh Bo small_mult still stops at 3.
	_check("anh_bo active: pinned 4 cells = Ghim x Quick Blade, no small_mult", _near(float(r["damage"]), per * 4.0 * ghim * quick), str(r["damage"]))
	status.clear()
	r = _cast(v, 3)
	_check("anh_bo active: UNPINNED 3 cells x small_mult x Quick Blade (Story 030)", _near(float(r["damage"]), per * 3.0 * quick * small), str(r["damage"]))
	r = _cast(v, 4)
	_check("anh_bo active: unpinned 4 cells = Quick Blade only", _near(float(r["damage"]), per * 4.0 * quick), str(r["damage"]))
	r = _cast(v, 1)
	_check("anh_bo active: unpinned 1 cell x small_mult", _near(float(r["damage"]), per * 1.0 * quick * small), str(r["damage"]))
	# Free steps while active.
	var mover: UnitMover = v.get_mover()
	var dir: Vector2i = Vector2i.ZERO
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if v.get_grid().is_player_cell(state.player_cell + d):
			dir = d
			break
	_check("anh_bo: step accepted", mover.try_step(dir))
	_check("anh_bo: no cooldown after the step", mover.get_cooldown_remaining() == 0.0 and mover.is_ready() and mover.get_cooldown_fraction() == 0.0)
	_check("anh_bo: immediate second step", mover.try_step(-dir))
	v._tick_signature(2.0)
	_check("anh_bo: expired", not v.is_signature_active())
	_check("anh_bo: step after expiry starts cooldown", mover.try_step(dir) and mover.get_cooldown_remaining() > 0.0)
	_check("anh_bo: cooldown equals the board-scaled one", _near(mover.get_cooldown_remaining(), v.get_player_step_cooldown()))
	status.pin(CombatState.Side.ENEMY, 100.0)
	mover.tick(10.0)
	r = _cast(v, 3)
	_check("anh_bo expired: pinned 3 cells back to Ghim x Quick", _near(float(r["damage"]), per * 3.0 * ghim * quick), str(r["damage"]))
	_drop(v)
	# Pure hook (Story 030: no pinned condition any more).
	var s: BaseSignature = SignatureRegistry.create("anh_bo")
	s.setup({}, {"duration_sec": 2.0, "small_mult": 2.5, "small_cells": 3})
	_check("anh_bo hook inactive", s.modify_damage("x", 3, 10.0, true) == 10.0 and s.modify_damage("x", 3, 10.0, false) == 10.0 and s.step_cooldown_scale() == 1.0)
	s.activate()
	_check("anh_bo hook active pinned small", s.modify_damage("x", 3, 10.0, true) == 25.0 and s.step_cooldown_scale() == 0.0)
	_check("anh_bo hook active UNPINNED small x small_mult", s.modify_damage("x", 2, 10.0, false) == 25.0 and s.modify_damage("x", 3, 10.0, false) == 25.0)
	_check("anh_bo hook active big: no multiplier, pinned or not", s.modify_damage("x", 4, 10.0, true) == 10.0 and s.modify_damage("x", 4, 10.0, false) == 10.0)
	s.tick(2.5)
	_check("anh_bo hook expired: plain again", not s.is_active() and s.modify_damage("x", 1, 10.0, false) == 10.0 and s.step_cooldown_scale() == 1.0)
	# Legacy key pinned_small_mult: still read when small_mult is absent (warns once); small_mult wins when both exist.
	var legacy: AnhBoSignature = SignatureRegistry.create("anh_bo") as AnhBoSignature
	legacy.setup({}, {"duration_sec": 2.0, "pinned_small_mult": 3.0, "small_cells": 3})
	legacy.activate()
	_check("anh_bo legacy key read as small_mult (no pin needed)", legacy.modify_damage("x", 3, 10.0, false) == 30.0 and legacy.modify_damage("x", 4, 10.0, false) == 10.0)
	_check("anh_bo legacy key: warned flag set, value 3", legacy._legacy_warned and legacy.small_mult() == 3.0)
	var both: AnhBoSignature = SignatureRegistry.create("anh_bo") as AnhBoSignature
	both.setup({}, {"duration_sec": 2.0, "pinned_small_mult": 3.0, "small_mult": 2.0, "small_cells": 3})
	both.activate()
	_check("anh_bo small_mult wins over the legacy key, no warning", both.modify_damage("x", 3, 10.0, false) == 20.0 and not both._legacy_warned)
	var bare: AnhBoSignature = SignatureRegistry.create("anh_bo") as AnhBoSignature
	bare.setup({}, {"duration_sec": 2.0})
	bare.activate()
	_check("anh_bo no mult param -> fallback 1.0", bare.modify_damage("x", 3, 10.0, false) == 10.0)


func _test_unknown_and_none() -> void:
	_check("registry unknown -> null", SignatureRegistry.create("zzz") == null)
	_check("registry known ids", SignatureRegistry.known_ids() == (["anh_bo", "thien_hoa", "tram"] as Array[String]))
	var ch: Dictionary = _cc.get_character("kiem_si")
	ch["signature"] = {"id": "zzz", "charge_cells": 18, "params": {}}
	var v: CombatView = await _view(ch)
	_check("unknown id -> no signature", v.get_signature() == null and v.get_signature_charge() == 0.0 and not v.is_signature_ready())
	_check("unknown id -> cannot activate", not v.can_activate_signature() and not v.activate_signature())
	_check("unknown id -> empty name, 0 duration", v.get_signature_name() == "" and v.get_signature_duration() == 0.0)
	_drop(v)
	# v2 character without signature plays as before.
	ch = _cc.get_character("sat_thu")
	ch.erase("signature")
	v = await _view(ch)
	var per: float = _per_cell(v)
	var r: Dictionary = _cast(v, 3)
	_check("no signature: casts work, Quick Blade still applies", _near(float(r["damage"]), per * 3.0 * 1.25))
	_check("no signature: charge 0, never ready", v.get_signature() == null and v.get_signature_charge() == 0.0 and not v.is_signature_ready() and not v.activate_signature())
	var mover: UnitMover = v.get_mover()
	var dir: Vector2i = Vector2i.ZERO
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if v.get_grid().is_player_cell(v.get_state().player_cell + d):
			dir = d
			break
	_check("no signature: step cooldown normal", mover.try_step(dir) and _near(mover.get_cooldown_remaining(), v.get_player_step_cooldown()))
	_drop(v)
	# No character at all.
	v = await _view({})
	_check("no character: no signature", v.get_signature() == null and not v.activate_signature())
	_drop(v)


func _test_character_config() -> void:
	for id: String in ["kiem_si", "phap_su", "sat_thu"]:
		var s: Dictionary = _cc.get_character(id)["signature"]
		_check("%s signature loaded" % id, not s.is_empty() and not s.has("charge_cells") and SignatureRegistry.has_id(str(s["id"])) and str(s["name_key"]).begins_with("signature."))
	var th_params: Dictionary = _cc.get_character("phap_su")["signature"]["params"]
	for key: String in ["burn_stacks", "burn_duration_sec", "burn_tick_sec", "burn_damage_per_tick", "detonate_mult"]:
		_check("phap_su thien_hoa param %s loaded (> 0)" % key, th_params.has(key) and float(th_params[key]) > 0.0)
	var ab_params: Dictionary = _cc.get_character("sat_thu")["signature"]["params"]
	_check("sat_thu anh_bo uses small_mult, not the legacy key", ab_params.has("small_mult") and not ab_params.has("pinned_small_mult") and float(ab_params["small_cells"]) == 3.0 and float(ab_params["duration_sec"]) > 0.0)
	_check("kiem_si tram params", _cc.get_character("kiem_si")["signature"]["params"] == {"duration_sec": 3.0, "cell_mult": 2.0, "lifesteal": 0.2})
	var bad: CharacterConfig = CharacterConfig.from_dictionary({"characters": [
		{"id": "a", "starter_deck": ["kiem_khi"], "signature": "tram"},
		{"id": "b", "starter_deck": ["kiem_khi"], "signature": {"id": "nope"}},
		{"id": "c", "starter_deck": ["kiem_khi"], "signature": {"id": "tram", "charge_cells": 0}},
		{"id": "d", "starter_deck": ["kiem_khi"], "signature": {"id": "tram", "params": "x"}},
		{"id": "e", "starter_deck": ["kiem_khi"]},
		{"id": "f", "starter_deck": ["kiem_khi"], "signature": {"id": "anh_bo", "charge_cells": 12.0, "params": {"duration_sec": 1}}},
	]})
	_check("signature not an object -> {}", (bad.get_character("a")["signature"] as Dictionary).is_empty())
	_check("unknown signature id -> {}", (bad.get_character("b")["signature"] as Dictionary).is_empty())
	_check("leftover charge_cells ignored (Story 029)", (bad.get_character("c")["signature"] as Dictionary).get("id", "") == "tram" and not (bad.get_character("c")["signature"] as Dictionary).has("charge_cells"))
	var d: Dictionary = bad.get_character("d")["signature"]
	_check("bad params -> {}", (d["params"] as Dictionary).is_empty())
	_check("absent signature -> {}", (bad.get_character("e")["signature"] as Dictionary).is_empty())
	var f: Dictionary = bad.get_character("f")["signature"]
	_check("valid signature kept", f["id"] == "anh_bo" and float(f["params"]["duration_sec"]) == 1.0)
	# Story 029 Phần D: cooldown_sec parsing (missing / negative / non-number -> 0) and shipped data.
	var cd: CharacterConfig = CharacterConfig.from_dictionary({"characters": [
		{"id": "m", "starter_deck": ["kiem_khi"], "signature": {"id": "tram"}},
		{"id": "n", "starter_deck": ["kiem_khi"], "signature": {"id": "tram", "cooldown_sec": -4}},
		{"id": "s", "starter_deck": ["kiem_khi"], "signature": {"id": "tram", "cooldown_sec": "ten"}},
		{"id": "i", "starter_deck": ["kiem_khi"], "signature": {"id": "thien_hoa", "cooldown_sec": 7}},
	]})
	_check("cooldown_sec missing -> 0", float(cd.get_character("m")["signature"]["cooldown_sec"]) == 0.0)
	_check("cooldown_sec negative -> 0", float(cd.get_character("n")["signature"]["cooldown_sec"]) == 0.0)
	_check("cooldown_sec non-number -> 0, signature kept", float(cd.get_character("s")["signature"]["cooldown_sec"]) == 0.0 and cd.get_character("s")["signature"]["id"] == "tram")
	_check("cooldown_sec int -> float 7", _near(float(cd.get_character("i")["signature"]["cooldown_sec"]), 7.0))
	for id: String in ["kiem_si", "phap_su", "sat_thu"]:
		var sig: Dictionary = _cc.get_character(id)["signature"]
		_check("%s characters.json cooldown_sec loaded (> 0)" % id, sig.has("cooldown_sec") and float(sig["cooldown_sec"]) > 0.0, str(sig.get("cooldown_sec")))
	_check("combat.json formation fade 3x3 = 12.2 s", _near(CombatConfig.load_from_file().formation_fade_for(9), 12.2))

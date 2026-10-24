extends SceneTree
## Story 021 Part 1 scratch test (headless): signature charge, host API on CombatView, the three
## signatures' numbers, registry / CharacterConfig validation, v2 behaviour without a signature.
## Prints PASS/FAIL lines and FAILS=n. No frames are processed until the very end, so CombatView's
## _process never runs: time is injected by hand.

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
	await _test_charge_unit()
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


func _test_charge_unit() -> void:
	var c := SignatureCharge.new(0)
	_check("charge capacity clamps to 1", c.capacity() == 1)
	c = SignatureCharge.new(18)
	c.add(-3)
	_check("charge ignores <= 0", c.cells() == 0 and c.fraction() == 0.0)
	c.add(5)
	_check("charge 5/18", c.cells() == 5 and _near(c.fraction(), 5.0 / 18.0) and not c.is_full())
	c.add(20)
	_check("charge caps at capacity", c.cells() == 18 and c.fraction() == 1.0 and c.is_full())
	c.reset()
	_check("charge reset", c.cells() == 0)


func _test_charge_and_host() -> void:
	var v: CombatView = await _view(_cc.get_character("kiem_si"))
	_check("kiem_si has tram", v.get_signature() != null and v.get_signature().get_id() == "tram")
	_check("charge starts at 0", v.get_signature_charge() == 0.0 and not v.is_signature_ready())
	_check("name translated", v.get_signature_name() == tr("signature.tram.name") and v.get_signature_name() != "signature.tram.name", v.get_signature_name())
	_check("duration 3 / time_left 0 / inactive", v.get_signature_duration() == 3.0 and v.get_signature_time_left() == 0.0 and not v.is_signature_active())
	_cast(v, 5)
	_check("5 cells -> 5/18", _near(v.get_signature_charge(), 5.0 / 18.0))
	_cast(v, 6)
	_cast(v, 6)
	_check("17 cells -> not ready", _near(v.get_signature_charge(), 17.0 / 18.0) and not v.is_signature_ready())
	# An interrupted (cancelled) swing still counted as cast; an uncast one (begin refused while
	# swinging) does not.
	_cast(v, 1)
	_check("18 cells -> full and ready", v.get_signature_charge() == 1.0 and v.is_signature_ready())
	_cast(v, 4)
	_check("charge capped at 1", v.get_signature_charge() == 1.0)
	var fired: Array[String] = []
	v.signature_activated.connect(func(id: String) -> void: fired.append(id))
	var ended: Array[String] = []
	v.signature_ended.connect(func(id: String) -> void: ended.append(id))
	_check("can activate", v.can_activate_signature())
	_check("activate -> true", v.activate_signature())
	_check("signal signature_activated(tram)", fired == (["tram"] as Array[String]))
	_check("charge reset to 0 on activate", v.get_signature_charge() == 0.0 and not v.is_signature_ready())
	_check("active, 3 s left", v.is_signature_active() and _near(v.get_signature_time_left(), 3.0))
	_check("activate again -> false", not v.activate_signature() and fired.size() == 1)
	v._tick_signature(1.0)
	_check("ticked 1 s -> 2 left", _near(v.get_signature_time_left(), 2.0) and ended.is_empty())
	v._tick_signature(2.5)
	_check("ended after 3 s + signal", not v.is_signature_active() and ended == (["tram"] as Array[String]))
	v.debug_set_signature_charge(0.5)
	_check("debug charge 0.5", _near(v.get_signature_charge(), 0.5))
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
	# Through the host.
	var v: CombatView = await _view(_cc.get_character("phap_su"))
	var state: CombatState = v.get_state()
	var status: StatusEffects = v.get_status()
	var g: BoardGrid = v.get_grid()
	var e1: Vector2i = g.enemy_cells()[0]
	var e2: Vector2i = g.enemy_cells()[g.enemy_cells().size() - 1]
	var p1: Vector2i = g.player_cells()[0]
	status.ignite([e1, e2, p1], 2.0, 0.5, 1.5)
	var cds: SkillCooldowns = v.get_skill_cooldowns()
	cds.start("hoa_tran", 8.0)
	cds.start("hoa_tinh", 7.0)
	cds.start("chan_phong", 6.0)
	var ended: Array[String] = []
	v.signature_ended.connect(func(id: String) -> void: ended.append(id))
	v.debug_set_signature_charge(1.0)
	var before: float = state.enemy_hp
	_check("thien_hoa: duration 0 (instant)", v.get_signature_duration() == 0.0)
	_check("thien_hoa: activate", v.activate_signature())
	_check("thien_hoa: boss takes 2 x (6 + 6)", _near(before - state.enemy_hp, 24.0), str(before - state.enemy_hp))
	_check("thien_hoa: last_damage", _near(float((v.get_signature() as ThienHoaSignature).last_damage()), 24.0))
	_check("thien_hoa: enemy burn cleared, player burn kept", not status.is_burning(e1) and not status.is_burning(e2) and status.is_burning(p1))
	_check("thien_hoa: burn cards reset", cds.is_ready("hoa_tran") and cds.is_ready("hoa_tinh"))
	_check("thien_hoa: non-burn cooldown kept", _near(cds.remaining("chan_phong"), 6.0))
	_check("thien_hoa: instant -> never active, ended at once", not v.is_signature_active() and ended == (["thien_hoa"] as Array[String]))
	# No burn: only the reset.
	status.clear()
	cds.start("hoa_tran", 8.0)
	v.debug_set_signature_charge(1.0)
	before = state.enemy_hp
	_check("thien_hoa no burn: activates", v.activate_signature())
	_check("thien_hoa no burn: no damage, reset only", state.enemy_hp == before and cds.is_ready("hoa_tran") and (v.get_signature() as ThienHoaSignature).last_damage() == 0.0)
	_check("thien_hoa: charge 0 after", v.get_signature_charge() == 0.0)
	_drop(v)


func _test_anh_bo() -> void:
	var v: CombatView = await _view(_cc.get_character("sat_thu"))
	var state: CombatState = v.get_state()
	var status: StatusEffects = v.get_status()
	var cfg: CombatConfig = CombatConfig.load_from_file()
	var ghim: float = cfg.pinned_damage_mult
	var quick: float = float(_cc.get_character("sat_thu")["passive"]["params"]["damage_mult"])
	var per: float = _per_cell(v)
	# Pinned, inactive: Ghim x Quick Blade only.
	status.pin(CombatState.Side.ENEMY, 100.0)
	var r: Dictionary = _cast(v, 3)
	_check("anh_bo inactive: pinned 3 cells = per*3*ghim*quick", _near(float(r["damage"]), per * 3.0 * ghim * quick), str(r["damage"]))
	v.debug_set_signature_charge(1.0)
	v.activate_signature()
	_check("anh_bo active 2 s", v.is_signature_active() and _near(v.get_signature_time_left(), 2.0))
	r = _cast(v, 3)
	_check("anh_bo active: pinned 3 cells x2 (stacks with Ghim + Quick Blade)", _near(float(r["damage"]), per * 3.0 * ghim * quick * 2.0), str(r["damage"]))
	_check("anh_bo: pin_bonus off (Ghim control-only, Story 023)", not bool(r["pin_bonus"]))
	r = _cast(v, 4)
	_check("anh_bo active: pinned 4 cells = Ghim only", _near(float(r["damage"]), per * 4.0 * ghim), str(r["damage"]))
	status.clear()
	r = _cast(v, 3)
	_check("anh_bo active: unpinned 3 cells = Quick Blade only", _near(float(r["damage"]), per * 3.0 * quick), str(r["damage"]))
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
	# Pure hook.
	var s: BaseSignature = SignatureRegistry.create("anh_bo")
	s.setup({}, {"duration_sec": 2.0, "pinned_small_mult": 2.0, "small_cells": 3})
	_check("anh_bo hook inactive", s.modify_damage("x", 3, 10.0, true) == 10.0 and s.step_cooldown_scale() == 1.0)
	s.activate()
	_check("anh_bo hook active pinned small", s.modify_damage("x", 3, 10.0, true) == 20.0 and s.step_cooldown_scale() == 0.0)
	_check("anh_bo hook active pinned big", s.modify_damage("x", 4, 10.0, true) == 10.0)
	_check("anh_bo hook active unpinned", s.modify_damage("x", 2, 10.0, false) == 10.0)


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
		_check("%s signature loaded" % id, not s.is_empty() and int(s["charge_cells"]) == 18 and SignatureRegistry.has_id(str(s["id"])) and str(s["name_key"]).begins_with("signature."))
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
	_check("charge_cells 0 -> {}", (bad.get_character("c")["signature"] as Dictionary).is_empty())
	var d: Dictionary = bad.get_character("d")["signature"]
	_check("missing charge_cells -> default 18, bad params -> {}", int(d["charge_cells"]) == CharacterConfig.DEFAULT_CHARGE_CELLS and (d["params"] as Dictionary).is_empty())
	_check("absent signature -> {}", (bad.get_character("e")["signature"] as Dictionary).is_empty())
	var f: Dictionary = bad.get_character("f")["signature"]
	_check("valid signature kept", f["id"] == "anh_bo" and int(f["charge_cells"]) == 12 and float(f["params"]["duration_sec"]) == 1.0)
	_check("combat.json signature_charge_cells", CombatConfig.load_from_file().signature_charge_cells == 18)

extends SceneTree
## Story 037 (headless): the Hunter's passive hunter_mark, the Priest's passive prayer and the two new match stats
## (frost_bursts, boss_thorn_steps). Pure rigs (CombatState + BoardGrid + StatusEffects) for the passive rules, one
## real CombatView each for the wiring (status signals -> passive / stats / heal flash). No frames run after the
## first one, so time is injected by hand. Prints PASS/FAIL lines and FAILS=n.

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


# A pure rig: 3x3 half grid, a status configured from combat.json, the boss on its first enemy cell, and the
# passive [param id] set up with the shipped params of [param character].
func _rig(id: String, character: String) -> Dictionary:
	var cfg: CombatConfig = CombatConfig.load_from_file()
	var st := StatusEffects.new()
	cfg.configure_status(st)
	var grid := BoardGrid.new(3, 3)
	var boss_cell: Vector2i = grid.enemy_cells()[0]
	var state := CombatState.new(grid, 100.0, BIG_HP, BoardGrid.NO_CELL, boss_cell)
	var heals: Array[float] = [0.0]
	var heal_fn: Callable = func(amount: float) -> void:
		heals[0] += amount
		state.set_player_hp(state.player_hp + amount)
	var passive: BasePassive = PassiveRegistry.create(id)
	var spec: Dictionary = _cc.get_character(character)["passive"]
	passive.setup({"status": st, "grid": grid, "state": state, "heal_player": heal_fn}, spec["params"])
	return {"status": st, "grid": grid, "state": state, "passive": passive, "heals": heals, "boss": boss_cell}


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


func _initialize() -> void:
	_cc = CharacterConfig.load_from_file()
	_test_hunter_mark_rules()
	_test_hunter_mark_icd()
	_test_prayer_rules()
	await _test_view_wiring_hunter()
	await _test_view_wiring_priest()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _test_hunter_mark_rules() -> void:
	var r: Dictionary = _rig("hunter_mark", "tho_san")
	var p: BasePassive = r["passive"]
	var st: StatusEffects = r["status"]
	var grid: BoardGrid = r["grid"]
	var boss: Vector2i = r["boss"]
	var enemy: int = CombatState.Side.ENEMY
	_check("hunter_mark: registered, id", PassiveRegistry.has_id("hunter_mark") and p.get_id() == "hunter_mark")
	_check("hunter_mark: shipped params (1 stack, 3 s)", p.param_int("fragile_stacks", 0) == 1 and _near(p.param_float("icd_sec", 0.0), 3.0))
	# Case 1: the boss steps onto a player thorn cell.
	p.on_boss_thorn_step(boss)
	_check("hunter_mark: boss on a player thorn -> 1 Ran", st.fragile_stacks(enemy) == 1, str(st.fragile_stacks(enemy)))
	# Case 2: a seal forms next to the boss (fresh passive: no cooldown running).
	r = _rig("hunter_mark", "tho_san")
	p = r["passive"]
	st = r["status"]
	boss = r["boss"]
	var near: Vector2i = Vector2i(-1, -1)
	var far: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in grid.enemy_cells():
		var dist: int = absi(cell.x - boss.x) + absi(cell.y - boss.y)
		if dist == 1 and near.x < 0:
			near = cell
		if dist >= 2 and far.x < 0:
			far = cell
	_check("rig has a neighbour and a far cell", near.x >= 0 and far.x >= 0)
	p.on_player_zone_formed(StatusEffects.KIND_SEAL, [far] as Array[Vector2i])
	_check("hunter_mark: seal NOT next to the boss -> nothing", st.fragile_stacks(enemy) == 0)
	p.on_player_zone_formed(StatusEffects.KIND_THORNS, [near] as Array[Vector2i])
	_check("hunter_mark: a THORNS zone next to the boss -> nothing (only seals count)", st.fragile_stacks(enemy) == 0)
	p.on_player_zone_formed(StatusEffects.KIND_SEAL, [far, near] as Array[Vector2i])
	_check("hunter_mark: seal with a cell next to the boss -> 1 Ran", st.fragile_stacks(enemy) == 1 and (p as HunterMarkPassive).marks_given() == 1)
	# The boss standing INSIDE the seal (not adjacent) does not count.
	r = _rig("hunter_mark", "tho_san")
	p = r["passive"]
	st = r["status"]
	p.on_player_zone_formed(StatusEffects.KIND_SEAL, [r["boss"]] as Array[Vector2i])
	_check("hunter_mark: boss only INSIDE the seal (no neighbour cell) -> nothing", st.fragile_stacks(enemy) == 0)
	# No stack param / no status: safe.
	var bare: HunterMarkPassive = PassiveRegistry.create("hunter_mark") as HunterMarkPassive
	bare.setup({}, {})
	bare.on_boss_thorn_step(Vector2i.ZERO)
	_check("hunter_mark: no ctx / no params -> no crash, no mark", bare.marks_given() == 0)


func _test_hunter_mark_icd() -> void:
	var r: Dictionary = _rig("hunter_mark", "tho_san")
	var p: BasePassive = r["passive"]
	var st: StatusEffects = r["status"]
	var boss: Vector2i = r["boss"]
	var enemy: int = CombatState.Side.ENEMY
	p.on_boss_thorn_step(boss)
	p.on_boss_thorn_step(boss)
	_check("icd: a second trigger at once is ignored", st.fragile_stacks(enemy) == 1)
	p.tick(1.0)
	p.on_boss_thorn_step(boss)
	_check("icd: still inside the 3 s window at 1 s", st.fragile_stacks(enemy) == 1)
	p.tick(1.9)
	p.on_player_zone_formed(StatusEffects.KIND_SEAL, [r["grid"].enemy_cells()[1]] as Array[Vector2i])
	_check("icd: still inside at 2.9 s (either source shares the cooldown)", st.fragile_stacks(enemy) == 1)
	p.tick(0.1)
	p.on_boss_thorn_step(boss)
	_check("icd: ready again at 3.0 s -> 2nd Ran", st.fragile_stacks(enemy) == 2, str(st.fragile_stacks(enemy)))
	p.tick(-5.0)
	p.on_boss_thorn_step(boss)
	_check("icd: a negative tick never rewinds the clock", st.fragile_stacks(enemy) == 2)
	p.tick(3.0)
	p.on_boss_thorn_step(boss)
	_check("icd: after another 3 s -> 3rd Ran (config cap 3)", st.fragile_stacks(enemy) == 3)
	# icd 0: every trigger counts.
	var free: HunterMarkPassive = PassiveRegistry.create("hunter_mark") as HunterMarkPassive
	var st2 := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(st2)
	free.setup({"status": st2}, {"fragile_stacks": 1, "icd_sec": 0.0})
	free.on_boss_thorn_step(boss)
	free.on_boss_thorn_step(boss)
	_check("icd_sec 0 -> no cooldown", st2.fragile_stacks(enemy) == 2)


func _test_prayer_rules() -> void:
	var r: Dictionary = _rig("prayer", "giao_si")
	var p: BasePassive = r["passive"]
	var st: StatusEffects = r["status"]
	var state: CombatState = r["state"]
	var heals: Array[float] = r["heals"]
	_check("prayer: registered, id, shipped heal 8", PassiveRegistry.has_id("prayer") and p.get_id() == "prayer" and _near(p.param_float("heal_per_burst", 0.0), 8.0))
	state.set_player_hp(50.0)
	p.on_frost_burst(24.0)
	_check("prayer: a burst heals 8", _near(heals[0], 8.0) and _near(state.player_hp, 58.0), str(state.player_hp))
	p.on_frost_burst(24.0)
	_check("prayer: each burst heals again", _near(state.player_hp, 66.0))
	state.set_player_hp(97.0)
	p.on_frost_burst(24.0)
	_check("prayer: never over max HP", _near(state.player_hp, 100.0), str(state.player_hp))
	# Via a real StatusEffects burst forwarded the way CombatView does.
	var enemy: int = CombatState.Side.ENEMY
	st.frost_burst.connect(func(side: int, damage: float) -> void:
		if side == enemy:
			p.on_frost_burst(damage))
	state.set_player_hp(10.0)
	st.apply_frost(enemy, 2)
	_check("prayer: no burst below the threshold -> no heal", _near(state.player_hp, 10.0))
	st.apply_frost(enemy, 1)
	_check("prayer: threshold reached -> +8 through the status signal", _near(state.player_hp, 18.0), str(state.player_hp))
	# Missing heal callable or 0 param: safe.
	var bare: PrayerPassive = PassiveRegistry.create("prayer") as PrayerPassive
	bare.setup({}, {"heal_per_burst": 8})
	bare.on_frost_burst(1.0)
	var zero: PrayerPassive = PassiveRegistry.create("prayer") as PrayerPassive
	zero.setup({"heal_player": func(_a: float) -> void: heals[0] = -999.0}, {"heal_per_burst": 0})
	zero.on_frost_burst(1.0)
	_check("prayer: no ctx -> safe; heal 0 -> never calls the heal", bare.bursts_seen() == 1 and heals[0] != -999.0)


func _test_view_wiring_hunter() -> void:
	var v: CombatView = await _view(_cc.get_character("tho_san"))
	var st: StatusEffects = v.get_status()
	var state: CombatState = v.get_state()
	var enemy: int = CombatState.Side.ENEMY
	var passive: HunterMarkPassive = v.get_passive() as HunterMarkPassive
	_check("view: tho_san has hunter_mark", passive != null)
	_check("stats start at 0", int(v.get_match_stats()["boss_thorn_steps"]) == 0 and int(v.get_match_stats()["frost_bursts"]) == 0)
	# The boss steps onto a thorn cell of the player's zone: damage 0, 0 Ran from the thorn itself, so every Ran is the mark.
	var cells: Array[Vector2i] = v.get_grid().enemy_cells()
	var start: Vector2i = state.enemy_cell
	var target: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in cells:
		if cell != start:
			target = cell
			break
	st.apply_thorns(enemy, [target] as Array[Vector2i], 5.0, 0.0, 0)
	st.tick(0.0, state)
	state.set_enemy_cell(target)
	st.tick(0.0, state)
	_check("view: the boss stepping onto a thorn counts 1 boss_thorn_step", int(v.get_match_stats()["boss_thorn_steps"]) == 1)
	_check("view: ... and hunter_mark gave 1 Ran", st.fragile_stacks(enemy) == 1 and passive.marks_given() == 1)
	state.set_enemy_cell(start)
	st.tick(0.0, state)
	state.set_enemy_cell(target)
	st.tick(0.0, state)
	_check("view: each step counts (2 steps), the icd keeps the Ran at 1", int(v.get_match_stats()["boss_thorn_steps"]) == 2 and st.fragile_stacks(enemy) == 1)
	# A thorn zone the boss walks onto on the PLAYER half is not a step onto the player's thorns.
	st.apply_thorns(CombatState.Side.PLAYER, [state.player_cell] as Array[Vector2i], 5.0, 1.0, 0)
	_check("view: the player's own thorn entry is not counted", int(v.get_match_stats()["boss_thorn_steps"]) == 2)
	# A seal formed next to the boss through a real card cast.
	passive.tick(10.0)
	var st_before: int = st.fragile_stacks(enemy)
	var neighbour: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in cells:
		if absi(cell.x - state.enemy_cell.x) + absi(cell.y - state.enemy_cell.y) == 1:
			neighbour = cell
			break
	var got: Array[Dictionary] = [{}]
	var cb: Callable = func(side: int, result: Dictionary) -> void:
		if side == CombatState.Side.PLAYER:
			got[0] = result
	v.get_arbiter().swing_resolved.connect(cb)
	v._begin_cut("ket_gioi", [neighbour] as Array[Vector2i])
	v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	v.get_arbiter().swing_resolved.disconnect(cb)
	_check("view: a real ket_gioi cast next to the boss -> hunter_mark Ran", not (got[0].get("zone_cells", []) as Array).is_empty() and st.fragile_stacks(enemy) == st_before + 1, "before %d after %d" % [st_before, st.fragile_stacks(enemy)])
	_drop(v)
	# A character without the passive: same events, no mark, stats still count.
	var v2: CombatView = await _view(_cc.get_character("kiem_si"))
	var st2: StatusEffects = v2.get_status()
	var s2: CombatState = v2.get_state()
	var t2: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in v2.get_grid().enemy_cells():
		if cell != s2.enemy_cell:
			t2 = cell
			break
	var home: Vector2i = s2.enemy_cell
	st2.apply_thorns(enemy, [t2] as Array[Vector2i], 5.0, 0.0, 0)
	st2.tick(0.0, s2)
	s2.set_enemy_cell(t2)
	st2.tick(0.0, s2)
	_check("view: kiem_si, same thorn step: counted, no Ran from a passive", int(v2.get_match_stats()["boss_thorn_steps"]) == 1 and st2.fragile_stacks(enemy) == 0 and home != t2)
	_drop(v2)


func _test_view_wiring_priest() -> void:
	var v: CombatView = await _view(_cc.get_character("giao_si"))
	var st: StatusEffects = v.get_status()
	var state: CombatState = v.get_state()
	var enemy: int = CombatState.Side.ENEMY
	_check("view: giao_si has prayer", v.get_passive() != null and v.get_passive().get_id() == "prayer")
	state.set_player_hp(100.0)
	st.apply_frost(enemy, 3)
	_check("view: a Han burst heals 8 and is counted", _near(state.player_hp, 108.0) and int(v.get_match_stats()["frost_bursts"]) == 1, str(state.player_hp))
	_check("view: the heal flash shows +8", not v.get_heal_flash().is_empty() and _near(float(v.get_heal_flash()["amount"]), 8.0))
	state.set_player_hp(state.player_max_hp - 3.0)
	st.apply_frost(enemy, 3)
	_check("view: never over max HP", _near(state.player_hp, state.player_max_hp), str(state.player_hp))
	_check("view: the flash shows the 3 HP actually gained, bursts = 2", _near(float(v.get_heal_flash()["amount"]), 11.0) and int(v.get_match_stats()["frost_bursts"]) == 2, str(v.get_heal_flash()))
	st.apply_frost(CombatState.Side.PLAYER, 3)
	_check("view: a Han burst on the PLAYER is not counted and heals nothing", int(v.get_match_stats()["frost_bursts"]) == 2 and _near(state.player_hp, state.player_max_hp))
	_drop(v)
	var v2: CombatView = await _view(_cc.get_character("kiem_si"))
	v2.get_state().set_player_hp(100.0)
	v2.get_status().apply_frost(enemy, 3)
	_check("view: kiem_si bursts count but heal nothing", int(v2.get_match_stats()["frost_bursts"]) == 1 and _near(v2.get_state().player_hp, 100.0) and v2.get_heal_flash().is_empty())
	_drop(v2)

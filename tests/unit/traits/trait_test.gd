extends SceneTree
## Headless mini-world test of Story 014 Part B (traits). PASS/FAIL lines + FAILS=N.

const DT: float = 0.05

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _world(seed_value: int) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var brain_config: BossBrainConfig = BossBrainConfig.load_from_file()
	var hold_config := HoldSlotsConfig.new()
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 100000.0
	var player_drops := FieldDrops.new(drops_config, grid.player_cells(), seed_value)
	var boss := BossController.new(state, grid, cut_config, skill_config, brain_config, drops_config, hold_config, seed_value + 1)
	boss.set_active(false)
	var status := StatusEffects.new()
	boss.set_status(status)
	var player_actor := CutActor.new(cut_config, CombatState.Side.PLAYER)
	var arbiter := SwingArbiter.new(state, grid, player_actor, boss.get_actor(), cut_config, skill_config, status)
	var hold := HoldSlots.new(4)
	var ctx: Dictionary = {
		"state": state, "grid": grid, "player_drops": player_drops, "boss_drops": boss.get_drops(),
		"boss": boss, "status": status, "arbiter": arbiter, "hold_getter": func() -> HoldSlots: return hold,
		"skill_config": skill_config, "cut_config": cut_config,
	}
	return {"ctx": ctx, "state": state, "grid": grid, "status": status, "drops": player_drops, "hold": hold, "arbiter": arbiter}


func _tick(w: Dictionary, host: TraitHost, step: float) -> void:
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	var drops: FieldDrops = w["drops"]
	var hold: HoldSlots = w["hold"]
	status.tick(step, state)
	drops.set_blocked_cells(status.burning_cells())
	drops.tick(step, state.player_cell, hold.get_occupied_count())
	(w["arbiter"] as SwingArbiter).tick(step)
	hold.tick_rot(step)
	host.on_tick(step)


func _run_until(w: Dictionary, host: TraitHost, t: Array, until: float) -> void:
	while t[0] < until - 0.000001:
		t[0] += DT
		_tick(w, host, DT)


func _same_cells(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size():
		return false
	for c: Vector2i in a:
		if not b.has(c):
			return false
	return true


func _init() -> void:
	_test_registry()
	_test_row_burner_damage()
	_test_row_burner_row_fixed_at_warning()
	_test_rotten_thrower()
	_test_determinism()
	_test_teardown()
	print("FAILS=%d" % fails)
	quit(fails)


func _test_registry() -> void:
	var w: Dictionary = _world(5)
	_check("registry unknown null", TraitRegistry.create("nope") == null)
	_check("registry known ids", TraitRegistry.known_ids() == (["frost_aura", "fuse_cannon", "phase_shift", "rotten_thrower", "row_burner", "slam", "step_reactor"] as Array[String]), str(TraitRegistry.known_ids()))
	var host := TraitHost.new(w["ctx"], [{"id": "nope"}, 42, {"id": "row_burner", "params": 7}, {"id": "row_burner"}], 5)
	_check("host skips unknown (1 of 4 entries bad, 2 valid)", host.size() == 2, str(host.get_ids()))
	host.on_match_start()
	host.on_tick(0.1)
	_check("host still runs", host.get_trait("row_burner") != null)
	var empty := TraitHost.new(w["ctx"], [], 5)
	empty.on_match_start()
	empty.on_tick(0.1)
	empty.on_boss_damaged(3.0)
	_check("empty host ok", empty.size() == 0 and empty.get_traits().is_empty())


func _test_row_burner_damage() -> void:
	var w: Dictionary = _world(11)
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	state.set_player_cell(Vector2i(0, 0))
	var params: Dictionary = {"first_delay_sec": 1.0, "warn_sec": 0.5, "burn_sec": 1.0, "tick_sec": 0.25, "damage_per_tick": 2.0, "interval_sec": 3.0}
	var host := TraitHost.new(w["ctx"], [{"id": "row_burner", "params": params}], 11)
	var rb: RowBurnerTrait = host.get_trait("row_burner") as RowBurnerTrait
	var warned: Array[float] = []
	var burned: Array[float] = []
	var warned_cells: Array[Vector2i] = []
	var t: Array = [0.0]
	rb.row_warned.connect(func(cells: Array[Vector2i]) -> void:
		warned.append(t[0])
		warned_cells.assign(cells))
	rb.row_burned.connect(func(_cells: Array[Vector2i]) -> void: burned.append(t[0]))
	host.on_match_start()
	_run_until(w, host, t, 0.9)
	_check("rb no warning before first_delay", warned.is_empty() and rb.get_warn_left() == 0.0)
	_run_until(w, host, t, 1.05)
	_check("rb first warning at first_delay", warned.size() == 1 and absf(warned[0] - 1.0) <= DT + 0.001, str(warned))
	var row0: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_check("rb warned cells = player's row", _same_cells(warned_cells, row0), str(warned_cells))
	_check("rb warning getters", _same_cells(rb.get_warning_cells(), row0) and rb.get_warn_left() > 0.0 and rb.get_warn_left() <= 0.5)
	_check("rb nothing burning during warning", status.burning_cells().is_empty())
	_run_until(w, host, t, 1.6)
	_check("rb burn starts warn_sec later", burned.size() == 1 and absf(burned[0] - 1.5) <= DT + 0.001, str(burned))
	_check("rb row burning", _same_cells(status.burning_cells(), row0), str(status.burning_cells()))
	_check("rb warning cleared", rb.get_warning_cells().is_empty() and rb.get_warn_left() == 0.0)
	_run_until(w, host, t, 2.4)
	_check("rb still burning before burn_sec", _same_cells(status.burning_cells(), row0))
	_run_until(w, host, t, 2.7)
	_check("rb burned out after burn_sec", status.burning_cells().is_empty(), str(status.burning_cells()))
	var lost: float = 100.0 - state.player_hp
	_check("rb player in row took damage_per_tick per tick_sec (lost %.1f, expect 6..8 in steps of 2)" % lost, lost >= 6.0 and lost <= 8.0 and is_equal_approx(fmod(lost, 2.0), 0.0))
	_run_until(w, host, t, 3.9)
	_check("rb no second warning yet", warned.size() == 1)
	_run_until(w, host, t, 4.1)
	_check("rb next warning interval after the first", warned.size() == 2 and absf(warned[1] - 4.0) <= DT + 0.001, str(warned))
	_check("rb debug", rb.get_debug()["id"] == "row_burner" and rb.get_burn_count() == 1)


func _test_row_burner_row_fixed_at_warning() -> void:
	var w: Dictionary = _world(12)
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var params: Dictionary = {"first_delay_sec": 0.5, "warn_sec": 0.5, "burn_sec": 1.0, "tick_sec": 0.25, "damage_per_tick": 2.0, "interval_sec": 10.0}
	var host := TraitHost.new(w["ctx"], [{"id": "row_burner", "params": params}], 12)
	host.on_match_start()
	var t: Array = [0.0]
	_run_until(w, host, t, 0.6)
	var rb: RowBurnerTrait = host.get_trait("row_burner") as RowBurnerTrait
	var row1: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	_check("rb2 warned player's row (1)", _same_cells(rb.get_warning_cells(), row1), str(rb.get_warning_cells()))
	state.set_player_cell(Vector2i(1, 2))
	_run_until(w, host, t, 1.2)
	_check("rb2 burned the row fixed at warning time", _same_cells(status.burning_cells(), row1), str(status.burning_cells()))
	_run_until(w, host, t, 2.2)
	_check("rb2 player who left the row took no damage", is_equal_approx(state.player_hp, 100.0), str(state.player_hp))
	# random row pick: still a whole row of the half
	var w2: Dictionary = _world(13)
	var host2 := TraitHost.new(w2["ctx"], [{"id": "row_burner", "params": {"first_delay_sec": 0.1, "row_pick": "random", "warn_sec": 5.0}}], 13)
	host2.on_match_start()
	var t2: Array = [0.0]
	_run_until(w2, host2, t2, 0.2)
	var cells: Array[Vector2i] = (host2.get_trait("row_burner") as RowBurnerTrait).get_warning_cells()
	var ok: bool = cells.size() == 3
	for c: Vector2i in cells:
		ok = ok and c.y == cells[0].y and (w2["grid"] as BoardGrid).is_player_cell(c)
	_check("rb2 random row_pick gives one whole player row", ok, str(cells))


func _test_rotten_thrower() -> void:
	var w: Dictionary = _world(21)
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var drops: FieldDrops = w["drops"]
	var hold: HoldSlots = w["hold"]
	var grid: BoardGrid = w["grid"]
	var burning: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 0)]
	status.ignite(burning, 1000.0, 0.5, 0.0)
	var params: Dictionary = {"first_delay_sec": 1.0, "interval_sec": 2.0, "max_on_field": 1, "rot_in_hand_sec": 1.0, "field_freshness_sec": 100.0, "label": "X"}
	var host := TraitHost.new(w["ctx"], [{"id": "rotten_thrower", "params": params}], 21)
	var rt: RottenThrowerTrait = host.get_trait("rotten_thrower") as RottenThrowerTrait
	var thrown: Array[FieldPoint] = []
	var t: Array = [0.0]
	var times: Array[float] = []
	rt.thrown.connect(func(p: FieldPoint) -> void:
		thrown.append(p)
		times.append(t[0]))
	host.on_match_start()
	_run_until(w, host, t, 0.9)
	_check("rt nothing before first_delay", thrown.is_empty())
	_run_until(w, host, t, 1.05)
	_check("rt first throw at first_delay", thrown.size() == 1 and absf(times[0] - 1.0) <= DT + 0.001, str(times))
	var p: FieldPoint = thrown[0]
	_check("rt point is a rotten piece with rot time", p.rotten and p.piece != null and p.piece.is_rotten() and p.label == Piece.ROTTEN_ID and is_equal_approx(p.rot_in_hand_sec, 1.0))
	_check("rt cell is a free player cell, not the player, not burning", grid.is_player_cell(p.cell) and p.cell != state.player_cell and not status.is_burning(p.cell), str(p.cell))
	_check("rt only free candidates were (1,2)/(2,1)/(2,2)... got %s" % p.cell, p.cell == Vector2i(2, 1) or p.cell == Vector2i(2, 2))
	_check("rt last thrown cell", rt.get_last_thrown_cell() == p.cell)
	_check("rt on field", drops.get_points().size() == 1 and drops.get_points()[0].rotten)
	_run_until(w, host, t, 3.6)
	_check("rt max_on_field respected (still 1 after interval)", thrown.size() == 1 and drops.get_points().size() == 1)
	# pick it up
	var picked: FieldPoint = drops.pick_up_at(p.cell, not hold.is_full())
	_check("rt pick up", picked == p)
	var cleared: Array[int] = []
	hold.slot_cleared.connect(func(index: int, _point: FieldPoint) -> void: cleared.append(index))
	var slot: int = hold.place_in_first_free(picked)
	_check("rt occupies a slot", slot == 0 and hold.get_occupied_count() == 1 and hold.get_rotten_count() == 1)
	_check("rt toggle_selected false", hold.toggle_selected(slot) == false and not hold.is_selected(slot))
	_check("rt not in selected labels/indices", hold.get_selected_labels().is_empty() and hold.get_selected_indices().is_empty())
	_check("rt remove_selected removes nothing", hold.remove_selected().is_empty() and hold.get_occupied_count() == 1)
	hold.tick_rot(0.5)
	_check("rt still held before rot_in_hand_sec", hold.get_occupied_count() == 1 and cleared.is_empty())
	hold.tick_rot(0.6)
	_check("rt removed after rot_in_hand_sec with slot_cleared", hold.get_occupied_count() == 0 and hold.get_rotten_count() == 0 and cleared == ([0] as Array[int]), str(cleared))
	# the pending throw happens as soon as the field frees
	_run_until(w, host, t, 3.8)
	_check("rt pending throw once the field is free", thrown.size() == 2 and drops.get_points().size() == 1, str(times))
	_check("rt debug", rt.get_debug()["throws"] == 2 and rt.get_throw_count() == 2)
	# place_rotten_piece refuses bad cells (Story 026: the labelled place_rotten is gone)
	_check("place_rotten_piece refuses occupied", drops.place_rotten_piece(thrown[1].cell, 5.0, 5.0) == null)
	_check("place_rotten_piece refuses boss cell", drops.place_rotten_piece(Vector2i(4, 1), 5.0, 5.0) == null)
	_check("place_rotten_piece refuses blocked (burning) cell", drops.place_rotten_piece(Vector2i(0, 0), 5.0, 5.0) == null)


func _throw_cells(seed_value: int) -> Array[Vector2i]:
	var w: Dictionary = _world(seed_value)
	var host := TraitHost.new(w["ctx"], [{"id": "rotten_thrower", "params": {"first_delay_sec": 0.2, "interval_sec": 0.5, "max_on_field": 4, "field_freshness_sec": 1.2}}, {"id": "row_burner", "params": {"first_delay_sec": 0.3, "interval_sec": 1.0, "warn_sec": 0.2, "burn_sec": 0.4, "row_pick": "random", "damage_per_tick": 0.0}}], seed_value)
	var rt: RottenThrowerTrait = host.get_trait("rotten_thrower") as RottenThrowerTrait
	var cells: Array[Vector2i] = []
	rt.thrown.connect(func(p: FieldPoint) -> void: cells.append(p.cell))
	(host.get_trait("row_burner") as RowBurnerTrait).row_warned.connect(func(c: Array[Vector2i]) -> void: cells.append(c[0]))
	host.on_match_start()
	var t: Array = [0.0]
	_run_until(w, host, t, 12.0)
	return cells


func _test_determinism() -> void:
	var a: Array[Vector2i] = _throw_cells(77)
	var b: Array[Vector2i] = _throw_cells(77)
	var c: Array[Vector2i] = _throw_cells(78)
	_check("determinism same seed same cells (%d events)" % a.size(), a.size() >= 8 and a == b, str(a))
	_check("determinism different seed differs (informational)", a != c, str(c))


func _test_teardown() -> void:
	var w: Dictionary = _world(31)
	var host := TraitHost.new(w["ctx"], [{"id": "rotten_thrower"}, {"id": "row_burner"}], 31)
	host.on_match_start()
	var traits: Array[BossTrait] = host.get_traits()
	_check("teardown: 2 traits before", traits.size() == 2 and host.get_ids() == (["rotten_thrower", "row_burner"] as Array[String]))
	host.teardown_all()
	_check("teardown: host empty", host.get_traits().is_empty() and host.size() == 0)
	_check("teardown: traits dropped context/params", traits[0].get_context().is_empty() and traits[0].get_params().is_empty() and traits[1].get_context().is_empty())
	host.teardown_all()
	host.on_tick(0.1)
	_check("teardown: idempotent", host.size() == 0)

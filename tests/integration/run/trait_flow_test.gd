extends SceneTree
## Real-scene test of Story 014 Part B: traits in a run (windowed). PASS/FAIL + FAILS=N.

const CFG: String = "res://tests/fixtures/trait_run.json"

var fails: int = 0
var rc: RunController


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _wait_phase(phase: int, max_frames: int = 900) -> bool:
	for _i: int in max_frames:
		if rc.get_state().get_phase() == phase:
			return true
		await process_frame
	return false


func _view() -> CombatView:
	return rc.get_battle().get_node("CombatView") as CombatView


func _same_cells(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size():
		return false
	for c: Vector2i in a:
		if not b.has(c):
			return false
	return true


func _initialize() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	rc = flow.enter_test_floor(RunConfig.load_from_file(CFG))
	await process_frame
	_check("config traits passed through", (rc.get_config().matches[0]["traits"] as Array).size() == 1 and (rc.get_config().matches[1]["traits"] as Array).size() == 2)
	# ---- match 1: row_burner
	_check("m1 PLAYING", await _wait_phase(RunState.Phase.PLAYING))
	var v: CombatView = _view()
	var host: TraitHost = v.get_trait_host()
	_check("m1 host has row_burner", host != null and host.get_ids() == (["row_burner"] as Array[String]), str(host.get_ids()) if host != null else "null host")
	var rb: RowBurnerTrait = host.get_trait("row_burner") as RowBurnerTrait
	var warned_cells: Array[Vector2i] = []
	for _i: int in 180:
		if rb.get_warn_left() > 0.0:
			warned_cells = rb.get_warning_cells()
			break
		await process_frame
	_check("m1 warning shown", not warned_cells.is_empty() and warned_cells.has(v.get_state().player_cell), str(warned_cells))
	_check("m1 nothing burning yet", v.get_status().burning_cells().is_empty())
	var burning: Array[Vector2i] = []
	for _i: int in 180:
		burning = v.get_status().burning_cells()
		if not burning.is_empty():
			break
		await process_frame
	_check("m1 warned row is burning", _same_cells(burning, warned_cells), str(burning))
	_check("m1 warning gone after ignite", rb.get_warn_left() == 0.0 and rb.get_burn_count() == 1)
	_check("m1 hold rot count 0", v.get_hold().get_rotten_count() == 0)
	# ---- match 2: rotten_thrower + bogus
	v.get_state().damage(CombatState.Side.ENEMY, 99999.0)
	_check("m1 -> BETWEEN", await _wait_phase(RunState.Phase.BETWEEN))
	var host1: TraitHost = host
	await _wait_phase(RunState.Phase.INTRO, 5)
	_check("m2 PLAYING", await _wait_phase(RunState.Phase.PLAYING))
	v = _view()
	host = v.get_trait_host()
	_check("m1 host torn down once its battle was freed", host1.size() == 0)
	_check("m2 host skipped bogus, has rotten_thrower", host.get_ids() == (["rotten_thrower"] as Array[String]), str(host.get_ids()))
	var rt: RottenThrowerTrait = host.get_trait("rotten_thrower") as RottenThrowerTrait
	var rotten: FieldPoint = null
	for _i: int in 180:
		for p: FieldPoint in v.get_drops().get_points():
			if p.rotten:
				rotten = p
		if rotten != null:
			break
		await process_frame
	_check("m2 rotten point on the player's field", rotten != null and rt.get_throw_count() >= 1)
	if rotten != null:
		var state: CombatState = v.get_state()
		_check("m2 rotten on a player cell, not the player's", v.get_grid().is_player_cell(rotten.cell) and rotten.cell != state.player_cell, str(rotten.cell))
		var hold: HoldSlots = v.get_hold()
		var before: int = hold.get_occupied_count()
		state.set_player_cell(rotten.cell)
		_check("m2 stepping on it picks it up into a slot", hold.get_rotten_count() == 1 and hold.get_occupied_count() == before + 1)
		var idx: int = -1
		for i: int in hold.get_slot_count():
			if hold.get_point(i) == rotten:
				idx = i
		_check("m2 hand refuses to select it", idx >= 0 and hold.toggle_selected(idx) == false and not hold.is_selected(idx))
		_check("m2 not in cut selection labels", not hold.get_selected_labels().has("X") and not v.get_cut_selection_labels().has("X"))
		_check("m2 confirm not visible with only rotten", not v.is_confirm_visible())
		for _i: int in 120:
			if hold.get_rotten_count() == 0:
				break
			await process_frame
		_check("m2 rotten left the hand after rot_in_hand_sec", hold.get_rotten_count() == 0 and hold.get_point(idx) != rotten)
	# ---- restart: new trait instances
	var old_host: TraitHost = host
	var old_ids: Array[int] = []
	for tr: BossTrait in old_host.get_traits():
		old_ids.append(tr.get_instance_id())
	rc.restart_requested()
	_check("restart PLAYING", await _wait_phase(RunState.Phase.PLAYING))
	_check("restart old host torn down", old_host.size() == 0)
	v = _view()
	host = v.get_trait_host()
	_check("restart new host", host != old_host and host.size() == 1 and host.get_ids() == (["row_burner"] as Array[String]))
	var fresh: bool = true
	for tr: BossTrait in host.get_traits():
		fresh = fresh and not old_ids.has(tr.get_instance_id()) and tr.get_params().has("first_delay_sec")
	_check("restart fresh trait instances", fresh)
	var rb2: RowBurnerTrait = host.get_trait("row_burner") as RowBurnerTrait
	_check("restart trait state reset", rb2.get_burn_count() == 0 and rb2.get_warning_cells().is_empty())
	print("FAILS=%d" % fails)
	quit(fails)

extends SceneTree

var fails: int = 0
const VP: Vector2 = Vector2(1280, 720)
var reasons: Array[String] = []
var combat: CombatView
var sv: HoldSlotsView
var hold: HoldSlots
var focus: FocusController
var mover: UnitMover
var tracked: FieldPoint


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _on_ended(r: String) -> void:
	reasons.append(r)


func _click(p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		root.push_input(ev, true)
		await process_frame


func _wait_real(sec: float) -> void:
	var end: int = Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _cond_focus_active() -> bool:
	return focus.is_active()


func _cond_focus_not_ready() -> bool:
	return not focus.is_ready()


func _cond_mover_busy() -> bool:
	return not mover.is_ready()


func _cond_busy_cut() -> bool:
	return combat.get_cut_actor().is_swinging() or combat.get_cut_flow().is_menu_open()


func _wait_while(cond: Callable, limit_sec: float) -> float:
	var t0: int = Time.get_ticks_msec()
	while cond.call() and float(Time.get_ticks_msec() - t0) < limit_sec * 1000.0:
		await process_frame
	return float(Time.get_ticks_msec() - t0) / 1000.0


func _fill(n: int) -> void:
	for i: int in n:
		var p := FieldPoint.new()
		p.label = "A1"
		hold.place_in_first_free(p)


func _fresh(drops: FieldDrops) -> float:
	var total: float = 0.0
	for p: FieldPoint in drops.get_points():
		total += p.freshness_left
	return total


func _initialize() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	await process_frame
	await process_frame
	for _i: int in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	combat = battle.get_node("CombatView") as CombatView
	sv = battle.get_node("HoldSlotsView") as HoldSlotsView
	hold = sv.get_slots()
	focus = combat.get_focus()
	focus.ended.connect(_on_ended)
	var state: CombatState = combat.get_state()
	mover = combat.get_mover()
	var drops: FieldDrops = combat.get_drops()
	var boss: BossController = combat.get_boss()
	var rects: Dictionary = ScreenLayout.dpad_rects(VP)
	var confirm_c: Vector2 = ScreenLayout.confirm_button_rect(VP).get_center()
	boss.set_active(true)
	_check("focus ready at start", focus.is_ready())
	_fill(3)
	tracked = drops.debug_place("B2", Vector2i(2, 0), 30.0)
	await _wait_while(_cond_mover_busy, 3.0)

	var cell0: Vector2i = state.player_cell
	var t_start: int = Time.get_ticks_msec()
	await _click(sv.get_slot_rect(0).get_center())
	_check("tap -> focus active", focus.is_active())
	var boss_cell: Vector2i = state.enemy_cell
	var fresh0: float = _fresh(drops)
	var boss_cd: float = boss.get_mover().get_cooldown_remaining()
	var boss_fresh0: float = _fresh(boss.get_drops())
	await _wait_real(1.0)
	_check("boss cell frozen", state.enemy_cell == boss_cell)
	_check("drop freshness frozen", absf(_fresh(drops) - fresh0) < 0.0001, "%f vs %f" % [_fresh(drops), fresh0])
	_check("boss drops frozen", absf(_fresh(boss.get_drops()) - boss_fresh0) < 0.0001)
	_check("boss step cooldown frozen", absf(boss.get_mover().get_cooldown_remaining() - boss_cd) < 0.0001)
	await _click(rects[Vector2i.LEFT].get_center())
	await _click(rects[Vector2i.DOWN].get_center())
	_check("d-pad ignored while focus", state.player_cell == cell0 and mover.is_ready(), str(state.player_cell))
	_check("try_step_player false", not combat.try_step_player(Vector2i.LEFT))
	await _wait_while(_cond_focus_active, 6.0)
	var total: float = float(Time.get_ticks_msec() - t_start) / 1000.0
	_check("timeout after ~4 s real", absf(total - 4.0) < 0.5 and reasons == ["timeout"], "%f %s" % [total, str(reasons)])
	var cd_start: int = Time.get_ticks_msec()
	_check("selection kept after timeout", hold.is_selected(0))
	_check("cooldown running", focus.is_on_cooldown())
	var fresh1: float = tracked.freshness_left
	await _wait_real(0.4)
	_check("time moves again", tracked.freshness_left < fresh1 - 0.1, "%f -> %f" % [fresh1, tracked.freshness_left])
	boss.set_active(false)

	# Cooldown: reselecting does not freeze; 1-point cut works.
	await _click(sv.get_slot_rect(0).get_center())
	await _click(sv.get_slot_rect(0).get_center())
	_check("selected in cooldown, no focus", hold.is_selected(0) and not focus.is_active())
	var fresh2: float = tracked.freshness_left
	await _wait_real(0.4)
	_check("freshness decreasing during cooldown", tracked.freshness_left < fresh2 - 0.1)
	state.set_enemy_cell(Vector2i(4, 1))
	await _click(confirm_c)
	_check("1-point cut works in cooldown", combat.get_cut_actor().is_swinging() or combat.get_cut_flow().is_menu_open())
	await _wait_while(_cond_focus_not_ready, 9.0)
	var cd_total: float = float(Time.get_ticks_msec() - cd_start) / 1000.0
	_check("ready ~8 s after timeout", absf(cd_total - 8.0) < 0.7 and focus.is_ready(), str(cd_total))

	# Deselect ends it.
	await _wait_while(_cond_busy_cut, 5.0)
	_fill(3)
	reasons.clear()
	await _click(sv.get_slot_rect(1).get_center())
	_check("active again", focus.is_active())
	await _click(sv.get_slot_rect(1).get_center())
	_check("deselect ends it", not focus.is_active() and reasons == ["deselected"] and focus.is_on_cooldown(), str(reasons))
	await _wait_while(_cond_focus_not_ready, 9.0)

	# Confirm ends it.
	_fill(3)
	reasons.clear()
	await _click(sv.get_slot_rect(1).get_center())
	_check("active for confirm test", focus.is_active())
	await _click(confirm_c)
	_check("confirm ends it and starts cooldown", not focus.is_active() and reasons == ["confirmed"] and focus.is_on_cooldown(), str(reasons))
	await _wait_while(_cond_focus_not_ready, 9.0)
	await _wait_while(_cond_busy_cut, 5.0)

	# Death ends it.
	_fill(3)
	reasons.clear()
	await _click(sv.get_slot_rect(2).get_center())
	_check("active for death test", focus.is_active())
	state.damage(CombatState.Side.PLAYER, 99999.0)
	await process_frame
	await process_frame
	_check("death ends it", not focus.is_active() and reasons == ["death"], str(reasons))
	print("FAILS=%d" % fails)
	quit(fails)

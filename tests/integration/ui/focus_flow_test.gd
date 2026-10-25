extends SceneTree
## Story 024 (piece flow) + Story 012 (Focus): drives Focus with real clicks / a mouse drag.
## Windowed only: --windowed --resolution 1280x720 ... -- --no-autopause.
## Intents: selecting a piece (tap or drag) with Focus ready = full stop (boss, drops, boss step
## cooldown frozen) for ~4 s real, then 8 s cooldown; PLACING on cooldown = 0.2x (menu_time_scale),
## no Focus; d-pad locked while placing (the d-pad area is the Xoay button then: a press rotates,
## never steps), d-pad live again when not placing; Focus ends on timeout / cancel (deselected) /
## confirm / death.

var fails: int = 0
const VP: Vector2 = Vector2(1280, 720)
const BOSS_CELL: Vector2i = Vector2i(4, 1)
var reasons: Array[String] = []
var combat: CombatView
var sv: HoldSlotsView
var hold: HoldSlots
var focus: FocusController
var mover: UnitMover
var lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _on_ended(r: String) -> void:
	reasons.append(r)


func _mouse_button(p: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	root.push_input(ev, true)
	await process_frame


func _mouse_move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(ev, true)
	await process_frame


func _click(p: Vector2) -> void:
	await _mouse_button(p, true)
	await _mouse_button(p, false)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
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


# Fills every free bag slot with a bar2 piece (not square, so a rotation is visible).
func _fill() -> void:
	for i: int in hold.get_slot_count():
		if hold.get_piece(i) == null:
			var p := FieldPoint.new()
			p.uid = -100 - i
			p.freshness_left = 0.0
			p.piece = lib.make_piece("bar2", 0)
			p.label = "bar2"
			hold.place(p, i)


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
	lib = PieceLibrary.load_from_file()
	var state: CombatState = combat.get_state()
	mover = combat.get_mover()
	var drops: FieldDrops = combat.get_drops()
	var boss: BossController = combat.get_boss()
	var cut_flow: CutFlow = combat.get_cut_flow()
	var skill_cfg: SkillConfig = combat.get_skill_config()
	var rects: Dictionary = ScreenLayout.dpad_rects(VP)
	var cancel_c: Vector2 = ScreenLayout.cancel_button_rect(VP).get_center()
	var rot_rect: Rect2 = ScreenLayout.rotate_button_rect(VP)
	boss.set_active(true)
	_check("focus ready at start", focus.is_ready())
	_check("Xoay hidden / not placing at start", not combat.is_placing())
	_check("rotate button covers the d-pad buttons", rot_rect.has_point(rects[Vector2i.LEFT].get_center()) and rot_rect.has_point(rects[Vector2i.DOWN].get_center()))
	_fill()
	var tracked: FieldPoint = drops.debug_place("B2", Vector2i(2, 0), 30.0)
	await _wait_while(_cond_mover_busy, 3.0)

	# --- Tap with Focus ready: full stop.
	var cell0: Vector2i = state.player_cell
	var t_start: int = Time.get_ticks_msec()
	await _click(sv.get_slot_rect(0).get_center())
	await process_frame
	_check("tap piece -> PLACING + focus active", combat.is_placing() and focus.is_active())
	_check("focus is a full stop (scale 0)", focus.get_time_scale() == 0.0, str(focus.get_time_scale()))
	var boss_cell: Vector2i = state.enemy_cell
	var fresh0: float = _fresh(drops)
	var boss_cd: float = boss.get_mover().get_cooldown_remaining()
	var boss_fresh0: float = _fresh(boss.get_drops())
	await _wait_real(1.0)
	_check("boss cell frozen", state.enemy_cell == boss_cell)
	_check("drop freshness frozen", absf(_fresh(drops) - fresh0) < 0.0001, "%f vs %f" % [_fresh(drops), fresh0])
	_check("boss drops frozen", absf(_fresh(boss.get_drops()) - boss_fresh0) < 0.0001)
	_check("boss step cooldown frozen", absf(boss.get_mover().get_cooldown_remaining() - boss_cd) < 0.0001)
	var size0: Vector2i = combat.get_placing_piece().size()
	await _click(rects[Vector2i.LEFT].get_center())
	_check("d-pad press while placing = Xoay (rotates, no step)", combat.get_placing_piece().size() == Vector2i(size0.y, size0.x) and state.player_cell == cell0, "%s %s" % [combat.get_placing_piece().size(), state.player_cell])
	await _key(KEY_DOWN)
	_check("arrow key ignored while placing", state.player_cell == cell0 and mover.is_ready(), str(state.player_cell))
	_check("movement locked / try_step_player false", combat.is_movement_locked() and not combat.try_step_player(Vector2i.LEFT))
	await _wait_while(_cond_focus_active, 6.0)
	var total: float = float(Time.get_ticks_msec() - t_start) / 1000.0
	_check("timeout after ~4 s real", absf(total - 4.0) < 0.5 and reasons == ["timeout"], "%f %s" % [total, str(reasons)])
	var cd_start: int = Time.get_ticks_msec()
	_check("still placing after timeout (selection kept)", combat.is_placing() and hold.is_selected(0))
	_check("cooldown running", focus.is_on_cooldown())
	_check("d-pad still locked while placing on cooldown", combat.is_movement_locked())
	boss.set_active(false)

	# --- PLACING on cooldown runs at menu_time_scale (0.2x); not placing = full speed.
	var f1: float = tracked.freshness_left
	var t1: int = Time.get_ticks_msec()
	await _wait_real(1.0)
	var rate_placing: float = (f1 - tracked.freshness_left) / (float(Time.get_ticks_msec() - t1) / 1000.0)
	_check("placing on cooldown slows to ~0.2x", absf(rate_placing - skill_cfg.menu_time_scale) < 0.08, "rate=%.3f" % rate_placing)
	await _click(cancel_c)
	await process_frame
	_check("Huy: not placing, Xoay gone", not combat.is_placing() and not combat.is_movement_locked())
	var f2: float = tracked.freshness_left
	var t2: int = Time.get_ticks_msec()
	await _wait_real(0.5)
	var rate_free: float = (f2 - tracked.freshness_left) / (float(Time.get_ticks_msec() - t2) / 1000.0)
	_check("not placing: full speed", rate_free > 0.8, "rate=%.3f" % rate_free)
	var cell1: Vector2i = state.player_cell
	var expect: Vector2i = cell1 + Vector2i.LEFT if cell1.x > 0 else cell1 + Vector2i.RIGHT
	var dir: Vector2i = Vector2i.LEFT if cell1.x > 0 else Vector2i.RIGHT
	await _click(rects[dir].get_center())
	_check("d-pad steps again when not placing", state.player_cell == expect, "%s -> %s" % [cell1, state.player_cell])
	await _wait_while(_cond_mover_busy, 3.0)

	# --- Reselect on cooldown: no Focus; a piece can still be placed (drag -> menu).
	await _click(sv.get_slot_rect(1).get_center())
	await process_frame
	_check("selected on cooldown: placing, no focus", combat.is_placing() and not focus.is_active())
	await _click(cancel_c)
	state.set_enemy_cell(BOSS_CELL)
	var slot1: Vector2 = sv.get_slot_rect(1).get_center()
	var finger: Vector2 = combat.drag_point_for_cell(BOSS_CELL)
	await _mouse_button(slot1, true)
	await _mouse_move(slot1 + Vector2(0, -60))
	await _mouse_move(finger)
	_check("drag on cooldown: no focus", combat.is_dragging() and not focus.is_active())
	await _mouse_button(finger, false)
	_check("placing works on cooldown (menu open)", cut_flow.is_menu_open())
	await _wait_while(_cond_focus_not_ready, 9.0)
	var cd_total: float = float(Time.get_ticks_msec() - cd_start) / 1000.0
	_check("ready ~8 s after timeout", absf(cd_total - 8.0) < 0.7 and focus.is_ready(), str(cd_total))

	# --- Cancel (Huy) ends it: reason deselected.
	await _wait_while(_cond_busy_cut, 6.0)
	_fill()
	reasons.clear()
	await _click(sv.get_slot_rect(1).get_center())
	await process_frame
	_check("active again (tap)", focus.is_active())
	await _click(cancel_c)
	await process_frame
	_check("Huy ends it (deselected) + cooldown", not focus.is_active() and reasons == ["deselected"] and focus.is_on_cooldown(), str(reasons))
	await _wait_while(_cond_focus_not_ready, 9.0)

	# --- Drag start with Focus ready = full stop; release on the boss = confirmed.
	_fill()
	reasons.clear()
	state.set_enemy_cell(BOSS_CELL)
	await _mouse_button(slot1, true)
	await _mouse_move(slot1 + Vector2(0, -60))
	await _mouse_move(finger)
	await process_frame
	_check("drag start -> focus active (full stop)", combat.is_dragging() and focus.is_active() and focus.get_time_scale() == 0.0)
	await _mouse_button(finger, false)
	_check("release confirms: focus ended (confirmed) + cooldown", cut_flow.is_menu_open() and not focus.is_active() and reasons == ["confirmed"] and focus.is_on_cooldown(), str(reasons))
	await _click(cancel_c)
	_check("Huy in menu returns the piece", not cut_flow.is_menu_open() and hold.get_piece(1) != null)
	await _wait_while(_cond_focus_not_ready, 9.0)

	# --- Death ends it.
	_fill()
	reasons.clear()
	await _click(sv.get_slot_rect(2).get_center())
	await process_frame
	_check("active for death test", focus.is_active())
	state.damage(CombatState.Side.PLAYER, 99999.0)
	await process_frame
	await process_frame
	_check("death ends it and leaves PLACING", not focus.is_active() and reasons == ["death"] and not combat.is_placing(), str(reasons))
	print("FAILS=%d" % fails)
	print("VERDICT %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(fails)

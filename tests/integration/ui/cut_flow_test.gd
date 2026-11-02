extends SceneTree
## Story 024 (piece flow): drives the real cut flow with mouse / touch events (local coords).
## Windowed only: --windowed --resolution 1280x720 ... -- --no-autopause.
## Intents (2026-11-01 flow, quick spec menu-la-giua-man-hinh): select a piece (tap / drag), drag with lift onto
## the boss, release -> the place window (no cards) -> Tung phép -> card menu with the piece cells -> card -> swing
## with exactly those cells; locked card ignored; Huy returns the piece; release off the board returns it; Xoay by
## a second finger mid-drag; tap-step fallback; the place window runs out -> Tung phép pressed automatically; menu
## timeout picks the default card; confirm during a swing does nothing.

var fails: int = 0
const VP: Vector2 = Vector2(1280, 720)
const BOSS_CELL: Vector2i = Vector2i(4, 1)


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


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


# Left-mouse drag from a bag slot to [param to] (lifted ghost), released there.
func _mouse_drag(from: Vector2, to: Vector2) -> void:
	await _mouse_button(from, true)
	await _mouse_move(from + Vector2(0, -60))
	await _mouse_move(to)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = pos
	root.push_input(ev, true)
	await process_frame


func _touch_drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	root.push_input(ev, true)
	await process_frame


func _wait_real(sec: float) -> void:
	var end: int = Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _put(hold: HoldSlots, lib: PieceLibrary, shape: String, slot: int) -> void:
	var p := FieldPoint.new()
	p.uid = -100 - slot
	p.freshness_left = 0.0
	p.piece = lib.make_piece(shape, 0)
	p.label = shape
	hold.place(p, slot)


func _shape(hold: HoldSlots, slot: int) -> String:
	var piece: Piece = hold.get_piece(slot)
	return "" if piece == null else piece.shape_id


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = cells.duplicate()
	out.sort()
	return out


func _initialize() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	var game_flow := main.get_node("GameFlow") as GameFlow
	game_flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	# The shipped hero, so the window shows the real sprite (not the character-less placeholder).
	game_flow.set_character("kiem_si")
	var rc: RunController = game_flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	await process_frame
	await process_frame
	for _i: int in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	var combat := battle.get_node("CombatView") as CombatView
	# The timings below are the normal card time (3 s place window); the player's real user://settings.json may hold
	# "6 s" or "no limit", so the match is pinned to normal whatever the file says.
	combat.set_card_time(SettingsStore.CARD_TIME_NORMAL)
	var sv := battle.get_node("HoldSlotsView") as HoldSlotsView
	var hold: HoldSlots = sv.get_slots()
	var state: CombatState = combat.get_state()
	combat.get_boss().set_active(false)
	var actor: CutActor = combat.get_cut_actor()
	var flow: CutFlow = combat.get_cut_flow()
	combat._deck = Deck.from_array(["kiem_khi", "chan_phong", "hoa_tran", "bang_phong"] as Array[String], 1)
	var cds: SkillCooldowns = combat.get_skill_cooldowns()
	var drops: FieldDrops = combat.get_drops()
	var skill_cfg: SkillConfig = combat.get_skill_config()
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var cast_c: Vector2 = ScreenLayout.confirm_button_rect(VP).get_center()
	var rot_c: Vector2 = ScreenLayout.rotate_button_rect(VP).get_center()
	var off_board: Vector2 = Vector2(40, 400)

	drops.pick_up_at(state.player_cell, true)
	for i: int in hold.get_slot_count():
		hold.remove(i)
	_check("bag has 3 slots", hold.get_slot_count() == 3, str(hold.get_slot_count()))
	_put(hold, lib, "plus5", 0)
	_put(hold, lib, "bar2", 1)
	_put(hold, lib, "mono", 2)
	state.set_enemy_cell(BOSS_CELL)
	await process_frame
	var slot0: Vector2 = sv.get_slot_rect(0).get_center()
	var slot1: Vector2 = sv.get_slot_rect(1).get_center()
	var slot2: Vector2 = sv.get_slot_rect(2).get_center()
	var boss_finger: Vector2 = combat.drag_point_for_cell(BOSS_CELL)
	_check("not placing / confirm hidden with nothing selected", not combat.is_placing() and not combat.is_confirm_visible())

	# --- Tap selects; tapping another slot switches; Huy leaves PLACING with the piece kept.
	await _click(slot1)
	_check("tap slot selects the piece (PLACING)", combat.is_placing() and combat.get_placing_piece().shape_id == "bar2")
	_check("confirm visible while placing", combat.is_confirm_visible())
	await _click(slot0)
	_check("tap other slot switches piece", combat.is_placing() and combat.get_placing_piece().shape_id == "plus5")
	await _click(ScreenLayout.cancel_button_rect(VP, flow.is_menu_open()).get_center())
	_check("Huy leaves PLACING, piece stays", not combat.is_placing() and _shape(hold, 0) == "plus5")

	# --- Mouse drag bar2 onto the boss (lift), release -> menu with the piece cells.
	await _mouse_drag(slot1, boss_finger)
	_check("drag started (mouse)", combat.is_dragging())
	var ghost: Array[Vector2i] = combat.get_placement().get_cells().duplicate()
	_check("ghost on the boss cell, 2 cells", ghost.size() == 2 and ghost.has(BOSS_CELL), str(ghost))
	_check("ghost aims above the finger (lift)", combat.get_drag_lift_px() > 0.0 and ScreenLayout.cell_at(combat.get_grid(), VP, boss_finger) != BOSS_CELL)
	await _mouse_button(boss_finger, false)
	_check("release on board commits the piece: place window, NO card menu", combat.is_placed() and not flow.is_menu_open() and flow.get_hand().is_empty())
	_check("placed cells == ghost cells", _sorted(combat.get_cast_plan().cells()) == _sorted(ghost), str(combat.get_cast_plan().cells()))
	_check("piece left the bag, others kept", hold.get_piece(1) == null and _shape(hold, 0) == "plus5" and _shape(hold, 2) == "mono")
	_check("no swing before a card is chosen", not actor.is_swinging())

	var fp: FieldPoint = drops.debug_place("B2", Vector2i(0, 0), 5.0)
	var t0: int = Time.get_ticks_msec()
	await _wait_real(1.0)
	var real_s: float = float(Time.get_ticks_msec() - t0) / 1000.0
	var lost: float = 5.0 - fp.freshness_left
	_check("place window slows the sim (freshness lost << real time)", lost < real_s * 0.5 and lost > 0.0, "real=%.2f lost=%.2f" % [real_s, lost])
	_check("still no menu 1 s into the place window", combat.is_placed() and not flow.is_menu_open())
	await _click(cast_c)
	_check("tap Tung phép opens the menu with the piece cells", flow.is_menu_open() and _sorted(flow.get_cells()) == _sorted(ghost), str(flow.get_cells()))

	var order: Array[String] = combat.get_hand()
	_check("hand holds the 4-card deck", order.size() == 4 and combat.get_deck().size() == 4, str(order))
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(VP, order.size())
	await _click(rects[order.find("bang_phong")].get_center())
	_check("locked card (needs >2 cells) ignored, menu stays", flow.is_menu_open() and not actor.is_swinging())
	await _click(ScreenLayout.cancel_button_rect(VP, flow.is_menu_open()).get_center())
	_check("Huy in menu returns the piece to its slot", not flow.is_menu_open() and _shape(hold, 1) == "bar2" and not actor.is_swinging())

	# --- Drag plus5 onto the boss, choose push: swing uses exactly the piece cells.
	await _mouse_drag(slot0, boss_finger)
	ghost = combat.get_placement().get_cells().duplicate()
	await _mouse_button(boss_finger, false)
	_check("plus5 placed: place window, no menu yet", combat.is_placed() and not flow.is_menu_open())
	await _click(cast_c)
	_check("plus5 placed + Tung phép: menu open with 5 cells", flow.is_menu_open() and flow.get_cells().size() == 5, str(flow.get_cells()))
	order = combat.get_hand()
	rects = ScreenLayout.skill_menu_rects(VP, order.size())
	await _click(rects[order.find("chan_phong")].get_center())
	_check("push chosen: menu closed, swing running", not flow.is_menu_open() and actor.is_swinging())
	_check("swing cells == placed piece cells", _sorted(actor.get_cells()) == _sorted(ghost), str(actor.get_cells()))
	_check("push cooldown started", not cds.is_ready("chan_phong") and cds.remaining("chan_phong") > 5.0, "%.2f" % cds.remaining("chan_phong"))
	_check("piece spent", hold.get_piece(0) == null)

	# --- Confirm during a swing does nothing (tap-step: select, aim, tap ghost).
	await _click(slot1)
	await _click(ScreenLayout.cell_center(combat.get_grid(), VP, BOSS_CELL))
	await _click(ScreenLayout.cell_center(combat.get_grid(), VP, BOSS_CELL))
	_check("confirm during swing does nothing", not flow.is_menu_open() and not combat.is_placed() and _shape(hold, 1) == "bar2" and actor.is_swinging())
	await _click(cast_c)
	_check("Tung phép during a swing does nothing", not flow.is_menu_open() and not combat.is_placed() and actor.is_swinging())
	await _click(ScreenLayout.cancel_button_rect(VP, flow.is_menu_open()).get_center())

	var guard: int = 0
	while actor.is_swinging() and guard < 900:
		await process_frame
		guard += 1
	_check("swing resolved", not actor.is_swinging())
	_check("push damage 20 (5 cells x 4 dmg/cell, Story 020)", is_equal_approx(state.enemy_hp, state.enemy_max_hp - 20.0), str(state.enemy_hp))
	_check("boss pushed away from divider", state.enemy_cell == Vector2i(5, 1), str(state.enemy_cell))
	state.set_enemy_cell(BOSS_CELL)
	await process_frame

	# --- Release off the board: piece goes back.
	await _mouse_drag(slot2, boss_finger)
	_check("mono drag started", combat.is_dragging())
	await _mouse_move(off_board)
	await _mouse_button(off_board, false)
	_check("release off board: not placing, no menu", not combat.is_placing() and not flow.is_menu_open())
	_check("release off board: piece back in slot", _shape(hold, 2) == "mono")

	# --- Touch: finger 0 drags bar2, finger 1 presses Xoay mid-drag, release -> rotated cells.
	await _touch(0, slot1, true)
	await _touch_drag(0, slot1 + Vector2(0, -60))
	await _touch_drag(0, boss_finger)
	_check("touch drag started", combat.is_dragging())
	var size0: Vector2i = combat.get_placing_piece().size()
	await _touch(1, rot_c, true)
	await _touch(1, rot_c, false)
	_check("Xoay (finger 1) rotated mid-drag", combat.get_placing_piece().size() == Vector2i(size0.y, size0.x) and size0.x != size0.y, "%s -> %s" % [size0, combat.get_placing_piece().size()])
	_check("drag not cancelled by Xoay", combat.is_dragging())
	await _touch_drag(0, boss_finger + Vector2(2, 0))
	await _touch(0, boss_finger + Vector2(2, 0), false)
	_check("touch release committed the piece (no menu yet)", combat.is_placed() and not flow.is_menu_open())
	await _touch(0, cast_c, true)
	await _touch(0, cast_c, false)
	var xs: Dictionary = {}
	for c: Vector2i in flow.get_cells():
		xs[c.x] = true
	_check("touch tap on Tung phép opened the menu with the rotated (vertical) bar", flow.is_menu_open() and flow.get_cells().size() == 2 and xs.size() == 1 and flow.get_cells().has(BOSS_CELL), str(flow.get_cells()))
	order = combat.get_hand()
	rects = ScreenLayout.skill_menu_rects(VP, order.size())
	await _touch(0, rects[order.find("kiem_khi")].get_center(), true)
	await _touch(0, rects[order.find("kiem_khi")].get_center(), false)
	_check("touch card choice starts the swing", not flow.is_menu_open() and actor.is_swinging() and actor.get_skill_id() == "kiem_khi")
	guard = 0
	while actor.is_swinging() and guard < 900:
		await process_frame
		guard += 1

	# --- Tap-step fallback with mono, then menu timeout auto-picks the default card.
	state.set_enemy_cell(BOSS_CELL)
	await _click(slot2)
	_check("tap-step: mono selected", combat.is_placing() and not combat.is_dragging())
	var aim: Vector2i = BOSS_CELL + Vector2i(1, 0)
	await _click(ScreenLayout.cell_center(combat.get_grid(), VP, aim))
	_check("tap-step: tap cell aims the ghost, no menu", combat.get_placement().get_cells() == [aim] and not flow.is_menu_open(), str(combat.get_placement().get_cells()))
	_check("ghost off the boss reports a miss", not combat.get_placement().hits(state.enemy_cell))
	await _click(ScreenLayout.cell_center(combat.get_grid(), VP, BOSS_CELL))
	_check("tap-step: re-aim onto the boss reports a hit", combat.get_placement().get_cells() == [BOSS_CELL] and combat.get_placement().hits(state.enemy_cell) and not flow.is_menu_open())
	await _click(ScreenLayout.cell_center(combat.get_grid(), VP, BOSS_CELL))
	_check("tap-step: tap ghost commits it -> place window, no menu", combat.is_placed() and not flow.is_menu_open() and combat.get_cast_plan().cells() == [BOSS_CELL], str(combat.get_cast_plan().cells()))
	var t_place: int = Time.get_ticks_msec()
	while combat.is_placed() and Time.get_ticks_msec() - t_place < int((combat.get_place_duration() + 1.0) * 1000.0):
		await process_frame
	var waited_place: float = float(Time.get_ticks_msec() - t_place) / 1000.0
	_check("place window ran out: Tung phép pressed automatically", flow.is_menu_open() and flow.get_cells() == [BOSS_CELL], str(flow.get_cells()))
	_check("place window closed after ~place_window_sec", absf(waited_place - combat.get_cut_config().place_window_sec) < 0.6, "%.2f" % waited_place)
	var t_menu: int = Time.get_ticks_msec()
	while flow.is_menu_open() and Time.get_ticks_msec() - t_menu < int((skill_cfg.menu_choose_sec + 1.0) * 1000.0):
		await process_frame
	var waited: float = float(Time.get_ticks_msec() - t_menu) / 1000.0
	_check("timeout auto-chose slash on the piece cell", not flow.is_menu_open() and actor.is_swinging() and actor.get_skill_id() == "kiem_khi" and actor.get_cells() == [BOSS_CELL], "%s %s after %.2fs" % [actor.get_skill_id(), str(actor.get_cells()), waited])
	_check("menu closed by its timeout (~menu_choose_sec)", absf(waited - skill_cfg.menu_choose_sec) < 0.6, "%.2f" % waited)
	print("FAILS=%d" % fails)
	print("VERDICT %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(fails)

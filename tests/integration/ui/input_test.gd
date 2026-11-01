extends SceneTree
## Story 024 (piece flow): drives the real main scene with pointer / touch / key events (local coords).
## Windowed only: --windowed --resolution 1280x720 ... -- --no-autopause.
## Intents: d-pad steps (one cell, cooldown, no queue, wall), stepping on a piece picks it into the
## bag (full bag leaves it on the field), slot tap selects / tap again rotates / empty or rotten slot
## does nothing (mouse and touch), desktop extras 1-3 / R / Esc (placing and menu), and no hover
## dependence (a buttonless mouse motion never moves the ghost or selects).

var fails: int = 0
const VP: Vector2 = Vector2(1280, 720)
const BOSS_CELL: Vector2i = Vector2i(4, 1)


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _click(p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		root.push_input(ev, true)
		await process_frame


func _hover(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	ev.relative = Vector2(5, 5)
	root.push_input(ev, true)
	await process_frame


func _tap(index: int, p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = index
		ev.pressed = pressed
		ev.position = p
		root.push_input(ev, true)
		await process_frame


func _touch(index: int, p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = p
	root.push_input(ev, true)
	await process_frame


func _touch_drag(index: int, p: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = p
	root.push_input(ev, true)
	await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		root.push_input(ev, true)
		await process_frame


func _wait_ready(mover: UnitMover) -> void:
	var guard: int = 0
	while not mover.is_ready() and guard < 600:
		await process_frame
		guard += 1


func _shape(hold: HoldSlots, slot: int) -> String:
	var piece: Piece = hold.get_piece(slot)
	return "" if piece == null else piece.shape_id


func _drop_at(drops: FieldDrops, cell: Vector2i) -> bool:
	for p: FieldPoint in drops.get_points():
		if p.cell == cell:
			return true
	return false


# Determinism: the field drops use a random seed, so a random piece could land on a cell the player
# steps on and be picked into the bag before the suite expects. Every player-half cell is cleared and
# BLOCKED (FieldDrops.set_blocked_cells: nothing spawns there, nothing can be picked up); a section
# that wants a piece on a cell opens just that cell (see _open_cell) and places the piece itself.
func _lock_field(drops: FieldDrops, grid: BoardGrid) -> void:
	for cell: Vector2i in grid.player_cells():
		drops.pick_up_at(cell, true)
	drops.set_blocked_cells(grid.player_cells())


# Unblocks only [param cell] and puts a fresh [param piece] there.
func _open_cell(drops: FieldDrops, grid: BoardGrid, cell: Vector2i, piece: Piece) -> void:
	var blocked: Array[Vector2i] = grid.player_cells()
	blocked.erase(cell)
	drops.set_blocked_cells(blocked)
	drops.pick_up_at(cell, true)
	drops.debug_place_piece(piece, cell, 5.0)


func _initialize() -> void:
	# Story 044: these suites click the 3x3 pad; the default control is the floating joystick.
	SettingsStore.set_movement_override(SettingsStore.MOVEMENT_PAD)
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	# The shipped hero, so the window shows the real sprite (not the character-less placeholder).
	flow.set_character("kiem_si")
	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	await process_frame
	await process_frame
	for _i: int in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	var combat := battle.get_node("CombatView") as CombatView
	var slots_view := battle.get_node("HoldSlotsView") as HoldSlotsView
	var state: CombatState = combat.get_state()
	var mover: UnitMover = combat.get_mover()
	var drops: FieldDrops = combat.get_drops()
	var hold: HoldSlots = slots_view.get_slots()
	var cut_flow: CutFlow = combat.get_cut_flow()
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var rects: Dictionary = ScreenLayout.dpad_rects(VP)
	combat.get_boss().set_active(false)
	for i: int in hold.get_slot_count():
		hold.remove(i)
	_lock_field(drops, combat.get_grid())
	_check("field locked: no piece on the field, bag empty", drops.get_points().is_empty() and hold.is_empty(), str(drops.get_points().size()))

	# --- D-pad.
	_check("start cell (1,1)", state.player_cell == Vector2i(1, 1), str(state.player_cell))
	await _click(rects[Vector2i.LEFT].get_center())
	_check("LEFT press moves exactly one cell", state.player_cell == Vector2i(0, 1), str(state.player_cell))
	await _click(rects[Vector2i.RIGHT].get_center())
	_check("press during cooldown ignored", state.player_cell == Vector2i(0, 1), str(state.player_cell))
	await _wait_ready(mover)
	_check("queued press did NOT fire after cooldown", state.player_cell == Vector2i(0, 1), str(state.player_cell))
	await _click(rects[Vector2i.RIGHT].get_center())
	_check("RIGHT after cooldown moves one cell", state.player_cell == Vector2i(1, 1), str(state.player_cell))
	await _wait_ready(mover)

	# --- Stepping on a piece picks it up (the field is locked; only this cell is opened).
	_open_cell(drops, combat.get_grid(), Vector2i(1, 0), lib.make_piece("l3", 0))
	await _click(rects[Vector2i.UP].get_center())
	_check("stepping on piece moved player", state.player_cell == Vector2i(1, 0), str(state.player_cell))
	_check("piece picked into slot 0", _shape(hold, 0) == "l3", _shape(hold, 0))
	_check("picked piece left the field", not _drop_at(drops, Vector2i(1, 0)))
	await _wait_ready(mover)
	await _click(rects[Vector2i.UP].get_center())
	_check("wall step rejected", state.player_cell == Vector2i(1, 0), str(state.player_cell))
	_check("rejected step starts no cooldown", mover.is_ready())
	await _key(KEY_DOWN)
	_check("DOWN arrow key steps one cell", state.player_cell == Vector2i(1, 1), str(state.player_cell))
	await _wait_ready(mover)

	# --- Slot taps (mouse): select, tap again rotates, empty / rotten slot does nothing.
	var bar := FieldPoint.new()
	bar.uid = -201
	bar.piece = lib.make_piece("bar3", 0)
	bar.label = "bar3"
	hold.place(bar, 1)
	var slot0: Vector2 = slots_view.get_slot_rect(0).get_center()
	var slot1: Vector2 = slots_view.get_slot_rect(1).get_center()
	var slot2: Vector2 = slots_view.get_slot_rect(2).get_center()
	_check("bag has 3 slots", hold.get_slot_count() == 3, str(hold.get_slot_count()))
	await _hover(slot0)
	_check("hover over a slot selects nothing", not combat.is_placing())
	await _click(slot0)
	_check("tap selects occupied slot (PLACING)", combat.is_placing() and hold.is_selected(0))
	var r0: int = combat.get_placing_piece().rotation
	await _click(slot0)
	_check("second tap rotates (stays selected)", combat.is_placing() and combat.get_placing_piece().rotation == (r0 + 1) % 4, str(combat.get_placing_piece().rotation))
	_check("bag slot shows the rotation", hold.get_piece(0).rotation == (r0 + 1) % 4)
	await _click(slot2)
	_check("tap on empty slot does nothing", combat.is_placing() and hold.is_selected(0) and not hold.is_selected(2))

	# --- No hover dependence: a buttonless motion over the board never moves the ghost.
	var grid: BoardGrid = combat.get_grid()
	# Tap a cell OUTSIDE the current ghost (a tap on the ghost would confirm).
	var aim: Vector2i = BoardGrid.NO_CELL
	for cand: Vector2i in [Vector2i(5, 2), Vector2i(3, 0), Vector2i(5, 0), Vector2i(3, 2)]:
		if not combat.get_placement().get_cells().has(cand) and combat.get_placement().get_target() != cand:
			aim = cand
			break
	await _click(ScreenLayout.cell_center(grid, VP, aim))
	var target: Vector2i = combat.get_placement().get_target()
	_check("tap on a board cell aims the ghost", target == aim and not cut_flow.is_menu_open(), "%s aim=%s" % [target, aim])
	await _hover(ScreenLayout.cell_center(grid, VP, Vector2i(3, 1)))
	await _hover(ScreenLayout.cell_center(grid, VP, Vector2i(5, 1)))
	_check("hover does not move the ghost", combat.get_placement().get_target() == target and not cut_flow.is_menu_open(), str(combat.get_placement().get_target()))

	# --- Keys: Esc cancels placing, 1-3 select, R rotates.
	await _key(KEY_ESCAPE)
	_check("Esc cancels placing, piece kept", not combat.is_placing() and _shape(hold, 0) == "l3")
	await _key(KEY_2)
	_check("key 2 selects slot 1", combat.is_placing() and hold.is_selected(1) and combat.get_placing_piece().shape_id == "bar3")
	var s0: Vector2i = combat.get_placing_piece().size()
	await _key(KEY_R)
	_check("R rotates", combat.get_placing_piece().size() == Vector2i(s0.y, s0.x), "%s -> %s" % [s0, combat.get_placing_piece().size()])
	await _key(KEY_1)
	_check("key 1 switches to slot 0", combat.is_placing() and hold.is_selected(0) and not hold.is_selected(1))
	await _key(KEY_3)
	_check("key 3 on empty slot keeps slot 0", combat.is_placing() and hold.is_selected(0))

	# --- Esc in the card menu returns the piece (2026-11-01: tap ghost commits it, Tung phép opens the menu).
	state.set_enemy_cell(BOSS_CELL)
	await _click(ScreenLayout.cell_center(grid, VP, BOSS_CELL))
	if not combat.is_placed():
		await _click(ScreenLayout.cell_center(grid, VP, BOSS_CELL))
	_check("tap ghost committed the piece (place window, no menu)", combat.is_placed() and not cut_flow.is_menu_open() and hold.get_piece(0) == null)
	await _click(ScreenLayout.confirm_button_rect(VP).get_center())
	_check("click on Tung phép opened the menu", cut_flow.is_menu_open() and hold.get_piece(0) == null)
	await _key(KEY_ESCAPE)
	_check("Esc closes the menu and returns the piece", not cut_flow.is_menu_open() and _shape(hold, 0) == "l3" and not combat.get_cut_actor().is_swinging())
	_check("not placing after Esc in menu", not combat.is_placing())

	# --- 2026-11-01 desktop extras: Enter presses Tung phép, key 1..4 picks the card in that place.
	await _key(KEY_1)
	await _click(ScreenLayout.cell_center(grid, VP, BOSS_CELL))
	if not combat.is_placed():
		await _click(ScreenLayout.cell_center(grid, VP, BOSS_CELL))
	await _key(KEY_ENTER)
	_check("Enter presses Tung phép (menu open)", cut_flow.is_menu_open())
	var picked: int = -1
	var hand_now: Array[String] = cut_flow.get_hand()
	for i: int in hand_now.size():
		if bool(SkillAvailability.check(combat.get_skill_config(), combat.get_skill_cooldowns(), hand_now[i], cut_flow.get_cells().size())["available"]):
			picked = i
			break
	_check("an available card in the hand", picked >= 0, str(hand_now))
	await _key((KEY_1 + picked) as Key)
	_check("key %d picks that card (swing started)" % (picked + 1), not cut_flow.is_menu_open() and combat.get_cut_actor().is_swinging() 		and combat.get_cut_actor().get_skill_id() == hand_now[picked], combat.get_cut_actor().get_skill_id())
	combat.get_arbiter().tick(combat.get_cut_actor().get_time_left() + 0.01)
	var l3 := FieldPoint.new()
	l3.uid = -203
	l3.piece = lib.make_piece("l3", 0)
	l3.label = "l3"
	hold.place(l3, 0)

	# --- Rotten piece: never selectable (tap or key).
	var rot := FieldPoint.new()
	rot.uid = -202
	rot.piece = Piece.make_rotten()
	rot.label = Piece.ROTTEN_ID
	rot.rotten = true
	rot.rot_in_hand_sec = 60.0
	hold.place(rot, 2)
	await _click(slot2)
	_check("tap on rotten piece does nothing", not combat.is_placing())
	await _key(KEY_3)
	_check("key 3 on rotten piece does nothing", not combat.is_placing())

	# --- Touch: tap selects, touch drag released off the board puts the piece back.
	await _tap(0, slot1)
	_check("touch tap selects slot 1", combat.is_placing() and hold.is_selected(1))
	await _key(KEY_ESCAPE)
	await _touch(0, slot1, true)
	await _touch_drag(0, slot1 + Vector2(0, -60))
	await _touch_drag(0, combat.drag_point_for_cell(BOSS_CELL))
	_check("touch drag started", combat.is_dragging())
	await _touch_drag(0, Vector2(40, 400))
	await _touch(0, Vector2(40, 400), false)
	_check("touch release off board: piece back, not placing", not combat.is_placing() and _shape(hold, 1) == "bar3" and not cut_flow.is_menu_open())

	# --- Full bag: stepping on a piece leaves it on the field.
	_check("hand is full (3 slots)", hold.is_full())
	await _wait_ready(mover)
	_open_cell(drops, grid, Vector2i(2, 1), lib.make_piece("mono", 0))
	await _click(rects[Vector2i.RIGHT].get_center())
	_check("stepped onto the piece cell", state.player_cell == Vector2i(2, 1), str(state.player_cell))
	_check("full bag: piece stays on field", _drop_at(drops, Vector2i(2, 1)))
	print("FAILS=%d" % fails)
	print("VERDICT %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(fails)

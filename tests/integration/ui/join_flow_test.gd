extends SceneTree
## Story 028 (join up to 2 pieces per cast + featured shape): drives the real battle with touch / mouse
## events (local coords). Windowed only: --windowed --resolution 1280x720 ... -- --no-autopause.
## Intents (2026-11-01 flow, quick spec menu-la-giua-man-hinh): drag piece 1 onto the boss -> the place window
## (NO card menu); drag piece 2 before Tung phép (ghost avoids piece 1, Xoay by a second finger mid-drag, release
## attaches: union cells, no time added); overlap never attaches; tap piece 2 on the board detaches it; tap
## Tung phép -> the menu ("needs N cells" locks on the placed cells; no piece joins while it is open); choose a card
## -> swing = union, both pieces spent; Huy returns BOTH pieces (place window and menu); featured join -> glow +
## x mult + effect applied once; non-featured / single piece never gets the bonus; max_cast_cells refuses (in-memory
## config change only). The match's featured shape is replaced by a known 3x2 block (test seam).

var fails: int = 0
const VP: Vector2 = Vector2(1280, 720)
const BOSS_CELL: Vector2i = Vector2i(4, 1)

var combat: CombatView
var sv: HoldSlotsView
var hud: CutHudView
var hold: HoldSlots
var flow: CutFlow
var lib: PieceLibrary
var state: CombatState


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


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


func _tap(index: int, pos: Vector2) -> void:
	await _touch(index, pos, true)
	await _touch(index, pos, false)


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


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		root.push_input(ev, true)
		await process_frame


# Finger [param index] presses bag slot [param slot], lifts the piece and drags it to [param cell];
# released there when [param release].
func _touch_drag_piece(index: int, slot: int, cell: Vector2i, release: bool) -> void:
	var start: Vector2 = sv.get_slot_rect(slot).get_center()
	await _touch(index, start, true)
	await _touch_drag(index, start + Vector2(0, -80))
	await _touch_drag(index, combat.drag_point_for_cell(cell))
	if release:
		await _touch(index, combat.drag_point_for_cell(cell), false)


func _mouse_drag_piece(slot: int, cell: Vector2i, release: bool) -> void:
	var start: Vector2 = sv.get_slot_rect(slot).get_center()
	await _mouse_button(start, true)
	await _mouse_move(start + Vector2(0, -80))
	await _mouse_move(combat.drag_point_for_cell(cell))
	if release:
		await _mouse_button(combat.drag_point_for_cell(cell), false)


func _fill_bag() -> void:
	if flow.is_menu_open() or combat.is_placing() or combat.is_placed():
		combat.cancel_placement()
		combat.cancel_placement()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	var specs: Array = [[0, "bar3"], [1, "bar2"], [2, "mono"]]
	for spec: Array in specs:
		var p := FieldPoint.new()
		p.uid = -100 - int(spec[0])
		p.freshness_left = 0.0
		p.piece = lib.make_piece(str(spec[1]), 0)
		p.label = str(spec[1])
		hold.place(p, int(spec[0]))


func _shape(slot: int) -> String:
	var piece: Piece = hold.get_piece(slot)
	return "" if piece == null else piece.shape_id


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = cells.duplicate()
	out.sort()
	return out


func _disjoint(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	for c: Vector2i in a:
		if b.has(c):
			return false
	return true


func _card_center(id: String) -> Vector2:
	var order: Array[String] = combat.get_hand()
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(VP, order.size())
	var i: int = order.find(id)
	if i < 0:
		_check("card %s is in the hand" % id, false, str(order))
		return Vector2.ZERO
	return rects[i].get_center()


# Resolves the running player swing at once (the arbiter runs the swing to its end).
func _resolve_swing() -> void:
	combat.get_arbiter().tick(10.0)
	await process_frame


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
	combat = battle.get_node("CombatView") as CombatView
	# The user's real settings file may hold another card time: pin the normal one (the place window is timed).
	combat.set_card_time(SettingsStore.CARD_TIME_NORMAL)
	sv = battle.get_node("HoldSlotsView") as HoldSlotsView
	hud = battle.get_node("CutHudView") as CutHudView
	hold = sv.get_slots()
	state = combat.get_state()
	flow = combat.get_cut_flow()
	lib = PieceLibrary.load_from_file()
	combat.get_boss().set_active(false)
	var cfg: CombatConfig = combat.get_config()
	var actor: CutActor = combat.get_cut_actor()
	var plan: CastPlan = combat.get_cast_plan()
	var skill_cfg: SkillConfig = combat.get_skill_config()
	var rot_c: Vector2 = ScreenLayout.rotate_button_rect(VP).get_center()
	var cast_c: Vector2 = ScreenLayout.confirm_button_rect(VP).get_center()
	var sc: int = combat.get_grid().side_cols
	var cell_a := Vector2i(sc + 1, 1)  # bar3 across the boss row (the enemy half is 3 wide)
	var cell_b := Vector2i(sc, 2)      # bar2 under the left end of bar3
	var cell_far := Vector2i(sc + 1, 0) # bar2 on the top row, shifted right (mirror of the block)

	# Determinism: nothing spawns on / can be picked from the player half; fixed deck; boss stays put.
	var drops: FieldDrops = combat.get_drops()
	for cell: Vector2i in combat.get_grid().player_cells():
		drops.pick_up_at(cell, true)
	drops.set_blocked_cells(combat.get_grid().player_cells())
	combat._deck = Deck.from_array(["kiem_khi", "chan_phong", "dai_dao", "kiem_vu"] as Array[String], 1)
	# Known featured shape: the 3x2 block (bar3 over bar2), mult 1.5 + one Ran stack.
	var block: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var bonus: Dictionary = {"damage_mult": 1.5, "effect": "fragile", "stacks": 1, "sec": 0.0}
	combat._featured = {"cells": block, "bonus": bonus}
	state.set_enemy_cell(BOSS_CELL)
	_check("test board: max_pieces_per_cast 2, no cell cap", cfg.max_pieces_per_cast == 2 and cfg.max_cast_cells == 0)
	_fill_bag()
	await process_frame

	# --- Piece 1 (finger 0): release on the boss row commits it: the place window starts, NO card menu.
	await _touch_drag_piece(0, 0, cell_a, true)
	_check("piece 1 release commits it: place window, no card menu", combat.is_placed() and not flow.is_menu_open() and plan.piece_count() == 1 and flow.get_hand().is_empty())
	_check("placed cells == piece 1 (bar3 across row 1)", _sorted(plan.cells()) == [Vector2i(sc, 1), Vector2i(sc + 1, 1), Vector2i(sc + 2, 1)], str(plan.cells()))
	_check("slot 0 spent, bag still live", hold.get_piece(0) == null and _shape(1) == "bar2" and combat.can_join_piece())
	_check("Tung phép button shown", combat.is_confirm_visible() and combat.can_cast())

	# --- Piece 2 (finger 0) dragged in the place window; finger 1 taps Xoay mid-drag.
	await _touch_drag_piece(0, 1, cell_a, false)
	_check("piece 2 drag started in the place window", combat.is_dragging() and combat.is_placing())
	var ghost: Array[Vector2i] = combat.get_placement().get_cells()
	_check("lifted ghost (finger over piece 1) avoids piece 1 cells", ghost.size() == 2 and _disjoint(ghost, plan.cells()), str(ghost))
	# Controls v3: no resonance while the pieces do not tile the featured shape (the plain total reads instead).
	await process_frame
	await process_frame
	_check("controls v3: no resonance label before a match", not hud.get_board_labels().has("resonance") and hud.get_board_labels().has("total"), str(hud.get_board_labels()))
	var size0: Vector2i = combat.get_placing_piece().size()
	await _tap(1, rot_c)
	_check("Xoay by finger 1 rotated the dragged piece, drag alive", combat.is_dragging() and combat.get_placing_piece().size() == Vector2i(size0.y, size0.x) and size0.x != size0.y, "%s -> %s" % [size0, combat.get_placing_piece().size()])
	await _tap(1, rot_c)
	await _touch_drag(0, combat.drag_point_for_cell(cell_b))
	_check("ghost on the block spot reports featured while dragging", combat.joined_is_featured(combat.get_placement().get_cells()), str(combat.get_placement().get_cells()))
	await process_frame
	await process_frame
	_check("controls v3: resonance label (gold, no total) while the ghost completes the shape", hud.get_board_labels().has("resonance") and not hud.get_board_labels().has("total"), str(hud.get_board_labels()))
	_check("controls v3: resonance text names the multiplier, cells and damage", hud.resonance_label_text(1.5, 5, 45).contains("5") and hud.resonance_label_text(1.5, 5, 45).contains("45"), hud.resonance_label_text(1.5, 5, 45))
	var t_pre: float = combat.get_place_time_left()
	await _touch(0, combat.drag_point_for_cell(cell_b), false)
	var t_post: float = combat.get_place_time_left()
	_check("release attaches piece 2: 2 pieces, union 5 cells, still no menu", plan.piece_count() == 2 and plan.cells().size() == 5 and not combat.is_placing() and not flow.is_menu_open(), str(plan.cells()))
	_check("a join adds no time (the +1.5 s rule is gone)", t_post <= t_pre + 0.001 and t_post > 0.0, "pre=%.2f post=%.2f" % [t_pre, t_post])
	_check("slot 1 spent", hold.get_piece(1) == null)
	_check("glow state: plan is featured (block)", combat.is_plan_featured())
	await process_frame
	await process_frame
	_check("controls v3: resonance label kept in the place window", hud.get_board_labels().has("resonance"), str(hud.get_board_labels()))

	# --- Tap piece 2 on the board: detached to its slot, cells shrink, still in the place window.
	var p2cell: Vector2i = plan.piece_cells(1)[0]
	await _tap(0, ScreenLayout.cell_center(combat.get_grid(), VP, p2cell))
	_check("tap on piece 2 detaches it back to its slot", plan.piece_count() == 1 and plan.cells().size() == 3 and _shape(1) == "bar2" and combat.is_placed(), str(plan.cells()))
	_check("glow off after detach", not combat.is_plan_featured())
	await process_frame
	await process_frame
	_check("controls v3: resonance label gone after the detach", not hud.get_board_labels().has("resonance"), str(hud.get_board_labels()))

	# --- Overlap: dropping piece 2 on piece 1's cell never overlaps (snaps beside it or is refused).
	await _touch_drag_piece(0, 1, cell_a, true)
	if plan.piece_count() == 2:
		var cells2: Array[Vector2i] = plan.cells()
		_check("drop on piece 1: union has no overlap", cells2.size() == 5 and _sorted(cells2).size() == 5 and _disjoint(plan.piece_cells(0), plan.piece_cells(1)), str(cells2))
		await _tap(0, ScreenLayout.cell_center(combat.get_grid(), VP, plan.piece_cells(1)[0]))
	else:
		_check("drop on piece 1 refused: piece back in its slot", _shape(1) == "bar2" and plan.cells().size() == 3)
	var probe: CastPlan = CastPlan.new().init(2, 0)
	probe.add_piece(0, lib.make_piece("bar3"), plan.piece_cells(0))
	var clash: Array[Vector2i] = [plan.piece_cells(0)[0], plan.piece_cells(0)[0] + Vector2i(0, 1)]
	_check("CastPlan refuses a second piece overlapping the first", not probe.add_piece(1, lib.make_piece("bar2"), clash) and probe.piece_count() == 1)

	# --- Tung phép with piece 1 alone: the menu opens; a 5-cell card is locked; no join while it is open.
	await _tap(0, cast_c)
	_check("tap Tung phép opens the card menu on the 3 placed cells", flow.is_menu_open() and flow.get_cells().size() == 3 and not combat.is_placed())
	await _tap(0, _card_center("dai_dao"))
	_check("card needing 5 cells is locked with 3 cells (menu stays)", flow.is_menu_open() and not actor.is_swinging())
	await _touch_drag_piece(0, 1, cell_b, true)
	_check("no join while the menu is open: piece 2 stays in the bag", plan.piece_count() == 1 and _shape(1) == "bar2" and not combat.is_placing() and flow.is_menu_open())
	await _tap(0, ScreenLayout.cancel_button_rect(VP, flow.is_menu_open()).get_center())
	_check("Huy in the menu returns piece 1", not flow.is_menu_open() and _shape(0) == "bar3" and plan.piece_count() == 0)

	# --- Non-featured 2-piece join (mirror of the block) before Tung phép: dai_dao, swing = union, no bonus.
	await _touch_drag_piece(0, 0, cell_a, true)
	await _touch_drag_piece(0, 1, cell_far, true)
	_check("non-featured join attached (5 cells, no glow)", plan.piece_count() == 2 and plan.cells().size() == 5 and not combat.is_plan_featured(), str(plan.cells()))
	var union: Array[Vector2i] = plan.cells()
	await _tap(0, cast_c)
	_check("Tung phép: menu on the union", flow.is_menu_open() and _sorted(flow.get_cells()) == _sorted(union))
	await _tap(0, _card_center("dai_dao"))
	_check("card needing 5 cells unlocks on the union (swing started)", not flow.is_menu_open() and actor.is_swinging() and actor.get_skill_id() == "dai_dao")
	_check("swing cells == union exactly", _sorted(actor.get_cells()) == _sorted(union), str(actor.get_cells()))
	_check("both pieces gone from the bag, plan cleared", hold.get_piece(0) == null and hold.get_piece(1) == null and _shape(2) == "mono" and plan.piece_count() == 0)
	_check("non-featured swing carries no bonus", actor.get_featured_bonus().is_empty())
	state.enemy_hp = state.enemy_max_hp
	await _resolve_swing()
	var fb: Dictionary = combat.get_cut_feedback()
	var per_cell: float = float(skill_cfg.get_skill("dai_dao")["damage_per_cell"])
	_check("non-featured 2-piece hit: featured false, mult 1, no stacks", bool(fb.get("hit", false)) and not bool(fb.get("featured", true)) and float(fb.get("featured_mult", 0.0)) == 1.0 and combat.get_fragile_stacks() == 0, str(fb))
	var plain_damage: float = float(fb.get("damage", 0.0))
	_check("plain damage = per-cell x 5 cells", is_equal_approx(plain_damage, per_cell * 5.0), "%.2f vs %.2f" % [plain_damage, per_cell * 5.0])

	# --- Huy in the place window returns BOTH pieces.
	_fill_bag()
	await _touch_drag_piece(0, 0, cell_a, true)
	await _touch_drag_piece(0, 1, cell_b, true)
	_check("two pieces joined before Huy", plan.piece_count() == 2 and hold.get_piece(0) == null and hold.get_piece(1) == null)
	await _tap(0, ScreenLayout.cancel_button_rect(VP, flow.is_menu_open()).get_center())
	_check("Huy in the place window returns BOTH pieces", not combat.is_placed() and not flow.is_menu_open() and _shape(0) == "bar3" and _shape(1) == "bar2" and plan.piece_count() == 0 and not actor.is_swinging())

	# --- Huy in the menu returns BOTH pieces.
	await _touch_drag_piece(0, 0, cell_a, true)
	await _touch_drag_piece(0, 1, cell_b, true)
	await _tap(0, cast_c)
	_check("two pieces joined, menu open", flow.is_menu_open() and plan.piece_count() == 2)
	await _tap(0, ScreenLayout.cancel_button_rect(VP, flow.is_menu_open()).get_center())
	_check("Huy in the menu returns BOTH pieces", not flow.is_menu_open() and _shape(0) == "bar3" and _shape(1) == "bar2" and plan.piece_count() == 0)

	# --- Huy while piece 2 is still in the finger returns piece 1 and ends the drag.
	await _touch_drag_piece(0, 0, cell_a, true)
	await _touch_drag_piece(0, 1, cell_b, false)
	await _tap(1, ScreenLayout.cancel_button_rect(VP, flow.is_menu_open()).get_center())
	_check("Huy (finger 1) mid-drag: piece 1 back, drag over", not combat.is_placed() and not combat.is_placing() and _shape(0) == "bar3" and _shape(1) == "bar2")
	await _touch(0, combat.drag_point_for_cell(cell_b), false)
	_check("late release after Huy does nothing", not combat.is_placed() and not flow.is_menu_open() and _shape(1) == "bar2")

	# --- Featured join (block) before Tung phép: glow, kiem_khi swing x1.5, effect applied once.
	_fill_bag()
	state.set_enemy_cell(BOSS_CELL)
	await _touch_drag_piece(0, 0, cell_a, true)
	await _touch_drag_piece(0, 1, cell_b, true)
	_check("featured join: glow on, union is the block", combat.is_plan_featured() and plan.piece_count() == 2, str(plan.cells()))
	await _tap(0, cast_c)
	_check("featured: glow kept with the menu open", flow.is_menu_open() and combat.is_plan_featured())
	await _tap(0, _card_center("kiem_khi"))
	_check("featured swing started with the bonus", actor.is_swinging() and float(actor.get_featured_bonus().get("damage_mult", 0.0)) == 1.5, str(actor.get_featured_bonus()))
	state.enemy_hp = state.enemy_max_hp
	await _resolve_swing()
	fb = combat.get_cut_feedback()
	var kk: float = float(skill_cfg.get_skill("kiem_khi")["damage_per_cell"])
	_check("hit result is featured with mult 1.5 and the fragile effect", bool(fb.get("hit", false)) and bool(fb.get("featured", false)) and float(fb.get("featured_mult", 0.0)) == 1.5 and str(fb.get("featured_effect", "")) == "fragile", str(fb))
	_check("damage carries the 1.5 mult", is_equal_approx(float(fb.get("damage", 0.0)), kk * 5.0 * 1.5), "%.2f vs %.2f" % [float(fb.get("damage", 0.0)), kk * 5.0 * 1.5])
	_check("effect applied exactly once (1 Ran stack on the boss)", combat.get_fragile_stacks() == 1, str(combat.get_fragile_stacks()))
	_check("the bonus is spent after the hit", actor.get_featured_bonus().is_empty() or not actor.is_swinging())

	# --- A single piece matching the featured shape never gets the bonus.
	var plus_cells: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]
	combat._featured = {"cells": plus_cells, "bonus": bonus}
	_fill_bag()
	var plus := FieldPoint.new()
	plus.uid = -200
	plus.freshness_left = 0.0
	plus.piece = lib.make_piece("plus5", 0)
	plus.label = "plus5"
	hold.remove(2)
	hold.place(plus, 2)
	state.set_enemy_cell(BOSS_CELL)
	await _touch_drag_piece(0, 2, BOSS_CELL, true)
	await _tap(0, cast_c)
	_check("single plus5 (== featured shape) in the menu, no glow", flow.is_menu_open() and plan.piece_count() == 1 and flow.get_cells().size() == 5 and not combat.is_plan_featured(), str(flow.get_cells()))
	await _tap(0, _card_center("kiem_khi"))
	_check("single-piece swing has no featured bonus", actor.is_swinging() and actor.get_featured_bonus().is_empty())
	state.enemy_hp = state.enemy_max_hp
	await _resolve_swing()
	fb = combat.get_cut_feedback()
	_check("single piece hit: featured false, mult 1, no new stack", bool(fb.get("hit", false)) and not bool(fb.get("featured", true)) and float(fb.get("featured_mult", 0.0)) == 1.0 and combat.get_fragile_stacks() == 0, str(fb))
	combat._featured = {"cells": block, "bonus": bonus}

	# --- Desktop extras (mouse): drag both pieces with the mouse, Esc returns both (place window and menu).
	_fill_bag()
	await _mouse_drag_piece(0, cell_a, true)
	await _mouse_drag_piece(1, cell_b, true)
	_check("mouse: two pieces joined", combat.is_placed() and plan.piece_count() == 2 and plan.cells().size() == 5, str(plan.cells()))
	await _key(KEY_ESCAPE)
	_check("Esc in the place window returns BOTH pieces", not combat.is_placed() and _shape(0) == "bar3" and _shape(1) == "bar2" and plan.piece_count() == 0)
	await _mouse_drag_piece(0, cell_a, true)
	await _mouse_drag_piece(1, cell_b, true)
	await _mouse_button(cast_c, true)
	await _mouse_button(cast_c, false)
	_check("mouse: click on Tung phép opens the menu", flow.is_menu_open() and plan.piece_count() == 2)
	await _key(KEY_ESCAPE)
	_check("Esc in the menu returns BOTH pieces", not flow.is_menu_open() and _shape(0) == "bar3" and _shape(1) == "bar2" and plan.piece_count() == 0)

	# --- max_cast_cells (in-memory CombatConfig only): an over-cap second piece is refused.
	cfg.max_cast_cells = 4
	_fill_bag()
	await _touch_drag_piece(0, 0, cell_a, true)
	_check("cap 4: a 3-cell first piece is fine", combat.is_placed() and plan.piece_count() == 1)
	var t_cap: float = combat.get_place_time_left()
	await _touch_drag_piece(0, 1, cell_b, true)
	_check("cap 4: 3 + 2 cells refused, piece back in its slot", plan.piece_count() == 1 and _shape(1) == "bar2" and plan.cells().size() == 3 and combat.is_placed(), str(plan.cells()))
	_check("cap refusal recorded for the red ghost + note", not combat.get_join_refusal().is_empty(), str(combat.get_join_refusal()))
	_check("refused join did not add time", combat.get_place_time_left() <= t_cap + 0.001)
	await _touch_drag_piece(0, 2, Vector2i(sc, 2), true)
	_check("cap 4: 3 + 1 cells fits", plan.piece_count() == 2 and plan.cells().size() == 4, str(plan.cells()))
	cfg.max_cast_cells = 0
	await _tap(0, ScreenLayout.cancel_button_rect(VP, flow.is_menu_open()).get_center())
	_check("Huy returns both after the cap test", not combat.is_placed() and _shape(0) == "bar3" and _shape(2) == "mono")

	print("FAILS=%d" % fails)
	print("VERDICT %s" % ("PASS" if fails == 0 else "FAIL"))
	quit(fails)

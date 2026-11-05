extends SceneTree
## 2026-11-04 (user: "sau khi mà đã đặt mảnh khối xuống rồi thì ko thể điều chỉnh nó nữa ? cần cho người dùng điều
## chỉnh nó chứ"): in the place window a placed piece can be lifted off the cast back into PLACING (same cells, same
## rotation), then moved / rotated and put back, or left in the bag. The cast clock keeps running; the bookkeeping of
## the bag points stays right (cancel returns every piece, the cast uses the new cells); a cast whose every piece was
## left in the bag closes its window; the clock running out puts a lifted piece back where its ghost is; a press on a
## placed piece lifts it through HandInputController (tap = lift in place, drag = carry), also when the cast is full.
## Headless, time frozen (the real-time windows advanced through CombatView._tick_place_window).
## Run: godot --headless --path . -s res://tests/unit/combat/lift_placed_piece_test.gd

const BIG_HP: float = 1000000.0

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_lift_keeps_cells_and_moves()
	await test_lift_off_the_board_closes_the_window()
	await test_two_pieces_bookkeeping()
	await test_timeout_puts_a_lifted_piece_back()
	await test_input_tap_and_drag_lift()
	await test_readout_damage_counts_the_held_piece()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ fixtures

func _match() -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = {"boss_max_hp": BIG_HP}
	v.drops_seed = 7
	v.freeze_time = true
	v.card_time_mode = SettingsStore.CARD_TIME_NORMAL
	holder.add_child(v)
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	var hand := HandInputController.new()
	hand.name = "HandInputController"
	holder.add_child(hand)
	root.add_child(holder)
	await process_frame
	v.get_boss().set_active(false)
	v._featured = {}
	var drops: FieldDrops = v.get_drops()
	for cell: Vector2i in v.get_grid().player_cells():
		drops.pick_up_at(cell, true)
	drops.set_blocked_cells(v.get_grid().player_cells())
	v.get_state().set_enemy_cell(_ec(v, 1, 1))
	_fill(v)
	return holder


func _cv(holder: Node) -> CombatView:
	return holder.get_node("CombatView") as CombatView


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


func _ec(v: CombatView, dx: int, y: int) -> Vector2i:
	return Vector2i(v.get_grid().side_cols + dx, y)


# Bag: bar3 / bar2 / mono in slots 0..2; deck all kiem_khi.
func _fill(v: CombatView) -> void:
	var hold: HoldSlots = v.get_hold()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	var shapes: Array[String] = ["bar3", "bar2", "mono"]
	for i: int in shapes.size():
		var p := FieldPoint.new()
		p.uid = -100 - i
		p.freshness_left = 0.0
		p.piece = _lib.make_piece(shapes[i], 0)
		p.label = shapes[i]
		hold.place(p, i)
	v._deck = Deck.from_array(["kiem_khi", "kiem_khi", "kiem_khi", "kiem_khi"] as Array[String], 1)


func _place(v: CombatView, slot: int, cell: Vector2i) -> bool:
	return v.select_piece(slot, false) and v.aim_at_cell(cell) and v.confirm_placement()


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = cells.duplicate()
	out.sort()
	return out


func _bag_count(v: CombatView) -> int:
	var n: int = 0
	for i: int in v.get_hold().get_slot_count():
		if v.get_hold().get_piece(i) != null:
			n += 1
	return n


# ------------------------------------------------------------------ tests

func test_lift_keeps_cells_and_moves() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	_place(v, 0, _ec(v, 1, 1))
	var before: Array[Vector2i] = _sorted(v.get_cast_plan().cells())
	v._tick_place_window(1.0)
	var left: float = v.get_place_time_left()
	_check("test_placed_piece_found_under_its_cell", v.placed_piece_at(before[0]) == 0)
	_check("test_lift_returns_true", v.lift_placed_piece(0))
	_check("test_lifted_piece_is_being_placed_on_the_same_cells", v.is_placing() and _sorted(v.get_placement().get_cells()) == before, str(v.get_placement().get_cells()))
	_check("test_lifted_piece_left_the_cast_window_still_open", v.get_cast_plan().piece_count() == 0 and v.is_placed())
	_check("test_cast_clock_not_reset", absf(v.get_place_time_left() - left) < 0.0001)
	v.rotate_piece()
	v.aim_at_cell(_ec(v, 1, 0))
	var moved: Array[Vector2i] = _sorted(v.get_placement().get_cells())
	_check("test_rotated_and_moved_ghost_differs", moved != before, str(moved))
	_check("test_put_back_into_the_cast", v.confirm_placement() and v.get_cast_plan().piece_count() == 1 and _sorted(v.get_cast_plan().cells()) == moved)
	_check("test_piece_left_the_bag_again", v.get_hold().get_piece(0) == null and _bag_count(v) == 2)
	v.press_cast()
	_check("test_cast_uses_the_new_cells", v.get_cut_flow().choose("kiem_khi") and _sorted(v.get_cut_actor().get_cells()) == moved, str(v.get_cut_actor().get_cells()))
	v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	_drop(h)


func test_lift_off_the_board_closes_the_window() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	_place(v, 0, _ec(v, 1, 1))
	v.lift_placed_piece(0)
	v.begin_drag(v.get_placement().get_slot(), Vector2.ZERO)
	v.end_drag(Vector2.ZERO)
	_check("test_dropped_off_the_board_back_in_the_bag", not v.is_placing() and v.get_hold().get_piece(0) != null and _bag_count(v) == 3)
	_check("test_empty_cast_closes_the_window", not v.is_placed() and v.get_cast_plan().piece_count() == 0 and not v.is_movement_locked())
	_drop(h)


func test_two_pieces_bookkeeping() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	_place(v, 0, _ec(v, 0, 0))
	_place(v, 1, _ec(v, 2, 2))
	_check("fixture: two pieces placed", v.get_cast_plan().piece_count() == 2 and _bag_count(v) == 1)
	_check("test_lift_the_first_piece", v.lift_placed_piece(0) and v.get_cast_plan().piece_count() == 1 and v.get_placement().get_slot() == 0)
	v.aim_at_cell(_ec(v, 0, 1))
	_check("test_first_piece_put_back_after_the_second", v.confirm_placement() and v.get_cast_plan().piece_count() == 2)
	_check("test_cancel_returns_both_pieces", v.cancel_placement() and _bag_count(v) == 3 and not v.is_placed())
	_drop(h)


func test_timeout_puts_a_lifted_piece_back() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	_place(v, 0, _ec(v, 1, 1))
	v.lift_placed_piece(0)
	v.aim_at_cell(_ec(v, 1, 2))
	var ghost: Array[Vector2i] = _sorted(v.get_placement().get_cells())
	v._tick_place_window(v.get_place_duration() + 0.1)
	var actor: CutActor = v.get_cut_actor()
	_check("test_timeout_casts_the_lifted_piece_where_its_ghost_is", actor.is_swinging() and _sorted(actor.get_cells()) == ghost, "%s vs %s" % [actor.get_cells(), ghost])
	_check("test_timeout_lifted_piece_consumed", v.get_hold().get_piece(0) == null and not v.is_placing())
	v.get_arbiter().tick(actor.get_time_left() + 0.01)
	_drop(h)


func test_input_tap_and_drag_lift() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	var hand: HandInputController = h.get_node("HandInputController") as HandInputController
	_place(v, 0, _ec(v, 0, 0))
	_place(v, 1, _ec(v, 2, 2))
	_check("fixture: the cast is full (no bag piece may join)", not v.can_join_piece(), str(v.get_cast_plan().piece_count()))
	var cells0: Array[Vector2i] = _sorted(v.get_cast_plan().piece_cells(0))
	var at: Vector2 = v.board_geometry().cell_center(cells0[0])
	_check("fixture: the screen point maps to the first piece", v.placed_piece_at_screen(at) == 0)
	hand.pointer_down(HandInputController.MOUSE_ID, at)
	hand.pointer_up(HandInputController.MOUSE_ID, at)
	_check("test_tap_lifts_in_place", v.is_placing() and not v.is_dragging() and _sorted(v.get_placement().get_cells()) == cells0, str(v.get_placement().get_cells()))
	v.confirm_placement()
	var cells1: Array[Vector2i] = _sorted(v.get_cast_plan().piece_cells(v.get_cast_plan().piece_count() - 1))
	var at1: Vector2 = v.board_geometry().cell_center(cells1[0])
	var target: Vector2 = v.drag_point_for_cell(_ec(v, 1, 1))
	hand.pointer_down(HandInputController.MOUSE_ID, at1)
	hand.pointer_move(HandInputController.MOUSE_ID, at1 + Vector2(0, -80))
	_check("test_drag_carries_the_placed_piece", v.is_dragging() and v.get_cast_plan().piece_count() == 1)
	hand.pointer_move(HandInputController.MOUSE_ID, target)
	hand.pointer_up(HandInputController.MOUSE_ID, target)
	_check("test_drag_release_puts_it_back_moved", v.get_cast_plan().piece_count() == 2 and not v.is_placing() and _sorted(v.get_cast_plan().piece_cells(1)) != cells1, str(v.get_cast_plan().piece_cells(1)))
	_drop(h)


# 2026-11-05 (user: "Sửa dòng sát thương"): the board readout's damage counts the piece being placed, so lifting the only
# placed piece no longer reads "0 damage"; with nothing held it is the committed cast alone.
func test_readout_damage_counts_the_held_piece() -> void:
	var h: Node = await _match()
	var v: CombatView = _cv(h)
	var cut: CutConfig = v.get_cut_config()
	_place(v, 0, _ec(v, 1, 1))
	v.lift_placed_piece(0)
	var held: int = v.get_placement().get_cells().size()
	var cells: int = CutHudView.preview_damage_cells(v.get_cast_plan().total_cells(), held)
	_check("test_lifted_only_piece_counts_its_cells", cells == 3 and cut.slash_damage(cells) > 0.0, "%d cells" % cells)
	_check("test_nothing_held_counts_the_committed_cast", CutHudView.preview_damage_cells(5, 0) == 5)
	_check("test_committed_plus_held", CutHudView.preview_damage_cells(3, 2) == 5)
	_drop(h)

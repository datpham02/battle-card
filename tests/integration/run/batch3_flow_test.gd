extends SceneTree
## Skill v2 batch 3, the 7 cards in the REAL player flow of a CombatView (bag -> place -> menu -> choose), one scene
## per card: Bẫy Kẹp arms and snaps on the boss's entry; Bẫy Lò Xo flings and slams at the edge; Gai Nổ blows the
## thorns under the boss; Thánh Thuẫn re-anchors on the hero and halves a hit + heals; Khiên Thép gives Guard 6;
## Tường Đá raises pillars the boss cannot step into; Hỏa Tuyến's line burns as a wall. Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/batch3_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_bay_kep()
	await test_bay_lo()
	await test_gai_no()
	await test_thanh_thuan()
	await test_khien_thep()
	await test_tuong_da()
	await test_hoa_tuyen()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


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
	holder.add_child(v)
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	var pad := DPadView.new()
	pad.name = "DPadView"
	holder.add_child(pad)
	root.add_child(holder)
	await process_frame
	v.set_process(false)
	v.get_boss().set_active(false)
	if v.get_pattern_controller() != null:
		v.get_pattern_controller().set_process(false)
	v._featured = {}
	var drops: FieldDrops = v.get_drops()
	for cell: Vector2i in v.get_grid().player_cells():
		drops.pick_up_at(cell, true)
	drops.set_blocked_cells(v.get_grid().player_cells())
	v.get_state().set_enemy_cell(Vector2i(v.get_grid().side_cols + 1, 1))
	return holder


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


func _fill(v: CombatView, id: String, shapes: Array[String], rotation: int = 0) -> void:
	var hold: HoldSlots = v.get_hold()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	for i: int in shapes.size():
		var p := FieldPoint.new()
		p.uid = -300 - i
		p.freshness_left = 0.0
		p.piece = _lib.make_piece(shapes[i], rotation)
		p.label = shapes[i]
		hold.place(p, i)
	v._deck = Deck.from_array([id, id, id, id] as Array[String], 1)


func _run(v: CombatView, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		v._process(STEP)
		t += STEP


# Places slot 0 at [param anchor], opens the menu, chooses [param id] and runs the swing plus 0.05 s.
func _cast(v: CombatView, id: String, anchor: Vector2i) -> void:
	v.freeze_time = true
	_check("%s: place the Block at %s" % [id, str(anchor)], v.select_piece(0, false) and v.aim_at_cell(anchor) and v.confirm_placement())
	var flow: CutFlow = v.get_cut_flow()
	_check("%s: Tung phép opens the menu with the card" % id, v.press_cast() and flow.is_menu_open() and flow.get_hand().has(id))
	_check("%s: choose" % id, flow.choose(id))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	_run(v, 0.05)


func test_bay_kep() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, "bay_kep", ["bar2", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	var fx: StatusEffects = v.get_status()
	var hp0: float = v.get_state().enemy_hp
	_cast(v, "bay_kep", Vector2i(c, 0))  # (c,0) (c+1,0): above the boss on (c+1,1)
	_check("bay_kep: 2 trap cells armed, no damage, one armed cast", fx.field_cells(CombatState.Side.ENEMY, StatusEffects.KIND_TRAP).size() == 2
		and is_equal_approx(v.get_state().enemy_hp, hp0) and fx.trap_cast_count(CombatState.Side.ENEMY, "bay_kep") == 1)
	v.get_state().set_enemy_cell(Vector2i(c + 1, 0))
	_run(v, STEP)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("bay_kep: the boss steps onto the trap: 6 x 1 (or more with a passive), Pinned, trap spent", (is_equal_approx(lost, 6.0) or lost > 6.0)
		and fx.is_pinned(CombatState.Side.ENEMY) and fx.field_cells(CombatState.Side.ENEMY).is_empty(), "%.1f" % lost)
	_drop(holder)


func test_bay_lo() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, "bay_lo", ["bar2", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	var hp0: float = v.get_state().enemy_hp
	_cast(v, "bay_lo", Vector2i(c, 0))
	v.get_state().set_enemy_cell(Vector2i(c + 1, 0))
	_run(v, STEP)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("bay_lo: the boss steps in: 3, flung toward the edge (c+2, 0), the short fling slams +8 (11 or more)", (is_equal_approx(lost, 11.0) or lost > 11.0)
		and v.get_state().enemy_cell == Vector2i(c + 2, 0) and v.get_status().is_pinned(CombatState.Side.ENEMY), "%.1f %s" % [lost, str(v.get_state().enemy_cell)])
	_drop(holder)


func test_gai_no() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, "gai_no", ["bar3", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	var fx: StatusEffects = v.get_status()
	var row: Array[Vector2i] = [Vector2i(c, 1), Vector2i(c + 1, 1), Vector2i(c + 2, 1)]
	ZoneRules.cast_thorns(fx, CombatState.Side.ENEMY, row, 5.0, 6.0, 1)
	var hp0: float = v.get_state().enemy_hp
	_cast(v, "gai_no", Vector2i(c, 1))
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("gai_no: the thorn under the boss blows: 6 (or more with a passive), +1 Rạn, every thorn spent", (is_equal_approx(lost, 6.0) or lost > 6.0)
		and fx.fragile_stacks(CombatState.Side.ENEMY) == 1 and fx.thorn_cells(CombatState.Side.ENEMY).is_empty(), "%.1f" % lost)
	_drop(holder)


func test_thanh_thuan() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, "thanh_thuan", ["bar2", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	var fx: StatusEffects = v.get_status()
	var state: CombatState = v.get_state()
	state.set_player_hp(50.0)
	var hp0: float = state.enemy_hp
	_cast(v, "thanh_thuan", Vector2i(c, 1))  # placed on the enemy half, re-anchored on the hero when chosen
	var wards: Array[Vector2i] = fx.field_cells(CombatState.Side.PLAYER, StatusEffects.KIND_WARD)
	_check("thanh_thuan: the ward formed on the hero's own half (2 cells, the hero's cell included), the boss untouched",
		wards.size() == 2 and wards.has(state.player_cell) and is_equal_approx(state.enemy_hp, hp0), str(wards))
	_check("thanh_thuan: a 12 hit on the hero is halved", is_equal_approx(fx.ward_absorb(CombatState.Side.PLAYER, 12.0, state), 6.0))
	var php: float = state.player_hp
	_run(v, 1.0)
	_check("thanh_thuan: +2 HP after 1 s on the ward", state.player_hp - php >= 1.9, "%.2f" % (state.player_hp - php))
	_drop(holder)


func test_khien_thep() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, "khien_thep", ["bar2", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	var fx: StatusEffects = v.get_status()
	_cast(v, "khien_thep", Vector2i(c, 1))
	_check("khien_thep: the ward is under the hero, Guard 6 takes a 12 hit to 6 and a 4 hit to 1",
		not fx.ward_at(CombatState.Side.PLAYER, v.get_state()).is_empty() and is_equal_approx(fx.ward_absorb(CombatState.Side.PLAYER, 12.0, v.get_state()), 6.0)
		and is_equal_approx(fx.ward_absorb(CombatState.Side.PLAYER, 4.0, v.get_state()), 1.0))
	_drop(holder)


func test_tuong_da() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, "tuong_da", ["bar3", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	var fx: StatusEffects = v.get_status()
	_cast(v, "tuong_da", Vector2i(c, 0))  # the row above the boss
	var pillars: Array[Vector2i] = fx.field_cells(CombatState.Side.ENEMY, StatusEffects.KIND_PILLAR)
	_check("tuong_da: 3 pillars on the empty row, 4 s (line)", pillars.size() == 3 and absf(float(fx.field_at(CombatState.Side.ENEMY, pillars[0])["left"]) - 4.0) < 0.1, str(pillars))
	_check("tuong_da: the boss's mover refuses a pillar cell", v.get_boss().get_mover().is_cell_blocked(Vector2i(c + 1, 0))
		and not v.get_boss().get_mover().is_cell_blocked(Vector2i(c + 1, 2)))
	_drop(holder)


func test_hoa_tuyen() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, "hoa_tuyen", ["bar3", "mono", "mono"], 1)  # a vertical bar3
	var c: int = v.get_grid().side_cols
	var fx: StatusEffects = v.get_status()
	_cast(v, "hoa_tuyen", Vector2i(c + 2, 0))  # the column (c+2, 0..2) next to the boss on (c+1, 1)
	_run(v, 1.2)
	_check("hoa_tuyen: the column burns as a fire wall (3 cells)", fx.wall_cells().size() == 3 and fx.burning_cells().size() == 3, str(fx.wall_cells()))
	_check("hoa_tuyen: the boss's mover refuses the wall, not the open cell", v.get_boss().get_mover().is_cell_blocked(Vector2i(c + 2, 1))
		and not v.get_boss().get_mover().is_cell_blocked(Vector2i(c, 1)))
	_drop(holder)

extends SceneTree
## Skill v2 batch 4, the 5 cards in the REAL player flow of a CombatView (bag -> place -> menu -> choose), one scene
## per card: Chuông Thánh rings three waves (+Hàn each); Thiên Quang's pillars hit once and chill up to twice;
## Dấu Tử marks the boss and the next card echoes; Phi Tiêu's daggers bounce after the boss (2 hits); Móc Kéo
## drags the boss toward the divider. Time is stepped by hand.
## Run: godot --headless --path . -s res://tests/integration/run/batch4_flow_test.gd

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
	await test_chuong_thanh()
	await test_thien_quang()
	await test_dau_tu()
	await test_phi_tieu()
	await test_moc_keo()
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


func _fill(v: CombatView, deck: Array[String], shapes: Array[String], rotation: int = 0) -> void:
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
	v._deck = Deck.from_array(deck, 1)


func _run(v: CombatView, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		v._process(STEP)
		t += STEP


# Places slot [param slot] at [param anchor], opens the menu, chooses [param id], runs the swing plus [param after] seconds.
func _cast(v: CombatView, id: String, slot: int, anchor: Vector2i, after: float = 0.05) -> void:
	v.freeze_time = true
	_check("%s: place the Block at %s" % [id, str(anchor)], v.select_piece(slot, false) and v.aim_at_cell(anchor) and v.confirm_placement())
	var flow: CutFlow = v.get_cut_flow()
	_check("%s: Tung phép opens the menu with the card" % id, v.press_cast() and flow.is_menu_open() and flow.get_hand().has(id))
	_check("%s: choose" % id, flow.choose(id))
	v.freeze_time = false
	while v.get_cut_actor().is_swinging():
		v._process(STEP)
	_run(v, after)


func test_chuong_thanh() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, ["chuong_thanh", "chuong_thanh", "chuong_thanh", "chuong_thanh"], ["bar3", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	var hp0: float = v.get_state().enemy_hp
	var hits: Array = []
	v.get_arbiter().impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		if hit:
			hits.append(str(ev["kind"])))
	_cast(v, "chuong_thanh", 0, Vector2i(c, 1), 1.5)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("chuong_thanh: hit + 2 echoes on the boss that stayed (3 hits), the third Hàn burst", hits == ["hit", "echo", "echo"]
		and lost >= 12.0 + 6.0 + 6.0 - 0.001 and v.get_status().frost_stacks(CombatState.Side.ENEMY) == 0, "%.1f %s" % [lost, str(hits)])
	_drop(holder)


func test_thien_quang() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, ["thien_quang", "thien_quang", "thien_quang", "thien_quang"], ["t4", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	v.get_state().set_player_hp(50.0)
	var hp0: float = v.get_state().enemy_hp
	# t4 at (c,0): (c,0) (c+1,0) (c+2,0) (c+1,1): the boss on (c+1,1); from the centre (nearest the hero on ties)
	_cast(v, "thien_quang", 0, Vector2i(c, 0), 1.5)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("thien_quang: one pillar hit 5 x 4 = 20 (or more), +1 Hàn, no plus clause so no heal", lost >= 20.0 - 0.001
		and v.get_status().frost_stacks(CombatState.Side.ENEMY) == 1 and is_equal_approx(v.get_state().player_hp, 50.0), "%.1f" % lost)
	_drop(holder)


func test_dau_tu() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, ["dau_tu", "kiem_khi", "kiem_khi", "kiem_khi"], ["mono", "bar2", "mono"])
	var c: int = v.get_grid().side_cols
	var boss: Vector2i = v.get_state().enemy_cell
	var hp0: float = v.get_state().enemy_hp
	_cast(v, "dau_tu", 0, boss)
	_check("dau_tu: the mono hit marks the boss for 5 s", v.get_status().has_mark(CombatState.Side.ENEMY)
		and absf(float(v.get_status().mark_at(CombatState.Side.ENEMY)["left"]) - 5.0) < 0.1, str(v.get_status().mark_at(CombatState.Side.ENEMY)))
	var hp1: float = v.get_state().enemy_hp
	var echoes: Array = []
	v.get_arbiter().impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		if str(ev["kind"]) == "echo":
			echoes.append(hit))
	_cast(v, "kiem_khi", 1, Vector2i(c, 1), 0.8)  # bar2 (c,1)-(c+1,1) on the boss
	var lost: float = hp1 - v.get_state().enemy_hp
	_check("kiem_khi on the marked boss: 12 then the mark's echo 7.2 (19.2 or more), the mark spent", echoes == [true]
		and lost >= 19.2 - 0.001 and not v.get_status().has_mark(CombatState.Side.ENEMY), "%.2f %s" % [lost, str(echoes)])
	_drop(holder)


func test_phi_tieu() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, ["phi_tieu", "phi_tieu", "phi_tieu", "phi_tieu"], ["bar2", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	var hp0: float = v.get_state().enemy_hp
	var log: Array = []
	v.get_arbiter().impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"hit": hit, "bounced": ev.has("bounced_from")}))
	# bar2 (c,1)-(c+1,1): the boss on (c+1,1): dagger 1 bounces from (c,1) to the boss, dagger 2 hits it too
	_cast(v, "phi_tieu", 0, Vector2i(c, 1), 0.5)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("phi_tieu: the first dagger bounces onto the boss, both hit: 5 x 2 x 2 = 20 (or more)", log.size() == 2 and bool(log[0]["hit"])
		and bool(log[0]["bounced"]) and bool(log[1]["hit"]) and lost >= 20.0 - 0.001, "%.1f %s" % [lost, str(log)])
	_drop(holder)


func test_moc_keo() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	_fill(v, ["moc_keo", "moc_keo", "moc_keo", "moc_keo"], ["bar2", "mono", "mono"])
	var c: int = v.get_grid().side_cols
	var boss: Vector2i = v.get_state().enemy_cell  # (c+1, 1)
	var hp0: float = v.get_state().enemy_hp
	var paths: Array = []
	v.get_arbiter().cast_scheduled.connect(func(_side: int, cast: Dictionary) -> void: paths.append(cast.get("pull_path", [])))
	# bar2 (c+1,1)-(c+2,1) (line_h: pull 3): the hook lands on the boss's cell
	_cast(v, "moc_keo", 0, boss, 1.0)
	var lost: float = hp0 - v.get_state().enemy_hp
	_check("moc_keo: the hook hits 4 x 2 = 8 (or more) and drags the boss to the divider cell (c, 1)", lost >= 8.0 - 0.001
		and v.get_state().enemy_cell == Vector2i(c, 1), "%.1f %s" % [lost, str(v.get_state().enemy_cell)])
	_check("moc_keo: the pull path was telegraphed on cast_scheduled", paths.size() == 1 and (paths[0] as Array) == [Vector2i(c, 1)], str(paths))
	_drop(holder)

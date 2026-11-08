extends SceneTree
## Ngàn Kiếm Cast Commitment, final QA: the COMPLETE player flow through the real piece path, headless (bag slot ->
## select_piece -> aim_at_cell -> confirm_placement -> press_cast (Tung phép) -> CutFlow.choose("ngan_kiem") ->
## CHANNELING -> Hủy), then: the Block is gone from the real bag (not returned), the full cooldown keeps running and
## the card cannot be picked again, nothing is scheduled and no damage lands. Mobile: the d-pad (DPadView) is locked
## while channeling and free again after the cancel; the channel's Hủy touch area; the labels in Vietnamese and
## English. Time is stepped by hand: deterministic.
## Run: godot --headless --path . -s res://tests/integration/run/ngan_kiem_full_flow_test.gd

const BIG_HP: float = 1000000.0
const STEP: float = 0.01
const ID: String = "ngan_kiem"

var fails: int = 0
var _lib: PieceLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_lib = PieceLibrary.load_from_file()
	await test_full_flow_cancel()
	await test_full_flow_commit()
	test_labels_vi_en()
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


# Bag: t4 (4 cells, Ngàn Kiếm's minimum) in slot 0, bar2 and mono after it; deck: four Ngàn Kiếm (the hand offers it).
func _fill(v: CombatView) -> void:
	var hold: HoldSlots = v.get_hold()
	for i: int in hold.get_slot_count():
		hold.remove(i)
	var shapes: Array[String] = ["t4", "bar2", "mono"]
	for i: int in shapes.size():
		var p := FieldPoint.new()
		p.uid = -200 - i
		p.freshness_left = 0.0
		p.piece = _lib.make_piece(shapes[i], 0)
		p.label = shapes[i]
		hold.place(p, i)
	v._deck = Deck.from_array([ID, ID, ID, ID] as Array[String], 1)


func _run(v: CombatView, sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		v._process(STEP)
		t += STEP


# Pick up -> place -> confirm -> Tung phép -> choose Ngàn Kiếm. Returns the bag's piece count before the placement.
func _cast_ngan_kiem(v: CombatView) -> int:
	_fill(v)
	var hold: HoldSlots = v.get_hold()
	var before: int = hold.get_occupied_count()
	var target := Vector2i(v.get_grid().side_cols + 1, 1)
	_check("pick up the t4 Block and place it on the enemy half", v.select_piece(0, false) and v.aim_at_cell(target) and v.confirm_placement())
	_check("the Block left the bag at the placement (PLANNING)", hold.get_piece(0) == null and hold.get_occupied_count() == before - 1)
	var flow: CutFlow = v.get_cut_flow()
	_check("Tung phép opens the card menu with Ngàn Kiếm", v.press_cast() and flow.is_menu_open() and flow.get_hand().has(ID), str(flow.get_hand()))
	_check("choose Ngàn Kiếm -> CHANNELING", flow.choose(ID) and v.channel_phase() == CombatView.PHASE_CHANNELING)
	v.freeze_time = false
	return before


func test_full_flow_cancel() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var hud: CutHudView = holder.get_node("CutHudView") as CutHudView
	var pad: DPadView = holder.get_node("DPadView") as DPadView
	var hold: HoldSlots = v.get_hold()
	var hp0: float = v.get_state().enemy_hp
	var before: int = _cast_ngan_kiem(v)
	var cd_full: float = float(v.get_skill_config().resolved(ID, 1)["cooldown_sec"])
	_check("cooldown started at the swing start (full)", absf(v.get_skill_cooldowns().remaining(ID) - cd_full) < 0.001)
	_check("joystick locked while channeling (d-pad reports locked, no step)", pad._is_locked() and not pad._can_step_now())
	var vp: Vector2 = hud.get_viewport_rect().size
	var hit: Rect2 = ScreenLayout.channel_cancel_hit_rect(vp)
	_check("Hủy touch area at least the minimum touch side", hit.size.x >= 44.0 and hit.size.y >= 44.0, str(hit.size))
	_run(v, 0.05)
	_check("accidental tap in the first 0.15 s is ignored", hud._press_at(hit.get_center(), false) and not v._cancel_requested)
	_run(v, 0.4)
	_check("tap Hủy during the channel", hud._press_at(hit.get_center(), false) and v._cancel_requested)
	v._process(STEP)
	_check("CANCELLED: no swing, no phase", not v.get_cut_actor().is_swinging() and v.channel_phase() == CombatView.PHASE_NONE)
	_check("the Block is consumed in the real bag (not returned)", hold.get_occupied_count() == before - 1 and hold.get_piece(0) == null)
	_check("nothing to give back: cancel_placement has no piece to return", not v.cancel_placement() and hold.get_occupied_count() == before - 1)
	_check("the full cooldown keeps running", v.get_skill_cooldowns().remaining(ID) > cd_full - 0.6, "%.2f" % v.get_skill_cooldowns().remaining(ID))
	_check("the card cannot be picked again while cooling down", not bool(SkillAvailability.check(v.get_skill_config(), v.get_skill_cooldowns(), ID, 4)["available"]))
	_check("no damage scheduled", v.get_arbiter().active_cast_count() == 0 and v.get_arbiter().first_event_at() == INF)
	_check("joystick free again right after the cancel", not pad._is_locked() and pad._can_step_now())
	var dir: Vector2i = Vector2i.ZERO
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if v.get_grid().is_player_cell(v.get_state().player_cell + d):
			dir = d
			break
	var cell0: Vector2i = v.get_state().player_cell
	_check("cancel -> movement: the hero steps at once", v.try_step_player(dir) and v.get_state().player_cell == cell0 + dir)
	_run(v, 2.5)
	_check("no damage landed", is_equal_approx(v.get_state().enemy_hp, hp0))
	_drop(holder)


func test_full_flow_commit() -> void:
	var holder: Node = await _match()
	var v: CombatView = holder.get_node("CombatView") as CombatView
	var pad: DPadView = holder.get_node("DPadView") as DPadView
	var hp0: float = v.get_state().enemy_hp
	_cast_ngan_kiem(v)
	var t0: float = v.get_arbiter().clock()
	var actor: CutActor = v.get_cut_actor()
	_check("t4 channel = 0.2 + 4 x 0.25 + 0.28 = 1.48 s", is_equal_approx(actor.get_duration(), 1.48))
	while v.channel_phase() == CombatView.PHASE_CHANNELING:
		v._process(STEP)
	_check("COMMIT: joystick still locked", v.channel_phase() == CombatView.PHASE_COMMIT and pad._is_locked())
	var first_at: float = v.get_arbiter().first_event_at()
	_check("first stab 0.22 s after the commit", absf(first_at - v.get_arbiter().clock() - 0.22) < 0.011)
	while v.channel_phase() == CombatView.PHASE_COMMIT:
		v._process(STEP)
	_check("RESOLUTION after 0.13 s: joystick restored", not pad._is_locked() and absf(v.get_arbiter().clock() - t0 - 1.61) < 0.011,
		"%.3f" % (v.get_arbiter().clock() - t0))
	_run(v, 1.2)
	_check("the swords landed (damage dealt)", v.get_state().enemy_hp < hp0)
	_drop(holder)


func test_labels_vi_en() -> void:
	var keys: Dictionary = {"ui.hud.cancel": ["Hủy", "Cancel"], "ui.hud.channel_cancel_cost": ["mất khối · thẻ vẫn hồi chiêu",
		"Blocks lost · card stays on cooldown"], "ui.hud.channel_cancelled": ["ĐÃ HỦY", "CANCELLED"],
		"ui.hud.channel_cancelled_sub": ["khối đã dùng · thẻ vẫn hồi chiêu", "Blocks spent · card on cooldown"],
		"ui.hud.channel_committed": ["ĐÃ CHỐT", "COMMITTED"], "ui.hud.channel_committed_sub": ["không thể hủy nữa", "too late to cancel"]}
	var old: String = TranslationServer.get_locale()
	for k: String in keys:
		TranslationServer.set_locale("vi")
		var vi: String = TranslationServer.translate(k)
		TranslationServer.set_locale("en")
		var en: String = TranslationServer.translate(k)
		_check("label %s: vi '%s' / en '%s'" % [k, vi, en], vi == keys[k][0] and en == keys[k][1])
	TranslationServer.set_locale(old)

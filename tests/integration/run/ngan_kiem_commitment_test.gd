extends SceneTree
## Cast Commitment, Ngàn Kiếm prototype (design/quick-specs/cast-commitment-ngan-kiem-2026-11-08.md), in a real
## CombatView: PLANNING -> CHANNELING -> COMMIT -> RESOLUTION, CHANNELING -> CANCELLED / INTERRUPTED; the channel root
## and the 0.13 s commit lock; cancel policy "spent" (no attack, no damage, cooldown kept); commit wins a same-tick
## cancel; the accidental-tap guard; Hủy (touch) and Esc through the real CutHudView; pause; hero death in every phase;
## the impact times after the card choice unchanged; other cards untouched. The boss brain is kept still and time is
## stepped by hand: deterministic.
## Run: godot --headless --path . -s res://tests/integration/run/ngan_kiem_commitment_test.gd

const SEED: int = 11
const STEP: float = 0.01
const ID: String = "ngan_kiem"
const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const EPS: float = 0.011  # one STEP of slack on times read between ticks

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	await process_frame
	await test_timing_and_phases()
	await test_cancel_before_commit()
	await test_accidental_tap_guard()
	await test_commit_wins_same_tick()
	await test_cancel_after_commit_refused()
	await test_touch_and_esc_inputs()
	await test_pause_rules()
	await test_boss_interrupt()
	await test_death_in_every_phase()
	await test_other_cards_untouched()
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
	v.match_params = {"end_delay_sec": 0.0}
	v.drops_seed = SEED
	v.freeze_time = true
	holder.add_child(v)
	var hud := CutHudView.new()
	hud.name = "CutHudView"
	holder.add_child(hud)
	root.add_child(holder)
	await process_frame
	v.set_process(false)  # time is stepped by hand below
	v.get_boss().set_active(false)
	if v.get_pattern_controller() != null:
		v.get_pattern_controller().set_process(false)
	v.freeze_time = false
	return holder


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


func _view(holder: Node) -> CombatView:
	return holder.get_node("CombatView") as CombatView


# The card choice: the real _begin_cut (swing + cooldown), as CutFlow's skill_chosen leads to.
func _choose(v: CombatView, card: String) -> void:
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece("bar4", 0)]
	var ctx: Dictionary = CastContext.build(card, 1, pieces, [BAR4], v.delivery_for(card), false, CombatState.Side.PLAYER,
		v.get_state().player_cell, {"t_cast": v.get_arbiter().clock()})
	v._begin_cut(card, BAR4, {}, {}, ctx)


func _free_dir(v: CombatView) -> Vector2i:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if v.get_grid().is_player_cell(v.get_state().player_cell + d):
			return d
	return Vector2i.ZERO


func _run_until(v: CombatView, cond: Callable, max_sec: float) -> bool:
	var t: float = 0.0
	while t < max_sec:
		if bool(cond.call()):
			return true
		v._process(STEP)
		t += STEP
	return bool(cond.call())


func _run(v: CombatView, sec: float) -> void:
	_run_until(v, func() -> bool: return false, sec)


func test_timing_and_phases() -> void:
	var holder: Node = await _match()
	var v: CombatView = _view(holder)
	var s: Dictionary = v.get_skill_config().get_skill(ID)
	_check("data: channel +0.28, hover 0.22, commit lock 0.13, policy spent", is_equal_approx(float(s["channel_extend_sec"]), 0.28)
		and is_equal_approx(float(s["sky_hover_sec"]), 0.22) and is_equal_approx(float(s["commit_lock_sec"]), 0.13)
		and s["cancel_policy"] == "spent" and not s.has("cast_root_lead_sec"))
	_check("PLANNING (nothing chosen): no phase", v.channel_phase() == CombatView.PHASE_NONE)
	var t0: float = v.get_arbiter().clock()
	_choose(v, ID)
	var actor: CutActor = v.get_cut_actor()
	_check("CHANNELING after the card choice; 4 cells = 0.2 + 4 x 0.25 + 0.28 = 1.48 s", v.channel_phase() == CombatView.PHASE_CHANNELING
		and is_equal_approx(actor.get_duration(), 1.48), "%.3f" % actor.get_duration())
	var dir: Vector2i = _free_dir(v)
	var start: Vector2i = v.get_state().player_cell
	_run(v, 0.7)
	_check("channel root: the step is refused, the hero stays", v.is_cast_rooted() and not v.try_step_player(dir)
		and v.get_state().player_cell == start)
	_check("the root blocks steps only (Focus / Awakening lock untouched)", not v.is_movement_locked() and v.is_step_locked())
	_run_until(v, func() -> bool: return v.channel_phase() != CombatView.PHASE_CHANNELING, 2.0)
	var commit_t: float = v.get_arbiter().clock()
	_check("COMMIT at the swing end (1.48 s after the choice)", v.channel_phase() == CombatView.PHASE_COMMIT
		and absf(commit_t - t0 - 1.48) <= EPS, "%.3f" % (commit_t - t0))
	var first_at: float = v.get_arbiter().first_event_at()
	_check("first impact 1.70 s after the choice (as before: 1.2 + 0.5), 0.22 after the commit",
		absf(first_at - t0 - 1.70) <= EPS, "%.3f" % (first_at - t0))
	_check("commit lock: the step is refused", not v.try_step_player(dir) and v.get_state().player_cell == start)
	_run_until(v, func() -> bool: return v.channel_phase() != CombatView.PHASE_COMMIT, 0.5)
	var unlock_t: float = v.get_arbiter().clock()
	_check("RESOLUTION 0.13 s after the commit", v.channel_phase() == CombatView.PHASE_RESOLUTION
		and absf(unlock_t - commit_t - 0.13) <= EPS, "%.3f" % (unlock_t - commit_t))
	_check("movement restored: the step is accepted, the swords keep their schedule", v.try_step_player(dir)
		and v.get_arbiter().first_event_at() == first_at)
	_run(v, 1.0)
	_check("after the last impact: no phase", v.channel_phase() == CombatView.PHASE_NONE)
	_drop(holder)


func test_cancel_before_commit() -> void:
	var holder: Node = await _match()
	var v: CombatView = _view(holder)
	var hp0: float = v.get_state().enemy_hp
	_choose(v, ID)
	var cd_full: float = float(v.get_skill_config().resolved(ID, 1)["cooldown_sec"])
	_run(v, 0.6)
	_check("cancel requested mid-channel", v.request_channel_cancel())
	v._process(STEP)
	_check("CANCELLED: no swing, no phase", not v.get_cut_actor().is_swinging() and v.channel_phase() == CombatView.PHASE_NONE)
	_check("no attack scheduled, no pending impact", v.get_arbiter().first_event_at() == INF and v.get_arbiter().active_cast_count() == 0)
	_check("cost: the full cooldown keeps running", v.get_skill_cooldowns().remaining(ID) > cd_full - 0.7, "%.2f" % v.get_skill_cooldowns().remaining(ID))
	var flash: Dictionary = v.get_channel_flash()
	_check("feedback: ĐÃ HỦY on the cast cells", not flash.is_empty() and not bool(flash["refused"]) and (flash["cells"] as Array).size() == 4)
	var drops: Array[Dictionary] = v.get_sky_drops()
	_check("the uncommitted swords disperse (no impact)", not drops.is_empty() and drops.all(func(d: Dictionary) -> bool:
		return bool(d.get("disperse", false))))
	var dir: Vector2i = _free_dir(v)
	_check("movement restored at once", v.try_step_player(dir))
	_run(v, 2.0)
	_check("no damage from the cancelled cast", is_equal_approx(v.get_state().enemy_hp, hp0))
	_check("nothing left to draw", v.get_sky_drops().is_empty())
	_drop(holder)


func test_accidental_tap_guard() -> void:
	var holder: Node = await _match()
	var v: CombatView = _view(holder)
	_choose(v, ID)
	_run(v, 0.1)
	_check("inside the first 0.15 s: the cancel is ignored", not v.can_cancel_channel() and not v.request_channel_cancel())
	v._process(STEP)
	_check("the channel goes on", v.channel_phase() == CombatView.PHASE_CHANNELING)
	_run(v, 0.06)
	_check("after 0.15 s: cancel allowed", v.can_cancel_channel())
	_drop(holder)


func test_commit_wins_same_tick() -> void:
	var holder: Node = await _match()
	var v: CombatView = _view(holder)
	_choose(v, ID)
	# stop while exactly one tick of the channel is left: the next tick both resolves the swing and handles the request
	_run_until(v, func() -> bool: return v.get_cut_actor().is_swinging() and v.get_cut_actor().get_time_left() <= STEP + 0.000001, 2.0)
	_check("cancel requested in the very tick the channel ends", v.request_channel_cancel())
	v._process(STEP)
	_check("commit wins: the cast is scheduled", v.channel_phase() == CombatView.PHASE_COMMIT and v.get_arbiter().first_event_at() < INF)
	var flash: Dictionary = v.get_channel_flash()
	_check("feedback: ĐÃ CHỐT (refused)", not flash.is_empty() and bool(flash["refused"]))
	_drop(holder)


func test_cancel_after_commit_refused() -> void:
	var holder: Node = await _match()
	var v: CombatView = _view(holder)
	_choose(v, ID)
	_run_until(v, func() -> bool: return v.channel_phase() == CombatView.PHASE_COMMIT, 2.0)
	_check("COMMIT: cancel refused", not v.request_channel_cancel() and bool(v.get_channel_flash().get("refused", false)))
	_run_until(v, func() -> bool: return v.channel_phase() == CombatView.PHASE_RESOLUTION, 0.5)
	var first_at: float = v.get_arbiter().first_event_at()
	_check("RESOLUTION: cancel refused, the schedule stays", not v.request_channel_cancel() and v.get_arbiter().first_event_at() == first_at)
	_drop(holder)


func test_touch_and_esc_inputs() -> void:
	var holder: Node = await _match()
	var v: CombatView = _view(holder)
	var hud: CutHudView = holder.get_node("CutHudView") as CutHudView
	var vp: Vector2 = hud.get_viewport_rect().size
	var cancel_pt: Vector2 = ScreenLayout.channel_cancel_hit_rect(vp).get_center()
	_choose(v, ID)
	_run(v, 0.05)
	_check("touch inside the guard: consumed, nothing cancelled", hud._press_at(cancel_pt, false) and v.channel_phase() == CombatView.PHASE_CHANNELING
		and not v._cancel_requested)
	_check("the Hủy button is shown while channeling", v.is_channel_cancel_shown())
	var cancel_rect: Rect2 = ScreenLayout.channel_cancel_hit_rect(vp)
	_check("the channel's Hủy is on the right half (away from the joystick), above the Block bag, overlapping no bag slot",
		cancel_rect.position.x > vp.x * 0.5 and ScreenLayout.slot_hit_rects(vp, HoldSlots.MAX_SLOTS).all(func(r: Rect2) -> bool:
			return not r.intersects(cancel_rect)))
	_run(v, 0.2)
	hud._press_at(ScreenLayout.cancel_hit_rect(vp, true).get_center(), false)
	_check("past the guard, a press on Tung phép's old corner (the joystick side) does not cancel", not v._cancel_requested
		and v.channel_phase() == CombatView.PHASE_CHANNELING)
	_check("touch on Hủy after the guard: queued", hud._press_at(cancel_pt, false) and v._cancel_requested)
	v._process(STEP)
	_check("touch cancel done", v.channel_phase() == CombatView.PHASE_NONE and not v.is_channel_cancel_shown())
	_drop(holder)
	holder = await _match()
	v = _view(holder)
	hud = holder.get_node("CutHudView") as CutHudView
	_choose(v, ID)
	_run(v, 0.3)
	_check("Esc during the channel: taken", hud._piece_key(KEY_ESCAPE))
	v._process(STEP)
	_check("Esc cancel done", v.channel_phase() == CombatView.PHASE_NONE)
	_drop(holder)


func test_pause_rules() -> void:
	var holder: Node = await _match()
	var v: CombatView = _view(holder)
	_choose(v, ID)
	_run(v, 0.3)
	_check("pause allowed early in the channel", v.can_pause())
	_run_until(v, func() -> bool: return v.get_cut_actor().get_time_left() < 0.4, 2.0)
	_check("pause refused in the channel's last 0.5 s", not v.can_pause())
	_run_until(v, func() -> bool: return v.channel_phase() == CombatView.PHASE_COMMIT, 1.0)
	_check("pause refused during the commit lock", not v.can_pause())
	_run_until(v, func() -> bool: return v.channel_phase() == CombatView.PHASE_RESOLUTION, 0.5)
	_check("pause allowed again in RESOLUTION", v.can_pause())
	_drop(holder)


func test_boss_interrupt() -> void:
	var holder: Node = await _match()
	var v: CombatView = _view(holder)
	var hp0: float = v.get_state().enemy_hp
	_choose(v, ID)
	_run(v, 0.3)
	var boss_actor: CutActor = v.get_boss().get_actor()
	boss_actor.begin_swing([v.get_state().player_cell] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, false, 1, 0.2)
	_run(v, 0.3)
	_check("INTERRUPTED by the boss's hit: no swing, no attack", not v.get_cut_actor().is_swinging()
		and v.get_arbiter().first_event_at() == INF and v.channel_phase() == CombatView.PHASE_NONE)
	_check("interrupt costs the same (cooldown kept)", v.get_skill_cooldowns().remaining(ID) > 0.0)
	_run(v, 2.0)
	_check("no damage from the interrupted cast", is_equal_approx(v.get_state().enemy_hp, hp0))
	_drop(holder)


func test_death_in_every_phase() -> void:
	for phase: String in [CombatView.PHASE_CHANNELING, CombatView.PHASE_COMMIT, CombatView.PHASE_RESOLUTION]:
		var holder: Node = await _match()
		var v: CombatView = _view(holder)
		var hp0: float = v.get_state().enemy_hp
		_choose(v, ID)
		_run_until(v, func() -> bool: return v.channel_phase() == phase, 3.0)
		var reached: bool = v.channel_phase() == phase
		v.get_state().set_player_hp(0.0)
		_run(v, 2.0)
		_check("hero dies in %s: everything cleared, no damage" % phase, reached and v.get_arbiter().first_event_at() == INF
			and not v.get_cut_actor().is_swinging() and is_equal_approx(v.get_state().enemy_hp, hp0))
		_drop(holder)


func test_other_cards_untouched() -> void:
	var holder: Node = await _match()
	var v: CombatView = _view(holder)
	_check("tram_dia is not a commitment card", not v.is_commitment_card("tram_dia"))
	_choose(v, "tram_dia")
	_check("tram_dia swing unchanged (0.2 + 4 x 0.25 = 1.2 s)", is_equal_approx(v.get_cut_actor().get_duration(), 1.2))
	var dir: Vector2i = _free_dir(v)
	var start: Vector2i = v.get_state().player_cell
	_run(v, 0.5)
	_check("tram_dia: no phase, the step is accepted, no Hủy", v.channel_phase() == CombatView.PHASE_NONE and v.try_step_player(dir)
		and v.get_state().player_cell == start + dir and not v.is_channel_cancel_shown())
	_drop(holder)

extends SceneTree
## Controls v3 HUD maths (design/quick-specs/bo-cuc-dieu-khien-v3-2026-11-02.md; pure, headless):
## - HudFuse: the burnt fraction goes 0 -> 1 with the time; the path starts at 12 o'clock and runs CLOCKWISE (right
##   along the top first, the bottom centre half-way round a square, the left middle at three quarters); the part still
##   to burn shrinks to nothing;
## - CutHudView.pick_fuse: the place window or Focus, whichever ends first; nothing when neither runs;
## - StatusEffects.active_statuses: exactly the active statuses of a side, in order, with their remaining fractions,
##   and nothing once they end; StatusRow's clockwise shade over the time gone;
## - EffectText.pop_scale: a short pop that ends at exactly 1, none with reduce motion.
## Run: godot --headless --path . -s res://tests/unit/ui/controls_v3_hud_test.gd

const EPS: float = 0.001
const PLAYER: int = CombatState.Side.PLAYER
const ENEMY: int = CombatState.Side.ENEMY

var fails: int = 0


func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_fuse_burnt_fraction_goes_0_to_1()
	test_fuse_path_runs_clockwise_from_12()
	test_fuse_remaining_shrinks_to_nothing()
	test_pick_fuse_shows_the_one_that_ends_first()
	test_active_statuses_exactly_the_active_ones_with_fractions()
	test_status_shade_clockwise_from_12()
	test_status_row_missing_icons_are_listed()
	test_effect_text_pop()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_fuse_burnt_fraction_goes_0_to_1() -> void:
	check("test_fuse_fraction_full_time_is_0", is_equal_approx(HudFuse.burnt_fraction(3.0, 3.0), 0.0))
	check("test_fuse_fraction_half_time_is_0_5", is_equal_approx(HudFuse.burnt_fraction(1.5, 3.0), 0.5))
	check("test_fuse_fraction_time_up_is_1", is_equal_approx(HudFuse.burnt_fraction(0.0, 3.0), 1.0))
	check("test_fuse_fraction_clamped", is_equal_approx(HudFuse.burnt_fraction(4.0, 3.0), 0.0) and is_equal_approx(HudFuse.burnt_fraction(-1.0, 3.0), 1.0))
	check("test_fuse_without_length_is_burnt", is_equal_approx(HudFuse.burnt_fraction(1.0, 0.0), 1.0))
	var prev: float = -1.0
	var rising: bool = true
	for i: int in 31:
		var f: float = HudFuse.burnt_fraction(3.0 - 0.1 * i, 3.0)
		rising = rising and f > prev
		prev = f
	check("test_fuse_fraction_rises_as_time_passes", rising)


func test_fuse_path_runs_clockwise_from_12() -> void:
	var square := Rect2(100, 100, 80, 80)
	var pts: PackedVector2Array = HudFuse.path(square, 0.0)
	check("test_fuse_path_starts_and_ends_at_the_top_centre", pts[0] == Vector2(140, 100) and pts[pts.size() - 1] == Vector2(140, 100))
	check("test_fuse_path_length_is_the_perimeter", absf(HudFuse.length(pts) - 320.0) < EPS, str(HudFuse.length(pts)))
	var early: Vector2 = HudFuse.point_at(pts, 0.05)
	check("test_fuse_head_moves_right_along_the_top_first_clockwise", early.x > 140.0 and is_equal_approx(early.y, 100.0), str(early))
	check("test_fuse_quarter_is_the_right_middle", HudFuse.point_at(pts, 0.25).is_equal_approx(Vector2(180, 140)), str(HudFuse.point_at(pts, 0.25)))
	check("test_fuse_half_is_the_bottom_centre", HudFuse.point_at(pts, 0.5).is_equal_approx(Vector2(140, 180)), str(HudFuse.point_at(pts, 0.5)))
	check("test_fuse_three_quarters_is_the_left_middle", HudFuse.point_at(pts, 0.75).is_equal_approx(Vector2(100, 140)), str(HudFuse.point_at(pts, 0.75)))
	var cut: PackedVector2Array = HudFuse.path(Rect2(0, 0, 100, 64), 6.0)
	check("test_fuse_chamfered_path_has_the_cut_corners", cut.size() == 10 and cut[1] == Vector2(94, 0) and cut[2] == Vector2(100, 6), str(cut))


func test_fuse_remaining_shrinks_to_nothing() -> void:
	var pts: PackedVector2Array = HudFuse.path(Rect2(0, 0, 100, 64), 6.0)
	var total: float = HudFuse.length(pts)
	check("test_fuse_remaining_at_0_is_the_whole_fuse", absf(HudFuse.length(HudFuse.remaining(pts, 0.0)) - total) < EPS)
	check("test_fuse_remaining_at_1_is_empty", HudFuse.remaining(pts, 1.0).size() < 2)
	var ok: bool = true
	for i: int in range(1, 10):
		var f: float = i / 10.0
		var left: PackedVector2Array = HudFuse.remaining(pts, f)
		ok = ok and absf(HudFuse.length(left) - total * (1.0 - f)) < 0.01 and left[0].is_equal_approx(HudFuse.point_at(pts, f))
	check("test_fuse_remaining_length_is_the_unburnt_share_from_the_head", ok)


func test_pick_fuse_shows_the_one_that_ends_first() -> void:
	check("test_pick_fuse_place_window_only", CutHudView.pick_fuse(2.0, 3.0, 0.0, 0.0) == Vector2(2.0, 3.0))
	check("test_pick_fuse_focus_only", CutHudView.pick_fuse(0.0, 0.0, 3.5, 4.0) == Vector2(3.5, 4.0))
	check("test_pick_fuse_both_focus_ends_first", CutHudView.pick_fuse(2.5, 3.0, 1.0, 4.0) == Vector2(1.0, 4.0))
	check("test_pick_fuse_both_place_window_ends_first", CutHudView.pick_fuse(0.8, 3.0, 2.0, 4.0) == Vector2(0.8, 3.0))
	check("test_pick_fuse_unlimited_window_ignored", CutHudView.pick_fuse(0.0, 0.0, 0.0, 4.0) == Vector2.ZERO)
	check("test_pick_fuse_nothing_running_is_none", CutHudView.pick_fuse(0.0, 3.0, 0.0, 4.0) == Vector2.ZERO)


func test_active_statuses_exactly_the_active_ones_with_fractions() -> void:
	var status := StatusEffects.new()
	status.configure_keywords(1.5, 3, 3, 10.0)
	var state := CombatState.new(BoardGrid.new(3, 3), 1000.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))
	var cell: Vector2i = state.player_cell
	check("test_no_status_lists_nothing", status.active_statuses(PLAYER, cell).is_empty())
	status.root(PLAYER, 4.0)
	status.slow(PLAYER, 6.0, 1.5)
	status.guard(PLAYER, 3.0, 8.0)
	status.apply_fragile(PLAYER, 2)
	status.slow(ENEMY, 9.0, 2.0)
	status.tick(1.0, state)
	var list: Array[Dictionary] = status.active_statuses(PLAYER, cell)
	var ids: Array[String] = []
	for e: Dictionary in list:
		ids.append(str(e["id"]))
	check("test_active_statuses_are_exactly_root_slow_fragile_guard_in_order", ids == (["root", "slow", "fragile", "guard"] as Array[String]), str(ids))
	var fractions: Dictionary = {}
	for e: Dictionary in list:
		fractions[str(e["id"])] = StatusEffects.status_left_fraction(e)
	check("test_root_fraction_3_of_4", absf(float(fractions["root"]) - 0.75) < EPS, str(fractions))
	check("test_slow_fraction_5_of_6", absf(float(fractions["slow"]) - 5.0 / 6.0) < EPS, str(fractions))
	check("test_guard_fraction_7_of_8_and_is_a_buff", absf(float(fractions["guard"]) - 0.875) < EPS and bool(list[3]["buff"]), str(list[3]))
	check("test_fragile_is_a_stack_status_full_pie_2_stacks", is_equal_approx(float(fractions["fragile"]), 1.0) and int(list[2]["stacks"]) == 2, str(list[2]))
	status.slow(PLAYER, 2.0, 1.2)
	var slow_e: Dictionary = status.active_statuses(PLAYER, cell)[1]
	check("test_reapplying_a_shorter_slow_keeps_the_longer_time_and_its_total", absf(float(slow_e["left"]) - 5.0) < EPS and absf(float(slow_e["total"]) - 5.0) < EPS, str(slow_e))
	status.ignite([cell] as Array[Vector2i], 5.0, 1.0, 1.0)
	status.tick(2.0, state)
	var burn: Dictionary = {}
	for e: Dictionary in status.active_statuses(PLAYER, cell):
		if str(e["id"]) == "burn":
			burn = e
	check("test_burn_listed_while_the_player_cell_burns_with_its_fraction", not burn.is_empty() and absf(StatusEffects.status_left_fraction(burn) - 0.6) < EPS, str(burn))
	check("test_burn_not_listed_for_another_cell", status.active_statuses(PLAYER, Vector2i(0, 0) if cell != Vector2i(0, 0) else Vector2i(1, 0)).all(
		func(e: Dictionary) -> bool: return str(e["id"]) != "burn"))
	status.tick(10.0, state)
	var after: Array[String] = []
	for e: Dictionary in status.active_statuses(PLAYER, cell):
		after.append(str(e["id"]))
	check("test_timed_statuses_leave_when_they_end_stacks_stay", after == (["fragile"] as Array[String]), str(after))
	status.pin(PLAYER, 2.0)
	var frozen: Dictionary = status.active_statuses(PLAYER, cell)[0]
	check("test_frozen_listed_first_full_fraction", str(frozen["id"]) == "frozen" and is_equal_approx(StatusEffects.status_left_fraction(frozen), 1.0), str(frozen))
	status.clear()
	check("test_clear_lists_nothing", status.active_statuses(PLAYER, cell).is_empty())


func test_status_shade_clockwise_from_12() -> void:
	var r := Rect2(0, 0, 40, 40)
	check("test_status_shade_none_at_0", StatusRow.shade_polygons(r, 0.0).is_empty())
	check("test_status_shade_whole_frame_at_1", StatusRow.shade_polygons(r, 1.0).size() == 1)
	check("test_status_shade_quarter_covers_the_top_right", StatusRow.is_shaded(r, 0.25, Vector2(30, 10)) and not StatusRow.is_shaded(r, 0.25, Vector2(10, 30)) and not StatusRow.is_shaded(r, 0.25, Vector2(10, 10)))
	check("test_status_shade_three_quarters_leaves_the_top_left", StatusRow.is_shaded(r, 0.75, Vector2(10, 30)) and not StatusRow.is_shaded(r, 0.75, Vector2(10, 10)))
	check("test_status_hand_at_quarter_points_right", StatusRow.hand_end(r, 0.25).is_equal_approx(Vector2(40, 20)), str(StatusRow.hand_end(r, 0.25)))
	check("test_status_frame_is_angular_8_corners", StatusRow.frame_points(r).size() == 8)


func test_status_row_missing_icons_are_listed() -> void:
	var missing: Array[String] = StatusRow.missing_icons()
	check("test_root_and_slow_have_no_sheet_icon_yet", missing.has("root") and missing.has("slow"), str(missing))
	check("test_sheet_statuses_are_not_missing", not missing.has("burn") and not missing.has("frozen") and not missing.has("guard"), str(missing))
	for id: String in StatusEffects.STATUS_ORDER:
		var keys: Array[String] = StatusRow.text_keys(id)
		check("test_status_%s_has_name_and_effect_keys" % id, not keys[0].is_empty() and not keys[1].is_empty(), str(keys))


func test_effect_text_pop() -> void:
	check("test_pop_starts_bigger", EffectText.pop_scale(0.0, false) > 1.2)
	check("test_pop_ends_at_exactly_1", is_equal_approx(EffectText.pop_scale(EffectText.POP_SEC, false), 1.0) and is_equal_approx(EffectText.pop_scale(5.0, false), 1.0))
	check("test_pop_shrinks_over_time", EffectText.pop_scale(0.05, false) > EffectText.pop_scale(0.1, false))
	check("test_reduce_motion_never_pops", is_equal_approx(EffectText.pop_scale(0.0, true), 1.0))
	check("test_effect_text_about_1_2x_plain", EffectText.size_for(20) == 24)

extends SceneTree
## Story 047 Part C: unit sprites of UnitLayer (headless). Pure part: UnitLayer.clip_for (the whole
## priority table), unit_ids_for, sprite_dest_rect (feet anchor, odd widths, the mirrored rect),
## facing_for. Scene part: the real battle (main.tscn, as battle_canvas_test) twice: the fast_run
## fixture without a character and with a sheetless match id (ids "" / "test_no_sheet" -> both placeholders, clip idle, no crash), then
## kiem_si vs goblin_scout (the fast_run timings with the first match id swapped) where both sheets
## resolve and the clips follow the match: hit for HIT_SEC after damage, step for the step cooldown,
## cast_gesture once on swing_started, down / victory when the boss dies, defeat when the player dies.
## The animators are driven by UnitLayer.advance with freeze_time on (so the frame clock adds 0).
## Headless, the SubViewport may never reach _draw; the draw signal count is printed, not asserted.
## Run: godot --headless --path . -s res://tests/unit/battle/unit_sprites_test.gd

const MAX_FRAMES: int = 600
const DRAW_FRAMES: int = 10
const PLAYER: int = CombatState.Side.PLAYER
const ENEMY: int = CombatState.Side.ENEMY
const HERO: String = "kiem_si"
const BOSS: String = "goblin_scout"
const FIXTURE_RUN: String = "res://tests/fixtures/fast_run.json"
## A match id with no unit sheet: the placeholder path (the shared fixture now uses real, drawn enemies).
const FIXTURE_BOSS_ID: String = "test_no_sheet"
const HIT: float = 5.0
const OVERKILL: float = 10000.0
const CAST_SEC: float = 0.5
## Longer than every once-clip of the sheets (cast_gesture 200 ms, hit 120 ms, down 300 ms).
const LONG_SEC: float = 1.0
const EPS: float = 0.0001
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var fails: int = 0
var _draw_count: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_clip_for_priority_table()
	test_clip_for_side_only_rows_do_not_leak_to_the_other_side()
	test_unit_ids_for()
	test_sprite_dest_rect()
	test_facing_for()
	await test_battle_without_a_character_uses_placeholders()
	await test_battle_kiem_si_vs_goblin_scout()
	_finish()


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(fails)


func _ctx(side: int, flags: Array) -> Dictionary:
	var ctx: Dictionary = {UnitLayer.CTX_SIDE: side}
	for flag: String in flags:
		ctx[flag] = true
	return ctx


# The nine rows, each with every lower-priority flag also on, so the row proves its rank.
func test_clip_for_priority_table() -> void:
	var all_player: Array[String] = [UnitLayer.CTX_OPPONENT_DEAD, UnitLayer.CTX_HIT, UnitLayer.CTX_CASTING, UnitLayer.CTX_AWAKEN, UnitLayer.CTX_STEPPING]
	var all_enemy: Array[String] = [UnitLayer.CTX_HIT, UnitLayer.CTX_SWINGING, UnitLayer.CTX_STEPPING]
	_check("test_row_defeat_player_dead_over_everything", UnitLayer.clip_for(_ctx(PLAYER, [UnitLayer.CTX_DEAD] + all_player)) == UnitLayer.CLIP_DEFEAT)
	_check("test_row_down_enemy_dead_over_everything", UnitLayer.clip_for(_ctx(ENEMY, [UnitLayer.CTX_DEAD] + all_enemy)) == UnitLayer.CLIP_DOWN)
	_check("test_row_down_enemy_downed_not_dead", UnitLayer.clip_for(_ctx(ENEMY, [UnitLayer.CTX_DOWNED] + all_enemy)) == UnitLayer.CLIP_DOWN)
	_check("test_row_victory_player_alive_enemy_dead_over_hit", UnitLayer.clip_for(_ctx(PLAYER, all_player)) == UnitLayer.CLIP_VICTORY)
	_check("test_row_hit_over_cast_awaken_step", UnitLayer.clip_for(_ctx(PLAYER, [UnitLayer.CTX_HIT, UnitLayer.CTX_CASTING, UnitLayer.CTX_AWAKEN, UnitLayer.CTX_STEPPING])) == UnitLayer.CLIP_HIT)
	_check("test_row_hit_enemy_over_windup_step", UnitLayer.clip_for(_ctx(ENEMY, all_enemy)) == UnitLayer.CLIP_HIT)
	_check("test_row_cast_gesture_over_awaken_step", UnitLayer.clip_for(_ctx(PLAYER, [UnitLayer.CTX_CASTING, UnitLayer.CTX_AWAKEN, UnitLayer.CTX_STEPPING])) == UnitLayer.CLIP_CAST)
	_check("test_row_windup_over_step", UnitLayer.clip_for(_ctx(ENEMY, [UnitLayer.CTX_SWINGING, UnitLayer.CTX_STEPPING])) == UnitLayer.CLIP_WINDUP)
	_check("test_row_awaken_over_step", UnitLayer.clip_for(_ctx(PLAYER, [UnitLayer.CTX_AWAKEN, UnitLayer.CTX_STEPPING])) == UnitLayer.CLIP_AWAKEN)
	_check("test_row_step_player", UnitLayer.clip_for(_ctx(PLAYER, [UnitLayer.CTX_STEPPING])) == UnitLayer.CLIP_STEP)
	_check("test_row_step_enemy", UnitLayer.clip_for(_ctx(ENEMY, [UnitLayer.CTX_STEPPING])) == UnitLayer.CLIP_STEP)
	_check("test_row_idle_player_nothing_set", UnitLayer.clip_for(_ctx(PLAYER, [])) == UnitLayer.CLIP_IDLE)
	_check("test_row_idle_enemy_nothing_set", UnitLayer.clip_for(_ctx(ENEMY, [])) == UnitLayer.CLIP_IDLE)
	_check("test_empty_context_is_player_idle", UnitLayer.clip_for({}) == UnitLayer.CLIP_IDLE)


func test_clip_for_side_only_rows_do_not_leak_to_the_other_side() -> void:
	_check("test_enemy_ignores_casting_and_awaken", UnitLayer.clip_for(_ctx(ENEMY, [UnitLayer.CTX_CASTING, UnitLayer.CTX_AWAKEN])) == UnitLayer.CLIP_IDLE)
	_check("test_enemy_has_no_victory_when_the_player_dies", UnitLayer.clip_for(_ctx(ENEMY, [UnitLayer.CTX_OPPONENT_DEAD])) == UnitLayer.CLIP_IDLE)
	_check("test_player_ignores_swinging", UnitLayer.clip_for(_ctx(PLAYER, [UnitLayer.CTX_SWINGING])) == UnitLayer.CLIP_IDLE)
	_check("test_player_dead_beats_victory", UnitLayer.clip_for(_ctx(PLAYER, [UnitLayer.CTX_DEAD, UnitLayer.CTX_OPPONENT_DEAD])) == UnitLayer.CLIP_DEFEAT)


func test_unit_ids_for() -> void:
	var ids: Dictionary = UnitLayer.unit_ids_for({"id": BOSS, "character": {"id": HERO}})
	_check("test_ids_character_id_and_match_id", ids[PLAYER] == HERO and ids[ENEMY] == BOSS, str(ids))
	var none: Dictionary = UnitLayer.unit_ids_for({})
	_check("test_ids_empty_params_give_empty_ids", none[PLAYER] == "" and none[ENEMY] == "")
	var odd: Dictionary = UnitLayer.unit_ids_for({"id": FIXTURE_BOSS_ID, "character": "kiem_si"})
	_check("test_ids_non_dictionary_character_gives_empty_player_id", odd[PLAYER] == "" and odd[ENEMY] == FIXTURE_BOSS_ID)


func test_sprite_dest_rect() -> void:
	var feet := Vector2i(100, 200)
	_check("test_dest_40x48_bottom_centre_on_the_feet", UnitLayer.sprite_dest_rect(feet, Vector2i(40, 48), false) == Rect2(80, 152, 40, 48))
	_check("test_dest_32x48_bottom_centre_on_the_feet", UnitLayer.sprite_dest_rect(feet, Vector2i(32, 48), false) == Rect2(84, 152, 32, 48))
	_check("test_dest_odd_width_floors_the_left_edge", UnitLayer.sprite_dest_rect(feet, Vector2i(33, 48), false) == Rect2(84, 152, 33, 48))
	var flipped: Rect2 = UnitLayer.sprite_dest_rect(feet, Vector2i(40, 48), true)
	_check("test_dest_flipped_starts_at_the_right_edge_with_negative_width", flipped == Rect2(120, 152, -40, 48), str(flipped))
	_check("test_dest_flipped_covers_the_same_pixels", flipped.abs() == Rect2(80, 152, 40, 48))
	var odd_feet := Vector2i(101, 200)
	_check("test_dest_integer_positions_for_an_odd_feet_x", UnitLayer.sprite_dest_rect(odd_feet, Vector2i(40, 48), false).position == Vector2(81, 152))


func test_facing_for() -> void:
	_check("test_player_faces_right_enemy_faces_left", UnitLayer.facing_for(PLAYER) == "right" and UnitLayer.facing_for(ENEMY) == "left")
	_check("test_kiem_si_sheet_faces_right_no_flip", SpriteSheet.load_unit(HERO) != null and SpriteSheet.load_unit(HERO).facing() == UnitLayer.facing_for(PLAYER))
	_check("test_goblin_scout_sheet_faces_left_no_flip", SpriteSheet.load_unit(BOSS) != null and SpriteSheet.load_unit(BOSS).facing() == UnitLayer.facing_for(ENEMY))


# Builds main.tscn, enters the test floor with [param config] and waits for PLAYING. Returns
# {main, flow, rc, battle, combat, canvas, units} or {} on failure.
func _enter_battle(flow_in: GameFlow, main_in: Node, config: RunConfig, character_id: String) -> Dictionary:
	var main: Node = main_in
	var flow: GameFlow = flow_in
	if main == null:
		root.size = Vector2i(1280, 720)
		main = load("res://src/main.tscn").instantiate()
		flow = main.get_node("GameFlow") as GameFlow
		flow.set_store_for_test(ProgressStore.memory_store())
		root.add_child(main)
		await process_frame
	flow.set_character(character_id)
	var rc: RunController = flow.enter_test_floor(config)
	await process_frame
	await process_frame
	for _i: int in MAX_FRAMES:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	_check("test_battle_spawned", battle != null)
	if battle == null:
		return {}
	var combat := battle.get_node("CombatView") as CombatView
	await process_frame
	var canvas := battle.get_child(0) as BattleCanvas
	_check("test_canvas_present", canvas != null and combat != null)
	if canvas == null or combat == null:
		return {}
	return {"main": main, "flow": flow, "rc": rc, "battle": battle, "combat": combat, "canvas": canvas, "units": canvas.get_unit_layer()}


func test_battle_without_a_character_uses_placeholders() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_RUN))
	(data["matches"][0] as Dictionary)["id"] = FIXTURE_BOSS_ID
	var b: Dictionary = await _enter_battle(null, null, RunConfig.from_dictionary(data), "")
	if b.is_empty():
		return
	var units: UnitLayer = b["units"]
	_check("test_fixture_player_id_empty_got_'%s'" % units.get_unit_id(PLAYER), units.get_unit_id(PLAYER) == "")
	_check("test_fixture_enemy_id_is_the_match_id_got_'%s'" % units.get_unit_id(ENEMY), units.get_unit_id(ENEMY) == FIXTURE_BOSS_ID)
	_check("test_fixture_both_units_are_placeholders", units.is_placeholder(PLAYER) and units.is_placeholder(ENEMY))
	_check("test_fixture_sheets_null", units.get_sheet(PLAYER) == null and units.get_sheet(ENEMY) == null)
	_check("test_fixture_clips_idle", units.get_current_clip(PLAYER) == UnitLayer.CLIP_IDLE and units.get_current_clip(ENEMY) == UnitLayer.CLIP_IDLE)
	var combat: CombatView = b["combat"]
	combat.get_state().damage_enemy(HIT)
	units.advance(0.0)
	_check("test_fixture_placeholder_still_tracks_the_logical_clip_hit", units.get_current_clip(ENEMY) == UnitLayer.CLIP_HIT)
	units.advance(UnitLayer.HIT_SEC)
	_check("test_fixture_placeholder_back_to_idle", units.get_current_clip(ENEMY) == UnitLayer.CLIP_IDLE)
	for _i: int in DRAW_FRAMES:
		await process_frame
	_check("test_fixture_frames_run_without_a_crash", is_instance_valid(units))
	(b["main"] as Node).queue_free()
	await process_frame
	await process_frame


func test_battle_kiem_si_vs_goblin_scout() -> void:
	# The fast_run timings with the first match renamed to the goblin's chapters.json id.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_RUN))
	(data["matches"][0] as Dictionary)["id"] = BOSS
	var b: Dictionary = await _enter_battle(null, null, RunConfig.from_dictionary(data), HERO)
	if b.is_empty():
		return
	var units: UnitLayer = b["units"]
	var combat: CombatView = b["combat"]
	var state: CombatState = combat.get_state()
	units.draw.connect(func() -> void: _draw_count += 1)
	_check("test_ids_resolve_kiem_si_vs_goblin_scout_got_%s_%s" % [units.get_unit_id(PLAYER), units.get_unit_id(ENEMY)], units.get_unit_id(PLAYER) == HERO and units.get_unit_id(ENEMY) == BOSS)
	_check("test_both_sheets_loaded", units.get_sheet(PLAYER) != null and units.get_sheet(ENEMY) != null)
	_check("test_both_textures_loaded_no_placeholder", not units.is_placeholder(PLAYER) and not units.is_placeholder(ENEMY))
	# 2026-11-08 (option A): the Knight frame is 96x92 (raised-sword headroom) with a 70 px body, bottom-aligned.
	_check("test_frame_sizes_96x92_body70_and_64x52", units.get_sheet(PLAYER).frame_size() == Vector2i(96, 92)
		and units.get_sheet(PLAYER).body_height() == 70 and units.get_sheet(ENEMY).frame_size() == Vector2i(64, 52))
	_check("test_clips_idle_after_setup", units.get_current_clip(PLAYER) == UnitLayer.CLIP_IDLE and units.get_current_clip(ENEMY) == UnitLayer.CLIP_IDLE)
	# 2026-11-02 guard stance: the hero opens the match with its `draw` clip (sword into the guard), then idles.
	_check("test_animators_play_draw_then_idle", units.get_animator(PLAYER).current_clip() in [UnitLayer.CLIP_DRAW, UnitLayer.CLIP_IDLE] and units.get_animator(ENEMY).current_clip() == UnitLayer.CLIP_IDLE, units.get_animator(PLAYER).current_clip())
	_check("test_reduce_motion_from_settings_off", not units.is_reduce_motion() and not units.get_animator(PLAYER).is_reduce_motion())
	# The frame clock adds 0 from here: the test drives advance() itself.
	combat.freeze_time = true
	await process_frame
	# Hit: HIT_SEC of priority, then idle.
	state.damage_enemy(HIT)
	units.advance(0.0)
	_check("test_enemy_hit_right_after_damage", units.get_current_clip(ENEMY) == UnitLayer.CLIP_HIT and units.get_animator(ENEMY).current_clip() == UnitLayer.CLIP_HIT)
	_check("test_player_untouched_stays_idle", units.get_current_clip(PLAYER) == UnitLayer.CLIP_IDLE)
	units.advance(UnitLayer.HIT_SEC * 0.5)
	_check("test_enemy_still_hit_at_half_HIT_SEC", units.get_current_clip(ENEMY) == UnitLayer.CLIP_HIT)
	units.advance(UnitLayer.HIT_SEC * 0.5 + EPS)
	_check("test_enemy_idle_after_HIT_SEC", units.get_current_clip(ENEMY) == UnitLayer.CLIP_IDLE and units.get_animator(ENEMY).current_clip() == UnitLayer.CLIP_IDLE)
	# Step: the clip lasts the step cooldown the mover just started.
	var mover: UnitMover = combat.get_mover()
	var stepped: bool = false
	var from_cell: Vector2i = state.player_cell
	for dir: Vector2i in DIRECTIONS:
		if mover.try_step(dir):
			stepped = true
			break
	_check("test_player_could_step", stepped)
	if stepped:
		var cooldown: float = mover.get_cooldown_remaining()
		_check("test_step_cooldown_positive_got_%.3f" % cooldown, cooldown > 0.0)
		units.advance(0.0)
		# 2026-11-02 OSFE dashes: the logical clip is `step`; the hero's animator plays the directional dash of that step.
		var dash: String = UnitLayer.step_clip_for(from_cell, state.player_cell, true)
		_check("test_player_step_after_cell_changed", units.get_current_clip(PLAYER) == UnitLayer.CLIP_STEP and units.get_animator(PLAYER).current_clip() == dash, units.get_animator(PLAYER).current_clip())
		_check("test_step_length_is_the_cooldown", is_equal_approx(units.get_step_left(PLAYER), cooldown))
		_check("test_step_runs_once_not_the_sheet_loop", units.get_animator(PLAYER).loop_kind() == UnitAnimator.ONCE)
		units.advance(cooldown * 0.5)
		_check("test_player_still_step_at_half_cooldown", units.get_current_clip(PLAYER) == UnitLayer.CLIP_STEP)
		var anim: UnitAnimator = units.get_animator(PLAYER)
		@warning_ignore("integer_division")
		# The dash keeps its own 50 ms frames (its lean meets the glide): by half the cooldown it is past its middle frame.
		_check("test_dash_frames_run_at_their_own_pace", anim.frame_index() >= anim.frame_count() / 2, "%d of %d" % [anim.frame_index(), anim.frame_count()])
		units.advance(cooldown * 0.5 + EPS)
		_check("test_player_idle_after_the_cooldown", units.get_current_clip(PLAYER) == UnitLayer.CLIP_IDLE and anim.current_clip() == UnitLayer.CLIP_IDLE)
	# Cast gesture: once, on the player's swing_started.
	combat.get_cut_actor().swing_started.emit([] as Array[Vector2i], "test", CAST_SEC)
	units.advance(0.0)
	_check("test_player_cast_gesture_on_swing_started", units.get_current_clip(PLAYER) == UnitLayer.CLIP_CAST and units.get_animator(PLAYER).current_clip() == UnitLayer.CLIP_CAST)
	units.advance(LONG_SEC)
	_check("test_player_idle_after_the_cast_gesture_finished", units.get_current_clip(PLAYER) == UnitLayer.CLIP_IDLE)
	# Ten frames with sprites bound (draw happens only when the SubViewport renders; headless may not).
	for _i: int in DRAW_FRAMES:
		await process_frame
	print("  draw signals during %d frames: %d (headless SubViewport)" % [DRAW_FRAMES, _draw_count])
	_check("test_frames_with_sprites_run_without_a_crash", is_instance_valid(units) and is_instance_valid(combat))
	# Boss dies: down (held on the last frame), the player wins: victory. Checked in the same frame (the
	# match end timer would free the battle later).
	state.enemy_invulnerable_left = 0.0
	state.enemy_hp_floor = 0.0
	state.damage_enemy(OVERKILL)
	units.advance(0.0)
	_check("test_enemy_down_when_dead", units.get_current_clip(ENEMY) == UnitLayer.CLIP_DOWN and units.get_animator(ENEMY).current_clip() == UnitLayer.CLIP_DOWN)
	_check("test_player_victory_when_the_boss_is_dead", units.get_current_clip(PLAYER) == UnitLayer.CLIP_VICTORY and units.get_animator(PLAYER).current_clip() == UnitLayer.CLIP_VICTORY)
	units.advance(LONG_SEC)
	var down: UnitAnimator = units.get_animator(ENEMY)
	_check("test_enemy_stays_down_on_the_last_frame", units.get_current_clip(ENEMY) == UnitLayer.CLIP_DOWN and down.current_clip() == UnitLayer.CLIP_DOWN and down.is_finished() and down.frame_index() == down.frame_count() - 1)
	state.damage_enemy(HIT)
	units.advance(0.0)
	_check("test_enemy_still_down_after_ignored_damage", units.get_current_clip(ENEMY) == UnitLayer.CLIP_DOWN)
	# Player dies: defeat, held.
	state.damage_player(OVERKILL)
	units.advance(0.0)
	_check("test_player_defeat_when_dead", units.get_current_clip(PLAYER) == UnitLayer.CLIP_DEFEAT and units.get_animator(PLAYER).current_clip() == UnitLayer.CLIP_DEFEAT)
	units.advance(LONG_SEC)
	var defeat: UnitAnimator = units.get_animator(PLAYER)
	_check("test_player_stays_defeated_on_the_last_frame", defeat.current_clip() == UnitLayer.CLIP_DEFEAT and defeat.is_finished() and defeat.frame_index() == defeat.frame_count() - 1)
	(b["main"] as Node).queue_free()
	await process_frame

extends SceneTree
## Story 047 Part B: the Misty Forest floor and backdrop in the real main scene (headless: the
## SubViewport renders nothing, but the layers' _draw runs, so the region plumbing, the redraw
## policy and the fallback path are checked). The battle is reached the way battle_canvas_test
## reaches it (main.tscn, GameFlow.enter_test_floor with the fast_run fixture, no chapter id).
## Run: godot --headless --path . -s res://tests/unit/battle/floor_layer_test.gd

const MAX_FRAMES: int = 600
const IDLE_FRAMES: int = 4
const THORN_SEC: float = 3.0
const DROP_WARN_SEC: float = 0.5
const DROP_HOLE_SEC: float = 1.5
const BOGUS_REGION: String = "nowhere_047"
const BURN_SEC: float = 1.0
const BURN_STEP_SEC: float = 0.1
const BURN_STEPS: int = 4

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	ArtAssets.clear_cache()
	var main: Node = load("res://src/main.tscn").instantiate()
	var flow := main.get_node("GameFlow") as GameFlow
	flow.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	var rc: RunController = flow.enter_test_floor(RunConfig.load_from_file("res://tests/fixtures/fast_run.json"))
	await process_frame
	await process_frame
	for _i: int in MAX_FRAMES:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	_check("test_battle_spawned", battle != null)
	if battle == null:
		_finish()
		return
	var combat := battle.get_node("CombatView") as CombatView
	await process_frame
	var canvas := battle.get_child(0) as BattleCanvas
	_check("test_first_child_is_the_BattleCanvas", canvas != null)
	if canvas == null:
		_finish()
		return
	await process_frame
	await process_frame
	await test_region_id_defaults_to_forest_without_a_chapter(canvas, combat)
	await test_region_id_is_forest_for_ch1(canvas, combat)
	test_draws_with_the_forest_textures_present(canvas)
	await test_no_redraw_while_nothing_changes(canvas)
	await test_boss_swing_redraws_only_the_dynamic_layer(canvas, combat)
	await test_burning_cell_redraws_the_dynamic_layer_until_it_burns_out(canvas, combat)
	await test_zone_apply_marks_the_floor_dirty(canvas, combat)
	await test_zone_expiry_marks_the_floor_dirty(canvas, combat)
	test_cut_hud_no_longer_draws_thorn_or_seal_cells(battle)
	await test_bogus_region_falls_back_without_error(canvas)
	_finish()


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(fails)


func _settle() -> void:
	for _i: int in IDLE_FRAMES:
		await process_frame


func test_region_id_defaults_to_forest_without_a_chapter(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange: the test floor sets no chapter id.
	var chapter: String = str(combat.match_params.get("chapter_id", ""))
	# Assert
	_check("test_test_floor_has_no_chapter_id_got_[%s]" % chapter, chapter.is_empty())
	_check("test_floor_region_id_defaults_to_forest_got_%s" % canvas.get_floor_layer().get_region_id(), canvas.get_floor_layer().get_region_id() == "forest")
	_check("test_backdrop_region_id_defaults_to_forest", canvas.get_backdrop_layer().get_region_id() == "forest")
	_check("test_canvas_region_id_defaults_to_forest", canvas.get_region_id() == "forest")
	_check("test_backdrop_is_not_in_fallback_for_forest", not canvas.get_backdrop_layer().is_fallback())
	await _settle()


func test_region_id_is_forest_for_ch1(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange
	combat.match_params["chapter_id"] = "ch1"
	# Act: rebind as BattleCanvas does.
	canvas.get_floor_layer().setup(combat)
	canvas.get_backdrop_layer().setup(combat)
	await _settle()
	# Assert
	_check("test_floor_region_id_for_ch1_is_forest", canvas.get_floor_layer().get_region_id() == "forest")
	_check("test_backdrop_region_id_for_ch1_is_forest", canvas.get_backdrop_layer().get_region_id() == "forest")
	combat.match_params.erase("chapter_id")


func test_draws_with_the_forest_textures_present(canvas: BattleCanvas) -> void:
	_check("test_forest_slab_nine_slice_texture_loaded", ArtAssets.region_texture("forest", "slab.nine_slice") != null)
	_check("test_forest_thorn_tile_loaded", ArtAssets.region_texture("forest", "thorn_tile") != null)
	_check("test_forest_backdrop_far_loaded", ArtAssets.region_texture("forest", "backdrop.far") != null)
	_check("test_floor_drew_at_least_once_got_%d" % canvas.get_floor_layer().get_redraw_count(), canvas.get_floor_layer().get_redraw_count() >= 1)
	_check("test_backdrop_drew_at_least_once_got_%d" % canvas.get_backdrop_layer().get_redraw_count(), canvas.get_backdrop_layer().get_redraw_count() >= 1)


func test_no_redraw_while_nothing_changes(canvas: BattleCanvas) -> void:
	# Arrange
	await _settle()
	var floor_before: int = canvas.get_floor_layer().get_redraw_count()
	var backdrop_before: int = canvas.get_backdrop_layer().get_redraw_count()
	# Act: idle frames, no zone, no resize.
	await _settle()
	# Assert (art bible 8.6: no per-frame redraw of the floor).
	_check("test_floor_redraw_count_unchanged_over_%d_idle_frames" % IDLE_FRAMES, canvas.get_floor_layer().get_redraw_count() == floor_before)
	_check("test_backdrop_redraw_count_unchanged_over_%d_idle_frames" % IDLE_FRAMES, canvas.get_backdrop_layer().get_redraw_count() == backdrop_before)


# Story 046 Part C: the telegraph lives in the FloorDynamicLayer; a boss swing redraws that child while its progress
# moves and once more when it ends, never the static floor (art bible 8.6).
func test_boss_swing_redraws_only_the_dynamic_layer(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange: time frozen so only the test moves the swing.
	var floor_layer: FloorLayer = canvas.get_floor_layer()
	var actor: CutActor = combat.get_boss().get_actor()
	combat.freeze_time = true
	actor.cancel()
	await _settle()
	var floor_before: int = floor_layer.get_redraw_count()
	var dyn_idle: int = floor_layer.get_dynamic_redraw_count()
	await _settle()
	_check("test_dynamic_layer_idle_without_swing", floor_layer.get_dynamic_redraw_count() == dyn_idle)
	# Act: a swing at three progress values, a frozen stretch, then the swing ends.
	actor.begin_swing([combat.get_state().player_cell] as Array[Vector2i], "kiem_khi", false)
	for k: float in [0.0, 0.5, 1.0]:
		actor.debug_set_progress(k)
		await process_frame
		await process_frame
	var dyn_running: int = floor_layer.get_dynamic_redraw_count()
	await _settle()
	var dyn_frozen: int = floor_layer.get_dynamic_redraw_count()
	actor.cancel()
	await _settle()
	var dyn_ended: int = floor_layer.get_dynamic_redraw_count()
	await _settle()
	# Assert
	_check("test_dynamic_layer_redraws_as_progress_moves_got_%d" % (dyn_running - dyn_idle), dyn_running - dyn_idle >= 3)
	_check("test_dynamic_layer_still_while_progress_frozen", dyn_frozen == dyn_running)
	_check("test_dynamic_layer_redraws_once_to_clear_got_%d" % (dyn_ended - dyn_frozen), dyn_ended == dyn_frozen + 1)
	_check("test_dynamic_layer_idle_after_the_swing", floor_layer.get_dynamic_redraw_count() == dyn_ended)
	_check("test_static_floor_not_redrawn_by_the_swing", floor_layer.get_redraw_count() == floor_before)
	_check("test_telegraph_state_empty_after_the_swing", floor_layer.telegraph_state().is_empty())
	combat.freeze_time = false


# Story 046 Part C follow-up: burning cells live in the FloorDynamicLayer (BurnPainter); it redraws while the time
# bar shrinks, once more when the last burn ends, then stays idle; the static floor is untouched.
func test_burning_cell_redraws_the_dynamic_layer_until_it_burns_out(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange: time frozen so only the test ticks the burn; a cell nobody stands on (no damage, no death).
	var floor_layer: FloorLayer = canvas.get_floor_layer()
	var status: StatusEffects = combat.get_status()
	var state: CombatState = combat.get_state()
	combat.freeze_time = true
	combat.get_boss().get_actor().cancel()
	var cell: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in combat.get_grid().enemy_cells():
		if c != state.enemy_cell and c != state.player_cell:
			cell = c
			break
	_check("test_burn_found_an_empty_cell", cell != Vector2i(-1, -1))
	await _settle()
	var floor_before: int = floor_layer.get_redraw_count()
	var dyn_idle: int = floor_layer.get_dynamic_redraw_count()
	# Act: ignite, then shrink the burn a step per frame.
	status.ignite([cell] as Array[Vector2i], BURN_SEC, BURN_SEC, 0.0)
	await process_frame
	await process_frame
	_check("test_burn_state_has_the_cell", floor_layer.get_dynamic_layer().burn_state().size() == 1)
	for _i: int in BURN_STEPS:
		status.tick(BURN_STEP_SEC, state)
		await process_frame
		await process_frame
	var dyn_burning: int = floor_layer.get_dynamic_redraw_count()
	await _settle()
	var dyn_frozen: int = floor_layer.get_dynamic_redraw_count()
	status.tick(BURN_SEC, state)
	await _settle()
	var dyn_out: int = floor_layer.get_dynamic_redraw_count()
	await _settle()
	# Assert
	_check("test_burn_redraws_while_it_burns_got_%d" % (dyn_burning - dyn_idle), dyn_burning - dyn_idle >= BURN_STEPS + 1)
	_check("test_burn_still_while_time_frozen", dyn_frozen == dyn_burning)
	_check("test_burn_redraws_once_when_it_burns_out_got_%d" % (dyn_out - dyn_frozen), dyn_out == dyn_frozen + 1)
	_check("test_burn_idle_after_burning_out", floor_layer.get_dynamic_redraw_count() == dyn_out)
	_check("test_burn_state_empty_after_burning_out", floor_layer.get_dynamic_layer().burn_state().is_empty())
	_check("test_static_floor_not_redrawn_by_the_burn", floor_layer.get_redraw_count() == floor_before)
	combat.freeze_time = false


func test_zone_apply_marks_the_floor_dirty(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange
	var status: StatusEffects = combat.get_status()
	var grid: BoardGrid = combat.get_grid()
	var floor_layer: FloorLayer = canvas.get_floor_layer()
	var before: int = floor_layer.get_redraw_count()
	var thorn_cell: Vector2i = grid.player_cells()[0]
	var drop_cell: Vector2i = grid.enemy_cells()[0]
	# Act
	status.apply_thorns(CombatState.Side.PLAYER, [thorn_cell] as Array[Vector2i], THORN_SEC, 1.0, 0)
	await _settle()
	var after_thorns: int = floor_layer.get_redraw_count()
	status.apply_drop(CombatState.Side.ENEMY, [drop_cell] as Array[Vector2i], DROP_WARN_SEC, DROP_HOLE_SEC)
	await _settle()
	var after_drop: int = floor_layer.get_redraw_count()
	# Assert: one redraw per zone event, not more.
	_check("test_thorn_apply_redraws_the_floor_once_got_%d" % (after_thorns - before), after_thorns == before + 1)
	_check("test_drop_crack_redraws_the_floor_once_got_%d" % (after_drop - after_thorns), after_drop == after_thorns + 1)
	_check("test_thorn_cell_is_registered", status.thorn_cells(CombatState.Side.PLAYER).has(thorn_cell))
	_check("test_drop_cell_is_cracking", status.is_cracking(CombatState.Side.ENEMY, drop_cell))


func test_zone_expiry_marks_the_floor_dirty(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange: both zones from the previous test are live.
	var status: StatusEffects = combat.get_status()
	var floor_layer: FloorLayer = canvas.get_floor_layer()
	# The crack falls first (its own redraw), so the next tick ends both the thorns and the hole.
	status.tick(DROP_WARN_SEC + 0.1, combat.get_state())
	await _settle()
	_check("test_drop_cell_fell_into_a_hole", status.hole_cells(CombatState.Side.ENEMY).size() == 1)
	var before: int = floor_layer.get_redraw_count()
	# Act: tick past both durations (thorn expiry + hole return in one tick: one redraw).
	status.tick(maxf(THORN_SEC, DROP_HOLE_SEC) + 1.0, combat.get_state())
	await _settle()
	# Assert
	_check("test_zones_expired", status.thorn_cells(CombatState.Side.PLAYER).is_empty() and status.hole_cells(CombatState.Side.ENEMY).is_empty()
		and status.crack_cells(CombatState.Side.ENEMY).is_empty())
	_check("test_zone_expiry_redraws_the_floor_got_%d" % (floor_layer.get_redraw_count() - before), floor_layer.get_redraw_count() == before + 1)


func test_cut_hud_no_longer_draws_thorn_or_seal_cells(battle: Node) -> void:
	var huds: Array[Node] = battle.find_children("*", "CutHudView", true, false)
	_check("test_battle_has_a_CutHudView", not huds.is_empty())
	if huds.is_empty():
		return
	var hud: Node = huds[0]
	_check("test_cut_hud_has_no__draw_thorn_cell", not hud.has_method("_draw_thorn_cell"))
	_check("test_cut_hud_has_no__draw_seal_cell", not hud.has_method("_draw_seal_cell"))
	_check("test_cut_hud_has_no__draw_burning", not hud.has_method("_draw_burning"))
	_check("test_cut_hud_keeps__draw_zones_for_the_timer_bars", hud.has_method("_draw_zones") and hud.has_method("_draw_zone_bar"))


func test_bogus_region_falls_back_without_error(canvas: BattleCanvas) -> void:
	# Arrange
	ArtAssets.clear_cache()
	var floor_before: int = canvas.get_floor_layer().get_redraw_count()
	var backdrop_before: int = canvas.get_backdrop_layer().get_redraw_count()
	# Act
	canvas.set_region_id(BOGUS_REGION)
	await _settle()
	# Assert: the layers still draw (flat stone, flat bands); a SCRIPT ERROR in the log fails the run.
	_check("test_canvas_region_id_is_the_bogus_region", canvas.get_region_id() == BOGUS_REGION)
	_check("test_floor_redrew_with_the_bogus_region", canvas.get_floor_layer().get_redraw_count() == floor_before + 1)
	_check("test_backdrop_redrew_with_the_bogus_region", canvas.get_backdrop_layer().get_redraw_count() == backdrop_before + 1)
	_check("test_backdrop_is_in_fallback_for_the_bogus_region", canvas.get_backdrop_layer().is_fallback())
	_check("test_bogus_region_dictionary_is_empty", ArtAssets.region(BOGUS_REGION).is_empty())
	# Restore
	canvas.set_region_id("forest")
	await _settle()
	_check("test_forest_restored_and_not_fallback", not canvas.get_backdrop_layer().is_fallback())

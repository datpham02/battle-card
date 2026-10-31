extends SceneTree
## Story 047 Part B: the Misty Forest floor and backdrop in the real main scene (headless: the
## SubViewport renders nothing, but the layers' _draw runs, so the region plumbing, the redraw
## policy and the fallback path are checked). The battle is reached the way battle_canvas_test
## reaches it (main.tscn, GameFlow.enter_test_floor with the fast_run fixture, no chapter id).
## Run: godot --headless --path . -s res://tests/unit/battle/floor_layer_test.gd

const MAX_FRAMES: int = 600
const IDLE_FRAMES: int = 4
const THORN_SEC: float = 3.0
const SEAL_SEC: float = 2.0
const BOGUS_REGION: String = "nowhere_047"

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


func test_zone_apply_marks_the_floor_dirty(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange
	var status: StatusEffects = combat.get_status()
	var grid: BoardGrid = combat.get_grid()
	var floor_layer: FloorLayer = canvas.get_floor_layer()
	var before: int = floor_layer.get_redraw_count()
	var thorn_cell: Vector2i = grid.player_cells()[0]
	var seal_cell: Vector2i = grid.enemy_cells()[0]
	# Act
	status.apply_thorns(CombatState.Side.PLAYER, [thorn_cell] as Array[Vector2i], THORN_SEC, 1.0, 0)
	await _settle()
	var after_thorns: int = floor_layer.get_redraw_count()
	status.apply_seal(CombatState.Side.ENEMY, [seal_cell] as Array[Vector2i], SEAL_SEC)
	await _settle()
	var after_seal: int = floor_layer.get_redraw_count()
	# Assert: one redraw per zone event, not more.
	_check("test_thorn_apply_redraws_the_floor_once_got_%d" % (after_thorns - before), after_thorns == before + 1)
	_check("test_seal_apply_redraws_the_floor_once_got_%d" % (after_seal - after_thorns), after_seal == after_thorns + 1)
	_check("test_thorn_cell_is_registered", status.thorn_cells(CombatState.Side.PLAYER).has(thorn_cell))
	_check("test_seal_cell_is_registered", status.is_sealed(CombatState.Side.ENEMY, seal_cell))


func test_zone_expiry_marks_the_floor_dirty(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange: both zones from the previous test are live.
	var status: StatusEffects = combat.get_status()
	var floor_layer: FloorLayer = canvas.get_floor_layer()
	var before: int = floor_layer.get_redraw_count()
	# Act: tick past both durations (two zone_expired signals in one tick: one redraw).
	status.tick(maxf(THORN_SEC, SEAL_SEC) + 1.0, combat.get_state())
	await _settle()
	# Assert
	_check("test_zones_expired", status.thorn_cells(CombatState.Side.PLAYER).is_empty() and status.sealed_cells(CombatState.Side.ENEMY).is_empty())
	_check("test_zone_expiry_redraws_the_floor_got_%d" % (floor_layer.get_redraw_count() - before), floor_layer.get_redraw_count() == before + 1)


func test_cut_hud_no_longer_draws_thorn_or_seal_cells(battle: Node) -> void:
	var huds: Array[Node] = battle.find_children("*", "CutHudView", true, false)
	_check("test_battle_has_a_CutHudView", not huds.is_empty())
	if huds.is_empty():
		return
	var hud: Node = huds[0]
	_check("test_cut_hud_has_no__draw_thorn_cell", not hud.has_method("_draw_thorn_cell"))
	_check("test_cut_hud_has_no__draw_seal_cell", not hud.has_method("_draw_seal_cell"))
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

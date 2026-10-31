extends SceneTree
## Story 047 Part A: the battle art canvas in the real main scene (headless; the SubViewport renders
## nothing headless, only the tree, the flags and the geometry are checked). The battle is reached the
## way the click suites reach it (main.tscn, GameFlow.enter_test_floor with the fast_run fixture).
## Run: godot --headless --path . -s res://tests/unit/battle/battle_canvas_test.gd

const MAX_FRAMES: int = 600

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	# Headless, the root viewport is square (1280x1280); ask for the reference size (honoured or not, every
	# geometry check below is relative to the size the CombatView actually sees).
	root.size = Vector2i(1280, 720)
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
	test_canvas_is_first_child_before_combat_view(battle, combat)
	var canvas := battle.get_child(0) as BattleCanvas
	if canvas == null:
		_finish()
		return
	test_sub_viewport_flags(canvas)
	test_four_layers_in_order(canvas)
	test_bound_to_combat_view(canvas, combat)
	test_cell_art_rect_matches_to_art_rect(canvas, combat)
	test_unit_feet_inside_the_cell(canvas, combat)
	test_painters_add_remove(canvas)
	test_combat_view_no_longer_draws_the_board(combat)
	_finish()


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(fails)


func test_canvas_is_first_child_before_combat_view(battle: Node, combat: CombatView) -> void:
	var first: Node = battle.get_child(0)
	_check("test_first_child_of_battle_is_a_BattleCanvas_named_BattleCanvas", first is BattleCanvas and first.name == "BattleCanvas")
	_check("test_combat_view_comes_after_the_canvas", combat != null and combat.get_index() > first.get_index())


func test_sub_viewport_flags(canvas: BattleCanvas) -> void:
	var vp: SubViewport = canvas.get_art_viewport()
	_check("test_canvas_owns_a_SubViewport_child", vp != null and vp.get_parent() == canvas)
	if vp == null:
		return
	_check("test_sub_viewport_size_800x360_got_%s" % vp.size, vp.size == Vector2i(800, 360))
	_check("test_sub_viewport_nearest_filter", vp.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	_check("test_sub_viewport_msaa_2d_disabled", vp.msaa_2d == Viewport.MSAA_DISABLED)
	_check("test_sub_viewport_no_hdr_2d", vp.use_hdr_2d == false)
	_check("test_sub_viewport_snap_2d_transforms_to_pixel", vp.snap_2d_transforms_to_pixel)
	_check("test_sub_viewport_snap_2d_vertices_to_pixel", vp.snap_2d_vertices_to_pixel)
	_check("test_sub_viewport_opaque_background", vp.transparent_bg == false)
	_check("test_sub_viewport_update_always", vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	_check("test_canvas_node_nearest_texture_filter", canvas.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	# Snap flags belong to this SubViewport only, never to the project / root viewport.
	_check("test_root_viewport_keeps_default_snap_off", not root.snap_2d_transforms_to_pixel and not root.snap_2d_vertices_to_pixel)


func test_four_layers_in_order(canvas: BattleCanvas) -> void:
	var vp: SubViewport = canvas.get_art_viewport()
	if vp == null:
		return
	_check("test_sub_viewport_has_four_children_got_%d" % vp.get_child_count(), vp.get_child_count() == 4)
	var names: Array[String] = []
	for child: Node in vp.get_children():
		names.append(child.name)
	var want: Array[String] = ["BackdropLayer", "FloorLayer", "UnitLayer", "OverlayLayer"]
	_check("test_layer_order_backdrop_floor_unit_overlay_got_%s" % [names], names == want)
	_check("test_layer_classes", vp.get_child(0) is BackdropLayer and vp.get_child(1) is FloorLayer and vp.get_child(2) is UnitLayer and vp.get_child(3) is OverlayLayer)
	_check("test_layer_getters_return_the_children", canvas.get_backdrop_layer() == vp.get_child(0) and canvas.get_floor_layer() == vp.get_child(1) and canvas.get_unit_layer() == vp.get_child(2) and canvas.get_overlay_layer() == vp.get_child(3))


func test_bound_to_combat_view(canvas: BattleCanvas, combat: CombatView) -> void:
	_check("test_canvas_bound_to_the_sibling_combat_view", canvas.get_combat_view() == combat)
	_check("test_combat_view_get_battle_canvas_returns_the_canvas", combat.get_battle_canvas() == canvas)


func test_cell_art_rect_matches_to_art_rect(canvas: BattleCanvas, combat: CombatView) -> void:
	var floor_layer: FloorLayer = canvas.get_floor_layer()
	var grid: BoardGrid = combat.get_grid()
	var vp: Vector2 = combat.get_viewport_rect().size
	print("  screen viewport seen by CombatView: %s (art_scale %d)" % [vp, ScreenLayout.art_scale(vp)])
	var ok_all: bool = true
	var count: int = 0
	for cell: Vector2i in grid.player_cells() + grid.enemy_cells():
		count += 1
		var want: Rect2i = ScreenLayout.to_art_rect(vp, ScreenLayout.cell_rect(grid, vp, cell))
		var got: Rect2i = floor_layer.cell_art_rect(cell)
		if got != want:
			ok_all = false
			print("  cell %s: got %s want %s" % [cell, got, want])
	_check("test_cell_art_rect_equals_to_art_rect_of_cell_rect_for_all_%d_cells" % count, ok_all and count > 0)
	var first: Rect2i = floor_layer.cell_art_rect(grid.player_cells()[0])
	var band_top: int = ScreenLayout.to_art(vp, ScreenLayout.board_area_rect(vp).position).y
	_check("test_cell_art_rect_top_at_or_below_the_20_percent_band_%d_art_px_got_%d" % [band_top, first.position.y], first.position.y >= band_top)
	if vp == Vector2(1280, 720):
		_check("test_cell_art_rect_inside_the_800x360_canvas_got_%s" % first, Rect2i(0, 0, 800, 360).encloses(first))
		_check("test_band_top_is_72_art_px_at_720p", band_top == 72)


func test_unit_feet_inside_the_cell(canvas: BattleCanvas, combat: CombatView) -> void:
	var units: UnitLayer = canvas.get_unit_layer()
	var floor_layer: FloorLayer = canvas.get_floor_layer()
	var state: CombatState = combat.get_state()
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		var cell: Vector2i = state.player_cell if side == CombatState.Side.PLAYER else state.enemy_cell
		var rect: Rect2i = floor_layer.cell_art_rect(cell)
		var feet: Vector2i = units.unit_feet_art(side)
		_check("test_unit_feet_side_%d_inside_its_cell_got_%s_in_%s" % [side, feet, rect], rect.has_point(feet))
		_check("test_unit_feet_side_%d_three_art_px_above_the_front_edge" % side, feet.y == rect.end.y - UnitLayer.FEET_INSET_ART)
		@warning_ignore("integer_division")
		var centre_x: int = rect.position.x + rect.size.x / 2
		_check("test_unit_feet_side_%d_at_the_cell_centre_x" % side, feet.x == centre_x)
		# The rings in CombatView sit where they used to: the cell centre (within one art px of rounding).
		var vp: Vector2 = combat.get_viewport_rect().size
		var centre: Vector2 = ScreenLayout.cell_center(combat.get_grid(), vp, cell)
		var via_feet: Vector2 = ScreenLayout.from_art(vp, Vector2(feet)) - Vector2(0.0, ScreenLayout.cell_size(combat.get_grid(), vp).y * 0.5 - UnitLayer.FEET_INSET_ART * ScreenLayout.art_scale(vp))
		_check("test_ring_centre_side_%d_within_one_art_px_of_the_cell_centre" % side, centre.distance_to(via_feet) <= float(ScreenLayout.art_scale(vp)) + 0.01)


func test_painters_add_remove(canvas: BattleCanvas) -> void:
	var floor_layer: FloorLayer = canvas.get_floor_layer()
	var fn: Callable = func(_c: Node2D, _f: FloorLayer) -> void: pass
	floor_layer.add_painter(fn)
	floor_layer.add_painter(fn)
	_check("test_add_painter_twice_registers_once", floor_layer.get_painters().size() == 1)
	floor_layer.remove_painter(fn)
	_check("test_remove_painter_empties_the_list", floor_layer.get_painters().is_empty())


func test_combat_view_no_longer_draws_the_board(combat: CombatView) -> void:
	for fn: String in ["_draw_board", "_draw_cell", "_draw_enemy", "_draw_player_marker"]:
		_check("test_combat_view_has_no_%s" % fn, not combat.has_method(fn))
	_check("test_combat_view_keeps_hud_and_rings", combat.has_method("_draw_hud") and combat.has_method("_draw_cooldown_ring") and combat.has_method("_draw_boss_ring"))

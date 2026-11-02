extends SceneTree
## PROTOTYPE floor-perspective (2026-11-02): the flag's wiring in the real battle (headless; the SubViewports render
## nothing, the tree, the mapping and the follower geometry are checked). The battle is reached the way
## battle_canvas_test reaches it. Flag off: the canvas is exactly the Story 047 tree (no floor viewport, four layers
## in the art viewport). Flag on (CombatView.floor_perspective_override = 0.82, apply_floor_perspective): the floor
## moves into its own transparent viewport, the warp sprite takes its slot, cell_at_warped(warp(cell_center)) == cell
## for every cell on square / rect / boss_hall at 1280x720 and the unit feet land inside their warped cell. Off again:
## the tree is restored.
## Run: godot --headless --path . -s res://tests/unit/battle/floor_perspective_wiring_test.gd

const MAX_FRAMES: int = 600
const RATIO: float = 0.82
const SHAPES: Array[String] = ["square", "rect", "boss_hall"]
const FLAT_LAYERS: Array[String] = ["BackdropLayer", "FloorLayer", "UnitLayer", "OverlayLayer"]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
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
	var canvas := battle.get_child(0) as BattleCanvas
	if canvas == null or combat == null:
		_check("test_canvas_and_combat_present", false)
		_finish()
		return
	test_flag_off_is_the_story_047_tree(canvas, combat)
	test_flag_on_rewires_the_floor(canvas, combat)
	await process_frame
	test_round_trip_on_every_shape()
	test_unit_feet_inside_the_warped_cell(canvas, combat)
	test_flag_off_again_restores_the_tree(canvas, combat)
	_finish()


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(fails)


func _layer_names(vp: SubViewport) -> Array[String]:
	var names: Array[String] = []
	for child: Node in vp.get_children():
		names.append(child.name)
	return names


func test_flag_off_is_the_story_047_tree(canvas: BattleCanvas, combat: CombatView) -> void:
	_check("test_default_back_ratio_is_off_got_%s" % combat.floor_back_ratio(), not FloorPerspective.is_on(combat.floor_back_ratio()))
	_check("test_default_no_floor_viewport", canvas.get_floor_viewport() == null)
	_check("test_default_no_perspective", canvas.get_floor_perspective() == null and FloorPerspective.of(combat) == null)
	_check("test_default_four_layers_in_the_art_viewport_got_%s" % [_layer_names(canvas.get_art_viewport())],
		_layer_names(canvas.get_art_viewport()) == FLAT_LAYERS)


func test_flag_on_rewires_the_floor(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange / Act: the flag the way DemoArgs sets it, then the canvas re-applies it.
	combat.floor_perspective_override = RATIO
	canvas.apply_floor_perspective()
	# Assert
	var fvp: SubViewport = canvas.get_floor_viewport()
	_check("test_on_floor_viewport_exists", fvp != null)
	if fvp == null:
		return
	_check("test_on_floor_viewport_800x360_transparent_nearest", fvp.size == Vector2i(800, 360) and fvp.transparent_bg
		and fvp.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	_check("test_on_floor_viewport_is_a_child_of_the_art_viewport_so_it_renders_first", fvp.get_parent() == canvas.get_art_viewport())
	_check("test_on_floor_layer_moved_into_the_floor_viewport", canvas.get_floor_layer().get_parent() == fvp)
	_check("test_on_floor_layer_keeps_its_dynamic_child", canvas.get_floor_layer().get_dynamic_layer().get_parent() == canvas.get_floor_layer())
	var names: Array[String] = _layer_names(canvas.get_art_viewport())
	_check("test_on_warp_sprite_sits_between_backdrop_and_units_got_%s" % [names],
		names.size() >= 4 and names[0] == "BackdropLayer" and names[1] == "FloorWarp" and names[2] == "UnitLayer" and names[3] == "OverlayLayer")
	var warp := canvas.get_art_viewport().get_node_or_null("FloorWarp") as Sprite2D
	_check("test_on_warp_sprite_draws_the_floor_viewport_texture_through_the_shader", warp != null and warp.texture is ViewportTexture
		and warp.material is ShaderMaterial and (warp.material as ShaderMaterial).shader != null
		and (warp.material as ShaderMaterial).shader.resource_path == BattleCanvas.PERSPECTIVE_SHADER)
	if warp != null and warp.material is ShaderMaterial:
		var inv: Variant = (warp.material as ShaderMaterial).get_shader_parameter("inv_h")
		_check("test_on_shader_gets_the_inverse_homography_basis", inv is Basis and not (inv as Basis).is_equal_approx(Basis.IDENTITY))
	var persp: FloorPerspective = canvas.get_floor_perspective()
	_check("test_on_perspective_ratio_%s" % RATIO, persp != null and is_equal_approx(persp.back_ratio, RATIO))
	_check("test_on_floor_layer_still_draws_flat_cell_rects", canvas.get_floor_layer().cell_art_rect(combat.get_grid().player_cells()[0])
		== ScreenLayout.to_art_rect(combat.get_viewport_rect().size, ScreenLayout.cell_rect(combat.get_grid(), combat.get_viewport_rect().size, combat.get_grid().player_cells()[0])))


func test_round_trip_on_every_shape() -> void:
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	var vp: Vector2 = Vector2(1280, 720)
	for id: String in SHAPES:
		var spec: Dictionary = library.get_shape(id)
		_check("test_shape_%s_exists" % id, not spec.is_empty())
		if spec.is_empty():
			continue
		var grid: BoardGrid = ArenaValidator.build_grid(spec)
		var persp: FloorPerspective = FloorPerspective.make(grid, vp, RATIO)
		var ok: bool = persp != null
		var count: int = 0
		for cell: Vector2i in grid.player_cells() + grid.enemy_cells():
			count += 1
			var centre: Vector2 = ScreenLayout.cell_center(grid, vp, cell)
			if persp.cell_at_warped_screen(grid, persp.warp_screen(centre)) != cell:
				ok = false
				print("  %s cell %s round-trips to %s" % [id, cell, persp.cell_at_warped_screen(grid, persp.warp_screen(centre))])
		_check("test_%s_1280x720_cell_at_warped_of_warp_cell_center_is_the_cell_for_%d_cells" % [id, count], ok and count > 0)


func test_unit_feet_inside_the_warped_cell(canvas: BattleCanvas, combat: CombatView) -> void:
	var persp: FloorPerspective = canvas.get_floor_perspective()
	if persp == null:
		return
	var grid: BoardGrid = combat.get_grid()
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		var feet: Vector2i = canvas.get_unit_layer().unit_feet_art(side)
		var cell: Vector2i = persp.cell_at_warped(grid, Vector2(feet) + Vector2(0.5, 0.5))
		var state: CombatState = combat.get_state()
		var want: Vector2i = state.player_cell if side == CombatState.Side.PLAYER else state.enemy_cell
		var inside: bool = cell == want or (side == CombatState.Side.ENEMY and state.enemy_footprint_cells().has(cell))
		_check("test_side_%d_feet_%s_sit_on_its_warped_cell_%s" % [side, feet, want], inside, "got cell %s" % cell)
		var flat_feet: Vector2i = canvas.get_unit_layer().feet_art_of_cell(want)
		_check("test_side_%d_feet_differ_from_the_flat_feet_only_in_the_warp" % side, flat_feet == feet or side == CombatState.Side.ENEMY)


func test_flag_off_again_restores_the_tree(canvas: BattleCanvas, combat: CombatView) -> void:
	combat.floor_perspective_override = 0.0
	canvas.apply_floor_perspective()
	_check("test_off_again_no_floor_viewport", canvas.get_floor_viewport() == null)
	_check("test_off_again_floor_layer_back_in_the_art_viewport_got_%s" % [_layer_names(canvas.get_art_viewport())],
		_layer_names(canvas.get_art_viewport()) == FLAT_LAYERS and canvas.get_floor_layer().get_parent() == canvas.get_art_viewport())
	_check("test_off_again_no_perspective", canvas.get_floor_perspective() == null)

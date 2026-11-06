extends SceneTree
## Floor perspective (ADR-0002): the wiring in the real battle (headless; the SubViewports render nothing, the tree,
## the mapping and the follower geometry are checked). The battle is reached the way battle_canvas_test reaches it.
## Default (combat.json floor.perspective.back_ratio = 0.82): the floor sits in its own transparent viewport drawn
## through the warp sprite. Forced flat (CombatView.floor_perspective_override = 0, i.e. `--floor-perspective=0`): the
## canvas is exactly the Story 047 tree. On again (0.82): the floor moves back into its own viewport, the warp sprite
## takes its slot, cell_at_warped(warp(cell_center)) == cell for every cell on square / rect / boss_hall at 1280x720,
## the unit feet land inside their warped cell, and every consumer agrees on BoardGeometry's cell polygons (boss
## placeholder = the warped footprint inset, drop tiles / travel rects = warped quads, labels on warped anchors). Off
## again: the tree is restored.
## Run: godot --headless --path . -s res://tests/unit/battle/floor_perspective_wiring_test.gd

const MAX_FRAMES: int = 600
const RATIO: float = 0.82
const SHAPES: Array[String] = ["square", "rect", "boss_hall"]
## 2026-11-05 (voxel pickups, forest-integration-pickup-plan step 1): PickupLayer sits between the floor and the units.
## 2026-11-06 (step 2): SupportLayer (stone foundation) sits between the backdrop and the floor.
const FLAT_LAYERS: Array[String] = ["BackdropLayer", "SupportLayer", "FloorLayer", "PickupLayer", "UnitLayer", "OverlayLayer"]
## Tolerance (px) of polygon agreement.
const EPS_PX: float = 0.01

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
	test_default_is_the_perspective_floor(canvas, combat)
	test_flag_off_is_the_story_047_tree(canvas, combat)
	test_flag_on_rewires_the_floor(canvas, combat)
	await process_frame
	test_round_trip_on_every_shape()
	test_unit_feet_inside_the_warped_cell(canvas, combat)
	test_consumers_agree_on_the_board_geometry(battle, canvas, combat)
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


func test_default_is_the_perspective_floor(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange: nothing (combat.json's default). Assert: 0.82, the floor viewport and the warp sprite are there.
	_check("test_default_back_ratio_is_%s_got_%s" % [RATIO, combat.floor_back_ratio()], is_equal_approx(combat.floor_back_ratio(), RATIO))
	_check("test_default_floor_viewport_exists", canvas.get_floor_viewport() != null)
	_check("test_default_perspective_on", canvas.get_floor_perspective() != null and combat.board_geometry().is_warped())


func test_flag_off_is_the_story_047_tree(canvas: BattleCanvas, combat: CombatView) -> void:
	# Arrange / Act: forced flat the way `--floor-perspective=0` does it.
	combat.floor_perspective_override = 0.0
	canvas.apply_floor_perspective()
	# Assert
	_check("test_forced_flat_back_ratio_is_off_got_%s" % combat.floor_back_ratio(), not FloorPerspective.is_on(combat.floor_back_ratio()))
	_check("test_forced_flat_no_floor_viewport", canvas.get_floor_viewport() == null)
	_check("test_forced_flat_no_perspective", canvas.get_floor_perspective() == null and FloorPerspective.of(combat) == null)
	_check("test_forced_flat_geometry_is_flat", not combat.board_geometry().is_warped())
	_check("test_forced_flat_four_layers_in_the_art_viewport_got_%s" % [_layer_names(canvas.get_art_viewport())],
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
		names.size() >= 6 and names[0] == "BackdropLayer" and names[1] == "SupportLayer" and names[2] == "FloorWarp" and names[3] == "PickupWarp" and names[4] == "UnitLayer" and names[5] == "OverlayLayer")
	# 2026-11-06: the pickups warp through the same shader and homography, with white (no) half tints.
	var pwarp := canvas.get_art_viewport().get_node_or_null("PickupWarp") as Sprite2D
	var pmat := pwarp.material as ShaderMaterial if pwarp != null else null
	var fmat := (canvas.get_art_viewport().get_node_or_null("FloorWarp") as Sprite2D).material as ShaderMaterial
	_check("test_on_pickup_warp_same_shader_and_homography_no_tints", pmat != null and pmat.shader == fmat.shader
		and pmat.get_shader_parameter("inv_h") == fmat.get_shader_parameter("inv_h")
		and pmat.get_shader_parameter("tint_player") == Color.WHITE and pmat.get_shader_parameter("tint_enemy") == Color.WHITE)
	# 2026-11-06 (user: the lip blends with the floor and the platform): the halves are tinted only above the front
	# faces (tint_max_v = the lowest deck row), so the lip stays neutral stone like the support wall.
	var tmv: float = float(fmat.get_shader_parameter("tint_max_v"))
	_check("test_on_tint_stops_at_the_front_faces", tmv > 0.3 and tmv < 1.0 and is_equal_approx(tmv, canvas.face_top_v()), "v=%.3f" % tmv)
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


# Every consumer of board space draws / anchors on BoardGeometry's polygons (ADR-0002).
func test_consumers_agree_on_the_board_geometry(battle: Node, canvas: BattleCanvas, combat: CombatView) -> void:
	var geo: BoardGeometry = combat.board_geometry()
	_check("test_geo_is_warped", geo != null and geo.is_warped())
	if geo == null or not geo.is_warped():
		return
	var grid: BoardGrid = combat.get_grid()
	var persp: FloorPerspective = canvas.get_floor_perspective()
	# The HUD / touch polygon is the floor slab's own warped polygon.
	var same: bool = true
	for cell: Vector2i in grid.player_cells() + grid.enemy_cells():
		var a: PackedVector2Array = geo.cell_polygon(cell)
		var b: PackedVector2Array = persp.warped_cell_polygon_screen(grid, cell)
		for i: int in 4:
			same = same and a[i].distance_to(b[i]) < EPS_PX
		same = same and geo.cell_at(geo.cell_center(cell)) == cell
	_check("test_geo_cell_polygon_is_the_slab_polygon_and_cell_at_inverts_it_on_every_cell", same)
	# Boss placeholder: the warped footprint polygon, inset.
	var units: UnitLayer = canvas.get_unit_layer()
	var footprint: Array[Vector2i] = combat.get_state().enemy_footprint_cells()
	var body: PackedVector2Array = units.enemy_placeholder_polygon()
	var want: PackedVector2Array = geo.art_quad(UnitLayer.enemy_body_rect(geo.cells_art_rect(footprint)))
	var body_ok: bool = body.size() == 4
	for i: int in mini(body.size(), 4):
		body_ok = body_ok and body[i].distance_to(want[i]) < EPS_PX
	_check("test_boss_placeholder_is_the_warped_footprint_body_quad", body_ok)
	var outer: PackedVector2Array = geo.art_quad(Rect2(geo.cells_art_rect(footprint)))
	var inside: bool = body.size() == 4
	for p: Vector2 in body:
		inside = inside and Geometry2D.is_point_in_polygon(p, outer)
	_check("test_boss_placeholder_lies_inside_the_warped_footprint", inside)
	_check("test_boss_placeholder_is_a_trapezoid_not_a_rect", body.size() == 4 and absf((body[1].x - body[0].x) - (body[2].x - body[3].x)) > 0.5)
	# Ground shadow: narrower than the flat cell (the floor shrinks towards the back), never wider.
	var cell_size: Vector2i = geo.cell_art_rect(combat.get_state().player_cell).size
	var shadow: Vector2i = units.shadow_size(cell_size, units.unit_feet_art(CombatState.Side.PLAYER))
	_check("test_shadow_scaled_by_the_floor_at_the_feet_got_%s_of_%s" % [shadow, cell_size], shadow.x <= cell_size.x and shadow.x > 0)
	# Drop tiles: the warped quad of the inset model cell, inside the cell polygon.
	var drops := battle.get_node_or_null("FieldDropsView") as FieldDropsView
	_check("test_drops_view_present", drops != null)
	if drops != null:
		var cell: Vector2i = combat.get_state().player_cell
		var tile: PackedVector2Array = drops.tile_polygon(cell)
		var poly: PackedVector2Array = geo.cell_polygon(cell)
		var tile_ok: bool = tile.size() == 4
		for p: Vector2 in tile:
			tile_ok = tile_ok and Geometry2D.is_point_in_polygon(p, poly)
		_check("test_drop_tile_is_a_warped_quad_inside_its_cell_polygon", tile_ok)
		_check("test_drop_tile_top_edge_narrower_than_bottom", tile.size() == 4 and (tile[1].x - tile[0].x) < (tile[2].x - tile[3].x))
	# Travel / flash rects: drawn as the warped quad of the flat rect, so a full-cell flash is the slab polygon.
	var overlay: OverlayLayer = canvas.get_overlay_layer()
	# Regression (2026-11-02): the overlay found its floor by sibling name, which fails once the floor sits in the
	# FloorViewport, so every overlay VFX / travel square silently vanished with the perspective on.
	_check("test_overlay_bound_to_the_floor_layer_inside_the_floor_viewport", overlay._floor == canvas.get_floor_layer())
	var c0: Vector2i = grid.enemy_cells()[0]
	var flash: PackedVector2Array = overlay.travel_polygon(geo.cell_art_rect(c0))
	var slab: PackedVector2Array = geo.cell_art_polygon(c0)
	var flash_ok: bool = flash.size() == 4
	for i: int in mini(flash.size(), 4):
		flash_ok = flash_ok and flash[i].distance_to(slab[i]) < EPS_PX
	_check("test_overlay_full_cell_rect_is_the_slab_polygon", flash_ok)
	# Labels: anchored on the warped cells (inside the drawn enemy half, touching the drawn box of the cells).
	var hud := battle.get_node_or_null("CutHudView") as CutHudView
	_check("test_hud_present", hud != null)
	if hud != null:
		var cells: Array[Vector2i] = [c0]
		var box: Rect2 = geo.cells_bounds(cells)
		var size := Vector2(60.0, 20.0)
		var label: Rect2 = hud._place_label(combat.get_viewport_rect().size, cells, size, [] as Array[Rect2])
		var half: Rect2 = geo.half_bounds(true)
		_check("test_label_inside_the_drawn_enemy_half_got_%s_in_%s" % [label, half], half.grow(1.0).encloses(label))
		_check("test_label_touches_the_drawn_box_got_%s_box_%s" % [label, box], label.grow(3.0).intersects(box))
		var flat_box: Rect2 = geo.flat_cells_rect(cells)
		_check("test_drawn_box_differs_from_the_flat_box", not box.is_equal_approx(flat_box))
		# The ghost / drag aim: the drag point of a cell aims back at that cell through the inverse map.
		_check("test_drag_point_for_cell_lands_on_the_warped_cell_centre", combat.drag_point_for_cell(c0).distance_to(geo.cell_center(c0) + Vector2(0.0, combat.get_drag_lift_px())) < EPS_PX)


func test_flag_off_again_restores_the_tree(canvas: BattleCanvas, combat: CombatView) -> void:
	combat.floor_perspective_override = 0.0
	canvas.apply_floor_perspective()
	_check("test_off_again_no_floor_viewport", canvas.get_floor_viewport() == null)
	_check("test_off_again_floor_layer_back_in_the_art_viewport_got_%s" % [_layer_names(canvas.get_art_viewport())],
		_layer_names(canvas.get_art_viewport()) == FLAT_LAYERS and canvas.get_floor_layer().get_parent() == canvas.get_art_viewport())
	_check("test_off_again_no_perspective", canvas.get_floor_perspective() == null)

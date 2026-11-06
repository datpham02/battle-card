extends SceneTree
## Field pieces over tall heads (2026-11-02): the units and the overlay render in their own pass (BattleCanvas
## UnitViewport, a transparent viewport sharing the art viewport's World2D that renders only UNIT_VISIBILITY_LAYER),
## drawn by BattleUnitView after the field-point views and before the hold slots / cut HUD. So a field piece lying in
## the cell behind a unit is under the unit's head, and the art viewport no longer draws the units a second time.
## Headless: the SubViewports render nothing, only the tree order, the layers and the viewport flags are checked.
## Evidence: production/qa/evidence/head-occlusion/.
## Run: godot --headless --path . -s res://tests/unit/battle/unit_pass_order_test.gd

const MAX_FRAMES: int = 600

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
	for _i: int in MAX_FRAMES:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	await process_frame
	var battle: Node = rc.get_battle()
	_check("test_battle_spawned", battle != null)
	if battle == null:
		_finish()
		return
	var canvas := battle.get_node_or_null("BattleCanvas") as BattleCanvas
	var view := battle.get_node_or_null("BattleUnitView") as BattleUnitView
	_check("test_battle_has_a_BattleUnitView", view != null)
	if canvas == null or view == null:
		_finish()
		return
	test_unit_view_sits_between_the_field_pieces_and_the_hud(battle, view)
	test_units_and_overlay_on_the_unit_layer_only(canvas)
	test_art_viewport_culls_the_units(canvas)
	test_pickup_layer_between_floor_and_units(canvas)
	test_unit_viewport_renders_only_the_units(canvas)
	_check("test_unit_view_draws_this_canvas", view.get_battle_canvas() == canvas)
	_finish()


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_unit_view_sits_between_the_field_pieces_and_the_hud(battle: Node, view: BattleUnitView) -> void:
	var at: int = view.get_index()
	for below: String in ["BattleCanvas", "CombatView", "FieldDropsView", "BossDropsView"]:
		var node: Node = battle.get_node_or_null(below)
		_check("test_%s_draws_under_the_units" % below, node != null and node.get_index() < at)
	for above: String in ["HoldSlotsView", "CutHudView", "DPadView"]:
		var node: Node = battle.get_node_or_null(above)
		_check("test_%s_draws_over_the_units" % above, node != null and node.get_index() > at)


func test_units_and_overlay_on_the_unit_layer_only(canvas: BattleCanvas) -> void:
	var bit: int = BattleCanvas.UNIT_VISIBILITY_LAYER
	_check("test_unit_layer_renders_on_the_unit_layer_only", canvas.get_unit_layer().visibility_layer == bit)
	_check("test_overlay_layer_renders_on_the_unit_layer_only", canvas.get_overlay_layer().visibility_layer == bit)
	var flash := canvas.get_unit_layer().get_node_or_null("HitFlash") as CanvasItem
	# A viewport draws an item only when every parent shares its layer: the hit flash child must follow.
	_check("test_hit_flash_child_on_the_unit_layer", flash != null and flash.visibility_layer == bit)
	_check("test_backdrop_not_on_the_unit_layer", canvas.get_backdrop_layer().visibility_layer & bit == 0)
	_check("test_floor_not_on_the_unit_layer", canvas.get_floor_layer().visibility_layer & bit == 0)


# 2026-11-05 (voxel pickups, forest-integration-pickup-plan step 1): the field pieces moved from FieldDropsView into the
# art canvas. The PickupLayer must render in the ART viewport (not the unit pass) after the floor / its warp and before
# the units, so the unit pass (BattleUnitView, over the canvas) still covers a piece lying behind a tall head.
func test_pickup_layer_between_floor_and_units(canvas: BattleCanvas) -> void:
	var pickups: PickupLayer = canvas.get_pickup_layer()
	_check("test_canvas_has_a_pickup_layer", pickups != null)
	if pickups == null:
		return
	var art: SubViewport = canvas.get_art_viewport()
	# 2026-11-06 (user: sigils lie with the stone tilt): with the perspective on, PickupLayer lives in its own flat
	# PickupViewport and a PickupWarp sprite (floor shader) takes its place between the floor warp and the units.
	var shown: Node = pickups
	if canvas.get_pickup_viewport() != null:
		shown = art.get_node_or_null("PickupWarp")
		_check("test_pickup_layer_lives_in_the_pickup_viewport", pickups.get_parent() == canvas.get_pickup_viewport()
			and canvas.get_pickup_viewport().get_parent() == art)
	_check("test_pickup_shown_in_the_art_viewport", shown != null and shown.get_parent() == art)
	if shown == null:
		return
	_check("test_pickup_layer_not_on_the_unit_layer", pickups.visibility_layer & BattleCanvas.UNIT_VISIBILITY_LAYER == 0
		and (shown as CanvasItem).visibility_layer & BattleCanvas.UNIT_VISIBILITY_LAYER == 0)
	_check("test_pickup_layer_before_the_unit_layer", shown.get_index() < canvas.get_unit_layer().get_index())
	var floor_node: Node = art.get_node_or_null("FloorWarp")
	if floor_node == null:
		floor_node = canvas.get_floor_layer()
	_check("test_pickup_layer_after_the_floor", floor_node.get_parent() == art and floor_node.get_index() < shown.get_index())


func test_art_viewport_culls_the_units(canvas: BattleCanvas) -> void:
	var mask: int = canvas.get_art_viewport().canvas_cull_mask
	_check("test_art_viewport_culls_the_unit_layer", mask & BattleCanvas.UNIT_VISIBILITY_LAYER == 0)
	_check("test_art_viewport_still_draws_the_floor", mask & canvas.get_floor_layer().visibility_layer != 0)


func test_unit_viewport_renders_only_the_units(canvas: BattleCanvas) -> void:
	var uvp: SubViewport = canvas.get_unit_viewport()
	var art: SubViewport = canvas.get_art_viewport()
	_check("test_unit_viewport_exists_under_the_canvas", uvp != null and uvp.get_parent() == canvas)
	if uvp == null:
		return
	_check("test_unit_viewport_shares_the_art_world", uvp.world_2d == art.world_2d)
	_check("test_unit_viewport_cull_mask_is_the_unit_layer", uvp.canvas_cull_mask == BattleCanvas.UNIT_VISIBILITY_LAYER)
	_check("test_unit_viewport_transparent", uvp.transparent_bg)
	_check("test_unit_viewport_same_size_got_%s" % uvp.size, uvp.size == art.size)
	_check("test_unit_viewport_nearest_and_snapped", uvp.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		and uvp.snap_2d_transforms_to_pixel and uvp.snap_2d_vertices_to_pixel and uvp.msaa_2d == Viewport.MSAA_DISABLED)
	_check("test_unit_viewport_updates_always", uvp.render_target_update_mode == SubViewport.UPDATE_ALWAYS)

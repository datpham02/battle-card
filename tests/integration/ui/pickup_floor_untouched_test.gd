extends SceneTree
## Voxel pickups (design/art/forest-integration-pickup-plan-2026-11-05.md section 4.3, check required by the user):
## with the PickupLayer hidden, the floor cell under a field piece must not change a single pixel (no cell tint, cell
## outline, label tag or freshness bar left anywhere for piece points). With the layer shown, the piece is drawn and
## every changed pixel lies inside the pickup's own sprite box. Renders real frames, so windowed only:
##   godot --path . --windowed --resolution 1280x720 -s res://tests/integration/ui/pickup_floor_untouched_test.gd -- --no-autopause

const MAX_FRAMES: int = 600
const SETTLE_FRAMES: int = 6
## Freshness shares checked (intact, hairline, deep): the old look tinted the cell at every one of them.
const RATIOS: Array[float] = [1.0, 0.4, 0.1]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _settle() -> void:
	for _i: int in SETTLE_FRAMES:
		await process_frame


func _region(rect: Rect2i) -> Image:
	return root.get_texture().get_image().get_region(rect)


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
	await _settle()
	var battle: Node = rc.get_battle()
	var combat := battle.get_node("CombatView") as CombatView
	var canvas := battle.get_node("BattleCanvas") as BattleCanvas
	var layer: PickupLayer = canvas.get_pickup_layer()
	_check("test_canvas_has_a_pickup_layer", layer != null)
	if layer == null:
		_finish()
		return
	combat.freeze_time = true
	combat.get_boss().set_active(false)
	# Clear the start pieces and let their shatters finish (layer clock advanced by hand, time is frozen).
	var all: Array[Vector2i] = combat.get_grid().player_cells() + combat.get_grid().enemy_cells()
	combat.get_drops().bury_cells(all)
	combat.get_boss().get_drops().bury_cells(all)
	layer.advance(VoxelPiece.shatter_sec() + 0.1)
	await _settle()
	var geo: BoardGeometry = combat.board_geometry()
	var stand: Vector2i = combat.get_state().player_cell
	var target: Vector2i = stand
	var best: int = -1
	for c: Vector2i in combat.get_grid().player_cells():
		var d: int = absi(c.x - stand.x) + absi(c.y - stand.y)
		if d > best:
			best = d
			target = c
	var screen := Rect2i(geo.cell_bounds(target).grow(2.0))
	var before: Image = _region(screen)
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var total: float = combat.get_drops_config().piece_freshness_sec
	for ratio: float in RATIOS:
		var point: FieldPoint = combat.get_drops().debug_place_piece(lib.make_piece("l3", 0), target, total * ratio)
		_check("test_piece_placed_at_ratio_%.2f" % ratio, point != null)
		layer.visible = false
		await _settle()
		var hidden: Image = _region(screen)
		var diff_hidden: int = _diff_count(before, hidden)
		_check("test_layer_hidden_floor_cell_unchanged_at_ratio_%.2f" % ratio, diff_hidden == 0, "%d px changed" % diff_hidden)
		layer.visible = true
		await _settle()
		var shown: Image = _region(screen)
		_check("test_layer_shown_draws_the_piece_at_ratio_%.2f" % ratio, _diff_count(before, shown) > 0)
		var box: Rect2i = _pickup_screen_box(layer, canvas, target)
		var outside: int = _diff_outside(before, shown, screen, box)
		_check("test_changes_only_inside_the_pickup_box_at_ratio_%.2f" % ratio, outside == 0, "%d px outside %s" % [outside, box])
		combat.get_drops().bury_cells([target] as Array[Vector2i])
		layer.advance(VoxelPiece.shatter_sec() + 0.1)
		await _settle()
	_check("test_nothing_left_after_the_last_shatter", _diff_count(before, _region(screen)) == 0)
	_finish()


func _finish() -> void:
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _diff_count(a: Image, b: Image) -> int:
	var n: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				n += 1
	return n


func _diff_outside(a: Image, b: Image, origin: Rect2i, box: Rect2i) -> int:
	var n: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if box.has_point(origin.position + Vector2i(x, y)):
				continue
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				n += 1
	return n


# Screen box of the pickup on [param cell]: its sprite frame (art px, +1 art px margin) scaled to
# the screen through the art rect.
func _pickup_screen_box(layer: PickupLayer, canvas: BattleCanvas, cell: Vector2i) -> Rect2i:
	for p: Dictionary in layer.pickups():
		if p["cell"] != cell:
			continue
		var frame: Dictionary = p["frame"]
		var art := Rect2i(p["sprite_pos"], frame["size"]).grow(1)
		# 2026-11-06: a warped layer draws in the flat floor space: the box is the hull of its warped corners.
		if layer.warped:
			var geo: BoardGeometry = canvas.get_combat_view().board_geometry()
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for c: Vector2 in [Vector2(art.position), Vector2(art.end.x, art.position.y), Vector2(art.position.x, art.end.y), Vector2(art.end)]:
				var w: Vector2 = geo.warp_art(c)
				lo = lo.min(w)
				hi = hi.max(w)
			art = Rect2i(Vector2i(lo.floor()), Vector2i((hi - lo).ceil())).grow(1)
		var vp: Vector2 = Vector2(root.size)
		var ar: Rect2 = ScreenLayout.art_rect(vp)
		var s: float = ar.size.x / ScreenLayout.ART_CANVAS_WIDTH
		return Rect2i(Vector2i((ar.position + Vector2(art.position) * s).floor()), Vector2i((Vector2(art.size) * s).ceil()))
	return Rect2i()

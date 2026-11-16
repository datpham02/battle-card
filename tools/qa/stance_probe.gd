extends SceneTree
## Evidence tool (monster-cast-anim session, 2026-11-16): measures where a unit's feet actually land inside its
## cell, against the two rules the user fixed — a unit stands at the CELL CENTRE, and a floor effect sits in the
## middle of its cell.
##
## Run (windowed, muted):
##   godot --audio-driver Dummy --path . -s res://tools/qa/stance_probe.gd -- <out_dir> <chapter> <match_id>
##
## IT MEASURES THE GEOMETRY, NOT THE PICTURE. Reading a sprite's feet off a screenshot means guessing which
## pixel is a foot and which is a shadow, on a board whose rows are not the same size. The engine already knows
## the exact numbers, so this asks it: the feet anchor it computed, and the drawn quad of the same cell.
##
## THE TWO CANDIDATE FAULTS, which produce different numbers:
##
## 1. THE CLAMP. `UnitLayer._feet_of_cell` takes `y = min(top + h * FEET_DEPTH_RATIO, bottom - FEET_INSET_ART)`
##    on the FLAT rect. When a cell is short, the second term wins and the feet are pushed to the cell's front
##    lip instead of its centre. Printed per cell as `clamped`.
##
## 2. THE WARP. The anchor is the warp of the flat centre. The drawn cell is a trapezoid, and warping the
##    midpoint of a trapezoid does NOT give its centroid — the centroid of a shape that is wider at the near
##    edge sits NEARER than the warped midpoint. If that is the fault, every cell is off by the same sign and
##    the error grows with the row's perspective, which is exactly what `d_centroid` below reports.
##
## A single number cannot separate those two, which is why both are printed for every cell of the board.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://stance_probe"
	var chapter: String = args[1] if args.size() > 1 else "ch1"
	var match_id: String = args[2] if args.size() > 2 else "goblin_scout"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character("kiem_si")
	var rc: RunController = gf.enter_test_floor(
		RunConfig.from_node(ChaptersConfig.load_from_file(), chapter, match_id, "battle", 7, 2))
	for _i: int in 900:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	for _i: int in 120:
		await process_frame

	var layer := rc.get_battle().find_child("UnitLayer", true, false) as UnitLayer
	var geo := rc.get_battle().find_child("BoardGeometry", true, false)
	if layer == null:
		print("FAIL no UnitLayer")
		quit(1)
		return
	var grid: Variant = null
	var bg: Variant = layer.get("_bg") if layer.has_method("get") else null

	print("probe %s/%s" % [chapter, match_id])
	print("cell  flat_rect              clamped  feet_y  flat_mid_y  drawn_quad_y(top..bot)  centroid_y  d_centroid")
	var cols: int = 7
	var rows: int = 5
	for y: int in rows:
		for x: int in cols:
			var cell := Vector2i(x, y)
			var flat: Rect2i = layer.call("_cell_art_rect", cell)
			if flat.size.x <= 0:
				continue
			var mid_y: int = flat.position.y + roundi(flat.size.y * UnitLayer.FEET_DEPTH_RATIO)
			var lip_y: int = flat.end.y - UnitLayer.FEET_INSET_ART
			var clamped: bool = mid_y > lip_y
			var feet: Vector2i = layer.feet_art_of_cell(cell)
			# the drawn quad of the same cell, to compare against what the eye reads as "the middle of the cell"
			var tl: Vector2i = layer.call("_warp_feet", Vector2i(flat.position.x, flat.position.y))
			var tr: Vector2i = layer.call("_warp_feet", Vector2i(flat.end.x, flat.position.y))
			var br: Vector2i = layer.call("_warp_feet", Vector2i(flat.end.x, flat.end.y))
			var bl: Vector2i = layer.call("_warp_feet", Vector2i(flat.position.x, flat.end.y))
			var centroid_y: float = (tl.y + tr.y + br.y + bl.y) / 4.0
			print("%d,%d   %4d,%4d %3dx%3d   %-7s %6d %10d   %4d..%-4d %16.1f %+10.1f" % [
				x, y, flat.position.x, flat.position.y, flat.size.x, flat.size.y,
				"YES" if clamped else "no", feet.y, mid_y, mini(tl.y, tr.y), maxi(bl.y, br.y),
				centroid_y, float(feet.y) - centroid_y])

	root.get_texture().get_image().save_png(out.path_join("stance_%s_%s.png" % [chapter, match_id]))
	print("SHOT saved")
	quit(0)

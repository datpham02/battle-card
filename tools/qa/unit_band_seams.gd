extends SceneTree
## Evidence tool (unit motion pass, 2026-11-13): the band seams of the unit motion poses, controlled. For each unit id
## it takes `idle` frame 0 from the sheet PNG, measures the body height (topmost opaque row, as UnitMotion does), splits
## it with UnitLayer.band_split + the unit's UnitMotion.band_rows, and composes the frame for a set of poses exactly the
## way UnitLayer._draw_frame_bands draws it (legs in place, torso by (lean / 2, squash), head by (lean, squash), upper
## bands over lower). Saves <out_dir>/<id>_seams.png, scaled 6x nearest:
##   row 1: each pose on a light ground, with cyan ticks in the left margin at the two split rows (waist, chest)
##   row 2: the same poses with every art px that differs from the zero pose in magenta over a grey silhouette
## Pose list: zero, lean +1, lean -1, squash 1, lean +1 squash 1, lean +2 (agile max), squash 2 (heavy / blob max).
## Headless: godot --headless --path . -s res://tools/qa/unit_band_seams.gd -- <out_dir> <unit_id> [<unit_id> ...]

const SCALE: int = 6
const POSES: Array[Vector4i] = [Vector4i(0, 0, 0, 0), Vector4i(0, 0, 1, 0), Vector4i(0, 0, -1, 0), Vector4i(0, 0, 0, 1),
	Vector4i(0, 0, 1, 1), Vector4i(0, 0, 2, 0), Vector4i(0, 0, 0, 2)]
const MARGIN: int = 6
const PAD: int = 4
const GROUND: Color = Color(0.82, 0.84, 0.88)
const SILHOUETTE: Color = Color(0.62, 0.62, 0.66)
const CHANGED: Color = Color(1.0, 0.1, 0.8)
const TICK: Color = Color(0.0, 0.85, 0.95)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	for i in range(1, args.size()):
		_one(out, args[i])
	print("DONE")
	quit(0)


func _one(out: String, spec: String) -> void:
	# "<unit_id>" uses idle frame 0; "<unit_id>:<clip>" uses frame 0 of that clip (windup is a held frame).
	var id: String = spec.get_slice(":", 0)
	var clip_name: String = spec.get_slice(":", 1) if spec.contains(":") else "idle"
	var sheet: SpriteSheet = SpriteSheet.load_unit(id)
	var img := Image.load_from_file(ProjectSettings.globalize_path(sheet.image_path()))
	img.convert(Image.FORMAT_RGBA8)
	var r: Rect2i = (sheet.clip(clip_name)["frames"] as Array)[0]
	var frame: Image = img.get_region(r)
	# The split always comes from the idle body height, as in the game (UnitMotion.body_height_of measures idle frame 0).
	var idle_frame: Image = img.get_region((sheet.clip("idle")["frames"] as Array)[0])
	var top: int = 0
	for y: int in idle_frame.get_height():
		var hit: bool = false
		for x: int in idle_frame.get_width():
			if idle_frame.get_pixel(x, y).a > 0.5:
				hit = true
				break
		if hit:
			top = y
			break
	var body_h: int = frame.get_height() - top
	var m: UnitMotion = UnitMotion.for_unit(id)
	var split: Vector2i = UnitLayer.band_split(frame.get_height(), body_h, m.band_rows(body_h))
	id = spec.replace(":", "_")
	print("%s: frame %s body_h %d archetype %s chest_y %d waist_y %d" % [id, frame.get_size(), body_h, m.archetype, split.x, split.y])
	var cell := Vector2i(frame.get_width() + 2 * PAD, frame.get_height() + 2 * PAD)
	var sheet_out := Image.create(MARGIN + POSES.size() * (cell.x + 2), 2 * (cell.y + 2), false, Image.FORMAT_RGBA8)
	sheet_out.fill(Color(0.1, 0.09, 0.13))
	var zero: Image = _compose(frame, split, POSES[0], cell)
	for k: int in POSES.size():
		var posed: Image = _compose(frame, split, POSES[k], cell)
		var x0: int = MARGIN + k * (cell.x + 2)
		var lit := Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
		lit.fill(GROUND)
		lit.blend_rect(posed, Rect2i(Vector2i.ZERO, cell), Vector2i.ZERO)
		sheet_out.blit_rect(lit, Rect2i(Vector2i.ZERO, cell), Vector2i(x0, 0))
		var diff := Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
		diff.fill(GROUND)
		for y: int in cell.y:
			for x: int in cell.x:
				var a: Color = zero.get_pixel(x, y)
				var b: Color = posed.get_pixel(x, y)
				if a != b:
					diff.set_pixel(x, y, CHANGED)
				elif b.a > 0.5:
					diff.set_pixel(x, y, SILHOUETTE)
		sheet_out.blit_rect(diff, Rect2i(Vector2i.ZERO, cell), Vector2i(x0, cell.y + 2))
		if POSES[k].w > 0:
			# Lower-band loss: legs-band art px (rows at and below the waist split) that the squashed torso changes,
			# against the opaque px of the legs-band rows it can reach.
			var lost: int = 0
			var reach: int = 0
			for y: int in range(PAD + split.y, PAD + mini(split.y + POSES[k].w, frame.get_height())):
				for x: int in cell.x:
					if zero.get_pixel(x, y).a > 0.5:
						reach += 1
						if zero.get_pixel(x, y) != posed.get_pixel(x, y):
							lost += 1
			print("  %s squash %d lean %d: legs-band px changed %d of %d opaque in the %d covered row(s); total px changed %d"
				% [id, POSES[k].w, POSES[k].z, lost, reach, POSES[k].w, _count_diff(zero, posed)])
		elif POSES[k].z != 0:
			print("  %s lean %d: total px changed %d; new silhouette breaks at the chest row (frame x): %s; at the waist row: %s"
				% [id, POSES[k].z, _count_diff(zero, posed), _breaks(zero, posed, PAD + split.x), _breaks(zero, posed, PAD + split.y)])
	# Split ticks in the left margin (both rows), at the frame rows chest_y and waist_y.
	for row_y: int in [split.x, split.y]:
		for base: int in [0, cell.y + 2]:
			for x: int in MARGIN - 1:
				sheet_out.set_pixel(x, base + PAD + row_y, TICK)
	sheet_out.resize(sheet_out.get_width() * SCALE, sheet_out.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	sheet_out.save_png(out.path_join("%s_seams.png" % id))


# Columns (frame x, runs merged as "a-b") where the opaque / clear state of row [param y] - 1 and row [param y] differs
# in [param posed] but not in [param zero]: silhouette edges a pose breaks at a band seam (art already open there is
# not counted).
func _breaks(zero: Image, posed: Image, y: int) -> String:
	if y <= 0 or y >= zero.get_height():
		return "-"
	var runs: PackedStringArray = []
	var start: int = -1
	for x: int in zero.get_width() + 1:
		var hit: bool = false
		if x < zero.get_width():
			var z: bool = (zero.get_pixel(x, y - 1).a > 0.5) != (zero.get_pixel(x, y).a > 0.5)
			var p: bool = (posed.get_pixel(x, y - 1).a > 0.5) != (posed.get_pixel(x, y).a > 0.5)
			hit = p and not z
		if hit and start < 0:
			start = x
		elif not hit and start >= 0:
			runs.append(str(start - PAD) if x - 1 == start else "%d-%d" % [start - PAD, x - 1 - PAD])
			start = -1
	return "none" if runs.is_empty() else ", ".join(runs)


func _count_diff(a: Image, b: Image) -> int:
	var n: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


# The frame drawn for [param pose] into a transparent image of [param cell] (the frame at PAD, PAD), band by band.
func _compose(frame: Image, split: Vector2i, pose: Vector4i, cell: Vector2i) -> Image:
	var out := Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
	var w: int = frame.get_width()
	var h: int = frame.get_height()
	var chest_y: int = split.x
	var waist_y: int = split.y
	@warning_ignore("integer_division")
	var torso_dx: int = pose.z / 2
	if waist_y < h:
		out.blend_rect(frame, Rect2i(0, waist_y, w, h - waist_y), Vector2i(PAD, PAD + waist_y))
	if chest_y < waist_y:
		out.blend_rect(frame, Rect2i(0, chest_y, w, waist_y - chest_y), Vector2i(PAD + torso_dx, PAD + chest_y + pose.w))
	if chest_y > 0:
		out.blend_rect(frame, Rect2i(0, 0, w, chest_y), Vector2i(PAD + pose.z, PAD + pose.w))
	return out

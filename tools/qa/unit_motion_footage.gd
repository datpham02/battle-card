extends SceneTree
## Evidence tool (unit motion pass, 2026-11-13): opens a battle with the hero against one enemy and drives the
## UnitLayer clock by hand at a fixed 1/60 s per captured frame, so the footage is deterministic and the PNG writes do
## not skew the timing. The match is frozen first: the boss brain paused (BossController.set_active), a pattern brain
## paused through its own PatternController.set_active(false), which cancels a windup / warning and returns it to IDLE,
## and CombatView's _process stopped. No game code is changed by this tool.
## Saves into <out_dir>:
##   context.png            the whole screen once (1280x720 window)
##   idle_NNN.png           6.0 s of both units standing, every 3rd frame (50 ms): art-px crops that follow each unit's
##                          ground anchor, hero left, enemy right, scaled 4x nearest
##   screen_idle_NNN.png    the same frames from the real screen at 1:1 (the game's own display scale), no upscaling
##   step_NNN.png / screen_step_NNN.png   the hero steps, then the enemy steps; every frame for 0.6 s each
##   seam_NNN_<pose>.png    (after only) the enemy alone at 8x on the first frame of each distinct pose, with a
##                          zero-pose reference first: for checking the band seams
##   motion.csv             per frame: clip and pose (pose "-" on a layer without unit_pose)
## Run (windowed, muted):
##   godot --audio-driver Dummy --windowed --resolution 1280x720 --path . -s res://tools/qa/unit_motion_footage.gd -- \
##       <out_dir> <chapter_index> <enemy_id> [hero_id] [enemy_profile_override]
## enemy_profile_override: a unit id whose UnitMotion profile the enemy uses instead of its own ("" = the `default`
## archetype); only for showing a profile no shipped unit has. Ignored by a layer without motion profiles.

const DT: float = 1.0 / 60.0
const SCALE: int = 4
const SEAM_SCALE: int = 8
const SEAM_MAX: int = 8
const IDLE_FRAMES: int = 360

var _units: UnitLayer = null
var _canvas: BattleCanvas = null
## Screen-space rect (1:1) round both units, fixed for the run.
var _screen_crop: Rect2i = Rect2i()
## motion.csv rows.
var _rows: PackedStringArray = ["phase,frame,hero_clip,hero_pose,enemy_clip,enemy_pose"]
## Idle footage: art px changed between consecutive saved frames per unit crop (hero, enemy), and frames compared.
var _changed: Array[float] = [0.0, 0.0]
var _changed_n: float = 0.0
var _prev: Array = [null, null]
## Seam stills already saved (pose string -> true).
var _seams: Dictionary = {}
var _out: String = ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://unit_motion"
	var chapter: int = int(args[1]) if args.size() > 1 else 0
	var enemy: String = args[2] if args.size() > 2 else "goblin_scout"
	var hero: String = args[3] if args.size() > 3 else "kiem_si"
	var override: Variant = args[4] if args.size() > 4 and not args[4].is_empty() and args[4] != "-" else null
	var mode: String = args[5] if args.size() > 5 else "idle_step"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var main: Node = load("res://src/main.tscn").instantiate()
	var gf := main.get_node("GameFlow") as GameFlow
	gf.set_store_for_test(ProgressStore.memory_store())
	root.add_child(main)
	await process_frame
	gf.set_character(hero)
	var rc: RunController = gf.enter_test_floor(RunConfig.from_node(ChaptersConfig.load_from_file(), chapter, enemy, "battle", 7, 3))
	for _i in 600:
		if rc.get_state().get_phase() == RunState.Phase.PLAYING:
			break
		await process_frame
	var battle: Node = rc.get_battle()
	var v := battle.get_node("CombatView") as CombatView
	v.get_boss().set_active(false)
	for _i in 120:
		await process_frame
	_canvas = battle.get_child(0) as BattleCanvas
	_units = _canvas.get_unit_layer()
	_freeze(v)
	var st: CombatState = v.get_state()
	st.set_player_cell(Vector2i(1, 1))
	if not st.set_enemy_cell(Vector2i(4, 1)):
		# A multi-cell boss spawns on a varying cell: put it on the first cell (column, then row) its footprint fits,
		# so every run films the same place.
		var placed: bool = false
		for x: int in range(4, 12):
			for y: int in 4:
				if not placed and st.set_enemy_cell(Vector2i(x, y)):
					placed = true
	if override != null and "_motion" in _units:
		# Loaded by path: the committed tree (before footage) has no UnitMotion class, so the name must not be parsed.
		var motion_script: Script = load("res://src/art/unit_motion.gd")
		var motion: Dictionary = _units.get("_motion")
		motion[CombatState.Side.ENEMY] = motion_script.call("for_unit", String(override))
		print("enemy profile forced: ", motion[CombatState.Side.ENEMY].get("archetype"))
	# Let the match-start draw, any cancelled windup and the placement glides finish.
	for _i in 90:
		await _tick()
	print("player cell ", st.player_cell, " enemy cell ", st.enemy_cell, " clips ",
		_units.get_current_clip(CombatState.Side.PLAYER), " / ", _units.get_current_clip(CombatState.Side.ENEMY))
	_screen_crop = _screen_rect_round_units()
	if mode == "windup":
		await _windup(v)
		return
	root.get_texture().get_image().save_png(_out.path_join("context.png"))
	var n: int = 0
	for i in IDLE_FRAMES:
		await _tick()
		_log("idle", i)
		_seam(i)
		if i % 3 == 0:
			_save("idle_%03d.png" % n)
			n += 1
	v.get_mover().tick(5.0)
	var fwd := Vector2i(1, 0)
	if not st.grid.is_player_cell(st.player_cell + fwd) or st.is_enemy_at(st.player_cell + fwd):
		fwd = Vector2i(-1, 0)
	print("hero stepped: ", v.get_mover().try_step(fwd))
	n = 0
	for _i in 36:
		await _tick()
		_log("step", n)
		_save("step_%03d.png" % n)
		n += 1
	var bm: UnitMover = v.get_boss().get_mover()
	var stepped: bool = false
	if bm != null:
		bm.tick(5.0)
		for dir: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if bm.try_step(dir):
				stepped = true
				break
	if not stepped:
		# The mover refused (locked while the boss is frozen): move the cell directly; the glide still plays.
		for dir: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if st.set_enemy_cell(st.enemy_cell + dir):
				break
	print("enemy stepped by mover: ", stepped)
	for _i in 36:
		await _tick()
		_log("step", n)
		_save("step_%03d.png" % n)
		n += 1
	var f := FileAccess.open(_out.path_join("motion.csv"), FileAccess.WRITE)
	f.store_string("\n".join(_rows) + "\n")
	print("art scale on screen: %d screen px per art px" % ScreenLayout.art_scale(root.get_visible_rect().size))
	print("idle changed px per 50 ms frame: hero %.1f enemy %.1f" % [_changed[0] / maxf(_changed_n, 1.0), _changed[1] / maxf(_changed_n, 1.0)])
	print("DONE ", _out)
	quit(0)


# Windup mode: the pattern brain resumes and the whole match runs on CombatView's own tick, called by hand at a fixed
# DT (its _process is off), the layer on the same scaled step, so the windup plays at game timing whatever the PNG
# writes cost. Every frame from WINDUP_PRE frames before the enemy's first non-idle clip to WINDUP_POST frames after it
# is back in idle is saved: windup_NNN.png (4x, hero | enemy), screen_windup_NNN.png (1:1) and enemy_windup_NNN.png
# (the enemy alone at 8x); motion.csv logs every frame. Up to WINDUP_MAX_WAIT frames are waited for a skill.
const WINDUP_PRE: int = 10
const WINDUP_POST: int = 40
const WINDUP_MAX_WAIT: int = 900
const WINDUP_MAX_LEN: int = 400


func _windup(v: CombatView) -> void:
	var pc: PatternController = v.get_pattern_controller()
	if pc != null and pc.has_method("set_active"):
		pc.call("set_active", true)
	# Pre-roll: the last WINDUP_PRE frames (art image, screen image) before the enemy leaves idle.
	var ring: Array = []
	var started: int = -1
	var back_idle: int = -1
	var n: int = 0
	for i in WINDUP_MAX_WAIT + WINDUP_MAX_LEN:
		v._process(DT)
		_units.advance(v.scaled_delta(DT))
		_units.queue_redraw()
		for c in _units.get_children():
			(c as CanvasItem).queue_redraw()
		await RenderingServer.frame_post_draw
		_log("windup", i)
		var clip: String = _units.get_current_clip(CombatState.Side.ENEMY)
		var art: Image = _art_image()
		var screen: Image = root.get_texture().get_image()
		if started < 0:
			if clip != "idle" and clip != "step":
				started = i
				print("enemy left idle at frame %d with clip %s (stage %d)" % [i, clip, pc.get_stage() if pc != null else -1])
				for pre: Array in ring:
					_save_windup(n, pre[0], pre[1])
					n += 1
			elif i >= WINDUP_MAX_WAIT:
				print("no windup within %d frames" % WINDUP_MAX_WAIT)
				break
			else:
				ring.append([art, screen])
				if ring.size() > WINDUP_PRE:
					ring.pop_front()
				continue
		elif back_idle < 0 and clip == "idle":
			back_idle = i
			print("enemy back in idle at frame %d (%.2f s after it left)" % [i, (i - started) * DT])
		if back_idle >= 0 and i - back_idle >= WINDUP_POST:
			break
		if i - started >= WINDUP_MAX_LEN:
			break
		_save_windup(n, art, screen)
		n += 1
	var f := FileAccess.open(_out.path_join("motion.csv"), FileAccess.WRITE)
	f.store_string(LF.join(_rows) + LF)
	print("saved %d windup frames (%d pre-roll); DONE %s" % [n, WINDUP_PRE, _out])
	quit(0)


const LF: String = "\n"


func _save_windup(n: int, art: Image, screen: Image) -> void:
	_save("windup_%03d.png" % n, art, screen)
	var part: Image = _unit_crop(art, CombatState.Side.ENEMY)
	part.resize(part.get_width() * SEAM_SCALE, part.get_height() * SEAM_SCALE, Image.INTERPOLATE_NEAREST)
	part.save_png(_out.path_join("enemy_windup_%03d.png" % n))


# Stops everything that could start an attack: the boss brain, a pattern brain (its own pause cancels a windup or a
# warning and sets it back to IDLE), CombatView's tick and the layer's own _process.
func _freeze(v: CombatView) -> void:
	v.set_process(false)
	_units.set_process(false)
	v.get_boss().set_active(false)
	var pc: PatternController = v.get_pattern_controller()
	if pc != null:
		if pc.has_method("set_active"):
			pc.call("set_active", false)
		elif pc.is_busy():
			# The committed controller (before footage) has no pause: end the skill the way the pause does.
			pc.call("_end_skill", "paused", false)
		print("pattern brain paused, stage ", pc.get_stage())


func _log(phase: String, frame: int) -> void:
	var cells: PackedStringArray = [phase, str(frame)]
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		cells.append(_units.get_current_clip(side))
		cells.append(_pose_text(side))
	_rows.append(",".join(cells))


func _pose_text(side: int) -> String:
	if not _units.has_method("unit_pose"):
		return "-"
	var p: Vector4i = _units.call("unit_pose", side)
	return "%d %d %d %d" % [p.x, p.y, p.z, p.w]


func _tick() -> Signal:
	_units.advance(DT)
	_units.queue_redraw()
	for c in _units.get_children():
		(c as CanvasItem).queue_redraw()
	return RenderingServer.frame_post_draw


# The battle art in art px: the art SubViewport with the units' own transparent UnitViewport (BattleCanvas) blended
# over it.
func _art_image() -> Image:
	var img: Image = _canvas.get_art_viewport().get_texture().get_image()
	var top_img: Image = _canvas.get_unit_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	top_img.convert(Image.FORMAT_RGBA8)
	img.blend_rect(top_img, Rect2i(Vector2i.ZERO, top_img.get_size()), Vector2i.ZERO)
	return img


# The art-px crop round [param side]: its frame plus 8 px each way, bottom at its ground anchor + 8.
func _unit_crop(img: Image, side: int) -> Image:
	var sheet: SpriteSheet = _units.get_sheet(side)
	var fs: Vector2i = sheet.frame_size() if sheet != null else Vector2i(64, 64)
	var feet: Vector2i = _units.unit_feet_art(side)
	var size: Vector2i = fs + Vector2i(16, 16)
	@warning_ignore("integer_division")
	var r := Rect2i(feet.x - size.x / 2, feet.y - fs.y - 8, size.x, size.y)
	var part := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	part.blit_rect(img, r, Vector2i.ZERO)
	return part


func _save(file: String, art: Image = null, screen_img: Image = null) -> void:
	var img: Image = art.duplicate() if art != null else _art_image()
	var parts: Array[Image] = []
	var w: int = 0
	var h: int = 0
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		var part: Image = _unit_crop(img, side)
		parts.append(part)
		if file.begins_with("idle_"):
			var k: int = parts.size() - 1
			if _prev[k] != null:
				_changed[k] += _diff(_prev[k], part)
				if k == 1:
					_changed_n += 1.0
			_prev[k] = part
		w += part.get_width() + 4
		h = maxi(h, part.get_height())
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.1, 0.09, 0.13))
	var x: int = 0
	for part: Image in parts:
		out.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(x, h - part.get_height()))
		x += part.get_width() + 4
	out.resize(w * SCALE, h * SCALE, Image.INTERPOLATE_NEAREST)
	out.save_png(_out.path_join(file))
	# The real screen at 1:1 (what the player sees in a 1280x720 window).
	var screen: Image = screen_img if screen_img != null else root.get_texture().get_image()
	screen.get_region(_screen_crop.intersection(Rect2i(Vector2i.ZERO, screen.get_size()))).save_png(_out.path_join("screen_" + file))


# The first frame of every distinct enemy pose, enemy alone at SEAM_SCALE (a zero pose is saved first as reference).
func _seam(frame: int) -> void:
	if not _units.has_method("unit_pose") or _seams.size() >= SEAM_MAX:
		return
	var text: String = _pose_text(CombatState.Side.ENEMY)
	if _seams.has(text):
		return
	if _seams.is_empty() and text != "0 0 0 0":
		return
	_seams[text] = true
	var part: Image = _unit_crop(_art_image(), CombatState.Side.ENEMY)
	part.resize(part.get_width() * SEAM_SCALE, part.get_height() * SEAM_SCALE, Image.INTERPOLATE_NEAREST)
	part.save_png(_out.path_join("seam_%03d_%s.png" % [frame, text.replace(" ", "_")]))


# A fixed screen rect round both units: from the art px round the two feet anchors to screen px through the art
# rect (ScreenLayout.art_rect: integer scale, centred).
func _screen_rect_round_units() -> Rect2i:
	var vp: Vector2 = root.get_visible_rect().size
	var art: Rect2 = ScreenLayout.art_rect(vp)
	var k: float = float(ScreenLayout.art_scale(vp))
	var hf: Vector2i = _units.unit_feet_art(CombatState.Side.PLAYER)
	var ef: Vector2i = _units.unit_feet_art(CombatState.Side.ENEMY)
	var top: int = mini(hf.y, ef.y) - 140
	var art_r := Rect2(float(mini(hf.x, ef.x) - 90), float(top), float(absi(ef.x - hf.x) + 180), float(maxi(hf.y, ef.y) + 16 - top))
	var r := Rect2i(Vector2i(art.position + art_r.position * k), Vector2i(art_r.size * k))
	return r.intersection(Rect2i(Vector2i.ZERO, Vector2i(vp)))


# Art px that differ between two same-size crops.
func _diff(a: Image, b: Image) -> int:
	var count: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count

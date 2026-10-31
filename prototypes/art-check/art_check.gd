extends Node2D
## DEV-ONLY art check for the vertical-slice sprites (art bible §8.9 #1, #3, #9).
## Throwaway prototype: it is not part of the game and nothing in src/ depends on it.
##
## It mimics the §8.2–8.3 render rules the battle will move to: a 640x360 art
## canvas (SubViewport) shown at an integer scale with Nearest filtering, slabs
## of 38x27 art-px by default (the smallest size, so the 5x5 board is the
## hardest case), units anchored bottom-centre 3 art-px above the slab's front
## edge and drawn back row first (y-sort). Sprites are read straight from the
## candidate PNGs, so no import settings are involved. The board sits in the
## band ScreenLayout gives it (below the HUD band, above the controls).
##
##   godot --path . --windowed --resolution 1280x720 res://prototypes/art-check/art_check.tscn \
##       -- --mode=normal --shot=C:/abs/out.png
##
##   --mode=normal    the Swordsman on the player half, one Goblin Scout on the enemy half
##   --mode=blackout  the same, every unit drawn as a flat Ink silhouette (§8.9 #1)
##   --mode=rows      three Goblin Scouts in one enemy column on three adjacent rows (§8.9 #3)
##   --board=CxR      cells per half (default 5x5; 3x3 is the other real board)
##   --arena=<id>     a shape from assets/data/arenas.json (bounding grid + missing cells,
##                    mirrored onto the enemy half like BoardGrid); overrides --board
##   --missing=c,r;…  ad-hoc shape for --board: missing cells in BoardGrid side coordinates
##                    (col 0 = farthest from the divider), mirrored onto the enemy half; put
##                    --board BEFORE --missing on the command line
##   --cell=WxH|auto  slab size in art-px (default 38x27; auto = the largest slab of aspect
##                    1.4 between 38x27 and 64x46 that fits the board band)
##   --scale=N        integer display scale (default 2 = 1280x720)
##   --hud            draw flat placeholder HUD zones Z1–Z5 (design/ux/hud.md) at 1280x720
##                    on top, so the units can be judged inside the real layout
##   --layout=v1|v2   v1 = the shipped ScreenLayout (arena to 55 %, fixed d-pad, straight
##                    slots); v2 = the 2026-10-31 sketch (arena to 64 %, floating joystick,
##                    slots on an arc)
##   --slabs=<9slice.png>,<stamps.png>  real slab art: the 16x16 nine-slice is stretched to the
##                    cell (corners and edges keep their pixels), stamps from the sheet (JSON
##                    beside it) are placed per cell seed; without it the flat placeholder is drawn
##   --props=<wall.png>,<thorns.png>  place the Wall one cell ahead of the hero (unit layer, a
##                    second unit behind it shows the overlap) and the Thorns on the floor beside
##                    the goblin
##   --anim=<clip>    play a clip on both units (idle, step, hit, defeat, victory, fall, cast,
##                    awaken; the goblin plays its matching clip); with --shot, one PNG per
##                    frame index is saved as <shot>-<i>.png and the run quits after one cycle
##   --shot=<path>    save a PNG of the window after SHOT_FRAME frames, then quit

const ART_SIZE := Vector2i(640, 360)
const DEFAULT_CELL := Vector2i(38, 27)
const MIN_CELL := Vector2i(38, 27)
const MAX_CELL := Vector2i(64, 46)
const CELL_ASPECT := 1.4
const DEFAULT_BOARD := Vector2i(5, 5)
## Art-px between the two halves (the divider).
const DIVIDER_GAP := 6
## Front lip of a slab, in art-px (§8.3: 2–3).
const LIP := 3
## The Ink gap between slabs, in art-px.
const GAP := 1
## Feet sit this many art-px above the slab's front edge (§1 technical consequences).
const FOOT_LIFT := 3
## ScreenLayout bands (ratios of the screen height): arena 3 %–55 %, HUD band = 20 % of the arena,
## side margin 3 % of the width.
const ARENA_TOP_RATIO := 0.03
const ARENA_BOTTOM_RATIO := 0.55
const HUD_HEIGHT_RATIO := 0.2
const MARGIN_RATIO := 0.03
## Sky band of the §6.4 backdrop recipe (horizon about 12 % from the top).
const SKY_RATIO := 0.12
const SHOT_FRAME := 30
const ARENAS_PATH := "res://assets/data/arenas.json"

const INK := Color("1B1722")
const GROUND := Color("3A3F36")
const SKY := Color("7D8896")
const STONE := Color("4A4640")
const STONE_LIGHT := Color("5A5650")
const LIP_COLOR := Color("2C2925")
const HUD_DARK := Color("2B2730")
const HUD_FRAME := Color("8E8A96")
const HP_PLAYER := Color("4CBF59")
const HP_BOSS := Color("EFE6D2")
const IVORY := Color("EFE6D2")

const HERO_DIR := "res://design/assets/candidates/swordsman/ASSET-001-%s-40x48.png"
const GOBLIN_DIR := "res://design/assets/candidates/goblin-scout/ASSET-003-%s-32x48.png"
const HERO_PNG := "res://design/assets/candidates/swordsman/ASSET-001-idle-A-40x48.png"
const GOBLIN_PNG := "res://design/assets/candidates/goblin-scout/ASSET-003-idle-A-32x48.png"
## --anim clips: hero frame names and the goblin clip played beside them (spec hold 0.4 s,
## except where the spec says otherwise; one hold for the whole clip here, it is a look test).
const CLIPS := {
	"idle": {"hero": ["idle-A", "idle-B"], "goblin": ["idle-A", "idle-B"], "hold": 0.4},
	"step": {"hero": ["step-A", "step-B"], "goblin": ["step-A", "step-B"], "hold": 0.3},
	"hit": {"hero": ["idle-A", "hit", "idle-A"], "goblin": ["idle-A", "hit", "idle-A"], "hold": 0.4},
	"defeat": {"hero": ["idle-A", "defeat-A", "defeat-B"], "goblin": ["idle-A", "down-A", "down-B"], "hold": 0.4},
	"victory": {"hero": ["victory-A", "victory-B"], "goblin": ["idle-A", "idle-B"], "hold": 0.4},
	"fall": {"hero": ["idle-A", "fall"], "goblin": ["idle-A", "idle-B"], "hold": 0.4},
	"cast": {"hero": ["idle-A", "cast-A", "cast-B", "idle-A"], "goblin": ["idle-A", "windup", "windup", "idle-A"], "hold": 0.4},
	"awaken": {"hero": ["awaken-A", "awaken-B"], "goblin": ["idle-A", "windup"], "hold": 0.4},
}

var _mode: String = "normal"
var _cell: Vector2i = DEFAULT_CELL
var _cell_auto: bool = false
var _board: Vector2i = DEFAULT_BOARD
var _arena_id: String = ""
## Missing cells per half in LOCAL columns (0 = leftmost column of that half on screen).
var _missing: Array[Dictionary] = [{}, {}]
var _scale: int = 2
var _hud: bool = false
## "v1" = the shipped ScreenLayout (arena to 55 %, fixed d-pad, straight slots);
## "v2" = the user's 2026-10-31 sketch (arena to 64 %, floating 4-way joystick, slots on an arc).
var _layout: String = "v1"
var _arena_bottom: float = ARENA_BOTTOM_RATIO
## Where the v2 controls start (the thumb zones); the board band may run below it when its
## lower rows are narrow enough to pass between the thumbs (--arena-bottom).
var _controls_top: float = 0.64
## Width of the v2 joystick home zone as a ratio of the screen width.
var _stick_zone_w: float = 0.25
var _shot: String = ""
var _frames: int = 0
var _units: Node2D
## --props: "<wall.png>,<thorns.png>"; the wall stands on the player's cell one column toward the
## divider (unit layer, y-sorted like a unit), the thorns lie on the goblin's neighbour cell (floor).
var _wall_png: String = ""
var _thorns_png: String = ""
## --slabs: real slab art (9-slice + stamps) instead of the flat placeholder slab.
var _slab_tex: ImageTexture
var _stamp_tex: ImageTexture
var _stamps: Array = []
var _slab_margins := {"left": 3, "right": 3, "top": 3, "bottom": 4}
## --anim state: clip name, per-sprite texture lists, current index, time in the current frame.
var _anim: String = ""
var _anim_sprites: Array[Sprite2D] = []
var _anim_textures: Array = []
var _anim_index: int = 0
var _anim_time: float = 0.0
var _anim_shots_left: int = 0
var _capturing: bool = false


func _ready() -> void:
	_parse_args()
	if not _arena_id.is_empty() and _arena_id != "custom":
		_load_arena(_arena_id)
	if _cell_auto:
		_cell = _auto_cell()
	var viewport := SubViewport.new()
	viewport.name = "Art"
	viewport.size = ART_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	add_child(viewport)

	var board := Node2D.new()
	board.name = "Board"
	board.draw.connect(_draw_board.bind(board))
	viewport.add_child(board)

	_units = Node2D.new()
	_units.name = "Units"
	_units.y_sort_enabled = true
	viewport.add_child(_units)
	_place_units()

	var screen := Sprite2D.new()
	screen.name = "Screen"
	screen.texture = viewport.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.centered = false
	screen.scale = Vector2(_scale, _scale)
	var shown: Vector2 = Vector2(ART_SIZE) * _scale
	screen.position = ((get_viewport_rect().size - shown) * 0.5).floor()
	add_child(screen)
	board.queue_redraw()

	if _hud:
		var hud := Node2D.new()
		hud.name = "Hud"
		hud.draw.connect(_draw_hud.bind(hud))
		add_child(hud)
		hud.queue_redraw()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--scale="):
			_scale = maxi(1, arg.trim_prefix("--scale=").to_int())
		elif arg.begins_with("--cell="):
			if arg.trim_prefix("--cell=") == "auto":
				_cell_auto = true
			else:
				_cell = _parse_pair(arg.trim_prefix("--cell="), _cell)
		elif arg.begins_with("--board="):
			_board = _parse_pair(arg.trim_prefix("--board="), _board)
		elif arg.begins_with("--arena="):
			_arena_id = arg.trim_prefix("--arena=")
		elif arg.begins_with("--missing="):
			# Ad-hoc shape: "c,r;c,r;..." in BoardGrid side coordinates, applied to --board.
			_missing = [{}, {}]
			for pair: String in arg.trim_prefix("--missing=").split(";", false):
				var p: PackedStringArray = pair.split(",")
				if p.size() == 2:
					var side_col: int = p[0].to_int()
					var row: int = p[1].to_int()
					_missing[0][Vector2i(side_col, row)] = true
					_missing[1][Vector2i(_board.x - 1 - side_col, row)] = true
			_arena_id = "custom"
		elif arg == "--hud":
			_hud = true
		elif arg.begins_with("--props="):
			var pp: PackedStringArray = arg.trim_prefix("--props=").split(",")
			if pp.size() == 2:
				_wall_png = pp[0]
				_thorns_png = pp[1]
		elif arg.begins_with("--slabs="):
			# "<9slice.png>,<stamps.png>" (res:// paths); the stamps JSON sits beside the stamps PNG.
			var parts: PackedStringArray = arg.trim_prefix("--slabs=").split(",")
			if parts.size() == 2:
				_load_slabs(parts[0], parts[1])
		elif arg.begins_with("--anim="):
			_anim = arg.trim_prefix("--anim=")
			if not CLIPS.has(_anim):
				push_error("art_check: unknown clip '%s'" % _anim)
				_anim = ""
		elif arg.begins_with("--layout="):
			_layout = arg.trim_prefix("--layout=")
	if _layout == "v2":
		_arena_bottom = _controls_top
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--arena-bottom="):
			# Board band bottom as a ratio of the height; the v2 controls keep starting at 64 %.
			_arena_bottom = clampf(arg.trim_prefix("--arena-bottom=").to_float(), 0.3, 0.95)


func _parse_pair(text: String, fallback: Vector2i) -> Vector2i:
	var parts: PackedStringArray = text.split("x")
	if parts.size() == 2 and parts[0].to_int() > 0 and parts[1].to_int() > 0:
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return fallback


## Reads one shape of arenas.json. Missing cells are in BoardGrid side coordinates (side col 0 =
## farthest from the divider on BOTH halves), so on the player half the local column is the side
## column and on the enemy half it is mirrored.
func _load_arena(id: String) -> void:
	var text: String = FileAccess.get_file_as_string(ARENAS_PATH)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("shapes"):
		push_error("art_check: cannot read %s" % ARENAS_PATH)
		return
	for raw: Variant in (data as Dictionary)["shapes"]:
		var shape: Dictionary = raw
		if String(shape.get("id", "")) != id:
			continue
		_board = Vector2i(int(shape.get("side_cols", _board.x)), int(shape.get("side_rows", _board.y)))
		_missing = [{}, {}]
		for cell: Variant in shape.get("missing_cells", []):
			var c: Array = cell
			var side_col: int = int(c[0])
			var row: int = int(c[1])
			_missing[0][Vector2i(side_col, row)] = true
			_missing[1][Vector2i(_board.x - 1 - side_col, row)] = true
		print("art_check: arena %s = %dx%d per half, %d missing per half" % [id, _board.x, _board.y, _missing[0].size()])
		return
	push_error("art_check: arena '%s' not in %s" % [id, ARENAS_PATH])


## Largest slab (aspect 1.4, between MIN_CELL and MAX_CELL) whose board fits the band between the
## HUD band and the arena bottom, and whose two halves fit the width inside the side margins.
func _auto_cell() -> Vector2i:
	var band_h: float = ART_SIZE.y * _arena_bottom - _band_top()
	var half_w: float = (ART_SIZE.x * (1.0 - MARGIN_RATIO * 2.0) - DIVIDER_GAP) * 0.5
	var h: int = mini(MAX_CELL.y, int(band_h / _board.y))
	h = mini(h, int(half_w / _board.x / CELL_ASPECT))
	h = maxi(h, MIN_CELL.y)
	var w: int = mini(MAX_CELL.x, int(h * CELL_ASPECT))
	return Vector2i(w, h)


func _band_top() -> float:
	var arena_top: float = ART_SIZE.y * ARENA_TOP_RATIO
	var arena_bottom: float = ART_SIZE.y * _arena_bottom
	return arena_top + (arena_bottom - arena_top) * HUD_HEIGHT_RATIO


## Top-left of the board on the art canvas, in whole art-px: centred in the band between
## the HUD band and the bottom of the arena, like ScreenLayout.board_area_rect.
func _board_origin() -> Vector2i:
	var width: int = _board.x * 2 * _cell.x + DIVIDER_GAP
	var height: int = _board.y * _cell.y
	var center_y: int = int((_band_top() + ART_SIZE.y * _arena_bottom) * 0.5)
	return Vector2i((ART_SIZE.x - width) / 2, center_y - height / 2)


## Top-left of a cell. [param side] 0 = player half (left), 1 = enemy half (right); [param col]
## is the LOCAL column (0 = leftmost on screen in that half).
func _cell_origin(side: int, col: int, row: int) -> Vector2i:
	var origin: Vector2i = _board_origin()
	var x: int = origin.x + col * _cell.x + side * (_board.x * _cell.x + DIVIDER_GAP)
	return Vector2i(x, origin.y + row * _cell.y)


func _is_real(side: int, col: int, row: int) -> bool:
	return col >= 0 and col < _board.x and row >= 0 and row < _board.y \
		and not _missing[side].has(Vector2i(col, row))


## Where a unit's feet go: bottom-centre of the cell, FOOT_LIFT above the front edge.
func _anchor(side: int, col: int, row: int) -> Vector2i:
	var o: Vector2i = _cell_origin(side, col, row)
	return Vector2i(o.x + _cell.x / 2, o.y + _cell.y - GAP - FOOT_LIFT)


## BoardGrid.default_*_cell: the real cell nearest the centre of the half; ties go to the cell
## nearer the divider, then the upper one. Returned in local columns.
func _default_cell(side: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist: int = 0
	var best_near: int = 0
	for row: int in _board.y:
		for col: int in _board.x:
			if not _is_real(side, col, row):
				continue
			# Side column: distance from the far edge of the half.
			var side_col: int = col if side == 0 else _board.x - 1 - col
			var dx: int = side_col * 2 - (_board.x - 1)
			var dy: int = row * 2 - (_board.y - 1)
			var dist: int = dx * dx + dy * dy
			var better: bool = best.x < 0 or dist < best_dist
			if not better and dist == best_dist:
				better = side_col > best_near
			if better:
				best = Vector2i(col, row)
				best_dist = dist
				best_near = side_col
	return best


func _draw_board(board: Node2D) -> void:
	board.draw_rect(Rect2(Vector2.ZERO, Vector2(ART_SIZE)), GROUND)
	board.draw_rect(Rect2(0, 0, ART_SIZE.x, int(ART_SIZE.y * SKY_RATIO)), SKY)
	# Ink only under the real slabs (plus their 1 px gap), so missing cells show the ground.
	for side: int in 2:
		for col: int in _board.x:
			for row: int in _board.y:
				if _is_real(side, col, row):
					var o: Vector2i = _cell_origin(side, col, row)
					board.draw_rect(Rect2(o.x - GAP, o.y - GAP, _cell.x + GAP, _cell.y + GAP), INK)
	for side: int in 2:
		for col: int in _board.x:
			for row: int in _board.y:
				if _is_real(side, col, row):
					if _slab_tex != null:
						_draw_slab_art(board, _cell_origin(side, col, row), side, col, row)
					else:
						_draw_slab(board, _cell_origin(side, col, row))


func _load_slabs(nine_path: String, stamps_path: String) -> void:
	var nine: Image = Image.load_from_file(ProjectSettings.globalize_path(nine_path))
	var stamps: Image = Image.load_from_file(ProjectSettings.globalize_path(stamps_path))
	if nine == null or stamps == null:
		push_error("art_check: cannot load slabs %s / %s" % [nine_path, stamps_path])
		return
	_slab_tex = ImageTexture.create_from_image(nine)
	_stamp_tex = ImageTexture.create_from_image(stamps)
	var meta_path: String = stamps_path.get_basename() + ".json"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	if typeof(data) == TYPE_DICTIONARY:
		_stamps = (data as Dictionary).get("stamps", [])
		var m: Dictionary = ((data as Dictionary).get("nine_slice", {}) as Dictionary).get("margins", _slab_margins)
		_slab_margins = m
	print("art_check: slabs %s (%dx%d), %d stamps" % [nine_path, nine.get_width(), nine.get_height(), _stamps.size()])


## One slab, the whole cell (the 9-slice carries its own gap on the right and bottom): corners
## and edges keep their pixels, the flat centre stretches. Then up to one cover stamp and one
## crack per slab, chosen by the cell's seed so the board is stable between redraws.
func _draw_slab_art(board: Node2D, o: Vector2i, side: int, col: int, row: int) -> void:
	var w: int = _cell.x
	var h: int = _cell.y
	var L: int = int(_slab_margins["left"])
	var R: int = int(_slab_margins["right"])
	var Tm: int = int(_slab_margins["top"])
	var B: int = int(_slab_margins["bottom"])
	var tw: int = _slab_tex.get_width()
	var th: int = _slab_tex.get_height()
	var xs: Array = [[0, L, 0, L], [L, tw - L - R, L, w - L - R], [tw - R, R, w - R, R]]
	var ys: Array = [[0, Tm, 0, Tm], [Tm, th - Tm - B, Tm, h - Tm - B], [th - B, B, h - B, B]]
	for yy: Array in ys:
		for xx: Array in xs:
			var src := Rect2(xx[0], yy[0], xx[1], yy[1])
			var dst := Rect2(o.x + xx[2], o.y + yy[2], xx[3], yy[3])
			board.draw_texture_rect_region(_slab_tex, dst, src)
	if _stamps.is_empty():
		return
	# Face rectangle the stamps may touch: inside the light edge, above the lip, left of the gap.
	var face := Rect2i(o.x + 1, o.y + 1, w - 1 - R, h - Tm - B + 2)
	var seed_v: int = (side * 7919 + col * 104729 + row * 1299709) % 1000
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var covers: Array = _stamps.filter(func(s: Dictionary) -> bool: return s["kind"] == "cover")
	var cracks: Array = _stamps.filter(func(s: Dictionary) -> bool: return s["kind"] == "crack")
	if rng.randf() < 0.45 and not covers.is_empty():
		_draw_stamp(board, covers[rng.randi() % covers.size()], face, rng)
	if rng.randf() < 0.35 and not cracks.is_empty():
		_draw_stamp(board, cracks[rng.randi() % cracks.size()], face, rng)


func _draw_stamp(board: Node2D, stamp: Dictionary, face: Rect2i, rng: RandomNumberGenerator) -> void:
	var r: Array = stamp["rect"]
	var src := Rect2(r[0], r[1], r[2], r[3])
	var pos := Vector2i(face.position)
	match String(stamp["anchor"]):
		"top_left":
			pos = face.position
		"bottom_right":
			pos = face.end - Vector2i(int(r[2]), int(r[3]))
		"bottom_left":
			pos = Vector2i(face.position.x, face.end.y - int(r[3]))
		_:
			pos = face.position + Vector2i(rng.randi_range(1, maxi(face.size.x - int(r[2]) - 1, 1)), rng.randi_range(1, maxi(face.size.y - int(r[3]) - 1, 1)))
	board.draw_texture_rect_region(_stamp_tex, Rect2(Vector2(pos), src.size), src)


## One slab: stone face, a 1 px light edge top-left, a LIP-px front lip, an Ink gap right and below.
func _draw_slab(board: Node2D, o: Vector2i) -> void:
	var w: int = _cell.x - GAP
	var h: int = _cell.y - GAP
	board.draw_rect(Rect2(o.x, o.y, w, h - LIP), STONE)
	board.draw_rect(Rect2(o.x, o.y, w, 1), STONE_LIGHT)
	board.draw_rect(Rect2(o.x, o.y, 1, h - LIP), STONE_LIGHT)
	board.draw_rect(Rect2(o.x, o.y + h - LIP, w, LIP), LIP_COLOR)


func _place_units() -> void:
	var hero: Vector2i = _default_cell(0)
	var goblin: Vector2i = _default_cell(1)
	if not _anim.is_empty():
		var clip: Dictionary = CLIPS[_anim]
		_add_anim_unit(HERO_DIR, clip["hero"], 0, hero.x, hero.y)
		_add_anim_unit(GOBLIN_DIR, clip["goblin"], 1, goblin.x, goblin.y)
		_anim_shots_left = (clip["hero"] as Array).size() if not _shot.is_empty() else 0
		return
	_add_unit(HERO_PNG, 0, hero.x, hero.y)
	if not _wall_png.is_empty():
		# Wall one cell ahead of the hero (toward the divider) and one row up, so it overlaps a
		# unit behind it; thorns on the floor beside the goblin.
		var wall_col: int = mini(hero.x + 1, _board.x - 1)
		var wall_row: int = maxi(hero.y - 1, 0)
		if _is_real(0, wall_col, wall_row):
			_add_unit(_wall_png, 0, wall_col, wall_row)
		# A second hero-side unit behind the wall to show the overlap: the goblin sprite stands in.
		if _is_real(0, wall_col, wall_row - 1):
			_add_unit(GOBLIN_PNG, 0, wall_col, wall_row - 1)
		var th_col: int = maxi(goblin.x - 1, 0)
		if _is_real(1, th_col, goblin.y):
			_add_floor_prop(_thorns_png, 1, th_col, goblin.y)
	match _mode:
		"rows":
			# Three adjacent real rows in the goblin's column, as close to its row as possible.
			var placed: int = 0
			var start: int = clampi(goblin.y - 1, 0, maxi(_board.y - 3, 0))
			for row: int in range(start, _board.y):
				if _is_real(1, goblin.x, row) and placed < 3:
					_add_unit(GOBLIN_PNG, 1, goblin.x, row)
					placed += 1
			if placed < 3:
				print("art_check: only %d adjacent real rows in column %d" % [placed, goblin.x])
		_:
			_add_unit(GOBLIN_PNG, 1, goblin.x, goblin.y)
	if _mode == "blackout":
		_units.modulate = INK


func _add_unit(path: String, side: int, col: int, row: int) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		push_error("art_check: cannot load %s" % path)
		return
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = Vector2(-image.get_width() / 2, -image.get_height())
	sprite.position = Vector2(_anchor(side, col, row))
	_units.add_child(sprite)


## A floor decal (thorns): drawn under the units, bottom-centre anchored like a unit.
func _add_floor_prop(path: String, side: int, col: int, row: int) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		push_error("art_check: cannot load %s" % path)
		return
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = Vector2(-image.get_width() / 2, -image.get_height())
	sprite.position = Vector2(_anchor(side, col, row))
	# Floor layer: a sibling drawn before Units.
	var floor_layer: Node = _units.get_parent().get_node_or_null("Floor")
	if floor_layer == null:
		floor_layer = Node2D.new()
		floor_layer.name = "Floor"
		_units.get_parent().add_child(floor_layer)
		_units.get_parent().move_child(floor_layer, _units.get_index())
	floor_layer.add_child(sprite)


## A unit that cycles through [param names] (frame files of one candidate folder). All frames of a
## unit share one canvas size, so the bottom-centre anchor never moves between frames.
func _add_anim_unit(pattern: String, names: Array, side: int, col: int, row: int) -> void:
	var textures: Array = []
	for n: String in names:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(pattern % n))
		if image == null:
			push_error("art_check: cannot load %s" % (pattern % n))
			return
		textures.append(ImageTexture.create_from_image(image))
	var first: Image = (textures[0] as ImageTexture).get_image()
	var sprite := Sprite2D.new()
	sprite.texture = textures[0]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = Vector2(-first.get_width() / 2, -first.get_height())
	sprite.position = Vector2(_anchor(side, col, row))
	_units.add_child(sprite)
	_anim_sprites.append(sprite)
	_anim_textures.append(textures)


## Flat placeholder HUD at screen resolution: the zones of design/ux/hud.md with the sizes of
## ScreenLayout and art bible §7.4, no real widgets. Only here so the units can be judged next
## to the bars, the pad and the slots.
func _draw_hud(hud: Node2D) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var font: Font = ThemeDB.fallback_font
	var margin: float = vp.x * MARGIN_RATIO
	# Z1: everything inside 3–8 % of the height (hud.md), 8–14 % left free for the back-row heads.
	var z1_top: float = vp.y * 0.03
	var bar_h: float = 14.0
	var bar_w: float = vp.x * 0.34
	var bar_y: float = z1_top + 8.0
	hud.draw_rect(Rect2(margin, bar_y, bar_w, bar_h), INK)
	hud.draw_rect(Rect2(margin + 1, bar_y + 1, (bar_w - 2) * 0.85, bar_h - 2), HP_PLAYER)
	hud.draw_string(font, Vector2(margin, bar_y + bar_h + 16), "YOU 170/200", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
	hud.draw_rect(Rect2(vp.x - margin - bar_w, bar_y, bar_w, bar_h), INK)
	hud.draw_rect(Rect2(vp.x - margin - bar_w + 1, bar_y + 1, bar_w - 2, bar_h - 2), HP_BOSS)
	hud.draw_string(font, Vector2(vp.x - margin - bar_w, bar_y + bar_h + 16), "GOBLIN SCOUT 60/60", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
	hud.draw_rect(Rect2(vp.x * 0.5 - 16, z1_top + 2, 32, 32), INK, false, 2.0)  # pause, 32 px (7.7)
	if _layout == "v2":
		_draw_controls_v2(hud, vp, font, margin)
	else:
		_draw_controls_v1(hud, vp, font, margin)
	# Z2 band markers: top (under Z1) and bottom (arena bottom).
	var z2_top: float = vp.y * (ARENA_TOP_RATIO + (_arena_bottom - ARENA_TOP_RATIO) * HUD_HEIGHT_RATIO)
	hud.draw_dashed_line(Vector2(margin, z2_top), Vector2(vp.x - margin, z2_top), HUD_FRAME, 1.0, 8.0)
	var label: String = "Z2 board band"
	if not _arena_id.is_empty():
		label += "  arena=%s %dx%d  cell %dx%d" % [_arena_id, _board.x, _board.y, _cell.x, _cell.y]
	hud.draw_string(font, Vector2(margin, z2_top - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HUD_FRAME)
	var z2_bottom: float = vp.y * _arena_bottom
	hud.draw_dashed_line(Vector2(margin, z2_bottom), Vector2(vp.x - margin, z2_bottom), HUD_FRAME, 1.0, 8.0)
	if _layout == "v2" and _arena_bottom > _controls_top + 0.001:
		var ct: float = vp.y * _controls_top
		hud.draw_dashed_line(Vector2(margin, ct), Vector2(vp.x - margin, ct), Color(HUD_FRAME, 0.5), 1.0, 4.0)
		hud.draw_string(font, Vector2(vp.x * 0.42, ct - 4), "controls top 64 %%  /  board band to %d %%" % int(round(_arena_bottom * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HUD_FRAME)


## The shipped layout: fixed 3x3 d-pad, three straight slots, controls below 55 %.
func _draw_controls_v1(hud: Node2D, vp: Vector2, font: Font, margin: float) -> void:
	# Art bible §7.2: dark backgrounds ONLY on the touch targets; the rest stays transparent.
	var band_top: float = vp.y * ARENA_BOTTOM_RATIO
	var band_mid: float = band_top + (vp.y - band_top) * 0.5
	# Z3: d-pad, DPAD_BUTTON_RATIO 0.135 of the height per button.
	var b: float = vp.y * 0.135
	var g: float = vp.y * 0.008
	var cx: float = margin + b * 1.5 + g
	for d: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var p := Vector2(cx, band_mid) + d * (b + g) - Vector2(b, b) * 0.5
		_touch_target(hud, Rect2(p, Vector2(b, b)))
	hud.draw_string(font, Vector2(cx - 24, band_mid + 6), "Z3", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
	# Z5: three hold slots, SLOT_HEIGHT_RATIO 0.22, aspect 1.4, gap 0.02.
	var sh: float = vp.y * 0.22
	var sw: float = sh / 1.4
	var sg: float = vp.y * 0.02
	var sx: float = vp.x - margin - (sw * 3 + sg * 2)
	for i: int in 3:
		_touch_target(hud, Rect2(sx + i * (sw + sg), band_mid - sh * 0.5, sw, sh))
	hud.draw_string(font, Vector2(sx, band_mid - sh * 0.5 - 8), "Z5 bag", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
	# Z4: the signature button (2x2 cells), centred.
	var sig: float = vp.y * 0.16
	_touch_target(hud, Rect2(vp.x * 0.5 - sig * 0.5, band_mid - sig * 0.5, sig, sig))
	hud.draw_string(font, Vector2(vp.x * 0.5 - 50, band_mid + sig * 0.5 + 20), "Z4 Awaken", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)


## The 2026-10-31 sketch: a floating 4-way joystick in the left thumb zone (drawn here as if the
## thumb were down at its home spot), three slots on an arc around the right thumb's pivot,
## the Awaken button low in the middle, arena down to 64 %.
func _draw_controls_v2(hud: Node2D, vp: Vector2, font: Font, margin: float) -> void:
	# Z3 home zone: 0–25 % of the width, from the controls top (64 %) to the screen bottom
	# (dashed, invisible in game). It never reaches the board's full-width rows.
	var zone := Rect2(0, vp.y * _controls_top, vp.x * _stick_zone_w, vp.y * (1.0 - _controls_top))
	hud.draw_dashed_line(Vector2(zone.end.x, zone.position.y), zone.end, HUD_FRAME, 1.0, 8.0)
	hud.draw_string(font, Vector2(margin, zone.position.y + 18), "Z3 joystick zone", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HUD_FRAME)
	# Floating stick where a resting thumb lands: base 160 px, knob 88 px, pushed right (a step).
	var base_r: float = 80.0
	var knob_r: float = 44.0
	var center := Vector2(margin + 150.0, vp.y * 0.80)
	hud.draw_circle(center, base_r, Color(HUD_DARK, 0.6))
	hud.draw_arc(center, base_r, 0.0, TAU, 48, HUD_FRAME, 2.0)
	for d: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		hud.draw_line(center + d * (base_r - 14.0), center + d * (base_r - 4.0), HUD_FRAME, 3.0)
	var knob := center + Vector2(base_r * 0.55, 0)
	hud.draw_circle(knob, knob_r, Color(HUD_DARK, 0.95))
	hud.draw_arc(knob, knob_r, 0.0, TAU, 40, IVORY, 2.0)
	# Z5: three slots 18 % tall (aspect 1.4) on an arc around the right thumb's pivot (bottom-right
	# corner, inset), angles 100°, 128°, 156° from +x: T1 high-right, T3 low-left, 28° apart so
	# the 130x93 px slots never touch.
	var sh: float = vp.y * 0.18
	var sw: float = sh / 1.4
	var pivot := Vector2(vp.x - margin * 0.5, vp.y + sh * 0.35)
	var radius: float = sh * 2.0
	var i: int = 0
	for deg: float in [100.0, 128.0, 156.0]:
		var c: Vector2 = pivot + Vector2(cos(deg_to_rad(deg)), -sin(deg_to_rad(deg))) * radius
		var r := Rect2(c - Vector2(sw, sh) * 0.5, Vector2(sw, sh))
		_touch_target(hud, r)
		hud.draw_string(font, r.position + Vector2(8, 22), "T%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
		i += 1
	hud.draw_string(font, Vector2(vp.x * 0.78, vp.y * _controls_top + 18), "Z5 bag (arc)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HUD_FRAME)
	# Z4: Awaken button 115 px, low centre.
	var sig: float = vp.y * 0.16
	var sig_rect := Rect2(vp.x * 0.5 - sig * 0.5, vp.y - margin * 0.5 - sig, sig, sig)
	_touch_target(hud, sig_rect)
	hud.draw_string(font, Vector2(sig_rect.position.x - 4, sig_rect.position.y - 8), "Z4 Awaken", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)


## A touch target per §7.2: dark fill only under the button, 1 px frame.
func _touch_target(hud: Node2D, rect: Rect2) -> void:
	hud.draw_rect(rect, Color(HUD_DARK, 0.85))
	hud.draw_rect(rect, HUD_FRAME, false, 2.0)


func _draw() -> void:
	draw_rect(get_viewport_rect(), INK)


func _process(delta: float) -> void:
	if not _anim.is_empty():
		_tick_anim(delta)
		return
	if _shot.is_empty():
		return
	_frames += 1
	if _frames == SHOT_FRAME:
		_capture(_shot)


## Advance every animated unit together; with --shot, save one picture per frame index
## (shot path with "-<index>" before the extension) and quit after a full cycle.
func _tick_anim(delta: float) -> void:
	_frames += 1
	if _frames < SHOT_FRAME or _capturing:
		return
	var hold: float = CLIPS[_anim]["hold"]
	_anim_time += delta
	var first_frame: bool = _frames == SHOT_FRAME
	if not first_frame and _anim_time < hold:
		return
	if not first_frame:
		_anim_time = 0.0
		_anim_index += 1
		for i: int in _anim_sprites.size():
			var textures: Array = _anim_textures[i]
			_anim_sprites[i].texture = textures[_anim_index % textures.size()]
	if _anim_shots_left > 0:
		_capturing = true
		var path: String = _shot.get_basename() + ("-%d." % _anim_index) + _shot.get_extension()
		await _capture(path, false)
		_anim_shots_left -= 1
		_capturing = false
		if _anim_shots_left == 0:
			get_tree().quit()


func _capture(path: String, quit: bool = true) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(path)
	print("art_check: mode=%s anim=%s arena=%s board=%s cell=%s scale=%d hud=%s layout=%s shot=%s (%s)" % [_mode, _anim, _arena_id, _board, _cell, _scale, _hud, _layout, path, error_string(err)])
	if quit:
		get_tree().quit()

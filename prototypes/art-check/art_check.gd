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
##   --bg=<far.png>[,<near.png>]  800x360 backdrop layers (ASSET-005): far under everything,
##                    near = mist band over the horizon strip; replaces the flat sky/ground fill
##   --props=<wall.png>,<thorns.png>  place the Wall one cell ahead of the hero (unit layer, a
##                    second unit behind it shows the overlap) and the Thorns on the floor beside
##                    the goblin
##   --ui=<dir>       ASSET-013 frames + ASSET-015 icon sheet (res:// folder): the HUD placeholder
##                    rects become the real 9-slice slots / button / bars / pause drawn at 2x, with
##                    icons; the zone labels and dashed markers are hidden so the HUD can be judged
##   --fx=<dir>       ASSET-008 steel tiles, ASSET-011 marks, ASSET-012 stripe and ASSET-009 slash
##                    sheet (res:// folder) shown on the board: telegraph on the hero's cell and the
##                    cell below (stripes on the floor, red frame + Ink edge on the overlay), cast
##                    target tiles under the goblin (70 %) and below it (100 %) with the steel mark and
##                    raised edge, a lying T block of 5x5 tiles beside the hero (hover 2 px + shadow),
##                    a falling 16x16 domino over the enemy half, slash frame 3 tinted steel on the
##                    target tiles
##   --seq=slash|push the cast sequence as keyframes on top of --fx: hero idle while the target
##                    tiles ramp 35 → 100 %, cast gesture A/B, the steel domino falls onto the lower
##                    target tile, the VFX sheet plays on both tiles, the goblin takes the hit frame
##                    with a flash, rest. With --shot one PNG per keyframe (<shot>-<i>.png) and
##                    <shot>.json with the durations in centiseconds for tools/make_gif.py
##   --skin=osfe      STYLE TEST (2026-10-31): the HUD drawn sharp at 1280x720 in the UI language of
##                    One Step From Eden instead of the pixel 9-slices: navy panels with 45-degree
##                    chamfers, diamond badges for numbers, segmented Engraving bar, white sans text
##                    with a dark outline, HP plates under the units, slot cards with cost badges.
##                    Layout v2 geometry is kept; --ui is ignored while the skin is on
##   --floor=tessera  the same construction in the Misty Forest palette (art bible §4/§6: moss-grey
##                    face S<=30 V<=55, lighter moss line, dark lip; NO side colours, the divider
##                    tells the halves apart)
##   --floor=osfe     STYLE TEST: flat dark tiles in OSFE's language instead of the stone slabs:
##                    navy face, 1 px inner line (cool on the player half, warm on the enemy half,
##                    both low saturation), 1 px top highlight, 2 px Ink gap; the backdrop stays
##   --font=<semibold.ttf>[,<bold.ttf>]  system font files for the --skin text (art bible §7.3:
##                    names SemiBold, numbers Bold); without it Godot's fallback font is used
##   --icons=<png>    icon sheet for the --skin HUD (JSON index beside it, cells drawn 1:1): the
##                    pause button, an info button, status chips under the goblin, the Awaken glyph
##   --band-top=R     top of the board band as a ratio of the height (default = the HUD band of
##                    ScreenLayout, 0.03 + 20 % of the arena); 0.20 leaves the top fifth to the scenery
##   --platform       STYLE TEST (option B, 2026-10-31): the board sits on a raised stone platform
##                    drawn by code — deck 6 px around the slabs (the divider gap shows deck stone
##                    with a thin line), front face 12 px below the last row with a light top edge,
##                    4 px shadow on the ground. Rectangular only; shaped arenas need edge pieces
##   --mist-bottom=N  art-px row where the --bg near layer's bottom sits (default BG_MIST_BOTTOM 47;
##                    the v2 backdrop uses 70, inside the 20 % scenery strip)
##   --tele-k=K       telegraph intensity 0..1 (user 2026-10-31: no countdown label; the enemy's
##                    damage tiles start faint and darken until full, then the hit lands): stripes
##                    at alpha 0.5→1, flat red fill 0→0.45, frame 0.3→1
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
## Where the ASSET-005 mist band's bottom row sits on the art canvas (horizon 44 + 2).
const BG_MIST_BOTTOM := 47

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
## ASSET-014: the damage trail behind the fill (no red).
const HP_TRAIL := Color("B8B0A0")
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
## --skin: "" = the pixel 9-slice HUD (or flat placeholders), "osfe" = the sharp-UI style test.
var _skin: String = ""
## --floor: "" = slabs (art or placeholder), "osfe" = flat tiles style test.
var _floor: String = ""
var _platform: bool = false
var _tele_k: float = 1.0
const DECK_MARGIN := 6
const FACE_H := 12
## Platform colours = the slab v2 palette: deck one tone under the slab face, face = lip tone.
const DECK := Color("3A3B37")
const DECK_LIGHT := Color("5A5B54")
const DECK_LIP := Color("262521")
var _font_semi: Font
var _font_bold: Font
var _skin_icons: ImageTexture
var _skin_icon_index: Dictionary = {}
const TILE_FACE := Color("1B2130")
const TILE_FACE_ENEMY := Color("231F2C")
const TILE_LINE_PLAYER := Color("3E5578")
const TILE_LINE_ENEMY := Color("6E4A52")
const TILE_TOP := Color("4A5B7A")
const TILE_TOP_ENEMY := Color("7A5A60")
const TILE_LIP := Color("0E1320")
const MF_FACE := Color("30352F")
const MF_LINE := Color("4B5648")
const MF_TOP := Color("5E6B55")
const MF_LIP := Color("1B1F1A")
const TILE_LIP_ENEMY := Color("150F18")
## Top-left of the 2x art canvas on the window, for HUD elements that follow a unit.
var _screen_origin: Vector2 = Vector2.ZERO
const UI_NAVY := Color("1E1B24")   # Đá Đêm (art bible §4), was OSFE navy 1C2233
const UI_NAVY_LIGHT := Color("2B2735")
const UI_NAVY_DEEP := Color("15131A")
const UI_LINE := Color("7D8896")   # Sương, the §7.4 frame colour
const UI_TEXT := Color("F4F6FA")
const UI_OUTLINE := Color("0F1219")
const UI_GOLD := Color("FFD45C")
const UI_GREEN := Color("58D468")
var _arena_bottom: float = ARENA_BOTTOM_RATIO
var _band_top_ratio: float = -1.0
var _mist_bottom: int = BG_MIST_BOTTOM
## Where the v2 controls start (the thumb zones); the board band may run below it when its
## lower rows are narrow enough to pass between the thumbs (--arena-bottom).
var _controls_top: float = 0.64
## Width of the v2 joystick home zone as a ratio of the screen width.
var _stick_zone_w: float = 0.25
var _shot: String = ""
var _frames: int = 0
var _units: Node2D
## --bg: "<far.png>,<near.png>" 800x360 backdrop layers (far drawn under everything, centred so the
## 640 play area shows; near = mist band drawn over the slabs' top rows at the horizon).
var _bg_far: ImageTexture
var _bg_near: ImageTexture
## --props: "<wall.png>,<thorns.png>"; the wall stands on the player's cell one column toward the
## divider (unit layer, y-sorted like a unit), the thorns lie on the goblin's neighbour cell (floor).
var _wall_png: String = ""
var _thorns_png: String = ""
## --ui=<dir>: ASSET-013 frames and the ASSET-015 icon sheet, drawn x2 on the HUD layer instead of
## the flat placeholder rects (slots, pad, Awaken, pause, bars).
var _ui_dir: String = ""
var _ui_tex: Dictionary = {}
var _ui_icons: Dictionary = {}
## --fx=<dir>: slice-1 floor/VFX candidates (see the header) drawn on a floor layer under the
## units and an overlay layer above them, so the §8.6 layer order can be judged.
var _fx_dir: String = ""
var _fx_tex: Dictionary = {}
var _fx_meta: Dictionary = {}
var _fx_floor: Node2D
var _fx_over: Node2D
## --seq state: keyframes (see _build_seq), the current one, the two sequence units and the
## values the fx layers read while a sequence runs.
const SEQ_HERO_FRAMES: Array[String] = ["idle-A", "idle-B", "cast-A", "cast-B"]
const SEQ_GOBLIN_FRAMES: Array[String] = ["idle-A", "idle-B", "hit"]
var _seq: String = ""
var _seq_steps: Array = []
var _seq_i: int = -1
var _seq_time: float = 0.0
var _seq_hero: Sprite2D
var _seq_goblin: Sprite2D
var _seq_state: Dictionary = {"k": 0.0, "dy": -1000.0, "vf": -1, "flash": false}
const STEEL := Color("8FA3B8")
const STEEL_HI := Color("EEF4FA")
const STEEL_LO := Color("5F6F82")
const TELEGRAPH_RED := Color("E5293B")
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
	if _has_fx():
		_fx_floor = Node2D.new()
		_fx_floor.name = "FxFloor"
		_fx_floor.draw.connect(_draw_fx_floor.bind(_fx_floor))
		viewport.add_child(_fx_floor)
		viewport.move_child(_fx_floor, _units.get_index())
		_fx_over = Node2D.new()
		_fx_over.name = "FxOverlay"
		_fx_over.draw.connect(_draw_fx_overlay.bind(_fx_over))
		viewport.add_child(_fx_over)
	if not _seq.is_empty() and not _has_fx():
		push_error("art_check: --seq needs --fx")
		_seq = ""

	var screen := Sprite2D.new()
	screen.name = "Screen"
	screen.texture = viewport.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.centered = false
	screen.scale = Vector2(_scale, _scale)
	var shown: Vector2 = Vector2(ART_SIZE) * _scale
	screen.position = ((get_viewport_rect().size - shown) * 0.5).floor()
	_screen_origin = screen.position
	add_child(screen)
	board.queue_redraw()

	if _hud:
		var hud := Node2D.new()
		hud.name = "Hud"
		hud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
		elif arg.begins_with("--bg="):
			var bp: PackedStringArray = arg.trim_prefix("--bg=").split(",")
			if bp.size() >= 1:
				var far: Image = Image.load_from_file(ProjectSettings.globalize_path(bp[0]))
				if far != null:
					_bg_far = ImageTexture.create_from_image(far)
			if bp.size() >= 2 and not bp[1].is_empty():
				var near: Image = Image.load_from_file(ProjectSettings.globalize_path(bp[1]))
				if near != null:
					_bg_near = ImageTexture.create_from_image(near)
		elif arg.begins_with("--ui="):
			_ui_dir = arg.trim_prefix("--ui=")
			_load_ui()
		elif arg.begins_with("--fx="):
			_fx_dir = arg.trim_prefix("--fx=")
			_load_fx()
		elif arg.begins_with("--seq="):
			_seq = arg.trim_prefix("--seq=")
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
		elif arg.begins_with("--skin="):
			_skin = arg.trim_prefix("--skin=")
		elif arg.begins_with("--floor="):
			_floor = arg.trim_prefix("--floor=")
		elif arg == "--platform":
			_platform = true
		elif arg.begins_with("--tele-k="):
			_tele_k = clampf(arg.trim_prefix("--tele-k=").to_float(), 0.0, 1.0)
		elif arg.begins_with("--icons="):
			var ip: String = arg.trim_prefix("--icons=")
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(ip))
			if img != null:
				_skin_icons = ImageTexture.create_from_image(img)
			var jf := FileAccess.open(ip.get_basename() + ".json", FileAccess.READ)
			if jf != null:
				var data: Variant = JSON.parse_string(jf.get_as_text())
				if data is Dictionary and data.has("icons"):
					_skin_icon_index = data["icons"]
		elif arg.begins_with("--font="):
			var fp: PackedStringArray = arg.trim_prefix("--font=").split(",")
			_font_semi = _load_font(fp[0])
			_font_bold = _load_font(fp[1]) if fp.size() > 1 else _font_semi
	if _layout == "v2":
		_arena_bottom = _controls_top
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mist-bottom="):
			_mist_bottom = arg.trim_prefix("--mist-bottom=").to_int()
		if arg.begins_with("--band-top="):
			_band_top_ratio = clampf(arg.trim_prefix("--band-top=").to_float(), 0.05, 0.6)
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
	if _band_top_ratio > 0.0:
		return ART_SIZE.y * _band_top_ratio
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
	if _bg_far != null:
		# 800-wide layer centred on the 640 canvas: the outer 80 px are the wide-screen margins.
		var off: int = (ART_SIZE.x - _bg_far.get_width()) / 2
		board.draw_texture(_bg_far, Vector2(off, 0))
	else:
		board.draw_rect(Rect2(Vector2.ZERO, Vector2(ART_SIZE)), GROUND)
		board.draw_rect(Rect2(0, 0, ART_SIZE.x, int(ART_SIZE.y * SKY_RATIO)), SKY)
	if _platform:
		_draw_platform(board)
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
					if _floor == "osfe" or _floor == "tessera":
						_draw_tile_osfe(board, _cell_origin(side, col, row), side)
					elif _slab_tex != null:
						_draw_slab_art(board, _cell_origin(side, col, row), side, col, row)
					else:
						_draw_slab(board, _cell_origin(side, col, row))
	if _bg_near != null:
		# Mist band: its bottom sits BG_MIST_BOTTOM (horizon row + 2) so it lies on the feet of the
		# far scene over the sky, above the board; drawn once, no drift in a still capture.
		var off: int = (ART_SIZE.x - _bg_near.get_width()) / 2
		var y: int = _mist_bottom - _bg_near.get_height()
		board.draw_texture(_bg_near, Vector2(off, y))


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
	if not _seq.is_empty():
		_add_anim_unit(HERO_DIR, SEQ_HERO_FRAMES, 0, hero.x, hero.y)
		_seq_hero = _anim_sprites[_anim_sprites.size() - 1]
		_add_anim_unit(GOBLIN_DIR, SEQ_GOBLIN_FRAMES, 1, goblin.x, goblin.y)
		_seq_goblin = _anim_sprites[_anim_sprites.size() - 1]
		_build_seq()
		return
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
	if _skin == "osfe":
		_draw_hud_osfe(hud, _font_semi if _font_semi != null else font, margin)
		return
	# Z1: everything inside 3–8 % of the height (hud.md), 8–14 % left free for the back-row heads.
	var z1_top: float = vp.y * 0.03
	var bar_h: float = 12.0 if _has_ui() else 14.0
	var bar_w: float = vp.x * 0.34
	var bar_y: float = z1_top + 8.0
	if _has_ui():
		# ASSET-013 bar frame + ASSET-014 fills: player green with a grey trail, boss Ivory with
		# the half-life notch; pause = panel 32x32 with the pause icon.
		_draw_bar(hud, Rect2(margin, bar_y, bar_w, bar_h), 0.85, HP_PLAYER, 0.93, false)
		_draw_bar(hud, Rect2(vp.x - margin - bar_w, bar_y, bar_w, bar_h), 1.0, HP_BOSS, 1.0, true)
		_draw_nine(hud, _ui_tex["panel"], Rect2(0, 0, 16, 16), Rect2(vp.x * 0.5 - 16, z1_top + 2, 32, 32), [4, 4, 4, 6], 2)
		_draw_icon(hud, "pause", Vector2(vp.x * 0.5 - 12, z1_top + 5))
	else:
		hud.draw_rect(Rect2(margin, bar_y, bar_w, bar_h), INK)
		hud.draw_rect(Rect2(margin + 1, bar_y + 1, (bar_w - 2) * 0.85, bar_h - 2), HP_PLAYER)
		hud.draw_rect(Rect2(vp.x - margin - bar_w, bar_y, bar_w, bar_h), INK)
		hud.draw_rect(Rect2(vp.x - margin - bar_w + 1, bar_y + 1, bar_w - 2, bar_h - 2), HP_BOSS)
		hud.draw_rect(Rect2(vp.x * 0.5 - 16, z1_top + 2, 32, 32), INK, false, 2.0)  # pause, 32 px (7.7)
	hud.draw_string_outline(font, Vector2(margin, bar_y + bar_h + 16), "YOU 170/200", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 2, INK)
	hud.draw_string(font, Vector2(margin, bar_y + bar_h + 16), "YOU 170/200", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
	hud.draw_string_outline(font, Vector2(vp.x - margin - bar_w, bar_y + bar_h + 16), "GOBLIN SCOUT 60/60", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 2, INK)
	hud.draw_string(font, Vector2(vp.x - margin - bar_w, bar_y + bar_h + 16), "GOBLIN SCOUT 60/60", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
	if _layout == "v2":
		_draw_controls_v2(hud, vp, font, margin)
	else:
		_draw_controls_v1(hud, vp, font, margin)
	# Z2 band markers: top (under Z1) and bottom (arena bottom). Debug only, hidden with --ui.
	if _has_ui():
		return
	var z2_top: float = vp.y * (ARENA_TOP_RATIO + (_arena_bottom - ARENA_TOP_RATIO) * HUD_HEIGHT_RATIO)
	hud.draw_dashed_line(Vector2(margin, z2_top), Vector2(vp.x - margin, z2_top), HUD_FRAME, 1.0, 8.0)
	var label: String = "Z2 board band"
	if not _arena_id.is_empty():
		label += "  arena=%s %dx%d  cell %dx%d" % [_arena_id, _board.x, _board.y, _cell.x, _cell.y]
	hud.draw_string_outline(font, Vector2(margin, z2_top - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 2, INK)
	hud.draw_string(font, Vector2(margin, z2_top - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HUD_FRAME)
	var z2_bottom: float = vp.y * _arena_bottom
	hud.draw_dashed_line(Vector2(margin, z2_bottom), Vector2(vp.x - margin, z2_bottom), HUD_FRAME, 1.0, 8.0)
	if _layout == "v2" and _arena_bottom > _controls_top + 0.001:
		var ct: float = vp.y * _controls_top
		hud.draw_dashed_line(Vector2(margin, ct), Vector2(vp.x - margin, ct), Color(HUD_FRAME, 0.5), 1.0, 4.0)
		hud.draw_string_outline(font, Vector2(vp.x * 0.42, ct - 4), "controls top 64 %%  /  board band to %d %%" % int(round(_arena_bottom * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 2, INK)
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
	var pad: Dictionary = {"arrow_up": Vector2(0, -1), "arrow_down": Vector2(0, 1), "arrow_left": Vector2(-1, 0), "arrow_right": Vector2(1, 0)}
	for icon_name: String in pad:
		var dir: Vector2 = pad[icon_name]
		var p := Vector2(cx, band_mid) + dir * (b + g) - Vector2(b, b) * 0.5
		_touch_target(hud, Rect2(p, Vector2(b, b)), icon_name)
	if not _has_ui():
		hud.draw_string_outline(font, Vector2(cx - 24, band_mid + 6), "Z3", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 2, INK)
		hud.draw_string(font, Vector2(cx - 24, band_mid + 6), "Z3", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
	# Z5: three hold slots, SLOT_HEIGHT_RATIO 0.22, aspect 1.4, gap 0.02.
	var sh: float = vp.y * 0.22
	var sw: float = sh / 1.4
	var sg: float = vp.y * 0.02
	var sx: float = vp.x - margin - (sw * 3 + sg * 2)
	for i: int in 3:
		_touch_target(hud, Rect2(sx + i * (sw + sg), band_mid - sh * 0.5, sw, sh), "slot")
	# Z4: the signature button (2x2 cells), centred.
	var sig: float = vp.y * 0.16
	_touch_target(hud, Rect2(vp.x * 0.5 - sig * 0.5, band_mid - sig * 0.5, sig, sig), "awakening")
	if not _has_ui():
		hud.draw_string_outline(font, Vector2(sx, band_mid - sh * 0.5 - 8), "Z5 bag", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 2, INK)
		hud.draw_string(font, Vector2(sx, band_mid - sh * 0.5 - 8), "Z5 bag", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
		hud.draw_string_outline(font, Vector2(vp.x * 0.5 - 50, band_mid + sig * 0.5 + 20), "Z4 Awaken", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 2, INK)
		hud.draw_string(font, Vector2(vp.x * 0.5 - 50, band_mid + sig * 0.5 + 20), "Z4 Awaken", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)


## The 2026-10-31 sketch: a floating 4-way joystick in the left thumb zone (drawn here as if the
## thumb were down at its home spot), three slots on an arc around the right thumb's pivot,
## the Awaken button low in the middle, arena down to 64 %.
func _draw_controls_v2(hud: Node2D, vp: Vector2, font: Font, margin: float) -> void:
	# Z3 home zone: 0–25 % of the width, from the controls top (64 %) to the screen bottom
	# (dashed, invisible in game). It never reaches the board's full-width rows.
	var zone := Rect2(0, vp.y * _controls_top, vp.x * _stick_zone_w, vp.y * (1.0 - _controls_top))
	if not _has_ui():
		hud.draw_dashed_line(Vector2(zone.end.x, zone.position.y), zone.end, HUD_FRAME, 1.0, 8.0)
		hud.draw_string_outline(font, Vector2(margin, zone.position.y + 18), "Z3 joystick zone", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 2, INK)
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
		_touch_target(hud, r, "slot")
		if not _has_ui():
			hud.draw_string(font, r.position + Vector2(8, 22), "T%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)
		i += 1
	# Z4: Awaken button 115 px, low centre.
	var sig: float = vp.y * 0.16
	var sig_rect := Rect2(vp.x * 0.5 - sig * 0.5, vp.y - margin * 0.5 - sig, sig, sig)
	_touch_target(hud, sig_rect, "awakening")
	if not _has_ui():
		hud.draw_string_outline(font, Vector2(vp.x * 0.78, vp.y * _controls_top + 18), "Z5 bag (arc)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 2, INK)
		hud.draw_string(font, Vector2(vp.x * 0.78, vp.y * _controls_top + 18), "Z5 bag (arc)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HUD_FRAME)
		hud.draw_string_outline(font, Vector2(sig_rect.position.x - 4, sig_rect.position.y - 8), "Z4 Awaken", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 2, INK)
		hud.draw_string(font, Vector2(sig_rect.position.x - 4, sig_rect.position.y - 8), "Z4 Awaken", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, IVORY)


## A touch target per §7.2: dark fill only under the button, 1 px frame. With --ui, `kind` picks
## the ASSET-013 frame ("slot" = the recessed slot with the plus icon; anything else = the button
## in its default state with that icon name from ASSET-015, the Awaken icon at x4).
func _touch_target(hud: Node2D, rect: Rect2, kind: String = "") -> void:
	if not _has_ui():
		hud.draw_rect(rect, Color(HUD_DARK, 0.85))
		hud.draw_rect(rect, HUD_FRAME, false, 2.0)
		return
	var r := Rect2(rect.position.floor(), rect.size.floor())
	if kind == "slot":
		_draw_nine(hud, _ui_tex["slot"], Rect2(0, 0, 16, 16), r, [3, 3, 3, 3], 2)
		_draw_icon(hud, "plus", (r.get_center() - Vector2(12, 12)).floor())
	else:
		_draw_nine(hud, _ui_tex["button"], Rect2(0, 0, 16, 16), r, [4, 4, 4, 6], 2)
		# §7.4 icons are 12x12 (24 px); on buttons of 88 px and more the glyph is drawn x4 (48 px)
		var k: int = 4 if minf(r.size.x, r.size.y) >= 88.0 else 2
		# centred in the face above the 2 art-px lip
		_draw_icon(hud, kind, (r.get_center() - Vector2(6 * k, 6 * k + 2)).floor(), k)


func _has_ui() -> bool:
	return _ui_tex.has("slot") and _ui_tex.has("button") and _ui_tex.has("bar") and _ui_tex.has("panel") and _ui_tex.has("icons")


## --ui: the four ASSET-013 frames and the ASSET-015 sheet + JSON index from one folder.
func _load_ui() -> void:
	for frame_name: String in ["panel", "button", "slot", "bar"]:
		var suffix: String = "3slice" if frame_name == "bar" else "9slice"
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path("%s/ASSET-013-ui_frame_%s_%s.png" % [_ui_dir, frame_name, suffix]))
		if img != null:
			_ui_tex[frame_name] = ImageTexture.create_from_image(img)
	var icons: Image = Image.load_from_file(ProjectSettings.globalize_path(_ui_dir + "/ASSET-015-ui_icons_12.png"))
	if icons != null:
		_ui_tex["icons"] = ImageTexture.create_from_image(icons)
	var f := FileAccess.open(_ui_dir + "/ASSET-015-ui_icons_12.json", FileAccess.READ)
	if f != null:
		var data: Variant = JSON.parse_string(f.get_as_text())
		if data is Dictionary and data.has("icons"):
			_ui_icons = data["icons"]
	if not _has_ui():
		push_error("art_check: --ui folder incomplete: " + _ui_dir)


## Nine-slice at integer scale k: corners keep their pixels, edges stretch along one axis, the
## centre fills the rest (edges and centre are flat colours, so the stretch is exact).
## `m` = margins left/top/right/bottom in art-px; `src` = the source rect inside the texture.
func _draw_nine(hud: Node2D, tex: Texture2D, src: Rect2, dst: Rect2, m: Array, k: int, tint: Color = Color.WHITE) -> void:
	var xs: Array = [0.0, float(m[0]), src.size.x - float(m[2]), src.size.x]
	var ys: Array = [0.0, float(m[1]), src.size.y - float(m[3]), src.size.y]
	var dxs: Array = [0.0, float(m[0]) * k, dst.size.x - float(m[2]) * k, dst.size.x]
	var dys: Array = [0.0, float(m[1]) * k, dst.size.y - float(m[3]) * k, dst.size.y]
	for j: int in 3:
		for i: int in 3:
			var s := Rect2(src.position + Vector2(xs[i], ys[j]), Vector2(xs[i + 1] - xs[i], ys[j + 1] - ys[j]))
			var d := Rect2(dst.position + Vector2(dxs[i], dys[j]), Vector2(dxs[i + 1] - dxs[i], dys[j + 1] - dys[j]))
			if s.size.x > 0.0 and s.size.y > 0.0 and d.size.x > 0.0 and d.size.y > 0.0:
				hud.draw_texture_rect_region(tex, d, s, tint)


## One ASSET-015 icon (12x12 art-px) at integer scale k, top-left at pos.
func _draw_icon(hud: Node2D, icon_name: String, pos: Vector2, k: int = 2) -> void:
	if not _ui_icons.has(icon_name):
		return
	var r: Array = _ui_icons[icon_name]
	hud.draw_texture_rect_region(_ui_tex["icons"], Rect2(pos, Vector2(12 * k, 12 * k)), Rect2(r[0], r[1], r[2], r[3]))


## ASSET-014 on the ASSET-013 bar frame (16x6, ends 2, border 1, drawn x2 = 12 px tall, §7.5):
## fill from the left inside the 8 px groove at screen pixels (§7.4: bars are drawn sharp at
## 1280x720), a trail behind it, and for the boss the Ivory half-life notch (2 px wide, sticking
## out 3 px above and below).
func _draw_bar(hud: Node2D, rect: Rect2, ratio: float, fill: Color, trail: float, boss: bool) -> void:
	var r := Rect2(rect.position.floor(), rect.size.floor())
	var tex: Texture2D = _ui_tex["bar"]
	_draw_nine(hud, tex, Rect2(0, 0, tex.get_width(), tex.get_height()), r, [2, 1, 2, 1], 2)
	var inner := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
	if trail > ratio:
		hud.draw_rect(Rect2(inner.position, Vector2(floorf(inner.size.x * trail), inner.size.y)), HP_TRAIL)
	hud.draw_rect(Rect2(inner.position, Vector2(floorf(inner.size.x * ratio), inner.size.y)), fill)
	if boss:
		var nx: float = floorf(inner.position.x + inner.size.x * 0.5) - 1.0
		hud.draw_rect(Rect2(nx - 1.0, r.position.y - 4.0, 4.0, r.size.y + 8.0), INK)
		hud.draw_rect(Rect2(nx, r.position.y - 3.0, 2.0, r.size.y + 6.0), IVORY)


func _draw() -> void:
	draw_rect(get_viewport_rect(), INK)


func _process(delta: float) -> void:
	if not _seq.is_empty():
		_tick_seq(delta)
		return
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


func _has_fx() -> bool:
	return _fx_tex.has("tiles16") and _fx_tex.has("tiles5") and _fx_tex.has("marks") and _fx_tex.has("stripe") and _fx_tex.has("slash")


## --fx: the slice-1 floor and VFX candidates from one folder (PNG + JSON index where there is one).
func _load_fx() -> void:
	var files: Dictionary = {"tiles16": "ASSET-008-block_tiles_16.png", "tiles5": "ASSET-008-block_tiles_5.png",
		"marks": "ASSET-011-fx_material_marks_16.png", "stripe": "ASSET-012-fx_telegraph_stripe_8.png",
		"slash": "ASSET-009-vfx_slash_sheet.png", "push": "ASSET-016-vfx_push_sheet.png"}
	for key: String in files:
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(_fx_dir + "/" + files[key]))
		if img != null:
			_fx_tex[key] = ImageTexture.create_from_image(img)
	for key: String in ["marks", "slash", "push"]:
		var f := FileAccess.open(_fx_dir + "/" + String(files[key]).get_basename() + ".json", FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_fx_meta[key] = data
	if not _has_fx():
		push_error("art_check: --fx folder incomplete: " + _fx_dir)


## The slab face a floor overlay may cover: the cell minus the Ink gap and the front lip.
func _face_rect(side: int, col: int, row: int) -> Rect2:
	var o: Vector2i = _cell_origin(side, col, row)
	return Rect2(o.x, o.y, _cell.x - GAP, _cell.y - GAP - LIP)


## Pixel-exact frame of [param t] px drawn INSIDE [param r].
func _frame_px(n: Node2D, r: Rect2, t: float, col: Color) -> void:
	n.draw_rect(Rect2(r.position, Vector2(r.size.x, t)), col)
	n.draw_rect(Rect2(r.position + Vector2(0, r.size.y - t), Vector2(r.size.x, t)), col)
	n.draw_rect(Rect2(r.position, Vector2(t, r.size.y)), col)
	n.draw_rect(Rect2(r.position + Vector2(r.size.x - t, 0), Vector2(t, r.size.y)), col)


## Cells the --fx demo uses: [telegraph cells (player)], [target cells (enemy)], lying-block cell.
func _fx_cells() -> Dictionary:
	var hero: Vector2i = _default_cell(0)
	var goblin: Vector2i = _default_cell(1)
	var tele: Array = [Vector2i(hero.x, hero.y)]
	if _is_real(0, hero.x, hero.y + 1):
		tele.append(Vector2i(hero.x, hero.y + 1))
	var target: Array = [Vector2i(goblin.x, goblin.y)]
	if _is_real(1, goblin.x, goblin.y + 1):
		target.append(Vector2i(goblin.x, goblin.y + 1))
	var lying := Vector2i(maxi(hero.x - 1, 0), hero.y)
	return {"tele": tele, "target": target, "lying": lying}


## Floor layer (under the units): telegraph fill + stripes, cast target fill + mark + raised edge,
## the lying block with its shadow.
func _draw_fx_floor(n: Node2D) -> void:
	var cells: Dictionary = _fx_cells()
	var in_seq: bool = not _seq.is_empty()
	if not in_seq:
		# telegraph at intensity k: a flat red fill grows 0 → 0.45, the stripe texture 0.5 → 1,
		# the frame 0.3 → 1; everything on the floor layer (user 2026-10-31: nothing on a tile
		# may cover the unit standing on it; no countdown label, the darkening IS the timer)
		var k: float = _tele_k
		for c: Vector2i in cells["tele"]:
			var face: Rect2 = _face_rect(0, c.x, c.y)
			n.draw_rect(face, Color(TELEGRAPH_RED, lerpf(0.0, 0.45, k)))
			n.draw_texture_rect(_fx_tex["stripe"], face, true, Color(1, 1, 1, lerpf(0.5, 1.0, k)))
			_frame_px(n, face.grow(1), 1, Color(INK, lerpf(0.3, 1.0, k)))
			_frame_px(n, face, 2, Color(TELEGRAPH_RED, lerpf(0.3, 1.0, k)))
	var intensity: Array = [0.7, 1.0]
	var i: int = 0
	for c: Vector2i in cells["target"]:
		var face: Rect2 = _face_rect(1, c.x, c.y)
		var k: float = float(_seq_state["k"]) if in_seq else float(intensity[mini(i, 1)])
		if k <= 0.0:
			continue
		n.draw_rect(face, Color(STEEL, 0.6))
		# raised edge in the highlight colour (top-left) and the shadow (bottom-right), ramped by k
		n.draw_rect(Rect2(face.position, Vector2(face.size.x, 1)), Color(STEEL_HI, k))
		n.draw_rect(Rect2(face.position, Vector2(1, face.size.y)), Color(STEEL_HI, k))
		n.draw_rect(Rect2(face.position + Vector2(0, face.size.y - 1), Vector2(face.size.x, 1)), Color(STEEL_LO, k))
		n.draw_rect(Rect2(face.position + Vector2(face.size.x - 1, 0), Vector2(1, face.size.y)), Color(STEEL_LO, k))
		# the material mark, stretched to the face (steel = bevel, margins 1): tinted highlight
		var mark: Dictionary = (_fx_meta.get("marks", {}) as Dictionary).get("marks", {}).get("bevel", {})
		if not mark.is_empty():
			var r: Array = mark["rect"]
			var m: Array = mark["nine_slice"]
			_draw_nine(n, _fx_tex["marks"], Rect2(r[0], r[1], r[2], r[3]), face.grow(-2), m, 1, Color(STEEL_HI, k))
		i += 1
	# lying T block: four 5x5 steel tiles, 1 px Ink halo around the whole shape, hovering 2 px over
	# a square shadow; centred on the face
	var lying: Vector2i = cells["lying"]
	if _is_real(0, lying.x, lying.y) and not in_seq:
		var face: Rect2 = _face_rect(0, lying.x, lying.y)
		var shape: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]
		var base: Vector2 = (face.get_center() - Vector2(7.5, 5)).floor()
		for sc: Vector2i in shape:
			n.draw_rect(Rect2(base + Vector2(sc) * 5 + Vector2(0, 2), Vector2(5, 5)), Color(INK, 0.5))
		var top: Vector2 = base - Vector2(0, 2)
		for sc: Vector2i in shape:
			n.draw_rect(Rect2(top + Vector2(sc) * 5 - Vector2(1, 1), Vector2(7, 7)), INK)
		for sc: Vector2i in shape:
			n.draw_texture_rect_region(_fx_tex["tiles5"], Rect2(top + Vector2(sc) * 5, Vector2(5, 5)), Rect2(0, 0, 5, 5))


## Overlay layer (above the units): the telegraph frame with its Ink edge, slash frame 3 on the
## target tiles (tinted with the steel highlight), a falling 16x16 domino.
func _draw_fx_overlay(n: Node2D) -> void:
	var cells: Dictionary = _fx_cells()
	var in_seq: bool = not _seq.is_empty()
	var sheet_key: String = _seq if in_seq and _fx_tex.has(_seq) else "slash"
	var vf: int = int(_seq_state["vf"]) if in_seq else 2
	var meta: Dictionary = _fx_meta.get(sheet_key, {})
	var fw: int = 38
	var fh: int = 27
	var gut: int = 1
	if meta.has("frame"):
		fw = int(meta["frame"][0])
		fh = int(meta["frame"][1])
		gut = int(meta.get("gutter", 1))
	# user 2026-10-31: when a piece is dragged or cast, only the tiles light up; no block sprite
	# travels onto the board (the falling domino of the first demo is gone)
	if vf >= 0:
		for c: Vector2i in cells["target"]:
			var face: Rect2 = _face_rect(1, c.x, c.y)
			var pos: Vector2 = (face.get_center() - Vector2(fw, fh) * 0.5).floor()
			n.draw_texture_rect_region(_fx_tex[sheet_key], Rect2(pos, Vector2(fw, fh)), Rect2(vf * (fw + gut), 0, fw, fh), STEEL_HI)


## One keyframe of the cast sequence.
func _step(ms: int, hero: String, gob: String, k: float, dy: float, vf: int, flash: bool) -> Dictionary:
	return {"ms": ms, "hero": hero, "gob": gob, "k": k, "dy": dy, "vf": vf, "flash": flash}


## The cast sequence: choose tiles (ramp) → cast gesture (art bible §3: A 0.08 s, B 0.12 s) → the
## block falls (3 keyframes) → VFX frames at the sheet's own timings while the goblin takes the
## hit (flash on the first VFX frame) → rest. One cycle = ~2.1 s.
func _build_seq() -> void:
	var meta: Dictionary = _fx_meta.get(_seq, _fx_meta.get("slash", {}))
	var vfx_ms: Array = []
	for f: Variant in meta.get("frames", []):
		vfx_ms.append(int((f as Dictionary).get("ms", 60)))
	if vfx_ms.is_empty():
		vfx_ms = [50, 60, 60, 60]
	_seq_steps = [
		_step(300, "idle-A", "idle-A", 0.35, -1000.0, -1, false),
		_step(300, "idle-B", "idle-B", 0.6, -1000.0, -1, false),
		_step(80, "cast-A", "idle-A", 1.0, -1000.0, -1, false),
		_step(120, "cast-B", "idle-A", 1.0, -1000.0, -1, false),
		_step(120, "idle-A", "idle-A", 1.0, -1000.0, -1, false),
	]
	for i: int in vfx_ms.size():
		var gob: String = "hit" if i >= 1 and i <= 2 else "idle-A"
		_seq_steps.append(_step(vfx_ms[i], "idle-A", gob, 1.0, -1000.0, i, i == 1))
	_seq_steps.append(_step(400, "idle-A", "idle-B", 0.0, -1000.0, -1, false))
	_seq_steps.append(_step(300, "idle-B", "idle-B", 0.0, -1000.0, -1, false))


func _apply_seq_step(i: int) -> void:
	var st: Dictionary = _seq_steps[i]
	_seq_hero.texture = _anim_textures[0][SEQ_HERO_FRAMES.find(st["hero"])]
	_seq_goblin.texture = _anim_textures[1][SEQ_GOBLIN_FRAMES.find(st["gob"])]
	# hit flash = ASSET-010: every opaque texel drawn as Ivory for one VFX frame (a 2-line canvas
	# shader here; the game's unit_fx shader does the same inside the palette)
	_seq_goblin.material = _flash_material() if bool(st["flash"]) else null
	_seq_state = {"k": st["k"], "dy": st["dy"], "vf": st["vf"], "flash": st["flash"]}
	if _fx_floor != null:
		_fx_floor.queue_redraw()
	if _fx_over != null:
		_fx_over.queue_redraw()


## Keyframe clock; with --shot every keyframe is saved once and the run quits after one cycle,
## writing <shot>.json = the durations in centiseconds (GIF units).
func _tick_seq(delta: float) -> void:
	_frames += 1
	if _frames < SHOT_FRAME or _capturing:
		return
	if _seq_i >= 0:
		_seq_time += delta
		if _seq_time < float(_seq_steps[_seq_i]["ms"]) / 1000.0:
			return
	_seq_time = 0.0
	_seq_i += 1
	if _seq_i >= _seq_steps.size():
		if _shot.is_empty():
			_seq_i = 0
		else:
			var cs: Array = []
			for st: Dictionary in _seq_steps:
				cs.append(int(st["ms"]) / 10)
			var f := FileAccess.open(_shot.get_basename() + ".json", FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(cs))
			get_tree().quit()
			return
	_apply_seq_step(_seq_i)
	if not _shot.is_empty():
		_capturing = true
		var path: String = _shot.get_basename() + ("-%02d." % _seq_i) + _shot.get_extension()
		await _capture(path, false)
		_capturing = false


var _flash_mat: ShaderMaterial
func _flash_material() -> ShaderMaterial:
	if _flash_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;
void fragment() { vec4 t = texture(TEXTURE, UV); COLOR = vec4(0.937, 0.902, 0.823, t.a); }"
		_flash_mat = ShaderMaterial.new()
		_flash_mat.shader = sh
	return _flash_mat


# ---------------------------------------------------------------------------------------------
# --skin=osfe: style test. Everything below is drawn with vector calls at screen resolution.
# ---------------------------------------------------------------------------------------------

## Rectangle with 45-degree chamfers; `cuts` = [top-left, top-right, bottom-right, bottom-left] px.
func _chamfer(r: Rect2, cuts: Array) -> PackedVector2Array:
	var tl: float = cuts[0]
	var tr: float = cuts[1]
	var br: float = cuts[2]
	var bl: float = cuts[3]
	var p := PackedVector2Array()
	p.append(r.position + Vector2(tl, 0))
	p.append(r.position + Vector2(r.size.x - tr, 0))
	if tr > 0.0:
		p.append(r.position + Vector2(r.size.x, tr))
	p.append(r.position + Vector2(r.size.x, r.size.y - br))
	if br > 0.0:
		p.append(r.position + Vector2(r.size.x - br, r.size.y))
	p.append(r.position + Vector2(bl, r.size.y))
	if bl > 0.0:
		p.append(r.position + Vector2(0, r.size.y - bl))
	p.append(r.position + Vector2(0, tl))
	return p


func _panel(n: Node2D, r: Rect2, cuts: Array, fill: Color, line: Color, width: float = 1.0) -> void:
	var poly: PackedVector2Array = _chamfer(r, cuts)
	n.draw_colored_polygon(poly, fill)
	var closed: PackedVector2Array = poly.duplicate()
	closed.append(poly[0])
	n.draw_polyline(closed, line, width, false)


func _diamond(n: Node2D, c: Vector2, r: float, fill: Color, line: Color, width: float = 2.0) -> void:
	var p := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	n.draw_colored_polygon(p, fill)
	var closed: PackedVector2Array = p.duplicate()
	closed.append(p[0])
	n.draw_polyline(closed, line, width, false)


func _text(n: Node2D, font: Font, pos: Vector2, text: String, size: int, col: Color = UI_TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	n.draw_string_outline(font, pos, text, align, width, size, 3, UI_OUTLINE)
	n.draw_string(font, pos, text, align, width, size, col)


## Segmented bar: `total` segments, `filled` lit, 2 px gaps, light end cap.
func _segments(n: Node2D, r: Rect2, total: int, filled: int, lit: Color) -> void:
	n.draw_rect(r.grow(1), UI_OUTLINE)
	n.draw_rect(r, UI_NAVY_DEEP)
	var gap: float = 2.0
	var w: float = (r.size.x - gap * (total - 1)) / total
	for i: int in total:
		var seg := Rect2(r.position + Vector2(i * (w + gap), 0), Vector2(w, r.size.y))
		n.draw_rect(seg, lit if i < filled else UI_NAVY_LIGHT)
	n.draw_rect(Rect2(r.position + Vector2(r.size.x - 3, 0), Vector2(3, r.size.y)), UI_LINE)


## HP bar with groove, fill, trail and optional boss notch; numbers drawn beside by the caller.
func _hp_bar(n: Node2D, r: Rect2, ratio: float, trail: float, fill: Color, notch: bool) -> void:
	n.draw_rect(r.grow(1), UI_OUTLINE)
	n.draw_rect(r, UI_NAVY_DEEP)
	if trail > ratio:
		n.draw_rect(Rect2(r.position, Vector2(floorf(r.size.x * trail), r.size.y)), HP_TRAIL)
	n.draw_rect(Rect2(r.position, Vector2(floorf(r.size.x * ratio), r.size.y)), fill)
	# a 1 px lighter top line gives the fill a bevel without a gradient
	n.draw_rect(Rect2(r.position, Vector2(floorf(r.size.x * ratio), 1)), fill.lightened(0.35))
	if notch:
		var nx: float = floorf(r.position.x + r.size.x * 0.5)
		n.draw_rect(Rect2(nx - 1, r.position.y - 3, 2, r.size.y + 6), IVORY)


## A steel block preview inside a slot card: `cells` in block units, `k` px per cell.
func _block_preview(n: Node2D, origin: Vector2, cells: Array, k: float) -> void:
	for c: Vector2i in cells:
		var r := Rect2(origin + Vector2(c) * k, Vector2(k, k))
		n.draw_rect(r.grow(1), UI_OUTLINE)
	for c: Vector2i in cells:
		var r := Rect2(origin + Vector2(c) * k, Vector2(k, k))
		n.draw_rect(r, STEEL)
		n.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), STEEL_HI)
		n.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), STEEL_HI)
		n.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), STEEL_LO)
		n.draw_rect(Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y)), STEEL_LO)


## Slot card in the OSFE language: navy card, chamfered top-right, light frame, cost badge
## bottom-left (white square, dark number), content centred; `selected` = white 3 px frame.
func _slot_card(n: Node2D, font: Font, r: Rect2, cost: String, content: String, selected: bool) -> void:
	_panel(n, r.grow(3), [0, 14, 0, 0], UI_OUTLINE, UI_OUTLINE)
	_panel(n, r, [0, 12, 0, 0], UI_NAVY, UI_TEXT if selected else UI_LINE, 3.0 if selected else 1.5)
	# a lighter band at the top third stands in for OSFE's dark gradient
	n.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 16, r.size.y * 0.33)), Color(UI_NAVY_LIGHT, 0.6))
	match content:
		"T":
			_block_preview(n, r.get_center() - Vector2(27, 18), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], 18.0)
		"I":
			_block_preview(n, r.get_center() - Vector2(9, 27), [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)], 18.0)
		_:
			_text(n, font, Vector2(r.position.x, r.get_center().y + 10), "+", 30, UI_LINE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if not cost.is_empty():
		var badge := Rect2(r.position + Vector2(-4, r.size.y - 26), Vector2(30, 30))
		n.draw_rect(badge.grow(2), UI_OUTLINE)
		n.draw_rect(badge, UI_TEXT)
		n.draw_string(_font_bold if _font_bold != null else font, badge.position + Vector2(0, 22), cost, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 18, UI_OUTLINE)


func _draw_hud_osfe(hud: Node2D, font: Font, margin: float) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var bold: Font = _font_bold if _font_bold != null else font
	# --- Z1 left: hero header panel, chamfered bottom-right; name, HP bar + numbers, Engraving bar
	var hp_w: float = 300.0
	var head := Rect2(margin, 20, 430, 60)
	_panel(hud, head, [0, 0, 18, 0], Color(UI_NAVY, 0.92), UI_LINE)
	_text(hud, font, head.position + Vector2(12, 26), "KIẾM SĨ", 24)
	_text(hud, font, head.position + Vector2(118, 26), "Lv. 1", 14, Color("B8C2D0"))
	var bar := Rect2(head.position + Vector2(12, 32), Vector2(hp_w, 12))
	_hp_bar(hud, bar, 0.85, 0.93, UI_GREEN, false)
	_text(hud, bold, bar.position + Vector2(hp_w + 10, 13), "170/200", 20)
	var eng := Rect2(head.position + Vector2(12, 48), Vector2(hp_w, 6))
	_segments(hud, eng, 7, 2, UI_GOLD)
	_text(hud, bold, eng.position + Vector2(hp_w + 10, 9), "6/21", 14, UI_GOLD)
	# --- Z1 right: boss header, mirrored
	var bhead := Rect2(vp.x - margin - 430, 20, 430, 60)
	_panel(hud, bhead, [0, 0, 0, 18], Color(UI_NAVY, 0.92), UI_LINE)
	_text(hud, font, bhead.position + Vector2(12, 26), "GOBLIN SCOUT", 24, UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, bhead.size.x - 24)
	var bbar := Rect2(bhead.position + Vector2(bhead.size.x - 12 - hp_w, 32), Vector2(hp_w, 12))
	_hp_bar(hud, bbar, 1.0, 1.0, IVORY, true)
	_text(hud, bold, bbar.position + Vector2(-90, 13), "60/60", 20, UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 80)
	# boss block preview: three small navy squares under the bar (Z1b)
	for i: int in 3:
		var bq := Rect2(bbar.position + Vector2(hp_w - 26 - i * 30, 18), Vector2(22, 14))
		hud.draw_rect(bq.grow(1), UI_OUTLINE)
		hud.draw_rect(bq, UI_NAVY_LIGHT if i > 0 else Color("CFC6B4"))
	# --- pause: small chamfered square, centre top
	if _skin_icon("pause", Vector2(vp.x * 0.5 - 27, 16)):
		_skin_icon("info", Vector2(vp.x * 0.5 + 34, 16))
	else:
		var pr := Rect2(vp.x * 0.5 - 20, 22, 40, 40)
		_panel(hud, pr, [6, 6, 6, 6], Color(UI_NAVY, 0.92), UI_LINE)
		hud.draw_rect(Rect2(pr.position + Vector2(12, 11), Vector2(5, 18)), UI_TEXT)
		hud.draw_rect(Rect2(pr.position + Vector2(23, 11), Vector2(5, 18)), UI_TEXT)
	# --- keyword chips under the enemy's feet (§7.4: max 2 on a 5x5), centred, nothing on the body.
	# HP plates dropped (user 2026-10-31: they covered the unit and the tile; the HUD bars carry HP)
	var gcell: Vector2i = _default_cell(1)
	var ga: Vector2 = _screen_origin + Vector2(_anchor(1, gcell.x, gcell.y)) * _scale
	_skin_icon("burn", ga + Vector2(-30, 4), 0.5)
	_skin_icon("fragile", ga + Vector2(2, 4), 0.5)
	# --- Z3: joystick in navy
	var base_r: float = 80.0
	var center := Vector2(margin + 150.0, vp.y * 0.80)
	hud.draw_circle(center, base_r, Color(UI_NAVY, 0.55))
	hud.draw_arc(center, base_r, 0.0, TAU, 64, UI_LINE, 1.5)
	for d: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var tip: Vector2 = center + d * (base_r - 10.0)
		var side_v: Vector2 = Vector2(-d.y, d.x) * 6.0
		hud.draw_colored_polygon(PackedVector2Array([tip, tip - d * 8.0 + side_v, tip - d * 8.0 - side_v]), UI_LINE)
	var knob := center + Vector2(base_r * 0.55, 0)
	hud.draw_circle(knob, 44.0, Color(UI_NAVY_LIGHT, 0.95))
	hud.draw_arc(knob, 44.0, 0.0, TAU, 48, UI_TEXT, 2.0)
	# --- Z5: slot cards on the v2 arc
	var sh: float = vp.y * 0.18
	var sw: float = sh / 1.4
	var pivot := Vector2(vp.x - margin * 0.5, vp.y + sh * 0.35)
	var radius: float = sh * 2.0
	var contents: Array = ["T", "", "I"]
	var costs: Array = ["4", "", "3"]
	var i: int = 0
	for deg: float in [100.0, 128.0, 156.0]:
		var c: Vector2 = pivot + Vector2(cos(deg_to_rad(deg)), -sin(deg_to_rad(deg))) * radius
		var r := Rect2((c - Vector2(sw, sh) * 0.5).floor(), Vector2(sw, sh).floor())
		_slot_card(hud, font, r, costs[i], contents[i], i == 0)
		i += 1
	# bag counter plate under the arc, like OSFE's deck count
	var bagp := Rect2(vp.x - margin - sw - 84, vp.y - 30, 64, 22)
	_panel(hud, bagp, [0, 0, 0, 8], Color(UI_NAVY, 0.92), UI_LINE)
	_text(hud, font, bagp.position + Vector2(0, 16), "5 / 9", 13, UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER, bagp.size.x)
	# --- Z4: Awaken as a diamond button, gold frame, counter inside, label under
	var sig: float = vp.y * 0.16
	var sc := Vector2(vp.x * 0.5, vp.y - margin * 0.5 - sig * 0.5 - 6)
	_diamond(hud, sc, sig * 0.5 + 3, UI_OUTLINE, UI_OUTLINE, 1.0)
	_diamond(hud, sc, sig * 0.5, UI_NAVY, UI_GOLD, 3.0)
	_diamond(hud, sc, sig * 0.22, Color(UI_GOLD, 0.15), Color(UI_GOLD, 0.6), 1.0)
	if _skin_icons != null:
		_skin_icon("awakening", sc + Vector2(-27, -40), 1.0)
		_text(hud, bold, Vector2(sc.x - 60, sc.y + 34), "6/21", 20, UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER, 120)
	else:
		_text(hud, bold, Vector2(sc.x - 60, sc.y + 8), "6/21", 22, UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER, 120)
	_text(hud, font, Vector2(sc.x - 80, sc.y - sig * 0.5 - 10), "THỨC TỈNH", 13, Color("B8C2D0"), HORIZONTAL_ALIGNMENT_CENTER, 160)


## --floor=osfe: OSFE's LOOK on Tessera's STRUCTURE (user, 2026-10-31: "phong cách của nó, cấu tạo
## hình dạng của game mình"): the face is a flat navy plane with a 1 px inner line (cool on the
## player half, warm on the enemy half) and a 1 px top highlight, but the slab keeps its front lip
## (LIP art-px, darker) and the 1 px Ink gap, so rows still stack like stone and missing cells
## still cut the arena shapes.
func _draw_tile_osfe(board: Node2D, o: Vector2i, side: int) -> void:
	var w: int = _cell.x - GAP
	var h: int = _cell.y - GAP
	var face := Rect2(o.x, o.y, w, h - LIP)
	var lip := Rect2(o.x, o.y + h - LIP, w, LIP)
	var mf: bool = _floor == "tessera"
	board.draw_rect(face, MF_FACE if mf else (TILE_FACE if side == 0 else TILE_FACE_ENEMY))
	board.draw_rect(lip, MF_LIP if mf else (TILE_LIP if side == 0 else TILE_LIP_ENEMY))
	var line: Color = MF_LINE if mf else (TILE_LINE_PLAYER if side == 0 else TILE_LINE_ENEMY)
	var inner := face.grow(-1)
	board.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), line)
	board.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(inner.size.x, 1)), line)
	board.draw_rect(Rect2(inner.position, Vector2(1, inner.size.y)), line)
	board.draw_rect(Rect2(inner.position + Vector2(inner.size.x - 1, 0), Vector2(1, inner.size.y)), line)
	board.draw_rect(Rect2(face.position, Vector2(face.size.x, 1)), MF_TOP if mf else (TILE_TOP if side == 0 else TILE_TOP_ENEMY))



func _load_font(path: String) -> Font:
	var f := FontFile.new()
	var err: Error = f.load_dynamic_font(path)
	if err != OK:
		push_error("art_check: cannot load font %s (%s)" % [path, error_string(err)])
		return null
	return f


## One tile of the --icons sheet at `k` times its size (1.0 = 1:1); false when there is no sheet.
func _skin_icon(icon_name: String, pos: Vector2, k: float = 1.0) -> bool:
	if _skin_icons == null or not _skin_icon_index.has(icon_name):
		return false
	var hud: Node2D = get_node_or_null("Hud")
	if hud == null:
		return false
	var r: Array = _skin_icon_index[icon_name]
	hud.draw_texture_rect_region(_skin_icons, Rect2(pos.floor(), Vector2(r[2] * k, r[3] * k)), Rect2(r[0], r[1], r[2], r[3]))
	return true


## --platform: raised stone deck drawn PER REAL CELL (grown by DECK_MARGIN), so the deck follows
## shaped arenas; a front face under every cell with no real cell below it, light edges where a
## top or left neighbour is missing, a shadow under the faces. Light from the top-left like the slabs.
func _draw_platform(board: Node2D) -> void:
	var m: int = DECK_MARGIN
	var faces: Array[Rect2] = []
	# pass 1: shadows + faces (under the deck so the deck covers their top)
	for side: int in 2:
		for col: int in _board.x:
			for row: int in _board.y:
				if not _is_real(side, col, row):
					continue
				if not _is_real(side, col, row + 1):
					var o: Vector2i = _cell_origin(side, col, row)
					var left_edge: int = o.x - m if not _is_real(side, col - 1, row) else o.x
					var right_edge: int = o.x + _cell.x - GAP + m if not _is_real(side, col + 1, row) else o.x + _cell.x
					var face := Rect2(left_edge, o.y + _cell.y - GAP + m - 1, right_edge - left_edge, FACE_H)
					faces.append(face)
	for f: Rect2 in faces:
		board.draw_rect(Rect2(f.position.x + 2, f.end.y, f.size.x - 4, 4), Color(INK, 0.5))
	for f: Rect2 in faces:
		board.draw_rect(f, DECK_LIP)
		board.draw_rect(Rect2(f.position + Vector2(0, f.size.y - 2), Vector2(f.size.x, 2)), INK)
		var jx: int = int(f.position.x) + 17
		while jx < int(f.end.x) - 4:
			board.draw_rect(Rect2(jx, f.position.y + 2, 1, f.size.y - 4), INK)
			jx += 40
	# pass 2: deck under every real cell, grown toward missing neighbours (the divider gap is deck)
	for side: int in 2:
		for col: int in _board.x:
			for row: int in _board.y:
				if not _is_real(side, col, row):
					continue
				var o: Vector2i = _cell_origin(side, col, row)
				var r := Rect2(o.x - m, o.y - m, _cell.x + m * 2, _cell.y + m * 2)
				board.draw_rect(r, DECK)
	# pass 3: light edge on top / left where no real neighbour, dark on right where none, lip top line
	for side: int in 2:
		for col: int in _board.x:
			for row: int in _board.y:
				if not _is_real(side, col, row):
					continue
				var o: Vector2i = _cell_origin(side, col, row)
				var r := Rect2(o.x - m, o.y - m, _cell.x + m * 2, _cell.y + m * 2)
				if not _is_real(side, col, row - 1):
					board.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), DECK_LIGHT)
				if not _is_real(side, col - 1, row) and not (side == 1 and col == 0):
					board.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), DECK_LIGHT)
				if not _is_real(side, col + 1, row) and not (side == 0 and col == _board.x - 1):
					board.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), DECK_LIP)
	for f: Rect2 in faces:
		board.draw_rect(Rect2(f.position, Vector2(f.size.x, 1)), DECK_LIGHT)
	# divider: a thin line in the gap between the halves
	var o0: Vector2i = _board_origin()
	var dx: int = o0.x + _board.x * _cell.x + DIVIDER_GAP / 2 - 1
	board.draw_rect(Rect2(dx, o0.y - 2, 1, _board.y * _cell.y + 2), DECK_LIP)

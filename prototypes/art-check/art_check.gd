extends Node2D
## DEV-ONLY art check for the vertical-slice sprites (art bible §8.9 #1, #3, #9).
## Throwaway prototype: it is not part of the game and nothing in src/ depends on it.
##
## It mimics the §8.2–8.3 render rules the battle will move to: a 640x360 art
## canvas (SubViewport) shown at an integer scale with Nearest filtering, slabs
## of 38x27 art-px (the smallest size, so the 5x5 board is the hardest case),
## units anchored bottom-centre 3 art-px above the slab's front edge and drawn
## back row first (y-sort). Sprites are read straight from the candidate PNGs,
## so no import settings are involved.
##
##   godot --path . --windowed --resolution 1280x720 res://prototypes/art-check/art_check.tscn \
##       -- --mode=normal --shot=C:/abs/out.png
##
##   --mode=normal    the Swordsman on the player half, one Goblin Scout on the enemy half
##   --mode=blackout  the same, every unit drawn as a flat Ink silhouette (§8.9 #1)
##   --mode=rows      three Goblin Scouts in one enemy column on three adjacent rows (§8.9 #3)
##   --cell=WxH       slab size in art-px (default 38x27; §8.3 allows up to 64x46)
##   --scale=N        integer display scale (default 2 = 1280x720)
##   --shot=<path>    save a PNG of the window after SHOT_FRAME frames, then quit

const ART_SIZE := Vector2i(640, 360)
const DEFAULT_CELL := Vector2i(38, 27)
const SIDE_COLS := 5
const SIDE_ROWS := 5
## Art-px between the two halves (the divider).
const DIVIDER_GAP := 6
## Front lip of a slab, in art-px (§8.3: 2–3).
const LIP := 3
## The Ink gap between slabs, in art-px.
const GAP := 1
## Feet sit this many art-px above the slab's front edge (§1 technical consequences).
const FOOT_LIFT := 3
## Vertical centre of the board on the art canvas, as a ratio (the arena band of ScreenLayout).
const BOARD_CENTER_RATIO := 0.3
const SHOT_FRAME := 30

const INK := Color("1B1722")
const GROUND := Color("3A3F36")
const STONE := Color("4A4640")
const STONE_LIGHT := Color("5A5650")
const LIP_COLOR := Color("2C2925")

const HERO_PNG := "res://design/assets/candidates/swordsman/ASSET-001-idle-A-32x48.png"
const GOBLIN_PNG := "res://design/assets/candidates/goblin-scout/ASSET-003-idle-A-32x48.png"

var _mode: String = "normal"
var _cell: Vector2i = DEFAULT_CELL
var _scale: int = 2
var _shot: String = ""
var _frames: int = 0
var _units: Node2D


func _ready() -> void:
	_parse_args()
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


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--scale="):
			_scale = maxi(1, arg.trim_prefix("--scale=").to_int())
		elif arg.begins_with("--cell="):
			var parts: PackedStringArray = arg.trim_prefix("--cell=").split("x")
			if parts.size() == 2:
				_cell = Vector2i(parts[0].to_int(), parts[1].to_int())


## Top-left of the board on the art canvas, in whole art-px.
func _board_origin() -> Vector2i:
	var width: int = SIDE_COLS * 2 * _cell.x + DIVIDER_GAP
	var height: int = SIDE_ROWS * _cell.y
	return Vector2i((ART_SIZE.x - width) / 2, int(ART_SIZE.y * BOARD_CENTER_RATIO) - height / 2)


## Top-left of a cell. [param side] 0 = player half (left), 1 = enemy half (right).
func _cell_origin(side: int, col: int, row: int) -> Vector2i:
	var origin: Vector2i = _board_origin()
	var x: int = origin.x + col * _cell.x + side * (SIDE_COLS * _cell.x + DIVIDER_GAP)
	return Vector2i(x, origin.y + row * _cell.y)


## Where a unit's feet go: bottom-centre of the cell, FOOT_LIFT above the front edge.
func _anchor(side: int, col: int, row: int) -> Vector2i:
	var o: Vector2i = _cell_origin(side, col, row)
	return Vector2i(o.x + _cell.x / 2, o.y + _cell.y - GAP - FOOT_LIFT)


func _draw_board(board: Node2D) -> void:
	board.draw_rect(Rect2(Vector2.ZERO, Vector2(ART_SIZE)), GROUND)
	var origin: Vector2i = _board_origin()
	var size := Vector2i(SIDE_COLS * 2 * _cell.x + DIVIDER_GAP, SIDE_ROWS * _cell.y)
	board.draw_rect(Rect2(Vector2(origin) - Vector2(GAP, GAP), Vector2(size) + Vector2(GAP, GAP)), INK)
	for side: int in 2:
		for col: int in SIDE_COLS:
			for row: int in SIDE_ROWS:
				_draw_slab(board, _cell_origin(side, col, row))


## One slab: stone face, a 1 px light edge top-left, a LIP-px front lip, an Ink gap right and below.
func _draw_slab(board: Node2D, o: Vector2i) -> void:
	var w: int = _cell.x - GAP
	var h: int = _cell.y - GAP
	board.draw_rect(Rect2(o.x, o.y, w, h - LIP), STONE)
	board.draw_rect(Rect2(o.x, o.y, w, 1), STONE_LIGHT)
	board.draw_rect(Rect2(o.x, o.y, 1, h - LIP), STONE_LIGHT)
	board.draw_rect(Rect2(o.x, o.y + h - LIP, w, LIP), LIP_COLOR)


func _place_units() -> void:
	match _mode:
		"rows":
			_add_unit(HERO_PNG, 0, 3, 2)
			for row: int in [1, 2, 3]:
				_add_unit(GOBLIN_PNG, 1, 1, row)
		_:
			_add_unit(HERO_PNG, 0, 3, 2)
			_add_unit(GOBLIN_PNG, 1, 1, 2)
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


func _draw() -> void:
	draw_rect(get_viewport_rect(), INK)


func _process(_delta: float) -> void:
	if _shot.is_empty():
		return
	_frames += 1
	if _frames == SHOT_FRAME:
		_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(_shot)
	print("art_check: mode=%s cell=%s scale=%d shot=%s (%s)" % [_mode, _cell, _scale, _shot, error_string(err)])
	get_tree().quit()

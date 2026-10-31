class_name BattleCanvas
extends Node2D
## The battle art canvas (Story 047, art bible 8.2 / 8.6): owns a SubViewport of
## ScreenLayout.ART_CANVAS_WIDTH x ART_CANVAS_HEIGHT art px (800x360) holding four Node2D layers in
## draw order, BackdropLayer, FloorLayer, UnitLayer, OverlayLayer, and shows its texture at the integer
## scale ScreenLayout.art_scale, centred ([method ScreenLayout.art_rect]), with nearest filtering; the
## remainder of the screen is INK. First child of battle.tscn, so it draws under CombatView (HUD, rings)
## and every other battle view. Pixel snapping is set on this SubViewport only, not project-wide.
## Binds to the sibling CombatView ([member combat_view_path]) one frame after _ready (CombatView
## builds its grid and state in its own _ready); the layers read everything from it.
## Implements: Story 047 Part A.

## Ink (art bible 1): the colour outside the art rect.
const INK: Color = Color("1B1722")

## Path to the CombatView the layers read (grid, state, names, screen size).
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _viewport: SubViewport = null
var _backdrop: BackdropLayer = null
var _floor: FloorLayer = null
var _units: UnitLayer = null
var _overlay: OverlayLayer = null
var _combat: CombatView = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport = SubViewport.new()
	_viewport.name = "ArtViewport"
	_viewport.size = Vector2i(int(ScreenLayout.ART_CANVAS_WIDTH), int(ScreenLayout.ART_CANVAS_HEIGHT))
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.msaa_2d = Viewport.MSAA_DISABLED
	_viewport.use_hdr_2d = false
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.snap_2d_vertices_to_pixel = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_backdrop = BackdropLayer.new()
	_backdrop.name = "BackdropLayer"
	_floor = FloorLayer.new()
	_floor.name = "FloorLayer"
	_units = UnitLayer.new()
	_units.name = "UnitLayer"
	_overlay = OverlayLayer.new()
	_overlay.name = "OverlayLayer"
	for layer: Node2D in [_backdrop, _floor, _units, _overlay]:
		_viewport.add_child(layer)
	get_viewport().size_changed.connect(queue_redraw)
	call_deferred("_bind")


# Binds the layers to the CombatView after its _ready ran.
func _bind() -> void:
	if not is_inside_tree():
		return  # the battle was freed before the deferred bind ran (flow tests)
	var combat := get_node_or_null(combat_view_path) as CombatView
	if combat == null:
		push_warning("BattleCanvas: no CombatView at %s; the canvas stays empty" % combat_view_path)
		return
	_combat = combat
	combat.set_canvas(self)
	_backdrop.setup(combat)
	_floor.setup(combat)
	_units.setup(combat)
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), INK)
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), ScreenLayout.art_rect(vp), false)


## The SubViewport the layers draw into.
func get_art_viewport() -> SubViewport:
	return _viewport


## The CombatView the layers are bound to (null until the deferred bind ran or when none is found).
func get_combat_view() -> CombatView:
	return _combat


## Story 047 Part B: the art region the layers draw (resolved from match_params["chapter_id"] at bind).
func get_region_id() -> String:
	return _floor.get_region_id() if _floor != null else ArtAssets.DEFAULT_REGION


## Story 047 Part B: switches the backdrop and the floor to art region [param id] (`--region=<id>`, tests).
func set_region_id(id: String) -> void:
	if _backdrop != null:
		_backdrop.set_region_id(id)
	if _floor != null:
		_floor.set_region_id(id)


func get_backdrop_layer() -> BackdropLayer:
	return _backdrop


func get_floor_layer() -> FloorLayer:
	return _floor


func get_unit_layer() -> UnitLayer:
	return _units


func get_overlay_layer() -> OverlayLayer:
	return _overlay

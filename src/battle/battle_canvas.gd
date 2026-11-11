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
## 2026-11-02 (field pieces over tall heads): UnitLayer and OverlayLayer render on UNIT_VISIBILITY_LAYER only. The art
## viewport culls that layer; a second, transparent UnitViewport shares its World2D and renders only that layer, and
## BattleUnitView (after the field-point views in battle.tscn) draws it. So the units sit above the field pieces: a
## head rising into the cell behind covers a piece lying there instead of being covered by it.
## 2026-11-05 (forest-integration-pickup-plan step 1): a PickupLayer between FloorLayer (or its perspective warp) and
## UnitLayer draws the field pieces as stone-sigil pickups inside the art canvas (default visibility layer, so the
## art viewport renders it and the unit pass, drawn over the canvas, still covers it). 2026-11-06 (user: the sigils lie
## with the stone's tilt): with the floor perspective on, PickupLayer moves into its own flat PickupViewport warped by
## a PickupWarp sprite through the floor's own shader (same homography, no half tints), at the layer's place.
## 2026-11-06 (step 2, the board and the background are one place): a SupportLayer between BackdropLayer and the floor
## draws the stone foundation the board stands on (retaining walls under the front faces, side walls, moss, low mist).
## Implements: Story 047 Part A.

## Ink (art bible 1): the colour outside the art rect.
const INK: Color = Color("1B1722")
## ADR-0002 floor perspective: the inverse-homography resampler (see [method apply_floor_perspective]).
const PERSPECTIVE_SHADER: String = "res://src/battle/canvas_floor_perspective.gdshader"
## The perspective floor's half tints (user 2026-11-02: player half teal-green, enemy half purple), multiplied over the
## region's own half tints.
## 2026-11-06 (user: redo the whole floor; the halves stay apart but read as the same stone): lighter than the
## 2026-11-02 (0.78, 1.0, 0.90) / (0.98, 0.82, 1.0).
const PERSPECTIVE_TINT_PLAYER: Color = Color(0.93, 1.0, 0.96)
const PERSPECTIVE_TINT_ENEMY: Color = Color(0.99, 0.93, 1.0)
## The visibility layer (bit) UnitLayer and OverlayLayer render on: culled by the art viewport, the only one the
## UnitViewport renders.
const UNIT_VISIBILITY_LAYER: int = 1 << 1

## Path to the CombatView the layers read (grid, state, names, screen size).
@export var combat_view_path: NodePath = NodePath("../CombatView")

var _viewport: SubViewport = null
var _backdrop: BackdropLayer = null
var _floor: FloorLayer = null
var _pickups: PickupLayer = null
## 2026-11-06 (forest-integration-pickup-plan step 2): the stone foundation under the board, before the floor.
var _support: SupportLayer = null
var _units: UnitLayer = null
var _overlay: OverlayLayer = null
var _combat: CombatView = null
## ADR-0002: the floor's own SubViewport (a child of the art viewport, so it renders first) and
## the Sprite2D that draws its texture warped into the art viewport; null while the flag is off.
var _floor_viewport: SubViewport = null
var _floor_warp: Sprite2D = null
## 2026-11-06: the pickups' own flat SubViewport and its warp sprite (floor shader, white tints); null while flat.
var _pickup_viewport: SubViewport = null
var _pickup_warp: Sprite2D = null
## Skill v2 (Ngàn Kiếm finale): the visual-only board shake now applied (SkyDropFx.board_shake; zero under reduce motion).
var _board_offset: Vector2i = Vector2i.ZERO
## The units' pass: shares the art viewport's World2D, renders UNIT_VISIBILITY_LAYER only, transparent.
var _unit_viewport: SubViewport = null


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
	_support = SupportLayer.new()
	_support.name = "SupportLayer"
	_floor = FloorLayer.new()
	_floor.name = "FloorLayer"
	_pickups = PickupLayer.new()
	_pickups.name = "PickupLayer"
	_units = UnitLayer.new()
	_units.name = "UnitLayer"
	_overlay = OverlayLayer.new()
	_overlay.name = "OverlayLayer"
	for layer: Node2D in [_backdrop, _support, _floor, _pickups, _units, _overlay]:
		_viewport.add_child(layer)
	_viewport.canvas_cull_mask = _viewport.canvas_cull_mask & ~UNIT_VISIBILITY_LAYER
	_unit_viewport = SubViewport.new()
	_unit_viewport.name = "UnitViewport"
	_unit_viewport.size = _viewport.size
	_unit_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_unit_viewport.msaa_2d = Viewport.MSAA_DISABLED
	_unit_viewport.use_hdr_2d = false
	_unit_viewport.snap_2d_transforms_to_pixel = true
	_unit_viewport.snap_2d_vertices_to_pixel = true
	_unit_viewport.transparent_bg = true
	_unit_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_unit_viewport)
	_unit_viewport.world_2d = _viewport.world_2d
	_unit_viewport.canvas_cull_mask = UNIT_VISIBILITY_LAYER
	_put_on_unit_layer(_units)
	_put_on_unit_layer(_overlay)
	get_viewport().size_changed.connect(queue_redraw)
	call_deferred("_bind")


func _process(_delta: float) -> void:
	if _combat == null:
		return
	var reduce: bool = SettingsStore.shared().get_reduce_motion()
	var o: Vector2i = SkyDropFx.board_shake(_combat.get_sky_drops(), _combat.combat_clock(), reduce)
	if o == Vector2i.ZERO:
		# V4 feel pass: the hit shake of a landing player cast (CombatView.hit_shake_offset, zero under reduce motion).
		o = _combat.hit_shake_offset()
	if o != _board_offset:
		set_board_offset(o)


## Visual-only board shake: moves the stone foundation, the floor (or its warp sprite), the pickups (or theirs), the
## units and the overlay by [param offset] art px; the far backdrop stays put. Never touches gameplay state.
func set_board_offset(offset: Vector2i) -> void:
	_board_offset = offset
	for n: Node2D in [_support, _floor_warp if _floor_warp != null else _floor, _pickup_warp if _pickup_warp != null else _pickups, _units, _overlay]:
		if n != null:
			n.position = Vector2(offset)


## The visual-only board offset applied now (Vector2i.ZERO at rest).
func get_board_offset() -> Vector2i:
	return _board_offset


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
	_support.setup(combat)
	_floor.setup(combat)
	_pickups.setup(combat)
	_units.setup(combat)
	# ADR-0002: bound explicitly; its sibling lookup fails once the floor moves into the FloorViewport.
	_overlay.setup(_floor)
	# setup may add children (the units' hit-flash layer); a viewport draws an item only when its parents share the layer.
	_put_on_unit_layer(_units)
	_put_on_unit_layer(_overlay)
	apply_floor_perspective()
	queue_redraw()


# [param item] and every CanvasItem under it render on UNIT_VISIBILITY_LAYER only.
static func _put_on_unit_layer(item: Node) -> void:
	if item is CanvasItem:
		(item as CanvasItem).visibility_layer = UNIT_VISIBILITY_LAYER
	for child: Node in item.get_children():
		_put_on_unit_layer(child)


## ADR-0002: (re)builds the warped floor path from CombatView.floor_back_ratio(). On: FloorLayer
## (with its FloorDynamicLayer) moves into its own transparent 800x360 SubViewport and a Sprite2D drawing that texture
## through PERSPECTIVE_SHADER (inverse homography per fragment, nearest) takes its place between BackdropLayer and
## UnitLayer; FloorLayer itself keeps drawing flat. Off: FloorLayer sits in the art viewport as before (the default
## path is untouched: nothing is created). Safe to call again (tests flip the flag at runtime).
func apply_floor_perspective() -> void:
	var on: bool = _combat != null and is_instance_valid(_combat) and FloorPerspective.is_on(_combat.floor_back_ratio())
	if on and _floor_viewport == null:
		_floor_viewport = SubViewport.new()
		_floor_viewport.name = "FloorViewport"
		_floor_viewport.size = _viewport.size
		_floor_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		_floor_viewport.msaa_2d = Viewport.MSAA_DISABLED
		_floor_viewport.use_hdr_2d = false
		_floor_viewport.snap_2d_transforms_to_pixel = true
		_floor_viewport.snap_2d_vertices_to_pixel = true
		_floor_viewport.transparent_bg = true
		_floor_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var index: int = _floor.get_index()
		_viewport.remove_child(_floor)
		_floor_viewport.add_child(_floor)
		_viewport.add_child(_floor_viewport)
		_floor_warp = Sprite2D.new()
		_floor_warp.name = "FloorWarp"
		_floor_warp.centered = false
		_floor_warp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_floor_warp.texture = _floor_viewport.get_texture()
		var material := ShaderMaterial.new()
		material.shader = load(PERSPECTIVE_SHADER) as Shader
		_floor_warp.material = material
		_viewport.add_child(_floor_warp)
		_viewport.move_child(_floor_warp, index)
		_floor.mark_dirty()
		_warp_pickups(true)
	elif not on and _floor_viewport != null:
		_warp_pickups(false)
		var index: int = _floor_warp.get_index()
		_viewport.remove_child(_floor_warp)
		_floor_warp.queue_free()
		_floor_warp = null
		_floor_viewport.remove_child(_floor)
		_viewport.add_child(_floor)
		_viewport.move_child(_floor, index)
		_viewport.remove_child(_floor_viewport)
		_floor_viewport.queue_free()
		_floor_viewport = null
		_floor.mark_dirty()
	_update_perspective_uniforms()


# 2026-11-06: moves PickupLayer into (on) or out of (off) its own flat SubViewport warped by the floor shader.
func _warp_pickups(on: bool) -> void:
	if on and _pickup_viewport == null:
		_pickup_viewport = SubViewport.new()
		_pickup_viewport.name = "PickupViewport"
		_pickup_viewport.size = _viewport.size
		_pickup_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		_pickup_viewport.msaa_2d = Viewport.MSAA_DISABLED
		_pickup_viewport.use_hdr_2d = false
		_pickup_viewport.snap_2d_transforms_to_pixel = true
		_pickup_viewport.snap_2d_vertices_to_pixel = true
		_pickup_viewport.transparent_bg = true
		_pickup_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var index: int = _pickups.get_index()
		_viewport.remove_child(_pickups)
		_pickup_viewport.add_child(_pickups)
		_viewport.add_child(_pickup_viewport)
		_pickup_warp = Sprite2D.new()
		_pickup_warp.name = "PickupWarp"
		_pickup_warp.centered = false
		_pickup_warp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_pickup_warp.texture = _pickup_viewport.get_texture()
		var material := ShaderMaterial.new()
		material.shader = load(PERSPECTIVE_SHADER) as Shader
		_pickup_warp.material = material
		_viewport.add_child(_pickup_warp)
		_viewport.move_child(_pickup_warp, index)
		_pickups.warped = true
	elif not on and _pickup_viewport != null:
		var index: int = _pickup_warp.get_index()
		_viewport.remove_child(_pickup_warp)
		_pickup_warp.queue_free()
		_pickup_warp = null
		_pickup_viewport.remove_child(_pickups)
		_viewport.add_child(_pickups)
		_viewport.move_child(_pickups, index)
		_viewport.remove_child(_pickup_viewport)
		_pickup_viewport.queue_free()
		_pickup_viewport = null
		_pickups.warped = false


# ADR-0002: pushes the current homography (the board moves with the screen size) and the half
# tints to the warp shader (and the same homography, white tints, to the pickups' warp).
func _update_perspective_uniforms() -> void:
	if _floor_warp == null:
		return
	var persp: FloorPerspective = get_floor_perspective()
	var material := _floor_warp.material as ShaderMaterial
	if persp == null or material == null:
		return
	material.set_shader_parameter("inv_h", persp.inverse_uv_basis())
	material.set_shader_parameter("divider_u", persp.divider_u(_combat.get_grid()))
	material.set_shader_parameter("tint_player", PERSPECTIVE_TINT_PLAYER)
	material.set_shader_parameter("tint_enemy", PERSPECTIVE_TINT_ENEMY)
	material.set_shader_parameter("tint_max_v", face_top_v())
	if _pickup_warp != null and _pickup_warp.material is ShaderMaterial:
		var pm := _pickup_warp.material as ShaderMaterial
		pm.set_shader_parameter("inv_h", persp.inverse_uv_basis())
		pm.set_shader_parameter("divider_u", persp.divider_u(_combat.get_grid()))
		pm.set_shader_parameter("tint_player", Color.WHITE)
		pm.set_shader_parameter("tint_enemy", Color.WHITE)


## ADR-0002: the homography the warp shader follows right now (FloorPerspective.of the bound
## CombatView), null while flat.
func get_floor_perspective() -> FloorPerspective:
	return FloorPerspective.of(_combat)


## 2026-11-06 (user: the lip blends with the floor and the platform): the flat V (0..1 of the art canvas height) of
## the lowest deck row, i.e. where the front faces start: the warp shader tints the halves only above it. 1.0 when
## unbound.
func face_top_v() -> float:
	if _combat == null or not is_instance_valid(_combat) or _combat.get_grid() == null:
		return 1.0
	var geo: BoardGeometry = _combat.board_geometry()
	if geo == null:
		return 1.0
	var bottom: int = 0
	for cell: Vector2i in _combat.get_grid().player_cells() + _combat.get_grid().enemy_cells():
		bottom = maxi(bottom, geo.cell_art_rect(cell).end.y)
	return float(bottom + SlabPainter.DECK_MARGIN - 1) / float(ScreenLayout.ART_CANVAS_HEIGHT)


## 2026-11-06: the pickups' own flat SubViewport while the perspective is on (tests), null while flat.
func get_pickup_viewport() -> SubViewport:
	return _pickup_viewport


## ADR-0002: the floor's own SubViewport while the perspective is on (tests), null while flat.
func get_floor_viewport() -> SubViewport:
	return _floor_viewport


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), INK)
	_update_perspective_uniforms()
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), ScreenLayout.art_rect(vp), false)


## The SubViewport the layers draw into.
func get_art_viewport() -> SubViewport:
	return _viewport


## The transparent SubViewport rendering only the units and the overlay (BattleUnitView draws it).
func get_unit_viewport() -> SubViewport:
	return _unit_viewport


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
	if _support != null:
		_support.set_region_id(id)
	if _floor != null:
		_floor.set_region_id(id)


func get_backdrop_layer() -> BackdropLayer:
	return _backdrop


## 2026-11-06: the stone foundation under the board (SupportLayer).
func get_support_layer() -> SupportLayer:
	return _support


func get_floor_layer() -> FloorLayer:
	return _floor


## The voxel pickup layer (field pieces of both halves; forest-integration-pickup-plan step 1).
func get_pickup_layer() -> PickupLayer:
	return _pickups


func get_unit_layer() -> UnitLayer:
	return _units


func get_overlay_layer() -> OverlayLayer:
	return _overlay

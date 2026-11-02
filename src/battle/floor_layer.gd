class_name FloorLayer
extends Node2D
## Floor layer of the battle art canvas (Story 047 Part B, art bible 6.3 / 8.6): the board, drawn in
## art px of the 800x360 SubViewport. The board geometry stays ScreenLayout's (screen px); this layer
## only converts it with [method cell_art_rect]. Draw order: the raised platform B
## (SlabPainter.paint_platform over every real cell of both halves, a front face under cells with no
## real cell below, the deck filling the gap between the halves with its 1 px divider line), the
## 9-slice slab of every real cell with stamps seeded by SlabPainter.cell_seed, the thorn tile on
## thorn cells, the seal overlay on sealed cells. Then its child FloorDynamicLayer (Story 046 Part C) draws the
## boss's telegraph (TelegraphPainter) and the [method add_painter] hooks (the drag target cell). Units draw above
## all of it in UnitLayer.
## The static floor redraws on [method setup], on a screen size change and on [method mark_dirty] (CombatView calls
## it when a zone is applied or expires), never per frame (art bible 8.6); only the dynamic child redraws while a
## boss swing runs.
## A region without slab art falls back to SlabPainter's flat stone and the default platform palette;
## thorn cells without a tile get a flat thorn colour. Nothing here crashes on missing art.
## Implements: Story 047 Part B, Story 046 Part C (dynamic sub-layer).

## P2.3 pattern markers (spec 7.1 / section 8: dark wood-amber root anchor, dark moss wreath; no red, no glow).
const MARKER_ANCHOR: Color = Color("7A5230")
const MARKER_WREATH: Color = Color("4F6B3C")
const MARKER_EDGE: Color = Color("1B1722")
## P2.3 ivory frame (Rootling creep destination, Guard): never red (F6 keeps red for cells that will be hit).
const IVORY_OUTLINE: Color = Color("EDE3C8")

var _combat: CombatView = null
var _painters: Array[Callable] = []
var _region_id: String = ArtAssets.DEFAULT_REGION
var _nine: Texture2D = null
var _stamps_tex: Texture2D = null
var _stamps_meta: Dictionary = {}
var _thorn_tile: Texture2D = null
var _platform_palette: Dictionary = {}
## Multiply tints of the two halves ({"player": Color, "enemy": Color}, ArtAssets.half_tints).
var _half_tints: Dictionary = {}
var _redraws: int = 0
var _dynamic: FloorDynamicLayer = null


func _init() -> void:
	_dynamic = FloorDynamicLayer.new()
	_dynamic.name = "FloorDynamicLayer"
	_dynamic.setup(self)
	add_child(_dynamic)


## Binds the layer to the battle's CombatView (grid, zones and screen size come from it), resolves
## the art region from `match_params["chapter_id"]` (ArtAssets.region_for_chapter) and redraws.
func setup(combat: CombatView) -> void:
	_combat = combat
	# The bind is deferred, so a battle freed within the same frame (flow tests) has no viewport left.
	var vp: Viewport = combat.get_viewport() if combat != null and combat.is_inside_tree() else null
	if vp != null and not vp.size_changed.is_connected(mark_dirty):
		vp.size_changed.connect(mark_dirty)
	var chapter: String = str(combat.match_params.get("chapter_id", "")) if combat != null else ""
	set_region_id(ArtAssets.region_for_chapter(chapter))


## Switches the floor to art region [param id] (its slab 9-slice, stamps, thorn tile and platform
## palette; nulls / defaults when missing) and redraws.
func set_region_id(id: String) -> void:
	_region_id = id
	_nine = ArtAssets.region_texture(id, "slab.nine_slice")
	_stamps_tex = ArtAssets.region_texture(id, "slab.stamps")
	_stamps_meta = ArtAssets.region_stamps(id)
	_thorn_tile = ArtAssets.region_texture(id, "thorn_tile")
	var palette: Variant = ArtAssets.region(id).get("platform", {})
	_platform_palette = palette if palette is Dictionary else {}
	_half_tints = ArtAssets.half_tints(id)
	mark_dirty()


## The multiply tint of the slabs of [param side]'s half (white when the region names none).
func half_tint(side: int) -> Color:
	return _half_tints.get("player" if side == CombatState.Side.PLAYER else "enemy", Color.WHITE)


## ADR-0001 Task 5: the region's `platform` palette block (hex strings; {} = SlabPainter defaults), for the pit colours.
func get_platform_palette() -> Dictionary:
	return _platform_palette


## The art region drawn right now (`forest`, ...).
func get_region_id() -> String:
	return _region_id


## Asks for one redraw (the board, a zone or a cell state changed) of the floor and its dynamic layer. Cheap to
## call repeatedly.
func mark_dirty() -> void:
	queue_redraw()
	if _dynamic != null:
		_dynamic.queue_redraw()


## Number of times `_draw` ran (tests: redraws happen on setup, resize and mark_dirty only).
func get_redraw_count() -> int:
	return _redraws


## Story 046 Part C: number of times the dynamic sub-layer (telegraph + painters) drew (tests).
func get_dynamic_redraw_count() -> int:
	return _dynamic.get_redraw_count() if _dynamic != null else 0


## Story 046 Part C: the dynamic sub-layer drawn after the static floor (telegraph, painters).
func get_dynamic_layer() -> FloorDynamicLayer:
	return _dynamic


## Story 046 Part C: the boss telegraph to draw now (TelegraphPainter.state_for on the boss's CutActor, the
## combat config and SettingsStore reduce motion); {} when unbound or the boss is not swinging.
func telegraph_state() -> Dictionary:
	if _combat == null or not is_instance_valid(_combat) or _combat.get_boss() == null:
		return {}
	var pattern: PatternController = _combat.get_pattern_controller()
	if pattern != null:
		return pattern_telegraph_state(pattern, _combat.get_config(), SettingsStore.shared().get_reduce_motion())
	return TelegraphPainter.state_for(_combat.get_boss().get_actor(), _combat.get_config(), SettingsStore.shared().get_reduce_motion(),
		_combat.get_status())


## Phase 2 (spec 3.6, F6, F7): the pattern brain's warning in TelegraphPainter's shape: `cells` = the snapshotted red
## cells minus locked ones (exactly the cells that will be hit), `queued` = the second lane's sparser stripe, `k` =
## the warning's progress (reduce motion quantized, never hidden). {} when no warning is showing.
static func pattern_telegraph_state(pattern: PatternController, config: CombatConfig, reduce_motion: bool) -> Dictionary:
	if pattern == null or config == null:
		return {}
	var cells: Array[Vector2i] = pattern.telegraph_cells()
	var queued: Array[Vector2i] = []
	for cell: Vector2i in pattern.queued_cells():
		if not cells.has(cell):
			queued.append(cell)
	if cells.is_empty() and queued.is_empty():
		return {}
	return {"cells": cells, "k": config.quantize_progress(pattern.warning_progress(), reduce_motion), "queued": queued}


## P2.3 (spec section 8 "drawn by code"): what the pattern brain shows besides red, for the dynamic layer:
## `markers` = [{cell, kind}] (root anchor / wreath on the enemy half: a dark wood / moss square, no red, no glow),
## `outline` = cells framed in ivory (the Rootling creep's destination while it winds up; the enemy's cells while its
## Guard holds). {} when nothing shows. Drawn UNDER the red (F6).
static func pattern_extras_state(pattern: PatternController, status: StatusEffects, state: CombatState) -> Dictionary:
	if pattern == null:
		return {}
	var marks: Array[Dictionary] = []
	for m: Dictionary in pattern.markers():
		marks.append({"cell": m["cell"], "kind": m["kind"]})
	var outline: Array[Vector2i] = []
	var target: Vector2i = pattern.move_target_cell()
	if target != BoardGrid.NO_CELL:
		outline.append(target)
	if status != null and state != null and status.get_guard_left(CombatState.Side.ENEMY) > 0.0 and not state.is_enemy_dead():
		for cell: Vector2i in state.enemy_footprint_cells():
			if not outline.has(cell):
				outline.append(cell)
	if marks.is_empty() and outline.is_empty():
		return {}
	return {"markers": marks, "outline": outline}


## The pattern extras to draw now ({} for a block-brain match).
func pattern_extras() -> Dictionary:
	if _combat == null or not is_instance_valid(_combat):
		return {}
	return pattern_extras_state(_combat.get_pattern_controller(), _combat.get_status(), _combat.get_state())


# P2.3: marker squares and ivory outlines (see pattern_extras_state), whole art px, flat colours.
func _paint_pattern_extras(canvas: Node2D, extras: Dictionary) -> void:
	for m: Dictionary in extras.get("markers", []) as Array:
		var slab: Rect2i = _slab_of(m["cell"])
		if not slab.has_area():
			continue
		var side: int = maxi(mini(slab.size.x, slab.size.y) * 2 / 5, 4)
		var box: Rect2i = Rect2i(slab.position + (slab.size - Vector2i(side, side)) / 2, Vector2i(side, side))
		var fill: Color = MARKER_WREATH if str(m["kind"]) == "wreath" else MARKER_ANCHOR
		canvas.draw_rect(Rect2(box), MARKER_EDGE)
		canvas.draw_rect(Rect2(box.grow(-1)), fill)
		canvas.draw_rect(Rect2(box.position + Vector2i(2, 2), Vector2i(maxi(side / 4, 1), maxi(side / 4, 1))), fill.lightened(0.25))
	for cell: Vector2i in extras.get("outline", []) as Array:
		var slab2: Rect2i = _slab_of(cell)
		if slab2.has_area():
			canvas.draw_rect(Rect2(slab2.grow(-1)), IVORY_OUTLINE, false, 2.0)


func _slab_of(cell: Vector2i) -> Rect2i:
	var rect: Rect2i = cell_art_rect(cell)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return Rect2i()
	var slab: Rect2i = SlabPainter.slab_rect(rect.size)
	slab.position += rect.position
	return slab


## Story 046 Part C: what the dynamic sub-layer draws on [param canvas]: the pattern extras (P2.3, under the red),
## the telegraph [param state], then every [method add_painter] hook as `fn(canvas, self)`.
func paint_dynamic(canvas: Node2D, state: Dictionary) -> void:
	if _combat == null or not is_instance_valid(_combat) or _combat.get_grid() == null:
		return
	_paint_pattern_extras(canvas, pattern_extras())
	TelegraphPainter.paint(canvas, self, state, _combat.get_config())
	for painter: Callable in _painters:
		if painter.is_valid():
			painter.call(canvas, self)


## Rectangle of board cell [param cell] in art px: ScreenLayout.cell_rect converted with
## ScreenLayout.to_art_rect (the side is resolved from the grid). Empty when unbound.
func cell_art_rect(cell: Vector2i) -> Rect2i:
	if _combat == null or _combat.get_grid() == null:
		return Rect2i()
	var vp: Vector2 = _combat.get_viewport_rect().size
	return ScreenLayout.to_art_rect(vp, ScreenLayout.cell_rect(_combat.get_grid(), vp, cell))


## Registers [param fn] (`fn(canvas: Node2D, floor: FloorLayer)`), run by the dynamic sub-layer after the
## cells and the telegraph and before the units ([param canvas] is that sub-layer). A painter added twice runs once.
func add_painter(fn: Callable) -> void:
	if not _painters.has(fn):
		_painters.append(fn)
	mark_dirty()


## Unregisters a painter added with [method add_painter].
func remove_painter(fn: Callable) -> void:
	_painters.erase(fn)
	mark_dirty()


## Painters registered right now (tests).
func get_painters() -> Array[Callable]:
	return _painters.duplicate()


func _draw() -> void:
	_redraws += 1
	if _combat == null or _combat.get_grid() == null:
		return
	var grid: BoardGrid = _combat.get_grid()
	var vp: Vector2 = _combat.get_viewport_rect().size
	var cells: Array[Vector2i] = grid.player_cells() + grid.enemy_cells()
	var rects: Array[Rect2i] = []
	for cell: Vector2i in cells:
		rects.append(cell_art_rect(cell))
	# Platform B: a front face under every cell with no real cell directly below it (same column, so
	# the same half); the deck between the halves carries the 1 px divider line.
	var has_cell_below: Callable = func(i: int) -> bool: return grid.is_in_board(cells[i] + Vector2i.DOWN)
	var divider_x: int = ScreenLayout.to_art(vp, Vector2(ScreenLayout.divider_x(grid, vp), 0.0)).x
	SlabPainter.paint_platform(self, rects, has_cell_below, _platform_palette, divider_x)
	for i: int in cells.size():
		var side: int = CombatState.Side.PLAYER if grid.is_player_cell(cells[i]) else CombatState.Side.ENEMY
		SlabPainter.paint_cell(self, rects[i], SlabPainter.cell_seed(side, cells[i].x, cells[i].y), _nine, _stamps_tex, _stamps_meta, half_tint(side))
	_draw_zones(grid)


# Thorn cells (tile over the whole slab) and sealed cells of both halves, read from StatusEffects
# the way CutHudView._draw_zones did before Part B (CutHudView keeps only the remaining-time bars).
func _draw_zones(grid: BoardGrid) -> void:
	var status: StatusEffects = _combat.get_status()
	if status == null:
		return
	for side: int in [CombatState.Side.PLAYER, CombatState.Side.ENEMY]:
		for cell: Vector2i in status.thorn_cells(side):
			if grid.is_in_board(cell):
				_draw_thorn_cell(cell_art_rect(cell))


# The 16x16 thorn tile repeated over the slab (art bible 6.3: thorns fill the cell); a region without
# the tile gets a flat thorn colour so the zone stays readable.
func _draw_thorn_cell(rect: Rect2i) -> void:
	var slab: Rect2i = SlabPainter.slab_rect(rect.size)
	slab.position += rect.position
	if _thorn_tile != null:
		SlabPainter.paint_thorns(self, slab, _thorn_tile)
	else:
		draw_rect(Rect2(Vector2(slab.position), Vector2(slab.size)), CutHudView.THORN_SPIKE)


class_name FloorLayer
extends Node2D
## Floor layer of the battle art canvas (Story 047 Part B, art bible 6.3 / 8.6): the board, drawn in
## art px of the 800x360 SubViewport. The board geometry stays ScreenLayout's (screen px); this layer
## only converts it with [method cell_art_rect]. Draw order: the raised platform B
## (SlabPainter.paint_platform over every real cell of both halves, a front face under cells with no
## real cell below, the deck filling the gap between the halves with its 1 px divider line), the
## 9-slice slab of every real cell with stamps seeded by SlabPainter.cell_seed, the thorn tile on
## thorn cells, the seal overlay on sealed cells, then the [method add_painter] hooks (Story 046
## Part C's telegraph cells, the drag target cell). Units draw above all of it in UnitLayer.
## Redraws on [method setup], on a screen size change and on [method mark_dirty] (CombatView calls it
## when a zone is applied or expires), never per frame (art bible 8.6).
## A region without slab art falls back to SlabPainter's flat stone and the default platform palette;
## thorn cells without a tile get a flat thorn colour. Nothing here crashes on missing art.
## Implements: Story 047 Part B.

var _combat: CombatView = null
var _painters: Array[Callable] = []
var _region_id: String = ArtAssets.DEFAULT_REGION
var _nine: Texture2D = null
var _stamps_tex: Texture2D = null
var _stamps_meta: Dictionary = {}
var _thorn_tile: Texture2D = null
var _platform_palette: Dictionary = {}
var _redraws: int = 0


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
	mark_dirty()


## The art region drawn right now (`forest`, ...).
func get_region_id() -> String:
	return _region_id


## Asks for one redraw (the board, a zone or a cell state changed). Cheap to call repeatedly.
func mark_dirty() -> void:
	queue_redraw()


## Number of times `_draw` ran (tests: redraws happen on setup, resize and mark_dirty only).
func get_redraw_count() -> int:
	return _redraws


## Rectangle of board cell [param cell] in art px: ScreenLayout.cell_rect converted with
## ScreenLayout.to_art_rect (the side is resolved from the grid). Empty when unbound.
func cell_art_rect(cell: Vector2i) -> Rect2i:
	if _combat == null or _combat.get_grid() == null:
		return Rect2i()
	var vp: Vector2 = _combat.get_viewport_rect().size
	return ScreenLayout.to_art_rect(vp, ScreenLayout.cell_rect(_combat.get_grid(), vp, cell))


## Registers [param fn] (`fn(canvas: Node2D, floor: FloorLayer)`), run after the cells and before the
## units on every redraw. A painter added twice runs once.
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
		SlabPainter.paint_cell(self, rects[i], SlabPainter.cell_seed(side, cells[i].x, cells[i].y), _nine, _stamps_tex, _stamps_meta)
	_draw_zones(grid)
	for painter: Callable in _painters:
		if painter.is_valid():
			painter.call(self, self)


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
		for cell: Vector2i in status.sealed_cells(side):
			if grid.is_in_board(cell):
				_draw_seal_cell(cell_art_rect(cell))


# The 16x16 thorn tile repeated over the slab (art bible 6.3: thorns fill the cell); a region without
# the tile gets a flat thorn colour so the zone stays readable.
func _draw_thorn_cell(rect: Rect2i) -> void:
	var slab: Rect2i = SlabPainter.slab_rect(rect.size)
	slab.position += rect.position
	if _thorn_tile != null:
		SlabPainter.paint_thorns(self, slab, _thorn_tile)
	else:
		draw_rect(Rect2(Vector2(slab.position), Vector2(slab.size)), CutHudView.THORN_SPIKE)


# Seal: today's CutHudView seal colour as a flat overlay on the slab's face (inside the 9-slice
# margins, above the lip). The real look (the sealed hole / barrier art of art bible 6.3) is a later
# story; drawing it here already puts it under the units instead of over them.
func _draw_seal_cell(rect: Rect2i) -> void:
	var face: Rect2i = SlabPainter.face_rect(rect.size, _stamps_meta)
	face.position += rect.position
	draw_rect(Rect2(Vector2(face.position), Vector2(face.size)), CutHudView.SEAL_FILL)

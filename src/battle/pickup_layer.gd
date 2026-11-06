class_name PickupLayer
extends Node2D
## Pickup layer of the battle art canvas (forest-integration-pickup-plan-2026-11-05 step 1, section 4.2): every field
## point carrying a piece, on either half, drawn as a ground Block pickup ([VoxelPiece]: an Ancient Stone Sigil, a
## flat polyomino of stone squares, 2026-11-06) inside the 800x360 art viewport, between the floor (or its perspective
## warp) and the units. A separate overlay: the floor texture is never touched, and a picked-up piece just stops being
## drawn. The units render in the separate unit pass (BattleUnitView, drawn over the art canvas), so a unit always
## covers a pickup, as the old FieldDropsView order did.
##
## One sigil per point, centred on its cell. 2026-11-06 (user: lie with the stone's tilt): while the floor
## perspective is on, BattleCanvas puts this layer in its own flat SubViewport warped by the floor's own shader (no half
## tints), so the layer draws in the FLAT floor space ([member warped] true: [method anchor_flat], the cell's
## flat size) and every sigil gets the floor's trapezoid; its squares are squashed to the cell's aspect
## (VoxelPiece.edge_y_for) like the stone tiles. Flat floor: [method anchor_art] in the art canvas, as before.
## It lies still: no float, bob, rotation, shadow, sparkle or glow. The floor cell is never tinted.
## Freshness is the crack stage (VoxelPiece.crack_stage of freshness_left / piece_freshness_sec): intact, hairline,
## deep. On FieldDrops.point_expired the piece crumbles in place (VoxelPiece.crumble_left: its squares vanish one by
## one) and then nothing is left. The block colour never changes with freshness. Odd Blocks (Story 041) are muted
## violet; a rotten piece (Story 014) is grey and carries an ink X.
## Within the layer, pickups draw back row first, left to right. Frames are cached as ImageTextures per shape, ramp,
## unit, stage and crack seed. Clock: the match's scaled delta (stops with freeze_time / pause). Classic labelled
## points (no piece) stay in FieldDropsView.
## Tuning: assets/art/vfx/pickup_voxel.json.

## Entries of the texture cache before it is cleared.
const CACHE_MAX: int = 600

var _combat: CombatView = null
var _time: float = 0.0
var _reduce_motion: bool = false
## Active crumbles: {anchor: Vector2i, age: float, seed: int, ramp: String, frame: Dictionary, squares: Array[Rect2i]}.
var _shatters: Array[Dictionary] = []
var _connected: Array[FieldDrops] = []
var _cache: Dictionary = {}
## True while the layer draws in the flat floor space and BattleCanvas warps it with the floor perspective.
var warped: bool = false


## Binds the layer to the battle's CombatView (drops of both halves, geometry, clock). [param settings] is the store
## the reduce-motion flag comes from (the shared one when null).
func setup(combat: CombatView, settings: SettingsStore = null) -> void:
	_combat = combat
	var store: SettingsStore = settings if settings != null else SettingsStore.shared()
	_reduce_motion = store != null and store.get_reduce_motion()
	_connect_sources()
	set_process(combat != null)
	queue_redraw()


## Reduce motion flag (kept for the settings wiring; the sigils have no idle motion to reduce).
func set_reduce_motion(on: bool) -> void:
	_reduce_motion = on


func _process(delta: float) -> void:
	if _combat != null:
		advance(_combat.scaled_delta(delta))
	queue_redraw()


## Advances the layer clock (crumbles) by [param step] match seconds; drops finished shatters.
func advance(step: float) -> void:
	_connect_sources()
	_time += maxf(step, 0.0)
	var keep: Array[Dictionary] = []
	for s: Dictionary in _shatters:
		s["age"] = float(s["age"]) + maxf(step, 0.0)
		if float(s["age"]) < VoxelPiece.shatter_sec():
			keep.append(s)
	_shatters = keep


## The layer clock (seconds).
func get_time() -> float:
	return _time


## The crumbles still running (copies; keys anchor, age, seed, ramp, frame, squares).
func get_shatters() -> Array[Dictionary]:
	return _shatters.duplicate(true)


## Pure: the anchor (art px, the pivot's ground point) of a pickup on board cell [param cell]: the art pixel holding
## the flat cell art rect's exact centre moved onto the drawn floor (BoardGeometry.warp_art; the plain centre pixel
## while flat). Within 0.71 art px of the true perspective centre on every cell (a rounded integer centre then
## warp_art_px drifted up to 1.8 px).
static func anchor_art(geo: BoardGeometry, cell: Vector2i) -> Vector2i:
	return Vector2i(geo.warp_art(Rect2(geo.cell_art_rect(cell)).get_center()).floor())


## Pure: the anchor of a pickup on [param cell] in the FLAT floor space (the layer is warped afterwards with the floor):
## the pixel holding the flat cell art rect's centre.
static func anchor_flat(geo: BoardGeometry, cell: Vector2i) -> Vector2i:
	return Vector2i(Rect2(geo.cell_art_rect(cell)).get_center().floor())


## The flat floor cell aspect (height / width) of [param cell]: the squash of a stone square lying on it.
static func cell_aspect(geo: BoardGeometry, cell: Vector2i) -> float:
	var rect: Rect2i = geo.cell_art_rect(cell)
	return float(rect.size.y) / float(maxi(rect.size.x, 1))


## The square size (art px) of [param piece] on [param cell]: VoxelPiece.edge_for with the cell size on the drawn
## floor at the anchor (back rows are narrower).
static func edge_on(geo: BoardGeometry, piece: Piece, cell: Vector2i) -> int:
	var rect: Rect2i = geo.cell_art_rect(cell)
	var k: Vector2 = geo.art_local_scale(Vector2(rect.get_center()))
	return VoxelPiece.edge_for(piece.relative_cells(), rect.size.x * k.x, rect.size.y * k.y, cell_aspect(geo, cell))


# This layer's anchor of [param cell]: flat space while [member warped], else the warped art canvas.
func _anchor(geo: BoardGeometry, cell: Vector2i) -> Vector2i:
	return anchor_flat(geo, cell) if warped else anchor_art(geo, cell)


# This layer's (x, y) pitch of [param piece] on [param cell]: flat cell size while [member warped].
func _pitch(geo: BoardGeometry, piece: Piece, cell: Vector2i) -> Vector2i:
	var aspect: float = cell_aspect(geo, cell)
	var edge: int = edge_on(geo, piece, cell)
	if warped:
		var rect: Rect2i = geo.cell_art_rect(cell)
		edge = VoxelPiece.edge_for(piece.relative_cells(), rect.size.x, rect.size.y, aspect)
	return Vector2i(edge, VoxelPiece.edge_y_for(edge, aspect))


## What the layer draws this frame, one Dictionary per piece point (both halves), back row first: point, cell,
## anchor (Vector2i), edge, ramp, stage, rotten, frame (VoxelPiece frame dict), sprite_pos (Vector2i top-left of
## the frame in art px). Empty when unbound.
func pickups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _combat == null or not is_instance_valid(_combat) or _combat.get_grid() == null:
		return out
	var geo: BoardGeometry = _combat.board_geometry()
	if geo == null:
		return out
	var cfg: FieldDropsConfig = _combat.get_drops_config()
	var total: float = cfg.piece_freshness_sec if cfg != null else 8.0
	for drops: FieldDrops in _sources():
		for point: FieldPoint in drops.get_points():
			if point.piece == null:
				continue
			out.append(_entry(geo, point, total))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = a["cell"]
		var cb: Vector2i = b["cell"]
		return ca.y < cb.y if ca.y != cb.y else ca.x < cb.x)
	return out


func _entry(geo: BoardGeometry, point: FieldPoint, total: float) -> Dictionary:
	var rotten: bool = point.rotten or point.piece.is_rotten()
	var cells: Array[Vector2i] = point.piece.relative_cells()
	var ratio: float = clampf(point.freshness_left / maxf(total, 0.01), 0.0, 1.0)
	var stage: int = VoxelPiece.crack_stage(ratio)
	var pitch: Vector2i = _pitch(geo, point.piece, point.cell)
	var edge: int = pitch.x
	var ramp: String = VoxelPiece.ramp_id_for(point.piece, rotten)
	var frame: Dictionary = _frame(cells, edge, stage, point.uid, rotten, pitch.y)
	var anchor: Vector2i = _anchor(geo, point.cell)
	var sprite_pos: Vector2i = anchor - (frame["anchor"] as Vector2i)
	return {"point": point, "cell": point.cell, "anchor": anchor, "edge": edge, "ramp": ramp, "stage": stage,
		"rotten": rotten, "frame": frame, "sprite_pos": sprite_pos}


# The frame dict (with its "texture") of the given state, cached.
func _frame(cells: Array[Vector2i], edge: int, stage: int, seed: int, rotten: bool, edge_y: int = 0) -> Dictionary:
	var key: String = "%s|%d|%d|%d|%d|%s" % [str(cells), edge, edge_y, stage, seed if stage > 0 else 0, rotten]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() >= CACHE_MAX:
		_cache.clear()
	var frame: Dictionary = VoxelPiece.render_frame(cells, edge, stage, seed, rotten, edge_y)
	_cache[key] = frame
	return frame


# The texture of [param frame] in [param ramp] (cached on the frame dict per ramp).
func _texture(frame: Dictionary, ramp: String) -> ImageTexture:
	var tex_key: String = "tex_" + ramp
	if not frame.has(tex_key):
		frame[tex_key] = ImageTexture.create_from_image(VoxelPiece.to_image(frame, ramp))
	return frame[tex_key]


func _draw() -> void:
	for p: Dictionary in pickups():
		draw_texture(_texture(p["frame"], str(p["ramp"])), Vector2(p["sprite_pos"] as Vector2i))
	for s: Dictionary in _shatters:
		var frame: Dictionary = s["frame"]
		var tex: ImageTexture = _texture(frame, str(s["ramp"]))
		var pos: Vector2i = (s["anchor"] as Vector2i) - (frame["anchor"] as Vector2i)
		var squares: Array = s["squares"]
		for k: int in VoxelPiece.crumble_left(float(s["age"]), squares.size(), int(s["seed"])):
			var r: Rect2i = squares[k]
			draw_texture_rect_region(tex, Rect2(Vector2(pos + r.position), Vector2(r.size)), Rect2(r))


# The FieldDrops of both halves (player's, then the boss's when present).
func _sources() -> Array[FieldDrops]:
	var out: Array[FieldDrops] = []
	if _combat == null or not is_instance_valid(_combat):
		return out
	if _combat.get_drops() != null:
		out.append(_combat.get_drops())
	if _combat.get_boss() != null and _combat.get_boss().get_drops() != null:
		out.append(_combat.get_boss().get_drops())
	return out


func _connect_sources() -> void:
	for drops: FieldDrops in _sources():
		if _connected.has(drops):
			continue
		_connected.append(drops)
		drops.point_expired.connect(_on_point_expired)


## Starts the crumble of [param point] at its cell (FieldDrops.point_expired; also a sand burial, Story 036): its
## deep-cracked frame, whose squares then vanish one by one.
func _on_point_expired(point: FieldPoint) -> void:
	if point == null or point.piece == null or _combat == null or not is_instance_valid(_combat):
		return
	var geo: BoardGeometry = _combat.board_geometry()
	if geo == null:
		return
	var rotten: bool = point.rotten or point.piece.is_rotten()
	var cells: Array[Vector2i] = point.piece.relative_cells()
	var pitch: Vector2i = _pitch(geo, point.piece, point.cell)
	var squares: Array[Rect2i] = []
	var lo: Vector2i = VoxelPiece.lo_of(cells)
	for c: Vector2i in cells:
		squares.append(VoxelPiece.square_rect(c, lo, pitch.x, pitch.y))
	_shatters.append({"anchor": _anchor(geo, point.cell), "age": 0.0, "seed": point.uid,
		"ramp": VoxelPiece.ramp_id_for(point.piece, rotten),
		"frame": _frame(cells, pitch.x, VoxelPiece.STAGE_DEEP, point.uid, rotten, pitch.y), "squares": squares})
	queue_redraw()

class_name TelegraphPainter
extends RefCounted
## The boss's attack telegraph on the player's half, painted on the floor (Story 046 Part C; art bible 1 P3 and the
## floor-layer rule, 4 telegraph row, 7.4 Ink edge; design/ux/hud.md I-17 / E-17; ASSET-012). Every telegraphed slab
## gets a flat red #E5293B fill, the 8x8 45-degree stripe tile and a 2 px red edge with a 1 px Ink edge outside it,
## all in integer art px and all UNDER the units (FloorDynamicLayer draws it, a child of FloorLayer, before UnitLayer).
## There is no countdown label: the three alphas fade in with the swing's progress k (CutActor.get_progress) and reach
## full strength exactly when the hit lands; reduce motion snaps k to three levels (CombatConfig.quantize_progress).
## A queued combo swing (Story 013) shows at k = 0 with the sparser queued stripe alpha and no fill.
## Red is the telegraph's colour only (art bible P3). Alphas: CombatConfig.telegraph_* (combat.json `telegraph`).
## Implements: Story 046 Part C.

## Telegraph red (art bible 4).
const RED: Color = Color("E5293B")
## Ink (art bible 1): the 1 px edge outside the red edge (red on stone is ~2.1:1, red on Ink ~4:1, art bible 7.4).
const INK: Color = Color("1B1722")
## The stripe tile (ASSET-012): (x + y) mod 4 < 2 opaque red, the rest red at alpha 110; tiles seamlessly.
const STRIPE_PATH: String = "res://assets/art/vfx/fx_telegraph_stripe_8.png"
## Fallback tile drawn by code when the PNG is missing: size, stripe period, opaque run and the light pixels' alpha
## (the same pattern as ASSET-012's script-01).
const STRIPE_TILE_PX: int = 8
const STRIPE_PERIOD_PX: int = 4
const STRIPE_RUN_PX: int = 2
const STRIPE_LIGHT_ALPHA: float = 110.0 / 255.0
## Edge widths in art px.
const EDGE_RED_PX: int = 2
const EDGE_INK_PX: int = 1

static var _fallback_stripe: Texture2D = null


## Pure: what to draw for the boss's [param actor] right now, `{cells, k, queued}` (running cells, the progress
## quantized with [param reduce_motion] by [param config], the queued combo cells the running swing does not cover);
## `{}` when the actor is not swinging (a queued swing only exists while one runs).
static func state_for(actor: CutActor, config: CombatConfig, reduce_motion: bool) -> Dictionary:
	if actor == null or config == null or not actor.is_swinging():
		return {}
	var running: Array[Vector2i] = actor.get_cells()
	var queued: Array[Vector2i] = []
	if actor.has_queued():
		for cell: Vector2i in actor.get_queued_cells():
			if not running.has(cell):
				queued.append(cell)
	return {"cells": running, "k": config.quantize_progress(actor.get_progress(), reduce_motion), "queued": queued}


## Paints [param state] (from [method state_for]) on [param canvas] over the slabs of [param floor]
## (FloorLayer.cell_art_rect). Queued cells first, then the running swing. No-op for `{}`.
static func paint(canvas: CanvasItem, floor: FloorLayer, state: Dictionary, config: CombatConfig) -> void:
	if state.is_empty() or floor == null or config == null:
		return
	var tex: Texture2D = stripe_texture()
	var queued: Array[Vector2i] = state.get("queued", [] as Array[Vector2i])
	var running: Array[Vector2i] = state.get("cells", [] as Array[Vector2i])
	var k: float = float(state.get("k", 0.0))
	_paint_cells(canvas, _slabs(floor, queued), 0.0, config.telegraph_queued_stripe_alpha, config.telegraph_edge_alpha(0.0), tex)
	_paint_cells(canvas, _slabs(floor, running), config.telegraph_fill_alpha(k), config.telegraph_stripe_alpha(k), config.telegraph_edge_alpha(k), tex)


## The stripe tile: the imported PNG (ArtAssets cache), else an 8x8 texture built once by code with the same pattern.
static func stripe_texture() -> Texture2D:
	var tex: Texture2D = ArtAssets.texture(STRIPE_PATH)
	if tex != null:
		return tex
	if _fallback_stripe == null:
		var img: Image = Image.create(STRIPE_TILE_PX, STRIPE_TILE_PX, false, Image.FORMAT_RGBA8)
		for y: int in STRIPE_TILE_PX:
			for x: int in STRIPE_TILE_PX:
				var opaque: bool = (x + y) % STRIPE_PERIOD_PX < STRIPE_RUN_PX
				img.set_pixel(x, y, RED if opaque else Color(RED, STRIPE_LIGHT_ALPHA))
		_fallback_stripe = ImageTexture.create_from_image(img)
	return _fallback_stripe


# The visible slab (SlabPainter.slab_rect) of each cell, in art px.
static func _slabs(floor: FloorLayer, cells: Array[Vector2i]) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for cell: Vector2i in cells:
		var rect: Rect2i = floor.cell_art_rect(cell)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var slab: Rect2i = SlabPainter.slab_rect(rect.size)
		slab.position += rect.position
		out.append(slab)
	return out


# Ink edges of every slab first (so a neighbour's red edge is never inked over), then per slab: fill, stripes, red edge.
static func _paint_cells(canvas: CanvasItem, slabs: Array[Rect2i], fill_alpha: float, stripe_alpha: float, edge_alpha: float, tex: Texture2D) -> void:
	if slabs.is_empty():
		return
	for slab: Rect2i in slabs:
		_ring(canvas, slab.grow(EDGE_INK_PX), EDGE_INK_PX, Color(INK, edge_alpha))
	for slab: Rect2i in slabs:
		if fill_alpha > 0.0:
			canvas.draw_rect(Rect2(slab), Color(RED, fill_alpha))
		if stripe_alpha > 0.0 and tex != null:
			_tile(canvas, tex, slab, stripe_alpha)
		_ring(canvas, slab, EDGE_RED_PX, Color(RED, edge_alpha))


# The stripe tile repeated over [param rect], aligned to the art-px grid (not the slab), so stripes run on across
# neighbouring slabs; the source region is clipped at every edge, nothing spills.
static func _tile(canvas: CanvasItem, tex: Texture2D, rect: Rect2i, alpha: float) -> void:
	var tw: int = tex.get_width()
	var th: int = tex.get_height()
	if tw <= 0 or th <= 0:
		return
	var tint := Color(1.0, 1.0, 1.0, alpha)
	var y: int = rect.position.y
	while y < rect.end.y:
		var sy: int = posmod(y, th)
		var h: int = mini(th - sy, rect.end.y - y)
		var x: int = rect.position.x
		while x < rect.end.x:
			var sx: int = posmod(x, tw)
			var w: int = mini(tw - sx, rect.end.x - x)
			canvas.draw_texture_rect_region(tex, Rect2(x, y, w, h), Rect2(sx, sy, w, h), tint)
			x += w
		y += h


# A [param width]-px frame just inside [param rect], as four filled integer rects (no half-pixel line edges).
static func _ring(canvas: CanvasItem, rect: Rect2i, width: int, color: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var w: int = mini(width, mini(rect.size.x, rect.size.y))
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, w), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - w, rect.size.x, w), color)
	var inner: int = rect.size.y - w * 2
	if inner > 0:
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y + w, w, inner), color)
		canvas.draw_rect(Rect2(rect.end.x - w, rect.position.y + w, w, inner), color)

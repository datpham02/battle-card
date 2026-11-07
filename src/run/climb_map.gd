class_name ClimbMap
extends RefCounted
## 2026-11-07 (user: a climb map like the approved concept; the player climbs every region from the bottom to the
## Lattice Heart, taps the floor's island (it lights up) and taps again or presses "Vào tầng" to enter): the pure layout
## of the Tower Ascent map and its drawing helpers. The map is a tall strip in "map space" (y grows down): one island
## per floor zig-zagging up from the bottom, the final cube on top; WorldMapView scrolls it so the current floor sits at
## FOCUS_Y. Islands are PixelLab sprites (`assets/art/ui/climb/islands.json`: sprite + anchors in art px), drawn at the
## whole-number UI scale like the hero; a region without a sprite gets a code-drawn angular island of the same size.
## Spec: design/art/climb-map-asset-spec-2026-11-07.md.

## Island sprite size in art px (all islands share it, so the zig-zag stays even).
const ISLAND_ART: Vector2 = Vector2(320, 192)
## Vertical distance between two floors' island centres, share of the screen height.
const STEP: float = 0.23
## Map space below the first island's centre and above the last one's (the summit), shares of the screen height.
const BOTTOM_MARGIN: float = 0.36
const TOP_RESERVE: float = 0.6
## Island centres' x as shares of the width: even floors left, odd floors right.
const ZIG_X: Array[float] = [0.4, 0.6]
## Where the current floor's island centre sits on screen (share of the height): low, so the climb above shows.
const FOCUS_Y: float = 0.72
## 2026-11-07 (user: the concept shows the whole climb at once): the current island is drawn near (the art scale), every
## other island far, at FAR_SCALE of it, so 3-4 islands and the summit share the screen.
const FAR_SCALE: float = 0.5
## The cube's centre (map space, share of the screen height), its crop of the title art (art px) and its scale (x the
## art scale: the summit is the map's strongest landmark).
const CUBE_Y: float = 0.32
const CUBE_SCALE: float = 1.0
const CUBE_SRC: Rect2 = Rect2(280, 0, 166, 120)
const ISLANDS_FILE: String = "res://assets/art/ui/climb/islands.json"
## Layer art (PixelLab G2-G4, 2026-11-07): the far sky (640x424, it slides SKY_TRAVEL of its spare height over the whole
## scroll), the cloud clumps (128x48, transparent ends: they repeat with gaps, so no seam) and the stair blocks (32x32,
## two steps rising to the upper left; mirrored for a stair going right).
const SKY_FAR: String = "res://assets/art/ui/climb/sky_far.png"
const CLOUDS: Array[String] = ["res://assets/art/ui/climb/cloud_0.png", "res://assets/art/ui/climb/cloud_1.png",
	"res://assets/art/ui/climb/cloud_2.png", "res://assets/art/ui/climb/cloud_3.png"]
const STEPS: Array[String] = ["res://assets/art/ui/climb/stair_step_0.png", "res://assets/art/ui/climb/stair_step_1.png",
	"res://assets/art/ui/climb/stair_step_2.png", "res://assets/art/ui/climb/stair_step_3.png"]
## Cloud layer: parallax (share of the map scroll), rows per screen, the clumps' alpha.
const CLOUD_PARALLAX: float = 0.4
const CLOUD_ROWS_PER_SCREEN: float = 2.5
const CLOUD_ALPHA: float = 0.8
## Stair blocks: art px along the stair between two blocks, and the state tints (done: warm lattice gold, next: lit,
## locked: grey-violet).
const STEP_SPACING_ART: float = 9.0
## Stair blocks are drawn at this share of the art scale (a fine stairway, like the concept).
const STEP_SCALE: float = 0.5
## 2026-11-07 (user: "fix the perspective first"): the map's 2.5D projection, the elevated three-quarter view of the
## concept and of the island sprites. World axes: X across (right), Z into the scene (depth), H height (up). Screen:
## x = X, y = -(Z * DEPTH_K) - H. Going deeper or higher both move up the screen; depth is foreshortened by DEPTH_K.
const DEPTH_K: float = 0.5
## Share of a floor's screen rise that is height (the rest is depth): stairs climb through both.
const RISE_HEIGHT_SHARE: float = 0.55
## Stair steps (world px at map scale 1): tread width across the stair, riser height cap, steps per stair, and the
## step colours (tread lit from the upper left, riser in shade, foundations darker).
const STAIR_WIDTH: float = 46.0
const STAIR_STEPS: int = 16
## Depth (world px) of the solid stringer under the steps.
const STRINGER: float = 14.0
const TREAD: Color = Color("7A7B70")
const TREAD_TONES: Array[Color] = [Color("7A7B70"), Color("6A6B62"), Color("85867A")]
## Colours taken from an island sprite for its stairs ([method island_ramp]).
const RAMP_SIZE: int = 10
## Colours more saturated than this (accents) are left out of an island's stair ramp.
const RAMP_MAX_SATURATION: float = 0.42
const TREAD_LIP: Color = Color("A4ACB4")
const MOSS: Color = Color("5E6B55")
const RISER: Color = Color("4C4D47")
const FOUNDATION: Color = Color("3A3B37")
## Placeholder islands (until a region's sprite exists): top face depth and front wall height (world px, map scale 1).
const PRISM_DEPTH: float = 120.0
const PRISM_WALL: float = 26.0
## Bridge foundations under the stair: every Nth block, how many darker blocks hang below, and their shade.
const SUPPORT_EVERY: int = 3
const SUPPORT_DEPTH: int = 2
const SUPPORT_SHADE: float = 0.55
const STAIR_DONE_TINT: Color = Color(1.0, 0.97, 0.88)
const STAIR_NEXT_TINT: Color = Color(1.0, 1.0, 1.0)
const STAIR_LOCKED_TINT: Color = Color(0.55, 0.52, 0.66)
## Colours.
const SKY_TOP: Color = Color("15131F")
const SKY_BOTTOM: Color = Color("3A3550")
const STAIR_LIT: Color = Color("F8C838")
const STAIR_DIM: Color = Color("4A4560")
const INK: Color = Color("15131B")
const GLOW: Color = Color("FFD45C")
const DONE_TINT: Color = Color(0.92, 0.92, 0.95)
## Locked islands: darker and desaturated, never black (the brief).
const LOCKED_TINT: Color = Color(0.62, 0.6, 0.72)
## Code-drawn placeholder islands: base stone, top, and how far they lean to the region's fallback colours.
const PLACEHOLDER_STONE: Color = Color("5A5B54")
const PLACEHOLDER_TOP: Color = Color("8E98A4")
const PLACEHOLDER_LEAN: float = 0.4

static var _data: Dictionary = {}
static var _textures: Dictionary = {}
static var _fx_cache: Dictionary = {}


## Pure: the whole-number art scale of the map on a [param vp] screen (the hero's and the islands').
static func art_scale(vp: Vector2) -> float:
	return float(PixelFrame.scale_for(vp.y))


## Pure: the map's height in px for [param floors] floors on a [param vp] screen.
static func map_height(vp: Vector2, floors: int) -> float:
	return vp.y * (BOTTOM_MARGIN + TOP_RESERVE + STEP * maxi(floors - 1, 0))


## Pure: the centre (map space) of the island of 0-based [param index] among [param floors].
static func island_center(vp: Vector2, index: int, floors: int) -> Vector2:
	var bottom: float = map_height(vp, floors) - vp.y * BOTTOM_MARGIN
	return Vector2(roundf(vp.x * ZIG_X[index % ZIG_X.size()]), roundf(bottom - vp.y * STEP * index))


## Pure: the draw scale of island [param index] when [param current] is the current floor (-1 = all near).
static func island_scale(vp: Vector2, index: int, current: int = -1) -> float:
	# 2026-11-07 (user: the concept's view): every island, the hero and the summit share one scale, half the UI art
	# scale (1x at 720p: an island ~320 px wide, the hero ~65 px tall, as measured on the concept); the current island
	# is marked by the hero, its marker and the glow, not by size. [param index] / [param current] kept for callers.
	var _unused: Array = [index, current]
	return map_scale(vp)


## Pure: the one draw scale of the climb map's art (islands, hero, summit, stairs).
static func map_scale(vp: Vector2) -> float:
	return maxf(roundf(art_scale(vp) * FAR_SCALE), 1.0)


## Pure: the island's rect (map space): the sprite size at its scale ([method island_scale]), centred.
static func island_rect(vp: Vector2, index: int, floors: int, current: int = -1) -> Rect2:
	var size: Vector2 = ISLAND_ART * island_scale(vp, index, current)
	return Rect2((island_center(vp, index, floors) - size * 0.5).round(), size)


## Pure: the cube's centre (map space).
static func cube_center(vp: Vector2) -> Vector2:
	return Vector2(vp.x * 0.5, vp.y * CUBE_Y)


## Pure: the scroll (px, map y shown at the screen's top) that puts floor [param floor] at FOCUS_Y, clamped to the
## map; the top of the map (the cube) once the floors are done.
static func scroll_for(vp: Vector2, floor: int, floors: int) -> float:
	var max_scroll: float = map_height(vp, floors) - vp.y
	if floor >= floors:
		return 0.0
	return clampf(island_center(vp, floor, floors).y - vp.y * FOCUS_Y, 0.0, max_scroll)


## The island entry of [param region] in ISLANDS_FILE merged over its default anchors: {sprite (res:// path or ""),
## feet, stair_in, stair_out, marker (Vector2, art px)}.
static func island_info(region: String) -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ISLANDS_FILE)) if FileAccess.file_exists(ISLANDS_FILE) else null
		_data = parsed if parsed is Dictionary else {"default_anchors": {}, "islands": {}}
	var base: Dictionary = (_data.get("default_anchors", {}) as Dictionary).duplicate()
	var own: Dictionary = ((_data.get("islands", {}) as Dictionary).get(region, {}) as Dictionary)
	base.merge(own, true)
	var out: Dictionary = {"sprite": ""}
	for key: String in ["feet", "stair_in", "stair_out", "marker", "edge_left", "edge_right", "back_left", "back_right"]:
		var v: Variant = base.get(key, [160, 104])
		out[key] = Vector2(float((v as Array)[0]), float((v as Array)[1])) if v is Array else ISLAND_ART * 0.5
	if base.has("sprite"):
		out["sprite"] = ISLANDS_FILE.get_base_dir() + "/" + str(base["sprite"])
	if base.get("fx") is Dictionary:
		out["fx"] = base["fx"]
	return out


## The island sprite of [param region] (null without one).
static func island_texture(region: String) -> Texture2D:
	var path: String = str(island_info(region)["sprite"])
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = ArtAssets.texture(path)
	return _textures[path]


## Pure: an anchor (art px of the sprite) of the island drawn at [param r] as a screen / map point.
static func anchor_point(r: Rect2, anchor: Vector2) -> Vector2:
	return r.position + anchor * (r.size.x / ISLAND_ART.x)


## Pure: a code-drawn island's outline in [param r] (angular, clockwise from the top-left): a flat top with cut corners
## over a rocky underside tapering to a point (no curves: the UI rule).
static func island_shape(r: Rect2) -> PackedVector2Array:
	var w: float = r.size.x
	var h: float = r.size.y
	var p: Vector2 = r.position + Vector2(0.0, h * 0.4)
	h *= 0.6
	return PackedVector2Array([
		p + Vector2(w * 0.08, 0.0), p + Vector2(w * 0.92, 0.0), p + Vector2(w, h * 0.16),
		p + Vector2(w * 0.86, h * 0.42), p + Vector2(w * 0.7, h * 0.58), p + Vector2(w * 0.6, h * 0.86),
		p + Vector2(w * 0.5, h), p + Vector2(w * 0.38, h * 0.8), p + Vector2(w * 0.26, h * 0.6),
		p + Vector2(w * 0.12, h * 0.44), p + Vector2(0.0, h * 0.16),
	])


## Pure: the stair polyline from [param from] to [param to]: steps of equal rise and run.
static func stair_points(from: Vector2, to: Vector2, steps: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array([from])
	var d: Vector2 = (to - from) / float(maxi(steps, 1))
	var at: Vector2 = from
	for _i: int in steps:
		at += Vector2(0.0, d.y)
		pts.append(at)
		at += Vector2(d.x, 0.0)
		pts.append(at)
	return pts


## The sky: the far layer (whole-number scaled, sliding over its spare height as the map scrolls), else a gradient;
## then the cloud clumps on their own parallax rows.
static func draw_sky(canvas: CanvasItem, vp: Vector2, scroll: float, floors: int) -> void:
	var far: Texture2D = _tex(SKY_FAR)
	var max_scroll: float = maxf(map_height(vp, floors) - vp.y, 1.0)
	if far != null:
		var k: float = maxf(ceilf(vp.x / far.get_width()), art_scale(vp))
		var size: Vector2 = Vector2(far.get_size()) * k
		var spare: float = maxf(size.y - vp.y, 0.0)
		var y: float = -spare * (1.0 - clampf(scroll / max_scroll, 0.0, 1.0))
		canvas.draw_texture_rect(PixelFrame.nearest(far), Rect2(Vector2(roundf((vp.x - size.x) * 0.5), roundf(y)), size), false)
	else:
		var bands: int = 24
		var h: float = map_height(vp, floors)
		for i: int in bands:
			var y0: float = vp.y * i / bands
			var t: float = clampf((y0 + scroll) / h, 0.0, 1.0)
			canvas.draw_rect(Rect2(0.0, floorf(y0), vp.x, ceilf(vp.y / bands) + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
	draw_clouds(canvas, vp, scroll)


## Pure: the cloud clumps on screen at [param scroll]: [{index (CLOUDS), pos (screen, top-left)}], deterministic rows
## of one clump each, placed by a hash of the row (no RNG state), moving at CLOUD_PARALLAX.
static func cloud_slots(vp: Vector2, scroll: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gap: float = vp.y / CLOUD_ROWS_PER_SCREEN
	var shift: float = scroll * CLOUD_PARALLAX
	var first: int = floori(shift / gap) - 1
	for row: int in range(first, first + int(CLOUD_ROWS_PER_SCREEN) + 3):
		var h: int = absi(hash(row * 7919 + 17))
		var x: float = vp.x * (0.05 + float(h % 1000) / 1000.0 * 0.75)
		out.append({"index": h % CLOUDS.size(), "pos": Vector2(roundf(x), roundf(row * gap - shift))})
	return out


static func draw_clouds(canvas: CanvasItem, vp: Vector2, scroll: float) -> void:
	var k: float = art_scale(vp)
	for slot: Dictionary in cloud_slots(vp, scroll):
		var tex: Texture2D = _tex(CLOUDS[int(slot["index"])])
		if tex != null:
			canvas.draw_texture_rect(PixelFrame.nearest(tex), Rect2(slot["pos"], Vector2(tex.get_size()) * k), false, Color(1, 1, 1, CLOUD_ALPHA))


## Pure: the stair blocks from [param from] to [param to] (screen / map px) at art scale [param k]: [{pos (the block's
## centre), index (STEPS), flip}], from the top block down (draw order: back first), one every STEP_SPACING_ART art px.
static func stair_blocks(from: Vector2, to: Vector2, k: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = maxi(ceili(from.distance_to(to) / (STEP_SPACING_ART * k)), 1)
	var flip: bool = to.x > from.x
	for i: int in range(n, -1, -1):
		var p: Vector2 = from.lerp(to, float(i) / float(n))
		out.append({"pos": p.round(), "index": absi(hash(i * 31 + int(from.x))) % STEPS.size(), "flip": flip})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y)
	return out


## A stair of blocks from [param from] to [param to] tinted [param tint] (a 4 px line when the block art is missing).
## 2026-11-07 (user: the concept's stairways are broad stone causeways with hanging masonry under them): every
## SUPPORT_EVERY-th block hangs SUPPORT_DEPTH darker blocks below it (the bridge's foundations), drawn first.
## [param near] = the stair touches the current (near) island: its blocks are drawn at the full art scale.
static func draw_stair(canvas: CanvasItem, vp: Vector2, from: Vector2, to: Vector2, tint: Color, near: bool = false) -> void:
	var k: float = art_scale(vp) if near else maxf(roundf(art_scale(vp) * STEP_SCALE), 1.0)
	if _tex(STEPS[0]) == null:
		canvas.draw_polyline(stair_points(from, to), tint, 4.0)
		return
	var blocks: Array[Dictionary] = stair_blocks(from, to, k)
	var support: Color = Color(tint.r * SUPPORT_SHADE, tint.g * SUPPORT_SHADE, tint.b * SUPPORT_SHADE * 1.1, tint.a)
	for n: int in blocks.size():
		if n % SUPPORT_EVERY != 1:
			continue
		var b: Dictionary = blocks[n]
		for d: int in range(SUPPORT_DEPTH, 0, -1):
			_draw_block(canvas, b, k, Vector2(0.0, d * 13.0 * k), support)
	for b: Dictionary in blocks:
		_draw_block(canvas, b, k, Vector2.ZERO, tint)


static func _draw_block(canvas: CanvasItem, b: Dictionary, k: float, shift: Vector2, tint: Color) -> void:
	var tex: Texture2D = _tex(STEPS[int(b["index"])])
	var size: Vector2 = Vector2(tex.get_size()) * k
	var rect := Rect2((b["pos"] as Vector2) + shift - size * 0.5, size)
	if bool(b["flip"]):
		rect = Rect2(rect.position + Vector2(size.x, 0.0), Vector2(-size.x, size.y))
	canvas.draw_texture_rect(PixelFrame.nearest(tex), rect, false, tint)


## Pure: the 2.5D steps of a stair from landing [param from] to landing [param to] (screen points on the two islands'
## walk surfaces, [param from] lower): the screen rise is split into height (RISE_HEIGHT_SHARE) and depth, the run
## goes through X and Z, each step is a tread (the top face, a parallelogram across the travel) and a riser (its front
## face, one step of height). Returns [{tread: PackedVector2Array, riser: PackedVector2Array, foot: Vector2}] from the
## top step down (draw order: far first). [param k] = the map scale.
static func stair_steps(from: Vector2, to: Vector2, k: float, steps: int = STAIR_STEPS) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rise_screen: float = maxf(from.y - to.y, 1.0)
	var h_total: float = rise_screen * RISE_HEIGHT_SHARE
	var z_total: float = (rise_screen - h_total) / DEPTH_K
	var dx: float = to.x - from.x
	# The travel in the ground plane (X, Z) and the across direction, both projected to the screen.
	var travel_xz := Vector2(dx, z_total)
	var across_xz := Vector2(-travel_xz.y, travel_xz.x).normalized() * STAIR_WIDTH * k * 0.5
	var across := Vector2(across_xz.x, -across_xz.y * DEPTH_K)
	var run := Vector2(dx, -z_total * DEPTH_K) / float(steps)
	var riser_h: float = h_total / float(steps)
	for i: int in range(steps - 1, -1, -1):
		# Step i's tread sits at height (i + 1) risers above the start, from run i to run i + 1.
		var base: Vector2 = from + run * float(i) - Vector2(0.0, riser_h * float(i + 1))
		var front_l: Vector2 = base - across
		var front_r: Vector2 = base + across
		var back_l: Vector2 = front_l + run
		var back_r: Vector2 = front_r + run
		var tread := PackedVector2Array([front_l, back_l, back_r, front_r])
		var riser := PackedVector2Array([front_l, front_r, front_r + Vector2(0.0, riser_h), front_l + Vector2(0.0, riser_h)])
		out.append({"tread": tread, "riser": riser, "foot": base + Vector2(0.0, riser_h)})
	return out


## A 2.5D stair from [param from] to [param to] (screen landings) tinted [param tint]: hanging foundations every
## SUPPORT_EVERY steps (darker, tapering down), then each step's riser and tread with an Ink edge, far steps first.
static func draw_stair_25d(canvas: CanvasItem, vp: Vector2, from: Vector2, to: Vector2, tint: Color, region: String = "") -> void:
	var k: float = map_scale(vp)
	# Colours of the island the stair leaves from (its ramp, darkest first), else the default stone.
	var ramp: Array[Color] = island_ramp(region)
	var tones: Array[Color] = TREAD_TONES
	var riser_c: Color = RISER
	var found_c: Color = FOUNDATION
	var lip_c: Color = TREAD_LIP
	if ramp.size() >= 6:
		var n: int = ramp.size()
		tones = [ramp[n - 3], ramp[n - 4], ramp[n - 2]] as Array[Color]
		riser_c = ramp[maxi(n - 6, 1)]
		found_c = ramp[1]
		lip_c = ramp[n - 1]
	var steps: Array[Dictionary] = stair_steps(from, to, k)
	# The stair's body: a solid stringer under the steps on the side facing the viewer (the lower screen edge of each
	# tread), STRINGER px deep, so the steps read as one carved stairway and not loose slabs.
	var edge_top := PackedVector2Array()
	for st: Dictionary in steps:
		var rz: PackedVector2Array = st["riser"]
		edge_top.append(rz[3] if rz[3].y >= rz[2].y else rz[2])
	if edge_top.size() >= 2:
		var body := PackedVector2Array(edge_top)
		for j: int in range(edge_top.size() - 1, -1, -1):
			body.append(edge_top[j] + Vector2(0.0, STRINGER * k))
		canvas.draw_colored_polygon(body, found_c * tint)
		var outline: PackedVector2Array = body.duplicate()
		outline.append(body[0])
		canvas.draw_polyline(outline, INK, 1.0)
	for n: int in steps.size():
		if n % SUPPORT_EVERY != 1:
			continue
		var r: PackedVector2Array = steps[n]["riser"]
		var bl: Vector2 = r[3]
		var br: Vector2 = r[2]
		var drop: float = 22.0 * k
		var hang := PackedVector2Array([bl, br, br + Vector2(-(br.x - bl.x) * 0.2, drop), bl + Vector2((br.x - bl.x) * 0.2, drop)])
		canvas.draw_colored_polygon(hang, found_c * tint)
		var closed: PackedVector2Array = hang.duplicate()
		closed.append(hang[0])
		canvas.draw_polyline(closed, INK, 1.0)
	for n: int in steps.size():
		var st: Dictionary = steps[n]
		var riser: PackedVector2Array = st["riser"]
		var tread: PackedVector2Array = st["tread"]
		# G1's stone: each tread one of three worn greys (a hash of its index), a lit front lip, a mossy fleck now and then.
		var tone: Color = tones[absi(hash(n * 13 + 7)) % tones.size()]
		canvas.draw_colored_polygon(riser, riser_c * tint)
		canvas.draw_colored_polygon(tread, tone * tint)
		canvas.draw_line(tread[0], tread[3], lip_c * tint, 1.0)
		if absi(hash(n * 31 + 3)) % 5 == 0:
			var m: Vector2 = (tread[0] + tread[2]) * 0.5
			canvas.draw_rect(Rect2(m.round(), Vector2(2, 1)), MOSS * tint)
		var edge: PackedVector2Array = tread.duplicate()
		edge.append(tread[0])
		canvas.draw_polyline(edge, INK, 1.0)
		canvas.draw_line(riser[3], riser[2], INK, 1.0)


## The stair root piece (ST1) placed with its landing on [param at] (screen): {rect (screen, mirrored when going
## left), exit (screen point where the run continues), tex}; {} without the sprite.
static func stair_root_at(vp: Vector2, at: Vector2, going_right: bool) -> Dictionary:
	if _data.is_empty():
		island_info("")
	var info: Dictionary = _data.get("stair_root", {})
	var tex: Texture2D = _tex(ISLANDS_FILE.get_base_dir() + "/" + str(info.get("sprite", ""))) if info.has("sprite") else null
	if tex == null or not bool(info.get("enabled", true)):
		return {}
	# 2026-11-07 (user: the island-to-stair joint did not match): only the steps of the piece (`crop`), so the first
	# step rises straight out of the island's own built-in landing; `landing` / `exit` are in crop coordinates.
	var src := Rect2(Vector2.ZERO, Vector2(tex.get_size()))
	if info.get("crop") is Array:
		var c: Array = info["crop"]
		src = Rect2(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	var k: float = map_scale(vp)
	var size: Vector2 = src.size * k
	var landing := Vector2(float(info["landing"][0]), float(info["landing"][1])) * k
	var exit := Vector2(float(info["exit"][0]), float(info["exit"][1])) * k
	if not going_right:
		landing.x = size.x - landing.x
		exit.x = size.x - exit.x
	var pos: Vector2 = (at - landing).round()
	var rect := Rect2(pos, size)
	if not going_right:
		rect = Rect2(pos + Vector2(size.x, 0.0), Vector2(-size.x, size.y))
	return {"rect": rect, "exit": pos + exit, "tex": tex, "src": src}


## The chained middle run (ST2) from [param start] (screen, the root's exit) toward [param target]: a whole number of
## segments along the segment's own step (mirrored going left), as many as best cover the distance. Returns
## {pieces: [{rect, src}] far first, end (screen point where the last segment's top lands), tex}; {} without art.
static func stair_run(vp: Vector2, start: Vector2, target: Vector2, going_right: bool) -> Dictionary:
	if _data.is_empty():
		island_info("")
	var info: Dictionary = _data.get("stair_segment", {})
	var tex: Texture2D = _tex(ISLANDS_FILE.get_base_dir() + "/" + str(info.get("sprite", ""))) if info.has("sprite") else null
	if tex == null:
		return {}
	var k: float = map_scale(vp)
	var size: Vector2 = Vector2(tex.get_size()) * k
	var foot := Vector2(float(info["foot"][0]), float(info["foot"][1])) * k
	var step := Vector2(float(info["step"][0]), float(info["step"][1])) * k
	if not going_right:
		foot.x = size.x - foot.x
		step.x = -step.x
	var n: int = maxi(roundi((target - start).length() / step.length()), 1)
	var pieces: Array[Dictionary] = []
	for i: int in range(n - 1, -1, -1):
		var pos: Vector2 = (start + step * float(i) - foot).round()
		var rect := Rect2(pos, size)
		if not going_right:
			rect = Rect2(pos + Vector2(size.x, 0.0), Vector2(-size.x, size.y))
		pieces.append({"rect": rect})
	var beam := PackedVector2Array()
	if info.get("beam") is Dictionary:
		var bo := Vector2(float(info["beam"]["offset"][0]), float(info["beam"]["offset"][1])) * k
		if not going_right:
			bo.x = -bo.x
		var depth: float = float(info["beam"]["depth"]) * k
		var a0: Vector2 = start + bo
		var a1: Vector2 = start + step * float(n) + bo
		beam = PackedVector2Array([a0, a1, a1 + Vector2(0.0, depth), a0 + Vector2(0.0, depth)])
	return {"pieces": pieces, "end": start + step * float(n), "tex": tex, "beam": beam}


## Draws a [method stair_run] tinted [param tint], recoloured to [param region]'s ramp: first the continuous
## foundation beam under the whole run (the tiles' own stone colours, an Ink edge), then the tiles, far first.
static func draw_stair_run(canvas: CanvasItem, run: Dictionary, tint: Color, region: String = "") -> void:
	if run.is_empty():
		return
	var tex: Texture2D = run["tex"]
	var ramp: Array[Color] = island_ramp(region)
	if not ramp.is_empty():
		tex = recoloured(tex, ramp, "run:" + region)

	for piece: Dictionary in run["pieces"]:
		canvas.draw_texture_rect(PixelFrame.nearest(tex), piece["rect"], false, tint)
	# The foundation beam over the wall's stepped underside (each tile's wall ends in a tooth): one straight course with
	# a lit top lip and an Ink edge, so the stair reads as one structure.
	var beam: PackedVector2Array = run.get("beam", PackedVector2Array())
	if beam.size() == 4:
		var face: Color = ramp[maxi(ramp.size() / 3, 0)] if not ramp.is_empty() else FOUNDATION
		var lip: Color = ramp[maxi(ramp.size() / 2, 0)] if not ramp.is_empty() else RISER
		canvas.draw_colored_polygon(beam, face * tint)
		canvas.draw_line(beam[0], beam[1], lip * tint, 1.0)
		var edge: PackedVector2Array = beam.duplicate()
		edge.append(beam[0])
		canvas.draw_polyline(edge, INK, 1.0)


## True when [param region]'s island sprite has a departure landing built in (islands.json `landing_out`).
static func has_landing_out(region: String) -> bool:
	island_info(region)
	return bool(((_data.get("islands", {}) as Dictionary).get(region, {}) as Dictionary).get("landing_out", false))


## Draws a root piece from [method stair_root_at] tinted [param tint], recoloured to [param region]'s ramp (the
## island the stair leaves from: user 2026-11-07, "the stair takes the colour of the island it starts from").
static func draw_stair_root(canvas: CanvasItem, root: Dictionary, tint: Color, region: String = "") -> void:
	if root.is_empty():
		return
	var tex: Texture2D = root["tex"]
	var ramp: Array[Color] = island_ramp(region)
	if not ramp.is_empty():
		tex = recoloured(tex, ramp, "root:" + region)
	canvas.draw_texture_rect_region(PixelFrame.nearest(tex), root["rect"], root.get("src", Rect2(Vector2.ZERO, Vector2(tex.get_size()))), tint)


## The dominant colours of [param region]'s island sprite, darkest first: the RAMP_SIZE most frequent opaque
## colours (cached). [] without a sprite.
static func island_ramp(region: String) -> Array[Color]:
	var key: String = "ramp:" + region
	if _textures.has(key):
		return _textures[key]
	var out: Array[Color] = []
	var tex: Texture2D = island_texture(region) if not region.is_empty() else null
	if tex != null:
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		# 2026-11-07 (user: the stair was much darker than the island): only the stone the stair touches, the island's
		# `ramp_sample` rect (its landing), else a band around its feet anchor on the walk surface.
		var own: Dictionary = ((_data.get("islands", {}) as Dictionary).get(region, {}) as Dictionary)
		var feet: Vector2 = island_info(region)["feet"]
		var area := Rect2i(int(feet.x) - 40, int(feet.y) - 8, 80, 18)
		if own.get("ramp_sample") is Array:
			var r: Array = own["ramp_sample"]
			area = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		var seen: Dictionary = {}
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var c: Color = img.get_pixel(x, y)
				# Stone only: strong accents (lava orange, waterfall blue) never colour a stair.
				if c.a > 0.5 and c.s <= RAMP_MAX_SATURATION:
					seen[c.to_html(false)] = true
		var all: Array[Color] = []
		for h: Variant in seen.keys():
			all.append(Color.html(str(h)))
		all.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
		if all.size() <= RAMP_SIZE:
			out = all
		else:
			for i: int in RAMP_SIZE:
				out.append(all[roundi(float(i) / float(RAMP_SIZE - 1) * float(all.size() - 1))])
	_textures[key] = out
	return out


## [param tex] with every colour replaced, by luminance rank, with the matching colour of [param ramp] (darkest to
## darkest, lightest to lightest; no pixel moves). Cached under [param key].
static func recoloured(tex: Texture2D, ramp: Array[Color], key: String) -> Texture2D:
	var cache: String = "recol:" + key
	if _textures.has(cache):
		return _textures[cache]
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var colours: Array[Color] = []
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5:
				c.a = 1.0
				if not colours.has(c):
					colours.append(c)
	colours.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	var map: Dictionary = {}
	for i: int in colours.size():
		var t: float = float(i) / float(maxi(colours.size() - 1, 1))
		map[colours[i].to_html(false)] = ramp[roundi(t * float(ramp.size() - 1))]
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5:
				var n: Color = map.get(Color(c.r, c.g, c.b).to_html(false), c)
				img.set_pixel(x, y, Color(n.r, n.g, n.b, c.a))
	var out := ImageTexture.create_from_image(img)
	_textures[cache] = out
	return out


# A cached texture by path (null when missing).
static func _tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = ArtAssets.texture(path) if ResourceLoader.exists(path) or FileAccess.file_exists(path) else null
	return _textures[path]


## An island at [param r] (screen space) for [param region]: its sprite (nearest, [param tint]), else a code-drawn
## angular island in [param bands]' colours. With [param glow] > 0 a gold outline (the sprite's alpha offset 1 art px
## in 8 directions under it) at that alpha.
static func draw_island(canvas: CanvasItem, r: Rect2, region: String, bands: Dictionary, tint: Color, glow: float = 0.0, t: float = -1.0, phase: float = 0.0) -> void:
	var tex: Texture2D = island_texture(region)
	if tex != null:
		if glow > 0.0:
			var s: float = r.size.x / ISLAND_ART.x
			var sil: Texture2D = _silhouette(region, tex)
			for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				canvas.draw_texture_rect(PixelFrame.nearest(sil), Rect2(r.position + o * s, r.size), false, Color(GLOW, glow))
		canvas.draw_texture_rect(PixelFrame.nearest(tex), r, false, tint)
		# 2026-11-07 (user: animate the islands): the island's accent pixels (lava, water, frost highlights) pulse.
		if t >= 0.0:
			var accent: Texture2D = _accent_mask(region, tex)
			canvas.draw_texture_rect(PixelFrame.nearest(accent), r, false, Color(1.0, 0.97, 0.9, accent_alpha(t, phase) * tint.v))
		return
	# Placeholder (no sprite yet): a 2.5D prism in the map's projection: a top face (the walk surface, foreshortened
	# depth), a front wall and a side wall in shade, a tapering rocky underside; stone leaning to the region's colours.
	var k: float = r.size.x / ISLAND_ART.x
	var top_c: Vector2 = r.position + Vector2(r.size.x * 0.5, r.size.y * 0.5)
	var half_w: float = r.size.x * 0.4
	var depth: float = PRISM_DEPTH * k * DEPTH_K
	var wall: float = PRISM_WALL * k
	var fl := top_c + Vector2(-half_w, depth * 0.5)
	var fr := top_c + Vector2(half_w * 0.9, depth * 0.5)
	var bl := top_c + Vector2(-half_w * 0.85, -depth * 0.5)
	var br := top_c + Vector2(half_w, -depth * 0.5)
	var ground: Color = PLACEHOLDER_STONE.lerp(bands.get("ground", Color("4A5257")) as Color, PLACEHOLDER_LEAN) * tint
	var top: Color = PLACEHOLDER_TOP.lerp(bands.get("sky", Color("7D8896")) as Color, PLACEHOLDER_LEAN) * tint
	var under := PackedVector2Array([fl + Vector2(0, wall), fr + Vector2(0, wall), br + Vector2(0, wall), fr.lerp(br, 0.5) + Vector2(-half_w * 0.3, wall + r.size.y * 0.35),
		top_c + Vector2(0.0, depth * 0.5 + wall + r.size.y * 0.42), fl.lerp(bl, 0.3) + Vector2(half_w * 0.3, wall + r.size.y * 0.3)])
	canvas.draw_colored_polygon(under, ground.darkened(0.35))
	var side := PackedVector2Array([fr, br, br + Vector2(0, wall), fr + Vector2(0, wall)])
	canvas.draw_colored_polygon(side, ground.darkened(0.2))
	var front := PackedVector2Array([fl, fr, fr + Vector2(0, wall), fl + Vector2(0, wall)])
	canvas.draw_colored_polygon(front, ground)
	var face := PackedVector2Array([bl, br, fr, fl])
	if glow > 0.0:
		var g: PackedVector2Array = face.duplicate()
		g.append(face[0])
		canvas.draw_polyline(g, Color(GLOW, glow), 3.0)
	canvas.draw_colored_polygon(face, top)
	for poly: PackedVector2Array in [face, front, side, under]:
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		canvas.draw_polyline(closed, INK, 1.0)


## 2026-11-07 (user: the summit should not be a still image): the Lattice Heart summit sprite (PixelLab S, 256x224) and
## its live layers, cut by rows: the heart (cube, rings, fragments) above SUMMIT_SPLIT bobs by SUMMIT_BOB px on a slow
## sine, the platform below stays put; the gold seam pixels (SUMMIT_GLOW colours) pulse brighter over the heart.
const SUMMIT_FILE: String = "res://assets/art/ui/climb/summit.png"
const SUMMIT_SPLIT: int = 140
const SUMMIT_BOB: float = 2.0
const SUMMIT_BOB_HZ: float = 0.35
const SUMMIT_PULSE_HZ: float = 0.6
const SUMMIT_GLOW: Array[String] = ["f8c838", "ffe89a", "fff6c8"]
## Where the route ends on the summit platform (sprite px).
const SUMMIT_LANDING: Vector2 = Vector2(128, 168)


## Pure: the summit's vertical bob (px, before scale) at [param t] seconds.
static func summit_bob(t: float) -> float:
	return roundf(SUMMIT_BOB * sin(t * TAU * SUMMIT_BOB_HZ))


## Pure: the seam glow's alpha at [param t] seconds (0.15..0.65).
static func summit_glow(t: float) -> float:
	return 0.4 + 0.25 * sin(t * TAU * SUMMIT_PULSE_HZ)


## The summit's rect on screen (map scale, centred on [param center]); empty without the sprite.
static func summit_rect(vp: Vector2, center: Vector2) -> Rect2:
	var tex: Texture2D = _tex(SUMMIT_FILE)
	if tex == null:
		return Rect2()
	var size: Vector2 = Vector2(tex.get_size()) * map_scale(vp)
	return Rect2((center - size * 0.5).round(), size)


## Draws the live summit at [param center] (screen) for time [param t]: the platform rows still, the heart rows bobbing,
## then the pulsing gold over the heart's seams. False without the sprite (the caller draws its fallback).
static func draw_summit(canvas: CanvasItem, vp: Vector2, center: Vector2, t: float) -> bool:
	var tex: Texture2D = _tex(SUMMIT_FILE)
	if tex == null:
		return false
	var k: float = map_scale(vp)
	var r: Rect2 = summit_rect(vp, center)
	var w: float = float(tex.get_width())
	var h: float = float(tex.get_height())
	var split: float = float(SUMMIT_SPLIT)
	var bob: float = summit_bob(t) * k
	var tx: Texture2D = PixelFrame.nearest(tex)
	canvas.draw_texture_rect_region(tx, Rect2(r.position + Vector2(0.0, split * k), Vector2(w, h - split) * k), Rect2(0.0, split, w, h - split))
	var top := Rect2(r.position + Vector2(0.0, bob), Vector2(w, split) * k)
	canvas.draw_texture_rect_region(tx, top, Rect2(0.0, 0.0, w, split))
	var glow: Texture2D = _summit_glow_mask(tex)
	canvas.draw_texture_rect_region(PixelFrame.nearest(glow), top, Rect2(0.0, 0.0, w, split), Color(1.0, 0.95, 0.75, summit_glow(t)))
	return true


# White where the summit sprite is one of SUMMIT_GLOW (cached).
static func _summit_glow_mask(tex: Texture2D) -> Texture2D:
	var key: String = "summit_glow"
	if _textures.has(key):
		return _textures[key]
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var hit: bool = c.a > 0.5 and SUMMIT_GLOW.has(c.to_html(false))
			img.set_pixel(x, y, Color(1, 1, 1, 1) if hit else Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(img)
	_textures[key] = out
	return out


## 2026-11-07 (user: animate the islands): each island drifts up and down by ISLAND_BOB px on a slow sine, phase-shifted
## per floor so the map never bobs in step; its accent pixels (strong colours: lava, water; or near-white frost) pulse.
const ISLAND_BOB: float = 2.0
const ISLAND_BOB_HZ: float = 0.28
const ACCENT_SATURATION: float = 0.42
const ACCENT_VALUE: float = 0.88
const ACCENT_HZ: float = 0.5


## Pure: island [param index]'s drift (px, before scale) at [param t] seconds.
static func island_bob(index: int, t: float) -> float:
	return roundf(ISLAND_BOB * sin(t * TAU * ISLAND_BOB_HZ + float(index) * 1.3))


## Pure: the accent pulse alpha (0..0.4) at [param t] seconds with [param phase] (radians).
static func accent_alpha(t: float, phase: float) -> float:
	return 0.2 + 0.2 * sin(t * TAU * ACCENT_HZ + phase)


# White where [param tex]'s pixel is an accent: strongly saturated (lava, water) or near white (frost) (cached).
static func _accent_mask(region: String, tex: Texture2D) -> Texture2D:
	var key: String = "accent:" + region
	if _textures.has(key):
		return _textures[key]
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var hit: bool = c.a > 0.5 and (c.s > ACCENT_SATURATION or c.v > ACCENT_VALUE)
			img.set_pixel(x, y, Color(1, 1, 1, 1) if hit else Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(img)
	_textures[key] = out
	return out


## 2026-11-07 (user: "đảo băng thì gió băng, rừng thì thác nước chảy"): colours of the per-island live effects.
const FX_WATER: Color = Color("e8f6ff")
const FX_FROST: Color = Color("d8f2ff")
const FX_EMBER_HOT: Color = Color("ffe070")
const FX_EMBER_COOL: Color = Color("ff5a1e")


## Pure: a stable 0..1 hash of [param n] (effect phases without randomness).
static func fx_hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)


## Draws [param region]'s live effect (islands.json "fx") over its island drawn in [param r] at time [param t],
## dimmed by [param tint]. Nothing for a region without one or without a sprite.
static func draw_island_fx(canvas: CanvasItem, r: Rect2, region: String, t: float, tint: Color) -> void:
	var fx: Dictionary = island_info(region).get("fx", {})
	var tex: Texture2D = island_texture(region)
	if fx.is_empty() or tex == null:
		return
	var k: float = r.size.x / float(tex.get_width())
	match str(fx.get("kind", "")):
		"waterfall":
			_fx_waterfall(canvas, r.position, k, region, tex, fx, t, tint)
		"wind":
			_fx_wind(canvas, r.position, k, tex, fx, t, tint)
		"embers":
			_fx_embers(canvas, r.position, k, region, tex, fx, t, tint)
		"clouds":
			_fx_clouds(canvas, r.position, k, tex, fx, t, tint)


static func _fx_px(canvas: CanvasItem, at: Vector2, k: float, p: Vector2, size: Vector2, c: Color) -> void:
	canvas.draw_rect(Rect2((at + p * k).round(), size * k), c)


static func _fx_waterfall(canvas: CanvasItem, at: Vector2, k: float, region: String, tex: Texture2D, fx: Dictionary, t: float, tint: Color) -> void:
	var px: PackedVector2Array = _fx_pixels(region, tex, "water", int(fx.get("min_y", 0)))
	var band: float = float(fx.get("band", 9))
	var lit: float = float(fx.get("lit", 2))
	var speed: float = float(fx.get("speed", 26.0))
	var foot := {}
	for p: Vector2 in px:
		foot[int(p.x)] = maxf(float(foot.get(int(p.x), 0.0)), p.y)
		if fposmod(p.y - t * speed + fx_hash(int(p.x)) * 3.0, band) < lit:
			_fx_px(canvas, at, k, p, Vector2.ONE, Color(FX_WATER, 0.85) * tint)
	# Droplets below each fall's foot.
	var drop: float = float(fx.get("drop_len", 14.0))
	for x: int in foot:
		if x % 2 != 0:
			continue
		var u: float = fposmod(t * 0.9 + fx_hash(x * 7), 1.0)
		_fx_px(canvas, at, k, Vector2(float(x), float(foot[x]) + 1.0 + u * drop), Vector2(1.0, 2.0), Color(FX_WATER, 0.8 * (1.0 - u)) * tint)


static func _fx_wind(canvas: CanvasItem, at: Vector2, k: float, tex: Texture2D, fx: Dictionary, t: float, tint: Color) -> void:
	var w: float = float(tex.get_width())
	var count: int = int(fx.get("count", 16))
	var speed: float = float(fx.get("speed", 46.0))
	var top: float = float(fx.get("top", 10))
	var bottom: float = float(fx.get("bottom", 150))
	var min_len: float = float(fx.get("min_len", 6))
	var max_len: float = float(fx.get("max_len", 14))
	for i: int in count:
		var span: float = w + 60.0
		var v: float = speed * (0.75 + 0.5 * fx_hash(i + 101))
		var x: float = fposmod(fx_hash(i) * span + t * v, span) - 30.0
		var y: float = roundf(top + fx_hash(i + 37) * (bottom - top) + 3.0 * sin(t * 1.8 + float(i)))
		var length: float = roundf(min_len + fx_hash(i + 59) * (max_len - min_len))
		var fade: float = clampf(sin(PI * clampf((x + 30.0) / span, 0.0, 1.0)), 0.0, 1.0)
		var c := Color(Color(str(fx.get("color", FX_FROST.to_html(false)))), 0.95 * fade) * tint
		_fx_px(canvas, at, k, Vector2(x, y), Vector2(length, 2.0 if i % 2 == 0 else 1.0), c)
		# A dimmer tail one row lower and a flake ahead give the gust its slant.
		_fx_px(canvas, at, k, Vector2(x - length * 0.6, y + 1.0), Vector2(length * 0.6, 1.0), Color(c, c.a * 0.45))
		if i % 3 == 0:
			_fx_px(canvas, at, k, Vector2(x + length + 3.0, y - 1.0), Vector2.ONE, c)
		if bool(fx.get("grains", false)):
			for g: int in 3:
				var gx: float = x - float(g) * 7.0 - fx_hash(i * 3 + g) * 5.0
				_fx_px(canvas, at, k, Vector2(roundf(gx), y + 2.0 + float(g % 2) * 2.0), Vector2.ONE, Color(c, c.a * 0.8))


static func _fx_embers(canvas: CanvasItem, at: Vector2, k: float, region: String, tex: Texture2D, fx: Dictionary, t: float, tint: Color) -> void:
	var px: PackedVector2Array = _fx_pixels(region, tex, str(fx.get("source", "lava")), 0)
	var hot: Color = Color(str(fx.get("hot", FX_EMBER_HOT.to_html(false))))
	var cool: Color = Color(str(fx.get("cool", FX_EMBER_COOL.to_html(false))))
	if px.is_empty():
		return
	var count: int = int(fx.get("count", 14))
	var rise: float = float(fx.get("rise", 30.0))
	var period: float = float(fx.get("period", 2.4))
	for i: int in count:
		var src: Vector2 = px[int(fx_hash(i + 13) * float(px.size())) % px.size()]
		var u: float = fposmod(t / period + fx_hash(i), 1.0)
		var p := Vector2(roundf(src.x + 3.0 * sin(u * 6.0 + float(i))), roundf(src.y - u * rise))
		var c: Color = hot.lerp(cool, u)
		c.a = 1.0 - u * u
		_fx_px(canvas, at, k, p, Vector2(3.0, 3.0) if u < 0.35 else (Vector2(2.0, 2.0) if u < 0.7 else Vector2.ONE), c * tint)


static func _fx_clouds(canvas: CanvasItem, at: Vector2, k: float, tex: Texture2D, fx: Dictionary, t: float, tint: Color) -> void:
	var w: float = float(tex.get_width())
	var count: int = int(fx.get("count", 5))
	var speed: float = float(fx.get("speed", 9.0))
	var top: float = float(fx.get("top", 120))
	var bottom: float = float(fx.get("bottom", 175))
	var base := Color(str(fx.get("color", "e6e0f5")))
	for i: int in count:
		var span: float = w + 120.0
		var x: float = fposmod(fx_hash(i + 3) * span + t * speed * (0.7 + 0.6 * fx_hash(i + 17)), span) - 60.0
		var y: float = roundf(top + fx_hash(i + 29) * (bottom - top))
		var fade: float = clampf(sin(PI * clampf((x + 60.0) / span, 0.0, 1.0)), 0.0, 1.0)
		var size: float = 1.0 + fx_hash(i + 41)
		var c := Color(base, 0.55 * fade) * tint
		# A blocky puff: a wide base, a raised middle and a small cap (angular, no circles).
		_fx_px(canvas, at, k, Vector2(roundf(x), y), Vector2(roundf(30.0 * size), roundf(5.0 * size)), c)
		_fx_px(canvas, at, k, Vector2(roundf(x + 6.0 * size), y - roundf(4.0 * size)), Vector2(roundf(16.0 * size), roundf(4.0 * size)), c)
		_fx_px(canvas, at, k, Vector2(roundf(x + 10.0 * size), y - roundf(7.0 * size)), Vector2(roundf(7.0 * size), roundf(3.0 * size)), c)


# The sprite pixels an effect runs on (cached): "water" = blue fall pixels at or below [param min_y]; "lava" = hot
# orange pixels.
static func _fx_pixels(region: String, tex: Texture2D, kind: String, min_y: int) -> PackedVector2Array:
	var key: String = "fx:%s:%s" % [region, kind]
	if _fx_cache.has(key):
		return _fx_cache[key]
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var out := PackedVector2Array()
	for y: int in range(min_y, img.get_height()):
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var hit: bool
			if kind == "water":
				hit = c.h > 0.47 and c.h < 0.65 and c.s > 0.3 and c.v > 0.45
			elif kind == "spore":
				hit = c.h > 0.68 and c.h < 0.92 and c.s > 0.18 and c.v > 0.5
			else:
				hit = (c.h < 0.12 or c.h > 0.97) and c.s > 0.55 and c.v > 0.6
			if hit:
				out.append(Vector2(x, y))
	_fx_cache[key] = out
	return out


# A white copy of [param tex]'s opaque pixels (cached per region), tinted gold for the selection outline.
static func _silhouette(region: String, tex: Texture2D) -> Texture2D:
	var key: String = "sil:" + region
	if _textures.has(key):
		return _textures[key]
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			img.set_pixel(x, y, Color(1, 1, 1, 1) if img.get_pixel(x, y).a > 0.5 else Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(img)
	_textures[key] = out
	return out


## Pure: the selection glow's alpha at [param t] seconds (a slow pulse, never fully off).
static func glow_alpha(t: float) -> float:
	return 0.55 + 0.45 * (0.5 + 0.5 * sin(t * TAU * 1.2))

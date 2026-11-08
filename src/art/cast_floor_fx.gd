class_name CastFloorFx
extends RefCounted
## ADR-0001 Phase 1 Task 5 (D1, D7, pack 01 §1A / §3 steps 2-4): pure, code-drawn geometry for the cast and floor
## presentation pass. Everything is whole art px squares (art bible: square-only VFX, crisp pixels, no glow, no bloom,
## no smooth gradients; red only for enemy warnings). Callers (FloorDynamicLayer, OverlayLayer) pick the colours and
## draw; nothing here touches a node, a clock or the combat rules. The travel shapes are animation only (§1A): they
## never decide which cells take damage.
##   charge  - the target cells lit in the hero's block colour, brightening in a few palette steps until the resolve.
##   travel  - square_streak (caster -> first cell), falling_squares (sky -> each cell), chain_spark (cell to cell hop),
##             floor_run (along the floor from the origin cell, row then column).
##   flash   - the square impact flash on a cell when the delivery reaches it.
##   pit     - the drop-tile hole: broken rim, stepped depth bands, rubble.

const DEFAULT_CHARGE_STEPS: int = 4
## The ✓ drawn on the foe's cell: whole-pixel points of a 7x5 tick (x, y), thickened one pixel down.
const CHECK_POINTS: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 4), Vector2i(3, 3), Vector2i(4, 2), Vector2i(5, 1), Vector2i(6, 0)]
const CHECK_SIZE: Vector2i = Vector2i(7, 6)
## Stages of the square impact flash (fill, then two outlines growing out).
const FLASH_STAGES: int = 3
## Pit band heights as a share of the inner slab: the lit back wall, then a darker step; the rest is the deep floor.
const PIT_WALL_RATIO: float = 0.3
const PIT_MID_RATIO: float = 0.2
const PIT_RUBBLE: int = 3


# --- charge ---------------------------------------------------------------------------------------

## Pure: the charge step 0..[param steps]-1 at swing [param progress] 0..1 (no smooth ramp: the cells brighten in
## whole steps; the last step is reached in the final 1/steps of the swing).
static func charge_step(progress: float, steps: int = DEFAULT_CHARGE_STEPS) -> int:
	var n: int = maxi(steps, 1)
	return clampi(floori(clampf(progress, 0.0, 1.0) * float(n)), 0, n - 1)


## Pure: {"fill": Color, "outline": Color} of a charging target cell at [param step] of [param steps]: the fill is the
## block colour [param base] at alpha fill_lo .. fill_hi, the outline goes from base to the highlight [param light];
## both change only per step (palette steps, art bible §5: mood by palette step, no bloom).
static func charge_colours(base: Color, light: Color, step: int, steps: int, fill_lo: float = 0.35, fill_hi: float = 0.75) -> Dictionary:
	var f: float = 0.0 if steps <= 1 else clampf(float(step) / float(steps - 1), 0.0, 1.0)
	var fill: Color = base.lerp(light, f * 0.5)
	fill.a = lerpf(fill_lo, fill_hi, f)
	var outline: Color = base.lerp(light, f)
	outline.a = 1.0
	return {"fill": fill, "outline": outline}


## Pure: the ✓ squares (art px) centred in [param cell_rect], each pixel [param scale] px.
static func check_rects(cell_rect: Rect2i, scale: int = 2) -> Array[Rect2i]:
	var s: int = maxi(scale, 1)
	var size: Vector2i = CHECK_SIZE * s
	var origin: Vector2i = cell_rect.position + (cell_rect.size - size) / 2
	var out: Array[Rect2i] = []
	for p: Vector2i in CHECK_POINTS:
		out.append(Rect2i(origin + p * s, Vector2i(s, s * 2)))
	return out


# --- travel ---------------------------------------------------------------------------------------

## Pure: a streak of [param count] stepped squares from [param from] towards [param to] at flight progress [param t]
## (0..1): the head (size [param size]) at the flight point, each trailing square [param spacing] px further back and
## 1 px smaller (min 1), never behind [param from]. [] outside 0..1.
static func streak_rects(from: Vector2i, to: Vector2i, t: float, count: int, size: int, spacing: float) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if t < 0.0 or t > 1.0:
		return out
	var a := Vector2(from)
	var d: Vector2 = Vector2(to) - a
	var length: float = d.length()
	var dir: Vector2 = d / length if length > 0.0 else Vector2.ZERO
	var head: float = length * t
	for i: int in maxi(count, 1):
		var along: float = head - float(i) * spacing
		if along < 0.0:
			break
		out.append(square_rect(Vector2i((a + dir * along).round()), maxi(size - i, 1)))
	return out


## Pure, deterministic per [param seed]: the squares falling onto [param cell_rect], [param until_land] seconds before
## they land (they all land together at 0, so the impact meets the delivery's arrival): [param count] squares spread
## across the cell, each starting [param height] px (+ 25 % per square) above its landing row over [param drop_sec].
## [] before the drop starts or after the landing.
static func fall_rects(cell_rect: Rect2i, until_land: float, drop_sec: float, height: int, count: int, size: int, seed: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if drop_sec <= 0.0 or until_land < 0.0 or until_land > drop_sec:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed & 0x7FFFFFFF
	var k: float = until_land / drop_sec
	var n: int = maxi(count, 1)
	for i: int in n:
		var fx: float = (float(i) + 0.5) / float(n) + rng.randf_range(-0.1, 0.1)
		var x: int = cell_rect.position.x + roundi(cell_rect.size.x * clampf(fx, 0.15, 0.85))
		var land_y: int = cell_rect.position.y + roundi(cell_rect.size.y * rng.randf_range(0.35, 0.7))
		var h: float = float(height) * (1.0 + 0.25 * float(i))
		out.append(square_rect(Vector2i(x, land_y - roundi(h * k)), maxi(size - (i % 2), 1)))
	return out


## Pure: a hop from [param a] to [param b] at [param t] (0..1), lifted [param lift] px at the middle (whole px).
static func hop_point(a: Vector2i, b: Vector2i, t: float, lift: int) -> Vector2i:
	var u: float = clampf(t, 0.0, 1.0)
	var p: Vector2 = Vector2(a).lerp(Vector2(b), u)
	p.y -= float(lift) * 4.0 * u * (1.0 - u)
	return Vector2i(p.round())


## Pure: the point [param f] (0..1) of the way along the floor run from [param a] to [param b], row first, then column
## (SkillDelivery._l_path's order), whole px.
static func l_point(a: Vector2i, b: Vector2i, f: float) -> Vector2i:
	var corner := Vector2i(b.x, a.y)
	var leg1: float = absf(float(corner.x - a.x))
	var leg2: float = absf(float(b.y - corner.y))
	var total: float = leg1 + leg2
	if total <= 0.0:
		return b
	var d: float = clampf(f, 0.0, 1.0) * total
	if d <= leg1:
		return Vector2i(Vector2(a).lerp(Vector2(corner), d / maxf(leg1, 0.001)).round())
	return Vector2i(Vector2(corner).lerp(Vector2(b), (d - leg1) / maxf(leg2, 0.001)).round())


## Pure: the running squares of a floor run from [param a] to [param b] [param rel] seconds after it left, landing at
## [param arrive] (> 0): the head plus [param count]-1 trailing squares [param trail_sec] behind, 1 px smaller each.
## [] before the start or once it arrived.
static func run_rects(a: Vector2i, b: Vector2i, rel: float, arrive: float, count: int, size: int, trail_sec: float) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if arrive <= 0.0 or rel < 0.0 or rel > arrive:
		return out
	for i: int in maxi(count, 1):
		var r: float = rel - float(i) * trail_sec
		if r < 0.0:
			break
		out.append(square_rect(l_point(a, b, r / arrive), maxi(size - i, 1)))
	return out


# --- impact flash ---------------------------------------------------------------------------------

## Pure: the square impact flash of [param cell_rect] [param age] seconds after the delivery reached it, over
## [param sec]: stage 0 a filled inner square, stage 1 a 2 px outline, stage 2 a 1 px outline at the cell edge. Returns
## [] outside the flash, else [{"rect": Rect2i, "fill": bool, "width": int}].
static func flash_rects(cell_rect: Rect2i, age: float, sec: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sec <= 0.0 or age < 0.0 or age >= sec:
		return out
	var stage: int = clampi(floori(age / sec * float(FLASH_STAGES)), 0, FLASH_STAGES - 1)
	var q: int = mini(cell_rect.size.x, cell_rect.size.y) / 4
	match stage:
		0:
			out.append({"rect": cell_rect.grow(-q), "fill": true, "width": 0})
		1:
			out.append({"rect": cell_rect.grow(-q / 2), "fill": false, "width": 2})
		_:
			out.append({"rect": cell_rect.grow(-1), "fill": false, "width": 1})
	return out


# --- drop-tile pit --------------------------------------------------------------------------------

## Pure, deterministic per [param seed]: the pit drawn on [param slab] (art px): "deep" (the whole inner slab, drawn
## first), "bands" ([back wall, middle step], drawn over it top-down), "rim" (the broken lighter edge: 1-2 px runs with
## gaps along the top, 1 px down both sides over the wall band) and "rubble" (PIT_RUBBLE small squares on the deep
## floor).
static func pit_layout(slab: Rect2i, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed & 0x7FFFFFFF
	var inner: Rect2i = slab.grow(-1)
	var wall_h: int = maxi(roundi(inner.size.y * PIT_WALL_RATIO), 1)
	var mid_h: int = maxi(roundi(inner.size.y * PIT_MID_RATIO), 1)
	var bands: Array[Rect2i] = [
		Rect2i(inner.position, Vector2i(inner.size.x, wall_h)),
		Rect2i(inner.position.x, inner.position.y + wall_h, inner.size.x, mid_h),
	]
	var rim: Array[Rect2i] = []
	var x: int = slab.position.x
	while x < slab.end.x:
		var run: int = mini(rng.randi_range(2, 6), slab.end.x - x)
		if rng.randf() > 0.2:
			rim.append(Rect2i(x, slab.position.y, run, rng.randi_range(1, 2)))
		x += run
	var side_h: int = wall_h + 1
	rim.append(Rect2i(slab.position.x, slab.position.y, 1, side_h))
	rim.append(Rect2i(slab.end.x - 1, slab.position.y, 1, rng.randi_range(maxi(side_h - 2, 1), side_h)))
	var rubble: Array[Rect2i] = []
	var floor_top: int = inner.position.y + wall_h + mid_h
	for i: int in PIT_RUBBLE:
		var s: int = rng.randi_range(1, 2)
		var rx: int = inner.position.x + rng.randi_range(1, maxi(inner.size.x - s - 1, 1))
		var ry: int = rng.randi_range(floor_top, maxi(inner.end.y - s - 1, floor_top))
		rubble.append(Rect2i(rx, ry, s, s))
	return {"deep": inner, "bands": bands, "rim": rim, "rubble": rubble}


## Default pit tuning (index.json travel_style.pit overrides): rim_light = how much the broken rim lightens the face_top
## edge, wall_light = the lit back wall over the deck, mid_mix = the middle band from deck towards face, deep_ink = the
## deep floor from face towards Ink. Task 5 item 3: the v1 pit (wall from the face) read as a black square.
const PIT_TUNING: Dictionary = {"rim_light": 0.45, "wall_light": 0.12, "mid_mix": 0.55, "deep_ink": 0.3, "rubble_light": 0.2}


## Pure: the pit colours from a region's platform palette ([param deck], [param face], [param face_top] = its deck,
## front face and light top edge): steps of the floor itself, never red - a light broken rim, the lit back wall (a step
## lighter than the deck), a middle band, the deep floor (between face and Ink, darker than the floor) and lighter
## rubble. [param tuning] overrides [constant PIT_TUNING] key by key. {"deep", "wall", "mid", "rim", "rubble"}.
static func pit_colours(deck: Color, face: Color, face_top: Color, tuning: Dictionary = {}) -> Dictionary:
	var ink: Color = SlabPainter.INK
	var k: Dictionary = PIT_TUNING.duplicate()
	k.merge(tuning, true)
	return {
		"wall": deck.lightened(float(k["wall_light"])),
		"mid": deck.lerp(face, float(k["mid_mix"])),
		"deep": face.lerp(ink, float(k["deep_ink"])),
		"rim": face_top.lightened(float(k["rim_light"])),
		"rubble": deck.lightened(float(k["rubble_light"])),
	}


## Pure: the crack-to-hole widening: from crack progress [param k] >= [param from_k] the rim shows (the crack lines
## reach the edge); from [param wall_k] the back wall band opens too. Returns {"rim": bool, "wall": bool}.
static func crack_opening(k: float, from_k: float = 0.75, wall_k: float = 0.9) -> Dictionary:
	return {"rim": k >= from_k, "wall": k >= wall_k}


# --- square impacts -------------------------------------------------------------------------------

## Task 5 item 2: the impact kinds drawn in code (SkillDelivery.IMPACTS minus "none").
const IMPACT_KINDS: Array[String] = ["slash", "burst", "shatter", "burn", "freeze", "poison", "knockback", "guard", "seal", "thorns", "curse"]


## Pure, deterministic per [param seed]: the square shards of impact [param kind] on [param cell_rect] [param age]
## seconds after the delivery reached it, over [param sec]; [param dir] = +1 / -1, the way the cast travels (knockback
## pushes, slash slides that way). [] outside 0..sec or for an unknown kind. Each item {"rect": Rect2i, "light": bool}
## (light = the highlight colour, else the body colour); whole art px, squares only (art bible: no diamond, no glow).
##   slash 3 offset bars sliding; burst a ring of 8 shards going out; shatter 6 squares scattering and dropping;
##   burn stepped squares rising and shrinking; freeze 5 pale squares holding then shrinking; poison 3 bubbles rising;
##   knockback 3 squares pushed one way; guard a square outline of 4 bars; seal an outline plus a centre square;
##   thorns 3 stepped spikes rising; curse a ring of 8 shards closing in.
static func impact_rects(kind: String, cell_rect: Rect2i, age: float, sec: float, seed: int, dir: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sec <= 0.0 or age < 0.0 or age >= sec:
		return out
	var u: float = age / sec
	var w: int = cell_rect.size.x
	var h: int = cell_rect.size.y
	var c: Vector2i = cell_rect.position + Vector2i(_div(w, 2), _div(h, 2))
	var sgn: int = 1 if dir >= 0 else -1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed & 0x7FFFFFFF
	match kind:
		"slash":
			var bar: int = maxi(roundi(w * 0.5 * (1.0 - u * 0.6)), 2)
			for i: int in 3:
				if u < float(i) * 0.15:
					continue
				var y: int = c.y + (i - 1) * maxi(_div(h, 5), 3)
				var x0: int = c.x - _div(bar, 2) + (i - 1) * 3 * sgn + roundi(u * 6.0) * sgn
				out.append({"rect": Rect2i(x0, y - 1, bar, 2), "light": i == 1})
		"burst", "curse":
			var r: float = lerpf(3.0, w * 0.4, u) if kind == "burst" else lerpf(w * 0.4, 3.0, u)
			var s: int = 3 if u < 0.5 else 2
			for i: int in 8:
				var a: float = TAU * float(i) / 8.0
				out.append({"rect": square_rect(c + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r * 0.7)), s), "light": i % 2 == 0})
		"shatter":
			for i: int in 6:
				var a: float = TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / 6.0
				var d: float = u * w * 0.45
				var p := Vector2i(roundi(cos(a) * d), roundi(sin(a) * d * 0.6 + u * u * h * 0.3))
				out.append({"rect": square_rect(c + p, 2 if i % 3 else 3), "light": i % 2 == 0})
		"burn":
			for i: int in 4:
				var x: int = c.x + (i - 2) * maxi(_div(w, 6), 3) + 2
				var rise: int = roundi(u * h * 0.45) + (i % 2) * 3
				var s: int = maxi(4 - floori(u * 3.0) - (i % 2), 1)
				out.append({"rect": square_rect(Vector2i(x, c.y + _div(h, 5) - rise), s), "light": i % 2 == 1})
		"freeze":
			var s: int = 3 if u < 0.6 else 2
			var off: int = maxi(_div(w, 5), 3)
			for p: Vector2i in [Vector2i.ZERO, Vector2i(-off, -_div(off, 2)), Vector2i(off, -_div(off, 2)), Vector2i(-off, _div(off, 2)), Vector2i(off, _div(off, 2))]:
				out.append({"rect": square_rect(c + p, s + (1 if p == Vector2i.ZERO else 0)), "light": p == Vector2i.ZERO})
		"poison":
			for i: int in 3:
				var x: int = c.x + roundi((float(i) - 1.0) * w * 0.22 + rng.randf_range(-2.0, 2.0))
				var lag: float = clampf(u - float(i) * 0.15, 0.0, 1.0)
				out.append({"rect": square_rect(Vector2i(x, c.y + _div(h, 6) - roundi(lag * h * 0.35)), 3 if lag < 0.7 else 2), "light": i == 1})
		"knockback":
			for i: int in 3:
				var x: int = c.x + sgn * (roundi(u * w * 0.4) - i * 5)
				out.append({"rect": square_rect(Vector2i(x, c.y), maxi(4 - i, 2)), "light": i == 0})
		"guard", "seal":
			var g: Rect2i = cell_rect.grow(-maxi(_div(mini(w, h), 5) - roundi(u * 2.0), 2))
			out.append({"rect": Rect2i(g.position, Vector2i(g.size.x, 2)), "light": true})
			out.append({"rect": Rect2i(g.position.x, g.end.y - 2, g.size.x, 2), "light": true})
			out.append({"rect": Rect2i(g.position.x, g.position.y + 2, 2, g.size.y - 4), "light": false})
			out.append({"rect": Rect2i(g.end.x - 2, g.position.y + 2, 2, g.size.y - 4), "light": false})
			if kind == "seal":
				out.append({"rect": square_rect(c, 4), "light": true})
		"thorns":
			var tall: int = clampi(ceili(u * 6.0), 1, 3)
			for i: int in 3:
				var x: int = c.x + (i - 1) * maxi(_div(w, 4), 4)
				var base_y: int = c.y + _div(h, 4)
				for k: int in tall:
					var s: int = maxi(5 - k * 2, 1)
					out.append({"rect": Rect2i(x - _div(s, 2), base_y - (k + 1) * 2, s, 2), "light": k == tall - 1})
	return out


# Whole-px floor division without the integer_division warning.
static func _div(a: int, b: int) -> int:
	return floori(float(a) / float(b))


## Pure: a [param size] px square centred on [param centre] (whole px).
## Skill v2 (Trảm Địa, V13 crack): the steel crack the surge leaves from [param a] to [param b] (flat art px centres):
## squares of [param size] every [param gap] px along the line, jittered 1 px across it per [param seed]; revealed from
## a to b over [param reveal_sec], then all shrink away from a to b over the rest of [param sec]. [] outside [0, sec).
static func crack_rects(a: Vector2i, b: Vector2i, age: float, reveal_sec: float, sec: float, size: int, gap: int, seed: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if age < 0.0 or age >= sec or a == b or gap <= 0:
		return out
	var d: Vector2 = Vector2(b - a)
	var n: int = maxi(int(d.length()) / gap, 1)
	var across: Vector2 = Vector2(-d.y, d.x).normalized()
	var shown: int = n if reveal_sec <= 0.0 else clampi(int(ceilf(age / reveal_sec * float(n))), 1, n)
	var fade_k: float = clampf((age - reveal_sec) / maxf(sec - reveal_sec, 0.001), 0.0, 1.0)
	for i: int in shown + 1:
		var f: float = float(i) / float(n)
		if f < fade_k:
			continue
		var j: int = ((seed + i * 7) % 3) - 1
		var p: Vector2 = Vector2(a) + d * f + across * float(j)
		var s: int = maxi(size - (1 if f < fade_k + 0.3 and fade_k > 0.0 else 0), 1)
		out.append(square_rect(Vector2i(p.round()), s))
	return out


## Skill v2 (Trảm Địa): the ground shockwave of a burst: [param count] squares leaving [param centre] (flat art px) in
## the 8 directions (count / 8 per ring), out to [param reach] px over [param sec], shrinking from [param size] to 1.
## No outline frame (a white cell frame read as a selection box, 2026-11-02). [] outside [0, sec).
static func shock_rects(centre: Vector2i, age: float, sec: float, reach: int, count: int, size: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if sec <= 0.0 or age < 0.0 or age >= sec or count <= 0:
		return out
	var k: float = age / sec
	var e: float = 1.0 - (1.0 - k) * (1.0 - k)
	var s: int = maxi(int(roundf(lerpf(float(size), 1.0, k))), 1)
	for i: int in count:
		var ang: float = TAU * float(i) / float(count)
		var dir := Vector2(cos(ang), sin(ang) * 0.6)
		out.append(square_rect(Vector2i((Vector2(centre) + dir * float(reach) * e).round()), s))
	return out


## Skill v2 (Trảm Địa primary impact): the steel eruption out of the burst tile, in SCREEN art px (vertical = up on
## screen, never mapped onto the floor). [param base] = the tile's drawn centre, [param cell_w] its drawn width. Beats:
## 0-0.05 s a flat white collision flash across the tile; 0-0.14 s a column of squares shooting up to 1.4 cells and
## thinning; 0.04 s on, [param shards] shards (sizes 4-8, deterministic per [param seed]) thrown up and out, falling
## back under gravity and shrinking until [param sec]. Returns [{rect, light}] (light = highlight colour). [] outside.
static func eruption_rects(base: Vector2i, cell_w: int, age: float, sec: float, seed: int, shards: int = 16) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if age < 0.0 or age >= sec or cell_w <= 0:
		return out
	var u: float = float(cell_w)
	if age < 0.05:
		var fw: int = int(u * lerpf(0.9, 0.5, age / 0.05))
		out.append({"rect": Rect2i(base.x - fw / 2, base.y - 2, fw, 4), "light": true})
	if age < 0.14:
		var k: float = age / 0.14
		var h: int = int(u * 1.4 * (1.0 - (1.0 - k) * (1.0 - k)))
		var cw: int = maxi(int(u * lerpf(0.45, 0.12, k)), 2)
		var step: int = maxi(cw, 3)
		var y: int = 0
		var i: int = 0
		while y < h:
			var w: int = maxi(cw - (i % 2) * 2, 2)
			out.append({"rect": Rect2i(base.x - w / 2, base.y - y - step, w, step - 1), "light": y > h / 2})
			y += step
			i += 1
	var t: float = age - 0.04
	if t >= 0.0:
		var life: float = maxf(sec - 0.04, 0.001)
		for j: int in shards:
			var r: int = absi(hash(seed * 131 + j * 17))
			var vx: float = (float(r % 200) / 100.0 - 1.0) * u * 0.9
			var vy: float = u * (1.6 + float((r / 200) % 100) / 100.0 * 1.4)
			var g: float = u * 7.0
			var x: float = float(base.x) + vx * t
			var yy: float = float(base.y) - (vy * t - 0.5 * g * t * t)
			if yy > float(base.y) + 2.0:
				continue
			var s0: int = 4 + (r / 7) % 5
			var s: int = maxi(int(roundf(float(s0) * (1.0 - t / life))), 1)
			out.append({"rect": square_rect(Vector2i(int(roundf(x)), int(roundf(yy))), s), "light": j % 3 == 0})
	return out


## Skill v2 (Trảm Địa propagation): the incoming steel front between two surge cells, on the FLAT floor: a short
## stepped bar of [param count] squares at fraction [param f] of the way from [param a] to [param b] (centres, art px),
## trailing back toward a; the first square is the lit leading edge. [] when f is outside [0, 1].
static func front_rects(a: Vector2i, b: Vector2i, f: float, count: int, size: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if f < 0.0 or f > 1.0 or a == b:
		return out
	var d: Vector2 = Vector2(b - a)
	var dir: Vector2 = d.normalized()
	var head: Vector2 = Vector2(a) + d * f
	for i: int in count:
		var p: Vector2 = head - dir * float(i * (size + 1))
		if (p - Vector2(a)).dot(dir) < 0.0:
			break
		out.append(square_rect(Vector2i(p.round()), maxi(size - i, 2)))
	return out


## Skill v2 (Trảm Địa targeting preview): tile-exact marks on the FLAT floor for one planned surge cell of
## [param cell_rect]: the landing cell gets four corner squares (size 3), a surge cell a small chevron of squares
## pointing from [param from_centre] into the cell (its step direction), a cell cut off by a lock gets a small X.
## [param kind] = burst / landing / surge / blocked. Returns rects (no colours; the caller uses steel / dim).
static func preview_rects(cell_rect: Rect2i, kind: String, from_centre: Vector2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var c: Vector2i = cell_rect.position + cell_rect.size / 2
	var q: int = mini(cell_rect.size.x, cell_rect.size.y) / 4
	match kind:
		"burst", "landing":
			var s: int = 3 if kind == "burst" else 2
			for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				out.append(square_rect(c + corner * q, s))
			if kind == "burst":
				out.append(square_rect(c, 3))
		"blocked":
			for i: int in range(-2, 3):
				out.append(square_rect(c + Vector2i(i * 2, i * 2), 2))
				out.append(square_rect(c + Vector2i(i * 2, -i * 2), 2))
		_:
			var dir: Vector2 = Vector2(c - from_centre).normalized() if c != from_centre else Vector2.RIGHT
			var side := Vector2(-dir.y, dir.x)
			var tip: Vector2 = Vector2(c) + dir * float(q) * 0.5
			out.append(square_rect(Vector2i(tip.round()), 2))
			for k: int in [1, 2]:
				out.append(square_rect(Vector2i((tip - dir * float(k * 3) + side * float(k * 3)).round()), 2))
				out.append(square_rect(Vector2i((tip - dir * float(k * 3) - side * float(k * 3)).round()), 2))
	return out


static func square_rect(centre: Vector2i, size: int) -> Rect2i:
	@warning_ignore("integer_division")
	return Rect2i(centre - Vector2i(size / 2, size / 2), Vector2i(size, size))

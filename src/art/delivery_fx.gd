class_name DeliveryFx
extends RefCounted
## Skill v2 V3 (docs/skill-v2/16-animation-audit-and-plan.md §4 step 3): the delivery (travel) of a cast, pure and
## deterministic, in the same two layers as ImpactFx: FLAT items in cell art px on the floor (drawn through the board
## map) and STANDING items in screen art px over a tile's drawn ground point (unmapped, like the Hỏa Lôi columns).
## Every function takes times from SkillDelivery.arrival_times (the authoritative schedule); nothing here decides a
## time. Items are {"rect": Rect2i, "light": bool} (body / highlight colour; the caller adds the Ink edge).
##   sky      (falling_squares)  flat: a target square closing in on the cell before the drop; standing: an element
##                               block with a trail falling from 1.4 H onto the tile, two sparks beside it
##   ground   (floor_run)        flat: a ripple front of slabs running from the origin to the cell (3 rows, the Trảm
##                               Địa front); standing: dust squares hopping up behind the front
##   chain    (chain_spark)      standing: a bolt hopping link to link with a thinning tail (0.45 H lift)
##   streak   (square_streak)    flat: the boss's straight shot, a 6 px head, a tail of 3 and two side sparks
##   gather   (travel none)      flat: eight squares converging on the cell in the last GATHER_SEC before it
##                               manifests; standing: three squares dropping in from 0.6 H
## Heights are fractions of the drawn cell width (H = cell_w). Art bible: squares only, no rays, no round shapes.

## Standing height unit, in cell widths.
const COLUMN_CELLS: float = 1.0
## How long before a cell manifests the gather (in-place delivery) and the sky target show.
const GATHER_SEC: float = 0.2
const TARGET_SEC: float = 0.3


static func _d(a: int, b: int) -> int:
	return floori(float(a) / float(b))


## Items carry `tone` like ImpactFx (0 dark, 1 body, 2 highlight, 3 core): a plain square is 1 / 2 by `light`.
static func _sq(c: Vector2i, s: int, light: bool, tone: int = -1) -> Dictionary:
	var ss: int = maxi(s, 1)
	return {"rect": Rect2i(c - Vector2i(_d(ss, 2), _d(ss, 2)), Vector2i(ss, ss)), "light": light, "tone": tone if tone >= 0 else (2 if light else 1)}


static func _bar(x: int, y: int, w: int, h: int, light: bool) -> Dictionary:
	return {"rect": Rect2i(x, y, maxi(w, 1), maxi(h, 1)), "light": light, "tone": 2 if light else 1}


static func _outline(out: Array[Dictionary], f: Rect2i, t: int, light: bool) -> void:
	out.append(_bar(f.position.x, f.position.y, f.size.x, t, light))
	out.append(_bar(f.position.x, f.end.y - t, f.size.x, t, light))
	out.append(_bar(f.position.x, f.position.y + t, t, f.size.y - t * 2, light))
	out.append(_bar(f.end.x - t, f.position.y + t, t, f.size.y - t * 2, light))


# --- sky -------------------------------------------------------------------------------------------

## Flat: the target square closing in on [param cell_rect] from its edge to 0.45 of it over the last TARGET_SEC
## before the drop lands ([param until_land] seconds left), 3 px thick, then 2 px. [] outside that window.
static func sky_floor(cell_rect: Rect2i, until_land: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if until_land < 0.0 or until_land > TARGET_SEC:
		return out
	var k: float = 1.0 - until_land / TARGET_SEC
	var frac: float = lerpf(1.0, 0.45, k)
	var c: Vector2i = cell_rect.position + Vector2i(_d(cell_rect.size.x, 2), _d(cell_rect.size.y, 2))
	var half := Vector2i(roundi(float(cell_rect.size.x) * frac * 0.5), roundi(float(cell_rect.size.y) * frac * 0.5))
	_outline(out, Rect2i(c - half, half * 2), 3 if k < 0.6 else 2, k > 0.6)
	if k > 0.8:
		out.append(_sq(c, 5, true))
	return out


## Standing: the falling element block over [param base] (the tile's drawn ground centre) [param until_land]
## seconds before it lands, dropping from 1.4 H over [param drop_sec]: a 9 px core, three trail squares above it
## thinning, two sparks beside the core. [] outside [0, drop_sec].
static func sky_standing(base: Vector2i, cell_w: int, until_land: float, drop_sec: float, seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if drop_sec <= 0.0 or until_land < 0.0 or until_land > drop_sec:
		return out
	var H: int = maxi(roundi(float(cell_w) * COLUMN_CELLS), 8)
	var k: float = until_land / drop_sec
	var up: int = roundi(float(H) * 1.4 * k * k) + 4
	var jx: int = ((seed % 5) - 2)
	var core := Vector2i(base.x + jx, base.y - up)
	out.append(_sq(core + Vector2i(1, 2), 9, false, 0))
	out.append(_sq(core, 9, false))
	out.append(_sq(core + Vector2i(-2, -2), 4, true, 3))
	for i: int in 3:
		out.append(_sq(core + Vector2i(((i + seed) % 3) - 1, -8 - i * 6), 5 - i, i == 0, 2 if i == 0 else (1 if i == 1 else 0)))
	for sx: int in [-1, 1]:
		out.append(_sq(core + Vector2i(sx * 8, 2 + roundi(k * 6.0)), 3, true))
	return out


## Standing: Thiên Thạch's meteor over [param base]: a 15 px rock with a bright edge streaking in from the upper
## left on a trail of eight fire squares, from 2.2 H away over [param drop_sec]; [] outside [0, drop_sec].
static func meteor_standing(base: Vector2i, cell_w: int, until_land: float, drop_sec: float, seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if drop_sec <= 0.0 or until_land < 0.0 or until_land > drop_sec:
		return out
	var H: int = maxi(roundi(float(cell_w) * COLUMN_CELLS), 8)
	var k: float = until_land / drop_sec
	var dist: float = float(H) * 2.2 * k * k
	var core := Vector2i(base.x - roundi(dist * 0.55), base.y - roundi(dist) - 8)
	out.append(_sq(core + Vector2i(2, 3), 15, false, 0))
	out.append(_sq(core, 15, false))
	out.append(_sq(core + Vector2i(-4, -4), 6, true, 3))
	for i: int in 8:
		var t: Vector2i = core + Vector2i(-6 - i * 5 + ((i * 3 + seed) % 3), -8 - i * 8)
		out.append(_sq(t, 7 - _d(i, 2), i < 2, 2 if i < 2 else (1 if i < 5 else 0)))
	return out


# --- ground ----------------------------------------------------------------------------------------

## Flat: the ripple front running from [param a] to [param b] (flat cell centres), [param rel] seconds into a
## travel that arrives at [param arrive]: five 6 px slabs along the path ending at the front, plus two side rows of
## 4 px squares 5 px across, the front slab light. [] outside [0, arrive].
static func ground_floor(a: Vector2i, b: Vector2i, rel: float, arrive: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if arrive <= 0.0 or rel < 0.0 or rel > arrive or a == b:
		return out
	var f: float = rel / arrive
	var d: Vector2 = Vector2(b - a)
	var across: Vector2 = Vector2(-d.y, d.x).normalized()
	for i: int in 5:
		var fi: float = f - float(i) * 0.08
		if fi < 0.0:
			break
		var p: Vector2i = Vector2i((Vector2(a) + d * fi).round())
		out.append(_sq(p, 8 - i, i == 0))
		# a wedge: two rows each side, wider behind the front
		for row: int in [1, 2]:
			if i + row > 4:
				continue
			var s: int = 6 - i - row
			out.append(_sq(Vector2i((Vector2(p) + across * float(row * 8)).round()), s, i == 0 and row == 1))
			out.append(_sq(Vector2i((Vector2(p) - across * float(row * 8)).round()), s, i == 0 and row == 1))
	return out


## Standing: dust kicked up behind the ripple front at [param front] (the front's drawn ground point): four squares
## hopping up to 0.3 H behind it along [param back] (unit direction back toward the origin, screen px).
static func ground_dust(front: Vector2i, back: Vector2, cell_w: int, f: float, seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if f < 0.05 or f > 1.0:
		return out
	var H: int = maxi(roundi(float(cell_w) * COLUMN_CELLS), 8)
	for i: int in 6:
		var lag: float = fmod(f * 3.0 + float((i * 7 + seed) % 4) * 0.25, 1.0)
		var up: int = roundi(float(H) * 0.4 * 4.0 * lag * (1.0 - lag)) + 2
		var p: Vector2i = Vector2i((Vector2(front) + back * float(4 + i * 7)).round())
		out.append(_sq(Vector2i(p.x + ((i * 5 + seed) % 7) - 3, p.y - up), 6 - _d(i, 2), i % 2 == 0))
	return out


# --- chain -----------------------------------------------------------------------------------------

## Standing: the bolt hopping from [param a] to [param b] (the links' drawn ground points) at [param t] (0..1),
## lifted 0.45 H at the middle: a 6 px head and a tail of five squares along the arc behind it, thinning.
static func chain_standing(a: Vector2i, b: Vector2i, cell_w: int, t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if t < 0.0 or t > 1.0:
		return out
	var H: int = maxi(roundi(float(cell_w) * COLUMN_CELLS), 8)
	for i: int in 7:
		var u: float = t - float(i) * 0.08
		if u < 0.0:
			break
		var p: Vector2 = Vector2(a).lerp(Vector2(b), u)
		p.y -= float(H) * 0.45 * 4.0 * u * (1.0 - u)
		out.append(_sq(Vector2i(p.round()), 8 - i if i < 5 else 3, i <= 1, 2 if i <= 1 else (1 if i < 4 else 0)))
		if i == 0:
			out.append(_sq(Vector2i(p.round()), 4, true, 3))
			out.append(_sq(Vector2i(p.round()) + Vector2i(0, -7), 3, true))
			out.append(_sq(Vector2i(p.round()) + Vector2i(0, 7), 3, true))
	return out


# --- projectile streak (the boss's straight shot) --------------------------------------------------

## Flat: the shot from [param from] to [param to] at [param t] (0..1): a 6 px head, a tail of three squares 6 px
## apart thinning, and two 2 px sparks beside the head.
static func streak(from: Vector2i, to: Vector2i, t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if t < 0.0 or t > 1.0 or from == to:
		return out
	var d: Vector2 = Vector2(to - from)
	var dir: Vector2 = d.normalized()
	var across: Vector2 = Vector2(-dir.y, dir.x)
	var head: Vector2 = Vector2(from) + d * t
	out.append(_sq(Vector2i(head.round()), 8, true))
	out.append(_sq(Vector2i(head.round()), 4, true, 3))
	for i: int in range(1, 4):
		out.append(_sq(Vector2i((head - dir * float(i * 7)).round()), 7 - i, false, 1 if i < 3 else 0))
	for sx: int in [-1, 1]:
		out.append(_sq(Vector2i((head - dir * 4.0 + across * float(sx * 7)).round()), 3, true))
	return out


# --- gather (in-place manifestation) ----------------------------------------------------------------

## Flat: eight squares converging from the edges of [param cell_rect] onto its centre over the last GATHER_SEC
## before the cell manifests ([param until] seconds left), 3 px then 4 px as they close. [] outside the window.
static func gather_floor(cell_rect: Rect2i, until: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if until < 0.0 or until > GATHER_SEC:
		return out
	var k: float = 1.0 - until / GATHER_SEC
	var c: Vector2i = cell_rect.position + Vector2i(_d(cell_rect.size.x, 2), _d(cell_rect.size.y, 2))
	var hw: int = _d(cell_rect.size.x, 2) - 2
	var hh: int = _d(cell_rect.size.y, 2) - 2
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		var r: float = 1.0 - k * 0.85
		out.append(_sq(c + Vector2i(roundi(cos(a) * float(hw) * r), roundi(sin(a) * float(hh) * r)), 3 if k < 0.5 else 4, i % 2 == 0))
	if k > 0.7:
		out.append(_sq(c, 6, true))
	return out


## Standing: three squares dropping in from 0.6 H onto [param base] over the last GATHER_SEC ([param until] seconds
## left), the middle one 5 px.
static func gather_standing(base: Vector2i, cell_w: int, until: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if until < 0.0 or until > GATHER_SEC:
		return out
	var H: int = maxi(roundi(float(cell_w) * COLUMN_CELLS), 8)
	var k: float = until / GATHER_SEC
	for i: int in 3:
		var up: int = roundi(float(H) * (0.6 - 0.1 * float(i % 2)) * k * k) + 3
		out.append(_sq(Vector2i(base.x + (i - 1) * 9, base.y - up), 5 if i == 1 else 4, i == 1))
	return out


## Batch 4 (Móc Kéo): the pull path telegraph on [param cell_rects] (the cells the hooked unit will be dragged
## through, flat cell art px): two chevrons of three 3 px squares per cell pointing [param toward] (-1 = left, +1 =
## right), marching that way with [param t] (seconds). The leading chevron is highlight, the other body.
static func pull_path_floor(cell_rects: Array[Rect2i], toward: int, t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: int = 1 if toward >= 0 else -1
	var march: int = roundi(fposmod(t * 2.0, 1.0) * 10.0) * dir
	for r: Rect2i in cell_rects:
		var c: Vector2i = r.position + Vector2i(_d(r.size.x, 2), _d(r.size.y, 2))
		for n: int in 2:
			var cx: int = c.x + march - dir * (n * 10 - 5)
			var light: bool = n == 0
			for p: Vector2i in [Vector2i(cx + dir * 3, c.y), Vector2i(cx - dir * 1, c.y - 4), Vector2i(cx - dir * 1, c.y + 4)]:
				var q: Rect2i = Rect2i(p - Vector2i(1, 1), Vector2i(3, 3)).intersection(r)
				if q.size.x > 0 and q.size.y > 0:
					out.append({"rect": q, "light": light, "tone": 2 if light else 1})
	return out

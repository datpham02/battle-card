class_name ImpactFx
extends RefCounted
## Skill v2 V1 (docs/skill-v2/16-animation-audit-and-plan.md §4 step 1): per-card impact forms, pure and deterministic.
## The shared code-drawn impact (CastFloorFx.impact_rects) draws ONE shape per impact type, so every freeze card
## ended in the same five pale squares. This module gives each impact family several FORMS, picked per card by
## `impact_variants` in the cast index (CastVfx.impact_variant), so a Đóng Băng pin freezes a frame around the cell
## while a Giá Lạnh frost gathers a cross and an ice strike raises a spike. Art bible §3: types differ by SHAPE and
## MOTION, not by colour; squares only, whole art px, no rays, no round blasts; under reduce motion the last frame
## holds still.
##
## 2026-11-11 (user): the camera is a low top-down, so an impact must STAND UP from the tile, not lie flat on it.
## Every form is therefore two layers, both on the authoritative arrival clock (`age` since the delivery reached the
## cell; nothing here decides a time):
##   - [method items]: the FLAT part, in cell art px on the floor, drawn through the board map by OverlayLayer's
##     travel path: the full-cell hit sheet, ground shapes (ice frame, frost cross, cracks, shock ring, push wedge,
##     burst ring) and the dust residue;
##   - [method standing_items]: the STANDING part, in screen art px over the tile's drawn ground centre, unmapped
##     like FuseFx.eruption_items / the Ngàn Kiếm blades: shards thrown up by the hit, ice columns, sword streaks,
##     thorns, bubbles, push walls, flying chunks. Heights are fractions of the drawn cell width (COLUMN_CELLS).
## The user also asked the impact to fill 80–100 % of the cell: flat shapes reach the cell edges, standing shapes
## span the tile's width and rise up to one cell width. The variant's own `sec` (index, 0.5 s) replaces the type's
## impact_style sec. Items are {"rect": Rect2i, "light": bool} (body / highlight colour; the caller draws the Ink edge).

## Every form, by family. Unknown forms draw nothing (the caller falls back to CastFloorFx.impact_rects).
const FORMS: Array[String] = [
	"frame", "cross", "spike", "cluster",            # freeze
	"arc_h", "arc_v", "cross_x", "double", "stab4",  # slash
	"crack", "chunks", "shards",                     # shatter
	"column", "wedge", "slam",                       # knockback
	"spikes", "bubbles",                             # thorns / poison
	"ring", "ring2",                                 # burst
	# signature forms of the batch-2 cards (2026-11-11): Thiên Thạch crater, Lốc Cuốn vortex, Hỏa Băng steam,
	# Băng Vỡ ice burst, Hồi Âm echo, Địa Chấn quake
	"crater", "vortex", "steam", "iceburst", "echo", "quake",
]

## Reduce motion (art bible §3): the last frame, still, for this long.
const REDUCE_HOLD_SEC: float = 0.15
const REDUCE_U: float = 0.7
## Forms whose late frame is nearly empty hold an earlier moment; the sweep forms show their WHOLE streak (whole).
const REDUCE_U_BY_FORM := {"slam": 0.3, "chunks": 0.5, "shards": 0.45, "ring": 0.45, "ring2": 0.45, "bubbles": 0.5,
	"arc_h": 0.6, "arc_v": 0.6, "cross_x": 0.9, "double": 0.7, "stab4": 0.7, "column": 0.5, "wedge": 0.5}
## Standing heights: the tallest standing shape is this many cell widths.
const COLUMN_CELLS: float = 1.0
## Sweep streaks: head squares, tail length and spacing (art px).
const STREAK_SIZE: int = 5
const STREAK_TAIL: int = 16
const STREAK_GAP: int = 2
## The hit: a full-cell sheet for SHEET_END, shards thrown up over the first BURST_END of the clip.
const SHEET_END: float = 0.08
const BURST_SHARDS: int = 12
const BURST_END: float = 0.4
## The residue: dust settling on the floor from RESIDUE_FROM to the end.
const RESIDUE_FROM: float = 0.55


## The FLAT items of form [param form] on [param cell_rect] (cell art px) at [param age] seconds after the delivery
## reached the cell, over [param sec]; [param seed] fixes the per-cell jitter, [param dir] (+1 / -1) is the way the
## cast travels, [param params] the card's knobs, [param reduce] the reduce-motion setting. [] outside [0, sec).
static func items(form: String, cell_rect: Rect2i, age: float, sec: float, seed: int, dir: int = 1,
		params: Dictionary = {}, reduce: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var u: float = _u(form, age, sec, reduce)
	if u < 0.0:
		return out
	var g := _Geo.new(cell_rect, 1 if dir >= 0 else -1, seed)
	g.whole = reduce
	match form:
		"frame": _frame(out, g, u, params)
		"cross": _cross(out, g, u, params)
		"crack": _crack(out, g, u, params)
		"chunks":
			if u < 0.35:
				_crack(out, g, u / 0.35 * 0.6, {"lines": 6})
		"wedge": _wedge(out, g, u, params)
		"slam": _slam_floor(out, g, u)
		"ring": _ring_floor(out, g, u, 0.0, params)
		"ring2":
			_ring_floor(out, g, u, 0.0, params)
			_ring_floor(out, g, u, 0.3, params)
		"spikes":
			if bool(params.get("vine", false)) and u > 0.4:
				out.append(g.bar(g.r.position.x + 2, g.r.end.y - 6, g.w - 4, 3, false))
		"crater": _crater_floor(out, g, u)
		"vortex": _vortex_floor(out, g, u)
		"steam": _steam_floor(out, g, u)
		"iceburst":
			if u > 0.4:
				_crack(out, g, (u - 0.4) / 0.6, {"lines": 6, "web": true})
		"echo": _arc_scar(out, g, u)
		"quake": _quake_floor(out, g, u)
	_residue(out, g, u)
	# Art bible §3: only inside the target cell (its 1 px Ink edge included).
	var bound: Rect2i = cell_rect.grow(1)
	var clipped: Array[Dictionary] = []
	# the hit sheet: the whole cell flashes core-white for SHEET_END, under everything else
	if not bool(params.get("no_burst", false)) and u < SHEET_END:
		clipped.append({"rect": g.r, "light": true, "tone": 3})
	for it: Dictionary in out:
		var r: Rect2i = (it["rect"] as Rect2i).intersection(bound)
		if r.size.x > 0 and r.size.y > 0:
			clipped.append(_toned(r, bool(it["light"]), u, r.end.y >= cell_rect.end.y - _d(cell_rect.size.y, 4)))
	return clipped


## V4 feel pass (user: "hiệu ứng hơi đơn giản"): a 4-tone ramp instead of two colours. Every item carries `tone`:
## 0 dark (the body colour darkened), 1 body, 2 highlight, 3 core (near white, the first CORE_U of the clip on the
## highlight items only). Low parts (the bottom quarter of a flat cell, the bottom layers of a standing shape) go
## dark, so columns, frames and streaks have a shaded underside. `light` stays for callers that read it.
const CORE_U: float = 0.1
static func _toned(r: Rect2i, light: bool, u: float, low: bool) -> Dictionary:
	var tone: int = 2 if light else 1
	if light and u < CORE_U:
		tone = 3
	elif not light and low:
		tone = 0
	return {"rect": r, "light": light, "tone": tone}


## The AFTERMATH of form [param form]: what the hit leaves on the cell for [param after_sec] seconds once the impact
## clip ended ([param age] seconds after the clip's end), flat and fading: freeze forms leave a rime frame and
## lying shards, shatter forms keep their cracks, slashes a scar, knockback and burst forms settling chips, thorns
## their stumps, bubbles a few drops. Tones 0–1 only (never brighter than the body), shrinking to 1 px over the last
## third. [] outside [0, after_sec).
static func aftermath_items(form: String, cell_rect: Rect2i, age: float, after_sec: float, seed: int, params: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if after_sec <= 0.0 or age < 0.0 or age >= after_sec or not FORMS.has(form):
		return out
	var k: float = age / after_sec
	var fade: bool = k > 0.66
	var g := _Geo.new(cell_rect, 1, seed)
	match form:
		"frame", "cross", "spike", "cluster":
			# rime: a thin frame inside the cell and four lying shards
			_outline(out, g.r.grow(-3), 2 if not fade else 1)
			for i: int in 4:
				out.append(g.sq(Vector2i(g.r.position.x + 8 + _d((g.w - 16) * (i * 2 + 1), 8), g.r.end.y - 7 - (i % 2) * 5), 3 if not fade else 2, false))
			if form == "cross" and not fade:
				out.append(g.bar(g.c.x - _d(g.w, 4), g.c.y - 1, _d(g.w, 2), 2, false))
				out.append(g.bar(g.c.x - 1, g.c.y - _d(g.h, 4), 2, _d(g.h, 2), false))
		"crack", "chunks", "shards":
			_crack(out, g, 1.0, {"lines": int(params.get("lines", 5)), "web": false})
			if fade:
				var thin: Array[Dictionary] = []
				for it: Dictionary in out:
					var r: Rect2i = it["rect"]
					if (r.size.x + r.size.y) % 2 == 0:
						thin.append(it)
				out = thin
		"arc_h", "arc_v", "cross_x", "double", "stab4":
			# the scar: a 2 px stepped line across the cell (and its twin for the double / X forms)
			var a := Vector2i(g.r.position.x + 4, g.r.end.y - 6)
			var b := Vector2i(g.r.end.x - 4, g.r.position.y + 6)
			_stepped(out, a, b, 2 if not fade else 1, 2)
			if form == "double" or form == "cross_x":
				_stepped(out, Vector2i(a.x, g.r.position.y + 6), Vector2i(b.x, g.r.end.y - 6), 2 if not fade else 1, 2)
		"column", "wedge", "slam", "ring", "ring2":
			for i: int in 6:
				out.append(g.sq(Vector2i(g.r.position.x + 5 + _d((g.w - 10) * (i * 2 + 1), 12), g.r.end.y - 5 - ((i * 7) % 9)), 3 if not fade else 2, false))
		"spikes":
			for i: int in 5:
				out.append(g.bar(g.r.position.x + 6 + i * _d(g.w - 12, 5) - 2, g.r.end.y - 6, 5, 3 if not fade else 2, false))
		"bubbles":
			for i: int in 4:
				out.append(g.sq(Vector2i(g.r.position.x + 8 + _d((g.w - 16) * (i * 2 + 1), 8), g.c.y + ((i * 5) % 11) - 5), 3 if not fade else 2, false))
		"crater":
			_outline(out, Rect2i(g.c - Vector2i(roundi(float(g.hw) * 0.7), roundi(float(g.hh) * 0.7)), Vector2i(roundi(float(g.w) * 0.7), roundi(float(g.h) * 0.7))), 3 if not fade else 2)
			_crack(out, g, 1.0, {"lines": 6, "web": false})
			out.append(g.sq(g.c, 10 if not fade else 6, false))
		"vortex", "quake":
			_crack(out, g, 1.0, {"lines": 5, "web": false})
			for i: int in 6:
				out.append(g.sq(Vector2i(g.r.position.x + 5 + _d((g.w - 10) * (i * 2 + 1), 12), g.r.end.y - 5 - ((i * 7) % 9)), 4 if not fade else 2, false))
		"steam":
			for i: int in 6:
				out.append(g.sq(Vector2i(g.r.position.x + 6 + _d((g.w - 12) * (i * 2 + 1), 12), g.r.position.y + 6 + ((i * 9) % (g.h - 12))), 3 if not fade else 2, false))
		"iceburst":
			_crack(out, g, 1.0, {"lines": 6, "web": true})
			for i: int in 4:
				out.append(g.sq(Vector2i(g.r.position.x + 8 + _d((g.w - 16) * (i * 2 + 1), 8), g.r.end.y - 7), 4 if not fade else 2, false))
		"echo":
			# the echo: 0.1–0.4 s after the clip a ghost of the hit replays — a double ring pulsing out and the scar
			var a := Vector2i(g.r.position.x + 4, g.r.end.y - 6)
			var b := Vector2i(g.r.end.x - 4, g.r.position.y + 6)
			_stepped(out, a, b, 2 if not fade else 1, 2)
			var ek: float = clampf((age - 0.1) / 0.3, 0.0, 1.0)
			if ek > 0.0 and ek < 1.0:
				for ring: int in 2:
					var frac: float = lerpf(0.3, 1.0, clampf(ek - float(ring) * 0.2, 0.0, 1.0))
					_outline(out, Rect2i(g.c - Vector2i(roundi(float(g.hw) * frac), roundi(float(g.hh) * frac)), Vector2i(roundi(float(g.w) * frac), roundi(float(g.h) * frac))), 2)
				_stepped(out, Vector2i(a.x, g.r.position.y + 6), Vector2i(b.x, g.r.end.y - 6), 2, 2)
	var toned: Array[Dictionary] = []
	for it: Dictionary in out:
		var r: Rect2i = (it["rect"] as Rect2i).intersection(cell_rect.grow(1))
		if r.size.x > 0 and r.size.y > 0:
			toned.append({"rect": r, "light": false, "tone": 0 if fade else 1})
	return toned


## The STANDING items of form [param form] at [param age] over [param sec]: screen art px, standing on [param base]
## (the tile's drawn ground centre; up is -y) and sized from the drawn cell width [param cell_w]. Same knobs as
## [method items]. [] outside [0, sec). Nothing is clipped: a tall column rises over the rows behind the tile.
static func standing_items(form: String, base: Vector2i, cell_w: int, age: float, sec: float, seed: int, dir: int = 1,
		params: Dictionary = {}, reduce: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var u: float = _u(form, age, sec, reduce)
	if u < 0.0:
		return out
	var s := _Stand.new(base, cell_w, 1 if dir >= 0 else -1, seed)
	s.whole = reduce
	if not bool(params.get("no_burst", false)):
		_burst_up(out, s, u)
	match form:
		"frame": _frame_crystals(out, s, u, params)
		"cross": _cross_crystal(out, s, u, params)
		"spike": _spike(out, s, u, params)
		"cluster": _cluster(out, s, u, params)
		"arc_h": _arc(out, s, u, 0.0, params)
		"arc_v": _arc_v(out, s, u, params)
		"cross_x": _cross_x(out, s, u, params)
		"double": _double(out, s, u, params)
		"stab4": _stab4(out, s, u, params)
		"chunks": _chunks(out, s, u, params)
		"shards": _shards(out, s, u, params)
		"column": _column(out, s, u, params)
		"wedge": _wedge_dust(out, s, u)
		"slam": _slam_shards(out, s, u)
		"spikes": _spikes(out, s, u, params)
		"bubbles": _bubbles(out, s, u, params)
		"ring": _ring_up(out, s, u, 0.0, params)
		"ring2":
			_ring_up(out, s, u, 0.0, params)
			_ring_up(out, s, u, 0.3, params)
		"crater": _crater_standing(out, s, u)
		"vortex": _vortex_standing(out, s, u)
		"steam": _steam_standing(out, s, u)
		"iceburst": _iceburst_standing(out, s, u)
		"echo": _arc(out, s, u, 0.0, params)
		"quake": _quake_standing(out, s, u)
	var toned: Array[Dictionary] = []
	for it: Dictionary in out:
		var r: Rect2i = it["rect"]
		toned.append(_toned(r, bool(it["light"]), u, r.end.y >= base.y - 4))
	return toned


# --- signature forms (batch-2 cards) --------------------------------------------------------------

## Thiên Thạch, flat: a crater — a 4 px square ring at 0.9 of the cell that settles to 0.7, radial cracks, a dark
## core; the ring cells of the shockwave get the `slam` form from the variant's `ring_form`.
static func _crater_floor(out: Array[Dictionary], g: _Geo, u: float) -> void:
	var frac: float = lerpf(0.95, 0.7, minf(u / 0.3, 1.0))
	_outline(out, Rect2i(g.c - Vector2i(roundi(float(g.hw) * frac), roundi(float(g.hh) * frac)),
		Vector2i(roundi(float(g.w) * frac), roundi(float(g.h) * frac))), 4)
	_crack(out, g, minf(u / 0.5, 1.0) * 0.6, {"lines": 6})
	out.append(g.sq(g.c, 10, false))


## Thiên Thạch, standing: the meteor chunk embedded in the tile (a 16 px block sinking over the first 0.2), a
## stepped fire column bursting up to 1.1 H and sinking back, and sixteen rocks thrown out in arcs.
static func _crater_standing(out: Array[Dictionary], s: _Stand, u: float) -> void:
	var sink: int = roundi(float(s.H) * 0.25 * (1.0 - minf(u / 0.2, 1.0)))
	out.append(s.sq(0, sink + 6, 16, false))
	out.append(s.sq(-3, sink + 9, 6, true))
	var top: float = float(s.H) * 1.1 * (1.0 - (1.0 - minf(u / 0.25, 1.0)) * (1.0 - minf(u / 0.25, 1.0))) if u < 0.45 \
		else float(s.H) * 1.1 * clampf(1.0 - (u - 0.45) / 0.45, 0.0, 1.0)
	var layers: int = maxi(roundi(top / 3.0), 0)
	for k: int in layers:
		var frac: float = float(k) / float(maxi(layers, 1))
		var w: int = maxi(roundi(float(s.w) * (0.75 - 0.6 * frac)), 3) + ((k * 3) % 5) - 2
		out.append(s.slab(0, 10 + k * 3, w, 3, frac > 0.45))
	for i: int in 16:
		var a: float = PI * (float(i) + 0.5) / 16.0 + s.rng.randf_range(-0.1, 0.1)
		var vx: float = cos(a) * float(s.hw) * s.rng.randf_range(0.7, 1.15)
		var vy: float = (0.4 + 0.8 * sin(a)) * float(s.H) * s.rng.randf_range(0.6, 1.3)
		var up: int = roundi(vy * u - vy * 0.9 * u * u)
		out.append(s.sq(roundi(vx * u), maxi(up, 0) + 8, 5 if i % 3 == 0 else 4, false))


## Lốc Cuốn, flat: twelve squares spiralling inward (one and a half turns over the clip) onto a 6 px core, and a
## 3 px ring that tightens as they arrive.
static func _vortex_floor(out: Array[Dictionary], g: _Geo, u: float) -> void:
	for i: int in 12:
		var k: float = clampf(u * 1.3 - float(i) * 0.025, 0.0, 1.0)
		var a: float = TAU * (float(i) / 12.0) + k * TAU * 1.5
		var r: float = 1.0 - k * 0.9
		out.append(g.sq(g.c + Vector2i(roundi(cos(a) * float(g.hw - 2) * r), roundi(sin(a) * float(g.hh - 2) * r)), 5 if k < 0.5 else 4, i % 3 == 0))
	var frac: float = lerpf(0.9, 0.35, minf(u / 0.6, 1.0))
	_outline(out, Rect2i(g.c - Vector2i(roundi(float(g.hw) * frac), roundi(float(g.hh) * frac)),
		Vector2i(roundi(float(g.w) * frac), roundi(float(g.h) * frac))), 3)
	out.append(g.sq(g.c, 6, true))


## Lốc Cuốn, standing: a funnel at the centre — stacked bars widening upward to 1.0 H, with highlight bands that
## climb (the spin), and six squares orbiting in and up.
static func _vortex_standing(out: Array[Dictionary], s: _Stand, u: float) -> void:
	var grow: float = minf(u / 0.3, 1.0)
	var layers: int = roundi(float(s.H) * grow / 3.0)
	for k: int in layers:
		var frac: float = float(k) / float(maxi(layers, 1))
		var w: int = maxi(roundi(6.0 + float(s.w) * 0.8 * frac), 4)
		var band: bool = int(floorf(u * 24.0)) % 4 == k % 4
		out.append(s.slab(((k * 7) % 5) - 2, 3 + k * 3, w, 3, band))
	for i: int in 6:
		var a: float = u * TAU * 2.0 + TAU * float(i) / 6.0
		var r: float = float(s.hw) * (1.0 - u * 0.7)
		out.append(s.sq(roundi(cos(a) * r), roundi(float(s.H) * u * 0.9) + 4, 4, i % 2 == 0))


## Hỏa Băng, flat: a wet patch — a dashed 3 px ring that spreads from the centre to the cell edge.
static func _steam_floor(out: Array[Dictionary], g: _Geo, u: float) -> void:
	var frac: float = lerpf(0.3, 1.0, minf(u / 0.5, 1.0))
	var f := Rect2i(g.c - Vector2i(roundi(float(g.hw) * frac), roundi(float(g.hh) * frac)), Vector2i(roundi(float(g.w) * frac), roundi(float(g.h) * frac)))
	for x: int in range(f.position.x, f.end.x, 8):
		out.append(g.bar(x, f.position.y, 4, 3, false))
		out.append(g.bar(x, f.end.y - 3, 4, 3, false))
	for y: int in range(f.position.y, f.end.y, 8):
		out.append(g.bar(f.position.x, y, 3, 4, false))
		out.append(g.bar(f.end.x - 3, y, 3, 4, false))
	out.append(g.sq(g.c, 6, true))


## Hỏa Băng, standing: six steam puffs rising from the tile to 1.2 H, growing 6 → 14 px then thinning, with a
## bright cap each; the burst of the hit stays underneath.
static func _steam_standing(out: Array[Dictionary], s: _Stand, u: float) -> void:
	for i: int in 6:
		var start: float = s.rng.randf_range(0.0, 0.3)
		var x0: int = roundi(s.rng.randf_range(-float(s.hw) + 8.0, float(s.hw) - 8.0))
		var sway: float = s.rng.randf_range(2.0, 5.0)
		var lag: float = clampf((u - start) / 0.7, 0.0, 1.0)
		if lag <= 0.0:
			continue
		var up: int = 4 + roundi(float(s.H) * 1.2 * lag)
		var size: int = roundi(6.0 + 8.0 * minf(lag * 2.0, 1.0)) - roundi(4.0 * maxf(lag - 0.7, 0.0) / 0.3)
		var dx: int = x0 + roundi(sin(lag * 5.0 + float(i)) * sway)
		out.append(s.sq(dx, up, size, false))
		out.append(s.sq(dx - 2, up + 3, maxi(size - 6, 2), true))


## Băng Vỡ, standing: a 20 px ice block on the tile cracks (dark lines over its face, u < 0.4), flashes, then
## bursts into fourteen chunks and the block's halves fall apart.
static func _iceburst_standing(out: Array[Dictionary], s: _Stand, u: float) -> void:
	if u < 0.4:
		out.append(s.sq(0, 12, 20, false))
		out.append(s.sq(-5, 17, 6, true))
		var cracks: int = clampi(ceili(u / 0.4 * 4.0), 0, 4)
		for i: int in cracks:
			var a: Vector2i = Vector2i(0, 12) + Vector2i([-8, 6, 4, -6][i], [6, 8, -7, -5][i])
			out.append({"rect": Rect2i(s.base.x + a.x - 1, s.base.y - a.y - 4, 2, 8), "light": false})
		if u > 0.34:
			out.append(s.sq(0, 12, 22, true))
		return
	var k: float = (u - 0.4) / 0.6
	for sd: int in [-1, 1]:
		out.append(s.sq(sd * (6 + roundi(k * 10.0)), maxi(10 - roundi(k * k * 14.0), 3), 10, false))
	for i: int in 14:
		var a: float = PI * (float(i) + 0.5) / 14.0
		var vx: float = cos(a) * float(s.hw) * s.rng.randf_range(0.8, 1.4)
		var vy: float = (0.3 + 0.9 * sin(a)) * float(s.H) * s.rng.randf_range(0.6, 1.2)
		var up: int = roundi(12.0 + vy * k - vy * 0.9 * k * k)
		out.append(s.sq(roundi(vx * k), maxi(up, 2), 5 if i % 3 == 0 else 4, i % 2 == 0))


## Hồi Âm, flat: the first hit's scar (a stepped line across the cell), then at the echo (see aftermath) a ghost.
static func _arc_scar(out: Array[Dictionary], g: _Geo, u: float) -> void:
	if u < 0.3:
		return
	var reveal: float = minf((u - 0.3) / 0.3, 1.0)
	var a := Vector2i(g.r.position.x + 4, g.r.end.y - 6)
	var b := Vector2i(g.r.end.x - 4, g.r.position.y + 6)
	var end: Vector2i = Vector2i((Vector2(a) + Vector2(b - a) * reveal).round())
	_stepped(out, a, end, 2, 2)


## Địa Chấn, flat: three square rings expanding one after another to the cell edge and fading, over radial cracks.
static func _quake_floor(out: Array[Dictionary], g: _Geo, u: float) -> void:
	for i: int in 3:
		var k: float = clampf((u - float(i) * 0.15) / 0.6, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var frac: float = lerpf(0.2, 1.0, k)
		_outline(out, Rect2i(g.c - Vector2i(roundi(float(g.hw) * frac), roundi(float(g.hh) * frac)),
			Vector2i(roundi(float(g.w) * frac), roundi(float(g.h) * frac))), 4 if k < 0.5 else 3)
	_crack(out, g, minf(u / 0.5, 1.0) * 0.6, {"lines": 5})


## Địa Chấn, standing: slabs of ground heave up in a row across the tile (each a 10 px bar lifting then dropping,
## staggered), and ten stones thrown up with dust.
static func _quake_standing(out: Array[Dictionary], s: _Stand, u: float) -> void:
	for i: int in 5:
		var k: float = clampf((u - float(i) * 0.06) / 0.5, 0.0, 1.0)
		var lift: int = roundi(float(s.H) * 0.35 * 4.0 * k * (1.0 - k))
		out.append(s.slab(-s.hw + 7 + i * _d(s.w - 10, 5), lift, 10, 5, k > 0.3 and k < 0.7))
	for i: int in 10:
		var a: float = PI * (float(i) + 0.5) / 10.0
		var vx: float = cos(a) * float(s.hw) * s.rng.randf_range(0.7, 1.3)
		var vy: float = (0.5 + 0.6 * sin(a)) * float(s.H) * s.rng.randf_range(0.6, 1.2)
		var up: int = roundi(vy * u - vy * 0.9 * u * u)
		out.append(s.sq(roundi(vx * u), maxi(up, 0) + 6, 5 if i % 3 == 0 else 3, i % 2 == 0))


## The form of a card's variant entry ({"form": ..., knobs}); "" when it names none or an unknown one.
static func form_of(variant: Dictionary) -> String:
	var f: String = str(variant.get("form", ""))
	return f if FORMS.has(f) else ""


## The clip position 0..1 of [param form] at [param age], or -1 when nothing draws (outside [0, sec), or past the
## reduce-motion hold).
static func _u(form: String, age: float, sec: float, reduce: bool) -> float:
	if sec <= 0.0 or age < 0.0 or age >= sec or not FORMS.has(form):
		return -1.0
	if reduce and age >= REDUCE_HOLD_SEC:
		return -1.0
	return float(REDUCE_U_BY_FORM.get(form, REDUCE_U)) if reduce else age / sec


# --- geometry helpers ------------------------------------------------------------------------------

## Whole-px floor division without the integer_division warning.
static func _d(a: int, b: int) -> int:
	return floori(float(a) / float(b))


static func _sq(centre: Vector2i, size: int, light: bool) -> Dictionary:
	var s: int = maxi(size, 1)
	return {"rect": Rect2i(centre - Vector2i(_d(s, 2), _d(s, 2)), Vector2i(s, s)), "light": light}


static func _bar_at(x: int, y: int, bw: int, bh: int, light: bool) -> Dictionary:
	return {"rect": Rect2i(x, y, maxi(bw, 1), maxi(bh, 1)), "light": light}


## The 4 bars of a square outline [param t] px thick inside [param f] (top / left light, bottom / right body).
static func _outline(out: Array[Dictionary], f: Rect2i, t: int) -> void:
	var tt: int = maxi(t, 1)
	out.append(_bar_at(f.position.x, f.position.y, f.size.x, tt, true))
	out.append(_bar_at(f.position.x, f.end.y - tt, f.size.x, tt, false))
	out.append(_bar_at(f.position.x, f.position.y + tt, tt, f.size.y - tt * 2, true))
	out.append(_bar_at(f.end.x - tt, f.position.y + tt, tt, f.size.y - tt * 2, false))


## A stepped (pixel-art) line of [param size] px squares from [param a] to [param b], every [param gap] px.
static func _stepped(out: Array[Dictionary], a: Vector2i, b: Vector2i, size: int, gap: int) -> void:
	var d: Vector2 = Vector2(b - a)
	var n: int = maxi(int(d.length() / float(maxi(gap, 1))), 1)
	for i: int in n + 1:
		out.append(_sq(Vector2i((Vector2(a) + d * (float(i) / float(n))).round()), size, i >= n - 1))


## The flat cell: rect, size, centre, half sizes, travel sign, seeded rng.
class _Geo:
	var r: Rect2i
	var w: int
	var h: int
	var hw: int
	var hh: int
	var c: Vector2i
	var sgn: int
	var whole: bool = false
	var rng := RandomNumberGenerator.new()

	func _init(rect: Rect2i, dir: int, seed: int) -> void:
		r = rect
		w = rect.size.x
		h = rect.size.y
		hw = ImpactFx._d(w, 2)
		hh = ImpactFx._d(h, 2)
		c = rect.position + Vector2i(hw, hh)
		sgn = dir
		rng.seed = seed & 0x7FFFFFFF

	func sq(centre: Vector2i, size: int, light: bool) -> Dictionary:
		return ImpactFx._sq(centre, size, light)

	func bar(x: int, y: int, bw: int, bh: int, light: bool) -> Dictionary:
		return ImpactFx._bar_at(x, y, bw, bh, light)


## The standing frame: base point (tile ground centre), the tile's width and the standing height unit H = cell_w *
## COLUMN_CELLS; x across the tile (± hw), y UP from the base (positive = higher, converted on output).
class _Stand:
	var base: Vector2i
	var w: int
	var hw: int
	var H: int
	var sgn: int
	var whole: bool = false
	var rng := RandomNumberGenerator.new()

	func _init(b: Vector2i, cell_w: int, dir: int, seed: int) -> void:
		base = b
		w = cell_w
		hw = ImpactFx._d(cell_w, 2)
		H = maxi(roundi(float(cell_w) * ImpactFx.COLUMN_CELLS), 8)
		sgn = dir
		rng.seed = (seed * 7 + 3) & 0x7FFFFFFF

	## A square centred [param dx] across and [param up] above the base.
	func sq(dx: int, up: int, size: int, light: bool) -> Dictionary:
		return ImpactFx._sq(Vector2i(base.x + dx, base.y - up), size, light)

	## A bar [param bw] wide centred on [param dx], its bottom [param up] above the base, [param bh] tall.
	func slab(dx: int, up: int, bw: int, bh: int, light: bool) -> Dictionary:
		return ImpactFx._bar_at(base.x + dx - ImpactFx._d(bw, 2), base.y - up - bh, bw, bh, light)

	## A stepped column: [param layers] slabs 3 px tall from the base up, [param base_w] wide at the bottom tapering to
	## 2 px, leaning [param lean] px per layer; the top two layers light.
	func column(out: Array[Dictionary], dx: int, layers: int, base_w: int, lean: int) -> void:
		for k: int in layers:
			var s: int = maxi(base_w - ImpactFx._d(k * base_w, maxi(layers, 1)), 2)
			out.append(slab(dx + lean * k, k * 3, s, 3, k >= layers - 2))

	## A sweep streak from [param a] to [param b] (across, up): a STREAK_SIZE head with a STREAK_TAIL tail that thins,
	## moving along with [param k]; whole when `whole`. Two body-colour shadow lines run beside it.
	func streak(out: Array[Dictionary], a: Vector2i, b: Vector2i, k: float, size: int) -> void:
		var pa := Vector2i(base.x + a.x, base.y - a.y)
		var pb := Vector2i(base.x + b.x, base.y - b.y)
		var d: Vector2 = Vector2(pb - pa)
		var n: int = maxi(int(d.length() / float(ImpactFx.STREAK_GAP)), 1)
		var head: int = n if whole else roundi(k * float(n + ImpactFx.STREAK_TAIL))
		var from: int = 0 if whole else head - ImpactFx.STREAK_TAIL
		var across: Vector2 = Vector2(-d.y, d.x).normalized() * 4.0
		for i: int in range(maxi(from, 0), mini(head, n) + 1):
			var p: Vector2i = Vector2i((Vector2(pa) + d * (float(i) / float(n))).round())
			var back: int = head - i
			var s: int = size if back <= 4 else (size - 1 if back <= 9 else maxi(size - 2, 2))
			out.append(ImpactFx._sq(Vector2i((Vector2(p) + across).round()), 3, false))
			out.append(ImpactFx._sq(Vector2i((Vector2(p) - across).round()), 2, false))
			out.append(ImpactFx._sq(p, s, back <= 4))


# --- shared layers ---------------------------------------------------------------------------------

## Standing hit burst: BURST_SHARDS squares thrown up and out from the base in arcs (gravity brings them back
## down), 4 px then 3 px, over the first BURST_END of the clip.
static func _burst_up(out: Array[Dictionary], s: _Stand, u: float) -> void:
	if u < SHEET_END or u >= BURST_END:
		return
	var k: float = (u - SHEET_END) / (BURST_END - SHEET_END)
	for i: int in BURST_SHARDS:
		var a: float = PI * (float(i) + 0.5) / float(BURST_SHARDS) + s.rng.randf_range(-0.12, 0.12)
		var vx: float = cos(a) * float(s.hw) * s.rng.randf_range(0.7, 1.2)
		var vy: float = (0.6 + 0.5 * sin(a)) * float(s.H) * s.rng.randf_range(0.55, 1.25)
		var dx: int = roundi(vx * k)
		var up: int = roundi(vy * k - vy * 0.75 * k * k)
		out.append(s.sq(dx, maxi(up, 0), 4 if k < 0.5 else 3, i % 2 == 0))


## Flat residue on every form: ten 2–3 px dust squares spread over the cell, settling and fading out from
## RESIDUE_FROM to the end.
static func _residue(out: Array[Dictionary], g: _Geo, u: float) -> void:
	if u < RESIDUE_FROM:
		return
	var k: float = (u - RESIDUE_FROM) / (1.0 - RESIDUE_FROM)
	for i: int in 10:
		var x: int = g.r.position.x + 3 + _d((g.w - 6) * (i * 2 + 1), 20) + ((i * 7) % 3) - 1
		var y: int = g.r.position.y + 3 + ((i * 11) % maxi(g.h - 8, 1)) + roundi(k * 5.0)
		out.append(g.sq(Vector2i(x, y), (3 if i % 3 == 0 else 2) if k < 0.6 else 1, i % 3 == 0))


# --- freeze ----------------------------------------------------------------------------------------

## Đóng Băng, flat: twelve shards fall onto the cell (u < 0.4), then a 4 px ice frame freezes 2 px inside the cell
## with 6 px corner studs and rime squares inside. Knobs: `sparse` (a 3 px dashed frame and loose mist, Sương Mỏng).
static func _frame(out: Array[Dictionary], g: _Geo, u: float, params: Dictionary) -> void:
	var sparse: bool = bool(params.get("sparse", false))
	var f: Rect2i = g.r.grow(-2)
	if u < 0.4:
		var k: float = u / 0.4
		var n: int = 6 if sparse else 12
		for i: int in n:
			var x: int = f.position.x + roundi(float(f.size.x) * (float(i) + 0.5) / float(n))
			var y: int = g.r.position.y + roundi(float(f.size.y) * k * (0.6 + 0.4 * float(i % 2)))
			out.append(g.sq(Vector2i(x, mini(y, f.end.y - 2)), 4 if i % 2 == 0 else 3, i % 2 == 0))
		return
	var k2: float = (u - 0.4) / 0.6
	if sparse:
		var dash: int = 6
		for x: int in range(f.position.x, f.end.x, dash * 2):
			out.append(g.bar(x, f.position.y, mini(dash, f.end.x - x), 3, true))
			out.append(g.bar(x, f.end.y - 3, mini(dash, f.end.x - x), 3, false))
		for y: int in range(f.position.y + dash, f.end.y - 3, dash * 2):
			out.append(g.bar(f.position.x, y, 3, mini(dash, f.end.y - 3 - y), true))
			out.append(g.bar(f.end.x - 3, y, 3, mini(dash, f.end.y - 3 - y), false))
		for i: int in 8:
			out.append(g.sq(Vector2i(f.position.x + 8 + _d((f.size.x - 16) * (i % 4), 3), f.position.y + 9 + (f.size.y - 18) * _d(i, 4)), 3, i % 2 == 0))
		return
	_outline(out, f, 3 if k2 < 0.25 else 4)
	if k2 > 0.3:
		for p: Vector2i in [f.position, Vector2i(f.end.x - 6, f.position.y), Vector2i(f.position.x, f.end.y - 6), Vector2i(f.end.x - 6, f.end.y - 6)]:
			out.append({"rect": Rect2i(p, Vector2i(6, 6)), "light": true})
	if k2 > 0.45:
		var inner: Rect2i = f.grow(-6)
		for j: int in 3:
			for i: int in 5:
				if (i + j) % 2 == 1:
					continue
				out.append(g.sq(Vector2i(inner.position.x + _d(inner.size.x * (i * 2 + 1), 10), inner.position.y + _d(inner.size.y * (j * 2 + 1), 6)),
					4 if (i == 2 and j == 1) else 3, j == 1))


## Đóng Băng, standing: once the frame is set (u > 0.4) four ice crystals rise at the tile's corners (0.45 H) and a
## fifth at the centre (0.3 H); the sparse mist raises three thin ones instead.
static func _frame_crystals(out: Array[Dictionary], s: _Stand, u: float, params: Dictionary) -> void:
	if u < 0.4:
		return
	var k: float = minf((u - 0.4) / 0.3, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	var sparse: bool = bool(params.get("sparse", false))
	var spots: Array = [[-s.hw + 6, 0.45, 8], [s.hw - 6, 0.45, 8], [-_d(s.hw, 2), 0.3, 6], [_d(s.hw, 2), 0.3, 6], [0, 0.35, 7]] \
		if not sparse else [[-_d(s.hw, 2), 0.3, 4], [_d(s.hw, 2), 0.3, 4], [0, 0.4, 4]]
	for sp: Array in spots:
		var layers: int = maxi(roundi(float(s.H) * float(sp[1]) * k / 3.0), 1)
		s.column(out, int(sp[0]), layers, int(sp[2]), 0)


## Giá Lạnh, flat: shards fall (u < 0.35), then a 4 px plus sign grows to the cell edges with 6 px caps and
## diagonal arms (a snowflake). Knobs: `diag` (the diagonals come first), `drops` (water drops fall first).
static func _cross(out: Array[Dictionary], g: _Geo, u: float, params: Dictionary) -> void:
	var diag: bool = bool(params.get("diag", false))
	var drops: int = int(params.get("drops", 0))
	if u < 0.35:
		var k: float = u / 0.35
		var n: int = 8 + drops
		for i: int in n:
			var x: int = g.r.position.x + 3 + _d((g.w - 6) * (i * 2 + 1), n * 2)
			var y: int = g.r.position.y + roundi(float(g.hh) * k * (0.7 + 0.3 * float(i % 2)))
			out.append(g.sq(Vector2i(x, y), 4 if i < drops or i % 2 == 0 else 3, i < drops))
		return
	var k2: float = (u - 0.35) / 0.65
	var reach: int = roundi(float(g.hw - 2) * minf(k2 * 1.6, 1.0))
	var vr: int = roundi(float(g.hh - 2) * minf(k2 * 1.6, 1.0))
	out.append(g.sq(g.c, 8, true))
	if diag:
		for st: int in range(3, reach + 1, 3):
			for v: Vector2i in [Vector2i(st, -st), Vector2i(-st, -st), Vector2i(st, st), Vector2i(-st, st)]:
				out.append(g.sq(g.c + Vector2i(v.x, roundi(float(v.y) * float(g.hh) / float(g.hw))), 4, false))
		if k2 > 0.6:
			out.append(g.bar(g.c.x - reach, g.c.y - 1, reach * 2 + 1, 3, true))
			out.append(g.bar(g.c.x - 1, g.c.y - vr, 3, vr * 2 + 1, true))
		return
	out.append(g.bar(g.c.x - reach, g.c.y - 2, reach * 2 + 1, 4, false))
	out.append(g.bar(g.c.x - 2, g.c.y - vr, 4, vr * 2 + 1, false))
	if k2 > 0.5:
		for v: Vector2i in [Vector2i(reach, 0), Vector2i(-reach, 0), Vector2i(0, vr), Vector2i(0, -vr)]:
			out.append(g.sq(g.c + v, 6, true))
	if k2 > 0.7:
		for st: int in range(4, reach - 2, 4):
			for v: Vector2i in [Vector2i(st, -st), Vector2i(-st, -st), Vector2i(st, st), Vector2i(-st, st)]:
				out.append(g.sq(g.c + Vector2i(v.x, roundi(float(v.y) * float(g.hh) / float(g.hw))), 3, true))


## Giá Lạnh, standing: a central ice crystal (0.55 H, 10 px base) rises as the cross forms, flanked by two small
## ones at the cell thirds (0.3 H); Thanh Thủy's drops splash up as 3 px squares first.
static func _cross_crystal(out: Array[Dictionary], s: _Stand, u: float, params: Dictionary) -> void:
	var drops: int = int(params.get("drops", 0))
	if u < 0.35:
		if drops > 0 and u > 0.1:
			var k0: float = (u - 0.1) / 0.25
			for i: int in drops:
				var dx: int = (i - _d(drops, 2)) * _d(s.w, 4)
				out.append(s.sq(dx, roundi(float(s.H) * 0.25 * (1.0 - (1.0 - k0) * (1.0 - k0))), 3, true))
		return
	var k: float = minf((u - 0.35) / 0.3, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	s.column(out, 0, maxi(roundi(float(s.H) * 0.55 * k / 3.0), 1), 10, 0)
	for dx: int in [-_d(s.w, 3), _d(s.w, 3)]:
		s.column(out, dx, maxi(roundi(float(s.H) * 0.3 * k / 3.0), 1), 6, 0)


## Ice strike, standing: stepped ice columns rise to the full height (16 px base), each flanked by two half-height
## shards; a lone column gets two more at the thirds. Knobs: `count` (1 or 2), `tilt` (leans the travel way).
static func _spike(out: Array[Dictionary], s: _Stand, u: float, params: Dictionary) -> void:
	var count: int = clampi(int(params.get("count", 1)), 1, 2)
	var lean: int = s.sgn if bool(params.get("tilt", false)) else 0
	var rise: float = minf(u / 0.45, 1.0)
	rise = 1.0 - (1.0 - rise) * (1.0 - rise)
	var columns: Array = [[-_d(s.w, 4), 1.0, 16], [_d(s.w, 4), 1.0, 16]] if count == 2 \
		else [[0, 1.0, 16], [-_d(s.w, 3), 0.55, 9], [_d(s.w, 3), 0.55, 9]]
	for col: Array in columns:
		var layers: int = maxi(roundi(float(s.H) * float(col[1]) * rise / 3.0), 1)
		s.column(out, int(col[0]), layers, int(col[2]), lean)
		if int(col[2]) >= 16:
			for sdx: int in [-1, 1]:
				s.column(out, int(col[0]) + sdx * 11, maxi(_d(layers, 2), 1), 6, 0)


## Chain freeze, standing: seven ice blocks pop up across the tile one after another (0.06 apart), each rising a
## little as it grows 1 → 9 px, then holding with a lit top.
static func _cluster(out: Array[Dictionary], s: _Stand, u: float, _params: Dictionary) -> void:
	var spots: Array = [[0, 6], [-_d(s.w, 3), 2], [_d(s.w, 3), 10], [_d(s.w, 6), 0], [-_d(s.w, 6), 12], [-s.hw + 6, 7], [s.hw - 6, 4]]
	for i: int in spots.size():
		var k: float = clampf((u - float(i) * 0.06) / 0.3, 0.0, 1.0)
		if k <= 0.0:
			continue
		var size: int = clampi(ceili(k * 10.0), 1, 9 if i < 5 else 6)
		var up: int = int(spots[i][1]) + roundi(k * 6.0) + _d(size, 2)
		out.append(s.sq(int(spots[i][0]), up, size, false))
		if size >= 4:
			out.append(_bar_at(s.base.x + int(spots[i][0]) - _d(size, 2), s.base.y - up - _d(size, 2), _d(size, 2), 2, true))


# --- slash (standing, in the vertical plane facing the camera) --------------------------------------

## One streak sweeping across the tile the way the cast travels, rising from 0.15 H to 0.85 H. [param dy] shifts it
## (the double form). Knobs: `size`.
static func _arc(out: Array[Dictionary], s: _Stand, u: float, dy: float, params: Dictionary) -> void:
	var size: int = clampi(int(params.get("size", STREAK_SIZE)), 3, 6)
	var off: int = roundi(dy * float(s.H))
	var a := Vector2i(-s.sgn * (s.hw - 2), roundi(float(s.H) * 0.15) + off)
	var b := Vector2i(s.sgn * (s.hw - 2), roundi(float(s.H) * 0.85) + off)
	s.streak(out, a, b, u, size)


## Sky slash: the streak drops from 1.0 H to the ground, leaning the travel way. Knobs: `size`.
static func _arc_v(out: Array[Dictionary], s: _Stand, u: float, params: Dictionary) -> void:
	var size: int = clampi(int(params.get("size", STREAK_SIZE)), 3, 6)
	s.streak(out, Vector2i(-s.sgn * _d(s.w, 4), s.H), Vector2i(s.sgn * _d(s.w, 4), 2), u, size)


## Two streaks crossing in an X over the tile (0.1 H .. 0.9 H), the second 0.25 behind. Knobs: `size`.
static func _cross_x(out: Array[Dictionary], s: _Stand, u: float, params: Dictionary) -> void:
	var size: int = clampi(int(params.get("size", STREAK_SIZE)), 3, 6)
	var lo: int = roundi(float(s.H) * 0.1)
	var hi: int = roundi(float(s.H) * 0.9)
	var dx: int = s.hw - 2
	var lines: Array = [[Vector2i(-s.sgn * dx, hi), Vector2i(s.sgn * dx, lo), 0.0], [Vector2i(s.sgn * dx, hi), Vector2i(-s.sgn * dx, lo), 0.25]]
	for l: Array in lines:
		var k: float = (u - float(l[2])) / 0.75
		if k > 0.0:
			s.streak(out, l[0], l[1], minf(k, 1.0), size)


## Two parallel streaks 0.4 H apart, the lower one 0.15 behind. Knobs: `size`.
static func _double(out: Array[Dictionary], s: _Stand, u: float, params: Dictionary) -> void:
	_arc(out, s, u, 0.12, params)
	var k: float = (u - 0.15) / 0.85
	if k > 0.0:
		_arc(out, s, minf(k, 1.0), -0.12, params)


## Four bars rush in from the corners of the standing plane in trails of three and meet at the centre (u 0.6),
## which flashes a 16 px square.
static func _stab4(out: Array[Dictionary], s: _Stand, u: float, _params: Dictionary) -> void:
	var k: float = minf(u / 0.6, 1.0)
	var cy: int = _d(s.H, 2)
	var dx: int = roundi(float(s.hw - 10) * (1.0 - k))
	var dyy: int = roundi(float(cy - 8) * (1.0 - k))
	for v: Vector2i in [Vector2i(dx, dyy), Vector2i(-dx, dyy), Vector2i(dx, -dyy), Vector2i(-dx, -dyy)]:
		if u < 0.6:
			for t: int in 3:
				out.append(s.sq(v.x + signi(v.x) * t * 4, cy + v.y + signi(v.y) * t * 3, 6 - t, t == 0))
	if u >= 0.5:
		out.append(s.sq(0, cy, 22 if u < 0.65 else 14, false))
		out.append(s.sq(0, cy, 16 if u < 0.75 else 9, true))


# --- shatter ---------------------------------------------------------------------------------------

## Rạn, flat: 2 px stepped cracks spread from a 6 px core to the cell edges (6 lines), revealed over the first 0.6
## and holding. Knobs: `web` (a 3 px dashed ring joins the tips, Rạn Vân), `lines`.
static func _crack(out: Array[Dictionary], g: _Geo, u: float, params: Dictionary) -> void:
	var web: bool = bool(params.get("web", false))
	var lines: int = clampi(int(params.get("lines", 6)), 2, 8)
	var reveal: float = minf(u / 0.6, 1.0)
	for i: int in lines:
		var ang: float = TAU * (float(i) / float(lines)) + g.rng.randf_range(-0.35, 0.35)
		var reach: float = g.rng.randf_range(0.85, 1.0)
		var prev: Vector2i = g.c
		for k: int in 3:
			var rr: float = reach * float(k + 1) / 3.0
			var a2: float = ang + g.rng.randf_range(-0.35, 0.35)
			var p := Vector2i((Vector2(g.c) + Vector2(cos(a2) * float(g.hw - 2), sin(a2) * float(g.hh - 2)) * rr).round())
			var seg_k: float = clampf(reveal * 3.0 - float(k), 0.0, 1.0)
			if seg_k <= 0.0:
				break
			_stepped(out, prev, Vector2i((Vector2(prev) + Vector2(p - prev) * seg_k).round()), 3 if k == 0 else 2, 1)
			prev = p
	if web and u > 0.45:
		var f: Rect2i = g.r.grow(-3)
		for x: int in range(f.position.x, f.end.x, 10):
			out.append(g.bar(x, f.position.y, 5, 3, false))
			out.append(g.bar(x, f.end.y - 3, 5, 3, false))
		for y: int in range(f.position.y, f.end.y, 10):
			out.append(g.bar(f.position.x, y, 3, 5, false))
			out.append(g.bar(f.end.x - 3, y, 3, 5, false))
	out.append(g.sq(g.c, 6, true))


## Hàn Băng, standing: after the cracks (u > 0.35) eight 6 px chunks are thrown up from across the tile and fall
## back, drifting apart.
static func _chunks(out: Array[Dictionary], s: _Stand, u: float, _params: Dictionary) -> void:
	if u < 0.35:
		return
	var k: float = (u - 0.35) / 0.65
	for i: int in 8:
		var dx0: int = -s.hw + 5 + _d((s.w - 10) * (i * 2 + 1), 16)
		var vy: float = float(s.H) * s.rng.randf_range(0.35, 0.75)
		var up: int = roundi(vy * k - vy * 1.0 * k * k)
		var drift: int = roundi(k * 6.0) * (1 if i % 2 else -1)
		out.append(s.sq(dx0 + drift, maxi(up, 0) + 3, 6 if k < 0.6 else 4, i % 2 == 0))


## Băng Tâm, standing: sixteen 4–5 px shards burst up and out from the base and rain back down. Knobs: `count`.
static func _shards(out: Array[Dictionary], s: _Stand, u: float, params: Dictionary) -> void:
	var count: int = clampi(int(params.get("count", 16)), 6, 20)
	for i: int in count:
		var a: float = PI * (float(i) + 0.5) / float(count) + s.rng.randf_range(-0.15, 0.15)
		var vx: float = cos(a) * float(s.hw) * s.rng.randf_range(0.8, 1.3)
		var vy: float = (0.4 + 0.7 * sin(a)) * float(s.H) * s.rng.randf_range(0.5, 1.2)
		var up: int = roundi(vy * u - vy * 0.9 * u * u)
		out.append(s.sq(roundi(vx * u), maxi(up, 0) + 2, 5 if i % 3 == 0 and u < 0.6 else 4, i % 2 == 0))


# --- knockback -------------------------------------------------------------------------------------

## Push, standing: a wall of six 8 px squares (0.9 H tall) slides across the tile the way the cast travels, thinning
## to 5 px, a second wall 0.15 behind. Knobs: `count` (2: a third wall, Cuồng Phong).
static func _column(out: Array[Dictionary], s: _Stand, u: float, params: Dictionary) -> void:
	var count: int = clampi(int(params.get("count", 1)), 1, 2) + 1
	var step: int = maxi(_d(s.H * 9, 50), 5)
	for j: int in count:
		var k: float = (u - float(j) * 0.15) / (1.0 - float(j) * 0.15)
		if k <= 0.0:
			continue
		var dx: int = -s.sgn * (s.hw - 5) + s.sgn * roundi(k * float(s.w - 8)) - s.sgn * j * 5
		var size: int = (8 if k < 0.4 else (7 if k < 0.75 else 5)) - j
		for i: int in 6:
			out.append(s.sq(dx, 4 + i * step, size, j == 0 and i >= 1 and i <= 4))


## Ground push, flat: a stepped wedge (rows 8 / 16 / 24 / 32 px) pointing the travel way crosses the whole cell.
static func _wedge(out: Array[Dictionary], g: _Geo, u: float, _params: Dictionary) -> void:
	var x: int = g.c.x - g.sgn * (g.hw - 6) + g.sgn * roundi(u * float(g.w - 4))
	var widths: Array[int] = [8, 16, 24, 32]
	for i: int in 4:
		var bw: int = widths[i]
		out.append(g.bar(x - (bw if g.sgn > 0 else 0), g.c.y + (i - 2) * 5, bw, 5, i <= 1))


## Ground push, standing: eight dust squares kicked up behind the wedge, hopping and settling.
static func _wedge_dust(out: Array[Dictionary], s: _Stand, u: float) -> void:
	if u < 0.2:
		return
	var k: float = (u - 0.2) / 0.8
	var front: int = -s.sgn * (s.hw - 6) + s.sgn * roundi(u * float(s.w - 4))
	for i: int in 8:
		var lag: float = clampf(k * 1.5 - float(i) * 0.1, 0.0, 1.0)
		var up: int = roundi(float(s.H) * 0.35 * (lag - lag * lag) * 4.0 * 0.25) + 2
		var dx: int = front - s.sgn * (10 + i * 5)
		if absi(dx) <= s.hw - 3:
			out.append(s.sq(dx, up + (i % 3) * 3, 4 if i < 3 else 3, i % 2 == 0))


## Sky push, flat: a 4 px square ring slams in from the cell edge to 0.6 of it (u < 0.35) and holds a while.
static func _slam_floor(out: Array[Dictionary], g: _Geo, u: float) -> void:
	if u < 0.35:
		var k: float = u / 0.35
		var frac: float = lerpf(1.0, 0.6, k)
		_outline(out, Rect2i(g.c - Vector2i(roundi(float(g.hw) * frac), roundi(float(g.hh) * frac)),
			Vector2i(roundi(float(g.w) * frac), roundi(float(g.h) * frac))), 4)
	elif u < 0.65:
		_outline(out, Rect2i(g.c - Vector2i(roundi(float(g.hw) * 0.6), roundi(float(g.hh) * 0.6)),
			Vector2i(roundi(float(g.w) * 0.6), roundi(float(g.h) * 0.6))), 3)


## Sky push, standing: after the slam (u > 0.35) eight shards fly out low to both sides and a dust plume rises.
static func _slam_shards(out: Array[Dictionary], s: _Stand, u: float) -> void:
	if u < 0.35:
		return
	var k: float = (u - 0.35) / 0.65
	for sd: int in [-1, 1]:
		for i: int in 4:
			var vx: float = float(s.hw) * (0.6 + 0.15 * float(i))
			var vy: float = float(s.H) * (0.25 + 0.12 * float(i % 3))
			var up: int = roundi(vy * k - vy * 0.9 * k * k)
			out.append(s.sq(sd * roundi(vx * k) + sd * 4, maxi(up, 0) + 2, 5 - _d(i, 2), i % 2 == 0))
	var plume: int = roundi(float(s.H) * 0.4 * (1.0 - (1.0 - k) * (1.0 - k)))
	for i: int in 3:
		out.append(s.sq((i - 1) * 7, plume - i * 5, 4, false))


# --- thorns / poison -------------------------------------------------------------------------------

## Bãi Gai, standing: seven stepped thorns rise from the front of the tile to 0.5 H, 10 px wide at the base.
## Knobs: `vine` (the flat vine is in [method items]; here 2 px buds sit on the thorns once they stand).
static func _spikes(out: Array[Dictionary], s: _Stand, u: float, params: Dictionary) -> void:
	var vine: bool = bool(params.get("vine", false))
	var rise: float = minf(u / 0.4, 1.0)
	rise = 1.0 - (1.0 - rise) * (1.0 - rise)
	var step: int = _d(s.w - 6, 6)
	for i: int in 7:
		var dx: int = -s.hw + 3 + i * step
		var frac: float = 0.5 if i % 2 == 0 else 0.35
		var layers: int = maxi(roundi(float(s.H) * frac * rise / 3.0), 1)
		s.column(out, dx, layers, 10 if i % 2 == 0 else 7, 0)
		if vine and u > 0.4:
			out.append(s.sq(dx + 3, layers * 3 - 4, 3, true))


## Gai Độc, standing: seven bubbles rise from the ground to 0.9 H, then each pops into four 3 px dots.
static func _bubbles(out: Array[Dictionary], s: _Stand, u: float, _params: Dictionary) -> void:
	for i: int in 7:
		var dx: int = -s.hw + 4 + _d((s.w - 8) * (i * 2 + 1), 14) + roundi(s.rng.randf_range(-2.0, 2.0))
		var lag: float = clampf((u - s.rng.randf_range(0.0, 0.4)) / 0.9, 0.0, 1.0)
		if lag <= 0.0:
			continue
		var up: int = 4 + roundi(lag * float(s.H) * 0.9)
		if lag < 0.7:
			var size: int = 6 if i % 2 == 0 else 5
			out.append(s.sq(dx, up, size, false))
			out.append(s.sq(dx - 1, up + 1, 2, true))
		else:
			var spread: int = roundi((lag - 0.7) * 20.0) + 3
			out.append(s.sq(dx - spread, up, 3, true))
			out.append(s.sq(dx + spread, up, 3, true))
			out.append(s.sq(dx, up + spread, 3, false))
			out.append(s.sq(dx, up - spread, 3, false))


# --- burst -----------------------------------------------------------------------------------------

## Burst, flat: a 4 px square ring expands from the centre to the cell edges. [param phase] delays it.
static func _ring_floor(out: Array[Dictionary], g: _Geo, u: float, phase: float, _params: Dictionary) -> void:
	var k: float = (u - phase) / (1.0 - phase)
	if k <= 0.0 or k > 0.8:
		return
	var fx: float = lerpf(0.15, 1.0, k)
	_outline(out, Rect2i(g.c - Vector2i(roundi(float(g.hw) * fx), roundi(float(g.hh) * fx)),
		Vector2i(roundi(float(g.w) * fx), roundi(float(g.h) * fx))), 4 if k < 0.5 else 3)


## Burst, standing: sixteen shards fan up from the base to 0.8 H and fall back; [param phase] delays it (Độ Kiếm's
## second burst). Knobs: `count`.
static func _ring_up(out: Array[Dictionary], s: _Stand, u: float, phase: float, params: Dictionary) -> void:
	var count: int = clampi(int(params.get("count", 16)), 8, 20)
	var k: float = (u - phase) / (1.0 - phase)
	if k <= 0.0:
		return
	for i: int in count:
		var a: float = PI * (float(i) + 0.5) / float(count) + s.rng.randf_range(-0.1, 0.1)
		var vx: float = cos(a) * float(s.hw) * s.rng.randf_range(0.8, 1.3)
		var vy: float = (0.3 + 0.6 * sin(a)) * float(s.H) * s.rng.randf_range(0.55, 1.3)
		var up: int = roundi(vy * k - vy * 0.85 * k * k)
		out.append(s.sq(roundi(vx * k), maxi(up, 0) + 2, 5 if k < 0.5 else 4, i % 2 == 0))

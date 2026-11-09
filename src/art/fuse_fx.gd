class_name FuseFx
extends RefCounted
## Skill v2 Hỏa Lôi H2 (docs/skill-v2/09-hoa-loi-design.md §12): the delayed-explosion visuals, pure and deterministic.
## Every record comes from the AUTHORITATIVE schedule (SwingArbiter.cast_scheduled: the armed event's cells and `at`);
## nothing here decides a time or a cell. Stages, on the arbiter clock:
##   1 seal      a geometric fire sigil draws itself on each armed slab (corners first, DRAW_IN_SEC)
##   2 charge    three nested charge rings count down 3-2-1 (the outermost ring goes out each third of the fuse), the
##               core and the fill brighten each step
##   3 warning   the last FINAL_SEC: the frame thickens and flickers cream / orange (steady under reduce motion), the
##               core swells; the last COLLAPSE_SEC every ring collapses into the core (anticipation)
##   4 blast     at `at`, on every armed cell at once: a cream ground flash and a square shock ring on the slab (floor),
##               and a stepped flame column rising from the tile (screen space, overlay), then smoke and embers
##   fizzle      a cell locked before the blast (SwingArbiter `fizzled_cells`): the sigil breaks into ash, no flame
## The burning ground after the blast is the existing burn (StatusEffects + burning_cell pack + BurnPainter bar); this
## module only adds a faint scorch frame that fades while the flames burn. Colours: the Mage's fire ramp (art bible;
## no enemy red). Floor items are in FLAT cell art px (FloorDynamicLayer, mapped by the board); column items are screen
## art px over the tile's drawn ground centre (OverlayLayer, unmapped like the Ngàn Kiếm blades).

const DRAW_IN_SEC: float = 0.25
const FINAL_SEC: float = 0.35
const COLLAPSE_SEC: float = 0.08
const FLICKER_SEC: float = 0.06
const FLASH_SEC: float = 0.09
const RING_SEC: float = 0.18
const RISE_SEC: float = 0.12
const HOLD_SEC: float = 0.14
const DECAY_SEC: float = 0.46
const FIZZLE_SEC: float = 0.25
const STEPS: int = 3
## Sigil frame and charge rings, as fractions of the slab.
const FRAME_FRAC: float = 0.80
const RING_FRACS: Array[float] = [0.62, 0.44, 0.26]
const CORE_FRAC: float = 0.12
const CORE_FINAL_FRAC: float = 0.30
## Flame column height in cell widths, and its layer height floor.
const COLUMN_CELLS: float = 1.15
const MIN_LAYER_PX: int = 4

const CHARCOAL := Color("3A2A26")
const AMBER := Color("F0A030")
const ORANGE := Color("FF7A1F")
const GOLD := Color("FFB21F")
const CREAM := Color("EFE6D2")
const SMOKE := Color("1B1722")
const ASH := Color("8A8378")


## The records of one scheduled cast [param cast] (SwingArbiter.cast_scheduled payload) put on the clock at
## [param now]: one per armed cell of its `fuse` events {cell, cast_id, start, at, square, fired, fizzled, hit}.
static func records_from_cast(cast: Dictionary, now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in cast.get("events", []) as Array:
		var ev: Dictionary = e as Dictionary
		if str(ev.get("kind", "")) != CastResolver.KIND_FUSE:
			continue
		for c: Variant in ev.get("cells", []) as Array:
			out.append({"cell": c as Vector2i, "cast_id": int(cast.get("cast_id", -1)), "start": now,
				"at": float(ev.get("at", now)), "square": bool(cast.get("clause", false)), "fired": false,
				"fizzled": false, "hit": false})
	return out


## The clock time after which [param rec] shows nothing more.
static func end_time(rec: Dictionary) -> float:
	if bool(rec.get("fizzled", false)):
		return float(rec["at"]) + FIZZLE_SEC
	return float(rec["at"]) + RISE_SEC + HOLD_SEC + DECAY_SEC


## The countdown step of [param rec] at [param now]: 3, 2, 1 (thirds of its fuse left), 0 once it fired.
static func steps_left(rec: Dictionary, now: float) -> int:
	var fuse: float = maxf(float(rec["at"]) - float(rec["start"]), 0.001)
	var left: float = float(rec["at"]) - now
	if left <= 0.0:
		return 0
	return clampi(ceili(left / (fuse / float(STEPS)) - 0.000001), 1, STEPS)


## The phase of [param rec] at [param now]: "sigil", "blast", "fizzle" or "" (nothing to draw).
static func phase(rec: Dictionary, now: float) -> String:
	var at: float = float(rec["at"])
	if now < at:
		return "sigil"
	if now >= end_time(rec):
		return ""
	return "fizzle" if bool(rec.get("fizzled", false)) else "blast"


# Centred rect of [param frac] of [param slab] (whole px, even margins).
static func _inset(slab: Rect2i, fx: float, fy: float) -> Rect2i:
	var w: int = maxi(roundi(float(slab.size.x) * fx), 2)
	var h: int = maxi(roundi(float(slab.size.y) * fy), 2)
	@warning_ignore("integer_division")
	return Rect2i(slab.position + (slab.size - Vector2i(w, h)) / 2, Vector2i(w, h))


# The four sides of [param r] as rects [param t] px wide.
static func _ring(out: Array[Dictionary], r: Rect2i, t: int, col: Color) -> void:
	t = clampi(t, 1, maxi(mini(r.size.x, r.size.y) / 2, 1))
	out.append({"rect": Rect2i(r.position, Vector2i(r.size.x, t)), "col": col})
	out.append({"rect": Rect2i(Vector2i(r.position.x, r.end.y - t), Vector2i(r.size.x, t)), "col": col})
	out.append({"rect": Rect2i(Vector2i(r.position.x, r.position.y + t), Vector2i(t, r.size.y - 2 * t)), "col": col})
	out.append({"rect": Rect2i(Vector2i(r.end.x - t, r.position.y + t), Vector2i(t, r.size.y - 2 * t)), "col": col})


# The four corner brackets of [param r]: arms [param k] (0..1) of half a side long, [param t] px wide.
static func _brackets(out: Array[Dictionary], r: Rect2i, k: float, t: int, col: Color) -> void:
	@warning_ignore("integer_division")
	var ax: int = maxi(roundi(float(r.size.x / 2) * k), t)
	@warning_ignore("integer_division")
	var ay: int = maxi(roundi(float(r.size.y / 2) * k), t)
	for corner: Vector2i in [r.position, Vector2i(r.end.x - ax, r.position.y), Vector2i(r.position.x, r.end.y - t),
			Vector2i(r.end.x - ax, r.end.y - t)]:
		out.append({"rect": Rect2i(corner, Vector2i(ax, t)), "col": col})
	for corner: Vector2i in [r.position, Vector2i(r.end.x - t, r.position.y), Vector2i(r.position.x, r.end.y - ay),
			Vector2i(r.end.x - t, r.end.y - ay)]:
		out.append({"rect": Rect2i(corner, Vector2i(t, ay)), "col": col})


## The armed sigil of [param rec] at [param now] on the slab [param slab] (flat cell art px): [{rect, col}] in draw
## order (a dark Ink outline first, then fill, frame, rings, core); [] when it is not armed now.
static func sigil_items(rec: Dictionary, now: float, slab: Rect2i, reduce: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if phase(rec, now) != "sigil":
		return out
	var age: float = now - float(rec["start"])
	var left: float = float(rec["at"]) - now
	var n: int = steps_left(rec, now)
	var final: bool = left <= FINAL_SEC
	var frame: Rect2i = _inset(slab, FRAME_FRAC, FRAME_FRAC)
	var collapse: float = clampf(left / COLLAPSE_SEC, 0.0, 1.0) if left < COLLAPSE_SEC else 1.0
	if collapse < 1.0:
		frame = _inset(slab, lerpf(CORE_FINAL_FRAC, FRAME_FRAC, collapse), lerpf(CORE_FINAL_FRAC, FRAME_FRAC, collapse))
	# fill: the armed slab reads as "marked" (brighter each step)
	var fill_a: float = 0.16 + 0.07 * float(STEPS - n) + (0.12 if final else 0.0)
	out.append({"rect": frame, "col": Color(AMBER, fill_a)})
	var t: int = 3 if final else 2
	var frame_col: Color = AMBER
	if final:
		frame_col = CREAM if reduce or int(floorf(left / FLICKER_SEC)) % 2 == 0 else ORANGE
	if age < DRAW_IN_SEC:
		_brackets(out, frame.grow(1), clampf(age / DRAW_IN_SEC, 0.1, 1.0), t + 2, CHARCOAL)
		_brackets(out, frame, clampf(age / DRAW_IN_SEC, 0.1, 1.0), t, frame_col)
		return out
	_ring(out, frame.grow(1), t + 2, CHARCOAL)
	_ring(out, frame, t, frame_col)
	# corner pips: the square reads as a ground seal, not a button
	_brackets(out, frame, 0.32, t + 1, CREAM if final else GOLD)
	if collapse >= 1.0:
		var tone: Color = [CREAM, GOLD, AMBER][clampi(n - 1, 0, 2)]
		for k: int in range(STEPS - n, STEPS):
			_ring(out, _inset(slab, RING_FRACS[k], RING_FRACS[k]), 2, ORANGE if k < STEPS - 1 else tone)
	var core_frac: float = CORE_FINAL_FRAC if final else CORE_FRAC + 0.04 * float(STEPS - n)
	if collapse < 1.0:
		core_frac = lerpf(CORE_FINAL_FRAC + 0.1, CORE_FINAL_FRAC, collapse)
	var core: Rect2i = _inset(slab, core_frac, core_frac)
	out.append({"rect": core.grow(1), "col": CHARCOAL})
	out.append({"rect": core, "col": CREAM if (final or n == 1) else GOLD})
	return out


## The blast on the floor of [param rec] at [param now] (flat cell art px): the cream ground flash, the square shock
## ring and the scorch frame under the burn; or the fizzle's ash. [] outside those times.
static func blast_floor_items(rec: Dictionary, now: float, slab: Rect2i, reduce: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p: String = phase(rec, now)
	var t: float = now - float(rec["at"])
	if p == "fizzle":
		# the sigil breaks into 4 ash squares drifting out of the corners; no flame
		var k: float = clampf(t / FIZZLE_SEC, 0.0, 1.0)
		var frame: Rect2i = _inset(slab, FRAME_FRAC, FRAME_FRAC)
		var s: int = maxi(roundi(float(slab.size.y) * 0.14), 3)
		var drift: int = 0 if reduce else roundi(k * float(s))
		for c: Vector2i in [frame.position, Vector2i(frame.end.x - s, frame.position.y), Vector2i(frame.position.x, frame.end.y - s),
				Vector2i(frame.end.x - s, frame.end.y - s)]:
			var dir := Vector2i(signi(c.x - frame.get_center().x), signi(c.y - frame.get_center().y))
			out.append({"rect": Rect2i(c + dir * drift, Vector2i(s, s)), "col": Color(ASH, 1.0 - k)})
		return out
	if p != "blast":
		return out
	if t < FLASH_SEC:
		out.append({"rect": slab, "col": Color(CREAM, 0.9 * (1.0 - t / FLASH_SEC))})
	if t < RING_SEC:
		var k2: float = t / RING_SEC
		var frac: float = lerpf(0.3, 1.0, k2)
		_ring(out, _inset(slab, frac, frac), 3 if k2 < 0.5 else 2, Color(GOLD if k2 < 0.5 else ORANGE, 1.0 - 0.6 * k2))
	var total: float = RISE_SEC + HOLD_SEC + DECAY_SEC
	var a: float = clampf(1.0 - t / total, 0.0, 1.0) * 0.8
	_ring(out, _inset(slab, FRAME_FRAC, FRAME_FRAC), 2, Color(CHARCOAL, a))
	return out


## The flame column of [param rec] at [param now], standing on [param base] (the tile's drawn ground centre, screen
## art px) and sized from the drawn cell width [param cell_w]: [{rect, col, edge}] (edge = Ink px under it), bottom
## layers first; [] outside the blast.
static func eruption_items(rec: Dictionary, now: float, base: Vector2i, cell_w: int, reduce: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if phase(rec, now) != "blast":
		return out
	var t: float = now - float(rec["at"])
	var h_max: float = float(cell_w) * COLUMN_CELLS * (1.15 if bool(rec.get("square", false)) else 1.0)
	var lh: int = maxi(roundi(float(cell_w) / 10.0), MIN_LAYER_PX)
	var w0: float = float(cell_w) * 0.64
	var top: float
	var bottom: float = 0.0
	var decay: float = 0.0
	if t < RISE_SEC:
		var k: float = t / RISE_SEC
		top = h_max * (1.0 - (1.0 - k) * (1.0 - k))
	elif t < RISE_SEC + HOLD_SEC:
		top = h_max
	else:
		# the column sinks back into its tile (never lifts off the ground) while it darkens to smoke
		decay = clampf((t - RISE_SEC - HOLD_SEC) / DECAY_SEC, 0.0, 1.0)
		top = h_max * (1.0 - decay) * (1.0 - 0.25 * decay)
	var tick: int = int(floorf(t / 0.05))
	# impact frame: a wide flat burst on the ground
	if t < 0.15:
		var bw: int = roundi(float(cell_w) * lerpf(0.7, 1.05, t / 0.15))
		@warning_ignore("integer_division")
		out.append({"rect": Rect2i(base.x - bw / 2, base.y - lh, bw, lh), "col": CREAM if t < 0.07 else GOLD, "edge": 1})
	var layers: int = maxi(ceili(top / float(lh)), 1)
	for i: int in layers:
		var y0: float = float(i * lh)
		if y0 + float(lh) <= bottom or y0 >= top:
			continue
		var hk: float = y0 / h_max
		# ragged flame edge: every layer's width bites in / out by a few px (deterministic per layer and tick)
		var rag: int = 0 if reduce else (((i * 5 + tick * 2) % 3) - 1) * maxi(lh / 2, 2)
		# the taper follows the CURRENT top, so a sinking column stays a flame (never a flat-topped block)
		var taper: float = y0 / maxf(top, 1.0)
		var shape_k: float = hk if decay <= 0.0 else taper
		var w: int = maxi(roundi(w0 * (1.0 - (0.6 + 0.2 * decay) * shape_k) * (1.0 - 0.3 * decay)) + rag, 4)
		w -= w % 2
		var jit: int = 0 if reduce else ((i * 7 + tick * 3) % 3) - 1
		var r := Rect2i(base.x - w / 2 + jit, base.y - int(y0) - lh, w, lh)
		var outer: Color = ORANGE.lerp(CHARCOAL, decay * 0.7)
		out.append({"rect": r, "col": outer, "edge": 1})
		if decay < 0.6:
			var wi: int = maxi(roundi(float(w) * (0.55 + 0.1 * float((i + tick) % 2))), 2)
			wi -= wi % 2
			@warning_ignore("integer_division")
			out.append({"rect": Rect2i(r.position.x + (w - wi) / 2, r.position.y, wi, lh), "col": GOLD.lerp(ORANGE, decay), "edge": 0})
		if hk < 0.35 and decay < 0.2:
			var wc: int = maxi(roundi(float(w) * 0.28), 2)
			wc -= wc % 2
			@warning_ignore("integer_division")
			out.append({"rect": Rect2i(r.position.x + (w - wc) / 2, r.position.y, wc, lh), "col": CREAM, "edge": 0})
	# tongues above the top
	if decay < 0.6 and not reduce:
		for j: int in 2:
			var s: int = lh
			var x: int = base.x + ((j * 2 - 1) * roundi(w0 * 0.18)) + (((tick + j) % 2) * 2 - 1) * 2
			out.append({"rect": Rect2i(x - s / 2, base.y - int(top) - s * (2 + ((tick + j) % 2)), s, s), "col": GOLD, "edge": 1})
	# smoke and embers in the decay
	if decay > 0.0:
		var n: int = 2 if reduce else 4
		for j: int in n:
			var sx: int = roundi(w0 * (0.35 * float(j % 2 * 2 - 1)) * (0.5 + 0.25 * float(j / 2)))
			var rise: int = roundi(decay * h_max * 0.4) + j * lh
			var ss: int = lh + lh / 2
			out.append({"rect": Rect2i(base.x + sx - ss / 2, base.y - int(top) - rise, ss, ss),
				"col": Color(SMOKE, 0.85 * (1.0 - decay)), "edge": 0})
			out.append({"rect": Rect2i(base.x - sx, base.y - int(h_max * 0.5) - rise, 2, 2),
				"col": Color(GOLD, 1.0 - decay), "edge": 0})
	return out


## The command glyph at the Mage's hand [param hand] (screen art px) while the 0.45 s cast runs, [param k] = progress
## 0..1: a 3x3 grid of squares lighting one by one, then the whole glyph flaring as the seals are committed.
static func glyph_items(hand: Vector2i, k: float, reduce: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lit: int = clampi(ceili(k * 9.0), 1, 9)
	var cell: int = 3
	var gap: int = 1
	var size: int = cell * 3 + gap * 2
	var origin := Vector2i(hand.x - size / 2, hand.y - size / 2)
	var flare: bool = k >= 0.85
	out.append({"rect": Rect2i(origin - Vector2i(1, 1), Vector2i(size + 2, size + 2)), "col": Color(CHARCOAL, 0.9), "edge": 0})
	var order: Array[int] = [4, 1, 5, 7, 3, 0, 2, 8, 6]
	for n: int in lit:
		var idx: int = order[n]
		@warning_ignore("integer_division")
		var p := origin + Vector2i((idx % 3) * (cell + gap), (idx / 3) * (cell + gap))
		var col: Color = CREAM if idx == 4 else (GOLD if flare else AMBER)
		out.append({"rect": Rect2i(p, Vector2i(cell, cell)), "col": col, "edge": 0})
	if flare and not reduce:
		_ring(out, Rect2i(origin - Vector2i(3, 3), Vector2i(size + 6, size + 6)), 1, ORANGE)
	return out

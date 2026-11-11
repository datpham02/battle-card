class_name CastGlyphFx
extends RefCounted
## Skill v2 V2 (docs/skill-v2/16-animation-audit-and-plan.md §4 step 2): the hero's cast glyph, pure and deterministic.
## While a card's `cast_gesture` swing runs, a sigil in the hero's block colours draws itself at the casting hand
## (screen art px), holds with a pulse, then flares as the cast is released, so every one of the 60 casts has a
## visible "spell being spoken" even when the card's delivery is generic. One kit per hero, picked by the cast index
## `cast_glyphs` (CastVfx.cast_glyph), which also gives the hand point of that hero's hold frame:
##   sigil    Knight   a steel square frame whose four corner studs lock in one by one, then the core
##   runes    Mage     three stacked flame runes lighting bottom-up with embers (Hỏa Lôi keeps FuseFx's own glyph)
##   daggers  Assassin two jade dagger strokes crossing in an X, drawn stroke by stroke, tips flashing
##   leaf     Hunter   a stepped jade leaf growing from its stem, three seeds popping
##   halo     Cleric   an ivory square halo growing from a bright core, then a second ring
## Items are {"rect": Rect2i, "col": Color, "edge": int} like FuseFx.glyph_items (OverlayLayer draws them unmapped,
## Ink edge `edge` px). Art bible: squares only, no round shapes, no box behind it, the hero's colours; reduce
## motion = no flare ring. [param k] is the swing progress 0..1 from the CutActor clock; nothing here decides a time.

const FORMS: Array[String] = ["sigil", "runes", "daggers", "leaf", "halo"]
## The glyph's square footprint (art px).
const SIZE: int = 23
const DRAW_END: float = 0.6
const FLARE_FROM: float = 0.85


## The glyph of [param form] at [param hand] with [param cols] = [body, highlight] (the hero's block colours),
## progress [param k]; [] for an unknown form.
static func items(form: String, hand: Vector2i, k: float, cols: Array[Color], reduce: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FORMS.has(form) or cols.size() < 2:
		return out
	var kk: float = clampf(k, 0.0, 1.0)
	var body: Color = cols[0]
	var light: Color = cols[1]
	var pulse: bool = kk >= DRAW_END and kk < FLARE_FROM and int(floorf(kk * 20.0)) % 2 == 0
	var flare: bool = kk >= FLARE_FROM
	match form:
		"sigil": _sigil(out, hand, kk, body, light, pulse, flare, reduce)
		"runes": _runes(out, hand, kk, body, light, pulse, flare, reduce)
		"daggers": _daggers(out, hand, kk, body, light, pulse, flare, reduce)
		"leaf": _leaf(out, hand, kk, body, light, pulse, flare, reduce)
		"halo": _halo(out, hand, kk, body, light, pulse, flare, reduce)
	return out


static func _it(r: Rect2i, col: Color, edge: int = 1) -> Dictionary:
	return {"rect": r, "col": col, "edge": edge}


static func _sq(c: Vector2i, s: int, col: Color, edge: int = 1) -> Dictionary:
	return _it(Rect2i(c - Vector2i(_half(s), _half(s)), Vector2i(s, s)), col, edge)


static func _ring(out: Array[Dictionary], f: Rect2i, t: int, col: Color, edge: int = 1) -> void:
	out.append(_it(Rect2i(f.position, Vector2i(f.size.x, t)), col, edge))
	out.append(_it(Rect2i(f.position.x, f.end.y - t, f.size.x, t), col, edge))
	out.append(_it(Rect2i(f.position.x, f.position.y + t, t, f.size.y - t * 2), col, edge))
	out.append(_it(Rect2i(f.end.x - t, f.position.y + t, t, f.size.y - t * 2), col, edge))


static func _box(hand: Vector2i, size: int) -> Rect2i:
	return Rect2i(hand - Vector2i(_half(size), _half(size)), Vector2i(size, size))


## The flare at the release: an outer 1 px ring opening out and fading, skipped under reduce motion.
static func _flare(out: Array[Dictionary], hand: Vector2i, k: float, col: Color, reduce: bool) -> void:
	if reduce:
		return
	var f: float = (k - FLARE_FROM) / (1.0 - FLARE_FROM)
	var grow: int = roundi(f * 6.0)
	_ring(out, _box(hand, SIZE + 4 + grow * 2), 1, Color(col, 1.0 - f * 0.6), 0)


# --- Knight: steel sigil -----------------------------------------------------------------------------

static func _sigil(out: Array[Dictionary], hand: Vector2i, k: float, body: Color, light: Color, pulse: bool, flare: bool, reduce: bool) -> void:
	var f: Rect2i = _box(hand, SIZE)
	# the frame draws in left to right over the first third, 3 px
	var frame_k: float = clampf(k / 0.3, 0.0, 1.0)
	var fw: int = maxi(roundi(float(SIZE) * frame_k), 5)
	_ring(out, Rect2i(f.position, Vector2i(fw, SIZE)) if frame_k < 1.0 else f, 3, body)
	# four corner studs lock in one by one (0.3 .. 0.6)
	var studs: int = clampi(ceili((k - 0.3) / 0.3 * 4.0), 0, 4)
	var corners: Array[Vector2i] = [f.position, Vector2i(f.end.x - 6, f.position.y), Vector2i(f.end.x - 6, f.end.y - 6), Vector2i(f.position.x, f.end.y - 6)]
	for i: int in studs:
		out.append(_it(Rect2i(corners[i], Vector2i(6, 6)), light))
	# the core
	if k >= DRAW_END:
		out.append(_sq(hand, 11 if (pulse or flare) else 9, light if (pulse or flare) else body))
		out.append(_sq(hand, 5 if (pulse or flare) else 3, light, 0))
	if flare:
		_flare(out, hand, k, light, reduce)


# --- Mage: flame runes -------------------------------------------------------------------------------

static func _runes(out: Array[Dictionary], hand: Vector2i, k: float, body: Color, light: Color, pulse: bool, flare: bool, reduce: bool) -> void:
	# three stepped flame runes stacked, lighting bottom-up over the first 0.6
	var lit: int = clampi(ceili(k / DRAW_END * 3.0), 1, 3)
	for i: int in lit:
		var y: int = hand.y + 8 - i * 7
		var top: bool = i == lit - 1
		var w: int = (11 - i * 2) + (2 if pulse and top else 0)
		out.append(_it(Rect2i(hand.x - _half(w), y - 2, w, 4), light if top else body))
		out.append(_it(Rect2i(hand.x - 2, y - 5, 5, 3), light))
	# embers drifting up beside the runes
	if k > 0.3:
		for i: int in 4:
			var ey: int = hand.y + 6 - roundi(fmod(k * 24.0 + float(i) * 4.0, 14.0))
			out.append(_it(Rect2i(hand.x + (i - 2) * 6 + 3, ey, 2, 2), light, 0))
	if flare:
		out.append(_sq(hand, 15, light))
		out.append(_sq(hand, 7, body, 0))
		_flare(out, hand, k, body, reduce)


# --- Assassin: crossed daggers -----------------------------------------------------------------------

static func _daggers(out: Array[Dictionary], hand: Vector2i, k: float, body: Color, light: Color, pulse: bool, flare: bool, reduce: bool) -> void:
	var r: int = _half(SIZE) - 1
	# the crossing point first, then stroke 1 (top-left to bottom-right) over 0..0.3 and stroke 2 over 0.3..0.6,
	# 3 px stepped squares every 2 px
	out.append(_sq(hand, 3, body))
	var strokes: Array = [[Vector2i(-r, -r), Vector2i(r, r), 0.0], [Vector2i(r, -r), Vector2i(-r, r), 0.3]]
	for st: Array in strokes:
		var sk: float = clampf((k - float(st[2])) / 0.3, 0.0, 1.0)
		if sk <= 0.0:
			continue
		var n: int = r
		var shown: int = clampi(ceili(sk * float(n + 1)), 1, n + 1)
		for i: int in shown:
			var p: Vector2i = hand + Vector2i((Vector2(st[0]) + Vector2(st[1] - st[0]) * (float(i) / float(n))).round())
			out.append(_sq(p, 3, light if i == shown - 1 and sk < 1.0 else body))
	# the tips flash while held, the centre flares at the release
	if k >= DRAW_END:
		for v: Vector2i in [Vector2i(-r, -r), Vector2i(r, -r), Vector2i(r, r), Vector2i(-r, r)]:
			out.append(_sq(hand + v, 5, light if (pulse or flare) else body))
	if flare:
		out.append(_sq(hand, 7, light))
		_flare(out, hand, k, light, reduce)


# --- Hunter: jade leaf -------------------------------------------------------------------------------

static func _leaf(out: Array[Dictionary], hand: Vector2i, k: float, body: Color, light: Color, pulse: bool, flare: bool, reduce: bool) -> void:
	# the stem, then a stepped leaf (a chevron of 3 px squares) growing up from it over 0..0.6
	var grow: float = clampf(k / DRAW_END, 0.0, 1.0)
	out.append(_it(Rect2i(hand.x - 1, hand.y + 2, 3, 9), body))
	var rows: int = clampi(ceili(grow * 6.0), 1, 6)
	for rr: int in rows:
		var y: int = hand.y + 2 - rr * 3
		var half: int = (rr if rr <= 3 else 7 - rr) * 3
		var tip: bool = rr == rows - 1
		out.append(_it(Rect2i(hand.x - half - 2, y, 3, 3), light if tip else body))
		out.append(_it(Rect2i(hand.x + half - 1, y, 3, 3), light if tip else body))
		if rr == 3 or rr == 6:
			out.append(_it(Rect2i(hand.x - 1, y, 3, 3), light))
	# three seeds pop beside the leaf while held
	if k >= DRAW_END:
		for i: int in 3:
			var p: Vector2i = hand + Vector2i((i - 1) * 9, -14 - (i % 2) * 3)
			out.append(_sq(p, 4 if (pulse or flare) else 3, light))
	if flare:
		_flare(out, hand, k, light, reduce)


# --- Cleric: ivory halo ------------------------------------------------------------------------------

static func _halo(out: Array[Dictionary], hand: Vector2i, k: float, body: Color, light: Color, pulse: bool, flare: bool, reduce: bool) -> void:
	# the core, then a square halo growing from 7 to SIZE px over 0..0.6
	var grow: float = clampf(k / DRAW_END, 0.0, 1.0)
	var hs: int = 7 + roundi(grow * float(SIZE - 7))
	hs += (SIZE - hs) % 2
	_ring(out, _box(hand, hs), 3, light if (pulse or flare) else body)
	out.append(_sq(hand, 7 if (pulse or flare) else 5, light))
	if k >= DRAW_END:
		var r: int = _half(SIZE) + 1
		for v: Vector2i in [Vector2i(0, -r), Vector2i(r, 0), Vector2i(0, r), Vector2i(-r, 0)]:
			out.append(_sq(hand + v, 3, light))
	if flare:
		_ring(out, _box(hand, 13), 2, light)
		_flare(out, hand, k, light, reduce)


static func _half(v: int) -> int:
	@warning_ignore("integer_division")
	return v / 2

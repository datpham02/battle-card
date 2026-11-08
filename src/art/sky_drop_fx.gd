class_name SkyDropFx
extends RefCounted
## Skill v2 reusable SKY_TO_TARGET presentation (Ngàn Kiếm first; Thiên Thạch / Thiên Quang / Tuyết rơi later): pure,
## deterministic, code-drawn square art. It never decides gameplay: every timing comes from the AUTHORITATIVE impact
## schedule (SwingArbiter.cast_scheduled events: `at` on the arbiter clock), and damage feedback stays with
## SwingArbiter.impact_resolved.
##
## One drop record d = {cell, at (impact time, arbiter clock), t0 (clock when the cast was scheduled = the swing end),
## final (bool: the branched centre strike), seed (int), cast_id, dx, over_enemy}. Phases on the arbiter clock:
##   materialize  t0 .. t0 + MATERIALIZE_SEC      fragments gather, then the sword assembles (blade, guard, hilt)
##   hover        .. at - fall_sec(d)             tip down above its tile, trembling 1 px; its tile shadow darkens
##   fall         at - fall_sec(d) .. at          accelerates down (ease-in) with a stepped trail, sliding back over
##                                                the tile centre; the tip reaches the centre EXACTLY at `at`
##   embedded     at .. at + EMBED_SEC            tip sunk SINK_PX into the tile; cracks appear in its last part
##   shatter      .. + SHATTER_SEC                breaks into square fragments that fall and vanish; then nothing
## The shadow (floor, tile-exact) runs t0 .. at. A `final` drop is drawn FINAL_SCALE bigger and brighter, assembles with
## more fragments and a white forge flash, wears a 2 px Ink edge, falls faster, hits with more shards and shakes the
## board SHAKE_PX (board_shake; never under reduce motion).
##
## Visual-only layout (never the target cell, never the timing; records_from_cast fixes it once per cast):
## - `dx` (layout_dx): of two drops stacked in one column, the back one hovers STAGGER_PX to one side (the finale stays
##   centred; the one in front of it moves instead), so stacked swords do not overlap; it slides home during its fall.
## - `over_enemy`: a drop on a cell the enemy covered at the swing end hovers OVER_ENEMY_HOVER_TIP_PX up (above a
##   Goblin-sized head) and see-through (OVER_ENEMY_ALPHA) until it falls, so the enemy's warning pose stays readable.
## - every hover is capped so the pommel stays at or below SAFE_TOP_PX (the HUD title band).
## Items are {rect: Rect2i (art px), tone: int, edge (optional, px of Ink under it)} with tones TONE_INK / DARK / BODY /
## LIGHT / CORE; screen-space items (blades, impacts) are drawn unmapped, floor items (shadow) through the board map.

const MATERIALIZE_SEC: float = 0.2
const FALL_SEC: float = 0.1
## The finale falls faster, with a cubic ease-in: the same contact time, a harder arrival.
const FINAL_FALL_SEC: float = 0.07
const EMBED_SEC: float = 0.35
const SHATTER_SEC: float = 0.25
const IMPACT_SEC: float = 0.18
## Geometry in art px at scale 1, sized by docs/art/vfx-scale-impact-guide.md (a drawn tile is ~60 x 43 px at 640x360,
## the Knight 64 px tall): a SIGNATURE sword is ~1.35 tile heights tall (blade 40, guard 3, grip 9, pommel 4), its
## ground impact ~1 tile wide; the branched finale is FINAL_SCALE (+30 %) bigger.
const BLADE_LEN: int = 40
const BLADE_HALF_W: int = 3
const GUARD_W: int = 19
const GUARD_H: int = 3
const GRIP_H: int = 9
const POMMEL_W: int = 5
const POMMEL_H: int = 4
const HOVER_TIP_PX: int = 24
const SINK_PX: int = 8
const FINAL_SCALE: float = 1.3
## Visual-only layout (see the header): hover x offset of a stacked drop, the hover of a drop over the enemy and its
## alpha while it hovers, the HUD band no sword may reach (art px at 640x360) and the lowest hover the cap may leave.
const STAGGER_PX: int = 18
## The drop just behind a big or lifted sword (the finale, or a drop lifted over the enemy) moves this far aside.
const FINAL_STAGGER_PX: int = 26
const OVER_ENEMY_HOVER_TIP_PX: int = 50
const OVER_ENEMY_ALPHA: float = 0.7
const SAFE_TOP_PX: int = 18
const MIN_HOVER_TIP_PX: int = 6
## The finale's visual-only board shake at contact: SHAKE_PX for SHAKE_SEC, flipping side every SHAKE_STEP_SEC.
const SHAKE_PX: int = 2
const SHAKE_SEC: float = 0.12
const SHAKE_STEP_SEC: float = 0.03
## Ground impact half-width (px, scale 1) and shard size.
const IMPACT_HALF_W: int = 26
const SHARD_PX: int = 4
const TONE_INK: int = 0
const TONE_DARK: int = 1
const TONE_BODY: int = 2
const TONE_LIGHT: int = 3
const TONE_CORE: int = 4
const SHADOW_ALPHA_MIN: float = 0.18
const SHADOW_ALPHA_MAX: float = 0.62


## The drop records of a scheduled cast ([param cast] = SwingArbiter.cast_scheduled's dictionary, events in schedule
## order) placed at [param t0] (the arbiter clock at the swing end): one record per event, its cell, its authoritative
## `at`, final = kind drop_final. The visual order IS the gameplay order (nothing is recomputed here). Visual-only
## layout: `dx` (layout_dx) and `over_enemy` ([param enemy_cells] = the cells the enemy covered at the swing end).
static func records_from_cast(cast: Dictionary, t0: float, enemy_cells: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cells: Array[Vector2i] = []
	var final_cell := Vector2i(-99, -99)
	for e: Variant in cast.get("events", []) as Array:
		cells.append(((e as Dictionary)["cells"] as Array)[0])
		if str((e as Dictionary).get("kind", "")) == CastResolver.KIND_DROP_FINAL:
			final_cell = cells[-1]
	for e: Variant in cast.get("events", []) as Array:
		var ev: Dictionary = e
		var cell: Vector2i = (ev["cells"] as Array)[0]
		var final: bool = str(ev.get("kind", "")) == CastResolver.KIND_DROP_FINAL
		out.append({"cell": cell, "at": float(ev["at"]), "t0": t0, "final": final, "seed": absi(hash(cell)) % 997,
			"cast_id": int(cast.get("cast_id", -1)), "dx": layout_dx(cell, final, cells, final_cell, enemy_cells), "over_enemy": enemy_cells.has(cell),
			"skill": str(cast.get("skill_id", ""))})
	return out


## Visual-only hover x offset of the drop on [param cell] among [param cells] (the cast's drop cells). A hovering
## sword's tip reaches into the pommel of the sword on the row in front (below on screen), so the BACK one of such a
## pair moves aside: STAGGER_PX, or FINAL_STAGGER_PX when the one in front is bigger or lifted ([param wide_cells]:
## the finale's cell and the drops lifted over the enemy). The finale ([param final_cell]) stays centred; the sword in
## front of it moves aside instead. Right on even rows, left on odd rows, so a column of three alternates. 0 for a drop
## with no such pair.
static func layout_dx(cell: Vector2i, final: bool, cells: Array, final_cell: Vector2i = Vector2i(-99, -99),
		wide_cells: Array = []) -> int:
	if final:
		return 0
	var below: Vector2i = cell + Vector2i(0, 1)
	var px: int = 0
	if cells.has(below):
		px = FINAL_STAGGER_PX if below == final_cell or wide_cells.has(below) else STAGGER_PX
	elif cell - Vector2i(0, 1) == final_cell:
		px = STAGGER_PX
	return px if posmod(cell.y, 2) == 0 else -px


## Seconds of the fall of [param d] (FINAL_FALL_SEC for the finale).
static func fall_sec(d: Dictionary) -> float:
	return FINAL_FALL_SEC if bool(d.get("final", false)) else FALL_SEC


## Pixel height of a sword at [param scale], tip to pommel top.
static func sword_height(scale: float) -> int:
	var dims: Dictionary = _dims(scale)
	return int(dims["L"]) + int(dims["gh"]) + int(dims["grip"]) + int(dims["ph"])


## The hover of [param d]'s tip above [param ground_y] (art px): HOVER_TIP_PX (x FINAL_SCALE for the finale), or
## OVER_ENEMY_HOVER_TIP_PX over the enemy, capped so the pommel stays at or below SAFE_TOP_PX (never under
## MIN_HOVER_TIP_PX).
static func hover_px(d: Dictionary, ground_y: int) -> int:
	var s: float = FINAL_SCALE if bool(d.get("final", false)) else 1.0
	var want: int = OVER_ENEMY_HOVER_TIP_PX if bool(d.get("over_enemy", false)) else int(roundf(float(HOVER_TIP_PX) * s))
	var cap: int = ground_y - SAFE_TOP_PX - sword_height(s) - (COCK_PX if d.has("command_at") else 0)
	return maxi(mini(want, cap), MIN_HOVER_TIP_PX)


## The visual x offset of [param d] at [param now]: its `dx` while it assembles and hovers, sliding linearly back to
## 0 over the fall, 0 from the contact on (the tip lands on the tile centre).
static func x_offset(d: Dictionary, now: float) -> int:
	var dx: int = int(d.get("dx", 0))
	var at: float = float(d["at"])
	if dx == 0 or now >= at:
		return 0
	var fs: float = fall_sec(d)
	if now < at - fs:
		return dx
	return int(roundf(float(dx) * (at - now) / fs))


## The alpha of [param d]'s blade at [param now]: OVER_ENEMY_ALPHA while it assembles / hovers over the enemy
## (`over_enemy`, or [param occupied_now] when the enemy stepped under it since), else 1 (solid from the fall on).
static func blade_alpha(d: Dictionary, now: float, occupied_now: bool = false) -> float:
	var ph: String = phase(d, now)
	if (ph == "materialize" or ph == "hover") and (bool(d.get("over_enemy", false)) or occupied_now):
		return OVER_ENEMY_ALPHA
	return 1.0


## The visual-only board offset at [param now] from [param drops]: SHAKE_PX side to side during SHAKE_SEC after a
## finale's contact; zero otherwise, and always zero under [param reduce] (reduce motion).
static func board_shake(drops: Array, now: float, reduce: bool = false) -> Vector2i:
	if reduce:
		return Vector2i.ZERO
	for v: Variant in drops:
		var d: Dictionary = v
		var since: float = now - float(d["at"])
		if bool(d.get("final", false)) and since >= 0.0 and since < SHAKE_SEC:
			return Vector2i(SHAKE_PX if int(since / SHAKE_STEP_SEC) % 2 == 0 else -SHAKE_PX, 0)
	return Vector2i.ZERO


## Seconds after `at` until the drop has nothing left to draw.
static func end_after_impact() -> float:
	return EMBED_SEC + SHATTER_SEC


## True while drop [param d] has something to draw at clock [param now].
static func alive(d: Dictionary, now: float) -> bool:
	return now >= float(d["t0"]) and now < float(d["at"]) + end_after_impact()


## The drops to draw at [param now] out of [param records] (schedule order kept): alive ones, minus the not-yet-landed
## drops of a cast the arbiter dropped ([param cast_alive]: Callable(cast_id) -> bool; a caster death / match end
## clears the schedule, so their blades vanish instead of falling on nothing). Landed drops finish their embed / shatter.
static func drops_now(records: Array, now: float, cast_alive: Callable = Callable()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in records:
		var d: Dictionary = r
		if not alive(d, now):
			continue
		if now < float(d["at"]) and cast_alive.is_valid() and not bool(cast_alive.call(int(d.get("cast_id", -1)))):
			continue
		out.append(d)
	return out


## The tile shadow's alpha at [param now] (0 outside t0 .. at): darker as the strike nears.
static func shadow_alpha(d: Dictionary, now: float) -> float:
	var t0: float = float(d["t0"])
	var at: float = float(d["at"])
	if now < t0 or now >= at or at <= t0:
		return 0.0
	var k: float = (now - t0) / (at - t0)
	return lerpf(SHADOW_ALPHA_MIN, SHADOW_ALPHA_MAX, k * k)


## The tile-exact shadow square of a cell ([param cell_rect], flat floor art px): inset 1/6 of the cell.
static func shadow_rect(cell_rect: Rect2i) -> Rect2i:
	var inset := Vector2i(cell_rect.size.x / 6, cell_rect.size.y / 6)
	return Rect2i(cell_rect.position + inset, cell_rect.size - inset * 2)


## The phase name of [param d] at [param now]: "", materialize, hover, fall, embedded, shatter.
static func phase(d: Dictionary, now: float) -> String:
	var t0: float = float(d["t0"])
	var at: float = float(d["at"])
	if now < t0 or now >= at + end_after_impact():
		return ""
	if now < t0 + materialize_sec(d) and now < at - fall_sec(d):
		return "materialize"
	if now < at - fall_sec(d):
		return "hover"
	if now < at:
		return "fall"
	if now < at + EMBED_SEC:
		return "embedded"
	return "shatter"


## The y of the blade TIP above [param ground_y] (screen art px, y down) at [param now]: hover_px up while it hovers,
## falling with ease-in (cubic for the finale) to exactly ground_y at `at`, then SINK_PX below it (embedded).
static func tip_y(d: Dictionary, now: float, ground_y: int) -> int:
	var at: float = float(d["at"])
	var fs: float = fall_sec(d)
	var hover: int = hover_px(d, ground_y) + cock_px(d, minf(now, at - fs))
	if now >= at:
		return ground_y + SINK_PX
	if now >= at - fs:
		var k: float = (now - (at - fs)) / fs
		var ease: float = k * k * k if bool(d.get("final", false)) else k * k
		return ground_y - int(roundf(float(hover) * (1.0 - ease)))
	return ground_y - hover


## The sword silhouette with its tip at [param tip] (screen art px), pointing DOWN, at [param scale]: a tapered blade
## with a lit fuller and edge, a guard wider than the blade, a short hilt and a pommel (the overlay adds the Ink edge).
## Rects below [param clip_y] are left out (the sunk part of an embedded blade); -1 = no clip.
static func blade_rects(tip: Vector2i, scale: float, clip_y: int = -1, bright: bool = false) -> Array[Dictionary]:
	return _clip(_sword(tip, scale, bright), clip_y)


# The sword parts, tip down at [param tip]: a stepped point, the blade (dark left edge, light right edge, lit fuller),
# a guard with dark tips, a wrapped grip and a pommel with a highlight.
static func _sword(tip: Vector2i, scale: float, bright: bool) -> Array[Dictionary]:
	var dims: Dictionary = _dims(scale)
	var L: int = dims["L"]
	var hw: int = dims["hw"]
	var gw: int = dims["gw"]
	var gh: int = dims["gh"]
	var grip: int = dims["grip"]
	var pw: int = dims["pw"]
	var ph: int = dims["ph"]
	var x: int = tip.x
	var y: int = tip.y
	var out: Array[Dictionary] = []
	# point: widening steps over the first hw + 1 rows
	for i: int in hw + 1:
		out.append({"rect": Rect2i(x - i, y - 2 - i * 2, i * 2 + 1, 2), "tone": TONE_LIGHT if i == 0 else TONE_BODY})
	var top: int = y - L
	var body_h: int = L - (hw + 1) * 2
	out.append({"rect": Rect2i(x - hw, top, hw * 2 + 1, body_h), "tone": TONE_BODY})
	out.append({"rect": Rect2i(x - hw, top, 1, body_h), "tone": TONE_DARK})
	out.append({"rect": Rect2i(x + hw, top, 1, body_h), "tone": TONE_LIGHT})
	out.append({"rect": Rect2i(x, top + 2, 1, body_h - 2), "tone": TONE_CORE if bright else TONE_LIGHT})
	# guard
	var gx: int = x - gw / 2
	out.append({"rect": Rect2i(gx, top - gh, gw, gh), "tone": TONE_LIGHT if bright else TONE_BODY})
	out.append({"rect": Rect2i(gx, top - gh, 2, gh), "tone": TONE_DARK})
	out.append({"rect": Rect2i(gx + gw - 2, top - gh, 2, gh), "tone": TONE_DARK})
	out.append({"rect": Rect2i(gx + 2, top - gh, gw - 4, 1), "tone": TONE_LIGHT})
	# grip with wrap bands, pommel
	var gy: int = top - gh - grip
	out.append({"rect": Rect2i(x - 1, gy, 3, grip), "tone": TONE_DARK})
	var band: int = gy + 1
	while band < top - gh - 1:
		out.append({"rect": Rect2i(x - 1, band, 3, 1), "tone": TONE_BODY})
		band += 3
	out.append({"rect": Rect2i(x - pw / 2, gy - ph, pw, ph), "tone": TONE_BODY})
	out.append({"rect": Rect2i(x - pw / 2 + 1, gy - ph + 1, 2, 1), "tone": TONE_CORE if bright else TONE_LIGHT})
	return out


# The sword's part sizes at [param scale] (whole px; odd widths so it stays centred on the tip).
static func _dims(scale: float) -> Dictionary:
	return {"L": int(roundf(float(BLADE_LEN) * scale)), "hw": maxi(int(roundf(float(BLADE_HALF_W) * scale)), 2),
		"gw": int(roundf(float(GUARD_W) * scale)) | 1, "gh": maxi(int(roundf(float(GUARD_H) * scale)), 2),
		"grip": int(roundf(float(GRIP_H) * scale)), "pw": int(roundf(float(POMMEL_W) * scale)) | 1,
		"ph": maxi(int(roundf(float(POMMEL_H) * scale)), 3)}


# The parts of [param parts] above [param clip_y] (the sunk part of an embedded blade); -1 = all.
static func _clip(parts: Array[Dictionary], clip_y: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in parts:
		var r: Rect2i = p["rect"]
		if clip_y >= 0:
			if r.position.y >= clip_y:
				continue
			if r.end.y > clip_y:
				r = Rect2i(r.position, Vector2i(r.size.x, clip_y - r.position.y))
		out.append({"rect": r, "tone": int(p["tone"])})
	return out


## Everything drop [param d] draws in SCREEN space at [param now] on a tile whose drawn ground centre is [param base]
## (art px): the blade in its phase (materializing fragments, hovering with a 1 px tremble unless [param reduce],
## falling with a stepped trail, embedded with cracks, shattering into squares) and its ground impact (flash, shards,
## a compact shock) during IMPACT_SEC after `at`. [] when nothing shows. Finale items carry edge 2.
static func items(d: Dictionary, now: float, base: Vector2i, reduce: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ph: String = phase(d, now)
	if ph.is_empty():
		return out
	var final: bool = bool(d.get("final", false))
	var s: float = FINAL_SCALE if final else 1.0
	var seed: int = int(d.get("seed", 0))
	var at: float = float(d["at"])
	var t0: float = float(d["t0"])
	var tip := Vector2i(base.x + x_offset(d, now), tip_y(d, now, base.y))
	match ph:
		"materialize":
			var k: float = clampf((now - t0) / materialize_sec(d), 0.0, 1.0)
			if not reduce and k < 0.6:
				out.append_array(_gather(tip, s, k / 0.6, seed, 14 if final else 8, 1.5 if final else 1.0))
			if k >= 0.35:
				var parts: Array[Dictionary] = blade_rects(tip, s, -1, final)
				var shown: int = int(ceilf(float(parts.size()) * clampf((k - 0.35) / 0.65, 0.0, 1.0)))
				parts = parts.slice(0, maxi(shown, 1))
				if final and k >= 0.8:
					# the finale's forge flash: the finished sword glows white for its last assembly frames
					for p: Dictionary in parts:
						p["tone"] = TONE_CORE
				out.append_array(parts)
		"hover":
			var dx: int = 0
			if not reduce and int((now - t0) / 0.06) % 2 == 1:
				dx = 1 if seed % 2 == 0 else -1
			var parts: Array[Dictionary] = blade_rects(tip + Vector2i(dx, 0), s, -1, final or locked_flash(d, now))
			if locked_flash(d, now):
				for p: Dictionary in parts:
					p["tone"] = TONE_CORE if int(p["tone"]) != TONE_DARK else TONE_LIGHT
			out.append_array(parts)
		"fall":
			out.append_array(blade_rects(tip, s, -1, final))
			if not reduce:
				var top: int = tip.y - sword_height(s)
				var n: int = 6 if final else 4
				for i: int in n:
					var sz: int = maxi((7 if final else 5) - i, 1)
					if top - 6 - i * 7 < SAFE_TOP_PX:
						break  # the trail never reaches into the HUD band
					out.append({"rect": Rect2i(tip.x - sz / 2, top - 6 - i * 7, sz, 5), "tone": TONE_LIGHT if i == 0 else TONE_BODY})
		"embedded":
			out.append_array(blade_rects(tip, s, base.y, final))
			var ek: float = (now - at) / EMBED_SEC
			if ek > 0.55:
				var L: int = int(roundf(float(BLADE_LEN) * s))
				for i: int in 4:
					var cy: int = base.y - 6 - i * (L / 5)
					out.append({"rect": Rect2i(tip.x - 2 + (i % 2) * 2, cy, 3, 1), "tone": TONE_INK})
		"shatter":
			var sk: float = clampf((now - at - EMBED_SEC) / SHATTER_SEC, 0.0, 1.0)
			var mid_y: int = base.y - int(roundf(float(BLADE_LEN) * s * 0.5))
			var mid_x: int = tip.x
			if bool(d.get("disperse", false)):
				# a dispersed (never committed) sword breaks up where it hovered
				mid_y = base.y - hover_px(d, base.y) - int(roundf(float(BLADE_LEN) * s * 0.5))
				mid_x = base.x + int(d.get("dx", 0))
			out.append_array(_shards(Vector2i(mid_x, mid_y), sk, seed, 14 if final else 10))
	if now >= at and now < at + IMPACT_SEC and not bool(d.get("disperse", false)):
		out.append_array(_impact(base, (now - at) / IMPACT_SEC, seed, final))
	for it: Dictionary in out:
		# fragments flying up (gather, shatter, impact shards) stay out of the HUD band, like the swords' hover cap
		var r: Rect2i = it["rect"]
		if r.position.y < SAFE_TOP_PX and r.size.y <= 5:
			it["rect"] = Rect2i(r.position.x, SAFE_TOP_PX, r.size.x, r.size.y)
	if final:
		# the finale's silhouette wears a 2 px Ink edge (the overlay draws `edge` px of Ink under each rect)
		for it: Dictionary in out:
			it["edge"] = 2
	return out


# Square fragments converging from around the blade spot onto it (k 0 -> 1): [param n] of them, from [param reach]
# times the normal distance.
static func _gather(tip: Vector2i, s: float, k: float, seed: int, n: int = 8, reach: float = 1.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var centre := Vector2(tip.x, tip.y - float(BLADE_LEN) * s * 0.6)
	for i: int in n:
		var r: int = absi(hash(seed * 31 + i * 7))
		var ang: float = TAU * float(i) / float(n) + float(r % 100) / 100.0
		var dist: float = (22.0 + float(r % 10)) * s * reach * (1.0 - k)
		var p: Vector2 = centre + Vector2(cos(ang), sin(ang)) * dist
		out.append({"rect": Rect2i(Vector2i(p.round()), Vector2i(3, 3)), "tone": TONE_LIGHT if i % 2 == 0 else TONE_BODY})
	return out


# The blade breaking into squares that fly out and fall, shrinking (k 0 -> 1).
static func _shards(centre: Vector2i, k: float, seed: int, n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in n:
		var r: int = absi(hash(seed * 17 + i * 13))
		var vx: float = (float(r % 31) - 15.0) * 1.6
		var vy: float = -10.0 - float((r / 31) % 12)
		var p := Vector2(centre) + Vector2(0.0, float(i - n / 2) * 3.0) + Vector2(vx * k, vy * k + 46.0 * k * k)
		var sz: int = maxi(int(roundf(float(SHARD_PX) * (1.0 - k))), 1)
		out.append({"rect": Rect2i(Vector2i(p.round()), Vector2i(sz, sz)), "tone": TONE_LIGHT if i % 3 == 0 else TONE_BODY})
	return out


# The ground contact (~1 tile wide; the finale +30-50 %): a white flash cross, square shards thrown up and out from the
# tip (the finale: twice as many, in two distances, thrown higher), a flat stepped shock along the ground, and on the
# finale a second, wider shock (k 0 -> 1).
static func _impact(base: Vector2i, k: float, seed: int, final: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var grow: float = 1.4 if final else 1.0
	var half: int = int(roundf(float(IMPACT_HALF_W) * grow))
	if k < 0.35:
		var arm: int = int(roundf(float(half) * (1.0 - k)))
		out.append({"rect": Rect2i(base.x - arm, base.y - 1, arm * 2 + 1, 3), "tone": TONE_CORE})
		out.append({"rect": Rect2i(base.x - 2, base.y - arm / 2 - 2, 5, arm / 2 + 3), "tone": TONE_CORE})
	var n: int = 16 if final else 8
	var lift: float = 6.0 if final else 4.0
	for i: int in n:
		var ang: float = PI + PI * (float(i) + 0.5) / float(n)
		var dist: float = float(half) * (0.25 + 0.75 * k) * (0.7 if final and i % 2 == 1 else 1.0)
		var p := Vector2(base) + Vector2(cos(ang) * dist, sin(ang) * dist * 0.55 - 10.0 * k * (1.0 - k) * lift)
		var sz: int = maxi(int(roundf(float(SHARD_PX) * grow * (1.0 - k))), 1)
		out.append({"rect": Rect2i(Vector2i(p.round()), Vector2i(sz, sz)), "tone": TONE_LIGHT if i % 2 == 0 else TONE_BODY})
	if k > 0.1:
		for ring: int in (2 if final else 1):
			var rk: float = clampf(k - 0.15 * float(ring), 0.0, 1.0)
			var reach: int = int(roundf(float(half) * (0.4 + 0.6 * rk)))
			for sgn: int in [-1, 1]:
				out.append({"rect": Rect2i(base.x + sgn * reach - (3 if sgn < 0 else 0), base.y + 2 + ring * 2, 4, 2), "tone": TONE_BODY})
				out.append({"rect": Rect2i(base.x + sgn * (reach - 7) - (3 if sgn < 0 else 0), base.y + 3 + ring * 2, 3, 1), "tone": TONE_LIGHT})
	return out


## Summoning beat (stage A, during the Knight's cast): steel squares rising and gathering round [param hand] (screen
## art px) over the swing, brightest near the release; [param k] 0 -> 1 = progress of the swing.
static func summon_items(hand: Vector2i, k: float, seed: int, reduce: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if k < 0.0 or k > 1.0:
		return out
	var n: int = 3 if reduce else 7
	for i: int in n:
		var r: int = absi(hash(seed * 11 + i * 29))
		var phase_k: float = fmod(k * 2.0 + float(r % 100) / 100.0, 1.0)
		var x: int = hand.x + (r % 13) - 6
		var y: int = hand.y + 6 - int(roundf(phase_k * 16.0))
		var sz: int = 2 if phase_k < 0.6 else 1
		out.append({"rect": Rect2i(x, y, sz, sz), "tone": TONE_LIGHT if i % 3 == 0 else TONE_BODY})
	if k > 0.8:
		out.append({"rect": Rect2i(hand.x - 1, hand.y - 1, 3, 3), "tone": TONE_CORE})
	return out


## --- On-tile summon (card_casts `summon_fx`, Ngàn Kiếm): visual only, on the existing combat clock. ---
## From the cast clip's raise frame, EVERY target tile assembles its own sword right above it (tile shadow, steel
## fragments gathering, the sword built part by part, in schedule order), and the swords hover there while the Knight
## holds the summon. At the clip's command frame (the pull-down) they lock on: a short white flash and a small
## cock-up. Then each one stabs down at its own authoritative `at`, as before. Nothing flies from the Knight.
const SUMMON_ASSEMBLY_SEC: float = 0.45
const SUMMON_STAGGER_SEC: float = 0.06
const COCK_PX: int = 4
const COCK_SEC: float = 0.08
const LOCK_FLASH_SEC: float = 0.1
## The Knight's pull-down (and the swords' lock-on) comes this long before the first sword starts to fall, so the
## command reads as the cause of the stab.
const COMMAND_LEAD_SEC: float = 0.12


## [param records] re-timed for the on-tile summon (copies; schedule order kept): record i starts assembling at
## [param summon_from] + i x SUMMON_STAGGER_SEC, its assembly lasts SUMMON_ASSEMBLY_SEC, and it locks on at
## [param command_at]. The cast preview and the real schedule call this with the same values, so the swords formed
## during the swing are the very ones that fall.
static func summon_records(records: Array[Dictionary], summon_from: float, command_at: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in records.size():
		var d: Dictionary = records[i].duplicate()
		d["t0"] = summon_from + float(i) * SUMMON_STAGGER_SEC
		d["summon_sec"] = SUMMON_ASSEMBLY_SEC
		d["command_at"] = command_at
		out.append(d)
	return out


## The visual command time of an on-tile summon from its (schedule-ordered) [param records]: COMMAND_LEAD_SEC before
## the first sword starts to fall (the earliest `at` minus its fall). -1 for no records.
static func summon_command_at(records: Array[Dictionary]) -> float:
	var best: float = INF
	for d: Dictionary in records:
		best = minf(best, float(d["at"]) - fall_sec(d))
	return best - COMMAND_LEAD_SEC if best < INF else -1.0


## A copy of the hovering record [param d] that disperses at [param now] (a cancelled / interrupted channel): it
## goes straight to its shatter, centred where it hovered, with no ground impact. Visual only.
static func dispersed(d: Dictionary, now: float) -> Dictionary:
	var out: Dictionary = d.duplicate()
	out["at"] = now - EMBED_SEC
	out["disperse"] = true
	out["cast_id"] = -2
	out.erase("command_at")
	return out


## Seconds [param d] takes to assemble (SUMMON_ASSEMBLY_SEC for an on-tile summon, else MATERIALIZE_SEC).
static func materialize_sec(d: Dictionary) -> float:
	return float(d.get("summon_sec", MATERIALIZE_SEC))


## The lock-on cock-up of [param d] at [param now] (px up, 0 -> COCK_PX over COCK_SEC from `command_at`; 0 without a
## command).
static func cock_px(d: Dictionary, now: float) -> int:
	if not d.has("command_at"):
		return 0
	return int(roundf(float(COCK_PX) * clampf((now - float(d["command_at"])) / COCK_SEC, 0.0, 1.0)))


## True while [param d] shows its lock-on flash (LOCK_FLASH_SEC from `command_at`, before it falls).
static func locked_flash(d: Dictionary, now: float) -> bool:
	if not d.has("command_at"):
		return false
	var since: float = now - float(d["command_at"])
	return since >= 0.0 and since < LOCK_FLASH_SEC and now < float(d["at"]) - fall_sec(d)


## The art colours of the tones for a normal / [param final] drop (steel; never the telegraph red).
static func tone_colours(final: bool = false) -> Array[Color]:
	if final:
		return [Color("#1B1722"), Color("#8FA3B8"), Color("#C8D2DE"), Color("#EEF4FA"), Color("#FFFFFF")]
	return [Color("#1B1722"), Color("#5F6F82"), Color("#8FA3B8"), Color("#C8D2DE"), Color("#EEF4FA")]

class_name CastVfx
extends RefCounted
## 2026-10-31 (user: "skill chỉ hiển luôn trên ô chứ ko có hiệu ứng cast ra từ nhân vật"): the projectile a hero's
## skill throws from the hero to its target cells. Data: `assets/art/vfx/cast/index.json` (character id -> pack, and
## per pack its clip, hand offset, aim lift, travel_sec, gesture_lead_sec). The projectile leaves the hand when the
## player's swing has travel_sec left and lands on the target exactly when the swing resolves; the cast_gesture clip
## starts gesture_lead_sec earlier so its slash frame meets the launch. Pure helpers + a cached pack loader; a
## missing index or pack gives an empty entry / null, warned once, never a crash.

const INDEX_PATH: String = "res://assets/art/vfx/cast/index.json"
const CAST_DIR: String = "res://assets/art/vfx/cast"
const DEFAULT_CLIP: String = "whole"
const DEFAULT_TRAVEL_SEC: float = 0.18
const DEFAULT_GESTURE_LEAD_SEC: float = 0.09
## OSFE beats (design/references/osfe-spell-anatomy.md): the straight-shot path value and the defaults.
const PATH_ROW: String = "row"
## Straight from the hand to the area cell nearest the hero (the wave flow starts there).
const PATH_FIRST_CELL: String = "first_cell"
const DEFAULT_FLOW_STEP_SEC: float = 0.07
const DEFAULT_FLOW_TAIL_SEC: float = 0.08
const FLOW_NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]
const DEFAULT_CHARGE_SEC: float = 0.15
const DEFAULT_STAGGER_SEC: float = 0.04
## step_slide_sec / step_dust_sec (2026-11-02, user: "animation move ... hơi cứng", OSFE dash): a unit glides from its
## old feet to the new ones over step_slide_sec (ease-out) and leaves square dust on the old cell for step_dust_sec.
const DEFAULT_HIT_FEEL: Dictionary = {"flash_sec": 0.1, "flash_alpha": 0.75, "shake_px": 2, "shake_sec": 0.12,
	"step_slide_sec": 0.15, "step_dust_sec": 0.25}

static var _index: Dictionary = {}
static var _loaded: bool = false
static var _packs: Dictionary = {}


## The pack entry for the hero [param unit_id] (the index's `default` for an unmapped id); {} when none.
static func entry_for(unit_id: String) -> Dictionary:
	_ensure()
	var units: Dictionary = _index.get("units", {}) if _index.get("units", {}) is Dictionary else {}
	var pack_id: String = str(units.get(unit_id, _index.get("default", "")))
	var packs: Dictionary = _index.get("packs", {}) if _index.get("packs", {}) is Dictionary else {}
	var e: Variant = packs.get(pack_id, {})
	if not (e is Dictionary) or (e as Dictionary).is_empty():
		return {}
	var out: Dictionary = (e as Dictionary).duplicate()
	out["id"] = pack_id
	return out


## The loaded VfxPack of [param entry] (cached); null when the entry or its files are missing.
static func pack_for(entry: Dictionary) -> VfxPack:
	var dir: String = str(entry.get("dir", ""))
	if dir.is_empty():
		return null
	if not _packs.has(dir):
		_packs[dir] = VfxPack.load_pack(CAST_DIR.path_join(dir))
	return _packs[dir]


## The pack entry with id [param pack_id] (a projectile, or a charge pack); {} when none.
static func pack_entry(pack_id: String) -> Dictionary:
	_ensure()
	var packs: Dictionary = _index.get("packs", {}) if _index.get("packs", {}) is Dictionary else {}
	var e: Variant = packs.get(pack_id, {})
	if pack_id.is_empty() or not (e is Dictionary) or (e as Dictionary).is_empty():
		return {}
	var out: Dictionary = (e as Dictionary).duplicate()
	out["id"] = pack_id
	return out


## The charge pack entry of [param entry] (beat 1, looping at the hand before the launch); {} when it has none.
static func charge_entry(entry: Dictionary) -> Dictionary:
	return pack_entry(str(entry.get("charge", "")))


## Seconds the charge plays before the launch (>= 0).
static func charge_sec(entry: Dictionary) -> float:
	return maxf(float(entry.get("charge_sec", DEFAULT_CHARGE_SEC)), 0.0)


## Seconds into the charge with [param time_left] on a swing: -1 outside the window (travel_sec, travel_sec +
## charge_sec], so the charge ends exactly at the launch.
static func charge_elapsed(entry: Dictionary, time_left: float) -> float:
	var travel: float = travel_sec(entry)
	var charge: float = charge_sec(entry)
	if charge <= 0.0 or time_left <= travel or time_left > travel + charge:
		return -1.0
	return travel + charge - time_left


## The release pack entry of [param entry] (played once at the hand as the slash frame comes in: the cut the wave
## leaves from; tools/fx-pipeline `release_square_slash_*`); {} when it has none.
static func release_entry(entry: Dictionary) -> Dictionary:
	return pack_entry(str(entry.get("release", "")))


## Seconds into the release with [param time_left] on a swing: it starts gesture_lead_sec before the launch (when the
## cast_gesture jumps to its slash frame), i.e. at time_left = travel_sec + gesture_lead_sec; -1 before that.
static func release_elapsed(entry: Dictionary, time_left: float) -> float:
	if release_entry(entry).is_empty():
		return -1.0
	var start: float = gesture_due_left(entry)
	if time_left > start:
		return -1.0
	return start - time_left


## True when [param entry] draws its cast's impacts with packs (`impact` set): the code-drawn impact shards
## (CastFloorFx.impact_rects) are then left out for that cast so the cells are not drawn twice.
static func packs_replace_shards(entry: Dictionary) -> bool:
	return not str(entry.get("impact", "")).is_empty()


## Where the projectile flies to from [param from]: on the `row` path straight along the hero's row to the nearest
## target column (OSFE straight shot; the hero faces right, so the smallest x), else the aim point of the targets.
static func flight_to(entry: Dictionary, from: Vector2i, target_feet: Array[Vector2i]) -> Vector2i:
	if target_feet.is_empty():
		return from
	if str(entry.get("path", "")) != PATH_ROW:
		return aim_point(entry, target_feet)
	var nearest: int = target_feet[0].x
	for p: Vector2i in target_feet:
		nearest = mini(nearest, p.x)
	return Vector2i(nearest, from.y)


## Whether a resolved cut of a card with effect [param effect] flows as a wave through its cells (the entry's
## blast_effects; user 2026-11-01).
static func flows_for(entry: Dictionary, effect: String) -> bool:
	var effects: Variant = entry.get("blast_effects", [])
	return effects is Array and (effects as Array).has(effect)


## Seconds the wave takes from one cell to its neighbour (> 0).
static func flow_step_sec(entry: Dictionary) -> float:
	return maxf(float(entry.get("flow_step_sec", DEFAULT_FLOW_STEP_SEC)), 0.01)


## The area cell the projectile flies to and the wave starts from: the one nearest the hero's column, then row.
## [param hero_cell] (-1, -1) when unknown: the smallest x, then the smallest y.
static func first_cell(cells: Array, hero_cell: Vector2i) -> Vector2i:
	return SkillDelivery.nearest_cell(cells, hero_cell)


## ADR-0001 A1: the FloorVfx one-shot pack id drawn for delivery impact [param impact_id] (index `impact_packs`);
## "" when none is mapped.
static func impact_pack(impact_id: String) -> String:
	_ensure()
	var m: Variant = _index.get("impact_packs", {})
	return str((m as Dictionary).get(impact_id, "")) if m is Dictionary else ""


## ADR-0001 A1: the FloorVfx one-shot pack id drawn on the cells a delivery's travel [param travel_id] crosses
## (index `travel_packs`); "" when none is mapped (the hero's projectile is drawn by OverlayLayer instead).
static func travel_pack(travel_id: String) -> String:
	_ensure()
	var m: Variant = _index.get("travel_packs", {})
	return str((m as Dictionary).get(travel_id, "")) if m is Dictionary else ""


## Pure: how the wave flows through [param cells] from [param first]: breadth-first over 4-neighbours inside the
## area, [param step] seconds per neighbour; a cell not joined to the rest is reached from the nearest reached cell,
## step x their Manhattan distance later. Returns {"arrive": {cell: sec}, "segments": [[from, to, t0, t1], ...]
## (the front moving from one cell to the next, plus a [cell, cell, t, t + tail] linger on every last cell); the
## cells next to [param first] wait [param first_hold] more (the big explosion on the first cell, user 2026-11-01),
## "end": sec when the last front is gone}.
static func flow_plan(cells: Array, first: Vector2i, step: float, tail: float = DEFAULT_FLOW_TAIL_SEC, first_hold: float = 0.0) -> Dictionary:
	var arrive: Dictionary = {first: 0.0}
	var segments: Array = []
	var area: Dictionary = {}
	for c: Vector2i in cells:
		area[c] = true
	var queue: Array[Vector2i] = [first]
	var has_child: Dictionary = {}
	while true:
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for d: Vector2i in FLOW_NEIGHBOURS:
				var n: Vector2i = cur + d
				if area.has(n) and not arrive.has(n):
					arrive[n] = float(arrive[cur]) + step + (first_hold if cur == first else 0.0)
					segments.append([cur, n, float(arrive[cur]), float(arrive[n])])
					has_child[cur] = true
					queue.append(n)
		# Islands: join the unreached cell nearest to any reached one.
		var best_from := Vector2i(-1, -1)
		var best_to := Vector2i(-1, -1)
		var best_d: int = 1 << 30
		for c: Vector2i in cells:
			if arrive.has(c):
				continue
			for r: Vector2i in arrive:
				var md: int = absi(c.x - r.x) + absi(c.y - r.y)
				if md < best_d:
					best_d = md
					best_from = r
					best_to = c
		if best_d == 1 << 30:
			break
		arrive[best_to] = float(arrive[best_from]) + step * best_d + (first_hold if best_from == first else 0.0)
		segments.append([best_from, best_to, float(arrive[best_from]), float(arrive[best_to])])
		has_child[best_from] = true
		queue.append(best_to)
	var end: float = 0.0
	for c: Vector2i in arrive:
		if not has_child.has(c):
			segments.append([c, c, float(arrive[c]), float(arrive[c]) + tail])
			end = maxf(end, float(arrive[c]) + tail)
	return {"arrive": arrive, "segments": segments, "end": end}


## The flood settings of [param entry] with defaults: {fill, edge (Color), alpha, edge_px, hold_sec, fade_sec}.
static func flood_style(entry: Dictionary) -> Dictionary:
	var f: Dictionary = entry.get("flood", {}) if entry.get("flood", {}) is Dictionary else {}
	return {
		"fill": Color(str(f.get("fill", "#FFD45C"))), "edge": Color(str(f.get("edge", "#FFF1C2"))),
		"crack": Color(str(f.get("crack", "#FFE9A8"))), "alpha": float(f.get("alpha", 0.35)),
		"edge_px": int(f.get("edge_px", 2)), "squares": int(f.get("squares", 5)), "tiles": bool(f.get("tiles", true)),
		"hold_sec": float(f.get("hold_sec", 0.05)), "fade_sec": maxf(float(f.get("fade_sec", 0.16)), 0.01),
	}


## Pure: the lit cells [param age] seconds after the impact: one {"cell", "since" (seconds since the cell was
## reached), "reveal" (0..1, how much of the cell is lit), "fade" (1 = full; every cell fades together once the last
## one is lit + [param hold], over [param fade]), "dir" (the step it came in by: the cell minus the cell it was
## reached from; ZERO on the first cell, which grows from its centre)} per cell already reached.
static func flood_cells(plan: Dictionary, age: float, step: float, hold: float, fade: float) -> Array[Dictionary]:
	var parent: Dictionary = {}
	for seg: Array in plan.get("segments", []):
		if seg[0] != seg[1]:
			parent[seg[1]] = seg[0]
	var out: Array[Dictionary] = []
	var arrive: Dictionary = plan.get("arrive", {})
	var last: float = 0.0
	for cell: Vector2i in arrive:
		last = maxf(last, float(arrive[cell]))
	var f: float = 1.0 - clampf((age - last - step - hold) / fade, 0.0, 1.0)
	if f <= 0.0:
		return out
	for cell: Vector2i in arrive:
		var a: float = age - float(arrive[cell])
		if a < 0.0:
			continue
		var reveal: float = clampf(a / maxf(step, 0.001), 0.0, 1.0)
		var dir := Vector2i.ZERO
		if parent.has(cell):
			var dv: Vector2i = cell - (parent[cell] as Vector2i)
			dir = Vector2i(signi(dv.x), 0) if absi(dv.x) >= absi(dv.y) else Vector2i(0, signi(dv.y))
		out.append({"cell": cell, "since": a, "reveal": reveal, "fade": f, "dir": dir})
	return out


## Pure, deterministic per cell: [param count] crack polylines for a lit cell of art rect [param rect], each a list
## of whole-pixel points from near the centre outwards (the jagged gold cracks of the user's reference).
static func crack_lines(cell: Vector2i, rect: Rect2i, count: int = 3) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell) & 0x7FFFFFFF
	var c: Vector2 = Vector2(rect.position) + Vector2(rect.size) * 0.5
	var lines: Array = []
	for i: int in count:
		var ang: float = TAU * (float(i) / float(count)) + rng.randf_range(-0.6, 0.6)
		var reach: float = minf(rect.size.x, rect.size.y) * rng.randf_range(0.3, 0.45)
		var pts: Array[Vector2i] = [Vector2i(c.round())]
		for k: int in 3:
			var r: float = reach * float(k + 1) / 3.0
			var a2: float = ang + rng.randf_range(-0.35, 0.35)
			pts.append(Vector2i((c + Vector2(cos(a2), sin(a2) * 0.6) * r).round()))
		lines.append(pts)
	return lines


## Pure, deterministic per cell: the square shards rising from a lit cell [param since] seconds after it lit:
## [param count] Rect2i (art px) inside/above [param rect]; [] once they have risen away (0.5 s).
static func shard_rects(cell: Vector2i, rect: Rect2i, since: float, count: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if since < 0.0 or since > 0.5:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(cell) * 31 + 7) & 0x7FFFFFFF
	for i: int in count:
		var x: float = rect.position.x + rect.size.x * rng.randf_range(0.15, 0.85)
		var y0: float = rect.position.y + rect.size.y * rng.randf_range(0.35, 0.8)
		var speed: float = rng.randf_range(40.0, 90.0)
		var size: int = rng.randi_range(2, 4)
		var delay: float = rng.randf_range(0.0, 0.1)
		var t: float = since - delay
		if t < 0.0:
			continue
		out.append(Rect2i(roundi(x), roundi(y0 - speed * t), size, size))
	return out


## Seconds after the impact when the last cell's flood is gone.
static func flood_end(plan: Dictionary, step: float, hold: float, fade: float) -> float:
	var last: float = 0.0
	for cell: Vector2i in plan.get("arrive", {}):
		last = maxf(last, float(plan["arrive"][cell]))
	return last + step + hold + fade


## Pure: the part of [param rect] (art px) the stain covers at [param reveal], wiping in along [param dir] (ZERO =
## growing from the centre). Whole pixels.
static func flood_rect(rect: Rect2i, reveal: float, dir: Vector2i) -> Rect2i:
	var r: float = clampf(reveal, 0.0, 1.0)
	if dir == Vector2i.ZERO:
		var w: int = roundi(rect.size.x * r)
		var h: int = roundi(rect.size.y * r)
		return Rect2i(rect.position + (rect.size - Vector2i(w, h)) / 2, Vector2i(w, h))
	if dir.x != 0:
		var w2: int = roundi(rect.size.x * r)
		var x: int = rect.position.x if dir.x > 0 else rect.end.x - w2
		return Rect2i(x, rect.position.y, w2, rect.size.y)
	var h2: int = roundi(rect.size.y * r)
	var y: int = rect.position.y if dir.y > 0 else rect.end.y - h2
	return Rect2i(rect.position.x, y, rect.size.x, h2)


## Pure: the wave fronts alive [param age] seconds into [param plan]: one {"from", "to", "t" (0..1)} per segment
## running now.
static func flow_fronts(plan: Dictionary, age: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for seg: Array in plan.get("segments", []):
		var t0: float = float(seg[2])
		var t1: float = float(seg[3])
		if age >= t0 and age < t1:
			out.append({"from": seg[0], "to": seg[1], "t": clampf((age - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)})
	return out


## The FloorVfx one-shot played on every cell of a resolved cut of a card with effect [param effect]; "" when the
## entry has none for it (the old single hit_impact stays).
static func blast_for(entry: Dictionary, effect: String) -> String:
	var effects: Variant = entry.get("blast_effects", [])
	if not (effects is Array) or not (effects as Array).has(effect):
		return ""
	return str(entry.get("cell_blast", ""))


## Delay of each cell's blast (cell -> seconds): the nearest column (smallest x) at 0, each further column
## stagger_sec later, so the blasts run away from the hero (OSFE 0.05-0.2 s apart).
static func blast_delays(entry: Dictionary, cells: Array) -> Dictionary:
	var out: Dictionary = {}
	if cells.is_empty():
		return out
	var stagger: float = maxf(float(entry.get("stagger_sec", DEFAULT_STAGGER_SEC)), 0.0)
	var first: int = (cells[0] as Vector2i).x
	for c: Vector2i in cells:
		first = mini(first, c.x)
	for c: Vector2i in cells:
		out[c] = float(c.x - first) * stagger
	return out


## Seconds into a cell blast its brightest frame comes (>= 0): the hit flash waits for it.
static func blast_peak_sec(entry: Dictionary) -> float:
	return maxf(float(entry.get("blast_peak_sec", 0.0)), 0.0)


## The hit feel of a unit that takes damage: {flash_sec, flash_alpha, shake_px, shake_sec} (index `hit_feel`, each
## key falling back to DEFAULT_HIT_FEEL).
static func hit_feel() -> Dictionary:
	_ensure()
	var out: Dictionary = DEFAULT_HIT_FEEL.duplicate()
	var feel: Variant = _index.get("hit_feel", {})
	if feel is Dictionary:
		for k: String in DEFAULT_HIT_FEEL:
			if (feel as Dictionary).has(k):
				out[k] = float(feel[k])
	return out


## Seconds of flight of [param entry] (> 0).
static func travel_sec(entry: Dictionary) -> float:
	return maxf(float(entry.get("travel_sec", DEFAULT_TRAVEL_SEC)), 0.01)


## Seconds before the launch the cast_gesture clip starts (>= 0).
static func gesture_lead_sec(entry: Dictionary) -> float:
	return maxf(float(entry.get("gesture_lead_sec", DEFAULT_GESTURE_LEAD_SEC)), 0.0)


## The cast_gesture frame the hero holds during the swing telegraph (the wind-up's coil); -1 when the entry has
## none (the clip then waits on its first frame, the pre-v4 behaviour).
static func gesture_hold_frame(entry: Dictionary) -> int:
	return int(entry.get("gesture_hold_frame", -1))


## Time left on the swing at which the cast_gesture clip starts (travel + lead); a swing shorter than that plays the
## gesture from its start.
static func gesture_due_left(entry: Dictionary) -> float:
	return travel_sec(entry) + gesture_lead_sec(entry)


## Flight progress 0..1 of the projectile with [param time_left] on a swing: -1 before the launch (time_left >
## travel_sec), 0 at the launch, 1 when the swing resolves.
static func flight_t(entry: Dictionary, time_left: float) -> float:
	var travel: float = travel_sec(entry)
	if time_left > travel:
		return -1.0
	return clampf(1.0 - time_left / travel, 0.0, 1.0)


## Where the projectile is (whole art px) between [param from] and [param to] at progress [param t].
static func flight_pos(from: Vector2i, to: Vector2i, t: float) -> Vector2i:
	return Vector2i(Vector2(from).lerp(Vector2(to), clampf(t, 0.0, 1.0)).round())


## The launch point: the hero's [param feet] plus the entry's `hand` offset.
static func hand_point(entry: Dictionary, feet: Vector2i) -> Vector2i:
	var hand: Variant = entry.get("hand", [0, 0])
	var off := Vector2i.ZERO
	if hand is Array and (hand as Array).size() == 2:
		off = Vector2i(int(hand[0]), int(hand[1]))
	return feet + off


## The aim point: the mean of [param target_feet] (the target cells' feet anchors) lifted by the entry's aim_lift.
static func aim_point(entry: Dictionary, target_feet: Array[Vector2i]) -> Vector2i:
	if target_feet.is_empty():
		return Vector2i.ZERO
	var sum := Vector2.ZERO
	for p: Vector2i in target_feet:
		sum += Vector2(p)
	var mean: Vector2 = sum / float(target_feet.size())
	return Vector2i(mean.round()) - Vector2i(0, int(entry.get("aim_lift", 0)))


## ADR-0001 Task 5: [body, highlight] block colours of character [param unit_id] (index `block_colours`; `_enemy` for
## the enemy block; the `default` row, then Kiếm sĩ's steel, when unmapped).
static func block_colours(unit_id: String) -> Array[Color]:
	_ensure()
	var m: Dictionary = _index.get("block_colours", {}) if _index.get("block_colours", {}) is Dictionary else {}
	var row: Variant = m.get(unit_id, m.get("default", ["#8FA3B8", "#EEF4FA"]))
	var out: Array[Color] = [Color("8FA3B8"), Color("EEF4FA")]
	if row is Array and (row as Array).size() >= 2:
		out = [Color(str(row[0])), Color(str(row[1]))]
	return out


## ADR-0001 Task 5: the code-drawn style of [param key] (index `travel_style`: square_streak, falling_squares,
## chain_spark, floor_run, flash, charge); {} when absent (callers keep their defaults).
static func travel_style(key: String) -> Dictionary:
	_ensure()
	var m: Variant = _index.get("travel_style", {})
	var s: Variant = (m as Dictionary).get(key, {}) if m is Dictionary else {}
	return s as Dictionary if s is Dictionary else {}


## Task 5 item 2: {"colours": "block" or [body hex, highlight hex], "sec": float} of the code-drawn square impact
## [param impact_id] (index `impact_style`); {} when it has none (nothing is drawn).
static func impact_style(impact_id: String) -> Dictionary:
	_ensure()
	var m: Variant = _index.get("impact_style", {})
	var s: Variant = (m as Dictionary).get(impact_id, {}) if m is Dictionary else {}
	return s as Dictionary if s is Dictionary else {}


## Task 5 item 2: [body, highlight] of impact [param impact_id] cast by [param caster_id] (a character id or "_enemy"):
## the style's two hex colours, or the caster's block colours when the style says "block" (or names none).
static func impact_colours(impact_id: String, caster_id: String) -> Array[Color]:
	var cols: Variant = impact_style(impact_id).get("colours", "block")
	if cols is Array and (cols as Array).size() >= 2:
		return [Color(str(cols[0])), Color(str(cols[1]))]
	return block_colours(caster_id)


## Drops the cached index and packs (tests).
static func clear_cache() -> void:
	_index = {}
	_loaded = false
	_packs.clear()


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(INDEX_PATH):
		push_warning("CastVfx: no index at %s" % INDEX_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if parsed is Dictionary:
		_index = parsed
	else:
		push_warning("CastVfx: malformed %s" % INDEX_PATH)

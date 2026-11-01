class_name SkillDelivery
extends RefCounted
## ADR-0001 D7 / A1 (pack 01 §1A, 06 `Delivery`): a cast is three independent parts.
##   CELL MASK - the cells of the placed block shape; the ONLY cells that take damage or status (CutEffects).
##   DELIVERY  - origin + travel animation + per-cell arrival timing (this class, pure data + maths).
##   IMPACT    - the per-cell effect visual (a semantic id; CastVfx maps it to a FloorVfx pack).
## None of them knows how the others are drawn. The travel is animation only: it never applies damage or status
## outside the mask, unless the skill defines its own `path_rule` AND that path is telegraphed
## (`path_rule.telegraphed: true`; validated here, see [method damage_cells]). The gameplay Block is never thrown.
##
## Timing rule per type (seconds after the swing resolves; damage itself still lands at the resolve, D1 - these
## times only drive the per-cell impacts, the hit flash and the HIT label):
##   CASTER_TO_TARGET     - the travel leaves the caster before the resolve and lands on the mask cell nearest the
##                          caster at 0; the effect then spreads breadth-first through the mask: neighbours of the
##                          first cell at first_hold_sec + spread_step_sec, each further step spread_step_sec later
##                          (a cell not joined to the rest: from the nearest reached cell, step x Manhattan distance).
##                          This is the sword wave of 2026-11-01, unchanged.
##   SKY_TO_TARGET        - every cell falls together: fall_sec + its row-major index x stagger_sec (near-simultaneous).
##   GROUND_PROPAGATION   - runs along the floor from the origin cell (the caster's cell, or the first mask cell):
##                          a cell is reached at Manhattan distance x step_sec. Cells at equal distance land together.
##   DIRECT_MANIFESTATION - every cell at appear_sec, all at once.
##   SEQUENTIAL_CHAIN     - strictly one cell after another in chain_order: the k-th link at k x step_sec.
## Timing numbers live in assets/data/combat.json `timing.delivery` (CombatConfig.delivery_timing).

const CASTER_TO_TARGET: String = "CASTER_TO_TARGET"
const SKY_TO_TARGET: String = "SKY_TO_TARGET"
const GROUND_PROPAGATION: String = "GROUND_PROPAGATION"
const DIRECT_MANIFESTATION: String = "DIRECT_MANIFESTATION"
const SEQUENTIAL_CHAIN: String = "SEQUENTIAL_CHAIN"
const TYPES: Array[String] = [CASTER_TO_TARGET, SKY_TO_TARGET, GROUND_PROPAGATION, DIRECT_MANIFESTATION, SEQUENTIAL_CHAIN]
## Origins each type accepts; the first one is the type's default.
const ORIGINS: Dictionary = {
	CASTER_TO_TARGET: ["caster"],
	SKY_TO_TARGET: ["sky"],
	GROUND_PROPAGATION: ["origin_cell", "first_cell"],
	DIRECT_MANIFESTATION: ["target_cells"],
	SEQUENTIAL_CHAIN: ["first_cell", "caster"],
}
## Square-based travel visual ids (never the gameplay Block). `hero_pack` = the hero's cast pack (CastVfx).
const TRAVELS: Array[String] = ["hero_pack", "square_streak", "falling_squares", "floor_run", "chain_spark", "none"]
const IMPACTS: Array[String] = ["slash", "burst", "shatter", "burn", "freeze", "poison", "knockback", "guard", "seal", "thorns", "curse", "none"]
const CHAIN_ORDERS: Array[String] = ["nearest_first", "row_major", "authored"]
const CELL_MASK_BLOCK_SHAPE: String = "block_shape"
## What a skill's own path rule may apply on the travel cells.
const PATH_EFFECTS: Array[String] = ["damage", "status"]
## Types whose travel crosses floor cells (the only ones a path rule can mean anything for).
const PATH_TYPES: Array[String] = [CASTER_TO_TARGET, GROUND_PROPAGATION, SEQUENTIAL_CHAIN]
## Default of a skill with no / unusable delivery data (flagged as a problem; never silently SKY_TO_TARGET).
const FALLBACK: Dictionary = {
	"type": DIRECT_MANIFESTATION, "origin": "target_cells", "travel": "none", "impact": "burst",
	"cell_mask": CELL_MASK_BLOCK_SHAPE, "chain_order": "", "path_rule": {},
}
## Built-in timing per type (seconds); combat.json `timing.delivery` overrides key by key.
const DEFAULT_TIMING: Dictionary = {
	CASTER_TO_TARGET: {"spread_step_sec": 0.08, "first_hold_sec": 0.13},
	SKY_TO_TARGET: {"fall_sec": 0.12, "stagger_sec": 0.03},
	GROUND_PROPAGATION: {"step_sec": 0.06},
	DIRECT_MANIFESTATION: {"appear_sec": 0.0},
	SEQUENTIAL_CHAIN: {"step_sec": 0.1},
}
const _NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]


## Pure: the normalized delivery of [param raw] plus the problems found: {"delivery": Dictionary (keys type, origin,
## travel, impact, cell_mask, chain_order ("" unless SEQUENTIAL_CHAIN), path_rule ({} or {effect, telegraphed})),
## "problems": Array[String]}. Missing or unusable parts fall back per key (whole object: [constant FALLBACK]).
static func normalize(raw: Variant) -> Dictionary:
	var problems: Array[String] = []
	var out: Dictionary = FALLBACK.duplicate(true)
	if raw == null:
		problems.append("no delivery (every skill must declare one), using DIRECT_MANIFESTATION")
		return {"delivery": out, "problems": problems}
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("delivery must be an object, using DIRECT_MANIFESTATION")
		return {"delivery": out, "problems": problems}
	var d: Dictionary = raw as Dictionary
	var type: String = str(d.get("type", ""))
	if not TYPES.has(type):
		problems.append("delivery type '%s' unknown, using DIRECT_MANIFESTATION" % type)
		return {"delivery": out, "problems": problems}
	out["type"] = type
	var allowed: Array = ORIGINS[type]
	var origin: String = str(d.get("origin", allowed[0]))
	if not allowed.has(origin):
		problems.append("origin '%s' not valid for %s, using '%s'" % [origin, type, allowed[0]])
		origin = str(allowed[0])
	out["origin"] = origin
	var travel: String = str(d.get("travel", "none"))
	if not TRAVELS.has(travel):
		problems.append("travel '%s' unknown, using 'none'" % travel)
		travel = "none"
	if type == DIRECT_MANIFESTATION and travel != "none":
		problems.append("DIRECT_MANIFESTATION appears in place: travel '%s' dropped" % travel)
		travel = "none"
	out["travel"] = travel
	var impact: String = str(d.get("impact", ""))
	if not IMPACTS.has(impact):
		problems.append("impact '%s' unknown, using 'burst'" % impact)
		impact = "burst"
	out["impact"] = impact
	var mask: String = str(d.get("cell_mask", CELL_MASK_BLOCK_SHAPE))
	if mask != CELL_MASK_BLOCK_SHAPE:
		problems.append("cell_mask '%s' unsupported, using 'block_shape'" % mask)
	out["cell_mask"] = CELL_MASK_BLOCK_SHAPE
	if type == SEQUENTIAL_CHAIN:
		var order: String = str(d.get("chain_order", CHAIN_ORDERS[0]))
		if not CHAIN_ORDERS.has(order):
			problems.append("chain_order '%s' unknown, using 'nearest_first'" % order)
			order = CHAIN_ORDERS[0]
		out["chain_order"] = order
	elif d.has("chain_order"):
		problems.append("chain_order is for SEQUENTIAL_CHAIN only, ignored")
	if d.has("path_rule"):
		out["path_rule"] = _normalize_path_rule(d["path_rule"], type, problems)
	return {"delivery": out, "problems": problems}


## The normalized delivery of [param raw]; each problem is pushed as a warning naming [param owner_id].
static func parse(raw: Variant, owner_id: String = "") -> Dictionary:
	var r: Dictionary = normalize(raw)
	for p: String in r["problems"]:
		push_warning("SkillDelivery: %s: %s" % [owner_id, p])
	return r["delivery"]


## Pure: [constant DEFAULT_TIMING] with [param raw] (combat.json `timing.delivery`) laid over it key by key.
## {"timing": {type: {key: sec}}, "problems": Array[String]}; a bad value keeps its default.
static func normalize_timing(raw: Variant) -> Dictionary:
	var out: Dictionary = DEFAULT_TIMING.duplicate(true)
	var problems: Array[String] = []
	if raw == null:
		return {"timing": out, "problems": problems}
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("timing.delivery must be an object, using defaults")
		return {"timing": out, "problems": problems}
	for type: Variant in (raw as Dictionary).keys():
		if not TYPES.has(str(type)) or typeof((raw as Dictionary)[type]) != TYPE_DICTIONARY:
			problems.append("timing.delivery.%s unknown or not an object, ignored" % str(type))
			continue
		var block: Dictionary = (raw as Dictionary)[type]
		for key: Variant in block.keys():
			var v: Variant = block[key]
			if not (out[str(type)] as Dictionary).has(str(key)):
				problems.append("timing.delivery.%s.%s unknown, ignored" % [str(type), str(key)])
			elif (typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT) or float(v) < 0.0:
				problems.append("timing.delivery.%s.%s must be a number >= 0, using default" % [str(type), str(key)])
			else:
				out[str(type)][str(key)] = float(v)
	return {"timing": out, "problems": problems}


## The mask cell nearest [param from]: smallest column distance, then row distance; the first on ties.
static func nearest_cell(cells: Array, from: Vector2i) -> Vector2i:
	var best: Vector2i = cells[0]
	for c: Vector2i in cells:
		var dc := Vector2i(absi(c.x - from.x), absi(c.y - from.y))
		var db := Vector2i(absi(best.x - from.x), absi(best.y - from.y))
		if dc.x < db.x or (dc.x == db.x and dc.y < db.y):
			best = c
	return best


## The cell the delivery starts from on the floor: the caster's cell for `caster` / `origin_cell`, else the mask cell
## nearest the caster.
static func origin_cell(delivery: Dictionary, mask: Array, caster_cell: Vector2i) -> Vector2i:
	var origin: String = str(delivery.get("origin", ""))
	if origin == "caster" or origin == "origin_cell" or mask.is_empty():
		return caster_cell
	return nearest_cell(mask, caster_cell)


## The mask cell the travel lands on first (the hero projectile's aim): CASTER_TO_TARGET the nearest cell, a chain
## its first link, any other type the nearest cell.
static func first_link(delivery: Dictionary, mask: Array, caster_cell: Vector2i) -> Vector2i:
	if str(delivery.get("type", "")) == SEQUENTIAL_CHAIN:
		return chain_cells(delivery, mask, caster_cell)[0]
	return nearest_cell(mask, caster_cell)


## Pure: the chain's cells in order. nearest_first = Manhattan distance from the origin cell, ties row-major;
## row_major = by row, then column; authored = the mask's own order.
static func chain_cells(delivery: Dictionary, mask: Array, caster_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(mask)
	var order: String = str(delivery.get("chain_order", "nearest_first"))
	if order == "authored" or out.is_empty():
		return out
	var o: Vector2i = origin_cell(delivery, mask, caster_cell)
	if order == "row_major":
		out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	else:
		out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = _manhattan(a, o)
			var db: int = _manhattan(b, o)
			return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	return out


## Pure, deterministic: cell -> seconds after the resolve at which the delivery reaches each [param mask] cell, by
## the type's timing rule (see the class doc). [param timing] = CombatConfig.delivery_timing (or DEFAULT_TIMING).
static func arrival_times(delivery: Dictionary, mask: Array, caster_cell: Vector2i, timing: Dictionary = DEFAULT_TIMING) -> Dictionary:
	var out: Dictionary = {}
	if mask.is_empty():
		return out
	var type: String = str(delivery.get("type", DIRECT_MANIFESTATION))
	var t: Dictionary = _timing_of(timing, type)
	match type:
		CASTER_TO_TARGET:
			return _spread(mask, nearest_cell(mask, caster_cell), float(t["spread_step_sec"]), float(t["first_hold_sec"]))
		SKY_TO_TARGET:
			var rows: Array[Vector2i] = chain_cells({"chain_order": "row_major"}, mask, caster_cell)
			for i: int in rows.size():
				out[rows[i]] = float(t["fall_sec"]) + float(i) * float(t["stagger_sec"])
		GROUND_PROPAGATION:
			var o: Vector2i = origin_cell(delivery, mask, caster_cell)
			for c: Vector2i in mask:
				out[c] = float(_manhattan(c, o)) * float(t["step_sec"])
		SEQUENTIAL_CHAIN:
			var links: Array[Vector2i] = chain_cells(delivery, mask, caster_cell)
			for i: int in links.size():
				out[links[i]] = float(i) * float(t["step_sec"])
		_:
			for c: Vector2i in mask:
				out[c] = float(t["appear_sec"])
	return out


## Pure: the floor cells the travel visibly crosses that are NOT in [param mask], in travel order (animation only).
## CASTER_TO_TARGET: the straight flight from the caster's cell to the first cell; GROUND_PROPAGATION: the run from
## the origin cell along the row, then the column, to every mask cell; SEQUENTIAL_CHAIN: the row-then-column hop
## between consecutive links (and from the caster to the first link when the origin is `caster`); SKY / DIRECT: none.
## The caster's own cell is never included.
static func travel_cells(delivery: Dictionary, mask: Array, caster_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if mask.is_empty():
		return out
	var in_mask: Dictionary = {}
	for c: Vector2i in mask:
		in_mask[c] = true
	var raw: Array[Vector2i] = []
	match str(delivery.get("type", "")):
		CASTER_TO_TARGET:
			raw = _line(caster_cell, nearest_cell(mask, caster_cell))
		GROUND_PROPAGATION:
			var o: Vector2i = origin_cell(delivery, mask, caster_cell)
			for c: Vector2i in mask:
				raw.append_array(_l_path(o, c))
		SEQUENTIAL_CHAIN:
			var links: Array[Vector2i] = chain_cells(delivery, mask, caster_cell)
			if str(delivery.get("origin", "")) == "caster":
				raw.append_array(_line(caster_cell, links[0]))
			for i: int in range(1, links.size()):
				raw.append_array(_l_path(links[i - 1], links[i]))
	for c: Vector2i in raw:
		if c != caster_cell and not in_mask.has(c) and not out.has(c):
			out.append(c)
	return out


## Seconds after the resolve at which a GROUND_PROPAGATION run passes [param cell] (also the travel cells).
static func ground_time(delivery: Dictionary, mask: Array, caster_cell: Vector2i, cell: Vector2i, timing: Dictionary = DEFAULT_TIMING) -> float:
	return float(_manhattan(cell, origin_cell(delivery, mask, caster_cell))) * float(_timing_of(timing, GROUND_PROPAGATION)["step_sec"])


## The ONE gate for which cells a cast may affect: [param mask], plus the travel cells only when the delivery carries
## a valid path rule (normalized => telegraphed). No shipped card has a path rule; CutEffects still receives the mask
## only (the swing telegraph would have to draw the path cells before a card may use one).
static func damage_cells(delivery: Dictionary, mask: Array, caster_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(mask)
	var rule: Variant = delivery.get("path_rule", {})
	if rule is Dictionary and bool((rule as Dictionary).get("telegraphed", false)):
		for c: Vector2i in travel_cells(delivery, mask, caster_cell):
			out.append(c)
	return out


static func _normalize_path_rule(raw: Variant, type: String, problems: Array[String]) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("path_rule must be an object, dropped (the path stays animation only)")
		return {}
	var r: Dictionary = raw as Dictionary
	if not PATH_TYPES.has(type):
		problems.append("path_rule needs a travelling delivery (%s has no floor path), dropped" % type)
		return {}
	if r.get("telegraphed") != true:
		problems.append("path_rule without telegraphed: true is not allowed, dropped (the path stays animation only)")
		return {}
	var effect: String = str(r.get("effect", ""))
	if not PATH_EFFECTS.has(effect):
		problems.append("path_rule effect '%s' unknown, dropped" % effect)
		return {}
	return {"effect": effect, "telegraphed": true}


static func _timing_of(timing: Dictionary, type: String) -> Dictionary:
	var out: Dictionary = (DEFAULT_TIMING.get(type, DEFAULT_TIMING[DIRECT_MANIFESTATION]) as Dictionary).duplicate()
	var t: Variant = timing.get(type, {})
	if t is Dictionary:
		for k: Variant in (t as Dictionary).keys():
			if out.has(k):
				out[k] = float((t as Dictionary)[k])
	return out


# Breadth-first spread from [param first] (CastVfx.flow_plan's arrival rule, kept identical for the sword wave).
static func _spread(cells: Array, first: Vector2i, step: float, first_hold: float) -> Dictionary:
	var arrive: Dictionary = {first: 0.0}
	var area: Dictionary = {}
	for c: Vector2i in cells:
		area[c] = true
	var queue: Array[Vector2i] = [first]
	while true:
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for d: Vector2i in _NEIGHBOURS:
				var n: Vector2i = cur + d
				if area.has(n) and not arrive.has(n):
					arrive[n] = float(arrive[cur]) + step + (first_hold if cur == first else 0.0)
					queue.append(n)
		var best_from := Vector2i(-1, -1)
		var best_to := Vector2i(-1, -1)
		var best_d: int = 1 << 30
		for c: Vector2i in cells:
			if arrive.has(c):
				continue
			for r: Vector2i in arrive:
				var md: int = _manhattan(c, r)
				if md < best_d:
					best_d = md
					best_from = r
					best_to = c
		if best_d == 1 << 30:
			break
		arrive[best_to] = float(arrive[best_from]) + step * best_d + (first_hold if best_from == first else 0.0)
		queue.append(best_to)
	return arrive


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# Cells on the straight segment a -> b (sampled), both ends included.
static func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n: int = maxi(absi(b.x - a.x), absi(b.y - a.y)) * 4
	for i: int in n + 1:
		var p: Vector2 = Vector2(a).lerp(Vector2(b), float(i) / float(maxi(n, 1)))
		var c := Vector2i(roundi(p.x), roundi(p.y))
		if out.is_empty() or out[out.size() - 1] != c:
			out.append(c)
	return out


# Along the row first, then the column (floor slabs, no diagonals), both ends included.
static func _l_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [a]
	var c: Vector2i = a
	while c.x != b.x:
		c.x += signi(b.x - c.x)
		out.append(c)
	while c.y != b.y:
		c.y += signi(b.y - c.y)
		out.append(c)
	return out

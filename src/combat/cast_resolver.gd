class_name CastResolver
extends RefCounted
## Skill v2 (docs/skill-v2/02-mechanics-catalog.md M02): turns a resolved swing into its authoritative impact
## schedule. Pure and deterministic (no RNG, no clock): SwingArbiter places the events on its combat clock.
##
## A plan = {resolve, legacy (bool), max_hits, waves: [wave], events: [event]}:
##   wave  = {wave: int, t: float (first event, seconds after the swing end), cells: Array[Vector2i] (union),
##            kind: String, mult: float}
##   event = {wave: int, index: int (order in the cast), t: float, cells: Array[Vector2i], kind: String, mult: float}
##           (+ surge extras: step, region, from, pin_sec)
## Events are sorted by (t, wave, first cell y, x) and indexed in that order (surge: (t, region, y, x)).
##
## Resolve modes (card field `resolve`, validated by [method validate]):
##   instant  legacy: one wave, one event of every cell at t = 0. SwingArbiter keeps the pre-v2 code path for it
##            (golden test). Every legacy card uses it.
##   waves    `hits` waves on the same cells, `hit_interval_sec` apart (M08 engine form); `wave_mults` optional.
##   arrival  one event per cell, one wave. CASTER_TO_TARGET = the SURGE rule below (M03); a SKY_TO_TARGET delivery
##            makes every cell its own wave (M05); other types use SkillDelivery.arrival_times (M04 / M06).
## Hit limits (applied by the arbiter): a unit is hit at most once per wave and at most `max_hits` times per cast.
##
## Surge (CASTER_TO_TARGET arrival; Trảm Địa): the mask minus the cells locked at the resolve (cracking / holes) splits
## into 4-connected regions. The primary region holds the projectile's landing cell (SkillDelivery.first_link: the cell
## nearest the caster, the same cell the projectile flies to). It gets the `burst` event at t = 0, then every other cell
## of the region in breadth-first order from it: step k at first_hold_sec + k x spread_step_sec (combat.json
## timing.delivery, the same numbers as the visuals). The surge never crosses a missing or locked cell. A region not
## connected to the landing cell is reached by its OWN split of the wave (no path is drawn or hit between regions): it
## starts on its own cell nearest the caster (a `landing` event, no burst, no pin) at t = 0 and surges the same way.
## Regions are ordered primary first, then by (start cell's Manhattan distance to the caster, y, x).
## Event extras: step (from its region's start), region (order index), from (the cell the surge came from; (-1, -1)
## for a start cell), pin_sec (the burst's Pin on a hit).
## Per-event multiplier = the shape-clause group S (02-design-decisions.md §10), capped at [constant SHAPE_GROUP_CAP]:
## the burst x `burst_first`; a surge event x (1 + min(step x surge_per_step, surge_cap)) when the card's shape_clause
## holds for the cast (scope any_piece / all_pieces / union, tags of the PHYSICAL pieces in the CastContext).

const RESOLVE_INSTANT: String = "instant"
const RESOLVE_WAVES: String = "waves"
const RESOLVE_ARRIVAL: String = "arrival"
const RESOLVE_MODES: Array[String] = [RESOLVE_INSTANT, RESOLVE_WAVES, RESOLVE_ARRIVAL]
## Bounds of the validated numbers.
const MAX_HITS: int = 8
const MIN_INTERVAL_SEC: float = 0.02
const MAX_INTERVAL_SEC: float = 2.0
const DEFAULT_INTERVAL_SEC: float = 0.12
const MAX_BURST_FIRST: float = 2.0
const MAX_PIN_SEC: float = 2.0
## Card effects a scheduled (non-instant) resolve may carry; zone / status cards stay instant.
const SCHEDULED_EFFECTS: Array[String] = ["damage"]
## 02-design-decisions.md §10: the product of a card's shape-clause multipliers (burst-first, surge, ...) is capped here.
const SHAPE_GROUP_CAP: float = 2.0
const CLAUSE_SCOPES: Array[String] = ["any_piece", "all_pieces", "union"]
const CLAUSE_KEYS: Array[String] = ["tag", "scope", "surge_per_step", "surge_cap"]
## Event kinds of the surge.
const KIND_BURST: String = "burst"
const KIND_LANDING: String = "landing"
const KIND_SURGE: String = "surge"
const NO_CELL := Vector2i(-1, -1)
const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]


## Validates the resolve fields of raw card [param raw] (id [param id], its normalized [param effect] and
## [param cast_mode]). Returns {resolve, hits, max_hits, hit_interval_sec, wave_mults, burst_first, burst_pin_sec,
## shape_clause, errors: Array[String]}. Any error puts the card back on `instant` with hits = max_hits = 1 and no
## clause (its legacy path) and is REPORTED, never silent.
static func validate(id: String, raw: Dictionary, effect: String = "damage", cast_mode: String = "direct") -> Dictionary:
	var errors: Array[String] = []
	var resolve: String = str(raw.get("resolve", RESOLVE_INSTANT))
	if not RESOLVE_MODES.has(resolve):
		errors.append("card %s: resolve '%s' unknown (known: %s)" % [id, resolve, ", ".join(RESOLVE_MODES)])
	var hits: int = _int_field(id, raw, "hits", 1, 1, MAX_HITS, errors)
	var max_hits: int = _int_field(id, raw, "max_hits", hits, 1, MAX_HITS, errors)
	var interval: float = DEFAULT_INTERVAL_SEC
	if raw.has("hit_interval_sec"):
		var v: Variant = raw["hit_interval_sec"]
		if not (v is float or v is int) or float(v) < MIN_INTERVAL_SEC or float(v) > MAX_INTERVAL_SEC:
			errors.append("card %s: hit_interval_sec %s must be a number in [%s, %s]" % [id, str(v), MIN_INTERVAL_SEC, MAX_INTERVAL_SEC])
		else:
			interval = float(v)
	var mults: Array[float] = []
	if raw.has("wave_mults"):
		var arr: Variant = raw["wave_mults"]
		if not arr is Array:
			errors.append("card %s: wave_mults must be an array of numbers" % id)
		else:
			for m: Variant in arr as Array:
				if not (m is float or m is int) or float(m) < 0.0:
					errors.append("card %s: wave_mults entry %s must be a number >= 0" % [id, str(m)])
					break
				mults.append(float(m))
	var burst: float = _num_field(id, raw, "burst_first", 1.0, 1.0, MAX_BURST_FIRST, errors)
	var pin_sec: float = _num_field(id, raw, "burst_pin_sec", 0.0, 0.0, MAX_PIN_SEC, errors)
	var clause: Dictionary = _clause(id, raw.get("shape_clause", {}), errors)
	if resolve != RESOLVE_ARRIVAL and (raw.has("burst_first") or raw.has("burst_pin_sec") or clause.has("surge_per_step")):
		errors.append("card %s: burst_first / burst_pin_sec / a surge clause need resolve 'arrival'" % id)
	if resolve == RESOLVE_INSTANT and hits > 1:
		errors.append("card %s: hits %d needs resolve 'waves' (instant resolves once)" % [id, hits])
	if resolve != RESOLVE_INSTANT and not SCHEDULED_EFFECTS.has(effect):
		errors.append("card %s: resolve '%s' is not supported for effect '%s' yet (damage only)" % [id, resolve, effect])
	if resolve != RESOLVE_INSTANT and cast_mode != "direct":
		errors.append("card %s: resolve '%s' needs cast_mode direct (got '%s')" % [id, resolve, cast_mode])
	if not errors.is_empty():
		return {"resolve": RESOLVE_INSTANT, "hits": 1, "max_hits": 1, "hit_interval_sec": DEFAULT_INTERVAL_SEC,
			"wave_mults": [] as Array[float], "burst_first": 1.0, "burst_pin_sec": 0.0, "shape_clause": {}, "errors": errors}
	return {"resolve": resolve, "hits": hits, "max_hits": max_hits, "hit_interval_sec": interval, "wave_mults": mults,
		"burst_first": burst, "burst_pin_sec": pin_sec, "shape_clause": clause, "errors": errors}


## The impact plan of card [param skill] (a normalized SkillConfig entry) cast on [param cells] with [param context]
## (CastContext; may be empty). [param timing] = the delivery timing table (CombatConfig.delivery_timing).
## [param locked] = the cells locked (cracking / hole) at the resolve: no event on them; the surge does not cross them.
static func plan(skill: Dictionary, cells: Array[Vector2i], context: Dictionary,
		timing: Dictionary = SkillDelivery.DEFAULT_TIMING, locked: Array = []) -> Dictionary:
	var resolve: String = str(skill.get("resolve", RESOLVE_INSTANT))
	var events: Array[Dictionary] = []
	var max_hits: int = maxi(int(skill.get("max_hits", 1)), 1)
	var surge: bool = false
	match resolve:
		RESOLVE_WAVES:
			var hits: int = maxi(int(skill.get("hits", 1)), 1)
			var interval: float = float(skill.get("hit_interval_sec", DEFAULT_INTERVAL_SEC))
			var mults: Array = skill.get("wave_mults", []) as Array
			for k: int in hits:
				var m: float = float(mults[k]) if k < mults.size() else 1.0
				events.append(_event(k, float(k) * interval, cells.duplicate(), "hit", m))
		RESOLVE_ARRIVAL:
			if _delivery_type(skill, context) == SkillDelivery.CASTER_TO_TARGET:
				surge = true
				events = surge_events(skill, cells, context, timing, locked)
			else:
				events = _arrival_events(skill, cells, context, timing)
		_:
			resolve = RESOLVE_INSTANT
			max_hits = 1
			events.append(_event(0, 0.0, cells.duplicate(), "hit", 1.0))
	if not surge:
		events.sort_custom(_event_before)
	var waves: Dictionary = {}
	for i: int in events.size():
		var e: Dictionary = events[i]
		e["index"] = i
		var w: int = int(e["wave"])
		if not waves.has(w):
			waves[w] = {"wave": w, "t": float(e["t"]), "cells": [] as Array[Vector2i], "kind": e["kind"], "mult": e["mult"]}
		for c: Vector2i in e["cells"] as Array[Vector2i]:
			if not (waves[w]["cells"] as Array[Vector2i]).has(c):
				(waves[w]["cells"] as Array[Vector2i]).append(c)
	var wave_list: Array[Dictionary] = []
	var keys: Array = waves.keys()
	keys.sort()
	for w: Variant in keys:
		wave_list.append(waves[w])
	return {"resolve": resolve, "legacy": resolve == RESOLVE_INSTANT, "max_hits": max_hits, "waves": wave_list,
		"events": events}


## B1 API kept: the waves of [method plan].
static func schedule(skill: Dictionary, cells: Array[Vector2i], context: Dictionary) -> Array[Dictionary]:
	var waves: Array[Dictionary] = []
	waves.assign(plan(skill, cells, context)["waves"])
	return waves


## The surge events of a CASTER_TO_TARGET `arrival` card (see the class doc), sorted by (t, region, y, x), not indexed.
static func surge_events(skill: Dictionary, cells: Array[Vector2i], context: Dictionary,
		timing: Dictionary = SkillDelivery.DEFAULT_TIMING, locked: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var open: Array[Vector2i] = []
	for c: Vector2i in cells:
		if not locked.has(c) and not open.has(c):
			open.append(c)
	if open.is_empty():
		return out
	var delivery: Dictionary = context.get("delivery", skill.get("delivery", {})) as Dictionary
	var caster: Vector2i = context.get("caster_cell", Vector2i(-1, open[0].y))
	var t: Dictionary = SkillDelivery.DEFAULT_TIMING[SkillDelivery.CASTER_TO_TARGET]
	if timing.get(SkillDelivery.CASTER_TO_TARGET) is Dictionary:
		t = timing[SkillDelivery.CASTER_TO_TARGET]
	var step_sec: float = maxf(float(t.get("spread_step_sec", 0.08)), 0.0)
	var hold: float = maxf(float(t.get("first_hold_sec", 0.0)), 0.0)
	var landing: Vector2i = SkillDelivery.first_link(delivery, open, caster)
	var regions: Array = _regions(open)
	var starts: Array[Vector2i] = []
	for reg: Variant in regions:
		var region: Array[Vector2i] = reg
		starts.append(landing if region.has(landing) else SkillDelivery.nearest_cell(region, caster))
	var order: Array = range(regions.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var sa: Vector2i = starts[a]
		var sb: Vector2i = starts[b]
		if (sa == landing) != (sb == landing):
			return sa == landing
		var da: int = absi(sa.x - caster.x) + absi(sa.y - caster.y)
		var db: int = absi(sb.x - caster.x) + absi(sb.y - caster.y)
		return da < db or (da == db and (sa.y < sb.y or (sa.y == sb.y and sa.x < sb.x))))
	var burst: float = float(skill.get("burst_first", 1.0))
	var pin_sec: float = float(skill.get("burst_pin_sec", 0.0))
	var clause: Dictionary = skill.get("shape_clause", {}) as Dictionary
	var per_step: float = float(clause.get("surge_per_step", 0.0)) if clause_holds(clause, context) else 0.0
	var cap: float = float(clause.get("surge_cap", 0.0))
	for ri: int in order.size():
		var region: Array[Vector2i] = regions[order[ri]]
		var start: Vector2i = starts[order[ri]]
		var dist: Dictionary = {start: 0}
		var parent: Dictionary = {start: NO_CELL}
		var queue: Array[Vector2i] = [start]
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for d: Vector2i in _DIRS:
				var n: Vector2i = cur + d
				if region.has(n) and not dist.has(n):
					dist[n] = int(dist[cur]) + 1
					parent[n] = cur
					queue.append(n)
		for c: Vector2i in region:
			var k: int = int(dist[c])
			var kind: String = KIND_SURGE
			var m: float = 1.0 + minf(float(k) * per_step, cap)
			var pin: float = 0.0
			if k == 0:
				kind = KIND_BURST if start == landing else KIND_LANDING
				m = burst if start == landing else 1.0
				pin = pin_sec if start == landing else 0.0
			var one: Array[Vector2i] = [c]
			var e: Dictionary = _event(0, 0.0 if k == 0 else hold + float(k) * step_sec, one, kind, minf(m, SHAPE_GROUP_CAP))
			e["step"] = k
			e["region"] = ri
			e["from"] = parent[c]
			e["pin_sec"] = pin
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["t"]) - float(b["t"])) > 0.000001:
			return float(a["t"]) < float(b["t"])
		if int(a["region"]) != int(b["region"]):
			return int(a["region"]) < int(b["region"])
		var ca: Vector2i = (a["cells"] as Array[Vector2i])[0]
		var cb: Vector2i = (b["cells"] as Array[Vector2i])[0]
		return ca.y < cb.y or (ca.y == cb.y and ca.x < cb.x))
	return out


## True when shape clause [param clause] ({tag, scope}) holds for the cast [param context]: any_piece (default) = at
## least one placed piece has the tag; all_pieces = every placed piece; union = the union of the cells. {} / no tag /
## no pieces = false. Tags come from the PHYSICAL pieces (effective cells never change them).
static func clause_holds(clause: Dictionary, context: Dictionary) -> bool:
	var tag: String = str(clause.get("tag", ""))
	var pieces: Array = context.get("pieces", []) as Array
	if tag.is_empty() or pieces.is_empty():
		return false
	match str(clause.get("scope", "any_piece")):
		"all_pieces":
			for p: Variant in pieces:
				if not ((p as Dictionary).get("tags", []) as Array).has(tag):
					return false
			return true
		"union":
			var union: Array[Vector2i] = []
			union.assign(context.get("cells", []) as Array)
			return (ShapeTags.tags_for(union)["tags"] as Array).has(tag)
		_:
			return CastContext.has_tag(context, tag)


static func _arrival_events(skill: Dictionary, cells: Array[Vector2i], context: Dictionary, timing: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var delivery: Dictionary = context.get("delivery", skill.get("delivery", {})) as Dictionary
	var caster: Vector2i = context.get("caster_cell", Vector2i(-1, cells[0].y if not cells.is_empty() else 0))
	var times: Dictionary = SkillDelivery.arrival_times(delivery, cells, caster, timing)
	var per_cell_wave: bool = str(delivery.get("type", "")) == SkillDelivery.SKY_TO_TARGET
	var ordered: Array[Vector2i] = cells.duplicate()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ta: float = float(times.get(a, 0.0))
		var tb: float = float(times.get(b, 0.0))
		if absf(ta - tb) > 0.000001:
			return ta < tb
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for i: int in ordered.size():
		var one: Array[Vector2i] = [ordered[i]]
		events.append(_event(i if per_cell_wave else 0, float(times.get(ordered[i], 0.0)), one, "hit", 1.0))
	return events


static func _delivery_type(skill: Dictionary, context: Dictionary) -> String:
	var delivery: Dictionary = context.get("delivery", skill.get("delivery", {})) as Dictionary
	return str(delivery.get("type", ""))


# 4-connected regions of [param cells], each listed in discovery order.
static func _regions(cells: Array[Vector2i]) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for c: Vector2i in cells:
		if seen.has(c):
			continue
		var region: Array[Vector2i] = []
		var queue: Array[Vector2i] = [c]
		seen[c] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			region.append(cur)
			for d: Vector2i in _DIRS:
				var n: Vector2i = cur + d
				if cells.has(n) and not seen.has(n):
					seen[n] = true
					queue.append(n)
		out.append(region)
	return out


static func _event(wave: int, t: float, cells: Array[Vector2i], kind: String, mult: float) -> Dictionary:
	return {"wave": wave, "index": 0, "t": t, "cells": cells, "kind": kind, "mult": mult}


static func _event_before(a: Dictionary, b: Dictionary) -> bool:
	if absf(float(a["t"]) - float(b["t"])) > 0.000001:
		return float(a["t"]) < float(b["t"])
	if int(a["wave"]) != int(b["wave"]):
		return int(a["wave"]) < int(b["wave"])
	var ca: Vector2i = (a["cells"] as Array[Vector2i])[0] if not (a["cells"] as Array).is_empty() else Vector2i.ZERO
	var cb: Vector2i = (b["cells"] as Array[Vector2i])[0] if not (b["cells"] as Array).is_empty() else Vector2i.ZERO
	return ca.y < cb.y or (ca.y == cb.y and ca.x < cb.x)


static func _num_field(id: String, raw: Dictionary, key: String, fallback: float, lo: float, hi: float, errors: Array[String]) -> float:
	if not raw.has(key):
		return fallback
	var v: Variant = raw[key]
	if not (v is float or v is int) or float(v) < lo or float(v) > hi:
		errors.append("card %s: %s %s must be a number in [%s, %s]" % [id, key, str(v), lo, hi])
		return fallback
	return float(v)


static func _clause(id: String, raw: Variant, errors: Array[String]) -> Dictionary:
	if raw == null or (raw is Dictionary and (raw as Dictionary).is_empty()):
		return {}
	if not raw is Dictionary:
		errors.append("card %s: shape_clause must be an object" % id)
		return {}
	var c: Dictionary = raw as Dictionary
	for k: Variant in c.keys():
		if not CLAUSE_KEYS.has(str(k)):
			errors.append("card %s: shape_clause key '%s' unknown (known: %s)" % [id, str(k), ", ".join(CLAUSE_KEYS)])
	var tag: String = str(c.get("tag", ""))
	if tag.is_empty():
		errors.append("card %s: shape_clause needs a tag" % id)
	var scope: String = str(c.get("scope", "any_piece"))
	if not CLAUSE_SCOPES.has(scope):
		errors.append("card %s: shape_clause scope '%s' unknown" % [id, scope])
	var out: Dictionary = {"tag": tag, "scope": scope}
	for k: String in ["surge_per_step", "surge_cap"]:
		if c.has(k):
			out[k] = _num_field(id, c, k, 0.0, 0.0, 1.0, errors)
	return out


static func _int_field(id: String, raw: Dictionary, key: String, fallback: int, lo: int, hi: int, errors: Array[String]) -> int:
	if not raw.has(key):
		return fallback
	var v: Variant = raw[key]
	if not (v is int or (v is float and float(v) == floorf(float(v)))) or int(v) < lo or int(v) > hi:
		errors.append("card %s: %s %s must be a whole number in [%d, %d]" % [id, key, str(v), lo, hi])
		return fallback
	return int(v)

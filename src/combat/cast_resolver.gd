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
## Sky drops (SKY_TO_TARGET arrival; Ngàn Kiếm, M05 + M06 from_centre): every open (not locked) cell gets ONE drop, each
## its own wave (a unit is hit at most once per drop; `max_hits` caps the cast), drop i at sky_hover_sec + i x
## sky_stagger_sec (card fields; else the delivery timing fall_sec / stagger_sec). Order (`drop_order`):
##   row_major (default)  by y, then x.
##   from_centre          the hub first, then outward by BFS distance inside its region (ties y, x). The hub = the
##                        union's ShapeTags centre (ties nearest the caster). Regions not connected to the hub follow,
##                        ordered by their own centre's Manhattan distance to the hub (ties y, x), each from its own
##                        centre; no path between regions.
## Branched rule (shape_clause {tag: branched, tips_first: true, centre_mult}): when the clause holds, the hub is the
## union cell with the most neighbours (the junction; ties nearest the bbox centre, then y, x) and the whole order is
## reversed: tips first, the hub LAST as kind `drop_final` x centre_mult. Kinds: drop / drop_final.
## Delayed (M07, `resolve: "delayed"`; Hỏa Lôi, docs/skill-v2/09-hoa-loi-design.md): the open cells (not locked, not in
## the caller's `excluded` list = cells already holding an armed event of the same side) become ONE wave, ONE event of
## kind `fuse` at t = fuse_sec, x fuse_mult (all cells detonate in the same instant; a unit is hit once). The event is
## `armed` (an armed-zone cell until it fires), re-checks locks when it fires (`recheck_locked`) and carries the card's
## `event_payload` (applied by the arbiter after the damage, hit or miss). A shape_clause {fuse_sec, fuse_mult} that holds
## replaces both (its fuse_mult / the card's is the shape-clause group, capped). The plan's `cast_cells` = the number of
## armed cells (damage counts them). No open cell -> no event (`fizzled`).
## Per-event multiplier = the shape-clause group S (02-design-decisions.md §10), capped at [constant SHAPE_GROUP_CAP]:
## the burst x `burst_first`; a surge event x (1 + min(step x surge_per_step, surge_cap)) when the card's shape_clause
## holds for the cast (scope any_piece / all_pieces / union, tags of the PHYSICAL pieces in the CastContext).

const RESOLVE_INSTANT: String = "instant"
const RESOLVE_WAVES: String = "waves"
const RESOLVE_ARRIVAL: String = "arrival"
const RESOLVE_DELAYED: String = "delayed"
const RESOLVE_MODES: Array[String] = [RESOLVE_INSTANT, RESOLVE_WAVES, RESOLVE_ARRIVAL, RESOLVE_DELAYED]
## Delayed (fuse) bounds and the event kind.
const MIN_FUSE_SEC: float = 0.2
const MAX_FUSE_SEC: float = 5.0
const MAX_FUSE_MULT: float = 4.0
const MAX_ACTIVE_FIELDS: int = 4
const KIND_FUSE: String = "fuse"
## Payload effects a scheduled event may carry (applied after its damage): ignite {sec, tick_sec, damage}.
const PAYLOAD_KEYS: Array[String] = ["ignite"]
## Damage-cell rules (card field `damage_cells_rule`, scheduled resolves): how many of a cast's cells its damage counts
## when it hits (dpc x counted cells x mult). "all" (default: every cell, the rule of every card so far), "footprint"
## (at most the target's footprint cells + `extra`; Hỏa Lôi Model C, docs/skill-v2/13-hoa-loi-damage-models.md), "max"
## (at most `max` cells). SwingArbiter and the balance sim both read [method damage_cells].
const DAMAGE_CELL_MODES: Array[String] = ["all", "footprint", "max"]
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
const CLAUSE_KEYS: Array[String] = ["tag", "scope", "surge_per_step", "surge_cap", "tips_first", "centre_mult", "fuse_sec",
	"fuse_mult", "fuse_mult_scale"]
const DROP_ORDERS: Array[String] = ["row_major", "from_centre"]
const KIND_DROP: String = "drop"
const KIND_DROP_FINAL: String = "drop_final"
const MAX_AWAKENING_EXTRA_HITS: int = 3
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
	var hover: float = _num_field(id, raw, "sky_hover_sec", -1.0, 0.0, 2.0, errors)
	var stagger: float = _num_field(id, raw, "sky_stagger_sec", -1.0, 0.02, 1.0, errors)
	var drop_order: String = str(raw.get("drop_order", "row_major"))
	if not DROP_ORDERS.has(drop_order):
		errors.append("card %s: drop_order '%s' unknown (known: %s)" % [id, drop_order, ", ".join(DROP_ORDERS)])
	var extra_hits: int = _int_field(id, raw, "awakening_extra_hits", 0, 0, MAX_AWAKENING_EXTRA_HITS, errors)
	var fixed_hit: bool = false
	if raw.has("fixed_hit"):
		if not raw["fixed_hit"] is bool:
			errors.append("card %s: fixed_hit must be true / false" % id)
		else:
			fixed_hit = bool(raw["fixed_hit"])
	if resolve != RESOLVE_ARRIVAL and (raw.has("sky_hover_sec") or raw.has("sky_stagger_sec") or raw.has("drop_order")
			or clause.has("tips_first")):
		errors.append("card %s: sky_hover_sec / sky_stagger_sec / drop_order / a tips_first clause need resolve 'arrival'" % id)
	if resolve != RESOLVE_ARRIVAL and (raw.has("burst_first") or raw.has("burst_pin_sec") or clause.has("surge_per_step")):
		errors.append("card %s: burst_first / burst_pin_sec / a surge clause need resolve 'arrival'" % id)
	if resolve == RESOLVE_INSTANT and hits > 1:
		errors.append("card %s: hits %d needs resolve 'waves' (instant resolves once)" % [id, hits])
	var fuse_sec: float = _num_field(id, raw, "fuse_sec", 1.5, MIN_FUSE_SEC, MAX_FUSE_SEC, errors)
	var fuse_mult: float = _num_field(id, raw, "fuse_mult", 1.0, 0.0, MAX_FUSE_MULT, errors)
	var max_active: int = _int_field(id, raw, "max_active", 0, 0, MAX_ACTIVE_FIELDS, errors)
	var payload: Dictionary = _payload(id, raw.get("event_payload", {}), errors)
	var dmg_rule: Dictionary = _damage_cells_rule(id, raw.get("damage_cells_rule", {}), errors)
	if resolve == RESOLVE_INSTANT and str(dmg_rule.get("mode", "all")) != "all":
		errors.append("card %s: damage_cells_rule needs a scheduled resolve" % id)
	if resolve != RESOLVE_DELAYED and (raw.has("fuse_sec") or raw.has("fuse_mult") or raw.has("max_active")
			or clause.has("fuse_sec") or clause.has("fuse_mult") or clause.has("fuse_mult_scale")):
		errors.append("card %s: fuse_sec / fuse_mult / max_active / a fuse clause need resolve 'delayed'" % id)
	if resolve != RESOLVE_DELAYED and not payload.is_empty():
		errors.append("card %s: event_payload is carried by resolve 'delayed' events only (for now)" % id)
	if clause.has("fuse_mult") and fuse_mult > 0.0 and float(clause["fuse_mult"]) / fuse_mult > SHAPE_GROUP_CAP + 0.000001:
		errors.append("card %s: shape_clause fuse_mult / fuse_mult must be <= %s (shape-clause group cap)" % [id, SHAPE_GROUP_CAP])
	if resolve != RESOLVE_INSTANT and not SCHEDULED_EFFECTS.has(effect):
		errors.append("card %s: resolve '%s' is not supported for effect '%s' yet (damage only)" % [id, resolve, effect])
	if resolve != RESOLVE_INSTANT and cast_mode != "direct":
		errors.append("card %s: resolve '%s' needs cast_mode direct (got '%s')" % [id, resolve, cast_mode])
	if not errors.is_empty():
		return {"resolve": RESOLVE_INSTANT, "hits": 1, "max_hits": 1, "hit_interval_sec": DEFAULT_INTERVAL_SEC,
			"wave_mults": [] as Array[float], "burst_first": 1.0, "burst_pin_sec": 0.0, "shape_clause": {},
			"sky_hover_sec": -1.0, "sky_stagger_sec": -1.0, "drop_order": "row_major", "awakening_extra_hits": 0,
			"fixed_hit": false, "fuse_sec": 1.5, "fuse_mult": 1.0, "max_active": 0, "event_payload": {},
			"damage_cells_rule": {"mode": "all"}, "errors": errors}
	return {"fuse_sec": fuse_sec, "fuse_mult": fuse_mult, "max_active": max_active, "event_payload": payload,
		"damage_cells_rule": dmg_rule,
		"resolve": resolve, "hits": hits, "max_hits": max_hits, "hit_interval_sec": interval, "wave_mults": mults,
		"burst_first": burst, "burst_pin_sec": pin_sec, "shape_clause": clause, "sky_hover_sec": hover,
		"sky_stagger_sec": stagger, "drop_order": drop_order, "awakening_extra_hits": extra_hits, "fixed_hit": fixed_hit,
		"errors": errors}


## The impact plan of card [param skill] (a normalized SkillConfig entry) cast on [param cells] with [param context]
## (CastContext; may be empty). [param timing] = the delivery timing table (CombatConfig.delivery_timing).
## [param locked] = the cells locked (cracking / hole) at the resolve: no event on them; the surge does not cross them.
## [param excluded] = cells skipped by a `delayed` card (already armed by the same side); other modes ignore it.
static func plan(skill: Dictionary, cells: Array[Vector2i], context: Dictionary,
		timing: Dictionary = SkillDelivery.DEFAULT_TIMING, locked: Array = [], excluded: Array = []) -> Dictionary:
	var resolve: String = str(skill.get("resolve", RESOLVE_INSTANT))
	var events: Array[Dictionary] = []
	var max_hits: int = maxi(int(skill.get("max_hits", 1)), 1)
	var surge: bool = false
	var extra: Dictionary = {}
	match resolve:
		RESOLVE_DELAYED:
			max_hits = 1
			var open: Array[Vector2i] = []
			for c: Vector2i in cells:
				if not locked.has(c) and not excluded.has(c) and not open.has(c):
					open.append(c)
			var skipped: Array[Vector2i] = []
			for c: Vector2i in cells:
				if excluded.has(c) and not locked.has(c) and not skipped.has(c):
					skipped.append(c)
			var fuse: Dictionary = fuse_timing(skill, context)
			extra = {"cast_cells": open.size(), "skipped_cells": skipped, "fizzled": open.is_empty(),
				"fuse_sec": float(fuse["fuse_sec"]), "fuse_mult": float(fuse["fuse_mult"]), "clause": bool(fuse["clause"])}
			if not open.is_empty():
				var e: Dictionary = _event(0, float(fuse["fuse_sec"]), open, KIND_FUSE, float(fuse["fuse_mult"]))
				e["armed"] = true
				e["recheck_locked"] = true
				var payload: Dictionary = skill.get("event_payload", {}) as Dictionary
				if not payload.is_empty():
					e["payload"] = payload.duplicate(true)
				events.append(e)
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
			elif _delivery_type(skill, context) == SkillDelivery.SKY_TO_TARGET:
				surge = true
				events = sky_events(skill, cells, context, timing, locked)
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
	var out: Dictionary = {"resolve": resolve, "legacy": resolve == RESOLVE_INSTANT, "max_hits": max_hits, "waves": wave_list,
		"events": events}
	out.merge(extra)
	return out


## Seconds between the swing end and the damage of [param skill] cast with [param context]: the fuse of a `delayed`
## card, 0 otherwise (the boss's threat feed adds it to a running swing's time left).
static func threat_delay(skill: Dictionary, context: Dictionary) -> float:
	if str(skill.get("resolve", RESOLVE_INSTANT)) != RESOLVE_DELAYED:
		return 0.0
	return float(fuse_timing(skill, context)["fuse_sec"])


## Delayed (fuse) timing of [param skill] for the cast [param context]: {fuse_sec, fuse_mult, clause (bool)}. A
## shape_clause carrying fuse_sec / fuse_mult that holds (e.g. Hỏa Lôi's `square`) replaces the card's values.
static func fuse_timing(skill: Dictionary, context: Dictionary) -> Dictionary:
	var sec: float = float(skill.get("fuse_sec", 1.5))
	var mult: float = float(skill.get("fuse_mult", 1.0))
	var clause: Dictionary = skill.get("shape_clause", {}) as Dictionary
	var holds: bool = (clause.has("fuse_sec") or clause.has("fuse_mult") or clause.has("fuse_mult_scale")) 		and clause_holds(clause, context)
	if holds:
		sec = float(clause.get("fuse_sec", sec))
		# fuse_mult_scale: the clause's multiplier as a ratio of the card's own (follows a re-tuned base)
		mult = mult * float(clause["fuse_mult_scale"]) if clause.has("fuse_mult_scale") else float(clause.get("fuse_mult", mult))
	return {"fuse_sec": sec, "fuse_mult": mult, "clause": holds}


## The cell count the damage of a hit of [param skill] uses: its cast counted [param cast_cells] cells and the target's
## footprint has [param footprint_cells] cells (DAMAGE_CELL_MODES; "all" = cast_cells). Never below 1.
static func damage_cells(skill: Dictionary, cast_cells: int, footprint_cells: int) -> int:
	var rule: Dictionary = skill.get("damage_cells_rule", {}) as Dictionary
	match str(rule.get("mode", "all")):
		"footprint":
			return maxi(mini(cast_cells, maxi(footprint_cells, 1) + int(rule.get("extra", 0))), 1)
		"max":
			return maxi(mini(cast_cells, int(rule.get("max", cast_cells))), 1)
		_:
			return cast_cells


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


## The sky-drop events of a SKY_TO_TARGET `arrival` card (see the class doc), in drop order, not indexed.
static func sky_events(skill: Dictionary, cells: Array[Vector2i], context: Dictionary,
		timing: Dictionary = SkillDelivery.DEFAULT_TIMING, locked: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var open: Array[Vector2i] = []
	for c: Vector2i in cells:
		if not locked.has(c) and not open.has(c):
			open.append(c)
	if open.is_empty():
		return out
	var t: Dictionary = SkillDelivery.DEFAULT_TIMING[SkillDelivery.SKY_TO_TARGET]
	if timing.get(SkillDelivery.SKY_TO_TARGET) is Dictionary:
		t = timing[SkillDelivery.SKY_TO_TARGET]
	var hover: float = float(skill.get("sky_hover_sec", -1.0))
	if hover < 0.0:
		hover = maxf(float(t.get("fall_sec", 0.12)), 0.0)
	var stagger: float = float(skill.get("sky_stagger_sec", -1.0))
	if stagger < 0.0:
		stagger = maxf(float(t.get("stagger_sec", 0.03)), 0.0)
	var caster: Vector2i = context.get("caster_cell", Vector2i(-1, open[0].y))
	var clause: Dictionary = skill.get("shape_clause", {}) as Dictionary
	var branched: bool = bool(clause.get("tips_first", false)) and clause_holds(clause, context)
	var order: Array[Vector2i] = []
	var regions_of: Dictionary = {}
	if str(skill.get("drop_order", "row_major")) == "from_centre":
		var hub: Vector2i = junction(open) if branched else ShapeTags.tags_for(open, false, caster)["centre"]
		var regions: Array = _regions(open)
		var starts: Array[Vector2i] = []
		for reg: Variant in regions:
			var region: Array[Vector2i] = reg
			starts.append(hub if region.has(hub) else ShapeTags.tags_for(region, false, caster)["centre"])
		var idx: Array = range(regions.size())
		idx.sort_custom(func(a: int, b: int) -> bool:
			var sa: Vector2i = starts[a]
			var sb: Vector2i = starts[b]
			if (sa == hub) != (sb == hub):
				return sa == hub
			var da: int = absi(sa.x - hub.x) + absi(sa.y - hub.y)
			var db: int = absi(sb.x - hub.x) + absi(sb.y - hub.y)
			return da < db or (da == db and (sa.y < sb.y or (sa.y == sb.y and sa.x < sb.x))))
		for ri: int in idx.size():
			var region: Array[Vector2i] = regions[idx[ri]]
			var dist: Dictionary = _bfs(region, starts[idx[ri]])
			var cells_r: Array[Vector2i] = region.duplicate()
			cells_r.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				if int(dist[a]) != int(dist[b]):
					return int(dist[a]) < int(dist[b])
				return a.y < b.y or (a.y == b.y and a.x < b.x))
			for c: Vector2i in cells_r:
				order.append(c)
				regions_of[c] = ri
		if branched:
			order.reverse()
	else:
		order = open.duplicate()
		order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var centre_mult: float = minf(float(clause.get("centre_mult", 1.0)), SHAPE_GROUP_CAP) if branched else 1.0
	for i: int in order.size():
		var last: bool = branched and i == order.size() - 1
		var one: Array[Vector2i] = [order[i]]
		var e: Dictionary = _event(i, hover + float(i) * stagger, one, KIND_DROP_FINAL if last else KIND_DROP,
			centre_mult if last else 1.0)
		e["step"] = i
		e["region"] = int(regions_of.get(order[i], 0))
		e["from"] = NO_CELL
		e["pin_sec"] = 0.0
		out.append(e)
	return out


## The junction of [param cells]: the cell with the most 4-neighbours inside them; ties -> nearest the bbox centre,
## then smallest y, then x (deterministic for T, plus, Y and Odd blocks).
static func junction(cells: Array[Vector2i]) -> Vector2i:
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c: Vector2i in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var mid: Vector2 = (Vector2(lo) + Vector2(hi)) * 0.5
	var best: Vector2i = cells[0]
	var best_deg: int = -1
	var best_d: float = INF
	for c: Vector2i in cells:
		var deg: int = 0
		for d: Vector2i in _DIRS:
			if cells.has(c + d):
				deg += 1
		var dd: float = Vector2(c).distance_squared_to(mid)
		var better: bool = deg > best_deg or (deg == best_deg and (dd < best_d - 0.0001 or (absf(dd - best_d) <= 0.0001
			and (c.y < best.y or (c.y == best.y and c.x < best.x)))))
		if better:
			best = c
			best_deg = deg
			best_d = dd
	return best


static func _bfs(region: Array[Vector2i], start: Vector2i) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in _DIRS:
			var n: Vector2i = cur + d
			if region.has(n) and not dist.has(n):
				dist[n] = int(dist[cur]) + 1
				queue.append(n)
	return dist


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
	if c.has("tips_first"):
		if not c["tips_first"] is bool:
			errors.append("card %s: shape_clause tips_first must be true / false" % id)
		else:
			out["tips_first"] = bool(c["tips_first"])
	if c.has("centre_mult"):
		out["centre_mult"] = _num_field(id, c, "centre_mult", 1.0, 1.0, SHAPE_GROUP_CAP, errors)
	if c.has("fuse_sec"):
		out["fuse_sec"] = _num_field(id, c, "fuse_sec", 1.5, MIN_FUSE_SEC, MAX_FUSE_SEC, errors)
	if c.has("fuse_mult"):
		out["fuse_mult"] = _num_field(id, c, "fuse_mult", 1.0, 0.0, MAX_FUSE_MULT, errors)
	if c.has("fuse_mult_scale"):
		out["fuse_mult_scale"] = _num_field(id, c, "fuse_mult_scale", 1.0, 1.0, SHAPE_GROUP_CAP, errors)
		if c.has("fuse_mult"):
			errors.append("card %s: shape_clause takes fuse_mult or fuse_mult_scale, not both" % id)
	return out


# The card's damage_cells_rule ({} / {"mode": "all"} = every cell): DAMAGE_CELL_MODES; footprint {extra 0..4}, max {max 1..20}.
static func _damage_cells_rule(id: String, raw: Variant, errors: Array[String]) -> Dictionary:
	if raw == null or (raw is Dictionary and (raw as Dictionary).is_empty()):
		return {"mode": "all"}
	if not raw is Dictionary:
		errors.append("card %s: damage_cells_rule must be an object" % id)
		return {"mode": "all"}
	var d: Dictionary = raw as Dictionary
	var mode: String = str(d.get("mode", "all"))
	if not DAMAGE_CELL_MODES.has(mode):
		errors.append("card %s: damage_cells_rule mode '%s' unknown (known: %s)" % [id, mode, ", ".join(DAMAGE_CELL_MODES)])
		return {"mode": "all"}
	var out: Dictionary = {"mode": mode}
	if mode == "footprint":
		out["extra"] = _int_field(id, d, "extra", 0, 0, 4, errors)
	elif mode == "max":
		out["max"] = _int_field(id, d, "max", 4, 1, 20, errors)
	return out


# The card's event_payload ({} = none): only PAYLOAD_KEYS; ignite = {sec > 0, tick_sec > 0, damage >= 0}.
static func _payload(id: String, raw: Variant, errors: Array[String]) -> Dictionary:
	if raw == null or (raw is Dictionary and (raw as Dictionary).is_empty()):
		return {}
	if not raw is Dictionary:
		errors.append("card %s: event_payload must be an object" % id)
		return {}
	var out: Dictionary = {}
	for k: Variant in (raw as Dictionary).keys():
		if not PAYLOAD_KEYS.has(str(k)):
			errors.append("card %s: event_payload key '%s' unknown (known: %s)" % [id, str(k), ", ".join(PAYLOAD_KEYS)])
	var ig: Variant = (raw as Dictionary).get("ignite")
	if ig != null:
		if not ig is Dictionary:
			errors.append("card %s: event_payload ignite must be an object" % id)
		else:
			var d: Dictionary = ig as Dictionary
			out["ignite"] = {"sec": _num_field(id, d, "sec", 0.0, 0.05, 10.0, errors),
				"tick_sec": _num_field(id, d, "tick_sec", 0.5, 0.05, 5.0, errors),
				"damage": _num_field(id, d, "damage", 0.0, 0.0, 100.0, errors)}
			if not d.has("sec"):
				errors.append("card %s: event_payload ignite needs sec" % id)
	return out


static func _int_field(id: String, raw: Dictionary, key: String, fallback: int, lo: int, hi: int, errors: Array[String]) -> int:
	if not raw.has(key):
		return fallback
	var v: Variant = raw[key]
	if not (v is int or (v is float and float(v) == floorf(float(v)))) or int(v) < lo or int(v) > hi:
		errors.append("card %s: %s %s must be a whole number in [%d, %d]" % [id, key, str(v), lo, hi])
		return fallback
	return int(v)

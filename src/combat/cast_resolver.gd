class_name CastResolver
extends RefCounted
## Skill v2 (docs/skill-v2/02-mechanics-catalog.md M02): turns a resolved swing into its authoritative impact
## schedule. Pure and deterministic (no RNG, no clock): SwingArbiter places the events on its combat clock.
##
## A plan = {resolve, legacy (bool), max_hits, waves: [wave], events: [event]}:
##   wave  = {wave: int, t: float (first event, seconds after the swing end), cells: Array[Vector2i] (union),
##            kind: String, mult: float}
##   event = {wave: int, index: int (order in the cast), t: float, cells: Array[Vector2i], kind: String, mult: float}
## Events are sorted by (t, wave, first cell y, x) and indexed in that order.
##
## Resolve modes (card field `resolve`, validated by [method validate]):
##   instant  legacy: one wave, one event of every cell at t = 0. SwingArbiter keeps the pre-v2 code path for it
##            (golden test). Every card in the game uses it today.
##   waves    `hits` waves on the same cells, `hit_interval_sec` apart (M08 engine form); `wave_mults` optional.
##   arrival  one event per cell at its SkillDelivery.arrival_times time (M03 / M04 / M06), one wave; a
##            SKY_TO_TARGET delivery makes every cell its own wave (M05).
## Hit limits (applied by the arbiter): a unit is hit at most once per wave and at most `max_hits` times per cast.
## B1.5: the engine supports waves / arrival but no card uses them yet (no new skill rule is active).

const RESOLVE_INSTANT: String = "instant"
const RESOLVE_WAVES: String = "waves"
const RESOLVE_ARRIVAL: String = "arrival"
const RESOLVE_MODES: Array[String] = [RESOLVE_INSTANT, RESOLVE_WAVES, RESOLVE_ARRIVAL]
## Bounds of the validated numbers.
const MAX_HITS: int = 8
const MIN_INTERVAL_SEC: float = 0.02
const MAX_INTERVAL_SEC: float = 2.0
const DEFAULT_INTERVAL_SEC: float = 0.12
## Card effects a scheduled (non-instant) resolve may carry in B1.5; zone / status cards stay instant.
const SCHEDULED_EFFECTS: Array[String] = ["damage"]


## Validates the resolve fields of raw card [param raw] (id [param id], its normalized [param effect] and
## [param cast_mode]). Returns {resolve, hits, max_hits, hit_interval_sec, wave_mults, errors: Array[String]}.
## Any error puts the card back on `instant` with hits = max_hits = 1 (its legacy path) and is REPORTED, never silent.
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
	if resolve == RESOLVE_INSTANT and hits > 1:
		errors.append("card %s: hits %d needs resolve 'waves' (instant resolves once)" % [id, hits])
	if resolve != RESOLVE_INSTANT and not SCHEDULED_EFFECTS.has(effect):
		errors.append("card %s: resolve '%s' is not supported for effect '%s' yet (damage only)" % [id, resolve, effect])
	if resolve != RESOLVE_INSTANT and cast_mode != "direct":
		errors.append("card %s: resolve '%s' needs cast_mode direct (got '%s')" % [id, resolve, cast_mode])
	if not errors.is_empty():
		return {"resolve": RESOLVE_INSTANT, "hits": 1, "max_hits": 1, "hit_interval_sec": DEFAULT_INTERVAL_SEC,
			"wave_mults": [] as Array[float], "errors": errors}
	return {"resolve": resolve, "hits": hits, "max_hits": max_hits, "hit_interval_sec": interval, "wave_mults": mults,
		"errors": errors}


## The impact plan of card [param skill] (a normalized SkillConfig entry) cast on [param cells] with [param context]
## (CastContext; may be empty). [param timing] = the delivery timing table (CombatConfig.delivery_timing).
static func plan(skill: Dictionary, cells: Array[Vector2i], context: Dictionary,
		timing: Dictionary = SkillDelivery.DEFAULT_TIMING) -> Dictionary:
	var resolve: String = str(skill.get("resolve", RESOLVE_INSTANT))
	var events: Array[Dictionary] = []
	var max_hits: int = maxi(int(skill.get("max_hits", 1)), 1)
	match resolve:
		RESOLVE_WAVES:
			var hits: int = maxi(int(skill.get("hits", 1)), 1)
			var interval: float = float(skill.get("hit_interval_sec", DEFAULT_INTERVAL_SEC))
			var mults: Array = skill.get("wave_mults", []) as Array
			for k: int in hits:
				var m: float = float(mults[k]) if k < mults.size() else 1.0
				events.append(_event(k, float(k) * interval, cells.duplicate(), "hit", m))
		RESOLVE_ARRIVAL:
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
		_:
			resolve = RESOLVE_INSTANT
			max_hits = 1
			events.append(_event(0, 0.0, cells.duplicate(), "hit", 1.0))
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


static func _int_field(id: String, raw: Dictionary, key: String, fallback: int, lo: int, hi: int, errors: Array[String]) -> int:
	if not raw.has(key):
		return fallback
	var v: Variant = raw[key]
	if not (v is int or (v is float and float(v) == floorf(float(v)))) or int(v) < lo or int(v) > hi:
		errors.append("card %s: %s %s must be a whole number in [%d, %d]" % [id, key, str(v), lo, hi])
		return fallback
	return int(v)

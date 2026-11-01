class_name EnemySkillsConfig
extends RefCounted
## The pattern-brain data (assets/data/enemy_skills.json): fairness numbers, AI weights, defaults, status numbers,
## skills (cell pattern + anchor + timings + delivery + effects) and enemies (phases of ANY length, A4). Pure: build
## with [method from_dictionary] in tests. Bad data is REFUSED with a clear problem line (a skill without a delivery,
## an unknown anchor, a followup warning below fairness.followup_min_warning_sec...): the skill is dropped, never
## patched to a default delivery (spec section 10, ADR-0001 D7). Keys: assets/data/schema.md "enemy_skills.json".
## Implements: design/quick-specs/phase2-misty-forest-2026-11-01.md P2.2 (sections 3.2-3.8), ADR-0001 A4.

const DEFAULT_PATH: String = "res://assets/data/enemy_skills.json"
const KINDS: Array[String] = ["attack", "self", "marker"]
const ANCHORS: Array[String] = [
	"on_player", "near_player", "row_of_player", "column_of_player", "row_of_anchor", "fixed", "self_cell",
	"enemy_half_empty",
]
const ROTATIONS: Array[int] = [0, 90, 180, 270]
const RELATIVE_TO: Array[String] = ["first_cells", "first_end", "first_center", "player"]
## Status ids a skill may apply: existing pin (Frozen), fragile (Ran), frost (Han) + Phase 2 root (D2) / slow (D4).
const STATUS_IDS: Array[String] = ["root", "slow", "pin", "fragile", "frost"]
const ZONE_IDS: Array[String] = ["thorns", "drop"]
const DEFAULT_FAIRNESS: Dictionary = {
	"reaction_margin_sec": 0.25, "max_red_ratio": 0.5, "cc_grace_sec": 1.0,
	"min_gap_between_warnings_sec": 0.4, "followup_min_warning_sec": 0.75, "heavy_recovery_sec": 1.2,
}
const DEFAULT_AI: Dictionary = {
	"punish_standing_still": 1.2, "standing_still_sec": 1.5, "avoid_repeat_last_skill": 0.45,
	"favor_phase_mechanic": 1.25, "noise": 0.1, "cancel_cooldown_ratio": 0.5,
}
const DEFAULT_DEFAULTS: Dictionary = {
	"windup_sec": 0.5, "recovery_sec": 0.6, "weight": 1.0, "interruptible": true, "phase_transition_sec": 1.5,
	"marker_life_sec": 12.0, "marker_break_min_cells": 1,
}
const DEFAULT_STATUSES: Dictionary = {
	"root": {"sec": 0.7}, "slow": {"sec": 1.5, "step_mult": 1.3}, "guard": {"amount": 3.0, "sec": 3.0},
	"fragile": {"stacks": 1}, "frost": {"stacks": 1},
}
const _EPS: float = 0.000001

var fairness: Dictionary = DEFAULT_FAIRNESS.duplicate(true)
var ai: Dictionary = DEFAULT_AI.duplicate(true)
var defaults: Dictionary = DEFAULT_DEFAULTS.duplicate(true)
var statuses: Dictionary = DEFAULT_STATUSES.duplicate(true)
## skill id -> normalized skill (keys: see schema.md).
var skills: Dictionary = {}
## enemy id -> normalized enemy {id, tier, ai, phases: Array[Dictionary]}.
var enemies: Dictionary = {}
## Every problem found while loading (also pushed as warnings by [method load_from_file]).
var problems: Array[String] = []


## Loads [param path]; a missing / broken file gives an empty config with a problem line.
static func load_from_file(path: String = DEFAULT_PATH) -> EnemySkillsConfig:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var config: EnemySkillsConfig
	if typeof(parsed) != TYPE_DICTIONARY:
		config = EnemySkillsConfig.new()
		config.problems.append("%s: missing or not a JSON object" % path)
	else:
		config = from_dictionary(parsed as Dictionary)
	for p: String in config.problems:
		push_warning("EnemySkillsConfig: " + p)
	return config


## Pure: validates and normalizes [param data] (the JSON object). See the class doc for the refusal rules.
static func from_dictionary(data: Dictionary) -> EnemySkillsConfig:
	var c: EnemySkillsConfig = EnemySkillsConfig.new()
	c.fairness = _merge_numbers(DEFAULT_FAIRNESS, data.get("fairness"), "fairness", c.problems)
	c.ai = _merge_numbers(DEFAULT_AI, data.get("ai"), "ai", c.problems)
	c.defaults = _merge_numbers(DEFAULT_DEFAULTS, data.get("defaults"), "defaults", c.problems)
	if typeof(data.get("statuses")) == TYPE_DICTIONARY:
		for key: String in DEFAULT_STATUSES:
			c.statuses[key] = _merge_numbers(DEFAULT_STATUSES[key], (data["statuses"] as Dictionary).get(key), "statuses." + key, c.problems)
	var raw_skills: Variant = data.get("skills", {})
	if typeof(raw_skills) != TYPE_DICTIONARY:
		c.problems.append("skills must be an object")
		raw_skills = {}
	for id: Variant in (raw_skills as Dictionary):
		var skill: Dictionary = c._normalize_skill(str(id), (raw_skills as Dictionary)[id])
		if not skill.is_empty():
			c.skills[str(id)] = skill
	var raw_enemies: Variant = data.get("enemies", {})
	if typeof(raw_enemies) != TYPE_DICTIONARY:
		c.problems.append("enemies must be an object")
		raw_enemies = {}
	for id: Variant in (raw_enemies as Dictionary):
		var enemy: Dictionary = c._normalize_enemy(str(id), (raw_enemies as Dictionary)[id])
		if not enemy.is_empty():
			c.enemies[str(id)] = enemy
	return c


## The normalized enemy [param id]; {} when unknown.
func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {}) as Dictionary


## The skill [param id] with [param phase]'s override for it laid over (one level deep for pattern / effects /
## followup objects); {} when unknown. Same skill, different numbers per phase, no duplicate skill (spec 3.8).
func skill_for_phase(id: String, phase: Dictionary) -> Dictionary:
	if not skills.has(id):
		return {}
	var skill: Dictionary = (skills[id] as Dictionary).duplicate(true)
	var overrides: Dictionary = (phase.get("overrides", {}) as Dictionary).get(id, {}) as Dictionary
	for key: Variant in overrides:
		if typeof(overrides[key]) == TYPE_DICTIONARY and typeof(skill.get(key)) == TYPE_DICTIONARY:
			(skill[key] as Dictionary).merge(overrides[key] as Dictionary, true)
		elif key == "count":
			(skill["pattern"] as Dictionary)["count"] = maxi(int(overrides[key]), 1)
		else:
			skill[key] = overrides[key]
	return skill


func _normalize_skill(id: String, raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("skill %s: must be an object, refused" % id)
		return {}
	var d: Dictionary = raw as Dictionary
	var errors: Array[String] = []
	var kind: String = str(d.get("kind", "attack"))
	if not KINDS.has(kind):
		errors.append("kind '%s' unknown" % kind)
	var default_side: String = "player"
	if kind == "self":
		default_side = "self"
	elif kind == "marker":
		default_side = "enemy"
	var s: Dictionary = {
		"id": id, "owner": str(d.get("owner", "shared")), "kind": kind,
		"pattern": _normalize_pattern(d.get("pattern", {}), kind, errors),
		"target_side": str(d.get("target_side", default_side)),
		"windup_sec": maxf(float(d.get("windup_sec", defaults["windup_sec"])), 0.0),
		"warning_sec": float(d.get("warning_sec", 0.0)),
		"recovery_sec": maxf(float(d.get("recovery_sec", defaults["recovery_sec"])), 0.0),
		"cooldown_sec": maxf(float(d.get("cooldown_sec", 0.0)), 0.0),
		"weight": maxf(float(d.get("weight", defaults["weight"])), 0.0),
		"interruptible": bool(d.get("interruptible", defaults["interruptible"])),
		"conditions": (d["conditions"] as Dictionary).duplicate(true) if typeof(d.get("conditions")) == TYPE_DICTIONARY else {},
		"counter_key": str(d.get("counter_key", "")),
		"effects": _normalize_effects(d.get("effects", {}), errors, "effects"),
		"followup": {},
	}
	if kind == "attack" and float(s["warning_sec"]) <= 0.0:
		errors.append("attack skill needs warning_sec > 0")
	if not d.has("delivery"):
		errors.append("no delivery (every skill declares type, origin, travel, impact)")
	else:
		var r: Dictionary = SkillDelivery.normalize(d["delivery"])
		for p: String in r["problems"]:
			errors.append("delivery: " + p)
		s["delivery"] = r["delivery"]
	if d.get("followup") != null:
		s["followup"] = _normalize_followup(d["followup"], errors)
	if not errors.is_empty():
		for e: String in errors:
			problems.append("skill %s: %s, refused" % [id, e])
		return {}
	return s


func _normalize_pattern(raw: Variant, kind: String, errors: Array[String]) -> Dictionary:
	var d: Dictionary = raw as Dictionary if typeof(raw) == TYPE_DICTIONARY else {}
	var default_anchor: String = "on_player"
	if kind == "self":
		default_anchor = "self_cell"
	elif kind == "marker":
		default_anchor = "enemy_half_empty"
	var anchor: String = str(d.get("anchor", default_anchor))
	if not ANCHORS.has(anchor):
		errors.append("anchor '%s' unknown (known: %s)" % [anchor, ", ".join(ANCHORS)])
	var offsets: Array[Vector2i] = _parse_offsets(d.get("offsets", [[0, 0]]), errors, "pattern.offsets")
	var rotations: Array[int] = _parse_rotations(d.get("rotations", [0]), errors, "pattern.rotations")
	var covers_by_default: bool = anchor == "on_player" or anchor == "row_of_player" or anchor == "column_of_player"
	return {
		"anchor": anchor, "offsets": offsets, "rotations": rotations,
		"must_cover_player": bool(d.get("must_cover_player", covers_by_default)),
		"clip": bool(d.get("clip", false)), "min_cells": maxi(int(d.get("min_cells", offsets.size())), 1),
		"start": str(d.get("start", "any")), "count": maxi(int(d.get("count", 1)), 1),
		"exclude_player": bool(d.get("exclude_player", false)),
	}


func _normalize_followup(raw: Variant, errors: Array[String]) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("followup must be an object or null")
		return {}
	var d: Dictionary = raw as Dictionary
	var rel: String = str(d.get("relative_to", "first_cells"))
	if not RELATIVE_TO.has(rel):
		errors.append("followup.relative_to '%s' unknown" % rel)
	var warn: float = float(d.get("warning_sec", 0.0))
	if warn + _EPS < float(fairness["followup_min_warning_sec"]):
		errors.append("followup warning %.2f s below fairness.followup_min_warning_sec %.2f s" % [warn, float(fairness["followup_min_warning_sec"])])
	return {
		"offsets": _parse_offsets(d.get("offsets", [[0, 0]]), errors, "followup.offsets"), "relative_to": rel,
		"warning_sec": warn, "rotations": _parse_rotations(d.get("rotations", [0]), errors, "followup.rotations"),
		"effects": _normalize_effects(d.get("effects", {}), errors, "followup.effects"),
		"show_with_first": bool(d.get("show_with_first", false)),
		"requires_anchor": maxi(int(d.get("requires_anchor", 0)), 0),
	}


func _normalize_effects(raw: Variant, errors: Array[String], where: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append(where + " must be an object")
		return {}
	var d: Dictionary = raw as Dictionary
	var out: Dictionary = {"damage": maxf(float(d.get("damage", 0.0)), 0.0)}
	if typeof(d.get("status")) == TYPE_DICTIONARY:
		var st: Dictionary = d["status"] as Dictionary
		var sid: String = str(st.get("id", ""))
		if not STATUS_IDS.has(sid):
			errors.append("%s.status id '%s' unknown (known: %s)" % [where, sid, ", ".join(STATUS_IDS)])
		var base: Dictionary = statuses.get(sid, {}) as Dictionary
		out["status"] = {
			"id": sid, "sec": float(st.get("sec", base.get("sec", 0.0))), "stacks": int(st.get("stacks", base.get("stacks", 1))),
			"step_mult": float(st.get("step_mult", base.get("step_mult", 1.0))),
			"first_cell_only": bool(st.get("first_cell_only", false)),
		}
	if typeof(d.get("zone")) == TYPE_DICTIONARY:
		var z: Dictionary = d["zone"] as Dictionary
		if not ZONE_IDS.has(str(z.get("id", ""))):
			errors.append("%s.zone id '%s' unknown (known: %s)" % [where, str(z.get("id", "")), ", ".join(ZONE_IDS)])
		out["zone"] = z.duplicate(true)
	if typeof(d.get("guard")) == TYPE_DICTIONARY:
		var g: Dictionary = d["guard"] as Dictionary
		out["guard"] = {
			"amount": float(g.get("amount", statuses["guard"]["amount"])), "sec": float(g.get("sec", statuses["guard"]["sec"])),
			"while_markers": bool(g.get("while_markers", false)),
		}
	if typeof(d.get("marker")) == TYPE_DICTIONARY:
		var m: Dictionary = d["marker"] as Dictionary
		out["marker"] = {
			"life_sec": float(m.get("life_sec", defaults["marker_life_sec"])),
			"break_min_cells": maxi(int(m.get("break_min_cells", defaults["marker_break_min_cells"])), 1),
		}
	return out


func _normalize_enemy(id: String, raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("enemy %s: must be an object, refused" % id)
		return {}
	var d: Dictionary = raw as Dictionary
	var enemy_ai: Dictionary = ai.duplicate(true)
	if typeof(d.get("ai")) == TYPE_DICTIONARY:
		enemy_ai = _merge_numbers(ai, d["ai"], "enemy %s ai" % id, problems)
	var raw_phases: Array = []
	if typeof(d.get("phases")) == TYPE_ARRAY:
		raw_phases = d["phases"] as Array
	elif typeof(d.get("skills")) == TYPE_ARRAY:
		raw_phases = [{"id": "main", "enter_hp_ratio": 1.0, "skills": d["skills"]}]
	var phases: Array[Dictionary] = []
	var last_ratio: float = 1.0 + _EPS
	for i: int in raw_phases.size():
		if typeof(raw_phases[i]) != TYPE_DICTIONARY:
			problems.append("enemy %s: phase %d must be an object, refused" % [id, i])
			continue
		var p: Dictionary = raw_phases[i] as Dictionary
		var pid: String = str(p.get("id", "p%d" % (i + 1)))
		var ratio: float = 1.0 if phases.is_empty() else float(p.get("enter_hp_ratio", 0.0))
		if not phases.is_empty() and (ratio <= 0.0 or ratio >= last_ratio):
			problems.append("enemy %s: phase %s enter_hp_ratio %.2f must be > 0 and below the previous phase, refused" % [id, pid, ratio])
			continue
		last_ratio = ratio
		var ids: Array[String] = []
		for sid: Variant in (p["skills"] as Array if typeof(p.get("skills")) == TYPE_ARRAY else []):
			if skills.has(str(sid)):
				ids.append(str(sid))
			else:
				problems.append("enemy %s phase %s: skill '%s' unknown or refused, dropped" % [id, pid, str(sid)])
		var transition: Dictionary = (p["transition"] as Dictionary).duplicate(true) if typeof(p.get("transition")) == TYPE_DICTIONARY else {}
		transition["sec"] = maxf(float(transition.get("sec", defaults["phase_transition_sec"])), 0.0)
		var on_enter: Array[String] = []
		for entry: Variant in (transition["on_enter"] as Array if typeof(transition.get("on_enter")) == TYPE_ARRAY else []):
			var sid2: String = str((entry as Dictionary).get("skill", "")) if typeof(entry) == TYPE_DICTIONARY else str(entry)
			if skills.has(sid2):
				on_enter.append(sid2)
			else:
				problems.append("enemy %s phase %s: on_enter skill '%s' unknown, dropped" % [id, pid, sid2])
		transition["on_enter"] = on_enter
		var every: Dictionary = {}
		if typeof(p.get("every_nth")) == TYPE_DICTIONARY:
			var raw_every: Dictionary = p["every_nth"] as Dictionary
			every = {"skill": str(raw_every.get("skill", "")), "n": int(raw_every.get("n", 0))}
			if not ids.has(str(every["skill"])) or int(every["n"]) < 1:
				problems.append("enemy %s phase %s: every_nth needs a skill of the phase and n >= 1, ignored" % [id, pid])
				every = {}
		phases.append({
			"id": pid, "enter_hp_ratio": ratio, "skills": ids, "mechanic": str(p.get("mechanic", "")),
			"every_nth": every, "transition": transition,
			"overrides": (p["overrides"] as Dictionary).duplicate(true) if typeof(p.get("overrides")) == TYPE_DICTIONARY else {},
			"traits": (p["traits"] as Array).duplicate(true) if typeof(p.get("traits")) == TYPE_ARRAY else [],
		})
	if phases.is_empty():
		problems.append("enemy %s: no usable phase, refused" % id)
		return {}
	# `dev: true` = a dev / test fixture enemy (the --pattern= capture, integration tests); never named by a chapters.json match.
	return {"id": id, "tier": str(d.get("tier", "normal")), "ai": enemy_ai, "phases": phases, "dev": bool(d.get("dev", false))}


static func _merge_numbers(base: Dictionary, raw: Variant, where: String, out_problems: Array[String]) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	if raw == null:
		return out
	if typeof(raw) != TYPE_DICTIONARY:
		out_problems.append(where + " must be an object, defaults used")
		return out
	for key: Variant in (raw as Dictionary):
		var value: Variant = (raw as Dictionary)[key]
		if not base.has(key):
			out_problems.append("%s.%s unknown, ignored" % [where, str(key)])
		elif typeof(base[key]) == TYPE_BOOL:
			out[key] = bool(value)
		elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			out[key] = value
		else:
			out_problems.append("%s.%s must be a number, default kept" % [where, str(key)])
	return out


static func _parse_offsets(raw: Variant, errors: Array[String], where: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
		errors.append(where + " must be a non-empty list of [dc, dr]")
		return out
	for item: Variant in (raw as Array):
		if typeof(item) != TYPE_ARRAY or (item as Array).size() != 2:
			errors.append(where + " entry %s is not [dc, dr]" % str(item))
			continue
		var cell: Vector2i = Vector2i(int((item as Array)[0]), int((item as Array)[1]))
		if not out.has(cell):
			out.append(cell)
	return out


static func _parse_rotations(raw: Variant, errors: Array[String], where: String) -> Array[int]:
	var out: Array[int] = []
	if typeof(raw) != TYPE_ARRAY:
		errors.append(where + " must be a list")
		out.append(0)
		return out
	for r: Variant in (raw as Array):
		if not ROTATIONS.has(int(r)):
			errors.append("%s: %s not in 0/90/180/270" % [where, str(r)])
		elif not out.has(int(r)):
			out.append(int(r))
	if out.is_empty():
		out.append(0)
	return out

class_name SkillConfig
extends RefCounted
## Skill definitions and skill-menu timing from assets/data/skills.json.
## Schema: assets/data/schema.md. Implements: Story 008 (skills data; burn/pin: Story 010).

const DEFAULT_PATH: String = "res://assets/data/skills.json"
## Skill id used when nothing else is chosen; always present in [member skills].
const FALLBACK_SKILL: String = "slash"

## Simulation speed factor while the skill menu is open (0..1). Applied by the view.
var menu_time_scale: float = 0.2
## REAL seconds the player has to choose before the default skill is auto-picked.
var menu_choose_sec: float = 3.0
var default_skill: String = FALLBACK_SKILL
## Focus: simulation speed factor while active (0 = full stop, 0..1).
var focus_time_scale: float = 0.0
## Focus: max REAL seconds one Focus lasts (> 0).
var focus_max_sec: float = 4.0
## Focus: REAL seconds before it can start again (>= 0).
var focus_cooldown_sec: float = 8.0
## Focus: true = the player cannot step while Focus is active.
var focus_locks_movement: bool = true
## Stable menu order of skill ids.
var skill_order: Array[String] = [FALLBACK_SKILL]
## id -> {display_name: String, min_cells: int, cooldown_sec: float,
## damage_multiplier: float, push_cells: int, implemented: bool}
var skills: Dictionary = {}


func _init() -> void:
	skills[FALLBACK_SKILL] = {
		"effect": "damage", "burn_duration_sec": 0.0, "burn_tick_sec": 0.5,
		"burn_damage_per_tick": 0.0, "pin_duration_sec": 0.0,
		"display_name": "Slash", "min_cells": 1, "cooldown_sec": 0.0,
		"damage_multiplier": 1.0, "push_cells": 0, "implemented": true,
	}


## Loads from a JSON file. Never null: a missing or bad file gives defaults (warning).
static func load_from_file(path: String = DEFAULT_PATH) -> SkillConfig:
	if not FileAccess.file_exists(path):
		push_warning("SkillConfig: file not found: %s, using defaults" % path)
		return SkillConfig.new()
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Never null (defaults + warning if invalid).
static func from_json_text(text: String) -> SkillConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SkillConfig: JSON root must be an object, using defaults")
		return SkillConfig.new()
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults, values are clamped.
static func from_dictionary(data: Dictionary) -> SkillConfig:
	var config := SkillConfig.new()
	config.menu_time_scale = clampf(float(data.get("menu_time_scale", config.menu_time_scale)), 0.0, 1.0)
	config.menu_choose_sec = maxf(float(data.get("menu_choose_sec", config.menu_choose_sec)), 0.0)
	config._read_focus(data.get("focus"))
	var raw_skills: Variant = data.get("skills")
	if typeof(raw_skills) == TYPE_DICTIONARY and not (raw_skills as Dictionary).is_empty():
		config.skills.clear()
		for id: Variant in (raw_skills as Dictionary).keys():
			var raw: Variant = (raw_skills as Dictionary)[id]
			if typeof(raw) != TYPE_DICTIONARY:
				push_warning("SkillConfig: skill %s is not an object, ignored" % str(id))
				continue
			config.skills[str(id)] = _normalize(str(id), raw as Dictionary)
	else:
		push_warning("SkillConfig: no skills in data, using the built-in slash only")
	config.skill_order = []
	var raw_order: Variant = data.get("skill_order")
	if typeof(raw_order) == TYPE_ARRAY:
		for id: Variant in raw_order as Array:
			if config.skills.has(str(id)) and not config.skill_order.has(str(id)):
				config.skill_order.append(str(id))
	for id: Variant in config.skills.keys():
		if not config.skill_order.has(str(id)):
			config.skill_order.append(str(id))
	var wanted: String = str(data.get("default_skill", FALLBACK_SKILL))
	if config.skills.has(wanted):
		config.default_skill = wanted
	else:
		push_warning("SkillConfig: default_skill %s unknown, using the first skill" % wanted)
		config.default_skill = config.skill_order[0] if not config.skill_order.is_empty() else FALLBACK_SKILL
	return config


## True if [param id] is a defined skill.
func has_skill(id: String) -> bool:
	return skills.has(id)


## The definition of [param id] (see [member skills]); empty dictionary if unknown.
func get_skill(id: String) -> Dictionary:
	if skills.has(id):
		return skills[id] as Dictionary
	return {}


# Parses the optional "focus" object; bad or missing values keep the defaults (warning if bad).
func _read_focus(raw: Variant) -> void:
	if raw == null:
		return
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("SkillConfig: focus must be an object, using defaults")
		return
	var focus: Dictionary = raw as Dictionary
	focus_time_scale = _number(focus, "focus_time_scale", focus_time_scale, 0.0, 1.0, true)
	focus_max_sec = _number(focus, "focus_max_sec", focus_max_sec, 0.0, INF, false)
	focus_cooldown_sec = _number(focus, "focus_cooldown_sec", focus_cooldown_sec, 0.0, INF, true)
	if focus.has("focus_locks_movement"):
		if typeof(focus["focus_locks_movement"]) == TYPE_BOOL:
			focus_locks_movement = bool(focus["focus_locks_movement"])
		else:
			push_warning("SkillConfig: focus_locks_movement must be true/false, using default")


# A numeric focus value: non-number => default (warning); clamped to [low, high]; when
# [param allow_low] is false the value must be > low, otherwise the default is used (warning).
static func _number(d: Dictionary, key: String, fallback: float, low: float, high: float, allow_low: bool) -> float:
	if not d.has(key):
		return fallback
	var v: Variant = d[key]
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		push_warning("SkillConfig: %s must be a number, using %s" % [key, fallback])
		return fallback
	var value: float = float(v)
	if is_nan(value) or value < low or (not allow_low and value <= low):
		push_warning("SkillConfig: %s is out of range, using %s" % [key, fallback])
		return fallback
	return clampf(value, low, high)


static func _normalize(id: String, raw: Dictionary) -> Dictionary:
	var tick: float = float(raw.get("burn_tick_sec", 0.5))
	if tick <= 0.0:
		push_warning("SkillConfig: skill %s burn_tick_sec must be > 0, using 0.5" % id)
		tick = 0.5
	return {
		"effect": str(raw.get("effect", "damage")),
		"burn_duration_sec": maxf(float(raw.get("burn_duration_sec", 0.0)), 0.0),
		"burn_tick_sec": tick,
		"burn_damage_per_tick": maxf(float(raw.get("burn_damage_per_tick", 0.0)), 0.0),
		"pin_duration_sec": maxf(float(raw.get("pin_duration_sec", 0.0)), 0.0),
		"display_name": str(raw.get("display_name", id)),
		"min_cells": maxi(int(raw.get("min_cells", 1)), 1),
		"cooldown_sec": maxf(float(raw.get("cooldown_sec", 0.0)), 0.0),
		"damage_multiplier": maxf(float(raw.get("damage_multiplier", 1.0)), 0.0),
		"push_cells": maxi(int(raw.get("push_cells", 0)), 0),
		"implemented": bool(raw.get("implemented", false)),
	}

class_name BossBrainConfig
extends RefCounted
## Boss brain numbers and named weight sets from assets/data/boss_brain.json.
## Schema: assets/data/schema.md. Implements: Story 009.

const DEFAULT_PATH: String = "res://assets/data/boss_brain.json"
## Set used when [member active_set] is unknown; always present in [member sets].
const DEFAULT_SET: String = "balanced"
## Weight keys starting with this prefix (followed by a skill id) are accepted too.
const SKILL_BONUS_PREFIX: String = "skill_bonus_"
## Every known weight with its default (flags are 0.0 / 1.0). Missing keys in a set use these.
const DEFAULT_WEIGHTS: Dictionary = {
	"cut_hit_now": 3.0,
	"cut_per_cell": 1.0,
	"cut_duration_penalty": 0.8,
	"cut_interrupt_bonus": 4.0,
	"cut_point_cost": 0.4,
	"cut_hand_wait": 1.5,
	"hand_target": 3.0,
	"min_cut_score": 3.0,
	"skill_bonus_push": 1.0,
	"dodge_danger": 2.0,
	"pickup_value": 2.0,
	"pickup_danger_penalty": 2.0,
	"pickup_full_hand_zero": 1.0,
	"idle_bias": 0.2,
	"retreat_hp_ratio": 0.3,
	"retreat_bonus": 1.0,
}

## Seconds between accepted boss steps.
var step_cooldown_sec: float = 0.55
## Seconds between brain evaluations.
var think_interval_sec: float = 0.3
## Seconds the player's swing must have been visible before the brain reacts to it.
var reaction_sec: float = 0.35
## Amplitude of the uniform score noise.
var noise: float = 0.15
## Name of the weight set in use.
var active_set: String = DEFAULT_SET
## set name -> {weight key -> float}.
var sets: Dictionary = {}


func _init() -> void:
	sets[DEFAULT_SET] = DEFAULT_WEIGHTS.duplicate()


## Loads from a JSON file. Never null: a missing or bad file gives defaults (warning).
static func load_from_file(path: String = DEFAULT_PATH) -> BossBrainConfig:
	if not FileAccess.file_exists(path):
		push_warning("BossBrainConfig: file not found: %s, using defaults" % path)
		return BossBrainConfig.new()
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Never null (defaults + warning if invalid).
static func from_json_text(text: String) -> BossBrainConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("BossBrainConfig: JSON root must be an object, using defaults")
		return BossBrainConfig.new()
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults, values are clamped.
static func from_dictionary(data: Dictionary) -> BossBrainConfig:
	var config := BossBrainConfig.new()
	config.step_cooldown_sec = maxf(float(data.get("step_cooldown_sec", config.step_cooldown_sec)), 0.0)
	config.think_interval_sec = maxf(float(data.get("think_interval_sec", config.think_interval_sec)), 0.0)
	config.reaction_sec = maxf(float(data.get("reaction_sec", config.reaction_sec)), 0.0)
	config.noise = maxf(float(data.get("noise", config.noise)), 0.0)
	var raw_sets: Variant = data.get("sets")
	if typeof(raw_sets) == TYPE_DICTIONARY and not (raw_sets as Dictionary).is_empty():
		var parsed_sets: Dictionary = {}
		for set_name: Variant in (raw_sets as Dictionary).keys():
			var raw: Variant = (raw_sets as Dictionary)[set_name]
			if typeof(raw) != TYPE_DICTIONARY:
				push_warning("BossBrainConfig: set %s is not an object, ignored" % str(set_name))
				continue
			parsed_sets[str(set_name)] = _normalize_set(str(set_name), raw as Dictionary)
		if not parsed_sets.is_empty():
			config.sets = parsed_sets
	else:
		push_warning("BossBrainConfig: no sets in data, using the built-in balanced set")
	var wanted: String = str(data.get("active_set", DEFAULT_SET))
	if config.sets.has(wanted):
		config.active_set = wanted
	else:
		push_warning("BossBrainConfig: active_set %s unknown, using the first set" % wanted)
		config.active_set = str(config.sets.keys()[0])
	return config


## True if a weight set called [param set_name] exists.
func has_set(set_name: String) -> bool:
	return sets.has(set_name)


## Names of all weight sets, in file order.
func set_names() -> Array[String]:
	var names: Array[String] = []
	for set_name: Variant in sets.keys():
		names.append(str(set_name))
	return names


## Copy of the weights of [param set_name]; "" or an unknown name gives the active set.
func weights_for(set_name: String = "") -> Dictionary:
	if sets.has(set_name):
		return (sets[set_name] as Dictionary).duplicate()
	if sets.has(active_set):
		return (sets[active_set] as Dictionary).duplicate()
	return DEFAULT_WEIGHTS.duplicate()


static func _normalize_set(set_name: String, raw: Dictionary) -> Dictionary:
	var weights: Dictionary = DEFAULT_WEIGHTS.duplicate()
	for key: Variant in raw.keys():
		var key_text: String = str(key)
		if not DEFAULT_WEIGHTS.has(key_text) and not key_text.begins_with(SKILL_BONUS_PREFIX):
			push_warning("BossBrainConfig: set %s has unknown weight %s, ignored" % [set_name, key_text])
			continue
		var value: Variant = raw[key]
		if typeof(value) == TYPE_BOOL:
			weights[key_text] = 1.0 if bool(value) else 0.0
		else:
			weights[key_text] = maxf(float(value), 0.0)
	weights["hand_target"] = clampf(roundf(float(weights["hand_target"])), 1.0, 4.0)
	weights["retreat_hp_ratio"] = clampf(float(weights["retreat_hp_ratio"]), 0.0, 1.0)
	weights["pickup_full_hand_zero"] = 1.0 if float(weights["pickup_full_hand_zero"]) >= 0.5 else 0.0
	return weights

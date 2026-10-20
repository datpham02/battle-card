class_name BossBrainConfig
extends RefCounted
## Boss brain numbers and named weight sets from assets/data/boss_brain.json.
## Each set also carries a `movement` profile (Story 013): target commitment, movement noise,
## per-set reaction time, path style, juke chance and idle wandering.
## Schema: assets/data/schema.md. Implements: Story 009, Story 013.

const DEFAULT_PATH: String = "res://assets/data/boss_brain.json"
## Set used when [member active_set] is unknown; always present in [member sets].
const DEFAULT_SET: String = "balanced"
## Weight keys starting with this prefix (followed by a skill id) are accepted too.
const SKILL_BONUS_PREFIX: String = "skill_bonus_"
## Every known weight with its default (flags are 0.0 / 1.0). Missing keys in a set use these.
const DEFAULT_WEIGHTS: Dictionary = {
	"cut_hit_now": 1.5,
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
	"skill_bonus_burn": 1.0,
	"skill_bonus_pin": 1.0,
	"burn_avoid": 3.0,
	"escape_penalty": 4.0,
	"combo_chance": 0.25,
	"combo_gap_sec": 0.5,
}
## Learning rules (see BossLearning) with defaults; the `learning` section of the file overrides.
const DEFAULT_LEARNING: Dictionary = {
	"dodge_streak_threshold": 3,
	"feint_chance_base": 0.15,
	"feint_chance_per_dodge": 0.1,
	"feint_chance_max": 0.5,
	"feint_cancel_fraction": 0.5,
	"full_hand_seconds": 4.0,
	"quick_cut_bias": 2.0,
	"interrupt_count_threshold": 2,
	"single_point_bonus": 2.0,
}
## Allowed `path_style` values of a movement profile.
const PATH_STYLES: Array[String] = ["row_first", "shortest", "mixed"]
## Movement profile keys with their defaults (the `movement` block of a set). `reaction_sec` is
## deliberately absent: a set without it uses the file-level [member reaction_sec].
const DEFAULT_MOVEMENT: Dictionary = {
	"move_commitment": 0.7,
	"move_noise": 0.15,
	"path_style": "shortest",
	"juke_chance": 0.2,
	"wander_when_idle": true,
}
## Movement profile key holding the per-set reaction time (optional).
const MOVEMENT_REACTION_KEY: String = "reaction_sec"
## Key of a set that holds its movement profile (not a weight).
const MOVEMENT_KEY: String = "movement"

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
## set name -> movement profile ([constant DEFAULT_MOVEMENT] keys, plus `reaction_sec` when set).
var movement: Dictionary = {}
## Learning rules (keys of [constant DEFAULT_LEARNING]).
var learning: Dictionary = DEFAULT_LEARNING.duplicate()


func _init() -> void:
	sets[DEFAULT_SET] = DEFAULT_WEIGHTS.duplicate()
	movement[DEFAULT_SET] = DEFAULT_MOVEMENT.duplicate()


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
	var raw_learning: Variant = data.get("learning")
	if typeof(raw_learning) == TYPE_DICTIONARY:
		for key: Variant in DEFAULT_LEARNING.keys():
			if (raw_learning as Dictionary).has(key):
				config.learning[key] = _clean_learning(str(key), float((raw_learning as Dictionary)[key]))
	var raw_sets: Variant = data.get("sets")
	if typeof(raw_sets) == TYPE_DICTIONARY and not (raw_sets as Dictionary).is_empty():
		var parsed_sets: Dictionary = {}
		var parsed_movement: Dictionary = {}
		for set_name: Variant in (raw_sets as Dictionary).keys():
			var raw: Variant = (raw_sets as Dictionary)[set_name]
			if typeof(raw) != TYPE_DICTIONARY:
				push_warning("BossBrainConfig: set %s is not an object, ignored" % str(set_name))
				continue
			parsed_sets[str(set_name)] = _normalize_set(str(set_name), raw as Dictionary)
			parsed_movement[str(set_name)] = _normalize_movement(str(set_name), (raw as Dictionary).get(MOVEMENT_KEY))
		if not parsed_sets.is_empty():
			config.sets = parsed_sets
			config.movement = parsed_movement
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


## Copy of the movement profile of [param set_name]; "" or an unknown name gives the active set.
## Always has every [constant DEFAULT_MOVEMENT] key; `reaction_sec` only when the set has one.
func movement_for(set_name: String = "") -> Dictionary:
	if movement.has(set_name):
		return (movement[set_name] as Dictionary).duplicate()
	if movement.has(active_set):
		return (movement[active_set] as Dictionary).duplicate()
	return DEFAULT_MOVEMENT.duplicate()


## Reaction time of [param set_name]: its movement profile's `reaction_sec` when present, else
## the file-level [member reaction_sec].
func reaction_sec_for(set_name: String = "") -> float:
	var profile: Dictionary = movement_for(set_name)
	if profile.has(MOVEMENT_REACTION_KEY):
		return float(profile[MOVEMENT_REACTION_KEY])
	return reaction_sec


## Merges [param override] (movement keys, validated like the file) over the profile of
## [param set_name]. Unknown set or keys: warning, those parts are ignored. Returns true when
## the set exists.
func override_movement(set_name: String, override: Dictionary) -> bool:
	if not sets.has(set_name):
		push_warning("BossBrainConfig: cannot override movement of unknown set %s" % set_name)
		return false
	var profile: Dictionary = movement_for(set_name)
	var cleaned: Dictionary = _normalize_movement(set_name, override)
	for key: Variant in override.keys():
		if cleaned.has(key):
			profile[key] = cleaned[key]
	movement[set_name] = profile
	return true


## Overrides one weight of [param set_name] (validated like the file: `combo_chance` is clamped
## to 0..1, `combo_gap_sec` to >= 0). Unknown set or weight key: warning, ignored. Returns true
## when applied.
func override_weight(set_name: String, key: String, value: float) -> bool:
	if not sets.has(set_name) or not DEFAULT_WEIGHTS.has(key):
		push_warning("BossBrainConfig: cannot override weight %s of set %s" % [key, set_name])
		return false
	var weights: Dictionary = sets[set_name] as Dictionary
	if key == "combo_chance":
		weights[key] = clampf(value, 0.0, 1.0)
	else:
		weights[key] = maxf(value, 0.0)
	return true


static func _normalize_movement(set_name: String, raw: Variant) -> Dictionary:
	var profile: Dictionary = DEFAULT_MOVEMENT.duplicate()
	if raw == null:
		return profile
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("BossBrainConfig: movement of set %s is not an object, using defaults" % set_name)
		return profile
	for key: Variant in (raw as Dictionary).keys():
		var key_text: String = str(key)
		var value: Variant = (raw as Dictionary)[key]
		if key_text == MOVEMENT_REACTION_KEY:
			profile[key_text] = maxf(float(value), 0.0)
		elif not DEFAULT_MOVEMENT.has(key_text):
			push_warning("BossBrainConfig: set %s has unknown movement key %s, ignored" % [set_name, key_text])
		else:
			profile[key_text] = _clean_movement_value(set_name, key_text, value)
	return profile


static func _clean_movement_value(set_name: String, key: String, value: Variant) -> Variant:
	if key == "path_style":
		var style: String = str(value)
		if PATH_STYLES.has(style):
			return style
		push_warning("BossBrainConfig: set %s has unknown path_style %s, using %s" % [set_name, style, DEFAULT_MOVEMENT[key]])
		return DEFAULT_MOVEMENT[key]
	if key == "wander_when_idle":
		if typeof(value) == TYPE_BOOL:
			return bool(value)
		return float(value) >= 0.5
	if key == "move_commitment" or key == "juke_chance":
		return clampf(float(value), 0.0, 1.0)
	return maxf(float(value), 0.0)


static func _clean_learning(key: String, value: float) -> Variant:
	if key == "dodge_streak_threshold" or key == "interrupt_count_threshold":
		return maxi(roundi(value), 1)
	if key == "feint_chance_base" or key == "feint_chance_max" or key == "feint_cancel_fraction":
		return clampf(value, 0.0, 1.0)
	if key == "quick_cut_bias":
		return maxf(value, 1.0)
	return maxf(value, 0.0)


static func _normalize_set(set_name: String, raw: Dictionary) -> Dictionary:
	var weights: Dictionary = DEFAULT_WEIGHTS.duplicate()
	for key: Variant in raw.keys():
		var key_text: String = str(key)
		if key_text == MOVEMENT_KEY:
			continue
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
	weights["combo_chance"] = clampf(float(weights["combo_chance"]), 0.0, 1.0)
	weights["combo_gap_sec"] = maxf(float(weights["combo_gap_sec"]), 0.0)
	weights["pickup_full_hand_zero"] = 1.0 if float(weights["pickup_full_hand_zero"]) >= 0.5 else 0.0
	return weights

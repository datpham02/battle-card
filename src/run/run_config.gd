class_name RunConfig
extends RefCounted
## One run = ONE floor: ordered matches (the last one is the boss match), HP carried between
## matches and the timings of the run flow. Built from a resolved floor of chapters.json with
## [method from_floor] (Story 015), or from the flat single-floor format with
## [method from_dictionary] / [method load_from_file] (used by tests and ad-hoc floors).
## Schema: assets/data/schema.md. Implements: Story 011, Story 015.

## Keys every match entry carries after validation (a deprecated absolute
## `boss_step_cooldown_sec` is carried too, but only when the data had it).
const MATCH_KEYS: Array[String] = [
	"id", "display_name", "boss_max_hp", "brain_set", "boss_step_cooldown_mult",
	"boss_think_interval_sec", "boss_reaction_sec", "boss_drop_interval_mult", "movement",
	"swing_speed_mult", "combo_chance", "combo_gap_sec", "arena", "arena_seed", "traits",
]

## Keys of the flow numbers shared by chapters.json `defaults` and a floor's overrides.
const TIMING_KEYS: Array[String] = [
	"heal_between_matches", "intro_sec", "end_delay_sec", "between_sec", "retry_min_hp_ratio",
]

## Flat HP the player recovers after winning a match (clamped to max HP by RunState).
var heal_between_matches: float = 25.0
## Seconds of real time the intro of each match lasts (battle frozen).
var intro_sec: float = 1.5
## Seconds of real time between the last hit and leaving the match.
var end_delay_sec: float = 1.5
## Seconds before the between-matches screen advances alone (0 = wait for the button).
var between_sec: float = 3.0
## Share of the player's max HP a retried or resumed match starts with at least (0..1).
var retry_min_hp_ratio: float = 0.5
## Ordered matches (at least 1); the last is the boss match. Each: see [constant MATCH_KEYS].
var matches: Array[Dictionary] = []


func _init() -> void:
	matches.append(_default_match(0))


## Loads a flat single-floor JSON file (used by tests and ad-hoc floors). Never null: an empty
## path, a missing or bad file gives defaults (warning).
static func load_from_file(path: String = "") -> RunConfig:
	if not FileAccess.file_exists(path):
		push_warning("RunConfig: file not found, using defaults: %s" % path)
		return RunConfig.new()
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Never null (defaults + warning if invalid).
static func from_json_text(text: String) -> RunConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("RunConfig: JSON root must be an object, using defaults")
		return RunConfig.new()
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults, nonsense is clamped.
static func from_dictionary(data: Dictionary) -> RunConfig:
	var c := RunConfig.new()
	c._apply_timings(data)
	var raw: Variant = data.get("matches")
	if typeof(raw) == TYPE_ARRAY:
		var parsed: Array[Dictionary] = []
		for entry: Variant in raw as Array:
			if typeof(entry) != TYPE_DICTIONARY:
				push_warning("RunConfig: a match entry is not an object, ignored")
				continue
			parsed.append(_clean_match(entry as Dictionary, parsed.size()))
		if not parsed.is_empty():
			c.matches = parsed
			return c
	push_warning("RunConfig: no valid matches, using one default match")
	return c


## Builds the config of one floor from [method ChaptersConfig.resolved_floor] (arena and
## arena_seed already filled per match). [param defaults] is [method ChaptersConfig.defaults];
## the floor's own optional `overrides` (or top-level keys) of those numbers win over it.
static func from_floor(resolved_floor: Dictionary, defaults: Dictionary) -> RunConfig:
	var data: Dictionary = defaults.duplicate()
	var overrides: Variant = resolved_floor.get("overrides", {})
	if typeof(overrides) == TYPE_DICTIONARY:
		data.merge(overrides as Dictionary, true)
	for key: String in TIMING_KEYS:
		if resolved_floor.has(key):
			data[key] = resolved_floor[key]
	data["matches"] = resolved_floor.get("matches", [])
	return from_dictionary(data)


## Number of matches (>= 1).
func match_count() -> int:
	return matches.size()


func _apply_timings(data: Dictionary) -> void:
	heal_between_matches = maxf(float(data.get("heal_between_matches", heal_between_matches)), 0.0)
	intro_sec = maxf(float(data.get("intro_sec", intro_sec)), 0.0)
	end_delay_sec = maxf(float(data.get("end_delay_sec", end_delay_sec)), 0.0)
	between_sec = maxf(float(data.get("between_sec", between_sec)), 0.0)
	retry_min_hp_ratio = clampf(float(data.get("retry_min_hp_ratio", retry_min_hp_ratio)), 0.0, 1.0)


static func _default_match(index: int) -> Dictionary:
	return {
		"id": "match_%d" % (index + 1), "display_name": "Match %d" % (index + 1), "boss_max_hp": 100.0,
		"brain_set": "balanced", "boss_step_cooldown_mult": 1.0, "boss_think_interval_sec": 0.3,
		"boss_reaction_sec": 0.35, "boss_drop_interval_mult": 1.0, "movement": {},
		"swing_speed_mult": 1.0, "combo_chance": -1.0, "combo_gap_sec": -1.0, "arena": {}, "arena_seed": -1, "traits": [],
	}


static func _clean_match(raw: Dictionary, index: int) -> Dictionary:
	var m: Dictionary = _default_match(index)
	m["id"] = str(raw.get("id", m["id"]))
	m["display_name"] = str(raw.get("display_name", m["display_name"]))
	m["brain_set"] = str(raw.get("brain_set", m["brain_set"]))
	m["boss_max_hp"] = _positive(raw, "boss_max_hp", float(m["boss_max_hp"]))
	m["boss_drop_interval_mult"] = _positive(raw, "boss_drop_interval_mult", float(m["boss_drop_interval_mult"]))
	m["boss_step_cooldown_mult"] = _positive(raw, "boss_step_cooldown_mult", float(m["boss_step_cooldown_mult"]))
	m["swing_speed_mult"] = _positive(raw, "swing_speed_mult", float(m["swing_speed_mult"]))
	# combo_chance / combo_gap_sec: negative (default) = keep the brain set's own value.
	if raw.has("combo_chance"):
		m["combo_chance"] = clampf(float(raw["combo_chance"]), 0.0, 1.0)
	if raw.has("combo_gap_sec"):
		m["combo_gap_sec"] = maxf(float(raw["combo_gap_sec"]), 0.0)
	for key: String in ["boss_think_interval_sec", "boss_reaction_sec"]:
		m[key] = maxf(float(raw.get(key, m[key])), 0.0)
	var raw_movement: Variant = raw.get("movement", {})
	if typeof(raw_movement) == TYPE_DICTIONARY:
		# Passed through as-is; BossBrainConfig.override_movement validates the keys.
		m["movement"] = (raw_movement as Dictionary).duplicate()
	else:
		push_warning("RunConfig: movement of match %s must be an object, ignored" % m["id"])
	var raw_arena: Variant = raw.get("arena", {})
	if typeof(raw_arena) == TYPE_DICTIONARY:
		# Passed through as-is; ArenaLibrary.grid_for_spec validates it (Story 014).
		m["arena"] = (raw_arena as Dictionary).duplicate(true)
	else:
		push_warning("RunConfig: arena of match %s must be an object, ignored" % m["id"])
	# Filled by ChaptersConfig.resolved_floor; negative = no seed (random).
	m["arena_seed"] = int(raw.get("arena_seed", m["arena_seed"]))
	var raw_traits: Variant = raw.get("traits", [])
	if typeof(raw_traits) == TYPE_ARRAY:
		# Passed through as-is; TraitHost / TraitRegistry validate the entries (Story 014).
		m["traits"] = (raw_traits as Array).duplicate(true)
	else:
		push_warning("RunConfig: traits of match %s must be an array, ignored" % m["id"])
	if raw.has("boss_step_cooldown_sec"):
		# Deprecated absolute value: carried (and used by CombatView) only for old data.
		push_warning("RunConfig: boss_step_cooldown_sec is deprecated, use boss_step_cooldown_mult")
		m["boss_step_cooldown_sec"] = maxf(float(raw["boss_step_cooldown_sec"]), 0.0)
	return m


static func _positive(data: Dictionary, key: String, fallback: float) -> float:
	var value: float = float(data.get(key, fallback))
	if value <= 0.0:
		push_warning("RunConfig: %s must be > 0 (got %s), using %s" % [key, value, fallback])
		return fallback
	return value

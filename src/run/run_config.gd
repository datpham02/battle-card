class_name RunConfig
extends RefCounted
## One run config: ordered matches (the last one is the boss match), HP carried between
## matches and the timings of the run flow. Built for one map node of chapters.json with
## [method from_node] (Story 022), or from the flat format with
## [method from_dictionary] / [method load_from_file] (used by tests and ad-hoc runs).
## Schema: assets/data/schema.md. Implements: Story 011, Story 015.

## Keys every match entry carries after validation (a deprecated absolute
## `boss_step_cooldown_sec` is carried too, but only when the data had it).
const MATCH_KEYS: Array[String] = [
	"id", "name_key", "display_name", "boss_max_hp", "brain_set", "boss_step_cooldown_mult",
	"boss_think_interval_sec", "boss_reaction_sec", "boss_drop_interval_mult", "movement",
	"swing_speed_mult", "combo_chance", "combo_gap_sec", "arena", "arena_seed", "traits", "boss_cards", "boss_defense", "boss_min_runes",
	"desc_key", "boss_root_while_swinging",
	"mire_immune", "player_drop_interval_mult", "odd_blocks",
]
## Story 036: combat.json `hazards` keys a match may override (same name in the match; absent = not set in the match dict).
const HAZARD_OVERRIDE_KEYS: Array[String] = [
	"mire_step_mult", "mire_tick_damage", "mire_tick_sec", "mire_grace_sec", "sand_interval_sec",
	"sand_cells", "sand_sec", "sand_warn_sec", "drift_sec", "wind_shift_sec",
	# Story 039: vents and crumbling cells.
	"vent_interval_sec", "vent_warn_sec", "vent_sec", "vent_tick_sec", "vent_tick_damage",
	"crumble_after_sec", "crumble_warn_sec", "fall_sec", "fall_damage",
]
## Phase 2 (design/quick-specs/phase2-misty-forest-2026-11-01.md 3.1): match key `brain` values. Absent = the block
## brain (every match before Phase 2, unchanged); "pattern" = PatternController with `enemy` from enemy_skills.json.
const BRAIN_BLOCK: String = "block"
const BRAIN_PATTERN: String = "pattern"
## Story 035: trait id a match's `phases` key turns into (see [method _apply_phases]).
const BOSS_PHASES_TRAIT_ID: String = "boss_phases"


## Flat HP the player recovers after winning a match (clamped to max HP by RunState).
var heal_between_matches: float = 0.0
## Seconds of real time the intro of each match lasts (battle frozen).
var intro_sec: float = 1.5
## Seconds of real time between the last hit and leaving the match.
var end_delay_sec: float = 1.5
## Seconds before the between-matches screen advances alone (0 = wait for the button).
var between_sec: float = 3.0
## HP the player recovers after a floor's boss (Story 019; used by RunSession, clamped to max HP).
var heal_between_floors: float = 0.0
## Revive tokens a run starts with (Story 019; reserved for the future revive item, unused).
var revive_tokens: int = 0
## Share of the player's max HP a retried or resumed match starts with at least (0..1). Optional
## key; default 0 = no minimum. The Story 019 run flow always passes 0 (kept for the revive item).
var retry_min_hp_ratio: float = 0.0
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


## Builds the single-match config of ONE map node (Story 022): the match [param match_id] of chapter
## [param chapter_index] with its own arena, arena_seed = hash(run_seed, match id) and, for a
## "danger" node, the chapter's extra danger traits. Timings come from the chapters defaults.
## [param chapter_index_or_region] is the chapter index (int) or a region id (String, Story 031).
## [param floor] < 0 (default) = no scaling (old behaviour). With [param floor] >= 0 (0-based run floor; a
## floor >= `world.floors` = the final match, `final` row) the match is scaled at THIS one point, in order:
## the region's `region_normalize`, then `floor_scaling` of the floor: boss_max_hp x hp_mult,
## boss_step_cooldown_mult x step_mult, boss_defense + defense_add (clamped >= 0 after each step) and
## boss_min_runes (the boss's smallest piece, Story 023/025) + size_add (clamped >= 0).
## Story 038: [param kiep_level] (0..10, default 0 = exactly the call without it) picks the scaling row of
## [method KiepRules.scaling_floor] (+ [method KiepRules.final_extra] hp), then [method KiepRules.apply_match] changes the
## raw match (extra boss trait, boss swing speed, the player's drop interval via the match key
## `player_drop_interval_mult`) after the danger traits are added.
## World Map v2 (docs/design/world-map-v2/03 section 8): [param profile] = EncounterComposer.profile(...) of the node;
## its patches (modifiers, the region rule at the current gauge, the warden hook) are applied to the raw match AFTER
## the danger traits and BEFORE Kiep. An empty profile (every v1 node, tests, dev args) leaves the result exactly as
## without the parameter.
static func from_node(chapters: ChaptersConfig, chapter_index_or_region: Variant, match_id: String, node_kind: String,
		run_seed: int, floor: int = -1, kiep_level: int = 0, profile: Dictionary = {}) -> RunConfig:
	var chapter_index: int = -1
	if typeof(chapter_index_or_region) == TYPE_STRING or typeof(chapter_index_or_region) == TYPE_STRING_NAME:
		chapter_index = chapters.region_index(str(chapter_index_or_region))
	else:
		chapter_index = int(chapter_index_or_region)
	var raw: Dictionary = chapters.get_match_raw(chapter_index, match_id)
	if raw.is_empty():
		push_warning("RunConfig: unknown match '%s' in chapter %d, using the default match" % [match_id, chapter_index])
		return from_dictionary(chapters.defaults())
	raw["arena_seed"] = hash([run_seed, match_id]) & ChaptersConfig.SEED_MASK
	if floor >= 0:
		var scaling: Dictionary = chapters.floor_scaling(floor)
		if kiep_level > 0:
			var rules: KiepRules = KiepRules.shared()
			scaling = chapters.floor_scaling(rules.scaling_floor(floor, kiep_level, chapters.world_floors()))
			var extra: Dictionary = rules.final_extra(floor, kiep_level, chapters.world_floors())
			if extra.has("hp_mult"):
				scaling["hp_mult"] = float(scaling.get("hp_mult", 1.0)) * float(extra["hp_mult"])
		_apply_scaling(raw, chapters.region_normalize_at(chapter_index), scaling)
	if node_kind == "danger":
		var traits: Array = (raw.get("traits", []) as Array).duplicate(true)
		for extra: Variant in chapters.danger_traits():
			var known: bool = false
			for have: Variant in traits:
				if typeof(have) == TYPE_DICTIONARY and (have as Dictionary).get("id") == (extra as Dictionary).get("id"):
					known = true
			if not known:
				traits.append(extra)
		raw["traits"] = traits
	if not profile.is_empty():
		EncounterComposer.apply_to_raw(raw, profile)
	if kiep_level > 0:
		raw = KiepRules.shared().apply_match(raw, kiep_level, {"run_seed": run_seed, "floor": floor, "match_id": match_id,
				"node_kind": node_kind, "is_final": floor >= chapters.world_floors()})
	var data: Dictionary = chapters.defaults()
	data["matches"] = [raw]
	return from_dictionary(data)


## Story 031: the one application point of region normalization and floor scaling on a RAW match
## dictionary (see [method from_node]). Absent keys count as the match defaults.
static func _apply_scaling(raw: Dictionary, normalize: Dictionary, scaling: Dictionary) -> void:
	var base: Dictionary = _default_match(0)
	var hp: float = float(raw.get("boss_max_hp", base["boss_max_hp"]))
	var step: float = float(raw.get("boss_step_cooldown_mult", base["boss_step_cooldown_mult"]))
	var defense: float = float(raw.get("boss_defense", base["boss_defense"]))
	var size: int = int(raw.get("boss_min_runes", base["boss_min_runes"]))
	hp *= float(normalize.get("hp_mult", 1.0))
	step *= float(normalize.get("step_mult", 1.0))
	defense = maxf(defense + float(normalize.get("defense_add", 0.0)), 0.0)
	hp *= float(scaling.get("hp_mult", 1.0))
	step *= float(scaling.get("step_mult", 1.0))
	defense = maxf(defense + float(scaling.get("defense_add", 0.0)), 0.0)
	size = maxi(size + int(scaling.get("size_add", 0)), 0)
	raw["boss_max_hp"] = hp
	raw["boss_step_cooldown_mult"] = step
	raw["boss_defense"] = defense
	raw["boss_min_runes"] = size
	if raw.has("boss_step_cooldown_sec"):
		# Deprecated absolute cooldown: scaled the same way so old data keeps its relative pace.
		raw["boss_step_cooldown_sec"] = float(raw["boss_step_cooldown_sec"]) \
				* float(normalize.get("step_mult", 1.0)) * float(scaling.get("step_mult", 1.0))
	if str(raw.get("brain", "")) == BRAIN_PATTERN:
		# Phase 2 spec 3.6: the pattern brain's floor tempo (region x floor step_mult) scales windup / cooldown /
		# recovery, never warning_sec (PatternController.tempo_mult).
		raw["pattern_tempo_mult"] = float(raw.get("pattern_tempo_mult", 1.0)) \
				* float(normalize.get("step_mult", 1.0)) * float(scaling.get("step_mult", 1.0))


## Number of matches (>= 1).
func match_count() -> int:
	return matches.size()


## Player-facing name of a match record (or any match_params dictionary): the translated
## `name_key` when present and non-empty, else the literal `display_name`, else "".
static func match_name(m: Dictionary) -> String:
	var key: String = str(m.get("name_key", ""))
	if not key.is_empty():
		return TranslationServer.translate(key)
	return str(m.get("display_name", ""))


func _apply_timings(data: Dictionary) -> void:
	heal_between_matches = maxf(float(data.get("heal_between_matches", heal_between_matches)), 0.0)
	intro_sec = maxf(float(data.get("intro_sec", intro_sec)), 0.0)
	end_delay_sec = maxf(float(data.get("end_delay_sec", end_delay_sec)), 0.0)
	between_sec = maxf(float(data.get("between_sec", between_sec)), 0.0)
	heal_between_floors = maxf(float(data.get("heal_between_floors", heal_between_floors)), 0.0)
	revive_tokens = maxi(int(data.get("revive_tokens", revive_tokens)), 0)
	retry_min_hp_ratio = clampf(float(data.get("retry_min_hp_ratio", retry_min_hp_ratio)), 0.0, 1.0)


static func _default_match(index: int) -> Dictionary:
	return {
		"id": "match_%d" % (index + 1), "name_key": "", "display_name": "Match %d" % (index + 1), "boss_max_hp": 100.0,
		"brain_set": "balanced", "boss_step_cooldown_mult": 1.0, "boss_think_interval_sec": 0.3,
		"boss_reaction_sec": 0.35, "boss_drop_interval_mult": 1.0, "movement": {},
		"swing_speed_mult": 1.0, "combo_chance": -1.0, "combo_gap_sec": -1.0, "arena": {}, "arena_seed": -1, "traits": [], "boss_cards": [],
		"boss_defense": 0.0, "boss_min_runes": 0, "desc_key": "", "player_drop_interval_mult": 1.0,
	}


## Normalizes one raw match dictionary (see [constant MATCH_KEYS]).
static func clean_match(raw: Dictionary, index: int) -> Dictionary:
	return _clean_match(raw, index)


static func _clean_match(raw: Dictionary, index: int) -> Dictionary:
	var m: Dictionary = _default_match(index)
	m["id"] = str(raw.get("id", m["id"]))
	m["name_key"] = str(raw.get("name_key", ""))
	# Story 023: one-line match description shown in the intro band (translated by the HUD; "" = none).
	m["desc_key"] = str(raw.get("desc_key", ""))
	if raw.has("display_name"):
		# Legacy literal name (flat test configs); shipped data carries name_key only.
		if m["name_key"].is_empty():
			push_warning("RunConfig: match %s uses the legacy display_name; use name_key (Story 017)" % m["id"])
		m["display_name"] = str(raw["display_name"])
	m["brain_set"] = str(raw.get("brain_set", m["brain_set"]))
	m["boss_max_hp"] = _positive(raw, "boss_max_hp", float(m["boss_max_hp"]))
	m["boss_drop_interval_mult"] = _positive(raw, "boss_drop_interval_mult", float(m["boss_drop_interval_mult"]))
	# Story 038: the player's piece drop interval x (Kiep 4; default 1.0, positive; read by CombatView).
	m["player_drop_interval_mult"] = _positive(raw, "player_drop_interval_mult", float(m["player_drop_interval_mult"]))
	m["boss_step_cooldown_mult"] = _positive(raw, "boss_step_cooldown_mult", float(m["boss_step_cooldown_mult"]))
	m["swing_speed_mult"] = _positive(raw, "swing_speed_mult", float(m["swing_speed_mult"]))
	# combo_chance / combo_gap_sec: negative (default) = keep the brain set's own value.
	if raw.has("combo_chance"):
		m["combo_chance"] = clampf(float(raw["combo_chance"]), 0.0, 1.0)
	if raw.has("combo_gap_sec"):
		m["combo_gap_sec"] = maxf(float(raw["combo_gap_sec"]), 0.0)
	# TD-023: per-match override of boss_brain.json root_while_swinging (absent = the brain set's value).
	if raw.has("boss_root_while_swinging"):
		m["boss_root_while_swinging"] = bool(raw["boss_root_while_swinging"])
	# Story 023: flat defense of the boss (>= 0) and the smallest cut the boss brain prefers (>= 0).
	m["boss_defense"] = maxf(float(raw.get("boss_defense", m["boss_defense"])), 0.0)
	m["boss_min_runes"] = maxi(int(raw.get("boss_min_runes", m["boss_min_runes"])), 0)
	for key: String in ["boss_think_interval_sec", "boss_reaction_sec"]:
		m[key] = maxf(float(raw.get(key, m[key])), 0.0)
	# Story 036: the boss ignores mire (absent = not set, the combat default is false) and per-match hazard numbers.
	if raw.has("mire_immune"):
		m["mire_immune"] = bool(raw["mire_immune"])
	for key: String in HAZARD_OVERRIDE_KEYS:
		if raw.has(key):
			m[key] = maxf(float(raw[key]), 0.0)
	# Story 041: per-match odd block override (keys of field_drops.json `odd_blocks`, merged over it by
	# CombatView); absent = not set (the file's block applies).
	if raw.has("odd_blocks"):
		if typeof(raw["odd_blocks"]) == TYPE_DICTIONARY:
			m["odd_blocks"] = (raw["odd_blocks"] as Dictionary).duplicate(true)
		else:
			push_warning("RunConfig: odd_blocks of match %s must be an object, ignored" % m["id"])
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
	# Filled by RunConfig.from_node; negative = no seed (random).
	m["arena_seed"] = int(raw.get("arena_seed", m["arena_seed"]))
	var raw_traits: Variant = raw.get("traits", [])
	if typeof(raw_traits) == TYPE_ARRAY:
		# Passed through as-is; TraitHost / TraitRegistry validate the entries (Story 014).
		m["traits"] = (raw_traits as Array).duplicate(true)
	else:
		push_warning("RunConfig: traits of match %s must be an array, ignored" % m["id"])
	var raw_cards: Variant = raw.get("boss_cards", [])
	if typeof(raw_cards) == TYPE_ARRAY:
		# Card ids the boss may use; [] = the basics. CombatView validates the ids.
		m["boss_cards"] = (raw_cards as Array).duplicate()
	else:
		push_warning("RunConfig: boss_cards of match %s must be an array, ignored" % m["id"])
	if raw.has("phases"):
		_apply_phases(m, raw["phases"])
	if raw.has("boss_step_cooldown_sec"):
		# Deprecated absolute value: carried (and used by CombatView) only for old data.
		push_warning("RunConfig: boss_step_cooldown_sec is deprecated, use boss_step_cooldown_mult")
		m["boss_step_cooldown_sec"] = maxf(float(raw["boss_step_cooldown_sec"]), 0.0)
	_apply_brain(m, raw)
	return m


# Phase 2: `brain` / `enemy` / `pattern_tempo_mult` carried ONLY when the data has `brain` (a match without it keeps
# exactly today's keys). "pattern" without an `enemy` id falls back to the block brain with a warning.
static func _apply_brain(m: Dictionary, raw: Dictionary) -> void:
	if not raw.has("brain"):
		return
	var brain: String = str(raw["brain"])
	if brain != BRAIN_BLOCK and brain != BRAIN_PATTERN:
		push_warning("RunConfig: brain '%s' of match %s is unknown, using the block brain" % [brain, m["id"]])
		brain = BRAIN_BLOCK
	if brain == BRAIN_PATTERN and str(raw.get("enemy", "")).is_empty():
		push_warning("RunConfig: match %s has brain 'pattern' but no enemy, using the block brain" % m["id"])
		brain = BRAIN_BLOCK
	m["brain"] = brain
	if brain == BRAIN_PATTERN:
		m["enemy"] = str(raw["enemy"])
		m["pattern_tempo_mult"] = _positive(raw, "pattern_tempo_mult", 1.0)


## Story 035: a match key `phases` (non-empty array of phase objects, see schema.md) becomes the ONE trait
## `{"id": "boss_phases", "params": {"phases": <the array>}}`, replacing the match's own `traits`,
## `brain_set` (back to the default) and `boss_cards` (back to []): the trait applies each phase's
## values at runtime. A bad `phases` value is ignored with a warning (the match keeps its own keys).
static func _apply_phases(m: Dictionary, raw_phases: Variant) -> void:
	if typeof(raw_phases) != TYPE_ARRAY or (raw_phases as Array).is_empty():
		push_warning("RunConfig: phases of match %s must be a non-empty array, ignored" % m["id"])
		return
	var phases: Array = []
	for entry: Variant in raw_phases as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("RunConfig: a phase of match %s is not an object, phases ignored" % m["id"])
			return
		phases.append((entry as Dictionary).duplicate(true))
	var base: Dictionary = _default_match(0)
	m["traits"] = [{"id": BOSS_PHASES_TRAIT_ID, "params": {"phases": phases}}]
	m["brain_set"] = base["brain_set"]
	m["boss_cards"] = (base["boss_cards"] as Array).duplicate()


static func _positive(data: Dictionary, key: String, fallback: float) -> float:
	var value: float = float(data.get(key, fallback))
	if value <= 0.0:
		push_warning("RunConfig: %s must be > 0 (got %s), using %s" % [key, value, fallback])
		return fallback
	return value

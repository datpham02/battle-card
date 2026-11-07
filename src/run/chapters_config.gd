class_name ChaptersConfig
extends RefCounted
## Chapters from assets/data/chapters.json (v2, Story 022): per chapter a `matches` map, `pools`
## (kind -> tier -> match ids) and a `columns` spec feeding [ChapterMapGen]; use [method generate_map],
## [method get_match_def] and [method RunConfig.from_node]. The v1 `floors` format is still read (its floor
## matches become the chapter's matches); the floor API and `legacy_floors` are gone (Story 026).
## Never null after [method load_from_file]: a bad file gives one default chapter / match.
## Story 031: the chapters double as the REGIONS of a 5-floor run (never call them zones: `zone` is the
## seals / thorns of Story 027). The `world` block (floors, region_pool, region_columns, floor_scaling,
## floor_tiers, floor_heal_ratio, final_match) is read here; see [method world_spec], [method region_spec],
## [method floor_scaling] and [method generate_region_map]. Every `floor` argument of this class is the
## 0-based run floor of RunSession (0..floors-1; `floors` itself = the final match); data rows are keyed by
## the 1-based floor number ("1".."5", "final").
## Schema: assets/data/schema.md. Implements: Story 015, Story 022, Story 031.

const DEFAULT_PATH: String = "res://assets/data/chapters.json"
## Keys of the `defaults` block (and of an optional per-floor override of them).
const DEFAULT_KEYS: Array[String] = [
	"heal_between_matches", "intro_sec", "end_delay_sec", "between_sec", "heal_between_floors",
	"retry_min_hp_ratio",
]
## Keeps arena seeds non-negative (a negative seed means "random" to the arena code).
const SEED_MASK: int = 0x7fffffff
const TEXT_DEFAULT_CHAPTER_NAME: String = "ui.chapter.default_name"
const TEXT_DEFAULT_FLOOR_NAME: String = "ui.floor.default_name"
## Fallbacks used only when chapters.json has no (valid) `world` block; the shipped numbers live in the file.
const DEFAULT_WORLD_FLOORS: int = 5
const DEFAULT_CHOICES_PER_FLOOR: int = 2
const DEFAULT_FLOOR_HEAL_RATIO: float = 0.25
## Story 035 fallbacks of `world.fate` / `world.endings` (mirror the shipped chapters.json).
const DEFAULT_FATE: Dictionary = {"execute_artifact_offers": 3, "execute_min_rarity": "rare", "fate_hold_sec": 0.6}
const DEFAULT_ENDINGS: Dictionary = {"spare_min_ratio": 1.0, "execute_max_ratio": 0.0}
## Identity row of `floor_scaling` (no change).
const IDENTITY_SCALING: Dictionary = {"hp_mult": 1.0, "step_mult": 1.0, "defense_add": 0.0, "size_add": 0}
## Fallback region frame (col 0 one battle, col 1 two or three nodes with one rest-or-treasure, col 2 the boss).
const DEFAULT_REGION_COLUMNS: Array[Dictionary] = [
	{"tier": 0, "kinds": ["battle"], "pick": [1, 1], "required": []},
	{"tier": 1, "kinds": ["battle", "danger"], "pick": [2, 3], "required": [["rest", "treasure"]]},
	{"tier": 2, "kinds": [], "pick": [1, 1], "required": ["boss"]},
]

var _defaults: Dictionary = {}
## Each chapter: {id, name, name_is_key, floors: Array[Dictionary]}. Each floor: {id, name, name_is_key, arena, arena_pool,
## arena_variant, matches (raw dictionaries), overrides (defaults keys present on the floor)}.
var _chapters: Array[Dictionary] = []
## Map defaults shared by chapters: {columns, onboarding_tier_cap, danger_traits}.
var _map_defaults: Dictionary = {"columns": [], "onboarding_tier_cap": 1, "danger_traits": []}
## The cleaned `world` block (Story 031): {floors, choices_per_floor, region_pool, region_columns, floor_scaling,
## floor_tiers, floor_heal_ratio, final_match}.
var _world: Dictionary = {}


## Loads from a JSON file. Never null (defaults + warning when missing or bad).
static func load_from_file(path: String = DEFAULT_PATH) -> ChaptersConfig:
	if not FileAccess.file_exists(path):
		push_warning("ChaptersConfig: file not found, using defaults: %s" % path)
		return from_dictionary({})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ChaptersConfig: JSON root must be an object, using defaults")
		return from_dictionary({})
	return from_dictionary(parsed as Dictionary)


## Builds from a dictionary (see schema.md). Never null; invalid parts are dropped with a warning.
static func from_dictionary(data: Dictionary) -> ChaptersConfig:
	var c := ChaptersConfig.new()
	c._defaults = _clean_defaults(data.get("defaults", {}))
	c._map_defaults = _clean_map_defaults(data.get("defaults", {}))
	var raw_chapters: Variant = data.get("chapters")
	if typeof(raw_chapters) == TYPE_ARRAY:
		var seen: Dictionary = {}
		for entry: Variant in raw_chapters as Array:
			var chapter: Dictionary = c._clean_chapter(entry, c._chapters.size(), seen)
			if not chapter.is_empty():
				c._chapters.append(chapter)
	if c._chapters.is_empty():
		push_warning("ChaptersConfig: no valid chapters, using one default chapter")
		c._chapters.append({
			"id": "ch1", "name": TEXT_DEFAULT_CHAPTER_NAME, "name_is_key": true,
			"floors": [_make_floor("f1", TEXT_DEFAULT_FLOOR_NAME, [{}])],
			"matches": {"match_1": {"id": "match_1"}}, "match_ids": ["match_1"], "pools": {}, "columns": [],
			"region_columns": [], "region_normalize": {"hp_mult": 1.0, "step_mult": 1.0, "defense_add": 0.0},
			})
	c._world = c._clean_world(data.get("world"))
	return c


## Number of chapters (>= 1).
func chapter_count() -> int:
	return _chapters.size()


## Map spec of chapter [param ci] for [method ChapterMapGen.generate]: {id, columns, pools, match_ids,
## onboarding_tier_cap, teach_after}. `teach_after` (P2.3, decision D10) = {match id: [match ids]} of the matches that
## carry the key: such a match (a new elite) is drawn only after one of the listed matches (see ChapterMapGen).
## Empty when out of range.
func get_map_spec(ci: int) -> Dictionary:
	if ci < 0 or ci >= _chapters.size():
		return {}
	var ch: Dictionary = _chapters[ci]
	var columns: Array = ch["columns"]
	if columns.is_empty():
		columns = _map_defaults["columns"]
	if columns.is_empty():
		columns = ChapterMapGen.DEFAULT_COLUMNS
	return {
		"id": ch["id"], "columns": columns.duplicate(true), "pools": (ch["pools"] as Dictionary).duplicate(true),
		"match_ids": (ch["match_ids"] as Array).duplicate(), "onboarding_tier_cap": _map_defaults["onboarding_tier_cap"],
		"teach_after": _teach_after_of(ch["matches"] as Dictionary),
	}


# P2.3: {match id: [teacher match ids]} of every match with a non-empty `teach_after` array (ids kept as written;
# an id that is not a match of the chapter can never be fought there, so that elite then always falls back).
static func _teach_after_of(matches: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for mid: Variant in matches:
		var raw: Variant = (matches[mid] as Dictionary).get("teach_after")
		if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
			continue
		var ids: Array = []
		for id: Variant in raw as Array:
			ids.append(str(id))
		out[str(mid)] = ids
	return out


## Seeded map of chapter [param ci] (see [method ChapterMapGen.generate]); [] when out of range.
func generate_map(ci: int, run_seed: int, cleared_bosses: int) -> Array[Dictionary]:
	var spec: Dictionary = get_map_spec(ci)
	if spec.is_empty():
		var none: Array[Dictionary] = []
		return none
	return ChapterMapGen.generate(spec, run_seed, cleared_bosses)


## Story 031: the cleaned `world` block (deep copy): `floors` (int), `choices_per_floor` (int), `region_pool`
## (Array[String] of region ids), `region_columns` (Array of column specs), `floor_scaling` (object
## "1".."N" / "final" -> {hp_mult, step_mult, defense_add, size_add}), `floor_tiers` (object "1".."N" ->
## [first column tier, middle column tier, boss column tier]), `floor_heal_ratio` (float 0..1),
## `final_match` ({region, match_id} or {}). Built-in fallbacks when the file has no block.
func world_spec() -> Dictionary:
	return _world.duplicate(true)


## Run floors before the final match (>= 1).
## 2026-11-07: the fixed climb order (`world.region_order`): the region of each 0-based floor; [] = none (offer).
func region_order() -> Array[String]:
	var out: Array[String] = []
	out.assign(_world.get("region_order", []) as Array)
	return out


func world_floors() -> int:
	return int(_world["floors"])


## Ids of the regions a world offers from (`world.region_pool`, only ids that exist as chapters).
func region_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in _world["region_pool"] as Array:
		ids.append(str(id))
	return ids


## Index into the chapters array of region [param region_id]; -1 when unknown.
func region_index(region_id: String) -> int:
	for i: int in _chapters.size():
		if str(_chapters[i]["id"]) == region_id:
			return i
	return -1


## `region_normalize` of region [param region_id] ({hp_mult, step_mult, defense_add}; identity when absent
## or the region is unknown). Applied by [method RunConfig.from_node] BEFORE [method floor_scaling].
func region_normalize(region_id: String) -> Dictionary:
	var ci: int = region_index(region_id)
	if ci < 0:
		return {"hp_mult": 1.0, "step_mult": 1.0, "defense_add": 0.0}
	return (_chapters[ci]["region_normalize"] as Dictionary).duplicate()


## Same as [method region_normalize] by chapter index (identity when out of range).
func region_normalize_at(ci: int) -> Dictionary:
	return region_normalize(chapter_id(ci))


## The scaling row of 0-based run [param floor]: `floor_scaling["<floor+1>"]`; a floor >= `floors` (the
## final match) gets the `final` row; a negative floor the first row. Identity when the data has no row.
func floor_scaling(floor: int) -> Dictionary:
	var rows: Dictionary = _world["floor_scaling"]
	var key: String = "final" if floor >= world_floors() else str(maxi(floor, 0) + 1)
	if rows.has(key):
		return (rows[key] as Dictionary).duplicate()
	if key == "final" and rows.has(str(world_floors())):
		return (rows[str(world_floors())] as Dictionary).duplicate()
	return IDENTITY_SCALING.duplicate()


## Share of max HP the player heals when a region boss falls (`world.floor_heal_ratio`, 0..1).
func floor_heal_ratio() -> float:
	return float(_world["floor_heal_ratio"])


## `world.final_match` ({region, match_id}); {} when not set or invalid.
func final_match() -> Dictionary:
	return (_world["final_match"] as Dictionary).duplicate()


## TD-029: node kinds a `world.final_prelude` column may hold (kinds that need no match id).
const FINAL_PRELUDE_KINDS: Array[String] = ["shop", "rest"]


## TD-029: `world.final_prelude` (deep copy): columns placed before the final match's boss column, each
## an Array[String] of node kinds from [constant FINAL_PRELUDE_KINDS] (shipped: [["shop"]], so the gold
## of the floor-5 boss can be spent before the final). [] when the key is missing or empty (the final
## floor is then the boss column alone, the pre-TD-029 behaviour).
func final_prelude() -> Array:
	return (_world["final_prelude"] as Array).duplicate(true)


## TD-029: the final floor's map: the [method final_prelude] columns (indices 0..n-1, tier 0, nodes
## {kind, match_id ""}) then the boss column {index n, tier 0, nodes [{kind boss, match_id}]} of
## [method final_match]. [] when there is no final match.
func final_map() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fm: Dictionary = final_match()
	if fm.is_empty():
		return out
	for kinds: Variant in final_prelude():
		var nodes: Array = []
		for kind: Variant in kinds as Array:
			nodes.append({"kind": str(kind), "match_id": ""})
		out.append({"index": out.size(), "tier": 0, "nodes": nodes})
	out.append({"index": out.size(), "tier": 0, "nodes": [{"kind": ChapterMapGen.KIND_BOSS, "match_id": str(fm.get("match_id", ""))}]})
	return out


# TD-029: `world.final_prelude` cleaned: an array of columns, each an array of node kinds. Only kinds that
# need no match id (FINAL_PRELUDE_KINDS) are kept; anything else is dropped with a warning (a column left
# empty is dropped too). Missing / null = [] (no prelude).
static func _clean_final_prelude(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) == TYPE_NIL:
		return out
	if typeof(raw) != TYPE_ARRAY:
		push_warning("ChaptersConfig: world.final_prelude must be an array of columns, ignored")
		return out
	for col: Variant in raw as Array:
		if typeof(col) != TYPE_ARRAY:
			push_warning("ChaptersConfig: world.final_prelude: column %s is not an array of kinds, dropped" % str(col))
			continue
		var kinds: Array = []
		for kind: Variant in col as Array:
			if typeof(kind) == TYPE_STRING and FINAL_PRELUDE_KINDS.has(str(kind)):
				kinds.append(str(kind))
			else:
				push_warning("ChaptersConfig: world.final_prelude: kind '%s' not allowed (one of %s), dropped" % [str(kind), str(FINAL_PRELUDE_KINDS)])
		if kinds.is_empty():
			push_warning("ChaptersConfig: world.final_prelude: a column has no allowed kind, dropped")
			continue
		out.append(kinds)
	return out


## Story 035: `world.fate` = {execute_artifact_offers (int >= 1), execute_min_rarity (String),
## fate_hold_sec (float >= 0)}; built-in values mirror the shipped JSON ([constant DEFAULT_FATE]).
func fate_config() -> Dictionary:
	return (_world["fate"] as Dictionary).duplicate()


## Story 035: `world.endings` = {spare_min_ratio, execute_max_ratio} (0..1, execute <= spare); see
## [method FateLogic.ending_for]. Built-in values mirror the shipped JSON ([constant DEFAULT_ENDINGS]).
func endings_config() -> Dictionary:
	return (_world["endings"] as Dictionary).duplicate()


## Story 035: the raw `phases` array of the final match (deep copy; [] when there is no final match or
## it has no phases). [method RunConfig.clean_match] turns it into the `boss_phases` trait.
func final_match_phases() -> Array:
	var final: Dictionary = _world["final_match"]
	if final.is_empty():
		return []
	var raw: Dictionary = get_match_raw(region_index(str(final["region"])), str(final["match_id"]))
	var phases: Variant = raw.get("phases")
	if typeof(phases) != TYPE_ARRAY:
		return []
	return (phases as Array).duplicate(true)


## Map spec of region [param region_id] for run [param floor] (0-based), for [method ChapterMapGen.generate]:
## the [method get_map_spec] dictionary with `columns` = the region frame (`world.region_columns`, or the
## region's own `region_columns`) whose tiers follow `world.floor_tiers` for that floor, plus `region_id`,
## `floor`, `floor_number` (1-based; makes [ChapterMapGen] drop node kinds whose `min_floor` is higher),
## `name_key`, `intro_key`, `end_key`, `region_normalize`. {} when the region is unknown.
## Story 038: [param kiep_level] > 0 passes the spec through [method KiepRules.apply_map_spec] (0 = unchanged).
func region_spec(region_id: String, floor: int, kiep_level: int = 0) -> Dictionary:
	var ci: int = region_index(region_id)
	if ci < 0:
		return {}
	var spec: Dictionary = get_map_spec(ci)
	var chapter: Dictionary = _chapters[ci]
	var frame: Array = _world["region_columns"]
	if not (chapter["region_columns"] as Array).is_empty():
		frame = chapter["region_columns"]
	var number: int = clampi(floor, 0, world_floors() - 1) + 1
	var columns: Array = frame.duplicate(true)
	var tiers: Variant = (_world["floor_tiers"] as Dictionary).get(str(number))
	if typeof(tiers) == TYPE_ARRAY and not (tiers as Array).is_empty():
		var t: Array = tiers as Array
		for i: int in columns.size():
			if typeof(columns[i]) != TYPE_DICTIONARY:
				continue
			# [first, middle, boss]: the first column, every middle column, the last column.
			var slot: int = 0
			if i == columns.size() - 1 and i > 0:
				slot = mini(2, t.size() - 1)
			elif i > 0:
				slot = mini(1, t.size() - 1)
			(columns[i] as Dictionary)["tier"] = maxi(int(t[slot]), 0)
	spec["columns"] = columns
	spec["region_id"] = region_id
	spec["floor"] = floor
	spec["floor_number"] = number
	spec["name_key"] = str(chapter["name"]) if bool(chapter["name_is_key"]) else ""
	spec["intro_key"] = str(chapter.get("intro_key", ""))
	spec["end_key"] = str(chapter.get("end_key", ""))
	spec["region_normalize"] = region_normalize(region_id)
	spec["special_nodes"] = special_nodes()
	if kiep_level > 0:
		return KiepRules.shared().apply_map_spec(spec, kiep_level)
	return spec


## Seeded map of region [param region_id] at run [param floor] (0-based): [method ChapterMapGen.generate] of
## [method region_spec] (Story 038: trailing [param kiep_level] too) with the seed [method WorldMapGen.region_map_seed]. Same shape as [method generate_map];
## [] for an unknown region.
func generate_region_map(region_id: String, run_seed: int, floor: int, cleared_bosses: int, kiep_level: int = 0) -> Array[Dictionary]:
	var spec: Dictionary = region_spec(region_id, floor, kiep_level)
	if spec.is_empty():
		var none: Array[Dictionary] = []
		return none
	spec["guarantee_shop"] = shop_floors(run_seed).has(clampi(floor, 0, world_floors() - 1))
	return ChapterMapGen.generate(spec, WorldMapGen.region_map_seed(run_seed, region_id, floor), cleared_bosses)


## Story 033: the cleaned `world.special_nodes` block: {column (0-based column of the region frame whose
## fight nodes a shop / event replace, default 1), shop_weight, event_weight (0..1 probability per region), guaranteed_shops
## (count of floors per run whose region always has a shop), guaranteed_min_floor (1-based first eligible floor)}.
## Without the block: no shop / event nodes at all (old maps unchanged).
func special_nodes() -> Dictionary:
	return (_world["special_nodes"] as Dictionary).duplicate()


## Story 033: the run's shop plan (0-based floors whose region map always has a shop), see
## [method WorldMapGen.shop_floors]; [] when `guaranteed_shops` is 0. 2026-11-04: `first_floor_shop` adds floor 0
## (the first floor) to the drawn plan; the draw itself is unchanged, so later floors keep their shops.
func shop_floors(run_seed: int) -> Array[int]:
	var special: Dictionary = _world["special_nodes"]
	var plan: Array[int] = WorldMapGen.shop_floors(run_seed, world_floors(), int(special["guaranteed_shops"]), int(special["guaranteed_min_floor"]))
	if bool(special.get("first_floor_shop", false)) and world_floors() > 0 and not plan.has(0):
		plan.push_front(0)
	return plan


## Number of columns of chapter [param ci]'s map skeleton (0 when out of range).
func column_count(ci: int) -> int:
	return (get_map_spec(ci).get("columns", []) as Array).size()


## Total nodes of a generated [param map].
func node_count(map: Array) -> int:
	var total: int = 0
	for column: Variant in map:
		total += ((column as Dictionary).get("nodes", []) as Array).size()
	return total


## Match ids of chapter [param ci] in file order.
func match_ids(ci: int) -> Array[String]:
	var ids: Array[String] = []
	if ci >= 0 and ci < _chapters.size():
		for id: Variant in _chapters[ci]["match_ids"] as Array:
			ids.append(str(id))
	return ids


## Normalized match dictionary (keys of [constant RunConfig.MATCH_KEYS], including `arena`) of
## [param match_id] in chapter [param ci]; {} when unknown.
func get_match_def(ci: int, match_id: String) -> Dictionary:
	var raw: Dictionary = get_match_raw(ci, match_id)
	if raw.is_empty():
		return {}
	return RunConfig.clean_match(raw, 0)


## The match as written in the data (deep copy); {} when unknown.
func get_match_raw(ci: int, match_id: String) -> Dictionary:
	if ci < 0 or ci >= _chapters.size():
		return {}
	var matches: Dictionary = _chapters[ci]["matches"]
	if not matches.has(match_id):
		return {}
	return (matches[match_id] as Dictionary).duplicate(true)


## Extra traits a `danger` node adds to its match (from `defaults.danger_traits`).
func danger_traits() -> Array:
	return (_map_defaults["danger_traits"] as Array).duplicate(true)


## Id of chapter [param ci] ("" when out of range).
func chapter_id(ci: int) -> String:
	if ci < 0 or ci >= _chapters.size():
		return ""
	return str(_chapters[ci]["id"])


## Translated display name of chapter [param ci] ("" when out of range): tr(name_key), or the legacy
## display_name literal.
func chapter_name(ci: int) -> String:
	if ci < 0 or ci >= _chapters.size():
		return ""
	return _display(_chapters[ci])


## Story 023: the translation key of chapter [param ci]'s one-line text of [param which] ("intro" or
## "end"; chapters.json `intro_key` / `end_key`); "" when the chapter has none or is out of range.
## Views call tr() on it.
func chapter_text_key(ci: int, which: String) -> String:
	if ci < 0 or ci >= _chapters.size():
		return ""
	return str(_chapters[ci].get(which + "_key", ""))


## The validated defaults block (all keys of [constant DEFAULT_KEYS]).
func defaults() -> Dictionary:
	return _defaults.duplicate()


## Deterministic, non-negative seed of match [param match_index] of a floor entered with
## [param floor_seed].
static func arena_seed_for(floor_seed: int, match_index: int) -> int:
	return hash([floor_seed, match_index]) & SEED_MASK


static func _clean_defaults(raw: Variant) -> Dictionary:
	var base := RunConfig.new()
	var source: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		source = raw as Dictionary
	elif typeof(raw) != TYPE_NIL:
		push_warning("ChaptersConfig: defaults must be an object, using built-in values")
	var result: Dictionary = {
		"heal_between_matches": base.heal_between_matches, "intro_sec": base.intro_sec,
		"end_delay_sec": base.end_delay_sec, "between_sec": base.between_sec,
		"heal_between_floors": base.heal_between_floors, "revive_tokens": base.revive_tokens,
		"retry_min_hp_ratio": base.retry_min_hp_ratio,
	}
	for key: String in DEFAULT_KEYS:
		if source.has(key):
			result[key] = maxf(float(source[key]), 0.0)
	result["revive_tokens"] = maxi(int(source.get("revive_tokens", result["revive_tokens"])), 0)
	result["retry_min_hp_ratio"] = clampf(float(result["retry_min_hp_ratio"]), 0.0, 1.0)
	return result


# Translated name of a chapter / floor record ({name, name_is_key}).
func _display(record: Dictionary) -> String:
	var raw_name: String = str(record.get("name", ""))
	return tr(raw_name) if bool(record.get("name_is_key", false)) else raw_name


# [name, is_key] of a chapter / floor entry: `name_key` (translated later), else the legacy literal
# `display_name` (warning), else the id.
static func _name_of(raw: Dictionary, id: String, what: String) -> Array:
	if raw.has("name_key"):
		return [str(raw["name_key"]), true]
	if raw.has("display_name"):
		push_warning("ChaptersConfig: %s '%s' uses the legacy display_name; use name_key (Story 017)" % [what, id])
		return [str(raw["display_name"]), false]
	return [id, false]


static func _make_floor(id: String, display: String, matches: Array, name_is_key: bool = true) -> Dictionary:
	return {
		"id": id, "name": display, "name_is_key": name_is_key, "arena": {}, "arena_pool": [], "arena_variant": false,
		"matches": matches, "overrides": {},
	}


func _clean_chapter(entry: Variant, index: int, seen: Dictionary) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		push_warning("ChaptersConfig: a chapter entry is not an object, dropped")
		return {}
	var raw: Dictionary = entry as Dictionary
	var id: String = str(raw.get("id", "ch%d" % (index + 1)))
	if seen.has(id):
		push_warning("ChaptersConfig: duplicate chapter id '%s', later one dropped" % id)
		return {}
	var matches: Dictionary = {}
	var match_ids: Array[String] = []
	var raw_matches: Variant = raw.get("matches")
	if typeof(raw_matches) == TYPE_DICTIONARY:
		for match_id: Variant in (raw_matches as Dictionary).keys():
			var entry_match: Variant = (raw_matches as Dictionary)[match_id]
			if typeof(entry_match) != TYPE_DICTIONARY:
				push_warning("ChaptersConfig: match '%s' of '%s' is not an object, ignored" % [match_id, id])
				continue
			var def: Dictionary = (entry_match as Dictionary).duplicate(true)
			def["id"] = str(match_id)
			matches[str(match_id)] = def
			match_ids.append(str(match_id))
	var floors: Array[Dictionary] = []
	var floor_ids: Dictionary = {}
	var raw_floors: Variant = raw.get("floors")
	if typeof(raw_floors) == TYPE_ARRAY:
		for floor_entry: Variant in raw_floors as Array:
			var cleaned: Dictionary = _clean_floor(floor_entry, floors.size(), id, floor_ids)
			if not cleaned.is_empty():
				floors.append(cleaned)
				# v1 format: the floor matches double as the chapter's match definitions.
				for m: Variant in cleaned["matches"] as Array:
					var mid: String = str((m as Dictionary).get("id", "match_%d" % (match_ids.size() + 1)))
					if not matches.has(mid):
						matches[mid] = (m as Dictionary).duplicate(true)
						match_ids.append(mid)
	if floors.is_empty() and not matches.is_empty():
		# A v2 chapter: one internal floor holding every match (the v1 parse path expects one).
		var all: Array = []
		for mid: String in match_ids:
			all.append((matches[mid] as Dictionary).duplicate(true))
		floors.append(_make_floor("f1", TEXT_DEFAULT_FLOOR_NAME, all))
	if floors.is_empty() or matches.is_empty():
		push_warning("ChaptersConfig: chapter '%s' has no valid matches, dropped" % id)
		return {}
	seen[id] = true
	var named: Array = _name_of(raw, id, "chapter")
	var columns: Array = []
	if typeof(raw.get("columns")) == TYPE_ARRAY:
		columns = (raw["columns"] as Array).duplicate(true)
	var pools: Dictionary = {}
	if typeof(raw.get("pools")) == TYPE_DICTIONARY:
		pools = _clean_pools(raw["pools"] as Dictionary, matches, id)
	var region_columns: Array = []
	if typeof(raw.get("region_columns")) == TYPE_ARRAY:
		region_columns = (raw["region_columns"] as Array).duplicate(true)
	return {"id": id, "name": named[0], "name_is_key": named[1], "floors": floors, "matches": matches,
		"match_ids": match_ids, "pools": pools, "columns": columns, "region_columns": region_columns,
		"region_normalize": _clean_normalize(raw.get("region_normalize"), id),
		"intro_key": str(raw.get("intro_key", "")), "end_key": str(raw.get("end_key", ""))}


# pools: kind -> tier ("0".."n") -> match ids; unknown ids are dropped with a warning.
static func _clean_pools(raw: Dictionary, matches: Dictionary, chapter_id_text: String) -> Dictionary:
	var result: Dictionary = {}
	for kind: Variant in raw.keys():
		if typeof(raw[kind]) != TYPE_DICTIONARY:
			push_warning("ChaptersConfig: pools.%s of '%s' must be an object, ignored" % [kind, chapter_id_text])
			continue
		var tiers: Dictionary = {}
		for tier: Variant in (raw[kind] as Dictionary).keys():
			var ids: Array = []
			var list: Variant = (raw[kind] as Dictionary)[tier]
			if typeof(list) == TYPE_ARRAY:
				for mid: Variant in list as Array:
					if matches.has(str(mid)):
						ids.append(str(mid))
					else:
						push_warning("ChaptersConfig: pools.%s.%s of '%s': unknown match '%s' dropped" % [kind, tier, chapter_id_text, mid])
			tiers[str(tier)] = ids
		result[str(kind)] = tiers
	return result


static func _clean_map_defaults(raw: Variant) -> Dictionary:
	var result: Dictionary = {"columns": [], "onboarding_tier_cap": 1, "danger_traits": []}
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var source: Dictionary = raw as Dictionary
	if typeof(source.get("columns")) == TYPE_ARRAY:
		result["columns"] = (source["columns"] as Array).duplicate(true)
	if source.has("onboarding_tier_cap"):
		result["onboarding_tier_cap"] = maxi(int(source["onboarding_tier_cap"]), 0)
	if typeof(source.get("danger_traits")) == TYPE_ARRAY:
		result["danger_traits"] = (source["danger_traits"] as Array).duplicate(true)
	return result


func _clean_floor(entry: Variant, index: int, chapter_id_text: String, seen: Dictionary) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		push_warning("ChaptersConfig: a floor entry in '%s' is not an object, dropped" % chapter_id_text)
		return {}
	var raw: Dictionary = entry as Dictionary
	var id: String = str(raw.get("id", "f%d" % (index + 1)))
	if seen.has(id):
		push_warning("ChaptersConfig: duplicate floor id '%s' in '%s', later one dropped" % [id, chapter_id_text])
		return {}
	var matches: Array = []
	var raw_matches: Variant = raw.get("matches")
	if typeof(raw_matches) == TYPE_ARRAY:
		for m: Variant in raw_matches as Array:
			if typeof(m) == TYPE_DICTIONARY:
				matches.append((m as Dictionary).duplicate(true))
			else:
				push_warning("ChaptersConfig: a match entry of floor '%s/%s' is not an object, ignored" % [chapter_id_text, id])
	if matches.is_empty():
		push_warning("ChaptersConfig: floor '%s/%s' has no matches, dropped" % [chapter_id_text, id])
		return {}
	var named: Array = _name_of(raw, id, "floor")
	var floor_dict: Dictionary = _make_floor(id, named[0], matches, named[1])
	var arena: Variant = raw.get("arena", {})
	if typeof(arena) == TYPE_DICTIONARY:
		floor_dict["arena"] = (arena as Dictionary).duplicate(true)
	elif typeof(arena) != TYPE_NIL:
		push_warning("ChaptersConfig: arena of floor '%s/%s' must be an object, ignored" % [chapter_id_text, id])
	var pool: Variant = raw.get("arena_pool", [])
	if typeof(pool) == TYPE_ARRAY:
		floor_dict["arena_pool"] = (pool as Array).duplicate()
	elif typeof(pool) != TYPE_NIL:
		push_warning("ChaptersConfig: arena_pool of floor '%s/%s' must be an array, ignored" % [chapter_id_text, id])
	floor_dict["arena_variant"] = bool(raw.get("arena_variant", false))
	var overrides: Dictionary = {}
	for key: String in DEFAULT_KEYS:
		if raw.has(key):
			overrides[key] = float(raw[key])
	floor_dict["overrides"] = overrides
	seen[id] = true
	return floor_dict


# `region_normalize` of one chapter: {hp_mult > 0, step_mult > 0, defense_add}; identity for missing parts.
static func _clean_normalize(raw: Variant, chapter_id_text: String) -> Dictionary:
	var result: Dictionary = {"hp_mult": 1.0, "step_mult": 1.0, "defense_add": 0.0}
	if typeof(raw) == TYPE_NIL:
		return result
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("ChaptersConfig: region_normalize of '%s' must be an object, ignored" % chapter_id_text)
		return result
	var source: Dictionary = raw as Dictionary
	for key: String in ["hp_mult", "step_mult"]:
		if source.has(key):
			var value: float = float(source[key])
			if value <= 0.0:
				push_warning("ChaptersConfig: region_normalize.%s of '%s' must be > 0, using 1" % [key, chapter_id_text])
			else:
				result[key] = value
	result["defense_add"] = float(source.get("defense_add", 0.0))
	return result


# One `floor_scaling` row: {hp_mult > 0, step_mult > 0, defense_add, size_add}; bad parts keep the identity.
static func _clean_scaling_row(raw: Variant, label: String) -> Dictionary:
	var row: Dictionary = IDENTITY_SCALING.duplicate()
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("ChaptersConfig: world.floor_scaling.%s must be an object, using no scaling" % label)
		return row
	var source: Dictionary = raw as Dictionary
	for key: String in ["hp_mult", "step_mult"]:
		if source.has(key):
			var value: float = float(source[key])
			if value <= 0.0:
				push_warning("ChaptersConfig: world.floor_scaling.%s.%s must be > 0, using 1" % [label, key])
			else:
				row[key] = value
	row["defense_add"] = float(source.get("defense_add", 0.0))
	row["size_add"] = int(source.get("size_add", 0))
	return row


# The `world` block with defaults and warnings (see [method world_spec]).
func _clean_world(raw: Variant) -> Dictionary:
	var source: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		source = raw as Dictionary
	else:
		push_warning("ChaptersConfig: no `world` block, using the built-in run frame")
	var world: Dictionary = {}
	world["floors"] = maxi(int(source.get("floors", DEFAULT_WORLD_FLOORS)), 1)
	world["choices_per_floor"] = maxi(int(source.get("choices_per_floor", DEFAULT_CHOICES_PER_FLOOR)), 1)
	var pool: Array[String] = []
	var raw_pool: Variant = source.get("region_pool")
	if typeof(raw_pool) == TYPE_ARRAY:
		for id: Variant in raw_pool as Array:
			if region_index(str(id)) < 0:
				push_warning("ChaptersConfig: world.region_pool: unknown region '%s' dropped" % id)
			elif not pool.has(str(id)):
				pool.append(str(id))
	if pool.is_empty():
		if typeof(raw_pool) == TYPE_ARRAY:
			push_warning("ChaptersConfig: world.region_pool has no valid region, using every chapter")
		for chapter: Dictionary in _chapters:
			pool.append(str(chapter["id"]))
	world["region_pool"] = pool
	# 2026-11-07 (user: the run climbs every region, bottom to top of the climb map): `region_order` = the region of
	# each floor in order (unknown ids dropped); empty / absent = the Story 031 offer of choices_per_floor regions.
	var order: Array[String] = []
	var raw_order: Variant = source.get("region_order")
	if typeof(raw_order) == TYPE_ARRAY:
		for id: Variant in raw_order as Array:
			if region_index(str(id)) < 0:
				push_warning("ChaptersConfig: world.region_order: unknown region '%s' dropped" % id)
			else:
				order.append(str(id))
	world["region_order"] = order
	var columns: Array = []
	if typeof(source.get("region_columns")) == TYPE_ARRAY:
		columns = (source["region_columns"] as Array).duplicate(true)
	if columns.is_empty():
		if source.has("region_columns"):
			push_warning("ChaptersConfig: world.region_columns is empty or not an array, using the built-in frame")
		columns = DEFAULT_REGION_COLUMNS.duplicate(true)
	world["region_columns"] = columns
	var rows: Dictionary = {}
	var raw_rows: Variant = source.get("floor_scaling")
	if typeof(raw_rows) == TYPE_DICTIONARY:
		for key: Variant in (raw_rows as Dictionary).keys():
			rows[str(key)] = _clean_scaling_row((raw_rows as Dictionary)[key], str(key))
	elif typeof(raw_rows) != TYPE_NIL:
		push_warning("ChaptersConfig: world.floor_scaling must be an object, using no scaling")
	world["floor_scaling"] = rows
	var tiers: Dictionary = {}
	var raw_tiers: Variant = source.get("floor_tiers")
	if typeof(raw_tiers) == TYPE_DICTIONARY:
		for key: Variant in (raw_tiers as Dictionary).keys():
			var list: Variant = (raw_tiers as Dictionary)[key]
			if typeof(list) == TYPE_ARRAY and not (list as Array).is_empty():
				var cleaned: Array = []
				for t: Variant in list as Array:
					cleaned.append(maxi(int(t), 0))
				tiers[str(key)] = cleaned
			else:
				push_warning("ChaptersConfig: world.floor_tiers.%s must be a non-empty array, ignored" % key)
	elif typeof(raw_tiers) != TYPE_NIL:
		push_warning("ChaptersConfig: world.floor_tiers must be an object, ignored")
	world["floor_tiers"] = tiers
	world["floor_heal_ratio"] = clampf(float(source.get("floor_heal_ratio", DEFAULT_FLOOR_HEAL_RATIO)), 0.0, 1.0)
	var final: Dictionary = {}
	var raw_final: Variant = source.get("final_match")
	if typeof(raw_final) == TYPE_DICTIONARY:
		var rid: String = str((raw_final as Dictionary).get("region", ""))
		var mid: String = str((raw_final as Dictionary).get("match_id", ""))
		var ci: int = region_index(rid)
		if ci >= 0 and (_chapters[ci]["matches"] as Dictionary).has(mid):
			final = {"region": rid, "match_id": mid}
		else:
			push_warning("ChaptersConfig: world.final_match '%s/%s' is unknown, ignored" % [rid, mid])
	elif typeof(raw_final) != TYPE_NIL:
		push_warning("ChaptersConfig: world.final_match must be an object, ignored")
	world["final_match"] = final
	world["final_prelude"] = _clean_final_prelude(source.get("final_prelude"))
	var special: Dictionary = {"column": 1, "shop_weight": 0.0, "event_weight": 0.0, "guaranteed_shops": 0, "guaranteed_min_floor": 1,
		"first_floor_shop": false}
	var raw_special: Variant = source.get("special_nodes")
	if typeof(raw_special) == TYPE_DICTIONARY:
		var sp: Dictionary = raw_special as Dictionary
		special["column"] = maxi(int(sp.get("column", 1)), 1)
		special["shop_weight"] = clampf(float(sp.get("shop_weight", 0.0)), 0.0, 1.0)
		special["event_weight"] = clampf(float(sp.get("event_weight", 0.0)), 0.0, 1.0)
		special["guaranteed_shops"] = maxi(int(sp.get("guaranteed_shops", 0)), 0)
		special["guaranteed_min_floor"] = maxi(int(sp.get("guaranteed_min_floor", 1)), 1)
		# 2026-11-04: floor 1 always has a shop too, on top of the guaranteed ones (see shop_floors).
		special["first_floor_shop"] = bool(sp.get("first_floor_shop", false))
	elif raw_special != null:
		push_warning("ChaptersConfig: world.special_nodes must be an object, ignored")
	world["special_nodes"] = special
	world["fate"] = _clean_fate(source.get("fate"))
	world["endings"] = _clean_endings(source.get("endings"))
	return world


# Story 035: `world.fate` with defaults (DEFAULT_FATE) and a warning per bad value.
static func _clean_fate(raw: Variant) -> Dictionary:
	var fate: Dictionary = DEFAULT_FATE.duplicate()
	if typeof(raw) == TYPE_NIL:
		return fate
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("ChaptersConfig: world.fate must be an object, using defaults")
		return fate
	var source: Dictionary = raw as Dictionary
	if source.has("execute_artifact_offers"):
		var offers: int = int(source["execute_artifact_offers"])
		if offers < 1:
			push_warning("ChaptersConfig: world.fate.execute_artifact_offers must be >= 1, using %d" % fate["execute_artifact_offers"])
		else:
			fate["execute_artifact_offers"] = offers
	if source.has("execute_min_rarity"):
		var rarity: String = str(source["execute_min_rarity"])
		if rarity.is_empty():
			push_warning("ChaptersConfig: world.fate.execute_min_rarity is empty, using '%s'" % fate["execute_min_rarity"])
		else:
			fate["execute_min_rarity"] = rarity
	if source.has("fate_hold_sec"):
		var hold: float = float(source["fate_hold_sec"])
		if hold < 0.0:
			push_warning("ChaptersConfig: world.fate.fate_hold_sec must be >= 0, using %s" % fate["fate_hold_sec"])
		else:
			fate["fate_hold_sec"] = hold
	return fate


# Story 035: `world.endings` with defaults (DEFAULT_ENDINGS): both ratios in 0..1 and
# execute_max_ratio <= spare_min_ratio, else a warning and the defaults for the pair.
static func _clean_endings(raw: Variant) -> Dictionary:
	var endings: Dictionary = DEFAULT_ENDINGS.duplicate()
	if typeof(raw) == TYPE_NIL:
		return endings
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("ChaptersConfig: world.endings must be an object, using defaults")
		return endings
	var source: Dictionary = raw as Dictionary
	for key: String in ["spare_min_ratio", "execute_max_ratio"]:
		if source.has(key):
			var value: float = float(source[key])
			if value < 0.0 or value > 1.0:
				push_warning("ChaptersConfig: world.endings.%s must be in 0..1, using %s" % [key, endings[key]])
			else:
				endings[key] = value
	if float(endings["execute_max_ratio"]) > float(endings["spare_min_ratio"]):
		push_warning("ChaptersConfig: world.endings.execute_max_ratio > spare_min_ratio, using defaults")
		endings = DEFAULT_ENDINGS.duplicate()
	return endings

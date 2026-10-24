class_name ChaptersConfig
extends RefCounted
## Chapters from assets/data/chapters.json (v2, Story 022): per chapter a `matches` map, `pools`
## (kind -> tier -> match ids) and a `columns` spec feeding [ChapterMapGen]; use [method generate_map],
## [method get_match_def] and [method RunConfig.from_node]. DEPRECATED (kept until GameFlow migrates,
## Story 022 Part 2): the floor API ([method resolved_floor], [method floor_count], [method next_floor]
## ...), fed by the optional `legacy_floors` list or the v1 `floors` format.
## Never null after [method load_from_file]: a bad file gives one default chapter / match.
## Schema: assets/data/schema.md. Implements: Story 015, Story 022.

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

## Optional library used to validate pool ids; loaded from arenas.json on first use.
var arena_library: ArenaLibrary = null
var _defaults: Dictionary = {}
## Each chapter: {id, name, name_is_key, floors: Array[Dictionary]}. Each floor: {id, name, name_is_key, arena, arena_pool,
## arena_variant, matches (raw dictionaries), overrides (defaults keys present on the floor)}.
var _chapters: Array[Dictionary] = []
## Map defaults shared by chapters: {columns, onboarding_tier_cap, danger_traits}.
var _map_defaults: Dictionary = {"columns": [], "onboarding_tier_cap": 1, "danger_traits": []}


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
			})
	return c


## Number of chapters (>= 1).
func chapter_count() -> int:
	return _chapters.size()


## Map spec of chapter [param ci] for [method ChapterMapGen.generate]: {id, columns, pools, match_ids,
## onboarding_tier_cap}. Empty when out of range.
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
	}


## Seeded map of chapter [param ci] (see [method ChapterMapGen.generate]); [] when out of range.
func generate_map(ci: int, run_seed: int, cleared_bosses: int) -> Array[Dictionary]:
	var spec: Dictionary = get_map_spec(ci)
	if spec.is_empty():
		var none: Array[Dictionary] = []
		return none
	return ChapterMapGen.generate(spec, run_seed, cleared_bosses)


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


## Number of floors of chapter [param ci] (0 when out of range).
func floor_count(ci: int) -> int:
	if ci < 0 or ci >= _chapters.size():
		return 0
	return (_chapters[ci]["floors"] as Array).size()


## Floors over all chapters.
func total_floors() -> int:
	var total: int = 0
	for ci: int in _chapters.size():
		total += floor_count(ci)
	return total


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


## Id of floor [param fi] of chapter [param ci] ("" when out of range).
func floor_id(ci: int, fi: int) -> String:
	return str(_floor(ci, fi).get("id", ""))


## Translated display name of the floor ("" when out of range); see [method chapter_name].
func floor_name(ci: int, fi: int) -> String:
	var fl: Dictionary = _floor(ci, fi)
	return "" if fl.is_empty() else _display(fl)


## "<chapter id>/<floor id>" (e.g. "ch1/f2"); "" when out of range.
func floor_key(ci: int, fi: int) -> String:
	if _floor(ci, fi).is_empty():
		return ""
	return "%s/%s" % [chapter_id(ci), floor_id(ci, fi)]


## (chapter, floor) of a key, or (-1, -1) when unknown.
func find_floor(key: String) -> Vector2i:
	for ci: int in _chapters.size():
		for fi: int in floor_count(ci):
			if floor_key(ci, fi) == key:
				return Vector2i(ci, fi)
	return Vector2i(-1, -1)


## Position of a floor in the linear order across chapters (-1 when out of range).
func linear_index(ci: int, fi: int) -> int:
	if _floor(ci, fi).is_empty():
		return -1
	var index: int = fi
	for previous: int in ci:
		index += floor_count(previous)
	return index


## Inverse of [method linear_index]; (-1, -1) when out of range.
func floor_at_linear(i: int) -> Vector2i:
	if i < 0:
		return Vector2i(-1, -1)
	var rest: int = i
	for ci: int in _chapters.size():
		var count: int = floor_count(ci)
		if rest < count:
			return Vector2i(ci, rest)
		rest -= count
	return Vector2i(-1, -1)


## The floor after (ci, fi) in linear order across chapters; (-1, -1) after the last one.
func next_floor(ci: int, fi: int) -> Vector2i:
	var index: int = linear_index(ci, fi)
	if index < 0:
		return Vector2i(-1, -1)
	return floor_at_linear(index + 1)


## True when (ci, fi) is the last floor of its chapter.
func is_last_floor_of_chapter(ci: int, fi: int) -> bool:
	return not _floor(ci, fi).is_empty() and fi == floor_count(ci) - 1


## Number of matches of a floor (0 when out of range).
func match_count(ci: int, fi: int) -> int:
	return (_floor(ci, fi).get("matches", []) as Array).size()


## Arena info of a floor for the floor-select screen:
## {"kind": "fixed"|"pool"|"none", "shape": String, "pool": Array[String], "variant": bool}.
## A floor with both arena and arena_pool reports "fixed" (the arena wins).
func arena_summary(ci: int, fi: int) -> Dictionary:
	var fl: Dictionary = _floor(ci, fi)
	var summary: Dictionary = {"kind": "none", "shape": "", "pool": [] as Array[String], "variant": false}
	if fl.is_empty():
		return summary
	var arena: Dictionary = fl["arena"]
	if not arena.is_empty():
		summary["kind"] = "fixed"
		summary["shape"] = str(arena.get("shape", ""))
		summary["variant"] = bool(arena.get("variant", false))
	elif not (fl["arena_pool"] as Array).is_empty():
		var pool: Array[String] = []
		for id: Variant in fl["arena_pool"] as Array:
			pool.append(str(id))
		summary["kind"] = "pool"
		summary["pool"] = pool
		summary["variant"] = bool(fl["arena_variant"])
	return summary


## The validated defaults block (all keys of [constant DEFAULT_KEYS]).
func defaults() -> Dictionary:
	return _defaults.duplicate()


## Deep copy of floor (ci, fi) whose matches[i] carry "arena" and "arena_seed". Rules: the match's
## own non-empty arena wins; else the floor's fixed arena; else a shape drawn from the floor's
## pool with a seeded shuffle bag (adjacent matches differ when the pool has >= 2 shapes); else {}
## (the combat.json board). Empty dictionary when the floor does not exist. Does not mutate.
func resolved_floor(ci: int, fi: int, floor_seed: int) -> Dictionary:
	var fl: Dictionary = _floor(ci, fi)
	if fl.is_empty():
		return {}
	var result: Dictionary = fl.duplicate(true)
	var floor_arena: Dictionary = result["arena"]
	var pool: Array[String] = []
	if not floor_arena.is_empty():
		if not (result["arena_pool"] as Array).is_empty():
			push_warning("ChaptersConfig: floor %s has both arena and arena_pool, using arena" % floor_key(ci, fi))
	else:
		pool = _validated_pool(result["arena_pool"] as Array, floor_key(ci, fi))
	var bag: Array[String] = _shuffled(pool, floor_seed)
	var variant: bool = bool(result["arena_variant"])
	var matches: Array = result["matches"]
	for i: int in matches.size():
		var match_dict: Dictionary = matches[i]
		var own: Variant = match_dict.get("arena", {})
		var has_own: bool = typeof(own) == TYPE_DICTIONARY and not (own as Dictionary).is_empty()
		if not has_own:
			if not floor_arena.is_empty():
				match_dict["arena"] = floor_arena.duplicate(true)
			elif not bag.is_empty():
				match_dict["arena"] = {"shape": bag[i % bag.size()], "variant": variant}
			else:
				match_dict["arena"] = {}
		match_dict["arena_seed"] = arena_seed_for(floor_seed, i)
		matches[i] = match_dict
	return result


## Deterministic, non-negative seed of match [param match_index] of a floor entered with
## [param floor_seed].
static func arena_seed_for(floor_seed: int, match_index: int) -> int:
	return hash([floor_seed, match_index]) & SEED_MASK


func _floor(ci: int, fi: int) -> Dictionary:
	if ci < 0 or ci >= _chapters.size():
		return {}
	var floors: Array = _chapters[ci]["floors"]
	if fi < 0 or fi >= floors.size():
		return {}
	return floors[fi]


func _library() -> ArenaLibrary:
	if arena_library == null:
		arena_library = ArenaLibrary.load_from_file()
	return arena_library


func _validated_pool(raw_pool: Array, key: String) -> Array[String]:
	var pool: Array[String] = []
	if raw_pool.is_empty():
		return pool
	var valid: Array[String] = _library().shape_ids()
	for id: Variant in raw_pool:
		var text: String = str(id)
		if not valid.has(text):
			push_warning("ChaptersConfig: floor %s: unknown arena '%s' dropped from arena_pool" % [key, text])
		elif not pool.has(text):
			pool.append(text)
	if pool.is_empty():
		push_warning("ChaptersConfig: floor %s: arena_pool is empty after validation, using the combat.json board" % key)
	return pool


static func _shuffled(pool: Array[String], floor_seed: int) -> Array[String]:
	var bag: Array[String] = pool.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_seed
	for i: int in range(bag.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
	return bag


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
	var raw_legacy: Variant = raw.get("legacy_floors")
	if floors.is_empty() and typeof(raw_legacy) == TYPE_ARRAY:
		for floor_entry: Variant in raw_legacy as Array:
			if typeof(floor_entry) != TYPE_DICTIONARY:
				continue
			var lf: Dictionary = (floor_entry as Dictionary).duplicate(true)
			var resolved: Array = []
			for mid: Variant in lf.get("match_ids", []) as Array:
				if matches.has(str(mid)):
					resolved.append((matches[str(mid)] as Dictionary).duplicate(true))
			lf["matches"] = resolved
			var cleaned_legacy: Dictionary = _clean_floor(lf, floors.size(), id, floor_ids)
			if not cleaned_legacy.is_empty():
				floors.append(cleaned_legacy)
	if floors.is_empty() and not matches.is_empty():
		# A v2 chapter without legacy floors: one synthetic floor holding every match.
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
	return {"id": id, "name": named[0], "name_is_key": named[1], "floors": floors, "matches": matches,
		"match_ids": match_ids, "pools": pools, "columns": columns}


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

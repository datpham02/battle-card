class_name ChaptersConfig
extends RefCounted
## Chapters -> floors -> matches from assets/data/chapters.json, plus the arena rules of a
## floor (fixed shape, seeded shape pool, per-match override). A run is ONE floor: use
## [method resolved_floor] and [method RunConfig.from_floor]. Never null after
## [method load_from_file]: a bad file gives one default chapter / floor / match.
## Schema: assets/data/schema.md. Implements: Story 015.

const DEFAULT_PATH: String = "res://assets/data/chapters.json"
## Keys of the `defaults` block (and of an optional per-floor override of them).
const DEFAULT_KEYS: Array[String] = [
	"heal_between_matches", "intro_sec", "end_delay_sec", "between_sec", "retry_min_hp_ratio",
]
## Keeps arena seeds non-negative (a negative seed means "random" to the arena code).
const SEED_MASK: int = 0x7fffffff
const TEXT_DEFAULT_CHAPTER_NAME: String = "Chương 1"
const TEXT_DEFAULT_FLOOR_NAME: String = "Tầng 1"

## Optional library used to validate pool ids; loaded from arenas.json on first use.
var arena_library: ArenaLibrary = null
var _defaults: Dictionary = {}
## Each chapter: {id, name, floors: Array[Dictionary]}. Each floor: {id, name, arena, arena_pool,
## arena_variant, matches (raw dictionaries), overrides (defaults keys present on the floor)}.
var _chapters: Array[Dictionary] = []


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
			"id": "ch1", "name": TEXT_DEFAULT_CHAPTER_NAME,
			"floors": [_make_floor("f1", TEXT_DEFAULT_FLOOR_NAME, [{}])],
		})
	return c


## Number of chapters (>= 1).
func chapter_count() -> int:
	return _chapters.size()


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


## Display name of chapter [param ci] ("" when out of range).
func chapter_name(ci: int) -> String:
	if ci < 0 or ci >= _chapters.size():
		return ""
	return str(_chapters[ci]["name"])


## Id of floor [param fi] of chapter [param ci] ("" when out of range).
func floor_id(ci: int, fi: int) -> String:
	return str(_floor(ci, fi).get("id", ""))


## Display name of the floor ("" when out of range).
func floor_name(ci: int, fi: int) -> String:
	return str(_floor(ci, fi).get("name", ""))


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
		"retry_min_hp_ratio": base.retry_min_hp_ratio,
	}
	for key: String in DEFAULT_KEYS:
		if source.has(key):
			result[key] = maxf(float(source[key]), 0.0)
	result["retry_min_hp_ratio"] = clampf(float(result["retry_min_hp_ratio"]), 0.0, 1.0)
	return result


static func _make_floor(id: String, display: String, matches: Array) -> Dictionary:
	return {
		"id": id, "name": display, "arena": {}, "arena_pool": [], "arena_variant": false,
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
	var floors: Array[Dictionary] = []
	var floor_ids: Dictionary = {}
	var raw_floors: Variant = raw.get("floors")
	if typeof(raw_floors) == TYPE_ARRAY:
		for floor_entry: Variant in raw_floors as Array:
			var cleaned: Dictionary = _clean_floor(floor_entry, floors.size(), id, floor_ids)
			if not cleaned.is_empty():
				floors.append(cleaned)
	if floors.is_empty():
		push_warning("ChaptersConfig: chapter '%s' has no valid floors, dropped" % id)
		return {}
	seen[id] = true
	return {"id": id, "name": str(raw.get("display_name", id)), "floors": floors}


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
	var floor_dict: Dictionary = _make_floor(id, str(raw.get("display_name", id)), matches)
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

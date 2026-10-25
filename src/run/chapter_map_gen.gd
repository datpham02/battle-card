class_name ChapterMapGen
extends RefCounted
## Pure, seeded chapter map generator (Story 022 Phase A). A map is an Array of columns
## {"index": int, "tier": int, "nodes": [{"kind": String, "match_id": String}]}. The skeleton comes
## from the chapter's `columns` spec (chapters.json): per column `kinds` (random filler kinds),
## `pick` ([min, max] node count), `required` (kinds that must appear once; an array entry is a set
## of alternatives, one drawn 50/50) and `tier`. Same (chapter, run_seed, cleared_bosses) -> same map.
## Story 031: an entry of `kinds` / `required` may also be {"kind": String, "min_floor": int}; with a
## positive `floor_number` (1-based run floor, set by ChaptersConfig.region_spec) entries whose min_floor is
## higher are dropped; without `floor_number` min_floor is ignored (old maps are unchanged).
## Design: design/game-brief.md "Run", design/reference/osfe-reference.md section 9.3.

const KIND_BATTLE: String = "battle"
const KIND_DANGER: String = "danger"
const KIND_TREASURE: String = "treasure"
const KIND_REST: String = "rest"
const KIND_MINIBOSS: String = "miniboss"
const KIND_BOSS: String = "boss"
const KINDS: Array[String] = [KIND_BATTLE, KIND_DANGER, KIND_TREASURE, KIND_REST, KIND_MINIBOSS, KIND_BOSS]
## Kinds that play a match (the others have an empty match_id).
const MATCH_KINDS: Array[String] = [KIND_BATTLE, KIND_DANGER, KIND_MINIBOSS, KIND_BOSS]
const SEED_MASK: int = 0x7fffffff
## Fallback skeleton used only when the data carries no `columns` (missing / bad chapters.json);
## the shipped spec lives in chapters.json `defaults.columns`.
const DEFAULT_COLUMNS: Array[Dictionary] = [
	{"tier": 0, "kinds": ["battle"], "pick": [1, 1], "required": []},
	{"tier": 1, "kinds": ["battle", "danger", "treasure"], "pick": [2, 3], "required": []},
	{"tier": 1, "kinds": ["battle", "danger", "treasure"], "pick": [2, 3], "required": []},
	{"tier": 2, "kinds": ["battle", "danger"], "pick": [2, 3], "required": ["miniboss"]},
	{"tier": 2, "kinds": ["battle", "danger"], "pick": [2, 3], "required": ["rest", ["treasure", "battle"]]},
	{"tier": 2, "kinds": ["battle", "danger"], "pick": [2, 3], "required": []},
	{"tier": 2, "kinds": [], "pick": [1, 1], "required": ["boss"]},
]


## Generates the map of [param chapter] ({id, columns, pools, match_ids, onboarding_tier_cap}, as
## from [method ChaptersConfig.get_map_spec]). [param cleared_bosses] 0 caps every tier at
## `onboarding_tier_cap` (hidden onboarding). Never fails: a non-array `columns` yields an empty array; a missing or empty one uses
## [constant DEFAULT_COLUMNS].
static func generate(chapter: Dictionary, run_seed: int, cleared_bosses: int) -> Array[Dictionary]:
	var map: Array[Dictionary] = []
	var columns: Variant = chapter.get("columns", [])
	if typeof(columns) != TYPE_ARRAY:
		return map
	if (columns as Array).is_empty():
		columns = DEFAULT_COLUMNS
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, str(chapter.get("id", ""))]) & SEED_MASK
	var cap: int = int(chapter.get("onboarding_tier_cap", 1))
	var floor_number: int = int(chapter.get("floor_number", 0))
	var used: Array[String] = []
	var spec_columns: Array = columns as Array
	for ci: int in spec_columns.size():
		var spec: Dictionary = spec_columns[ci] if typeof(spec_columns[ci]) == TYPE_DICTIONARY else {}
		var tier: int = maxi(int(spec.get("tier", 0)), 0)
		if cleared_bosses <= 0:
			tier = mini(tier, cap)
		var kinds: Array[String] = _column_kinds(spec, rng, floor_number)
		var nodes: Array[Dictionary] = []
		for kind: String in kinds:
			var match_id: String = ""
			if MATCH_KINDS.has(kind):
				match_id = _draw_match(chapter, kind, tier, used, rng)
				used.append(match_id)
			nodes.append({"kind": kind, "match_id": match_id})
		map.append({"index": ci, "tier": tier, "nodes": nodes})
	return map


# Kinds of one column: required ones first, fillers up to a seeded count, siblings differ when
# possible, then a seeded shuffle of the order.
static func _column_kinds(spec: Dictionary, rng: RandomNumberGenerator, floor_number: int = 0) -> Array[String]:
	var kinds: Array[String] = []
	var required: Variant = spec.get("required", [])
	if typeof(required) == TYPE_ARRAY:
		for entry: Variant in required as Array:
			if typeof(entry) == TYPE_ARRAY and not (entry as Array).is_empty():
				var options: Array[String] = _allowed_kinds(entry as Array, floor_number)
				if not options.is_empty():
					kinds.append(options[rng.randi_range(0, options.size() - 1)])
			elif typeof(entry) == TYPE_STRING or typeof(entry) == TYPE_DICTIONARY:
				var allowed: Array[String] = _allowed_kinds([entry], floor_number)
				if not allowed.is_empty():
					kinds.append(allowed[0])
	var pick_min: int = 1
	var pick_max: int = 1
	var pick: Variant = spec.get("pick", 1)
	if typeof(pick) == TYPE_ARRAY and (pick as Array).size() >= 2:
		pick_min = int((pick as Array)[0])
		pick_max = int((pick as Array)[1])
	elif typeof(pick) != TYPE_ARRAY:
		pick_min = int(pick)
		pick_max = pick_min
	pick_max = maxi(pick_max, pick_min)
	var count: int = maxi(rng.randi_range(pick_min, pick_max), kinds.size())
	var fillers: Array[String] = []
	var raw_fillers: Variant = spec.get("kinds", [])
	if typeof(raw_fillers) == TYPE_ARRAY:
		fillers = _allowed_kinds(raw_fillers as Array, floor_number)
	while kinds.size() < count and not fillers.is_empty():
		var fresh: Array[String] = []
		for k: String in fillers:
			if not kinds.has(k):
				fresh.append(k)
		var source: Array[String] = fresh if not fresh.is_empty() else fillers
		kinds.append(source[rng.randi_range(0, source.size() - 1)])
	for i: int in range(kinds.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	return kinds


# Kind names of [param entries] (strings or {kind, min_floor}) available at [param floor_number]
# (<= 0 = no floor filtering).
static func _allowed_kinds(entries: Array, floor_number: int) -> Array[String]:
	var result: Array[String] = []
	for entry: Variant in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			var def: Dictionary = entry as Dictionary
			if floor_number > 0 and int(def.get("min_floor", 0)) > floor_number:
				continue
			result.append(str(def.get("kind", "")))
		else:
			result.append(str(entry))
	return result


# Match id for a node: the pool of its kind at [param tier], else the nearest lower tier, else any
# tier of the kind; a kind without any pool draws from every match of the chapter. Unused ids
# first; repeats (within the kind's pool) only when it is exhausted.
static func _draw_match(chapter: Dictionary, kind: String, tier: int, used: Array[String],
		rng: RandomNumberGenerator) -> String:
	var groups: Array[Array] = []
	var pools: Variant = chapter.get("pools", {})
	var by_tier: Dictionary = {}
	if typeof(pools) == TYPE_DICTIONARY and typeof((pools as Dictionary).get(kind)) == TYPE_DICTIONARY:
		by_tier = (pools as Dictionary)[kind]
	for t: int in range(tier, -1, -1):
		groups.append(_ids_of(by_tier.get(str(t), [])))
	var any_kind: Array = []
	for t_key: Variant in by_tier.keys():
		for id: Variant in _ids_of(by_tier[t_key]):
			if not any_kind.has(id):
				any_kind.append(id)
	groups.append(any_kind)
	if any_kind.is_empty():
		# The kind has no pool at all: any match of the chapter (never for kinds with a pool, so
		# boss / miniboss entries are not spent on battle nodes).
		groups.append(_ids_of(chapter.get("match_ids", [])))
	for group: Array in groups:
		var fresh: Array = []
		for id: Variant in group:
			if not used.has(str(id)):
				fresh.append(id)
		if not fresh.is_empty():
			return str(fresh[rng.randi_range(0, fresh.size() - 1)])
	for group: Array in groups:
		if not group.is_empty():
			return str(group[rng.randi_range(0, group.size() - 1)])
	push_warning("ChapterMapGen: chapter has no match for a %s node" % kind)
	return ""


static func _ids_of(raw: Variant) -> Array:
	var ids: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for id: Variant in raw as Array:
			ids.append(str(id))
	return ids

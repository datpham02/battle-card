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
## P2.3 (decision D10, spec phase2-misty-forest 5.5): `teach_after` ({match id: [match ids]}, ChaptersConfig) gates a
## match (the new elites): it may only stand after an EARLIER column every path must fight a listed match in (all its
## nodes are fights whose match id is in the list; e.g. the 1-node first column). The main draw ignores the gate (a
## gated elite is as likely as any other id of its pool / tier); then _teach_gated makes it hold: a drawn
## elite not yet taught FORCES the earliest earlier column of battle / danger nodes whose every node can take a
## teacher legal in its own pool (the node's kind at the column's tier, else the nearest lower tier) to such teachers
## (a node already holding one keeps it; two elites share a column through the intersection of their lists; after a
## forcing, a later battle / danger node that now repeats an earlier id is redrawn while its pool allows). Only
## when no column can teach does the elite give way to another match of the same pool / tier, as before. The forcing /
## fallback draws use their own rng stream (hash([run_seed, chapter id, "teach"])), so the main stream is the same
## as without the gate and a chapter without `teach_after` is generated exactly as before. The shop / event pass
## never replaces a node of a column that teaches a drawn elite, so the guarantee holds on every path.
## Design: design/game-brief.md "Run", design/reference/osfe-reference.md section 9.3.

const KIND_BATTLE: String = "battle"
const KIND_DANGER: String = "danger"
const KIND_TREASURE: String = "treasure"
const KIND_REST: String = "rest"
const KIND_MINIBOSS: String = "miniboss"
const KIND_BOSS: String = "boss"
## Story 033: the shop and event nodes (no match, empty match_id). Only [method _apply_special_nodes] places them.
const KIND_SHOP: String = "shop"
const KIND_EVENT: String = "event"
const KINDS: Array[String] = [KIND_BATTLE, KIND_DANGER, KIND_TREASURE, KIND_REST, KIND_MINIBOSS, KIND_BOSS, KIND_SHOP, KIND_EVENT]
## Story 033: kinds a shop / event may replace in the special column (optional fights, never rest / treasure / boss).
const REPLACEABLE_KINDS: Array[String] = [KIND_BATTLE, KIND_DANGER, KIND_MINIBOSS]
## Kinds that play a match (the others have an empty match_id).
const MATCH_KINDS: Array[String] = [KIND_BATTLE, KIND_DANGER, KIND_MINIBOSS, KIND_BOSS]
## P2.3: kinds of the nodes a teach_after elite may force to its teachers (ordinary fights, never an elite / boss).
const TEACH_KINDS: Array[String] = [KIND_BATTLE, KIND_DANGER]
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
	var lists: Dictionary = _teach_lists(chapter)
	# P2.3: the main draw lets gated elites in (see the class doc); _teach_gated fixes the map afterwards.
	var open_gate: Callable = Callable()
	if not lists.is_empty():
		open_gate = func(_id: String) -> bool: return true
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
				match_id = _draw_match(chapter, kind, tier, used, rng, open_gate)
				used.append(match_id)
			nodes.append({"kind": kind, "match_id": match_id})
		map.append({"index": ci, "tier": tier, "nodes": nodes})
	var teachers: Array[int] = []
	if not lists.is_empty():
		teachers = _teach_gated(map, chapter, run_seed, lists)
	_apply_special_nodes(map, chapter, run_seed, teachers)
	return map


## P2.3: true when [param id] may be drawn after the columns already in [param map]: no `teach_after` list for it in
## [param chapter], or an earlier column that teaches it (see the class doc).
static func is_taught(chapter: Dictionary, id: String, map: Array) -> bool:
	return _teaching_column(chapter, id, map) >= 0


# Index of the first column of [param map] whose every node is a fight with a match id in the teach_after list of
# [param id]; -1 when none; 0 when [param id] has no list (not gated).
static func _teaching_column(chapter: Dictionary, id: String, map: Array) -> int:
	var lists: Variant = chapter.get("teach_after", {})
	if typeof(lists) != TYPE_DICTIONARY or not (lists as Dictionary).has(id):
		return 0
	var teach: Array = (lists as Dictionary)[id] as Array
	for col: Variant in map:
		var nodes: Array = (col as Dictionary).get("nodes", []) as Array
		if nodes.is_empty():
			continue
		var all_teach: bool = true
		for node: Variant in nodes:
			var n: Dictionary = node as Dictionary
			if not MATCH_KINDS.has(str(n.get("kind", ""))) or not teach.has(str(n.get("match_id", ""))):
				all_teach = false
				break
		if all_teach:
			return int((col as Dictionary).get("index", 0))
	return -1


# The chapter's teach_after lists ({} when absent or not an object).
static func _teach_lists(chapter: Dictionary) -> Dictionary:
	var lists: Variant = chapter.get("teach_after", {})
	return lists as Dictionary if typeof(lists) == TYPE_DICTIONARY else {}


# P2.3: after the main draw, every gated elite of [param map] (column order) gets a teaching column before it: one
# that already teaches it, else the earliest forceable one (_force_teachers), else the elite is redrawn as another
# match of the same pool / tier (the old gate). Own rng stream. Returns the indices of the teaching columns (the shop /
# event pass keeps their nodes).
static func _teach_gated(map: Array[Dictionary], chapter: Dictionary, run_seed: int, lists: Dictionary) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, str(chapter.get("id", "")), "teach"]) & SEED_MASK
	var teachers: Array[int] = []
	# column index -> per node the ids it may still hold (the intersection of the lists of the elites it teaches).
	var allowed: Dictionary = {}
	for ci: int in map.size():
		var nodes: Array = map[ci]["nodes"]
		for ni: int in nodes.size():
			var id: String = str((nodes[ni] as Dictionary)["match_id"])
			if not lists.has(id):
				continue
			var teach: Array = lists[id] as Array
			var at: int = _teaching_column(chapter, id, map.slice(0, ci))
			if at >= 0:
				# A column that teaches on its own may still be re-forced for a later elite, within this elite's teachers.
				var keep: Array = []
				var col_nodes: Array = map[at]["nodes"]
				for k: int in col_nodes.size():
					var current: String = str((col_nodes[k] as Dictionary)["match_id"])
					var legal: Array = _pool_teachers(chapter, str((col_nodes[k] as Dictionary)["kind"]), int(map[at]["tier"]), teach)
					if not legal.has(current):
						legal.append(current)
					if allowed.has(at):
						var prior: Array = (allowed[at] as Array)[k] as Array
						legal = legal.filter(func(x: Variant) -> bool: return prior.has(x))
					keep.append(legal)
				allowed[at] = keep
			if at < 0:
				at = _force_teachers(map, ci, teach, chapter, allowed, rng)
			if at >= 0:
				if not teachers.has(at):
					teachers.append(at)
				continue
			# No earlier column can teach it: another match of the same pool / tier (the gate refuses untaught ids).
			var used: Array[String] = []
			for c: int in map.size():
				for k: int in (map[c]["nodes"] as Array).size():
					var other: String = str((map[c]["nodes"][k] as Dictionary)["match_id"])
					if (c != ci or k != ni) and not other.is_empty():
						used.append(other)
			var before: Array = map.slice(0, ci)
			var gate: Callable = func(x: String) -> bool: return _teaching_column(chapter, x, before) >= 0
			var kind: String = str((nodes[ni] as Dictionary)["kind"])
			nodes[ni] = {"kind": kind, "match_id": _draw_match(chapter, kind, int(map[ci]["tier"]), used, rng, gate)}
	return teachers


# Forces the earliest column before [param before] whose nodes are all TEACH_KINDS and can each hold an id of
# [param teach] legal in its pool (and still allowed by [param allowed], see _teach_gated) to such ids: a node already
# holding one keeps it, else one is drawn (ids not yet on the map first). Records the column's allowed ids. Returns
# its index, or -1 when no column qualifies (nothing changed).
static func _force_teachers(map: Array[Dictionary], before: int, teach: Array, chapter: Dictionary,
		allowed: Dictionary, rng: RandomNumberGenerator) -> int:
	for c: int in before:
		var nodes: Array = map[c]["nodes"]
		if nodes.is_empty():
			continue
		var picks: Array = []
		for ni: int in nodes.size():
			var n: Dictionary = nodes[ni]
			if not TEACH_KINDS.has(str(n["kind"])):
				break
			var legal: Array = _pool_teachers(chapter, str(n["kind"]), int(map[c]["tier"]), teach)
			if allowed.has(c):
				var still: Array = (allowed[c] as Array)[ni] as Array
				legal = legal.filter(func(x: Variant) -> bool: return still.has(x))
			if legal.is_empty():
				break
			picks.append(legal)
		if picks.size() != nodes.size():
			continue
		var used: Array[String] = []
		for col: Dictionary in map:
			for n: Variant in col["nodes"]:
				used.append(str((n as Dictionary)["match_id"]))
		var placed: Array[String] = []
		for ni: int in nodes.size():
			var legal_ids: Array = picks[ni]
			if legal_ids.has(str(nodes[ni]["match_id"])):
				continue
			var fresh: Array = legal_ids.filter(func(x: Variant) -> bool: return not used.has(str(x)))
			var source: Array = fresh if not fresh.is_empty() else legal_ids
			var pick: String = str(source[rng.randi_range(0, source.size() - 1)])
			nodes[ni] = {"kind": str(nodes[ni]["kind"]), "match_id": pick}
			used.append(pick)
			placed.append(pick)
		allowed[c] = picks
		_redraw_repeats(map, chapter, placed, allowed, rng)
		return c
	return -1


# Keeps "no repeat while the pool allows" after a forcing (the main draw chose its fresh ids against the map before
# the forcing): walking the map in order, a battle / danger node outside the teaching columns ([param allowed]) whose
# id already stood earlier is redrawn from its own pool, ids found anywhere else on the map counted as used first, then
# only the earlier ones; it keeps a repeat only when its pool has nothing left. No-op when nothing was [param placed].
static func _redraw_repeats(map: Array[Dictionary], chapter: Dictionary, placed: Array[String], allowed: Dictionary,
		rng: RandomNumberGenerator) -> void:
	if placed.is_empty():
		return
	var seen: Array[String] = []
	for j: int in map.size():
		var col_nodes: Array = map[j]["nodes"]
		for k: int in col_nodes.size():
			var nd: Dictionary = col_nodes[k]
			var id: String = str(nd["match_id"])
			if not allowed.has(j) and TEACH_KINDS.has(str(nd["kind"])) and seen.has(id):
				var others: Array[String] = seen.duplicate()
				for c2: int in range(j, map.size()):
					for k2: int in (map[c2]["nodes"] as Array).size():
						var other: String = str((map[c2]["nodes"][k2] as Dictionary)["match_id"])
						if (c2 != j or k2 != k) and not other.is_empty():
							others.append(other)
				id = _draw_match(chapter, str(nd["kind"]), int(map[j]["tier"]), others, rng)
				if seen.has(id):
					id = _draw_match(chapter, str(nd["kind"]), int(map[j]["tier"]), seen, rng)
				col_nodes[k] = {"kind": str(nd["kind"]), "match_id": id}
			if not id.is_empty():
				seen.append(id)


# The ids of [param teach] in the [param kind] pool at [param tier], else at the nearest lower tier that has one; a
# kind without any pool uses the chapter's match_ids (as _draw_match). [] when none.
static func _pool_teachers(chapter: Dictionary, kind: String, tier: int, teach: Array) -> Array:
	var pools: Variant = chapter.get("pools", {})
	var by_tier: Dictionary = {}
	if typeof(pools) == TYPE_DICTIONARY and typeof((pools as Dictionary).get(kind)) == TYPE_DICTIONARY:
		by_tier = (pools as Dictionary)[kind]
	if by_tier.is_empty():
		return _ids_of(chapter.get("match_ids", [])).filter(func(x: Variant) -> bool: return teach.has(x))
	for t: int in range(tier, -1, -1):
		var hit: Array = _ids_of(by_tier.get(str(t), [])).filter(func(x: Variant) -> bool: return teach.has(x))
		if not hit.is_empty():
			return hit
	return []


# Story 033: the SHOP / EVENT pass, after the whole map is built, on its own rng stream
# (hash([run_seed, chapter id, "special"])) so the rest of the map is the same as without it. Only with a
# `special_nodes` block in [param chapter] ({column, shop_weight, event_weight}; chapters.json
# `world.special_nodes` via ChaptersConfig.region_spec) and a map of >= 3 columns. In column `column`
# (default 1) one optional fight node (REPLACEABLE_KINDS) may become a shop and one an event, so a region
# has at most 1 shop and 1 event. Each is rolled by its weight (probability 0..1); `guarantee_shop` (set by
# ChaptersConfig.generate_region_map on the floors of the run's shop plan) makes the shop certain. A
# non-guaranteed shop / the event only replaces when 2 or more fights are left in the column (one fight is
# always kept); a guaranteed shop may take the last one. Both rolls are always drawn (stable stream).
static func _apply_special_nodes(map: Array[Dictionary], chapter: Dictionary, run_seed: int, keep_columns: Array[int] = []) -> void:
	var special: Variant = chapter.get("special_nodes")
	if typeof(special) != TYPE_DICTIONARY or map.size() < 3:
		return
	var column: int = clampi(int((special as Dictionary).get("column", 1)), 1, map.size() - 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, str(chapter.get("id", "")), "special"]) & SEED_MASK
	var shop_roll: float = rng.randf()
	var event_roll: float = rng.randf()
	var pick_roll: int = rng.randi()
	var want_shop: bool = bool(chapter.get("guarantee_shop", false)) \
			or shop_roll < float((special as Dictionary).get("shop_weight", 0.0))
	var want_event: bool = event_roll < float((special as Dictionary).get("event_weight", 0.0))
	var nodes: Array = map[column]["nodes"]
	var fights: Array[int] = []
	for i: int in nodes.size():
		if REPLACEABLE_KINDS.has(str((nodes[i] as Dictionary)["kind"])):
			fights.append(i)
	# P2.3: a column that taught a drawn elite keeps every node (each path must still fight a teacher there).
	if keep_columns.has(column):
		fights.clear()
	var min_left: int = 0 if bool(chapter.get("guarantee_shop", false)) else 1
	if want_shop and fights.size() > min_left:
		var at: int = fights[pick_roll % fights.size()]
		nodes[at] = {"kind": KIND_SHOP, "match_id": ""}
		fights.erase(at)
	if want_event and fights.size() > 1:
		var at2: int = fights[(pick_roll >> 8) % fights.size()]
		nodes[at2] = {"kind": KIND_EVENT, "match_id": ""}
		fights.erase(at2)


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
# P2.3: [param gate] (Callable(id) -> bool) removes the ids it refuses from every group before the draw (generate
# passes one that allows every id; _teach_gated one that reads the columns before the node); without a gate a match
# with a teach_after list is never drawn (callers outside generate: event fights).
static func _draw_match(chapter: Dictionary, kind: String, tier: int, used: Array[String],
		rng: RandomNumberGenerator, gate: Callable = Callable()) -> String:
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
	var lists: Variant = chapter.get("teach_after", {})
	if typeof(lists) == TYPE_DICTIONARY and not (lists as Dictionary).is_empty():
		for gi: int in groups.size():
			var kept: Array = []
			for id: Variant in groups[gi]:
				if not (lists as Dictionary).has(str(id)) or (gate.is_valid() and bool(gate.call(str(id)))):
					kept.append(id)
			groups[gi] = kept
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

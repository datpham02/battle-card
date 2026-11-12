class_name KiepRules
extends RefCounted
## Story 038: Kiep levels 1..10 (per character, stacking, harder only). Pure rules read from
## assets/data/kiep_levels.json; no nodes. Level k applies the rules of levels 1..k in order; level 0 is
## the game exactly as without Kiep (every function returns an equal copy / the base number).
## Rule `type`s are a fixed set in code, the numbers live in the JSON (schema: assets/data/schema.md
## `kiep_levels.json`). An unknown type warns and that rule is dropped (the level stays); a bad number keeps
## the documented default below with a warning. Stacked multipliers are bounded by the file's `clamp` block.

const DEFAULT_PATH: String = "res://assets/data/kiep_levels.json"
const SEED_MASK: int = 0x7fffffff
const SCOPE_REGION_BOSS: String = "region_boss"
const SCOPE_FINAL: String = "final"
## Fallback numbers (the shipped numbers live in kiep_levels.json, the file wins).
const DEFAULT_MULTS: Dictionary = {
	"node_weight": 2.0, "rest_heal_mult": 0.67, "player_drop_mult": 1.15, "gold_mult": 0.75,
	"boss_swing_mult": 0.909, "floor_heal_mult": 0.5, "max_hp_mult": 0.85, "shop_price_mult": 1.2,
}
## Fallback clamp bounds (same rule: the file wins).
const DEFAULT_CLAMP: Dictionary = {
	"node_weight_mult_max": 4.0, "rest_heal_mult_min": 0.25, "player_drop_mult_max": 1.5, "gold_mult_min": 0.4,
	"boss_swing_mult_min": 0.6, "floor_heal_mult_min": 0.25, "max_hp_mult_min": 0.4, "floor_shift_max": 2.0,
	"final_hp_mult_max": 1.5, "shop_price_mult_max": 2.0,
}
const DEFAULT_SHIFT: int = 1
const DEFAULT_FINAL_HP_MULT: float = 1.1
## The fixed rule types.
const TYPES: Array[String] = ["boss_extra_trait", "node_weight", "rest_heal_mult", "player_drop_mult", "gold_mult",
		"boss_swing_mult", "floor_heal_mult", "max_hp_mult", "floor_shift", "shop_price_mult"]

static var _shared: KiepRules = null

# Cleaned rows, ascending by level: {level, name_key, desc_key, rules: Array[{type, params}]}.
var _levels: Array[Dictionary] = []
var _clamp: Dictionary = DEFAULT_CLAMP.duplicate()
# SIM ONLY: > 0 = every level > 0 applies just this one level's rules.
var _only: int = 0


## The lazily loaded shared instance of the shipped kiep_levels.json.
static func shared() -> KiepRules:
	if _shared == null:
		_shared = load_from_file()
	return _shared


## Loads from a JSON file; never null (an empty rule set + warning when the file is missing or bad).
static func load_from_file(path: String = DEFAULT_PATH) -> KiepRules:
	if not FileAccess.file_exists(path):
		push_warning("KiepRules: file not found, no Kiep levels: %s" % path)
		return from_dictionary({})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("KiepRules: JSON root must be an object, no Kiep levels")
		return from_dictionary({})
	return from_dictionary(parsed as Dictionary)


## Builds from a dictionary (see schema.md). Never null.
static func from_dictionary(d: Dictionary) -> KiepRules:
	var k := KiepRules.new()
	var clamp_raw: Variant = d.get("clamp")
	if typeof(clamp_raw) == TYPE_DICTIONARY:
		for key: Variant in (clamp_raw as Dictionary).keys():
			if not DEFAULT_CLAMP.has(str(key)):
				push_warning("KiepRules: unknown clamp key '%s', ignored" % str(key))
				continue
			var v: Variant = (clamp_raw as Dictionary)[key]
			if _is_number(v) and float(v) > 0.0:
				k._clamp[str(key)] = float(v)
			else:
				push_warning("KiepRules: clamp '%s' must be a number > 0, default kept" % str(key))
	var rows: Variant = d.get("levels")
	if typeof(rows) != TYPE_ARRAY:
		return k
	var seen: Array[int] = []
	for row: Variant in rows as Array:
		if typeof(row) != TYPE_DICTIONARY or not _is_number((row as Dictionary).get("level")) \
				or int((row as Dictionary)["level"]) < 1:
			push_warning("KiepRules: a level row needs an integer level >= 1, skipped")
			continue
		var r: Dictionary = row as Dictionary
		var level: int = int(r["level"])
		if seen.has(level):
			push_warning("KiepRules: duplicate level %d, later row dropped" % level)
			continue
		seen.append(level)
		var rules: Array[Dictionary] = []
		var raw_rule: Variant = r.get("rule", [])
		var list: Array = raw_rule as Array if typeof(raw_rule) == TYPE_ARRAY else [raw_rule]
		for entry: Variant in list:
			var clean: Dictionary = _clean_rule(entry, level)
			if not clean.is_empty():
				rules.append(clean)
		k._levels.append({"level": level, "name_key": str(r.get("name_key", "")),
				"desc_key": str(r.get("desc_key", "")), "rules": rules})
	k._levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
	return k


static func _is_number(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v))


static func _clean_rule(entry: Variant, level: int) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		push_warning("KiepRules: level %d rule is not an object, dropped" % level)
		return {}
	var type: String = str((entry as Dictionary).get("type", ""))
	if not TYPES.has(type):
		push_warning("KiepRules: level %d has unknown rule type '%s', dropped" % [level, type])
		return {}
	var raw: Variant = (entry as Dictionary).get("params", {})
	var src: Dictionary = raw as Dictionary if typeof(raw) == TYPE_DICTIONARY else {}
	var params: Dictionary = {}
	match type:
		"boss_extra_trait":
			var pool: Array = []
			var raw_pool: Variant = src.get("trait_pool")
			if typeof(raw_pool) == TYPE_ARRAY:
				for t: Variant in raw_pool as Array:
					if typeof(t) == TYPE_DICTIONARY and typeof((t as Dictionary).get("id")) == TYPE_STRING \
							and str((t as Dictionary)["id"]) != "":
						var p: Variant = (t as Dictionary).get("params", {})
						pool.append({"id": str((t as Dictionary)["id"]),
								"params": (p as Dictionary).duplicate(true) if typeof(p) == TYPE_DICTIONARY else {}})
			if pool.is_empty():
				push_warning("KiepRules: level %d boss_extra_trait has no valid trait_pool, dropped" % level)
				return {}
			var scope: String = str(src.get("scope", SCOPE_REGION_BOSS))
			if scope != SCOPE_REGION_BOSS and scope != SCOPE_FINAL:
				push_warning("KiepRules: level %d scope '%s' unknown, region_boss used" % [level, scope])
				scope = SCOPE_REGION_BOSS
			var count: int = 1
			if _is_number(src.get("count")) and int(src["count"]) >= 1:
				count = int(src["count"])
			elif src.has("count"):
				push_warning("KiepRules: level %d count must be an integer >= 1, 1 kept" % level)
			params = {"trait_pool": pool, "scope": scope, "count": count}
		"node_weight":
			params["kind"] = str(src.get("kind", "danger"))
			params["mult"] = _mult(src, "mult", float(DEFAULT_MULTS["node_weight"]), type, level)
		"floor_shift":
			var shift: int = DEFAULT_SHIFT
			if _is_number(src.get("shift")) and int(src["shift"]) >= 0:
				shift = int(src["shift"])
			elif src.has("shift"):
				push_warning("KiepRules: level %d shift must be an integer >= 0, default kept" % level)
			params["shift"] = shift
			params["final_hp_mult"] = _mult(src, "final_hp_mult", DEFAULT_FINAL_HP_MULT, type, level)
		_:
			params["mult"] = _mult(src, "mult", float(DEFAULT_MULTS[type]), type, level)
	return {"type": type, "params": params}


static func _mult(src: Dictionary, key: String, fallback: float, type: String, level: int) -> float:
	if not src.has(key):
		return fallback
	if _is_number(src[key]) and float(src[key]) > 0.0:
		return float(src[key])
	push_warning("KiepRules: level %d %s.%s must be a number > 0, default %s kept" % [level, type, key, fallback])
	return fallback


## Number of valid levels (10 for the shipped file).
func max_level() -> int:
	return _levels.size()


## {level, name_key, desc_key, rules: Array[{type, params}]}; {} for level 0 or an unknown level.
func level_def(level: int) -> Dictionary:
	for row: Dictionary in _levels:
		if int(row["level"]) == level:
			return row.duplicate(true)
	return {}


## SIM ONLY: with [param level] > 0 every level > 0 applies just that level's own rules (a single-rule
## table, to measure one rule alone); 0 = normal stacking.
func set_only(level: int) -> void:
	_only = maxi(level, 0)


## The desc keys of levels 1..[param level] (the select screen's rule list).
func rules_text_keys(level: int) -> Array[String]:
	var keys: Array[String] = []
	for row: Dictionary in _levels:
		if int(row["level"]) <= level:
			keys.append(str(row["desc_key"]))
	return keys


# The rules active at [param level], in order.
func _active(level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if level <= 0:
		return out
	for row: Dictionary in _levels:
		var l: int = int(row["level"])
		if (_only > 0 and l == _only) or (_only <= 0 and l <= level):
			out.append_array(row["rules"] as Array[Dictionary])
	return out


# Product of the `mult` of every active rule of [param type], 1.0 when none.
func _product(level: int, type: String, key: String = "mult") -> float:
	var p: float = 1.0
	for rule: Dictionary in _active(level):
		if rule["type"] == type:
			p *= float((rule["params"] as Dictionary)[key])
	return p


func _has(level: int, type: String) -> bool:
	for rule: Dictionary in _active(level):
		if rule["type"] == type:
			return true
	return false


func _lo(clamp_key: String, v: float) -> float:
	return maxf(v, float(_clamp[clamp_key]))


func _hi(clamp_key: String, v: float) -> float:
	return minf(v, float(_clamp[clamp_key]))


## Returns a modified COPY of the RAW match dictionary [param match_cfg] (before RunConfig.from_dictionary).
## [param ctx]: {run_seed, floor, match_id, node_kind ("fight"|"danger"|"boss"|...), is_final}.
## Applies boss_extra_trait (seeded, never a duplicate; phased matches get it in every phase), boss_swing_mult
## (`swing_speed_mult` x; below 1 = faster windup) and player_drop_mult (new key `player_drop_interval_mult`).
func apply_match(match_cfg: Dictionary, level: int, ctx: Dictionary) -> Dictionary:
	var m: Dictionary = match_cfg.duplicate(true)
	if level <= 0:
		return m
	var is_final: bool = bool(ctx.get("is_final", false))
	var is_region_boss: bool = str(ctx.get("node_kind", "")) == "boss" and not is_final
	var seed_base: int = hash([int(ctx.get("run_seed", 0)), int(ctx.get("floor", 0)), str(ctx.get("match_id", ""))])
	var extra_index: int = 0
	for rule: Dictionary in _active(level):
		var params: Dictionary = rule["params"]
		match str(rule["type"]):
			"boss_extra_trait":
				var scope: String = str(params["scope"])
				if (scope == SCOPE_FINAL and is_final) or (scope == SCOPE_REGION_BOSS and is_region_boss):
					_add_extra_traits(m, params, seed_base + extra_index)
				extra_index += 1
	if _has(level, "boss_swing_mult"):
		m["swing_speed_mult"] = float(match_cfg.get("swing_speed_mult", 1.0)) * _lo("boss_swing_mult_min", _product(level, "boss_swing_mult"))
	if _has(level, "player_drop_mult"):
		m["player_drop_interval_mult"] = float(match_cfg.get("player_drop_interval_mult", 1.0)) * _hi("player_drop_mult_max", _product(level, "player_drop_mult"))
	return m


# Appends `count` seeded pool traits not already on the match (every phase of a phased match gets it).
func _add_extra_traits(m: Dictionary, params: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value & SEED_MASK
	var phases: Variant = m.get("phases")
	var phased: bool = typeof(phases) == TYPE_ARRAY and not (phases as Array).is_empty()
	for _i: int in int(params["count"]):
		var have: Array[String] = _trait_ids(m.get("traits"))
		if phased:
			for ph: Variant in phases as Array:
				if typeof(ph) == TYPE_DICTIONARY:
					have.append_array(_trait_ids((ph as Dictionary).get("traits")))
		var candidates: Array = []
		for t: Variant in params["trait_pool"] as Array:
			if not have.has(str((t as Dictionary)["id"])):
				candidates.append(t)
		if candidates.is_empty():
			return
		var pick: Dictionary = (candidates[rng.randi_range(0, candidates.size() - 1)] as Dictionary).duplicate(true)
		if phased:
			for ph: Variant in phases as Array:
				if typeof(ph) == TYPE_DICTIONARY:
					var list: Array = ((ph as Dictionary).get("traits", []) as Array).duplicate(true) \
							if typeof((ph as Dictionary).get("traits")) == TYPE_ARRAY else []
					list.append(pick.duplicate(true))
					(ph as Dictionary)["traits"] = list
		else:
			var own: Array = (m.get("traits", []) as Array).duplicate(true) if typeof(m.get("traits")) == TYPE_ARRAY else []
			own.append(pick)
			m["traits"] = own


static func _trait_ids(raw: Variant) -> Array[String]:
	var ids: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for t: Variant in raw as Array:
			if typeof(t) == TYPE_DICTIONARY:
				ids.append(str((t as Dictionary).get("id", "")))
	return ids


## The 0-based floor whose `floor_scaling` row RunConfig must use: floor_shift moves it up by the stacked
## shift (capped by `floor_shift_max`), never above [param world_floors] (the `final` row). == [param floor]
## when the rule is off or [param floor] is negative (no scaling).
func scaling_floor(floor: int, level: int, world_floors: int) -> int:
	if floor < 0 or not _has(level, "floor_shift"):
		return floor
	var shift: int = 0
	for rule: Dictionary in _active(level):
		if rule["type"] == "floor_shift":
			shift += int((rule["params"] as Dictionary)["shift"])
	shift = mini(shift, int(_clamp["floor_shift_max"]))
	return maxi(mini(floor + shift, world_floors), floor)


## Extra `{hp_mult}` on top of the scaling when floor_shift is on and [param floor] >= world_floors - 1
## (the last floor and the final match); {} otherwise.
func final_extra(floor: int, level: int, world_floors: int) -> Dictionary:
	if floor < world_floors - 1 or not _has(level, "floor_shift"):
		return {}
	return {"hp_mult": _hi("final_hp_mult_max", _product(level, "floor_shift", "final_hp_mult"))}


## A copy of the region map spec with node_weight applied: the weight of the node kind (danger) is
## multiplied in the branch columns (not the first, not the boss column). ChapterMapGen has no weight table:
## kinds are drawn uniformly from a column's `kinds` filler list, so the weight is the number of copies of
## the kind in that list (mult rounded, clamped by `node_weight_mult_max`).
func apply_map_spec(spec: Dictionary, level: int) -> Dictionary:
	var out: Dictionary = spec.duplicate(true)
	var columns: Variant = out.get("columns")
	if level <= 0 or typeof(columns) != TYPE_ARRAY:
		return out
	for rule: Dictionary in _active(level):
		if rule["type"] != "node_weight":
			continue
		var kind: String = str((rule["params"] as Dictionary)["kind"])
		var mult: float = _hi("node_weight_mult_max", _product_for_kind(level, kind))
		var copies: int = maxi(roundi(mult), 1)
		if copies <= 1:
			continue
		var cols: Array = columns as Array
		for ci: int in range(1, cols.size() - 1):
			if typeof(cols[ci]) != TYPE_DICTIONARY or typeof((cols[ci] as Dictionary).get("kinds")) != TYPE_ARRAY:
				continue
			var kinds: Array = (cols[ci] as Dictionary)["kinds"]
			var expanded: Array = []
			for entry: Variant in kinds:
				var name: String = str((entry as Dictionary).get("kind", "")) if typeof(entry) == TYPE_DICTIONARY else str(entry)
				expanded.append(entry)
				if name == kind:
					for _c: int in copies - 1:
						expanded.append(entry.duplicate(true) if typeof(entry) == TYPE_DICTIONARY else entry)
			(cols[ci] as Dictionary)["kinds"] = expanded
		break  # the stacked product already covers every node_weight rule of this kind
	return out


## World Map v2: the clamped `node_weight` product of [param kind] at [param level] (1.0 when none) — what
## [method apply_map_spec] uses to multiply a v1 column's kind entries; RegionMapGen multiplies the `peril` archetype's
## draw weight by the same number so Kiep 3 (danger x2) acts on a v2 map too. Read-only.
func node_weight_mult(kind: String, level: int) -> float:
	if level <= 0:
		return 1.0
	return _hi("node_weight_mult_max", _product_for_kind(level, kind))


func _product_for_kind(level: int, kind: String) -> float:
	var p: float = 1.0
	for rule: Dictionary in _active(level):
		if rule["type"] == "node_weight" and str((rule["params"] as Dictionary)["kind"]) == kind:
			p *= float((rule["params"] as Dictionary)["mult"])
	return p


## A copy of [param character] with max_hp x max_hp_mult (clamped by `max_hp_mult_min`, at least 1).
func apply_run_start(character: Dictionary, level: int) -> Dictionary:
	var c: Dictionary = character.duplicate(true)
	if _has(level, "max_hp_mult") and c.has("max_hp"):
		var mult: float = _lo("max_hp_mult_min", _product(level, "max_hp_mult"))
		c["max_hp"] = maxi(roundi(float(c["max_hp"]) * mult), 1)
	return c


## Rest-camp heal share [param base] x the stacked rest_heal_mult (clamped by `rest_heal_mult_min`).
func rest_heal_ratio(base: float, level: int) -> float:
	if not _has(level, "rest_heal_mult"):
		return base
	return base * _lo("rest_heal_mult_min", _product(level, "rest_heal_mult"))


## Between-floors heal share [param base] x the stacked floor_heal_mult (clamped by `floor_heal_mult_min`).
func floor_heal_ratio(base: float, level: int) -> float:
	if not _has(level, "floor_heal_mult"):
		return base
	return base * _lo("floor_heal_mult_min", _product(level, "floor_heal_mult"))


## Economy multiplier: [param key] "gold" (gold_mult, clamped >= `gold_mult_min`) or "shop_price"
## (shop_price_mult, clamped <= `shop_price_mult_max`); 1.0 when off or the key is unknown.
func economy_mult(key: String, level: int) -> float:
	match key:
		"gold":
			return _lo("gold_mult_min", _product(level, "gold_mult")) if _has(level, "gold_mult") else 1.0
		"shop_price":
			return _hi("shop_price_mult_max", _product(level, "shop_price_mult")) if _has(level, "shop_price_mult") else 1.0
	return 1.0

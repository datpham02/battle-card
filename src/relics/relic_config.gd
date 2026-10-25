class_name RelicConfig
extends RefCounted
## Relic data loaded from assets/data/relics.json (Story 032). Schema: assets/data/schema.md.
## A bad or missing file falls back to [constant DEFAULTS] (with a warning); bad entries are
## dropped with a warning, never a crash. The relic list itself has no fallback (empty).

const DEFAULT_PATH: String = "res://assets/data/relics.json"
## Rarity order from lowest to highest; `min_rarity` floors use it.
const RARITIES: Array[String] = ["common", "rare", "epic", "boss"]
const TAGS: Array[String] = ["negative", "stackable"]

## Fallback values when a key is absent or invalid (the file wins).
const DEFAULTS: Dictionary = {
	"rarity_weights": {"common": 60.0, "rare": 30.0, "epic": 10.0},
	"source_rules": {
		"treasure": {"count": 3, "min_rarity": "common"},
		"boss_kill": {"count": 1, "tiers": ["boss", "epic"]},
	},
	"relic_damage_mult_cap": 3.0,
}

## Normalised relic entries in file order: `{id, rarity, tags: Array[String], name_key, desc_key,
## script, params}`.
var relics: Array[Dictionary] = []
## rarity -> weight (>= 0) for the `treasure` draw; a missing rarity = 0.
var rarity_weights: Dictionary = {}
## source -> `{count, min_rarity}` (treasure) / `{count, tiers}` (boss_kill).
var source_rules: Dictionary = {}
## Cap of the product of all relic damage multipliers (>= 1).
var relic_damage_mult_cap: float = 3.0


## A config with only the defaults (no relics).
static func defaults() -> RelicConfig:
	return from_dictionary({})


## Loads a config from a JSON file. A missing/bad file gives the defaults (and a warning).
static func load_from_file(path: String = DEFAULT_PATH) -> RelicConfig:
	if not FileAccess.file_exists(path):
		push_warning("RelicConfig: file not found: %s, defaults used (no relics)" % path)
		return defaults()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("RelicConfig: JSON root of %s must be an object, defaults used (no relics)" % path)
		return defaults()
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing or invalid keys keep their defaults (warning).
static func from_dictionary(data: Dictionary) -> RelicConfig:
	var config := RelicConfig.new()
	config.rarity_weights = _read_weights(data.get("rarity_weights"))
	config.source_rules = _read_rules(data.get("source_rules"))
	var cap: Variant = data.get("relic_damage_mult_cap")
	if cap == null:
		config.relic_damage_mult_cap = float(DEFAULTS["relic_damage_mult_cap"])
	elif (typeof(cap) == TYPE_FLOAT or typeof(cap) == TYPE_INT) and float(cap) >= 1.0:
		config.relic_damage_mult_cap = float(cap)
	else:
		push_warning("RelicConfig: relic_damage_mult_cap must be a number >= 1, default used")
		config.relic_damage_mult_cap = float(DEFAULTS["relic_damage_mult_cap"])
	var seen: Dictionary = {}
	var list: Variant = data.get("relics", [])
	if typeof(list) != TYPE_ARRAY:
		push_warning("RelicConfig: `relics` must be an array, none loaded")
		return config
	for raw: Variant in list as Array:
		var entry: Dictionary = _read_relic(raw, seen)
		if not entry.is_empty():
			seen[entry["id"]] = true
			config.relics.append(entry)
	return config


## The normalised entry of [param relic_id], or {} when unknown.
func get_relic(relic_id: String) -> Dictionary:
	for entry: Dictionary in relics:
		if entry["id"] == relic_id:
			return entry
	return {}


## Every relic id in file order.
func ids() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in relics:
		out.append(str(entry["id"]))
	return out


## Index of [param rarity] in [constant RARITIES], or -1.
static func rarity_rank(rarity: String) -> int:
	return RARITIES.find(rarity)


## How many ids [param source] offers by its rule (`count`), or [param fallback] for an unknown source.
func source_count(source: String, fallback: int = 3) -> int:
	var rule: Variant = source_rules.get(source)
	if typeof(rule) == TYPE_DICTIONARY:
		return maxi(int((rule as Dictionary).get("count", fallback)), 1)
	return fallback


static func _read_weights(raw: Variant) -> Dictionary:
	var out: Dictionary = (DEFAULTS["rarity_weights"] as Dictionary).duplicate()
	if raw == null:
		return out
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("RelicConfig: rarity_weights must be an object, defaults used")
		return out
	out = {}
	for key: Variant in (raw as Dictionary).keys():
		var value: Variant = (raw as Dictionary)[key]
		if not RARITIES.has(str(key)) or (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT):
			push_warning("RelicConfig: rarity_weights entry '%s' ignored" % str(key))
			continue
		out[str(key)] = maxf(float(value), 0.0)
	return out


static func _read_rules(raw: Variant) -> Dictionary:
	var out: Dictionary = (DEFAULTS["source_rules"] as Dictionary).duplicate(true)
	if raw == null:
		return out
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("RelicConfig: source_rules must be an object, defaults used")
		return out
	for source: Variant in (raw as Dictionary).keys():
		var rule: Variant = (raw as Dictionary)[source]
		if typeof(rule) != TYPE_DICTIONARY:
			push_warning("RelicConfig: source_rules.%s must be an object, ignored" % str(source))
			continue
		var merged: Dictionary = {}
		if out.has(str(source)):
			merged = (out[str(source)] as Dictionary).duplicate(true)
		merged.merge((rule as Dictionary).duplicate(true), true)
		out[str(source)] = merged
	return out


static func _read_relic(raw: Variant, seen: Dictionary) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("RelicConfig: a relic entry is not an object, dropped")
		return {}
	var d: Dictionary = raw as Dictionary
	var id: String = str(d.get("id", ""))
	if id.is_empty():
		push_warning("RelicConfig: a relic without id, dropped")
		return {}
	if seen.has(id):
		push_warning("RelicConfig: duplicate relic id '%s', later one dropped" % id)
		return {}
	var rarity: String = str(d.get("rarity", ""))
	if not RARITIES.has(rarity):
		push_warning("RelicConfig: relic '%s' has unknown rarity '%s', dropped" % [id, rarity])
		return {}
	var tags: Array[String] = []
	var raw_tags: Variant = d.get("tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for tag: Variant in raw_tags as Array:
			if TAGS.has(str(tag)):
				tags.append(str(tag))
			else:
				push_warning("RelicConfig: relic '%s' has unknown tag '%s', ignored" % [id, str(tag)])
	var params: Variant = d.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		push_warning("RelicConfig: relic '%s' params must be an object, none used" % id)
		params = {}
	return {
		"id": id,
		"rarity": rarity,
		"tags": tags,
		"name_key": str(d.get("name_key", "relic.%s.name" % id)),
		"desc_key": str(d.get("desc_key", "relic.%s.desc" % id)),
		"script": str(d.get("script", id)),
		"params": (params as Dictionary).duplicate(true),
	}

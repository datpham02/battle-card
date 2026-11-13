class_name RegionRules
extends RefCounted
## World Map v2: assets/data/region_rules.json — which generator a region uses (`map_gen` v1 / v2), its ACTIVE rule
## (gauge, combat effect by gauge, reward tier bonus, warden hook), the modifier catalogue and each region's modifier
## pool. Never null after [method load_from_file]: a missing / bad file gives the built-in defaults (no rule anywhere,
## every region v1) with a warning, so the game runs exactly as before the file existed.
## Design: docs/design/world-map-v2/02-region-design.md section 1 and 2, 03 section 4.

const DEFAULT_PATH: String = "res://assets/data/region_rules.json"
const MAP_GEN_V1: String = "v1"
const MAP_GEN_V2: String = "v2"
## Node counts per depth of the approved layout (01 section B1): entry, 3 lanes, 3 lanes, hub, 3 lanes, approach, warden.
const DEFAULT_DEPTH_LAYOUT: Array[int] = [1, 3, 3, 1, 3, 2, 1]
## Match keys a combat patch may carry besides the hazard numbers and `traits` (04 section 2 / 07 C7).
## 2026-11-13 (Monster Skill Phase 1): `pattern_tempo_mult` so a modifier can reach a pattern-brain enemy (windup /
## cooldown / recovery, never warning_sec); RunConfig keeps the key only on `brain: pattern` matches.
const PATCH_MULT_KEYS: Array[String] = ["boss_drop_interval_mult", "player_drop_interval_mult", "boss_step_cooldown_mult", "swing_speed_mult", "pattern_tempo_mult"]
const PATCH_ADD_KEYS: Array[String] = ["boss_min_runes_add", "boss_defense_add"]

static var _shared: RegionRules = null

var depth_layout: Array[int] = DEFAULT_DEPTH_LAYOUT.duplicate()
var _modifiers: Dictionary = {}
var _rules: Dictionary = {}
var _regions: Dictionary = {}


## The process-wide instance (loaded once from [constant DEFAULT_PATH]); tests inject with [method set_shared].
static func shared() -> RegionRules:
	if _shared == null:
		_shared = load_from_file()
	return _shared


static func set_shared(rules: RegionRules) -> void:
	_shared = rules


static func load_from_file(path: String = DEFAULT_PATH) -> RegionRules:
	if not FileAccess.file_exists(path):
		push_warning("RegionRules: file not found, using defaults (no rules, every region v1): %s" % path)
		return from_dictionary({})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("RegionRules: JSON root must be an object, using defaults")
		return from_dictionary({})
	return from_dictionary(parsed as Dictionary)


## Builds from a dictionary (see the data file's _doc). Invalid parts are dropped with a warning.
static func from_dictionary(data: Dictionary) -> RegionRules:
	var r := RegionRules.new()
	var layout: Variant = data.get("depth_layout")
	if typeof(layout) == TYPE_ARRAY and not (layout as Array).is_empty():
		var cleaned: Array[int] = []
		var ok: bool = true
		for v: Variant in layout as Array:
			if int(v) <= 0:
				ok = false
			cleaned.append(maxi(int(v), 1))
		if ok and cleaned.size() >= 3:
			r.depth_layout = cleaned
		else:
			push_warning("RegionRules: depth_layout must be >= 3 positive counts, using the default")
	elif data.has("depth_layout"):
		push_warning("RegionRules: depth_layout must be a non-empty array, using the default")
	var mods: Variant = data.get("modifiers", {})
	if typeof(mods) == TYPE_DICTIONARY:
		for id: Variant in (mods as Dictionary).keys():
			var m: Variant = (mods as Dictionary)[id]
			if typeof(m) != TYPE_DICTIONARY:
				push_warning("RegionRules: modifier '%s' is not an object, dropped" % id)
				continue
			var md: Dictionary = (m as Dictionary).duplicate(true)
			if not (md.has("trait") or md.has("match") or md.has("arena")):
				push_warning("RegionRules: modifier '%s' has no trait / match / arena part, dropped" % id)
				continue
			r._modifiers[str(id)] = md
	var rules: Variant = data.get("rules", {})
	if typeof(rules) == TYPE_DICTIONARY:
		for id: Variant in (rules as Dictionary).keys():
			var rule: Variant = (rules as Dictionary)[id]
			if typeof(rule) == TYPE_DICTIONARY:
				r._rules[str(id)] = _clean_rule(str(id), rule as Dictionary)
			else:
				push_warning("RegionRules: rule '%s' is not an object, dropped" % id)
	var regions: Variant = data.get("regions", {})
	if typeof(regions) == TYPE_DICTIONARY:
		for id: Variant in (regions as Dictionary).keys():
			var reg: Variant = (regions as Dictionary)[id]
			if typeof(reg) != TYPE_DICTIONARY:
				continue
			var rd: Dictionary = reg as Dictionary
			var entry: Dictionary = {"map_gen": MAP_GEN_V1, "rule": "", "archetype_weights": {}, "modifier_pool": []}
			var gen: String = str(rd.get("map_gen", MAP_GEN_V1))
			if gen == MAP_GEN_V2:
				entry["map_gen"] = MAP_GEN_V2
			elif gen != MAP_GEN_V1:
				push_warning("RegionRules: region '%s' map_gen '%s' unknown, using v1" % [id, gen])
			var rule_id: String = str(rd.get("rule", ""))
			if not rule_id.is_empty() and not r._rules.has(rule_id):
				push_warning("RegionRules: region '%s' names unknown rule '%s', ignored" % [id, rule_id])
				rule_id = ""
			entry["rule"] = rule_id
			if typeof(rd.get("archetype_weights")) == TYPE_DICTIONARY:
				var w: Dictionary = {}
				for a: Variant in (rd["archetype_weights"] as Dictionary).keys():
					w[str(a)] = maxf(float((rd["archetype_weights"] as Dictionary)[a]), 0.0)
				entry["archetype_weights"] = w
			if typeof(rd.get("modifier_pool")) == TYPE_ARRAY:
				var pool: Array[String] = []
				for m: Variant in rd["modifier_pool"] as Array:
					if r._modifiers.has(str(m)):
						pool.append(str(m))
					else:
						push_warning("RegionRules: region '%s' modifier_pool names unknown modifier '%s', dropped" % [id, m])
				entry["modifier_pool"] = pool
			r._regions[str(id)] = entry
	return r


## "v1" or "v2" for [param region_id] (v1 for an unknown region).
func map_gen_for(region_id: String) -> String:
	return str((_regions.get(region_id, {}) as Dictionary).get("map_gen", MAP_GEN_V1))


## True when the region's map comes from RegionMapGen.
func uses_v2(region_id: String) -> bool:
	return map_gen_for(region_id) == MAP_GEN_V2


## Id of the region's active rule ("" = none).
func rule_id_for(region_id: String) -> String:
	return str((_regions.get(region_id, {}) as Dictionary).get("rule", ""))


## The cleaned rule record of [param rule_id] ({} when unknown): {id, name_key, desc_key, icon, gauge {min, max,
## start, per_kind}, map_effect, reward_effect, combat_effect {by_gauge}, warden_hook}.
func rule(rule_id: String) -> Dictionary:
	if not _rules.has(rule_id):
		return {}
	return (_rules[rule_id] as Dictionary).duplicate(true)


## The region's active rule record ({} when none).
func rule_for(region_id: String) -> Dictionary:
	return rule(rule_id_for(region_id))


## True when the rule has a gauge.
static func has_gauge(rule_rec: Dictionary) -> bool:
	return typeof(rule_rec.get("gauge")) == TYPE_DICTIONARY and not (rule_rec["gauge"] as Dictionary).is_empty()


## Gauge start value (0 without a gauge).
static func gauge_start(rule_rec: Dictionary) -> int:
	if not has_gauge(rule_rec):
		return 0
	return int((rule_rec["gauge"] as Dictionary).get("start", 0))


## Clamps [param value] to the gauge's range (unchanged without a gauge).
static func gauge_clamp(rule_rec: Dictionary, value: int) -> int:
	if not has_gauge(rule_rec):
		return value
	var g: Dictionary = rule_rec["gauge"]
	return clampi(value, int(g.get("min", 0)), int(g.get("max", 0)))


## The gauge after a node of [param kind] completes: value + per_kind[kind], clamped (unchanged without a gauge or an
## unlisted kind).
static func gauge_after(rule_rec: Dictionary, value: int, kind: String) -> int:
	if not has_gauge(rule_rec):
		return value
	var per: Dictionary = (rule_rec["gauge"] as Dictionary).get("per_kind", {})
	return gauge_clamp(rule_rec, value + int(per.get(kind, 0)))


## The combat patch row at [param gauge]: the exact `by_gauge` row, else the nearest lower one, else {}. Keys: hazard
## numbers (set), `*_mult` (multiply), `*_add` (add), `traits` (append). Deep copy.
static func combat_patch(rule_rec: Dictionary, gauge: int) -> Dictionary:
	var effect: Variant = rule_rec.get("combat_effect", {})
	if typeof(effect) != TYPE_DICTIONARY:
		return {}
	var rows: Variant = (effect as Dictionary).get("by_gauge", {})
	if typeof(rows) != TYPE_DICTIONARY:
		return {}
	var best: int = -1
	for key: Variant in (rows as Dictionary).keys():
		if str(key).is_valid_int() and int(str(key)) <= gauge and int(str(key)) > best:
			best = int(str(key))
	if best < 0:
		return {}
	return ((rows as Dictionary)[str(best)] as Dictionary).duplicate(true)


## Reward tier bonus at [param gauge] (0 without a reward effect or below its threshold).
static func tier_bonus(rule_rec: Dictionary, gauge: int) -> int:
	var effect: Variant = rule_rec.get("reward_effect", {})
	if typeof(effect) != TYPE_DICTIONARY:
		return 0
	var from: int = int((effect as Dictionary).get("tier_bonus_from_gauge", 999))
	return int((effect as Dictionary).get("tier_bonus", 0)) if gauge >= from else 0


## Warden hook: {trait_id: params to override} when gauge >= min_gauge, else {}.
static func warden_hook(rule_rec: Dictionary, gauge: int) -> Dictionary:
	var hook: Variant = rule_rec.get("warden_hook", {})
	if typeof(hook) != TYPE_DICTIONARY or (hook as Dictionary).is_empty():
		return {}
	if gauge < int((hook as Dictionary).get("min_gauge", 0)):
		return {}
	var params: Variant = (hook as Dictionary).get("trait_params", {})
	return (params as Dictionary).duplicate(true) if typeof(params) == TYPE_DICTIONARY else {}


## The modifier catalogue entry ({} when unknown).
func modifier(id: String) -> Dictionary:
	if not _modifiers.has(id):
		return {}
	return (_modifiers[id] as Dictionary).duplicate(true)


func modifier_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_modifiers.keys())
	out.sort()
	return out


## Ids the region's lane slots may draw from ([] when none).
func modifier_pool(region_id: String) -> Array[String]:
	var out: Array[String] = []
	out.assign((_regions.get(region_id, {}) as Dictionary).get("modifier_pool", []))
	return out


## Per-archetype weight overrides of the region ({} when none).
func archetype_weights(region_id: String) -> Dictionary:
	return ((_regions.get(region_id, {}) as Dictionary).get("archetype_weights", {}) as Dictionary).duplicate()


func region_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_regions.keys())
	out.sort()
	return out


static func _clean_rule(id: String, raw: Dictionary) -> Dictionary:
	var out: Dictionary = {"id": id, "name_key": str(raw.get("name_key", "")), "desc_key": str(raw.get("desc_key", "")),
		"icon": str(raw.get("icon", "")), "gauge": {}, "map_effect": {"type": "none"}, "reward_effect": {}, "combat_effect": {},
		"warden_hook": {}}
	var gauge: Variant = raw.get("gauge")
	if typeof(gauge) == TYPE_DICTIONARY:
		var g: Dictionary = gauge as Dictionary
		var lo: int = int(g.get("min", 0))
		var hi: int = int(g.get("max", 0))
		if hi < lo:
			push_warning("RegionRules: rule '%s' gauge max < min, using min" % id)
			hi = lo
		var per: Dictionary = {}
		if typeof(g.get("per_kind")) == TYPE_DICTIONARY:
			for k: Variant in (g["per_kind"] as Dictionary).keys():
				per[str(k)] = int((g["per_kind"] as Dictionary)[k])
		out["gauge"] = {"min": lo, "max": hi, "start": clampi(int(g.get("start", lo)), lo, hi), "per_kind": per}
	if typeof(raw.get("map_effect")) == TYPE_DICTIONARY:
		out["map_effect"] = (raw["map_effect"] as Dictionary).duplicate(true)
	if typeof(raw.get("reward_effect")) == TYPE_DICTIONARY:
		out["reward_effect"] = (raw["reward_effect"] as Dictionary).duplicate(true)
	var ce: Variant = raw.get("combat_effect")
	if typeof(ce) == TYPE_DICTIONARY:
		var rows: Dictionary = {}
		var by: Variant = (ce as Dictionary).get("by_gauge", {})
		if typeof(by) == TYPE_DICTIONARY:
			for key: Variant in (by as Dictionary).keys():
				if not str(key).is_valid_int():
					push_warning("RegionRules: rule '%s' by_gauge key '%s' is not an integer, dropped" % [id, key])
					continue
				var row: Variant = (by as Dictionary)[key]
				if typeof(row) == TYPE_DICTIONARY:
					rows[str(int(str(key)))] = _clean_patch(id, row as Dictionary)
		out["combat_effect"] = {"by_gauge": rows}
	if typeof(raw.get("warden_hook")) == TYPE_DICTIONARY:
		var hook: Dictionary = raw["warden_hook"] as Dictionary
		var params: Dictionary = {}
		if typeof(hook.get("trait_params")) == TYPE_DICTIONARY:
			for tid: Variant in (hook["trait_params"] as Dictionary).keys():
				var p: Variant = (hook["trait_params"] as Dictionary)[tid]
				if typeof(p) == TYPE_DICTIONARY:
					var pf: Dictionary = {}
					for k: Variant in (p as Dictionary).keys():
						var v: Variant = (p as Dictionary)[k]
						# Numbers as floats (the JSON type), so a loaded hook compares equal to a hand-written one.
						pf[str(k)] = float(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else v
					params[str(tid)] = pf
		out["warden_hook"] = {"min_gauge": int(hook.get("min_gauge", 0)), "trait_params": params}
	return out


# A combat patch row: hazard override numbers, *_mult / *_add numbers, traits (array of {id, params}); anything else
# is dropped with a warning so a typo never reaches a match silently.
static func _clean_patch(rule_id: String, raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in raw.keys():
		var k: String = str(key)
		var v: Variant = raw[key]
		if k == "traits":
			var traits: Array = []
			if typeof(v) == TYPE_ARRAY:
				for t: Variant in v as Array:
					if typeof(t) == TYPE_DICTIONARY and (t as Dictionary).has("id"):
						traits.append({"id": str((t as Dictionary)["id"]), "params": ((t as Dictionary).get("params", {}) as Dictionary).duplicate(true)})
			out["traits"] = traits
		elif RunConfig.HAZARD_OVERRIDE_KEYS.has(k) or PATCH_MULT_KEYS.has(k) or PATCH_ADD_KEYS.has(k):
			if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
				out[k] = float(v)
			else:
				push_warning("RegionRules: rule '%s' patch key '%s' must be a number, dropped" % [rule_id, k])
		else:
			push_warning("RegionRules: rule '%s' patch key '%s' is not a combat key, dropped" % [rule_id, k])
	return out

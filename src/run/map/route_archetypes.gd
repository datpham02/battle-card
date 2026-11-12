class_name RouteArchetypes
extends RefCounted
## World Map v2: assets/data/route_archetypes.json — the lane templates (03 section 3), the guarantee list, the hub
## and gamble kinds, the objective catalogue and the objective bonus. Never null after [method load_from_file]: a
## missing / bad file gives the built-in templates (the approved ones) with a warning.

const DEFAULT_PATH: String = "res://assets/data/route_archetypes.json"
const SAFE: String = "safe"
const TREASURE: String = "treasure"
const PERIL: String = "peril"
const ELITE: String = "elite"
const MYSTERY: String = "mystery"
## Slots per lane: depths 1, 2 and 4 of the default layout.
const SLOTS_PER_LANE: int = 3

static var _shared: RouteArchetypes = null

var _archetypes: Dictionary = {}
var _guarantee: Array[String] = [SAFE, TREASURE]
var _hub_kinds: Array[String] = ["rest", "event"]
var _gamble: Dictionary = {"kind": "miniboss", "min_floor": 2, "before_min_floor": "event"}
var _objectives: Dictionary = {}
var _objective_bonus: Dictionary = {"gold_mult": 1.3, "relic_offer": 1}


static func shared() -> RouteArchetypes:
	if _shared == null:
		_shared = load_from_file()
	return _shared


static func set_shared(a: RouteArchetypes) -> void:
	_shared = a


## The approved templates (03 section 3), used when the file is missing.
static func default_data() -> Dictionary:
	return {
		"archetypes": {
			SAFE: {"slots": [{"kind": "battle", "tier_delta": -1, "reward_tier": 1}, {"kind": "battle", "tier_delta": 0, "reward_tier": 1},
				{"kind": ["rest", "battle"], "tier_delta": 0, "reward_tier": 1}], "modifier_slots": [0, 0, 0], "min_floor": 1, "weight": 1.0},
			TREASURE: {"slots": [{"kind": "battle", "tier_delta": 0, "reward_tier": 1}, {"kind": "treasure", "reward_tier": 1},
				{"kind": ["battle", "forge"], "tier_delta": 0, "reward_tier": 1, "gold_mult": 1.5}], "modifier_slots": [0, 0, 0], "min_floor": 1, "weight": 1.0},
			PERIL: {"slots": [{"kind": "danger", "tier_delta": 0, "reward_tier": 2}, {"kind": "danger", "tier_delta": 0, "reward_tier": 2},
				{"kind": "danger", "tier_delta": 0, "reward_tier": 3, "objective": true}], "modifier_slots": [0, 1, 1], "min_floor": 2, "weight": 1.0},
			ELITE: {"slots": [{"kind": "battle", "tier_delta": 0, "reward_tier": 2}, {"kind": "miniboss", "tier_delta": 0, "reward_tier": 3, "relic_offer": 1},
				{"kind": "battle", "tier_delta": 0, "reward_tier": 2}], "modifier_slots": [0, 0, 1], "min_floor": 2, "weight": 0.8},
			MYSTERY: {"slots": [{"kind": "event", "reward_tier": 1}, {"kind": "battle", "tier_delta": 0, "reward_tier": 1},
				{"kind": ["event", "treasure"], "reward_tier": 1}], "modifier_slots": [0, 0, 0], "min_floor": 1, "weight": 0.8},
		},
		"guarantee": [SAFE, TREASURE],
		"hub_kinds": ["rest", "event"],
		"gamble": {"kind": "miniboss", "min_floor": 2, "before_min_floor": "event"},
		"objectives": {
			"no_hit_3": {"stat": "hits_taken", "op": "<=", "value": 3, "text_key": "objective.no_hit_3"},
			"joiner": {"stat": "joins", "op": ">=", "value": 2, "text_key": "objective.joiner"},
			"big_cast": {"stat": "max_cast_cells", "op": ">=", "value": 4, "text_key": "objective.big_cast"},
			"vent_dancer": {"stat": "vents_dodged", "op": ">=", "value": 2, "text_key": "objective.vent_dancer", "regions": ["hellfire"]},
		},
		"objective_bonus": {"gold_mult": 1.3, "relic_offer": 1},
	}


static func load_from_file(path: String = DEFAULT_PATH) -> RouteArchetypes:
	if not FileAccess.file_exists(path):
		push_warning("RouteArchetypes: file not found, using the built-in templates: %s" % path)
		return from_dictionary(default_data())
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("RouteArchetypes: JSON root must be an object, using the built-in templates")
		return from_dictionary(default_data())
	return from_dictionary(parsed as Dictionary)


## Builds from a dictionary; a template with no valid slots is dropped (warning); no valid template at all = defaults.
static func from_dictionary(data: Dictionary) -> RouteArchetypes:
	var a := RouteArchetypes.new()
	var raw: Variant = data.get("archetypes", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for id: Variant in (raw as Dictionary).keys():
			var t: Variant = (raw as Dictionary)[id]
			if typeof(t) != TYPE_DICTIONARY:
				push_warning("RouteArchetypes: '%s' is not an object, dropped" % id)
				continue
			var cleaned: Dictionary = _clean_template(str(id), t as Dictionary)
			if cleaned.is_empty():
				continue
			a._archetypes[str(id)] = cleaned
	if a._archetypes.is_empty():
		push_warning("RouteArchetypes: no valid archetype, using the built-in templates")
		return from_dictionary(default_data())
	if typeof(data.get("guarantee")) == TYPE_ARRAY:
		var g: Array[String] = []
		for id: Variant in data["guarantee"] as Array:
			if a._archetypes.has(str(id)):
				g.append(str(id))
		if not g.is_empty():
			a._guarantee = g
	if typeof(data.get("hub_kinds")) == TYPE_ARRAY:
		var h: Array[String] = []
		for k: Variant in data["hub_kinds"] as Array:
			if MapGraph.KINDS.has(str(k)):
				h.append(str(k))
		if not h.is_empty():
			a._hub_kinds = h
	if typeof(data.get("gamble")) == TYPE_DICTIONARY:
		var g: Dictionary = data["gamble"]
		a._gamble = {"kind": str(g.get("kind", "miniboss")), "min_floor": maxi(int(g.get("min_floor", 2)), 1),
			"before_min_floor": str(g.get("before_min_floor", "event"))}
	if typeof(data.get("objectives")) == TYPE_DICTIONARY:
		for id: Variant in (data["objectives"] as Dictionary).keys():
			var o: Variant = (data["objectives"] as Dictionary)[id]
			if typeof(o) == TYPE_DICTIONARY and (o as Dictionary).has("stat"):
				var od: Dictionary = o as Dictionary
				var regions: Array[String] = []
				if typeof(od.get("regions")) == TYPE_ARRAY:
					for r: Variant in od["regions"] as Array:
						regions.append(str(r))
				a._objectives[str(id)] = {"id": str(id), "stat": str(od["stat"]), "op": str(od.get("op", ">=")),
					"value": float(od.get("value", 0)), "text_key": str(od.get("text_key", "")), "regions": regions}
	if typeof(data.get("objective_bonus")) == TYPE_DICTIONARY:
		var b: Dictionary = data["objective_bonus"]
		a._objective_bonus = {"gold_mult": maxf(float(b.get("gold_mult", 1.3)), 1.0), "relic_offer": maxi(int(b.get("relic_offer", 1)), 0)}
	return a


func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_archetypes.keys())
	out.sort()
	return out


## The cleaned template ({} when unknown): {slots: [{kind: Array[String], tier_delta, reward_tier, gold_mult,
## relic_offer, objective}], modifier_slots: Array[int], min_floor, weight}.
func template(id: String) -> Dictionary:
	if not _archetypes.has(id):
		return {}
	return (_archetypes[id] as Dictionary).duplicate(true)


## Draw weight of [param id] with a region's overrides applied (0 when unknown).
func weight(id: String, overrides: Dictionary = {}) -> float:
	if not _archetypes.has(id):
		return 0.0
	if overrides.has(id):
		return maxf(float(overrides[id]), 0.0)
	return float((_archetypes[id] as Dictionary)["weight"])


func min_floor(id: String) -> int:
	if not _archetypes.has(id):
		return 1
	return int((_archetypes[id] as Dictionary)["min_floor"])


## Archetype ids at least one of which every map must hold.
func guarantee() -> Array[String]:
	return _guarantee.duplicate()


func hub_kinds() -> Array[String]:
	return _hub_kinds.duplicate()


## {kind, min_floor, before_min_floor}: the gamble slot's kind from min_floor on, the other kind before it.
func gamble() -> Dictionary:
	return _gamble.duplicate()


func objective(id: String) -> Dictionary:
	if not _objectives.has(id):
		return {}
	return (_objectives[id] as Dictionary).duplicate(true)


## Objective ids legal in [param region_id] (an objective with a `regions` list is limited to those).
func objective_ids(region_id: String) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _objectives.keys():
		var regions: Array = (_objectives[id] as Dictionary)["regions"]
		if regions.is_empty() or regions.has(region_id):
			out.append(str(id))
	out.sort()
	return out


func objective_bonus() -> Dictionary:
	return _objective_bonus.duplicate()


static func _clean_template(id: String, raw: Dictionary) -> Dictionary:
	var slots: Array = []
	var raw_slots: Variant = raw.get("slots", [])
	if typeof(raw_slots) == TYPE_ARRAY:
		for s: Variant in raw_slots as Array:
			if typeof(s) != TYPE_DICTIONARY:
				continue
			var sd: Dictionary = s as Dictionary
			var kinds: Array[String] = []
			var k: Variant = sd.get("kind", "battle")
			if typeof(k) == TYPE_ARRAY:
				for x: Variant in k as Array:
					if MapGraph.KINDS.has(str(x)):
						kinds.append(str(x))
			elif MapGraph.KINDS.has(str(k)):
				kinds.append(str(k))
			if kinds.is_empty():
				push_warning("RouteArchetypes: '%s' slot %d has no known kind, dropped" % [id, slots.size()])
				continue
			slots.append({"kind": kinds, "tier_delta": clampi(int(sd.get("tier_delta", 0)), -2, 2),
				"reward_tier": clampi(int(sd.get("reward_tier", 1)), 1, 3), "gold_mult": maxf(float(sd.get("gold_mult", 1.0)), 0.0),
				"relic_offer": maxi(int(sd.get("relic_offer", 0)), 0), "objective": bool(sd.get("objective", false))})
	if slots.size() != SLOTS_PER_LANE:
		push_warning("RouteArchetypes: '%s' needs %d slots, has %d, dropped" % [id, SLOTS_PER_LANE, slots.size()])
		return {}
	var mod_slots: Array[int] = []
	var raw_mods: Variant = raw.get("modifier_slots", [])
	if typeof(raw_mods) == TYPE_ARRAY:
		for m: Variant in raw_mods as Array:
			mod_slots.append(clampi(int(m), 0, 3))
	while mod_slots.size() < SLOTS_PER_LANE:
		mod_slots.append(0)
	return {"id": id, "slots": slots, "modifier_slots": mod_slots.slice(0, SLOTS_PER_LANE),
		"min_floor": maxi(int(raw.get("min_floor", 1)), 1), "weight": maxf(float(raw.get("weight", 1.0)), 0.0)}

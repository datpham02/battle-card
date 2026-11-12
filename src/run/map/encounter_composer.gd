class_name EncounterComposer
extends RefCounted
## World Map v2 encounter profiles (docs/design/world-map-v2/03-encounter-system.md). Pure, static, draws nothing: the
## generator already wrote `match_id`, `modifiers`, `objective` and `reward_tier` on the node; this class turns them,
## plus the region rule at the current gauge, into (a) a PATCH for the raw match dictionary that
## [method RunConfig.from_node] applies after the danger traits and before Kiep, (b) the PREVIEW the map shows, (c) the
## objective check on the match stats. Every patch key is one the combat already reads: `traits` (BossTrait entries),
## `RunConfig.HAZARD_OVERRIDE_KEYS` numbers, `*_mult` match keys (multiplied) and `boss_min_runes_add` /
## `boss_defense_add` (resolved into the match keys), `arena.variant`. Nothing else can reach a match.

const KEY_MATCH_PATCH: String = "match_patch"
const KEY_ARENA_PATCH: String = "arena_patch"
const KEY_TRAIT_PARAMS: String = "trait_params"


## The profile of [param node] (a MapGraph node record) fought in [param region_id] at [param gauge]:
## {match_patch, arena_patch, objective ({} or {id, stat, op, value, text_key}), reward_tier (after the rule's bonus,
## 1..3; 1 for non-fight kinds), modifiers (ids as on the node, unknown ones dropped), rule_id, gauge, is_warden}.
static func profile(node: Dictionary, region_id: String, gauge: int, rules: RegionRules = null, archetypes: RouteArchetypes = null) -> Dictionary:
	var r: RegionRules = rules if rules != null else RegionRules.shared()
	var a: RouteArchetypes = archetypes if archetypes != null else RouteArchetypes.shared()
	var kind: String = str(node.get("kind", ""))
	var is_fight: bool = MapGraph.MATCH_KINDS.has(kind)
	var is_warden: bool = str(node.get("slot", "")) == MapGraph.SLOT_WARDEN
	var rule: Dictionary = r.rule_for(region_id)
	var patch: Dictionary = {}
	var arena: Dictionary = {}
	var mods: Array[String] = []
	if is_fight:
		var raw_mods: Variant = node.get("modifiers", [])
		if typeof(raw_mods) == TYPE_ARRAY:
			for id: Variant in raw_mods as Array:
				var cat: Dictionary = r.modifier(str(id))
				if cat.is_empty():
					continue
				mods.append(str(id))
				if cat.has("trait") and typeof(cat["trait"]) == TYPE_DICTIONARY:
					_merge_patch(patch, {"traits": [cat["trait"]]})
				if cat.has("match") and typeof(cat["match"]) == TYPE_DICTIONARY:
					_merge_patch(patch, cat["match"] as Dictionary)
				if cat.has("arena") and typeof(cat["arena"]) == TYPE_DICTIONARY:
					for k: Variant in (cat["arena"] as Dictionary).keys():
						arena[str(k)] = (cat["arena"] as Dictionary)[k]
		if not rule.is_empty():
			_merge_patch(patch, RegionRules.combat_patch(rule, gauge))
			if is_warden:
				var hook: Dictionary = RegionRules.warden_hook(rule, gauge)
				if not hook.is_empty():
					patch[KEY_TRAIT_PARAMS] = hook
	var objective: Dictionary = {}
	var oid: String = str(node.get("objective", ""))
	if is_fight and not oid.is_empty():
		objective = a.objective(oid)
	return {
		KEY_MATCH_PATCH: patch, KEY_ARENA_PATCH: arena, "objective": objective,
		"reward_tier": reward_tier_for(node, rule, gauge), "modifiers": mods,
		"rule_id": str(rule.get("id", "")), "gauge": gauge, "is_warden": is_warden,
	}


## The node's reward tier at [param gauge]: the generator's tier plus the rule's bonus, capped at 3; 1 for a non-fight.
static func reward_tier_for(node: Dictionary, rule: Dictionary, gauge: int) -> int:
	if not MapGraph.MATCH_KINDS.has(str(node.get("kind", ""))):
		return 1
	var tier: int = clampi(int(node.get("reward_tier", 1)), 1, 3)
	if not rule.is_empty():
		tier += RegionRules.tier_bonus(rule, gauge)
	return clampi(tier, 1, 3)


## Applies [param prof]'s patches to the RAW match dictionary [param raw] (before RunConfig._clean_match): traits are
## appended unless an entry with the same id exists (then only `trait_params` overrides its params), hazard numbers
## are set, `*_mult` keys multiply the match's value (default 1), `*_add` keys resolve into `boss_min_runes` /
## `boss_defense`, `arena_patch.variant` sets the arena's variant flag. Unknown keys are ignored with a warning.
static func apply_to_raw(raw: Dictionary, prof: Dictionary) -> void:
	var patch: Dictionary = prof.get(KEY_MATCH_PATCH, {}) if typeof(prof.get(KEY_MATCH_PATCH)) == TYPE_DICTIONARY else {}
	var traits: Array = (raw.get("traits", []) as Array).duplicate(true) if typeof(raw.get("traits")) == TYPE_ARRAY else []
	for key: Variant in patch.keys():
		var k: String = str(key)
		var v: Variant = patch[key]
		if k == "traits":
			if typeof(v) != TYPE_ARRAY:
				continue
			for t: Variant in v as Array:
				if typeof(t) != TYPE_DICTIONARY:
					continue
				var tid: String = str((t as Dictionary).get("id", ""))
				if tid.is_empty() or _trait_index(traits, tid) >= 0:
					continue
				traits.append({"id": tid, "params": ((t as Dictionary).get("params", {}) as Dictionary).duplicate(true)})
		elif k == KEY_TRAIT_PARAMS:
			if typeof(v) != TYPE_DICTIONARY:
				continue
			for tid: Variant in (v as Dictionary).keys():
				var at: int = _trait_index(traits, str(tid))
				if at < 0:
					continue
				var entry: Dictionary = traits[at]
				var params: Dictionary = (entry.get("params", {}) as Dictionary).duplicate(true) if typeof(entry.get("params")) == TYPE_DICTIONARY else {}
				for pk: Variant in ((v as Dictionary)[tid] as Dictionary).keys():
					params[str(pk)] = ((v as Dictionary)[tid] as Dictionary)[pk]
				entry["params"] = params
				traits[at] = entry
		elif RunConfig.HAZARD_OVERRIDE_KEYS.has(k):
			raw[k] = float(v)
		elif k.ends_with("_mult"):
			raw[k] = float(raw.get(k, 1.0)) * float(v)
		elif k == "boss_min_runes_add":
			raw["boss_min_runes"] = maxi(int(raw.get("boss_min_runes", 0)) + int(v), 0)
		elif k == "boss_defense_add":
			raw["boss_defense"] = maxf(float(raw.get("boss_defense", 0.0)) + float(v), 0.0)
		else:
			push_warning("EncounterComposer: patch key '%s' is not a combat key, ignored" % k)
	raw["traits"] = traits
	var arena_patch: Dictionary = prof.get(KEY_ARENA_PATCH, {}) if typeof(prof.get(KEY_ARENA_PATCH)) == TYPE_DICTIONARY else {}
	if not arena_patch.is_empty():
		var arena: Dictionary = (raw.get("arena", {}) as Dictionary).duplicate(true) if typeof(raw.get("arena")) == TYPE_DICTIONARY else {}
		for k: Variant in arena_patch.keys():
			arena[str(k)] = arena_patch[k]
		raw["arena"] = arena


## True when the match [param stats] (CombatView.get_match_stats) meet [param objective]; a missing counter never
## meets it; {} is never met.
static func objective_met(objective: Dictionary, stats: Dictionary) -> bool:
	if objective.is_empty() or not objective.has("stat"):
		return false
	var stat: String = str(objective["stat"])
	if not stats.has(stat):
		return false
	var have: float = float(stats[stat])
	var want: float = float(objective.get("value", 0))
	match str(objective.get("op", ">=")):
		">=": return have >= want
		"<=": return have <= want
		">": return have > want
		"<": return have < want
		"==": return is_equal_approx(have, want)
	return false


## What the map shows for [param node] (03 section 7): {node_id, kind, slot, archetype, reward_tier, modifiers
## ([{id, icon, text_key}]), objective_text_key, enemy_name_key, enemy_desc_key, arena_shape, hidden, gauge,
## gauge_after}. With [param hidden] the enemy, modifiers and arena are blanked (kind, archetype, tier stay).
static func preview(node: Dictionary, prof: Dictionary, region_id: String, hidden: bool, chapters: ChaptersConfig,
		graph: MapGraph = null, rules: RegionRules = null) -> Dictionary:
	var r: RegionRules = rules if rules != null else RegionRules.shared()
	var kind: String = str(node.get("kind", ""))
	var out: Dictionary = {
		"node_id": str(node.get("id", "")), "kind": kind, "slot": str(node.get("slot", "")),
		"archetype": graph.archetype_of(str(node.get("id", ""))) if graph != null else "",
		"reward_tier": int(prof.get("reward_tier", 1)), "modifiers": [], "objective_text_key": "",
		"enemy_name_key": "", "enemy_desc_key": "", "arena_shape": "", "hidden": hidden,
		"gauge": int(prof.get("gauge", 0)), "gauge_after": int(prof.get("gauge", 0)),
		"gold_mult": float(node.get("gold_mult", 1.0)), "relic_offer": int(node.get("relic_offer", 0)),
	}
	var rule: Dictionary = r.rule_for(region_id)
	if not rule.is_empty():
		out["gauge_after"] = RegionRules.gauge_after(rule, int(prof.get("gauge", 0)), kind)
	if hidden:
		return out
	var objective: Dictionary = prof.get("objective", {})
	if not objective.is_empty():
		out["objective_text_key"] = str(objective.get("text_key", ""))
	for id: Variant in prof.get("modifiers", []):
		var cat: Dictionary = r.modifier(str(id))
		(out["modifiers"] as Array).append({"id": str(id), "icon": str(cat.get("icon", "")), "text_key": str(cat.get("text_key", ""))})
	var match_id: String = str(node.get("match_id", ""))
	if not match_id.is_empty() and chapters != null:
		var raw: Dictionary = chapters.get_match_raw(chapters.region_index(region_id), match_id)
		out["enemy_name_key"] = str(raw.get("name_key", ""))
		out["enemy_desc_key"] = str(raw.get("desc_key", ""))
		if typeof(raw.get("arena")) == TYPE_DICTIONARY:
			out["arena_shape"] = str((raw["arena"] as Dictionary).get("shape", ""))
	return out


static func _trait_index(traits: Array, id: String) -> int:
	for i: int in traits.size():
		if typeof(traits[i]) == TYPE_DICTIONARY and str((traits[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


# Merges one patch row into [param into]: traits append (dedupe by id), *_mult multiply, *_add add, others set.
static func _merge_patch(into: Dictionary, row: Dictionary) -> void:
	for key: Variant in row.keys():
		var k: String = str(key)
		var v: Variant = row[key]
		if k == "traits":
			if typeof(v) != TYPE_ARRAY:
				continue
			var list: Array = into.get("traits", [])
			for t: Variant in v as Array:
				if typeof(t) == TYPE_DICTIONARY and _trait_index(list, str((t as Dictionary).get("id", ""))) < 0:
					list.append((t as Dictionary).duplicate(true))
			into["traits"] = list
		elif k.ends_with("_mult"):
			into[k] = float(into.get(k, 1.0)) * float(v)
		elif k.ends_with("_add"):
			into[k] = float(into.get(k, 0.0)) + float(v)
		else:
			into[k] = v

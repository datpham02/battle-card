class_name RewardRoller
extends RefCounted
## Pure, seeded card-reward roll (Story 019, extended by Story 022). Config: assets/data/rewards.json
## (schema.md). Pool = every `implemented` card; weight = rarity weight only (Story 020: no class
## tags), where the rarity weights drift with the run's luck (Story 022). A card whose deck level
## already equals max_card_level is not offered unless the pool would then have fewer than
## offer_count candidates. The offer is a weighted draw WITHOUT replacement.

const DEFAULT_PATH: String = "res://assets/data/rewards.json"


## Built-in defaults (also the shape of a validated config).
static func default_config() -> Dictionary:
	return {
		"offer_count": 3,
		"rarity_weights": {"common": 70.0, "rare": 25.0, "epic": 5.0},
		"rarity_weights_at_luck": {"0": [70.0, 25.0, 5.0], "70": [31.0, 35.0, 34.0]},
		"allow_skip": true,
		"allow_remove": true,
		"min_deck_size": 4,
		"max_card_level": 3,
		"offer_upgrades": true,
		"pool_excludes_defaults": false,
		"starting_removals": 1,
		"luck_start": 0.0,
		"luck_per_node": 1.0,
		"rest_heal_ratio": 0.3,
		"rest_forge_levels": 1,
		"node_rewards": {
			"battle": {"offers": 3, "min_rarity": "common", "free": false, "removal_token": false},
			"danger": {"offers": 3, "min_rarity": "common", "free": false, "removal_token": false},
			"treasure": {"offers": 3, "min_rarity": "common", "free": true, "removal_token": false},
			"miniboss": {"offers": 3, "min_rarity": "rare", "free": false, "removal_token": false},
			"boss": {"offers": 3, "min_rarity": "common", "free": false, "removal_token": true},
			"rest": {"offers": 0, "min_rarity": "common", "free": false, "removal_token": false},
			"shop": {"offers": 0, "min_rarity": "common", "free": false, "removal_token": false},
			"event": {"offers": 0, "min_rarity": "common", "free": false, "removal_token": false},
		},
	}


## Loads and validates [param path]. Never fails: missing or bad file gives defaults (warning).
static func load_config(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("RewardRoller: %s missing, using defaults" % path)
		return default_config()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("RewardRoller: %s is not a JSON object, using defaults" % path)
		return default_config()
	return clean_config(parsed as Dictionary)


## Validates a parsed config dictionary over the defaults (bad values keep the default).
static func clean_config(data: Dictionary) -> Dictionary:
	var result: Dictionary = default_config()
	if data.has("offer_count"):
		result["offer_count"] = maxi(int(data["offer_count"]), 1)
	if data.has("min_deck_size"):
		result["min_deck_size"] = maxi(int(data["min_deck_size"]), 1)
	if data.has("max_card_level"):
		result["max_card_level"] = clampi(int(data["max_card_level"]), 1, SkillConfig.MAX_LEVEL)
	if data.has("starting_removals"):
		result["starting_removals"] = maxi(int(data["starting_removals"]), 0)
	if data.has("rest_forge_levels"):
		result["rest_forge_levels"] = maxi(int(data["rest_forge_levels"]), 1)
	if data.has("luck_start"):
		result["luck_start"] = maxf(float(data["luck_start"]), 0.0)
	if data.has("luck_per_node"):
		result["luck_per_node"] = maxf(float(data["luck_per_node"]), 0.0)
	if data.has("rest_heal_ratio"):
		result["rest_heal_ratio"] = clampf(float(data["rest_heal_ratio"]), 0.0, 1.0)
	for key: String in ["allow_remove", "offer_upgrades", "allow_skip", "pool_excludes_defaults"]:
		if data.has(key):
			result[key] = bool(data[key])
	var raw: Variant = data.get("rarity_weights")
	if typeof(raw) == TYPE_DICTIONARY:
		var weights: Dictionary = {}
		for rarity: String in SkillConfig.RARITIES:
			weights[rarity] = maxf(float((raw as Dictionary).get(rarity, 0.0)), 0.0)
		result["rarity_weights"] = weights
		# Without explicit luck anchors a custom rarity_weights holds at every luck.
		result["rarity_weights_at_luck"] = {"0": [weights["common"], weights["rare"], weights["epic"]]}
	elif raw != null:
		push_warning("RewardRoller: rarity_weights must be an object, using defaults")
	if data.has("rarity_weights_at_luck"):
		var anchors: Dictionary = _clean_anchors(data["rarity_weights_at_luck"])
		if anchors.is_empty():
			push_warning("RewardRoller: rarity_weights_at_luck has no valid anchor, ignored")
		else:
			result["rarity_weights_at_luck"] = anchors
	if data.has("node_rewards"):
		if typeof(data["node_rewards"]) == TYPE_DICTIONARY:
			var table: Dictionary = result["node_rewards"]
			for kind: String in table.keys():
				var entry: Variant = (data["node_rewards"] as Dictionary).get(kind)
				if typeof(entry) == TYPE_DICTIONARY:
					table[kind] = _clean_node_reward(entry as Dictionary, table[kind])
		else:
			push_warning("RewardRoller: node_rewards must be an object, using defaults")
	return result


## Card-pick spec of a map node [param kind] from [param config]:
## {"offers": int, "min_rarity": String, "free": bool, "removal_token": bool}. offers 0 = no card
## (rest). An unknown kind gives the battle entry (warning).
static func reward_for_node(kind: String, config: Dictionary) -> Dictionary:
	var table: Dictionary = clean_config(config)["node_rewards"]
	var key: String = kind
	if not table.has(key):
		push_warning("RewardRoller: unknown node kind '%s', using battle" % kind)
		key = "battle"
	return (table[key] as Dictionary).duplicate()


## Rarity weights {"common", "rare", "epic"} at [param luck]: linear interpolation between the
## `rarity_weights_at_luck` anchors, clamped to the first / last anchor outside their range.
static func luck_rarity_weights(config: Dictionary, luck: float) -> Dictionary:
	var anchors: Dictionary = clean_config(config)["rarity_weights_at_luck"]
	var points: Array[float] = []
	for key: String in anchors.keys():
		points.append(float(key))
	points.sort()
	var vector: Array = []
	if luck <= points[0]:
		vector = anchors[_anchor_key(anchors, points[0])]
	elif luck >= points[points.size() - 1]:
		vector = anchors[_anchor_key(anchors, points[points.size() - 1])]
	else:
		for i: int in points.size() - 1:
			if luck >= points[i] and luck <= points[i + 1]:
				var t: float = (luck - points[i]) / (points[i + 1] - points[i])
				var a: Array = anchors[_anchor_key(anchors, points[i])]
				var b: Array = anchors[_anchor_key(anchors, points[i + 1])]
				for r: int in a.size():
					vector.append(lerpf(float(a[r]), float(b[r]), t))
				break
	var result: Dictionary = {}
	for r: int in SkillConfig.RARITIES.size():
		result[SkillConfig.RARITIES[r]] = float(vector[r])
	return result


## True when offering [param id] would UPGRADE a copy: the deck owns it below [param max_level]
## ([param deck_levels] is id -> highest copy level, see RunSession.deck_levels).
static func is_upgrade(id: String, deck_levels: Dictionary, max_level: int = SkillConfig.MAX_LEVEL) -> bool:
	var level: int = int(deck_levels.get(id, 0))
	return level >= 1 and level < max_level


## Draws up to config.offer_count DISTINCT card ids. [param config] comes from [method load_config];
## [param exclude_ids] are never offered; [param deck_levels] (id -> highest copy level) hides cards
## already at max_card_level unless fewer than offer_count candidates would remain. Rarity weights
## follow [param luck] ([method luck_rarity_weights]). With [param min_rarity] above common only
## cards of that rarity or better are offered; when too few exist the rest is topped up from the
## whole pool (warning). Deterministic for the same inputs. Fewer candidates than offer_count:
## returns what exists.
## Skill v2 Q3 (docs/skill-v2/02-design-decisions.md, approved): [param hero_id] = the run's hero; that hero's own cards
## flagged `hero_reward` (cards.json) join the pool at their rarity. Other heroes' cards never do; "" = none.
static func roll(cards: SkillConfig, config: Dictionary, seed: int,
		exclude_ids: Array[String] = [], deck_levels: Dictionary = {}, luck: float = 0.0,
		min_rarity: String = "common", hero_id: String = "") -> Array[String]:
	var cfg: Dictionary = clean_config(config)
	var weights: Dictionary = luck_rarity_weights(cfg, luck)
	var floor_rank: int = maxi(SkillConfig.RARITIES.find(min_rarity), 0)
	var want: int = int(cfg["offer_count"])
	var offer: Array[String] = _draw(cards, cfg, weights, floor_rank, seed, exclude_ids, deck_levels, want, hero_id)
	if offer.size() < want and floor_rank > 0:
		push_warning("RewardRoller: only %d cards of rarity %s or better, topping up" % [offer.size(), min_rarity])
		var skip: Array[String] = exclude_ids.duplicate()
		skip.append_array(offer)
		offer.append_array(_draw(cards, cfg, weights, 0, seed + 1, skip, deck_levels, want - offer.size(), hero_id))
	return offer


static func _draw(cards: SkillConfig, cfg: Dictionary, weights: Dictionary, floor_rank: int, seed: int,
		exclude_ids: Array[String], deck_levels: Dictionary, want: int, hero_id: String = "") -> Array[String]:
	var max_level: int = int(cfg["max_card_level"])
	var ids: Array[String] = []
	var w: Array[float] = []
	var maxed_ids: Array[String] = []
	var maxed_w: Array[float] = []
	for id: String in cards.card_order:
		if exclude_ids.has(id) or not bool(cards.get_skill(id).get("implemented", false)):
			continue
		# Cast rhythm spec 2026-11-05: hero cards (cards.json `hero`) never come from rewards, shops or events, except
		# (Skill v2 Q3) the run hero's own cards flagged `hero_reward`, offered in its rewards only.
		if not cards.hero_of(id).is_empty() and not (not hero_id.is_empty() and cards.hero_of(id) == hero_id
				and bool(cards.get_skill(id).get("hero_reward", false))):
			continue
		if bool(cfg["pool_excludes_defaults"]) and cards.default_deck.has(id):
			continue
		var rarity: String = cards.get_rarity(id)
		if SkillConfig.RARITIES.find(rarity) < floor_rank:
			continue
		var weight: float = float(weights.get(rarity, 0.0))
		if weight <= 0.0:
			continue
		if int(deck_levels.get(id, 0)) >= max_level:
			maxed_ids.append(id)
			maxed_w.append(weight)
		else:
			ids.append(id)
			w.append(weight)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var offer: Array[String] = []
	# Pool short: every free card is offered (card order); maxed cards fill the rest by weight.
	if ids.size() < want:
		offer = ids.duplicate()
		ids = maxed_ids
		w = maxed_w
	while offer.size() < want and not ids.is_empty():
		var total: float = 0.0
		for x: float in w:
			total += x
		var pick: float = rng.randf() * total
		var chosen: int = ids.size() - 1
		for i: int in ids.size():
			pick -= w[i]
			if pick < 0.0:
				chosen = i
				break
		offer.append(ids[chosen])
		ids.remove_at(chosen)
		w.remove_at(chosen)
	return offer


# Cleaned anchors: string luck key -> [common, rare, epic] (>= 0 each); malformed ones dropped.
static func _clean_anchors(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	for key: Variant in (raw as Dictionary).keys():
		var vector: Variant = (raw as Dictionary)[key]
		if not str(key).is_valid_float() or typeof(vector) != TYPE_ARRAY or (vector as Array).size() != SkillConfig.RARITIES.size():
			continue
		var weights: Array = []
		for x: Variant in vector as Array:
			weights.append(maxf(float(x), 0.0))
		result[str(key)] = weights
	return result


static func _anchor_key(anchors: Dictionary, luck: float) -> String:
	for key: String in anchors.keys():
		if is_equal_approx(float(key), luck):
			return key
	return str(anchors.keys()[0])


static func _clean_node_reward(raw: Dictionary, fallback: Dictionary) -> Dictionary:
	var entry: Dictionary = fallback.duplicate()
	if raw.has("offers"):
		entry["offers"] = maxi(int(raw["offers"]), 0)
	var rarity: String = str(raw.get("min_rarity", entry["min_rarity"]))
	if SkillConfig.RARITIES.has(rarity):
		entry["min_rarity"] = rarity
	else:
		push_warning("RewardRoller: node_rewards min_rarity '%s' unknown, kept %s" % [rarity, entry["min_rarity"]])
	entry["free"] = bool(raw.get("free", entry["free"]))
	entry["removal_token"] = bool(raw.get("removal_token", entry["removal_token"]))
	return entry

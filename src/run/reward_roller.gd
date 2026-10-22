class_name RewardRoller
extends RefCounted
## Pure, seeded card-reward roll (Story 019). Config: assets/data/rewards.json (schema.md).
## Pool = every `implemented` card; weight = rarity weight x class_tag_bonus when the card's
## class_tags contain one of the character tags; the offer is a weighted draw WITHOUT replacement.

const DEFAULT_PATH: String = "res://assets/data/rewards.json"


## Built-in defaults (also the shape of a validated config).
static func default_config() -> Dictionary:
	return {
		"offer_count": 3,
		"rarity_weights": {"common": 70.0, "rare": 25.0, "epic": 5.0},
		"class_tag_bonus": 2.0,
		"allow_skip": true,
		"pool_excludes_defaults": false,
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
	if data.has("class_tag_bonus"):
		result["class_tag_bonus"] = maxf(float(data["class_tag_bonus"]), 1.0)
	if data.has("allow_skip"):
		result["allow_skip"] = bool(data["allow_skip"])
	if data.has("pool_excludes_defaults"):
		result["pool_excludes_defaults"] = bool(data["pool_excludes_defaults"])
	var raw: Variant = data.get("rarity_weights")
	if typeof(raw) == TYPE_DICTIONARY:
		var weights: Dictionary = {}
		for rarity: String in SkillConfig.RARITIES:
			weights[rarity] = maxf(float((raw as Dictionary).get(rarity, 0.0)), 0.0)
		result["rarity_weights"] = weights
	elif raw != null:
		push_warning("RewardRoller: rarity_weights must be an object, using defaults")
	return result


## Draws up to config.offer_count DISTINCT card ids. [param config] comes from [method load_config];
## [param character_tags] is normally [character_id]; [param exclude_ids] are never offered.
## Deterministic for the same inputs. Fewer candidates than offer_count: returns what exists.
static func roll(cards: SkillConfig, config: Dictionary, character_tags: Array[String], seed: int,
		exclude_ids: Array[String] = []) -> Array[String]:
	var cfg: Dictionary = clean_config(config)
	var weights: Dictionary = cfg["rarity_weights"]
	var bonus: float = float(cfg["class_tag_bonus"])
	var ids: Array[String] = []
	var w: Array[float] = []
	for id: String in cards.card_order:
		if exclude_ids.has(id) or not bool(cards.get_skill(id).get("implemented", false)):
			continue
		if bool(cfg["pool_excludes_defaults"]) and cards.default_deck.has(id):
			continue
		var weight: float = float(weights.get(cards.get_rarity(id), 0.0))
		for tag: String in cards.get_class_tags(id):
			if character_tags.has(tag):
				weight *= bonus
				break
		if weight > 0.0:
			ids.append(id)
			w.append(weight)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var offer: Array[String] = []
	while offer.size() < int(cfg["offer_count"]) and not ids.is_empty():
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

class_name RewardRoller
extends RefCounted
## Pure, seeded card-reward roll (Story 019). Config: assets/data/rewards.json (schema.md).
## Pool = every `implemented` card; weight = rarity weight only (Story 020: no class tags). A card
## whose deck level already equals max_card_level is not offered unless the pool would then have
## fewer than offer_count candidates. The offer is a weighted draw WITHOUT replacement.

const DEFAULT_PATH: String = "res://assets/data/rewards.json"


## Built-in defaults (also the shape of a validated config).
static func default_config() -> Dictionary:
	return {
		"offer_count": 3,
		"rarity_weights": {"common": 70.0, "rare": 25.0, "epic": 5.0},
		"allow_skip": true,
		"allow_remove": true,
		"min_deck_size": 4,
		"max_card_level": 3,
		"offer_upgrades": true,
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
	if data.has("min_deck_size"):
		result["min_deck_size"] = maxi(int(data["min_deck_size"]), 1)
	if data.has("max_card_level"):
		result["max_card_level"] = clampi(int(data["max_card_level"]), 1, SkillConfig.MAX_LEVEL)
	for key: String in ["allow_remove", "offer_upgrades"]:
		if data.has(key):
			result[key] = bool(data[key])
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


## True when offering [param id] would UPGRADE a copy: the deck owns it below [param max_level]
## ([param deck_levels] is id -> highest copy level, see RunSession.deck_levels).
static func is_upgrade(id: String, deck_levels: Dictionary, max_level: int = SkillConfig.MAX_LEVEL) -> bool:
	var level: int = int(deck_levels.get(id, 0))
	return level >= 1 and level < max_level


## Draws up to config.offer_count DISTINCT card ids. [param config] comes from [method load_config];
## [param exclude_ids] are never offered; [param deck_levels] (id -> highest copy level) hides cards
## already at max_card_level unless fewer than offer_count candidates would remain.
## Deterministic for the same inputs. Fewer candidates than offer_count: returns what exists.
static func roll(cards: SkillConfig, config: Dictionary, seed: int,
		exclude_ids: Array[String] = [], deck_levels: Dictionary = {}) -> Array[String]:
	var cfg: Dictionary = clean_config(config)
	var weights: Dictionary = cfg["rarity_weights"]
	var max_level: int = int(cfg["max_card_level"])
	var ids: Array[String] = []
	var w: Array[float] = []
	var maxed_ids: Array[String] = []
	var maxed_w: Array[float] = []
	for id: String in cards.card_order:
		if exclude_ids.has(id) or not bool(cards.get_skill(id).get("implemented", false)):
			continue
		if bool(cfg["pool_excludes_defaults"]) and cards.default_deck.has(id):
			continue
		var weight: float = float(weights.get(cards.get_rarity(id), 0.0))
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
	if ids.size() < int(cfg["offer_count"]):
		offer = ids.duplicate()
		ids = maxed_ids
		w = maxed_w
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

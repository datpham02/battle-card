class_name RelicRoller
extends RefCounted
## Pure, seeded, deterministic relic offers (Story 032), shared by the treasure node, the shop and
## events (Story 033) and the boss kill (Story 035). Same rng state + same inputs = same offer.
## The relic pool is the config's file order, so adding a relic never reorders existing draws of
## other rarities unpredictably within one rarity bucket beyond the new entry.

const SOURCE_TREASURE: String = "treasure"
const SOURCE_BOSS_KILL: String = "boss_kill"


## Up to [param count] DIFFERENT relic ids for [param source]; never a duplicate, never an id of
## [param owned] unless it has the `stackable` tag; fewer than [param count] when the pool is short.
## `treasure`: every slot draws a rarity by `rarity_weights` among the rarities at or above the rule's
## `min_rarity` (floor, shipped `common`) that still have a candidate, then a relic of it.
## `boss_kill`: tier `boss` first, then `epic` when no boss relic is left. Unknown source: empty
## (warning). A null [param rng] uses a fresh generator with seed 0; null [param config] the shared
## relics.json.
static func roll(
	source: String,
	owned: Array,
	rng: RandomNumberGenerator,
	config: RelicConfig = null,
	count: int = 3
) -> Array[String]:
	var cfg: RelicConfig = config if config != null else RelicRegistry.shared_config()
	var generator: RandomNumberGenerator = rng
	if generator == null:
		generator = RandomNumberGenerator.new()
		generator.seed = 0
	var out: Array[String] = []
	if count <= 0:
		return out
	match source:
		SOURCE_TREASURE:
			_roll_treasure(cfg, owned, generator, count, out)
		SOURCE_BOSS_KILL:
			_roll_tiers(cfg, owned, generator, count, out)
		_:
			push_warning("RelicRoller: unknown source '%s', nothing offered" % source)
	return out


## Candidates of [param rarity] in file order: not owned (unless stackable) and not yet in [param taken].
static func _candidates(cfg: RelicConfig, rarity: String, owned: Array, taken: Array[String]) -> Array[String]:
	var pool: Array[String] = []
	for entry: Dictionary in cfg.relics:
		if entry["rarity"] != rarity:
			continue
		var id: String = str(entry["id"])
		if taken.has(id):
			continue
		if owned.has(id) and not (entry["tags"] as Array).has("stackable"):
			continue
		pool.append(id)
	return pool


static func _roll_treasure(cfg: RelicConfig, owned: Array, rng: RandomNumberGenerator, count: int, out: Array[String]) -> void:
	var rule: Dictionary = cfg.source_rules.get(SOURCE_TREASURE, {})
	var floor_rank: int = maxi(RelicConfig.rarity_rank(str(rule.get("min_rarity", "common"))), 0)
	while out.size() < count:
		var buckets: Array[String] = []
		var weights: Array[float] = []
		var total: float = 0.0
		for rank: int in range(floor_rank, RelicConfig.RARITIES.size()):
			var rarity: String = RelicConfig.RARITIES[rank]
			var weight: float = float(cfg.rarity_weights.get(rarity, 0.0))
			if weight > 0.0 and not _candidates(cfg, rarity, owned, out).is_empty():
				buckets.append(rarity)
				weights.append(weight)
				total += weight
		if buckets.is_empty():
			return
		var pick: float = rng.randf() * total
		var chosen: int = buckets.size() - 1
		for i: int in buckets.size():
			if pick < weights[i]:
				chosen = i
				break
			pick -= weights[i]
		var pool: Array[String] = _candidates(cfg, buckets[chosen], owned, out)
		out.append(pool[rng.randi_range(0, pool.size() - 1)])


static func _roll_tiers(cfg: RelicConfig, owned: Array, rng: RandomNumberGenerator, count: int, out: Array[String]) -> void:
	var rule: Dictionary = cfg.source_rules.get(SOURCE_BOSS_KILL, {})
	var tiers: Array = rule.get("tiers", ["boss", "epic"])
	for tier: Variant in tiers:
		while out.size() < count:
			var pool: Array[String] = _candidates(cfg, str(tier), owned, out)
			if pool.is_empty():
				break
			out.append(pool[rng.randi_range(0, pool.size() - 1)])
		if out.size() >= count:
			return

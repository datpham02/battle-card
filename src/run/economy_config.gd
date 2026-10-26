class_name EconomyConfig
extends RefCounted
## Gold economy of a run from assets/data/economy.json (Story 033): the gold a won node drops (per node kind,
## +-`variance`, scaled per floor), the starting gold, the shop prices (card and relic by rarity, a per-floor
## price multiplier, three services: remove_card, heal, Story 034 remove_shape) and the shop stock counts. Pure data + seeded maths, no nodes. Never null
## after [method load_from_file]: a missing / bad file or key falls back to [constant DEFAULTS] (warning).
## Every `floor` argument is the 0-based run floor of RunSession (a floor past the last row uses the last
## row, so the final match uses the last multiplier). Schema: assets/data/schema.md `economy.json`.
## Design: design/game-brief.md "Run v6", design/reference/osfe-reference.md section 9.2.

const DEFAULT_PATH: String = "res://assets/data/economy.json"
## The single place of the documented fallbacks (the shipped numbers live in economy.json, the file wins).
const DEFAULTS: Dictionary = {
	"starting_gold": 20,
	"gold_drops": {"battle": 12, "danger": 22, "miniboss": 25, "boss": 35, "treasure": 15},
	"variance": 0.2,
	"gold_floor_mult": [1.0, 1.1, 1.2, 1.3, 1.4],
	"shop": {
		"stock": {"cards": 3, "relics": 2},
		"card_prices": {"common": 40, "rare": 60, "epic": 85},
		"relic_prices": {"common": 75, "rare": 100, "epic": 130},
		"price_floor_mult": [1.0, 1.05, 1.1, 1.15, 1.2],
		"services": {
			"remove_card": {"price": 60, "max_uses": 1},
			"heal": {"price": 40, "max_uses": 1, "heal_ratio": 0.25},
			"remove_shape": {"price": 45, "max_uses": 1},
		},
	},
}
## Service ids of the shop (the keys of `shop.services`).
const SERVICE_REMOVE_CARD: String = "remove_card"
const SERVICE_HEAL: String = "heal"
## Story 034: removes a piece shape from the run's piece deck for gold (no removal token).
const SERVICE_REMOVE_SHAPE: String = "remove_shape"
## Keeps seeds non-negative.
const SEED_MASK: int = 0x7fffffff

static var _shared: EconomyConfig = null

# The cleaned data (same shape as DEFAULTS).
var _data: Dictionary = {}


## The lazily loaded shared instance of the shipped economy.json (read once per process).
static func shared() -> EconomyConfig:
	if _shared == null:
		_shared = load_from_file()
	return _shared


## Loads from a JSON file. Never null (defaults + warning when missing or bad).
static func load_from_file(path: String = DEFAULT_PATH) -> EconomyConfig:
	if not FileAccess.file_exists(path):
		push_warning("EconomyConfig: file not found, using defaults: %s" % path)
		return from_dictionary({})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("EconomyConfig: JSON root must be an object, using defaults")
		return from_dictionary({})
	return from_dictionary(parsed as Dictionary)


## Builds from a dictionary (see schema.md). Never null; bad parts keep their default (warning).
static func from_dictionary(data: Dictionary) -> EconomyConfig:
	var c := EconomyConfig.new()
	var d: Dictionary = DEFAULTS.duplicate(true)
	if data.has("starting_gold"):
		d["starting_gold"] = maxi(int(data["starting_gold"]), 0)
	if data.has("variance"):
		d["variance"] = clampf(float(data["variance"]), 0.0, 1.0)
	_merge_numbers(d["gold_drops"], data.get("gold_drops"), "gold_drops", 0.0)
	d["gold_floor_mult"] = _clean_mults(data.get("gold_floor_mult"), d["gold_floor_mult"], "gold_floor_mult")
	var shop_raw: Variant = data.get("shop")
	if typeof(shop_raw) == TYPE_DICTIONARY:
		var shop: Dictionary = d["shop"]
		var src: Dictionary = shop_raw as Dictionary
		_merge_numbers(shop["stock"], src.get("stock"), "shop.stock", 0.0)
		_merge_numbers(shop["card_prices"], src.get("card_prices"), "shop.card_prices", 0.0)
		_merge_numbers(shop["relic_prices"], src.get("relic_prices"), "shop.relic_prices", 0.0)
		shop["price_floor_mult"] = _clean_mults(src.get("price_floor_mult"), shop["price_floor_mult"], "shop.price_floor_mult")
		var services: Variant = src.get("services")
		if typeof(services) == TYPE_DICTIONARY:
			for id: String in (shop["services"] as Dictionary).keys():
				_merge_numbers((shop["services"] as Dictionary)[id], (services as Dictionary).get(id), "shop.services.%s" % id, 0.0)
		elif services != null:
			push_warning("EconomyConfig: shop.services must be an object, using defaults")
		var heal: Dictionary = (shop["services"] as Dictionary)[SERVICE_HEAL]
		heal["heal_ratio"] = clampf(float(heal["heal_ratio"]), 0.0, 1.0)
	elif shop_raw != null:
		push_warning("EconomyConfig: shop must be an object, using defaults")
	c._data = d
	return c


## Gold a new run starts with (>= 0).
func starting_gold() -> int:
	return int(_data["starting_gold"])


## Gold dropped by a WON node of [param kind] at 0-based [param floor]: base(kind) x floor multiplier x
## (1 + variance x u), u uniform in [-1, 1], rounded, never negative. [param rng_or_seed] is a
## RandomNumberGenerator (one draw is taken) or an int seed (a fresh generator is seeded with it): the same
## seed gives the same amount. A kind without a base (rest, shop, event, unknown) drops 0.
func gold_for(kind: String, floor: int, rng_or_seed: Variant = 0) -> int:
	var drops: Dictionary = _data["gold_drops"]
	if not drops.has(kind):
		return 0
	var rng: RandomNumberGenerator = null
	if rng_or_seed is RandomNumberGenerator:
		rng = rng_or_seed as RandomNumberGenerator
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = int(rng_or_seed) & SEED_MASK
	var spread: float = float(_data["variance"]) * rng.randf_range(-1.0, 1.0)
	var value: float = float(drops[kind]) * _mult_at(_data["gold_floor_mult"], floor) * (1.0 + spread)
	return maxi(roundi(value), 0)


## Smallest and largest [method gold_for] result of [param kind] at [param floor] (the variance bounds).
func gold_bounds(kind: String, floor: int) -> Vector2i:
	var drops: Dictionary = _data["gold_drops"]
	if not drops.has(kind):
		return Vector2i.ZERO
	var base: float = float(drops[kind]) * _mult_at(_data["gold_floor_mult"], floor)
	var v: float = float(_data["variance"])
	return Vector2i(maxi(roundi(base * (1.0 - v)), 0), maxi(roundi(base * (1.0 + v)), 0))


## Shop price of a card of [param rarity] at [param floor]: base x price_floor_mult, rounded. An unknown
## rarity costs the `common` price.
func price_card(rarity: String, floor: int) -> int:
	var prices: Dictionary = _shop()["card_prices"]
	return _price(float(prices.get(rarity, prices["common"])), floor)


## Shop price of a relic of [param rarity] at [param floor] (as [method price_card], `relic_prices`).
func price_relic(rarity: String, floor: int) -> int:
	var prices: Dictionary = _shop()["relic_prices"]
	return _price(float(prices.get(rarity, prices["common"])), floor)


## Price of shop service [param id] ([constant SERVICE_REMOVE_CARD] / [constant SERVICE_HEAL] /
## [constant SERVICE_REMOVE_SHAPE]) at
## [param floor] (base x price_floor_mult, rounded); 0 for an unknown id (warning).
func service_price(id: String, floor: int) -> int:
	var services: Dictionary = _shop()["services"]
	if not services.has(id):
		push_warning("EconomyConfig: unknown shop service '%s'" % id)
		return 0
	return _price(float((services[id] as Dictionary)["price"]), floor)


## Uses of service [param id] allowed per shop visit (>= 0; 0 for an unknown id).
func service_max_uses(id: String) -> int:
	var services: Dictionary = _shop()["services"]
	if not services.has(id):
		return 0
	return maxi(int((services[id] as Dictionary)["max_uses"]), 0)


## Share of max HP the heal service restores (0..1).
func service_heal_ratio() -> float:
	return float(((_shop()["services"] as Dictionary)[SERVICE_HEAL] as Dictionary)["heal_ratio"])


## Shop stock sizes: {"cards": int, "relics": int}.
func stock_counts() -> Dictionary:
	var stock: Dictionary = _shop()["stock"]
	return {"cards": maxi(int(stock["cards"]), 0), "relics": maxi(int(stock["relics"]), 0)}


# The cleaned `shop` block.
func _shop() -> Dictionary:
	return _data["shop"]


# base x the price multiplier of [param floor], rounded, at least 0.
func _price(base: float, floor: int) -> int:
	return maxi(roundi(base * _mult_at(_shop()["price_floor_mult"], floor)), 0)


# Row [param floor] of a multiplier list (clamped to its ends; 1.0 for an empty list).
static func _mult_at(mults: Array, floor: int) -> float:
	if mults.is_empty():
		return 1.0
	return float(mults[clampi(floor, 0, mults.size() - 1)])


# Copies the known numeric keys of [param target] from [param raw] (an object); bad values keep the default.
static func _merge_numbers(target: Dictionary, raw: Variant, label: String, minimum: float) -> void:
	if raw == null:
		return
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("EconomyConfig: %s must be an object, using defaults" % label)
		return
	for key: String in target.keys():
		if (raw as Dictionary).has(key):
			var value: Variant = (raw as Dictionary)[key]
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				push_warning("EconomyConfig: %s.%s must be a number, using the default" % [label, key])
			elif typeof(target[key]) == TYPE_FLOAT:
				target[key] = maxf(float(value), minimum)
			else:
				target[key] = maxi(int(value), int(minimum))


# A non-empty list of multipliers > 0; anything else keeps [param fallback].
static func _clean_mults(raw: Variant, fallback: Array, label: String) -> Array:
	if raw == null:
		return fallback
	if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
		push_warning("EconomyConfig: %s must be a non-empty array, using defaults" % label)
		return fallback
	var out: Array = []
	for v: Variant in raw as Array:
		out.append(maxf(float(v), 0.0))
	return out

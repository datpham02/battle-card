class_name ShopLogic
extends RefCounted
## Pure data + rules of one SHOP node (Story 033 Part B). No nodes, no files, no flow: GameFlow stores
## the state Dictionary in `RunSession.shop_state` and the view reads it. Every number (prices, stock
## sizes, the heal ratio) comes from the EconomyConfig passed to [method build] (assets/data/economy.json);
## nothing gameplay-related is hardcoded here.
##
## State shape (what [method to_dict] / [method from_dict] move through the save):
## {"version": int, "floor": int, "heal_ratio": float, "min_deck_size": int,
##  "cards":  [{"id": String, "price": int, "sold": bool}],
##  "relics": [{"id": String, "price": int, "sold": bool}],
##  "services": {"remove_card": {"price": int, "used": bool}, "heal": {"price": int, "used": bool}}}
## Every refusal result carries `reason` (a code of the REASON_* constants) and `reason_key`
## (`ui.shop.reason.<code>`, a translation key the view may show).

const STATE_VERSION: int = 1
const KIND_CARD: String = "card"
const KIND_RELIC: String = "relic"
const KIND_SERVICE: String = "service"
const SERVICE_REMOVE_CARD: String = "remove_card"
const SERVICE_HEAL: String = "heal"
const SERVICES: Array[String] = [SERVICE_REMOVE_CARD, SERVICE_HEAL]
## Relic source of RelicRoller (relics.json `source_rules.shop`).
const RELIC_SOURCE: String = "shop"

const REASON_UNKNOWN: String = "unknown"
const REASON_SOLD: String = "sold"
const REASON_USED: String = "used"
const REASON_NO_GOLD: String = "no_gold"
const REASON_OWNED: String = "owned"
const REASON_BAD_INDEX: String = "bad_index"
const REASON_MIN_DECK: String = "min_deck"
const REASON_FULL_HP: String = "full_hp"


## Seeded stock of the shop at ([param floor], [param column], [param node_index]) of the run
## [param run_seed]: `economy.stock_counts().cards` cards by [param luck] (RewardRoller rarity weights,
## `reward_cfg` from RewardRoller.load_config, curse cards never), `.relics` relics by RelicRoller
## "shop" (none of [param owned_relics]) and the two services, each with its price
## (`economy.price_card / price_relic / service_price`, scaled by [param floor]). Same inputs = same
## state.
static func build(run_seed: int, floor: int, column: int, node_index: int, luck: float,
		owned_relics: Array, cards_cfg: SkillConfig, reward_cfg: Dictionary, relic_cfg: RelicConfig,
		economy: EconomyConfig) -> Dictionary:
	var seed_value: int = hash([run_seed, floor, column, node_index, "shop"])
	var counts: Dictionary = economy.stock_counts()
	var card_count: int = maxi(int(counts.get("cards", 0)), 0)
	var relic_count: int = maxi(int(counts.get("relics", 0)), 0)
	var cards: Array = []
	if card_count > 0 and cards_cfg != null:
		var roll_cfg: Dictionary = RewardRoller.clean_config(reward_cfg)
		roll_cfg["offer_count"] = card_count
		var ids: Array[String] = RewardRoller.roll(cards_cfg, roll_cfg, seed_value, [] as Array[String], {}, luck)
		for id: String in ids:
			if _is_curse(cards_cfg, id):
				continue
			cards.append({"id": id, "price": int(economy.price_card(cards_cfg.get_rarity(id), floor)), "sold": false})
	var relics: Array = []
	if relic_count > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "relics"])
		var relic_ids: Array[String] = RelicRoller.roll(RELIC_SOURCE, owned_relics, rng, relic_cfg, relic_count)
		var cfg: RelicConfig = relic_cfg if relic_cfg != null else RelicRegistry.shared_config()
		for id: String in relic_ids:
			var rarity: String = str(cfg.get_relic(id).get("rarity", "common"))
			relics.append({"id": id, "price": int(economy.price_relic(rarity, floor)), "sold": false})
	var services: Dictionary = {}
	for service: String in SERVICES:
		services[service] = {"price": int(economy.service_price(service, floor)), "used": false}
	return {
		"version": STATE_VERSION,
		"floor": floor,
		"heal_ratio": float(economy.service_heal_ratio()),
		"min_deck_size": int(RewardRoller.clean_config(reward_cfg)["min_deck_size"]),
		"cards": cards,
		"relics": relics,
		"services": services,
	}


## Whether [param id] of [param kind] (`card`, `relic` or `service`) can be bought with [param gold]:
## {"ok": bool, "reason": String, "reason_key": String, "price": int}. Reasons: unknown, sold / used,
## no_gold. Does not change anything.
static func can_buy(state: Dictionary, kind: String, id: String, gold: int) -> Dictionary:
	var entry: Dictionary = _find(state, kind, id)
	if entry.is_empty():
		return _refuse(REASON_UNKNOWN, 0)
	var price: int = int(entry.get("price", 0))
	if bool(entry.get("sold", false)):
		return _refuse(REASON_SOLD, price)
	if bool(entry.get("used", false)):
		return _refuse(REASON_USED, price)
	if gold < price:
		return _refuse(REASON_NO_GOLD, price)
	return {"ok": true, "reason": "", "reason_key": "", "price": price}


## Buys the card or relic [param id] with the run's gold. A card goes through `run.add_card` (a copy
## below the max level is UPGRADED, else a new copy joins); a relic through `run.add_relic` (an owned
## relic is refused before any gold is spent). The entry is marked sold. Result: {"ok", "reason",
## "reason_key", "price", "kind", "id"} plus, for a card, "upgraded" and "level".
static func buy(state: Dictionary, run: RunSession, kind: String, id: String) -> Dictionary:
	if kind != KIND_CARD and kind != KIND_RELIC:
		return _refuse(REASON_UNKNOWN, 0)
	var check: Dictionary = can_buy(state, kind, id, run.gold)
	if not bool(check["ok"]):
		return check
	if kind == KIND_RELIC and run.has_relic(id):
		return _refuse(REASON_OWNED, int(check["price"]))
	if not run.spend_gold(int(check["price"])):
		return _refuse(REASON_NO_GOLD, int(check["price"]))
	var result: Dictionary = {"ok": true, "reason": "", "reason_key": "", "price": int(check["price"]), "kind": kind, "id": id}
	if kind == KIND_CARD:
		var added: Dictionary = run.add_card(id)
		result["upgraded"] = bool(added.get("upgraded", false))
		result["level"] = int(added.get("level", 1))
	else:
		run.add_relic(id)
	var row: Dictionary = _find(state, kind, id)
	row["sold"] = true
	return result


## Uses service [param id] once. `remove_card`: [param arg] = deck index; the card leaves the deck
## right away (no removal token), refused for a bad index or when a non-curse card would drop the
## non-curse count to `min_deck_size` or below (a curse card may always go; [param cards] tells which
## cards are curses, default the shipped cards.json). `heal`: [param arg] = the player's max HP; heals
## `heal_ratio` x max HP clamped, refused at full HP (nothing charged). Result: {"ok", "reason",
## "reason_key", "price", "kind": "service", "id"} plus `removed_id` (remove_card) or `healed` (heal).
static func use_service(state: Dictionary, run: RunSession, id: String, arg: Variant = null,
		cards: SkillConfig = null) -> Dictionary:
	var check: Dictionary = can_buy(state, KIND_SERVICE, id, run.gold)
	if not bool(check["ok"]):
		return check
	var price: int = int(check["price"])
	var result: Dictionary = {"ok": true, "reason": "", "reason_key": "", "price": price, "kind": KIND_SERVICE, "id": id}
	match id:
		SERVICE_REMOVE_CARD:
			var index: int = int(arg) if typeof(arg) == TYPE_INT or typeof(arg) == TYPE_FLOAT else -1
			if index < 0 or index >= run.deck.size():
				return _refuse(REASON_BAD_INDEX, price)
			var config: SkillConfig = cards if cards != null else SkillConfig.load_from_file()
			var target: String = str(run.deck[index]["id"])
			if not _is_curse(config, target):
				var normal: int = 0
				for e: Dictionary in run.deck:
					if not _is_curse(config, str(e["id"])):
						normal += 1
				if normal <= int(state.get("min_deck_size", 0)):
					return _refuse(REASON_MIN_DECK, price)
			if not run.spend_gold(price):
				return _refuse(REASON_NO_GOLD, price)
			run.deck.remove_at(index)
			result["removed_id"] = target
		SERVICE_HEAL:
			var max_hp: float = float(arg) if typeof(arg) == TYPE_INT or typeof(arg) == TYPE_FLOAT else 0.0
			if max_hp <= 0.0 or run.hp < 0.0 or run.hp >= max_hp:
				return _refuse(REASON_FULL_HP, price)
			if not run.spend_gold(price):
				return _refuse(REASON_NO_GOLD, price)
			result["healed"] = run.rest_heal(max_hp, {"rest_heal_ratio": float(state.get("heal_ratio", 0.0))})
		_:
			return _refuse(REASON_UNKNOWN, 0)
	var service_row: Dictionary = _find(state, KIND_SERVICE, id)
	service_row["used"] = true
	return result


## Count of cards and relics not yet sold.
static func remaining_stock(state: Dictionary) -> int:
	var left: int = 0
	for row: String in ["cards", "relics"]:
		for entry: Variant in state.get(row, []) as Array:
			if not bool((entry as Dictionary).get("sold", false)):
				left += 1
	return left


## Save form of [param state] (a deep copy, JSON-safe).
static func to_dict(state: Dictionary) -> Dictionary:
	return state.duplicate(true)


## Rebuilds a state from [method to_dict] (numbers come back from JSON as floats). {} when [param raw]
## is not a shop state; malformed rows are dropped.
static func from_dict(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or not (raw as Dictionary).has("services"):
		return {}
	var d: Dictionary = raw as Dictionary
	var services: Dictionary = {}
	for service: String in SERVICES:
		var s: Variant = (d["services"] as Dictionary).get(service) if typeof(d["services"]) == TYPE_DICTIONARY else null
		if typeof(s) != TYPE_DICTIONARY:
			return {}
		services[service] = {"price": int((s as Dictionary).get("price", 0)), "used": bool((s as Dictionary).get("used", false))}
	return {
		"version": STATE_VERSION,
		"floor": int(d.get("floor", 0)),
		"heal_ratio": float(d.get("heal_ratio", 0.0)),
		"min_deck_size": int(d.get("min_deck_size", 0)),
		"cards": _rows(d.get("cards", [])),
		"relics": _rows(d.get("relics", [])),
		"services": services,
	}


static func _rows(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw as Array:
		if typeof(entry) == TYPE_DICTIONARY and not str((entry as Dictionary).get("id", "")).is_empty():
			out.append({"id": str((entry as Dictionary)["id"]), "price": int((entry as Dictionary).get("price", 0)),
				"sold": bool((entry as Dictionary).get("sold", false))})
	return out


# The state row of [param id]: a stock entry (card / relic) or a service entry with `used`. {} when unknown.
# The returned Dictionary is the live row (not a copy) so callers can flip its flag.
static func _find(state: Dictionary, kind: String, id: String) -> Dictionary:
	match kind:
		KIND_CARD, KIND_RELIC:
			for entry: Variant in state.get("cards" if kind == KIND_CARD else "relics", []) as Array:
				if str((entry as Dictionary).get("id", "")) == id:
					return entry as Dictionary
		KIND_SERVICE:
			var services: Variant = state.get("services", {})
			if typeof(services) == TYPE_DICTIONARY and (services as Dictionary).has(id):
				return (services as Dictionary)[id] as Dictionary
	return {}


static func _refuse(reason: String, price: int) -> Dictionary:
	return {"ok": false, "reason": reason, "reason_key": "ui.shop.reason.%s" % reason, "price": price}


# Story 033: true when [param id] is a curse card (SkillConfig.is_curse).
static func _is_curse(cards: SkillConfig, id: String) -> bool:
	return cards.is_curse(id)

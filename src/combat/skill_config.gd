class_name SkillConfig
extends RefCounted
## Card definitions, deck defaults and card-menu timing from assets/data/cards.json.
## (Class name kept from the v3 "skills" era; a skill is now a card.)
## Schema: assets/data/schema.md. Implements: Story 008 (skills data; burn/pin: Story 010),
## Story 017 part A (cards, hand_size, default deck).

const DEFAULT_PATH: String = "res://assets/data/cards.json"
## Card id used when nothing else is chosen; always present in [member cards].
const FALLBACK_SKILL: String = "kiem_khi"
## Reward / shop rarities (the pool tiers). `curse` is NOT one of them: curse cards never reach a pool.
const RARITIES: Array[String] = ["common", "rare", "epic"]
## Story 033: rarity id of a curse card (takes a menu slot, shown locked, never upgraded, never rewarded).
const CURSE_RARITY: String = "curse"
## Highest card level (levels are 1..MAX_LEVEL; Story 020).
const MAX_LEVEL: int = 3
const EFFECTS: Array[String] = ["damage", "push", "burn", "pin", "fragile", "frost", "thorns"]
## Keys an `upgrade` table may change (additive deltas), with the floor each is clamped to.
const UPGRADE_FLOORS: Dictionary = {
	"damage_per_cell": 0.0, "min_cells": 1.0, "cooldown_sec": 0.0, "burn_damage_per_tick": 0.0,
	"burn_duration_sec": 0.0, "pin_duration_sec": 0.0, "push_cells": 0.0,
	"fragile_stacks": 0.0, "frost_stacks": 0.0,
	"thorn_sec": 0.0, "thorn_damage": 0.0, "thorn_fragile_stacks": 0.0,
	"parry_sec": 0.0, "reflect_mult": 0.0, "parry_pin_sec": 0.0,
}

## Story 027: the optional per-card zone number keys.
const ZONE_KEYS: Array[String] = ["thorn_sec", "thorn_damage", "thorn_fragile_stacks"]
## Story 027: card effects that form a zone (kept out of the boss's card list).
const ZONE_EFFECTS: Array[String] = ["thorns"]
## Cast rhythm spec 2026-11-05 (design/quick-specs/nhip-ra-chieu-2026-11-05.md 1.1): how a card resolves. Only `direct`
## (the old behaviour, the default) and `parry` (the Knight's Do Kiem) are implemented; the other modes of the spec are
## later stories and an unknown mode falls back to `direct` (warning).
const CAST_MODE_DIRECT: String = "direct"
const CAST_MODE_PARRY: String = "parry"
const CAST_MODES: Array[String] = [CAST_MODE_DIRECT, CAST_MODE_PARRY]
## Parry numbers used when a `parry` card omits its own (cards.json normally carries them).
const PARRY_DEFAULTS: Dictionary = {"parry_sec": 0.8, "reflect_mult": 1.5, "parry_pin_sec": 1.2}

## Simulation speed factor while the card menu is open (0..1). Applied by the view.
var menu_time_scale: float = 0.2
## REAL seconds the player has to choose before the default card is auto-picked.
var menu_choose_sec: float = 3.0
## Cards drawn into the menu hand per cut (>= 1).
var hand_size: int = 4
## Basic card chosen on timeout (a rule, not a card in the hand); always in [member cards].
var default_card: String = FALLBACK_SKILL
## Starting deck: card ids (duplicates allowed), all known; never empty.
var default_deck: Array[String] = [FALLBACK_SKILL]
## Focus: simulation speed factor while active (0 = full stop, 0..1).
var focus_time_scale: float = 0.0
## Focus: max REAL seconds one Focus lasts (> 0).
var focus_max_sec: float = 4.0
## Focus: REAL seconds before it can start again (>= 0).
var focus_cooldown_sec: float = 8.0
## Focus: true = the player cannot step while Focus is active.
var focus_locks_movement: bool = true
## Stable display order of the known NON-curse PLAYER card ids (also the boss's default card list and the
## reward / shop pool: Story 033 curse cards and `player_pool: false` cards (the boss-only Wall cards, quick
## spec o-rot-thay-tuong 2026-10-31) are never in it, whatever cards.json lists).
var card_order: Array[String] = [FALLBACK_SKILL]
## id -> {name_key, desc_key, effect, min_cells, cooldown_sec, damage_per_cell, push_cells,
## burn_*, pin_duration_sec, fragile_stacks, frost_stacks, pierce_defense, execute, execute_ratio,
## bonus_vs_fragile_mult, rarity, draw_damage, upgrade, implemented, player_pool, delivery, cast_mode, crit} (level 1
## values; see
## [method resolved]). `delivery` = SkillDelivery.parse of the card's `delivery` object (ADR-0001 D7 / A1).
## Story 033: rarity `curse` cards (ganh_nang, oan_hon) carry `draw_damage` (HP the player loses each
## time the card is drawn into the card menu; 0 = none).
## Story 027 zone cards (effect thorns) may also carry the optional per-card overrides
## thorn_sec, thorn_damage, thorn_fragile_stacks; a key the card omits is absent here and combat.json
## `zones` supplies the number.
var cards: Dictionary = {}


func _init() -> void:
	cards[FALLBACK_SKILL] = {
		"delivery": SkillDelivery.parse({"type": SkillDelivery.CASTER_TO_TARGET, "origin": "caster", "travel": "hero_pack", "impact": "burst"}),
		"effect": "damage", "burn_duration_sec": 0.0, "burn_tick_sec": 0.5,
		"burn_damage_per_tick": 0.0, "pin_duration_sec": 0.0,
		"name_key": "card.kiem_khi.name", "desc_key": "card.kiem_khi.desc", "min_cells": 1, "cooldown_sec": 0.0,
		"damage_per_cell": CutConfig.load_from_file().base_damage_per_cell, "push_cells": 0,
			"rarity": "common", "upgrade": {"damage_per_cell": 1.0}, "implemented": true,
	}


## Loads from a JSON file. Never null: a missing or bad file gives defaults (warning).
static func load_from_file(path: String = DEFAULT_PATH) -> SkillConfig:
	if not FileAccess.file_exists(path):
		push_warning("SkillConfig: file not found: %s, using defaults" % path)
		return SkillConfig.new()
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Never null (defaults + warning if invalid).
static func from_json_text(text: String) -> SkillConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SkillConfig: JSON root must be an object, using defaults")
		return SkillConfig.new()
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults, values are clamped.
static func from_dictionary(data: Dictionary) -> SkillConfig:
	var config := SkillConfig.new()
	config.menu_time_scale = clampf(float(data.get("menu_time_scale", config.menu_time_scale)), 0.0, 1.0)
	config.menu_choose_sec = maxf(float(data.get("menu_choose_sec", config.menu_choose_sec)), 0.0)
	config.hand_size = maxi(int(data.get("hand_size", config.hand_size)), 1)
	config._read_focus(data.get("focus"))
	var raw_cards: Variant = data.get("cards")
	if typeof(raw_cards) == TYPE_DICTIONARY and not (raw_cards as Dictionary).is_empty():
		config.cards.clear()
		for id: Variant in (raw_cards as Dictionary).keys():
			var raw: Variant = (raw_cards as Dictionary)[id]
			if typeof(raw) != TYPE_DICTIONARY:
				push_warning("SkillConfig: card %s is not an object, ignored" % str(id))
				continue
			config.cards[str(id)] = _normalize(str(id), raw as Dictionary)
	else:
		push_warning("SkillConfig: no cards in data, using the built-in kiem_khi only")
	if config.cards.is_empty():
		config.cards = SkillConfig.new().cards
	config.card_order = []
	var raw_order: Variant = data.get("card_order")
	if typeof(raw_order) == TYPE_ARRAY:
		for id: Variant in raw_order as Array:
			if config.is_player_card(str(id)) and not config.card_order.has(str(id)):
				config.card_order.append(str(id))
	for id: Variant in config.cards.keys():
		if not config.card_order.has(str(id)) and config.is_player_card(str(id)):
			config.card_order.append(str(id))
	var wanted: String = str(data.get("default_card", FALLBACK_SKILL))
	if config.is_player_card(wanted):
		config.default_card = wanted
	else:
		push_warning("SkillConfig: default_card %s unknown, using the first card" % wanted)
		config.default_card = config.card_order[0]
	config.default_deck = []
	var raw_deck: Variant = data.get("default_deck")
	if typeof(raw_deck) == TYPE_ARRAY:
		for id: Variant in raw_deck as Array:
			if config.is_player_card(str(id)):
				config.default_deck.append(str(id))
			elif config.is_curse(str(id)):
				push_warning("SkillConfig: default_deck card %s is a curse, dropped" % str(id))
			elif config.cards.has(str(id)):
				push_warning("SkillConfig: default_deck card %s is not a player card (player_pool false), dropped" % str(id))
			else:
				push_warning("SkillConfig: default_deck card %s unknown, dropped" % str(id))
	if config.default_deck.is_empty():
		config.default_deck = [config.default_card]
	return config


## True if [param id] is a defined card.
func has_skill(id: String) -> bool:
	return cards.has(id)


## The definition of [param id] (see [member cards]); empty dictionary if unknown.
func get_skill(id: String) -> Dictionary:
	if cards.has(id):
		return cards[id] as Dictionary
	return {}


## True when the player may hold [param id]: a known, non-curse card whose `player_pool` is not false.
## `player_pool: false` keeps a card out of every player source (starter deck, reward, shop, event, achievement,
## Kiep); quick spec 2026-10-31. Its only users, the Wall cards (ket_gioi, long_an, luoi_san), were deleted on
## 2026-11-01 with the seal effect; the flag is kept (harmless, no card sets it today) for future boss-only cards.
func is_player_card(id: String) -> bool:
	return cards.has(id) and not is_curse(id) and bool((cards[id] as Dictionary).get("player_pool", true))


## Story 027: true when [param id] is a zone card (effect in [constant ZONE_EFFECTS]). The boss never
## plays these: it gets zones only through its traits (seal_caster, thorn_field).
func is_zone_card(id: String) -> bool:
	return ZONE_EFFECTS.has(str(get_skill(id).get("effect", "")))


## Story 027: [member card_order] without the zone cards: the boss's default card list. Cast rhythm spec 2026-11-05:
## also without the cards whose cast_mode is not `direct` (a parry answers the ENEMY's telegraph; the boss never has one
## to answer), see [method is_boss_playable].
func boss_card_order() -> Array[String]:
	var out: Array[String] = []
	for id: String in card_order:
		if is_boss_playable(id):
			out.append(id)
	return out


## True when the block-brain boss may hold card [param id]: a known card that is not a zone card and casts `direct`.
func is_boss_playable(id: String) -> bool:
	return cards.has(id) and not is_zone_card(id) and cast_mode(id) == CAST_MODE_DIRECT


## Cast rhythm spec 2026-11-05: the cast_mode of [param id] ("direct" for an unknown card).
func cast_mode(id: String) -> String:
	return str(get_skill(id).get("cast_mode", CAST_MODE_DIRECT))


## True when [param id] is a `parry` card (available only during an enemy telegraph, opens a guard; SkillAvailability,
## ParryGuard).
func is_parry_card(id: String) -> bool:
	return cast_mode(id) == CAST_MODE_PARRY


## Story 033: true when [param id] is a curse card (rarity `curse`). Curses take a card-menu slot and
## are shown locked, never upgrade, never appear in reward / shop pools or the boss deck, and do not
## count toward the run's min_deck_size. Unknown id: false.
## Cast rhythm spec 2026-11-05 (user: "Riêng Kiếm sĩ"): the hero id a hero card belongs to ("" = shared pool).
## A hero card is a player card (it may sit in that hero's starter deck) but never enters a reward / shop / event
## pool ([method is_pool_card]).
func hero_of(id: String) -> String:
	return str(get_skill(id).get("hero", ""))


## True when [param id] may be drawn from the shared pools (RewardRoller): a player card that is not a hero card.
func is_pool_card(id: String) -> bool:
	return is_player_card(id) and hero_of(id).is_empty()


func is_curse(id: String) -> bool:
	return str(get_skill(id).get("rarity", "")) == CURSE_RARITY


## Story 033: HP the player loses each time curse [param id] is drawn into the card menu (0 for any
## other card).
func draw_damage(id: String) -> float:
	return maxf(float(get_skill(id).get("draw_damage", 0.0)), 0.0)


## Story 033: ids of the curse cards in cards.json order.
func curse_ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in cards.keys():
		if is_curse(str(id)):
			out.append(str(id))
	return out


## Rarity of [param id] ("common" / "rare" / "epic" / "curse"); "common" if unknown.
func get_rarity(id: String) -> String:
	return str(get_skill(id).get("rarity", "common"))


## The card [param id] at [param level] (clamped to 1..MAX_LEVEL) with its `upgrade` deltas applied
## once per level above 1 (min_cells >= 1, cooldown >= 0, others >= 0). Same keys as
## [method get_skill] plus "level". Unknown id: {}. The single place upgrades are summed.
func resolved(id: String, level: int = 1) -> Dictionary:
	if not cards.has(id):
		return {}
	var card: Dictionary = (cards[id] as Dictionary).duplicate(true)
	# Story 033: a curse never levels.
	var lv: int = 1 if is_curse(id) else clampi(level, 1, MAX_LEVEL)
	var upgrade: Dictionary = card.get("upgrade", {}) as Dictionary
	for key: Variant in upgrade.keys():
		var floor_value: float = float(UPGRADE_FLOORS.get(str(key), 0.0))
		var value: float = maxf(float(card.get(key, 0.0)) + float(upgrade[key]) * float(lv - 1), floor_value)
		card[key] = int(value) if typeof(card.get(key, 0.0)) == TYPE_INT else value
	card["level"] = lv
	return card


# Parses the optional "focus" object; bad or missing values keep the defaults (warning if bad).
func _read_focus(raw: Variant) -> void:
	if raw == null:
		return
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("SkillConfig: focus must be an object, using defaults")
		return
	var focus: Dictionary = raw as Dictionary
	focus_time_scale = _number(focus, "focus_time_scale", focus_time_scale, 0.0, 1.0, true)
	focus_max_sec = _number(focus, "focus_max_sec", focus_max_sec, 0.0, INF, false)
	focus_cooldown_sec = _number(focus, "focus_cooldown_sec", focus_cooldown_sec, 0.0, INF, true)
	if focus.has("focus_locks_movement"):
		if typeof(focus["focus_locks_movement"]) == TYPE_BOOL:
			focus_locks_movement = bool(focus["focus_locks_movement"])
		else:
			push_warning("SkillConfig: focus_locks_movement must be true/false, using default")


# A numeric focus value: non-number => default (warning); clamped to [low, high]; when
# [param allow_low] is false the value must be > low, otherwise the default is used (warning).
static func _number(d: Dictionary, key: String, fallback: float, low: float, high: float, allow_low: bool) -> float:
	if not d.has(key):
		return fallback
	var v: Variant = d[key]
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		push_warning("SkillConfig: %s must be a number, using %s" % [key, fallback])
		return fallback
	var value: float = float(v)
	if is_nan(value) or value < low or (not allow_low and value <= low):
		push_warning("SkillConfig: %s is out of range, using %s" % [key, fallback])
		return fallback
	return clampf(value, low, high)


static func _normalize(id: String, raw: Dictionary) -> Dictionary:
	var tick: float = float(raw.get("burn_tick_sec", 0.5))
	if tick <= 0.0:
		push_warning("SkillConfig: card %s burn_tick_sec must be > 0, using 0.5" % id)
		tick = 0.5
	var rarity: String = str(raw.get("rarity", "common"))
	if not RARITIES.has(rarity) and rarity != CURSE_RARITY:
		push_warning("SkillConfig: card %s rarity '%s' unknown, using common" % [id, rarity])
		rarity = "common"
	var effect: String = str(raw.get("effect", "damage"))
	if not EFFECTS.has(effect):
		push_warning("SkillConfig: card %s effect '%s' unknown" % [id, effect])
	var upgrade: Dictionary = {}
	var raw_up: Variant = raw.get("upgrade")
	if rarity == CURSE_RARITY:
		pass  # Story 033: a curse has no upgrade table (never upgradable)
	elif typeof(raw_up) == TYPE_DICTIONARY:
		for key: Variant in (raw_up as Dictionary).keys():
			if UPGRADE_FLOORS.has(str(key)) and (typeof((raw_up as Dictionary)[key]) == TYPE_FLOAT or typeof((raw_up as Dictionary)[key]) == TYPE_INT):
				upgrade[str(key)] = float((raw_up as Dictionary)[key])
			else:
				push_warning("SkillConfig: card %s upgrade key '%s' invalid, ignored" % [id, str(key)])
	else:
		push_warning("SkillConfig: card %s has no upgrade table" % id)
	# Fallback for a card without damage_per_cell: the global cuts.json base_damage_per_cell; a burn card without it
	# has no hit damage (2026-11-05: a burn card's damage_per_cell is now dealt on a hit, CutEffects burn_hits_too).
	var dpc: float = 0.0
	if raw.has("damage_per_cell"):
		dpc = maxf(float(raw["damage_per_cell"]), 0.0)
	elif effect != "burn":
		dpc = CutConfig.load_from_file().base_damage_per_cell
	var out: Dictionary = {
		"effect": effect,
		"burn_duration_sec": maxf(float(raw.get("burn_duration_sec", 0.0)), 0.0),
		"burn_tick_sec": tick,
		"burn_damage_per_tick": maxf(float(raw.get("burn_damage_per_tick", 0.0)), 0.0),
		"pin_duration_sec": maxf(float(raw.get("pin_duration_sec", 0.0)), 0.0),
		"name_key": str(raw.get("name_key", "card.%s.name" % id)),
		"desc_key": str(raw.get("desc_key", "card.%s.desc" % id)),
		"min_cells": maxi(int(raw.get("min_cells", 1)), 1),
		"cooldown_sec": maxf(float(raw.get("cooldown_sec", 0.0)), 0.0),
		"damage_per_cell": dpc,
		"push_cells": maxi(int(raw.get("push_cells", 0)), 0),
		# Story 023: keyword stacks the card applies to a target it hits, defense piercing, execute
		# (execute_ratio > 0 = own threshold; execute true = combat.json default) and the Ran bonus.
		"fragile_stacks": maxi(int(raw.get("fragile_stacks", 0)), 0),
		"frost_stacks": maxi(int(raw.get("frost_stacks", 0)), 0),
		"pierce_defense": bool(raw.get("pierce_defense", false)),
		# Story 037: HP the CASTER heals when the cut lands (hit or miss); 0 = none.
		"heal_self": maxf(float(raw.get("heal_self", 0.0)), 0.0),
		"execute": bool(raw.get("execute", false)),
		"execute_ratio": clampf(float(raw.get("execute_ratio", 0.0)), 0.0, 1.0),
		"bonus_vs_fragile_mult": maxf(float(raw.get("bonus_vs_fragile_mult", 1.0)), 1.0),
		"rarity": rarity,
		"draw_damage": maxf(float(raw.get("draw_damage", 0.0)), 0.0) if rarity == CURSE_RARITY else 0.0,
		"upgrade": upgrade,
		"implemented": bool(raw.get("implemented", false)),
		"player_pool": bool(raw.get("player_pool", true)),
		"hero": str(raw.get("hero", "")),
		# ADR-0001 D7 / A1: the card's delivery (origin, travel, impact, cell mask = the block shape); presentation
		# only - CutEffects never reads it (SkillDelivery).
		"delivery": SkillDelivery.parse(raw.get("delivery"), "card %s" % id),
		# Cast rhythm spec 2026-11-05 1.1 / 1.2: the cast mode and the optional crit ({} = none, CritRules.normalize).
		"cast_mode": _cast_mode(id, raw),
		"crit": CritRules.normalize(raw.get("crit"), "card %s" % id),
	}
	if str(out["cast_mode"]) == CAST_MODE_PARRY:
		for key: String in PARRY_DEFAULTS.keys():
			out[key] = maxf(float(raw.get(key, PARRY_DEFAULTS[key])), 0.0)
	# Story 027: optional per-card zone numbers (absent = the combat.json `zones` block decides).
	for key: String in ZONE_KEYS:
		if raw.has(key):
			out[key] = maxi(int(raw[key]), 0) if key == "thorn_fragile_stacks" else maxf(float(raw[key]), 0.0)
	return out


# The card's cast_mode, `direct` when absent; an unknown mode is `direct` (warning).
static func _cast_mode(id: String, raw: Dictionary) -> String:
	var mode: String = str(raw.get("cast_mode", CAST_MODE_DIRECT))
	if not CAST_MODES.has(mode):
		push_warning("SkillConfig: card %s cast_mode '%s' unknown or not implemented, using direct" % [id, mode])
		return CAST_MODE_DIRECT
	return mode

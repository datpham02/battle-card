class_name SkillConfig
extends RefCounted
## Card definitions, deck defaults and card-menu timing from assets/data/cards.json.
## (Class name kept from the v3 "skills" era; a skill is now a card.)
## Schema: assets/data/schema.md. Implements: Story 008 (skills data; burn/pin: Story 010),
## Story 017 part A (cards, hand_size, default deck).

const DEFAULT_PATH: String = "res://assets/data/cards.json"
## Card id used when nothing else is chosen; always present in [member cards].
const FALLBACK_SKILL: String = "kiem_khi"
const RARITIES: Array[String] = ["common", "rare", "epic"]

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
## Stable display order of the known card ids (also the boss's default card list).
var card_order: Array[String] = [FALLBACK_SKILL]
## id -> {name_key, desc_key, effect, min_cells, cooldown_sec, damage_multiplier, push_cells,
## burn_*, pin_duration_sec, rarity, class_tags, implemented}
var cards: Dictionary = {}


func _init() -> void:
	cards[FALLBACK_SKILL] = {
		"effect": "damage", "burn_duration_sec": 0.0, "burn_tick_sec": 0.5,
		"burn_damage_per_tick": 0.0, "pin_duration_sec": 0.0,
		"name_key": "card.kiem_khi.name", "desc_key": "card.kiem_khi.desc", "min_cells": 1, "cooldown_sec": 0.0,
		"damage_multiplier": 1.0, "push_cells": 0, "rarity": "common", "class_tags": [],
		"implemented": true,
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
			if config.cards.has(str(id)) and not config.card_order.has(str(id)):
				config.card_order.append(str(id))
	for id: Variant in config.cards.keys():
		if not config.card_order.has(str(id)):
			config.card_order.append(str(id))
	var wanted: String = str(data.get("default_card", FALLBACK_SKILL))
	if config.cards.has(wanted):
		config.default_card = wanted
	else:
		push_warning("SkillConfig: default_card %s unknown, using the first card" % wanted)
		config.default_card = config.card_order[0]
	config.default_deck = []
	var raw_deck: Variant = data.get("default_deck")
	if typeof(raw_deck) == TYPE_ARRAY:
		for id: Variant in raw_deck as Array:
			if config.cards.has(str(id)):
				config.default_deck.append(str(id))
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


## Rarity of [param id] ("common" / "rare" / "epic"); "common" if unknown.
func get_rarity(id: String) -> String:
	return str(get_skill(id).get("rarity", "common"))


## Class tags of [param id] (empty if none or unknown).
func get_class_tags(id: String) -> Array[String]:
	var tags: Array[String] = []
	for tag: Variant in get_skill(id).get("class_tags", []) as Array:
		tags.append(str(tag))
	return tags


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
	if not RARITIES.has(rarity):
		push_warning("SkillConfig: card %s rarity '%s' unknown, using common" % [id, rarity])
		rarity = "common"
	var tags: Array = []
	var raw_tags: Variant = raw.get("class_tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for tag: Variant in raw_tags as Array:
			tags.append(str(tag))
	else:
		push_warning("SkillConfig: card %s class_tags must be an array, ignored" % id)
	return {
		"effect": str(raw.get("effect", "damage")),
		"burn_duration_sec": maxf(float(raw.get("burn_duration_sec", 0.0)), 0.0),
		"burn_tick_sec": tick,
		"burn_damage_per_tick": maxf(float(raw.get("burn_damage_per_tick", 0.0)), 0.0),
		"pin_duration_sec": maxf(float(raw.get("pin_duration_sec", 0.0)), 0.0),
		"name_key": str(raw.get("name_key", "card.%s.name" % id)),
		"desc_key": str(raw.get("desc_key", "card.%s.desc" % id)),
		"min_cells": maxi(int(raw.get("min_cells", 1)), 1),
		"cooldown_sec": maxf(float(raw.get("cooldown_sec", 0.0)), 0.0),
		"damage_multiplier": maxf(float(raw.get("damage_multiplier", 1.0)), 0.0),
		"push_cells": maxi(int(raw.get("push_cells", 0)), 0),
		"rarity": rarity,
		"class_tags": tags,
		"implemented": bool(raw.get("implemented", false)),
	}

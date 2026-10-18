class_name CombatConfig
extends RefCounted
## Card effects and combat start values, loaded from assets/data/combat_cards.json.
## Schema: assets/data/schema.md. Implements: Story 003.

const DEFAULT_PATH: String = "res://assets/data/combat_cards.json"
const EFFECT_ATTACK: String = "attack"
const EFFECT_SHIELD: String = "shield"


## One card's placeholder effect.
class CardEffect:
	extends RefCounted
	## Either EFFECT_ATTACK or EFFECT_SHIELD.
	var effect: String = ""
	## Damage or armor points.
	var amount: float = 0.0
	## Play lock in seconds.
	var recovery_sec: float = 0.0
	## True if the card also moves the player to an adjacent lane (the drop lane chooses it).
	var lane_shift: bool = false


var player_max_hp: float = 100.0
var enemy_max_hp: float = 100.0
var _effects: Dictionary = {} # type_id -> CardEffect


## Loads from a JSON file. Returns null (and pushes an error) on failure.
static func load_from_file(path: String = DEFAULT_PATH) -> CombatConfig:
	if not FileAccess.file_exists(path):
		push_error("CombatConfig: file not found: %s" % path)
		return null
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Returns null (and pushes an error) if invalid.
static func from_json_text(text: String) -> CombatConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CombatConfig: JSON root must be an object")
		return null
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults.
static func from_dictionary(data: Dictionary) -> CombatConfig:
	var config := CombatConfig.new()
	config.player_max_hp = maxf(float(data.get("player_max_hp", config.player_max_hp)), 1.0)
	config.enemy_max_hp = maxf(float(data.get("enemy_max_hp", config.enemy_max_hp)), 1.0)
	var cards: Variant = data.get("cards", {})
	if typeof(cards) != TYPE_DICTIONARY:
		return config
	var table: Dictionary = cards as Dictionary
	for id: Variant in table:
		if typeof(table[id]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = table[id] as Dictionary
		var kind: String = str(entry.get("effect", ""))
		if kind != EFFECT_ATTACK and kind != EFFECT_SHIELD:
			push_warning("CombatConfig: card '%s' has unknown effect '%s'" % [id, kind])
			continue
		var effect := CardEffect.new()
		effect.effect = kind
		effect.amount = maxf(float(entry.get("amount", 0.0)), 0.0)
		effect.recovery_sec = maxf(float(entry.get("recovery_sec", 0.0)), 0.0)
		effect.lane_shift = bool(entry.get("lane_shift", false))
		config._effects[str(id)] = effect
	return config


## Effect for card type [param type_id], or null if the card has none.
func get_effect(type_id: String) -> CardEffect:
	return _effects.get(type_id, null) as CardEffect

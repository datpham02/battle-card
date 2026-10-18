class_name CombatConfig
extends RefCounted
## Card effects and combat start values, loaded from assets/data/combat_cards.json.
## Schema: assets/data/schema.md. Implements: Story 003.

const DEFAULT_PATH: String = "res://assets/data/combat_cards.json"
const EFFECT_ATTACK: String = "attack"
const EFFECT_SHIELD: String = "shield"
const EFFECT_MOVE: String = "move"


## One card's placeholder effect.
class CardEffect:
	extends RefCounted
	## EFFECT_ATTACK, EFFECT_SHIELD or EFFECT_MOVE (step to an adjacent own-half cell).
	var effect: String = ""
	## Damage or armor points.
	var amount: float = 0.0
	## Play lock in seconds.
	var recovery_sec: float = 0.0
	## Name of the shape preset (empty for move cards).
	var shape_name: String = ""
	## Resolved shape offsets relative to the attacker (+dx = toward the opponent).
	var shape: Array[Vector2i] = []


var player_max_hp: float = 100.0
var enemy_max_hp: float = 100.0
## Board cell each unit starts on (validated against its half by CombatState).
var player_start_cell: Vector2i = Vector2i(1, 1)
var enemy_start_cell: Vector2i = Vector2i(4, 1)
## Cap (s) on one frame's time step so a frame hitch cannot skip logic windows.
var max_tick_sec: float = 0.1
## Seconds the HIT / MISS feedback stays on screen.
var feedback_sec: float = 1.0
var _shapes: Dictionary = {} # name -> Array[Vector2i]
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
	config.player_start_cell = _parse_cell(data.get("player_start_cell"), config.player_start_cell)
	config.enemy_start_cell = _parse_cell(data.get("enemy_start_cell"), config.enemy_start_cell)
	config.max_tick_sec = maxf(float(data.get("max_tick_sec", config.max_tick_sec)), 0.001)
	config.feedback_sec = maxf(float(data.get("feedback_sec", config.feedback_sec)), 0.0)
	var shapes: Variant = data.get("shapes", {})
	if typeof(shapes) == TYPE_DICTIONARY:
		for shape_id: Variant in shapes:
			config._shapes[str(shape_id)] = _parse_offsets(shapes[shape_id])
	var cards: Variant = data.get("cards", {})
	if typeof(cards) != TYPE_DICTIONARY:
		return config
	var table: Dictionary = cards as Dictionary
	for id: Variant in table:
		if typeof(table[id]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = table[id] as Dictionary
		var kind: String = str(entry.get("effect", ""))
		if kind != EFFECT_ATTACK and kind != EFFECT_SHIELD and kind != EFFECT_MOVE:
			push_warning("CombatConfig: card '%s' has unknown effect '%s'" % [id, kind])
			continue
		var effect := CardEffect.new()
		effect.effect = kind
		effect.amount = maxf(float(entry.get("amount", 0.0)), 0.0)
		effect.recovery_sec = maxf(float(entry.get("recovery_sec", 0.0)), 0.0)
		if kind != EFFECT_MOVE:
			effect.shape_name = str(entry.get("shape", "self"))
			if not config._shapes.has(effect.shape_name):
				push_warning("CombatConfig: card '%s' has unknown shape '%s'" % [id, effect.shape_name])
				continue
			effect.shape = config._shapes[effect.shape_name]
		config._effects[str(id)] = effect
	return config


## Effect for card type [param type_id], or null if the card has none.
func get_effect(type_id: String) -> CardEffect:
	return _effects.get(type_id, null) as CardEffect


## Shape preset [param shape_name] as offsets, or an empty array if unknown.
func get_shape(shape_name: String) -> Array[Vector2i]:
	var shape: Array[Vector2i] = []
	shape.assign(_shapes.get(shape_name, []))
	return shape


static func _parse_cell(raw: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() == 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return fallback


static func _parse_offsets(raw: Variant) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY:
		return offsets
	for pair: Variant in raw as Array:
		if typeof(pair) == TYPE_ARRAY and (pair as Array).size() == 2:
			offsets.append(Vector2i(int((pair as Array)[0]), int((pair as Array)[1])))
	return offsets

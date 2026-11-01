class_name CharacterConfig
extends RefCounted
## Playable characters (classes) from assets/data/characters.json (Story 018): base stats, a
## pluggable passive (see PassiveRegistry) and a starter deck. Pure data: no scene access.
## Validation: duplicate id -> warning, the later one dropped; unknown card in starter_deck ->
## warning, that card dropped; empty deck -> SkillConfig.default_deck; max_hp >= 1;
## step_cooldown_mult > 0 else 1; focus_max_sec >= 0. Never null from [method load_from_file].
## Implements: Story 018 (design/game-brief.md v4 "Nhan vat theo lop").

const DEFAULT_PATH: String = "res://assets/data/characters.json"
## Built-in fallback character when the file is missing or unusable.
const FALLBACK_ID: String = "kiem_si"
const FALLBACK_MAX_HP: float = 100.0
const FALLBACK_FOCUS_SEC: float = 4.0

var _order: Array[String] = []
var _characters: Dictionary = {}
var _default_id: String = ""
# Story 037: Callable(character_id: String) -> bool, the progress-based unlock test; invalid = everything unlocked.
var _unlock_source: Callable = Callable()


## Loads [param path]; a missing / unparsable / empty file gives one built-in character (warning).
static func load_from_file(path: String = DEFAULT_PATH) -> CharacterConfig:
	if not FileAccess.file_exists(path):
		push_warning("CharacterConfig: %s missing, using the built-in character" % path)
		return from_dictionary({})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("CharacterConfig: %s is not a JSON object, using the built-in character" % path)
		return from_dictionary({})
	return from_dictionary(parsed as Dictionary)


## Builds a config from a parsed dictionary (see assets/data/schema.md). Never null.
static func from_dictionary(data: Dictionary) -> CharacterConfig:
	var config := CharacterConfig.new()
	var known_cards: SkillConfig = SkillConfig.load_from_file()
	var raw: Variant = data.get("characters", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry: Variant in raw as Array:
			if typeof(entry) == TYPE_DICTIONARY:
				config._add(entry as Dictionary, known_cards)
	if config._order.is_empty():
		if not data.is_empty():
			push_warning("CharacterConfig: no valid character, using the built-in one")
		config._add_fallback(known_cards)
	var wanted: String = str(data.get("default_character", ""))
	if config._characters.has(wanted):
		config._default_id = wanted
	else:
		if not wanted.is_empty():
			push_warning("CharacterConfig: default_character '%s' unknown, using '%s'" % [wanted, config._order[0]])
		config._default_id = config._order[0]
	return config


## Every character id in file order.
func ids() -> Array[String]:
	return _order.duplicate()


## Story 037: sets the unlock test, Callable(character_id: String) -> bool (GameFlow: the earned achievements
## that list the character as a reward). An invalid Callable (the default) = every character is unlocked, which
## keeps tests and the simulation as they were. A character without `unlock_by` is always unlocked.
func set_unlock_source(fn: Callable) -> void:
	_unlock_source = fn


## Ids of the unlocked characters (see [method set_unlock_source]), in file order.
func unlocked_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _order:
		if _is_unlocked(id):
			out.append(id)
	return out


## True when [param id] is a character.
func has(id: String) -> bool:
	return _characters.has(id)


## A copy of the cleaned character [param id] ({id, name_key, desc_key, max_hp, step_cooldown_mult,
## focus_max_sec, passive {id, params}, passive_name_key, passive_desc_key, signature ({} or
## {id, name_key, desc_key, params}, Story 021), starter_deck, unlock_by (Story 037: achievement id or ""),
## unlocked (computed with the unlock source)}); {} when unknown.
func get_character(id: String) -> Dictionary:
	if not _characters.has(id):
		return {}
	var out: Dictionary = (_characters[id] as Dictionary).duplicate(true)
	out["unlocked"] = _is_unlocked(id)
	return out


## Id of the default character (default_character of the file, else the first one).
func default_id() -> String:
	return _default_id


## Starter deck card ids of [param id] (empty array when unknown).
func deck_of(id: String) -> Array[String]:
	var out: Array[String] = []
	if _characters.has(id):
		for card: Variant in (_characters[id] as Dictionary)["starter_deck"] as Array:
			out.append(str(card))
	return out


# Story 037: no unlock_by or no source = unlocked; else the source decides.
func _is_unlocked(id: String) -> bool:
	if str((_characters[id] as Dictionary)["unlock_by"]).is_empty() or not _unlock_source.is_valid():
		return true
	return bool(_unlock_source.call(id))


func _add(raw: Dictionary, skills: SkillConfig) -> void:
	var id: String = str(raw.get("id", ""))
	if id.is_empty():
		push_warning("CharacterConfig: character without id dropped")
		return
	if _characters.has(id):
		push_warning("CharacterConfig: duplicate character id '%s' dropped" % id)
		return
	var deck: Array[String] = []
	var raw_deck: Variant = raw.get("starter_deck", [])
	if typeof(raw_deck) == TYPE_ARRAY:
		for card: Variant in raw_deck as Array:
			if skills.is_player_card(str(card)):
				deck.append(str(card))
			elif skills.has_skill(str(card)):
				push_warning("CharacterConfig: %s starter_deck card '%s' is not a player card, dropped" % [id, str(card)])
			else:
				push_warning("CharacterConfig: %s starter_deck card '%s' unknown, dropped" % [id, str(card)])
	if deck.is_empty():
		push_warning("CharacterConfig: %s has an empty deck, using the default deck" % id)
		deck = skills.default_deck.duplicate()
	var mult: float = float(raw.get("step_cooldown_mult", 1.0))
	var passive: Dictionary = {"id": "", "params": {}}
	var raw_passive: Variant = raw.get("passive")
	if typeof(raw_passive) == TYPE_DICTIONARY:
		passive["id"] = str((raw_passive as Dictionary).get("id", ""))
		var params: Variant = (raw_passive as Dictionary).get("params", {})
		passive["params"] = (params as Dictionary).duplicate(true) if typeof(params) == TYPE_DICTIONARY else {}
	var signature: Dictionary = _read_signature(id, raw.get("signature"))
	_characters[id] = {
		"id": id,
		"name_key": str(raw.get("name_key", "")),
		"desc_key": str(raw.get("desc_key", "")),
		"max_hp": maxf(float(raw.get("max_hp", FALLBACK_MAX_HP)), 1.0),
		"step_cooldown_mult": mult if mult > 0.0 else 1.0,
		"focus_max_sec": maxf(float(raw.get("focus_max_sec", FALLBACK_FOCUS_SEC)), 0.0),
		"passive": passive,
		"passive_name_key": str(raw.get("passive_name_key", "")),
		"passive_desc_key": str(raw.get("passive_desc_key", "")),
		"signature": signature,
		"starter_deck": deck,
		"unlock_by": str(raw.get("unlock_by", "")),
	}
	_order.append(id)


# Story 021: the cleaned `signature` block ({id, name_key, desc_key, cooldown_sec, params}) or {} when
# absent; malformed (not an object, empty / unknown id) -> warning and {} (no signature).
# Story 029: `charge_cells` is gone (the formation map replaces the charge bar); a leftover key is ignored.
func _read_signature(id: String, raw: Variant) -> Dictionary:
	if raw == null:
		return {}
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("CharacterConfig: %s signature is not an object, none used" % id)
		return {}
	var dict: Dictionary = raw as Dictionary
	var sig_id: String = str(dict.get("id", ""))
	if sig_id.is_empty() or not SignatureRegistry.has_id(sig_id):
		push_warning("CharacterConfig: %s signature id '%s' unknown (known: %s), none used" % [id, sig_id, ", ".join(SignatureRegistry.known_ids())])
		return {}
	var params: Variant = dict.get("params", {})
	# Story 029 Phần D: cooldown after each use; missing -> 0, negative -> 0, non-number -> warning and 0.
	var cooldown_raw: Variant = dict.get("cooldown_sec", 0.0)
	var cooldown: float = 0.0
	if typeof(cooldown_raw) == TYPE_FLOAT or typeof(cooldown_raw) == TYPE_INT:
		cooldown = maxf(float(cooldown_raw), 0.0)
	else:
		push_warning("CharacterConfig: %s signature cooldown_sec is not a number, 0 used" % id)
	return {
		"id": sig_id,
		"name_key": str(dict.get("name_key", "")),
		"desc_key": str(dict.get("desc_key", "")),
		"cooldown_sec": cooldown,
		"params": (params as Dictionary).duplicate(true) if typeof(params) == TYPE_DICTIONARY else {},
	}


func _add_fallback(skills: SkillConfig) -> void:
	_add({"id": FALLBACK_ID, "name_key": "character.kiem_si.name", "desc_key": "character.kiem_si.desc",
		"max_hp": FALLBACK_MAX_HP, "step_cooldown_mult": 1.0, "focus_max_sec": FALLBACK_FOCUS_SEC,
		"starter_deck": skills.default_deck}, skills)

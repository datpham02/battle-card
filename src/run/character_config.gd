class_name CharacterConfig
extends RefCounted
## Playable characters from assets/data/characters.json (Story 018): identity, base stats, a
## pluggable passive (see PassiveRegistry) and a starter deck. Pure data: no scene access.
## There is no class and no weapon system: a character IS the unit of identity (user decision
## 2026-10-22, design/game-brief.md "Nhân vật (018, 021) — không có lớp").
## Validation: duplicate id -> warning, the later one dropped; unknown card in starter_deck ->
## warning, that card dropped; empty deck -> SkillConfig.default_deck; max_hp >= 1;
## step_cooldown_mult > 0 else 1; focus_max_sec >= 0. Never null from [method load_from_file].
## Implements: Story 018 (design/game-brief.md v4 "Nhan vat theo lop").

const DEFAULT_PATH: String = "res://assets/data/characters.json"
## Built-in fallback character when the file is missing or unusable.
const FALLBACK_ID: String = "kiem_si"
const FALLBACK_MAX_HP: float = 100.0
const FALLBACK_FOCUS_SEC: float = 4.0

## F1 (docs/design/character-system/CHARACTER-SYSTEM-REDESIGN.md §B.3): the `identity` block's
## translation-key fields. Each one is a strings.csv key; an absent field reads as "" and the view
## falls back to `desc_key`. Never a literal string: display text lives in assets/i18n/strings.csv.
const IDENTITY_KEY_FIELDS: Array[String] = [
	"lore_key", "personality_key", "playstyle_key", "block_material_key",
]
## Accent colour used when `identity.accent_color` is absent or unparsable (HudSkin.IVORY).
const FALLBACK_ACCENT: String = "#EFE6D2"

## F2 (pillar 2 "Base Attributes", OD-2 approved 2026-11-13): every per-character stat, with its
## default. Read from the `attributes` block when present, else from the LEGACY flat key of the same
## name at the character's top level (every pre-F2 characters.json keeps working, and both spellings
## stay readable forever — `get_character()` returns them flat, which is the shape 15+ tests expect).
## A value <= 0 or non-numeric falls back to the default with a warning; `max_hp` clamps to >= 1.
## `formation_fade_mult` was proposed and REJECTED under OD-2: it would change the Awakening charge
## rate, which needs its own balance pass. Do not add it here without that decision.
const ATTRIBUTE_DEFAULTS: Dictionary = {
	"max_hp": FALLBACK_MAX_HP,
	"step_cooldown_mult": 1.0,
	"focus_max_sec": FALLBACK_FOCUS_SEC,
	"cast_speed_mult": 1.0,
	"hazard_resist_mult": 1.0,
}
## Attributes that are a multiplier: clamped > 0 (a 0 or negative multiplier is never meaningful).
const ATTRIBUTE_MULTS: Array[String] = ["step_cooldown_mult", "cast_speed_mult", "hazard_resist_mult"]

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


## A copy of the cleaned character [param id] ({id, name_key, desc_key, identity (F1: always a full
## dictionary — lore_key, personality_key, playstyle_key, block_material_key, accent_color, portrait,
## select_art), F2: cast_speed_mult, hazard_resist_mult and `attributes` (all five stats together;
## the three legacy ones stay flat too), max_hp, step_cooldown_mult,
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
	var attributes: Dictionary = _read_attributes(id, raw)
	var passive: Dictionary = {"id": "", "params": {}}
	var raw_passive: Variant = raw.get("passive")
	if typeof(raw_passive) == TYPE_DICTIONARY:
		passive["id"] = str((raw_passive as Dictionary).get("id", ""))
		var params: Variant = (raw_passive as Dictionary).get("params", {})
		passive["params"] = (params as Dictionary).duplicate(true) if typeof(params) == TYPE_DICTIONARY else {}
	var signature: Dictionary = _read_signature(id, raw.get("signature"))
	var identity: Dictionary = _read_identity(id, raw.get("identity"))
	_characters[id] = {
		"id": id,
		"name_key": str(raw.get("name_key", "")),
		"desc_key": str(raw.get("desc_key", "")),
		"identity": identity,
		"max_hp": attributes["max_hp"],
		"step_cooldown_mult": attributes["step_cooldown_mult"],
		"focus_max_sec": attributes["focus_max_sec"],
		# F2: new attributes, flat alongside the three legacy ones (same shape for every consumer).
		"cast_speed_mult": attributes["cast_speed_mult"],
		"hazard_resist_mult": attributes["hazard_resist_mult"],
		"attributes": attributes.duplicate(),
		"passive": passive,
		"passive_name_key": str(raw.get("passive_name_key", "")),
		"passive_desc_key": str(raw.get("passive_desc_key", "")),
		"signature": signature,
		"starter_deck": deck,
		"unlock_by": str(raw.get("unlock_by", "")),
	}
	_order.append(id)


# F2 (pillar 2 "Base Attributes"): every stat of [constant ATTRIBUTE_DEFAULTS], read from the
# `attributes` block first and from the legacy flat key of the same name second, so a pre-F2 file and
# an F2 file both load with identical numbers. Never partial: always all five keys.
# Precedence is deliberate — `attributes` wins over a flat key of the same name, and a character
# carrying BOTH gets a warning, because two different numbers for one stat is an authoring mistake,
# not a feature.
func _read_attributes(id: String, raw: Dictionary) -> Dictionary:
	var block: Dictionary = {}
	var raw_block: Variant = raw.get("attributes")
	if raw_block != null:
		if typeof(raw_block) == TYPE_DICTIONARY:
			block = raw_block as Dictionary
		else:
			push_warning("CharacterConfig: %s attributes is not an object, the legacy flat keys are used" % id)
	var out: Dictionary = {}
	for key: String in ATTRIBUTE_DEFAULTS:
		var fallback: float = float(ATTRIBUTE_DEFAULTS[key])
		var source: Variant = null
		if block.has(key) and raw.has(key):
			push_warning("CharacterConfig: %s sets '%s' both in attributes and at the top level; attributes wins" % [id, key])
		if block.has(key):
			source = block[key]
		elif raw.has(key):
			source = raw[key]
		var value: float = fallback
		if source != null:
			if typeof(source) == TYPE_FLOAT or typeof(source) == TYPE_INT:
				value = float(source)
			else:
				push_warning("CharacterConfig: %s attribute '%s' is not a number, %s used" % [id, key, fallback])
		if ATTRIBUTE_MULTS.has(key) and value <= 0.0:
			if source != null:
				push_warning("CharacterConfig: %s attribute '%s' must be > 0, %s used" % [id, key, fallback])
			value = fallback
		out[key] = value
	out["max_hp"] = maxf(float(out["max_hp"]), 1.0)
	out["focus_max_sec"] = maxf(float(out["focus_max_sec"]), 0.0)
	return out


## F2: a copy of every base attribute of [param id] ([constant ATTRIBUTE_DEFAULTS] for an unknown
## character, so a caller never gets an empty dictionary).
func attributes_of(id: String) -> Dictionary:
	if not _characters.has(id):
		return ATTRIBUTE_DEFAULTS.duplicate()
	return ((_characters[id] as Dictionary)["attributes"] as Dictionary).duplicate()


# F1 (character-system redesign, pillar 1 "Identity"): the cleaned `identity` block. ALWAYS a full
# dictionary with every key present, so a view never has to test for the block itself — an absent or
# malformed block simply yields empty keys and the fallback accent. Nothing here is gameplay: the
# values are translation keys, a colour and two art paths.
# Rules: not an object -> warning and the empty identity; each *_key field is a string key or "";
# `accent_color` must parse as an HTML colour else a warning and FALLBACK_ACCENT; `portrait` /
# `select_art` are res:// paths, "" when the art does not exist yet (F9) — a NON-EMPTY path that is
# missing on disk warns and is cleared, so the select screen falls back to the body sheet instead of
# drawing nothing.
func _read_identity(id: String, raw: Variant) -> Dictionary:
	var out: Dictionary = {
		"lore_key": "", "personality_key": "", "playstyle_key": "", "block_material_key": "",
		"accent_color": FALLBACK_ACCENT, "portrait": "", "select_art": "",
	}
	if raw == null:
		return out
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("CharacterConfig: %s identity is not an object, the empty identity is used" % id)
		return out
	var dict: Dictionary = raw as Dictionary
	for field: String in IDENTITY_KEY_FIELDS:
		out[field] = str(dict.get(field, ""))
	var accent: String = str(dict.get("accent_color", ""))
	if accent.is_empty():
		pass
	elif Color.html_is_valid(accent):
		out["accent_color"] = accent
	else:
		push_warning("CharacterConfig: %s identity accent_color '%s' is not a colour, %s used" % [id, accent, FALLBACK_ACCENT])
	for field: String in ["portrait", "select_art"]:
		var path: String = str(dict.get(field, ""))
		if path.is_empty():
			continue
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			out[field] = path
		else:
			push_warning("CharacterConfig: %s identity %s '%s' does not exist, the body sheet is used" % [id, field, path])
	return out


## F1: the cleaned identity of [param id] (see [method _read_identity]); the empty identity for an
## unknown character, so a caller never gets null.
func identity_of(id: String) -> Dictionary:
	if not _characters.has(id):
		return _read_identity(id, null)
	return ((_characters[id] as Dictionary)["identity"] as Dictionary).duplicate(true)


## F1: the accent colour of [param id] ([constant FALLBACK_ACCENT] when unknown or unset).
func accent_of(id: String) -> Color:
	return Color(str(identity_of(id).get("accent_color", FALLBACK_ACCENT)))


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

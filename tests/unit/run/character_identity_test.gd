extends SceneTree
## F1 of the character-system redesign (docs/design/character-system/CHARACTER-SYSTEM-REDESIGN.md,
## decisions approved 2026-11-13): the `identity` block of every character is present, complete and
## consistent, and CharacterConfig cleans a malformed block instead of crashing.
##
## What it gates, and why each gate exists:
##  1. Every character has all four identity translation keys, and every key resolves in BOTH
##     locales to non-empty text. A key that exists in characters.json but not in strings.csv shows
##     the raw key on the select screen.
##  2. Identity keys follow `character.<id>.<field>` — a key pointing at ANOTHER character's text is
##     the copy-paste failure this pillar is most exposed to, and no generic "key exists" check
##     would catch it.
##  3. Accent colours are valid, distinct, and far enough apart to tell two cards apart at a glance.
##  4. Lore / personality / playstyle text is actually distinct per character (pillar 1: a character
##     must be recognisable without a class or weapon label).
##  5. Art paths are either "" (not produced yet — F9) or exist; CharacterConfig clears a dangling
##     path so the view falls back to the body sheet.
##  6. Malformed / absent blocks degrade to the full empty identity, never to null.
##
## Headless, pure data (no scene). Prints PASS/FAIL lines and FAILS=n, exit code 1 on failure.
## Run: godot --headless -s res://tests/unit/run/character_identity_test.gd

const CSV_PATH: String = "res://assets/i18n/strings.csv"
const LOCALES: Array[String] = ["vi", "en"]
const KEY_FIELDS: Array[String] = ["lore_key", "personality_key", "playstyle_key", "block_material_key"]
const PATH_FIELDS: Array[String] = ["portrait", "select_art"]
## Two accent colours closer than this (sum of the RGB channel distances) read as the same colour on
## a card at phone width.
const MIN_ACCENT_DISTANCE: float = 0.35
## A lore line shorter than this is a stub, not an identity.
const MIN_LORE_LENGTH: int = 40

var fails: int = 0


func _check(what: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + what + ((" — " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var config: CharacterConfig = CharacterConfig.load_from_file()
	var ids: Array[String] = config.ids()
	_check("five characters load", ids.size() == 5, "got %d" % ids.size())

	_test_keys_complete_and_owned(config, ids)
	_test_text_resolves_in_both_locales(config, ids)
	_test_text_is_distinct(config, ids)
	_test_accents(config, ids)
	_test_art_paths(config, ids)
	_test_malformed_blocks_degrade()
	_test_ids_unchanged(ids)

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# Gate 1 + 2: every field present, and every key belongs to ITS OWN character.
func _test_keys_complete_and_owned(config: CharacterConfig, ids: Array[String]) -> void:
	for id: String in ids:
		var identity: Dictionary = config.identity_of(id)
		for field: String in KEY_FIELDS:
			var key: String = str(identity.get(field, ""))
			_check("%s.%s is set" % [id, field], not key.is_empty())
			if key.is_empty():
				continue
			var field_name: String = field.trim_suffix("_key")
			var expected: String = "character.%s.%s" % [id, field_name]
			_check("%s.%s names its own character" % [id, field], key == expected,
				"expected '%s', got '%s'" % [expected, key])


# Gate 1: every identity key resolves to non-empty text in vi AND en.
func _test_text_resolves_in_both_locales(config: CharacterConfig, ids: Array[String]) -> void:
	var csv: Dictionary = _parse_csv()
	_check("strings.csv parsed", csv.size() > 100, "%d keys" % csv.size())
	for id: String in ids:
		var identity: Dictionary = config.identity_of(id)
		for field: String in KEY_FIELDS:
			var key: String = str(identity.get(field, ""))
			if key.is_empty():
				continue
			_check("%s is in strings.csv" % key, csv.has(key))
			if not csv.has(key):
				continue
			for locale: String in LOCALES:
				var text: String = str((csv[key] as Dictionary).get(locale, ""))
				_check("%s has %s text" % [key, locale], not text.strip_edges().is_empty())


# Gate 4: no two characters share a lore / personality / playstyle line, and lore is not a stub.
func _test_text_is_distinct(config: CharacterConfig, ids: Array[String]) -> void:
	var csv: Dictionary = _parse_csv()
	for field: String in ["lore_key", "personality_key", "playstyle_key"]:
		for locale: String in LOCALES:
			var seen: Dictionary = {}
			for id: String in ids:
				var key: String = str(config.identity_of(id).get(field, ""))
				if not csv.has(key):
					continue
				var text: String = str((csv[key] as Dictionary).get(locale, "")).strip_edges()
				if text.is_empty():
					continue
				_check("%s %s %s is unique" % [id, field, locale], not seen.has(text),
					"same text as '%s'" % str(seen.get(text, "")))
				seen[text] = id
	for id: String in ids:
		var lore_key: String = str(config.identity_of(id).get("lore_key", ""))
		if not csv.has(lore_key):
			continue
		for locale: String in LOCALES:
			var lore: String = str((csv[lore_key] as Dictionary).get(locale, "")).strip_edges()
			_check("%s lore %s is more than a stub" % [id, locale], lore.length() >= MIN_LORE_LENGTH,
				"%d chars, want >= %d" % [lore.length(), MIN_LORE_LENGTH])


# Gate 3: accents parse, are unique, and are far enough apart to be told apart.
func _test_accents(config: CharacterConfig, ids: Array[String]) -> void:
	var accents: Dictionary = {}
	for id: String in ids:
		var raw: String = str(config.identity_of(id).get("accent_color", ""))
		_check("%s accent is a valid colour" % id, Color.html_is_valid(raw), raw)
		_check("%s accent is not the fallback" % id, raw.to_lower() != CharacterConfig.FALLBACK_ACCENT.to_lower(),
			"every character needs its own accent")
		accents[id] = Color(raw)
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: Color = accents[ids[i]]
			var b: Color = accents[ids[j]]
			var distance: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			_check("%s and %s accents are distinguishable" % [ids[i], ids[j]], distance >= MIN_ACCENT_DISTANCE,
				"distance %.2f, want >= %.2f" % [distance, MIN_ACCENT_DISTANCE])


# Gate 5: a path is "" (art not produced yet) or a file that exists. CharacterConfig clears danglers.
func _test_art_paths(config: CharacterConfig, ids: Array[String]) -> void:
	for id: String in ids:
		var identity: Dictionary = config.identity_of(id)
		for field: String in PATH_FIELDS:
			var path: String = str(identity.get(field, ""))
			var ok: bool = path.is_empty() or ResourceLoader.exists(path) or FileAccess.file_exists(path)
			_check("%s %s is empty or exists" % [id, field], ok, path)


# Gate 6: a bad block never crashes and never yields null or a partial dictionary.
func _test_malformed_blocks_degrade() -> void:
	var cases: Dictionary = {
		"absent": {"id": "t_absent", "name_key": "x", "max_hp": 100},
		"not an object": {"id": "t_scalar", "name_key": "x", "max_hp": 100, "identity": "nope"},
		"empty object": {"id": "t_empty", "name_key": "x", "max_hp": 100, "identity": {}},
		"bad colour": {"id": "t_colour", "name_key": "x", "max_hp": 100, "identity": {"accent_color": "not-a-colour"}},
		"dangling art": {"id": "t_art", "name_key": "x", "max_hp": 100, "identity": {"portrait": "res://assets/art/portraits/does_not_exist.png"}},
	}
	# Built by append_array, not `A + B`: concatenating two Array[String] constants yields an
	# untyped Array in GDScript, and assigning that to an Array[String] is a runtime error that
	# aborts this whole function (it silently skipped every gate below on the first run).
	var expected_fields: Array[String] = []
	expected_fields.append_array(KEY_FIELDS)
	expected_fields.append_array(PATH_FIELDS)
	expected_fields.append("accent_color")
	for label: String in cases:
		var entry: Dictionary = cases[label] as Dictionary
		var config: CharacterConfig = CharacterConfig.from_dictionary({"characters": [entry]})
		var id: String = str(entry["id"])
		_check("%s: character still loads" % label, config.has(id))
		var identity: Dictionary = config.identity_of(id)
		var complete: bool = true
		for field: String in expected_fields:
			if not identity.has(field):
				complete = false
		_check("%s: identity has every field" % label, complete, str(identity.keys()))
		_check("%s: accent falls back to a valid colour" % label,
			Color.html_is_valid(str(identity.get("accent_color", ""))), str(identity.get("accent_color", "")))
		if label == "bad colour":
			_check("bad colour: fallback accent used",
				str(identity["accent_color"]) == CharacterConfig.FALLBACK_ACCENT, str(identity["accent_color"]))
		if label == "dangling art":
			_check("dangling art: portrait cleared", str(identity["portrait"]).is_empty(), str(identity["portrait"]))
	# identity_of on an unknown id is the empty identity, not null and not a crash.
	var empty_config: CharacterConfig = CharacterConfig.from_dictionary({"characters": []})
	var unknown: Dictionary = empty_config.identity_of("no_such_character")
	_check("unknown id gives the empty identity", unknown.has("accent_color") and str(unknown["lore_key"]).is_empty())


# Saves key on the character id (run_session.gd drops a run with an unknown id; progress_state v8
# keys Pact level and runs_won on it). This gate exists so a later phase cannot quietly rename one.
func _test_ids_unchanged(ids: Array[String]) -> void:
	var expected: Array[String] = ["kiem_si", "phap_su", "sat_thu", "tho_san", "giao_si"]
	for id: String in expected:
		_check("character id '%s' still exists (saves key on it)" % id, ids.has(id))


func _parse_csv() -> Dictionary:
	var out: Dictionary = {}
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return out
	var header: PackedStringArray = file.get_csv_line()
	var columns: Dictionary = {}
	for index: int in header.size():
		columns[str(header[index]).strip_edges()] = index
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or str(row[0]).strip_edges().is_empty():
			continue
		var entry: Dictionary = {}
		for locale: String in LOCALES:
			var index: int = int(columns.get(locale, -1))
			entry[locale] = str(row[index]) if index >= 0 and index < row.size() else ""
		out[str(row[0]).strip_edges()] = entry
	file.close()
	return out

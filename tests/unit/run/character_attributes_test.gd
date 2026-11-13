extends SceneTree
## F2 of the character-system redesign (docs/design/character-system/CHARACTER-SYSTEM-REDESIGN.md,
## OD-2 approved 2026-11-13): the per-character base attributes load, clamp and degrade correctly,
## and — the point of this suite — the F2 schema change is PROVABLY a no-op for existing data.
##
## What it gates:
##  1. Back-compat. A pre-F2 character (flat `max_hp` / `step_cooldown_mult` / `focus_max_sec`, no
##     `attributes` block) loads with exactly the same numbers as before, and the two new
##     multipliers default to 1.0 — i.e. the shipped balance cannot move just by landing F2.
##  2. The `attributes` block is read, and wins over a flat key of the same name.
##  3. Multipliers clamp > 0; max_hp clamps >= 1; focus clamps >= 0; non-numeric falls back.
##  4. `get_character()` still carries the three legacy keys FLAT — 15+ suites read them that way,
##     so moving them into the block only would break them silently.
##  5. `formation_fade_mult` stays REJECTED (OD-2): if someone adds it to the data it must not
##     quietly become a live stat without the balance pass that decision demands.
##  6. The shipped roster's attributes are sane, and every character differs from every other in at
##     least one attribute (pillar 2: five characters must not be the same stat line).
##
## Headless, pure data (no scene). Prints PASS/FAIL lines and FAILS=n, exit code 1 on failure.
## Run: godot --headless -s res://tests/unit/run/character_attributes_test.gd

const LEGACY_FLAT_KEYS: Array[String] = ["max_hp", "step_cooldown_mult", "focus_max_sec"]
const NEW_KEYS: Array[String] = ["cast_speed_mult", "hazard_resist_mult"]

var fails: int = 0


func _check(what: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + what + ((" — " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _one(entry: Dictionary) -> CharacterConfig:
	return CharacterConfig.from_dictionary({"characters": [entry]})


func _initialize() -> void:
	_test_pre_f2_file_is_unchanged()
	_test_attributes_block_read_and_wins()
	_test_clamps_and_bad_values()
	_test_legacy_keys_stay_flat()
	_test_rejected_attribute_is_not_live()
	_test_shipped_roster()

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# Gate 1: the whole point of F2's schema being additive.
func _test_pre_f2_file_is_unchanged() -> void:
	var legacy: Dictionary = {
		"id": "t_legacy", "name_key": "x",
		"max_hp": 177.0, "step_cooldown_mult": 0.93, "focus_max_sec": 4.25,
	}
	var character: Dictionary = _one(legacy).get_character("t_legacy")
	_check("pre-F2: max_hp kept", is_equal_approx(float(character["max_hp"]), 177.0), str(character["max_hp"]))
	_check("pre-F2: step_cooldown_mult kept", is_equal_approx(float(character["step_cooldown_mult"]), 0.93), str(character["step_cooldown_mult"]))
	_check("pre-F2: focus_max_sec kept", is_equal_approx(float(character["focus_max_sec"]), 4.25), str(character["focus_max_sec"]))
	for key: String in NEW_KEYS:
		_check("pre-F2: %s defaults to 1.0 (balance cannot move)" % key,
			is_equal_approx(float(character[key]), 1.0), str(character[key]))


# Gate 2.
func _test_attributes_block_read_and_wins() -> void:
	var character: Dictionary = _one({
		"id": "t_block", "name_key": "x",
		"attributes": {"max_hp": 150.0, "cast_speed_mult": 0.8, "hazard_resist_mult": 1.25},
	}).get_character("t_block")
	_check("block: max_hp read", is_equal_approx(float(character["max_hp"]), 150.0), str(character["max_hp"]))
	_check("block: cast_speed_mult read", is_equal_approx(float(character["cast_speed_mult"]), 0.8), str(character["cast_speed_mult"]))
	_check("block: hazard_resist_mult read", is_equal_approx(float(character["hazard_resist_mult"]), 1.25), str(character["hazard_resist_mult"]))
	_check("block: an absent attribute still defaults", is_equal_approx(float(character["step_cooldown_mult"]), 1.0), str(character["step_cooldown_mult"]))
	# Both spellings present: the block wins, deterministically.
	var conflict: Dictionary = _one({
		"id": "t_conflict", "name_key": "x", "max_hp": 100.0, "attributes": {"max_hp": 250.0},
	}).get_character("t_conflict")
	_check("conflict: attributes wins over the flat key", is_equal_approx(float(conflict["max_hp"]), 250.0), str(conflict["max_hp"]))


# Gate 3.
func _test_clamps_and_bad_values() -> void:
	var cases: Array[Dictionary] = [
		{"label": "zero multiplier", "attrs": {"cast_speed_mult": 0.0}, "key": "cast_speed_mult", "want": 1.0},
		{"label": "negative multiplier", "attrs": {"hazard_resist_mult": -2.0}, "key": "hazard_resist_mult", "want": 1.0},
		{"label": "non-numeric multiplier", "attrs": {"cast_speed_mult": "fast"}, "key": "cast_speed_mult", "want": 1.0},
		{"label": "max_hp below 1", "attrs": {"max_hp": 0.0}, "key": "max_hp", "want": 1.0},
		{"label": "negative focus", "attrs": {"focus_max_sec": -3.0}, "key": "focus_max_sec", "want": 0.0},
		{"label": "zero step mult", "attrs": {"step_cooldown_mult": 0.0}, "key": "step_cooldown_mult", "want": 1.0},
	]
	for case: Dictionary in cases:
		var character: Dictionary = _one({
			"id": "t_clamp", "name_key": "x", "attributes": case["attrs"],
		}).get_character("t_clamp")
		_check("clamp: %s" % str(case["label"]),
			is_equal_approx(float(character[str(case["key"])]), float(case["want"])),
			"got %s, want %s" % [str(character[str(case["key"])]), str(case["want"])])
	# A malformed block as a whole must not lose the legacy flat values.
	var salvaged: Dictionary = _one({
		"id": "t_scalar", "name_key": "x", "max_hp": 123.0, "attributes": "nope",
	}).get_character("t_scalar")
	_check("clamp: a non-object attributes block falls back to the flat keys",
		is_equal_approx(float(salvaged["max_hp"]), 123.0), str(salvaged["max_hp"]))


# Gate 4: the shape 15+ existing suites depend on.
func _test_legacy_keys_stay_flat() -> void:
	var config: CharacterConfig = CharacterConfig.load_from_file()
	for id: String in config.ids():
		var character: Dictionary = config.get_character(id)
		for key: String in LEGACY_FLAT_KEYS:
			_check("%s: legacy key '%s' is still flat" % [id, key], character.has(key))
		for key: String in NEW_KEYS:
			_check("%s: new key '%s' is flat too" % [id, key], character.has(key))
		_check("%s: attributes_of() agrees with the flat keys" % id,
			is_equal_approx(float(config.attributes_of(id).get("max_hp", -1.0)), float(character["max_hp"])))


# Gate 5: OD-2 rejected formation_fade_mult. Adding it to the data must stay inert.
func _test_rejected_attribute_is_not_live() -> void:
	var character: Dictionary = _one({
		"id": "t_rejected", "name_key": "x", "attributes": {"formation_fade_mult": 3.0},
	}).get_character("t_rejected")
	_check("OD-2: formation_fade_mult is not a live attribute", not character.has("formation_fade_mult"),
		"it was rejected pending its own balance pass; adding it needs a decision, not a data edit")


# Gate 6: five characters must not be one stat line.
func _test_shipped_roster() -> void:
	var config: CharacterConfig = CharacterConfig.load_from_file()
	var ids: Array[String] = config.ids()
	_check("roster: five characters", ids.size() == 5, "got %d" % ids.size())
	for id: String in ids:
		var attributes: Dictionary = config.attributes_of(id)
		_check("%s: max_hp is sane" % id, float(attributes["max_hp"]) >= 50.0 and float(attributes["max_hp"]) <= 400.0, str(attributes["max_hp"]))
		for key: String in ["step_cooldown_mult", "cast_speed_mult", "hazard_resist_mult"]:
			var value: float = float(attributes[key])
			_check("%s: %s within 0.5..2.0" % [id, key], value >= 0.5 and value <= 2.0, str(value))
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: Dictionary = config.attributes_of(ids[i])
			var b: Dictionary = config.attributes_of(ids[j])
			var differs: bool = false
			for key: String in a:
				if not is_equal_approx(float(a[key]), float(b[key])):
					differs = true
			_check("%s and %s differ in at least one attribute" % [ids[i], ids[j]], differs,
				"identical stat lines make two characters the same in pillar 2")

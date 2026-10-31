extends SceneTree
## Story 044 Part B: SettingsStore (controls.movement, show_control_hints). Every file access goes
## through a temp path under user://, never the real user://settings.json; the static override is
## reset around each case.

var fails: int = 0

const TEMP_PATH: String = "user://settings_store_test_tmp.json"


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _clean() -> void:
	SettingsStore.reset_shared()
	SettingsStore.set_movement_override("")
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _initialize() -> void:
	test_default_is_joystick_without_a_file()
	test_default_hints_are_off()
	test_cli_arg_parses_pad_and_joystick()
	test_cli_arg_unknown_value_is_ignored()
	test_override_beats_the_stored_value()
	test_round_trip_through_a_temp_path()
	test_unknown_or_malformed_file_falls_back_to_joystick()
	test_toggle_flips_and_saves()
	test_set_with_override_does_not_write_the_file()
	test_invalid_set_is_ignored()
	test_hints_round_trip()
	_clean()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_default_is_joystick_without_a_file() -> void:
	_clean()
	var store := SettingsStore.new(TEMP_PATH)
	_check("missing file -> joystick", store.get_movement() == SettingsStore.MOVEMENT_JOYSTICK and not store.is_pad())


func test_default_hints_are_off() -> void:
	_clean()
	_check("show_control_hints defaults to false", not SettingsStore.new(TEMP_PATH).get_show_control_hints())


func test_cli_arg_parses_pad_and_joystick() -> void:
	_check("--movement=pad", SettingsStore.parse_movement_arg(PackedStringArray(["--no-autopause", "--movement=pad"])) == "pad")
	_check("--movement=joystick", SettingsStore.parse_movement_arg(PackedStringArray(["--movement=joystick"])) == "joystick")
	_check("absent -> empty", SettingsStore.parse_movement_arg(PackedStringArray(["--arena=ring"])) == "")
	_check("last valid one wins", SettingsStore.parse_movement_arg(PackedStringArray(["--movement=pad", "--movement=joystick"])) == "joystick")


func test_cli_arg_unknown_value_is_ignored() -> void:
	_check("--movement=gyro -> empty", SettingsStore.parse_movement_arg(PackedStringArray(["--movement=gyro"])) == "")


func test_override_beats_the_stored_value() -> void:
	_clean()
	var store := SettingsStore.new(TEMP_PATH)
	SettingsStore.set_movement_override(SettingsStore.MOVEMENT_PAD)
	_check("override pad over default joystick", store.is_pad())
	SettingsStore.set_movement_override("")
	_check("cleared override returns to stored", not store.is_pad())
	SettingsStore.set_movement_override("bogus")
	_check("invalid override is ignored", not store.is_pad() and SettingsStore.get_movement_override() == "")


func test_round_trip_through_a_temp_path() -> void:
	_clean()
	var store := SettingsStore.new(TEMP_PATH)
	store.set_movement(SettingsStore.MOVEMENT_PAD)
	_check("file written", FileAccess.file_exists(TEMP_PATH))
	var again := SettingsStore.new(TEMP_PATH)
	_check("a new instance reads pad back", again.get_movement() == SettingsStore.MOVEMENT_PAD)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_PATH))
	_check("file has controls.movement", parsed is Dictionary and (parsed as Dictionary).get("controls", {}).get("movement", "") == "pad")


func test_unknown_or_malformed_file_falls_back_to_joystick() -> void:
	_clean()
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string('{"controls": {"movement": "gyro"}}')
	file.close()
	_check("unknown value -> joystick", SettingsStore.new(TEMP_PATH).get_movement() == "joystick")
	file = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string("not json at all {")
	file.close()
	_check("malformed file -> joystick", SettingsStore.new(TEMP_PATH).get_movement() == "joystick")
	file = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string('{"controls": 5}')
	file.close()
	_check("wrong shape -> joystick", SettingsStore.new(TEMP_PATH).get_movement() == "joystick")


func test_toggle_flips_and_saves() -> void:
	_clean()
	var store := SettingsStore.new(TEMP_PATH)
	_check("toggle joystick -> pad", store.toggle_movement() == "pad")
	_check("saved as pad", SettingsStore.new(TEMP_PATH).is_pad())
	_check("toggle pad -> joystick", store.toggle_movement() == "joystick")
	_check("saved as joystick", not SettingsStore.new(TEMP_PATH).is_pad())


func test_set_with_override_does_not_write_the_file() -> void:
	_clean()
	SettingsStore.set_movement_override(SettingsStore.MOVEMENT_PAD)
	var store := SettingsStore.new(TEMP_PATH)
	_check("toggle under override flips the override", store.toggle_movement() == "joystick")
	_check("no file was written", not FileAccess.file_exists(TEMP_PATH))
	_clean()


func test_invalid_set_is_ignored() -> void:
	_clean()
	var store := SettingsStore.new(TEMP_PATH)
	store.set_movement("gyro")
	_check("invalid set keeps joystick and writes nothing", store.get_movement() == "joystick" and not FileAccess.file_exists(TEMP_PATH))


func test_hints_round_trip() -> void:
	_clean()
	var store := SettingsStore.new(TEMP_PATH)
	store.set_show_control_hints(true)
	_check("hints persisted", SettingsStore.new(TEMP_PATH).get_show_control_hints())
	_check("movement default kept", SettingsStore.new(TEMP_PATH).get_movement() == "joystick")

extends SceneTree
## Story 044 Part B: SettingsStore (show_control_hints); Story 047 Part D: reduce_motion. Every file access goes
## through a temp path under user://, never the real user://settings.json. 2026-11-01: the pad movement mode was
## removed (joystick only); an old controls.movement value in the file must still load and is dropped on save.

var fails: int = 0

const TEMP_PATH: String = "user://settings_store_test_tmp.json"


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _clean() -> void:
	SettingsStore.reset_shared()
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _initialize() -> void:
	test_default_hints_are_off()
	test_old_pad_file_still_loads()
	test_malformed_file_falls_back_to_defaults()
	test_hints_round_trip()
	test_reduce_motion_defaults_off()
	test_reduce_motion_round_trip()
	_clean()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_default_hints_are_off() -> void:
	_clean()
	_check("show_control_hints defaults to false", not SettingsStore.new(TEMP_PATH).get_show_control_hints())


func test_old_pad_file_still_loads() -> void:
	_clean()
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string('{"controls": {"movement": "pad"}, "show_control_hints": true, "card_time": "long"}')
	file.close()
	var store := SettingsStore.new(TEMP_PATH)
	_check("an old pad file parses", store.load_file())
	_check("its other values are kept", store.get_show_control_hints() and store.get_card_time() == SettingsStore.CARD_TIME_LONG)
	_check("the store has no movement API any more", not store.has_method("is_pad") and not store.has_method("set_movement"))
	store.set_reduce_motion(true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_PATH))
	_check("the next save drops controls.movement", parsed is Dictionary and not (parsed as Dictionary).has("controls"))


func test_malformed_file_falls_back_to_defaults() -> void:
	_clean()
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string("not json at all {")
	file.close()
	var store := SettingsStore.new(TEMP_PATH)
	_check("malformed file -> defaults", not store.get_show_control_hints() and not store.get_reduce_motion() and store.get_card_time() == SettingsStore.CARD_TIME_NORMAL)
	file = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string('{"controls": 5}')
	file.close()
	_check("wrong shape -> defaults", not SettingsStore.new(TEMP_PATH).get_show_control_hints())


func test_hints_round_trip() -> void:
	_clean()
	var store := SettingsStore.new(TEMP_PATH)
	store.set_show_control_hints(true)
	_check("hints persisted", SettingsStore.new(TEMP_PATH).get_show_control_hints())
	_check("reduce motion default kept", not SettingsStore.new(TEMP_PATH).get_reduce_motion())


func test_reduce_motion_defaults_off() -> void:
	_clean()
	_check("reduce_motion defaults to false", not SettingsStore.new(TEMP_PATH).get_reduce_motion())
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string('{"reduce_motion": "yes"}')
	file.close()
	_check("non-bool reduce_motion -> false", not SettingsStore.new(TEMP_PATH).get_reduce_motion())


func test_reduce_motion_round_trip() -> void:
	_clean()
	var store := SettingsStore.new(TEMP_PATH)
	store.set_reduce_motion(true)
	_check("reduce_motion persisted", SettingsStore.new(TEMP_PATH).get_reduce_motion())
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_PATH))
	_check("file has reduce_motion true", parsed is Dictionary and (parsed as Dictionary).get("reduce_motion", false) == true)
	_check("hints default kept", not SettingsStore.new(TEMP_PATH).get_show_control_hints())
	store.set_reduce_motion(false)
	_check("reduce_motion off again persisted", not SettingsStore.new(TEMP_PATH).get_reduce_motion())

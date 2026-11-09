extends SceneTree
## Audio settings (docs/skill-v2/10-audio-system-design.md §9, decision A3; §11 settings_audio_test): five volumes
## default 80 %, Reduced audio off, vibration on; values round-trip through the file; clamping and cycling; an old file
## without "audio" loads the defaults; audio_changed fires; the settings screen's audio column. Files go only to a temp
## path under user:// (never the real user://settings.json); the screen test uses a memory store.
## Run: godot --headless --path . -s res://tests/unit/audio/settings_audio_test.gd

const TEMP_PATH: String = "user://settings_audio_test_tmp.json"
const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1024, 768)]

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _clean() -> void:
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _initialize() -> void:
	var real_before: String = FileAccess.get_file_as_string(SettingsStore.DEFAULT_PATH)
	var real_existed: bool = FileAccess.file_exists(SettingsStore.DEFAULT_PATH)
	test_defaults()
	test_round_trip()
	test_clamp_cycle_and_unknown_bus()
	test_old_file_without_audio()
	test_signal()
	test_settings_view_layout()
	_clean()
	ck("the real user://settings.json was not touched", FileAccess.file_exists(SettingsStore.DEFAULT_PATH) == real_existed
		and FileAccess.get_file_as_string(SettingsStore.DEFAULT_PATH) == real_before)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_defaults() -> void:
	_clean()
	var s := SettingsStore.new(TEMP_PATH)
	var all80: bool = true
	for bus: String in SettingsStore.VOLUME_BUSES:
		all80 = all80 and s.get_volume(bus) == 80
	ck("five volumes default to 80 %", all80 and SettingsStore.VOLUME_BUSES == ["Master", "Music", "SFX", "UI", "Ambience"])
	ck("reduced audio off, vibration on by default", not s.get_reduced_audio() and s.get_vibration())


func test_round_trip() -> void:
	_clean()
	var s := SettingsStore.new(TEMP_PATH)
	s.set_volume("Music", 30)
	s.set_volume("Ambience", 0)
	s.set_reduced_audio(true)
	s.set_vibration(false)
	var again := SettingsStore.new(TEMP_PATH)
	ck("volumes, reduced audio and vibration survive a reload", again.get_volume("Music") == 30 and again.get_volume("Ambience") == 0
		and again.get_volume("SFX") == 80 and again.get_reduced_audio() and not again.get_vibration())
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_PATH))
	ck("the file has an audio object with all five volumes", parsed is Dictionary and (parsed["audio"]["volumes"] as Dictionary).size() == 5)
	ck("other settings are kept beside it", (parsed as Dictionary).has("reduce_motion") and (parsed as Dictionary).has("last_slot"))


func test_clamp_cycle_and_unknown_bus() -> void:
	var s := SettingsStore.memory()
	s.set_volume("SFX", 150)
	ck("a volume clamps to 100", s.get_volume("SFX") == 100)
	ck("cycling from 100 wraps to 0", s.cycle_volume("SFX") == 0)
	ck("then steps by 10", s.cycle_volume("SFX") == 10)
	s.set_volume("Warning", 10)
	ck("an unknown bus is ignored (Warning has no player volume)", s.get_volume("Warning") == 0)


func test_old_file_without_audio() -> void:
	_clean()
	var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	f.store_string('{"show_control_hints": true, "audio": {"volumes": {"Music": "loud", "UI": 55}, "vibration": "yes"}}')
	f.close()
	var s := SettingsStore.new(TEMP_PATH)
	ck("bad values fall back, good ones load", s.get_volume("Music") == 80 and s.get_volume("UI") == 55 and s.get_vibration()
		and s.get_show_control_hints())
	_clean()
	f = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	f.store_string('{"reduce_motion": true}')
	f.close()
	var old := SettingsStore.new(TEMP_PATH)
	ck("a pre-audio file loads audio defaults", old.get_volume("Master") == 80 and not old.get_reduced_audio() and old.get_reduce_motion())


func test_signal() -> void:
	var s := SettingsStore.memory()
	var count: Array[int] = [0]
	s.audio_changed.connect(func() -> void: count[0] += 1)
	s.set_volume("UI", 40)
	s.set_reduced_audio(true)
	s.set_vibration(false)
	s.set_show_control_hints(true)
	ck("audio_changed fires on the three audio setters only", count[0] == 3, str(count[0]))


func test_settings_view_layout() -> void:
	ck("the audio column lists the five volumes, reduced audio and vibration",
		SettingsView.AUDIO_ROWS == ["vol_Master", "vol_Music", "vol_SFX", "vol_UI", "vol_Ambience", "reduced_audio", "vibration"])
	for vp: Vector2 in VIEWPORTS:
		var tag: String = "%dx%d" % [int(vp.x), int(vp.y)]
		var rows: Array[Rect2] = SettingsView.audio_row_rects(vp)
		var left: Array[Rect2] = SettingsView.row_rects(vp)
		var ok: bool = rows.size() == 7
		for i: int in rows.size():
			ok = ok and rows[i].size.y >= 64.0 * SettingsView.unit(vp) - 0.5 and rows[i].end.y <= vp.y and rows[i].end.x <= vp.x
			ok = ok and rows[i].encloses(SettingsView.value_rect(rows[i], vp))
			if i > 0:
				ok = ok and not rows[i].intersects(rows[i - 1])
			for t: Rect2 in SettingsView.tab_rects(vp):
				ok = ok and not rows[i].intersects(t)
		ck("%s: audio rows thumb-sized, apart, on screen, clear of the tab rail" % tag, ok)
		var tabs: Array[Rect2] = SettingsView.tab_rects(vp)
		var tabs_ok: bool = tabs.size() == 2 and not tabs[0].intersects(tabs[1]) and not tabs[-1].intersects(SettingsView.back_rect(vp))
		for t: Rect2 in tabs:
			tabs_ok = tabs_ok and t.size.y >= 64.0 * SettingsView.unit(vp) - 0.5 and t.end.x <= vp.x * 0.3
			for l: Rect2 in left:
				tabs_ok = tabs_ok and not t.intersects(l)
		ck("%s: two touch-sized tabs in a left rail, clear of the rows and Back" % tag, tabs_ok)
		ck("%s: Back clear of the audio rows" % tag, not SettingsView.back_rect(vp).intersects(rows[-1]))
	var view := SettingsView.new()
	ck("one tab per settings group: General then Audio, General first", SettingsView.TABS == ["general", "audio"] and view.get_tab() == "general")
	view.set_tab("audio")
	view.set_tab("nope")
	ck("set_tab selects a known tab and ignores an unknown one", view.get_tab() == "audio")
	var store := SettingsStore.memory()
	view.audio_settings = store
	view.toggle_audio("vol_Music", 1)
	ck("tapping a volume row raises it by 10", store.get_volume("Music") == 90)
	view.toggle_audio("vol_Music", -1)
	view.toggle_audio("vol_Music", -1)
	ck("the left half lowers it by 10", store.get_volume("Music") == 70)
	view.toggle_audio("reduced_audio")
	view.toggle_audio("vibration")
	ck("the toggles flip", store.get_reduced_audio() and not store.get_vibration())
	ck("the value text shows the percent", view.audio_value_text("vol_Music").contains("70"))
	view.free()

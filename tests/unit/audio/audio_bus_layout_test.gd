extends SceneTree
## Audio buses (docs/skill-v2/10-audio-system-design.md §9, decision A2): default_bus_layout.tres gives Master (hard
## limiter -1 dB) <- Music, Ambience, SFX (<- Skill, Combat), UI, Warning; Music and SFX carry a compressor
## side-chained to Warning (the ducking); Warning has no effect (never ducked); every bus the bank names exists.
## Run: godot --headless --path . -s res://tests/unit/audio/audio_bus_layout_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_layout_file_is_the_project_default()
	test_bus_tree()
	test_limiter_and_ducking()
	test_bank_buses_exist()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _send(bus: String) -> String:
	return str(AudioServer.get_bus_send(AudioServer.get_bus_index(StringName(bus))))


func _effects(bus: String) -> Array:
	var idx: int = AudioServer.get_bus_index(StringName(bus))
	var out: Array = []
	for i: int in AudioServer.get_bus_effect_count(idx):
		out.append(AudioServer.get_bus_effect(idx, i))
	return out


func test_layout_file_is_the_project_default() -> void:
	var path: String = str(ProjectSettings.get_setting("audio/buses/default_bus_layout", "res://default_bus_layout.tres"))
	ck("the project loads res://default_bus_layout.tres", path == "res://default_bus_layout.tres" and ResourceLoader.exists(path), path)
	ck("the layout resource is an AudioBusLayout", load(path) is AudioBusLayout)


func test_bus_tree() -> void:
	ck("8 buses", AudioServer.bus_count == 8, str(AudioServer.bus_count))
	for bus: String in ["Music", "Ambience", "SFX", "UI", "Warning"]:
		ck("%s sends to Master" % bus, _send(bus) == "Master", _send(bus))
	for bus: String in ["Skill", "Combat"]:
		ck("%s sends to SFX" % bus, _send(bus) == "SFX", _send(bus))
	ck("Master is bus 0", AudioServer.get_bus_name(0) == "Master")


func test_limiter_and_ducking() -> void:
	var master: Array = _effects("Master")
	ck("Master has a hard limiter at -1 dB", master.size() == 1 and master[0] is AudioEffectHardLimiter
		and is_equal_approx((master[0] as AudioEffectHardLimiter).ceiling_db, -1.0))
	for bus: String in ["Music", "SFX"]:
		var fx: Array = _effects(bus)
		ck("%s ducks: a compressor side-chained to Warning" % bus, fx.size() == 1 and fx[0] is AudioEffectCompressor
			and str((fx[0] as AudioEffectCompressor).sidechain) == "Warning")
	ck("Warning is never ducked (no effect on it)", _effects("Warning").is_empty())
	ck("Warning is processed before the ducked buses (higher index)",
		AudioServer.get_bus_index(&"Warning") > AudioServer.get_bus_index(&"SFX")
		and AudioServer.get_bus_index(&"Warning") > AudioServer.get_bus_index(&"Music"))


func test_bank_buses_exist() -> void:
	var bank: AudioBank = AudioBank.load_from_file()
	var missing: Array[String] = []
	for bus: String in bank.bus_names():
		if AudioServer.get_bus_index(StringName(bus)) < 0:
			missing.append(bus)
	ck("every bus named in audio_events.json exists", missing.is_empty() and bank.bus_names().size() == 8, str(missing))

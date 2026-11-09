extends SceneTree
## AudioDirector (docs/skill-v2/10-audio-system-design.md §4, §6, §9, §11 audio_pause_test): arbiter-time cues start at
## `at - lead` on the arbiter clock and wait while it stands still; local delays follow unpaused match time; tags stop
## and cancel; pause holds combat cues and voices (UI keeps playing); background drops new sounds; reduced audio drops
## reducible events only; Critical ducks and logs a vibration; the latency lead is clamped to 80 ms; a real (non-silent)
## director pre-creates its players and sets bus volumes from the settings.
## Run: godot --headless --path . -s res://tests/unit/audio/audio_director_test.gd

var fails: int = 0
var clock: float = 0.0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_arbiter_cue_starts_at_at_minus_lead()
	test_arbiter_cue_waits_for_the_clock()
	test_local_delay_and_cancel()
	test_stop_tag_and_cancel_all()
	test_pause_and_background()
	test_reduced_audio()
	test_critical_ducks_and_vibrates()
	test_lead_clamp()


# The real director needs the scene tree running (players play only inside it): first frame.
var _frame: int = 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		test_real_director_players_and_volumes()
	elif _frame == 4:
		# A few frames after the real director is freed, so the audio server lets go of its streams.
		print("FAILS=%d" % fails)
		quit(1 if fails > 0 else 0)
	return false


func _director() -> AudioDirector:
	var d := AudioDirector.silent()
	clock = 0.0
	d.clock_fn = func() -> float: return clock
	d.lead_override = 0.03
	return d


func _plays(d: AudioDirector, id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in d.play_log:
		if e["op"] == "play" and e["id"] == id:
			out.append(e)
	return out


func _step(d: AudioDirector, dt: float, n: int) -> void:
	for i: int in n:
		clock += dt
		d.advance(dt)


func test_arbiter_cue_starts_at_at_minus_lead() -> void:
	var d := _director()
	d.apply([{"op": "at", "id": "skill.tram_dia.impact_final", "at": 0.5, "cells": 1, "step": 0, "tag": "cast:1"}])
	ck("nothing plays before at - lead", _plays(d, "skill.tram_dia.impact_final").is_empty() and d.pending().size() == 1)
	_step(d, 0.005, 200)
	var p: Array[Dictionary] = _plays(d, "skill.tram_dia.impact_final")
	ck("plays once", p.size() == 1)
	ck("started at the first clock >= at - lead (0.47), before the impact", p.size() == 1 and float(p[0]["clock"]) >= 0.47 - 0.000001
		and float(p[0]["clock"]) < 0.47 + 0.005 + 0.000001 and float(p[0]["clock"]) < 0.5, str(p[0]["clock"]) if p.size() > 0 else "")
	d.free()


func test_arbiter_cue_waits_for_the_clock() -> void:
	var d := _director()
	d.apply([{"op": "at", "id": "skill.generic.hit", "at": 0.2, "cells": 1, "step": 0, "tag": ""}])
	for i: int in 100:
		d.advance(0.01)
	ck("a frozen arbiter clock (card menu, pause) holds the cue", _plays(d, "skill.generic.hit").is_empty())
	d.clock_fn = Callable()
	_step(d, 0.01, 50)
	ck("no clock (no battle) holds the cue too", _plays(d, "skill.generic.hit").is_empty())
	d.free()


func test_local_delay_and_cancel() -> void:
	var d := _director()
	d.apply([{"op": "after", "id": "warn.boss.imminent", "delay": 0.7, "cells": 1, "step": 0, "tag": "warn:slam"},
		{"op": "after", "id": "warn.boss.windup", "delay": 0.2, "cells": 1, "step": 0, "tag": "warn:other"}])
	_step(d, 0.1, 3)
	ck("the 0.2 s cue played, the 0.7 s one waits", _plays(d, "warn.boss.windup").size() == 1 and _plays(d, "warn.boss.imminent").is_empty())
	d.apply([{"op": "cancel", "tag": "warn:slam"}])
	_step(d, 0.1, 10)
	ck("a cancelled pending cue never plays", _plays(d, "warn.boss.imminent").is_empty() and d.pending().is_empty())
	var d2 := _director()
	d2.local_scale_fn = func() -> float: return 0.25
	d2.apply([{"op": "after", "id": "ui.tap", "delay": 0.1, "cells": 1, "step": 0, "tag": ""}])
	_step(d2, 0.1, 3)
	ck("local delays follow the match time scale (x0.25: not yet after 0.3 s real)", _plays(d2, "ui.tap").is_empty())
	_step(d2, 0.1, 2)
	ck("... and play after 0.4 s real", _plays(d2, "ui.tap").size() == 1)
	d.free()
	d2.free()


func test_stop_tag_and_cancel_all() -> void:
	var d := _director()
	d.apply([{"op": "play", "id": "skill.ngan_kiem.channel_loop", "cells": 1, "step": 0, "tag": "channel:0"}])
	ck("the loop voice is live", d.get_pool().voices().any(func(v: Dictionary) -> bool: return v["tag"] == "channel:0" and v["loop"]))
	_step(d, 0.5, 10)
	ck("a loop outlives its file length", d.get_pool().active_count("Skill") == 1)
	d.apply([{"op": "stop", "tag": "channel:0"}])
	ck("stop ends it", d.get_pool().active_count("Skill") == 0)
	d.apply([{"op": "at", "id": "skill.generic.hit", "at": 9.0, "cells": 1, "step": 0, "tag": "cast:3"},
		{"op": "play", "id": "skill.generic.windup", "cells": 1, "step": 0, "tag": ""}])
	d.apply(AudioEventRules.on_match_ended(true))
	ck("match end: pending dropped, combat voices stopped, stinger plays on Music", d.pending().is_empty()
		and d.get_pool().active_count("Skill") == 0 and _plays(d, "flow.victory").size() == 1)
	d.free()


func test_pause_and_background() -> void:
	var d := _director()
	d.apply([{"op": "after", "id": "warn.boss.imminent", "delay": 0.2, "cells": 1, "step": 0, "tag": "w"},
		{"op": "at", "id": "skill.generic.hit", "at": 0.1, "cells": 1, "step": 0, "tag": ""}])
	d.set_paused(true)
	_step(d, 0.1, 10)
	ck("paused: local and arbiter cues wait", d.pending().size() == 2 and d.is_paused())
	ck("paused: UI still answers", d.play("ui.tap") != VoicePool.NO_VOICE)
	d.set_paused(false)
	_step(d, 0.1, 3)
	ck("resumed: both play", _plays(d, "warn.boss.imminent").size() == 1 and _plays(d, "skill.generic.hit").size() == 1)
	d.set_background(true)
	ck("backgrounded: nothing new starts", d.play("ui.back") == VoicePool.NO_VOICE)
	d.set_background(false)
	ck("foreground again: plays", d.play("ui.back") != VoicePool.NO_VOICE)
	d.free()


func test_reduced_audio() -> void:
	var d := _director()
	d.reduced_audio = true
	ck("reduced: an aftermath is dropped", d.play("skill.tram_dia.aftermath") == VoicePool.NO_VOICE)
	ck("reduced: the skill-ready tone is dropped", d.play("card.ready") == VoicePool.NO_VOICE)
	ck("reduced: warnings stay", d.play("warn.boss.imminent") != VoicePool.NO_VOICE)
	ck("reduced: impacts stay", d.play("skill.tram_dia.impact_final") != VoicePool.NO_VOICE)
	d.free()


func test_critical_ducks_and_vibrates() -> void:
	var d := _director()
	d.play("warn.boss.imminent")
	ck("a Critical cue starts a 0.4 s duck", is_equal_approx(d.duck_left(), 0.4))
	ck("and logs a vibration", d.play_log.any(func(e: Dictionary) -> bool: return e["op"] == "vibrate"))
	d.advance(0.5)
	ck("the duck ends", d.duck_left() == 0.0)
	var d2 := _director()
	d2.vibration_enabled = false
	d2.play("warn.boss.imminent")
	ck("vibration off: no vibration", not d2.play_log.any(func(e: Dictionary) -> bool: return e["op"] == "vibrate"))
	d.free()
	d2.free()


func test_lead_clamp() -> void:
	var d := _director()
	d.lead_override = 0.5
	ck("lead clamped to 80 ms", is_equal_approx(d.lead_sec(), 0.08))
	d.lead_override = -1.0
	ck("silent director: auto lead is 0 (no AudioServer)", d.lead_sec() == 0.0)
	d.free()


func test_real_director_players_and_volumes() -> void:
	var d := AudioDirector.new(null, false)
	root.add_child(d)
	var h: int = d.play("ui.tap")
	var players: int = d.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer).size()
	ck("a real director pre-creates 24 players on first play", players == 24 and h != VoicePool.NO_VOICE, str(players))
	var store := SettingsStore.memory()
	store.set_volume("Music", 50)
	store.set_volume("UI", 0)
	d.apply_settings(store)
	ck("Music 50 % = -6 dB on the Music bus", absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) - (-6.02)) < 0.05)
	ck("UI 0 % mutes the UI bus", AudioServer.is_bus_mute(AudioServer.get_bus_index(&"UI")))
	ck("Master stays at its 80 % default", absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.8)) < 0.01)
	ck("Warning keeps 0 dB (no player volume, never ducked by settings)", AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Warning")) == 0.0)
	d.play("warn.boss.imminent")
	ck("during the duck the Skill bus is 6 dB down and Warning untouched",
		absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Skill")) - (-6.0)) < 0.01
		and AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Warning")) == 0.0)
	d.advance(0.5)
	ck("after the duck Skill is back to 0 dB", absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Skill"))) < 0.01)
	d.stop_buses()
	for p: Node in d.get_children():
		(p as AudioStreamPlayer).stream = null
	d.free()

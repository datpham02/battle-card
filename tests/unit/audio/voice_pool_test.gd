extends SceneTree
## VoicePool (docs/skill-v2/10-audio-system-design.md §6, §9, §11 voice_pool_test), on a fake clock: per-bus caps;
## Critical never culled; Low stolen first; per-event cap steals the oldest; same-event cooldown merges, and 5 same-tick
## one-cell impacts become ONE voice at tier L; Warning voices reserved under the total cap; expiry and tags.
## Run: godot --headless --path . -s res://tests/unit/audio/voice_pool_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_bus_cap_steals_low_first()
	test_critical_never_culled()
	test_equal_or_higher_priority_is_not_stolen_by_lower()
	test_per_event_cap_steals_oldest()
	test_cooldown_merges_into_a_tiered_voice()
	test_cooldown_drop_after_the_voice_ended()
	test_total_cap_keeps_warning_reserve()
	test_expiry_loops_and_tags()
	test_unknown_event_dropped()
	test_real_bank_five_hoa_loi_cells()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _bank(total: int = 24) -> AudioBank:
	return AudioBank.new({
		"buses": ["Master", "Skill", "UI", "Warning"], "priorities": {"low": 0, "normal": 1, "high": 2, "critical": 3},
		"voice_caps": {"total": total, "Skill": 3, "UI": 2, "Warning": 2}, "reserved_voices": {"Warning": 2},
		"defaults": {"cooldown_ms": 0, "max_voices": 0},
		"size_tiers": {"S": 1, "M": 3, "L": 5},
		"events": {
			"low": {"bus": "Skill", "priority": "low", "files": ["x"]},
			"low2": {"bus": "Skill", "priority": "low", "files": ["x"]},
			"normal": {"bus": "Skill", "priority": "normal", "files": ["x"]},
			"normal2": {"bus": "Skill", "priority": "normal", "files": ["x"]},
			"high": {"bus": "Skill", "priority": "high", "files": ["x"]},
			"crit": {"bus": "Warning", "priority": "critical", "files": ["x"]},
			"crit_skill": {"bus": "Skill", "priority": "critical", "files": ["x"]},
			"capped": {"bus": "UI", "priority": "normal", "files": ["x"], "max_voices": 1},
			"impact": {"bus": "Skill", "priority": "high", "files": ["x"], "cooldown_ms": 40},
			"loop": {"bus": "UI", "priority": "low", "files": ["x"], "loop": true},
		}})


func _ids(p: VoicePool) -> Array:
	return p.voices().map(func(v: Dictionary) -> String: return v["id"])


func test_bus_cap_steals_low_first() -> void:
	var p := VoicePool.new(_bank())
	p.request("normal", 0.0, 5.0)
	p.request("low", 0.1, 5.0)
	p.request("normal2", 0.2, 5.0)
	var r: Dictionary = p.request("high", 0.3, 5.0)
	ck("a 4th Skill voice over the cap of 3 plays", r["action"] == "play" and p.active_count("Skill") == 3)
	ck("the Low voice was stolen, not the older Normal", not _ids(p).has("low") and _ids(p).has("normal") and (r["stolen"] as Array).size() == 1)


func test_critical_never_culled() -> void:
	var p := VoicePool.new(_bank())
	p.request("crit_skill", 0.0, 5.0)
	p.request("crit_skill", 0.1, 5.0)
	p.request("crit_skill", 0.2, 5.0)
	var r: Dictionary = p.request("high", 0.3, 5.0)
	ck("High cannot steal Critical: dropped", r["action"] == "drop" and r["reason"] == "bus_cap" and p.active_count("Skill") == 3)
	var r2: Dictionary = p.request("crit_skill", 0.4, 5.0)
	ck("even Critical does not steal Critical (drop, the playing warning wins)", r2["action"] == "drop")


func test_equal_or_higher_priority_is_not_stolen_by_lower() -> void:
	var p := VoicePool.new(_bank())
	p.request("high", 0.0, 5.0)
	p.request("high", 0.1, 5.0)
	p.request("normal", 0.2, 5.0)
	var r: Dictionary = p.request("low", 0.3, 5.0)
	ck("Low finds nothing to steal (all higher): dropped", r["action"] == "drop" and _ids(p).count("high") == 2)
	var r2: Dictionary = p.request("normal2", 0.4, 5.0)
	ck("Normal steals the equal-priority oldest Normal, never a High", r2["action"] == "play" and _ids(p).count("high") == 2
		and not _ids(p).has("normal") and _ids(p).has("normal2"))


func test_per_event_cap_steals_oldest() -> void:
	var p := VoicePool.new(_bank())
	var a: Dictionary = p.request("capped", 0.0, 5.0)
	var b: Dictionary = p.request("capped", 0.5, 5.0)
	ck("max_voices 1: the second steals the first", b["action"] == "play" and (b["stolen"] as Array) == [a["handle"]]
		and p.active_count("UI") == 1)


func test_cooldown_merges_into_a_tiered_voice() -> void:
	var p := VoicePool.new(_bank())
	var first: Dictionary = p.request("impact", 1.0, 0.5, {"cells": 1})
	var merged: Array = []
	for i: int in 4:
		merged.append(p.request("impact", 1.0, 0.5, {"cells": 1}))
	ck("5 same-tick one-cell impacts = 1 voice", p.active_count() == 1 and first["action"] == "play")
	ck("the repeats merged into the first voice", merged.all(func(r: Dictionary) -> bool: return r["action"] == "merge" and r["handle"] == first["handle"]))
	ck("its tier rose S -> M -> L with the merged cells", first["tier"] == "S" and (merged[1] as Dictionary)["tier"] == "M"
		and (merged[1] as Dictionary)["retier"] and (merged[3] as Dictionary)["tier"] == "L" and (merged[3] as Dictionary)["retier"]
		and not (merged[2] as Dictionary)["retier"], str(merged.map(func(r: Dictionary) -> String: return r["tier"])))
	var later: Dictionary = p.request("impact", 1.05, 0.5, {"cells": 1})
	ck("after the 40 ms cooldown a new voice starts", later["action"] == "play" and p.active_count() == 2)


func test_cooldown_drop_after_the_voice_ended() -> void:
	var p := VoicePool.new(_bank())
	var a: Dictionary = p.request("impact", 0.0, 0.01)
	p.release(int(a["handle"]))
	var r: Dictionary = p.request("impact", 0.02, 0.5)
	ck("a repeat inside the cooldown whose voice is gone is dropped", r["action"] == "drop" and r["reason"] == "cooldown")


func test_total_cap_keeps_warning_reserve() -> void:
	var p := VoicePool.new(_bank(5))
	p.request("low", 0.0, 9.0)
	p.request("normal", 0.1, 9.0)
	p.request("capped", 0.2, 9.0)
	var r: Dictionary = p.request("loop", 0.3, 9.0)
	ck("total 5 - 2 reserved = 3 shared voices: the 4th steals the oldest Low", r["action"] == "play" and not _ids(p).has("low")
		and p.active_count() == 3)
	var w1: Dictionary = p.request("crit", 0.4, 9.0)
	var w2: Dictionary = p.request("crit", 0.5, 9.0)
	ck("both reserved Warning voices still play on a full pool", w1["action"] == "play" and w2["action"] == "play"
		and p.active_count("Warning") == 2 and p.active_count() == 5)


func test_expiry_loops_and_tags() -> void:
	var p := VoicePool.new(_bank())
	p.request("normal", 0.0, 0.3, {"tag": "cast:1"})
	p.request("loop", 0.0, 0.3, {"tag": "channel:0"})
	var gone: Array[int] = p.expire(0.31)
	ck("one-shots expire at start + duration, loops live on", gone.size() == 1 and _ids(p) == ["loop"])
	var stopped: Array[int] = p.release_tag("channel:0")
	ck("release_tag stops the tagged loop", stopped.size() == 1 and p.active_count() == 0)


func test_unknown_event_dropped() -> void:
	var p := VoicePool.new(_bank())
	ck("an unknown id is dropped", p.request("nope", 0.0, 1.0)["reason"] == "unknown")


func test_real_bank_five_hoa_loi_cells() -> void:
	var bank: AudioBank = AudioBank.load_from_file()
	var p := VoicePool.new(bank)
	var r: Dictionary = p.request("skill.hoa_loi.impact", 0.0, 0.6, {"cells": 5})
	ck("one Hoa Loi detonation of 5 cells = one voice at tier L", r["action"] == "play" and r["tier"] == "L" and p.active_count() == 1)

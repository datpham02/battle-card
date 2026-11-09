extends SceneTree
## AudioEventRules (docs/skill-v2/10-audio-system-design.md §4–§7, §11 audio_event_rules_test): pure mapping of each
## combat / UI fact to cues. Wind-up and channel loop on swing start; cancel deferred and replaced by NGẮT! on an
## interrupt (cancel != interrupt != miss); a scheduled cast gives commit, travel, one impact per same-time group (tier
## by cells; burst / drop_final = impact_final at L) on the event `at` times and an aftermath; Hỏa Lôi's fuse gives
## seal, charge, 3 rising ticks and the prime; hit layer only on a hit; low HP; boss warnings; match end.
## Run: godot --headless --path . -s res://tests/unit/audio/audio_event_rules_test.gd

const P: int = AudioEventRules.SIDE_PLAYER
const E: int = AudioEventRules.SIDE_ENEMY

var fails: int = 0
var bank: AudioBank
var sc: SkillConfig


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	bank = AudioBank.load_from_file()
	sc = SkillConfig.load_from_file()
	test_swing_started()
	test_cancel_and_interrupt()
	test_tram_dia_schedule()
	test_ngan_kiem_drops()
	test_hoa_loi_fuse_and_one_detonation()
	test_fizzle()
	test_impact_hit_layer_only_on_hit()
	test_damage_and_low_hp()
	test_boss_warnings()
	test_match_end_and_ui()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _ev(at: float, n: int, kind: String) -> Dictionary:
	var cells: Array[Vector2i] = []
	for i: int in n:
		cells.append(Vector2i(4 + i, 1))
	return {"at": at, "t": at, "cells": cells, "kind": kind, "mult": 1.0}


func _ops(cues: Array[Dictionary], op: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in cues:
		if c["op"] == op:
			out.append(c)
	return out


func _ids(cues: Array) -> Array:
	return cues.map(func(c: Dictionary) -> String: return str(c.get("id", "")))


func test_swing_started() -> void:
	var c: Array[Dictionary] = AudioEventRules.on_swing_started(bank, P, "ngan_kiem", sc.get_skill("ngan_kiem"), 4)
	ck("Ngan Kiem swing start: the summon loop alone (no separate charge, user 2026-11-09)",
		_ids(c) == ["skill.ngan_kiem.channel_loop"] and c[0]["tag"] == AudioEventRules.channel_tag(P), str(_ids(c)))
	var t: Array[Dictionary] = AudioEventRules.on_swing_started(bank, P, "tram_dia", sc.get_skill("tram_dia"), 3)
	ck("Tram Dia swing start: its wind-up only (no loop)", _ids(t) == ["skill.tram_dia.windup"])
	var g: Array[Dictionary] = AudioEventRules.on_swing_started(bank, P, "kiem_khi", sc.get_skill("kiem_khi"), 2)
	ck("an archetype card: the generic wind-up", _ids(g) == ["skill.generic.windup"])
	var b: Array[Dictionary] = AudioEventRules.on_swing_started(bank, E, "kiem_khi", sc.get_skill("kiem_khi"), 2)
	ck("the boss's swing start is the boss wind-up warning", _ids(b) == ["warn.boss.windup"])


func test_cancel_and_interrupt() -> void:
	var c: Array[Dictionary] = AudioEventRules.on_swing_cancelled(bank, P, "ngan_kiem", sc.get_skill("ngan_kiem"))
	var deferred: Array[Dictionary] = _ops(c, "after")
	ck("cancel stops wind-up and loop", _ops(c, "stop").size() == 2)
	ck("the cancel cue is deferred and tagged (an interrupt can replace it)", deferred.size() == 1
		and deferred[0]["id"] == "skill.ngan_kiem.cancel" and deferred[0]["tag"] == AudioEventRules.cancel_tag(P))
	var i: Array[Dictionary] = AudioEventRules.on_swing_interrupted(P)
	ck("interrupt drops the deferred cancel and plays NGAT!", _ops(i, "cancel").size() == 1 and _ops(i, "cancel")[0]["tag"] == AudioEventRules.cancel_tag(P)
		and _ids(_ops(i, "play")) == ["combat.interrupt"])
	ck("cancel, interrupt and miss are distinct sounds", "skill.ngan_kiem.cancel" != "combat.interrupt"
		and AudioEventRules.on_impact_resolved(bank, P, _ev(1.0, 1, "drop"), false, "ngan_kiem", sc.get_skill("ngan_kiem")).is_empty())
	ck("the boss's cancel plays no cancel sound", _ops(AudioEventRules.on_swing_cancelled(bank, E, "kiem_khi", {}), "after").is_empty())


func test_tram_dia_schedule() -> void:
	var events: Array = [_ev(0.35, 1, "burst"), _ev(0.6, 1, "surge"), _ev(0.85, 1, "surge")]
	var cast: Dictionary = {"cast_id": 7, "skill_id": "tram_dia", "cells": [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)], "events": events}
	var c: Array[Dictionary] = AudioEventRules.on_cast_scheduled(bank, P, cast, sc.get_skill("tram_dia"), 0.1)
	ck("commit and travel now (first impact 0.25 s away)", _ids(_ops(c, "play")) == ["skill.tram_dia.commit", "skill.tram_dia.travel"])
	var at: Array[Dictionary] = _ops(c, "at")
	ck("burst = impact_final at tier L, at the event time", at[0]["id"] == "skill.tram_dia.impact_final" and is_equal_approx(at[0]["at"], 0.35)
		and at[0]["tier"] == "L")
	ck("surge steps = impact with step 1, 2 at their times", at[1]["id"] == "skill.tram_dia.impact" and at[1]["step"] == 1
		and is_equal_approx(at[2]["at"], 0.85) and at[2]["step"] == 2 and at[1]["tier"] == "S")
	ck("aftermath 0.4 s after the last impact", at[3]["id"] == "skill.tram_dia.aftermath" and is_equal_approx(at[3]["at"], 1.25))
	ck("every scheduled cue carries the cast tag", at.all(func(x: Dictionary) -> bool: return x["tag"] == "cast:7"))
	ck("the release stops the wind-up and the loop", _ops(c, "stop").size() == 2)
	var immediate: Array[Dictionary] = AudioEventRules.on_cast_scheduled(bank, P, {"cast_id": 1, "skill_id": "tram_dia", "cells": [],
		"events": [_ev(0.12, 1, "burst")]}, sc.get_skill("tram_dia"), 0.1)
	ck("no travel sound when the impact is under travel_min_sec away", not _ids(immediate).has("skill.tram_dia.travel"))


func test_ngan_kiem_drops() -> void:
	var events: Array = [_ev(1.0, 1, "drop"), _ev(1.12, 1, "drop"), _ev(1.24, 1, "drop_final")]
	var c: Array[Dictionary] = AudioEventRules.on_cast_scheduled(bank, P, {"cast_id": 2, "skill_id": "ngan_kiem", "cells": [], "events": events},
		sc.get_skill("ngan_kiem"), 0.78)
	var at: Array = _ids(_ops(c, "at"))
	ck("one impact per drop, the last is the centre blade", at == ["skill.ngan_kiem.impact", "skill.ngan_kiem.impact",
		"skill.ngan_kiem.impact_final"], str(at))
	ck("no commit cue (silent by design, user 2026-11-09) and no travel for a sky card", _ids(_ops(c, "play")).is_empty(),
		str(_ids(_ops(c, "play"))))


func test_hoa_loi_fuse_and_one_detonation() -> void:
	var events: Array = [_ev(2.45, 1, "fuse"), _ev(2.45, 1, "fuse"), _ev(2.45, 1, "fuse"), _ev(2.45, 1, "fuse"), _ev(2.45, 1, "fuse")]
	var cast: Dictionary = {"cast_id": 3, "skill_id": "hoa_loi", "cells": [1, 2, 3, 4, 5], "events": events, "fuse_sec": 2.0}
	var c: Array[Dictionary] = AudioEventRules.on_cast_scheduled(bank, P, cast, sc.get_skill("hoa_loi"), 0.45)
	var at: Array[Dictionary] = _ops(c, "at")
	var impacts: Array = at.filter(func(x: Dictionary) -> bool: return x["id"] == "skill.hoa_loi.impact")
	ck("5 seals detonating together = ONE impact cue at tier L", impacts.size() == 1 and impacts[0]["tier"] == "L" and impacts[0]["cells"] == 5)
	# synced to src/art/fuse_fx.gd (user 2026-11-09): the lock when the seals' rings appear (DRAW_IN_SEC 0.25 after the
	# release), a pulse at each ring drop (fuse/3, 2fuse/3) and at the final flicker (FINAL_SEC 0.35 before `at`)
	ck("the release plays the one fire burst at once (commit = skill.hoa_loi.ignite); no seal lock (user chose 'B')",
		_ids(_ops(c, "play")).has("skill.hoa_loi.ignite") and not _ids(c).has("skill.hoa_loi.seal"), str(_ids(c)))
	ck("no charge drone and no prime hiss (silent by design)", not _ids(c).has("skill.hoa_loi.charge") and not _ids(c).has("skill.hoa_loi.prime"))
	ck("Hoa Loi's fuse is silent: no countdown ticks (user 2026-11-09: 'bỏ tiếng tò te')",
		not _ids(c).has("skill.hoa_loi.tick"))
	# the pulse timing stays available to other fuse cards: a copy of the data with the tick mapped back on
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio_events.json"))
	data["cards"]["hoa_loi"]["tick"] = "skill.hoa_loi.tick"
	data["cards"]["hoa_loi"]["seal"] = "skill.hoa_loi.seal"
	var c2: Array[Dictionary] = AudioEventRules.on_cast_scheduled(AudioBank.new(data), P, cast, sc.get_skill("hoa_loi"), 0.45)
	var seal: Array = _ops(c2, "at").filter(func(x: Dictionary) -> bool: return x["id"] == "skill.hoa_loi.seal")
	ck("a fuse card with a seal cue: it plays when the seals are armed (release + 0.25 s, FuseFx DRAW_IN_SEC)",
		seal.size() == 1 and is_equal_approx(seal[0]["at"], 0.70), str(seal))
	var ticks: Array = _ops(c2, "at").filter(func(x: Dictionary) -> bool: return x["id"] == "skill.hoa_loi.tick")
	ck("a fuse card with ticks: 3 pulses on the visible warning changes, rising step 0-1-2", ticks.size() == 3 and ticks[2]["step"] == 2
		and is_equal_approx(ticks[0]["at"], 0.45 + 2.0 / 3.0) and is_equal_approx(ticks[1]["at"], 0.45 + 4.0 / 3.0)
		and is_equal_approx(ticks[2]["at"], 2.45 - 0.35), str(ticks.map(func(x: Dictionary) -> float: return float(x["at"]))))


func test_fizzle() -> void:
	var c: Array[Dictionary] = AudioEventRules.on_cast_scheduled(bank, P, {"cast_id": 4, "skill_id": "hoa_loi", "cells": [], "events": [],
		"fizzled": true}, sc.get_skill("hoa_loi"), 1.0)
	ck("a cast that armed nothing plays only its fizzle", _ids(_ops(c, "play")) == ["skill.hoa_loi.fizzle"] and _ops(c, "at").is_empty())


func test_impact_hit_layer_only_on_hit() -> void:
	var hit: Array[Dictionary] = AudioEventRules.on_impact_resolved(bank, P, _ev(1.0, 2, "hit"), true, "kiem_khi", sc.get_skill("kiem_khi"))
	ck("a hit drops the deferred body hit, then plays the hit layer and the enemy body hit",
		_ids(_ops(hit, "play")) == ["skill.generic.hit", "combat.hit.enemy"] and _ops(hit, "cancel").size() == 1
		and _ops(hit, "cancel")[0]["tag"] == AudioEventRules.body_tag(AudioEventRules.SIDE_ENEMY), str(hit))
	var blast: Array[Dictionary] = AudioEventRules.on_impact_resolved(bank, P, _ev(1.0, 4, "fuse"), true, "hoa_loi", sc.get_skill("hoa_loi"))
	ck("Hoa Loi's blast is the hit: no hit layer and no body thump on top (user 2026-11-09)", _ops(blast, "play").is_empty()
		and _ops(blast, "cancel").size() == 1, str(blast))
	var dmg: Array[Dictionary] = AudioEventRules.on_damaged(bank, AudioEventRules.SIDE_ENEMY, 5.0, 1.0)
	ck("damage defers the body hit by under a frame, tagged so its source can drop it", _ops(dmg, "after").size() == 1
		and float(_ops(dmg, "after")[0]["delay"]) < 1.0 / 60.0 and _ops(dmg, "after")[0]["tag"] == AudioEventRules.body_tag(AudioEventRules.SIDE_ENEMY))
	var burn: Array[Dictionary] = AudioEventRules.on_burn_hurt(AudioEventRules.SIDE_ENEMY)
	ck("a burn tick drops the body thump and plays a light sizzle", _ids(_ops(burn, "play")) == ["status.burn.hurt"]
		and _ops(burn, "cancel")[0]["tag"] == AudioEventRules.body_tag(AudioEventRules.SIDE_ENEMY))
	ck("a miss plays nothing (the body was pre-scheduled)", AudioEventRules.on_impact_resolved(bank, P, _ev(1.0, 2, "hit"), false, "kiem_khi",
		sc.get_skill("kiem_khi")).is_empty())


func test_damage_and_low_hp() -> void:
	ck("player hurt: body hit", _ids(AudioEventRules.on_damaged(bank, P, 5.0, 0.8)) == ["combat.hit.player"])
	ck("player under 25 %: heartbeat too", _ids(AudioEventRules.on_damaged(bank, P, 5.0, 0.2)) == ["combat.hit.player", "combat.hp_low"])
	ck("enemy hurt: enemy body hit, no heartbeat", _ids(AudioEventRules.on_damaged(bank, E, 5.0, 0.1)) == ["combat.hit.enemy"])
	ck("zero damage: nothing", AudioEventRules.on_damaged(bank, P, 0.0, 0.1).is_empty())


func test_boss_warnings() -> void:
	var w: Array[Dictionary] = AudioEventRules.on_warning_started(bank, "slam", 1.2)
	ck("imminent alarm 0.5 s before the warning ends", w.size() == 1 and w[0]["op"] == "after" and w[0]["id"] == "warn.boss.imminent"
		and is_equal_approx(w[0]["delay"], 0.7) and w[0]["tag"] == "warn:slam")
	ck("a short warning alarms at once", is_equal_approx(AudioEventRules.on_warning_started(bank, "x", 0.3)[0]["delay"], 0.0))
	ck("warning cleared drops the pending alarm", AudioEventRules.on_warning_cleared("slam") == [{"op": "cancel", "tag": "warn:slam"}])
	ck("boss WINDUP edge: wind-up warning", _ids(AudioEventRules.on_boss_windup()) == ["warn.boss.windup"])


func test_match_end_and_ui() -> void:
	var v: Array[Dictionary] = AudioEventRules.on_match_ended(true)
	ck("match end: cancel pending, stop combat, victory stinger", v[0]["op"] == "cancel_all" and v[1]["op"] == "stop_all" and v[2]["id"] == "flow.victory")
	ck("defeat stinger", AudioEventRules.on_match_ended(false)[2]["id"] == "flow.defeat")
	var p: Array[Dictionary] = AudioEventRules.on_block_pickup(bank, 5)
	ck("Block pickup pitch tier by size (5 cells = L)", p[0]["id"] == "block.pickup" and p[0]["tier"] == "L")
	ck("UI cue", AudioEventRules.ui("card.choose")[0]["id"] == "card.choose")

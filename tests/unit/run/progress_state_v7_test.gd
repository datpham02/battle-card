extends SceneTree
## Story 037: ProgressState v7 - milestones / achievements / seen_unlocks, round trip, v4..v6 migration, unknown version.

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _same(a: ProgressState, b: ProgressState) -> bool:
	return a.get_milestones() == b.get_milestones() and a.get_achievements() == b.get_achievements() \
		and a.get_seen_unlocks() == b.get_seen_unlocks() and a.get_regions_boss_beaten() == b.get_regions_boss_beaten() \
		and a.get_spared_bosses() == b.get_spared_bosses() and a.get_executed_bosses() == b.get_executed_bosses() \
		and a.get_spare_total() == b.get_spare_total() and a.get_execute_total() == b.get_execute_total() \
		and a.get_endings_seen() == b.get_endings_seen() and a.get_best_floor() == b.get_best_floor() \
		and a.get_cleared_bosses() == b.get_cleared_bosses() and a.get_locale() == b.get_locale() \
		and a.get_seen_cards() == b.get_seen_cards()


func _init() -> void:
	_check("VERSION is 8 (Story 038)", ProgressState.VERSION == 8)
	var fresh := ProgressState.new()
	_check("fresh: empty ledger", fresh.get_milestones().is_empty() and fresh.get_achievements().is_empty() and fresh.get_seen_unlocks().is_empty() and fresh.get_milestone("x") == 0)

	# --- milestone writers
	var p := ProgressState.new()
	p.add_milestone("x", 2)
	p.add_milestone("x")
	p.add_milestone("", 5)
	p.add_milestone("neg", -1)
	p.add_milestone("zero", 0)
	_check("add_milestone sums, ignores empty key and n < 1", p.get_milestone("x") == 3 and p.get_milestones() == {"x": 3}, str(p.get_milestones()))
	var copy: Dictionary = p.get_milestones()
	copy["x"] = 99
	_check("get_milestones is a copy", p.get_milestone("x") == 3)
	p.add_region_boss_beaten("ch1")
	p.add_region_boss_beaten("ch1")
	p.add_region_boss_beaten("")
	_check("add_region_boss_beaten: +1 per call, list deduped", p.get_milestone("region_boss:ch1") == 2 and p.get_regions_boss_beaten() == (["ch1"] as Array[String]))
	p.record_fate("m1", FateLogic.FATE_SPARE)
	p.record_fate("m2", FateLogic.FATE_EXECUTE)
	p.record_fate("m3", FateLogic.FATE_EXECUTE)
	p.record_fate("m4", "bogus")
	_check("record_fate: spares_total / kills_total", p.get_milestone("spares_total") == 1 and p.get_milestone("kills_total") == 2 and p.get_spare_total() == 1 and p.get_execute_total() == 2)
	p.record_ending("spare")
	p.record_ending("spare")
	p.record_ending("")
	_check("record_ending: +1 per call, list deduped", p.get_milestone("ending:spare") == 2 and p.get_endings_seen() == (["spare"] as Array[String]))
	p.record_run_won("tho_san")
	p.record_run_won("kiem_si")
	p.record_run_won("")
	_check("record_run_won: runs_won and runs_won:<id>", p.get_milestone("runs_won") == 3 and p.get_milestone("runs_won:tho_san") == 1 and p.get_milestone("runs_won:kiem_si") == 1 and p.get_milestone("runs_won:") == 0)
	p.record_final_reached()
	_check("record_final_reached", p.get_milestone("reached_final") == 1)

	# --- achievements and seen unlocks
	_check("add_achievement: new -> true, dedup -> false, empty -> false", p.add_achievement("hunter_path") and not p.add_achievement("hunter_path") and not p.add_achievement(""))
	p.add_achievement("first_run_won")
	_check("get_achievements keeps earned order, is a copy", p.get_achievements() == (["hunter_path", "first_run_won"] as Array[String]) and p.has_achievement("first_run_won") and not p.has_achievement("zz"))
	var cfg: AchievementsConfig = AchievementsConfig.load_from_file()
	_check("is_new_unlock: earned and unseen", p.is_new_unlock("character", "tho_san", cfg) and p.is_new_unlock("relic", "tui_rong", cfg))
	_check("is_new_unlock: owner not earned / open content -> false", not p.is_new_unlock("character", "giao_si", cfg) and not p.is_new_unlock("card", "kiem_khi", cfg))
	p.mark_unlock_seen("character", "tho_san")
	p.mark_unlock_seen("character", "tho_san")
	p.mark_unlock_seen("", "x")
	_check("mark_unlock_seen: dedup, seen -> not new", not p.is_new_unlock("character", "tho_san", cfg) and p.is_new_unlock("relic", "tui_rong", cfg) and p.get_seen_unlocks() == (["character:tho_san"] as Array[String]))

	# --- round trip
	p.record_floor(4)
	p.mark_card_seen("kiem_khi")
	p.add_cleared_boss()
	p.set_locale("en")
	var json: String = p.to_json()
	var parsed: Dictionary = JSON.parse_string(json)
	_check("json carries version 7 and the new keys", int(parsed["version"]) == ProgressState.VERSION and parsed.has("milestones") and parsed.has("achievements") and parsed.has("seen_unlocks"))
	var back: ProgressState = ProgressState.from_json(json)
	_check("v7 round trip: every field equal", _same(p, back))
	_check("v7 round trip: json stable", back.to_json() == json)

	# --- v6 migration
	var v6: Dictionary = {"version": 6, "locale": "en", "regions_boss_beaten": ["ch1", "ch2"], "best_floor": 4, "seen_cards": ["a"], "cleared_bosses": 2,
		"spared_bosses": ["m1"], "executed_bosses": ["m2", "m3"], "spare_total": 2, "execute_total": 3, "endings_seen": ["spare", "balance"], "run_in_progress": null}
	var m6: ProgressState = ProgressState.from_json(JSON.stringify(v6))
	_check("v6: region_boss:<r> = 1 per beaten region", m6.get_milestone("region_boss:ch1") == 1 and m6.get_milestone("region_boss:ch2") == 1 and m6.get_milestone("region_boss:ch3") == 0)
	_check("v6: spares_total / kills_total from the totals", m6.get_milestone("spares_total") == 2 and m6.get_milestone("kills_total") == 3)
	_check("v6: ending:<id> = 1 per ending seen", m6.get_milestone("ending:spare") == 1 and m6.get_milestone("ending:balance") == 1 and m6.get_milestone("ending:execute") == 0)
	_check("v6: nothing else invented, no achievements", m6.get_milestone("runs_won") == 0 and m6.get_milestone("reached_final") == 0 and m6.get_achievements().is_empty() and m6.get_seen_unlocks().is_empty())
	_check("v6: old fields kept", m6.get_locale() == "en" and m6.get_best_floor() == 4 and m6.get_cleared_bosses() == 2 and m6.get_spared_bosses() == (["m1"] as Array[String]) and m6.get_execute_total() == 3)
	_check("v6 re-saves as v7 and reloads equal", _same(m6, ProgressState.from_json(m6.to_json())) and int(JSON.parse_string(m6.to_json())["version"]) == ProgressState.VERSION)

	# --- v5 / v4 migration
	var v5: Dictionary = {"version": 5, "locale": "vi", "regions_boss_beaten": ["ch3"], "best_floor": 2, "seen_cards": [], "cleared_bosses": 1}
	var m5: ProgressState = ProgressState.from_json(JSON.stringify(v5))
	_check("v5: region_boss:ch3 = 1, no spare/ending ledger", m5.get_milestones() == {"region_boss:ch3": 1}, str(m5.get_milestones()))
	var v4: Dictionary = {"version": 4, "locale": "vi", "cleared_chapters": ["ch1", "ch2"], "seen_cards": [], "cleared_bosses": 2}
	var m4: ProgressState = ProgressState.from_json(JSON.stringify(v4))
	_check("v4: cleared_chapters -> region_boss:<r> = 1", m4.get_milestones() == {"region_boss:ch1": 1, "region_boss:ch2": 1} and m4.get_regions_boss_beaten() == (["ch1", "ch2"] as Array[String]), str(m4.get_milestones()))
	_check("v4: no achievements granted retroactively", m4.get_achievements().is_empty())
	var dup: ProgressState = ProgressState.from_json(JSON.stringify({"version": 5, "locale": "vi", "regions_boss_beaten": ["ch1", "ch1", ""]}))
	_check("duplicate region entries in an old file still count 1", dup.get_milestone("region_boss:ch1") == 1)
	var v1: ProgressState = ProgressState.from_json(JSON.stringify({"version": 1, "locale": "en"}))
	_check("v1: only locale, empty ledger", v1.get_locale() == "en" and v1.get_milestones().is_empty())

	# --- unknown versions and bad v7 content
	_check("version 9 -> empty", ProgressState.from_json(JSON.stringify({"version": 9, "milestones": {"x": 5}, "locale": "en"})).get_milestones().is_empty())
	_check("version 0 -> empty", ProgressState.from_json(JSON.stringify({"version": 0, "milestones": {"x": 5}})).get_milestones().is_empty())
	_check("no version -> empty", ProgressState.from_json(JSON.stringify({"milestones": {"x": 5}})).get_milestones().is_empty())
	_check("corrupt text -> empty", ProgressState.from_json("{nope").get_milestones().is_empty() and ProgressState.from_json("").get_milestones().is_empty())
	var bad: ProgressState = ProgressState.from_json(JSON.stringify({"version": 7, "locale": "vi", "milestones": {"ok": 2, "neg": -3, "str": "x", "": 4, "flt": 2.0},
		"achievements": ["a", "a", "", "b"], "seen_unlocks": ["card:x", "card:x"]}))
	_check("v7: bad ledger entries dropped, ids deduped", bad.get_milestones() == {"ok": 2, "flt": 2} and bad.get_achievements() == (["a", "b"] as Array[String]) and bad.get_seen_unlocks() == (["card:x"] as Array[String]), str(bad.get_milestones()))
	var wrong_types: ProgressState = ProgressState.from_json(JSON.stringify({"version": 7, "locale": "vi", "milestones": [1, 2], "achievements": "x", "seen_unlocks": 5}))
	_check("v7: wrong container types -> empty", wrong_types.get_milestones().is_empty() and wrong_types.get_achievements().is_empty() and wrong_types.get_seen_unlocks().is_empty())

	# --- dev: mark_all_unlocked
	var all := ProgressState.new()
	all.mark_all_unlocked(cfg, ["ch1", "ch2", "ch3", "swamp", "desert"])
	var every: bool = true
	for id: String in cfg.ids():
		every = every and all.has_achievement(id)
	_check("mark_all_unlocked: every achievement earned", every and all.get_achievements().size() == 22)
	_check("mark_all_unlocked: every region boss beaten", all.get_regions_boss_beaten().size() == 5 and all.get_milestone("region_boss:ch2") >= 1)
	_check("mark_all_unlocked: milestones satisfy their conditions", all.get_milestone("kills_total") >= 3 and all.get_milestone("spares_total") >= 3 and all.get_milestone("reached_final") >= 1 and all.get_milestone("runs_won") >= 1 and all.get_milestone("ending:execute") >= 1)
	var nothing_new: bool = true
	for r: Dictionary in cfg.all_rewards():
		nothing_new = nothing_new and not all.is_new_unlock(str(r["kind"]), str(r["id"]), cfg)
	_check("mark_all_unlocked: rewards marked seen, nothing locked", nothing_new and cfg.locked_content(all).is_empty())
	var again := ProgressState.from_json(all.to_json())
	_check("mark_all_unlocked state round trips", _same(all, again))

	print("FAILS=", fails)
	quit(fails)

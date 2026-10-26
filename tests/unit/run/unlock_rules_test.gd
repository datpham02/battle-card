extends SceneTree
## Story 037: UnlockRules - every condition type grants the right achievement exactly once, contextual types
## react only to their own event, a migrated save gets no retroactive grants, process is idempotent.

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _boss_won(match_stats: Dictionary = {}, run_stats: Dictionary = {}, deck: Array = [], is_boss: bool = true) -> Dictionary:
	return {"type": "match_won", "character_id": "kiem_si", "region_id": "ch1", "is_region_boss": is_boss, "is_final": false,
		"match_stats": match_stats, "run_stats": run_stats, "deck_ids": deck}


func _run_ended(won: bool, run_stats: Dictionary = {}, deck: Array = []) -> Dictionary:
	return {"type": "run_ended", "won": won, "ending_id": "balance", "character_id": "kiem_si", "run_stats": run_stats, "deck_ids": deck}


func _init() -> void:
	var cfg: AchievementsConfig = AchievementsConfig.load_from_file()
	_check("24 achievements loaded", cfg.ids().size() == 24)

	# --- milestone: reached_final
	var p := ProgressState.new()
	_check("fresh progress + final_reached event grants nothing", UnlockRules.process(cfg, p, {"type": "final_reached"}).is_empty())
	p.record_final_reached()
	var got: Array[String] = UnlockRules.process(cfg, p, {"type": "final_reached"})
	_check("milestone reached_final -> reach_an_dai", got == (["reach_an_dai"] as Array[String]), str(got))
	_check("idempotent: second process grants nothing", UnlockRules.process(cfg, p, {"type": "final_reached"}).is_empty() and p.get_achievements().size() == 1)

	# --- milestone_sum (any region boss) + per-region milestones, file order
	var p2 := ProgressState.new()
	p2.add_region_boss_beaten("ch1")
	got = UnlockRules.process(cfg, p2, _boss_won())
	_check("first boss -> first_region_boss then boss_forest (file order)", got == (["first_region_boss", "boss_forest"] as Array[String]), str(got))
	p2.add_region_boss_beaten("swamp")
	_check("another region boss grants nothing new", UnlockRules.process(cfg, p2, _boss_won()).is_empty())
	p2.add_region_boss_beaten("ch2")
	_check("ch2 -> boss_dungeon only", UnlockRules.process(cfg, p2, _boss_won()) == (["boss_dungeon"] as Array[String]))
	p2.add_region_boss_beaten("ch3")
	_check("ch3 -> boss_frost only", UnlockRules.process(cfg, p2, _boss_won()) == (["boss_frost"] as Array[String]))

	# --- kills / spares totals
	var p3 := ProgressState.new()
	p3.record_fate("a", FateLogic.FATE_EXECUTE)
	p3.record_fate("b", FateLogic.FATE_EXECUTE)
	p3.record_fate("c", FateLogic.FATE_SPARE)
	_check("2 kills + 1 spare grants nothing", UnlockRules.process(cfg, p3, _run_ended(false)).is_empty())
	p3.record_fate("d", FateLogic.FATE_EXECUTE)
	_check("3 kills -> hunter_path", UnlockRules.process(cfg, p3, _run_ended(false)) == (["hunter_path"] as Array[String]))
	p3.record_fate("e", FateLogic.FATE_SPARE)
	p3.record_fate("f", FateLogic.FATE_SPARE)
	_check("3 spares -> mercy_path", UnlockRules.process(cfg, p3, _run_ended(false)) == (["mercy_path"] as Array[String]))
	var pr: Dictionary = UnlockRules.progress_of(cfg, "hunter_path", p3)
	_check("progress_of earned milestone = target/target/done", pr == {"current": 3, "target": 3, "done": true}, str(pr))
	var p3b := ProgressState.new()
	p3b.record_fate("a", FateLogic.FATE_EXECUTE)
	p3b.record_fate("b", FateLogic.FATE_EXECUTE)
	pr = UnlockRules.progress_of(cfg, "hunter_path", p3b)
	_check("progress_of 2 of 3", pr == {"current": 2, "target": 3, "done": false}, str(pr))
	p3b.add_milestone("kills_total", 5)
	pr = UnlockRules.progress_of(cfg, "hunter_path", p3b)
	_check("progress_of caps current at target while not yet processed", int(pr["current"]) == 3 and not bool(pr["done"]), str(pr))
	pr = UnlockRules.progress_of(cfg, "first_region_boss", p3b)
	_check("progress_of milestone_sum", pr == {"current": 0, "target": 1, "done": false}, str(pr))
	pr = UnlockRules.progress_of(cfg, "zone_trap", p3b)
	_check("progress_of contextual type = 0/1", pr == {"current": 0, "target": 1, "done": false}, str(pr))
	pr = UnlockRules.progress_of(cfg, "nope", p3b)
	_check("progress_of unknown id", pr == {"current": 0, "target": 1, "done": false}, str(pr))
	_check("requirement_text_key = desc_key", UnlockRules.requirement_text_key(cfg, "hunter_path") == "achievement.hunter_path.desc" and UnlockRules.requirement_text_key(cfg, "nope") == "")

	# --- endings
	var p4 := ProgressState.new()
	p4.record_ending("spare")
	p4.record_ending("balance")
	p4.record_ending("execute")
	var e: Array[String] = UnlockRules.process(cfg, p4, _run_ended(true))
	_check("three endings -> ending_mercy, ending_middle, ending_slaughter", e == (["ending_mercy", "ending_middle", "ending_slaughter"] as Array[String]), str(e))

	# --- runs won
	var p5 := ProgressState.new()
	p5.record_run_won("tho_san")
	got = UnlockRules.process(cfg, p5, _run_ended(true))
	_check("record_run_won(tho_san) -> first_run_won + win_tho_san", got == (["first_run_won", "win_tho_san"] as Array[String]), str(got))
	p5.record_run_won("giao_si")
	_check("a second character -> win_giao_si only", UnlockRules.process(cfg, p5, _run_ended(true)) == (["win_giao_si"] as Array[String]))
	p5.record_run_won("kiem_si")
	p5.record_run_won("phap_su")
	p5.record_run_won("sat_thu")
	got = UnlockRules.process(cfg, p5, _run_ended(true))
	_check("the other three win_ achievements", got == (["win_kiem_si", "win_phap_su", "win_sat_thu"] as Array[String]), str(got))

	# --- run_counter (zone_trap, featured_10): match_won and run_ended, not other events
	var p6 := ProgressState.new()
	_check("run_counter below min grants nothing", UnlockRules.process(cfg, p6, _boss_won({}, {"boss_thorn_steps": 4, "featured_casts": 9}, [], false)).is_empty())
	_check("run_counter ignores final_reached", UnlockRules.process(cfg, p6, {"type": "final_reached", "run_stats": {"boss_thorn_steps": 9}}).is_empty())
	got = UnlockRules.process(cfg, p6, _boss_won({}, {"boss_thorn_steps": 5}, [], false))
	_check("zone_trap on match_won (not a boss)", got == (["zone_trap"] as Array[String]), str(got))
	got = UnlockRules.process(cfg, p6, _run_ended(false, {"featured_casts": 10}))
	_check("featured_10 on run_ended", got == (["featured_10"] as Array[String]), str(got))
	_check("run_counter granted once", UnlockRules.process(cfg, p6, _run_ended(false, {"featured_casts": 99, "boss_thorn_steps": 99})).is_empty())

	# --- match_counter (frost_burst_5): match_won only
	var p7 := ProgressState.new()
	_check("frost_bursts 4 grants nothing", UnlockRules.process(cfg, p7, _boss_won({"frost_bursts": 4}, {}, [], false)).is_empty())
	var wrong: Dictionary = _run_ended(true)
	wrong["match_stats"] = {"frost_bursts": 9}
	_check("match_counter ignores run_ended", UnlockRules.process(cfg, p7, wrong).is_empty())
	got = UnlockRules.process(cfg, p7, _boss_won({"frost_bursts": 5}, {}, [], false))
	_check("frost_bursts 5 on a won match (any node) -> frost_burst_5", got == (["frost_burst_5"] as Array[String]), str(got))

	# --- boss_clear_deck (burn_build)
	var burn: Array = ["hoa_tinh", "hoa_xa", "hoa_tran", "liet_hoa"]
	_check("burn cards recognised from cards.json", UnlockRules.is_burn_card("hoa_tinh") and UnlockRules.is_burn_card("thien_hoa") and not UnlockRules.is_burn_card("kiem_khi") and not UnlockRules.is_burn_card("nope"))
	_check("burn_card_count counts duplicates and {id} entries", UnlockRules.burn_card_count(["hoa_tinh", "hoa_tinh", {"id": "hoa_xa", "level": 2}, "kiem_khi"]) == 3)
	var p8 := ProgressState.new()
	_check("3 burn cards grants nothing", UnlockRules.process(cfg, p8, _boss_won({}, {}, ["hoa_tinh", "hoa_xa", "hoa_tran", "kiem_khi", "kiem_khi"])).is_empty())
	_check("4 burn cards without a boss grants nothing", UnlockRules.process(cfg, p8, _boss_won({}, {}, burn, false)).is_empty())
	var run_end_burn: Dictionary = _run_ended(true, {}, burn)
	_check("4 burn cards on run_ended grants nothing", not UnlockRules.process(cfg, p8, run_end_burn).has("burn_build"))
	_check("4 burn cards on a region boss -> burn_build", UnlockRules.process(cfg, p8, _boss_won({}, {}, burn)) == (["burn_build"] as Array[String]))

	# --- boss_clear_no_hit
	var p9 := ProgressState.new()
	_check("a hit taken grants nothing", UnlockRules.process(cfg, p9, _boss_won({"hits_taken": 1})).is_empty())
	_check("no hit on a non-boss match grants nothing", UnlockRules.process(cfg, p9, _boss_won({"hits_taken": 0}, {}, [], false)).is_empty())
	_check("missing match_stats grants nothing", UnlockRules.process(cfg, p9, _boss_won({})).is_empty())
	_check("hits_taken 0 on a region boss -> no_hit_boss", UnlockRules.process(cfg, p9, _boss_won({"hits_taken": 0})) == (["no_hit_boss"] as Array[String]))

	# --- run_won_deck_max (small_deck)
	var p10 := ProgressState.new()
	var nine: Array = ["a", "a", "a", "a", "a", "a", "a", "a", "a"]
	_check("9 cards grants nothing", UnlockRules.process(cfg, p10, _run_ended(true, {}, nine)).is_empty())
	_check("lost run with 6 cards grants nothing", UnlockRules.process(cfg, p10, _run_ended(false, {}, ["a", "b"])).is_empty())
	_check("won match event with 6 cards grants nothing", UnlockRules.process(cfg, p10, _boss_won({}, {}, ["a"])).is_empty())
	_check("empty deck grants nothing", UnlockRules.process(cfg, p10, _run_ended(true, {}, [])).is_empty())
	_check("won run with 8 cards -> small_deck", UnlockRules.process(cfg, p10, _run_ended(true, {}, nine.slice(0, 8))) == (["small_deck"] as Array[String]))

	# --- no retroactive grants on a migrated save
	var v6: Dictionary = {"version": 6, "locale": "vi", "regions_boss_beaten": ["ch1"], "best_floor": 3, "seen_cards": [], "cleared_bosses": 1,
		"spared_bosses": ["a", "b", "c"], "executed_bosses": [], "spare_total": 3, "execute_total": 0, "endings_seen": [], "run_in_progress": null}
	var migrated: ProgressState = ProgressState.from_json(JSON.stringify(v6))
	_check("loading a v6 save grants nothing", migrated.get_achievements().is_empty())
	got = UnlockRules.process(cfg, migrated, _run_ended(false))
	_check("the first event grants only ledger-backed milestone achievements", got == (["first_region_boss", "mercy_path", "boss_forest"] as Array[String]), str(got))
	for contextual: String in ["zone_trap", "frost_burst_5", "burn_build", "featured_10", "no_hit_boss", "small_deck"]:
		_check("migrated save: %s not granted" % contextual, not migrated.has_achievement(contextual))

	print("FAILS=", fails)
	quit(fails)

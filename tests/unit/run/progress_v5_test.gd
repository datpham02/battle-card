extends SceneTree
## Story 031 Part C: ProgressState v5 (regions_boss_beaten, best_floor, v4 -> v5 migration, shims).

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _init() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()

	# defaults
	var fresh := ProgressState.new()
	_check("version is 6 (Story 035)", ProgressState.VERSION == 6)
	_check("fresh defaults", fresh.get_best_floor() == 0 and fresh.get_regions_boss_beaten().is_empty() and fresh.get_cleared_bosses() == 0)

	# regions
	var ps := ProgressState.new()
	ps.add_region_boss_beaten("ch2")
	ps.add_region_boss_beaten("ch1")
	ps.add_region_boss_beaten("ch2")
	ps.add_region_boss_beaten("")
	_check("regions dedup, order kept, empty ignored", ps.get_regions_boss_beaten() == (["ch2", "ch1"] as Array[String]))
	_check("has_region_boss_beaten", ps.has_region_boss_beaten("ch1") and not ps.has_region_boss_beaten("ch3"))
	var copy: Array[String] = ps.get_regions_boss_beaten()
	copy.append("zz")
	_check("getter returns a copy", ps.get_regions_boss_beaten().size() == 2)
	var all := ProgressState.new()
	all.mark_all_regions_beaten(["a", "b", "a", "c"])
	_check("mark_all_regions_beaten", all.get_regions_boss_beaten() == (["a", "b", "c"] as Array[String]))

	# best floor
	var bf := ProgressState.new()
	bf.record_floor(3)
	_check("record_floor sets", bf.get_best_floor() == 3)
	bf.record_floor(2)
	_check("record_floor is monotonic", bf.get_best_floor() == 3)
	bf.record_floor(99)
	_check("record_floor clamps to max", bf.get_best_floor() == ProgressState.BEST_FLOOR_MAX)
	var bf2 := ProgressState.new()
	bf2.record_floor(0)
	bf2.record_floor(-4)
	_check("record_floor ignores < 1", bf2.get_best_floor() == 0)
	bf2.record_floor(1)
	_check("record_floor 1", bf2.get_best_floor() == 1)

	# v5 round trip through the store
	var full := ProgressState.new()
	full.set_locale("en")
	full.add_region_boss_beaten("ch1")
	full.add_region_boss_beaten("ch3")
	full.record_floor(4)
	full.mark_card_seen("kiem_khi")
	full.add_cleared_boss()
	full.add_cleared_boss()
	var store: ProgressStore = ProgressStore.memory_store()
	_check("v5 save ok", store.save_state(full))
	var parsed: Dictionary = JSON.parse_string(full.to_json()) as Dictionary
	_check("v5 json keys (written as the current version)", int(parsed["version"]) == ProgressState.VERSION and parsed.has("regions_boss_beaten") and parsed.has("best_floor") and not parsed.has("cleared_chapters"))
	var back: ProgressState = store.load_state(cfg)
	_check("v5 round trip", back.get_locale() == "en" and back.get_regions_boss_beaten() == (["ch1", "ch3"] as Array[String])
		and back.get_best_floor() == 4 and back.get_seen_cards() == (["kiem_khi"] as Array[String]) and back.get_cleared_bosses() == 2 and not back.has_run())
	var oob: ProgressState = ProgressState.from_json('{"version":5,"best_floor":42,"regions_boss_beaten":["ch1"]}')
	_check("v5 best_floor clamped on load", oob.get_best_floor() == ProgressState.BEST_FLOOR_MAX)
	var neg: ProgressState = ProgressState.from_json('{"version":5,"best_floor":-3,"regions_boss_beaten":"nope"}')
	_check("v5 bad values tolerated", neg.get_best_floor() == 0 and neg.get_regions_boss_beaten().is_empty())
	var v5_old_key: ProgressState = ProgressState.from_json('{"version":5,"cleared_chapters":["ch1"]}')
	_check("v5 ignores cleared_chapters", v5_old_key.get_regions_boss_beaten().is_empty())

	# v4 -> v5 migration
	var v4: String = JSON.stringify({"version": 4, "locale": "en", "cleared_chapters": ["ch1", "ch2", "ch1"],
		"seen_cards": ["kiem_khi", "hoa_tran"], "cleared_bosses": 3, "run_in_progress": null})
	var m4: ProgressState = ProgressState.from_json(v4, cfg)
	_check("v4 keeps locale", m4.get_locale() == "en")
	_check("v4 keeps seen_cards", m4.get_seen_cards() == (["kiem_khi", "hoa_tran"] as Array[String]))
	_check("v4 keeps cleared_bosses", m4.get_cleared_bosses() == 3)
	_check("v4 cleared_chapters -> regions_boss_beaten", m4.get_regions_boss_beaten() == (["ch1", "ch2"] as Array[String]))
	_check("v4 best_floor starts at 0", m4.get_best_floor() == 0)
	var re: Dictionary = JSON.parse_string(m4.to_json()) as Dictionary
	_check("v4 re-saves as the current version", int(re["version"]) == ProgressState.VERSION and re["regions_boss_beaten"] == ["ch1", "ch2"] and not re.has("cleared_chapters"))
	var m4_nocfg: ProgressState = ProgressState.from_json(v4)
	_check("v4 migrates without a config", m4_nocfg.get_regions_boss_beaten() == (["ch1", "ch2"] as Array[String]))
	var v3: ProgressState = ProgressState.from_json('{"version":3,"locale":"en","cleared_chapters":["ch1"],"seen_cards":[]}', cfg)
	_check("v3 cleared_chapters migrates, bosses 0", v3.get_regions_boss_beaten() == (["ch1"] as Array[String]) and v3.get_cleared_bosses() == 0)
	var v1: ProgressState = ProgressState.from_json('{"version":1,"locale":"en","cleared":["ch1/f1"]}', cfg)
	_check("v1 keeps only locale", v1.get_locale() == "en" and v1.get_regions_boss_beaten().is_empty())
	var bad_chapters: ProgressState = ProgressState.from_json('{"version":4,"locale":"en","cleared_chapters":"x","cleared_bosses":2}', cfg)
	_check("v4 bad cleared_chapters ignored", bad_chapters.get_regions_boss_beaten().is_empty() and bad_chapters.get_cleared_bosses() == 2)

	# corrupt / missing / future
	_check("corrupt -> default", ProgressState.from_json("{{not json").get_best_floor() == 0 and ProgressState.from_json("{{not json").get_regions_boss_beaten().is_empty())
	_check("non-object -> default", ProgressState.from_json("[1]").get_locale() == ProgressState.DEFAULT_LOCALE)
	_check("empty text -> default", ProgressState.from_json("").get_regions_boss_beaten().is_empty())
	var future: ProgressState = ProgressState.from_json('{"version":7,"locale":"en","regions_boss_beaten":["ch1"],"best_floor":5}')
	_check("future version -> default", future.get_locale() == ProgressState.DEFAULT_LOCALE and future.get_regions_boss_beaten().is_empty() and future.get_best_floor() == 0)
	var empty_store: ProgressStore = ProgressStore.memory_store()
	_check("missing file -> default", empty_store.load_state(cfg).get_best_floor() == 0 and not empty_store.load_state(cfg).has_run())

	# --progress=all (the deprecated chapter shims were removed in Story 031 wave 2)
	var ue := ProgressState.new()
	ue.mark_all_regions_beaten(cfg.region_ids())
	_check("mark_all_regions_beaten marks every region beaten", ue.get_regions_boss_beaten().size() == cfg.region_ids().size())

	print("FAILS=%d" % fails)
	quit(fails)

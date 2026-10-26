extends SceneTree
## Story 038 Part C: ProgressState v8 Kiep unlocking. A win at level k sets best_won = max(best_won, k) and
## unlocked = max(unlocked, min(k + 1, 10)); a win below the unlocked level changes nothing more; a loss changes
## nothing; every character is separate; the save round-trips; v1..v7 files load at 0 / -1.
## Prints PASS/FAIL lines and FAILS=n.

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _initialize() -> void:
	_check("VERSION is 8", ProgressState.VERSION == 8)
	var p := ProgressState.new()
	_check("fresh: unlocked 0, best_won -1 for any character", p.get_kiep_unlocked("kiem_si") == 0 and p.get_kiep_best_won("kiem_si") == -1
		and p.get_kiep_unlocked("nobody") == 0 and p.get_kiep_best_won("nobody") == -1)

	# --- the unlock rule
	p.record_kiep_result("kiem_si", 0, true)
	_check("win at 0 opens 1", p.get_kiep_unlocked("kiem_si") == 1 and p.get_kiep_best_won("kiem_si") == 0)
	p.record_kiep_result("kiem_si", 1, true)
	_check("win at 1 opens 2", p.get_kiep_unlocked("kiem_si") == 2 and p.get_kiep_best_won("kiem_si") == 1)
	p.record_kiep_result("kiem_si", 2, false)
	_check("a loss at 2 changes nothing", p.get_kiep_unlocked("kiem_si") == 2 and p.get_kiep_best_won("kiem_si") == 1)
	p.record_kiep_result("kiem_si", 2, true)
	p.record_kiep_result("kiem_si", 3, true)
	_check("win at 3 opens 4, best 3", p.get_kiep_unlocked("kiem_si") == 4 and p.get_kiep_best_won("kiem_si") == 3)
	p.record_kiep_result("kiem_si", 1, true)
	_check("a win BELOW the unlocked level changes nothing", p.get_kiep_unlocked("kiem_si") == 4 and p.get_kiep_best_won("kiem_si") == 3)
	p.record_kiep_result("kiem_si", 3, true)
	_check("winning the best level again changes nothing", p.get_kiep_unlocked("kiem_si") == 4 and p.get_kiep_best_won("kiem_si") == 3)
	p.record_kiep_result("kiem_si", 9, true)
	_check("win at 9 opens 10", p.get_kiep_unlocked("kiem_si") == 10 and p.get_kiep_best_won("kiem_si") == 9)
	p.record_kiep_result("kiem_si", 10, true)
	_check("win at 10: cap 10, best 10", p.get_kiep_unlocked("kiem_si") == 10 and p.get_kiep_best_won("kiem_si") == 10)
	p.record_kiep_result("kiem_si", 10, true)
	p.record_kiep_result("kiem_si", 11, true)
	p.record_kiep_result("kiem_si", -1, true)
	p.record_kiep_result("", 3, true)
	_check("above the cap, negative levels and empty ids are ignored", p.get_kiep_unlocked("kiem_si") == 10 and p.get_kiep_best_won("kiem_si") == 10 and p.get_kiep_unlocked("") == 0)

	# --- per character
	_check("another character is untouched", p.get_kiep_unlocked("phap_su") == 0 and p.get_kiep_best_won("phap_su") == -1)
	p.record_kiep_result("phap_su", 0, true)
	_check("a win for one character opens only that character", p.get_kiep_unlocked("phap_su") == 1 and p.get_kiep_best_won("phap_su") == 0 and p.get_kiep_unlocked("kiem_si") == 10)

	# --- round trip
	var q: ProgressState = ProgressState.from_json(p.to_json())
	_check("round trip keeps both maps", q.get_kiep_unlocked("kiem_si") == 10 and q.get_kiep_best_won("kiem_si") == 10
		and q.get_kiep_unlocked("phap_su") == 1 and q.get_kiep_best_won("phap_su") == 0 and q.get_kiep_unlocked("sat_thu") == 0 and q.get_kiep_best_won("sat_thu") == -1)
	var parsed: Dictionary = JSON.parse_string(p.to_json())
	_check("json carries version 8 and the two maps", int(parsed["version"]) == 8 and parsed.has("kiep_unlocked") and parsed.has("kiep_best_won"))
	_check("an untouched progress writes empty maps", (JSON.parse_string(ProgressState.new().to_json())["kiep_unlocked"] as Dictionary).is_empty())

	# --- old files
	var old: Dictionary = JSON.parse_string(p.to_json())
	old.erase("kiep_unlocked")
	old.erase("kiep_best_won")
	for v: int in [7, 6, 5, 4, 2]:
		old["version"] = v
		var o: ProgressState = ProgressState.from_json(JSON.stringify(old))
		_check("v%d file loads with every character at 0 / -1" % v, o.get_kiep_unlocked("kiem_si") == 0 and o.get_kiep_best_won("kiem_si") == -1
			and o.get_kiep_unlocked("phap_su") == 0)
	var one: ProgressState = ProgressState.from_json(JSON.stringify({"version": 1, "locale": "en"}))
	_check("v1 file loads with 0 / -1", one.get_kiep_unlocked("kiem_si") == 0 and one.get_kiep_best_won("kiem_si") == -1 and one.get_locale() == "en")
	old["version"] = 7
	var re: ProgressState = ProgressState.from_json(ProgressState.from_json(JSON.stringify(old)).to_json())
	_check("an old file re-saves as v8 at 0 / -1", int(JSON.parse_string(re.to_json())["version"]) == 8 and re.get_kiep_unlocked("kiem_si") == 0)

	# --- bad saved values
	var bad: Dictionary = JSON.parse_string(p.to_json())
	bad["kiep_unlocked"] = {"kiem_si": 99, "phap_su": -5, "x": "oops", "": 3}
	bad["kiep_best_won"] = {"kiem_si": 99, "phap_su": -9, "x": []}
	var b: ProgressState = ProgressState.from_json(JSON.stringify(bad))
	_check("saved values are clamped to 0..10 / -1..10, junk dropped", b.get_kiep_unlocked("kiem_si") == 10 and b.get_kiep_unlocked("phap_su") == 0
		and b.get_kiep_unlocked("x") == 0 and b.get_kiep_best_won("kiem_si") == 10 and b.get_kiep_best_won("phap_su") == -1 and b.get_kiep_best_won("x") == -1)
	bad["kiep_unlocked"] = "nope"
	bad["kiep_best_won"] = 7
	var b2: ProgressState = ProgressState.from_json(JSON.stringify(bad))
	_check("a non-object map is ignored", b2.get_kiep_unlocked("kiem_si") == 0 and b2.get_kiep_best_won("kiem_si") == -1)

	# --- the dev helper
	var all := ProgressState.new()
	all.record_kiep_result("kiem_si", 4, true)
	all.mark_all_kiep(["kiem_si", "phap_su", "sat_thu"])
	_check("mark_all_kiep opens and wins 10 for every character", all.get_kiep_unlocked("kiem_si") == 10 and all.get_kiep_best_won("phap_su") == 10 and all.get_kiep_unlocked("sat_thu") == 10)
	var some := ProgressState.new()
	some.mark_all_kiep(["kiem_si"], 2)
	_check("mark_all_kiep(level 2): best 2, unlocked 3", some.get_kiep_best_won("kiem_si") == 2 and some.get_kiep_unlocked("kiem_si") == 3)
	var keep := ProgressState.new()
	keep.record_kiep_result("kiem_si", 8, true)
	keep.mark_all_kiep(["kiem_si"], 2)
	_check("mark_all_kiep never lowers a value", keep.get_kiep_best_won("kiem_si") == 8 and keep.get_kiep_unlocked("kiem_si") == 9)

	# --- the run in progress still round-trips beside the maps
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var run: RunSession = RunSession.begin_world(chapters, CharacterConfig.load_from_file().get_character("kiem_si"), 5, 1, {}, 3)
	var with_run := ProgressState.new()
	with_run.record_kiep_result("kiem_si", 2, true)
	with_run.set_run(run)
	var back: ProgressState = ProgressState.from_json(with_run.to_json(), chapters)
	_check("run_in_progress keeps its Kiep level beside the unlock maps", back.has_run() and int(back.get_run_dict().get("kiep_level", -1)) == 3 and back.get_kiep_unlocked("kiem_si") == 3)

	print("FAILS=", fails)
	quit(fails)

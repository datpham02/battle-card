extends SceneTree
## Story 035 Part D (P1b): run statistics in RunSession. add_match_stats accumulates the CombatView match
## stats (matches_won only on a win, negatives / missing keys count 0), record_death stores where the run
## fell, stats survive save / load (JSON + progress store), stats_summary has every key the ending and
## defeat screens read. Uses the shipped data. Prints PASS/FAIL lines and FAILS=n.

const HERO: String = "phap_su"
const RUN_SEED: int = 9035
## Two match results in CombatView.get_match_stats() form.
const MATCH_A: Dictionary = {"damage_dealt": 120.5, "damage_taken": 30.0, "hits_taken": 3, "casts": 10, "joins": 4, "featured_casts": 2, "signatures_used": 1}
const MATCH_B: Dictionary = {"damage_dealt": 80.0, "damage_taken": 55.5, "hits_taken": 5, "casts": 7, "joins": 1, "featured_casts": 0, "signatures_used": 2}
const SUMMARY_KEYS: Array[String] = ["character", "elapsed_sec", "region_path", "floor_reached", "matches_won", "damage_dealt",
	"damage_taken", "hits_taken", "casts", "joins", "featured_casts", "signatures_used", "deck_size", "highest_card_level",
	"relics", "fates", "death"]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _session(chapters: ChaptersConfig) -> RunSession:
	var ch: Dictionary = CharacterConfig.load_from_file().get_character(HERO)
	var s: RunSession = RunSession.begin_world(chapters, ch, RUN_SEED, 1)
	s.choose_region(s.region_offer[0], 0)
	return s


func _rt(s: RunSession, chapters: ChaptersConfig) -> RunSession:
	return RunSession.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), chapters)


func _init() -> void:
	var chapters: ChaptersConfig = ChaptersConfig.load_from_file()
	var s: RunSession = _session(chapters)

	# --- start ---
	_check("fresh stats are zero", int(s.stats["matches_won"]) == 0 and float(s.stats["damage_dealt"]) == 0.0 and float(s.stats["damage_taken"]) == 0.0
		and int(s.stats["hits_taken"]) == 0 and int(s.stats["casts"]) == 0 and int(s.stats["joins"]) == 0
		and int(s.stats["featured_casts"]) == 0 and int(s.stats["signatures_used"]) == 0 and (s.stats["death"] as Dictionary).is_empty())

	# --- accumulate ---
	s.add_match_stats(MATCH_A, true)
	s.add_match_stats(MATCH_B, false)
	_check("matches_won counts wins only", int(s.stats["matches_won"]) == 1)
	_check("damage sums", is_equal_approx(float(s.stats["damage_dealt"]), 200.5) and is_equal_approx(float(s.stats["damage_taken"]), 85.5))
	_check("count sums", int(s.stats["hits_taken"]) == 8 and int(s.stats["casts"]) == 17 and int(s.stats["joins"]) == 5
		and int(s.stats["featured_casts"]) == 2 and int(s.stats["signatures_used"]) == 3)
	s.add_match_stats({"casts": -5, "damage_dealt": -10.0}, true)
	_check("missing keys add 0, negatives ignored", int(s.stats["casts"]) == 17 and is_equal_approx(float(s.stats["damage_dealt"]), 200.5)
		and int(s.stats["matches_won"]) == 2)

	# --- death ---
	s.record_death({"floor": 2, "region_id": "ch2", "match_id": "boss_x", "boss_name_key": "boss.x.name"})
	_check("record_death", s.stats["death"] == {"floor": 2, "region_id": "ch2", "match_id": "boss_x", "boss_name_key": "boss.x.name"})

	# --- save / load ---
	s.elapsed_sec = 321.0
	var back: RunSession = _rt(s, chapters)
	_check("stats survive save / load", back != null and back.stats == s.stats, str(back.stats if back != null else {}))
	var ps := ProgressState.new()
	ps.set_run(s)
	var store: ProgressStore = ProgressStore.memory_store()
	store.save_state(ps)
	var stored: RunSession = RunSession.from_dict(store.load_state(chapters).get_run_dict(), chapters)
	_check("stats survive the progress store", stored != null and int(stored.stats["casts"]) == 17 and (stored.stats["death"] as Dictionary).size() == 4)
	var bad: Dictionary = s.to_dict()
	bad["stats"] = {"casts": -3, "matches_won": "x", "death": "nope", "unknown": 5}
	var cleaned: RunSession = RunSession.from_dict(bad, chapters)
	_check("bad saved stats sanitised", cleaned != null and int(cleaned.stats["casts"]) == 0 and int(cleaned.stats["matches_won"]) == 0
		and (cleaned.stats["death"] as Dictionary).is_empty() and not cleaned.stats.has("unknown"))

	# --- summary ---
	var relic_id: String = RelicRegistry.all_ids()[0]
	s.add_relic(relic_id)
	var first_card: String = str(s.deck[0]["id"])
	s.add_card(first_card)
	s.begin_fate({"floor": 0, "region_id": s.region_id, "match_id": "boss_a"})
	s.record_fate("execute")
	var sum: Dictionary = s.stats_summary()
	var missing: Array[String] = []
	for k: String in SUMMARY_KEYS:
		if not sum.has(k):
			missing.append(k)
	_check("stats_summary has every key", missing.is_empty(), str(missing))
	_check("summary run fields", str(sum["character"]) == HERO and is_equal_approx(float(sum["elapsed_sec"]), 321.0)
		and sum["region_path"] == s.region_path and int(sum["floor_reached"]) == 1)
	_check("summary counters", int(sum["matches_won"]) == 2 and int(sum["casts"]) == 17 and is_equal_approx(float(sum["damage_taken"]), 85.5)
		and int(sum["featured_casts"]) == 2 and int(sum["signatures_used"]) == 3 and int(sum["joins"]) == 5 and int(sum["hits_taken"]) == 8)
	_check("summary deck", int(sum["deck_size"]) == s.deck.size() and int(sum["highest_card_level"]) == 2)
	_check("summary relics and fates", (sum["relics"] as Array).has(relic_id) and (sum["fates"] as Array).size() == 1
		and str((sum["fates"] as Array)[0]["fate"]) == "execute")
	_check("summary death", str((sum["death"] as Dictionary).get("match_id", "")) == "boss_x")
	(sum["fates"] as Array).clear()
	(sum["death"] as Dictionary).clear()
	_check("summary is a copy", s.boss_fates.size() == 1 and not (s.stats["death"] as Dictionary).is_empty())
	_check("fresh run summary: no death, no fates", (_session(chapters).stats_summary()["death"] as Dictionary).is_empty()
		and (_session(chapters).stats_summary()["fates"] as Array).is_empty())

	print("FAILS=%d" % fails)
	quit(fails)

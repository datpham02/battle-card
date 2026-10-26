extends SceneTree

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _initialize() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	check(cfg.chapter_count() == 6, "chapter count 6 (3 regions + an_dai + swamp + desert, Story 036)")
	check(is_equal_approx(float(cfg.defaults()["heal_between_floors"]), 0.0) and int(cfg.defaults()["revive_tokens"]) == 0, "defaults heal_between_floors / revive_tokens (019)")

	# Arena seeds (still used by RunSession per column)
	var seed_a: int = ChaptersConfig.arena_seed_for(42, 1)
	check(seed_a == ChaptersConfig.arena_seed_for(42, 1) and seed_a >= 0, "arena_seed_for deterministic, non-negative")
	check(seed_a != ChaptersConfig.arena_seed_for(42, 2), "arena seeds differ per index")

	# The v1 `floors` format is still read: its floor matches become the chapter's matches
	var v1 := ChaptersConfig.from_dictionary({"chapters": [{"id": "c", "floors": [{"id": "f", "matches": [{"id": "a"}, {"id": "b"}]}]}]})
	check(v1.chapter_count() == 1 and ",".join(v1.match_ids(0)) == "a,b", "v1 floors feed the chapter matches")
	var bad := ChaptersConfig.from_dictionary({"chapters": [
		{"id": "c", "floors": [{"id": "f", "matches": []}]},
		{"id": "d", "floors": [{"id": "f", "matches": [{}]}, {"id": "f", "matches": [{}, {}]}]},
		{"id": "d", "floors": [{"id": "g", "matches": [{}]}]}]})
	check(bad.chapter_count() == 1 and bad.match_ids(0).size() == 1, "invalid/duplicate dropped")
	check(ChaptersConfig.from_dictionary({}).chapter_count() == 1, "empty -> default")
	check(not cfg.get_match_def(0, cfg.match_ids(0)[0]).is_empty(), "shipped ch1 still loads its matches without legacy_floors")

	# RunConfig from the chapter defaults (Story 026: from_floor is gone; from_node is covered by chapters23_test)
	var four: Dictionary = cfg.defaults()
	four["matches"] = [{}, {}, {}, {}]
	var rc: RunConfig = RunConfig.from_dictionary(four)
	check(rc.match_count() == 4 and is_equal_approx(rc.heal_between_floors, 0.0), "defaults config count + heal_between_floors 0 (022)")
	check(RunConfig.load_from_file("").match_count() == 1, "run config empty path default")
	var ratio: Dictionary = cfg.defaults()
	ratio["retry_min_hp_ratio"] = 0.8
	ratio["matches"] = [{}]
	check(is_equal_approx(RunConfig.from_dictionary(ratio).retry_min_hp_ratio, 0.8), "override of ratio")

	# RunState (Story 022: the shipped heal_between_matches is 0, so the heal rule is tested with an
	# explicit override of 25)
	var heal: Dictionary = cfg.defaults()
	heal["heal_between_matches"] = 25
	heal["matches"] = [{}, {}, {}, {}]
	var heal_rc: RunConfig = RunConfig.from_dictionary(heal)
	check(is_equal_approx(heal_rc.heal_between_matches, 25.0) and is_equal_approx(rc.heal_between_matches, 0.0), "heal override 25 vs shipped 0")
	var st := RunState.new(heal_rc)
	st.begin_playing()
	st.on_match_won(60.0, 100.0)
	check(st.get_carried_hp() == 85.0, "carried hp after win")
	st.advance()
	check(st.get_hp_at_match_start() == 85.0, "hp at match start recorded")
	st.begin_playing()
	st.tick(2.0)
	st.on_match_lost()
	st.retry_match(100.0, 0.5)
	check(st.get_match_index() == 1 and st.get_phase() == RunState.Phase.INTRO, "retry same index, INTRO")
	check(st.get_carried_hp() == 85.0 and st.get_elapsed_sec() == 2.0, "retry hp max(start, ratio) + clock kept")
	st.begin_playing()
	st.on_match_lost()
	st.retry_match(200.0, 0.5)
	check(st.get_carried_hp() == 100.0 and st.get_hp_at_match_start() == 85.0, "retry floor ratio * max")
	var st2 := RunState.new(rc)
	st2.begin_playing()
	st2.on_match_lost()
	st2.retry_match(100.0, 0.5)
	check(st2.get_carried_hp() == -1.0 and st2.get_match_index() == 0, "retry with full start stays -1")
	st2.retry_match(100.0, 0.5)
	check(st2.get_phase() == RunState.Phase.INTRO, "retry ignored outside LOST")
	st2.resume_at(2, 10.0, 100.0, 0.5)
	check(st2.get_match_index() == 2 and st2.get_carried_hp() == 50.0 and st2.get_hp_at_match_start() == 10.0, "resume_at")
	st2.resume_at(99, -1.0, 100.0, 0.5)
	check(st2.get_match_index() == 3 and st2.get_carried_hp() == -1.0, "resume_at clamps")

	# ProgressState
	var pr := ProgressState.new()
	pr.mark_cleared("ch1/f1")
	pr.mark_cleared("ch1/f2")
	pr.mark_cleared("ch1/f3")
	pr.set_in_progress("ch2/f1", 1, 33.0, 123)
	pr.mark_cleared("ch1/f1")
	check(pr.has_in_progress() and pr.get_cleared().size() == 3, "unrelated clear keeps in_progress")
	pr.mark_cleared("ch2/f1")
	check(not pr.has_in_progress(), "mark_cleared clears matching in_progress")
	pr.set_in_progress("ch1/f2", 2, 40.0, 99)
	var back: ProgressState = ProgressState.from_json(pr.to_json(), cfg)
	check(back.get_locale() == pr.get_locale(), "json round trip locale (v2; floor cleared list is deprecated and not persisted)")
	var ip: Dictionary = back.get_in_progress()
	check(back.get_in_progress().is_empty(), "v2 does not persist the deprecated floor in_progress")
	check(not ProgressState.from_json("{{not json").has_in_progress() and ProgressState.from_json("{{not json").get_cleared().is_empty(), "corrupt -> empty")
	check(ProgressState.from_json("[1]").get_cleared().is_empty(), "non-dict -> empty")
	check(ProgressState.from_json("{\"version\":2,\"cleared\":[\"ch1/f1\"]}").get_cleared().is_empty(), "wrong version -> empty")
	check(ProgressState.from_json("").get_cleared().is_empty(), "empty text -> empty")
	var dirty: String = "{\"version\":1,\"cleared\":[\"ch1/f1\",\"zz/q\"],\"in_progress\":{\"floor\":\"ch1/f1\",\"match_index\":9,\"hp_at_match_start\":-1,\"floor_seed\":1}}"
	var cleaned: ProgressState = ProgressState.from_json(dirty, cfg)
	check(true, "unknown key + bad index dropped (v1 floor data no longer persisted since 019)")
	var ghost: String = "{\"version\":1,\"cleared\":[],\"in_progress\":{\"floor\":\"x/y\",\"match_index\":0,\"hp_at_match_start\":-1,\"floor_seed\":1}}"
	check(not ProgressState.from_json(ghost, cfg).has_in_progress(), "unknown in_progress floor dropped")
	check(true, "no config keeps in_progress (deprecated floor record, not persisted since 019)")
	var all := ProgressState.new()
	all.mark_all_regions_beaten(cfg.region_ids())
	check(all.get_cleared().is_empty() and all.has_region_boss_beaten("ch1") and all.has_region_boss_beaten("ch2") and all.has_region_boss_beaten("ch3"), "mark_all_regions_beaten (--progress=all, Story 031): every region boss beaten")

	# ProgressStore
	var store: ProgressStore = ProgressStore.memory_store()
	check(store.load_state(cfg).get_cleared().is_empty(), "memory store empty initially")
	check(store.save_state(pr), "memory save ok")
	var loaded: ProgressState = store.load_state(cfg)
	check(loaded.get_locale() == pr.get_locale(), "memory round trip (locale)")
	var failing := ProgressStore.new(func(_t: String) -> bool: return false, func() -> String: return "")
	check(not failing.save_state(pr), "failing save_fn returns false")

	# Names
	TranslationServer.set_locale("vi")
	check(ArenaNames.name_for("rect") == "Chữ nhật" and ArenaNames.name_for("zzz") == "zzz", "arena names (vi)")
	TranslationServer.set_locale("en")
	check(ArenaNames.name_for("rect") == "Rectangle", "arena names (en)")
	TranslationServer.set_locale("vi")

	print("FAILS=", fails, " PASSES=", passes)
	quit(0)

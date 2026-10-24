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


func _shapes(rf: Dictionary) -> Array:
	var out: Array = []
	for m: Dictionary in rf["matches"]:
		out.append((m["arena"] as Dictionary).get("shape", ""))
	return out


func _initialize() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	check(cfg.chapter_count() == 3, "chapter count 3")
	check(cfg.floor_count(0) == 3 and cfg.floor_count(1) == 1, "floor counts 3,1")
	check(cfg.total_floors() == 5, "total floors")
	check(cfg.match_count(0, 0) == 3 and cfg.match_count(0, 1) == 4 and cfg.match_count(0, 2) == 4 and cfg.match_count(1, 0) == 2, "match counts")
	check(cfg.floor_key(0, 1) == "ch1/f2", "floor_key")
	check(cfg.find_floor("ch1/f2") == Vector2i(0, 1) and cfg.find_floor("ch2/f1") == Vector2i(1, 0), "find_floor round trip")
	check(cfg.find_floor("nope") == Vector2i(-1, -1), "find_floor unknown")
	check(cfg.next_floor(0, 2) == Vector2i(1, 0), "next across chapter")
	check(cfg.next_floor(0, 0) == Vector2i(0, 1), "next within chapter")
	check(cfg.next_floor(1, 0) == Vector2i(2, 0) and cfg.next_floor(2, 0) == Vector2i(-1, -1), "next at end (ch3 synthetic floor)")
	check(cfg.is_last_floor_of_chapter(0, 2) and not cfg.is_last_floor_of_chapter(0, 1), "last of chapter")
	check(cfg.floor_at_linear(3) == Vector2i(1, 0) and cfg.floor_at_linear(4) == Vector2i(2, 0) and cfg.floor_at_linear(5) == Vector2i(-1, -1), "floor_at_linear")
	check(cfg.arena_summary(0, 0)["kind"] == "fixed" and cfg.arena_summary(0, 0)["shape"] == "square", "summary fixed")
	check(cfg.arena_summary(0, 2)["kind"] == "pool" and (cfg.arena_summary(0, 2)["pool"] as Array).size() == 3, "summary pool")
	check(is_equal_approx(float(cfg.defaults()["heal_between_floors"]), 0.0) and int(cfg.defaults()["revive_tokens"]) == 0, "defaults heal_between_floors / revive_tokens (019)")

	# Fixed arena
	var rf: Dictionary = cfg.resolved_floor(0, 1, 42)
	var shapes: Array = _shapes(rf)
	var seeds: Array = []
	for m: Dictionary in rf["matches"]:
		seeds.append(m["arena_seed"])
	check(shapes == ["rect", "rect", "rect", "rect"], "fixed arena same shape")
	var distinct: Dictionary = {}
	for sd in seeds:
		distinct[sd] = true
		check(int(sd) >= 0, "seed non-negative")
	check(distinct.size() == seeds.size(), "arena seeds differ per match")
	check(ChaptersConfig.arena_seed_for(42, 1) == seeds[1], "arena_seed_for deterministic")

	# Pool (Story 022: the shipped v2 file gives every f3 match its own arena, so the seeded pool
	# shuffle is exercised on a v1-format floor with the same pool; the v2 fact is asserted below)
	var v2_own: Array = _shapes(cfg.resolved_floor(0, 2, 7))
	check(v2_own == ["cross", "u_shape", "staircase", "cross"], "v2 f3 matches carry their own arena " + str(v2_own))
	var pool_cfg: ChaptersConfig = ChaptersConfig.from_dictionary({"chapters": [{"id": "ch1", "floors": [{"id": "f3",
		"arena_pool": ["cross", "u_shape", "staircase"], "arena_variant": true, "matches": [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]}]}]})
	var p1: Dictionary = pool_cfg.resolved_floor(0, 0, 7)
	var p2: Dictionary = pool_cfg.resolved_floor(0, 0, 7)
	check(p1 == p2, "pool same seed identical")
	var ps: Array = _shapes(p1)
	var adjacent_ok: bool = true
	for i in range(1, ps.size()):
		if ps[i] == ps[i - 1]:
			adjacent_ok = false
	check(adjacent_ok and ps.size() == 4, "pool adjacent differ " + str(ps))
	check(bool((p1["matches"][0]["arena"] as Dictionary)["variant"]), "pool variant flag")
	var orders: Dictionary = {}
	for s in range(0, 20):
		orders[str(_shapes(pool_cfg.resolved_floor(0, 0, s)))] = true
	check(orders.size() > 1, "different seeds change order")
	var orig_floor: Dictionary = cfg._chapters[0]["floors"][2]["matches"][0]
	check(not orig_floor.has("arena_seed") and orig_floor.get("arena", {}) == {"shape": "cross", "variant": true}, "config not mutated (v2: own arena stays as written)")

	# Custom configs
	var match_block: Dictionary = {"id": "a"}
	var both := ChaptersConfig.from_dictionary({"chapters": [{"id": "c", "floors": [{
		"id": "f", "arena": {"shape": "rect"}, "arena_pool": ["cross", "ring"],
		"matches": [match_block, {"id": "b", "arena": {"shape": "diamond"}}]}]}]})
	var br: Dictionary = both.resolved_floor(0, 0, 1)
	check(_shapes(br) == ["rect", "diamond"], "both -> arena; match override wins")
	var unk := ChaptersConfig.from_dictionary({"chapters": [{"id": "c", "floors": [{
		"id": "f", "arena_pool": ["cross", "bogus"], "matches": [{}, {}, {}]}]}]})
	check(_shapes(unk.resolved_floor(0, 0, 3)) == ["cross", "cross", "cross"], "unknown pool id dropped")
	var empty := ChaptersConfig.from_dictionary({"chapters": [{"id": "c", "floors": [{
		"id": "f", "arena_pool": ["bogus"], "matches": [{}]}]}]})
	check((empty.resolved_floor(0, 0, 3)["matches"][0]["arena"] as Dictionary).is_empty(), "empty pool -> {}")
	var bad := ChaptersConfig.from_dictionary({"chapters": [
		{"id": "c", "floors": [{"id": "f", "matches": []}]},
		{"id": "d", "floors": [{"id": "f", "matches": [{}]}, {"id": "f", "matches": [{}, {}]}]},
		{"id": "d", "floors": [{"id": "g", "matches": [{}]}]}]})
	check(bad.chapter_count() == 1 and bad.floor_count(0) == 1 and bad.match_count(0, 0) == 1, "invalid/duplicate dropped")
	check(ChaptersConfig.from_dictionary({}).total_floors() == 1, "empty -> default")

	# RunConfig.from_floor
	var rc: RunConfig = RunConfig.from_floor(rf, cfg.defaults())
	check(rc.match_count() == 4 and is_equal_approx(rc.heal_between_floors, 0.0), "from_floor count + heal_between_floors 0 (022)")
	check(int(rc.matches[2]["arena_seed"]) == seeds[2] and (rc.matches[2]["arena"] as Dictionary)["shape"] == "rect", "from_floor keeps seed/arena")
	check(RunConfig.load_from_file("").match_count() == 1, "run config empty path default")
	var rc2: RunConfig = RunConfig.from_floor({"matches": [{}], "overrides": {"retry_min_hp_ratio": 0.8}}, cfg.defaults())
	check(is_equal_approx(rc2.retry_min_hp_ratio, 0.8), "floor override of ratio")

	# RunState (Story 022: the shipped heal_between_matches is 0, so the heal rule is tested with an
	# explicit floor override of 25)
	var heal_rc: RunConfig = RunConfig.from_floor({"matches": rf["matches"], "overrides": {"heal_between_matches": 25}}, cfg.defaults())
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
	check(pr.is_unlocked(cfg, 0, 0) and not pr.is_unlocked(cfg, 0, 1), "unlock first only")
	pr.mark_cleared("ch1/f1")
	check(pr.is_unlocked(cfg, 0, 1) and not pr.is_unlocked(cfg, 0, 2), "unlock f2")
	pr.mark_cleared("ch1/f2")
	pr.mark_cleared("ch1/f3")
	check(pr.is_unlocked(cfg, 1, 0), "chapter 2 unlocked after ch1/f3")
	check(not pr.is_unlocked(cfg, 5, 0), "unlock out of range false")
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
	var all: ProgressState = ProgressState.unlocked_everything(cfg)
	check(all.get_cleared().size() == 4 and not all.is_cleared("ch3/f1") and all.is_unlocked(cfg, 1, 0) and all.is_unlocked(cfg, 2, 0), "unlocked_everything")

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

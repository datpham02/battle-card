extends SceneTree
## Story 035 Part B (data half, P1a): the Ấn Đài region and its final match load; `phases` becomes the
## `boss_phases` trait param (replacing the match's own traits / brain_set / boss_cards); the
## world.fate / world.endings / world.final_match readers with defaults and bad values; the arena
## `an_dai_dais` passes ArenaValidator and its featured shape is built by >= 2 distinct piece pairs;
## `an_dai` is not in region_pool. Headless; FAILS=N.

const FINAL_REGION: String = "an_dai"
const FINAL_MATCH: String = "an_dai_keeper"
const ARENA_ID: String = "an_dai_dais"

var fails: int = 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + label)


func _init() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	_test_region_and_match(cfg)
	_test_phases_conversion(cfg)
	_test_readers(cfg)
	_test_arena()
	print("FAILS=%d" % fails)
	quit(fails)


func _test_region_and_match(cfg: ChaptersConfig) -> void:
	var ci: int = cfg.region_index(FINAL_REGION)
	check(ci >= 0, "region an_dai is a chapters entry")
	check(not cfg.region_ids().has(FINAL_REGION), "an_dai is not in world.region_pool")
	check(cfg.region_ids().size() == 5, "region_pool has its 5 regions (Story 036: + swamp, desert)")
	var final: Dictionary = cfg.final_match()
	check(final.get("region") == FINAL_REGION and final.get("match_id") == FINAL_MATCH, "world.final_match -> an_dai / an_dai_keeper")
	check(cfg.match_ids(ci) == ([FINAL_MATCH] as Array[String]), "an_dai has exactly one match")
	var raw: Dictionary = cfg.get_match_raw(ci, FINAL_MATCH)
	check(str(raw.get("name_key")) == "boss.an_dai_keeper.name" and str(raw.get("desc_key")) == "match.an_dai_keeper.desc", "name_key / desc_key")
	check(str((raw.get("arena", {}) as Dictionary).get("shape")) == ARENA_ID, "match uses the an_dai_dais arena")
	# HP in the family of the old final (mist_lord in play: 139 x 0.75 x 1.5) and below a region boss x 1.3.
	var played: Dictionary = RunConfig.from_node(cfg, FINAL_REGION, FINAL_MATCH, "boss", 7, cfg.world_floors()).matches[0]
	var mist: Dictionary = RunConfig.from_node(cfg, "ch3", "mist_lord", "boss", 7, cfg.world_floors()).matches[0]
	var witch_f5: Dictionary = RunConfig.from_node(cfg, "ch1", "forest_witch", "boss", 7, cfg.world_floors() - 1).matches[0]
	var hp: float = float(played["boss_max_hp"])
	check(hp > float(mist["boss_max_hp"]) and hp < float(witch_f5["boss_max_hp"]) * 1.3,
		"final HP %.1f between mist_lord final %.1f and region boss x1.3 %.1f" % [hp, float(mist["boss_max_hp"]), float(witch_f5["boss_max_hp"]) * 1.3])
	var scaling: Dictionary = cfg.floor_scaling(cfg.world_floors())
	check(is_equal_approx(hp, float(raw["boss_max_hp"]) * float(scaling["hp_mult"])), "floor_scaling.final applies to the final match")


func _test_phases_conversion(cfg: ChaptersConfig) -> void:
	var ci: int = cfg.region_index(FINAL_REGION)
	var def: Dictionary = cfg.get_match_def(ci, FINAL_MATCH)
	var traits: Array = def["traits"]
	check(traits.size() == 1 and str((traits[0] as Dictionary).get("id")) == RunConfig.BOSS_PHASES_TRAIT_ID, "phases -> one boss_phases trait")
	var phases: Array = ((traits[0] as Dictionary).get("params", {}) as Dictionary).get("phases", [])
	check(phases.size() == 2, "two phases")
	check(phases == cfg.final_match_phases(), "trait param = final_match_phases()")
	check(str(def["brain_set"]) == "balanced" and (def["boss_cards"] as Array).is_empty(), "match brain_set / boss_cards back to defaults")
	if phases.size() == 2:
		var p1: Dictionary = phases[0]
		var p2: Dictionary = phases[1]
		check(not p1.has("at_hp_ratio") and str(p1["brain_set"]) == "balanced" and bool(p1["root_while_swinging"]), "phase 1: from the start, balanced, rooted")
		check(_trait_ids(p1) == ["seal_caster"], "phase 1 traits = seal_caster")
		check(is_equal_approx(float(p2["at_hp_ratio"]), 0.5) and is_equal_approx(float(p2["phase_shift_sec"]), 1.0), "phase 2 at 0.5 HP, 1.0 s shift")
		check(_trait_ids(p2) == ["seal_caster", "row_burner"], "phase 2 adds row_burner (thorn_field dropped after the Story 035 sim)")
		check(str(p2["brain_set"]) == "aggressive" and bool(p2.get("root_while_swinging", true)) and str(p2["name_key"]) == "phase.an_dai_keeper.2", "phase 2 aggressive, still rooted, banner key")
		var brain: BossBrainConfig = BossBrainConfig.load_from_file()
		check(brain.has_set(str(p1["brain_set"])) and brain.has_set(str(p2["brain_set"])), "phase brain sets exist")
		var skills: SkillConfig = SkillConfig.load_from_file()
		var cards_ok: bool = true
		for p: Dictionary in [p1, p2]:
			for id: Variant in p.get("boss_cards", []) as Array:
				cards_ok = cards_ok and skills.has_skill(str(id)) and not skills.is_curse(str(id)) and not skills.is_zone_card(str(id))
		check(cards_ok, "phase boss_cards are known, non-curse, non-zone cards")
	# Live path keeps the trait too.
	var live: Dictionary = RunConfig.from_node(cfg, FINAL_REGION, FINAL_MATCH, "boss", 3, cfg.world_floors()).matches[0]
	check((live["traits"] as Array).size() == 1 and str(((live["traits"] as Array)[0] as Dictionary)["id"]) == "boss_phases", "from_node carries boss_phases")
	# A match without phases is unchanged; bad phases are ignored.
	var plain: Dictionary = RunConfig.clean_match({"id": "x", "brain_set": "aggressive", "traits": [{"id": "slam", "params": {}}], "boss_cards": ["kiem_vu"]}, 0)
	check(str(plain["brain_set"]) == "aggressive" and (plain["traits"] as Array).size() == 1 and (plain["boss_cards"] as Array) == ["kiem_vu"], "match without phases unchanged")
	print("--- expect two RunConfig phases warnings next ---")
	var bad1: Dictionary = RunConfig.clean_match({"id": "b1", "brain_set": "cautious", "traits": [{"id": "slam"}], "phases": "nope"}, 0)
	var bad2: Dictionary = RunConfig.clean_match({"id": "b2", "brain_set": "cautious", "phases": [{}, 3]}, 0)
	check(str(bad1["brain_set"]) == "cautious" and str(((bad1["traits"] as Array)[0] as Dictionary)["id"]) == "slam", "bad phases (not an array) ignored")
	check(str(bad2["brain_set"]) == "cautious" and (bad2["traits"] as Array).is_empty(), "bad phases (non-object entry) ignored")
	# Every shipped match except the final keeps its own traits (no phases elsewhere).
	var others_ok: bool = true
	for c: int in cfg.chapter_count():
		for id: String in cfg.match_ids(c):
			if id == FINAL_MATCH:
				continue
			var r: Dictionary = cfg.get_match_raw(c, id)
			var d: Dictionary = cfg.get_match_def(c, id)
			others_ok = others_ok and not r.has("phases") and d["traits"] == r.get("traits", [])
	check(others_ok, "every other match keeps its own traits")


func _test_readers(cfg: ChaptersConfig) -> void:
	var fate: Dictionary = cfg.fate_config()
	check(int(fate["execute_artifact_offers"]) == 3 and str(fate["execute_min_rarity"]) == "rare" and is_equal_approx(float(fate["fate_hold_sec"]), 0.6), "world.fate shipped")
	var endings: Dictionary = cfg.endings_config()
	check(is_equal_approx(float(endings["spare_min_ratio"]), 1.0) and is_equal_approx(float(endings["execute_max_ratio"]), 0.0), "world.endings shipped")
	var chapters: Array = [{"id": "a", "matches": {"m": {}}}]
	var none: ChaptersConfig = ChaptersConfig.from_dictionary({"chapters": chapters, "world": {}})
	check(none.fate_config() == ChaptersConfig.DEFAULT_FATE and none.endings_config() == ChaptersConfig.DEFAULT_ENDINGS, "missing blocks -> defaults")
	check(none.final_match().is_empty() and none.final_match_phases().is_empty(), "no final match -> no phases")
	print("--- expect ChaptersConfig fate / endings warnings next ---")
	var bad: ChaptersConfig = ChaptersConfig.from_dictionary({"chapters": chapters, "world": {
		"fate": {"execute_artifact_offers": 0, "execute_min_rarity": "", "fate_hold_sec": -1},
		"endings": {"spare_min_ratio": 2.0, "execute_max_ratio": -0.5}}})
	check(bad.fate_config() == ChaptersConfig.DEFAULT_FATE, "bad fate values -> defaults")
	check(bad.endings_config() == ChaptersConfig.DEFAULT_ENDINGS, "bad ending ratios -> defaults")
	var crossed: ChaptersConfig = ChaptersConfig.from_dictionary({"chapters": chapters, "world": {"endings": {"spare_min_ratio": 0.3, "execute_max_ratio": 0.6}}})
	check(crossed.endings_config() == ChaptersConfig.DEFAULT_ENDINGS, "execute_max > spare_min -> defaults")
	var custom: ChaptersConfig = ChaptersConfig.from_dictionary({"chapters": chapters, "world": {
		"fate": {"execute_artifact_offers": 2, "execute_min_rarity": "epic", "fate_hold_sec": 1.0},
		"endings": {"spare_min_ratio": 0.8, "execute_max_ratio": 0.2}}})
	check(int(custom.fate_config()["execute_artifact_offers"]) == 2 and str(custom.fate_config()["execute_min_rarity"]) == "epic", "custom fate read")
	check(is_equal_approx(float(custom.endings_config()["spare_min_ratio"]), 0.8), "custom endings read")
	var mutated: Dictionary = cfg.fate_config()
	mutated["execute_artifact_offers"] = 99
	check(int(cfg.fate_config()["execute_artifact_offers"]) == 3, "fate_config returns a copy")


func _test_arena() -> void:
	var arenas: ArenaLibrary = ArenaLibrary.load_from_file()
	check(arenas.shape_ids().has(ARENA_ID), "an_dai_dais loads (passed ArenaValidator at load)")
	var shape: Dictionary = arenas.get_shape(ARENA_ID)
	var verdict: Dictionary = ArenaValidator.validate(shape, arenas.rules)
	check(bool(verdict.get("ok", false)), "ArenaValidator ok %s" % str(verdict.get("reasons", [])))
	check(ArenaNames.NAMES.has(ARENA_ID), "ArenaNames has the arena")
	var f: Dictionary = arenas.featured_for_shape(ARENA_ID)
	check(not f.is_empty(), "featured shape present")
	if f.is_empty():
		return
	var cells: Array[Vector2i] = f["cells"]
	check(cells.size() >= ArenaLibrary.FEATURED_MIN_CELLS and cells.size() <= ArenaLibrary.FEATURED_MAX_CELLS, "featured 5-7 cells (%d)" % cells.size())
	var pairs: Array = FeaturedShape.pair_compositions(PieceLibrary.load_from_file(), cells)
	check(pairs.size() >= 2, ">= 2 distinct piece pairs (%s)" % str(pairs))
	var grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": ARENA_ID}, arenas, 0)
	check(grid != null and PiecePlacement.has_any_placement(grid, Piece.make("featured", cells)), "featured placeable on the enemy half")
	check(grid != null and not grid.is_player_cell(Vector2i(2, 2)), "hole in the middle of the player half")


func _trait_ids(phase: Dictionary) -> Array:
	var ids: Array = []
	for t: Variant in phase.get("traits", []) as Array:
		ids.append(str((t as Dictionary).get("id")))
	return ids

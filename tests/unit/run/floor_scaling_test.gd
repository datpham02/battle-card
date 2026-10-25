extends SceneTree
## Story 031 Part A/E: RunConfig.from_node(..., floor): region_normalize first, then floor_scaling / final row,
## applied at one point only.

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _initialize() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var ids: Array[String] = ["ch1", "ch2", "ch3"]

	# floor < 0 keeps the old behaviour exactly.
	var old_m: Dictionary = RunConfig.from_node(cfg, 0, "wolf", "battle", 5).matches[0]
	var def_m: Dictionary = cfg.get_match_def(0, "wolf")
	check(_near(float(old_m["boss_max_hp"]), float(def_m["boss_max_hp"])) and _near(float(old_m["boss_step_cooldown_mult"]), float(def_m["boss_step_cooldown_mult"]))
			and _near(float(old_m["boss_defense"]), float(def_m["boss_defense"])) and int(old_m["boss_min_runes"]) == int(def_m["boss_min_runes"]), "floor -1: no scaling")
	check(RunConfig.from_node(cfg, "ch1", "wolf", "battle", 5).matches[0] == old_m, "a region id string gives the same match as the chapter index")

	# Every floor row (display floors 1..5, final) on ch1, expectations read from the shipped data
	# (Story 031 tuning changed the numbers; the rule under test is normalize first, then the floor row).
	var norm1: Dictionary = cfg.region_normalize("ch1")
	var base: Dictionary = cfg.get_match_def(0, "goblin_brute")
	var table_ok: bool = true
	for floor_index: int in 6:
		var row: Dictionary = cfg.floor_scaling(floor_index)
		var m: Dictionary = RunConfig.from_node(cfg, "ch1", "goblin_brute", "battle", 5, floor_index).matches[0]
		var expect_hp: float = float(base["boss_max_hp"]) * float(norm1["hp_mult"]) * float(row["hp_mult"])
		var expect_step: float = float(base["boss_step_cooldown_mult"]) * float(norm1["step_mult"]) * float(row["step_mult"])
		var expect_def: float = maxf(maxf(float(base["boss_defense"]) + float(norm1["defense_add"]), 0.0) + float(row["defense_add"]), 0.0)
		var expect_size: int = maxi(int(base["boss_min_runes"]) + int(row["size_add"]), 0)
		if not (_near(float(m["boss_max_hp"]), expect_hp) and _near(float(m["boss_step_cooldown_mult"]), expect_step)
				and _near(float(m["boss_defense"]), expect_def) and int(m["boss_min_runes"]) == expect_size):
			table_ok = false
			print("  row ", row, " got ", m["boss_max_hp"], " ", m["boss_step_cooldown_mult"], " ", m["boss_defense"], " ", m["boss_min_runes"])
	check(table_ok, "ch1 floors 1-5 and final match the floor_scaling table (hp, step, defense, piece size)")
	var rows_data: Dictionary = cfg.world_spec()["floor_scaling"]
	check(_near(float(cfg.floor_scaling(3)["hp_mult"]), float(rows_data["4"]["hp_mult"])) and _near(float(cfg.floor_scaling(5)["hp_mult"]), float(rows_data["final"]["hp_mult"])), "floor_scaling(floor) is 0-based, floor 5 = final")
	check(cfg.floor_scaling(9) == cfg.floor_scaling(5), "a floor past the end uses the final row")

	# Floor 1 vs floor 5 for the same match (floor 4 has no size step after the Story 031 tuning).
	var f1: Dictionary = RunConfig.from_node(cfg, "ch1", "goblin_brute", "battle", 5, 0).matches[0]
	var f4: Dictionary = RunConfig.from_node(cfg, "ch1", "goblin_brute", "battle", 5, 4).matches[0]
	check(float(f4["boss_max_hp"]) > float(f1["boss_max_hp"]) and float(f4["boss_step_cooldown_mult"]) < float(f1["boss_step_cooldown_mult"])
			and float(f4["boss_defense"]) > float(f1["boss_defense"]) and int(f4["boss_min_runes"]) > int(f1["boss_min_runes"]), "floor 5 is harder than floor 1 on all four axes")

	# Region normalize applies before the floor row (multiplicative on hp/step, additive on defense).
	var ch2_base: Dictionary = cfg.get_match_def(1, "skeleton")
	var norm2: Dictionary = cfg.region_normalize("ch2")
	check(_near(float(norm2["hp_mult"]), 0.85) and _near(float(norm2["step_mult"]), 1.05) and _near(float(norm2["defense_add"]), 0.0), "ch2 region_normalize 0.85 / 1.05 / 0")
	var ch2_m: Dictionary = RunConfig.from_node(cfg, "ch2", "skeleton", "battle", 5, 3).matches[0]
	var row4: Dictionary = cfg.floor_scaling(3)
	check(_near(float(ch2_m["boss_max_hp"]), float(ch2_base["boss_max_hp"]) * float(norm2["hp_mult"]) * float(row4["hp_mult"]))
			and _near(float(ch2_m["boss_step_cooldown_mult"]), float(ch2_base["boss_step_cooldown_mult"]) * float(norm2["step_mult"]) * float(row4["step_mult"])), "ch2: normalize x floor row (floor 4)")

	# Defense never goes negative: ch3 normalize -1 on a defense-0 match, then floor row 0.
	var ch3_base: Dictionary = cfg.get_match_def(2, "frost_sprite")
	var ch3_m: Dictionary = RunConfig.from_node(cfg, "ch3", "frost_sprite", "battle", 5, 0).matches[0]
	check(float(ch3_base["boss_defense"]) >= 0.0 and float(ch3_m["boss_defense"]) >= 0.0, "defense stays >= 0 (ch3 normalize -1)")
	var guard: Dictionary = {"chapters": [{"id": "r", "region_normalize": {"hp_mult": 1, "step_mult": 1, "defense_add": -5}, "matches": {"m": {"boss_defense": 2}}}],
		"world": {"floors": 2, "region_pool": ["r"], "floor_scaling": {"1": {"hp_mult": 2, "step_mult": 0.5, "defense_add": 1, "size_add": -4}, "2": {}, "final": {}}}}
	var gcfg: ChaptersConfig = ChaptersConfig.from_dictionary(guard)
	var gm: Dictionary = RunConfig.from_node(gcfg, "r", "m", "battle", 1, 0).matches[0]
	check(_near(float(gm["boss_defense"]), 1.0), "clamp after the normalize step: max(2-5, 0) + 1 = 1 (not -2)")
	check(int(gm["boss_min_runes"]) == 0, "piece size never below 0")
	check(_near(float(gm["boss_max_hp"]), float(RunConfig.clean_match({}, 0)["boss_max_hp"]) * 2.0), "a match without boss_max_hp scales the default")

	# Normalize first, then scale: ch3 with defense 4 (wisp family has defense) -> (4 - 1) + floor add.
	var wisp: Dictionary = cfg.get_match_def(2, "stone_sentry")
	var s_m: Dictionary = RunConfig.from_node(cfg, "ch3", "stone_sentry", "battle", 5, 2).matches[0]
	var expect_def: float = maxf(float(wisp["boss_defense"]) - 1.0, 0.0) + 1.0
	check(_near(float(s_m["boss_defense"]), expect_def), "ch3 stone_sentry floor 3: max(def-1, 0) + 1")

	# Final match: region ch3 / mist_lord with the `final` row, no double application.
	var fin: Dictionary = cfg.final_match()
	var final_base: Dictionary = cfg.get_match_def(cfg.region_index(fin["region"]), fin["match_id"])
	var final_m: Dictionary = RunConfig.from_node(cfg, fin["region"], fin["match_id"], "boss", 5, 5).matches[0]
	var norm3: Dictionary = cfg.region_normalize(fin["region"])
	var final_row: Dictionary = cfg.floor_scaling(5)
	check(_near(float(final_m["boss_max_hp"]), float(final_base["boss_max_hp"]) * float(norm3["hp_mult"]) * float(final_row["hp_mult"]))
			and _near(float(final_m["boss_step_cooldown_mult"]), float(final_base["boss_step_cooldown_mult"]) * float(norm3["step_mult"]) * float(final_row["step_mult"]))
			and int(final_m["boss_min_runes"]) == maxi(int(final_base["boss_min_runes"]) + int(final_row["size_add"]), 0), "final match: ch3 normalize then the `final` row")
	check(cfg.get_match_def(2, "mist_lord")["boss_max_hp"] == final_base["boss_max_hp"], "scaling never mutates the stored match data")

	# Everything else of the match is untouched; danger traits still added.
	var danger: Dictionary = RunConfig.from_node(cfg, "ch1", "wolf", "danger", 5, 2).matches[0]
	var plain: Dictionary = RunConfig.from_node(cfg, "ch1", "wolf", "battle", 5, 2).matches[0]
	check(danger["arena"] == plain["arena"] and (danger["traits"] as Array).size() == (plain["traits"] as Array).size() + 1, "danger node still adds its trait under scaling")
	check(RunConfig.from_node(cfg, "nope", "wolf", "battle", 5, 1).matches.size() == 1, "unknown region falls back to the default match")

	# Every region x every match scales without error.
	var every_ok: bool = true
	for rid: String in ids:
		for mid: String in cfg.match_ids(cfg.region_index(rid)):
			var mm: Dictionary = RunConfig.from_node(cfg, rid, mid, "battle", 1, 4).matches[0]
			if float(mm["boss_max_hp"]) <= 0.0 or float(mm["boss_step_cooldown_mult"]) <= 0.0 or float(mm["boss_defense"]) < 0.0:
				every_ok = false
	check(every_ok, "every match of every region scales to valid values")

	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)

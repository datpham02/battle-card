extends SceneTree
## Multi-enemy Phase 0 (docs/design/world-map-v2/MULTI-ENEMY-ENCOUNTER-AUDIT.md section 5 / 8.4): the `formations`
## block of chapters.json is validated by FormationRules, invalid formations are dropped, the shipped data loads
## unchanged, and RunConfig carries `enemies` / `attack_slots` only for a formation node.

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)


func _has_problem(cfg: ChaptersConfig, needle: String) -> bool:
	for p: String in cfg.formation_problems():
		if p.contains(needle):
			return true
	return false


# A fixture chapter: four 1-cell block matches, one 2x2 pattern warden (footprint from the injected lookup).
func _fixture(formations: Dictionary, pools: Dictionary = {}) -> Dictionary:
	var matches: Dictionary = {
		"a": {"boss_max_hp": 100, "arena": {"shape": "square"}},
		"b": {"boss_max_hp": 120, "arena": {"shape": "rect"}, "boss_defense": 2},
		"c": {"boss_max_hp": 140, "arena": {"shape": "forge"}, "traits": [{"id": "row_burner"}]},
		"d": {"boss_max_hp": 90, "arena": {"shape": "dunes"}},
		"w": {"boss_max_hp": 900, "brain": "pattern", "enemy": "big", "arena": {"shape": "boss_hall"}},
	}
	var chapter: Dictionary = {"id": "fx", "matches": matches, "formations": formations,
		"region_normalize": {"hp_mult": 0.8, "step_mult": 1.0, "defense_add": 1},
		"pools": {"battle": {"0": ["a", "b"]}, "boss": {"0": ["w"]}}}
	if not pools.is_empty():
		chapter["pools"]["formation"] = pools
	return {"defaults": {"danger_traits": [{"id": "row_burner"}]}, "chapters": [chapter]}


func _initialize() -> void:
	var library: ArenaLibrary = ArenaLibrary.load_from_file()
	ChaptersConfig.set_formation_lookup(library, func(enemy_id: String) -> Array: return [[0, 0], [1, 0], [0, 1], [1, 1]] if enemy_id == "big" else [[0, 0]])

	# 1. A valid block: normal 2 on square, hard 3 on forge, 4 on dunes, elite 2 on rect, boss 2x2 + 1 on boss_hall.
	var good: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"n2": {"type": "normal", "arena": {"shape": "square"}, "enemies": [{"id": "a", "role": "attacker"}, {"id": "b", "role": "tank", "hp_mult": 0.8}]},
		"h3": {"type": "hard", "arena": {"shape": "forge"}, "attack_slots": 2, "enemies": [{"id": "c", "role": "disruptor"}, {"id": "a"}, {"id": "b", "required": false}]},
		"h4": {"type": "hard", "arena": {"shape": "dunes"}, "enemies": [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]},
		"e2": {"type": "elite", "enemies": [{"id": "b", "slot": "front_mid"}, {"id": "a", "hp_mult": 0.4, "defense_add": 1, "tempo_mult": 1.2, "traits": [{"id": "row_burner"}]}]},
		"boss": {"type": "boss", "arena": {"shape": "boss_hall"}, "attack_slots": 2, "hp_budget_mult": 1.1, "enemies": [{"id": "w"}, {"id": "a", "hp_mult": 0.3}]},
	}, {"0": ["n2"], "1": ["n2", "h3", "e2"], "2": ["h4", "boss"]}))
	check(good.formation_problems().is_empty(), "valid block: no problems (%s)" % ",".join(good.formation_problems()))
	check(",".join(good.formation_ids(0)) == "n2,h3,h4,e2,boss", "five valid formations kept in file order")
	var h3: Dictionary = good.get_formation(0, "h3")
	check(h3["type"] == "hard" and int(h3["attack_slots"]) == 2 and (h3["enemies"] as Array).size() == 3 and int(h3["unit_cells"]) == 3, "h3 cleaned: type, attack_slots, 3 units, 3 cells")
	check(h3["name_key"] == "formation.h3.name" and h3["arena"] == {"shape": "forge"}, "defaults: name_key formation.<id>.name, arena as written")
	var e2: Dictionary = good.get_formation(0, "e2")
	check(e2["arena"] == {"shape": "rect"}, "no arena -> the first enemy's arena")
	var e2b: Dictionary = (e2["enemies"] as Array)[1]
	check(e2b["slot"] == "" and is_equal_approx(float(e2b["hp_mult"]), 0.4) and is_equal_approx(float(e2b["defense_add"]), 1.0)
			and is_equal_approx(float(e2b["tempo_mult"]), 1.2) and (e2b["traits"] as Array).size() == 1 and bool(e2b["required"]), "entry overrides kept, required defaults true")
	check((good.get_formation(0, "boss")["enemies"] as Array).size() == 2 and int(good.get_formation(0, "boss")["unit_cells"]) == 5, "2x2 warden + 1 on boss_hall = 5 cells allowed")
	check(good.formation_pools(0) == {"0": ["n2"], "1": ["n2", "h3", "e2"], "2": ["h4", "boss"]}, "pools.formation kept per tier")
	check(not good.get_map_spec(0)["pools"].has("formation") and ",".join(good.match_ids(0)) == "a,b,c,d,w", "pools / match_ids seen by the generators do not contain formations")
	check(not good.has_formation(0, "a") and good.get_formation(0, "zzz").is_empty() and good.formation_ids(5).is_empty(), "has_formation / get_formation / out of range")

	# 2. Every rule rejects (the formation is dropped, never clamped).
	var bad: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"sq3": {"type": "normal", "arena": {"shape": "square"}, "enemies": [{"id": "a"}, {"id": "b"}, {"id": "c"}]},
		"five": {"type": "hard", "arena": {"shape": "oasis"}, "enemies": [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}, {"id": "a"}]},
		"forge4": {"type": "hard", "arena": {"shape": "forge"}, "enemies": [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]},
		"wcal": {"type": "boss", "arena": {"shape": "caldera"}, "enemies": [{"id": "w"}, {"id": "a"}]},
		"wsq": {"type": "boss", "arena": {"shape": "square"}, "enemies": [{"id": "w"}]},
		"ghost": {"type": "normal", "enemies": [{"id": "nope"}, {"id": "a"}]},
		"badtype": {"type": "swarm", "enemies": [{"id": "a"}, {"id": "b"}]},
		"slots": {"type": "normal", "arena": {"shape": "rect"}, "attack_slots": 3, "enemies": [{"id": "a"}, {"id": "b"}]},
		"noreq": {"type": "normal", "arena": {"shape": "rect"}, "enemies": [{"id": "a", "required": false}, {"id": "b", "required": false}]},
		"late": {"type": "normal", "arena": {"shape": "rect"}, "enemies": [{"id": "a"}, {"id": "b", "spawn_at": {"phase": 2}}]},
		"a": {"type": "normal", "enemies": [{"id": "b"}, {"id": "c"}]},
		"noarena": {"type": "normal", "arena": {"shape": "nowhere"}, "enemies": [{"id": "a"}, {"id": "b"}]},
		"empty": {"type": "normal", "enemies": []},
		"notobj": 5,
		"badrole": {"type": "normal", "arena": {"shape": "rect"}, "enemies": [{"id": "a", "role": "healer"}, {"id": "b"}]},
		"variant": {"type": "hard", "arena": {"shape": "bog", "variant": true}, "enemies": [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]},
	}, {"0": ["sq3", "late", "zzz"]}))
	check(bad.formation_ids(0).is_empty(), "every invalid formation dropped (kept: %s)" % ",".join(bad.formation_ids(0)))
	check(_has_problem(bad, "'sq3'") and _has_problem(bad, "cap there is 2"), "square: 3 units rejected (cap 2)")
	check(_has_problem(bad, "'five'") and _has_problem(bad, "cap is 4"), "5 units rejected")
	check(_has_problem(bad, "'forge4'") and _has_problem(bad, "15-cell half, the cap there is 3"), "forge (15 cells): 4 units rejected")
	check(_has_problem(bad, "'wcal'") and _has_problem(bad, "only have company on boss_hall, oasis"), "2x2 warden + company on caldera rejected")
	check(_has_problem(bad, "'wsq'") and _has_problem(bad, "exceed a third"), "2x2 warden alone on square rejected (4 cells of 9)")
	check(_has_problem(bad, "'nope' is not a match"), "unknown enemy id reported")
	check(_has_problem(bad, "type 'swarm' unknown"), "unknown type reported")
	check(_has_problem(bad, "attack_slots 3 must be 1..2"), "attack_slots above the unit count rejected")
	check(_has_problem(bad, "no enemy is required"), "no required unit rejected")
	check(_has_problem(bad, "spawn_at is not supported"), "spawn_at refused in Phase 0")
	check(_has_problem(bad, "collides with a match"), "formation id equal to a match id refused")
	check(_has_problem(bad, "arena unknown"), "unknown arena shape rejected")
	check(_has_problem(bad, "'empty'") and _has_problem(bad, "'notobj'") and _has_problem(bad, "role 'healer' unknown"), "empty enemies, non-object block, unknown role reported")
	check(_has_problem(bad, "'variant'") and _has_problem(bad, "10-cell half"), "variant arena counted minus variant_change_max (bog 13 - 3)")
	check(bad.formation_pools(0) == {"0": []}, "pools.formation drops dropped / unknown ids")
	check(",".join(bad.match_ids(0)) == "a,b,c,d,w" and bad.get_map_spec(0)["pools"] == {"battle": {"0": ["a", "b"]}, "boss": {"0": ["w"]}}, "matches and regular pools untouched by a bad formations block")

	# 3. Direct arena blocks and the pure helpers.
	check(FormationRules.half_cells({"side_cols": 4, "side_rows": 3, "missing_cells": [[0, 0]]}, null) == 11, "half_cells of a direct block")
	check(FormationRules.half_cells({"shape": "caldera"}, library) == 22 and FormationRules.half_cells({"shape": "caldera", "variant": true}, library) == 19, "half_cells of a shape, variant conservative")
	check(FormationRules.max_units_for(9) == 2 and FormationRules.max_units_for(12) == 3 and FormationRules.max_units_for(16) == 3 and FormationRules.max_units_for(17) == 4, "max_units_for table")
	var direct: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"dir": {"type": "normal", "arena": {"side_cols": 4, "side_rows": 3, "missing_cells": []}, "enemies": [{"id": "a"}, {"id": "b"}, {"id": "c"}]},
		"dirw": {"type": "boss", "arena": {"side_cols": 6, "side_rows": 4, "missing_cells": []}, "enemies": [{"id": "w"}, {"id": "a"}]},
	}))
	check(",".join(direct.formation_ids(0)) == "dir" and _has_problem(direct, "'dirw'"), "direct arena block accepted; a warden pack needs a named boss_hall / oasis")

	# 4. The shipped data loads unchanged.
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var shipped_ok: bool = cfg.formation_problems().is_empty()
	for ci: int in cfg.chapter_count():
		if not cfg.formation_ids(ci).is_empty() or not cfg.formation_pools(ci).is_empty():
			shipped_ok = false
	check(shipped_ok, "shipped chapters.json: no formations, no problems")
	var plain: Dictionary = RunConfig.from_node(cfg, "hellfire", "imp", "battle", 7, 2).matches[0]
	check(not plain.has("enemies") and not plain.has("attack_slots") and not plain.has("hp_budget_mult"), "a plain match carries none of the new keys")
	check(plain == RunConfig.from_node(cfg, "hellfire", "imp", "battle", 7, 2).matches[0] and plain["id"] == "imp", "from_node of a plain match is unchanged and deterministic")
	var flat: Dictionary = RunConfig.clean_match({"id": "x", "boss_max_hp": 50}, 0)
	check(flat.keys().size() == RunConfig._default_match(0).keys().size() and not flat.has("enemies"), "clean_match of a plain raw adds no key")

	# 5. from_node on a formation id: the first enemy's template + the formation keys, scaled like a match.
	var fm: Dictionary = RunConfig.from_node(good, 0, "h3", "danger", 11, 3).matches[0]
	var tpl: Dictionary = RunConfig.from_node(good, 0, "c", "danger", 11, 3).matches[0]
	check(fm["id"] == "h3" and fm["name_key"] == "formation.h3.name" and fm["arena"] == {"shape": "forge"}, "formation node: id, name_key, arena of the formation")
	check((fm["enemies"] as Array).size() == 3 and (fm["enemies"] as Array)[0]["id"] == "c" and int(fm["attack_slots"]) == 2 and is_equal_approx(float(fm["hp_budget_mult"]), 1.0), "formation node carries enemies / attack_slots / hp_budget_mult")
	check(is_equal_approx(float(fm["boss_max_hp"]), float(tpl["boss_max_hp"])) and fm["traits"] == tpl["traits"] and is_equal_approx(float(fm["boss_defense"]), float(tpl["boss_defense"])), "unit 0 = the first enemy's template, floor-scaled and danger-traited like that match")
	check(fm["arena_seed"] == (hash([11, "h3"]) & ChaptersConfig.SEED_MASK), "arena seed from the formation id")
	var wf: Dictionary = RunConfig.from_node(good, 0, "boss", "boss", 1).matches[0]
	check(wf.get("brain") == "pattern" and wf.get("enemy") == "big" and (wf["enemies"] as Array).size() == 2, "a warden formation keeps the pattern brain of its first unit")

	# 6. Flat configs: `enemies` cleaned structurally, bad shapes dropped with the single-enemy keys kept.
	var carried: Dictionary = RunConfig.from_dictionary({"matches": [{"id": "f", "enemies": [{"id": "p", "role": "tank", "hp_mult": 0.5}, {"id": "q", "hp_mult": -1}], "attack_slots": 0, "hp_budget_mult": 2}]}).matches[0]
	check((carried["enemies"] as Array).size() == 2 and (carried["enemies"] as Array)[0]["role"] == "tank" and is_equal_approx(float((carried["enemies"] as Array)[1]["hp_mult"]), 1.0)
			and int(carried["attack_slots"]) == 1 and is_equal_approx(float(carried["hp_budget_mult"]), 2.0), "flat enemies cleaned (hp_mult <= 0 -> 1, attack_slots floored at 1)")
	var carried0: Dictionary = (carried["enemies"] as Array)[0]
	check(carried0.keys().size() == FormationRules.ENTRY_KEYS.size() + FormationRules.RESOLVED_KEYS.size(), "a cleaned entry has exactly ENTRY_KEYS + RESOLVED_KEYS")
	check(carried0["template_id"] == "p" and is_equal_approx(float(carried0["max_hp"]), float(carried["boss_max_hp"])) and is_equal_approx(float(carried0["defense"]), float(carried["boss_defense"]))
			and carried0["brain"] == "block" and carried0["enemy"] == "" and carried0["footprint"] == [[0, 0]], "flat entry without resolved keys falls back to the match's own numbers")
	var flat_res: Dictionary = (RunConfig.from_dictionary({"matches": [{"id": "f2", "enemies": [{"id": "p", "max_hp": 77, "defense": 3, "brain": "pattern", "enemy": "big", "footprint": [[0, 0], [1, 0]]},
			{"id": "q", "max_hp": -5, "brain": "pattern", "footprint": [[1, 0]]}, {"id": "r", "brain": "swarm", "footprint": "bad"}]}]}).matches[0]["enemies"] as Array)[0]
	check(is_equal_approx(float(flat_res["max_hp"]), 77.0) and is_equal_approx(float(flat_res["defense"]), 3.0) and flat_res["brain"] == "pattern" and flat_res["enemy"] == "big" and flat_res["footprint"] == [[0, 0], [1, 0]], "flat entry keeps written resolved keys")
	var flat_bad: Array = RunConfig.from_dictionary({"matches": [{"id": "f3", "boss_max_hp": 60, "enemies": [{"id": "q", "max_hp": -5, "brain": "pattern", "footprint": [[1, 0]]}, {"id": "r", "brain": "swarm", "footprint": "bad"}]}]}).matches[0]["enemies"]
	check(is_equal_approx(float((flat_bad[0] as Dictionary)["max_hp"]), 60.0) and (flat_bad[0] as Dictionary)["brain"] == "block" and (flat_bad[0] as Dictionary)["footprint"] == [[0, 0]]
			and (flat_bad[1] as Dictionary)["brain"] == "block" and (flat_bad[1] as Dictionary)["footprint"] == [[0, 0]], "bad resolved values fall back: max_hp <= 0 -> boss_max_hp, pattern without enemy / unknown brain -> block, footprint without [0,0] -> one cell")

	# 7. Phase 1: from_node resolves every entry (design 3.3): unit 0 folded into the match, units 1.. from their
	# templates with the same normalize / floor rows, traits merged, footprint from the lookup.
	var floor_index: int = 3
	var norm: Dictionary = good.region_normalize_at(0)
	var row: Dictionary = good.floor_scaling(floor_index)
	var res: Dictionary = RunConfig.from_node(good, 0, "e2", "danger", 5, floor_index).matches[0]
	var r0: Dictionary = (res["enemies"] as Array)[0]
	var r1: Dictionary = (res["enemies"] as Array)[1]
	var tpl_b: Dictionary = good.get_match_raw(0, "b")
	var tpl_a: Dictionary = good.get_match_raw(0, "a")
	var exp_hp0: float = float(tpl_b["boss_max_hp"]) * float(norm["hp_mult"]) * float(row["hp_mult"])
	var exp_def0: float = maxf(maxf(float(tpl_b["boss_defense"]) + float(norm["defense_add"]), 0.0) + float(row["defense_add"]), 0.0)
	check(is_equal_approx(float(res["boss_max_hp"]), exp_hp0) and is_equal_approx(float(r0["max_hp"]), float(res["boss_max_hp"])), "entry 0 max_hp == the match's boss_max_hp (template x normalize x floor, hp_mult 1)")
	check(is_equal_approx(float(r0["defense"]), float(res["boss_defense"])) and is_equal_approx(float(res["boss_defense"]), exp_def0), "entry 0 defense == the match's boss_defense")
	var exp_hp1: float = float(tpl_a["boss_max_hp"]) * float(norm["hp_mult"]) * float(row["hp_mult"]) * 0.4
	var exp_def1: float = maxf(maxf(0.0 + float(norm["defense_add"]), 0.0) + float(row["defense_add"]), 0.0) + 1.0
	check(is_equal_approx(float(r1["max_hp"]), exp_hp1), "entry 1 max_hp = template x normalize x floor x hp_mult (%s vs %s)" % [r1["max_hp"], exp_hp1])
	check(is_equal_approx(float(r1["defense"]), exp_def1), "entry 1 defense = template + normalize + floor + defense_add (%s vs %s)" % [r1["defense"], exp_def1])
	check(r1["template_id"] == "a" and r1["brain"] == "block" and r1["enemy"] == "" and r1["footprint"] == [[0, 0]], "entry 1 template_id / block brain / one cell")
	check((r1["traits"] as Array).size() == 1 and (r1["traits"] as Array)[0]["id"] == "row_burner", "entry 1 traits = template (none) + entry traits")
	check((r0["traits"] as Array) == (res["traits"] as Array) and (res["traits"] as Array).size() == 1 and (res["traits"] as Array)[0]["id"] == "row_burner", "entry 0 traits mirror the match traits (danger row_burner added once) r0=%s res=%s" % [str(r0["traits"]), str(res["traits"])])
	# unit-0 hp_mult / defense_add / traits fold into the match: n2's second entry is "b" hp_mult 0.8; build a
	# formation whose FIRST entry carries overrides.
	var fold: ChaptersConfig = ChaptersConfig.from_dictionary(_fixture({
		"lead": {"type": "hard", "arena": {"shape": "forge"}, "enemies": [{"id": "c", "hp_mult": 0.5, "defense_add": 2, "traits": [{"id": "step_reactor"}]}, {"id": "b", "hp_mult": 0.7}]},
	}))
	var fm2: Dictionary = RunConfig.from_node(fold, 0, "lead", "battle", 9, floor_index).matches[0]
	var tpl_c: Dictionary = fold.get_match_raw(0, "c")
	var exp_c: float = float(tpl_c["boss_max_hp"]) * float(norm["hp_mult"]) * float(row["hp_mult"]) * 0.5
	check(is_equal_approx(float(fm2["boss_max_hp"]), exp_c) and is_equal_approx(float((fm2["enemies"] as Array)[0]["max_hp"]), exp_c), "entry 0 hp_mult folds into boss_max_hp")
	check(is_equal_approx(float(fm2["boss_defense"]), maxf(maxf(0.0 + float(norm["defense_add"]), 0.0) + float(row["defense_add"]), 0.0) + 2.0), "entry 0 defense_add folds into boss_defense")
	var ids0: Array = []
	for t: Variant in fm2["traits"] as Array:
		ids0.append((t as Dictionary)["id"])
	check(ids0 == ["row_burner", "step_reactor"], "entry 0 traits = template traits + entry traits, deduplicated (%s)" % str(ids0))
	var fb: Dictionary = (fm2["enemies"] as Array)[1]
	check(is_equal_approx(float(fb["max_hp"]), float(fold.get_match_raw(0, "b")["boss_max_hp"]) * float(norm["hp_mult"]) * float(row["hp_mult"]) * 0.7), "entry 1 of a second formation scales independently")
	var nof: Dictionary = RunConfig.from_node(good, 0, "boss", "boss", 1).matches[0]
	check((nof["enemies"] as Array)[0]["footprint"] == [[0, 0], [1, 0], [0, 1], [1, 1]] and (nof["enemies"] as Array)[0]["brain"] == "pattern" and (nof["enemies"] as Array)[0]["enemy"] == "big"
			and is_equal_approx(float((nof["enemies"] as Array)[0]["max_hp"]), 900.0) and is_equal_approx(float((nof["enemies"] as Array)[1]["max_hp"]), 30.0), "floor < 0: no scaling; warden entry gets its 2x2 footprint and pattern brain, helper hp_mult 0.3")
	var plain2: Dictionary = RunConfig.from_node(good, 0, "a", "danger", 5, floor_index).matches[0]
	check(not plain2.has("enemies") and plain2 == RunConfig.from_node(good, 0, "a", "danger", 5, floor_index).matches[0], "a plain match of the same chapter still carries no enemies key")
	check(not RunConfig.from_dictionary({"matches": [{"id": "g", "enemies": [{"role": "tank"}]}]}).matches[0].has("enemies")
			and not RunConfig.from_dictionary({"matches": [{"id": "h", "enemies": "no"}]}).matches[0].has("enemies"), "an entry without id / a non-array drops the enemies key")

	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)

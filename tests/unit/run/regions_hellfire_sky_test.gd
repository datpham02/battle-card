extends SceneTree
## Story 039 Parts B, C, D (data half, W2): the `hellfire` and `sky_isles` regions load and are in the world pool
## (now 7 regions, `an_dai` still not); every match id of the contract exists with the story's HP, traits and params;
## the pools cover every node the map generator makes on floors 1-5; the four new arenas pass ArenaValidator
## (vent lines on real cells, crumble arenas connected to the start cell, featured shape from >= 2 piece pairs);
## `ArenaLibrary.hazards_for_match` returns the vents / crumble (every sky_isles match runs on a crumble arena);
## every new string key has vi + en; `weights.hellfire` / `weights.sky_isles` list the default-pool shapes and lean
## the story's way; the new `best_floor` unlock condition (`reach_floor_4` -> region hellfire, `reach_floor_5` ->
## region sky_isles); the world offer never repeats a region in a 5-floor run (20 seeds). Headless; FAILS=N.

## Contract match ids -> the story's floor-1 HP (the exact numbers ARE the spec here).
const HELL_HP: Dictionary = {
	"imp": 92, "ember_hound": 110, "ash_golem": 132, "flame_cultist": 128, "magma_slug": 140, "hell_knight": 156,
	"fire_eater": 90, "ash_phoenix": 74, "inferno_lord": 180,
}
const SKY_HP: Dictionary = {
	"cloud_sprite": 88, "harpy": 104, "wind_monk": 118, "storm_eagle": 126, "sky_sentinel": 144, "thunder_shaman": 150,
	"gale_bird": 86, "cloud_veil": 96, "storm_dragon": 185,
}
## Contract trait id of each breaker / boss / trait-carrying normal match.
const TRAITS: Dictionary = {
	"flame_cultist": "row_burner", "fire_eater": "burn_eater", "ash_phoenix": "rebirth", "inferno_lord": "vent_surge",
	"thunder_shaman": "row_burner", "gale_bird": "gust", "cloud_veil": "shroud", "storm_dragon": "island_drop",
}
const NEW_TRAITS: Array[String] = ["burn_eater", "rebirth", "vent_surge", "gust", "shroud", "island_drop"]
const HELL_ARENAS: Array[String] = ["forge", "caldera"]
const SKY_ARENAS: Array[String] = ["twin_isles", "three_isles", "islands_bridge"]
const NEW_ARENAS: Array[String] = ["forge", "caldera", "twin_isles", "three_isles"]
const MAP_SEEDS: int = 30
const WORLD_SEEDS: int = 20
const FIGHT_KINDS: Array[String] = ["battle", "danger", "miniboss", "boss"]

var fails: int = 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + label)


func _init() -> void:
	var cfg: ChaptersConfig = ChaptersConfig.load_from_file()
	var arenas: ArenaLibrary = ArenaLibrary.load_from_file()
	_test_regions(cfg)
	_test_matches(cfg, "hellfire", HELL_HP, arenas)
	_test_matches(cfg, "sky_isles", SKY_HP, arenas)
	_test_numbers(cfg)
	_test_pools(cfg, "hellfire")
	_test_pools(cfg, "sky_isles")
	_test_arenas(arenas)
	_test_hazards(cfg, arenas)
	_test_validator(arenas)
	_test_strings()
	_test_weights()
	_test_unlocks()
	_test_world(cfg)
	print("FAILS=%d" % fails)
	quit(fails)


func _test_regions(cfg: ChaptersConfig) -> void:
	var pool: Array[String] = cfg.region_ids()
	check(pool == (["ch1", "ch2", "ch3", "swamp", "desert", "hellfire", "sky_isles"] as Array[String]), "region_pool has 7 regions (%s)" % [pool])
	check(not pool.has("an_dai"), "an_dai is not in the pool")
	for id: String in ["hellfire", "sky_isles"]:
		check(cfg.region_index(id) >= 0, "%s loads as a chapter" % id)
		var spec: Dictionary = cfg.region_spec(id, 0)
		check(str(spec.get("name_key")) == "chapter.%s.name" % id, "%s name_key" % id)
		check(str(spec.get("intro_key")) == "chapter.%s.intro" % id and str(spec.get("end_key")) == "chapter.%s.end" % id, "%s intro / end keys" % id)


func _test_matches(cfg: ChaptersConfig, region: String, hp: Dictionary, arenas: ArenaLibrary) -> void:
	var ci: int = cfg.region_index(region)
	var allowed: Array[String] = HELL_ARENAS if region == "hellfire" else SKY_ARENAS
	check(cfg.match_ids(ci).size() == hp.size(), "%s has %d matches" % [region, hp.size()])
	for id: String in hp.keys():
		var m: Dictionary = cfg.get_match_def(ci, id)
		check(not m.is_empty(), "%s: match %s exists" % [region, id])
		if m.is_empty():
			continue
		check(is_equal_approx(float(m["boss_max_hp"]), float(hp[id])), "%s: HP %s" % [id, hp[id]])
		check(str(m["name_key"]) == "boss.%s.name" % id, "%s: name_key" % id)
		var shape: String = str((m["arena"] as Dictionary).get("shape", ""))
		check(allowed.has(shape) and not arenas.get_shape(shape).is_empty(), "%s: arena %s is a %s arena" % [id, shape, region])
		if TRAITS.has(id):
			check(_trait_ids(m).has(str(TRAITS[id])), "%s: trait %s" % [id, TRAITS[id]])


func _trait_ids(m: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for t: Variant in m.get("traits", []) as Array:
		ids.append(str((t as Dictionary).get("id", "")))
	return ids


func _trait_params(m: Dictionary, id: String) -> Dictionary:
	for t: Variant in m.get("traits", []) as Array:
		if str((t as Dictionary).get("id", "")) == id:
			return (t as Dictionary).get("params", {}) as Dictionary
	return {}


## The story's starting numbers of the new traits and per-match keys.
func _test_numbers(cfg: ChaptersConfig) -> void:
	var h: int = cfg.region_index("hellfire")
	var s: int = cfg.region_index("sky_isles")
	var imp: Dictionary = cfg.get_match_def(h, "imp")
	check(str(imp["brain_set"]) == "cautious", "imp is cautious")
	check(is_equal_approx(float((cfg.get_match_def(h, "ember_hound")["movement"] as Dictionary)["move_commitment"]), 0.9), "ember_hound move_commitment 0.9")
	check(is_equal_approx(float(cfg.get_match_def(h, "ash_golem")["boss_defense"]), 3.0), "ash_golem boss_defense 3")
	check(is_equal_approx(float(cfg.get_match_def(h, "magma_slug")["swing_speed_mult"]), 0.95), "magma_slug swing_speed_mult 0.95")
	var knight: Dictionary = cfg.get_match_def(h, "hell_knight")
	check(is_equal_approx(float(knight["boss_defense"]), 2.0) and int(knight["boss_min_runes"]) == 3, "hell_knight boss_defense 2, boss_min_runes 3")
	var eater: Dictionary = cfg.get_match_def(h, "fire_eater")
	check(is_equal_approx(float(_trait_params(eater, "burn_eater")["heal_ratio"]), 1.0), "fire_eater heal_ratio 1.0")
	check(str(eater["desc_key"]) == "match.fire_eater.desc", "fire_eater has a match description")
	var phoenix: Dictionary = cfg.get_match_def(h, "ash_phoenix")
	var rp: Dictionary = _trait_params(phoenix, "rebirth")
	check(is_equal_approx(float(rp["revive_ratio"]), 0.4) and is_equal_approx(float(rp["revive_sec"]), 1.5), "ash_phoenix revive_ratio 0.4, revive_sec 1.5")
	var lord: Dictionary = cfg.get_match_def(h, "inferno_lord")
	check(str(lord["brain_set"]) == "aggressive" and int(lord["boss_min_runes"]) == 3, "inferno_lord aggressive, boss_min_runes 3")
	var vs: Dictionary = _trait_params(lord, "vent_surge")
	check(is_equal_approx(float(vs["interval_sec"]), 10.0) and int(vs["vents"]) == 2, "inferno_lord vent_surge interval 10, vents 2")
	var ps: Dictionary = _trait_params(lord, "phase_shift")
	check(_trait_ids(lord).has("phase_shift") and is_equal_approx(float(ps["at_hp_ratio"]), 0.5) and is_equal_approx(float(ps["vent_interval_mult"]), 0.7),
		"inferno_lord phase 2 at 50 %% HP with vent_interval_mult 0.7")
	check(is_equal_approx(float((cfg.get_match_def(s, "harpy")["movement"] as Dictionary)["move_noise"]), 0.1), "harpy move_noise 0.1")
	check(is_equal_approx(float(cfg.get_match_def(s, "sky_sentinel")["boss_defense"]), 3.0), "sky_sentinel boss_defense 3")
	var lowest: bool = true
	var eagle_step: float = float(cfg.get_match_def(s, "storm_eagle")["boss_step_cooldown_mult"])
	for id: String in SKY_HP.keys():
		if id != "storm_eagle" and float(cfg.get_match_def(s, id)["boss_step_cooldown_mult"]) <= eagle_step:
			lowest = false
	check(lowest, "storm_eagle has the lowest step cooldown mult of the region")
	var gust: Dictionary = _trait_params(cfg.get_match_def(s, "gale_bird"), "gust")
	check(is_equal_approx(float(gust["interval_sec"]), 6.0) and is_equal_approx(float(gust["warn_sec"]), 0.6), "gale_bird gust interval 6, warn 0.6")
	var dragon: Dictionary = cfg.get_match_def(s, "storm_dragon")
	check(str(dragon["brain_set"]) == "balanced" and int(dragon["boss_min_runes"]) == 3, "storm_dragon balanced, boss_min_runes 3")
	var drop: Dictionary = _trait_params(dragon, "island_drop")
	check(is_equal_approx(float(drop["interval_sec"]), 11.0) and is_equal_approx(float(drop["fall_sec"]), 4.0) and is_equal_approx(float(drop["warn_sec"]), 1.2),
		"storm_dragon island_drop interval 11, fall 4, warn 1.2")
	check(_trait_ids(dragon).has("gust") and float(_trait_params(dragon, "gust")["interval_sec"]) > 6.0, "storm_dragon has a lighter gust")
	for id: String in ["fire_eater", "ash_phoenix", "inferno_lord", "gale_bird", "cloud_veil", "storm_dragon"]:
		var ci: int = h if HELL_HP.has(id) else s
		check(str(cfg.get_match_def(ci, id).get("desc_key", "")) == "match.%s.desc" % id, "%s has desc_key" % id)
	for id: String in ["fire_eater", "ash_phoenix", "gale_bird", "cloud_veil"]:
		var ci2: int = h if HELL_HP.has(id) else s
		check(cfg.get_match_def(ci2, id)["boss_max_hp"] < 100, "%s (breaker) HP is below 100" % id)


func _test_pools(cfg: ChaptersConfig, region: String) -> void:
	var ci: int = cfg.region_index(region)
	var ids: Array[String] = cfg.match_ids(ci)
	var bad: Array[String] = []
	var kinds_seen: Dictionary = {}
	for floor: int in cfg.world_floors():
		for seed_value: int in MAP_SEEDS:
			var map: Array[Dictionary] = cfg.generate_region_map(region, seed_value, floor, 0)
			for column: Dictionary in map:
				for node: Variant in column.get("nodes", []) as Array:
					var kind: String = str((node as Dictionary).get("kind", ""))
					if not FIGHT_KINDS.has(kind):
						continue
					kinds_seen[kind] = true
					var mid: String = str((node as Dictionary).get("match_id", ""))
					if not ids.has(mid):
						bad.append("f%d s%d %s '%s'" % [floor + 1, seed_value, kind, mid])
	check(bad.is_empty(), "%s: every fight node of floors 1-5 has a match of the region %s" % [region, bad.slice(0, 5)])
	check(kinds_seen.has("battle") and kinds_seen.has("boss") and kinds_seen.has("miniboss"), "%s: battle, miniboss and boss nodes appear (%s)" % [region, kinds_seen.keys()])


func _test_arenas(arenas: ArenaLibrary) -> void:
	var pieces: PieceLibrary = PieceLibrary.load_from_file()
	for id: String in NEW_ARENAS:
		var shape: Dictionary = arenas.get_shape(id)
		check(not shape.is_empty(), "arena %s loads (passed ArenaValidator)" % id)
		if shape.is_empty():
			continue
		var verdict: Dictionary = ArenaValidator.validate(shape, arenas.rules)
		check(bool(verdict["ok"]), "arena %s validates %s" % [id, verdict["reasons"]])
		var f: Dictionary = arenas.featured_for_shape(id)
		check(not f.is_empty(), "arena %s has a featured shape" % id)
		if f.is_empty():
			continue
		var cells: Array[Vector2i] = f["cells"]
		check(cells.size() >= 5 and cells.size() <= 7, "arena %s featured shape has 5-7 cells" % id)
		check(FeaturedShape.pair_compositions(pieces, cells).size() >= 2, "arena %s featured from >= 2 piece pairs" % id)
		var want_effect: String = "burn" if HELL_ARENAS.has(id) else "pin"
		check(str(f["bonus"]["effect"]) == want_effect, "arena %s featured bonus %s" % [id, want_effect])
		var grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": id}, arenas, 0)
		check(PiecePlacement.has_any_placement(grid, Piece.make("featured", cells)), "arena %s featured shape fits the enemy half" % id)
	var forge: Dictionary = arenas.get_shape("forge")
	var caldera: Dictionary = arenas.get_shape("caldera")
	var fv: Dictionary = (forge["hazards"] as Dictionary)["vents"]
	var cv: Dictionary = (caldera["hazards"] as Dictionary)["vents"]
	check((fv["player"] as Array).size() == 2 and (fv["enemy"] as Array).size() == 2, "forge: 2 row vents per half")
	check((cv["player"] as Array).size() == 2 and (cv["enemy"] as Array).size() == 2, "caldera: 2 column vents per half")
	check(not (caldera["missing_cells"] as Array).is_empty(), "caldera has missing centre cells")
	for id: String in ["twin_isles", "three_isles"]:
		check(bool(arenas.get_shape(id).get("crumble", false)), "%s is a crumble arena" % id)
		var grid2: BoardGrid = ArenaLibrary.grid_for_spec({"shape": id}, arenas, 0)
		check(ArenaValidator.island_cells(grid2, true).size() >= 2 and _min_island(grid2, true) >= 2, "%s: >= 2 islands (bridge cells removed), each >= 2 cells" % id)
	check(ArenaValidator.island_cells(ArenaLibrary.grid_for_spec({"shape": "three_isles"}, arenas, 0), true).size() == 3, "three_isles has 3 islands")
	check(not bool(arenas.get_shape("islands_bridge").get("crumble", false)), "islands_bridge itself is unchanged (no crumble key)")
	var bridge_grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "islands_bridge"}, arenas, 0)
	check(ArenaValidator.bridge_cells(bridge_grid, true) == ([Vector2i(2, 1)] as Array[Vector2i]) and ArenaValidator.island_cells(bridge_grid, true).size() == 2,
		"islands_bridge: one bridge cell (2, 1), two islands")
	check(ArenaValidator.bridge_cells(ArenaLibrary.grid_for_spec({"shape": "twin_isles"}, arenas, 0), false) == ([Vector2i(9, 1)] as Array[Vector2i]),
		"twin_isles: the enemy half has the mirrored bridge cell")
	check(ArenaValidator.island_cells(ArenaLibrary.grid_for_spec({"shape": "forge"}, arenas, 0), true).size() == 1, "an arena without a bridge has one island")
	var sizes: Array[int] = []
	for island: Variant in ArenaValidator.island_cells(ArenaLibrary.grid_for_spec({"shape": "three_isles"}, arenas, 0), true):
		sizes.append((island as Array).size())
	sizes.sort()
	check(sizes == ([2, 4, 4] as Array[int]), "three_isles: islands of 2, 4 and 4 cells once the 2 bridge cells are removed %s" % [sizes])
	var tsizes: Array[int] = []
	for island: Variant in ArenaValidator.island_cells(ArenaLibrary.grid_for_spec({"shape": "twin_isles"}, arenas, 0), false):
		tsizes.append((island as Array).size())
	tsizes.sort()
	check(tsizes == ([4, 9] as Array[int]), "twin_isles: boss half islands of 4 and 9 cells %s" % [tsizes])
	var three_grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "three_isles"}, arenas, 0)
	check(ArenaValidator.bridges_in(three_grid.player_cells()) == ArenaValidator.bridge_cells(three_grid, true) and ArenaValidator.bridge_cells(three_grid, true).size() == 2,
		"bridges_in(cells) agrees with bridge_cells(grid): 2 bridges on three_isles")


func _min_island(grid: BoardGrid, player_half: bool) -> int:
	var smallest: int = 1000
	for island: Variant in ArenaValidator.island_cells(grid, player_half):
		smallest = mini(smallest, (island as Array).size())
	return smallest


func _test_hazards(cfg: ChaptersConfig, arenas: ArenaLibrary) -> void:
	for id: String in HELL_ARENAS:
		var grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": id}, arenas, 0)
		var h: Dictionary = ArenaLibrary.hazards_for_match({"arena": {"shape": id}}, grid, arenas)
		var vp: Array = h["vents_player"]
		var ve: Array = h["vents_enemy"]
		check(vp.size() == 2 and ve.size() == 2 and not bool(h["crumble"]), "%s: 2 vents per half, no crumble" % id)
		var ok: bool = true
		for cells: Variant in vp:
			for c: Vector2i in cells as Array:
				ok = ok and grid.is_player_cell(c)
		for cells: Variant in ve:
			for c: Vector2i in cells as Array:
				ok = ok and grid.is_enemy_cell(c)
		check(ok, "%s: vent cells are real cells of the right half" % id)
		var mirrored: bool = true
		for i: int in vp.size():
			var a: Array[Vector2i] = []
			a.assign(vp[i])
			var b: Array[Vector2i] = []
			for c: Vector2i in a:
				b.append(Vector2i(grid.total_cols - 1 - c.x, c.y))
			var want: Array = b.duplicate()
			want.sort()
			var got: Array = (ve[i] as Array).duplicate()
			got.sort()
			mirrored = mirrored and want == got
		check(mirrored, "%s: enemy vents mirror the player vents (side coordinates)" % id)
		var a1: Dictionary = ArenaLibrary.hazards_for_match({"arena": {"shape": id}}, grid, arenas)
		check(a1 == h, "%s: same call, same hazards" % id)
	var forge_grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "forge"}, arenas, 0)
	var fh: Dictionary = ArenaLibrary.hazards_for_match({"arena": {"shape": "forge"}}, forge_grid, arenas)
	check((fh["vents_player"] as Array)[0] == ([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i]), "forge: the row-0 vent is the whole row 0 of the half")
	var cal: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "caldera"}, arenas, 0)
	var ch: Dictionary = ArenaLibrary.hazards_for_match({"arena": {"shape": "caldera"}}, cal, arenas)
	check((ch["vents_player"] as Array)[1] == ([Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)] as Array[Vector2i]), "caldera: the col-4 vent is the whole side column 4 (real cells only)")
	# Every sky_isles match runs on a crumble arena; hellfire matches never do.
	var s: int = cfg.region_index("sky_isles")
	for id: String in SKY_HP.keys():
		var m: Dictionary = cfg.get_match_def(s, id)
		var grid2: BoardGrid = ArenaLibrary.grid_for_spec(m["arena"] as Dictionary, arenas, 0)
		check(grid2 != null and bool(ArenaLibrary.hazards_for_match(m, grid2, arenas)["crumble"]), "sky_isles %s: crumble arena" % id)
	var hf: int = cfg.region_index("hellfire")
	for id: String in HELL_HP.keys():
		var m2: Dictionary = cfg.get_match_def(hf, id)
		var grid3: BoardGrid = ArenaLibrary.grid_for_spec(m2["arena"] as Dictionary, arenas, 0)
		var h3: Dictionary = ArenaLibrary.hazards_for_match(m2, grid3, arenas)
		check(not bool(h3["crumble"]) and not (h3["vents_player"] as Array).is_empty(), "hellfire %s: vents, no crumble" % id)
	# islands_bridge crumbles only where a match says so.
	var br: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "islands_bridge"}, arenas, 0)
	check(not bool(ArenaLibrary.hazards_for_match({"arena": {"shape": "islands_bridge"}}, br, arenas)["crumble"]), "islands_bridge without the match key: no crumble")
	check(bool(ArenaLibrary.hazards_for_match({"arena": {"shape": "islands_bridge", "crumble": true}}, br, arenas)["crumble"]), "islands_bridge with the match key: crumble")
	var sq: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "square"}, arenas, 0)
	var none: Dictionary = ArenaLibrary.hazards_for_match({"arena": {"shape": "square"}}, sq, arenas)
	check((none["vents_player"] as Array).is_empty() and (none["vents_enemy"] as Array).is_empty() and not bool(none["crumble"]), "a shape without hazards gives no vents, no crumble")
	var direct: Dictionary = {"side_cols": 3, "side_rows": 3, "missing_cells": [], "hazards": {"vents": {"enemy": [{"col": 0}]}}, "crumble": true}
	var dh: Dictionary = ArenaLibrary.hazards_for_match({"arena": direct}, sq, arenas)
	check((dh["vents_player"] as Array).is_empty() and (dh["vents_enemy"] as Array) == [[Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)]] and bool(dh["crumble"]),
		"a direct arena block: enemy col 0 is the far board column, crumble from the block")


func _test_validator(arenas: ArenaLibrary) -> void:
	var base: Dictionary = {"id": "x", "side_cols": 3, "side_rows": 3, "missing_cells": []}
	var good: Dictionary = base.duplicate(true)
	good["hazards"] = {"vents": {"player": [{"row": 0}, {"col": 2}], "enemy": [{"row": 2}]}}
	good["crumble"] = true
	check(bool(ArenaValidator.validate(good, arenas.rules)["ok"]), "validator: a valid vents + crumble block passes")
	var off_board: Dictionary = base.duplicate(true)
	off_board["hazards"] = {"vents": {"player": [{"row": 5}]}}
	check(not bool(ArenaValidator.validate(off_board, arenas.rules)["ok"]), "validator: a vent line with no real cell is rejected")
	var only_hole: Dictionary = {"id": "x", "side_cols": 3, "side_rows": 3, "missing_cells": [[2, 0]], "hazards": {"vents": {"player": [{"row": 0}]}}}
	check(bool(ArenaValidator.validate(only_hole, arenas.rules)["ok"]), "validator: a vent line keeps only the real cells (row 0 has 2)")
	var bad_line: Dictionary = base.duplicate(true)
	bad_line["hazards"] = {"vents": {"player": [{"row": 0, "col": 1}]}}
	check(not bool(ArenaValidator.validate(bad_line, arenas.rules)["ok"]), "validator: a line with both row and col is rejected")
	var bad_key: Dictionary = base.duplicate(true)
	bad_key["hazards"] = {"vents": {"both": [{"row": 0}]}}
	check(not bool(ArenaValidator.validate(bad_key, arenas.rules)["ok"]), "validator: unknown vents key rejected")
	var lonely: Dictionary = {"id": "x", "side_cols": 4, "side_rows": 3, "missing_cells": [[1, 0], [1, 2], [0, 0], [0, 2]], "crumble": true}
	check(str(ArenaValidator.validate(lonely, arenas.rules)["reasons"]).contains("island"), "validator: a crumble arena with a 1-cell island is rejected")
	var bad_type: Dictionary = base.duplicate(true)
	bad_type["crumble"] = 1
	check(not bool(ArenaValidator.validate(bad_type, arenas.rules)["ok"]), "validator: non-bool crumble rejected")
	# Every shipped shape is still valid with the extended validator (a regression guard on the old arenas).
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/arenas.json"))
	var all_ok: bool = true
	for entry: Variant in raw["shapes"] as Array:
		all_ok = all_ok and arenas.get_shape(str((entry as Dictionary)["id"])).size() > 0
	check(all_ok, "every shape in arenas.json is accepted by the library")


func _test_strings() -> void:
	var rows: Dictionary = {}
	var file: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3:
			rows[row[0]] = row
	var keys: Array[String] = []
	for id: String in ["hellfire", "sky_isles"]:
		for which: String in ["name", "intro", "end"]:
			keys.append("chapter.%s.%s" % [id, which])
		keys.append("region.%s.desc" % id)
	for id: String in HELL_HP.keys() + SKY_HP.keys():
		keys.append("boss.%s.name" % id)
	for id: String in ["fire_eater", "ash_phoenix", "inferno_lord", "gale_bird", "cloud_veil", "storm_dragon"]:
		keys.append("match.%s.desc" % id)
	for id: String in NEW_TRAITS:
		keys.append("trait.%s.name" % id)
		keys.append("trait.%s.desc" % id)
	for id: String in NEW_ARENAS:
		keys.append(str(ArenaNames.NAMES.get(id, "")))
	for id: String in ["reach_floor_4", "reach_floor_5"]:
		keys.append("achievement.%s.name" % id)
		keys.append("achievement.%s.desc" % id)
	var missing: Array[String] = []
	for key: String in keys:
		if not rows.has(key) or str(rows[key][1]).is_empty() or str(rows[key][2]).is_empty():
			missing.append(key)
	check(missing.is_empty(), "every new string key has vi + en (%d keys) %s" % [keys.size(), missing])
	check(str(rows.get("chapter.hellfire.name", ["", ""])[1]) == "Thành Hỏa Ngục", "vi has real diacritics")
	check(str(rows.get("trait.burn_eater.desc", ["", "", ""])[2]).to_lower().contains("burn") and str(rows.get("trait.shroud.desc", ["", "", ""])[2]).to_lower().contains("forecast"),
		"burn_eater / shroud descriptions state the rule (en)")


func _test_weights() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pieces.json"))
	var default_pool: Array[String] = []
	for s: Variant in data["shapes"] as Array:
		if str((s as Dictionary).get("pool", "")) != "run_only":
			default_pool.append(str((s as Dictionary)["id"]))
	for region: String in ["hellfire", "sky_isles"]:
		var w: Dictionary = (data["weights"] as Dictionary).get(region, {})
		var ids: Array[String] = []
		for k: Variant in w.keys():
			ids.append(str(k))
		ids.sort()
		var want: Array[String] = default_pool.duplicate()
		want.sort()
		check(ids == want, "weights.%s lists exactly the default-pool shapes" % region)
		for new_shape: String in ["w5", "n5", "v5"]:
			check(float(w[new_shape]) >= 0.125 and float(w[new_shape]) <= 0.25, "weights.%s %s is 0.125-0.25" % [region, new_shape])
	var hf: Dictionary = data["weights"]["hellfire"]
	var sk: Dictionary = data["weights"]["sky_isles"]
	var small_hf: float = float(hf["mono"]) + float(hf["bar2"]) + float(hf["bar3"]) + float(hf["l3"])
	var big_hf: float = float(hf["square"]) + float(hf["t4"]) + float(hf["l4"]) + float(hf["s4"]) + float(hf["bar4"]) + float(hf["plus5"]) + float(hf["u5"]) + float(hf["p5"]) + float(hf["bar5"])
	check(big_hf > small_hf and float(hf["mono"]) >= 8.0 and float(hf["bar2"]) >= 8.0, "hellfire leans 4-5 cell pieces, mono / bar2 >= 8")
	var small_sk: float = float(sk["mono"]) + float(sk["bar2"]) + float(sk["bar3"]) + float(sk["l3"])
	var big_sk: float = float(sk["square"]) + float(sk["t4"]) + float(sk["l4"]) + float(sk["s4"]) + float(sk["bar4"]) + float(sk["plus5"]) + float(sk["u5"]) + float(sk["p5"]) + float(sk["bar5"])
	check(small_sk > 3.0 * big_sk, "sky_isles leans 1-3 cell pieces (%.1f vs %.1f)" % [small_sk, big_sk])


func _test_unlocks() -> void:
	AchievementsConfig.reset_shared()
	var cfg: AchievementsConfig = AchievementsConfig.load_from_file()
	check(cfg.ids().size() == 24, "24 achievements (22 + reach_floor_4 / reach_floor_5), got %d" % cfg.ids().size())
	check(cfg.has("reach_floor_4") and cfg.has("reach_floor_5"), "both reach_floor achievements load")
	check(cfg.reward_owner("region", "hellfire") == "reach_floor_4" and cfg.reward_owner("region", "sky_isles") == "reach_floor_5", "hellfire / sky_isles are rewards of reach_floor_4 / reach_floor_5")
	check(cfg.ids().slice(-2) == (["reach_floor_4", "reach_floor_5"] as Array[String]), "appended after small_deck")
	var progress := ProgressState.new()
	var locked: Dictionary = cfg.locked_content(progress)
	check((locked.get("region", []) as Array).has("hellfire") and (locked.get("region", []) as Array).has("sky_isles"), "both new regions are locked at the start")
	check(UnlockRules.process(cfg, progress, {"type": "match_won"}).is_empty(), "best floor 0: nothing earned")
	progress.record_floor(3)
	check(UnlockRules.process(cfg, progress, {"type": "match_won"}).is_empty(), "best floor 3: nothing earned")
	var p3: Dictionary = UnlockRules.progress_of(cfg, "reach_floor_4", progress)
	check(int(p3["current"]) == 3 and int(p3["target"]) == 4 and not bool(p3["done"]), "progress_of reach_floor_4 at floor 3 = 3/4")
	progress.record_floor(4)
	var earned: Array[String] = UnlockRules.process(cfg, progress, {"type": "run_ended", "won": false})
	check(earned == (["reach_floor_4"] as Array[String]), "best floor 4 earns reach_floor_4 on any event (%s)" % [earned])
	check(cfg.is_unlocked("region", "hellfire", progress) and not cfg.is_unlocked("region", "sky_isles", progress), "hellfire open, sky_isles still locked")
	progress.record_floor(5)
	check(UnlockRules.process(cfg, progress, {"type": "final_reached"}) == (["reach_floor_5"] as Array[String]), "best floor 5 earns reach_floor_5")
	var p5: Dictionary = UnlockRules.progress_of(cfg, "reach_floor_5", progress)
	check(int(p5["current"]) == 5 and int(p5["target"]) == 5 and bool(p5["done"]), "progress_of reach_floor_5 done = 5/5")
	var bad: AchievementsConfig = AchievementsConfig.from_dictionary({"achievements": [
		{"id": "x", "condition": {"type": "best_floor", "params": {}}, "rewards": []},
		{"id": "y", "condition": {"type": "best_floor", "params": {"min": 2}}, "rewards": []}]})
	check(not bad.has("x") and bad.has("y"), "best_floor needs a positive min")


func _test_world(cfg: ChaptersConfig) -> void:
	var pool: Array[String] = cfg.region_ids()
	var all_unique: bool = true
	var deterministic: bool = true
	var seen_new: Dictionary = {}
	for seed_value: int in WORLD_SEEDS:
		var path: Array = _walk(pool, seed_value, cfg.world_floors())
		deterministic = deterministic and path == _walk(pool, seed_value, cfg.world_floors())
		var unique: Dictionary = {}
		for id: Variant in path:
			unique[id] = true
			seen_new[id] = true
		all_unique = all_unique and unique.size() == path.size()
	check(all_unique, "5-floor runs never repeat a region (%d seeds, 7 regions)" % WORLD_SEEDS)
	check(deterministic, "same seed, same region order")
	check(seen_new.has("hellfire") and seen_new.has("sky_isles"), "hellfire and sky_isles are offered")
	# With the two new regions locked (a fresh save) the pool has 5 and a run still never repeats.
	var locked_pool: Array[String] = []
	for id: String in pool:
		if id != "hellfire" and id != "sky_isles":
			locked_pool.append(id)
	var locked_ok: bool = true
	for seed_value: int in WORLD_SEEDS:
		var path2: Array = _walk(locked_pool, seed_value, cfg.world_floors())
		var unique2: Dictionary = {}
		for id: Variant in path2:
			unique2[id] = true
		locked_ok = locked_ok and unique2.size() == path2.size()
	check(locked_ok, "a 5-region pool (new regions locked) still never repeats in a run")


## Picks the first offered region not yet visited (else the first offered) at every floor.
func _walk(pool: Array[String], seed_value: int, floors: int) -> Array:
	var path: Array = []
	for floor: int in floors:
		var offer: Array[String] = WorldMapGen.offer_for_floor(pool, seed_value, floor, path)
		var pick: String = offer[0]
		for id: String in offer:
			if not path.has(id):
				pick = id
				break
		path.append(pick)
	return path

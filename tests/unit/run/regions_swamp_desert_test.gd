extends SceneTree
## Story 036 Parts B, C, D (data half, W2): the `swamp` and `desert` regions load and are in the world
## pool (`an_dai` is not); every match id of the contract exists with the story's HP; the pools cover every
## node the map generator makes on floors 1-5; the four new arenas pass ArenaValidator (leave-a-path for
## mire, featured shape from >= 2 piece pairs); `ArenaLibrary.hazards_for_match` returns cells of the right
## half (never missing, never a start cell, at most half of the half); every new string key has vi + en;
## `weights.swamp` / `weights.desert` list only default-pool shapes; the world offer never repeats a
## region in a 5-floor run (20 seeds, same seed same order). Headless; FAILS=N.

## Contract match ids -> the story's floor-1 HP (the exact numbers ARE the spec here).
const SWAMP_HP: Dictionary = {
	"bog_rat": 88, "mire_slug": 104, "swamp_lizard": 112, "marsh_toad": 126, "reed_witch": 138, "bog_hound": 150,
	"spore_cap": 70, "leap_frog": 80, "toad_matriarch": 170,
}
const DESERT_HP: Dictionary = {
	"dune_jackal": 90, "sand_beetle": 106, "dust_nomad": 116, "mirage_sprite": 124, "scarab_guard": 140, "sun_archer": 152,
	"sand_burrower": 84, "scorpion": 96, "sand_sphinx": 175,
}
## Contract trait id of each breaker / boss.
const TRAITS: Dictionary = {
	"spore_cap": "spore_burst", "leap_frog": "hop_skip", "toad_matriarch": "bog_spread",
	"sand_burrower": "burrow", "scorpion": "riposte", "sand_sphinx": "sandstorm",
}
const SWAMP_ARENAS: Array[String] = ["bog", "reed_maze"]
const DESERT_ARENAS: Array[String] = ["dunes", "oasis"]
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
	_test_matches(cfg, "swamp", SWAMP_HP, arenas)
	_test_matches(cfg, "desert", DESERT_HP, arenas)
	_test_pools(cfg, "swamp")
	_test_pools(cfg, "desert")
	_test_arenas(arenas)
	_test_hazards(arenas)
	_test_clean_match()
	_test_strings()
	_test_weights()
	_test_world(cfg)
	print("FAILS=%d" % fails)
	quit(fails)


func _test_regions(cfg: ChaptersConfig) -> void:
	var pool: Array[String] = cfg.region_ids()
	check(pool == (["ch1", "ch2", "ch3", "swamp", "desert"] as Array[String]), "region_pool = ch1 ch2 ch3 swamp desert (%s)" % [pool])
	check(not pool.has("an_dai"), "an_dai is not in the pool")
	for id: String in ["swamp", "desert"]:
		var ci: int = cfg.region_index(id)
		check(ci >= 0, "%s loads as a chapter" % id)
		check(cfg.chapter_text_key(ci, "intro") != "" or not cfg.region_spec(id, 0).is_empty(), "%s has a region spec" % id)
		var spec: Dictionary = cfg.region_spec(id, 0)
		check(str(spec.get("name_key")) == "chapter.%s.name" % id, "%s name_key" % id)
		check(str(spec.get("intro_key")) == "chapter.%s.intro" % id and str(spec.get("end_key")) == "chapter.%s.end" % id, "%s intro / end keys" % id)


func _test_matches(cfg: ChaptersConfig, region: String, hp: Dictionary, arenas: ArenaLibrary) -> void:
	var ci: int = cfg.region_index(region)
	var allowed: Array[String] = SWAMP_ARENAS if region == "swamp" else DESERT_ARENAS
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
			var ids: Array[String] = []
			for t: Variant in m["traits"] as Array:
				ids.append(str((t as Dictionary).get("id", "")))
			check(ids.has(str(TRAITS[id])), "%s: trait %s" % [id, TRAITS[id]])
	var mat: Dictionary = cfg.get_match_def(ci, "toad_matriarch") if region == "swamp" else {}
	if region == "swamp":
		check(bool(mat.get("mire_immune", false)) and bool(cfg.get_match_def(ci, "mire_slug").get("mire_immune", false)), "mire_immune on toad_matriarch and mire_slug")
		check(not cfg.get_match_def(ci, "bog_rat").has("mire_immune"), "absent mire_immune stays absent")
		check(str(mat["brain_set"]) == "aggressive", "toad_matriarch is aggressive")
	else:
		var sphinx: Dictionary = cfg.get_match_def(ci, "sand_sphinx")
		check(int(sphinx["boss_min_runes"]) == 3 and str(sphinx["brain_set"]) == "balanced", "sand_sphinx balanced, boss_min_runes 3")
		check(is_equal_approx(float(cfg.get_match_def(ci, "scarab_guard")["boss_defense"]), 2.0), "scarab_guard boss_defense 2 (tuned from 3, simulation-regions.md)")


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
	for id: String in SWAMP_ARENAS + DESERT_ARENAS:
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
		var pairs: Array = FeaturedShape.pair_compositions(pieces, cells)
		check(pairs.size() >= 2, "arena %s featured from >= 2 piece pairs %s" % [id, pairs])
		var want_effect: String = "pin" if SWAMP_ARENAS.has(id) else "fragile"
		check(str(f["bonus"]["effect"]) == want_effect, "arena %s featured bonus %s" % [id, want_effect])
		var grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": id}, arenas, 0)
		check(PiecePlacement.has_any_placement(grid, Piece.make("featured", cells)), "arena %s featured shape fits the enemy half" % id)
	var bad_mire: Dictionary = {"id": "x", "side_cols": 3, "side_rows": 3, "missing_cells": [], "hazards": {"mire": {"per_side": 5}}}
	check(not bool(ArenaValidator.validate(bad_mire, arenas.rules)["ok"]), "validator: mire per_side above half of a half is rejected")
	var ring_start: Dictionary = {"id": "x", "side_cols": 3, "side_rows": 3, "missing_cells": [],
		"hazards": {"mire": {"player": [[0, 1], [1, 0], [1, 2], [2, 1]]}}}
	check(not bool(ArenaValidator.validate(ring_start, arenas.rules)["ok"]), "validator: mire ringing the start cell is rejected (leave-a-path)")
	var bad_key: Dictionary = {"id": "x", "side_cols": 3, "side_rows": 3, "missing_cells": [], "hazards": {"lava": true}, "wind": 1}
	check((ArenaValidator.validate(bad_key, arenas.rules)["reasons"] as Array).size() == 2, "validator: unknown hazard key and non-bool wind rejected")
	var good: Dictionary = {"id": "x", "side_cols": 3, "side_rows": 3, "missing_cells": [], "hazards": {"mire": {"player": [[0, 0]], "enemy": [[0, 0]]}, "sand": true}, "wind": true}
	check(bool(ArenaValidator.validate(good, arenas.rules)["ok"]), "validator: a valid hazards block passes")
	check(ArenaValidator.featured_reasons([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i], 2, pieces).is_empty() == (FeaturedShape.pair_compositions(pieces, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i]).size() >= 2), "featured_reasons agrees with pair_compositions")


func _test_hazards(arenas: ArenaLibrary) -> void:
	for id: String in SWAMP_ARENAS + DESERT_ARENAS:
		var shape: Dictionary = arenas.get_shape(id)
		var mire_per_side: int = int(((shape.get("hazards", {}) as Dictionary).get("mire", {}) as Dictionary).get("per_side", 0))
		for variant: bool in [false, true]:
			for seed_value: int in 10:
				var spec: Dictionary = {"shape": id, "variant": variant}
				var grid: BoardGrid = ArenaLibrary.grid_for_spec(spec, arenas, seed_value)
				var h: Dictionary = ArenaLibrary.hazards_for_match({"arena": spec, "arena_seed": seed_value}, grid, arenas)
				var label: String = "%s%s seed %d" % [id, " variant" if variant else "", seed_value]
				var mp: Array[Vector2i] = h["mire_player"]
				var me: Array[Vector2i] = h["mire_enemy"]
				var ok: bool = true
				for c: Vector2i in mp:
					ok = ok and grid.is_player_cell(c) and c != grid.default_player_cell()
				for c: Vector2i in me:
					ok = ok and grid.is_enemy_cell(c) and c != grid.default_enemy_cell()
				ok = ok and mp.size() <= grid.player_cells().size() / 2 and me.size() <= grid.enemy_cells().size() / 2
				ok = ok and ArenaValidator.leaves_path(grid, grid.default_player_cell(), mp, true)
				ok = ok and ArenaValidator.leaves_path(grid, grid.default_enemy_cell(), me, false)
				check(ok, "%s: mire cells on the right half, real, off the start cell, leave a path" % label)
				if SWAMP_ARENAS.has(id):
					check(mp.size() == mire_per_side and me.size() == mire_per_side and not bool(h["sand"]) and not bool(h["wind"]),
						"%s: %d mire cells per side, no sand / wind" % [label, mire_per_side])
				else:
					check(mp.is_empty() and me.is_empty() and bool(h["sand"]) and bool(h["wind"]), "%s: sand + wind, no mire" % label)
		var g0: BoardGrid = ArenaLibrary.grid_for_spec({"shape": id}, arenas, 3)
		var a: Dictionary = ArenaLibrary.hazards_for_match({"arena": {"shape": id}, "arena_seed": 3}, g0, arenas)
		var b: Dictionary = ArenaLibrary.hazards_for_match({"arena": {"shape": id}, "arena_seed": 3}, g0, arenas)
		check(a == b, "%s: same seed, same hazards" % id)
	var sq: BoardGrid = ArenaLibrary.grid_for_spec({"shape": "square"}, arenas, 0)
	var none: Dictionary = ArenaLibrary.hazards_for_match({"arena": {"shape": "square"}}, sq, arenas)
	check((none["mire_player"] as Array).is_empty() and (none["mire_enemy"] as Array).is_empty() and not bool(none["sand"]) and not bool(none["wind"]),
		"a shape without hazards gives empty / false")
	check(not bool(ArenaLibrary.hazards_for_match({}, sq)["wind"]), "no arena block gives empty / false (default library)")
	var direct: Dictionary = {"side_cols": 3, "side_rows": 3, "missing_cells": [], "hazards": {"mire": {"player": [[0, 0]], "enemy": [[0, 0]]}}}
	var dh: Dictionary = ArenaLibrary.hazards_for_match({"arena": direct}, sq, arenas)
	check(dh["mire_player"] == ([Vector2i(0, 0)] as Array[Vector2i]) and dh["mire_enemy"] == ([Vector2i(5, 0)] as Array[Vector2i]),
		"explicit mire lists are side coordinates, mirrored onto the enemy half")


func _test_clean_match() -> void:
	var m: Dictionary = RunConfig.clean_match({"id": "t", "mire_immune": true, "drift_sec": 1.5, "sand_cells": 3}, 0)
	check(bool(m.get("mire_immune", false)) and is_equal_approx(float(m["drift_sec"]), 1.5) and int(m["sand_cells"]) == 3,
		"clean_match passes mire_immune and hazard overrides through")
	var plain: Dictionary = RunConfig.clean_match({"id": "t"}, 0)
	var leaked: bool = plain.has("mire_immune")
	for key: String in RunConfig.HAZARD_OVERRIDE_KEYS:
		leaked = leaked or plain.has(key)
	check(not leaked and RunConfig.HAZARD_OVERRIDE_KEYS.size() == 10, "absent hazard keys stay absent (10 override keys)")


func _test_strings() -> void:
	var rows: Dictionary = {}
	var file: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3:
			rows[row[0]] = row
	var keys: Array[String] = []
	for id: String in ["swamp", "desert"]:
		for which: String in ["name", "intro", "end"]:
			keys.append("chapter.%s.%s" % [id, which])
	for id: String in SWAMP_HP.keys() + DESERT_HP.keys():
		keys.append("boss.%s.name" % id)
	for id: String in ["mire_slug", "spore_cap", "leap_frog", "toad_matriarch", "sand_burrower", "scorpion", "sand_sphinx"]:
		keys.append("match.%s.desc" % id)
	for id: String in SWAMP_ARENAS + DESERT_ARENAS:
		keys.append(str(ArenaNames.NAMES.get(id, "")))
	var missing: Array[String] = []
	for key: String in keys:
		if not rows.has(key) or str(rows[key][1]).is_empty() or str(rows[key][2]).is_empty():
			missing.append(key)
	check(missing.is_empty(), "every new string key has vi + en (%d keys) %s" % [keys.size(), missing])
	check(str(rows.get("chapter.swamp.name", ["", ""])[1]) == "Đầm Lầy Độc", "vi has real diacritics")


func _test_weights() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pieces.json"))
	var default_pool: Array[String] = []
	for s: Variant in data["shapes"] as Array:
		if str((s as Dictionary).get("pool", "")) != "run_only":
			default_pool.append(str((s as Dictionary)["id"]))
	for region: String in ["swamp", "desert"]:
		var w: Dictionary = (data["weights"] as Dictionary).get(region, {})
		var ids: Array[String] = []
		for k: Variant in w.keys():
			ids.append(str(k))
		ids.sort()
		var want: Array[String] = default_pool.duplicate()
		want.sort()
		check(ids == want, "weights.%s lists exactly the default-pool shapes" % region)
	var sw: Dictionary = data["weights"]["swamp"]
	var de: Dictionary = data["weights"]["desert"]
	check(float(sw["bar2"]) + float(sw["bar3"]) + float(sw["l3"]) > float(sw["square"]) + float(sw["t4"]) + float(sw["l4"]) + float(sw["s4"]) + float(sw["bar4"]),
		"swamp leans 2-3 cell pieces")
	check(float(sw["bar5"]) <= 1.0 and float(sw["plus5"]) <= 1.0, "swamp 5-cell pieces are rare")
	check(float(de["bar4"]) > float(de["square"]) and float(de["bar3"]) > float(de["l3"]) and float(de["bar2"]) > float(de["mono"]), "desert leans bars")


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
	check(all_unique, "5-floor runs never repeat a region (%d seeds)" % WORLD_SEEDS)
	check(deterministic, "same seed, same region order")
	check(seen_new.has("swamp") and seen_new.has("desert"), "swamp and desert are offered")


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

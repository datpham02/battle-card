extends SceneTree
## Story 037 W2: the four locked cards (gai_doc, gai_nguyen, thanh_thuy with `heal_self`, bang_tam), the three
## locked 5-cell shapes (w5, n5, v5) and the `unlock_by` keys on cards / shapes / relics.
## gai_nguyen took the `boss_dungeon` slot of the Wall card luoi_san (quick spec 2026-10-31; luoi_san deleted
## 2026-11-01, ADR-0001 Phase 1).
## Run: godot --headless --path . -s res://tests/unit/run/unlock_content_test.gd   (ends with FAILS=N)

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const HP: float = 1000.0
const NEW_CARDS: Array[String] = ["gai_doc", "gai_nguyen", "thanh_thuy", "bang_tam"]
const NEW_SHAPES: Array[String] = ["w5", "n5", "v5"]
const WEIGHT_SETS: Array[String] = ["default", "ch1", "ch2", "ch3", "swamp", "desert", "hellfire", "sky_isles"]
## Story 039: sky_isles is left out on purpose: its arenas are 2-3 rows tall, so a 5-cell shape that is 4 long (n5) cannot be placed there (such a shape is simply never placed, Story 024).
const REGIONS: Array[String] = ["ch1", "ch2", "ch3", "swamp", "desert", "hellfire"]
const CHAPTERS_PATH: String = "res://assets/data/chapters.json"

var fails: int = 0


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func _init() -> void:
	_card_data()
	_card_behaviour()
	_shapes()
	_unlock_by_keys()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _state() -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), HP, HP, Vector2i(1, 1), Vector2i(4, 1))


func _fx() -> StatusEffects:
	var fx: StatusEffects = StatusEffects.new()
	fx.configure_keywords(1.5, 3, 3, 24.0)
	return fx


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in list:
		out.append(c as Vector2i)
	return out


func _card_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	for id: String in NEW_CARDS:
		ck("%s: loaded, implemented, in card_order" % id, sc.has_skill(id) and bool(sc.get_skill(id)["implemented"])
			and sc.card_order.has(id) and sc.is_player_card(id))
	ck("the deleted Wall card luoi_san is gone", not sc.has_skill("luoi_san"))
	var d: Dictionary = sc.get_skill("gai_doc")
	ck("gai_doc: common thorns 3 cells, 2 dmg/cell, 2 Ran per entry (trap role, 2026-11-05), cd 6",
		d["rarity"] == "common" and d["effect"] == "thorns" and d["min_cells"] == 3 and is_equal_approx(float(d["damage_per_cell"]), 2.0)
		and int(d["thorn_fragile_stacks"]) == 2 and is_equal_approx(float(d["cooldown_sec"]), 6.0))
	d = sc.get_skill("gai_nguyen")
	ck("gai_nguyen: rare thorns 4 cells, 0 dmg/cell, 3 Ran per entry (full Ran, 2026-11-05), cd 8",
		d["rarity"] == "rare" and d["effect"] == "thorns" and d["min_cells"] == 4 and is_equal_approx(float(d["damage_per_cell"]), 0.0)
		and int(d["thorn_fragile_stacks"]) == 3 and is_equal_approx(float(d["cooldown_sec"]), 8.0))
	d = sc.get_skill("thanh_thuy")
	ck("thanh_thuy: common frost 3 cells, 1 Han, heal_self 4, cd 6",
		d["rarity"] == "common" and d["effect"] == "frost" and d["min_cells"] == 3 and int(d["frost_stacks"]) == 1
		and is_equal_approx(float(d["heal_self"]), 4.0) and is_equal_approx(float(d["cooldown_sec"]), 6.0))
	d = sc.get_skill("bang_tam")
	ck("bang_tam: rare damage 4 cells, 5 dmg/cell, 2 Han, cd 6",
		d["rarity"] == "rare" and d["effect"] == "damage" and d["min_cells"] == 4 and is_equal_approx(float(d["damage_per_cell"]), 5.0)
		and int(d["frost_stacks"]) == 2 and is_equal_approx(float(d["cooldown_sec"]), 6.0))
	ck("only thanh_thuy heals (heal_self defaults to 0)", is_equal_approx(float(sc.get_skill("kiem_khi")["heal_self"]), 0.0) and is_equal_approx(float(sc.get_skill("bang_tam")["heal_self"]), 0.0))
	ck("gai_doc and gai_nguyen are zone cards (kept out of the boss list)", sc.is_zone_card("gai_doc") and sc.is_zone_card("gai_nguyen")
		and not sc.boss_card_order().has("gai_doc") and not sc.boss_card_order().has("gai_nguyen")
		and sc.boss_card_order().has("thanh_thuy") and sc.boss_card_order().has("bang_tam"))
	var rows: Dictionary = _csv_rows()
	var strings_ok: bool = true
	for id: String in NEW_CARDS:
		for k: String in ["card.%s.name" % id, "card.%s.desc" % id]:
			var r: Array = rows.get(k, ["", ""])
			if str(r[0]).is_empty() or str(r[1]).is_empty():
				strings_ok = false
				print("missing csv ", k)
	for id: String in NEW_SHAPES:
		var r: Array = rows.get("piece.%s.name" % id, ["", ""])
		if str(r[0]).is_empty() or str(r[1]).is_empty():
			strings_ok = false
			print("missing csv piece.", id)
	ck("vi + en strings for the 4 cards and 3 shapes", strings_ok)


func _card_behaviour() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cc: CutConfig = CutConfig.new()
	# thanh_thuy: heals the caster by 4 on a HIT.
	var st: CombatState = _state()
	st.set_player_hp(100.0)
	var fx: StatusEffects = _fx()
	var res: Dictionary = CutEffects.apply(st, st.grid, P, _cells([Vector2i(4, 1), Vector2i(4, 0), Vector2i(3, 1)]), "thanh_thuy", cc, sc, fx)
	ck("thanh_thuy hit: caster +4 HP, 1 Han on the boss", res["hit"] and is_equal_approx(st.player_hp, 104.0) and is_equal_approx(float(res["healed"]), 4.0) and fx.frost_stacks(E) == 1)
	# ... and on a MISS (boss not in the cells): still heals, no Han.
	var st2: CombatState = _state()
	st2.set_player_hp(100.0)
	var fx2: StatusEffects = _fx()
	var miss: Dictionary = CutEffects.apply(st2, st2.grid, P, _cells([Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)]), "thanh_thuy", cc, sc, fx2)
	ck("thanh_thuy miss: still heals 4, no Han", not miss["hit"] and is_equal_approx(st2.player_hp, 104.0) and fx2.frost_stacks(E) == 0)
	# Capped at max HP.
	var st3: CombatState = _state()
	st3.set_player_hp(HP - 1.0)
	CutEffects.apply(st3, st3.grid, P, _cells([Vector2i(4, 1), Vector2i(4, 0), Vector2i(3, 1)]), "thanh_thuy", cc, sc, _fx())
	ck("thanh_thuy: heal is capped at max HP", is_equal_approx(st3.player_hp, HP))
	var full: Dictionary = CutEffects.apply(st3, st3.grid, P, _cells([Vector2i(4, 1), Vector2i(4, 0), Vector2i(3, 1)]), "thanh_thuy", cc, sc, _fx())
	ck("thanh_thuy at full HP: nothing healed", is_equal_approx(float(full["healed"]), 0.0) and is_equal_approx(st3.player_hp, HP))
	# A boss swing never heals the boss with it (heal_self is the caster's, player side only).
	var st4: CombatState = _state()
	st4.set_player_hp(500.0)
	st4.damage_enemy(300.0)
	var boss_hp: float = st4.enemy_hp
	CutEffects.apply(st4, st4.grid, E, _cells([Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1)]), "thanh_thuy", cc, sc, _fx())
	ck("a boss casting thanh_thuy heals nobody", is_equal_approx(st4.enemy_hp, boss_hp) and is_equal_approx(st4.player_hp, 500.0 - 0.0))
	# gai_nguyen: thorns form on the boss half on a hit (no damage, 3 Ran per entry since 2026-11-05) and on a miss.
	var st5: CombatState = _state()
	var fx5: StatusEffects = _fx()
	var zone_cells: Array[Vector2i] = _cells([Vector2i(4, 1), Vector2i(4, 0), Vector2i(3, 1), Vector2i(3, 0)])
	var opts: Dictionary = {"zones": {"seal_sec": 1.2, "thorn_sec": 3.0, "thorn_damage": 6.0, "thorn_fragile_stacks": 1}}
	var hit: Dictionary = CutEffects.apply(st5, st5.grid, P, zone_cells, "gai_nguyen", cc, sc, fx5, Callable(), 1, Callable(), Callable(), opts)
	ck("gai_nguyen hit: thorns formed (3 Ran per entry), no damage",
		hit["hit"] and hit["zone_kind"] == "thorns" and not (hit["zone_cells"] as Array).is_empty()
		and int(fx5.thorns_at(E, Vector2i(3, 0)).get("fragile_stacks", -1)) == 3 and is_equal_approx(st5.enemy_hp, HP))
	var st6: CombatState = _state()
	var fx6: StatusEffects = _fx()
	var mmiss: Dictionary = CutEffects.apply(st6, st6.grid, P, _cells([Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(3, 2)]), "gai_nguyen", cc, sc, fx6, Callable(), 1, Callable(), Callable(), opts)
	ck("gai_nguyen miss: thorns still form", not mmiss["hit"] and mmiss["zone_kind"] == "thorns" and fx6.thorn_cells(E).size() == 4)
	# gai_doc: thorns form (hit or miss), 2 dmg per cell on a hit (3 cells = 6).
	var st7: CombatState = _state()
	var fx7: StatusEffects = _fx()
	var gd: Dictionary = CutEffects.apply(st7, st7.grid, P, _cells([Vector2i(4, 1), Vector2i(4, 0), Vector2i(3, 1)]), "gai_doc", cc, sc, fx7, Callable(), 1, Callable(), Callable(), opts)
	ck("gai_doc hit: thorns formed and 6 damage (3 cells x 2)", gd["hit"] and gd["zone_kind"] == "thorns" and is_equal_approx(float(gd["damage"]), 6.0) and is_equal_approx(st7.enemy_hp, HP - 6.0))
	var st8: CombatState = _state()
	var gm: Dictionary = CutEffects.apply(st8, st8.grid, P, _cells([Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)]), "gai_doc", cc, sc, _fx(), Callable(), 1, Callable(), Callable(), opts)
	ck("gai_doc miss: thorns formed, no damage", not gm["hit"] and gm["zone_kind"] == "thorns" and is_equal_approx(st8.enemy_hp, HP))
	# bang_tam: 4 cells x 5 = 20 damage, 2 Han stacks.
	var st9: CombatState = _state()
	var fx9: StatusEffects = _fx()
	var bt: Dictionary = CutEffects.apply(st9, st9.grid, P, _cells([Vector2i(4, 1), Vector2i(4, 0), Vector2i(3, 1), Vector2i(3, 0)]), "bang_tam", cc, sc, fx9)
	ck("bang_tam hit: 20 damage and 2 Han", bt["hit"] and is_equal_approx(float(bt["damage"]), 20.0) and fx9.frost_stacks(E) == 2)


func _shapes() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var text: String = FileAccess.get_file_as_string("res://assets/data/pieces.json")
	var raw: Dictionary = JSON.parse_string(text) as Dictionary
	var arenas: ArenaLibrary = ArenaLibrary.load_from_file()
	var region_arenas: Dictionary = _region_arena_shapes()
	var want: Dictionary = {
		"w5": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		"n5": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
		"v5": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
	}
	for id: String in NEW_SHAPES:
		ck("%s: valid shape, 5 cells, in the default pool" % id, lib.has_shape(id) and lib.shape_cells(id).size() == 5 and lib.pool(id) == PieceLibrary.POOL_DEFAULT and lib.base_shape_ids().has(id))
		var cells: Array[Vector2i] = lib.shape_cells(id)
		var expected: Array[Vector2i] = []
		expected.assign(want[id])
		var same: bool = cells.size() == expected.size()
		for c: Vector2i in expected:
			same = same and cells.has(c)
		ck("%s: the intended cells" % id, same)
		ck("%s: name key piece.%s.name" % [id, id], lib.name_key(id) == "piece.%s.name" % id)
		var weights: Dictionary = raw["weights"] as Dictionary
		var all_sets: bool = true
		for set_id: String in WEIGHT_SETS:
			var w: float = float((weights.get(set_id, {}) as Dictionary).get(id, -1.0))
			if w < 0.1 or w > 0.25:
				all_sets = false
				print("weight out of 0.1..0.25 (tuned x0.25 from 0.5..1.0, simulation-characters.md) in ", set_id, " for ", id, ": ", w)
			ck("%s: lib.weight in %s is that entry" % [id, set_id], is_equal_approx(lib.weight(id, set_id), w))
		ck("%s: weight 0.1..0.25 in all 8 weight sets (tuned)" % id, all_sets)
		var piece: Piece = Piece.make(id, cells)
		for region: String in REGIONS:
			var fits: bool = false
			var tried: Array[String] = []
			for shape_id: String in (region_arenas.get(region, []) as Array):
				var grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": shape_id}, arenas, 0)
				tried.append(shape_id)
				if grid != null and PiecePlacement.has_any_placement(grid, piece):
					fits = true
					break
			ck("%s fits an arena of %s (tried %s)" % [id, region, str(tried)], fits)


# region id -> Array of the arena shape ids its matches use (read from chapters.json).
func _region_arena_shapes() -> Dictionary:
	var out: Dictionary = {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHAPTERS_PATH)) as Dictionary
	for chapter: Variant in data.get("chapters", []) as Array:
		var found: Array = []
		_collect_arenas(chapter, found)
		out[str((chapter as Dictionary).get("id", ""))] = found
	return out


func _collect_arenas(node: Variant, found: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		var d: Dictionary = node as Dictionary
		if typeof(d.get("arena")) == TYPE_DICTIONARY and (d["arena"] as Dictionary).has("shape"):
			var shape_id: String = str((d["arena"] as Dictionary)["shape"])
			if not found.has(shape_id):
				found.append(shape_id)
		for key: Variant in d.keys():
			_collect_arenas(d[key], found)
	elif typeof(node) == TYPE_ARRAY:
		for item: Variant in node as Array:
			_collect_arenas(item, found)


func _unlock_by_keys() -> void:
	var cards: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/cards.json")) as Dictionary)["cards"] as Dictionary
	var want_cards: Dictionary = {"gai_doc": "first_region_boss", "gai_nguyen": "boss_dungeon", "thanh_thuy": "boss_frost", "bang_tam": "ending_middle"}
	var cards_ok: bool = true
	for id: String in want_cards.keys():
		cards_ok = cards_ok and str((cards[id] as Dictionary).get("unlock_by", "")) == str(want_cards[id])
	ck("the 4 cards carry unlock_by (gai_nguyen replaces luoi_san, quick spec 2026-10-31)", cards_ok and not cards.has("luoi_san"))
	var shapes: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pieces.json")) as Dictionary)["shapes"] as Array
	var want_shapes: Dictionary = {"w5": "reach_an_dai", "n5": "zone_trap", "v5": "boss_forest"}
	var found: int = 0
	var old_locked: int = 0
	for s: Variant in shapes:
		var sd: Dictionary = s as Dictionary
		if want_shapes.has(str(sd["id"])) and str(sd.get("unlock_by", "")) == str(want_shapes[str(sd["id"])]):
			found += 1
		elif sd.has("unlock_by"):
			old_locked += 1
	ck("the 3 shapes carry unlock_by, no other shape does", found == 3 and old_locked == 0)
	var relics: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/relics.json")) as Dictionary)["relics"] as Array
	var want_relics: Dictionary = {"tui_rong": "first_run_won", "phong_an": "ending_mercy", "gai_ran": "ending_slaughter", "han_ky": "frost_burst_5"}
	var rfound: int = 0
	var rother: int = 0
	for r: Variant in relics:
		var rd: Dictionary = r as Dictionary
		if want_relics.has(str(rd["id"])) and str(rd.get("unlock_by", "")) == str(want_relics[str(rd["id"])]):
			rfound += 1
		elif rd.has("unlock_by"):
			rother += 1
	ck("the 4 relics carry unlock_by, no other relic does", rfound == 4 and rother == 0)
	var rc: RelicConfig = RelicConfig.load_from_file()
	ck("RelicConfig still loads all relics with the new key", rc.relics.size() == relics.size())


# key -> [vi, en] from strings.csv (first row of a key wins).
func _csv_rows() -> Dictionary:
	var out: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	if f == null:
		return out
	f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 3 and not out.has(row[0]):
			out[row[0]] = [row[1], row[2]]
	return out

extends SceneTree
## Story 038 Part B/E: KiepRules. Each rule type applies its number at its own level and NOT below; level 10
## stacks in order with the clamps; the extra trait is seeded and never a duplicate; an unknown type is
## skipped; level 0 changes nothing; set_only. The level of each rule and its numbers are read from the
## shipped data (level_of / param), so reordering the levels in kiep_levels.json needs no test change.

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


func _boss_ctx(is_final: bool = false) -> Dictionary:
	return {"run_seed": 77, "floor": 1, "match_id": "goblin_chief", "node_kind": "boss", "is_final": is_final}


func _raw() -> Dictionary:
	return {"id": "goblin_chief", "boss_max_hp": 130, "swing_speed_mult": 0.9,
			"traits": [{"id": "row_burner", "params": {}}], "arena": {"shape": "square"}}


## The level whose rules hold [param type] (and, for boss_extra_trait, [param scope]); -1 when none.
static func level_of(k: KiepRules, type: String, scope: String = "") -> int:
	for level: int in range(1, k.max_level() + 1):
		for rule: Variant in k.level_def(level)["rules"] as Array:
			var r: Dictionary = rule as Dictionary
			if r["type"] == type and (scope == "" or str((r["params"] as Dictionary).get("scope", "")) == scope):
				return level
	return -1


## The param [param key] of the rule [param type] (+ [param scope]) in the shipped data.
static func param(k: KiepRules, type: String, key: String, scope: String = "") -> Variant:
	for rule: Variant in k.level_def(level_of(k, type, scope))["rules"] as Array:
		var r: Dictionary = rule as Dictionary
		if r["type"] == type and (scope == "" or str((r["params"] as Dictionary).get("scope", "")) == scope):
			return (r["params"] as Dictionary)[key]
	return null


func _initialize() -> void:
	var k: KiepRules = KiepRules.load_from_file()
	var top: int = k.max_level()
	check(top == 10, "shipped file has 10 levels")
	check(KiepRules.shared() == KiepRules.shared(), "shared() is cached")
	check(k.level_def(0).is_empty() and k.level_def(top + 1).is_empty(), "level_def: {} for 0 and out of range")
	var types: Array[String] = []
	for level: int in range(1, top + 1):
		var def: Dictionary = k.level_def(level)
		check(def["name_key"] == "kiep.level.%d.name" % level and def["desc_key"] == "kiep.level.%d.desc" % level
				and not (def["rules"] as Array).is_empty(), "level_def(%d): keys follow the level, has rules" % level)
		for rule: Variant in def["rules"] as Array:
			types.append(str((rule as Dictionary)["type"]) + str(((rule as Dictionary)["params"] as Dictionary).get("scope", "")))
	check(types.size() == 11, "the ten levels hold 11 rules (one level has two)")
	var keys: Array[String] = k.rules_text_keys(3)
	check(keys.size() == 3 and keys[2] == "kiep.level.3.desc" and k.rules_text_keys(0).is_empty(), "rules_text_keys(3) = 3 desc keys")

	var l_trait: int = level_of(k, "boss_extra_trait", KiepRules.SCOPE_REGION_BOSS)
	var l_final: int = level_of(k, "boss_extra_trait", KiepRules.SCOPE_FINAL)
	var l_map: int = level_of(k, "node_weight")
	var l_rest: int = level_of(k, "rest_heal_mult")
	var l_drop: int = level_of(k, "player_drop_mult")
	var l_gold: int = level_of(k, "gold_mult")
	var l_swing: int = level_of(k, "boss_swing_mult")
	var l_floor: int = level_of(k, "floor_heal_mult")
	var l_hp: int = level_of(k, "max_hp_mult")
	var l_shift: int = level_of(k, "floor_shift")
	var l_shop: int = level_of(k, "shop_price_mult")
	check([l_trait, l_final, l_map, l_rest, l_drop, l_gold, l_swing, l_floor, l_hp, l_shift, l_shop].min() >= 1,
			"every rule type sits at a level")
	var rest_mult: float = float(param(k, "rest_heal_mult", "mult"))
	var drop_mult: float = float(param(k, "player_drop_mult", "mult"))
	var gold_mult: float = float(param(k, "gold_mult", "mult"))
	var swing_mult: float = float(param(k, "boss_swing_mult", "mult"))
	var floor_mult: float = float(param(k, "floor_heal_mult", "mult"))
	var hp_mult: float = float(param(k, "max_hp_mult", "mult"))
	var shop_mult: float = float(param(k, "shop_price_mult", "mult"))
	var final_hp: float = float(param(k, "floor_shift", "final_hp_mult"))
	var shift: int = int(param(k, "floor_shift", "shift"))
	check(_near(rest_mult, 0.67) and _near(drop_mult, 1.15) and _near(gold_mult, 0.75) and _near(swing_mult, 0.909)
			and _near(floor_mult, 0.5) and _near(hp_mult, 0.85) and _near(shop_mult, 1.2) and _near(final_hp, 1.1) and shift == 1
			and _near(float(param(k, "node_weight", "mult")), 2.0), "shipped starting numbers (story table)")

	# --- level 0 = equal ---
	var raw: Dictionary = _raw()
	check(k.apply_match(raw, 0, _boss_ctx()) == raw, "apply_match level 0 equals the input")
	var ch: Dictionary = {"id": "x", "max_hp": 200}
	check(k.apply_run_start(ch, 0) == ch, "apply_run_start level 0 equals the input")
	check(_near(k.rest_heal_ratio(0.3, 0), 0.3) and _near(k.floor_heal_ratio(0.25, 0), 0.25), "heal ratios unchanged at level 0")
	check(_near(k.economy_mult("gold", 0), 1.0) and _near(k.economy_mult("shop_price", 0), 1.0), "economy 1.0 at level 0")
	check(k.scaling_floor(2, 0, 5) == 2 and k.final_extra(4, 0, 5).is_empty(), "scaling/final_extra off at level 0")
	var spec: Dictionary = _spec()
	check(k.apply_map_spec(spec, 0) == spec, "apply_map_spec level 0 equals the input")

	# --- boss_extra_trait (region_boss) ---
	var below_t: Dictionary = k.apply_match(raw, l_trait - 1, _boss_ctx())
	var at_t: Dictionary = k.apply_match(raw, l_trait, _boss_ctx())
	check((at_t["traits"] as Array).size() == 2 and below_t["traits"] == raw["traits"],
			"Kiep %d: a region boss gains one trait, not at %d" % [l_trait, l_trait - 1])
	check(((at_t["traits"] as Array)[1] as Dictionary)["id"] != "row_burner", "extra trait is not a duplicate of row_burner")
	check(raw["traits"].size() == 1, "the input match is not modified")
	check(k.apply_match(raw, l_trait, _boss_ctx())["traits"] == at_t["traits"], "same seed -> same extra trait")
	var pool_ids: Array = []
	for t: Variant in param(k, "boss_extra_trait", "trait_pool", KiepRules.SCOPE_REGION_BOSS) as Array:
		pool_ids.append((t as Dictionary)["id"])
	var ids: Dictionary = {}
	for s: int in 40:
		var c: Dictionary = _boss_ctx()
		c["run_seed"] = s
		var t: Array = k.apply_match(raw, l_trait, c)["traits"]
		ids[(t[t.size() - 1] as Dictionary)["id"]] = true
		check_dup(t)
	var in_pool: bool = true
	for id: Variant in ids.keys():
		in_pool = in_pool and pool_ids.has(id)
	check(ids.size() >= 2 and not ids.has("row_burner") and in_pool, "different seeds draw different pool traits (%d kinds)" % ids.size())
	var not_boss: Dictionary = _boss_ctx()
	not_boss["node_kind"] = "fight"
	check(k.apply_match(raw, top, not_boss)["traits"].size() == 1, "a normal fight never gets an extra trait")
	var full: Dictionary = raw.duplicate(true)
	full["traits"] = []
	for id: Variant in pool_ids:
		full["traits"].append({"id": id})
	check(k.apply_match(full, l_trait, _boss_ctx())["traits"].size() == pool_ids.size(), "no duplicate when the whole pool is already on the match")

	# --- boss_extra_trait (final) incl. phased match ---
	var fin: Dictionary = {"id": "an_dai_keeper", "phases": [
			{"traits": [{"id": "seal_caster", "params": {}}]},
			{"at_hp_ratio": 0.5, "traits": [{"id": "seal_caster", "params": {}}, {"id": "row_burner", "params": {}}]}]}
	check(k.apply_match(fin, l_final - 1, _boss_ctx(true))["phases"] == fin["phases"], "Kiep %d: the final's phases unchanged" % (l_final - 1))
	var ftop: Dictionary = k.apply_match(fin, top, _boss_ctx(true))
	var p0: Array = (ftop["phases"] as Array)[0]["traits"]
	var p1: Array = (ftop["phases"] as Array)[1]["traits"]
	check(p0.size() == 2 and p1.size() == 3 and (p0[1] as Dictionary)["id"] == (p1[2] as Dictionary)["id"],
			"Kiep %d+: the final gets ONE extra trait, the same in every phase (the region-boss rule never applies)" % l_final)
	check(k.apply_match(fin, l_final, _boss_ctx(true))["phases"] == ftop["phases"], "the final's phases at Kiep %d = at the top level" % l_final)
	check(not ["seal_caster", "row_burner"].has((p0[1] as Dictionary)["id"]), "the final's extra trait is a new one")
	check((k.apply_match(raw, top, _boss_ctx(false))["traits"] as Array).size() == 2, "top level: a region boss gets only the region-boss trait")

	# --- node_weight ---
	check(k.apply_map_spec(spec, l_map - 1) == spec, "Kiep %d: map spec unchanged" % (l_map - 1))
	var cols: Array = k.apply_map_spec(spec, l_map)["columns"]
	check(_count(cols[0]["kinds"], "danger") == 1 and _count(cols[3]["kinds"], "danger") == 1, "Kiep %d: first and boss columns untouched" % l_map)
	check(_count(cols[1]["kinds"], "danger") == 2 and _count(spec["columns"][1]["kinds"], "danger") == 1, "Kiep %d: danger x2 in the branch column, input untouched" % l_map)
	check(_count(cols[1]["kinds"], "battle") == 1, "node_weight: other kinds keep their weight")
	check(_count(cols[2]["kinds"], "danger") == 2, "node_weight: a {kind, min_floor} danger entry is doubled too")

	# --- rest / floor heal ---
	check(_near(k.rest_heal_ratio(0.3, l_rest - 1), 0.3) and _near(k.rest_heal_ratio(0.3, l_rest), 0.3 * rest_mult), "Kiep %d: rest heal x%s, not below" % [l_rest, rest_mult])
	check(_near(k.floor_heal_ratio(0.25, l_floor - 1), 0.25) and _near(k.floor_heal_ratio(0.25, l_floor), 0.25 * floor_mult), "Kiep %d: floor heal x%s, not below" % [l_floor, floor_mult])
	# --- player drop ---
	check(not k.apply_match(raw, l_drop - 1, _boss_ctx()).has("player_drop_interval_mult"), "Kiep %d: no player drop key" % (l_drop - 1))
	check(_near(float(k.apply_match(raw, l_drop, _boss_ctx())["player_drop_interval_mult"]), drop_mult), "Kiep %d: player drop interval x%s" % [l_drop, drop_mult])
	# --- gold / shop ---
	check(_near(k.economy_mult("gold", l_gold - 1), 1.0) and _near(k.economy_mult("gold", l_gold), gold_mult), "Kiep %d: gold x%s, not below" % [l_gold, gold_mult])
	check(_near(k.economy_mult("shop_price", l_shop - 1), 1.0) and _near(k.economy_mult("shop_price", l_shop), shop_mult), "Kiep %d: shop price x%s, not below" % [l_shop, shop_mult])
	check(_near(k.economy_mult("other", top), 1.0), "unknown economy key = 1.0")
	# --- swing ---
	check(_near(float(k.apply_match(raw, l_swing - 1, _boss_ctx())["swing_speed_mult"]), 0.9), "Kiep %d: swing unchanged" % (l_swing - 1))
	check(_near(float(k.apply_match(raw, l_swing, _boss_ctx())["swing_speed_mult"]), 0.9 * swing_mult), "Kiep %d: windup x%s" % [l_swing, swing_mult])
	check(_near(float(k.apply_match({"id": "m"}, l_swing, _boss_ctx())["swing_speed_mult"]), swing_mult), "an absent swing_speed_mult counts as 1.0")
	# --- max HP ---
	check(k.apply_run_start(ch, l_hp - 1)["max_hp"] == 200 and k.apply_run_start(ch, l_hp)["max_hp"] == roundi(200 * hp_mult), "Kiep %d: max HP x%s, not below" % [l_hp, hp_mult])
	check(ch["max_hp"] == 200, "apply_run_start does not modify the input")
	# --- floor_shift ---
	check(k.scaling_floor(1, l_shift - 1, 5) == 1 and k.scaling_floor(1, l_shift, 5) == 1 + shift, "Kiep %d: scaling floor +%d, not below" % [l_shift, shift])
	check(k.scaling_floor(4, l_shift, 5) == 5 and k.scaling_floor(5, l_shift, 5) == 5, "floor_shift: floor 5 and the final both use the final row, never above")
	check(k.scaling_floor(-1, l_shift, 5) == -1, "no scaling (floor -1) stays")
	check(k.final_extra(4, l_shift - 1, 5).is_empty() and k.final_extra(3, l_shift, 5).is_empty(), "no final extra below its level / before the last floor")
	check(_near(float(k.final_extra(4, l_shift, 5)["hp_mult"]), final_hp) and _near(float(k.final_extra(5, l_shift, 5)["hp_mult"]), final_hp), "Kiep %d: hp x%s on floor 5 and the final" % [l_shift, final_hp])

	# --- top level stacks everything ---
	var mtop: Dictionary = k.apply_match(raw, top, _boss_ctx())
	check(_near(float(mtop["swing_speed_mult"]), 0.9 * swing_mult) and _near(float(mtop["player_drop_interval_mult"]), drop_mult), "top level stacks swing and drop")
	check(_near(k.rest_heal_ratio(0.3, top), 0.3 * rest_mult) and _near(k.economy_mult("gold", top), gold_mult)
			and k.apply_run_start(ch, top)["max_hp"] == roundi(200 * hp_mult) and k.scaling_floor(1, top, 5) == 1 + shift, "top level keeps every lower rule")
	check(k.apply_match(raw, 99, _boss_ctx()) == mtop, "a level above the maximum acts as the maximum")

	_test_clamps()
	_test_bad_data()
	_test_set_only(k, l_rest, l_hp, rest_mult, hp_mult)

	print("PASSES=%d" % passes)
	print("FAILS=%d" % fails)
	quit(fails)


func check_dup(traits: Array) -> void:
	var seen: Array = []
	for t: Variant in traits:
		var id: String = str((t as Dictionary)["id"])
		if seen.has(id):
			check(false, "duplicate trait %s" % id)
			return
		seen.append(id)


func _count(kinds: Array, kind: String) -> int:
	var n: int = 0
	for e: Variant in kinds:
		var name: String = str((e as Dictionary)["kind"]) if typeof(e) == TYPE_DICTIONARY else str(e)
		if name == kind:
			n += 1
	return n


func _spec() -> Dictionary:
	return {"id": "ch1", "columns": [
			{"tier": 0, "kinds": ["battle", "danger"], "pick": [1, 1], "required": []},
			{"tier": 1, "kinds": ["battle", "danger"], "pick": [2, 3], "required": []},
			{"tier": 1, "kinds": ["battle", {"kind": "danger", "min_floor": 2}], "pick": [2, 3], "required": []},
			{"tier": 2, "kinds": ["battle", "danger"], "pick": [1, 1], "required": ["boss"]}]}


# Stacked multipliers are bounded by the file's `clamp` block.
func _test_clamps() -> void:
	var rows: Array = []
	for i: int in 6:
		rows.append({"level": i + 1, "name_key": "n", "desc_key": "d", "rule": {"type": "max_hp_mult", "params": {"mult": 0.5}}})
	rows.append({"level": 7, "name_key": "n", "desc_key": "d", "rule": {"type": "player_drop_mult", "params": {"mult": 2.0}}})
	rows.append({"level": 8, "name_key": "n", "desc_key": "d", "rule": {"type": "floor_shift", "params": {"shift": 5, "final_hp_mult": 9.0}}})
	rows.append({"level": 9, "name_key": "n", "desc_key": "d", "rule": {"type": "node_weight", "params": {"kind": "danger", "mult": 50.0}}})
	rows.append({"level": 10, "name_key": "n", "desc_key": "d", "rule": {"type": "gold_mult", "params": {"mult": 0.01}}})
	var k: KiepRules = KiepRules.from_dictionary({"clamp": {"max_hp_mult_min": 0.4, "player_drop_mult_max": 1.5,
			"floor_shift_max": 2, "final_hp_mult_max": 1.5, "node_weight_mult_max": 3.0, "gold_mult_min": 0.4}, "levels": rows})
	check(k.apply_run_start({"max_hp": 200}, 6)["max_hp"] == 80, "clamp: max HP never below 40 % (200 -> 80, not 3)")
	check(_near(float(k.apply_match({}, 7, {})["player_drop_interval_mult"]), 1.5), "clamp: player drop at most x1.5")
	check(k.scaling_floor(0, 8, 5) == 2, "clamp: floor shift at most 2")
	check(_near(float(k.final_extra(4, 8, 5)["hp_mult"]), 1.5), "clamp: final hp mult at most 1.5")
	var cols: Array = k.apply_map_spec(_spec(), 9)["columns"]
	check(_count(cols[1]["kinds"], "danger") == 3, "clamp: danger weight at most 3 copies")
	check(_near(k.economy_mult("gold", 10), 0.4), "clamp: gold never below x0.4")


func _test_bad_data() -> void:
	var rows: Array = [
		{"level": 1, "name_key": "n1", "desc_key": "d1", "rule": {"type": "no_such_rule", "params": {"mult": 3.0}}},
		{"level": 2, "name_key": "n2", "desc_key": "d2", "rule": {"type": "gold_mult", "params": {"mult": -4}}},
		{"level": 3, "name_key": "n3", "desc_key": "d3", "rule": [{"type": "bogus"}, {"type": "rest_heal_mult", "params": {"mult": 0.5}}]},
		{"level": 4, "name_key": "n4", "desc_key": "d4", "rule": {"type": "boss_extra_trait", "params": {"trait_pool": []}}},
		"not a row"]
	var k: KiepRules = KiepRules.from_dictionary({"levels": rows})
	check(k.max_level() == 4, "unknown type: the level stays, bad row skipped (4 levels)")
	check((k.level_def(1)["rules"] as Array).is_empty(), "unknown type: that rule is dropped")
	check(k.apply_match({"id": "m"}, 1, _boss_ctx()) == {"id": "m"}, "unknown type: the match is unchanged")
	check(_near(k.economy_mult("gold", 2), 0.75), "bad number keeps the default (gold 0.75)")
	check(_near(k.rest_heal_ratio(0.3, 3), 0.15), "valid rule next to an unknown one still applies")
	check((k.level_def(4)["rules"] as Array).is_empty(), "boss_extra_trait with an empty pool is dropped")
	var empty: KiepRules = KiepRules.from_dictionary({})
	check(empty.max_level() == 0 and empty.apply_run_start({"max_hp": 9}, 3) == {"max_hp": 9}, "empty data: no levels, nothing applied")


func _test_set_only(shipped: KiepRules, l_rest: int, l_hp: int, rest_mult: float, hp_mult: float) -> void:
	var k: KiepRules = KiepRules.load_from_file()
	var top: int = k.max_level()
	k.set_only(l_rest)
	check(_near(k.rest_heal_ratio(0.3, 1), 0.3 * rest_mult) and _near(k.rest_heal_ratio(0.3, top), 0.3 * rest_mult), "set_only(rest level): the rest rule at any level > 0")
	check(_near(k.economy_mult("gold", top), 1.0) and k.apply_run_start({"max_hp": 200}, top)["max_hp"] == 200, "set_only(rest level): no other rule applies")
	check(_near(k.rest_heal_ratio(0.3, 0), 0.3), "set_only: level 0 is still normal")
	k.set_only(l_hp)
	check(k.apply_run_start({"max_hp": 200}, 1)["max_hp"] == roundi(200 * hp_mult) and _near(k.rest_heal_ratio(0.3, top), 0.3), "set_only(max HP level): max HP only")
	k.set_only(0)
	check(_near(k.rest_heal_ratio(0.3, top), 0.3 * rest_mult), "set_only(0): back to stacking")
	check(_near(shipped.rest_heal_ratio(0.3, top), 0.3 * rest_mult), "set_only on one instance does not touch another")

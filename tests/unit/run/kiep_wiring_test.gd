extends SceneTree
## Story 038 Part B: every apply point changes the right number at Kiep level k and NOTHING at level 0:
## RunConfig.from_node (extra trait, scaling row shift, final hp, swing, the player's drop key), the region map
## spec / generated map, shop prices, rest heal, floor heal, max HP and gold (through the KiepRules calls the
## flow makes), and the RunSession save (kiep_level round trip, old saves = 0, level clamp).
## Numbers AND the level of each rule are read from assets/data/kiep_levels.json through KiepRules (_level_of), so
## reordering the levels needs no test change; every check is "at its level" and "not at the level below".
## Prints PASS/FAIL lines and FAILS=n.

const REGION: String = "ch1"
const MATCH_BOSS: String = "goblin_warlock"
const MATCH_FIGHT: String = "goblin_scout"
const HERO: String = "kiem_si"
const SEED: int = 4242
const MAX_HP: float = 200.0

var fails: int = 0
var chapters: ChaptersConfig
var reward_cfg: Dictionary


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _m(kind: String, match_id: String, floor: int, level: int) -> Dictionary:
	return RunConfig.from_node(chapters, REGION, match_id, kind, SEED, floor, level).matches[0]


func _session(level: int) -> RunSession:
	var ch: Dictionary = CharacterConfig.load_from_file().get_character(HERO)
	return RunSession.begin_world(chapters, ch, SEED, 1, {}, level)


func _count_kind(map: Array[Dictionary], kind: String) -> int:
	var n: int = 0
	for col: Dictionary in map:
		for node: Variant in col["nodes"] as Array:
			if str((node as Dictionary).get("kind", "")) == kind:
				n += 1
	return n


# HP healed by the region-boss floor clear of a fresh run at [param level] (hp 50 of MAX_HP).
func _floor_heal(level: int) -> float:
	var s: RunSession = _session(level)
	s.choose_region(s.region_offer[0], 3)
	while s.column < s.map.size() - 1:
		s.choose_node(int(s.available_nodes()[0]["node_index"]))
		s.complete_node(s.hp, MAX_HP, "", reward_cfg)
	s.choose_node(0)
	var res: Dictionary = s.complete_node(50.0, MAX_HP, "", reward_cfg)
	return float(res["healed"]) if bool(res["floor_cleared"]) else -1.0


# The level whose rules hold [param type] (and, for boss_extra_trait, [param scope]); -1 when none.
func _level_of(k: KiepRules, type: String, scope: String = "") -> int:
	for level: int in range(1, k.max_level() + 1):
		for rule: Variant in k.level_def(level)["rules"] as Array:
			var r: Dictionary = rule as Dictionary
			if r["type"] == type and (scope == "" or str((r["params"] as Dictionary).get("scope", "")) == scope):
				return level
	return -1


func _initialize() -> void:
	chapters = ChaptersConfig.load_from_file()
	reward_cfg = RewardRoller.load_config()
	var rules: KiepRules = KiepRules.shared()
	var worlds: int = chapters.world_floors()
	_check("the shipped file has 10 levels", rules.max_level() == 10)
	var top: int = rules.max_level()
	var l_trait: int = _level_of(rules, "boss_extra_trait", "region_boss")
	var l_final: int = _level_of(rules, "boss_extra_trait", "final")
	var l_map: int = _level_of(rules, "node_weight")
	var l_rest: int = _level_of(rules, "rest_heal_mult")
	var l_drop: int = _level_of(rules, "player_drop_mult")
	var l_gold: int = _level_of(rules, "gold_mult")
	var l_swing: int = _level_of(rules, "boss_swing_mult")
	var l_floor: int = _level_of(rules, "floor_heal_mult")
	var l_hp: int = _level_of(rules, "max_hp_mult")
	var l_shift: int = _level_of(rules, "floor_shift")
	var l_shop: int = _level_of(rules, "shop_price_mult")
	_check("every rule type sits at a level >= 1", [l_trait, l_final, l_map, l_rest, l_drop, l_gold, l_swing, l_floor, l_hp, l_shift, l_shop].min() >= 1)

	# --- RunConfig.from_node
	var level0_ok: bool = true
	for floor: int in range(-1, worlds + 1):
		for kind: String in ["battle", "danger", "boss"]:
			var plain: Dictionary = RunConfig.from_node(chapters, REGION, MATCH_BOSS, kind, SEED, floor).matches[0]
			level0_ok = level0_ok and plain == _m(kind, MATCH_BOSS, floor, 0)
	_check("from_node level 0 = the call without the argument (floors -1..final, battle/danger/boss)", level0_ok)
	_check("a plain match carries player_drop_interval_mult 1.0", _near(float(_m("battle", MATCH_FIGHT, 0, 0)["player_drop_interval_mult"]), 1.0))
	var plain_boss: Dictionary = _m("boss", MATCH_BOSS, 1, 0)
	var k1_boss: Dictionary = _m("boss", MATCH_BOSS, 1, l_trait)
	_check("Kiep %d: a region boss gains one trait" % l_trait, (k1_boss["traits"] as Array).size() == (plain_boss["traits"] as Array).size() + 1,
		"%d vs %d" % [(k1_boss["traits"] as Array).size(), (plain_boss["traits"] as Array).size()])
	_check("Kiep %d: a region boss has no extra trait yet" % (l_trait - 1), _m("boss", MATCH_BOSS, 1, l_trait - 1)["traits"] == plain_boss["traits"])
	_check("Kiep %d: same seed -> same match" % l_trait, _m("boss", MATCH_BOSS, 1, l_trait) == k1_boss)
	_check("Kiep %d: a plain fight gets nothing from the trait rule" % l_trait, _m("battle", MATCH_FIGHT, 1, l_trait) == _m("battle", MATCH_FIGHT, 1, l_trait - 1))
	var drop_ok: bool = true
	var swing_ok: bool = true
	var base: Dictionary = _m("battle", MATCH_FIGHT, 1, 0)
	for level: int in range(0, 11):
		var m: Dictionary = _m("battle", MATCH_FIGHT, 1, level)
		drop_ok = drop_ok and ((float(m["player_drop_interval_mult"]) > 1.0) == (level >= l_drop)) and float(m["player_drop_interval_mult"]) <= 1.5 + 0.0001
		swing_ok = swing_ok and ((not _near(float(m["swing_speed_mult"]), float(base["swing_speed_mult"]))) == (level >= l_swing))
	_check("player_drop_interval_mult is above 1 (and within the clamp) exactly from Kiep %d" % l_drop, drop_ok)
	_check("swing_speed_mult changes exactly from Kiep %d" % l_swing, swing_ok)

	# floor_shift scaling: the match uses the row of the next floor (+ the final hp mult on the last floor and the final).
	var shift_ok: bool = true
	for floor: int in range(0, worlds + 1):
		var at_s: Dictionary = _m("battle", MATCH_FIGHT, floor, l_shift)
		var below_s: Dictionary = _m("battle", MATCH_FIGHT, floor, l_shift - 1)
		var shifted: Dictionary = _m("battle", MATCH_FIGHT, mini(rules.scaling_floor(floor, l_shift, worlds), worlds), 0)
		var hp_mult: float = float(rules.final_extra(floor, l_shift, worlds).get("hp_mult", 1.0))
		var own: Dictionary = _m("battle", MATCH_FIGHT, floor, 0)
		shift_ok = shift_ok and _near(float(at_s["boss_max_hp"]), float(shifted["boss_max_hp"]) * hp_mult) \
			and _near(float(at_s["boss_step_cooldown_mult"]), float(shifted["boss_step_cooldown_mult"])) \
			and _near(float(at_s["boss_defense"]), float(shifted["boss_defense"])) and int(at_s["boss_min_runes"]) == int(shifted["boss_min_runes"]) \
			and _near(float(below_s["boss_max_hp"]), float(own["boss_max_hp"])) and _near(float(below_s["boss_defense"]), float(own["boss_defense"]))
	_check("Kiep %d: the scaling row is the next floor's (+ final hp mult), Kiep %d keeps the floor's own" % [l_shift, l_shift - 1], shift_ok)
	_check("Kiep %d: the scaling floor moves up by one below the final and never past it" % l_shift,
		rules.scaling_floor(0, l_shift, worlds) == 1 and rules.scaling_floor(worlds, l_shift, worlds) == worlds and rules.scaling_floor(0, l_shift - 1, worlds) == 0)
	_check("Kiep %d: the final match has more HP than at level 0" % l_shift,
		float(_m("battle", MATCH_FIGHT, worlds, l_shift)["boss_max_hp"]) > float(_m("battle", MATCH_FIGHT, worlds, 0)["boss_max_hp"]))
	var kf_at: Dictionary = _m("boss", MATCH_BOSS, worlds, l_final)
	var k0f: Dictionary = _m("boss", MATCH_BOSS, worlds, 0)
	_check("Kiep %d: the final match gains one trait (scope final)" % l_final, (kf_at["traits"] as Array).size() == (k0f["traits"] as Array).size() + 1)
	var kf_below: Dictionary = _m("boss", MATCH_BOSS, worlds, l_final - 1)
	_check("Kiep %d: the final match has no extra trait yet" % (l_final - 1), (kf_below["traits"] as Array).size() == (k0f["traits"] as Array).size())
	_check("Kiep %d: the final match has exactly one extra trait (the region-boss rule never applies to it)" % top,
		(_m("boss", MATCH_BOSS, worlds, top)["traits"] as Array).size() == (k0f["traits"] as Array).size() + 1)

	# --- region map
	var spec0: Dictionary = chapters.region_spec(REGION, 1)
	_check("region_spec level 0 = the call without the argument", chapters.region_spec(REGION, 1, 0) == spec0)
	_check("region_spec Kiep %d is unchanged (node_weight starts at %d)" % [l_map - 1, l_map], chapters.region_spec(REGION, 1, l_map - 1) == spec0)
	var spec2: Dictionary = chapters.region_spec(REGION, 1, l_map)
	_check("region_spec Kiep %d changes the columns" % l_map, spec2["columns"] != spec0["columns"] and spec2["region_id"] == spec0["region_id"])
	_check("region_spec of an unknown region is {} at any level", chapters.region_spec("nope", 1, 5).is_empty())
	_check("generate_region_map level 0 = the call without the argument", chapters.generate_region_map(REGION, SEED, 1, 3, 0) == chapters.generate_region_map(REGION, SEED, 1, 3))
	var danger_more: bool = false
	var same_len: bool = true
	for s: int in range(1, 40):
		var m0: Array[Dictionary] = chapters.generate_region_map(REGION, s, 1, 3, 0)
		var m2: Array[Dictionary] = chapters.generate_region_map(REGION, s, 1, 3, l_map)
		danger_more = danger_more or _count_kind(m2, "danger") > _count_kind(m0, "danger")
		same_len = same_len and m0.size() == m2.size() and not m0.is_empty()
	_check("Kiep %d produces more danger nodes in some seeds, same map length" % l_map, danger_more and same_len)

	# --- shop prices
	var cards: SkillConfig = SkillConfig.load_from_file()
	var relics: RelicConfig = RelicConfig.load_from_file()
	var economy: EconomyConfig = EconomyConfig.load_from_file()
	var shop0: Dictionary = ShopLogic.build(SEED, 1, 2, 1, 5.0, [], cards, reward_cfg, relics, economy)
	_check("shop level 0 = the call without the argument", ShopLogic.build(SEED, 1, 2, 1, 5.0, [], cards, reward_cfg, relics, economy, {}, 0) == shop0)
	_check("shop Kiep %d: prices unchanged (the price rule is level %d)" % [l_shop - 1, l_shop], ShopLogic.build(SEED, 1, 2, 1, 5.0, [], cards, reward_cfg, relics, economy, {}, l_shop - 1) == shop0)
	var shop10: Dictionary = ShopLogic.build(SEED, 1, 2, 1, 5.0, [], cards, reward_cfg, relics, economy, {}, l_shop)
	var mult: float = rules.economy_mult("shop_price", l_shop)
	var prices_ok: bool = mult > 1.0 and (shop10["cards"] as Array).size() == (shop0["cards"] as Array).size() and (shop10["relics"] as Array).size() == (shop0["relics"] as Array).size()
	for i: int in (shop0["cards"] as Array).size():
		prices_ok = prices_ok and shop10["cards"][i]["id"] == shop0["cards"][i]["id"] and int(shop10["cards"][i]["price"]) == maxi(roundi(float(shop0["cards"][i]["price"]) * mult), 1)
	for i: int in (shop0["relics"] as Array).size():
		prices_ok = prices_ok and shop10["relics"][i]["id"] == shop0["relics"][i]["id"] and int(shop10["relics"][i]["price"]) == maxi(roundi(float(shop0["relics"][i]["price"]) * mult), 1)
	for service: String in (shop0["services"] as Dictionary).keys():
		prices_ok = prices_ok and int(shop10["services"][service]["price"]) == maxi(roundi(float(shop0["services"][service]["price"]) * mult), 1)
	_check("shop Kiep %d: every price x economy_mult(shop_price), rounded, >= 1; same stock" % l_shop, prices_ok)

	# --- rest heal / floor heal (RunSession)
	var s0: RunSession = _session(0)
	s0.hp = 50.0
	var heal0: float = s0.rest_heal(MAX_HP, reward_cfg)
	var s2: RunSession = _session(l_rest - 1)
	s2.hp = 50.0
	_check("rest heal at Kiep %d = level 0" % (l_rest - 1), _near(s2.rest_heal(MAX_HP, reward_cfg), heal0))
	var s3: RunSession = _session(l_rest)
	s3.hp = 50.0
	var heal3: float = s3.rest_heal(MAX_HP, reward_cfg)
	var ratio3: float = rules.rest_heal_ratio(RunSession.cfg(reward_cfg, "rest_heal_ratio"), l_rest)
	_check("rest heal at Kiep %d is smaller and = rest_heal_ratio(base, level) x max HP" % l_rest, heal3 < heal0 and _near(heal3, ratio3 * MAX_HP), "%s vs %s" % [heal3, heal0])
	var fh0: float = _floor_heal(0)
	var fh6: float = _floor_heal(l_floor - 1)
	var fh7: float = _floor_heal(l_floor)
	_check("floor heal: Kiep %d = level 0, Kiep %d smaller = floor_heal_ratio(base, level) x max HP" % [l_floor - 1, l_floor],
		fh0 > 0.0 and _near(fh6, fh0) and fh7 < fh0 and _near(fh7, rules.floor_heal_ratio(chapters.floor_heal_ratio(), l_floor) * MAX_HP), "%s %s %s" % [fh0, fh6, fh7])

	# --- max HP / gold (the calls GameFlow makes at its single points)
	var hero: Dictionary = CharacterConfig.load_from_file().get_character(HERO)
	_check("max HP: Kiep 0..%d unchanged" % (l_hp - 1), rules.apply_run_start(hero, 0) == hero and rules.apply_run_start(hero, l_hp - 1) == hero)
	var c8: Dictionary = rules.apply_run_start(hero, l_hp)
	var hp8: float = float(c8["max_hp"])
	_check("max HP: Kiep %d lower (within the clamp), other keys intact" % l_hp, hp8 < float(hero["max_hp"]) and hp8 >= float(hero["max_hp"]) * 0.4 - 1.0 and c8["starter_deck"] == hero["starter_deck"])
	_check("gold: Kiep %d = x1, Kiep %d below 1 and above 0" % [l_gold - 1, l_gold], _near(rules.economy_mult("gold", l_gold - 1), 1.0) and rules.economy_mult("gold", l_gold) < 1.0 and rules.economy_mult("gold", l_gold) > 0.0)
	var gold_ok: bool = true
	for kind: String in ["battle", "miniboss", "boss"]:
		var base_gold: int = economy.gold_for(kind, 1, 77)
		var at5: int = maxi(roundi(float(base_gold) * rules.economy_mult("gold", l_gold)), 0)
		gold_ok = gold_ok and at5 <= base_gold and at5 >= 0
	_check("gold: the rounded Kiep %d drop never exceeds the base and is never negative" % l_gold, gold_ok)

	# --- RunSession save
	var run: RunSession = _session(4)
	_check("begin_world keeps kiep_level", run.kiep_level == 4)
	_check("begin (legacy) is Kiep 0", RunSession.begin(chapters, hero, 0, SEED).kiep_level == 0)
	_check("begin_world clamps the level to 0..10", _session(99).kiep_level == 10 and _session(-3).kiep_level == 0)
	var d: Dictionary = JSON.parse_string(JSON.stringify(run.to_dict()))
	_check("to_dict writes the current version and kiep_level", int(d["version"]) == RunSession.SAVE_VERSION and RunSession.SAVE_VERSION == 7 and int(d["kiep_level"]) == 4)
	var back: RunSession = RunSession.from_dict(d, chapters)
	_check("save round trip keeps kiep_level", back != null and back.kiep_level == 4)
	d.erase("kiep_level")
	d["version"] = 6
	var old: RunSession = RunSession.from_dict(d, chapters)
	_check("a v6 save without the key loads as Kiep 0 and re-saves as v7", old != null and old.kiep_level == 0 and int(old.to_dict()["version"]) == 7)
	d["kiep_level"] = 55
	_check("a bad saved level is clamped", RunSession.from_dict(d, chapters).kiep_level == 10)
	d["kiep_level"] = "x"
	_check("a non-number level loads as 0", RunSession.from_dict(d, chapters).kiep_level == 0)

	# --- the session builds its region map with the level
	var map_a: RunSession = _session(0)
	var map_b: RunSession = _session(l_map)
	var offer: String = map_a.region_offer[0]
	map_a.choose_region(offer, 3)
	map_b.choose_region(offer, 3)
	_check("choose_region at Kiep 0 matches the plain generator", map_a.map == chapters.generate_region_map(offer, SEED, 0, 3))
	_check("choose_region at Kiep %d uses the Kiep map" % l_map, map_b.map == chapters.generate_region_map(offer, SEED, 0, 3, l_map))

	print("FAILS=", fails)
	quit(fails)


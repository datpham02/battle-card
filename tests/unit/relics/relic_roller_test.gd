extends SceneTree
## Story 032: RelicRoller (seeded determinism, no duplicates, owned excluded, rarity floor, boss tier
## then epic, short pool, stackable). Prints PASS/FAIL lines and FAILS=n.

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _distinct(ids: Array[String]) -> bool:
	var seen: Dictionary = {}
	for id: String in ids:
		if seen.has(id):
			return false
		seen[id] = true
	return true


func _initialize() -> void:
	var cfg: RelicConfig = RelicConfig.load_from_file()
	var none: Array = []
	var a: Array[String] = RelicRoller.roll("treasure", none, _rng(7), cfg)
	var b: Array[String] = RelicRoller.roll("treasure", none, _rng(7), cfg)
	_check(a == b and a.size() == 3, "treasure: same seed -> same 3 ids: %s" % str(a))
	var differs: bool = false
	for s: int in range(1, 30):
		differs = differs or RelicRoller.roll("treasure", none, _rng(s), cfg) != a
	_check(differs, "treasure: other seeds give other offers")
	# Properties over many seeds.
	var props_ok: bool = true
	var floor_ok: bool = true
	var all_seen: Dictionary = {}
	for s: int in 400:
		var offer: Array[String] = RelicRoller.roll("treasure", none, _rng(s), cfg)
		props_ok = props_ok and offer.size() == 3 and _distinct(offer)
		for id: String in offer:
			all_seen[id] = true
			floor_ok = floor_ok and cfg.get_relic(id)["rarity"] != "boss"
	_check(props_ok, "treasure: 400 seeds, always 3 distinct ids")
	_check(floor_ok, "treasure: never a boss-tier relic (weight 0)")
	_check(all_seen.size() == 14, "treasure: every non-boss relic can appear: %d" % all_seen.size())
	# Owned relics are excluded.
	var owned: Array = ["an_don", "chi_khau", "phong_an", "gai_ran", "manh_tuoi", "dinh_tam"]
	var owned_ok: bool = true
	for s: int in 200:
		for id: String in RelicRoller.roll("treasure", owned, _rng(s), cfg):
			owned_ok = owned_ok and not owned.has(id)
	_check(owned_ok, "treasure: owned ids are never offered")
	# Pool short: only two non-owned non-boss relics left.
	var nearly_all: Array = []
	for id: String in cfg.ids():
		if cfg.get_relic(id)["rarity"] != "boss" and id != "la_ban" and id != "han_ky":
			nearly_all.append(id)
	var short: Array[String] = RelicRoller.roll("treasure", nearly_all, _rng(3), cfg)
	short.sort()
	_check(short == ["han_ky", "la_ban"], "treasure: a short pool gives fewer than 3: %s" % str(short))
	var everything: Array = cfg.ids()
	_check(RelicRoller.roll("treasure", everything, _rng(3), cfg).is_empty(), "treasure: everything owned -> empty")
	# Rarity weights bend the draw: common 60 / rare 30 / epic 10 by first pick.
	var counts: Dictionary = {"common": 0, "rare": 0, "epic": 0}
	for s: int in 3000:
		var first: Array[String] = RelicRoller.roll("treasure", none, _rng(s), cfg, 1)
		counts[cfg.get_relic(first[0])["rarity"]] += 1
	_check(counts["common"] > counts["rare"] and counts["rare"] > counts["epic"] and counts["epic"] > 0, "treasure: first-pick rarity follows weights %s" % str(counts))
	# Floor: min_rarity rare removes the commons.
	var floored: RelicConfig = RelicConfig.from_dictionary({
		"source_rules": {"treasure": {"count": 3, "min_rarity": "rare"}},
		"relics": cfg.relics,
	})
	var floor_rare_ok: bool = true
	for s: int in 100:
		for id: String in RelicRoller.roll("treasure", none, _rng(s), floored):
			floor_rare_ok = floor_rare_ok and floored.get_relic(id)["rarity"] != "common"
	_check(floor_rare_ok, "treasure: min_rarity rare is a floor")
	# Weights of a rarity with no candidates are redistributed.
	var only_rare: RelicConfig = RelicConfig.from_dictionary({
		"rarity_weights": {"common": 100, "rare": 1},
		"relics": [{"id": "x", "rarity": "rare"}, {"id": "y", "rarity": "rare"}],
	})
	var redistributed: Array[String] = RelicRoller.roll("treasure", none, _rng(1), only_rare)
	redistributed.sort()
	_check(redistributed == ["x", "y"], "treasure: an empty rarity bucket is skipped: %s" % str(redistributed))
	# Stackable ids may come back even when owned.
	var stack_cfg: RelicConfig = RelicConfig.from_dictionary({
		"relics": [{"id": "s", "rarity": "common", "tags": ["stackable"]}],
	})
	_check(RelicRoller.roll("treasure", ["s"], _rng(1), stack_cfg, 3) == ["s"], "treasure: stackable owned id offered again (once per offer)")
	# Boss kill: boss tier first, then epic.
	var boss: Array[String] = RelicRoller.roll("boss_kill", none, _rng(5), cfg, 1)
	_check(boss.size() == 1 and cfg.get_relic(boss[0])["rarity"] == "boss", "boss_kill: a boss-tier relic first")
	_check(RelicRoller.roll("boss_kill", none, _rng(5), cfg, 1) == boss, "boss_kill: deterministic")
	var both: Array[String] = RelicRoller.roll("boss_kill", none, _rng(5), cfg, 3)
	var tiers: Array[String] = []
	for id: String in both:
		tiers.append(str(cfg.get_relic(id)["rarity"]))
	_check(tiers == ["boss", "boss", "epic"] or tiers == ["boss", "boss", "epic"], "boss_kill count 3: both boss relics, then epic: %s" % str(tiers))
	var boss_owned: Array[String] = RelicRoller.roll("boss_kill", ["an_chu", "tam_hop"], _rng(5), cfg, 1)
	_check(boss_owned.size() == 1 and cfg.get_relic(boss_owned[0])["rarity"] == "epic", "boss_kill: no boss relic left -> epic: %s" % str(boss_owned))
	var one_left: Array[String] = RelicRoller.roll("boss_kill", ["an_chu"], _rng(5), cfg, 1)
	_check(one_left == ["tam_hop"], "boss_kill: the remaining boss relic")
	var drained: Array[String] = RelicRoller.roll("boss_kill", cfg.ids(), _rng(5), cfg, 1)
	_check(drained.is_empty(), "boss_kill: nothing left -> empty")
	# Story 033: "shop" / "event" are real sources now (treasure-like draw); an unknown one still gives nothing.
	_check(RelicRoller.roll("nowhere", none, _rng(1), cfg).is_empty(), "unknown source -> empty (warning)")
	_check(RelicRoller.roll("shop", none, _rng(1), cfg, 2).size() == 2, "shop source: a treasure-like draw of count")
	var rare_up: bool = true
	for s: int in 30:
		for id: String in RelicRoller.roll("event", none, _rng(s), cfg, 1, "rare"):
			rare_up = rare_up and RelicConfig.rarity_rank(str(cfg.get_relic(id)["rarity"])) >= RelicConfig.rarity_rank("rare")
	_check(rare_up, "min_rarity argument raises the floor (event, rare)")
	_check(RelicRoller.roll("treasure", none, null, cfg) == RelicRoller.roll("treasure", none, null, cfg), "null rng: fixed seed 0, deterministic")
	_check(RelicRoller.roll("treasure", none, _rng(1), cfg, 0).is_empty(), "count 0 -> empty")
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)

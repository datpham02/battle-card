extends SceneTree
## Story 032 Part A: RelicRegistry (unknown id, right class, info, instantiate), RelicConfig
## (file + fallbacks), ConfigModRelic, merge_overrides / apply_override order, fold_damage cap and
## damage order. Prints PASS/FAIL lines and FAILS=n.

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _initialize() -> void:
	_registry()
	_config()
	_config_mod()
	_merge()
	_fold()
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


func _registry() -> void:
	_check(RelicRegistry.create("nope") == null, "unknown script id -> null (warning, no crash)")
	_check(not RelicRegistry.has_id("nope") and RelicRegistry.has_id("config_mod"), "has_id")
	_check(RelicRegistry.known_ids().size() == RelicRegistry.SCRIPTS.size(), "known_ids lists every script")
	_check(RelicRegistry.create("config_mod") is ConfigModRelic, "config_mod -> ConfigModRelic")
	_check(RelicRegistry.create("an_don") is AnDon, "an_don -> AnDon")
	_check(RelicRegistry.create("chi_khau") is ChiKhau, "chi_khau -> ChiKhau")
	_check(RelicRegistry.create("khoi_the") is KhoiThe, "khoi_the -> KhoiThe")
	_check(RelicRegistry.create("phan_don") is PhanDon, "phan_don -> PhanDon")
	_check(RelicRegistry.create("huyet_an") is HuyetAn, "huyet_an -> HuyetAn")
	_check(RelicRegistry.create("an_chu") is AnChu, "an_chu -> AnChu")
	_check(RelicRegistry.create("tam_hop") is TamHop, "tam_hop -> TamHop")
	var ids: Array[String] = RelicRegistry.all_ids()
	_check(ids.size() == 16, "relics.json has 16 relics: %d" % ids.size())
	_check(ids[0] == "an_don" and ids[15] == "tam_hop", "all_ids keeps file order")
	var info: Dictionary = RelicRegistry.info("huyet_an")
	_check(info["rarity"] == "epic" and (info["tags"] as Array).has("negative"), "info huyet_an rarity + negative tag")
	_check(info["name_key"] == "relic.huyet_an.name" and info["desc_key"] == "relic.huyet_an.desc", "info keys")
	_check(int((info["params"] as Dictionary)["min_cells"]) == 5, "info params")
	_check(RelicRegistry.info("nope").is_empty(), "info of an unknown id is {}")
	_check(RelicRegistry.instantiate("nope") == null, "instantiate unknown id -> null")
	var relic: BaseRelic = RelicRegistry.instantiate("an_don")
	_check(relic is AnDon and relic.get_id() == "an_don", "instantiate an_don")
	var mod: BaseRelic = RelicRegistry.instantiate("phong_an")
	_check(mod is ConfigModRelic and mod.get_id() == "phong_an", "config-type instance carries its relic id")
	_check(mod.config_overrides().has("seal_sec"), "instantiate pre-sets params so config_overrides works without ctx")
	# Every shipped relic instantiates and its script id is registered.
	var all_ok: bool = true
	for id: String in ids:
		all_ok = all_ok and RelicRegistry.instantiate(id) != null
	_check(all_ok, "every relic of relics.json instantiates")
	# Neutral defaults of the base class.
	var base := BaseRelic.new()
	var info_cast: Dictionary = {"pieces": ["mono"], "cells": 1, "joined": false, "featured": false, "card_id": "x", "hit": true}
	_check(_near(base.modify_cast_damage(info_cast, 7.0), 7.0) and _near(base.modify_cast_time(info_cast, 2.0), 2.0), "BaseRelic hooks are neutral")
	_check(base.config_overrides().is_empty() and base.max_join_pieces() == 2 and base.featured_mult_override() == 0.0, "BaseRelic neutral overrides")


func _config() -> void:
	var cfg: RelicConfig = RelicConfig.load_from_file()
	_check(cfg.relics.size() == 16, "RelicConfig loads 16 relics")
	_check(_near(cfg.relic_damage_mult_cap, 3.0), "cap 3.0")
	_check(_near(float(cfg.rarity_weights["common"]), 60.0) and _near(float(cfg.rarity_weights["rare"]), 30.0) and _near(float(cfg.rarity_weights["epic"]), 10.0), "rarity weights 60/30/10")
	_check(cfg.source_count("treasure") == 3 and cfg.source_count("boss_kill") == 1, "source counts")
	var missing: RelicConfig = RelicConfig.load_from_file("res://assets/data/does_not_exist.json")
	_check(missing.relics.is_empty() and _near(missing.relic_damage_mult_cap, float(RelicConfig.DEFAULTS["relic_damage_mult_cap"])), "missing file -> DEFAULTS, no relics")
	var bad: RelicConfig = RelicConfig.from_dictionary({
		"relic_damage_mult_cap": 0.2,
		"rarity_weights": {"common": -4, "weird": 5},
		"relics": [
			{"id": "a", "rarity": "common"},
			{"id": "a", "rarity": "rare"},
			{"id": "b", "rarity": "mythic"},
			{"rarity": "common"},
			"junk",
			{"id": "c", "rarity": "rare", "tags": ["negative", "bogus"], "params": 3},
		],
	})
	_check(_near(bad.relic_damage_mult_cap, 3.0), "invalid cap -> default")
	_check(_near(float(bad.rarity_weights["common"]), 0.0) and not bad.rarity_weights.has("weird"), "negative weight clamped, unknown rarity dropped")
	_check(bad.ids() == ["a", "c"], "duplicate / bad rarity / no id / junk entries dropped: %s" % str(bad.ids()))
	_check(bad.get_relic("c")["tags"] == ["negative"] and (bad.get_relic("c")["params"] as Dictionary).is_empty(), "unknown tag ignored, bad params -> {}")
	_check(bad.get_relic("a")["script"] == "a" and bad.get_relic("a")["name_key"] == "relic.a.name", "script / name_key default from the id")


func _config_mod() -> void:
	var mul: BaseRelic = RelicRegistry.instantiate("la_ban")
	_check(_near(float(mul.config_overrides()["formation_fade"]["mul"]), 1.3), "la_ban mul 1.3 maps to the override")
	var add: BaseRelic = RelicRegistry.instantiate("phong_an")
	_check(_near(float(add.config_overrides()["seal_sec"]["add"]), 1.0), "phong_an add 1.0")
	var two: BaseRelic = RelicRegistry.instantiate("tui_rong")
	var o: Dictionary = two.config_overrides()
	_check(_near(float(o["hold_slots"]["add"]), 1.0) and not o.has("piece_spawn_interval"), "tui_rong: one slot more, no slower drop (Story 032 tuning)")
	var han: BaseRelic = RelicRegistry.instantiate("han_ky")
	var h: Dictionary = han.config_overrides()
	_check(_near(float(h["han_stacks"]["set"]), 2.0) and _near(float(h["han_damage"]["mul"]), 0.67), "han_ky bare number = set, plus mul")
	var odd := ConfigModRelic.new()
	odd.setup({}, {"seal_sec": "x", "focus_sec": {"add": 2}})
	_check(odd.config_overrides().size() == 1 and odd.config_overrides().has("focus_sec"), "a bad param is ignored")
	var copy: Dictionary = add.config_overrides()
	copy["seal_sec"]["add"] = 99.0
	_check(_near(float(add.config_overrides()["seal_sec"]["add"]), 1.0), "config_overrides returns a copy")
	add.teardown()
	_check(add.config_overrides().is_empty(), "teardown clears the table")
	var every_key_known: bool = true
	for id: String in RelicRegistry.all_ids():
		for key: Variant in RelicRegistry.info(id)["params"].keys():
			if RelicRegistry.info(id)["script"] == "config_mod":
				every_key_known = every_key_known and RelicRegistry.CONFIG_KEYS.has(str(key))
	_check(every_key_known, "every config_mod param key is a canonical config key")


func _merge() -> void:
	var relics: Array = [
		RelicRegistry.instantiate("tui_rong"),
		RelicRegistry.instantiate("manh_tuoi"),
		RelicRegistry.instantiate("phong_an"),
	]
	var merged: Dictionary = RelicRegistry.merge_overrides(relics)
	_check(_near(RelicRegistry.apply_override(3.0, merged, "hold_slots"), 4.0), "hold_slots 3 + 1 = 4")
	_check(_near(RelicRegistry.apply_override(2.0, merged, "piece_spawn_interval"), 2.0), "spawn interval unchanged (tui_rong lost its slower drop in the Story 032 tuning)")
	_check(_near(RelicRegistry.apply_override(10.0, merged, "piece_freshness_sec"), 14.0), "freshness 10 + 4")
	_check(_near(RelicRegistry.apply_override(5.0, merged, "focus_sec"), 5.0), "no override -> base unchanged")
	# Adds sum, muls multiply, add and mul combine as (base + add) x mul.
	var a := ConfigModRelic.new()
	a.setup({}, {"focus_sec": {"add": 1.0, "mul": 2.0}})
	var b := ConfigModRelic.new()
	b.setup({}, {"focus_sec": {"add": 2.0, "mul": 1.5}})
	var m2: Dictionary = RelicRegistry.merge_overrides([a, b])
	_check(_near(float(m2["focus_sec"]["add"]), 3.0) and _near(float(m2["focus_sec"]["mul"]), 3.0), "adds sum, muls multiply")
	_check(_near(RelicRegistry.apply_override(2.0, m2, "focus_sec"), 15.0), "order: (2 + 3) x 3 = 15, not 2 x 3 + 3")
	# Two muls (la_ban x2 stacking via two instances) multiply.
	var m3: Dictionary = RelicRegistry.merge_overrides([RelicRegistry.instantiate("la_ban"), RelicRegistry.instantiate("la_ban")])
	_check(_near(RelicRegistry.apply_override(10.0, m3, "formation_fade"), 16.9), "1.3 x 1.3 on 10 = 16.9")
	# Set replaces the base, then add / mul apply.
	var s := ConfigModRelic.new()
	s.setup({}, {"han_stacks": 2})
	var addon := ConfigModRelic.new()
	addon.setup({}, {"han_stacks": {"add": 1}})
	var m4: Dictionary = RelicRegistry.merge_overrides([s, addon])
	_check(_near(RelicRegistry.apply_override(3.0, m4, "han_stacks"), 3.0), "set 2 then add 1 = 3 (base ignored)")
	_check(RelicRegistry.merge_overrides([]).is_empty() and RelicRegistry.merge_overrides([null, 5]).is_empty(), "empty / junk input -> {}")


func _fold() -> void:
	var cast: Dictionary = {"pieces": ["mono"], "cells": 1, "joined": false, "featured": false, "card_id": "kiem_khi", "hit": true}
	var an_don: BaseRelic = RelicRegistry.instantiate("an_don")
	var cfg: RelicConfig = RelicConfig.load_from_file()
	_check(_near(RelicRegistry.fold_damage([an_don], cast, 10.0, cfg), 17.5), "fold: an_don x1.75 (Story 040)")
	_check(_near(RelicRegistry.fold_damage([], cast, 10.0, cfg), 10.0), "fold: no relics unchanged")
	_check(_near(RelicRegistry.fold_damage([an_don], cast, 0.0, cfg), 0.0), "fold: zero damage stays zero")
	# Damage order: per cell x cells -> relics -> passive -> keywords (Fragile x1.5). 10 x 1 cell,
	# an_don x1.75 = 17.5, quick_blade x1.25 = 21.875, Fragile x1.5 = 32.8125 (Story 040: an_don 2.0 -> 1.75).
	var passive: BasePassive = PassiveRegistry.create("quick_blade")
	passive.setup({}, {"max_cells": 3, "damage_mult": 1.25})
	var per_cell: float = 10.0
	var after_relics: float = RelicRegistry.fold_damage([an_don], cast, per_cell * 1.0, cfg)
	var after_passive: float = passive.modify_damage(1, after_relics)
	var fragile_mult: float = 1.5
	_check(_near(after_passive * fragile_mult, 32.8125), "an_don + quick_blade on a Fragile foe = 32.8125 (hand calc), got %f" % (after_passive * fragile_mult))
	# Cap: two an_don instances multiply to 3.0625, capped to 3.
	var second: BaseRelic = RelicRegistry.instantiate("an_don")
	_check(_near(RelicRegistry.fold_damage([an_don, second], cast, 10.0, cfg), 30.0), "fold: product 3.0625 capped at 3.0 -> 30")
	var tight: RelicConfig = RelicConfig.from_dictionary({"relic_damage_mult_cap": 1.5})
	_check(_near(RelicRegistry.fold_damage([an_don], cast, 10.0, tight), 15.0), "fold: cap 1.5 -> 15")
	var big: Dictionary = {"pieces": ["bar5"], "cells": 5, "joined": false}
	var huyet: BaseRelic = RelicRegistry.instantiate("huyet_an")
	_check(_near(RelicRegistry.fold_damage([an_don, huyet], big, 10.0, cfg), 13.0), "fold: only the relics whose condition holds multiply (huyet_an x1.3)")
	# The other fold helpers.
	var tam_hop: BaseRelic = RelicRegistry.instantiate("tam_hop")
	var an_chu: BaseRelic = RelicRegistry.instantiate("an_chu")
	_check(RelicRegistry.max_join_pieces([an_don]) == 2 and RelicRegistry.max_join_pieces([an_don, tam_hop]) == 3, "max_join_pieces fold")
	_check(RelicRegistry.featured_mult_override([an_don]) == 0.0 and _near(RelicRegistry.featured_mult_override([an_chu]), 2.0), "featured_mult_override fold")
	var khoi: BaseRelic = RelicRegistry.instantiate("khoi_the")
	_check(_near(RelicRegistry.fold_cast_time([khoi], cast, 1.2), 0.0) and _near(RelicRegistry.fold_cast_time([khoi], cast, 1.2), 1.2), "fold_cast_time: first cast 0, then unchanged")

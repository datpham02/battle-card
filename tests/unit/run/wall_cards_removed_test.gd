extends SceneTree
## Quick spec design/quick-specs/o-rot-thay-tuong-2026-10-31.md, "Thay Tuong trong bo cua nguoi choi" (ADR-0001
## Phase 1 task 2): the Wall cards ket_gioi / long_an / luoi_san are boss-only (player_pool false), the Hunter is
## rebuilt on thorns. Regression checks: no player source yields a Wall card; the Hunter starter deck; Dau san's
## new trigger (thorns just laid beside the boss); Vay Bat's extra thorn cell; Gai Dai (phong_an) thorns +1 s.
## Shipped data is read through the configs' loaders (like every config test); the rules run on pure rigs.
## Deterministic: the Vay Bat random pick uses seeded RandomNumberGenerators. Prints PASS/FAIL lines and FAILS=n.

const WALLS: Array[String] = ["ket_gioi", "long_an", "luoi_san"]
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const EPS: float = 0.001

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


func _initialize() -> void:
	_test_flag_mechanism()
	_test_no_player_source_yields_a_wall()
	_test_hunter_starter_deck()
	_test_hunter_mark_thorn_trigger()
	_test_vay_bat_extra_thorn_cell()
	_test_gai_dai_relic()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# The exclusion mechanism on an inline fixture: player_pool false keeps a card out of card_order, default_deck
# and the default card, but the card still exists for the seal card-effect path.
func _test_flag_mechanism() -> void:
	var sc := SkillConfig.from_dictionary({
		"default_card": "wall", "default_deck": ["wall", "slash"], "card_order": ["wall", "slash"],
		"cards": {
			"slash": {"effect": "damage", "implemented": true, "upgrade": {}},
			"wall": {"effect": "seal", "implemented": true, "upgrade": {}, "player_pool": false}}})
	_check("fixture: a player_pool false card exists but is not a player card", sc.has_skill("wall") and not sc.is_player_card("wall") and sc.is_player_card("slash"))
	_check("fixture: card_order skips it (listed or not)", sc.card_order == (["slash"] as Array[String]), str(sc.card_order))
	_check("fixture: default_deck and default_card skip it", sc.default_deck == (["slash"] as Array[String]) and sc.default_card == "slash", "%s %s" % [str(sc.default_deck), sc.default_card])


func _test_no_player_source_yields_a_wall() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	for id: String in WALLS:
		_check("%s: deleted (2026-11-01), unknown card and never a player card" % id, not sc.has_skill(id) and not sc.is_player_card(id))
		# card_order is the reward / shop / event-offer pool (RewardRoller._draw) and the boss default list.
		_check("%s: not in card_order (reward / shop / event pool)" % id, not sc.card_order.has(id))
		_check("%s: not in default_deck" % id, not sc.default_deck.has(id))
		_check("%s: not in the boss card list" % id, not sc.boss_card_order().has(id))
	var cc: CharacterConfig = CharacterConfig.load_from_file()
	var in_starters: Array[String] = []
	for cid: String in cc.ids():
		for card: String in cc.deck_of(cid):
			if WALLS.has(card):
				in_starters.append("%s:%s" % [cid, card])
	_check("no starter deck holds a Wall card", in_starters.is_empty(), str(in_starters))
	# A starter deck that still lists a Wall card has it dropped by the loader.
	var stale: CharacterConfig = CharacterConfig.from_dictionary({"characters": [{"id": "x", "starter_deck": ["kiem_khi", "ket_gioi", "luoi_san"]}]})
	_check("a stale starter deck listing Wall cards loses them on load", stale.deck_of("x") == (["kiem_khi"] as Array[String]), str(stale.deck_of("x")))
	var cfg: AchievementsConfig = AchievementsConfig.load_from_file()
	var rewarded: Array[String] = []
	for r: Dictionary in cfg.all_rewards():
		if str(r["kind"]) == "card" and WALLS.has(str(r["id"])):
			rewarded.append(str(r["achievement"]))
	_check("no achievement rewards a Wall card", rewarded.is_empty(), str(rewarded))
	_check("boss_dungeon rewards gai_nguyen", cfg.reward_owner("card", "gai_nguyen") == "boss_dungeon" and cfg.reward_owner("card", "luoi_san") == "")


func _test_hunter_starter_deck() -> void:
	var cc: CharacterConfig = CharacterConfig.load_from_file()
	_check("tho_san starter deck = kiem_khi x2, tran_gai x2, gai_doc, ran_kich",
		cc.deck_of("tho_san") == (["kiem_khi", "kiem_khi", "tran_gai", "tran_gai", "gai_doc", "ran_kich"] as Array[String]), str(cc.deck_of("tho_san")))


# Pure rig: 3x3 halves, boss on (4, 1).
func _rig() -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))
	var status := StatusEffects.new()
	CombatConfig.new().configure_status(status)
	return {"grid": grid, "state": state, "status": status}


func _test_hunter_mark_thorn_trigger() -> void:
	var r: Dictionary = _rig()
	var status: StatusEffects = r["status"]
	var mark: HunterMarkPassive = PassiveRegistry.create("hunter_mark") as HunterMarkPassive
	mark.setup({"status": status, "state": r["state"], "grid": r["grid"]}, {"fragile_stacks": 1, "icd_sec": 3.0})
	# The real chain: thorns laid through StatusEffects.apply_thorns -> zone_applied -> the passive hook.
	status.zone_applied.connect(func(kind: String, side: int, cells: Array[Vector2i]) -> void:
		if side == E:
			mark.on_player_zone_formed(kind, cells))
	status.apply_thorns(E, [Vector2i(3, 0), Vector2i(5, 2)] as Array[Vector2i], 3.0, 0.0, 0)
	_check("Dau san: thorns laid away from the boss (diagonal) -> no Ran", status.fragile_stacks(E) == 0)
	status.apply_thorns(E, [Vector2i(3, 0), Vector2i(4, 2)] as Array[Vector2i], 3.0, 0.0, 0)
	_check("Dau san: thorns laid with a cell next to the boss -> 1 Ran", status.fragile_stacks(E) == 1 and mark.marks_given() == 1)
	status.apply_thorns(E, [Vector2i(5, 1)] as Array[Vector2i], 3.0, 0.0, 0)
	_check("Dau san: a second fresh thorn beside the boss inside the 3 s cooldown -> still 1 Ran", status.fragile_stacks(E) == 1)
	mark.tick(3.0)
	status.apply_thorns(E, [Vector2i(4, 1)] as Array[Vector2i], 3.0, 0.0, 0)
	_check("Dau san (user 2026-11-01): thorns laid ON the boss's cell -> +1 Ran", status.fragile_stacks(E) == 2 and mark.marks_given() == 2)
	status.apply_thorns(E, [Vector2i(4, 1)] as Array[Vector2i], 3.0, 0.0, 0)
	_check("Dau san: on-cell lay inside the 3 s cooldown -> no extra Ran", status.fragile_stacks(E) == 2)
	mark.tick(3.0)
	mark.on_boss_thorn_step(Vector2i(4, 2))
	_check("Dau san: the boss stepping into your thorns still marks", status.fragile_stacks(E) == 3)


func _test_vay_bat_extra_thorn_cell() -> void:
	var r: Dictionary = _rig()
	var grid: BoardGrid = r["grid"]
	var state: CombatState = r["state"]
	var status: StatusEffects = r["status"]
	var sc := SkillConfig.from_dictionary({"cards": {"thorn": {"effect": "thorns", "thorn_sec": 3.0, "implemented": true, "upgrade": {}}}})
	var zones: Dictionary = CombatConfig.new().zone_numbers()
	var cast: Array[Vector2i] = [Vector2i(3, 0), Vector2i(3, 1)]
	var off: Dictionary = CutEffects.apply(state, grid, P, cast, "thorn", CutConfig.new(), sc, status, Callable(), 1, Callable(), Callable(), {"zones": zones})
	_check("Vay Bat off: only the cast cells", (off["zone_cells"] as Array).size() == 2 and status.thorn_cells(E).size() == 2)
	status.clear_zones()
	var on: Dictionary = CutEffects.apply(state, grid, P, cast, "thorn", CutConfig.new(), sc, status, Callable(), 1, Callable(), Callable(),
		{"zones": zones, "extra_thorn_cells": 1, "zone_sec_mult": 1.5, "zone_rng": _rng(7)})
	# User 2026-11-01: candidates next to the cast are (3,2) and (4,0) ((4,1) is the boss's cell); the pick is random.
	var cand: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 0)]
	var extra_cell: Vector2i = (on["zone_cells"] as Array)[2] if (on["zone_cells"] as Array).size() == 3 else Vector2i(-1, -1)
	_check("Vay Bat on: 1 extra thorn cell, one of the free neighbours of the cast (never the boss's cell)",
		cand.has(extra_cell) and status.thorns_at(E, Vector2i(4, 1)).is_empty(), str(on["zone_cells"]))
	_check("Vay Bat on: the extra cell lasts as long as the rest (x1.5)", _near(status.thorn_total_sec(E, extra_cell), 4.5), str(status.thorn_total_sec(E, extra_cell)))
	# The one candidate left (the other neighbour): asking for 2 gives 1; already-thorned cells are skipped.
	var left_cell: Vector2i = cand[1] if extra_cell == cand[0] else cand[0]
	var picks: Array[Vector2i] = CutEffects.extra_thorn_cells(state, grid, status, E, cast, 2, Callable(), _rng(1))
	_check("extra_thorn_cells: already-thorned and boss cells skipped, fewer when none left", picks == ([left_cell] as Array[Vector2i]), str(picks))
	var all_two: Array[Vector2i] = CutEffects.extra_thorn_cells(state, grid, StatusEffects.new(), E, [Vector2i(5, 1)] as Array[Vector2i], 3, Callable(), _rng(1))
	_check("extra_thorn_cells: every free neighbour is a candidate (asking 3 of 2 gives both)", all_two.size() == 2 and all_two.has(Vector2i(5, 0)) and all_two.has(Vector2i(5, 2)), str(all_two))
	# Random, not nearest-first: over seeds both candidates of a 2-candidate cast get picked; same seed = same pick.
	var seen: Dictionary = {}
	var same_seed: bool = true
	for s: int in range(16):
		var a: Array[Vector2i] = CutEffects.extra_thorn_cells(state, grid, StatusEffects.new(), E, cast, 1, Callable(), _rng(s))
		var b: Array[Vector2i] = CutEffects.extra_thorn_cells(state, grid, StatusEffects.new(), E, cast, 1, Callable(), _rng(s))
		same_seed = same_seed and a == b
		if a.size() == 1:
			seen[a[0]] = true
	_check("extra_thorn_cells: random pick (both neighbours seen over 16 seeds), deterministic per seed",
		seen.size() == 2 and seen.has(Vector2i(3, 2)) and seen.has(Vector2i(4, 0)) and same_seed, str(seen.keys()))
	var blocked: Array[Vector2i] = CutEffects.extra_thorn_cells(state, grid, StatusEffects.new(), E, cast, 1, func(c: Vector2i) -> bool: return c == Vector2i(4, 0), _rng(3))
	_check("extra_thorn_cells: a blocked cell is skipped", blocked == ([Vector2i(3, 2)] as Array[Vector2i]), str(blocked))
	var sig: VayBatSignature = SignatureRegistry.create("vay_bat") as VayBatSignature
	var ch: Dictionary = CharacterConfig.load_from_file().get_character("tho_san")
	sig.setup({}, ch["signature"]["params"])
	_check("Vay Bat signature: inactive -> 0 extra cells", sig.extra_thorn_cells() == 0)
	sig.activate()
	_check("Vay Bat signature (shipped params): active -> 1 extra cell, thorns x1.5", sig.extra_thorn_cells() == 1 and _near(sig.zone_sec_mult(), 1.5))


func _rng(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng


func _test_gai_dai_relic() -> void:
	var r: Dictionary = _rig()
	var sc := SkillConfig.from_dictionary({"cards": {"thorn": {"effect": "thorns", "thorn_sec": 3.0, "implemented": true, "upgrade": {}}}})
	var merged: Dictionary = RelicRegistry.merge_overrides([RelicRegistry.instantiate("phong_an")])
	var cell: Array[Vector2i] = [Vector2i(5, 0)]
	CutEffects.apply(r["state"], r["grid"], P, cell, "thorn", CutConfig.new(), sc, r["status"], Callable(), 1, Callable(), Callable(),
		{"zones": CombatConfig.new().zone_numbers(), "zone_overrides": merged})
	_check("Gai Dai (phong_an): thorns last their 3 s + 1 s", _near((r["status"] as StatusEffects).thorn_total_sec(E, cell[0]), 4.0), str((r["status"] as StatusEffects).thorn_total_sec(E, cell[0])))
	_check("Gai Dai keeps its unlock (ending_mercy)", AchievementsConfig.load_from_file().reward_owner("relic", "phong_an") == "ending_mercy")

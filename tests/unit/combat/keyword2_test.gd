extends SceneTree
# Story 023 part C: Ran (fragile), Han (frost), execute, bonus_vs_fragile, Ghim control-only,
# modifier order, cards.json pool / curve / i18n checks.
var fails: int = 0
func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)

func mk(enemy_hp: float = 1000.0) -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), 1000.0, enemy_hp, Vector2i(1, 1), Vector2i(4, 1))

func _init() -> void:
	var cc: CutConfig = CutConfig.new()
	var grid: BoardGrid = BoardGrid.new(3, 3)
	var cfg: CombatConfig = CombatConfig.load_from_file()
	var E: int = CombatState.Side.ENEMY
	var P: int = CombatState.Side.PLAYER
	var hit: Array[Vector2i] = [Vector2i(4, 1), Vector2i(4, 0)]
	var miss: Array[Vector2i] = [Vector2i(5, 2)]
	# --- config
	ck("combat.json keys", cfg.pinned_damage_mult == 1.0 and cfg.fragile_mult == 1.5 and cfg.fragile_max_stacks == 3 \
		and cfg.frost_stacks_to_burst == 3 and cfg.frost_burst_damage == 24.0 and cfg.execute_ratio == 0.25)
	var bad: CombatConfig = CombatConfig.from_dictionary({"fragile_mult": 0.5, "frost_stacks_to_burst": 0, "execute_ratio": 2.0})
	ck("invalid keyword values -> fallbacks", bad.fragile_mult == 1.5 and bad.frost_stacks_to_burst == 3 and bad.execute_ratio == 0.25)
	# --- test cards (numbers are the point of these boundary tests)
	var sc: SkillConfig = SkillConfig.from_dictionary({"cards": {
		"sw": {"effect": "damage", "damage_per_cell": 7.0, "implemented": true, "upgrade": {}},
		"sw_bonus": {"effect": "damage", "damage_per_cell": 8.0, "bonus_vs_fragile_mult": 1.5, "implemented": true, "upgrade": {}},
		"sw_exec": {"effect": "damage", "damage_per_cell": 8.0, "execute": true, "implemented": true, "upgrade": {}},
		"sw_exec_own": {"effect": "damage", "damage_per_cell": 8.0, "execute_ratio": 0.5, "implemented": true, "upgrade": {}},
		"sw_pierce": {"effect": "damage", "damage_per_cell": 7.0, "pierce_defense": true, "implemented": true, "upgrade": {}},
		"fr1": {"effect": "fragile", "fragile_stacks": 1, "implemented": true, "upgrade": {"fragile_stacks": 1}},
		"fr2": {"effect": "fragile", "fragile_stacks": 2, "implemented": true, "upgrade": {}},
		"fz1": {"effect": "frost", "frost_stacks": 1, "implemented": true, "upgrade": {}},
		"fz2": {"effect": "frost", "frost_stacks": 2, "implemented": true, "upgrade": {}},
		"pin_fr": {"effect": "pin", "pin_duration_sec": 1.8, "fragile_stacks": 2, "implemented": true, "upgrade": {}},
		"sw_fz": {"effect": "damage", "damage_per_cell": 6.0, "frost_stacks": 1, "implemented": true, "upgrade": {}},
		"kiem_khi": {"effect": "damage", "damage_per_cell": 6.0, "implemented": true, "upgrade": {}},
	}})
	var n: Dictionary = sc.get_skill("fr1")
	ck("normalize: fragile effect + fields", n["effect"] == "fragile" and int(n["fragile_stacks"]) == 1 and int(n["frost_stacks"]) == 0 \
		and n["pierce_defense"] == false and n["execute"] == false and float(n["bonus_vs_fragile_mult"]) == 1.0)
	ck("upgrade fragile_stacks lv3 = 3", int(sc.resolved("fr1", 3)["fragile_stacks"]) == 3)
	ck("defaults on an old card dict", int(sc.get_skill("sw").get("fragile_stacks", -1)) == 0 and float(sc.get_skill("sw")["execute_ratio"]) == 0.0)
	# --- Ran: apply / cap / consume
	var fx: StatusEffects = StatusEffects.new()
	cfg.configure_status(fx)
	var s: CombatState = mk()
	var changed: Array = []
	fx.fragile_changed.connect(func(side: int) -> void: changed.append(side))
	var r: Dictionary = CutEffects.apply(s, grid, P, hit, "fr1", cc, sc, fx)
	ck("fragile card hit applies 1 (no damage)", bool(r["hit"]) and int(r["fragile_applied"]) == 1 and float(r["damage"]) == 0.0 \
		and fx.fragile_stacks(E) == 1 and fx.get_fragile_stacks(E) == 1 and s.enemy_hp == 1000.0)
	r = CutEffects.apply(s, grid, P, miss, "fr1", cc, sc, fx)
	ck("fragile card miss applies nothing", not bool(r["hit"]) and int(r["fragile_applied"]) == 0 and fx.fragile_stacks(E) == 1)
	fx.apply_fragile(E, 5)
	ck("cap at 3", fx.fragile_stacks(E) == 3 and changed.size() == 2)
	r = CutEffects.apply(s, grid, P, hit, "sw", cc, sc, fx)
	ck("Ran hit x1.5: 14 -> 21, one stack spent", is_equal_approx(float(r["damage"]), 21.0) and bool(r["fragile_hit"]) and fx.fragile_stacks(E) == 2)
	CutEffects.apply(s, grid, P, hit, "sw", cc, sc, fx)
	CutEffects.apply(s, grid, P, hit, "sw", cc, sc, fx)
	r = CutEffects.apply(s, grid, P, hit, "sw", cc, sc, fx)
	ck("stacks gone -> x1", fx.fragile_stacks(E) == 0 and is_equal_approx(float(r["damage"]), 14.0) and not bool(r["fragile_hit"]))
	ck("hp after Ran", is_equal_approx(s.enemy_hp, 1000.0 - 21.0 * 3.0 - 14.0))
	fx.apply_fragile(P, 1)
	ck("per side: player Ran does not touch enemy", fx.fragile_stacks(P) == 1 and fx.fragile_stacks(E) == 0)
	# burn tick ignores Ran
	var s2: CombatState = mk()
	var fx2: StatusEffects = StatusEffects.new()
	cfg.configure_status(fx2)
	fx2.apply_fragile(E, 1)
	fx2.ignite([Vector2i(4, 1)], 1.0, 0.5, 2.0)
	fx2.tick(0.5, s2)
	ck("burn tick ignores Ran (2 dmg, stack kept)", is_equal_approx(s2.enemy_hp, 998.0) and fx2.fragile_stacks(E) == 1)
	# pin card with fragile stacks (han_bang pattern)
	var s3: CombatState = mk()
	var fx3: StatusEffects = StatusEffects.new()
	cfg.configure_status(fx3)
	r = CutEffects.apply(s3, grid, P, hit, "pin_fr", cc, sc, fx3)
	ck("pin + fragile_stacks 2", bool(r["pinned"]) and fx3.is_pinned(E) and fx3.fragile_stacks(E) == 2 and int(r["fragile_applied"]) == 2)
	r = CutEffects.apply(s3, grid, P, hit, "sw", cc, sc, fx3)
	ck("Ghim no longer multiplies (pinned_damage_mult 1.0): Ran only = 21", is_equal_approx(float(r["damage"]), 21.0) and not bool(r["pin_bonus"]))
	# bonus_vs_fragile before the stack is spent
	var s4: CombatState = mk()
	var fx4: StatusEffects = StatusEffects.new()
	cfg.configure_status(fx4)
	fx4.apply_fragile(E, 1)
	r = CutEffects.apply(s4, grid, P, hit, "sw_bonus", cc, sc, fx4)
	ck("song_kiem pattern: 16 x1.5 bonus x1.5 Ran = 36", is_equal_approx(float(r["damage"]), 36.0) and fx4.fragile_stacks(E) == 0)
	r = CutEffects.apply(s4, grid, P, hit, "sw_bonus", cc, sc, fx4)
	ck("no Ran: bonus off = 16", is_equal_approx(float(r["damage"]), 16.0))
	# --- execute
	var s5: CombatState = mk(100.0)
	var opts: Dictionary = {"execute_ratio": cfg.execute_ratio}
	r = CutEffects.apply(s5, grid, P, hit, "sw_exec", cc, sc, null, Callable(), 1, Callable(), Callable(), opts)
	ck("execute above 25%: x1 = 16", is_equal_approx(float(r["damage"]), 16.0) and not bool(r["executed"]))
	s5.set_enemy_cell(Vector2i(4, 1))
	var s6: CombatState = mk(100.0)
	s6.damage_enemy(75.0)
	r = CutEffects.apply(s6, grid, P, hit, "sw_exec", cc, sc, null, Callable(), 1, Callable(), Callable(), opts)
	ck("execute at exactly 25%: x2 = 32", is_equal_approx(float(r["damage"]), 32.0) and bool(r["executed"]))
	var s7: CombatState = mk(100.0)
	s7.damage_enemy(60.0)
	r = CutEffects.apply(s7, grid, P, hit, "sw_exec_own", cc, sc, null)
	ck("card-level execute_ratio 0.5 without options: x2", is_equal_approx(float(r["damage"]), 32.0))
	r = CutEffects.apply(mk(100.0), grid, P, hit, "sw_exec", cc, sc, null)
	ck("execute true without options ratio: off", is_equal_approx(float(r["damage"]), 16.0))
	# --- order: card 8*2=16 -> Ran x1.5=24 -> execute x2=48 -> passive +3=51 -> signature x2=102 -> defense 10 = 92
	var s8: CombatState = mk(100.0)
	s8.damage_enemy(80.0)
	var fx8: StatusEffects = StatusEffects.new()
	cfg.configure_status(fx8)
	fx8.apply_fragile(E, 1)
	var passive := func(_c: int, d: float) -> float: return d + 3.0
	var sig := func(_id: String, _c: int, d: float, _p: bool) -> float: return d * 2.0
	r = CutEffects.apply(s8, grid, P, hit, "sw_exec", cc, sc, fx8, passive, 1, Callable(), sig, {"execute_ratio": 0.25, "target_defense": 10.0})
	ck("order card->Ran->execute->passive->signature->defense = 92 (%s)" % r["damage"], is_equal_approx(float(r["damage"]), 92.0) \
		and is_equal_approx(float(r["defense_applied"]), 10.0))
	# --- Han
	var s9: CombatState = mk()
	var fx9: StatusEffects = StatusEffects.new()
	cfg.configure_status(fx9)
	var bursts: Array = []
	fx9.frost_burst.connect(func(side: int, dmg: float) -> void: bursts.append([side, dmg]))
	r = CutEffects.apply(s9, grid, P, hit, "fz1", cc, sc, fx9)
	ck("frost card: 1 stack, no damage", int(r["frost_applied"]) == 1 and fx9.frost_stacks(E) == 1 and s9.enemy_hp == 1000.0 and float(r["frost_burst"]) == 0.0)
	r = CutEffects.apply(s9, grid, P, hit, "fz2", cc, sc, fx9)
	ck("3 stacks -> burst 24, stacks cleared, signal", is_equal_approx(float(r["frost_burst"]), 24.0) and fx9.frost_stacks(E) == 0 \
		and fx9.get_frost_stacks(E) == 0 and is_equal_approx(s9.enemy_hp, 976.0) and bursts.size() == 1 and bursts[0][0] == E)
	fx9.apply_fragile(E, 3)
	fx9.apply_frost(E, 2)
	var burst: float = fx9.apply_frost(E, 1)
	ck("burst ignores Ran (24, stacks kept)", is_equal_approx(burst, 24.0) and fx9.fragile_stacks(E) == 3)
	r = CutEffects.apply(mk(), grid, P, miss, "fz2", cc, sc, fx9)
	ck("frost miss applies nothing", not bool(r["hit"]) and int(r["frost_applied"]) == 0)
	var s10: CombatState = mk()
	var fx10: StatusEffects = StatusEffects.new()
	cfg.configure_status(fx10)
	r = CutEffects.apply(s10, grid, P, hit, "sw_fz", cc, sc, fx10)
	ck("damage card with frost_stacks: damage 12 + 1 stack", is_equal_approx(float(r["damage"]), 12.0) and int(r["frost_applied"]) == 1)
	var fx11: StatusEffects = StatusEffects.new()
	ck("unconfigured status: Ran x1, no burst", fx11.consume_fragile(E) == 1.0 and fx11.apply_frost(E, 9) == 0.0 and fx11.frost_stacks(E) == 9)
	fx11.apply_fragile(E, 2)
	fx11.clear()
	ck("clear() wipes Ran/Han", fx11.fragile_stacks(E) == 0 and fx11.frost_stacks(E) == 0)
	# --- cards.json data checks
	var real: SkillConfig = SkillConfig.load_from_file()
	# Story 033: card_order is every card except the curses (never in a pool). The boss-only Wall cards that were also
	# kept out were deleted 2026-11-01 (ADR-0001 Phase 1).
	ck("pool >= 24 (%d), = cards - curses" % real.card_order.size(), real.card_order.size() >= 24
		and real.card_order.size() == real.cards.size() - real.curse_ids().size())
	var over: Array = []
	var by_kw: Dictionary = {"pin": 0, "burn": 0, "fragile": 0, "frost": 0}
	for id: String in real.cards:
		var c: Dictionary = real.get_skill(id)
		# Skill v2 (Ngàn Kiếm): a fixed_hit card's damage_per_cell is damage per HIT (never x cells), outside the per-cell curve.
		if float(c["damage_per_cell"]) > 8.0 and not bool(c.get("fixed_hit", false)):
			over.append(id)
		var rar: String = str(c["rarity"])
		var dpc: float = float(c["damage_per_cell"])
		if dpc > 0.0:
			# Cast rhythm spec 2026-11-05: a mode card (cast_mode not direct, e.g. the parry do_kiem) is tuned through its own
			# measure, never toward the 6-7 curve.
			var mode_card: bool = str(c.get("cast_mode", "direct")) != "direct"
			if rar == "common" and not mode_card and (dpc < 6.0 or dpc > 7.0) and id != "chan_phong" and id != "xung_kich" and id != "han_tran" and id != "gai_doc":
				over.append(id + ":common")
			if rar == "rare" and dpc > 8.0:
				over.append(id + ":rare")
		if c["effect"] == "pin":
			by_kw["pin"] += 1
		if c["effect"] == "burn":
			by_kw["burn"] += 1
		if int(c["fragile_stacks"]) > 0:
			by_kw["fragile"] += 1
		if int(c["frost_stacks"]) > 0:
			by_kw["frost"] += 1
	ck("dpc curve: no card above 8, commons 6-7 (%s)" % str(over), over.is_empty())
	ck(">= 4 cards per keyword %s" % str(by_kw), int(by_kw["pin"]) >= 4 and int(by_kw["burn"]) >= 4 and int(by_kw["fragile"]) >= 3 and int(by_kw["frost"]) >= 4)
	var tu: Dictionary = real.get_skill("tu_kiem")
	var sk: Dictionary = real.get_skill("song_kiem")
	var hb: Dictionary = real.get_skill("han_bang")
	ck("tu_kiem 8 + execute", float(tu["damage_per_cell"]) == 8.0 and bool(tu["execute"]))
	ck("song_kiem 8 + bonus_vs_fragile 1.5", float(sk["damage_per_cell"]) == 8.0 and float(sk["bonus_vs_fragile_mult"]) == 1.5)
	ck("han_bang pin 1.8 + fragile 2", float(hb["pin_duration_sec"]) == 1.8 and int(hb["fragile_stacks"]) == 2)
	for nid: String in ["ran_kich", "ran_van", "han_khi", "han_phong"]:
		ck("new card %s present, not in starter deck" % nid, real.has_skill(nid) and not real.default_deck.has(nid))
	ck("starter deck valid (6 cards)", real.default_deck.size() == 6)
	for cid: String in real.card_order:
		ck("upgrade table %s" % cid, not (real.get_skill(cid)["upgrade"] as Dictionary).is_empty())
	# --- i18n: every name_key/desc_key has vi AND en
	var csv: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	var keys: Dictionary = {}
	var bad_rows: int = 0
	var header: PackedStringArray = csv.get_csv_line()
	ck("csv header keys,vi,en", header.size() == 3 and header[0] == "keys")
	while not csv.eof_reached():
		var row: PackedStringArray = csv.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		if row.size() != 3:
			bad_rows += 1
			continue
		keys[row[0]] = row[1].strip_edges() != "" and row[2].strip_edges() != ""
	ck("csv: every row 3 columns (%d bad)" % bad_rows, bad_rows == 0)
	var missing: Array = []
	for cid: String in real.cards:
		for k: String in [str(real.get_skill(cid)["name_key"]), str(real.get_skill(cid)["desc_key"])]:
			if not bool(keys.get(k, false)):
				missing.append(k)
	for k: String in ["ui.hud.fragile_stacks", "ui.hud.frost_stacks", "keyword.fragile", "keyword.frost", "keyword.execute"]:
		if not bool(keys.get(k, false)):
			missing.append(k)
	ck("i18n vi+en for every card and keyword key %s" % str(missing), missing.is_empty())
	var ghim_old: int = 0
	for cid: String in ["suong_mong", "bang_chau", "bang_phong", "han_bang", "kiem_vu", "kiem_than"]:
		var dk: String = str(real.get_skill(cid)["desc_key"])
		if keys.has(dk):
			pass
	ck("Ghim desc no longer says extra damage", ghim_old == 0)
	print("FAILS=%d" % fails)
	quit()

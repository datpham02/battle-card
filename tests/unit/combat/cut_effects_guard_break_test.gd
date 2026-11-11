extends SceneTree
## Skill v2 batch 1, Đập Vỡ (dap_vo): the data-driven `guard_break` / `guard_break_mult` fields (CutEffects) and the
## `compact` clause `fragile_stacks`: data, Guard stripped before the damage and x1.5 when it was there (the stripped
## Guard leaves the hit's flat defense; the match's own boss_defense stays), no multiplier without Guard, another card
## leaves Guard alone, the clause Rạn on a compact piece only, the REAL arbiter path (sky arrival, one hit), and
## determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/cut_effects_guard_break_test.gd

const ID: String = "dap_vo"
const HERO := Vector2i(1, 1)
const STEP: float = 0.01

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data()
	test_guard_stripped_and_multiplied()
	test_no_guard_no_multiplier()
	test_boss_defense_stays_after_the_strip()
	test_other_cards_leave_guard_alone()
	test_compact_clause_applies_fragile()
	test_real_arbiter_sky_arrival()
	test_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _world(boss: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


# One direct CutEffects.apply of Đập Vỡ on [param cells], the arbiter's options (boss defense + the boss's Guard).
func _apply(w: Dictionary, cells: Array[Vector2i], boss_defense: float = 0.0, context: Dictionary = {}, skill_id: String = ID) -> Dictionary:
	var fx: StatusEffects = w["fx"]
	return CutEffects.apply(w["state"], w["grid"], CombatState.Side.PLAYER, cells, skill_id, w["cc"], w["sc"], fx, Callable(), 1,
		Callable(), Callable(), {"target_defense": boss_defense + fx.guard_amount(CombatState.Side.ENEMY), "cast_context": context})


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR2: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1)]
const SQUARE: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1), Vector2i(6, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared common anti-armour card, implemented, in the pool", sc.hero_of(ID).is_empty() and s["rarity"] == "common"
		and bool(s["implemented"]) and sc.is_pool_card(ID) and sc.card_order.has(ID))
	ck("guard_break true x1.5; compact clause +1 Rạn", bool(s["guard_break"]) and is_equal_approx(float(s["guard_break_mult"]), 1.5)
		and s["shape_clause"]["tag"] == "compact" and int(s["shape_clause"]["fragile_stacks"]) == 1)
	ck("min 2, cd 5, dpc 6, sky arrival, 1 hit, no resolve errors", int(s["min_cells"]) == 2 and is_equal_approx(float(s["cooldown_sec"]), 5.0)
		and is_equal_approx(float(s["damage_per_cell"]), 6.0) and s["resolve"] == "arrival" and s["delivery"]["type"] == SkillDelivery.SKY_TO_TARGET
		and int(s["max_hits"]) == 1 and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("a card without the field has guard_break false x1", not bool(sc.get_skill("kiem_khi")["guard_break"])
		and is_equal_approx(float(sc.get_skill("kiem_khi")["guard_break_mult"]), 1.0))
	var bad: Dictionary = CastResolver.validate("x", {"shape_clause": {"tag": "compact", "fragile_stacks": 9}}, "damage")
	ck("a clause fragile_stacks above the cap is rejected", not (bad["errors"] as Array).is_empty())


func test_guard_stripped_and_multiplied() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	(w["fx"] as StatusEffects).guard(CombatState.Side.ENEMY, 6.0, 5.0)
	var r: Dictionary = _apply(w, BAR2)
	ck("Guard 6 present: stripped, 6 x 2 x 1.5 = 18 with no defense taken off", bool(r["hit"]) and bool(r["guard_broken"])
		and is_equal_approx(float(r["damage"]), 18.0) and is_zero_approx(float(r["defense_applied"]))
		and is_zero_approx((w["fx"] as StatusEffects).guard_amount(CombatState.Side.ENEMY)), str(r))


func test_no_guard_no_multiplier() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	var r: Dictionary = _apply(w, BAR2)
	ck("no Guard: plain 6 x 2 = 12, guard_broken false", bool(r["hit"]) and not bool(r["guard_broken"])
		and is_equal_approx(float(r["damage"]), 12.0), str(r))


func test_boss_defense_stays_after_the_strip() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	(w["fx"] as StatusEffects).guard(CombatState.Side.ENEMY, 6.0, 5.0)
	var r: Dictionary = _apply(w, BAR2, 2.0)
	ck("boss_defense 2 + Guard 6: 18 - 2 = 16 (only the Guard is stripped)", is_equal_approx(float(r["damage"]), 16.0)
		and is_equal_approx(float(r["defense_applied"]), 2.0), str(r))


func test_other_cards_leave_guard_alone() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	(w["fx"] as StatusEffects).guard(CombatState.Side.ENEMY, 6.0, 5.0)
	var r: Dictionary = _apply(w, BAR2, 0.0, {}, "kiem_khi")
	ck("kiem_khi vs Guard 6: 6 x 2 - 6 = 6, Guard stays, no guard_broken key", is_equal_approx(float(r["damage"]), 6.0) and not r.has("guard_broken")
		and is_equal_approx((w["fx"] as StatusEffects).guard_amount(CombatState.Side.ENEMY), 6.0), str(r))


func test_compact_clause_applies_fragile() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	var r: Dictionary = _apply(w, SQUARE, 0.0, _ctx(w["sc"], "square", SQUARE))
	ck("square (compact): +1 Rạn on the boss", int(r["fragile_applied"]) == 1 and (w["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 1, str(r))
	var w2: Dictionary = _world(Vector2i(6, 1))
	var r2: Dictionary = _apply(w2, BAR2, 0.0, _ctx(w2["sc"], "bar2", BAR2))
	ck("bar2: no Rạn", int(r2["fragile_applied"]) == 0 and (w2["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 0)
	var w3: Dictionary = _world(Vector2i(6, 1))
	var r3: Dictionary = _apply(w3, SQUARE)
	ck("no cast context: the clause cannot hold, no Rạn", int(r3["fragile_applied"]) == 0)


func test_real_arbiter_sky_arrival() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	(w["fx"] as StatusEffects).guard(CombatState.Side.ENEMY, 6.0, 5.0)
	(w["player"] as CutActor).begin_swing(BAR2, ID, true, 1, -1.0, {}, _ctx(w["sc"], "bar2", BAR2))
	_run(w, (w["player"] as CutActor).get_duration() + 0.5)
	var hits: int = 0
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			hits += 1
	ck("sky drops: 2 events, one hit, Guard gone, 18 damage", (w["log"] as Array).size() == 2 and hits == 1
		and is_zero_approx((w["fx"] as StatusEffects).guard_amount(CombatState.Side.ENEMY)) and is_equal_approx(_lost(w), 18.0),
		"%.1f %s" % [_lost(w), str(w["log"])])


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 0))
	(a["fx"] as StatusEffects).guard(CombatState.Side.ENEMY, 4.0, 5.0)
	(a["player"] as CutActor).begin_swing(SQUARE, ID, true, 1, -1.0, {}, _ctx(a["sc"], "square", SQUARE))
	_run(a, 2.0)
	var b: Dictionary = _world(Vector2i(5, 0))
	(b["fx"] as StatusEffects).guard(CombatState.Side.ENEMY, 4.0, 5.0)
	(b["player"] as CutActor).begin_swing(SQUARE, ID, true, 1, -1.0, {}, _ctx(b["sc"], "square", SQUARE))
	_run(b, 2.0)
	ck("two identical runs: same log, 6 x 4 x 1.5 = 36, +1 Rạn", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), 36.0)
		and is_equal_approx(_lost(a), _lost(b)) and (a["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 1, "%.1f" % _lost(a))

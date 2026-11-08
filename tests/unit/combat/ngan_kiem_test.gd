extends SceneTree
## Skill v2 Ngàn Kiếm (ngan_kiem, docs/skill-v2/02-skill-bible.md; mechanics M05 sky drops + M06 from_centre) through the
## REAL path (cards.json, CastContext from real pieces, SwingArbiter clock, CutEffects): Knight-only data, min cells,
## cooldown, one drop per open cell, 0.22 s hover after a channel 0.28 s longer (Cast Commitment 2026-11-08; the same
## times after the card choice as the earlier 0.5 s hover) + 0.12 s stagger, centre-outward order, branched tips-first with the
## centre last x1.5, fixed 12 per hit (never x cells), the 3-hit cap, Awakening +1 hit without multiplying damage,
## moving targets, a 2x2 boss (once per drop, several drops), locked cells, defense per hit, interruption, card-level
## result once, cleanup, determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/ngan_kiem_test.gd

const EPS: float = 0.0001
const ID: String = "ngan_kiem"
const HERO := Vector2i(1, 1)
const SWING: float = 0.5

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data_and_ownership()
	test_min_cells_and_cooldown()
	test_drop_count_and_timing()
	test_centre_outward_order()
	test_branched_tips_first_centre_last()
	test_fixed_damage_and_cap()
	test_awakening_extra_hit()
	test_moving_target()
	test_two_by_two_boss()
	test_locked_cells()
	test_defense_per_hit()
	test_interruption_and_cleanup()
	test_determinism()
	test_pattern_interrupt_at_first_hit()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _world(cols: int, boss: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(cols, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	# Cast Commitment (2026-11-08): the game lengthens the channel by channel_extend_sec (CombatView wires the same
	# Callable), so every impact keeps its time after the card choice (hover 0.22 after a swing 0.28 longer).
	player.channel_extend_fn = func(id: String) -> float: return float(sc.get_skill(id).get("channel_extend_sec", 0.0))
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "kind": ev["kind"], "mult": ev["mult"], "t": ev["t"], "hit": hit,
			"dmg": float(ev.get("damage", 0.0)), "at": arb.clock()}))
	var done: Array = []
	arb.swing_resolved.connect(func(side: int, r: Dictionary) -> void: done.append({"side": side, "r": r}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "enemy": enemy, "arb": arb, "log": log, "done": done}


func _cells(pts: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Variant in pts:
		out.append(p as Vector2i)
	return out


func _ctx(w: Dictionary, shape: String, rot: int, cells: Array[Vector2i]) -> Dictionary:
	var sc: SkillConfig = w["sc"]
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece(shape, rot)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, cells: Array[Vector2i], ctx: Dictionary, ticks: float = 3.0) -> void:
	(w["player"] as CutActor).begin_swing(cells, ID, true, 1, SWING, {}, ctx)
	if ticks > 0.0:
		(w["arb"] as SwingArbiter).tick(ticks)


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


func _order(w: Dictionary) -> Array:
	return (w["log"] as Array).map(func(e: Dictionary) -> Vector2i: return e["cell"])


const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const PLUS: Array[Vector2i] = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]


func test_data_and_ownership() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("epic Knight card, damage, implemented", s["rarity"] == "epic" and sc.hero_of(ID) == "kiem_si" and s["effect"] == "damage"
		and bool(s["implemented"]))
	ck("min 4 cells, cd 10, 12 per hit, fixed hit", int(s["min_cells"]) == 4 and is_equal_approx(float(s["cooldown_sec"]), 10.0)
		and is_equal_approx(float(s["damage_per_cell"]), 12.0) and bool(s["fixed_hit"]))
	ck("SKY_TO_TARGET arrival, max 3 hits, hover 0.22 (+0.28 channel), stagger 0.12, from_centre", s["delivery"]["type"] == SkillDelivery.SKY_TO_TARGET
		and s["resolve"] == "arrival" and int(s["max_hits"]) == 3 and is_equal_approx(float(s["sky_hover_sec"]), 0.22)
		and is_equal_approx(float(s["channel_extend_sec"]), 0.28)
		and is_equal_approx(float(s["sky_stagger_sec"]), 0.12) and s["drop_order"] == "from_centre")
	ck("branched clause tips first, centre x1.5; Awakening +1 hit", s["shape_clause"]["tag"] == "branched"
		and bool(s["shape_clause"]["tips_first"]) and is_equal_approx(float(s["shape_clause"]["centre_mult"]), 1.5)
		and int(s["awakening_extra_hits"]) == 1)
	ck("Knight-only: never pool, starter deck or boss", not sc.is_pool_card(ID) and not sc.default_deck.has(ID)
		and not sc.is_boss_playable(ID))
	ck("cards.json has no resolve error", sc.validation_errors.is_empty(), str(sc.validation_errors))


func test_min_cells_and_cooldown() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cd := SkillCooldowns.new()
	ck("3 cells not available, 4 available", not bool(SkillAvailability.check(sc, cd, ID, 3)["available"])
		and bool(SkillAvailability.check(sc, cd, ID, 4)["available"]))
	cd.start(ID, float(sc.resolved(ID, 1)["cooldown_sec"]))
	ck("10 s cooldown", is_equal_approx(cd.remaining(ID), 10.0) and not bool(SkillAvailability.check(sc, cd, ID, 4)["available"]))


func test_drop_count_and_timing() -> void:
	var w: Dictionary = _world(4, Vector2i(9, 1))
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4), 0.0)
	var arb: SwingArbiter = w["arb"]
	arb.tick(0.99)
	ck("nothing lands before 1.00 (channel 0.5 + 0.28, hover 0.22)", (w["log"] as Array).is_empty())
	arb.tick(2.0)
	var at: Array = (w["log"] as Array).map(func(e: Dictionary) -> float: return float(e["at"]))
	ck("one drop per cell (4)", at.size() == 4)
	ck("drops at 1.00 / 1.12 / 1.24 / 1.36 on the clock", at.size() == 4 and absf(at[0] - 1.0) < EPS and absf(at[1] - 1.12) < EPS
		and absf(at[2] - 1.24) < EPS and absf(at[3] - 1.36) < EPS, str(at))


func test_centre_outward_order() -> void:
	var w: Dictionary = _world(4, Vector2i(9, 1))
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4))
	ck("bar4: centre (5,1) (tie -> nearer the hero), then outward, ties by x", _order(w) == [Vector2i(5, 1), Vector2i(4, 1), Vector2i(6, 1), Vector2i(7, 1)],
		str(_order(w)))
	var l: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(5, 2)])
	var w2: Dictionary = _world(4, Vector2i(9, 1))
	_cast(w2, l, _ctx(w2, "l4", 0, l))
	ck("L: from its centre along the connected cells (no jump)", _order(w2) == [Vector2i(4, 1), Vector2i(4, 0), Vector2i(4, 2), Vector2i(5, 2)],
		str(_order(w2)))
	ck("non-branched: every drop x1.0", (w["log"] as Array).all(func(e: Dictionary) -> bool: return is_equal_approx(float(e["mult"]), 1.0)))


func test_branched_tips_first_centre_last() -> void:
	var w: Dictionary = _world(4, Vector2i(5, 1))
	_cast(w, PLUS, _ctx(w, "plus5", 0, PLUS))
	var log: Array = w["log"]
	ck("plus: the junction (5,1) falls last as drop_final x1.5", log.size() == 5 and log[4]["cell"] == Vector2i(5, 1)
		and log[4]["kind"] == "drop_final" and is_equal_approx(float(log[4]["mult"]), 1.5))
	ck("plus: the four tips fall first", log.slice(0, 4).all(func(e: Dictionary) -> bool: return e["kind"] == "drop" and e["cell"] != Vector2i(5, 1)))
	ck("boss on the centre: one hit 12 x 1.5 = 18", is_equal_approx(_lost(w), 18.0), str(_lost(w)))
	var t: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1)])
	ck("T junction = the 3-way cell", CastResolver.junction(t) == Vector2i(5, 0))
	var w2: Dictionary = _world(4, Vector2i(9, 2))
	_cast(w2, t, _ctx(w2, "t4", 0, t))
	ck("T: junction last", (w2["log"] as Array).size() == 4 and (w2["log"] as Array)[3]["cell"] == Vector2i(5, 0))
	ck("bar4 is not branched: no drop_final", not (_world_log_kinds(BAR4, "bar4")).has("drop_final"))


func _world_log_kinds(cells: Array[Vector2i], shape: String) -> Array:
	var w: Dictionary = _world(4, Vector2i(9, 1))
	_cast(w, cells, _ctx(w, shape, 0, cells))
	return (w["log"] as Array).map(func(e: Dictionary) -> String: return e["kind"])


func test_fixed_damage_and_cap() -> void:
	# The boss walks along the bar onto each next drop's cell: hit on drops 1, 2, 3, then the cap stops drop 4.
	var w: Dictionary = _world(4, Vector2i(5, 1))
	var arb: SwingArbiter = w["arb"]
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4), 0.0)
	var st: CombatState = w["state"]
	arb.tick(1.01)  # drop 1 on (5,1): hit
	st.set_enemy_cell(Vector2i(4, 1))
	arb.tick(0.12)  # drop 2 on (4,1): hit
	st.set_enemy_cell(Vector2i(6, 1))
	arb.tick(0.12)  # drop 3 on (6,1): hit
	st.set_enemy_cell(Vector2i(7, 1))
	arb.tick(1.0)  # drop 4 on (7,1): capped
	var hits: Array = (w["log"] as Array).map(func(e: Dictionary) -> bool: return e["hit"])
	ck("three hits then the cap (4th drop finds the boss but cannot hit)", hits == [true, true, true, false], str(hits))
	ck("12 per hit, never x cells: 3 x 12 = 36", is_equal_approx(_lost(w), 36.0), str(_lost(w)))
	var done: Array = w["done"]
	ck("one card-level result at the end (hooks once per cast)", done.size() == 1 and int(done[0]["r"]["hits"]) == 3
		and is_equal_approx(float(done[0]["r"]["damage"]), 36.0))


func test_awakening_extra_hit() -> void:
	var w: Dictionary = _world(4, Vector2i(5, 1))
	var arb: SwingArbiter = w["arb"]
	arb.player_awakening_fn = func() -> bool: return true
	arb.player_cells_modifier = func(n: int) -> int: return n * 2
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4), 0.0)
	var st: CombatState = w["state"]
	arb.tick(1.01)
	st.set_enemy_cell(Vector2i(4, 1))
	arb.tick(0.12)
	st.set_enemy_cell(Vector2i(6, 1))
	arb.tick(0.12)
	st.set_enemy_cell(Vector2i(7, 1))
	arb.tick(1.0)
	ck("Awakening: 4 hits (cap 3 + 1)", (w["log"] as Array).filter(func(e: Dictionary) -> bool: return e["hit"]).size() == 4)
	ck("Awakening never multiplies the fixed hit (cells x2 ignored): 4 x 12 = 48", is_equal_approx(_lost(w), 48.0), str(_lost(w)))
	var w2: Dictionary = _world(4, Vector2i(5, 1))
	(w2["arb"] as SwingArbiter).player_awakening_fn = func() -> bool: return false
	_cast(w2, BAR4, _ctx(w2, "bar4", 0, BAR4))
	ck("Awakening off: no change (one hit, 12)", is_equal_approx(_lost(w2), 12.0))


func test_moving_target() -> void:
	var w: Dictionary = _world(4, Vector2i(5, 1))
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4), 0.0)
	(w["arb"] as SwingArbiter).tick(0.8)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(5, 0))
	(w["arb"] as SwingArbiter).tick(2.0)
	ck("boss stepped off before its blade: no hit", is_equal_approx(_lost(w), 0.0))
	var w2: Dictionary = _world(4, Vector2i(5, 0))
	_cast(w2, BAR4, _ctx(w2, "bar4", 0, BAR4), 0.0)
	(w2["arb"] as SwingArbiter).tick(1.05)
	(w2["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	(w2["arb"] as SwingArbiter).tick(2.0)
	ck("boss stepped onto a later drop's cell: hit when it lands (12)", is_equal_approx(_lost(w2), 12.0), str(_lost(w2)))


func test_two_by_two_boss() -> void:
	var w: Dictionary = _world(4, Vector2i(5, 1))
	var fp: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	(w["state"] as CombatState).set_enemy_footprint(fp)
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4))
	var hits: int = (w["log"] as Array).filter(func(e: Dictionary) -> bool: return e["hit"]).size()
	ck("2x2 boss under two drops: hit once per drop (2 hits, 24)", hits == 2 and is_equal_approx(_lost(w), 24.0), "hits=%d lost=%.1f" % [hits, _lost(w)])


func test_locked_cells() -> void:
	var w: Dictionary = _world(4, Vector2i(9, 1))
	(w["fx"] as StatusEffects).apply_drop(CombatState.Side.ENEMY, [Vector2i(6, 1)] as Array[Vector2i], 5.0, 5.0)
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4))
	ck("a locked cell gets no blade (3 drops, none on (6,1))", _order(w).size() == 3 and not _order(w).has(Vector2i(6, 1)), str(_order(w)))


func test_defense_per_hit() -> void:
	var w: Dictionary = _world(4, Vector2i(5, 1))
	var arb: SwingArbiter = w["arb"]
	arb.boss_defense = 2.0
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4), 0.0)
	arb.tick(1.01)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(4, 1))
	arb.tick(1.0)
	ck("flat defense on every hit: 2 x (12 - 2) = 20", is_equal_approx(_lost(w), 20.0), str(_lost(w)))


func test_interruption_and_cleanup() -> void:
	var w: Dictionary = _world(4, Vector2i(5, 1))
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4), 0.0)
	(w["arb"] as SwingArbiter).tick(0.3)
	(w["player"] as CutActor).cancel()
	(w["arb"] as SwingArbiter).tick(3.0)
	ck("Knight interrupted before the release: no blade", (w["log"] as Array).is_empty() and _lost(w) == 0.0)
	var w2: Dictionary = _world(4, Vector2i(5, 1))
	var hero: Array[Vector2i] = [HERO]
	(w2["enemy"] as CutActor).begin_swing(hero, "kiem_khi", false, 1, 3.0)
	_cast(w2, BAR4, _ctx(w2, "bar4", 0, BAR4), 0.0)
	(w2["arb"] as SwingArbiter).tick(0.9)
	ck("boss swing alive during the hover", (w2["enemy"] as CutActor).is_swinging())
	(w2["arb"] as SwingArbiter).tick(0.2)
	ck("the first damaging blade cancels it", not (w2["enemy"] as CutActor).is_swinging())
	var w3: Dictionary = _world(4, Vector2i(5, 1))
	_cast(w3, BAR4, _ctx(w3, "bar4", 0, BAR4), 0.0)
	(w3["arb"] as SwingArbiter).tick(1.05)
	(w3["state"] as CombatState).damage(CombatState.Side.ENEMY, 5000.0)
	(w3["arb"] as SwingArbiter).tick(2.0)
	ck("death mid-drops clears the rest", (w3["arb"] as SwingArbiter).scheduled_count() == 0 and (w3["log"] as Array).size() == 1)
	var w4: Dictionary = _world(4, Vector2i(9, 1))
	_cast(w4, BAR4, _ctx(w4, "bar4", 0, BAR4))
	ck("after the cast nothing is left on the clock", (w4["arb"] as SwingArbiter).scheduled_count() == 0
		and (w4["arb"] as SwingArbiter).active_cast_count() == 0)


func test_determinism() -> void:
	var a: Array = _orders_for(PLUS)
	var rev: Array[Vector2i] = PLUS.duplicate()
	rev.reverse()
	ck("drop order does not depend on the mask's listing order", a == _orders_for(rev), "%s vs %s" % [a, _orders_for(rev)])


# Regression (2026-11-08, found in the in-game capture): a pattern enemy's warning hit the hero because a scheduled
# cast only interrupted the pattern at its END. The arbiter's pattern_hit_fn now fires once, at the first damaging drop.
func test_pattern_interrupt_at_first_hit() -> void:
	var w: Dictionary = _world(4, Vector2i(5, 1))
	var arb: SwingArbiter = w["arb"]
	var calls: Array = []
	arb.pattern_hit_fn = func() -> void: calls.append(arb.clock())
	_cast(w, BAR4, _ctx(w, "bar4", 0, BAR4), 0.0)
	arb.tick(1.01)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	arb.tick(2.0)
	ck("pattern interrupted once, at the first damaging drop (clock 1.00), not at the cast's end", calls.size() == 1
		and absf(float(calls[0]) - 1.0) < EPS, str(calls))
	var w2: Dictionary = _world(4, Vector2i(7, 0))
	var calls2: Array = []
	(w2["arb"] as SwingArbiter).pattern_hit_fn = func() -> void: calls2.append(1)
	_cast(w2, BAR4, _ctx(w2, "bar4", 0, BAR4))
	ck("a cast that never hits does not interrupt", calls2.is_empty())
	var w3: Dictionary = _world(3, Vector2i(4, 1))
	var calls3: Array = []
	(w3["arb"] as SwingArbiter).pattern_hit_fn = func() -> void: calls3.append(1)
	var k: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]
	(w3["player"] as CutActor).begin_swing(k, "kiem_khi", true, 1, 0.5)
	(w3["arb"] as SwingArbiter).tick(2.0)
	ck("legacy instant cards keep their own path (hook unused)", calls3.is_empty() and (w3["state"] as CombatState).enemy_hp < 1000.0)


func _orders_for(cells: Array[Vector2i]) -> Array:
	var w: Dictionary = _world(4, Vector2i(9, 1))
	var sc: SkillConfig = w["sc"]
	var ctx: Dictionary = _ctx(w, "plus5", 0, cells)
	return (CastResolver.plan(sc.get_skill(ID), cells, ctx)["events"] as Array).map(func(e: Dictionary) -> String:
		return str((e["cells"] as Array)[0]) + str(e["t"]))

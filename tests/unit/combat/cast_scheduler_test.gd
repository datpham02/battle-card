extends SceneTree
## Skill v2 B1.5 (docs/skill-v2/02-mechanics-catalog.md M02): the scheduled impact path of SwingArbiter + CastResolver:
## two / three waves, timing on the combat clock across ticks, ordered cell impacts (arrival), a target moving between
## waves, a multi-cell boss hit at most once per wave, interruption before / after the first impact, cancellation and
## cleanup, deterministic order, invalid resolve configuration, and the frozen cast-time context. Test cards are built
## in memory from kiem_khi (6 per cell); no card in cards.json uses a scheduled resolve.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_scheduler_test.gd

const EPS: float = 0.0001
const DPC: float = 6.0
const SWING: float = 0.5
const MASK: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_two_waves()
	test_three_waves_with_mults()
	test_timing_across_ticks()
	test_arrival_ordered_cells()
	test_target_moves_between_waves()
	test_multi_cell_boss_once_per_wave()
	test_interrupt_before_first_impact()
	test_interrupt_after_first_impact()
	test_cancellation_and_cleanup()
	test_deterministic_order()
	test_invalid_resolve_config()
	test_context_snapshot()
	test_legacy_cards_stay_instant()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# A fresh match: hero at (1,1), enemy at [param enemy_cell], test card [param id] = kiem_khi + [param over].
func _world(id: String, over: Dictionary, enemy_cell: Vector2i = Vector2i(4, 1)) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, Vector2i(1, 1), enemy_cell)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var card: Dictionary = sc.get_skill("kiem_khi").duplicate(true)
	card.merge(over, true)
	sc.cards[id] = card
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var log: Array = []
	var w := {"state": state, "sc": sc, "player": player, "enemy": enemy, "arb": arb, "log": log, "id": id}
	arb.impact_resolved.connect(func(side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"k": "impact", "side": side, "wave": ev["wave"], "index": ev["index"], "t": ev["t"], "hit": hit,
			"at": arb.clock(), "hp": state.enemy_hp}))
	arb.wave_resolved.connect(func(side: int, wave: Dictionary, result: Dictionary) -> void:
		log.append({"k": "wave", "side": side, "wave": wave.get("wave", -1), "hit": result.get("hit", false),
			"ctx": result.get("cast_context", {})}))
	arb.swing_resolved.connect(func(side: int, result: Dictionary) -> void:
		log.append({"k": "swing", "side": side, "hit": result["hit"], "damage": result["damage"],
			"hits": result.get("hits", -1), "scheduled": result.get("scheduled", false), "at": arb.clock()}))
	arb.swing_interrupted.connect(func(victim: int, _c: Array[Vector2i], _s: String) -> void:
		log.append({"k": "interrupt", "victim": victim, "at": arb.clock()}))
	return w


func _cast(w: Dictionary, ctx: Dictionary = {}) -> void:
	(w["player"] as CutActor).begin_swing(MASK, str(w["id"]), true, 1, SWING, {}, ctx)


func _of(w: Dictionary, kind: String) -> Array:
	return (w["log"] as Array).filter(func(e: Dictionary) -> bool: return e["k"] == kind)


func test_two_waves() -> void:
	var w: Dictionary = _world("t2", {"resolve": "waves", "hits": 2, "max_hits": 2, "hit_interval_sec": 0.2})
	_cast(w)
	(w["arb"] as SwingArbiter).tick(3.0)
	var swings: Array = _of(w, "swing")
	ck("2 waves: two impacts, two waves, one card-level result", _of(w, "impact").size() == 2 and _of(w, "wave").size() == 2 and swings.size() == 1)
	ck("2 waves: both hit, 2 x 18 damage", swings.size() == 1 and int(swings[0]["hits"]) == 2 and is_equal_approx(float(swings[0]["damage"]), 36.0)
		and is_equal_approx((w["state"] as CombatState).enemy_hp, 1000.0 - 36.0), str(swings))
	ck("2 waves: the result says scheduled", swings.size() == 1 and bool(swings[0]["scheduled"]))
	ck("2 waves: nothing left on the clock", (w["arb"] as SwingArbiter).scheduled_count() == 0 and (w["arb"] as SwingArbiter).active_cast_count() == 0)


func test_three_waves_with_mults() -> void:
	var w: Dictionary = _world("t3", {"resolve": "waves", "hits": 3, "max_hits": 3, "hit_interval_sec": 0.2, "wave_mults": [1.0, 0.5, 2.0]})
	_cast(w)
	(w["arb"] as SwingArbiter).tick(3.0)
	var hp: Array = _of(w, "impact").map(func(e: Dictionary) -> float: return 1000.0 - float(e["hp"]))
	ck("3 waves: damage 18, +9, +36 (wave_mults)", hp.size() == 3 and is_equal_approx(hp[0], 18.0) and is_equal_approx(hp[1], 27.0)
		and is_equal_approx(hp[2], 63.0), str(hp))


func test_timing_across_ticks() -> void:
	var w: Dictionary = _world("tt", {"resolve": "waves", "hits": 3, "max_hits": 3, "hit_interval_sec": 0.2})
	var arb: SwingArbiter = w["arb"]
	_cast(w)
	var counts: Array = []
	for i: int in 20:
		arb.tick(0.07)
		counts.append(arb.scheduled_count())
	var at: Array = _of(w, "impact").map(func(e: Dictionary) -> float: return float(e["at"]))
	ck("impacts at 0.5 / 0.7 / 0.9 on the clock, not at tick ends", at.size() == 3 and absf(at[0] - 0.5) < EPS
		and absf(at[1] - 0.7) < EPS and absf(at[2] - 0.9) < EPS, str(at))
	# Tick 8 ends at 0.56: wave 0 fired, two waiting; tick 13 ends at 0.91: all fired.
	ck("pending count follows the clock (2 after 0.56, 0 after 0.91)", int(counts[7]) == 2 and int(counts[12]) == 0, str(counts))
	ck("clock = ticked time", absf(arb.clock() - 1.4) < EPS, str(arb.clock()))


func test_arrival_ordered_cells() -> void:
	var w: Dictionary = _world("ta", {"resolve": "arrival", "max_hits": 1}, Vector2i(5, 1))
	_cast(w, {"delivery": {"type": SkillDelivery.CASTER_TO_TARGET}, "caster_cell": Vector2i(1, 1)})
	(w["arb"] as SwingArbiter).tick(3.0)
	var imp: Array = _of(w, "impact")
	var t: Array = imp.map(func(e: Dictionary) -> float: return float(e["t"]))
	ck("arrival: three cell events, nearest first, t 0 / 0.21 / 0.29", imp.size() == 3 and absf(t[0]) < EPS
		and absf(t[1] - 0.21) < EPS and absf(t[2] - 0.29) < EPS, str(t))
	ck("arrival: only the far cell (enemy) hits, at 0.79 on the clock", imp.size() == 3 and not imp[0]["hit"] and not imp[1]["hit"]
		and imp[2]["hit"] and absf(float(imp[2]["at"]) - 0.79) < EPS)
	ck("arrival: one wave, damage counts the cast's 3 cells (18)", _of(w, "wave").size() == 1
		and is_equal_approx((w["state"] as CombatState).enemy_hp, 1000.0 - 18.0))
	var sky: Dictionary = CastResolver.plan({"resolve": "arrival", "max_hits": 1}, MASK, {"delivery": {"type": SkillDelivery.SKY_TO_TARGET}, "caster_cell": Vector2i(1, 1)})
	ck("sky arrival: one wave per cell, t = 0.12 + i x 0.03", (sky["waves"] as Array).size() == 3
		and absf(float((sky["events"] as Array)[2]["t"]) - 0.18) < EPS)


func test_target_moves_between_waves() -> void:
	var w: Dictionary = _world("tm", {"resolve": "waves", "hits": 2, "max_hits": 2, "hit_interval_sec": 0.3})
	var arb: SwingArbiter = w["arb"]
	_cast(w)
	arb.tick(0.6)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(4, 0))
	arb.tick(1.0)
	var imp: Array = _of(w, "impact")
	ck("target left the mask: wave 0 hit, wave 1 missed", imp.size() == 2 and imp[0]["hit"] and not imp[1]["hit"], str(imp))
	var sw: Array = _of(w, "swing")
	ck("card-level: hit, 1 hit, 18 damage", sw.size() == 1 and sw[0]["hit"] and int(sw[0]["hits"]) == 1 and is_equal_approx(float(sw[0]["damage"]), 18.0))
	# Moving INTO the mask between waves: the second wave finds it.
	var w2: Dictionary = _world("tm2", {"resolve": "waves", "hits": 2, "max_hits": 2, "hit_interval_sec": 0.3}, Vector2i(4, 0))
	_cast(w2)
	(w2["arb"] as SwingArbiter).tick(0.6)
	(w2["state"] as CombatState).set_enemy_cell(Vector2i(4, 1))
	(w2["arb"] as SwingArbiter).tick(1.0)
	var imp2: Array = _of(w2, "impact")
	ck("target entered the mask: wave 0 missed, wave 1 hit", imp2.size() == 2 and not imp2[0]["hit"] and imp2[1]["hit"])


func test_multi_cell_boss_once_per_wave() -> void:
	var fp: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	# arrival, one wave: two events find the 2-cell boss, one hit.
	var w: Dictionary = _world("tb", {"resolve": "arrival", "max_hits": 3})
	(w["state"] as CombatState).set_enemy_footprint(fp)
	_cast(w, {"delivery": {"type": SkillDelivery.CASTER_TO_TARGET}, "caster_cell": Vector2i(1, 1)})
	(w["arb"] as SwingArbiter).tick(3.0)
	var hits: int = _of(w, "impact").filter(func(e: Dictionary) -> bool: return e["hit"]).size()
	ck("2-cell boss, one wave over both cells: hit once (18)", hits == 1 and is_equal_approx((w["state"] as CombatState).enemy_hp, 1000.0 - 18.0), "hits=%d" % hits)
	# waves x2: one hit per wave.
	var w2: Dictionary = _world("tb2", {"resolve": "waves", "hits": 2, "max_hits": 2, "hit_interval_sec": 0.2})
	(w2["state"] as CombatState).set_enemy_footprint(fp)
	_cast(w2)
	(w2["arb"] as SwingArbiter).tick(3.0)
	ck("2-cell boss, two waves: two hits (36)", is_equal_approx((w2["state"] as CombatState).enemy_hp, 1000.0 - 36.0))
	# sky: a wave per cell but max_hits 1: one hit for the cast.
	var w3: Dictionary = _world("tb3", {"resolve": "arrival", "max_hits": 1})
	(w3["state"] as CombatState).set_enemy_footprint(fp)
	_cast(w3, {"delivery": {"type": SkillDelivery.SKY_TO_TARGET}, "caster_cell": Vector2i(1, 1)})
	(w3["arb"] as SwingArbiter).tick(3.0)
	ck("2-cell boss, sky drop per cell, max_hits 1: one hit", is_equal_approx((w3["state"] as CombatState).enemy_hp, 1000.0 - 18.0))


func test_interrupt_before_first_impact() -> void:
	# The caster is interrupted before its swing resolves: nothing is scheduled.
	var w: Dictionary = _world("ti", {"resolve": "waves", "hits": 3, "max_hits": 3, "hit_interval_sec": 0.2})
	var arb: SwingArbiter = w["arb"]
	_cast(w)
	arb.tick(0.3)
	(w["player"] as CutActor).cancel()
	arb.tick(2.0)
	ck("caster interrupted before resolve: no event, no damage", _of(w, "impact").is_empty() and arb.scheduled_count() == 0
		and is_equal_approx((w["state"] as CombatState).enemy_hp, 1000.0))
	# The enemy's swing is cancelled by the FIRST damaging event (0.79 here), not by the swing end (0.5).
	var w2: Dictionary = _world("ti2", {"resolve": "arrival", "max_hits": 1}, Vector2i(5, 1))
	var enemy_cells: Array[Vector2i] = [Vector2i(1, 1)]
	(w2["enemy"] as CutActor).begin_swing(enemy_cells, "kiem_khi", false, 1, 2.0)
	_cast(w2, {"delivery": {"type": SkillDelivery.CASTER_TO_TARGET}, "caster_cell": Vector2i(1, 1)})
	(w2["arb"] as SwingArbiter).tick(0.6)
	ck("enemy still swinging after the swing end (no damaging event yet)", (w2["enemy"] as CutActor).is_swinging())
	(w2["arb"] as SwingArbiter).tick(0.4)
	var intr: Array = _of(w2, "interrupt")
	ck("enemy swing cancelled at the first damaging event (0.79)", intr.size() == 1 and absf(float(intr[0]["at"]) - 0.79) < EPS
		and not (w2["enemy"] as CutActor).is_swinging(), str(intr))
	ck("hero untouched (the enemy swing never landed)", is_equal_approx((w2["state"] as CombatState).player_hp, 1000.0))


func test_interrupt_after_first_impact() -> void:
	var w: Dictionary = _world("tj", {"resolve": "waves", "hits": 3, "max_hits": 3, "hit_interval_sec": 0.2})
	var arb: SwingArbiter = w["arb"]
	_cast(w)
	arb.tick(0.55)
	# The boss hits the hero between wave 0 (0.5) and wave 1 (0.7): the cast's remaining waves still land.
	var hero: Array[Vector2i] = [Vector2i(1, 1)]
	(w["enemy"] as CutActor).begin_swing(hero, "kiem_khi", false, 1, 0.05)
	arb.tick(1.0)
	ck("hero was hit after the first impact", (w["state"] as CombatState).player_hp < 1000.0)
	ck("the cast's later waves still landed (3 hits, 54)", is_equal_approx((w["state"] as CombatState).enemy_hp, 1000.0 - 54.0))
	# Only the first damaging event interrupts: a boss swing started after it survives waves 1 and 2.
	var w2: Dictionary = _world("tj2", {"resolve": "waves", "hits": 3, "max_hits": 3, "hit_interval_sec": 0.2})
	_cast(w2)
	(w2["arb"] as SwingArbiter).tick(0.55)
	(w2["enemy"] as CutActor).begin_swing(hero, "kiem_khi", false, 1, 5.0)
	(w2["arb"] as SwingArbiter).tick(0.5)
	ck("later waves do not interrupt again", (w2["enemy"] as CutActor).is_swinging() and _of(w2, "interrupt").is_empty())


func test_cancellation_and_cleanup() -> void:
	# The enemy dies after the first wave: the rest is dropped, nothing more is emitted.
	var w: Dictionary = _world("tc", {"resolve": "waves", "hits": 3, "max_hits": 3, "hit_interval_sec": 0.2})
	var arb: SwingArbiter = w["arb"]
	_cast(w)
	arb.tick(0.55)
	(w["state"] as CombatState).damage(CombatState.Side.ENEMY, 5000.0)
	arb.tick(1.0)
	ck("unit death clears the schedule", arb.scheduled_count() == 0 and arb.active_cast_count() == 0)
	ck("no event after the death", _of(w, "impact").size() == 1 and _of(w, "swing").is_empty())
	# clear_scheduled(side) drops only that side's events (match end path).
	var w2: Dictionary = _world("tc2", {"resolve": "waves", "hits": 3, "max_hits": 3, "hit_interval_sec": 0.2})
	_cast(w2)
	(w2["arb"] as SwingArbiter).tick(0.55)
	(w2["arb"] as SwingArbiter).clear_scheduled(CombatState.Side.ENEMY)
	ck("clearing the other side keeps the cast", (w2["arb"] as SwingArbiter).scheduled_count() == 2)
	(w2["arb"] as SwingArbiter).clear_scheduled(CombatState.Side.PLAYER)
	(w2["arb"] as SwingArbiter).tick(1.0)
	ck("clearing the caster's side drops it: no more impact, no result", (w2["arb"] as SwingArbiter).scheduled_count() == 0
		and _of(w2, "impact").size() == 1 and _of(w2, "swing").is_empty())


func _run_log(steps: Array) -> Array:
	var w: Dictionary = _world("td", {"resolve": "waves", "hits": 3, "max_hits": 3, "hit_interval_sec": 0.13})
	_cast(w)
	var hero: Array[Vector2i] = [Vector2i(1, 1)]
	(w["enemy"] as CutActor).begin_swing(hero, "kiem_khi", false, 1, 0.76)
	for s: Variant in steps:
		(w["arb"] as SwingArbiter).tick(float(s))
	return (w["log"] as Array).map(func(e: Dictionary) -> String:
		var c: Dictionary = e.duplicate()
		c.erase("ctx")
		return str(c))


func test_deterministic_order() -> void:
	var a: Array = _run_log([2.0])
	var b: Array = _run_log([2.0])
	var c: Array = _run_log([0.05, 0.05, 0.3, 0.017, 0.5, 1.0])
	ck("same inputs -> same event log", a == b and not a.is_empty())
	ck("tick sizes do not change the order or times", a == c, "\n%s\n%s" % [str(a), str(c)])


func test_invalid_resolve_config() -> void:
	var bad: Array = [
		[{"resolve": "teleport"}, "damage", "direct", "unknown mode"],
		[{"resolve": "waves", "hits": 0}, "damage", "direct", "hits 0"],
		[{"resolve": "waves", "hits": 99}, "damage", "direct", "hits 99"],
		[{"resolve": "waves", "hits": 2.5}, "damage", "direct", "hits 2.5"],
		[{"resolve": "waves", "hits": "3"}, "damage", "direct", "hits as text"],
		[{"resolve": "waves", "hits": 2, "hit_interval_sec": 0.0}, "damage", "direct", "interval 0"],
		[{"resolve": "instant", "hits": 3}, "damage", "direct", "instant with hits 3"],
		[{"resolve": "waves", "hits": 2}, "thorns", "direct", "zone card scheduled"],
		[{"resolve": "arrival"}, "damage", "parry", "parry card scheduled"],
		[{"resolve": "waves", "hits": 2, "wave_mults": [1.0, -1.0]}, "damage", "direct", "negative wave mult"],
	]
	for case: Array in bad:
		var v: Dictionary = CastResolver.validate("x", case[0], case[1], case[2])
		ck("invalid: %s -> reported, back on instant x1" % case[3], not (v["errors"] as Array).is_empty()
			and v["resolve"] == "instant" and int(v["hits"]) == 1 and int(v["max_hits"]) == 1, str(v["errors"]))
	var ok: Dictionary = CastResolver.validate("y", {"resolve": "waves", "hits": 3, "hit_interval_sec": 0.12}, "damage", "direct")
	ck("valid waves card: no error, max_hits defaults to hits", (ok["errors"] as Array).is_empty() and int(ok["max_hits"]) == 3)
	print("  (one SkillConfig error line below is expected)")
	var sc: SkillConfig = SkillConfig.from_dictionary({"cards": {"bad": {"effect": "damage", "implemented": true, "resolve": "teleport"}}})
	ck("SkillConfig lists the error and keeps the card instant", sc.validation_errors.size() == 1 and str(sc.get_skill("bad")["resolve"]) == "instant",
		str(sc.validation_errors))
	ck("the real cards.json has no resolve error", SkillConfig.load_from_file().validation_errors.is_empty())


func test_context_snapshot() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var pieces: Array[Piece] = [lib.make_piece("bar3", 0)]
	var bonus: Dictionary = {"damage_mult": 1.5, "effect": "burn"}
	var ctx: Dictionary = CastContext.build("kiem_khi", 2, pieces, [MASK], {"type": "CASTER_TO_TARGET"}, true,
		CombatState.Side.PLAYER, Vector2i(1, 1), {"cast_mode": "direct", "featured_bonus": bonus, "effective_cells": 6, "t_cast": 12.5})
	bonus["damage_mult"] = 9.0
	ck("context keeps the featured bonus as it was at the cast", is_equal_approx(float((ctx["featured_bonus"] as Dictionary)["damage_mult"]), 1.5))
	ck("context fields: schema, caster_side, cast_mode, effective_cells, t_cast, canonical_key",
		int(ctx["schema"]) == CastContext.SCHEMA and int(ctx["caster_side"]) == CombatState.Side.PLAYER and ctx["cast_mode"] == "direct"
		and int(ctx["effective_cells"]) == 6 and is_equal_approx(float(ctx["t_cast"]), 12.5)
		and not str((ctx["pieces"] as Array)[0]["canonical_key"]).is_empty())
	var old: Dictionary = CastContext.build("kiem_khi", 1, pieces, [MASK], {}, false, CombatState.Side.PLAYER, Vector2i(1, 1))
	ck("old callers (no extras) get the defaults", old["cast_mode"] == "direct" and int(old["effective_cells"]) == 3
		and (old["featured_bonus"] as Dictionary).is_empty() and is_equal_approx(float(old["t_cast"]), 0.0))
	# Through the arbiter: every wave sees the SAME frozen snapshot; the caller's dictionary is untouched.
	var w: Dictionary = _world("ts", {"resolve": "waves", "hits": 2, "max_hits": 2, "hit_interval_sec": 0.2})
	_cast(w, ctx)
	(w["arb"] as SwingArbiter).tick(3.0)
	var waves: Array = _of(w, "wave")
	ck("waves carry a frozen context", waves.size() == 2 and CastContext.is_frozen(waves[0]["ctx"]) and is_same(waves[0]["ctx"], waves[1]["ctx"]))
	ck("the caller's context stays writable and unchanged", not ctx.is_read_only() and int(ctx["level"]) == 2)
	var frozen: Dictionary = waves[0]["ctx"] if not waves.is_empty() else {}
	var copy: Dictionary = frozen.duplicate(true)
	copy["level"] = 3
	ck("a duplicate of the snapshot is writable, the snapshot is not changed", int(copy["level"]) == 3 and int(frozen.get("level", 0)) == 2)


func test_legacy_cards_stay_instant() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var not_instant: Array[String] = []
	for id: String in sc.cards.keys():
		if str((sc.cards[id] as Dictionary).get("resolve", "instant")) != "instant":
			not_instant.append(id)
	# Skill v2 cards opt in one by one (tram_dia, 2026-11-08; batch 1 chuoi_set / dap_vo / min_tre / thuong_xuyen,
	# 2026-11-11); every other card stays on the legacy instant path.
	var v2: Array[String] = ["chuoi_set", "dap_vo", "hoa_loi", "lien_tram", "min_tre", "ngan_kiem", "song_dao", "thuong_xuyen", "tram_dia"]
	not_instant.sort()
	ck("only the Skill v2 cards leave the instant (legacy) path", not_instant == v2, str(not_instant))
	var w: Dictionary = _world("tl", {})
	_cast(w)
	(w["arb"] as SwingArbiter).tick(3.0)
	ck("an instant card emits no impact events (legacy path)", _of(w, "impact").is_empty() and _of(w, "swing").size() == 1
		and not bool(_of(w, "swing")[0]["scheduled"]))

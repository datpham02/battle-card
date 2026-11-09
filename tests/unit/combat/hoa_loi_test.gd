extends SceneTree
## Skill v2 Hỏa Lôi (hoa_loi, docs/skill-v2/09-hoa-loi-design.md; M07 delayed) through the REAL path (cards.json, a
## CastContext from real pieces, CutActor with the fixed cast time, SwingArbiter clock, CutEffects, StatusEffects):
## data and validation, the fixed 0.45 s cast, one simultaneous wave at swing end + fuse (square 1.8 s), damage
## dpc x armed cells x mult sampled at the detonation, moving and 2x2 targets, locked cells at the cast and at the fire,
## the armed-cell skip rule and the fizzled empty cast, the field cap and the menu reasons, the burn payload (hit or
## miss, no entry tick on the blast), survival of a hit caster, cleanup on death, the threat feed and determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/hoa_loi_test.gd

const ID: String = "hoa_loi"
const HERO := Vector2i(1, 1)
const STEP: float = 0.01

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data_and_validation()
	test_fixed_cast_time()
	test_one_wave_at_fuse_end()
	test_square_clause()
	test_damage_whole_field_once()
	test_moving_target()
	test_two_by_two_boss()
	test_locked_cells()
	test_overlap_skip_and_fizzle()
	test_field_cap_and_menu_reasons()
	test_burn_payload()
	test_caster_hit_and_death()
	test_threat_feed()
	test_determinism()
	test_model_c_rule()
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
	player.cast_time_fn = func(id: String) -> float: return float(sc.get_skill(id).get("cast_time_sec", -1.0))
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cells": ev["cells"], "kind": ev["kind"], "mult": ev["mult"], "at": arb.clock(), "hit": hit,
			"dmg": float(ev.get("damage", 0.0)), "ignited": ev.get("ignited", []), "fizzled": ev.get("fizzled_cells", [])}))
	var done: Array = []
	arb.swing_resolved.connect(func(side: int, r: Dictionary) -> void: done.append({"side": side, "r": r}))
	var sched: Array = []
	arb.cast_scheduled.connect(func(_side: int, c: Dictionary) -> void: sched.append(c))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log, "done": done,
		"sched": sched}


func _cells(pts: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Variant in pts:
		out.append(p as Vector2i)
	return out


func _ctx(w: Dictionary, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var sc: SkillConfig = w["sc"]
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, shape: String, cells: Array[Vector2i]) -> bool:
	return (w["player"] as CutActor).begin_swing(cells, ID, true, 1, -1.0, {}, _ctx(w, shape, cells))


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR2: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1)]
const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const SQUARE: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1), Vector2i(6, 1)]
const T4: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1)]


func test_data_and_validation() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("Mage hero card, common, damage, implemented, not in rewards yet (D10)", sc.hero_of(ID) == "phap_su"
		and s["rarity"] == "common" and s["effect"] == "damage" and bool(s["implemented"]) and not bool(s["hero_reward"]))
	ck("delayed resolve valid (no resolve errors)", s["resolve"] == "delayed" and (s["resolve_errors"] as Array).is_empty(),
		str(s["resolve_errors"]))
	ck("candidates: min 2, cd 6, dpc 6, fuse 1.5 x2.0, max 2 fields", int(s["min_cells"]) == 2
		and is_equal_approx(float(s["cooldown_sec"]), 6.0) and is_equal_approx(float(s["damage_per_cell"]), 6.0)
		and is_equal_approx(float(s["fuse_sec"]), 1.5) and is_equal_approx(float(s["fuse_mult"]), 2.0) and int(s["max_active"]) == 2)
	ck("square clause 1.8 s x2.4; cast 0.45 s lock", s["shape_clause"]["tag"] == "square"
		and is_equal_approx(float(s["shape_clause"]["fuse_sec"]), 1.8) and is_equal_approx(float(s["shape_clause"]["fuse_mult"]), 2.4)
		and is_equal_approx(float(s["cast_time_sec"]), 0.45) and s["cast_root"] == "lock")
	ck("burn payload 2.0 s / 0.5 s / 1.5", is_equal_approx(float(s["event_payload"]["ignite"]["sec"]), 2.0)
		and is_equal_approx(float(s["event_payload"]["ignite"]["tick_sec"]), 0.5)
		and is_equal_approx(float(s["event_payload"]["ignite"]["damage"]), 1.5))
	# validation is reported, never silent
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "delayed", "fuse_sec": 9.0}, "damage")
	ck("fuse_sec out of range is rejected (back to instant)", bad["resolve"] == "instant" and not (bad["errors"] as Array).is_empty())
	var bad2: Dictionary = CastResolver.validate("x", {"resolve": "arrival", "fuse_sec": 1.0}, "damage")
	ck("fuse fields need resolve delayed", not (bad2["errors"] as Array).is_empty())
	var bad3: Dictionary = CastResolver.validate("x", {"resolve": "delayed", "fuse_mult": 1.0,
		"shape_clause": {"tag": "square", "fuse_mult": 2.5}}, "damage")
	ck("a fuse clause above the shape-group cap is rejected", not (bad3["errors"] as Array).is_empty())
	var bad4: Dictionary = CastResolver.validate("x", {"resolve": "instant", "event_payload": {"ignite": {"sec": 1.0}}}, "damage")
	ck("a payload on a non-delayed card is rejected", not (bad4["errors"] as Array).is_empty())
	var bad5: Dictionary = CastResolver.validate("x", {"resolve": "delayed", "event_payload": {"poison": {}}}, "damage")
	ck("an unknown payload key is rejected", not (bad5["errors"] as Array).is_empty())


func test_fixed_cast_time() -> void:
	for n: int in [2, 3, 4, 5]:
		var w: Dictionary = _world(Vector2i(7, 2))
		var cells: Array[Vector2i] = []
		for i: int in n:
			cells.append(Vector2i(4 + (i % 4), 0 if i < 4 else 1))
		_cast(w, "bar4", cells)
		ck("%d cells: the cast is 0.45 s (not 0.2 + 0.25 x cells)" % n, is_equal_approx((w["player"] as CutActor).get_duration(), 0.45),
			"%.3f" % (w["player"] as CutActor).get_duration())


func test_one_wave_at_fuse_end() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	_cast(w, "bar4", BAR4)
	_run(w, 0.45)
	var sched: Array = w["sched"]
	ck("scheduled at the swing end (one cast, one event, all 4 cells, kind fuse, armed)", sched.size() == 1
		and (sched[0]["events"] as Array).size() == 1 and ((sched[0]["events"] as Array)[0]["cells"] as Array).size() == 4
		and (sched[0]["events"] as Array)[0]["kind"] == "fuse" and bool((sched[0]["events"] as Array)[0]["armed"]))
	var at: float = float((sched[0]["events"] as Array)[0]["at"])
	ck("detonation at swing end + 1.5 s on the arbiter clock", absf(at - 1.95) < 0.0001, "%.4f" % at)
	_run(w, 1.49)
	ck("nothing fired 0.01 s before", (w["log"] as Array).is_empty())
	_run(w, 0.02)
	ck("one event fired, at 1.95", (w["log"] as Array).size() == 1 and absf(float((w["log"] as Array)[0]["at"]) - 1.95) < 0.0001)


func test_square_clause() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast(w, "square", SQUARE)
	_run(w, 2.4)
	var ev: Dictionary = ((w["sched"] as Array)[0]["events"] as Array)[0]
	ck("square: fuse 1.8 s, x2.4", absf(float(ev["at"]) - 2.25) < 0.0001 and is_equal_approx(float(ev["mult"]), 2.4),
		"at=%.3f mult=%.2f" % [float(ev["at"]), float(ev["mult"])])
	# Model C (approved 2026-11-09): a 1-cell boss counts min(4 armed, 1 + 1) = 2 cells
	ck("square on a 1-cell boss (Model C): 6 x 2 x 2.4 = 28.8", is_equal_approx(_lost(w), 28.8), "%.2f" % _lost(w))
	for shape: String in ["t4", "bar4"]:
		var w2: Dictionary = _world(Vector2i(5, 0))
		_cast(w2, shape, T4 if shape == "t4" else BAR4)
		_run(w2, 2.0)
		var e2: Dictionary = ((w2["sched"] as Array)[0]["events"] as Array)[0]
		ck("%s: no clause, 1.5 s, x2.0" % shape, absf(float(e2["at"]) - 1.95) < 0.0001 and is_equal_approx(float(e2["mult"]), 2.0))


func test_damage_whole_field_once() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	_cast(w, "bar4", BAR4)
	_run(w, 2.0)
	ck("boss on 1 of 4 seals, 1-cell boss (Model C): one hit, min(4, 1 + 1) = 2 cells -> 6 x 2 x 2.0 = 24", is_equal_approx(_lost(w), 24.0),
		"%.1f" % _lost(w))
	var w2: Dictionary = _world(Vector2i(6, 1))
	_cast(w2, "bar2", BAR2)
	_run(w2, 2.0)
	ck("2 cells: 24", is_equal_approx(_lost(w2), 24.0), "%.1f" % _lost(w2))
	var done: Array = w["done"]
	ck("one card-level result, scheduled, hit", done.size() == 1 and bool(done[0]["r"]["hit"]) and bool(done[0]["r"]["scheduled"])
		and not bool(done[0]["r"]["fizzled"]))


func test_moving_target() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast(w, "bar2", BAR2)
	_run(w, 1.0)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(5, 2))
	_run(w, 1.0)
	ck("on a seal at the cast, off at the detonation: miss", is_equal_approx(_lost(w), 0.0) and not bool((w["log"] as Array)[0]["hit"]))
	var w2: Dictionary = _world(Vector2i(5, 2))
	_cast(w2, "bar2", BAR2)
	_run(w2, 1.0)
	(w2["state"] as CombatState).set_enemy_cell(Vector2i(5, 1))
	_run(w2, 1.0)
	ck("off at the cast, on at the detonation: hit (24)", is_equal_approx(_lost(w2), 24.0), "%.1f" % _lost(w2))


func test_two_by_two_boss() -> void:
	var w: Dictionary = _world(Vector2i(5, 0))
	var fp: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	(w["state"] as CombatState).set_enemy_footprint(fp)
	_cast(w, "bar4", BAR4)
	_run(w, 2.0)
	ck("2x2 boss touching 2 seals (Model C: min(4, 4 + 1) = 4 cells): hit once (48)", is_equal_approx(_lost(w), 48.0), "%.1f" % _lost(w))
	var w2: Dictionary = _world(Vector2i(5, 0))
	(w2["state"] as CombatState).set_enemy_footprint(fp)
	_cast(w2, "square", SQUARE)
	_run(w2, 2.4)
	ck("2x2 boss on the whole square: hit once (57.6)", is_equal_approx(_lost(w2), 57.6), "%.2f" % _lost(w2))


func test_locked_cells() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	(w["fx"] as StatusEffects).apply_drop(CombatState.Side.ENEMY, [Vector2i(6, 1)] as Array[Vector2i], 5.0, 5.0)
	_cast(w, "bar4", BAR4)
	_run(w, 0.46)
	var ev: Dictionary = ((w["sched"] as Array)[0]["events"] as Array)[0]
	ck("a cell locked at the cast gets no seal (3 seals)", (ev["cells"] as Array).size() == 3 and not (ev["cells"] as Array).has(Vector2i(6, 1)))
	# a cell that locks during the fuse fizzles: no damage there, no burn
	var w2: Dictionary = _world(Vector2i(5, 1))
	_cast(w2, "bar4", BAR4)
	_run(w2, 1.0)
	(w2["fx"] as StatusEffects).apply_drop(CombatState.Side.ENEMY, [Vector2i(6, 1)] as Array[Vector2i], 0.0, 5.0)
	_run(w2, 1.0)
	var e2: Dictionary = (w2["log"] as Array)[0] if not (w2["log"] as Array).is_empty() else {}
	ck("a cell locked during the fuse fizzles (not in the blast, not burnt)", not e2.is_empty()
		and (e2["fizzled"] as Array).has(Vector2i(6, 1)) and not (e2["cells"] as Array).has(Vector2i(6, 1))
		and not (w2["fx"] as StatusEffects).burning_cells().has(Vector2i(6, 1)), str(e2))
	ck("the other seals still detonate (boss on (5,1) hit, 3 cells burn)", not e2.is_empty() and bool(e2["hit"])
		and (w2["fx"] as StatusEffects).burning_cells().size() == 3)


func test_overlap_skip_and_fizzle() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	var arb: SwingArbiter = w["arb"]
	_cast(w, "bar2", BAR2)
	_run(w, 0.46)
	ck("armed registry: 2 cells, 1 field", arb.armed_cells(CombatState.Side.PLAYER).size() == 2
		and arb.armed_cast_count(CombatState.Side.PLAYER, ID) == 1)
	var three: Array[Vector2i] = _cells([Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)])
	_cast(w, "bar3", three)
	_run(w, 0.46)
	var c2: Dictionary = (w["sched"] as Array)[1]
	ck("a second field skips the armed cells (1 seal on (7,1)), counts 1 cell", ((c2["events"] as Array)[0]["cells"] as Array) == [Vector2i(7, 1)]
		and (c2["skipped_cells"] as Array).size() == 2, str(c2))
	ck("the first field's countdown is unchanged", absf(float(((w["sched"] as Array)[0]["events"] as Array)[0]["at"]) - 1.95) < 0.0001)
	# every cell already armed -> the cast fizzles: no event, a clear result
	var w3: Dictionary = _world(Vector2i(7, 2))
	_cast(w3, "bar2", BAR2)
	_run(w3, 0.46)
	_cast(w3, "bar2", BAR2)
	_run(w3, 0.46)
	var c3: Dictionary = (w3["sched"] as Array)[1]
	ck("all cells armed: the cast fizzles (no event, fizzled result)", (c3["events"] as Array).is_empty() and bool(c3["fizzled"])
		and bool(((w3["done"] as Array)[0]["r"] as Dictionary).get("fizzled", false)))


func test_field_cap_and_menu_reasons() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	var arb: SwingArbiter = w["arb"]
	var sc: SkillConfig = w["sc"]
	var cds := SkillCooldowns.new()
	var ctx: Dictionary = {SkillAvailability.CTX_ARMED_COUNT_FN: func(id: String) -> int: return arb.armed_cast_count(CombatState.Side.PLAYER, id)}
	ck("available with no field", bool(SkillAvailability.check(sc, cds, ID, 2, 1, ctx)["available"]))
	_cast(w, "bar2", BAR2)
	_run(w, 0.46)
	_cast(w, "bar2", _cells([Vector2i(4, 0), Vector2i(5, 0)]))
	_run(w, 0.46)
	var r: Dictionary = SkillAvailability.check(sc, cds, ID, 2, 1, ctx)
	ck("2 armed fields: unavailable, reason field_cap", not bool(r["available"]) and r["reason"] == "field_cap", str(r))
	var open: Array[Vector2i] = SkillAvailability.delayed_open_cells(BAR2, arb.armed_cells(CombatState.Side.PLAYER), w["fx"])
	var r2: Dictionary = SkillAvailability.check(sc, cds, ID, 2, 1, {SkillAvailability.CTX_DELAYED_OPEN_CELLS: open})
	ck("placed only on armed cells: unavailable, reason no_valid_cells (no Blocks / cooldown spent)", open.is_empty()
		and not bool(r2["available"]) and r2["reason"] == "no_valid_cells", str(r2))
	ck("other cards ignore the delayed context", bool(SkillAvailability.check(sc, cds, "kiem_khi", 2, 1,
		{SkillAvailability.CTX_DELAYED_OPEN_CELLS: open})["available"]))


func test_burn_payload() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	_cast(w, "bar4", BAR4)
	_run(w, 1.94)
	var before: float = _lost(w)
	(w["arb"] as SwingArbiter).tick(0.02)
	ck("the blast tick deals exactly the hit (24, Model C), no entry burn tick", is_equal_approx(_lost(w) - before, 24.0), "%.2f" % (_lost(w) - before))
	var fx: StatusEffects = w["fx"]
	ck("every seal cell burns after the detonation", fx.burning_cells().size() == 4)
	var w2: Dictionary = _world(Vector2i(7, 2))
	_cast(w2, "bar4", BAR4)
	_run(w2, 2.0)
	ck("a missed field still burns its cells", (w2["fx"] as StatusEffects).burning_cells().size() == 4 and is_equal_approx(_lost(w2), 0.0))
	_run(w2, 2.1)
	ck("the burn ends after 2.0 s", (w2["fx"] as StatusEffects).burning_cells().is_empty())
	# the boss standing in the fire takes the existing ticks (0.5 s x 1.5)
	var hp_after_blast: float = _lost(w)
	_run(w, 0.55)
	ck("the burning cell ticks 1.5 per 0.5 s", is_equal_approx(_lost(w) - hp_after_blast, 1.5), "%.2f" % (_lost(w) - hp_after_blast))


func test_caster_hit_and_death() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	_cast(w, "bar2", BAR2)
	_run(w, 0.6)
	(w["state"] as CombatState).damage(CombatState.Side.PLAYER, 10.0)
	_run(w, 1.5)
	ck("the Mage hit during the fuse: the seals still detonate (24)", is_equal_approx(_lost(w), 24.0), "%.1f" % _lost(w))
	var w2: Dictionary = _world(Vector2i(6, 1))
	_cast(w2, "bar2", BAR2)
	_run(w2, 0.6)
	(w2["state"] as CombatState).damage(CombatState.Side.PLAYER, 5000.0)
	_run(w2, 1.5)
	ck("caster death: the field is cleared, nothing fires", (w2["log"] as Array).is_empty() and (w2["arb"] as SwingArbiter).armed_cells(CombatState.Side.PLAYER).is_empty())
	# interrupted during the 0.45 s cast: no seals
	var w3: Dictionary = _world(Vector2i(6, 1))
	_cast(w3, "bar2", BAR2)
	_run(w3, 0.2)
	(w3["player"] as CutActor).cancel()
	_run(w3, 2.0)
	ck("a cast cancelled before its end arms nothing", (w3["sched"] as Array).is_empty() and (w3["log"] as Array).is_empty())


func test_threat_feed() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	var arb: SwingArbiter = w["arb"]
	_cast(w, "bar2", BAR2)
	_run(w, 0.46)
	var p: Dictionary = arb.pending_cells(CombatState.Side.PLAYER)
	var armed: Array = p.get("armed", []) as Array
	ck("pending: armed seals reported apart, with their time left", not p.has("cells") and armed.size() == 1
		and (armed[0]["cells"] as Array).size() == 2 and absf(float(armed[0]["time_left"]) - 1.49) < 0.011, str(p))
	var player: CutActor = w["player"]
	_cast(w, "bar2", _cells([Vector2i(4, 0), Vector2i(5, 0)]))
	ck("a running delayed swing's threat delay = its fuse", is_equal_approx(CastResolver.threat_delay((w["sc"] as SkillConfig).get_skill(ID),
		player.get_cast_context()), 1.5))
	ck("a direct card has no threat delay", is_equal_approx(CastResolver.threat_delay((w["sc"] as SkillConfig).get_skill("kiem_khi"), {}), 0.0))


func test_determinism() -> void:
	var runs: Array = []
	for k: int in 2:
		var w: Dictionary = _world(Vector2i(5, 1))
		_cast(w, "square", SQUARE)
		_run(w, 1.0)
		(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 0))
		_run(w, 2.5)
		runs.append([str(w["log"]), _lost(w), str((w["fx"] as StatusEffects).burning_cells())])
	ck("same inputs, same events, damage and burn", runs[0] == runs[1], str(runs[0]))


# Model C (docs/skill-v2/13-hoa-loi-damage-models.md, approved for the prototype 2026-11-09): data-driven, generic.
func test_model_c_rule() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("hoa_loi damage_cells_rule = footprint + 1 (data)", s["damage_cells_rule"]["mode"] == "footprint" and int(s["damage_cells_rule"]["extra"]) == 1)
	ck("rule: 5 armed on a 1-cell boss count 2; on a 2x2 boss 5; 2 armed count 2", CastResolver.damage_cells(s, 5, 1) == 2
		and CastResolver.damage_cells(s, 5, 4) == 5 and CastResolver.damage_cells(s, 2, 1) == 2)
	ck("every other card keeps all cells (default rule)", CastResolver.damage_cells(sc.get_skill("tram_dia"), 5, 1) == 5
		and CastResolver.damage_cells(sc.get_skill("ngan_kiem"), 5, 1) == 5 and CastResolver.damage_cells(sc.get_skill("hoa_tran"), 5, 1) == 5)
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "instant", "damage_cells_rule": {"mode": "footprint", "extra": 1}}, "damage")
	ck("a damage_cells_rule on an instant card is rejected (reported)", not (bad["errors"] as Array).is_empty())
	var bad2: Dictionary = CastResolver.validate("x", {"resolve": "delayed", "damage_cells_rule": {"mode": "nope"}}, "damage")
	ck("an unknown damage_cells_rule mode is rejected", not (bad2["errors"] as Array).is_empty())
	var sq: Dictionary = CastResolver.validate("x", {"resolve": "delayed", "fuse_mult": 2.5, "shape_clause": {"tag": "square", "fuse_mult_scale": 1.2}}, "damage")
	ck("square ratio form: fuse_mult_scale 1.2 follows the base (2.5 -> 3.0)", (sq["errors"] as Array).is_empty()
		and is_equal_approx(float(CastResolver.fuse_timing({"fuse_sec": 1.5, "fuse_mult": 2.5, "shape_clause": sq["shape_clause"]},
			_ctx(_world(Vector2i(7, 2)), "square", SQUARE))["fuse_mult"]), 3.0))
	# five armed cells, 1-cell boss: Model C counts 2 cells
	var w: Dictionary = _world(Vector2i(5, 1))
	var plus: Array[Vector2i] = _cells([Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)])
	_cast(w, "plus5", plus)
	_run(w, 2.0)
	ck("plus field on a 1-cell boss (Model C): 6 x 2 x 2.0 = 24 (not 60)", is_equal_approx(_lost(w), 24.0), "%.1f" % _lost(w))
	ck("the impact event reports the damage the HUD shows (24)", is_equal_approx(float((w["log"] as Array)[0]["dmg"]), 24.0))

extends SceneTree
## Skill v2 Trảm Địa (tram_dia, docs/skill-v2/02-skill-bible.md; 02-mechanics-catalog.md M03 + M16): the Knight's
## arrival card through the REAL path (SkillConfig from cards.json, CastContext from real pieces, SwingArbiter + combat
## clock, CutEffects). Covers data / ownership, min cells, cooldown, timing, burst x1.5 + Pin 0.4 s, surge order, the
## line_h clause and its cap, L / T / plus geometry, multi-piece and disconnected casts, holes (at resolve and later),
## a moving and a 2x2 boss, interruption / cancellation, passive / Awakening / Resonance / relic hooks, determinism,
## the code-drawn surge VFX helpers and cleanup. Numbers: dpc 6 (level 1).
## Run: godot --headless --path . -s res://tests/unit/combat/tram_dia_test.gd

const EPS: float = 0.0001
const ID: String = "tram_dia"
const HERO := Vector2i(1, 1)

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data_and_ownership()
	test_min_cells_and_cooldown()
	test_timing_on_the_clock()
	test_burst_and_pin()
	test_surge_order_and_line_h_bonus()
	test_line_h_cap_and_no_clause()
	test_l_shape()
	test_t_and_plus_branching()
	test_multi_piece_scope()
	test_disconnected_regions()
	test_locked_cells()
	test_moving_boss()
	test_two_by_two_boss()
	test_interruption_and_cancel()
	test_hooks_passive_awakening_resonance_relic()
	test_determinism()
	test_vfx_helpers()
	test_cleanup()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# A match on a [param cols] x 3 half: hero at (1,1), boss at [param boss].
func _world(cols: int, boss: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(cols, 3)
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
		log.append({"cell": (ev["cells"] as Array)[0], "kind": ev["kind"], "step": ev.get("step", -1), "mult": ev["mult"],
			"t": ev["t"], "hit": hit, "dmg": float(ev.get("damage", 0.0)), "at": arb.clock(), "from": ev.get("from", Vector2i(-9, -9)),
			"pinned": ev.get("pinned", false)}))
	var done: Array = []
	arb.swing_resolved.connect(func(side: int, r: Dictionary) -> void: done.append({"side": side, "r": r}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "enemy": enemy, "arb": arb, "log": log, "done": done}


func _piece(shape: String, rot: int) -> Piece:
	return PieceLibrary.load_from_file().make_piece(shape, rot)


# The cast context of [param pieces] placed on [param cells_per_piece] (parallel arrays), as CombatView builds it.
func _ctx(w: Dictionary, pieces: Array[Piece], cells_per_piece: Array) -> Dictionary:
	var sc: SkillConfig = w["sc"]
	return CastContext.build(ID, 1, pieces, cells_per_piece, sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER,
		HERO, {"cast_mode": "direct"})


func _cast(w: Dictionary, cells: Array[Vector2i], ctx: Dictionary, ticks: float = 3.0) -> void:
	(w["player"] as CutActor).begin_swing(cells, ID, true, 1, 0.5, {}, ctx)
	if ticks > 0.0:
		(w["arb"] as SwingArbiter).tick(ticks)


func _cells(pts: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Variant in pts:
		out.append(p as Vector2i)
	return out


func _hp_lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


func _plan(cells: Array[Vector2i], ctx: Dictionary, locked: Array = []) -> Array:
	var sc: SkillConfig = SkillConfig.load_from_file()
	return CastResolver.plan(sc.get_skill(ID), cells, ctx, SkillDelivery.DEFAULT_TIMING, locked)["events"]


func test_data_and_ownership() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("tram_dia exists, implemented, damage, rare", bool(s.get("implemented", false)) and s["effect"] == "damage" and s["rarity"] == "rare")
	ck("dpc 6, cd 6, min 3 cells", is_equal_approx(float(s["damage_per_cell"]), 6.0) and is_equal_approx(float(s["cooldown_sec"]), 6.0)
		and int(s["min_cells"]) == 3)
	ck("direct, CASTER_TO_TARGET hero_pack, resolve arrival, max_hits 1", sc.cast_mode(ID) == "direct"
		and s["delivery"]["type"] == SkillDelivery.CASTER_TO_TARGET and s["delivery"]["travel"] == "hero_pack"
		and s["resolve"] == "arrival" and int(s["max_hits"]) == 1)
	ck("burst x1.5, Pin 0.4 s, clause line_h +0.15 / step cap +0.45", is_equal_approx(float(s["burst_first"]), 1.5)
		and is_equal_approx(float(s["burst_pin_sec"]), 0.4) and s["shape_clause"]["tag"] == "line_h"
		and is_equal_approx(float(s["shape_clause"]["surge_per_step"]), 0.15) and is_equal_approx(float(s["shape_clause"]["surge_cap"]), 0.45))
	ck("Knight-only: hero kiem_si, never a reward / shop pool card, not in the starter deck, never the boss's",
		sc.hero_of(ID) == "kiem_si" and not sc.is_pool_card(ID) and not sc.default_deck.has(ID)
		and not sc.is_boss_playable(ID) and not sc.boss_card_order().has(ID))
	ck("no resolve validation error in cards.json", sc.validation_errors.is_empty(), str(sc.validation_errors))


func test_min_cells_and_cooldown() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cd := SkillCooldowns.new()
	ck("2 cells: not available", not bool(SkillAvailability.check(sc, cd, ID, 2)["available"]))
	ck("3 cells: available", bool(SkillAvailability.check(sc, cd, ID, 3)["available"]))
	cd.start(ID, float(sc.resolved(ID, 1)["cooldown_sec"]))
	ck("on cooldown after a cast", not bool(SkillAvailability.check(sc, cd, ID, 3)["available"]) and is_equal_approx(cd.remaining(ID), 6.0))
	cd.tick(6.0)
	ck("ready again after 6 s", bool(SkillAvailability.check(sc, cd, ID, 3)["available"]))
	ck("level 2 cooldown 5 s (upgrade -1)", is_equal_approx(float(sc.resolved(ID, 2)["cooldown_sec"]), 5.0))


func test_timing_on_the_clock() -> void:
	var w: Dictionary = _world(3, Vector2i(5, 1))
	var cells: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	var p: Array[Piece] = [_piece("bar3", 0)]
	_cast(w, cells, _ctx(w, p, [cells]), 0.0)
	var arb: SwingArbiter = w["arb"]
	arb.tick(0.49)
	ck("nothing lands before the swing end (projectile still flying)", (w["log"] as Array).is_empty())
	arb.tick(1.0)
	var at: Array = (w["log"] as Array).map(func(e: Dictionary) -> float: return float(e["at"]))
	ck("burst at the swing end 0.50, surge 0.71 / 0.79 (first_hold 0.13 + 0.08 / step)", at.size() == 3
		and absf(at[0] - 0.5) < EPS and absf(at[1] - 0.71) < EPS and absf(at[2] - 0.79) < EPS, str(at))


func test_burst_and_pin() -> void:
	var w: Dictionary = _world(3, Vector2i(3, 1))
	var cells: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	var p: Array[Piece] = [_piece("bar3", 0)]
	_cast(w, cells, _ctx(w, p, [cells]), 0.0)
	(w["arb"] as SwingArbiter).tick(0.6)
	var fx: StatusEffects = w["fx"]
	ck("boss on the burst cell: 6 x 3 x 1.5 = 27", is_equal_approx(_hp_lost(w), 27.0), str(_hp_lost(w)))
	ck("burst Pins the boss for 0.4 s", fx.is_pinned(CombatState.Side.ENEMY) and absf(float(fx._pins[CombatState.Side.ENEMY]) - 0.4) < EPS)
	(w["arb"] as SwingArbiter).tick(1.0)
	ck("one hit per cast (later cells skip it)", is_equal_approx(_hp_lost(w), 27.0)
		and (w["log"] as Array).filter(func(e: Dictionary) -> bool: return e["hit"]).size() == 1)
	fx.tick(0.41, w["state"])
	ck("Pin over after 0.4 s", not fx.is_pinned(CombatState.Side.ENEMY))
	# No Pin when the burst misses.
	var w2: Dictionary = _world(3, Vector2i(5, 1))
	_cast(w2, cells, _ctx(w2, p, [cells]))
	ck("a burst that misses Pins nothing", not (w2["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY)
		and not bool((w2["log"] as Array)[2]["pinned"]))


func test_surge_order_and_line_h_bonus() -> void:
	# E4: bar4 flat on a 4-wide half, boss on the far cell: 24 x 1.45 = 34.8.
	var w: Dictionary = _world(4, Vector2i(7, 1))
	var cells: Array[Vector2i] = _cells([Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)])
	var p: Array[Piece] = [_piece("bar4", 0)]
	_cast(w, cells, _ctx(w, p, [cells]))
	var log: Array = w["log"]
	var order: Array = log.map(func(e: Dictionary) -> Vector2i: return e["cell"])
	ck("surge order: nearest the hero first, then outward", order == [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)], str(order))
	var mults: Array = log.map(func(e: Dictionary) -> float: return float(e["mult"]))
	ck("mults 1.5 / 1.15 / 1.30 / 1.45", absf(mults[0] - 1.5) < EPS and absf(mults[1] - 1.15) < EPS and absf(mults[2] - 1.3) < EPS
		and absf(mults[3] - 1.45) < EPS, str(mults))
	ck("E4: boss on the far cell takes 24 x 1.45 = 34.8", is_equal_approx(_hp_lost(w), 34.8), str(_hp_lost(w)))


func test_line_h_cap_and_no_clause() -> void:
	var w: Dictionary = _world(5, Vector2i(9, 1))
	var cells: Array[Vector2i] = _cells([Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1)])
	var p: Array[Piece] = [_piece("bar5", 0)]
	_cast(w, cells, _ctx(w, p, [cells]))
	ck("step 4 capped at +45%: 30 x 1.45 = 43.5", is_equal_approx(_hp_lost(w), 43.5), str(_hp_lost(w)))
	# A vertical bar (line_v): no clause bonus.
	var w2: Dictionary = _world(3, Vector2i(4, 2))
	var vcells: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	var vp: Array[Piece] = [_piece("bar3", 1)]
	var vctx: Dictionary = _ctx(w2, vp, [vcells])
	ck("bar3 turned is line_v", CastContext.has_tag(vctx, "line_v") and not CastContext.has_tag(vctx, "line_h"))
	_cast(w2, vcells, vctx)
	ck("line_v: surge without bonus, 6 x 3 = 18", is_equal_approx(_hp_lost(w2), 18.0), str(_hp_lost(w2)))
	# Effective cells (Awakening) never change tags: a context without pieces gets no clause.
	ck("no pieces in the context -> clause off", not CastResolver.clause_holds({"tag": "line_h"}, {"cells": vcells}))


func test_l_shape() -> void:
	# l4 laid as an L: (3,0)(3,1)(3,2)(4,2) - the surge goes down the stem, then turns at the corner.
	var cells: Array[Vector2i] = _cells([Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2)])
	var ev: Array = _plan(cells, {"delivery": {"type": SkillDelivery.CASTER_TO_TARGET}, "caster_cell": HERO})
	var order: Array = ev.map(func(e: Dictionary) -> Vector2i: return (e["cells"] as Array)[0])
	var steps: Array = ev.map(func(e: Dictionary) -> int: return int(e["step"]))
	ck("L: lands on (3,1) (nearest the hero), then both stem ends, then turns to (4,2)",
		order == [Vector2i(3, 1), Vector2i(3, 0), Vector2i(3, 2), Vector2i(4, 2)] and steps == [0, 1, 1, 2], "%s %s" % [order, steps])
	ck("L: the corner cell is reached from the stem end", ev[3]["from"] == Vector2i(3, 2))


func test_t_and_plus_branching() -> void:
	var plus: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2)])
	var ev: Array = _plan(plus, {"delivery": {"type": SkillDelivery.CASTER_TO_TARGET}, "caster_cell": HERO})
	var by: Dictionary = {}
	for e: Dictionary in ev:
		by[(e["cells"] as Array)[0]] = e
	ck("plus: lands on the near arm (3,1), centre next", by[Vector2i(3, 1)]["kind"] == "burst" and int(by[Vector2i(4, 1)]["step"]) == 1)
	ck("plus: the three far arms branch from the centre at the same time", by[Vector2i(4, 0)]["from"] == Vector2i(4, 1)
		and by[Vector2i(5, 1)]["from"] == Vector2i(4, 1) and by[Vector2i(4, 2)]["from"] == Vector2i(4, 1)
		and is_equal_approx(float(by[Vector2i(4, 0)]["t"]), float(by[Vector2i(4, 2)]["t"])))
	var t: Array[Vector2i] = _cells([Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1)])
	var tev: Array = _plan(t, {"delivery": {"type": SkillDelivery.CASTER_TO_TARGET}, "caster_cell": HERO})
	var tby: Dictionary = {}
	for e: Dictionary in tev:
		tby[(e["cells"] as Array)[0]] = e
	ck("T: from the bar end through the junction, then the stem and the far end together",
		tby[Vector2i(3, 0)]["kind"] == "burst" and int(tby[Vector2i(4, 0)]["step"]) == 1 and int(tby[Vector2i(4, 1)]["step"]) == 2
		and int(tby[Vector2i(5, 0)]["step"]) == 2 and tby[Vector2i(4, 1)]["from"] == Vector2i(4, 0))


func test_multi_piece_scope() -> void:
	var w: Dictionary = _world(3, Vector2i(5, 1))
	var flat: Array[Vector2i] = _cells([Vector2i(4, 1), Vector2i(5, 1)])
	var mono: Array[Vector2i] = _cells([Vector2i(3, 1)])
	var p: Array[Piece] = [_piece("bar2", 0), _piece("mono", 0)]
	var ctx: Dictionary = _ctx(w, p, [flat, mono])
	ck("two pieces: one has line_h -> any_piece holds", CastResolver.clause_holds({"tag": "line_h", "scope": "any_piece"}, ctx))
	ck("all_pieces fails (mono is not line_h)", not CastResolver.clause_holds({"tag": "line_h", "scope": "all_pieces"}, ctx))
	var all: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	_cast(w, all, ctx)
	ck("the joined cast surges as one region: boss at step 2 -> 18 x 1.30 = 23.4", is_equal_approx(_hp_lost(w), 23.4), str(_hp_lost(w)))


func test_disconnected_regions() -> void:
	var w: Dictionary = _world(3, Vector2i(5, 2))
	var a: Array[Vector2i] = _cells([Vector2i(3, 0), Vector2i(4, 0)])
	var b: Array[Vector2i] = _cells([Vector2i(5, 2)])
	var p: Array[Piece] = [_piece("bar2", 0), _piece("mono", 0)]
	var all: Array[Vector2i] = _cells([Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 2)])
	_cast(w, all, _ctx(w, p, [a, b]))
	var log: Array = w["log"]
	var by: Dictionary = {}
	for e: Dictionary in log:
		by[e["cell"]] = e
	ck("main region bursts on its landing cell", by[Vector2i(3, 0)]["kind"] == "burst")
	ck("a separate region gets its own landing at t 0, no burst, no path between", by[Vector2i(5, 2)]["kind"] == "landing"
		and is_equal_approx(float(by[Vector2i(5, 2)]["t"]), 0.0) and is_equal_approx(float(by[Vector2i(5, 2)]["mult"]), 1.0)
		and by[Vector2i(5, 2)]["from"] == CastResolver.NO_CELL)
	ck("boss on the landing: plain 6 x 3 = 18 (damage counts the whole cast)", is_equal_approx(_hp_lost(w), 18.0), str(_hp_lost(w)))
	ck("no Pin from a landing", not (w["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY))


func test_locked_cells() -> void:
	# Locked at the resolve: the middle of a bar3 is a hole -> the far cell is cut off (own landing), no event on the hole.
	var w: Dictionary = _world(3, Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	var cells: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	fx.apply_drop(CombatState.Side.ENEMY, [Vector2i(4, 1)] as Array[Vector2i], 5.0, 5.0)
	ck("the drop locks the cell", fx.is_locked(Vector2i(4, 1)))
	var p: Array[Piece] = [_piece("bar3", 0)]
	_cast(w, cells, _ctx(w, p, [cells]))
	var log: Array = w["log"]
	var lcells: Array = log.map(func(e: Dictionary) -> Vector2i: return e["cell"])
	ck("no event on the locked cell; the surge does not cross it", not lcells.has(Vector2i(4, 1)) and lcells.size() == 2)
	ck("the far cell is a separate landing", log.size() == 2 and log[1]["kind"] == "landing")
	ck("damage counts the 2 open cells: 12", is_equal_approx(_hp_lost(w), 12.0), str(_hp_lost(w)))
	# Locked AFTER the resolve, before its event: that event cannot hit.
	var w2: Dictionary = _world(3, Vector2i(5, 1))
	_cast(w2, cells, _ctx(w2, p, [cells]), 0.0)
	(w2["arb"] as SwingArbiter).tick(0.55)
	(w2["fx"] as StatusEffects).apply_drop(CombatState.Side.ENEMY, [Vector2i(5, 1)] as Array[Vector2i], 5.0, 5.0)
	(w2["arb"] as SwingArbiter).tick(1.0)
	ck("a cell locked mid-surge: its event misses", is_equal_approx(_hp_lost(w2), 0.0)
		and not bool((w2["log"] as Array)[2]["hit"]))


func test_moving_boss() -> void:
	var cells: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	var p: Array[Piece] = [_piece("bar3", 0)]
	# Boss leaves the mask after the burst: never hit.
	var w: Dictionary = _world(3, Vector2i(4, 1))
	_cast(w, cells, _ctx(w, p, [cells]), 0.0)
	(w["arb"] as SwingArbiter).tick(0.55)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(4, 0))
	(w["arb"] as SwingArbiter).tick(1.0)
	ck("boss stepped out before the surge: no damage", is_equal_approx(_hp_lost(w), 0.0))
	# Boss steps ahead of the surge onto the far cell: hit there at step 2.
	var w2: Dictionary = _world(3, Vector2i(4, 1))
	_cast(w2, cells, _ctx(w2, p, [cells]), 0.0)
	(w2["arb"] as SwingArbiter).tick(0.55)
	(w2["state"] as CombatState).set_enemy_cell(Vector2i(5, 1))
	(w2["arb"] as SwingArbiter).tick(1.0)
	ck("boss moved onto the far cell: hit at step 2, 18 x 1.30 = 23.4", is_equal_approx(_hp_lost(w2), 23.4), str(_hp_lost(w2)))


func test_two_by_two_boss() -> void:
	var w: Dictionary = _world(3, Vector2i(4, 1))
	var fp: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	ck("2x2 footprint set", (w["state"] as CombatState).set_enemy_footprint(fp))
	var cells: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 2)])
	var p: Array[Piece] = [_piece("l4", 0)]
	_cast(w, cells, _ctx(w, p, [cells]))
	var hits: int = (w["log"] as Array).filter(func(e: Dictionary) -> bool: return e["hit"]).size()
	ck("2x2 boss under three surge cells: one hit (first reached, step 1: 24 x 1.0)", hits == 1, "hits=%d lost=%.1f" % [hits, _hp_lost(w)])
	ck("damage is one hit's worth", _hp_lost(w) > 0.0 and _hp_lost(w) <= 24.0 * 1.45 + EPS)


func test_interruption_and_cancel() -> void:
	var cells: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	var p: Array[Piece] = [_piece("bar3", 0)]
	var w: Dictionary = _world(3, Vector2i(5, 1))
	_cast(w, cells, _ctx(w, p, [cells]), 0.0)
	(w["arb"] as SwingArbiter).tick(0.3)
	(w["player"] as CutActor).cancel()
	(w["arb"] as SwingArbiter).tick(2.0)
	ck("Knight interrupted before the release: nothing scheduled, no damage", (w["log"] as Array).is_empty() and _hp_lost(w) == 0.0)
	var w2: Dictionary = _world(3, Vector2i(5, 1))
	var hero: Array[Vector2i] = [HERO]
	(w2["enemy"] as CutActor).begin_swing(hero, "kiem_khi", false, 1, 2.0)
	_cast(w2, cells, _ctx(w2, p, [cells]), 0.0)
	(w2["arb"] as SwingArbiter).tick(0.6)
	ck("enemy swing alive after the (missing) burst", (w2["enemy"] as CutActor).is_swinging())
	(w2["arb"] as SwingArbiter).tick(0.3)
	ck("cancelled by the surge's damaging event at 0.79", not (w2["enemy"] as CutActor).is_swinging()
		and is_equal_approx((w2["state"] as CombatState).player_hp, 1000.0))


func test_hooks_passive_awakening_resonance_relic() -> void:
	var cells: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	var p: Array[Piece] = [_piece("bar3", 0)]
	# Awakening (Trảm): cells x2 for damage only, the path / tags stay physical.
	var w: Dictionary = _world(3, Vector2i(5, 1))
	(w["arb"] as SwingArbiter).player_cells_modifier = func(n: int) -> int: return n * 2
	_cast(w, cells, _ctx(w, p, [cells]))
	ck("Awakening x2 cells: 6 x 6 x 1.30 = 46.8, still 3 events", is_equal_approx(_hp_lost(w), 46.8) and (w["log"] as Array).size() == 3,
		str(_hp_lost(w)))
	# Passive (damage modifier) and relic hook each see the cast's cell count and the damage after S.
	var w2: Dictionary = _world(3, Vector2i(5, 1))
	var seen: Array = []
	(w2["arb"] as SwingArbiter).player_damage_modifier = func(n: int, d: float) -> float:
		seen.append(["passive", n, d])
		return d + 1.0
	(w2["arb"] as SwingArbiter).player_relic_modifier = func(n: int, d: float) -> float:
		seen.append(["relic", n, d])
		return d * 2.0
	_cast(w2, cells, _ctx(w2, p, [cells]))
	ck("relic then passive on the hit: (18 x 1.30) x 2 + 1 = 47.8", is_equal_approx(_hp_lost(w2), 47.8), str(seen))
	ck("hooks see the cast's 3 cells", seen.size() == 2 and int(seen[0][1]) == 3 and int(seen[1][1]) == 3)
	# Resonance (featured bonus x1.5) multiplies too.
	var w3: Dictionary = _world(3, Vector2i(5, 1))
	(w3["player"] as CutActor).begin_swing(cells, ID, true, 1, 0.5, {"damage_mult": 1.5}, _ctx(w3, p, [cells]))
	(w3["arb"] as SwingArbiter).tick(3.0)
	ck("Resonance x1.5: 18 x 1.30 x 1.5 = 35.1", is_equal_approx(_hp_lost(w3), 35.1), str(_hp_lost(w3)))


func _log_of(steps: Array) -> Array:
	var w: Dictionary = _world(3, Vector2i(5, 1))
	var cells: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	var p: Array[Piece] = [_piece("bar3", 0)]
	_cast(w, cells, _ctx(w, p, [cells]), 0.0)
	for s: Variant in steps:
		(w["arb"] as SwingArbiter).tick(float(s))
	# Clock times compared to 1e-4: a tick that ends a hair before the swing end costs the arbiter's 1e-6 minimum slice.
	return (w["log"] as Array).map(func(e: Dictionary) -> String:
		var c: Dictionary = e.duplicate()
		c["at"] = snappedf(float(c["at"]), 0.0001)
		return str(c))


func test_determinism() -> void:
	var a: Array = _log_of([3.0])
	ck("same cast -> same events", a == _log_of([3.0]) and a.size() == 3)
	var b: Array = _log_of([0.1, 0.33, 0.05, 0.02, 0.4, 2.0])
	ck("tick sizes do not change times or order", a == b, "
%s
%s" % [str(a), str(b)])
	var cells: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2)])
	var rev: Array[Vector2i] = cells.duplicate()
	rev.reverse()
	var ctx: Dictionary = {"delivery": {"type": SkillDelivery.CASTER_TO_TARGET}, "caster_cell": HERO}
	var o1: Array = _plan(cells, ctx).map(func(e: Dictionary) -> String: return str(e["cells"]) + str(e["t"]))
	var o2: Array = _plan(rev, ctx).map(func(e: Dictionary) -> String: return str(e["cells"]) + str(e["t"]))
	ck("plan order does not depend on the mask's listing order", o1 == o2, "\n%s\n%s" % [o1, o2])


func test_vfx_helpers() -> void:
	var a := Vector2i(10, 10)
	var b := Vector2i(40, 10)
	ck("crack: nothing before / after its life", CastFloorFx.crack_rects(a, b, -0.1, 0.08, 0.6, 2, 3, 1).is_empty()
		and CastFloorFx.crack_rects(a, b, 0.6, 0.08, 0.6, 2, 3, 1).is_empty())
	var early: int = CastFloorFx.crack_rects(a, b, 0.02, 0.08, 0.6, 2, 3, 1).size()
	var full: int = CastFloorFx.crack_rects(a, b, 0.08, 0.08, 0.6, 2, 3, 1).size()
	var late: int = CastFloorFx.crack_rects(a, b, 0.5, 0.08, 0.6, 2, 3, 1).size()
	ck("crack reveals from the source, then fades", early < full and late < full and early > 0, "%d %d %d" % [early, full, late])
	ck("crack is deterministic", CastFloorFx.crack_rects(a, b, 0.05, 0.08, 0.6, 2, 3, 7) == CastFloorFx.crack_rects(a, b, 0.05, 0.08, 0.6, 2, 3, 7))
	var s0: Array[Rect2i] = CastFloorFx.shock_rects(Vector2i(50, 50), 0.01, 0.3, 30, 12, 4)
	var s1: Array[Rect2i] = CastFloorFx.shock_rects(Vector2i(50, 50), 0.25, 0.3, 30, 12, 4)
	ck("shockwave: 12 squares that move out and shrink", s0.size() == 12 and s1.size() == 12
		and Vector2(s1[0].get_center()).distance_to(Vector2(50, 50)) > Vector2(s0[0].get_center()).distance_to(Vector2(50, 50))
		and s1[0].size.x < s0[0].size.x)
	ck("shockwave ends", CastFloorFx.shock_rects(Vector2i(50, 50), 0.3, 0.3, 30, 12, 4).is_empty())
	var steel: Array[Color] = CastVfx.block_colours("kiem_si")
	ck("surge colours are the Knight's steel, not telegraph red", steel[0] != Color("#E5293B") and steel[1] != Color("#E5293B"))
	# Polish pass: the primary eruption stands UP on screen from the tile, is far bigger than a surge cell's marks, and ends.
	var base := Vector2i(100, 120)
	var e1: Array[Dictionary] = CastFloorFx.eruption_rects(base, 55, 0.1, 0.5, 3)
	var top: int = 9999
	var area: int = 0
	for it: Dictionary in e1:
		var r: Rect2i = it["rect"]
		top = mini(top, r.position.y)
		area += r.size.x * r.size.y
	ck("eruption rises above the tile (> 1 cell up at 0.1 s)", base.y - top > 55, "rise=%d" % (base.y - top))
	var crack_area: int = 0
	for r: Rect2i in CastFloorFx.crack_rects(a, b, 0.08, 0.08, 0.6, 3, 3, 1):
		crack_area += r.size.x * r.size.y
	ck("the eruption covers far more pixels than a surge crack", area > crack_area * 3, "%d vs %d" % [area, crack_area])
	ck("eruption shards never go below the tile", e1.all(func(it: Dictionary) -> bool: return (it["rect"] as Rect2i).position.y <= base.y + 3))
	ck("eruption ends and is deterministic", CastFloorFx.eruption_rects(base, 55, 0.5, 0.5, 3).is_empty()
		and CastFloorFx.eruption_rects(base, 55, 0.2, 0.5, 3) == CastFloorFx.eruption_rects(base, 55, 0.2, 0.5, 3))
	# The incoming front travels from the source cell to the next one, its lit head leading.
	var f0: Array[Rect2i] = CastFloorFx.front_rects(a, b, 0.2, 4, 5)
	var f1: Array[Rect2i] = CastFloorFx.front_rects(a, b, 0.8, 4, 5)
	ck("front moves toward the next cell and never trails behind the source", not f0.is_empty() and f1[0].get_center().x > f0[0].get_center().x
		and f0.all(func(r: Rect2i) -> bool: return r.get_center().x >= a.x - 3))
	ck("no front outside [0, 1]", CastFloorFx.front_rects(a, b, -0.1, 4, 5).is_empty() and CastFloorFx.front_rects(a, b, 1.1, 4, 5).is_empty())
	# Art production 2026-11-08: Trảm Địa's own cast overrides; every other card keeps the hero entry.
	var tram: Dictionary = CastVfx.entry_for("kiem_si", "burst", "tram_dia")
	var other: Dictionary = CastVfx.entry_for("kiem_si", "burst", "thiet_kiem")
	ck("tram_dia burst uses the eruption pack and its floor mark", tram.get("impact") == "impact_eruption_tram_dia"
		and tram.get("impact_mark") == "mark_eruption_tram_dia", str(tram.get("impact")))
	ck("other Knight cards keep the shared steel burst", other.get("impact") == "impact_burst_big_steel"
		and other.get("impact_mark") == "mark_stamp_big_steel", str(other.get("impact")))
	ck("tram_dia casts cast_forward, others cast_gesture", CastVfx.cast_clip("tram_dia", "cast_gesture") == "cast_forward"
		and CastVfx.cast_clip("thiet_kiem", "cast_gesture") == "cast_gesture")
	var fv := FloorVfx.new()
	ck("both eruption packs load (7 and 12 frames, ground_center)", fv.pack("impact_eruption_tram_dia") != null
		and fv.pack("mark_eruption_tram_dia") != null and int(fv.entry("impact_eruption_tram_dia")["frames"]) == 7
		and int(fv.entry("mark_eruption_tram_dia")["frames"]) == 12 and fv.entry("impact_eruption_tram_dia")["anchor"] == "ground_center")
	# Preview marks: landing corners, step chevron, blocked X, all inside the tile.
	var cell := Rect2i(0, 0, 40, 30)
	for kind: String in ["burst", "landing", "surge", "blocked"]:
		var pr: Array[Rect2i] = CastFloorFx.preview_rects(cell, kind, Vector2i(-40, 15))
		ck("preview %s marks stay inside the tile" % kind, not pr.is_empty() and pr.all(func(r: Rect2i) -> bool: return cell.grow(1).encloses(r)))


func test_cleanup() -> void:
	var w: Dictionary = _world(3, Vector2i(5, 1))
	var cells: Array[Vector2i] = _cells([Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)])
	var p: Array[Piece] = [_piece("bar3", 0)]
	_cast(w, cells, _ctx(w, p, [cells]))
	var arb: SwingArbiter = w["arb"]
	ck("after the cast: no event, no cast left on the clock", arb.scheduled_count() == 0 and arb.active_cast_count() == 0)
	var done: Array = w["done"]
	ck("one card-level result at the end: hit, scheduled, 1 hit", done.size() == 1 and bool(done[0]["r"]["hit"])
		and bool(done[0]["r"]["scheduled"]) and int(done[0]["r"]["hits"]) == 1)
	# A death mid-surge drops the rest.
	var w2: Dictionary = _world(3, Vector2i(5, 1))
	_cast(w2, cells, _ctx(w2, p, [cells]), 0.0)
	(w2["arb"] as SwingArbiter).tick(0.55)
	(w2["state"] as CombatState).damage(CombatState.Side.PLAYER, 5000.0)
	(w2["arb"] as SwingArbiter).tick(1.0)
	ck("caster death mid-surge: the rest is cleared", (w2["arb"] as SwingArbiter).scheduled_count() == 0
		and (w2["log"] as Array).size() == 1 and (w2["done"] as Array).is_empty())

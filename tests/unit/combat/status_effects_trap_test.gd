extends SceneTree
## Skill v2 batch 3, Bẫy Kẹp (bay_kep) and Bẫy Lò Xo (bay_lo): the M09 trap zone through the REAL path (cards.json,
## CastContext from real pieces, CutActor, SwingArbiter, CutEffects._form_field, StatusEffects.fire_trap): data, the
## cells arm (zone kind trap) and fire on the first entry for dpc x the trap cells under the footprint + Pin (the
## line_v clause 1.6 s), a cast on the unit's own cell fires at once, the spring trap flings 2 (a short fling slams,
## R3), the trap cap (2 casts, field_cap), a lock disarms without firing, a player zone never overwrites a trap, and
## determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/status_effects_trap_test.gd

const HERO := Vector2i(1, 1)
const STEP: float = 0.01

var fails: int = 0
var _lib: PieceLibrary


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	_lib = PieceLibrary.load_from_file()
	test_data()
	test_arms_then_fires_on_entry()
	test_line_v_clause_pin()
	test_own_cell_fires_at_once()
	test_spring_trap_flings_and_slams()
	test_cap_and_disarm()
	test_player_zone_never_overwrites_a_trap()
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
	arb.reactions = CombatConfig.load_from_file().reactions()
	var fired: Array = []
	fx.trap_fired.connect(func(side: int, cast_id: int, cells: Array[Vector2i], damage: float) -> void:
		fired.append({"side": side, "cast_id": cast_id, "cells": cells, "damage": damage}))
	var done: Array = []
	arb.swing_resolved.connect(func(_side: int, r: Dictionary) -> void: done.append(r))
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "arb": arb, "fired": fired, "done": done}


func _ctx(sc: SkillConfig, id: String, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(id, 1, pieces, [cells], sc.get_skill(id)["delivery"], false, CombatState.Side.PLAYER, HERO)


# Casts [param id] on [param cells] and runs the swing plus [param sec] seconds.
func _cast(w: Dictionary, id: String, shape: String, cells: Array[Vector2i], sec: float = 0.2) -> void:
	(w["player"] as CutActor).begin_swing(cells, id, true, 1, -1.0, {}, _ctx(w["sc"], id, shape, cells))
	_run(w, (w["player"] as CutActor).get_duration() + sec)


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR2_ROW: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1)]
const BAR2_COL: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var k: Dictionary = sc.get_skill("bay_kep")
	ck("bay_kep: Hunter common trap card, dpc 6, 8 s, Pin 1.2 (line_v 1.6), cap 2, waves x1, no errors, never the boss's",
		sc.hero_of("bay_kep") == "tho_san" and k["cast_mode"] == "trap" and k["effect"] == "trap" and is_equal_approx(float(k["damage_per_cell"]), 6.0)
		and is_equal_approx(float(k["trap_sec"]), 8.0) and is_equal_approx(float(k["trap_pin_sec"]), 1.2)
		and is_equal_approx(float(k["shape_clause"]["trap_pin_sec"]), 1.6) and int(k["max_active"]) == 2 and k["resolve"] == "waves"
		and (k["resolve_errors"] as Array).is_empty() and not sc.is_boss_playable("bay_kep") and sc.is_zone_card("bay_kep"), str(k["resolve_errors"]))
	var l: Dictionary = sc.get_skill("bay_lo")
	ck("bay_lo: shared common trap, dpc 3, fling 2, reaction r3, cap 2", sc.hero_of("bay_lo").is_empty() and l["effect"] == "trap"
		and is_equal_approx(float(l["damage_per_cell"]), 3.0) and int(l["trap_push_cells"]) == 2 and (l["reactions"] as Array) == ["r3"]
		and int(l["max_active"]) == 2 and (l["resolve_errors"] as Array).is_empty(), str(l["resolve_errors"]))
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "waves", "max_active": 2}, "damage", "direct")
	ck("max_active on a direct non-delayed card is still rejected", not (bad["errors"] as Array).is_empty())


func test_arms_then_fires_on_entry() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	var fx: StatusEffects = w["fx"]
	_cast(w, "bay_kep", "bar2", BAR2_ROW)
	ck("the cast arms 2 trap cells (zone kind trap), no damage, the card result is a miss with the zone",
		fx.field_cells(CombatState.Side.ENEMY, StatusEffects.KIND_TRAP) == BAR2_ROW and fx.zone_kind_at(Vector2i(5, 1)) == "trap"
		and is_zero_approx(_lost(w)) and (w["done"] as Array).size() == 1 and not bool((w["done"] as Array)[0]["hit"])
		and str((w["done"] as Array)[0].get("zone_kind", "")) == "trap", str(w["done"]))
	ck("one armed trap cast of bay_kep", fx.trap_cast_count(CombatState.Side.ENEMY, "bay_kep") == 1 and fx.trap_cast_count(CombatState.Side.ENEMY) == 1)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(w, STEP)
	ck("the boss steps onto (6,1): the whole trap fires, 6 x 1 cell under it = 6, Pinned 1.2 s, zone consumed",
		is_equal_approx(_lost(w), 6.0) and fx.is_pinned(CombatState.Side.ENEMY) and absf(fx.get_pin_left(CombatState.Side.ENEMY) - 1.2) < 0.02
		and fx.field_cells(CombatState.Side.ENEMY).is_empty() and (w["fired"] as Array).size() == 1
		and ((w["fired"] as Array)[0]["cells"] as Array).size() == 2, "%.1f %s" % [_lost(w), str(w["fired"])])
	ck("the trap cast count is back to 0", fx.trap_cast_count(CombatState.Side.ENEMY) == 0)


func test_line_v_clause_pin() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	_cast(w, "bay_kep", "bar2", BAR2_COL)  # the piece's cells are vertical: tag line_v (the piece object is bar2; the clause reads the CELLS)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(5, 1))
	_run(w, STEP)
	ck("a vertical bar: Pin 1.6 s on the snap", absf((w["fx"] as StatusEffects).get_pin_left(CombatState.Side.ENEMY) - 1.6) < 0.02,
		"%.2f" % (w["fx"] as StatusEffects).get_pin_left(CombatState.Side.ENEMY))


func test_own_cell_fires_at_once() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	_cast(w, "bay_kep", "bar2", BAR2_ROW)
	ck("cast under the boss: snaps at once, 6, Pinned, the card result is a hit, nothing left armed", is_equal_approx(_lost(w), 6.0)
		and (w["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY) and bool((w["done"] as Array)[0]["hit"])
		and (w["fx"] as StatusEffects).field_cells(CombatState.Side.ENEMY).is_empty(), "%.1f" % _lost(w))


func test_spring_trap_flings_and_slams() -> void:
	# bar2 (4,1)-(5,1), boss on (7,1): step to (6,1) then (5,1) -> fling 2 toward +x: (6,1) (7,1), full move, no slam
	var w: Dictionary = _world(Vector2i(7, 1))
	var cells: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1)]
	_cast(w, "bay_lo", "bar2", cells)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(5, 1))
	_run(w, STEP)
	ck("spring trap: 3 damage, flung 2 to (7,1), no slam", is_equal_approx(_lost(w), 3.0) and (w["state"] as CombatState).enemy_cell == Vector2i(7, 1),
		"%.1f %s" % [_lost(w), str((w["state"] as CombatState).enemy_cell)])
	# bar2 (6,1)-(7,1), boss enters (6,1): fling 2 -> (7,1) then the edge: slam 8 + Pin 0.6
	var w2: Dictionary = _world(Vector2i(5, 1))
	_cast(w2, "bay_lo", "bar2", [Vector2i(6, 1), Vector2i(7, 1)])
	(w2["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(w2, STEP)
	ck("one cell of room: 3 + R3 slam 8 = 11, (7,1), Pinned 0.6", is_equal_approx(_lost(w2), 11.0)
		and (w2["state"] as CombatState).enemy_cell == Vector2i(7, 1) and absf((w2["fx"] as StatusEffects).get_pin_left(CombatState.Side.ENEMY) - 0.6) < 0.02,
		"%.1f" % _lost(w2))


func test_cap_and_disarm() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	var fx: StatusEffects = w["fx"]
	_cast(w, "bay_kep", "bar2", [Vector2i(4, 0), Vector2i(5, 0)])
	_cast(w, "bay_kep", "bar2", [Vector2i(4, 1), Vector2i(5, 1)])
	var cd := SkillCooldowns.new()
	var ctx: Dictionary = {SkillAvailability.CTX_ARMED_COUNT_FN: func(id: String) -> int: return fx.trap_cast_count(CombatState.Side.ENEMY, id)}
	var r: Dictionary = SkillAvailability.check(w["sc"], cd, "bay_kep", 2, 1, ctx)
	ck("two trap casts armed: a third Bẫy Kẹp is unavailable, reason field_cap", not bool(r["available"]) and r["reason"] == "field_cap", str(r))
	ck("another trap card (bay_lo) is not capped by them", bool(SkillAvailability.check(w["sc"], cd, "bay_lo", 2, 1, ctx)["available"]))
	# a lock (drop tile crack) on a trap cell disarms that cell without firing
	fx.apply_drop(CombatState.Side.ENEMY, [Vector2i(4, 0)] as Array[Vector2i], 0.5, 1.0)
	ck("a crack on (4,0) removed that trap cell, nothing fired, the cast still holds (5,0)", fx.field_at(CombatState.Side.ENEMY, Vector2i(4, 0)).is_empty()
		and (w["fired"] as Array).is_empty() and fx.zone_kind_at(Vector2i(5, 0)) == "trap" and is_zero_approx(_lost(w)))


func test_player_zone_never_overwrites_a_trap() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	var fx: StatusEffects = w["fx"]
	_cast(w, "bay_kep", "bar2", BAR2_ROW)
	var lit: Array[Vector2i] = fx.ignite(BAR2_ROW, 2.0, 0.5, 1.0)
	ck("a burn on the trap cells is skipped (armed zone kept), nothing lit", lit.is_empty() and fx.zone_kind_at(Vector2i(5, 1)) == "trap")
	var thorns: Array[Vector2i] = ZoneRules.cast_thorns(fx, CombatState.Side.ENEMY, BAR2_ROW, 3.0, 6.0, 1)
	ck("thorns on the trap cells are skipped too", thorns.is_empty() and fx.field_cells(CombatState.Side.ENEMY, StatusEffects.KIND_TRAP).size() == 2)
	var again: Array[Vector2i] = fx.apply_field(CombatState.Side.ENEMY, StatusEffects.KIND_TRAP, BAR2_ROW, 8.0, 99, {"dpc": 1.0})
	ck("the same kind refreshes the cells (a new trap cast on a trap)", again.size() == 2 and int(fx.field_at(CombatState.Side.ENEMY, Vector2i(5, 1))["cast_id"]) == 99)


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(7, 1))
	_cast(a, "bay_lo", "bar2", BAR2_ROW)
	(a["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(a, 0.5)
	var b: Dictionary = _world(Vector2i(7, 1))
	_cast(b, "bay_lo", "bar2", BAR2_ROW)
	(b["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(b, 0.5)
	ck("two identical runs: same fired log, HP and cell", str(a["fired"]) == str(b["fired"]) and is_equal_approx(_lost(a), _lost(b))
		and (a["state"] as CombatState).enemy_cell == (b["state"] as CombatState).enemy_cell)

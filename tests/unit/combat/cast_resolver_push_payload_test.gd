extends SceneTree
## Skill v2 batch 1, Mìn Trễ (min_tre): the data-driven `event_payload.push` of a `delayed` card through the REAL path
## (cards.json, CastContext from real pieces, CutActor, SwingArbiter clock, CutEffects, StatusEffects): data and
## validation, the push away from the mask's centre on the detonation (row, column, standing on the centre, the half's
## edge), a miss pushes nothing, Hỏa Lôi's blast still pushes nothing, and determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_push_payload_test.gd

const ID: String = "min_tre"
const HERO := Vector2i(1, 1)
const STEP: float = 0.01

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data_and_validation()
	test_plan_carries_push_payload()
	test_push_along_row_away_from_centre()
	test_push_along_column_away_from_centre()
	test_push_from_centre_cell_goes_away_from_divider()
	test_push_stops_at_half_edge_damage_still_lands()
	test_miss_pushes_nothing()
	test_hoa_loi_blast_never_pushes()
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
	player.cast_time_fn = func(id: String) -> float: return float(sc.get_skill(id).get("cast_time_sec", -1.0))
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cells": ev["cells"], "kind": ev["kind"], "mult": ev["mult"], "at": arb.clock(), "hit": hit,
			"pushed": bool(ev.get("pushed", false)), "from": ev.get("push_from", Vector2i(-9, -9)), "dmg": float(ev.get("damage", 0.0))}))
	var done: Array = []
	arb.swing_resolved.connect(func(side: int, r: Dictionary) -> void: done.append({"side": side, "r": r}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log, "done": done}


func _ctx(w: Dictionary, skill_id: String, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var sc: SkillConfig = w["sc"]
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece(shape, 0)]
	return CastContext.build(skill_id, 1, pieces, [cells], sc.get_skill(skill_id)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, shape: String, cells: Array[Vector2i], skill_id: String = ID) -> bool:
	return (w["player"] as CutActor).begin_swing(cells, skill_id, true, 1, -1.0, {}, _ctx(w, skill_id, shape, cells))


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


# Swing end + fuse, with a margin: the mine has fired by then.
func _run_past_fuse(w: Dictionary) -> void:
	_run(w, (w["player"] as CutActor).get_duration() + 1.2 + 0.05)


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR2_R1: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1)]
const SQUARE: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1), Vector2i(6, 1)]


func test_data_and_validation() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared common delayed card, implemented, in the player pool", sc.hero_of(ID).is_empty() and s["rarity"] == "common"
		and bool(s["implemented"]) and sc.is_pool_card(ID) and sc.card_order.has(ID))
	ck("resolve delayed, fuse 1.2 s x1.6, 2 fields, no resolve errors", s["resolve"] == "delayed"
		and is_equal_approx(float(s["fuse_sec"]), 1.2) and is_equal_approx(float(s["fuse_mult"]), 1.6) and int(s["max_active"]) == 2
		and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("payload = push 1 cell, no ignite", (s["event_payload"] as Dictionary).keys() == ["push"]
		and int(s["event_payload"]["push"]["cells"]) == 1)
	ck("min 2 cells, cd 6, dpc 5", int(s["min_cells"]) == 2 and is_equal_approx(float(s["cooldown_sec"]), 6.0)
		and is_equal_approx(float(s["damage_per_cell"]), 5.0))
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "delayed", "event_payload": {"push": {"cells": 5}}}, "damage")
	ck("push cells above the cap is rejected (back to instant)", bad["resolve"] == "instant" and not (bad["errors"] as Array).is_empty())
	var bad2: Dictionary = CastResolver.validate("x", {"resolve": "delayed", "event_payload": {"push": 1}}, "damage")
	ck("push must be an object", not (bad2["errors"] as Array).is_empty())
	var bad3: Dictionary = CastResolver.validate("x", {"resolve": "instant", "event_payload": {"push": {"cells": 1}}}, "damage")
	ck("a push payload on a non-delayed card is rejected", not (bad3["errors"] as Array).is_empty())
	var ok: Dictionary = CastResolver.validate("x", {"resolve": "delayed", "event_payload": {"push": {}}}, "damage")
	ck("push {} defaults to 1 cell", (ok["errors"] as Array).is_empty() and int(ok["event_payload"]["push"]["cells"]) == 1)


func test_plan_carries_push_payload() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR2_R1, {})
	var e: Dictionary = (plan["events"] as Array)[0]
	ck("one armed fuse event at 1.2 s x1.6 carrying payload push", (plan["events"] as Array).size() == 1 and bool(e["armed"])
		and e["kind"] == "fuse" and is_equal_approx(float(e["t"]), 1.2) and is_equal_approx(float(e["mult"]), 1.6)
		and int((e["payload"] as Dictionary)["push"]["cells"]) == 1)


func test_push_along_row_away_from_centre() -> void:
	# bar2 (5,1)-(6,1): the centre is (5,1); the boss on (6,1) is pushed to (7,1).
	var w: Dictionary = _world(Vector2i(6, 1))
	_cast(w, "bar2", BAR2_R1)
	_run_past_fuse(w)
	var log: Array = w["log"]
	ck("the mine hit: 5 x 2 x 1.6 = 16", is_equal_approx(_lost(w), 16.0), "%.1f" % _lost(w))
	ck("one event, hit, pushed from the mask centre (5,1)", log.size() == 1 and bool(log[0]["hit"]) and bool(log[0]["pushed"])
		and log[0]["from"] == Vector2i(5, 1), str(log))
	ck("the boss stands one cell further from the centre: (7,1)", (w["state"] as CombatState).enemy_cell == Vector2i(7, 1),
		str((w["state"] as CombatState).enemy_cell))
	var done: Array = w["done"]
	ck("the card-level result reports hit + pushed", done.size() == 1 and bool(done[0]["r"]["hit"]) and bool(done[0]["r"]["pushed"]))


func test_push_along_column_away_from_centre() -> void:
	# square (5..6, 0..1): the centre is (5,0); the boss on (5,1) is pushed down to (5,2).
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast(w, "square", SQUARE)
	_run_past_fuse(w)
	ck("square: the boss below the centre is pushed down to (5,2)", (w["state"] as CombatState).enemy_cell == Vector2i(5, 2)
		and bool((w["log"] as Array)[0]["pushed"]), str((w["state"] as CombatState).enemy_cell))


func test_push_from_centre_cell_goes_away_from_divider() -> void:
	# the boss on the centre cell (5,1) has no direction: it goes away from the divider (+x) to (6,1).
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast(w, "bar2", BAR2_R1)
	_run_past_fuse(w)
	ck("on the centre: pushed away from the divider to (6,1)", (w["state"] as CombatState).enemy_cell == Vector2i(6, 1),
		str((w["state"] as CombatState).enemy_cell))


func test_push_stops_at_half_edge_damage_still_lands() -> void:
	# bar2 (6,1)-(7,1): centre (6,1); the boss on (7,1) is at the half's edge: no cell to go to, the damage still lands.
	var w: Dictionary = _world(Vector2i(7, 1))
	var cells: Array[Vector2i] = [Vector2i(6, 1), Vector2i(7, 1)]
	_cast(w, "bar2", cells)
	_run_past_fuse(w)
	ck("edge: not pushed, still (7,1), still 16 damage", (w["state"] as CombatState).enemy_cell == Vector2i(7, 1)
		and not bool((w["log"] as Array)[0]["pushed"]) and is_equal_approx(_lost(w), 16.0), "%.1f" % _lost(w))


func test_miss_pushes_nothing() -> void:
	var w: Dictionary = _world(Vector2i(5, 2))
	_cast(w, "bar2", BAR2_R1)
	_run_past_fuse(w)
	ck("off the mines: no damage, no push, boss still (5,2)", is_equal_approx(_lost(w), 0.0)
		and not bool((w["log"] as Array)[0]["hit"]) and not bool((w["log"] as Array)[0]["pushed"])
		and (w["state"] as CombatState).enemy_cell == Vector2i(5, 2))


func test_hoa_loi_blast_never_pushes() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	_cast(w, "bar2", BAR2_R1, "hoa_loi")
	_run(w, 0.45 + 1.5 + 0.05)
	ck("Hỏa Lôi (ignite payload only): hit, boss not moved, cells burning", bool((w["log"] as Array)[0]["hit"])
		and not bool((w["log"] as Array)[0]["pushed"]) and (w["state"] as CombatState).enemy_cell == Vector2i(6, 1)
		and (w["fx"] as StatusEffects).burning_cells().size() == 2)


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(6, 1))
	_cast(a, "bar2", BAR2_R1)
	_run_past_fuse(a)
	var b: Dictionary = _world(Vector2i(6, 1))
	_cast(b, "bar2", BAR2_R1)
	_run_past_fuse(b)
	ck("two identical runs give the same log, HP and boss cell", str(a["log"]) == str(b["log"])
		and is_equal_approx(_lost(a), _lost(b)) and (a["state"] as CombatState).enemy_cell == (b["state"] as CombatState).enemy_cell)

extends SceneTree
## Skill v2 batch 2, Lốc Cuốn (loc_cuon): the M12 `pull_cells` field (CutEffects.pull_toward): a unit inside or
## 4-adjacent to the mask is pulled toward the mask's centre BEFORE the hit is judged, the `square` clause pulls 2
## and Pins 0.4 s, a blocked pull slams (R3), a unit away from the mask is untouched. Direct CutEffects.apply and the
## real arbiter path (resolve waves, one event of every cell).
## Run: godot --headless --path . -s res://tests/unit/combat/cut_effects_pull_test.gd

const ID: String = "loc_cuon"
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
	test_pull_toward_helper()
	test_adjacent_unit_pulled_in_then_hit()
	test_square_clause_pulls_two_and_pins()
	test_far_unit_untouched()
	test_blocked_pull_slams()
	test_real_arbiter()
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
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cells": ev["cells"], "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _apply(w: Dictionary, shape: String, cells: Array[Vector2i], blocked: Callable = Callable()) -> Dictionary:
	return CutEffects.apply(w["state"], w["grid"], CombatState.Side.PLAYER, cells, ID, w["cc"], w["sc"], w["fx"], Callable(), 1,
		Callable(), Callable(), {"cast_context": _ctx(w["sc"], shape, cells), "target_blocked_fn": blocked,
			"reactions": CombatConfig.load_from_file().reactions()})


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


# square at (5,0): centre (5,0); t4 at (4,0): (4,0) (5,0) (6,0) (5,1), centre (5,1) (nearest the hero on the tie)
const SQUARE: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1), Vector2i(6, 1)]
const T4: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared rare card, pull 1, square clause pull 2 + pin 0.4, reaction r3, waves x1, no errors", s["rarity"] == "rare"
		and int(s["pull_cells"]) == 1 and int(s["shape_clause"]["pull_cells"]) == 2 and is_equal_approx(float(s["shape_clause"]["pin_sec"]), 0.4)
		and (s["reactions"] as Array) == ["r3"] and s["resolve"] == "waves" and int(s["hits"]) == 1 and (s["resolve_errors"] as Array).is_empty(),
		str(s))
	ck("min 4, cd 8, dpc 4", int(s["min_cells"]) == 4 and is_equal_approx(float(s["cooldown_sec"]), 8.0) and is_equal_approx(float(s["damage_per_cell"]), 4.0))
	ck("a card without the field pulls nothing", int(sc.get_skill("kiem_khi")["pull_cells"]) == 0)


func test_pull_toward_helper() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	var r: Dictionary = CutEffects.pull_toward(w["state"], w["grid"], CombatState.Side.ENEMY, Vector2i(5, 0), 2)
	ck("(7,2) toward (5,0), 2 steps: the larger offset first each step (tie: the row) -> (6,2) then (6,1)",
		(w["state"] as CombatState).enemy_cell == Vector2i(6, 1) and int(r["steps"]) == 2 and not bool(r["blocked"]), str((w["state"] as CombatState).enemy_cell))
	var w2: Dictionary = _world(Vector2i(5, 0))
	var r2: Dictionary = CutEffects.pull_toward(w2["state"], w2["grid"], CombatState.Side.ENEMY, Vector2i(5, 0), 2)
	ck("already on the centre: no step, not blocked", int(r2["steps"]) == 0 and not bool(r2["blocked"]))
	var w3: Dictionary = _world(Vector2i(7, 0))
	var r3: Dictionary = CutEffects.pull_toward(w3["state"], w3["grid"], CombatState.Side.ENEMY, Vector2i(5, 0), 2,
		func(c: Vector2i) -> bool: return c == Vector2i(6, 0))
	ck("a blocked cell on the way: no step, blocked", int(r3["steps"]) == 0 and bool(r3["blocked"]) and (w3["state"] as CombatState).enemy_cell == Vector2i(7, 0))


func test_adjacent_unit_pulled_in_then_hit() -> void:
	# t4 (no square clause): boss on (6,1), adjacent to (6,0) and (5,1): pulled 1 toward the centre (5,1) -> inside -> hit
	var w: Dictionary = _world(Vector2i(6, 1))
	var r: Dictionary = _apply(w, "t4", T4)
	ck("adjacent boss pulled onto (5,1) and hit: 4 x 4 = 16", bool(r["hit"]) and bool(r.get("pulled", false))
		and (w["state"] as CombatState).enemy_cell == Vector2i(5, 1) and is_equal_approx(float(r["damage"]), 16.0), str(r))
	ck("no clause: not pinned", not (w["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY))


func test_square_clause_pulls_two_and_pins() -> void:
	# square (5..6, 0..1), centre (5,0): boss on (7,1) is adjacent to (6,1): pulled (6,1) then (5,1), inside, hit, pinned 0.4
	var w: Dictionary = _world(Vector2i(7, 1))
	var r: Dictionary = _apply(w, "square", SQUARE)
	ck("square: pulled 2 to (5,1), hit 16, Pinned 0.4 s", bool(r["hit"]) and (w["state"] as CombatState).enemy_cell == Vector2i(5, 1)
		and is_equal_approx(float(r["damage"]), 16.0) and bool(r["pinned"]) and is_equal_approx((w["fx"] as StatusEffects).get_pin_left(CombatState.Side.ENEMY), 0.4),
		str(r))


func test_far_unit_untouched() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	var r: Dictionary = _apply(w, "square", SQUARE)
	ck("boss two cells away (diagonal): no pull, no hit, still (7,2)", not bool(r["hit"]) and not bool(r.get("pulled", false))
		and (w["state"] as CombatState).enemy_cell == Vector2i(7, 2) and is_zero_approx(_lost(w)))


func test_blocked_pull_slams() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	var r: Dictionary = _apply(w, "square", SQUARE, func(c: Vector2i) -> bool: return c == Vector2i(6, 1))
	ck("the first pull step is blocked: R3 slam 8, Pinned 0.6 s, boss still outside (no hit)", r.get("reaction", "") == "r3"
		and is_equal_approx(_lost(w), 8.0) and not bool(r["hit"]) and (w["state"] as CombatState).enemy_cell == Vector2i(7, 1)
		and is_equal_approx((w["fx"] as StatusEffects).get_pin_left(CombatState.Side.ENEMY), 0.6), str(r))


func test_real_arbiter() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	(w["player"] as CutActor).begin_swing(SQUARE, ID, true, 1, -1.0, {}, _ctx(w["sc"], "square", SQUARE))
	var t: float = 0.0
	while t < 3.0:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP
	ck("arbiter: one event of the 4 cells, boss pulled to (5,1), 16 damage", (w["log"] as Array).size() == 1
		and ((w["log"] as Array)[0]["cells"] as Array).size() == 4 and (w["state"] as CombatState).enemy_cell == Vector2i(5, 1)
		and is_equal_approx(_lost(w), 16.0), "%.1f %s" % [_lost(w), str(w["log"])])


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(6, 1))
	_apply(a, "t4", T4)
	var b: Dictionary = _world(Vector2i(6, 1))
	_apply(b, "t4", T4)
	ck("two identical applies: same HP and cell", is_equal_approx(_lost(a), _lost(b)) and (a["state"] as CombatState).enemy_cell == (b["state"] as CombatState).enemy_cell)

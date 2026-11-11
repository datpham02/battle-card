extends SceneTree
## Skill v2 batch 2, Hồi Âm (hoi_am) and the M14 `echo` of a `waves` card: after the last wave an echo wave repeats
## the cast at x mult, delay_sec later, shifted `shift` cells toward the target half's back edge when every shifted
## cell is allowed (else in place), the `square` clause gives two echoes, the boss's cast shifts the other way, the
## echo hits a unit that stayed (max_hits grows by the echo count), and determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_echo_test.gd

const ID: String = "hoi_am"
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
	test_data_and_validation()
	test_echo_shifted_toward_the_back_edge()
	test_echo_in_place_when_the_shift_leaves_the_half()
	test_square_clause_two_echoes()
	test_boss_cast_shifts_the_other_way()
	test_echo_hits_a_unit_that_stayed()
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
		log.append({"cells": ev["cells"], "kind": ev["kind"], "mult": ev["mult"], "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const ENEMY_HALF: Array = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1),
	Vector2i(7, 1), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)]
const BAR3: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
const BAR3_FAR: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const SQUARE: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)]


func test_data_and_validation() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared epic waves card: 1 hit, echo 1 x0.6 after 0.6 s shifted 1, square clause 2 echoes, no errors", s["rarity"] == "epic"
		and s["resolve"] == "waves" and int(s["hits"]) == 1 and int(s["echo"]["count"]) == 1 and is_equal_approx(float(s["echo"]["mult"]), 0.6)
		and is_equal_approx(float(s["echo"]["delay_sec"]), 0.6) and int(s["echo"]["shift"]) == 1 and int(s["shape_clause"]["echo_count"]) == 2
		and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("min 3, cd 9, dpc 5", int(s["min_cells"]) == 3 and is_equal_approx(float(s["cooldown_sec"]), 9.0) and is_equal_approx(float(s["damage_per_cell"]), 5.0))
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "arrival", "echo": {"count": 1}}, "damage")
	ck("echo needs resolve waves", not (bad["errors"] as Array).is_empty())
	var bad2: Dictionary = CastResolver.validate("x", {"resolve": "waves", "echo": {"count": 5}}, "damage")
	ck("echo count above 2 is rejected", not (bad2["errors"] as Array).is_empty())
	ck("every other waves card has no echo", (sc.get_skill("song_dao")["echo"] as Dictionary).is_empty())


func test_echo_shifted_toward_the_back_edge() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR3, _ctx(sc, "bar3", BAR3), SkillDelivery.DEFAULT_TIMING, [], [], ENEMY_HALF)
	var ev: Array = plan["events"]
	ck("wave 0 at 0 on the mask, wave 1 echo at 0.6 x0.6 on the mask shifted +1 (5..7,1); max_hits 2", ev.size() == 2
		and int(ev[0]["wave"]) == 0 and is_zero_approx(float(ev[0]["t"])) and ev[1]["kind"] == "echo" and int(ev[1]["wave"]) == 1
		and is_equal_approx(float(ev[1]["t"]), 0.6) and is_equal_approx(float(ev[1]["mult"]), 0.6) and (ev[1]["cells"] as Array) == BAR3_FAR
		and bool(ev[1]["shifted"]) and int(plan["max_hits"]) == 2 and int(plan["echo_count"]) == 1, str(ev))


func test_echo_in_place_when_the_shift_leaves_the_half() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR3_FAR, _ctx(sc, "bar3", BAR3_FAR), SkillDelivery.DEFAULT_TIMING, [], [], ENEMY_HALF)
	var ev: Array = plan["events"]
	ck("(5..7,1) cannot shift past the edge: the echo lands in place", ev.size() == 2 and (ev[1]["cells"] as Array) == BAR3_FAR and not bool(ev[1]["shifted"]), str(ev))


func test_square_clause_two_echoes() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), SQUARE, _ctx(sc, "square", SQUARE), SkillDelivery.DEFAULT_TIMING, [], [], ENEMY_HALF)
	var ev: Array = plan["events"]
	ck("square: two echoes at 0.6 and 1.2, shifted +1 and +2, waves 1 and 2, max_hits 3", ev.size() == 3
		and is_equal_approx(float(ev[1]["t"]), 0.6) and is_equal_approx(float(ev[2]["t"]), 1.2) and int(ev[2]["wave"]) == 2
		and (ev[1]["cells"] as Array)[0] == Vector2i(5, 0) and (ev[2]["cells"] as Array)[0] == Vector2i(6, 0) and int(plan["max_hits"]) == 3, str(ev))


func test_boss_cast_shifts_the_other_way() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var player_half: Array = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	var mask: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1)]
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), mask, {"side": CombatState.Side.ENEMY}, SkillDelivery.DEFAULT_TIMING, [], [], player_half)
	ck("the boss's echo shifts -x (toward the player's back edge): (1,1) (2,1)", ((plan["events"] as Array)[1]["cells"] as Array) == [Vector2i(1, 1), Vector2i(2, 1)],
		str(plan["events"]))


func test_echo_hits_a_unit_that_stayed() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	(w["player"] as CutActor).begin_swing(BAR3, ID, true, 1, -1.0, {}, _ctx(w["sc"], "bar3", BAR3))
	var t: float = 0.0
	while t < 3.0:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP
	var hits: int = 0
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			hits += 1
	ck("hit 15 now and 9 by the echo 0.6 s later: 24, two hits", hits == 2 and is_equal_approx(_lost(w), 24.0)
		and absf(float((w["log"] as Array)[1]["at"]) - float((w["log"] as Array)[0]["at"]) - 0.6) < 0.011, "%.1f %s" % [_lost(w), str(w["log"])])
	var w2: Dictionary = _world(Vector2i(4, 1))
	(w2["player"] as CutActor).begin_swing(BAR3, ID, true, 1, -1.0, {}, _ctx(w2["sc"], "bar3", BAR3))
	t = 0.0
	while t < 3.0:
		(w2["arb"] as SwingArbiter).tick(STEP)
		t += STEP
	ck("boss on the near cell: the shifted echo misses it: 15 only", is_equal_approx(_lost(w2), 15.0), "%.1f" % _lost(w2))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(6, 1))
	(a["player"] as CutActor).begin_swing(BAR3, ID, true, 1, -1.0, {}, _ctx(a["sc"], "bar3", BAR3))
	var b: Dictionary = _world(Vector2i(6, 1))
	(b["player"] as CutActor).begin_swing(BAR3, ID, true, 1, -1.0, {}, _ctx(b["sc"], "bar3", BAR3))
	var t: float = 0.0
	while t < 3.0:
		(a["arb"] as SwingArbiter).tick(STEP)
		(b["arb"] as SwingArbiter).tick(STEP)
		t += STEP
	ck("two identical runs: same log and HP (24)", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), 24.0) and is_equal_approx(_lost(a), _lost(b)))

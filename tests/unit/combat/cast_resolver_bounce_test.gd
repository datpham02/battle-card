extends SceneTree
## Skill v2 batch 4, Phi Tiêu Liên Hoàn (phi_tieu): a chain of daggers from the caster 0.08 s apart (card
## link_step_sec), M06 `bounce` (a dagger whose cell is empty re-targets the mask cell the unit moved to), the 2-hit
## cap, and the L clause (the corner's dagger flies first and lands Rạn before the rest). Plan and the real arbiter.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_bounce_test.gd

const ID: String = "phi_tieu"
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
	test_data_and_plan()
	test_bounce_finds_the_unit()
	test_leaving_the_mask_escapes()
	test_two_hit_cap()
	test_l_clause_corner_first_with_ran()
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
		log.append({"cell": (ev["cells"] as Array)[0], "from": ev.get("bounced_from", Vector2i(-9, -9)), "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _begin(w: Dictionary, shape: String, cells: Array[Vector2i]) -> float:
	(w["player"] as CutActor).begin_swing(cells, ID, true, 1, -1.0, {}, _ctx(w["sc"], shape, cells))
	return (w["player"] as CutActor).get_duration()


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _hits(w: Dictionary) -> int:
	var n: int = 0
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			n += 1
	return n


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR2: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1)]
# l4 at (5,0): (5,0) (5,1) (5,2) (6,2); the corner is (5,2)
const L4: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(6, 2)]


func test_data_and_plan() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("Assassin rare: chain from the caster, 0.08 s per dagger, 2 hits, bounce, L clause corner_first + 1 Rạn, no errors",
		sc.hero_of(ID) == "sat_thu" and s["resolve"] == "arrival" and s["delivery"]["type"] == SkillDelivery.SEQUENTIAL_CHAIN
		and is_equal_approx(float(s["link_step_sec"]), 0.08) and int(s["max_hits"]) == 2 and bool(s["bounce"])
		and bool(s["shape_clause"]["corner_first"]) and int(s["shape_clause"]["fragile_stacks"]) == 1 and (s["resolve_errors"] as Array).is_empty(),
		str(s["resolve_errors"]))
	var plan: Dictionary = CastResolver.plan(s, BAR2, _ctx(sc, "bar2", BAR2))
	var ev: Array = plan["events"]
	ck("bar2: daggers at 0 and 0.08 s, nearest first, each may bounce", ev.size() == 2 and (ev[0]["cells"] as Array)[0] == Vector2i(5, 1)
		and is_equal_approx(float(ev[1]["t"]), 0.08) and bool(ev[1]["bounce"]), str(ev))
	var plan2: Dictionary = CastResolver.plan(s, L4, _ctx(sc, "l4", L4))
	ck("l4: the corner (5,2) flies first", ((plan2["events"] as Array)[0]["cells"] as Array)[0] == Vector2i(5, 2), str(plan2["events"]))
	ck("corner_cell: an L finds its corner, a bar has none", CastResolver.corner_cell(L4) == Vector2i(5, 2) and CastResolver.corner_cell(BAR2) == CastResolver.NO_CELL)
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "waves", "bounce": true}, "damage")
	ck("bounce needs resolve arrival", not (bad["errors"] as Array).is_empty())


func test_bounce_finds_the_unit() -> void:
	# the boss on (6,1): the first dagger (5,1) finds its cell empty and bounces to (6,1); the second hits (6,1) too
	var w: Dictionary = _world(Vector2i(6, 1))
	var d: float = _begin(w, "bar2", BAR2)
	_run(w, d + 0.5)
	var log: Array = w["log"]
	ck("dagger 1 bounced from (5,1) to (6,1) and hit; dagger 2 hit: 2 hits, 5 x 2 x 2 = 20", log.size() == 2 and log[0]["from"] == Vector2i(5, 1)
		and log[0]["cell"] == Vector2i(6, 1) and bool(log[0]["hit"]) and bool(log[1]["hit"]) and is_equal_approx(_lost(w), 20.0), str(log))


func test_leaving_the_mask_escapes() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var d: float = _begin(w, "bar2", BAR2)
	_run(w, d + 0.03)
	ck("the first dagger hit (5,1): 10", is_equal_approx(_lost(w), 10.0), "%.1f" % _lost(w))
	(w["state"] as CombatState).set_enemy_cell(Vector2i(7, 1))  # out of the mask before dagger 2
	_run(w, 0.3)
	ck("the boss left the mask: dagger 2 finds nothing to bounce to: still 10", is_equal_approx(_lost(w), 10.0) and _hits(w) == 1, str(w["log"]))


func test_two_hit_cap() -> void:
	# 4 daggers, the boss sitting on (6,2) of an L: every dagger bounces onto it, only 2 may hit
	var w: Dictionary = _world(Vector2i(6, 2))
	var d: float = _begin(w, "l4", L4)
	_run(w, d + 0.6)
	ck("l4 with the boss on (6,2): 2 hits of 4 daggers (20, then 30 with the corner's Rạn), the last two find nothing to add",
		_hits(w) == 2 and is_equal_approx(_lost(w), 50.0), "%.1f %s" % [_lost(w), str(w["log"])])


func test_l_clause_corner_first_with_ran() -> void:
	# the boss on the corner (5,2): the corner dagger hits first (20) and lands Rạn; the next bounces back x1.5 (30)
	var w: Dictionary = _world(Vector2i(5, 2))
	var d: float = _begin(w, "l4", L4)
	_run(w, d + 0.6)
	var log: Array = w["log"]
	ck("corner first: 20 then 30 (Rạn), 2 hits, 50", log[0]["cell"] == Vector2i(5, 2) and is_equal_approx(float(log[0]["dmg"]), 20.0)
		and is_equal_approx(float(log[1]["dmg"]), 30.0) and is_equal_approx(_lost(w), 50.0) and _hits(w) == 2, str(log))
	var w2: Dictionary = _world(Vector2i(5, 1))
	var d2: float = _begin(w2, "bar2", BAR2)
	_run(w2, d2 + 0.5)
	ck("bar2 (no L): no Rạn, 10 + 10", is_equal_approx(_lost(w2), 20.0) and (w2["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 0)


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(6, 2))
	_run(a, _begin(a, "l4", L4) + 0.6)
	var b: Dictionary = _world(Vector2i(6, 2))
	_run(b, _begin(b, "l4", L4) + 0.6)
	ck("two identical runs: same log and HP", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), _lost(b)))

extends SceneTree
## Skill v2 batch 4, Chuông Thánh (chuong_thanh): the M14 echo waves of batch 2 ringing in place: hit now, two echoes
## at 0.6 s intervals at 50 % (the square clause three), each wave that hits adds +1 Hàn (three Hàn burst), and an echo
## wave neither consumes nor receives Rạn (02-design-decisions.md §7). Plan and the real arbiter path.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_echo_waves_test.gd

const ID: String = "chuong_thanh"
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
	test_plan_two_echoes_in_place_square_three()
	test_three_waves_hit_and_han_bursts()
	test_echo_waves_ignore_ran()
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
		log.append({"kind": ev["kind"], "mult": float(ev["mult"]), "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, shape: String, cells: Array[Vector2i], sec: float = 2.5) -> void:
	(w["player"] as CutActor).begin_swing(cells, ID, true, 1, -1.0, {}, _ctx(w["sc"], shape, cells))
	var until: float = (w["player"] as CutActor).get_duration() + sec
	var t: float = 0.0
	while t < until:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR3: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
const SQUARE: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("Cleric rare: waves x1, echo 2 x0.5 every 0.6 s in place, +1 Hàn, square clause 3 echoes, no errors", sc.hero_of(ID) == "giao_si"
		and s["resolve"] == "waves" and int(s["echo"]["count"]) == 2 and is_equal_approx(float(s["echo"]["mult"]), 0.5) and int(s["echo"]["shift"]) == 0
		and int(s["frost_stacks"]) == 1 and int(s["shape_clause"]["echo_count"]) == 3 and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "waves", "echo": {"count": 4}}, "damage")
	ck("echo count above 3 is rejected", not (bad["errors"] as Array).is_empty())


func test_plan_two_echoes_in_place_square_three() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR3, _ctx(sc, "bar3", BAR3))
	var ev: Array = plan["events"]
	ck("bar3: wave 0 at 0, echoes at 0.6 and 1.2 x0.5 on the same cells, max_hits 3", ev.size() == 3 and is_equal_approx(float(ev[1]["t"]), 0.6)
		and is_equal_approx(float(ev[2]["t"]), 1.2) and (ev[2]["cells"] as Array) == BAR3 and is_equal_approx(float(ev[2]["mult"]), 0.5)
		and int(plan["max_hits"]) == 3, str(ev))
	var plan2: Dictionary = CastResolver.plan(sc.get_skill(ID), SQUARE, _ctx(sc, "square", SQUARE))
	ck("square: three echoes (4 waves), max_hits 4", (plan2["events"] as Array).size() == 4 and int(plan2["max_hits"]) == 4)


func test_three_waves_hit_and_han_bursts() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var cc: CombatConfig = CombatConfig.load_from_file()
	_cast(w, "bar3", BAR3)
	var hits: int = 0
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			hits += 1
	var want: float = 12.0 + 6.0 + 6.0 + (cc.frost_burst_damage if cc.frost_stacks_to_burst == 3 else 0.0)
	ck("the boss that stays is hit 3 times (12 + 6 + 6) and the third Hàn bursts (+%.0f)" % cc.frost_burst_damage, hits == 3
		and is_equal_approx(_lost(w), want) and (w["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY) == 0, "%.1f %s" % [_lost(w), str(w["log"])])


func test_echo_waves_ignore_ran() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	(w["fx"] as StatusEffects).apply_fragile(CombatState.Side.ENEMY, 2)
	_cast(w, "bar3", BAR3)
	var log: Array = w["log"]
	ck("Rạn 2: the first hit spends one (18), the echoes neither spend nor gain (6, 6), one stack left",
		is_equal_approx(float(log[0]["dmg"]), 18.0) and is_equal_approx(float(log[1]["dmg"]), 6.0) and is_equal_approx(float(log[2]["dmg"]), 6.0)
		and (w["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 1, str(log))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 1))
	_cast(a, "square", SQUARE)
	var b: Dictionary = _world(Vector2i(5, 1))
	_cast(b, "square", SQUARE)
	ck("two identical runs: same log and HP", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), _lost(b)))

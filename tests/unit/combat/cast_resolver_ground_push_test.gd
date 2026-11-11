extends SceneTree
## Skill v2 batch 2, Địa Chấn (dia_chan): a `push` card on the GROUND_PROPAGATION `arrival` path (M04): the run starts on
## the mask cell nearest the hero, never crosses a locked cell (a hole stops it), the hit pushes 1 (the `line` clause 2),
## and a push stopped short slams the target (R3 Va Đập, card-listed: combat.json reactions.r3). Real path: cards.json,
## CastContext from real pieces, CutActor, SwingArbiter clock, CutEffects, StatusEffects.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_ground_push_test.gd

const ID: String = "dia_chan"
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
	test_ground_run_from_the_hero()
	test_hole_stops_the_run()
	test_hit_pushes_one()
	test_line_clause_pushes_two()
	test_blocked_push_slams()
	test_other_push_cards_slam_too()
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
		log.append({"cell": (ev["cells"] as Array)[0], "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	var done: Array = []
	arb.swing_resolved.connect(func(_side: int, r: Dictionary) -> void: done.append(r))
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log, "done": done}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i], skill_id: String = ID) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(skill_id, 1, pieces, [cells], sc.get_skill(skill_id)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, shape: String, cells: Array[Vector2i], skill_id: String = ID) -> void:
	(w["player"] as CutActor).begin_swing(cells, skill_id, true, 1, -1.0, {}, _ctx(w["sc"], shape, cells, skill_id))
	var t: float = 0.0
	var until: float = (w["player"] as CutActor).get_duration() + 1.5
	while t < until:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR3: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
const BAR3_FAR: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const L3: Array[Vector2i] = [Vector2i(4, 0), Vector2i(4, 1), Vector2i(5, 1)]


func test_data_and_validation() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared common push card, in the pool, boss-playable", s["rarity"] == "common" and s["effect"] == "push" and sc.is_pool_card(ID)
		and sc.is_boss_playable(ID))
	ck("resolve arrival on GROUND_PROPAGATION, push 1, line clause push 2, reaction r3, no errors", s["resolve"] == "arrival"
		and s["delivery"]["type"] == SkillDelivery.GROUND_PROPAGATION and int(s["push_cells"]) == 1
		and int(s["shape_clause"]["push_cells"]) == 2 and (s["reactions"] as Array) == ["r3"] and (s["resolve_errors"] as Array).is_empty(),
		str(s["resolve_errors"]))
	ck("min 3, cd 6, dpc 5", int(s["min_cells"]) == 3 and is_equal_approx(float(s["cooldown_sec"]), 6.0) and is_equal_approx(float(s["damage_per_cell"]), 5.0))
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "arrival"}, "burn")
	ck("a burn card still cannot schedule (push is the only new scheduled effect)", not (bad["errors"] as Array).is_empty())
	var cfg: SkillConfig = SkillConfig.from_dictionary({"cards": {"x": {"reactions": ["r3", "r9"]}}})
	ck("an unknown reaction id is dropped (warning), the known one kept", (cfg.get_skill("x")["reactions"] as Array) == ["r3"])
	ck("combat.json reactions: r3 8 damage, 0.6 s Pin", is_equal_approx(CombatConfig.load_from_file().r3_damage, 8.0)
		and is_equal_approx(CombatConfig.load_from_file().r3_pin_sec, 0.6))


func test_ground_run_from_the_hero() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR3, _ctx(sc, "bar3", BAR3))
	var ev: Array = plan["events"]
	var ok: bool = ev.size() == 3 and not bool(plan["legacy"])
	for i: int in ev.size():
		ok = ok and (ev[i]["cells"] as Array)[0] == BAR3[i] and is_equal_approx(float(ev[i]["t"]), 0.12 * float(3 + i)) and int(ev[i]["wave"]) == 0
	ck("bar3: three events from the cell nearest the hero outward, 0.12 s apart (origin distance 3), one wave", ok, str(ev))


func test_hole_stops_the_run() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR3, _ctx(sc, "bar3", BAR3), SkillDelivery.DEFAULT_TIMING, [Vector2i(5, 1)])
	var ev: Array = plan["events"]
	ck("a hole on the middle cell: only the near cell resolves, the far cell is never reached", ev.size() == 1
		and (ev[0]["cells"] as Array)[0] == Vector2i(4, 1), str(ev))
	var plan2: Dictionary = CastResolver.plan(sc.get_skill(ID), L3, _ctx(sc, "l3", L3), SkillDelivery.DEFAULT_TIMING, [Vector2i(4, 1)])
	ck("L: the corner locked splits the mask; the cell cut off gets no event", (plan2["events"] as Array).size() == 1, str(plan2["events"]))


func test_hit_pushes_one() -> void:
	# l3 (no line tag): the card's own push 1
	var w: Dictionary = _world(Vector2i(4, 1))
	_cast(w, "l3", L3)
	ck("boss on an L cell: hit once, 5 x 3 = 15, pushed 1 to (5,1), no slam", is_equal_approx(_lost(w), 15.0)
		and (w["state"] as CombatState).enemy_cell == Vector2i(5, 1) and (w["done"] as Array).size() == 1
		and str((w["done"] as Array)[0].get("reaction", "")).is_empty(),
		"%.1f %s %s" % [_lost(w), str((w["state"] as CombatState).enemy_cell), str(w["done"])])
	var hits: int = 0
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			hits += 1
	ck("one hit per cast", hits == 1)


func test_line_clause_pushes_two() -> void:
	var w: Dictionary = _world(Vector2i(4, 1))
	_cast(w, "bar3", BAR3)
	ck("bar3 is a line: pushed 2 to (6,1)", (w["state"] as CombatState).enemy_cell == Vector2i(6, 1) and is_equal_approx(_lost(w), 15.0),
		str((w["state"] as CombatState).enemy_cell))
	var w2: Dictionary = _world(Vector2i(4, 1))
	_cast(w2, "l3", L3)
	ck("L (no line tag): pushed 1 to (5,1)", (w2["state"] as CombatState).enemy_cell == Vector2i(5, 1), str((w2["state"] as CombatState).enemy_cell))


func test_blocked_push_slams() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	_cast(w, "bar3", BAR3_FAR)
	var r: Dictionary = (w["done"] as Array)[0] if not (w["done"] as Array).is_empty() else {}
	ck("boss on the half's edge: the push is blocked -> R3: 15 + 8 = 23, Pinned (0.6 s, over by now), reaction r3", is_equal_approx(_lost(w), 23.0)
		and r.get("reaction", "") == "r3" and bool(r.get("pinned", false)) and is_equal_approx(float(r.get("reaction_damage", 0.0)), 8.0)
		and (w["state"] as CombatState).enemy_cell == Vector2i(7, 1), "%.1f %s" % [_lost(w), str(r)])
	# the line clause asks for 2 cells: one step then the edge is also a slam
	var w2: Dictionary = _world(Vector2i(6, 1))
	_cast(w2, "bar3", BAR3_FAR)
	ck("line push 2 with one cell of room: moved 1 then slammed (23)", is_equal_approx(_lost(w2), 23.0)
		and (w2["state"] as CombatState).enemy_cell == Vector2i(7, 1), "%.1f" % _lost(w2))


func test_other_push_cards_slam_too() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	(w["player"] as CutActor).begin_swing(BAR3_FAR, "chan_phong", true, 1, -1.0, {}, {})
	var t: float = 0.0
	while t < 3.0:
		(w["arb"] as SwingArbiter).tick(STEP)
		t += STEP
	# batch 5 (Deferred 2): reactions are GLOBAL: a push stopped short slams for every card, not only the ones that list r3
	ck("chan_phong at the edge: 4 x 3 = 12 + the global R3 slam 8 = 20, Pinned", is_equal_approx(_lost(w), 20.0)
		and (w["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY), "%.1f" % _lost(w))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(6, 1))
	_cast(a, "bar3", BAR3_FAR)
	var b: Dictionary = _world(Vector2i(6, 1))
	_cast(b, "bar3", BAR3_FAR)
	ck("two identical runs give the same log, HP and boss cell", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), _lost(b))
		and (a["state"] as CombatState).enemy_cell == (b["state"] as CombatState).enemy_cell)

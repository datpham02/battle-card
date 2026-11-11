extends SceneTree
## Skill v2 batch 1, Chuỗi Sét (chuoi_set): the M06 chain ramp `link_ramp` / `link_ramp_cap` of a SEQUENTIAL_CHAIN
## `arrival` card and the `S` clause `link_step_sec`, through CastResolver.plan and the REAL arbiter path: data and
## validation, link multipliers 1 + min(k x ramp, cap) in chain order, the cap, the default (no ramp = every link x1,
## existing chain cards untouched), the S clause re-timing, one hit per cast at the link that finds the target, and
## determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_link_ramp_test.gd

const ID: String = "chuoi_set"
const HERO := Vector2i(1, 1)
const STEP: float = 0.01

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data_and_validation()
	test_link_multipliers_in_chain_order()
	test_ramp_cap()
	test_no_ramp_keeps_every_link_at_one()
	test_s_clause_retimes_links()
	test_hit_at_the_link_that_finds_the_target()
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
		log.append({"cell": (ev["cells"] as Array)[0], "mult": ev["mult"], "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, shape: String, cells: Array[Vector2i]) -> bool:
	return (w["player"] as CutActor).begin_swing(cells, ID, true, 1, -1.0, {}, _ctx(w["sc"], shape, cells))


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
# s4 at anchor (4,0): (5,0) (6,0) (4,1) (5,1)
const S4: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(4, 1), Vector2i(5, 1)]


func test_data_and_validation() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared rare chain card, implemented, in the pool", sc.hero_of(ID).is_empty() and s["rarity"] == "rare"
		and bool(s["implemented"]) and sc.is_pool_card(ID) and sc.card_order.has(ID))
	ck("resolve arrival on a SEQUENTIAL_CHAIN delivery, max 1 hit, no resolve errors", s["resolve"] == "arrival"
		and s["delivery"]["type"] == SkillDelivery.SEQUENTIAL_CHAIN and int(s["max_hits"]) == 1 and (s["resolve_errors"] as Array).is_empty(),
		str(s["resolve_errors"]))
	ck("link_ramp 0.15, cap 0.6; S clause link_step_sec 0.06", is_equal_approx(float(s["link_ramp"]), 0.15)
		and is_equal_approx(float(s["link_ramp_cap"]), 0.6) and s["shape_clause"]["tag"] == "S"
		and is_equal_approx(float(s["shape_clause"]["link_step_sec"]), 0.06))
	ck("min 4 cells, cd 7, dpc 5", int(s["min_cells"]) == 4 and is_equal_approx(float(s["cooldown_sec"]), 7.0)
		and is_equal_approx(float(s["damage_per_cell"]), 5.0))
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "instant", "link_ramp": 0.15}, "damage")
	ck("link_ramp on an instant card is rejected", bad["resolve"] == "instant" and not (bad["errors"] as Array).is_empty())
	var bad2: Dictionary = CastResolver.validate("x", {"resolve": "arrival", "link_ramp": 2.0}, "damage")
	ck("link_ramp above 1 is rejected", not (bad2["errors"] as Array).is_empty())
	var bad3: Dictionary = CastResolver.validate("x", {"resolve": "waves", "hits": 2, "shape_clause": {"tag": "S", "link_step_sec": 0.06}}, "damage")
	ck("a link_step_sec clause needs resolve arrival", not (bad3["errors"] as Array).is_empty())
	var ok: Dictionary = CastResolver.validate("x", {"resolve": "arrival"}, "damage")
	ck("defaults: ramp 0, cap 0.6", (ok["errors"] as Array).is_empty() and is_zero_approx(float(ok["link_ramp"]))
		and is_equal_approx(float(ok["link_ramp_cap"]), 0.6))


func test_link_multipliers_in_chain_order() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR4, _ctx(sc, "bar4", BAR4))
	var ev: Array = plan["events"]
	var ok: bool = ev.size() == 4 and not bool(plan["legacy"])
	var want_mult: Array[float] = [1.0, 1.15, 1.3, 1.45]
	for i: int in 4:
		ok = ok and (ev[i]["cells"] as Array)[0] == BAR4[i] and is_equal_approx(float(ev[i]["mult"]), want_mult[i]) \
			and is_equal_approx(float(ev[i]["t"]), 0.1 * float(i)) and int(ev[i]["wave"]) == 0 and int(ev[i]["step"]) == i
	ck("bar4 from the hero: links (4,1)..(7,1) x1 / x1.15 / x1.3 / x1.45 at 0 / 0.1 / 0.2 / 0.3 s, one wave", ok, str(ev))
	ck("the plan's max_hits is 1 (hit at the link that finds the unit)", int(plan["max_hits"]) == 1)


func test_ramp_cap() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var six: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(7, 1), Vector2i(7, 2)]
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), six, {"caster_cell": HERO})
	var ev: Array = plan["events"]
	ck("6 links: the 5th and 6th stop at +60 % (x1.6)", ev.size() == 6 and is_equal_approx(float(ev[4]["mult"]), 1.6)
		and is_equal_approx(float(ev[5]["mult"]), 1.6) and is_equal_approx(float(ev[3]["mult"]), 1.45), str(ev))


func test_no_ramp_keeps_every_link_at_one() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	# an existing chain card (bang_chau) stays on its legacy instant path
	var legacy: Dictionary = CastResolver.plan(sc.get_skill("bang_chau"), BAR4, {})
	ck("bang_chau (chain, no ramp) is still legacy: one instant event x1", bool(legacy["legacy"])
		and (legacy["events"] as Array).size() == 1 and is_equal_approx(float((legacy["events"] as Array)[0]["mult"]), 1.0))
	# a scheduled chain without link_ramp: every link x1 (the ramp defaults to 0)
	var raw: Dictionary = {"resolve": "arrival", "effect": "damage", "delivery": {"type": "SEQUENTIAL_CHAIN", "origin": "first_cell",
		"travel": "chain_spark", "impact": "burst", "chain_order": "nearest_first"}}
	var normal: SkillConfig = SkillConfig.from_dictionary({"cards": {"chain_x": raw}})
	var plan: Dictionary = CastResolver.plan(normal.get_skill("chain_x"), BAR4, {"caster_cell": HERO})
	var all_one: bool = (plan["events"] as Array).size() == 4
	for e: Dictionary in plan["events"]:
		all_one = all_one and is_equal_approx(float(e["mult"]), 1.0)
	ck("an arrival chain without link_ramp: every link x1", all_one, str(plan["events"]))


func test_s_clause_retimes_links() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), S4, _ctx(sc, "s4", S4))
	var ev: Array = plan["events"]
	var ok: bool = ev.size() == 4
	for i: int in ev.size():
		ok = ok and is_equal_approx(float(ev[i]["t"]), 0.06 * float(i))
	ck("s4: links every 0.06 s (clause holds), ramp unchanged", ok and is_equal_approx(float(ev[3]["mult"]), 1.45), str(ev))
	var plan2: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR4, _ctx(sc, "bar4", BAR4))
	ck("bar4: no clause, links every 0.1 s", is_equal_approx(float((plan2["events"] as Array)[1]["t"]), 0.1))


func test_hit_at_the_link_that_finds_the_target() -> void:
	# boss on the 3rd link (6,1): hit once at link index 2 -> 5 x 4 x 1.3 = 26
	var w: Dictionary = _world(Vector2i(6, 1))
	_cast(w, "bar4", BAR4)
	_run(w, (w["player"] as CutActor).get_duration() + 0.5)
	var hits: int = 0
	var hit_cell: Vector2i = Vector2i(-1, -1)
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			hits += 1
			hit_cell = e["cell"]
	ck("4 links fired, exactly one hit, at (6,1)", (w["log"] as Array).size() == 4 and hits == 1 and hit_cell == Vector2i(6, 1),
		str(w["log"]))
	ck("damage 5 x 4 cells x 1.3 = 26", is_equal_approx(_lost(w), 26.0), "%.2f" % _lost(w))
	# boss on the first link: x1 -> 20
	var w2: Dictionary = _world(Vector2i(4, 1))
	_cast(w2, "bar4", BAR4)
	_run(w2, (w2["player"] as CutActor).get_duration() + 0.5)
	ck("first link: x1 -> 20", is_equal_approx(_lost(w2), 20.0), "%.2f" % _lost(w2))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(7, 1))
	_cast(a, "bar4", BAR4)
	_run(a, 2.0)
	var b: Dictionary = _world(Vector2i(7, 1))
	_cast(b, "bar4", BAR4)
	_run(b, 2.0)
	ck("two identical runs give the same log and HP (last link x1.45 -> 29)", str(a["log"]) == str(b["log"])
		and is_equal_approx(_lost(a), 29.0) and is_equal_approx(_lost(a), _lost(b)), "%.2f" % _lost(a))

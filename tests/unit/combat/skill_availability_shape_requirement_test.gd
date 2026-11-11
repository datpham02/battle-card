extends SceneTree
## Skill v2 batch 1, Thương Xuyên (thuong_xuyen): the `requires_shape` menu rule (SkillAvailability reason need_shape,
## context CTX_PIECE_TAGS built by SkillAvailability.piece_tags_of from a CastPlan), the `dpc_bonus` per-cell damage
## bonus (CutEffects.dpc_bonus, the rule the sim shares) and the pierce order: a CASTER_TO_TARGET `arrival` cast
## resolves cell by cell from the caster outward (the surge order) and hits once at the cell that finds the target.
## Run: godot --headless --path . -s res://tests/unit/combat/skill_availability_shape_requirement_test.gd

const ID: String = "thuong_xuyen"
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
	test_menu_rule_need_shape()
	test_piece_tags_of_cast_plan()
	test_dpc_bonus_rule()
	test_pierce_order_and_one_hit()
	test_other_cards_ignore_the_rule()
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
		log.append({"cell": (ev["cells"] as Array)[0], "kind": ev["kind"], "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const BAR2: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared common line-payoff card, implemented, in the pool", sc.hero_of(ID).is_empty() and s["rarity"] == "common"
		and bool(s["implemented"]) and sc.is_pool_card(ID) and sc.card_order.has(ID))
	ck("requires a line piece (any_piece); dpc_bonus +1 per cell beyond 2, cap +3", s["requires_shape"]["tag"] == "line"
		and s["requires_shape"]["scope"] == "any_piece" and is_equal_approx(float(s["dpc_bonus"]["per_cell"]), 1.0)
		and int(s["dpc_bonus"]["from_cells"]) == 2 and is_equal_approx(float(s["dpc_bonus"]["cap"]), 3.0))
	ck("min 2, cd 4, dpc 5, CASTER_TO_TARGET arrival, 1 hit, no resolve errors", int(s["min_cells"]) == 2
		and is_equal_approx(float(s["cooldown_sec"]), 4.0) and is_equal_approx(float(s["damage_per_cell"]), 5.0)
		and s["resolve"] == "arrival" and s["delivery"]["type"] == SkillDelivery.CASTER_TO_TARGET and int(s["max_hits"]) == 1
		and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("a card without the field has no requirement / bonus", (sc.get_skill("kiem_khi")["requires_shape"] as Dictionary).is_empty()
		and (sc.get_skill("kiem_khi")["dpc_bonus"] as Dictionary).is_empty())
	var bad: SkillConfig = SkillConfig.from_dictionary({"cards": {"x": {"requires_shape": {"scope": "any_piece"}, "dpc_bonus": 3}}})
	ck("a requires_shape without tag / a non-object dpc_bonus are dropped (warning), never a crash",
		(bad.get_skill("x")["requires_shape"] as Dictionary).is_empty() and (bad.get_skill("x")["dpc_bonus"] as Dictionary).is_empty())


func test_menu_rule_need_shape() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cd := SkillCooldowns.new()
	var square_only: Dictionary = {SkillAvailability.CTX_PIECE_TAGS: [["square", "compact"]]}
	var r: Dictionary = SkillAvailability.check(sc, cd, ID, 4, 1, square_only)
	ck("only a square placed: unavailable, reason need_shape", not bool(r["available"]) and r["reason"] == "need_shape", str(r))
	var with_line: Dictionary = {SkillAvailability.CTX_PIECE_TAGS: [["square", "compact"], ["line", "line_h", "domino"]]}
	ck("a square and a bar2: available", bool(SkillAvailability.check(sc, cd, ID, 6, 1, with_line)["available"]))
	ck("no piece tags in the context: the rule is not checked (available)", bool(SkillAvailability.check(sc, cd, ID, 4, 1, {})["available"]))
	ck("cells before shape: 1 cell with a line piece -> need_cells first",
		SkillAvailability.check(sc, cd, ID, 1, 1, with_line)["reason"] == "need_cells")
	ck("no pieces at all: need_shape", SkillAvailability.check(sc, cd, ID, 4, 1, {SkillAvailability.CTX_PIECE_TAGS: []})["reason"] == "need_shape")
	ck("shape_satisfied all_pieces: every piece must carry the tag",
		SkillAvailability.shape_satisfied({"tag": "line", "scope": "all_pieces"}, [["line"], ["line", "line_v"]])
		and not SkillAvailability.shape_satisfied({"tag": "line", "scope": "all_pieces"}, [["line"], ["square"]]))


func test_piece_tags_of_cast_plan() -> void:
	var plan: CastPlan = CastPlan.new().init(2, 10)
	var bar: Piece = _lib.make_piece("bar2", 0)
	var sq: Piece = _lib.make_piece("square", 0)
	plan.add_piece(0, bar, bar.cells_at(Vector2i(4, 0)))
	plan.add_piece(1, sq, sq.cells_at(Vector2i(4, 1)))
	var tags: Array = SkillAvailability.piece_tags_of(plan, HERO)
	ck("two placed pieces -> two tag lists: bar2 line / square compact", tags.size() == 2 and (tags[0] as Array).has("line")
		and (tags[1] as Array).has("square") and (tags[1] as Array).has("compact"), str(tags))
	ck("an empty plan -> no tag lists (need_shape)", SkillAvailability.piece_tags_of(CastPlan.new().init(2, 10), HERO).is_empty())


func test_dpc_bonus_rule() -> void:
	var s: Dictionary = SkillConfig.load_from_file().get_skill(ID)
	ck("2 cells: +0; 3: +1; 4: +2; 5: +3; 6: +3 (cap)", is_zero_approx(CutEffects.dpc_bonus(s, 2)) and is_equal_approx(CutEffects.dpc_bonus(s, 3), 1.0)
		and is_equal_approx(CutEffects.dpc_bonus(s, 4), 2.0) and is_equal_approx(CutEffects.dpc_bonus(s, 5), 3.0)
		and is_equal_approx(CutEffects.dpc_bonus(s, 6), 3.0))
	ck("no bonus field -> 0", is_zero_approx(CutEffects.dpc_bonus({}, 5)))


func test_pierce_order_and_one_hit() -> void:
	# bar4 along row 1, hero on (1,1): the lance lands on (4,1) first then pierces (5,1) (6,1) (7,1), each later.
	var w: Dictionary = _world(Vector2i(7, 1))
	(w["player"] as CutActor).begin_swing(BAR4, ID, true, 1, -1.0, {}, _ctx(w["sc"], "bar4", BAR4))
	_run(w, (w["player"] as CutActor).get_duration() + 1.0)
	var log: Array = w["log"]
	var ordered: bool = log.size() == 4
	for i: int in log.size():
		ordered = ordered and log[i]["cell"] == BAR4[i] and (i == 0 or float(log[i]["at"]) > float(log[i - 1]["at"]) + 0.001)
	ck("4 cells resolve one after another from the hero outward", ordered, str(log))
	var hits: int = 0
	for e: Dictionary in log:
		if bool(e["hit"]):
			hits += 1
	ck("one hit, at the far end (7,1): (5 + 2) x 4 = 28", hits == 1 and bool(log[3]["hit"]) and is_equal_approx(_lost(w), 28.0),
		"%.1f" % _lost(w))
	var w2: Dictionary = _world(Vector2i(6, 1))
	(w2["player"] as CutActor).begin_swing(BAR2, ID, true, 1, -1.0, {}, _ctx(w2["sc"], "bar2", BAR2))
	_run(w2, 2.0)
	ck("bar2 (no bonus): 5 x 2 = 10", is_equal_approx(_lost(w2), 10.0), "%.1f" % _lost(w2))


func test_other_cards_ignore_the_rule() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cd := SkillCooldowns.new()
	var square_only: Dictionary = {SkillAvailability.CTX_PIECE_TAGS: [["square", "compact"]]}
	ck("kiem_khi with only a square placed: available", bool(SkillAvailability.check(sc, cd, "kiem_khi", 4, 1, square_only)["available"]))
	var w: Dictionary = _world(Vector2i(6, 1))
	(w["player"] as CutActor).begin_swing(BAR4, "kiem_khi", true, 1, -1.0, {}, {})
	_run(w, 2.0)
	ck("kiem_khi bar4: 6 x 4 = 24 (no dpc bonus)", is_equal_approx(_lost(w), 24.0), "%.1f" % _lost(w))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 1))
	(a["player"] as CutActor).begin_swing(BAR4, ID, true, 1, -1.0, {}, _ctx(a["sc"], "bar4", BAR4))
	_run(a, 2.0)
	var b: Dictionary = _world(Vector2i(5, 1))
	(b["player"] as CutActor).begin_swing(BAR4, ID, true, 1, -1.0, {}, _ctx(b["sc"], "bar4", BAR4))
	_run(b, 2.0)
	ck("two identical runs: same log, 28 damage", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), 28.0)
		and is_equal_approx(_lost(a), _lost(b)), "%.1f" % _lost(a))

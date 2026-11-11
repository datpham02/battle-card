extends SceneTree
## Skill v2 batch 5 (Deferred 4): a card may carry several shape clauses (`shape_clause` + `shape_clauses` list);
## CastResolver.active_clause picks the FIRST that holds for the cast and every reader goes through it. Thiên Thạch:
## `plus` (ring step 0, hub x2) first, then `square` (hub_all: every cell is a hub at hover, x1.5); a bar holds neither.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_shape_clauses_test.gd

const ID: String = "thien_thach"
const HERO := Vector2i(1, 1)
const PLUS: Array[Vector2i] = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]
const SQUARE: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1), Vector2i(6, 1)]
const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]

var fails: int = 0
var _lib: PieceLibrary


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	_lib = PieceLibrary.load_from_file()
	test_data_and_validation()
	test_active_clause_order()
	test_square_every_cell_is_a_hub()
	test_plus_still_first()
	test_bar_holds_none()
	test_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func test_data_and_validation() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	var clauses: Array[Dictionary] = CastResolver.shape_clauses(s)
	ck("thien_thach: two clauses, plus (ring 0, hub x2) then square (hub_all), shape_clause = the first, no errors", clauses.size() == 2
		and clauses[0]["tag"] == "plus" and is_equal_approx(float(clauses[0]["hub_mult"]), 2.0) and clauses[1]["tag"] == "square"
		and bool(clauses[1]["hub_all"]) and (s["shape_clause"] as Dictionary)["tag"] == "plus" and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("a card with one shape_clause lists it alone; a card with none lists nothing", CastResolver.shape_clauses(sc.get_skill("moc_keo")).size() == 1
		and CastResolver.shape_clauses(sc.get_skill("kiem_khi")).is_empty())
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "arrival", "shape_clauses": {"tag": "plus"}}, "damage")
	ck("shape_clauses must be a list", not (bad["errors"] as Array).is_empty())
	var bad2: Dictionary = CastResolver.validate("x", {"resolve": "arrival", "shape_clauses": [{"tag": "plus", "bogus": 1}]}, "damage")
	ck("every entry is validated like a shape_clause (unknown key)", not (bad2["errors"] as Array).is_empty())
	var ok: Dictionary = CastResolver.validate("x", {"resolve": "arrival", "shape_clauses": [{"tag": "plus", "hub_mult": 2.0}, {"tag": "square", "hub_all": true}]}, "damage")
	ck("a list alone (no shape_clause) is valid: shape_clause = its first entry", (ok["errors"] as Array).is_empty()
		and (ok["shape_clauses"] as Array).size() == 2 and (ok["shape_clause"] as Dictionary)["tag"] == "plus", str(ok["errors"]))


func test_active_clause_order() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("plus5 -> the plus clause", CastResolver.active_clause(s, _ctx(sc, "plus5", PLUS))["tag"] == "plus")
	ck("square -> the square clause", CastResolver.active_clause(s, _ctx(sc, "square", SQUARE))["tag"] == "square")
	ck("bar4 -> {}", CastResolver.active_clause(s, _ctx(sc, "bar4", BAR4)).is_empty())
	# the first that holds wins: a skill whose two clauses both match a square piece
	var both: Dictionary = {"shape_clauses": [{"tag": "square", "tags": ["square"], "hub_mult": 3.0}, {"tag": "compact", "tags": ["compact"], "hub_mult": 1.0}]}
	ck("two clauses that both hold: the first (card order) is the active one", is_equal_approx(float(CastResolver.active_clause(both, _ctx(sc, "square", SQUARE))["hub_mult"]), 3.0))


func test_square_every_cell_is_a_hub() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), SQUARE, _ctx(sc, "square", SQUARE))
	var ev: Array = plan["events"]
	var hubs: int = 0
	var at_hover: bool = true
	var mult_ok: bool = true
	for e: Dictionary in ev:
		if e["kind"] == "hub":
			hubs += 1
		at_hover = at_hover and is_equal_approx(float(e["t"]), 0.6)
		mult_ok = mult_ok and is_equal_approx(float(e["mult"]), 1.5)
	ck("square: 4 events, every one a hub at 0.6 s x1.5 (hub_all), one hit per cast", ev.size() == 4 and hubs == 4 and at_hover and mult_ok
		and int(plan["max_hits"]) == 1, str(ev))


func test_plus_still_first() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), PLUS, _ctx(sc, "plus5", PLUS))
	var hubs: int = 0
	var hub_mult: float = 0.0
	var all_at_hover: bool = true
	for e: Dictionary in plan["events"]:
		if e["kind"] == "hub":
			hubs += 1
			hub_mult = float(e["mult"])
		all_at_hover = all_at_hover and is_equal_approx(float(e["t"]), 0.6)
	ck("plus: one hub x2, every ring at 0.6 (the batch-2 clause unchanged)", hubs == 1 and is_equal_approx(hub_mult, 2.0) and all_at_hover)


func test_bar_holds_none() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR4, _ctx(sc, "bar4", BAR4))
	var by: Dictionary = {}
	for e: Dictionary in plan["events"]:
		by[e["cells"][0]] = e
	ck("bar4: the card's own numbers: hub (5,1) at 0.6 x1.5, rings 0.1 s apart", by[Vector2i(5, 1)]["kind"] == "hub"
		and is_equal_approx(float(by[Vector2i(5, 1)]["mult"]), 1.5) and is_equal_approx(float(by[Vector2i(7, 1)]["t"]), 0.8), str(plan["events"]))


func test_determinism() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var a: Dictionary = CastResolver.plan(sc.get_skill(ID), SQUARE, _ctx(sc, "square", SQUARE))
	var b: Dictionary = CastResolver.plan(sc.get_skill(ID), SQUARE, _ctx(sc, "square", SQUARE))
	ck("two identical plans", str(a["events"]) == str(b["events"]))

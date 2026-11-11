extends SceneTree
## Skill v2 batch 4, Thiên Quang (thien_quang): sky drops from the centre, one damage hit per cast, and the new
## `keyword_hits_max`: a drop that finds the unit after the damage hit is spent applies only the card's keywords (+1
## Hàn), up to 2 per cast; the `plus` clause heals the caster when the centre pillar hits. Plan and the real arbiter.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_keyword_cap_test.gd

const ID: String = "thien_quang"
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
	test_centre_first_hit_and_heal()
	test_keyword_only_drops_capped()
	test_no_clause_no_heal()
	test_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _world(boss: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	state.set_player_hp(50.0)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0)),
			"kw": bool(ev.get("keyword_only", false)), "heal": float(ev.get("hub_heal", 0.0))}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, shape: String, cells: Array[Vector2i], sec: float = 1.5) -> void:
	(w["player"] as CutActor).begin_swing(cells, ID, true, 1, -1.0, {}, _ctx(w["sc"], shape, cells))
	var until: float = (w["player"] as CutActor).get_duration() + sec
	var t: float = 0.0
	while t < until:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


# plus5 at (4,0): (5,0) (4,1) (5,1) (6,1) (5,2); centre (5,1)
const PLUS: Array[Vector2i] = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]
const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("Cleric epic: sky arrival from the centre, hover 0.7, 1 hit, +1 Hàn, keyword cap 2, plus clause heal 6, no errors",
		sc.hero_of(ID) == "giao_si" and s["resolve"] == "arrival" and s["drop_order"] == "from_centre" and is_equal_approx(float(s["sky_hover_sec"]), 0.7)
		and int(s["max_hits"]) == 1 and int(s["frost_stacks"]) == 1 and int(s["keyword_hits_max"]) == 2
		and is_equal_approx(float(s["shape_clause"]["hub_heal"]), 6.0) and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("every other card has no keyword cap", int(sc.get_skill("han_kiem")["keyword_hits_max"]) == 0)


func test_centre_first_hit_and_heal() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast(w, "plus5", PLUS)
	var log: Array = w["log"]
	ck("the centre pillar falls first (0.7 s) and hits the boss there: 5 x 5 = 25, +1 Hàn, the Cleric heals 6 (50 -> 56)",
		log.size() == 5 and log[0]["cell"] == Vector2i(5, 1) and bool(log[0]["hit"]) and is_equal_approx(float(log[0]["dmg"]), 25.0)
		and is_equal_approx(float(log[0]["heal"]), 6.0) and is_equal_approx((w["state"] as CombatState).player_hp, 56.0)
		and (w["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY) == 1, str(log))
	ck("one damage hit per cast", is_equal_approx(_lost(w), 25.0))


func test_keyword_only_drops_capped() -> void:
	# a 3-wide boss on (4,1) (5,1) (6,1) under a bar4: the hub (5,1) hits, (4,1) applies Hàn only, (6,1) is past the cap
	var w: Dictionary = _world(Vector2i(4, 1))
	(w["state"] as CombatState).set_enemy_footprint([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	_cast(w, "bar4", BAR4)
	var hits: int = 0
	var kw: int = 0
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			hits += 1
		if bool(e["kw"]):
			kw += 1
	ck("one damage hit, one keyword-only drop, Hàn 2 (the cap), the third drop on the boss adds nothing", hits == 1 and kw == 1
		and (w["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY) == 2 and is_equal_approx(_lost(w), 20.0), "%.1f %s" % [_lost(w), str(w["log"])])


func test_no_clause_no_heal() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast(w, "bar4", BAR4)
	ck("bar4 (no plus): the hit heals nothing", is_equal_approx((w["state"] as CombatState).player_hp, 50.0) and is_equal_approx(_lost(w), 20.0))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(6, 1))
	_cast(a, "plus5", PLUS)
	var b: Dictionary = _world(Vector2i(6, 1))
	_cast(b, "plus5", PLUS)
	ck("two identical runs: same log and HP", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), _lost(b)))

extends SceneTree
## Skill v2 batch 5 (Deferred 8 / 9): a snapping trap's damage goes through the target's flat defense like a hit
## (combat.json reactions.trap_through_defense; SwingArbiter hands StatusEffects the defense), a spring trap's fling
## never enters a pillar / hole (the mover's blockers) and slams (R3) when stopped, and Gai Nổ's blast consumes a
## fire-wall column (the burn is put out, the cell counts as detonated).
## Run: godot --headless --path . -s res://tests/unit/combat/status_effects_trap_defense_test.gd

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
	test_trap_through_defense()
	test_trap_toll_rule_as_data()
	test_fling_into_a_pillar_slams()
	test_detonate_fire_wall()
	test_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _world(boss: Vector2i, defense: float = 0.0, blocked: Callable = Callable()) -> Dictionary:
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
	arb.boss_defense = defense
	if blocked.is_valid():
		arb.blocked_cell_fns[CombatState.Side.ENEMY] = blocked
	var fired: Array = []
	fx.reaction_fired.connect(func(side: int, id: String, dmg: float) -> void: fired.append("%d:%s:%.0f" % [side, id, dmg]))
	fx.tick(0.0, state)
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "arb": arb, "fired": fired}


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _ctx(sc: SkillConfig, id: String, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(id, 1, pieces, [cells], sc.get_skill(id)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, id: String, shape: String, cells: Array[Vector2i], sec: float = 0.2) -> void:
	(w["player"] as CutActor).begin_swing(cells, id, true, 1, -1.0, {}, _ctx(w["sc"], id, shape, cells))
	_run(w, (w["player"] as CutActor).get_duration() + sec)


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR2: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1)]


func test_trap_through_defense() -> void:
	# bay_kep bar2 (5,1)-(6,1), boss defense 4: the boss steps onto (6,1): 6 x 1 cell under = 6 - 4 = 2
	var w: Dictionary = _world(Vector2i(7, 1), 4.0)
	_cast(w, "bay_kep", "bar2", BAR2)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(w, STEP)
	ck("bay_kep snap 6 through defense 4 = 2, Pinned", is_equal_approx(_lost(w), 2.0) and (w["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY), "%.1f" % _lost(w))
	# a Guard on the boss adds to the defense (the arbiter's defense_fn): defense 4 + guard 10 >= the snap -> minimum 1
	var w2: Dictionary = _world(Vector2i(7, 1), 4.0)
	(w2["fx"] as StatusEffects).guard(CombatState.Side.ENEMY, 10.0, 5.0)
	_cast(w2, "bay_kep", "bar2", BAR2)
	(w2["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(w2, STEP)
	ck("defense 4 + Guard 10: the snap never goes below 1", is_equal_approx(_lost(w2), 1.0), "%.1f" % _lost(w2))


func test_trap_toll_rule_as_data() -> void:
	var w: Dictionary = _world(Vector2i(7, 1), 4.0)
	(w["fx"] as StatusEffects).trap_through_defense = false
	_cast(w, "bay_kep", "bar2", BAR2)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(w, STEP)
	ck("trap_through_defense false: the old thorn-toll rule, 6 straight to HP", is_equal_approx(_lost(w), 6.0), "%.1f" % _lost(w))
	# a trap without a status defense hook (no arbiter) keeps the toll rule too
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	ck("CombatConfig sets trap_through_defense true on the book; without a defense_fn nothing is subtracted", fx.trap_through_defense and not fx.defense_fn.is_valid())


func test_fling_into_a_pillar_slams() -> void:
	# bay_lo bar2 (4,1)-(5,1), boss enters (5,1): fling 2 toward +x; (6,1) is a pillar -> 0 cells, the slam 8 + Pin 0.6
	var pillar: Vector2i = Vector2i(6, 1)
	var w: Dictionary = _world(Vector2i(7, 1), 0.0, func(c: Vector2i) -> bool: return c == pillar)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(7, 0))
	_run(w, STEP)
	_cast(w, "bay_lo", "bar2", [Vector2i(4, 1), Vector2i(5, 1)] as Array[Vector2i])
	(w["state"] as CombatState).set_enemy_cell(Vector2i(5, 1))
	_run(w, STEP)
	ck("the fling stops at the pillar: 3 + R3 8 = 11, still on (5,1), Pinned 0.6, reaction_fired r3", is_equal_approx(_lost(w), 11.0)
		and (w["state"] as CombatState).enemy_cell == Vector2i(5, 1) and absf((w["fx"] as StatusEffects).get_pin_left(CombatState.Side.ENEMY) - 0.6) < 0.02
		and (w["fired"] as Array) == ["1:r3:8"], "%.1f %s %s" % [_lost(w), str((w["state"] as CombatState).enemy_cell), str(w["fired"])])


func test_detonate_fire_wall() -> void:
	# a fire wall column on (6,0)-(6,2), the boss on (6,1): gai_no's bar3 over the column detonates the wall (1 cell under the boss)
	var w: Dictionary = _world(Vector2i(6, 1))
	var fx: StatusEffects = w["fx"]
	var col: Array[Vector2i] = [Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2)]
	fx.ignite(col, 5.0, 10.0, 0.0, false, true)
	ck("the column is a fire wall", fx.wall_cells() == col, str(fx.wall_cells()))
	var r: Dictionary = CutEffects.apply(w["state"], w["grid"], CombatState.Side.PLAYER, col, "gai_no", w["cc"], w["sc"], fx, Callable(), 1,
		Callable(), Callable(), {"reactions": CombatConfig.load_from_file().reactions()})
	ck("gai_no blows the 3 wall cells: hit 6 x 1 cell under the boss, the wall out (no burn left)", bool(r["hit"]) and (r["detonated"] as Array).size() == 3
		and is_equal_approx(float(r["damage"]), 6.0) and fx.wall_cells().is_empty() and fx.burning_cells().is_empty(), str(r))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(7, 1), 4.0)
	var b: Dictionary = _world(Vector2i(7, 1), 4.0)
	for w: Dictionary in [a, b]:
		_cast(w, "bay_kep", "bar2", BAR2)
		(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
		_run(w, STEP)
	ck("two identical runs: same HP", is_equal_approx(_lost(a), _lost(b)))

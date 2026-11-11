extends SceneTree
## Skill v2 batch 3, Tường Đá (tuong_da): the M11 pillar zone through the real path: data, the empty mask cells become
## pillars (never under the boss, never a locked cell), a pillar blocks the boss's step (UnitMover blocker) and is a
## blocked cell for a forced move (a push into it slams for a card that lists r3), the leave-a-path rule keeps the
## boss one exit, the line clause lasts 4 s, pillars expire, a player zone never overwrites a pillar, determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/status_effects_pillar_test.gd

const ID: String = "tuong_da"
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
	test_pillars_on_empty_cells_only()
	test_pillar_blocks_the_step_and_slams_a_push()
	test_exit_is_kept()
	test_line_clause_and_expiry()
	test_player_zone_never_overwrites_a_pillar()
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
	# the boss's mover with the pillar blocker, as CombatView._wire_zones wires it
	var mover := UnitMover.new(state, CombatState.Side.ENEMY, 0.0)
	mover.add_blocker(func(cell: Vector2i) -> bool: return fx.is_pillar(CombatState.Side.ENEMY, cell))
	arb.blocked_cell_fns[CombatState.Side.ENEMY] = Callable(mover, "is_cell_blocked")
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "arb": arb, "mover": mover}


func _ctx(sc: SkillConfig, id: String, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(id, 1, pieces, [cells], sc.get_skill(id)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, id: String, shape: String, cells: Array[Vector2i], sec: float = STEP) -> void:
	(w["player"] as CutActor).begin_swing(cells, id, true, 1, -1.0, {}, _ctx(w["sc"], id, shape, cells))
	_run(w, (w["player"] as CutActor).get_duration() + sec)


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


const BAR3: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const L3: Array[Vector2i] = [Vector2i(6, 0), Vector2i(6, 1), Vector2i(7, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared rare pillar card, 3 s (line 4 s), dpc 0, zone card, never the boss's, waves x1, no errors", sc.hero_of(ID).is_empty()
		and s["effect"] == "pillar" and is_equal_approx(float(s["pillar_sec"]), 3.0) and is_equal_approx(float(s["shape_clause"]["pillar_sec"]), 4.0)
		and is_zero_approx(float(s["damage_per_cell"])) and sc.is_zone_card(ID) and not sc.is_boss_playable(ID) and s["resolve"] == "waves"
		and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))


func test_pillars_on_empty_cells_only() -> void:
	var w: Dictionary = _world(Vector2i(6, 1))
	var fx: StatusEffects = w["fx"]
	fx.apply_drop(CombatState.Side.ENEMY, [Vector2i(7, 1)] as Array[Vector2i], 0.5, 1.0)
	_cast(w, ID, "l3", L3)
	ck("L (6,0) (6,1) (7,1): the boss's cell and the cracking cell are skipped, (6,0) is a pillar, the boss untouched",
		fx.field_cells(CombatState.Side.ENEMY, StatusEffects.KIND_PILLAR) == [Vector2i(6, 0)] and fx.is_pillar(CombatState.Side.ENEMY, Vector2i(6, 0))
		and not fx.is_pillar(CombatState.Side.ENEMY, Vector2i(6, 1)) and is_equal_approx((w["state"] as CombatState).enemy_hp, 1000.0),
		str(fx.field_cells(CombatState.Side.ENEMY)))


func test_pillar_blocks_the_step_and_slams_a_push() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	_cast(w, ID, "bar3", [Vector2i(6, 1), Vector2i(7, 1), Vector2i(7, 0)])
	ck("pillars on (6,1) (7,1) (7,0)", fx.field_cells(CombatState.Side.ENEMY, StatusEffects.KIND_PILLAR).size() == 3)
	var mover: UnitMover = w["mover"]
	ck("the boss cannot step onto the pillar (6,1)", mover.is_cell_blocked(Vector2i(6, 1)) and not mover.try_step(Vector2i(1, 0))
		and (w["state"] as CombatState).enemy_cell == Vector2i(5, 1))
	ck("it can still step to (5,0)", not mover.is_cell_blocked(Vector2i(5, 0)))
	# dia_chan (push 1, r3) with the boss against the pillar: the push is blocked -> slam
	var hp0: float = (w["state"] as CombatState).enemy_hp
	_cast(w, "dia_chan", "l3", [Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 2)], 1.5)
	ck("dia_chan into the pillar: 15 + R3 8 = 23, the boss stays on (5,1)", is_equal_approx(hp0 - (w["state"] as CombatState).enemy_hp, 23.0)
		and (w["state"] as CombatState).enemy_cell == Vector2i(5, 1), "%.1f" % (hp0 - (w["state"] as CombatState).enemy_hp))


func test_exit_is_kept() -> void:
	# the boss in the corner (7,2): its only neighbours are (6,2) and (7,1); a bar covering both keeps one open
	var w: Dictionary = _world(Vector2i(7, 2))
	var fx: StatusEffects = w["fx"]
	_cast(w, ID, "bar2", [Vector2i(6, 2), Vector2i(7, 1)])
	var pillars: Array[Vector2i] = fx.field_cells(CombatState.Side.ENEMY, StatusEffects.KIND_PILLAR)
	ck("the leave-a-path rule drops one cell: exactly one pillar, the boss keeps an exit", pillars.size() == 1, str(pillars))


func test_line_clause_and_expiry() -> void:
	var w: Dictionary = _world(Vector2i(4, 0))
	var fx: StatusEffects = w["fx"]
	_cast(w, ID, "bar3", BAR3)
	ck("bar3 (line): pillars last 4 s", is_equal_approx(fx.field_at(CombatState.Side.ENEMY, Vector2i(5, 1))["left"], 4.0 - STEP) or
		absf(float(fx.field_at(CombatState.Side.ENEMY, Vector2i(5, 1))["left"]) - 4.0) < 0.02, str(fx.field_at(CombatState.Side.ENEMY, Vector2i(5, 1))))
	_run(w, 4.1)
	ck("after 4 s the pillars are gone", fx.field_cells(CombatState.Side.ENEMY).is_empty())
	var w2: Dictionary = _world(Vector2i(4, 0))
	_cast(w2, ID, "l3", L3)
	ck("L (no line tag): 3 s", absf(float((w2["fx"] as StatusEffects).field_at(CombatState.Side.ENEMY, Vector2i(6, 0))["left"]) - 3.0) < 0.02)


func test_player_zone_never_overwrites_a_pillar() -> void:
	var w: Dictionary = _world(Vector2i(4, 0))
	var fx: StatusEffects = w["fx"]
	_cast(w, ID, "bar3", BAR3)
	var lit: Array[Vector2i] = fx.ignite(BAR3, 2.0, 0.5, 1.0)
	ck("a burn on pillar cells is skipped", lit.is_empty() and fx.zone_kind_at(Vector2i(6, 1)) == "pillar")
	fx.apply_drop(CombatState.Side.ENEMY, [Vector2i(5, 1)] as Array[Vector2i], 0.5, 1.0)
	ck("a lock (crack) removes the pillar", not fx.is_pillar(CombatState.Side.ENEMY, Vector2i(5, 1)))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(7, 2))
	_cast(a, ID, "bar2", [Vector2i(6, 2), Vector2i(7, 1)])
	var b: Dictionary = _world(Vector2i(7, 2))
	_cast(b, ID, "bar2", [Vector2i(6, 2), Vector2i(7, 1)])
	ck("two identical casts keep the same pillar", str((a["fx"] as StatusEffects).field_cells(CombatState.Side.ENEMY)) == str((b["fx"] as StatusEffects).field_cells(CombatState.Side.ENEMY)))

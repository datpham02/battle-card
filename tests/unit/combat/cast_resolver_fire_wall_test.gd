extends SceneTree
## Skill v2 batch 3, Hỏa Tuyến (hoa_tuyen): the M04 ground run (stopped by holes, batch 2) with an ignite payload
## (3 s) and the `line` clause `fire_wall`: the burning line blocks the boss's steps (StatusEffects.is_fire_wall, the
## boss mover's blocker) while the leave-a-path rule keeps it one exit; a non-line mask burns without blocking; the
## wall goes out with the burn; determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_fire_wall_test.gd

const ID: String = "hoa_tuyen"
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
	test_line_burns_as_a_wall_and_blocks_the_boss()
	test_non_line_burns_without_blocking()
	test_exit_is_kept()
	test_wall_goes_out_with_the_burn()
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
	var mover := UnitMover.new(state, CombatState.Side.ENEMY, 0.0)
	mover.add_blocker(func(cell: Vector2i) -> bool: return fx.is_fire_wall(cell))
	arb.blocked_cell_fns[CombatState.Side.ENEMY] = Callable(mover, "is_cell_blocked")
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "hit": hit, "wall": ev.get("wall_cells", [])}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "mover": mover, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, shape: String, cells: Array[Vector2i], sec: float = 1.5) -> void:
	(w["player"] as CutActor).begin_swing(cells, ID, true, 1, -1.0, {}, _ctx(w["sc"], shape, cells))
	var t: float = 0.0
	var until: float = (w["player"] as CutActor).get_duration() + sec
	while t < until:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const COL3: Array[Vector2i] = [Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2)]
const L3: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1), Vector2i(6, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("Mage rare: GROUND arrival, dpc 4, ignite payload 3 s, line clause fire_wall, 1 hit, no errors", sc.hero_of(ID) == "phap_su"
		and s["resolve"] == "arrival" and s["delivery"]["type"] == SkillDelivery.GROUND_PROPAGATION and is_equal_approx(float(s["damage_per_cell"]), 4.0)
		and is_equal_approx(float(s["event_payload"]["ignite"]["sec"]), 3.0) and bool(s["shape_clause"]["fire_wall"]) and int(s["max_hits"]) == 1
		and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	var bad: Dictionary = CastResolver.validate("x", {"shape_clause": {"tag": "line", "fire_wall": 1}}, "damage")
	ck("fire_wall must be a bool", not (bad["errors"] as Array).is_empty())


func test_line_burns_as_a_wall_and_blocks_the_boss() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	_cast(w, "bar3", COL3)  # a vertical bar3: the line tag holds; the boss on (5,1) next to it
	ck("the 3 cells burn and are a fire wall", fx.burning_cells().size() == 3 and fx.wall_cells() == COL3, str(fx.wall_cells()))
	var mover: UnitMover = w["mover"]
	ck("the boss cannot step into the wall (6,1), can step to (4,1)", mover.is_cell_blocked(Vector2i(6, 1)) and not mover.is_cell_blocked(Vector2i(4, 1))
		and not mover.try_step(Vector2i(1, 0)) and (w["state"] as CombatState).enemy_cell == Vector2i(5, 1))
	ck("the boss off the mask took nothing", is_zero_approx(_lost(w)))


func test_non_line_burns_without_blocking() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	var fx: StatusEffects = w["fx"]
	_cast(w, "l3", L3)
	ck("an L: the cells burn, none is a wall, the boss may step into them", fx.burning_cells().size() == 3 and fx.wall_cells().is_empty()
		and not (w["mover"] as UnitMover).is_cell_blocked(Vector2i(6, 1)))


func test_exit_is_kept() -> void:
	# the boss in the corner (7,2): a vertical line on x = 6 would be fine; a line (6,2) (7,1)? not a line. Use the wall on
	# the boss's two exits: a bar2 (6,2)-(7,1) is not a line... a column (7,0) (7,1) blocks (7,1); (6,2) stays open.
	# Box the boss with a line covering its only exit: boss on (7,2) with a crack on (6,2), the line (7,0)-(7,1)
	var w: Dictionary = _world(Vector2i(7, 2))
	var fx: StatusEffects = w["fx"]
	fx.apply_drop(CombatState.Side.ENEMY, [Vector2i(6, 2)] as Array[Vector2i], 0.5, 1.0)
	(w["mover"] as UnitMover).add_blocker(func(cell: Vector2i) -> bool: return fx.is_cracking(CombatState.Side.ENEMY, cell) or fx.is_hole(CombatState.Side.ENEMY, cell))
	_cast(w, "bar2", [Vector2i(7, 0), Vector2i(7, 1)])
	ck("the boss's last exit (7,1) burns but is NOT a wall; (7,0) is", not fx.is_fire_wall(Vector2i(7, 1)) and fx.is_burning(Vector2i(7, 1))
		and fx.is_fire_wall(Vector2i(7, 0)), str(fx.wall_cells()))


func test_wall_goes_out_with_the_burn() -> void:
	var w: Dictionary = _world(Vector2i(4, 1))
	var fx: StatusEffects = w["fx"]
	_cast(w, "bar3", COL3, 4.0)  # the run reaches the far cells 0.72 s after the swing; the burn lasts 3 s
	ck("4 s later the fire and the wall are gone", fx.burning_cells().is_empty() and fx.wall_cells().is_empty())


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(6, 1))
	_cast(a, "bar3", COL3, 1.0)
	var b: Dictionary = _world(Vector2i(6, 1))
	_cast(b, "bar3", COL3, 1.0)
	ck("two identical runs: same log, HP (the boss on the line is hit: 12) and wall", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), _lost(b))
		and _lost(a) >= 12.0 and str((a["fx"] as StatusEffects).wall_cells()) == str((b["fx"] as StatusEffects).wall_cells()), "%.1f" % _lost(a))

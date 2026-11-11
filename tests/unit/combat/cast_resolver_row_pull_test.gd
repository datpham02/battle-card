extends SceneTree
## Skill v2 batch 4, Móc Kéo (moc_keo): the hook (the CASTER_TO_TARGET surge of M03) and the M12 row pull: a hit drags
## the target along its row toward the divider up to 2 cells (the line_h clause 3), one by one, the pull path is
## telegraphed on cast_scheduled, a refused step slams (R3), and ending on thorns triggers them. Real arbiter path.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_row_pull_test.gd

const ID: String = "moc_keo"
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
	test_hook_pulls_two_toward_the_divider()
	test_line_h_pulls_three_and_telegraph()
	test_blocked_pull_slams()
	test_ending_on_thorns_triggers_them()
	test_miss_pulls_nothing()
	test_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _world(boss: Vector2i, blocked: Callable = Callable()) -> Dictionary:
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
	if blocked.is_valid():
		arb.blocked_cell_fns[CombatState.Side.ENEMY] = blocked
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "kind": ev["kind"], "hit": hit, "dmg": float(ev.get("damage", 0.0)),
			"pulled": bool(ev.get("pulled", false)), "to": ev.get("pull_to", Vector2i(-9, -9)), "reaction": str(ev.get("reaction", ""))}))
	var sched: Array = []
	arb.cast_scheduled.connect(func(_side: int, c: Dictionary) -> void: sched.append(c))
	var done: Array = []
	arb.swing_resolved.connect(func(_side: int, r: Dictionary) -> void: done.append(r))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log, "sched": sched, "done": done}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _cast(w: Dictionary, shape: String, cells: Array[Vector2i], sec: float = 1.0) -> void:
	(w["player"] as CutActor).begin_swing(cells, ID, true, 1, -1.0, {}, _ctx(w["sc"], shape, cells))
	var until: float = (w["player"] as CutActor).get_duration() + sec
	var t: float = 0.0
	while t < until:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR2: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1)]
const BAR3: Array[Vector2i] = [Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
# l3 at (6,0): (6,0) (6,1) (7,1): no line tag
const L3: Array[Vector2i] = [Vector2i(6, 0), Vector2i(6, 1), Vector2i(7, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("Hunter rare: CASTER_TO_TARGET arrival, dpc 4, pull 2 (line_h 3), reaction r3, 1 hit, no errors", sc.hero_of(ID) == "tho_san"
		and s["resolve"] == "arrival" and s["delivery"]["type"] == SkillDelivery.CASTER_TO_TARGET and int(s["pull_row_cells"]) == 2
		and int(s["shape_clause"]["pull_row_cells"]) == 3 and (s["reactions"] as Array) == ["r3"] and int(s["max_hits"]) == 1
		and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("every other card pulls no row", int(sc.get_skill("tram_dia")["pull_row_cells"]) == 0)


func test_hook_pulls_two_toward_the_divider() -> void:
	# L (6,0) (6,1) (7,1), boss on (7,1): the hook lands on (6,1) (nearest the hero) and surges; the hit on (7,1) drags the
	# boss 2 cells toward the divider: (6,1) then (5,1)
	var w: Dictionary = _world(Vector2i(7, 1))
	_cast(w, "l3", L3)
	var hit: Dictionary = {}
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			hit = e
	ck("hit 4 x 3 = 12 on (7,1), pulled to (5,1)", is_equal_approx(_lost(w), 12.0) and not hit.is_empty() and bool(hit["pulled"]) and hit["to"] == Vector2i(5, 1)
		and (w["state"] as CombatState).enemy_cell == Vector2i(5, 1), "%.1f %s" % [_lost(w), str(w["log"])])
	ck("one hit per cast (the dragged boss crosses mask cells without a second hit)", (w["done"] as Array).size() == 1 and int((w["done"] as Array)[0]["hits"]) == 1)


func test_line_h_pulls_three_and_telegraph() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	_cast(w, "bar3", BAR3)
	var sched: Dictionary = (w["sched"] as Array)[0]
	ck("the telegraph lists the pull path from (7,1): (6,1) (5,1) (4,1)", (sched.get("pull_path", []) as Array) == [Vector2i(6, 1), Vector2i(5, 1), Vector2i(4, 1)], str(sched.get("pull_path")))
	ck("line_h: pulled 3 to (4,1), 12 damage", (w["state"] as CombatState).enemy_cell == Vector2i(4, 1) and is_equal_approx(_lost(w), 12.0),
		"%s %.1f" % [str((w["state"] as CombatState).enemy_cell), _lost(w)])


func test_blocked_pull_slams() -> void:
	var w: Dictionary = _world(Vector2i(7, 1), func(c: Vector2i) -> bool: return c == Vector2i(5, 1))
	_cast(w, "bar3", BAR3)
	var r: Dictionary = (w["done"] as Array)[0]
	ck("(5,1) blocked: one step to (6,1) then the slam: 12 + 8 = 20, Pinned, reaction r3", (w["state"] as CombatState).enemy_cell == Vector2i(6, 1)
		and is_equal_approx(_lost(w), 20.0) and r.get("reaction", "") == "r3" and bool(r.get("pinned", false)), "%.1f %s" % [_lost(w), str(r)])


func test_ending_on_thorns_triggers_them() -> void:
	var w: Dictionary = _world(Vector2i(7, 1))
	ZoneRules.cast_thorns(w["fx"], CombatState.Side.ENEMY, [Vector2i(5, 1)] as Array[Vector2i], 5.0, 6.0, 1)
	_cast(w, "l3", L3)
	# batch 5 (Deferred 5): a forced move that ends on a thorn cell slams too: 12 + the toll 6 + R3 8 = 26, Pinned 0.6
	ck("dragged onto the thorn cell (5,1): the entry toll 6 + 1 Rạn + the R3 slam 8 on top of the hit: 26 (the 0.6 s Pin has run out)", is_equal_approx(_lost(w), 26.0)
		and (w["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 1, "%.1f" % _lost(w))


func test_miss_pulls_nothing() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	_cast(w, "bar2", BAR2)
	ck("off the mask: no damage, not moved", is_zero_approx(_lost(w)) and (w["state"] as CombatState).enemy_cell == Vector2i(7, 2))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(7, 1))
	_cast(a, "bar3", BAR3)
	var b: Dictionary = _world(Vector2i(7, 1))
	_cast(b, "bar3", BAR3)
	ck("two identical runs: same log, HP and cell", str(a["log"]) == str(b["log"]) and is_equal_approx(_lost(a), _lost(b))
		and (a["state"] as CombatState).enemy_cell == (b["state"] as CombatState).enemy_cell)

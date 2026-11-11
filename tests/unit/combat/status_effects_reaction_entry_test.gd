extends SceneTree
## Skill v2 batch 5 (Deferred 5, M15): R1 Hơi Nước when a unit that carries Hàn steps ONTO a burning cell (the status
## book's entry check: 12 straight to HP, the fire out, 1 Hàn spent, reaction_fired), gated by the ICD; R3 Va Đập when a
## forced move (a push) ENDS on a thorn cell: the slam on top of the thorn toll. Real CutActor -> SwingArbiter ->
## CutEffects -> StatusEffects.
## Run: godot --headless --path . -s res://tests/unit/combat/status_effects_reaction_entry_test.gd

const HERO := Vector2i(1, 1)
const STEP: float = 0.01
const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]

var fails: int = 0
var _lib: PieceLibrary


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	_lib = PieceLibrary.load_from_file()
	test_entry_with_han_bursts()
	test_entry_without_han_or_fire_does_nothing()
	test_entry_icd()
	test_push_ending_on_thorns_slams()
	test_push_ending_on_a_clean_cell_no_slam()
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
	var fired: Array = []
	fx.reaction_fired.connect(func(side: int, id: String, dmg: float) -> void: fired.append("%d:%s:%.0f" % [side, id, dmg]))
	var done: Array = []
	arb.swing_resolved.connect(func(_side: int, r: Dictionary) -> void: done.append(r))
	fx.tick(0.0, state)  # seed the entry check's last cells
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "fired": fired, "done": done}


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


func test_entry_with_han_bursts() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	fx.apply_frost(CombatState.Side.ENEMY, 2)
	fx.ignite([Vector2i(6, 1)] as Array[Vector2i], 5.0, 10.0, 0.0)  # no tick damage: the burst alone counts
	(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(w, STEP)
	ck("a boss with 2 Hàn steps onto the burning (6,1): R1 12, Hàn 1 left, the fire out, reaction_fired", is_equal_approx(_lost(w), 12.0)
		and fx.frost_stacks(CombatState.Side.ENEMY) == 1 and not fx.is_burning(Vector2i(6, 1)) and (w["fired"] as Array) == ["1:r1:12"],
		"%.1f %s" % [_lost(w), str(w["fired"])])


func test_entry_without_han_or_fire_does_nothing() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	fx.ignite([Vector2i(6, 1)] as Array[Vector2i], 5.0, 10.0, 0.0)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(w, STEP)
	ck("no Hàn: the entry pays no burst (the burn's own entry toll is 0 here)", is_zero_approx(_lost(w)) and (w["fired"] as Array).is_empty())
	fx.apply_frost(CombatState.Side.ENEMY, 1)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(7, 1))
	_run(w, STEP)
	ck("Hàn but a cold cell: nothing", is_zero_approx(_lost(w)) and fx.frost_stacks(CombatState.Side.ENEMY) == 1)


func test_entry_icd() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	fx.apply_frost(CombatState.Side.ENEMY, 2)  # 3 would burst at once (frost_stacks_to_burst)
	fx.ignite([Vector2i(6, 1), Vector2i(7, 1)] as Array[Vector2i], 5.0, 10.0, 0.0)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))
	_run(w, STEP)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(7, 1))
	_run(w, STEP)
	ck("two burning entries 0.01 s apart: one burst (ICD 1 s), Hàn 1 left, (7,1) still burns", is_equal_approx(_lost(w), 12.0)
		and fx.frost_stacks(CombatState.Side.ENEMY) == 1 and fx.is_burning(Vector2i(7, 1)), "%.1f" % _lost(w))
	_run(w, 1.0)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(6, 1))  # cold now (the first burst put it out)
	_run(w, STEP)
	(w["state"] as CombatState).set_enemy_cell(Vector2i(7, 1))  # still burning, the ICD has run out
	_run(w, STEP)
	ck("after the ICD: the next burning entry bursts again (24 total), no Hàn left", is_equal_approx(_lost(w), 24.0) and fx.frost_stacks(CombatState.Side.ENEMY) == 0, "%.1f" % _lost(w))


func test_push_ending_on_thorns_slams() -> void:
	# xung_kich (push 2): the boss on (5,1) is pushed to (7,1), a thorn cell: the hit + the toll 6 + 1 Rạn + R3 8, Pinned 0.6
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	ZoneRules.cast_thorns(fx, CombatState.Side.ENEMY, [Vector2i(7, 1)] as Array[Vector2i], 5.0, 6.0, 1)
	_cast(w, "xung_kich", "bar4", BAR4)
	var r: Dictionary = (w["done"] as Array)[0]
	var hit: float = float(r["damage"])
	ck("pushed onto the thorn cell (7,1): the hit + toll 6 + R3 8, reaction r3, Pinned, 1 Rạn", (w["state"] as CombatState).enemy_cell == Vector2i(7, 1)
		and is_equal_approx(_lost(w), hit + 6.0 + 8.0) and str(r.get("reaction", "")) == "r3" and fx.is_pinned(CombatState.Side.ENEMY)
		and fx.fragile_stacks(CombatState.Side.ENEMY) == 1, "%.1f hit %.1f %s" % [_lost(w), hit, str(r)])


func test_push_ending_on_a_clean_cell_no_slam() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast(w, "xung_kich", "bar4", BAR4)
	var r: Dictionary = (w["done"] as Array)[0]
	ck("pushed the full 2 onto a clean (7,1): the hit only, no reaction, not Pinned", (w["state"] as CombatState).enemy_cell == Vector2i(7, 1)
		and is_equal_approx(_lost(w), float(r["damage"])) and str(r.get("reaction", "")).is_empty() and not (w["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY), str(r))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 1))
	var b: Dictionary = _world(Vector2i(5, 1))
	for w: Dictionary in [a, b]:
		ZoneRules.cast_thorns(w["fx"], CombatState.Side.ENEMY, [Vector2i(7, 1)] as Array[Vector2i], 5.0, 6.0, 1)
		_cast(w, "xung_kich", "bar4", BAR4)
	ck("two identical runs: same HP", is_equal_approx(_lost(a), _lost(b)))

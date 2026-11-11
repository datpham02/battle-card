extends SceneTree
## Skill v2 batch 3, Gai Nổ (gai_no): `detonate_zones` consumes the player's thorn and trap cells inside the mask;
## the hit counts only the detonated cells under the target's footprint (dpc 6 each, one hit, + fragile_per_cell Rạn
## each); no field inside = a miss; the `branched` clause regrows thorns on the branch tips. Direct CutEffects.apply
## and the real arbiter path.
## Run: godot --headless --path . -s res://tests/unit/combat/cut_effects_detonate_test.gd

const ID: String = "gai_no"
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
	test_detonates_thorns_under_the_boss()
	test_traps_count_too_and_fields_are_spent()
	test_no_field_is_a_miss()
	test_fields_outside_the_mask_stay()
	test_branched_clause_regrows_tips()
	test_real_arbiter()
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
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "arb": arb}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _apply(w: Dictionary, shape: String, cells: Array[Vector2i]) -> Dictionary:
	return CutEffects.apply(w["state"], w["grid"], CombatState.Side.PLAYER, cells, ID, w["cc"], w["sc"], w["fx"], Callable(), 1,
		Callable(), Callable(), {"cast_context": _ctx(w["sc"], shape, cells), "zones": CombatConfig.load_from_file().zone_numbers()})


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR3: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
# t4 at (4,0): (4,0) (5,0) (6,0) (5,1): branched; tips (4,0) (6,0) (5,1)
const T4: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("Hunter epic: detonate_zones, dpc 6, +1 Rạn per cell, branched regrow 2 s, waves x1, no errors", sc.hero_of(ID) == "tho_san"
		and bool(s["detonate_zones"]) and is_equal_approx(float(s["damage_per_cell"]), 6.0) and int(s["fragile_per_cell"]) == 1
		and is_equal_approx(float(s["shape_clause"]["regrow_sec"]), 2.0) and s["resolve"] == "waves" and (s["resolve_errors"] as Array).is_empty(),
		str(s["resolve_errors"]))
	ck("a card without the field never detonates", not bool(sc.get_skill("kiem_khi")["detonate_zones"]))


func test_detonates_thorns_under_the_boss() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	ZoneRules.cast_thorns(fx, CombatState.Side.ENEMY, BAR3, 5.0, 6.0, 1)
	var r: Dictionary = _apply(w, "bar3", BAR3)
	ck("3 thorn cells in the mask, the boss on one: hit, 6 x 1 = 6, +1 Rạn, every thorn spent", bool(r["hit"]) and is_equal_approx(float(r["damage"]), 6.0)
		and int(r["fragile_applied"]) == 1 and (r["detonated"] as Array).size() == 3 and fx.thorn_cells(CombatState.Side.ENEMY).is_empty(), str(r))


func test_traps_count_too_and_fields_are_spent() -> void:
	var w: Dictionary = _world(Vector2i(5, 0))
	var fx: StatusEffects = w["fx"]
	(w["state"] as CombatState).set_enemy_footprint([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])  # 2x1 boss on (5,0) (6,0)
	ZoneRules.cast_thorns(fx, CombatState.Side.ENEMY, [Vector2i(5, 0)] as Array[Vector2i], 5.0, 6.0, 1)
	fx.apply_field(CombatState.Side.ENEMY, StatusEffects.KIND_TRAP, [Vector2i(6, 0)] as Array[Vector2i], 8.0, 7, {"dpc": 1.0})
	var bar4: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0)]
	var r: Dictionary = _apply(w, "bar4", bar4)  # a bar: no branched regrow
	ck("a thorn and a trap under a 2-cell boss: 6 x 2 = 12 in one hit, +2 Rạn, both zones spent (the trap never fired)",
		is_equal_approx(float(r["damage"]), 12.0) and int(r["fragile_applied"]) == 2 and fx.field_cells(CombatState.Side.ENEMY).is_empty()
		and fx.thorn_cells(CombatState.Side.ENEMY).is_empty() and is_equal_approx(_lost(w), 12.0), str(r))


func test_no_field_is_a_miss() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var r: Dictionary = _apply(w, "bar3", BAR3)
	ck("no thorn / trap in the mask: a miss, no damage, no Rạn", not bool(r["hit"]) and is_zero_approx(_lost(w)) and int(r["fragile_applied"]) == 0, str(r))
	var w2: Dictionary = _world(Vector2i(5, 2))
	ZoneRules.cast_thorns(w2["fx"], CombatState.Side.ENEMY, BAR3, 5.0, 6.0, 1)
	var r2: Dictionary = _apply(w2, "bar3", BAR3)
	ck("thorns in the mask but the boss off them: spent, no damage", not bool(r2["hit"]) and (w2["fx"] as StatusEffects).thorn_cells(CombatState.Side.ENEMY).is_empty()
		and is_zero_approx(_lost(w2)))


func test_fields_outside_the_mask_stay() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	ZoneRules.cast_thorns(fx, CombatState.Side.ENEMY, [Vector2i(5, 1), Vector2i(7, 2)] as Array[Vector2i], 5.0, 6.0, 1)
	_apply(w, "bar3", BAR3)
	ck("the thorn outside the mask (7,2) stays", fx.thorn_cells(CombatState.Side.ENEMY) == [Vector2i(7, 2)])


func test_branched_clause_regrows_tips() -> void:
	var w: Dictionary = _world(Vector2i(5, 0))
	var fx: StatusEffects = w["fx"]
	ZoneRules.cast_thorns(fx, CombatState.Side.ENEMY, T4, 5.0, 6.0, 1)
	_apply(w, "t4", T4)
	var regrown: Array[Vector2i] = fx.thorn_cells(CombatState.Side.ENEMY)
	ck("t4 (branched): the 3 tips regrow thorns for 2 s, the junction stays bare", regrown == [Vector2i(4, 0), Vector2i(5, 1), Vector2i(6, 0)]
		and is_equal_approx(fx.thorn_left(CombatState.Side.ENEMY, Vector2i(4, 0)), 2.0), str(regrown))
	var w2: Dictionary = _world(Vector2i(5, 1))
	ZoneRules.cast_thorns(w2["fx"], CombatState.Side.ENEMY, BAR3, 5.0, 6.0, 1)
	_apply(w2, "bar3", BAR3)
	ck("bar3 (not branched): nothing regrows", (w2["fx"] as StatusEffects).thorn_cells(CombatState.Side.ENEMY).is_empty())


func test_real_arbiter() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	ZoneRules.cast_thorns(w["fx"], CombatState.Side.ENEMY, BAR3, 5.0, 6.0, 1)
	(w["player"] as CutActor).begin_swing(BAR3, ID, true, 1, -1.0, {}, _ctx(w["sc"], "bar3", BAR3))
	var t: float = 0.0
	while t < 2.0:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP
	ck("arbiter: 6 damage, thorns spent, 1 Rạn", is_equal_approx(_lost(w), 6.0) and (w["fx"] as StatusEffects).thorn_cells(CombatState.Side.ENEMY).is_empty()
		and (w["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 1, "%.1f" % _lost(w))

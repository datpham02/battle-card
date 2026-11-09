extends SceneTree
## Hỏa Lôi damage-model evaluation seam (SwingArbiter.armed_damage_cells_fn, evaluation only): unset = the approved
## Model A (every armed cell counts); A4 caps the counted cells at 4; C at the boss footprint + 1. Only ARMED (delayed)
## events read it; a non-delayed scheduled card (Trảm Địa) is unaffected.
## Run: godot --headless --path . -s res://tests/unit/balance/damage_model_seam_test.gd

const HERO := Vector2i(1, 1)

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var plus: Array[Vector2i] = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]
	ck("unset: the card's own rule (Model C since 2026-11-09): 5 armed, 1-cell boss -> 6 x 2 x 2 = 24",
		is_equal_approx(_lost("hoa_loi", "plus5", plus, Callable(), 1), 24.0))
	var a := func(n: int, _fp: int) -> int: return n
	ck("Model A via the seam: every armed cell -> 60", is_equal_approx(_lost("hoa_loi", "plus5", plus, a, 1), 60.0))
	var a4 := func(n: int, _fp: int) -> int: return mini(n, 4)
	ck("Model A4: capped at 4 cells -> 48", is_equal_approx(_lost("hoa_loi", "plus5", plus, a4, 1), 48.0))
	var c := func(n: int, fp: int) -> int: return mini(n, fp + 1)
	ck("Model C: 1-cell boss -> min(5, 2) = 2 cells -> 24", is_equal_approx(_lost("hoa_loi", "plus5", plus, c, 1), 24.0))
	ck("Model C: 2x2 boss -> min(5, 5) = 5 cells -> 60", is_equal_approx(_lost("hoa_loi", "plus5", plus, c, 4), 60.0))
	var bar3: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	ck("a non-delayed scheduled card ignores the seam (Trảm Địa same with / without it)",
		is_equal_approx(_lost("tram_dia", "bar3", bar3, c, 1), _lost("tram_dia", "bar3", bar3, Callable(), 1)))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _lost(card: String, shape: String, cells: Array[Vector2i], policy: Callable, fp: int) -> float:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, Vector2i(5, 1) if fp == 1 else Vector2i(5, 0))
	if fp == 4:
		state.set_enemy_footprint([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i])
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	player.cast_time_fn = func(id: String) -> float: return float(sc.get_skill(id).get("cast_time_sec", -1.0))
	var arb := SwingArbiter.new(state, grid, player, CutActor.new(cc, CombatState.Side.ENEMY), cc, sc, fx)
	arb.armed_damage_cells_fn = policy
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece(shape, 0)]
	var ctx: Dictionary = CastContext.build(card, 1, pieces, [cells], sc.get_skill(card)["delivery"], false, CombatState.Side.PLAYER, HERO)
	player.begin_swing(cells, card, true, 1, -1.0, {}, ctx)
	arb.tick(3.0)
	return 1000.0 - state.enemy_hp

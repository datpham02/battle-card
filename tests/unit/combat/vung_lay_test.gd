extends SceneTree
## Skill v2 Vũng Lầy (vung_lay, docs/skill-v2/02-skill-bible.md): instant damage plus TileHazards.add_mire
## for mire_sec on the mask, hit or miss. Compact duration and hole-stop are not this card.
## Run: godot --headless --path . -s res://tests/unit/combat/vung_lay_test.gd

const ID: String = "vung_lay"
const HERO := Vector2i(1, 1)
const BOSS := Vector2i(5, 1)

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data()
	test_hit_lays_mire_and_damage()
	test_miss_still_lays_mire()
	print("FAILS=%d" % fails)
	quit(0)


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("registered", sc.has_skill(ID) and sc.card_order.has(ID))
	ck("no resolve error", sc.validation_errors.is_empty(), str(sc.validation_errors))
	ck("instant damage 2 per cell, mire 4 s, cd 7, min 3",
		str(s.get("resolve", "instant")) == "instant" and is_equal_approx(float(s["damage_per_cell"]), 2.0)
		and is_equal_approx(float(s["mire_sec"]), 4.0) and is_equal_approx(float(s["cooldown_sec"]), 7.0)
		and int(s["min_cells"]) == 3)
	ck("ground travel", str((s["delivery"] as Dictionary).get("type", "")) == "GROUND_PROPAGATION")
	ck("shared common", str(s["rarity"]) == "common" and str(s.get("hero", "")).is_empty())


func test_hit_lays_mire_and_damage() -> void:
	var w: Dictionary = _world(BOSS)
	var cells: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	ck("swing starts", _cast(w, cells))
	_run(w, 3.0)
	ck("damage 2 x 3", is_equal_approx(_lost(w), 6.0), str(_lost(w)))
	var mire: Array[Vector2i] = (w["hazards"] as TileHazards).mire_cells(CombatState.Side.ENEMY)
	ck("three mire cells", mire.size() == 3 and mire.has(Vector2i(5, 1)), str(mire))


func test_miss_still_lays_mire() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	var cells: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	ck("miss swing starts", _cast(w, cells))
	_run(w, 3.0)
	ck("no damage on a miss", is_equal_approx(_lost(w), 0.0), str(_lost(w)))
	var mire: Array[Vector2i] = (w["hazards"] as TileHazards).mire_cells(CombatState.Side.ENEMY)
	ck("mire still laid", mire.size() == 3, str(mire))


func _world(boss: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var hazards := TileHazards.new(grid, 1)
	hazards.configure({})
	hazards.bind_state(state)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	arb.tile_hazards = hazards
	return {"state": state, "sc": sc, "player": player, "arb": arb, "hazards": hazards}


func _cast(w: Dictionary, cells: Array[Vector2i]) -> bool:
	var sc: SkillConfig = w["sc"]
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece("bar3", 0)]
	var groups: Array = [cells]
	var ctx: Dictionary = CastContext.build(ID, 1, pieces, groups, sc.get_skill(ID)["delivery"], false,
		CombatState.Side.PLAYER, HERO)
	return (w["player"] as CutActor).begin_swing(cells, ID, true, 1, -1.0, {}, ctx)


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		(w["arb"] as SwingArbiter).tick(0.05)
		t += 0.05


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp

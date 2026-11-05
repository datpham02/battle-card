extends SceneTree
## 2026-11-05 Mage balance (design/quick-specs/phap-su-lua-trung-2026-11-05.md): a burn card with damage_per_cell > 0
## hits like a damage card when the target stands inside its cells (damage = damage_per_cell x cells, then the usual
## order: Ran, passive, defense...) AND ignites the cells. A miss still ignites but deals nothing. A burn card with
## damage_per_cell 0 keeps the old rule (ignite, hit, no damage).
## Run: godot --headless --path . -s res://tests/unit/combat/burn_impact_test.gd

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _state() -> CombatState:
	# Target (PLAYER side here, as in status_test) stands on (1, 1).
	return CombatState.new(BoardGrid.new(3, 3), 1000.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))


func _init() -> void:
	var grid := BoardGrid.new(3, 3)
	var cc := CutConfig.new()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var dpc: float = float(sc.get_skill("hoa_xa").get("damage_per_cell", 0.0))
	_check("test_hoa_xa_data_has_an_impact_damage", dpc > 0.0, "damage_per_cell %s" % dpc)
	var two: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2)]

	# Hit: the target is inside -> damage x cells and the cells burn.
	var st: CombatState = _state()
	var fx := StatusEffects.new()
	var r: Dictionary = CutEffects.apply(st, grid, CombatState.Side.ENEMY, two, "hoa_xa", cc, sc, fx)
	_check("test_burn_hit_deals_damage_per_cell_times_cells", r["hit"] == true and is_equal_approx(float(r["damage"]), dpc * 2.0) and is_equal_approx(st.player_hp, 1000.0 - dpc * 2.0), str(r["damage"]))
	_check("test_burn_hit_still_ignites_every_cell", r["burning"] == true and fx.burning_cells().size() == 2)

	# Miss: ignites, no damage.
	var st2: CombatState = _state()
	var fx2 := StatusEffects.new()
	var away: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 2)]
	r = CutEffects.apply(st2, grid, CombatState.Side.ENEMY, away, "hoa_xa", cc, sc, fx2)
	_check("test_burn_miss_ignites_without_damage", r["hit"] == false and fx2.burning_cells().size() == 2 and st2.player_hp == 1000.0)

	# A burn card with damage_per_cell 0 keeps the old rule.
	(sc.cards["hoa_xa"] as Dictionary)["damage_per_cell"] = 0.0
	var st3: CombatState = _state()
	var fx3 := StatusEffects.new()
	r = CutEffects.apply(st3, grid, CombatState.Side.ENEMY, two, "hoa_xa", cc, sc, fx3)
	_check("test_burn_without_impact_hits_for_zero", r["hit"] == true and float(r["damage"]) == 0.0 and st3.player_hp == 1000.0 and fx3.burning_cells().size() == 2)

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

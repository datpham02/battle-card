extends SceneTree
## 2026-11-05 Hunter balance (design/quick-specs/tho-san-gai-trung-2026-11-05.md): Bui ram (tran_gai), the Hunter's
## starter thorn card, now has damage_per_cell > 0, so a cast with the boss inside its cells hits for
## damage_per_cell x cells (the thorn card damage path, as gai_doc) and still lays the thorns. A miss lays the thorns
## and deals nothing.
## Run: godot --headless --path . -s res://tests/unit/combat/thorn_impact_test.gd

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const HP: float = 1000.0
const ZONES: Dictionary = {"seal_sec": 1.2, "thorn_sec": 3.0, "thorn_damage": 6.0, "thorn_fragile_stacks": 1}

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _state() -> CombatState:
	# The boss stands on (4, 1).
	return CombatState.new(BoardGrid.new(3, 3), HP, HP, Vector2i(1, 1), Vector2i(4, 1))


func _fx() -> StatusEffects:
	var fx: StatusEffects = StatusEffects.new()
	fx.configure_keywords(1.5, 3, 3, 24.0)
	return fx


func _init() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cc: CutConfig = CutConfig.new()
	var opts: Dictionary = {"zones": ZONES}
	var dpc: float = float(sc.get_skill("tran_gai").get("damage_per_cell", 0.0))
	_check("test_tran_gai_data_has_an_impact_damage", dpc > 0.0, "damage_per_cell %s" % dpc)

	# Hit: the boss is inside the 3 cells -> damage x 3 and thorns on the cells.
	var st: CombatState = _state()
	var fx: StatusEffects = _fx()
	var three: Array[Vector2i] = [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)]
	var r: Dictionary = CutEffects.apply(st, st.grid, P, three, "tran_gai", cc, sc, fx, Callable(), 1, Callable(), Callable(), opts)
	_check("test_tran_gai_hit_deals_damage_per_cell_times_cells", bool(r["hit"]) and is_equal_approx(float(r["damage"]), dpc * 3.0) and is_equal_approx(st.enemy_hp, HP - dpc * 3.0), "damage %s enemy_hp %s" % [r["damage"], st.enemy_hp])
	_check("test_tran_gai_hit_still_lays_thorns", not fx.thorn_cells(E).is_empty(), str(fx.thorn_cells(E)))

	# Miss: thorns, no damage.
	var st2: CombatState = _state()
	var fx2: StatusEffects = _fx()
	var away: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)]
	r = CutEffects.apply(st2, st2.grid, P, away, "tran_gai", cc, sc, fx2, Callable(), 1, Callable(), Callable(), opts)
	_check("test_tran_gai_miss_lays_thorns_without_damage", not bool(r["hit"]) and fx2.thorn_cells(E).size() == 3 and st2.enemy_hp == HP)

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

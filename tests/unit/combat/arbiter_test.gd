extends SceneTree

var fails: int = 0
var interrupts: Array = []
var resolves: Array = []


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func make() -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	var cc := CutConfig.new()
	var sc := SkillConfig.new()
	var pa := CutActor.new(cc, CombatState.Side.PLAYER)
	var ba := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, pa, ba, cc, sc)
	interrupts = []
	resolves = []
	arb.swing_interrupted.connect(func(s: int, _c: Array[Vector2i], _k: String) -> void: interrupts.append(s))
	arb.swing_resolved.connect(func(s: int, r: Dictionary) -> void: resolves.append([s, r]))
	return {"grid": grid, "state": state, "pa": pa, "ba": ba, "arb": arb, "cc": cc}


# 3 cells covering the given cell.
func cells_with(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [cell]
	out.append(cell + Vector2i(0, 1) if cell.y < 2 else cell + Vector2i(0, -1))
	out.append(cell + Vector2i(0, 2) if cell.y < 1 else cell + Vector2i(0, -2))
	return out


func run_case(first_player: bool, gap: float, step: float, p_hit: bool = true, b_hit: bool = true) -> Dictionary:
	var m: Dictionary = make()
	var st: CombatState = m["state"]
	var pc: Array[Vector2i] = cells_with(st.enemy_cell) if p_hit else [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)] as Array[Vector2i]
	var bc: Array[Vector2i] = cells_with(st.player_cell) if b_hit else [Vector2i(0, 0), Vector2i(0, 2), Vector2i(2, 0)] as Array[Vector2i]
	if p_hit == false:
		pc = [st.enemy_cell + Vector2i(0, 1), st.enemy_cell + Vector2i(0, -1), st.enemy_cell + Vector2i(1, 1)] as Array[Vector2i]
		if pc.has(st.enemy_cell):
			pass
	var first: CutActor = m["pa"] if first_player else m["ba"]
	var second: CutActor = m["ba"] if first_player else m["pa"]
	var f_cells: Array[Vector2i] = pc if first_player else bc
	var s_cells: Array[Vector2i] = bc if first_player else pc
	first.begin_swing(f_cells, "kiem_khi", first_player)
	var arb: SwingArbiter = m["arb"]
	if gap > 0.0:
		arb.tick(gap)
	second.begin_swing(s_cells, "kiem_khi", not first_player)
	var total: float = 5.0 if step >= 5.0 else 3.0
	var t: float = 0.0
	while t < total:
		arb.tick(step)
		t += step
	m["gap"] = gap
	return m


func _init() -> void:
	var cc := CutConfig.new()
	print("swing_duration(3)=", cc.swing_duration(3), " damage(3)=", cc.slash_damage(3))
	# (1) player first, boss 0.1 later
	var m: Dictionary = run_case(true, 0.1, 0.02)
	var st: CombatState = m["state"]
	check("1 boss swing cancelled, boss side interrupt", interrupts == [CombatState.Side.ENEMY])
	check("1 player took no damage", st.player_hp == 100.0)
	check("1 boss took 18", is_equal_approx(st.enemy_hp, 82.0))
	# (5) same with a huge tick
	m = run_case(true, 0.1, 5.0)
	st = m["state"]
	check("5 huge tick: same outcome (interrupt boss, no player dmg, boss -18)", interrupts == [CombatState.Side.ENEMY] and st.player_hp == 100.0 and is_equal_approx(st.enemy_hp, 82.0) and resolves.size() == 1)
	# (2) mirror
	m = run_case(false, 0.1, 0.02)
	st = m["state"]
	check("2 player swing cancelled, player took damage", interrupts == [CombatState.Side.PLAYER] and is_equal_approx(st.player_hp, 82.0) and st.enemy_hp == 100.0)
	m = run_case(false, 0.1, 5.0)
	st = m["state"]
	check("5b huge tick mirror", interrupts == [CombatState.Side.PLAYER] and is_equal_approx(st.player_hp, 82.0) and st.enemy_hp == 100.0)
	# (3) tie
	m = run_case(true, 0.0, 0.02)
	st = m["state"]
	check("3 tie: both resolve, none cancelled", interrupts.is_empty() and resolves.size() == 2 and is_equal_approx(st.player_hp, 82.0) and is_equal_approx(st.enemy_hp, 82.0))
	m = run_case(true, 0.0, 5.0)
	st = m["state"]
	check("3b tie huge tick", interrupts.is_empty() and resolves.size() == 2)
	# (4) first swing misses (player's swing avoids the boss cell)
	m = make()
	st = m["state"]
	var pa: CutActor = m["pa"]
	var ba: CutActor = m["ba"]
	var arb: SwingArbiter = m["arb"]
	var miss: Array[Vector2i] = [st.enemy_cell + Vector2i(0, 1), st.enemy_cell + Vector2i(0, -1)]
	pa.begin_swing(miss, "kiem_khi", true)
	arb.tick(0.05)
	ba.begin_swing(cells_with(st.player_cell), "kiem_khi", false)
	for i in 200:
		arb.tick(0.02)
	check("4 miss does not cancel; boss swing resolved and hit", interrupts.is_empty() and resolves.size() == 2 and not bool(resolves[0][1]["hit"]) and is_equal_approx(st.player_hp, 82.0))
	# (6) player dies mid-swing
	m = make()
	st = m["state"]
	pa = m["pa"]
	ba = m["ba"]
	arb = m["arb"]
	pa.begin_swing(cells_with(st.enemy_cell), "kiem_khi", true)
	ba.begin_swing(cells_with(st.player_cell), "kiem_khi", false)
	arb.tick(0.1)
	st.damage_player(1000.0)
	check("6 both cancelled on death", not pa.is_swinging() and not ba.is_swinging())
	var hp: float = st.enemy_hp
	arb.tick(5.0)
	check("6 no further effects", resolves.is_empty() and interrupts.is_empty() and st.enemy_hp == hp)
	print("FAILS: ", fails)
	quit(fails)

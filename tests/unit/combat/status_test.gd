extends SceneTree
var fails: int = 0
func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)
func mk() -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), 1000.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))
func _init() -> void:
	var cc: CutConfig = CutConfig.new()
	var sc: SkillConfig = SkillConfig.load_from_file()
	# 1 burn
	var st: CombatState = mk()
	var fx: StatusEffects = StatusEffects.new()
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 0), Vector2i(2, 2)]
	fx.ignite(cells, 3.0, 0.5, 2.0)
	ck("burn: is_burning", fx.is_burning(Vector2i(0, 0)) and fx.burning_cells().size() == 3)
	fx.tick(0.25, st)
	ck("burn: no dmg before tick", st.player_hp == 1000.0)
	fx.tick(0.25, st)
	ck("burn: 2 dmg at 0.5s", st.player_hp == 998.0)
	ck("burn: enemy untouched", st.enemy_hp == 1000.0)
	fx.tick(0.5, st)
	ck("burn: 4 dmg at 1.0s", st.player_hp == 996.0)
	fx.ignite(cells, 3.0, 0.5, 2.0)
	ck("burn: reignite resets", is_equal_approx(fx.get_burn_left(Vector2i(1, 1)), 3.0))
	var st2: CombatState = mk()
	fx.clear()
	fx.ignite(cells, 3.0, 0.5, 2.0)
	for i in 60:
		fx.tick(0.05, st2)
	ck("burn: 60 small ticks = 12 dmg (%s)" % (1000.0 - st2.player_hp), is_equal_approx(st2.player_hp, 988.0))
	ck("burn: burned out", fx.burning_cells().is_empty())
	var st3: CombatState = mk()
	fx.ignite(cells, 3.0, 0.5, 2.0)
	fx.tick(3.0, st3)
	ck("burn: delta 3.0 = 12 dmg (%s)" % (1000.0 - st3.player_hp), is_equal_approx(st3.player_hp, 988.0) and fx.burning_cells().is_empty())
	var st4: CombatState = mk()
	fx.ignite([Vector2i(0, 0)] as Array[Vector2i], 3.0, 0.5, 2.0)
	fx.tick(3.0, st4)
	ck("burn: off-cell no dmg", st4.player_hp == 1000.0)
	# 2 pin
	var st5: CombatState = mk()
	var mv: UnitMover = UnitMover.new(st5, CombatState.Side.PLAYER, 0.45)
	mv.set_status(fx)
	fx.pin(CombatState.Side.PLAYER, 1.2)
	ck("pin: refuses", not mv.try_step(Vector2i(-1, 0)) and mv.get_cooldown_remaining() == 0.0 and st5.player_cell == Vector2i(1, 1))
	fx.tick(1.0, st5)
	fx.pin(CombatState.Side.PLAYER, 1.2)
	fx.tick(0.5, st5)
	ck("pin: refreshed still pinned", fx.is_pinned(CombatState.Side.PLAYER) and not mv.try_step(Vector2i(-1, 0)))
	fx.tick(0.8, st5)
	ck("pin: ends", not fx.is_pinned(CombatState.Side.PLAYER) and mv.try_step(Vector2i(-1, 0)))
	var mv2: UnitMover = UnitMover.new(mk(), CombatState.Side.PLAYER, 0.45)
	ck("pin: no status unchanged", mv2.try_step(Vector2i(1, 0)))
	# 3 drops
	var grid: BoardGrid = BoardGrid.new(3, 3)
	var cfgd: FieldDropsConfig = FieldDropsConfig.new()
	cfgd.spawn_interval_sec = 0.01
	cfgd.initial_delay_sec = 0.0
	cfgd.freshness_sec = 0.02
	var fd: FieldDrops = FieldDrops.new(cfgd, grid.player_cells(), grid.perimeter_labels(), 7)
	var blocked: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	fd.set_blocked_cells(blocked)
	var bad: bool = false
	var spawned: int = 0
	for i in 500:
		fd.tick(0.02, Vector2i(2, 0), 1)
		for p: FieldPoint in fd.get_points():
			spawned += 1
			if blocked.has(p.cell):
				bad = true
	ck("drops: 500 ticks no blocked spawn (seen %d)" % spawned, not bad and spawned > 0)
	var fd2: FieldDrops = FieldDrops.new(FieldDropsConfig.new(), grid.player_cells(), grid.perimeter_labels(), 1)
	fd2.debug_place("A1", Vector2i(0, 0), 5.0)
	fd2.debug_place("A2", Vector2i(1, 0), 5.0)
	fd2.set_blocked_cells([Vector2i(0, 0)] as Array[Vector2i])
	var sig: Array = [0]
	fd2.pickup_blocked.connect(func(_p: FieldPoint) -> void: sig[0] += 1)
	ck("drops: blocked pick null, no signal", fd2.pick_up_at(Vector2i(0, 0), true) == null and sig[0] == 0)
	ck("drops: blocked full hand no signal", fd2.pick_up_at(Vector2i(0, 0), false) == null and sig[0] == 0)
	ck("drops: unblocked works", fd2.pick_up_at(Vector2i(1, 0), true) != null)
	# 4 effects
	var nine: Array[Vector2i] = []
	for x in 3:
		for y in 3:
			nine.append(Vector2i(x, y))
	var sa: CombatState = mk()
	var fa: StatusEffects = StatusEffects.new()
	var r: Dictionary = CutEffects.apply(sa, grid, CombatState.Side.ENEMY, nine, "hoa_tran", cc, sc, fa)
	ck("fx: burn 9 ignite, inside hit, dmg 0", fa.burning_cells().size() == 9 and r["hit"] == true and r["damage"] == 0.0 and r["burning"] == true and sa.player_hp == 1000.0)
	var fb: StatusEffects = StatusEffects.new()
	var sb: CombatState = mk()
	sb.set_player_cell(Vector2i(1, 1))
	var six: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	r = CutEffects.apply(sb, grid, CombatState.Side.ENEMY, six, "hoa_tran", cc, sc, fb)
	ck("fx: burn outside ignites, hit false", fb.burning_cells().size() == 6 and r["hit"] == false)
	r = CutEffects.apply(sb, grid, CombatState.Side.ENEMY, nine, "bang_phong", cc, sc, fb)
	ck("fx: pin inside", r["pinned"] == true and r["hit"] == true and fb.is_pinned(CombatState.Side.PLAYER) and sb.player_hp == 1000.0)
	var fc: StatusEffects = StatusEffects.new()
	r = CutEffects.apply(sb, grid, CombatState.Side.ENEMY, six, "bang_phong", cc, sc, fc)
	ck("fx: pin outside", r["pinned"] == false and r["hit"] == false and not fc.is_pinned(CombatState.Side.PLAYER))
	var sd: CombatState = mk()
	var three: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	r = CutEffects.apply(sd, grid, CombatState.Side.ENEMY, three, "kiem_khi", cc, sc)
	ck("fx: slash 3 cells 18", r["damage"] == 18.0 and r["hit"] == true and r["burning"] == false)
	var five: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 0), Vector2i(0, 1)]
	var se: CombatState = mk()
	r = CutEffects.apply(se, grid, CombatState.Side.ENEMY, five, "chan_phong", cc, sc)
	ck("fx: push 5 cells 20 pushed", r["damage"] == 20.0 and r["pushed"] == true)
	r = CutEffects.apply(mk(), grid, CombatState.Side.ENEMY, nine, "hoa_tran", cc, sc)
	ck("fx: null status burn no crash", r["burning"] == false)
	r = CutEffects.apply(mk(), grid, CombatState.Side.ENEMY, nine, "bang_phong", cc, sc)
	ck("fx: null status pin no crash", r["pinned"] == false)
	# 5 availability
	var cd: SkillCooldowns = SkillCooldowns.new()
	var a: Dictionary = SkillAvailability.check(sc, cd, "hoa_tran", 4)
	ck("avail: burn 4 cells", a["reason"] == "need_cells" and a["need_cells"] == 5)
	ck("avail: burn 5", SkillAvailability.check(sc, cd, "hoa_tran", 5)["available"] == true)
	ck("avail: pin 6", SkillAvailability.check(sc, cd, "bang_phong", 6)["need_cells"] == 7 and not SkillAvailability.check(sc, cd, "bang_phong", 6)["available"])
	ck("avail: pin 7", SkillAvailability.check(sc, cd, "bang_phong", 7)["available"] == true)
	print("FAILS=%d" % fails)
	quit(fails)

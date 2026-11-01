extends SceneTree
## Story 027 zones: Tran gai (thorns) in StatusEffects, the ZoneRules leave-a-path rule, UnitMover blocker
## composition and the CutEffects thorns dispatch. The Wall cards and the player seal zone were deleted 2026-11-01
## (ADR-0001 Phase 1); the boss's drop tiles (ZoneRules.cast_drop) stand in where a blocking zone is needed.
## Deterministic, headless. Run: godot --headless --path . -s res://tests/unit/combat/zone_test.gd

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
# Zone numbers used by the tests (the shipped combat.json values are checked separately).
const HOLE_SEC: float = 1.2
const THORN_SEC: float = 3.0
const THORN_DAMAGE: float = 6.0
const ZONES: Dictionary = {"seal_sec": HOLE_SEC, "thorn_sec": THORN_SEC, "thorn_damage": THORN_DAMAGE, "thorn_fragile_stacks": 1}
const HP: float = 1000.0

var fails: int = 0


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func mk() -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), HP, HP, Vector2i(1, 1), Vector2i(4, 1))


func fx_new() -> StatusEffects:
	var fx: StatusEffects = StatusEffects.new()
	fx.configure_keywords(1.5, 3, 3, 24.0)
	return fx


func mover(st: CombatState, side: int, fx: StatusEffects) -> UnitMover:
	var mv: UnitMover = UnitMover.new(st, side, 0.0)
	mv.set_status(fx)
	var s: int = side
	mv.add_blocker(func(cell: Vector2i) -> bool: return fx.is_hole(s, cell))
	return mv


func cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in list:
		out.append(c as Vector2i)
	return out

# Opens a drop-tile hole at once (no crack warning) on [param list] of [param side]'s half.
func open_hole(fx: StatusEffects, st: CombatState, side: int, list: Array) -> void:
	fx.apply_drop(side, cells(list), 0.0, HOLE_SEC)
	fx.tick(0.0001, st)


func _init() -> void:
	_thorn_tests()
	_fit_tests()
	_dispatch_tests()
	_composition_and_refresh_tests()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _thorn_tests() -> void:
	var st: CombatState = mk()
	var fx: StatusEffects = fx_new()
	var mv: UnitMover = mover(st, P, fx)
	var entered: Array = []
	fx.thorn_entered.connect(func(side: int, cell: Vector2i, dmg: float) -> void: entered.append([side, cell, dmg]))
	fx.tick(0.0, st)
	fx.apply_thorns(P, cells([Vector2i(0, 1), Vector2i(1, 1)]), THORN_SEC, THORN_DAMAGE, 1)
	fx.tick(0.1, st)
	ck("thorns: standing when formed does not trigger", st.player_hp == HP and fx.fragile_stacks(P) == 0)
	ck("thorns: steppable", mv.try_step(Vector2i(-1, 0)))
	fx.tick(0.1, st)
	ck("thorns: entry hurts (%s)" % st.player_hp, st.player_hp == HP - THORN_DAMAGE and fx.fragile_stacks(P) == 1)
	fx.tick(0.1, st)
	ck("thorns: standing still no extra", st.player_hp == HP - THORN_DAMAGE)
	mv.try_step(Vector2i(0, -1))
	fx.tick(0.1, st)
	ck("thorns: leaving is free", st.player_hp == HP - THORN_DAMAGE)
	mv.try_step(Vector2i(0, 1))
	fx.tick(0.1, st)
	ck("thorns: re-entry hurts again", st.player_hp == HP - 2.0 * THORN_DAMAGE and fx.fragile_stacks(P) == 2)
	mv.try_step(Vector2i(1, 0))
	fx.tick(0.1, st)
	ck("thorns: thorn-to-thorn step counts", st.player_hp == HP - 3.0 * THORN_DAMAGE and entered.size() == 3)
	ck("thorns: thorns_at", int(fx.thorns_at(P, Vector2i(0, 1)).get("fragile_stacks", -1)) == 1 and fx.thorns_at(E, Vector2i(0, 1)).is_empty())
	var expired: Array = []
	fx.zone_expired.connect(func(kind: String, side: int, cell: Vector2i) -> void: expired.append([kind, side, cell]))
	fx.tick(THORN_SEC, st)
	ck("thorns: expire", fx.thorn_cells(P).is_empty() and fx.thorn_left(P, Vector2i(0, 1)) == 0.0)
	ck("thorns: zone_expired per cell (%d)" % expired.size(), expired.size() == 2 and str(expired[0][0]) == "thorns")
	# Entry by push (CutEffects chan_phong pushes the boss one cell away from the divider).
	var st2: CombatState = mk()
	var fx2: StatusEffects = fx_new()
	var sc: SkillConfig = SkillConfig.load_from_file()
	fx2.tick(0.0, st2)
	fx2.apply_thorns(E, cells([Vector2i(5, 1)]), THORN_SEC, THORN_DAMAGE, 1)
	var res: Dictionary = CutEffects.apply(st2, st2.grid, P, cells([Vector2i(4, 1)]), "chan_phong", CutConfig.new(), sc, fx2)
	var after_hit: float = st2.enemy_hp
	fx2.tick(0.05, st2)
	ck("thorns: push entry hurts", bool(res["pushed"]) and st2.enemy_cell == Vector2i(5, 1) and st2.enemy_hp == after_hit - THORN_DAMAGE and fx2.fragile_stacks(E) == 1)
	# Entry by teleport.
	fx2.apply_thorns(E, cells([Vector2i(3, 0)]), THORN_SEC, THORN_DAMAGE, 0)
	st2.set_enemy_cell(Vector2i(3, 0))
	var before: float = st2.enemy_hp
	fx2.tick(0.05, st2)
	ck("thorns: teleport entry hurts", st2.enemy_hp == before - THORN_DAMAGE)


func _fit_tests() -> void:
	var grid: BoardGrid = BoardGrid.new(3, 3)
	var none: Callable = Callable()
	# Corner (0,0): neighbours (1,0) and (0,1); zone covers both -> exactly one dropped.
	var corner: Array[Vector2i] = ZoneRules.fit_cells(grid, P, Vector2i(0, 0), cells([Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]), none)
	ck("fit: corner drops one neighbour (%s)" % str(corner), corner.size() == 2 and corner.has(Vector2i(1, 1)) and not (corner.has(Vector2i(1, 0)) and corner.has(Vector2i(0, 1))))
	ck("fit: deterministic", corner == ZoneRules.fit_cells(grid, P, Vector2i(0, 0), cells([Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]), none))
	# Cracked on three sides: the only open neighbour is dropped, the rest kept.
	var cracked: Array[Vector2i] = cells([Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 1)])
	var crack_fn: Callable = func(c: Vector2i) -> bool: return cracked.has(c)
	var around: Array[Vector2i] = ZoneRules.fit_cells(grid, P, Vector2i(1, 1), cells([Vector2i(0, 1), Vector2i(0, 0)]), crack_fn)
	ck("fit: cracked surround keeps the last exit (%s)" % str(around), around == cells([Vector2i(0, 0)]))
	# Already no open neighbour: zone unchanged (cannot make it worse).
	var all4: Array[Vector2i] = cells([Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 1), Vector2i(0, 1)])
	var all_fn: Callable = func(c: Vector2i) -> bool: return all4.has(c)
	ck("fit: already stuck unchanged", ZoneRules.fit_cells(grid, P, Vector2i(1, 1), cells([Vector2i(0, 0)]), all_fn).size() == 1)
	# Keep-max: a zone that leaves an exit is kept whole (duplicates removed).
	var whole: Array[Vector2i] = ZoneRules.fit_cells(grid, P, Vector2i(1, 1), cells([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 0)]), none)
	ck("fit: keep-max whole zone", whole == cells([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 0)]))
	# Centre fully surrounded by the zone: 4 neighbours -> 3 kept, the standing cell kept.
	var ring: Array[Vector2i] = ZoneRules.fit_cells(grid, P, Vector2i(1, 1), cells([Vector2i(1, 1), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]), none)
	ck("fit: ring keeps max (%d)" % ring.size(), ring.size() == 4 and ring.has(Vector2i(1, 1)))
	# Boss half corner (5,0): neighbours (4,0), (5,1).
	var boss: Array[Vector2i] = ZoneRules.fit_cells(grid, E, Vector2i(5, 0), cells([Vector2i(4, 0), Vector2i(5, 1)]), none)
	ck("fit: boss corner keeps one exit", boss.size() == 1)
	# Existing holes and cracks count as blocked through cast_drop (unit at (0,0), (1,0) already a hole).
	var st: CombatState = CombatState.new(grid, HP, HP, Vector2i(0, 0), Vector2i(4, 1))
	var fx: StatusEffects = fx_new()
	open_hole(fx, st, P, [Vector2i(1, 0)])
	var kept: Array[Vector2i] = ZoneRules.cast_drop(st, grid, fx, P, cells([Vector2i(0, 1)]), 0.8, HOLE_SEC, false)
	ck("fit: cast_drop sees existing holes", fx.is_hole(P, Vector2i(1, 0)) and kept.is_empty() and not fx.is_cracking(P, Vector2i(0, 1)))


func _dispatch_tests() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cc: CutConfig = CutConfig.new()
	var opts: Dictionary = {"zones": ZONES}
	ck("cards: the 2 thorn zone cards implemented, Wall cards gone", sc.has_skill("tran_gai") and sc.has_skill("gai_nguyen") and bool(sc.get_skill("tran_gai")["implemented"]) and not sc.has_skill("ket_gioi") and not sc.has_skill("long_an") and not sc.has_skill("luoi_san"))
	# Thorns cards (hit or miss), Gai nguyen carries 2 Ran per entry.
	var st3: CombatState = mk()
	var fx3: StatusEffects = fx_new()
	var tg: Dictionary = CutEffects.apply(st3, st3.grid, P, cells([Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)]), "tran_gai", cc, sc, fx3, Callable(), 1, Callable(), Callable(), opts)
	ck("dispatch: thorns on miss", not bool(tg["hit"]) and fx3.thorn_cells(E).size() == 3 and float(fx3.thorns_at(E, Vector2i(5, 1))["damage"]) == THORN_DAMAGE)
	CutEffects.apply(st3, st3.grid, P, cells([Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 0)]), "gai_nguyen", cc, sc, fx3, Callable(), 1, Callable(), Callable(), opts)
	ck("dispatch: gai_nguyen 2 Ran per entry", int(fx3.thorns_at(E, Vector2i(3, 1))["fragile_stacks"]) == 2 and int(fx3.thorns_at(E, Vector2i(5, 1))["fragile_stacks"]) == 1)
	# Boss swing places its zone on the PLAYER's half.
	var bs: Dictionary = CutEffects.apply(st3, st3.grid, E, cells([Vector2i(0, 0)]), "tran_gai", cc, sc, fx3, Callable(), 1, Callable(), Callable(), opts)
	ck("dispatch: boss zone on player half", fx3.thorn_cells(P).has(Vector2i(0, 0)) and not bool(bs["hit"]))
	# Shipped numbers (zones.seal_sec is now the drop-tile hole duration).
	var cfg: CombatConfig = CombatConfig.load_from_file()
	ck("config: zones block", cfg.seal_sec == 1.2 and cfg.thorn_sec == 3.0 and cfg.thorn_damage == 6.0 and cfg.thorn_fragile_stacks == 1)
	var bad: CombatConfig = CombatConfig.from_dictionary({"zones": {"seal_sec": -1}})
	ck("config: invalid zones fall back", bad.seal_sec == 1.2)


func _composition_and_refresh_tests() -> void:
	var st: CombatState = mk()
	var fx: StatusEffects = fx_new()
	var mv: UnitMover = mover(st, P, fx)
	var crack: CrackField = CrackField.new()
	crack.announce(cells([Vector2i(0, 1)]), 0.0, 2.0)
	crack.tick(0.01)
	# slam installs its crack test by assigning blocked_cell_fn AFTER the hole blocker was added.
	mv.blocked_cell_fn = Callable(crack, "is_cracked")
	open_hole(fx, st, P, [Vector2i(1, 0)])
	ck("compose: crack blocks", crack.is_cracked(Vector2i(0, 1)) and not mv.try_step(Vector2i(-1, 0)))
	ck("compose: hole blocks with slam installed", fx.is_hole(P, Vector2i(1, 0)) and not mv.try_step(Vector2i(0, -1)))
	mv.blocked_cell_fn = Callable()
	ck("compose: hole blocker survives slam teardown", not mv.try_step(Vector2i(0, -1)) and mv.try_step(Vector2i(-1, 0)))
	# Refresh of a re-applied thorn cell.
	var fx2: StatusEffects = fx_new()
	var st2: CombatState = mk()
	var applied: Array = []
	fx2.zone_applied.connect(func(kind: String, side: int, c: Array[Vector2i]) -> void: applied.append(kind))
	fx2.apply_thorns(P, cells([Vector2i(0, 2)]), THORN_SEC, THORN_DAMAGE, 1)
	fx2.tick(1.0, st2)
	fx2.apply_thorns(P, cells([Vector2i(0, 2)]), THORN_SEC, 9.0, 2)
	var t: Dictionary = fx2.thorns_at(P, Vector2i(0, 2))
	ck("refresh: thorns time and numbers", is_equal_approx(float(t["left"]), THORN_SEC) and float(t["damage"]) == 9.0 and int(t["fragile_stacks"]) == 2)
	ck("refresh: zone_applied each time", applied == ["thorns", "thorns"])
	open_hole(fx2, st2, P, [Vector2i(0, 0)])
	fx2.clear_zones(P)
	ck("clear_zones", fx2.thorn_cells(P).is_empty() and fx2.hole_cells(P).is_empty())

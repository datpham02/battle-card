extends SceneTree
# Story 020 part 1b: Ghim, Dot stacking, level at cast.
var fails: int = 0
func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)

class LvSkills extends SkillConfig:
	func resolved(id: String, level: int = 1) -> Dictionary:
		var d: Dictionary = (get_skill(id) as Dictionary).duplicate(true)
		d["damage_per_cell"] = float(d.get("damage_per_cell", 6.0)) + float(level - 1)
		return d

func mk() -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), 1000.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))

func _init() -> void:
	var cc: CutConfig = CutConfig.new()
	var grid: BoardGrid = BoardGrid.new(3, 3)
	var sc: LvSkills = LvSkills.new()
	sc.cards["sw"] = (sc.get_skill("kiem_khi") as Dictionary).duplicate(true)
	sc.cards["sw"]["damage_per_cell"] = 7.0
	sc.cards["sw"].erase("damage_multiplier")
	var hit: Array[Vector2i] = [Vector2i(4, 1), Vector2i(4, 0)]
	var E: int = CombatState.Side.ENEMY
	var P: int = CombatState.Side.PLAYER
	# config
	var cfg: CombatConfig = CombatConfig.load_from_file()
	ck("cfg keys (Story 023: Ghim mult 1.0)", cfg.pinned_damage_mult == 1.0 and cfg.burn_stack_extend_sec == 2.0 and cfg.burn_stack_tick_bonus == 1.0 and cfg.burn_max_stacks == 3)
	var bad: CombatConfig = CombatConfig.from_dictionary({"pinned_damage_mult": 0.5, "burn_max_stacks": 0})
	ck("cfg invalid -> fallbacks", bad.pinned_damage_mult == 1.0 and bad.burn_max_stacks == 3)
	# old positional call (8 args), no status
	var s0: CombatState = mk()
	var r0: Dictionary = CutEffects.apply(s0, grid, P, hit, "sw", cc, sc, null)
	ck("per-card damage 7*2 (%s)" % r0["damage"], is_equal_approx(float(r0["damage"]), 14.0) and not bool(r0["pin_bonus"]))
	var r0b: Dictionary = CutEffects.apply(mk(), grid, P, hit, "kiem_khi", cc, sc)
	ck("5-arg call compiles", bool(r0b["hit"]))
	# Ghim
	var fx: StatusEffects = StatusEffects.new()
	cfg.configure_status(fx)
	var s1: CombatState = mk()
	var r1: Dictionary = CutEffects.apply(s1, grid, P, hit, "sw", cc, sc, fx)
	ck("not pinned: x1", is_equal_approx(float(r1["damage"]), 14.0) and not bool(r1["pin_bonus"]))
	fx.pin(E, 1.0)
	var r2: Dictionary = CutEffects.apply(s1, grid, P, hit, "sw", cc, sc, fx)
	ck("pinned: Ghim is control only (Story 023) x1 = 14", is_equal_approx(float(r2["damage"]), 14.0) and not bool(r2["pin_bonus"]))
	var fx15: StatusEffects = StatusEffects.new()
	fx15.configure(2.0, 1.0, 3, 1.5)
	fx15.pin(E, 1.0)
	var r2b: Dictionary = CutEffects.apply(mk(), grid, P, hit, "sw", cc, sc, fx15)
	ck("Ghim code path kept: configured 1.5 -> 21 + pin_bonus", is_equal_approx(float(r2b["damage"]), 21.0) and bool(r2b["pin_bonus"]))
	var mod := func(_c: int, d: float) -> float: return d + 3.0
	var r3: Dictionary = CutEffects.apply(s1, grid, P, hit, "sw", cc, sc, fx, mod)
	ck("order card->ghim(x1)->passive = 17 (%s)" % r3["damage"], is_equal_approx(float(r3["damage"]), 17.0))
	fx.tick(1.1, s1)
	var r4: Dictionary = CutEffects.apply(s1, grid, P, hit, "sw", cc, sc, fx)
	ck("after expiry x1", is_equal_approx(float(r4["damage"]), 14.0) and not bool(r4["pin_bonus"]))
	ck("hp accounting", is_equal_approx(s1.enemy_hp, 1000.0 - 14.0 - 14.0 - 17.0 - 14.0))
	var fx0: StatusEffects = StatusEffects.new()
	fx0.pin(E, 1.0)
	var r5: Dictionary = CutEffects.apply(mk(), grid, P, hit, "sw", cc, sc, fx0)
	ck("unconfigured status: no Ghim", is_equal_approx(float(r5["damage"]), 14.0))
	# levels
	var r6: Dictionary = CutEffects.apply(mk(), grid, P, hit, "sw", cc, sc, null, Callable(), 2)
	ck("level 2 damage 8*2 (%s)" % r6["damage"], is_equal_approx(float(r6["damage"]), 16.0))
	# Dot stacking
	var b: StatusEffects = StatusEffects.new()
	cfg.configure_status(b)
	var c: Array[Vector2i] = [Vector2i(4, 1)]
	b.ignite(c, 3.0, 0.5, 2.0)
	ck("1st: stacks 1, left 3", b.stacks_at(c[0]) == 1 and is_equal_approx(b.get_burn_left(c[0]), 3.0))
	b.ignite(c, 3.0, 0.5, 2.0)
	ck("2nd: stacks 2, left 5, dmg 3", b.stacks_at(c[0]) == 2 and is_equal_approx(b.get_burn_left(c[0]), 5.0))
	var sb: CombatState = mk()
	b.tick(0.5, sb)
	ck("2nd tick dmg 3 (%s)" % (1000.0 - sb.enemy_hp), is_equal_approx(sb.enemy_hp, 997.0))
	b.ignite(c, 3.0, 0.5, 2.0)
	ck("3rd: stacks 3", b.stacks_at(c[0]) == 3)
	b.ignite(c, 3.0, 0.5, 2.0)
	ck("4th: stays 3", b.stacks_at(c[0]) == 3 and b.max_stacks_on(c) == 3)
	var sb2: CombatState = mk()
	var b2: StatusEffects = StatusEffects.new()
	cfg.configure_status(b2)
	b2.ignite(c, 3.0, 0.5, 2.0)
	b2.ignite(c, 3.0, 0.5, 2.0)
	b2.ignite(c, 3.0, 0.5, 2.0)
	b2.tick(0.5, sb2)
	ck("3 stacks dmg 2+1*2=4 (flat per stack) (%s)" % (1000.0 - sb2.enemy_hp), is_equal_approx(sb2.enemy_hp, 996.0))
	var m: Array[Vector2i] = [Vector2i(4, 1), Vector2i(4, 2)]
	var b3: StatusEffects = StatusEffects.new()
	cfg.configure_status(b3)
	b3.ignite(c, 3.0, 0.5, 2.0)
	b3.ignite(c, 3.0, 0.5, 2.0)
	b3.ignite([Vector2i(4, 2)] as Array[Vector2i], 3.0, 0.5, 2.0)
	ck("max_stacks_on mixed", b3.max_stacks_on(m) == 2 and b3.stacks_at(Vector2i(4, 2)) == 1 and b3.stacks_at(Vector2i(0, 0)) == 0)
	b3.tick(20.0, mk())
	ck("burn-out clears stacks", b3.stacks_at(c[0]) == 0 and b3.max_stacks_on(m) == 0)
	# unconfigured = old reset
	var o: StatusEffects = StatusEffects.new()
	o.ignite(c, 3.0, 0.5, 2.0)
	o.tick(1.0, mk())
	o.ignite(c, 3.0, 0.5, 2.0)
	ck("unconfigured reignite resets to 3, stacks 1", is_equal_approx(o.get_burn_left(c[0]), 3.0) and o.stacks_at(c[0]) == 1)
	# CutActor level + arbiter
	var pa := CutActor.new(cc, P)
	var ba := CutActor.new(cc, E)
	var st: CombatState = mk()
	var arb := SwingArbiter.new(st, grid, pa, ba, cc, sc, fx0)
	var got: Array = []
	arb.swing_resolved.connect(func(_s: int, r: Dictionary) -> void: got.append(r))
	ck("begin_swing default level", pa.begin_swing(hit, "sw", true) and pa.get_level() == 1)
	arb.tick(5.0)
	pa.begin_swing(hit, "sw", true, 3)
	ck("level stored", pa.get_level() == 3)
	arb.tick(5.0)
	ck("arbiter level plumbing", got.size() == 2 and int(got[0]["level"]) == 1 and int(got[1]["level"]) == 3 and is_equal_approx(float(got[1]["damage"]), 18.0))
	print("FAILS=%d" % fails)
	quit()

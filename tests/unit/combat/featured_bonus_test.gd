extends SceneTree
## Story 028 Part B/C: the featured-shape bonus. CutEffects: x damage_mult between Ran and execute
## (hand-computed full order), the effect applied once on a hit, nothing on a miss, never for the boss.
## SwingArbiter + CutActor carrier: one-shot, dropped when the swing is interrupted, boss never.
## Headless; FAILS=N.

var fails: int = 0
var P: int = CombatState.Side.PLAYER
var E: int = CombatState.Side.ENEMY
var cc: CutConfig
var sc: SkillConfig
var grid: BoardGrid
# Boss stands on (4, 1); the player on (1, 1).
var hit: Array[Vector2i] = [Vector2i(4, 1), Vector2i(4, 0)]
var miss: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 2)]


func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)


func mk(enemy_hp: float = 1000.0) -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), 1000.0, enemy_hp, Vector2i(1, 1), Vector2i(4, 1))


func mk_status() -> StatusEffects:
	var status := StatusEffects.new()
	status.configure(0.0, 0.0, 3, 1.0)
	status.configure_keywords(1.5, 3, 3, 24.0)
	return status


func bonus(effect: String, stacks: int, sec: float) -> Dictionary:
	return {"damage_mult": 1.5, "effect": effect, "stacks": stacks, "sec": sec}


func apply(state: CombatState, status: StatusEffects, side: int, cells: Array[Vector2i], skill: String, b: Dictionary, modifier: Callable = Callable(), opts: Dictionary = {}) -> Dictionary:
	var options: Dictionary = opts.duplicate()
	options["featured_bonus"] = b
	return CutEffects.apply(state, grid, side, cells, skill, cc, sc, status, modifier, 1, Callable(), Callable(), options)


func _init() -> void:
	cc = CutConfig.new()
	grid = BoardGrid.new(3, 3)
	sc = SkillConfig.from_dictionary({"cards": {
		"sw": {"effect": "damage", "damage_per_cell": 7.0, "implemented": true, "upgrade": {}},
		"ex": {"effect": "damage", "damage_per_cell": 7.0, "execute_ratio": 0.5, "implemented": true, "upgrade": {}},
		"pinc": {"effect": "pin", "pin_duration_sec": 0.5, "implemented": true, "upgrade": {}},
	}})
	_test_damage_order()
	_test_effects_once()
	_test_miss_and_boss()
	_test_arbiter_carrier()
	print("FAILS=%d" % fails)
	quit(fails)


func _test_damage_order() -> void:
	var state: CombatState = mk()
	state.damage(E, 600.0) # 400 / 1000 <= execute 0.5
	var status: StatusEffects = mk_status()
	status.apply_fragile(E, 1)
	var plus_one: Callable = func(_cells: int, d: float) -> float: return d + 1.0
	# 7 x 2 cells = 14 -> Ran x1.5 = 21 -> featured x1.5 = 31.5 -> execute x2 = 63 -> passive +1 = 64 -> defense 4 = 60.
	# Featured after the passive would give 64.5 - 4; after defense 64 + ... ; the additive passive pins the order.
	var r: Dictionary = apply(state, status, P, hit, "ex", bonus("fragile", 1, 0.0), plus_one, {"target_defense": 4.0})
	ck("order: card -> Ran -> featured -> execute -> passive -> defense = 60 (got %s)" % r["damage"], is_equal_approx(float(r["damage"]), 60.0))
	ck("order: result flags featured, mult 1.5, executed, Ran hit", bool(r["featured"]) and is_equal_approx(float(r["featured_mult"]), 1.5) and bool(r["executed"]) and bool(r["fragile_hit"]))
	var plain: Dictionary = apply(mk(), mk_status(), P, hit, "sw", {})
	ck("no bonus: 14 damage, featured false", is_equal_approx(float(plain["damage"]), 14.0) and not bool(plain["featured"]))
	var only: Dictionary = apply(mk(), mk_status(), P, hit, "sw", bonus("frost", 1, 0.0))
	ck("bonus alone: 14 x 1.5 = 21", is_equal_approx(float(only["damage"]), 21.0))


func _test_effects_once() -> void:
	var status: StatusEffects = mk_status()
	var r: Dictionary = apply(mk(), status, P, hit, "sw", bonus("fragile", 2, 0.0))
	ck("fragile x2: boss has exactly 2 Ran stacks after the hit", status.fragile_stacks(E) == 2 and int(r["fragile_applied"]) == 2)
	status = mk_status()
	r = apply(mk(), status, P, hit, "sw", bonus("frost", 2, 0.0))
	ck("frost x2: boss has exactly 2 Han stacks", status.frost_stacks(E) == 2 and int(r["frost_applied"]) == 2 and str(r["featured_effect"]) == "frost")
	status = mk_status()
	r = apply(mk(), status, P, hit, "sw", bonus("pin", 0, 1.2))
	ck("pin 1.2 s: boss pinned for 1.2 s", status.is_pinned(E) and is_equal_approx(status.get_pin_left(E), 1.2) and bool(r["pinned"]))
	status = mk_status()
	r = apply(mk(), status, P, hit, "sw", bonus("burn", 1, 0.0))
	ck("burn x1: every cast cell burns with 1 stack", status.stacks_at(Vector2i(4, 1)) == 1 and status.stacks_at(Vector2i(4, 0)) == 1 and bool(r["burning"]))
	status = mk_status()
	r = apply(mk(), status, P, hit, "pinc", bonus("fragile", 1, 0.0))
	ck("control card hit: effect still applied once (Ran 1), no damage", status.fragile_stacks(E) == 1 and float(r["damage"]) == 0.0 and bool(r["featured"]))


func _test_miss_and_boss() -> void:
	var status: StatusEffects = mk_status()
	var state: CombatState = mk()
	var r: Dictionary = apply(state, status, P, miss, "sw", bonus("fragile", 2, 0.0))
	ck("miss: nothing applied (no damage, no Ran, featured false)", not bool(r["hit"]) and not bool(r["featured"]) and status.fragile_stacks(E) == 0 and is_equal_approx(state.enemy_hp, 1000.0))
	status = mk_status()
	r = apply(mk(), status, P, miss, "sw", bonus("pin", 0, 1.2))
	ck("miss: no pin", not status.is_pinned(E))
	status = mk_status()
	var boss_cells: Array[Vector2i] = [Vector2i(1, 1)]
	r = apply(mk(), status, E, boss_cells, "sw", bonus("fragile", 2, 0.0))
	ck("boss swing: never featured, unscaled 7, no Ran on the player", not bool(r["featured"]) and is_equal_approx(float(r["damage"]), 7.0) and status.fragile_stacks(P) == 0)


func _test_arbiter_carrier() -> void:
	var state: CombatState = mk()
	var status: StatusEffects = mk_status()
	var pa := CutActor.new(cc, P)
	var ba := CutActor.new(cc, E)
	var arb := SwingArbiter.new(state, grid, pa, ba, cc, sc, status)
	var got: Array = []
	arb.swing_resolved.connect(func(side: int, r: Dictionary) -> void: got.append([side, r]))
	pa.begin_swing(hit, "sw", true, 1, 0.5, bonus("fragile", 1, 0.0))
	ck("carrier: actor reports the bonus while swinging", str(pa.get_featured_bonus().get("effect", "")) == "fragile")
	arb.tick(1.0)
	var r: Dictionary = got[0][1] if got.size() == 1 else {}
	ck("carrier: featured hit through the arbiter = 21, Ran 1", bool(r.get("featured", false)) and is_equal_approx(float(r.get("damage", 0.0)), 21.0) and status.fragile_stacks(E) == 1)
	ck("carrier: consumed after resolve", pa.get_featured_bonus().is_empty())
	got.clear()
	pa.begin_swing(hit, "sw", true, 1, 0.5)
	arb.tick(1.0)
	r = got[0][1] if got.size() == 1 else {}
	ck("carrier: the next plain swing is not featured (one-shot); Ran x1.5 = 21", not bool(r.get("featured", true)) and is_equal_approx(float(r.get("damage", 0.0)), 21.0))
	# Interrupted: the boss hits first, the player's featured swing is cancelled and the bonus dropped.
	got.clear()
	var boss_cells: Array[Vector2i] = [Vector2i(1, 1)]
	pa.begin_swing(hit, "sw", true, 1, 1.0, bonus("frost", 2, 0.0))
	ba.begin_swing(boss_cells, "sw", false, 1, 0.2)
	arb.tick(0.3)
	ck("interrupt: the player's swing was cancelled and its bonus dropped", not pa.is_swinging() and pa.get_featured_bonus().is_empty())
	arb.tick(2.0)
	ck("interrupt: no frost was ever applied", status.frost_stacks(E) == 0)
	# Boss swing started with a bonus: the arbiter ignores it.
	got.clear()
	ba.begin_swing(boss_cells, "sw", false, 1, 0.2, bonus("fragile", 2, 0.0))
	arb.tick(0.5)
	r = got[0][1] if got.size() == 1 else {}
	ck("boss carrier: never featured, unscaled 7", got.size() == 1 and int(got[0][0]) == E and not bool(r.get("featured", true)) and is_equal_approx(float(r.get("damage", 0.0)), 7.0))

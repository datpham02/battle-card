extends SceneTree
## Multi-enemy Phase 2 (docs/design/world-map-v2/MULTI-ENEMY-PHASE2-PREFLIGHT.md 6.1 / 7): the resolvers act on the unit
## a cast covers. Decisions: (1) every covered unit takes the full hit once; (2) push / pull per unit by index, each
## step re-checking occupancy; (3) chained hits keep a hit book per unit; (4) Rạn / execute / mark per unit; (5) only a
## hit on unit 0 interrupts; (6) damage sums. One unit = the pre-Phase-2 behaviour.

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY  # = the key of unit 0
const K1: int = 2  # key of unit 1
const K2: int = 3  # key of unit 2

var fails: int = 0
var passes: int = 0
var _sc: SkillConfig
var _cc: CutConfig
var _resolves: Array = []
var _interrupts: Array = []


func check(ok: bool, label: String, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label, "  ", extra)


func _initialize() -> void:
	_sc = SkillConfig.load_from_file()
	_cc = CutConfig.load_from_file()
	_test_single_unit_unchanged()
	_test_multi_hit_damage_and_signals()
	_test_only_covered_units_and_interrupt()
	_test_fragile_execute_per_unit()
	_test_push_occupancy()
	_test_status_ticks_per_unit()
	_test_death_and_match_end()
	_test_scheduled_per_unit_books()
	_test_mark_per_unit()
	_test_detonation_once()
	_test_hazards_per_unit()
	_test_zone_rules_for_units()
	_test_footprint_2x2_with_helper()
	_test_pull_and_bounce()
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)


# A 4x3 board (enemy half cols 4..7) with unit 0 at [param c0] and further units at [param more].
func _state(c0: Vector2i, more: Array = [], hp: float = 100.0) -> CombatState:
	var s := CombatState.new(BoardGrid.new(4, 3), 200.0, hp, Vector2i(1, 1), c0)
	for c: Variant in more:
		s.add_unit("u", hp, [Vector2i.ZERO], c as Vector2i)
	return s


func _status() -> StatusEffects:
	var st := StatusEffects.new()
	CombatConfig.new().configure_status(st)
	return st


func _arb(s: CombatState, st: StatusEffects = null) -> Dictionary:
	var pa := CutActor.new(_cc, P)
	var ba := CutActor.new(_cc, E)
	var arb := SwingArbiter.new(s, s.grid, pa, ba, _cc, _sc, st)
	_resolves = []
	_interrupts = []
	arb.swing_resolved.connect(func(side: int, r: Dictionary) -> void: _resolves.append([side, r]))
	arb.swing_interrupted.connect(func(side: int, _c: Array[Vector2i], _k: String) -> void: _interrupts.append(side))
	return {"pa": pa, "ba": ba, "arb": arb}


# Casts [param skill] by the player on [param cells] and ticks until the cast resolved (instant or scheduled).
func _cast(m: Dictionary, cells: Array[Vector2i], skill: String, max_sec: float = 6.0) -> Dictionary:
	var before: int = _resolves.size()
	(m["pa"] as CutActor).begin_swing(cells, skill, true)
	var t: float = 0.0
	while t < max_sec and _resolves.size() == before:
		(m["arb"] as SwingArbiter).tick(0.05)
		t += 0.05
	# let a scheduled cast's later events land
	for i: int in 40:
		(m["arb"] as SwingArbiter).tick(0.05)
	for i: int in range(_resolves.size() - 1, before - 1, -1):
		if int(_resolves[i][0]) == P:
			return _resolves[i][1]
	return {}


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in list:
		out.append(c as Vector2i)
	return out


# --- A. One unit: the pre-Phase-2 path ------------------------------------------------------------------------------

func _test_single_unit_unchanged() -> void:
	var s: CombatState = _state(Vector2i(5, 1))
	check(CutEffects.target_keys(s, _sc.get_skill("kiem_khi"), P, _cells([Vector2i(4, 0)])) == ([E] as Array[int]), "A: one unit: target_keys = [unit 0] even on a miss")
	check(CutEffects.target_keys(s, {}, E, _cells([Vector2i(1, 1)])) == ([P] as Array[int]), "A: a boss swing targets the hero")
	var m: Dictionary = _arb(s)
	var r: Dictionary = _cast(m, _cells([Vector2i(5, 1), Vector2i(5, 0), Vector2i(5, 2)]), "kiem_khi")
	check(bool(r.get("hit", false)) and is_equal_approx(s.enemy_hp, 100.0 - float(r["damage"])) and float(r["damage"]) > 0.0, "A: one unit hit through the arbiter", str(r.get("damage")))
	check(not r.has("unit_results") and not r.has("unit_keys_hit") and not r.has("unit0_damage"), "A: a one-unit result carries no Phase 2 key (byte-for-byte legacy shape)")
	# the same cast resolved directly on a twin state gives the same damage
	var twin: CombatState = _state(Vector2i(5, 1))
	var direct: Dictionary = CutEffects.apply(twin, twin.grid, P, _cells([Vector2i(5, 1), Vector2i(5, 0), Vector2i(5, 2)]), "kiem_khi", _cc, _sc)
	check(is_equal_approx(float(direct["damage"]), float(r["damage"])) and direct["cell"] == r["cell"], "A: arbiter and a direct apply agree")
	check(CutEffects.hit_unit0({"hit": true}) and not CutEffects.hit_unit0({"hit": false}), "A: hit_unit0 on a legacy result = its hit")


# --- B. Several units: full hit once each, sum, signals ------------------------------------------------------------

func _test_multi_hit_damage_and_signals() -> void:
	var s: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0), Vector2i(6, 2)])
	var events: Array = []
	s.unit_damaged.connect(func(i: int, a: float) -> void: events.append(["unit", i, a]))
	s.damaged.connect(func(side: int, a: float) -> void: events.append(["legacy", side, a]))
	var m: Dictionary = _arb(s)
	var cells: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	var r: Dictionary = _cast(m, cells, "kiem_khi")
	var lost0: float = 100.0 - s.get_unit(0).hp
	var lost1: float = 100.0 - s.get_unit(1).hp
	check(lost0 > 0.0 and is_equal_approx(lost0, lost1), "B: both covered units lose the same full damage (%s / %s)" % [lost0, lost1])
	check(is_equal_approx(s.get_unit(2).hp, 100.0), "B: the uncovered unit 2 is untouched")
	var single: CombatState = _state(Vector2i(4, 1))
	var one: Dictionary = CutEffects.apply(single, single.grid, P, cells, "kiem_khi", _cc, _sc)
	check(is_equal_approx(lost0, float(one["damage"])), "B: each unit's loss equals the single-target damage (no split, no double)")
	check(is_equal_approx(float(r["damage"]), lost0 + lost1) and (r["unit_keys_hit"] as Array) == [E, K1] and is_equal_approx(float(r["unit0_damage"]), lost0), "B: merged result: damage sum, unit_keys_hit [1, 2], unit0_damage")
	check((r["unit_results"] as Array).size() == 2, "B: two per-unit results")
	var unit_ev: Array = events.filter(func(e: Array) -> bool: return e[0] == "unit")
	var legacy_ev: Array = events.filter(func(e: Array) -> bool: return e[0] == "legacy" and int(e[1]) == E)
	check(unit_ev.size() == 2 and int(unit_ev[0][1]) == 0 and int(unit_ev[1][1]) == 1, "B: unit_damaged once per unit, index order", str(unit_ev))
	check(legacy_ev.size() == 1 and is_equal_approx(float(legacy_ev[0][2]), lost0), "B: legacy damaged(ENEMY) once, unit 0's loss only", str(legacy_ev))


# --- C. Only covered units; interrupt on unit 0 only ----------------------------------------------------------------

func _test_only_covered_units_and_interrupt() -> void:
	var s: CombatState = _state(Vector2i(6, 1), [Vector2i(4, 0)])
	var m: Dictionary = _arb(s)
	(m["ba"] as CutActor).begin_swing(_cells([Vector2i(1, 1)]), "kiem_khi", false, 1, 5.0)
	var r: Dictionary = _cast(m, _cells([Vector2i(4, 0), Vector2i(5, 0)]), "kiem_khi", 2.0)
	check(bool(r.get("hit", false)) and is_equal_approx(s.enemy_hp, 100.0) and s.get_unit(1).hp < 100.0, "C: a cast covering only unit 1 leaves unit 0's HP")
	check(not CutEffects.hit_unit0(r) and (m["ba"] as CutActor).is_swinging() and _interrupts.is_empty(), "C: a hit on unit 1 does not interrupt unit 0's swing")
	var r2: Dictionary = _cast(m, _cells([Vector2i(6, 1), Vector2i(6, 0)]), "kiem_khi", 2.0)
	check(CutEffects.hit_unit0(r2) and _interrupts.has(E), "C: a hit on unit 0 interrupts its swing")


# --- D. Fragile and execute per unit ---------------------------------------------------------------------------------

func _test_fragile_execute_per_unit() -> void:
	var st: StatusEffects = _status()
	var s: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)])
	var m: Dictionary = _arb(s, st)
	_cast(m, _cells([Vector2i(4, 0)]), "ran_kich")
	check(st.fragile_stacks(K1) == 1 and st.fragile_stacks(E) == 0, "D: Rạn lands on unit 1 only")
	var cells: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(4, 1)])
	_cast(m, cells, "kiem_khi")
	var lost0: float = 100.0 - s.get_unit(0).hp
	var lost1: float = 100.0 - s.get_unit(1).hp
	check(lost1 > lost0 * 1.4 and st.fragile_stacks(K1) == 0, "D: unit 1 spends ITS Rạn (x mult), unit 0 takes the plain hit (%s vs %s)" % [lost1, lost0])
	# execute: unit 1 at 20 % HP, unit 0 full
	var s2: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)])
	s2.get_unit(1).hp = 20.0
	var m2: Dictionary = _arb(s2, _status())
	(m2["arb"] as SwingArbiter).execute_ratio = 0.25  # CombatView sets it from combat.json
	var r: Dictionary = _cast(m2, cells, "tu_kiem")
	var res: Array = r["unit_results"]
	var by_key: Dictionary = {}
	for e: Dictionary in res:
		by_key[int(e["key"])] = e
	check(bool((by_key[K1] as Dictionary)["executed"]) and not bool((by_key[E] as Dictionary)["executed"]), "D: execute reads each unit's own HP")


# --- E. Push: index order, occupancy re-checked each step -------------------------------------------------------------

func _test_push_occupancy() -> void:
	# unit 0 behind unit 1 in one row: unit 0 is stopped by unit 1, then unit 1 moves on
	var s: CombatState = _state(Vector2i(4, 1), [Vector2i(6, 1)])
	var m: Dictionary = _arb(s, _status())
	_cast(m, _cells([Vector2i(4, 1), Vector2i(6, 1)]), "xung_kich")
	check(s.get_unit(0).cell == Vector2i(5, 1) and s.get_unit(1).cell == Vector2i(7, 1), "E: unit 0 first: blocked by unit 1 after one step; unit 1 then pushed to the edge (%s, %s)" % [s.get_unit(0).cell, s.get_unit(1).cell])
	# the later unit's destination is held by the earlier unit's new cell
	var s2: CombatState = _state(Vector2i(6, 1), [Vector2i(5, 1)])
	var m2: Dictionary = _arb(s2, _status())
	_cast(m2, _cells([Vector2i(5, 1), Vector2i(6, 1)]), "xung_kich")
	check(s2.get_unit(0).cell == Vector2i(7, 1) and s2.get_unit(1).cell == Vector2i(6, 1), "E: unit 1 stops before the cell unit 0 just took (%s, %s)" % [s2.get_unit(0).cell, s2.get_unit(1).cell])
	check(s2.get_unit(0).cell != s2.get_unit(1).cell, "E: never two units on one cell")


# --- F. Status ticks per unit: burn, burn-heal (unit 0 trait), thorns ------------------------------------------------

func _test_status_ticks_per_unit() -> void:
	var st: StatusEffects = _status()
	var s: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)])
	st.ignite(_cells([Vector2i(4, 0)]), 3.0, 0.5, 2.0)
	st.tick(1.0, s)
	check(s.get_unit(1).hp < 100.0 and is_equal_approx(s.enemy_hp, 100.0), "F: a burning cell under unit 1 hurts unit 1 only")
	# burn_eater heals unit 0 (its trait), never unit 1
	var st2: StatusEffects = _status()
	st2.burn_heal_ratio_fn = func() -> float: return 1.0
	var s2: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)])
	s2.get_unit(0).hp = 50.0
	s2.get_unit(1).hp = 50.0
	st2.ignite(_cells([Vector2i(4, 0), Vector2i(4, 1)]), 3.0, 0.5, 2.0)
	st2.tick(1.0, s2)
	check(s2.get_unit(0).hp > 50.0 and s2.get_unit(1).hp < 50.0, "F: the burn-heal hook heals unit 0 and burns unit 1 (%s / %s)" % [s2.get_unit(0).hp, s2.get_unit(1).hp])
	# thorns: unit 1 steps in and pays, unit 0 does not
	var st3: StatusEffects = _status()
	var s3: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)])
	st3.tick(0.0, s3)
	st3.apply_thorns(E, _cells([Vector2i(5, 0)]), 3.0, 6.0, 1)
	s3.set_unit_cell(1, Vector2i(5, 0))
	st3.tick(0.1, s3)
	check(is_equal_approx(s3.get_unit(1).hp, 94.0) and st3.fragile_stacks(K1) == 1 and is_equal_approx(s3.enemy_hp, 100.0) and st3.fragile_stacks(E) == 0, "F: thorn toll + Rạn on unit 1 only")


# --- G. Unit death: occupancy freed, the match goes on until every required unit is dead ------------------------------

func _test_death_and_match_end() -> void:
	var s: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)], 5.0)  # one kiem_khi cell (6) kills
	var m: Dictionary = _arb(s)
	(m["ba"] as CutActor).begin_swing(_cells([Vector2i(1, 1)]), "kiem_khi", false, 1, 5.0)
	_cast(m, _cells([Vector2i(4, 1)]), "kiem_khi")
	check(s.is_unit_dead(0) and not s.all_required_dead() and not (m["ba"] as CutActor).is_swinging(), "G: unit 0 dead: its actor stops, the match goes on")
	check(s.set_unit_cell(1, Vector2i(4, 1)), "G: unit 0's cell is free once it died")
	var r: Dictionary = _cast(m, _cells([Vector2i(4, 1)]), "kiem_khi")
	check(bool(r.get("hit", false)) and s.is_unit_dead(1) and s.all_required_dead(), "G: unit 1 still takes hits; its death ends the fight")


# --- H. Scheduled casts: a hit book per unit (max hits, one per wave) ------------------------------------------------

func _test_scheduled_per_unit_books() -> void:
	for skill: String in ["ngan_kiem", "lien_tram", "song_dao"]:
		var cells: Array[Vector2i] = _cells([Vector2i(4, 0), Vector2i(4, 1), Vector2i(5, 0), Vector2i(5, 1)])
		var one: CombatState = _state(Vector2i(4, 1))
		var m1: Dictionary = _arb(one)
		_cast(m1, cells, skill)
		var solo: float = 100.0 - one.enemy_hp
		var two: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)])
		var m2: Dictionary = _arb(two)
		var r: Dictionary = _cast(m2, cells, skill)
		var lost0: float = 100.0 - two.get_unit(0).hp
		var lost1: float = 100.0 - two.get_unit(1).hp
		check(solo > 0.0 and is_equal_approx(lost0, solo) and is_equal_approx(lost1, solo), "H: %s: each unit takes exactly the one-unit damage (%s, %s vs %s)" % [skill, lost0, lost1, solo])
		check(is_equal_approx(float(r.get("damage", 0.0)), lost0 + lost1) and (r.get("unit_keys_hit", []) as Array) == [E, K1], "H: %s: the cast result sums both units" % skill)


# --- I. Death mark per unit ------------------------------------------------------------------------------------------

func _test_mark_per_unit() -> void:
	var st: StatusEffects = _status()
	var s: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)])
	var m: Dictionary = _arb(s, st)
	_cast(m, _cells([Vector2i(4, 0)]), "dau_tu")
	check(st.has_mark(K1) and not st.has_mark(E), "I: the mark lands on the unit hit (unit 1)")
	var before0: float = s.get_unit(0).hp
	var before1: float = s.get_unit(1).hp
	_cast(m, _cells([Vector2i(4, 0), Vector2i(4, 1)]), "kiem_khi")
	var lost0: float = before0 - s.get_unit(0).hp
	var lost1: float = before1 - s.get_unit(1).hp
	check(not st.has_mark(K1) and lost1 > lost0, "I: the marked unit spends its mark and takes the echo on top (%s vs %s)" % [lost1, lost0])


# --- J. Detonation: the blast happens once, each unit counts its own blown cells --------------------------------------

func _test_detonation_once() -> void:
	var st: StatusEffects = _status()
	var s: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)])
	st.apply_thorns(E, _cells([Vector2i(4, 0), Vector2i(4, 1)]), 9.0, 6.0, 0)
	var m: Dictionary = _arb(s, st)
	_cast(m, _cells([Vector2i(4, 0), Vector2i(4, 1)]), "gai_no")
	check(s.get_unit(0).hp < 100.0 and s.get_unit(1).hp < 100.0 and is_equal_approx(s.get_unit(0).hp, s.get_unit(1).hp), "J: both units under blown thorns take the same blast (%s, %s)" % [s.get_unit(0).hp, s.get_unit(1).hp])
	check(st.thorns_at(E, Vector2i(4, 0)).is_empty() and st.thorns_at(E, Vector2i(4, 1)).is_empty(), "J: the thorns were consumed once")


# --- K. Tile hazards: mire per unit (immunity is unit 0's match key) --------------------------------------------------

func _test_hazards_per_unit() -> void:
	var s: CombatState = _state(Vector2i(4, 1), [Vector2i(4, 0)])
	var hz: TileHazards = TileHazards.new(s.grid, 1)
	hz.configure({})
	hz.bind_state(s)
	var hits: Array = []
	hz.mire_damage.connect(func(key: int, a: float) -> void: hits.append(key))
	hz.set_mire(E, _cells([Vector2i(4, 0), Vector2i(4, 1)]))
	hz.set_mire_immune(E, true)
	for i: int in 40:
		hz.tick(0.1, s)
	check(hits.has(K1) and not hits.has(E), "K: mire ticks unit 1, unit 0 is immune (match key), keyed by unit", str(hits))
	check(hz.mire_standing_sec(K1) > 0.0 and is_equal_approx(hz.mire_standing_sec(E), 0.0), "K: standing timers are per unit")


# --- L. Leave-a-path for every unit ----------------------------------------------------------------------------------

func _test_zone_rules_for_units() -> void:
	var grid := BoardGrid.new(3, 3)
	var zone: Array[Vector2i] = _cells([Vector2i(3, 0), Vector2i(4, 1), Vector2i(3, 2), Vector2i(5, 0)])
	var single: Array[Vector2i] = ZoneRules.fit_cells(grid, E, Vector2i(3, 1), zone, Callable())
	check(ZoneRules.fit_cells_for(grid, E, _cells([Vector2i(3, 1)]), zone, Callable()) == single, "L: one standing unit = fit_cells")
	var both: Array[Vector2i] = ZoneRules.fit_cells_for(grid, E, _cells([Vector2i(3, 1), Vector2i(4, 0)]), zone, Callable())
	var exits_ok: bool = true
	for here: Vector2i in [Vector2i(3, 1), Vector2i(4, 0)]:
		var open: int = 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = here + d
			if grid.is_enemy_cell(n) and not both.has(n) and n != Vector2i(3, 1) and n != Vector2i(4, 0):
				open += 1
		exits_ok = exits_ok and open >= 1
	check(exits_ok, "L: every unit keeps one open neighbour", str(both))


# --- M. A 2x2 unit 0 with a 1-cell helper: footprint hits count once per unit ------------------------------------------

func _test_footprint_2x2_with_helper() -> void:
	var s := CombatState.new(BoardGrid.new(6, 4), 200.0, 300.0)
	s.set_enemy_footprint([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i])
	var helper: int = s.add_unit("h", 50.0, [Vector2i.ZERO], Vector2i(6, 0))
	check(helper == 1 and not s.enemy_footprint_cells().has(Vector2i(6, 0)), "M: helper beside the 2x2")
	var m: Dictionary = _arb(s)
	var cells: Array[Vector2i] = s.enemy_footprint_cells().duplicate()
	cells.append(Vector2i(6, 0))
	var r: Dictionary = _cast(m, cells, "kiem_khi")
	var lost0: float = 300.0 - s.get_unit(0).hp
	var lost1: float = 50.0 - s.get_unit(1).hp
	check(lost0 > 0.0 and lost1 > 0.0, "M: both the 2x2 and the helper are hit (%s, %s)" % [lost0, lost1])
	check(is_equal_approx(lost0, float((r["unit_results"] as Array)[0]["damage"])) and (r["unit_keys_hit"] as Array) == [E, K1], "M: the 2x2 is hit once (one result), the helper once")


# --- N. Pull (decision 2) and bounce (decision 3) ---------------------------------------------------------------------

func _test_pull_and_bounce() -> void:
	# loc_cuon pulls every unit inside or 4-adjacent to the mask toward its centre, index order, never onto another unit
	var s: CombatState = _state(Vector2i(4, 0), [Vector2i(4, 2)])
	var m: Dictionary = _arb(s, _status())
	var mask: Array[Vector2i] = _cells([Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)])
	check(CutEffects.target_keys(s, _sc.get_skill("loc_cuon"), P, mask) == ([E, K1] as Array[int]), "N: a pull card targets the units adjacent to the mask")
	_cast(m, mask, "loc_cuon")
	var c0: Vector2i = s.get_unit(0).cell
	var c1: Vector2i = s.get_unit(1).cell
	check(c0 != Vector2i(4, 0) and c1 != Vector2i(4, 2) and c0 != c1, "N: both adjacent units were pulled, onto different cells (%s, %s)" % [c0, c1])
	# phi_tieu: a dagger landing on an empty cell bounces to the mask cell a unit covers; the unit it lands on takes what
	# a single target would take, and a unit outside the mask takes nothing
	var mask2: Array[Vector2i] = _cells([Vector2i(5, 1), Vector2i(4, 1)])
	var solo: CombatState = _state(Vector2i(4, 1))
	_cast(_arb(solo), mask2, "phi_tieu")
	var solo_lost: float = 100.0 - solo.enemy_hp
	var multi: CombatState = _state(Vector2i(7, 0), [Vector2i(4, 1)])
	var r: Dictionary = _cast(_arb(multi), mask2, "phi_tieu")
	check(solo_lost > 0.0 and is_equal_approx(100.0 - multi.get_unit(1).hp, solo_lost), "N: bounce: unit 1 takes the single-target damage (%s vs %s)" % [100.0 - multi.get_unit(1).hp, solo_lost])
	check(is_equal_approx(multi.enemy_hp, 100.0) and not CutEffects.hit_unit0(r), "N: unit 0 outside the mask is untouched and not reported as hit")

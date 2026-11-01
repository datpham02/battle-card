extends SceneTree
## Drop tile (Ô rớt) rules, design/quick-specs/o-rot-thay-tuong-2026-10-31.md, ADR-0001 A5: the crack warning
## (start, duration from data, enterable), the fall timing (exactly at hole_warn_sec, hole for seal_sec, cell returns),
## collision (a unit on the cell at fall time drops to HP 0 = player_died; stepping off in time costs nothing; stepping
## onto a cracking cell; nobody enters a hole) and every no-reaction case (Frozen, rooted, step cooldown above the
## margin, no safe neighbour; Frozen / rooted mid-crack holds the fall until the unit leaves; Focus = time scale 0 stops
## the clock), the may_target_player_cell=false and hole_fall_lethal=false fallbacks, and no drop state without a cast.
## Pure logic: no file I/O (CombatConfig.new() / from_json_text carry the numbers), no randomness beyond a fixed seed.
## Run: godot --headless --path . -s res://tests/unit/combat/drop_tile_rules_test.gd

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.1
const HP: float = 100.0
const SEED: int = 11
## Fall damage of the non-lethal fallback fixture (the boundary value the assertion checks).
const FALL_DAMAGE: float = 8.0

var fails: int = 0
var cfg: CombatConfig = CombatConfig.new()


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_config_defaults_match_spec()
	test_config_invalid_values_keep_defaults()
	test_crack_starts_with_data_duration_and_is_enterable()
	test_fall_exactly_at_warn_then_hole_for_seal_sec_then_returns()
	test_unit_on_cell_at_fall_dies_through_player_died()
	test_unit_stepping_off_in_time_takes_no_damage()
	test_unit_stepping_onto_cracking_cell_falls()
	test_nobody_enters_a_hole()
	test_enemy_on_falling_cell_also_falls()
	test_frozen_at_fall_holds_until_unit_leaves()
	test_frozen_mid_crack_holds_even_after_thaw()
	test_rooted_mid_crack_holds_until_unit_leaves()
	test_focus_time_scale_zero_stops_crack_clock()
	test_unit_cell_droppable_cooldown_margin_frozen_rooted()
	test_fit_drop_cells_keeps_one_safe_neighbour()
	test_fit_drop_cells_no_safe_neighbour_no_cast()
	test_cast_drop_drops_unit_cell_when_not_ok()
	test_non_lethal_fall_pushes_and_costs_fall_damage()
	test_non_lethal_fall_without_landing_is_cancelled()
	test_clear_zones_closes_cracks()
	test_no_cast_no_drop_state()
	test_trait_targets_player_cell_when_droppable()
	test_trait_skips_player_cell_when_frozen_rooted_or_slow()
	test_trait_may_target_false_is_old_choice()
	test_trait_no_safe_neighbour_no_cast()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ fixtures

func _world(player_cell: Vector2i, enemy_cell: Vector2i = BoardGrid.NO_CELL) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, HP, HP, player_cell, enemy_cell)
	var status := StatusEffects.new()
	cfg.configure_status(status)
	var mover := UnitMover.new(state, P, 0.0)
	mover.set_status(status)
	# The CombatView wiring: an open hole blocks the mover, a cracking cell does not.
	mover.add_blocker(func(cell: Vector2i) -> bool: return status.is_hole(P, cell))
	status.step_locked_fn = func(side: int) -> bool: return side == P and mover.is_step_locked()
	status.hole_blocked_fn = func(side: int, cell: Vector2i) -> bool: return side == P and mover.is_cell_blocked(cell)
	return {"grid": grid, "state": state, "status": status, "mover": mover}


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in list:
		out.append(c as Vector2i)
	return out


func _ticks(w: Dictionary, n: int) -> void:
	for i: int in n:
		(w["status"] as StatusEffects).tick(STEP, w["state"])


func _warn_ticks() -> int:
	return roundi(cfg.hole_warn_sec / STEP)


func _hole_ticks() -> int:
	return roundi(cfg.seal_sec / STEP)


func _drop(w: Dictionary, cells: Array) -> Array[Vector2i]:
	return (w["status"] as StatusEffects).apply_drop(P, _cells(cells), cfg.hole_warn_sec, cfg.seal_sec)


# ------------------------------------------------------------------ config

func test_config_defaults_match_spec() -> void:
	var c := CombatConfig.new()
	var z: Dictionary = c.zone_numbers()
	_check("config: hole_warn_sec 0.8, margin 0.2, lethal true, seal_sec 1.2 (spec Tuning Knobs)",
		is_equal_approx(float(z["hole_warn_sec"]), 0.8) and is_equal_approx(float(z["hole_reaction_margin_sec"]), 0.2)
		and bool(z["hole_fall_lethal"]) and is_equal_approx(float(z["seal_sec"]), 1.2), str(z))
	var parsed: CombatConfig = CombatConfig.from_json_text(JSON.stringify({"zones": {
		"seal_sec": 1.5, "thorn_sec": 3.0, "thorn_damage": 6.0, "thorn_fragile_stacks": 1,
		"hole_warn_sec": 1.0, "hole_reaction_margin_sec": 0.3, "hole_fall_lethal": false}}))
	_check("config: zones.hole_* read from data", parsed != null and is_equal_approx(parsed.hole_warn_sec, 1.0)
		and is_equal_approx(parsed.hole_reaction_margin_sec, 0.3) and not parsed.hole_fall_lethal and is_equal_approx(parsed.seal_sec, 1.5))
	var status := StatusEffects.new()
	parsed.configure_status(status)
	_check("config: configure_status hands lethal + fall_damage to StatusEffects",
		not status.hole_fall_lethal and is_equal_approx(status.hole_fall_damage, float(parsed.hazards()["fall_damage"])))


func test_config_invalid_values_keep_defaults() -> void:
	var parsed: CombatConfig = CombatConfig.from_json_text(JSON.stringify({"zones": {
		"hole_warn_sec": -1.0, "hole_reaction_margin_sec": 5.0, "hole_fall_lethal": "yes"}}))
	_check("config: invalid hole_* values keep the defaults", parsed != null and is_equal_approx(parsed.hole_warn_sec, 0.8)
		and is_equal_approx(parsed.hole_reaction_margin_sec, 0.2) and parsed.hole_fall_lethal)


# ------------------------------------------------------------------ warning + timing

func test_crack_starts_with_data_duration_and_is_enterable() -> void:
	var w: Dictionary = _world(Vector2i(0, 1))
	var status: StatusEffects = w["status"]
	var started: Array[Vector2i] = _drop(w, [Vector2i(1, 1)])
	_check("warning: crack starts on the chosen cell", started == _cells([Vector2i(1, 1)]) and status.is_cracking(P, Vector2i(1, 1)))
	_check("warning: duration = zones.hole_warn_sec", is_equal_approx(status.crack_left(P, Vector2i(1, 1)), cfg.hole_warn_sec))
	_check("warning: not a hole yet", not status.is_hole(P, Vector2i(1, 1)))
	_check("warning: the cracking cell can be entered", (w["mover"] as UnitMover).try_step(Vector2i(1, 0)) and (w["state"] as CombatState).player_cell == Vector2i(1, 1))
	_check("warning: ...and left again", (w["mover"] as UnitMover).try_step(Vector2i(-1, 0)) and (w["state"] as CombatState).player_cell == Vector2i(0, 1))


func test_fall_exactly_at_warn_then_hole_for_seal_sec_then_returns() -> void:
	var w: Dictionary = _world(Vector2i(0, 1))
	var status: StatusEffects = w["status"]
	var c := Vector2i(1, 1)
	_drop(w, [c])
	_ticks(w, _warn_ticks() - 1)
	_check("timing: still cracking one step before hole_warn_sec", status.is_cracking(P, c) and not status.is_hole(P, c),
		str(status.crack_left(P, c)))
	_ticks(w, 1)
	_check("timing: a hole exactly at hole_warn_sec", status.is_hole(P, c) and not status.is_cracking(P, c))
	_check("timing: the hole is set to seal_sec", is_equal_approx(status.hole_left(P, c), cfg.seal_sec), str(status.hole_left(P, c)))
	_ticks(w, _hole_ticks() - 1)
	_check("timing: still a hole one step before seal_sec", status.is_hole(P, c))
	_ticks(w, 1)
	_check("timing: the cell returns after seal_sec", not status.is_hole(P, c) and not status.is_cracking(P, c))
	_check("timing: the returning cell fades in from white (presentation)", status.returning_cells(P).has(c)
		and is_equal_approx(status.hole_return_fraction(P, c), 1.0))
	_check("timing: the returned cell can be entered", (w["mover"] as UnitMover).try_step(Vector2i(1, 0)))


# ------------------------------------------------------------------ collision

func test_unit_on_cell_at_fall_dies_through_player_died() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var state: CombatState = w["state"]
	var died: Array[bool] = []
	state.player_died.connect(func() -> void: died.append(true))
	var fell: Array = []
	(w["status"] as StatusEffects).hole_fell.connect(func(side: int, cell: Vector2i, victim: bool) -> void: fell.append([side, cell, victim]))
	_drop(w, [Vector2i(1, 1)])
	_ticks(w, _warn_ticks() - 1)
	_check("collision: no damage during the warning", is_equal_approx(state.player_hp, HP))
	_ticks(w, 1)
	_check("collision: standing on the cell when it falls = HP 0", state.player_hp <= 0.0 and state.is_player_dead(), str(state.player_hp))
	_check("collision: player_died fires once (the existing match-loss path)", died.size() == 1)
	_check("collision: hole_fell reports the victim", fell == [[P, Vector2i(1, 1), true]], str(fell))


func test_unit_stepping_off_in_time_takes_no_damage() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var state: CombatState = w["state"]
	_drop(w, [Vector2i(1, 1)])
	_ticks(w, _warn_ticks() - 1)
	var moved: bool = (w["mover"] as UnitMover).try_step(Vector2i(-1, 0))
	_ticks(w, 1)
	_check("collision: stepping off before the fall costs nothing", moved and is_equal_approx(state.player_hp, HP)
		and (w["status"] as StatusEffects).is_hole(P, Vector2i(1, 1)))


func test_unit_stepping_onto_cracking_cell_falls() -> void:
	var w: Dictionary = _world(Vector2i(0, 1))
	var state: CombatState = w["state"]
	_drop(w, [Vector2i(1, 1)])
	_ticks(w, 3)
	var moved: bool = (w["mover"] as UnitMover).try_step(Vector2i(1, 0))
	_ticks(w, _warn_ticks() - 3)
	_check("collision: a unit that steps onto a cracking cell and stays falls with it", moved and state.is_player_dead())


func test_nobody_enters_a_hole() -> void:
	var w: Dictionary = _world(Vector2i(0, 1))
	_drop(w, [Vector2i(1, 1)])
	_ticks(w, _warn_ticks())
	var mover: UnitMover = w["mover"]
	_check("collision: the mover refuses a hole", mover.is_cell_blocked(Vector2i(1, 1)) and not mover.try_step(Vector2i(1, 0))
		and (w["state"] as CombatState).player_cell == Vector2i(0, 1))


func test_enemy_on_falling_cell_also_falls() -> void:
	var w: Dictionary = _world(Vector2i(0, 1), Vector2i(4, 1))
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	status.apply_drop(E, _cells([Vector2i(4, 1)]), cfg.hole_warn_sec, cfg.seal_sec)
	_ticks(w, _warn_ticks())
	_check("collision: any unit on a falling cell drops to HP 0 (enemy too)", state.is_enemy_dead() and is_equal_approx(state.player_hp, HP))


# ------------------------------------------------------------------ held falls (Frozen / rooted)

func test_frozen_at_fall_holds_until_unit_leaves() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	var c := Vector2i(1, 1)
	_drop(w, [c])
	status.pin(P, 2.0)
	_ticks(w, _warn_ticks() + 5)
	_check("frozen: the crack under a Frozen player keeps cracking and does not fall", status.is_cracking(P, c)
		and status.is_crack_held(P, c) and is_equal_approx(state.player_hp, HP))
	_ticks(w, 20) # the pin is over; the player stays
	_check("frozen: still no fall while the player stays on the cell", status.is_cracking(P, c) and is_equal_approx(state.player_hp, HP))
	var moved: bool = (w["mover"] as UnitMover).try_step(Vector2i(-1, 0))
	_ticks(w, 1)
	_check("frozen: the cell falls once the player has left, no damage", moved and status.is_hole(P, c) and is_equal_approx(state.player_hp, HP))


func test_frozen_mid_crack_holds_even_after_thaw() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var status: StatusEffects = w["status"]
	var c := Vector2i(1, 1)
	_drop(w, [c])
	_ticks(w, 2)
	status.pin(P, 0.3)
	_ticks(w, _warn_ticks())
	_check("frozen mid-crack: thawed before the fall time, the player on the cell still does not fall",
		not status.is_pinned(P) and status.is_cracking(P, c) and not (w["state"] as CombatState).is_player_dead())


func test_rooted_mid_crack_holds_until_unit_leaves() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var status: StatusEffects = w["status"]
	var mover: UnitMover = w["mover"]
	var rooted: Array[bool] = [false]
	mover.step_lock_fn = func() -> bool: return rooted[0]
	var c := Vector2i(1, 1)
	_drop(w, [c])
	_ticks(w, 2)
	rooted[0] = true
	_ticks(w, _warn_ticks())
	_check("rooted: no fall while rooted on the cracking cell", status.is_cracking(P, c) and not (w["state"] as CombatState).is_player_dead())
	rooted[0] = false
	var moved: bool = mover.try_step(Vector2i(0, -1))
	_ticks(w, 1)
	_check("rooted: falls after the player leaves", moved and status.is_hole(P, c) and not (w["state"] as CombatState).is_player_dead())


func test_focus_time_scale_zero_stops_crack_clock() -> void:
	# CombatView feeds StatusEffects real_step x _sim_scale(); Focus's shipped time scale is 0 (cards.json focus).
	var w: Dictionary = _world(Vector2i(0, 1))
	var status: StatusEffects = w["status"]
	var c := Vector2i(1, 1)
	_drop(w, [c])
	_ticks(w, 3)
	var before: float = status.crack_left(P, c)
	var focus_scale: float = SkillConfig.new().focus_time_scale
	for i: int in 50:
		status.tick(STEP * focus_scale, w["state"])
	_check("focus: time scale 0 -> the crack clock does not move", focus_scale == 0.0 and is_equal_approx(status.crack_left(P, c), before),
		"%f vs %f" % [status.crack_left(P, c), before])


# ------------------------------------------------------------------ ZoneRules (single rule point)

func test_unit_cell_droppable_cooldown_margin_frozen_rooted() -> void:
	var warn: float = cfg.hole_warn_sec
	var margin: float = cfg.hole_reaction_margin_sec
	var limit: float = warn - margin
	_check("rule 6: cooldown 0 -> droppable", ZoneRules.unit_cell_droppable(0.0, warn, margin, false, false))
	_check("rule 6: cooldown exactly warn - margin -> droppable", ZoneRules.unit_cell_droppable(limit, warn, margin, false, false))
	_check("rule 6: cooldown above warn - margin -> not droppable", not ZoneRules.unit_cell_droppable(limit + 0.01, warn, margin, false, false))
	_check("rule 6: Frozen -> not droppable", not ZoneRules.unit_cell_droppable(0.0, warn, margin, true, false))
	_check("rule 6: rooted -> not droppable", not ZoneRules.unit_cell_droppable(0.0, warn, margin, false, true))


func test_fit_drop_cells_keeps_one_safe_neighbour() -> void:
	var w: Dictionary = _world(Vector2i(0, 0))
	var status: StatusEffects = w["status"]
	# (1,0) already cracking: the only other neighbour (0,1) must stay safe, so it is dropped from the new crack.
	_drop(w, [Vector2i(1, 0)])
	var kept: Array[Vector2i] = ZoneRules.cast_drop(w["state"], w["grid"], status, P, _cells([Vector2i(0, 1), Vector2i(0, 0)]),
		cfg.hole_warn_sec, cfg.seal_sec, true)
	_check("rule 6: a cracking neighbour is not safe; the last safe neighbour is kept open", kept == _cells([Vector2i(0, 0)])
		and not status.is_cracking(P, Vector2i(0, 1)), str(kept))


func test_fit_drop_cells_no_safe_neighbour_no_cast() -> void:
	var w: Dictionary = _world(Vector2i(0, 0))
	var status: StatusEffects = w["status"]
	_drop(w, [Vector2i(1, 0), Vector2i(0, 1)])
	var kept: Array[Vector2i] = ZoneRules.cast_drop(w["state"], w["grid"], status, P, _cells([Vector2i(0, 0), Vector2i(2, 2)]),
		cfg.hole_warn_sec, cfg.seal_sec, true)
	_check("rule 6: no safe neighbour at crack start -> no cast at all", kept.is_empty() and not status.is_cracking(P, Vector2i(2, 2)), str(kept))


func test_cast_drop_drops_unit_cell_when_not_ok() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var kept: Array[Vector2i] = ZoneRules.cast_drop(w["state"], w["grid"], w["status"], P, _cells([Vector2i(1, 1), Vector2i(1, 0)]),
		cfg.hole_warn_sec, cfg.seal_sec, false)
	_check("rule 6: the unit's own cell is never cracked when not droppable", kept == _cells([Vector2i(1, 0)]), str(kept))


# ------------------------------------------------------------------ fallbacks

func test_non_lethal_fall_pushes_and_costs_fall_damage() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	status.hole_fall_lethal = false
	status.hole_fall_damage = FALL_DAMAGE
	_drop(w, [Vector2i(1, 1)])
	_ticks(w, _warn_ticks())
	_check("hole_fall_lethal=false: the unit loses fall_damage, survives and is moved off the hole",
		is_equal_approx(state.player_hp, HP - FALL_DAMAGE) and state.player_cell != Vector2i(1, 1) and status.is_hole(P, Vector2i(1, 1)),
		"%f %s" % [state.player_hp, state.player_cell])


func test_non_lethal_fall_without_landing_is_cancelled() -> void:
	var w: Dictionary = _world(Vector2i(0, 0))
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	status.hole_fall_lethal = false
	status.hole_fall_damage = FALL_DAMAGE
	(w["mover"] as UnitMover).add_blocker(func(cell: Vector2i) -> bool: return cell == Vector2i(1, 0) or cell == Vector2i(0, 1))
	_drop(w, [Vector2i(0, 0)])
	_ticks(w, _warn_ticks())
	_check("hole_fall_lethal=false: no landing cell -> the fall is cancelled, no damage (as a crumble)",
		not status.is_hole(P, Vector2i(0, 0)) and not status.is_cracking(P, Vector2i(0, 0)) and is_equal_approx(state.player_hp, HP))


# ------------------------------------------------------------------ no regression

func test_clear_zones_closes_cracks() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var status: StatusEffects = w["status"]
	_drop(w, [Vector2i(1, 1)])
	status.clear_zones(P)
	_ticks(w, _warn_ticks())
	_check("clear_zones (boss died): no crack left to kill the player", status.crack_cells(P).is_empty()
		and status.hole_cells(P).is_empty() and is_equal_approx((w["state"] as CombatState).player_hp, HP))


func test_no_cast_no_drop_state() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var status: StatusEffects = w["status"]
	var signals: Array[int] = [0]
	status.hole_cracked.connect(func(_s: int, _c: Array[Vector2i]) -> void: signals[0] += 1)
	status.hole_fell.connect(func(_s: int, _c: Vector2i, _v: bool) -> void: signals[0] += 1)
	_ticks(w, 30)
	var mover: UnitMover = w["mover"]
	_check("no seal_caster: no crack, no hole, no signal, every cell steppable", signals[0] == 0 and status.crack_cells(P).is_empty()
		and status.hole_cells(P).is_empty() and mover.try_step(Vector2i(1, 0)))


# ------------------------------------------------------------------ trait seal_caster

func _trait(w: Dictionary, params: Dictionary) -> SealCasterTrait:
	var t := SealCasterTrait.new()
	t.setup({"state": w["state"], "grid": w["grid"], "status": w["status"], "player_mover": w["mover"], "combat_config": cfg},
		params, SEED)
	t.on_match_start()
	return t


func _row(y: int) -> Array[Vector2i]:
	return _cells([Vector2i(0, y), Vector2i(1, y), Vector2i(2, y)])


func test_trait_targets_player_cell_when_droppable() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var t: SealCasterTrait = _trait(w, {"cells_min": 2, "cells_max": 2})
	var numbers: Dictionary = t.get_drop_numbers()
	_check("trait: numbers from combat.json zones (warn 0.8, hole 1.2, margin 0.2, may_target true)",
		is_equal_approx(float(numbers["warn_sec"]), 0.8) and is_equal_approx(float(numbers["hole_sec"]), 1.2)
		and is_equal_approx(float(numbers["margin_sec"]), 0.2) and bool(numbers["may_target_player_cell"]), str(numbers))
	var placed: Array[Vector2i] = t._cast(_row(1))
	var status: StatusEffects = w["status"]
	_check("trait: the player's cell is chosen when the player can step off in time", placed.has(Vector2i(1, 1))
		and status.is_cracking(P, Vector2i(1, 1)), str(placed))
	_check("trait: 2 cells, a safe neighbour stays open", placed.size() == 2 and _safe_neighbours(w).size() >= 1, str(placed))


func test_trait_skips_player_cell_when_frozen_rooted_or_slow() -> void:
	var cases: Array[String] = ["frozen", "rooted", "cooldown"]
	for kind: String in cases:
		var w: Dictionary = _world(Vector2i(1, 1))
		var mover: UnitMover = w["mover"]
		match kind:
			"frozen":
				(w["status"] as StatusEffects).pin(P, 5.0)
			"rooted":
				mover.step_lock_fn = func() -> bool: return true
			"cooldown":
				# A real step whose cooldown left (0.7 s) is above warn - margin (0.6 s).
				var slow := UnitMover.new(w["state"], P, cfg.hole_warn_sec - cfg.hole_reaction_margin_sec + 0.1)
				slow.try_step(Vector2i(0, 1))
				slow.try_step(Vector2i(0, -1)) # refused (cooldown), the player stays on (1,2)
				w["mover"] = slow
		var t: SealCasterTrait = _trait(w, {"cells_min": 3, "cells_max": 3})
		var own: Vector2i = (w["state"] as CombatState).player_cell
		var placed: Array[Vector2i] = t._cast(_row(own.y))
		_check("trait: %s player -> own cell never chosen" % kind, not placed.has(own) and not t.player_cell_droppable(), str(placed))


func test_trait_may_target_false_is_old_choice() -> void:
	var w: Dictionary = _world(Vector2i(1, 1))
	var t: SealCasterTrait = _trait(w, {"cells_min": 3, "cells_max": 3, "may_target_player_cell": false})
	var placed: Array[Vector2i] = t._cast(_row(1))
	var ok: bool = not placed.is_empty()
	for c: Vector2i in placed:
		ok = ok and not _row(1).has(c)
	_check("may_target_player_cell=false: escape cells only, never the player's cell", ok, str(placed))


func test_trait_no_safe_neighbour_no_cast() -> void:
	var w: Dictionary = _world(Vector2i(0, 0))
	var status: StatusEffects = w["status"]
	_drop(w, [Vector2i(1, 0), Vector2i(0, 1)])
	var t: SealCasterTrait = _trait(w, {"cells_min": 2, "cells_max": 3})
	var swing: Array[Vector2i] = _cells([Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)])
	var placed: Array[Vector2i] = t._cast(swing)
	_check("trait: cornered with no safe neighbour -> no cast", placed.is_empty() and not status.is_cracking(P, Vector2i(0, 0)), str(placed))


# Player-half neighbours of the player that are steppable, not cracking and not a hole.
func _safe_neighbours(w: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var status: StatusEffects = w["status"]
	var p: Vector2i = (w["state"] as CombatState).player_cell
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var c: Vector2i = p + d
		if (w["grid"] as BoardGrid).is_player_cell(c) and not status.is_cracking(P, c) and not status.is_hole(P, c):
			out.append(c)
	return out

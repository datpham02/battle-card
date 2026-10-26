extends SceneTree
## Story 036 Parts B-D: the six region traits spore_burst, hop_skip, bog_spread, burrow, riposte, sandstorm, each on
## its cadence with its params, against a real CombatState + BoardGrid + TileHazards + BossController; plus the
## untargetable window (a burrowed boss: a landing cast misses, its seal still forms) through the real
## SwingArbiter + TraitHost. Headless; FAILS=N. Deterministic: fixed seeds, fixed steps.

const SEED: int = 23
const STEP: float = 0.1
## 3x3 per half: the player's half is x 0..2, the boss's x 3..5.
const SIDE_COLS: int = 3
const SIDE_ROWS: int = 3
const EPS: float = 0.001

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	_test_registry()
	_test_spore_burst_icd()
	_test_hop_over_seal()
	_test_hop_refused_into_sand()
	_test_bog_spread_interval_and_escape()
	_test_burrow_cadence_and_surface()
	_test_burrow_untargetable_cast_misses_zone_lands()
	_test_riposte_min_cells()
	_test_sandstorm_drift_mult()
	_test_missing_hazards_is_inert()
	print("FAILS=%d" % fails)
	quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ fixtures

func _world(player_cell: Vector2i, enemy_cell: Vector2i, with_hazards: bool = true) -> Dictionary:
	var grid := BoardGrid.new(SIDE_COLS, SIDE_ROWS)
	var state := CombatState.new(grid, 100.0, 1000.0, player_cell, enemy_cell)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 1.0e9
	var boss := BossController.new(
		state, grid, cut_config, skill_config, BossBrainConfig.load_from_file(), drops_config,
		HoldSlotsConfig.new(), SEED
	)
	boss.set_active(true)
	var status := StatusEffects.new()
	var mover := UnitMover.new(state, CombatState.Side.PLAYER, 0.3)
	var ctx: Dictionary = {"state": state, "grid": grid, "status": status, "boss": boss, "player_mover": mover}
	var hazards: TileHazards = null
	if with_hazards:
		hazards = TileHazards.new(grid, SEED)
		hazards.bind_state(state)
		ctx["hazards"] = hazards
	return {
		"grid": grid, "state": state, "status": status, "boss": boss, "mover": mover, "ctx": ctx, "hazards": hazards,
		"cut_config": cut_config, "skill_config": skill_config,
	}


func _make(id: String, w: Dictionary, params: Dictionary) -> BossTrait:
	var t: BossTrait = TraitRegistry.create(id)
	t.setup(w["ctx"], params, SEED)
	t.on_match_start()
	return t


func _run(t: BossTrait, seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		t.on_tick(STEP)


# ------------------------------------------------------------------ tests

func _test_registry() -> void:
	_check("registry: spore_burst", TraitRegistry.create("spore_burst") is SporeBurstTrait)
	_check("registry: hop_skip", TraitRegistry.create("hop_skip") is HopSkipTrait)
	_check("registry: bog_spread", TraitRegistry.create("bog_spread") is BogSpreadTrait)
	_check("registry: burrow", TraitRegistry.create("burrow") is BurrowTrait)
	_check("registry: riposte", TraitRegistry.create("riposte") is RiposteTrait)
	_check("registry: sandstorm", TraitRegistry.create("sandstorm") is SandstormTrait)


func _test_spore_burst_icd() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var t: SporeBurstTrait = _make("spore_burst", w, {"spread_cells": 2, "spore_mire_sec": 4.0, "icd_sec": 1.5}) as SporeBurstTrait
	var hz: TileHazards = w["hazards"]
	t.on_boss_damaged(5.0)
	var cells: Array[Vector2i] = t.get_last_cells()
	_check("spore: player cell + 2 neighbours mired", cells.size() == 3 and cells.has(Vector2i(1, 1))
		and hz.is_mire(CombatState.Side.PLAYER, Vector2i(1, 1)), str(cells))
	_check("spore: timed spore_mire_sec", absf(hz.mire_left(CombatState.Side.PLAYER, Vector2i(1, 1)) - 4.0) < EPS,
		str(hz.mire_left(CombatState.Side.PLAYER, Vector2i(1, 1))))
	t.on_boss_damaged(5.0)
	_check("spore: second hit inside icd ignored", t.get_burst_count() == 1)
	_run(t, 1.5)
	t.on_boss_damaged(5.0)
	_check("spore: bursts again after icd_sec", t.get_burst_count() == 2)
	t.teardown()


# Boss steps (3,1)->(3,0)->(3,1) with hop_every 2; (4,1) sealed: the only hop is over the seal to (5,1).
func _test_hop_over_seal() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(3, 1))
	var t: HopSkipTrait = _make("hop_skip", w, {"hop_every": 2, "hop_warn_sec": 0.4}) as HopSkipTrait
	var state: CombatState = w["state"]
	(w["status"] as StatusEffects).apply_seal(CombatState.Side.ENEMY, [Vector2i(4, 1)] as Array[Vector2i], 30.0)
	state.set_enemy_cell(Vector2i(3, 0))
	t.on_tick(STEP)
	_check("hop: no hop before hop_every steps", t.get_hop_target() == Vector2i(-1, -1))
	state.set_enemy_cell(Vector2i(3, 1))
	t.on_tick(STEP)
	_check("hop: shadow on (5,1) over the seal", t.get_hop_target() == Vector2i(5, 1), str(t.get_hop_target()))
	_check("hop: warn time = hop_warn_sec", absf(t.get_hop_warn_left() - 0.4) < EPS, str(t.get_hop_warn_left()))
	var mover: UnitMover = (w["boss"] as BossController).get_mover()
	_check("hop: boss steps locked during the shadow", not mover.try_step(Vector2i(0, -1)))
	_run(t, 0.4)
	_check("hop: landed on (5,1)", state.enemy_cell == Vector2i(5, 1) and t.get_hop_count() == 1, str(state.enemy_cell))
	_check("hop: step counter reset, shadow cleared", t.get_step_count() == 0 and t.get_hop_target() == Vector2i(-1, -1))
	t.teardown()


func _test_hop_refused_into_sand() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(3, 1))
	var t: HopSkipTrait = _make("hop_skip", w, {"hop_every": 2, "hop_warn_sec": 0.4}) as HopSkipTrait
	var state: CombatState = w["state"]
	var hz: TileHazards = w["hazards"]
	var kept: Array[Vector2i] = hz.add_sand(CombatState.Side.ENEMY, [Vector2i(5, 1)] as Array[Vector2i], 30.0, 0.0)
	hz.tick(STEP, state)
	state.set_enemy_cell(Vector2i(3, 0))
	state.set_enemy_cell(Vector2i(3, 1))
	t.on_tick(STEP)
	_check("hop: sand on the only destination refuses the hop", kept.has(Vector2i(5, 1))
		and t.get_hop_target() == Vector2i(-1, -1), "kept=%s target=%s" % [kept, t.get_hop_target()])
	t.teardown()


func _test_bog_spread_interval_and_escape() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var t: BogSpreadTrait = _make("bog_spread", w, {"interval_sec": 8.0, "cells": 2, "mire_sec": 5.0}) as BogSpreadTrait
	var hz: TileHazards = w["hazards"]
	_run(t, 7.9)
	_check("bog: nothing before interval_sec", t.get_spread_count() == 0)
	_run(t, 0.1)
	var cells: Array[Vector2i] = t.get_last_cells()
	_check("bog: 2 seeded mire cells at interval_sec", t.get_spread_count() == 1 and cells.size() == 2
		and not t.was_last_escape() and not cells.has(Vector2i(1, 1)), str(cells))
	_check("bog: mire_sec", absf(hz.mire_left(CombatState.Side.PLAYER, cells[0]) - 5.0) < EPS)
	# A 3-cell boss cast over row 0: the escape cells touching it come first.
	var actor: CutActor = (w["boss"] as BossController).get_actor()
	actor.begin_swing([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, false, 1, 20.0)
	_run(t, 8.0)
	cells = t.get_last_cells()
	cells.sort()
	var expected: Array[Vector2i] = [Vector2i(0, 1), Vector2i(2, 1)]
	_check("bog: escape priority while the boss casts >= 3 cells", t.was_last_escape() and cells == expected, str(cells))
	t.teardown()


func _test_burrow_cadence_and_surface() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var t: BurrowTrait = _make("burrow", w, {"interval_sec": 7.0, "burrow_sec": 1.5, "surface_warn_sec": 0.5}) as BurrowTrait
	var boss: BossController = w["boss"]
	_run(t, 6.9)
	_check("burrow: not before interval_sec", not t.is_burrowed())
	_run(t, 0.1)
	_check("burrow: burrowed at interval_sec, untargetable, boss inactive", t.is_burrowed() and t.untargetable()
		and not boss.is_active())
	_check("burrow: no surface circle before the warning window", t.get_surface_cell() == Vector2i(-1, -1))
	_run(t, 1.0)
	var surface: Vector2i = t.get_surface_cell()
	_check("burrow: surface circle in the last surface_warn_sec", surface != Vector2i(-1, -1) and surface != Vector2i(4, 1)
		and absf(t.get_surface_warn_left() - 0.5) < EPS, "%s %f" % [surface, t.get_surface_warn_left()])
	_run(t, 0.5)
	_check("burrow: surfaced on the announced cell, active again", not t.is_burrowed() and boss.is_active()
		and (w["state"] as CombatState).enemy_cell == surface, str((w["state"] as CombatState).enemy_cell))
	t.teardown()


# The real damage path: TraitHost wires SwingArbiter.enemy_untargetable_fn; a long_an (seal + damage) cast over the
# burrowed boss's row misses it but its seal forms; after surfacing a slash on its cell hits.
func _test_burrow_untargetable_cast_misses_zone_lands() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var boss: BossController = w["boss"]
	var player_actor := CutActor.new(w["cut_config"], CombatState.Side.PLAYER)
	var arbiter := SwingArbiter.new(state, w["grid"], player_actor, boss.get_actor(), w["cut_config"], w["skill_config"], status)
	var ctx: Dictionary = w["ctx"]
	ctx["arbiter"] = arbiter
	var host := TraitHost.new(ctx, [{"id": "burrow", "params": {"interval_sec": 1.0, "burrow_sec": 1.5, "surface_warn_sec": 0.5}}], SEED)
	host.on_match_start()
	_check("untargetable: host wired the arbiter", arbiter.enemy_untargetable_fn.is_valid() and not host.is_boss_untargetable())
	for i: int in 10:
		host.on_tick(STEP)
	_check("untargetable: host reports the burrow", host.is_boss_untargetable())
	var hp_before: float = state.enemy_hp
	var row: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]
	player_actor.begin_swing(row, "long_an", true, 1, 0.2)
	arbiter.tick(0.3)
	_check("untargetable: landing cast misses (no damage)", absf(state.enemy_hp - hp_before) < EPS, str(state.enemy_hp))
	_check("untargetable: its seal still forms", not status.sealed_cells(CombatState.Side.ENEMY).is_empty(),
		str(status.sealed_cells(CombatState.Side.ENEMY)))
	for i: int in 15:
		host.on_tick(STEP)
	_check("untargetable: surfaced", not host.is_boss_untargetable())
	player_actor.begin_swing([state.enemy_cell] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, true, 1, 0.2)
	arbiter.tick(0.3)
	_check("untargetable: after surfacing a cast hits", state.enemy_hp < hp_before, str(state.enemy_hp))
	host.teardown_all()
	_check("untargetable: teardown unwires the arbiter", not arbiter.enemy_untargetable_fn.is_valid())


func _test_riposte_min_cells() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var state: CombatState = w["state"]
	var t: RiposteTrait = _make("riposte", w, {"min_cells": 4, "warn_sec": 0.4, "damage": 10.0}) as RiposteTrait
	var three: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(4, 1)]
	var four: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(4, 1), Vector2i(5, 1)]
	t.on_player_swing_resolved({"hit": true, "damage": 6.0, "cells": three})
	_check("riposte: a 3-cell hit does not trigger", t.get_riposte_cell() == Vector2i(-1, -1))
	t.on_player_swing_resolved({"hit": false, "damage": 0.0, "cells": four})
	_check("riposte: a 4-cell miss does not trigger", t.get_riposte_cell() == Vector2i(-1, -1))
	t.on_player_swing_resolved({"hit": true, "damage": 8.0, "cells": four})
	_check("riposte: a 4-cell hit warns on the player's cell", t.get_riposte_cell() == Vector2i(1, 1)
		and absf(t.get_riposte_warn_left() - 0.4) < EPS)
	var hp: float = state.player_hp
	_run(t, 0.4)
	_check("riposte: standing still takes damage", absf(hp - state.player_hp - 10.0) < EPS, str(state.player_hp))
	t.on_player_swing_resolved({"hit": true, "damage": 8.0, "cells": four})
	state.set_player_cell(Vector2i(0, 1))
	hp = state.player_hp
	_run(t, 0.4)
	_check("riposte: not re-aimed, stepping away dodges", absf(hp - state.player_hp) < EPS and t.get_counter_count() == 2
		and t.get_hit_count() == 1)
	t.teardown()


func _test_sandstorm_drift_mult() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var hz: TileHazards = w["hazards"]
	var t: SandstormTrait = _make("sandstorm", w, {"interval_sec": 2.0, "storm_sec": 1.0, "extra_sand": 2}) as SandstormTrait
	_run(t, 1.9)
	_check("storm: not before interval_sec", not t.is_storm())
	_run(t, 0.1)
	_check("storm: started, drift mult 0.5", t.is_storm() and absf(float(hz.get_debug()["drift_mult"]) - 0.5) < EPS
		and absf(t.get_storm_fraction() - 1.0) < EPS)
	var cells: Array[Vector2i] = t.get_last_cells()
	_check("storm: extra sand on the player's half, not the player's cell", not cells.is_empty() and cells.size() <= 2
		and not cells.has(Vector2i(1, 1)) and hz.is_sand_warning(CombatState.Side.PLAYER, cells[0]), str(cells))
	_run(t, 0.5)
	_check("storm: bar half way", absf(t.get_storm_fraction() - 0.5) < 0.051, str(t.get_storm_fraction()))
	_run(t, 0.5)
	_check("storm: drift mult back to 1 after storm_sec", not t.is_storm() and absf(float(hz.get_debug()["drift_mult"]) - 1.0) < EPS)
	t.teardown()


func _test_missing_hazards_is_inert() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1), false)
	var t: SporeBurstTrait = _make("spore_burst", w, {}) as SporeBurstTrait
	t.on_boss_damaged(5.0)
	_check("no hazards: spore_burst does nothing", t.get_burst_count() == 0)
	t.teardown()

extends SceneTree
## Story 036 Parts B-D: the six region traits spore_burst, hop_skip, bog_spread, burrow, riposte, sandstorm, each on
## its cadence with its params, against a real CombatState + BoardGrid + TileHazards + BossController; plus the
## untargetable window (a burrowed boss: a landing cast misses, its seal still forms) through the real
## SwingArbiter + TraitHost. Story 039 adds burn_eater, rebirth, vent_surge, gust, shroud, island_drop and the
## phase_shift vent interval multiplier. Headless; FAILS=N. Deterministic: fixed seeds, fixed steps.

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
	_test_registry_039()
	_test_burn_eater_heals_instead_of_damaging()
	_test_rebirth_once_and_not_with_frost()
	_test_vent_surge_timing()
	_test_vent_surge_first_delay()
	_test_gust_cancels_into_forbidden_cells()
	_test_gust_pushes_one_cell()
	_test_shroud_blocks_forecast_except_pinned_or_casting()
	_test_island_drop_never_the_last_island()
	_test_phase_shift_vent_interval_mult()
	print("FAILS=%d" % fails)
	quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ fixtures

func _world(player_cell: Vector2i, enemy_cell: Vector2i, with_hazards: bool = true, cols: int = SIDE_COLS, rows: int = SIDE_ROWS) -> Dictionary:
	var grid := BoardGrid.new(cols, rows)
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


# Boss steps (3,1)->(3,0)->(3,1) with hop_every 2; (4,1) is an open drop-tile hole: the only hop is over it to (5,1).
func _test_hop_over_seal() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(3, 1))
	var t: HopSkipTrait = _make("hop_skip", w, {"hop_every": 2, "hop_warn_sec": 0.4}) as HopSkipTrait
	var state: CombatState = w["state"]
	var hop_status: StatusEffects = w["status"]
	hop_status.apply_drop(CombatState.Side.ENEMY, [Vector2i(4, 1)] as Array[Vector2i], 0.0, 30.0)
	hop_status.tick(STEP, state)
	_check("hop: (4,1) is an open hole", hop_status.is_hole(CombatState.Side.ENEMY, Vector2i(4, 1)))
	state.set_enemy_cell(Vector2i(3, 0))
	t.on_tick(STEP)
	_check("hop: no hop before hop_every steps", t.get_hop_target() == Vector2i(-1, -1))
	state.set_enemy_cell(Vector2i(3, 1))
	t.on_tick(STEP)
	_check("hop: shadow on (5,1) over the hole", t.get_hop_target() == Vector2i(5, 1), str(t.get_hop_target()))
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


# The real damage path: TraitHost wires SwingArbiter.enemy_untargetable_fn; a gai_doc (thorns + damage) cast over the
# burrowed boss's row misses it but its thorns form; after surfacing a slash on its cell hits.
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
	player_actor.begin_swing(row, "gai_doc", true, 1, 0.2)
	arbiter.tick(0.3)
	_check("untargetable: landing cast misses (no damage)", absf(state.enemy_hp - hp_before) < EPS, str(state.enemy_hp))
	_check("untargetable: its thorns still form", not status.thorn_cells(CombatState.Side.ENEMY).is_empty(),
		str(status.thorn_cells(CombatState.Side.ENEMY)))
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


# ------------------------------------------------------------------ Story 039 traits

func _test_registry_039() -> void:
	_check("registry: burn_eater", TraitRegistry.create("burn_eater") is BurnEaterTrait)
	_check("registry: rebirth", TraitRegistry.create("rebirth") is RebirthTrait)
	_check("registry: vent_surge", TraitRegistry.create("vent_surge") is VentSurgeTrait)
	_check("registry: gust", TraitRegistry.create("gust") is GustTrait)
	_check("registry: shroud", TraitRegistry.create("shroud") is ShroudTrait)
	_check("registry: island_drop", TraitRegistry.create("island_drop") is IslandDropTrait)


# A burning cell under the boss heals it by the tick damage x heal_ratio; without the trait it hurts as before.
func _test_burn_eater_heals_instead_of_damaging() -> void:
	var control: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	(control["state"] as CombatState).damage_enemy(500.0)
	var cells: Array[Vector2i] = [Vector2i(4, 1)]
	(control["status"] as StatusEffects).ignite(cells, 2.0, 0.5, 10.0)
	(control["status"] as StatusEffects).tick(0.5, control["state"])
	_check("burn_eater: control (no trait) burning hurts", absf((control["state"] as CombatState).enemy_hp - 490.0) < EPS,
		str((control["state"] as CombatState).enemy_hp))

	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var host := TraitHost.new(w["ctx"], [{"id": "burn_eater", "params": {"heal_ratio": 1.0}}], SEED)
	host.on_match_start()
	var eater: BurnEaterTrait = host.get_trait("burn_eater") as BurnEaterTrait
	var heals: Array[float] = []
	state.enemy_healed.connect(func(amount: float) -> void: heals.append(amount))
	state.damage_enemy(500.0)
	status.ignite(cells, 2.0, 0.5, 10.0)
	status.tick(0.5, state)
	_check("burn_eater: a burn tick heals instead of damaging", absf(state.enemy_hp - 510.0) < EPS, str(state.enemy_hp))
	_check("burn_eater: green-number signal fired with the amount", heals.size() == 1 and absf(heals[0] - 10.0) < EPS, str(heals))
	_check("burn_eater: getters", eater.heals_from_burn() and absf(eater.get_heal_total() - 10.0) < EPS and host.burn_heal_ratio() == 1.0)
	status.tick(0.5, state)
	_check("burn_eater: every tick heals", absf(state.enemy_hp - 520.0) < EPS and eater.get_heal_count() == 2, str(state.enemy_hp))
	# The PLAYER standing on a burning cell is hurt as usual.
	var player_cells: Array[Vector2i] = [Vector2i(1, 1)]
	status.ignite(player_cells, 2.0, 0.5, 10.0)
	status.tick(0.5, state)
	_check("burn_eater: the player's own burn still hurts the player", absf(state.player_hp - 90.0) < EPS, str(state.player_hp))
	# Never above max HP.
	state.enemy_hp = state.enemy_max_hp - 4.0
	status.tick(0.5, state)
	_check("burn_eater: heal clamps at max HP", absf(state.enemy_hp - state.enemy_max_hp) < EPS, str(state.enemy_hp))
	host.teardown_all()
	_check("burn_eater: teardown unwires the hook", not status.burn_heal_ratio_fn.is_valid())


# The first death is taken over (held at 1 HP, untargetable, boss paused), then the boss revives at revive_ratio; a second
# death is final; a Han stack at the moment of death makes the first one final too.
func _test_rebirth_once_and_not_with_frost() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var state: CombatState = w["state"]
	var boss: BossController = w["boss"]
	var host := TraitHost.new(w["ctx"], [{"id": "rebirth", "params": {"revive_ratio": 0.4, "revive_sec": 1.5}}], SEED)
	host.on_match_start()
	var phoenix: RebirthTrait = host.get_trait("rebirth") as RebirthTrait
	var deaths: Array[int] = [0]
	state.enemy_died.connect(func() -> void: deaths[0] += 1)
	_check("rebirth: one life before", phoenix.lives_left() == 1 and not phoenix.is_reviving())
	state.damage_enemy(5000.0)
	_check("rebirth: the first death is taken over (held at 1 HP, no enemy_died)", deaths[0] == 0 and not state.is_enemy_dead()
		and absf(state.enemy_hp - CombatState.HOLD_HP) < EPS, "hp=%f deaths=%d" % [state.enemy_hp, deaths[0]])
	_check("rebirth: reviving, untargetable, boss paused, lives 0", phoenix.is_reviving() and host.is_boss_untargetable()
		and not boss.is_active() and phoenix.lives_left() == 0 and absf(phoenix.revive_left() - 1.5) < EPS)
	state.damage_enemy(50.0)
	_check("rebirth: a blow while reviving does not kill", deaths[0] == 0 and not state.is_enemy_dead())
	for i: int in 14:
		host.on_tick(STEP)
	_check("rebirth: still reviving before revive_sec", phoenix.is_reviving())
	host.on_tick(STEP)
	_check("rebirth: revived at revive_ratio x max HP, active again", not phoenix.is_reviving()
		and absf(state.enemy_hp - 400.0) < EPS and boss.is_active() and not host.is_boss_untargetable(), str(state.enemy_hp))
	state.damage_enemy(5000.0)
	_check("rebirth: the second death is final", deaths[0] == 1 and state.is_enemy_dead() and phoenix.lives_left() == 0)
	host.teardown_all()
	_check("rebirth: teardown unwires the death hook", not state.enemy_death_hook_fn.is_valid())

	var f: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var fstate: CombatState = f["state"]
	var fhost := TraitHost.new(f["ctx"], [{"id": "rebirth", "params": {}}], SEED)
	fhost.on_match_start()
	(f["status"] as StatusEffects).apply_frost(CombatState.Side.ENEMY, 1)
	fstate.damage_enemy(5000.0)
	_check("rebirth: >= 1 Han stack at death means it dies", fstate.is_enemy_dead()
		and (fhost.get_trait("rebirth") as RebirthTrait).lives_left() == 1)
	fhost.teardown_all()


# Every interval_sec the player's half vents surge: 2 vents warn at once, the one holding the player's cell included.
func _test_vent_surge_timing() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var hz: TileHazards = w["hazards"]
	var row0: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var row1: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	var row2: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
	hz.set_vents(CombatState.Side.PLAYER, [row0, row1, row2])
	var t: VentSurgeTrait = _make("vent_surge", w, {"interval_sec": 10.0, "vents": 2}) as VentSurgeTrait
	_run(t, 9.9)
	_check("vent_surge: nothing before interval_sec", t.get_surge_count() == 0
		and not hz.is_vent_warning(CombatState.Side.PLAYER, Vector2i(1, 1)))
	_run(t, 0.1)
	var warning: int = 0
	for cell: Vector2i in hz.vent_cells(CombatState.Side.PLAYER):
		if hz.is_vent_warning(CombatState.Side.PLAYER, cell):
			warning += 1
	_check("vent_surge: 2 vents warn at interval_sec (6 cells)", t.get_surge_count() == 1 and t.get_last_count() == 2 and warning == 6,
		"surges=%d count=%d cells=%d" % [t.get_surge_count(), t.get_last_count(), warning])
	_check("vent_surge: the vent holding the player's cell is one of them", hz.is_vent_warning(CombatState.Side.PLAYER, Vector2i(1, 1)))
	t.teardown()
	var bare: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var inert: VentSurgeTrait = _make("vent_surge", bare, {"interval_sec": 1.0}) as VentSurgeTrait
	_run(inert, 2.0)
	_check("vent_surge: no vents on the side = nothing happens", inert.get_surge_count() == 0)
	inert.teardown()


# All four neighbours forbidden (drop-tile hole, sand): every gust is cancelled and the player stays.
func _test_gust_cancels_into_forbidden_cells() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var state: CombatState = w["state"]
	var hz: TileHazards = w["hazards"]
	var status: StatusEffects = w["status"]
	var t: GustTrait = _make("gust", w, {"interval_sec": 6.0, "warn_sec": 0.6}) as GustTrait
	var holes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 2)]
	status.apply_drop(CombatState.Side.PLAYER, holes, 0.0, 60.0)
	status.tick(STEP, state)
	_check("gust: (1,0) and (1,2) are open holes", status.is_hole(CombatState.Side.PLAYER, Vector2i(1, 0)) and status.is_hole(CombatState.Side.PLAYER, Vector2i(1, 2)),
		str(status.hole_cells(CombatState.Side.PLAYER)))
	var sand: Array[Vector2i] = [Vector2i(0, 1), Vector2i(2, 1)]
	hz.add_sand(CombatState.Side.PLAYER, sand, 60.0, 0.0)
	hz.tick(STEP, state)
	_check("gust: hole and sand cells are no push targets", not t.can_push_to(Vector2i(1, 0)) and not t.can_push_to(Vector2i(0, 1))
		and not t.can_push_to(Vector2i(2, 1)) and not t.can_push_to(Vector2i(1, 2)))
	_check("gust: outside the half is refused, a free cell is allowed", not t.can_push_to(Vector2i(3, 1))
		and not t.can_push_to(Vector2i(-1, 1)) and t.can_push_to(Vector2i(0, 0)))
	_run(t, 5.9)
	_check("gust: no arrow before interval_sec", t.get_gust_dir() == Vector2i.ZERO and t.get_gust_warn_left() == 0.0)
	_run(t, 0.1)
	var dir: Vector2i = t.get_gust_dir()
	_check("gust: arrow with a 1-cell direction and warn_sec", absi(dir.x) + absi(dir.y) == 1 and absf(t.get_gust_warn_left() - 0.6) < EPS,
		"%s %f" % [dir, t.get_gust_warn_left()])
	_run(t, 0.6)
	_check("gust: the push into a forbidden cell is cancelled (the player stays)", state.player_cell == Vector2i(1, 1)
		and t.get_cancel_count() == 1 and t.get_push_count() == 0 and t.get_gust_dir() == Vector2i.ZERO, str(state.player_cell))
	t.teardown()


# A free board: every gust moves the player exactly 1 cell (or cancels at the edge) and keeps it inside its half.
func _test_gust_pushes_one_cell() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var state: CombatState = w["state"]
	var t: GustTrait = _make("gust", w, {"interval_sec": 2.0, "warn_sec": 0.5}) as GustTrait
	var grid: BoardGrid = w["grid"]
	var ok: bool = true
	var moved: int = 0
	for i: int in 12:
		var before: Vector2i = state.player_cell
		_run(t, 2.5)
		var delta: Vector2i = state.player_cell - before
		if delta != Vector2i.ZERO:
			moved += 1
		ok = ok and absi(delta.x) + absi(delta.y) <= 1 and grid.is_player_cell(state.player_cell)
	_check("gust: every gust moves the player 0 or 1 cell inside its half", ok and moved > 0 and t.get_push_count() == moved,
		"moved=%d pushes=%d" % [moved, t.get_push_count()])
	t.teardown()


# The forecast is off unless the boss is pinned or casting; the switch reaches the PlacementController through the host.
func _test_shroud_blocks_forecast_except_pinned_or_casting() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var status: StatusEffects = w["status"]
	var boss: BossController = w["boss"]
	var placement := PlacementController.new(w["grid"])
	var ctx: Dictionary = w["ctx"]
	ctx["placement"] = placement
	var host := TraitHost.new(ctx, [{"id": "shroud", "params": {}}], SEED)
	host.on_match_start()
	var cloud: ShroudTrait = host.get_trait("shroud") as ShroudTrait
	_check("shroud: forecast blocked by default (host + placement controller)", host.hit_forecast_blocked()
		and placement.forecast_blocked() and cloud.is_shrouding() and not cloud.is_cloud_lifted())
	status.pin(CombatState.Side.ENEMY, 1.0)
	_check("shroud: not blocked while the boss is pinned", not host.hit_forecast_blocked() and not placement.forecast_blocked()
		and cloud.is_cloud_lifted())
	status.tick(1.5, w["state"])
	_check("shroud: blocked again once the pin ends", placement.forecast_blocked())
	boss.get_actor().begin_swing([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i], SkillConfig.FALLBACK_SKILL, false, 1, 20.0)
	_check("shroud: not blocked while the boss is casting", not placement.forecast_blocked() and not cloud.is_shrouding())
	host.teardown_all()
	_check("shroud: teardown unwires the switch", not placement.forecast_blocked() and not placement.forecast_blocked_fn.is_valid())
	var plain: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var plain_host := TraitHost.new(plain["ctx"], [], SEED)
	_check("shroud: a match without the trait never blocks", not plain_host.hit_forecast_blocked())


# The real sky_isles arenas (twin_isles, three_isles): the trait's islands are ArenaValidator.island_cells (bridge cells
# removed, every island >= 2 cells); over a long run with a short interval the bridges never fall and at least one
# whole island always stands (never the last island); a half with a single island is left alone.
func _test_island_drop_never_the_last_island() -> void:
	var arenas: ArenaLibrary = ArenaLibrary.load_from_file()
	for id: String in ["twin_isles", "three_isles"]:
		var grid: BoardGrid = ArenaLibrary.grid_for_spec({"shape": id}, arenas, 0)
		var w: Dictionary = _world_on(grid)
		var hz: TileHazards = w["hazards"]
		var state: CombatState = w["state"]
		var t: IslandDropTrait = _make("island_drop", w, {"interval_sec": 2.0, "fall_sec": 4.0, "warn_sec": 1.2}) as IslandDropTrait
		var expected: Array = ArenaValidator.island_cells(grid, true)
		var bridges: Array[Vector2i] = ArenaValidator.bridge_cells(grid, true)
		var islands: Array = t.get_islands()
		var sizes_ok: bool = true
		var no_bridge_inside: bool = true
		for island: Variant in islands:
			sizes_ok = sizes_ok and (island as Array).size() >= 2
			for bridge: Vector2i in bridges:
				no_bridge_inside = no_bridge_inside and not (island as Array).has(bridge)
		_check("island_drop %s: islands = the arena's islands (bridges removed, each >= 2 cells)" % id,
			islands.size() == expected.size() and islands.size() >= 2 and sizes_ok and no_bridge_inside,
			"trait=%s arena=%s" % [islands, expected])
		_run(t, 1.9)
		_check("island_drop %s: nothing before interval_sec" % id, t.get_drop_count() == 0 and t.get_drop_cells().is_empty())
		t.on_tick(STEP)
		var cells: Array[Vector2i] = t.get_drop_cells()
		var in_one_island: bool = false
		for island: Variant in expected:
			var all_in: bool = not cells.is_empty()
			for cell: Vector2i in cells:
				all_in = all_in and (island as Array).has(cell)
			in_one_island = in_one_island or all_in
		_check("island_drop %s: the announced cells lie in ONE island, >= 2 cells, warn_sec" % id, t.get_drop_count() == 1
			and cells.size() >= 2 and in_one_island and absf(t.get_drop_warn_left() - 1.2) < EPS, "%s %f" % [cells, t.get_drop_warn_left()])
		var whole_island_stands: bool = true
		var bridges_stand: bool = true
		var fell_any: bool = false
		for i: int in 400:
			t.on_tick(STEP)
			hz.tick(STEP, state)
			var any_whole: bool = false
			for island: Variant in expected:
				var whole: bool = true
				for cell: Vector2i in island as Array:
					if hz.is_fallen(CombatState.Side.PLAYER, cell):
						whole = false
						fell_any = true
				any_whole = any_whole or whole
			if whole_island_stands and not any_whole:
				print("  island_drop %s: no whole island at step %d, fallen=%s" % [id, i, hz.fallen_cells(CombatState.Side.PLAYER)])
			whole_island_stands = whole_island_stands and any_whole
			for bridge: Vector2i in bridges:
				if bridges_stand and hz.is_fallen(CombatState.Side.PLAYER, bridge):
					print("  island_drop %s: bridge %s fell at step %d" % [id, bridge, i])
				bridges_stand = bridges_stand and not hz.is_fallen(CombatState.Side.PLAYER, bridge)
		_check("island_drop %s: an island really fell during the run" % id, fell_any)
		_check("island_drop %s: one whole island and every bridge always stand (never the last island)" % id,
			whole_island_stands and bridges_stand)
		t.teardown()

	var single: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var one: IslandDropTrait = _make("island_drop", single, {"interval_sec": 1.0}) as IslandDropTrait
	_run(one, 30.0)
	_check("island_drop: a half with one island never drops", one.get_drop_count() == 0
		and (single["hazards"] as TileHazards).fallen_cells(CombatState.Side.PLAYER).is_empty())
	one.teardown()


# A _world on a given arena grid (both units on the grid's default cells).
func _world_on(grid: BoardGrid) -> Dictionary:
	var w: Dictionary = _world(BoardGrid.NO_CELL, BoardGrid.NO_CELL, true, grid.side_cols, grid.rows)
	var state := CombatState.new(grid, 100.0, 1000.0)
	var hazards := TileHazards.new(grid, SEED)
	hazards.bind_state(state)
	var boss := BossController.new(
		state, grid, w["cut_config"], w["skill_config"], BossBrainConfig.load_from_file(), _idle_drops(),
		HoldSlotsConfig.new(), SEED
	)
	boss.set_active(true)
	var status := StatusEffects.new()
	var mover := UnitMover.new(state, CombatState.Side.PLAYER, 0.3)
	var ctx: Dictionary = {"state": state, "grid": grid, "status": status, "boss": boss, "player_mover": mover, "hazards": hazards}
	return {"grid": grid, "state": state, "status": status, "boss": boss, "mover": mover, "ctx": ctx, "hazards": hazards}


func _idle_drops() -> FieldDropsConfig:
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 1.0e9
	return drops_config


# phase_shift param vent_interval_mult scales the vent clock when phase 2 starts.
# B1 (2026-11-12): the warden hook sets interval_sec 7 with first_delay_sec 10 — the first surge keeps the boss's 10 s
# opening, the next ones come every 7 s. The hazards are ticked alongside so the vents are idle again for the second surge.
func _test_vent_surge_first_delay() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var hz: TileHazards = w["hazards"]
	var col1: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	var col2: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	hz.configure({"vent_interval_sec": 1000.0})  # the regular clock stays out of the way (set before the vents arm it)
	hz.set_vents(CombatState.Side.PLAYER, [col1, col2])
	var t: VentSurgeTrait = _make("vent_surge", w, {"interval_sec": 7.0, "first_delay_sec": 10.0, "vents": 2}) as VentSurgeTrait
	var state: CombatState = w["state"]
	var elapsed: float = 0.0
	while elapsed < 9.9 - EPS:
		t.on_tick(STEP)
		hz.tick(STEP, state)
		elapsed += STEP
	_check("vent_surge first_delay: no surge at 9.9 s", t.get_surge_count() == 0, "surges=%d" % t.get_surge_count())
	t.on_tick(STEP)
	hz.tick(STEP, state)
	elapsed += STEP
	_check("vent_surge first_delay: the first surge at 10 s starts both vents", t.get_surge_count() == 1 and t.get_last_count() == 2
		and hz.is_vent_warning(CombatState.Side.PLAYER, Vector2i(1, 1)) and hz.is_vent_warning(CombatState.Side.PLAYER, Vector2i(2, 1)),
		"surges=%d last=%d" % [t.get_surge_count(), t.get_last_count()])
	while elapsed < 16.9 - EPS:
		t.on_tick(STEP)
		hz.tick(STEP, state)
		elapsed += STEP
	_check("vent_surge first_delay: still one surge at 16.9 s (interval 7, not 10)", t.get_surge_count() == 1, "surges=%d" % t.get_surge_count())
	t.on_tick(STEP)
	hz.tick(STEP, state)
	elapsed += STEP
	_check("vent_surge first_delay: the second surge at 17 s (vents idle again after warn 1 s + burn 2 s)", t.get_surge_count() == 2 and t.get_last_count() == 2,
		"surges=%d last=%d" % [t.get_surge_count(), t.get_last_count()])
	t.teardown()


func _test_phase_shift_vent_interval_mult() -> void:
	var w: Dictionary = _world(Vector2i(1, 1), Vector2i(4, 1))
	var hz: TileHazards = w["hazards"]
	var state: CombatState = w["state"]
	var row0: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	hz.set_vents(CombatState.Side.PLAYER, [row0])
	var before: float = hz.vent_timer_left()
	var t: PhaseShiftTrait = _make("phase_shift", w, {"at_hp_ratio": 0.5, "extra_traits": [], "vent_interval_mult": 0.7}) as PhaseShiftTrait
	t.on_tick(STEP)
	_check("phase_shift: phase 1 leaves the vent clock alone", t.get_phase() == 1 and absf(hz.vent_timer_left() - before) < EPS)
	state.damage_enemy(600.0)
	t.on_boss_damaged(600.0)
	_check("phase_shift: phase 2 multiplies the vent interval by 0.7", t.get_phase() == 2
		and absf(hz.vent_timer_left() - before * 0.7) < EPS, "%f -> %f" % [before, hz.vent_timer_left()])
	t.teardown()

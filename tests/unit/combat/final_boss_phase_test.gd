extends SceneTree
## Story 035 Part F (F2): the `boss_phases` trait of the Ấn Đài final boss. One transition per threshold, once,
## in order; invulnerable for exactly phase_shift_sec; the boss's cast in progress is cancelled with no damage;
## phase 1 traits torn down and phase 2 traits live; brain set / step cooldown / cards / root flag switch; a
## single hit that would cross the threshold is clamped at it (phase 2 cannot be skipped); the player's cell,
## bag and field pieces are untouched; a missing phase field keeps the previous value. Pure trait world (no
## CombatView), own match params (no chapters.json data). Headless; FAILS=N. Deterministic: fixed seeds, no RNG.

const SEED: int = 35
const MAX_HP: float = 100.0
## Boundary values of the scenario (the exact numbers are the point).
const AT_RATIO: float = 0.5
const SHIFT_SEC: float = 1.0
const STEP: float = 0.25
const STEP_MULT_2: float = 0.85
const NAME_KEY_2: String = "phase.test_keeper.2"
const BIG_HIT: float = 90.0

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	_test_registry()
	_test_phase_one_at_start()
	_test_big_hit_clamped_and_phase_two()
	_test_invulnerable_for_shift_sec()
	_test_transition_once()
	_test_player_untouched()
	_test_three_phases_in_order()
	_test_missing_fields_keep_previous()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ fixtures

func _world() -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, MAX_HP, MAX_HP)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var drops_config := FieldDropsConfig.new()
	drops_config.initial_delay_sec = 100000.0
	var player_drops := FieldDrops.new(drops_config, grid.player_cells(), SEED)
	var boss := BossController.new(state, grid, cut_config, skill_config, BossBrainConfig.load_from_file(), drops_config,
		HoldSlotsConfig.new(), SEED + 1)
	var status := StatusEffects.new()
	boss.set_status(status)
	var player_actor := CutActor.new(cut_config, CombatState.Side.PLAYER)
	var arbiter := SwingArbiter.new(state, grid, player_actor, boss.get_actor(), cut_config, skill_config, status)
	var hold := HoldSlots.new(4)
	var mover := UnitMover.new(state, CombatState.Side.PLAYER, 0.0)
	var ctx: Dictionary = {
		"state": state, "grid": grid, "player_drops": player_drops, "boss_drops": boss.get_drops(),
		"boss": boss, "status": status, "arbiter": arbiter, "hold_getter": func() -> HoldSlots: return hold,
		"skill_config": skill_config, "cut_config": cut_config, "player_mover": mover,
	}
	return {"grid": grid, "state": state, "boss": boss, "status": status, "hold": hold, "player_drops": player_drops,
		"ctx": ctx, "skill_config": skill_config, "arbiter": arbiter}


# The F2 starting data: phase 1 seal_caster / balanced / root on; phase 2 at 50 % thorn_field + row_burner /
# aggressive / x0.85 / root off / the last boss card only.
func _phases(skill_config: SkillConfig) -> Array:
	var order: Array[String] = skill_config.boss_card_order()
	return [
		{"traits": [{"id": "seal_caster", "params": {}}], "brain_set": "balanced", "boss_step_cooldown_mult": 1.0,
			"root_while_swinging": true},
		{"at_hp_ratio": AT_RATIO, "phase_shift_sec": SHIFT_SEC, "name_key": NAME_KEY_2,
			"traits": [{"id": "thorn_field", "params": {}}, {"id": "row_burner", "params": {}}],
			"brain_set": "aggressive", "boss_step_cooldown_mult": STEP_MULT_2, "boss_cards": [order[order.size() - 1]],
			"root_while_swinging": false},
	]


func _host(w: Dictionary, phases: Array) -> TraitHost:
	var host := TraitHost.new(w["ctx"], [{"id": "boss_phases", "params": {"phases": phases}}], SEED)
	host.on_match_start()
	return host


func _trait(host: TraitHost) -> BossPhasesTrait:
	return host.get_trait(BossPhasesTrait.ID) as BossPhasesTrait


# A boss swing over the whole player half (lasts long enough to still run after the transition).
func _boss_swing(w: Dictionary) -> void:
	var grid: BoardGrid = w["grid"]
	var boss: BossController = w["boss"]
	boss.get_actor().begin_swing(grid.player_cells(), SkillConfig.FALLBACK_SKILL, false, 1, 5.0)


func _hit(w: Dictionary, host: TraitHost, amount: float) -> void:
	(w["state"] as CombatState).damage_enemy(amount)
	host.on_boss_damaged(amount)


# ------------------------------------------------------------------ tests

func _test_registry() -> void:
	_check("registry creates boss_phases", TraitRegistry.create("boss_phases") is BossPhasesTrait)


func _test_phase_one_at_start() -> void:
	# Arrange / Act
	var w: Dictionary = _world()
	var host := _host(w, _phases(w["skill_config"]))
	var t: BossPhasesTrait = _trait(host)
	var boss: BossController = w["boss"]
	var state: CombatState = w["state"]
	# Assert
	_check("start: phase 1", t.get_phase() == 1 and t.get_phase_count() == 2)
	_check("start: phase 1 trait seal_caster live", host.get_ids() == (["boss_phases", "seal_caster"] as Array[String]), str(host.get_ids()))
	_check("start: brain set balanced", boss.get_brain().get_set_name() == "balanced", boss.get_brain().get_set_name())
	_check("start: HP floor at the phase 2 threshold", is_equal_approx(state.enemy_hp_floor, AT_RATIO * MAX_HP), str(state.enemy_hp_floor))
	_boss_swing(w)
	_check("start: root_while_swinging on", boss.is_step_locked())
	_check("start: not invulnerable", not t.is_invulnerable())


func _test_big_hit_clamped_and_phase_two() -> void:
	# Arrange
	var w: Dictionary = _world()
	var host := _host(w, _phases(w["skill_config"]))
	var t: BossPhasesTrait = _trait(host)
	var boss: BossController = w["boss"]
	var state: CombatState = w["state"]
	var seen: Array = []
	host.phase_changed.connect(func(p: int) -> void: seen.append(p))
	var base_mult: float = boss.get_mover().cooldown_mult
	_boss_swing(w)
	var player_hp: float = state.player_hp
	# Act: one hit that would carry the boss from 100 % to 10 %.
	_hit(w, host, BIG_HIT)
	# Assert
	_check("big hit clamped at the threshold", is_equal_approx(state.enemy_hp, AT_RATIO * MAX_HP), str(state.enemy_hp))
	_check("big hit enters phase 2 (not skipped)", t.get_phase() == 2 and seen == [2], str(seen))
	_check("phase 2: boss cast cancelled", not boss.get_actor().is_swinging() and not boss.get_actor().has_queued())
	(w["arbiter"] as SwingArbiter).tick(6.0)
	_check("phase 2: the cancelled cast dealt no damage", is_equal_approx(state.player_hp, player_hp))
	var ids: Array[String] = host.get_ids()
	_check("phase 2: seal_caster torn down", not ids.has("seal_caster"), str(ids))
	_check("phase 2: thorn_field and row_burner live", ids.has("thorn_field") and ids.has("row_burner"), str(ids))
	_check("phase 2: brain set aggressive", boss.get_brain().get_set_name() == "aggressive")
	_check("phase 2: step cooldown x0.85 of the base", is_equal_approx(boss.get_mover().cooldown_mult, base_mult * STEP_MULT_2))
	var order: Array[String] = (w["skill_config"] as SkillConfig).boss_card_order()
	_check("phase 2: boss cards switched", boss.get_brain().cards == ([order[order.size() - 1]] as Array[String]), str(boss.get_brain().cards))
	_boss_swing(w)
	_check("phase 2: root_while_swinging off", not boss.is_step_locked())
	_check("phase 2: name key for the banner", t.get_phase_name_key() == NAME_KEY_2)
	_check("phase 2: last phase, floor 0", is_equal_approx(state.enemy_hp_floor, 0.0))


func _test_invulnerable_for_shift_sec() -> void:
	# Arrange
	var w: Dictionary = _world()
	var host := _host(w, _phases(w["skill_config"]))
	var t: BossPhasesTrait = _trait(host)
	var state: CombatState = w["state"]
	var boss: BossController = w["boss"]
	_hit(w, host, BIG_HIT)
	# Act / Assert: damage ignored until SHIFT_SEC has passed.
	_check("shift: invulnerable at once", t.is_invulnerable() and is_equal_approx(state.enemy_invulnerable_left, SHIFT_SEC))
	_check("shift: boss decisions paused", not boss.is_active())
	_hit(w, host, 10.0)
	_check("shift: damage ignored, HP unchanged", is_equal_approx(state.enemy_hp, AT_RATIO * MAX_HP), str(state.enemy_hp))
	var ticks: int = roundi(SHIFT_SEC / STEP)
	for i: int in ticks - 1:
		host.on_tick(STEP)
	_check("shift: still invulnerable just before the end", t.is_invulnerable())
	host.on_tick(STEP)
	_check("shift: over after exactly phase_shift_sec", not t.is_invulnerable() and boss.is_active())
	_hit(w, host, 10.0)
	_check("shift: damage lands again", is_equal_approx(state.enemy_hp, AT_RATIO * MAX_HP - 10.0), str(state.enemy_hp))


func _test_transition_once() -> void:
	# Arrange
	var w: Dictionary = _world()
	var host := _host(w, _phases(w["skill_config"]))
	var seen: Array = []
	host.phase_changed.connect(func(p: int) -> void: seen.append(p))
	_hit(w, host, BIG_HIT)
	for i: int in 8:
		host.on_tick(STEP)
	# Act: more hits and ticks below the threshold.
	_hit(w, host, 5.0)
	host.on_tick(STEP)
	_hit(w, host, 5.0)
	# Assert
	_check("transition fires once", seen == [2] and _trait(host).get_phase() == 2, str(seen))
	_check("phase 2 traits not duplicated", host.get_ids().count("row_burner") == 1, str(host.get_ids()))


func _test_player_untouched() -> void:
	# Arrange
	var w: Dictionary = _world()
	var host := _host(w, _phases(w["skill_config"]))
	var state: CombatState = w["state"]
	var hold: HoldSlots = w["hold"]
	var drops: FieldDrops = w["player_drops"]
	var point := FieldPoint.new()
	point.label = "test"
	hold.place_in_first_free(point)
	drops.debug_place("lie", Vector2i(0, 0), 50.0)
	var cell: Vector2i = state.player_cell
	# Act
	_hit(w, host, BIG_HIT)
	# Assert
	_check("player cell untouched", state.player_cell == cell)
	_check("player bag untouched", hold.get_occupied_count() == 1 and hold.get_point(0) == point)
	_check("player field pieces untouched", drops.get_points().size() == 1)


func _test_three_phases_in_order() -> void:
	# Arrange
	var w: Dictionary = _world()
	var state: CombatState = w["state"]
	var host := _host(w, [
		{"brain_set": "balanced"},
		{"at_hp_ratio": 0.6, "phase_shift_sec": 0.5},
		{"at_hp_ratio": 0.3, "phase_shift_sec": 0.5},
	])
	var seen: Array = []
	host.phase_changed.connect(func(p: int) -> void: seen.append(p))
	# Act / Assert: each lethal-sized hit stops at the next threshold.
	_hit(w, host, MAX_HP)
	_check("3 phases: first hit stops at 60", is_equal_approx(state.enemy_hp, 60.0) and seen == [2], str([state.enemy_hp, seen]))
	host.on_tick(0.5)
	_hit(w, host, MAX_HP)
	_check("3 phases: second hit stops at 30", is_equal_approx(state.enemy_hp, 30.0) and seen == [2, 3], str([state.enemy_hp, seen]))
	host.on_tick(0.5)
	_hit(w, host, MAX_HP)
	_check("3 phases: last phase can die", state.is_enemy_dead() and seen == [2, 3], str([state.enemy_hp, seen]))


func _test_missing_fields_keep_previous() -> void:
	# Arrange
	var w: Dictionary = _world()
	var boss: BossController = w["boss"]
	var host := _host(w, [
		{"traits": [{"id": "seal_caster", "params": {}}], "brain_set": "aggressive"},
		{"at_hp_ratio": AT_RATIO, "phase_shift_sec": 0.0},
	])
	# Act
	_hit(w, host, BIG_HIT)
	# Assert
	_check("missing traits: phase 1 traits kept", host.get_ids() == (["boss_phases", "seal_caster"] as Array[String]), str(host.get_ids()))
	_check("missing brain_set: kept", boss.get_brain().get_set_name() == "aggressive")
	_check("phase_shift_sec 0: no invulnerability, boss not paused", not _trait(host).is_invulnerable() and boss.is_active())

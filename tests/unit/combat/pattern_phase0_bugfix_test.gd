extends SceneTree
## Monster Skill Phase 0 (docs/design/world-map-v2/MONSTER-SKILL-DESIGN.md §1.3 G1-G3): regression tests for the three
## audit bugs.
## - G1: a pattern strike on a player with Rạn (fragile) multiplies its damage and spends the stack (the block boss's casts
##   did through CutEffects; PatternController._resolve_cells did not).
## - G2: a pattern status `frost` that reaches the burst threshold DEALS the burst (apply_frost's return value was thrown
##   away), plus the Phase 0 per-side burst cooldown (StatusEffects.frost_burst_icd, off by default).
## - G3: StatusEffects.reaction_immune_fn was never bound: TraitHost binds it; a trait's reaction_immune() and a pattern
##   enemy's `immune_reactions` both answer through it.
## Pure logic, no file I/O. Run: godot --headless --path . -s res://tests/unit/combat/pattern_phase0_bugfix_test.gd

const Fx = preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05

var fails: int = 0


class ImmuneR3Trait extends BossTrait:
	func get_id() -> String:
		return "test_immune_r3"
	func reaction_immune(_side: int, id: String) -> bool:
		return id == "r3"


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_g1_fragile_multiplies_pattern_damage_and_spends_stack()
	test_g1_no_fragile_keeps_base_damage()
	test_g2_frost_burst_damages_player()
	test_g2_frost_burst_icd_holds_stacks()
	test_g3_trait_host_binds_reaction_immunity()
	test_g3_pattern_enemy_immune_reactions()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# One attack skill "hit" (1 cell on the player, [param effects]) for enemy "solo" (no AI noise).
func _config(effects: Dictionary, extra: Dictionary = {}) -> EnemySkillsConfig:
	var skill: Dictionary = {"pattern": {"offsets": [[0, 0]], "anchor": "on_player"}, "windup_sec": 0.4, "warning_sec": 0.9,
		"delivery": Fx.DM, "effects": effects, "recovery_sec": 0.6, "cooldown_sec": 3.0}
	for k: String in extra:
		skill[k] = extra[k]
	return EnemySkillsConfig.from_dictionary({"skills": {"hit": skill}, "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": ["hit"]}}})


func _world(config: EnemySkillsConfig) -> Dictionary:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), config, "solo", 7)
	# combat.json numbers: Rạn x1.5 (3 stacks max), Hàn bursts at 3 stacks for 24.
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)
	return w


func _tick_until(w: Dictionary, stage: int, limit: float = 5.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		ctrl.tick(STEP)
		t += STEP
		if ctrl.get_stage() == stage:
			return true
	return false


func test_g1_fragile_multiplies_pattern_damage_and_spends_stack() -> void:
	# Arrange: a player with 1 Rạn, a strike of 8.
	var w: Dictionary = _world(_config({"damage": 8}))
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	status.apply_fragile(P, 1)
	# Act: the player stands still and takes the strike.
	_tick_until(w, PatternController.Stage.WARNING)
	_tick_until(w, PatternController.Stage.RECOVERY)
	# Assert: 8 x 1.5 = 12, the stack spent, the result says so.
	_check("G1: 8 damage x1.5 Rạn = 12", is_equal_approx(state.player_hp, 88.0), str(state.player_hp))
	_check("G1: the Rạn stack is spent", status.fragile_stacks(P) == 0)
	var last: Dictionary = (w["ctrl"] as PatternController).event_log.back()
	_check("G1: event log records 12 damage", is_equal_approx(float(last["damage"]), 12.0), str(last))


func test_g1_no_fragile_keeps_base_damage() -> void:
	var w: Dictionary = _world(_config({"damage": 8}))
	var state: CombatState = w["state"]
	_tick_until(w, PatternController.Stage.WARNING)
	_tick_until(w, PatternController.Stage.RECOVERY)
	_check("G1: without Rạn the strike stays 8", is_equal_approx(state.player_hp, 92.0), str(state.player_hp))


func test_g2_frost_burst_damages_player() -> void:
	# Arrange: a 0-damage strike that applies 3 Hàn at once (the threshold).
	var w: Dictionary = _world(_config({"damage": 0, "status": {"id": "frost", "stacks": 3}}))
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var bursts: Array = []
	status.frost_burst.connect(func(side: int, dmg: float) -> void: bursts.append([side, dmg]))
	# Act
	_tick_until(w, PatternController.Stage.WARNING)
	_tick_until(w, PatternController.Stage.RECOVERY)
	# Assert: the burst (24) reached the player's HP; the stacks are gone.
	_check("G2: the Hàn burst deals 24 to the player", is_equal_approx(state.player_hp, 76.0), str(state.player_hp))
	_check("G2: stacks cleared after the burst", status.frost_stacks(P) == 0)
	_check("G2: frost_burst emitted for the player side", bursts.size() == 1 and int(bursts[0][0]) == P and is_equal_approx(float(bursts[0][1]), 24.0))
	var last: Dictionary = (w["ctrl"] as PatternController).event_log.back()
	_check("G2: the strike's logged damage includes the burst", is_equal_approx(float(last["damage"]), 24.0), str(last))


func test_g2_frost_burst_icd_holds_stacks() -> void:
	# Arrange: the per-side burst cooldown of 10 s (design §9.2), a plain book.
	var status: StatusEffects = StatusEffects.new()
	status.configure_keywords(1.5, 3, 3, 24.0)
	status.frost_burst_icd[P] = 10.0
	var state: CombatState = CombatState.new(BoardGrid.new(3, 3), 100.0, 100.0)
	# Act / Assert: the first burst fires; the second within 10 s is held one stack below the threshold.
	_check("ICD: first burst fires", is_equal_approx(status.apply_frost(P, 3), 24.0))
	_check("ICD: second burst inside the cooldown returns 0", is_equal_approx(status.apply_frost(P, 3), 0.0))
	_check("ICD: stacks capped at threshold - 1", status.frost_stacks(P) == 2, str(status.frost_stacks(P)))
	status.tick(10.0, state)
	_check("ICD: after 10 s a new stack bursts again", is_equal_approx(status.apply_frost(P, 1), 24.0) and status.frost_stacks(P) == 0)
	# The enemy side has no cooldown entry: unchanged behaviour.
	_check("ICD: a side without an entry bursts every time", is_equal_approx(status.apply_frost(E, 3), 24.0) and is_equal_approx(status.apply_frost(E, 3), 24.0))


func test_g3_trait_host_binds_reaction_immunity() -> void:
	# Arrange: a book with no host: the hook is unbound, every reaction is allowed (the pre-fix behaviour, kept).
	var status: StatusEffects = StatusEffects.new()
	var state: CombatState = CombatState.new(BoardGrid.new(3, 3), 100.0, 100.0)
	_check("G3: no host = hook unbound", not status.reaction_immune_fn.is_valid())
	_check("G3: no host = r3 allowed", status.reaction_allowed(E, "r3"))
	# Act: a host with a trait that is immune to r3.
	var host: TraitHost = TraitHost.new({"status": status, "state": state}, [], 3)
	var immune: ImmuneR3Trait = ImmuneR3Trait.new()
	immune.setup({"status": status, "state": state}, {}, 3)
	host.debug_add_trait(immune)
	status.tick(2.0, state)  # past the 1 s ICD of the r3 above
	# Assert
	_check("G3: the host bound StatusEffects.reaction_immune_fn", status.reaction_immune_fn.is_valid())
	_check("G3: the trait's immunity blocks r3 on the enemy", not status.reaction_allowed(E, "r3"))
	_check("G3: r1 / r2 still fire", status.reaction_allowed(E, "r1") and status.reaction_allowed(E, "r2"))
	host.teardown_all()
	_check("G3: teardown unbinds the hook", not status.reaction_immune_fn.is_valid())


func test_g3_pattern_enemy_immune_reactions() -> void:
	# Arrange: enemy data lists immune_reactions ["r1", "bogus"]: r1 kept, bogus dropped with a problem line.
	var data: Dictionary = {"skills": Fx.skills(), "enemies": {"ghost": {"skills": ["fx_1"], "immune_reactions": ["r1", "bogus"]}}}
	var config: EnemySkillsConfig = EnemySkillsConfig.from_dictionary(data)
	_check("G3: unknown reaction id reported", config.problems.size() == 1 and config.problems[0].contains("bogus"), str(config.problems))
	_check("G3: r1 kept on the enemy", (config.get_enemy("ghost")["immune_reactions"] as Array) == ["r1"])
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), config, "ghost", 1)
	var ctrl: PatternController = w["ctrl"]
	var status: StatusEffects = w["status"]
	var host: TraitHost = TraitHost.new({"status": status, "state": w["state"]}, [], 1)
	host.extra_reaction_immune_fn = Callable(ctrl, "reaction_immune")
	# Act / Assert: the enemy is immune to r1 only; the player never is.
	_check("G3: pattern enemy immune to r1", not status.reaction_allowed(E, "r1"))
	_check("G3: pattern enemy not immune to r2", status.reaction_allowed(E, "r2"))
	_check("G3: the player is never immune", status.reaction_allowed(P, "r1"))
	_check("G3: an enemy without the key is not immune", not ctrl.reaction_immune(E, "r2") and not PatternController.new(w["state"], BoardGrid.new(3, 3), Fx.config(), "fx_single", status, 1).reaction_immune(E, "r1"))

extends SceneTree
## Monster Skill Phase 0 (G6): PatternController.set_active pause / resume: a pause mid-windup / warning cancels the skill
## (red off, cooldown x cancel ratio, event "paused") and freezes every clock; a pause in RECOVERY keeps its timer; a
## resume continues from the frozen clocks and never casts twice; interrupts while paused do nothing; the burrow and
## rebirth traits pause the controller through the ctx `pattern_getter` (burrow waits for a skill in progress).
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_phase0_pause_test.gd

const Fx = preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const EPS: float = 0.001

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_pause_mid_warning_cancels_and_freezes()
	test_pause_in_recovery_keeps_timer()
	test_resume_casts_once_and_is_idempotent()
	test_interrupt_while_paused_does_nothing()
	test_burrow_pauses_pattern_and_waits_for_skill()
	test_rebirth_pauses_pattern()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _config(cooldown: float = 3.0, recovery: float = 0.6) -> EnemySkillsConfig:
	var skill: Dictionary = {"pattern": {"offsets": [[0, 0]], "anchor": "on_player"}, "windup_sec": 0.4, "warning_sec": 0.9,
		"delivery": Fx.DM, "effects": {"damage": 8}, "recovery_sec": recovery, "cooldown_sec": cooldown}
	return EnemySkillsConfig.from_dictionary({"skills": {"hit": skill}, "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": ["hit"]}}})


func _world(config: EnemySkillsConfig = _config()) -> Dictionary:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), config, "solo", 3)
	var warnings: Array = []
	(w["ctrl"] as PatternController).warning_started.connect(func(id: String, _c: Array[Vector2i], _q: Array[Vector2i], _s: float) -> void: warnings.append(id))
	w["warnings"] = warnings
	return w


func _run(w: Dictionary, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds - 0.000001:
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		(w["ctrl"] as PatternController).tick(STEP)
		t += STEP


func _tick_until(w: Dictionary, stage: int, limit: float = 5.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		_run(w, STEP)
		t += STEP
		if ctrl.get_stage() == stage:
			return true
	return false


func _events(ctrl: PatternController, name: String) -> int:
	var n: int = 0
	for e: Dictionary in ctrl.event_log:
		if str(e.get("event", "")) == name:
			n += 1
	return n


func test_pause_mid_warning_cancels_and_freezes() -> void:
	# Arrange: a warning in progress.
	var w: Dictionary = _world()
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	_check("warning starts", _tick_until(w, PatternController.Stage.WARNING))
	# Act
	ctrl.set_active(false)
	# Assert: the skill is cancelled like an interrupt, the red is gone, the cooldown is the cancel share (3 x 0.5).
	_check("pause: inactive, idle, no skill, red off", not ctrl.is_active() and ctrl.get_stage() == PatternController.Stage.IDLE
		and ctrl.get_current_skill().is_empty() and ctrl.telegraph_cells().is_empty())
	_check("pause: cooldown x cancel ratio", is_equal_approx(ctrl.cooldown_left("hit"), 1.5), str(ctrl.cooldown_left("hit")))
	_check("pause: logged", _events(ctrl, "paused") == 1 and _events(ctrl, "pause") == 1)
	# Frozen: 5 s pass, nothing moves (no cooldown tick, no warning, no damage to a player standing still).
	_run(w, 5.0)
	_check("pause: cooldown frozen", is_equal_approx(ctrl.cooldown_left("hit"), 1.5), str(ctrl.cooldown_left("hit")))
	_check("pause: no new warning, no damage", (w["warnings"] as Array).size() == 1 and is_equal_approx(state.player_hp, 100.0))


func test_pause_in_recovery_keeps_timer() -> void:
	var w: Dictionary = _world(_config(3.0, 1.0))
	var ctrl: PatternController = w["ctrl"]
	_tick_until(w, PatternController.Stage.RECOVERY)
	_run(w, 0.3)
	ctrl.set_active(false)
	_run(w, 3.0)
	_check("pause in recovery: still recovering (timer frozen)", ctrl.get_stage() == PatternController.Stage.RECOVERY)
	ctrl.set_active(true)
	_run(w, 0.5)
	_check("resume: recovery still running (0.3 + 0.5 < 1.0)", ctrl.get_stage() == PatternController.Stage.RECOVERY)
	_run(w, 0.3)
	_check("resume: recovery ends on the frozen clock (0.3 + 0.8 >= 1.0)", ctrl.get_stage() == PatternController.Stage.IDLE)


func test_resume_casts_once_and_is_idempotent() -> void:
	# Arrange: paused mid-warning (cooldown 1.5 frozen), then resumed.
	var w: Dictionary = _world()
	var ctrl: PatternController = w["ctrl"]
	_tick_until(w, PatternController.Stage.WARNING)
	ctrl.set_active(false)
	ctrl.set_active(false)
	_check("idempotent: a second pause logs nothing", _events(ctrl, "pause") == 1)
	# Act: resume; the next warning comes after the frozen cooldown (1.5) + think + windup, ONCE.
	ctrl.set_active(true)
	ctrl.set_active(true)
	_check("idempotent: a second resume logs nothing", _events(ctrl, "resume") == 1)
	_run(w, 1.4)
	_check("resume: no warning before the cooldown ran out", (w["warnings"] as Array).size() == 1)
	_check("resume: next warning after the cooldown", _tick_until(w, PatternController.Stage.WARNING, 2.0))
	_check("resume: exactly one new warning", (w["warnings"] as Array).size() == 2, str((w["warnings"] as Array).size()))
	_tick_until(w, PatternController.Stage.RECOVERY)
	_check("resume: the strike resolves once", _events(ctrl, "resolve") == 1)


func test_interrupt_while_paused_does_nothing() -> void:
	var w: Dictionary = _world()
	var ctrl: PatternController = w["ctrl"]
	_tick_until(w, PatternController.Stage.WINDUP)
	ctrl.set_active(false)
	_check("paused: on_enemy_hit cancels nothing (no skill)", not ctrl.on_enemy_hit())
	var stunned: Array = []
	ctrl.stunned.connect(func(sec: float) -> void: stunned.append(sec))
	ctrl.on_player_cast([Vector2i(4, 1)] as Array[Vector2i])
	_check("paused: a cast over the enemy breaks nothing and stuns nothing", stunned.is_empty())
	ctrl.set_active(true)
	_check("resumed: idle, ready to think again", ctrl.get_stage() == PatternController.Stage.IDLE)


# A trait context with the pattern controller behind `pattern_getter` (what CombatView.make_trait_ctx provides).
func _trait_ctx(w: Dictionary) -> Dictionary:
	var ctrl: PatternController = w["ctrl"]
	var grid: BoardGrid = (w["state"] as CombatState).grid
	return {"state": w["state"], "grid": grid, "status": w["status"], "pattern_getter": func() -> PatternController: return ctrl}


func test_burrow_pauses_pattern_and_waits_for_skill() -> void:
	var w: Dictionary = _world()
	var ctrl: PatternController = w["ctrl"]
	var t: BurrowTrait = TraitRegistry.create("burrow") as BurrowTrait
	t.setup(_trait_ctx(w), {"interval_sec": 1.0, "burrow_sec": 1.5, "surface_warn_sec": 0.5}, 3)
	t.on_match_start()
	# The controller is busy (windup) when the burrow is due: the trait waits.
	_tick_until(w, PatternController.Stage.WINDUP)
	for i: int in 20:
		t.on_tick(STEP)
	_check("burrow: waits while the pattern skill runs", not t.is_burrowed() and ctrl.is_active())
	# Let the skill end (resolve + recovery), then the burrow fires at once.
	_tick_until(w, PatternController.Stage.IDLE, 3.0)
	t.on_tick(STEP)
	_check("burrow: burrowed once idle, the pattern paused", t.is_burrowed() and not ctrl.is_active())
	# 1.5 s underground: the controller's clocks stand still (cooldown unchanged).
	var cd: float = ctrl.cooldown_left("hit")
	for i: int in 30:
		_run(w, STEP)
		t.on_tick(STEP)
	_check("burrow: surfaced, pattern active again", not t.is_burrowed() and ctrl.is_active())
	_check("burrow: the cooldown did not tick underground", is_equal_approx(ctrl.cooldown_left("hit"), cd), "%s %s" % [cd, ctrl.cooldown_left("hit")])
	t.teardown()


func test_rebirth_pauses_pattern() -> void:
	var w: Dictionary = _world()
	var ctrl: PatternController = w["ctrl"]
	var state: CombatState = w["state"]
	var t: RebirthTrait = TraitRegistry.create("rebirth") as RebirthTrait
	t.setup(_trait_ctx(w), {"revive_ratio": 0.4, "revive_sec": 1.0}, 3)
	t.on_match_start()
	state.enemy_death_hook_fn = Callable(t, "on_boss_would_die")
	_tick_until(w, PatternController.Stage.WARNING)
	# Act: a lethal blow mid-warning.
	state.damage_enemy(state.enemy_hp + 100.0)
	_check("rebirth: held at 1 HP, reviving", t.is_reviving() and not state.is_enemy_dead())
	_check("rebirth: the pattern is paused and its warning cancelled", not ctrl.is_active() and ctrl.get_stage() == PatternController.Stage.IDLE and ctrl.telegraph_cells().is_empty())
	for i: int in 20:
		_run(w, STEP)
		t.on_tick(STEP)
	_check("rebirth: back with 40 % HP, pattern active", not t.is_reviving() and is_equal_approx(state.enemy_hp, state.enemy_max_hp * 0.4) and ctrl.is_active(), str(state.enemy_hp))
	t.teardown()

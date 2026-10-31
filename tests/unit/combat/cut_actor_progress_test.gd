extends SceneTree
## Story 046 Part C: CutActor.get_progress() = 1 - time_left / duration of the running swing, where duration is
## the windup stored at begin_swing AFTER every override and multiplier (duration_mult, duration_modifier,
## duration_override, cast_time_modifier); 0 when idle. The boss's floor telegraph fades in with it.
## Run: godot --headless --path . -s res://tests/unit/combat/cut_actor_progress_test.gd

const EPS: float = 0.0001
const SIDE: int = 1
const SKILL: String = "kiem_khi"
## A windup override (s) and a boss swing-speed multiplier, as Stories 023 / 013 use them.
const OVERRIDE_SEC: float = 2.0
const MULT: float = 1.5
## Story 018 passive / Story 032 relic stand-ins: each scales the windup.
const MODIFIER_SCALE: float = 0.5
const RELIC_SCALE: float = 0.8

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_idle_actor_progress_is_zero()
	test_progress_zero_at_start()
	test_progress_half_after_half_the_windup()
	test_progress_one_at_the_last_instant()
	test_progress_zero_after_resolve()
	test_progress_zero_after_cancel()
	test_progress_with_duration_override_uses_the_override()
	test_progress_with_duration_mult_uses_the_scaled_windup()
	test_progress_with_modifier_callables_uses_the_final_windup()
	test_progress_queued_swing_starts_at_zero_with_its_own_duration()
	test_debug_set_progress_moves_time_left()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _actor() -> CutActor:
	return CutActor.new(CutConfig.new(), SIDE)


func _cells(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in count:
		out.append(Vector2i(i, 0))
	return out


func test_idle_actor_progress_is_zero() -> void:
	# Arrange
	var actor: CutActor = _actor()
	# Act / Assert
	_check("test_idle_actor_progress_is_zero", actor.get_progress() == 0.0)


func test_progress_zero_at_start() -> void:
	# Arrange
	var actor: CutActor = _actor()
	# Act
	actor.begin_swing(_cells(3), SKILL, false)
	# Assert
	_check("test_progress_zero_at_start", is_equal_approx(actor.get_progress(), 0.0), str(actor.get_progress()))


func test_progress_half_after_half_the_windup() -> void:
	# Arrange
	var actor: CutActor = _actor()
	actor.begin_swing(_cells(3), SKILL, false)
	# Act
	actor.tick(actor.get_duration() * 0.5)
	# Assert
	_check("test_progress_half_after_half_the_windup", absf(actor.get_progress() - 0.5) < EPS, str(actor.get_progress()))


func test_progress_one_at_the_last_instant() -> void:
	# Arrange
	var actor: CutActor = _actor()
	actor.begin_swing(_cells(3), SKILL, false)
	# Act: everything but a sliver, then the sliver (time left 0 = the hit lands; the actor resolves).
	actor.tick(actor.get_duration() - EPS * 0.01)
	var almost: float = actor.get_progress()
	# Assert
	_check("test_progress_reaches_one_at_the_last_instant", almost > 1.0 - EPS and almost <= 1.0, str(almost))


func test_progress_zero_after_resolve() -> void:
	# Arrange
	var actor: CutActor = _actor()
	actor.begin_swing(_cells(3), SKILL, false)
	# Act
	actor.tick(actor.get_duration() + 1.0)
	# Assert
	_check("test_progress_zero_after_resolve", not actor.is_swinging() and actor.get_progress() == 0.0)


func test_progress_zero_after_cancel() -> void:
	# Arrange
	var actor: CutActor = _actor()
	actor.begin_swing(_cells(3), SKILL, false)
	actor.tick(actor.get_duration() * 0.5)
	# Act
	actor.cancel()
	# Assert
	_check("test_progress_zero_after_cancel", actor.get_progress() == 0.0)


func test_progress_with_duration_override_uses_the_override() -> void:
	# Arrange
	var actor: CutActor = _actor()
	actor.begin_swing(_cells(3), SKILL, false, 1, OVERRIDE_SEC)
	# Act
	actor.tick(OVERRIDE_SEC * 0.25)
	# Assert: a quarter of the OVERRIDE windup, not of the cell-count windup.
	_check("test_progress_with_duration_override_is_quarter", absf(actor.get_progress() - 0.25) < EPS,
		"progress=%f duration=%f" % [actor.get_progress(), actor.get_duration()])


func test_progress_with_duration_mult_uses_the_scaled_windup() -> void:
	# Arrange
	var actor: CutActor = _actor()
	var base: float = CutConfig.new().swing_duration(3)
	actor.duration_mult = MULT
	actor.begin_swing(_cells(3), SKILL, false)
	# Act: half the UNSCALED windup is a third of the scaled one.
	actor.tick(base * 0.5)
	# Assert
	var expected: float = 0.5 / MULT
	_check("test_progress_with_duration_mult_uses_scaled_windup", absf(actor.get_progress() - expected) < EPS,
		"progress=%f expected=%f" % [actor.get_progress(), expected])


func test_progress_with_modifier_callables_uses_the_final_windup() -> void:
	# Arrange
	var actor: CutActor = _actor()
	var base: float = CutConfig.new().swing_duration(2)
	actor.duration_modifier = func(_cells_n: int, sec: float) -> float: return sec * MODIFIER_SCALE
	actor.cast_time_modifier = func(_cells_n: int, sec: float) -> float: return sec * RELIC_SCALE
	actor.begin_swing(_cells(2), SKILL, true)
	var final_sec: float = base * MODIFIER_SCALE * RELIC_SCALE
	# Act
	actor.tick(final_sec * 0.5)
	# Assert
	_check("test_modifiers_final_windup_stored", absf(actor.get_duration() - final_sec) < EPS)
	_check("test_progress_with_modifiers_is_half", absf(actor.get_progress() - 0.5) < EPS, str(actor.get_progress()))


func test_progress_queued_swing_starts_at_zero_with_its_own_duration() -> void:
	# Arrange
	var actor: CutActor = _actor()
	actor.begin_swing(_cells(1), SKILL, false)
	actor.queue_swing(_cells(2), SKILL, false, OVERRIDE_SEC)
	# Act: resolve swing 1, the queued one starts.
	actor.tick(actor.get_duration())
	var at_start: float = actor.get_progress()
	actor.tick(OVERRIDE_SEC * 0.5)
	# Assert
	_check("test_queued_swing_progress_zero_at_start", actor.is_swinging() and is_equal_approx(at_start, 0.0), str(at_start))
	_check("test_queued_swing_progress_half", absf(actor.get_progress() - 0.5) < EPS, str(actor.get_progress()))


func test_debug_set_progress_moves_time_left() -> void:
	# Arrange
	var actor: CutActor = _actor()
	actor.begin_swing(_cells(3), SKILL, false)
	# Act
	actor.debug_set_progress(0.5)
	# Assert
	_check("test_debug_set_progress_half", absf(actor.get_progress() - 0.5) < EPS
		and absf(actor.get_time_left() - actor.get_duration() * 0.5) < EPS)
	actor.debug_set_progress(1.0)
	_check("test_debug_set_progress_one", is_equal_approx(actor.get_progress(), 1.0) and actor.is_swinging())

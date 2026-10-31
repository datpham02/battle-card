extends SceneTree
## Story 046 Part C: the telegraph's pure functions in CombatConfig (combat.json `telegraph` block): fill / stripe /
## edge alphas lerped over progress k, the reduce-motion quantizer (three levels 0 / 0.5 / 1, thresholds 1/3 and
## 2/3), monotonic in k; plus TelegraphPainter.state_for on a CutActor (no node needed).
## Run: godot --headless --path . -s res://tests/unit/combat/telegraph_alpha_test.gd

const EPS: float = 0.0001
## Boundary values of the quantizer (the exact numbers are the point).
const QUANTIZE_CASES: Array = [[0.0, 0.0], [0.32, 0.0], [0.34, 0.5], [0.66, 0.5], [0.67, 1.0], [1.0, 1.0]]
const MONOTONIC_STEPS: int = 100

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var shipped: CombatConfig = CombatConfig.load_from_file()
	test_shipped_json_matches_the_spec(shipped)
	test_alphas_at_zero_half_one(shipped)
	test_quantize_continuous_without_reduce_motion(shipped)
	test_quantize_three_steps_with_reduce_motion(shipped)
	test_alphas_monotonic_non_decreasing(shipped)
	test_invalid_block_falls_back_to_defaults()
	test_state_for_idle_and_running_and_queued(shipped)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


func test_shipped_json_matches_the_spec(config: CombatConfig) -> void:
	# Arrange / Act: combat.json loaded. Assert: the art bible 4 / hud.md E-17 numbers.
	_check("test_shipped_config_loads", config != null)
	if config == null:
		return
	_check("test_shipped_telegraph_pairs", config.telegraph_fill == Vector2(0.0, 0.45) and config.telegraph_stripe == Vector2(0.5, 1.0)
		and config.telegraph_edge == Vector2(0.3, 1.0), "%s %s %s" % [config.telegraph_fill, config.telegraph_stripe, config.telegraph_edge])
	_check("test_shipped_queued_stripe_sparser_than_running_start", config.telegraph_queued_stripe_alpha < config.telegraph_stripe_alpha(0.0))


func test_alphas_at_zero_half_one(config: CombatConfig) -> void:
	# Arrange / Act / Assert
	_check("test_fill_alpha_0_half_1", _near(config.telegraph_fill_alpha(0.0), 0.0) and _near(config.telegraph_fill_alpha(0.5), 0.225)
		and _near(config.telegraph_fill_alpha(1.0), 0.45))
	_check("test_stripe_alpha_0_half_1", _near(config.telegraph_stripe_alpha(0.0), 0.5) and _near(config.telegraph_stripe_alpha(0.5), 0.75)
		and _near(config.telegraph_stripe_alpha(1.0), 1.0))
	_check("test_edge_alpha_0_half_1", _near(config.telegraph_edge_alpha(0.0), 0.3) and _near(config.telegraph_edge_alpha(0.5), 0.65)
		and _near(config.telegraph_edge_alpha(1.0), 1.0))
	_check("test_alphas_clamp_outside_0_1", _near(config.telegraph_fill_alpha(-1.0), 0.0) and _near(config.telegraph_edge_alpha(2.0), 1.0))


func test_quantize_continuous_without_reduce_motion(config: CombatConfig) -> void:
	for case: Array in QUANTIZE_CASES:
		var k: float = float(case[0])
		_check("test_quantize_off_keeps_%.2f" % k, _near(config.quantize_progress(k, false), k))


func test_quantize_three_steps_with_reduce_motion(config: CombatConfig) -> void:
	for case: Array in QUANTIZE_CASES:
		var k: float = float(case[0])
		var got: float = config.quantize_progress(k, true)
		_check("test_quantize_on_%.2f_is_%.1f" % [k, float(case[1])], _near(got, float(case[1])), str(got))


func test_alphas_monotonic_non_decreasing(config: CombatConfig) -> void:
	# Arrange
	var ok: bool = true
	var prev: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	# Act: walk k from 0 to 1 through the three alphas and the reduce-motion quantizer.
	for i: int in MONOTONIC_STEPS + 1:
		var k: float = float(i) / float(MONOTONIC_STEPS)
		var now: Array[float] = [config.telegraph_fill_alpha(k), config.telegraph_stripe_alpha(k), config.telegraph_edge_alpha(k), config.quantize_progress(k, true)]
		for j: int in now.size():
			if now[j] < prev[j] - EPS:
				ok = false
		prev = now
	# Assert
	_check("test_alphas_and_quantizer_monotonic_non_decreasing", ok)


func test_invalid_block_falls_back_to_defaults() -> void:
	# Arrange: one bad value (alpha > 1) -> the whole block keeps the built-in defaults.
	var data: Dictionary = {"telegraph": {"fill": [0.1, 0.2], "stripe": [0.5, 3.0]}}
	# Act
	var config: CombatConfig = CombatConfig.from_dictionary(data)
	# Assert
	_check("test_invalid_telegraph_block_keeps_defaults", config.telegraph_fill == CombatConfig.new().telegraph_fill
		and config.telegraph_stripe == CombatConfig.new().telegraph_stripe)
	var custom: CombatConfig = CombatConfig.from_dictionary({"telegraph": {"fill": [0.1, 0.2], "reduce_motion_steps": [0.0, 1.0]}})
	_check("test_valid_custom_block_applies", custom.telegraph_fill == Vector2(0.1, 0.2) and _near(custom.quantize_progress(0.49, true), 0.0)
		and _near(custom.quantize_progress(0.5, true), 1.0))


func test_state_for_idle_and_running_and_queued(config: CombatConfig) -> void:
	# Arrange
	var actor := CutActor.new(CutConfig.new(), CombatState.Side.ENEMY)
	var running: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var queued: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]
	# Act / Assert: idle.
	_check("test_state_for_idle_is_empty", TelegraphPainter.state_for(actor, config, false).is_empty())
	actor.begin_swing(running, "kiem_khi", false)
	actor.queue_swing(queued, "kiem_khi", false, 1.0)
	actor.debug_set_progress(0.4)
	var smooth: Dictionary = TelegraphPainter.state_for(actor, config, false)
	var stepped: Dictionary = TelegraphPainter.state_for(actor, config, true)
	_check("test_state_for_running_cells_and_k", smooth.get("cells") == running and _near(float(smooth.get("k", -1.0)), 0.4))
	_check("test_state_for_queued_drops_cells_the_running_swing_covers", smooth.get("queued") == ([Vector2i(2, 0)] as Array[Vector2i]))
	_check("test_state_for_reduce_motion_quantizes_k", _near(float(stepped.get("k", -1.0)), 0.5))

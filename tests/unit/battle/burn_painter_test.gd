extends SceneTree
## Story 046 Part C follow-up: BurnPainter.state_for, the pure burn state the floor paints (one {cell, ratio} per
## burning cell, ratio = seconds left / duration clamped 0..1).
## Run: godot --headless --path . -s res://tests/unit/battle/burn_painter_test.gd

const DURATION_SEC: float = 4.0
const TICK_SEC: float = 0.5
const DAMAGE: float = 5.0
const HALF_SEC: float = 2.0
const EPS: float = 0.0001
const CELL := Vector2i(1, 1)

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_state_for_null_status_is_empty()
	test_state_for_nothing_burning_is_empty()
	test_state_for_tracks_the_burn_left()
	test_state_for_zero_duration_gives_ratio_zero()
	print("FAILS=%d" % fails)
	quit(fails)


# A state with no unit on CELL, so ticking the burn hurts nobody.
func _state() -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), 1000.0, 1000.0, Vector2i(0, 0), Vector2i(4, 2))


func test_state_for_null_status_is_empty() -> void:
	_check("test_state_for_null_status_is_empty", BurnPainter.state_for(null, DURATION_SEC).is_empty())


func test_state_for_nothing_burning_is_empty() -> void:
	_check("test_state_for_nothing_burning_is_empty", BurnPainter.state_for(StatusEffects.new(), DURATION_SEC).is_empty())


func test_state_for_tracks_the_burn_left() -> void:
	# Arrange
	var status := StatusEffects.new()
	var state: CombatState = _state()
	status.ignite([CELL] as Array[Vector2i], DURATION_SEC, TICK_SEC, DAMAGE)
	# Act / Assert: full at ignition.
	var fresh: Array[Dictionary] = BurnPainter.state_for(status, DURATION_SEC)
	_check("test_one_entry_after_ignite_got_%d" % fresh.size(), fresh.size() == 1)
	if fresh.size() == 1:
		_check("test_entry_cell_is_the_ignited_cell", fresh[0].get("cell") == CELL)
		_check("test_ratio_is_1_at_ignition_got_%s" % fresh[0].get("ratio"), absf(float(fresh[0].get("ratio")) - 1.0) < EPS)
	# Half the duration later: half the bar.
	status.tick(HALF_SEC, state)
	var half: Array[Dictionary] = BurnPainter.state_for(status, DURATION_SEC)
	_check("test_one_entry_half_way_got_%d" % half.size(), half.size() == 1)
	if half.size() == 1:
		_check("test_ratio_is_0.5_half_way_got_%s" % half[0].get("ratio"), absf(float(half[0].get("ratio")) - 0.5) < EPS)
	# Past the end: burnt out, nothing to paint.
	status.tick(DURATION_SEC, state)
	_check("test_state_empty_after_expiry", BurnPainter.state_for(status, DURATION_SEC).is_empty())


func test_state_for_zero_duration_gives_ratio_zero() -> void:
	var status := StatusEffects.new()
	status.ignite([CELL] as Array[Vector2i], DURATION_SEC, TICK_SEC, DAMAGE)
	var out: Array[Dictionary] = BurnPainter.state_for(status, 0.0)
	_check("test_zero_duration_ratio_is_0", out.size() == 1 and float(out[0].get("ratio")) == 0.0)

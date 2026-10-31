extends SceneTree
## Story 044 Part B: StickReader, the node-free joystick rules (dead zone, 4-way snap by the nearer
## axis, step on enter / change, repeat when the cooldown ends while held, stop on release). The
## cooldown is a fake: a Callable over a counter the test drives, so no UnitMover is needed.

var fails: int = 0
var _ready_now: bool = true

const ORIGIN: Vector2 = Vector2(100.0, 400.0)


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _can_step() -> bool:
	return _ready_now


func _new_reader() -> StickReader:
	_ready_now = true
	var reader := StickReader.new(_can_step)
	reader.press(ORIGIN)
	return reader


func _initialize() -> void:
	test_constants_match_quick_spec()
	test_inside_dead_zone_is_no_direction()
	test_just_outside_dead_zone_snaps()
	test_four_directions_snap()
	test_diagonals_snap_to_the_nearer_axis()
	test_exact_diagonal_goes_vertical()
	test_press_alone_steps_nothing()
	test_enter_direction_steps_at_once_when_ready()
	test_enter_direction_on_cooldown_does_not_step_then_repeats_when_ready()
	test_held_direction_repeats_each_time_cooldown_ends()
	test_move_inside_same_direction_does_not_step_again()
	test_direction_change_steps_at_once_when_ready()
	test_direction_change_on_cooldown_steps_when_ready()
	test_back_to_dead_zone_stops()
	test_release_stops_and_hides()
	test_poll_before_press_does_nothing()
	test_knob_is_clamped_to_base_radius()
	test_invalid_callable_means_always_ready()
	test_new_press_resets_direction()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_constants_match_quick_spec() -> void:
	_check("base is 160 px", is_equal_approx(StickReader.BASE_PX, 160.0))
	_check("knob is 88 px", is_equal_approx(StickReader.KNOB_PX, 88.0))
	_check("dead zone is 16 px (20 % of the base radius)", is_equal_approx(StickReader.deadzone_radius(), 16.0))
	_check("base radius 80, knob radius 44", is_equal_approx(StickReader.base_radius(), 80.0) and is_equal_approx(StickReader.knob_radius(), 44.0))


func test_inside_dead_zone_is_no_direction() -> void:
	for offset: Vector2 in [Vector2.ZERO, Vector2(15.9, 0), Vector2(0, -15.9), Vector2(-11, 11)]:
		_check("dead zone %s is ZERO" % offset, StickReader.snap(offset) == Vector2i.ZERO)


func test_just_outside_dead_zone_snaps() -> void:
	_check("16.5 px right snaps RIGHT", StickReader.snap(Vector2(16.5, 0)) == Vector2i.RIGHT)
	_check("16.5 px up snaps UP", StickReader.snap(Vector2(0, -16.5)) == Vector2i.UP)


func test_four_directions_snap() -> void:
	_check("right", StickReader.snap(Vector2(60, 0)) == Vector2i.RIGHT)
	_check("left", StickReader.snap(Vector2(-60, 0)) == Vector2i.LEFT)
	_check("up (screen y negative)", StickReader.snap(Vector2(0, -60)) == Vector2i.UP)
	_check("down (screen y positive)", StickReader.snap(Vector2(0, 60)) == Vector2i.DOWN)


func test_diagonals_snap_to_the_nearer_axis() -> void:
	_check("right-leaning up-right is RIGHT", StickReader.snap(Vector2(50, -30)) == Vector2i.RIGHT)
	_check("up-leaning up-right is UP", StickReader.snap(Vector2(30, -50)) == Vector2i.UP)
	_check("left-leaning down-left is LEFT", StickReader.snap(Vector2(-50, 30)) == Vector2i.LEFT)
	_check("down-leaning down-left is DOWN", StickReader.snap(Vector2(-30, 50)) == Vector2i.DOWN)
	_check("down-leaning down-right is DOWN", StickReader.snap(Vector2(30, 50)) == Vector2i.DOWN)
	_check("left-leaning up-left is LEFT", StickReader.snap(Vector2(-50, -30)) == Vector2i.LEFT)


func test_exact_diagonal_goes_vertical() -> void:
	_check("exact diagonal is vertical", StickReader.snap(Vector2(40, 40)) == Vector2i.DOWN and StickReader.snap(Vector2(40, -40)) == Vector2i.UP)


func test_press_alone_steps_nothing() -> void:
	var reader: StickReader = _new_reader()
	_check("press returns ZERO, poll ZERO", reader.press(ORIGIN) == Vector2i.ZERO and reader.poll() == Vector2i.ZERO)
	_check("press makes it active at the touch point", reader.is_active() and reader.get_origin() == ORIGIN)


func test_enter_direction_steps_at_once_when_ready() -> void:
	var reader: StickReader = _new_reader()
	var step: Vector2i = reader.move(ORIGIN + Vector2(50, 0))
	_check("entering RIGHT while ready steps RIGHT", step == Vector2i.RIGHT, str(step))


func test_enter_direction_on_cooldown_does_not_step_then_repeats_when_ready() -> void:
	var reader: StickReader = _new_reader()
	_ready_now = false
	var step: Vector2i = reader.move(ORIGIN + Vector2(0, -50))
	_check("entering on cooldown does not step", step == Vector2i.ZERO, str(step))
	_check("poll on cooldown is ZERO", reader.poll() == Vector2i.ZERO)
	_ready_now = true
	_check("poll once the cooldown ended steps the held direction", reader.poll() == Vector2i.UP)


func test_held_direction_repeats_each_time_cooldown_ends() -> void:
	var reader: StickReader = _new_reader()
	var steps: Array[Vector2i] = []
	steps.append(reader.move(ORIGIN + Vector2(50, 0)))
	for cycle: int in 3:
		_ready_now = false
		steps.append(reader.poll())
		steps.append(reader.poll())
		_ready_now = true
		steps.append(reader.poll())
	_check("enter + one step per cooldown end, nothing during cooldown", steps == [
		Vector2i.RIGHT,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.RIGHT,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.RIGHT,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.RIGHT,
	], str(steps))


func test_move_inside_same_direction_does_not_step_again() -> void:
	var reader: StickReader = _new_reader()
	reader.move(ORIGIN + Vector2(50, 0))
	var again: Vector2i = reader.move(ORIGIN + Vector2(70, 10))
	_check("sliding within RIGHT is not a new entry", again == Vector2i.ZERO, str(again))


func test_direction_change_steps_at_once_when_ready() -> void:
	var reader: StickReader = _new_reader()
	reader.move(ORIGIN + Vector2(50, 0))
	var step: Vector2i = reader.move(ORIGIN + Vector2(0, 50))
	_check("RIGHT -> DOWN while ready steps DOWN at once", step == Vector2i.DOWN, str(step))
	_check("direction is DOWN now", reader.get_direction() == Vector2i.DOWN)


func test_direction_change_on_cooldown_steps_when_ready() -> void:
	var reader: StickReader = _new_reader()
	reader.move(ORIGIN + Vector2(50, 0))
	_ready_now = false
	var step: Vector2i = reader.move(ORIGIN + Vector2(-50, 0))
	_check("change on cooldown does not step now", step == Vector2i.ZERO)
	_ready_now = true
	_check("then steps the new direction when ready", reader.poll() == Vector2i.LEFT)


func test_back_to_dead_zone_stops() -> void:
	var reader: StickReader = _new_reader()
	reader.move(ORIGIN + Vector2(50, 0))
	var step: Vector2i = reader.move(ORIGIN + Vector2(5, 0))
	_check("returning to the dead zone steps nothing", step == Vector2i.ZERO and reader.get_direction() == Vector2i.ZERO)
	_check("poll after returning is ZERO", reader.poll() == Vector2i.ZERO)
	var reenter: Vector2i = reader.move(ORIGIN + Vector2(50, 0))
	_check("re-entering the same direction steps again", reenter == Vector2i.RIGHT)


func test_release_stops_and_hides() -> void:
	var reader: StickReader = _new_reader()
	reader.move(ORIGIN + Vector2(50, 0))
	reader.release()
	_check("inactive after release", not reader.is_active())
	_check("no repeat after release", reader.poll() == Vector2i.ZERO)
	_check("no step from a move after release", reader.move(ORIGIN + Vector2(50, 0)) == Vector2i.ZERO)
	_check("direction cleared", reader.get_direction() == Vector2i.ZERO)


func test_poll_before_press_does_nothing() -> void:
	_ready_now = true
	var reader := StickReader.new(_can_step)
	_check("fresh reader: not active, poll ZERO", not reader.is_active() and reader.poll() == Vector2i.ZERO)


func test_knob_is_clamped_to_base_radius() -> void:
	var reader: StickReader = _new_reader()
	reader.move(ORIGIN + Vector2(300, 0))
	var knob: Vector2 = reader.get_knob_position()
	_check("knob stops at the base radius", is_equal_approx(knob.distance_to(ORIGIN), StickReader.base_radius()), str(knob))
	reader.move(ORIGIN + Vector2(30, 0))
	_check("inside the base the knob is on the finger", reader.get_knob_position().is_equal_approx(ORIGIN + Vector2(30, 0)))


func test_invalid_callable_means_always_ready() -> void:
	var reader := StickReader.new()
	reader.press(ORIGIN)
	_check("no query = ready", reader.move(ORIGIN + Vector2(50, 0)) == Vector2i.RIGHT)


func test_new_press_resets_direction() -> void:
	var reader: StickReader = _new_reader()
	reader.move(ORIGIN + Vector2(50, 0))
	reader.release()
	reader.press(Vector2(40, 500))
	_check("new gesture starts with no direction at the new origin", reader.get_direction() == Vector2i.ZERO and reader.get_origin() == Vector2(40, 500))

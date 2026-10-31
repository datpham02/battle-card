class_name DPadView
extends Node2D
## Z3 movement control. Two modes, from [member SettingsStore] [code]controls.movement[/code]
## (Story 044 Part B):
##
## [b]joystick[/b] (default): a floating 4-way stick. A press inside ScreenLayout.stick_zone_rect
## spawns the base at the touch point, the knob follows the finger (clamped to the base radius),
## [StickReader] decides the steps (step on entering / changing a direction, repeat when the
## UnitMover cooldown ends while held, stop on release) and releasing hides it. Nothing is drawn
## while untouched except a faint hint ring for the first [constant HINT_SECONDS] of a match (and
## all match when show_control_hints is on). The stick tracks ITS OWN pointer (touch index, -1 for
## the mouse) and never reacts to another finger, so the bag drag (HandInputController) keeps its
## own finger.
##
## [b]pad[/b]: four thumb-size move buttons (plus layout, ScreenLayout.dpad_rects). One press = one
## step attempt on the player's UnitMover; a press during cooldown does nothing (no queue, no
## repeat on hold). Dimmed while the mover is on cooldown. Placeholder art.
##
## Both: while placing, the zone is the ROTATE button (CutHudView) and this view takes no pointer.
## Focus lock (Story 012): no steps, dimmed. Input is read in _input so a press in the zone is
## consumed before the hand controller (_unhandled_input) sees it. Dedup: with
## emulate_mouse_from_touch a real touch also arrives as a mouse event, and with
## emulate_touch_from_mouse a click also arrives as a touch. Both emulated copies carry
## device == InputEvent.DEVICE_ID_EMULATION; they are consumed in the zone but never start, move or
## end a gesture or step, so one physical press gives exactly one gesture.
## DEV convenience: arrow keys and WASD also step (physical keycodes, no InputMap edits).
## Implements: Story 007, Story 044 (Part B).

const BUTTON_COLOR: Color = Color(0.2, 0.17, 0.15, 0.85)
const BUTTON_OUTLINE: Color = Color(0.95, 0.9, 0.78)
const ARROW_COLOR: Color = Color(0.95, 0.9, 0.78)
## Alpha multiplier of a button right after a step (cooldown fraction 1), 1 when ready.
const DIM_ALPHA: float = 0.4
## Locked while Focus pauses the match (Story 012): a stronger dim than the step cooldown plus
## a cool blue-grey tint (same family as CutHudView.FOCUS_BOARD_TINT), so it reads as "paused".
const LOCKED_ALPHA: float = 0.3
const LOCKED_TINT: Color = Color(0.35, 0.45, 0.65, 0.5)
const OUTLINE_WIDTH: float = 4.0
## Arrow half-size as a share of the button edge.
const ARROW_RATIO: float = 0.25
## DEV keys per direction (physical keycodes).
const KEYS: Dictionary = {
	KEY_UP: Vector2i.UP, KEY_W: Vector2i.UP,
	KEY_DOWN: Vector2i.DOWN, KEY_S: Vector2i.DOWN,
	KEY_LEFT: Vector2i.LEFT, KEY_A: Vector2i.LEFT,
	KEY_RIGHT: Vector2i.RIGHT, KEY_D: Vector2i.RIGHT,
}

## Stick hint ring (quick spec 2.2): shown this many seconds from the start of a match.
const HINT_SECONDS: float = 3.0
## Hint ring: alpha, line width px, centre 150 px from the left edge and 80 % of the height down.
const HINT_ALPHA: float = 0.25
const HINT_WIDTH: float = 1.0
const HINT_CENTER_X_PX: float = 150.0
const HINT_CENTER_Y_RATIO: float = 0.8
## Stick look: base fill alpha factor, outline width, knob fill, and the direction ticks on the base.
const STICK_BASE_ALPHA: float = 0.45
const STICK_OUTLINE_WIDTH: float = 3.0
const STICK_KNOB_COLOR: Color = Color(0.95, 0.9, 0.78, 0.9)
const STICK_TICK_RATIO: float = 0.72
const STICK_TICK_SIZE_PX: float = 9.0
const STICK_TICK_ACTIVE_ALPHA: float = 1.0
const STICK_TICK_IDLE_ALPHA: float = 0.35
const ARC_POINTS: int = 48
## Pad mode: every button's HIT area is at least this big (px), the 88 px minimum touch target of
## design/accessibility-requirements.md (art bible 7.4: touch area >= visible area). The drawn
## button may be smaller (Part A draws 86.4 px); the hit area only grows OUTWARD (see [method hit_rect]).
const PAD_HIT_MIN_PX: float = 88.0
## Pointer id of the mouse (HandInputController uses the same value); no pointer = NO_POINTER.
const MOUSE_POINTER: int = -1
const NO_POINTER: int = -2

@export var combat_view_path: NodePath = NodePath("../CombatView")

var _combat: CombatView
var _settings: SettingsStore
var _reader: StickReader
## Pointer (touch index / MOUSE_POINTER) that owns the stick, NO_POINTER when untouched.
var _stick_pointer: int = NO_POINTER
## Seconds this match has been running (counted while the battle processes, so a pause stops it).
var _match_time: float = 0.0


func _ready() -> void:
	_combat = get_node(combat_view_path) as CombatView
	_settings = SettingsStore.shared()
	_reader = StickReader.new(_can_step_now)


func _process(delta: float) -> void:
	_match_time += delta
	if _reader.is_active():
		if _combat.is_placing():
			_cancel_stick()
		else:
			var direction: Vector2i = _reader.poll()
			if direction != Vector2i.ZERO:
				_combat.try_step_player(direction)
	queue_redraw()


# The battle is switched off by the pause overlay, which swallows the finger lift: a stick left
# held would resume with a ghost finger, so the gesture is dropped when processing is disabled.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED and _reader != null:
		_cancel_stick()


## True when the joystick (not the 3x3 pad) is the movement control.
func is_joystick_mode() -> bool:
	return _settings != null and not _settings.is_pad()


## The stick reader (floating base, knob, direction); exposed for tests and the HUD.
func get_stick_reader() -> StickReader:
	return _reader


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and KEYS.has(key.physical_keycode):
			# A locked key is still consumed (nothing else reacts) but never steps.
			if not _is_locked():
				_combat.try_step_player(KEYS[key.physical_keycode])
			get_viewport().set_input_as_handled()
		return
	if _combat.is_placing():
		# Story 024: the d-pad area is the ROTATE button while placing (CutHudView handles it).
		return
	if is_joystick_mode():
		_input_stick(event)
		return
	var pos: Vector2
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
			return
		pos = button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		pos = touch.position
	else:
		return
	var direction: Vector2i = direction_at(pos)
	if direction == Vector2i.ZERO:
		return
	get_viewport().set_input_as_handled()
	if event.device != InputEvent.DEVICE_ID_EMULATION and not _is_locked():
		_combat.try_step_player(direction)


# Joystick mode: a press in the zone starts a gesture owned by that pointer; only that pointer moves
# and ends it. Emulated copies are consumed in the zone (so the hand controller never sees them)
# but never drive the stick.
func _input_stick(event: InputEvent) -> void:
	var real: bool = event.device != InputEvent.DEVICE_ID_EMULATION
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_stick_press(touch.index, touch.position, real)
		elif real and touch.index == _stick_pointer:
			_end_stick()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_stick_press(MOUSE_POINTER, button.position, real)
		elif real and _stick_pointer == MOUSE_POINTER:
			_end_stick()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if real and drag.index == _stick_pointer:
			_stick_move(drag.position)
	elif event is InputEventMouseMotion:
		if real and _stick_pointer == MOUSE_POINTER:
			_stick_move((event as InputEventMouseMotion).position)


func _stick_press(pointer: int, position: Vector2, real: bool) -> void:
	if not ScreenLayout.stick_zone_rect(get_viewport_rect().size).has_point(position):
		return
	if _stick_pointer != NO_POINTER:
		return  # a second finger in the zone is not ours; it is left to whoever wants it
	get_viewport().set_input_as_handled()
	if not real:
		return
	_stick_pointer = pointer
	_reader.press(position)


func _stick_move(position: Vector2) -> void:
	get_viewport().set_input_as_handled()
	var direction: Vector2i = _reader.move(position)
	if direction != Vector2i.ZERO:
		_combat.try_step_player(direction)


func _end_stick() -> void:
	get_viewport().set_input_as_handled()
	_cancel_stick()


func _cancel_stick() -> void:
	_stick_pointer = NO_POINTER
	_reader.release()


# Reader query: a step would be accepted now (cooldown over, not step-locked, not Focus-locked).
func _can_step_now() -> bool:
	if _combat == null or _combat.get_mover() == null or _is_locked():
		return false
	return _combat.get_mover().is_ready()


# True while Focus pauses the match and locks movement (Story 012): the buttons dim and every
# press or key on them is swallowed without a step.
func _is_locked() -> bool:
	if _combat == null:
		return false
	return _combat.is_movement_locked()


## Direction of the pad button under viewport point [param point], or Vector2i.ZERO if none
## (always ZERO in joystick mode, which has no buttons).
func direction_at(point: Vector2) -> Vector2i:
	if is_joystick_mode():
		return Vector2i.ZERO
	var rects: Dictionary = ScreenLayout.dpad_rects(get_viewport_rect().size)
	for direction: Vector2i in rects:
		if (rects[direction] as Rect2).has_point(point):
			return direction
	# Not on a drawn button: try the grown hit areas (never overlapping a neighbour).
	for direction: Vector2i in rects:
		if hit_rect(rects[direction], direction).has_point(point):
			return direction
	return Vector2i.ZERO


## The touch area of a pad button drawn as [param drawn] for [param direction]: at least
## [constant PAD_HIT_MIN_PX] square. It grows outward only: along the button's own direction
## (UP grows up, DOWN down, LEFT left, RIGHT right) by the full deficit, and sideways by half the
## deficit on each side, so it stays clear of the neighbouring buttons (the pad gap is far larger).
## A button already that big is returned unchanged.
static func hit_rect(drawn: Rect2, direction: Vector2i) -> Rect2:
	var deficit := Vector2(maxf(PAD_HIT_MIN_PX - drawn.size.x, 0.0), maxf(PAD_HIT_MIN_PX - drawn.size.y, 0.0))
	var rect: Rect2 = drawn
	if direction.x != 0:
		rect.size.x += deficit.x
		if direction.x < 0:
			rect.position.x -= deficit.x
		rect = rect.grow_individual(0.0, deficit.y * 0.5, 0.0, deficit.y * 0.5)
	else:
		rect.size.y += deficit.y
		if direction.y < 0:
			rect.position.y -= deficit.y
		rect = rect.grow_individual(deficit.x * 0.5, 0.0, deficit.x * 0.5, 0.0)
	return rect


func _draw() -> void:
	if _combat == null or _combat.get_mover() == null:
		return
	if _combat.is_placing():
		return
	var locked: bool = _is_locked()
	var alpha: float = LOCKED_ALPHA if locked else lerpf(1.0, DIM_ALPHA, _combat.get_mover().get_cooldown_fraction())
	if is_joystick_mode():
		_draw_stick(alpha, locked)
	else:
		_draw_pad(alpha, locked)


func _draw_pad(alpha: float, locked: bool) -> void:
	var rects: Dictionary = ScreenLayout.dpad_rects(get_viewport_rect().size)
	for direction: Vector2i in rects:
		var rect: Rect2 = rects[direction]
		draw_rect(rect, Color(BUTTON_COLOR, BUTTON_COLOR.a * alpha))
		if locked:
			draw_rect(rect, LOCKED_TINT)
		draw_rect(rect, Color(BUTTON_OUTLINE, alpha), false, OUTLINE_WIDTH)
		var c: Vector2 = rect.get_center()
		var r: float = rect.size.x * ARROW_RATIO
		var d := Vector2(direction)
		var perp := Vector2(-d.y, d.x)
		draw_colored_polygon(
			PackedVector2Array([c + d * r, c - d * r + perp * r, c - d * r - perp * r]),
			Color(ARROW_COLOR, alpha)
		)


# Joystick: base + knob only while a finger holds the stick; otherwise the faint hint ring.
func _draw_stick(alpha: float, locked: bool) -> void:
	if not _reader.is_active():
		if _match_time < HINT_SECONDS or _settings.get_show_control_hints():
			var vp: Vector2 = get_viewport_rect().size
			var center := Vector2(HINT_CENTER_X_PX, vp.y * HINT_CENTER_Y_RATIO)
			draw_arc(center, StickReader.base_radius(), 0.0, TAU, ARC_POINTS, Color(BUTTON_OUTLINE, HINT_ALPHA), HINT_WIDTH, true)
		return
	var origin: Vector2 = _reader.get_origin()
	var radius: float = StickReader.base_radius()
	draw_circle(origin, radius, Color(BUTTON_COLOR, BUTTON_COLOR.a * STICK_BASE_ALPHA * alpha))
	if locked:
		draw_circle(origin, radius, LOCKED_TINT)
	draw_arc(origin, radius, 0.0, TAU, ARC_POINTS, Color(BUTTON_OUTLINE, alpha), STICK_OUTLINE_WIDTH, true)
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var d := Vector2(direction)
		var perp := Vector2(-d.y, d.x)
		var tip: Vector2 = origin + d * radius * STICK_TICK_RATIO
		var tick_alpha: float = STICK_TICK_ACTIVE_ALPHA if direction == _reader.get_direction() else STICK_TICK_IDLE_ALPHA
		draw_colored_polygon(
			PackedVector2Array([tip + d * STICK_TICK_SIZE_PX, tip + perp * STICK_TICK_SIZE_PX, tip - perp * STICK_TICK_SIZE_PX]),
			Color(ARROW_COLOR, tick_alpha * alpha)
		)
	draw_circle(_reader.get_knob_position(), StickReader.knob_radius(), Color(STICK_KNOB_COLOR, STICK_KNOB_COLOR.a * alpha))

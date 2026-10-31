class_name StickReader
extends RefCounted
## Story 044 Part B: the pure reading rules of the floating 4-way joystick (quick spec
## control-layout-v2 section 2.2). No nodes, no engine input: feed it the press / move / release
## positions (viewport px) and poll it once per frame; it returns the step direction to attempt.
##
## The step cadence is NOT its own timer. "Can a step happen now" is an injected Callable (the
## view passes UnitMover readiness), so the repeat rate is exactly the mover cooldown and no new
## number exists. Rules: a direction entered while ready steps at once; held, it steps again every
## time the cooldown ends (the next [method poll] that finds the query true); changing direction
## while ready steps at once; back in the dead zone or released = stop.

## Diameter of the base, px at 1280x720 (quick spec knob layout.stick_base_px).
const BASE_PX: float = 160.0
## Diameter of the knob, px (layout.stick_knob_px; the 88 px minimum touch target).
const KNOB_PX: float = 88.0
## Dead zone as a share of the base radius (layout.stick_deadzone_ratio): 16 px.
const DEADZONE_RATIO: float = 0.20

var _can_step: Callable
var _active: bool = false
var _origin: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
var _direction: Vector2i = Vector2i.ZERO


## [param can_step] is a Callable () -> bool, true when a step would be accepted right now
## (cooldown over, not locked). An invalid Callable counts as always ready.
func _init(can_step: Callable = Callable()) -> void:
	_can_step = can_step


## Radius of the base in px.
static func base_radius() -> float:
	return BASE_PX * 0.5


## Radius of the knob in px.
static func knob_radius() -> float:
	return KNOB_PX * 0.5


## Dead-zone radius in px (16 at the default sizes).
static func deadzone_radius() -> float:
	return base_radius() * DEADZONE_RATIO


## 4-way snap of [param offset] (finger minus base centre): ZERO inside the dead zone, else the
## axis it leans on more; an exact diagonal goes to the vertical axis.
static func snap(offset: Vector2) -> Vector2i:
	if offset.length() <= deadzone_radius():
		return Vector2i.ZERO
	if absf(offset.x) > absf(offset.y):
		return Vector2i.RIGHT if offset.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if offset.y > 0.0 else Vector2i.UP


## True between [method press] and [method release].
func is_active() -> bool:
	return _active


## Base centre (the press point) while active.
func get_origin() -> Vector2:
	return _origin


## Knob position: the finger clamped to the base radius, around the origin.
func get_knob_position() -> Vector2:
	return _origin + _offset.limit_length(base_radius())


## Current snapped direction (ZERO in the dead zone or when inactive).
func get_direction() -> Vector2i:
	return _direction


## A finger went down at [param position]: the base is placed there. The finger sits on the base
## centre, so no direction yet; returns ZERO.
func press(position: Vector2) -> Vector2i:
	_active = true
	_origin = position
	_offset = Vector2.ZERO
	_direction = Vector2i.ZERO
	return Vector2i.ZERO


## The finger moved to [param position]. Returns the direction to step now (entering or changing
## a direction while ready), else ZERO.
func move(position: Vector2) -> Vector2i:
	if not _active:
		return Vector2i.ZERO
	_offset = position - _origin
	var next: Vector2i = snap(_offset)
	if next == _direction:
		return Vector2i.ZERO
	_direction = next
	if next != Vector2i.ZERO and _can_step_now():
		return next
	return Vector2i.ZERO


## Once per frame while held: the direction to step again (the cooldown ended while the finger
## still leans), else ZERO.
func poll() -> Vector2i:
	if _active and _direction != Vector2i.ZERO and _can_step_now():
		return _direction
	return Vector2i.ZERO


## The finger lifted (or the gesture was cancelled): the base disappears and nothing steps.
func release() -> void:
	_active = false
	_offset = Vector2.ZERO
	_direction = Vector2i.ZERO


func _can_step_now() -> bool:
	return not _can_step.is_valid() or bool(_can_step.call())

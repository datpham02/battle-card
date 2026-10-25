class_name DPadView
extends Node2D
## Four thumb-size move buttons (plus layout, bottom-left). One press = one step attempt
## on the player's UnitMover; a press during cooldown does nothing (no queue, no repeat on
## hold). Dimmed while the mover is on cooldown. Placeholder art.
##
## Input is read in _input so a press on a button is consumed before the hand controller
## (_unhandled_input) sees it. Dedup: with emulate_mouse_from_touch a real touch also arrives
## as a mouse event, and with emulate_touch_from_mouse a click also arrives as a touch. Both
## emulated copies carry device == InputEvent.DEVICE_ID_EMULATION; they are consumed when on
## a button but never trigger a step, so one physical press gives exactly one step attempt.
## DEV convenience: arrow keys and WASD also step (physical keycodes, no InputMap edits).
## Implements: Story 007.

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

@export var combat_view_path: NodePath = NodePath("../CombatView")

var _combat: CombatView


func _ready() -> void:
	_combat = get_node(combat_view_path) as CombatView


func _process(_delta: float) -> void:
	queue_redraw()


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


# True while Focus pauses the match and locks movement (Story 012): the buttons dim and every
# press or key on them is swallowed without a step.
func _is_locked() -> bool:
	if _combat == null:
		return false
	return _combat.is_movement_locked()


## Direction of the button under viewport point [param point], or Vector2i.ZERO if none.
func direction_at(point: Vector2) -> Vector2i:
	var rects: Dictionary = ScreenLayout.dpad_rects(get_viewport_rect().size)
	for direction: Vector2i in rects:
		if (rects[direction] as Rect2).has_point(point):
			return direction
	return Vector2i.ZERO


func _draw() -> void:
	if _combat == null or _combat.get_mover() == null:
		return
	if _combat.is_placing():
		return
	var locked: bool = _is_locked()
	var alpha: float = LOCKED_ALPHA if locked else lerpf(1.0, DIM_ALPHA, _combat.get_mover().get_cooldown_fraction())
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

class_name CutActor
extends RefCounted
## One side's cut swing: holds at most ONE running swing (plus a 1-slot queue for the boss's
## combo), counts it down, and reports when it resolves. It does NOT apply damage (see
## CutEffects). Time advances only via [method tick].
## Implements: Story 008 (player), reused by Story 009 (boss), Story 013 (duration_mult, queue).

## Emitted when a swing starts. [param duration] is the windup in seconds.
signal swing_started(cells: Array[Vector2i], skill_id: String, duration: float)
## Emitted once when the countdown reaches zero.
signal swing_resolved(cells: Array[Vector2i], skill_id: String)
## Emitted when a running swing is cancelled (interrupt).
signal swing_cancelled(cells: Array[Vector2i], skill_id: String)
## Emitted when a queued (not yet started) swing is dropped because the running one was cancelled.
signal queue_cleared(cells: Array[Vector2i], skill_id: String)

## Which side owns this actor (a CombatState.Side value).
var side: int = 0
## Multiplies the windup computed from the cell count in [method begin_swing] (the boss's
## per-match swing speed). Queued swings keep the explicit duration they were given. > 0.
var duration_mult: float = 1.0:
	set(value):
		duration_mult = value if value > 0.0 else 1.0

## Story 018: optional Callable(cells: int, duration: float) -> float applied to the windup in
## [method begin_swing] (the player's passive); invalid = none. Queued swings are not touched.
var duration_modifier: Callable = Callable()

var _config: CutConfig
var _swinging: bool = false
var _time_left: float = 0.0
var _duration: float = 0.0
var _cells: Array[Vector2i] = []
var _skill_id: String = ""
var _target_is_enemy: bool = true
var _has_queued: bool = false
var _q_cells: Array[Vector2i] = []
var _q_skill_id: String = ""
var _q_target_is_enemy: bool = true
var _q_duration: float = 0.0


func _init(cut_config: CutConfig, p_side: int) -> void:
	_config = cut_config
	side = p_side


## True when no swing is running.
func can_begin() -> bool:
	return not _swinging


## Starts a swing over [param cells]. Returns false if one is already running or the
## cell list is empty. Duration = CutConfig.swing_duration(cells) * [member duration_mult].
func begin_swing(cells: Array[Vector2i], skill_id: String, target_is_enemy: bool) -> bool:
	if _swinging or cells.is_empty():
		return false
	var duration: float = _config.swing_duration(cells.size()) * duration_mult
	if duration_modifier.is_valid():
		duration = float(duration_modifier.call(cells.size(), duration))
	_start(cells, skill_id, target_is_enemy, duration)
	return true


## Queues ONE follow-up swing that starts automatically the moment the running swing resolves
## and lasts exactly [param duration] seconds (independent of its cell count and of
## [member duration_mult]). Refused (false) when no swing is running (use [method begin_swing]),
## when a swing is already queued, when [param cells] is empty or [param duration] <= 0.
## The queue is dropped when the running swing is cancelled.
func queue_swing(cells: Array[Vector2i], skill_id: String, target_is_enemy: bool, duration: float) -> bool:
	if not _swinging or _has_queued or cells.is_empty() or duration <= 0.0:
		return false
	_has_queued = true
	_q_cells = cells.duplicate()
	_q_skill_id = skill_id
	_q_target_is_enemy = target_is_enemy
	_q_duration = duration
	return true


## True while a swing waits in the queue.
func has_queued() -> bool:
	return _has_queued


## Cells of the queued swing (empty when none).
func get_queued_cells() -> Array[Vector2i]:
	return _q_cells.duplicate()


## Windup of the queued swing (0 when none).
func get_queued_duration() -> float:
	return _q_duration if _has_queued else 0.0


## Skill id of the queued swing ("" when none).
func get_queued_skill_id() -> String:
	return _q_skill_id


## Drops the queued swing silently (no signal). No-op when none.
func clear_queue() -> void:
	_has_queued = false
	_q_cells = []
	_q_skill_id = ""
	_q_duration = 0.0


## Advances the swing by [param delta] seconds; resolves it (once) at zero, then starts the
## queued swing (if any) with its full duration: it is never ticked in the same call.
func tick(delta: float) -> void:
	if not _swinging:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	var cells: Array[Vector2i] = _cells
	var skill_id: String = _skill_id
	_clear()
	swing_resolved.emit(cells, skill_id)
	# A listener may have cancelled/queued in the meantime; start only a still-pending queue.
	if _has_queued and not _swinging:
		var next_cells: Array[Vector2i] = _q_cells
		var next_skill: String = _q_skill_id
		var next_target: bool = _q_target_is_enemy
		var next_duration: float = _q_duration
		clear_queue()
		_start(next_cells, next_skill, next_target, next_duration)


## Cancels the running swing (no effect applied) and drops the queue. No-op when idle.
func cancel() -> void:
	if not _swinging:
		_drop_queue_with_signal()
		return
	var cells: Array[Vector2i] = _cells
	var skill_id: String = _skill_id
	_clear()
	swing_cancelled.emit(cells, skill_id)
	_drop_queue_with_signal()


## True while a swing is running.
func is_swinging() -> bool:
	return _swinging


## Seconds until the swing resolves (0 when idle).
func get_time_left() -> float:
	return maxf(_time_left, 0.0) if _swinging else 0.0


## Windup length of the current swing (0 when idle).
func get_duration() -> float:
	return _duration if _swinging else 0.0


## Cells of the current swing (empty when idle).
func get_cells() -> Array[Vector2i]:
	return _cells.duplicate()


## Skill id of the current swing ("" when idle).
func get_skill_id() -> String:
	return _skill_id


## True if the current swing targets the enemy half.
func targets_enemy() -> bool:
	return _target_is_enemy


func _start(cells: Array[Vector2i], skill_id: String, target_is_enemy: bool, duration: float) -> void:
	_swinging = true
	_cells = cells.duplicate()
	_skill_id = skill_id
	_target_is_enemy = target_is_enemy
	_duration = duration
	_time_left = duration
	swing_started.emit(_cells.duplicate(), _skill_id, _duration)


func _drop_queue_with_signal() -> void:
	if not _has_queued:
		return
	var cells: Array[Vector2i] = _q_cells.duplicate()
	var skill_id: String = _q_skill_id
	clear_queue()
	queue_cleared.emit(cells, skill_id)


func _clear() -> void:
	_swinging = false
	_time_left = 0.0
	_duration = 0.0
	_cells = []
	_skill_id = ""

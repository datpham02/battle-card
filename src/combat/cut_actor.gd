class_name CutActor
extends RefCounted
## One side's cut swing: holds at most ONE swing, counts it down, and reports when it
## resolves. It does NOT apply damage (see CutEffects). Time advances only via [method tick].
## Implements: Story 008 (player), reused by Story 009 (boss).

## Emitted when a swing starts. [param duration] is the windup in seconds.
signal swing_started(cells: Array[Vector2i], skill_id: String, duration: float)
## Emitted once when the countdown reaches zero.
signal swing_resolved(cells: Array[Vector2i], skill_id: String)
## Emitted when a running swing is cancelled (interrupt).
signal swing_cancelled(cells: Array[Vector2i], skill_id: String)

## Which side owns this actor (a CombatState.Side value).
var side: int = 0

var _config: CutConfig
var _swinging: bool = false
var _time_left: float = 0.0
var _duration: float = 0.0
var _cells: Array[Vector2i] = []
var _skill_id: String = ""
var _target_is_enemy: bool = true


func _init(cut_config: CutConfig, p_side: int) -> void:
	_config = cut_config
	side = p_side


## True when no swing is running.
func can_begin() -> bool:
	return not _swinging


## Starts a swing over [param cells]. Returns false if one is already running or the
## cell list is empty. Duration comes from the cell count (CutConfig).
func begin_swing(cells: Array[Vector2i], skill_id: String, target_is_enemy: bool) -> bool:
	if _swinging or cells.is_empty():
		return false
	_swinging = true
	_cells = cells.duplicate()
	_skill_id = skill_id
	_target_is_enemy = target_is_enemy
	_duration = _config.swing_duration(cells.size())
	_time_left = _duration
	swing_started.emit(_cells.duplicate(), _skill_id, _duration)
	return true


## Advances the swing by [param delta] seconds; resolves it (once) at zero.
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


## Cancels the running swing (no effect applied). No-op when idle.
func cancel() -> void:
	if not _swinging:
		return
	var cells: Array[Vector2i] = _cells
	var skill_id: String = _skill_id
	_clear()
	swing_cancelled.emit(cells, skill_id)


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


func _clear() -> void:
	_swinging = false
	_time_left = 0.0
	_duration = 0.0
	_cells = []
	_skill_id = ""

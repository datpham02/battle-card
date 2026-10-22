class_name FocusController
extends RefCounted
## "Focus" (Tập trung): the player's limited, cooldown-gated pause of the match while points are
## being connected. READY -> ACTIVE (up to focus_max_sec REAL seconds) -> COOLDOWN
## (focus_cooldown_sec REAL seconds) -> READY. The view decides WHEN to start/end it; this
## class only owns the state and the real-time clocks (the delta is injected, never scaled).
## Numbers come from SkillConfig (assets/data/cards.json "focus"). Implements: Story 012.

## Emitted when Focus becomes ACTIVE.
signal started
## Emitted when Focus stops. [param reason] is "confirmed", "deselected", "timeout" or "death".
signal ended(reason: String)

enum State { READY, ACTIVE, COOLDOWN }

const REASON_CONFIRMED: String = "confirmed"
const REASON_DESELECTED: String = "deselected"
const REASON_TIMEOUT: String = "timeout"
const REASON_DEATH: String = "death"

var _config: SkillConfig
var _state: State = State.READY
var _time_left: float = 0.0
var _cooldown_left: float = 0.0


func _init(skill_config: SkillConfig) -> void:
	_config = skill_config


## Advances the clocks by [param delta] REAL seconds. An ACTIVE Focus that runs out ends with
## reason "timeout"; a cooldown that reaches 0 makes Focus READY again.
func tick_real(delta: float) -> void:
	if delta <= 0.0:
		return
	match _state:
		State.ACTIVE:
			_time_left -= delta
			if _time_left <= 0.0:
				end(REASON_TIMEOUT)
		State.COOLDOWN:
			_cooldown_left -= delta
			if _cooldown_left <= 0.0:
				_cooldown_left = 0.0
				_state = State.READY


## Starts Focus; only possible from READY. Returns true when it started.
func try_start() -> bool:
	if _state != State.READY:
		return false
	_state = State.ACTIVE
	_time_left = _config.focus_max_sec
	started.emit()
	return true


## Ends an ACTIVE Focus for [param reason] and starts the cooldown. No-op otherwise.
func end(reason: String) -> void:
	if _state != State.ACTIVE:
		return
	_state = State.COOLDOWN
	_time_left = 0.0
	_cooldown_left = _config.focus_cooldown_sec
	if _cooldown_left <= 0.0:
		_state = State.READY
	ended.emit(reason)


## True while the match is paused by Focus.
func is_active() -> bool:
	return _state == State.ACTIVE


## True when Focus can start.
func is_ready() -> bool:
	return _state == State.READY


## True while the cooldown runs.
func is_on_cooldown() -> bool:
	return _state == State.COOLDOWN


## REAL seconds of Focus left (0 unless ACTIVE).
func get_time_left() -> float:
	return _time_left if _state == State.ACTIVE else 0.0


## Total REAL seconds one Focus lasts.
func get_max_sec() -> float:
	return _config.focus_max_sec


## REAL seconds of cooldown left (0 unless on cooldown).
func get_cooldown_left() -> float:
	return _cooldown_left if _state == State.COOLDOWN else 0.0


## Total REAL seconds of the cooldown.
func get_cooldown_sec() -> float:
	return _config.focus_cooldown_sec


## Simulation speed factor while ACTIVE (0 = full stop).
func get_time_scale() -> float:
	return _config.focus_time_scale


## True when movement is blocked while ACTIVE.
func locks_movement() -> bool:
	return _config.focus_locks_movement

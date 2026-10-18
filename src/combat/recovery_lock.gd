class_name RecoveryLock
extends RefCounted
## Small state machine: UNLOCKED --start(duration)--> LOCKED --tick past duration--> UNLOCKED.
## Time only advances through [method tick] (injected delta, no wall-clock).
## Implements: Story 003 (per-card recovery).

## Emitted when the lock expires.
signal unlocked

var _remaining: float = 0.0
var _duration: float = 0.0


## True while the lock is active.
func is_locked() -> bool:
	return _remaining > 0.0


## Seconds left (0 when unlocked).
func get_remaining() -> float:
	return _remaining


## Length of the current/last lock in seconds.
func get_duration() -> float:
	return _duration


## Share of the lock left, 1 right after start down to 0; 0 when unlocked.
func get_ratio() -> float:
	if _remaining <= 0.0 or _duration <= 0.0:
		return 0.0
	return clampf(_remaining / _duration, 0.0, 1.0)


## Locks for [param duration] seconds (restarts any running lock). 0 or less = no lock.
func start(duration: float) -> void:
	_duration = maxf(duration, 0.0)
	_remaining = _duration


## Advances time by [param delta] seconds; emits [signal unlocked] on expiry.
func tick(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining == 0.0:
		unlocked.emit()

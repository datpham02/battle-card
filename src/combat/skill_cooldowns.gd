class_name SkillCooldowns
extends RefCounted
## Per-side skill cooldown timers. Time only advances through [method tick] (injected delta).
## Implements: Story 008.

var _remaining: Dictionary = {} # skill id -> seconds left


## Advances all running cooldowns by [param delta] seconds.
func tick(delta: float) -> void:
	for id: Variant in _remaining.keys():
		var left: float = float(_remaining[id]) - delta
		if left <= 0.0:
			_remaining.erase(id)
		else:
			_remaining[id] = left


## True when [param id] is not cooling down.
func is_ready(id: String) -> bool:
	return not _remaining.has(id)


## Seconds left on [param id] (0 when ready).
func remaining(id: String) -> float:
	return float(_remaining.get(id, 0.0))


## Starts a cooldown of [param cooldown_sec] on [param id]; 0 or less = none.
func start(id: String, cooldown_sec: float) -> void:
	if cooldown_sec > 0.0:
		_remaining[id] = cooldown_sec


## Story 021: ends the cooldown of [param id] at once.
func clear(id: String) -> void:
	_remaining.erase(id)

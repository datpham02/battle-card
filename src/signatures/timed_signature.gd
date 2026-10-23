class_name TimedSignature
extends BaseSignature
## Shared timer of the signatures that last `duration_sec` seconds (Params: duration_sec).
## Implements: Story 021.

## Fallback only; the real number is in characters.json.
const DEFAULT_DURATION_SEC: float = 0.0

var _left: float = 0.0


func activate() -> void:
	_left = duration()


func tick(dt: float) -> void:
	if _left > 0.0 and dt > 0.0:
		_left = maxf(_left - dt, 0.0)


func is_active() -> bool:
	return _left > 0.0


func time_left() -> float:
	return _left


func duration() -> float:
	return maxf(param_float("duration_sec", DEFAULT_DURATION_SEC), 0.0)


func teardown() -> void:
	_left = 0.0
	super.teardown()

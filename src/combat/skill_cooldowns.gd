class_name SkillCooldowns
extends RefCounted
## Per-side skill cooldown timers. Time only advances through [method tick] (injected delta).
## Each running cooldown also keeps its full length (for the HUD's recovery pie) and the order the cards were
## used in (2026-11-01 LoL-style cooldown column: [method running_ids], oldest use first).
## Implements: Story 008; quick spec menu-la-giua-man-hinh-2026-11-01.

var _remaining: Dictionary = {} # skill id -> seconds left (insertion order = use order)
var _total: Dictionary = {} # skill id -> full cooldown length of the running cooldown


## Advances all running cooldowns by [param delta] seconds.
func tick(delta: float) -> void:
	for id: Variant in _remaining.keys():
		var left: float = float(_remaining[id]) - delta
		if left <= 0.0:
			_remaining.erase(id)
			_total.erase(id)
		else:
			_remaining[id] = left


## True when [param id] is not cooling down.
func is_ready(id: String) -> bool:
	return not _remaining.has(id)


## Seconds left on [param id] (0 when ready).
func remaining(id: String) -> float:
	return float(_remaining.get(id, 0.0))


## Full length of the running cooldown of [param id] (0 when ready).
func total(id: String) -> float:
	return float(_total.get(id, 0.0))


## Share of the running cooldown of [param id] already recovered: 0 right after the use, 1 when ready.
func recovered_fraction(id: String) -> float:
	return CooldownPie.recovered_fraction(remaining(id), total(id))


## Ids of every running cooldown in the order the cards were used (the latest use last).
func running_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in _remaining.keys():
		ids.append(str(id))
	return ids


## Starts a cooldown of [param cooldown_sec] on [param id]; 0 or less = none. A card used again moves to the end
## of the use order.
func start(id: String, cooldown_sec: float) -> void:
	if cooldown_sec > 0.0:
		_remaining.erase(id)
		_remaining[id] = cooldown_sec
		_total[id] = cooldown_sec


## Story 021: ends the cooldown of [param id] at once.
func clear(id: String) -> void:
	_remaining.erase(id)
	_total.erase(id)

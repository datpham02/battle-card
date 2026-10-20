class_name StatusEffects
extends RefCounted
## Timed board effects: burning cells (area denial, damage per unit standing on them) and
## per-side pins (the unit cannot step). Pure logic, time is injected through tick().
## Implements: Story 010 (Burn and Pin).

## A cell started burning (also emitted when a burning cell is re-ignited).
signal cell_ignited(cell: Vector2i)
## A burning cell burned out.
signal cell_burned_out(cell: Vector2i)
## A unit got pinned or its pin was refreshed. [param side] = CombatState.Side.
signal pinned(side: int)
## A pin expired.
signal pin_ended(side: int)

## Tolerance for float accumulation when comparing against a tick boundary.
const _EPS: float = 0.000001

# Vector2i -> {left: float, tick_acc: float, tick_sec: float, damage: float}
var _burning: Dictionary = {}
# CombatState.Side -> seconds left
var _pins: Dictionary = {}


## Ignites every cell in [param cells] for [param duration] seconds. A unit standing on a
## burning cell takes [param damage_per_tick] every [param tick_sec]. Re-igniting resets the
## timer to the full duration (no stacking).
func ignite(cells: Array[Vector2i], duration: float, tick_sec: float, damage_per_tick: float) -> void:
	if duration <= 0.0:
		return
	for cell: Vector2i in cells:
		var acc: float = 0.0
		if _burning.has(cell):
			acc = float((_burning[cell] as Dictionary)["tick_acc"])
		_burning[cell] = {
			"left": duration, "tick_acc": acc,
			"tick_sec": maxf(tick_sec, _EPS), "damage": maxf(damage_per_tick, 0.0),
		}
		cell_ignited.emit(cell)


## Pins the unit of [param side] for [param duration] seconds; a pin already running is
## refreshed to the full duration.
func pin(side: int, duration: float) -> void:
	if duration <= 0.0:
		return
	_pins[side] = duration
	pinned.emit(side)


## Advances all timers by [param delta]; burning cells hurt the units standing on them in
## [param state] once per elapsed tick, however large the delta.
func tick(delta: float, state: CombatState) -> void:
	if delta <= 0.0:
		return
	for cell: Vector2i in _burning.keys():
		var entry: Dictionary = _burning[cell] as Dictionary
		var active: float = minf(delta, float(entry["left"]))
		var tick_sec: float = float(entry["tick_sec"])
		var acc: float = float(entry["tick_acc"])
		var victims: Array[int] = _units_on(cell, state)
		if victims.is_empty():
			acc = 0.0
		else:
			acc += active
			while acc >= tick_sec - _EPS:
				acc -= tick_sec
				for side: int in victims:
					state.damage(side, float(entry["damage"]))
		var left: float = float(entry["left"]) - delta
		if left <= _EPS:
			_burning.erase(cell)
			cell_burned_out.emit(cell)
		else:
			entry["left"] = left
			entry["tick_acc"] = acc
	for side: int in _pins.keys():
		var pin_left: float = float(_pins[side]) - delta
		if pin_left <= _EPS:
			_pins.erase(side)
			pin_ended.emit(side)
		else:
			_pins[side] = pin_left


## True while [param cell] is burning.
func is_burning(cell: Vector2i) -> bool:
	return _burning.has(cell)


## All burning cells.
func burning_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _burning.keys():
		out.append(cell)
	return out


## Seconds of burning left on [param cell]; 0 if it is not burning.
func get_burn_left(cell: Vector2i) -> float:
	if not _burning.has(cell):
		return 0.0
	return float((_burning[cell] as Dictionary)["left"])


## True while the unit of [param side] is pinned.
func is_pinned(side: int) -> bool:
	return _pins.has(side)


## Seconds of pin left for [param side]; 0 if not pinned.
func get_pin_left(side: int) -> float:
	return float(_pins.get(side, 0.0))


## Removes every effect without emitting signals.
func clear() -> void:
	_burning.clear()
	_pins.clear()


# Sides of the living units standing on [param cell].
func _units_on(cell: Vector2i, state: CombatState) -> Array[int]:
	var out: Array[int] = []
	if not state.is_player_dead() and state.player_cell == cell:
		out.append(CombatState.Side.PLAYER)
	if not state.is_enemy_dead() and state.enemy_cell == cell:
		out.append(CombatState.Side.ENEMY)
	return out

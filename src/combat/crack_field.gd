class_name CrackField
extends RefCounted
## Cracked board cells (Story 023, OSFE TileType Cracked): cell -> seconds left, plus announced
## (warning) cells -> seconds until they crack. Pure data + a clock, no board knowledge.
## A cracked cell cannot be stepped onto (the owner installs [method is_cracked] as the mover's
## blocked_cell_fn); it expires on its own. Time reaches it only through [method tick].
## Implements: Story 023 (`slam`).

## Cells that just cracked (warning ran out); emitted once per batch.
signal cracked(cells: Array[Vector2i])
## A cracked cell expired.
signal expired(cell: Vector2i)

var _cracked: Dictionary = {}
var _warned: Dictionary = {}
var _crack_sec: float = 0.0


## Announces [param cells]: they crack after [param warn_sec], then stay cracked [param crack_sec].
func announce(cells: Array[Vector2i], warn_sec: float, crack_sec: float) -> void:
	_crack_sec = maxf(crack_sec, 0.0)
	var done: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if warn_sec <= 0.0:
			_cracked[cell] = _crack_sec
			done.append(cell)
		else:
			_warned[cell] = warn_sec
	if not done.is_empty():
		cracked.emit(done)


## Advances every timer by [param step] seconds.
func tick(step: float) -> void:
	var now_cracked: Array[Vector2i] = []
	for cell: Vector2i in _warned.keys():
		_warned[cell] = float(_warned[cell]) - step
		if float(_warned[cell]) <= 0.0:
			_warned.erase(cell)
			_cracked[cell] = _crack_sec
			now_cracked.append(cell)
	if not now_cracked.is_empty():
		cracked.emit(now_cracked)
	for cell: Vector2i in _cracked.keys():
		if now_cracked.has(cell):
			continue
		_cracked[cell] = float(_cracked[cell]) - step
		if float(_cracked[cell]) <= 0.0:
			_cracked.erase(cell)
			expired.emit(cell)


## True while [param cell] is cracked.
func is_cracked(cell: Vector2i) -> bool:
	return _cracked.has(cell)


## True while [param cell] is announced and not yet cracked.
func is_warned(cell: Vector2i) -> bool:
	return _warned.has(cell)


## Cracked cells (sorted by y then x so the order is deterministic).
func get_cracked_cells() -> Array[Vector2i]:
	return _sorted(_cracked.keys())


## Announced cells (same order).
func get_warning_cells() -> Array[Vector2i]:
	return _sorted(_warned.keys())


## Seconds [param cell] stays cracked (0 when not cracked).
func time_left(cell: Vector2i) -> float:
	return float(_cracked.get(cell, 0.0))


## Forgets everything.
func clear() -> void:
	_cracked.clear()
	_warned.clear()


func _sorted(keys: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key: Variant in keys:
		out.append(key as Vector2i)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out

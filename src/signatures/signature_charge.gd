class_name SignatureCharge
extends RefCounted
## The signature charge bar (Story 021): grows by the cells of every player cut that is CAST.
## Pure logic, one per match (never carried across matches).

## Emitted after the bar changed.
signal changed

var _cells: int = 0
var _capacity: int = 1


## [param capacity] = cells needed for a full bar (>= 1).
func _init(capacity: int = 1) -> void:
	_capacity = maxi(capacity, 1)


## Adds [param cells] (ignored when <= 0); capped at the capacity.
func add(cells: int) -> void:
	if cells <= 0:
		return
	_cells = mini(_cells + cells, _capacity)
	changed.emit()


## Empties the bar.
func reset() -> void:
	_cells = 0
	changed.emit()


## Cells cast so far (capped).
func cells() -> int:
	return _cells


## Cells needed for a full bar.
func capacity() -> int:
	return _capacity


## 0..1.
func fraction() -> float:
	return clampf(float(_cells) / float(_capacity), 0.0, 1.0)


## True when full.
func is_full() -> bool:
	return _cells >= _capacity

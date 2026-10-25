class_name FormationMap
extends RefCounted
## The formation map ("Tran do", Story 029): one fade timer per REAL cell of the enemy half. A player
## cast that lands lights the cells it covers (hit or miss); a lit cell fades over [method get_fade_sec]
## seconds and must be covered again. When every real enemy cell is lit at once the map is complete
## (CombatView turns that into "signature ready" and resets it). Replaces the 18-cell signature charge.
## Pure logic, one per match (never carried across matches). Design: design/game-brief.md "Tran do".

## Seconds of timer below which a cell counts as dark (float residue of many small ticks).
const FADE_EPSILON: float = 0.000001

var _fade_sec: float = 1.0
## Real enemy cells in the order given at [method init] (deterministic).
var _order: Array[Vector2i] = []
## cell -> seconds left (0 = dark). Holds every real cell.
var _left: Dictionary = {}


## [param cells] = the REAL cells of the enemy half (e.g. grid.enemy_cells()); [param fade_sec] = seconds
## a covered cell stays lit (clamped to >= 0.001). Returns self.
func init(cells: Array[Vector2i], fade_sec: float) -> FormationMap:
	_fade_sec = maxf(fade_sec, 0.001)
	_order = []
	_left = {}
	for cell: Vector2i in cells:
		if not _left.has(cell):
			_order.append(cell)
			_left[cell] = 0.0
	return self


## Lights every cell of [param cells] that is a real enemy cell (timer back to full); others ignored.
func cover(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		if _left.has(cell):
			_left[cell] = _fade_sec


## Lights every real cell of [param cells] at a timer of [param fraction] (0..1) of the fade; dev/test only.
func set_cells(cells: Array[Vector2i], fraction: float) -> void:
	for cell: Vector2i in cells:
		if _left.has(cell):
			_left[cell] = clampf(fraction, 0.0, 1.0) * _fade_sec


## Subtracts [param dt] seconds from every lit timer (clamped at 0). dt <= 0 does nothing.
func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	for cell: Vector2i in _order:
		var left: float = float(_left[cell])
		if left > 0.0:
			# Snap float residue (e.g. 16.59 + 0.01 ticks) to dark so a cell lasts exactly fade_sec.
			var next: float = left - dt
			_left[cell] = next if next > FADE_EPSILON else 0.0


## Number of lit cells.
func lit_count() -> int:
	var n: int = 0
	for cell: Vector2i in _order:
		if float(_left[cell]) > 0.0:
			n += 1
	return n


## Number of real enemy cells.
func total() -> int:
	return _order.size()


## 0..1 of the fade left on [param cell] (1 = just covered, 0 = dark or not a real enemy cell).
func fraction_left(cell: Vector2i) -> float:
	if not _left.has(cell):
		return 0.0
	return clampf(float(_left[cell]) / _fade_sec, 0.0, 1.0)


## True when [param cell] is a real enemy cell with time left.
func is_lit(cell: Vector2i) -> bool:
	return _left.has(cell) and float(_left[cell]) > 0.0


## Lit cells, in the order of [method init].
func lit_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _order:
		if float(_left[cell]) > 0.0:
			out.append(cell)
	return out


## True when there is at least one real cell and every one of them is lit.
func is_complete() -> bool:
	return not _order.is_empty() and lit_count() == _order.size()


## Darkens every cell.
func reset() -> void:
	for cell: Vector2i in _order:
		_left[cell] = 0.0


## Seconds a covered cell stays lit.
func get_fade_sec() -> float:
	return _fade_sec

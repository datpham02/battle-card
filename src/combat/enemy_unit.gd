class_name EnemyUnit
extends RefCounted
## Multi-enemy Phase 1 (docs/design/world-map-v2/MULTI-ENEMY-PHASE1-DESIGN.md 3.1): the state of ONE enemy unit of a
## match, owned by [member CombatState.units]. Pure data plus the footprint geometry that used to live on CombatState
## (moved here, not copied: CombatState calls these for its unit 0 proxies). Index 0 is "the enemy" every pre-Phase-1
## caller knows; the legacy `enemy_*` fields of CombatState read and write THIS object through property proxies, so
## there is exactly one copy of each value.

## Position in [member CombatState.units] (0..CombatState.MAX_UNITS - 1).
var index: int = 0
## Template / match id ("" for the plain pre-Phase-1 match, whose unit 0 has no id of its own).
var id: String = ""
## Board cell the unit stands on: the ANCHOR (top-left cell) of [member footprint].
var cell: Vector2i = BoardGrid.NO_CELL
## Board-space offsets from [member cell] (dx, dy >= 0, (0, 0) always included; normalised, see
## [method CombatState.normalize_footprint]). [(0, 0)] = a 1-cell unit.
var footprint: Array[Vector2i] = [Vector2i.ZERO]
var max_hp: float = 100.0
var hp: float = 100.0
## HP never drops below this through damage (a boss phase floor); 0 = none.
var hp_floor: float = 0.0
## While > 0 the unit takes no damage (scaled simulation seconds).
var invulnerable_left: float = 0.0
## HP actually lost so far (clamped; overkill and ignored damage not counted).
var damage_taken: float = 0.0
## Callable() -> bool asked when a damage would take HP to 0; true = something took the death over (rebirth): the
## unit is held at [constant CombatState.HOLD_HP]. Invalid = no hook.
var death_hook_fn: Callable = Callable()
## Counts toward the victory condition ([method CombatState.all_required_dead]).
var required: bool = true
## Flat defense of this unit (Phase 2: SwingArbiter reads it per unit; Phase 1 stores it only).
var defense: float = 0.0
## Design / display label (attacker / tank / support / disruptor / ""); no logic reads it.
var role: String = ""
## Multi-enemy Phase 3: the resolved `enemies[]` entry this unit was built from (deep copy; {} for the plain
## pre-Phase-1 unit 0). CombatView reads its `brain`, `enemy` and `ai` block to build the unit's agent.
var source: Dictionary = {}


func _init(p_index: int = 0, p_id: String = "", p_max_hp: float = 100.0) -> void:
	index = p_index
	id = p_id
	max_hp = maxf(p_max_hp, 1.0)
	hp = max_hp


## True at 0 HP.
func is_dead() -> bool:
	return hp <= 0.0


## Board cells the footprint covers with its anchor on [param anchor] (footprint order; not validated).
func cells_at(anchor: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o: Vector2i in footprint:
		out.append(anchor + o)
	return out


## Board cells the unit covers now (anchor first).
func footprint_cells() -> Array[Vector2i]:
	return cells_at(cell)


## True when the footprint covers [param cell_at] now (dead or alive: callers check death).
func covers(cell_at: Vector2i) -> bool:
	return footprint.has(cell_at - cell)


## True when any cell of [param cells] lies under the footprint: ONE answer per call, so a resolution that asks once
## hits once however many footprint cells it covers (P2.2b).
func covers_any(cells: Array) -> bool:
	for o: Vector2i in footprint:
		if cells.has(cell + o):
			return true
	return false


## Width and height (cells) of the footprint's bounding rectangle (1x1 for a 1-cell unit).
func extent() -> Vector2i:
	var size: Vector2i = Vector2i.ONE
	for o: Vector2i in footprint:
		size = Vector2i(maxi(size.x, o.x + 1), maxi(size.y, o.y + 1))
	return size


## The cell the unit's casts start from: the FRONT-CENTRE of the footprint (nearest the divider = smallest board col,
## then nearest the centre of the footprint's row band, the upper one on a tie). The anchor for 1 cell.
func cast_origin() -> Vector2i:
	var cells: Array[Vector2i] = footprint_cells()
	var front: int = cells[0].x
	var top: int = cells[0].y
	var bottom: int = cells[0].y
	for c: Vector2i in cells:
		front = mini(front, c.x)
		top = mini(top, c.y)
		bottom = maxi(bottom, c.y)
	var best: Vector2i = BoardGrid.NO_CELL
	var best_d: int = 0
	for c: Vector2i in cells:
		if c.x != front:
			continue
		var d: int = absi(c.y * 2 - (top + bottom))
		if best == BoardGrid.NO_CELL or d < best_d or (d == best_d and c.y < best.y):
			best = c
			best_d = d
	return best


## The footprint cell a hit by [param cells] is drawn on: the covered cell nearest the footprint's centre (ties:
## upper, then left). The anchor when [param cells] covers nothing, and always for a 1-cell unit.
func hit_cell(cells: Array) -> Vector2i:
	var size: Vector2i = extent()
	var cx2: int = cell.x * 2 + size.x - 1
	var cy2: int = cell.y * 2 + size.y - 1
	var best: Vector2i = cell
	var best_d: int = -1
	for c: Vector2i in footprint_cells():
		if not cells.has(c):
			continue
		var d: int = (c.x * 2 - cx2) * (c.x * 2 - cx2) + (c.y * 2 - cy2) * (c.y * 2 - cy2)
		if best_d < 0 or d < best_d or (d == best_d and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			best = c
			best_d = d
	return best

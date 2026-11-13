class_name CombatState
extends RefCounted
## Pure-logic combat numbers: player HP and the enemy units' HP, plus unit cells. No scene
## dependency. The board (size, shape, halves) is a BoardGrid injected at construction.
## Implements: Story 003, Story 005 (player damage), Story 006 (board cells),
## Story 007 (cell_changed, armor removed, grid injection), P2.2b (multi-cell enemy footprint, D13 / ADR-0001 A7:
## [member enemy_footprint], [method enemy_in] = the one hit-once test, [method enemy_fits] = the one fit rule).
##
## Multi-enemy Phase 1 (docs/design/world-map-v2/MULTI-ENEMY-PHASE1-DESIGN.md): the enemy side is [member units], an
## array of [EnemyUnit] (1..[constant MAX_UNITS]). EVERY pre-Phase-1 member keeps its signature and its meaning and
## acts on unit 0: the `enemy_*` fields are property proxies (getter + setter, no storage of their own) onto
## `units[0]`, the legacy methods call the unit-indexed ones with index 0, and the legacy signals fire for unit 0
## only. A match with one unit therefore behaves exactly as before. Units 1.. are reached through the `*_unit` /
## `unit_*` API and the `unit_*` signals. Unit KEY: [method unit_key] (1 + index), so [constant Side.ENEMY] == the key
## of unit 0 and every side-keyed book elsewhere stays valid for it.

## Which half a unit belongs to.
enum Side { PLAYER, ENEMY }

## Emitted after any value changed.
signal changed
## Emitted once when UNIT 0 reaches 0 HP (legacy; see [signal unit_died] / [signal all_required_died]).
signal enemy_died
## Emitted once when the player reaches 0 HP (Story 007 listens for the defeat).
signal player_died
## Story 039: emitted when UNIT 0 gained HP through [method heal_enemy] ([param amount] = HP actually gained). The HUD
## reads it for the green heal number (burn_eater).
signal enemy_healed(amount: float)
## Emitted when a unit actually changes cell. [param side] is a [enum Side] value; for the enemy side only UNIT 0
## reports here (legacy), every unit reports on [signal unit_cell_changed].
signal cell_changed(side: int, old_cell: Vector2i, new_cell: Vector2i)
## Story 047: emitted when the unit of [param side] (a [enum Side] value) actually lost HP, with the HP it lost
## (after the floor / hook clamps; never 0). Not emitted for ignored damage (dead, invulnerable, non-positive).
## The UnitLayer plays the `hit` clip from it. Enemy side: UNIT 0 only (legacy; see [signal unit_damaged]).
signal damaged(side: int, amount: float)
## Phase 1: unit [param index] actually lost HP (every unit; fired BEFORE the legacy [signal damaged] for unit 0).
signal unit_damaged(index: int, amount: float)
## Phase 1: unit [param index] gained HP (every unit; before the legacy [signal enemy_healed] for unit 0).
signal unit_healed(index: int, amount: float)
## Phase 1: unit [param index] actually changed cell (every unit; before the legacy [signal cell_changed] for unit 0).
signal unit_cell_changed(index: int, old_cell: Vector2i, new_cell: Vector2i)
## Phase 1: unit [param index] reached 0 HP (every unit; before the legacy [signal enemy_died] for unit 0).
signal unit_died(index: int)
## Phase 1: the victory condition [method all_required_dead] just became true (once per match).
signal all_required_died

## Most enemy units a match holds (FormationRules.MAX_UNITS).
const MAX_UNITS: int = 4
## HP the enemy is held at while a death hook (rebirth) has taken the death over.
const HOLD_HP: float = 1.0

var player_max_hp: float
var player_hp: float
## The board the units stand on.
var grid: BoardGrid
## Board cell the player stands on (always a real cell of the player's half).
var player_cell: Vector2i = BoardGrid.NO_CELL
## Phase 1: the enemy units, index order; never empty. `units[0]` is "the enemy" of every legacy member.
var units: Array[EnemyUnit] = []
## Story 035 (match stats): HP the player actually lost so far this match. Read-only counter, no effect on the rules.
var player_damage_taken: float = 0.0
var _all_required_died_emitted: bool = false

# --- Legacy enemy fields: proxies onto units[0] (getter AND setter; nothing is stored here) -----------------------

## Board cell the enemy stands on (always a real cell of the enemy's half). With a multi-cell footprint (P2.2b, D13 /
## ADR-0001 A7) this is the footprint's ANCHOR: its top-left cell (smallest col and smallest row of the offsets).
var enemy_cell: Vector2i:
	get: return units[0].cell
	set(value): units[0].cell = value
## P2.2b: the enemy's footprint, board-space offsets from [member enemy_cell] (dx, dy >= 0, (0, 0) always included).
## Default [(0, 0)] = a 1-cell enemy, exactly the pre-P2.2b rules. Set with [method set_enemy_footprint].
var enemy_footprint: Array[Vector2i]:
	get: return units[0].footprint
	set(value): units[0].footprint = value
var enemy_max_hp: float:
	get: return units[0].max_hp
	set(value): units[0].max_hp = value
var enemy_hp: float:
	get: return units[0].hp
	set(value): units[0].hp = value
## Story 035 (boss phases): while > 0 the enemy takes no damage at all ([method damage_enemy] is ignored). The
## BossPhasesTrait sets it on a phase change and counts it down in scaled simulation seconds.
var enemy_invulnerable_left: float:
	get: return units[0].invulnerable_left
	set(value): units[0].invulnerable_left = value
## Story 035 (boss phases): enemy HP never drops below this value through [method damage_enemy] (a hit that would
## cross it is clamped at it), so a boss phase can never be skipped by one big hit. 0 = no floor (default).
var enemy_hp_floor: float:
	get: return units[0].hp_floor
	set(value): units[0].hp_floor = value
## Story 035 (match stats): HP the enemy actually lost so far this match (clamped HP, overkill and ignored damage not
## counted). Read-only counter, no effect on the rules.
var enemy_damage_taken: float:
	get: return units[0].damage_taken
	set(value): units[0].damage_taken = value
## Story 039 (rebirth): Callable() -> bool asked at the ONE place the enemy's death is decided (a damage that would
## take HP to 0). true = something took over (TraitHost.on_boss_would_die): the enemy is held at [constant HOLD_HP]
## instead of dying. Invalid = no hook (the old behaviour).
var enemy_death_hook_fn: Callable:
	get: return units[0].death_hook_fn
	set(value): units[0].death_hook_fn = value


## [param p_grid] is the board. A start cell of BoardGrid.NO_CELL means "use the grid's
## default cell"; any other cell outside the owner's half falls back to the default too
## (with a warning). Creates unit 0 (the pre-Phase-1 enemy) from [param p_enemy_max_hp] / [param p_enemy_cell].
func _init(
	p_grid: BoardGrid,
	p_player_max_hp: float = 100.0,
	p_enemy_max_hp: float = 100.0,
	p_player_cell: Vector2i = BoardGrid.NO_CELL,
	p_enemy_cell: Vector2i = BoardGrid.NO_CELL
) -> void:
	grid = p_grid
	player_max_hp = p_player_max_hp
	player_hp = p_player_max_hp
	var first: EnemyUnit = EnemyUnit.new(0, "", p_enemy_max_hp)
	first.max_hp = p_enemy_max_hp
	first.hp = p_enemy_max_hp
	first.cell = grid.default_enemy_cell()
	units.append(first)
	player_cell = grid.default_player_cell()
	if p_player_cell != BoardGrid.NO_CELL:
		if grid.is_player_cell(p_player_cell):
			player_cell = p_player_cell
		else:
			push_warning("CombatState: player start cell %s not in the player's half" % p_player_cell)
	if p_enemy_cell != BoardGrid.NO_CELL:
		if grid.is_enemy_cell(p_enemy_cell):
			first.cell = p_enemy_cell
		else:
			push_warning("CombatState: enemy start cell %s not in the enemy's half" % p_enemy_cell)


## Phase 1: builds the state of a match from its RESOLVED `match_params` (RunConfig.MATCH_KEYS): unit 0 exactly as
## [method _init] with `boss_max_hp`, then one unit per further `enemies[]` entry (`template_id`, `max_hp`,
## `footprint`, `required`, `role`, `defense`: numbers already scaled by RunConfig.from_node; nothing is looked up or
## scaled here). An entry whose footprint fits nowhere is skipped with a warning (the fight still runs). Without
## `enemies` (every plain match) the result is identical to [method _init].
static func from_match_params(p_grid: BoardGrid, p_player_max_hp: float, params: Dictionary,
		p_player_cell: Vector2i = BoardGrid.NO_CELL, p_enemy_cell: Vector2i = BoardGrid.NO_CELL) -> CombatState:
	var state := CombatState.new(p_grid, p_player_max_hp, maxf(float(params.get("boss_max_hp", 100.0)), 1.0), p_player_cell, p_enemy_cell)
	var entries: Variant = params.get("enemies", [])
	if typeof(entries) != TYPE_ARRAY or (entries as Array).is_empty():
		return state
	var first: Dictionary = (entries as Array)[0] if typeof((entries as Array)[0]) == TYPE_DICTIONARY else {}
	state.units[0].id = str(first.get("template_id", first.get("id", params.get("id", ""))))
	state.units[0].role = str(first.get("role", ""))
	state.units[0].required = bool(first.get("required", true))
	state.units[0].defense = maxf(float(params.get("boss_defense", 0.0)), 0.0)
	state.units[0].source = first.duplicate(true)
	# Unit 0's footprint from its entry (the same offsets PatternController sets later from enemy_skills.json, so
	# re-setting them is idempotent); set BEFORE the other units so they spawn clear of it.
	var first_fp: Array[Vector2i] = _footprint_from_entry(first)
	if first_fp.size() > 1:
		state.set_unit_footprint(0, first_fp)
	for i: int in range(1, (entries as Array).size()):
		var e: Variant = (entries as Array)[i]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = e as Dictionary
		var index: int = state.add_unit(str(entry.get("template_id", entry.get("id", ""))), float(entry.get("max_hp", 100.0)),
				_footprint_from_entry(entry), BoardGrid.NO_CELL, bool(entry.get("required", true)))
		if index < 0:
			push_warning("CombatState: enemies[%d] '%s' fits nowhere / over the cap, skipped" % [i, entry.get("id", "")])
			continue
		state.units[index].role = str(entry.get("role", ""))
		state.units[index].defense = maxf(float(entry.get("defense", 0.0)), 0.0)
		state.units[index].source = entry.duplicate(true)
	return state


# A resolved entry's `footprint` ([[dx, dy], ...] or Vector2i list) as offsets; [(0, 0)] when absent / malformed.
static func _footprint_from_entry(entry: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(entry.get("footprint")) == TYPE_ARRAY:
		for cell: Variant in entry["footprint"] as Array:
			if typeof(cell) == TYPE_ARRAY and (cell as Array).size() == 2:
				out.append(Vector2i(int((cell as Array)[0]), int((cell as Array)[1])))
			elif typeof(cell) == TYPE_VECTOR2I:
				out.append(cell as Vector2i)
	return normalize_footprint(out)


# --- Unit identity ------------------------------------------------------------------------------------------------

## The key of unit [param index] in side-keyed books: 1 + index, so unit 0's key is [constant Side.ENEMY] (1) and the
## player's is [constant Side.PLAYER] (0).
static func unit_key(index: int) -> int:
	return 1 + index


## The unit index of [param key]: -1 for [constant Side.PLAYER] (0), else key - 1.
static func unit_index_of(key: int) -> int:
	return key - 1


## Number of enemy units (>= 1).
func unit_count() -> int:
	return units.size()


## Unit [param index]; null when out of range.
func get_unit(index: int) -> EnemyUnit:
	if index < 0 or index >= units.size():
		return null
	return units[index]


## Indices of the units still alive, ascending.
func living_units() -> Array[int]:
	var out: Array[int] = []
	for u: EnemyUnit in units:
		if not u.is_dead():
			out.append(u.index)
	return out


## Phase 1: adds a unit with [param id], [param max_hp] and [param footprint] (normalised) at [param anchor], or at
## [method default_unit_anchor] when [param anchor] is NO_CELL or does not fit. Returns its index, or -1 (nothing
## changed, no unit moved) when the cap is reached or no anchor of the half fits around the living units.
func add_unit(id: String, max_hp: float, footprint: Array[Vector2i] = [Vector2i.ZERO], anchor: Vector2i = BoardGrid.NO_CELL,
		required: bool = true) -> int:
	if units.size() >= MAX_UNITS:
		push_warning("CombatState: unit cap %d reached, '%s' not added" % [MAX_UNITS, id])
		return -1
	var unit: EnemyUnit = EnemyUnit.new(units.size(), id, max_hp)
	unit.footprint = normalize_footprint(footprint)
	unit.required = required
	units.append(unit)
	var start: Vector2i = anchor if (anchor != BoardGrid.NO_CELL and unit_fits(unit.index, anchor)) else default_unit_anchor(unit.index)
	if start == BoardGrid.NO_CELL:
		units.pop_back()
		return -1
	unit.cell = start
	changed.emit()
	return unit.index


# --- Death and victory ----------------------------------------------------------------------------------------------

## True when UNIT 0 has 0 HP (legacy meaning kept in Phase 1; see [method all_required_dead]).
func is_enemy_dead() -> bool:
	return units[0].is_dead()


## True when unit [param index] has 0 HP (true for an index out of range).
func is_unit_dead(index: int) -> bool:
	var u: EnemyUnit = get_unit(index)
	return u == null or u.is_dead()


## The victory condition: every unit with `required` is dead. When NO unit is required (API misuse; FormationRules
## refuses such data) it falls back to "every unit is dead", so it is never true at match start.
func all_required_dead() -> bool:
	var saw_required: bool = false
	var all_dead: bool = true
	for u: EnemyUnit in units:
		if u.required:
			saw_required = true
			if not u.is_dead():
				return false
		if not u.is_dead():
			all_dead = false
	return true if saw_required else all_dead


## True while at least one unit lives.
func any_enemy_alive() -> bool:
	return not living_units().is_empty()


# --- Damage and heal ------------------------------------------------------------------------------------------------

## Subtracts [param amount] from UNIT 0's HP (floored at 0, or at [member enemy_hp_floor] while that is set).
## Ignored once dead and while [member enemy_invulnerable_left] > 0.
func damage_enemy(amount: float) -> void:
	damage_unit(0, amount)


## Phase 1: [method damage_enemy] for unit [param index]. Signal order for unit 0: unit_damaged, damaged(ENEMY),
## changed, unit_died, enemy_died, all_required_died; another unit skips the three legacy signals.
func damage_unit(index: int, amount: float) -> void:
	var u: EnemyUnit = get_unit(index)
	if u == null or u.is_dead() or amount <= 0.0 or u.invulnerable_left > 0.0:
		return
	var before: float = u.hp
	u.hp = maxf(u.hp - amount, minf(maxf(u.hp_floor, 0.0), u.hp))
	if u.hp <= 0.0 and u.death_hook_fn.is_valid() and bool(u.death_hook_fn.call()):
		u.hp = minf(HOLD_HP, before)
	if u.hp >= before:
		return
	u.damage_taken += before - u.hp
	unit_damaged.emit(index, before - u.hp)
	if index == 0:
		damaged.emit(Side.ENEMY, before - u.hp)
	changed.emit()
	if u.is_dead():
		unit_died.emit(index)
		if index == 0:
			enemy_died.emit()
		_check_all_required_died()


func _check_all_required_died() -> void:
	if _all_required_died_emitted or not all_required_dead():
		return
	_all_required_died_emitted = true
	all_required_died.emit()


## Story 039: gives UNIT 0 [param amount] HP (clamped to its max HP). Returns the HP actually gained; 0 when dead or
## the amount is not positive. Emits [signal enemy_healed] and [signal changed].
func heal_enemy(amount: float) -> float:
	return heal_unit(0, amount)


## Phase 1: [method heal_enemy] for unit [param index]. Order for unit 0: unit_healed, changed, enemy_healed.
func heal_unit(index: int, amount: float) -> float:
	var u: EnemyUnit = get_unit(index)
	if u == null or u.is_dead() or amount <= 0.0 or u.hp >= u.max_hp:
		return 0.0
	var before: float = u.hp
	u.hp = minf(u.hp + amount, u.max_hp)
	var gained: float = u.hp - before
	unit_healed.emit(index, gained)
	changed.emit()
	if index == 0:
		enemy_healed.emit(gained)
	return gained


## True when the player has 0 HP.
func is_player_dead() -> bool:
	return player_hp <= 0.0


# --- Cells ----------------------------------------------------------------------------------------------------------

## Moves the player to [param cell]. Returns false (no change) if the cell is not a real cell
## of the player's half or the player is dead. Emits cell_changed only on an actual change.
func set_player_cell(cell: Vector2i) -> bool:
	if is_player_dead() or not grid.is_player_cell(cell):
		return false
	var old: Vector2i = player_cell
	player_cell = cell
	if old != cell:
		cell_changed.emit(Side.PLAYER, old, cell)
	changed.emit()
	return true


## Moves UNIT 0 (its anchor) to [param cell]. Returns false (no change) if the footprint does not fit there
## ([method enemy_fits]: every footprint cell a real cell of the enemy's half, not under another living unit) or the
## unit is dead. Emits cell_changed only on an actual change. For a 1-cell enemy this is "a real cell of the enemy's
## half", as before P2.2b.
func set_enemy_cell(cell: Vector2i) -> bool:
	return set_unit_cell(0, cell)


## Phase 1: [method set_enemy_cell] for unit [param index] (legacy [signal cell_changed] only for unit 0).
func set_unit_cell(index: int, cell: Vector2i) -> bool:
	var u: EnemyUnit = get_unit(index)
	if u == null or u.is_dead() or not unit_fits(index, cell):
		return false
	var old: Vector2i = u.cell
	u.cell = cell
	if old != cell:
		unit_cell_changed.emit(index, old, cell)
		if index == 0:
			cell_changed.emit(Side.ENEMY, old, cell)
	changed.emit()
	return true


# --- P2.2b footprint (D13 / ADR-0001 A7) -------------------------------------------------------------------------

## Sets UNIT 0's footprint from board-space offsets (any order, duplicates ignored; shifted so the smallest dx and
## the smallest dy become 0, i.e. the anchor is the top-left of the bounding box). Empty = [(0, 0)]. When the current
## anchor no longer fits, the unit moves to [method default_enemy_anchor]; when NO anchor of the half fits, the
## footprint is refused (kept as it was, warning) and false is returned.
func set_enemy_footprint(offsets: Array[Vector2i]) -> bool:
	return set_unit_footprint(0, offsets)


## Phase 1: [method set_enemy_footprint] for unit [param index]. Other units are never moved.
func set_unit_footprint(index: int, offsets: Array[Vector2i]) -> bool:
	var u: EnemyUnit = get_unit(index)
	if u == null:
		return false
	var norm: Array[Vector2i] = normalize_footprint(offsets)
	var old_fp: Array[Vector2i] = u.footprint
	u.footprint = norm
	var start: Vector2i = default_unit_anchor(index)
	if start == BoardGrid.NO_CELL:
		push_warning("CombatState: footprint %s fits nowhere on the enemy half, kept %s" % [norm, old_fp])
		u.footprint = old_fp
		return false
	if not unit_fits(index, u.cell):
		var old: Vector2i = u.cell
		u.cell = start
		unit_cell_changed.emit(index, old, start)
		if index == 0:
			cell_changed.emit(Side.ENEMY, old, start)
		changed.emit()
	return true


## Pure: [param offsets] deduplicated and shifted so min dx = min dy = 0, sorted row by row (top first) then left to
## right; [(0, 0)] when empty.
static func normalize_footprint(offsets: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if offsets.is_empty():
		out.append(Vector2i.ZERO)
		return out
	var min_x: int = offsets[0].x
	var min_y: int = offsets[0].y
	for o: Vector2i in offsets:
		min_x = mini(min_x, o.x)
		min_y = mini(min_y, o.y)
	for o: Vector2i in offsets:
		var shifted: Vector2i = o - Vector2i(min_x, min_y)
		if not out.has(shifted):
			out.append(shifted)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## Number of cells UNIT 0 covers (1 = the classic 1-cell enemy).
func enemy_footprint_size() -> int:
	return units[0].footprint.size()


## Board cells UNIT 0's footprint covers with its anchor on [param anchor] (footprint order; not validated).
func footprint_cells_at(anchor: Vector2i) -> Array[Vector2i]:
	return units[0].cells_at(anchor)


## Board cells UNIT 0 covers now (anchor first). Not BoardGrid.enemy_cells(), which is the whole half.
func enemy_footprint_cells() -> Array[Vector2i]:
	return units[0].footprint_cells()


## True when UNIT 0's footprint covers [param cell] now (dead or alive: callers check death as before).
func is_enemy_at(cell: Vector2i) -> bool:
	return units[0].covers(cell)


## True when any cell of [param cells] lies under UNIT 0's footprint: THE "does this hit the boss" test of P2.2b.
## One answer per call, so a resolution that asks it once hits once however many footprint cells it covers.
## Phase 1 keeps the unit-0 meaning; [method enemies_in] answers for every unit.
func enemy_in(cells: Array) -> bool:
	return units[0].covers_any(cells)


## Phase 1: indices of the LIVING units whose footprint covers any cell of [param cells], ascending.
func enemies_in(cells: Array) -> Array[int]:
	var out: Array[int] = []
	for u: EnemyUnit in units:
		if not u.is_dead() and u.covers_any(cells):
			out.append(u.index)
	return out


## Phase 1: index of the LIVING unit covering [param cell], -1 when none.
func enemy_at(cell: Vector2i) -> int:
	for u: EnemyUnit in units:
		if not u.is_dead() and u.covers(cell):
			return u.index
	return -1


## Phase 1: every cell covered by a unit (living ones only with [param alive_only]), unit order.
func all_enemy_cells(alive_only: bool = true) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for u: EnemyUnit in units:
		if alive_only and u.is_dead():
			continue
		out.append_array(u.footprint_cells())
	return out


## True when UNIT 0's footprint fits with its anchor on [param anchor]: every cell a real cell of the enemy's half
## (not missing, not across the divider), none under another LIVING unit and, with [param blocked_fn]
## (Callable(cell) -> bool, true = blocked: hole, sand...), none blocked. For a 1-cell enemy alone:
## grid.is_enemy_cell(anchor) (and not blocked).
func enemy_fits(anchor: Vector2i, blocked_fn: Callable = Callable()) -> bool:
	return unit_fits(0, anchor, blocked_fn)


## Phase 1: [method enemy_fits] for unit [param index]: grid, [param blocked_fn], and the cells of every OTHER living
## unit (a dead unit frees its cells).
func unit_fits(index: int, anchor: Vector2i, blocked_fn: Callable = Callable()) -> bool:
	var u: EnemyUnit = get_unit(index)
	if u == null:
		return false
	for o: Vector2i in u.footprint:
		var cell: Vector2i = anchor + o
		if not grid.is_enemy_cell(cell):
			return false
		if blocked_fn.is_valid() and bool(blocked_fn.call(cell)):
			return false
		for other: EnemyUnit in units:
			if other.index != index and not other.is_dead() and other.covers(cell):
				return false
	return true


## Every anchor of the enemy's half where UNIT 0's footprint fits ([method enemy_fits] without blockers), row by row.
func enemy_anchors() -> Array[Vector2i]:
	return unit_anchors(0)


## Phase 1: [method enemy_anchors] for unit [param index].
func unit_anchors(index: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in grid.enemy_cells():
		if unit_fits(index, cell):
			out.append(cell)
	return out


## The start anchor of UNIT 0: the fitting anchor whose footprint centre is nearest the centre of the enemy's half
## (ties: nearer the divider, then the upper one). BoardGrid.default_enemy_cell() for a 1-cell enemy alone. NO_CELL
## when nothing fits.
func default_enemy_anchor() -> Vector2i:
	return default_unit_anchor(0)


## Phase 1: [method default_enemy_anchor] for unit [param index]. A 1-cell unit takes the grid's default cell when
## that is free, else the nearest-centre rule like a multi-cell one.
func default_unit_anchor(index: int) -> Vector2i:
	var u: EnemyUnit = get_unit(index)
	if u == null:
		return BoardGrid.NO_CELL
	if u.footprint.size() == 1 and unit_fits(index, grid.default_enemy_cell()):
		return grid.default_enemy_cell()
	var best: Vector2i = BoardGrid.NO_CELL
	var best_dist: int = 0
	var size: Vector2i = u.extent()
	# Doubled integers keep the ties exact: centre of the half and of the footprint at an anchor, board space.
	var half_cx2: int = grid.side_cols * 3 - 1
	var half_cy2: int = grid.side_rows - 1
	for anchor: Vector2i in unit_anchors(index):
		var dx: int = anchor.x * 2 + size.x - 1 - half_cx2
		var dy: int = anchor.y * 2 + size.y - 1 - half_cy2
		var dist: int = dx * dx + dy * dy
		# unit_anchors() runs top row first, left to right: a strict < keeps the upper / nearer-divider anchor.
		if best == BoardGrid.NO_CELL or dist < best_dist or (dist == best_dist and anchor.x < best.x):
			best = anchor
			best_dist = dist
	return best


## The cell UNIT 0's casts start from (CASTER_TO_TARGET / travel paths, P2.2b decision 5): the FRONT-CENTRE of the
## footprint (see [method EnemyUnit.cast_origin]). The anchor for 1 cell.
func enemy_cast_origin() -> Vector2i:
	return units[0].cast_origin()


## The footprint cell of UNIT 0 a hit by [param cells] is drawn on (see [method EnemyUnit.hit_cell]).
func enemy_hit_cell(cells: Array) -> Vector2i:
	return units[0].hit_cell(cells)


# --- Side / key API ------------------------------------------------------------------------------------------------
# Phase 2 (MULTI-ENEMY-PHASE2-PREFLIGHT.md 7.1): every function below that takes `side` takes a unit KEY: 0 = the
# player, 1 + i = enemy unit i ([method unit_key]). Key 1 IS [constant Side.ENEMY] (unit 0), so every pre-Phase-2
# caller, which only ever passes 0 or 1, gets exactly its old answer. An unknown enemy key answers "no unit": no
# cells, never covered, never fits, damage ignored.

## The half a unit KEY stands on: [constant Side.PLAYER] for key 0, [constant Side.ENEMY] for every enemy unit.
static func side_of(key: int) -> int:
	return Side.PLAYER if key == Side.PLAYER else Side.ENEMY


# The enemy unit of [param key] (null for the player or an unknown key).
func _unit_of_key(key: int) -> EnemyUnit:
	return null if key == Side.PLAYER else get_unit(unit_index_of(key))


## Board cells the unit of [param side] (a key) covers: [player_cell], or that enemy unit's footprint cells.
func unit_cells(side: int) -> Array[Vector2i]:
	if side == Side.PLAYER:
		var one: Array[Vector2i] = [player_cell]
		return one
	var u: EnemyUnit = _unit_of_key(side)
	return u.footprint_cells() if u != null else ([] as Array[Vector2i])


## True when the unit of [param side] (a key) covers [param cell] (player: its cell; enemy unit: its footprint).
func unit_at(side: int, cell: Vector2i) -> bool:
	if side == Side.PLAYER:
		return player_cell == cell
	var u: EnemyUnit = _unit_of_key(side)
	return u != null and u.covers(cell)


## True when the unit of [param side] (a key) covers any cell of [param cells] (one answer per call: hit once).
func unit_in(side: int, cells: Array) -> bool:
	if side == Side.PLAYER:
		return cells.has(player_cell)
	var u: EnemyUnit = _unit_of_key(side)
	return u != null and u.covers_any(cells)


## The cell a cast of [param side] (a key) starts from: the player's cell, or that unit's front-centre cell.
func cast_origin(side: int) -> Vector2i:
	if side == Side.PLAYER:
		return player_cell
	var u: EnemyUnit = _unit_of_key(side)
	return u.cast_origin() if u != null else BoardGrid.NO_CELL


## Width and height (cells) of UNIT 0's footprint bounding rectangle (1x1 for a 1-cell enemy).
func footprint_extent() -> Vector2i:
	return units[0].extent()


## Damages the unit of [param side] (a key); see damage_player / [method damage_unit].
func damage(side: int, amount: float) -> void:
	if side == Side.PLAYER:
		damage_player(amount)
	else:
		damage_unit(unit_index_of(side), amount)


## Board cell (anchor) of the unit of [param side] (a key); NO_CELL for an unknown enemy key.
func cell_of(side: int) -> Vector2i:
	if side == Side.PLAYER:
		return player_cell
	var u: EnemyUnit = _unit_of_key(side)
	return u.cell if u != null else BoardGrid.NO_CELL


## Phase 2: true when the unit of [param key] is dead (an unknown enemy key counts as dead).
func is_key_dead(key: int) -> bool:
	if key == Side.PLAYER:
		return is_player_dead()
	var u: EnemyUnit = _unit_of_key(key)
	return u == null or u.is_dead()


## Phase 2: HP / max HP of the unit of [param key] (0 for an unknown enemy key).
func hp_of(key: int) -> float:
	if key == Side.PLAYER:
		return player_hp
	var u: EnemyUnit = _unit_of_key(key)
	return u.hp if u != null else 0.0


func max_hp_of(key: int) -> float:
	if key == Side.PLAYER:
		return player_max_hp
	var u: EnemyUnit = _unit_of_key(key)
	return u.max_hp if u != null else 0.0


## Phase 2: heals the ENEMY unit of [param key] (see [method heal_unit]); the player has its own heal paths. Returns the
## HP gained (0 for the player key or an unknown key).
func heal_key(key: int, amount: float) -> float:
	if key == Side.PLAYER:
		return 0.0
	return heal_unit(unit_index_of(key), amount)


## Phase 2: [method unit_fits] for the unit of [param key]; the player fits on any real cell of its half not blocked.
func key_fits(key: int, anchor: Vector2i, blocked_fn: Callable = Callable()) -> bool:
	if key == Side.PLAYER:
		return grid.is_player_cell(anchor) and not (blocked_fn.is_valid() and bool(blocked_fn.call(anchor)))
	return unit_fits(unit_index_of(key), anchor, blocked_fn)


## Phase 2: moves the unit of [param key] ([method set_player_cell] / [method set_unit_cell]: occupancy checked).
func set_key_cell(key: int, cell: Vector2i) -> bool:
	if key == Side.PLAYER:
		return set_player_cell(cell)
	return set_unit_cell(unit_index_of(key), cell)


## Phase 2: the cell a hit by [param cells] on the unit of [param key] is drawn on (the player's cell for key 0).
func hit_cell_of(key: int, cells: Array) -> Vector2i:
	if key == Side.PLAYER:
		return player_cell
	var u: EnemyUnit = _unit_of_key(key)
	return u.hit_cell(cells) if u != null else BoardGrid.NO_CELL


## Phase 2: footprint size of the unit of [param key] (1 for the player, 0 for an unknown key).
func footprint_size_of(key: int) -> int:
	if key == Side.PLAYER:
		return 1
	var u: EnemyUnit = _unit_of_key(key)
	return u.footprint.size() if u != null else 0


## Phase 2: the cells the unit of [param key] would cover with its anchor on [param anchor].
func cells_at_key(key: int, anchor: Vector2i) -> Array[Vector2i]:
	if key == Side.PLAYER:
		var one: Array[Vector2i] = [anchor]
		return one
	var u: EnemyUnit = _unit_of_key(key)
	return u.cells_at(anchor) if u != null else ([] as Array[Vector2i])


## Phase 2: the keys of the enemy units, index order (living only with [param alive_only]).
func enemy_keys(alive_only: bool = true) -> Array[int]:
	var out: Array[int] = []
	for u: EnemyUnit in units:
		if alive_only and u.is_dead():
			continue
		out.append(unit_key(u.index))
	return out


## Phase 2: the keys of every unit that may stand on the board: the player, then each enemy unit (dead ones included;
## callers check death).
func all_keys() -> Array[int]:
	var out: Array[int] = [Side.PLAYER]
	out.append_array(enemy_keys(false))
	return out


## Phase 2: the keys of the LIVING enemy units whose footprint covers any cell of [param cells], index order.
func enemy_keys_in(cells: Array) -> Array[int]:
	var out: Array[int] = []
	for i: int in enemies_in(cells):
		out.append(unit_key(i))
	return out


## Phase 2: the key of the living unit standing on [param cell] of [param half] ([constant Side.PLAYER] or
## [constant Side.ENEMY]); -1 when none.
func key_at(half: int, cell: Vector2i) -> int:
	if half == Side.PLAYER:
		return Side.PLAYER if (not is_player_dead() and player_cell == cell) else -1
	var i: int = enemy_at(cell)
	return unit_key(i) if i >= 0 else -1


# --- Key-addressed aliases kept from Phase 1 ------------------------------------------------------------------------

## Damages the unit of [param key] (same as [method damage]).
func damage_key(key: int, amount: float) -> void:
	damage(key, amount)


## Anchor cell of the unit of [param key] (same as [method cell_of]).
func cell_of_key(key: int) -> Vector2i:
	return cell_of(key)


## Cells the unit of [param key] covers (same as [method unit_cells]).
func unit_cells_of_key(key: int) -> Array[Vector2i]:
	return unit_cells(key)


# --- Player ---------------------------------------------------------------------------------------------------------

## Sets the player's HP to [param hp] clamped to 0..player_max_hp (match start with carried
## HP). Emits changed; ignored once dead.
func set_player_hp(hp: float) -> void:
	if is_player_dead():
		return
	player_hp = clampf(hp, 0.0, player_max_hp)
	changed.emit()
	if is_player_dead():
		player_died.emit()


## Hits the player: reduces HP (floored at 0, no overkill). Ignored once dead.
func damage_player(amount: float) -> void:
	if is_player_dead() or amount <= 0.0:
		return
	var before: float = player_hp
	player_hp = maxf(player_hp - amount, 0.0)
	player_damage_taken += before - player_hp
	damaged.emit(Side.PLAYER, before - player_hp)
	changed.emit()
	if is_player_dead():
		player_died.emit()

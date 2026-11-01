class_name CombatState
extends RefCounted
## Pure-logic combat numbers: player HP and one dummy enemy's HP, plus unit cells. No scene
## dependency. The board (size, shape, halves) is a BoardGrid injected at construction.
## Implements: Story 003, Story 005 (player damage), Story 006 (board cells),
## Story 007 (cell_changed, armor removed, grid injection), P2.2b (multi-cell enemy footprint, D13 / ADR-0001 A7:
## [member enemy_footprint], [method enemy_in] = the one hit-once test, [method enemy_fits] = the one fit rule).

## Which half a unit belongs to.
enum Side { PLAYER, ENEMY }

## Emitted after any value changed.
signal changed
## Emitted once when the enemy reaches 0 HP.
signal enemy_died
## Emitted once when the player reaches 0 HP (Story 007 listens for the defeat).
signal player_died
## Story 039: emitted when the enemy gained HP through [method heal_enemy] ([param amount] = HP actually gained). The HUD
## reads it for the green heal number (burn_eater).
signal enemy_healed(amount: float)
## Emitted when a unit actually changes cell. [param side] is a [enum Side] value.
signal cell_changed(side: int, old_cell: Vector2i, new_cell: Vector2i)
## Story 047: emitted when the unit of [param side] (a [enum Side] value) actually lost HP, with the HP it lost
## (after the floor / hook clamps; never 0). Not emitted for ignored damage (dead, invulnerable, non-positive).
## The UnitLayer plays the `hit` clip from it.
signal damaged(side: int, amount: float)

var player_max_hp: float
var player_hp: float
## The board the units stand on.
var grid: BoardGrid
## Board cell the player stands on (always a real cell of the player's half).
var player_cell: Vector2i = BoardGrid.NO_CELL
## Board cell the enemy stands on (always a real cell of the enemy's half). With a multi-cell footprint (P2.2b, D13 /
## ADR-0001 A7) this is the footprint's ANCHOR: its top-left cell (smallest col and smallest row of the offsets).
var enemy_cell: Vector2i = BoardGrid.NO_CELL
## P2.2b: the enemy's footprint, board-space offsets from [member enemy_cell] (dx, dy >= 0, (0, 0) always included).
## Default [(0, 0)] = a 1-cell enemy, exactly the pre-P2.2b rules. Set with [method set_enemy_footprint].
var enemy_footprint: Array[Vector2i] = [Vector2i.ZERO]
var enemy_max_hp: float
var enemy_hp: float
## Story 035 (boss phases): while > 0 the enemy takes no damage at all ([method damage_enemy] is ignored). The
## BossPhasesTrait sets it on a phase change and counts it down in scaled simulation seconds.
var enemy_invulnerable_left: float = 0.0
## Story 035 (boss phases): enemy HP never drops below this value through [method damage_enemy] (a hit that would
## cross it is clamped at it), so a boss phase can never be skipped by one big hit. 0 = no floor (default).
var enemy_hp_floor: float = 0.0
## Story 035 (match stats): HP the enemy / the player actually lost so far this match (clamped HP, overkill and
## ignored damage not counted). Read-only counters, no effect on the rules.
var enemy_damage_taken: float = 0.0
var player_damage_taken: float = 0.0
## Story 039 (rebirth): Callable() -> bool asked at the ONE place the enemy's death is decided (a damage that would
## take HP to 0). true = something took over (TraitHost.on_boss_would_die): the enemy is held at [constant HOLD_HP]
## instead of dying. Invalid = no hook (the old behaviour).
var enemy_death_hook_fn: Callable = Callable()
## HP the enemy is held at while a death hook (rebirth) has taken the death over.
const HOLD_HP: float = 1.0


## [param p_grid] is the board. A start cell of BoardGrid.NO_CELL means "use the grid's
## default cell"; any other cell outside the owner's half falls back to the default too
## (with a warning).
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
	enemy_max_hp = p_enemy_max_hp
	enemy_hp = p_enemy_max_hp
	player_cell = grid.default_player_cell()
	enemy_cell = grid.default_enemy_cell()
	if p_player_cell != BoardGrid.NO_CELL:
		if grid.is_player_cell(p_player_cell):
			player_cell = p_player_cell
		else:
			push_warning("CombatState: player start cell %s not in the player's half" % p_player_cell)
	if p_enemy_cell != BoardGrid.NO_CELL:
		if grid.is_enemy_cell(p_enemy_cell):
			enemy_cell = p_enemy_cell
		else:
			push_warning("CombatState: enemy start cell %s not in the enemy's half" % p_enemy_cell)


## True when the enemy has 0 HP.
func is_enemy_dead() -> bool:
	return enemy_hp <= 0.0


## Subtracts [param amount] from enemy HP (floored at 0, or at [member enemy_hp_floor] while that is set).
## Ignored once dead and while [member enemy_invulnerable_left] > 0.
func damage_enemy(amount: float) -> void:
	if is_enemy_dead() or amount <= 0.0 or enemy_invulnerable_left > 0.0:
		return
	var before: float = enemy_hp
	enemy_hp = maxf(enemy_hp - amount, minf(maxf(enemy_hp_floor, 0.0), enemy_hp))
	if enemy_hp <= 0.0 and enemy_death_hook_fn.is_valid() and bool(enemy_death_hook_fn.call()):
		enemy_hp = minf(HOLD_HP, before)
	if enemy_hp >= before:
		return
	enemy_damage_taken += before - enemy_hp
	damaged.emit(Side.ENEMY, before - enemy_hp)
	changed.emit()
	if is_enemy_dead():
		enemy_died.emit()


## Story 039: gives the enemy [param amount] HP (clamped to its max HP). Returns the HP actually gained; 0 when dead or
## the amount is not positive. Emits [signal enemy_healed] and [signal changed].
func heal_enemy(amount: float) -> float:
	if is_enemy_dead() or amount <= 0.0 or enemy_hp >= enemy_max_hp:
		return 0.0
	var before: float = enemy_hp
	enemy_hp = minf(enemy_hp + amount, enemy_max_hp)
	var gained: float = enemy_hp - before
	changed.emit()
	enemy_healed.emit(gained)
	return gained


## True when the player has 0 HP.
func is_player_dead() -> bool:
	return player_hp <= 0.0


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


## Moves the enemy (its anchor) to [param cell]. Returns false (no change) if the footprint does not fit there
## ([method enemy_fits]: every footprint cell a real cell of the enemy's half) or the enemy is dead. Emits cell_changed
## only on an actual change. For a 1-cell enemy this is "a real cell of the enemy's half", as before P2.2b.
func set_enemy_cell(cell: Vector2i) -> bool:
	if is_enemy_dead() or not enemy_fits(cell):
		return false
	var old: Vector2i = enemy_cell
	enemy_cell = cell
	if old != cell:
		cell_changed.emit(Side.ENEMY, old, cell)
	changed.emit()
	return true


# --- P2.2b footprint (D13 / ADR-0001 A7) -------------------------------------------------------------------------

## Sets the enemy's footprint from board-space offsets (any order, duplicates ignored; shifted so the smallest dx and
## the smallest dy become 0, i.e. the anchor is the top-left of the bounding box). Empty = [(0, 0)]. When the current
## anchor no longer fits, the enemy moves to [method default_enemy_anchor]; when NO anchor of the half fits, the
## footprint is refused (kept as it was, warning) and false is returned.
func set_enemy_footprint(offsets: Array[Vector2i]) -> bool:
	var norm: Array[Vector2i] = normalize_footprint(offsets)
	var old_fp: Array[Vector2i] = enemy_footprint
	enemy_footprint = norm
	var start: Vector2i = default_enemy_anchor()
	if start == BoardGrid.NO_CELL:
		push_warning("CombatState: footprint %s fits nowhere on the enemy half, kept %s" % [norm, old_fp])
		enemy_footprint = old_fp
		return false
	if not enemy_fits(enemy_cell):
		var old: Vector2i = enemy_cell
		enemy_cell = start
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


## Number of cells the enemy covers (1 = the classic 1-cell enemy).
func enemy_footprint_size() -> int:
	return enemy_footprint.size()


## Board cells the enemy's footprint covers with its anchor on [param anchor] (footprint order; not validated).
func footprint_cells_at(anchor: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o: Vector2i in enemy_footprint:
		out.append(anchor + o)
	return out


## Board cells the enemy covers now (anchor first). Not BoardGrid.enemy_cells(), which is the whole half.
func enemy_footprint_cells() -> Array[Vector2i]:
	return footprint_cells_at(enemy_cell)


## True when the enemy's footprint covers [param cell] now (dead or alive: callers check death as before).
func is_enemy_at(cell: Vector2i) -> bool:
	return enemy_footprint.has(cell - enemy_cell)


## True when any cell of [param cells] lies under the enemy's footprint: THE "does this hit the boss" test of P2.2b.
## One answer per call, so a resolution that asks it once hits once however many footprint cells it covers.
func enemy_in(cells: Array) -> bool:
	for o: Vector2i in enemy_footprint:
		if cells.has(enemy_cell + o):
			return true
	return false


## True when the footprint fits with its anchor on [param anchor]: every cell a real cell of the enemy's half (not
## missing, not across the divider) and, with [param blocked_fn] (Callable(cell) -> bool, true = blocked: hole,
## sand...), none blocked. For a 1-cell enemy: grid.is_enemy_cell(anchor) (and not blocked).
func enemy_fits(anchor: Vector2i, blocked_fn: Callable = Callable()) -> bool:
	for o: Vector2i in enemy_footprint:
		var cell: Vector2i = anchor + o
		if not grid.is_enemy_cell(cell):
			return false
		if blocked_fn.is_valid() and bool(blocked_fn.call(cell)):
			return false
	return true


## Every anchor of the enemy's half where the footprint fits ([method enemy_fits] without blockers), row by row.
func enemy_anchors() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in grid.enemy_cells():
		if enemy_fits(cell):
			out.append(cell)
	return out


## The start anchor: the fitting anchor whose footprint centre is nearest the centre of the enemy's half (ties: nearer
## the divider, then the upper one). BoardGrid.default_enemy_cell() for a 1-cell enemy. NO_CELL when nothing fits.
func default_enemy_anchor() -> Vector2i:
	if enemy_footprint.size() == 1:
		return grid.default_enemy_cell()
	var best: Vector2i = BoardGrid.NO_CELL
	var best_dist: int = 0
	var size: Vector2i = footprint_extent()
	# Doubled integers keep the ties exact: centre of the half and of the footprint at an anchor, board space.
	var half_cx2: int = grid.side_cols * 3 - 1
	var half_cy2: int = grid.side_rows - 1
	for anchor: Vector2i in enemy_anchors():
		var dx: int = anchor.x * 2 + size.x - 1 - half_cx2
		var dy: int = anchor.y * 2 + size.y - 1 - half_cy2
		var dist: int = dx * dx + dy * dy
		# enemy_anchors() runs top row first, left to right: a strict < keeps the upper / nearer-divider anchor.
		if best == BoardGrid.NO_CELL or dist < best_dist or (dist == best_dist and anchor.x < best.x):
			best = anchor
			best_dist = dist
	return best


## The cell the enemy's casts start from (CASTER_TO_TARGET / travel paths, P2.2b decision 5): the FRONT-CENTRE of the
## footprint: among the footprint cells nearest the divider (smallest board col), the one nearest the centre of the
## footprint's row band, the upper one on a tie (a 2x2 boss casts from its upper front cell). The anchor for 1 cell.
func enemy_cast_origin() -> Vector2i:
	var cells: Array[Vector2i] = enemy_footprint_cells()
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


## The footprint cell a hit by [param cells] is drawn on: the covered footprint cell nearest the footprint's centre
## (ties: upper, then left), so the impact aims at the boss's middle. The anchor when [param cells] covers no
## footprint cell, and always for a 1-cell enemy.
func enemy_hit_cell(cells: Array) -> Vector2i:
	var size: Vector2i = footprint_extent()
	var cx2: int = enemy_cell.x * 2 + size.x - 1
	var cy2: int = enemy_cell.y * 2 + size.y - 1
	var best: Vector2i = enemy_cell
	var best_d: int = -1
	for c: Vector2i in enemy_footprint_cells():
		if not cells.has(c):
			continue
		var d: int = (c.x * 2 - cx2) * (c.x * 2 - cx2) + (c.y * 2 - cy2) * (c.y * 2 - cy2)
		if best_d < 0 or d < best_d or (d == best_d and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			best = c
			best_d = d
	return best


## Board cells the unit of [param side] covers: [player_cell], or the enemy's footprint cells.
func unit_cells(side: int) -> Array[Vector2i]:
	if side == Side.PLAYER:
		var one: Array[Vector2i] = [player_cell]
		return one
	return enemy_footprint_cells()


## True when the unit of [param side] covers [param cell] (player: its cell; enemy: [method is_enemy_at]).
func unit_at(side: int, cell: Vector2i) -> bool:
	return player_cell == cell if side == Side.PLAYER else is_enemy_at(cell)


## True when the unit of [param side] covers any cell of [param cells] (enemy: [method enemy_in]).
func unit_in(side: int, cells: Array) -> bool:
	return cells.has(player_cell) if side == Side.PLAYER else enemy_in(cells)


## The cell a cast of [param side] starts from: the player's cell, or [method enemy_cast_origin].
func cast_origin(side: int) -> Vector2i:
	return player_cell if side == Side.PLAYER else enemy_cast_origin()


## Width and height (cells) of the footprint's bounding rectangle (1x1 for a 1-cell enemy).
func footprint_extent() -> Vector2i:
	var size: Vector2i = Vector2i.ONE
	for o: Vector2i in enemy_footprint:
		size = Vector2i(maxi(size.x, o.x + 1), maxi(size.y, o.y + 1))
	return size


## Damages the unit of [param side] (a [enum Side] value); see damage_player / damage_enemy.
func damage(side: int, amount: float) -> void:
	if side == Side.PLAYER:
		damage_player(amount)
	else:
		damage_enemy(amount)


## Board cell of the unit of [param side] (a [enum Side] value).
func cell_of(side: int) -> Vector2i:
	return player_cell if side == Side.PLAYER else enemy_cell


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

class_name CombatState
extends RefCounted
## Pure-logic combat numbers: player HP and one dummy enemy's HP, plus unit cells. No scene
## dependency. The board (size, shape, halves) is a BoardGrid injected at construction.
## Implements: Story 003, Story 005 (player damage), Story 006 (board cells),
## Story 007 (cell_changed, armor removed, grid injection).

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

var player_max_hp: float
var player_hp: float
## The board the units stand on.
var grid: BoardGrid
## Board cell the player stands on (always a real cell of the player's half).
var player_cell: Vector2i = BoardGrid.NO_CELL
## Board cell the enemy stands on (always a real cell of the enemy's half).
var enemy_cell: Vector2i = BoardGrid.NO_CELL
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


## Moves the enemy to [param cell]. Returns false (no change) if the cell is not a real cell
## of the enemy's half or the enemy is dead. Emits cell_changed only on an actual change.
func set_enemy_cell(cell: Vector2i) -> bool:
	if is_enemy_dead() or not grid.is_enemy_cell(cell):
		return false
	var old: Vector2i = enemy_cell
	enemy_cell = cell
	if old != cell:
		cell_changed.emit(Side.ENEMY, old, cell)
	changed.emit()
	return true


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
	changed.emit()
	if is_player_dead():
		player_died.emit()

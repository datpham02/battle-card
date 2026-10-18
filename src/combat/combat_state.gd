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


## Subtracts [param amount] from enemy HP (floored at 0). Ignored once dead.
func damage_enemy(amount: float) -> void:
	if is_enemy_dead() or amount <= 0.0:
		return
	enemy_hp = maxf(enemy_hp - amount, 0.0)
	changed.emit()
	if is_enemy_dead():
		enemy_died.emit()


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


## Hits the player: reduces HP (floored at 0, no overkill). Ignored once dead.
func damage_player(amount: float) -> void:
	if is_player_dead() or amount <= 0.0:
		return
	player_hp = maxf(player_hp - amount, 0.0)
	changed.emit()
	if is_player_dead():
		player_died.emit()

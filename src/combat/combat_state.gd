class_name CombatState
extends RefCounted
## Pure-logic combat numbers: player HP/armor and one dummy enemy's HP. No scene
## dependency. Implements: Story 003, Story 005 (player damage), Story 006 (board cells).

## Emitted after any value changed.
signal changed
## Emitted once when the enemy reaches 0 HP.
signal enemy_died
## Emitted once when the player reaches 0 HP (Story 007 listens for the defeat).
signal player_died

## Fallback start cells, used when a constructor cell is outside the unit's half.
const DEFAULT_PLAYER_CELL: Vector2i = Vector2i(1, 1)
const DEFAULT_ENEMY_CELL: Vector2i = Vector2i(4, 1)

var player_max_hp: float
var player_hp: float
var player_armor: float = 0.0
## Board cell the player stands on (always in the player's half).
var player_cell: Vector2i = DEFAULT_PLAYER_CELL
## Board cell the enemy stands on (always in the enemy's half).
var enemy_cell: Vector2i = DEFAULT_ENEMY_CELL
var enemy_max_hp: float
var enemy_hp: float


## Start cells outside the owner's half fall back to the defaults (with a warning).
func _init(
	p_player_max_hp: float = 100.0,
	p_enemy_max_hp: float = 100.0,
	p_player_cell: Vector2i = DEFAULT_PLAYER_CELL,
	p_enemy_cell: Vector2i = DEFAULT_ENEMY_CELL
) -> void:
	player_max_hp = p_player_max_hp
	player_hp = p_player_max_hp
	enemy_max_hp = p_enemy_max_hp
	enemy_hp = p_enemy_max_hp
	if ScreenLayout.is_player_cell(p_player_cell):
		player_cell = p_player_cell
	else:
		push_warning("CombatState: player start cell %s not in the player's half" % p_player_cell)
	if ScreenLayout.is_enemy_cell(p_enemy_cell):
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


## Adds [param amount] armor to the player.
func add_armor(amount: float) -> void:
	if amount <= 0.0:
		return
	player_armor += amount
	changed.emit()


## True when the player has 0 HP.
func is_player_dead() -> bool:
	return player_hp <= 0.0


## Moves the player to [param cell]. Returns false (no change) if the cell is not in the
## player's half or the player is dead.
func set_player_cell(cell: Vector2i) -> bool:
	if is_player_dead() or not ScreenLayout.is_player_cell(cell):
		return false
	player_cell = cell
	changed.emit()
	return true


## Moves the enemy to [param cell]. Returns false (no change) if the cell is not in the
## enemy's half or the enemy is dead.
func set_enemy_cell(cell: Vector2i) -> bool:
	if is_enemy_dead() or not ScreenLayout.is_enemy_cell(cell):
		return false
	enemy_cell = cell
	changed.emit()
	return true


## Hits the player: armor absorbs first, the remainder reduces HP (floored at 0, no
## overkill). Ignored once dead.
func damage_player(amount: float) -> void:
	if is_player_dead() or amount <= 0.0:
		return
	var absorbed: float = minf(player_armor, amount)
	player_armor -= absorbed
	player_hp = maxf(player_hp - (amount - absorbed), 0.0)
	changed.emit()
	if is_player_dead():
		player_died.emit()

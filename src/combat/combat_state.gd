class_name CombatState
extends RefCounted
## Pure-logic combat numbers: player HP/armor and one dummy enemy's HP. No scene
## dependency. The dummy does not attack in Story 003. Implements: Story 003.

## Emitted after any value changed.
signal changed
## Emitted once when the enemy reaches 0 HP.
signal enemy_died

var player_max_hp: float
var player_hp: float
var player_armor: float = 0.0
var enemy_max_hp: float
var enemy_hp: float


func _init(p_player_max_hp: float = 100.0, p_enemy_max_hp: float = 100.0) -> void:
	player_max_hp = p_player_max_hp
	player_hp = p_player_max_hp
	enemy_max_hp = p_enemy_max_hp
	enemy_hp = p_enemy_max_hp


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

class_name CombatState
extends RefCounted
## Pure-logic combat numbers: player HP/armor and one dummy enemy's HP. No scene
## dependency. Implements: Story 003, Story 005 (player damage, lane).

## Emitted after any value changed.
signal changed
## Emitted once when the enemy reaches 0 HP.
signal enemy_died
## Emitted once when the player reaches 0 HP (Story 007 listens for the defeat).
signal player_died

## Lane the enemy always stands in (the middle one).
const ENEMY_LANE: int = 1

var player_max_hp: float
var player_hp: float
var player_armor: float = 0.0
## Lane (0..ScreenLayout.LANE_COUNT-1) the player stands in; starts in the middle.
var player_lane: int = 1
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


## True when the player has 0 HP.
func is_player_dead() -> bool:
	return player_hp <= 0.0


## Moves the player to [param lane] (clamped to a valid lane). Ignored once dead.
func set_player_lane(lane: int) -> void:
	if is_player_dead():
		return
	player_lane = clampi(lane, 0, ScreenLayout.LANE_COUNT - 1)
	changed.emit()


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

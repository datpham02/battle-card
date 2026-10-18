class_name CardPlayer
extends RefCounted
## Resolves playing a card: checks the rules, applies the data-driven effect to the
## [CombatState] and starts the card's recovery. No scene dependency.
## Rules: a card is rejected while recovery is running, once the enemy or player is dead,
## for a move card without a valid adjacent target cell in the player's half, or when its
## type has no effect entry. Attack cards hit if the enemy cell is in the resolved shape
## (player faces +col). Implements: Story 003, Story 006.

## Sentinel for "no target cell".
const NO_CELL: Vector2i = Vector2i(-1, -1)
## Player facing along the columns (toward the enemy half).
const PLAYER_FACING: int = 1

## Emitted after card [param type_id] was played successfully.
signal card_played(type_id: String)
## Emitted after an attack card resolved: [param cells] is the resolved shape, [param hit]
## whether the enemy cell was inside it.
signal attack_resolved(cells: Array[Vector2i], hit: bool)

var _config: CombatConfig
var _state: CombatState
var _lock: RecoveryLock


func _init(config: CombatConfig, state: CombatState, lock: RecoveryLock) -> void:
	_config = config
	_state = state
	_lock = lock


## The combat numbers.
func get_state() -> CombatState:
	return _state


## The recovery lock.
func get_lock() -> RecoveryLock:
	return _lock


## The combat data (timings, shapes).
func get_config() -> CombatConfig:
	return _config


## True if a card of [param type_id] could be played right now. A move card also needs
## [param target_cell] to be a cell adjacent (4 directions) to the player's, in the
## player's half; other cards ignore it.
func can_play(type_id: String, target_cell: Vector2i = NO_CELL) -> bool:
	var effect: CombatConfig.CardEffect = _config.get_effect(type_id)
	if (
		effect == null
		or _lock.is_locked()
		or _state.is_enemy_dead()
		or _state.is_player_dead()
	):
		return false
	if effect.effect == CombatConfig.EFFECT_MOVE:
		return is_valid_step(target_cell)
	return true


## True if the player could step onto [param cell] (adjacent, own half). Ignores recovery.
func is_valid_step(cell: Vector2i) -> bool:
	var delta: Vector2i = cell - _state.player_cell
	return ScreenLayout.is_player_cell(cell) and absi(delta.x) + absi(delta.y) == 1


## True if [param type_id] is a move card (needs a target cell to be played).
func is_move(type_id: String) -> bool:
	var effect: CombatConfig.CardEffect = _config.get_effect(type_id)
	return effect != null and effect.effect == CombatConfig.EFFECT_MOVE


## True if [param type_id] is an attack card (tap-to-use, shape preview).
func is_attack(type_id: String) -> bool:
	var effect: CombatConfig.CardEffect = _config.get_effect(type_id)
	return effect != null and effect.effect == CombatConfig.EFFECT_ATTACK


## Board cells the card would cover from the player's current cell (empty for move cards
## and unknown types).
func shape_cells(type_id: String) -> Array[Vector2i]:
	var effect: CombatConfig.CardEffect = _config.get_effect(type_id)
	if effect == null or effect.effect == CombatConfig.EFFECT_MOVE:
		return [] as Array[Vector2i]
	return AttackShape.resolve(effect.shape, _state.player_cell, PLAYER_FACING)


## Plays the card: effect applies immediately, then recovery starts. Returns false (no
## change) if [method can_play] is false.
func play(type_id: String, target_cell: Vector2i = NO_CELL) -> bool:
	if not can_play(type_id, target_cell):
		return false
	var effect: CombatConfig.CardEffect = _config.get_effect(type_id)
	match effect.effect:
		CombatConfig.EFFECT_ATTACK:
			var cells: Array[Vector2i] = shape_cells(type_id)
			var hit: bool = cells.has(_state.enemy_cell)
			if hit:
				_state.damage_enemy(effect.amount)
			attack_resolved.emit(cells, hit)
		CombatConfig.EFFECT_SHIELD:
			_state.add_armor(effect.amount)
		CombatConfig.EFFECT_MOVE:
			_state.set_player_cell(target_cell)
	_lock.start(effect.recovery_sec)
	card_played.emit(type_id)
	return true

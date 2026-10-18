class_name CardPlayer
extends RefCounted
## Resolves playing a card: checks the rules, applies the data-driven effect to the
## [CombatState] and starts the card's recovery. No scene dependency.
## Rules: a card is rejected while recovery is running, once the enemy is dead, or when
## its type has no effect entry. Implements: Story 003.

## Emitted after card [param type_id] was played successfully.
signal card_played(type_id: String)

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


## True if a card of [param type_id] could be played right now.
func can_play(type_id: String) -> bool:
	return (
		not _lock.is_locked()
		and not _state.is_enemy_dead()
		and _config.get_effect(type_id) != null
	)


## Plays the card: effect applies immediately, then recovery starts. Returns false (no
## change) if [method can_play] is false.
func play(type_id: String) -> bool:
	if not can_play(type_id):
		return false
	var effect: CombatConfig.CardEffect = _config.get_effect(type_id)
	if effect.effect == CombatConfig.EFFECT_ATTACK:
		_state.damage_enemy(effect.amount)
	else:
		_state.add_armor(effect.amount)
	_lock.start(effect.recovery_sec)
	card_played.emit(type_id)
	return true

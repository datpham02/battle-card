class_name CardPlayer
extends RefCounted
## Resolves playing a card: checks the rules, applies the data-driven effect to the
## [CombatState] and starts the card's recovery. No scene dependency.
## Rules: a card is rejected while recovery is running, once the enemy or player is dead, for a lane-shift card without an adjacent target lane, or when
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


## True if a card of [param type_id] could be played right now. A lane-shift card also
## needs [param target_lane] to be a lane adjacent to the player's; other cards ignore it.
func can_play(type_id: String, target_lane: int = -1) -> bool:
	var effect: CombatConfig.CardEffect = _config.get_effect(type_id)
	if (
		effect == null
		or _lock.is_locked()
		or _state.is_enemy_dead()
		or _state.is_player_dead()
	):
		return false
	if effect.lane_shift:
		return (
			target_lane >= 0
			and target_lane < ScreenLayout.LANE_COUNT
			and absi(target_lane - _state.player_lane) == 1
		)
	return true


## True if [param type_id] is a lane-shift card (needs a target lane to be played).
func is_lane_shift(type_id: String) -> bool:
	var effect: CombatConfig.CardEffect = _config.get_effect(type_id)
	return effect != null and effect.lane_shift


## Plays the card: effect applies immediately, then recovery starts. Returns false (no
## change) if [method can_play] is false.
func play(type_id: String, target_lane: int = -1) -> bool:
	if not can_play(type_id, target_lane):
		return false
	var effect: CombatConfig.CardEffect = _config.get_effect(type_id)
	if effect.effect == CombatConfig.EFFECT_ATTACK:
		_state.damage_enemy(effect.amount)
	else:
		_state.add_armor(effect.amount)
	if effect.lane_shift:
		_state.set_player_lane(target_lane)
	_lock.start(effect.recovery_sec)
	card_played.emit(type_id)
	return true

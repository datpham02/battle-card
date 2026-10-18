class_name EnemyLogic
extends RefCounted
## Enemy behaviour: runs the fixed cyclic attack pattern, one telegraphed attack at a time.
## State machine: IDLE --pause elapsed--> TELEGRAPHING --countdown hits 0--> (resolve) IDLE.
## Time only advances through [method tick] (injected delta). No scene dependency.
## The enemy does nothing while it or the player is dead. Implements: Story 005.

## Emitted when an attack starts its countdown.
signal attack_telegraphed(target_lane: int, damage: float)
## Emitted when a countdown reached 0. [param hit] is false if the player had left the lane.
signal attack_resolved(target_lane: int, damage: float, hit: bool)

## Returned by [method get_time_to_impact] when no attack is telegraphed.
const NO_ATTACK: float = -1.0
## Returned by [method get_target_lane] when no attack is telegraphed.
const NO_LANE: int = -1

enum Phase { IDLE, TELEGRAPHING }

var _config: EnemyPatternConfig
var _state: CombatState
var _phase: Phase = Phase.IDLE
var _remaining: float = 0.0
var _next_index: int = 0
var _current: EnemyPatternConfig.Attack = null


func _init(config: EnemyPatternConfig, state: CombatState) -> void:
	_config = config
	_state = state
	_remaining = config.initial_pause_sec


## Pattern settings (feedback duration etc.).
func get_config() -> EnemyPatternConfig:
	return _config


## True once the enemy or the player is dead; the enemy then does nothing.
func is_halted() -> bool:
	return _state.is_enemy_dead() or _state.is_player_dead()


## True while an attack is telegraphed and has not resolved yet.
func has_incoming_attack() -> bool:
	return _phase == Phase.TELEGRAPHING and _current != null and not is_halted()


## Seconds until the telegraphed attack lands, or [constant NO_ATTACK] (-1.0) if none.
## For "perfect timing" cards (Story 006).
func get_time_to_impact() -> float:
	return _remaining if has_incoming_attack() else NO_ATTACK


## Target lane of the telegraphed attack, or [constant NO_LANE] (-1) if none.
func get_target_lane() -> int:
	return _current.target_lane if has_incoming_attack() else NO_LANE


## Damage of the telegraphed attack, or 0 if none.
func get_incoming_damage() -> float:
	return _current.damage if has_incoming_attack() else 0.0


## Share of the countdown left (1 at telegraph start, 0 at impact); 0 if none.
func get_telegraph_ratio() -> float:
	if not has_incoming_attack():
		return 0.0
	return clampf(_remaining / _current.telegraph_sec, 0.0, 1.0)


## Advances time by [param delta] seconds, running as many phase changes as fit.
func tick(delta: float) -> void:
	if is_halted():
		_phase = Phase.IDLE
		_current = null
		return
	if _config.attacks.is_empty():
		return
	var left: float = delta
	while left > 0.0 and not is_halted():
		if _remaining > left:
			_remaining -= left
			return
		left -= _remaining
		_remaining = 0.0
		_advance()


func _advance() -> void:
	if _phase == Phase.IDLE:
		_current = _config.attacks[_next_index]
		_next_index = (_next_index + 1) % _config.attacks.size()
		_phase = Phase.TELEGRAPHING
		_remaining = _current.telegraph_sec
		attack_telegraphed.emit(_current.target_lane, _current.damage)
		return
	var attack: EnemyPatternConfig.Attack = _current
	var hit: bool = _state.player_lane == attack.target_lane
	_phase = Phase.IDLE
	_current = null
	_remaining = attack.pause_after_sec
	if hit:
		_state.damage_player(attack.damage)
	attack_resolved.emit(attack.target_lane, attack.damage, hit)

class_name UnitMover
extends RefCounted
## One-cell-per-press movement with a cooldown and no input buffering: presses during
## the cooldown are dropped. Used by the player now, the boss in Story 009.
## Implements: Story 007.

var _state: CombatState
var _side: int
var _cooldown_sec: float
var _remaining: float = 0.0


## [param side] is a CombatState.Side value.
func _init(state: CombatState, side: int, cooldown_sec: float) -> void:
	_state = state
	_side = side
	_cooldown_sec = maxf(cooldown_sec, 0.0)


## Tries to move one cell in [param direction] (a 4-way unit vector). Returns false and
## changes nothing when on cooldown, dead, off the owner's half or direction is invalid.
## Only an accepted move starts the cooldown.
func try_step(direction: Vector2i) -> bool:
	if _remaining > 0.0:
		return false
	if absi(direction.x) + absi(direction.y) != 1:
		return false
	var moved: bool
	if _side == CombatState.Side.PLAYER:
		moved = _state.set_player_cell(_state.player_cell + direction)
	else:
		moved = _state.set_enemy_cell(_state.enemy_cell + direction)
	if moved:
		_remaining = _cooldown_sec
	return moved


## Advances the cooldown.
func tick(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)


## Seconds until the next step is allowed.
func get_cooldown_remaining() -> float:
	return _remaining


## 0 = ready .. 1 = just moved.
func get_cooldown_fraction() -> float:
	if _cooldown_sec <= 0.0:
		return 0.0
	return clampf(_remaining / _cooldown_sec, 0.0, 1.0)


## True when a step would be accepted (ignoring walls).
func is_ready() -> bool:
	return _remaining <= 0.0

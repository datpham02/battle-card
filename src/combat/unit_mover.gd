class_name UnitMover
extends RefCounted
## One-cell-per-press movement with a cooldown and no input buffering: presses during
## the cooldown are dropped. Used by the player now, the boss in Story 009.
## Implements: Story 007.

var _state: CombatState
var _side: int
var _cooldown_sec: float
var _remaining: float = 0.0
var _status: StatusEffects = null
## Story 021: Callable() -> float multiplying the cooldown a step starts (0.0 = free steps); invalid = 1.
var cooldown_scale: Callable = Callable()
## Story 023: Callable(cell: Vector2i) -> bool; true = that cell cannot be stepped onto (slam's
## cracked cells). Invalid (default) = nothing blocked.
var blocked_cell_fn: Callable = Callable()
# Story 027: extra blockers, see add_blocker().
var _blockers: Array[Callable] = []
## Story 023: flat multiplier of every cooldown this mover starts (phase_shift speeds the boss up).
var cooldown_mult: float = 1.0
## Story 025: Callable() -> bool; true = the unit is rooted: try_step refuses (no cooldown started)
## and is_ready() is false (the boss while it swings). Invalid (default) = never locked.
var step_lock_fn: Callable = Callable()
## Story 036: Callable(from_cell: Vector2i) -> float multiplying the cooldown of the step that starts on
## [param from_cell] (mire: leaving a mire cell), applied AFTER [member cooldown_scale] so a free step stays free.
## Invalid (default) = 1.
var step_cost_fn: Callable = Callable()


## [param side] is a CombatState.Side value.
func _init(state: CombatState, side: int, cooldown_sec: float) -> void:
	_state = state
	_side = side
	_cooldown_sec = maxf(cooldown_sec, 0.0)


## Optional status effects; while this unit's side is pinned, try_step is refused (no
## cooldown started). Null (default) = never pinned.
func set_status(status: StatusEffects) -> void:
	_status = status


## Tries to move one cell in [param direction] (a 4-way unit vector). Returns false and
## changes nothing when on cooldown, dead, off the owner's half or direction is invalid.
## Only an accepted move starts the cooldown.
func try_step(direction: Vector2i) -> bool:
	if _remaining > 0.0 or is_step_locked():
		return false
	if _status != null and _status.is_pinned(_side):
		return false
	if absi(direction.x) + absi(direction.y) != 1:
		return false
	if is_cell_blocked(_state.cell_of(_side) + direction):
		return false
	var from_cell: Vector2i = _state.cell_of(_side)
	var moved: bool
	if _side == CombatState.Side.PLAYER:
		moved = _state.set_player_cell(_state.player_cell + direction)
	else:
		moved = _state.set_enemy_cell(_state.enemy_cell + direction)
	if moved:
		var scale: float = _scale()
		# Story 036: a plugged-in step cost (mire: leaving a mire cell) multiplies AFTER cooldown_scale, so a
		# free step (scale 0.0, Anh Bo) stays free.
		if scale > 0.0 and step_cost_fn.is_valid():
			scale *= maxf(float(step_cost_fn.call(from_cell)), 0.0)
		_remaining = _cooldown_sec * scale
	return moved


## Story 027: adds a step-destination blocker Callable(cell: Vector2i) -> bool that is OR-ed with
## [member blocked_cell_fn] and every other blocker (seals, cracks...). Safe to call from several
## sources: it never replaces anything, and a trait that overwrites blocked_cell_fn (slam) does not
## drop blockers added here. The same Callable added twice is kept once.
func add_blocker(fn: Callable) -> void:
	if fn.is_valid() and not _blockers.has(fn):
		_blockers.append(fn)


## Removes a blocker added with [method add_blocker] (no-op when absent).
func remove_blocker(fn: Callable) -> void:
	_blockers.erase(fn)


## True when [param cell] cannot be stepped onto: [member blocked_cell_fn] or any added blocker says so.
func is_cell_blocked(cell: Vector2i) -> bool:
	if blocked_cell_fn.is_valid() and bool(blocked_cell_fn.call(cell)):
		return true
	for fn: Callable in _blockers:
		if fn.is_valid() and bool(fn.call(cell)):
			return true
	return false


## Current cooldown multiplier (>= 0).
func _scale() -> float:
	var base: float = maxf(float(cooldown_scale.call()), 0.0) if cooldown_scale.is_valid() else 1.0
	return base * maxf(cooldown_mult, 0.0)


## Advances the cooldown.
func tick(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)


## Seconds until the next step is allowed.
func get_cooldown_remaining() -> float:
	return _remaining


## 0 = ready .. 1 = just moved.
func get_cooldown_fraction() -> float:
	if _cooldown_sec <= 0.0 or _remaining <= 0.0:
		return 0.0
	return clampf(_remaining / _cooldown_sec, 0.0, 1.0)


## True when a step would be accepted (ignoring walls).
func is_ready() -> bool:
	return _remaining <= 0.0 and not is_step_locked()


## True while [member step_lock_fn] says the unit is rooted (Story 025).
func is_step_locked() -> bool:
	return step_lock_fn.is_valid() and bool(step_lock_fn.call())

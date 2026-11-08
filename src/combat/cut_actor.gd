class_name CutActor
extends RefCounted
## One side's cut swing: holds at most ONE running swing (plus a 1-slot queue for the boss's
## combo), counts it down, and reports when it resolves. It does NOT apply damage (see
## CutEffects). Time advances only via [method tick].
## Implements: Story 008 (player), reused by Story 009 (boss), Story 013 (duration_mult, queue).

## Emitted when a swing starts. [param duration] is the windup in seconds.
signal swing_started(cells: Array[Vector2i], skill_id: String, duration: float)
## Emitted once when the countdown reaches zero.
signal swing_resolved(cells: Array[Vector2i], skill_id: String)
## Emitted when a running swing is cancelled (interrupt).
signal swing_cancelled(cells: Array[Vector2i], skill_id: String)
## Emitted when a queued (not yet started) swing is dropped because the running one was cancelled.
signal queue_cleared(cells: Array[Vector2i], skill_id: String)

## Which side owns this actor (a CombatState.Side value).
var side: int = 0
## Multiplies the windup computed from the cell count in [method begin_swing] (the boss's
## per-match swing speed). Queued swings keep the explicit duration they were given. > 0.
var duration_mult: float = 1.0:
	set(value):
		duration_mult = value if value > 0.0 else 1.0

## Story 018: optional Callable(cells: int, duration: float) -> float applied to the windup in
## [method begin_swing] (the player's passive); invalid = none. Queued swings are not touched.
var duration_modifier: Callable = Callable()
## Story 032: Callable(cells: int, sec: float) -> float applied LAST to the windup of a begun swing (the
## player's relics, RelicRegistry.fold_cast_time; called exactly once per begun swing, never for a refused
## one). The result is floored at 0 (a 0 s windup resolves on the next tick). Invalid = none.
var cast_time_modifier: Callable = Callable()
## Cast Commitment (Ngàn Kiếm): Callable(skill_id) -> float, seconds added to the swing of that card AFTER every other
## duration rule (cards.json channel_extend_sec). Unset = none.
var channel_extend_fn: Callable = Callable()

var _config: CutConfig
var _swinging: bool = false
var _time_left: float = 0.0
var _duration: float = 0.0
var _cells: Array[Vector2i] = []
var _skill_id: String = ""
var _level: int = 1
var _q_level: int = 1
var _target_is_enemy: bool = true
var _has_queued: bool = false
## Story 028: the one-shot featured-shape bonus the running swing carries ({} = none). Kept after the
## swing resolves (like the level) so the arbiter can read it while swing_resolved is emitted;
## cleared by [method cancel], by the next swing start and by [method consume_featured_bonus].
var _featured_bonus: Dictionary = {}
## Skill v2 B1 (CastContext): the record of the current (or just resolved) swing's cast; {} when none (boss swings,
## tests, dev paths). Same lifetime as the featured bonus.
var _cast_context: Dictionary = {}
var _q_cells: Array[Vector2i] = []
var _q_skill_id: String = ""
var _q_target_is_enemy: bool = true
var _q_duration: float = 0.0


func _init(cut_config: CutConfig, p_side: int) -> void:
	_config = cut_config
	side = p_side


## True when no swing is running.
func can_begin() -> bool:
	return not _swinging


## Starts a swing over [param cells]. Returns false if one is already running or the
## cell list is empty. Duration = CutConfig.swing_duration(cells) * [member duration_mult].
## Story 023: [param duration_override] > 0 fixes the windup (trait swings with their own telegraph).
## Story 028: a non-empty [param featured_bonus] ({damage_mult, effect, stacks, sec}) makes this a
## FEATURED swing: the bonus is applied once when it resolves with a hit (SwingArbiter, PLAYER side only).
func begin_swing(cells: Array[Vector2i], skill_id: String, target_is_enemy: bool, level: int = 1, duration_override: float = -1.0, featured_bonus: Dictionary = {}, cast_context: Dictionary = {}) -> bool:
	if _swinging or cells.is_empty():
		return false
	var duration: float = _config.swing_duration(cells.size()) * duration_mult
	if duration_modifier.is_valid():
		duration = float(duration_modifier.call(cells.size(), duration))
	if duration_override > 0.0:
		duration = duration_override
	if cast_time_modifier.is_valid():
		duration = maxf(float(cast_time_modifier.call(cells.size(), duration)), 0.0)
	# Cast Commitment: a channel card's extension comes after every modifier (the stab gap after the commit stays fixed).
	if channel_extend_fn.is_valid():
		duration += maxf(float(channel_extend_fn.call(skill_id)), 0.0)
	_featured_bonus = featured_bonus.duplicate(true)
	_cast_context = cast_context.duplicate(true)
	_start(cells, skill_id, target_is_enemy, duration, level)
	return true


## Queues ONE follow-up swing that starts automatically the moment the running swing resolves
## and lasts exactly [param duration] seconds (independent of its cell count and of
## [member duration_mult]). Refused (false) when no swing is running (use [method begin_swing]),
## when a swing is already queued, when [param cells] is empty or [param duration] <= 0.
## The queue is dropped when the running swing is cancelled.
func queue_swing(cells: Array[Vector2i], skill_id: String, target_is_enemy: bool, duration: float, level: int = 1) -> bool:
	if not _swinging or _has_queued or cells.is_empty() or duration <= 0.0:
		return false
	_has_queued = true
	_q_cells = cells.duplicate()
	_q_skill_id = skill_id
	_q_target_is_enemy = target_is_enemy
	_q_duration = duration
	_q_level = level
	return true


## True while a swing waits in the queue.
func has_queued() -> bool:
	return _has_queued


## Cells of the queued swing (empty when none).
func get_queued_cells() -> Array[Vector2i]:
	return _q_cells.duplicate()


## Windup of the queued swing (0 when none).
func get_queued_duration() -> float:
	return _q_duration if _has_queued else 0.0


## Skill id of the queued swing ("" when none).
func get_queued_skill_id() -> String:
	return _q_skill_id


## Drops the queued swing silently (no signal). No-op when none.
func clear_queue() -> void:
	_has_queued = false
	_q_cells = []
	_q_skill_id = ""
	_q_duration = 0.0


## Advances the swing by [param delta] seconds; resolves it (once) at zero, then starts the
## queued swing (if any) with its full duration: it is never ticked in the same call.
func tick(delta: float) -> void:
	if not _swinging:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	var cells: Array[Vector2i] = _cells
	var skill_id: String = _skill_id
	_clear()
	swing_resolved.emit(cells, skill_id)
	# A listener may have cancelled/queued in the meantime; start only a still-pending queue.
	if _has_queued and not _swinging:
		var next_cells: Array[Vector2i] = _q_cells
		var next_skill: String = _q_skill_id
		var next_target: bool = _q_target_is_enemy
		var next_duration: float = _q_duration
		var next_level: int = _q_level
		clear_queue()
		_featured_bonus = {}
		_cast_context = {}
		_start(next_cells, next_skill, next_target, next_duration, next_level)


## Cancels the running swing (no effect applied) and drops the queue. No-op when idle.
func cancel() -> void:
	if not _swinging:
		_drop_queue_with_signal()
		return
	var cells: Array[Vector2i] = _cells
	var skill_id: String = _skill_id
	_clear()
	_featured_bonus = {}
	_cast_context = {}
	swing_cancelled.emit(cells, skill_id)
	_drop_queue_with_signal()


## True while a swing is running.
func is_swinging() -> bool:
	return _swinging


## Seconds until the swing resolves (0 when idle).
func get_time_left() -> float:
	return maxf(_time_left, 0.0) if _swinging else 0.0


## Windup length of the current swing (0 when idle).
func get_duration() -> float:
	return _duration if _swinging else 0.0


## Story 046 Part C: how far the running swing's windup has gone, `1 - time_left / duration`, clamped to 0..1
## (0 when idle). The duration is the one [method begin_swing] stored AFTER every override and multiplier
## ([member duration_mult], [member duration_modifier], `duration_override`, [member cast_time_modifier]), so
## the value always reaches 1 exactly when the swing resolves. A 0 s windup (a relic floored it) reads 1.
## The boss's telegraph tiles fade in with it (CombatConfig.telegraph_*_alpha).
func get_progress() -> float:
	if not _swinging:
		return 0.0
	if _duration <= 0.0:
		return 1.0
	return clampf(1.0 - maxf(_time_left, 0.0) / _duration, 0.0, 1.0)


## DEV-ONLY (DemoArgs `--telegraph-k`): moves the running swing to progress [param k] (0..1) by setting its time
## left to `(1 - k) * duration`. No-op when idle. Never used by gameplay.
func debug_set_progress(k: float) -> void:
	if _swinging:
		_time_left = (1.0 - clampf(k, 0.0, 1.0)) * _duration


## Cells of the current swing (empty when idle).
func get_cells() -> Array[Vector2i]:
	return _cells.duplicate()


## Skill id of the current swing ("" when idle).
func get_skill_id() -> String:
	return _skill_id


## Story 020: card level of the current swing; while [signal swing_resolved] is being emitted it
## is still the level of the swing that just resolved. 1 by default.
func get_level() -> int:
	return _level


## Story 028: the featured bonus the current (or just resolved) swing carries; {} when none.
func get_featured_bonus() -> Dictionary:
	return _featured_bonus.duplicate(true)


## Skill v2 B1: the cast context of the current (or just resolved) swing; {} when none.
func get_cast_context() -> Dictionary:
	return _cast_context.duplicate(true)


## Skill v2 B1: returns the carried cast context and clears it (taken once, when the swing resolves).
func consume_cast_context() -> Dictionary:
	var ctx: Dictionary = _cast_context
	_cast_context = {}
	return ctx


## Story 028: returns the carried featured bonus and clears it, so it is applied at most once.
func consume_featured_bonus() -> Dictionary:
	var bonus: Dictionary = _featured_bonus
	_featured_bonus = {}
	return bonus


## True if the current swing targets the enemy half.
func targets_enemy() -> bool:
	return _target_is_enemy


func _start(cells: Array[Vector2i], skill_id: String, target_is_enemy: bool, duration: float, level: int = 1) -> void:
	_level = maxi(level, 1)
	_swinging = true
	_cells = cells.duplicate()
	_skill_id = skill_id
	_target_is_enemy = target_is_enemy
	_duration = duration
	_time_left = duration
	swing_started.emit(_cells.duplicate(), _skill_id, _duration)


func _drop_queue_with_signal() -> void:
	if not _has_queued:
		return
	var cells: Array[Vector2i] = _q_cells.duplicate()
	var skill_id: String = _q_skill_id
	clear_queue()
	queue_cleared.emit(cells, skill_id)


func _clear() -> void:
	_swinging = false
	_time_left = 0.0
	_duration = 0.0
	_cells = []
	_skill_id = ""

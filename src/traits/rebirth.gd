class_name RebirthTrait
extends BossTrait
## Trait `rebirth` (Story 039 Part B, Phuong Tro / ash_phoenix): the FIRST time the boss would reach 0 HP it does not
## die: CombatState holds it at 1 HP (the one death point asks TraitHost.on_boss_would_die -> [method on_boss_would_die]),
## it cannot be hit (BossTrait.untargetable) and takes no decisions for `revive_sec`, then it comes back with
## `revive_ratio` x max HP (or more when burning healed it meanwhile). UNLESS it carries >= 1 Han (frost) stack at that
## moment: then it dies for good, so the frost lane is rewarded. Only one revival per match.
## Notes: a Han stack that a lethal cut applies in the same cast lands AFTER its damage (CutEffects order), so it does not
## count for that blow; a burst that finishes a boss whose stacks it just cleared revives it.
## Params (match trait entry): `revive_ratio` (default 0.4), `revive_sec` (default 1.5).
## HUD: [method lives_left] (1 before the revival, 0 after: the "one life left" icon), [method is_reviving],
## [method revive_left] (rising timer).
## Implements: Story 039 (Part B).

## The boss fell to 0 HP and began to revive.
signal revival_started()
## The boss is back with [param hp] HP.
signal revived(hp: float)

const ID: String = "rebirth"
const DEFAULT_REVIVE_RATIO: float = 0.4
const DEFAULT_REVIVE_SEC: float = 1.5
## Float slack for timers counted down in fixed steps.
const _EPS: float = 0.000001

var _revive_ratio: float = DEFAULT_REVIVE_RATIO
var _revive_sec: float = DEFAULT_REVIVE_SEC
var _lives: int = 1
var _reviving: bool = false
var _revive_left: float = 0.0
var _restore_active: bool = false


func get_id() -> String:
	return ID


func setup(ctx: Dictionary, params: Dictionary, seed_value: int) -> void:
	super(ctx, params, seed_value)
	_revive_ratio = clampf(param_float("revive_ratio", DEFAULT_REVIVE_RATIO), 0.01, 1.0)
	_revive_sec = maxf(param_float("revive_sec", DEFAULT_REVIVE_SEC), 0.0)


func on_match_start() -> void:
	_lives = 1
	_reviving = false
	_revive_left = 0.0
	_restore_active = false


## True while the boss lies in its ashes: cannot be hit.
func untargetable() -> bool:
	return _reviving


## The hook. true = the death is taken over (first death without Han, or any further 0-HP blow while reviving).
func on_boss_would_die() -> bool:
	if _reviving:
		return true
	if _lives <= 0:
		return false
	var status: StatusEffects = get_context().get("status") as StatusEffects
	if status != null and status.frost_stacks(CombatState.Side.ENEMY) >= 1:
		return false
	_lives = 0
	_reviving = true
	_revive_left = _revive_sec
	var boss: BossController = get_context().get("boss") as BossController
	_restore_active = boss != null and boss.is_active()
	if boss != null:
		boss.set_active(false)
	revival_started.emit()
	if _revive_sec <= _EPS:
		_revive()
	return true


func on_tick(step: float) -> void:
	if not _reviving:
		return
	_revive_left -= step
	if _revive_left <= _EPS:
		_revive()


## Lives left: 1 before the revival, 0 after (and while reviving).
func lives_left() -> int:
	return _lives


## True while the boss is reviving.
func is_reviving() -> bool:
	return _reviving


## Seconds until the boss is back (0 when not reviving).
func revive_left() -> float:
	return maxf(_revive_left, 0.0) if _reviving else 0.0


## 0..1 progress of the revival (the rising timer); 0 when not reviving.
func get_revive_fraction() -> float:
	if not _reviving or _revive_sec <= 0.0:
		return 0.0
	return clampf(1.0 - _revive_left / _revive_sec, 0.0, 1.0)


func get_debug() -> Dictionary:
	return {"id": ID, "lives": _lives, "reviving": _reviving, "revive_left": revive_left()}


func teardown() -> void:
	if _reviving:
		var boss: BossController = get_context().get("boss") as BossController
		if boss != null and _restore_active:
			boss.set_active(true)
	_reviving = false
	super()


func _revive() -> void:
	_reviving = false
	_revive_left = 0.0
	var state: CombatState = get_context().get("state") as CombatState
	var boss: BossController = get_context().get("boss") as BossController
	if state != null:
		var target: float = state.enemy_max_hp * _revive_ratio
		if state.enemy_hp < target:
			state.heal_enemy(target - state.enemy_hp)
		revived.emit(state.enemy_hp)
	if boss != null and _restore_active:
		boss.set_active(true)

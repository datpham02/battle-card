class_name HunterMarkPassive
extends BasePassive
## Tho san - Dau san (Story 037, trigger changed by design/quick-specs/o-rot-thay-tuong-2026-10-31.md): when the
## boss steps onto one of the player's thorn cells, or the player lays thorns ON the boss's current cell or next to
## it (4-neighbour; user 2026-11-01 added "on the boss's cell"), the boss gets
## `fragile_stacks` Ran stack(s). After a mark it waits `icd_sec` SIMULATION seconds (the internal cooldown,
## advanced by [method tick]) before it can mark again. Params: fragile_stacks (int), icd_sec (float).
## Implements: Story 037.

## Fallbacks only; the real numbers are in characters.json.
const DEFAULT_FRAGILE_STACKS: int = 1
const DEFAULT_ICD_SEC: float = 0.0

var _clock: float = 0.0
var _ready_at: float = 0.0
var _marks: int = 0


func get_id() -> String:
	return "hunter_mark"


func tick(dt: float) -> void:
	if dt > 0.0:
		_clock += dt


func on_boss_thorn_step(_cell: Vector2i) -> void:
	_try_mark()


func on_player_zone_formed(kind: String, cells: Array[Vector2i]) -> void:
	if kind != StatusEffects.KIND_THORNS:
		return
	var state: CombatState = _ctx.get("state") as CombatState
	if state == null:
		return
	var boss: Vector2i = state.enemy_cell
	for cell: Vector2i in cells:
		# 0 = laid on the boss's own cell, 1 = beside it; both mark (same internal cooldown).
		if absi(cell.x - boss.x) + absi(cell.y - boss.y) <= 1:
			_try_mark()
			return


## How many times the boss was marked this match (tests / HUD).
func marks_given() -> int:
	return _marks


# Gives the Ran stack(s) unless the internal cooldown is still running.
func _try_mark() -> void:
	if _clock < _ready_at:
		return
	var status: StatusEffects = _ctx.get("status") as StatusEffects
	var stacks: int = maxi(param_int("fragile_stacks", DEFAULT_FRAGILE_STACKS), 0)
	if status == null or stacks <= 0:
		return
	status.apply_fragile(CombatState.Side.ENEMY, stacks)
	_marks += 1
	_ready_at = _clock + maxf(param_float("icd_sec", DEFAULT_ICD_SEC), 0.0)

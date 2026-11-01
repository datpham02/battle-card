class_name PatternController
extends RefCounted
## The pattern brain's skill lifecycle for ONE enemy (spec 3.6, pack 06 section 3): IDLE -> CHOOSE -> WINDUP ->
## WARNING (cells snapshotted when the warning starts) -> RESOLVE -> optional FOLLOWUP (a NEW warning) -> RECOVERY,
## plus phases (HP thresholds of any number of phases, A4) with a TRANSITION: warnings cleared at once, the enemy
## stands still and is invulnerable for transition.sec (D14, 1.5 s default), then the phase's on_enter skills run.
## Enemy HP is floored at the next threshold (CombatState.enemy_hp_floor) so one hit never skips a phase.
## Delivery is animation only (A1): damage, status and zones land on the snapshotted cells minus the cells locked at
## resolve time (StatusEffects.unlocked_cells, the same gate CutEffects uses), never on a path.
## Floor tempo ([member tempo_mult], floor_scaling.step_mult) scales windup, cooldown and recovery, NEVER warning_sec.
## Movement between skills stays BossBrain's (BossController); [method is_busy] roots the enemy during a skill.
## Implements: design/quick-specs/phase2-misty-forest-2026-11-01.md 3.5-3.8, section 4 (P2.2).

## A warning started: [param cells] are red now, [param queued] the second lane shown as the queued stripe.
signal warning_started(skill_id: String, cells: Array[Vector2i], queued: Array[Vector2i], warning_sec: float)
## The red went away: reason "resolved", "interrupted", "phase", "aborted".
signal warning_cleared(skill_id: String, reason: String)
## A strike resolved: [param result] {skill_id, cells, hit, damage, status, zone_cells, followup}.
signal skill_resolved(skill_id: String, result: Dictionary)
## A phase transition started (index of the NEW phase).
signal phase_started(index: int, phase_id: String)
## Markers (root anchors) changed (placed, broken, expired).
signal markers_changed

enum Stage { IDLE, WINDUP, WARNING, RECOVERY, TRANSITION }

const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const _EPS: float = 0.000001

## Floor tempo multiplier (floor_scaling.step_mult x region step_mult) on windup / cooldown / recovery.
var tempo_mult: float = 1.0
## Seconds between choices while idle (match boss_think_interval_sec).
var think_interval_sec: float = 0.3
## The player's board step cooldown (CombatConfig.step_cooldown_for x passives); Slow is folded in by the controller.
var player_step_cd: float = 0.45
## Callable() -> float: the player's step cooldown left now (UnitMover.get_cooldown_remaining); invalid = 0.
var player_step_left_fn: Callable = Callable()
## Callable() -> Array: cells of OTHER warnings showing now (traits); they count for F2 and are not safe (F1).
var external_red_fn: Callable = Callable()

var _state: CombatState
var _grid: BoardGrid
var _config: EnemySkillsConfig
var _status: StatusEffects
var _enemy: Dictionary
var _brain: PatternBrain
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _stage: int = Stage.IDLE
var _stage_left: float = 0.0
var _think_left: float = 0.0
var _phase: int = 0
var _skill: Dictionary = {}
var _plan: Dictionary = {}
var _warn_cells: Array[Vector2i] = []
var _queued_cells: Array[Vector2i] = []
var _warn_total: float = 0.0
var _is_followup: bool = false
var _first_cells: Array[Vector2i] = []
var _cooldowns: Dictionary = {}
var _used_once: Dictionary = {}
var _since_warning: float = 1000.0
var _gap_needed: float = 0.0
var _still_sec: float = 0.0
var _last_player_cell: Vector2i = BoardGrid.NO_CELL
var _last_skill: String = ""
var _phase_casts: int = 0
var _forced_queue: Array[String] = []
var _markers: Array[Dictionary] = []
var _guard_markers: bool = false
## Every resolved strike / event, in order, for tests and the decision log: {t, skill, cells, hit, phase}.
var event_log: Array[Dictionary] = []
var _time: float = 0.0


## [param enemy_id] must exist in [param config] (else the controller stays idle forever, with a warning).
func _init(state: CombatState, grid: BoardGrid, config: EnemySkillsConfig, enemy_id: String, status: StatusEffects, seed_value: int = -1) -> void:
	_state = state
	_grid = grid
	_config = config
	_status = status
	_enemy = config.get_enemy(enemy_id)
	if _enemy.is_empty():
		push_warning("PatternController: unknown enemy '%s'" % enemy_id)
	# P2.2b (D13 / ADR-0001 A7): the enemy's footprint is its data; CombatState validates every move / spawn against it.
	if not _enemy.is_empty():
		var footprint: Array[Vector2i] = []
		footprint.assign(_enemy.get("footprint", [Vector2i.ZERO]) as Array)
		_state.set_enemy_footprint(footprint)
	_brain = PatternBrain.new(_enemy.get("ai", config.ai) as Dictionary, seed_value)
	if seed_value >= 0:
		_rng.seed = seed_value + 101
	else:
		_rng.randomize()
	_apply_hp_floor()


## The enemy definition in use.
func get_enemy() -> Dictionary:
	return _enemy


## Current stage (a [enum Stage] value).
func get_stage() -> int:
	return _stage


## Index of the current phase (0-based).
func get_phase_index() -> int:
	return _phase


## The skill in progress ({} when idle).
func get_current_skill() -> Dictionary:
	return _skill


## The choice maker (debug breakdown).
func get_brain() -> PatternBrain:
	return _brain


## True while the enemy must stand still: windup, warning, recovery or a phase transition.
func is_busy() -> bool:
	return _stage != Stage.IDLE


## Red cells to paint now: the snapshot minus cells that became locked (F7, rule 4 of the one-zone spec).
func telegraph_cells() -> Array[Vector2i]:
	if _stage != Stage.WARNING:
		return [] as Array[Vector2i]
	return _status.unlocked_cells(_warn_cells) if _status != null else _warn_cells.duplicate()


## The queued second lane (sparser stripe) while the first lane warns.
func queued_cells() -> Array[Vector2i]:
	if _stage != Stage.WARNING:
		return [] as Array[Vector2i]
	return _status.unlocked_cells(_queued_cells) if _status != null else _queued_cells.duplicate()


## Warning progress 0..1 (the painter's k).
func warning_progress() -> float:
	if _stage != Stage.WARNING or _warn_total <= 0.0:
		return 0.0
	return clampf(1.0 - _stage_left / _warn_total, 0.0, 1.0)


## Marker cells alive (enemy half), oldest first.
func marker_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for m: Dictionary in _markers:
		out.append(m["cell"] as Vector2i)
	return out


## Cooldown left of [param skill_id].
func cooldown_left(skill_id: String) -> float:
	return float(_cooldowns.get(skill_id, 0.0))


## D9 interrupt: the player's cast HIT the enemy. An interruptible skill in WINDUP or WARNING is cancelled (red off at
## once) and goes on cooldown x ai.cancel_cooldown_ratio. Returns true when something was cancelled.
func on_enemy_hit() -> bool:
	if _skill.is_empty() or not (_stage == Stage.WINDUP or _stage == Stage.WARNING):
		return false
	if not bool(_skill["interruptible"]):
		return false
	var id: String = str(_skill["id"])
	_cooldowns[id] = float(_skill["cooldown_sec"]) * tempo_mult * float(_ai()["cancel_cooldown_ratio"])
	_end_skill("interrupted", false)
	return true


## A player cast landed on [param cells] of the enemy half: markers under it break when the cast has at least their
## break_min_cells cells.
func on_player_cast(cells: Array[Vector2i]) -> void:
	var broke: bool = false
	for i: int in range(_markers.size() - 1, -1, -1):
		var m: Dictionary = _markers[i]
		if cells.has(m["cell"]) and cells.size() >= int(m["break_min_cells"]):
			_markers.remove_at(i)
			broke = true
	if broke:
		markers_changed.emit()


## Advances every clock by [param delta] (scaled simulation time: Focus slows / stops it with the match).
func tick(delta: float) -> void:
	if _enemy.is_empty() or delta <= 0.0 or _state.is_enemy_dead() or _state.is_player_dead():
		return
	_time += delta
	_since_warning += delta
	for id: String in _cooldowns.keys():
		_cooldowns[id] = maxf(float(_cooldowns[id]) - delta, 0.0)
	if _state.player_cell == _last_player_cell:
		_still_sec += delta
	else:
		_still_sec = 0.0
		_last_player_cell = _state.player_cell
	_tick_markers(delta)
	if _stage != Stage.TRANSITION and _phase + 1 < _phases().size() \
			and _state.enemy_hp <= float(_phases()[_phase + 1]["enter_hp_ratio"]) * _state.enemy_max_hp + _EPS:
		_begin_transition()
		return
	match _stage:
		Stage.TRANSITION:
			_state.enemy_invulnerable_left = maxf(_state.enemy_invulnerable_left - delta, 0.0)
			_stage_left -= delta
			if _stage_left <= _EPS:
				_state.enemy_invulnerable_left = 0.0
				_stage = Stage.IDLE
				_apply_hp_floor()
				_forced_queue.assign(((_phases()[_phase] as Dictionary)["transition"] as Dictionary)["on_enter"] as Array)
				_think_left = 0.0
		Stage.WINDUP:
			_stage_left -= delta
			if _stage_left <= _EPS:
				_after_windup()
		Stage.WARNING:
			_stage_left -= delta
			if _stage_left <= _EPS:
				_resolve_warning()
		Stage.RECOVERY:
			_stage_left -= delta
			if _stage_left <= _EPS:
				_stage = Stage.IDLE
				_think_left = 0.0
		Stage.IDLE:
			_think_left -= delta
			if _think_left <= _EPS:
				_think_left = think_interval_sec
				_try_choose()


# --- choice ---------------------------------------------------------------------------------------------------------

func _try_choose() -> void:
	if not FairnessCheck.gap_ok(_since_warning, maxf(_gap_needed, float(_config.fairness["min_gap_between_warnings_sec"]))):
		return
	var phase: Dictionary = _phases()[_phase]
	var candidates: Array[Dictionary] = []
	var ids: Array[String] = []
	ids.assign(phase["skills"] as Array)
	var forced_queue_skill: String = _forced_queue[0] if not _forced_queue.is_empty() else ""
	if not forced_queue_skill.is_empty():
		ids.assign([forced_queue_skill])
	for id: String in ids:
		var skill: Dictionary = _config.skill_for_phase(id, phase)
		if skill.is_empty() or (forced_queue_skill.is_empty() and cooldown_left(id) > _EPS) or not _conditions_ok(skill, phase):
			continue
		var plans: Array[Dictionary] = _valid_plans(skill, float(skill["warning_sec"]))
		if not plans.is_empty():
			candidates.append({"skill": skill, "plans": plans})
	if not forced_queue_skill.is_empty():
		_forced_queue.pop_front()
	var every: Dictionary = phase["every_nth"] as Dictionary
	var forced: String = ""
	if not every.is_empty() and (_phase_casts + 1) % int(every["n"]) == 0:
		forced = str(every["skill"])
	var choice: Dictionary = _brain.choose(candidates, {
		"player_cell": _state.player_cell, "player_still_sec": _still_sec, "last_skill": _last_skill,
		"mechanic": str(phase["mechanic"]), "forced_skill": forced,
	})
	if choice.is_empty():
		return
	_skill = choice["skill"] as Dictionary
	_plan = choice["plan"] as Dictionary
	_stage = Stage.WINDUP
	_stage_left = float(_skill["windup_sec"]) * tempo_mult
	if _stage_left <= _EPS:
		_after_windup()


func _conditions_ok(skill: Dictionary, phase: Dictionary) -> bool:
	var c: Dictionary = skill["conditions"] as Dictionary
	var ratio: float = _state.enemy_hp / maxf(_state.enemy_max_hp, _EPS)
	if c.has("phases") and not (c["phases"] as Array).has(str(phase["id"])):
		return false
	if c.has("hp_below") and ratio > float(c["hp_below"]) + _EPS:
		return false
	if c.has("hp_above") and ratio < float(c["hp_above"]) - _EPS:
		return false
	if bool(c.get("once", false)) and _used_once.has(str(skill["id"])):
		return false
	if _markers.size() < int(c.get("requires_anchor", 0)):
		return false
	if _still_sec + _EPS < float(c.get("player_still_sec", 0.0)):
		return false
	return true


# Plans of [param skill] that pass F1 (4.1) and F2 (red ceiling). Self / marker skills only need a plan.
func _valid_plans(skill: Dictionary, warning_sec: float) -> Array[Dictionary]:
	var all: Array[Dictionary] = PatternPlanner.plans(skill, _plan_ctx())
	if str(skill["kind"]) != "attack":
		return all
	var out: Array[Dictionary] = []
	for plan: Dictionary in all:
		if _fair(plan["cells"] as Array, warning_sec):
			out.append(plan)
	return out


func _fair(cells: Array, warning_sec: float, extra_red: Array = []) -> bool:
	var env: Dictionary = fairness_env()
	var other: Array = (env["unsafe"] as Array).duplicate()
	other.append_array(extra_red)
	if not FairnessCheck.red_ok(cells, other, FairnessCheck.usable_floor(_grid, env), float(_config.fairness["max_red_ratio"])):
		return false
	return FairnessCheck.can_hero_respond(_grid, _state.player_cell, cells, warning_sec, _player_lock_left(),
		_player_step_cd(), float(_config.fairness["reaction_margin_sec"]), env)


## The env FairnessCheck reads (holes block, cracking / thorns / burning are not safe ends, other warnings unsafe).
func fairness_env() -> Dictionary:
	var status: StatusEffects = _status
	var unsafe: Array = []
	if external_red_fn.is_valid():
		unsafe = (external_red_fn.call() as Array).duplicate()
	if status == null:
		return {"unsafe": unsafe}
	return {
		"unsafe": unsafe,
		"blocked_fn": func(c: Vector2i) -> bool: return status.is_hole(P, c),
		"lock_fn": func(c: Vector2i) -> bool: return status.is_cracking(P, c),
		"hazard_fn": func(c: Vector2i) -> bool: return status.is_burning(c) or not status.thorns_at(P, c).is_empty(),
	}


func _player_step_cd() -> float:
	return player_step_cd * (_status.step_mult(P) if _status != null else 1.0)


func _player_lock_left() -> float:
	var step_left: float = float(player_step_left_fn.call()) if player_step_left_fn.is_valid() else 0.0
	if _status == null:
		return step_left
	return FairnessCheck.lock_left(step_left, _status.get_pin_left(P), _status.get_root_left(P))


func _plan_ctx() -> Dictionary:
	var status: StatusEffects = _status
	return {
		"grid": _grid, "player_cell": _state.player_cell, "enemy_cell": _state.enemy_cell, "markers": marker_cells(),
		"enemy_cells": _state.enemy_footprint_cells(),
		"cell_ok_fn": (func(c: Vector2i) -> bool: return not status.is_locked(c)) if status != null else Callable(),
	}


# --- lifecycle --------------------------------------------------------------------------------------------------------

func _after_windup() -> void:
	var kind: String = str(_skill["kind"])
	if kind != "attack":
		_resolve_self_or_marker()
		_finish_skill()
		return
	# Snapshot at warning start (spec 3.6): re-plan for where the player stands NOW; no fair plan = abort.
	var plans: Array[Dictionary] = _valid_plans(_skill, float(_skill["warning_sec"]))
	var followup: Dictionary = _skill["followup"] as Dictionary
	var queued: Array[Vector2i] = []
	var chosen: Dictionary = {}
	if not plans.is_empty():
		chosen = _brain.pick_plan(plans, _state.player_cell)
		if not followup.is_empty() and bool(followup["show_with_first"]):
			var lanes: Array[Dictionary] = _fair_followups(followup, chosen["cells"] as Array[Vector2i], float(_skill["warning_sec"]), chosen["cells"] as Array)
			if not lanes.is_empty():
				queued = lanes[0]["cells"] as Array[Vector2i]
	if chosen.is_empty() or not FairnessCheck.gap_ok(_since_warning, float(_config.fairness["min_gap_between_warnings_sec"])):
		_cooldowns[str(_skill["id"])] = float(_skill["cooldown_sec"]) * tempo_mult * float(_ai()["cancel_cooldown_ratio"])
		_end_skill("aborted", false)
		return
	_plan = chosen
	_is_followup = false
	_start_warning(chosen["cells"] as Array[Vector2i], queued, float(_skill["warning_sec"]))


func _start_warning(cells: Array[Vector2i], queued: Array[Vector2i], warning_sec: float) -> void:
	_warn_cells = cells.duplicate()
	_queued_cells = queued.duplicate()
	_warn_total = warning_sec
	_stage_left = warning_sec
	_stage = Stage.WARNING
	_since_warning = 0.0
	warning_started.emit(str(_skill["id"]), _warn_cells.duplicate(), _queued_cells.duplicate(), warning_sec)


func _resolve_warning() -> void:
	var effects: Dictionary = (_skill["followup"] as Dictionary)["effects"] if _is_followup else _skill["effects"]
	var result: Dictionary = _resolve_cells(_warn_cells, effects as Dictionary)
	warning_cleared.emit(str(_skill["id"]), "resolved")
	var followup: Dictionary = _skill["followup"] as Dictionary
	if _is_followup or followup.is_empty() or marker_cells().size() < int(followup["requires_anchor"]):
		_finish_skill()
		return
	# Followup (3.5): cells chosen NOW and checked against the player NOW; failing = dropped, never moved silently.
	_first_cells = _warn_cells.duplicate()
	var next: Array[Vector2i] = []
	if bool(followup["show_with_first"]) and not _queued_cells.is_empty():
		if _fair(_queued_cells, float(followup["warning_sec"])):
			next = _queued_cells.duplicate()
	else:
		var lanes: Array[Dictionary] = _fair_followups(followup, _first_cells, float(followup["warning_sec"]), [])
		if not lanes.is_empty():
			next = _brain.pick_plan(lanes, _state.player_cell)["cells"] as Array[Vector2i]
	result["followup"] = not next.is_empty()
	if next.is_empty():
		_finish_skill()
		return
	_is_followup = true
	_start_warning(next, [] as Array[Vector2i], float(followup["warning_sec"]))


func _fair_followups(followup: Dictionary, first: Array[Vector2i], warning_sec: float, extra_red: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lane: Dictionary in PatternPlanner.followup_candidates(followup, first, _state.player_cell, _plan_ctx()):
		if _fair(lane["cells"] as Array, warning_sec, extra_red):
			out.append(lane)
	return out


# Applies [param effects] on [param cells] (A1: the cells only). Returns the result logged and emitted.
func _resolve_cells(cells: Array[Vector2i], effects: Dictionary) -> Dictionary:
	var open: Array[Vector2i] = _status.unlocked_cells(cells) if _status != null else cells.duplicate()
	var hit: bool = open.has(_state.player_cell)
	var result: Dictionary = {"skill_id": str(_skill["id"]), "cells": open, "hit": hit, "damage": 0.0, "status": "", "zone_cells": [] as Array[Vector2i], "followup": false}
	var damage: float = float(effects.get("damage", 0.0))
	if hit and damage > 0.0:
		var before: float = _state.player_hp
		_state.damage_player(damage)
		result["damage"] = before - _state.player_hp
	if hit and _status != null and typeof(effects.get("status")) == TYPE_DICTIONARY:
		var st: Dictionary = effects["status"] as Dictionary
		if not bool(st["first_cell_only"]) or (not open.is_empty() and open[0] == _state.player_cell and cells[0] == open[0]):
			result["status"] = _apply_status(st)
	if _status != null and typeof(effects.get("zone")) == TYPE_DICTIONARY:
		result["zone_cells"] = _apply_zone(effects["zone"] as Dictionary, open)
	_record(result)
	skill_resolved.emit(str(_skill["id"]), result)
	return result


func _apply_status(st: Dictionary) -> String:
	var id: String = str(st["id"])
	match id:
		"root", "pin":
			# F4: no lock on a locked player, nor inside the grace after a lock.
			# The grace is read from StatusEffects' own clock: a lock that began and ended between two controller ticks
			# (a 0.05 s Frozen) still opens the window.
			var grace_left: float = maxf(float(_config.fairness["cc_grace_sec"]) - _status.since_lock_ended(P), 0.0)
			if not FairnessCheck.cc_allowed(_status.lock_left(P), grace_left):
				return ""
			if id == "root":
				return id if _status.root(P, float(st["sec"])) else ""
			_status.pin(P, float(st["sec"]))
		"slow":
			_status.slow(P, float(st["sec"]), float(st["step_mult"]))
		"fragile":
			_status.apply_fragile(P, int(st["stacks"]))
		"frost":
			_status.apply_frost(P, int(st["stacks"]))
	return id


func _apply_zone(zone: Dictionary, cells: Array[Vector2i]) -> Array[Vector2i]:
	var id: String = str(zone.get("id", ""))
	var zone_cells: Array[Vector2i] = cells.duplicate()
	var env: Dictionary = fairness_env()
	# F3: the zone never takes the player's last adjacent steppable cell.
	while not zone_cells.is_empty() and not FairnessCheck.zone_leaves_exit(_grid, _state.player_cell, zone_cells, env):
		var dropped: bool = false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if zone_cells.has(_state.player_cell + d):
				zone_cells.erase(_state.player_cell + d)
				dropped = true
				break
		if not dropped:
			break
	if id == "thorns":
		var numbers: Dictionary = {"thorn_sec": 3.0, "thorn_damage": 6.0, "thorn_fragile_stacks": 1}
		return ZoneRules.cast_thorns(_status, P, zone_cells, float(zone.get("sec", numbers["thorn_sec"])),
			float(zone.get("damage", numbers["thorn_damage"])), int(zone.get("fragile_stacks", numbers["thorn_fragile_stacks"])))
	if id == "drop":
		var warn: float = float(zone.get("warn_sec", 0.8))
		var margin: float = float(_config.fairness["reaction_margin_sec"])
		var step_left: float = float(player_step_left_fn.call()) if player_step_left_fn.is_valid() else 0.0
		var ok: bool = ZoneRules.unit_cell_droppable(step_left, warn, margin, _status.is_pinned(P), _status.is_rooted(P))
		return ZoneRules.cast_drop(_state, _grid, _status, P, zone_cells, warn, float(zone.get("hole_sec", 1.2)), ok)
	return [] as Array[Vector2i]


func _resolve_self_or_marker() -> void:
	var effects: Dictionary = _skill["effects"] as Dictionary
	var result: Dictionary = {"skill_id": str(_skill["id"]), "cells": [] as Array[Vector2i], "hit": false, "damage": 0.0, "status": "", "zone_cells": [] as Array[Vector2i], "followup": false}
	if str(_skill["kind"]) == "marker":
		var plans: Array[Dictionary] = PatternPlanner.plans(_skill, _plan_ctx())
		var marker: Dictionary = effects.get("marker", {"life_sec": float(_config.defaults["marker_life_sec"]), "break_min_cells": int(_config.defaults["marker_break_min_cells"])}) as Dictionary
		for i: int in int((_skill["pattern"] as Dictionary)["count"]):
			if plans.is_empty():
				break
			var plan: Dictionary = plans.pop_at(_rng.randi_range(0, plans.size() - 1))
			var cell: Vector2i = (plan["cells"] as Array[Vector2i])[0]
			_markers.append({"cell": cell, "left": float(marker["life_sec"]), "break_min_cells": int(marker["break_min_cells"])})
			(result["cells"] as Array[Vector2i]).append(cell)
		markers_changed.emit()
	if typeof(effects.get("guard")) == TYPE_DICTIONARY and _status != null:
		var g: Dictionary = effects["guard"] as Dictionary
		if not bool(g["while_markers"]) or not _markers.is_empty():
			_status.guard(E, float(g["amount"]), float(g["sec"]))
			_guard_markers = bool(g["while_markers"])
			result["status"] = "guard"
	_record(result)
	skill_resolved.emit(str(_skill["id"]), result)


func _finish_skill() -> void:
	var id: String = str(_skill["id"])
	_cooldowns[id] = float(_skill["cooldown_sec"]) * tempo_mult
	if bool((_skill["conditions"] as Dictionary).get("once", false)):
		_used_once[id] = true
	_last_skill = id
	_phase_casts += 1
	_gap_needed = FairnessCheck.gap_needed(float(_skill["recovery_sec"]), float(_config.fairness["min_gap_between_warnings_sec"]),
		_player_step_cd(), float(_config.fairness["reaction_margin_sec"]), float(_config.fairness["heavy_recovery_sec"]))
	var recovery: float = float(_skill["recovery_sec"]) * tempo_mult
	_skill = {}
	_warn_cells.clear()
	_queued_cells.clear()
	_is_followup = false
	_stage = Stage.RECOVERY if recovery > _EPS else Stage.IDLE
	_stage_left = recovery
	_think_left = 0.0


func _end_skill(reason: String, _resolved: bool) -> void:
	var id: String = str(_skill.get("id", ""))
	var was_warning: bool = _stage == Stage.WARNING
	_skill = {}
	_warn_cells.clear()
	_queued_cells.clear()
	_is_followup = false
	_stage = Stage.IDLE
	_think_left = think_interval_sec
	if was_warning or reason == "aborted":
		warning_cleared.emit(id, reason)
	event_log.append({"t": _time, "skill": id, "event": reason, "phase": _phase})


func _begin_transition() -> void:
	if not _skill.is_empty():
		_end_skill("phase", false)
	_phase += 1
	_phase_casts = 0
	_forced_queue.clear()
	var sec: float = float(((_phases()[_phase] as Dictionary)["transition"] as Dictionary)["sec"])
	_stage = Stage.TRANSITION
	_stage_left = sec
	_state.enemy_invulnerable_left = sec
	event_log.append({"t": _time, "skill": "", "event": "phase", "phase": _phase})
	phase_started.emit(_phase, str(_phases()[_phase]["id"]))
	if sec <= _EPS:
		_state.enemy_invulnerable_left = 0.0
		_stage = Stage.IDLE
		_apply_hp_floor()
		_forced_queue.assign(((_phases()[_phase] as Dictionary)["transition"] as Dictionary)["on_enter"] as Array)


# Floors enemy HP at the next phase's threshold (one hit never skips a phase), 0 in the last phase.
func _apply_hp_floor() -> void:
	if _enemy.is_empty():
		return
	if _phase + 1 < _phases().size():
		_state.enemy_hp_floor = float(_phases()[_phase + 1]["enter_hp_ratio"]) * _state.enemy_max_hp
	else:
		_state.enemy_hp_floor = 0.0


func _tick_markers(delta: float) -> void:
	var changed: bool = false
	for i: int in range(_markers.size() - 1, -1, -1):
		_markers[i]["left"] = float(_markers[i]["left"]) - delta
		if float(_markers[i]["left"]) <= _EPS:
			_markers.remove_at(i)
			changed = true
	if _guard_markers and _markers.is_empty() and _status != null:
		_status.clear_guard(E)
		_guard_markers = false
	if changed:
		markers_changed.emit()


func _record(result: Dictionary) -> void:
	event_log.append({"t": _time, "skill": str(result["skill_id"]), "event": "resolve", "cells": result["cells"], "hit": result["hit"],
		"damage": result["damage"], "phase": _phase, "followup_strike": _is_followup})


func _phases() -> Array:
	return _enemy["phases"] as Array


func _ai() -> Dictionary:
	return _enemy.get("ai", _config.ai) as Dictionary

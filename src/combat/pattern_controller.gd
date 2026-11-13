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
## P2.3: the player broke a marker with a stun (Sentinel's root anchor): the enemy stands still for [param sec], the
## skill in progress (and its followup) cancelled.
signal stunned(sec: float)
## Entered [param stage] (a [enum Stage] value). [param skill_id] is the skill in progress, or the skill that just
## ended when the new stage is RECOVERY / IDLE after it. Audio listens for WINDUP and RECOVERY (docs/skill-v2/10).
signal stage_changed(stage: int, skill_id: String)

## P2.3 adds FOLLOWUP_WAIT (a followup's `delay_sec` between the first strike and the followup warning) and STUNNED.
enum Stage { IDLE, WINDUP, WARNING, RECOVERY, TRANSITION, FOLLOWUP_WAIT, STUNNED }

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
## Cast rhythm spec 2026-11-05 (Knight parry): the hero's ParryGuard. A strike that hits the hero while it is open is
## parried in [method _resolve_cells] (0 damage, no status, reflect + pin through the guard). Null = no parry.
var player_guard: ParryGuard = null
## Monster Skill Phase 0 (design §5.2): the match's TileHazards for the mire / sand / fall zones; null = those zones
## are skipped with a warning (the skill still strikes).
var hazards: TileHazards = null
## Phase 0: Callable(cell) -> bool, the PLAYER mover's blocked test (pillars, holes, sand) a push / pull never enters.
var player_blocked_fn: Callable = Callable()
## Phase 0: the reaction numbers (CombatConfig.reactions(); {} = CutEffects' defaults) for the R3 slam of a push / pull
## stopped short, through the same StatusEffects.reaction_allowed gate as the cards.
var reactions: Dictionary = {}
## Phase 0 (design §9.2): seconds between two pushes / pulls of the player by enemy skills (0 = none).
var push_icd_sec: float = 0.0
## Phase 0 (multi-enemy, tier B): Callable() -> Dictionary {alive: int, died_within_sec: float, min_hp_ratio: float}
## describing the OTHER enemies of the encounter. Invalid (today's single-enemy engine) = no allies: alive 0,
## died_within_sec INF, min_hp_ratio 1.0. Only the ally_* conditions and the allies_alive weight read it.
var allies_fn: Callable = Callable()
## Multi-enemy Phase 3 (D1): the match's shared ThreatBoard; null = none (the pre-Phase-3 controller). With a shared
## board: a skill starts only with an attack token (released when the skill ends), and the F5 warning gap counts every
## unit's warnings.
var threat_board: ThreatBoard = null
## Multi-enemy Phase 3: the unit KEY this controller drives (1 = unit 0, Side.ENEMY). Every own-unit read / write goes
## through it, so two controllers never touch each other's unit.
var _key: int = CombatState.Side.ENEMY

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
# 2026-11-03 (effects.haste): seconds left and the cooldown multiplier while it lasts.
var _haste_left: float = 0.0
var _haste_mult: float = 1.0
## P2.3: seconds since the player last placed a block covering the enemy (on_player_aim); the Rootling's creep
## condition `player_aimed_within_sec` reads it.
var _since_aim: float = 1000.0
# Phase 0: seconds left of the enemy's evade (untargetable) and shroud (hit forecast hidden) self effects.
var _evade_left: float = 0.0
var _shroud_left: float = 0.0
# Phase 0: a heal over time in progress (effects.heal with sec > 0): seconds left and HP per second.
var _heal_left: float = 0.0
var _heal_per_sec: float = 0.0
# Phase 0: player steps since each skill last finished (conditions.player_steps_since; the step_reactor rule as data).
var _steps_since: Dictionary = {}
var _since_push: float = 1000.0
# Phase 0 (burrow / rebirth): false = every clock stands still and nothing is chosen (set_active).
var _active: bool = true
## Every resolved strike / event, in order, for tests and the decision log: {t, skill, cells, hit, phase}.
var event_log: Array[Dictionary] = []
var _time: float = 0.0


## [param enemy_id] must exist in [param config] (else the controller stays idle forever, with a warning).
func _init(state: CombatState, grid: BoardGrid, config: EnemySkillsConfig, enemy_id: String, status: StatusEffects, seed_value: int = -1,
		key: int = CombatState.Side.ENEMY) -> void:
	_key = key
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
		_state.set_unit_footprint(CombatState.unit_index_of(_key), footprint)
	_brain = PatternBrain.new(_enemy.get("ai", config.ai) as Dictionary, seed_value)
	if seed_value >= 0:
		_rng.seed = seed_value + 101
	else:
		_rng.randomize()
	_apply_hp_floor()


## Multi-enemy Phase 3: the unit key this controller drives.
func get_key() -> int:
	return _key


# Phase 3: the EnemyUnit this controller drives.
func _unit() -> EnemyUnit:
	return _state.get_unit(CombatState.unit_index_of(_key))


# Phase 3 (D1 / F5): seconds since the last warning, of this unit or (with a shared board) of any unit.
func _since_any_warning() -> float:
	if threat_board != null and threat_board.shared:
		return minf(_since_warning, threat_board.since_warning())
	return _since_warning


## The enemy definition in use.
func get_enemy() -> Dictionary:
	return _enemy


## Current stage (a [enum Stage] value).
func get_stage() -> int:
	return _stage


## Sets the stage and emits [signal stage_changed] when it actually changes. [param skill_id] overrides the skill
## read off the controller (needed once [member _skill] was already cleared, e.g. entering RECOVERY).
func _set_stage(next: int, skill_id: String = "") -> void:
	if next == _stage:
		return
	_stage = next
	# Phase 3 (D1): the attack token is held from the windup to the end of the warning / followup
	if threat_board != null and next != Stage.WINDUP and next != Stage.WARNING and next != Stage.FOLLOWUP_WAIT:
		threat_board.release(_key)
	var sid: String = skill_id if not skill_id.is_empty() else (str(_skill.get("id", "")) if not _skill.is_empty() else "")
	stage_changed.emit(next, sid)


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


## P2.3: every marker alive, oldest first: {cell, kind ("anchor" / "wreath"), left (seconds)} (copies, for drawing).
func markers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in _markers:
		out.append({"cell": m["cell"], "kind": str(m.get("kind", "anchor")), "left": float(m["left"])})
	return out


## P2.3: the cell a moving self skill (Rootling creep, effects.move) will step to, shown while it winds up (an ivory
## outline, never red); NO_CELL otherwise.
func move_target_cell() -> Vector2i:
	if _stage == Stage.WINDUP and not _skill.is_empty() and _plan.has("move_to"):
		return _plan["move_to"] as Vector2i
	return BoardGrid.NO_CELL


## P2.3: the player placed a block on [param cells] of the enemy half (CombatView.confirm_placement: the first piece
## of a cast or a joined one). When it covers the enemy, conditions.player_aimed_within_sec starts counting from now.
func on_player_aim(cells: Array[Vector2i]) -> void:
	if _state.unit_in(_key, cells):
		_since_aim = 0.0


## P2.4 (spec 3.6, D9): true while a skill that CANNOT be interrupted winds up or warns; FloorLayer frames the enemy's
## cells in ivory then (the "hitting it will not break this" tell).
## 2026-11-04: true while an interruptible skill with a designed interrupt window (interrupt_stun_sec > 0: the Wolf
## Alpha's howl) winds up - the floor blinks its ivory frame ("hit it now"), unlike the solid frame of
## [method uninterruptible_tell].
func interrupt_tell() -> bool:
	return not _skill.is_empty() and _stage == Stage.WINDUP and bool(_skill["interruptible"]) 		and float(_skill.get("interrupt_stun_sec", 0.0)) > _EPS


func uninterruptible_tell() -> bool:
	return not _skill.is_empty() and (_stage == Stage.WINDUP or _stage == Stage.WARNING) and not bool(_skill["interruptible"])


## Cast rhythm spec 2026-11-05: true while an ATTACK skill winds up or warns (a parry card may be cast now).
func is_threatening() -> bool:
	return not _skill.is_empty() and (_stage == Stage.WINDUP or _stage == Stage.WARNING) and str(_skill.get("kind", "")) == "attack"


## Cast rhythm spec 2026-11-05: match seconds until the current attack strikes (WARNING: what is left of it; WINDUP:
## the rest of the windup plus its warning_sec); INF when no attack is coming. The balance bot times its parry with it.
func strike_time_left() -> float:
	if not is_threatening():
		return INF
	var warning_sec: float = float((_skill["followup"] as Dictionary).get("warning_sec", _skill["warning_sec"])) if _is_followup else float(_skill["warning_sec"])
	return _stage_left if _stage == Stage.WARNING else _stage_left + warning_sec


## Cast rhythm spec 2026-11-05: the cells the current attack will strike when known (the warning's red), else the
## player's cell during a windup (the plan is made for where the hero stands); [] when no attack is coming.
func threatened_cells() -> Array[Vector2i]:
	if not is_threatening():
		return [] as Array[Vector2i]
	if _stage == Stage.WARNING:
		return telegraph_cells()
	var plan_cells: Array[Vector2i] = []
	if _plan.has("cells"):
		plan_cells.assign(_plan["cells"] as Array)
	return plan_cells


## Cooldown left of [param skill_id].
func cooldown_left(skill_id: String) -> float:
	return float(_cooldowns.get(skill_id, 0.0))


# --- Monster Skill Phase 0 -------------------------------------------------------------------------------------------

## Phase 0 (burrow / rebirth pause): [param active] false freezes the controller: no clock runs (cooldowns, haste,
## evade, markers, stage timers), nothing is chosen, and a skill in WINDUP / WARNING / FOLLOWUP_WAIT is cancelled at
## once (red off, cooldown x ai.cancel_cooldown_ratio like an interrupt, event "paused"). A RECOVERY / STUNNED timer is
## kept and resumes. true resumes from exactly where the clocks stopped; an idle controller waits one think interval
## before its next choice, so a resume never casts twice. Idempotent.
func set_active(active: bool) -> void:
	if active == _active:
		return
	_active = active
	if not active:
		if not _skill.is_empty() and (_stage == Stage.WINDUP or _stage == Stage.WARNING or _stage == Stage.FOLLOWUP_WAIT):
			_cooldowns[str(_skill["id"])] = float(_skill["cooldown_sec"]) * tempo_mult * float(_ai()["cancel_cooldown_ratio"])
			_end_skill("paused", false)
		_heal_left = 0.0
		_heal_per_sec = 0.0
		event_log.append({"t": _time, "skill": "", "event": "pause", "phase": _phase})
	else:
		if _stage == Stage.IDLE:
			_think_left = think_interval_sec
		event_log.append({"t": _time, "skill": "", "event": "resume", "phase": _phase})


## Phase 0: false while paused by [method set_active].
func is_active() -> bool:
	return _active


## Phase 0 (effects.evade): true while the enemy cannot be hit (TraitHost.extra_untargetable_fn -> SwingArbiter).
func is_evading() -> bool:
	return _evade_left > _EPS


## Phase 0 (effects.shroud): true while the placement hit forecast must be hidden (TraitHost.extra_forecast_blocked_fn).
func is_shrouded() -> bool:
	return _shroud_left > _EPS


## Phase 0: seconds left of the evade / shroud self effects (HUD, tests).
func evade_left() -> float:
	return maxf(_evade_left, 0.0)


func shroud_left() -> float:
	return maxf(_shroud_left, 0.0)


## Phase 0 (M15 immunity): true when this enemy's data lists reaction [param id] in `immune_reactions` and [param side]
## is the enemy's. TraitHost.extra_reaction_immune_fn points here.
func reaction_immune(side: int, id: String) -> bool:
	return side == E and (_enemy.get("immune_reactions", []) as Array).has(id)


## Phase 0: the PLAYER completed a step (CombatView.try_step_player); feeds conditions.player_steps_since.
func on_player_stepped() -> void:
	for id: Variant in _steps_since.keys():
		_steps_since[id] = int(_steps_since[id]) + 1
	_steps_since["*"] = int(_steps_since.get("*", 0)) + 1


## Phase 0 (G5): the `traits` entries ({id, params}) of phase [param index] (the current phase by default); [] when none.
func phase_traits(index: int = -1) -> Array:
	var p: Dictionary = _phase_dict(index)
	return (p.get("traits", []) as Array).duplicate(true)


## Phase 0: the BossBrain weight set the phase asks for ("" = keep the match's).
func phase_brain_set(index: int = -1) -> String:
	return str(_phase_dict(index).get("brain_set", ""))


## Phase 0: the phase's tempo multiplier (1.0 = none); CombatView multiplies the match tempo by it when the phase starts.
func phase_tempo_mult(index: int = -1) -> float:
	return float(_phase_dict(index).get("tempo_mult", 1.0))


func _phase_dict(index: int) -> Dictionary:
	if _enemy.is_empty():
		return {}
	var i: int = _phase if index < 0 else index
	if i < 0 or i >= _phases().size():
		return {}
	return _phases()[i] as Dictionary


## Phase 0 (G4, presentation only): the feedback CombatView plays a resolved ATTACK strike with: {cells, hit, damage,
## skill_id, delivery}; {} for a self / marker skill (nothing to draw on the player's half). A result without a usable
## delivery gets SkillDelivery.FALLBACK, so an unknown delivery never breaks the game; the caller logs it.
static func vfx_feedback(result: Dictionary) -> Dictionary:
	if str(result.get("kind", "attack")) != "attack":
		return {}
	var delivery: Variant = result.get("delivery")
	var out: Dictionary = {
		"cells": (result.get("cells", []) as Array).duplicate(), "hit": bool(result.get("hit", false)),
		"damage": float(result.get("damage", 0.0)), "skill_id": str(result.get("skill_id", "")),
		"delivery": (delivery as Dictionary).duplicate(true) if delivery is Dictionary and not (delivery as Dictionary).is_empty() else SkillDelivery.FALLBACK.duplicate(true),
		"delivery_fallback": not (delivery is Dictionary) or (delivery as Dictionary).is_empty(),
	}
	return out


## 2026-11-03: seconds left of the enemy's haste (effects.haste; 0 = none) - for the view and tests.
func haste_left() -> float:
	return _haste_left


## D9 interrupt: the player's cast HIT the enemy. An interruptible skill in WINDUP or WARNING is cancelled (red off at
## once) and goes on cooldown x ai.cancel_cooldown_ratio. Returns true when something was cancelled.
func on_enemy_hit() -> bool:
	if _skill.is_empty() or not (_stage == Stage.WINDUP or _stage == Stage.WARNING):
		return false
	if not bool(_skill["interruptible"]):
		return false
	var id: String = str(_skill["id"])
	var stun_sec: float = float(_skill.get("interrupt_stun_sec", 0.0))
	_cooldowns[id] = float(_skill["cooldown_sec"]) * tempo_mult * float(_ai()["cancel_cooldown_ratio"])
	_end_skill("interrupted", false)
	if stun_sec > _EPS:
		stun(stun_sec)
	return true


## A player cast landed on [param cells] of the enemy half: markers under it break when the cast has at least their
## break_min_cells cells. P2.3: a broken marker with break_stun_sec stuns the enemy (see [method stun]).
func on_player_cast(cells: Array[Vector2i]) -> void:
	var broke: bool = false
	var stun_sec: float = 0.0
	for i: int in range(_markers.size() - 1, -1, -1):
		var m: Dictionary = _markers[i]
		if cells.has(m["cell"]) and cells.size() >= int(m["break_min_cells"]):
			stun_sec = maxf(stun_sec, float(m.get("break_stun_sec", 0.0)))
			_markers.remove_at(i)
			broke = true
	if broke:
		markers_changed.emit()
	if stun_sec > _EPS:
		stun(stun_sec)


## P2.3: the enemy is stunned for [param sec]: the skill in progress is cancelled at once (red off, its followup
## dropped, cooldown x ai.cancel_cooldown_ratio like an interrupt), then it stands still and casts nothing (is_busy).
## Ignored during a phase transition and when dead.
func stun(sec: float) -> void:
	if sec <= _EPS or _stage == Stage.TRANSITION or _enemy.is_empty() or _state.is_key_dead(_key):
		return
	var already: float = _stage_left if _stage == Stage.STUNNED else 0.0
	# Phase 0: a stun ends a heal over time (the Spore Cap's regrow is lost when it is hit mid-growth).
	_heal_left = 0.0
	_heal_per_sec = 0.0
	if not _skill.is_empty():
		_cooldowns[str(_skill["id"])] = float(_skill["cooldown_sec"]) * tempo_mult * float(_ai()["cancel_cooldown_ratio"])
		_end_skill("stunned", false)
	_set_stage(Stage.STUNNED)
	_stage_left = maxf(already, sec)
	event_log.append({"t": _time, "skill": "", "event": "stun", "sec": sec, "phase": _phase})
	stunned.emit(sec)


## Advances every clock by [param delta] (scaled simulation time: Focus slows / stops it with the match).
func tick(delta: float) -> void:
	if _enemy.is_empty() or delta <= 0.0 or _state.is_key_dead(_key) or _state.is_player_dead() or not _active:
		return
	_time += delta
	_since_warning += delta
	_since_aim += delta
	_since_push += delta
	for id: String in _cooldowns.keys():
		_cooldowns[id] = maxf(float(_cooldowns[id]) - delta, 0.0)
	_haste_left = maxf(_haste_left - delta, 0.0)
	_evade_left = maxf(_evade_left - delta, 0.0)
	_shroud_left = maxf(_shroud_left - delta, 0.0)
	if _heal_left > _EPS:
		var slice: float = minf(delta, _heal_left)
		_state.heal_key(_key, _heal_per_sec * slice)
		_heal_left -= slice
	if _state.player_cell == _last_player_cell:
		_still_sec += delta
	else:
		_still_sec = 0.0
		_last_player_cell = _state.player_cell
	_tick_markers(delta)
	if _stage != Stage.TRANSITION and _phase + 1 < _phases().size() \
			and _state.hp_of(_key) <= float(_phases()[_phase + 1]["enter_hp_ratio"]) * _state.max_hp_of(_key) + _EPS:
		_begin_transition()
		return
	match _stage:
		Stage.TRANSITION:
			_unit().invulnerable_left = maxf(_unit().invulnerable_left - delta, 0.0)
			_stage_left -= delta
			if _stage_left <= _EPS:
				_unit().invulnerable_left = 0.0
				_set_stage(Stage.IDLE)
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
		Stage.RECOVERY, Stage.STUNNED:
			_stage_left -= delta
			if _stage_left <= _EPS:
				_set_stage(Stage.IDLE)
				_think_left = 0.0
		Stage.FOLLOWUP_WAIT:
			_stage_left -= delta
			if _stage_left <= _EPS:
				_start_followup()
		Stage.IDLE:
			_think_left -= delta
			if _think_left <= _EPS:
				_think_left = think_interval_sec
				_try_choose()


# --- choice ---------------------------------------------------------------------------------------------------------

func _try_choose() -> void:
	if not FairnessCheck.gap_ok(_since_any_warning(), maxf(_gap_needed, float(_config.fairness["min_gap_between_warnings_sec"]))):
		return
	# Multi-enemy Phase 3 (D1): no free attack token = no skill this think (checked before the on_enter queue is read,
	# so a forced skill waits for its token instead of being lost); a single enemy's board never refuses.
	if threat_board != null and not threat_board.request(_key):
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
	if not forced_queue_skill.is_empty():
		forced = forced_queue_skill  # on_enter forces its skill (schema: weight 0 = only when forced by every_nth / on_enter)
	elif not every.is_empty() and (_phase_casts + 1) % int(every["n"]) == 0:
		forced = str(every["skill"])
	var choice: Dictionary = _brain.choose(candidates, {
		"player_cell": _state.player_cell, "player_still_sec": _still_sec, "last_skill": _last_skill,
		"mechanic": str(phase["mechanic"]), "forced_skill": forced,
		# Phase 0: the fight's state the `weights` blocks read.
		"player_statuses": _player_statuses(), "player_zones": _player_zones(), "self_statuses": _self_statuses(),
		"allies_alive": int(_allies().get("alive", 0)),
	})
	if choice.is_empty():
		if threat_board != null:
			threat_board.release(_key)
		return
	_skill = choice["skill"] as Dictionary
	_plan = choice["plan"] as Dictionary
	_set_stage(Stage.WINDUP)
	_stage_left = float(_skill["windup_sec"]) * tempo_mult
	if _stage_left <= _EPS:
		_after_windup()


func _conditions_ok(skill: Dictionary, phase: Dictionary) -> bool:
	var c: Dictionary = skill["conditions"] as Dictionary
	var ratio: float = _state.hp_of(_key) / maxf(_state.max_hp_of(_key), _EPS)
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
	if c.has("player_aimed_within_sec") and _since_aim > float(c["player_aimed_within_sec"]) + _EPS:
		return false
	# Phase 0 (design §5.2): the fight's state. Any-of lists: a string counts as a one-item list.
	if c.has("player_status") and not _any_of(c["player_status"], _player_statuses()):
		return false
	if c.has("player_on_zone") and not _any_of(c["player_on_zone"], _player_zones()):
		return false
	if c.has("self_status") and not _any_of(c["self_status"], _self_statuses()):
		return false
	if c.has("player_steps_since") and int(_steps_since.get(str(skill["id"]), _steps_since.get("*", 0))) < int(c["player_steps_since"]):
		return false
	if c.has("burning_cells") and _status != null and _zone_fires().size() < int(c["burning_cells"]):
		return false
	if typeof(c.get("max_zone_cells")) == TYPE_DICTIONARY:
		# The zone budget (design §9.3): the skill waits while the player's half already holds that many cells of the kind.
		for kind: Variant in (c["max_zone_cells"] as Dictionary):
			if _zone_cell_count(str(kind)) >= int((c["max_zone_cells"] as Dictionary)[kind]):
				return false
	var allies: Dictionary = _allies()
	if c.has("allies_alive_min") and int(allies.get("alive", 0)) < int(c["allies_alive_min"]):
		return false
	if c.has("allies_alive_max") and int(allies.get("alive", 0)) > int(c["allies_alive_max"]):
		return false
	if c.has("ally_died_within_sec") and float(allies.get("died_within_sec", INF)) > float(c["ally_died_within_sec"]) + _EPS:
		return false
	if c.has("ally_hp_below") and float(allies.get("min_hp_ratio", 1.0)) > float(c["ally_hp_below"]) + _EPS:
		return false
	return true


# Phase 0: true when [param wanted] (a String or an Array of ids) names at least one id of [param have].
static func _any_of(wanted: Variant, have: Array[String]) -> bool:
	if wanted is Array:
		for id: Variant in (wanted as Array):
			if have.has(str(id)):
				return true
		return false
	return have.has(str(wanted))


## Phase 0: the status ids on the player right now (StatusEffects ids: frozen = pin): fragile, frost, slow, root,
## frozen, poison, mark.
func _player_statuses() -> Array[String]:
	var out: Array[String] = []
	if _status == null:
		return out
	if _status.fragile_stacks(P) > 0:
		out.append("fragile")
	if _status.frost_stacks(P) > 0:
		out.append("frost")
	if _status.get_slow_left(P) > _EPS:
		out.append("slow")
	if _status.is_rooted(P):
		out.append("root")
	if _status.is_pinned(P):
		out.append("frozen")
	if _status.is_poisoned(P):
		out.append("poison")
	if _status.has_mark(P):
		out.append("mark")
	return out


## Phase 0: the zone kinds under the player's cell right now: burn, thorns, mire, sand, crack (StatusEffects / TileHazards).
func _player_zones() -> Array[String]:
	var out: Array[String] = []
	var cell: Vector2i = _state.player_cell
	if _status != null:
		if _status.is_burning(cell):
			out.append("burn")
		if not _status.thorns_at(P, cell).is_empty():
			out.append("thorns")
		if _status.is_cracking(P, cell):
			out.append("crack")
	if hazards != null:
		if hazards.is_mire(P, cell):
			out.append("mire")
		if hazards.is_sanded(P, cell):
			out.append("sand")
	return out


## Phase 0: the enemy's own self-effect ids right now: guard, haste, evade, shroud.
func _self_statuses() -> Array[String]:
	var out: Array[String] = []
	if _status != null and _status.guard_amount(_key) > 0.0:
		out.append("guard")
	if _haste_left > _EPS:
		out.append("haste")
	if is_evading():
		out.append("evade")
	if is_shrouded():
		out.append("shroud")
	return out


# Phase 0: cells of [param kind] on the player's half (burn / thorns / mire / sand / hole / fall), for max_zone_cells.
func _zone_cell_count(kind: String) -> int:
	match kind:
		"burn":
			if _status == null:
				return 0
			var n: int = 0
			for c: Vector2i in _status.burning_cells():
				if _grid.is_player_cell(c):
					n += 1
			return n
		"thorns":
			return _status.thorn_cells(P).size() if _status != null else 0
		"mire":
			return hazards.mire_cells(P).size() if hazards != null else 0
		"sand":
			return hazards.sand_cells(P).size() + hazards.sand_warning_cells(P).size() if hazards != null else 0
		"hole", "drop":
			return _status.hole_cells(P).size() + _status.crack_cells(P).size() if _status != null else 0
		"fall":
			return hazards.fallen_cells(P).size() if hazards != null else 0
	return 0


func _allies() -> Dictionary:
	if allies_fn.is_valid():
		var d: Variant = allies_fn.call()
		if d is Dictionary:
			return d as Dictionary
	return {"alive": 0, "died_within_sec": INF, "min_hp_ratio": 1.0}


# Plans of [param skill] that pass F1 (4.1) and F2 (red ceiling). Self / marker skills only need a plan.
func _valid_plans(skill: Dictionary, warning_sec: float) -> Array[Dictionary]:
	if typeof((skill["effects"] as Dictionary).get("move")) == TYPE_DICTIONARY:
		# P2.3 (Rootling creep): one plan per cell it may step to; none = it cannot cast now.
		var moves: Array[Dictionary] = []
		for cell: Vector2i in _move_targets(str(((skill["effects"] as Dictionary)["move"] as Dictionary).get("to", "adjacent_row"))):
			moves.append({"cells": [cell] as Array[Vector2i], "anchor": cell, "rotation": 0, "move_to": cell})
		return moves
	var all: Array[Dictionary] = PatternPlanner.plans(skill, _plan_ctx())
	if str(skill["kind"]) != "attack":
		return all
	var out: Array[Dictionary] = []
	var most_rows: int = 1
	for plan: Dictionary in all:
		if _fair(plan["cells"] as Array, warning_sec):
			out.append(plan)
			most_rows = maxi(most_rows, int(plan.get("rows", 1)))
	if most_rows > 1:
		# P2.4 (entangled_row, phases 2-3): two rows when a two-row plan passes F1 / F2, else one.
		return out.filter(func(p: Dictionary) -> bool: return int(p.get("rows", 1)) == most_rows)
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
		"grid": _grid, "player_cell": _state.player_cell, "enemy_cell": _state.cell_of(_key), "markers": marker_cells(),
		"enemy_cells": _state.unit_cells(_key),
		# Phase 3: a cell under ANOTHER living enemy unit is not this unit's free cell (no other unit = unchanged)
		"cell_ok_fn": (func(c: Vector2i) -> bool: return not status.is_locked(c) and _free_of_others(c)) if status != null else Callable(),
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
			var lanes: Array[Dictionary] = _fair_followups(followup, chosen["cells"] as Array[Vector2i], float(_skill["warning_sec"]), chosen["cells"] as Array, int(chosen.get("rotation", 0)))
			if not lanes.is_empty():
				queued = lanes[0]["cells"] as Array[Vector2i]
	if chosen.is_empty() or not FairnessCheck.gap_ok(_since_any_warning(), float(_config.fairness["min_gap_between_warnings_sec"])):
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
	_set_stage(Stage.WARNING)
	_since_warning = 0.0
	if threat_board != null:
		threat_board.note_warning()
	warning_started.emit(str(_skill["id"]), _warn_cells.duplicate(), _queued_cells.duplicate(), warning_sec)


func _resolve_warning() -> void:
	var effects: Dictionary = (_skill["followup"] as Dictionary)["effects"] if _is_followup else _skill["effects"]
	var result: Dictionary = _resolve_cells(_warn_cells, effects as Dictionary)
	# Crash fix 2026-11-13: the strike may have ended its own skill inside _resolve_cells (a parried reflect crossing
	# a phase threshold, a rebirth / burrow pause, a stun). _end_skill has already emitted warning_cleared and reset
	# the stage, so there is nothing left to clear, follow up or finish — and _skill is empty, which every line below
	# would read.
	if _skill.is_empty():
		return
	warning_cleared.emit(str(_skill["id"]), "resolved")
	var followup: Dictionary = _skill["followup"] as Dictionary
	if _is_followup or followup.is_empty() or marker_cells().size() < int(followup["requires_anchor"]):
		_finish_skill()
		return
	_first_cells = _warn_cells.duplicate()
	if float(followup.get("delay_sec", 0.0)) > _EPS and not bool(followup["show_with_first"]):
		# P2.3: the enemy holds still delay_sec, then the followup warning starts (cells chosen then).
		_warn_cells.clear()
		_set_stage(Stage.FOLLOWUP_WAIT)
		_stage_left = float(followup["delay_sec"])
		return
	_start_followup()


# Followup (3.5): cells chosen NOW and checked against the player NOW; failing = dropped, never moved silently.
# P2.3: also re-checks requires_anchor (a delayed followup needs its anchor alive when it starts).
func _start_followup() -> void:
	var followup: Dictionary = _skill["followup"] as Dictionary
	if marker_cells().size() < int(followup["requires_anchor"]):
		_finish_skill()
		return
	var next: Array[Vector2i] = []
	if bool(followup["show_with_first"]) and not _queued_cells.is_empty():
		if _fair(_queued_cells, float(followup["warning_sec"])):
			next = _queued_cells.duplicate()
	else:
		var lanes: Array[Dictionary] = _fair_followups(followup, _first_cells, float(followup["warning_sec"]), [], int(_plan.get("rotation", 0)))
		if not lanes.is_empty():
			next = _brain.pick_plan(lanes, _state.player_cell)["cells"] as Array[Vector2i]
	if next.is_empty():
		_finish_skill()
		return
	_is_followup = true
	_start_warning(next, [] as Array[Vector2i], float(followup["warning_sec"]))


func _fair_followups(followup: Dictionary, first: Array[Vector2i], warning_sec: float, extra_red: Array, first_rotation: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lane: Dictionary in PatternPlanner.followup_candidates(followup, first, _state.player_cell, _plan_ctx(), first_rotation):
		if _fair(lane["cells"] as Array, warning_sec, extra_red):
			out.append(lane)
	return out


# Applies [param effects] on [param cells] (A1: the cells only). Returns the result logged and emitted.
func _resolve_cells(cells: Array[Vector2i], effects: Dictionary) -> Dictionary:
	var open: Array[Vector2i] = _status.unlocked_cells(cells) if _status != null else cells.duplicate()
	var hit: bool = open.has(_state.player_cell)
	var result: Dictionary = {"skill_id": str(_skill["id"]), "cells": open, "hit": hit, "damage": 0.0, "status": "", "zone_cells": [] as Array[Vector2i], "followup": false,
		# Phase 0 (G4): what the view needs to draw the strike (presentation reads it, never the other way round).
		"kind": str(_skill.get("kind", "attack")), "delivery": (_skill.get("delivery", {}) as Dictionary).duplicate(true)}
	var damage: float = float(effects.get("damage", 0.0))
	if effects.has("damage_no_markers") and _markers.is_empty():
		damage = float(effects["damage_no_markers"])  # P2.4: forest_last_knot without an anchor
	# Cast rhythm spec 2026-11-05: an open parry guard takes the whole strike (damage and status) and reflects it.
	var has_status: bool = typeof(effects.get("status")) == TYPE_DICTIONARY
	result["parried"] = false
	if hit and (damage > 0.0 or has_status) and player_guard != null and player_guard.is_active():
		var parry: Dictionary = player_guard.try_parry(_state, _status, damage, _key)
		result["parried"] = true
		result["reflected"] = float(parry.get("reflected", 0.0))
		result["blocked"] = float(parry.get("blocked", 0.0))
		damage = 0.0
		has_status = false
	if hit and damage > 0.0:
		var before: float = _state.player_hp
		if _status != null:
			# Phase 0 (bug G1): the player's Rạn (fragile) multiplies an enemy strike and spends a stack, as it does for
			# the block boss's casts (CutEffects). Before the ward, which is the hero's armour.
			if _status.fragile_stacks(P) > 0:
				damage *= _status.consume_fragile(P)
				result["fragile_hit"] = true
			# Skill v2 batch 3 (M10): the hero on a ward takes x damage_mult minus the ward's Guard (StatusEffects.ward_absorb).
			damage = _status.ward_absorb(CombatState.Side.PLAYER, damage, _state)
		_state.damage_player(damage)
		result["damage"] = before - _state.player_hp
	if hit and _status != null and has_status:
		var st: Dictionary = effects["status"] as Dictionary
		if not bool(st["first_cell_only"]) or (not open.is_empty() and open[0] == _state.player_cell and cells[0] == open[0]):
			result["status"] = _apply_status(st, result)
	if hit and not bool(result["parried"]) and (effects.has("push") or effects.has("pull")):
		# Phase 0 (design §5.2): a forced move of the hero through the cards' own push / pull (CutEffects), R3 when stopped.
		_apply_forced_move(effects, result)
	if _status != null and typeof(effects.get("zone")) == TYPE_DICTIONARY and str((effects["zone"] as Dictionary).get("side", "player")) == "player":
		result["zone_cells"] = _apply_zone(effects["zone"] as Dictionary, open)
	_record(result)
	# Crash fix 2026-11-13 (found by the monster-skills session, kiem_si set 2001): everything above may end the skill
	# under us — a parried strike whose reflect crosses a phase threshold, a rebirth or burrow pause, a stun — and
	# _end_skill empties _skill. Read the id from the result, which was filled before any of that ran.
	skill_resolved.emit(str(result["skill_id"]), result)
	return result


# Phase 0: effects.push {cells} moves the hero away from the divider, effects.pull {cells} toward the enemy's cast origin;
# never into a cell player_blocked_fn refuses, never through a ward with push_immune, never inside push_icd_sec of the
# previous one. A move stopped short slams (R3, the cards' reaction numbers, the shared reaction gate).
func _apply_forced_move(effects: Dictionary, result: Dictionary) -> void:
	if push_icd_sec > _EPS and _since_push < push_icd_sec - _EPS:
		result["push_icd"] = true
		return
	if _status != null and _status.ward_push_immune(P, _state):
		result["push_immune"] = true
		return
	var wanted: int = 0
	var moved: int = 0
	var blocked: bool = false
	if effects.has("push"):
		wanted = int((effects["push"] as Dictionary)["cells"])
		moved = CutEffects.push_away(_state, _grid, P, wanted, player_blocked_fn)
		blocked = moved < wanted
	else:
		wanted = int((effects["pull"] as Dictionary)["cells"])
		var pulled: Dictionary = CutEffects.pull_toward(_state, _grid, P, _state.cast_origin(_key), wanted, player_blocked_fn)
		moved = int(pulled["steps"])
		blocked = bool(pulled["blocked"])
	_since_push = 0.0
	result["moved"] = moved
	if blocked and _status != null and _status.reaction_allowed(P, "r3", float(reactions.get("icd_sec", -1.0))):
		var r3: Dictionary = CutEffects.reaction_numbers({"reactions": reactions})["r3"] as Dictionary
		var dmg: float = float(r3.get("damage", 8.0))
		var before: float = _state.player_hp
		_state.damage_player(dmg)
		result["damage"] = float(result["damage"]) + (before - _state.player_hp)
		if float(r3.get("pin_sec", 0.0)) > 0.0:
			_status.pin(P, float(r3["pin_sec"]))
		result["reaction"] = "r3"
		_status.reaction_fired.emit(P, "r3", dmg)


func _apply_status(st: Dictionary, result: Dictionary = {}) -> String:
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
			# Phase 0 (bug G2): apply_frost RETURNS the burst damage and the caller applies it (StatusEffects' contract);
			# it ignores defense and Rạn, so it goes straight to the HP, not through the ward.
			var burst: float = _status.apply_frost(P, int(st["stacks"]))
			if burst > 0.0:
				var before: float = _state.player_hp
				_state.damage_player(burst)
				result["frost_burst"] = burst
				result["damage"] = float(result.get("damage", 0.0)) + (before - _state.player_hp)
		"poison":
			_status.poison(P, float(st["sec"]), float(st["tick_sec"]), float(st["damage"]))
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
	# Phase 0 (design §5.2): the cell effects that already exist, opened to enemy skills. Each keeps its own leave-a-path
	# rule (ignite: the one-zone-per-cell book; TileHazards: its own blockers) on top of F3 above.
	if id == "burn":
		return _ignite(zone_cells, zone)
	if hazards == null:
		push_warning("PatternController: zone '%s' needs the match TileHazards (none wired), skipped" % id)
		return [] as Array[Vector2i]
	if id == "mire":
		hazards.add_mire(P, zone_cells, maxf(float(zone.get("sec", 4.0)), 0.05))
		return zone_cells
	if id == "sand":
		return hazards.add_sand(P, zone_cells, float(zone.get("sec", -1.0)), float(zone.get("warn_sec", -1.0)))
	if id == "fall":
		return hazards.drop_cells(P, zone_cells, float(zone.get("fall_sec", -1.0)), float(zone.get("warn_sec", -1.0)))
	return [] as Array[Vector2i]


# Phase 0: lights [param cells] through the ONE burn API every fire uses (row_burner, vents, the cards): sec / tick_sec /
# damage from the zone (defaults 3 / 0.5 / 2, the row_burner numbers). Returns the cells lit.
func _ignite(cells: Array[Vector2i], zone: Dictionary) -> Array[Vector2i]:
	if cells.is_empty() or _status == null:
		return [] as Array[Vector2i]
	_status.ignite(cells, maxf(float(zone.get("sec", 3.0)), 0.05), maxf(float(zone.get("tick_sec", 0.5)), 0.05), maxf(float(zone.get("damage", 2.0)), 0.0))
	return cells.duplicate()


func _resolve_self_or_marker() -> void:
	var effects: Dictionary = _skill["effects"] as Dictionary
	var result: Dictionary = {"skill_id": str(_skill["id"]), "cells": [] as Array[Vector2i], "hit": false, "damage": 0.0, "status": "", "zone_cells": [] as Array[Vector2i], "followup": false,
		"kind": str(_skill.get("kind", "self")), "delivery": (_skill.get("delivery", {}) as Dictionary).duplicate(true)}
	var left_cells: Array[Vector2i] = _state.unit_cells(_key)
	if str(_skill["kind"]) == "marker":
		var plans: Array[Dictionary] = PatternPlanner.plans(_skill, _plan_ctx())
		var marker: Dictionary = effects.get("marker", {"life_sec": float(_config.defaults["marker_life_sec"]), "break_min_cells": int(_config.defaults["marker_break_min_cells"])}) as Dictionary
		var placed_rows: Array[int] = []
		for i: int in int((_skill["pattern"] as Dictionary)["count"]):
			if plans.is_empty():
				break
			# P2.4: several markers in one cast go to different rows when they can (Witch root_anchor x2 feeds the
			# two-row entangled_row); one marker per cast picks exactly as before.
			var pool: Array[Dictionary] = plans.filter(func(p: Dictionary) -> bool: return not placed_rows.has((p["anchor"] as Vector2i).y))
			if pool.is_empty():
				pool = plans
			var plan: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
			plans.erase(plan)
			var cell: Vector2i = (plan["cells"] as Array[Vector2i])[0]
			placed_rows.append(cell.y)
			_markers.append({"cell": cell, "left": float(marker["life_sec"]), "break_min_cells": int(marker["break_min_cells"]),
				"kind": str(marker.get("kind", "anchor")), "break_stun_sec": float(marker.get("break_stun_sec", 0.0))})
			(result["cells"] as Array[Vector2i]).append(cell)
		markers_changed.emit()
	if typeof(effects.get("move")) == TYPE_DICTIONARY and _plan.has("move_to"):
		# P2.3 (Rootling creep): steps to the cell shown during the windup when it is still free; else stays.
		var to: Vector2i = _plan["move_to"] as Vector2i
		if _can_move_to(to) and _state.set_key_cell(_key, to):
			(result["cells"] as Array[Vector2i]).append(to)
	if typeof(effects.get("haste")) == TYPE_DICTIONARY:
		_haste_left = float((effects["haste"] as Dictionary)["sec"])
		_haste_mult = float((effects["haste"] as Dictionary)["cooldown_mult"])
		result["status"] = "haste"
	if typeof(effects.get("guard")) == TYPE_DICTIONARY and _status != null:
		var g: Dictionary = effects["guard"] as Dictionary
		if not bool(g["while_markers"]) or not _markers.is_empty():
			_status.guard(_key, float(g["amount"]), float(g["sec"]))
			_guard_markers = bool(g["while_markers"])
			result["status"] = "guard"
	# Phase 0 self effects (design §5.2): heal (at once, or over sec through tick), consume_burn, evade, shroud, and a
	# zone with side `self` on the footprint cells the enemy just LEFT (molten trail; its current cells when it did not move).
	if typeof(effects.get("heal")) == TYPE_DICTIONARY:
		var h: Dictionary = effects["heal"] as Dictionary
		var amount: float = float(h["amount"]) + float(h["ratio"]) * _state.max_hp_of(_key)
		if float(h["sec"]) > _EPS:
			_heal_left = float(h["sec"])
			_heal_per_sec = amount / float(h["sec"])
		else:
			_state.heal_key(_key, amount)
		result["heal"] = amount
		result["status"] = "heal"
	if typeof(effects.get("consume_burn")) == TYPE_DICTIONARY and _status != null:
		var burning: Array[Vector2i] = _zone_fires()
		if not burning.is_empty():
			_status.clear_burn(burning)
			var gained: float = _state.heal_key(_key, float((effects["consume_burn"] as Dictionary)["heal_per_cell"]) * burning.size())
			result["consumed_burn"] = burning.size()
			result["heal"] = gained
	if typeof(effects.get("evade")) == TYPE_DICTIONARY:
		_evade_left = maxf(_evade_left, float((effects["evade"] as Dictionary)["sec"]))
		result["status"] = "evade"
	if typeof(effects.get("shroud")) == TYPE_DICTIONARY:
		_shroud_left = maxf(_shroud_left, float((effects["shroud"] as Dictionary)["sec"]))
		result["status"] = "shroud"
	if typeof(effects.get("zone")) == TYPE_DICTIONARY and str((effects["zone"] as Dictionary).get("side", "player")) == "self":
		var zone: Dictionary = effects["zone"] as Dictionary
		if str(zone.get("id", "")) == "burn":
			result["zone_cells"] = _ignite(left_cells, zone)
		else:
			push_warning("PatternController: zone side 'self' supports burn only ('%s' skipped)" % str(zone.get("id", "")))
	_record(result)
	# Same reason as in _resolve_cells: a self skill's own effects can end it before this line.
	skill_resolved.emit(str(result["skill_id"]), result)


# P2.3: cells a moving self skill may step to: one row up / down on the enemy's half (effects.move.to adjacent_row).
# Phase 0: `far_cell` = the anchors of its half the footprint fits on, at the largest step distance from where it stands
# (several at a tie, the controller's seeded pick chooses); none when nothing is farther than its own cell.
func _move_targets(to: String = "adjacent_row") -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if to == "far_cell":
		var best: int = 0
		for anchor: Vector2i in _state.unit_anchors(CombatState.unit_index_of(_key)):
			if anchor == _state.cell_of(_key) or not _can_move_to(anchor):
				continue
			var dist: int = absi(anchor.x - _state.cell_of(_key).x) + absi(anchor.y - _state.cell_of(_key).y)
			if dist > best:
				best = dist
				out.clear()
			if dist == best:
				out.append(anchor)
		return out
	for dy: int in [-1, 1]:
		var cell: Vector2i = _state.cell_of(_key) + Vector2i(0, dy)
		if _can_move_to(cell):
			out.append(cell)
	return out


# The enemy's footprint fits on [param anchor]: no hole / crack, no marker under it.
func _can_move_to(anchor: Vector2i) -> bool:
	var status: StatusEffects = _status
	var marks: Array[Vector2i] = marker_cells()
	return _state.key_fits(_key, anchor, func(c: Vector2i) -> bool:
		return marks.has(c) or (status != null and (status.is_hole(E, c) or status.is_cracking(E, c))))


func _finish_skill() -> void:
	var id: String = str(_skill["id"])
	# Haste shortens the other skills' cooldowns, never the cooldown of the skill that grants it.
	var hasted: bool = _haste_left > _EPS and not (_skill["effects"] as Dictionary).has("haste")
	_cooldowns[id] = float(_skill["cooldown_sec"]) * tempo_mult * (_haste_mult if hasted else 1.0)
	if bool((_skill["conditions"] as Dictionary).get("once", false)):
		_used_once[id] = true
	# Phase 0: conditions.player_steps_since counts from the skill's last cast.
	_steps_since[id] = 0
	_last_skill = id
	if bool(_skill.get("counts_as_cast", true)):
		_phase_casts += 1
	_gap_needed = FairnessCheck.gap_needed(float(_skill["recovery_sec"]), float(_config.fairness["min_gap_between_warnings_sec"]),
		_player_step_cd(), float(_config.fairness["reaction_margin_sec"]), float(_config.fairness["heavy_recovery_sec"]))
	var recovery: float = float(_skill["recovery_sec"]) * tempo_mult
	_skill = {}
	_warn_cells.clear()
	_queued_cells.clear()
	_is_followup = false
	_set_stage(Stage.RECOVERY if recovery > _EPS else Stage.IDLE, id)
	_stage_left = recovery
	_think_left = 0.0


func _end_skill(reason: String, _resolved: bool) -> void:
	var id: String = str(_skill.get("id", ""))
	var was_warning: bool = _stage == Stage.WARNING
	_skill = {}
	_warn_cells.clear()
	_queued_cells.clear()
	_is_followup = false
	_set_stage(Stage.IDLE, id)
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
	_set_stage(Stage.TRANSITION)
	_stage_left = sec
	_unit().invulnerable_left = sec
	event_log.append({"t": _time, "skill": "", "event": "phase", "phase": _phase})
	phase_started.emit(_phase, str(_phases()[_phase]["id"]))
	if sec <= _EPS:
		_unit().invulnerable_left = 0.0
		_set_stage(Stage.IDLE)
		_apply_hp_floor()
		_forced_queue.assign(((_phases()[_phase] as Dictionary)["transition"] as Dictionary)["on_enter"] as Array)


# Floors enemy HP at the next phase's threshold (one hit never skips a phase), 0 in the last phase.
func _apply_hp_floor() -> void:
	if _enemy.is_empty():
		return
	if _phase + 1 < _phases().size():
		_unit().hp_floor = float(_phases()[_phase + 1]["enter_hp_ratio"]) * _unit().max_hp
	else:
		_unit().hp_floor = 0.0


func _tick_markers(delta: float) -> void:
	var changed: bool = false
	for i: int in range(_markers.size() - 1, -1, -1):
		_markers[i]["left"] = float(_markers[i]["left"]) - delta
		if float(_markers[i]["left"]) <= _EPS:
			_markers.remove_at(i)
			changed = true
	if _guard_markers and _markers.is_empty() and _status != null:
		_status.clear_guard(_key)
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


# Phase 3: true when no OTHER living enemy unit covers [param cell] (always true with one unit).
func _free_of_others(cell: Vector2i) -> bool:
	var other: int = _state.key_at(CombatState.Side.ENEMY, cell)
	return other < 0 or other == _key


# R11 (user-approved 2026-11-13): fires a skill or a card lit (zone fire); a lava vent's terrain fire is not food for
# consume_burn (eater_devour) and does not count toward a `burning_cells` condition.
func _zone_fires() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _status == null:
		return out
	for c: Vector2i in _status.burning_cells():
		if _status.zone_kind_at(c) == StatusEffects.KIND_BURN:
			out.append(c)
	return out

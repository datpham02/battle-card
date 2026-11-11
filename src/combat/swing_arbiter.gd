class_name SwingArbiter
extends RefCounted
## Owns the temporal order of the two sides' swings and the two-way interrupt rule.
## It ticks both CutActors in time order (never in one big jump), applies each resolved swing
## through CutEffects, and cancels the opponent's running swing when a swing HITS. A swing that
## misses never cancels; two swings resolving within [constant TIE_EPSILON_SEC] of each other
## trade (both resolve, no cancel). When either unit dies both swings are cancelled.
## A swing QUEUED on an actor (the boss's combo second swing, Story 013) is started by CutActor.tick
## when its running swing resolves and is ticked from the NEXT slice, never in the one that resolved it.
## Implements: Story 009.
## Skill v2 B1.5 (docs/skill-v2/02-mechanics-catalog.md M02): the arbiter owns the authoritative combat CLOCK
## ([method clock], advanced only by [method tick]). A resolved swing is turned into an impact plan by CastResolver:
## an `instant` card (every card today) keeps the pre-v2 path below unchanged; a scheduled card (`waves` / `arrival`)
## puts its impact EVENTS on the clock. Events fire in (time, schedule order) order inside the same time slicing as the
## swings (a slice never jumps over an event; at the same instant swings settle first, then due events). Per event:
## the target is hit when it stands on the event's cells at that moment, at most once per wave and `max_hits` times
## per cast; damage counts the cast's total cells. The first damaging event interrupts the opponent's running swing
## (not on a trade at t = 0, never for a parry card). A cast's scheduled events survive the caster being hit; all are
## cleared when a unit dies ([method clear_scheduled] for the match end). A swing cancelled before it resolves
## schedules nothing.
## Skill v2 delayed (M07; Hỏa Lôi): an `armed` event is an armed-zone cell until it fires (the armed-zone registry is
## this schedule: [method armed_cells], [method armed_cast_count]); a new delayed cast of the same side skips cells that
## are already armed. A `recheck_locked` event drops the cells locked by the time it fires (no damage, no payload
## there). An event `payload` (ignite) is applied on its open cells after the damage, hit or miss; a `push` payload
## (batch 1, Mìn Trễ) moves the target away from the mask's centre on a damaging hit (CutEffects.push_from).

## Emitted after a swing's effects were applied. [param result] is CutEffects' dictionary
## {hit, damage, pushed, cell} extended with {cells, skill_id, level, pin_bonus}. [param side] = CombatState.Side.
## Story 028: a PLAYER swing started with a featured bonus (CutActor.begin_swing's `featured_bonus`) also
## reports result.featured / featured_mult / featured_effect / featured_stacks / featured_sec (CutEffects).
signal swing_resolved(side: int, result: Dictionary)
## Skill v2 B1 (M02): one impact wave of a swing resolved: [param wave] {wave, t, cells, kind, mult} and the CutEffects
## [param result] (carries `cast_context`). Emitted before [signal swing_resolved] (B1: exactly one wave per swing).
signal wave_resolved(side: int, wave: Dictionary, result: Dictionary)
## Emitted when a hit cancelled the opponent's running swing; [param victim_side] is the
## side whose swing was cancelled, [param cells] / [param skill_id] that cancelled swing.
signal swing_interrupted(victim_side: int, cells: Array[Vector2i], skill_id: String)
## Skill v2 B1.5: one impact event of a SCHEDULED cast fired: [param event] {cast_id, wave, index, t, at, cells, kind,
## mult}, [param hit] whether it damaged the target. Instant (legacy) casts do not emit it.
signal impact_resolved(side: int, event: Dictionary, hit: bool)
## Skill v2 (Trảm Địa): a scheduled cast was put on the clock at the swing end: [param cast] {cast_id, side, skill_id,
## cells, events (the plan's events with `at`), context}. Presentation reads it (the travel landing, the forecast).
signal cast_scheduled(side: int, cast: Dictionary)

## Two swings resolving this close in time count as simultaneous.
const TIE_EPSILON_SEC: float = 0.0005
## Smallest time slice, guarantees the tick loop always makes progress.
const _MIN_SLICE_SEC: float = 0.000001

var _state: CombatState
var _grid: BoardGrid
var _actors: Dictionary = {}
var _cut_config: CutConfig
var _skill_config: SkillConfig
var _pending: Array[Dictionary] = []
var _status: StatusEffects = null
## Skill v2 Vũng Lầy: the match hazards. Null in tests that never lay mire. CombatView sets it after TileHazards exists.
var tile_hazards: TileHazards = null
## Story 018: Callable(cells: int, damage: float) -> float applied to the PLAYER's hit damage only
## (the character passive); invalid = none.
var player_damage_modifier: Callable = Callable()
## Story 021: signature hooks for the PLAYER only (see CutEffects.apply): the cell count used for
## damage, and the LAST damage scale (after Ghim and the passive).
var player_cells_modifier: Callable = Callable()
var player_signature_modifier: Callable = Callable()
## Story 032: the relics' ONE damage hook for the PLAYER only: Callable(cells: int, damage: float) -> float
## (CombatView folds RelicRegistry.fold_damage, product capped), applied by CutEffects right after the
## featured multiplier; invalid = none. And the relics' merged config overrides for the PLAYER's zone cards
## (thorn_sec / thorn_ran, applied after the card's own number; RelicRegistry.merge_overrides form).
var player_relic_modifier: Callable = Callable()
var player_zone_overrides: Dictionary = {}
## Story 037: Callable() -> float, the factor the PLAYER's zone cards multiply their seal / thorn seconds by
## (the character signature Vay Bat); invalid = 1.0.
var player_zone_sec_mult_fn: Callable = Callable()
## Quick spec 2026-10-31: Callable() -> int, extra thorn cells the PLAYER's thorn cards lay (the signature
## Vay Bat, CutEffects.extra_thorn_cells); invalid = 0.
var player_extra_thorn_cells_fn: Callable = Callable()
## User 2026-11-01: the match's seeded RNG for the RANDOM extra thorn cells of Vay Bat (CutEffects.extra_thorn_cells,
## options.zone_rng). CombatView seeds it from the match seed; null = CutEffects uses a randomized one.
var zone_rng: RandomNumberGenerator = null
## Story 023: flat defense of the BOSS (match key boss_defense, subtracted from the player's damage/push
## hits last, minimum 1; `pierce_defense` cards skip it) and the default execute threshold (combat.json
## execute_ratio). 0 = none; set by CombatView.
var boss_defense: float = 0.0
var execute_ratio: float = 0.0
## Story 027: zone numbers for seal / thorns cards (CombatConfig.zone_numbers(); empty = CombatConfig
## fallbacks) and, per CombatState.Side, the Callable(cell) -> bool that says whether that side's unit is
## blocked from stepping onto a cell (UnitMover.is_cell_blocked); used by the seal leave-a-path rule.
var zone_numbers: Dictionary = {}
var blocked_cell_fns: Dictionary = {}
## Story 036: Callable() -> bool, true while the BOSS cannot be hit (TraitHost.is_boss_untargetable, burrow; set by
## TraitHost). A player cast that lands then is a miss (no damage, no interrupt) but still leaves its zone. Invalid = never.
var enemy_untargetable_fn: Callable = Callable()
## Cast rhythm spec 2026-11-05: the hero's ParryGuard; the BOSS's swings pass it to CutEffects (options.player_guard), so
## a swing landing on the hero while it is open is parried. A parried swing never interrupts the player. Null = none.
var player_guard: ParryGuard = null
## Cast rhythm spec 2026-11-05 (fix): the hero's crit multiplier read when its swing STARTS ("cast while the foe is
## Frozen" crits): a Pin lasts 1.2 s and a 3-6 cell swing 0.95-1.7 s, so reading it at the hit missed almost every crit.
var _player_crit_at_start: float = 1.0
## Skill v2 (Ngàn Kiếm): Callable() -> bool, true while the PLAYER's Awakening (signature) is active; a scheduled card
## with `awakening_extra_hits` then gets that many more max hits for the cast (read when the swing resolves).
var player_awakening_fn: Callable = Callable()
## Skill v2 fix 2026-11-08 (interruption policy, catalog M02 / pattern D9): Callable() called ONCE per scheduled PLAYER
## cast at its FIRST damaging impact (not parried, not a parry card), so a pattern enemy's interruptible windup /
## warning is broken at that moment instead of at the cast's end. CombatView and the sim bind PatternController.on_enemy_hit;
## instant (legacy) casts keep calling it from swing_resolved. Invalid = none.
var pattern_hit_fn: Callable = Callable()
## EVALUATION SEAM (balance probe only; never set by the game): Callable(armed_cells: int, footprint_cells: int) -> int,
## the cell count an ARMED (delayed) event's damage uses instead of the cast's armed cells (damage-model experiments A4 /
## C, docs/skill-v2/13-hoa-loi-damage-models.md). Invalid = the approved rule (Model A: every armed cell counts).
var armed_damage_cells_fn: Callable = Callable()
## Skill v2 B1.5: the delivery timing table the `arrival` resolve reads (CombatConfig.delivery_timing; set by CombatView).
var delivery_timing: Dictionary = SkillDelivery.DEFAULT_TIMING
# The authoritative combat clock (seconds ticked), the pending impact events sorted by (at, seq) and the scheduled
# casts by id.
var _clock: float = 0.0
var _events: Array[Dictionary] = []
var _casts: Dictionary = {}
var _next_cast_id: int = 1
var _next_seq: int = 0


func _init(
	state: CombatState, grid: BoardGrid, player_actor: CutActor, boss_actor: CutActor,
	cut_config: CutConfig, skill_config: SkillConfig, status: StatusEffects = null
) -> void:
	_status = status
	_state = state
	_grid = grid
	_cut_config = cut_config
	_skill_config = skill_config
	_actors[CombatState.Side.PLAYER] = player_actor
	_actors[CombatState.Side.ENEMY] = boss_actor
	player_actor.swing_resolved.connect(_on_actor_resolved.bind(CombatState.Side.PLAYER))
	player_actor.swing_started.connect(_on_player_swing_started)
	boss_actor.swing_resolved.connect(_on_actor_resolved.bind(CombatState.Side.ENEMY))
	state.player_died.connect(_cancel_all)
	state.enemy_died.connect(_cancel_all)


## Advances both actors by [param delta] seconds in time order and resolves swings.
func tick(delta: float) -> void:
	if _state.is_player_dead() or _state.is_enemy_dead():
		_cancel_all()
		return
	if delta <= 0.0:
		return
	var remaining: float = delta
	while remaining > 0.0:
		var slice: float = remaining
		for side: int in _actors:
			var actor: CutActor = _actors[side] as CutActor
			if actor.is_swinging():
				slice = minf(slice, actor.get_time_left())
		if not _events.is_empty():
			slice = minf(slice, float(_events[0]["at"]) - _clock)
		slice = minf(maxf(slice, _MIN_SLICE_SEC), remaining)
		remaining -= slice
		_step(slice)
		if _state.is_player_dead() or _state.is_enemy_dead():
			_cancel_all()
			return


## Skill v2 B1.5: the authoritative combat clock, seconds ticked so far.
func clock() -> float:
	return _clock


## Skill v2 B1.5: the number of impact events still waiting on the clock.
func scheduled_count() -> int:
	return _events.size()


## Skill v2 (Trảm Địa, boss awareness): the cells of [param side]'s scheduled impact events that can still hit (their
## cast below max_hits, their wave not yet landed) and the seconds to the soonest of them on the clock:
## {cells: Array[Vector2i], time_left: float}; {} when none. The same authoritative schedule that resolves the damage.
func pending_cells(side: int) -> Dictionary:
	var cells: Array[Vector2i] = []
	var left: float = INF
	var armed: Array[Dictionary] = armed_threats(side)
	for e: Dictionary in _events:
		var cast: Dictionary = _casts.get(int(e["cast_id"]), {}) as Dictionary
		if cast.is_empty() or int(cast["side"]) != side or int(cast["hits"]) >= int(cast["max_hits"]) \
				or (cast["wave_hit"] as Dictionary).has(int(e["wave"])):
			continue
		# armed (delayed) events are reported apart, in `armed`: the brain weighs them by time left
		if bool(e.get("armed", false)):
			continue
		for c: Vector2i in e["cells"] as Array:
			if not cells.has(c):
				cells.append(c)
		left = minf(left, float(e["at"]) - _clock)
	if cells.is_empty():
		return {} if armed.is_empty() else {"armed": armed}
	var out: Dictionary = {"cells": cells, "time_left": maxf(left, 0.0)}
	if not armed.is_empty():
		out["armed"] = armed
	return out


## Skill v2 (Ngàn Kiếm root rule): the earliest `at` still on the clock (INF when nothing is scheduled). Read-only.
func first_event_at() -> float:
	var best: float = INF
	for e: Dictionary in _events:
		best = minf(best, float(e["at"]))
	return best


## Skill v2 (Ngàn Kiếm VFX): true while scheduled cast [param cast_id] still has events on the clock.
func has_cast(cast_id: int) -> bool:
	return _casts.has(cast_id)


## Skill v2 delayed (armed-zone registry): the cells of [param side]'s armed events still on the clock (sorted y, x).
func armed_cells(side: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e: Dictionary in _events:
		if not bool(e.get("armed", false)):
			continue
		var cast: Dictionary = _casts.get(int(e["cast_id"]), {}) as Dictionary
		if cast.is_empty() or int(cast["side"]) != side:
			continue
		for c: Vector2i in e["cells"] as Array:
			if not out.has(c):
				out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## Skill v2 delayed: the number of [param side]'s casts of [param skill_id] that still hold an armed event.
func armed_cast_count(side: int, skill_id: String) -> int:
	var ids: Dictionary = {}
	for e: Dictionary in _events:
		if not bool(e.get("armed", false)):
			continue
		var cast: Dictionary = _casts.get(int(e["cast_id"]), {}) as Dictionary
		if not cast.is_empty() and int(cast["side"]) == side and str(cast["skill_id"]) == skill_id:
			ids[int(e["cast_id"])] = true
	return ids.size()


## Skill v2 delayed (boss threat feed): [param side]'s armed events still on the clock, one entry per event:
## [{cast_id, skill_id, cells, time_left}], soonest first. The same schedule that resolves them.
func armed_threats(side: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _events:
		if not bool(e.get("armed", false)):
			continue
		var cast: Dictionary = _casts.get(int(e["cast_id"]), {}) as Dictionary
		if cast.is_empty() or int(cast["side"]) != side:
			continue
		var cells: Array[Vector2i] = []
		cells.assign(e["cells"])
		out.append({"cast_id": int(e["cast_id"]), "skill_id": str(cast["skill_id"]), "cells": cells,
			"time_left": maxf(float(e["at"]) - _clock, 0.0)})
	return out


## Skill v2 B1.5: the number of scheduled casts not finished yet.
func active_cast_count() -> int:
	return _casts.size()


## Skill v2 B1.5: drops every pending impact event (and its cast) of [param side], or of both sides when -1 (match end,
## a unit's death). Dropped casts emit nothing more.
func clear_scheduled(side: int = -1) -> void:
	var keep: Array[Dictionary] = []
	for e: Dictionary in _events:
		var cast: Dictionary = _casts.get(int(e["cast_id"]), {}) as Dictionary
		if side >= 0 and not cast.is_empty() and int(cast["side"]) != side:
			keep.append(e)
	_events = keep
	for id: Variant in _casts.keys():
		if side < 0 or int((_casts[id] as Dictionary)["side"]) == side:
			_casts.erase(id)


# Ticks both actors by one slice, then settles the swings that resolved in it.
func _step(slice: float) -> void:
	_clock += slice
	_pending.clear()
	for side: int in _actors:
		(_actors[side] as CutActor).tick(slice)
	# A single resolver whose opponent is within the tie window resolves it too (a trade).
	if _pending.size() == 1:
		var other: CutActor = _actors[_opposite(int(_pending[0]["side"]))] as CutActor
		if other.is_swinging() and other.get_time_left() <= TIE_EPSILON_SEC:
			other.tick(other.get_time_left() + _MIN_SLICE_SEC)
	var batch: Array[Dictionary] = _pending.duplicate()
	_pending.clear()
	var trade: bool = batch.size() > 1
	for entry: Dictionary in batch:
		_settle(int(entry["side"]), entry["cells"] as Array[Vector2i], str(entry["skill_id"]), trade, int(entry["level"]), entry["featured_bonus"] as Dictionary,
			entry.get("cast_context", {}) as Dictionary)
	_fire_due()


func _settle(side: int, cells: Array[Vector2i], skill_id: String, trade: bool, level: int = 1, featured_bonus: Dictionary = {},
		cast_context: Dictionary = {}) -> void:
	# Skill v2 B1 (docs/skill-v2/02-mechanics-catalog.md M02): the swing becomes an impact plan (CastResolver). An
	# `instant` card (all cards today) -> one wave of all its cells at t = 0 -> one CutEffects.apply exactly as before
	# (golden test). A scheduled card puts its events on the clock instead (B1.5).
	var locked: Array = []
	if _status != null:
		var open: Array[Vector2i] = _status.unlocked_cells(cells)
		for c: Vector2i in cells:
			if not open.has(c):
				locked.append(c)
	var plan: Dictionary = CastResolver.plan(_skill_config.get_skill(skill_id), cells, cast_context, delivery_timing, locked,
		armed_cells(side))
	if not bool(plan["legacy"]):
		_schedule_cast(side, cells, skill_id, trade, level, featured_bonus, cast_context, plan)
		return
	var waves: Array = plan["waves"] as Array
	var wave: Dictionary = waves[0] if not waves.is_empty() else {"wave": 0, "t": 0.0, "cells": cells, "kind": "hit", "mult": 1.0}
	var wave_cells: Array[Vector2i] = []
	wave_cells.assign(wave["cells"])
	var modifier: Callable = player_damage_modifier if side == CombatState.Side.PLAYER else Callable()
	var is_player: bool = side == CombatState.Side.PLAYER
	var result: Dictionary = CutEffects.apply(
		_state, _grid, side, wave_cells, skill_id, _cut_config, _skill_config, _status, modifier, level,
		player_cells_modifier if is_player else Callable(),
		player_signature_modifier if is_player else Callable(),
		{"target_defense": boss_defense + (_status.guard_amount(CombatState.Side.ENEMY) if _status != null else 0.0), "execute_ratio": execute_ratio, "featured_bonus": featured_bonus if is_player else {},
			"zones": zone_numbers, "target_blocked_fn": blocked_cell_fns.get(_opposite(side), Callable()),
			"relic_modifier": player_relic_modifier if is_player else Callable(),
			"zone_overrides": player_zone_overrides if is_player else {},
			"zone_sec_mult": float(player_zone_sec_mult_fn.call()) if (is_player and player_zone_sec_mult_fn.is_valid()) else 1.0,
			"extra_thorn_cells": int(player_extra_thorn_cells_fn.call()) if (is_player and player_extra_thorn_cells_fn.is_valid()) else 0,
			"zone_rng": zone_rng,
			"player_guard": player_guard if not is_player else null,
			"crit_mult_at_start": _player_crit_at_start if is_player else 1.0,
			"target_untargetable": is_player and enemy_untargetable_fn.is_valid() and bool(enemy_untargetable_fn.call()),
			"cast_context": cast_context})
	result["cells"] = cells
	result["cast_context"] = cast_context
	_lay_mire(side, cells, skill_id)
	wave_resolved.emit(side, wave, result)
	result["skill_id"] = skill_id
	result["level"] = level
	# Cast rhythm spec 2026-11-05: a parry card's own hit never cancels the enemy's attack it answers (else a parry could
	# not land on an interruptible skill); listeners skip PatternController.on_enemy_hit on it too.
	result["no_interrupt"] = is_player and _skill_config.is_parry_card(skill_id)
	swing_resolved.emit(side, result)
	if trade or not bool(result["hit"]) or bool(result.get("parried", false)) or bool(result["no_interrupt"]):
		return
	var victim_side: int = _opposite(side)
	var victim: CutActor = _actors[victim_side] as CutActor
	if victim.is_swinging():
		var victim_cells: Array[Vector2i] = victim.get_cells()
		var victim_skill: String = victim.get_skill_id()
		victim.cancel()
		swing_interrupted.emit(victim_side, victim_cells, victim_skill)


# Vũng Lầy: the whole mask becomes timed mire on the target half, hit or miss. Holes and the compact +1 s
# clause are not in this path (see docs/skill-v2/16-mvp-matrix.md).
func _lay_mire(side: int, cells: Array[Vector2i], skill_id: String) -> void:
	if tile_hazards == null:
		return
	var sec: float = float(_skill_config.get_skill(skill_id).get("mire_sec", 0.0))
	if sec <= 0.0:
		return
	tile_hazards.add_mire(_opposite(side), cells, sec)


func _on_actor_resolved(cells: Array[Vector2i], skill_id: String, side: int) -> void:
	var actor: CutActor = _actors[side] as CutActor
	# Story 028: a swing's featured bonus is consumed here (one-shot); the boss's swings never carry it.
	var bonus: Dictionary = actor.consume_featured_bonus()
	# B1.5: the context is frozen here, the cast-time snapshot every wave / event / listener reads.
	var ctx: Dictionary = CastContext.freeze(actor.consume_cast_context())
	if side != CombatState.Side.PLAYER:
		bonus = {}
	_pending.append({"side": side, "cells": cells, "skill_id": skill_id, "level": actor.get_level(), "featured_bonus": bonus,
		"cast_context": ctx})


# Snapshots the crit condition of the hero's swing as it starts (CritRules on the target as it is now).
func _on_player_swing_started(_cells: Array[Vector2i], skill_id: String, _duration: float) -> void:
	_player_crit_at_start = CritRules.mult_for(_skill_config.get_skill(skill_id),
		{"state": _state, "status": _status, "target_side": CombatState.Side.ENEMY})


func _cancel_all() -> void:
	for side: int in _actors:
		(_actors[side] as CutActor).cancel()
	clear_scheduled()


# Skill v2 B1.5: records a scheduled cast and puts its events on the clock (at = now + event t). The heal_self of the
# card happens now, once (the swing landed), as on the legacy path.
func _schedule_cast(side: int, cells: Array[Vector2i], skill_id: String, trade: bool, level: int, featured_bonus: Dictionary,
		cast_context: Dictionary, plan: Dictionary) -> void:
	var is_player: bool = side == CombatState.Side.PLAYER
	var count: int = (_status.unlocked_cells(cells) if _status != null else cells).size()
	# a delayed cast counts only the cells it armed (skipped / locked cells deal nothing)
	if plan.has("cast_cells"):
		count = int(plan["cast_cells"])
	var skill: Dictionary = CutEffects.resolved_skill(_skill_config, skill_id, level)
	var id: int = _next_cast_id
	_next_cast_id += 1
	var wave_left: Dictionary = {}
	for e: Dictionary in plan["events"]:
		wave_left[int(e["wave"])] = int(wave_left.get(int(e["wave"]), 0)) + 1
	var waves: Dictionary = {}
	for w: Dictionary in plan["waves"]:
		waves[int(w["wave"])] = w
	_casts[id] = {"id": id, "side": side, "skill_id": skill_id, "level": level, "cells": cells.duplicate(), "trade": trade,
		"featured_bonus": featured_bonus if is_player else {}, "context": cast_context, "cast_cells": count,
		"max_hits": int(plan["max_hits"]) + _awakening_extra(is_player, skill), "hits": 0, "wave_hit": {}, "wave_left": wave_left, "waves": waves,
		"events_left": (plan["events"] as Array).size(), "damage": 0.0, "interrupted": false, "last_hit": {},
		"crit_at_start": _player_crit_at_start if is_player else 1.0,
		"healed": CutEffects.heal_caster(_state, side, skill), "fizzled": bool(plan.get("fizzled", false)),
		"skipped_cells": plan.get("skipped_cells", [])}
	for e: Dictionary in plan["events"]:
		var ev: Dictionary = e.duplicate()
		ev["cast_id"] = id
		ev["at"] = _clock + float(e["t"])
		ev["seq"] = _next_seq
		_next_seq += 1
		_events.append(ev)
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["at"]) - float(b["at"])) > 0.0000001:
			return float(a["at"]) < float(b["at"])
		return int(a["seq"]) < int(b["seq"]))
	var listed: Array[Dictionary] = []
	for e: Dictionary in _events:
		if int(e["cast_id"]) == id:
			var pub: Dictionary = e.duplicate()
			pub.erase("seq")
			listed.append(pub)
	var info: Dictionary = {"cast_id": id, "side": side, "skill_id": skill_id, "cells": cells.duplicate(),
		"events": listed, "context": cast_context}
	for k: String in ["fizzled", "skipped_cells", "fuse_sec", "fuse_mult", "clause"]:
		if plan.has(k):
			info[k] = plan[k]
	cast_scheduled.emit(side, info)
	if (plan["events"] as Array).is_empty():
		_finish_cast(id)


# Ngàn Kiếm: the extra max hits of an active Awakening for the player's card (0 otherwise).
func _awakening_extra(is_player: bool, skill: Dictionary) -> int:
	var extra: int = int(skill.get("awakening_extra_hits", 0))
	if not is_player or extra <= 0 or not player_awakening_fn.is_valid():
		return 0
	return extra if bool(player_awakening_fn.call()) else 0


# Fires every event due by now (at <= clock + tie window), in order. Stops when a unit dies.
func _fire_due() -> void:
	while not _events.is_empty() and float(_events[0]["at"]) <= _clock + TIE_EPSILON_SEC:
		if _state.is_player_dead() or _state.is_enemy_dead():
			return
		var ev: Dictionary = _events.pop_front()
		_fire_event(ev)


func _fire_event(ev: Dictionary) -> void:
	var id: int = int(ev["cast_id"])
	if not _casts.has(id):
		return
	var cast: Dictionary = _casts[id]
	var side: int = int(cast["side"])
	var is_player: bool = side == CombatState.Side.PLAYER
	var wave: int = int(ev["wave"])
	var ev_cells: Array[Vector2i] = []
	ev_cells.assign(ev["cells"])
	# delayed: cells locked since the cast fizzle (no damage, no payload there)
	if bool(ev.get("recheck_locked", false)) and _status != null:
		var open: Array[Vector2i] = _status.unlocked_cells(ev_cells)
		var gone: Array[Vector2i] = []
		for c: Vector2i in ev_cells:
			if not open.has(c):
				gone.append(c)
		if not gone.is_empty():
			ev["fizzled_cells"] = gone
		ev_cells = open
		ev["cells"] = open
	var hit: bool = false
	var can_hit: bool = int(cast["hits"]) < int(cast["max_hits"]) and not (cast["wave_hit"] as Dictionary).has(wave)
	if can_hit and not ev_cells.is_empty() and _state.unit_in(_opposite(side), ev_cells):
		var skill_id: String = str(cast["skill_id"])
		# the card's damage-cell rule (CastResolver.damage_cells: "all" for every card but those that set one, e.g.
		# Hỏa Lôi's Model C), on the target's footprint now; the evaluation seam, when a probe sets it, overrides it
		var fp: int = _state.enemy_footprint_cells().size() if is_player else 1
		var dmg_cells: int = CastResolver.damage_cells(_skill_config.get_skill(skill_id), int(cast["cast_cells"]), fp)
		if bool(ev.get("armed", false)) and armed_damage_cells_fn.is_valid():
			dmg_cells = maxi(int(armed_damage_cells_fn.call(int(cast["cast_cells"]), fp)), 1)
		var result: Dictionary = CutEffects.apply(
			_state, _grid, side, ev_cells, skill_id, _cut_config, _skill_config, _status,
			player_damage_modifier if is_player else Callable(), int(cast["level"]),
			player_cells_modifier if is_player else Callable(),
			player_signature_modifier if is_player else Callable(),
			{"target_defense": boss_defense + (_status.guard_amount(CombatState.Side.ENEMY) if _status != null else 0.0),
				"execute_ratio": execute_ratio, "featured_bonus": cast["featured_bonus"],
				"zones": zone_numbers, "target_blocked_fn": blocked_cell_fns.get(_opposite(side), Callable()),
				"relic_modifier": player_relic_modifier if is_player else Callable(),
				"player_guard": player_guard if not is_player else null,
				"crit_mult_at_start": float(cast["crit_at_start"]),
				"target_untargetable": is_player and enemy_untargetable_fn.is_valid() and bool(enemy_untargetable_fn.call()),
				"cast_context": cast["context"], "cast_cell_count": dmg_cells, "wave_index": wave,
				"impact_mult": float(ev["mult"]), "apply_heal": false})
		hit = bool(result["hit"])
		# Trảm Địa: the burst's Pin lands with a damaging hit (not on a parry).
		if hit and float(ev.get("pin_sec", 0.0)) > 0.0 and _status != null and not bool(result.get("parried", false)):
			_status.pin(_opposite(side), float(ev["pin_sec"]))
			result["pinned"] = true
		ev["damage"] = float(result.get("damage", 0.0))
		ev["target_cell"] = result.get("cell", Vector2i(-1, -1))
		ev["crit"] = bool(result.get("crit", false))
		ev["pinned"] = bool(result.get("pinned", false))
		ev["parried"] = bool(result.get("parried", false))
		if hit:
			cast["hits"] = int(cast["hits"]) + 1
			(cast["wave_hit"] as Dictionary)[wave] = true
			cast["damage"] = float(cast["damage"]) + float(result.get("damage", 0.0))
			cast["last_hit"] = result
			if is_player and not bool(cast.get("pattern_hit", false)) and not bool(result.get("parried", false)) 					and not _skill_config.is_parry_card(skill_id) and pattern_hit_fn.is_valid():
				cast["pattern_hit"] = true
				pattern_hit_fn.call()
			var at_zero: bool = float(ev["t"]) <= TIE_EPSILON_SEC
			var may_interrupt: bool = not bool(cast["interrupted"]) and not (bool(cast["trade"]) and at_zero)
			may_interrupt = may_interrupt and not bool(result.get("parried", false))
			may_interrupt = may_interrupt and not (is_player and _skill_config.is_parry_card(skill_id))
			if may_interrupt:
				cast["interrupted"] = true
				var victim_side: int = _opposite(side)
				var victim: CutActor = _actors[victim_side] as CutActor
				if victim.is_swinging():
					var victim_cells: Array[Vector2i] = victim.get_cells()
					var victim_skill: String = victim.get_skill_id()
					victim.cancel()
					swing_interrupted.emit(victim_side, victim_cells, victim_skill)
	# the event's payload lands on its open cells after the damage (hit or miss); a burn on the target's cell now does
	# not pay an entry tick for this hit (StatusEffects ticks it from the next tick)
	var payload: Dictionary = ev.get("payload", {}) as Dictionary
	if not payload.is_empty() and _status != null and not ev_cells.is_empty() and not _state.is_player_dead() \
			and not _state.is_enemy_dead():
		var ig: Dictionary = payload.get("ignite", {}) as Dictionary
		if not ig.is_empty():
			ev["ignited"] = _status.ignite(ev_cells, float(ig["sec"]), float(ig["tick_sec"]), float(ig["damage"]))
	# Batch 1 (Mìn Trễ): a `push` payload moves the target away from the cast mask's centre on a damaging hit only.
	var push: Dictionary = payload.get("push", {}) as Dictionary
	if hit and not push.is_empty() and not bool(ev.get("parried", false)) and not _state.is_player_dead() \
			and not _state.is_enemy_dead():
		var mask: Array[Vector2i] = []
		mask.assign(cast["cells"])
		var centre: Vector2i = ShapeTags.tags_for(mask)["centre"]
		ev["pushed"] = CutEffects.push_from(_state, _grid, _opposite(side), centre, int(push["cells"]),
			blocked_cell_fns.get(_opposite(side), Callable()))
		ev["push_from"] = centre
		(cast["last_hit"] as Dictionary)["pushed"] = bool(ev["pushed"])
	var public: Dictionary = ev.duplicate()
	public.erase("seq")
	public["context"] = cast["context"]
	public["skill_id"] = cast["skill_id"]
	impact_resolved.emit(side, public, hit)
	if not _casts.has(id):
		return
	var left: Dictionary = cast["wave_left"]
	left[wave] = int(left[wave]) - 1
	if int(left[wave]) <= 0:
		var w: Dictionary = (cast["waves"] as Dictionary).get(wave, {}) as Dictionary
		wave_resolved.emit(side, w, {"hit": (cast["wave_hit"] as Dictionary).has(wave), "cast_context": cast["context"],
			"cells": cast["cells"], "skill_id": cast["skill_id"]})
	cast["events_left"] = int(cast["events_left"]) - 1
	if int(cast["events_left"]) <= 0:
		_finish_cast(id)


# The card-level result of a scheduled cast, once its last event fired: swing_resolved with hit = any event damaged
# the target and damage = their sum (listeners see one outcome per cast, as for an instant card).
func _finish_cast(id: int) -> void:
	var cast: Dictionary = _casts.get(id, {}) as Dictionary
	if cast.is_empty():
		return
	_casts.erase(id)
	var side: int = int(cast["side"])
	var last: Dictionary = cast["last_hit"] as Dictionary
	var result: Dictionary = last.duplicate()
	if last.is_empty():
		result = {"hit": false, "damage": 0.0, "pushed": false, "cell": _state.cell_of(_opposite(side)),
			"burning": false, "pinned": false}
	result["hit"] = int(cast["hits"]) > 0
	result["damage"] = float(cast["damage"])
	result["hits"] = int(cast["hits"])
	result["healed"] = float(cast["healed"])
	result["scheduled"] = true
	result["fizzled"] = bool(cast.get("fizzled", false))
	result["skipped_cells"] = cast.get("skipped_cells", [])
	result["cells"] = cast["cells"]
	result["cast_context"] = cast["context"]
	result["skill_id"] = cast["skill_id"]
	result["level"] = cast["level"]
	result["no_interrupt"] = side == CombatState.Side.PLAYER and _skill_config.is_parry_card(str(cast["skill_id"]))
	swing_resolved.emit(side, result)


func _opposite(side: int) -> int:
	return CombatState.Side.ENEMY if side == CombatState.Side.PLAYER else CombatState.Side.PLAYER

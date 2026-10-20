class_name BossBrain
extends RefCounted
## The boss's decision maker: a weighted-score brain (weights in boss_brain.json), pure logic.
## It never touches the world: [method decide] reads the objects in its context and returns
## an action the controller applies ({"type":"wait"}, {"type":"move","direction":Vector2i},
## {"type":"cut","hand_indices":Array[int],"skill_id":String}).
##
## CUTS: candidates are every ORDERED selection of 1..min(4, hand_max_points, points in hand)
## points (order = connection order, so A-B-C differs from C-B-A); a full 4-point hand gives
## 4 + 12 + 24 + 24 = 64 candidates. Covered cells are cached by label sequence.
## Cut score = per_cell*cells + hit_now(player cell covered)
## + escape_penalty / (1 + escape cells: cells the player can still reach during the wind-up
## that the cut does not cover, see EscapeAnalysis) - duration_penalty*windup
## - point_cost*points - hand_wait(points < hand_target while the hand is not full)
## + interrupt bonus + skill bonus + noise (the file-level `noise`).
##
## MOVEMENT (Story 013): the brain keeps ONE destination {cell, purpose} (purpose: pickup /
## dodge / retreat / wander) and walks one step per decision toward it along the set's
## path_style (row_first, shortest, or a per-destination coin between row_first and
## column_first for mixed). The destination is dropped at once when it stops making sense
## (point gone, cell burning, unreachable, reached) and otherwise re-evaluated only with
## probability 1 - move_commitment. A visible player swing on the current cell or on the next
## cell of the path always forces a dodge to the nearest safe cell, followed by an optional
## perpendicular juke. Burning or missing cells are never entered (BFS routes around them).
## Movement consumes RNG only for move_noise, the commitment roll (skipped at 0 and 1), the
## juke roll (skipped at 0 and 1), the mixed-style coin and the wander pick; the cautious
## profile (commitment 1, noise 0, row_first, juke 0, no wander) therefore moves identically
## whatever the seed. Best of cut / move / wait wins.
## Implements: Story 009, Story 013 (Parts 1 and 2).

## Destination purposes reported by [method get_destination].
const PURPOSE_PICKUP: String = "pickup"
const PURPOSE_DODGE: String = "dodge"
const PURPOSE_RETREAT: String = "retreat"
const PURPOSE_WANDER: String = "wander"
## Path styles actually walked (a set's "mixed" resolves to one of the first two per destination).
const STYLE_ROW_FIRST: String = "row_first"
const STYLE_COLUMN_FIRST: String = "column_first"
const STYLE_SHORTEST: String = "shortest"

const _DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const _MAX_POINTS: int = 4
## Added to the seed for the combo roll so it never shares a stream with the score noise.
const _COMBO_SEED_OFFSET: int = 104729
## Floor for the time left used to scale danger urgency.
const _MIN_TIME_LEFT: float = 0.1

var _config: BossBrainConfig
var _grid: BoardGrid
var _cut_config: CutConfig
var _skill_config: SkillConfig
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _weights: Dictionary = {}
var _movement: Dictionary = {}
var _reaction_sec: float = 0.0
var _set_name: String = ""
var _think_clock: float = 0.0
var _player_seen_sec: float = 0.0
var _cell_cache: Dictionary = {}
var _combo_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _debug: Dictionary = {}
var _cut_candidates: Array[Dictionary] = []
var _status: StatusEffects = null
var _learning: BossLearning = null
## Current destination: {cell, purpose, path_style_in_use, target_uid (pickup), from_cell and
## juke (dodge)}; empty when the boss has nowhere to go.
var _destination: Dictionary = {}


## [param seed_value] below 0 gives a random seed; otherwise noise is deterministic.
func _init(
	config: BossBrainConfig, grid: BoardGrid, cut_config: CutConfig, skill_config: SkillConfig, seed_value: int = -1
) -> void:
	_config = config
	_grid = grid
	_cut_config = cut_config
	_skill_config = skill_config
	if seed_value >= 0:
		_rng.seed = seed_value
		_combo_rng.seed = seed_value + _COMBO_SEED_OFFSET
	else:
		_rng.randomize()
		_combo_rng.randomize()
	use_set(config.active_set)
	_debug = {"type": "wait", "reason": "not_decided", "score": 0.0, "set": _set_name, "destination": {}}


## Switches the weight set (and its movement profile; the current destination is dropped).
## Returns false (nothing changes) when the name is unknown.
func use_set(set_name: String) -> bool:
	if not _config.has_set(set_name):
		if _weights.is_empty():
			_set_name = _config.active_set
			_weights = _config.weights_for("")
			_movement = _config.movement_for("")
			_reaction_sec = _config.reaction_sec_for("")
		return false
	_weights = _config.weights_for(set_name)
	_movement = _config.movement_for(set_name)
	_reaction_sec = _config.reaction_sec_for(set_name)
	_set_name = set_name
	_destination = {}
	return true


## Sets (or clears with null) the learning counters whose modifiers scale cut scores.
func set_learning(learning: BossLearning) -> void:
	_learning = learning


## The learning counters in use (null = none).
func get_learning() -> BossLearning:
	return _learning


## Name of the weight set in use.
func get_set_name() -> String:
	return _set_name


## Seconds between a combo's two impacts in the weight set in use (before the controller's floor).
func get_combo_gap_sec() -> float:
	return float(_weights.get("combo_gap_sec", 0.5))


## Reaction time in use (the set's own, or the file-level default).
func get_reaction_sec() -> float:
	return _reaction_sec


## Copy of the movement profile in use (keys of BossBrainConfig.DEFAULT_MOVEMENT).
func get_movement_profile() -> Dictionary:
	return _movement.duplicate()


## Where the boss is walking: {cell, purpose, path_style_in_use}, or empty when idle.
func get_destination() -> Dictionary:
	if _destination.is_empty():
		return {}
	return {
		"cell": _destination["cell"], "purpose": str(_destination["purpose"]),
		"path_style_in_use": str(_destination["path_style_in_use"]),
	}


## Advances the brain's clocks. [param player_swing_active] is whether the player has a swing
## running right now; the time it has been visible resets when it ends.
func tick(delta: float, player_swing_active: bool) -> void:
	_think_clock += delta
	if player_swing_active:
		_player_seen_sec += delta
	else:
		_player_seen_sec = 0.0


## Chooses the next action. [param ctx] holds the live objects: state (CombatState),
## hand (HoldSlots, boss), drops (FieldDrops, boss), mover (UnitMover), actor (CutActor,
## boss), cooldowns (SkillCooldowns, boss), player_actor (CutActor), optional status
## (StatusEffects: burning cells are never entered or targeted), optional
## player_step_cooldown (float seconds, the player's board-scaled step cooldown used to count
## escape cells; absent = the boss's own step cooldown). Returns a wait until
## think_interval_sec has elapsed, and always while either side is dead.
func decide(ctx: Dictionary) -> Dictionary:
	var state: CombatState = ctx.get("state") as CombatState
	var hand: HoldSlots = ctx.get("hand") as HoldSlots
	var drops: FieldDrops = ctx.get("drops") as FieldDrops
	var mover: UnitMover = ctx.get("mover") as UnitMover
	var actor: CutActor = ctx.get("actor") as CutActor
	var cooldowns: SkillCooldowns = ctx.get("cooldowns") as SkillCooldowns
	var player_actor: CutActor = ctx.get("player_actor") as CutActor
	_status = ctx.get("status") as StatusEffects
	if state == null or hand == null or drops == null or mover == null or actor == null \
			or cooldowns == null or player_actor == null:
		return _finish_wait("bad_context", 0.0)
	if state.is_enemy_dead() or state.is_player_dead():
		return _finish_wait("dead", 0.0)
	if _think_clock < _config.think_interval_sec:
		return _finish_wait("thinking", 0.0)
	_think_clock = 0.0

	var incoming: Array[Vector2i] = _visible_incoming(player_actor)
	var burning: Array[Vector2i] = []
	if _status != null:
		burning = _status.burning_cells()
	var urgency: float = 1.0 / maxf(player_actor.get_time_left(), _MIN_TIME_LEFT)
	var player_step_cooldown: float = float(ctx.get("player_step_cooldown", _config.step_cooldown_sec))
	var idle_score: float = float(_weights["idle_bias"])
	var best_cut: Dictionary = _best_cut(
		state, hand, actor, cooldowns, player_actor, incoming, burning, player_step_cooldown
	)
	var best_move: Dictionary = _plan_move(state, hand, drops, incoming, burning, urgency, mover.is_ready())

	var choice: Dictionary = {"type": "wait", "score": idle_score, "breakdown": {"idle_bias": idle_score}}
	if not best_move.is_empty() and float(best_move["score"]) >= float(choice["score"]):
		choice = best_move
	if not best_cut.is_empty() and float(best_cut["score"]) > float(choice["score"]):
		choice = best_cut
	_debug = choice.duplicate()
	_debug["set"] = _set_name
	_debug["reason"] = "chosen"
	_debug["destination"] = get_destination()
	_debug["cut_candidates"] = _cut_candidates.duplicate()
	_debug["alternatives"] = {
		"cut": float(best_cut["score"]) if not best_cut.is_empty() else null,
		"move": float(best_move["score"]) if not best_move.is_empty() else null,
		"wait": idle_score,
	}
	var type: String = str(choice["type"])
	if type == "cut":
		var cut_action: Dictionary = {"type": "cut", "hand_indices": choice["hand_indices"], "skill_id": choice["skill_id"]}
		var combo: Dictionary = _choose_combo(
			state, hand, choice, burning, player_step_cooldown, _swing_mult(actor)
		)
		if not combo.is_empty():
			cut_action["combo"] = {"hand_indices": combo["hand_indices"], "skill_id": combo["skill_id"]}
			_debug["combo"] = combo
		return cut_action
	if type == "move":
		return {"type": "move", "direction": choice["direction"]}
	return {"type": "wait"}


## Score breakdown of the last decision: {type, score, set, reason, breakdown, alternatives,
## destination {cell, purpose, path_style_in_use} (empty = idle), cut_candidates (every scored
## cut: {labels, score, escape, escape_term, hit_now}), and for cuts hand_indices / skill_id /
## labels / cells / escape, for moves direction / purpose}.
func last_debug() -> Dictionary:
	return _debug.duplicate(true)


# The boss actor's swing duration multiplier (1.0 when the actor has none).
func _swing_mult(actor: CutActor) -> float:
	return actor.duration_mult


# Second cut of a combo, or empty. Rolls combo_chance (own seeded stream, skipped at 0 and 1),
# then scores every ordered selection of the points left in hand ONLY by how many of the first
# cut's escape cells (where the player can stand when swing 1 lands) it covers; ties: fewer
# points, then fewer cells. Needs >= 1 covered escape cell. Combos always use slash.
func _choose_combo(
	state: CombatState, hand: HoldSlots, first: Dictionary, burning: Array[Vector2i],
	player_step_cooldown: float, duration_mult: float
) -> Dictionary:
	var chance: float = float(_weights.get("combo_chance", 0.0))
	if chance <= 0.0:
		return {}
	var used: Array[int] = []
	used.assign(first["hand_indices"] as Array)
	var pool: Array[int] = []
	for i: int in hand.get_slot_count():
		if hand.get_point(i) != null and not used.has(i):
			pool.append(i)
	if pool.is_empty():
		return {}
	if chance < 1.0 and _combo_rng.randf() >= chance:
		return {}
	var cells1: Array[Vector2i] = first["cells"] as Array[Vector2i]
	var steps1: int = EscapeAnalysis.steps_for_swing(_cut_config.swing_duration(cells1.size()) * duration_mult, player_step_cooldown)
	var escape_before: Array[Vector2i] = EscapeAnalysis.escape_cells(_grid, state.player_cell, steps1, true, cells1, burning)
	var selections: Array = []
	_collect_selections(pool, mini(mini(_MAX_POINTS, _cut_config.hand_max_points), pool.size()), [] as Array[int], selections)
	var best: Dictionary = {}
	for selection_variant: Variant in selections:
		var selection: Array[int] = []
		selection.assign(selection_variant as Array)
		var labels: Array[String] = []
		for index: int in selection:
			labels.append(hand.get_point(index).label)
		var cells2: Array[Vector2i] = _cells_for(labels)
		if cells2.is_empty():
			continue
		var covered: int = 0
		for cell: Vector2i in escape_before:
			if cells2.has(cell):
				covered += 1
		if covered < 1:
			continue
		if not best.is_empty():
			var better: bool = covered > int(best["covered"])
			if covered == int(best["covered"]):
				better = selection.size() < (best["hand_indices"] as Array).size() \
					or (selection.size() == (best["hand_indices"] as Array).size() and cells2.size() < (best["cells"] as Array).size())
			if not better:
				continue
		best = {
			"hand_indices": selection, "skill_id": "slash", "labels": labels, "cells": cells2,
			"covered": covered, "escape_before": escape_before.size(), "escape_after": escape_before.size() - covered,
		}
	return best


func _finish_wait(reason: String, score: float) -> Dictionary:
	_debug = {"type": "wait", "reason": reason, "score": score, "set": _set_name, "destination": get_destination()}
	return {"type": "wait"}


# Cells of the player's swing once the brain has seen it for the set's reaction time, else empty.
func _visible_incoming(player_actor: CutActor) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not player_actor.is_swinging() or not player_actor.targets_enemy():
		return none
	var elapsed: float = player_actor.get_duration() - player_actor.get_time_left()
	if minf(_player_seen_sec, elapsed) < _reaction_sec:
		return none
	return player_actor.get_cells()


# ---------------------------------------------------------------- cuts


func _best_cut(
	state: CombatState, hand: HoldSlots, actor: CutActor, cooldowns: SkillCooldowns,
	player_actor: CutActor, incoming: Array[Vector2i], burning: Array[Vector2i], player_step_cooldown: float
) -> Dictionary:
	var best: Dictionary = {}
	_cut_candidates = []
	if not actor.can_begin():
		return best
	var occupied: Array[int] = []
	for i: int in hand.get_slot_count():
		if hand.get_point(i) != null:
			occupied.append(i)
	if occupied.is_empty():
		return best
	var max_points: int = mini(mini(_MAX_POINTS, _cut_config.hand_max_points), occupied.size())
	var selections: Array = []
	_collect_selections(occupied, max_points, [] as Array[int], selections)
	var hand_full: bool = hand.is_full()
	var hand_target: int = int(_weights["hand_target"])
	var mods: Dictionary = {} if _learning == null else _learning.get_modifiers()
	var quick_bias: float = float(mods.get("quick_cut_bias", 1.0))
	var single_bonus: float = float(mods.get("single_point_bonus", 0.0))
	var escape_penalty: float = float(_weights["escape_penalty"])
	var duration_mult: float = _swing_mult(actor)
	for selection_variant: Variant in selections:
		var selection: Array[int] = []
		selection.assign(selection_variant as Array)
		var labels: Array[String] = []
		for index: int in selection:
			labels.append(hand.get_point(index).label)
		var cells: Array[Vector2i] = _cells_for(labels)
		if cells.is_empty():
			continue
		var count: int = cells.size()
		var duration: float = _cut_config.swing_duration(count) * duration_mult
		var hits_now: bool = cells.has(state.player_cell)
		var steps: int = EscapeAnalysis.steps_for_swing(duration, player_step_cooldown)
		var escape: int = EscapeAnalysis.escape_cells(_grid, state.player_cell, steps, true, cells, burning).size()
		var parts: Dictionary = {}
		parts["cells"] = float(_weights["cut_per_cell"]) * float(count)
		parts["hit_now"] = float(_weights["cut_hit_now"]) if hits_now else 0.0
		parts["escape"] = escape_penalty / (1.0 + float(escape))
		parts["duration"] = -float(_weights["cut_duration_penalty"]) * quick_bias * duration
		parts["single_point"] = single_bonus if selection.size() == 1 else 0.0
		parts["points"] = -float(_weights["cut_point_cost"]) * float(selection.size())
		parts["hand_wait"] = 0.0
		if selection.size() < hand_target and not hand_full:
			parts["hand_wait"] = -float(_weights["cut_hand_wait"])
		parts["interrupt"] = 0.0
		if player_actor.is_swinging() and not incoming.is_empty() and hits_now \
				and duration < player_actor.get_time_left():
			parts["interrupt"] = float(_weights["cut_interrupt_bonus"])
		var skill_id: String = _choose_skill(cooldowns, count)
		parts["skill"] = float(_weights.get(BossBrainConfig.SKILL_BONUS_PREFIX + skill_id, 0.0))
		parts["noise"] = _noise()
		var score: float = 0.0
		for value: Variant in parts.values():
			score += float(value)
		_cut_candidates.append({
			"labels": ",".join(labels), "score": score, "escape": escape,
			"escape_term": float(parts["escape"]), "hit_now": hits_now,
		})
		if score < float(_weights["min_cut_score"]):
			continue
		if best.is_empty() or score > float(best["score"]):
			best = {
				"type": "cut", "score": score, "hand_indices": selection, "skill_id": skill_id,
				"labels": labels, "cells": cells, "escape": escape, "breakdown": parts,
			}
	return best


# Appends every ordered selection of 1..max_points items of pool to out.
func _collect_selections(pool: Array[int], max_points: int, chosen: Array[int], out: Array) -> void:
	for index: int in pool:
		if chosen.has(index):
			continue
		chosen.append(index)
		out.append(chosen.duplicate())
		if chosen.size() < max_points:
			_collect_selections(pool, max_points, chosen, out)
		chosen.pop_back()


func _cells_for(labels: Array[String]) -> Array[Vector2i]:
	var key: String = ",".join(labels)
	if not _cell_cache.has(key):
		_cell_cache[key] = CutResolver.resolve_on_board(_grid, false, labels)
	var cached: Array[Vector2i] = _cell_cache[key]
	return cached


# Highest-preference available skill for [param cell_count]: slash has preference 0, any other
# skill its skill_bonus_<id> weight; ties keep the earlier skill in menu order.
func _choose_skill(cooldowns: SkillCooldowns, cell_count: int) -> String:
	var best_id: String = ""
	var best_bonus: float = -INF
	for skill_id: String in _skill_config.skill_order:
		var check: Dictionary = SkillAvailability.check(_skill_config, cooldowns, skill_id, cell_count)
		if not bool(check["available"]):
			continue
		var bonus: float = float(_weights.get(BossBrainConfig.SKILL_BONUS_PREFIX + skill_id, 0.0))
		if bonus > best_bonus:
			best_bonus = bonus
			best_id = skill_id
	if best_id.is_empty():
		return SkillConfig.FALLBACK_SKILL
	return best_id


func _noise() -> float:
	if _config.noise <= 0.0:
		return 0.0
	return _rng.randf_range(-_config.noise, _config.noise)


# ---------------------------------------------------------------- movement


# Maintains the destination (every think, so invalidation never waits for the step cooldown)
# and returns the one step toward it when [param can_step] ({} = no move this think).
func _plan_move(
	state: CombatState, hand: HoldSlots, drops: FieldDrops, incoming: Array[Vector2i],
	burning: Array[Vector2i], urgency: float, can_step: bool
) -> Dictionary:
	var here: Vector2i = state.enemy_cell
	var points: Array[FieldPoint] = drops.get_points()
	# 1. Arrival and invalidation of the current destination.
	if not _destination.is_empty():
		if _destination["cell"] == here:
			_arrive(here, incoming, burning)
		elif _destination_invalid(points, incoming, burning):
			_destination = {}
	# 2. Choose a destination, or re-evaluate the current one with probability 1 - commitment.
	if not _is_dodging() and (_destination.is_empty() or _rolls_re_evaluation()):
		_choose_destination(here, state, hand, points, incoming, burning)
	# 3. A visible swing on the current cell or on the next cell of the path forces a dodge.
	var threatened: bool = incoming.has(here)
	if not threatened and not _destination.is_empty() and not _is_dodging():
		var next_dir: Vector2i = _step_toward(here, _destination["cell"], str(_destination["path_style_in_use"]), burning)
		if next_dir == Vector2i.ZERO:
			_destination = {}
		elif incoming.has(here + next_dir):
			threatened = true
	if threatened and not _is_dodging():
		_set_dodge(here, incoming, burning)
	# 4. One step.
	if not can_step or _destination.is_empty() or _destination["cell"] == here:
		return {}
	var direction: Vector2i = _step_toward(here, _destination["cell"], str(_destination["path_style_in_use"]), burning)
	if direction == Vector2i.ZERO:
		_destination = {}
		return {}
	var purpose: String = str(_destination["purpose"])
	var base: float = _purpose_score(purpose, here, incoming, urgency)
	var noise: float = _move_noise()
	return {
		"type": "move", "score": base + noise, "direction": direction, "purpose": purpose,
		"breakdown": {purpose: base, "noise": noise},
	}


func _is_dodging() -> bool:
	return not _destination.is_empty() and str(_destination["purpose"]) == PURPOSE_DODGE


# True with probability 1 - move_commitment; consumes no RNG at commitment 0 or 1.
func _rolls_re_evaluation() -> bool:
	var commitment: float = float(_movement["move_commitment"])
	if commitment >= 1.0:
		return false
	if commitment <= 0.0:
		return true
	return _rng.randf() >= commitment


# True when the current destination no longer makes sense.
func _destination_invalid(points: Array[FieldPoint], incoming: Array[Vector2i], burning: Array[Vector2i]) -> bool:
	var cell: Vector2i = _destination["cell"]
	if not _grid.is_enemy_cell(cell) or burning.has(cell):
		return true
	var purpose: String = str(_destination["purpose"])
	if purpose == PURPOSE_PICKUP:
		var uid: int = int(_destination["target_uid"])
		for point: FieldPoint in points:
			if point.uid == uid and point.cell == cell:
				return false
		return true
	if purpose == PURPOSE_DODGE:
		if incoming.has(cell):
			return true
		return incoming.is_empty() and not bool(_destination.get("juke", false))
	return false


# The destination was reached: drop it; after a dodge, maybe juke one cell sideways.
func _arrive(here: Vector2i, incoming: Array[Vector2i], burning: Array[Vector2i]) -> void:
	var done: Dictionary = _destination
	_destination = {}
	if str(done["purpose"]) != PURPOSE_DODGE or bool(done.get("juke", false)):
		return
	var chance: float = float(_movement["juke_chance"])
	if chance <= 0.0:
		return
	if chance < 1.0 and _rng.randf() >= chance:
		return
	var delta: Vector2i = here - (done["from_cell"] as Vector2i)
	if delta == Vector2i.ZERO:
		return
	var perpendicular: Array[Vector2i] = []
	if absi(delta.x) >= absi(delta.y):
		perpendicular = [Vector2i(0, -1), Vector2i(0, 1)]
	else:
		perpendicular = [Vector2i(-1, 0), Vector2i(1, 0)]
	var best: Vector2i = here
	var best_key: Array = []
	for dir: Vector2i in perpendicular:
		var cell: Vector2i = here + dir
		if not _grid.is_enemy_cell(cell) or burning.has(cell) or incoming.has(cell):
			continue
		var key: Array = [-_grid.to_side_coords(cell).x, cell.y]
		if best == here or _key_less(key, best_key):
			best = cell
			best_key = key
	if best == here:
		return
	_destination = {
		"cell": best, "purpose": PURPOSE_DODGE, "path_style_in_use": str(done["path_style_in_use"]),
		"from_cell": here, "juke": true,
	}


# Picks the best pickup (noisy score), else a retreat column when hurt, else a wander cell.
# Keeps the current destination when the pick is the same (or when nothing is found).
func _choose_destination(
	here: Vector2i, state: CombatState, hand: HoldSlots, points: Array[FieldPoint],
	incoming: Array[Vector2i], burning: Array[Vector2i]
) -> void:
	var reach: Dictionary = _bfs(here, burning)
	var best: Dictionary = {}
	var best_score: float = -INF
	if not (hand.is_full() and float(_weights["pickup_full_hand_zero"]) >= 0.5):
		for point: FieldPoint in points:
			if point.cell == here or not reach.has(point.cell):
				continue
			var score: float = float(_weights["pickup_value"]) / (1.0 + float(reach[point.cell]))
			if incoming.has(point.cell):
				score -= float(_weights["pickup_danger_penalty"])
			score += _move_noise()
			if best.is_empty() or score > best_score:
				best_score = score
				best = {"cell": point.cell, "purpose": PURPOSE_PICKUP, "target_uid": point.uid}
	if best.is_empty():
		var hp_ratio: float = state.enemy_hp / maxf(state.enemy_max_hp, 0.001)
		if hp_ratio < float(_weights["retreat_hp_ratio"]) and float(_weights["retreat_bonus"]) > 0.0:
			var far: Vector2i = _farthest_cell(here, reach, incoming)
			if far != here:
				best = {"cell": far, "purpose": PURPOSE_RETREAT}
	if best.is_empty() and bool(_movement["wander_when_idle"]) and incoming.is_empty():
		if not _destination.is_empty() and str(_destination["purpose"]) == PURPOSE_WANDER:
			return
		var options: Array[Vector2i] = []
		for cell: Vector2i in reach.keys():
			if cell != here:
				options.append(cell)
		if not options.is_empty():
			best = {"cell": options[_rng.randi_range(0, options.size() - 1)], "purpose": PURPOSE_WANDER}
	if best.is_empty():
		return
	if not _destination.is_empty() and _destination["cell"] == best["cell"] \
			and str(_destination["purpose"]) == str(best["purpose"]):
		return
	best["path_style_in_use"] = _pick_path_style()
	_destination = best


# Nearest reachable cell outside the visible swing (may be the current cell = wait there).
func _set_dodge(here: Vector2i, incoming: Array[Vector2i], burning: Array[Vector2i]) -> void:
	var reach: Dictionary = _bfs(here, burning)
	var best: Vector2i = BoardGrid.NO_CELL
	var best_key: Array = []
	for cell: Vector2i in reach.keys():
		if incoming.has(cell):
			continue
		var key: Array = [int(reach[cell]), 0 if cell.y == here.y else 1, -_grid.to_side_coords(cell).x, cell.y]
		if best == BoardGrid.NO_CELL or _key_less(key, best_key):
			best = cell
			best_key = key
	if best == BoardGrid.NO_CELL:
		_destination = {}
		return
	_destination = {
		"cell": best, "purpose": PURPOSE_DODGE, "path_style_in_use": _pick_path_style(),
		"from_cell": here, "juke": false,
	}


# Reachable safe cell farthest from the divider (ties: same row as here, nearer here, upper row);
# here itself when it already sits in the farthest column.
func _farthest_cell(here: Vector2i, reach: Dictionary, incoming: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = here
	var best_key: Array = []
	for cell: Vector2i in reach.keys():
		if incoming.has(cell):
			continue
		var key: Array = [_grid.to_side_coords(cell).x, 0 if cell.y == here.y else 1, int(reach[cell]), cell.y]
		if best_key.is_empty() or _key_less(key, best_key):
			best = cell
			best_key = key
	if not best_key.is_empty() and _grid.to_side_coords(best).x == _grid.to_side_coords(here).x:
		return here
	return best


# Distances (cell -> steps) from [param start] over real, non-blocked own cells; start included.
func _bfs(start: Vector2i, blocked: Array[Vector2i]) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var d: int = int(dist[cell])
		for dir: Vector2i in _DIRECTIONS:
			var next: Vector2i = cell + dir
			if dist.has(next) or not _grid.is_enemy_cell(next) or blocked.has(next):
				continue
			dist[next] = d + 1
			queue.append(next)
	return dist


# The next step from [param from] to [param to] in [param style]; ZERO when there or unreachable.
# row_first / column_first take their axis step while it does not lengthen the path (BFS
# distance); otherwise, and for shortest, the step with the smallest remaining distance wins,
# ties broken by: horizontal (keeps the row) first, then the cell nearer the divider, then the
# direction order up / right / down / left.
func _step_toward(from: Vector2i, to: Vector2i, style: String, blocked: Array[Vector2i]) -> Vector2i:
	if from == to:
		return Vector2i.ZERO
	var dist: Dictionary = _bfs(to, blocked)
	if not dist.has(from):
		return Vector2i.ZERO
	var here_dist: int = int(dist[from])
	var delta: Vector2i = to - from
	if style == STYLE_ROW_FIRST or style == STYLE_COLUMN_FIRST:
		var horizontal: Vector2i = Vector2i(signi(delta.x), 0)
		var vertical: Vector2i = Vector2i(0, signi(delta.y))
		var order: Array[Vector2i] = []
		if style == STYLE_ROW_FIRST:
			order = [horizontal, vertical]
		else:
			order = [vertical, horizontal]
		for dir: Vector2i in order:
			if dir == Vector2i.ZERO:
				continue
			var cell: Vector2i = from + dir
			if dist.has(cell) and int(dist[cell]) <= here_dist:
				return dir
	var best_dir: Vector2i = Vector2i.ZERO
	var best_key: Array = []
	for dir: Vector2i in _DIRECTIONS:
		var cell: Vector2i = from + dir
		if not dist.has(cell):
			continue
		var key: Array = [int(dist[cell]), 0 if dir.y == 0 else 1, -_grid.to_side_coords(cell).x]
		if best_dir == Vector2i.ZERO or _key_less(key, best_key):
			best_dir = dir
			best_key = key
	return best_dir


# The set's path style, with "mixed" resolved by a seeded coin for one destination.
func _pick_path_style() -> String:
	var style: String = str(_movement["path_style"])
	if style == STYLE_ROW_FIRST or style == STYLE_SHORTEST:
		return style
	return STYLE_ROW_FIRST if _rng.randf() < 0.5 else STYLE_COLUMN_FIRST


# Score of walking toward the destination, compared against cuts and idle_bias.
func _purpose_score(purpose: String, here: Vector2i, incoming: Array[Vector2i], urgency: float) -> float:
	if purpose == PURPOSE_DODGE:
		return float(_weights["dodge_danger"]) * urgency
	if purpose == PURPOSE_PICKUP:
		var cell: Vector2i = _destination["cell"]
		var steps: int = absi(cell.x - here.x) + absi(cell.y - here.y)
		var value: float = float(_weights["pickup_value"]) / (1.0 + float(steps))
		if incoming.has(cell):
			value -= float(_weights["pickup_danger_penalty"])
		return value
	if purpose == PURPOSE_RETREAT:
		return float(_weights["retreat_bonus"])
	return float(_weights["idle_bias"])


func _move_noise() -> float:
	var amplitude: float = float(_movement["move_noise"])
	if amplitude <= 0.0:
		return 0.0
	return _rng.randf_range(-amplitude, amplitude)


# Lexicographic "a < b" over equally long integer arrays.
static func _key_less(a: Array, b: Array) -> bool:
	for i: int in a.size():
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false

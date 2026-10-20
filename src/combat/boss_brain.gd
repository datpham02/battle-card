class_name BossBrain
extends RefCounted
## The boss's decision maker: a weighted-score brain (weights in boss_brain.json), pure logic.
## It never touches the world: [method decide] reads the objects in its context and returns
## an action the controller applies ({"type":"wait"}, {"type":"move","direction":Vector2i},
## {"type":"cut","hand_indices":Array[int],"skill_id":String}).
##
## COMBINATORICS: cut candidates are every ORDERED selection of 1..min(4, hand_max_points,
## points in hand) points (order = connection order, so A-B-C differs from C-B-A). For a
## full 4-point hand that is 4 + 12 + 24 + 24 = 64 candidates. Covered cells are cached by
## label sequence, so the geometry runs once per distinct sequence.
## Cut score = per_cell*cells + hit_now(player cell covered) - duration_penalty*windup
## - point_cost*points - hand_wait(points < hand_target while the hand is not full)
## + interrupt bonus + skill bonus + noise. Move score = change in (pickup progress - danger
## + retreat) between the current and the candidate cell + noise. Best of cut / move / wait.
## Implements: Story 009.

const _DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const _MAX_POINTS: int = 4
## Floor for the time left used to scale danger urgency.
const _MIN_TIME_LEFT: float = 0.1

var _config: BossBrainConfig
var _grid: BoardGrid
var _cut_config: CutConfig
var _skill_config: SkillConfig
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _weights: Dictionary = {}
var _set_name: String = ""
var _think_clock: float = 0.0
var _player_seen_sec: float = 0.0
var _cell_cache: Dictionary = {}
var _debug: Dictionary = {}


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
	else:
		_rng.randomize()
	use_set(config.active_set)
	_debug = {"type": "wait", "reason": "not_decided", "score": 0.0, "set": _set_name}


## Switches the weight set. Returns false (nothing changes) when the name is unknown.
func use_set(set_name: String) -> bool:
	if not _config.has_set(set_name):
		if _weights.is_empty():
			_weights = _config.weights_for("")
			_set_name = _config.active_set
		return false
	_weights = _config.weights_for(set_name)
	_set_name = set_name
	return true


## Name of the weight set in use.
func get_set_name() -> String:
	return _set_name


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
## boss), cooldowns (SkillCooldowns, boss), player_actor (CutActor). Returns a wait until
## think_interval_sec has elapsed, and always while either side is dead.
func decide(ctx: Dictionary) -> Dictionary:
	var state: CombatState = ctx.get("state") as CombatState
	var hand: HoldSlots = ctx.get("hand") as HoldSlots
	var drops: FieldDrops = ctx.get("drops") as FieldDrops
	var mover: UnitMover = ctx.get("mover") as UnitMover
	var actor: CutActor = ctx.get("actor") as CutActor
	var cooldowns: SkillCooldowns = ctx.get("cooldowns") as SkillCooldowns
	var player_actor: CutActor = ctx.get("player_actor") as CutActor
	if state == null or hand == null or drops == null or mover == null or actor == null \
			or cooldowns == null or player_actor == null:
		return _finish_wait("bad_context", 0.0)
	if state.is_enemy_dead() or state.is_player_dead():
		return _finish_wait("dead", 0.0)
	if _think_clock < _config.think_interval_sec:
		return _finish_wait("thinking", 0.0)
	_think_clock = 0.0

	var incoming: Array[Vector2i] = _visible_incoming(player_actor)
	var urgency: float = 1.0 / maxf(player_actor.get_time_left(), _MIN_TIME_LEFT)
	var idle_score: float = float(_weights["idle_bias"])
	var best_cut: Dictionary = _best_cut(state, hand, actor, cooldowns, player_actor, incoming)
	var best_move: Dictionary = {}
	if mover.is_ready():
		best_move = _best_move(state, hand, drops, incoming, urgency)

	var choice: Dictionary = {"type": "wait", "score": idle_score, "breakdown": {"idle_bias": idle_score}}
	if not best_move.is_empty() and float(best_move["score"]) > float(choice["score"]):
		choice = best_move
	if not best_cut.is_empty() and float(best_cut["score"]) > float(choice["score"]):
		choice = best_cut
	_debug = choice.duplicate()
	_debug["set"] = _set_name
	_debug["reason"] = "chosen"
	_debug["alternatives"] = {
		"cut": float(best_cut["score"]) if not best_cut.is_empty() else null,
		"move": float(best_move["score"]) if not best_move.is_empty() else null,
		"wait": idle_score,
	}
	var type: String = str(choice["type"])
	if type == "cut":
		return {"type": "cut", "hand_indices": choice["hand_indices"], "skill_id": choice["skill_id"]}
	if type == "move":
		return {"type": "move", "direction": choice["direction"]}
	return {"type": "wait"}


## Score breakdown of the last decision: {type, score, set, reason, breakdown, alternatives,
## and for cuts hand_indices / skill_id / labels / cells, for moves direction}.
func last_debug() -> Dictionary:
	return _debug.duplicate(true)


func _finish_wait(reason: String, score: float) -> Dictionary:
	_debug = {"type": "wait", "reason": reason, "score": score, "set": _set_name}
	return {"type": "wait"}


# Cells of the player's swing once the brain has seen it for reaction_sec, else empty.
func _visible_incoming(player_actor: CutActor) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not player_actor.is_swinging() or not player_actor.targets_enemy():
		return none
	var elapsed: float = player_actor.get_duration() - player_actor.get_time_left()
	if minf(_player_seen_sec, elapsed) < _config.reaction_sec:
		return none
	return player_actor.get_cells()


func _best_cut(
	state: CombatState, hand: HoldSlots, actor: CutActor, cooldowns: SkillCooldowns,
	player_actor: CutActor, incoming: Array[Vector2i]
) -> Dictionary:
	var best: Dictionary = {}
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
		var duration: float = _cut_config.swing_duration(count)
		var parts: Dictionary = {}
		parts["cells"] = float(_weights["cut_per_cell"]) * float(count)
		parts["hit_now"] = float(_weights["cut_hit_now"]) if cells.has(state.player_cell) else 0.0
		parts["duration"] = -float(_weights["cut_duration_penalty"]) * duration
		parts["points"] = -float(_weights["cut_point_cost"]) * float(selection.size())
		parts["hand_wait"] = 0.0
		if selection.size() < hand_target and not hand_full:
			parts["hand_wait"] = -float(_weights["cut_hand_wait"])
		parts["interrupt"] = 0.0
		if player_actor.is_swinging() and not incoming.is_empty() and cells.has(state.player_cell) \
				and duration < player_actor.get_time_left():
			parts["interrupt"] = float(_weights["cut_interrupt_bonus"])
		var skill_id: String = _choose_skill(cooldowns, count)
		parts["skill"] = float(_weights.get(BossBrainConfig.SKILL_BONUS_PREFIX + skill_id, 0.0))
		parts["noise"] = _noise()
		var score: float = 0.0
		for value: Variant in parts.values():
			score += float(value)
		if score < float(_weights["min_cut_score"]):
			continue
		if best.is_empty() or score > float(best["score"]):
			best = {
				"type": "cut", "score": score, "hand_indices": selection, "skill_id": skill_id,
				"labels": labels, "cells": cells, "breakdown": parts,
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


func _best_move(
	state: CombatState, hand: HoldSlots, drops: FieldDrops, incoming: Array[Vector2i], urgency: float
) -> Dictionary:
	var best: Dictionary = {}
	var points: Array[FieldPoint] = drops.get_points()
	var hand_full: bool = hand.is_full()
	var hp_ratio: float = state.enemy_hp / maxf(state.enemy_max_hp, 0.001)
	var here: Dictionary = _cell_terms(state.enemy_cell, points, hand_full, incoming, urgency, hp_ratio)
	for direction: Vector2i in _DIRECTIONS:
		var cell: Vector2i = state.enemy_cell + direction
		if not _grid.is_enemy_cell(cell):
			continue
		var there: Dictionary = _cell_terms(cell, points, hand_full, incoming, urgency, hp_ratio)
		var parts: Dictionary = {
			"danger": float(there["danger"]) - float(here["danger"]),
			"pickup": float(there["pickup"]) - float(here["pickup"]),
			"retreat": float(there["retreat"]) - float(here["retreat"]),
			"noise": _noise(),
		}
		var score: float = 0.0
		for value: Variant in parts.values():
			score += float(value)
		if best.is_empty() or score > float(best["score"]):
			best = {"type": "move", "score": score, "direction": direction, "breakdown": parts}
	return best


# Value of standing on [param cell]: danger (<= 0), pickup progress (>= 0), retreat (>= 0).
func _cell_terms(
	cell: Vector2i, points: Array[FieldPoint], hand_full: bool, incoming: Array[Vector2i],
	urgency: float, hp_ratio: float
) -> Dictionary:
	var danger: float = 0.0
	if incoming.has(cell):
		danger = -float(_weights["dodge_danger"]) * urgency
	var pickup: float = 0.0
	if not (hand_full and float(_weights["pickup_full_hand_zero"]) >= 0.5):
		for point: FieldPoint in points:
			if not _grid.is_enemy_cell(point.cell):
				continue
			var steps: int = absi(point.cell.x - cell.x) + absi(point.cell.y - cell.y)
			var value: float = float(_weights["pickup_value"]) / (1.0 + float(steps))
			if incoming.has(point.cell):
				value -= float(_weights["pickup_danger_penalty"])
			pickup = maxf(pickup, value)
	var retreat: float = 0.0
	if hp_ratio < float(_weights["retreat_hp_ratio"]):
		var far_span: float = float(maxi(_grid.side_cols - 1, 1))
		var farness: float = 1.0 - float(_grid.to_side_coords(cell).x) / far_span
		retreat = float(_weights["retreat_bonus"]) * farness
	return {"danger": danger, "pickup": pickup, "retreat": retreat}


func _noise() -> float:
	if _config.noise <= 0.0:
		return 0.0
	return _rng.randf_range(-_config.noise, _config.noise)

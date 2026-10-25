class_name BossBrain
extends RefCounted
## The boss's decision maker: a weighted-score brain (weights in boss_brain.json), pure logic.
## It never touches the world: [method decide] reads the objects in its context and returns
## an action the controller applies ({"type":"wait"}, {"type":"move","direction":Vector2i},
## {"type":"cut","hand_indices":Array[int],"skill_id":String}).
##
## CUTS (Story 025, the only path since Story 026): the hand holds puzzle pieces
## (FieldPoint.piece). Candidates are PLACEMENTS: every held piece x distinct rotation x
## PiecePlacement.valid_anchors on the PLAYER's half. All single placements are ranked cheaply
## (covers the player's cell, then reachable cells covered) and only the top
## BossBrainConfig.max_placements_scored are scored in full; two-piece casts (up to max_pieces,
## across different held pieces, non-overlapping) are built from the best
## BossBrainConfig.pair_seed_placements singles and scored as ONE cast (union cells). The boss
## never uses featured-shape logic (that bonus is player-only).
## Cut score = per_cell*cells + hit_now(player cell covered)
## + escape_penalty / (1 + escape cells: cells the player can still reach during the wind-up
## that the cut does not cover, see EscapeAnalysis) - duration_penalty*windup
## - point_cost*pieces - hand_wait(pieces held < hand_target while the hand is not full)
## + interrupt bonus + skill bonus + noise (the file-level `noise`). A cut below min_cut_score is dropped,
## except with a FULL hand: then the best candidate is cast anyway so the boss never stalls (TD-022).
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
##
## ZONES (Story 027): a sealed cell of the boss's half (StatusEffects.is_sealed, side ENEMY) is a blocked
## cell for every path / step / dodge / juke search, exactly like a burning cell; a sealed cell of the
## PLAYER's half is blocked for the player's reach when cuts are scored (escape cells). A thorn cell of the
## boss's half stays steppable but costs `thorn_avoid` x its thorn damage (HP-weighted, see thorns_at):
## paths (one step = 1) go around a thorn while the detour is cheaper than that cost, a non-dodge step
## into a thorn adds the negative `thorn` term to the move score, and a DODGE picks the cell with the
## lowest expected cost = thorn cost of the path + the incoming swing's damage (CutConfig.slash_damage of
## its cells) when the boss would arrive too late ((steps - 1) x its step cooldown >= the swing's time
## left). The boss therefore steps through thorns when the swing hurts more than the thorns, goes around
## (or stays) when the thorns cost more, and records the trade in last_debug().dodge_plan.
##
## Implements: Story 009, Story 013 (Parts 1 and 2), Story 025 (piece cuts), Story 026 (label path removed), TD-022 (full-hand rule), Story 027 (zones).

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
## Added to the seed for the combo roll so it never shares a stream with the score noise.
const _COMBO_SEED_OFFSET: int = 104729
## Floor for the time left used to scale danger urgency.
const _MIN_TIME_LEFT: float = 0.1
## Float tolerance of path-cost comparisons.
const _COST_EPS: float = 0.0001

var _config: BossBrainConfig
var _grid: BoardGrid
var _cut_config: CutConfig
var _skill_config: SkillConfig
## Card ids the boss may use (match_params boss_cards; default = the basics in card_order).
var cards: Array[String] = []
## Story 023 (match key boss_min_runes): cuts of fewer cells than this are scored down by the weight
## `min_runes_penalty` per missing cell, and dropped altogether when a cut that big exists. 0 = off.
var min_runes: int = 0
## Story 025 (piece mode): most pieces one cast may join (CombatConfig.max_pieces_per_cast, set by
## BossController.enable_pieces). 1 = single pieces only.
var max_pieces: int = 2
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _weights: Dictionary = {}
var _movement: Dictionary = {}
var _reaction_sec: float = 0.0
var _set_name: String = ""
var _think_clock: float = 0.0
var _player_seen_sec: float = 0.0
var _combo_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _debug: Dictionary = {}
## "shape|rotated cells" -> valid anchors on the player's half (the grid never changes).
var _anchor_cache: Dictionary = {}
var _cut_candidates: Array[Dictionary] = []
var _status: StatusEffects = null
var _learning: BossLearning = null
## Current destination: {cell, purpose, path_style_in_use, target_uid (pickup), from_cell and
## juke (dodge)}; empty when the boss has nowhere to go.
var _destination: Dictionary = {}
## Story 027: own-half thorn cell -> cost (thorn_avoid x thorn damage), rebuilt every decide.
var _thorn_pen: Dictionary = {}
## Story 027: expected damage of the visible incoming swing (0 = none), its time left and the boss's
## step cooldown (seconds), used by the dodge trade-off.
var _swing_damage: float = 0.0
var _swing_time_left: float = 0.0
var _boss_step_sec: float = 0.0
## Story 027: the last dodge decision {cell, thorn_cost, hit_cost, steps, late, swing_damage, stay_cost}
## or {stay: true, ...} when staying in the swing was cheaper; empty when no dodge was planned.
var _dodge_plan: Dictionary = {}


## [param seed_value] below 0 gives a random seed; otherwise noise is deterministic.
func _init(
	config: BossBrainConfig, grid: BoardGrid, cut_config: CutConfig, skill_config: SkillConfig, seed_value: int = -1
) -> void:
	_config = config
	_grid = grid
	_cut_config = cut_config
	_skill_config = skill_config
	cards = skill_config.boss_card_order()
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
	# Story 027: own_blocked = burning + sealed cells of the boss's half (never entered); player_blocked =
	# burning + sealed cells of the player's half (the player cannot escape into them).
	var own_blocked: Array[Vector2i] = []
	var player_blocked: Array[Vector2i] = []
	_thorn_pen = {}
	if _status != null:
		own_blocked = _status.burning_cells()
		player_blocked = own_blocked.duplicate()
		own_blocked.append_array(_status.sealed_cells(CombatState.Side.ENEMY))
		player_blocked.append_array(_status.sealed_cells(CombatState.Side.PLAYER))
		var thorn_avoid: float = float(_weights.get("thorn_avoid", 0.0))
		for cell: Vector2i in _status.thorn_cells(CombatState.Side.ENEMY):
			_thorn_pen[cell] = thorn_avoid * float(_status.thorns_at(CombatState.Side.ENEMY, cell).get("damage", 0.0))
	_swing_damage = _cut_config.slash_damage(incoming.size()) if not incoming.is_empty() else 0.0
	_swing_time_left = player_actor.get_time_left() if not incoming.is_empty() else 0.0
	_boss_step_sec = _config.step_cooldown_sec * maxf(mover.cooldown_mult, 0.0)
	_dodge_plan = {}
	var urgency: float = 1.0 / maxf(player_actor.get_time_left(), _MIN_TIME_LEFT)
	var player_step_cooldown: float = float(ctx.get("player_step_cooldown", _config.step_cooldown_sec))
	var idle_score: float = float(_weights["idle_bias"])
	var best_cut: Dictionary = _best_cut(
		state, hand, actor, cooldowns, player_actor, incoming, player_blocked, player_step_cooldown
	)
	var best_move: Dictionary = _plan_move(state, hand, drops, incoming, own_blocked, urgency, mover.is_ready())

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
	if not _dodge_plan.is_empty():
		_debug["dodge_plan"] = _dodge_plan.duplicate()
	_debug["alternatives"] = {
		"cut": float(best_cut["score"]) if not best_cut.is_empty() else null,
		"move": float(best_move["score"]) if not best_move.is_empty() else null,
		"wait": idle_score,
	}
	var type: String = str(choice["type"])
	if type == "cut":
		var cut_action: Dictionary = {
			"type": "cut", "hand_indices": choice["hand_indices"], "skill_id": choice["skill_id"], "cells": choice["cells"],
		}
		var combo: Dictionary = _choose_combo(
				state, hand, choice, player_blocked, player_step_cooldown, _swing_mult(actor)
		)
		if not combo.is_empty():
			cut_action["combo"] = {"hand_indices": combo["hand_indices"], "skill_id": combo["skill_id"], "cells": combo["cells"]}
			_debug["combo"] = combo
		return cut_action
	if type == "move":
		return {"type": "move", "direction": choice["direction"]}
	return {"type": "wait"}


## Score breakdown of the last decision: {type, score, set, reason, breakdown, alternatives,
## destination {cell, purpose, path_style_in_use} (empty = idle), cut_candidates (every scored
## cut: {labels, score, escape, escape_term, hit_now}), and for cuts hand_indices / skill_id /
## labels / cells / escape, for moves direction / purpose; breakdown of a move = {purpose, thorn,
## noise}, thorn = -thorn cost of the step (0 for a dodge: its trade is in dodge_plan); dodge_plan when a
## dodge was planned this think (Story 027)}.
func last_debug() -> Dictionary:
	return _debug.duplicate(true)


# The boss actor's swing duration multiplier (1.0 when the actor has none).
func _swing_mult(actor: CutActor) -> float:
	return actor.duration_mult


# Second cut of a combo, or empty (see _choose_piece_combo). Combos always use slash.
func _choose_combo(
	state: CombatState, hand: HoldSlots, first: Dictionary, burning: Array[Vector2i],
	player_step_cooldown: float, duration_mult: float
) -> Dictionary:
	var chance: float = float(_weights.get("combo_chance", 0.0))
	if chance <= 0.0:
		return {}
	return _choose_piece_combo(state, hand, first, burning, player_step_cooldown, duration_mult, chance)


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
	return _best_piece_cut(state, hand, cooldowns, player_actor, incoming, burning, player_step_cooldown, _swing_mult(actor))


# ---------------------------------------------------------------- piece cuts (Story 025)


# Slots holding a piece that can be placed (rotten pieces are skipped), ascending.
func _placeable_slots(hand: HoldSlots) -> Array[int]:
	var out: Array[int] = []
	for i: int in hand.get_slot_count():
		var piece: Piece = hand.get_piece(i)
		if piece != null and piece.placeable():
			out.append(i)
	return out


# Valid anchors on the PLAYER's half for [param piece] in its current rotation (cached per shape + rotation).
func _anchors_for(piece: Piece) -> Array[Vector2i]:
	var key: String = "%s|%s" % [piece.shape_id, str(piece.relative_cells())]
	if not _anchor_cache.has(key):
		_anchor_cache[key] = PiecePlacement.valid_anchors(_grid, piece, false)
	var cached: Array[Vector2i] = _anchor_cache[key]
	return cached


# Every (piece in [param slots], distinct rotation, valid anchor) placement as a cast candidate
# {slots, pieces (shape ids), rotations, anchors, cells}; order = slot, rotation turn, anchor row by row.
func _enumerate_placements(hand: HoldSlots, slots: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: int in slots:
		var base: Piece = hand.get_piece(slot)
		var seen: Dictionary = {}
		for turns: int in 4:
			var piece: Piece = base.rotated(turns)
			var shape_key: String = str(piece.relative_cells())
			if seen.has(shape_key):
				continue
			seen[shape_key] = true
			for anchor: Vector2i in _anchors_for(piece):
				out.append({
					"slots": [slot] as Array[int], "pieces": [piece.shape_id] as Array[String],
					"rotations": [piece.rotation] as Array[int], "anchors": [anchor] as Array[Vector2i],
					"cells": piece.cells_at(anchor), "rank": 0.0,
				})
	return out


# Sets "rank" of every candidate with [param ranker] (Callable(cells) -> float) and sorts them best first:
# rank, then cell count (more first, or fewer first when [param fewer_cells_first]), then slot, rotation, anchor.
func _rank_candidates(list: Array[Dictionary], ranker: Callable, fewer_cells_first: bool) -> void:
	for cand: Dictionary in list:
		cand["rank"] = float(ranker.call(cand["cells"]))
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _candidate_before(a, b, fewer_cells_first))


static func _candidate_before(a: Dictionary, b: Dictionary, fewer_cells_first: bool) -> bool:
	if float(a["rank"]) != float(b["rank"]):
		return float(a["rank"]) > float(b["rank"])
	var ca: int = (a["cells"] as Array).size()
	var cb: int = (b["cells"] as Array).size()
	if ca != cb:
		return ca < cb if fewer_cells_first else ca > cb
	var sa: Array = a["slots"]
	var sb: Array = b["slots"]
	for i: int in mini(sa.size(), sb.size()):
		if int(sa[i]) != int(sb[i]):
			return int(sa[i]) < int(sb[i])
	var ra: Array = a["rotations"]
	var rb: Array = b["rotations"]
	for i: int in mini(ra.size(), rb.size()):
		if int(ra[i]) != int(rb[i]):
			return int(ra[i]) < int(rb[i])
	var aa: Array = a["anchors"]
	var ab: Array = b["anchors"]
	for i: int in mini(aa.size(), ab.size()):
		var pa: Vector2i = aa[i]
		var pb: Vector2i = ab[i]
		if pa != pb:
			return pa.y < pb.y or (pa.y == pb.y and pa.x < pb.x)
	return false


# Joins two single placements of DIFFERENT held pieces with disjoint cells into one cast candidate
# (slots ascending); returns an empty dictionary when they share a slot or a cell.
func _join_candidates(a: Dictionary, b: Dictionary) -> Dictionary:
	if int((a["slots"] as Array)[0]) == int((b["slots"] as Array)[0]):
		return {}
	var first: Dictionary = a
	var second: Dictionary = b
	if int((a["slots"] as Array)[0]) > int((b["slots"] as Array)[0]):
		first = b
		second = a
	var cells: Array[Vector2i] = []
	cells.assign(first["cells"] as Array)
	for cell: Vector2i in (second["cells"] as Array):
		if cells.has(cell):
			return {}
		cells.append(cell)
	var joined: Dictionary = {"cells": cells, "rank": 0.0}
	var slots: Array[int] = []
	slots.assign((first["slots"] as Array) + (second["slots"] as Array))
	joined["slots"] = slots
	var pieces: Array[String] = []
	pieces.assign((first["pieces"] as Array) + (second["pieces"] as Array))
	joined["pieces"] = pieces
	var rotations: Array[int] = []
	rotations.assign((first["rotations"] as Array) + (second["rotations"] as Array))
	joined["rotations"] = rotations
	var anchors: Array[Vector2i] = []
	anchors.assign((first["anchors"] as Array) + (second["anchors"] as Array))
	joined["anchors"] = anchors
	return joined


# Two-piece candidates from the best [param seed_count] ranked singles (all pairs across different slots,
# no shared cell). Empty when the cast may not join two pieces.
func _pair_candidates(ranked_singles: Array[Dictionary], seed_count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if max_pieces < 2:
		return out
	var n: int = mini(seed_count, ranked_singles.size())
	for i: int in n:
		for j: int in range(i + 1, n):
			var joined: Dictionary = _join_candidates(ranked_singles[i], ranked_singles[j])
			if not joined.is_empty():
				out.append(joined)
	return out


# Set (cell -> true) of the cells the player can reach while a swing of [param count] cells winds up.
func _reach_set(count: int, player_cell: Vector2i, burning: Array[Vector2i], step_cooldown: float,
		duration_mult: float, cache: Dictionary) -> Dictionary:
	if not cache.has(count):
		var steps: int = EscapeAnalysis.steps_for_swing(_cut_config.swing_duration(count) * duration_mult, step_cooldown)
		var reach: Dictionary = {}
		for cell: Vector2i in EscapeAnalysis.reachable_cells(_grid, player_cell, steps, true, burning):
			reach[cell] = true
		cache[count] = reach
	return cache[count] as Dictionary


# Cheap pre-ranking of a cast: the player's cell covered counts 1000, then 1 per reachable cell covered.
func _cut_rank(cells: Array[Vector2i], player_cell: Vector2i, burning: Array[Vector2i], step_cooldown: float,
		duration_mult: float, cache: Dictionary) -> float:
	var reach: Dictionary = _reach_set(cells.size(), player_cell, burning, step_cooldown, duration_mult, cache)
	var rank: float = 1000.0 if cells.has(player_cell) else 0.0
	for cell: Vector2i in cells:
		if reach.has(cell):
			rank += 1.0
	return rank


# Best piece cast: single placements (top max_placements_scored by cheap rank) plus two-piece joins of the
# best singles, each scored with the parts and weights in the file header.
func _best_piece_cut(
	state: CombatState, hand: HoldSlots, cooldowns: SkillCooldowns, player_actor: CutActor,
	incoming: Array[Vector2i], burning: Array[Vector2i], player_step_cooldown: float, duration_mult: float
) -> Dictionary:
	var best: Dictionary = {}
	var best_any: Dictionary = {} # best candidate ignoring min_cut_score (TD-022 full-hand rule)
	var slots: Array[int] = _placeable_slots(hand)
	if slots.is_empty():
		return best
	var player_cell: Vector2i = state.player_cell
	var reach_cache: Dictionary = {}
	var singles: Array[Dictionary] = _enumerate_placements(hand, slots)
	var cut_ranker: Callable = func(cells: Array[Vector2i]) -> float:
		return _cut_rank(cells, player_cell, burning, player_step_cooldown, duration_mult, reach_cache)
	_rank_candidates(singles, cut_ranker, false)
	var candidates: Array[Dictionary] = []
	for i: int in mini(singles.size(), _config.max_placements_scored):
		candidates.append(singles[i])
	var pairs: Array[Dictionary] = _pair_candidates(singles, _config.pair_seed_placements)
	candidates.append_array(pairs)
	var big_cut_exists: bool = false
	if min_runes > 0:
		for probe: Dictionary in singles + pairs:
			if (probe["cells"] as Array).size() >= min_runes:
				big_cut_exists = true
				break
	var hand_full: bool = hand.is_full()
	var hand_target: int = mini(int(_weights["hand_target"]), hand.get_slot_count())
	var mods: Dictionary = {} if _learning == null else _learning.get_modifiers()
	var quick_bias: float = float(mods.get("quick_cut_bias", 1.0))
	var single_bonus: float = float(mods.get("single_point_bonus", 0.0))
	var escape_penalty: float = float(_weights["escape_penalty"])
	var hand_wait: float = 0.0
	if hand.get_occupied_count() < hand_target and not hand_full:
		hand_wait = -float(_weights["cut_hand_wait"])
	for cand: Dictionary in candidates:
		var cells: Array[Vector2i] = []
		cells.assign(cand["cells"] as Array)
		var count: int = cells.size()
		if big_cut_exists and count < min_runes:
			continue
		var piece_count: int = (cand["slots"] as Array).size()
		var duration: float = _cut_config.swing_duration(count) * duration_mult
		var hits_now: bool = cells.has(player_cell)
		var reach: Dictionary = _reach_set(count, player_cell, burning, player_step_cooldown, duration_mult, reach_cache)
		var covered_reach: int = 0
		for cell: Vector2i in cells:
			if reach.has(cell):
				covered_reach += 1
		var escape: int = reach.size() - covered_reach
		var parts: Dictionary = {}
		parts["cells"] = float(_weights["cut_per_cell"]) * float(count)
		parts["hit_now"] = float(_weights["cut_hit_now"]) if hits_now else 0.0
		parts["escape"] = escape_penalty / (1.0 + float(escape))
		parts["duration"] = -float(_weights["cut_duration_penalty"]) * quick_bias * duration
		parts["single_point"] = single_bonus if count == 1 else 0.0
		parts["points"] = -float(_weights["cut_point_cost"]) * float(piece_count)
		parts["hand_wait"] = hand_wait
		parts["interrupt"] = 0.0
		if player_actor.is_swinging() and not incoming.is_empty() and hits_now \
				and duration < player_actor.get_time_left():
			parts["interrupt"] = float(_weights["cut_interrupt_bonus"])
		parts["min_runes"] = -float(_weights["min_runes_penalty"]) * float(maxi(min_runes - count, 0))
		var skill_id: String = _choose_skill(cooldowns, count)
		parts["skill"] = float(_weights.get(BossBrainConfig.SKILL_BONUS_PREFIX + skill_id, 0.0))
		parts["noise"] = _noise()
		var score: float = 0.0
		for value: Variant in parts.values():
			score += float(value)
		var piece_ids: String = ",".join(cand["pieces"] as Array[String])
		var rotations: Array = cand["rotations"]
		var anchors: Array = cand["anchors"]
		_cut_candidates.append({
			"labels": piece_ids, "piece": piece_ids, "pieces": (cand["pieces"] as Array).duplicate(),
			"rotation": rotations[0], "anchor": anchors[0], "rotations": rotations.duplicate(),
			"anchors": anchors.duplicate(), "cells": count, "score": score, "escape": escape,
			"escape_term": float(parts["escape"]), "hit_now": hits_now,
		})
		var entry: Dictionary = {
			"type": "cut", "score": score, "hand_indices": (cand["slots"] as Array).duplicate(), "skill_id": skill_id,
			"labels": (cand["pieces"] as Array).duplicate(), "cells": cells, "escape": escape, "breakdown": parts,
			"rotations": rotations.duplicate(), "anchors": anchors.duplicate(),
		}
		if best_any.is_empty() or score > float(best_any["score"]):
			best_any = entry
		if score < float(_weights["min_cut_score"]):
			continue
		if best.is_empty() or score > float(best["score"]):
			best = entry
	# TD-022 full-hand rule: a FULL hand never stalls. When every candidate is below min_cut_score and the
	# hand is full, the best candidate is cast anyway: a full hand cannot pick up anything better (pickup is
	# refused and normal pieces never rot in hand), so rejecting would freeze the boss for the rest of the
	# match (seen with three single-cell pieces). A partial hand still needs the bar (and pays cut_hand_wait).
	if best.is_empty() and hand_full and not best_any.is_empty():
		best = best_any
		best["full_hand_override"] = true
	return best


# Second cast of a combo in piece mode: needs a placeable piece left in hand. Rolls combo_chance, then picks the
# single (or joined pair) placement covering the MOST of the first cast's escape cells (>= 1 required); ties:
# fewer cells, then fewer pieces, then the enumeration order.
func _choose_piece_combo(
	state: CombatState, hand: HoldSlots, first: Dictionary, burning: Array[Vector2i],
	player_step_cooldown: float, duration_mult: float, chance: float
) -> Dictionary:
	var used: Array[int] = []
	used.assign(first["hand_indices"] as Array)
	var pool: Array[int] = []
	for slot: int in _placeable_slots(hand):
		if not used.has(slot):
			pool.append(slot)
	if pool.is_empty():
		return {}
	if chance < 1.0 and _combo_rng.randf() >= chance:
		return {}
	var cells1: Array[Vector2i] = first["cells"] as Array[Vector2i]
	var steps1: int = EscapeAnalysis.steps_for_swing(_cut_config.swing_duration(cells1.size()) * duration_mult, player_step_cooldown)
	var escape_before: Array[Vector2i] = EscapeAnalysis.escape_cells(_grid, state.player_cell, steps1, true, cells1, burning)
	var escape_set: Dictionary = {}
	for cell: Vector2i in escape_before:
		escape_set[cell] = true
	var singles: Array[Dictionary] = _enumerate_placements(hand, pool)
	var combo_ranker: Callable = func(cells: Array[Vector2i]) -> float:
		var n: int = 0
		for cell: Vector2i in cells:
			if escape_set.has(cell):
				n += 1
		return float(n)
	_rank_candidates(singles, combo_ranker, true)
	var candidates: Array[Dictionary] = singles.duplicate()
	candidates.append_array(_pair_candidates(singles, _config.pair_seed_placements))
	var best: Dictionary = {}
	var best_covered: int = 0
	for cand: Dictionary in candidates:
		var cells2: Array[Vector2i] = []
		cells2.assign(cand["cells"] as Array)
		var covered: int = 0
		for cell: Vector2i in cells2:
			if escape_set.has(cell):
				covered += 1
		if covered < 1:
			continue
		if not best.is_empty():
			var best_cells: int = (best["cells"] as Array).size()
			var better: bool = covered > best_covered
			if covered == best_covered:
				better = cells2.size() < best_cells \
					or (cells2.size() == best_cells and (cand["slots"] as Array).size() < (best["hand_indices"] as Array).size())
			if not better:
				continue
		best_covered = covered
		best = {
			"hand_indices": (cand["slots"] as Array).duplicate(), "skill_id": SkillConfig.FALLBACK_SKILL,
			"labels": (cand["pieces"] as Array).duplicate(), "cells": cells2, "covered": covered,
			"escape_before": escape_before.size(), "escape_after": escape_before.size() - covered,
		}
	return best


# Highest-preference available skill for [param cell_count]: slash has preference 0, any other
# skill its skill_bonus_<id> weight; ties keep the earlier skill in menu order.
func _choose_skill(cooldowns: SkillCooldowns, cell_count: int) -> String:
	var best_id: String = ""
	var best_bonus: float = -INF
	for skill_id: String in cards:
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
	# Story 027: a non-dodge step into a thorn pays its cost; a dodge already weighed it (dodge_plan).
	var thorn: float = 0.0 if purpose == PURPOSE_DODGE else -_thorn_penalty(here + direction)
	return {
		"type": "move", "score": base + thorn + noise, "direction": direction, "purpose": purpose,
		"breakdown": {purpose: base, "thorn": thorn, "noise": noise},
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
		if not _grid.is_enemy_cell(cell) or burning.has(cell) or incoming.has(cell) or _thorn_pen.has(cell):
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


# Cheapest reachable cell outside the visible swing (may be the current cell = wait there). Story 027:
# cost = thorn cost of the cheapest path + the swing's damage when the boss would arrive late; ties: fewer
# steps, same row, nearer the divider... (the pre-zone order, which it reproduces when no thorn exists).
# When standing in the swing and every escape costs MORE than taking the hit, the boss stays.
func _set_dodge(here: Vector2i, incoming: Array[Vector2i], burning: Array[Vector2i]) -> void:
	var paths: Dictionary = _cost_map(here, burning, false)
	var best: Vector2i = BoardGrid.NO_CELL
	var best_key: Array = []
	for cell: Vector2i in paths.keys():
		if incoming.has(cell):
			continue
		var entry: Array = paths[cell]
		var steps: int = int(entry[2])
		var cost: float = float(entry[1]) + (_swing_damage if _arrives_late(steps) else 0.0)
		var key: Array = [cost, steps, 0 if cell.y == here.y else 1, -_grid.to_side_coords(cell).x, cell.y]
		if best == BoardGrid.NO_CELL or _key_less_float(key, best_key):
			best = cell
			best_key = key
	if best == BoardGrid.NO_CELL:
		_destination = {}
		return
	var stay_cost: float = _swing_damage if incoming.has(here) else 0.0
	_dodge_plan = {
		"cell": best, "thorn_cost": float((paths[best] as Array)[1]), "steps": int(best_key[1]),
		"late": _arrives_late(int(best_key[1])), "hit_cost": float(best_key[0]) - float((paths[best] as Array)[1]),
		"swing_damage": _swing_damage, "stay_cost": stay_cost, "stay": false,
	}
	if incoming.has(here) and float(best_key[0]) > stay_cost + _COST_EPS:
		_dodge_plan["stay"] = true
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
# Story 027: distances are path costs (1 per step + the thorn cost of each cell entered, so a thorn is
# walked around while the detour is cheaper), and [param from] may itself be blocked (standing in a seal).
func _step_toward(from: Vector2i, to: Vector2i, style: String, blocked: Array[Vector2i]) -> Vector2i:
	if from == to:
		return Vector2i.ZERO
	var dist: Dictionary = _cost_map(to, blocked, true, from)
	if not dist.has(from):
		return Vector2i.ZERO
	var here_dist: float = float((dist[from] as Array)[0])
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
			if dist.has(cell) and cell != from and _via(dist, cell) <= here_dist + _COST_EPS:
				return dir
	var best_dir: Vector2i = Vector2i.ZERO
	var best_key: Array = []
	for dir: Vector2i in _DIRECTIONS:
		var cell: Vector2i = from + dir
		if not dist.has(cell):
			continue
		var key: Array = [_via(dist, cell), 0 if dir.y == 0 else 1, -_grid.to_side_coords(cell).x]
		if best_dir == Vector2i.ZERO or _key_less_float(key, best_key):
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


# Lexicographic "a < b" whose FIRST element is a float cost (compared with _COST_EPS), the rest integers.
static func _key_less_float(a: Array, b: Array) -> bool:
	if absf(float(a[0]) - float(b[0])) > _COST_EPS:
		return float(a[0]) < float(b[0])
	for i: int in range(1, a.size()):
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false


# ---------------------------------------------------------------- zones (Story 027)


# Cost of stepping INTO [param cell] of the boss's half: thorn_avoid x its thorn damage (0 = no thorn).
func _thorn_penalty(cell: Vector2i) -> float:
	return float(_thorn_pen.get(cell, 0.0))


# Total cost of reaching the search origin from [param from] when the next step is [param cell].
func _via(dist: Dictionary, cell: Vector2i) -> float:
	return float((dist[cell] as Array)[0]) + 1.0 + _thorn_penalty(cell)


# True when a dodge of [param steps] steps would land after the visible swing resolves (no swing: false).
func _arrives_late(steps: int) -> bool:
	if _swing_time_left <= 0.0 or steps <= 0:
		return false
	return float(steps - 1) * _boss_step_sec >= _swing_time_left


# Cheapest paths over the boss's real, non-blocked cells (Dijkstra; tiny grid, linear scan). Returns
# cell -> [metric, thorn cost, steps] where metric = steps + thorn cost of every cell entered. Forward
# (from [param origin]) the cost of a step is that of the cell entered; [param backward] (origin = a
# target) charges the cell stepped from, so metric = the cost of walking from that cell TO the origin.
# [param allow] may be entered even if blocked (the walker standing in a seal or a burning cell).
func _cost_map(origin: Vector2i, blocked: Array[Vector2i], backward: bool, allow: Vector2i = BoardGrid.NO_CELL) -> Dictionary:
	var best: Dictionary = {origin: [0.0, 0.0, 0]}
	var done: Dictionary = {}
	while true:
		var cell: Vector2i = BoardGrid.NO_CELL
		var cell_metric: float = INF
		for candidate: Vector2i in best.keys():
			if done.has(candidate):
				continue
			var metric: float = float((best[candidate] as Array)[0])
			if metric < cell_metric - _COST_EPS:
				cell = candidate
				cell_metric = metric
		if cell == BoardGrid.NO_CELL:
			break
		done[cell] = true
		var entry: Array = best[cell]
		for dir: Vector2i in _DIRECTIONS:
			var next: Vector2i = cell + dir
			if done.has(next) or not _grid.is_enemy_cell(next):
				continue
			if blocked.has(next) and next != allow:
				continue
			var pen: float = _thorn_penalty(cell) if backward else _thorn_penalty(next)
			var next_metric: float = float(entry[0]) + 1.0 + pen
			if not best.has(next) or next_metric < float((best[next] as Array)[0]) - _COST_EPS:
				best[next] = [next_metric, float(entry[1]) + pen, int(entry[2]) + 1]
	return best

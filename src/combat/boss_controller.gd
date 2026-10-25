class_name BossController
extends RefCounted
## The boss as a player-like agent: its own hand, field drops, step mover, skill cooldowns and
## cut actor, driven by a BossBrain. The controller applies the brain's decisions; it does NOT
## tick its [CutActor] (the SwingArbiter does, so swing order stays in one place).
## The boss plays PIECES only (Story 025; the labelled-point mode was removed in Story 026).
## Implements: Story 009, Story 013 (player step cooldown handed to the brain), Story 025, Story 026.

## The boss committed a cut: [param labels] = the shape ids of the cast pieces, the covered [param cells]
## on the player's board, the chosen [param skill_id].
signal cut_started(labels: Array[String], cells: Array[Vector2i], skill_id: String)
## The boss queued the second swing of a combo (it starts when the first resolves): the
## [param cells] it will cover on the player's board and its [param labels]. cut_started fires
## once, for the first swing only.
signal combo_queued(cells: Array[Vector2i], labels: Array[String])
## The boss moved one cell (new cell on the boss's half).
signal moved(direction: Vector2i)
## The boss picked up a point into its hand.
signal point_picked(point: FieldPoint)
## A feint was cancelled mid-windup (it dealt nothing): the cells it was showing and its labels.
signal feinted(cells: Array[Vector2i], labels: Array[String])

## Offset added to the seed for the feint RNG so it never shares a stream with the brain noise.
const _FEINT_SEED_OFFSET: int = 7919
## Skill of a combo's second swing (combos always slash).
const COMBO_SKILL: String = "kiem_khi"

## DEV-ONLY (capture demos): when true the next small cut is a feint regardless of the
## learning roll; cleared once used. Never set by gameplay code.
var force_next_feint: bool = false

var _brain_config: BossBrainConfig
var _status: StatusEffects = null
var _learning: BossLearning = null
var _feint_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _feint_pending: bool = false
var _feint_cells: Array[Vector2i] = []
var _feint_labels: Array[String] = []
var _feint_count: int = 0
var _state: CombatState
var _grid: BoardGrid
var _cut_config: CutConfig
var _skill_config: SkillConfig
var _hand: HoldSlots
var _drops: FieldDrops
var _mover: UnitMover
var _actor: CutActor
var _cooldowns: SkillCooldowns
var _brain: BossBrain
var _last_cut: Dictionary = {}
var _combo_count: int = 0
var _player_step_cooldown: float = 0.0
var _active: bool = true
var _removing: bool = false
var _hold_config: HoldSlotsConfig
var _max_pieces: int = 2


## [param seed_value] below 0 = random; otherwise drops and brain noise are deterministic.
func _init(
	state: CombatState, grid: BoardGrid, cut_config: CutConfig, skill_config: SkillConfig,
	brain_config: BossBrainConfig, drops_config: FieldDropsConfig, hold_config: HoldSlotsConfig,
	seed_value: int = -1
) -> void:
	_state = state
	_brain_config = brain_config
	if seed_value >= 0:
		_feint_rng.seed = seed_value + _FEINT_SEED_OFFSET
	else:
		_feint_rng.randomize()
	_grid = grid
	_cut_config = cut_config
	_skill_config = skill_config
	_hold_config = hold_config
	_hand = HoldSlots.create_piece_hand(hold_config.piece_slot_count)
	_drops = FieldDrops.new(drops_config, grid.enemy_cells(), seed_value)
	_mover = UnitMover.new(state, CombatState.Side.ENEMY, brain_config.step_cooldown_sec)
	_actor = CutActor.new(cut_config, CombatState.Side.ENEMY)
	_mover.step_lock_fn = Callable(self, "is_step_locked")
	_cooldowns = SkillCooldowns.new()
	_brain = BossBrain.new(brain_config, grid, cut_config, skill_config, seed_value)
	state.cell_changed.connect(_on_cell_changed)
	_hand.slot_cleared.connect(_on_slot_cleared)


## Story 025: gives the boss's field drops their puzzle pieces: shapes of [param library]
## (chapter weights of [param chapter_id], only shapes that fit the PLAYER half, seeded by
## [param rng_seed]; the spawn interval keeps whatever scaling the drops config carries).
## [param max_pieces] (CombatConfig.max_pieces_per_cast, default 2) is the most pieces one cast may join.
## Call before the first tick; without it nothing drops on the boss's half (its hand is a piece
## hand of HoldSlotsConfig.piece_slot_count slots from the start).
func enable_pieces(library: PieceLibrary, chapter_id: String, rng_seed: int, max_pieces: int = 2) -> void:
	_max_pieces = maxi(max_pieces, 1)
	_brain.max_pieces = _max_pieces
	_drops.enable_pieces(library, chapter_id, _grid, rng_seed, false)


## Story 025: true while the boss is rooted: the config's root_while_swinging is on and its actor
## swings (or has a combo swing queued). The boss's [UnitMover] refuses to step meanwhile; an
## interrupt, feint cancel or resolve unlocks at once.
func is_step_locked() -> bool:
	return _brain_config.root_while_swinging and (_actor.is_swinging() or _actor.has_queued())


## Advances the boss's own clocks and makes at most one decision. [param player_actor] is the
## player's cut actor (read only). Does nothing while frozen.
func tick(delta: float, player_actor: CutActor) -> void:
	if not _active:
		return
	_drops.tick(delta, _state.enemy_cell, _hand.get_occupied_count())
	_mover.tick(delta)
	_cooldowns.tick(delta)
	_brain.tick(delta, player_actor.is_swinging())
	if _state.is_enemy_dead() or _state.is_player_dead():
		return
	_tick_feint()
	var ctx: Dictionary = {
		"state": _state, "hand": _hand, "drops": _drops, "mover": _mover, "actor": _actor,
		"cooldowns": _cooldowns, "player_actor": player_actor, "status": _status,
	}
	if _player_step_cooldown > 0.0:
		ctx["player_step_cooldown"] = _player_step_cooldown
	var action: Dictionary = _brain.decide(ctx)
	match str(action["type"]):
		"move":
			var direction: Vector2i = action["direction"] as Vector2i
			if _mover.try_step(direction):
				moved.emit(direction)
		"cut":
			_do_cut(action)


## Shares the match's status effects: the boss's mover obeys pins and the brain avoids fire.
func set_status(status: StatusEffects) -> void:
	_status = status
	_mover.set_status(status)


## The player's (board-scaled) step cooldown in seconds: the brain counts the player's escape
## cells with it when scoring cuts. <= 0 (default) = the brain falls back to the boss's own
## step cooldown.
func set_player_step_cooldown(seconds: float) -> void:
	_player_step_cooldown = maxf(seconds, 0.0)


## Shares the learning counters with the brain and the feint roll (null = no learning).
func set_learning(learning: BossLearning) -> void:
	_learning = learning
	_brain.set_learning(learning)


## Seconds between a combo's two impacts: the active set's combo_gap_sec, at least the base
## swing time. The second swing starts when the first resolves and lasts exactly this long.
func combo_gap_sec() -> float:
	return maxf(_brain.get_combo_gap_sec(), _cut_config.swing_base_sec)


## Number of combos queued so far.
func get_combo_count() -> int:
	return _combo_count


## Number of feints cancelled so far.
func get_feint_count() -> int:
	return _feint_count


## Freezes (false) or resumes (true) the boss's decisions and clocks. Dev/capture only.
func set_active(value: bool) -> void:
	_active = value


## True unless frozen with [method set_active].
func is_active() -> bool:
	return _active


## The last committed cut {labels, skill_id}; empty before the first.
func get_last_cut() -> Dictionary:
	return _last_cut


## The boss's hand (no view).
func get_hand() -> HoldSlots:
	return _hand


## Field points on the boss's half.
func get_drops() -> FieldDrops:
	return _drops


## The boss's step mover.
func get_mover() -> UnitMover:
	return _mover


## The boss's cut actor (ticked by the SwingArbiter).
func get_actor() -> CutActor:
	return _actor


## The decision maker (weight set, debug breakdown).
func get_brain() -> BossBrain:
	return _brain


## The boss's skill cooldowns.
func get_cooldowns() -> SkillCooldowns:
	return _cooldowns


func _do_cut(action: Dictionary) -> void:
	var indices: Array[int] = []
	indices.assign(action["hand_indices"] as Array)
	var skill_id: String = str(action["skill_id"])
	var labels: Array[String] = []
	for index: int in indices:
		var point: FieldPoint = _hand.get_point(index)
		if point == null:
			return
		labels.append(point.label)
	if not _are_castable_pieces(indices):
		return
	var cells: Array[Vector2i] = _valid_piece_cells(action.get("cells"))
	if cells.is_empty() or not _actor.can_begin():
		return
	# Optional combo: validated up front (any bad index or empty cells = no combo, cut goes on).
	var combo_indices: Array[int] = []
	var combo_labels: Array[String] = []
	var combo_cells: Array[Vector2i] = []
	var combo: Variant = action.get("combo")
	if typeof(combo) == TYPE_DICTIONARY:
		combo_indices.assign((combo as Dictionary).get("hand_indices", []) as Array)
		for index: int in combo_indices:
			var combo_point: FieldPoint = _hand.get_point(index)
			if combo_point == null or indices.has(index) or combo_indices.count(index) > 1:
				combo_labels.clear()
				break
			combo_labels.append(combo_point.label)
		if not combo_labels.is_empty() and _are_castable_pieces(combo_indices):
			combo_cells = _valid_piece_cells((combo as Dictionary).get("cells"))
	var has_combo: bool = not combo_cells.is_empty()
	_removing = true
	for index: int in indices:
		_hand.remove(index)
	if has_combo:
		for index: int in combo_indices:
			_hand.remove(index)
	_removing = false
	if _actor.begin_swing(cells, skill_id, false):
		_cooldowns.start(skill_id, float(_skill_config.get_skill(skill_id).get("cooldown_sec", 0.0)))
		_last_cut = {"labels": labels, "skill_id": skill_id}
		cut_started.emit(labels, cells, skill_id)
		if has_combo and _actor.queue_swing(combo_cells, COMBO_SKILL, false, combo_gap_sec()):
			_last_cut["combo"] = {"labels": combo_labels, "skill_id": COMBO_SKILL}
			_combo_count += 1
			combo_queued.emit(combo_cells, combo_labels)
		else:
			_roll_feint(labels, cells)
	_carry_over()


# Story 025: true when [param indices] name 1..max_pieces DISTINCT hand slots that all hold a placeable piece.
func _are_castable_pieces(indices: Array[int]) -> bool:
	if indices.is_empty() or indices.size() > _max_pieces:
		return false
	for i: int in indices.size():
		var piece: Piece = _hand.get_piece(indices[i])
		if piece == null or not piece.placeable() or indices.count(indices[i]) > 1:
			return false
	return true


# Story 025: [param raw] (the action's "cells") when it is a non-empty list of distinct real cells of
# the PLAYER's half, else an empty array (the cut is refused and the piece stays in hand).
func _valid_piece_cells(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for cell_variant: Variant in (raw as Array):
		if typeof(cell_variant) != TYPE_VECTOR2I:
			return [] as Array[Vector2i]
		var cell: Vector2i = cell_variant as Vector2i
		if not _grid.is_player_cell(cell) or out.has(cell):
			return [] as Array[Vector2i]
		out.append(cell)
	return out


# A small cut may be a feint when the learning says the player keeps dodging early: a cast of at
# most learning.feint_max_cells cells.
func _roll_feint(labels: Array[String], cells: Array[Vector2i]) -> void:
	_feint_pending = false
	if cells.size() > int(_brain_config.learning["feint_max_cells"]):
		return
	if force_next_feint:
		force_next_feint = false
		_feint_pending = true
		_feint_cells = cells.duplicate()
		_feint_labels = labels.duplicate()
		return
	if _learning == null:
		return
	var chance: float = float(_learning.get_modifiers().get("feint_chance", 0.0))
	if chance > 0.0 and _feint_rng.randf() < chance:
		_feint_pending = true
		_feint_cells = cells.duplicate()
		_feint_labels = labels.duplicate()


# Cancels the running feint at feint_cancel_fraction of its duration. A swing already gone
# (interrupted or resolved) is left alone.
func _tick_feint() -> void:
	if not _feint_pending:
		return
	if not _actor.is_swinging():
		_feint_pending = false
		return
	var cancel_fraction: float = float(_brain_config.learning["feint_cancel_fraction"])
	var elapsed: float = _actor.get_duration() - _actor.get_time_left()
	if elapsed < _actor.get_duration() * cancel_fraction:
		return
	_feint_pending = false
	_actor.cancel()
	_feint_count += 1
	feinted.emit(_feint_cells, _feint_labels)


func _on_cell_changed(side: int, _old_cell: Vector2i, new_cell: Vector2i) -> void:
	if side != CombatState.Side.ENEMY:
		return
	_pick_up(new_cell)


func _on_slot_cleared(_index: int, _point: FieldPoint) -> void:
	if _removing:
		return
	_carry_over()


# Picks up the point under the boss's feet when there is room (same carry-over as the player).
func _carry_over() -> void:
	if not _state.is_enemy_dead():
		_pick_up(_state.enemy_cell)


func _pick_up(cell: Vector2i) -> void:
	var point: FieldPoint = _drops.pick_up_at(cell, not _hand.is_full())
	if point != null and _hand.place_in_first_free(point) >= 0:
		point_picked.emit(point)

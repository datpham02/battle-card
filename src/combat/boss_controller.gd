class_name BossController
extends RefCounted
## The boss as a player-like agent: its own hand, field drops, step mover, skill cooldowns and
## cut actor, driven by a BossBrain. The controller applies the brain's decisions; it does NOT
## tick its [CutActor] (the SwingArbiter does, so swing order stays in one place).
## Implements: Story 009.

## The boss committed a cut: [param labels] in connection order, the covered [param cells]
## on the player's board, the chosen [param skill_id].
signal cut_started(labels: Array[String], cells: Array[Vector2i], skill_id: String)
## The boss moved one cell (new cell on the boss's half).
signal moved(direction: Vector2i)
## The boss picked up a point into its hand.
signal point_picked(point: FieldPoint)

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
var _active: bool = true
var _removing: bool = false


## [param seed_value] below 0 = random; otherwise drops and brain noise are deterministic.
func _init(
	state: CombatState, grid: BoardGrid, cut_config: CutConfig, skill_config: SkillConfig,
	brain_config: BossBrainConfig, drops_config: FieldDropsConfig, hold_config: HoldSlotsConfig,
	seed_value: int = -1
) -> void:
	_state = state
	_grid = grid
	_cut_config = cut_config
	_skill_config = skill_config
	_hand = HoldSlots.new(hold_config.slot_count)
	_drops = FieldDrops.new(drops_config, grid.enemy_cells(), grid.perimeter_labels(), seed_value)
	_mover = UnitMover.new(state, CombatState.Side.ENEMY, brain_config.step_cooldown_sec)
	_actor = CutActor.new(cut_config, CombatState.Side.ENEMY)
	_cooldowns = SkillCooldowns.new()
	_brain = BossBrain.new(brain_config, grid, cut_config, skill_config, seed_value)
	state.cell_changed.connect(_on_cell_changed)
	_hand.slot_cleared.connect(_on_slot_cleared)


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
	var ctx: Dictionary = {
		"state": _state, "hand": _hand, "drops": _drops, "mover": _mover, "actor": _actor,
		"cooldowns": _cooldowns, "player_actor": player_actor,
	}
	var action: Dictionary = _brain.decide(ctx)
	match str(action["type"]):
		"move":
			var direction: Vector2i = action["direction"] as Vector2i
			if _mover.try_step(direction):
				moved.emit(direction)
		"cut":
			_do_cut(action)


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
	var cells: Array[Vector2i] = CutResolver.resolve_on_board(_grid, false, labels)
	if cells.is_empty() or not _actor.can_begin():
		return
	_removing = true
	for index: int in indices:
		_hand.remove(index)
	_removing = false
	if _actor.begin_swing(cells, skill_id, false):
		_cooldowns.start(skill_id, float(_skill_config.get_skill(skill_id).get("cooldown_sec", 0.0)))
		_last_cut = {"labels": labels, "skill_id": skill_id}
		cut_started.emit(labels, cells, skill_id)
	_carry_over()


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

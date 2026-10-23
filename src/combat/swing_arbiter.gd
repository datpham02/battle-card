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

## Emitted after a swing's effects were applied. [param result] is CutEffects' dictionary
## {hit, damage, pushed, cell} extended with {cells, skill_id, level, pin_bonus}. [param side] = CombatState.Side.
signal swing_resolved(side: int, result: Dictionary)
## Emitted when a hit cancelled the opponent's running swing; [param victim_side] is the
## side whose swing was cancelled, [param cells] / [param skill_id] that cancelled swing.
signal swing_interrupted(victim_side: int, cells: Array[Vector2i], skill_id: String)

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
## Story 018: Callable(cells: int, damage: float) -> float applied to the PLAYER's hit damage only
## (the character passive); invalid = none.
var player_damage_modifier: Callable = Callable()


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
		slice = minf(maxf(slice, _MIN_SLICE_SEC), remaining)
		remaining -= slice
		_step(slice)
		if _state.is_player_dead() or _state.is_enemy_dead():
			_cancel_all()
			return


# Ticks both actors by one slice, then settles the swings that resolved in it.
func _step(slice: float) -> void:
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
		_settle(int(entry["side"]), entry["cells"] as Array[Vector2i], str(entry["skill_id"]), trade, int(entry["level"]))


func _settle(side: int, cells: Array[Vector2i], skill_id: String, trade: bool, level: int = 1) -> void:
	var modifier: Callable = player_damage_modifier if side == CombatState.Side.PLAYER else Callable()
	var result: Dictionary = CutEffects.apply(_state, _grid, side, cells, skill_id, _cut_config, _skill_config, _status, modifier, level)
	result["cells"] = cells
	result["skill_id"] = skill_id
	result["level"] = level
	swing_resolved.emit(side, result)
	if trade or not bool(result["hit"]):
		return
	var victim_side: int = _opposite(side)
	var victim: CutActor = _actors[victim_side] as CutActor
	if victim.is_swinging():
		var victim_cells: Array[Vector2i] = victim.get_cells()
		var victim_skill: String = victim.get_skill_id()
		victim.cancel()
		swing_interrupted.emit(victim_side, victim_cells, victim_skill)


func _on_actor_resolved(cells: Array[Vector2i], skill_id: String, side: int) -> void:
	_pending.append({"side": side, "cells": cells, "skill_id": skill_id, "level": (_actors[side] as CutActor).get_level()})


func _cancel_all() -> void:
	for side: int in _actors:
		(_actors[side] as CutActor).cancel()


func _opposite(side: int) -> int:
	return CombatState.Side.ENEMY if side == CombatState.Side.PLAYER else CombatState.Side.PLAYER

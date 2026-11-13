class_name BossLearning
extends RefCounted
## Pure counters of the player's behaviour the boss adapts to. The match wiring feeds it events;
## [method get_modifiers] derives data-driven modifiers (numbers from the `learning` section of
## boss_brain.json, see BossBrainConfig.learning):
## (a) early dodges in a row >= dodge_streak_threshold => feint_chance (the boss may fake a
##     one-point cut); base at the threshold, plus per_dodge for every dodge beyond it, capped;
## (b) the player's hand continuously full for >= full_hand_seconds => quick_cut_bias (a
##     multiplier for the brain's windup penalty, so it prefers fast cuts to interrupt a big cut);
## (c) the player interrupted the boss >= interrupt_count_threshold times => single_point_bonus
##     (flat score bonus for 1-point cuts).
## Implements: Story 010.

var _rules: Dictionary
## Multi-enemy Phase 3 (A1, MULTI-ENEMY-PHASE3-5-PLAN.md 1.1b): ONE learning book for the whole enemy team, but each
## enemy unit's RUNNING swing has its own record (unit key -> {cells, dodged}), so two overlapping swings never
## overwrite each other. The learned numbers (dodge streak, interrupts, full hand) stay shared. Every key defaults to 1
## (unit 0): with one swing at a time the book behaves exactly as before.
var _swings: Dictionary = {}
var _player_cell: Vector2i = Vector2i(-1, -1)
var _dodge_streak: int = 0
var _interrupt_count: int = 0
var _full_hand_sec: float = 0.0


## [param rules] is BossBrainConfig.learning (missing keys fall back to its defaults).
func _init(rules: Dictionary = {}) -> void:
	_rules = BossBrainConfig.DEFAULT_LEARNING.duplicate()
	for key: Variant in rules.keys():
		_rules[key] = rules[key]


## A boss swing of the unit [param key] began over [param cells] while the player stood on [param player_cell].
func on_boss_swing_started(cells: Array[Vector2i], player_cell: Vector2i, key: int = CombatState.Side.ENEMY) -> void:
	_swings[key] = {"cells": cells.duplicate(), "dodged": false}
	_player_cell = player_cell


## The player moved to [param new_cell]. Leaving the cells of a running boss swing is an early dodge (each running swing
## judged on its own cells).
func on_player_moved(new_cell: Vector2i) -> void:
	for key: Variant in _swings.keys():
		var rec: Dictionary = _swings[key] as Dictionary
		var cells: Array = rec["cells"] as Array
		if cells.has(_player_cell) and not cells.has(new_cell):
			rec["dodged"] = true
	_player_cell = new_cell


## The running swing of the unit [param key] was cancelled (interrupt or feint): it neither hits nor misses.
func on_boss_swing_cancelled(key: int = CombatState.Side.ENEMY) -> void:
	_swings.erase(key)


## The swing of the unit [param key] resolved. A hit resets the dodge streak; a miss after an early dodge extends it;
## any other miss leaves it.
func on_boss_swing_resolved(hit: bool, key: int = CombatState.Side.ENEMY) -> void:
	if not _swings.has(key):
		return
	var rec: Dictionary = _swings[key] as Dictionary
	_swings.erase(key)
	if hit:
		_dodge_streak = 0
	elif bool(rec["dodged"]):
		_dodge_streak += 1


## Phase 3 (A1): true while the unit [param key] has a running swing on record.
func has_running_swing(key: int = CombatState.Side.ENEMY) -> bool:
	return _swings.has(key)


## The player's swing cancelled the boss's swing.
func on_player_interrupted_boss() -> void:
	_interrupt_count += 1


## Advances the full-hand clock: seconds the player's hand has been continuously full.
func tick(delta: float, player_hand_full: bool) -> void:
	if player_hand_full:
		_full_hand_sec += delta
	else:
		_full_hand_sec = 0.0


## Forgets everything learned.
func reset() -> void:
	_swings.clear()
	_dodge_streak = 0
	_interrupt_count = 0
	_full_hand_sec = 0.0


## Early dodges in a row.
func get_dodge_streak() -> int:
	return _dodge_streak


## Times the player interrupted the boss.
func get_interrupt_count() -> int:
	return _interrupt_count


## Seconds the player's hand has been continuously full.
func get_full_hand_sec() -> float:
	return _full_hand_sec


## {feint_chance (0..1), quick_cut_bias (>= 1, 1 = off), single_point_bonus (>= 0, 0 = off)}.
func get_modifiers() -> Dictionary:
	var chance: float = 0.0
	var threshold: int = int(_rules["dodge_streak_threshold"])
	if _dodge_streak >= threshold:
		chance = float(_rules["feint_chance_base"]) \
				+ float(_rules["feint_chance_per_dodge"]) * float(_dodge_streak - threshold)
		chance = clampf(chance, 0.0, float(_rules["feint_chance_max"]))
	var bias: float = 1.0
	if _full_hand_sec >= float(_rules["full_hand_seconds"]):
		bias = float(_rules["quick_cut_bias"])
	var bonus: float = 0.0
	if _interrupt_count >= int(_rules["interrupt_count_threshold"]):
		bonus = float(_rules["single_point_bonus"])
	return {"feint_chance": chance, "quick_cut_bias": bias, "single_point_bonus": bonus}

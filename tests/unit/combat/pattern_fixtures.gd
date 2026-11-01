extends RefCounted
## Test-only fixture factory for the pattern brain (P2.2): enemy_skills.json-shaped dictionaries built in code (no file
## I/O). These are NOT the Misty Forest roster (P2.3/P2.4); they exercise every anchor / followup / status / marker
## type the code knows, so the A4 tests can grow an enemy to any phase x skill count with data only.

const DM: Dictionary = {"type": "DIRECT_MANIFESTATION", "origin": "target_cells", "travel": "none", "impact": "thorns"}
const CT: Dictionary = {"type": "CASTER_TO_TARGET", "origin": "caster", "travel": "square_streak", "impact": "slash"}
const GP: Dictionary = {"type": "GROUND_PROPAGATION", "origin": "first_cell", "travel": "floor_run", "impact": "thorns"}
const SC: Dictionary = {"type": "SEQUENTIAL_CHAIN", "origin": "caster", "travel": "chain_spark", "impact": "burst", "chain_order": "authored"}


## Nine fixture skills, ids fx_1..fx_9 (every kind the model knows).
static func skills() -> Dictionary:
	return {
		"fx_1": {"pattern": {"offsets": [[0, 0]], "anchor": "on_player"}, "windup_sec": 0.4, "warning_sec": 0.9,
			"delivery": DM, "effects": {"damage": 8, "status": {"id": "root", "sec": 0.6}}, "recovery_sec": 0.6, "cooldown_sec": 3.0},
		"fx_2": {"pattern": {"offsets": [[0, 0], [1, 0]], "anchor": "on_player", "rotations": [0, 90, 180, 270]},
			"windup_sec": 0.5, "warning_sec": 1.0, "delivery": CT, "effects": {"damage": 14}, "recovery_sec": 0.6, "cooldown_sec": 2.8},
		"fx_3": {"pattern": {"offsets": [[0, 0], [1, 0], [0, 1]], "anchor": "on_player", "rotations": [0, 90, 180, 270]},
			"windup_sec": 0.5, "warning_sec": 1.1, "delivery": GP, "effects": {"damage": 10, "status": {"id": "fragile", "stacks": 1}},
			"recovery_sec": 0.8, "cooldown_sec": 3.0},
		"fx_4": {"kind": "marker", "pattern": {"anchor": "enemy_half_empty", "count": 1}, "windup_sec": 0.6, "delivery": DM,
			"effects": {"marker": {"life_sec": 12.0, "break_min_cells": 1}}, "recovery_sec": 0.6, "cooldown_sec": 8.0},
		"fx_5": {"pattern": {"offsets": [[0, 0], [1, 0], [2, 0]], "anchor": "row_of_anchor", "clip": true, "min_cells": 2, "start": "front", "must_cover_player": true},
			"windup_sec": 0.8, "warning_sec": 1.5, "delivery": GP, "effects": {"damage": 18, "status": {"id": "slow"}},
			"recovery_sec": 1.2, "cooldown_sec": 6.0, "interruptible": false},
		"fx_6": {"kind": "self", "windup_sec": 0.6, "delivery": DM, "effects": {"guard": {"amount": 6, "sec": 10, "while_markers": true}},
			"conditions": {"requires_anchor": 1}, "recovery_sec": 0.6, "cooldown_sec": 12.0},
		"fx_7": {"pattern": {"offsets": [[0, 0]], "anchor": "on_player"}, "windup_sec": 0.6, "warning_sec": 1.2, "delivery": SC,
			"effects": {"damage": 12}, "followup": {"offsets": [[0, -1], [0, 1]], "rotations": [0, 90], "relative_to": "first_cells",
			"warning_sec": 0.75, "effects": {"damage": 12}}, "recovery_sec": 0.8, "cooldown_sec": 4.5},
		"fx_8": {"pattern": {"offsets": [[0, 0], [1, 0]], "anchor": "on_player", "rotations": [0, 90]}, "windup_sec": 0.6, "warning_sec": 1.2,
			"delivery": CT, "effects": {"damage": 12}, "followup": {"offsets": [[0, 1], [1, 1]], "rotations": [0, 180], "relative_to": "first_cells",
			"warning_sec": 0.75, "show_with_first": true, "effects": {"damage": 12}}, "recovery_sec": 1.2, "cooldown_sec": 5.0, "interruptible": false},
		"fx_9": {"pattern": {"offsets": [[-1, 0], [0, 0], [1, 0], [0, 1]], "anchor": "near_player", "rotations": [0, 90, 180, 270], "must_cover_player": true},
			"windup_sec": 0.9, "warning_sec": 1.6, "delivery": SC, "effects": {"damage": 22},
			"followup": {"offsets": [[0, 0]], "relative_to": "first_center", "warning_sec": 0.75, "requires_anchor": 1, "effects": {"damage": 14}},
			"recovery_sec": 1.5, "cooldown_sec": 0.0, "interruptible": false},
	}


## An enemy with [param phase_count] phases; phase i has the first skills_per_phase[i] fixture skills; the last phase
## forces its last skill every 3rd cast. Thresholds evenly spaced below 1.0.
static func enemy(phase_count: int, skills_per_phase: Array) -> Dictionary:
	var phases: Array = []
	for i: int in phase_count:
		var ids: Array = []
		for k: int in int(skills_per_phase[i]):
			ids.append("fx_%d" % (k + 1))
		var phase: Dictionary = {"id": "p%d" % (i + 1), "enter_hp_ratio": 1.0 - float(i) / float(phase_count + 1),
			"skills": ids, "mechanic": ids[ids.size() - 1], "transition": {"sec": 1.5}}
		if i > 0:
			phase["transition"] = {"sec": 1.5, "on_enter": [{"skill": "fx_4"}]}
		if i == phase_count - 1:
			phase["every_nth"] = {"skill": ids[ids.size() - 1], "n": 3}
		phases.append(phase)
	return {"tier": "warden", "phases": phases}


## The full data dictionary with [param enemies] (id -> enemy dict).
static func data(enemies: Dictionary) -> Dictionary:
	return {"version": 1, "skills": skills(), "enemies": enemies}


## A config holding enemy "fx3x7" (3 phases x 7 skills at the end) and "fx4x9" (4 phases x 9 skills at the end).
static func config() -> EnemySkillsConfig:
	return EnemySkillsConfig.from_dictionary(data({
		"fx3x7": enemy(3, [4, 6, 7]),
		"fx4x9": enemy(4, [4, 6, 8, 9]),
		"fx_single": {"skills": ["fx_1", "fx_2", "fx_3"]},
	}))


## Board of a ch1 arena shape (side coords missing cells, as arenas.json).
static func arena(id: String) -> BoardGrid:
	match id:
		"rect":
			return BoardGrid.new(4, 3)
		"u_shape":
			return BoardGrid.new(4, 3, [Vector2i(0, 1)] as Array[Vector2i])
		"cross":
			return BoardGrid.new(4, 4, [Vector2i(0, 0), Vector2i(0, 3), Vector2i(3, 0), Vector2i(3, 3)] as Array[Vector2i])
		"staircase":
			return BoardGrid.new(4, 4, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)] as Array[Vector2i])
	return BoardGrid.new(3, 3)


## Headless match of [param ctrl] for [param seconds] in [param step] slices: status, mover and controller clocks, then
## the bot. [param bot]: "dodge" = the perfect dodger (when its cell is red it walks FairnessCheck.escape_path),
## "still" = never moves. [param on_tick] Callable(t: float) runs after each slice (damage the enemy, assertions...).
static func run(ctrl: PatternController, state: CombatState, status: StatusEffects, mover: UnitMover, seconds: float,
		bot: String, step: float = 0.05, on_tick: Callable = Callable()) -> void:
	var t: float = 0.0
	while t < seconds - 0.000001 and not state.is_player_dead():
		status.tick(step, state)
		mover.tick(step)
		ctrl.tick(step)
		t += step
		if bot == "dodge":
			var red: Array[Vector2i] = ctrl.telegraph_cells()
			if red.has(state.player_cell) and mover.is_ready():
				var path: Array[Vector2i] = FairnessCheck.escape_path(state.grid, state.player_cell, red, 99.0, 0.0, 0.45, 0.0, ctrl.fairness_env())
				if not path.is_empty():
					mover.try_step(path[0] - state.player_cell)
		if on_tick.is_valid():
			on_tick.call(t)


## A controller + its world on [param grid] for [param enemy_id] of [param config].
static func world(grid: BoardGrid, config: EnemySkillsConfig, enemy_id: String, seed_value: int, enemy_hp: float = 300.0) -> Dictionary:
	var state: CombatState = CombatState.new(grid, 100.0, enemy_hp)
	var status: StatusEffects = StatusEffects.new()
	var step_cd: float = CombatConfig.new().step_cooldown_for(grid)
	var mover: UnitMover = UnitMover.new(state, CombatState.Side.PLAYER, step_cd)
	mover.set_status(status)
	var ctrl: PatternController = PatternController.new(state, grid, config, enemy_id, status, seed_value)
	ctrl.player_step_cd = step_cd
	ctrl.player_step_left_fn = Callable(mover, "get_cooldown_remaining")
	return {"state": state, "status": status, "mover": mover, "ctrl": ctrl}

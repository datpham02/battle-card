extends SceneTree
## PatternController lifecycle + PatternBrain choice (phase 2 spec 3.5-3.8, P2.2 test list).
## Covers: snapshot (cells hit = red cells at warning start, player moving away is missed); a cell that starts cracking
## mid-warning loses red at once and is not hit (F7); D9 interrupt (cancel + cooldown x0.5) and non-interruptible skills;
## floor tempo scales windup / cooldown but never warning_sec; F4 no Root on a Frozen player; phases at thresholds with
## the HP floor (one hit never skips a phase) and 1.5 s invulnerability (D14), warnings cleared, on_enter skill; followup
## shows a new warning; show_with_first queued lane; every_nth; AI weights and seeded determinism; A4: a 3-phase x
## 7-skill and a 4-phase x 9-skill fixture enemy run every phase with no code change.
## Pure logic: no file I/O (fixtures built in code).
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_controller_test.gd

const Fx = preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_snapshot_cells_hit_equal_red()
	test_crack_mid_warning_drops_red()
	test_interrupt_rules()
	test_tempo_never_scales_warning()
	test_no_root_on_frozen_player()
	test_phase_threshold_floor_and_invulnerability()
	test_followup_and_queued_lane()
	test_ai_weights_and_seeded_choice()
	test_a4_fixtures_run_all_phases()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _one_skill_config(skill_id: String, extra_skill: Dictionary = {}) -> EnemySkillsConfig:
	var skills: Dictionary = Fx.skills()
	for k: String in extra_skill:
		(skills[skill_id] as Dictionary)[k] = extra_skill[k]
	return EnemySkillsConfig.from_dictionary({"skills": skills, "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": [skill_id]}}})


func _tick_until(w: Dictionary, stage: int, limit: float = 5.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		ctrl.tick(STEP)
		t += STEP
		if ctrl.get_stage() == stage:
			return true
	return false


func test_snapshot_cells_hit_equal_red() -> void:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill_config("fx_1"), "solo", 1)
	var state: CombatState = w["state"]
	_check("warning starts", _tick_until(w, PatternController.Stage.WARNING))
	var red: Array[Vector2i] = (w["ctrl"] as PatternController).telegraph_cells()
	_check("red = player cell at warning start", red == [state.player_cell])
	state.set_player_cell(Vector2i(0, 0))
	_check("resolves", _tick_until(w, PatternController.Stage.RECOVERY))
	var last: Dictionary = (w["ctrl"] as PatternController).event_log.back()
	_check("hit cells = snapshot, not the new player cell", last["cells"] == red and not bool(last["hit"]))
	_check("dodged: no damage", is_equal_approx(state.player_hp, 100.0))
	_check("standing still is hit next time", _tick_until(w, PatternController.Stage.WARNING, 6.0))
	_tick_until(w, PatternController.Stage.RECOVERY)
	_check("8 damage + Root", is_equal_approx(state.player_hp, 92.0) and (w["status"] as StatusEffects).is_rooted(P))


func test_crack_mid_warning_drops_red() -> void:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill_config("fx_1"), "solo", 2)
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	_tick_until(w, PatternController.Stage.WARNING)
	var cells: Array[Vector2i] = [state.player_cell]
	status.apply_drop(P, cells, 0.8, 1.2)
	_check("cracking cell loses red at once", (w["ctrl"] as PatternController).telegraph_cells().is_empty())
	state.set_player_cell(state.player_cell + Vector2i(-1, 0))
	_tick_until(w, PatternController.Stage.RECOVERY)
	var last: Dictionary = (w["ctrl"] as PatternController).event_log.back()
	_check("locked cell not hit", (last["cells"] as Array).is_empty() and is_equal_approx(state.player_hp, 100.0))


func test_interrupt_rules() -> void:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill_config("fx_1"), "solo", 3)
	var ctrl: PatternController = w["ctrl"]
	_tick_until(w, PatternController.Stage.WINDUP)
	_check("interruptible windup cancelled", ctrl.on_enemy_hit() and ctrl.get_stage() == PatternController.Stage.IDLE)
	_check("cancel cooldown = 3.0 x 0.5", is_equal_approx(ctrl.cooldown_left("fx_1"), 1.5))
	_tick_until(w, PatternController.Stage.WARNING)
	_check("interrupt during warning clears red", ctrl.on_enemy_hit() and ctrl.telegraph_cells().is_empty())
	var w2: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill_config("fx_8"), "solo", 3)
	var ctrl2: PatternController = w2["ctrl"]
	_tick_until(w2, PatternController.Stage.WARNING)
	_check("non-interruptible skill ignores the hit (D9)", not ctrl2.on_enemy_hit() and ctrl2.get_stage() == PatternController.Stage.WARNING)


func test_tempo_never_scales_warning() -> void:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill_config("fx_1", {"windup_sec": 1.0, "cooldown_sec": 2.0}), "solo", 4)
	var ctrl: PatternController = w["ctrl"]
	ctrl.tempo_mult = 0.8
	var seen: Array = []
	ctrl.warning_started.connect(func(_id: String, _c: Array[Vector2i], _q: Array[Vector2i], sec: float) -> void: seen.append(sec))
	_tick_until(w, PatternController.Stage.WINDUP)
	var t: float = 0.0
	while ctrl.get_stage() == PatternController.Stage.WINDUP and t < 3.0:
		ctrl.tick(STEP)
		t += STEP
	_check("windup x0.8 (1.0 -> 0.8 s)", absf(t - 0.8) < STEP + 0.001, str(t))
	_check("warning_sec unchanged 0.9", seen.size() == 1 and is_equal_approx(float(seen[0]), 0.9))
	_tick_until(w, PatternController.Stage.RECOVERY)
	_check("cooldown x0.8 (2.0 -> 1.6 s)", absf(ctrl.cooldown_left("fx_1") - 1.6) < 0.001, str(ctrl.cooldown_left("fx_1")))


func test_no_root_on_frozen_player() -> void:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill_config("fx_1"), "solo", 5)
	var status: StatusEffects = w["status"]
	_tick_until(w, PatternController.Stage.WARNING)
	status.pin(P, 0.05)
	_tick_until(w, PatternController.Stage.RECOVERY)
	_check("hit lands but no Root inside the cc grace (F4)", not status.is_rooted(P) and (w["state"] as CombatState).player_hp < 100.0)


func test_phase_threshold_floor_and_invulnerability() -> void:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), Fx.config(), "fx3x7", 6, 400.0)
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	_check("floor at phase 2 threshold (0.75)", is_equal_approx(state.enemy_hp_floor, 300.0))
	_tick_until(w, PatternController.Stage.WARNING)
	# Markers placed in phase 1 (fx_4 is a phase-1 skill) live on through the transition; on_enter adds one more.
	var markers_before: int = ctrl.marker_cells().size()
	var cleared: Array = []
	ctrl.warning_cleared.connect(func(_id: String, reason: String) -> void: cleared.append(reason))
	state.damage_enemy(1000.0)
	_check("one big hit stops at the threshold", is_equal_approx(state.enemy_hp, 300.0))
	ctrl.tick(STEP)
	_check("transition starts, warning cleared", ctrl.get_stage() == PatternController.Stage.TRANSITION and cleared.has("phase") and ctrl.telegraph_cells().is_empty())
	_check("invulnerable 1.5 s (D14)", is_equal_approx(state.enemy_invulnerable_left, 1.5))
	state.damage_enemy(50.0)
	_check("no damage while invulnerable", is_equal_approx(state.enemy_hp, 300.0))
	var t: float = 0.0
	while ctrl.get_stage() == PatternController.Stage.TRANSITION and t < 3.0:
		ctrl.tick(STEP)
		t += STEP
	_check("transition lasts 1.5 s", absf(t - 1.5) < STEP + 0.001, str(t))
	_check("phase 2 active, next floor 0.5", ctrl.get_phase_index() == 1 and is_equal_approx(state.enemy_hp_floor, 200.0) and is_equal_approx(state.enemy_invulnerable_left, 0.0))
	_tick_until(w, PatternController.Stage.RECOVERY, 3.0)
	var first_in_phase: Dictionary = {}
	for e: Dictionary in ctrl.event_log:
		if str(e["event"]) == "resolve" and int(e["phase"]) == 1:
			first_in_phase = e
			break
	_check("on_enter marker placed (first cast of the phase, one more marker)",
		str(first_in_phase.get("skill", "")) == "fx_4" and ctrl.marker_cells().size() == markers_before + 1,
		"%d -> %d %s" % [markers_before, ctrl.marker_cells().size(), str(first_in_phase)])


func test_followup_and_queued_lane() -> void:
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill_config("fx_7"), "solo", 7)
	var ctrl: PatternController = w["ctrl"]
	var warnings: Array = []
	ctrl.warning_started.connect(func(_id: String, c: Array[Vector2i], _q: Array[Vector2i], sec: float) -> void: warnings.append([c, sec]))
	Fx.run(ctrl, w["state"], w["status"], w["mover"], 3.5, "dodge")
	_check("followup shows a NEW warning (0.75 s)", warnings.size() >= 2 and is_equal_approx(float(warnings[1][1]), 0.75), str(warnings))
	if warnings.size() >= 2:
		var first: Vector2i = (warnings[0][0] as Array)[0]
		var two: Array = warnings[1][0] as Array
		_check("followup = two cells on one axis around the first", two.size() == 2 and (two[0] - first) == -(two[1] - first))
	var w2: Dictionary = Fx.world(BoardGrid.new(3, 3), _one_skill_config("fx_8"), "solo", 8)
	var queued_seen: Array = []
	(w2["ctrl"] as PatternController).warning_started.connect(func(_id: String, _c: Array[Vector2i], q: Array[Vector2i], _s: float) -> void: queued_seen.append(q))
	_tick_until(w2, PatternController.Stage.WARNING)
	_check("show_with_first: queued lane shown from the start", not (queued_seen[0] as Array).is_empty() and (w2["ctrl"] as PatternController).queued_cells() == queued_seen[0])


func test_ai_weights_and_seeded_choice() -> void:
	var ai: Dictionary = EnemySkillsConfig.DEFAULT_AI.duplicate()
	var skill: Dictionary = {"id": "a", "weight": 1.0}
	var plan: Dictionary = {"cells": [Vector2i(1, 1)]}
	var ctx: Dictionary = {"player_cell": Vector2i(1, 1), "player_still_sec": 2.0, "last_skill": "a", "mechanic": "a"}
	_check("weights multiply: 1.2 x 0.45 x 1.25", is_equal_approx(PatternBrain.weight_for(skill, plan, ctx, ai), 1.2 * 0.45 * 1.25))
	ctx["player_still_sec"] = 1.0
	ctx["last_skill"] = ""
	ctx["mechanic"] = ""
	_check("no factor when moving", is_equal_approx(PatternBrain.weight_for(skill, plan, ctx, ai), 1.0))
	var cands: Array[Dictionary] = []
	for id: String in ["a", "b", "c"]:
		var plans: Array[Dictionary] = [{"cells": [Vector2i(1, 1)]}]
		cands.append({"skill": {"id": id, "weight": 1.0 if id != "c" else 4.0}, "plans": plans})
	var seq: Array = [[], []]
	for run: int in 2:
		var brain: PatternBrain = PatternBrain.new(ai, 42)
		for i: int in 200:
			seq[run].append(str(brain.choose(cands, {"player_cell": Vector2i(1, 1)})["skill"]["id"]))
	_check("same seed, same choices", seq[0] == seq[1])
	_check("weight 4 picked most", (seq[0] as Array).count("c") > (seq[0] as Array).count("a") * 2)
	var forced: Dictionary = PatternBrain.new(ai, 1).choose(cands, {"player_cell": Vector2i(1, 1), "forced_skill": "b"})
	_check("every_nth forced skill wins", str(forced["skill"]["id"]) == "b")


func _run_enemy(enemy_id: String, grid: BoardGrid, seed_value: int) -> Dictionary:
	var w: Dictionary = Fx.world(grid, Fx.config(), enemy_id, seed_value, 400.0)
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	var phases: int = (ctrl.get_enemy()["phases"] as Array).size()
	# Every 12 s the player knocks the enemy to the next threshold (through the HP floor).
	var hurt: Callable = func(t: float) -> void:
		if fmod(t + 0.0001, 12.0) < STEP:
			state.damage_enemy(400.0)
	Fx.run(ctrl, state, w["status"], w["mover"], 12.0 * float(phases) + 6.0, "dodge", STEP, hurt)
	var per_phase: Dictionary = {}
	var used: Dictionary = {}
	for e: Dictionary in ctrl.event_log:
		if str(e["event"]) == "resolve":
			per_phase[int(e["phase"])] = int(per_phase.get(int(e["phase"]), 0)) + 1
			used[str(e["skill"])] = true
	return {"ctrl": ctrl, "state": state, "per_phase": per_phase, "used": used, "phases": phases}


func test_a4_fixtures_run_all_phases() -> void:
	for spec: Array in [["fx3x7", 3, 7], ["fx4x9", 4, 9]]:
		var r: Dictionary = _run_enemy(str(spec[0]), Fx.arena("cross"), 11)
		var ctrl: PatternController = r["ctrl"]
		_check("%s reaches its last phase" % spec[0], ctrl.get_phase_index() == int(spec[1]) - 1)
		var every_phase: bool = true
		for i: int in int(spec[1]):
			every_phase = every_phase and int((r["per_phase"] as Dictionary).get(i, 0)) > 0
		_check("%s casts in every phase" % spec[0], every_phase, str(r["per_phase"]))
		_check("%s uses most of its %d skills" % [spec[0], spec[2]], (r["used"] as Dictionary).size() >= int(spec[2]) - 2, str((r["used"] as Dictionary).keys()))
		_check("%s perfect dodger untouched" % spec[0], is_equal_approx((r["state"] as CombatState).player_hp, 100.0), str((r["state"] as CombatState).player_hp))

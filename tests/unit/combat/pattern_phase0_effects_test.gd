extends SceneTree
## Monster Skill Phase 0 (design §5.2): the effects opened to enemy skills through EnemySkillsConfig, each reusing code
## that exists: zone burn (StatusEffects.ignite), mire / sand / fall (TileHazards), heal (CombatState.heal_enemy, at once
## or over time, lost on a stun), consume_burn, push / pull (CutEffects, R3 when stopped short, the per-side push ICD),
## evade / shroud (through TraitHost's one-point hooks), move.to far_cell, poison as a status; invalid data is refused
## with a problem line; the VFX feedback of a result (vfx_feedback) carries the skill's delivery or the fallback.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_phase0_effects_test.gd

const Fx = preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05
const R3: Dictionary = {"r3": {"damage": 8.0, "pin_sec": 0.6}, "icd_sec": 1.0}

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_zone_burn_ignites_cells()
	test_zone_mire_sand_fall_through_hazards()
	test_zone_without_hazards_is_skipped()
	test_heal_at_once_and_over_time()
	test_heal_over_time_lost_on_stun()
	test_consume_burn_clears_and_heals()
	test_push_moves_and_slams_when_blocked()
	test_push_icd_and_pull()
	test_evade_and_shroud_through_trait_host()
	test_move_far_cell()
	test_poison_status_from_skill()
	test_invalid_data_refused()
	test_vfx_feedback()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- fixtures -----------------------------------------------------------------------------------------------------------

func _attack(effects: Dictionary, pattern: Dictionary = {"offsets": [[0, 0]], "anchor": "on_player"}, extra: Dictionary = {}) -> Dictionary:
	var s: Dictionary = {"pattern": pattern, "windup_sec": 0.4, "warning_sec": 0.9, "delivery": Fx.DM, "effects": effects,
		"recovery_sec": 0.3, "cooldown_sec": 3.0}
	for k: String in extra:
		s[k] = extra[k]
	return s


func _self(effects: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var s: Dictionary = {"kind": "self", "windup_sec": 0.4, "delivery": Fx.DM, "effects": effects, "recovery_sec": 0.3, "cooldown_sec": 3.0}
	for k: String in extra:
		s[k] = extra[k]
	return s


func _config(skills: Dictionary) -> EnemySkillsConfig:
	return EnemySkillsConfig.from_dictionary({"skills": skills, "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": skills.keys()}}})


func _world(config: EnemySkillsConfig, with_hazards: bool = true) -> Dictionary:
	var grid: BoardGrid = BoardGrid.new(3, 3)
	var w: Dictionary = Fx.world(grid, config, "solo", 11)
	var ctrl: PatternController = w["ctrl"]
	if with_hazards:
		var hazards: TileHazards = TileHazards.new(grid, 11)
		hazards.bind_state(w["state"])
		ctrl.hazards = hazards
		w["hazards"] = hazards
	return w


func _run(w: Dictionary, seconds: float) -> void:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < seconds - 0.000001:
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		if w.has("hazards"):
			(w["hazards"] as TileHazards).tick(STEP, w["state"])
		ctrl.tick(STEP)
		t += STEP


func _tick_until(w: Dictionary, stage: int, limit: float = 5.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		_run(w, STEP)
		t += STEP
		if ctrl.get_stage() == stage:
			return true
	return false


# Runs until the first resolve (RECOVERY) and returns the controller's last event.
func _resolve_once(w: Dictionary) -> Dictionary:
	_tick_until(w, PatternController.Stage.RECOVERY, 6.0)
	var log: Array[Dictionary] = (w["ctrl"] as PatternController).event_log
	return log.back() if not log.is_empty() else {}


# --- tests ---------------------------------------------------------------------------------------------------------------

func test_zone_burn_ignites_cells() -> void:
	# Arrange: a 2-cell bar on the player, no damage, a 2 s burn zone.
	var w: Dictionary = _world(_config({"kindle": _attack({"damage": 0, "zone": {"id": "burn", "sec": 2.0, "tick_sec": 0.5, "damage": 2.0}},
		{"offsets": [[0, 0], [1, 0]], "anchor": "on_player", "rotations": [0]})}))
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	var hp_before: float = state.player_hp
	# Act
	var last: Dictionary = _resolve_once(w)
	# Assert: both cells burn for 2 s; the player standing on one takes the burn ticks (the row_burner rule).
	var cells: Array = last.get("cells", [])
	_check("burn: two cells resolved", cells.size() == 2, str(cells))
	var lit: bool = not cells.is_empty()
	for c: Vector2i in cells:
		lit = lit and status.is_burning(c)
	_check("burn: the resolved cells are burning", lit)
	_check("burn: 2 s left", not cells.is_empty() and absf(status.get_burn_left(cells[0]) - 2.0) < 0.11, str(status.get_burn_left(cells[0]) if not cells.is_empty() else -1.0))
	_run(w, 0.5)
	_check("burn: the player on the lit cell takes a tick", state.player_hp < hp_before, str(state.player_hp))


func test_zone_mire_sand_fall_through_hazards() -> void:
	# Arrange: three near_player zones (one cell beside the player each), run one at a time.
	var near: Dictionary = {"offsets": [[0, 0]], "anchor": "near_player", "exclude_player": true}
	var w: Dictionary = _world(_config({"slime": _attack({"damage": 0, "zone": {"id": "mire", "sec": 4.0}}, near)}))
	var hazards: TileHazards = w["hazards"]
	var last: Dictionary = _resolve_once(w)
	var cell: Vector2i = (last.get("cells", []) as Array)[0] if not (last.get("cells", []) as Array).is_empty() else BoardGrid.NO_CELL
	_check("mire: the cell beside the player is mire", cell != BoardGrid.NO_CELL and hazards.is_mire(P, cell) and absf(hazards.mire_left(P, cell) - 4.0) < 0.11, str(cell))
	_check("mire: the player's own cell is not", not hazards.is_mire(P, (w["state"] as CombatState).player_cell))
	var w2: Dictionary = _world(_config({"spray": _attack({"damage": 0, "zone": {"id": "sand", "sec": 3.0, "warn_sec": 0.0}}, near)}))
	var hz2: TileHazards = w2["hazards"]
	var last2: Dictionary = _resolve_once(w2)
	var cell2: Vector2i = (last2.get("cells", []) as Array)[0] if not (last2.get("cells", []) as Array).is_empty() else BoardGrid.NO_CELL
	_run(w2, STEP)
	_check("sand: the cell is sand (or warning) after the strike", cell2 != BoardGrid.NO_CELL and (hz2.is_sanded(P, cell2) or hz2.is_sand_warning(P, cell2)), str(cell2))
	var w3: Dictionary = _world(_config({"gale": _attack({"damage": 0, "zone": {"id": "fall", "fall_sec": 2.0, "warn_sec": 0.5}}, near)}))
	var hz3: TileHazards = w3["hazards"]
	var last3: Dictionary = _resolve_once(w3)
	var cell3: Vector2i = (last3.get("cells", []) as Array)[0] if not (last3.get("cells", []) as Array).is_empty() else BoardGrid.NO_CELL
	_check("fall: the cell cracks (crumble warning) after the strike", cell3 != BoardGrid.NO_CELL and hz3.is_crumble_warning(P, cell3), str(cell3))
	_run(w3, 0.6)
	_check("fall: then it is fallen", cell3 != BoardGrid.NO_CELL and hz3.is_fallen(P, cell3))


func test_zone_without_hazards_is_skipped() -> void:
	var near: Dictionary = {"offsets": [[0, 0]], "anchor": "near_player", "exclude_player": true}
	var w: Dictionary = _world(_config({"slime": _attack({"damage": 3, "zone": {"id": "mire", "sec": 4.0}}, near)}), false)
	var last: Dictionary = _resolve_once(w)
	_check("no hazards: the strike still resolves, the zone is skipped", not last.is_empty() and str(last.get("event", "")) == "resolve")
	_check("no hazards: no crash, controller idle or recovering", (w["ctrl"] as PatternController).get_stage() != PatternController.Stage.WARNING)


func test_heal_at_once_and_over_time() -> void:
	var w: Dictionary = _world(_config({"mend": _self({"heal": {"amount": 30.0}})}))
	var state: CombatState = w["state"]
	state.enemy_hp = 200.0
	_resolve_once(w)
	_check("heal: +30 at once", is_equal_approx(state.enemy_hp, 230.0), str(state.enemy_hp))
	var w2: Dictionary = _world(_config({"regrow": _self({"heal": {"ratio": 0.1, "sec": 2.0}})}))
	var state2: CombatState = w2["state"]
	state2.enemy_hp = 200.0
	_tick_until(w2, PatternController.Stage.RECOVERY)
	var at_resolve: float = state2.enemy_hp
	_run(w2, 1.0)
	_check("heal over time: about half of 10 % (30) after 1 s", absf(state2.enemy_hp - (at_resolve + 15.0)) < 1.0, str(state2.enemy_hp))
	_run(w2, 1.5)
	_check("heal over time: the full 30 after 2 s, then stops", absf(state2.enemy_hp - 230.0) < 0.6, str(state2.enemy_hp))
	_check("heal: capped at max HP", state2.enemy_hp <= state2.enemy_max_hp)


func test_heal_over_time_lost_on_stun() -> void:
	var w: Dictionary = _world(_config({"regrow": _self({"heal": {"amount": 40.0, "sec": 2.0}})}))
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	state.enemy_hp = 200.0
	_tick_until(w, PatternController.Stage.RECOVERY)
	_run(w, 0.5)
	ctrl.stun(1.0)
	var at_stun: float = state.enemy_hp
	_run(w, 2.0)
	_check("heal over time: a stun ends it (about 10 of 40 gained)", absf(at_stun - 210.0) < 1.5 and is_equal_approx(state.enemy_hp, at_stun), "%s %s" % [at_stun, state.enemy_hp])


func test_consume_burn_clears_and_heals() -> void:
	var w: Dictionary = _world(_config({"devour": _self({"consume_burn": {"heal_per_cell": 6.0}})}))
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	state.enemy_hp = 200.0
	status.ignite([Vector2i(0, 0), Vector2i(5, 2)] as Array[Vector2i], 5.0, 0.5, 2.0)
	var last: Dictionary = _resolve_once(w)
	_check("consume_burn: both halves' fires are out", status.burning_cells().is_empty())
	_check("consume_burn: +6 per cell", is_equal_approx(state.enemy_hp, 212.0), str(state.enemy_hp))
	_check("consume_burn: logged", str(last.get("event", "")) == "resolve")


func test_push_moves_and_slams_when_blocked() -> void:
	# Arrange: a strike of 5 that shoves 1 cell away from the divider; the player at (1,1) of the 3x3 half.
	var w: Dictionary = _world(_config({"shove": _attack({"damage": 5, "push": {"cells": 1}})}))
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	ctrl.reactions = R3
	state.set_player_cell(Vector2i(1, 1))
	_resolve_once(w)
	_check("push: moved one cell away from the divider", state.player_cell == Vector2i(0, 1), str(state.player_cell))
	_check("push: 5 damage, no slam", is_equal_approx(state.player_hp, 95.0), str(state.player_hp))
	# Act: the next shove at the edge is stopped short: R3 (8 damage + 0.6 s pin) through the shared reaction gate.
	_run(w, 3.0)
	_resolve_once(w)
	_check("push blocked: stays at the edge", state.player_cell == Vector2i(0, 1), str(state.player_cell))
	_check("push blocked: R3 slam 5 + 8", is_equal_approx(state.player_hp, 82.0), str(state.player_hp))
	_check("push blocked: R3 pins the player", status.is_pinned(P) or status.get_pin_left(P) > 0.0 or status.since_lock_ended(P) < 0.5)
	var last: Dictionary = ctrl.event_log.back()
	_check("push blocked: logged 13 damage", is_equal_approx(float(last["damage"]), 13.0), str(last))


func test_push_icd_and_pull() -> void:
	# Push ICD: two shoves inside 2 s, the second is refused (no move, no slam), the damage still lands.
	var w: Dictionary = _world(_config({"shove": _attack({"damage": 5, "push": {"cells": 1}}, {"offsets": [[0, 0]], "anchor": "on_player"}, {"cooldown_sec": 0.5, "recovery_sec": 0.1})}))
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	ctrl.reactions = R3
	ctrl.push_icd_sec = 3.0
	state.set_player_cell(Vector2i(2, 1))
	_resolve_once(w)
	_check("push icd: first shove moves", state.player_cell == Vector2i(1, 1), str(state.player_cell))
	_tick_until(w, PatternController.Stage.WARNING, 3.0)
	_resolve_once(w)
	_check("push icd: second shove inside 3 s does not move", state.player_cell == Vector2i(1, 1), str(state.player_cell))
	_check("push icd: both strikes' damage landed", is_equal_approx(state.player_hp, 90.0), str(state.player_hp))
	# Pull: toward the enemy's cast origin (the divider side).
	var w2: Dictionary = _world(_config({"hook": _attack({"damage": 0, "pull": {"cells": 1}})}))
	var state2: CombatState = w2["state"]
	state2.set_player_cell(Vector2i(0, 1))
	_resolve_once(w2)
	_check("pull: moved one cell toward the enemy", state2.player_cell == Vector2i(1, 1), str(state2.player_cell))


func test_evade_and_shroud_through_trait_host() -> void:
	var w: Dictionary = _world(_config({"veil": _self({"evade": {"sec": 1.0}, "shroud": {"sec": 2.0}})}))
	var ctrl: PatternController = w["ctrl"]
	var host: TraitHost = TraitHost.new({"status": w["status"], "state": w["state"]}, [], 1)
	host.extra_untargetable_fn = Callable(ctrl, "is_evading")
	host.extra_forecast_blocked_fn = Callable(ctrl, "is_shrouded")
	_check("evade: not before the skill", not host.is_boss_untargetable() and not host.hit_forecast_blocked())
	_resolve_once(w)
	_check("evade: untargetable through the host after the skill", host.is_boss_untargetable() and ctrl.is_evading())
	_check("shroud: forecast hidden through the host", host.hit_forecast_blocked() and ctrl.is_shrouded())
	_run(w, 1.1)
	_check("evade: over after 1 s, shroud still on", not host.is_boss_untargetable() and host.hit_forecast_blocked())
	_run(w, 1.0)
	_check("shroud: over after 2 s", not host.hit_forecast_blocked())
	host.teardown_all()
	_check("teardown clears the extra hooks", not host.extra_untargetable_fn.is_valid())


func test_move_far_cell() -> void:
	var w: Dictionary = _world(_config({"step": _self({"move": {"to": "far_cell"}})}))
	var state: CombatState = w["state"]
	var ctrl: PatternController = w["ctrl"]
	var from: Vector2i = state.enemy_cell
	_tick_until(w, PatternController.Stage.WINDUP)
	var target: Vector2i = ctrl.move_target_cell()
	_check("far_cell: a target is shown during the windup", target != BoardGrid.NO_CELL)
	_resolve_once(w)
	var dist: int = absi(state.enemy_cell.x - from.x) + absi(state.enemy_cell.y - from.y)
	_check("far_cell: landed on the announced cell", state.enemy_cell == target, "%s %s" % [state.enemy_cell, target])
	_check("far_cell: at the largest step distance of the 3x3 half (2 from the centre)", dist == 2, str(dist))


func test_poison_status_from_skill() -> void:
	var w: Dictionary = _world(_config({"sting": _attack({"damage": 4, "status": {"id": "poison", "sec": 3.0, "tick_sec": 0.5, "damage": 1.5}})}))
	var status: StatusEffects = w["status"]
	var state: CombatState = w["state"]
	var last: Dictionary = _resolve_once(w)
	_check("poison skill: hit for 4 and poisoned", is_equal_approx(state.player_hp, 96.0) and status.is_poisoned(P), str(state.player_hp))
	_run(w, 3.0)
	_check("poison skill: 6 ticks of 1.5 = 9 more", is_equal_approx(state.player_hp, 87.0) and not status.is_poisoned(P), str(state.player_hp))
	_check("poison skill: event logged", str(last.get("event", "")) == "resolve")
	# The defaults block feeds a skill that names only the id.
	var cfg: EnemySkillsConfig = _config({"gnaw": _attack({"damage": 1, "status": {"id": "poison"}})})
	var st: Dictionary = (cfg.skills["gnaw"] as Dictionary)["effects"]["status"]
	_check("poison skill: statuses.poison defaults 3 / 0.5 / 1", is_equal_approx(float(st["sec"]), 3.0) and is_equal_approx(float(st["tick_sec"]), 0.5) and is_equal_approx(float(st["damage"]), 1.0), str(st))


func test_invalid_data_refused() -> void:
	var bad: Dictionary = {
		"lava": _attack({"damage": 1, "zone": {"id": "lava"}}),
		"side": _attack({"damage": 1, "zone": {"id": "burn", "side": "both"}}),
		"heal0": _self({"heal": {}}),
		"push0": _attack({"damage": 1, "push": {"cells": 0}}),
		"evade0": _self({"evade": {"sec": 0}}),
		"poison0": _attack({"damage": 1, "status": {"id": "poison", "sec": 0}}),
		"w_unknown": _attack({"damage": 1}, {"offsets": [[0, 0]], "anchor": "on_player"}, {"weights": {"moon": {"x": 2}}}),
		"w_zero": _attack({"damage": 1}, {"offsets": [[0, 0]], "anchor": "on_player"}, {"weights": {"player_status": {"fragile": 0}}}),
		"far": _self({"move": {"to": "nowhere"}}),
		"ok": _attack({"damage": 1, "zone": {"id": "burn"}, "push": {"cells": 1}}, {"offsets": [[0, 0]], "anchor": "on_player"},
			{"weights": {"player_status": {"fragile": 2.0}, "allies_alive": 1.5}}),
	}
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": bad, "enemies": {"solo": {"skills": bad.keys()}}})
	for id: String in ["lava", "side", "heal0", "push0", "evade0", "poison0", "w_unknown", "w_zero", "far"]:
		_check("refused: " + id, not cfg.skills.has(id))
	_check("kept: the valid skill", cfg.skills.has("ok") and (cfg.skills["ok"] as Dictionary)["weights"]["allies_alive"] == 1.5)
	_check("problems name every refusal", cfg.problems.size() >= 9, str(cfg.problems.size()))


func test_vfx_feedback() -> void:
	var attack: Dictionary = {"skill_id": "x", "kind": "attack", "cells": [Vector2i(1, 1)], "hit": true, "damage": 8.0, "delivery": Fx.CT}
	var fb: Dictionary = PatternController.vfx_feedback(attack)
	_check("vfx: attack feedback carries cells, hit, damage, delivery", fb["cells"] == [Vector2i(1, 1)] and bool(fb["hit"]) and is_equal_approx(float(fb["damage"]), 8.0)
		and str((fb["delivery"] as Dictionary)["type"]) == "CASTER_TO_TARGET" and not bool(fb["delivery_fallback"]))
	var missing: Dictionary = {"skill_id": "y", "kind": "attack", "cells": [], "hit": false, "damage": 0.0}
	var fb2: Dictionary = PatternController.vfx_feedback(missing)
	_check("vfx: a missing delivery falls back safely and says so", bool(fb2["delivery_fallback"]) and (fb2["delivery"] as Dictionary).has("type"))
	_check("vfx: a self skill draws nothing", PatternController.vfx_feedback({"skill_id": "z", "kind": "self", "cells": []}).is_empty())
	# The controller's results carry kind + delivery.
	var w: Dictionary = _world(_config({"jab": _attack({"damage": 1})}))
	var results: Array = []
	(w["ctrl"] as PatternController).skill_resolved.connect(func(_id: String, r: Dictionary) -> void: results.append(r))
	_resolve_once(w)
	_check("vfx: skill_resolved result has kind and delivery", results.size() == 1 and str(results[0]["kind"]) == "attack" and str((results[0]["delivery"] as Dictionary)["impact"]) == "thorns")

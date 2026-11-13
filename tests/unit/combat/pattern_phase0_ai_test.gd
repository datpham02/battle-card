extends SceneTree
## Monster Skill Phase 0 (design §5.2, §11 step 0): the pattern AI's new conditions and weights, read inside the existing
## filter / score (no second planner): player_status, player_on_zone, self_status, player_steps_since, burning_cells,
## max_zone_cells (the zone budget), the ally_* conditions through allies_fn (inert without allies), the `weights`
## blocks in PatternBrain.weight_for, and the phase keys traits / brain_set / tempo_mult parsed by EnemySkillsConfig.
## A skill without the new keys scores exactly as before (the 11 forest enemies are untouched).
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_phase0_ai_test.gd

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
	test_condition_player_status()
	test_condition_player_on_zone()
	test_condition_player_steps_since_resets_per_skill()
	test_condition_zone_budget_and_burning_cells()
	test_condition_allies_inert_without_allies()
	test_condition_self_status()
	test_weights_pure()
	test_weights_absent_unchanged()
	test_phase_keys_parsed()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _attack(conditions: Dictionary, effects: Dictionary = {"damage": 1}) -> Dictionary:
	return {"pattern": {"offsets": [[0, 0]], "anchor": "on_player"}, "windup_sec": 0.3, "warning_sec": 0.9, "delivery": Fx.DM,
		"effects": effects, "recovery_sec": 0.2, "cooldown_sec": 1.0, "conditions": conditions}


func _world(skill: Dictionary) -> Dictionary:
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": {"s": skill}, "enemies": {"solo": {"ai": {"noise": 0.0}, "skills": ["s"]}}})
	var grid: BoardGrid = BoardGrid.new(3, 3)
	var w: Dictionary = Fx.world(grid, cfg, "solo", 5)
	var hazards: TileHazards = TileHazards.new(grid, 5)
	hazards.bind_state(w["state"])
	(w["ctrl"] as PatternController).hazards = hazards
	w["hazards"] = hazards
	return w


# True when a warning starts within [param limit] seconds (the skill was chosen).
func _chosen(w: Dictionary, limit: float = 2.0) -> bool:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < limit:
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		(w["hazards"] as TileHazards).tick(STEP, w["state"])
		ctrl.tick(STEP)
		t += STEP
		if ctrl.get_stage() == PatternController.Stage.WARNING:
			return true
	return false


func _finish(w: Dictionary) -> void:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < 3.0 and ctrl.get_stage() != PatternController.Stage.RECOVERY and ctrl.get_stage() != PatternController.Stage.IDLE:
		(w["status"] as StatusEffects).tick(STEP, w["state"])
		ctrl.tick(STEP)
		t += STEP


func test_condition_player_status() -> void:
	var w: Dictionary = _world(_attack({"player_status": "fragile"}))
	_check("player_status: not chosen without Rạn", not _chosen(w))
	(w["status"] as StatusEffects).apply_fragile(P, 1)
	_check("player_status: chosen with Rạn", _chosen(w))
	var w2: Dictionary = _world(_attack({"player_status": ["slow", "poison"]}))
	_check("player_status list: not chosen", not _chosen(w2))
	(w2["status"] as StatusEffects).poison(P, 5.0, 0.5, 1.0)
	_check("player_status list: any-of matches poison", _chosen(w2))


func test_condition_player_on_zone() -> void:
	var w: Dictionary = _world(_attack({"player_on_zone": "mire"}))
	_check("player_on_zone: not chosen on dry ground", not _chosen(w))
	(w["hazards"] as TileHazards).add_mire(P, [(w["state"] as CombatState).player_cell] as Array[Vector2i], 10.0)
	_check("player_on_zone: chosen on mire", _chosen(w))
	var w2: Dictionary = _world(_attack({"player_on_zone": ["burn"]}))
	(w2["status"] as StatusEffects).ignite([(w2["state"] as CombatState).player_cell] as Array[Vector2i], 10.0, 0.5, 0.0)
	_check("player_on_zone: chosen on a burning cell", _chosen(w2))


func test_condition_player_steps_since_resets_per_skill() -> void:
	var w: Dictionary = _world(_attack({"player_steps_since": 2}))
	var ctrl: PatternController = w["ctrl"]
	_check("steps: not chosen before any step", not _chosen(w))
	ctrl.on_player_stepped()
	_check("steps: one step is not enough", not _chosen(w))
	ctrl.on_player_stepped()
	_check("steps: chosen after 2 steps", _chosen(w))
	_finish(w)
	_check("steps: the counter resets when the skill finishes", not _chosen(w, 2.5))
	ctrl.on_player_stepped()
	ctrl.on_player_stepped()
	_check("steps: and counts again", _chosen(w))


func test_condition_zone_budget_and_burning_cells() -> void:
	var w: Dictionary = _world(_attack({"max_zone_cells": {"burn": 2}}, {"damage": 0, "zone": {"id": "burn"}}))
	var status: StatusEffects = w["status"]
	status.ignite([Vector2i(0, 0), Vector2i(0, 2)] as Array[Vector2i], 10.0, 0.5, 0.0)
	_check("budget: 2 burning cells on the player's half block a burn skill capped at 2", not _chosen(w))
	status.clear_burn([Vector2i(0, 2)] as Array[Vector2i])
	_check("budget: 1 burning cell lets it through", _chosen(w))
	var w2: Dictionary = _world(_attack({"burning_cells": 2}))
	_check("burning_cells: not chosen with none", not _chosen(w2))
	(w2["status"] as StatusEffects).ignite([Vector2i(5, 0), Vector2i(3, 2)] as Array[Vector2i], 10.0, 0.5, 0.0)
	_check("burning_cells: chosen with 2 anywhere (the Fire Eater's devour)", _chosen(w2))


func test_condition_allies_inert_without_allies() -> void:
	var w: Dictionary = _world(_attack({"allies_alive_min": 1}))
	_check("allies: a single-enemy engine has no allies: not chosen", not _chosen(w))
	(w["ctrl"] as PatternController).allies_fn = func() -> Dictionary: return {"alive": 1, "died_within_sec": INF, "min_hp_ratio": 1.0}
	_check("allies: chosen when allies_fn reports one", _chosen(w))
	var w2: Dictionary = _world(_attack({"ally_died_within_sec": 3.0}))
	(w2["ctrl"] as PatternController).allies_fn = func() -> Dictionary: return {"alive": 1, "died_within_sec": 5.0, "min_hp_ratio": 0.5}
	_check("allies: ally_died_within_sec 3 with a death 5 s ago: not chosen", not _chosen(w2))
	(w2["ctrl"] as PatternController).allies_fn = func() -> Dictionary: return {"alive": 1, "died_within_sec": 1.0, "min_hp_ratio": 0.5}
	_check("allies: chosen with a death 1 s ago", _chosen(w2))
	var w3: Dictionary = _world(_attack({"ally_hp_below": 0.4, "allies_alive_max": 2}))
	(w3["ctrl"] as PatternController).allies_fn = func() -> Dictionary: return {"alive": 3, "died_within_sec": INF, "min_hp_ratio": 0.3}
	_check("allies: allies_alive_max 2 with 3 alive: not chosen", not _chosen(w3))
	(w3["ctrl"] as PatternController).allies_fn = func() -> Dictionary: return {"alive": 2, "died_within_sec": INF, "min_hp_ratio": 0.3}
	_check("allies: 2 alive, one below 0.4: chosen", _chosen(w3))


func test_condition_self_status() -> void:
	var w: Dictionary = _world(_attack({"self_status": "guard"}))
	_check("self_status: not chosen without guard", not _chosen(w))
	(w["status"] as StatusEffects).guard(E, 3.0, 10.0)
	_check("self_status: chosen while guarded", _chosen(w))


func test_weights_pure() -> void:
	var ai: Dictionary = EnemySkillsConfig.DEFAULT_AI.duplicate()
	var skill: Dictionary = {"id": "s", "weight": 1.0, "weights": {"player_status": {"fragile": 2.0, "slow": 3.0}, "player_on_zone": {"mire": 1.5},
		"self_status": {"haste": 4.0}, "allies_alive": 1.5}}
	var plan: Dictionary = {"cells": [Vector2i(9, 9)]}
	var base: Dictionary = {"player_cell": Vector2i(0, 0), "player_still_sec": 0.0, "last_skill": "", "mechanic": ""}
	_check("weights: nothing matching = 1.0", is_equal_approx(PatternBrain.weight_for(skill, plan, base, ai), 1.0))
	var ctx: Dictionary = base.duplicate()
	ctx["player_statuses"] = ["fragile"] as Array[String]
	ctx["allies_alive"] = 1
	_check("weights: fragile x2 and an ally x1.5 = 3.0", is_equal_approx(PatternBrain.weight_for(skill, plan, ctx, ai), 3.0))
	ctx["player_statuses"] = ["fragile", "slow"] as Array[String]
	ctx["player_zones"] = ["mire"] as Array[String]
	ctx["self_statuses"] = ["haste"] as Array[String]
	_check("weights: every matching entry multiplies (2 x 3 x 1.5 x 4 x 1.5 = 54)", is_equal_approx(PatternBrain.weight_for(skill, plan, ctx, ai), 54.0))
	ctx["allies_alive"] = 0
	_check("weights: allies_alive needs at least one ally", is_equal_approx(PatternBrain.weight_for(skill, plan, ctx, ai), 36.0))


func test_weights_absent_unchanged() -> void:
	var ai: Dictionary = EnemySkillsConfig.DEFAULT_AI.duplicate()
	var skill: Dictionary = {"id": "s", "weight": 2.0}
	var ctx: Dictionary = {"player_cell": Vector2i(0, 0), "player_still_sec": 0.0, "last_skill": "", "mechanic": "",
		"player_statuses": ["fragile", "slow"] as Array[String], "player_zones": ["mire"] as Array[String], "allies_alive": 3}
	_check("no weights block: the fight's state changes nothing", is_equal_approx(PatternBrain.weight_for(skill, {"cells": []}, ctx, ai), 2.0))
	# The 11 Misty Forest enemies carry no `weights` key, so they score exactly as before Phase 0. (Hellfire skills added
	# from Phase 1 on use `weights` by design; the check is scoped to the forest roster, not the whole file.)
	var shipped: EnemySkillsConfig = EnemySkillsConfig.load_from_file()
	var forest: Array[String] = ["goblin_scout", "rootling", "mossbound_sentry", "greycap_sporeling", "goblin_archer", "dire_wolf",
		"wolf_alpha", "ancient_root_sentinel", "mistbriar_matron", "goblin_warlock", "forest_witch"]
	var weighted: Array[String] = []
	for enemy_id: String in forest:
		for phase: Dictionary in shipped.get_enemy(enemy_id).get("phases", []):
			for sid: String in phase["skills"]:
				if not (shipped.skills[sid] as Dictionary).get("weights", {}).is_empty() and not weighted.has(sid):
					weighted.append(sid)
	_check("shipped forest roster: no weights, no problems", weighted.is_empty() and shipped.problems.is_empty(), "%s %s" % [weighted, shipped.problems])


func test_phase_keys_parsed() -> void:
	var data: Dictionary = {"skills": Fx.skills(), "enemies": {"boss": {"phases": [
		{"id": "p1", "skills": ["fx_1"]},
		{"id": "p2", "enter_hp_ratio": 0.5, "skills": ["fx_1", "fx_2"], "traits": [{"id": "row_burner", "params": {"interval_sec": 5}}, "bad", {"params": {}}],
			"brain_set": "aggressive", "tempo_mult": 0.8},
		{"id": "p3", "enter_hp_ratio": 0.2, "skills": ["fx_1"], "tempo_mult": -1},
	]}}}
	var cfg: EnemySkillsConfig = EnemySkillsConfig.from_dictionary(data)
	var w: Dictionary = Fx.world(BoardGrid.new(3, 3), cfg, "boss", 1)
	var ctrl: PatternController = w["ctrl"]
	_check("phases: p1 has no traits, no brain set, tempo 1", ctrl.phase_traits(0).is_empty() and ctrl.phase_brain_set(0).is_empty() and is_equal_approx(ctrl.phase_tempo_mult(0), 1.0))
	var traits: Array = ctrl.phase_traits(1)
	_check("phases: p2 keeps the one {id, params} entry", traits.size() == 1 and str((traits[0] as Dictionary)["id"]) == "row_burner"
		and int(((traits[0] as Dictionary)["params"] as Dictionary)["interval_sec"]) == 5, str(traits))
	_check("phases: p2 brain_set and tempo_mult", ctrl.phase_brain_set(1) == "aggressive" and is_equal_approx(ctrl.phase_tempo_mult(1), 0.8))
	_check("phases: p3 bad tempo falls back to 1.0 with a problem", is_equal_approx(ctrl.phase_tempo_mult(2), 1.0))
	var dropped: int = 0
	var tempo_problems: int = 0
	for p: String in cfg.problems:
		if p.contains("traits entry"):
			dropped += 1
		if p.contains("tempo_mult"):
			tempo_problems += 1
	_check("phases: the two bad trait entries and the bad tempo are reported", dropped == 2 and tempo_problems == 1, str(cfg.problems))
	_check("phases: the current phase is read when no index is given", ctrl.phase_tempo_mult() == ctrl.phase_tempo_mult(0))
	_check("phases: an index out of range gives the defaults", ctrl.phase_traits(9).is_empty() and is_equal_approx(ctrl.phase_tempo_mult(9), 1.0))

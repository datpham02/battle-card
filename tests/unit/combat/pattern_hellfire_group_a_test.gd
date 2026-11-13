extends SceneTree
## Monster Skill Phase 1 group A "Dấu Tro" (MONSTER-SKILL-PHASE1-HELLFIRE-PLAN.md §5 A): the shipped enemy_skills.json
## entries of imp / ember_hound / ash_golem behave as designed, on the shipped forge / caldera grids:
## - imp_ash_dart: 6 damage and 1 Rạn (fragile) on a hit;
## - hound_ember_charge: 10, or 15 against a Fragile hero (Phase 0 G1 spends the stack); weight x2 while the hero is Fragile;
## - golem_ash_mantle: Guard +3 for 4 s on the ENEMY side, which SwingArbiter adds to the boss's flat defense and a
##   pierce_defense card ignores; weight 0.3 alone, x4 (= 1.2) with an ally; windup interruptible with a 0.8 s stun;
## - golem_cinder_slam: 2x2, 12 damage, not interruptible.
## Run: godot --headless --path . -s res://tests/unit/combat/pattern_hellfire_group_a_test.gd

const Fx := preload("res://tests/unit/combat/pattern_fixtures.gd")
const P: int = CombatState.Side.PLAYER
const E: int = CombatState.Side.ENEMY
const STEP: float = 0.05

var fails: int = 0
var _cfg: EnemySkillsConfig
var _library: ArenaLibrary


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_cfg = EnemySkillsConfig.load_from_file()
	_library = ArenaLibrary.load_from_file()
	_check("shipped enemy_skills.json has no problems", _cfg.problems.is_empty(), str(_cfg.problems))
	test_data_shape()
	test_imp_dart_applies_fragile()
	test_hound_charge_x1_5_against_fragile()
	test_hound_weight_doubles_on_fragile()
	test_golem_mantle_guards_enemy_side_and_armour_math()
	test_golem_mantle_weight_alone_and_with_ally()
	test_golem_mantle_interrupt_stuns()
	test_golem_slam_is_2x2_uninterruptible()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _grid(shape: String, seed_value: int = 0) -> BoardGrid:
	return ArenaLibrary.grid_for_spec({"shape": shape}, _library, seed_value)


func _world(enemy_id: String, shape: String, seed_value: int = 1) -> Dictionary:
	var w: Dictionary = Fx.world(_grid(shape, seed_value), _cfg, enemy_id, seed_value, 1000.0)
	(w["status"] as StatusEffects).configure_keywords(1.5, 3, 3, 24.0)  # combat.json numbers
	return w


func _run(w: Dictionary, seconds: float) -> void:
	Fx.run(w["ctrl"], w["state"], w["status"], w["mover"], seconds, "still", STEP)


# Runs the standing-still bot until [param skill_id] resolves with a HIT (or [param limit] s pass). Returns the event.
func _until_hit(w: Dictionary, skill_id: String, limit: float = 20.0) -> Dictionary:
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	var seen: int = ctrl.event_log.size()
	while t < limit:
		_run(w, STEP)
		t += STEP
		for i: int in range(seen, ctrl.event_log.size()):
			var ev: Dictionary = ctrl.event_log[i]
			if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == skill_id and bool(ev.get("hit", false)):
				return ev
		seen = ctrl.event_log.size()
	return {}


func test_data_shape() -> void:
	for id: String in ["imp", "ember_hound", "ash_golem"]:
		_check("enemy %s loaded" % id, not _cfg.get_enemy(id).is_empty())
	var imp: Dictionary = _cfg.get_enemy("imp")
	_check("imp: dart + sidestep, sidestep weight 0.6 by override", (imp["phases"][0]["skills"] as Array) == ["imp_ash_dart", "shared_sidestep"]
		and is_equal_approx(float(_cfg.skill_for_phase("shared_sidestep", imp["phases"][0])["weight"]), 0.6))
	_check("hound: charge only", (_cfg.get_enemy("ember_hound")["phases"][0]["skills"] as Array) == ["hound_ember_charge"])
	_check("golem: mantle + slam", (_cfg.get_enemy("ash_golem")["phases"][0]["skills"] as Array) == ["golem_ash_mantle", "golem_cinder_slam"])
	for id: String in ["imp_ash_dart", "hound_ember_charge", "golem_ash_mantle", "golem_cinder_slam", "shared_sidestep"]:
		var s: Dictionary = _cfg.skills[id]
		_check("%s has name / counter keys" % id, str(s["name_key"]) == "enemy_skill.%s.name" % id and str(s["counter_key"]) == "enemy_skill.%s.counter" % id)
		_check("%s names its delivery" % id, (s["delivery"] as Dictionary).has("type"))


func test_imp_dart_applies_fragile() -> void:
	var w: Dictionary = _world("imp", "forge")
	var state: CombatState = w["state"]
	var status: StatusEffects = w["status"]
	var ev: Dictionary = _until_hit(w, "imp_ash_dart")
	_check("imp: dart hits the standing hero", not ev.is_empty())
	_check("imp: dart damage from data (%s)" % _dmg("imp_ash_dart"), not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg("imp_ash_dart")), str(ev))
	_check("imp: 1 Rạn on the hero", status.fragile_stacks(P) == 1, str(status.fragile_stacks(P)))
	_check("imp: no other damage source (hero 100 - dart)", is_equal_approx(state.player_hp, 100.0 - _dmg("imp_ash_dart")), str(state.player_hp))


func test_hound_charge_x1_5_against_fragile() -> void:
	# Plain: 10.
	var w: Dictionary = _world("ember_hound", "caldera")
	var ev: Dictionary = _until_hit(w, "hound_ember_charge")
	_check("hound: charge damage without Rạn", not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg("hound_ember_charge")), str(ev))
	# Against a Fragile hero (the Imp's mark): 15, the stack spent (Phase 0 G1).
	var w2: Dictionary = _world("ember_hound", "caldera", 2)
	var status: StatusEffects = w2["status"]
	status.apply_fragile(P, 1)
	var ev2: Dictionary = _until_hit(w2, "hound_ember_charge")
	_check("hound: x1.5 against Rạn", not ev2.is_empty() and is_equal_approx(float(ev2["damage"]), 1.5 * _dmg("hound_ember_charge")), str(ev2))
	_check("hound: the Rạn stack is spent", status.fragile_stacks(P) == 0)
	_check("hound: hero 100 - 1.5 x charge, nothing else", is_equal_approx((w2["state"] as CombatState).player_hp, 100.0 - 1.5 * _dmg("hound_ember_charge")), str((w2["state"] as CombatState).player_hp))


func test_hound_weight_doubles_on_fragile() -> void:
	var skill: Dictionary = _cfg.skills["hound_ember_charge"]
	var base: Dictionary = {"player_cell": Vector2i(0, 0), "player_still_sec": 0.0, "last_skill": "", "mechanic": ""}
	var plain: float = PatternBrain.weight_for(skill, {"cells": []}, base, _cfg.ai)
	var ctx: Dictionary = base.duplicate()
	ctx["player_statuses"] = ["fragile"] as Array[String]
	var marked: float = PatternBrain.weight_for(skill, {"cells": []}, ctx, _cfg.ai)
	_check("hound: weight 1.0 plain, 2.0 while the hero is Fragile", is_equal_approx(plain, 1.0) and is_equal_approx(marked, 2.0), "%s %s" % [plain, marked])


func test_golem_mantle_guards_enemy_side_and_armour_math() -> void:
	var w: Dictionary = _world("ash_golem", "forge")
	var status: StatusEffects = w["status"]
	var ctrl: PatternController = w["ctrl"]
	# Run until the mantle resolves (seeded choice between mantle 0.3 and slam 1.0).
	var t: float = 0.0
	var done: bool = false
	while t < 40.0 and not done:
		_run(w, STEP)
		t += STEP
		for ev: Dictionary in ctrl.event_log:
			if str(ev.get("event", "")) == "resolve" and str(ev.get("skill", "")) == "golem_ash_mantle":
				done = true
	_check("golem: mantle resolved within 40 s", done)
	_check("golem: Guard +3 on the ENEMY side, about 4 s", is_equal_approx(status.guard_amount(E), 3.0) and status.get_guard_left(E) > 3.9 and status.get_guard_left(E) <= 4.0,
		"%s %s" % [status.guard_amount(E), status.get_guard_left(E)])
	_check("golem: the hero has no Guard", is_equal_approx(status.guard_amount(P), 0.0))
	# Armour math through the real card path (defense_test.gd fixtures): SwingArbiter hands CutEffects
	# `target_defense` = boss_defense + Guard (swing_arbiter.gd:344); a 7-per-cell slash on the Golem (defense 3) loses
	# 3 + 3 Guard = 6 -> 1 per cell; a pierce_defense card ignores all of it.
	var state: CombatState = w["state"]
	var cut_config: CutConfig = CutConfig.new()
	var cards: SkillConfig = SkillConfig.from_dictionary({"cards": {
		"sw": {"effect": "damage", "damage_per_cell": 7.0, "implemented": true, "upgrade": {}},
		"pierce": {"effect": "damage", "damage_per_cell": 7.0, "pierce_defense": true, "implemented": true, "upgrade": {}},
	}})
	var cells: Array[Vector2i] = [state.enemy_cell]
	var defense: float = 3.0 + status.guard_amount(E)
	var r_plain: Dictionary = CutEffects.apply(state, state.grid, P, cells, "sw", cut_config, cards, null, Callable(), 1, Callable(), Callable(), {"target_defense": defense})
	_check("golem: plain card 7 loses defense 3 + Guard 3 = 1", bool(r_plain["hit"]) and is_equal_approx(float(r_plain["damage"]), 1.0)
		and is_equal_approx(float(r_plain["defense_applied"]), 6.0), str(r_plain.get("damage")))
	var r_pierce: Dictionary = CutEffects.apply(state, state.grid, P, cells, "pierce", cut_config, cards, null, Callable(), 1, Callable(), Callable(), {"target_defense": defense})
	_check("golem: pierce card ignores defense and Guard (7)", bool(r_pierce["hit"]) and is_equal_approx(float(r_pierce["damage"]), 7.0)
		and float(r_pierce["defense_applied"]) == 0.0, str(r_pierce.get("damage")))
	# Guard ends on its own.
	_run(w, 4.1)
	_check("golem: Guard gone after 4 s", status.guard_amount(E) == 0.0)


func test_golem_mantle_weight_alone_and_with_ally() -> void:
	var skill: Dictionary = _cfg.skills["golem_ash_mantle"]
	var base: Dictionary = {"player_cell": Vector2i(0, 0), "player_still_sec": 0.0, "last_skill": "", "mechanic": ""}
	var alone: float = PatternBrain.weight_for(skill, {"cells": []}, base, _cfg.ai)
	var ctx: Dictionary = base.duplicate()
	ctx["allies_alive"] = 1
	var pack: float = PatternBrain.weight_for(skill, {"cells": []}, ctx, _cfg.ai)
	_check("golem: mantle weight 0.3 alone, 1.2 with an ally", is_equal_approx(alone, 0.3) and is_equal_approx(pack, 1.2), "%s %s" % [alone, pack])
	var slam: float = PatternBrain.weight_for(_cfg.skills["golem_cinder_slam"], {"cells": []}, base, _cfg.ai)
	_check("golem: slam outweighs the mantle alone (no mantle spam)", slam > alone * 3.0, str(slam))


func test_golem_mantle_interrupt_stuns() -> void:
	var skill: Dictionary = _cfg.skills["golem_ash_mantle"]
	_check("golem: mantle interruptible with a 0.8 s stun", bool(skill["interruptible"]) and is_equal_approx(float(skill["interrupt_stun_sec"]), 0.8))
	# Force the choice: a config where the Golem only knows the mantle.
	var only: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": {"golem_ash_mantle": _raw_skill("golem_ash_mantle")},
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ["golem_ash_mantle"]}}})
	var w: Dictionary = Fx.world(_grid("forge"), only, "g", 1, 1000.0)
	var ctrl: PatternController = w["ctrl"]
	var status: StatusEffects = w["status"]
	var t: float = 0.0
	while t < 3.0 and ctrl.get_stage() != PatternController.Stage.WINDUP:
		_run(w, STEP)
		t += STEP
	_check("golem: mantle winds up", ctrl.get_stage() == PatternController.Stage.WINDUP)
	_check("golem: the floor shows the blinking interrupt tell", ctrl.interrupt_tell())
	_check("golem: a hit interrupts it", ctrl.on_enemy_hit())
	_check("golem: stunned 0.8 s, no Guard", ctrl.get_stage() == PatternController.Stage.STUNNED and status.guard_amount(E) == 0.0)


func test_golem_slam_is_2x2_uninterruptible() -> void:
	var skill: Dictionary = _cfg.skills["golem_cinder_slam"]
	_check("golem: slam 2x2 near the hero, must cover", (skill["pattern"]["offsets"] as Array).size() == 4 and str(skill["pattern"]["anchor"]) == "near_player"
		and bool(skill["pattern"]["must_cover_player"]))
	_check("golem: slam not interruptible, recovery 1.2", not bool(skill["interruptible"]) and is_equal_approx(float(skill["recovery_sec"]), 1.2))
	var only: EnemySkillsConfig = EnemySkillsConfig.from_dictionary({"skills": {"golem_cinder_slam": _raw_skill("golem_cinder_slam")},
		"enemies": {"g": {"ai": {"noise": 0.0}, "skills": ["golem_cinder_slam"]}}})
	var w: Dictionary = Fx.world(_grid("forge"), only, "g", 1, 1000.0)
	var ctrl: PatternController = w["ctrl"]
	var t: float = 0.0
	while t < 3.0 and ctrl.get_stage() != PatternController.Stage.WARNING:
		_run(w, STEP)
		t += STEP
	_check("golem: slam warns 4 red cells including the hero's", ctrl.telegraph_cells().size() == 4 and ctrl.telegraph_cells().has((w["state"] as CombatState).player_cell), str(ctrl.telegraph_cells()))
	_check("golem: a hit does not interrupt the slam", not ctrl.on_enemy_hit())
	var ev: Dictionary = _until_hit(w, "golem_cinder_slam", 5.0)
	_check("golem: slam hits for its data damage", not ev.is_empty() and is_equal_approx(float(ev["damage"]), _dmg("golem_cinder_slam")), str(ev))


# The raw JSON of a shipped skill (EnemySkillsConfig keeps the normalized form; the file is re-read for a fixture).
func _raw_skill(id: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemySkillsConfig.DEFAULT_PATH))
	return (data["skills"] as Dictionary)[id]


# Monster Skill Phase 1 tuning (2026-11-13): hit damage is read from the shipped data (set by
# production/qa/evidence/monster-skill-hellfire/tuning/scale_hellfire_damage.py); the test checks the pipeline delivers it.
func _dmg(id: String, followup: bool = false) -> float:
	var s: Dictionary = _cfg.skills[id]
	var fx: Dictionary = ((s["followup"] as Dictionary)["effects"] if followup else s["effects"]) as Dictionary
	return float(fx.get("damage", 0.0))

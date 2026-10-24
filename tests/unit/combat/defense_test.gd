extends SceneTree
# Story 023 part A (combat side): flat boss_defense (min 1, pierce_defense skips, burn/Han ignore),
# RunConfig match keys, SwingArbiter wiring, BossBrain boss_min_runes.
var fails: int = 0
func ck(name: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name)

func mk(enemy_hp: float = 1000.0) -> CombatState:
	return CombatState.new(BoardGrid.new(3, 3), 1000.0, enemy_hp, Vector2i(1, 1), Vector2i(4, 1))

func _init() -> void:
	var cc: CutConfig = CutConfig.new()
	var grid: BoardGrid = BoardGrid.new(3, 3)
	var cfg: CombatConfig = CombatConfig.load_from_file()
	var E: int = CombatState.Side.ENEMY
	var P: int = CombatState.Side.PLAYER
	var hit: Array[Vector2i] = [Vector2i(4, 1), Vector2i(4, 0)]
	var sc: SkillConfig = SkillConfig.from_dictionary({"cards": {
		"sw": {"effect": "damage", "damage_per_cell": 7.0, "implemented": true, "upgrade": {}},
		"pierce": {"effect": "damage", "damage_per_cell": 7.0, "pierce_defense": true, "implemented": true, "upgrade": {}},
		"push": {"effect": "push", "damage_per_cell": 4.0, "push_cells": 1, "implemented": true, "upgrade": {}},
		"fz3": {"effect": "frost", "frost_stacks": 3, "implemented": true, "upgrade": {}},
		"burn": {"effect": "burn", "burn_duration_sec": 1.0, "burn_tick_sec": 0.5, "burn_damage_per_tick": 2.0, "implemented": true, "upgrade": {}},
		"kiem_khi": {"effect": "damage", "damage_per_cell": 6.0, "implemented": true, "upgrade": {}},
	}})
	# --- flat defense
	var r: Dictionary = CutEffects.apply(mk(), grid, P, hit, "sw", cc, sc, null, Callable(), 1, Callable(), Callable(), {"target_defense": 5.0})
	ck("defense 5: 14 -> 9", is_equal_approx(float(r["damage"]), 9.0) and is_equal_approx(float(r["defense_applied"]), 5.0))
	r = CutEffects.apply(mk(), grid, P, hit, "sw", cc, sc, null, Callable(), 1, Callable(), Callable(), {"target_defense": 12.0})
	ck("defense 12 (Bong Ma): 14 -> 2", is_equal_approx(float(r["damage"]), 2.0))
	var s: CombatState = mk()
	r = CutEffects.apply(s, grid, P, hit, "sw", cc, sc, null, Callable(), 1, Callable(), Callable(), {"target_defense": 50.0})
	ck("defense 50: minimum 1 lands", is_equal_approx(float(r["damage"]), 1.0) and is_equal_approx(s.enemy_hp, 999.0))
	r = CutEffects.apply(mk(), grid, P, hit, "pierce", cc, sc, null, Callable(), 1, Callable(), Callable(), {"target_defense": 50.0})
	ck("pierce_defense skips: 14", is_equal_approx(float(r["damage"]), 14.0) and float(r["defense_applied"]) == 0.0)
	r = CutEffects.apply(mk(), grid, P, hit, "push", cc, sc, null, Callable(), 1, Callable(), Callable(), {"target_defense": 3.0})
	ck("push hit also defended: 8 -> 5, still pushed", is_equal_approx(float(r["damage"]), 5.0) and bool(r["pushed"]))
	r = CutEffects.apply(mk(), grid, P, hit, "sw", cc, sc, null)
	ck("no options = no defense (old call)", is_equal_approx(float(r["damage"]), 14.0))
	r = CutEffects.apply(mk(), grid, P, hit, "sw", cc, sc, null, Callable(), 1, Callable(), Callable(), {"target_defense": 0.0})
	ck("defense 0 = none", is_equal_approx(float(r["damage"]), 14.0))
	# defense applies to the ENEMY side only (boss hits on the player are not reduced)
	var sp: CombatState = mk()
	var pcells: Array[Vector2i] = [Vector2i(1, 1)]
	r = CutEffects.apply(sp, grid, E, pcells, "sw", cc, sc, null, Callable(), 1, Callable(), Callable(), {"target_defense": 5.0})
	ck("boss hit on player: no defense (7)", is_equal_approx(float(r["damage"]), 7.0))
	# burn ticks ignore defense
	var fx: StatusEffects = StatusEffects.new()
	cfg.configure_status(fx)
	var sb: CombatState = mk()
	r = CutEffects.apply(sb, grid, P, hit, "burn", cc, sc, fx, Callable(), 1, Callable(), Callable(), {"target_defense": 50.0})
	fx.tick(1.0, sb)
	ck("burn ticks ignore defense: 2 ticks x 2 = 4", bool(r["burning"]) and is_equal_approx(sb.enemy_hp, 996.0))
	# Han burst ignores defense
	var sf: CombatState = mk()
	r = CutEffects.apply(sf, grid, P, hit, "fz3", cc, sc, fx, Callable(), 1, Callable(), Callable(), {"target_defense": 50.0})
	ck("Han burst ignores defense: 24", is_equal_approx(float(r["frost_burst"]), 24.0) and is_equal_approx(sf.enemy_hp, 976.0))
	# --- RunConfig match keys
	var rc: RunConfig = RunConfig.from_dictionary({"matches": [
		{"id": "a", "boss_defense": 12, "boss_min_runes": 3},
		{"id": "b"},
		{"id": "c", "boss_defense": -4, "boss_min_runes": -1},
	]})
	ck("match keys parsed", float(rc.matches[0]["boss_defense"]) == 12.0 and int(rc.matches[0]["boss_min_runes"]) == 3)
	ck("match keys default 0", float(rc.matches[1]["boss_defense"]) == 0.0 and int(rc.matches[1]["boss_min_runes"]) == 0)
	ck("match keys clamped", float(rc.matches[2]["boss_defense"]) == 0.0 and int(rc.matches[2]["boss_min_runes"]) == 0)
	ck("MATCH_KEYS lists them", RunConfig.MATCH_KEYS.has("boss_defense") and RunConfig.MATCH_KEYS.has("boss_min_runes"))
	# --- SwingArbiter passes boss_defense + execute_ratio
	var sa: CombatState = mk(100.0)
	var pa: CutActor = CutActor.new(cc, P)
	var ba: CutActor = CutActor.new(cc, E)
	var arb: SwingArbiter = SwingArbiter.new(sa, grid, pa, ba, cc, sc, fx)
	arb.boss_defense = 4.0
	var got: Array = []
	arb.swing_resolved.connect(func(side: int, res: Dictionary) -> void: got.append([side, res]))
	pa.begin_swing(hit, "sw", true)
	arb.tick(pa.get_duration() + 0.01)
	ck("arbiter: player hit defended 14 -> 10", got.size() == 1 and is_equal_approx(float(got[0][1]["damage"]), 10.0))
	got.clear()
	ba.begin_swing(pcells, "sw", false)
	arb.tick(ba.get_duration() + 0.01)
	ck("arbiter: boss hit on player undefended 7", got.size() == 1 and is_equal_approx(float(got[0][1]["damage"]), 7.0))
	# --- BossBrain boss_min_runes
	var bcfg: BossBrainConfig = BossBrainConfig.load_from_file()
	ck("min_runes_penalty weight loaded", float(bcfg.weights_for("balanced").get("min_runes_penalty", -1.0)) == 3.0)
	_brain_checks(bcfg, cc)
	print("FAILS=%d" % fails)
	quit()


# On a 3x3 board one perimeter point already covers 3 cells, so the threshold under test is 5: with
# min_runes 5 the brain must prefer >= 5-cell cuts over the 3-4 cell ones it normally takes.
func _brain_checks(bcfg: BossBrainConfig, cc: CutConfig) -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var hold: HoldSlotsConfig = HoldSlotsConfig.load_from_file()
	if hold == null:
		hold = HoldSlotsConfig.new()
	var drops_cfg: FieldDropsConfig = FieldDropsConfig.load_from_file()
	var counts: Dictionary = {}
	for min_runes: int in [0, 5]:
		var small: int = 0
		var big: int = 0
		var total: int = 0
		for seed_value: int in 12:
			var grid: BoardGrid = BoardGrid.new(3, 3)
			var state: CombatState = CombatState.new(grid, 1000.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))
			var boss: BossController = BossController.new(state, grid, cc, sc, bcfg, drops_cfg, hold, seed_value)
			boss.get_brain().use_set("aggressive")
			boss.get_brain().min_runes = min_runes
			var pa: CutActor = CutActor.new(cc, CombatState.Side.PLAYER)
			var t: float = 0.0
			while t < 40.0:
				var before: bool = boss.get_actor().is_swinging()
				boss.tick(0.1, pa)
				t += 0.1
				if not before and boss.get_actor().is_swinging():
					var n: int = boss.get_actor().get_cells().size()
					total += 1
					if n < 5:
						small += 1
					else:
						big += 1
					boss.get_actor().cancel()
		counts[min_runes] = [small, big, total]
	print("  brain cuts {min_runes: [small, big, total]} = %s" % str(counts))
	ck("min_runes 0: brain does cut", int(counts[0][2]) > 0)
	ck("min_runes 5: brain still cuts", int(counts[5][2]) > 0)
	ck("min_runes 0 (aggressive): small cuts happen (%d)" % counts[0][0], int(counts[0][0]) > 0)
	ck("min_runes 5: fewer small cuts than with 0 (%d vs %d)" % [counts[5][0], counts[0][0]], int(counts[5][0]) < int(counts[0][0]))
	ck("min_runes 5: big cuts dominate (%d big / %d small)" % [counts[5][1], counts[5][0]], int(counts[5][1]) >= int(counts[5][0]) * 2)

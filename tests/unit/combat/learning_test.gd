extends SceneTree

const DT: float = 0.05
const SIM_SEC: float = 120.0

var _fails: int = 0


func _init() -> void:
	_counter_tests()
	_burn_avoid_test()
	var a: Dictionary = _sim(7, "aggressive", "dodge", false)
	var b: Dictionary = _sim(7, "aggressive", "dodge", false)
	_check("determinism with learning: hash %d vs %d, %d actions" % [a["hash"], b["hash"], a["log_len"]], a["hash"] == b["hash"])
	var feints_dodge: int = 0
	var feints_still: int = 0
	for s: int in [1, 2, 3]:
		feints_dodge += int(_sim(s, "aggressive", "dodge", false)["feints"])
		feints_still += int(_sim(s, "aggressive", "still", false)["feints"])
	_check("always-dodging player => feints > 0 (got %d over 3x120 s)" % feints_dodge, feints_dodge > 0)
	_check("never-dodging player => feints == 0 (got %d)" % feints_still, feints_still == 0)
	for set_name: String in ["balanced", "aggressive", "cautious"]:
		var skills: Dictionary = {}
		for s: int in [1, 2, 3]:
			var r: Dictionary = _sim(s, set_name, "still", true)
			for k: Variant in (r["skills"] as Dictionary).keys():
				skills[k] = int(skills.get(k, 0)) + int((r["skills"] as Dictionary)[k])
		print("skills 4-point hand %s: %s" % [set_name, str(skills)])
		if set_name != "balanced":
			_check("%s uses burn or pin (%s)" % [set_name, str(skills)], int(skills.get("hoa_tran", 0)) + int(skills.get("bang_phong", 0)) > 0)
	print("FAILS=%d" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(text: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_fails += 1


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in list:
		out.append(c as Vector2i)
	return out


func _counter_tests() -> void:
	var rules: Dictionary = BossBrainConfig.load_from_file().learning
	var l := BossLearning.new(rules)
	var cover: Array[Vector2i] = _cells([Vector2i(0, 0), Vector2i(1, 0)])
	var dodge: Callable = func() -> void:
		l.on_boss_swing_started(cover, Vector2i(0, 0))
		l.on_player_moved(Vector2i(0, 2))
		l.on_boss_swing_resolved(false)
		l.on_player_moved(Vector2i(0, 0))
	dodge.call()
	dodge.call()
	_check("2 dodges => chance 0", float(l.get_modifiers()["feint_chance"]) == 0.0)
	dodge.call()
	_check("3 dodges => base %.2f" % float(l.get_modifiers()["feint_chance"]), is_equal_approx(float(l.get_modifiers()["feint_chance"]), float(rules["feint_chance_base"])))
	dodge.call()
	var c4: float = float(l.get_modifiers()["feint_chance"])
	_check("4 dodges raises (%.2f)" % c4, is_equal_approx(c4, float(rules["feint_chance_base"]) + float(rules["feint_chance_per_dodge"])))
	for i: int in 10:
		dodge.call()
	_check("capped at max", is_equal_approx(float(l.get_modifiers()["feint_chance"]), float(rules["feint_chance_max"])))
	l.on_boss_swing_started(cover, Vector2i(0, 0))
	l.on_boss_swing_resolved(true)
	_check("a hit resets", l.get_dodge_streak() == 0 and float(l.get_modifiers()["feint_chance"]) == 0.0)
	dodge.call()
	l.on_boss_swing_started(cover, Vector2i(0, 0))
	l.on_boss_swing_resolved(false)
	_check("miss without dodge leaves streak (%d)" % l.get_dodge_streak(), l.get_dodge_streak() == 1)
	l.on_boss_swing_started(cover, Vector2i(0, 0))
	l.on_player_moved(Vector2i(1, 0))
	l.on_boss_swing_resolved(false)
	_check("moving inside the cells is no dodge", l.get_dodge_streak() == 1)
	var h := BossLearning.new(rules)
	h.tick(3.9, true)
	_check("full hand 3.9 s => bias 1.0", float(h.get_modifiers()["quick_cut_bias"]) == 1.0)
	h.tick(0.1, true)
	_check("full hand 4.0 s => bias %.1f" % float(h.get_modifiers()["quick_cut_bias"]), float(h.get_modifiers()["quick_cut_bias"]) == float(rules["quick_cut_bias"]))
	h.tick(0.1, false)
	_check("hand not full resets", float(h.get_modifiers()["quick_cut_bias"]) == 1.0)
	var i := BossLearning.new(rules)
	i.on_player_interrupted_boss()
	_check("1 interrupt => no bonus", float(i.get_modifiers()["single_point_bonus"]) == 0.0)
	i.on_player_interrupted_boss()
	_check("2 interrupts => bonus", float(i.get_modifiers()["single_point_bonus"]) == float(rules["single_point_bonus"]))
	i.reset()
	_check("reset", float(i.get_modifiers()["single_point_bonus"]) == 0.0)


func _burn_avoid_test() -> void:
	var violations: int = 0
	var moves: int = 0
	for seed_value: int in 60:
		var grid := BoardGrid.new(3, 3)
		var state := CombatState.new(grid, 1000.0, 1000.0)
		var cut_config: CutConfig = CutConfig.load_from_file()
		var skill_config: SkillConfig = SkillConfig.load_from_file()
		var brain_config: BossBrainConfig = BossBrainConfig.load_from_file()
		var drops := FieldDrops.new(FieldDropsConfig.new(), grid.enemy_cells(), seed_value)
		var status := StatusEffects.new()
		var here: Vector2i = state.enemy_cell
		var burning: Array[Vector2i] = []
		var free_cell: Vector2i = Vector2i(-99, -99)
		for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if grid.is_enemy_cell(here + d):
				if free_cell.x == -99:
					free_cell = here + d
				else:
					burning.append(here + d)
					drops.debug_place("A1", here + d, 10.0)
		drops.debug_place("B1", free_cell, 10.0)
		status.ignite(burning, 5.0, 0.5, 1.0)
		var brain := BossBrain.new(brain_config, grid, cut_config, skill_config, seed_value)
		brain.use_set(["balanced", "aggressive", "cautious"][seed_value % 3])
		brain.set_learning(BossLearning.new(brain_config.learning))
		var ctx: Dictionary = {
			"state": state, "hand": HoldSlots.new(4), "drops": drops, "mover": UnitMover.new(state, CombatState.Side.ENEMY, 0.5),
			"actor": CutActor.new(cut_config, CombatState.Side.ENEMY), "cooldowns": SkillCooldowns.new(),
			"player_actor": CutActor.new(cut_config, CombatState.Side.PLAYER), "status": status,
		}
		brain.tick(1.0, false)
		var action: Dictionary = brain.decide(ctx)
		if str(action["type"]) == "move":
			moves += 1
			if burning.has(here + (action["direction"] as Vector2i)):
				violations += 1
	_check("burn_avoid: brain never steps onto fire with a free alternative (moves=%d, violations=%d)" % [moves, violations], violations == 0)


# mode "dodge": the player leaves a boss swing's cells right after it starts and returns after.
func _sim(seed_value: int, set_name: String, mode: String, refill: bool) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 1000000.0, 1000000.0)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var brain_config: BossBrainConfig = BossBrainConfig.load_from_file()
	var boss := BossController.new(state, grid, cut_config, skill_config, brain_config, FieldDropsConfig.new(), HoldSlotsConfig.new(), seed_value)
	boss.enable_pieces(PieceLibrary.load_from_file(), "", seed_value, 2) # Story 026: pieces are the only mode
	boss.get_brain().use_set(set_name)
	var status := StatusEffects.new()
	var learning := BossLearning.new(brain_config.learning)
	boss.set_status(status)
	boss.set_learning(learning)
	var player_actor := CutActor.new(cut_config, CombatState.Side.PLAYER)
	var arbiter := SwingArbiter.new(state, grid, player_actor, boss.get_actor(), cut_config, skill_config, status)
	var stats: Dictionary = {"feints": 0, "skills": {}}
	var log_list: Array[String] = []
	var home: Vector2i = state.player_cell
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var piece_lib: PieceLibrary = PieceLibrary.load_from_file()
	var shape_ids: Array[String] = piece_lib.shape_ids()
	boss.get_actor().swing_started.connect(func(cells: Array[Vector2i], _s: String, _d: float) -> void:
		learning.on_boss_swing_started(cells, state.player_cell))
	boss.get_actor().swing_cancelled.connect(func(_c: Array[Vector2i], _s: String) -> void:
		learning.on_boss_swing_cancelled())
	arbiter.swing_resolved.connect(func(side: int, result: Dictionary) -> void:
		if side == CombatState.Side.ENEMY:
			learning.on_boss_swing_resolved(bool(result["hit"])))
	arbiter.swing_interrupted.connect(func(victim: int, _c: Array[Vector2i], _s: String) -> void:
		if victim == CombatState.Side.ENEMY:
			learning.on_player_interrupted_boss())
	state.cell_changed.connect(func(side: int, _o: Vector2i, n: Vector2i) -> void:
		if side == CombatState.Side.PLAYER:
			learning.on_player_moved(n))
	boss.cut_started.connect(func(labels: Array[String], _c: Array[Vector2i], skill_id: String) -> void:
		var skills: Dictionary = stats["skills"]
		skills[skill_id] = int(skills.get(skill_id, 0)) + 1
		log_list.append("C%s%s;" % [",".join(labels), skill_id]))
	boss.moved.connect(func(d: Vector2i) -> void:
		log_list.append("M%s;" % str(d)))
	boss.feinted.connect(func(_c: Array[Vector2i], _l: Array[String]) -> void:
		stats["feints"] += 1
		log_list.append("F;"))
	var t: float = 0.0
	while t < SIM_SEC:
		t += DT
		status.tick(DT, state)
		learning.tick(DT, false)
		if refill:
			var hand: HoldSlots = boss.get_hand()
			while not hand.is_full():
				var p := FieldPoint.new()
				p.piece = piece_lib.make_piece(shape_ids[rng.randi() % shape_ids.size()], rng.randi() % 4)
				p.label = p.piece.shape_id
				hand.place_in_first_free(p)
		boss.tick(DT, player_actor)
		arbiter.tick(DT)
		if mode == "dodge":
			var actor: CutActor = boss.get_actor()
			if actor.is_swinging() and actor.get_cells().has(state.player_cell):
				for cell: Vector2i in grid.player_cells():
					if not actor.get_cells().has(cell):
						state.set_player_cell(cell)
						break
			elif not actor.is_swinging() and state.player_cell != home:
				state.set_player_cell(home)
	stats["hash"] = "".join(log_list).hash()
	stats["log_len"] = log_list.size()
	return stats

extends SceneTree
## Multi-enemy Phase 3 (docs/design/world-map-v2/MULTI-ENEMY-PHASE3-5-PLAN.md 1.1b / 1.6): CombatView builds N enemy
## units and their agents. D1 shared ThreatBoard + attack_slots, D2/A1 shared learning with per-key swing records,
## D3 think x sqrt(N), D4 one shared FieldDrops ticked once, D5 one hand per block-brain unit, A2 per-unit AI config,
## A3 a hit interrupts only the hit unit. One unit = the pre-Phase-3 match.

const E: int = CombatState.Side.ENEMY
const SEED: int = 7
const DT: float = 0.05
# A 5x4 enemy half without hazards.
const ARENA: Dictionary = {"side_cols": 5, "side_rows": 4, "missing_cells": []}

var fails: int = 0
var passes: int = 0


func check(ok: bool, label: String, extra: String = "") -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label, "  ", extra)


func _initialize() -> void:
	await process_frame
	await _test_single_unit()
	await _test_two_block_units()
	await _test_mixed_four_units()
	await _test_multiple_pattern_units()
	await _test_attack_slot_contention()
	_test_shared_learning_records()
	await _test_interrupt_only_hit_unit()
	await _test_shared_drops_and_pickup()
	await _test_unit0_death_and_match_end()
	await _test_determinism_and_single_formation()
	await process_frame
	print("FAILS=%d PASSES=%d" % [fails, passes])
	quit(fails)


# --- helpers ------------------------------------------------------------------------------------------------------

func _block(id: String, hp: float = 80.0) -> Dictionary:
	return {"id": id, "max_hp": hp, "brain": "block", "ai": {"boss_think_interval_sec": 0.3, "swing_speed_mult": 1.0}}


func _pattern(id: String, enemy: String, hp: float = 80.0) -> Dictionary:
	return {"id": id, "max_hp": hp, "brain": "pattern", "enemy": enemy, "ai": {"boss_think_interval_sec": 0.3}}


# A cleaned match whose unit 0 is [param entries][0] (its top-level keys follow it, as from_node writes them).
func _params(entries: Array, slots: int = 1) -> Dictionary:
	var first: Dictionary = entries[0]
	var raw: Dictionary = {"id": "fx", "boss_max_hp": float(first["max_hp"]), "arena": ARENA, "end_delay_sec": 0.0,
		"boss_think_interval_sec": 0.3}
	if entries.size() > 1:
		raw["enemies"] = entries
		raw["attack_slots"] = slots
	if str(first.get("brain", "")) == "pattern":
		raw["brain"] = "pattern"
		raw["enemy"] = first["enemy"]
	var m: Dictionary = RunConfig.clean_match(raw, 0)
	m["end_delay_sec"] = 0.0  # a timing key RunController adds (not a match key): no real-time end delay in tests
	return m


func _match(params: Dictionary) -> Node:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.name = "CombatView"
	v.match_params = params
	v.drops_seed = SEED
	v.freeze_time = true
	holder.add_child(v)
	root.add_child(holder)
	await process_frame
	return holder


func _view(holder: Node) -> CombatView:
	return holder.get_node("CombatView") as CombatView


func _drop(holder: Node) -> void:
	root.remove_child(holder)
	holder.free()


# Steps the match by hand (the frame loop stays frozen): [param steps] x DT of simulation.
func _run(v: CombatView, steps: int, sample: Callable = Callable()) -> void:
	v.freeze_time = false
	for i: int in steps:
		v._process(DT)
		if sample.is_valid():
			sample.call()
		if v.get_state().is_player_dead() or v.get_state().all_required_dead():
			break
	v.freeze_time = true


func _all_cells_distinct(s: CombatState) -> bool:
	var seen: Dictionary = {}
	for key: int in s.enemy_keys(true):
		for c: Vector2i in s.unit_cells(key):
			if seen.has(c):
				return false
			seen[c] = true
	return true


# --- tests --------------------------------------------------------------------------------------------------------

func _test_single_unit() -> void:
	var h: Node = await _match(_params([_block("solo")]))
	var v: CombatView = _view(h)
	check(v.get_state().unit_count() == 1 and v.get_extra_agents().is_empty(), "1: one unit, no extra agent")
	check(v.get_threat_board() != null and not v.get_threat_board().shared, "1: the threat board never refuses with one unit")
	check(v.get_boss().get_key() == E and v.get_boss().owns_drops() and v.controller_of(E) == v.get_boss(), "1: unit 0 = the legacy controller, owning its drops")
	check(is_equal_approx(v.get_boss().get_brain()._config.think_interval_sec, 0.3), "1: think interval unscaled (0.3)", str(v.get_boss().get_brain()._config.think_interval_sec))
	_drop(h)


func _test_two_block_units() -> void:
	var entries: Array = [_block("a"), _block("b", 60.0)]
	var source_ai: Dictionary = (entries[1] as Dictionary)["ai"].duplicate(true)
	var h: Node = await _match(_params(entries))
	var v: CombatView = _view(h)
	var s: CombatState = v.get_state()
	check(s.unit_count() == 2 and v.get_extra_agents().size() == 1, "2: two units, one extra agent")
	var agent: EnemyAgent = v.get_extra_agents()[0]
	check(agent.key == 2 and agent.controller.get_key() == 2 and agent.controller.get_brain().self_key == 2 and agent.unit == s.get_unit(1), "2: the agent maps to key 2 / unit 1 (controller, brain)")
	check(v.get_arbiter().get_actor(2) == agent.controller.get_actor() and v.get_arbiter().get_actor(E) == v.get_boss().get_actor(), "2: each actor registered in the arbiter under its own key")
	check(is_equal_approx(s.get_unit(1).max_hp, 60.0) and is_equal_approx(s.enemy_max_hp, 80.0), "2: each unit's HP from its entry")
	check(_all_cells_distinct(s), "2: spawn cells do not overlap")
	check(agent.controller.get_drops() == v.get_boss().get_drops() and not agent.controller.owns_drops(), "2 (D4): one FieldDrops shared, owned by unit 0 only")
	check(agent.controller.get_hand() != v.get_boss().get_hand(), "2 (D5): each block-brain unit has its own hand")
	check(agent.brain_config != v.get_boss().get_brain()._config, "2 (A2): independent BossBrainConfig objects")
	var want: float = clampf(0.3 * sqrt(2.0), 0.05, 1.0)
	check(is_equal_approx(agent.brain_config.think_interval_sec, want) and is_equal_approx(v.get_boss().get_brain()._config.think_interval_sec, want), "2 (D3): every unit thinks 0.3 x sqrt(2)", str([agent.brain_config.think_interval_sec, want]))
	check(s.get_unit(1).source["ai"] == source_ai, "2 (A2): the resolved ai block is not mutated by the build")
	agent.brain_config.active_set = "aggressive"
	check(v.get_boss().get_brain()._config.active_set != "aggressive" or agent.brain_config == v.get_boss().get_brain()._config, "2 (A2): changing one unit's config does not reach unit 0")
	# damage / death land on the right unit through the view's state
	s.damage(2, 10.0)
	check(is_equal_approx(s.get_unit(1).hp, 50.0) and is_equal_approx(s.enemy_hp, 80.0), "2: damage on key 2 hits unit 1 only")
	_run(v, 40, func() -> void:
		if not _all_cells_distinct(v.get_state()):
			check(false, "2: overlap while running"))
	check(_all_cells_distinct(s), "2: 2 s of AI: units never share a cell")
	_drop(h)


func _test_mixed_four_units() -> void:
	var entries: Array = [_block("a"), _pattern("p1", "dev_pattern_dummy"), _block("b"), _pattern("p2", "dev_pattern_dummy")]
	var h: Node = await _match(_params(entries, 2))
	var v: CombatView = _view(h)
	var s: CombatState = v.get_state()
	check(s.unit_count() == 4 and v.get_extra_agents().size() == 3, "4: four units, three extra agents")
	var kinds: Array = []
	for a: EnemyAgent in v.get_extra_agents():
		kinds.append("block" if a.is_block_brain() else "pattern")
		if a.pattern != null:
			check(a.pattern.get_key() == a.key and a.pattern.threat_board == v.get_threat_board(), "4: pattern of key %d drives its own key, shared board" % a.key)
	check(kinds == ["pattern", "block", "pattern"], "4: block / pattern mix built from the entries", str(kinds))
	var want: float = clampf(0.3 * 2.0, 0.05, 1.0)
	check(is_equal_approx(v.get_extra_agents()[0].pattern.think_interval_sec, want), "4 (D3): pattern think 0.3 x sqrt(4)")
	_run(v, 100, func() -> void:
		if not _all_cells_distinct(v.get_state()):
			check(false, "4: overlap while running"))
	check(_all_cells_distinct(s), "4: 5 s of mixed AI without overlap")
	_drop(h)


func _test_multiple_pattern_units() -> void:
	var entries: Array = [_pattern("p0", "dev_pattern_dummy"), _pattern("boss", "dev_pattern_boss", 300.0)]
	var h: Node = await _match(_params(entries))
	var v: CombatView = _view(h)
	var s: CombatState = v.get_state()
	check(s.footprint_size_of(E) == 1 and s.footprint_size_of(2) == 4, "P: each pattern sets ITS unit's footprint (unit 0: 1 cell, unit 1: 2x2)", str([s.footprint_size_of(E), s.footprint_size_of(2)]))
	check(_all_cells_distinct(s), "P: the 2x2 and the 1-cell unit do not overlap")
	var agent: EnemyAgent = v.get_extra_agents()[0]
	s.get_unit(1).invulnerable_left = 2.0
	s.damage(E, 5.0)
	s.damage(2, 5.0)
	check(is_equal_approx(s.enemy_hp, 75.0) and is_equal_approx(s.get_unit(1).hp, 300.0), "P: invulnerability of unit 1 does not protect unit 0")
	v.get_status().guard(2, 4.0, 3.0)
	check(is_equal_approx(v.get_status().guard_amount(2), 4.0) and is_equal_approx(v.get_status().guard_amount(E), 0.0), "P: guard on unit 1 only")
	check(agent.pattern != v.get_pattern_controller() and agent.pattern.get_key() == 2, "P: two PatternController instances, own keys")
	_drop(h)


func _test_attack_slot_contention() -> void:
	for slots: int in [1, 2]:
		var entries: Array = [_pattern("p0", "dev_pattern_dummy"), _pattern("p1", "dev_pattern_dummy"), _pattern("p2", "dev_pattern_dummy")]
		var h: Node = await _match(_params(entries, slots))
		var v: CombatView = _view(h)
		var board: ThreatBoard = v.get_threat_board()
		var patterns: Array = [v.get_pattern_controller()]
		for a: EnemyAgent in v.get_extra_agents():
			patterns.append(a.pattern)
		var worst: Array = [0]
		var attackers: Dictionary = {}
		var red_max: Array = [0]
		var usable: int = v.get_grid().player_cells().size()
		_run(v, 200, func() -> void:
			var busy: int = 0
			var red: Dictionary = {}
			for pc: PatternController in patterns:
				var st: int = pc.get_stage()
				if st == PatternController.Stage.WINDUP or st == PatternController.Stage.WARNING or st == PatternController.Stage.FOLLOWUP_WAIT:
					busy += 1
					attackers[pc.get_key()] = true
				for c: Vector2i in pc.telegraph_cells():
					red[c] = true
			worst[0] = maxi(worst[0], busy)
			red_max[0] = maxi(red_max[0], red.size()))
		check(worst[0] <= slots and board.holder_count() <= slots, "T%d: never more than %d unit(s) attacking at once (max seen %d)" % [slots, slots, worst[0]])
		check(attackers.size() >= 2, "T%d: the token rotates (%d units attacked)" % [slots, attackers.size()])
		check(red_max[0] * 2 <= usable, "T%d (F2): shared red cap kept (max %d of %d cells)" % [slots, red_max[0], usable])
		_drop(h)


func _test_shared_learning_records() -> void:
	var l := BossLearning.new({})
	var a: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2)]
	var b: Array[Vector2i] = [Vector2i(0, 0)]
	l.on_boss_swing_started(a, Vector2i(1, 1), 2)
	l.on_boss_swing_started(b, Vector2i(1, 1), 3)
	check(l.has_running_swing(2) and l.has_running_swing(3), "L (A1): two overlapping swings keep two records")
	l.on_player_moved(Vector2i(2, 1))
	l.on_boss_swing_resolved(false, 2)
	check(l.get_dodge_streak() == 1 and l.has_running_swing(3) and not l.has_running_swing(2), "L (A1): the dodged swing counts, the other record survives")
	l.on_boss_swing_resolved(true, 3)
	check(l.get_dodge_streak() == 0, "L (A1): the other unit's hit resets the SHARED streak")
	var single := BossLearning.new({})
	single.on_boss_swing_started(a, Vector2i(1, 1))
	single.on_player_moved(Vector2i(2, 1))
	single.on_boss_swing_resolved(false)
	check(single.get_dodge_streak() == 1 and not single.has_running_swing(), "L: default key = the pre-Phase-3 single swing")


func _test_interrupt_only_hit_unit() -> void:
	var h: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(h)
	var s: CombatState = v.get_state()
	var agent: EnemyAgent = v.get_extra_agents()[0]
	v.get_boss().set_active(false)
	agent.controller.set_active(false)
	var ba: CutActor = v.get_boss().get_actor()
	var bb: CutActor = agent.controller.get_actor()
	ba.begin_swing([s.player_cell] as Array[Vector2i], "kiem_khi", false, 1, 6.0)
	bb.begin_swing([s.player_cell] as Array[Vector2i], "kiem_khi", false, 1, 6.0)
	var arb: SwingArbiter = v.get_arbiter()
	v.get_cut_actor().begin_swing([s.cell_of(2)] as Array[Vector2i], "kiem_khi", true)
	for i: int in 30:
		arb.tick(DT)
	check(not bb.is_swinging() and ba.is_swinging(), "A3: a hit on unit 1 cancels unit 1's swing only")
	v.get_cut_actor().begin_swing([s.cell_of(E)] as Array[Vector2i], "kiem_khi", true)
	for i: int in 30:
		arb.tick(DT)
	check(not ba.is_swinging(), "A3: a hit on unit 0 cancels unit 0's swing")
	_drop(h)


func _test_shared_drops_and_pickup() -> void:
	var h: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(h)
	var s: CombatState = v.get_state()
	var agent: EnemyAgent = v.get_extra_agents()[0]
	v.get_boss().set_active(false)
	agent.controller.set_active(false)
	var drops: FieldDrops = v.get_boss().get_drops()
	var free: Vector2i = BoardGrid.NO_CELL
	for c: Vector2i in v.get_grid().enemy_cells():
		if s.enemy_at(c) < 0 and drops.get_points().filter(func(p: FieldPoint) -> bool: return p.cell == c).is_empty():
			free = c
			break
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var piece: Piece = lib.make_piece("mono", 0) if lib.has_method("make_piece") else null
	var point: FieldPoint = drops.debug_place_piece(piece, free, 9.0) if piece != null else drops.debug_place("mono", free, 9.0)
	# D4: one controller ticks the shared drops once per frame (unit 0 inactive here: re-activate only unit 0's drops tick)
	v.get_boss().set_active(true)
	v.get_boss().get_brain().cards = [] as Array[String]
	var before: float = point.freshness_left
	agent.controller.tick(DT, v.get_cut_actor())
	check(is_equal_approx(point.freshness_left, before), "D4: an extra unit's controller never ticks the shared drops")
	v.get_boss().tick(DT, v.get_cut_actor())
	check(is_equal_approx(point.freshness_left, before - DT), "D4: the owner ticks them exactly once")
	v.get_boss().set_active(false)
	var hand0: int = v.get_boss().get_hand().get_occupied_count()
	var hand1: int = agent.controller.get_hand().get_occupied_count()
	s.set_unit_cell(1, free)
	check(agent.controller.get_hand().get_occupied_count() == hand1 + 1 and v.get_boss().get_hand().get_occupied_count() == hand0, "D5: only the unit that stepped on the piece picks it up")
	_drop(h)


func _test_unit0_death_and_match_end() -> void:
	var h: Node = await _match(_params([_block("a"), _block("b")]))
	var v: CombatView = _view(h)
	var s: CombatState = v.get_state()
	var ended: Array = []
	v.match_ended.connect(func(won: bool, _hp: float) -> void: ended.append(won))
	s.damage(E, 999.0)
	for i: int in 4:
		await process_frame
	check(s.is_unit_dead(0) and not s.all_required_dead() and ended.is_empty(), "6: unit 0 dead, unit 1 alive: the match goes on")
	_run(v, 10)
	check(ended.is_empty() and not v.get_state().is_player_dead(), "6: still running after unit 0's death")
	s.damage(2, 999.0)
	for i: int in 6:
		await process_frame
	check(ended == [true], "7: the match ends (won) once every required unit is dead", str(ended))
	_drop(h)


func _test_determinism_and_single_formation() -> void:
	var logs: Array = []
	for variant: int in 3:
		var params: Dictionary
		if variant < 2:
			params = _params([_block("solo")])
		else:
			# a one-entry formation (enemies of length 1) is the plain match
			var raw: Dictionary = {"id": "fx", "boss_max_hp": 80.0, "arena": ARENA, "end_delay_sec": 0.0, "boss_think_interval_sec": 0.3,
				"enemies": [_block("solo")]}
			params = RunConfig.clean_match(raw, 0)
			params["end_delay_sec"] = 0.0
		var h: Node = await _match(params)
		var v: CombatView = _view(h)
		var log: Array = []
		_run(v, 120, func() -> void:
			log.append([v.get_state().enemy_cell, snappedf(v.get_state().enemy_hp, 0.001), v.get_state().player_cell, snappedf(v.get_state().player_hp, 0.001)]))
		logs.append(log)
		_drop(h)
	check(logs[0] == logs[1], "D: same seed, same 6 s log (deterministic)")
	check(logs[0] == logs[2], "1: a one-entry formation plays exactly the plain match")

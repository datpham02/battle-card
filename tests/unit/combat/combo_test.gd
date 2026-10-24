extends SceneTree

var fails: int = 0
var resolves: Array = []
var interrupts: Array = []


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in list:
		out.append(c as Vector2i)
	return out


func _init() -> void:
	_test_actor()
	_test_arbiter()
	_test_brain()
	_test_determinism()
	print("FAILS=%d" % fails)
	quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ (1) actor

func _test_actor() -> void:
	var cc := CutConfig.new()
	var a := CutActor.new(cc, CombatState.Side.ENEMY)
	var events: Array[String] = []
	a.swing_started.connect(func(_c: Array[Vector2i], _k: String, d: float) -> void: events.append("start%.2f" % d))
	a.swing_resolved.connect(func(_c: Array[Vector2i], _k: String) -> void: events.append("resolve"))
	a.swing_cancelled.connect(func(_c: Array[Vector2i], _k: String) -> void: events.append("cancel"))
	a.queue_cleared.connect(func(_c: Array[Vector2i], _k: String) -> void: events.append("qclear"))
	check("1a queue while idle is refused", not a.queue_swing(_cells([Vector2i(0, 0)]), "kiem_khi", false, 0.5) and not a.has_queued())
	a.begin_swing(_cells([Vector2i(0, 0)]), "kiem_khi", false)
	check("1b queue while swinging accepted", a.queue_swing(_cells([Vector2i(1, 0)]), "kiem_khi", false, 0.5) and a.has_queued())
	check("1b2 second queue refused (1 slot)", not a.queue_swing(_cells([Vector2i(2, 0)]), "kiem_khi", false, 0.5))
	check("1b3 queued info", a.get_queued_duration() == 0.5 and a.get_queued_cells() == _cells([Vector2i(1, 0)]))
	a.tick(10.0)
	check("1c queued swing started automatically (duration 0.5, not ticked in the same call)",
		a.is_swinging() and is_equal_approx(a.get_duration(), 0.5) and is_equal_approx(a.get_time_left(), 0.5) and not a.has_queued())
	a.tick(0.6)
	check("1d events in order: %s" % str(events), events == ["start0.45", "resolve", "start0.50", "resolve"])
	events.clear()
	a.begin_swing(_cells([Vector2i(0, 0)]), "kiem_khi", false)
	a.queue_swing(_cells([Vector2i(1, 0)]), "kiem_khi", false, 0.5)
	a.cancel()
	a.tick(5.0)
	check("1e cancel clears queue, no second swing: %s" % str(events), events == ["start0.45", "cancel", "qclear"] and not a.is_swinging() and not a.has_queued())
	var b := CutActor.new(cc, CombatState.Side.ENEMY)
	b.duration_mult = 0.8
	b.begin_swing(_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]), "kiem_khi", false)
	check("1f duration_mult 0.8: 3-cell swing = %.3f s" % b.get_duration(), is_equal_approx(b.get_duration(), 0.76))
	var p := CutActor.new(cc, CombatState.Side.PLAYER)
	p.begin_swing(_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]), "kiem_khi", true)
	check("1g player actor stays 0.95", is_equal_approx(p.get_duration(), 0.95))


# ------------------------------------------------------------------ (2) arbiter

func _make() -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	var cc := CutConfig.new()
	var sc := SkillConfig.new()
	var pa := CutActor.new(cc, CombatState.Side.PLAYER)
	var ba := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, pa, ba, cc, sc)
	resolves = []
	interrupts = []
	arb.swing_interrupted.connect(func(s: int, _c: Array[Vector2i], _k: String) -> void: interrupts.append(s))
	arb.swing_resolved.connect(func(s: int, r: Dictionary) -> void: resolves.append([s, bool(r["hit"])]))
	return {"grid": grid, "state": state, "pa": pa, "ba": ba, "arb": arb}


func _test_arbiter() -> void:
	# a) huge tick: both swings land in order against a player covered by both
	var m: Dictionary = _make()
	var st: CombatState = m["state"]
	var ba: CutActor = m["ba"]
	var arb: SwingArbiter = m["arb"]
	var pc: Vector2i = st.player_cell
	ba.begin_swing(_cells([pc]), "kiem_khi", false)
	ba.queue_swing(_cells([pc]), "kiem_khi", false, 0.5)
	arb.tick(5.0)
	check("2a huge tick: swing 1 then swing 2, both hit: %s hp=%.0f" % [str(resolves), st.player_hp],
		resolves == [[CombatState.Side.ENEMY, true], [CombatState.Side.ENEMY, true]] and not ba.is_swinging() and st.player_hp < 100.0)
	# b) player moves between impacts
	m = _make()
	st = m["state"]
	ba = m["ba"]
	arb = m["arb"]
	pc = st.player_cell
	var other: Vector2i = Vector2i(0, 0) if pc != Vector2i(0, 0) else Vector2i(2, 2)
	ba.begin_swing(_cells([pc]), "kiem_khi", false)
	ba.queue_swing(_cells([pc]), "kiem_khi", false, 0.5)
	arb.tick(0.46)
	check("2b swing 1 hit while standing in it, swing 2 now running", resolves.size() == 1 and bool(resolves[0][1]) and ba.is_swinging())
	var hp_after_1: float = st.player_hp
	st.set_player_cell(other)
	arb.tick(0.6)
	check("2c player moved: swing 2 missed (no damage): %s" % str(resolves), resolves.size() == 2 and not bool(resolves[1][1]) and st.player_hp == hp_after_1)
	m = _make()
	st = m["state"]
	ba = m["ba"]
	arb = m["arb"]
	pc = st.player_cell
	other = Vector2i(0, 0) if pc != Vector2i(0, 0) else Vector2i(2, 2)
	ba.begin_swing(_cells([other]), "kiem_khi", false)
	ba.queue_swing(_cells([other]), "kiem_khi", false, 0.5)
	arb.tick(0.46)
	st.set_player_cell(other)
	arb.tick(0.6)
	check("2d player dodges swing 1 then steps into swing 2: miss then hit: %s" % str(resolves), resolves.size() == 2 and not bool(resolves[0][1]) and bool(resolves[1][1]))
	# c) player interrupt during swing 1 cancels both
	m = _make()
	st = m["state"]
	ba = m["ba"]
	arb = m["arb"]
	var pa: CutActor = m["pa"]
	var cleared: Array[int] = [0]
	ba.queue_cleared.connect(func(_c: Array[Vector2i], _k: String) -> void: cleared[0] += 1)
	ba.begin_swing(_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]), "kiem_khi", false)
	ba.queue_swing(_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]), "kiem_khi", false, 0.5)
	pa.begin_swing(_cells([st.enemy_cell]), "kiem_khi", true)
	arb.tick(5.0)
	check("2e interrupt during swing 1 cancels both: %s interrupts=%s cleared=%d" % [str(resolves), str(interrupts), cleared[0]],
		resolves.size() == 1 and int(resolves[0][0]) == CombatState.Side.PLAYER and interrupts == [CombatState.Side.ENEMY] and cleared[0] == 1 and st.player_hp == 100.0)
	# d) player interrupt during swing 2 cancels only swing 2
	m = _make()
	st = m["state"]
	ba = m["ba"]
	arb = m["arb"]
	pa = m["pa"]
	pc = st.player_cell
	other = Vector2i(0, 0) if pc != Vector2i(0, 0) else Vector2i(2, 2)
	ba.begin_swing(_cells([other]), "kiem_khi", false)
	ba.queue_swing(_cells([pc]), "kiem_khi", false, 0.5)
	pa.begin_swing(_cells([st.enemy_cell, st.enemy_cell + Vector2i(0, 1)]), "kiem_khi", true)
	arb.tick(5.0)
	check("2f interrupt during swing 2: swing 1 (miss) landed, swing 2 cancelled, no player damage: %s %s" % [str(resolves), str(interrupts)],
		resolves.size() == 2 and int(resolves[0][0]) == CombatState.Side.ENEMY and not bool(resolves[0][1]) and int(resolves[1][0]) == CombatState.Side.PLAYER \
		and interrupts == [CombatState.Side.ENEMY] and st.player_hp == 100.0 and not ba.is_swinging())


# ------------------------------------------------------------------ (3) brain

func _brain_case(set_name: String, chance: float, seed_value: int, player_cell: Vector2i, labels: Array[String], max_points: int = 4) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100000.0, 100000.0)
	state.set_player_cell(player_cell)
	var cut_config: CutConfig = CutConfig.load_from_file()
	cut_config.hand_max_points = max_points
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var brain_config: BossBrainConfig = BossBrainConfig.load_from_file()
	brain_config.override_weight(set_name, "combo_chance", chance)
	var hand := HoldSlots.new(4)
	var drops_config := FieldDropsConfig.new()
	drops_config.spawn_interval_sec = 1.0e9
	drops_config.initial_delay_sec = 1.0e9
	var drops := FieldDrops.new(drops_config, grid.enemy_cells(), grid.perimeter_labels(), 1)
	var mover := UnitMover.new(state, CombatState.Side.ENEMY, brain_config.step_cooldown_sec)
	var actor := CutActor.new(cut_config, CombatState.Side.ENEMY)
	var pactor := CutActor.new(cut_config, CombatState.Side.PLAYER)
	var brain := BossBrain.new(brain_config, grid, cut_config, skill_config, seed_value)
	brain.use_set(set_name)
	var w: Dictionary = {
		"grid": grid, "state": state, "hand": hand, "brain": brain, "cut_config": cut_config,
		"ctx": {"state": state, "hand": hand, "drops": drops, "mover": mover, "actor": actor,
			"cooldowns": SkillCooldowns.new(), "player_actor": pactor,
			"player_step_cooldown": CombatConfig.load_from_file().step_cooldown_for(grid)},
	}
	_fill(hand, labels)
	return w


func _fill(hand: HoldSlots, labels: Array[String]) -> void:
	for i: int in hand.get_slot_count():
		if hand.get_point(i) != null:
			hand.remove(i)
	for label: String in labels:
		var p := FieldPoint.new()
		p.label = label
		hand.place_in_first_free(p)


func _test_brain() -> void:
	var labels: Array[String] = ["A1", "B1", "C3"]
	var w: Dictionary = _brain_case("aggressive", 1.0, 1, Vector2i(0, 0), labels, 2)
	var brain: BossBrain = w["brain"]
	brain.tick(1.0, false)
	var action: Dictionary = brain.decide(w["ctx"])
	var dbg: Dictionary = brain.last_debug()
	var combo: Dictionary = dbg.get("combo", {})
	var ok: bool = str(action["type"]) == "cut" and action.has("combo") and not combo.is_empty()
	print("  first cut %s escape cells alone=%s; with combo %s escape cells left=%s" % [
		str(dbg.get("labels")), str(combo.get("escape_before")), str(combo.get("labels")), str(combo.get("escape_after"))])
	check("3a aggressive chance 1.0, corner: combo chosen and leaves fewer escape cells", ok and int(combo["escape_after"]) < int(combo["escape_before"]))
	if ok:
		var used: Array = (action["hand_indices"] as Array) + (action["combo"]["hand_indices"] as Array)
		var uniq: Dictionary = {}
		for i: Variant in used:
			uniq[i] = true
		check("3a2 combo uses points disjoint from the first cut", uniq.size() == used.size())
	# cautious: never over 60 s
	var cw: Dictionary = _brain_case("cautious", 0.0, 3, Vector2i(0, 0), ["A1", "B1", "C3"] as Array[String])
	var cb: BossBrain = cw["brain"]
	var cuts: int = 0
	var combos: int = 0
	var t: float = 0.0
	while t < 60.0:
		t += 0.3
		cb.tick(0.3, false)
		var act: Dictionary = cb.decide(cw["ctx"])
		if str(act["type"]) == "cut":
			cuts += 1
			if act.has("combo"):
				combos += 1
			_fill(cw["hand"], ["A1", "B1", "C3"] as Array[String])
	check("3b cautious over 60 s: cuts=%d combos=%d (must be 0)" % [cuts, combos], combos == 0 and cuts > 0)
	# balanced rate
	var bw: Dictionary = _brain_case("balanced", 0.25, 5, Vector2i(0, 0), ["A1", "B1", "C3"] as Array[String], 2)
	var bb: BossBrain = bw["brain"]
	cuts = 0
	combos = 0
	for i: int in 400:
		bb.tick(0.3, false)
		var act2: Dictionary = bb.decide(bw["ctx"])
		if str(act2["type"]) == "cut":
			cuts += 1
			if act2.has("combo"):
				combos += 1
			_fill(bw["hand"], ["A1", "B1", "C3"] as Array[String])
	print("  balanced combo rate (hand_max_points 2): %d/%d = %.3f (chance 0.25)" % [combos, cuts, float(combos) / maxf(cuts, 1)])
	check("3c balanced combos measurable (0.05..0.5)", cuts > 20 and float(combos) / maxf(cuts, 1) > 0.05 and float(combos) / maxf(cuts, 1) < 0.5)
	# swing multiplier reaches the escape calc: slower swing (mult 0.5) never gives MORE escape cells
	var mw: Dictionary = _brain_case("balanced", 0.0, 1, Vector2i(0, 0), ["A1", "B1", "C3"] as Array[String])
	var mb: BossBrain = mw["brain"]
	mb.tick(1.0, false)
	mb.decide(mw["ctx"])
	var base_cands: Array = mb.last_debug().get("cut_candidates", [])
	(mw["ctx"]["actor"] as CutActor).duration_mult = 0.5
	mb.tick(1.0, false)
	mb.decide(mw["ctx"])
	var fast_cands: Array = mb.last_debug().get("cut_candidates", [])
	var not_more: bool = base_cands.size() == fast_cands.size() and base_cands.size() > 0
	var lower_somewhere: bool = false
	for i: int in mini(base_cands.size(), fast_cands.size()):
		if int(fast_cands[i]["escape"]) > int(base_cands[i]["escape"]):
			not_more = false
		if int(fast_cands[i]["escape"]) < int(base_cands[i]["escape"]):
			lower_somewhere = true
	check("3d faster boss swings (mult 0.5) -> escape counts never larger, some smaller", not_more and lower_somewhere)


# ------------------------------------------------------------------ (4) determinism

func _sim(seed_value: int) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100000.0, 100000.0)
	var cut_config: CutConfig = CutConfig.load_from_file()
	var skill_config: SkillConfig = SkillConfig.load_from_file()
	var brain_config: BossBrainConfig = BossBrainConfig.load_from_file()
	brain_config.override_weight("balanced", "combo_chance", 0.6)
	brain_config.active_set = "balanced"
	var drops_config := FieldDropsConfig.new()
	drops_config.spawn_interval_sec = 0.8
	var boss := BossController.new(state, grid, cut_config, skill_config, brain_config, drops_config, HoldSlotsConfig.new(), seed_value)
	boss.set_status(StatusEffects.new())
	var pactor := CutActor.new(cut_config, CombatState.Side.PLAYER)
	var counters: Dictionary = {"cuts": 0, "combos": 0, "log": ""}
	boss.cut_started.connect(func(l: Array[String], _c: Array[Vector2i], k: String) -> void:
		counters["cuts"] += 1
		counters["log"] += "cut:%s:%s;" % [",".join(l), k])
	boss.combo_queued.connect(func(c: Array[Vector2i], l: Array[String]) -> void:
		counters["combos"] += 1
		counters["log"] += "combo:%s:%d;" % [",".join(l), c.size()])
	boss.get_actor().swing_started.connect(func(_c: Array[Vector2i], _k: String, d: float) -> void:
		counters["log"] += "start%.2f;" % d)
	boss.moved.connect(func(d: Vector2i) -> void: counters["log"] += "mv%s;" % str(d))
	var t: float = 0.0
	while t < 90.0:
		t += 0.05
		boss.tick(0.05, pactor)
		boss.get_actor().tick(0.05)
	return {"hash": str(counters["log"]).hash(), "cuts": counters["cuts"], "combos": counters["combos"]}


func _test_determinism() -> void:
	var a: Dictionary = _sim(11)
	var b: Dictionary = _sim(11)
	var c: Dictionary = _sim(12)
	print("  sim: cuts=%d combos=%d hash=%d / %d (other seed %d)" % [a["cuts"], a["combos"], a["hash"], b["hash"], c["hash"]])
	var nat_cuts: int = 0
	var nat_combos: int = 0
	for sd: int in [21, 22, 23, 24]:
		var r: Dictionary = _sim(sd)
		nat_cuts += int(r["cuts"])
		nat_combos += int(r["combos"])
	print("  natural sim (balanced chance 0.6 override, 4 seeds x 90 s): combos=%d / cuts=%d = %.3f" % [nat_combos, nat_cuts, float(nat_combos) / maxf(nat_cuts, 1)])
	check("4a same seed same hash with combos on", int(a["hash"]) == int(b["hash"]) and int(a["combos"]) > 0)
	check("4b different seed differs", int(a["hash"]) != int(c["hash"]))

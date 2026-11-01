extends SceneTree
## ADR-0001 D7 / A1 / A6 (Phase 1 task 4): SkillDelivery parsing and validation of the five delivery types, the
## per-type arrival-time rule, the path-rule telegraph gate, every card in cards.json declaring a valid delivery,
## casts through the real resolve path (SwingArbiter -> CutEffects) affecting only the mask cells for every delivery
## type, and CombatConfig timing.beat_sec / beats_to_sec. Deterministic; reads only the shipped data files.
## Run: godot --headless --path . -s res://tests/unit/combat/skill_delivery_test.gd

var fails: int = 0


func ck(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))


func _initialize() -> void:
	_parsing()
	_arrivals()
	_path_rule()
	_cards()
	_resolve_path()
	_beat()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _parsing() -> void:
	var good: Dictionary = {
		SkillDelivery.CASTER_TO_TARGET: {"type": "CASTER_TO_TARGET", "origin": "caster", "travel": "hero_pack", "impact": "burst"},
		SkillDelivery.SKY_TO_TARGET: {"type": "SKY_TO_TARGET", "origin": "sky", "travel": "falling_squares", "impact": "slash"},
		SkillDelivery.GROUND_PROPAGATION: {"type": "GROUND_PROPAGATION", "origin": "origin_cell", "travel": "floor_run", "impact": "burn"},
		SkillDelivery.DIRECT_MANIFESTATION: {"type": "DIRECT_MANIFESTATION", "origin": "target_cells", "travel": "none", "impact": "freeze"},
		SkillDelivery.SEQUENTIAL_CHAIN: {"type": "SEQUENTIAL_CHAIN", "origin": "first_cell", "travel": "chain_spark", "impact": "shatter", "chain_order": "row_major"},
	}
	for type: String in good:
		var r: Dictionary = SkillDelivery.normalize(good[type])
		ck("parse: %s valid, no problems" % type, (r["problems"] as Array).is_empty() and r["delivery"]["type"] == type, str(r["problems"]))
		ck("parse: %s cell_mask is the block shape" % type, r["delivery"]["cell_mask"] == "block_shape")
	ck("parse: chain keeps its chain_order", SkillDelivery.normalize(good[SkillDelivery.SEQUENTIAL_CHAIN])["delivery"]["chain_order"] == "row_major")
	ck("parse: chain_order defaults to nearest_first", SkillDelivery.normalize({"type": "SEQUENTIAL_CHAIN", "impact": "burst"})["delivery"]["chain_order"] == "nearest_first")
	var origin_default: Dictionary = SkillDelivery.normalize({"type": "GROUND_PROPAGATION", "travel": "floor_run", "impact": "burn"})
	ck("parse: missing origin = the type's default", origin_default["delivery"]["origin"] == "origin_cell" and (origin_default["problems"] as Array).is_empty())
	# Bad data: each is flagged, and falls back to something usable (never SKY_TO_TARGET by default).
	var missing: Dictionary = SkillDelivery.normalize(null)
	ck("bad: missing delivery flagged", (missing["problems"] as Array).size() == 1)
	ck("bad: missing delivery falls back to DIRECT, not SKY", missing["delivery"]["type"] == SkillDelivery.DIRECT_MANIFESTATION)
	ck("bad: non-object flagged", not (SkillDelivery.normalize("sky")["problems"] as Array).is_empty())
	var bad_type: Dictionary = SkillDelivery.normalize({"type": "TELEPORT", "impact": "burst"})
	ck("bad: unknown type flagged + fallback", not (bad_type["problems"] as Array).is_empty() and bad_type["delivery"]["type"] == SkillDelivery.DIRECT_MANIFESTATION)
	var bad_origin: Dictionary = SkillDelivery.normalize({"type": "SKY_TO_TARGET", "origin": "caster", "travel": "falling_squares", "impact": "burst"})
	ck("bad: origin not allowed for the type -> default", bad_origin["delivery"]["origin"] == "sky" and not (bad_origin["problems"] as Array).is_empty())
	var bad_impact: Dictionary = SkillDelivery.normalize({"type": "CASTER_TO_TARGET", "travel": "hero_pack", "impact": "laser"})
	ck("bad: unknown impact -> burst", bad_impact["delivery"]["impact"] == "burst" and not (bad_impact["problems"] as Array).is_empty())
	var bad_travel: Dictionary = SkillDelivery.normalize({"type": "CASTER_TO_TARGET", "travel": "throw_block", "impact": "burst"})
	ck("bad: unknown travel (e.g. throwing the Block) -> none", bad_travel["delivery"]["travel"] == "none" and not (bad_travel["problems"] as Array).is_empty())
	var direct_travel: Dictionary = SkillDelivery.normalize({"type": "DIRECT_MANIFESTATION", "travel": "square_streak", "impact": "burst"})
	ck("bad: DIRECT with a travel -> none", direct_travel["delivery"]["travel"] == "none" and not (direct_travel["problems"] as Array).is_empty())
	var chain_on_sky: Dictionary = SkillDelivery.normalize({"type": "SKY_TO_TARGET", "travel": "falling_squares", "impact": "burst", "chain_order": "row_major"})
	ck("bad: chain_order on a non-chain ignored", chain_on_sky["delivery"]["chain_order"] == "" and not (chain_on_sky["problems"] as Array).is_empty())
	ck("bad: unknown chain_order flagged", not (SkillDelivery.normalize({"type": "SEQUENTIAL_CHAIN", "impact": "burst", "chain_order": "random"})["problems"] as Array).is_empty())
	ck("bad: cell_mask other than block_shape flagged", not (SkillDelivery.normalize({"type": "SKY_TO_TARGET", "impact": "burst", "cell_mask": "row"})["problems"] as Array).is_empty())
	var timing: Dictionary = SkillDelivery.normalize_timing({"SKY_TO_TARGET": {"fall_sec": -1.0, "stagger_sec": 0.05}, "NOPE": {}})
	ck("timing: bad value keeps the default, good one applies", is_equal_approx(float(timing["timing"]["SKY_TO_TARGET"]["fall_sec"]), 0.12) and is_equal_approx(float(timing["timing"]["SKY_TO_TARGET"]["stagger_sec"]), 0.05))
	ck("timing: problems reported", (timing["problems"] as Array).size() == 2, str(timing["problems"]))


func _arrivals() -> void:
	var caster := Vector2i(1, 1)
	var mask: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 0), Vector2i(4, 2)]
	var timing: Dictionary = SkillDelivery.DEFAULT_TIMING
	# CASTER_TO_TARGET: first (nearest) cell at 0, then a breadth-first spread - same as the sword wave's flow_plan.
	var c: Dictionary = SkillDelivery.arrival_times({"type": "CASTER_TO_TARGET", "origin": "caster"}, mask, caster, timing)
	ck("caster: nearest cell lands at the resolve", is_equal_approx(float(c[Vector2i(3, 1)]), 0.0))
	ck("caster: neighbour after first_hold + step", is_equal_approx(float(c[Vector2i(4, 1)]), 0.13 + 0.08))
	ck("caster: spread goes outward", float(c[Vector2i(5, 1)]) > float(c[Vector2i(4, 1)]) and is_equal_approx(float(c[Vector2i(4, 0)]), float(c[Vector2i(5, 1)])))
	var plan: Dictionary = CastVfx.flow_plan(mask, Vector2i(3, 1), 0.08, 0.08, 0.13)
	var same: bool = true
	for cell: Vector2i in mask:
		same = same and is_equal_approx(float(plan["arrive"][cell]), float(c[cell]))
	ck("caster: identical to CastVfx.flow_plan (sword wave look kept)", same)
	# SKY_TO_TARGET: near-simultaneous, row-major stagger after the fall.
	var s: Dictionary = SkillDelivery.arrival_times({"type": "SKY_TO_TARGET", "origin": "sky"}, mask, caster, timing)
	var lo: float = 99.0
	var hi: float = 0.0
	for cell: Vector2i in mask:
		lo = minf(lo, float(s[cell]))
		hi = maxf(hi, float(s[cell]))
	ck("sky: first cell after fall_sec", is_equal_approx(lo, 0.12) and is_equal_approx(float(s[Vector2i(4, 0)]), 0.12))
	ck("sky: all within (n-1) x stagger", is_equal_approx(hi - lo, 0.03 * 4.0))
	# GROUND_PROPAGATION: distance from the caster's cell x step; equal distance lands together.
	var g: Dictionary = SkillDelivery.arrival_times({"type": "GROUND_PROPAGATION", "origin": "origin_cell"}, mask, caster, timing)
	ck("ground: distance x step", is_equal_approx(float(g[Vector2i(3, 1)]), 2.0 * 0.06) and is_equal_approx(float(g[Vector2i(5, 1)]), 4.0 * 0.06))
	ck("ground: equal distance together", is_equal_approx(float(g[Vector2i(4, 0)]), float(g[Vector2i(4, 2)])))
	var gf: Dictionary = SkillDelivery.arrival_times({"type": "GROUND_PROPAGATION", "origin": "first_cell"}, mask, caster, timing)
	ck("ground: origin first_cell starts at 0 there", is_equal_approx(float(gf[Vector2i(3, 1)]), 0.0))
	# DIRECT_MANIFESTATION: all at once.
	var d: Dictionary = SkillDelivery.arrival_times({"type": "DIRECT_MANIFESTATION"}, mask, caster, timing)
	var all_zero: bool = true
	for cell: Vector2i in mask:
		all_zero = all_zero and is_equal_approx(float(d[cell]), 0.0)
	ck("direct: every cell at appear_sec (0)", all_zero)
	# SEQUENTIAL_CHAIN: strictly one after another.
	var ch: Dictionary = SkillDelivery.arrival_times({"type": "SEQUENTIAL_CHAIN", "origin": "first_cell", "chain_order": "row_major"}, mask, caster, timing)
	var order: Array[Vector2i] = SkillDelivery.chain_cells({"chain_order": "row_major"}, mask, caster)
	var want: Array[Vector2i] = [Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2)]
	ck("chain: row_major order", order == want, str(order))
	var strict: bool = true
	for i: int in order.size():
		strict = strict and is_equal_approx(float(ch[order[i]]), 0.1 * i)
	ck("chain: k-th link at k x step, no two together", strict)
	var auth: Array[Vector2i] = SkillDelivery.chain_cells({"chain_order": "authored"}, mask, caster)
	ck("chain: authored keeps the mask order", auth == mask)
	var near: Array[Vector2i] = SkillDelivery.chain_cells({"chain_order": "nearest_first", "origin": "caster"}, mask, caster)
	var nondecreasing: bool = true
	for i: int in range(1, near.size()):
		nondecreasing = nondecreasing and (absi(near[i].x - 1) + absi(near[i].y - 1)) >= (absi(near[i - 1].x - 1) + absi(near[i - 1].y - 1))
	ck("chain: nearest_first from the caster (ties row-major)", near[0] == Vector2i(3, 1) and near[2] == Vector2i(4, 0) and nondecreasing, str(near))
	ck("deterministic: same input same output", SkillDelivery.arrival_times({"type": "SEQUENTIAL_CHAIN", "origin": "first_cell", "chain_order": "row_major"}, mask, caster, timing) == ch)
	ck("empty mask: no arrivals", SkillDelivery.arrival_times({"type": "SKY_TO_TARGET"}, [], caster).is_empty())


func _path_rule() -> void:
	var no_flag: Dictionary = SkillDelivery.normalize({"type": "GROUND_PROPAGATION", "travel": "floor_run", "impact": "burn", "path_rule": {"effect": "damage"}})
	ck("path_rule: without telegraphed is dropped", (no_flag["delivery"]["path_rule"] as Dictionary).is_empty() and not (no_flag["problems"] as Array).is_empty())
	var false_flag: Dictionary = SkillDelivery.normalize({"type": "GROUND_PROPAGATION", "travel": "floor_run", "impact": "burn", "path_rule": {"effect": "damage", "telegraphed": false}})
	ck("path_rule: telegraphed false is dropped", (false_flag["delivery"]["path_rule"] as Dictionary).is_empty())
	var on_sky: Dictionary = SkillDelivery.normalize({"type": "SKY_TO_TARGET", "impact": "burn", "path_rule": {"effect": "damage", "telegraphed": true}})
	ck("path_rule: on a type without a floor path is dropped", (on_sky["delivery"]["path_rule"] as Dictionary).is_empty())
	var ok: Dictionary = SkillDelivery.normalize({"type": "GROUND_PROPAGATION", "travel": "floor_run", "impact": "burn", "path_rule": {"effect": "damage", "telegraphed": true}})
	ck("path_rule: telegraphed + valid effect kept", ok["delivery"]["path_rule"] == {"effect": "damage", "telegraphed": true} and (ok["problems"] as Array).is_empty())
	var mask: Array[Vector2i] = [Vector2i(5, 1)]
	var caster := Vector2i(1, 1)
	var plain: Dictionary = SkillDelivery.normalize({"type": "GROUND_PROPAGATION", "travel": "floor_run", "impact": "burn"})["delivery"]
	ck("damage_cells: no path rule = the mask only", SkillDelivery.damage_cells(plain, mask, caster) == mask)
	ck("damage_cells: unflagged rule (dropped) = the mask only", SkillDelivery.damage_cells(no_flag["delivery"], mask, caster) == mask)
	var with_path: Array[Vector2i] = SkillDelivery.damage_cells(ok["delivery"], mask, caster)
	ck("damage_cells: telegraphed rule adds the travel cells", with_path.has(Vector2i(4, 1)) and with_path.has(Vector2i(3, 1)) and not with_path.has(caster), str(with_path))


func _cards() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/cards.json"))
	var types: Dictionary = {}
	var all_ok: bool = true
	for id: String in raw["cards"]:
		var card: Dictionary = raw["cards"][id]
		var r: Dictionary = SkillDelivery.normalize(card.get("delivery"))
		if not (r["problems"] as Array).is_empty():
			all_ok = false
			print("  card %s: %s" % [id, str(r["problems"])])
		types[str(r["delivery"]["type"])] = int(types.get(str(r["delivery"]["type"]), 0)) + 1
	ck("cards: every card (curses, player_pool false included) has a valid delivery", all_ok)
	ck("cards: all five delivery types are used", types.size() == 5, str(types))
	ck("cards: SKY_TO_TARGET is not the default (< half the cards)", int(types.get(SkillDelivery.SKY_TO_TARGET, 0)) * 2 < (raw["cards"] as Dictionary).size(), str(types))
	var sc: SkillConfig = SkillConfig.load_from_file()
	ck("SkillConfig: kiem_khi delivery is CASTER_TO_TARGET hero_pack", sc.get_skill("kiem_khi")["delivery"]["type"] == SkillDelivery.CASTER_TO_TARGET and sc.get_skill("kiem_khi")["delivery"]["travel"] == "hero_pack")
	ck("SkillConfig: resolved() keeps the delivery", sc.resolved("dai_dao", 2)["delivery"]["type"] == SkillDelivery.SEQUENTIAL_CHAIN)
	ck("SkillConfig: built-in fallback card has a delivery", (SkillConfig.new().get_skill("kiem_khi")["delivery"] as Dictionary).has("type"))


# A cast of [param card] by the player at (1, 1) on the far column; the boss stands on (4, 1), which the travel of
# a path type crosses but which is outside the mask. Then the same cast with the boss inside the mask.
func _resolve_path() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cases: Array = [
		["kiem_khi", SkillDelivery.CASTER_TO_TARGET], ["han_khi", SkillDelivery.CASTER_TO_TARGET],
		["kiem_vu", SkillDelivery.SKY_TO_TARGET], ["han_bang", SkillDelivery.SKY_TO_TARGET],
		["xung_kich", SkillDelivery.GROUND_PROPAGATION], ["hoa_xa", SkillDelivery.GROUND_PROPAGATION],
		["tu_kiem", SkillDelivery.DIRECT_MANIFESTATION], ["ran_van", SkillDelivery.DIRECT_MANIFESTATION],
		["dai_dao", SkillDelivery.SEQUENTIAL_CHAIN], ["bang_chau", SkillDelivery.SEQUENTIAL_CHAIN],
	]
	var mask: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)]
	var crossed := Vector2i(4, 1)
	for c: Array in cases:
		var id: String = c[0]
		var delivery: Dictionary = sc.get_skill(id)["delivery"]
		ck("resolve %s: delivery is %s" % [id, c[1]], delivery["type"] == c[1])
		# A chain starting on its first cell over a contiguous column crosses nothing; every caster / ground cast does.
		if (SkillDelivery.PATH_TYPES as Array).has(c[1]) and str(delivery["origin"]) != "first_cell":
			ck("resolve %s: (4,1) is crossed by the travel" % id, SkillDelivery.travel_cells(delivery, mask, Vector2i(1, 1)).has(crossed), str(SkillDelivery.travel_cells(delivery, mask, Vector2i(1, 1))))
		var out: Dictionary = _cast(sc, id, mask, crossed)
		ck("resolve %s: boss on a travel cell outside the mask takes nothing" % id,
			not bool(out["hit"]) and is_equal_approx(float(out["hp"]), 100.0) and not bool(out["pinned"]) and int(out["fragile"]) == 0
			and int(out["frost"]) == 0 and not bool(out["burning_at_boss"]), str(out))
		ck("resolve %s: burn / zones only on mask cells" % id, bool(out["burn_in_mask_only"]))
		var inside: Dictionary = _cast(sc, id, mask, Vector2i(5, 1))
		ck("resolve %s: boss inside the mask is hit" % id, bool(inside["hit"]), str(inside))


func _cast(sc: SkillConfig, id: String, mask: Array[Vector2i], boss_cell: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 100.0, 100.0)
	state.set_player_cell(Vector2i(1, 1))
	state.set_enemy_cell(boss_cell)
	var cc := CutConfig.new()
	var status := StatusEffects.new()
	var pa := CutActor.new(cc, CombatState.Side.PLAYER)
	var ba := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, pa, ba, cc, sc, status)
	var results: Array = []
	arb.swing_resolved.connect(func(_s: int, r: Dictionary) -> void: results.append(r))
	pa.begin_swing(mask, id, true)
	var t: float = 0.0
	while results.is_empty() and t < 10.0:
		arb.tick(0.05)
		t += 0.05
	var in_mask: bool = true
	for cell: Vector2i in status.burning_cells():
		in_mask = in_mask and mask.has(cell)
	return {
		"hit": not results.is_empty() and bool(results[0]["hit"]), "hp": state.enemy_hp,
		"pinned": status.is_pinned(CombatState.Side.ENEMY), "fragile": status.fragile_stacks(CombatState.Side.ENEMY),
		"frost": status.frost_stacks(CombatState.Side.ENEMY), "burning_at_boss": status.is_burning(boss_cell),
		"burn_in_mask_only": in_mask, "resolved": not results.is_empty(),
	}


func _beat() -> void:
	var shipped: CombatConfig = CombatConfig.load_from_file()
	ck("beat: shipped timing.beat_sec = 0.5", shipped != null and is_equal_approx(shipped.beat_sec, 0.5))
	ck("beat: beats_to_sec(2) = 2 x beat_sec", is_equal_approx(shipped.beats_to_sec(2.0), 2.0 * shipped.beat_sec))
	var custom: CombatConfig = CombatConfig.from_dictionary({"timing": {"beat_sec": 0.4}})
	ck("beat: configurable (0.4 -> 3 beats = 1.2 s)", is_equal_approx(custom.beats_to_sec(3.0), 1.2))
	var bad: CombatConfig = CombatConfig.from_dictionary({"timing": {"beat_sec": 0}})
	ck("beat: <= 0 keeps the default", is_equal_approx(bad.beat_sec, 0.5))
	ck("beat: absent block keeps the default", is_equal_approx(CombatConfig.from_dictionary({}).beat_sec, 0.5))
	ck("timing: shipped delivery timing parsed", is_equal_approx(float(shipped.delivery_timing[SkillDelivery.CASTER_TO_TARGET]["spread_step_sec"]), 0.08)
		and is_equal_approx(float(shipped.delivery_timing[SkillDelivery.GROUND_PROPAGATION]["step_sec"]), 0.06))

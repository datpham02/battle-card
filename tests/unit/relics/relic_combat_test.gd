extends SceneTree
## Story 032 wave 2 (combat): every one of the 16 relics changes its rule in a built match (a headless
## CombatView with a HoldSlotsView sibling), the damage order through the real CutEffects path, the
## relic_damage_mult_cap clamp, chi_khau's per-match cap, khoi_the's first cast only, tam_hop's third (not
## fourth) piece, phan_don only with room in the bag, tui_rong's 4 slots + slower drops, and zone overrides
## applied AFTER a card's own seal_sec. Expected numbers come from relics.json / characters.json / the match
## configs (no gameplay literals) except the hand-computed boundary case. No frames are processed after setup,
## so CombatView's _process never runs: time is injected by hand. Prints PASS/FAIL lines and FAILS=n.

const BIG_HP: float = 1000000.0
const EPS: float = 0.001
const SKILL: String = "kiem_khi"

var fails: int = 0
var P: int = CombatState.Side.PLAYER
var E: int = CombatState.Side.ENEMY
var _triggers: Array[String] = []


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


func _params(relic_id: String) -> Dictionary:
	return RelicRegistry.info(relic_id).get("params", {}) as Dictionary


# The relic's {add|mul|set} entry for config key [param key] (relics.json params).
func _entry(relic_id: String, key: String) -> Dictionary:
	var raw: Variant = _params(relic_id).get(key)
	if typeof(raw) == TYPE_DICTIONARY:
		return raw as Dictionary
	return {"set": float(raw)}


# A CombatView (with its HoldSlotsView sibling, added first) in the tree owning [param relics].
func _view(relics: Array, character: Dictionary = {}) -> CombatView:
	var holder := Node.new()
	var bag := HoldSlotsView.new()
	bag.name = "HoldSlotsView"
	holder.add_child(bag)
	var v := CombatView.new()
	v.match_params = {"boss_max_hp": BIG_HP, "player_hp": -1.0, "relics": relics}
	if not character.is_empty():
		v.match_params["character"] = character
	v.drops_seed = 7
	v.freeze_time = true
	holder.add_child(v)
	root.add_child(holder)
	await process_frame
	v.freeze_time = false
	v.relic_triggered.connect(func(id: String) -> void: _triggers.append(id))
	return v


func _drop(v: CombatView) -> void:
	var holder: Node = v.get_parent()
	root.remove_child(holder)
	holder.free()


func _cells(v: CombatView, count: int) -> Array[Vector2i]:
	var state: CombatState = v.get_state()
	var cells: Array[Vector2i] = []
	for i: int in count:
		cells.append(state.enemy_cell if i == 0 else Vector2i(state.enemy_cell.x, 100 + i))
	return cells


# [param count] cells none of which is the boss's cell (the swing misses).
func _miss_cells(v: CombatView, count: int) -> Array[Vector2i]:
	var x: int = v.get_state().enemy_cell.x
	var cells: Array[Vector2i] = []
	for i: int in count:
		cells.append(Vector2i(x, 200 + i))
	return cells


func _info(pieces: Array[String], cells: int, joined: bool = false) -> Dictionary:
	return {"pieces": pieces, "cells": cells, "joined": joined, "featured": false, "card_id": SKILL, "hit": false}


# Begins a player cast (with the relics' cast_info) and resolves it; returns the arbiter result.
func _cast(v: CombatView, cells: Array[Vector2i], info: Dictionary) -> Dictionary:
	var got: Array[Dictionary] = [{}]
	var cb: Callable = func(side: int, result: Dictionary) -> void:
		if side == CombatState.Side.PLAYER:
			got[0] = result
	v.get_arbiter().swing_resolved.connect(cb)
	v._begin_cut(SKILL, cells, {}, info)
	v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	v.get_arbiter().swing_resolved.disconnect(cb)
	return got[0]


func _initialize() -> void:
	_test_order_hand_computed()
	_test_cap()
	await _test_damage_relics()
	await _test_chi_khau()
	await _test_khoi_the()
	await _test_tam_hop()
	await _test_phan_don()
	await _test_bag_and_drops()
	await _test_focus_signature_formation()
	await _test_status_relics()
	_test_zone_overrides()
	await _test_an_chu()
	await process_frame
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# Boundary case (the exact number IS the point): 7/cell x 1 cell, Ran x1.5, an_don x2, Sat thu x1.25.
func _test_order_hand_computed() -> void:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))
	var status := StatusEffects.new()
	status.configure(0.0, 0.0, 3, 1.0)
	status.configure_keywords(1.5, 3, 3, 24.0)
	status.apply_fragile(E, 1)
	var sc := SkillConfig.from_dictionary({"cards": {
		"sw": {"effect": "damage", "damage_per_cell": 7.0, "implemented": true, "upgrade": {}}}})
	var an_don: BaseRelic = RelicRegistry.instantiate("an_don", RelicConfig.from_dictionary({
		"relic_damage_mult_cap": 3.0,
		"relics": [{"id": "an_don", "rarity": "common", "script": "an_don", "params": {"mult": 2.0}}]}))
	var passive := QuickBladePassive.new()
	passive.setup({}, {"max_cells": 3, "damage_mult": 1.25})
	var info: Dictionary = _info(["mono"] as Array[String], 1)
	var relic_mod: Callable = func(cells: int, damage: float) -> float:
		var i: Dictionary = info.duplicate()
		i["cells"] = cells
		return RelicRegistry.fold_damage([an_don], i, damage)
	var r: Dictionary = CutEffects.apply(
		state, grid, P, [Vector2i(4, 1)] as Array[Vector2i], "sw", CutConfig.new(), sc, status,
		Callable(passive, "modify_damage"), 1, Callable(), Callable(), {"relic_modifier": relic_mod})
	_check("order: an_don + quick_blade vs Ran = 7 x 1.5 x 2 x 1.25 = 26.25", _near(float(r["damage"]), 26.25), str(r["damage"]))
	_check("order: Ran spent", bool(r["fragile_hit"]) and status.fragile_stacks(E) == 0)


func _test_cap() -> void:
	var cfg := RelicConfig.from_dictionary({"relic_damage_mult_cap": 3.0, "relics": [
		{"id": "big", "rarity": "common", "script": "an_don", "params": {"mult": 4.0}},
		{"id": "an_don", "rarity": "common", "script": "an_don", "params": {"mult": 2.0}},
		{"id": "huyet_an", "rarity": "epic", "script": "huyet_an", "params": {"min_cells": 1, "mult": 1.3, "self_damage": 0}}]})
	var info: Dictionary = _info(["mono"] as Array[String], 1)
	var big: BaseRelic = RelicRegistry.instantiate("big", cfg)
	_check("cap: x4 clamped to cap 3", _near(RelicRegistry.fold_damage([big], info, 10.0, cfg), 10.0 * cfg.relic_damage_mult_cap))
	var two: Array = [RelicRegistry.instantiate("an_don", cfg), RelicRegistry.instantiate("huyet_an", cfg)]
	_check("cap: 2 x 1.3 under the cap multiplies", _near(RelicRegistry.fold_damage(two, info, 10.0, cfg), 26.0))


# an_don (lone mono), huyet_an (>= min_cells, self damage on a miss only), in a built match through CombatView -> arbiter.
func _test_damage_relics() -> void:
	var plain: CombatView = await _view([])
	var d_mono: float = float(_cast(plain, _cells(plain, 1), _info(["mono"] as Array[String], 1))["damage"])
	var d_five: float = float(_cast(plain, _cells(plain, 5), _info(["domino", "tri"] as Array[String], 5, true))["damage"])
	_drop(plain)
	var v: CombatView = await _view(["an_don"])
	_triggers.clear()
	var mono: Dictionary = _cast(v, _cells(v, 1), _info(["mono"] as Array[String], 1))
	_check("an_don: lone mono x mult", _near(float(mono["damage"]), d_mono * float(_params("an_don")["mult"])), str(mono["damage"]))
	_check("an_don: flash", _triggers.has("an_don"))
	var other: Dictionary = _cast(v, _cells(v, 1), _info(["domino"] as Array[String], 1))
	_check("an_don: not a mono -> unchanged", _near(float(other["damage"]), d_mono))
	_drop(v)
	v = await _view(["huyet_an"])
	var hp0: float = v.get_state().player_hp
	var five: Dictionary = _cast(v, _cells(v, 5), _info(["domino", "tri"] as Array[String], 5, true))
	_check("huyet_an: >= min_cells x mult", _near(float(five["damage"]), d_five * float(_params("huyet_an")["mult"])), str(five["damage"]))
	_check("huyet_an: a big cast that hits costs no HP", bool(five["hit"]) and _near(v.get_state().player_hp, hp0), str(v.get_state().player_hp))
	var small: Dictionary = _cast(v, _cells(v, 1), _info(["mono"] as Array[String], 1))
	_check("huyet_an: small cast unchanged", _near(float(small["damage"]), d_mono))
	var small_miss: Dictionary = _cast(v, _miss_cells(v, 1), _info(["mono"] as Array[String], 1))
	_check("huyet_an: a small cast that misses costs no HP", not bool(small_miss["hit"]) and _near(v.get_state().player_hp, hp0))
	var big_miss: Dictionary = _cast(v, _miss_cells(v, 5), _info(["domino", "tri"] as Array[String], 5, true))
	_check("huyet_an: a big cast that misses costs self_damage HP", not bool(big_miss["hit"])
		and _near(v.get_state().player_hp, hp0 - float(_params("huyet_an")["self_damage"])), str(v.get_state().player_hp))
	_drop(v)


func _test_chi_khau() -> void:
	var v: CombatView = await _view(["chi_khau"])
	var cap: float = float(_params("chi_khau")["max_heal_per_match"])
	var heal: float = float(_params("chi_khau")["heal"])
	v.get_state().set_player_hp(v.get_state().player_max_hp - cap - 50.0)
	var hp0: float = v.get_state().player_hp
	_cast(v, _cells(v, 1), _info(["mono"] as Array[String], 1, false))
	_check("chi_khau: unjoined cast heals nothing", _near(v.get_state().player_hp, hp0))
	_cast(v, _cells(v, 2), _info(["mono", "mono"] as Array[String], 2, true))
	_check("chi_khau: joined cast heals", _near(v.get_state().player_hp, hp0 + heal))
	for i: int in int(ceil(cap / heal)) + 2:
		_cast(v, _cells(v, 2), _info(["mono", "mono"] as Array[String], 2, true))
	_check("chi_khau: stops at max_heal_per_match", _near(v.get_state().player_hp, hp0 + cap), str(v.get_state().player_hp))
	_drop(v)


func _test_khoi_the() -> void:
	var plain: CombatView = await _view([])
	plain._begin_cut(SKILL, _cells(plain, 2), {}, _info(["domino"] as Array[String], 2))
	var normal: float = plain.get_cut_actor().get_time_left()
	_drop(plain)
	var v: CombatView = await _view(["khoi_the"])
	v._begin_cut(SKILL, _cells(v, 2), {}, _info(["domino"] as Array[String], 2))
	_check("khoi_the: first cast has no windup", _near(v.get_cut_actor().get_time_left(), 0.0) and v.get_cut_actor().is_swinging())
	v.get_arbiter().tick(0.01)
	v._begin_cut(SKILL, _cells(v, 2), {}, _info(["domino"] as Array[String], 2))
	_check("khoi_the: second cast keeps its windup", normal > 0.0 and _near(v.get_cut_actor().get_time_left(), normal))
	_drop(v)
	v = await _view(["khoi_the"])
	v._begin_cut(SKILL, _cells(v, 2), {}, _info(["domino"] as Array[String], 2))
	_check("khoi_the: again first cast of the next match", _near(v.get_cut_actor().get_time_left(), 0.0))
	_drop(v)


func _add_mono(plan: CastPlan, slot: int, cell: Vector2i) -> bool:
	return plan.add_piece(slot, Piece.make("mono", [Vector2i.ZERO] as Array[Vector2i]), [cell] as Array[Vector2i])


func _test_tam_hop() -> void:
	var plain: CombatView = await _view([])
	var base: int = plain.get_max_join_pieces()
	var pp: CastPlan = plain.get_cast_plan()
	pp.clear()
	var ok3: bool = true
	for i: int in base + 1:
		ok3 = _add_mono(pp, i, Vector2i(3 + i, 0))
	_check("tam_hop: without it a piece over the base limit is refused", not ok3 and pp.piece_count() == base)
	_drop(plain)
	var v: CombatView = await _view(["tam_hop"])
	var limit: int = int(_params("tam_hop")["max_join_pieces"])
	_check("tam_hop: join limit from params", v.get_max_join_pieces() == limit, str(v.get_max_join_pieces()))
	var plan: CastPlan = v.get_cast_plan()
	plan.clear()
	var all_ok: bool = true
	for i: int in limit:
		all_ok = all_ok and _add_mono(plan, i, Vector2i(3 + i, 0))
	_check("tam_hop: a third piece joins", all_ok and plan.piece_count() == limit)
	_check("tam_hop: not a fourth", not _add_mono(plan, limit, Vector2i(3, 2)) and plan.piece_count() == limit)
	_drop(v)


func _point(shape: String) -> FieldPoint:
	var p := FieldPoint.new()
	p.label = shape
	p.piece = Piece.make(shape, [Vector2i.ZERO] as Array[Vector2i])
	return p


func _test_phan_don() -> void:
	var v: CombatView = await _view(["phan_don"])
	var hold: HoldSlots = v.get_hold()
	var before: int = hold.get_occupied_count()
	_triggers.clear()
	v._on_swing_interrupted(E, _cells(v, 1), "boss")
	var shape: String = str(_params("phan_don")["shape"])
	var got: bool = false
	for i: int in hold.get_slot_count():
		if hold.get_piece(i) != null and hold.get_piece(i).shape_id == shape:
			got = true
	_check("phan_don: interrupting the boss gives a piece", hold.get_occupied_count() == before + 1 and got)
	_check("phan_don: flash", _triggers.has("phan_don"))
	v._on_swing_interrupted(P, _cells(v, 1), "player")
	_check("phan_don: the boss interrupting the player gives nothing", hold.get_occupied_count() == before + 1)
	while not hold.is_full():
		hold.place_in_first_free(_point("mono"))
	_triggers.clear()
	v._on_swing_interrupted(E, _cells(v, 1), "boss")
	_check("phan_don: full bag -> nothing, no flash", hold.is_full() and not _triggers.has("phan_don"))
	_drop(v)


func _test_bag_and_drops() -> void:
	var plain: CombatView = await _view([])
	var slots: int = plain.get_hold().get_slot_count()
	var interval: float = plain._drops_config.piece_spawn_interval_sec
	var fresh: float = plain._drops_config.piece_freshness_sec
	var start: int = plain._drops_config.start_pieces
	_drop(plain)
	var v: CombatView = await _view(["tui_rong"])
	_check("tui_rong: bag gains a slot", v.get_hold().get_slot_count() == slots + int(_entry("tui_rong", "hold_slots")["add"]), str(v.get_hold().get_slot_count()))
	_check("tui_rong: 4 slots", v.get_hold().get_slot_count() == 4)
	var owned: Array[BaseRelic] = v.get_relics()
	_check("get_relics: this match's relics for the HUD strip", owned.size() == 1 and owned[0].get_id() == "tui_rong")
	var view := v.get_parent().get_node("HoldSlotsView") as HoldSlotsView
	_check("tui_rong: the hold VIEW's bag is the resized one", view.get_slots().get_slot_count() == 4 and view.get_slots() == v.get_hold())
	# Story 032 tuning: the x1.25 slower drop was removed (the sim showed it alone cost 16 points of run win).
	_check("tui_rong: piece drops keep their pace", _near(v._drops_config.piece_spawn_interval_sec, interval))
	_check("tui_rong: boss drops untouched", v.get_boss().get_drops() != null)
	_drop(v)
	v = await _view(["manh_tuoi"])
	_check("manh_tuoi: fresher pieces", _near(v._drops_config.piece_freshness_sec, fresh + float(_entry("manh_tuoi", "piece_freshness_sec")["add"])))
	# Story 032 tuning: the +1 start piece was removed (+25.7 points of run win for Phap su in the sim).
	_check("manh_tuoi: start pieces unchanged", v._drops_config.start_pieces == start)
	_drop(v)


func _test_focus_signature_formation() -> void:
	var character: Dictionary = CharacterConfig.load_from_file().get_character("sat_thu")
	var plain: CombatView = await _view([], character)
	var focus: float = plain.get_focus().get_max_sec()
	var cooldown: float = plain.get_signature_cooldown_sec()
	var fade: float = plain.get_formation().get_fade_sec()
	_drop(plain)
	var v: CombatView = await _view(["dinh_tam"], character)
	_check("dinh_tam: longer Focus (after the character's own)", _near(v.get_focus().get_max_sec(), focus + float(_entry("dinh_tam", "focus_sec")["add"])))
	_drop(v)
	v = await _view(["tam_huong"], character)
	_check("tam_huong: shorter signature cooldown", cooldown > 0.0 and _near(v.get_signature_cooldown_sec(), cooldown * float(_entry("tam_huong", "signature_cooldown")["mul"])))
	_drop(v)
	v = await _view(["la_ban"], character)
	_check("la_ban: slower formation fade", _near(v.get_formation().get_fade_sec(), fade * float(_entry("la_ban", "formation_fade")["mul"])))
	_drop(v)


func _test_status_relics() -> void:
	var plain: CombatView = await _view([])
	var burn_cap: int = plain.get_config().burn_max_stacks
	var han_n: int = plain.get_config().frost_stacks_to_burst
	var han_dmg: float = plain.get_config().frost_burst_damage
	_drop(plain)
	var v: CombatView = await _view(["dau_than"])
	var cell: Array[Vector2i] = [v.get_state().enemy_cell]
	for i: int in burn_cap + 3:
		v.get_status().ignite(cell, 2.0, 0.5, 1.0)
	_check("dau_than: burn stacks one more", v.get_status().max_stacks_on(cell) == burn_cap + int(_entry("dau_than", "burn_max_stacks")["add"]), str(v.get_status().max_stacks_on(cell)))
	_drop(v)
	v = await _view(["han_ky"])
	var set_n: int = int(_entry("han_ky", "han_stacks")["set"])
	var burst: float = 0.0
	for i: int in set_n:
		burst = v.get_status().apply_frost(E, 1)
	_check("han_ky: bursts at the set stack count", set_n < han_n and burst > 0.0)
	_check("han_ky: weaker burst", _near(burst, han_dmg * float(_entry("han_ky", "han_damage")["mul"])), str(burst))
	_drop(v)


func _test_zone_overrides() -> void:
	var grid := BoardGrid.new(3, 3)
	var sc := SkillConfig.from_dictionary({"cards": {
		"seal_own": {"effect": "seal", "seal_sec": 2.0, "implemented": true, "upgrade": {}},
		"seal_cfg": {"effect": "seal", "implemented": true, "upgrade": {}},
		"thorn": {"effect": "thorns", "thorn_sec": 3.0, "thorn_damage": 6.0, "thorn_fragile_stacks": 1, "implemented": true, "upgrade": {}}}})
	var zones: Dictionary = CombatConfig.new().zone_numbers()
	var cell: Array[Vector2i] = [Vector2i(5, 0)]
	for case: Array in [["phong_an", "seal_own", 2.0], ["phong_an", "seal_cfg", float(zones["seal_sec"])]]:
		var merged: Dictionary = RelicRegistry.merge_overrides([RelicRegistry.instantiate(str(case[0]))])
		var state := CombatState.new(grid, 1000.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))
		var status := StatusEffects.new()
		CutEffects.apply(state, grid, P, cell, str(case[1]), CutConfig.new(), sc, status, Callable(), 1, Callable(), Callable(),
			{"zones": zones, "zone_overrides": merged})
		_check("phong_an: %s seal = its own seconds + add" % case[1],
			_near(status.seal_total_sec(E, cell[0]), float(case[2]) + float(_entry("phong_an", "seal_sec")["add"])), str(status.seal_total_sec(E, cell[0])))
	var g_state := CombatState.new(grid, 1000.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))
	var g_status := StatusEffects.new()
	CutEffects.apply(g_state, grid, P, cell, "thorn", CutConfig.new(), sc, g_status, Callable(), 1, Callable(), Callable(),
		{"zones": zones, "zone_overrides": RelicRegistry.merge_overrides([RelicRegistry.instantiate("gai_ran")])})
	_check("gai_ran: thorn Ran per entry + add", int(g_status.thorns_at(E, cell[0]).get("fragile_stacks", -1)) == 1 + int(_entry("gai_ran", "thorn_ran")["add"]))
	var b_status := StatusEffects.new()
	CutEffects.apply(g_state, grid, P, cell, "seal_own", CutConfig.new(), sc, b_status, Callable(), 1, Callable(), Callable(), {"zones": zones})
	_check("zones: no override = the card's own seal_sec", _near(b_status.seal_total_sec(E, cell[0]), 2.0))


# an_chu: the featured multiplier is the relic's, through the real _on_skill_chosen path.
func _featured_mult(relics: Array) -> Array:
	var v: CombatView = await _view(relics)
	var e: Vector2i = v.get_state().enemy_cell
	var cells: Array[Vector2i] = [e, Vector2i(e.x + 1, e.y)]
	v._featured = {"cells": [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i],
		"bonus": {"damage_mult": 1.5, "effect": "", "stacks": 0, "sec": 0.0}}
	var plan: CastPlan = v.get_cast_plan()
	plan.clear()
	_add_mono(plan, 0, cells[0])
	_add_mono(plan, 1, cells[1])
	var got: Array[Dictionary] = [{}]
	var cb: Callable = func(side: int, result: Dictionary) -> void:
		if side == CombatState.Side.PLAYER:
			got[0] = result
	v.get_arbiter().swing_resolved.connect(cb)
	_triggers.clear()
	v._on_skill_chosen(SKILL, ["mono", "mono"] as Array[String], cells)
	v.get_arbiter().tick(v.get_cut_actor().get_time_left() + 0.01)
	var flashed: bool = _triggers.has("an_chu")
	_drop(v)
	return [got[0], flashed]


func _test_an_chu() -> void:
	var plain: Array = await _featured_mult([])
	var with: Array = await _featured_mult(["an_chu"])
	_check("an_chu: plain featured x1.5 (arena bonus)", bool((plain[0] as Dictionary).get("featured", false)) and _near(float((plain[0] as Dictionary)["featured_mult"]), 1.5))
	_check("an_chu: featured mult replaced", _near(float((with[0] as Dictionary).get("featured_mult", 0.0)), float(_params("an_chu")["featured_mult"])), str((with[0] as Dictionary).get("featured_mult")))
	_check("an_chu: damage ratio", _near(float((with[0] as Dictionary)["damage"]) / float((plain[0] as Dictionary)["damage"]), float(_params("an_chu")["featured_mult"]) / 1.5))
	_check("an_chu: flash on the featured hit", bool(with[1]))

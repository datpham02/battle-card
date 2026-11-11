extends SceneTree
## Skill v2 batch 2, Thiên Thạch (thien_thach) and the M05 `shockwave` sky mode: the hub (the mask's centre) drops at
## sky_hover_sec x hub_mult, the other cells follow ring by ring ring_step_sec apart (BFS from the hub; a cell cut off
## by its Manhattan distance), every event its own wave with one hit per cast, the `plus` clause fires every ring at
## once with the hub x2, the ignite payload lights every cell as its event fires, and determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_shockwave_test.gd

const ID: String = "thien_thach"
const HERO := Vector2i(1, 1)
const STEP: float = 0.01

var fails: int = 0
var _lib: PieceLibrary


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	_lib = PieceLibrary.load_from_file()
	test_data_and_validation()
	test_hub_then_rings()
	test_cut_off_cell_by_manhattan_distance()
	test_plus_clause_all_at_once()
	test_one_hit_hub_or_ring()
	test_payload_lights_every_cell()
	test_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _world(boss: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "kind": ev["kind"], "mult": ev["mult"], "at": arb.clock(), "hit": hit,
			"dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _ctx(sc: SkillConfig, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(ID, 1, pieces, [cells], sc.get_skill(ID)["delivery"], false, CombatState.Side.PLAYER, HERO)


# Runs the swing plus [param sec] seconds after its end; the swing's length is kept in w.duration.
func _run(w: Dictionary, shape: String, cells: Array[Vector2i], sec: float) -> void:
	(w["player"] as CutActor).begin_swing(cells, ID, true, 1, -1.0, {}, _ctx(w["sc"], shape, cells))
	var t: float = 0.0
	w["duration"] = (w["player"] as CutActor).get_duration()
	sec += float(w["duration"])
	while t < sec:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


# The damage of the one event that hit (0 when none).
func _hit_damage(w: Dictionary) -> float:
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			return float(e["dmg"])
	return 0.0


const BAR4: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
# plus5 at (4,0): (5,0) (4,1) (5,1) (6,1) (5,2); centre (5,1)
const PLUS: Array[Vector2i] = [Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2)]


func test_data_and_validation() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("Mage hero epic card, offered in the Mage's rewards, not in the shared pool", sc.hero_of(ID) == "phap_su" and s["rarity"] == "epic"
		and bool(s["hero_reward"]) and not sc.is_pool_card(ID) and sc.is_player_card(ID))
	ck("shockwave: hover 0.6, ring 0.1, hub x1.5, plus clause ring 0 / hub x2, ignite 2 s, 1 hit, no errors", s["sky_mode"] == "shockwave"
		and is_equal_approx(float(s["sky_hover_sec"]), 0.6) and is_equal_approx(float(s["ring_step_sec"]), 0.1) and is_equal_approx(float(s["hub_mult"]), 1.5)
		and is_zero_approx(float(s["shape_clause"]["ring_step_sec"])) and is_equal_approx(float(s["shape_clause"]["hub_mult"]), 2.0)
		and is_equal_approx(float(s["event_payload"]["ignite"]["sec"]), 2.0) and int(s["max_hits"]) == 1 and (s["resolve_errors"] as Array).is_empty(),
		str(s["resolve_errors"]))
	ck("min 4, cd 9, dpc 7", int(s["min_cells"]) == 4 and is_equal_approx(float(s["cooldown_sec"]), 9.0) and is_equal_approx(float(s["damage_per_cell"]), 7.0))
	var bad: Dictionary = CastResolver.validate("x", {"resolve": "waves", "sky_mode": "shockwave"}, "damage")
	ck("sky_mode needs resolve arrival", not (bad["errors"] as Array).is_empty())
	var bad2: Dictionary = CastResolver.validate("x", {"resolve": "arrival", "sky_mode": "rain"}, "damage")
	ck("an unknown sky_mode is rejected", not (bad2["errors"] as Array).is_empty())
	var bad3: Dictionary = CastResolver.validate("x", {"resolve": "arrival", "hub_mult": 3.0}, "damage")
	ck("hub_mult above the shape-group cap is rejected", not (bad3["errors"] as Array).is_empty())
	ck("every other sky card keeps sky_mode drops", sc.get_skill("kiem_vu")["sky_mode"] == "drops" and sc.get_skill("ngan_kiem")["sky_mode"] == "drops")


func test_hub_then_rings() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR4, _ctx(sc, "bar4", BAR4))
	var ev: Array = plan["events"]
	var by: Dictionary = {}
	for e: Dictionary in ev:
		by[(e["cells"] as Array)[0]] = e
	ck("bar4: hub (5,1) at 0.6 x1.5 kind hub; (4,1) and (6,1) at 0.7; (7,1) at 0.8; kind ring", ev.size() == 4
		and by[Vector2i(5, 1)]["kind"] == "hub" and is_equal_approx(float(by[Vector2i(5, 1)]["t"]), 0.6) and is_equal_approx(float(by[Vector2i(5, 1)]["mult"]), 1.5)
		and is_equal_approx(float(by[Vector2i(4, 1)]["t"]), 0.7) and is_equal_approx(float(by[Vector2i(6, 1)]["t"]), 0.7)
		and is_equal_approx(float(by[Vector2i(7, 1)]["t"]), 0.8) and by[Vector2i(7, 1)]["kind"] == "ring" and is_equal_approx(float(by[Vector2i(7, 1)]["mult"]), 1.0),
		str(ev))
	var waves: Dictionary = {}
	for e: Dictionary in ev:
		waves[int(e["wave"])] = true
	ck("every drop is its own wave, max_hits 1, ordered hub first", waves.size() == 4 and int(plan["max_hits"]) == 1 and ev[0]["kind"] == "hub")


func test_cut_off_cell_by_manhattan_distance() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), BAR4, _ctx(sc, "bar4", BAR4), SkillDelivery.DEFAULT_TIMING, [Vector2i(5, 1)])
	var ev: Array = plan["events"]
	var by: Dictionary = {}
	for e: Dictionary in ev:
		by[(e["cells"] as Array)[0]] = e
	ck("(5,1) locked: 3 open cells, hub (6,1) (nearest the bbox centre), (7,1) ring 1 at 0.7, (4,1) cut off -> Manhattan 2 at 0.8", ev.size() == 3
		and by[Vector2i(6, 1)]["kind"] == "hub" and is_equal_approx(float(by[Vector2i(7, 1)]["t"]), 0.7) and is_equal_approx(float(by[Vector2i(4, 1)]["t"]), 0.8),
		str(ev))


func test_plus_clause_all_at_once() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var plan: Dictionary = CastResolver.plan(sc.get_skill(ID), PLUS, _ctx(sc, "plus5", PLUS))
	var ev: Array = plan["events"]
	var all_at_hover: bool = ev.size() == 5
	var hub_mult: float = 0.0
	for e: Dictionary in ev:
		all_at_hover = all_at_hover and is_equal_approx(float(e["t"]), 0.6)
		if e["kind"] == "hub":
			hub_mult = float(e["mult"])
	ck("plus: every cell at 0.6 (ring step 0), the hub (5,1) x2", all_at_hover and is_equal_approx(hub_mult, 2.0)
		and (ev[0]["cells"] as Array)[0] == Vector2i(5, 1), str(ev))


func test_one_hit_hub_or_ring() -> void:
	# the hit's own damage is read from the event: the lit cell under the boss ticks burn damage afterwards (payload)
	var w: Dictionary = _world(Vector2i(5, 1))
	_run(w, "bar4", BAR4, 2.0)
	ck("boss on the hub: the hub event deals 7 x 4 x 1.5 = 42, then the burn ticks on top", is_equal_approx(_hit_damage(w), 42.0)
		and _lost(w) > 42.0, "%.1f total %.1f" % [_hit_damage(w), _lost(w)])
	var w2: Dictionary = _world(Vector2i(7, 1))
	_run(w2, "bar4", BAR4, 2.0)
	var hits: int = 0
	var hit_at: float = 0.0
	for e: Dictionary in w2["log"]:
		if bool(e["hit"]):
			hits += 1
			hit_at = float(e["at"]) - float(w2["duration"])
	ck("boss on the far ring: one hit x1 = 28, 0.8 s after the swing end", hits == 1 and is_equal_approx(_hit_damage(w2), 28.0) and absf(hit_at - 0.8) < 0.011,
		"%.1f at %.3f" % [_hit_damage(w2), hit_at])


func test_payload_lights_every_cell() -> void:
	var w: Dictionary = _world(Vector2i(7, 2))
	_run(w, "bar4", BAR4, 0.75)
	ck("0.75 s after the swing end: hub and ring 1 lit (3 cells), the far cell not yet", (w["fx"] as StatusEffects).burning_cells().size() == 3
		and not (w["fx"] as StatusEffects).is_burning(Vector2i(7, 1)), str((w["fx"] as StatusEffects).burning_cells()))
	var t: float = 0.0
	while t < 0.2:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP
	ck("after the last ring: all 4 cells burn (hit or miss)", (w["fx"] as StatusEffects).burning_cells().size() == 4)


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(6, 1))
	_run(a, "bar4", BAR4, 2.0)
	var b: Dictionary = _world(Vector2i(6, 1))
	_run(b, "bar4", BAR4, 2.0)
	ck("two identical runs: same log and HP (ring 1 hit: 28)", str(a["log"]) == str(b["log"]) and is_equal_approx(_hit_damage(a), 28.0) and is_equal_approx(_lost(a), _lost(b)))

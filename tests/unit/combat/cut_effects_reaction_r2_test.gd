extends SceneTree
## Skill v2 batch 2, Băng Vỡ (bang_vo) and R2 Vỡ Băng (M15, card-listed): `fragile_timing: before` lands the card's
## Rạn before its own hit; on a Pinned target with Rạn the hit deals x r2.mult (combat.json) instead of the Rạn
## multiplier, spends the stack and ends the Pin at once; an unpinned target just takes the Rạn hit (x1.5); a card
## that does not list r2 keeps the old rule (x1.5, Pin stays). Direct CutEffects.apply and the real sky-arrival path.
## Run: godot --headless --path . -s res://tests/unit/combat/cut_effects_reaction_r2_test.gd

const ID: String = "bang_vo"
const HERO := Vector2i(1, 1)
const STEP: float = 0.01

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data()
	test_r2_on_pinned_target()
	test_unpinned_target_plain_ran_hit()
	test_card_without_r2_keeps_the_old_rule()
	test_real_arbiter_sky()
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
	arb.reactions = CombatConfig.load_from_file().reactions()
	var log: Array = []
	arb.impact_resolved.connect(func(_side: int, ev: Dictionary, hit: bool) -> void:
		log.append({"cell": (ev["cells"] as Array)[0], "at": arb.clock(), "hit": hit, "dmg": float(ev.get("damage", 0.0))}))
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "arb": arb, "log": log}


func _apply(w: Dictionary, cells: Array[Vector2i], skill_id: String = ID) -> Dictionary:
	return CutEffects.apply(w["state"], w["grid"], CombatState.Side.PLAYER, cells, skill_id, w["cc"], w["sc"], w["fx"], Callable(), 1,
		Callable(), Callable(), {"reactions": CombatConfig.load_from_file().reactions()})


func _lost(w: Dictionary) -> float:
	return 1000.0 - (w["state"] as CombatState).enemy_hp


const BAR3: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var s: Dictionary = sc.get_skill(ID)
	ck("shared rare sky card: 1 Rạn before the hit, reaction r2, arrival SKY, 1 hit, no errors", s["rarity"] == "rare"
		and int(s["fragile_stacks"]) == 1 and s["fragile_timing"] == "before" and (s["reactions"] as Array) == ["r2"]
		and s["resolve"] == "arrival" and s["delivery"]["type"] == SkillDelivery.SKY_TO_TARGET and int(s["max_hits"]) == 1
		and (s["resolve_errors"] as Array).is_empty(), str(s["resolve_errors"]))
	ck("min 3, cd 6, dpc 5", int(s["min_cells"]) == 3 and is_equal_approx(float(s["cooldown_sec"]), 6.0) and is_equal_approx(float(s["damage_per_cell"]), 5.0))
	ck("every other card keeps fragile_timing after", sc.get_skill("ran_kich")["fragile_timing"] == "after")
	ck("combat.json r2 mult 2.0", is_equal_approx(CombatConfig.load_from_file().r2_mult, 2.0))


func test_r2_on_pinned_target() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	(w["fx"] as StatusEffects).pin(CombatState.Side.ENEMY, 1.0)
	var r: Dictionary = _apply(w, BAR3)
	ck("Pinned, no Rạn before: the card's Rạn lands first, R2 -> 5 x 3 x 2.0 = 30, reaction r2", bool(r["hit"])
		and is_equal_approx(float(r["damage"]), 30.0) and r.get("reaction", "") == "r2" and bool(r["fragile_hit"]), str(r))
	ck("the stack is spent and the Pin ends at once", (w["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 0
		and not (w["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY))


func test_unpinned_target_plain_ran_hit() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var r: Dictionary = _apply(w, BAR3)
	ck("not Pinned: Rạn before the hit -> x1.5 = 22.5, no reaction, stack spent", is_equal_approx(float(r["damage"]), 22.5)
		and str(r.get("reaction", "")).is_empty() and (w["fx"] as StatusEffects).fragile_stacks(CombatState.Side.ENEMY) == 0, str(r))


func test_card_without_r2_keeps_the_old_rule() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	(w["fx"] as StatusEffects).pin(CombatState.Side.ENEMY, 1.0)
	(w["fx"] as StatusEffects).apply_fragile(CombatState.Side.ENEMY, 1)
	var r: Dictionary = _apply(w, BAR3, "kiem_khi")
	ck("kiem_khi on a Pinned foe with Rạn: 6 x 3 x 1.5 = 27, Pin stays, no reaction key", is_equal_approx(float(r["damage"]), 27.0)
		and (w["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY) and not r.has("reaction"), str(r))


func test_real_arbiter_sky() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	(w["fx"] as StatusEffects).pin(CombatState.Side.ENEMY, 2.0)
	(w["player"] as CutActor).begin_swing(BAR3, ID, true, 1, -1.0, {}, {})
	var t: float = 0.0
	while t < 2.0:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP
	var hits: int = 0
	for e: Dictionary in w["log"]:
		if bool(e["hit"]):
			hits += 1
	ck("sky drops: 3 events, one hit, 30 damage, the Pin ended early", (w["log"] as Array).size() == 3 and hits == 1
		and is_equal_approx(_lost(w), 30.0) and not (w["fx"] as StatusEffects).is_pinned(CombatState.Side.ENEMY), "%.1f" % _lost(w))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 1))
	(a["fx"] as StatusEffects).pin(CombatState.Side.ENEMY, 1.0)
	_apply(a, BAR3)
	var b: Dictionary = _world(Vector2i(5, 1))
	(b["fx"] as StatusEffects).pin(CombatState.Side.ENEMY, 1.0)
	_apply(b, BAR3)
	ck("two identical applies: same HP", is_equal_approx(_lost(a), _lost(b)) and is_equal_approx(_lost(a), 30.0))

extends SceneTree
## Skill v2 batch 5 (Deferred 1 / 2, M15 rules): every reaction passes StatusEffects.reaction_allowed: a per-unit
## per-reaction-id cooldown (combat.json reactions.icd_sec 1.0), the immunity hook (reaction_immune_fn, an enemy's
## `immune_status` list) and a burn_eater boss's R1 immunity (burn_heal_ratio_fn > 0). Reactions are GLOBAL
## (reactions.global true): a card that lists none reacts like one that does; `global: false` restores the
## card-listed rule as data.
## Run: godot --headless --path . -s res://tests/unit/combat/status_effects_reaction_icd_test.gd

const HERO := Vector2i(1, 1)
const BAR3: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_data()
	test_icd_blocks_a_second_r2_within_a_second()
	test_icd_is_per_reaction_id_and_per_unit()
	test_immune_hook()
	test_burn_eater_boss_is_immune_to_r1()
	test_global_off_keeps_the_card_listed_rule()
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
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "reactions": CombatConfig.load_from_file().reactions()}


# One CutEffects.apply of [param id] on [param cells] with the match's reaction numbers (the arbiter's options).
func _apply(w: Dictionary, cells: Array[Vector2i], id: String = "kiem_khi", extra: Dictionary = {}) -> Dictionary:
	var options: Dictionary = {"reactions": w["reactions"]}
	options.merge(extra, true)
	return CutEffects.apply(w["state"], w["grid"], CombatState.Side.PLAYER, cells, id, w["cc"], w["sc"], w["fx"], Callable(), 1,
		Callable(), Callable(), options)


func _pin_ran(w: Dictionary) -> void:
	(w["fx"] as StatusEffects).pin(CombatState.Side.ENEMY, 2.0)
	(w["fx"] as StatusEffects).apply_fragile(CombatState.Side.ENEMY, 1)


func _tick(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["fx"] as StatusEffects).tick(0.05, w["state"])
		t += 0.05


func test_data() -> void:
	var r: Dictionary = CombatConfig.load_from_file().reactions()
	ck("combat.json reactions: icd_sec 1.0, global true, trap_through_defense true, the r1-r3 numbers kept",
		is_equal_approx(float(r["icd_sec"]), 1.0) and bool(r["global"]) and bool(r["trap_through_defense"])
		and is_equal_approx(float(r["r1"]["burst_damage"]), 12.0) and is_equal_approx(float(r["r3"]["damage"]), 8.0), str(r))
	var defaults: Dictionary = CutEffects.reaction_numbers({})
	ck("CutEffects built-in defaults carry icd_sec 1.0 and global true", is_equal_approx(float(defaults["icd_sec"]), 1.0) and bool(defaults["global"]))
	var off: Dictionary = CutEffects.reaction_numbers({"reactions": {"global": false, "icd_sec": 2.5}})
	ck("options.reactions overrides global / icd_sec", not bool(off["global"]) and is_equal_approx(float(off["icd_sec"]), 2.5))
	ck("reaction_enabled: global -> every card; listed only when global is off",
		CutEffects.reaction_enabled({"reactions": []}, "r2", defaults) and not CutEffects.reaction_enabled({"reactions": []}, "r2", off)
		and CutEffects.reaction_enabled({"reactions": ["r2"]}, "r2", off))


func test_icd_blocks_a_second_r2_within_a_second() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	_pin_ran(w)
	var a: Dictionary = _apply(w, BAR3)
	ck("first hit on a Pinned foe with Rạn: R2 x2 = 36, the Pin ends", is_equal_approx(float(a["damage"]), 36.0) and str(a.get("reaction", "")) == "r2"
		and not fx.is_pinned(CombatState.Side.ENEMY), str(a))
	ck("the R2 cooldown of the ENEMY runs: 1.0 s left", absf(fx.reaction_cooldown_left(CombatState.Side.ENEMY, "r2") - 1.0) < 0.001)
	_tick(w, 0.5)
	_pin_ran(w)
	var b: Dictionary = _apply(w, BAR3)
	ck("0.5 s later: no R2 (ICD), the plain Rạn multiplier 27, the Pin stays", is_equal_approx(float(b["damage"]), 27.0)
		and not b.has("reaction") and fx.is_pinned(CombatState.Side.ENEMY), str(b))
	_tick(w, 0.5)
	_pin_ran(w)
	var c: Dictionary = _apply(w, BAR3)
	ck("1.0 s after the first: R2 again (36, Pin ends)", is_equal_approx(float(c["damage"]), 36.0) and str(c.get("reaction", "")) == "r2"
		and not fx.is_pinned(CombatState.Side.ENEMY), str(c))


func test_icd_is_per_reaction_id_and_per_unit() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	_pin_ran(w)
	_apply(w, BAR3)  # R2 on the ENEMY now
	ck("R2 on the ENEMY does not start R1 / R3, nor the PLAYER's R2", fx.reaction_allowed(CombatState.Side.ENEMY, "r1")
		and fx.reaction_allowed(CombatState.Side.ENEMY, "r3") and fx.reaction_allowed(CombatState.Side.PLAYER, "r2"))
	ck("a true answer starts that cooldown: R1 on the ENEMY is now on cooldown", not fx.reaction_allowed(CombatState.Side.ENEMY, "r1"))
	ck("an explicit icd_sec 0 ignores the cooldown", fx.reaction_allowed(CombatState.Side.ENEMY, "r1", 0.0))
	fx.clear()
	ck("clear() resets the reaction book", fx.reaction_allowed(CombatState.Side.ENEMY, "r2"))


func test_immune_hook() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	fx.reaction_immune_fn = func(side: int, id: String) -> bool: return side == CombatState.Side.ENEMY and id == "r2"
	_pin_ran(w)
	var r: Dictionary = _apply(w, BAR3)
	ck("an enemy immune to R2: the plain Rạn hit 27, the Pin stays, no reaction", is_equal_approx(float(r["damage"]), 27.0)
		and not r.has("reaction") and fx.is_pinned(CombatState.Side.ENEMY), str(r))
	ck("the immunity is per id: R3 is still allowed", fx.reaction_allowed(CombatState.Side.ENEMY, "r3"))


func test_burn_eater_boss_is_immune_to_r1() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	fx.burn_heal_ratio_fn = func() -> float: return 0.5
	fx.ignite([Vector2i(5, 1)] as Array[Vector2i], 5.0, 10.0, 0.0)
	var r: Dictionary = _apply(w, BAR3, "han_kiem")
	ck("han_kiem (+1 Hàn) on a burning cell under a burn_eater boss: no R1, 18 only, the Hàn stays, the cell still burns",
		is_equal_approx(float(r["damage"]), 18.0) and not r.has("reaction") and fx.frost_stacks(CombatState.Side.ENEMY) == 1
		and fx.is_burning(Vector2i(5, 1)), str(r))
	fx.burn_heal_ratio_fn = Callable()
	var r2: Dictionary = _apply(w, BAR3, "han_kiem")
	ck("the same boss without burn_eater: R1 fires (18 + 12), the Hàn spent, the fire out", is_equal_approx(float(r2["damage"]), 18.0)
		and str(r2.get("reaction", "")) == "r1" and is_equal_approx(1000.0 - (w["state"] as CombatState).enemy_hp, 18.0 + 18.0 + 12.0)
		and fx.frost_stacks(CombatState.Side.ENEMY) == 1 and not fx.is_burning(Vector2i(5, 1)), str(r2))


func test_global_off_keeps_the_card_listed_rule() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var off: Dictionary = (w["reactions"] as Dictionary).duplicate(true)
	off["global"] = false
	w["reactions"] = off
	_pin_ran(w)
	var a: Dictionary = _apply(w, BAR3)
	ck("global off: kiem_khi (no list) keeps the old Rạn rule 27", is_equal_approx(float(a["damage"]), 27.0) and not a.has("reaction"), str(a))
	(w["fx"] as StatusEffects).end_pin(CombatState.Side.ENEMY)
	_pin_ran(w)
	var b: Dictionary = _apply(w, BAR3, "bang_vo")
	ck("global off: bang_vo (lists r2) still shatters: 5 x 3 x 2 = 30", is_equal_approx(float(b["damage"]), 30.0) and str(b.get("reaction", "")) == "r2", str(b))


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 1))
	var b: Dictionary = _world(Vector2i(5, 1))
	for w: Dictionary in [a, b]:
		_pin_ran(w)
		_apply(w, BAR3)
		_tick(w, 0.3)
		_pin_ran(w)
		_apply(w, BAR3)
	ck("two identical runs: same HP", is_equal_approx((a["state"] as CombatState).enemy_hp, (b["state"] as CombatState).enemy_hp))

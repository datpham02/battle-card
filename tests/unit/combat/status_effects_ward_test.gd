extends SceneTree
## Skill v2 batch 3, Thánh Thuẫn (thanh_thuan) and Khiên Thép (khien_thep): the M10 ward zone on the hero's own
## half through the real path (the cells already re-anchored, resolve waves x1, CutEffects._form_field,
## StatusEffects): data, the ward forms without hitting the enemy, damage taken x0.5 + 2 HP/s while standing on it,
## the square clause chills the attacker on a softened hit, Guard 6 flat (minimum 1), push immunity (line_v), the
## ward expires, a boss swing through CutEffects.apply uses the same hook, determinism.
## Run: godot --headless --path . -s res://tests/unit/combat/status_effects_ward_test.gd

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
	test_data()
	test_holy_ward_forms_and_halves_damage()
	test_square_clause_chills_the_attacker()
	test_steel_ward_guard_and_push_immunity()
	test_ward_expires_and_off_ward_is_plain()
	test_determinism()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _world(boss: Vector2i) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	state.set_player_hp(100.0)
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var done: Array = []
	arb.swing_resolved.connect(func(_side: int, r: Dictionary) -> void: done.append(r))
	return {"grid": grid, "state": state, "cc": cc, "sc": sc, "fx": fx, "player": player, "enemy": enemy, "arb": arb, "done": done}


func _ctx(sc: SkillConfig, id: String, shape: String, placed: Array[Vector2i]) -> Dictionary:
	var pieces: Array[Piece] = [_lib.make_piece(shape, 0)]
	return CastContext.build(id, 1, pieces, [placed], sc.get_skill(id)["delivery"], false, CombatState.Side.PLAYER, HERO)


# Casts the ward card [param id]: [param placed] are the enemy-half cells (the context's pieces), the swing itself runs
# on their WardAnchor remap (what CombatView / the sim do when the card is chosen).
func _cast_ward(w: Dictionary, id: String, shape: String, placed: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = WardAnchor.remap(placed, (w["state"] as CombatState).player_cell, w["grid"], w["fx"])
	(w["player"] as CutActor).begin_swing(cells, id, true, 1, -1.0, {}, _ctx(w["sc"], id, shape, placed))
	_run(w, (w["player"] as CutActor).get_duration() + STEP)
	return cells


func _run(w: Dictionary, sec: float) -> void:
	var t: float = 0.0
	while t < sec - 0.000001:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP


# A boss block swing (kiem_khi 6 x cells) on the hero's cell through CutEffects.apply, as SwingArbiter does.
func _boss_hit(w: Dictionary, cells: int = 2) -> Dictionary:
	var mask: Array[Vector2i] = [HERO]
	for i: int in cells - 1:
		mask.append(Vector2i(HERO.x - 1 - i, HERO.y))
	return CutEffects.apply(w["state"], w["grid"], CombatState.Side.ENEMY, mask, "kiem_khi", w["cc"], w["sc"], w["fx"])


const BAR2: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1)]
const SQUARE: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)]
const COL: Array[Vector2i] = [Vector2i(4, 0), Vector2i(4, 1)]


func test_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var t: Dictionary = sc.get_skill("thanh_thuan")
	ck("thanh_thuan: Cleric common ward, self_anchor, 4 s, x0.5 + 2 HP/s, square clause attacker_frost 1, zone card, never the boss's",
		sc.hero_of("thanh_thuan") == "giao_si" and t["effect"] == "ward" and sc.is_self_anchored("thanh_thuan") and is_equal_approx(float(t["ward_sec"]), 4.0)
		and is_equal_approx(float(t["ward"]["damage_mult"]), 0.5) and is_equal_approx(float(t["ward"]["heal_per_sec"]), 2.0)
		and int(t["shape_clause"]["attacker_frost"]) == 1 and sc.is_zone_card("thanh_thuan") and not sc.is_boss_playable("thanh_thuan")
		and (t["resolve_errors"] as Array).is_empty(), str(t["resolve_errors"]))
	var k: Dictionary = sc.get_skill("khien_thep")
	ck("khien_thep: shared common ward, Guard 6, line_v clause push_immune", sc.hero_of("khien_thep").is_empty() and k["effect"] == "ward"
		and sc.is_self_anchored("khien_thep") and is_equal_approx(float(k["ward"]["guard"]), 6.0) and bool(k["shape_clause"]["push_immune"])
		and (k["resolve_errors"] as Array).is_empty(), str(k["resolve_errors"]))
	ck("every other card is placed on the enemy half", not sc.is_self_anchored("kiem_khi") and sc.get_skill("kiem_khi")["placement"] == "enemy")
	var cfg: SkillConfig = SkillConfig.from_dictionary({"cards": {"x": {"placement": "moon"}}})
	ck("an unknown placement falls back to enemy (warning)", cfg.get_skill("x")["placement"] == "enemy")


func test_holy_ward_forms_and_halves_damage() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	var cells: Array[Vector2i] = _cast_ward(w, "thanh_thuan", "bar2", BAR2)
	ck("the ward forms on the hero's own cells (1,1) (0,1), the enemy is not hit", cells == [Vector2i(1, 1), Vector2i(0, 1)]
		and fx.field_cells(CombatState.Side.PLAYER, StatusEffects.KIND_WARD) == [Vector2i(0, 1), Vector2i(1, 1)]
		and is_equal_approx((w["state"] as CombatState).enemy_hp, 1000.0) and (w["done"] as Array).size() == 1
		and not bool((w["done"] as Array)[0]["hit"]) and str((w["done"] as Array)[0].get("zone_kind", "")) == "ward", str(w["done"]))
	var hp0: float = (w["state"] as CombatState).player_hp
	var r: Dictionary = _boss_hit(w)
	ck("a boss hit of 12 on the warded hero: 6 taken, 6 warded", is_equal_approx(float(r["damage"]), 6.0) and is_equal_approx(float(r.get("warded", 0.0)), 6.0)
		and is_equal_approx(hp0 - (w["state"] as CombatState).player_hp, 6.0), str(r))
	var hp1: float = (w["state"] as CombatState).player_hp
	_run(w, 1.0)
	ck("standing on the ward 1 s: +2 HP", is_equal_approx((w["state"] as CombatState).player_hp - hp1, 2.0), "%.2f" % ((w["state"] as CombatState).player_hp - hp1))
	ck("no Hàn on the boss without the square clause", fx.frost_stacks(CombatState.Side.ENEMY) == 0)


func test_square_clause_chills_the_attacker() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	_cast_ward(w, "thanh_thuan", "square", SQUARE)
	_boss_hit(w)
	ck("square ward: the softened hit gives the boss +1 Hàn", (w["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY) == 1)


func test_steel_ward_guard_and_push_immunity() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	_cast_ward(w, "khien_thep", "bar2", COL)  # a vertical bar2: line_v -> push immune
	var r: Dictionary = _boss_hit(w)
	ck("Guard 6 on a 12 hit: 6 taken", is_equal_approx(float(r["damage"]), 6.0), str(r))
	var r1: Dictionary = CutEffects.apply(w["state"], w["grid"], CombatState.Side.ENEMY, [HERO] as Array[Vector2i], "kiem_khi", w["cc"], w["sc"], fx)
	ck("Guard 6 on a 6 hit: the minimum 1 is taken", is_equal_approx(float(r1["damage"]), 1.0), str(r1))
	var push: Dictionary = CutEffects.apply(w["state"], w["grid"], CombatState.Side.ENEMY, [HERO] as Array[Vector2i], "chan_phong", w["cc"], w["sc"], fx)
	ck("a boss push (chan_phong) on the line_v ward: the hero does not move (push_immune)", not bool(push["pushed"]) and bool(push.get("push_immune", false))
		and (w["state"] as CombatState).player_cell == HERO, str(push))
	var w2: Dictionary = _world(Vector2i(5, 1))
	_cast_ward(w2, "khien_thep", "bar2", BAR2)  # horizontal: no immunity
	var push2: Dictionary = CutEffects.apply(w2["state"], w2["grid"], CombatState.Side.ENEMY, [HERO] as Array[Vector2i], "chan_phong", w2["cc"], w2["sc"], w2["fx"])
	ck("a horizontal steel ward: the push lands", bool(push2["pushed"]) and (w2["state"] as CombatState).player_cell == Vector2i(0, 1), str(push2))


func test_ward_expires_and_off_ward_is_plain() -> void:
	var w: Dictionary = _world(Vector2i(5, 1))
	var fx: StatusEffects = w["fx"]
	_cast_ward(w, "thanh_thuan", "bar2", BAR2)
	(w["state"] as CombatState).set_player_cell(Vector2i(2, 1))
	var r: Dictionary = CutEffects.apply(w["state"], w["grid"], CombatState.Side.ENEMY, [Vector2i(2, 1)] as Array[Vector2i], "kiem_khi", w["cc"], w["sc"], fx)
	ck("off the ward: the plain 6", is_equal_approx(float(r["damage"]), 6.0) and not r.has("warded"))
	_run(w, 4.1)
	ck("after 4 s the ward is gone", fx.field_cells(CombatState.Side.PLAYER).is_empty())


func test_determinism() -> void:
	var a: Dictionary = _world(Vector2i(5, 1))
	_cast_ward(a, "thanh_thuan", "square", SQUARE)
	_boss_hit(a)
	_run(a, 1.0)
	var b: Dictionary = _world(Vector2i(5, 1))
	_cast_ward(b, "thanh_thuan", "square", SQUARE)
	_boss_hit(b)
	_run(b, 1.0)
	ck("two identical runs: same player HP and boss Hàn", is_equal_approx((a["state"] as CombatState).player_hp, (b["state"] as CombatState).player_hp)
		and (a["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY) == (b["fx"] as StatusEffects).frost_stacks(CombatState.Side.ENEMY))

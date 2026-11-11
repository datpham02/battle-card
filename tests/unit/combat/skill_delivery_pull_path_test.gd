extends SceneTree
## Skill v2 batch 5 (Deferred 12): the path_rule effect `pull` — Móc Kéo's drag path is declared by its delivery
## (`path_rule {effect "pull", telegraphed true}`), SwingArbiter telegraphs it as cast_scheduled.pull_path, and
## SkillDelivery.damage_cells adds NO travel cell for it (the path is read, never hit). The damage / status effects keep
## adding the travel cells as before.
## Run: godot --headless --path . -s res://tests/unit/combat/skill_delivery_pull_path_test.gd

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
	test_normalize()
	test_damage_cells()
	test_moc_keo_data()
	test_arbiter_telegraphs_only_through_the_rule()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_normalize() -> void:
	var pull: Dictionary = SkillDelivery.normalize({"type": "CASTER_TO_TARGET", "travel": "square_streak", "impact": "knockback", "path_rule": {"effect": "pull", "telegraphed": true}})
	ck("path_rule pull + telegraphed is kept, no problems", (pull["delivery"]["path_rule"] as Dictionary) == {"effect": "pull", "telegraphed": true}
		and (pull["problems"] as Array).is_empty(), str(pull))
	ck("path_effect reads it", SkillDelivery.path_effect(pull["delivery"]) == "pull" and SkillDelivery.PATH_EFFECT_PULL == "pull")
	var no_flag: Dictionary = SkillDelivery.normalize({"type": "CASTER_TO_TARGET", "travel": "square_streak", "impact": "knockback", "path_rule": {"effect": "pull"}})
	ck("pull without telegraphed is dropped like the others", (no_flag["delivery"]["path_rule"] as Dictionary).is_empty() and SkillDelivery.path_effect(no_flag["delivery"]).is_empty())
	var sky: Dictionary = SkillDelivery.normalize({"type": "SKY_TO_TARGET", "travel": "falling_squares", "impact": "burst", "path_rule": {"effect": "pull", "telegraphed": true}})
	ck("a sky delivery has no floor path: dropped", (sky["delivery"]["path_rule"] as Dictionary).is_empty())


func test_damage_cells() -> void:
	var mask: Array = [Vector2i(5, 1), Vector2i(6, 1)]
	var pull: Dictionary = SkillDelivery.normalize({"type": "CASTER_TO_TARGET", "travel": "square_streak", "impact": "knockback", "path_rule": {"effect": "pull", "telegraphed": true}})["delivery"]
	var dmg: Dictionary = SkillDelivery.normalize({"type": "CASTER_TO_TARGET", "travel": "square_streak", "impact": "knockback", "path_rule": {"effect": "damage", "telegraphed": true}})["delivery"]
	var travel: Array[Vector2i] = SkillDelivery.travel_cells(pull, mask, HERO)
	ck("the flight from (1,1) to (5,1) crosses cells", not travel.is_empty(), str(travel))
	ck("pull: damage_cells = the mask only", SkillDelivery.damage_cells(pull, mask, HERO).size() == mask.size())
	ck("damage: damage_cells = the mask + the travel cells (unchanged)", SkillDelivery.damage_cells(dmg, mask, HERO).size() == mask.size() + travel.size())


func test_moc_keo_data() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var d: Dictionary = sc.get_skill("moc_keo")["delivery"]
	ck("moc_keo: CASTER_TO_TARGET with path_rule pull", d["type"] == "CASTER_TO_TARGET" and SkillDelivery.path_effect(d) == "pull", str(d))
	ck("no other card carries a path rule", _cards_with_rule(sc) == ["moc_keo"], str(_cards_with_rule(sc)))


func _cards_with_rule(sc: SkillConfig) -> Array[String]:
	var out: Array[String] = []
	for id: String in sc.cards.keys():
		if not SkillDelivery.path_effect(sc.get_skill(id)["delivery"]).is_empty():
			out.append(id)
	out.sort()
	return out


func test_arbiter_telegraphs_only_through_the_rule() -> void:
	var sched: Array = []
	var w: Dictionary = _world(Vector2i(7, 1), sched)
	var cells: Array[Vector2i] = [Vector2i(6, 1), Vector2i(7, 1)]
	_cast(w, cells)
	# bar2 is line_h: the clause pull 3; from (7,1) the drag path is (6,1) (5,1) (4,1)
	ck("moc_keo's cast_scheduled carries pull_path (6,1) (5,1) (4,1)", sched.size() == 1
		and (sched[0] as Dictionary).get("pull_path", []) == [Vector2i(6, 1), Vector2i(5, 1), Vector2i(4, 1)], str(sched))
	ck("the hook's surge on (7,1) dragged the boss to the divider cell (4,1)", (w["state"] as CombatState).enemy_cell == Vector2i(4, 1))
	# the same card with its rule removed from the (shared) config entry: the pull still happens, nothing is telegraphed
	var sc: SkillConfig = w["sc"]
	var delivery: Dictionary = sc.get_skill("moc_keo")["delivery"]
	var saved: Dictionary = (delivery["path_rule"] as Dictionary).duplicate()
	delivery["path_rule"] = {}
	var sched2: Array = []
	var w2: Dictionary = _world(Vector2i(7, 1), sched2, sc)
	_cast(w2, cells)
	delivery["path_rule"] = saved
	ck("without the rule: no pull_path on cast_scheduled, the drag itself unchanged (the boss on (4,1))", sched2.size() == 1
		and not (sched2[0] as Dictionary).has("pull_path") and (w2["state"] as CombatState).enemy_cell == Vector2i(4, 1), str(sched2))


func _world(boss: Vector2i, sched: Array, sc: SkillConfig = null) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, boss)
	var cc: CutConfig = CutConfig.load_from_file()
	if sc == null:
		sc = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	arb.cast_scheduled.connect(func(_side: int, c: Dictionary) -> void: sched.append(c))
	return {"state": state, "sc": sc, "fx": fx, "player": player, "arb": arb}


func _cast(w: Dictionary, cells: Array[Vector2i]) -> void:
	var sc: SkillConfig = w["sc"]
	var pieces: Array[Piece] = [_lib.make_piece("bar2", 0)]
	var ctx: Dictionary = CastContext.build("moc_keo", 1, pieces, [cells], sc.get_skill("moc_keo")["delivery"], false, CombatState.Side.PLAYER, HERO)
	(w["player"] as CutActor).begin_swing(cells, "moc_keo", true, 1, -1.0, {}, ctx)
	var until: float = (w["player"] as CutActor).get_duration() + 1.0
	var t: float = 0.0
	while t < until:
		(w["arb"] as SwingArbiter).tick(STEP)
		(w["fx"] as StatusEffects).tick(STEP, w["state"])
		t += STEP

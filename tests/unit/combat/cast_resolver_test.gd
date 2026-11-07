extends SceneTree
## Skill v2 B1 (docs/skill-v2/02-mechanics-catalog.md M01, M02): the cast context is built from the placed pieces and
## rides with the player's swing to the resolve; CastResolver turns an instant card into ONE wave of all its cells at
## t = 0, so SwingArbiter applies CutEffects exactly once, as before (the golden test pins the outcomes).
## Run: godot --headless --path . -s res://tests/unit/combat/cast_resolver_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	test_context_from_pieces()
	test_instant_card_is_one_wave()
	test_context_rides_to_the_resolve()
	test_skill_schema_v2_defaults()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_context_from_pieces() -> void:
	var lib: PieceLibrary = PieceLibrary.load_from_file()
	var bar: Piece = lib.make_piece("bar3", 0)
	var sq: Piece = lib.make_piece("square", 0)
	var bar_cells: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
	var sq_cells: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 2), Vector2i(4, 2)]
	var pieces: Array[Piece] = [bar, sq]
	var ctx: Dictionary = CastContext.build("kiem_khi", 2, pieces, [bar_cells, sq_cells], {"type": "CASTER_TO_TARGET"}, true,
		CombatState.Side.PLAYER, Vector2i(1, 1))
	ck("card / level / side", ctx["card"] == "kiem_khi" and int(ctx["level"]) == 2 and int(ctx["side"]) == CombatState.Side.PLAYER)
	ck("two pieces with ids", (ctx["pieces"] as Array).size() == 2 and ctx["pieces"][0]["shape_id"] == "bar3" and ctx["pieces"][1]["shape_id"] == "square")
	ck("piece tags", (ctx["pieces"][0]["tags"] as Array).has("line_h") and (ctx["pieces"][1]["tags"] as Array).has("square"))
	ck("union cells and count", int(ctx["cell_count"]) == 7 and (ctx["cells"] as Array).size() == 7)
	ck("featured flag and delivery", bool(ctx["featured"]) and ctx["delivery"]["type"] == "CASTER_TO_TARGET")
	ck("has_tag any piece", CastContext.has_tag(ctx, "square") and CastContext.has_tag(ctx, "line") and not CastContext.has_tag(ctx, "T"))


func test_instant_card_is_one_wave() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var cells: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]
	for id: String in sc.card_order:
		var waves: Array[Dictionary] = CastResolver.schedule(sc.get_skill(id), cells, {})
		var ok: bool = waves.size() == 1 and is_zero_approx(float(waves[0]["t"])) and (waves[0]["cells"] as Array) == cells
		if not ok:
			ck("instant %s is one wave at t=0" % id, false, str(waves))
			return
	ck("all 32 existing cards are one wave at t=0 with all their cells", true)


func test_context_rides_to_the_resolve() -> void:
	var grid := BoardGrid.new(3, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, Vector2i(1, 1), Vector2i(4, 1))
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var seen: Array = []
	arb.wave_resolved.connect(func(side: int, wave: Dictionary, result: Dictionary) -> void:
		seen.append({"side": side, "wave": wave, "ctx": result.get("cast_context", {})}))
	var cells: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]
	var ctx: Dictionary = {"card": "kiem_khi", "cell_count": 3, "marker": 42}
	player.begin_swing(cells, "kiem_khi", true, 1, -1.0, {}, ctx)
	arb.tick(5.0)
	ck("one wave resolved for the player", seen.size() == 1 and int(seen[0]["side"]) == CombatState.Side.PLAYER, str(seen))
	ck("the swing's context reached the resolve", seen.size() == 1 and int((seen[0]["ctx"] as Dictionary).get("marker", 0)) == 42)
	ck("damage as before (6 x 3)", is_equal_approx(state.enemy_hp, 1000.0 - 18.0))


func test_skill_schema_v2_defaults() -> void:
	var s: Dictionary = SkillConfig.load_from_file().get_skill("kiem_khi")
	ck("resolve defaults to instant", str(s.get("resolve", "")) == "instant")
	ck("placement defaults to enemy", str(s.get("placement", "")) == "enemy")
	ck("hits / max_hits default to 1", int(s.get("hits", 0)) == 1 and int(s.get("max_hits", 0)) == 1)
	ck("shape_clause and tags default empty", (s.get("shape_clause", null) as Dictionary).is_empty() and (s.get("tags", null) as Array).is_empty())

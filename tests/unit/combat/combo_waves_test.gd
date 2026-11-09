extends SceneTree
## M08 combo (docs/skill-v2/02-skill-bible.md song_dao, lien_tram): a shape clause may override `hits`
## on resolve waves, and `tag` may be a list (OR). Song Đao is 3 hits, 4 on mono or domino, crit combo_3
## from the 3rd. Liên Trảm is 2 hits, 3 on a line. No defense in this world (dpc lands whole).
## Run: godot --headless --path . -s res://tests/unit/combat/combo_waves_test.gd

const EPS: float = 0.001
const HERO := Vector2i(1, 1)

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	_test_clause_override_is_pure()
	_test_song_dao_damage()
	_test_lien_tram_line()
	_test_tag_list_rejected_when_not_strings()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _ctx(id: String, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var pieces: Array[Piece] = [PieceLibrary.load_from_file().make_piece(shape, 0)]
	return CastContext.build(id, 1, pieces, [cells], sc.get_skill(id)["delivery"], false, CombatState.Side.PLAYER, HERO)


func _test_clause_override_is_pure() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	var song: Dictionary = sc.get_skill("song_dao")
	var lien: Dictionary = sc.get_skill("lien_tram")
	ck("song_dao loads as waves, 3 hits, crit combo_3 x2, not a boss card",
		song["resolve"] == "waves" and int(song["hits"]) == 3 and str((song["crit"] as Dictionary)["when"]) == "combo_3"
		and is_equal_approx(float((song["crit"] as Dictionary)["mult"]), 2.0) and not sc.is_boss_playable("song_dao")
		and not bool(song["hero_reward"]))
	ck("lien_tram loads as waves, 2 hits, shared so the boss may hold it",
		lien["resolve"] == "waves" and int(lien["hits"]) == 2 and sc.is_boss_playable("lien_tram"))
	var bar: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	var mono: Array[Vector2i] = [Vector2i(4, 1)]
	var domino: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1)]
	ck("song_dao bar is 3 waves", CastResolver.plan(song, bar, _ctx("song_dao", "bar3", bar))["events"].size() == 3)
	ck("song_dao mono is 4 waves", CastResolver.plan(song, mono, _ctx("song_dao", "mono", mono))["events"].size() == 4)
	ck("song_dao domino is 4 waves", CastResolver.plan(song, domino, _ctx("song_dao", "bar2", domino))["events"].size() == 4)
	ck("lien_tram bar is 3 waves", CastResolver.plan(lien, bar, _ctx("lien_tram", "bar3", bar))["events"].size() == 3)
	ck("lien_tram domino (a line) is 3 waves", CastResolver.plan(lien, domino, _ctx("lien_tram", "bar2", domino))["events"].size() == 3)
	var square: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2)]
	ck("lien_tram square stays 2 waves", CastResolver.plan(lien, square, _ctx("lien_tram", "square", square))["events"].size() == 2)
	var bad: Dictionary = CastResolver.validate("z", {"resolve": "instant", "shape_clause": {"tag": "mono", "hits": 4}}, "damage", "direct")
	ck("hits override on an instant card is rejected", not (bad["errors"] as Array).is_empty() and str(bad["resolve"]) == "instant")


func _swing(id: String, shape: String, cells: Array[Vector2i]) -> Dictionary:
	var grid := BoardGrid.new(4, 3)
	var state := CombatState.new(grid, 1000.0, 1000.0, HERO, Vector2i(5, 1))
	var cc: CutConfig = CutConfig.load_from_file()
	var sc: SkillConfig = SkillConfig.load_from_file()
	var fx := StatusEffects.new()
	CombatConfig.load_from_file().configure_status(fx)
	var player := CutActor.new(cc, CombatState.Side.PLAYER)
	var enemy := CutActor.new(cc, CombatState.Side.ENEMY)
	var arb := SwingArbiter.new(state, grid, player, enemy, cc, sc, fx)
	var box: Array = [{}]
	arb.swing_resolved.connect(func(_side: int, result: Dictionary) -> void: box[0] = result)
	var started: bool = player.begin_swing(cells, id, true, 1, 0.2, {}, _ctx(id, shape, cells))
	arb.tick(3.0)
	var got: Dictionary = box[0]
	got["started"] = started
	got["hp"] = state.enemy_hp
	return got


func _test_song_dao_damage() -> void:
	var bar: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	var wide: Dictionary = _swing("song_dao", "bar3", bar)
	# 3 cells x dpc 3 = 9, waves 1-2 full, wave 3 crit x2: 9+9+18 = 36
	ck("song_dao bar3: 3 hits, crit on the 3rd (36)", int(wide.get("hits", -1)) == 3 and is_equal_approx(float(wide.get("damage", -1.0)), 36.0),
		str(wide.get("damage", -1.0)))
	var mono: Array[Vector2i] = [Vector2i(5, 1)]
	var one: Dictionary = _swing("song_dao", "mono", mono)
	# 1 cell x 3 = 3; waves 3 and 4 crit: 3+3+6+6 = 18
	ck("song_dao mono: 4 hits, crit on the 3rd and 4th (18)", int(one.get("hits", -1)) == 4 and is_equal_approx(float(one.get("damage", -1.0)), 18.0),
		str(one.get("damage", -1.0)))


func _test_lien_tram_line() -> void:
	var line: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	var got: Dictionary = _swing("lien_tram", "bar3", line)
	# 3 cells x dpc 4 = 12, three hits, no crit: 36
	ck("lien_tram line: 3 hits x 12 = 36", int(got.get("hits", -1)) == 3 and is_equal_approx(float(got.get("damage", -1.0)), 36.0),
		str(got.get("damage", -1.0)))


func _test_tag_list_rejected_when_not_strings() -> void:
	var bad: Dictionary = CastResolver.validate("z", {"resolve": "waves", "hits": 2, "shape_clause": {"tag": [1], "hits": 3}}, "damage", "direct")
	ck("a non-string tag in the list is rejected", not (bad["errors"] as Array).is_empty())

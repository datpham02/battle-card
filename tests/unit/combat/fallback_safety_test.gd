extends SceneTree
## Skill v2 B1 fallback safety (docs/skill-v2/02-design-decisions.md §9, §13): for every hero's starter WITHOUT
## kiem_khi (Q10), with every hand card unavailable (cooldown, cell minimum, parry without a telegraph), at 1, 2 and 5
## placed cells, the cast still completes with kiem_khi (even though the hand does not hold it), and it does so after
## the short no-option wait (cards.json menu_no_option_sec), not the full choose time. A hand with an available card
## never auto-casts early. Run: godot --headless --path . -s res://tests/unit/combat/fallback_safety_test.gd

var fails: int = 0
var _chosen: Array[String] = []


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var cfg: SkillConfig = SkillConfig.load_from_file()
	ck("no-option wait is short and below the choose time", cfg.menu_no_option_sec > 0.0 and cfg.menu_no_option_sec < cfg.menu_choose_sec,
		"%s vs %s" % [cfg.menu_no_option_sec, cfg.menu_choose_sec])
	test_every_starter_falls_back(cfg)
	test_available_card_waits_for_the_player(cfg)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _cells(n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in n:
		out.append(Vector2i(3 + i % 3, i / 3))
	return out


func _flow(cfg: SkillConfig, cds: SkillCooldowns) -> CutFlow:
	var flow := CutFlow.new(cfg, cds)
	flow.rng.seed = 3
	_chosen.clear()
	flow.skill_chosen.connect(func(id: String, _l: Array[String], _c: Array[Vector2i]) -> void: _chosen.append(id))
	return flow


func test_every_starter_falls_back(cfg: SkillConfig) -> void:
	var chars: CharacterConfig = CharacterConfig.load_from_file()
	for hero_id: String in chars.ids():
		var hero: Dictionary = chars.get_character(hero_id)
		var hand: Array[String] = []
		for id: Variant in hero.get("starter_deck", []) as Array:
			if str(id) != cfg.default_card and not hand.has(str(id)):
				hand.append(str(id))
		hand = hand.slice(0, 4)
		for n: int in [1, 2, 5]:
			var cds := SkillCooldowns.new()
			for id: String in hand:
				cds.start(id, 99.0)
			var flow: CutFlow = _flow(cfg, cds)
			flow.open_menu(["p"] as Array[String], _cells(n), hand, cfg.menu_choose_sec)
			flow.tick_real(cfg.menu_no_option_sec + 0.05)
			ck("%s, %d cell(s), all on cooldown -> kiem_khi at the short wait" % [hero["id"], n],
				_chosen == ([cfg.default_card] as Array[String]) and not flow.is_menu_open(), str(_chosen))


func test_available_card_waits_for_the_player(cfg: SkillConfig) -> void:
	var flow: CutFlow = _flow(cfg, SkillCooldowns.new())
	var hand: Array[String] = ["kiem_vu", "thiet_kiem"]
	flow.open_menu(["p"] as Array[String], _cells(3), hand, cfg.menu_choose_sec)
	flow.tick_real(cfg.menu_no_option_sec + 0.05)
	ck("an available card keeps the menu open past the short wait", _chosen.is_empty() and flow.is_menu_open())
	flow.tick_real(cfg.menu_choose_sec)
	ck("then the timeout picks an available hand card", _chosen.size() == 1 and hand.has(_chosen[0]), str(_chosen))

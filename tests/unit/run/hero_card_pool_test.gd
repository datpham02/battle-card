extends SceneTree
## Cast rhythm spec 2026-11-05 (design/quick-specs/nhip-ra-chieu-2026-11-05.md; user: "Riêng Kiếm sĩ"): a hero card
## (cards.json `hero`) stays in its hero's starter deck but is never drawn by RewardRoller (rewards, shop, events).
## Run: godot --headless --path . -s res://tests/unit/run/hero_card_pool_test.gd

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var cards: SkillConfig = SkillConfig.load_from_file()
	var cfg: Dictionary = RewardRoller.load_config()
	_check("test_do_kiem_is_a_kiem_si_hero_card", cards.hero_of("do_kiem") == "kiem_si" and cards.is_player_card("do_kiem") and not cards.is_pool_card("do_kiem"), cards.hero_of("do_kiem"))
	_check("test_shared_card_is_a_pool_card", cards.hero_of("kiem_vu").is_empty() and cards.is_pool_card("kiem_vu"))

	# 2000 seeds over every rarity floor and luck: the hero card is never offered.
	var none: Array[String] = []
	var seen: int = 0
	for sd: int in 2000:
		var min_rarity: String = ["common", "rare", "epic"][sd % 3]
		for id: String in RewardRoller.roll(cards, cfg, sd, none, {}, float(sd % 70), min_rarity):
			if id == "do_kiem":
				seen += 1
	_check("test_reward_roll_never_offers_a_hero_card", seen == 0, "offered %d times" % seen)

	var chars: CharacterConfig = CharacterConfig.load_from_file()
	_check("test_kiem_si_starter_keeps_its_hero_card", chars.deck_of("kiem_si").has("do_kiem"), str(chars.deck_of("kiem_si")))

	# Skill v2 Q3 (approved): tram_dia (Knight, hero_reward, rare) joins the KNIGHT's rewards only; do_kiem never does.
	var by_hero: Dictionary = {}
	var do_kiem_seen: int = 0
	for hero: String in ["kiem_si", "phap_su", "giao_si", "sat_thu", "tho_san", ""]:
		var n: int = 0
		for sd: int in 1500:
			var offer: Array[String] = RewardRoller.roll(cards, cfg, sd, none, {}, float(sd % 70), ["common", "rare", "epic"][sd % 3], hero)
			n += offer.count("tram_dia")
			do_kiem_seen += offer.count("do_kiem")
		by_hero[hero] = n
	_check("test_tram_dia_offered_to_the_knight", int(by_hero["kiem_si"]) > 0, str(by_hero))
	_check("test_tram_dia_never_offered_to_other_heroes_or_no_hero", int(by_hero["phap_su"]) == 0 and int(by_hero["giao_si"]) == 0
		and int(by_hero["sat_thu"]) == 0 and int(by_hero["tho_san"]) == 0 and int(by_hero[""]) == 0, str(by_hero))
	_check("test_do_kiem_still_never_offered", do_kiem_seen == 0, str(do_kiem_seen))
	_check("test_tram_dia_rare_and_not_in_a_starter_deck", cards.get_rarity("tram_dia") == "rare"
		and not chars.deck_of("kiem_si").has("tram_dia"), str(chars.deck_of("kiem_si")))

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

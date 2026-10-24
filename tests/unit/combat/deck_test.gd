extends SceneTree

var fails: int = 0


func ck(label: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS: ", label)
	else:
		fails += 1
		print("FAIL: ", label, " ", extra)


func _twelve() -> Array[String]:
	var a: Array[String] = []
	for i: int in 5:
		a.append("kiem_khi")
	for i: int in 4:
		a.append("chan_phong")
	for i: int in 2:
		a.append("hoa_tran")
	a.append("bang_phong")
	return a


func _count(arr: Array[String], id: String) -> int:
	return arr.count(id)


func _initialize() -> void:
	var d1 := Deck.new(_twelve(), 42)
	var d2 := Deck.new(_twelve(), 42)
	var same: bool = true
	for i: int in 6:
		if d1.draw(4) != d2.draw(4):
			same = false
	ck("same seed same sequence", same)

	var d := Deck.new(_twelve(), 7)
	var all: Array[String] = []
	for i: int in 3:
		var h: Array[String] = d.draw(4)
		ck("hand size 4", h.size() == 4)
		all.append_array(h)
	ck("bag deals each card once over 3 hands", _count(all, "kiem_khi") == 5 and _count(all, "chan_phong") == 4 and _count(all, "hoa_tran") == 2 and _count(all, "bang_phong") == 1, str(all))

	var e8: Array[String] = ["kiem_khi", "kiem_khi", "chan_phong", "chan_phong", "hoa_tran", "hoa_tran", "bang_phong", "bang_phong"]
	var differs: bool = false
	var d8 := Deck.new(e8, 3)
	var prev: Array[String] = d8.draw(4)
	for i: int in 5:
		var h2: Array[String] = d8.draw(4)
		if h2 != prev:
			differs = true
		prev = h2
		ck("8-card hand has no more copies than the deck", _count(h2, "kiem_khi") <= 2 and h2.size() == 4)
	ck("consecutive hands differ", differs)

	var d3 := Deck.new(["kiem_khi", "chan_phong", "hoa_tran"] as Array[String], 1)
	ck("3-card deck hand size 3", d3.draw(4).size() == 3)
	ck("3-card deck again 3", d3.draw(4).size() == 3)
	ck("empty deck draws []", Deck.new([] as Array[String], 1).draw(4).is_empty())

	var da := Deck.new([] as Array[String], 1)
	da.add("kiem_khi")
	da.add("kiem_khi")
	da.add("hoa_tran")
	ck("add upgrades a copy below 3 instead of adding (020)", da.size() == 2 and da.count_of("kiem_khi") == 1 and da.level_of("kiem_khi") == 2 and da.count_of("hoa_tran") == 1 and da.count_of("x") == 0)
	da.remove_at(0)
	ck("remove_at", da.size() == 1 and da.count_of("kiem_khi") == 0)
	da.remove_at(99)
	ck("remove_at out of range ignored", da.size() == 1)
	var rt: Array[String] = ["bang_phong", "kiem_khi", "kiem_khi"]
	ck("from_array/to_array round trip", Deck.from_array(rt, 5).to_array() == rt)
	var dr := Deck.new(_twelve(), 9)
	var first: Array[String] = dr.draw(4)
	dr.draw(4)
	dr.reset_bag(9)
	ck("reset_bag replays", dr.draw(4) == first)

	# SkillConfig
	var cfg: SkillConfig = SkillConfig.load_from_file()
	ck("cards.json loads >= 20 cards (020)", cfg.cards.size() >= 20 and cfg.hand_size == 4 and cfg.default_card == "kiem_khi")
	var ids_ok: bool = cfg.default_deck.size() == 6
	for id: String in cfg.default_deck:
		ids_ok = ids_ok and cfg.has_skill(id)
	ck("default_deck ids valid", ids_ok, str(cfg.default_deck))
	ck("card_order starts with the basics", cfg.card_order.slice(0, 4) == (["kiem_khi", "chan_phong", "hoa_tran", "bang_phong"] as Array[String]))
	ck("rarity getters", cfg.get_rarity("kiem_khi") == "common" and cfg.get_rarity("chan_phong") == "common" and cfg.get_rarity("hoa_tran") == "rare" and cfg.get_rarity("bang_phong") == "rare")
	ck("class_tags gone, damage_per_cell + upgrade present (020)", not cfg.get_skill("hoa_tran").has("class_tags") and not cfg.get_skill("kiem_khi").has("damage_multiplier") and cfg.get_skill("kiem_khi")["damage_per_cell"] == 6.0 and not (cfg.get_skill("hoa_tran")["upgrade"] as Dictionary).is_empty())
	ck("name keys", cfg.get_skill("hoa_tran")["name_key"] == "card.hoa_tran.name")
	var bad: SkillConfig = SkillConfig.from_dictionary({
		"cards": {"kiem_khi": {"effect": "damage", "implemented": true}},
		"default_deck": ["kiem_khi", "ghost", "kiem_khi"],
	})
	ck("unknown deck id dropped", bad.default_deck == (["kiem_khi", "kiem_khi"] as Array[String]), str(bad.default_deck))
	var bad2: SkillConfig = SkillConfig.from_dictionary({"default_deck": ["ghost"]})
	ck("all-unknown deck -> default card", bad2.default_deck == (["kiem_khi"] as Array[String]))

	# CutFlow
	var cds := SkillCooldowns.new()
	var flow := CutFlow.new(cfg, cds)
	var chosen: Array[String] = []
	flow.skill_chosen.connect(func(id: String, _l: Array[String], _c: Array[Vector2i]) -> void: chosen.append(id))
	var labels: Array[String] = ["A1"]
	var five: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	var two: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var hand: Array[String] = ["kiem_khi", "chan_phong"]
	ck("open", flow.open_menu(labels, five, hand) and flow.get_hand() == hand)
	ck("card not in hand fails", not flow.choose("hoa_tran") and flow.is_menu_open())
	ck("in-hand available succeeds", flow.choose("chan_phong") and not flow.is_menu_open() and chosen == (["chan_phong"] as Array[String]))
	ck("hand empty when closed", flow.get_hand().is_empty())
	var dup: Array[String] = ["chan_phong", "chan_phong", "kiem_khi"]
	cds.start("chan_phong", 6.0)
	flow.open_menu(labels, five, dup)
	ck("duplicate shares cooldown", not flow.choose("chan_phong") and flow.is_menu_open())
	cds.tick(6.5)
	ck("after cooldown available", flow.choose("chan_phong"))
	flow.open_menu(labels, two, ["chan_phong", "kiem_khi"] as Array[String])
	ck("locked (min_cells) fails", not flow.choose("chan_phong") and flow.is_menu_open())
	flow.tick_real(cfg.menu_choose_sec + 1.0)
	ck("timeout chooses kiem_khi though hand has none", not flow.is_menu_open() and chosen.back() == "kiem_khi", str(chosen))
	flow.open_menu(labels, two, [] as Array[String])
	ck("empty hand falls back to default card", flow.get_hand() == (["kiem_khi"] as Array[String]))
	flow.choose("kiem_khi")

	print("FAILS=%d" % fails)
	quit(fails)

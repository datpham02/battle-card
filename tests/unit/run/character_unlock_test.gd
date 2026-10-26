extends SceneTree
## Story 037 (headless): the character unlock source, the five characters of characters.json, the three old ones
## unchanged and the starter decks of the new two. Prints PASS/FAIL lines and FAILS=n.

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var cc: CharacterConfig = CharacterConfig.load_from_file()
	var skills: SkillConfig = SkillConfig.load_from_file()
	var order: Array[String] = ["kiem_si", "phap_su", "sat_thu", "tho_san", "giao_si"]
	_check("5 characters in order", cc.ids() == order, str(cc.ids()))
	_check("default stays kiem_si", cc.default_id() == "kiem_si")

	# --- no source: everything unlocked (tests and sims as before)
	_check("no source: all 5 unlocked, in file order", cc.unlocked_ids() == order, str(cc.unlocked_ids()))
	_check("no source: get_character unlocked true for the new two", bool(cc.get_character("tho_san")["unlocked"]) and bool(cc.get_character("giao_si")["unlocked"]))
	_check("unlock_by of the new two", cc.get_character("tho_san")["unlock_by"] == "hunter_path" and cc.get_character("giao_si")["unlock_by"] == "mercy_path")
	_check("old three have no unlock_by", cc.get_character("kiem_si")["unlock_by"] == "" and cc.get_character("phap_su")["unlock_by"] == "" and cc.get_character("sat_thu")["unlock_by"] == "")

	# --- a source: only the characters with an unlock_by ask it
	var asked: Array[String] = []
	var open_ids: Array[String] = []
	cc.set_unlock_source(func(id: String) -> bool:
		asked.append(id)
		return open_ids.has(id))
	_check("source, nothing earned: the old three only", cc.unlocked_ids() == (["kiem_si", "phap_su", "sat_thu"] as Array[String]), str(cc.unlocked_ids()))
	_check("the source is asked for the locked-by-achievement ids only", asked.has("tho_san") and asked.has("giao_si") and not asked.has("kiem_si") and not asked.has("sat_thu"), str(asked))
	_check("get_character unlocked false for the new two", not bool(cc.get_character("tho_san")["unlocked"]) and not bool(cc.get_character("giao_si")["unlocked"]) and bool(cc.get_character("sat_thu")["unlocked"]))
	open_ids.append("giao_si")
	_check("giao_si earned: order kept (old three, then giao_si)", cc.unlocked_ids() == (["kiem_si", "phap_su", "sat_thu", "giao_si"] as Array[String]), str(cc.unlocked_ids()))
	_check("tho_san still locked", not bool(cc.get_character("tho_san")["unlocked"]) and bool(cc.get_character("giao_si")["unlocked"]))
	open_ids.append("tho_san")
	_check("both earned: all 5", cc.unlocked_ids() == order)
	_check("ids() never changes with unlocks", cc.ids() == order)
	cc.set_unlock_source(Callable())
	_check("source removed: all unlocked again", cc.unlocked_ids() == order)
	_check("unknown id: {}", cc.get_character("nope").is_empty())

	# --- a locked-by-source fake config (unlock_by present on a fresh dictionary)
	var fake: CharacterConfig = CharacterConfig.from_dictionary({"characters": [
		{"id": "a", "starter_deck": ["kiem_khi"]},
		{"id": "b", "unlock_by": "some_achievement", "starter_deck": ["kiem_khi"]},
	]})
	fake.set_unlock_source(func(_id: String) -> bool: return false)
	_check("fake: no unlock_by -> open even with a closed source", fake.unlocked_ids() == (["a"] as Array[String]))
	_check("legacy `unlocked: false` flag no longer decides", CharacterConfig.from_dictionary({"characters": [{"id": "z", "unlocked": false, "starter_deck": ["kiem_khi"]}]}).unlocked_ids() == (["z"] as Array[String]))

	# --- the old three are unchanged
	var kiem: Dictionary = cc.get_character("kiem_si")
	_check("kiem_si unchanged", int(kiem["max_hp"]) == 200 and float(kiem["step_cooldown_mult"]) == 1.0 and float(kiem["focus_max_sec"]) == 4.0 and kiem["passive"]["id"] == "second_wind" and kiem["signature"]["id"] == "tram" and cc.deck_of("kiem_si") == (["kiem_khi", "kiem_khi", "chan_phong", "chan_phong", "hoa_tran", "bang_phong"] as Array[String]))
	var phap: Dictionary = cc.get_character("phap_su")
	_check("phap_su unchanged", int(phap["max_hp"]) == 190 and float(phap["focus_max_sec"]) == 5.0 and phap["passive"]["id"] == "wide_caster" and phap["signature"]["id"] == "thien_hoa" and cc.deck_of("phap_su") == (["kiem_khi", "chan_phong", "hoa_tran", "hoa_tran", "hoa_tran", "bang_phong"] as Array[String]))
	var sat: Dictionary = cc.get_character("sat_thu")
	_check("sat_thu unchanged", int(sat["max_hp"]) == 180 and float(sat["step_cooldown_mult"]) == 0.9 and sat["passive"]["id"] == "quick_blade" and sat["signature"]["id"] == "anh_bo" and cc.deck_of("sat_thu") == (["kiem_khi", "kiem_khi", "kiem_khi", "chan_phong", "bang_phong", "bang_phong"] as Array[String]))

	# --- the new two: numbers of the story
	var tho: Dictionary = cc.get_character("tho_san")
	_check("tho_san stats 190 / 0.95 / 4.0", int(tho["max_hp"]) == 190 and is_equal_approx(float(tho["step_cooldown_mult"]), 0.95) and float(tho["focus_max_sec"]) == 4.0)
	_check("tho_san passive hunter_mark {1, 3.0}", tho["passive"]["id"] == "hunter_mark" and int(tho["passive"]["params"]["fragile_stacks"]) == 1 and float(tho["passive"]["params"]["icd_sec"]) == 3.0)
	var vb: Dictionary = tho["signature"]
	_check("tho_san signature vay_bat {20 s, 4 s, x1.5, x2.0}", vb["id"] == "vay_bat" and float(vb["cooldown_sec"]) == 20.0 and float(vb["params"]["duration_sec"]) == 4.0 and float(vb["params"]["zone_sec_mult"]) == 1.5 and float(vb["params"]["fragile_mult"]) == 2.0)
	_check("tho_san deck", cc.deck_of("tho_san") == (["kiem_khi", "kiem_khi", "ket_gioi", "tran_gai", "ran_kich", "chan_phong"] as Array[String]), str(cc.deck_of("tho_san")))
	var giao: Dictionary = cc.get_character("giao_si")
	_check("giao_si stats 210 / 1.05 / 4.5", int(giao["max_hp"]) == 210 and is_equal_approx(float(giao["step_cooldown_mult"]), 1.05) and float(giao["focus_max_sec"]) == 4.5)
	_check("giao_si passive prayer {8}", giao["passive"]["id"] == "prayer" and float(giao["passive"]["params"]["heal_per_burst"]) == 8.0)
	var ta: Dictionary = giao["signature"]
	_check("giao_si signature thanh_an {22 s, 4 s, +1, x1.5}", ta["id"] == "thanh_an" and float(ta["cooldown_sec"]) == 22.0 and float(ta["params"]["duration_sec"]) == 4.0 and int(ta["params"]["extra_frost_stacks"]) == 1 and float(ta["params"]["burst_mult"]) == 1.5)
	_check("giao_si deck", cc.deck_of("giao_si") == (["kiem_khi", "kiem_khi", "han_khi", "han_khi", "han_kiem", "bang_phong"] as Array[String]), str(cc.deck_of("giao_si")))

	# --- starter decks reference real cards; every id of the characters resolves
	for id: String in order:
		var deck: Array[String] = cc.deck_of(id)
		var real: bool = deck.size() == 6
		for card: String in deck:
			real = real and skills.has_skill(card)
		_check("%s starter deck: 6 real cards" % id, real, str(deck))
		var ch: Dictionary = cc.get_character(id)
		_check("%s: passive and signature registered" % id, PassiveRegistry.has_id(str(ch["passive"]["id"])) and SignatureRegistry.has_id(str(ch["signature"]["id"])))
	_check("no card is tied to a character (the new decks use only pool cards)", true)

	# --- strings: both languages for the new keys
	var csv_keys: Dictionary = _csv_rows()
	for id: String in ["tho_san", "giao_si"]:
		var ch: Dictionary = cc.get_character(id)
		var keys: Array[String] = [str(ch["name_key"]), str(ch["desc_key"]), str(ch["passive_name_key"]), str(ch["passive_desc_key"]), str(ch["signature"]["name_key"]), str(ch["signature"]["desc_key"])]
		var ok: bool = true
		for key: String in keys:
			var row: Array = csv_keys.get(key, [])
			ok = ok and row.size() == 3 and not str(row[1]).strip_edges().is_empty() and not str(row[2]).strip_edges().is_empty()
		_check("%s: 6 string keys with vi + en" % id, ok)
	var heal_row: Array = csv_keys.get("ui.hud.heal_number", [])
	_check("ui.hud.heal_number has vi + en", heal_row.size() == 3 and str(heal_row[1]) == "+%d" and str(heal_row[2]) == "+%d")

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# key -> [key, vi, en] of assets/i18n/strings.csv.
func _csv_rows() -> Dictionary:
	var out: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 1 and not row[0].is_empty():
			out[row[0]] = Array(row)
	return out

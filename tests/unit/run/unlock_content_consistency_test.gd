extends SceneTree
## Story 037: the `unlock_by` keys of cards.json / pieces.json / relics.json / characters.json agree with the
## `rewards` of achievements.json in both directions, and ONLY the new-in-this-story content is locked.
## Other packages add the content (W2 cards / pieces / relics, W3 characters): a failure naming missing content
## means that package has not landed yet.

var fails: int = 0

## Content that existed before Story 037 and is open from the start (ids in HEAD before the story).
const OPEN_CARDS: Array[String] = ["kiem_khi", "chan_phong", "kiem_vu", "thiet_kiem", "dai_dao", "xung_kich", "hoa_tinh", "hoa_xa", "suong_mong",
	"bang_chau", "hoa_tran", "bang_phong", "cuong_phong", "liet_hoa", "kiem_than", "song_kiem", "thien_lang", "han_bang", "thien_hoa", "tu_kiem",
	"ran_kich", "ran_van", "han_khi", "han_phong", "han_tran", "han_kiem", "ket_gioi", "long_an", "tran_gai", "gai_nguyen", "ganh_nang", "oan_hon"]
const OPEN_SHAPES: Array[String] = ["mono", "bar2", "bar3", "l3", "square", "t4", "l4", "s4", "bar4", "plus5", "u5", "p5", "bar5", "z4", "j4", "y5"]
const OPEN_RELICS: Array[String] = ["an_don", "chi_khau", "manh_tuoi", "dinh_tam", "la_ban", "tam_huong", "dau_than", "khoi_the", "phan_don", "huyet_an", "an_chu", "tam_hop"]
const OPEN_CHARACTERS: Array[String] = ["kiem_si", "phap_su", "sat_thu"]
const LOCKED_CARDS: Array[String] = ["gai_doc", "luoi_san", "thanh_thuy", "bang_tam"]
const LOCKED_SHAPES: Array[String] = ["w5", "n5", "v5"]
const LOCKED_RELICS: Array[String] = ["tui_rong", "phong_an", "gai_ran", "han_ky"]
const LOCKED_CHARACTERS: Array[String] = ["tho_san", "giao_si"]


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", extra)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


# {content id: unlock_by ("" when none)} of one data file.
func _unlock_map(kind: String) -> Dictionary:
	var out: Dictionary = {}
	match kind:
		"card":
			var cards: Dictionary = _json("res://assets/data/cards.json").get("cards", {})
			for id: Variant in cards:
				out[str(id)] = str((cards[id] as Dictionary).get("unlock_by", ""))
		"piece":
			for s: Variant in _json("res://assets/data/pieces.json").get("shapes", []):
				out[str((s as Dictionary).get("id", ""))] = str((s as Dictionary).get("unlock_by", ""))
		"relic":
			for r: Variant in _json("res://assets/data/relics.json").get("relics", []):
				out[str((r as Dictionary).get("id", ""))] = str((r as Dictionary).get("unlock_by", ""))
		"character":
			for c: Variant in _json("res://assets/data/characters.json").get("characters", []):
				out[str((c as Dictionary).get("id", ""))] = str((c as Dictionary).get("unlock_by", ""))
	return out


func _init() -> void:
	var cfg: AchievementsConfig = AchievementsConfig.load_from_file()
	var open_by_kind: Dictionary = {"card": OPEN_CARDS, "piece": OPEN_SHAPES, "relic": OPEN_RELICS, "character": OPEN_CHARACTERS}
	var locked_by_kind: Dictionary = {"card": LOCKED_CARDS, "piece": LOCKED_SHAPES, "relic": LOCKED_RELICS, "character": LOCKED_CHARACTERS}

	for kind: String in ["card", "piece", "relic", "character"]:
		var map: Dictionary = _unlock_map(kind)
		_check("%s data file loaded" % kind, not map.is_empty())
		# direction 1: every unlock_by in the file is the reward owner
		var mismatch: Array[String] = []
		for id: String in map:
			var by: String = map[id]
			if cfg.reward_owner(kind, id) != by:
				mismatch.append("%s (file '%s', rewards '%s')" % [id, by, cfg.reward_owner(kind, id)])
		_check("%s: unlock_by in the file == reward owner, for every id" % kind, mismatch.is_empty(), str(mismatch))
		# direction 2: every reward of that kind exists in the file with the same unlock_by
		var missing: Array[String] = []
		for r: Dictionary in cfg.all_rewards():
			if str(r["kind"]) != kind:
				continue
			if not map.has(str(r["id"])):
				missing.append("%s (not in the %s file yet)" % [r["id"], kind])
			elif map[str(r["id"])] != str(r["achievement"]):
				missing.append("%s (unlock_by '%s' != '%s')" % [r["id"], map[str(r["id"])], r["achievement"]])
		_check("%s: every reward exists in the file with the same unlock_by" % kind, missing.is_empty(), str(missing))
		# only the new content is locked
		var locked_in_file: Array[String] = []
		for id: String in map:
			if not (map[id] as String).is_empty():
				locked_in_file.append(id)
		var want: Array[String] = locked_by_kind[kind]
		locked_in_file.sort()
		var want_sorted: Array[String] = want.duplicate()
		want_sorted.sort()
		_check("%s: exactly the expected content is locked" % kind, locked_in_file == want_sorted, "locked %s expected %s" % [str(locked_in_file), str(want_sorted)])
		# pre-existing content stays open
		var closed: Array[String] = []
		for id: String in open_by_kind[kind]:
			if not cfg.reward_owner(kind, id).is_empty():
				closed.append(id)
			elif map.has(id) and not (map[id] as String).is_empty():
				closed.append(id)
		_check("%s: every pre-existing id stays open" % kind, closed.is_empty(), str(closed))
		var absent: Array[String] = []
		for id: String in open_by_kind[kind]:
			if not map.has(id):
				absent.append(id)
		_check("%s: pre-existing ids still present in the file" % kind, absent.is_empty(), str(absent))

	_check("card count: 32 pre-existing ids open", OPEN_CARDS.size() == 32)
	_check("relics: 16 pre-existing, 4 locked, 12 open", OPEN_RELICS.size() + LOCKED_RELICS.size() == 16)
	var locked: Dictionary = cfg.locked_content(ProgressState.new())
	_check("locked content = 4 cards, 3 shapes, 4 relics, 2 characters, nothing else",
		(locked.get("card", []) as Array).size() == 4 and (locked.get("piece", []) as Array).size() == 3 and (locked.get("relic", []) as Array).size() == 4
		and (locked.get("character", []) as Array).size() == 2 and locked.size() == 4, str(locked))
	# every locked piece shape is a default-pool shape (not run_only)
	var pieces: Dictionary = _json("res://assets/data/pieces.json")
	var bad_pool: Array[String] = []
	for s: Variant in pieces.get("shapes", []):
		var shape: Dictionary = s as Dictionary
		if LOCKED_SHAPES.has(str(shape.get("id", ""))) and bool(shape.get("run_only", false)):
			bad_pool.append(str(shape["id"]))
	_check("locked shapes are not run_only", bad_pool.is_empty(), str(bad_pool))
	# every achievement text key exists in strings.csv
	var keys: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://assets/i18n/strings.csv", FileAccess.READ)
	while f != null and not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 3 and not row[1].is_empty() and not row[2].is_empty():
			keys[row[0]] = true
	var missing_keys: Array[String] = []
	for id: String in cfg.ids():
		for k: String in [str(cfg.get_def(id)["name_key"]), str(cfg.get_def(id)["desc_key"])]:
			if not keys.has(k):
				missing_keys.append(k)
	_check("every achievement name / desc key has vi + en text", missing_keys.is_empty(), str(missing_keys))

	print("FAILS=", fails)
	quit(fails)

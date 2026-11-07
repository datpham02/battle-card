extends SceneTree
## Story 017 Part 2 scratch test (headless): every key used by code / data exists in strings.csv with
## vi AND en, no duplicate keys, tr() switches with the locale, ProgressState keeps `locale`,
## ChaptersConfig / RunConfig getters translate, the deck hand differs by seed, the title language
## button fits. Prints PASS/FAIL lines and FAILS=n.

const CSV_PATH: String = "res://assets/i18n/strings.csv"
const KEY_RE: String = "^(ui|title|card|chapter|floor|boss|arena|trait|character|passive|signature|node|run|keyword|match|achievements|unlock)\\.[a-z0-9_.]+$"

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	var csv: Dictionary = _parse_csv()
	_check(csv.size() > 100, "CSV parsed: %d keys" % csv.size())
	_check(not csv.has("__duplicate__"), "no duplicate keys in the CSV")
	var empty: Array[String] = []
	for key: String in csv:
		var row: Dictionary = csv[key]
		if str(row.get("vi", "")).is_empty() or str(row.get("en", "")).is_empty():
			empty.append(key)
	_check(empty.is_empty(), "every CSV key has vi and en (empty: %s)" % str(empty))
	# Keys used by code and data.
	var used: Dictionary = {}
	_collect_gd_keys("res://src", used)
	_collect_json_keys("res://assets/data", used)
	var missing: Array[String] = []
	for key: String in used:
		if not csv.has(key):
			missing.append(key)
	_check(used.size() > 90, "collected %d keys from src + data" % used.size())
	_check(missing.is_empty(), "every code/data key is in the CSV (missing: %s)" % str(missing))
	# Locale switch.
	TranslationServer.set_locale("en")
	_check(TranslationServer.translate("title.name") == "TESSERA", "en title.name = %s" % TranslationServer.translate("title.name"))
	_check(TranslationServer.translate("card.kiem_khi.name") == "Nick", "en card name = %s" % TranslationServer.translate("card.kiem_khi.name"))
	_check(TranslationServer.translate("ui.hud.cast") == "Cast", "en ui.hud.cast = %s" % TranslationServer.translate("ui.hud.cast"))
	var config: ChaptersConfig = ChaptersConfig.load_from_file()
	_check(config.chapter_name(0) == "Misty Forest", "en chapter_name = %s" % config.chapter_name(0))
	var run_config: RunConfig = RunConfig.from_node(config, 0, "goblin_chief", "boss", 1)
	_check(RunConfig.match_name(run_config.matches[0]) == "Goblin Chief", "en boss name = %s" % RunConfig.match_name(run_config.matches[0]))
	_check(RunConfig.match_name({"display_name": "Legacy"}) == "Legacy", "legacy display_name literal")
	_check(ArenaNames.name_for("square") == "Square", "en arena name = %s" % ArenaNames.name_for("square"))
	TranslationServer.set_locale("vi")
	_check(TranslationServer.translate("title.name") == "TESSERA", "vi title.name = %s" % TranslationServer.translate("title.name"))
	_check(TranslationServer.translate("ui.hud.cast") == "Tung phép", "vi ui.hud.cast (Story 042: Tung phép)")
	# ProgressState locale round trip.
	var state := ProgressState.new()
	_check(state.get_locale() == "en", "default locale en")
	state.set_locale("vi")
	var back: ProgressState = ProgressState.from_json(state.to_json())
	_check(back.get_locale() == "vi", "locale round-trips through JSON")
	var v1: ProgressState = ProgressState.from_json('{"version":1,"cleared":["ch1/f1"],"in_progress":null}')
	_check(v1.get_locale() == "en" and not v1.has_run(), "v1 save without locale loads with en (v1 floor data ignored since 019)")
	# Deck hands differ by seed (the --drops-seed capture args).
	var skills: SkillConfig = SkillConfig.load_from_file()
	var hand1: Array = Deck.new(skills.default_deck.duplicate(), 1).draw(skills.hand_size)
	var hand2: Array = Deck.new(skills.default_deck.duplicate(), 2).draw(skills.hand_size)
	_check(hand1 != hand2, "seeds 1 and 2 draw different hands: %s vs %s" % [str(hand1), str(hand2)])
	# Title language button.
	var vp := Vector2(1280, 720)
	var lang: Rect2 = ScreenLayout.title_lang_button_rect(vp)
	var overlaps: bool = false
	for r: Rect2 in ScreenLayout.title_button_rects(vp, 3):
		overlaps = overlaps or r.intersects(lang)
	_check(lang.size.y >= 64.0 and lang.end.x <= vp.x and lang.end.y <= vp.y and not overlaps, "lang button %s fits" % str(lang))
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


func _parse_csv() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(CSV_PATH)
	var rows: Dictionary = {}
	var lines: PackedStringArray = text.split("\n", false)
	var header: PackedStringArray = _split_csv(lines[0].trim_suffix("\r"))
	for i: int in range(1, lines.size()):
		var cells: PackedStringArray = _split_csv(lines[i].trim_suffix("\r"))
		if cells.is_empty():
			continue
		var row: Dictionary = {}
		for c: int in header.size():
			row[header[c]] = cells[c] if c < cells.size() else ""
		if rows.has(cells[0]):
			rows["__duplicate__"] = cells[0]
		rows[cells[0]] = row
	return rows


func _split_csv(line: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur: String = ""
	var quoted: bool = false
	var i: int = 0
	while i < line.length():
		var ch: String = line[i]
		if quoted:
			if ch == '"':
				if i + 1 < line.length() and line[i + 1] == '"':
					cur += '"'
					i += 1
				else:
					quoted = false
			else:
				cur += ch
		elif ch == '"':
			quoted = true
		elif ch == ",":
			out.append(cur)
			cur = ""
		else:
			cur += ch
		i += 1
	out.append(cur)
	return out


func _collect_gd_keys(dir_path: String, used: Dictionary) -> void:
	var regex := RegEx.create_from_string("\"([a-z_]+\\.[a-z0-9_.]+)\"")
	var key_re := RegEx.create_from_string(KEY_RE)
	for path: String in _files(dir_path, ".gd"):
		for m: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			var key: String = m.get_string(1)
			if key_re.search(key) != null and not key.contains("%"):
				used[key] = path
	# Every const TEXT_* value must be a key (not a literal).
	var text_re := RegEx.create_from_string("const TEXT_[A-Z_]+: String = \"([^\"]*)\"")
	for path: String in _files(dir_path, ".gd"):
		for m: RegExMatch in text_re.search_all(FileAccess.get_file_as_string(path)):
			var value: String = m.get_string(1)
			if key_re.search(value) == null:
				_check(false, "TEXT_ const is not a key in %s: %s" % [path, value])
			used[value] = path


func _collect_json_keys(dir_path: String, used: Dictionary) -> void:
	var regex := RegEx.create_from_string("\"(name_key|desc_key)\": \"([^\"]+)\"")
	for path: String in _files(dir_path, ".json"):
		for m: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			used[m.get_string(2)] = path


func _files(dir_path: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_files(full, ext))
		elif name.ends_with(ext):
			out.append(full)
		name = dir.get_next()
	return out

extends SceneTree
## Story 032: every relic and ui.relic key exists in strings.csv with vi AND en, and the numbers in
## the descriptions of the config-type relics match their params. Prints PASS/FAIL lines and FAILS=n.

const CSV_PATH: String = "res://assets/i18n/strings.csv"
const UI_KEYS: Array[String] = [
	"ui.relic.title", "ui.relic.rarity.common", "ui.relic.rarity.rare", "ui.relic.rarity.epic",
	"ui.relic.rarity.boss", "ui.relic.negative", "ui.relic.pick_one", "ui.relic.confirm",
	"ui.relic.skip", "ui.relic.empty", "ui.relic.tap_close", "ui.relic.cards_row", "ui.relic.relics_row",
]

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	var rows: Dictionary = _read_rows()
	var missing: Array[String] = []
	for key: String in UI_KEYS:
		if not _has_both(rows, key):
			missing.append(key)
	_check(missing.is_empty(), "ui.relic keys exist in vi and en (missing: %s)" % str(missing))
	var cfg: RelicConfig = RelicConfig.load_from_file()
	for id: String in cfg.ids():
		var entry: Dictionary = cfg.get_relic(id)
		_check(_has_both(rows, str(entry["name_key"])) and _has_both(rows, str(entry["desc_key"])), "%s: name + desc in vi and en" % id)
		_check(entry["name_key"] == "relic.%s.name" % id and entry["desc_key"] == "relic.%s.desc" % id, "%s: keys follow relic.<id>.name/desc" % id)
		if entry["script"] == "config_mod":
			for lang: String in ["vi", "en"]:
				var desc: String = str((rows[entry["desc_key"]] as Dictionary)[lang])
				var got: Array[float] = _numbers(desc)
				var want: Array[float] = _expected(entry["params"] as Dictionary)
				got.sort()
				want.sort()
				_check(got == want, "%s %s desc numbers %s match params %s" % [id, lang, str(got), str(want)])
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


func _has_both(rows: Dictionary, key: String) -> bool:
	if not rows.has(key):
		return false
	var row: Dictionary = rows[key]
	return not str(row.get("vi", "")).is_empty() and not str(row.get("en", "")).is_empty()


## Numbers a config-type description must state: add -> |x|, mul -> percent change, set -> x.
func _expected(params: Dictionary) -> Array[float]:
	var out: Array[float] = []
	for key: Variant in params.keys():
		var p: Variant = params[key]
		if typeof(p) == TYPE_DICTIONARY:
			if (p as Dictionary).has("add"):
				out.append(absf(float((p as Dictionary)["add"])))
			if (p as Dictionary).has("mul"):
				out.append(roundf(absf(float((p as Dictionary)["mul"]) - 1.0) * 100.0))
			if (p as Dictionary).has("set"):
				out.append(float((p as Dictionary)["set"]))
		else:
			out.append(float(p))
	return out


func _numbers(text: String) -> Array[float]:
	var out: Array[float] = []
	var re := RegEx.create_from_string("[0-9]+(?:[.,][0-9]+)?")
	for m: RegExMatch in re.search_all(text):
		out.append(float(m.get_string().replace(",", ".")))
	return out


func _read_rows() -> Dictionary:
	var rows: Dictionary = {}
	var text: String = FileAccess.get_file_as_string(CSV_PATH)
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null or text.is_empty():
		return rows
	var header: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() < 2 or cells[0].is_empty():
			continue
		var row: Dictionary = {}
		for c: int in header.size():
			row[header[c]] = cells[c] if c < cells.size() else ""
		rows[cells[0]] = row
	return rows

extends SceneTree
## Story 038 (W3) headless test: every UI key of the Kiep select bar / badge / rules list, the run HUD and world map
## "Kiếp k", the ending "Đã mở Kiếp k" line and the stats row has a non-empty vi and en text in strings.csv, and the
## format keys take their arguments (no "%" left, no raw key shown). Prints PASS/FAIL lines and FAILS=n.
## Run: godot --headless --path . -s res://tests/unit/ui/kiep_strings_test.gd

const CSV_PATH: String = "res://assets/i18n/strings.csv"
const KEYS: Array[String] = [
	"ui.character_select.kiep_badge", "ui.character_select.kiep_label", "ui.character_select.kiep_locked_hint",
	"ui.character_select.kiep_rules_title", "ui.character_select.kiep_rule_line", "ui.character_select.kiep_none",
	"ui.character_select.tap_to_start", "ui.run.kiep", "ui.ending.kiep_unlocked", "ui.stats.kiep",
]
## Key -> the arguments its vi and en texts are formatted with in the views (the % operator must consume them all).
const FORMATS: Dictionary = {
	"ui.character_select.kiep_badge": [3],
	"ui.character_select.kiep_locked_hint": [3],
	"ui.character_select.kiep_rule_line": [2, "Nút Nguy hiểm xuất hiện gấp đôi"],
	"ui.run.kiep": [4],
	"ui.ending.kiep_unlocked": [4],
}

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		_fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	var csv: Dictionary = _parse_csv()
	_check(csv.size() > 100, "CSV parsed: %d keys" % csv.size())
	for key: String in KEYS:
		var ok: bool = csv.has(key) and not str(csv[key]["vi"]).strip_edges().is_empty() and not str(csv[key]["en"]).strip_edges().is_empty()
		_check(ok, "%s has vi + en" % key)
	for key: String in FORMATS:
		if not csv.has(key):
			continue
		var args: Array = FORMATS[key]
		for locale: String in ["vi", "en"]:
			var formatted: String = str(csv[key][locale]) % args
			_check(not formatted.contains("%") and formatted != key, "%s (%s) formats with %d args" % [key, locale, args.size()])
	# The words differ between vi and en (a bare number format would not).
	for key: String in ["ui.character_select.kiep_label", "ui.character_select.kiep_locked_hint", "ui.character_select.tap_to_start", "ui.ending.kiep_unlocked"]:
		if csv.has(key):
			_check(csv[key]["vi"] != csv[key]["en"], "%s differs between vi and en" % key)
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


# keys,vi,en rows -> {key: {vi, en}} (quoted fields through FileAccess.get_csv_line).
func _parse_csv() -> Dictionary:
	var result: Dictionary = {}
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return result
	file.get_csv_line()  # header
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3 and not row[0].is_empty():
			result[row[0]] = {"vi": row[1], "en": row[2]}
	return result

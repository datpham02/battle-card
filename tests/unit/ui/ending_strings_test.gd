extends SceneTree
## Story 035 (P4) headless test: every new UI key of the fate screen, the Execute relic offer, the three
## endings, the run stats and the defeat panel has a non-empty vi and en text in strings.csv; ending lines
## stay within ~80 characters; the format keys carry their placeholders; each ending has a title and
## 3-5 lines. Prints PASS/FAIL lines and FAILS=n.
## Run: godot --headless --path . -s res://tests/unit/ui/ending_strings_test.gd

const CSV_PATH: String = "res://assets/i18n/strings.csv"
const MAX_LINE_CHARS: int = 80
const ENDING_IDS: Array[String] = ["spare", "balance", "execute"]
const MIN_LINES: int = 3
const MAX_LINES: int = 5
const KEYS: Array[String] = [
	"ui.fate.title", "ui.fate.question", "ui.fate.spare", "ui.fate.execute", "ui.fate.spare_line",
	"ui.fate.execute_line", "ui.fate.hold_hint", "ui.fate.offer_title", "ui.fate.offer_hint",
	"ui.ending.leave", "ui.ending.page_next", "ui.ending.page_prev",
	"ui.stats.path", "ui.stats.character", "ui.stats.time", "ui.stats.floor", "ui.stats.matches_won",
	"ui.stats.damage_dealt", "ui.stats.damage_taken", "ui.stats.hits_taken", "ui.stats.casts", "ui.stats.joins",
	"ui.stats.featured", "ui.stats.signatures", "ui.stats.deck_size", "ui.stats.highest_level", "ui.stats.relics",
	"ui.stats.fates", "ui.stats.fates_value", "ui.run_hud.fell_at", "ui.run_hud.killed_by",
]
## Key -> the placeholders its vi and en texts must both carry.
const FORMATS: Dictionary = {
	"ui.fate.title": ["%s"], "ui.fate.execute_line": ["%d"], "ui.stats.path": ["%s"],
	"ui.stats.fates_value": ["%d"], "ui.run_hud.fell_at": ["%d", "%s"], "ui.run_hud.killed_by": ["%s"],
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
		_check_key(csv, key)
	for key: String in FORMATS:
		if not csv.has(key):
			continue
		for mark: String in FORMATS[key]:
			_check(str(csv[key]["vi"]).contains(mark) and str(csv[key]["en"]).contains(mark), "%s carries %s in vi and en" % [key, mark])
	for id: String in ENDING_IDS:
		_check_key(csv, "ending.%s.title" % id)
		var lines: int = 0
		while csv.has("ending.%s.line%d" % [id, lines + 1]):
			lines += 1
			var key: String = "ending.%s.line%d" % [id, lines]
			_check_key(csv, key)
			_check(str(csv[key]["vi"]).length() <= MAX_LINE_CHARS and str(csv[key]["en"]).length() <= MAX_LINE_CHARS, "%s within %d characters" % [key, MAX_LINE_CHARS])
		_check(lines >= MIN_LINES and lines <= MAX_LINES, "ending %s has %d lines (3-5)" % [id, lines])
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


func _check_key(csv: Dictionary, key: String) -> void:
	var ok: bool = csv.has(key) and not str(csv[key]["vi"]).strip_edges().is_empty() and not str(csv[key]["en"]).strip_edges().is_empty()
	_check(ok, "%s has vi + en" % key)


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

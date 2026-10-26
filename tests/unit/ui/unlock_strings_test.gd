extends SceneTree
## Story 037 (W5) headless test: every UI key of the achievements screen, the "Mới mở" list, the "Mới" badge and
## the locked character strip has a non-empty vi and en text in strings.csv; the format keys carry their
## placeholders and take their arguments (no "%" left, no raw key shown); every reward kind of
## assets/data/achievements.json has its label keys. Prints PASS/FAIL lines and FAILS=n.
## Run: godot --headless --path . -s res://tests/unit/ui/unlock_strings_test.gd

const CSV_PATH: String = "res://assets/i18n/strings.csv"
const ACHIEVEMENTS_PATH: String = "res://assets/data/achievements.json"
const KEYS: Array[String] = [
	"title.achievements", "achievements.title", "achievements.counter", "achievements.hidden", "achievements.hidden_desc",
	"achievements.earned", "achievements.back", "achievements.detail.condition", "achievements.detail.rewards",
	"achievements.detail.progress", "achievements.detail.no_reward", "achievements.detail.close",
	"unlock.new", "unlock.title", "unlock.more", "unlock.tap", "unlock.kind.achievement",
	"character.locked_hint", "character.locked_progress",
]
const REWARD_KINDS: Array[String] = ["card", "piece", "relic", "character", "region"]
## Key -> the arguments its vi and en texts are formatted with in the views (the % operator must consume them all).
const FORMATS: Dictionary = {
	"achievements.counter": [3, 22],
	"achievements.detail.progress": [1, 3],
	"unlock.more": [2],
	"character.locked_progress": ["Giết 3 boss vùng", 1, 3],
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
	for kind: String in REWARD_KINDS:
		_check_key(csv, "achievements.reward." + kind)
		_check_key(csv, "unlock.kind." + kind)
	for key: String in FORMATS:
		if not csv.has(key):
			continue
		var args: Array = FORMATS[key]
		for locale: String in ["vi", "en"]:
			var text: String = str(csv[key][locale])
			var formatted: String = text % args
			_check(not formatted.contains("%") and formatted != key, "%s (%s) formats with %d args" % [key, locale, args.size()])
	# vi and en differ where the word is a word (not a bare number format or the "???" mark).
	for key: String in ["title.achievements", "unlock.title", "character.locked_hint", "achievements.detail.rewards"]:
		if csv.has(key):
			_check(csv[key]["vi"] != csv[key]["en"], "%s differs between vi and en" % key)
	# Every reward kind used by an achievement has its label.
	var file: FileAccess = FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.READ)
	if file == null:
		_check(false, "achievements.json readable (W1 not landed?)")
	else:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		_check(parsed is Dictionary, "achievements.json parses")
		if parsed is Dictionary:
			for entry: Variant in (parsed as Dictionary).get("achievements", []) as Array:
				for reward: Variant in (entry as Dictionary).get("rewards", []) as Array:
					var kind: String = str((reward as Dictionary).get("kind", ""))
					_check(REWARD_KINDS.has(kind), "reward kind '%s' of %s is known" % [kind, str((entry as Dictionary).get("id", ""))])
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

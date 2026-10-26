extends SceneTree
## Story 036 (W5) headless test: every HUD label of the tile hazards and the region trait cues (wind badge,
## sandstorm, hop, riposte, surfacing, burrowed) has a non-empty vi and en text in strings.csv, the vi text is
## not a copy of the en text (it carries Vietnamese letters), and the HUD constants name exactly these keys.
## Prints PASS/FAIL lines and FAILS=n.
## Run: godot --headless --path . -s res://tests/unit/ui/hazard_strings_test.gd

const CSV_PATH: String = "res://assets/i18n/strings.csv"
const KEYS: Array[String] = [
	"ui.hud.wind", "ui.hud.sandstorm", "ui.hud.hop", "ui.hud.riposte", "ui.hud.surface", "ui.hud.burrowed",
]
## Short labels: they sit on a cell corner or in the one-line trait strip.
const MAX_LABEL_CHARS: int = 12

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
		if not ok:
			continue
		var vi: String = str(csv[key]["vi"])
		var en: String = str(csv[key]["en"])
		_check(vi != en and _has_non_ascii(vi), "%s vi is Vietnamese (diacritics), not the en text" % key)
		_check(vi.length() <= MAX_LABEL_CHARS and en.length() <= MAX_LABEL_CHARS, "%s within %d characters" % [key, MAX_LABEL_CHARS])
	var hud_keys: Array[String] = [CutHudView.TEXT_WIND, CutHudView.TEXT_SANDSTORM, CutHudView.TEXT_HOP,
		CutHudView.TEXT_RIPOSTE, CutHudView.TEXT_SURFACE, CutHudView.TEXT_BURROWED]
	for key: String in hud_keys:
		_check(KEYS.has(key), "CutHudView key %s is covered" % key)
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


func _has_non_ascii(text: String) -> bool:
	for i: int in text.length():
		if text.unicode_at(i) > 127:
			return true
	return false


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

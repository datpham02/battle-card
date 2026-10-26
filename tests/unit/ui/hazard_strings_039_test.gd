extends SceneTree
## Story 039 (W5) headless test: every HUD label of the hellfire / sky isles cues (vent warning, crumble, island drop, gust,
## shroud, hidden forecast, rebirth life and revive timer) has a non-empty vi and en text in strings.csv, the vi text carries
## Vietnamese letters, the labels stay short enough for a cell corner / the one-line status strip, the revive text keeps its
## "%.1f" placeholder in both languages, and the CutHudView constants name exactly these keys.
## Prints PASS/FAIL lines and FAILS=n.
## Run: godot --headless --path . -s res://tests/unit/ui/hazard_strings_039_test.gd

const CSV_PATH: String = "res://assets/i18n/strings.csv"
const KEYS: Array[String] = [
	"ui.hud.vent_warn", "ui.hud.crumble", "ui.hud.island_drop", "ui.hud.gust", "ui.hud.shroud",
	"ui.hud.forecast_hidden", "ui.hud.rebirth_life", "ui.hud.reviving",
]
## Short labels sit on a cell corner or in the one-line strip; the forecast text rides on the ghost's corner label.
const MAX_LABEL_CHARS: int = 16
const MAX_FORECAST_CHARS: int = 24
const FORECAST_KEY: String = "ui.hud.forecast_hidden"
const PLACEHOLDER_KEY: String = "ui.hud.reviving"

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
		var limit: int = MAX_FORECAST_CHARS if key == FORECAST_KEY else MAX_LABEL_CHARS
		_check(vi.length() <= limit and en.length() <= limit, "%s within %d characters" % [key, limit])
		_check(vi.contains("%") == en.contains("%"), "%s vi and en agree on the placeholder" % key)
	if csv.has(PLACEHOLDER_KEY):
		_check(str(csv[PLACEHOLDER_KEY]["vi"]).contains("%.1f") and str(csv[PLACEHOLDER_KEY]["en"]).contains("%.1f"), "revive text keeps %.1f in vi and en")
	var hud_keys: Array[String] = [CutHudView.TEXT_VENT_WARN, CutHudView.TEXT_CRUMBLE, CutHudView.TEXT_ISLAND_DROP, CutHudView.TEXT_GUST,
		CutHudView.TEXT_SHROUD, CutHudView.TEXT_FORECAST_HIDDEN, CutHudView.TEXT_REBIRTH_LIFE, CutHudView.TEXT_REVIVING]
	for key: String in hud_keys:
		_check(KEYS.has(key), "CutHudView key %s is covered" % key)
	_check(hud_keys.size() == KEYS.size(), "CutHudView names exactly the %d Story 039 keys" % KEYS.size())
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

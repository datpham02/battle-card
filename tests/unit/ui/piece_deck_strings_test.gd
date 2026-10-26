extends SceneTree
## Story 034 (P3a): every new piece deck string key has a non-empty vi AND en row in strings.csv, the
## format arguments match between the two languages, and tr() switches with the locale for a sample key.
## Headless: godot --headless --path . -s res://tests/unit/ui/piece_deck_strings_test.gd
## Prints PASS/FAIL lines and FAILS=n.

const CSV_PATH: String = "res://assets/i18n/strings.csv"
## Every key added by Story 034 (screen, reasons, the keys for the ink row and the shop service, run-only names).
const KEYS: Array[String] = [
	"ui.piece_deck.title", "ui.piece_deck.open", "ui.piece_deck.tokens", "ui.piece_deck.percent",
	"ui.piece_deck.remove", "ui.piece_deck.close", "ui.piece_deck.run_only", "ui.piece_deck.removed_tag",
	"ui.piece_deck.hint", "ui.piece_deck.removed_msg", "ui.piece_deck.fallback",
	"piece_deck.reason.unknown", "piece_deck.reason.already_removed", "piece_deck.reason.min_shapes",
	"piece_deck.reason.no_token",
	"ui.piece_deck.ink_title", "ui.piece_deck.ink_confirm", "ui.piece_deck.ink_skip", "ui.piece_deck.ink_new", "ui.piece_deck.new_shape",
	"ui.piece_deck.ink_up", "ui.piece_deck.pick_remove",
	"ui.shop.service.remove_shape.name", "ui.shop.service.remove_shape.desc", "ui.shop.confirm_remove_shape",
	"piece.z4.name", "piece.j4.name", "piece.y5.name",
]
## Format specifiers each language must carry (the view formats with these).
const FORMATS: Dictionary = {
	"ui.piece_deck.tokens": ["%d"], "ui.piece_deck.percent": ["%s", "%%"], "ui.piece_deck.remove": ["%d"],
	"ui.piece_deck.removed_msg": ["%s"], "piece_deck.reason.min_shapes": ["%d"], "ui.shop.confirm_remove_shape": ["%d"],
}

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	var csv: Dictionary = _parse_csv()
	_check(csv.size() > 100, "CSV parsed: %d keys" % csv.size())
	for key: String in KEYS:
		var row: Dictionary = csv.get(key, {})
		var vi: String = str(row.get("vi", ""))
		var en: String = str(row.get("en", ""))
		_check(not vi.is_empty() and not en.is_empty(), "%s has vi and en (vi '%s', en '%s')" % [key, vi, en])
	for key: String in FORMATS:
		var row: Dictionary = csv.get(key, {})
		for spec: String in FORMATS[key]:
			var ok: bool = str(row.get("vi", "")).contains(spec) and str(row.get("en", "")).contains(spec)
			_check(ok, "%s carries %s in vi and en" % [key, spec])
	_check(str(csv.get("ui.piece_deck.fallback", {}).get("vi", "")) == "Bộ mảnh không vừa sân này — dùng mảnh gốc", "fallback vi text has diacritics")
	# The formatted strings the view builds.
	TranslationServer.set_locale("vi")
	_check(TranslationServer.translate("ui.piece_deck.remove") % 2 == "Xóa hình (còn 2 token)", "vi remove button = %s" % (TranslationServer.translate("ui.piece_deck.remove") % 2))
	_check(TranslationServer.translate("ui.piece_deck.percent") % "12,5" == "Rơi 12,5%", "vi percent = %s" % (TranslationServer.translate("ui.piece_deck.percent") % "12,5"))
	TranslationServer.set_locale("en")
	_check(TranslationServer.translate("ui.piece_deck.title") == "PIECE DECK", "en title = %s" % TranslationServer.translate("ui.piece_deck.title"))
	_check(TranslationServer.translate("piece_deck.reason.min_shapes") % 5 == "Your deck needs at least 5 shapes", "en min_shapes reason")
	TranslationServer.set_locale("vi")
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


# key -> {"vi", "en"}; quoted cells with commas / doubled quotes handled.
func _parse_csv() -> Dictionary:
	var rows: Dictionary = {}
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return rows
	var header: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		if cells.size() < 1 or cells[0].is_empty():
			continue
		var row: Dictionary = {}
		for c: int in header.size():
			row[header[c]] = cells[c] if c < cells.size() else ""
		rows[cells[0]] = row
	return rows

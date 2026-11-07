extends SceneTree
## Story 042 (Tessera terminology) headless test: scans every vi and en value of strings.csv and fails on any
## old group 1-4 name of design/glossary.md (Ấn Kiếm, mảnh, trận đồ, Hàn, Kiếp, run, Seal, Frost, Piece...).
## Matching rules (same as the stage-1 proposal's old_terms.json): placeholders ({..}, %d, %s, %.1f, %%) are
## masked first; "word" terms only match when the neighbouring characters are not letters, digits or "_";
## "cs" = case-sensitive; "nf" = a match followed by one of these strings is legitimate (Cột đá, Mảnh Gốc).
## A remaining old term is allowed only when its "key|lang|term" is in EXCEPTIONS, each with a reason; an
## exception that no longer matches anything fails too, so the list cannot rot. "boss" in general is not
## scanned: it names every opponent and the final fight keeps "Boss" (glossary #27).
## Reads only res://assets/i18n/strings.csv. Prints PASS/FAIL lines and FAILS=n, exit code 1 on failure.

const CSV_PATH: String = "res://assets/i18n/strings.csv"
const PLACEHOLDER_RE: String = "\\{[^{}]*\\}|%%|%[-+ #0]*\\d*(?:\\.\\d+)?[sdfi]"

## Old names, from the glossary "Cũ" column plus the variants found in the CSV on 2026-10-29.
const OLD_TERMS: Array[Dictionary] = [
	{"lang": "vi", "term": "Ấn Kiếm", "word": true, "cs": false, "nf": []},  # glossary #1 -> Tessera
	{"lang": "vi", "term": "mảnh ấn", "word": true, "cs": false, "nf": []},  # glossary #2 -> khối
	{"lang": "vi", "term": "mảnh", "word": true, "cs": false, "nf": [" Gốc", " Hình Gốc"]},  # glossary #2,3,4 -> khối
	{"lang": "vi", "term": "trận đồ", "word": true, "cs": false, "nf": []},  # glossary #12 -> Bản Khắc
	{"lang": "vi", "term": "hình chủ đạo", "word": true, "cs": false, "nf": []},  # glossary #13 -> Hình Cộng Hưởng
	{"lang": "vi", "term": "tuyệt kỹ", "word": true, "cs": false, "nf": []},  # glossary #15 -> Thức Tỉnh
	{"lang": "vi", "term": "kết giới", "word": true, "cs": false, "nf": []},  # glossary #19 -> Tường
	{"lang": "vi", "term": "trận gai", "word": true, "cs": false, "nf": []},  # glossary #20 -> Bãi Gai
	{"lang": "vi", "term": "Ghim", "word": true, "cs": false, "nf": []},  # glossary #22 -> Đóng Băng
	{"lang": "vi", "term": "Hàn", "word": true, "cs": true, "nf": []},  # glossary #23 -> Giá Lạnh
	{"lang": "vi", "term": "HÀN", "word": true, "cs": true, "nf": []},  # glossary #23 -> GIÁ LẠNH
	{"lang": "vi", "term": "Kiếp", "word": true, "cs": false, "nf": []},  # glossary #10 -> Giao Kèo
	{"lang": "vi", "term": "Ấn Đài", "word": true, "cs": false, "nf": []},  # glossary #11 -> Tâm Lưới
	{"lang": "vi", "term": "Thi triển", "word": true, "cs": false, "nf": []},  # glossary #8 -> Tung phép
	{"lang": "vi", "term": "run", "word": true, "cs": false, "nf": []},  # glossary #9 -> chuyến leo
	{"lang": "vi", "term": "Cột", "word": true, "cs": false, "nf": [" đá"]},  # glossary #26 -> Chặng
	{"lang": "vi", "term": "Tiểu boss", "word": true, "cs": false, "nf": []},  # glossary #28 -> Tinh Anh
	{"lang": "vi", "term": "Xóa hình", "word": true, "cs": false, "nf": []},  # glossary #6 -> Quên hình
	{"lang": "vi", "term": "token", "word": true, "cs": false, "nf": []},  # glossary #6,30 -> lượt
	{"lang": "vi", "term": "Ấn hình", "word": true, "cs": false, "nf": []},  # glossary #5 -> Học hình
	{"lang": "vi", "term": "boss vùng", "word": true, "cs": false, "nf": []},  # glossary #27 -> Kẻ Gác
	{"lang": "vi", "term": "bảo vật boss", "word": true, "cs": false, "nf": []},  # glossary #29 -> Mảnh Gốc
	{"lang": "vi", "term": "Sa Mạc Cát Ấn", "word": true, "cs": false, "nf": []},  # glossary #31 -> Sa Mạc Cát Vùi
	{"lang": "vi", "term": "Phong ấn", "word": true, "cs": false, "nf": []},  # glossary #19 -> Dựng Tường
	{"lang": "vi", "term": "lá đốt", "word": true, "cs": false, "nf": []},  # glossary #21 -> lá Cháy
	{"lang": "en", "term": "Rune Duel", "word": true, "cs": false, "nf": []},  # glossary #1 -> Tessera
	{"lang": "en", "term": "piece", "word": true, "cs": false, "nf": []},  # glossary #2 -> block
	{"lang": "en", "term": "pieces", "word": true, "cs": false, "nf": []},  # glossary #2 -> blocks
	{"lang": "en", "term": "Imprint", "word": true, "cs": false, "nf": []},  # glossary #5 -> Learn shape
	{"lang": "en", "term": "removal token", "word": true, "cs": false, "nf": []},  # glossary #6,30 -> Forget token / Card removal
	{"lang": "en", "term": "removal tokens", "word": true, "cs": false, "nf": []},  # glossary #6,30 -> Forget tokens / Card removals
	{"lang": "en", "term": "Formation", "word": true, "cs": false, "nf": []},  # glossary #12 -> Engraving
	{"lang": "en", "term": "featured shape", "word": false, "cs": false, "nf": []},  # glossary #13 -> Resonant shape
	{"lang": "en", "term": "featured-shape", "word": false, "cs": false, "nf": []},  # glossary #13 -> Resonant-shape
	{"lang": "en", "term": "Signature", "word": true, "cs": false, "nf": []},  # glossary #15 -> Awakening
	{"lang": "en", "term": "Signatures", "word": true, "cs": false, "nf": []},  # glossary #15 -> Awakenings
	{"lang": "en", "term": "Seal", "word": true, "cs": false, "nf": []},  # glossary #19 -> Wall
	{"lang": "en", "term": "Seals", "word": true, "cs": false, "nf": []},  # glossary #19 -> Walls
	{"lang": "en", "term": "Sealed", "word": true, "cs": false, "nf": []},  # glossary #19,31 -> Wall / Buried
	{"lang": "en", "term": "thorn field", "word": false, "cs": false, "nf": []},  # glossary #20 -> Thorns
	{"lang": "en", "term": "Pinned", "word": true, "cs": false, "nf": []},  # glossary #22 -> Frozen
	{"lang": "en", "term": "Pins", "word": true, "cs": false, "nf": []},  # glossary #22 -> Applies Frozen
	{"lang": "en", "term": "Frost", "word": true, "cs": false, "nf": []},  # glossary #23 -> Chill
	{"lang": "en", "term": "Rebirth", "word": true, "cs": false, "nf": []},  # glossary #10 -> Pact
	{"lang": "en", "term": "Altar", "word": true, "cs": false, "nf": []},  # glossary #11 -> The Lattice Heart
	{"lang": "en", "term": "Dais", "word": true, "cs": false, "nf": []},  # glossary #11 -> The Lattice Heart
	{"lang": "en", "term": "Column", "word": true, "cs": false, "nf": []},  # glossary #26 -> Stage
	{"lang": "en", "term": "Columns", "word": true, "cs": false, "nf": []},  # glossary #26 -> Stages
	{"lang": "en", "term": "Miniboss", "word": true, "cs": false, "nf": []},  # glossary #28 -> Elite
	{"lang": "en", "term": "Broken", "word": true, "cs": false, "nf": []},  # glossary #18 -> Interrupt
	{"lang": "en", "term": "windup", "word": true, "cs": false, "nf": []},  # glossary #18 -> channeling
	{"lang": "en", "term": "wind up", "word": true, "cs": false, "nf": []},  # glossary #18 -> channel
	{"lang": "en", "term": "region boss", "word": false, "cs": false, "nf": []},  # glossary #27 -> Warden
	{"lang": "en", "term": "region bosses", "word": false, "cs": false, "nf": []},  # glossary #27 -> Wardens
	{"lang": "en", "term": "regional bosses", "word": false, "cs": false, "nf": []},  # glossary #27 -> Wardens
	{"lang": "en", "term": "boss relic", "word": false, "cs": false, "nf": []},  # glossary #29 -> Primal Shard
	{"lang": "en", "term": "run", "word": true, "cs": false, "nf": []},  # glossary #9 -> climb
	{"lang": "en", "term": "runs", "word": true, "cs": false, "nf": []},  # glossary #9 -> climbs
]

## Allowed remaining old terms: "key|lang|term" -> true, one-line reason each.
const EXCEPTIONS: Dictionary = {
	"boss.frost_sprite.name|en|Frost": true,  # enemy proper name using 'Frost' as an ordinary adjective
	"boss.frost_mage.name|en|Frost": true,  # enemy proper name using 'Frost' as an ordinary adjective
	"boss.mist_lord.name|en|Frost": true,  # Warden proper name "Frost Lord" (design pack canon, ADR-0001 phase 1 task 3)
	"chapter.ch3.end|en|Frost": true,  # names the Warden "the Frost Lord" (same proper name)
	"event.ban_tho_mau.title|en|Altar": true,  # 'altar' = roadside Blood Altar event, unrelated to the old Seal Altar
	"event.ban_tho_mau.body|en|Altar": true,  # 'altar' = roadside Blood Altar event, unrelated to the old Seal Altar
	"event.ban_tho_mau.give.result|en|Altar": true,  # 'altar' = roadside Blood Altar event, unrelated to the old Seal Altar
	"arena.an_dai_dais.name|en|Dais": true,  # 'Lattice Dais' is the NEW arena name (user, 2026-10-29); only 'Seal Dais' was old
}

var _fails: int = 0
var _ph: RegEx = RegEx.create_from_string(PLACEHOLDER_RE)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	# The matcher itself, so a broken matcher cannot pass the scan by finding nothing.
	_check(_hits("ẤN KIẾM", "vi").has("Ấn Kiếm"), "matcher: case-insensitive phrase (ẤN KIẾM)")
	_check(_hits("Bỏ run đang dở?", "vi").has("run"), "matcher: 'run' as a word is caught")
	_check(_hits("running, rerun", "en").is_empty(), "matcher: 'run' inside other words is ignored")
	_check(_hits("Cột đá", "vi").is_empty() and _hits("Cột %d", "vi").has("Cột"), "matcher: 'Cột đá' allowed, 'Cột %d' caught")
	_check(_hits("không phải Mảnh Gốc", "vi").is_empty(), "matcher: new term Mảnh Gốc is not the old 'mảnh'")
	_check(_hits("gieo Giá Lạnh {frost_stacks} tầng", "vi").is_empty() and _hits("{frost_stacks} Chill", "en").is_empty(), "matcher: placeholders are masked")
	_check(_hits("hàn gắn", "vi").is_empty() and _hits("gieo Hàn 2", "vi").has("Hàn"), "matcher: 'Hàn' is case-sensitive")
	# The scan.
	var csv: Dictionary = _parse_csv()
	_check(csv.size() > 800, "CSV parsed: %d keys" % csv.size())
	var used: Dictionary = {}
	for lang: String in ["vi", "en"]:
		var bad: Array[String] = []
		for key: String in csv:
			for term: String in _hits(str(csv[key].get(lang, "")), lang):
				var id: String = "%s|%s|%s" % [key, lang, term]
				if EXCEPTIONS.has(id):
					used[id] = true
				else:
					bad.append("%s: %s" % [key, term])
		_check(bad.is_empty(), "no unlisted old group 1-4 term in %s values (%d found: %s)" % [lang, bad.size(), str(bad)])
	var stale: Array[String] = []
	for id: String in EXCEPTIONS:
		if not used.has(id):
			stale.append(id)
	_check(stale.is_empty(), "every exception still matches (stale: %s)" % str(stale))
	var title: Dictionary = csv.get("title.name", {})
	_check(str(title.get("vi", "")) == "TESSERA" and str(title.get("en", "")) == "TESSERA", "title.name is TESSERA in vi and en")
	print("FAILS=%d" % _fails)
	quit(1 if _fails > 0 else 0)


## Old terms found in [param text] for [param lang] ("vi" / "en"); each term listed once.
func _hits(text: String, lang: String) -> Array[String]:
	var masked: String = _ph.sub(text, "\u0001", true)
	var lower: String = masked.to_lower()
	var out: Array[String] = []
	for t: Dictionary in OLD_TERMS:
		if t["lang"] != lang:
			continue
		var cs: bool = t["cs"]
		var hay: String = masked if cs else lower
		var needle: String = str(t["term"]) if cs else str(t["term"]).to_lower()
		var from: int = 0
		while true:
			var i: int = hay.find(needle, from)
			if i < 0:
				break
			from = i + 1
			var j: int = i + needle.length()
			if t["word"] and ((i > 0 and _is_word(masked[i - 1])) or (j < masked.length() and _is_word(masked[j]))):
				continue
			var after: String = hay.substr(j)
			var allowed: bool = false
			for nf: String in t["nf"]:
				allowed = allowed or after.begins_with(nf if cs else nf.to_lower())
			if allowed:
				continue
			if not out.has(str(t["term"])):
				out.append(str(t["term"]))
			break
	return out


## True for a letter (any script with case), a digit or "_": the characters a "word" match may not touch.
func _is_word(ch: String) -> bool:
	return ch == "_" or ch.to_upper() != ch.to_lower() or (ch >= "0" and ch <= "9")


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

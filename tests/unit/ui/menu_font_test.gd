extends SceneTree
## Main Menu pass (user 2026-11-01): the menu's pixel font is Handjet (OFL), and every Vietnamese character the
## menu and settings screens use exists in it (Pixelify Sans was dropped for lacking them). Also VT323, the other
## candidate kept in assets/fonts. Headless; loads the font files only.
## Run: godot --headless --path . -s res://tests/unit/ui/menu_font_test.gd

const VIETNAMESE: String = "Tiếp tục chuyến leo Chơi Thành tựu Cài đặt Thoát Ngôn ngữ Di chuyển Gợi ý điều khiển Giảm chuyển động Bật Tắt Về Cần gạt Mũi tên Tiếng Việt ĐẤT ĐỊCH ỹỷỵửữựờớợộổỗồốẹẽẻặẳẵằắấầẩẫậếềểễệíìỉĩịóòỏõọúùủũụýỳ"

var fails: int = 0


func ck(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))


func _missing(path: String) -> String:
	var f: FontFile = load(path) as FontFile
	if f == null:
		return "<font not loaded>"
	var out: String = ""
	for ch: String in VIETNAMESE:
		if ch != " " and not f.has_char(ch.unicode_at(0)):
			out += ch
	return out


func _initialize() -> void:
	ck("menu font defaults to Handjet", MenuFont.choice == "handjet")
	ck("Handjet resolves to a weighted variation", MenuFont.font() is FontVariation)
	for id: String in ["handjet", "vt323"]:
		var missing: String = _missing(MenuFont.PATHS[id])
		ck("%s covers every Vietnamese character the menus use" % id, missing.is_empty(), "missing [%s]" % missing)
	ck("sizes scale up for the pixel font", MenuFont.size(32) > 32)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

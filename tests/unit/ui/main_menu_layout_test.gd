extends SceneTree
## Main Menu pass (user 2026-11-01): the title's button column sits on the left with five touch-sized buttons
## (Continue, Play, Achievements, Settings, Quit), clear of the key-art scene on the right; the settings screen's
## rows and "Về" are thumb-sized and on screen; the scene scale is a whole number. Headless, pure (no node).
## Run: godot --headless --path . -s res://tests/unit/ui/main_menu_layout_test.gd

const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1024, 768)]
const MIN_TOUCH_PX: float = 64.0

var fails: int = 0


func ck(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print(("PASS " if cond else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))


func _initialize() -> void:
	for vp: Vector2 in VIEWPORTS:
		var tag: String = "%dx%d" % [int(vp.x), int(vp.y)]
		var rects: Array[Rect2] = ScreenLayout.title_button_rects(vp, ScreenLayout.TITLE_BUTTON_COLUMN_COUNT)
		ck("%s: five title buttons" % tag, rects.size() == 5)
		var tall: bool = true
		var right: bool = true
		for r: Rect2 in rects:
			tall = tall and r.size.y >= MIN_TOUCH_PX * vp.y / 720.0 - 0.5
			right = right and r.position.x >= vp.x * 0.5 and r.end.x < vp.x
		ck("%s: title buttons are touch-sized (>= 64 px at 720p)" % tag, tall, str(rects[0].size))
		ck("%s: key-art menu: title buttons sit in the right half (the art's hero stands bottom-left)" % tag, right)
		ck("%s: the column ends on screen" % tag, rects[-1].end.y <= vp.y)
		ck("%s: the name band is on the left" % tag, ScreenLayout.title_rect(vp).end.x <= vp.x * 0.5)
		ck("%s: language button clear of the column" % tag, not ScreenLayout.title_lang_button_rect(vp).intersects(rects[-1]))
		var rows: Array[Rect2] = SettingsView.row_rects(vp)
		ck("%s: three settings rows, no movement or card time row (removed 2026-11-01 / 2026-11-07)" % tag, rows.size() == SettingsView.ROWS.size() and rows.size() == 3 and not SettingsView.ROWS.has("movement") and not SettingsView.ROWS.has("card_time"))
		var rows_ok: bool = true
		for i: int in rows.size():
			rows_ok = rows_ok and rows[i].size.y >= MIN_TOUCH_PX * vp.y / 720.0 - 0.5 and rows[i].end.y <= vp.y
			if i > 0:
				rows_ok = rows_ok and not rows[i].intersects(rows[i - 1])
			rows_ok = rows_ok and rows[i].encloses(SettingsView.value_rect(rows[i], vp))
		ck("%s: settings rows thumb-sized, apart, on screen, value inside" % tag, rows_ok)
		var back: Rect2 = SettingsView.back_rect(vp)
		ck("%s: settings back in the bottom-left, clear of the rows" % tag, back.position.x < vp.x * 0.25 and back.end.y <= vp.y and not back.intersects(rows[-1]))
	ScreenLayout.title_menu_right = false
	var lefts: Array[Rect2] = ScreenLayout.title_button_rects(Vector2(1280, 720), 5)
	ck("variant a: the column moves to the left half", lefts[0].end.x <= 640.0 and not ScreenLayout.title_lang_button_rect(Vector2(1280, 720)).intersects(lefts[-1]))
	ScreenLayout.title_menu_right = true
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

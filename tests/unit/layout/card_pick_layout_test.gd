extends SceneTree
## Quick spec menu-la-giua-man-hinh-2026-11-01 geometry (ScreenLayout, pure, headless): the 4 menu cards are CardFace
## size, centred on the screen and inside it, with the countdown bar above them; the cooldown column sits at the left
## edge between the relic row and the stick zone; every tap target of the flow is >= 96 px at 720p (scaled).
## Run: godot --headless --path . -s res://tests/unit/layout/card_pick_layout_test.gd

const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]
const MIN_TAP_720: float = 96.0
const EPS: float = 1.01

var fails: int = 0


func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	for vp: Vector2 in VIEWPORTS:
		test_menu_cards_centred_inside_the_screen(vp)
		test_menu_bar_above_the_cards(vp)
		test_cooldown_column_clear_of_relic_row_and_stick(vp)
		test_tap_targets_at_least_96_px_at_720p(vp)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_menu_cards_centred_inside_the_screen(vp: Vector2) -> void:
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, 4)
	var screen := Rect2(Vector2.ZERO, vp)
	var size: Vector2 = ScreenLayout.card_face_size(vp)
	var ok: bool = rects.size() == 4
	for i: int in rects.size():
		ok = ok and screen.encloses(rects[i]) and rects[i].size == size
		if i > 0:
			ok = ok and not rects[i].intersects(rects[i - 1]) and rects[i].position.x > rects[i - 1].end.x
	check("test_menu_four_card_faces_inside_the_screen_at_%s" % vp, ok, str(rects))
	var row: Rect2 = rects[0].merge(rects[-1])
	check("test_menu_row_centred_horizontally_at_%s" % vp, absf(row.get_center().x - vp.x * 0.5) <= EPS, str(row))
	check("test_menu_row_centred_vertically_at_%s" % vp, absf(row.get_center().y - vp.y * 0.5) <= EPS, str(row))
	check("test_card_face_is_176x256_at_720p", size == Vector2(176, 256) * vp.y / 720.0, str(size))


func test_menu_bar_above_the_cards(vp: Vector2) -> void:
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, 4)
	var bar: Rect2 = ScreenLayout.skill_menu_bar_rect(vp, 4)
	check("test_menu_bar_above_the_cards_on_screen_at_%s" % vp, bar.end.y <= rects[0].position.y and bar.position.y >= 0.0 \
		and absf(bar.position.x - rects[0].position.x) <= EPS and absf(bar.end.x - rects[-1].end.x) <= EPS, str(bar))
	check("test_menu_panel_encloses_bar_and_cards_at_%s" % vp, ScreenLayout.skill_menu_panel_rect(vp, 4).encloses(bar.merge(rects[0]).merge(rects[-1])))


func test_cooldown_column_clear_of_relic_row_and_stick(vp: Vector2) -> void:
	var column: Rect2 = ScreenLayout.cooldown_column_rect(vp)
	var relics: Rect2 = ScreenLayout.hud_relic_strip_rect(vp)
	var stick: Rect2 = ScreenLayout.stick_zone_rect(vp)
	check("test_cooldown_column_at_the_left_edge_at_%s" % vp, column.position.x >= 0.0 and column.end.x <= vp.x * 0.1, str(column))
	check("test_cooldown_column_below_the_relic_row_at_%s" % vp, column.position.y >= relics.end.y and not column.intersects(relics), "%s vs %s" % [column, relics])
	check("test_cooldown_column_above_the_stick_zone_at_%s" % vp, column.end.y <= stick.position.y and not column.intersects(stick), "%s vs %s" % [column, stick])
	var icons: Array[Rect2] = ScreenLayout.cooldown_icon_rects(vp, 20)
	var ok: bool = icons.size() >= 5
	for i: int in icons.size():
		ok = ok and column.encloses(icons[i]) and is_equal_approx(icons[i].size.x, icons[i].size.y)
		if i > 0:
			ok = ok and icons[i].position.y > icons[i - 1].end.y
	check("test_cooldown_icons_square_top_down_inside_the_column_at_least_5_at_%s" % vp, ok, "%d icons" % icons.size())
	check("test_cooldown_icons_never_overflow_the_column_at_%s" % vp, icons.size() < 20)
	var cards: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, 4)
	check("test_cooldown_column_clear_of_the_menu_cards_at_%s" % vp, not column.intersects(cards[0]))


func test_tap_targets_at_least_96_px_at_720p(vp: Vector2) -> void:
	var min_side: float = MIN_TAP_720 * vp.y / 720.0 - 0.5
	var targets: Dictionary = {
		"card": ScreenLayout.skill_menu_rects(vp, 4)[0],
		"tung_phep": ScreenLayout.confirm_button_rect(vp),
		"cancel": ScreenLayout.cancel_button_rect(vp),
		"rotate": ScreenLayout.rotate_button_rect(vp),
	}
	for name: String in targets:
		var r: Rect2 = targets[name]
		check("test_%s_tap_target_at_least_96_px_at_%s" % [name, vp], r.size.x >= min_side and r.size.y >= min_side, str(r.size))

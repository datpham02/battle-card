extends SceneTree
## Quick spec menu-la-giua-man-hinh-2026-11-01 geometry (ScreenLayout, pure, headless): the 4 menu cards are CardFace
## size, centred on the screen and inside it. Controls v3 (bo-cuc-dieu-khien-v3-2026-11-02): the pick-time fuse runs
## round an angular frame enclosing the cards (no bar), Hủy sits bottom-left in the place of Tung phép, the cooldown
## column sits at the left edge under the buff / debuff row and above the stick zone; every tap target of the flow is
## at least 96 px tall at 720p (scaled) and at least 64 px wide (the spec's thumb minimum).
## Run: godot --headless --path . -s res://tests/unit/layout/card_pick_layout_test.gd

const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]
const MIN_TAP_720: float = 96.0
const MIN_THUMB_720: float = 64.0
const EPS: float = 1.01

var fails: int = 0


func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	for vp: Vector2 in VIEWPORTS:
		test_menu_cards_centred_inside_the_screen(vp)
		test_menu_fuse_frame_encloses_the_cards(vp)
		test_menu_cancel_bottom_left_in_the_place_of_tung_phep(vp)
		test_cooldown_column_under_the_status_row_above_the_stick(vp)
		test_tap_targets_at_720p(vp)
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


func test_menu_fuse_frame_encloses_the_cards(vp: Vector2) -> void:
	var rects: Array[Rect2] = ScreenLayout.skill_menu_rects(vp, 4)
	var frame: Rect2 = ScreenLayout.skill_menu_frame_rect(vp, 4)
	var row: Rect2 = rects[0].merge(rects[-1])
	check("test_menu_frame_encloses_the_four_cards_with_a_margin_at_%s" % vp, frame.encloses(row) and frame.position.x < row.position.x and frame.end.y > row.end.y, str(frame))
	check("test_menu_frame_inside_the_screen_at_%s" % vp, Rect2(Vector2.ZERO, vp).encloses(frame), str(frame))
	check("test_menu_panel_is_the_fuse_frame_at_%s" % vp, ScreenLayout.skill_menu_panel_rect(vp, 4) == frame)


func test_menu_cancel_bottom_left_in_the_place_of_tung_phep(vp: Vector2) -> void:
	var cancel: Rect2 = ScreenLayout.cancel_button_rect(vp, true)
	var frame: Rect2 = ScreenLayout.skill_menu_frame_rect(vp, 4)
	check("test_menu_cancel_is_the_tung_phep_rect_at_%s" % vp, cancel == ScreenLayout.confirm_button_rect(vp), str(cancel))
	check("test_menu_cancel_bottom_left_at_%s" % vp, cancel.position.x < vp.x * 0.1 and cancel.end.y > vp.y * 0.85, str(cancel))
	check("test_menu_cancel_hit_clear_of_the_card_frame_at_%s" % vp, not ScreenLayout.cancel_hit_rect(vp, true).intersects(frame))


func test_cooldown_column_under_the_status_row_above_the_stick(vp: Vector2) -> void:
	var column: Rect2 = ScreenLayout.cooldown_column_rect(vp)
	var relics: Rect2 = ScreenLayout.hud_relic_strip_rect(vp)
	var statuses: Rect2 = ScreenLayout.hud_status_row_rect(vp)
	var stick: Rect2 = ScreenLayout.stick_zone_rect(vp)
	check("test_cooldown_column_at_the_left_edge_at_%s" % vp, column.position.x >= 0.0 and column.end.x <= vp.x * 0.1, str(column))
	check("test_cooldown_column_below_the_relic_and_status_rows_at_%s" % vp, column.position.y >= statuses.end.y and not column.intersects(statuses)
		and not column.intersects(relics) and statuses.position.y >= relics.end.y, "%s vs %s" % [column, statuses])
	check("test_cooldown_column_aligned_with_the_status_row_at_%s" % vp, absf(column.position.x - statuses.position.x) <= EPS)
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
	check("test_cooldown_column_clear_of_the_menu_frame_at_%s" % vp, not column.intersects(ScreenLayout.skill_menu_frame_rect(vp, 4)) and not column.intersects(cards[0]))


# Controls v3: the cards are full-size tap targets; the bottom-left controls keep their 64 px visuals but tap on hit rects
# at least 96 px tall and at least 64 px wide (Tung phép and the menu's Hủy at least 96 px wide, at the screen edge).
func test_tap_targets_at_720p(vp: Vector2) -> void:
	var s: float = vp.y / 720.0
	var card: Rect2 = ScreenLayout.skill_menu_rects(vp, 4)[0]
	check("test_card_tap_target_at_least_96_px_at_%s" % vp, card.size.x >= MIN_TAP_720 * s - 0.5 and card.size.y >= MIN_TAP_720 * s - 0.5, str(card.size))
	var hits: Dictionary = {
		"tung_phep": ScreenLayout.confirm_hit_rect(vp),
		"menu_cancel": ScreenLayout.cancel_hit_rect(vp, true),
		"cancel": ScreenLayout.cancel_hit_rect(vp),
		"rotate": ScreenLayout.rotate_hit_rect(vp),
	}
	for name: String in hits:
		var r: Rect2 = hits[name]
		check("test_%s_hit_rect_at_least_96_px_tall_at_%s" % [name, vp], r.size.y >= MIN_TAP_720 * s - 0.5, str(r.size))
		check("test_%s_hit_rect_at_least_64_px_wide_at_%s" % [name, vp], r.size.x >= MIN_THUMB_720 * s - 0.5, str(r.size))
	for name: String in ["tung_phep", "menu_cancel"]:
		check("test_%s_hit_rect_at_least_96_px_wide_at_%s" % [name, vp], (hits[name] as Rect2).size.x >= MIN_TAP_720 * s - 0.5, str((hits[name] as Rect2).size))

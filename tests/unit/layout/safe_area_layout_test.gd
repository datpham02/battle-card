extends SceneTree
## 2026-11-03: corner and edge UI keeps out of notches / rounded corners. With a simulated safe area
## (ScreenLayout.safe_rect_override: an 80 px left cutout and a 30 px right one at 1280x720), the battle's pause tile,
## player panel, relic row, gold, bag sockets, cast row, cooldown column and place hint, the map screen's corners and
## the menus' side margin (back button, shop leave) all sit inside the safe area; without an override (desktop) the
## margin is the plain MARGIN_RATIO and nothing moves.
## Run: godot --headless --path . -s res://tests/unit/layout/safe_area_layout_test.gd

const VP: Vector2 = Vector2(1280, 720)
const SAFE: Rect2 = Rect2(80, 0, 1170, 720)

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	test_desktop_margin_unchanged()
	ScreenLayout.safe_rect_override = SAFE
	test_battle_ui_inside_the_safe_area()
	test_map_and_menus_inside_the_safe_area()
	ScreenLayout.safe_rect_override = Rect2()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_desktop_margin_unchanged() -> void:
	ScreenLayout.safe_rect_override = Rect2()
	_check("test_no_safe_area_plain_margin", is_equal_approx(ScreenLayout.side_margin(VP), VP.x * ScreenLayout.MARGIN_RATIO))
	_check("test_no_safe_area_pause_tile_at_the_corner", is_equal_approx(ScreenLayout.pause_tile_rect(VP).end.x, VP.x - roundf(ScreenLayout.HUD_EDGE_INSET_PX)))


func test_battle_ui_inside_the_safe_area() -> void:
	var inside: Dictionary = {
		"pause_tile": ScreenLayout.pause_tile_rect(VP),
		"player_panel": ScreenLayout.hud_player_panel_rect(VP),
		"relic_row": ScreenLayout.hud_relic_strip_rect(VP),
		"gold": ScreenLayout.hud_gold_rect(VP),
		"cast_button": ScreenLayout.confirm_button_rect(VP),
		"cooldown_column": ScreenLayout.cooldown_column_rect(VP),
		"place_hint": ScreenLayout.place_hint_rect(VP),
	}
	for i: int in 3:
		inside["socket_%d" % i] = ScreenLayout.slot_rect(VP, i, 3)
	for name: String in inside:
		var r: Rect2 = inside[name]
		_check("test_battle_%s_inside_the_safe_area" % name, SAFE.encloses(r), str(r))


func test_map_and_menus_inside_the_safe_area() -> void:
	var margin: float = ScreenLayout.side_margin(VP)
	_check("test_side_margin_clears_the_wider_cutout", margin >= 80.0 + ScreenLayout.SAFE_EDGE_PAD_PX, str(margin))
	var rects: Dictionary = {
		"map_pennant": ScreenLayout.map_pennant_rect(VP),
		"map_gear": ScreenLayout.map_pause_button_rect(VP),
		"map_banner": ScreenLayout.map_floor_banner_rect(VP),
		"menu_back": ScreenLayout.back_button_rect(VP),
		"shop_leave": ScreenLayout.shop_leave_rect(VP),
	}
	for name: String in rects:
		var r: Rect2 = rects[name]
		_check("test_%s_inside_the_safe_area" % name, SAFE.encloses(r), str(r))

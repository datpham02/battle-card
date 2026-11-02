extends SceneTree
## 2026-11-02 map layout (ScreenLayout.map_*): at 1280x720 and 2560x1440 the HUD bar runs along the top of the safe
## area (pennant, hero block, two stat groups with the block-set chip, the gear) without overlap, the route nodes stay inside the route
## with tap areas of at least MIN_TOUCH_SIDE that do not overlap inside a column, the Enter button sits right of the
## info band, the floor banner sits right under the bar above the route, the legend runs along the bottom clear of the
## relic strip (map v6), and nothing leaves the screen.
## Run: godot --headless --path . -s res://tests/unit/layout/map_v5_layout_test.gd

const SIZES: Array[Vector2] = [Vector2(1280, 720), Vector2(2560, 1440)]

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	for vp: Vector2 in SIZES:
		test_corners(vp)
		test_route_nodes(vp)
		test_info_enter_and_floor_strip(vp)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_corners(vp: Vector2) -> void:
	var screen := Rect2(Vector2.ZERO, vp)
	var safe: Rect2 = ScreenLayout.safe_rect(vp)
	_check("test_safe_rect_inside_the_screen_%dx%d" % [vp.x, vp.y], screen.encloses(safe) and safe.has_area())
	var pennant: Rect2 = ScreenLayout.map_pennant_rect(vp)
	_check("test_pennant_in_the_top_left_of_the_safe_area_%d" % vp.x, safe.encloses(pennant) and pennant.position.x - safe.position.x < 0.05 * vp.x)
	var panel: Rect2 = ScreenLayout.map_hp_panel_rect(vp)
	_check("test_hero_block_right_of_the_pennant_%d" % vp.x, panel.position.x > pennant.end.x and screen.encloses(panel))
	var g0: Rect2 = ScreenLayout.map_stat_group_rect(vp, 0)
	var g1: Rect2 = ScreenLayout.map_stat_group_rect(vp, 1)
	_check("test_stat_groups_between_the_hero_and_the_gear_%d" % vp.x, g0.position.x > panel.end.x and g1.position.x > g0.end.x
		and g1.end.x < ScreenLayout.map_pause_button_rect(vp).position.x)
	_check("test_block_set_chip_inside_stat_group_0_%d" % vp.x, g0.encloses(ScreenLayout.map_block_set_button_rect(vp)))
	var pause: Rect2 = ScreenLayout.map_pause_button_rect(vp)
	var block: Rect2 = ScreenLayout.map_block_set_button_rect(vp)
	_check("test_icons_on_screen_and_apart_%d" % vp.x, screen.encloses(pause) and screen.encloses(block) and not pause.intersects(block) and block.end.x < pause.position.x)
	_check("test_icons_clear_of_the_hp_panel_%d" % vp.x, not block.intersects(panel))


func test_route_nodes(vp: Vector2) -> void:
	var route: Rect2 = ScreenLayout.map_route_rect(vp)
	var ok_inside: bool = true
	var ok_touch: bool = true
	var ok_apart: bool = true
	for count: int in [1, 2, 3]:
		var hits: Array[Rect2] = []
		for i: int in count:
			var c: Vector2 = ScreenLayout.map_route_node_center(vp, 1, 3, i, count)
			ok_inside = ok_inside and route.grow(1.0).has_point(c)
			var hit: Rect2 = ScreenLayout.map_route_node_hit_rect(vp, c)
			ok_touch = ok_touch and hit.size.x >= ScreenLayout.MIN_TOUCH_SIDE - 0.5 and hit.size.y >= ScreenLayout.MIN_TOUCH_SIDE - 0.5
			for other: Rect2 in hits:
				ok_apart = ok_apart and not other.intersects(hit)
			hits.append(hit)
	_check("test_nodes_inside_the_route_%d" % vp.x, ok_inside)
	_check("test_node_tap_areas_at_least_min_touch_%d" % vp.x, ok_touch)
	_check("test_node_tap_areas_of_a_column_do_not_overlap_%d" % vp.x, ok_apart)
	var last: Vector2 = ScreenLayout.map_route_node_center(vp, 2, 3, 0, 1)
	_check("test_last_column_on_the_right_edge_of_the_route_%d" % vp.x, is_equal_approx(last.x, roundf(route.end.x)))
	_check("test_start_point_on_the_left_edge_%d" % vp.x, is_equal_approx(ScreenLayout.map_route_start(vp).x, roundf(route.position.x)))


func test_info_enter_and_floor_strip(vp: Vector2) -> void:
	var screen := Rect2(Vector2.ZERO, vp)
	var info: Rect2 = ScreenLayout.map_info_rect(vp)
	var enter: Rect2 = ScreenLayout.map_enter_button_rect(vp)
	_check("test_enter_right_of_the_info_band_%d" % vp.x, enter.position.x > info.end.x and screen.encloses(enter))
	_check("test_info_band_under_the_route_%d" % vp.x, info.position.y >= ScreenLayout.map_route_rect(vp).end.y)
	var banner: Rect2 = ScreenLayout.map_floor_banner_rect(vp)
	_check("test_floor_banner_right_under_the_bar_above_the_route_%d" % vp.x, screen.encloses(banner) and banner.end.x > vp.x * 0.9
		and banner.position.y > ScreenLayout.map_pause_button_rect(vp).end.y and banner.end.y < ScreenLayout.map_route_rect(vp).position.y)
	_check("test_floor_banner_clear_of_the_corners_%d" % vp.x, not banner.intersects(ScreenLayout.map_hp_panel_rect(vp)) and not banner.intersects(ScreenLayout.map_block_set_button_rect(vp)))
	var legend: Rect2 = ScreenLayout.map_legend_rect(vp)
	_check("test_legend_under_the_info_band_%d" % vp.x, legend.position.y > info.end.y and screen.encloses(legend))
	_check("test_legend_clear_of_the_relic_strip_%d" % vp.x, legend.end.x <= ScreenLayout.map_relic_strip_rect(vp).position.x + 0.5)
	_check("test_enter_above_the_legend_%d" % vp.x, enter.end.y < legend.position.y)

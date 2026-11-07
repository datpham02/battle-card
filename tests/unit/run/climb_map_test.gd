extends SceneTree
## 2026-11-07 climb map: the fixed region order of the world (chapters.json world.region_order, one region offered
## per floor), the 7-floor scaling, and ClimbMap's pure layout (islands climb, zig-zag, stay on the map, the scroll
## shows the current floor, the island shape is a closed angular outline).
## Run: godot --headless --path . -s res://tests/unit/run/climb_map_test.gd

const VP: Vector2 = Vector2(1280, 720)
const ORDER: Array[String] = ["ch1", "hellfire", "desert", "swamp", "ch2", "ch3", "sky_isles"]

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	test_region_order_config()
	test_offer_follows_order()
	test_scaling_rows()
	test_islands_climb_and_zigzag()
	test_scroll_shows_current_floor()
	test_island_shape()
	test_island_anchors()
	test_stair_25d()
	test_island_animation()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func test_region_order_config() -> void:
	var c: ChaptersConfig = ChaptersConfig.load_from_file()
	check("world has 7 floors", c.world_floors() == 7)
	check("region_order is the climb order: %s" % [c.region_order()], c.region_order() == ORDER)


func test_offer_follows_order() -> void:
	var c: ChaptersConfig = ChaptersConfig.load_from_file()
	var hero: Dictionary = {"id": "kiem_si", "max_hp": 200.0}
	var got: Array[String] = []
	for f: int in 7:
		var s: RunSession = RunSession.begin(c, hero, 0, 5, [], 1)
		s.floor = f
		var offer: Array[String] = s.roll_offer()
		got.append(offer[0] if offer.size() == 1 else "<%d>" % offer.size())
	check("each floor offers exactly its region: %s" % [got], got == ORDER)


func test_scaling_rows() -> void:
	var c: ChaptersConfig = ChaptersConfig.load_from_file()
	var last: float = 0.0
	var rising: bool = true
	for f: int in 7:
		var hp: float = float(c.floor_scaling(f).get("hp_mult", 0.0))
		rising = rising and hp > last
		last = hp
	check("enemy HP rises every floor 1..7", rising)
	check("floor 1 keeps 0.7 HP", is_equal_approx(float(c.floor_scaling(0).get("hp_mult", 0.0)), 0.7))


func test_islands_climb_and_zigzag() -> void:
	var ok_climb: bool = true
	var ok_zig: bool = true
	var ok_inside: bool = true
	var h: float = ClimbMap.map_height(VP, 7)
	for i: int in 7:
		var c: Vector2 = ClimbMap.island_center(VP, i, 7)
		var r: Rect2 = ClimbMap.island_rect(VP, i, 7)
		ok_inside = ok_inside and r.position.x >= 0.0 and r.end.x <= VP.x and r.position.y >= 0.0 and r.end.y <= h
		if i > 0:
			var prev: Vector2 = ClimbMap.island_center(VP, i - 1, 7)
			ok_climb = ok_climb and c.y < prev.y
			ok_zig = ok_zig and signf(c.x - VP.x * 0.5) != signf(prev.x - VP.x * 0.5)
	check("each floor's island is higher than the one before", ok_climb)
	check("islands alternate sides", ok_zig)
	check("islands stay on the map", ok_inside)
	check("the cube is above the last island", ClimbMap.cube_center(VP).y < ClimbMap.island_rect(VP, 6, 7).position.y)


func test_scroll_shows_current_floor() -> void:
	var ok: bool = true
	for f: int in 7:
		var r: Rect2 = ClimbMap.island_rect(VP, f, 7)
		var scroll: float = ClimbMap.scroll_for(VP, f, 7)
		var y: float = r.get_center().y - scroll
		ok = ok and y > VP.y * 0.17 and y < VP.y and scroll >= 0.0 and scroll <= ClimbMap.map_height(VP, 7) - VP.y
	check("the current floor's island is on screen below the header at every floor", ok)
	check("after the last floor the map shows its top (cube)", ClimbMap.scroll_for(VP, 7, 7) == 0.0)


func test_island_shape() -> void:
	var r := Rect2(100, 100, 200, 110)
	var shape: PackedVector2Array = ClimbMap.island_shape(r)
	var inside: bool = true
	for p: Vector2 in shape:
		inside = inside and r.grow(0.01).has_point(p)
	check("island outline has 11 corners inside its rect", shape.size() == 11 and inside)
	var r0: Rect2 = ClimbMap.island_rect(VP, 0, 7)
	var r1: Rect2 = ClimbMap.island_rect(VP, 1, 7)
	var stairs: PackedVector2Array = ClimbMap.stair_points(ClimbMap.anchor_point(r0, ClimbMap.island_info("ch1")["stair_out"]), ClimbMap.anchor_point(r1, ClimbMap.island_info("hellfire")["stair_in"]))
	var axis: bool = true
	for k: int in range(1, stairs.size()):
		var d: Vector2 = stairs[k] - stairs[k - 1]
		axis = axis and (is_zero_approx(d.x) or is_zero_approx(d.y))
	check("stairs are only flat runs and vertical rises", axis and stairs.size() == 17 and stairs[stairs.size() - 1].y < stairs[0].y)


func test_island_anchors() -> void:
	var info: Dictionary = ClimbMap.island_info("ch1")
	check("ch1 has its generated sprite", str(info["sprite"]).ends_with("island_ch1.png") and ClimbMap.island_texture("ch1") != null)
	var feet: Vector2 = info["feet"]
	check("ch1 feet anchor inside the sprite", Rect2(Vector2.ZERO, ClimbMap.ISLAND_ART).has_point(feet))
	var none: Dictionary = ClimbMap.island_info("no_such_region")
	check("a region without a sprite gets the default anchors and no sprite", str(none["sprite"]).is_empty() and none["feet"] is Vector2)
	var r: Rect2 = ClimbMap.island_rect(VP, 0, 7)
	check("anchors scale with the island (the map scale, 1x at 720p)", ClimbMap.anchor_point(r, feet) == r.position + feet * ClimbMap.map_scale(VP) and ClimbMap.map_scale(VP) == 1.0)


func test_stair_25d() -> void:
	var from := Vector2(500, 500)
	var to := Vector2(700, 340)
	var steps: Array[Dictionary] = ClimbMap.stair_steps(from, to, 1.0, 10)
	check("one tread and riser per step", steps.size() == 10 and (steps[0]["tread"] as PackedVector2Array).size() == 4 and (steps[0]["riser"] as PackedVector2Array).size() == 4)
	# Drawn far first: the first entry is the top step, the last the bottom one; every step is lower on screen than the one before.
	var ok: bool = true
	for i: int in range(1, steps.size()):
		ok = ok and (steps[i]["foot"] as Vector2).y > (steps[i - 1]["foot"] as Vector2).y
	check("steps descend toward the viewer in draw order", ok)
	var risers_down: bool = true
	for st: Dictionary in steps:
		var rz: PackedVector2Array = st["riser"]
		risers_down = risers_down and rz[3].y > rz[0].y and is_equal_approx(rz[3].x, rz[0].x)
	check("each riser is a vertical front face under its tread", risers_down)
	check("the bottom step starts at the lower landing", (steps[steps.size() - 1]["foot"] as Vector2).distance_to(from) < 1.0)


# 2026-11-07 (user: animate the islands; ice wind, forest waterfall): the drift stays within ISLAND_BOB and is
# phase-shifted per island, the pulses stay in range, and the regions named carry their effect from islands.json.
func test_island_animation() -> void:
	var in_range: bool = true
	var shifted: bool = false
	for step: int in 40:
		var t: float = float(step) * 0.1
		in_range = in_range and absf(ClimbMap.island_bob(0, t)) <= ClimbMap.ISLAND_BOB
		shifted = shifted or ClimbMap.island_bob(0, t) != ClimbMap.island_bob(1, t)
		in_range = in_range and ClimbMap.accent_alpha(t, 0.0) >= 0.0 and ClimbMap.accent_alpha(t, 0.0) <= 0.4
		in_range = in_range and absf(ClimbMap.summit_bob(t)) <= ClimbMap.SUMMIT_BOB
	check("island drift and pulses stay in range", in_range)
	check("neighbouring islands drift out of step", shifted)
	check("forest has a waterfall", str(ClimbMap.island_info("ch1").get("fx", {}).get("kind", "")) == "waterfall")
	check("ice isle has wind", str(ClimbMap.island_info("ch3").get("fx", {}).get("kind", "")) == "wind")
	check("hellfire has embers", str(ClimbMap.island_info("hellfire").get("fx", {}).get("kind", "")) == "embers")
	check("desert has sand wind", str(ClimbMap.island_info("desert").get("fx", {}).get("kind", "")) == "wind")
	check("swamp has spores", str(ClimbMap.island_info("swamp").get("fx", {}).get("source", "")) == "spore")
	check("sky isles have clouds", str(ClimbMap.island_info("sky_isles").get("fx", {}).get("kind", "")) == "clouds")
	check("a region without an effect has none", not ClimbMap.island_info("no_such_region").has("fx"))
	var h: float = ClimbMap.fx_hash(7)
	check("fx hash is stable and in 0..1", h == ClimbMap.fx_hash(7) and h >= 0.0 and h < 1.0)

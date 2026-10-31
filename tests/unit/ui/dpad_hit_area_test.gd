extends SceneTree
## Story 044 Part B: pad mode keeps the drawn button size (ScreenLayout.dpad_rects) but every
## button's HIT area is at least 88x88 and grows outward only (art bible 7.4: touch area >= visible).

var fails: int = 0

const VP: Vector2 = Vector2(1280, 720)


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	test_press_one_pixel_above_drawn_up_rect_hits_up()
	test_every_hit_area_is_at_least_88_square()
	test_hit_area_contains_the_drawn_button_and_grows_outward_only()
	test_hit_areas_do_not_cover_a_neighbours_drawn_button()
	test_button_already_88_is_unchanged()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_press_one_pixel_above_drawn_up_rect_hits_up() -> void:
	var rects: Dictionary = ScreenLayout.dpad_rects(VP)
	var up: Rect2 = rects[Vector2i.UP]
	var point := Vector2(up.get_center().x, up.position.y - 1.0)
	_check("drawn UP is smaller than 88 at 1280x720", up.size.y < DPadView.PAD_HIT_MIN_PX, str(up.size))
	_check("the point is outside the drawn UP rect", not up.has_point(point))
	_check("but inside the UP hit area", DPadView.hit_rect(up, Vector2i.UP).has_point(point))
	var hits: Array[Vector2i] = []
	for direction: Vector2i in rects:
		if DPadView.hit_rect(rects[direction], direction).has_point(point):
			hits.append(direction)
	_check("only UP claims it", hits == [Vector2i.UP], str(hits))


func test_every_hit_area_is_at_least_88_square() -> void:
	var rects: Dictionary = ScreenLayout.dpad_rects(VP)
	for direction: Vector2i in rects:
		var hit: Rect2 = DPadView.hit_rect(rects[direction], direction)
		_check("hit area %s >= 88x88" % direction, hit.size.x >= DPadView.PAD_HIT_MIN_PX - 0.001 and hit.size.y >= DPadView.PAD_HIT_MIN_PX - 0.001, str(hit.size))


func test_hit_area_contains_the_drawn_button_and_grows_outward_only() -> void:
	var rects: Dictionary = ScreenLayout.dpad_rects(VP)
	var up: Rect2 = rects[Vector2i.UP]
	var down: Rect2 = rects[Vector2i.DOWN]
	var left: Rect2 = rects[Vector2i.LEFT]
	var right: Rect2 = rects[Vector2i.RIGHT]
	var hit_up: Rect2 = DPadView.hit_rect(up, Vector2i.UP)
	var hit_down: Rect2 = DPadView.hit_rect(down, Vector2i.DOWN)
	var hit_left: Rect2 = DPadView.hit_rect(left, Vector2i.LEFT)
	var hit_right: Rect2 = DPadView.hit_rect(right, Vector2i.RIGHT)
	_check("UP keeps its bottom edge and grows up", is_equal_approx(hit_up.end.y, up.end.y) and hit_up.position.y < up.position.y)
	_check("DOWN keeps its top edge and grows down", is_equal_approx(hit_down.position.y, down.position.y) and hit_down.end.y > down.end.y)
	_check("LEFT keeps its right edge and grows left", is_equal_approx(hit_left.end.x, left.end.x) and hit_left.position.x < left.position.x)
	_check("RIGHT keeps its left edge and grows right", is_equal_approx(hit_right.position.x, right.position.x) and hit_right.end.x > right.end.x)
	_check("each hit area contains its drawn button", hit_up.grow(0.001).encloses(up) and hit_down.grow(0.001).encloses(down) and hit_left.grow(0.001).encloses(left) and hit_right.grow(0.001).encloses(right))


func test_hit_areas_do_not_cover_a_neighbours_drawn_button() -> void:
	var rects: Dictionary = ScreenLayout.dpad_rects(VP)
	var clean: bool = true
	for a: Vector2i in rects:
		var hit: Rect2 = DPadView.hit_rect(rects[a], a)
		for b: Vector2i in rects:
			if a != b:
				var overlap: Rect2 = hit.intersection(rects[b])
				if overlap.size.x > 0.001 and overlap.size.y > 0.001:
					clean = false
	_check("no hit area overlaps another button's drawn rect", clean)


func test_button_already_88_is_unchanged() -> void:
	var drawn := Rect2(10, 10, 88, 88)
	_check("88 px button is returned as is", DPadView.hit_rect(drawn, Vector2i.UP) == drawn and DPadView.hit_rect(drawn, Vector2i.LEFT) == drawn)

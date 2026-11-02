extends SceneTree
## Story 046 Part B: HudSkin pure helpers and resources: chamfer vertex counts, segment rects, the two
## Noto Sans fonts (real FontFile, every Vietnamese test character covered), the icon sheet lookup and
## the missing-icon path, and the damage-trail interpolation.

var fails: int = 0

const VIETNAMESE: String = "Tiếng Việt ẳ ẵ ặ ế ộ ử ữ ự Đ đ Ơ ơ Ư ư"
const PANEL: Rect2 = Rect2(10, 20, 430, 60)


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + " " + extra)
	if not ok:
		fails += 1


func _initialize() -> void:
	test_chamfer_vertex_count_is_four_plus_one_per_cut()
	test_chamfer_points_stay_inside_the_rect()
	test_segment_rects_count_widths_and_gaps()
	test_segment_rects_uneven_width_spans_the_rect()
	test_fonts_are_real_font_files_covering_vietnamese()
	test_text_width_of_vietnamese_is_positive()
	test_pause_icon_frame_is_in_the_json()
	test_missing_icon_returns_false()
	test_missing_sheet_returns_false()
	test_trail_ratio_interpolates_then_lands()
	test_regular_points_sit_on_the_circumradius()
	test_perimeter_trace_follows_the_outline()
	test_flame_and_shackle_are_straight_segments()
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_chamfer_vertex_count_is_four_plus_one_per_cut() -> void:
	_check("square corners: 4 vertices", HudSkin.chamfer_points(PANEL, [0, 0, 0, 0]).size() == 4)
	_check("one cut: 5 vertices", HudSkin.chamfer_points(PANEL, [0, 0, 18, 0]).size() == 5)
	_check("two cuts: 6 vertices", HudSkin.chamfer_points(PANEL, [0, 12, 0, 12]).size() == 6)
	_check("four cuts: 8 vertices", HudSkin.chamfer_points(PANEL, [6, 6, 6, 6]).size() == 8)
	_check("missing entries count as square", HudSkin.chamfer_points(PANEL, [6]).size() == 5)


func test_chamfer_points_stay_inside_the_rect() -> void:
	var pts: PackedVector2Array = HudSkin.chamfer_points(PANEL, [0, 0, 18, 0])
	var inside: bool = true
	for p: Vector2 in pts:
		inside = inside and p.x >= PANEL.position.x and p.x <= PANEL.end.x and p.y >= PANEL.position.y and p.y <= PANEL.end.y
	_check("every vertex lies on the rect", inside, str(pts))
	_check("bottom-right cut is 45 degrees", pts.has(Vector2(PANEL.end.x, PANEL.end.y - 18)) and pts.has(Vector2(PANEL.end.x - 18, PANEL.end.y)), str(pts))


func test_segment_rects_count_widths_and_gaps() -> void:
	# 82 px = 7 * 10 + 6 * 2: every segment 10 px, every gap 2 px
	var rects: Array[Rect2] = HudSkin.segment_rects(Rect2(100, 50, 82, 6), 7, 2.0)
	_check("7 segments", rects.size() == 7, str(rects.size()))
	var widths_ok: bool = true
	var gaps_ok: bool = true
	for i: int in rects.size():
		widths_ok = widths_ok and is_equal_approx(rects[i].size.x, 10.0) and is_equal_approx(rects[i].size.y, 6.0)
		if i > 0:
			gaps_ok = gaps_ok and is_equal_approx(rects[i].position.x - rects[i - 1].end.x, 2.0)
	_check("each segment 10x6", widths_ok)
	_check("each gap 2 px", gaps_ok)
	_check("first starts at the rect", rects[0].position == Vector2(100, 50))
	_check("zero total: empty", HudSkin.segment_rects(Rect2(0, 0, 82, 6), 0).is_empty())


func test_segment_rects_uneven_width_spans_the_rect() -> void:
	var bar := Rect2(12, 60, 300, 6)
	var rects: Array[Rect2] = HudSkin.segment_rects(bar, 7)
	var ideal: float = (300.0 - 12.0) / 7.0
	var ok: bool = rects.size() == 7
	for r: Rect2 in rects:
		ok = ok and absf(r.size.x - ideal) <= 1.0
	_check("300 px bar: 7 segments within 1 px of the ideal width", ok)
	_check("last segment ends on the right edge", is_equal_approx(rects[6].end.x, bar.end.x), str(rects[6]))


func test_fonts_are_real_font_files_covering_vietnamese() -> void:
	var semi: Font = HudSkin.font_semibold()
	var bold: Font = HudSkin.font_bold()
	_check("semibold is a FontFile", semi is FontFile)
	_check("bold is a FontFile", bold is FontFile)
	_check("semibold is not the fallback", semi != ThemeDB.fallback_font)
	_check("bold is not the fallback", bold != ThemeDB.fallback_font)
	_check("cached: same instance twice", HudSkin.font_semibold() == semi and HudSkin.font_bold() == bold)
	if semi is FontFile:
		var ff: FontFile = semi as FontFile
		_check("grey antialiasing, no MSDF", ff.antialiasing == TextServer.FONT_ANTIALIASING_GRAY and not ff.multichannel_signed_distance_field)
	var missing: Array[String] = []
	for i: int in VIETNAMESE.length():
		var code: int = VIETNAMESE.unicode_at(i)
		if code == 32:
			continue
		if not semi.has_char(code) or not bold.has_char(code):
			missing.append(VIETNAMESE[i])
	_check("both fonts have every character of the test string", missing.is_empty(), str(missing))


func test_text_width_of_vietnamese_is_positive() -> void:
	_check("SemiBold 24 width > 0", HudSkin.text_width(VIETNAMESE, 24) > 0.0, str(HudSkin.text_width(VIETNAMESE, 24)))
	_check("Bold 24 width > 0", HudSkin.text_width(VIETNAMESE, 24, true) > 0.0)


func test_pause_icon_frame_is_in_the_json() -> void:
	HudSkin.reset_icons()
	var frame: Rect2 = HudSkin.icon_frame("pause")
	_check("pause frame found, 55x55", frame.size == Vector2(55, 55), str(frame))
	_check("info frame found", HudSkin.icon_frame("info").size == Vector2(55, 55))


func test_missing_icon_returns_false() -> void:
	HudSkin.reset_icons()
	var canvas := Node2D.new()
	_check("unknown name: frame empty", HudSkin.icon_frame("no_such_icon") == Rect2())
	_check("unknown name: icon() false", not HudSkin.icon(canvas, "no_such_icon", Vector2(100, 100)))
	canvas.free()


func test_missing_sheet_returns_false() -> void:
	HudSkin.reset_icons("res://assets/art/ui/missing_sheet.png", "res://assets/art/ui/missing_sheet.json")
	var canvas := Node2D.new()
	_check("missing sheet: pause frame empty", HudSkin.icon_frame("pause") == Rect2())
	_check("missing sheet: icon() false, no crash", not HudSkin.icon(canvas, "pause", Vector2(100, 100)))
	canvas.free()
	HudSkin.reset_icons()


func test_trail_ratio_interpolates_then_lands() -> void:
	_check("start: from", is_equal_approx(HudSkin.trail_ratio(1.0, 0.5, 0.0, 0.4), 1.0))
	_check("half way", is_equal_approx(HudSkin.trail_ratio(1.0, 0.5, 0.2, 0.4), 0.75))
	_check("over: to", is_equal_approx(HudSkin.trail_ratio(1.0, 0.5, 0.5, 0.4), 0.5))
	_check("zero duration: to", is_equal_approx(HudSkin.trail_ratio(1.0, 0.5, 0.0, 0.0), 0.5))


# 2026-11-02 (no circles in the UI but the joystick): the angular stand-ins.
func test_regular_points_sit_on_the_circumradius() -> void:
	var c := Vector2(10.0, 20.0)
	var oct: PackedVector2Array = HudSkin.regular_points(c, 8.0, 8)
	var on_radius: bool = oct.size() == 8
	for p: Vector2 in oct:
		on_radius = on_radius and is_equal_approx(p.distance_to(c), 8.0)
	_check("test_regular_points_octagon_has_8_corners_on_the_radius", on_radius)
	_check("test_regular_points_first_corner_straight_up", oct.size() > 0 and oct[0].is_equal_approx(c + Vector2(0.0, -8.0)))
	_check("test_regular_points_under_3_sides_is_empty", HudSkin.regular_points(c, 8.0, 2).is_empty())
	_check("test_regular_points_zero_radius_is_empty", HudSkin.regular_points(c, 0.0, 6).is_empty())


func test_perimeter_trace_follows_the_outline() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	var full: PackedVector2Array = HudSkin.perimeter_trace(square, 1.0)
	_check("test_trace_full_closes_back_on_the_first_corner", full.size() == 5 and full[4] == square[0])
	var half: PackedVector2Array = HudSkin.perimeter_trace(square, 0.5)
	_check("test_trace_half_ends_on_the_opposite_corner", half.size() == 3 and half[2] == Vector2(4, 4))
	var eighth: PackedVector2Array = HudSkin.perimeter_trace(square, 0.125)
	_check("test_trace_eighth_stops_mid_edge", eighth.size() == 2 and eighth[1].is_equal_approx(Vector2(2, 0)))
	_check("test_trace_zero_is_empty", HudSkin.perimeter_trace(square, 0.0).is_empty())


func test_flame_and_shackle_are_straight_segments() -> void:
	var flame: PackedVector2Array = HudSkin.flame_points(Vector2.ZERO, 10.0)
	_check("test_flame_is_five_corners_closed", flame.size() == 6 and flame[0] == flame[5])
	_check("test_flame_tip_up_base_at_h", flame[0] == Vector2(0.0, -10.0) and is_equal_approx(flame[2].y, 10.0))
	var shackle: PackedVector2Array = HudSkin.shackle_points(0.0, 0.0, 5.0)
	_check("test_shackle_is_six_points_from_body_to_body", shackle.size() == 6 and shackle[0].y == 0.0 and shackle[5].y == 0.0)

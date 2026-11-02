extends SceneTree
## Card layout v2 (user 2026-11-02: "đang trống quá nhiều làm card hơi xấu … không bị trống những diện tích không cần
## thiết"; layout from design/references/osfe-card-layout.md): pure geometry of the ancient card face (CardFace.
## ancient_layout / text_layout / foot_layout), headless. The picture window is at least half the card wide and
## integer-scaled; every part sits inside the frame's visible border; the rule text never overlaps the gems, the picture
## or the foot line; a typical one- or two-line card leaves no band over ~12 % of the card height between its text and
## the damage gem; a short face leaves its text to the detail panel; a long text is cut with "…" and reported
## incomplete, so the screen opens the detail panel.
## Run: godot --headless --path . -s res://tests/unit/ui/card_face_layout_test.gd

const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]
const LOCALES: Array[String] = ["vi", "en"]
const MAX_GAP_SHARE: float = 0.12
const EPS: float = 0.51
## Typical one- and two-line cards (cards.json ids).
const TYPICAL: Array[String] = ["kiem_khi", "kiem_vu", "thiet_kiem", "chan_phong", "han_kiem"]

var fails: int = 0


func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	CardFace.style = "ancient"
	var previous: String = TranslationServer.get_locale()
	var skills: SkillConfig = SkillConfig.load_from_file()
	for vp: Vector2 in VIEWPORTS:
		var rect := Rect2(Vector2(200, 100), ScreenLayout.card_face_size(vp))
		test_parts_inside_the_border(rect, vp)
		test_picture_is_half_the_card_and_integer_scaled(rect, vp)
		test_picture_clear_of_the_gems_and_the_name(rect, vp)
		test_short_face_leaves_text_to_the_panel(rect, vp, skills)
		for locale: String in LOCALES:
			TranslationServer.set_locale(locale)
			test_every_card_text_inside_its_band(rect, vp, skills, locale)
			test_typical_card_has_no_empty_band(rect, vp, skills, locale)
			test_foot_line_fits_before_the_damage_gem(rect, vp, skills, locale)
	TranslationServer.set_locale("vi")
	test_keywords_are_coloured()
	test_cut_text_is_reported_incomplete(skills)
	TranslationServer.set_locale(previous)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func test_parts_inside_the_border(rect: Rect2, vp: Vector2) -> void:
	var lay: Dictionary = CardFace.ancient_layout(rect, vp.y)
	var border: Rect2 = lay["border"]
	check("test_border_inside_the_card_rect_at_%s" % vp, rect.encloses(border), str(border))
	var ok: bool = true
	for key: String in ["cost", "damage", "name", "picture_frame", "text"]:
		ok = ok and border.encloses(lay[key])
	check("test_gems_name_picture_text_inside_the_border_at_%s" % vp, ok)
	var foot: Rect2 = lay["foot"]
	check("test_foot_baseline_inside_the_border_at_%s" % vp, foot.position.y < border.end.y and foot.position.x >= border.position.x)
	check("test_cost_gem_top_left_damage_gem_bottom_right_at_%s" % vp, (lay["cost"] as Rect2).position == border.position
		and (lay["damage"] as Rect2).end == border.end)
	check("test_gems_a_quarter_of_the_card_wide_at_%s" % vp, (lay["cost"] as Rect2).size.x >= rect.size.x * 0.22, str((lay["cost"] as Rect2).size))


func test_picture_is_half_the_card_and_integer_scaled(rect: Rect2, vp: Vector2) -> void:
	var lay: Dictionary = CardFace.ancient_layout(rect, vp.y)
	var pic: Rect2 = lay["picture"]
	var src: int = int(lay["picture_src"])
	check("test_picture_at_least_half_the_card_wide_at_%s" % vp, pic.size.x >= rect.size.x * 0.5 - EPS, "%s of %s" % [pic.size.x, rect.size.x])
	check("test_picture_square_at_%s" % vp, is_equal_approx(pic.size.x, pic.size.y))
	check("test_picture_whole_art_px_scale_at_%s" % vp, src > 0 and src <= 32 and is_equal_approx(fmod(pic.size.x, float(src)), 0.0), "%d art px -> %s" % [src, pic.size.x])
	check("test_picture_centred_at_%s" % vp, absf(pic.get_center().x - (lay["border"] as Rect2).get_center().x) <= 1.0)
	check("test_picture_in_the_upper_half_at_%s" % vp, pic.position.y < rect.position.y + rect.size.y * 0.25 and pic.end.y <= rect.get_center().y + rect.size.y * 0.08)


func test_picture_clear_of_the_gems_and_the_name(rect: Rect2, vp: Vector2) -> void:
	var lay: Dictionary = CardFace.ancient_layout(rect, vp.y)
	var frame: Rect2 = lay["picture_frame"]
	check("test_picture_frame_clear_of_the_cost_gem_diamond_at_%s" % vp, not _rect_hits_diamond(frame, lay["cost"]), str(frame))
	check("test_picture_frame_above_the_damage_gem_at_%s" % vp, frame.end.y <= (lay["damage"] as Rect2).position.y)
	check("test_name_line_above_the_picture_at_%s" % vp, (lay["name"] as Rect2).end.y <= frame.position.y and (lay["name"] as Rect2).position.x >= (lay["cost"] as Rect2).end.x)


func test_every_card_text_inside_its_band(rect: Rect2, vp: Vector2, skills: SkillConfig, locale: String) -> void:
	var lay: Dictionary = CardFace.ancient_layout(rect, vp.y)
	var band: Rect2 = lay["text"]
	var bad: Array[String] = []
	for id: Variant in skills.cards.keys():
		var skill: Dictionary = skills.resolved(str(id), 1)
		for show_cd: bool in [true, false]:
			var s: Dictionary = skill.duplicate()
			if not show_cd:
				s["cooldown_sec"] = 0.0
			for foot: Array in [[], ["%d gold" % 132, Color.GOLD, 22]]:
				var foot_line: Dictionary = CardFace.foot_layout(s, foot, rect, vp.y)
				var desc: String = CardText.describe_resolved(s)
				var body: String = CardFace.describe_with_cooldown(desc, s) if bool(foot_line["cooldown_in_text"]) else desc
				var lines: Array = CardFace.text_layout(body, rect, vp.y)
				var prev_end: float = -INF
				for line: Dictionary in lines:
					var r: Rect2 = line["rect"]
					var ok: bool = band.grow(EPS).encloses(r) and r.position.y >= prev_end - EPS
					ok = ok and not _rect_hits_diamond(r, lay["damage"]) and not _rect_hits_diamond(r, lay["cost"])
					ok = ok and not r.intersects(lay["picture_frame"])
					ok = ok and (r.end.y <= float(lay["text_full_bottom"]) + EPS or r.end.x <= float(lay["text_narrow_right"]) + EPS)
					if not ok:
						bad.append("%s %s cd=%s foot=%s: %s" % [str(id), r, show_cd, not foot.is_empty(), body])
						break
					prev_end = r.end.y
	check("test_every_card_text_in_its_band_clear_of_gems_and_picture_%s_at_%s" % [locale, vp], bad.is_empty(), str(bad.slice(0, 3)))


func test_typical_card_has_no_empty_band(rect: Rect2, vp: Vector2, skills: SkillConfig, locale: String) -> void:
	var lay: Dictionary = CardFace.ancient_layout(rect, vp.y)
	var gem_top: float = (lay["damage"] as Rect2).position.y
	var worst: float = 0.0
	var detail: String = ""
	for id: String in TYPICAL:
		var desc: String = CardText.describe_resolved(skills.resolved(id, 1))
		var lines: Array = CardFace.text_layout(desc, rect, vp.y)
		if lines.is_empty() or lines.size() > 2:
			continue
		var gap: float = gem_top - (lines[-1]["rect"] as Rect2).end.y
		if gap > worst:
			worst = gap
			detail = "%s (%d lines): %.0f px" % [id, lines.size(), gap]
		var top_gap: float = (lines[0]["rect"] as Rect2).position.y - (lay["picture_frame"] as Rect2).end.y
		worst = maxf(worst, top_gap)
	check("test_typical_card_text_gap_under_%d_percent_of_height_%s_at_%s" % [roundi(MAX_GAP_SHARE * 100.0), locale, vp],
		worst <= rect.size.y * MAX_GAP_SHARE, "%s (max %.0f)" % [detail, rect.size.y * MAX_GAP_SHARE])


func test_foot_line_fits_before_the_damage_gem(rect: Rect2, vp: Vector2, skills: SkillConfig, locale: String) -> void:
	var lay: Dictionary = CardFace.ancient_layout(rect, vp.y)
	var box: Rect2 = lay["foot"]
	var font: Font = MenuFont.font() if MenuFont.font() != null else HudSkin.font()
	var bad: Array[String] = []
	for id: Variant in skills.cards.keys():
		var skill: Dictionary = skills.resolved(str(id), 1)
		for foot: Array in [[], ["%d gold" % 132, Color.GOLD, 22]]:
			var parts: Array = CardFace.foot_layout(skill, foot, rect, vp.y)["parts"]
			var w: float = 0.0
			for part: Array in parts:
				w += font.get_string_size(str(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, MenuFont.size(int(part[2]))).x
			if w > box.size.x + EPS or parts.is_empty():
				bad.append("%s: %s" % [str(id), str(parts)])
	check("test_foot_line_fits_left_of_the_damage_gem_%s_at_%s" % [locale, vp], bad.is_empty() and box.end.x <= (lay["damage"] as Rect2).position.x, str(bad.slice(0, 3)))


func test_short_face_leaves_text_to_the_panel(rect: Rect2, vp: Vector2, skills: SkillConfig) -> void:
	var short := Rect2(rect.position, Vector2(rect.size.x, roundf(180.0 * vp.y / 720.0)))
	var skill: Dictionary = skills.resolved("kiem_khi", 1)
	check("test_short_face_has_no_text_at_%s" % vp, not CardFace.shows_text(short, vp.y))
	check("test_short_face_text_incomplete_opens_the_panel_at_%s" % vp, not CardFace.face_text_complete(skill, CardText.describe_resolved(skill), [], short, vp.y))
	check("test_full_face_prints_a_short_text_at_%s" % vp, CardFace.face_text_complete(skill, CardText.describe_resolved(skill), [], rect, vp.y))
	check("test_picture_rect_is_the_layout_picture_at_%s" % vp, CardFace.picture_rect(rect, vp.y) == CardFace.ancient_layout(rect, vp.y)["picture"])


func test_keywords_are_coloured() -> void:
	var vp := Vector2(1280, 720)
	var rect := Rect2(Vector2.ZERO, ScreenLayout.card_face_size(vp))
	var text: String = "%s 3 s, %s 2, %s." % [TranslationServer.translate("ui.hud.pinned"), TranslationServer.translate("keyword.fragile"), TranslationServer.translate("keyword.frost")]
	var coloured: Array[String] = []
	for line: Dictionary in CardFace.text_layout(text, rect, vp.y):
		for seg: Array in line["segments"]:
			if seg[1] != null:
				coloured.append(str(seg[0]).strip_edges())
	check("test_keywords_drawn_in_their_colours", coloured.size() >= 3, str(coloured))
	var plain: Array = CardFace.text_layout("Sát thương theo số ô.", rect, vp.y)
	var any: bool = false
	for line: Dictionary in plain:
		for seg: Array in line["segments"]:
			any = any or seg[1] != null
	check("test_plain_text_has_no_keyword_colour", not any)


func test_cut_text_is_reported_incomplete(skills: SkillConfig) -> void:
	var vp := Vector2(1280, 720)
	var rect := Rect2(Vector2.ZERO, ScreenLayout.card_face_size(vp))
	var skill: Dictionary = skills.resolved("kiem_khi", 1)
	var long_text: String = "Sát thương theo số ô và gieo Giá Lạnh hai tầng. ".repeat(6).strip_edges()
	var lines: Array = CardFace.text_layout(long_text, rect, vp.y)
	var last: Array = (lines[-1] as Dictionary)["segments"]
	check("test_too_long_text_cut_with_an_ellipsis", not lines.is_empty() and str(last[-1][0]) == CardFace.ELLIPSIS)
	check("test_too_long_text_reported_incomplete", not CardFace.face_text_complete(skill, long_text, [], rect, vp.y))


# True when [param r] overlaps the diamond inscribed in the square [param box].
func _rect_hits_diamond(r: Rect2, box: Rect2) -> bool:
	if not r.intersects(box):
		return false
	var c: Vector2 = box.get_center()
	var half: float = box.size.x * 0.5
	var p := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return absf(p.x - c.x) + absf(p.y - c.y) < half - 0.5

extends SceneTree
## Battle card menu text (2026-11-02 open item "English text can be cut in the battle menu"): the battle menu has no
## detail panel and only the card-choice seconds, so every player card and curse must show its WHOLE battle text
## (CardText.describe_battle) on a menu face, at every supported viewport, in both locales. Cards with a long rule text
## use a shorter "<desc_key>_battle" string; the others fall back to their normal description.
## Run: godot --headless --path . -s res://tests/unit/ui/card_face_battle_text_test.gd

const VIEWPORTS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]
const LOCALES: Array[String] = ["vi", "en"]
## The battle menu always shows this many cards (skills.json hand_size).
const MENU_CARDS: int = 4

var fails: int = 0


func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	CardFace.style = "ancient"
	var previous: String = TranslationServer.get_locale()
	var skills: SkillConfig = SkillConfig.load_from_file()
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		for vp: Vector2 in VIEWPORTS:
			var rect: Rect2 = ScreenLayout.skill_menu_rects(vp, MENU_CARDS)[0]
			var cut: Array[String] = []
			for id: String in skills.cards.keys():
				var desc: String = CardText.describe_battle(skills.resolved(id, 1), null, locale)
				if _is_cut(CardFace.text_layout(desc, rect, vp.y)):
					cut.append(id)
			check("%s %s: no battle menu card text is cut" % [locale, vp], cut.is_empty(), str(cut))

	# The fallback: a card without a battle string shows its normal description.
	TranslationServer.set_locale("en")
	var plain: Dictionary = skills.resolved("kiem_khi", 1)
	check("no battle string -> normal description", CardText.describe_battle(plain) == CardText.describe_resolved(plain))
	# A long card's battle text is the short one, not the full description.
	var curse: Dictionary = skills.resolved("ganh_nang", 1)
	check("long card uses its battle string", CardText.describe_battle(curse) != CardText.describe_resolved(curse),
		CardText.describe_battle(curse))

	TranslationServer.set_locale(previous)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


func _is_cut(lines: Array) -> bool:
	if lines.is_empty():
		return false
	var last: String = ""
	for segment: Array in lines[-1]["segments"]:
		last += str(segment[0])
	return last.ends_with(CardFace.ELLIPSIS)

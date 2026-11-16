extends SceneTree
## cast_presentation is visual only. Since the 2026-11-16 weaponless roster every hero body casts with
## its hands, so cast_gesture is the Block-casting gesture and no body holds idle on a hand cast.
## Run: godot --headless --path . -s res://tests/unit/battle/cast_presentation_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	ck("vung_lay is hand", str(sc.get_skill("vung_lay").get("cast_presentation", "")) == "hand")
	ck("a card with no cast_presentation defaults to block",
		str(sc.get_skill("kiem_khi").get("cast_presentation", "")) == "block")
	ck("tram card clip stays cast_forward", CastVfx.card_clip("tram_dia") == "cast_forward")
	ck("ngan card clip stays cast_summon", CastVfx.card_clip("ngan_kiem") == "cast_summon")
	ck("hoa_loi card clip stays cast_gesture", CastVfx.card_clip("hoa_loi") == "cast_gesture")
	ck("vung_lay has no dedicated clip", CastVfx.card_clip("vung_lay").is_empty())
	for id: String in ["kiem_si", "sat_thu", "tho_san", "giao_si"]:
		ck("%s hand cast plays the gesture now that the body is weaponless" % id,
			UnitLayer.resolve_cast_clip("hand", "", id, false, false) == UnitLayer.CLIP_CAST)
		ck("%s block cast plays the gesture" % id,
			UnitLayer.resolve_cast_clip("block", "", id, false, false) == UnitLayer.CLIP_CAST)
	ck("mage hand cast keeps the open-hand gesture",
		UnitLayer.resolve_cast_clip("hand", "", "phap_su", false, false) == UnitLayer.CLIP_CAST)
	ck("hand clip wins when the sheet has it",
		UnitLayer.resolve_cast_clip("hand", "", "kiem_si", false, true) == UnitLayer.CLIP_HAND)
	ck("dedicated clip beats presentation",
		UnitLayer.resolve_cast_clip("hand", "cast_forward", "kiem_si", true, true) == "cast_forward")
	ck("the four legacy weapon cards still resolve to the gesture",
		UnitLayer.resolve_cast_clip("weapon", "", "kiem_si", false, true) == UnitLayer.CLIP_CAST)
	for id: String in ["kiem_si", "sat_thu", "tho_san", "giao_si"]:
		var sheet: SpriteSheet = SpriteSheet.load_unit(id)
		ck("%s sheet has no cast_hand" % id, sheet != null and not sheet.has_clip(UnitLayer.CLIP_HAND))
		ck("%s never holds idle on a cast" % id,
			not UnitLayer.resolve_cast_clip("hand", "", id, false, false).is_empty())
	var mage: SpriteSheet = SpriteSheet.load_unit("phap_su")
	ck("mage has no cast_hand row", mage != null and not mage.has_clip(UnitLayer.CLIP_HAND))
	var knight: SpriteSheet = SpriteSheet.load_unit("kiem_si")
	ck("tram clip still on the knight sheet", knight != null and knight.has_clip("cast_forward"))
	ck("ngan clip still on the knight sheet", knight != null and knight.has_clip("cast_summon"))
	ck("dedicated tram clip still beats a hand cast",
		UnitLayer.resolve_cast_clip("hand", "cast_forward", "kiem_si", true, true) == "cast_forward")
	ck("dedicated ngan clip still beats a hand cast",
		UnitLayer.resolve_cast_clip("hand", "cast_summon", "kiem_si", true, true) == "cast_summon")
	ck("hoa loi clip still beats a hand cast",
		UnitLayer.resolve_cast_clip("hand", "cast_gesture", "phap_su", true, true) == UnitLayer.CLIP_CAST)
	ck("no body is listed as a weapon cast body any more", UnitLayer.WEAPON_CAST_BODIES.is_empty())
	print("FAILS=%d" % fails)
	quit(0)

extends SceneTree
## cast_presentation is visual only. A hand cast on a weapon body never plays cast_gesture.
## Run: godot --headless --path . -s res://tests/unit/battle/cast_presentation_test.gd

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var sc: SkillConfig = SkillConfig.load_from_file()
	ck("vung_lay is hand", str(sc.get_skill("vung_lay").get("cast_presentation", "")) == "hand")
	ck("kiem_khi stays weapon", str(sc.get_skill("kiem_khi").get("cast_presentation", "")) == "weapon")
	ck("tram card clip stays cast_forward", CastVfx.card_clip("tram_dia") == "cast_forward")
	ck("ngan card clip stays cast_summon", CastVfx.card_clip("ngan_kiem") == "cast_summon")
	ck("hoa_loi card clip stays cast_gesture", CastVfx.card_clip("hoa_loi") == "cast_gesture")
	ck("vung_lay has no dedicated clip", CastVfx.card_clip("vung_lay").is_empty())
	for id: String in ["kiem_si", "sat_thu", "tho_san", "giao_si"]:
		ck("%s hand cast does not swing" % id,
			UnitLayer.resolve_cast_clip("hand", "", id, false, false).is_empty())
	ck("mage hand cast keeps the open-hand gesture",
		UnitLayer.resolve_cast_clip("hand", "", "phap_su", false, false) == UnitLayer.CLIP_CAST)
	ck("hand clip wins when the sheet has it",
		UnitLayer.resolve_cast_clip("hand", "", "kiem_si", false, true) == UnitLayer.CLIP_HAND)
	ck("dedicated clip beats presentation",
		UnitLayer.resolve_cast_clip("hand", "cast_forward", "kiem_si", true, true) == "cast_forward")
	ck("weapon presentation is cast_gesture",
		UnitLayer.resolve_cast_clip("weapon", "", "kiem_si", false, true) == UnitLayer.CLIP_CAST)
	for id: String in ["kiem_si", "sat_thu", "tho_san", "giao_si"]:
		var sheet: SpriteSheet = SpriteSheet.load_unit(id)
		ck("%s sheet has no cast_hand" % id, sheet != null and not sheet.has_clip(UnitLayer.CLIP_HAND))
		ck("%s hand cast holds idle" % id,
			UnitLayer.resolve_cast_clip("hand", "", id, false, false).is_empty())
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
	print("FAILS=%d" % fails)
	quit(0)

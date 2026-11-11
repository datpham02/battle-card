extends SceneTree
## Skill v2 V2 CastGlyphFx: every hero kit draws at every progress, deterministic, stays within a 32 px box around
## the hand, grows (more items held than at the start), flares only at the end and never flares under reduce motion;
## unknown forms and short colour lists draw nothing.
## Run: godot --headless --path . -s res://tests/unit/art/cast_glyph_fx_test.gd

const HAND := Vector2i(200, 100)
const COLS: Array[Color] = [Color("8FA3B8"), Color("EEF4FA")]

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	# SIZE + the flare ring (up to 8 px out) each side
	var box := Rect2i(HAND - Vector2i(24, 24), Vector2i(49, 49))
	for form: String in CastGlyphFx.FORMS:
		var drew: bool = true
		var inside: bool = true
		for k: float in [0.0, 0.2, 0.5, 0.7, 0.9, 1.0]:
			var items: Array[Dictionary] = CastGlyphFx.items(form, HAND, k, COLS, false)
			drew = drew and not items.is_empty()
			ck("%s @%.1f deterministic" % [form, k], items == CastGlyphFx.items(form, HAND, k, COLS, false))
			for it: Dictionary in items:
				inside = inside and box.encloses(it["rect"] as Rect2i) and it.has("col") and it.has("edge")
		ck("%s draws at every progress" % form, drew)
		ck("%s stays within 24 px of the hand" % form, inside)
		ck("%s: held glyph has more items than the first frame" % form,
			CastGlyphFx.items(form, HAND, 0.7, COLS, false).size() > CastGlyphFx.items(form, HAND, 0.05, COLS, false).size())
		ck("%s: the flare adds items at the release" % form,
			CastGlyphFx.items(form, HAND, 0.95, COLS, false).size() > CastGlyphFx.items(form, HAND, 0.7, COLS, false).size())
		ck("%s: reduce motion draws fewer items at the release (no flare ring)" % form,
			CastGlyphFx.items(form, HAND, 0.95, COLS, true).size() < CastGlyphFx.items(form, HAND, 0.95, COLS, false).size())
	ck("unknown form -> []", CastGlyphFx.items("laser", HAND, 0.5, COLS, false).is_empty())
	ck("one colour -> []", CastGlyphFx.items("sigil", HAND, 0.5, [Color.WHITE] as Array[Color], false).is_empty())
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)

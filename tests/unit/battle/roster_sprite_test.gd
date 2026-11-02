extends SceneTree
## Misty Forest roster sprites (ASSET-021..025, 2026-11-02): every roster enemy has its sheet, and the pattern brain's
## states pick the special clips: a Guard skill winding up -> `guard` (UnitLayer swaps in `brace` for a sheet that has
## only that), stunned -> `stunned`; hit still outranks both. Higher tier stands taller (user 2026-11-02): every elite's
## idle art is clearly taller than every normal's.
## Run: godot --headless --path . -s res://tests/unit/battle/roster_sprite_test.gd

const ENEMY: int = CombatState.Side.ENEMY
## Roster id -> the special clip its sheet must have ("" = none).
const ROSTER: Dictionary = {
	"rootling": "", "greycap_sporeling": "", "mossbound_sentry": "brace",
	"ancient_root_sentinel": "stunned", "mistbriar_matron": "guard",
}
const NORMALS: Array[String] = ["rootling", "greycap_sporeling", "mossbound_sentry"]
const ELITES: Array[String] = ["ancient_root_sentinel", "mistbriar_matron"]
## How much taller (art px) the shortest elite stands than the tallest normal: v1 elites were only ~6 px taller and read
## as normals; v2 is ~20.
const ELITE_MIN_EXTRA_PX: int = 12

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS: " if ok else "FAIL: ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	for id: String in ROSTER:
		var sheet: SpriteSheet = SpriteSheet.load_unit(id)
		var basic: bool = sheet != null and sheet.has_clip("idle") and sheet.has_clip("step") and sheet.has_clip("windup") \
			and sheet.has_clip("hit") and sheet.has_clip("down")
		_check("test_%s_sheet_has_the_basic_clips" % id, basic)
		var special: String = String(ROSTER[id])
		if not special.is_empty():
			_check("test_%s_sheet_has_%s" % [id, special], sheet != null and sheet.has_clip(special))
		_check("test_%s_faces_left" % id, sheet != null and sheet.facing() == "left")
	var tallest_normal: int = 0
	for id: String in NORMALS:
		tallest_normal = maxi(tallest_normal, _idle_art_height(id))
	for id: String in ELITES:
		var h: int = _idle_art_height(id)
		_check("test_%s_stands_taller_than_the_normals" % id, h >= tallest_normal + ELITE_MIN_EXTRA_PX,
			"(elite %d px, tallest normal %d px)" % [h, tallest_normal])
	var base := {UnitLayer.CTX_SIDE: ENEMY, UnitLayer.CTX_SWINGING: true}
	var guarding: Dictionary = base.duplicate()
	guarding[UnitLayer.CTX_GUARDING] = true
	_check("test_guard_skill_winds_up_as_guard", UnitLayer.clip_for(guarding) == UnitLayer.CLIP_GUARD)
	var stunned := {UnitLayer.CTX_SIDE: ENEMY, UnitLayer.CTX_STUNNED: true}
	_check("test_stunned_enemy_plays_stunned", UnitLayer.clip_for(stunned) == UnitLayer.CLIP_STUNNED)
	var hit: Dictionary = stunned.duplicate()
	hit[UnitLayer.CTX_HIT] = true
	_check("test_hit_outranks_stunned", UnitLayer.clip_for(hit) == UnitLayer.CLIP_HIT)
	_check("test_a_plain_skill_still_winds_up", UnitLayer.clip_for(base) == UnitLayer.CLIP_WINDUP)
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


## Opaque rows in the first idle frame of a unit's sheet (0 when the sheet or texture is missing).
func _idle_art_height(id: String) -> int:
	var sheet: SpriteSheet = SpriteSheet.load_unit(id)
	if sheet == null or sheet.texture() == null or not sheet.has_clip("idle"):
		return 0
	var rect: Rect2i = (sheet.clip("idle")["frames"] as Array)[0]
	var image: Image = sheet.texture().get_image().get_region(rect)
	var used: Rect2i = image.get_used_rect()
	return used.size.y

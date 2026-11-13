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
	# 2026-11-03/04 roster v2 (ASSET-026..028).
	"goblin_archer": "", "dire_wolf": "", "wolf_alpha": "howl",
	# 2026-11-13 Hellfire roster (block brain: the 5 basic clips only, no special clip is ever requested).
	"imp": "", "ember_hound": "", "ash_golem": "", "flame_cultist": "", "magma_slug": "", "hell_knight": "",
	"fire_eater": "", "ash_phoenix": "", "inferno_lord": "",
	# 2026-11-13 Sands roster (block brain).
	"dune_jackal": "", "sand_beetle": "", "dust_nomad": "", "mirage_sprite": "", "scarab_guard": "", "sun_archer": "",
	"sand_burrower": "", "scorpion": "", "sand_sphinx": "",
	# 2026-11-13 Swamp roster (block brain).
	"bog_rat": "", "mire_slug": "", "swamp_lizard": "", "marsh_toad": "", "reed_witch": "", "bog_hound": "",
	"spore_cap": "", "leap_frog": "", "toad_matriarch": "",
	# 2026-11-13 Dungeon roster (block brain).
	"skeleton": "", "zombie": "", "bat_swarm": "", "slime": "", "ghost": "", "reacter": "", "cultist": "",
	"rat_king_guard": "", "jailer": "", "ogre_king": "",
	# 2026-11-13 Ice Tower roster (block brain); ghost_elite is the script recolour of ghost.
	"frost_sprite": "", "wisp": "", "stone_sentry": "", "snow_wolf": "", "fuse_golem": "", "rime_archer": "",
	"ice_golem": "", "ghost_elite": "", "frost_mage": "", "mist_lord": "",
	# 2026-11-13 Sky Isles roster (block brain).
	"cloud_sprite": "", "harpy": "", "wind_monk": "", "storm_eagle": "", "sky_sentinel": "", "thunder_shaman": "",
	"gale_bird": "", "cloud_veil": "", "storm_dragon": "",
}
## 2026-11-04: wolves are low by nature (height follows the creature, user 2026-11-03), so the elite wolf is measured
## against the normal wolf instead of the upright normals: it must stand clearly taller than the Dire Wolf.
const WOLF_ELITE_MIN_EXTRA_PX: int = 8
const NORMALS: Array[String] = ["rootling", "greycap_sporeling", "mossbound_sentry",
	# 2026-11-13 Hellfire normals (the hound and the slug are low by nature, like the wolves; the upright ones count).
	"imp", "ash_golem", "flame_cultist", "hell_knight",
	# 2026-11-13 Sands normals (the jackal and the beetle are low by nature; the upright ones count).
	"dust_nomad", "mirage_sprite", "scarab_guard", "sun_archer",
	# 2026-11-13 Swamp: the witch is the only upright normal; the rat, slug, lizard, toad and hound are low by nature.
	"reed_witch",
	# 2026-11-13 Dungeon upright normals (the bats and the slime are low by nature).
	"skeleton", "zombie", "ghost", "reacter", "cultist", "rat_king_guard",
	# 2026-11-13 Ice Tower upright normals (the snow wolf is low by nature).
	"frost_sprite", "wisp", "stone_sentry", "fuse_golem", "rime_archer", "ice_golem", "ghost_elite",
	# 2026-11-13 Sky Isles normals (all stand upright or hover).
	"cloud_sprite", "harpy", "wind_monk", "storm_eagle", "sky_sentinel", "thunder_shaman"]
const ELITES: Array[String] = ["ancient_root_sentinel", "mistbriar_matron",
	# 2026-11-13 Hellfire elites (80-wide canvases, 73-75 px tall).
	"fire_eater", "ash_phoenix",
	# 2026-11-13 Sands elites.
	"sand_burrower", "scorpion",
	# 2026-11-13 Swamp elite measured against the upright normals (the spore cap stands 78 px).
	"spore_cap",
	# 2026-11-13 Dungeon elite.
	"jailer",
	# 2026-11-13 Ice Tower elite.
	"frost_mage",
	# 2026-11-13 Sky Isles elites.
	"gale_bird", "cloud_veil"]
## 2026-11-13 (user "Yes, chấp nhận"): a low-by-nature elite (the frog, like the wolf) is measured against the low normals of its
## region instead of the upright ones.
const LOW_ELITES: Dictionary = {"leap_frog": ["bog_rat", "mire_slug", "swamp_lizard", "marsh_toad", "bog_hound"]}
## 2026-11-13: a one-cell warden stands clearly taller than every elite of its region (bigger tier = bigger, user rule).
const WARDENS_1CELL: Dictionary = {"inferno_lord": ["fire_eater", "ash_phoenix"], "sand_sphinx": ["sand_burrower", "scorpion"],
	"toad_matriarch": ["spore_cap", "leap_frog"], "ogre_king": ["jailer"],
	"mist_lord": ["frost_mage"], "storm_dragon": ["gale_bird", "cloud_veil"]}
const WARDEN_MIN_EXTRA_PX: int = 4
## 2026-11-13 (user "Yes, chấp nhận"): a warden the bible designs low and wide (the Toad Matriarch, "tròn, rộng, thấp") is bigger
## by body mass instead of height: its opaque idle pixels are at least this multiple of the elite's.
const WARDEN_MIN_AREA_MULT: float = 1.5
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
	var howling: Dictionary = base.duplicate()
	howling[UnitLayer.CTX_HOWLING] = true
	_check("test_haste_skill_winds_up_as_howl", UnitLayer.clip_for(howling) == UnitLayer.CLIP_HOWL)
	var howl_hit: Dictionary = howling.duplicate()
	howl_hit[UnitLayer.CTX_HIT] = true
	_check("test_hit_outranks_howl", UnitLayer.clip_for(howl_hit) == UnitLayer.CLIP_HIT)
	for warden: String in WARDENS_1CELL:
		var wh: int = _idle_art_height(warden)
		var wa: int = _idle_art_area(warden)
		for elite: Variant in WARDENS_1CELL[warden] as Array:
			var eh: int = _idle_art_height(str(elite))
			var ea: int = _idle_art_area(str(elite))
			var bigger: bool = wh >= eh + WARDEN_MIN_EXTRA_PX or float(wa) >= float(ea) * WARDEN_MIN_AREA_MULT
			_check("test_%s_is_bigger_than_%s" % [warden, str(elite)], bigger,
				"(warden %d px / %d opaque, elite %d px / %d opaque)" % [wh, wa, eh, ea])
	for low_elite: String in LOW_ELITES:
		var tallest_low: int = 0
		for id: Variant in LOW_ELITES[low_elite] as Array:
			tallest_low = maxi(tallest_low, _idle_art_height(str(id)))
		var lh: int = _idle_art_height(low_elite)
		_check("test_%s_stands_taller_than_the_low_normals" % low_elite, lh >= tallest_low + ELITE_MIN_EXTRA_PX,
			"(elite %d px, tallest low normal %d px)" % [lh, tallest_low])
	var alpha_h: int = _idle_art_height("wolf_alpha")
	var wolf_h: int = _idle_art_height("dire_wolf")
	_check("test_wolf_alpha_stands_taller_than_the_dire_wolf", alpha_h >= wolf_h + WOLF_ELITE_MIN_EXTRA_PX,
		"(alpha %d px, dire wolf %d px)" % [alpha_h, wolf_h])
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


## Opaque pixels in the first idle frame of a unit's sheet (0 when missing): the body mass a low, wide warden is judged by.
func _idle_art_area(id: String) -> int:
	var sheet: SpriteSheet = SpriteSheet.load_unit(id)
	if sheet == null or sheet.texture() == null or not sheet.has_clip("idle"):
		return 0
	var rect: Rect2i = (sheet.clip("idle")["frames"] as Array)[0]
	var image: Image = sheet.texture().get_image().get_region(rect)
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return count


## Opaque rows in the first idle frame of a unit's sheet (0 when the sheet or texture is missing).
func _idle_art_height(id: String) -> int:
	var sheet: SpriteSheet = SpriteSheet.load_unit(id)
	if sheet == null or sheet.texture() == null or not sheet.has_clip("idle"):
		return 0
	var rect: Rect2i = (sheet.clip("idle")["frames"] as Array)[0]
	var image: Image = sheet.texture().get_image().get_region(rect)
	var used: Rect2i = image.get_used_rect()
	return used.size.y

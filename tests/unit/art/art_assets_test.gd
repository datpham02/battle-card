extends SceneTree
## Story 047 Part B: ArtAssets registry (region.json resolution, missing-region behaviour,
## forest env PNGs byte-identical to their approved candidates). Headless, no import needed for
## the hash and region checks; textures load through `load()` or the raw-image fallback.
## Run: godot --headless --path . -s res://tests/unit/art/art_assets_test.gd

const Assets := preload("res://src/art/art_assets.gd")
const CANDIDATES := "res://design/assets/candidates/misty-forest/"
const FOREST := "res://assets/art/env/forest/"
## Copied file → approved candidate it must hash-match.
const COPIES: Dictionary = {
	"bg_forest_far.png": "ASSET-005-bg_forest_far.png",
	"bg_forest_near.png": "ASSET-005-bg_forest_near.png",
	"env_slab_forest_9slice.png": "ASSET-004-env_slab_forest_9slice.png",
	"env_slab_forest_stamps.png": "ASSET-004-env_slab_forest_stamps.png",
	"env_slab_forest_stamps.json": "ASSET-004-env_slab_forest_stamps.json",
	"env_thorn_forest_tile16.png": "ASSET-007-env_thorn_forest_tile16.png",
}
## Texture key → expected size.
const TEXTURES: Dictionary = {
	"backdrop.far": Vector2i(800, 360),
	"backdrop.near": Vector2i(800, 48),
	"slab.nine_slice": Vector2i(16, 16),
	"slab.stamps": Vector2i(96, 48),
	"thorn_tile": Vector2i(16, 16),
}

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	Assets.clear_cache()
	test_region_forest()
	test_region_missing()
	test_textures()
	test_stamps_meta()
	test_hashes()
	test_region_for_chapter()
	test_fallback_bands()
	test_half_tints()
	print("FAILS=%d" % fails)
	quit(fails)


func _dotted(d: Dictionary, key: String) -> Variant:
	var node: Variant = d
	for part: String in key.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(part):
			return null
		node = (node as Dictionary)[part]
	return node


func test_region_forest() -> void:
	var region: Dictionary = Assets.region("forest")
	check("region('forest') is not empty", not region.is_empty())
	var resolved := 0
	for key: String in Assets.REGION_PATH_KEYS:
		var value: Variant = _dotted(region, key)
		if value is String and String(value).begins_with(FOREST) and FileAccess.file_exists(String(value)):
			resolved += 1
		else:
			print("  unresolved %s = %s" % [key, str(value)])
	# 2026-11-06: + support.wall_tile (the forest's stone foundation strip) = 7.
	# + slab.flagstones (flagstone sheet) + platform.face_tile (lip strip) = 9.
	check("13 paths resolve to res:// files on disk (+ support pillar, arch, roots, ferns)", resolved == 13)
	check("near_bottom_row is read from JSON (70)", int(_dotted(region, "backdrop.near_bottom_row")) == 70)
	check("platform palette carries deck / face / face_top / mortar / shadow / divider",
		["deck", "face", "face_top", "mortar", "shadow", "shadow_alpha", "divider"].all(
			func(k: String) -> bool: return (region.get("platform", {}) as Dictionary).has(k)))
	check("region('forest') is cached (same dictionary)", Assets.region("forest") == region)


func test_region_missing() -> void:
	var r: Dictionary = Assets.region("nowhere")
	check("region('nowhere') is {}", r.is_empty())
	check("region('nowhere') again is {} (no crash, warned once)", Assets.region("nowhere").is_empty())
	check("region_texture of a missing region is null", Assets.region_texture("nowhere", "backdrop.far") == null)
	check("region_stamps of a missing region is {}", Assets.region_stamps("nowhere").is_empty())


func test_textures() -> void:
	for key: String in TEXTURES.keys():
		var tex: Texture2D = Assets.region_texture("forest", key)
		var expected: Vector2i = TEXTURES[key]
		check("region_texture('forest', '%s') is %dx%d" % [key, expected.x, expected.y],
			tex != null and tex.get_width() == expected.x and tex.get_height() == expected.y)
	check("region_texture is cached (same object)",
		Assets.region_texture("forest", "thorn_tile") == Assets.region_texture("forest", "thorn_tile"))
	check("region_texture of an unknown key is null", Assets.region_texture("forest", "slab.nope") == null)
	check("texture() of a missing path is null", Assets.texture("res://assets/art/env/forest/missing.png") == null)


func test_stamps_meta() -> void:
	var meta: Dictionary = Assets.region_stamps("forest")
	check("region_stamps('forest') has 18 stamps", (meta.get("stamps", []) as Array).size() == 18)
	check("region_stamps('forest') carries rules and nine_slice margins",
		meta.has("rules") and int(_dotted(meta, "nine_slice.margins.bottom")) == 4)


func test_hashes() -> void:
	for copy: String in COPIES.keys():
		var a: String = FileAccess.get_sha256(FOREST + copy)
		var b: String = FileAccess.get_sha256(CANDIDATES + String(COPIES[copy]))
		check("%s is byte-identical to %s" % [copy, COPIES[copy]], a != "" and a == b)
	var zips := 0
	for f: String in DirAccess.get_files_at(FOREST):
		if f.ends_with(".zip"):
			zips += 1
	check("no .zip was copied into the forest folder", zips == 0)


## Art bible 8.1 region folders; every mapped chapter must land on one of them.
const ART_REGIONS: Array[String] = ["forest", "dungeon", "ice_tower", "swamp", "sands", "hellfire", "sky_isles", "lattice_heart"]
## chapters.json id -> art region (assets/art/regions.json).
const CHAPTER_REGIONS: Dictionary = {
	"ch1": "forest", "ch2": "dungeon", "ch3": "ice_tower", "swamp": "swamp",
	"desert": "sands", "hellfire": "hellfire", "sky_isles": "sky_isles", "an_dai": "lattice_heart",
}


func test_region_for_chapter() -> void:
	for chapter: String in CHAPTER_REGIONS.keys():
		var got: String = Assets.region_for_chapter(chapter)
		check("region_for_chapter('%s') is '%s' (got '%s')" % [chapter, CHAPTER_REGIONS[chapter], got], got == String(CHAPTER_REGIONS[chapter]))
		check("region_for_chapter('%s') is an art bible 8.1 region" % chapter, ART_REGIONS.has(got))
	check("region_for_chapter('') is the default 'forest'", Assets.region_for_chapter("") == "forest")
	check("region_for_chapter('bogus_chapter') is the default 'forest'", Assets.region_for_chapter("bogus_chapter") == "forest")
	check("region_for_chapter is stable across calls", Assets.region_for_chapter("an_dai") == Assets.region_for_chapter("an_dai"))
	check("DEFAULT_REGION is 'forest'", Assets.DEFAULT_REGION == "forest")


func test_fallback_bands() -> void:
	var forest: Dictionary = Assets.fallback_bands("forest")
	check("fallback_bands('forest') sky is the art bible 6.4 mist #7D8896", forest.get("sky", Color.BLACK) == Color.html("#7D8896"))
	check("fallback_bands('forest') ground is darker than its sky", (forest["ground"] as Color).get_luminance() < (forest["sky"] as Color).get_luminance())
	for region: String in ART_REGIONS:
		var bands: Dictionary = Assets.fallback_bands(region)
		check("fallback_bands('%s') carries sky and ground Colors" % region, bands.get("sky") is Color and bands.get("ground") is Color)
	var unknown: Dictionary = Assets.fallback_bands("nowhere")
	check("fallback_bands of an unknown region falls back to the default bands (no crash)", unknown.get("sky") is Color and unknown["sky"] == Color.html(String(Assets.DEFAULT_BANDS["sky"])))
	check("fallback_bands never returns the old beige (MainScreen.BG_COLOR) for forest", forest["sky"] != MainScreen.BG_COLOR and forest["ground"] != MainScreen.BG_COLOR)


# 2026-10-31 (user): the two halves differ in colour; the enemy's is the gloomier one. Shared tints in
# regions.json; a region without its own uses them; neither is red-dominant (red = telegraph, art bible P3).
func test_half_tints() -> void:
	var t: Dictionary = Assets.half_tints("forest")
	# 2026-11-06 (user: redo the whole floor, the halves read as the same stone): the forest overrides the shared
	# tints with lighter ones in its region.json; the shared ones stay for the other regions.
	check("half_tints forest player is #E9DBEC (own, concept grey)", t["player"] == Color("E9DBEC"))
	check("half_tints forest enemy is #C4C5C4 (own, concept grey)", t["enemy"] == Color("C4C5C4"))
	check("half_tints unknown region uses the shared tints", Assets.half_tints("no_such_region")["enemy"] == Color("9A84A4"))
	var e: Color = t["enemy"]
	var pl: Color = t["player"]
	check("enemy half darker than the player half", e.get_luminance() < pl.get_luminance())
	check("enemy tint is not red-dominant (red is the telegraph)", e.r <= maxf(e.g, e.b) + 0.05)
	check("player tint is not red-dominant", pl.r <= maxf(pl.g, pl.b))

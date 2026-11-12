extends SceneTree
## 2026-11-06 (user: "Làm thử 3 khu"): areas of a region (`forest@edge` / `@ruins` / `@sanctum`): the area picked
## for a map node (ArtAssets.area_for), the region a battle draws (region_for_match) and the merged area data.
## Run: godot --headless --path . -s res://tests/unit/art/region_areas_test.gd

const Assets := preload("res://src/art/art_assets.gd")
## The forest region map: 7 columns, boss in the last (chapters.json region skeleton).
const COLUMNS: int = 7

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	Assets.clear_cache()
	test_area_for_columns()
	test_area_for_boss()
	test_region_for_match()
	test_area_merge()
	test_unknown_area()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func test_area_for_columns() -> void:
	var got: Array[String] = []
	for c: int in COLUMNS - 1:
		got.append(Assets.area_for("forest", c, COLUMNS, "battle"))
	var want: Array[String] = ["edge", "edge", "edge", "ruins", "ruins", "ruins"]
	check("columns 0-2 edge, 3-5 ruins: %s" % [got], got == want)
	check("miniboss mid-map stays ruins", Assets.area_for("forest", 3, COLUMNS, "miniboss") == "ruins")
	check("a region without areas has none", Assets.area_for("lattice_heart", 0, COLUMNS, "battle") == "")  # 2026-11-12: dungeon gained areas (World Map v2 region visuals); the final match has none


func test_area_for_boss() -> void:
	check("boss node is sanctum", Assets.area_for("forest", COLUMNS - 1, COLUMNS, "boss") == "sanctum")
	check("boss kind wins over column", Assets.area_for("forest", 0, COLUMNS, "boss") == "sanctum")


func test_region_for_match() -> void:
	check("no area -> base", Assets.region_for_match({"chapter_id": "ch1"}) == "forest")
	check("area -> region@area", Assets.region_for_match({"chapter_id": "ch1", "art_area": "sanctum"}) == "forest@sanctum")
	check("unknown area -> base", Assets.region_for_match({"chapter_id": "ch1", "art_area": "nowhere"}) == "forest")
	check("base_region strips area", Assets.base_region("forest@edge") == "forest")


func test_area_merge() -> void:
	var base: Dictionary = Assets.region("forest")
	var edge: Dictionary = Assets.region("forest@edge")
	var sanctum: Dictionary = Assets.region("forest@sanctum")
	var edge_far: String = str(edge["backdrop"]["far"])
	check("edge far resolved to the base folder: " + edge_far, edge_far.begins_with("res://assets/art/env/forest/") and edge_far != str(base["backdrop"]["far"]))
	check("edge keeps the base wall tile", str(edge["support"]["wall_tile"]) == str(base["support"]["wall_tile"]))
	check("sanctum has no ferns", int(sanctum["support"]["fern_every"]) == 0)
	check("sanctum keeps the base flagstones", str(sanctum["slab"]["flagstones"]) == str(base["slab"]["flagstones"]))
	check("sanctum half tints differ", Assets.half_tints("forest@sanctum")["player"] != Assets.half_tints("forest")["player"])
	check("area texture loads", Assets.region_texture("forest@edge", "backdrop.far") != null)
	check("base region not changed by the merge", int(Assets.region("forest")["support"]["fern_every"]) == int(base["support"]["fern_every"]) and int(base["support"]["fern_every"]) > 0)
	check("fallback bands of an area are the base region's", Assets.fallback_bands("forest@sanctum") == Assets.fallback_bands("forest"))


func test_unknown_area() -> void:
	var data: Dictionary = Assets.region("forest@nowhere")
	check("unknown area falls back to the base data", str(data.get("thorn_tile", "")) == str(Assets.region("forest").get("thorn_tile", "")))

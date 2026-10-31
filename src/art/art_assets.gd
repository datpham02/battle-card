class_name ArtAssets
extends RefCounted
## Static registry of the art the battle canvas draws (Story 047 Part B). Reads
## `assets/art/env/<region>/region.json` once, resolves every file name in it to a `res://` path
## and caches the parsed dictionary and every texture it hands out. Nothing here crashes on a
## missing file: a missing region is `{}`, a missing texture is `null`, and each is warned about
## once per path so a dev build without a region's art stays quiet after the first frame.
##
## Parts C and D add `unit_sheet(unit_id) -> SpriteSheet` and `status_pack(kind, frame_kind)
## -> VfxPack` here (same contract: `null` when missing, one warning per path).
##
## Resolution order for textures: `load()` (the imported `.ctex` — the production path); if the
## PNG is on disk but not yet imported (fresh clone, headless test before `--import`) it is read
## with `Image.load_from_file` and wrapped in an `ImageTexture` so the painters still work.

## Folder every region lives in: `assets/art/env/<id>/`.
const ENV_ROOT := "res://assets/art/env/"
## File each region folder must contain.
const REGION_FILE := "region.json"
## JSON keys whose string values are file names relative to the region folder; each is rewritten
## to a full `res://` path by `region()`.
const REGION_PATH_KEYS: Array[String] = [
	"backdrop.far", "backdrop.near", "slab.nine_slice", "slab.stamps", "slab.stamps_meta", "thorn_tile",
]
## Chapter -> region map (`chapters`, `default`) and the flat backdrop colours per region
## (`fallback_bands`), read once by [method region_for_chapter] / [method fallback_bands].
const REGIONS_FILE := "res://assets/art/regions.json"
## Region used when REGIONS_FILE is missing or names no `default`.
const DEFAULT_REGION := "forest"
## Sky / ground of the flat fallback backdrop when a region has no `fallback_bands` entry (the forest
## mist of art bible 6.4 over a darker ground).
const DEFAULT_BANDS := {"sky": "#7D8896", "ground": "#4A5257"}

static var _regions: Dictionary = {}
static var _textures: Dictionary = {}
static var _stamps: Dictionary = {}
static var _warned: Dictionary = {}
static var _regions_map: Dictionary = {}
static var _regions_map_loaded: bool = false


## The region's `region.json` with every path in REGION_PATH_KEYS resolved to `res://...`.
## `{}` (and one warning) when the file is missing or malformed.
static func region(id: String) -> Dictionary:
	if _regions.has(id):
		return _regions[id]
	var dir: String = ENV_ROOT + id + "/"
	var path: String = dir + REGION_FILE
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = (parsed as Dictionary).duplicate(true)
			for key: String in REGION_PATH_KEYS:
				var value: Variant = _get_dotted(data, key)
				if value is String and not (value as String).begins_with("res://"):
					_set_dotted(data, key, dir + String(value))
		else:
			_warn_once(path, "ArtAssets: region '%s' has a malformed %s" % [id, REGION_FILE])
	else:
		_warn_once(path, "ArtAssets: no region '%s' (%s missing)" % [id, path])
	_regions[id] = data
	return data


## A texture of the region by dotted key (`backdrop.far`, `backdrop.near`, `slab.nine_slice`,
## `slab.stamps`, `thorn_tile`). `null` when the region, the key or the file is missing.
static func region_texture(id: String, key: String) -> Texture2D:
	var value: Variant = _get_dotted(region(id), key)
	if not (value is String):
		return null
	return texture(String(value))


## The stamps sheet metadata (`slab.stamps_meta` JSON) of the region: `cell`, `stamps[]`, `rules`,
## `palette`, `nine_slice`. `{}` when missing.
static func region_stamps(id: String) -> Dictionary:
	if _stamps.has(id):
		return _stamps[id]
	var meta: Dictionary = {}
	var value: Variant = _get_dotted(region(id), "slab.stamps_meta")
	if value is String:
		var path := String(value)
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				meta = parsed
			else:
				_warn_once(path, "ArtAssets: malformed stamps JSON %s" % path)
		else:
			_warn_once(path, "ArtAssets: stamps JSON missing %s" % path)
	_stamps[id] = meta
	return meta


## The art region of chapters.json chapter [param chapter_id] (`ch1` -> `forest`, ...) from
## REGIONS_FILE; the file's `default` (DEFAULT_REGION when absent) for "" or an unmapped chapter.
## Never empty, never crashes: a missing or malformed file warns once and maps everything to the
## default.
static func region_for_chapter(chapter_id: String) -> String:
	var map: Dictionary = _load_regions_map()
	var chapters: Variant = map.get("chapters", {})
	if chapters is Dictionary and (chapters as Dictionary).has(chapter_id):
		var id := str((chapters as Dictionary)[chapter_id])
		if not id.is_empty():
			return id
	var fallback := str(map.get("default", DEFAULT_REGION))
	return fallback if not fallback.is_empty() else DEFAULT_REGION


## Flat sky / ground colours (`{"sky": Color, "ground": Color}`) BackdropLayer draws for
## [param region_id] when it has no backdrop art: the region's `fallback_bands` entry of
## REGIONS_FILE, DEFAULT_BANDS for an unknown region.
static func fallback_bands(region_id: String) -> Dictionary:
	var bands: Variant = _load_regions_map().get("fallback_bands", {})
	var entry: Variant = (bands as Dictionary).get(region_id, {}) if bands is Dictionary else {}
	var e: Dictionary = entry if entry is Dictionary else {}
	return {
		"sky": _html_color(e.get("sky", null), Color.html(String(DEFAULT_BANDS["sky"]))),
		"ground": _html_color(e.get("ground", null), Color.html(String(DEFAULT_BANDS["ground"]))),
	}


## 2026-10-31 (user: "sân của ta và địch có màu khác nhau để phân biệt"): the multiply tints FloorLayer lays on
## the slabs of each half, `{"player": Color, "enemy": Color}`: the region's own `half_tints` (region.json),
## else REGIONS_FILE's `half_tints`, else white (no tint).
static func half_tints(region_id: String) -> Dictionary:
	var shared: Variant = _load_regions_map().get("half_tints", {})
	var own: Variant = region(region_id).get("half_tints", {})
	var s: Dictionary = shared if shared is Dictionary else {}
	var o: Dictionary = own if own is Dictionary else {}
	return {
		"player": _html_color(o.get("player", s.get("player", null)), Color.WHITE),
		"enemy": _html_color(o.get("enemy", s.get("enemy", null)), Color.WHITE),
	}


## A cached texture by full `res://` path; `null` (one warning) when it cannot be loaded.
static func texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		# On disk but not imported (no .import yet, headless test): the runtime has no raw PNG
		# resource loader, so read the image directly. Filtering is the canvas item's, so the
		# result draws the same as the imported texture.
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		_warn_once(path, "ArtAssets: texture missing %s" % path)
	_textures[path] = tex
	return tex


## Forget every cached region, texture and warning (tests).
static func clear_cache() -> void:
	_regions.clear()
	_textures.clear()
	_stamps.clear()
	_warned.clear()
	_regions_map.clear()
	_regions_map_loaded = false


static func _load_regions_map() -> Dictionary:
	if _regions_map_loaded:
		return _regions_map
	_regions_map_loaded = true
	_regions_map = {}
	if FileAccess.file_exists(REGIONS_FILE):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGIONS_FILE))
		if parsed is Dictionary:
			_regions_map = parsed
		else:
			_warn_once(REGIONS_FILE, "ArtAssets: malformed %s; every chapter maps to '%s'" % [REGIONS_FILE, DEFAULT_REGION])
	else:
		_warn_once(REGIONS_FILE, "ArtAssets: %s missing; every chapter maps to '%s'" % [REGIONS_FILE, DEFAULT_REGION])
	return _regions_map


static func _html_color(value: Variant, fallback: Color) -> Color:
	if value is String and Color.html_is_valid(String(value)):
		return Color.html(String(value))
	return fallback


static func _warn_once(path: String, message: String) -> void:
	if _warned.has(path):
		return
	_warned[path] = true
	push_warning(message)


static func _get_dotted(data: Dictionary, key: String) -> Variant:
	var node: Variant = data
	for part: String in key.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(part):
			return null
		node = (node as Dictionary)[part]
	return node


static func _set_dotted(data: Dictionary, key: String, value: Variant) -> void:
	var parts: PackedStringArray = key.split(".")
	var node: Dictionary = data
	for i: int in parts.size() - 1:
		node = node[parts[i]]
	node[parts[parts.size() - 1]] = value

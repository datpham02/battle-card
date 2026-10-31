class_name SpriteSheet
extends RefCounted
## Unit sprite sheet loader. Story 047 Part C (art bible §8.3 frames, §8.6 clips and loop
## rules, §8.7 import). Node-free: `UnitLayer` draws a clip's `Rect2i` with
## `draw_texture_rect_region` from its own `_draw`; `UnitAnimator` walks the frames.
##
## Reads the Aseprite "array" JSON that `tools/asset-pipeline/export_sheets.py` writes
## (Story 045) next to `assets/art/units/unit_<id>_sheet.png`:
##   frames[]            { filename, frame {x, y, w, h}, duration (ms) }
##   meta.image          sheet file name, resolved next to the JSON
##   meta.frameTags[]    { name, from, to, direction } — one tag per clip, inclusive range
##   meta.tessera.loop   { <tag>: loop | once | hold_last | hold }   (default "loop")
##   meta.tessera.facing "right" | "left" — the direction the drawn unit faces (default "right")
## Only `direction: "forward"` is produced by the exporter; other directions are read as forward.
##
## The texture is never loaded by `load_unit`: `texture()` resolves it lazily with `load()` and
## stays null when the PNG is missing or not imported (headless without import), with no error.

const UNIT_DIR := "res://assets/art/units/"
const SHEET_PREFIX := "unit_"
const SHEET_SUFFIX := "_sheet"
const DEFAULT_LOOP := "loop"
const DEFAULT_FACING := "right"
const LOOP_KINDS: Array[String] = ["loop", "once", "hold_last", "hold"]
const FACINGS: Array[String] = ["right", "left"]

## unit id -> SpriteSheet (or null when the sheet is missing, so it is warned about once).
static var _cache: Dictionary = {}

var _unit_id: String = ""
var _image_path: String = ""
var _facing: String = DEFAULT_FACING
var _frame_size: Vector2i = Vector2i.ZERO
var _image_size: Vector2i = Vector2i.ZERO
## clip name -> clip Dictionary (see `clip()`), in frameTags order.
var _clips: Dictionary = {}
var _texture: Texture2D = null
var _texture_tried: bool = false


## Loads `res://assets/art/units/unit_<unit_id>_sheet.json` (+ `.png` lazily). Cached per id.
## Null, with one warning per id, when the JSON is missing or malformed.
static func load_unit(unit_id: String) -> SpriteSheet:
	if _cache.has(unit_id):
		return _cache[unit_id]
	var sheet := load_json(json_path(unit_id))
	if sheet != null:
		sheet._unit_id = unit_id
	_cache[unit_id] = sheet
	return sheet


## Loads a sheet JSON at an explicit path; the image resolves next to it. Null with one warning
## when the file is missing or malformed. Not cached (use `load_unit` for that).
static func load_json(path: String) -> SpriteSheet:
	if not FileAccess.file_exists(path):
		push_warning("SpriteSheet: no sheet JSON at %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SpriteSheet: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		push_warning("SpriteSheet: %s is not a JSON object" % path)
		return null
	var meta: Variant = (data as Dictionary).get("meta", {})
	var image_name := String((meta as Dictionary).get("image", "")) if meta is Dictionary else ""
	var image_path := path.get_base_dir().path_join(image_name) if not image_name.is_empty() else ""
	var sheet := from_json(data, image_path)
	if sheet == null:
		push_warning("SpriteSheet: malformed sheet JSON at %s" % path)
	return sheet


## Builds a sheet from already-parsed JSON data. Pure (no file access, no warning): null when
## `data` lacks a usable `frames` array or yields no clip. `image_path` is the sheet PNG.
static func from_json(data: Dictionary, image_path: String) -> SpriteSheet:
	var frames_data: Variant = data.get("frames", null)
	if not (frames_data is Array):
		return null
	var rects: Array[Rect2i] = []
	var durations: Array[int] = []
	for entry: Variant in frames_data:
		if not (entry is Dictionary):
			return null
		var f: Dictionary = entry
		var r: Variant = f.get("frame", null)
		if not (r is Dictionary):
			return null
		var rd: Dictionary = r
		var rect := Rect2i(int(rd.get("x", 0)), int(rd.get("y", 0)), int(rd.get("w", 0)), int(rd.get("h", 0)))
		if rect.size.x <= 0 or rect.size.y <= 0:
			return null
		rects.append(rect)
		durations.append(maxi(0, int(f.get("duration", 0))))
	if rects.is_empty():
		return null
	var meta: Variant = data.get("meta", {})
	if not (meta is Dictionary):
		meta = {}
	var m: Dictionary = meta
	var tessera: Variant = m.get("tessera", {})
	var t: Dictionary = tessera if tessera is Dictionary else {}
	var loops: Variant = t.get("loop", {})
	var loop_map: Dictionary = loops if loops is Dictionary else {}
	var tags: Variant = m.get("frameTags", null)
	if not (tags is Array):
		return null
	var sheet := new()
	sheet._image_path = image_path
	sheet._frame_size = rects[0].size
	sheet._image_size = _read_size(m.get("size", null))
	var facing := String(t.get("facing", DEFAULT_FACING))
	sheet._facing = facing if FACINGS.has(facing) else DEFAULT_FACING
	sheet._unit_id = String(t.get("unit", ""))
	for tag: Variant in tags:
		var clip_data := _parse_tag(tag, rects, durations, loop_map)
		if clip_data.is_empty():
			continue
		sheet._clips[String(clip_data["name"])] = clip_data
	if sheet._clips.is_empty():
		return null
	return sheet


## Drops every cached sheet (tests; a future hot reload).
static func clear_cache() -> void:
	_cache.clear()


## `res://assets/art/units/unit_<unit_id>_sheet.json`.
static func json_path(unit_id: String) -> String:
	return UNIT_DIR + SHEET_PREFIX + unit_id + SHEET_SUFFIX + ".json"


## `res://assets/art/units/unit_<unit_id>_sheet.png`.
static func image_path_for(unit_id: String) -> String:
	return UNIT_DIR + SHEET_PREFIX + unit_id + SHEET_SUFFIX + ".png"


## Data id of the unit (`kiem_si`, `goblin_scout`); from `load_unit` or `meta.tessera.unit`.
func unit_id() -> String:
	return _unit_id


## Direction the drawn unit faces: "right" (default) or "left". The drawer mirrors the sprite
## when its side needs the other direction.
func facing() -> String:
	return _facing


## Size of one frame in art px, read from the first frame (every frame of a unit shares it).
func frame_size() -> Vector2i:
	return _frame_size


## `meta.size` of the whole sheet image (zero when absent).
func image_size() -> Vector2i:
	return _image_size


## Path of the sheet PNG this sheet draws from.
func image_path() -> String:
	return _image_path


func has_clip(clip_name: String) -> bool:
	return _clips.has(clip_name)


## Clip names in frameTags order.
func clip_names() -> Array[String]:
	var names: Array[String] = []
	for key: Variant in _clips:
		names.append(String(key))
	return names


func clip_count() -> int:
	return _clips.size()


## The clip Dictionary, or `{}` when absent. Keys:
##   name: String, frames: Array[Rect2i] (source rects in sheet px, in play order),
##   durations_ms: Array[int] (one per frame; 0 = no own duration, held by code),
##   loop: String ("loop" | "once" | "hold_last" | "hold", from meta.tessera.loop).
func clip(clip_name: String) -> Dictionary:
	return _clips.get(clip_name, {})


## The sheet texture, resolved on the first call with `load()`. Null when the PNG is missing or
## not imported; never an error line.
func texture() -> Texture2D:
	if not _texture_tried:
		_texture_tried = true
		_texture = _load_texture(_image_path)
	return _texture


static func _read_size(data: Variant) -> Vector2i:
	if not (data is Dictionary):
		return Vector2i.ZERO
	var d: Dictionary = data
	return Vector2i(int(d.get("w", 0)), int(d.get("h", 0)))


## One frameTag -> clip Dictionary; `{}` when the tag is unnamed or its range is out of bounds.
static func _parse_tag(data: Variant, rects: Array[Rect2i], durations: Array[int], loop_map: Dictionary) -> Dictionary:
	if not (data is Dictionary):
		return {}
	var tag: Dictionary = data
	var clip_name := String(tag.get("name", ""))
	if clip_name.is_empty():
		return {}
	var from: int = int(tag.get("from", -1))
	var to: int = int(tag.get("to", -1))
	if from < 0 or to < from or to >= rects.size():
		return {}
	var frames: Array[Rect2i] = []
	var ms: Array[int] = []
	for i in range(from, to + 1):
		frames.append(rects[i])
		ms.append(durations[i])
	var loop_kind := String(loop_map.get(clip_name, DEFAULT_LOOP))
	if not LOOP_KINDS.has(loop_kind):
		loop_kind = DEFAULT_LOOP
	return {
		"name": clip_name,
		"frames": frames,
		"durations_ms": ms,
		"loop": loop_kind,
	}


## `load()` of the sheet PNG, guarded so a missing or un-imported file yields null quietly.
## An `.import` file alone is not enough: the imported `.ctex` it points at (`[remap] path=`)
## must exist too, or `load()` prints three errors per sheet in a headless run without import.
static func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return null
	var remap := _imported_path(import_path)
	if not remap.is_empty() and not FileAccess.file_exists(remap):
		return null
	return load(path) as Texture2D


## The `path="res://.godot/imported/...ctex"` entry of an `.import` file; "" when absent.
static func _imported_path(import_path: String) -> String:
	var file := FileAccess.open(import_path, FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("path=\""):
			return line.trim_prefix("path=\"").trim_suffix("\"")
	return ""

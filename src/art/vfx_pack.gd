class_name VfxPack
extends RefCounted
## PixelLab VFX game-pack loader. Story 047 Part D (art bible §8.5 overlays, §8.6 draw order,
## §8.10 whole-number placement only). Node-free: the owner (`UnitLayer`) keeps the clock and
## calls `draw_clip` from its own `_draw`, `behind` before the unit sprite and `front` after it.
##
## Manifest fields read (`<dir>/manifest.json`, PixelLab VFX Creator "game" export):
##   frame_ms, loop, canvas {w, h}, anchor {x, y},
##   clips[] { name, depth, frames, frame {w, h}, offset {x, y},
##             sheets[] { file, first_frame, frames, columns } }
## Frames run left to right, top to bottom in each sheet; `offset` is the frame's top-left
## relative to the unit's feet anchor. Only the first sheet of a clip is used (every shipped
## pack has one sheet per clip); a second sheet is reported with one warning.
##
## Textures are never loaded by `load_pack`: `clip()` resolves the sheet lazily with `load()`
## and leaves `texture` null when the PNG is missing or not imported, without an error line.

const MANIFEST_FILE := "manifest.json"
const DEFAULT_FRAME_MS := 83

var _dir: String = ""
var _frame_ms: int = DEFAULT_FRAME_MS
var _loop: bool = true
var _canvas: Vector2i = Vector2i.ZERO
var _anchor: Vector2i = Vector2i.ZERO
## clip name -> clip Dictionary (see `clip()` for the keys).
var _clips: Dictionary = {}
## clip name -> true once a texture load was attempted (so a missing sheet is tried once).
var _texture_tried: Dictionary = {}


## Loads `<dir>/manifest.json`. Null, with one warning, when the file is missing or malformed.
static func load_pack(dir: String) -> VfxPack:
	return load_manifest(dir.path_join(MANIFEST_FILE))


## Loads a manifest at an explicit path; sheet files resolve next to it.
static func load_manifest(path: String) -> VfxPack:
	if not FileAccess.file_exists(path):
		push_warning("VfxPack: no manifest at %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("VfxPack: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	var pack := parse_manifest(data, path.get_base_dir())
	if pack == null:
		push_warning("VfxPack: malformed manifest at %s" % path)
	return pack


## Builds a pack from already-parsed manifest data. Null (no warning) when `data` is not a
## Dictionary or yields no usable clip; `dir` is where the sheet files live.
static func parse_manifest(data: Variant, dir: String) -> VfxPack:
	if not (data is Dictionary):
		return null
	var m: Dictionary = data
	var clips: Variant = m.get("clips", null)
	if not (clips is Array):
		return null
	var pack := new()
	pack._dir = dir
	pack._frame_ms = maxi(1, int(m.get("frame_ms", DEFAULT_FRAME_MS)))
	pack._loop = bool(m.get("loop", true))
	pack._canvas = _read_size(m.get("canvas", null), "w", "h")
	pack._anchor = _read_size(m.get("anchor", null), "x", "y")
	for entry: Variant in clips:
		var clip_data := _parse_clip(entry)
		if clip_data.is_empty():
			continue
		pack._clips[String(clip_data["name"])] = clip_data
	if pack._clips.is_empty():
		return null
	return pack


## Directory the sheet files are resolved from.
func dir() -> String:
	return _dir


## Milliseconds per frame for every clip of the pack.
func frame_ms() -> int:
	return _frame_ms


## Whether the pack's clips repeat (top-level `loop`).
func is_loop() -> bool:
	return _loop


## Size of the effect's authoring canvas in art px.
func canvas_size() -> Vector2i:
	return _canvas


## Feet anchor on the authoring canvas (informational; offsets are already relative to it).
func anchor() -> Vector2i:
	return _anchor


func has_clip(clip_name: String) -> bool:
	return _clips.has(clip_name)


func clip_names() -> Array[String]:
	var names: Array[String] = []
	for key: Variant in _clips:
		names.append(String(key))
	return names


func clip_count() -> int:
	return _clips.size()


## The clip Dictionary, or `{}` when absent. Keys:
##   name: String, depth: String ("behind" | "front" | "both"), frames: int,
##   frame_size: Vector2i, offset: Vector2i (frame top-left relative to the feet),
##   regions: Array[Rect2i] (one source rect per frame), file: String,
##   texture: Texture2D (resolved on the first call; null when missing or not imported).
func clip(clip_name: String) -> Dictionary:
	if not _clips.has(clip_name):
		return {}
	var c: Dictionary = _clips[clip_name]
	if not _texture_tried.get(clip_name, false):
		_texture_tried[clip_name] = true
		c["texture"] = _load_texture(String(c["file"]))
	return c


## Frame index for a clip at `elapsed_sec` on a `frame_ms` clock: wraps when `loop`, otherwise
## holds the last frame. Pure; 0 for an empty clip or a non-positive frame time.
static func frame_at(clip_data: Dictionary, elapsed_sec: float, frame_ms_value: int, loop: bool) -> int:
	var frames: int = int(clip_data.get("frames", 0))
	if frames <= 0 or frame_ms_value <= 0:
		return 0
	var index: int = int(floor(maxf(elapsed_sec, 0.0) * 1000.0 / float(frame_ms_value)))
	if loop:
		return index % frames
	return mini(index, frames - 1)


## Draws frame `frame` of `clip_name` with its top-left at `feet + offset` (whole art px, no
## scaling). False, and nothing drawn, when the clip or its texture is unavailable; an
## out-of-range frame is clamped. [param modulate] tints the frame (Story 048: the hero-block cast target).
func draw_clip(canvas: CanvasItem, clip_name: String, feet: Vector2i, frame: int, modulate: Color = Color.WHITE, clip_rect: Rect2i = Rect2i()) -> bool:
	var c := clip(clip_name)
	if c.is_empty():
		return false
	var texture: Texture2D = c["texture"]
	if texture == null:
		return false
	var regions: Array[Rect2i] = c["regions"]
	if regions.is_empty():
		return false
	var index: int = clampi(frame, 0, regions.size() - 1)
	var position: Vector2i = feet + (c["offset"] as Vector2i)
	var size: Vector2i = c["frame_size"]
	var dst := Rect2i(position, size)
	var src: Rect2i = regions[index]
	# Story 048: [param clip_rect] (when it has an area) crops the frame to it, so a full-cell effect made on the
	# largest cell fits a smaller cell without scaling (art bible 8.10: no non-integer scaling).
	if clip_rect.has_area():
		var cut: Rect2i = dst.intersection(clip_rect)
		if not cut.has_area():
			return true
		src = Rect2i(src.position + (cut.position - dst.position), cut.size)
		dst = cut
	canvas.draw_texture_rect_region(texture, Rect2(dst), Rect2(src), modulate)
	return true


static func _read_size(data: Variant, key_x: String, key_y: String) -> Vector2i:
	if not (data is Dictionary):
		return Vector2i.ZERO
	var d: Dictionary = data
	return Vector2i(int(d.get(key_x, 0)), int(d.get(key_y, 0)))


## One manifest clip -> clip Dictionary; `{}` when a required field is missing or zero-sized.
static func _parse_clip(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return {}
	var c: Dictionary = data
	var clip_name := String(c.get("name", ""))
	if clip_name.is_empty():
		return {}
	var frame_size := _read_size(c.get("frame", null), "w", "h")
	if frame_size.x <= 0 or frame_size.y <= 0:
		return {}
	var sheets: Variant = c.get("sheets", null)
	if not (sheets is Array):
		return {}
	var sheet_list: Array = sheets
	if sheet_list.is_empty() or not (sheet_list[0] is Dictionary):
		return {}
	var sheet: Dictionary = sheet_list[0]
	var file := String(sheet.get("file", ""))
	if file.is_empty():
		return {}
	if sheet_list.size() > 1:
		push_warning("VfxPack: clip %s has %d sheets; only %s is used" % [clip_name, sheet_list.size(), file])
	var clip_frames: int = int(c.get("frames", 0))
	var first_frame: int = maxi(0, int(sheet.get("first_frame", 0)))
	var sheet_frames: int = int(sheet.get("frames", clip_frames))
	var count: int = clampi(sheet_frames, 0, maxi(0, clip_frames - first_frame))
	var columns: int = maxi(1, int(sheet.get("columns", 1)))
	var regions: Array[Rect2i] = []
	for i in count:
		@warning_ignore("integer_division")
		var row: int = i / columns
		regions.append(Rect2i((i % columns) * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y))
	if regions.is_empty():
		return {}
	return {
		"name": clip_name,
		"depth": String(c.get("depth", "both")),
		"frames": regions.size(),
		"frame_size": frame_size,
		"offset": _read_size(c.get("offset", null), "x", "y"),
		"regions": regions,
		"file": file,
		"texture": null,
	}


## `load()` of a sheet, guarded so a missing or un-imported PNG yields null without an error.
func _load_texture(file: String) -> Texture2D:
	var path := _dir.path_join(file)
	if not FileAccess.file_exists(path):
		return null
	if not FileAccess.file_exists(path + ".import") and not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D

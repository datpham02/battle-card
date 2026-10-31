class_name StatusPacks
extends RefCounted
## Static, cached access to the status overlay packs (Story 047 Part D; ASSET-017..020).
## `assets/art/vfx/status/index.json` maps status kind -> unit frame kind -> pack directory,
## so a designer can repoint a pack without touching code. A missing index or pack yields
## null, warned once per key, never a crash; callers keep their fallback draw path.
##
## `vfx_pack.gd` is referenced by preload so this file parses before the global class cache
## has been rebuilt; the type is the same `VfxPack`.

const STATUS_DIR := "res://assets/art/vfx/status"
const INDEX_FILE := "index.json"
const VfxPackScript := preload("res://src/art/vfx_pack.gd")

static var _index: Dictionary = {}
static var _index_loaded: bool = false
## "<kind>/<frame_kind>" -> VfxPack or null (null is cached so a missing pack warns once).
static var _cache: Dictionary = {}


## The pack for `kind` (burn | frozen | chill) on `frame_kind` (hero | goblin); null when the
## index has no entry or the pack fails to load.
static func pack(kind: String, frame_kind: String) -> VfxPackScript:
	var key := kind + "/" + frame_kind
	if _cache.has(key):
		return _cache[key]
	var result: VfxPackScript = null
	var sub_dir := pack_dir_name(kind, frame_kind)
	if not sub_dir.is_empty():
		result = VfxPackScript.load_pack(STATUS_DIR.path_join(sub_dir))
	_cache[key] = result
	return result


## Directory name the index assigns to the pair, or "" when unmapped.
static func pack_dir_name(kind: String, frame_kind: String) -> String:
	_ensure_index()
	var by_frame: Variant = _index.get(kind, null)
	if not (by_frame is Dictionary):
		return ""
	return String((by_frame as Dictionary).get(frame_kind, ""))


## Status kinds the index knows about.
static func kinds() -> Array[String]:
	_ensure_index()
	var out: Array[String] = []
	for key: Variant in _index:
		out.append(String(key))
	return out


## Drops every cached pack and the index so the next call re-reads from disk.
static func clear_cache() -> void:
	_cache.clear()
	_index.clear()
	_index_loaded = false


static func _ensure_index() -> void:
	if _index_loaded:
		return
	_index_loaded = true
	var path := STATUS_DIR.path_join(INDEX_FILE)
	if not FileAccess.file_exists(path):
		push_warning("StatusPacks: no index at %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("StatusPacks: cannot open %s" % path)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		push_warning("StatusPacks: malformed index at %s" % path)
		return
	_index = data

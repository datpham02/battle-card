class_name PieceLibrary
extends RefCounted
## The set of piece shapes, loaded from assets/data/pieces.json, plus the per-chapter drop
## weights. Never null from the loaders: a missing or broken file gives a warning and a built-in
## minimal library holding only the mono shape (a documented fallback mirroring the JSON entry).
## Schema: assets/data/schema.md. Implements: Story 024 (Part A).

const DEFAULT_PATH: String = "res://assets/data/pieces.json"
## Largest shape pieces.json may hold (cards never need more; see story 024). Story 041: runtime odd
## pieces ([OddBlock]) may be bigger (6-7 cells); only the library's own shapes obey this limit.
const MAX_CELLS: int = 5
const _FALLBACK_ID: String = "mono"
const _FALLBACK_NAME_KEY: String = "piece.mono.name"
## Weight used for a shape that appears in neither the chapter map nor the default map.
const _UNLISTED_WEIGHT: float = 1.0
## Story 034: pool names. A run_only shape only enters the player's deck through Ink.
const POOL_DEFAULT: String = "default"
const POOL_RUN_ONLY: String = "run_only"

var _ids: Array[String] = []
var _cells: Dictionary = {} # id -> Array[Vector2i] (normalised, sorted)
var _name_keys: Dictionary = {} # id -> String
var _pools: Dictionary = {} # id -> "default" | "run_only" (Story 034)
var _weights: Dictionary = {} # chapter id or "default" -> {shape id -> float}
# Story 041: Piece.canonical_key of every shape (both pools) -> true; built on first use.
var _canonical_keys: Dictionary = {}
var _canonical_built: bool = false


## Loads from a JSON file; falls back to the mono-only library (warning) when missing or bad.
static func load_from_file(path: String = DEFAULT_PATH) -> PieceLibrary:
	if not FileAccess.file_exists(path):
		push_warning("PieceLibrary: file not found, using the mono-only fallback: %s" % path)
		return _fallback()
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds from JSON text; falls back like [method load_from_file].
static func from_json_text(text: String) -> PieceLibrary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("PieceLibrary: JSON root must be an object, using the mono-only fallback")
		return _fallback()
	return from_dictionary(parsed as Dictionary)


## Builds from a dictionary {shapes: [{id, cells, name_key}], weights: {default: {...}, <chapter>: {...}}}.
## Invalid shapes (bad cells, not edge-connected, 0 or > 5 cells, duplicate id) are dropped with
## a warning; if none survive the mono-only fallback is returned.
static func from_dictionary(data: Dictionary) -> PieceLibrary:
	var lib := PieceLibrary.new()
	var shapes: Variant = data.get("shapes", [])
	if typeof(shapes) == TYPE_ARRAY:
		for entry: Variant in shapes as Array:
			lib._add_shape(entry)
	else:
		push_warning("PieceLibrary: 'shapes' must be an array")
	if lib._ids.is_empty():
		push_warning("PieceLibrary: no valid shape, using the mono-only fallback")
		return _fallback()
	lib._read_weights(data.get("weights", {}))
	return lib


## Shape ids in file order.
func shape_ids() -> Array[String]:
	return _ids.duplicate()


## True when [param id] is a known shape.
func has_shape(id: String) -> bool:
	return _cells.has(id)


## Unrotated cells of shape [param id] (normalised, sorted); empty for an unknown id.
func shape_cells(id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _cells.has(id):
		out.assign(_cells[id])
	return out


## Translation key of the shape's name (e.g. "piece.mono.name"); empty for an unknown id.
func name_key(id: String) -> String:
	return str(_name_keys.get(id, ""))


## Drop weight of shape [param id] in chapter [param chapter_id]: the chapter's own map first,
## then the `default` map, then 1.0 when listed in neither. Never negative; 0 = never drops.
## Story 034: a run_only shape is always 0 here (it has no table weight; the player's deck gives
## it one), so it never drops for the boss or in a match without a run.
func weight(id: String, chapter_id: String) -> float:
	if is_run_only(id):
		return 0.0
	for key: String in [chapter_id, "default"]:
		var map: Variant = _weights.get(key)
		if map is Dictionary and (map as Dictionary).has(id):
			return maxf(float((map as Dictionary)[id]), 0.0)
	return _UNLISTED_WEIGHT


## Story 034: pool of shape [param id], "default" or "run_only"; empty for an unknown id.
func pool(id: String) -> String:
	return str(_pools.get(id, ""))


## Story 034: true when [param id] is a known shape of the run_only pool.
func is_run_only(id: String) -> bool:
	return str(_pools.get(id, "")) == POOL_RUN_ONLY


## Story 034: ids of the default pool, in file order.
func base_shape_ids() -> Array[String]:
	return _ids_in_pool(POOL_DEFAULT)


## Story 034: ids of the run_only pool, in file order.
func run_only_ids() -> Array[String]:
	return _ids_in_pool(POOL_RUN_ONLY)


## A new piece of shape [param id] turned [param rotation] quarter turns, or null (with a
## warning) for an unknown id.
func make_piece(id: String, rotation: int = 0) -> Piece:
	if not _cells.has(id):
		push_warning("PieceLibrary: unknown shape '%s'" % id)
		return null
	return Piece.make(id, shape_cells(id), rotation)


## Story 041: true when [param cells] (any offset) equal one of this library's shapes (default AND
## run_only pools) under some 90-degree rotation (no mirroring), compared by [method Piece.canonical_key].
func has_equivalent_shape(cells: Array[Vector2i]) -> bool:
	if not _canonical_built:
		_canonical_built = true
		for id: String in _ids:
			_canonical_keys[Piece.canonical_key(shape_cells(id))] = true
	return _canonical_keys.has(Piece.canonical_key(cells))


static func _fallback() -> PieceLibrary:
	var lib := PieceLibrary.new()
	lib._ids.append(_FALLBACK_ID)
	lib._cells[_FALLBACK_ID] = [Vector2i.ZERO] as Array[Vector2i]
	lib._name_keys[_FALLBACK_ID] = _FALLBACK_NAME_KEY
	lib._pools[_FALLBACK_ID] = POOL_DEFAULT
	lib._weights["default"] = {_FALLBACK_ID: 1.0}
	return lib


func _add_shape(entry: Variant) -> void:
	if typeof(entry) != TYPE_DICTIONARY:
		push_warning("PieceLibrary: a shape entry is not an object, dropped")
		return
	var d: Dictionary = entry
	var id: String = str(d.get("id", ""))
	if id.is_empty() or id == Piece.ROTTEN_ID or _cells.has(id):
		push_warning("PieceLibrary: shape id '%s' is empty, reserved or duplicate, dropped" % id)
		return
	var raw: Variant = d.get("cells", [])
	var cells: Array[Vector2i] = []
	if typeof(raw) == TYPE_ARRAY:
		for item: Variant in raw as Array:
			if typeof(item) != TYPE_ARRAY or (item as Array).size() != 2:
				push_warning("PieceLibrary: shape '%s' has a malformed cell, dropped" % id)
				return
			var cell := Vector2i(int((item as Array)[0]), int((item as Array)[1]))
			if cells.has(cell):
				push_warning("PieceLibrary: shape '%s' repeats cell %s, dropped" % [id, cell])
				return
			cells.append(cell)
	if cells.is_empty() or cells.size() > MAX_CELLS:
		push_warning("PieceLibrary: shape '%s' needs 1..%d cells, dropped" % [id, MAX_CELLS])
		return
	var normalised: Array[Vector2i] = Piece.make(id, cells).relative_cells()
	if not _is_connected(normalised):
		push_warning("PieceLibrary: shape '%s' is not edge-connected, dropped" % id)
		return
	_ids.append(id)
	_cells[id] = normalised
	_name_keys[id] = str(d.get("name_key", "piece.%s.name" % id))
	var pool_name: String = str(d.get("pool", POOL_DEFAULT))
	if pool_name != POOL_DEFAULT and pool_name != POOL_RUN_ONLY:
		push_warning("PieceLibrary: shape '%s' has unknown pool '%s', using default" % [id, pool_name])
		pool_name = POOL_DEFAULT
	_pools[id] = pool_name


func _ids_in_pool(pool_name: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in _ids:
		if str(_pools.get(id, POOL_DEFAULT)) == pool_name:
			out.append(id)
	return out


func _read_weights(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key: Variant in (raw as Dictionary).keys():
		var map: Variant = (raw as Dictionary)[key]
		if typeof(map) != TYPE_DICTIONARY:
			push_warning("PieceLibrary: weights.%s must be an object, ignored" % key)
			continue
		var clean: Dictionary = {}
		for shape: Variant in (map as Dictionary).keys():
			if not _cells.has(str(shape)):
				push_warning("PieceLibrary: weights.%s names unknown shape '%s', ignored" % [key, shape])
				continue
			clean[str(shape)] = maxf(float((map as Dictionary)[shape]), 0.0)
		_weights[str(key)] = clean


static func _is_connected(cells: Array[Vector2i]) -> bool:
	var seen: Array[Vector2i] = [cells[0]]
	var frontier: Array[Vector2i] = [cells[0]]
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_back()
		for step: Vector2i in steps:
			var next: Vector2i = cur + step
			if cells.has(next) and not seen.has(next):
				seen.append(next)
				frontier.append(next)
	return seen.size() == cells.size()

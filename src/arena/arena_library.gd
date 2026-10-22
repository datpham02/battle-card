class_name ArenaLibrary
extends RefCounted
## Named arena shapes loaded from assets/data/arenas.json. Every shape is validated at load;
## invalid ones are dropped with a warning naming the reasons. Never null after
## [method load_from_file]: a bad or missing file yields a library with just `square`.
## Schema: assets/data/schema.md. Implements: Story 014.

const DEFAULT_PATH: String = "res://assets/data/arenas.json"
## Id of the built-in shape used when the file is unusable.
const FALLBACK_ID: String = "square"
const FALLBACK_SIDE: int = 3

## Rules block of the file (min_cells_per_side, variant_*); see ArenaValidator / ArenaVariants.
var rules: Dictionary = {}
var _shapes: Array[Dictionary] = []


## Loads and validates the file (never null; see the class doc).
static func load_from_file(path: String = DEFAULT_PATH) -> ArenaLibrary:
	if not FileAccess.file_exists(path):
		push_warning("ArenaLibrary: file not found, using the built-in square: %s" % path)
		return _fallback()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ArenaLibrary: JSON root must be an object, using the built-in square")
		return _fallback()
	var data: Dictionary = parsed as Dictionary
	var library := ArenaLibrary.new()
	var raw_rules: Variant = data.get("rules", {})
	if typeof(raw_rules) == TYPE_DICTIONARY:
		library.rules = (raw_rules as Dictionary).duplicate()
	else:
		push_warning("ArenaLibrary: rules must be an object, using defaults")
	var raw_shapes: Variant = data.get("shapes")
	if typeof(raw_shapes) == TYPE_ARRAY:
		for entry: Variant in raw_shapes as Array:
			library._add_checked(entry)
	if library._shapes.is_empty():
		push_warning("ArenaLibrary: no valid shapes, using the built-in square")
		var fallback: ArenaLibrary = _fallback()
		fallback.rules = library.rules
		return fallback
	return library


## The shape with [param id] (a copy), or an empty dictionary when unknown.
func get_shape(id: String) -> Dictionary:
	for shape: Dictionary in _shapes:
		if str(shape["id"]) == id:
			return shape.duplicate(true)
	return {}


## Ids of the valid shapes, in file order.
func shape_ids() -> Array[String]:
	var ids: Array[String] = []
	for shape: Dictionary in _shapes:
		ids.append(str(shape["id"]))
	return ids


## Copies of the valid shapes with difficulty <= [param max_difficulty].
func shapes_with_difficulty(max_difficulty: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shape: Dictionary in _shapes:
		if int(shape["difficulty"]) <= max_difficulty:
			result.append(shape.duplicate(true))
	return result


## Builds the board for a chapters.json `arena` block (floor or match level): {shape: id}, {shape: id, variant: true} or a
## direct {side_cols, side_rows, missing_cells}. Returns null (with a warning) for an unknown id
## or an invalid direct block, so the caller keeps its own grid. [param seed_value] drives variants.
static func grid_for_spec(spec: Dictionary, library: ArenaLibrary, seed_value: int) -> BoardGrid:
	var shape: Dictionary = {}
	if spec.has("shape"):
		shape = library.get_shape(str(spec["shape"]))
		if shape.is_empty():
			push_warning("ArenaLibrary: unknown arena shape '%s', keeping the combat.json board" % str(spec["shape"]))
			return null
		if bool(spec.get("variant", false)):
			shape = ArenaVariants.make(shape, library.rules, seed_value)
	elif spec.has("side_cols") and spec.has("side_rows"):
		shape = spec.duplicate(true)
		var verdict: Dictionary = ArenaValidator.validate(shape, library.rules)
		if not bool(verdict["ok"]):
			push_warning("ArenaLibrary: invalid direct arena (%s), keeping the combat.json board" % "; ".join(verdict["reasons"]))
			return null
	else:
		push_warning("ArenaLibrary: arena block has neither shape nor side_cols/side_rows, ignored")
		return null
	return ArenaValidator.build_grid(shape)


static func _fallback() -> ArenaLibrary:
	var library := ArenaLibrary.new()
	library._shapes.append({
		"id": FALLBACK_ID, "name_key": "arena.%s.name" % FALLBACK_ID, "side_cols": FALLBACK_SIDE,
		"side_rows": FALLBACK_SIDE, "missing_cells": [], "difficulty": 1,
	})
	return library


func _add_checked(entry: Variant) -> void:
	if typeof(entry) != TYPE_DICTIONARY:
		push_warning("ArenaLibrary: a shape entry is not an object, dropped")
		return
	var raw: Dictionary = entry as Dictionary
	var id: String = str(raw.get("id", ""))
	if id.is_empty() or not get_shape(id).is_empty():
		push_warning("ArenaLibrary: shape with empty or duplicate id '%s' dropped" % id)
		return
	var shape: Dictionary = {
		"id": id, "name_key": str(raw.get("name_key", "arena.%s.name" % id)),
		"side_cols": int(raw.get("side_cols", 0)), "side_rows": int(raw.get("side_rows", 0)),
		"missing_cells": (raw.get("missing_cells", []) as Array).duplicate(true) if typeof(raw.get("missing_cells", [])) == TYPE_ARRAY else [],
		"difficulty": clampi(int(raw.get("difficulty", 1)), 1, 5),
	}
	var verdict: Dictionary = ArenaValidator.validate(shape, rules)
	if bool(verdict["ok"]):
		_shapes.append(shape)
	else:
		push_warning("ArenaLibrary: shape '%s' dropped: %s" % [id, "; ".join(verdict["reasons"])])

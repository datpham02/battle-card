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
## Story 028 rules of the featured shape (not tuning numbers): its size in cells and the bonus effects.
const FEATURED_MIN_CELLS: int = 5
const FEATURED_MAX_CELLS: int = 7
const FEATURED_EFFECTS: Array[String] = ["fragile", "pin", "burn", "frost"]
## Story 036 rule of the featured shape: it must be buildable from at least this many DISTINCT piece pairs.
const FEATURED_MIN_PAIRS: int = 2

## Rules block of the file (min_cells_per_side, variant_*); see ArenaValidator / ArenaVariants.
var rules: Dictionary = {}
var _shapes: Array[Dictionary] = []
## Library behind [method hazards_for_match] when the caller passes none (loaded once, arenas.json).
static var _default_library: ArenaLibrary = null


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


## Story 036: the tile hazards of one match on [param grid] (the board built for it):
## {mire_player: Array[Vector2i], mire_enemy: Array[Vector2i], sand: bool, wind: bool}; Story 039 adds vents_player /
## vents_enemy (Array of Array[Vector2i], one array of cells per vent) and crumble (bool). The hazards come from the
## arena block of [param match_params] (`arena.shape` looked up in [param library], default arenas.json; a direct
## arena block may carry its own `hazards` / `wind`). All empty / false for an arena without hazards.
## `hazards.mire` is either {per_side: N} (N cells on EACH half, seeded by the match's `arena_seed`, never the
## unit start cell, never a missing cell, at most half of the half, the start cell always keeps a mire-free
## neighbour) or {player: [[c, r], ...], enemy: [[c, r], ...]} in side coordinates (cells that are not on the
## grid or are a start cell are dropped). Cells are BoardGrid cell coordinates of the right half.
static func hazards_for_match(match_params: Dictionary, grid: BoardGrid, library: ArenaLibrary = null) -> Dictionary:
	var no_cells: Array[Vector2i] = []
	var result: Dictionary = {"mire_player": no_cells.duplicate(), "mire_enemy": no_cells.duplicate(), "sand": false, "wind": false,
		"vents_player": [], "vents_enemy": [], "crumble": false}
	var arena: Variant = match_params.get("arena")
	if typeof(arena) != TYPE_DICTIONARY or grid == null:
		return result
	var spec: Dictionary = arena as Dictionary
	var shape: Dictionary = {}
	if spec.has("shape"):
		var lib: ArenaLibrary = library
		if lib == null:
			if _default_library == null:
				_default_library = load_from_file()
			lib = _default_library
		shape = lib.get_shape(str(spec["shape"]))
	else:
		shape = spec
	if shape.is_empty():
		return result
	result["wind"] = bool(shape.get("wind", false))
	# Story 039: `crumble` of the shape; a match-level arena block naming a shape may switch it on (or off) for this match.
	result["crumble"] = bool(spec.get("crumble", shape.get("crumble", false))) if spec.has("shape") else bool(shape.get("crumble", false))
	var raw_hazards: Variant = shape.get("hazards")
	if typeof(raw_hazards) != TYPE_DICTIONARY:
		return result
	var hazards: Dictionary = raw_hazards as Dictionary
	result["sand"] = bool(hazards.get("sand", false))
	var vents: Variant = hazards.get("vents")
	if typeof(vents) == TYPE_DICTIONARY:
		result["vents_player"] = _vents_side(vents as Dictionary, grid, true)
		result["vents_enemy"] = _vents_side(vents as Dictionary, grid, false)
	var mire: Variant = hazards.get("mire")
	if typeof(mire) == TYPE_DICTIONARY:
		var arena_seed: int = maxi(int(match_params.get("arena_seed", -1)), 0)
		result["mire_player"] = _mire_side(mire as Dictionary, grid, true, arena_seed)
		result["mire_enemy"] = _mire_side(mire as Dictionary, grid, false, arena_seed)
	return result


## Story 039: the vents of one half: one Array[Vector2i] per `hazards.vents.<player|enemy>` line ({"row": r} or
## {"col": c} in side coordinates), holding every real cell of that half on the line; a line without a real cell is dropped.
static func _vents_side(vents: Dictionary, grid: BoardGrid, player_half: bool) -> Array:
	var out: Array = []
	var key: String = "player" if player_half else "enemy"
	if typeof(vents.get(key)) != TYPE_ARRAY:
		return out
	for line: Variant in vents[key] as Array:
		var cells: Array[Vector2i] = ArenaValidator.vent_line_cells(grid, line, player_half)
		if not cells.is_empty():
			out.append(cells)
	return out


## Mire cells of one half (see [method hazards_for_match]).
static func _mire_side(mire: Dictionary, grid: BoardGrid, player_half: bool, arena_seed: int) -> Array[Vector2i]:
	var half: Array[Vector2i] = grid.player_cells() if player_half else grid.enemy_cells()
	var start: Vector2i = grid.default_player_cell() if player_half else grid.default_enemy_cell()
	var cap: int = half.size() / 2
	var picked: Array[Vector2i] = []
	var key: String = "player" if player_half else "enemy"
	if mire.has(key) and typeof(mire[key]) == TYPE_ARRAY:
		for item: Variant in mire[key] as Array:
			if typeof(item) != TYPE_ARRAY or (item as Array).size() != 2:
				continue
			var cell := Vector2i(int((item as Array)[0]), int((item as Array)[1]))
			if not player_half:
				cell = Vector2i(grid.total_cols - 1 - cell.x, cell.y)
			var with_cell: Array[Vector2i] = picked.duplicate()
			with_cell.append(cell)
			if half.has(cell) and cell != start and not picked.has(cell) and picked.size() < cap \
					and ArenaValidator.leaves_path(grid, start, with_cell, player_half):
				picked.append(cell)
		return picked
	var want: int = mini(maxi(int(mire.get("per_side", 0)), 0), cap)
	if want <= 0:
		return picked
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([arena_seed, key]) & 0x7fffffff
	var pool: Array[Vector2i] = []
	for cell: Vector2i in half:
		if cell != start:
			pool.append(cell)
	while picked.size() < want and not pool.is_empty():
		var cell: Vector2i = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var with_cell: Array[Vector2i] = picked.duplicate()
		with_cell.append(cell)
		if ArenaValidator.leaves_path(grid, start, with_cell, player_half):
			picked.append(cell)
	return picked


## Story 028: the featured shape (hinh chu dao) of the arena shape [param shape_id] as
## {cells: Array[Vector2i] (normalised, sorted), bonus: {damage_mult, effect, stacks, sec, ...}};
## an empty dictionary when the shape is unknown or defines none (the feature is then off).
func featured_for_shape(shape_id: String) -> Dictionary:
	var shape: Dictionary = get_shape(shape_id)
	if shape.is_empty() or not shape.has("featured_shape") or not shape.has("featured_bonus"):
		return {}
	var cells: Array[Vector2i] = parse_featured_cells(shape["featured_shape"])
	return {"cells": cells, "bonus": (shape["featured_bonus"] as Dictionary).duplicate(true)}


## Story 028: the featured shape of a chapters.json match dictionary. The shape comes from the
## match's `arena.shape` (see CombatView._apply_arena); the match's own `featured_shape` (array of
## [x, y]) and `featured_bonus` (keys override the shape's bonus one by one) win when valid.
## When [param grid] is given and the featured shape has no valid placement on its enemy half
## in any of the 4 rotations (a variant too small), the feature is off for this match.
## Returns {cells, bonus} like [method featured_for_shape] or an empty dictionary (feature off).
func featured_for_match(match_dict: Dictionary, grid: BoardGrid = null) -> Dictionary:
	var base: Dictionary = {}
	var arena: Variant = match_dict.get("arena")
	if typeof(arena) == TYPE_DICTIONARY and (arena as Dictionary).has("shape"):
		base = featured_for_shape(str((arena as Dictionary)["shape"]))
	var cells: Array[Vector2i] = []
	if base.has("cells"):
		cells.assign(base["cells"])
	if match_dict.has("featured_shape"):
		var own: Array[Vector2i] = parse_featured_cells(match_dict["featured_shape"])
		if own.is_empty():
			push_warning("ArenaLibrary: match featured_shape is invalid (5-7 edge-connected cells), ignored")
		else:
			cells = own
	var raw_bonus: Dictionary = (base["bonus"] as Dictionary).duplicate(true) if base.has("bonus") else {}
	var override: Variant = match_dict.get("featured_bonus")
	if typeof(override) == TYPE_DICTIONARY:
		for key: Variant in (override as Dictionary).keys():
			raw_bonus[key] = (override as Dictionary)[key]
	var bonus: Dictionary = parse_featured_bonus(raw_bonus)
	if cells.is_empty() or bonus.is_empty():
		return {}
	if grid != null and not PiecePlacement.has_any_placement(grid, Piece.make("featured", cells)):
		return {}
	return {"cells": cells, "bonus": bonus}


## Parses a `featured_shape` value ([[x, y], ...]). Returns the normalised, sorted cells, or an
## empty array when malformed, outside FEATURED_MIN_CELLS..FEATURED_MAX_CELLS or not edge-connected.
static func parse_featured_cells(raw: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if typeof(raw) != TYPE_ARRAY:
		return cells
	for item: Variant in raw as Array:
		if typeof(item) != TYPE_ARRAY or (item as Array).size() != 2:
			return [] as Array[Vector2i]
		cells.append(Vector2i(int((item as Array)[0]), int((item as Array)[1])))
	var norm: Array[Vector2i] = FeaturedShape.normalize(cells)
	if norm.size() != cells.size() or norm.size() < FEATURED_MIN_CELLS or norm.size() > FEATURED_MAX_CELLS:
		return [] as Array[Vector2i]
	var seen: Array[Vector2i] = [norm[0]]
	var frontier: Array[Vector2i] = [norm[0]]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cur + step
			if norm.has(next) and not seen.has(next):
				seen.append(next)
				frontier.append(next)
	return norm if seen.size() == norm.size() else ([] as Array[Vector2i])


## Parses a `featured_bonus` value into {damage_mult (>= 0), effect, stacks (>= 0), sec (>= 0)}
## (plus the optional burn_duration_sec / burn_tick_sec / burn_damage_per_tick when present).
## Empty when [param raw] is not an object or its effect is not in FEATURED_EFFECTS.
static func parse_featured_bonus(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = raw as Dictionary
	var effect: String = str(d.get("effect", ""))
	if not FEATURED_EFFECTS.has(effect):
		return {}
	var out: Dictionary = {
		"damage_mult": maxf(float(d.get("damage_mult", 1.0)), 0.0), "effect": effect,
		"stacks": maxi(int(d.get("stacks", 0)), 0), "sec": maxf(float(d.get("sec", 0.0)), 0.0),
	}
	for key: String in ["burn_duration_sec", "burn_tick_sec", "burn_damage_per_tick"]:
		if d.has(key):
			out[key] = maxf(float(d[key]), 0.0)
	return out


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
	# Story 036: tile hazards of the arena (checked by ArenaValidator together with the rest of the shape).
	if raw.has("hazards"):
		shape["hazards"] = (raw["hazards"] as Dictionary).duplicate(true) if typeof(raw["hazards"]) == TYPE_DICTIONARY else raw["hazards"]
	if raw.has("wind"):
		shape["wind"] = raw["wind"]
	if raw.has("crumble"):
		shape["crumble"] = raw["crumble"]
	var verdict: Dictionary = ArenaValidator.validate(shape, rules)
	if bool(verdict["ok"]):
		if raw.has("featured_shape") or raw.has("featured_bonus"):
			var cells: Array[Vector2i] = parse_featured_cells(raw.get("featured_shape"))
			var bonus: Dictionary = parse_featured_bonus(raw.get("featured_bonus"))
			var pair_reasons: Array[String] = ArenaValidator.featured_reasons(cells, FEATURED_MIN_PAIRS) if not cells.is_empty() else []
			if cells.is_empty() or bonus.is_empty():
				push_warning("ArenaLibrary: shape '%s' has an invalid featured_shape / featured_bonus, feature off for it" % id)
			elif not pair_reasons.is_empty():
				push_warning("ArenaLibrary: shape '%s' featured_shape rejected: %s" % [id, "; ".join(pair_reasons)])
			else:
				var raw_cells: Array = []
				for cell: Vector2i in cells:
					raw_cells.append([cell.x, cell.y])
				shape["featured_shape"] = raw_cells
				shape["featured_bonus"] = bonus
		_shapes.append(shape)
	else:
		push_warning("ArenaLibrary: shape '%s' dropped: %s" % [id, "; ".join(verdict["reasons"])])

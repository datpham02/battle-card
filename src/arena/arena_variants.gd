class_name ArenaVariants
extends RefCounted
## Pure, seeded variant generator: from a base shape, toggles a few holes and maybe flips it
## vertically; the first candidate that passes [ArenaValidator] and differs from the base wins.
## Implements: Story 014 (variants).

## Fallbacks used only when [param rules] lacks the key (arenas.json normally supplies them).
const FALLBACK_MAX_ATTEMPTS: int = 20
const FALLBACK_CHANGE_MIN: int = 1
const FALLBACK_CHANGE_MAX: int = 3
## Probability of flipping rows (vertical mirror) per candidate.
const FLIP_CHANCE: float = 0.5


## Returns a variant of [param base] (same keys plus `variant_of` = the base id). Never
## mutates the input. When no valid, different candidate is found within
## `variant_max_attempts` tries the base is returned unchanged (warning), still with `variant_of`.
static func make(base: Dictionary, rules: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var attempts: int = maxi(int(rules.get("variant_max_attempts", FALLBACK_MAX_ATTEMPTS)), 1)
	var change_min: int = maxi(int(rules.get("variant_change_min", FALLBACK_CHANGE_MIN)), 1)
	var change_max: int = maxi(int(rules.get("variant_change_max", FALLBACK_CHANGE_MAX)), change_min)
	var side_cols: int = int(base.get("side_cols", 1))
	var side_rows: int = int(base.get("side_rows", 1))
	var base_holes: Array[Vector2i] = ArenaValidator.parse_cells(base.get("missing_cells"))
	var base_key: Array[Vector2i] = _sorted(base_holes)
	for attempt: int in attempts:
		var holes: Array[Vector2i] = base_holes.duplicate()
		for i: int in rng.randi_range(change_min, change_max):
			var cell := Vector2i(rng.randi_range(0, side_cols - 1), rng.randi_range(0, side_rows - 1))
			if holes.has(cell):
				holes.erase(cell)
			else:
				holes.append(cell)
		if rng.randf() < FLIP_CHANCE:
			var flipped: Array[Vector2i] = []
			for cell: Vector2i in holes:
				flipped.append(Vector2i(cell.x, side_rows - 1 - cell.y))
			holes = flipped
		if _sorted(holes) == base_key:
			continue
		var candidate: Dictionary = _spec_with(base, holes)
		if bool(ArenaValidator.validate(candidate, rules).get("ok", false)):
			return candidate
	push_warning("ArenaVariants: no valid variant of '%s' in %d tries, using the base shape" % [base.get("id", "?"), attempts])
	return _spec_with(base, base_holes)


static func _spec_with(base: Dictionary, holes: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	var cells: Array = []
	for cell: Vector2i in _sorted(holes):
		cells.append([cell.x, cell.y])
	result["missing_cells"] = cells
	result["variant_of"] = str(base.get("id", ""))
	return result


static func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = cells.duplicate()
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result

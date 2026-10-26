class_name PieceDeckConfig
extends RefCounted
## Tuning of the player's piece deck (Story 034), read from the `piece_rewards` block of
## assets/data/rewards.json. Schema: assets/data/schema.md. The built-in defaults below mirror the
## JSON (documented fallback); a missing file/key or a bad value keeps the default with a warning.
## Implements: Story 034 (design/game-brief.md, "Bo manh").

const DEFAULT_PATH: String = "res://assets/data/rewards.json"
const BLOCK_KEY: String = "piece_rewards"

## Chance (0..1) that a won battle/danger node also offers an Ink row.
var ink_offer_chance: float = 0.35
## Shapes shown in one Ink offer.
var ink_offer_count: int = 2
## `mult` gained per Ink of an already-owned shape.
var mult_step: float = 1.0
## Ceiling of `mult`; a shape at the ceiling is not offered.
var mult_max: float = 4.0
## Removing is refused when fewer than this many shapes would stay active.
var min_shapes: int = 5
## Base drop weight of a run_only shape (they have no entry in pieces.json weights).
var run_only_weight: float = 6.0
## Shape-removal tokens at the start of a run.
var shape_removals_start: int = 1
## Extra shape-removal tokens per region boss.
var shape_removals_per_boss: int = 1


## Loads from rewards.json (the `piece_rewards` block); defaults with a warning when missing or bad.
static func load_from_file(path: String = DEFAULT_PATH) -> PieceDeckConfig:
	if not FileAccess.file_exists(path):
		push_warning("PieceDeckConfig: file not found, using defaults: %s" % path)
		return PieceDeckConfig.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("PieceDeckConfig: JSON root must be an object, using defaults")
		return PieceDeckConfig.new()
	return from_dictionary(parsed as Dictionary)


## Builds from a dictionary: either the `piece_rewards` block itself or a whole rewards.json
## object holding that block. Missing keys keep defaults; a wrongly typed or out-of-range value
## keeps the default with a warning.
static func from_dictionary(data: Dictionary) -> PieceDeckConfig:
	var c := PieceDeckConfig.new()
	var block: Dictionary = data
	if data.has(BLOCK_KEY):
		var inner: Variant = data[BLOCK_KEY]
		if typeof(inner) != TYPE_DICTIONARY:
			push_warning("PieceDeckConfig: '%s' must be an object, using defaults" % BLOCK_KEY)
			return c
		block = inner as Dictionary
	c.ink_offer_chance = _number(block, "ink_offer_chance", c.ink_offer_chance, 0.0, 1.0)
	c.ink_offer_count = int(_number(block, "ink_offer_count", float(c.ink_offer_count), 0.0, 100.0))
	c.mult_step = _number(block, "mult_step", c.mult_step, 0.001, 1000.0)
	c.mult_max = _number(block, "mult_max", c.mult_max, 1.0, 1000.0)
	c.min_shapes = int(_number(block, "min_shapes", float(c.min_shapes), 1.0, 1000.0))
	c.run_only_weight = _number(block, "run_only_weight", c.run_only_weight, 0.0, 1000000.0)
	c.shape_removals_start = int(_number(
		block, "shape_removals_start", float(c.shape_removals_start), 0.0, 1000.0
	))
	c.shape_removals_per_boss = int(_number(
		block, "shape_removals_per_boss", float(c.shape_removals_per_boss), 0.0, 1000.0
	))
	return c


static func _number(d: Dictionary, key: String, fallback: float, lo: float, hi: float) -> float:
	if not d.has(key):
		return fallback
	var v: Variant = d[key]
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		push_warning("PieceDeckConfig: '%s' must be a number, keeping %s" % [key, fallback])
		return fallback
	var f: float = float(v)
	if is_nan(f) or f < lo or f > hi:
		push_warning("PieceDeckConfig: '%s' = %s is outside %s..%s, keeping %s" % [key, f, lo, hi, fallback])
		return fallback
	return f

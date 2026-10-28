class_name FieldDropsConfig
extends RefCounted
## Cut-point drop tuning, loaded from assets/data/field_drops.json.
## Schema: assets/data/schema.md. Implements: Story 007, Story 041 (odd_blocks).

const DEFAULT_PATH: String = "res://assets/data/field_drops.json"

## Seconds between drops.
var spawn_interval_sec: float = 1.8
## Seconds before the first drop.
var initial_delay_sec: float = 0.5
## Maximum points lying on one half at once.
var max_on_field: int = 4
## Seconds a point survives on the field.
var freshness_sec: float = 7.0
## Seconds with an empty hand before hunger compensation starts.
var hungry_after_sec: float = 4.0
## Interval multiplier while hungry (< 1 = faster drops).
var hungry_interval_mult: float = 0.6
## When false, points avoid the opponent's swing cells.
var allow_drop_in_danger: bool = true
## Story 024 (piece mode only): seconds between piece drops.
var piece_spawn_interval_sec: float = 3.0
## Story 024 (piece mode only): maximum pieces lying on the half at once.
var piece_max_on_field: int = 3
## Story 024 (piece mode only): seconds a piece survives on the field.
var piece_freshness_sec: float = 8.0
## Story 024 (piece mode only): pieces already lying on the field when a match starts.
var start_pieces: int = 1
## Story 041: odd block ("Khoi La") tuning from the `odd_blocks` block; absent = off (chance 0).
var odd: OddBlockConfig = OddBlockConfig.new()


## Independent copy of this config (so one side's drops can be tuned without the other's).
func copy() -> FieldDropsConfig:
	var c := FieldDropsConfig.new()
	c.spawn_interval_sec = spawn_interval_sec
	c.initial_delay_sec = initial_delay_sec
	c.max_on_field = max_on_field
	c.freshness_sec = freshness_sec
	c.hungry_after_sec = hungry_after_sec
	c.hungry_interval_mult = hungry_interval_mult
	c.allow_drop_in_danger = allow_drop_in_danger
	c.piece_spawn_interval_sec = piece_spawn_interval_sec
	c.piece_max_on_field = piece_max_on_field
	c.piece_freshness_sec = piece_freshness_sec
	c.start_pieces = start_pieces
	c.odd = odd.copy() if odd != null else OddBlockConfig.new()
	return c


## Loads from a JSON file. Falls back to defaults (with a warning) when missing or bad.
static func load_from_file(path: String = DEFAULT_PATH) -> FieldDropsConfig:
	if not FileAccess.file_exists(path):
		push_warning("FieldDropsConfig: file not found, using defaults: %s" % path)
		return FieldDropsConfig.new()
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Falls back to defaults (with a warning) if invalid.
static func from_json_text(text: String) -> FieldDropsConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("FieldDropsConfig: JSON root must be an object, using defaults")
		return FieldDropsConfig.new()
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults, nonsense is clamped.
static func from_dictionary(data: Dictionary) -> FieldDropsConfig:
	var c := FieldDropsConfig.new()
	c.spawn_interval_sec = _positive(data, "spawn_interval_sec", c.spawn_interval_sec)
	c.initial_delay_sec = maxf(float(data.get("initial_delay_sec", c.initial_delay_sec)), 0.0)
	c.max_on_field = maxi(int(data.get("max_on_field", c.max_on_field)), 1)
	c.freshness_sec = _positive(data, "freshness_sec", c.freshness_sec)
	c.hungry_after_sec = maxf(float(data.get("hungry_after_sec", c.hungry_after_sec)), 0.0)
	c.hungry_interval_mult = _positive(data, "hungry_interval_mult", c.hungry_interval_mult)
	c.allow_drop_in_danger = bool(data.get("allow_drop_in_danger", c.allow_drop_in_danger))
	c.piece_spawn_interval_sec = _positive(data, "piece_spawn_interval_sec", c.piece_spawn_interval_sec)
	c.piece_max_on_field = maxi(int(data.get("piece_max_on_field", c.piece_max_on_field)), 1)
	c.piece_freshness_sec = _positive(data, "piece_freshness_sec", c.piece_freshness_sec)
	c.start_pieces = maxi(int(data.get("start_pieces", c.start_pieces)), 0)
	# Story 041: odd blocks; a missing or non-object block keeps them off.
	var raw_odd: Variant = data.get("odd_blocks", null)
	if raw_odd is Dictionary:
		c.odd = OddBlockConfig.from_dictionary(raw_odd as Dictionary)
	elif raw_odd != null:
		push_warning("FieldDropsConfig: odd_blocks must be an object, odd blocks are off")
	return c


static func _positive(data: Dictionary, key: String, fallback: float) -> float:
	var value: float = float(data.get(key, fallback))
	if value <= 0.0:
		push_warning("FieldDropsConfig: %s must be > 0 (got %s), using %s" % [key, value, fallback])
		return fallback
	return value

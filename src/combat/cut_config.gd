class_name CutConfig
extends RefCounted
## Cut numbers (damage per cell, swing timing, hand limit) from assets/data/cuts.json.
## Schema: assets/data/schema.md. Implements: Story 008.

const DEFAULT_PATH: String = "res://assets/data/cuts.json"

## Damage per covered real cell.
var base_damage_per_cell: float = 6.0
## Swing windup = swing_base_sec + swing_per_cell_sec * cells.
var swing_base_sec: float = 0.2
var swing_per_cell_sec: float = 0.25
## When false, a one-point cut goes straight to slash without the skill menu.
var single_point_opens_menu: bool = false
## Most points one cut may use (1..4).
var hand_max_points: int = 4


## Loads from a JSON file. Never null: a missing or bad file gives defaults (warning).
static func load_from_file(path: String = DEFAULT_PATH) -> CutConfig:
	if not FileAccess.file_exists(path):
		push_warning("CutConfig: file not found: %s, using defaults" % path)
		return CutConfig.new()
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Never null (defaults + warning if invalid).
static func from_json_text(text: String) -> CutConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("CutConfig: JSON root must be an object, using defaults")
		return CutConfig.new()
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults, values are clamped.
static func from_dictionary(data: Dictionary) -> CutConfig:
	var config := CutConfig.new()
	config.base_damage_per_cell = maxf(float(data.get("base_damage_per_cell", config.base_damage_per_cell)), 0.0)
	config.swing_base_sec = maxf(float(data.get("swing_base_sec", config.swing_base_sec)), 0.0)
	config.swing_per_cell_sec = maxf(float(data.get("swing_per_cell_sec", config.swing_per_cell_sec)), 0.0)
	config.single_point_opens_menu = bool(data.get("single_point_opens_menu", config.single_point_opens_menu))
	config.hand_max_points = clampi(int(data.get("hand_max_points", config.hand_max_points)), 1, 4)
	return config


## Swing windup in seconds for a cut covering [param cell_count] real cells.
func swing_duration(cell_count: int) -> float:
	return swing_base_sec + swing_per_cell_sec * float(maxi(cell_count, 0))


## Damage of a full-power (slash) hit covering [param cell_count] real cells.
func slash_damage(cell_count: int) -> float:
	return base_damage_per_cell * float(maxi(cell_count, 0))

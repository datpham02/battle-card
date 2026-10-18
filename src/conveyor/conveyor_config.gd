class_name ConveyorConfig
extends RefCounted
## Tunable conveyor data, loaded from an external JSON file.
## Implements: design/game-brief.md MVP feature 1 (Story 001).

const DEFAULT_PATH: String = "res://assets/data/conveyor_belt.json"

## Seconds between card spawns.
var spawn_interval_sec: float = 1.6
## Constant card speed, in belt units per second.
var belt_speed: float = 160.0
## Belt length in abstract belt units (the view scales this to the screen).
var belt_length: float = 1000.0
## Seconds of simulation run before the first frame so the belt starts populated.
var prewarm_sec: float = 0.0
## Card table. Each entry: {id: String, name: String, color: String, weight: float}.
var cards: Array[Dictionary] = []


## Loads a config from a JSON file. Returns null (and pushes an error) on failure.
static func load_from_file(path: String = DEFAULT_PATH) -> ConveyorConfig:
	if not FileAccess.file_exists(path):
		push_error("ConveyorConfig: file not found: %s" % path)
		return null
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Returns null (and pushes an error) if invalid.
static func from_json_text(text: String) -> ConveyorConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ConveyorConfig: JSON root must be an object")
		return null
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary. Returns null (and pushes an error) if invalid.
static func from_dictionary(data: Dictionary) -> ConveyorConfig:
	var config := ConveyorConfig.new()
	config.spawn_interval_sec = float(data.get("spawn_interval_sec", config.spawn_interval_sec))
	config.belt_speed = float(data.get("belt_speed", config.belt_speed))
	config.belt_length = float(data.get("belt_length", config.belt_length))
	config.prewarm_sec = float(data.get("prewarm_sec", config.prewarm_sec))
	var raw_cards: Variant = data.get("cards", [])
	if typeof(raw_cards) == TYPE_ARRAY:
		for entry: Variant in raw_cards:
			if typeof(entry) == TYPE_DICTIONARY:
				config.cards.append(entry as Dictionary)
	if config.cards.is_empty():
		push_error("ConveyorConfig: card table is empty")
		return null
	if config.spawn_interval_sec <= 0.0 or config.belt_speed <= 0.0 or config.belt_length <= 0.0:
		push_error("ConveyorConfig: spawn_interval_sec, belt_speed and belt_length must be > 0")
		return null
	return config

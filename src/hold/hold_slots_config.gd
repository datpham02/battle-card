class_name HoldSlotsConfig
extends RefCounted
## Tunable hold-slot and drag data, loaded from assets/data/hold_slots.json.
## Pixel values are in reference viewport pixels (1280x720, scaled by canvas_items stretch).
## Schema: assets/data/schema.md. Implements: Story 002.

const DEFAULT_PATH: String = "res://assets/data/hold_slots.json"

## Number of hold slots; clamped to HoldSlots.MIN_SLOTS..MAX_SLOTS.
var slot_count: int = HoldSlots.MAX_SLOTS
## Extra pixels around a belt card in which a press still picks it up (thumb tolerance).
var drag_pick_padding_px: float = 12.0
## Extra pixels around a slot in which a drop still counts as on that slot.
var drop_hit_padding_px: float = 16.0
## Pixels the dragged card is lifted above the pointer so the thumb does not cover it.
var drag_lift_px: float = 56.0
## Pointer travel (px) below which pressing and releasing a slot card counts as a tap.
var tap_threshold_px: float = 12.0


## Loads a config from a JSON file. Returns null (and pushes an error) on failure.
static func load_from_file(path: String = DEFAULT_PATH) -> HoldSlotsConfig:
	if not FileAccess.file_exists(path):
		push_error("HoldSlotsConfig: file not found: %s" % path)
		return null
	return from_json_text(FileAccess.get_file_as_string(path))


## Builds a config from JSON text. Returns null (and pushes an error) if invalid.
static func from_json_text(text: String) -> HoldSlotsConfig:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("HoldSlotsConfig: JSON root must be an object")
		return null
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep their defaults.
static func from_dictionary(data: Dictionary) -> HoldSlotsConfig:
	var config := HoldSlotsConfig.new()
	config.slot_count = clampi(
		int(data.get("slot_count", config.slot_count)), HoldSlots.MIN_SLOTS, HoldSlots.MAX_SLOTS
	)
	config.drag_pick_padding_px = maxf(
		float(data.get("drag_pick_padding_px", config.drag_pick_padding_px)), 0.0
	)
	config.drop_hit_padding_px = maxf(
		float(data.get("drop_hit_padding_px", config.drop_hit_padding_px)), 0.0
	)
	config.drag_lift_px = maxf(float(data.get("drag_lift_px", config.drag_lift_px)), 0.0)
	config.tap_threshold_px = maxf(
		float(data.get("tap_threshold_px", config.tap_threshold_px)), 0.0
	)
	return config

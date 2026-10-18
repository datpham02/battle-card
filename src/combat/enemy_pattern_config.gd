class_name EnemyPatternConfig
extends RefCounted
## Fixed enemy attack pattern loaded from assets/data/enemy_patterns.json.
## Schema: assets/data/schema.md. Implements: Story 005.

const DEFAULT_PATH: String = "res://assets/data/enemy_patterns.json"


## One telegraphed attack.
class Attack:
	extends RefCounted
	## Lane the attack hits (0..ScreenLayout.LANE_COUNT-1).
	var target_lane: int = 1
	## Damage in HP on hit (armor absorbs first).
	var damage: float = 0.0
	## Warning countdown in seconds.
	var telegraph_sec: float = 3.0
	## Idle seconds after resolution before the next telegraph.
	var pause_after_sec: float = 0.0


var initial_pause_sec: float = 1.0
var feedback_sec: float = 1.0
## Cap on one frame's time step (seconds) applied by the view before ticking timers.
var max_tick_sec: float = 0.1
var attacks: Array[Attack] = []


## Loads from a JSON file. Returns null (and pushes an error) on failure.
static func load_from_file(path: String = DEFAULT_PATH) -> EnemyPatternConfig:
	if not FileAccess.file_exists(path):
		push_error("EnemyPatternConfig: file not found: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EnemyPatternConfig: JSON root must be an object")
		return null
	return from_dictionary(parsed as Dictionary)


## Builds a config from a dictionary; missing keys keep defaults. Bad values are
## clamped to the valid range and a warning is pushed naming the attack index and key.
static func from_dictionary(data: Dictionary) -> EnemyPatternConfig:
	var config := EnemyPatternConfig.new()
	config.initial_pause_sec = maxf(_number(data, "initial_pause_sec", 1.0, -1), 0.0)
	config.feedback_sec = maxf(_number(data, "feedback_sec", 1.0, -1), 0.0)
	config.max_tick_sec = maxf(_number(data, "max_tick_sec", 0.1, -1), 0.001)
	var list: Variant = data.get("attacks", [])
	if typeof(list) != TYPE_ARRAY:
		push_warning("EnemyPatternConfig: 'attacks' must be an array; enemy stays idle")
		return config
	var rows: Array = list as Array
	if rows.is_empty():
		push_warning("EnemyPatternConfig: 'attacks' is empty; enemy stays idle")
	for i: int in rows.size():
		if typeof(rows[i]) != TYPE_DICTIONARY:
			push_warning("EnemyPatternConfig: attacks[%d] is not an object; skipped" % i)
			continue
		var row: Dictionary = rows[i] as Dictionary
		var attack := Attack.new()
		var lane: int = int(_number(row, "target_lane", 1.0, i))
		if lane < 0 or lane >= ScreenLayout.LANE_COUNT:
			push_warning("EnemyPatternConfig: attacks[%d].target_lane %d outside 0..%d; clamped" % [i, lane, ScreenLayout.LANE_COUNT - 1])
		attack.target_lane = clampi(lane, 0, ScreenLayout.LANE_COUNT - 1)
		attack.damage = maxf(_number(row, "damage", 0.0, i), 0.0)
		attack.telegraph_sec = maxf(_number(row, "telegraph_sec", 3.0, i), 0.1)
		attack.pause_after_sec = maxf(_number(row, "pause_after_sec", 0.0, i), 0.0)
		config.attacks.append(attack)
	return config


# Reads a numeric key; warns (naming attacks[index].key, or just key when index < 0) if it
# is missing, non-numeric or negative. Returns the default when missing/non-numeric.
static func _number(row: Dictionary, key: String, default: float, index: int) -> float:
	var label: String = key if index < 0 else "attacks[%d].%s" % [index, key]
	if not row.has(key):
		push_warning("EnemyPatternConfig: %s missing; using %s" % [label, default])
		return default
	var value: Variant = row[key]
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		push_warning("EnemyPatternConfig: %s is not a number; using %s" % [label, default])
		return default
	var number: float = float(value)
	if number < 0.0:
		push_warning("EnemyPatternConfig: %s is negative (%s); clamped" % [label, number])
	return number

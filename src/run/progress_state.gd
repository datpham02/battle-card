class_name ProgressState
extends RefCounted
## Pure save data of the floor ladder: the floors cleared ("ch1/f2") and at most one floor in
## progress (match index, player HP at the start of that match, floor seed). No scene or file
## dependency; [ProgressStore] moves the JSON. Schema: assets/data/schema.md. Implements: Story 015.

const VERSION: int = 1

var _cleared: Array[String] = []
var _in_progress: Dictionary = {}


## True when floor [param key] ("ch1/f2") is cleared.
func is_cleared(key: String) -> bool:
	return _cleared.has(key)


## Marks a floor cleared (no duplicates). Clears the in-progress record when it points at it.
func mark_cleared(key: String) -> void:
	if not _cleared.has(key):
		_cleared.append(key)
	if not _in_progress.is_empty() and str(_in_progress["floor"]) == key:
		_in_progress = {}


## Copy of the cleared floor keys.
func get_cleared() -> Array[String]:
	return _cleared.duplicate()


## Floor (ci, fi) is playable: the first floor of the first chapter, or the previous floor in
## linear order (across chapters) is cleared.
func is_unlocked(config: ChaptersConfig, ci: int, fi: int) -> bool:
	var index: int = config.linear_index(ci, fi)
	if index < 0:
		return false
	if index == 0:
		return true
	var previous: Vector2i = config.floor_at_linear(index - 1)
	return is_cleared(config.floor_key(previous.x, previous.y))


## Records the floor being played: set at the start of every match.
## [param hp_at_match_start] negative = full HP.
func set_in_progress(key: String, match_index: int, hp_at_match_start: float, floor_seed: int) -> void:
	_in_progress = {
		"floor": key, "match_index": match_index,
		"hp_at_match_start": hp_at_match_start, "floor_seed": floor_seed,
	}


## Forgets the floor in progress.
func clear_in_progress() -> void:
	_in_progress = {}


## True when a floor is in progress.
func has_in_progress() -> bool:
	return not _in_progress.is_empty()


## Copy of {"floor", "match_index", "hp_at_match_start", "floor_seed"}, or {} when none.
func get_in_progress() -> Dictionary:
	return _in_progress.duplicate()


## Serialises to {"version":1,"cleared":[...],"in_progress":{...}|null}.
func to_json() -> String:
	return JSON.stringify({
		"version": VERSION, "cleared": _cleared,
		"in_progress": null if _in_progress.is_empty() else _in_progress,
	})


## Parses saved text. Never null: empty, corrupt, non-object or wrong-version text gives an empty
## state (warning). With [param config], unknown floor keys in `cleared` and an in-progress
## record pointing at an unknown floor or an out-of-range match are dropped (warning).
static func from_json(text: String, config: ChaptersConfig = null) -> ProgressState:
	var state := ProgressState.new()
	if text.strip_edges().is_empty():
		return state
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ProgressState: save is not a JSON object, starting empty")
		return state
	var data: Dictionary = parsed as Dictionary
	if typeof(data.get("version")) not in [TYPE_INT, TYPE_FLOAT] or int(data["version"]) != VERSION:
		push_warning("ProgressState: unsupported save version, starting empty")
		return state
	var raw_cleared: Variant = data.get("cleared", [])
	if typeof(raw_cleared) == TYPE_ARRAY:
		for entry: Variant in raw_cleared as Array:
			var key: String = str(entry)
			if config != null and config.find_floor(key) == Vector2i(-1, -1):
				push_warning("ProgressState: cleared floor '%s' no longer exists, dropped" % key)
			elif not state._cleared.has(key):
				state._cleared.append(key)
	else:
		push_warning("ProgressState: cleared must be an array, ignored")
	var raw_progress: Variant = data.get("in_progress")
	if typeof(raw_progress) == TYPE_DICTIONARY:
		state._load_in_progress(raw_progress as Dictionary, config)
	elif typeof(raw_progress) != TYPE_NIL:
		push_warning("ProgressState: in_progress must be an object or null, ignored")
	return state


## Dev (--progress=all): every floor except the very last is cleared.
static func unlocked_everything(config: ChaptersConfig) -> ProgressState:
	var state := ProgressState.new()
	for i: int in config.total_floors() - 1:
		var pos: Vector2i = config.floor_at_linear(i)
		state._cleared.append(config.floor_key(pos.x, pos.y))
	return state


func _load_in_progress(raw: Dictionary, config: ChaptersConfig) -> void:
	var key: String = str(raw.get("floor", ""))
	var match_index: int = int(raw.get("match_index", 0))
	if key.is_empty() or match_index < 0:
		push_warning("ProgressState: malformed in_progress, ignored")
		return
	if config != null:
		var pos: Vector2i = config.find_floor(key)
		if pos == Vector2i(-1, -1):
			push_warning("ProgressState: in_progress floor '%s' does not exist, ignored" % key)
			return
		if match_index >= config.match_count(pos.x, pos.y):
			push_warning("ProgressState: in_progress match %d is out of range for '%s', ignored" % [match_index, key])
			return
	set_in_progress(key, match_index, float(raw.get("hp_at_match_start", -1.0)), int(raw.get("floor_seed", 0)))

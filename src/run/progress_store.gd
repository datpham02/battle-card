class_name ProgressStore
extends RefCounted
## Reads and writes the [ProgressState] JSON through two injectable callables, so tests and dev
## args (--progress=none|all) never touch the real file. The default is user://progress.json,
## written to a temp file and renamed over the target. Implements: Story 015.
## Save slots (2026-11-07): [SaveSlots] builds one store per slot file through the same callables; every save stamps
## [method ProgressState.set_saved_at] from [member clock] (unix seconds) for the slot card's "last saved" line.

const DEFAULT_PATH: String = "user://progress.json"
const TEMP_SUFFIX: String = ".tmp"

var _save_fn: Callable
var _load_fn: Callable
## Backing text of [method memory_store].
var _memory_text: String = ""
## () -> int: unix seconds stamped on every save (tests install a fixed clock).
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())


## [param save_fn]: (text: String) -> bool. [param load_fn]: () -> String ("" = nothing saved).
## An invalid callable falls back to the real file at [constant DEFAULT_PATH].
func _init(save_fn: Callable = Callable(), load_fn: Callable = Callable()) -> void:
	_save_fn = save_fn if save_fn.is_valid() else Callable(self, "_save_file")
	_load_fn = load_fn if load_fn.is_valid() else Callable(self, "_load_file")


## A store that only keeps the text in memory (never touches the disk).
static func memory_store() -> ProgressStore:
	var store := ProgressStore.new(Callable(), Callable())
	store._save_fn = Callable(store, "_save_memory")
	store._load_fn = Callable(store, "_load_memory")
	return store


## Loads the saved state (empty state when nothing is saved or the data is bad).
func load_state(config: ChaptersConfig) -> ProgressState:
	return ProgressState.from_json(str(_load_fn.call()), config)


## Saves [param state]; false when the write failed.
func save_state(state: ProgressState) -> bool:
	if clock.is_valid():
		state.set_saved_at(int(clock.call()))
	return bool(_save_fn.call(state.to_json()))


func _save_memory(text: String) -> bool:
	_memory_text = text
	return true


func _load_memory() -> String:
	return _memory_text


func _save_file(text: String) -> bool:
	return write_atomic(DEFAULT_PATH, text)


func _load_file() -> String:
	return read_text(DEFAULT_PATH)


## Writes [param text] to [param path] through a temp file renamed over it (no half-written save); false on failure.
static func write_atomic(path: String, text: String) -> bool:
	var temp_path: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("ProgressStore: cannot open %s (error %d)" % [temp_path, FileAccess.get_open_error()])
		return false
	var stored: bool = file.store_string(text)
	file.close()
	if not stored:
		push_warning("ProgressStore: writing %s failed" % temp_path)
		return false
	var err: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("ProgressStore: renaming the save failed (error %d)" % err)
		return false
	return true


## The text of [param path] ("" when the file is missing or unreadable).
static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)

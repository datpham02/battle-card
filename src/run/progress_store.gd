class_name ProgressStore
extends RefCounted
## Reads and writes the [ProgressState] JSON through two injectable callables, so tests and dev
## args (--progress=none|all) never touch the real file. The default is user://progress.json,
## written to a temp file and renamed over the target. Implements: Story 015.

const DEFAULT_PATH: String = "user://progress.json"
const TEMP_SUFFIX: String = ".tmp"

var _save_fn: Callable
var _load_fn: Callable
## Backing text of [method memory_store].
var _memory_text: String = ""


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
	return bool(_save_fn.call(state.to_json()))


func _save_memory(text: String) -> bool:
	_memory_text = text
	return true


func _load_memory() -> String:
	return _memory_text


func _save_file(text: String) -> bool:
	var temp_path: String = DEFAULT_PATH + TEMP_SUFFIX
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
		ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(DEFAULT_PATH))
	if err != OK:
		push_warning("ProgressStore: renaming the save failed (error %d)" % err)
		return false
	return true


func _load_file() -> String:
	if not FileAccess.file_exists(DEFAULT_PATH):
		return ""
	return FileAccess.get_file_as_string(DEFAULT_PATH)

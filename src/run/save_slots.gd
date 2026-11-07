class_name SaveSlots
extends RefCounted
## Save slots (user decision 2026-11-07): [constant SLOT_COUNT] fixed slots, each a full, separate progress file
## (run in progress, unlocks, Kiep, achievements, play time) at [code]<dir>/slot_<n>.json[/code] (n = 1..3), the
## same JSON as [ProgressState.to_json]. The machine settings (locale, last used slot) live in [SettingsStore].
##
## Migration: the first time the game starts with a legacy [code]user://progress.json[/code] and no slot 1 file, the
## legacy text is copied to slot 1 and the old file is renamed to [code]progress.json.bak[/code] (kept, never deleted);
## its locale moves to the settings when the settings have none.
##
## A slot file that is not a readable progress object (bad JSON, not an object, unknown version) is CORRUPT: the
## card shows it, and opening it moves the bytes aside to [code]slot_<n>.json.bad[/code] first (nothing is lost, the
## slot starts empty) — a bad file never crashes and is never silently overwritten.
##
## Two back ends with the same paths: files under [member dir] (the game: [code]user://saves[/code]; integration tests:
## a folder under OS.get_temp_dir()) or a Dictionary in memory ([method memory]; unit tests and dev args).

const SLOT_COUNT: int = 3
const DEFAULT_DIR: String = "user://saves"
const LEGACY_BACKUP_SUFFIX: String = ".bak"
const BAD_SUFFIX: String = ".bad"
enum Status { EMPTY, OK, CORRUPT }

## Folder of the slot files (no trailing slash).
var dir: String
## Path of the pre-slot progress file migrated into slot 1.
var legacy_path: String
var _in_memory: bool = false
## Memory back end: path -> text.
var _memory: Dictionary = {}


## Files under [param slot_dir]; [param legacy] is the pre-slot progress file to migrate.
func _init(slot_dir: String = DEFAULT_DIR, legacy: String = ProgressStore.DEFAULT_PATH) -> void:
	dir = slot_dir.trim_suffix("/")
	legacy_path = legacy


## Slots kept in memory only (same paths, nothing touches the disk).
static func memory() -> SaveSlots:
	var slots := SaveSlots.new()
	slots._in_memory = true
	return slots


## Path of slot [param index] (0-based).
func slot_path(index: int) -> String:
	return "%s/slot_%d.json" % [dir, index + 1]


## True for 0 .. SLOT_COUNT-1.
static func is_valid_index(index: int) -> bool:
	return index >= 0 and index < SLOT_COUNT


## True when slot [param index] has a file.
func has_file(index: int) -> bool:
	return is_valid_index(index) and _exists(slot_path(index))


## EMPTY (no file), OK (a readable progress file) or CORRUPT.
func status(index: int) -> Status:
	if not has_file(index):
		return Status.EMPTY
	return Status.OK if is_valid_text(_read(slot_path(index))) else Status.CORRUPT


## Pure: true when [param text] is a progress object ProgressState.from_json accepts (version 1..VERSION).
static func is_valid_text(text: String) -> bool:
	if text.strip_edges().is_empty():
		return false
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var version: Variant = (json.data as Dictionary).get("version")
	return typeof(version) in [TYPE_INT, TYPE_FLOAT] and int(version) >= 1 and int(version) <= ProgressState.VERSION


## The ProgressStore reading and writing slot [param index] (no file yet = an empty state on load).
func store_for(index: int) -> ProgressStore:
	var path: String = slot_path(index)
	return ProgressStore.new(func(text: String) -> bool: return _write(path, text), func() -> String: return _read(path))


## Loads slot [param index] (empty state when missing or corrupt; [param config] validates the run).
func load_state(index: int, config: ChaptersConfig = null) -> ProgressState:
	if status(index) != Status.OK:
		return ProgressState.new()
	return ProgressState.from_json(_read(slot_path(index)), config)


## Deletes slot [param index]'s file (true when there is none afterwards).
func delete_slot(index: int) -> bool:
	if not is_valid_index(index):
		return false
	var path: String = slot_path(index)
	return not _exists(path) or _remove(path)


## When slot [param index] is CORRUPT, renames its file to [code].bad[/code] (replacing an older one) so the slot is
## empty; true when it did.
func quarantine_if_corrupt(index: int) -> bool:
	if status(index) != Status.CORRUPT:
		return false
	var path: String = slot_path(index)
	push_warning("SaveSlots: %s is not a readable save, kept as %s" % [path, path + BAD_SUFFIX])
	if _exists(path + BAD_SUFFIX):
		_remove(path + BAD_SUFFIX)
	return _rename(path, path + BAD_SUFFIX)


## One-time migration of the legacy progress file into slot 1 (see the class doc). Returns the legacy file's locale
## ("" when nothing was migrated or it had none). [param settings] (optional) receives that locale when it has none,
## and last_slot 0.
func migrate_legacy(settings: SettingsStore = null) -> String:
	if legacy_path.is_empty() or not _exists(legacy_path) or has_file(0):
		return ""
	var text: String = _read(legacy_path)
	if not _write(slot_path(0), text):
		push_warning("SaveSlots: could not copy %s into slot 1, left as it is" % legacy_path)
		return ""
	if _exists(legacy_path + LEGACY_BACKUP_SUFFIX):
		_remove(legacy_path + LEGACY_BACKUP_SUFFIX)
	_rename(legacy_path, legacy_path + LEGACY_BACKUP_SUFFIX)
	var locale: String = ""
	if is_valid_text(text):
		locale = str((JSON.parse_string(text) as Dictionary).get("locale", ""))
	if settings != null:
		if settings.get_locale().is_empty() and not locale.is_empty():
			settings.set_locale(locale)
		settings.set_last_slot(0)
	return locale


## Pure summary of slot [param index] for the slot card: {index, status (Status), has_run, character_id, floor
## (1-based, 0 without a run), region_id, play_time_sec, saved_at, best_floor, achievements (count)}.
func summary(index: int) -> Dictionary:
	var st: Status = status(index)
	var out: Dictionary = {"index": index, "status": st, "has_run": false, "character_id": "", "floor": 0,
		"region_id": "", "play_time_sec": 0.0, "saved_at": 0, "best_floor": 0, "achievements": 0}
	if st != Status.OK:
		return out
	return summarize(ProgressState.from_json(_read(slot_path(index))), index)


## Pure: the [method summary] fields of [param state] (status OK).
static func summarize(state: ProgressState, index: int) -> Dictionary:
	var run: Dictionary = state.get_run_dict()
	var has_run: bool = not run.is_empty()
	var floor_raw: Variant = run.get("floor", 0)
	var floor_index: int = int(floor_raw) if typeof(floor_raw) in [TYPE_INT, TYPE_FLOAT] else 0
	return {"index": index, "status": Status.OK, "has_run": has_run,
		"character_id": str(run.get("character", "")) if has_run else "",
		"floor": floor_index + 1 if has_run else 0, "region_id": str(run.get("region", "")) if has_run else "",
		"play_time_sec": state.get_play_time_sec(), "saved_at": state.get_saved_at(),
		"best_floor": state.get_best_floor(), "achievements": state.get_achievements().size()}


## Pure: [param sec] as "h:mm:ss".
static func format_play_time(sec: float) -> String:
	var total: int = maxi(int(sec), 0)
	@warning_ignore("integer_division")
	return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


## Pure: unix time [param unix_sec] shifted by [param bias_min] minutes as "dd/mm/yyyy hh:mm" (vi) or
## "yyyy-mm-dd hh:mm" (other locales); "" for 0.
static func format_saved_at(unix_sec: int, bias_min: int, locale: String) -> String:
	if unix_sec <= 0:
		return ""
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix_sec + bias_min * 60)
	if locale.begins_with("vi"):
		return "%02d/%02d/%04d %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]
	return "%04d-%02d-%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]


## Memory back end only: writes raw [param text] at [param path] (tests build corrupt / legacy files with it).
func memory_put(path: String, text: String) -> void:
	_memory[path] = text


## Memory back end only: the raw text at [param path] ("" when none).
func memory_get(path: String) -> String:
	return str(_memory.get(path, ""))


# --- Back end -------------------------------------------------------------------


func _exists(path: String) -> bool:
	return _memory.has(path) if _in_memory else FileAccess.file_exists(path)


func _read(path: String) -> String:
	return str(_memory.get(path, "")) if _in_memory else ProgressStore.read_text(path)


func _write(path: String, text: String) -> bool:
	if _in_memory:
		_memory[path] = text
		return true
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		var err: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if err != OK:
			push_warning("SaveSlots: cannot create %s (error %d)" % [path.get_base_dir(), err])
			return false
	return ProgressStore.write_atomic(path, text)


func _remove(path: String) -> bool:
	if _in_memory:
		return _memory.erase(path)
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _rename(from: String, to: String) -> bool:
	if _in_memory:
		if not _memory.has(from):
			return false
		_memory[to] = _memory[from]
		_memory.erase(from)
		return true
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to)) == OK

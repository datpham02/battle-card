class_name SettingsStore
extends RefCounted
## Story 044 Part B: the player's persisted options (the Settings screen edits them). JSON file, default
## [constant DEFAULT_PATH]: [code]{"show_control_hints": false, "reduce_motion": false,
## "card_time": "normal" | "long" | "unlimited"}[/code] (card_time 2026-11-01, accessibility "Thời gian chọn lá").
## Unknown or missing values fall back to the defaults (hints off, reduce motion off, normal card time).
## Story 047 Part D adds [code]reduce_motion[/code] (accessibility "Giam chuyen dong",
## design/accessibility-requirements.md): animated overlays hold their first frame.
## 2026-11-01 (user decision): the optional "pad" movement mode was removed, the floating joystick is the only
## movement control. A [code]controls.movement[/code] value left in an older settings.json is ignored on load and
## dropped on the next save; a [code]--movement=[/code] command line arg is ignored.
##
## Save slots (2026-11-07, user decision): the UI [code]locale[/code] ("" = not chosen yet, the game default) and the
## [code]last_slot[/code] (0-based save slot the title opens) moved here from the progress file: they belong to the
## machine, not to a slot. [method memory] builds a store that never touches a file (tests, dev args).
##
## Two ways to use it. The game reads the shared instance ([method shared]), loaded lazily from
## the real file. Tests build their own instance on a temp path ([code]SettingsStore.new(path)[/code])
## and never touch the real file.

## Real settings file (per user).
const DEFAULT_PATH: String = "user://settings.json"
## Accessibility "Thời gian chọn lá" (design/ux/hud.md): the card menu's choose time and the place window
## (cuts.json place_window_sec) run x1 ("3 s"), x2 ("6 s") or without a limit (no auto pick / auto cast).
const CARD_TIME_NORMAL: String = "normal"
const CARD_TIME_LONG: String = "long"
const CARD_TIME_UNLIMITED: String = "unlimited"
## The values in the order the settings row cycles them.
const CARD_TIMES: Array[String] = [CARD_TIME_NORMAL, CARD_TIME_LONG, CARD_TIME_UNLIMITED]
## Time multiplier per card time value (0 = no limit).
const CARD_TIME_MULTS: Dictionary = {CARD_TIME_NORMAL: 1.0, CARD_TIME_LONG: 2.0, CARD_TIME_UNLIMITED: 0.0}

static var _shared: SettingsStore = null

var _path: String
var _show_control_hints: bool = false
var _reduce_motion: bool = false
var _card_time: String = CARD_TIME_NORMAL
var _locale: String = ""
var _last_slot: int = 0


## Builds a store on [param path] and loads it (missing or broken file = defaults).
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	load_file()


## A store with the defaults that never reads or writes a file (path "").
static func memory() -> SettingsStore:
	return SettingsStore.new("")


## The shared store of the game, created on first use from [constant DEFAULT_PATH].
static func shared() -> SettingsStore:
	if _shared == null:
		_shared = SettingsStore.new(DEFAULT_PATH)
	return _shared


## Drops the shared instance (tests).
static func reset_shared() -> void:
	_shared = null


## True when the faint stick hint ring stays visible all match (settings.show_control_hints).
func get_show_control_hints() -> bool:
	return _show_control_hints


## Sets show_control_hints and saves.
func set_show_control_hints(on: bool) -> void:
	_show_control_hints = on
	save_file()


## True when reduce motion is on (settings.reduce_motion): status overlays and other looping effects
## hold frame 0. Defaults to false; no OS setting is read (accessibility requirements, open question).
func get_reduce_motion() -> bool:
	return _reduce_motion


## Sets reduce_motion and saves.
func set_reduce_motion(on: bool) -> void:
	_reduce_motion = on
	save_file()


## The "Thời gian chọn lá" value (one of [constant CARD_TIMES]; default [constant CARD_TIME_NORMAL]).
func get_card_time() -> String:
	return _card_time


## Sets the card time value and saves; an unknown value is ignored.
func set_card_time(value: String) -> void:
	if not CARD_TIMES.has(value):
		return
	_card_time = value
	save_file()


## Moves the card time to the next value of [constant CARD_TIMES] (wrapping) and returns it.
func cycle_card_time() -> String:
	set_card_time(CARD_TIMES[(CARD_TIMES.find(_card_time) + 1) % CARD_TIMES.size()])
	return _card_time


## Save slots: the saved UI locale code ("" = never chosen; the caller validates it).
func get_locale() -> String:
	return _locale


## Sets the UI locale code and saves.
func set_locale(code: String) -> void:
	_locale = code
	save_file()


## Save slots: the 0-based slot the title opens (>= 0; the caller clamps to the slot count).
func get_last_slot() -> int:
	return _last_slot


## Sets the last used slot (negative = 0) and saves.
func set_last_slot(index: int) -> void:
	_last_slot = maxi(index, 0)
	save_file()


## Pure: the time multiplier of card time [param value] (1 for an unknown value; 0 = no limit).
static func card_time_mult(value: String) -> float:
	return float(CARD_TIME_MULTS.get(value, 1.0))


## Reads the file; anything missing or malformed leaves the defaults. Returns true when a file
## was parsed.
func load_file() -> bool:
	_show_control_hints = false
	_reduce_motion = false
	_card_time = CARD_TIME_NORMAL
	_locale = ""
	_last_slot = 0
	if _path.is_empty() or not FileAccess.file_exists(_path):
		return false
	var file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return false
	var data: Dictionary = json.data
	_show_control_hints = data.get("show_control_hints", false) == true
	var reduce: Variant = data.get("reduce_motion", false)
	_reduce_motion = reduce is bool and bool(reduce)
	var card_time: Variant = data.get("card_time", CARD_TIME_NORMAL)
	if card_time is String and CARD_TIMES.has(card_time):
		_card_time = card_time
	var locale: Variant = data.get("locale", "")
	_locale = locale if locale is String else ""
	var slot: Variant = data.get("last_slot", 0)
	_last_slot = maxi(int(slot), 0) if typeof(slot) in [TYPE_INT, TYPE_FLOAT] else 0
	return true


## Writes the stored values to the file. Returns false when it cannot write.
func save_file() -> bool:
	if _path.is_empty():
		return true
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return false
	var data: Dictionary = {
		"show_control_hints": _show_control_hints,
		"reduce_motion": _reduce_motion,
		"card_time": _card_time,
		"locale": _locale,
		"last_slot": _last_slot,
	}
	file.store_string(JSON.stringify(data, "\t"))
	return true


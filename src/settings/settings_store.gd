class_name SettingsStore
extends RefCounted
## Story 044 Part B: the player's persisted options (there is no Settings screen; the pause panel
## flips [code]controls.movement[/code]). JSON file, default [constant DEFAULT_PATH]:
## [code]{"controls": {"movement": "joystick" | "pad"}, "show_control_hints": false, "reduce_motion": false}[/code].
## Unknown or missing values fall back to the defaults (joystick, hints off, reduce motion off).
## Story 047 Part D adds [code]reduce_motion[/code] (accessibility "Giam chuyen dong",
## design/accessibility-requirements.md): animated overlays hold their first frame.
##
## Two ways to use it. The game reads the shared instance ([method shared]), loaded lazily from
## the real file. Tests build their own instance on a temp path ([code]SettingsStore.new(path)[/code])
## and never touch the real file.
##
## Override: the command line [code]--movement=pad|joystick[/code] (user args, after [code]--[/code])
## or [method set_movement_override] force the movement mode over the file. While an override is
## active, [method set_movement] changes the override and does NOT write the file, so a scripted run
## cannot damage the player's settings. Windowed click suites call
## [code]SettingsStore.set_movement_override(SettingsStore.MOVEMENT_PAD)[/code] before building the scene.

## Movement modes of Z3 (quick spec control-layout-v2 section 2.2).
const MOVEMENT_JOYSTICK: String = "joystick"
const MOVEMENT_PAD: String = "pad"
## Real settings file (per user).
const DEFAULT_PATH: String = "user://settings.json"
## Command line switch (the value after '=' is a movement mode).
const MOVEMENT_ARG: String = "--movement="

static var _shared: SettingsStore = null
static var _override: String = ""
static var _override_from_cli_checked: bool = false

var _path: String
var _movement: String = MOVEMENT_JOYSTICK
var _show_control_hints: bool = false
var _reduce_motion: bool = false


## Builds a store on [param path] and loads it (missing or broken file = defaults).
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	load_file()


## The shared store of the game, created on first use from [constant DEFAULT_PATH].
static func shared() -> SettingsStore:
	if _shared == null:
		_shared = SettingsStore.new(DEFAULT_PATH)
	return _shared


## Drops the shared instance and every override (tests; the CLI switch is read again).
static func reset_shared() -> void:
	_shared = null
	_override = ""
	_override_from_cli_checked = false


## Forces the movement mode regardless of the file; "" clears it. An unknown value is ignored.
## A programmatic override beats the command line.
static func set_movement_override(mode: String) -> void:
	_override_from_cli_checked = true
	_override = mode if _is_valid(mode) else ""


## The active override ("" = none): [method set_movement_override] first, else the CLI switch.
static func get_movement_override() -> String:
	if not _override_from_cli_checked:
		_override_from_cli_checked = true
		_override = parse_movement_arg(OS.get_cmdline_user_args())
	return _override


## The movement mode given in [param args] as [code]--movement=pad|joystick[/code]; "" when absent
## or unknown. The last valid occurrence wins.
static func parse_movement_arg(args: PackedStringArray) -> String:
	var mode: String = ""
	for arg: String in args:
		if arg.begins_with(MOVEMENT_ARG):
			var value: String = arg.substr(MOVEMENT_ARG.length())
			if _is_valid(value):
				mode = value
	return mode


## Effective movement mode: the override when active, else the stored value.
func get_movement() -> String:
	var forced: String = get_movement_override()
	return forced if forced != "" else _movement


## True when the effective movement mode is the 3x3 pad.
func is_pad() -> bool:
	return get_movement() == MOVEMENT_PAD


## Sets the movement mode. With an override active it changes the override only (nothing is
## written); otherwise it stores the value and saves. An unknown value is ignored.
func set_movement(mode: String) -> void:
	if not _is_valid(mode):
		return
	if get_movement_override() != "":
		set_movement_override(mode)
		return
	_movement = mode
	save_file()


## Flips joystick <-> pad (the pause panel button) and returns the new mode.
func toggle_movement() -> String:
	set_movement(MOVEMENT_JOYSTICK if is_pad() else MOVEMENT_PAD)
	return get_movement()


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


## Reads the file; anything missing or malformed leaves the defaults. Returns true when a file
## was parsed.
func load_file() -> bool:
	_movement = MOVEMENT_JOYSTICK
	_show_control_hints = false
	_reduce_motion = false
	if not FileAccess.file_exists(_path):
		return false
	var file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return false
	var data: Dictionary = json.data
	var controls: Variant = data.get("controls", {})
	if controls is Dictionary:
		var mode: Variant = (controls as Dictionary).get("movement", MOVEMENT_JOYSTICK)
		if mode is String and _is_valid(mode):
			_movement = mode
	_show_control_hints = data.get("show_control_hints", false) == true
	var reduce: Variant = data.get("reduce_motion", false)
	_reduce_motion = reduce is bool and bool(reduce)
	return true


## Writes the stored values (never an override) to the file. Returns false when it cannot write.
func save_file() -> bool:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return false
	var data: Dictionary = {
		"controls": {"movement": _movement},
		"show_control_hints": _show_control_hints,
		"reduce_motion": _reduce_motion,
	}
	file.store_string(JSON.stringify(data, "\t"))
	return true


static func _is_valid(mode: String) -> bool:
	return mode == MOVEMENT_JOYSTICK or mode == MOVEMENT_PAD

extends SceneTree
## QA capture for the settings screen: opens the main scene with `--screen=settings` (memory settings, never the
## real user://settings.json), optionally switches the locale (`--lang=en`), waits a few frames and saves the root
## viewport to `--out=<png>`. Windowed only (headless has no renderer).
## Run: godot --windowed --resolution 1280x720 --path . -s res://tools/audio/settings_shot.gd -- --screen=settings --out=<png> [--lang=en] [--tab=audio] [--volumes=Master:0,Music:100] [--focus=N] [--open-lang] [--press=x,y]

const WAIT_FRAMES: int = 30

var _frames: int = 0
var _out: String = ""
var _tab: String = ""
var _volumes: Dictionary = {}
var _focus: int = -1
var _open_lang: bool = false
var _press: Vector2 = Vector2(-1, -1)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--tab="):
			_tab = arg.trim_prefix("--tab=")
		elif arg.begins_with("--volumes="):
			for pair: String in arg.trim_prefix("--volumes=").split(",", false):
				_volumes[pair.get_slice(":", 0)] = int(pair.get_slice(":", 1))
		elif arg.begins_with("--press="):
			var xy: PackedStringArray = arg.trim_prefix("--press=").split(",")
			_press = Vector2(float(xy[0]), float(xy[1]))
		elif arg == "--open-lang":
			_open_lang = true
		elif arg.begins_with("--focus="):
			_focus = int(arg.trim_prefix("--focus="))
	root.add_child((load("res://src/main.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		for n: Node in root.find_children("*", "SettingsView", true, false):
			var view := n as SettingsView
			if not _tab.is_empty():
				view.set_tab(_tab)
			for bus: String in _volumes.keys():
				view.audio_store().set_volume(bus, int(_volumes[bus]))
			view.set("_focus", _focus)
			view.set_language_open(_open_lang)
	if _frames == WAIT_FRAMES - 3 and _press.x >= 0.0:
		# Holds a real left-button press there (pressed state); the press also acts like a tap.
		root.warp_mouse(_press)
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = _press
		e.global_position = _press
		Input.parse_input_event(e)
	if _frames == WAIT_FRAMES:
		var img: Image = root.get_texture().get_image()
		var err: int = img.save_png(_out)
		print("saved %s (%dx%d) err=%d" % [_out, img.get_width(), img.get_height(), err])
		quit(0 if err == OK else 1)
	return false

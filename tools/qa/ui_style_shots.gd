extends SceneTree
## 2026-11-14 UI style pass: in-game evidence for the two restyled pieces — the battle HP plate
## (CombatView._draw_player_panel) and the reward screen's ink row (RewardView.draw_shape_tile).
## Loads the real main scene, so the shots are the game as it runs, not a mockup.
## `--mode=battle` just waits and shoots; `--mode=ink` forces the run's pending card offer and ink offer the way
## DemoArgs._force_reward_offer does, so the reward screen comes up with the shape tiles on it.
## Run (windowed, muted):
##   godot --windowed --resolution 1280x720 --audio-driver Dummy --path . -s res://tools/qa/ui_style_shots.gd \
##     -- --mode=battle --out=<png> [--demo=controls_idle passed through to the game]

const WAIT_FRAMES: int = 40
const FORCE_FRAME: int = 12
const PRESS_FRAME: int = 24
## The ink offer forced in `--mode=ink`: the two shapes of the user's 2026-11-14 screenshot.
const INK_OFFER: Array[String] = ["y5", "z4"]
## The card offer forced alongside it, so the screen is the real two-row reward screen.
const CARD_OFFER: Array[String] = ["tran_gai", "gai_doc", "gai_nguyen"]

var _frames: int = 0
var _out: String = ""
var _mode: String = "battle"
## `--press=x,y`: a real left-button press held there from PRESS_FRAME on, so the shot carries a selected tile.
var _press: Vector2 = Vector2(-1.0, -1.0)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--press="):
			var xy: PackedStringArray = arg.trim_prefix("--press=").split(",")
			if xy.size() >= 2:
				_press = Vector2(float(xy[0]), float(xy[1]))
	root.add_child((load("res://src/main.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == FORCE_FRAME and _mode == "ink":
		_force_ink_offer()
	if _frames == PRESS_FRAME and _press.x >= 0.0:
		_tap(_press)
	if _frames < WAIT_FRAMES:
		return false
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(_out)
	print("saved %s (%dx%d) err=%d mode=%s" % [_out, img.get_width(), img.get_height(), err, _mode])
	quit(0 if err == OK else 1)
	return false


# As DemoArgs._force_reward_offer, plus the ink row: the reward screen draws the shape tiles only while
# GameFlow.has_ink_offer().
func _force_ink_offer() -> void:
	for n: Node in root.find_children("*", "GameFlow", true, false):
		var flow: GameFlow = n as GameFlow
		if flow.get_run() == null:
			continue
		flow.get_run().set_pending_reward(CARD_OFFER)
		flow.get_run().set_pending_ink_offer(INK_OFFER)
		flow.run_changed.emit()
		print("forced: reward=%s ink=%s" % [CARD_OFFER, INK_OFFER])
		return
	push_warning("ui_style_shots: no GameFlow with a run")


# A press and release at [param at] (screen px): one tap, which selects a tile without confirming it.
func _tap(at: Vector2) -> void:
	root.warp_mouse(at)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)

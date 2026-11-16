extends SceneTree
## QA tool (not a test): in-game evidence of the TITLE screen (TitleView), so the key art, the
## back-turned hero on the ledge, the name and the button column can be judged as the game draws
## them rather than as separate PNGs.
##
## Written 2026-11-16 for the weapon-free hero pass: `assets/art/ui/title/hero_back_ne.png` was still
## the pre-redesign Vale (long cape, a diagonal scabbard strap down the back) after every playable
## hero was redrawn weapon-free in commit 5868e44b. The replacement is Vale anchor v5's `north-east`
## rotation, and this script is how that swap is shown working rather than asserted.
##
## It loads the real `src/main.tscn`, so the shot is the game, not a mockup. GameFlow starts in
## Phase.TITLE, so no input is needed to reach the screen; the script only waits for the scene to
## settle (TitleView redraws every frame and its mist and sparks move) and then saves the viewport.
##
## It is not limited to the title. It loads the real main scene and shoots whatever that scene is showing, and
## GameFlow reads the SAME user args, so any dev switch that opens another screen can ride along and this shoots
## that screen instead. `--at-floor=N` (no `--region`) was used on 2026-11-16 to capture the climb map's WORLD_MAP
## at floors 1, 4 and 7 for the summit-scale change.
##
## Run (windowed, muted — these views need a real window, `--headless` cannot save a viewport image;
## the project's running rule is one Godot process at a time and `--audio-driver Dummy` on every
## windowed run):
##   godot --windowed --resolution 1280x720 --audio-driver Dummy --path . \
##     -s res://tools/qa/title_shot.gd -- --out=<png> [--variant=a|b] [--frames=N] [--at-floor=N]
##
## `--variant` is passed straight through to TitleView's own `--menu-variant=` switch: `b` (the
## default) is the art as drawn with the menu on the right, `a` mirrors it. `--frames` moves the
## capture frame, which is useful when a moving element (mist band, rising spark) sits over the
## thing being judged.

## Frames to wait before the shot. TitleView animates, so a shot on frame 1 catches the scene at
## t=0 with every mist band at its start offset; 40 frames is the settle used by the other QA shot
## tools in this directory and keeps the two comparable.
const DEFAULT_WAIT_FRAMES: int = 40

var _frames: int = 0
var _wait: int = DEFAULT_WAIT_FRAMES
var _out: String = ""


func _initialize() -> void:
	var variant: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--variant="):
			variant = arg.trim_prefix("--variant=")
		elif arg.begins_with("--frames="):
			_wait = maxi(1, int(arg.trim_prefix("--frames=")))
	if _out.is_empty():
		push_error("title_shot: --out=<png> is required")
		quit(1)
		return
	# TitleView reads `--menu-variant=` from the user args itself, so pass it on rather than
	# reaching into ScreenLayout from here: the shot then exercises the same path the game uses.
	if not variant.is_empty():
		print("title_shot: variant=%s (TitleView reads --menu-variant=)" % variant)
	root.add_child((load("res://src/main.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _wait:
		return false
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(_out)
	print("saved %s (%dx%d) err=%d frames=%d" % [_out, img.get_width(), img.get_height(), err, _frames])
	quit(0 if err == OK else 1)
	return false

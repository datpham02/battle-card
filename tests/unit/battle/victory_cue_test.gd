extends SceneTree
## F3 §2.1 (`second_wind`): the victory cue keeps animating while the battle subtree is FROZEN.
##
## Why this is a test and not only a screenshot. `RunController._on_match_ended` calls
## `_freeze_battle()`, which sets `Battle.process_mode = PROCESS_MODE_DISABLED`, and every drawing
## layer — `UnitLayer` and `CutHudView` both — is a child of `Battle`. A cue clocked by any of them
## appears and then hangs motionless for the three seconds the frozen board is on screen. **A single
## screenshot cannot tell a rising number from a hung one**: the frame looks identical either way.
## Neither can a reading of the code, which is why two sessions proposed the broken version.
##
## So the gate is here, where the question is mechanical: does the clock advance under a disabled
## parent. The retained capture still answers whether it LOOKS right; this answers whether it moves.
##
## The first leg is the control, and it is the point of the file: the same node with
## `PROCESS_MODE_INHERIT` must FAIL to advance under the same disabled parent. Without it, a green
## result here would be equally green if the freeze never happened in the test at all — the
## instrument would be unable to fail in the presence of the fault.
##
## Headless, no match needed. Run:
## godot --headless -s res://tests/unit/battle/victory_cue_test.gd

const PassiveCueLayer = preload("res://src/battle/passive_cue_layer.gd")

## Frames to spend waiting for the clock to reach the text. Headless frames are short and their
## delta is not fixed, so the test waits for a TIME to be reached rather than counting frames.
const FRAME_BUDGET: int = 4000
## Frames to sample the two rigs at. Must be well INSIDE the cue: past its end both rigs report
## elapsed() == -1.0 and the control stops discriminating.
const SAMPLE_FRAMES: int = 3

var fails: int = 0


func ck(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ((" — " + extra) if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	# Burn two frames before building any rig. Measured, not guessed: a node added during the very
	# first moments of _initialize reports can_process() == true for a couple of frames even with a
	# PROCESS_MODE_DISABLED parent, because the tree has not built its process lists yet. The control
	# leg below ran in exactly that window and reported a frozen parent failing to freeze -- which
	# almost had me conclude the whole premise of the cue was wrong. The premise is right; the
	# harness was lying. (Probe: `can_process` true at frame 0 of _initialize, false for identical
	# code a few frames later.)
	await process_frame
	await process_frame
	await _test_frozen_parent_stops_an_inheriting_node()
	await _test_cue_runs_under_a_frozen_parent()
	await _test_text_rises_then_the_cue_ends()
	print("FAILS=%d" % fails)
	quit(fails)


# Arrange a frozen battle: a parent standing in for `Battle`, with the cue under it.
func _rig(mode: int) -> Array:
	var parent := Node2D.new()
	root.add_child(parent)
	var cue: PassiveCueLayer = PassiveCueLayer.new()
	parent.add_child(cue)
	# After add_child, so it overrides what _ready() set.
	cue.process_mode = mode
	parent.process_mode = Node.PROCESS_MODE_DISABLED
	return [parent, cue]


# THE CONTROL. If this leg ever goes green, every other leg in this file is meaningless.
func _test_frozen_parent_stops_an_inheriting_node() -> void:
	var rig: Array = _rig(Node.PROCESS_MODE_INHERIT)
	var parent: Node2D = rig[0]
	var cue: PassiveCueLayer = rig[1]
	cue.play(0, 20)
	for _i: int in range(SAMPLE_FRAMES):
		await process_frame
	ck("control: an INHERITing cue does not advance under a frozen parent",
		is_equal_approx(cue.elapsed(), 0.0), "elapsed=%.4f after %d frames" % [cue.elapsed(), SAMPLE_FRAMES])
	ck("control: its text therefore never starts", cue.text_progress() < 0.0,
		"progress=%.3f" % cue.text_progress())
	parent.queue_free()


func _test_cue_runs_under_a_frozen_parent() -> void:
	var rig: Array = _rig(Node.PROCESS_MODE_ALWAYS)
	var parent: Node2D = rig[0]
	var cue: PassiveCueLayer = rig[1]
	cue.play(0, 20)
	var first: float = cue.elapsed()
	for _i: int in range(SAMPLE_FRAMES):
		await process_frame
	# Still playing: a cue that has already ENDED also reports elapsed() == -1.0, which is not an
	# advance and must not be read as one. That is how the first run of this file scored itself.
	ck("the shipped cue advances under a frozen parent", cue.is_playing() and cue.elapsed() > first,
		"%.4f -> %.4f, playing=%s" % [first, cue.elapsed(), str(cue.is_playing())])
	ck("the glow is lit at the start", cue.glow_fade() > 0.0, "fade=%.3f" % cue.glow_fade())
	parent.queue_free()


func _test_text_rises_then_the_cue_ends() -> void:
	var rig: Array = _rig(Node.PROCESS_MODE_ALWAYS)
	var parent: Node2D = rig[0]
	var cue: PassiveCueLayer = rig[1]
	cue.play(0, 20)

	# Wait for the text to start rather than guessing how many frames that takes.
	var spent: int = 0
	while cue.text_progress() < 0.0 and cue.is_playing() and spent < FRAME_BUDGET:
		await process_frame
		spent += 1
	var started: float = cue.text_progress()
	ck("the text starts after its delay", started >= 0.0, "progress=%.3f after %d frames" % [started, spent])

	# It must MOVE, which is the whole failure mode: a hung text reports the same progress forever.
	var moved: bool = false
	for _i: int in range(FRAME_BUDGET):
		await process_frame
		if not cue.is_playing():
			break
		if cue.text_progress() > started:
			moved = true
			break
	ck("the text's progress increases (it rises, it does not hang)", moved,
		"started=%.3f now=%.3f" % [started, cue.text_progress()])

	# And it must clear itself, or the frozen board keeps a number on it for the next match.
	var left: int = FRAME_BUDGET
	while cue.is_playing() and left > 0:
		await process_frame
		left -= 1
	ck("the cue ends on its own", not cue.is_playing(), "elapsed=%.3f" % cue.elapsed())
	ck("and hides itself when it does", not cue.visible)
	parent.queue_free()

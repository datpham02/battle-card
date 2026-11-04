extends SceneTree
## 2026-11-04 bug (user: "sau khi cast thì animation di chuyển bị mất"): the Mage's first cast_gesture had 5 frames
## while the shared cast pack's coil (gesture_hold_frame) is 4. When the launch came due the wind-up seeked to the
## slash frame 5, clamped back onto 4, and did so again every tick: the clip never finished, clip_context kept
## `casting` true and the hero never showed a step clip again. The coil is now clamped to count - 2.
## The test drives a real UnitAnimator the way UnitLayer._drive_cast_hold does, on a clip shorter than the coil.
## Run: godot --headless --path . -s res://tests/unit/battle/cast_hold_short_clip_test.gd

const STEP: float = 1.0 / 60.0

var fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" " + extra if not extra.is_empty() else ""))
	if not ok:
		fails += 1


func _initialize() -> void:
	var sheet: SpriteSheet = SpriteSheet.load_unit("kiem_si")
	_check("test_fixture_sheet_loads", sheet != null and sheet.has_clip("hit"))
	if sheet == null:
		quit(1)
		return
	# `hit` (3 frames, once) stands in for a cast clip shorter than the coil frame 4.
	_check("test_short_clip_finishes_after_the_launch", _run(sheet, "hit", 4), "")
	_check("test_long_clip_still_finishes", _run(sheet, "cast_gesture", 4), "")
	_check("test_old_hold_behaviour_finishes", _run(sheet, "hit", -1), "")
	var held: Dictionary = UnitLayer.cast_hold_step(4, 9, 4, true)
	_check("test_long_clip_holds_on_the_coil", held["seek"] == -1 and bool(held["paused"]))
	var launch: Dictionary = UnitLayer.cast_hold_step(4, 9, 4, false)
	_check("test_long_clip_jumps_to_the_slash", int(launch["seek"]) == 5 and not bool(launch["paused"]))
	var short: Dictionary = UnitLayer.cast_hold_step(4, 5, 4, false)
	_check("test_short_clip_never_seeks_back_onto_its_last_frame", int(short["seek"]) == -1, str(short))
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)


# Plays [param clip] with the telegraph held for 0.4 s, then the launch, driven for 3 s like UnitLayer does while the
# clip is current; true when it is finished at the end (a clip that keeps being seeked back never is).
func _run(sheet: SpriteSheet, clip: String, hold: int) -> bool:
	var anim := UnitAnimator.new(sheet)
	anim.play(clip, true)
	var t: float = 0.0
	while t < 3.0:
		anim.tick(STEP)
		var step: Dictionary = UnitLayer.cast_hold_step(anim.frame_index(), anim.frame_count(), hold, t < 0.4)
		if int(step["seek"]) >= 0:
			anim.seek(int(step["seek"]))
		anim.set_paused(bool(step["paused"]))
		t += STEP
	return anim.is_finished()

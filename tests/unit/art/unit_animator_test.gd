extends SceneTree
## Story 047 Part C: UnitAnimator clip state machine (loop / once / hold_last / hold, timed
## step, reduce motion, missing clip, null sheet). Headless, deterministic; the sheet comes from
## the fixture JSON so no texture is involved.
## Run: godot --headless --path . -s res://tests/unit/art/unit_animator_test.gd

const SpriteSheetScript := preload("res://src/art/sprite_sheet.gd")
const UnitAnimatorScript := preload("res://src/art/unit_animator.gd")

const FIXTURE := "res://tests/fixtures/art/unit_sheet_fixture.json"
## Fixture facts: idle 400+400 loop, cast_gesture 80+120 once, hit 120 once,
## defeat 150+150 hold_last, fall 0 hold, step 300+300 loop.
const IDLE_FRAME_SEC := 0.4
const CAST_FRAME0_SEC := 0.08
const CAST_FRAME1_SEC := 0.12
const HIT_SEC := 0.12
const DEFEAT_FRAME_SEC := 0.15
const STEP_COOLDOWN_SEC := 0.45

var fails: int = 0


func check(name: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	test_loop_idle_wraps_after_800ms()
	test_once_cast_gesture_finishes_at_200ms()
	test_hold_last_defeat_stays_on_frame_1()
	test_hold_fall_frame_0_forever()
	test_play_timed_step_shares_cooldown()
	test_play_timed_once_finishes_at_cooldown()
	test_reduce_motion_holds_idle_but_plays_hit()
	test_missing_clip_returns_false_and_idle()
	test_play_same_clip_keeps_going_unless_restart()
	test_null_sheet_is_a_quiet_no_op()
	print("FAILS=%d" % fails)
	quit(fails)


func _sheet() -> SpriteSheetScript:
	var file := FileAccess.open(FIXTURE, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	return SpriteSheetScript.from_json(data, "")


func _animator() -> UnitAnimatorScript:
	return UnitAnimatorScript.new(_sheet())


func test_loop_idle_wraps_after_800ms() -> void:
	# Arrange
	var anim := _animator()
	# Act / Assert
	check("play('idle') is true", anim.play("idle"))
	check("idle starts on frame 0", anim.frame_index() == 0)
	check("idle frame_rect is (0,0,40,48)", anim.frame_rect() == Rect2i(0, 0, 40, 48))
	anim.tick(IDLE_FRAME_SEC * 0.5)
	check("idle at 200 ms still frame 0", anim.frame_index() == 0)
	anim.tick(IDLE_FRAME_SEC * 0.5)
	check("idle at 400 ms is frame 1", anim.frame_index() == 1)
	check("idle frame 1 rect is (41,0,40,48)", anim.frame_rect() == Rect2i(41, 0, 40, 48))
	anim.tick(IDLE_FRAME_SEC)
	check("idle at 800 ms wrapped to frame 0", anim.frame_index() == 0)
	check("loop clip is never finished", not anim.is_finished())
	anim.tick(IDLE_FRAME_SEC * 5.0)
	check("idle after 2800 ms is frame 1 (multi-frame tick)", anim.frame_index() == 1)
	check("loop_kind reports 'loop'", anim.loop_kind() == "loop")


func test_once_cast_gesture_finishes_at_200ms() -> void:
	var anim := _animator()
	anim.play("cast_gesture")
	anim.tick(CAST_FRAME0_SEC * 0.5)
	check("cast at 40 ms is frame 0, not finished", anim.frame_index() == 0 and not anim.is_finished())
	anim.tick(CAST_FRAME0_SEC * 0.5)
	check("cast at 80 ms is frame 1", anim.frame_index() == 1)
	anim.tick(CAST_FRAME1_SEC - 0.01)
	check("cast at 190 ms still frame 1, not finished", anim.frame_index() == 1 and not anim.is_finished())
	anim.tick(0.01)
	check("cast at 200 ms is finished", anim.is_finished())
	check("finished once clip stays on its last frame", anim.frame_index() == 1)
	anim.tick(1.0)
	check("ticking a finished clip changes nothing", anim.frame_index() == 1 and anim.is_finished())
	# A single tick covering the whole clip also finishes it.
	var anim2 := _animator()
	anim2.play("cast_gesture")
	anim2.tick(CAST_FRAME0_SEC + CAST_FRAME1_SEC)
	check("cast finishes in one 200 ms tick", anim2.is_finished() and anim2.frame_index() == 1)


func test_hold_last_defeat_stays_on_frame_1() -> void:
	var anim := _animator()
	anim.play("defeat")
	anim.tick(DEFEAT_FRAME_SEC)
	check("defeat at 150 ms is frame 1, not finished yet", anim.frame_index() == 1 and not anim.is_finished())
	anim.tick(DEFEAT_FRAME_SEC)
	check("defeat at 300 ms is finished", anim.is_finished())
	anim.tick(10.0)
	check("defeat stays on frame 1 forever", anim.frame_index() == 1)
	check("defeat frame_rect is (41,196,40,48)", anim.frame_rect() == Rect2i(41, 196, 40, 48))


func test_hold_fall_frame_0_forever() -> void:
	var anim := _animator()
	anim.play("fall")
	check("fall starts on frame 0", anim.frame_index() == 0)
	anim.tick(5.0)
	anim.tick(5.0)
	check("fall stays on frame 0 after 10 s", anim.frame_index() == 0)
	check("fall (0 ms hold) never reports finished", not anim.is_finished())
	check("fall frame_rect is (0,245,40,48)", anim.frame_rect() == Rect2i(0, 245, 40, 48))
	# A hold clip with a real duration finishes once it elapses but keeps frame 0.
	var timed := _animator()
	timed.play_timed("fall", 0.3)
	timed.tick(0.3)
	check("timed hold clip finishes at its duration, still frame 0", timed.is_finished() and timed.frame_index() == 0)


func test_play_timed_step_shares_cooldown() -> void:
	var anim := _animator()
	check("play_timed('step', 0.45) is true", anim.play_timed("step", STEP_COOLDOWN_SEC))
	check("timed step keeps the sheet's loop kind", anim.loop_kind() == "loop")
	anim.tick(0.2)
	check("step at 200 ms is frame 0 (225 ms per frame)", anim.frame_index() == 0)
	anim.tick(0.025)
	check("step at 225 ms is frame 1", anim.frame_index() == 1)
	anim.tick(0.2)
	check("step at 425 ms still frame 1", anim.frame_index() == 1)
	anim.tick(0.025)
	check("step at 450 ms wrapped to frame 0 (loop)", anim.frame_index() == 0 and not anim.is_finished())
	# Non-positive total keeps the sheet's own 300 ms frames.
	var native := _animator()
	native.play_timed("step", 0.0)
	native.tick(0.25)
	check("play_timed with 0 s uses the sheet's 300 ms frames", native.frame_index() == 0)
	native.tick(0.05)
	check("...and advances at 300 ms", native.frame_index() == 1)


func test_play_timed_once_finishes_at_cooldown() -> void:
	var anim := _animator()
	anim.play_timed("step", STEP_COOLDOWN_SEC, "once")
	check("loop override reports 'once'", anim.loop_kind() == "once")
	anim.tick(STEP_COOLDOWN_SEC - 0.01)
	check("timed-once step not finished at 440 ms", not anim.is_finished() and anim.frame_index() == 1)
	anim.tick(0.01)
	check("timed-once step finished at 450 ms on frame 1", anim.is_finished() and anim.frame_index() == 1)
	check("missing clip through play_timed is false", not anim.play_timed("nope", 0.3))


func test_reduce_motion_holds_idle_but_plays_hit() -> void:
	var anim := _animator()
	anim.play("idle")
	anim.tick(IDLE_FRAME_SEC)
	check("idle advanced to frame 1 before reduce motion", anim.frame_index() == 1)
	anim.set_reduce_motion(true)
	check("set_reduce_motion snaps idle to frame 0", anim.frame_index() == 0)
	anim.tick(IDLE_FRAME_SEC * 3.0)
	check("reduce motion: idle holds frame 0 after 1200 ms", anim.frame_index() == 0)
	check("reduce motion: idle still not finished", not anim.is_finished())
	# Other clips still play.
	anim.play("hit")
	check("hit plays under reduce motion", anim.current_clip() == "hit")
	anim.tick(HIT_SEC * 0.5)
	check("hit at 60 ms not finished", not anim.is_finished())
	anim.tick(HIT_SEC * 0.5)
	check("hit at 120 ms finished (1 frame once)", anim.is_finished() and anim.frame_index() == 0)
	anim.play("cast_gesture")
	anim.tick(CAST_FRAME0_SEC)
	check("cast_gesture advances under reduce motion", anim.frame_index() == 1)
	anim.set_reduce_motion(false)
	anim.play("idle")
	anim.tick(IDLE_FRAME_SEC)
	check("idle animates again once reduce motion is off", anim.frame_index() == 1)


func test_missing_clip_returns_false_and_idle() -> void:
	var anim := _animator()
	check("play('victory') on the trimmed sheet is false", not anim.play("victory"))
	check("missing clip falls back to idle", anim.current_clip() == "idle")
	anim.tick(IDLE_FRAME_SEC)
	check("fallback idle is actually playing (frame 1 at 400 ms)", anim.frame_index() == 1)
	# Missing clip while on idle does not restart idle.
	check("play('nope') while idle is false", not anim.play("nope"))
	check("idle keeps its frame (not restarted)", anim.frame_index() == 1)
	# Missing clip while on step returns to idle.
	anim.play("step")
	check("play('windup') on a hero sheet is false", not anim.play("windup"))
	check("returns to idle from step", anim.current_clip() == "idle" and anim.frame_index() == 0)
	check("no error: frame_rect is idle frame 0", anim.frame_rect() == Rect2i(0, 0, 40, 48))


func test_play_same_clip_keeps_going_unless_restart() -> void:
	var anim := _animator()
	anim.play("idle")
	anim.tick(IDLE_FRAME_SEC)
	check("play('idle') again keeps frame 1", anim.play("idle") and anim.frame_index() == 1)
	check("play('idle', true) restarts at frame 0", anim.play("idle", true) and anim.frame_index() == 0)
	anim.play("hit")
	anim.tick(HIT_SEC)
	check("hit finished", anim.is_finished())
	check("play('hit') again without restart stays finished", anim.play("hit") and anim.is_finished())
	check("play('hit', true) restarts and clears finished", anim.play("hit", true) and not anim.is_finished())
	check("is_playing true with a clip loaded", anim.is_playing())


func test_null_sheet_is_a_quiet_no_op() -> void:
	var anim := UnitAnimatorScript.new(null)
	check("null sheet: play is false", not anim.play("idle"))
	check("null sheet: play_timed is false", not anim.play_timed("step", 0.3))
	anim.tick(1.0)
	anim.set_reduce_motion(true)
	anim.tick(1.0)
	check("null sheet: current_clip is ''", anim.current_clip() == "")
	check("null sheet: frame_index is 0", anim.frame_index() == 0)
	check("null sheet: frame_rect is zero", anim.frame_rect() == Rect2i())
	check("null sheet: is_finished false", not anim.is_finished())
	check("null sheet: is_playing false", not anim.is_playing())
	check("null sheet: sheet() is null", anim.sheet() == null)
	check("null sheet: frame_count 0", anim.frame_count() == 0)

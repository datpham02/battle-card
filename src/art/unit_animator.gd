class_name UnitAnimator
extends RefCounted
## Pure clip state machine over one `SpriteSheet`. Story 047 Part C (art bible §8.6 loop rules
## and reduce-motion idle). Node-free: the owner (`UnitLayer`) calls `tick(delta)` with the
## battle clock (so Focus / Pause stop it) and draws `frame_rect()` from its own `_draw`.
##
## Loop kinds (from `clip.loop`):
##   loop       wraps to frame 0 after the last frame; never finished.
##   once       plays through, then stays on the last frame and reports finished (the caller
##              decides what comes next, usually `play("idle")`).
##   hold_last  plays through and stops on the last frame; finished once it gets there.
##   hold       shows frame 0 and stays; finished once that frame's duration elapses.
## A frame with 0 ms holds indefinitely in every kind (`fall`, `windup`), so such a clip never
## reports finished: the caller leaves it from its own state (boss stopped swinging, ...).
##
## Priority is the caller's call: this class has no override stack. `UnitLayer` keeps its own
## rule (hit over step / windup for 0.12 s, defeat / down over everything) and simply calls
## `play` or lets a clip run. Timing is kept in milliseconds with a small tolerance so a clip of
## 80 + 120 ms finishes at exactly 200 ms of delta.

## `sprite_sheet.gd` is referenced by preload so this file parses before the global class cache
## knows `SpriteSheet` (same reason as `status_packs.gd`).
const SpriteSheetScript := preload("res://src/art/sprite_sheet.gd")

const IDLE_CLIP := "idle"
const LOOP := "loop"
const ONCE := "once"
const HOLD_LAST := "hold_last"
const HOLD := "hold"
## Tolerance in ms when comparing the accumulated clock to a frame duration.
const EPSILON_MS := 1e-4

var _sheet: SpriteSheetScript = null
var _clip_name: String = ""
var _frames: Array[Rect2i] = []
var _durations_ms: Array[float] = []
var _loop: String = LOOP
var _index: int = 0
var _elapsed_ms: float = 0.0
var _finished: bool = false
var _reduce_motion: bool = false


## `sheet` may be null (unit without art): every call is then a no-op with neutral results.
func _init(sheet: SpriteSheetScript) -> void:
	_sheet = sheet


## The sheet this animator walks (null for a placeholder unit).
func sheet() -> SpriteSheetScript:
	return _sheet


## Starts `clip_name` with the sheet's own durations. Already playing it and `restart` is
## false: keeps going and returns true. Clip missing (or no sheet): returns false and falls
## back to `idle` when the sheet has one (stays on idle if already there).
func play(clip_name: String, restart: bool = false) -> bool:
	return _play(clip_name, restart, [], "")


## Starts `clip_name` with its frames sharing `total_sec` equally, for clips whose length is
## decided by game state (`step` follows the UnitMover cooldown). `loop_kind` overrides the
## sheet's loop rule ("once" makes `step` finish exactly at `total_sec`); "" keeps the sheet's.
## Non-positive `total_sec` keeps the sheet's own durations. Always restarts. Same fallback as
## `play` when the clip is missing.
func play_timed(clip_name: String, total_sec: float, loop_kind: String = "") -> bool:
	var timed: Array[float] = []
	if total_sec > 0.0 and _sheet != null and _sheet.has_clip(clip_name):
		var count: int = (_sheet.clip(clip_name)["frames"] as Array).size()
		var share: float = total_sec * 1000.0 / float(maxi(1, count))
		for i in count:
			timed.append(share)
	return _play(clip_name, true, timed, loop_kind)


## Advances the clock by `delta` seconds (battle time, not wall time).
func tick(delta: float) -> void:
	if _frames.is_empty() or _finished or delta <= 0.0:
		return
	if _reduce_motion and _clip_name == IDLE_CLIP:
		_index = 0
		return
	var duration: float = _durations_ms[_index]
	if duration <= 0.0:
		return
	_elapsed_ms += delta * 1000.0
	while _elapsed_ms + EPSILON_MS >= duration:
		_elapsed_ms -= duration
		if not _advance():
			_elapsed_ms = 0.0
			return
		duration = _durations_ms[_index]
		if duration <= 0.0:
			_elapsed_ms = 0.0
			return


## Name of the playing clip; "" when nothing plays (no sheet, or the sheet has no idle).
func current_clip() -> String:
	return _clip_name


## Loop kind of the playing clip ("" when nothing plays).
func loop_kind() -> String:
	return _loop if not _frames.is_empty() else ""


## Index of the frame to draw within the clip (0 when nothing plays).
func frame_index() -> int:
	return _index


## Number of frames in the playing clip (0 when nothing plays).
func frame_count() -> int:
	return _frames.size()


## Source rect of the frame to draw; `Rect2i()` (zero) when nothing plays.
func frame_rect() -> Rect2i:
	if _frames.is_empty():
		return Rect2i()
	return _frames[_index]


## True once a `once` / `hold_last` / `hold` clip has reached its end; never for `loop`, and
## never while a 0 ms frame is holding. False when nothing plays.
func is_finished() -> bool:
	return _finished


## True while a clip is loaded (even a finished one).
func is_playing() -> bool:
	return not _frames.is_empty()


## Reduce motion (§8.6): `idle` holds frame 0; every other clip still plays.
func set_reduce_motion(on: bool) -> void:
	_reduce_motion = on
	if on and _clip_name == IDLE_CLIP and not _frames.is_empty():
		_index = 0
		_elapsed_ms = 0.0


func is_reduce_motion() -> bool:
	return _reduce_motion


## Shared start logic. `timed_ms` replaces the clip's durations when non-empty.
func _play(clip_name: String, restart: bool, timed_ms: Array[float], loop_override: String) -> bool:
	if _sheet == null:
		return false
	if not _sheet.has_clip(clip_name):
		if clip_name != IDLE_CLIP and _sheet.has_clip(IDLE_CLIP) and _clip_name != IDLE_CLIP:
			_start(IDLE_CLIP, [], "")
		return false
	if clip_name == _clip_name and not restart:
		return true
	_start(clip_name, timed_ms, loop_override)
	return true


func _start(clip_name: String, timed_ms: Array[float], loop_override: String) -> void:
	var c: Dictionary = _sheet.clip(clip_name)
	_clip_name = clip_name
	_frames = c["frames"]
	_durations_ms = []
	if timed_ms.is_empty():
		for ms: int in (c["durations_ms"] as Array[int]):
			_durations_ms.append(float(ms))
	else:
		_durations_ms = timed_ms.duplicate()
	_loop = loop_override if SpriteSheetScript.LOOP_KINDS.has(loop_override) else String(c["loop"])
	_index = 0
	_elapsed_ms = 0.0
	_finished = false
	if _loop == HOLD and _frames.size() > 1:
		# A hold clip shows its first frame only; extra frames are ignored by design.
		_frames = [_frames[0]]
		_durations_ms = [_durations_ms[0]]


## Steps to the next frame per the loop kind. False when the clip stopped (finished).
func _advance() -> bool:
	var last: int = _frames.size() - 1
	if _loop == LOOP:
		_index = 0 if _index >= last else _index + 1
		return true
	if _index < last:
		_index += 1
		return true
	_finished = true
	return false

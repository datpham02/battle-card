extends RefCounted
## Dash pass (user 2026-11-15, "nhay luot dash ... dash la chinh"): the fading copies of a unit's sprite that trail
## behind it while it glides from one cell to the next.
##
## Why this is its own file and has no `class_name`: `unit_layer.gd` is edited by several sessions at once, and a new
## `class_name` breaks every other session's headless run until a Godot run rebuilds the class cache. It is loaded the
## way `PassiveCueLayer` is -- `const DashGhost = preload(...)` -- which costs nothing and disturbs nobody.
##
## Every function here is pure: no nodes, no state, no allocation beyond the returned Array. [UnitLayer] turns a
## sample into a draw by adding its `offset` to the feet it is already drawing and tinting by `alpha`.

## Never draw more than this many ghosts, whatever the profile asks for: each one is a full sprite blit, and past
## four they stop reading as a trail and start reading as a crowd.
const MAX_GHOSTS: int = 4
## Alpha of the ghost nearest the body. The ones behind it fade off linearly.
const NEAR_ALPHA: float = 0.34
## The trail is at full strength for the first half of the glide, then fades out, so nothing lingers after landing.
const FADE_FROM: float = 0.5


## Pure: where the unit WAS [param age] seconds before the moment with [param left] seconds of glide left, as an
## offset (art px) from the destination feet -- the same convention as [method UnitLayer.slide_offset], which this
## mirrors. [param ease] is the horizontal ease exponent ([member UnitMotion.dash_ease]).
## Returns Vector2i.ZERO when that moment is before the glide began (there was no trail yet).
static func offset_at(from: Vector2i, to: Vector2i, left: float, total: float, age: float, ease: float) -> Vector2i:
	if total <= 0.0:
		return Vector2i.ZERO
	var then: float = left + maxf(age, 0.0)
	if then >= total:
		return Vector2i.ZERO  # before the dash started: no ghost yet
	var t: float = 1.0 - clampf(then / total, 0.0, 1.0)
	var remain: float = pow(1.0 - t, maxf(ease, 0.1))
	return Vector2i(roundi((from.x - to.x) * remain), roundi((from.y - to.y) * remain))


## Pure: the trail at the moment with [param left] of [param total] seconds of glide left, nearest ghost first.
## Each entry is {"offset": Vector2i (from the destination feet), "alpha": float in (0, 1]}.
##
## [param gap] is seconds between ghosts, but it is a CAP, not the spacing: the trail is squeezed to fit inside the
## part of the dash already travelled. A fixed spacing does not survive a short dash -- at 120 ms a 35 ms gap leaves
## room for the third ghost only in the last few frames, so the trail would pop from one copy to three while the eye
## is on it. Squeezing instead makes the trail grow out of the body as the dash goes, which is what an afterimage
## does, and keeps the count steady whatever the dash length or the frame rate.
##
## Empty when the unit is not gliding, when [param count] is 0, or while every ghost would land on the body's own
## pixel (the first instant, when the unit has not moved far enough for a copy to be visible behind it).
static func samples(from: Vector2i, to: Vector2i, left: float, total: float, ease: float,
		count: int, gap: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = mini(maxi(count, 0), MAX_GHOSTS)
	var elapsed: float = total - left
	if n == 0 or total <= 0.0 or left <= 0.0 or gap <= 0.0 or elapsed <= 0.0:
		return out
	var step: float = minf(gap, elapsed / float(n + 1))
	# Fade the whole trail out over the back half of the glide, so it is gone the moment the unit lands.
	var life: float = clampf(left / total / FADE_FROM, 0.0, 1.0)
	var previous: Vector2i = offset_at(from, to, left, total, 0.0, ease)  # the body itself
	for k: int in range(1, n + 1):
		var offset: Vector2i = offset_at(from, to, left, total, float(k) * step, ease)
		if offset == previous:
			continue  # it would land on the pixel already drawn: nothing to see, and alpha would just stack
		previous = offset
		var alpha: float = NEAR_ALPHA * (1.0 - float(k - 1) / float(n)) * life
		if alpha <= 0.0:
			continue
		out.append({"offset": offset, "alpha": alpha})
	return out

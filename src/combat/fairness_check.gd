class_name FairnessCheck
extends RefCounted
## Pure fairness rules of the pattern brain (design/quick-specs/phase2-misty-forest-2026-11-01.md section 4, F1-F10).
## Every function is static and takes plain values, so each rule is a unit test. Numbers come from
## enemy_skills.json `fairness` (reaction_margin_sec, max_red_ratio, cc_grace_sec, min_gap_between_warnings_sec,
## followup_min_warning_sec, heavy_recovery_sec), never from here.
## [param env] used by the path functions: {blocked_fn: Callable(cell) -> bool (cannot be walked: hole),
## hazard_fn: Callable(cell) -> bool (walkable but not a SAFE end: cracking, thorns, burning), unsafe: Array[Vector2i]
## (cells of every OTHER warning showing now, trait or skill)}. Missing keys = nothing blocked.
## Implements: spec 4.1 and 4.2 (P2.2).

const _EPS: float = 0.000001
const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## 4.1: seconds the player needs to reach a cell [param k] steps away: lock_left + (k - 1) * step_cd + margin.
static func t_need(k: int, lock_left: float, step_cd: float, margin: float) -> float:
	return maxf(lock_left, 0.0) + float(maxi(k - 1, 0)) * step_cd + margin


## 4.1: lock_left = max(step cooldown left, Frozen left, Root left).
static func lock_left(step_cooldown_left: float, frozen_left: float, root_left: float) -> float:
	return maxf(maxf(step_cooldown_left, frozen_left), maxf(root_left, 0.0))


## F1 / F9 (4.1): true when the player standing on [param player_cell] is not in [param cells], or a safe cell at BFS
## distance k exists with t_need(k) <= [param warning_sec]. A safe cell: on the player's half, not in [param cells],
## not in env.unsafe, not blocked, not a hazard. Paths may cross red (not yet hit) cells, never holes.
static func can_hero_respond(
	grid: BoardGrid, player_cell: Vector2i, cells: Array, warning_sec: float, p_lock_left: float, step_cd: float,
	margin: float, env: Dictionary = {}
) -> bool:
	if not cells.has(player_cell):
		return true
	return not escape_path(grid, player_cell, cells, warning_sec, p_lock_left, step_cd, margin, env).is_empty()


## The shortest path (cells after the start, in order) from [param player_cell] to the nearest safe cell reachable in
## time (see [method can_hero_respond]); empty when none or when the player is not in [param cells]. Deterministic
## (BFS in a fixed direction order). The "perfect dodger" bot walks this.
static func escape_path(
	grid: BoardGrid, player_cell: Vector2i, cells: Array, warning_sec: float, p_lock_left: float, step_cd: float,
	margin: float, env: Dictionary = {}
) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not cells.has(player_cell):
		return none
	var prev: Dictionary = {player_cell: player_cell}
	var dist: Dictionary = {player_cell: 0}
	var queue: Array[Vector2i] = [player_cell]
	var head: int = 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		var k: int = int(dist[at])
		if k > 0 and _is_safe(grid, at, cells, env):
			if t_need(k, p_lock_left, step_cd, margin) <= warning_sec + _EPS:
				var path: Array[Vector2i] = []
				var c: Vector2i = at
				while c != player_cell:
					path.push_front(c)
					c = prev[c] as Vector2i
				return path
			return none
		for d: Vector2i in _DIRS:
			var n: Vector2i = at + d
			if dist.has(n) or not grid.is_player_cell(n) or _call(env, "blocked_fn", n):
				continue
			dist[n] = k + 1
			prev[n] = at
			queue.append(n)
	return none


## F2: the red ceiling, floor(max_red_ratio x usable floor cells) (3x3 at 0.5 -> 4).
static func red_cap(usable_cells: int, max_red_ratio: float) -> int:
	return floori(float(usable_cells) * max_red_ratio + _EPS)


## F2: true when the union of [param new_cells] and [param other_red] (every warning showing, queued stripes too) stays
## within [method red_cap] of [param usable_cells].
static func red_ok(new_cells: Array, other_red: Array, usable_cells: int, max_red_ratio: float) -> bool:
	var union: Dictionary = {}
	for c: Variant in new_cells:
		union[c] = true
	for c: Variant in other_red:
		union[c] = true
	return union.size() <= red_cap(usable_cells, max_red_ratio)


## F2: usable floor of the player's half: real cells not blocked by env.blocked_fn nor env.hazard_fn (holes, cracking).
static func usable_floor(grid: BoardGrid, env: Dictionary = {}) -> int:
	var n: int = 0
	for c: Vector2i in grid.player_cells():
		if not _call(env, "blocked_fn", c) and not _call(env, "lock_fn", c):
			n += 1
	return n


## F3: after a zone forms on [param zone_cells] the player keeps at least one adjacent cell to step onto that is not in
## the zone and not blocked.
static func zone_leaves_exit(grid: BoardGrid, player_cell: Vector2i, zone_cells: Array, env: Dictionary = {}) -> bool:
	for d: Vector2i in _DIRS:
		var n: Vector2i = player_cell + d
		if grid.is_player_cell(n) and not zone_cells.has(n) and not _call(env, "blocked_fn", n):
			return true
	return false


## F4: a new Root / Frozen from an enemy may land only when the player is not locked ([param p_lock_left] = Frozen /
## Root seconds left, step cooldown excluded) and the grace after the last lock ([param grace_left]) is over.
static func cc_allowed(p_lock_left: float, grace_left: float) -> bool:
	return p_lock_left <= _EPS and grace_left <= _EPS


## F5: an enemy warning may start [param since_last_warning] seconds after the previous one started.
static func gap_ok(since_last_warning: float, min_gap: float) -> bool:
	return since_last_warning + _EPS >= min_gap


## F10: the gap needed before the next warning after a skill with [param recovery_sec]: a heavy skill
## (recovery >= [param heavy_recovery_sec]) leaves at least one step (+ margin) of meaningful action; otherwise min_gap.
static func gap_needed(recovery_sec: float, min_gap: float, step_cd: float, margin: float, heavy_recovery_sec: float) -> float:
	if recovery_sec + _EPS >= heavy_recovery_sec:
		return maxf(min_gap, step_cd + margin)
	return min_gap


## F7: [param cells] without the locked ones (StatusEffects.unlocked_cells is the game's gate; this is its pure form).
static func drop_locked(cells: Array, locked_fn: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		if not (locked_fn.is_valid() and bool(locked_fn.call(c))):
			out.append(c)
	return out


## F8: a NEW source starting while [param showing] cells warn must leave a cell safe from both: the player can still
## respond to the union of both warnings within the shorter warning time [param warning_sec].
static func both_leave_safe(
	grid: BoardGrid, player_cell: Vector2i, showing: Array, new_cells: Array, warning_sec: float, p_lock_left: float,
	step_cd: float, margin: float, env: Dictionary = {}
) -> bool:
	var union: Array = showing.duplicate()
	for c: Variant in new_cells:
		if not union.has(c):
			union.append(c)
	if not union.has(player_cell):
		return _has_any_safe(grid, union, env)
	return can_hero_respond(grid, player_cell, union, warning_sec, p_lock_left, step_cd, margin, env)


static func _has_any_safe(grid: BoardGrid, cells: Array, env: Dictionary) -> bool:
	for c: Vector2i in grid.player_cells():
		if _is_safe(grid, c, cells, env):
			return true
	return false


static func _is_safe(grid: BoardGrid, cell: Vector2i, cells: Array, env: Dictionary) -> bool:
	if not grid.is_player_cell(cell) or cells.has(cell):
		return false
	if (env.get("unsafe", []) as Array).has(cell):
		return false
	return not _call(env, "blocked_fn", cell) and not _call(env, "hazard_fn", cell) and not _call(env, "lock_fn", cell)


static func _call(env: Dictionary, key: String, cell: Vector2i) -> bool:
	var fn: Variant = env.get(key)
	return typeof(fn) == TYPE_CALLABLE and (fn as Callable).is_valid() and bool((fn as Callable).call(cell))
